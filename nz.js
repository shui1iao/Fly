<script>
    // 全局配置
    window.ShowNetTransfer=true;
    window.ForceUseSvgFlag=true;
    window.CustomBackgroundImage = 'https://t.alcy.cc/ycy';
    window.CustomMobileBackgroundImage = 'https://t.alcy.cc/ycy';
    window.CustomLogo = 'https://raw.githubusercontent.com/shuijiao1/Fly/refs/heads/main/ID.PNG';
    window.DisableAnimatedMan = true;
    window.FixedTopServerName = true;
</script>

<!-- 流量进度条 -->
<script>
  window.TrafficScriptConfig = {
    showTrafficStats: true,   // 显示流量统计
    insertAfter: true,        // 插入位置
    interval: 60000,          // 刷新间隔 (ms)
    toggleInterval: 0,        // 切换间隔 (0 = 不切换)
    duration: 500,            // 缓动时间 (ms)
    enableLog: false          // 是否开启日志
  };
</script>
<script src="https://cdn.jsdelivr.net/gh/ziwiwiz/nezha-ui@main/traffic-progress.js"></script>

//直接显示网络延迟
<script>
const selectorButton = '#root > div > main > div.mx-auto.w-full.max-w-5xl.px-0.flex.flex-col.gap-4.server-info > section > div.flex.justify-center.w-full.max-w-\\[200px\\] > div > div > div.relative.cursor-pointer.rounded-3xl.px-2\\.5.py-\\[8px\\].text-\\[13px\\].font-\\[600\\].transition-all.duration-500.text-stone-400.dark\\:text-stone-500';
const selectorSection = '#root > div > main > div.mx-auto.w-full.max-w-5xl.px-0.flex.flex-col.gap-4.server-info > section';
const selector3 = '#root > div > main > div.mx-auto.w-full.max-w-5xl.px-0.flex.flex-col.gap-4.server-info > div:nth-child(3)';
const selector4 = '#root > div > main > div.mx-auto.w-full.max-w-5xl.px-0.flex.flex-col.gap-4.server-info > div:nth-child(4)';
let hasClicked = false;
let divVisible = false;
let swapping = false;
function forceBothVisible() {
  const div3 = document.querySelector(selector3);
  const div4 = document.querySelector(selector4);
  if (div3 && div4) {
    div3.style.display = 'block';
    div4.style.display = 'block';
  }
}
function hideSection() {
  const section = document.querySelector(selectorSection);
  if (section) {
    section.style.display = 'none';
  }
}
function tryClickButton() {
  const btn = document.querySelector(selectorButton);
  if (btn && !hasClicked) {
    btn.click();
    hasClicked = true;
    setTimeout(forceBothVisible, 500);
  }
}
function swapDiv3AndDiv4() {
  if (swapping) return;
  swapping = true;
  const div3 = document.querySelector(selector3);
  const div4 = document.querySelector(selector4);
  if (!div3 || !div4) {
    swapping = false;
    return;
  }
  const parent = div3.parentNode;
  if (parent !== div4.parentNode) {
    swapping = false;
    return;
  }
  parent.insertBefore(div4, div3);
  parent.insertBefore(div3, div4.nextSibling);
  swapping = false;
}
const observer = new MutationObserver(() => {
  const div3 = document.querySelector(selector3);
  const div4 = document.querySelector(selector4);

  const isDiv3Visible = div3 && getComputedStyle(div3).display !== 'none';
  const isDiv4Visible = div4 && getComputedStyle(div4).display !== 'none';

  const isAnyDivVisible = isDiv3Visible || isDiv4Visible;

  if (isAnyDivVisible && !divVisible) {
    hideSection();
    tryClickButton();
    setTimeout(swapDiv3AndDiv4, 100);
  } else if (!isAnyDivVisible && divVisible) {
    hasClicked = false;
  }
  divVisible = isAnyDivVisible;
  if (div3 && div4) {
    if (!isDiv3Visible || !isDiv4Visible) {
      forceBothVisible();
    }
  }
});
const root = document.querySelector('#root');
if (root) {
  observer.observe(root, {
    childList: true,
    attributes: true,
    subtree: true,
    attributeFilter: ['style', 'class']
  });
}
</script>

<style>
/* ========== 通用隐藏样式 ========== */
footer,
p.text-base.font-semibold,
p.text-sm.font-medium.opacity-50,
.flex.text-sm.font-medium.mt-0\.5,
[id="radix-:r0:"], [id="radix-:r2:"],
button:has(.lucide-image-minus),
button.rounded-\[50px\][aria-haspopup="dialog"],
.flex.items-center.gap-2.w-full.overflow-hidden,
.shrink-0.bg-border.mx-2.hidden.h-4.w-\[1px\].md\:block,
.text-sm.font-medium.opacity-40.md\:block {
    display: none !important;
}

/* 卡片高斯模糊 */
.bg-card\/70 {
  background-color: rgba(255, 255, 255, 0.4) !important;
  backdrop-filter: blur(25px) saturate(150%) !important;
  -webkit-backdrop-filter: blur(25px) saturate(150%) !important;
  border: 1px solid rgba(0,0,0,0) !important;
  transition: background-color .2s ease, color .2s ease, opacity .2s ease;
}

.dark .bg-card\/70 {
  background-color: rgba(0, 0, 0, 0.3) !important;
  border-color: rgba(255,255,255,.1) !important;
}


/* ========== 在线按钮默认立体毛玻璃效果 ========== */
.bg-white\/70, .bg-black\/70 {
  background-color: rgba(255, 255, 255, 0.4) !important;
  backdrop-filter: blur(25px) saturate(150%) !important;
  -webkit-backdrop-filter: blur(25px) saturate(150%) !important;
  border: 1px solid rgba(0,0,0,0) !important;
  border-radius: 9999px !important;
  transition: background-color .2s ease, color .2s ease, opacity .2s ease;
}
.dark .bg-white\/70, .dark .bg-black\/70 {
  background-color: rgba(0, 0, 0, 0.4) !important;
  border-color: rgba(255,255,255,.14) !important;
}

/* ========== 字体颜色 ========== */
.text-muted-foreground { color: black !important; }
.dark .text-muted-foreground,
.dark .text-\[10px\].text-muted-foreground {
    color: white !important;
}
.text-neutral-500,
.text-neutral-800,
.text-neutral-600 { color: black !important; }
.dark .text-neutral-500,
.dark .text-neutral-800,
.dark .text-neutral-600,
.dark .text-neutral-400,
.dark .text-neutral-300 { color: white !important; }


/* —— 进度条毛玻璃 —— */
.relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.bg-secondary.h-\[3px\].rounded-sm {
  background-color: rgba(255,255,255,0.4) !important;
  -webkit-backdrop-filter: blur(25px) saturate(150%) !important;
  backdrop-filter: blur(25px) saturate(150%) !important;
}
.dark .relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.dark .bg-secondary.h-\[3px\].rounded-sm {
  background-color: rgba(0,0,0,0.4) !important;
}
.relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:last-child,
.bg-secondary.h-\[3px\].rounded-sm > .absolute.inset-0.rounded-full:last-child {
  background: linear-gradient(90deg, #00d26a, #00b05c) !important; /* 明亮绿色渐变 */
}
.dark .relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:last-child,
.dark .bg-secondary.h-\[3px\].rounded-sm > .absolute.inset-0.rounded-full:last-child {
  background: linear-gradient(90deg, #00d26a, #00b05c) !important;
}

/* ========== 探针栏毛玻璃背景  ========== */
section.flex.items-center.cursor-pointer.text-sm.font-medium,
section.flex.items-center.cursor-pointer.sm\:text-base.text-sm.font-medium {
  background-color: rgba(255, 255, 255, 0.3) !important;
  backdrop-filter: blur(25px) saturate(150%) !important;
  -webkit-backdrop-filter: blur(325px) saturate(150%) !important;
  border: none !important;
  border-radius: 9999px !important;
  padding: 6px 12px !important;
  box-shadow: none !important;
  transition: all 0.3s ease !important;
}

/* 暗色模式下样式 */
.dark section.flex.items-center.cursor-pointer.text-sm.font-medium,
.dark section.flex.items-center.cursor-pointer.sm\:text-base.text-sm.font-medium {
  background-color: rgba(0, 0, 0, 0.4) !important;
  border-color: rgba(255, 255, 255, 0.1) !important;
}
.dark section.flex.items-center.cursor-pointer.text-sm.font-medium:hover,
.dark section.flex.items-center.cursor-pointer.sm\:text-base.text-sm.font-medium:hover {
  background-color: rgba(0, 0, 0, 0.5) !important;
  border-color: rgba(255, 255, 255, 0.4) !important;
}

/* ========== 管理后台按钮：毛玻璃 + 悬浮动画 ========== */
a[href="/dashboard"].flex.items-center.text-nowrap.text-sm.font-medium.opacity-50 {
  background-color: rgba(255, 255, 255, 0.4) !important;
  backdrop-filter: blur(25px) saturate(150%) !important;
  -webkit-backdrop-filter: blur(25px) saturate(150%) !important;
  border: none !important;
  border-radius: 9999px !important;
  padding: 6px 12px !important;
  box-shadow: none !important;
  transition: all 0.3s ease !important;
  opacity: 1 !important; /* 去除原有透明效果 */
}

</style>
<style id="hover-color-no-scale">
/* 卡片 */
.bg-card\/70:hover {
  transform: none !important;
  background-color: rgba(255, 255, 255, 0.55) !important;
}
.dark .bg-card\/70:hover {
  transform: none !important;
  background-color: rgba(0, 0, 0, 0.5) !important;
}

</style>
//去除搜索按钮
<style>
button[title="Search"] {
  display: none !important;
}

section.flex.items-center.w-full.justify-between.gap-1 {
  display: none !important;
}
</style>

