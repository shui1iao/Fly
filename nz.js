<script>
    window.ForceUseSvgFlag=false;
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

<script>
(function() {
    // 定义核心点击逻辑
    function autoClickNetwork() {
        // 1. 寻找目标容器
        var container = document.querySelector('.server-info-tab');
        
        // 2. 如果找到了容器，并且这个容器还没被我们“处理”过
        if (container && !container.dataset.hasAutoSwitched) {
            var buttons = container.querySelectorAll('.cursor-pointer');
            
            // 3. 确保按钮存在
            if (buttons.length >= 2) {
                // 点击第二个按钮（网络）
                buttons[1].click();
                
                // 4. 给这个容器打上“已处理”的标签
                // 这样如果你手动点回“详情”，脚本看到标签就不会再强制切回去了
                container.dataset.hasAutoSwitched = "true";
                // console.log('监测到新菜单，已自动切换至网络');
            }
        }
    }

    // A. 脚本刚加载时先尝试一次
    autoClickNetwork();

    // B. 创建监听器，盯着整个页面的一举一动
    var observer = new MutationObserver(function(mutations) {
        // 页面变动时，再次尝试执行
        autoClickNetwork();
    });

    // 开始监听 (body 及其子元素的变化)
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
})();
</script>

<style>
/* ========== 简炼版自定义样式 ========== */

/* 隐藏新增的服务器状态详情栏 (CPU/Mem/Disk/TCP等) */
div.mb-2.flex.flex-wrap.items-center.gap-4 {
    display: none !important;
}

/* 1. 隐藏顶部功能按钮 (搜索、语言、主题、图片管理) */
button[title="Search"], 
button[id^="radix-:r"], 
button:has(.lucide-sun, .lucide-moon, .lucide-image-minus) {
    display: none !important;
}

/* 2. 隐藏标题栏装饰 (分隔线、哪吒监控文字) */
section.cursor-pointer div.bg-border, 
section.cursor-pointer p.opacity-40 {
    display: none !important;
}

/* 3. 隐藏内容区标题与时间行 (概览、当前时间) */
p.text-base.font-semibold, 
div.flex.items-center.gap-1:has(p.opacity-50, [data-issues-count-animation]) {
    display: none !important;
}

/* 4. 隐藏功能按钮组 (Map/Chart 蓝色按钮、Sort 排序按钮) */
section.flex.items-center.gap-2.w-full.overflow-hidden,
button.rounded-\[50px\].flex.items-center.gap-1.p-\[10px\] {
    display: none !important;
}

/* 5. 隐藏页脚 */
footer {
    display: none !important;
}

/* ========== 详情/网络 切换按钮毛玻璃化 ========== */

/* 1. 针对按钮底座（Track）应用高斯模糊 */
.server-info-tab > div {
    /* 覆盖原有的 bg-stone-100/70 */
    background-color: rgba(255, 255, 255, 0.4) !important; 
    backdrop-filter: blur(15px) saturate(150%) !important;
    -webkit-backdrop-filter: blur(15px) saturate(150%) !important;
    /* 移除原有边框或添加透明边框以对齐 */
    border: 1px solid rgba(0,0,0,0) !important; 
    box-shadow: none !important;
}

/* 2. 暗色模式适配 */
.dark .server-info-tab > div {
    /* 覆盖原有的 dark:bg-stone-800/70 */
    background-color: rgba(0, 0, 0, 0.4) !important; 
    border-color: rgba(255, 255, 255, 0.1) !important;
}

/* ========== 隐藏按钮两侧线条（保留占位） ========== */
section.flex.items-center.my-2.w-full > div.bg-border {
    background-color: transparent !important; /* 变透明，而不是 display:none */
    border: none !important;                  /* 确保没有残留边框 */
}

/* ========== 详情/网络 激活滑块毛玻璃化 ========== */

/* 1. 定位滑块：它是 server-info-tab 下面的那个 absolute 层 */
.server-info-tab div.absolute.inset-0.z-10 {
    /* 覆盖原本的 bg-white，改为半透明白色 */
    background-color: rgba(255, 255, 255, 0.3) !important; 
    
    /* 加上毛玻璃滤镜 */
    backdrop-filter: blur(15px) saturate(150%) !important;
    -webkit-backdrop-filter: blur(15px) saturate(150%) !important;
}

/* 2. 暗色模式下的滑块 */
.dark .server-info-tab div.absolute.inset-0.z-10 {
    /* 覆盖 dark:bg-stone-700 */
    background-color: rgba(0, 0, 0, 0.5) !important; 
    border-color: rgba(255, 255, 255, 0.15) !important;
}

/* ========== 详情/网络 字体全强制纯黑 ========== */
.server-info-tab p {
    color: #000000 !important;
}

/* 如果你发现未选中的文字还是灰色的，加上这一行确保容器颜色也被覆盖 */
.server-info-tab div {
    color: #000000 !important;
}

/* 卡片高斯模糊 */
.bg-card\/70 {
  background-color: rgba(255, 255, 255, 0.4) !important;
  backdrop-filter: blur(15px) saturate(150%) !important;
  -webkit-backdrop-filter: blur(15px) saturate(150%) !important;
  border: 1px solid rgba(0,0,0,0) !important;
  transition: background-color .2s ease, color .2s ease, opacity .2s ease;
}

.dark .bg-card\/70 {
  background-color: rgba(0, 0, 0, 0.4) !important;
  border-color: rgba(255,255,255,.1) !important;
}

/* ========== 在线按钮默认立体毛玻璃效果 ========== */

.bg-white\/70, .bg-black\/70 {

  background-color: rgba(255, 255, 255, 0.4) !important;

  backdrop-filter: blur(15px) saturate(150%) !important;

  -webkit-backdrop-filter: blur(15px) saturate(150%) !important;

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


/* —— 进   条毛������ —— */
.relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.bg-secondary.h-\[3px\].rounded-sm {
  background-color: rgba(255,255,255,0.4) !important;
  -webkit-backdrop-filter: blur(15px) saturate(150%) !important;
  backdrop-filter: blur(15px) saturate(150%) !important;
}
.dark .relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.dark .bg-secondary.h-\[3px\].rounded-sm {
  background-color: rgba(0,0,0,0.4) !important;
}
.relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:last-child,
.bg-secondary.h-\[3px\].rounded-sm > .absolute.inset-0.rounded-full:last-child {
  background: linear-gradient(90deg, #00d26a, #00b05c) !important; /* 明   绿色渐变 */
}
.dark .relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:last-child,
.dark .bg-secondary.h-\[3px\].rounded-sm > .absolute.inset-0.rounded-full:last-child {
  background: linear-gradient(90deg, #00d26a, #00b05c) !important;
}

/* ========== 探针栏毛玻璃背景 ========== */
section.flex.items-center.cursor-pointer.text-sm.font-medium,
section.flex.items-center.cursor-pointer.sm\:text-base.text-sm.font-medium {
  background-color: rgba(255, 255, 255, 0.4) !important;
  backdrop-filter: blur(15px) saturate(150%) !important;
  -webkit-backdrop-filter: blur(15px) saturate(150%) !important;
  border: none !important;
  border-radius: 9999px !important;
  padding: 6px 12px !important;
  box-shadow: none !important;
  transition: all 0.3s ease !important;
}

/* ========== 亮色模式���悬停变    ========== */
section.flex.items-center.cursor-pointer.text-sm.font-medium:hover,
section.flex.items-center.cursor-pointer.sm\:text-base.text-sm.font-medium:hover {
  background-color: rgba(255, 255, 255, 0.55) !important; /* 亮一点，与卡片一致 */
  border-color: rgba(0, 0, 0, 0) !important;
}

/* ========== 暗色模式下样式 ========== */
.dark section.flex.items-center.cursor-pointer.text-sm.font-medium,
.dark section.flex.items-center.cursor-pointer.sm\:text-base.text-sm.font-medium {
  background-color: rgba(0, 0, 0, 0.4) !important;
  border-color: rgba(255, 255, 255, 0.1) !important;
}

/* ========== 暗色模式下悬停变亮 ========== */
.dark section.flex.items-center.cursor-pointer.text-sm.font-medium:hover,
.dark section.flex.items-center.cursor-pointer.sm\:text-base.text-sm.font-medium:hover {
  background-color: rgba(0, 0, 0, 0.5) !important; /* 与卡片一致 */
  border-color: rgba(255, 255, 255, 0.4) !important;
}

/* ========== 管理后台按钮：毛玻璃 + 悬停变亮 ========== */
a[href="/dashboard"].flex.items-center.text-nowrap.text-sm.font-medium.opacity-50 {
  background-color: rgba(255, 255, 255, 0.4) !important;
  backdrop-filter: blur(15px) saturate(150%) !important;
  -webkit-backdrop-filter: blur(15px) saturate(150%) !important;
  border: none !important;
  border-radius: 9999px !important;
  padding: 6px 12px !important;
  box-shadow: none !important;
  transition: all 0.3s ease !important;
  opacity: 1 !important; /* 去除原有透明效果 */
}

.dark a[href="/dashboard"].flex.items-center.text-nowrap.text-sm.font-medium.opacity-50 {
  background-color: rgba(0, 0, 0, 0.4) !important;
  border: 1px solid rgba(255, 255, 255, 0.1) !important;
  color: white !important;
}

/* 亮色模式下悬停变亮 */
a[href="/dashboard"].flex.items-center.text-nowrap.text-sm.font-medium.opacity-50:hover {
  background-color: rgba(255, 255, 255, 0.55) !important;
}

/* 暗色模式下悬停变亮 */
.dark a[href="/dashboard"].flex.items-center.text-nowrap.text-sm.font-medium.opacity-50:hover {
  background-color: rgba(0, 0, 0, 0.5) !important;
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
