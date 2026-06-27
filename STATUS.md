# Stetic — project status & handoff

> Read this first. Single source of truth for where the build is. Last updated 2026-06-26
> (food-tracking + check-in + progressive-overload session). For positioning/scoring philosophy
> see CONTEXT.md; for the conversion funnel see ONBOARDING.md; for dashboard setup see SETUP.md.

Stetic = native iOS (SwiftUI) AI physique scanner + aesthetics coach. Loop: scan a photo →
**Stetic Score** (1–10) + rank (Bronze→Greek God) + Core-6 muscle breakdown → unlock a
workout + nutrition plan (Jordan-Peters doctrine, never named) → train/eat/track → share.
Distributed via faceless TikTok. Hard paywall, 3-day trial.

## Current phase
**Feature-complete MVP; deep daily-use loop built & device-tested by Jason (meal tracking confirmed working).**
Remaining before launch is mostly verification, backend deploys of the latest functions/migrations, the
production entitlement webhook, legal pages, and the App Store listing.

## ⭐ HANDOFF — what's left (start here next session)
**Deploy / config (Jason's step — ✅ DONE 2026-06-26):**
- ✅ `supabase db push` — newer migrations: `plan_status`, `meal_type`, `meal_items`, `saved_meals`, `check_ins`, plus profile ones.
- ✅ `supabase functions deploy meal-scan plan food-search craving`.
- ✅ `FDC_API_KEY` secret set. **Google** + **Email** auth providers enabled + `stetic://auth-callback` redirect added.

**Features still to build:**
- **Aggregate-stats pipeline** (`checkin-stats` cron/fn) — real "trained-on-low-day → streak N× longer" number; gated until enough users. Post-launch.
- **Form check** (record a set → Gemini vision → cues) — postponed; strong V2/viral.
- **AI coach chat** — Gemini chat seeded with plan + scan (proposed, not started).
- **Time-based logic verification** (couldn't fast-forward days): streak grace across a real missed day, week-8 deload trigger, "Up Next" advancing, plan 8-week block finish→next. Needs a multi-day device check.
- **Exercise demos** (link-out now; evaluate free GIF set later). **Barcode/label** live device QA. **App icon** (non-marble direction). Female-rubric calibration. Real social proof. **Marketing** (MARKETING.md playbook).

**Launch blockers:** device test pass · ~~RC→Supabase entitlement webhook~~ (BUILT: `functions/rc-webhook` — deploy `--no-verify-jwt`, set `RC_WEBHOOK_SECRET`, add the webhook in RC dashboard, then flip `STETIC_DEV_BYPASS_ENTITLEMENT=false`) · ~~Privacy/Terms pages~~ (DRAFTED: `legal/privacy.html` + `legal/terms.html` — fill `CONTACT_EMAIL` + `GOVERNING_LAW_JURISDICTION`, host, update Settings links) · App Store listing.
- **Stat fix:** check-in low-day line now cites a real study (plan/implementation-intention 91% vs 39%, Milne/Orbell/Sheeran 2002) instead of the invented "2× longer".

## 📱 DEVICE TEST CHECKLIST (the remaining launch blocker)
Real iPhone required — the simulator can't do Apple sign-in or sandbox purchases.

**Prep (one-time):**
- [ ] Sandbox tester exists (ASC → Users and Access → Sandbox → Testers). Reusable across apps; make a fresh one if it acts already-subscribed.
- [ ] On the iPhone: Settings → App Store → **Sandbox Account** → sign in with the tester (NOT a real Apple ID).
- [ ] `rc-webhook` redeployed (`--no-verify-jwt`); RC "re-send test event" returns **200**.
- [ ] Keep `STETIC_DEV_BYPASS_ENTITLEMENT=true` for now (so a failed purchase doesn't lock you out).
- [ ] Delete any existing Stetic from the phone, then build+run from Xcode for a clean first-run.

**Flow:**
- [ ] **Apple Sign In** completes → lands in onboarding (verifies the in-funnel placement, never device-tested).
- [ ] Onboarding runs end to end (watch for the sim-only duplicate-CTA artifact — confirm it's ABSENT on device).
- [ ] **Scan** a real physique photo → score card renders.
- [ ] **Paywall** → buy **annual (trial path)**; separately test **weekly** (buys directly).
- [ ] Sandbox sheet → confirm → **Pro unlocks**.

**Verify the webhook end-to-end:**
- [ ] RC → Customers → sandbox user shows **"Stetic Pro" active**.
- [ ] Supabase `subscriptions` table → **row for that user_id**, status `active`/`trialing`. ✅ = webhook works.

**Turn the firewall on:**
- [ ] `supabase secrets set STETIC_DEV_BYPASS_ENTITLEMENT=false`
- [ ] One more scan as the subscribed user → still works (firewall now real).

**Also test on device:**
- [ ] Google sign-in · email sign-up/sign-in.
- [ ] **Restore purchases** (delete app → reinstall → restore → Pro returns).
- [ ] Camera meal scan + **barcode** + food-label modes (no camera in sim).
- [ ] HealthKit steps + bodyweight prompt.

## ⭐ NEW ONBOARDING — BUILT (2026-06-26, commit 967cf2a). Emotion-first, identity-driven.
Implements ONBOARDING-REDESIGN.md. Live in `OnboardingView` + `OnbScreens.swift` + `Onboarding.swift`.
Flow: name → why-here → **time-wanted slider** → what's-holding-you-back → empathy → trained-how-long →
**results-feeling** → **ever-had-a-plan** → goal → **DOOM (two roads)** → **AHA (complete physique + weak-point
silhouette)** → **TRAINING FIX (X-years + animated mountain + Tolstoy)** → **NUTRITION (freedom)** → stats (batched) →
social proof → reminders → attribution → **⭐ IDENTITY TRANSFORMATION** (trash old self from their real answers →
"You ARE…" reveal → Socrates close → "step in for free") → funnel/paywall. All screens verified on iOS 26 sim.
Preview any step: `STETIC_ONB_STEP=N` (name=0 … doom=9, aha=10, trainingFix=11, nutrition=12 … transformation=27).
**Polish candidates (optional):** richer AHA body silhouette · mountain camp/sleep beat · more dramatic trash animation · projection-payoff rework (#10, lives in the funnel/RevealFunnelView, not yet done).

## ⭐ DEVICE-TEST FEEDBACK — punch list (2026-06-26, Jason's on-device pass). NOTHING HERE GETS LOST.
**Sandbox purchase WORKED ✅** (full A-path: Apple sign-in → onboarding → paywall → sandbox buy → unlock). Lean physique scored **Mythic** — Jason is OK with it (aspirational for the target audience).

**Progress (commit f28290a):** ✅ DONE = #2 craving, #4 onboarding weight→Progress, #5 rest day, #6 Progress refresh, #9 copy, #11 weight slider (step+range; full type-field deferred to onboarding redesign), #12 scanner brackets, #13 paywall Terms/Privacy links, #14 plan disclaimer, #20 Top/Back-off labels. ⏳ REMAINING = #1 plan horizontal drag (needs live repro — root is vertical-only ScrollView, culprit not found in code), #3 keyboard dismiss (do a pass across all text-entry views), #7 scoring ceiling-compression, #8 weak-point card/plan mismatch, #10 projection tier language (folds into onboarding redesign), #15 calorie-hit animation, #16–19 onboarding redesign (drafting flow doc next).

### Bugs confirmed on device
1. **Plan view scrolls horizontally** — "Your plan" can be dragged side-to-side; should be vertical-only. Constrain the scroll.
2. **Craving button dead on first press** — tapping "Craving?" inside the Ideas sheet does nothing; it only appears AFTER you exit Ideas. Sheet-over-sheet presentation race (same family as the old meal-scan double-cover). Fix.
3. **Keyboard won't dismiss after typing** — persists over the UI. Add tap-to-dismiss / Done handling everywhere there's text entry (weight, craving, food, manual add).
4. **Onboarding bodyweight not saved to Progress** — weight entered in onboarding doesn't seed `weight_logs`; Progress shows nothing until you log again. Persist the onboarding weight as the first entry.
5. **Rest days show a workout** — Today/Up-Next shows a session on a rest day; should say "Rest day" when nothing is scheduled. (Logging on a rest day still worked + streak persisted.)
6. **Progress doesn't refresh after a scan** — a new scan didn't update Progress until switching tabs and back. Refresh on scan completion / onAppear.

### Scoring (investigated 2026-06-26)
7. **Ceiling compression — DECIDED: keep generous scoring (no change).** Jason's call (2026-06-26): the target audience (people making no progress) are happy with the lean look + high score, and each point at the higher echelon is genuinely harder to gain, so small top-end rescan movements are realistic/honest. Tier ladder stays (elite 8.0, mythic 8.8, greek_god 9.3). Minor follow-up if ever wanted: lean the "climb" framing on signals that move more for already-high users (body fat %, symmetry, per-muscle gains) rather than the headline score.
8. **Weak-point mismatch FIXED (needs deploy).** Root cause: the score card uses `scan.muscles`; the plan re-judged muscles in its OWN Gemini call (`muscle_breakdown`) → different ratings → chest weak in plan but not on card. Also card marks bottom-1 "weakest", plan marks bottom-2. Fix: plan.ts now forces `muscle_breakdown.rating` to EQUAL the scan's per-group score (no re-rating). **Needs `supabase functions deploy plan`.**

### Copy / wording
9. **Onboarding screen 4 "walk in with confidence" → "walk with confidence"** (doesn't parse). Do a wording pass on the intro screens.
10. **12-week projection tier names (Gold/Elite/Mythic) mean nothing to the target user** — rework into visceral/visual language they understand, not invented tiers. (We flagged this before.)

### UX tweaks
11. **Weight pickers** — slider doesn't stop on every pound. Add a TYPE option, and/or rescale so the slider midpoint is ~200 (not 243); 400 goal weights are rare. (Both current-weight and goal-weight screens.)
12. **Meal scanner crosshairs** — make bigger + not a perfect square; show the rounded corners (aesthetic).

### Legal / paywall (LAUNCH-RELEVANT)
13. Privacy/Terms ARE linked in Settings → About (wired this session — corrects "not linked anywhere"). BUT **Apple requires the PAYWALL itself to display Terms (EULA) + Privacy links AND the subscription price/length/auto-renew terms** — currently missing on the paywall → likely review rejection. ADD to paywall.
14. Add a visible **"not medical advice — general training guidance"** disclaimer near the plan (it's in Settings + Terms today; should sit on/near the plan screen).

### Features to add
15. **Calorie-goal-hit animation** — celebrate when daily calories are hit (esp. bulking; likely any time the target is met). New.
16. **Show the app in onboarding — the AHA MOMENT.** Today nothing captures the user pre-paywall; the offering (rank ladder, sample plan, food scanner, ideas/cravings) is all behind the wall → "we are not capturing people with anything." Add a value showcase. WHERE = open (discuss): not the first 4 screens; mid/late onboarding and/or right before the paywall.

### Onboarding redesign (bigger — Jason wants an overhaul)
17. **"Picture 6 months from now" answer options are weak** — overhaul.
18. Consider moving **"what's holding you back" earlier** (unsure vs the onboarding philosophy — discuss).
19. General overhaul of several onboarding screens; ties into #10 (projection language) + #16 (aha moment).

### Doctrine question Jason raised (answered — for reference)
20. **Different rep ranges on subsequent sets / "back-off every 2nd set" = INTENDED** (the per-set fix this session). Set 1 = heavy **TOP set** (e.g. 5-9); set 2 = **BACK-OFF** (~10% lighter, 10-12). JP doctrine, applies to compounds (not just incline DB). **Recommend labeling the sets "Top set" / "Back-off"** so it's self-explanatory — this confusion is exactly why.

## JP-doctrine audit (5 parallel Opus agents vs the PDF) — 2026-06-26
The app's **intensity** engine is faithful (low volume, ~2 working sets, every set to failure,
double-progression beat-the-logbook, compound-first, ~2×/wk, correct macro order + BMR). Misses
cluster in the **periodization/personalization** half.

**Fixed this session (pre-launch):**
- **RepRange bug** — `RepRange.perSet()` now parses multi-range reps ("5-9, 10-12, 15-20") into one range PER SET (top set vs back-off vs high-rep). The old single-range parse dropped everything after the first → progression mis-fired on every multi-range lift. Wired through SessionLogView (cards, set rows, progression, celebration).
- **Render the `note` field** — tempo 3010 / stretch / cues that `plan.ts` already generates were never shown; now rendered in PlanView split + SessionLogView exercise cards.
- **Deload corrected to doctrine** — was "drop weight to ~60%"; now KEEP the weight, stop 2 reps short of failure (3–4 on 15–20), or take the week off. No auto-add during deload; top-of-range cues suppressed; the week after naturally rebuilds then exceeds. Banner copy (Today + SessionLogView) updated.
- **Step goal 8000 → 10000** (guide says ~10k/day).
- Kept protein at 1.1 g/lb and pace-based deficit (deliberate; guide's 1.5 g/lb is high).

**Funnel idea (Jason, 2026-06-26) — "show what you get" before the paywall:** add a value-showcase right before the paywall (currently the funnel hides scan/score/plan behind the wall). A few swipeable screens previewing the actual offering: the rank ladder (Bronze→Greek God), a sample plan card, the food scanner, ideas/cravings. Give the user something tangible to say yes to. Focused funnel build; do after the device test passes.

**Exercise swap (Jason, 2026-06-26 — eventually, not now):** let users swap an exercise for a like-for-like alternative (don't like it / equipment taken / travel / time-crunch). Aligns with JP single-lift-stall doctrine (swap, return later) + the coach-gap "on-the-fly substitution." Post-launch.

**Roadmap (post-launch — real builds, NOT blocking):**
- **Phase 1/2/3 model + recovery assessment** — the guide's THESIS (Person 1 vs Person 2): split should be gated on experience + recovery (sleep/stress/life-load), not days-available. Beginners stay in Phase 1 Upper/Lower; graduate to Phase 2 PPL on a logbook stall. Onboarding asks none of this today. **#1 roadmap item.**
- **Stall handling** — single-lift stall (2 sessions no PR) → swap like-for-like, return later; multi-lift stall → that's the real deload trigger (vs the current calendar timer). History data already loaded, unused.
- **Weigh-daily → weekly-average → ±200 kcal adjust loop** — the guide's ongoing nutrition feedback mechanism; app shows noisy daily weights with no trend/nudge.
- Surface logbook history (review past sessions / per-exercise progression); record RIR + per-session sleep/stress; warm-up ramp UI; stretches as logged steps; supplements card; gate weak-point specialization to advanced lifters.

## Architecture
- **App:** `app/` SwiftUI, iOS 17+, XcodeGen (`project.yml` → `Stetic.xcodeproj`; run `xcodegen generate` after adding files). Bundle `com.stetic.app`. Theme in `Theme.swift` (stealth lime).
- **Backend:** Supabase (Postgres + RLS + Auth + Edge Functions in Deno/TS). Gemini 2.5 **Flash** (scan, meal-scan, read-split) + 2.5 **Pro** (plan — the only expensive call, ~$0.04; everything else ~$0.001–0.002). Photos NEVER stored; only derived numbers.
- **Monetization:** RevenueCat (entitlement "Stetic Pro"; products `stetic.weekly`, `stetic.anual`).

## Backend — DEPLOYED & LIVE
Hosted project `bnamfaocppltrcvnbmcv` (`https://bnamfaocppltrcvnbmcv.supabase.co`):
- All 6 migrations pushed; 4 edge functions deployed (scan/plan/meal-scan/read-split).
- Secrets set: `GEMINI_API_KEY`, `STETIC_DEV_BYPASS_ENTITLEMENT=true` (**flip to `false` before launch** once the webhook below exists).
- Apple auth provider enabled (Client ID `com.stetic.app`); email-confirm off.
- App `Config.swift`: `useRemote=true`, publishable key set, RevenueCat `appl_` key set.
- Local dev stack still works (Docker, ports +30; `useRemote=false`). DB queries: `docker exec supabase_db_LiftAI psql -U postgres -d postgres`.

## Running the app (simulator) — DEBUG env flags
Sim: iPhone 16e `43A95D7D-74E1-4491-9BD2-A26C3030D09E`. Build:
`xcodebuild -project app/Stetic.xcodeproj -scheme Stetic -destination 'platform=iOS Simulator,id=43A95D7D-74E1-4491-9BD2-A26C3030D09E' build`
Launch a screen directly via `SIMCTL_CHILD_<FLAG>=1 xcrun simctl launch <id> com.stetic.app`:
`STETIC_HOME` (home), `STETIC_TAB=0-3`, `STETIC_SESSION`, `STETIC_SHARECARD`, `STETIC_SETTINGS`,
`STETIC_SCORECARD`, `STETIC_SHOWPLAN`, `STETIC_SKIP_ONBOARDING` (funnel), `STETIC_ONB_STEP=N`,
`STETIC_GOAL=lose_fat`, `STETIC_FUNNEL_PHASE=capture|fomo|tease|paywall`, `STETIC_LOADSAMPLE/AUTOSCAN`.
Dev flags bypass the sign-in gate (use the dev account). On the sign-in screen, "Continue as dev" (DEBUG-only) is the simulator path since Apple sign-in needs a device.

## What's BUILT (verified on simulator unless noted)
- **Funnel:** intro → onboarding → capture → FOMO → bluff loader → tease → paywall → scan → score card → plan. Capture allows **optional scan** ("skip → estimate baseline from answers"). Re-scan from Progress = **progress update only** (no plan, no Pro call).
- **Onboarding:** name/sex/goal/pace/obstacles/experience/current-split(+photo OCR via read-split)/days/equipment/height/weight/goal-weight/age/activity/social-proof/attribution/reminders. Goal + pace have icon cards. Obstacle callback interstitial. (FOMO analyze-loaders were tried and removed — the with/without chart carries it.)
- **Score card** (`ScoreCardView`/`ScoreCardBody`): score "/10 Stetic Score", tier badge, verdict, body fat, symmetry, potential ("where your frame can get to", no timeline), Core-6 ranked bars, climb strip. "ESTIMATED" badge when no photo.
- **Plan** (`PlanView`): goal chip, starting point, 6/12-wk projection (cumulative gain), **structured split critique** (headline + from→to·why), macros, priorities, weekly split (JP 2-sets-to-failure), detailed muscle breakdown w/ sub-muscle status+cue, BodyMap.
- **Home/Today:** training streak, Apple Health steps card, up-next session (rest days filtered), today's fuel vs target.
- **Session logging** (`SessionLogView`): per-set weight/reps + done, **pre-fills from last session** + JP beat-the-logbook cue → `workout_logs`.
- **Food:** macros vs target, **camera-first meal scan** (`CameraPicker` → `MealScanView` animated scan: scan line, detected-item boxes, macro count-up), **manual add**, **quick-add presets** → `meal_logs`.
- **Progress:** Swift Charts score history, delta-since-last, bodyweight logging (+ Apple Health write), recent sessions, **share card** (ImageRenderer PNG → ShareLink), Settings gear.
- **Settings:** reminders toggle (schedules local notifications), Apple Health, restore purchases, Privacy/Terms links (PLACEHOLDER URLs), disclaimer, version.
- **Apple Sign In:** first-run gate, Supabase id_token grant, session persists (refresh token), returning+onboarded → home. Entitlement added. (Verify on device.)
- **RevenueCat:** SDK + `PurchaseManager`, paywall pulls real RC prices, purchases selected package, gates on "Stetic Pro", restore. Falls back to built-in prices + dev path when no key/sim. (Verify on device.)
- **HealthKit:** steps read + bodyweight read/write, gated behind a tap. Capability KEEP (enabled on App ID).

## What's LEFT
**Before launch (blocking):**
1. **Device test** the full flow: Apple sign-in → onboarding → scan → paywall → sandbox purchase → unlock. (Not yet done.)
2. **RC → Supabase webhook** edge function (RC events → upsert `subscriptions`), then flip `STETIC_DEV_BYPASS_ENTITLEMENT=false` so the backend firewall is real. **NOT built yet.**
3. **Real Privacy Policy + Terms pages** (HealthKit + subscriptions require them). Settings links are placeholders. (Offer: draft them.)
4. **App Store listing:** icon, screenshots, description, keywords, age rating, category. First subscription submits with the first binary.

**Product / polish (next session):**
5. **Female rubric calibration** (only male calibrated — needs a few female physique photos).
6. Replace placeholder social proof ("12,000+", testimonials) with real numbers/reviews.
7. One real end-to-end scan to sanity-check scoring accuracy now the flow is settled.
8. **Backlog:** food database + sample meal plan; sign-out in Settings; exercise demos (text only today — normalize plan exercise names to a canonical aesthetic-movement vocab before adding a GIF library v1.1; form-check deferred to V2).

**Polish done (2026-06-25, transcript-teardown session):**
- **Scan consistency cache** — same photo set+sex now returns the stored card instead of re-calling Gemini (which drifts run-to-run even at temp 0). New migration `…130000_scan_photo_hash.sql` (adds `photo_hash` col) + lookup wired in `scan/index.ts` via the existing `photoSetHash()`. **Needs `supabase db push` + `functions deploy scan` to the live project to take effect.**
- **Meal scan** temp `0.2 → 0` (less calorie jitter on the same plate). **Needs `functions deploy meal-scan`.**
- **Affirmation screen 1** — gender-neutral reaffirm interstitial added before `name` (`OnbStep.affirm`). Shifts `STETIC_ONB_STEP` indices by +1.
- **Capture photo preview** no longer crops — `scaledToFill → scaledToFit` over the card (`RevealFunnelView` photoSlot).
- ⚠️ **Verify on device:** all onboarding interstitials (affirm/callback/socialProof) show a faint duplicate of the CTA near the top **in the simulator only (suspected)**. Tracks purely with the button's presence; survives every layout variant — looks like a sim rendering artifact. Pre-existing on callback/socialProof. Confirm it's absent on real hardware during the device-test pass.

**Funnel restructure + onboarding gaps (2026-06-25, part 2):**
- **Sign-in moved to the END** (right before the paywall), per SPEC §2 + PrayerLock/PuffCount. `ContentView` no longer gates on sign-in: new users go `intro → onboarding → funnel`, and `OnboardingView` now hands answers up (no save) — they're held in `ContentView.pendingProfile` and persisted via `saveProfile` only **after** sign-in inside `RevealFunnelView` (new `.signin` phase). Returning onboarded users still skip to home.
- **Fixed onboarding save crash** — `activity_level`/`pace` columns were missing (empty macro-fields migration); added `…140000_add_profile_activity_pace.sql`. **Needs `supabase db push`.**
- **Personalized FOMO** — projection now computed from their answers (experience/activity) showing "Likely plateau: X → Your potential: Y" tier pills + name.
- **Trial mechanics** — new `.trialReminder` screen ("we'll remind you", Today/Day 2/Day 3 timeline) between the paywall CTA and purchase (annual only; weekly buys directly). Paywall header personalized ("Your plan is ready, {name} · Built for people exactly like you").
- **Intro copy** sharpened to name the lean/movie-star promise + "smart programming, not bro science."
- **Haptics** on onboarding sliders + step transitions.
- Dev screenshot flags: `STETIC_FUNNEL_PHASE=signin|trial` added.
- ⚠️ Apple Sign In still needs a **device** to verify the new in-funnel placement (sim uses "Continue as dev").

**Onboarding content + meal scanner (2026-06-25, part 3):**
- **Welcome checkmark is now the true first screen** (`WelcomeView`, before the intro). Pulled out of onboarding.
- **Onboarding questions consolidated:** removed the redundant "what brought you here" (motivation) step and the focus step from the main flow; **obstacles upgraded** to real gym pain points (don't know what to do / can't stay consistent / train hard but look same / hours for little result / plateau / lost or intimidated) with matching stat callbacks.
- **Focus moved to the no-photo path only** — new `.focusPick` screen ("No photo? No problem.") shows when they Skip the scan; saved into the profile + used by `estimateScan` (focus areas estimated as lagging/priority).
- **Meal scanner reworked to Cal AI style** (`MealScanView`): scan → loading (no jarring error) → editable results card: photo, name, **servings stepper**, big calories, macro chips, **ingredient list you can add / edit / remove**, totals recompute live. Failure now lands in the editor (add manually) instead of a dead-end error.
  - `meal-scan` edge function + `MealEstimate` now carry **per-item macros**; decode is resilient (falls back to totals) so it works pre-deploy. **Needs `supabase functions deploy meal-scan`** for per-ingredient calories.
  - **Still TODO:** edit/delete an *already-logged* meal (tap a row in Nutrition) — not built yet; food catalog (free API: USDA FoodData Central / OpenFoodFacts — $0; paid Nutritionix/Edamam not needed) for richer "Add food".
- **Dev test affordances:** `STETIC_HOME=1 STETIC_TAB=2` → straight to Food tab (no funnel/paywall, reuses cached plan, no regen); **"Dev: skip paywall →"** button on the paywall (DEBUG); `STETIC_MEALSCAN=1` previews the meal results screen with sample data.
- New migration `…150000_add_profile_motivation.sql` (kept; client only writes it when non-empty, so safe pre-deploy).

**Requested roadmap (not built yet — 2026-06-25, part 4):**
- **Sign-in options** — Apple can't be the only one. Add **Google + email** (Supabase: enable Google provider + OAuth client; enable Email). Phone = skip (SMS cost). Apple-only today.
- **Food APIs / catalog** — all free: `food-search` edge fn → USDA FoodData Central (whole foods) + OpenFoodFacts (barcodes). **Barcode scan** (camera→OpenFoodFacts), **label scan** (Gemini OCR), text search, built-in common-foods list. Feeds the meal editor's "Add food". Fixes the per-item 0-cal once `meal-scan` is also deployed.
- **Meal log like MyFitnessPal** — `meal_type` (breakfast/lunch/dinner/snacks), group day by type, add-to-meal via scan/search/saved, **saved meals** table, **sample meals** per goal, optional scheduled meal reminders.
- **Progressive overload feature** — surface the JP double-progression target ("hit top of range to failure → add smallest load"); track top-of-range hits. **Rest timer** in the logbook (easy).
- **Deload prompt** — JP says deload every ~8–12 wks; show a banner/reminder based on weeks since plan start.
- **Exercise demos** — don't hand-draw (not sleek); link-out "see how" now, evaluate a free GIF set (free-exercise-db / wger, check license) later.
- **Form check** (WrestleAI-style) — record a set → Gemini video analysis + cue rubric. Moderate effort (video capture + token cost + per-lift rubric). Strong V2/viral feature.
- **FOMO stat** — "likely plateau Gold → potential Diamond" is meaningless pre-scan; replace with a real sourced stat (e.g. people who train without a plan / quit rate) and keep tier projection for AFTER the real scan.
- **Capture now has a camera option** (built); physique scan can shoot or pick from library.
- Note: progress *photos* comparison conflicts with the ephemeral-photo privacy stance — decide before building.

**Open design picks for Jason:** app-icon direction — 20 mark concepts + 10 statue concepts mocked; SVG statues were too stick-figure, so use the **image-gen prompt** (marble David-style statue, lime rim-light/kintsugi) to generate the real icon, then refine + export into `Assets.xcassets`.

## Pricing (current)
Weekly **$9.99/wk** + Annual **$59.99/yr** ($1.15/wk, "SAVE 88%", 3-day trial). Two tiers, no monthly. Prices now flow from RevenueCat; the in-app numbers are fallbacks. Still open to revisit.

## Progressive overload + Today calendar + meal-scan polish (part 5)
- **Progressive overload (SessionLogView):** each exercise shows its rep-range target pill + "Last: w×r" line; per-set "last N" to beat; beating last reps or hitting the top of range fires a green pulse + haptic + inline "you're going up next session" banner; finishing shows a celebration overlay listing exercises to add weight to. `LoggedExercise.repRange` added (optional, back-compatible); `RepRange` parser in LogModels.
- **Today week strip:** current-week 7-day calendar — logged days = green check, scheduled-but-missed = ✕, today = ring, rest = muted. Edit opens `ScheduleSheet` (pick training weekdays + reminder time → `NotificationManager.setTrainingReminders`). Stored in AppStorage (`trainWeekdays`, `trainHour`).
- **Deload banner:** JP doctrine ~8 wks. Shows when weeksTraining ≥ 8 (anchored to first workout or last deload); "Done" resets the 8-week clock (`deloadAnchor`).
- **Meal scan:** fixed status-bar overlap (ZStack so content respects safe area, was floating under the clock/X); sleeker scan animation (targeting grid + sweeping line + detection nodes that light up + walking status steps); fixed results-photo framing.

## Coach-gap review (from the "what a coach does" research) — not yet built
Covered: programming, nutrition+scan, progress, weak points, accountability (streak+timed reminders), onboarding/assessment, celebrations. **Gaps worth considering:** (1) **workout adjustment/swap** — "only have dumbbells today / traveling / 30 min" on-the-fly substitution (real coach behavior we lack); (2) **weekly check-in** that nudges macro/volume adjustments; (3) **community/challenges** later (retention lever). Niche/identity = marketing, already our positioning.

## Food block + sign-in expansion + scan/schedule polish (part 6)
- **Meal types:** Food tab grouped into Breakfast/Lunch/Dinner/Snacks (each with Scan / Search / Manual / Upload). `meal_logs.meal_type` (migration 20260625170000); `logMeal`/`updateMeal` send it with a pre-migration fallback.
- **Edit logged meal:** tap any meal row → edit fields + meal-type + delete (`updateMeal`).
- **Food search:** `food-search` edge function (USDA FoodData Central + OpenFoodFacts, both free; `FDC_API_KEY` optional, falls back to DEMO_KEY). `FoodSearchView` wired into "Add more" (scan) and section "Search foods". Barcode supported by the function (client barcode UI = follow-up).
- **Sign-in:** added Google (Supabase OAuth via ASWebAuthenticationSession, scheme `stetic://auth-callback`) + email/password (sign-up/in) alongside Apple. URL scheme added to Info.plist.
- **Meal scan:** loader verified in the real fullScreenCover; upload path now defers presentation so the loader shows; photo removed from results screen.
- **Today:** one session/day for real users (DEBUG can re-log); schedule locked to the plan's day count; default training weekdays are spaced (Mon/Wed/Fri etc.).

### Deploy / config needed (user's step)
- `supabase db push` — migrations 20260625160000 (plan status) + 20260625170000 (meal_type).
- `supabase functions deploy food-search`.
- Supabase Auth: enable **Email** provider; enable **Google** provider (OAuth client) and add redirect URL `stetic://auth-callback` to allowed URLs.
- Optional: set `FDC_API_KEY` secret for USDA (else DEMO_KEY, rate-limited).

## Cal AI capture + barcode/label + sample meals (part 7)
- **FoodCameraView:** custom AVFoundation camera, Cal AI-style — live preview, modes **Scan Food / Barcode / Food Label**, STETIC branding, "?" accuracy disclaimer, flash, capture button, photo-library shortcut. Barcode auto-detects (AVCaptureMetadataOutput). Graceful no-camera fallback (simulator) keeps the library button usable. Needs **device QA** (no camera in sim).
- **Modes wired:** Scan Food → meal-scan (`mode:"meal"`); Food Label → meal-scan (`mode:"label"`, reads the nutrition panel per-serving); Barcode → `searchBarcode` (OpenFoodFacts) → results with servings stepper. meal-scan function now branches prompt on `mode`.
- **Sample meals:** `MealIdeasView` — 16 curated high-protein meals by type, one tap logs to today. "Ideas" button next to "Scan a meal".
- **Dev:** STETIC_FOODCAM=1 previews the capture overlay.

### FDC key (answered)
USDA via DEMO_KEY = ~30 req/hr (rate-limits at volume). Get a free `FDC_API_KEY` (api.data.gov) for 1,000/hr; OpenFoodFacts has no key (fair-use). Recommend setting `FDC_API_KEY`.

### Still open
- **Light mode** — deferred (whole app themes off `Theme` dark constants; real effort). Confirm before building.

## Food polish: saved meals, meal reminders, camera crash fix (part 8)
- **Camera crash fixed:** tapping Barcode set `metadataObjectTypes` to types not yet available (empty pre-config / simulator) → NSException. Now filtered to `availableMetadataObjectTypes` and applied only after the output is wired.
- **STETIC** wordmark on the camera is now lime.
- **Saved meals:** `saved_meals` table (migration 20260626120000) + `saveMeal/savedMeals/deleteSavedMeal`. Bookmark button on the scan results saves the combo; section "+" → "Saved meals" → one-tap re-log; delete from the list.
- **Meal reminders:** bell on the Food header → `MealRemindersView` (per-meal toggle + time) → `NotificationManager.setMealReminders` (daily "time to eat" notifications). Stored in AppStorage.
- **Add menu simplified:** section "+" = Scan a photo / Search or add food / Saved meals. Dropped standalone Upload (camera has library) and Enter-manually (now lives inside search as "Create a food manually").

### Deploy / config (user's step)
- `supabase db push` (saved_meals migration).
- `FDC_API_KEY`: production → `supabase secrets set FDC_API_KEY=...`; local → `supabase/functions/.env` + `functions serve --env-file`.

## AI craving feature (part 9)
- **"Craving something?"** on the Food tab → `CravingView`: craving input + quick chips + an **intensity slider** (Lightly / Mildly / Badly). Badly = the real thing (In-N-Out-style), Mildly = lighter homemade, Lightly = macro-friendly remake. 80/20 framing.
- **`craving` edge function** (Gemini 2.5 Flash): given craving + intensity + remaining macros + goal → returns the food + realistic macros + a fit tip + 1-3 "make room" adjustments to other meals. Result card → "Log it" / "Try again".
- ScanAPI.craving(); CravingResult model. Dev: STETIC_CRAVING=1.
- **Deploy needed:** `supabase functions deploy craving` (uses existing GEMINI_API_KEY).

## NEXT: Full MyFitnessPal food model (chosen, not yet built)
User chose the full model. To build: a user **Food catalog** (create manually or by label scan; foods are reusable), a staging **Cart** (add foods + portions), then **assign to a meal/time** and optionally **save the combo as a Meal**. Big data-model change — own focused build. Also: consider upping protein ratio / trimming carbs in `plan.ts` (current split is carb-heavy, ~414g).

## Craving v2 + protein 1.1 + step animation + daily quotes (part 10)
- **Protein → 1.1 g/lb** in `plan.ts`. Static macro guidance added to PlanView: "hit calories daily; protein is the priority; carbs/fat flex; treat as averages." (Consistent w/ JP: calories master lever, protein priority, carbs/fat flexible.)
- **Craving v2:** function now reasons about REMAINING calories — `fits_today` verdict, `ingredients` (how to make it), `adjustments` (fit today) OR `tomorrow_plan` (per-meal budget for tomorrow when it doesn't fit). Cooler animated "cooking" loader (pulsing rings + cycling steps). Result card shows verdict (lime/amber), ingredients, and the right plan block.
- **Ideas & cravings:** renamed Ideas button; craving lives inside that sheet now (removed standalone button).
- **Step goal animation:** steps card shows a progress ring toward the goal; hitting it flips to a checkmark + "Goal hit — streak safe" and flares the streak flame (steps kept the streak alive).
- **Daily quote** card on Today (stoics / disciplined figures; rotates daily). `Quotes.swift`.
- **Deploy:** `supabase functions deploy craving` (updated). Re-generate a plan to get the 1.1 protein split.

## Daily readiness check-in (part 11)
- **3-tap check-in** (`CheckInView`): mood, confidence in the goal, readiness ("Feel like training today?" on training days → "…sticking to your plan?" on off days). Stored in `check_ins` (migration 20260626140000, one row/day upsert). Card on Today when not done today.
- **Motivation engine:** low-day nudge ("this is the day that counts — motivation comes after you start" + one-tap Start session); **your own history** ("the last N times you felt like this you showed up X×"); **mood-tailored quote** (`Quotes.forReadiness` — hard-day set: James Clear "never miss twice", C.S. Lewis, Tolstoy, Earl Nightingale, Marcus Aurelius).
- **Aggregate social proof: NOT shipped** — needs a real stats pass over all `check_ins` (no invented numbers per the no-fake-stats rule). TODO: a `checkin-stats` edge function returning real "trained-on-low-day kept streak longer" aggregates.
- ScanAPI.saveCheckIn/recentCheckIns. Dev: STETIC_CHECKIN=1.
- **Deploy:** `supabase db push` (check_ins migration).

## Ingredient-based meals + streak grace + check-in polish (part 12)
- **Ingredient-based meals (MFP-style):** `meal_logs.items` jsonb (migration 20260626160000). Logging stores the component foods (scaled by servings); a single food synthesizes one item. New **`MealDetailView`**: tap a logged meal → see its foods, edit/remove/add per-food, change meal type, **bookmark to save the combo** as a saved meal, or delete. Totals = sum of foods. Replaces the old opaque edit sheet. `updateMeal`/`logMeal` carry items with a pre-migration fallback.
- **Streak grace (James Clear "never miss twice"):** one missed day forgiven; two in a row resets. `Streak.count` rewritten; `graceActive` drives an amber "Grace day — act to keep it" state. Tappable streak card → `StreakInfoSheet` (grace, never-miss-twice, **don't compensate — just hit today's plan**).
- **Step goal copy** reframed as the harder commitment (on rest days you must hit steps or risk the streak; one grace day).
- **Check-in:** emoji mood scale (renders on device), low-day adds the "train on a low day → streak ~2× longer" social-proof line (placeholder stat, update with real data later).
- **Quote moved:** off the bottom of Today; now the completed check-in summary card (with the day's quote) sits at the bottom, and the check-in prompt is at the top until done.

### Deploy (new this round)
- `supabase db push` for: `check_ins`, `saved_meals`, `meal_type`, `plan_status`, `meal_items` migrations.
- `supabase functions deploy craving food-search meal-scan`.

### Still open / next
- Aggregate social-proof real stats pipeline (`checkin-stats` fn) to back the 2× claim.
- Optional: "build a combo across separately-logged foods" (cart/multi-select) — current path is build-the-combo-in-one-meal-then-save.
- Light mode (deferred).

## Bug fixes + combine-to-meal + JP sets (part 13)
- **Snacks bug fixed:** logMeal/updateMeal bundled items+meal_type, so when the (undeployed) items column 400'd it dropped meal_type too → defaulted to 'other' → Snacks. Now tiers down independently (items+type → type → minimal) so meal_type always saves.
- **Upload loader fixed (root cause found):** two `fullScreenCover`s on one view (camera dismiss → scan present via onChange) stalled the second presentation, skipping the loader. Reproduced on the simulator. Replaced with **`FoodCaptureFlow`** — one cover that switches camera→scan internally (view-tree swap fires MealScanView's `.task` → loader always shows). FoodCameraView no longer self-dismisses on capture.
- **Combine to meal:** each meal section "+" → "Select & save as a meal" → multi-select logged items → name → saves the combined foods to saved_meals. MealDetailView's save is now a clear "Save this as a meal" button (not a vague bookmark).
- **JP abs sets:** plan.ts said "Abs = 4 sets" (contradicted the 2-working-set doctrine). Changed to "2-3 sets of 15-20." Re-generate a plan to apply.

## Food deep-fix: loader, portions, ingredient breakdown (part 14)
Investigated with 3 parallel Opus agents, then fixed:
- **Scan loader (root cause):** `FoodCaptureFlow` swapped camera→scan with `withAnimation`, cross-fading the subtree and swallowing the loader frames. Fixed: wrap body in a ZStack, drop the animation on the phase change, give `MealScanView` a stable `.id` so it mounts fresh and its `.task` drives the loader. Verified on the simulator (loader shows during the swap).
- **Portion editing:** `MealEstimate.Item` gains `quantity` + `unit` (backward-compatible, decodeIfPresent + parsePortion). Unified editor (`FoodItemEditor`, used by both MealScanView and MealDetailView; old duplicate ItemEditor removed) now has a **quantity stepper + unit picker (serving/g/oz/cup/tbsp/piece/ml)** that **rescales macros proportionally**. FoodHit seeds qty/unit from its catalog portion.
- **Ingredient breakdown:** `meal-scan` prompt rewritten to BREAK a composite food into its components (burger → bun/patty/cheese/sauce; salad → greens/chicken/dressing), 2–6 main contributors, simple foods stay one item. Schema/UI already supported N items. **Needs `supabase functions deploy meal-scan`.**

## Food editing UX refinement (part 15)
- **FoodItemEditor:** typed measure field (quantity) + unit picker; macros **auto-calculate** from the food's per-unit data as you change the amount (read-only tiles). Manual new-food path still allows entering macros once.
- **MealDetailView:** removed the name typer and the meal-type segmented picker (name/type now read-only header). Foods remain tappable→edit (you reach this by opening a meal from its section). "Save as a meal" now opens a **category food-selector** (`CombineFoodsSheet`) — deselect any foods in that category, name it, save the combo.
- **MealScanView (scan results):** ingredient rows are **view-only** (with remove + add) — no tap-to-edit; portions are edited after logging via the meal section.
- Combine flow rewritten to operate on the category's flattened foods (replaces the meal-row multiselect).

## Meal = the category (Option B) + scan meal picker (part 16)
- **The meal IS the category.** Food tab sections now show foods INLINE (flattened across entries, display-only) with an **"Open ›"** on the header. Tapping individual foods does nothing; "Open" drills in.
- **`MealCategoryView`** — titled just "Breakfast" (etc.), lists all the category's foods, tap a food → edit (typed measure + auto-calc), remove, "Add food", and **"Save breakfast as a meal"** → CombineFoodsSheet. Edits map back to the underlying meal_log entries (edit/remove rewrites that entry; add creates a single-food entry).
- **Scan meal-type picker:** the scan results screen now has a Breakfast/Lunch/Dinner/Snacks segmented picker above "Add to today."
- MealDetailView retired from the flow (FoodItemEditor still shared).

## Aggregate-stats pipeline (proposed, post-launch)
`checkin-stats` edge fn / nightly cron over all users' check_ins + workout_logs → anonymized aggregate (e.g. real "trained-on-low-day → streak N× longer"), gated until enough data. Replaces the hardcoded 2× placeholder. Build after there are users. (Light mode: dropped per user.)

## Git
Commit + push directly to `main` (never auto-branch). Recent work all on `main`.
