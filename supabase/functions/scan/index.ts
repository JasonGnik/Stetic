// POST /scan — physique scan. Gated on an active entitlement (the cost firewall).
// Receives image bytes, scores via Gemini, writes ONLY numbers to `scans`, discards photos.
//
// Body: { sex?: "male"|"female", images: [{ mimeType: string, dataB64: string }] }
// Auth: Authorization: Bearer <supabase user jwt>

import { createClient } from "jsr:@supabase/supabase-js@2";
import { photoSetHash, scorePhotos } from "../_shared/scoring.ts";

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

  // ── auth: identify the caller from their JWT (RLS-scoped client) ──
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  const user = userData?.user;
  if (userErr || !user) return json({ error: "unauthorized" }, 401);

  // ── cost firewall: require an active entitlement (bypass in dev) ──
  const bypass = Deno.env.get("STETIC_DEV_BYPASS_ENTITLEMENT") === "true";
  if (!bypass) {
    const { data: sub } = await supabase
      .from("subscriptions")
      .select("status, expires_at")
      .eq("user_id", user.id)
      .maybeSingle();
    const active = sub &&
      ["active", "trialing"].includes(sub.status) &&
      (!sub.expires_at || new Date(sub.expires_at) > new Date());
    if (!active) return json({ error: "subscription required" }, 402);
  }

  // ── parse + validate input ──
  let payload: { sex?: string; images?: { mimeType: string; dataB64: string }[] };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }
  const images = (payload.images ?? []).filter((i) => i?.dataB64 && i?.mimeType);
  if (images.length === 0) return json({ error: "no images" }, 400);
  if (images.length > 3) return json({ error: "max 3 images" }, 400);

  // sex: from body, else from profile
  let sex = payload.sex;
  if (sex !== "male" && sex !== "female") {
    const { data: profile } = await supabase
      .from("profiles").select("sex").eq("id", user.id).maybeSingle();
    sex = profile?.sex ?? "male";
  }

  // ── consistency cache: same photo set + sex → return the stored card, no model call.
  // (Gemini drifts run-to-run even at temp 0; this keeps an identical photo from flip-flopping.)
  const hash = await photoSetHash(sex, images);
  const { data: cached } = await supabase
    .from("scans")
    .select("*")
    .eq("user_id", user.id)
    .eq("photo_hash", hash)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (cached) return json({ scan: cached });

  // ── score (photos used in-memory only, never persisted) ──
  let card;
  try {
    card = await scorePhotos(GEMINI_API_KEY, sex as "male" | "female", images);
  } catch (e) {
    console.error("scoring failed:", e);
    return json({ error: "scoring failed" }, 502);
  }

  // ── persist numbers only ──
  const { data: scan, error: insErr } = await supabase
    .from("scans")
    .insert({
      user_id: user.id,
      sex,
      aesthetic_score: card.aesthetic_score,
      rank_tier: card.rank_tier,
      body_fat: card.body_fat,
      symmetry: card.symmetry,
      potential: card.potential,
      muscles: card.muscles,
      verdict: card.verdict,
      photo_count: images.length,
      photo_hash: hash,
    })
    .select()
    .single();
  if (insErr) {
    console.error("insert failed:", insErr);
    return json({ error: "could not save scan" }, 500);
  }

  return json({ scan });
});
