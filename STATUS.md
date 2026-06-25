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
8. **Backlog:** food database + sample meal plan; sign-out in Settings; refine onboarding from Jason's transcript teardown.

## Pricing (current)
Weekly **$9.99/wk** + Annual **$59.99/yr** ($1.15/wk, "SAVE 88%", 3-day trial). Two tiers, no monthly. Prices now flow from RevenueCat; the in-app numbers are fallbacks. Still open to revisit.

## Git
Commit + push directly to `main` (never auto-branch). Recent work all on `main`.
