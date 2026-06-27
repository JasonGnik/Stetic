# Stetic — Positioning & Onboarding Redesign (working doc)

> Started 2026-06-26 from Jason's brain dump on "the feeling we're selling." This is the
> strategy layer the new onboarding is built on. Copy comes after the feeling is locked.
> Companion to ONBOARDING.md (current funnel) and CONTEXT.md (positioning).

## 1. The core truth: we sell the LOOK — and how looking good FEELS. (corrected 2026-06-26)
NOT what the physique proves (discipline/follow-through — too virtuous, motivational-poster). We sell
the **result and the feeling it gives**: you catch yourself in the mirror and think *"damn, I look
good."* Abs showing. A lean, well-rounded, movie-star frame. People want to look good — **Stetic makes
them look good.** Vanity-first, not virtue-first.

**The one feeling (north star): "DAMN, I LOOK GOOD" → and that makes you feel unstoppable.**
Looking good is the thing; the confidence/can-do-anything high is what *looking good* gives you.

Sub-feelings (all anchored to the look):
- **The mirror moment** — shirt off, abs in, *"this is the best I've ever looked."*
- **Magnetism / being seen** — heads turn, people notice, you get attention; looking good opens doors.
- **Movie-star specifically** — lean + balanced reads as elite/leading-man, not gym-bro bulky.
- **Vindication via the look** — you visibly out-look the guy who's been in the gym 2 years looking the same.
- (Supporting, minor) earned/no-shortcuts — present as flavor, never the lead.

## 2. The enemy (the "where you are now" — the doom)
Framed around the LOOK, not morality. The audience *tries* and still doesn't look how they want.
- **Years in the gym, same body in the mirror.** Still hiding your shirt. Spinning wheels.
- **Wasting time — and the time passes anyway.** A year from now you either look the part or you look the same.
- Identity jab (aspirational, not insulting): "You value your time — so why train like someone who
  doesn't?" Keep it light vs the look; don't moralize about career/seriousness (Jason: lean off that).

## 3. Our wedge (why Stetic, vs Cal AI, vs everything else)
Cal AI sells "tracking made easy." We sell **the whole transformation, done for you, the efficient way.**
- **Efficiency is the hook, not volume.** ~45 min–1 hr, *fewer* days a week. You don't need 3 hours
  and 6 days. Less time, more result. (This is counter-intuitive and sticky.)
- **Decoded by the best.** Programming distilled from elite/pro-level coaching — not bro-science.
  Proven to build muscle and strip fat. (Never name the source.)
- **It's all here — no searching.** Plan, nutrition, what to do every set. Removes the overwhelm.
- **THE AHA (our true differentiator): weak-point → well-rounded.** We identify *your* specific weak
  points and build the plan to bring them up. A well-rounded frame is what reads as "movie-star" —
  not spamming bench. Small shoulders? We see it and prioritize it with the right science. THIS is
  what no generic plan does, and it's the moment that should hook them in onboarding.

## 4. Identity — "Stetic is for people who…" (look-first)
- …want to look like a movie star — lean, defined, well-built — not just "fit."
- …want it the efficient, proven way (less gym time, smarter), without the bro-science guesswork.
- …value their time and refuse to waste years and still look the same.
- (minor) …would rather earn the look than fake it.

## 5. The emotional arc (this is the onboarding spine)
**PAIN → NAME IT → STAKES → AHA/HOPE → PROOF → IDENTITY COMMITMENT.**
Open on *their* problem (make them feel it), show the cost of staying the same, then flip to the
guided, efficient, weak-point-aware path — and close the paywall as an identity choice, not a price.

## 6. Screen-by-screen spec (proposed) — ASK = question, SHOW = interstitial
Hook block first (emotional), stats batched late, payoff at the end. Tag = [KEPT] / [MOVED] /
[NEW] / [CHANGED] vs the current flow. Options reuse the existing `OnbOptions` unless noted.

### Block A — Hook (make them feel the problem)
1. **SHOW · Welcome / identity opener** [KEPT — WelcomeView]
   "Built to make you look like a movie star — the efficient way." One line on who it's for.
2. **ASK · "Why are you really here?"** [NEW — revive `motivation`, multi-select]
   Options: Get lean & defined · Build muscle in the right places · Feel good shirtless · Look good for an event/summer · Turn heads · Break out of a rut.
3. **ASK · "What's holding you back?"** [MOVED to front — `obstacles`, multi]
   Don't know what to do · Can't stay consistent · Train hard but look the same · Hours for little result · Plateaued · Lost/intimidated.
4. **SHOW · Empathy beat** [KEPT — `callback`] the sourced stat that answers their top obstacle.
5. **ASK · "How long have you trained?"** [MOVED earlier — `experience`] Beginner / Intermediate / Advanced.
6. **ASK · "How do you feel about your results for that time?"** [NEW] — the gut-punch / vindication setup.
   Options: "Honestly, behind where I should be" · "Some progress, not enough" · "Decent, but stuck/plateaued" · "Just getting started."
7. **ASK · "Tried a coach or program before?"** [NEW] — positions us as the thing that finally works.
   Options: "Winged it / free YouTube" · "A paid app or program" · "An actual coach" · "Never had a real plan."

### Block B — Desire + the flip
8. **ASK · "What do you want to build?"** [KEPT — `goal`] Lose fat / Build / Recomp / Tone.
9. **ASK · "Which areas feel behind?"** [MOVED into main flow — `focus`, multi] Shoulders/Chest/Back/Arms/Abs/Legs/Lower body fat. → feeds the aha (screen 11).
10. **SHOW · DOOM** [CHANGED — replaces the "Picture 6 months" *question*]
    "A year from now: same mirror, or the best you've looked? The time passes either way." Honest, a little uncomfortable, about the LOOK (not morality).
11. **SHOW · THE AHA** [NEW — the differentiator] personalized from screen 9, with a **MOCK weak-point visual**:
    a body silhouette highlighting their self-reported weak area + "your focus" — makes it tangible without a real (gated) scan. "You said your **shoulders** feel behind. That's exactly what breaks the movie-star line. We'll prioritize it with science-based training — a balanced frame, in less gym time."
11b. **SHOW · "Your coach handles the rest"** [NEW — feature-as-proof, ONE screen, NOT a tour]
    Compress everything-a-coach-does into a single benefit beat: "The plan, your food, when to go heavier, when to back off — all done for you. You just show up." Tiny supporting line lists it as outcomes (trains your weak points · macros + meal ideas · tracks your lifts & tells you when to add weight · deloads you on time). Sells the *effortless/it's-all-here* wedge without explaining features one by one.

### Block C — Build it for me (stats, batched & fast)
12. **ASK · pace** [KEPT] · 13. **ASK · sex** [KEPT, needed for scoring/macros] · 14. **ASK · days** [KEPT] ·
15. **ASK · equipment (+detail)** [KEPT] · 16. **ASK · height / weight / (goal weight if fat-loss) / age** [KEPT, batched] ·
17. **ASK · activity** [KEPT] · 18. **ASK · current split** [KEPT, experienced only].

### Block D — Payoff + commit
19. **SHOW · Projection payoff** [CHANGED — #10] where they'll **GET TO** ("will," not "can"), in visceral/visual language ("abs starting to show, fuller shoulders"), tier name secondary.
20. **SHOW · Social proof** [KEPT — `socialProof`].
21. **ASK · reminders** [KEPT] · 22. **ASK · attribution** [KEPT].
→ **Sign-in → Paywall** as the identity choice ("You value your time. This is the efficient way. Start your 3-day trial.").

## 7. Diff vs current onboarding
**Added (4 asks + 2 shows):** "Why are you here" (revive motivation) · "How do you feel about your results" · "Tried a coach/program" · "Which areas feel behind" (focus moved into main flow) · DOOM screen · AHA screen.
**Changed:** "Picture 6 months from now" (stakes) — removed as a *question*, becomes the projection payoff (#19). Projection reworded off tier names (#10).
**Moved to front:** obstacles, experience (hook block) — they currently sit mid/late.
**Moved to back / batched:** all physical stats (height/weight/age/days/equipment/activity), attribution, reminders.
**Cut candidate (decide):** `commitment` ("how committed are you?") — the front-loaded emotional block may make it redundant. Keep or cut?
**Kept as-is:** name (or fold into welcome), sex, goal, pace, currentSplit, callback, socialProof.

## 8. Feature philosophy + DOOM options
**Features: sell the feeling, don't tour them.** (Jason) No feature-by-feature screens. Features appear
ONLY as proof, in exactly two beats: (1) the AHA — weak-point → plan with a mock visual; (2) "your coach
handles the rest" — one screen compressing nutrition/meal-ideas/cravings + lift logging + progressive
overload (when to push/add weight) + deload into "it's all done for you." Everything else (the actual
scanner, meal scan, cravings, logbook UI) is discovered IN the app, not explained in onboarding.

**DOOM options — pick the intensity (all about the look + wasted time, off career/morality):**
- **A — Mirror gut-punch (hardest):** "Another year. Same body in the mirror. Still hiding your shirt at the beach. The time passes whether you change or not — most people waste it."
- **B — The other guy (vindication angle):** "The guy who started when you did already looks the part. You've put in the time — you just haven't seen it pay off. That stops here."
- **C — Two roads (visual, less harsh):** split image — "Keep guessing → 12 months, barely different. Or start now → the best you've ever looked. Same year, two completely different mirrors."
Recommendation: lead with **A or B** for this audience; C is the softer fallback. Can also A/B test later.

## Decisions locked
- **CUT the `commitment` screen.** (Jason, 2026-06-26)
- **Scan stays gated** — they UPLOAD their photo before the paywall, but the scan/score reveal is post-paywall (current funnel structure). No free scan. The onboarding AHA uses a MOCK weak-point visual + self-reported area. (Jason)
- **Features: sell the feeling, don't tour.** Only 2 feature-as-proof beats (AHA + "coach handles the rest"). (Jason)
- **Sell the LOOK + the feeling of looking good ("damn, I look good"), not what it proves.** (Jason, 2026-06-26)
- Aha = weak-point → well-rounded movie-star physique, the efficient way (less gym time). (Jason)
- Open on WHY / what's holding them back — pain-first hook, then doom, then aha. (Jason)
- "6 months from now" is NOT a question — it's the projection payoff. (Jason)
- Feeling > features. (Jason)
