<script>
    window.ForceUseSvgFlag=false;
    window.DisableAnimatedMan = true;
    window.FixedTopServerName = true;
    window.CustomLogo = 'https://raw.githubusercontent.com/shuijiao1/Fly/refs/heads/main/ID.png';
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

section.cursor-pointer div.bg-border, section.cursor-pointer p.opacity-40,
p.text-base.font-semibold, div.flex.items-center.gap-1:has(p.opacity-50, [data-issues-count-animation]),
section.flex.items-center.gap-2.w-full.overflow-hidden, button.rounded-\[50px\].flex.items-center.gap-1.p-\[10px\],
footer {
    display: none !important;
}


/* ========== 10. 流量信息精简：只保留 Loss ========== */
/* 隐藏下载速度 (绿色) 和 上传速度 (红色) */
div.flex.items-center.gap-2.text-\[12px\] > span.text-green-600,
div.flex.items-center.gap-2.text-\[12px\] > span.dark\:text-green-400,
div.flex.items-center.gap-2.text-\[12px\] > span.text-red-600,
div.flex.items-center.gap-2.text-\[12px\] > span.dark\:text-red-500 {
    display: none !important;
}

/* 确保剩下的 Loss 信息位置居中或对齐 (可选) */
div.flex.items-center.gap-2.text-\[12px\] {
    justify-content: flex-start; 
    gap: 0 !important;
}
</style>
