# Crashman — Backlog

Direction for the overnight loop. North star is `tools/overnight/VISION.md` (read it).
Priority order: **fun → feel → looks**, depth over breadth. Take ONE item per iteration and
finish it to *top-10 polish*, not just "it works." Check off `[x]`, move finished items to Done,
add follow-ups you discover. The deep-audit iterations will keep refilling and re-prioritizing
"Now" — this list is a starting seed, not a ceiling. Be ambitious.

---

## NOW — highest leverage (do these first)

<!-- Refilled by the 2026-06-19 deep audit (iter 12). Iters 9-11 lifted the iter-8
     lows (#1 Core fun via greed+flow, #4 Visual polish via biome particles). The
     new floor is #7 Onboarding (was 2 — iter 12 shipped the first-run tutorial,
     lifting it toward 3), then #8 Difficulty and #9 Performance (both 3). These
     items attack those, plus a #1/#3 design risk to decide. See iter-12 JOURNAL. -->

- [ ] **[HUMAN / HARNESS — loop cannot self-do: `tools/overnight/` is off-limits per AGENT_BRIEF]
      Archive old JOURNAL entries to cut per-iteration token cost.** `tools/overnight/JOURNAL.md`
      is ~51 KB and grows every iteration, and the brief makes EVERY fresh session re-read it in
      full ([AGENT_BRIEF.md] "Read first") — it's the single largest and fastest-growing recurring
      input. Split it: move all but the **last ~3–4 iterations** into a new
      `tools/overnight/JOURNAL.archive.md`, but **keep every deep-audit scorecard** (the iter
      4/8/12/… rubric entries) in the live `JOURNAL.md` since those are the running quality signal.
      No brief change needed: the brief reads `JOURNAL.md` by name, so the archive is automatically
      NOT auto-read. Net effect: every subsequent iteration reads a much smaller journal for the
      same state. Do this from a human/maintenance session (NOT a loop iteration). Re-run as
      maintenance whenever the live journal creeps back up.

- [ ] **Object pooling for the hot spawners** (Performance #9): cars, coins, projectiles, and
      crash debris all instantiate+free every spawn — under worst-case carnage (MINIGUN + MORTAR
      AOE + many cars) this churns allocations and risks frame hitches, the exact thing the
      VISION "no jank" anti-goal warns about. Add a simple free-list pool (reset-on-reuse) to
      CarSpawner + Projectile + CoinSpawner; measure worst-case frame time before/after. NOTE:
      higher regression risk than usual (lifecycle/state-reset bugs can pass smoke yet break
      feel) — do it carefully, exercise heavily headless, ideally with human oversight.

- [x] **Dynamic difficulty (light rubber-banding)** — DONE iter 14 (see Done): bounded signed
      `difficulty_bias` in GameManager (dodges/near-misses press up, a crash drops toward relief,
      decays to neutral), mapped to `difficulty_pressure()`; CarSpawner nudges spawn interval
      (±~12%) and shaves/adds one car at the extremes — dodgeable-gap guarantee preserved.

- [x] **Gun scaling: tame runaway layering (LOCKED SPEC)** — DONE iter 16 (see Done). All 4
      locked items shipped: `MAX_GUNS=6` slot cap (over-cap NEW pickups redirect into the
      lowest-level owned gun; `roll_choices` stops offering unowned guns at cap), `MIN_COOLDOWN=0.05`
      per-gun fire-rate floor, per-level depth rewards (RAPID/MINIGUN parallel streams, RAILGUN/LASER
      +0.5 m corridor/level, MORTAR +1 m AOE/level capped +4 m, `PELLET_CAP=9`), and the ≥3-owned
      ~60/40 upgrade-lead bias. Stale "30s layer" comments fixed to 20 s.

- [x] **Gun slot-cap feedback cue** — DONE iter 17 (see Done): new `GunManager.gun_redirected`
      signal; HUD shows a "MAX GUNS · <GUN> ▸ LV<n>" toast above the gun panel + a panel punch +
      light haptic on every over-cap redirect, and a "N/6 GUNS" slot-count header appears on the
      gun panel once the loadout is full.

- [ ] **Tutorial polish v2 + bullet-time/weapon teaching** (follow-up to iter-12 onboarding):
      the first-run tutorial teaches move/jump/stomp; extend the same pattern to the bullet-time
      (dodge-25) and weapon (dodge-50) unlocks ("SWIPE DOWN FOR BULLET TIME"), and consider a
      tiny persistent control-glyph legend for the first ~20 s. Tune prompt placement/timing
      once playtested (see iter-12 JOURNAL risks).

- [x] **Player rim/back light + stronger per-biome grade** — DONE iter 15 (see Done): code-built
      biome-keyed `RimLight` OmniLight3D on the runner (breathes with flow_heat) + a per-biome 1D
      color-correction LUT (duotone tone-curve) and resting saturation that cross-fade on biome
      change. Each biome got a `rim`/`grade_lo`/`grade_hi`/`sat` recipe.

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
- [x] Coin/pickup juice — DONE iter 13 (see Done): always-on grab magnet, rising-pitch
      "coin-run" streak chime, sparkle burst, streak-heated HUD "+1" floater.
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
- [x] First-run tutorial / teaching moment (non-blocking) — DONE iter 12 (see Done): teaches
      move/jump/stomp at each unlock moment through play, plus a guns-auto-fire toast.
- [ ] Front-end & menu polish: kinetic transitions, animated buttons, consistent typography &
      iconography, screen wipes. The portrait cards are a great base — make menus fun to touch.
- [ ] Game-over recap polish: lean into the JourneyMap, animate stat count-ups, clear CTAs.

## DIFFICULTY & BALANCE
- [x] Light dynamic difficulty — DONE iter 14 (see NOW/Done). Follow-up: a broader
      difficulty-curve tuning pass (smooth the speed/spawn ramp end-to-end) + playtest the DDA
      feel and tune `DDA_*` constants / the 0.32/0.78 pressure thresholds in CarSpawner.
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
- [x] **Gun slot-cap feedback cue** (2026-06-20, iter 17) — made the (good but invisible) iter-16
      slot cap legible. New `GunManager.gun_redirected(target_id, new_level)` signal fires whenever an
      over-cap NEW pickup is redirected into deepening the lowest-level owned gun. HUD reacts: a
      "MAX GUNS · <GUN> ▸ LV<n>" toast pops above the left-edge gun panel (in the redirected gun's
      color), the panel punches to draw the eye to the row that grew, and a light haptic fires so it
      reads as a reward not a dropped pickup. Also a persistent "N/6 GUNS" slot-count header now leads
      the gun panel once `owned.size() >= MAX_GUNS`. Files: `GunManager.gd` (signal + emit in
      `add_gun`), `HUD.gd` (`_on_gun_redirected` + header line in `_refresh_powerups`). Verified
      headless via the `Main._ready` swap: redirect fired `PISTOL LV2`, owned stayed 6, MINIGUN not
      added, no script errors; swap restored.
- [x] **Gun scaling: tame runaway layering (LOCKED SPEC)** (2026-06-20, iter 16) — implemented the
      human-locked spec to bound the Vampire-Survivors runaway while keeping escalating power as the
      core fun (#1 Core fun / power-fantasy pillar). The runaway was **uncapped simultaneous
      weapons** (all 9 guns firing at once ~95 proj/s), so the fix = **cap breadth, reward depth**.
      Shipped all four locked items in `GunManager.gd`:
      (1) **`MAX_GUNS=6` weapon-slot cap** — `add_gun` redirects a brand-new gun picked up beyond the
      cap into a level on the **lowest-level owned gun** (new `_lowest_level_owned()`; ties → first
      found in insertion order) so the pickup still rewards you (deeper, not wider); `roll_choices`
      clears the unowned pool once at the cap so the level-up screen only offers upgrades.
      (2) **`MIN_COOLDOWN=0.05` per-gun floor** — `st["cd"] = maxf(st["cd"], MIN_COOLDOWN)` after the
      schedule block in `_process` (20 shots/s ceiling per gun; only bites the rapid cadences, burst
      pause is always above it).
      (3) **Depth rewards** — RAPID(BURST)/MINIGUN gain **+1 parallel stream every 2 levels**
      (`1 + (level-1)/2` → 2nd@L3, 3rd@L5) via new `_fire_streams(gun, streams, jitter, fan_step)`
      (MINIGUN keeps its random jitter, RAPID a tight jitter-free fan); RAILGUN **+0.5 m sweep
      corridor/level** (base 0.9 → 2.9 m at L5) and LASER **+0.5 m beam corridor/level** (1.5 → 3.5 m
      at L5); MORTAR **+1 m AOE/level capped at +4 m** (6 → 10 m at L5); SHOTGUN/SPREAD pellets
      `min(base+(level-1), PELLET_CAP=9)`. Per-level boosts pass through a new `_spawn(..., overrides)`
      param (aoe / hit_radius) so the const `GUNS` dict stays the base recipe.
      (4) **Depth-biased roller** — once you own **≥3** guns, `roll_choices` leads with an *upgrade*
      of an owned gun ~60% of the time instead of always leading with a new gun.
      Also fixed the stale "30s layer" comments (`_stacks` / `add_gun`) to **20 s** (the constant is
      `GUN_DURATION=20.0`). Files: `scripts/autoload/GunManager.gd` only (constants, `add_gun` redirect
      + `_lowest_level_owned`, `roll_choices` cap+bias, `_process` cd floor, `_fire` per-level rewards
      + `_fire_streams`, `_spawn` overrides + RAILGUN hit_radius, `_fire_beam` level radius). Verified
      (per CLAUDE.md): clean headless boot, no `error|script|parse|invalid|shader`. Exercised via the
      `Main._ready` swap (`_gunscaletest`): owned 6 distinct guns → 7th NEW (MINIGUN) **rejected**,
      size stayed 6, the lowest-level gun (RAPID, first lvl-1 in insertion order) leveled 1→2;
      `roll_choices` at cap offered a NEW gun **0/40** rolls and led with an upgrade **200/200**;
      maxed MINIGUN/RAPID reached L5 (streams=3); a heavy maxed loadout (SHOTGUN/LASER/MORTAR/RAILGUN
      L5) auto-fired live for 4 s producing `[Car] CRUMPLE!` with **zero** SCRIPT ERROR/nil/invalid —
      proving the new `_fire_streams`/override paths run end-to-end. Swap restored from `/tmp/Main.gd.bak`
      (`_gunscaletest` gone, `_front_end.begin()` back) + re-verified a clean boot.
      - [ ] Human playtest / balance (the numbers are first-pass): does the slot cap *feel* good — is
            redirecting an over-cap pickup into your weakest gun satisfying, or does it want a tiny HUD
            tell ("MAX GUNS — leveled RAPID")? Does the 0.05 s floor noticeably tame the MINIGUN hose
            without making it feel weak? Are the per-level depth rewards (streams / corridor / AOE)
            readable as "my gun got stronger"? Tune `MAX_GUNS`/`MIN_COOLDOWN`/`PELLET_CAP`, the
            `_fire_streams` `fan_step` angles (5°/3.5°), the RAILGUN/LASER +0.5 m and MORTAR +1 m
            per-level rates, and the 0.6 upgrade-lead probability. Follow-up logged below.
      - [ ] Follow-up (NOW): a small HUD/feedback cue when an over-cap pickup is redirected into an
            owned gun, so the player understands why the new gun "didn't appear." Also the noted
            "Gun balance pass" (every gun has a reason to be picked) now has the depth rewards to tune
            against. Consider showing the slot count (e.g. "6/6 GUNS") on the HUD gun panel.
      #4 Visual polish (the "asset-flip → art-directed" lever). Before, only fog/ambient/sun
      changed per biome and the runner had no separation light. Now TWO additions, both
      biome-keyed and cross-fading: (1) a code-built `RimLight` OmniLight3D on the runner
      (`PlayerController._ready`, matching the `_star_light`/`GunHold` pattern) sitting
      above-and-ahead (`(0, 2.3, -1.7)`, range 5.5) so it back-lights his camera-facing
      silhouette — separating him from the dark road and tinting him to the biome accent. It
      **breathes brighter with `flow_heat`** (`_rim_base_energy` × `(1 + heat*0.9)` × subtle
      sin breathe) so a hot streak makes him glow; the star aura takes over while invincible
      (rim drive gated on `not _star_active`). New `set_rim_color(color, instant)` is tweened
      by Main on theme change (3 s, matching fog/ambient). (2) A **per-biome 1D color-correction
      LUT** (`GradientTexture1D` duotone tone-curve: shadows→`grade_lo`, highlights→`grade_hi`,
      applied per channel) + a **resting saturation** per biome — both cross-fade in
      `Main._process` by lerping the LUT endpoint colors and the saturation toward the biome
      targets, giving each biome a genuine "designed" grade instead of a recolor. Bullet Time now
      restores to the biome's resting saturation (not a hardcoded 1.22) so the grade survives the
      dip. Each `THEMES` entry gained `rim`/`grade_lo`/`grade_hi`/`sat`: Downtown cool-blue rim +
      cool nocturnal grade (sat 1.18), Countryside warm sun-green (1.08), Industrial hot-amber +
      desaturated grimy (0.95), Neon hot-pink + punchy magenta + lifted sat (1.35). Files:
      `scenes/highway/Highway.gd` (4 theme recipes), `scenes/player/PlayerController.gd` (rim
      light build + flow pulse + `set_rim_color`), `scenes/main/Main.gd` (`_build_grade_lut`,
      grade/sat crossfade in `_process`, rim+grade targets in `_apply_theme`, BT saturation
      restore). Verified (per CLAUDE.md): clean headless boot, no `error|script|parse|invalid|
      shader`. Exercised via the documented `Main._ready` swap (windowed, so `_process` + the LUT
      run for real): boot grade = Downtown (lo (0.04,0.05,0.12), sat 1.18), `RimLight` built with
      Downtown color (0.45,0.7,1.0) energy ~1.78, `adjustment_color_correction` set; forced a
      crossfade to Neon → +1 s later grade/sat/rim all easing toward the Neon targets
      (lo→(0.076,0.032,0.132), sat 1.18→1.28→1.35, rim→(0.635,0.599,0.983)) with zero errors.
      Swap restored from `/tmp/Main.gd.bak` (GRADETEST gone, `_front_end.begin()` back) +
      re-verified a clean headless boot.
      - [ ] Human playtest (GPU look unverified — the whole point is visual): rim energy/range
            (1.7 base, range 5.5 — does it separate the runner without a hot blob on the road or
            blowing out the skin?), the LUT grade strength per biome (lifted blacks via `grade_lo`
            vs the existing `adjustment_contrast` 1.12 — does Industrial read grimy not muddy, Neon
            punchy not garish?), and the 3 s crossfade read on a biome change. Tune the per-theme
            `rim`/`grade_lo`/`grade_hi`/`sat` in Highway.gd + `_rim_base_energy`/pulse in
            PlayerController + the `delta*0.9` crossfade rate in Main.
- [x] **Dynamic difficulty — light, bounded rubber-banding** (2026-06-19, iter 14) — attacks
      the joint-low #8 Difficulty (was 3): the spawn/speed ramp was fully open-loop (pure
      `time_elapsed`), so a struggling player and a flow-state expert got identical traffic. Now
      a single signed `difficulty_bias` in `[-1,+1]` (GameManager) tracks recent performance:
      **+0.018/dodge**, **+0.05/near-miss** (skill flexes press up), **−0.65 on crash** (via
      `cool_flow`, the clearest "struggling" signal → relief), **decays 0.06/s toward neutral**
      when quiet, and a continue clamps to a **−0.6 relief floor** so a comeback isn't brutal.
      Reset to 0 in `start_game`. Mapped to `difficulty_pressure()` (0..1, 0.5 = the plain time
      ramp). CarSpawner reads it: spawn interval ×`lerp(1.14,0.90,p)` (struggling gets ~12% more
      time, flow ~10% less), **+1 car** when `p>0.78` (deep flow) and **−1 car** when `p<0.32`
      (struggling) — both still clamped to `[1, lanes−1]` AND after the existing high-speed
      easing, so the **always-dodgeable-gap guarantee is never violated**. Kept deliberately
      subtle and SEPARATE from `flow_heat` so the music/visual feel that consumes flow_heat is
      untouched. Files: `scripts/autoload/GameManager.gd` (bias field + consts, gains in
      dodge/near-miss handlers, drop in `cool_flow`, relief in `do_continue`, decay in
      `_process`, reset in `start_game`, `difficulty_pressure()`), `scenes/car/CarSpawner.gd`
      (interval mult + wave-size nudge). Verified headless via the `Main._ready` swap: start
      bias 0.0/p0.50 → 20 dodges+6 near-miss bias 0.66/p0.83 (>0.78) → crash bias 0.01/p0.505 →
      2nd crash bias −0.64/p0.18 (<0.32) → 3 s decay from 0.9→0.72 → continue floor p0.20. Clean
      boot, no `error|script|parse|invalid|shader`. **Playtest/tune** the constants + thresholds.
- [x] **Coin pickup juice — "delicious" collection** (2026-06-19, iter 13) — closes the gap
      flagged in FOUR consecutive audits (#3 Juice): coin collection was the one dull moment in
      a loud game (single fixed-pitch blip + 0.04 trauma + instant free; magnet only with the
      orb). Now it's layered: (1) **always-on grab magnet** — `Coin.gd` pulls any coin within a
      gentle 2.6 m radius (< the 2.75 m lane gap so it never yanks from an adjacent lane you
      didn't commit to), with a pull that *accelerates* as the coin nears (lerp 7→26 m/s) for a
      snappy grab; the orb magnet keeps its bigger far-range pull. (2) **Rising-pitch "coin-run"**
      — new `GameManager.coin_streak` ramps on rapid collects (window `COIN_STREAK_WINDOW` 0.7 s,
      cap 16, reset in `_process`/`start_game`); `AudioManager.play_coin(streak)` climbs +0.075
      pitch/step so a run of coins is a satisfying Mario-style scale. (3) **Sparkle burst** — a
      gold additive billboard `CPUParticles3D` one-shot at the pickup point (8→16 sparks with
      streak), parented to the spawner so it survives the coin's free, self-frees at 0.8 s.
      (4) **HUD juice** — new `coin_collected(streak)` signal drives a streak-heated counter
      punch (bigger + gold→white-hot) and a rising/fading **"+1" floater** (shows "+1 x N" at
      streak ≥3). Files: `scripts/autoload/GameManager.gd` (signal + streak + collect_coin),
      `scripts/autoload/AudioManager.gd` (`play_coin(streak)`), `scenes/coin/Coin.gd`
      (auto-magnet + `_spawn_sparkle`), `scenes/ui/HUD.gd` (floater + streak pop). Verified:
      clean headless boot; exercised via the `Main._ready` swap (headless+windowed) — streak
      climbed 1→5 on rapid collects, reset to 0 after the 0.7 s window, fresh collect = 1; the
      sparkle `CPUParticles3D` spawned (`emitting=true`, amount 14 at streak 8) with no error;
      the HUD `coin_collected` handler ran on every collect cleanly. Swap restored + re-verified.
      - [ ] Human playtest (GPU/feel unverified): the auto-magnet 2.6 m radius / 7→26 m/s pull
            (does it feel forgiving without auto-collecting things you weave past?), the streak
            pitch ramp (+0.075/step, cap 14 — exciting vs shrill on a long run?), sparkle
            density/brightness vs the glow post, and the "+1" floater placement under the counter
            (top-right) at real res. Tune in the noted constants.
- [x] **First-run control tutorial (non-blocking, play-integrated)** (2026-06-19, iter 12 deep
      audit ship) — attacks the audit's lowest score (#7 Onboarding, 2). The game taught nothing:
      abilities unlock progressively (jump@10 dodges, bullet-time@25, weapon@50) but the unlock
      was only a flash + dim HUD icon, so a new player never learned a control became available
      or how to use it. New `scenes/ui/TutorialOverlay.gd` (code-built CanvasLayer, no .tscn)
      teaches **through play, never blocking**: a MOVE prompt at run start (clears after 2 m of
      lateral travel), a JUMP prompt that fires the instant jump unlocks (clears on first jump),
      a STOMP prompt after the first jump (clears on first `car_stomped`), and a one-shot
      "GUNS AUTO-FIRE!" toast on the first pickup. Each prompt fades/scales in, breathes, and on
      completion punches green with a ✓ + chime + haptic. First-run only, persisted via new
      `Settings.tutorial_seen` (`[game]`, back-compatible); marked seen the moment the pivotal
      JUMP lesson completes so it never nags; a paid continue doesn't restart it. Wired in
      `Main._ready` (instantiate + `set_player`). Files: `scenes/ui/TutorialOverlay.gd` (new),
      `scenes/main/Main.gd`, `scripts/autoload/Settings.gd`. Verified: clean headless + windowed
      boot; exercised the full step machine via the `Main._ready` swap — MOVE→JUMP_WAIT on
      lateral move, JUMP on unlock, seen=true + STOMP on jump, toast on gun pickup, FINISHED on
      stomp, `_active=false` after end, and no re-begin on a second PLAYING; swap restored + dev
      save's `tutorial_seen` reset to false so the human sees it; re-verified clean.
      - [ ] Human playtest (GPU look/feel unverified): prompt placement at real res (card at 70%
            height, toast at 58% — confirm no clash with the greed meter at ~15.5% or masking the
            next obstacle), the green-✓ confirm read, and the 0.7 s confirm→next pacing. Tune
            `PROMPT_Y`/`TOAST_Y` + timers in TutorialOverlay.gd. MOVE auto-clears after only 2 m —
            watch that it doesn't complete before the player reads it on a packed first wave.
      - [ ] Follow-up (in NOW): extend the pattern to bullet-time (dodge-25) + weapon (dodge-50)
            unlocks; optional persistent control-glyph legend for the first ~20 s.
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
