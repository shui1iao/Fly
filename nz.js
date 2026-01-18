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
/* ========== 1. 元素隐藏模块 (清理 UI) ========== */
div.mb-2.flex.flex-wrap.items-center.gap-4,
button[title="Search"], button[id^="radix-:r"], button:has(.lucide-sun, .lucide-moon, .lucide-image-minus),
section.cursor-pointer div.bg-border, section.cursor-pointer p.opacity-40,
p.text-base.font-semibold, div.flex.items-center.gap-1:has(p.opacity-50, [data-issues-count-animation]),
section.flex.items-center.gap-2.w-full.overflow-hidden, button.rounded-\[50px\].flex.items-center.gap-1.p-\[10px\],
footer {
    display: none !important;
}

/* ========== 2. 精准字体与元素颜色控制 (浅黑深铂金) ========== */
/* 浅色模式：文字、开关圆点、图标纯黑 */
p, span, a, div, button,
.text-muted-foreground, .text-neutral-500, .text-neutral-400,
.recharts-text, .recharts-cartesian-axis-tick-value,
img[alt="BackIcon"] { /* 修复返回图标颜色 */
    color: #000000 !important;
}
.recharts-text tspan, .recharts-cartesian-axis-tick-value {
    fill: #000000 !important;
}
/* 开关圆点 - 浅色模式 */
button[role="switch"] span {
    background-color: #000000 !important;
}

/* 深色模式：改为柔和的铂金色 (#E5E5E5) */
.dark p, .dark span, .dark a, .dark div, .dark button,
.dark .text-muted-foreground, .dark .text-neutral-500,
.dark .recharts-text, .dark .recharts-cartesian-axis-tick-value,
.dark img[alt="BackIcon"] { /* 修复返回图标颜色 */
    color: #e5e5e5 !important; 
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.5) !important;
}
.dark .recharts-text tspan, .dark .recharts-cartesian-axis-tick-value {
    fill: #e5e5e5 !important;
}
/* 开关圆点 - 深色模式同步铂金色 */
.dark button[role="switch"] span {
    background-color: #e5e5e5 !important;
    box-shadow: 0 0 8px rgba(255, 255, 255, 0.2);
}

/* ========== 3. 开关组件 (Switch - 玻璃质感) ========== */
button[role="switch"] {
    background-color: rgba(255, 255, 255, 0.05) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
    backdrop-filter: blur(10px) saturate(120%) !important;
    -webkit-backdrop-filter: blur(10px) saturate(120%) !important;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.05) !important;
    transition: all 0.3s ease !important;
}

button[role="switch"][data-state="checked"] {
    background-color: rgba(255, 255, 255, 0.15) !important;
}

.dark button[role="switch"] {
    background-color: rgba(0, 0, 0, 0.05) !important;
}
.dark button[role="switch"][data-state="checked"] {
    background-color: rgba(255, 255, 255, 0.1) !important;
}

/* ========== 4. 服务器卡片 (Cards) ========== */
[class*="bg-card"], .bg-card\/70 {
    background-color: rgba(255, 255, 255, 0.05) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
    backdrop-filter: blur(10px) saturate(120%) !important;
    -webkit-backdrop-filter: blur(10px) saturate(120%) !important;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.05) !important;
    border-radius: 16px !important;
    transition: background-color 0.3s ease, box-shadow 0.3s ease !important;
}

.dark [class*="bg-card"], .dark .bg-card\/70 {
    background-color: rgba(0, 0, 0, 0.05) !important;
}

/* 卡片悬停反馈 */
[class*="bg-card"]:hover, .bg-card\/70:hover { 
    background-color: rgba(255, 255, 255, 0.3) !important; 
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08) !important;
}
.dark [class*="bg-card"]:hover, .dark .bg-card\/70:hover { background-color: rgba(255, 255, 255, 0.08) !important; }

/* ========== 5. 管理后台按钮 (Dashboard) ========== */
body a[href="/dashboard"] {
    opacity: 1 !important;
    background-color: rgba(255, 255, 255, 0.05) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
    backdrop-filter: blur(10px) saturate(120%) !important;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.05) !important;
    border-radius: 9999px !important;
    padding: 6px 14px !important;
    min-height: 32px !important;
    display: flex !important;
    align-items: center !important;
    transition: all 0.25s ease-in-out !important;
}
.dark body a[href="/dashboard"] { background-color: rgba(0, 0, 0, 0.05) !important; }
body a[href="/dashboard"]:hover { background-color: rgba(255, 255, 255, 0.3) !important; }

/* ========== 6. 在线状态按钮 (Online Status) ========== */
button.bg-white\/70, 
button.dark\:bg-black\/70 {
    background-color: rgba(255, 255, 255, 0.05) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
    backdrop-filter: blur(10px) saturate(120%) !important;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.05) !important;
    border-radius: 9999px !important;
    padding: 2px 8px !important;
}
.dark button.bg-white\/70, .dark button.dark\:bg-black\/70 { background-color: rgba(0, 0, 0, 0.05) !important; }

/* ========== 7. 探针列表栏 (Probe Bars) ========== */
section.flex.items-center.cursor-pointer.text-sm, 
section.flex.items-center.cursor-pointer.sm\:text-base {
    background-color: rgba(255, 255, 255, 0.05) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
    backdrop-filter: blur(10px) saturate(120%) !important;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.05) !important;
    border-radius: 9999px !important;
    padding: 6px 14px !important;
}
.dark section.flex.items-center.cursor-pointer { background-color: rgba(0, 0, 0, 0.05) !important; }

/* ========== 8. 切换座与进度条轨道 ========== */
.server-info-tab > div {
    background-color: rgba(255, 255, 255, 0.05) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
    backdrop-filter: blur(10px) saturate(120%) !important;
}
.dark .server-info-tab > div { background-color: rgba(0, 0, 0, 0.05) !important; }

.relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.bg-secondary.h-\[3px\].rounded-sm {
    background-color: rgba(255, 255, 255, 0.05) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
    backdrop-filter: blur(10px) saturate(120%) !important;
}
.dark .relative[class*="h-1.5"] > .absolute.inset-0.rounded-full:first-child,
.dark .bg-secondary.h-\[3px\].rounded-sm { background-color: rgba(0, 0, 0, 0.05) !important; }

/* 装饰细节 */
.server-info-tab div.absolute.inset-0.z-10 { background-color: rgba(255, 255, 255, 0.2) !important; }
section.flex.items-center.my-2.w-full > div.bg-border { background-color: transparent !important; border: none !important; }
</style>

<script>
    // 强制探针默认开启深色模式
    (function() {
        document.documentElement.classList.add('dark');
        localStorage.setItem('theme', 'dark');
    })();
</script>
