// POST /delete-account — permanently deletes the signed-in user's account and all
// their data. Required by App Store Guideline 5.1.1(v): any app that creates an
// account must let the user delete it in-app. Auth required (the JWT identifies who
// to delete); a service-role client does the actual removal.
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...CORS, "content-type": "application/json" } });

// Tables that hold per-user rows, cleared before the auth user is removed (in case
// FK cascade isn't configured). Order doesn't matter — all are keyed by user_id.
const USER_TABLES = [
  "meal_logs", "workout_logs", "check_ins", "weight_logs",
  "saved_meals", "plans", "scans", "profiles",
];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const URL = Deno.env.get("SUPABASE_URL");
  if (!SERVICE || !URL) return json({ error: "server misconfigured" }, 500);

  // Identify the caller from their JWT.
  const authed = createClient(URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: u, error: e } = await authed.auth.getUser();
  if (e || !u?.user) return json({ error: "unauthorized" }, 401);
  const uid = u.user.id;

  // Service-role client removes the data, then the auth user itself.
  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
  for (const t of USER_TABLES) {
    // profiles is keyed by id; the rest by user_id.
    const col = t === "profiles" ? "id" : "user_id";
    await admin.from(t).delete().eq(col, uid);
  }
  const { error: delErr } = await admin.auth.admin.deleteUser(uid);
  if (delErr) return json({ error: delErr.message }, 500);

  return json({ ok: true });
});
