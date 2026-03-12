export default async function(ctx) {
  // 1. 解析用户传入的 JSON 事件列表
  let rawEvents = [];
  try {
    rawEvents = JSON.parse(ctx.env.EVENTS || "[]");
  } catch (e) {
    rawEvents = [{ name: "JSON格式错误", date: "2099-12-31" }];
  }
  if (rawEvents.length === 0) {
    rawEvents = [{ name: "未设置事件", date: "2099-12-31" }];
  }

  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const nowTime = now.getTime();

  // 2. 数据处理与进度计算
  const events = rawEvents.map(ev => {
    const target = new Date(ev.date);
    target.setHours(0, 0, 0, 0);
    const targetTime = target.getTime();
    
    // 核心逻辑：正数为还剩（未来），负数为已过（过去）
    const diffDays = Math.ceil((targetTime - nowTime) / (1000 * 60 * 60 * 24));
    const isPast = diffDays < 0;
    const absDays = Math.abs(diffDays);

    let progress = 0;
    if (isPast) {
      progress = 100; // 过去的事默认 100%
    } else if (ev.startDate) {
      const start = new Date(ev.startDate);
      start.setHours(0, 0, 0, 0);
      const startTime = start.getTime();
      const total = targetTime - startTime;
      const elapsed = nowTime - startTime;
      if (total > 0) {
        progress = Math.max(0, Math.min(Math.round((elapsed / total) * 100), 100));
      }
    }

    return { ...ev, diffDays, absDays, isPast, progress };
  });

  // 默认取最紧急（或最靠前）的事件作为核心展示
  const mainEvent = events[0];

  // 3. UI 积木：构建进度条 (利用 flex 弹性布局模拟)
  function buildProgressBar(progress, isPast) {
    const p1 = progress;
    const p2 = 100 - progress;
    // 快到期变红色，平时蓝色，过期灰色
    const activeColor = isPast ? "#8E8E93" : (progress > 85 ? "#FF3B30" : "#0A84FF");

    const children = [];
    if (p1 > 0) children.push({ type: "stack", flex: p1, backgroundColor: activeColor, borderRadius: 3, children: [{ type: "spacer" }] });
    if (p2 > 0) children.push({ type: "stack", flex: p2, backgroundColor: "#FFFFFF33", borderRadius: 3, children: [{ type: "spacer" }] });

    return {
      type: "stack", direction: "row", height: 6, borderRadius: 3, gap: 0, children: children
    };
  }

  // 4. UI 积木：构建列表行 (适用于中号和大号组件)
  function buildEventRow(ev) {
    const statusText = ev.isPast ? "已过" : "还剩";
    const colorText = ev.isPast ? "#8E8E93" : "#FFFFFF";
    return {
      type: "stack",
      direction: "column",
      gap: 4,
      children: [
        {
          type: "stack",
          direction: "row",
          alignItems: "center",
          children: [
            { type: "text", text: ev.name, font: { size: "subheadline", weight: "bold" }, textColor: colorText },
            { type: "spacer" },
            { type: "text", text: `${statusText} `, font: { size: "caption1" }, textColor: "#FFFFFF80" },
            { type: "text", text: `${ev.absDays}`, font: { size: "headline", weight: "bold" }, textColor: colorText },
            { type: "text", text: " 天", font: { size: "caption1" }, textColor: "#FFFFFF80" }
          ]
        },
        buildProgressBar(ev.progress, ev.isPast)
      ]
    };
  }

  // 5. 根据尺寸路由渲染
  const family = ctx.widgetFamily || "systemMedium";
  const bgGradient = { type: "linear", colors: ["#1C1C1E", "#2C2C2E"], startPoint: { x: 0, y: 0 }, endPoint: { x: 1, y: 1 } };
  
  // -- iOS 锁屏小组件 (极致精简) --
  if (family === "accessoryInline") {
    return {
      type: "widget",
      url: "calshow://", // 点击打开日历
      children: [{ type: "text", text: `${mainEvent.name} ${mainEvent.isPast ? '已过' : '剩'} ${mainEvent.absDays}天` }]
    };
  }
  
  if (family === "accessoryCircular") {
    return {
      type: "widget",
      url: "calshow://",
      children: [
        { type: "image", src: "sf-symbol:calendar", width: 16, height: 16 },
        { type: "text", text: `${mainEvent.absDays}d`, font: { size: "headline", weight: "bold" } }
      ]
    };
  }

  if (family === "accessoryRectangular") {
    return {
      type: "widget",
      url: "calshow://",
      children: [
        { type: "text", text: mainEvent.name, font: { size: "subheadline", weight: "bold" }, maxLines: 1 },
        { type: "text", text: `${mainEvent.isPast ? '已过去' : '还剩余'} ${mainEvent.absDays} 天`, font: { size: "headline", weight: "bold" } }
      ]
    };
  }

  // -- iOS 桌面小组件 --
  let desktopChildren = [];
  
  if (family === "systemSmall") {
    // 小号：只显示首个事件的巨大化视图
    desktopChildren = [
      {
        type: "stack", direction: "row", alignItems: "center", gap: 6,
        children: [
          { type: "image", src: "sf-symbol:calendar.badge.clock", color: "#0A84FF", width: 16, height: 16 },
          { type: "text", text: mainEvent.name, font: { size: "subheadline", weight: "bold" }, textColor: "#FFFFFF", maxLines: 1 }
        ]
      },
      { type: "spacer" },
      { type: "text", text: mainEvent.isPast ? "已过去" : "距离目标还有", font: { size: "caption1" }, textColor: "#FFFFFFCC" },
      {
        type: "stack", direction: "row", alignItems: "end", gap: 2,
        children: [
          { type: "text", text: `${mainEvent.absDays}`, font: { size: 36, weight: "heavy" }, textColor: "#FFFFFF" },
          { type: "text", text: "天", font: { size: "subheadline", weight: "bold" }, textColor: "#FFFFFF80" }
        ]
      },
      { type: "spacer" },
      buildProgressBar(mainEvent.progress, mainEvent.isPast)
    ];
  } else {
    // 中号/大号：显示列表。中号最多 3 个，大号最多 6 个。
    const maxItems = family === "systemLarge" ? 6 : 3;
    const displayEvents = events.slice(0, maxItems);
    
    desktopChildren = displayEvents.map(ev => buildEventRow(ev));
    
    // 如果列表没填满屏幕，用 spacer 隔开
    for (let i = 1; i < desktopChildren.length; i += 2) {
      desktopChildren.splice(i, 0, { type: "spacer", length: 12 });
    }
  }

  // 最终组装返回
  return {
    type: "widget",
    url: "calshow://", // 全局点击打开 iOS 原生日历应用
    backgroundGradient: bgGradient,
    padding: 16,
    children: [
      {
        type: "stack",
        direction: "column",
        flex: 1, // 填充整个 Widget
        children: desktopChildren
      }
    ]
  };
}
