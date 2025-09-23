/* nezha-ui traffic-progress SHIM
 * 目标：
 * 1) 右上角只显示日期（不显示百分比、不轮播）
 * 2) 进度条“轨道”用你的高斯模糊风格
 * 实现：先加载官方脚本，再做覆盖与修正，避免破坏内部对接点
 */
(function () {
  const SHIM_VER = 'v20250923';

  // —— 1) 在加载官方脚本之前，先把轮播关掉（如果官方脚本读取这个配置就会直接禁用）
  window.TrafficScriptConfig = Object.assign({}, window.TrafficScriptConfig || {}, {
    toggleInterval: 0,     // 禁止轮播
    showTrafficStats: true // 保持显示
  });

  // —— 2) 注入与你自定义一致的“毛玻璃/高斯模糊”样式（尽量匹配多种 DOM 结构）
  (function injectBlurCSS() {
    const style = document.createElement('style');
    style.setAttribute('data-traffic-shim', SHIM_VER);
    style.textContent = `
      /* ======== 进度条轨道高斯模糊（亮色） ======== */
      .bg-secondary.h-\$begin:math:display$3px\\$end:math:display$.rounded-sm,
      .relative.h-1\\.5 > .absolute.inset-0.rounded-full:first-child,
      .traffic-progress-track,
      .traffic-bar-bg-blur {
        background-color: rgba(255, 255, 255, 0.5) !important;
        backdrop-filter: blur(18px) saturate(180%) !important;
        -webkit-backdrop-filter: blur(18px) saturate(180%) !important;
        border: 1px solid rgba(255, 255, 255, 0.2) !important;
      }
      /* ======== 进度条轨道高斯模糊（暗色） ======== */
      .dark .bg-secondary.h-\$begin:math:display$3px\\$end:math:display$.rounded-sm,
      .dark .relative.h-1\\.5 > .absolute.inset-0.rounded-full:first-child,
      .dark .traffic-progress-track,
      .dark .traffic-bar-bg-blur {
        background-color: rgba(30, 30, 30, 0.25) !important;
        border-color: rgba(255, 255, 255, 0.1) !important;
      }

      /* 通用：隐藏任何“百分比”标识的节点（若存在对应类名）*/
      .percentage-value,
      .time-info [data-type="percent"] {
        display: none !important;
      }
    `;
    document.head.appendChild(style);
  })();

  // —— 3) 加载官方 traffic-progress.js，然后做“只显示日期”的锁定
  const VENDOR_URL = 'https://cdn.jsdelivr.net/gh/ziwiwiz/nezha-ui@main/traffic-progress.js';

  function lockTimeInfoIn(el) {
    if (!el || el.dataset.locked === '1') return;

    const text = (el.textContent || '').replace(/\s+/g, ' ').trim();
    const fromNode = el.querySelector('.from-date');
    const toNode   = el.querySelector('.to-date');

    let from = '', to = '';
    if (fromNode && toNode) {
      from = fromNode.textContent.trim();
      to   = toNode.textContent.trim();
    } else {
      // 兜底：文本里找 “yyyy-mm-dd ... yyyy-mm-dd”
      const m = text.match(/(\d{4}[./-]\d{2}[./-]\d{2}).*?(\d{4}[./-]\d{2}[./-]\d{2})/);
      if (m) { from = m[1]; to = m[2]; }
    }

    let html = '';
    if (from && to) {
      html = `<span class="from-date">${from}</span><span class="text-neutral-500 dark:text-neutral-400">-</span><span class="to-date">${to}</span>`;
    } else {
      // 实在没有，就粗暴去掉百分号内容
      html = (text.includes('%') ? text.split('%')[0] : text);
    }

    el.innerHTML = html;
    el.dataset.locked = '1';
  }

  function scanAndLockDateOnly() {
    // 尽量覆盖不同实现下的右上角信息容器
    const nodes = document.querySelectorAll(
      '.time-info, .new-inserted-element .time-info, section .time-info'
    );
    nodes.forEach(lockTimeInfoIn);
  }

  function startGuardObserver() {
    const obs = new MutationObserver((muts) => {
      // 页面上有任何结构/子节点变更，尝试重锁一次
      for (const m of muts) {
        if (m.type === 'childList' || (m.type === 'attributes' && m.attributeName === 'class')) {
          scanAndLockDateOnly();
          break;
        }
      }
    });
    obs.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['class']
    });
  }

  // 动态加载官方脚本，再执行“只显示日期”与守护
  const s = document.createElement('script');
  s.src = VENDOR_URL;
  s.defer = true;
  s.onload = function () {
    // 给官方脚本一点渲染时间，再锁一次
    setTimeout(scanAndLockDateOnly, 200);
    startGuardObserver();
  };
  s.onerror = function () {
    console.warn('[traffic-progress.shim] 官方脚本加载失败；仅样式覆盖可用。');
  };
  document.head.appendChild(s);
})();