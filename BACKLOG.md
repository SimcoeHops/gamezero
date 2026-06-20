# Crashman — Backlog

Direction for the overnight loop. North star is `tools/overnight/VISION.md` (read it).
Priority order: **fun → feel → looks**, depth over breadth. Take ONE item per iteration and
finish it to *top-10 polish*, not just "it works." Check off `[x]`, move finished items to Done,
add follow-ups you discover. The deep-audit iterations will keep refilling and re-prioritizing
"Now" — this list is a starting seed, not a ceiling. Be ambitious.

---

## NOW — highest leverage (do these first)

<!-- Refilled by the 2026-06-19 deep audit (iter 8). Iters 5-7 lifted the iter-4
     lows (#5 Audio, #6 Progression, #10 Accessibility) off the floor. The new
     lowest cluster is #1 Core fun, #4 Visual polish, #8 Difficulty — all at 3.
     These four items attack those. See the iter-8 JOURNAL scorecard. -->

- [ ] **Player rim/back light + stronger per-biome grade** (Visual polish #4): a back/rim light
      keyed to the biome accent separates the runner from the road and unifies the Kenney kits
      under one art-direction; push the per-biome color grade (currently only fog/ambient/sun)
      toward distinct LUT-like tints so each biome reads as a designed place, not a recolor.

- [ ] **Daily challenge + missions/goals** (Progression #6): 3 rotating goals
      ("near-miss 20 cars", "reach Neon", "own 4 guns at once") with a coin reward + a
      visible streak counter. Seed the daily from the date so it's deterministic. Surface
      on the front-end and tick progress live on the HUD. Strongest runner retention driver.

- [ ] **Gantry polish v2** (follow-up to the shipped gantries): per-biome sign *text/icons*
      (e.g. a billboarded WORD like the powerup gates) instead of a blank lit panel; rarer
      special variants (a full overhead tunnel ring you pass *through* in Industrial/Neon, an
      animated arrow board); tie spawn density to flow-state/combo so hot streaks feel busier.

## FUN & GAME LOOP
- [x] Risk/reward "greed" mechanic — DONE iter 9 (see Done): visible GREED meter (chunky ×N +
      draining heat bar, hot→white tiers, rising whoosh pitch).
- [ ] A pursuer/boss beat: an occasional chasing hazard (cop, wrecking truck) that forces
      forward pressure and creates memorable run peaks.
- [x] Flow-state escalation — DONE iter 10 (see Done): clean-survival `flow_heat` (0..1, faster
      while a greed combo is hot) drives music swell + footstep energy, a warm screen-edge glow,
      a brighter/punchier grade, and tighter coin/gantry density; a crash snuffs it.
- [ ] Run-modifier variants selectable at the front-end (low gravity, double speed, one-gun,
      bullet-hell) for replay variety.

## GAME FEEL / RESPONSIVENESS
- [x] Control crispness pass — jump input buffering + coyote time DONE iter 8 (see Done).
      Follow-up: tune lateral easing (`move_speed`/`lateral_accel`) once playtested — left
      unchanged this pass to avoid altering feel blind.
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
- [x] Screen-shake intensity, haptics on/off, reduce-flashes — DONE iter 7 (see Done).
- [ ] Remaining options: motion-blur toggle, colorblind-safe palettes, remappable controls,
      and a UI/text-scale option. The SETTINGS panel (`FrontEnd._show_settings` /
      `PauseMenu._build_panel`) is the place to add them.

## ASSETS WANTED (for the human / a Cowork asset-sourcing pass)
- [ ] More CC0 vehicle variants to expand `CAR_MODEL_PATHS`; richer props per biome.
- [ ] A couple of looping synthwave tracks for `music/` (drop-in `.mp3`, then `--headless --import`).
- [ ] SFX gaps from the audio audit (UI, level-up, weather, tunnel whoosh).

## Done
<!-- iterations move finished items here with a date + one-line note -->
- [x] **Per-biome environmental particles & atmosphere** (2026-06-19, iter 11) — the top NOW item
      and the biggest "asset-flip → art-directed" lever (#4 Visual polish). New
      `scenes/environment/BiomeParticles.gd` (a code-built GPUParticles3D, no .tscn) fills the
      volume around/ahead of the camera with a soft-dot mote field that **streams past with speed**
      (`speed_scale` tracks `GameManager.highway_speed`) and **thickens/brightens with flow_heat**.
      Per-biome identity via a `BIOMES` recipe + `apply_biome()`: Downtown pale paper/litter
      (mix blend, falls), Countryside green leaves/pollen (mix, falls, more sway), Industrial
      HDR-orange embers (additive→blooms, rise), Neon magenta motes (additive, slow). **Cross-fades**
      on biome change — color + `amount_ratio` + fall direction tween over 3s; glow biomes flip the
      draw-pass blend mode to additive. Wired in `Main.gd` (instantiated in `_ready`, restyled from
      `_apply_theme`). Alpha-curve life fade (no pops), radial-gradient dot sprite, `preprocess` so
      it boots already full. Files: `scenes/environment/BiomeParticles.gd` (new), `scenes/main/Main.gd`.
      Verified: clean headless + windowed boot (renderer compiled the material/textures); exercised
      via the `Main._ready` swap — `emitting=true amount=170`, all 4 biomes apply correct
      color/gravity/`amount_ratio`/blend (mix↔add), and `speed_scale` tracks live highway_speed+flow
      in `_process`; swap restored + re-verified clean.
      - [ ] Human playtest (GPU, look unverified): density/size per biome at real res (170 amount,
            ratios 0.55–0.9), whether embers/neon bloom too hot vs the glow post (HDR colors 1.4–1.5),
            the 3s cross-fade read, and whether the field ever clutters the "readable chaos" pillar at
            high speed/flow. Tune the `BIOMES` recipe + `speed_scale` range in BiomeParticles.gd.
      - [ ] Follow-up (the item's other half): a subtle biome-tinted **near-camera haze** — currently
            leaning on the existing themed WorldEnvironment fog. A faint additive depth-fog tint pass
            or a soft near-plane wash could deepen each biome's air without hurting readability.
- [x] **Flow-state escalation** (2026-06-19, iter 10) — the top NOW item and the logged follow-up
      to iter 9's greed meter (#1 Core fun). The greed combo was a short-term, per-near-miss spike;
      this adds the *long-term* layer the runner was missing: a clean run now visibly **heats up the
      whole world**, and a crash cools it. New central `GameManager.flow_heat` (0..1) ramps with
      clean survival time (`FLOW_RAMP` ≈ reach max in ~70s) **faster while a greed combo is hot**
      (`FLOW_COMBO_GAIN` per tier — greedy threading literally turns up the temperature, ~22s to max
      at held ×9), resets to 0 in `start_game`/`do_continue` and snaps to 0 via `cool_flow()` the
      instant the player crashes (called from `Main._on_player_crashed`). Consumers, all reading
      `flow_heat` live: **audio** — music swells from −3 dB cold to full hot (`_update_music_dynamics`)
      + footsteps quicken/brighten/loud­en (`_process_footsteps`); **visual** — a new `flow_heat`
      uniform in `screen_fx.gdshader` glows the screen *edges* warm (centre stays clear — readability
      pillar) and breathes faster as it climbs, driven from `HUD._process` via an eased `_flow_display`
      (fast cool); plus a subtle 3D grade nudge (brightness/contrast up with heat in `Main._process` —
      saturation left to Bullet Time, no conflict); **density** — coin trails spawn up to ~40% more
      often (`CoinSpawner._reschedule`) and gantries pack ~30% closer (`GantrySpawner._arm_next`) when
      hot. Files: `scripts/autoload/GameManager.gd`, `scripts/autoload/AudioManager.gd`,
      `shaders/screen_fx.gdshader`, `scenes/ui/HUD.gd`, `scenes/main/Main.gd`,
      `scenes/coin/CoinSpawner.gd`, `scenes/highway/GantrySpawner.gd`. Verified: clean headless boot;
      exercised the full chain windowed via the `Main._ready` swap — base ramp 0.0144/s, held-combo-9
      ramp 0.0464/s (matches FLOW_RAMP + 8·FLOW_COMBO_GAIN), shader uniform eased toward target, grade
      brightness/contrast rose above base, coin wait dropped to ~1.77s (base 2.2–4.0), gantry spacing
      to ~61 m (base ~105), `cool_flow()` → 0; swap restored + re-verified clean.
      - [ ] Human playtest: the *feel* of the ~70s ramp (too slow/fast?), the warm-glow intensity
            (0.55 mix — could be too strong at full heat or invisible early; tune the smoothstep deadzone),
            whether the music swell reads or is too subtle, and if the tighter density makes hot runs
            feel exciting vs cluttered (readability pillar). Tune `FLOW_RAMP`/`FLOW_COMBO_GAIN` in
            GameManager + the per-consumer gains.
      - [ ] Follow-up: a stronger *audio* heat cue than a volume swell — a low-pass/high-shelf opening
            up on the Music bus as flow climbs (adaptive-music technique; skipped this pass to avoid
            blind mix risk). Also consider a brief "FLOW" / heat-tier flourish on the HUD at max heat.
- [x] **Visible greed / risk multiplier** (2026-06-19, iter 9) — attacks #1 Core fun (the
      top NOW item). The near-miss combo (max ×9) was tracked in GameManager but shown only as a
      tiny "COMBO x2" label — the central greed/risk hook was nearly invisible. Built a proper
      **GREED meter** in the HUD: a chunky outlined **×N** (font 78) over a draining **heat bar**,
      centered in the upper third clear of the road. The number punches bigger each tier and
      shifts color **hot-orange → gold → white-hot** as the combo climbs (`_combo_color`); the
      heat bar drains over `COMBO_WINDOW` (3s) and, as it runs low (<34%), the whole meter
      **pulses with rising urgency** (a "use it or lose it" cue) before cooling back to ×1 with a
      shrink-fade. Wiring: `GameManager.combo_fraction()` exposes the normalized timer for the
      bar; the combo now also **resets to ×1 on a survived hit** (`do_continue`), not just on
      timeout. Audio: `AudioManager.play_nearmiss(combo)` now **pitches the whoosh up per tier**
      (+0.085/tier) so a hot streak reads as escalating tension; `Main._on_near_miss` passes the
      live combo. Rewards greedy lane-threading over playing safe. Files:
      `scripts/autoload/GameManager.gd`, `scripts/autoload/AudioManager.gd`,
      `scenes/main/Main.gd`, `scenes/ui/HUD.gd`. Verified: clean headless boot; exercised the
      full path windowed via the `Main._ready` swap (`_combo_test`) — combo climbed ×2→×9 and
      capped, heat refilled to 1.00 on each near-miss, drained linearly (0.79→0.63→…→0.13) then
      cooled to ×1 at empty with the box fading out, all error-free; swap restored + re-verified
      clean.
      - [ ] Human playtest: the meter *placement/size* at real resolution (centered at 15.5%
            vertical — confirm it never blocks the next obstacle, the readability pillar), the
            tier colors/punch feel, the urgency-pulse intensity, and whether the rising whoosh
            pitch reads as exciting vs shrill at ×9 (tune the +0.085/tier bump in `play_nearmiss`).
      - [ ] Follow-up (next NOW item): **flow-state escalation** — tie this hot streak to music
            intensity / color-grade warmth / spawn density so a hot combo *feels* hot worldwide.
- [x] **Control crispness pass: jump input buffering + coyote time** (2026-06-19, iter 8 deep
      audit ship) — attacks #2 Game feel, the longest-standing flagged gap (called out in the
      iter-4 audit, never fixed). A jump pressed a few frames BEFORE landing (e.g. out of
      air-jumps, descending toward traffic) was silently eaten; now it's BUFFERED
      (`JUMP_BUFFER_TIME` 0.13s) and auto-fires the instant the player lands, so a slightly-early
      tap bounces straight into the next jump instead of being lost — the classic platformer
      responsiveness win. Added COYOTE_TIME (0.10s) grace so a ground-jump still works for a beat
      after leaving the floor (mostly latent on the flat-collision road, but future-proofs ledges/
      hills if collisions ever follow them). Refactored `request_jump()` → `_try_jump() -> bool`
      (returns whether a jump actually fired) + buffer-arm on failure; consumed the buffer in the
      JUMPING→RUNNING landing transition; topped up coyote each grounded frame; cleared both
      windows in `revive()`. Files: `scenes/player/PlayerController.gd`. Verified: clean headless
      boot; exercised the full path via the `Main._ready` swap (ground jump → press while
      descending at y=0.26 out of air-jumps → buffered t=0.130 → re-jumped on landing vy=16.0),
      swap restored + re-verified clean.
      - [ ] Human playtest: the 0.13s buffer / 0.10s coyote *feel* — confirm an early tap reads as
            responsive, not as a "double jump I didn't ask for"; tune the windows if needed.
      - [ ] Follow-up (logged in GAME FEEL): tune lateral easing once playtested.
- [x] **Accessibility & options screen** (2026-06-19, iter 7) — attacks the joint-lowest rubric
      score (#10 Accessibility, 2). The game had NO way to tame the (heavy) shake/flash/haptics.
      Added three accessibility knobs persisted in `Settings` under a new `[accessibility]`
      section: **SCREEN SHAKE** (0–100% slider), **HAPTICS** (on/off), **REDUCE FLASHES**
      (on/off). Crucially these are read **live at the source** in `Juice` so ONE knob governs
      every caller with zero per-caller edits: `add_trauma`/`kick_fov` multiply by
      `Settings.shake_scale`; `flash` intensity + `impact()` multiply by a `_flash_scale()`
      (0.3 when reduce-flashes is on); `haptic()` early-returns when haptics are off. Surfaced
      via a full **SETTINGS** panel on the title (`FrontEnd._show_settings` — audio + the 3
      accessibility rows, plain Controls so it's headless-verifiable) reachable from a new
      title button, AND the same 3 rows appended to the existing **pause menu**
      (`PauseMenu._make_shake_row`/`_make_toggle_row`). The front-end shake slider previews
      *live* — the world behind the dim actually shakes as you drag (Main keeps compositing the
      camera in MENU), scaled by the value you're choosing. Files: `Settings.gd`, `Juice.gd`,
      `FrontEnd.gd`, `PauseMenu.gd`. Verified: clean headless boot; exercised the settings-panel
      build + the full Settings→Juice scaling path windowed via the `Main._ready` swap
      (shake 0% → trauma 0.000; shake 50% adds; reduce-flashes → impact 0.300; haptics-off gate;
      flash) with zero errors; swap restored + re-verified clean.
      - [ ] Human playtest: default shake at 100% may still be strong for some — confirm the
            slider range/feel and the reduce-flashes 0.3 floor; decide if reduce-flashes should
            also dampen the per-channel chroma fringe (currently only the white flash + impact ring).
      - [ ] Follow-up: motion-blur toggle, colorblind-safe palette option, remappable controls,
            UI/text scale (logged in ACCESSIBILITY & OPTIONS).
- [x] **Meta-progression coin shop** (2026-06-19, iter 6) — attacks the lowest rubric score
      (#6 Progression, 2). Persistent `coins` used to ONLY buy mid-run continues; now there's
      a real reason to grind. Added an UPGRADE SHOP reachable from the title (`FrontEnd._show_shop`
      + `_make_upgrade_row`, plain Buttons/Panels so it's headless-verifiable — no custom `_draw`)
      that spends coins on 5 PERMANENT, tiered upgrades applied at `start_game`:
      **SIDEARM** (start armed with a Pistol, +1 level/tier, max 3), **AIR DASH** (start with a
      double jump), **COIN MAGNET** (always-on magnet — new `PowerUpManager.permanent_magnet`),
      **GUARDIAN** (start with N free no-coin revives, max 2), **LUCKY CHARM** (+25% coins/run
      per level, max 4). Costs tier up (base + step·level). Owned levels persist in the existing
      ConfigFile (`[upgrades]` section, back-compatible). `GameManager` gained the shop API
      (`UPGRADES` const, `upgrade_level/cost/is_maxed/can_buy/buy_upgrade`, `coin_multiplier`,
      `_apply_meta_upgrades`), `free_continues` (spent before coins in `do_continue`/`can_continue`),
      and `ContinueScreen` shows "★ FREE REVIVE ★" when a Guardian revive is available. Title screen
      now shows an `UPGRADES ◎n` button. Files: `GameManager.gd`, `PowerUpManager.gd`,
      `FrontEnd.gd`, `ContinueScreen.gd`, `BACKLOG.md`, `JOURNAL.md`. Verified: clean headless boot;
      exercised the full apply path via the `Main._ready` swap (bought all 5, maxed STARTGUN→3 /
      COINMULT→4, confirmed cost tiering, then `start_game` showed air_jumps=1, permanent_magnet=true,
      free_revives=1, PISTOL lvl3, coin mult 2.0) AND the shop UI build + buy→rebuild path windowed
      (no errors); restored Main.gd/FrontEnd + reset the dev save.
      - [ ] Human playtest: shop layout/readability at real resolution (5 PanelContainer rows +
            heading + balance + BACK — should fit 720p+ but a ScrollContainer may be wanted if more
            upgrades are added); the buy SFX (`play_unlock` on success, `play_ui` on fail); and the
            ECONOMY BALANCE — costs (120–580) vs coin earn (~score/10 · charm mult) may need tuning
            so the first upgrade is reachable in a few runs but the full board takes a while.
      - [ ] Follow-up: a juicier purchase moment (coin-spend animation, row flash/punch, particle)
            and gate the existing character skins behind coins/achievements (skins are currently free).
- [x] **Per-gun distinct fire SFX** (2026-06-19, iter 5) — every gun used to call
      `AudioManager.play_laser`, so a stacked loadout sounded like one repeated zap.
      Added per-gun shot voices: new banks `_g_low`/`_g_zap`/`_g_three`/`_g_trash`
      (scanned from the digital kit: low tones, zaps, three-tones, spaceTrash) and a
      `AudioManager.play_gun_shot(pattern)` dispatch with a pitch/layer recipe per
      `Pattern` — PISTOL crisp pop, RAPID light fast pops, MINIGUN high hose, SHOTGUN
      sub-thump+spray BOOM, LASER zap+low body, SPREAD tonal triple, MORTAR hollow
      launch thoomp (its explosion keeps its own boom), RAILGUN deep crack+sub-boom+metal
      tail, NET whoosh+fizz. Each branch falls back to `_laser` if a kit is missing.
      `GunManager._play_shot` now routes to `play_gun_shot(pattern)` (rapid-gun throttle
      kept). Files: `AudioManager.gd`, `GunManager.gd`. Verified: clean headless boot, then
      exercised ALL 9 guns firing via the `Main._ready` swap both headless and windowed
      (real AudioServer) — every pattern fired over ~3.6s with zero errors; swap restored
      + re-verified clean.
      - [ ] Human playtest: the actual *mix* — relative loudness of each gun, whether big
            guns (shotgun/railgun/mortar) thump enough vs the rapid guns, and whether a
            full 9-gun stack is a satisfying chord or mush. Tune dB/pitch in `play_gun_shot`.
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
