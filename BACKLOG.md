# Crashman — Backlog

Direction for the overnight loop. North star is `tools/overnight/VISION.md` (read it).
Priority order: **fun → feel → looks**, depth over breadth. Take ONE item per iteration and
finish it to *top-10 polish*, not just "it works." Check off `[x]`, move finished items to Done,
add follow-ups you discover. The deep-audit iterations will keep refilling and re-prioritizing
"Now" — this list is a starting seed, not a ceiling. Be ambitious.

---

## NOW — highest leverage (do these first)

- [ ] **Crash sequence, taken to "wow".** Crashing is the signature spectacle (pillar #2).
      Layer it: brief hit-stop → slow-mo → camera punch + heavy shake → debris/glass particles
      → screen flash + chromatic aberration → crunch SFX stack → haptic. Then a satisfying
      ragdoll beat before the recap. Make players *want* to watch themselves die.
- [ ] **Overhead tunnels / gantries** using `assets/kenney_3d-road-tiles/` (now present;
      CLAUDE.md wrongly says it's missing). Cosmetic first, ride the hills/curve like cars.
      Use them to punctuate biomes and sell speed (whoosh + shadow sweep as you pass under).
      Update the CLAUDE.md note when done.

## FUN & GAME LOOP
- [ ] Risk/reward "greed" mechanic: a rising near-miss/combo multiplier that resets on hit —
      reward threading traffic instead of playing safe. Big, readable on-screen feedback.
- [ ] A pursuer/boss beat: an occasional chasing hazard (cop, wrecking truck) that forces
      forward pressure and creates memorable run peaks.
- [ ] Flow-state escalation: the longer you survive cleanly, the more the world reacts
      (music intensity, color, spawn density) — make a hot streak *feel* hot.
- [ ] Run-modifier variants selectable at the front-end (low gravity, double speed, one-gun,
      bullet-hell) for replay variety.

## GAME FEEL / RESPONSIVENESS
- [ ] Control crispness pass: input buffering on jump, coyote time off ledges/hills, tune
      lateral easing so lane changes feel snappy but weighty. This is felt, not seen — get it right.
- [ ] Speed-sensation pass: FOV ramps with speed, motion blur / stronger speed-lines at top
      speed, wind audio, engine-drone pitch curve, subtle camera bob. Make 100% speed *scary*.
- [ ] Character squash & stretch + anticipation on jump/land, dust puff on landing.
- [ ] Camera intentionality: dynamic look-ahead, slight FOV/height shift in bullet-time, a
      considered framing for the gun-carnage power fantasy.

## JUICE & FEEDBACK (every action earns a reaction)
- [ ] Coin/pickup juice: magnetize coins to the player, rising-pitch collect chime, count-up
      pop on the HUD, sparkle particle. Collecting should feel *delicious*.
- [ ] Near-miss feedback: doppler whoosh, brief slow-mo flirt at very close passes, score
      popup, screen-edge speed-line spike.
- [ ] Gun feel: muzzle flash, light kick, impact sparks + small hit-stop on crumple, tracer
      glow, per-gun distinct sound. Big guns should *thump*.
- [ ] Milestone stingers: distance/combo milestones trigger a musical stinger + UI flourish.

## VISUALS & ART DIRECTION (unify the kit, art-direct the world)
- [ ] Post-processing pass: tonemapping, bloom on emissives/neon, color grading (per-biome
      LUT/tint), depth-based fog — the cheapest path from "asset flip" to "designed."
- [ ] Lighting pass: rim/back light on the player, stronger emissive neon in the Neon biome,
      better sun angle/shadows per theme. Cohesion across the Kenney kits.
- [ ] Environmental particles & atmosphere per biome (dust/leaves/embers/rain), and weather —
      a wet road with reflections in one biome would be a showpiece.
- [ ] Biome identity pass: give each of Downtown→Countryside→Industrial→Neon a distinct
      palette, skybox, props, and transition flourish ("NOW ENTERING" already exists — juice it).

## AUDIO
- [ ] Adaptive music: intensity layers/filter tied to speed & combo; duck + low-pass during
      bullet-time; sidechain to big crashes. (AudioManager already has playlist + drone.)
- [ ] SFX coverage & variation audit: ensure every action has a sound with pitch variation;
      fill gaps (UI, level-up, milestone, tunnel whoosh); balance the mix.

## PROGRESSION & RETENTION (the top-10 stickiness)
- [ ] Meta-progression shop: spend persistent `coins` on permanent unlocks/upgrades
      (starting gun, extra air-jump, coin magnet, revive). Power that persists between runs.
- [ ] Daily challenge + goals/missions ("near-miss 20 cars", "reach Neon") with rewards and
      a streak. This is the #1 retention driver for runners.
- [ ] Local leaderboard / personal-best chase with juicy "NEW BEST!" celebration.
- [ ] Character unlock progression tied to coins/achievements (skins already exist — gate &
      celebrate them).

## ONBOARDING & UX
- [ ] First-run tutorial / teaching moment (non-blocking): teach move, jump, stomp, guns in
      the first 15 seconds through play, not text walls.
- [ ] Front-end & menu polish: kinetic transitions, animated buttons, consistent typography &
      iconography, screen wipes. The portrait cards are a great base — make menus fun to touch.
- [ ] Game-over recap polish: lean into the JourneyMap, animate stat count-ups, clear CTAs.

## DIFFICULTY & BALANCE
- [ ] Difficulty-curve tuning pass: smooth the speed/spawn ramp; ensure deaths feel fair
      (always a dodgeable gap); consider light dynamic difficulty.
- [ ] Gun balance pass so every gun has a reason to be picked; no dominant/useless options.

## PERFORMANCE & STABILITY (protect the 60fps spell)
- [ ] Object pooling for cars/coins/projectiles/particles; reduce per-frame allocations.
- [ ] Draw-call / material audit; LOD or culling for distant props; eliminate any pop-in.
- [ ] Frame-pacing check under heavy carnage (many guns + many cars) — the worst case must hold.

## ACCESSIBILITY & OPTIONS
- [ ] Options for screen-shake intensity, haptics, motion-blur, colorblind-safe palettes,
      and remappable controls. Cheap to add, expected at this quality bar.

## ASSETS WANTED (for the human / a Cowork asset-sourcing pass)
- [ ] More CC0 vehicle variants to expand `CAR_MODEL_PATHS`; richer props per biome.
- [ ] A couple of looping synthwave tracks for `music/` (drop-in `.mp3`, then `--headless --import`).
- [ ] SFX gaps from the audio audit (UI, level-up, weather, tunnel whoosh).

## Done
<!-- iterations move finished items here with a date + one-line note -->
- [x] **Level-up "choose your gun" moment** (2026-06-19) — dodges are now XP (GameManager
      `run_level`/`level_up`); filling the bar freezes the run (tree pause) and shows 3 themed
      gun cards (`scenes/ui/LevelUpScreen.gd`). Pick grants/levels the gun via `add_gun`.
      Added a HUD XP bar + level badge, punch-in card animations, NEW/LV-up badges, number-key
      selection, reward flash on pick. Follow-ups below.
      - [ ] Card polish v2: render a live 3D gun GLB per card (reuse FrontEnd SubViewport
            pattern) instead of the color slab + ► glyph; add a slow idle spin.
      - [ ] Add non-gun upgrade cards (extra air-jump, coin magnet, +speed, heal/shield) so
            choices aren't only guns — deepen the build variety.
      - [ ] Tune the XP curve (`LEVEL_XP_BASE`/`STEP`) against real dodge rates once playtested;
            current 7 + 3·level may level too fast/slow.
      - [ ] Re-pick weighting: bias toward upgrading owned guns later in a run so power *stacks*
            visibly rather than always sprawling into new guns.
