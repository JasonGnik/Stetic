// POST /craving — "I'm craving X" → a version tuned to how badly they want it,
// that still respects the day's macros (80/20). Returns the food + realistic macros
// + a fit tip + small adjustments to other meals. Auth required.
//
// Body: { craving, intensity: "lightly"|"mildly"|"badly", goal,
//         remaining: {calories,protein_g,carbs_g,fat_g}, target: {...} }
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...CORS, "content-type": "application/json" } });

const MODEL = "gemini-2.5-flash";
const SCHEMA = {
  type: "object",
  properties: {
    name: { type: "string" },
    version: { type: "string" },      // which take this is, e.g. "The real thing" / "Lighter homemade" / "Macro-friendly"
    portion: { type: "string" },
    calories: { type: "number" },
    protein_g: { type: "number" },
    carbs_g: { type: "number" },
    fat_g: { type: "number" },
    ingredients: { type: "array", items: { type: "string" } },  // what's in it / how to make it
    fits_today: { type: "boolean" },   // does it realistically fit the remaining calories?
    verdict: { type: "string" },       // honest one-liner about today
    adjustments: { type: "array", items: { type: "string" } }, // if it fits: tweaks to other meals to make room
    tomorrow_plan: { type: "array", items: { type: "string" } }, // if it doesn't: how to budget for it tomorrow, per meal
    fit_tip: { type: "string" },       // 80/20 framing
  },
  required: ["name", "version", "calories", "protein_g", "carbs_g", "fat_g", "ingredients", "fits_today", "verdict", "fit_tip"],
} as const;

const INTENSITY: Record<string, string> = {
  badly: "They want it BADLY — give them the ACTUAL thing they're craving (the real, restaurant/indulgent version, e.g. an In-N-Out-style cheeseburger). Realistic indulgent macros. Don't sanitize it; help them fit it in instead.",
  mildly: "They want it MILDLY — give a lighter HOMEMADE version of it (e.g. a homemade burger with a leaner build). Still satisfying, moderately lighter macros.",
  lightly: "They want it LIGHTLY — give a HEALTHY, macro-friendly remake (e.g. a burger bowl). Hit the craving's flavor with much lighter macros.",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const KEY = Deno.env.get("GEMINI_API_KEY");
  if (!KEY) return json({ error: "server misconfigured" }, 500);

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: u, error: e } = await supabase.auth.getUser();
  if (e || !u?.user) return json({ error: "unauthorized" }, 401);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "invalid json" }, 400); }
  const craving = String(body.craving ?? "").trim();
  if (!craving) return json({ error: "no craving" }, 400);
  const intensity = INTENSITY[body.intensity] ?? INTENSITY.mildly;
  const remaining = body.remaining ?? {};
  const goal = String(body.goal ?? "stay on track");

  const remCal = Math.round(remaining.calories ?? 0);
  const dayTarget = Math.round(body.target?.calories ?? 0);
  const prompt =
    `The user is craving "${craving}". Goal: ${goal}. ${intensity} ` +
    `They have ~${remCal} kcal left TODAY (out of a ${dayTarget || "?"} kcal daily target), with ` +
    `~${Math.round(remaining.protein_g ?? 0)}g protein, ~${Math.round(remaining.carbs_g ?? 0)}g carbs, ~${Math.round(remaining.fat_g ?? 0)}g fat left. ` +
    `Name the specific food, a 'version' label, a realistic portion, and realistic macros for one serving. ` +
    `List 'ingredients' (3-7 items, how it's actually made — e.g. "5oz lean ground beef", "1 brioche bun", "lettuce, tomato, onion"). ` +
    `Decide 'fits_today': true only if its calories realistically fit what's left today without wrecking the plan. ` +
    `Write an honest one-line 'verdict' about today. ` +
    `IF it fits: give 1-3 'adjustments' to other meals today to make room and leave 'tomorrow_plan' empty. ` +
    `IF it does NOT fit: be honest that today's too tight, leave 'adjustments' empty, and give a 'tomorrow_plan' of 3-4 lines ` +
    `budgeting it into TOMORROW across meals using their daily target (e.g. "Breakfast: ~400 kcal — eggs & oats", "Lunch: ~500 kcal — chicken & rice", "Dinner: save ~900 kcal for the ${craving}"). ` +
    `Always give a short 80/20 'fit_tip'. Numbers only — never refuse or lecture.`;

  const reqBody = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { temperature: 0.6, responseMimeType: "application/json", responseSchema: SCHEMA },
  };
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${KEY}`;

  try {
    let result;
    for (let attempt = 0; attempt < 3; attempt++) {
      const res = await fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(reqBody) });
      if (res.ok) { const d = await res.json(); const t = d?.candidates?.[0]?.content?.parts?.[0]?.text; if (t) { result = JSON.parse(t); break; } }
      else if (res.status >= 500 || res.status === 429) { await new Promise((s) => setTimeout(s, 1000 * 2 ** attempt)); continue; }
      else throw new Error(`Gemini ${res.status}`);
    }
    if (!result) throw new Error("no result");
    return json({
      craving: {
        name: String(result.name ?? craving),
        version: String(result.version ?? ""),
        portion: String(result.portion ?? ""),
        calories: Math.round(result.calories ?? 0),
        protein_g: Math.round(result.protein_g ?? 0),
        carbs_g: Math.round(result.carbs_g ?? 0),
        fat_g: Math.round(result.fat_g ?? 0),
        ingredients: Array.isArray(result.ingredients) ? result.ingredients.map(String).slice(0, 8) : [],
        fits_today: result.fits_today !== false,
        verdict: String(result.verdict ?? ""),
        adjustments: Array.isArray(result.adjustments) ? result.adjustments.map(String).slice(0, 3) : [],
        tomorrow_plan: Array.isArray(result.tomorrow_plan) ? result.tomorrow_plan.map(String).slice(0, 4) : [],
        fit_tip: String(result.fit_tip ?? ""),
      },
    });
  } catch (err) {
    console.error("craving failed:", err);
    return json({ error: "craving failed" }, 502);
  }
});
