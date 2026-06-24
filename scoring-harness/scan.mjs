// Stetic scoring harness — prove photo -> aesthetic score before building the app.
// Usage: node scoring-harness/scan.mjs            (scores every image in ./test-photos)
//        node scoring-harness/scan.mjs male path/to/pic.jpg [more.jpg ...]   (one card from N angles)
//
// Reads GEMINI_API_KEY from ../.env. Calls Gemini 2.5 Flash with a strict JSON
// schema at temperature 0. BASIC physique scoring (no harsh mass cap) — movie-star
// framing is marketing only.

import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, dirname, extname, basename } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");

// --- load .env ---
function loadEnv() {
  const p = join(ROOT, ".env");
  if (!existsSync(p)) throw new Error(".env not found at project root");
  for (const line of readFileSync(p, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m) process.env[m[1]] ??= m[2].replace(/^["']|["']$/g, "");
  }
}
loadEnv();
const KEY = process.env.GEMINI_API_KEY;
if (!KEY || KEY.includes("paste-your-key")) {
  console.error("GEMINI_API_KEY not set in .env");
  process.exit(1);
}

const MODEL = "gemini-2.5-flash";
const MIME = { ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp" };

// --- rubric prompt (basic, honest fundamentals) ---
const SYSTEM = `You are a physique-assessment vision model for an aesthetics app. Score the MALE physique in the photo(s) on standard, honest fundamentals — the way a knowledgeable coach would judge a "lean, proportional, movie-star" look. This is a BASIC assessment: do not invent an opinionated agenda, do not hard-cap large physiques to mid-tier. Just rate what you see.

Weighting (internal, do not mention jargon to the user):
- Leanness / conditioning (~30%): lower body fat, visible muscle separation and abdominal definition score higher.
- Shoulder-to-waist taper (~25%): wider shoulders relative to waist scores higher.
- Proportion & symmetry (~20%): balanced development, left/right symmetry, no single part badly lagging.
- Muscle development / fullness (~15%): overall muscular maturity and size, in proportion.
- Frame & posture (~10%): structure and how it's carried.

Rate the overall physique and each of the Core-6 groups: chest, back, shoulders, arms, legs, abs.
Scores are 0-100 (the app divides by 10 to show 0-10).
If a muscle group is NOT visible in the photo(s) (e.g. legs or back are off-frame), give your best conservative estimate inferred from the visible physique and set "visible": false for that group. Do NOT heavily penalize a group just because it's not in frame.
Estimate body_fat as a realistic percentage. symmetry and potential are 0-100.
Keep "verdict" to one punchy sentence. Keep each muscle "note" to a few words.`;

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    aesthetic_score: { type: "number", description: "0-100 overall" },
    body_fat: { type: "number", description: "estimated body fat %" },
    symmetry: { type: "number", description: "0-100" },
    potential: { type: "number", description: "0-100 ceiling with training" },
    muscles: {
      type: "array",
      items: {
        type: "object",
        properties: {
          group: { type: "string", enum: ["chest", "back", "shoulders", "arms", "legs", "abs"] },
          score: { type: "number", description: "0-100" },
          visible: { type: "boolean" },
          note: { type: "string" },
        },
        required: ["group", "score", "visible", "note"],
      },
    },
    verdict: { type: "string" },
  },
  required: ["aesthetic_score", "body_fat", "symmetry", "potential", "muscles", "verdict"],
};

// --- rank ladder (display score 0-10 -> tier) ---
function tierFor(s10) {
  if (s10 >= 9.3) return "Greek God";
  if (s10 >= 8.8) return "Mythic";
  if (s10 >= 8.0) return "Elite";
  if (s10 >= 7.0) return "Diamond";
  if (s10 >= 6.0) return "Platinum";
  if (s10 >= 5.0) return "Gold";
  if (s10 >= 4.0) return "Silver";
  return "Bronze";
}

const clamp = (n, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, n));
const d1 = (n) => Math.round(n) / 10; // 0-100 -> one-decimal 0-10

async function scoreImages(paths) {
  const parts = [{ text: "Assess this physique." }];
  for (const p of paths) {
    const ext = extname(p).toLowerCase();
    const mime = MIME[ext];
    if (!mime) throw new Error(`unsupported image type: ${p}`);
    parts.push({ inline_data: { mime_type: mime, data: readFileSync(p).toString("base64") } });
  }

  const body = {
    systemInstruction: { parts: [{ text: SYSTEM }] },
    contents: [{ role: "user", parts }],
    generationConfig: {
      temperature: 0,
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  };

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${KEY}`;
  let res, lastErr;
  for (let attempt = 0; attempt < 6; attempt++) {
    res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    if (res.ok) break;
    lastErr = `Gemini ${res.status}`;
    if (res.status === 503 || res.status === 429 || res.status >= 500) {
      await new Promise((s) => setTimeout(s, 1500 * 2 ** attempt)); // 1.5s,3s,6s,12s,24s
      continue;
    }
    throw new Error(`${lastErr}: ${await res.text()}`);
  }
  if (!res.ok) throw new Error(`${lastErr} after retries (model overloaded)`);
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("no text in response: " + JSON.stringify(data).slice(0, 500));
  return JSON.parse(text);
}

function printCard(label, r) {
  const overall = d1(clamp(r.aesthetic_score));
  const tier = tierFor(overall);
  const order = ["chest", "back", "shoulders", "arms", "legs", "abs"];
  const muscles = [...r.muscles].sort((a, b) => b.score - a.score);
  const bar = (s10) => {
    const n = Math.round(s10);
    return "█".repeat(n) + "░".repeat(10 - n);
  };

  console.log("\n" + "═".repeat(48));
  console.log(`  ${label}`);
  console.log("═".repeat(48));
  console.log(`  AESTHETIC  ${overall.toFixed(1)}/10   ·   ${tier.toUpperCase()}`);
  console.log(`  body fat ${r.body_fat}%   symmetry ${d1(clamp(r.symmetry)).toFixed(1)}   potential ${d1(clamp(r.potential)).toFixed(1)}`);
  console.log("  " + "─".repeat(44));
  muscles.forEach((m, i) => {
    const s = d1(clamp(m.score));
    const tag = i === 0 ? "↑strong" : i === muscles.length - 1 ? "↓weak " : "       ";
    const vis = m.visible === false ? " (est)" : "";
    console.log(`  ${tag} ${m.group.padEnd(9)} ${bar(s)} ${s.toFixed(1)}  ${m.note}${vis}`);
  });
  console.log("  " + "─".repeat(44));
  console.log(`  "${r.verdict}"`);
}

// --- main ---
const args = process.argv.slice(2);
const dir = join(__dirname, "test-photos");

if (args[0] === "each" && args.length >= 2) {
  // score each listed file as its own card (with spacing for free-tier RPM)
  const files = args.slice(1);
  for (let i = 0; i < files.length; i++) {
    try {
      printCard(basename(files[i]), await scoreImages([files[i]]));
    } catch (e) {
      console.error(`\n  ${files[i]}: ${e.message}`);
    }
    if (i < files.length - 1) await new Promise((s) => setTimeout(s, 4000));
  }
} else if (args.length >= 2 && args[0] === "male") {
  // explicit multi-angle single card
  const card = await scoreImages(args.slice(1));
  printCard(args.slice(1).map(basename).join(" + "), card);
} else {
  // score every image in test-photos as its own card
  const imgs = existsSync(dir)
    ? readdirSync(dir).filter((f) => MIME[extname(f).toLowerCase()]).sort()
    : [];
  if (imgs.length === 0) {
    console.error(`No images in ${dir}. Drop .jpg/.png/.webp files there and re-run.`);
    process.exit(1);
  }
  console.log(`Scoring ${imgs.length} photo(s) from test-photos/ ...`);
  for (let i = 0; i < imgs.length; i++) {
    const f = imgs[i];
    try {
      const card = await scoreImages([join(dir, f)]);
      printCard(f, card);
    } catch (e) {
      console.error(`\n  ${f}: ${e.message}`);
    }
    if (i < imgs.length - 1) await new Promise((s) => setTimeout(s, 4000)); // free-tier RPM spacing
  }
}
console.log("");
