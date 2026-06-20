# Crashman — Backlog

Direction for the overnight loop. North star is `tools/overnight/VISION.md` (read it).
Priority order: **fun → feel → looks**, depth over breadth. Take ONE item per iteration and
finish it to *top-10 polish*, not just "it works." Check off `[x]`, move finished items to Done,
add follow-ups you discover. The deep-audit iterations will keep refilling and re-prioritizing
"Now" — this list is a starting seed, not a ceiling. Be ambitious.

---

## NOW — highest leverage (do these first)

<!-- Refilled by the 2026-06-19 deep audit (iter 4). Lowest rubric scores were
     #6 Progression & retention (2) and #10 Accessibility (2); #5 Audio (3) close
     behind. These attack those. See JOURNAL scorecard. -->

- [ ] **Meta-progression coin shop** (Progression #6 — the biggest retention hole):
      persistent `coins` currently only buy mid-run continues. Add a SHOP reachable from
      the front-end that spends coins on PERMANENT upgrades that apply at `start_game`
      (e.g. starting gun, +1 air-jump, always-on coin magnet, +1 free revive, score/coin
      multiplier). Persist owned upgrades in the existing ConfigFile; apply them in
      `GameManager.start_game`/relevant autoloads. Keep the UI simple Buttons (no custom
      `_draw`) so it's headless-verifiable via the apply-logic path. This is the #1
      "why grind coins" lever.
- [ ] **Daily challenge + missions/goals** (Progression #6): 3 rotating goals
      ("near-miss 20 cars", "reach Neon", "own 4 guns at once") with a coin reward + a
      visible streak counter. Seed the daily from the date so it's deterministic. Surface
      on the front-end and tick progress live on the HUD. Strongest runner retention driver.
- [ ] **Per-gun distinct fire SFX** (Audio #5 — quick, high-impact win): every gun
      currently calls `AudioManager.play_laser`, so the build-a-loadout power fantasy
      sounds identical no matter what you stack. Give each `Pattern` its own voice
      (pistol pop, shotgun boom, minigun hose, mortar thunk+boom, railgun crack, laser
      zap). Pitch/volume per pattern; route through `_play`. Big guns should *thump*.
- [ ] **Accessibility & options screen** (Accessibility #10 — cheap, expected at this bar):
      add a SETTINGS panel (front-end + pause) with screen-shake intensity (0–100%, scales
      `Juice.add_trauma`/`kick_fov`), a haptics on/off toggle, and a reduce-flashes toggle
      (dampens `Juice.flash`/impact pulse). Persist in `Settings`. Have `Juice` read a
      `shake_scale`/`haptics_on`/`flash_scale` so one knob governs all callers.

- [ ] **Gantry polish v2** (follow-up to the shipped gantries): per-biome sign *text/icons*
      (e.g. a billboarded WORD like the powerup gates) instead of a blank lit panel; rarer
      special variants (a full overhead tunnel ring you pass *through* in Industrial/Neon, an
      animated arrow board); tie spawn density to flow-state/combo so hot streaks feel busier.

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
- [x] **Game-over recap: "NEW BEST!" celebration + animated count-ups** (2026-06-19, iter 4
      audit ship) — the recap was static text with a fragile pulsing "NEW RECORD" label.
      Now: the hero SCORE counts up from 0 with a rising-pitch blip (`AudioManager.
      play_count_tick`), supporting stats (dodges · **distance** · time) punch in under it,
      and the BEST line shows both best score **and** best distance. On a personal best a
      "★ NEW BEST ★" (or "✦ FURTHEST RUN ✦" for distance-only) banner punches in with an
      ELASTIC tween, a multi-color **confetti burst** (5 one-shot `CPUParticles2D`), a
      rising 4-note **fanfare** (`AudioManager.play_fanfare`), a gold/cyan screen flash +
      haptic, then settles into a gentle pulse; restart unlocks only AFTER the payoff so a
      reflexive tap can't skip it. Added persistent **best_distance** + clean pre-overwrite
      record detection (`prev_high_score`, `last_run_best_score/_distance`) in GameManager
      (saved under `score/best_distance`). Files: `GameManager.gd`, `AudioManager.gd`,
      `GameOverScreen.gd`. Verified: clean headless boot; exercised BOTH the new-best and
      not-a-record paths windowed via the `Main._ready` swap (count-ups, confetti, fanfare,
      banner all ran error-free over 260 frames), swap restored + re-verified clean.
      - [ ] Human playtest: confetti density/scale & spread, count-up duration feel, banner
            ELASTIC overshoot, fanfare pitch/loudness vs music duck. Unverified visually.
- [x] **Overhead gantries** (2026-06-19) — punctuate biomes & sell speed. The named asset
      (`kenney_3d-road-tiles`) turned out to be a top-down *terrain* kit, not tunnels, so
      gantries were built **procedurally**: `scenes/highway/Gantry.gd` (pillars + cross-beam +
      truss rail + lit hanging sign + under-light, all code-built BoxMeshes) and
      `GantrySpawner.gd` (distance-based spacing, per-biome `ACCENTS` tint, sign/bare-truss
      variety, speed-synced). They ride the curve/hills via the same lens functions as cars.
      Pass-under "whoosh" beat: `AudioManager.play_gantry_whoosh` (deep doppler + low impact),
      a near-black `Juice.flash` shadow sweep, FOV kick + trauma + haptic, and the under-light
      punches bright as it crosses overhead. Wired into `Main.tscn`/`Main.gd`; CLAUDE.md note
      corrected. Verified headless (spawn→ride→sweep@z≈9→despawn, biome accent amber→green,
      zero errors) + a windowed renderer pass. Follow-up "Gantry polish v2" added to NOW.
- [x] **Crash sequence, taken to "wow"** (2026-06-19) — layered the signature crash: hard
      hit-stop (time_scale 0.001) → held slow-mo (0.12) → cubic "whip" back to speed, all on a
      real-time timeline (`PlayerController._run_crash_time_sequence`). Added a glass/metal shard
      + spark `GPUParticles3D` burst at impact (`PlayerRagdoll._spawn_debris`), a screen_fx
      shockwave-ring + chromatic edge-fringe overlay (new `impact_pulse` uniform driven by
      `Juice.impact()`/`impact_pulse()` via the HUD), a layered crunch SFX stack + delayed
      tumble crunch (`AudioManager.play_crash`/`_play_crash_tumble`), and a double flash
      (white pop → warm afterglow) + secondary landing thud/shake/haptic in `Main`.
      Follow-ups below.
      - [ ] Tune debris counts/perf on-device — 40 shards + 28 sparks per crash is fine on
            desktop but unverified on mobile GPU; consider pooling if crashes feel heavy.
      - [ ] Consider a brief slow-mo "hero" camera dolly/zoom toward the ragdoll instead of
            only shake (camera intentionality item in GAME FEEL).
      - [ ] Glass shards currently a generic blue tint; could tint to the player's skin/biome
            palette for cohesion.
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
