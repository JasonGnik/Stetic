// POST /rc-webhook — RevenueCat → Supabase entitlement mirror.
//
// RevenueCat sends an event whenever a subscription changes (purchase, renewal,
// trial start, cancellation, expiration, billing issue). We upsert the result
// into `subscriptions`, which is the table the cost firewall in scan/plan/etc.
// reads to decide whether to run the (paid) Gemini calls.
//
// app_user_id == the Supabase auth user id, because the app calls
// Purchases.logIn(<supabase user id>) on sign-in (see PurchaseManager.identify).
//
// Auth: RevenueCat sends the Authorization header you configure in its dashboard.
// We compare it to the RC_WEBHOOK_SECRET secret. This function must be deployed
// with --no-verify-jwt (RevenueCat does not send a Supabase JWT).

import { createClient } from "jsr:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  // ── verify the shared secret RevenueCat is configured to send ──
  const expected = Deno.env.get("RC_WEBHOOK_SECRET");
  if (!expected || req.headers.get("Authorization") !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  let body: { event?: Record<string, any> };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }

  const event = body?.event;
  const userId = event?.app_user_id as string | undefined;
  if (!event || !userId) return json({ error: "no event/app_user_id" }, 400);

  const type = String(event.type ?? "");

  // RevenueCat "Send test event" + test pings + anonymous ids — acknowledge, don't write.
  if (type === "TEST") return json({ ok: true, test: true });
  if (userId.startsWith("$RCAnonymousID")) return json({ ok: true, ignored: "anonymous" });

  const periodType = String(event.period_type ?? "");      // TRIAL | NORMAL | INTRO
  const entitlements: string[] = event.entitlement_ids ?? (event.entitlement_id ? [event.entitlement_id] : []);
  const expiresMs = Number(event.expiration_at_ms ?? 0);
  const expiresAt = expiresMs > 0 ? new Date(expiresMs).toISOString() : null;
  const stillValid = expiresMs > 0 && expiresMs > Date.now();

  // Terminal events => not entitled, regardless of the timestamp.
  const terminal = ["EXPIRATION", "SUBSCRIPTION_PAUSED"].includes(type);

  let status: string;
  if (terminal || !stillValid) status = "expired";
  else if (periodType === "TRIAL") status = "trialing";
  else status = "active";

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,   // service role → bypasses RLS to write
  );

  const { error } = await supabase.from("subscriptions").upsert({
    user_id: userId,
    entitlement: entitlements[0] ?? "Stetic Pro",
    status,
    expires_at: expiresAt,
    updated_at: new Date().toISOString(),
  }, { onConflict: "user_id" });

  if (error) {
    // 23503 = foreign-key violation: app_user_id isn't a real user in our DB
    // (synthetic test event, or a purchase not yet tied to a signed-in user).
    // Acknowledge so RevenueCat doesn't retry indefinitely.
    if ((error as { code?: string }).code === "23503") {
      return json({ ok: true, ignored: "unknown user", user_id: userId });
    }
    console.error("rc-webhook upsert failed", error);
    return json({ error: "db write failed" }, 500);
  }

  return json({ ok: true, user_id: userId, status });
});
