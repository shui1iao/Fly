const SCRIPT_VERSION = 'v20250617';
// == 样式注入模块 ==
// 注入自定义CSS隐藏特定元素 + 流量条模糊背景样式
function injectCustomCSS() {
  const style = document.createElement('style');
  style.textContent = `
    /* 隐藏父级类名为 mt-4 w-full mx-auto 下的所有 div */
    .mt-4.w-full.mx-auto > div { display: none; }

    /* ===== 流量条模糊背景样式 ===== */
    .traffic-bar-wrapper {
      position: relative;
      height: 6px;              /* 原 h-1.5 */
      border-radius: 9999px;
      overflow: hidden;         /* 裁掉超出部分，避免模糊溢出 */
      isolation: isolate;       /* 避免 backdrop 与外层 stacking 冲突 */
    }
    .traffic-bar-bg-blur {
      position: absolute;
      inset: 0;
      /* 半透明底，配合 backdrop-filter 呈现高斯模糊 */
      background: rgba(255, 255, 255, 0.14);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      border: 1px solid rgba(255, 255, 255, 0.22);
      border-radius: inherit;
      z-index: 0;
    }
    /* 深色模式下稍微提高透明度对比 */
    .dark .traffic-bar-bg-blur {
      background: rgba(0, 0, 0, 0.22);
      border-color: rgba(255, 255, 255, 0.12);
    }
    .traffic-progress-bar {
      position: absolute;
      inset: 0;
      border-radius: inherit;
      z-index: 1;               /* 进度条要在模糊层之上 */
      transition: width 0.3s ease, background-color 0.3s ease;
    }
  `;
  document.head.appendChild(style);
}
injectCustomCSS();

// == 工具函数模块 ==
const utils = (() => {
  function formatFileSize(bytes) {
    if (bytes === 0) return { value: '0', unit: 'B' };
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    let size = bytes;
    let unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return { value: size.toFixed(unitIndex === 0 ? 0 : 2), unit: units[unitIndex] };
  }

  function calculatePercentage(used, total) {
    used = Number(used); total = Number(total);
    if (used > 1e15 || total > 1e15) { used /= 1e10; total /= 1e10; }
    return total === 0 ? '0.00' : ((used / total) * 100).toFixed(2);
  }

  function formatDate(dateString) {
    const date = new Date(dateString);
    if (isNaN(date)) return '';
    return date.toLocaleDateString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit' });
  }

  function safeSetTextContent(parent, selector, text) {
    const el = parent.querySelector(selector);
    if (el) el.textContent = text;
  }

  function getHslGradientColor(percentage) {
    const clamp = (v, a, b) => Math.min(Math.max(v, a), b);
    const lerp = (s, e, t) => s + (e - s) * t;
    const p = clamp(Number(percentage), 0, 100);
    let h, s, l;
    if (p <= 35) {
      const t = p / 35;  h = lerp(142, 32, t); s = lerp(69, 85, t); l = lerp(45, 55, t);
    } else if (p <= 85) {
      const t = (p - 35) / 50; h = lerp(32, 0, t); s = lerp(85, 75, t); l = lerp(55, 50, t);
    } else {
      const t = (p - 85) / 15; h = 0; s = 75; l = lerp(50, 45, t);
    }
    return `hsl(${h.toFixed(0)}, ${s.toFixed(0)}%, ${l.toFixed(0)}%)`;
  }

  function fadeOutIn(element, newContent, duration = 500) {
    element.style.transition = `opacity ${duration / 2}ms`;
    element.style.opacity = '0';
    setTimeout(() => {
      element.innerHTML = newContent;
      element.style.transition = `opacity ${duration / 2}ms`;
      element.style.opacity = '1';
    }, duration / 2);
  }

  return { formatFileSize, calculatePercentage, formatDate, safeSetTextContent, getHslGradientColor, fadeOutIn };
})();

// == 流量统计渲染模块 ==
const trafficRenderer = (() => {
  const toggleElements = [];  // 这版不使用轮播

  function renderTrafficStats(trafficData, config) {
    const serverMap = new Map();

    // 解析数据
    for (const cycleId in trafficData) {
      const cycle = trafficData[cycleId];
      if (!cycle.server_name || !cycle.transfer) continue;
      for (const serverId in cycle.server_name) {
        const serverName = cycle.server_name[serverId];
        const transfer   = cycle.transfer[serverId];
        const max        = cycle.max;
        const from       = cycle.from;
        const to         = cycle.to;
        const next_update = cycle.next_update[serverId];
        if (serverName && transfer !== undefined && max && from && to) {
          serverMap.set(serverName, { id: serverId, transfer, max, name: cycle.name, from, to, next_update });
        }
      }
    }

    serverMap.forEach((serverData, serverName) => {
      const targetElement = Array.from(document.querySelectorAll('section.grid.items-center.gap-2'))
        .find(section => section.querySelector('p')?.textContent.trim() === serverName.trim());
      if (!targetElement) return;

      const usedFormatted  = utils.formatFileSize(serverData.transfer);
      const totalFormatted = utils.formatFileSize(serverData.max);
      const percentage     = utils.calculatePercentage(serverData.transfer, serverData.max);
      const fromFormatted  = utils.formatDate(serverData.from);
      const toFormatted    = utils.formatDate(serverData.to);
      const nextUpdateFormatted = new Date(serverData.next_update).toLocaleString("zh-CN", { timeZone: "Asia/Shanghai" });
      const uniqueClassName = 'traffic-stats-for-server-' + serverData.id;
      const progressColor   = utils.getHslGradientColor(percentage);
      const containerDiv = targetElement.closest('div');
      if (!containerDiv) return;

      const log = (...args) => { if (config.enableLog) console.log('[renderTrafficStats]', ...args); };

      const existing = Array.from(containerDiv.querySelectorAll('.new-inserted-element'))
        .find(el => el.classList.contains(uniqueClassName));

      if (!config.showTrafficStats) {
        if (existing) { existing.remove(); log(`移除流量条目: ${serverName}`); }
        return;
      }

      if (existing) {
        // 仅更新必要字段（不显示百分比、不做轮播）
        utils.safeSetTextContent(existing, '.used-traffic',  usedFormatted.value);
        utils.safeSetTextContent(existing, '.used-unit',     usedFormatted.unit);
        utils.safeSetTextContent(existing, '.total-traffic', totalFormatted.value);
        utils.safeSetTextContent(existing, '.total-unit',    totalFormatted.unit);
        utils.safeSetTextContent(existing, '.from-date',     fromFormatted);
        utils.safeSetTextContent(existing, '.to-date',       toFormatted);
        utils.safeSetTextContent(existing, '.next-update',   `next update: ${nextUpdateFormatted}`);

        const progressBar = existing.querySelector('.traffic-progress-bar');
        if (progressBar) {
          progressBar.style.width = percentage + '%';
          progressBar.style.backgroundColor = progressColor;
        }
        log(`更新流量条目: ${serverName}`);
      } else {
        // 插入新元素
        let oldSection = null;
        if (config.insertAfter) {
          oldSection = containerDiv.querySelector('section.flex.items-center.w-full.justify-between.gap-1')
                   || containerDiv.querySelector('section.grid.items-center.gap-3');
        } else {
          oldSection = containerDiv.querySelector('section.grid.items-center.gap-3');
        }
        if (!oldSection) return;

        const defaultTimeInfoHTML = `
          <span class="from-date">${fromFormatted}</span>
          <span class="text-neutral-500 dark:text-neutral-400">-</span>
          <span class="to-date">${toFormatted}</span>
        `;

        const newElement = document.createElement('div');
        newElement.classList.add('space-y-1.5', 'new-inserted-element', uniqueClassName);
        newElement.style.width = '100%';
        newElement.innerHTML = `
          <div class="flex items-center justify-between">
            <div class="flex items-baseline gap-1">
              <span class="text-[10px] font-medium text-neutral-800 dark:text-neutral-200 used-traffic">${usedFormatted.value}</span>
              <span class="text-[10px] font-medium text-neutral-800 dark:text-neutral-200 used-unit">${usedFormatted.unit}</span>
              <span class="text-[10px] text-neutral-500 dark:text-neutral-400">/ </span>
              <span class="text-[10px] text-neutral-500 dark:text-neutral-400 total-traffic">${totalFormatted.value}</span>
              <span class="text-[10px] text-neutral-500 dark:text-neutral-400 total-unit">${totalFormatted.unit}</span>
            </div>
            <div class="text-[10px] font-medium text-neutral-600 dark:text-neutral-300 time-info" style="opacity:1; transition: opacity 0.3s;">
              ${defaultTimeInfoHTML}
            </div>
          </div>

          <!-- 模糊背景的流量条 -->
          <div class="traffic-bar-wrapper">
            <div class="traffic-bar-bg-blur"></div>
            <div class="traffic-progress-bar" style="width: ${percentage}%; background-color: ${progressColor};"></div>
          </div>
        `;

        oldSection.after(newElement);
        log(`插入新流量条目: ${serverName}`);

        // 不加入轮播
      }
    });
  }

  function startToggleCycle(toggleInterval, duration) {
    if (toggleInterval <= 0) return;
    // 这版不启用轮播（保持空实现以兼容调用）
  }

  return { renderTrafficStats, startToggleCycle };
})();

// == 数据请求和缓存模块 ==
const trafficDataManager = (() => {
  let trafficCache = null;

  function fetchTrafficData(apiUrl, config, callback) {
    const now = Date.now();
    if (trafficCache && (now - trafficCache.timestamp < config.interval)) {
      if (config.enableLog) console.log('[fetchTrafficData] 使用缓存数据');
      callback(trafficCache.data);
      return;
    }

    if (config.enableLog) console.log('[fetchTrafficData] 请求新数据...');
    fetch(apiUrl)
      .then(res => res.json())
      .then(data => {
        if (!data.success) {
          if (config.enableLog) console.warn('[fetchTrafficData] 请求成功但数据异常');
          return;
        }
        if (config.enableLog) console.log('[fetchTrafficData] 成功获取新数据');
        const trafficData = data.data.cycle_transfer_stats;
        trafficCache = { timestamp: now, data: trafficData };
        callback(trafficData);
      })
      .catch(err => {
        if (config.enableLog) console.error('[fetchTrafficData] 请求失败:', err);
      });
  }

  return { fetchTrafficData };
})();

// == DOM变化监听模块 ==
const domObserver = (() => {
  const TARGET_SELECTOR = 'section.server-card-list, section.server-inline-list';
  let currentSection = null;
  let childObserver = null;

  function onDomChildListChange(onChangeCallback) { onChangeCallback(); }

  function observeSection(section, onChangeCallback) {
    if (childObserver) { childObserver.disconnect(); }
    currentSection = section;
    childObserver = new MutationObserver(mutations => {
      for (const m of mutations) {
        if (m.type === 'childList' && (m.addedNodes.length || m.removedNodes.length)) {
          onDomChildListChange(onChangeCallback);
          break;
        }
      }
    });
    childObserver.observe(currentSection, { childList: true, subtree: false });
    onChangeCallback(); // 初始调用
  }

  function startSectionDetector(onChangeCallback) {
    const sectionDetector = new MutationObserver(() => {
      const section = document.querySelector(TARGET_SELECTOR);
      if (section && section !== currentSection) {
        observeSection(section, onChangeCallback);
      }
    });
    const root = document.querySelector('main') || document.body;
    sectionDetector.observe(root, { childList: true, subtree: true });
    return sectionDetector;
  }

  function disconnectAll(sectionDetector) {
    if (childObserver) childObserver.disconnect();
    if (sectionDetector) sectionDetector.disconnect();
  }

  return { startSectionDetector, disconnectAll };
})();

// == 主程序入口 ==
(function main() {
  const defaultConfig = {
    showTrafficStats: true,
    insertAfter: true,
    interval: 60000,
    toggleInterval: 5000,
    duration: 500,
    apiUrl: '/api/v1/service',
    enableLog: false
  };
  // 需要后续重赋值，使用 let
  let config = Object.assign({}, defaultConfig, window.TrafficScriptConfig || {});
  // 强制禁用轮播：只显示日期，不显示百分比且不循环
  config.toggleInterval = 0;

  if (config.enableLog) {
    console.log(`[TrafficScript] 版本: ${SCRIPT_VERSION}`);
    console.log('[TrafficScript] 最终配置如下:', config);
  }

  function updateTrafficStats() {
    trafficDataManager.fetchTrafficData(config.apiUrl, config, trafficData => {
      trafficRenderer.renderTrafficStats(trafficData, config);
    });
  }

  function onDomChange() {
    if (config.enableLog) console.log('[main] DOM变化，刷新流量数据');
    updateTrafficStats();
    if (!trafficTimer) startPeriodicRefresh();
  }

  let trafficTimer = null;
  function startPeriodicRefresh() {
    if (!trafficTimer) {
      if (config.enableLog) console.log('[main] 启动周期刷新任务');
      trafficTimer = setInterval(() => { updateTrafficStats(); }, config.interval);
    }
  }

  // 轮播关闭（传入0）
  trafficRenderer.startToggleCycle(config.toggleInterval, config.duration);

  const sectionDetector = domObserver.startSectionDetector(onDomChange);
  onDomChange();

  // 100ms 后检查外部配置
  setTimeout(() => {
    const newConfig = Object.assign({}, defaultConfig, window.TrafficScriptConfig || {});
    newConfig.toggleInterval = 0; // 仍强制关闭轮播
    if (JSON.stringify(newConfig) !== JSON.stringify(config)) {
      if (config.enableLog) console.log('[main] 100ms后检测到新配置，更新配置并重启任务');
      config = newConfig;
      startPeriodicRefresh();
      trafficRenderer.startToggleCycle(config.toggleInterval, config.duration);
      updateTrafficStats();
    } else {
      if (config.enableLog) console.log('[main] 100ms后无新配置，保持原配置');
    }
  }, 100);

  window.addEventListener('beforeunload', () => {
    domObserver.disconnectAll(sectionDetector);
    if (trafficTimer) clearInterval(trafficTimer);
  });
})();