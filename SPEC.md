# Stetic — Build Spec (v1)

> AI physique scanner + coach for an aesthetic ("Greek god / movie-star") look, not a bodybuilder one.
> Scan your physique → get a 1–10 Aesthetic score + rank + per-muscle ratings → unlock a workout + macros plan.
> Native iOS (SwiftUI). Solo build. Distribution via faceless TikTok content (see `CONTEXT.md`).

This spec is the source of truth for the build. Marketing/positioning lives in `CONTEXT.md`; score-card mockups live in `mockups/`.

---

## 1. Product in one paragraph

Stetic is a hard-paywalled iOS app. A new user goes through a long, investment-building onboarding (à la Fellow / Wrestle AI / PrayerLock / Cal AI): ~20 question screens, a shock/FOMO moment, a cinematic "analyzing your physique" sequence, account creation, then a paywall with a 3-day free trial. **The physique photos are captured during onboarding but are NOT sent to the AI until the user subscribes** — the onboarding "analysis" is a bluff animation, so we spend ~$0 on non-payers. On successful trial start, we actually call the vision model, render the real score card (1–10 aesthetic score + rank + Core-6 muscle ratings), and generate a personalized workout + macros plan. The app then retains the user with a re-scan progress loop, workout session logging, bodyweight tracking, and photo-based meal calorie tracking. Every result is one-tap exportable as a branded share card to feed the content engine.

---

## 2. Core decisions (locked this session)

| Area | Decision |
|---|---|
| Platform | Native iOS, SwiftUI, iOS 17+, iPhone-only, portrait-only |
| Backend | Supabase (Postgres + Auth + Storage + Edge Functions) |
| AI — scan scoring | LLM vision **end-to-end**, **Gemini 2.5 Flash** (cheap, high volume) |
| AI — plan generation | **Gemini 2.5 Pro** (reasoning matters, lower volume, post-paywall only) |
| AI — meal scan | Gemini 2.5 Flash, food-specific prompt |
| Score scale | **1–10, one decimal** overall AND per-muscle (internally 0–100, displayed ÷10) |
| Consistency | Hash the photo set → cache the result; temp ~0 + strict JSON schema + clamp in code. Same photo never flip-flops; a NEW photo re-scores. No multi-sampling. |
| Photo input | Up to 3 photos, all optional (front recommended; side/back optional). Full-body vs upper-body optional. More angles = better accuracy (confidence is NOT surfaced to the user). |
| Photo retention | **Ephemeral** — never persisted at rest. Sent to AI, scored, discarded. Only derived numbers stored. |
| Auth | Apple Sign In (primary) + optional email; account created **at the end of onboarding, right before the paywall** |
| Monetization | **Hard paywall + 3-day free trial.** Whole app gated. (This also solves abuse: card required.) |
| Paywall infra | **RevenueCat** |
| Pricing | **Monthly + Annual** (Cal AI model). Monthly $9.99/mo; Annual $39.99/yr (default-selected, "Save 67%"). **3-day free trial on ANNUAL only** (pushes annual + lifts LTV). Exit-intent extra discount on annual w/ countdown. |
| Plan | Workout + macros (no rigid recipes in v1) |
| Progress | Score-history graph (numbers only, no stored images) |
| Audience | **Both sexes at launch** — separate male & female rubrics |
| Future-you image | Deferred (use projected score chart for FOMO instead) |
| Growth loop | Share-card export in v1; leaderboard + referrals deferred |
| Reveal mechanic | Capture in onboarding → bluff "analysis" → paywall → **real AI call on subscribe** → reveal |

---

## 3. The scoring model

### 3.1 Overall
- **Aesthetic score 1–10** (one decimal). Single headline number; drives the rank. Mass is NOT a co-headline.
- Quick stats shown under the score: **Body fat %** (actual number), **Symmetry** (1–10), **Potential** (1–10).
- **Core-6 muscle groups** each rated 1–10, **ranked strongest → weakest**, strongest highlighted green, weakest red.
- **"Your priorities"** section: Fix-first / Maintain guidance pulled out of the muscle rows.
- **Rank ladder:** Bronze → Silver → Gold → Platinum → Diamond → Elite → Mythic → Greek God (apex). Climb strip on the result for FOMO.

### 3.2 Male rubric — weighted drivers (the wedge: leanness & ratios dominate, mass demoted)
1. **Leanness / conditioning** — ~30–35%. Target sustainable ~10–13% bf. Biggest visual lever, most controllable.
2. **V-taper (shoulder-to-waist)** — ~25–30%. Adonis ratio ~1.6 ideal band. Computed internally; not surfaced as jargon.
3. **Proportion & balance** — ~20%. Where weak-point detection lives (lagging part that breaks the line, L/R asymmetry).
4. **Upper-body camera read** — ~15%. Side delts, upper chest, arms, detail (serratus/abs/neck). Legs/back thickness deliberately down-weighted.
5. **Frame & posture** — ~10% modifier. Posture coachable; frame (clavicle width) is context, not a penalty.
- **Mass cap:** excessive total mass caps the score via a **"Size: Extreme"** flag even if every group rates 9.5+ (the Ronnie Coleman = 5.0 case). This is a deliberate take; embrace the comment debate. Not over-engineered.

### 3.3 Female rubric (NEW — both-sexes launch)
Same machinery, reweighted levers and different benchmarks (fitness-model/aesthetic physiques, not female bodybuilders):
1. **Leanness / tone** — ~25–30%. **Higher target band ~18–24% bf** (do not apply the male 10–13% target).
2. **Shoulder-waist-hip balance (hourglass)** — ~25–30%. Waist-to-hip ratio is the dominant ratio (vs male V-taper).
3. **Glute & leg development** — ~20%. Up-weighted vs the male rubric.
4. **Proportion & balance / camera read** — ~15%. Delts/back for shoulder line, core definition relative to band.
5. **Frame & posture** — ~10% modifier.
- **No hard mass cap** (or a much softer one) — over-muscled is a rarer failure mode here. Same rank ladder & tiers; benchmark physiques swapped to female references.

> Both rubrics are **prompt + post-processing**, not a trained model. The moat is positioning + content, not the math. Keep it consistent and on-brand; ship it.

### 3.4 Consistency mechanic
- On scan: compute a stable hash of the normalized photo set + sex + key inputs. Look up cache; if present, return stored result.
- Model call: temperature ~0, `responseSchema` enforced JSON, then code clamps/rounds to the rubric (e.g., applies mass cap, computes tier from score).
- A re-scan with new photos is a new hash → new result (expected; "new day, new pump/lighting").

---

## 4. Onboarding funnel (the conversion engine)

Modeled on the teardowns (Fellow / Wrestle AI / Program AI / Cal AI / PrayerLock). Order tuned for sunk-cost investment, then reveal-gating.

1. **Cinematic intro** — "The naked eye misses the patterns. Stetic finds them." Demo of the scan→score→plan loop. ("powered by computer vision")
2. **Identity** — sex (male/female). (Routes to correct rubric.)
3. **Primary goal** — lose fat / gain muscle / both.
4. **Fine-tune focus (multiselect)** — V-taper/back, arms, shoulders, abs, chest, legs, lower body fat. (Male/female option sets differ.)
5. **Obstacles (multiselect)** — slow results, plateauing, limited knowledge, intimidated in gym, other.
6. **Value/credibility interstitial** — "Stetic uncovers what's beneath the surface and builds the plan around your weak points."
7. **Experience** — beginner / intermediate / advanced.
8. **Days/week** — pick training days.
9. **Equipment** — full gym / home / dumbbells-only.
10. **Stats** — height, weight (kg/lb toggle), age.
11. **Target weight** — gain/cut target with rate framing.
12. **Diet style / restrictions** — (feeds macros).
13. **Attribution** — "How did you hear about us?" (TikTok/IG/YouTube/App Store/friend) → marketing data.
14. **Social proof** — reviews / "X bodies analyzed" screens (sprinkled earlier too).
15. **Scan capture** — instructions (athletic wear, lighting), capture up to 3 photos (front/side/back), all optional but front strongly nudged. **On-device body + nudity check here** (reject unusable/explicit before proceeding).
16. **FOMO/shock moment** — projected outcome chart "with vs without Stetic," and/or a teaser stat computed from answers ("at your current training you'll never break Silver"). Numbers-only (no AI call).
17. **Bluff analysis sequence** — cinematic multi-stage loader: "Mapping your physique → identifying lagging groups → calibrating your ratios → finalizing." **NO AI call.** ~6–10s with case-study cards.
18. **"Your analysis is ready"** — blurred/placeholder score card + FOMO summary ("we found 3 lagging groups and 1 proportion breaking your frame").
19. **Account creation** — Apple Sign In (+ optional email). Onboarding answers (held locally) now persisted to the account.
20. **Paywall** — RevenueCat. Weekly + Annual, 3-day trial, "Save 87%" on annual. Exit-intent → ~40% off annual with countdown.
21. **On subscribe → REAL scan.** Now send photos to Gemini 2.5 Flash, score, generate plan (2.5 Pro), discard photos, reveal real result + plan.

> If the user backgrounds/abandons after paying but before reveal, the scan runs server-side and the result is waiting on next open.

---

## 5. Post-purchase product (retention)

- **Result / score card** — the hero screen (see `mockups/stetic-score-cards.html`). Score, rank, stats, ranked Core-6, priorities, climb strip, share + "view plan."
- **Workout plan** — split tailored to weak points + goal + days + equipment + experience. Sessions listed; user **logs a completed session** (NOT per-exercise set logging in v1). Optional **bodyweight log**.
- **Macros plan** — daily calorie + protein/carb/fat targets from stats/goal/activity. Adjusts on weight change / re-scan.
- **Meal calorie tracking (Cal AI-style)** — photo of a meal → Gemini Flash returns calories + macros; logs against daily targets. (Reuses vision infra; paying-user volume only.)
- **Progress** — re-scan anytime → score-history graph (score, bf%, per-muscle over time). No stored images. Re-scan reminders.
- **Share-card export** — one-tap branded image/Story export of the result (watermarked) → TikTok/IG growth loop.

---

## 6. Architecture

```
iOS app (SwiftUI)
  ├─ Onboarding (local state until account) ── RevenueCat (paywall, trial, restore)
  ├─ Vision capture + on-device body/nudity check (Apple Vision / Sensitive Content)
  └─ Supabase client (auth, data)
        │  HTTPS (JWT)
        ▼
Supabase
  ├─ Auth (Apple Sign In)
  ├─ Postgres (users, scans, plans, logs, meals) + RLS
  └─ Edge Functions (the only place AI keys live)
        ├─ /scan      → Gemini 2.5 Flash (score)         [gated: active subscription]
        ├─ /plan      → Gemini 2.5 Pro   (workout+macros) [gated]
        └─ /meal-scan → Gemini 2.5 Flash (calories)       [gated]
```

- **Photos never persist server-side.** Edge function receives image bytes (or a short-lived signed-URL upload that is deleted immediately after inference), sends to Gemini, returns JSON, drops the image. Nothing written to Storage at rest.
- **Subscription gate:** edge functions verify an active entitlement (RevenueCat webhook → `subscriptions` table, or validate receipt) before any paid AI call. No entitlement → 402, no model call. This is the cost firewall.
- **App Attest / DeviceCheck** (optional, post-MVP) to ensure callers are genuine app instances.

### Data model (sketch)
- `profiles` — id, sex, dob/age, height, weight, goal, focus[], experience, days[], equipment, diet, attribution, created_at.
- `scans` — id, user_id, sex, aesthetic_score, rank_tier, body_fat, symmetry, potential, muscles_jsonb (6× {group, score, rank}), size_flag, verdict, confidence, created_at. **No image.**
- `plans` — id, user_id, scan_id, workout_jsonb, macros_jsonb, created_at, version.
- `workout_logs` — id, user_id, session_ref, completed_at.
- `weight_logs` — id, user_id, weight, logged_at.
- `meals` — id, user_id, calories, protein, carbs, fat, label, logged_at. **No image.**
- `subscriptions` — user_id, entitlement, status, expires_at (from RevenueCat).

---

## 7. Monetization detail

- **Plans (Cal AI model — Monthly + Annual):**
  - Monthly — **$9.99/month**, no trial.
  - Annual — **$39.99/year** (default-selected, "Save 67% · ~$0.77/week"), the LTV driver.
  - **3-day free trial on the ANNUAL plan only.** Trial-on-annual (not monthly) makes annual feel safer and lifts one-year LTV (+~35% for AI apps; Health & Fitness specifically benefits). Card required → also gates abuse.
- **Exit-intent:** dismiss attempt → one-time extra discount on annual (e.g. ~$24.99) with a countdown.
- **Paywall transparency (Apple compliance — non-negotiable):** show the **actual amount that will be billed** at least as prominently as any per-week framing, and surface **auto-renewal terms** clearly near the CTA. (Apple pulled Cal AI in April 2026 for obscuring the real price + renewal behind a weekly figure — do not repeat this.)
- **No external (Stripe) checkout** at MVP — gray-area post-*Epic* link-out, review risk. Apple IAP via RevenueCat only.
- All gating through RevenueCat entitlements; server double-checks before AI spend.

---

## 8. Safety & compliance

- **Age rating: 9+** (matching Thelo). Keep an age question in onboarding for personalization/macros, but no special age wall at launch.
- **Paywall must clearly show the real billed amount + auto-renewal terms** (see §7 — Apple pulled Cal AI over this). Treat as a compliance requirement, not a polish item.
- **On-device nudity rejection** — Apple Sensitive Content Analysis / Vision before any upload; explicit images never leave the device.
- **Athletic-wear + lighting guidance**, plus on-device **body-pose detection** to confirm a usable photo pre-paywall (never charge then fail).
- **Health disclaimer** — scores, bf%, and plans are fitness guidance, not medical/body-composition diagnosis. Surface at onboarding + in settings.
- **Privacy policy + ToS** — generate our own (Termly/iubenda/RevenueCat templates); do NOT copy a competitor's verbatim. Lead with the **ephemeral-photo** story as a trust/marketing asset ("we never store your photos").
- **GDPR/CCPA** — account + data deletion path; minimal PII.

---

## 9. Tech stack summary

- **Client:** SwiftUI, iOS 17+, iPhone portrait. Swift Concurrency (async/await). Charts via Swift Charts. Vision/AVFoundation for capture + checks.
- **Backend:** Supabase (Postgres, Auth, Edge Functions in TypeScript/Deno). RLS on all tables.
- **AI:** Gemini 2.5 Flash (scan, meal) + 2.5 Pro (plan), structured output (responseSchema), temp ~0.
- **Payments:** RevenueCat + StoreKit 2.
- **Analytics:** lightweight event tracking on the funnel (onboarding step drop-off, paywall view→trial→convert, scan complete, share). RevenueCat for subscription metrics.

---

## 10. MVP scope (v1)

**In:**
- Full onboarding funnel (questions → bluff analysis → account → paywall → real reveal)
- Body scan → score / rank / Core-6 (male + female rubrics), post-payment only
- Workout plan (weak-point targeted) + macros plan
- Workout **session** logging (not per-exercise sets) + optional bodyweight logging
- **Meal photo → calorie/macro tracking**
- Score-history progress graph (no stored images)
- Share-card export (watermarked)
- RevenueCat paywall, 3-day trial, exit-intent offer
- Safety: age gate, on-device nudity/body checks, disclaimer, ephemeral photos

**Deferred (post-v1):**
- Leaderboard / rank flex social
- Referral / invite rewards
- AI "future-you" image
- Recipes & detailed meal plans, per-exercise set logging
- Re-scan push reminders (nice-to-have early follow)
- App Attest, Android, iPad

---

## 11. Open questions / to confirm

Resolved this session: age rating = **9+**; trial = **annual only**; scan confidence = **not shown**; meal scan = **no cost cap (paid users get full access)**.

Deferred (revisit when we reach them, not blockers for the build):
1. **Female benchmark roster** — pick the reference physiques + tier anchors (doubles as content fuel).
2. **Re-scan cadence** — how often before the score meaningfully moves (avoid "scanned twice, same score" disappointment); tune once scoring is live.

---

## 12. Rough build milestones

1. **Backend skeleton** — Supabase project, schema + RLS, Apple auth, one `/scan` edge function calling Gemini with the rubric + schema. Prove a photo → JSON score end-to-end.
2. **Result UI** — port the score-card mockup to SwiftUI, wire to `/scan`.
3. **Onboarding funnel** — all screens, local state, bluff loader, FOMO.
4. **Paywall** — RevenueCat, trial, exit offer, entitlement gate on edge functions (the cost firewall + reveal trigger).
5. **Plan** — `/plan` (2.5 Pro) → workout + macros UI; session + weight logging.
6. **Meal scan** — `/meal-scan` + daily tracker.
7. **Progress + share export.**
8. **Safety pass** — age gate, on-device checks, disclaimer, privacy policy.
9. **Female rubric calibration + content benchmarks.**
10. **TestFlight → polish → submit.**
```
