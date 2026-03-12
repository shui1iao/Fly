export default async function (ctx) {

  const raw = ctx.env.EVENTS || "考试|2026-06-01,生日|2026-08-12,新年|2027-01-01";

  const events = raw.split(",").map(e => {
    const [name, date] = e.split("|");
    return { name, date };
  });

  const now = new Date();

  function calc(event) {
    const target = new Date(event.date);
    const diff = target.getTime() - now.getTime();
    const days = Math.ceil(diff / (1000 * 60 * 60 * 24));

    return {
      name: event.name,
      date: event.date,
      days
    };
  }

  const results = events.map(calc).sort((a,b)=>a.days-b.days);

  function progress(days) {
    const total = 365;
    const passed = Math.max(0, total - days);
    return Math.min(1, passed / total);
  }

  const size = ctx.widgetFamily;

  let showCount = 1;
  if (size === "systemMedium") showCount = 2;
  if (size === "systemLarge") showCount = 4;

  const display = results.slice(0, showCount);

  const children = [];

  children.push({
    type: "text",
    text: "倒数日",
    font: { size: "headline", weight: "bold" }
  });

  for (const e of display) {

    const p = progress(e.days);

    children.push({
      type: "stack",
      direction: "column",
      gap: 4,
      children: [

        {
          type: "stack",
          direction: "row",
          children: [
            {
              type: "text",
              text: e.name
            },
            {
              type: "spacer"
            },
            {
              type: "text",
              text: `${e.days} 天`
            }
          ]
        },

        {
          type: "progress",
          value: p
        },

        {
          type: "text",
          text: e.date,
          font: { size: "caption2" }
        }

      ]
    });
  }

  return {
    type: "widget",
    url: "calshow://",
    padding: 16,
    gap: 10,
    children
  };
}
