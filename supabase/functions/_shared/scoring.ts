// Stetic scoring — single source of truth for the physique rubric.
// Ported from scoring-harness/scan.mjs (validated 2026-06-24). Basic, honest
// fundamentals; leanness is the top lever (movie-star wedge). No harsh mass cap.

export const SCAN_MODEL = "gemini-2.5-flash";

export const RANK_TIERS = [
  "bronze", "silver", "gold", "platinum", "diamond", "elite", "mythic", "greek_god",
] as const;
export type RankTier = (typeof RANK_TIERS)[number];

export const CORE6 = ["chest", "back", "shoulders", "arms", "legs", "abs"] as const;

export function systemPrompt(sex: "male" | "female"): string {
  const lean = sex === "male"
    ? "Lower body fat with a target band around 10-13% scores highest."
    : "Tone with a healthy target band around 18-24% body fat scores highest (do NOT apply a male 10-13% target).";
  const ratio = sex === "male"
    ? "Shoulder-to-waist taper (~25%): wider shoulders relative to waist scores higher."
    : "Shoulder-waist-hip balance / hourglass (~25%): waist-to-hip ratio is the dominant ratio.";
  return `You are a physique-assessment vision model for an aesthetics app. Score the ${sex.toUpperCase()} physique in the photo(s) on standard, honest fundamentals — the way a knowledgeable coach would judge a "lean, proportional, movie-star" look. This is a BASIC assessment: do not invent an opinionated agenda, do not hard-cap large physiques to mid-tier. Rate what you see.

Weighting (internal, do not mention jargon to the user):
- Leanness / conditioning (~30%): ${lean} Visible muscle separation and definition score higher.
- ${ratio}
- Proportion & symmetry (~20%): balanced development, left/right symmetry, no single part badly lagging.
- Muscle development / fullness (~15%): actual muscular maturity and size, in proportion. A lean but undeveloped (skinny) physique should NOT clear the upper tiers on leanness alone.
- Frame & posture (~10%): structure and how it's carried.

Rate the overall physique and each of the Core-6 groups: chest, back, shoulders, arms, legs, abs.
Scores are 0-100 (the app divides by 10 to show 0-10).
If a muscle group is NOT visible (e.g. legs or back off-frame), give your best conservative estimate from the visible physique and set "visible": false. Do NOT heavily penalize a group just for being out of frame.
Estimate body_fat as a realistic percentage. symmetry and potential are 0-100. potential is the realistic CEILING with focused training, so it must be >= the overall aesthetic_score (never below it).
Keep "verdict" to one punchy sentence. Keep each muscle "note" to a few words.`;
}

export const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    aesthetic_score: { type: "number" },
    body_fat: { type: "number" },
    symmetry: { type: "number" },
    potential: { type: "number" },
    muscles: {
      type: "array",
      items: {
        type: "object",
        properties: {
          group: { type: "string", enum: [...CORE6] },
          score: { type: "number" },
          visible: { type: "boolean" },
          note: { type: "string" },
        },
        required: ["group", "score", "visible", "note"],
      },
    },
    verdict: { type: "string" },
  },
  required: ["aesthetic_score", "body_fat", "symmetry", "potential", "muscles", "verdict"],
} as const;

export function tierFor(s10: number): RankTier {
  if (s10 >= 9.3) return "greek_god";
  if (s10 >= 8.8) return "mythic";
  if (s10 >= 8.0) return "elite";
  if (s10 >= 7.0) return "diamond";
  if (s10 >= 6.0) return "platinum";
  if (s10 >= 5.0) return "gold";
  if (s10 >= 4.0) return "silver";
  return "bronze";
}

const clamp = (n: number, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, n));
const d1 = (n: number) => Math.round(clamp(n)) / 10; // 0-100 -> one-decimal 0-10

export interface ScoreCard {
  aesthetic_score: number; // 0.0-10.0
  rank_tier: RankTier;
  body_fat: number;
  symmetry: number;
  potential: number;
  muscles: { group: string; score: number; visible: boolean; note: string }[];
  verdict: string;
}

// Raw Gemini JSON -> clamped/rounded, display-ready card (scores on 0-10 scale).
export function postProcess(raw: any): ScoreCard {
  const overall = d1(raw.aesthetic_score);
  const muscles = (raw.muscles ?? [])
    .map((m: any) => ({
      group: m.group,
      score: d1(m.score),
      visible: m.visible !== false,
      note: String(m.note ?? "").slice(0, 80),
    }))
    .sort((a: any, b: any) => b.score - a.score);
  return {
    aesthetic_score: overall,
    rank_tier: tierFor(overall),
    body_fat: Math.round(clamp(raw.body_fat, 1, 60) * 10) / 10,
    symmetry: d1(raw.symmetry),
    potential: Math.max(d1(raw.potential), overall), // ceiling can never be below current score

    muscles,
    verdict: String(raw.verdict ?? "").slice(0, 200),
  };
}

// Call Gemini with N images (base64) and return the validated card.
export async function scorePhotos(
  apiKey: string,
  sex: "male" | "female",
  images: { mimeType: string; dataB64: string }[],
): Promise<ScoreCard> {
  const parts: any[] = [{ text: "Assess this physique." }];
  for (const img of images) {
    parts.push({ inline_data: { mime_type: img.mimeType, data: img.dataB64 } });
  }
  const body = {
    systemInstruction: { parts: [{ text: systemPrompt(sex) }] },
    contents: [{ role: "user", parts }],
    generationConfig: {
      temperature: 0,
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  };
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${SCAN_MODEL}:generateContent?key=${apiKey}`;

  let lastStatus = 0;
  for (let attempt = 0; attempt < 5; attempt++) {
    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    if (res.ok) {
      const data = await res.json();
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!text) throw new Error("Gemini returned no content");
      return postProcess(JSON.parse(text));
    }
    lastStatus = res.status;
    if (res.status === 503 || res.status === 429 || res.status >= 500) {
      await new Promise((s) => setTimeout(s, 1200 * 2 ** attempt));
      continue;
    }
    throw new Error(`Gemini ${res.status}: ${await res.text()}`);
  }
  throw new Error(`Gemini ${lastStatus} after retries`);
}

// Stable hash of the normalized photo set + sex -> consistency cache key.
export async function photoSetHash(
  sex: string,
  images: { dataB64: string }[],
): Promise<string> {
  const enc = new TextEncoder();
  const joined = sex + "|" + images.map((i) => i.dataB64).join("|");
  const digest = await crypto.subtle.digest("SHA-256", enc.encode(joined));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
