<script>
    window.ShowNetTransfer=true;
    window.CustomBackgroundImage = 'https://raw.githubusercontent.com/shuijiao1/Fly/refs/heads/main/PC_Wallpaper.JPG';
    window.CustomMobileBackgroundImage = 'https://raw.githubusercontent.com/shuijiao1/Fly/refs/heads/main/Mobile_Wallpaper.JPG';
    window.CustomLogo = 'https://raw.githubusercontent.com/shuijiao1/Fly/refs/heads/main/ID.PNG';
    window.DisableAnimatedMan = true;
    window.FixedTopServerName = true;
</script>
/* 周期性流量进度条 */
<script>
  window.TrafficScriptConfig = {
    showTrafficStats: true,    // 显示流量统计, 默认开启
    insertAfter: true,         // 如果开启总流量卡片, 是否放置在总流量卡片后面, 默认为true
    interval: 60000,           // 60秒刷新缓存, 单位毫秒, 默认60秒
    toggleInterval: 0,      // 4秒切换流量进度条右上角内容, 0秒不切换, 单位毫秒, 默认5秒
    duration: 500,             // 缓出缓进切换时间, 单位毫秒, 默认500毫秒
    enableLog: false           // 开启日志, 默认关闭
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
/* ====================================
   通用样式与隐藏部分
   ==================================== */
.dark .bg-cover::after {
    content: '';
    position: absolute;
    inset: 0;
    /* 这里的blur(0px)是冗余的，但保留以防万一 */
    backdrop-filter: blur(0px);
    background-color: rgba(0, 0, 0, 0.1);
}
.light .bg-cover::after {
    content: '';
    position: absolute;
    inset: 0;
    backdrop-filter: blur(0px);
    background-color: rgba(255, 255, 255, 0.1);
}

/* 隐藏页面底部的页脚 */
footer {
    display: none;
}

/* 隐藏 “overview” 和 “time is” 文本 */
p.text-base.font-semibold,
p.text-sm.font-medium.opacity-50 {
    display: none !important;
}

/* 隐藏大时间显示 */
.flex.text-sm.font-medium.mt-0\.5 {
    display: none !important;
}

/* 隐藏右上角语言切换和主题切换按钮 */
[id="radix-:r0:"], [id="radix-:r2:"] {
    display: none;
}

/* 隐藏右下角的图片按钮和弹窗按钮 */
button:has(.lucide-image-minus), button.rounded-\[50px\][aria-haspopup="dialog"] {
    display: none !important;
}

/* 隐藏三个按钮和“All”标签的区域 */
.flex.items-center.gap-2.w-full.overflow-hidden {
    display: none !important;
}

/* 隐藏“哪吒监控”文字和前面的分隔线 */
.shrink-0.bg-border.mx-2.hidden.h-4.w-\[1px\].md\:block,
.text-sm.font-medium.opacity-40.md\:block {
    display: none !important;
}

/* ====================================
   毛玻璃效果
   ==================================== */
.card-3d-wrap {
    perspective: 1200px;
    perspective-origin: 50% 35%;
}

/* 🌤 通用毛玻璃卡片样式：适配所有 bg-card 类 */
[class*="bg-card"] {
    background-color: rgba(255, 255, 255, 0.5) !important;
    backdrop-filter: blur(18px) saturate(180%);
    -webkit-backdrop-filter: blur(18px) saturate(180%);
    border-radius: 18px;
    border: 1px solid rgba(255, 255, 255, 0.2);
    transition: all 0.3s ease;
    position: relative;
    overflow: hidden;
}

/* 🌙 暗色模式支持 */
.dark [class*="bg-card"] {
    background-color: rgba(30, 30, 30, 0.25) !important;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

/* 🖱 鼠标悬停时的选中效果 */
[class*="bg-card"]:hover {
    transform: scale(1.02);
    cursor: pointer;
}

/* 为“在线”按钮添加高斯模糊效果，并统一亮暗色模式下的样式 */
.bg-white\/70,
.dark .bg-black\/70 {
    background-color: rgba(255, 255, 255, 0.5) !important;
    backdrop-filter: blur(12px) saturate(180%) !important;
    -webkit-backdrop-filter: blur(12px) saturate(180%) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
}
.dark .bg-white\/70 {
    background-color: rgba(30, 30, 30, 0.25) !important;
    border: 1px solid rgba(255, 255, 255, 0.1) !important;
}

/* 字体颜��� */
/* �����������色模式下，将这些文字颜色设置为黑色 */
.text-muted-foreground {
    color: black !important;
}
/* 暗色模式下，将文字颜色设置为白色 */
.dark .text-muted-foreground,
.dark .text-\[10px\].text-muted-foreground {
    color: white !important;
}

/* 统一上传标签的样式，使其背景透明并与下载标签边框颜色一致 */
.inline-flex.border-muted-50 {
    background-color: transparent !important;
    border: 1px solid !important;
}
.light .inline-flex.border-muted-50 {
    border-color: #e5e7eb !important;
}
.dark .inline-flex.border-muted-50 {
    border-color: #374151 !important;
}

/* 统一进度条背景的样式，添加高斯模糊 */
.relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.bg-secondary.h-\[3px\].rounded-sm {
    background-color: rgba(255, 255, 255, 0.5) !important;
    backdrop-filter: blur(18px) saturate(180%) !important;
    -webkit-backdrop-filter: blur(18px) saturate(180%) !important;
}
/* 暗色模式下统一背景 */
.dark .relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.dark .bg-secondary.h-\[3px\].rounded-sm {
    background-color: rgba(30, 30, 30, 0.25) !important;
}
</style><style>
/* 通用样式与隐藏部分 */
.dark .bg-cover::after {
    content: '';
    position: absolute;
    inset: 0;
    backdrop-filter: blur(0px);
    background-color: rgba(0, 0, 0, 0.1);
}
.light .bg-cover::after {
    content: '';
    position: absolute;
    inset: 0;
    backdrop-filter: blur(0px);
    background-color: rgba(255, 255, 255, 0.1);
}
/* 隐藏页面底部的页脚 */
footer {
    display: none;
}
/* 隐藏 “overview” 和 “time is” 文本 */
p.text-base.font-semibold,
p.text-sm.font-medium.opacity-50 {
    display: none !important;
}
/* 隐藏时间显示 */
.flex.text-sm.font-medium.mt-0\.5 {
    display: none !important;
}
/* 隐藏右上角语言切换和主题切换按钮 */
[id="radix-:r0:"], [id="radix-:r2:"] {
    display: none;
}
/* 隐藏右下角的图片按钮和弹窗按钮 */
button:has(.lucide-image-minus), button.rounded-\[50px\][aria-haspopup="dialog"] {
    display: none !important;
}
/* 隐藏三个按钮和“All”标签的区域 */
.flex.items-center.gap-2.w-full.overflow-hidden {
    display: none !important;
}
/* 隐藏“哪吒监控”文字和前面的分隔线 */
.shrink-0.bg-border.mx-2.hidden.h-4.w-\[1px\].md\:block,
.text-sm.font-medium.opacity-40.md\:block {
    display: none !important;
}
</style>

<style>
/* 毛玻璃效果 */
.card-3d-wrap {
    perspective: 1200px;
    perspective-origin: 50% 35%;
}
/* 通用毛玻璃卡片样式：适配所有 bg-card 类 */
[class*="bg-card"] {
    background-color: rgba(255, 255, 255, 0.5) !important;
    backdrop-filter: blur(18px) saturate(180%);
    -webkit-backdrop-filter: blur(18px) saturate(180%);
    border-radius: 18px;
    border: 1px solid rgba(255, 255, 255, 0.2);
    transition: all 0.3s ease;
    position: relative;
    overflow: hidden;
}

/* 暗色模式支持 */
.dark [class*="bg-card"] {
    background-color: rgba(30, 30, 30, 0.25) !important;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

/* 鼠标悬停时的选中效果 */
[class*="bg-card"]:hover {
    transform: scale(1.02);
    cursor: pointer;
}

/* 亮色：保持原样 */
.bg-white\/70 {
  background-color: rgba(255, 255, 255, 0.5) !important;
  backdrop-filter: blur(12px) saturate(180%) !important;
  -webkit-backdrop-filter: blur(12px) saturate(180%) !important;
  border: 1px solid rgba(255, 255, 255, 0.2) !important;
}

/* 暗色：无论徽章是 .bg-white/70 还是 .bg-black/70，都统一覆盖为暗色毛玻璃 */
html.dark .bg-white\/70,
body.dark .bg-white\/70,
.dark .bg-white\/70,
html.dark .bg-black\/70,
body.dark .bg-black\/70,
.dark .bg-black\/70,
html[data-theme="dark"] .bg-white\/70,
html[data-theme="dark"] .bg-black\/70 {
  background-color: rgba(30, 30, 30, 0.25) !important;
  backdrop-filter: blur(12px) saturate(180%) !important;
  -webkit-backdrop-filter: blur(12px) saturate(180%) !important;
  border: 1px solid rgba(255, 255, 255, 0.1) !important;
}
/* 可选：暗色下提高文字对比度（如果里面用了这个类名） */
.dark .bg-white\/70 .text-muted-foreground,
.dark .bg-black\/70 .text-muted-foreground {
  color: #fff !important;
}
/* 针对亮色模式，将文字颜色设置为黑色 */
.text-muted-foreground {
    color: black !important;
}
/* 在暗色模式下，将文字颜色设置为白色 */
.dark .text-muted-foreground,
.dark .text-\[10px\].text-muted-foreground {
    color: white !important;
｝
}
/* 亮色和暗色模式下，为上传标签设���正确的边框颜色 */
.inline-flex.border-muted-50 {
    /* 强制去除背景色 */
    background-color: transparent !important;
    /* 确保边框存在，颜色在下面根据模式定义 */
    border: 1px solid !important;
}
/* 亮色模式下，边框颜色与下载标签一致 */
.light .inline-flex.border-muted-50 {
    border-color: #e5e7eb !important;
}
/* 暗色模式下，边框颜色与下载标签一致 */
.dark .inline-flex.border-muted-50 {
    border-color: #374151 !important;
}
/* 针对所有进度条的背景，添加高斯模糊效果 */
.bg-secondary.h-\[3px\].rounded-sm {
    /* 为亮色模式设置半透明白色背景，以便高斯模糊效果可见 */
    background-color: rgba(255, 255, 255, 0.5) !important;
    /* 应用高斯模糊效果 */
    backdrop-filter: blur(18px) saturate(180%);
    -webkit-backdrop-filter: blur(18px) saturate(180%);
}
/* 确保在暗色模式下，背景为半透明的深色 */
.dark .bg-secondary.h-\[3px\].rounded-sm {
    background-color: rgba(30, 30, 30, 0.25) !important;
}
/* 流量条轨道高斯模糊（最小覆盖，不改高度） */
.relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.bg-secondary.h-\[3px\].rounded-sm {
  background-color: rgba(255, 255, 255, 0.5) !important;
  backdrop-filter: blur(18px) saturate(180%) !important;
  -webkit-backdrop-filter: blur(18px) saturate(180%) !important;
}
/* 暗色模式 */
.dark .relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.dark .bg-secondary.h-\[3px\].rounded-sm {
  background-color: rgba(30, 30, 30, 0.25) !important;
}
/* 亮色模式下，将流量数据文本颜色改为黑色 */
.text-neutral-500,
.text-neutral-800,
.text-neutral-600 {
    color: black !important;
}
/* 暗色模式下，将流量数据文本颜色改为白色 */
.dark .text-neutral-500,
.dark .text-neutral-800,
.dark .text-neutral-600 {
    color: white !important;
}
/* 确保暗色模式下，text-neutral-400 和 text-neutral-300 也变为白色 */
.dark .text-neutral-400,
.dark .text-neutral-300 {
    color: white !important;
}
</style>
