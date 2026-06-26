// POST /meal-scan — estimate calories + macros from a meal photo.
// Gated on an active entitlement. Photo is used in-memory only and never stored;
// the client decides whether to save the returned numbers to meal_logs.
//
// Body: { image: { mimeType: string, dataB64: string } }
// Auth: Authorization: Bearer <supabase user jwt>

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });

const MEAL_MODEL = "gemini-2.5-flash";
const MEAL_SCHEMA = {
  type: "object",
  properties: {
    name: { type: "string" },
    items: {                          // distinct foods detected, each with its own macros
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          portion: { type: "string" },
          calories: { type: "number" },
          protein_g: { type: "number" },
          carbs_g: { type: "number" },
          fat_g: { type: "number" },
        },
        required: ["name", "calories", "protein_g", "carbs_g", "fat_g"],
      },
    },
    calories: { type: "number" },
    protein_g: { type: "number" },
    carbs_g: { type: "number" },
    fat_g: { type: "number" },
    confidence: { type: "string" },   // low | medium | high
    note: { type: "string" },         // short assumption, e.g. "assumed ~200g chicken"
  },
  required: ["name", "calories", "protein_g", "carbs_g", "fat_g", "confidence"],
} as const;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
  if (!GEMINI_API_KEY) return json({ error: "server misconfigured" }, 500);

  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  const user = userData?.user;
  if (userErr || !user) return json({ error: "unauthorized" }, 401);

  const bypass = Deno.env.get("STETIC_DEV_BYPASS_ENTITLEMENT") === "true";
  if (!bypass) {
    const { data: sub } = await supabase
      .from("subscriptions").select("status, expires_at").eq("user_id", user.id).maybeSingle();
    const active = sub && ["active", "trialing"].includes(sub.status) &&
      (!sub.expires_at || new Date(sub.expires_at) > new Date());
    if (!active) return json({ error: "subscription required" }, 402);
  }

  let payload: { image?: { mimeType: string; dataB64: string }; mode?: string };
  try { payload = await req.json(); } catch { return json({ error: "invalid json" }, 400); }
  const image = payload.image;
  if (!image?.dataB64 || !image?.mimeType) return json({ error: "no image" }, 400);

  const labelPrompt =
    `This is a photo of a nutrition facts label (and possibly the product). Read the label EXACTLY ` +
    `as printed. Return ONE item named after the product (or "Packaged food" if unknown) with portion ` +
    `set to the stated serving size (e.g. "1 serving (40g)"). Use the PER-SERVING calories and macros ` +
    `from the label. The top-level totals must equal that single item. confidence "high" if the label ` +
    `is legible. Numbers only — do not refuse.`;
  const mealPrompt =
    `You are a nutrition estimator. Identify the meal in this photo and BREAK IT DOWN into its component foods/ingredients in 'items'. ` +
    `If a dish is a single assembled item (burger, sandwich, burrito, salad, stir-fry, pasta, bowl), list its MAIN edible components separately — ` +
    `e.g. a cheeseburger → {bun}, {beef patty}, {cheese}, {sauce}; a chicken salad → {greens}, {grilled chicken}, {dressing}, {croutons}. ` +
    `If the plate has several separate foods, list each of those. Each item: short name, a rough portion, AND its own calories + macros for the ` +
    `portion shown (e.g. {name:"Beef patty", portion:"~150g", calories:280, protein_g:24, carbs_g:0, fat_g:20}). ` +
    `Only list components that meaningfully affect macros — skip trivial things (water, spices, a pinch of salt). Aim for the 2–6 main contributors; ` +
    `a genuinely simple single food (an apple, black coffee) stays ONE item. ` +
    `The top-level calories/protein_g/carbs_g/fat_g MUST equal the SUM of the items, and MUST be realistic NON-ZERO numbers for any real food (never return all zeros). ` +
    `If you cannot confidently break it into components, still return ONE item for the whole dish with its full macros. Name the whole meal naturally (e.g. "Cheeseburger", "Chicken salad"). ` +
    `Be realistic, not rounded to marketing numbers. Set confidence by how clearly you can judge it. Put any key assumption in 'note'. ` +
    `Numbers only — do not refuse; give your best estimate.`;
  const prompt = payload.mode === "label" ? labelPrompt : mealPrompt;

  const body = {
    contents: [{
      role: "user",
      parts: [
        { text: prompt },
        { inlineData: { mimeType: image.mimeType, data: image.dataB64 } },
      ],
    }],
    generationConfig: {
      temperature: 0,   // deterministic: same plate shouldn't jitter calories run-to-run
      responseMimeType: "application/json",
      responseSchema: MEAL_SCHEMA,
    },
  };
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${MEAL_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

  let meal;
  try {
    let lastStatus = 0;
    for (let attempt = 0; attempt < 4; attempt++) {
      const res = await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      });
      if (res.ok) {
        const data = await res.json();
        const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (!text) throw new Error("no content");
        meal = JSON.parse(text);
        break;
      }
      lastStatus = res.status;
      if (res.status === 503 || res.status === 429 || res.status >= 500) {
        await new Promise((s) => setTimeout(s, 1200 * 2 ** attempt));
        continue;
      }
      throw new Error(`Gemini ${res.status}: ${await res.text()}`);
    }
    if (!meal) throw new Error(`Gemini ${lastStatus} after retries`);
  } catch (e) {
    console.error("meal scan failed:", e);
    return json({ error: "meal scan failed" }, 502);
  }

  // Round to clean integers; never persist the photo.
  return json({
    meal: {
      name: String(meal.name ?? "Meal"),
      items: Array.isArray(meal.items)
        ? meal.items.map((it: Record<string, unknown>) => ({
          name: String(it?.name ?? ""),
          portion: String(it?.portion ?? ""),
          calories: Math.round(Number(it?.calories ?? 0)),
          protein_g: Math.round(Number(it?.protein_g ?? 0)),
          carbs_g: Math.round(Number(it?.carbs_g ?? 0)),
          fat_g: Math.round(Number(it?.fat_g ?? 0)),
        })).filter((it: { name: string }) => it.name)
        : [],
      calories: Math.round(meal.calories ?? 0),
      protein_g: Math.round(meal.protein_g ?? 0),
      carbs_g: Math.round(meal.carbs_g ?? 0),
      fat_g: Math.round(meal.fat_g ?? 0),
      confidence: meal.confidence ?? "medium",
      note: meal.note ?? "",
    },
  });
});
