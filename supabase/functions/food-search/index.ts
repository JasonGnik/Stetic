// GET/POST /food-search — search a food catalog by text or barcode.
// Sources (both free): OpenFoodFacts (no key) + USDA FoodData Central (FDC_API_KEY,
// falls back to DEMO_KEY). Returns normalized macros per ~100g; the client scales
// with the servings stepper. Auth required; no entitlement gate (search is cheap).
//
// Body/query: { q?: string, barcode?: string }
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...CORS, "content-type": "application/json" } });

type Food = { name: string; brand: string; portion: string; calories: number; protein_g: number; carbs_g: number; fat_g: number };
const num = (v: unknown) => { const n = Number(v); return isFinite(n) && n >= 0 ? Math.round(n) : 0; };

async function openFoodFactsSearch(q: string): Promise<Food[]> {
  const url = `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(q)}` +
    `&search_simple=1&action=process&json=1&page_size=20` +
    `&fields=product_name,brands,nutriments`;
  const res = await fetch(url, { headers: { "User-Agent": "Stetic/1.0 (food-search)" } });
  if (!res.ok) return [];
  const data = await res.json();
  return (data.products ?? []).flatMap((p: Record<string, any>): Food[] => {
    const n = p.nutriments ?? {};
    const cals = n["energy-kcal_100g"] ?? (n["energy_100g"] ? n["energy_100g"] / 4.184 : 0);
    const name = (p.product_name ?? "").trim();
    if (!name || !cals) return [];
    return [{
      name, brand: (p.brands ?? "").split(",")[0]?.trim() ?? "", portion: "100 g",
      calories: num(cals), protein_g: num(n.proteins_100g), carbs_g: num(n.carbohydrates_100g), fat_g: num(n.fat_100g),
    }];
  });
}

async function usdaSearch(q: string): Promise<Food[]> {
  const key = Deno.env.get("FDC_API_KEY") ?? "DEMO_KEY";
  const url = `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${key}` +
    `&query=${encodeURIComponent(q)}&pageSize=20&dataType=Foundation,SR%20Legacy,Branded`;
  const res = await fetch(url);
  if (!res.ok) return [];
  const data = await res.json();
  const pick = (nuts: any[], names: string[]) => {
    const f = (nuts ?? []).find((x) => names.some((nm) => (x.nutrientName ?? "").toLowerCase().includes(nm)));
    return f ? Number(f.value) : 0;
  };
  return (data.foods ?? []).flatMap((f: Record<string, any>): Food[] => {
    const name = (f.description ?? "").trim();
    const cals = pick(f.foodNutrients, ["energy"]);
    if (!name || !cals) return [];
    return [{
      name: name.charAt(0) + name.slice(1).toLowerCase(),
      brand: (f.brandOwner ?? f.brandName ?? "").trim(), portion: "100 g",
      calories: num(cals),
      protein_g: num(pick(f.foodNutrients, ["protein"])),
      carbs_g: num(pick(f.foodNutrients, ["carbohydrate"])),
      fat_g: num(pick(f.foodNutrients, ["total lipid", "fat"])),
    }];
  });
}

async function barcodeLookup(code: string): Promise<Food[]> {
  const res = await fetch(`https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(code)}.json`,
    { headers: { "User-Agent": "Stetic/1.0 (food-search)" } });
  if (!res.ok) return [];
  const data = await res.json();
  if (data.status !== 1 || !data.product) return [];
  const p = data.product, n = p.nutriments ?? {};
  const cals = n["energy-kcal_100g"] ?? (n["energy_100g"] ? n["energy_100g"] / 4.184 : 0);
  const name = (p.product_name ?? "").trim();
  if (!name) return [];
  return [{
    name, brand: (p.brands ?? "").split(",")[0]?.trim() ?? "", portion: "100 g",
    calories: num(cals), protein_g: num(n.proteins_100g), carbs_g: num(n.carbohydrates_100g), fat_g: num(n.fat_100g),
  }];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "unauthorized" }, 401);

  let q = "", barcode = "";
  if (req.method === "POST") {
    try { const b = await req.json(); q = (b.q ?? "").trim(); barcode = (b.barcode ?? "").trim(); } catch { /* ignore */ }
  } else {
    const u = new URL(req.url); q = (u.searchParams.get("q") ?? "").trim(); barcode = (u.searchParams.get("barcode") ?? "").trim();
  }
  if (!q && !barcode) return json({ foods: [] });

  try {
    if (barcode) return json({ foods: await barcodeLookup(barcode) });
    // Run both sources in parallel; interleave so the user sees variety.
    const [off, usda] = await Promise.all([openFoodFactsSearch(q), usdaSearch(q)]);
    const merged: Food[] = [];
    for (let i = 0; i < Math.max(off.length, usda.length); i++) {
      if (usda[i]) merged.push(usda[i]);
      if (off[i]) merged.push(off[i]);
    }
    return json({ foods: merged.slice(0, 30) });
  } catch (e) {
    console.error("food-search failed:", e);
    return json({ foods: [] });
  }
});
