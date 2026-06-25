# Stetic — account setup status (Supabase / Apple / RevenueCat)

State of the dashboard setup as of 2026-06-25. Bundle id everywhere: **`com.stetic.app`**.
For overall project status see STATUS.md.

## ✅ DONE
- **Supabase deployed live** — project `bnamfaocppltrcvnbmcv`. Migrations pushed, 4 functions
  deployed, secrets set (`GEMINI_API_KEY`, `STETIC_DEV_BYPASS_ENTITLEMENT=true`), email-confirm off.
  App `Config.swift` `useRemote=true` + publishable key.
- **App Store Connect** — app "Stetic" created. Two auto-renewable subs in a group:
  - **Stetic Weekly** — product id `stetic.weekly`, $9.99/week.
  - **Stetic Annual** — product id `stetic.anual` *(note: missing an 'n', immutable, fine)*, $59.99/year, **3-day free trial** intro offer.
  - Metadata cleared (per-sub localization + review screenshot = `app-store-assets/paywall-review-screenshot.png`).
- **RevenueCat** — App Store app added with In-App-Purchase key + App Store Connect API key.
  Entitlement **`Stetic Pro`** → both App Store products attached. Offering **`default`** →
  Weekly pkg→`stetic.weekly`, Annual pkg→`stetic.anual`. **`appl_` public SDK key pasted into
  `Config.swift → revenueCatKey`** (safe to embed; the app reads prices/packages from RC).
- **Apple Sign In** — App ID capability enabled; Supabase Auth → Providers → **Apple enabled**
  (Client ID `com.stetic.app`; native flow needs no Services ID/secret). App entitlement added,
  sign-in screen + token exchange built.
- **HealthKit** — App ID capability enabled; entitlement in app.

## ⬜ REMAINING
1. **Device test** the live flow: Apple sign-in → onboarding → scan → paywall → **sandbox Apple ID**
   purchase → confirm unlock. (Sandbox testers: App Store Connect → Users and Access → Sandbox.)
2. **RC → Supabase webhook** (not built): RevenueCat → Integrations → Webhooks → point at a new
   `rc-webhook` edge function that upserts the `subscriptions` table; then set
   `STETIC_DEV_BYPASS_ENTITLEMENT=false` so the backend cost-firewall is real.
3. **Privacy Policy + Terms** pages hosted (required for HealthKit + subscriptions); update the
   Settings links (currently placeholder `stetic.app/privacy|terms`).
4. **App Store listing** — icon, screenshots, description, keywords, age rating, category; submit
   (first subscription submits with the first binary).

## Notes
- RC **public** key (`appl_`/`test_`) = safe to ship. RC **secret** key (`sk_`) = never expose (not used).
- Keys/IDs: Team ID `8A6486RXG9`. RC appl key + Supabase publishable key live in `Config.swift`.
