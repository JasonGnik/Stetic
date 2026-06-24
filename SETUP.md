# Stetic — account setup (RevenueCat + Apple)

What you need to do in the web dashboards so the paywall + Apple Sign In aren't blocked when we
reach them. Do these when you have ~30 min; none block the screens I'm building now.

Bundle id everywhere: **`com.stetic.app`**

---

## 1. App Store Connect — create the app + subscription products

1. **App Store Connect → Apps → +** → New App. Platform iOS, name "Stetic", bundle id `com.stetic.app`
   (create the App ID first in Apple Developer → Certificates, IDs & Profiles → Identifiers if needed,
   with **Sign In with Apple** capability checked).
2. **Subscriptions** (App Store Connect → your app → Monetization → Subscriptions):
   - Create a **Subscription Group**: "Stetic Pro".
   - Add two auto-renewable subscriptions in that group:
     - **Weekly** — product id `stetic_weekly`, price $7.99/week.
     - **Annual** — product id `stetic_annual`, price $119.99/year. Add an **Introductory Offer →
       Free Trial → 3 days** on this one only.
   - (Optional, for exit-intent) a second annual at $59.99 OR handle the discount via a promotional
     offer later. Simpler to start: one weekly + one annual w/ trial.
   - Fill required metadata (display name, description, review screenshot). Status can sit at
     "Ready to Submit" — they get reviewed with the app's first submission.
3. Generate an **App-Specific Shared Secret**: App Store Connect → your app → App Information →
   (or Users & Access → Integrations → In-App Purchase) → copy it for RevenueCat.

## 2. RevenueCat — wire the products (you already made the project)

1. **Project → Apps → + New** → Apple App Store. Bundle id `com.stetic.app`. Paste the **App-Specific
   Shared Secret** from step 1.3.
2. **Entitlements → +** → identifier `pro`.
3. **Products → +** → add `stetic_weekly` and `stetic_annual` (must match App Store product ids).
   Attach both to the `pro` entitlement.
4. **Offerings → +** → identifier `default`. Add two **packages**: Weekly → `stetic_weekly`,
   Annual → `stetic_annual`. Make Annual the default.
5. **API Keys** → copy the **Public SDK Key (Apple)** — this is the only thing the app needs.
   **Send me that key** (it's a publishable key, safe to embed).
6. (Later, I'll set up) **Integrations → Webhooks** → point at a Supabase edge function so an active
   purchase writes to the `subscriptions` table (server-side entitlement = the cost firewall).

## 3. Apple Sign In (for account creation)

1. **Apple Developer → Identifiers → `com.stetic.app`** → ensure **Sign In with Apple** is enabled.
2. In Xcode you'll need to set your **Development Team** on the target (Signing & Capabilities).
   Tell me your Team ID, or set it in `app/project.yml` (`DEVELOPMENT_TEAM`).
3. **Supabase → Authentication → Providers → Apple** → enable. You'll need: a **Services ID**, your
   **Team ID**, a **Key ID** + the **.p8 private key** (Apple Developer → Keys → + → Sign in with
   Apple). I'll walk you through generating these when we wire the account screen.

---

## What I need from you to unblock the paywall

- The **RevenueCat Public SDK Key (Apple)** (step 2.5) → I add the SDK + paywall.
- Confirm the **product ids + prices** above (or give me your preferred ids/prices).

Everything else (Apple Sign In provider config) we do together when we build the account screen.
