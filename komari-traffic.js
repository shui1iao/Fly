/*! Komari Traffic Bars (batch render, anti-flicker) */
(() => {
  const CFG = {
    refreshMs: 30_000,                 // 正常轮询
    burstMs: 6_000,                    // 首屏“高频补渲染”窗口
    hideUnlimited: true,               // 不限流不显示
    matchCardSelector: '.rounded-lg.border.text-card-foreground',
    nameSelector: 'p.font-bold.text-xs',
    insertBeforeSelector: 'section.flex.gap-1.items-center.flex-wrap',
    barHeightPx: 6,
    recentConcurrency: 4,              // recent 并发（缺 stats 时才会请求）
    epsilonPct: 0.2,                   // 百分比变化小于该值则不更新（避免微抖）
    debug: false
  };

  const log = (...a) => CFG.debug && console.log('[traffic]', ...a);
  const q  = (el, sel) => el.querySelector(sel);
  const qa = (el, sel) => Array.from(el.querySelectorAll(sel));

  // CSS（淡入 + 毛玻璃一致）
  (function injectCSS(){
    if (document.getElementById('km-traffic-css')) return;
    const css = `
.km-traffic-wrap{opacity:0;transform:translateY(2px);transition:opacity .25s ease,transform .25s ease;}
.km-traffic-wrap.km-show{opacity:1;transform:none}
.km-traffic-shell{position:relative;width:100%;overflow:hidden;border-radius:.25rem;box-shadow:inset 0 1px 1px rgba(0,0,0,.06)}
.km-traffic-shell.bg-secondary{background-color:rgba(255,255,255,.4)}
.dark .km-traffic-shell.bg-secondary{background-color:rgba(0,0,0,.4)}
.km-traffic-label{display:flex;align-items:center;justify-content:space-between;font-size:10.5px;margin-top:.25rem}
`;
    const style = document.createElement('style');
    style.id = 'km-traffic-css';
    style.textContent = css;
    document.head.appendChild(style);
  })();

  const fmtBytes = n => {
    if (!Number.isFinite(n)) return '-';
    const u = ['B','KiB','MiB','GiB','TiB','PiB'];
    let v = Number(n), i = 0;
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
    return v.toFixed(v < 10 ? 2 : v < 100 ? 1 : 0) + ' ' + u[i];
  };
  const calcUsed = (type, up, down) => {
    switch ((type || 'sum').toLowerCase()) {
      case 'up':  return up;
      case 'down':return down;
      case 'max': return Math.max(up, down);
      case 'min': return Math.min(up, down);
      case 'sum': default: return up + down;
    }
  };
  const colorClass = pct => pct >= 90 ? 'bg-red-600' : pct >= 50 ? 'bg-yellow-400' : 'bg-green-500';
  const typeLabel  = t => ({sum:'月流量',up:'上行',down:'下行',max:'单向最大',min:'单向最小'})[(t||'sum').toLowerCase()] || t;

  async function jget(url){
    const r = await fetch(url, { credentials: 'include' });
    if (!r.ok) throw new Error(url + ' ' + r.status);
    return r.json();
  }

  function getCardName(cardEl){
    const el = q(cardEl, CFG.nameSelector);
    return (el?.textContent || '').trim();
  }
  function findInsertBefore(cardEl) {
    let anchor = q(cardEl, CFG.insertBeforeSelector);
    if (anchor) return anchor;
    const secs = qa(cardEl, 'section');
    return secs[secs.length - 1] || cardEl.lastElementChild || cardEl;
  }

  // 限并发
  function pLimit(n){
    const queue = [];
    let active = 0;
    const run = async (fn, resolve, reject) => {
      active++;
      try { resolve(await fn()); }
      catch(e){ reject(e); }
      finally {
        active--;
        if (queue.length) {
          const next = queue.shift();
          run(next.fn, next.res, next.rej);
        }
      }
    };
    return fn => new Promise((res, rej) => {
      if (active < n) run(fn, res, rej);
      else queue.push({ fn, res, rej });
    });
  }
  const limitRecent = pLimit(CFG.recentConcurrency);

  // 缓存：/api/nodes
  let nodesCache = null, nodesCacheAt = 0;
  async function getNodes(){
    const now = Date.now();
    if (nodesCache && (now - nodesCacheAt < 10_000)) return nodesCache;
    const res = await jget('/api/nodes');
    nodesCache = (res?.data || []);
    nodesCacheAt = now;
    return nodesCache;
  }

  async function getUsedFromRecent(uuid) {
    // 仅 stats 缺失时调用
    const rec = await jget(`/api/recent/${encodeURIComponent(uuid)}`);
    const arr = rec?.data || [];
    const last = arr[arr.length - 1] || {};
    const net  = last?.network || {};
    return { up: Number(net.totalUp || 0), down: Number(net.totalDown || 0) };
  }

  // —— 批量渲染 —— //
  let rendering = false;
  async function renderOnce(){
    if (rendering) return;
    rendering = true;
    try {
      const cards = qa(document, CFG.matchCardSelector);
      if (!cards.length) return;

      const byCard = new Map(); // cardEl -> { name, anchor }
      for (const card of cards) {
        const name = getCardName(card);
        if (!name) continue;
        byCard.set(card, { name, anchor: findInsertBefore(card) });
      }
      if (!byCard.size) return;

      const nodes = await getNodes();
      const mapByName = new Map(nodes.map(n => [(n.name || '').trim(), n]));

      // 准备异步任务：仅对缺少 stats 的节点请求 recent（限并发）
      const tasks = [];
      const results = new Map(); // name -> { percent, usedTxt, limitTxt, typeTxt }

      for (const { name } of byCard.values()) {
        const node = mapByName.get(name);
        if (!node) continue;
        const limit = Number(node.traffic_limit || 0);
        if (CFG.hideUnlimited && !limit) {
          results.set(name, null); // 表示隐藏
          continue;
        }
        let up = Number(node?.stats?.net_total_up ?? NaN);
        let down = Number(node?.stats?.net_total_down ?? NaN);

        if (Number.isFinite(up) && Number.isFinite(down)) {
          const used = calcUsed(node.traffic_limit_type, up, down);
          const percent = limit > 0 ? (used / limit) * 100 : 0;
          results.set(name, {
            percent, usedTxt: fmtBytes(used),
            limitTxt: limit ? fmtBytes(limit) : '无限制',
            typeTxt: typeLabel(node.traffic_limit_type)
          });
        } else {
          tasks.push(limitRecent(async () => {
            try {
              const ud = await getUsedFromRecent(node.uuid);
              up = ud.up; down = ud.down;
              const used = calcUsed(node.traffic_limit_type, up, down);
              const percent = limit > 0 ? (used / limit) * 100 : 0;
              results.set(name, {
                percent, usedTxt: fmtBytes(used),
                limitTxt: limit ? fmtBytes(limit) : '无限制',
                typeTxt: typeLabel(node.traffic_limit_type)
              });
            } catch(e){
              console.warn('recent failed:', name, e);
              results.set(name, null);
            }
          }));
        }
      }

      if (tasks.length) await Promise.allSettled(tasks);

      // 批量构建 DOM（不立即插入，先在 fragment 里搭好）
      const buildForCard = (card, info) => {
        if (!info) {
          const old = q(card, '.km-traffic-wrap'); if (old) old.remove();
          return null;
        }
        const pct = Math.max(0, Math.min(100, info.percent));
        // 如果已有且变化极小，则只更新宽度/文本，避免重建
        let wrap = q(card, '.km-traffic-wrap');
        let existed = !!wrap;
        if (!wrap) {
          wrap = document.createElement('div');
          wrap.className = 'km-traffic-wrap w-full mt-1';
        }
        // 如果有历史百分比且变化很小，不更新文本，减少抖动
        const prev = Number(wrap.dataset.pct || NaN);
        const minorChange = Number.isFinite(prev) && Math.abs(prev - pct) < CFG.epsilonPct;

        // 清空并重建（保证幂等）
        if (!minorChange) wrap.innerHTML = '';

        if (!minorChange) {
          const shell = document.createElement('div');
          shell.className = `km-traffic-shell bg-secondary rounded-sm`;
          shell.style.height = CFG.barHeightPx + 'px';
          const bar = document.createElement('div');
          bar.className = `h-full transition-all ${colorClass(pct)}`;
          bar.style.width = pct.toFixed(2) + '%';
          const label = document.createElement('div');
          label.className = 'km-traffic-label text-muted-foreground';
          label.innerHTML = `<span>${info.typeTxt}：${info.usedTxt} / ${info.limitTxt}</span><span>${pct.toFixed(1)}%</span>`;
          shell.appendChild(bar);
          wrap.appendChild(shell);
          wrap.appendChild(label);
        } else {
          const bar = q(wrap, '.h-full');
          if (bar) bar.style.width = pct.toFixed(2) + '%';
        }

        wrap.dataset.pct = pct.toString();

        // 把 wrap 放到正确位置（如果不在就移动过去）
        const anchor = byCard.get(card).anchor;
        if (wrap.parentNode !== anchor?.parentNode) {
          anchor?.parentNode?.insertBefore(wrap, anchor);
        }
        // 首次插入淡入
        if (!existed) {
          requestAnimationFrame(() => wrap.classList.add('km-show'));
        }
        return wrap;
      };

      // 统一调度到渲染帧里做 DOM 变更，避免每卡一次 reflow
      requestAnimationFrame(() => {
        const frag = document.createDocumentFragment();
        for (const [card, { name }] of byCard.entries()) {
          const info = results.get(name);
          const wrap = buildForCard(card, info);
          if (wrap && !wrap.parentNode) {
            // 正常情况下 buildForCard 已经插入了；这里仅兜底
            frag.appendChild(wrap);
          }
        }
        if (frag.childNodes.length) {
          const anyCard = [...byCard.keys()][0];
          const parent = anyCard?.parentNode;
          parent && parent.appendChild(frag);
        }
      });
    } catch (e) {
      console.warn('renderOnce failed:', e);
    } finally {
      rendering = false;
    }
  }

  // —— 触发策略 —— //
  renderOnce();

  // 首屏 6s 内每 400ms 补一次（防首屏抹掉）
  const t0 = Date.now();
  const burst = setInterval(() => {
    if (Date.now() - t0 > CFG.burstMs) return clearInterval(burst);
    renderOnce();
  }, 400);

  // 正常轮询
  setInterval(renderOnce, CFG.refreshMs);

  // DOM 变更（挂 body，避免容器被替换）
  const mo = new MutationObserver(() => { Promise.resolve().then(() => setTimeout(renderOnce, 0)); });
  mo.observe(document.body, { childList: true, subtree: true });

  // 路由/可见性/焦点
  const _ps = history.pushState, _rs = history.replaceState;
  history.pushState = function(){ _ps.apply(this, arguments); setTimeout(renderOnce, 0); };
  history.replaceState = function(){ _rs.apply(this, arguments); setTimeout(renderOnce, 0); };
  window.addEventListener('popstate', () => setTimeout(renderOnce, 0));
  window.addEventListener('hashchange', () => setTimeout(renderOnce, 0));
  document.addEventListener('visibilitychange', () => { if (!document.hidden) renderOnce(); });
  window.addEventListener('focus', renderOnce);
})();
