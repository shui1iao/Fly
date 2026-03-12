export default async function(ctx) {
  // 从配置文件的 env 中读取用户填写的变量，提供默认值防错
  const targetName = ctx.env.TARGET_NAME || "目标日";
  const targetDateStr = ctx.env.TARGET_DATE || "2026-01-01";

  // 日期计算逻辑（抹平时间误差，只算天数）
  const now = new Date();
  const target = new Date(targetDateStr);
  now.setHours(0, 0, 0, 0);
  target.setHours(0, 0, 0, 0);

  const diffTime = target.getTime() - now.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  const absDays = Math.abs(diffDays).toString();

  // 状态变量初始化
  let titleText = "🗓️ 倒数日";
  let descText = "";
  let iconName = "calendar";
  let bgColors = ["#1A1A2E", "#16213E"]; // 默认深色渐变

  // 核心分支判断：未到、当天、已过期
  if (diffDays > 0) {
    descText = `距离 ${targetName} 还有`;
    iconName = "clock.fill";
    bgColors = ["#FF512F", "#F09819"]; // 橙色渐变
  } else if (diffDays === 0) {
    descText = `就是今天！`;
    titleText = targetName;
    iconName = "star.fill";
    bgColors = ["#11998e", "#38ef7d"]; // 绿色渐变
  } else {
    descText = `${targetName} 已过去`;
    iconName = "clock.badge.checkmark.fill";
    bgColors = ["#3a6073", "#16222A"]; // 蓝灰渐变
  }

  // 严格返回 Egern 支持的 Widget DSL JSON
  return {
    type: "widget",
    backgroundGradient: {
      type: "linear",
      colors: bgColors,
      startPoint: { x: 0, y: 0 },
      endPoint: { x: 1, y: 1 }
    },
    padding: 16,
    children: [
      // 顶部：图标 + 标题
      {
        type: "stack",
        direction: "row",
        alignItems: "center",
        gap: 6,
        children: [
          {
            type: "image",
            src: `sf-symbol:${iconName}`,
            color: "#FFFFFF",
            width: 18,
            height: 18
          },
          {
            type: "text",
            text: titleText,
            font: { size: "headline", weight: "bold" },
            textColor: "#FFFFFF"
          }
        ]
      },
      // 弹性空白，将内容推向两端
      { type: "spacer" },
      // 描述文本
      {
        type: "text",
        text: descText,
        font: { size: "subheadline", weight: "medium" },
        textColor: "#FFFFFFCC"
      },
      // 底部：巨大数字 + "天"
      {
        type: "stack",
        direction: "row",
        alignItems: "end", // 底部对齐，让"天"字和数字底部平齐
        gap: 4,
        children: [
          {
            type: "text",
            text: diffDays === 0 ? "0" : absDays,
            font: { size: 42, weight: "heavy" }, 
            textColor: "#FFFFFF"
          },
          {
            type: "text",
            text: "天",
            font: { size: "headline", weight: "bold" },
            textColor: "#FFFFFFCC"
          }
        ]
      }
    ]
  };
}
