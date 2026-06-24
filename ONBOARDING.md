# Stetic — Onboarding / Conversion Funnel (blueprint)

Synthesized from teardown of **PrayerLock, WrestleAI/RusselAI, ProgramAI, Cal AI** (Jason's
dictations) + `SPEC.md` §4 + the Jordan Peters doctrine. This is the screen-by-screen plan
for the cinematic funnel. The functional stat-capture screens already exist (`OnboardingView`);
this wraps them in the conversion engine.

---

## The universal funnel skeleton (what all 4 winners do)

1. **Cinematic intro / demo** — show what it does, "powered by computer vision."
2. **Feature highlight screens** — flash the app's surfaces (scan, plan, progress).
3. **Name entry early** — personalization ("Jason, …") buys investment.
4. **Question screens** — identity, habits, goals. Each tap = sunk cost.
5. **The shock/FOMO stat** — computed from THEIR answers ("you'll spend X years on your phone",
   "78% less likely to miss weight", projected-growth chart *with vs without*). The emotional peak.
6. **Stat callbacks per answer** — pick "I plateau" → instantly show a stat that validates the pain.
7. **Social proof everywhere** — reviews, "X bodies analyzed", sprinkled between questions.
8. **Personalized affirmation** — "You're in the right place. Thousands started exactly here."
9. **Bluff build/loader** — a long, beautiful "analyzing/building" animation (reviews shown during it).
10. **"Your … is ready"** — tease the result (blurred/locked).
11. **Account** — Sign in with Apple.
12. **Paywall** — 3-day trial, weekly **or** annual (annual heavily discounted), exit-intent → extra
    ~50% off annual with a countdown ("you've been selected").
13. **Sprinkles** — commitment/signature, "how did you hear about us", rate-app prompts.

> Takeaway: the product is the *reveal*; the funnel's job is to make the user **invest** (answers,
> photo, name) and feel a **specific, personal gap** before the paywall. Numbers, not vibes.

---

## Stetic funnel — screen by screen

> Rule: **no AI spend before subscribe.** Every "analysis" pre-paywall is computed from answers or
> a bluff animation. The real Gemini call fires only on successful trial start (`SPEC.md` §4.21).

1. **Cinematic intro** — black, lime. "The naked eye misses the patterns. Stetic finds them."
   3-beat demo: scan → score → plan. Tagline: "the AI coach for a Greek-god physique, not an
   Olympia gut." *Powered by computer vision.*
2. **Feature highlights** (3 quick screens): the score/rank gotcha · the JP weak-point plan ·
   the re-scan progress climb.
3. **Name** — "What should we call you?" → personalizes everything after ("Jason, …").
4. **Identity** — Male / Female *(routes rubric)*. ← existing screen
5. **Primary goal** — lose fat / build muscle / both. ← existing
6. **Obstacles** (multiselect) — "I plateau", "I don't know what to train", "I train hard but look
   the same", "intimidated in the gym". → drives stat callbacks + the plan's split critique.
7. **Stat callback / value interstitial** — based on obstacle, e.g. "I plateau" → *"73% of guys who
   stall are over-training their strong muscles and under-training their weak ones."* (JP-true, on-brand.)
8. **Experience · Days · Equipment** ← existing
9. **Stats** — height (ft) · weight (lb) · age ← existing
10. **Social proof** — reviews carousel + "**X,XXX physiques analyzed**" (placeholder stat).
11. **Attribution** — "How did you hear about us?" (TikTok / IG / YouTube / App Store / friend) → marketing data.
12. **Scan capture** — instructions (athletic wear, good lighting), capture up to 3 (front nudged,
    side/back optional). **Say why:** "More angles = a sharper, more honest read." On-device
    body + nudity check before proceeding. Photos held locally, NOT sent yet.
13. **FOMO / shock moment** — the peak. A projected chart **"with vs without Stetic"** over 6 & 12
    weeks (reuses the plan projection logic, numbers-only), and/or a teaser computed from answers:
    *"At your current training, you'll plateau around Gold. Your weak points are capping a 2.4-point
    jump you're leaving on the table."*
14. **Bluff analysis loader** — the `ScanningLoader` (reticle/scan animation) with "why" stages
    ("Mapping your frame → Reading proportions → Finding weak points → Building your plan") + rotating
    review cards / case-study cards. ~6–10s. **NO AI CALL.**
15. **"Your analysis is ready"** — blurred score card + locked summary: *"We found 3 lagging groups
    and 1 proportion breaking your frame. Unlock to see your score, rank, and plan."*
16. **Account** — Sign in with Apple (creates account; local answers persist to it).
17. **Paywall** — RevenueCat. **Weekly $7.99 / Annual $119.99** (annual default-selected, "Save 80%",
    **3-day free trial on annual only**). Show the **real billed amount + auto-renewal terms** near the
    CTA (Apple compliance — non-negotiable). Exit-intent → **$59.99/yr** one-time with a countdown
    ("you've been selected").
18. **On subscribe → REAL scan** — now send photos to Gemini, score, generate plan, **reveal**.

---

## "More stats" — the FOMO inventory (fill with real/marketing numbers later)

- "**12,480 physiques analyzed** this week" (live-ish counter).
- "The average man scores **5.8** — and sits **2.3 points** below his potential."
- Obstacle callbacks: plateau → 73% over-train strong parts; "look the same" → "volume without
  intensity is why" (JP); intimidated → "every plan here is built for your level."
- Projected-results chart: your line *with* vs *without* Stetic (6 & 12 wk), same engine as the plan
  projection — credible, not hype.
- Rank-ladder teaser: "You're a few points from **Diamond**. Here's the climb."

> ⚠️ All specific percentages above are PLACEHOLDERS for marketing to set with real data. Don't ship
> invented stats as fact — frame as ranges or label them, or back them with actual app data once live.

---

## Build order

**Buildable now (no accounts):** intro, feature highlights, name, obstacles + stat callbacks,
social proof, attribution, scan-capture screen, FOMO chart, bluff loader, "analysis ready" tease.
**Blocked on accounts:** account (Apple Sign In) + paywall (RevenueCat / App Store products) — see
`SETUP.md`. We build the screens and stub these two until the accounts are wired.

**Pricing (current intent, Thelo model):** weekly $7.99 · annual $119.99 · exit $59.99 · 3-day trial
on annual. Easy to change in RevenueCat without an app update.
