// POST /plan — generate workout + macros + breakdown from the user's latest scan.
// Gated on an active entitlement (post-paywall). Uses Gemini 2.5 Pro.
//
// Body (all optional): { scan_id?, profile?: { goal, focus, days_per_week, equipment, experience, ... } }
//   - scan_id: which scan to base on (defaults to the user's most recent)
//   - profile: overrides merged over the stored profile (lets us test before onboarding exists)
// Auth: Authorization: Bearer <supabase user jwt>

import { createClient } from "jsr:@supabase/supabase-js@2";
import { generatePlan, type PlanProfile } from "../_shared/plan.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
  if (!GEMINI_API_KEY) return json({ error: "server misconfigured" }, 500);

  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  const user = userData?.user;
  if (userErr || !user) return json({ error: "unauthorized" }, 401);

  // cost firewall
  const bypass = Deno.env.get("STETIC_DEV_BYPASS_ENTITLEMENT") === "true";
  if (!bypass) {
    const { data: sub } = await supabase
      .from("subscriptions").select("status, expires_at").eq("user_id", user.id).maybeSingle();
    const active = sub && ["active", "trialing"].includes(sub.status) &&
      (!sub.expires_at || new Date(sub.expires_at) > new Date());
    if (!active) return json({ error: "subscription required" }, 402);
  }

  let payload: { scan_id?: string; profile?: PlanProfile } = {};
  try { payload = await req.json(); } catch { /* empty body ok */ }

  // pick the scan (explicit id or most recent)
  let scanQuery = supabase.from("scans").select("*").eq("user_id", user.id);
  scanQuery = payload.scan_id
    ? scanQuery.eq("id", payload.scan_id)
    : scanQuery.order("created_at", { ascending: false }).limit(1);
  const { data: scans } = await scanQuery;
  const scan = scans?.[0];
  if (!scan) return json({ error: "no scan found — scan first" }, 404);

  // merge stored profile + body overrides
  const { data: profile } = await supabase
    .from("profiles").select("*").eq("id", user.id).maybeSingle();
  const merged: PlanProfile = {
    goal: profile?.goal, focus: profile?.focus, experience: profile?.experience,
    days_per_week: profile?.days_per_week, equipment: profile?.equipment,
    height_cm: profile?.height_cm, weight_kg: profile?.weight_kg, age: profile?.age,
    goal_weight_kg: profile?.goal_weight_kg,
    activity_level: profile?.activity_level, pace: profile?.pace,
    sex: scan.sex,
    ...(payload.profile ?? {}),
  };

  let plan;
  try {
    plan = await generatePlan(GEMINI_API_KEY, scan, merged);
  } catch (e) {
    console.error("plan generation failed:", e);
    return json({ error: "plan generation failed" }, 502);
  }

  const { data: saved, error: insErr } = await supabase
    .from("plans")
    .insert({
      user_id: user.id,
      scan_id: scan.id,
      workout: {
        goal_label: plan.goal_label,
        summary: plan.summary,
        weekly_split: plan.weekly_split,
        priorities: plan.priorities,
        muscle_breakdown: plan.muscle_breakdown,
        projection: plan.projection,
        split_critique: plan.split_critique ?? null,
      },
      macros: plan.macros,
    })
    .select()
    .single();
  if (insErr) {
    console.error("plan insert failed:", insErr);
    return json({ error: "could not save plan" }, 500);
  }

  return json({ plan: saved, content: plan, scan });
});
