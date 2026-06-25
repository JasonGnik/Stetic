// POST /read-split — transcribe a photo of a written/screenshotted workout routine
// into clean text, so onboarding can prefill "your current split". Auth required but
// NOT entitlement-gated (it runs pre-paywall, as a conversion investment). Cheap Flash.
//
// Body: { image: { mimeType: string, dataB64: string } }

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
  if (!GEMINI_API_KEY) return json({ error: "server misconfigured" }, 500);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "unauthorized" }, 401);

  let payload: { image?: { mimeType: string; dataB64: string } };
  try { payload = await req.json(); } catch { return json({ error: "invalid json" }, 400); }
  const image = payload.image;
  if (!image?.dataB64 || !image?.mimeType) return json({ error: "no image" }, 400);

  const prompt =
    `This image shows someone's workout routine / training split (handwritten, a notes app, ` +
    `or a screenshot). Transcribe it into clean, concise plain text that captures the structure: ` +
    `which days train which muscles, the exercises, and sets/reps if shown. Keep it short and ` +
    `readable — no commentary, just the routine. If it's unreadable or not a workout, return an empty string.`;

  const body = {
    contents: [{ role: "user", parts: [{ text: prompt }, { inlineData: { mimeType: image.mimeType, data: image.dataB64 } }] }],
    generationConfig: { temperature: 0.1 },
  };
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`;

  try {
    const res = await fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
    if (!res.ok) throw new Error(`Gemini ${res.status}`);
    const data = await res.json();
    const text = (data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();
    return json({ text });
  } catch (e) {
    console.error("read-split failed:", e);
    return json({ error: "could not read the photo" }, 502);
  }
});
