// Stetic plan generation — workout split + macros + breakdown + projection.
// Gemini 2.5 Pro. Training doctrine = Jordan Peters (Trained by JP): low volume,
// high intensity (every set to failure), high frequency, progressive overload.

export const PLAN_MODEL = "gemini-2.5-pro";

export interface PlanProfile {
  goal?: string;          // lose_fat | gain_muscle | both
  focus?: string[];       // arms, shoulders, abs, chest, legs, back, lower_bf
  experience?: string;    // beginner | intermediate | advanced
  days_per_week?: number;
  equipment?: string;     // full_gym | home | dumbbells_only
  height_cm?: number;
  weight_kg?: number;
  age?: number;
  sex?: string;
  current_split?: string;     // optional: what they're currently doing
  training_duration?: string; // optional: how long they've trained / run that split
}

export function planPrompt(scan: any, profile: PlanProfile): string {
  const days = profile.days_per_week ?? 4;
  const goal = profile.goal ?? "both";
  const equip = profile.equipment ?? "full_gym";
  const exp = profile.experience ?? "intermediate";
  const focus = (profile.focus ?? []).join(", ") || "none specified";
  const ranked = (scan.muscles ?? [])
    .slice().sort((a: any, b: any) => a.score - b.score)
    .map((m: any) => `${m.group} ${m.score}`).join(", ");
  const stats = profile.height_cm && profile.weight_kg && profile.age
    ? `${profile.age}yo ${profile.sex ?? "male"}, ${profile.height_cm}cm, ${profile.weight_kg}kg (bf ${scan.body_fat}% → lean mass ≈ ${Math.round((profile.weight_kg) * (1 - (scan.body_fat ?? 15) / 100))}kg)`
    : `bf ${scan.body_fat}%`;
  const splitNote = profile.current_split
    ? `\nThe user's CURRENT routine: "${profile.current_split}"${profile.training_duration ? ` (running it for ${profile.training_duration})` : ""}. In "split_critique", explain honestly why this routine is likely leaving their weak points (${ranked.split(",")[0]?.trim()}) behind, referencing the JP principles (junk volume vs intensity, frequency, progressive overload). Be specific, not generic.`
    : "";

  return `You are Stetic's coach. The product sells a lean, proportional "movie-star / Greek-god" aesthetic — NOT a mass-monster look. Build a plan that moves THIS user toward that.

TRAINING DOCTRINE — you MUST follow Jordan Peters (Trained by JP) principles:
- LOW VOLUME, HIGH INTENSITY, HIGH FREQUENCY. ~2 working sets per exercise (a heavy top set, then a back-off set ~10% lighter on compounds / ~5% on isolation). Do NOT prescribe 3-4 straight working sets.
- EVERY working set is taken to TRUE muscular failure (0 reps in reserve). Make this explicit in notes where useful.
- Progressive overload via a logbook is the primary driver — beat last session by a rep or a tiny load increase. Mechanical tension first.
- FREQUENCY: hit each muscle group ~2x per week. With ${days} training days: 3 days → Upper/Lower split; 4 days → Push/Pull/Legs(+ one); 5-6 → push/pull/legs twice but only if recovery supports it. "More work does NOT equal more results."
- UNDULATING rep ranges across the week: 5-9, 10-12, 15-20. Put compound / mechanical-tension movements FIRST while fresh; isolation + stretch/metabolic-stress work LAST.
- Tempo ~3010, ~2 min rest between work sets, full range of motion, controlled. Stretch each trained muscle 60-90s after.
- Advanced intensity techniques (rest-pause, drop set, cluster) ONLY occasionally, usually on a final isolation movement.
- RECOVERY dictates results. Respect the user's training days; do not over-prescribe. Mention a deload every ~8-12 weeks.
- WEAK POINTS: bring up lagging groups via smart exercise selection, order (train them first/when fresh) and slightly more frequency — NOT by piling on junk sets.

USER PHYSIQUE (from scan):
- Aesthetic score ${scan.aesthetic_score}/10 (${scan.rank_tier}); body fat ${scan.body_fat}%, symmetry ${scan.symmetry}/10, potential ${scan.potential}/10 (this is their realistic ceiling).
- Groups weakest→strongest: ${ranked}.
- Verdict: ${scan.verdict}

USER PROFILE: goal ${goal}; focus ${focus}; experience ${exp}; ${days} days/week; equipment ${equip}; ${stats}.${splitNote}

OUTPUT REQUIREMENTS:
- goal_label: a short human label for the goal driving this plan (e.g. "Build muscle — lean bulk", "Lose fat — get lean", "Recomp").
- summary: 2-3 punchy sentences naming their weak points and the strategy.
- macros: follow the JP ebook method EXACTLY, in this order:
  1) PROTEIN FIRST: 1.5 g per lb of BODYWEIGHT (use weight if known, else estimate from height/build). Protein is 4 kcal/g.
  2) TDEE: Mifflin-St Jeor BMR [men: 10·kg + 6.25·cm − 5·age + 5; women: same but −161 instead of +5] × activity factor (1.5 sedentary, 1.8 office+training [USE THIS DEFAULT], 2.2 vigorous).
  3) Adjust TDEE for goal: lose_fat = deficit (~−400 to −500 kcal); gain_muscle / both = small surplus (~+200 to +300 kcal). Slow and steady — JP says start ~±200/week.
  4) Remaining calories after protein are split 65% to CARBS / 35% to FAT (carbs 4 kcal/g, fat 9 kcal/g). Constraints: fat ≥ 0.3 g/lb of LEAN mass; carbs ≥ ~120 g.
  Put the actual method in the rationale (mention Mifflin × 1.8, protein 1.5g/lb, 65/35 split).
- weekly_split: exactly ${days} sessions, JP rep scheme — MATCH the ebook:
  • Most exercises = **2 working sets**: a heavy TOP set (5-9 or 6-9 reps) then a BACK-OFF set ~10% lighter on compounds / ~5% on isolation in the 10-12 range. Write reps as "5-9, 10-12" (top, back-off).
  • Isolation / finisher movements = 2 sets of "15-20".
  • Biceps/arm movements may use 3 sets "6-9, 10-12, 15-20".
  • Abs = 4 sets of "15-20".
  • Occasionally on the LAST movement of a muscle, use a JP intensity technique: rest-pause reps "12, 6, 3" or "15, 8, 5" (sets=1), a triple drop set (sets=1), or a 6×4 cluster (sets=6, reps="4").
  • Set the 'sets' number to match (2 normally; 3 for the three-range arm work; 4 for abs; 1 for rest-pause/drop/cluster).
  • ALL working sets to failure, tempo 3010, ~2 min rest. Compounds/mechanical-tension FIRST while fresh; isolation + stretch work LAST. Each exercise 'note' = a cue or technique (e.g. "Top set then ~10% back-off, both to failure", "Rest-pause", "Stretch 60-90s after").
- priorities: 3-4 fix-first items with sub-muscle specificity (side delts, lats, lower abs, etc.).
- muscle_breakdown: for EACH of chest, back, shoulders, arms, legs, abs — rating, a one-line detail, and 1-3 sub-muscles (biceps/triceps, side/rear/front delts, upper/lower abs, lats/upper-back, quads/hamstrings) each with a status and a training cue.
- projection: REALISTIC but motivating. Two milestones at 6 and 12 weeks of following THIS plan. Gains scale by starting level: a beginner / higher-body-fat / score far below potential improves faster; an advanced, lean, near-potential lifter improves slowly (maybe +0.1-0.3 over 6 weeks). NEVER exceed their potential (${scan.potential}). For each milestone give: weeks, projected_score (one decimal), projected_tier (lowercase: bronze/silver/gold/platinum/diamond/elite/mythic/greek_god), points_gain, projected_body_fat (realistic — drops a few % with a fat-loss goal, roughly flat on a lean-gain; current is ${scan.body_fat}%), a one-line summary, and muscle_gains for their 2-3 weakest groups as {group, from, to}. Honesty matters — the user re-scans and this gets checked.${profile.current_split ? "\n- split_critique: see instruction above." : ""}
- No medical claims.`;
}

const subSchema = {
  type: "object",
  properties: {
    name: { type: "string" }, status: { type: "string" }, cue: { type: "string" },
  },
  required: ["name", "status", "cue"],
};

export const PLAN_SCHEMA = {
  type: "object",
  properties: {
    goal_label: { type: "string" },
    summary: { type: "string" },
    macros: {
      type: "object",
      properties: {
        calories: { type: "number" }, protein_g: { type: "number" },
        carbs_g: { type: "number" }, fat_g: { type: "number" }, rationale: { type: "string" },
      },
      required: ["calories", "protein_g", "carbs_g", "fat_g", "rationale"],
    },
    weekly_split: {
      type: "array",
      items: {
        type: "object",
        properties: {
          day: { type: "string" }, focus: { type: "string" },
          exercises: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" }, sets: { type: "number" },
                reps: { type: "string" }, target: { type: "string" }, note: { type: "string" },
              },
              required: ["name", "sets", "reps", "target"],
            },
          },
        },
        required: ["day", "focus", "exercises"],
      },
    },
    priorities: {
      type: "array",
      items: {
        type: "object",
        properties: { area: { type: "string" }, why: { type: "string" }, action: { type: "string" } },
        required: ["area", "why", "action"],
      },
    },
    muscle_breakdown: {
      type: "array",
      items: {
        type: "object",
        properties: {
          group: { type: "string" }, rating: { type: "number" }, detail: { type: "string" },
          sub: { type: "array", items: subSchema },
        },
        required: ["group", "rating", "detail", "sub"],
      },
    },
    projection: {
      type: "object",
      properties: {
        milestones: {
          type: "array",
          items: {
            type: "object",
            properties: {
              weeks: { type: "number" },
              projected_score: { type: "number" },
              projected_tier: { type: "string" },
              points_gain: { type: "number" },
              projected_body_fat: { type: "number" },
              summary: { type: "string" },
              muscle_gains: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    group: { type: "string" }, from: { type: "number" }, to: { type: "number" },
                  },
                  required: ["group", "from", "to"],
                },
              },
            },
            required: ["weeks", "projected_score", "projected_tier", "points_gain", "projected_body_fat", "summary", "muscle_gains"],
          },
        },
      },
      required: ["milestones"],
    },
    split_critique: { type: "string" },
  },
  required: ["goal_label", "summary", "macros", "weekly_split", "priorities", "muscle_breakdown", "projection"],
} as const;

export async function generatePlan(
  apiKey: string,
  scan: any,
  profile: PlanProfile,
): Promise<any> {
  const body = {
    systemInstruction: { parts: [{ text: planPrompt(scan, profile) }] },
    contents: [{ role: "user", parts: [{ text: "Generate the plan." }] }],
    generationConfig: {
      temperature: 0.3,
      responseMimeType: "application/json",
      responseSchema: PLAN_SCHEMA,
    },
  };
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${PLAN_MODEL}:generateContent?key=${apiKey}`;

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
      return JSON.parse(text);
    }
    lastStatus = res.status;
    if (res.status === 503 || res.status === 429 || res.status >= 500) {
      await new Promise((s) => setTimeout(s, 1500 * 2 ** attempt));
      continue;
    }
    throw new Error(`Gemini ${res.status}: ${await res.text()}`);
  }
  throw new Error(`Gemini ${lastStatus} after retries`);
}
