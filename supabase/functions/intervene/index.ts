Deno.serve(async (req) => {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    });

  try {
    const { app, minutes, task, title } = await req.json();

    // Keep inputs short and plain so nobody can stuff huge text into your prompt.
    const appName = String(app ?? "a distracting app").slice(0, 60);
    const mins = Math.min(Number(minutes) || 0, 600);
    const nextTask = String(task ?? "").slice(0, 200) || "something important";
    const userTitle = String(title ?? "").slice(0, 40);

    const system =
      "You are a sassy pet guardian helping a human stop doom scrolling. " +
      "Reply with exactly 2 short sentences: a funny reality check, then a nudge back to work. " +
      "Use the real details you are given, never placeholders in brackets. " +
      "No emojis, no hashtags, no cruelty about appearance or identity.";

    const user =
      `The user has been on ${appName} for ${mins} minutes. ` +
      `Their next task is: ${nextTask}. ` +
      (userTitle ? `Address them by their current title: "${userTitle}".` : "");

    console.log("PROMPT:", user);

    const res = await fetch(`${Deno.env.get("LLM_BASE_URL")}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${Deno.env.get("LLM_API_KEY")}`,
      },
      body: JSON.stringify({
        model: Deno.env.get("LLM_MODEL"),
        max_tokens: 120,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
      }),
    });

    if (!res.ok) return json({ error: `LLM error ${res.status}` }, 502);

    const data = await res.json();
    const roast = data.choices?.[0]?.message?.content?.trim();
    return json({ roast: roast || "Put the phone down. Now." });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});