# Stetic — project status & handoff

> Read this first. Single source of truth for where the build is. Last updated end of the
> deploy/monetization session (2026-06-25). For positioning/scoring philosophy see CONTEXT.md;
> for the conversion funnel see ONBOARDING.md; for dashboard setup see SETUP.md.

Stetic = native iOS (SwiftUI) AI physique scanner + aesthetics coach. Loop: scan a photo →
**Stetic Score** (1–10) + rank (Bronze→Greek God) + Core-6 muscle breakdown → unlock a
workout + nutrition plan (Jordan-Peters doctrine, never named) → train/eat/track → share.
Distributed via faceless TikTok. Hard paywall, 3-day trial.

## Current phase
**Feature-complete MVP; backend deployed live; monetization wired.** Remaining before launch is
mostly verification (device test), the production entitlement webhook, legal pages, and the App
Store listing. Next session = **app polish** (Jason has YouTube onboarding transcripts to break down).

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

## Git
Commit + push directly to `main` (never auto-branch). Recent work all on `main`.
