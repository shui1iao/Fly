export default async function(ctx) {
  // 1. 解析环境变量数据
  let events = [];
  try {
    events = JSON.parse(ctx.env.EVENTS || "[]");
  } catch (e) {
    events = [];
  }

  // 补齐数据，防止用户填写的数量不足导致渲染报错
  while (events.length < 7) {
    events.push({ name: "未设置", date: "2099-12-31" });
  }

  // 2. 日期计算引擎
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const nowTime = now.getTime();

  const processedEvents = events.map(ev => {
    const target = new Date(ev.date);
    target.setHours(0, 0, 0, 0);
    
    const diffDays = Math.ceil((target.getTime() - nowTime) / (1000 * 60 * 60 * 24));
    return {
      name: ev.name,
      absDays: Math.abs(diffDays),
      isPast: diffDays < 0
    };
  });

  const mainEvent = processedEvents[0];
  const gridEvents = processedEvents.slice(1, 7); // 取后 6 个放入网格

  // 3. UI 积木：构建单个胶囊格子
  function buildCell(ev) {
    return {
      type: "stack",
      direction: "row",
      flex: 1, // 让一行内的两个格子平分宽度
      backgroundColor: "#FFFFFF15", // 半透明的白底，模拟毛玻璃胶囊
      borderRadius: 16, // 圆角
      padding: [8, 12], // 上下 8，左右 12
      alignItems: "center",
      children: [
        {
          type: "text",
          text: ev.name,
          font: { size: 12, weight: "medium" },
          textColor: "#FFFFFF99", // 灰色文字
          maxLines: 1
        },
        { type: "spacer" },
        {
          type: "stack",
          direction: "row",
          alignItems: "end",
          gap: 2,
          children: [
            {
              type: "text",
              text: String(ev.absDays),
              font: { size: 16, weight: "bold" },
              textColor: "#FFFFFF" // 白色数字
            },
            {
              type: "text",
              text: "天",
              font: { size: 10, weight: "medium" },
              textColor: "#FFFFFF99",
              padding: [0, 0, 2, 0] // 微调“天”字的底部对齐
            }
          ]
        }
      ]
    };
  }

  // 4. UI 积木：构建网格行（每行两个格子）
  function buildGridRow(ev1, ev2) {
    return {
      type: "stack",
      direction: "row",
      gap: 10, // 两个胶囊之间的间距
      children: [
        buildCell(ev1),
        buildCell(ev2)
      ]
    };
  }

  // 5. 组装全局 DSL
  return {
    type: "widget",
    url: "calshow://", // 全局点击打开日历
    backgroundGradient: {
      type: "linear",
      colors: ["#232252", "#3735B3"], // 提取自原图的深蓝紫渐变
      startPoint: { x: 0, y: 0 },
      endPoint: { x: 1, y: 1 }
    },
    padding: 16,
    children: [
      // 第一层：顶部 Title 和 时间
      {
        type: "stack",
        direction: "row",
        alignItems: "center",
        children: [
          {
            type: "text",
            text: "✨ 2026 LIFE DASHBOARD",
            font: { size: 11, weight: "bold" },
            textColor: "#FFFFFF80"
          },
          { type: "spacer" },
          // 这里使用 Egern 的 date 类型直接渲染时间，无需反复执行脚本
          {
            type: "date",
            date: new Date().toISOString(),
            format: "time",
            font: { size: 14, weight: "medium" },
            textColor: "#FFFFFF80"
          }
        ]
      },
      
      { type: "spacer", length: 12 },

      // 第二层：主打大事件
      {
        type: "stack",
        direction: "row",
        alignItems: "end", // 底部对齐
        children: [
          {
            type: "text",
            text: mainEvent.name,
            font: { size: 18, weight: "bold" },
            textColor: "#FFD60A" // 类似图片中的亮黄色
          },
          { type: "spacer" },
          {
            type: "text",
            text: String(mainEvent.absDays),
            font: { size: 48, weight: "heavy" }, // 超大数字
            textColor: "#FFFFFF"
          },
          {
            type: "text",
            text: " 天",
            font: { size: 12, weight: "medium" },
            textColor: "#FFFFFF80",
            padding: [0, 0, 8, 4] // 微调对齐，让“天”字靠下
          }
        ]
      },

      { type: "spacer", length: 16 },

      // 第三层：下方的胶囊网格（2列3行）
      {
        type: "stack",
        direction: "column",
        gap: 8, // 每行之间的上下间距
        children: [
          buildGridRow(gridEvents[0], gridEvents[1]),
          buildGridRow(gridEvents[2], gridEvents[3]),
          buildGridRow(gridEvents[4], gridEvents[5])
        ]
      }
    ]
  };
}
