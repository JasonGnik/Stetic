# Lift AI — context

AI gym coach. Scan your physique → get an **Aesthetic score + rank + per-muscle ratings + a personalized plan**. The scan is the viral hook; the personalized plan is the product.

## Positioning
- Goal the app sells: a **Greek god / movie-star physique** (lean, proportional, attractive) — NOT a 300lb Olympia mass-monster look.
- Tagline direction: "the AI coach for a Greek god physique, not an Olympia gut. It scans you, scores your aesthetics, finds your weak points, and builds the plan to fix it."
- Trust hook: "the same principles the pros use to peak — pointed at looking good in a shirt, not on a stage." Normal people don't know these principles; that's the wedge.
- Niche: looksmaxxing / "ascend" / aesthetic gym TikTok (David Laid, Greek god physique, mogging).

## The scoring model (locked this session)
- **Aesthetic score (0–100)** is the single overall number. It drives the rank. Nothing competes with it as a headline (Mass is NOT a co-headline).
- Top of result shows: Aesthetic score + rank, then quick stats: **body fat %** (actual number, not a "leanness" bar), Symmetry, Potential.
- **Muscle groups — Core 6 rated:** chest, back, shoulders, arms, legs, abs. Each gets a 0–100 rating bar. Highlight **strongest (green)** and **weakest (red)**.
- **"Your priorities" section** holds the what-to-do (Fix first / Maintain), pulled out of the muscle rows so they stay clean.
- **V-taper was removed** as a visible metric (too jargony; "shoulder-to-waist ratio" confused testers).
- **Mass-monster handling:** too much total mass caps the Aesthetic score via a **"Size: Extreme"** flag, even when every muscle group rates 90+. This is a *take*, not a fact (some people like that look) — expect/embrace comment debate. We are NOT over-engineering this edge case; ~nobody downloading is a pro bodybuilder.

## Rank ladder
Bronze → Silver → Gold → Platinum → Diamond → **Elite → Mythic → Greek God** (apex).
- Result screen shows a "climb strip" (cleared tiers colored, next tier + points to go) for FOMO/retention.
- Reference scores: mass monster ≈ Silver 51; David Laid ≈ Greek God 95; Brad Pitt (Troy) ≈ Mythic/Greek God 90–95; realistic intermediate user ≈ Platinum 64.

## Plan logic (the differentiator)
The plan flips based on the read:
- **Undertrained guy** → add volume to weak/lagging groups (e.g., back, side delts) to build toward the ideal.
- **Over-massed / dirty-bulked guy** → cut/recomp to ~10–12% bf, widen the taper (side delts/lats/upper back), tighten waist (vacuums; avoid heavy weighted obliques), maintenance volume on big groups. "Lift AI doesn't just tell everyone to lift more."
- Frequency + intensity over raw volume (e.g., 9 sets across 3 days beats 9 in one day; "too many sets = not training to failure").

## Competitor: Thelo
- Same engine (body scan → weak points/proportions → adaptive plan + macros). Their tone is clinical ("train for your body"). No score, no rank.
- Our wedge = the **rank/score gotcha (Umax mechanic)** + the **ascendy/aesthetic framing** they don't have.
- Pricing benchmark: Thelo $7.99/wk, $19.99/mo, $59.99/yr; one-off BioScan $5.99–9.99.

## Design
- Dark theme. Colors: `--bg #0E0E10 / --card #1A1A1E / --line #26262B / --txt #F5F5F7 / --mut #9A9AA0 / --acc lime #C8FF3D / --amber #FFC24B / --red #FF5A4D`.
- Tier colors: Bronze #B0764A, Silver #C9CDD4, Gold #FFC24B, Platinum/teal #6FE0C8, Diamond #7FD0FF, Elite #C08BFF, Mythic #FF7AB0, Greek God lime #C8FF3D.

## Files
- `index.html` — main clickable prototype (scan → info → analyzing → result). Needs the result screen rebuilt to the locked Aesthetic/rank/muscle-group model above.
- `mockups/lift-ai-result.html` — single Platinum result screen (standalone, for screenshots).
- `mockups/lift-ai-bodybuilder-vs-greekgod.html` — Silver mass-monster vs Greek God comparison (for "I rated these physiques" content).
- `scan.html` — redirect to index.html.

## Marketing strategy
- **Distribution-first:** test content cheaply (slideshows + demo videos) before building the real app. New-account cold-start is normal (a flop at 127 views means nothing; post 5–10 first).
- **Faceless** content for everything; partner with influencers once a concept pops.
- **Slideshows** for top-of-funnel niche tips (TikTok Photo Mode → FYP, save-heavy); **video** (screen-recording the scan/result) for the app demo/conversion. Repurpose one concept into both.
- Strongest content = app rating a famous physique ("I put [celeb] in the app and it said…", "AI ranked David Laid"). The rank reveal is the gotcha.
- Comment-CTA for distribution (no bio link under 1k followers): "comment X and I'll send it."
- Tech note: market scan/form analysis as "computer vision"; Gemini does the photo/video analysis.

## Related
- Sibling app: Gratitude Scroll (own folder). Shared venture, distribution-first strategy.
