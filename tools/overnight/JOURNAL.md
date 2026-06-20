# Overnight journal

Each iteration appends a short entry here: what changed, files touched, how it was verified,
and anything the human should review or decide. Newest at the bottom.

---

## 2026-06-19 — Per-gun distinct fire SFX (iter 5, Build mode)

**What & why:** Shipped a top NOW item (Audio #5, flagged "quick, high-impact win") that
directly serves VISION pillar #3, the build-a-loadout power fantasy. Every gun called
`AudioManager.play_laser`, so stacking 9 different guns sounded *identical* — the carnage
looked varied but sounded like one zap on repeat. Now each gun has its own voice, so a full
loadout reads as a chord of distinct weapons.

**How it works:**
- `AudioManager`: 4 new SFX banks scanned from the Kenney digital kit — `_g_low`
  (lowDown/lowRandom/lowThreeTone), `_g_zap` (zap1/2 + zapTwoTone + zapThreeToneUp/Down),
  `_g_three` (threeTone), `_g_trash` (spaceTrash). New `play_gun_shot(pattern)` dispatches a
  per-`Pattern` pitch/layer recipe: PISTOL crisp pop, RAPID light/fast/quiet pops, MINIGUN
  high hose, SHOTGUN sub-thump (`_crash` low) + noisy spray (`_g_trash`) BOOM, LASER zap over
  a low body layer, SPREAD tonal triple, MORTAR hollow launch *thoomp* (its AOE explosion
  keeps its own `play_crash` boom — no double-up), RAILGUN deep electric crack + sub-boom +
  metal tail (a real *thump*), NET whoosh + soft fizz. Every branch falls back to `_laser` if
  a sound kit is missing (export-safe).
- `GunManager._play_shot` now calls `AudioManager.play_gun_shot(pattern)` instead of
  `play_laser`; the existing rapid-gun audio throttle (MINIGUN/BURST 40%) is unchanged.
  `Main.gd`'s legacy manual-fire weapon still uses `play_laser` (left intact).

**Files touched:** `scripts/autoload/AudioManager.gd`, `scripts/autoload/GunManager.gd`,
`BACKLOG.md`, `tools/overnight/JOURNAL.md`.

**Verified (per CLAUDE.md):** Clean headless boot (no `error|script|parse|invalid|shader`).
Exercised via the documented `Main._ready` swap (`start_game` + `add_gun` for ALL 9 guns):
ran **headless** (220 frames ~3.6s, every gun's cooldown fires at least once incl. the slow
RAILGUN at 1.6s) and **windowed** (real AudioServer actually plays the streams) — both showed
`[GUNTEST] owned=[all 9]` with zero errors. Restored `Main.gd` from `/tmp/Main.gd.bak`,
confirmed test code gone + `_front_end.begin()` back, re-ran a clean headless boot.

**Unverified / risk — human should playtest:** the actual *mix*. dB/pitch values were tuned by
ear-in-head, not on speakers — check relative loudness, whether big guns thump enough vs the
rapid hose, and whether a 9-gun stack is a satisfying chord or turns to mush (the SFX pool is
14 round-robin voices; shotgun/railgun use 2–3 each, so a huge stack may steal voices — likely
fine but unmeasured). Tune in `AudioManager.play_gun_shot`. spaceTrash's exact character is
unheard by me.

---

## 2026-06-19 — Deep audit (iter 4) + game-over "NEW BEST" celebration

**Mode:** Deep-audit (iteration 4 = multiple of 4). Booted clean headless; read the core
scripts critically (PlayerController, GameManager, GunManager, Highway, CarSpawner, HUD,
Coin/CoinSpawner, Juice, GameOverScreen, Settings, Main + Main.tscn env block).

**Rubric scorecard (harsh critic, 1–5):**
1. **Core fun & game loop — 3.** Solid VS-style stacking guns + level-up choice + dodge/
   combo + biomes + continues. But thin reasons to *return*: no shop, missions, or PB chase.
2. **Game feel / responsiveness — 3.** Direct-touch positioning + eased keyboard steering,
   variable jump, lean/flair, speed-FOV all good. Missing: jump input-buffering, coyote time.
3. **Juice & feedback — 4.** Crash sequence, level-up, near-miss, gantry, star FX are strong.
   Gap: **coin pickup** is near-silent (trauma 0.04 + a blip; no pop/sparkle/count).
4. **Visual polish & art direction — 3.** Real post stack exists (ACES tonemap, glow, grade,
   fog) + per-biome fog/ambient/sun. But no per-biome skybox, env particles, weather, or
   player rim-light; still reads a bit asset-flip up close.
5. **Audio — 3.** Playlist + drone + pooled pitched SFX. But **every gun reuses play_laser**
   (kills the loadout fantasy), no adaptive-music layers, no milestone stingers.
6. **Progression & retention — 2 (LOWEST).** `coins` persist but ONLY buy continues. No shop,
   no daily/missions, no leaderboard beyond a single high score, skins ungated. The #1
   runner-retention surface is essentially absent.
7. **Onboarding & UX — 3.** Front-end portrait cards are nice; no tutorial; recap was static.
8. **Difficulty & balance — 3.** Sensible ramp, always-dodgeable gap, traffic eases at speed.
   Gun balance unvalidated.
9. **Performance & stability — 3.** Clean, no errors, but **no pooling** (cars/coins/
   projectiles/particles all instantiate+free) — worst-case carnage unmeasured.
10. **Accessibility & options — 2 (LOWEST).** Only volume + skin. No shake/haptics/flash
    toggles, no colorblind, no in-UI remap.

**Lowest: #6 Progression (2) and #10 Accessibility (2); #5 Audio (3) close behind.** Refilled
BACKLOG "NOW" with 4 scoped items attacking these: meta-coin-shop, daily/missions, per-gun
SFX, and an accessibility/options screen.

**Shipped this iteration (the best fully-completable + verifiable one):** a real game-over
recap — attacks #6 (PB chase) + #7. The old recap was static text + a fragile pulsing label.
Now the hero SCORE counts up from 0 with a rising-pitch blip; supporting stats (dodges ·
**distance** · time) punch in; the BEST line shows best score **and** a new persistent best
**distance**. On a personal best: a "★ NEW BEST ★" / "✦ FURTHEST RUN ✦" banner punches in
(ELASTIC), a 5-emitter multi-color **confetti burst**, a rising 4-note **fanfare**, a flash +
haptic, then a gentle pulse; restart arms only after the payoff. Added `best_distance`
persistence + clean pre-overwrite record detection (`prev_high_score`, `last_run_best_score/
_distance`) so detection no longer relies on the already-overwritten high score.

**Files touched:** `scripts/autoload/GameManager.gd` (best_distance + record flags + save),
`scripts/autoload/AudioManager.gd` (`play_count_tick`, `play_fanfare`),
`scenes/ui/GameOverScreen.gd` (confetti, count-up + celebration sequence), `BACKLOG.md`,
`tools/overnight/JOURNAL.md`.

**Verified (per CLAUDE.md):** Clean headless boot (no `error|script|parse|invalid|shader`).
Exercised the recap **windowed** (real renderer for tweens/CPUParticles2D) via the documented
`Main._ready` swap: forced `start_game` then a 0.6s-delayed test that set run stats and called
`end_game`. Ran BOTH branches — new-best (`last_run_best_score=true best_distance=true`,
fanfare + confetti) and not-a-record (`false/false`, soft drain) — each over 260 frames with
zero errors. Restored `Main.gd` from `/tmp/Main.gd.bak`, confirmed the test fn is gone, re-ran
a clean headless boot.

**Unverified / risk — human should playtest:** no GPU/visual confirmation of the *look*.
Check confetti density/scale (5×22 one-shot particles, negligible but unseen), count-up
duration (scales 0.45–1.1s with score), the banner's ELASTIC overshoot, and fanfare loudness
vs the music duck. `best_distance` adds a new key to `user://highscore.cfg` (back-compatible —
defaults to 0). The "✦ FURTHEST RUN ✦" path only shows when distance is a best but score isn't.

---

## 2026-06-19 — Overhead gantries (Build mode)

**What & why:** Shipped the top NOW item — overhead structures that punctuate the biomes and
sell speed (VISION pillar #1 "Speed you can feel", rubric #4 art direction). The road is long,
flat-overhead and a bit empty up top; rushing *under* a lit structure is one of the cheapest,
strongest speed cues in any runner.

**Asset reality check:** The backlog said to use `kenney_3d-road-tiles` and that CLAUDE.md
"wrongly" called it missing. The folder IS present now — but it's a low-poly **terrain**
road-planning kit (sunken roads/grass/water, `roadTile_001..N.gltf`), NOT tunnels or gantries,
and (like `city-kit-roads`) its tiles don't span the 14 m highway. Rather than force a
top-down terrain asset into an unverifiable visual feature, I built the *design intent*
**procedurally** so it's fully controllable and headless-verifiable. Corrected the CLAUDE.md
asset note to say exactly this.

**How it works:**
- `scenes/highway/Gantry.gd` (new, no .tscn — built in code so the spawner can style it):
  two edge pillars + a top cross-beam + a thinner truss rail + an optional lit hanging sign +
  a dark frame, plus an `OmniLight3D` slung under the beam. Structure is dark metal; sign/
  strips/rail are emissive in the biome accent. `_process` moves it +Z at the highway speed and
  rides the road's cosmetic curve/hills via the **same** `get_curve_offset/get_curve_yaw/
  get_height_offset` lenses cars use, so it sits on the bending/rolling road. Despawns past z>22.
- Pass-under beat (`_do_sweep`, fired once as it crosses the overhead plane z≈9, between the
  player at z=6.5 and camera at z=12): `AudioManager.play_gantry_whoosh()` (new — deep doppler
  whoosh from the `_whoosh` bank pitched to 0.5–0.68 + a soft low `_crash` thud), a near-black
  `Juice.flash` as a momentary "shadow sweep" dim, `kick_fov(5)` + `add_trauma(0.16)` + haptic,
  and the under-light punches to 6.0 then tweens back — the "drove under a lit structure" feel.
- `scenes/highway/GantrySpawner.gd` (new, registered in `Main.tscn`, wired in `Main.gd` like the
  other spawners): **distance-based** spacing (~105 m ± jitter) so cadence is consistent at any
  speed; reads the biome from the highway each spawn for the accent (`ACCENTS` dict — amber
  Downtown / green Countryside / orange Industrial / hot-magenta Neon); ~72% carry a sign, the
  rest are bare trusses for variety; keeps live gantries speed-synced and clears them on a fresh
  run (`state_changed → PLAYING`).
- `AudioManager.play_gantry_whoosh()` added.

**Files touched:** `scenes/highway/Gantry.gd` (new), `scenes/highway/GantrySpawner.gd` (new),
`scenes/main/Main.tscn`, `scenes/main/Main.gd`, `scripts/autoload/AudioManager.gd`, `CLAUDE.md`,
`BACKLOG.md`.

**Verified (per CLAUDE.md):** Clean headless boot (no `error|script|parse|invalid|shader`).
Exercised gameplay via the documented `Main._ready` swap (forced `start_game`, temporarily bumped
`base_speed`/lowered gantry spacing + debug prints): logs showed gantries spawn, ride the road,
**SWEEP at z≈9** firing the whoosh/flash/light, the biome accent flip on a theme change
(DOWNTOWN amber → COUNTRYSIDE green), sign/bare-truss variety, and clean despawn with no errors
or buildup. Ran **windowed** too (real renderer for the meshes/OmniLight/materials) — clean.
Restored `Main.gd` from `/tmp/Main.gd.bak`, removed both debug prints, re-ran a clean boot.

**Unverified / risk:** No GPU/visual confirmation of the actual look — **human should playtest**:
the beam height/clearance (BEAM_H 6.6; camera y 6.6 — should pass cleanly *over* the view but
confirm it doesn't clip the camera near plane), the shadow-sweep dim intensity (0.34 — could be
too dark or too subtle), whoosh timing/loudness vs the engine drone, and spacing/density feel
(105 m may be too frequent or too sparse). The under-light adds one OmniLight per live gantry
(usually 1–2 on screen) — negligible, but noted for the perf pillar. Sign panels are currently
blank lit slabs (no text/icon) — follow-up "Gantry polish v2" added to BACKLOG NOW.

---

## 2026-06-19 — Level-up "choose your weapon" moment (Build mode)

**What & why:** Shipped the top NOW item — the Vampire-Survivors pick-1-of-3 upgrade screen,
the single biggest "one more run" lever (VISION pillar #3, rubric #1 Core fun). Passive gun
pickups from gates still exist; this adds a *meaningful choice* layer on top.

**How it works:**
- Dodges are now XP. `GameManager` gained `run_level`, `level_xp`, `level_xp_needed`
  (curve = 7 + 3·level dodges/level), a `level_up(level)` signal emitted from
  `_advance_level_progress()` (hooked into the existing dodge handler), and `level_progress()`.
- `scenes/ui/LevelUpScreen.gd` (new, registered in `Main.tscn` CanvasLayer): on `level_up` it
  freezes the run via `get_tree().paused = true` (the node is `PROCESS_MODE_ALWAYS` so its
  tweens still animate; tweens use `set_ignore_time_scale(true)`), captures + restores the
  current `Engine.time_scale` so an in-flight Bullet Time isn't clobbered, and shows 3 themed
  gun cards. Picking calls `GunManager.add_gun(id)` (grants new / levels owned). Queues
  multiple pending level-ups; bails cleanly (un-pauses) if the run ends mid-pick.
- `GunManager`: added `GUN_DESC` + `gun_desc()`/`gun_level()` and `roll_choices(n)` (distinct,
  skips maxed guns, leads with a NEW gun when available).
- HUD: slim centered XP bar + "LV n" badge (`_build_xp_bar`/`_update_xp_bar`), eased fill,
  punch on level-up, reset on new run.
- Juice: staggered card punch-in (TRANS_BACK), NEW/LV-up badges, glow-bordered cards in each
  gun's color, `play_unlock` on open + `play_pickup` on select, chosen-card punch + siblings
  fade, reward screen-flash/trauma/FOV-kick/haptic in the gun color after resume. Number keys
  1–3 also select (desktop/accessibility).

**Verified (headless, per CLAUDE.md):** Clean boot, no `error|script|parse|invalid`. Exercised
the full path via the temporary `Main._ready` swap (start_game + `add_gun("PISTOL")` + forced
`level_up.emit(2)` + auto-`_choose`): logs showed cards rolled (randomized each run), selection
granted the gun (`guns=["PISTOL","NET"]`), and the tree un-paused (`paused=false`). Swap restored
from `/tmp/Main.gd.bak`; confirmed test code is gone and re-ran a clean boot.

**Unverified / risk:** Could not headless-simulate a real touch tap or the visual card layout
(no custom `_draw`, so low risk) — **human should playtest** the on-screen look, card readability,
and especially the *pacing* of level-ups (XP curve is a first guess). The pause-freeze (vs
slow-mo) was chosen for safety/clarity; if it feels too abrupt for a speed game, consider a
short slow-mo lead-in. Bullet-time-during-level-up is an untested edge (rare).

**Follow-ups added to BACKLOG Done sub-list:** live 3D gun preview per card, non-gun upgrade
cards, XP-curve tuning, late-run upgrade weighting.

---

## 2026-06-19 — Crash sequence taken to "wow" (Build mode)

**What & why:** Shipped the top NOW item — the signature spectacle (VISION pillar #2,
"Spectacular failure"; rubric #3 Juice). The old crash was a single `time_scale = 0.15` jump +
ragdoll + one flash/trauma/sound. Now it's a layered, choreographed beat designed to make you
*want* to watch yourself die.

**The layers (in order on impact):**
- **Time choreography** (`PlayerController.activate_ragdoll` + new `_run_crash_time_sequence`):
  hard hit-stop (`time_scale = 0.001`) for a frozen impact frame → after 0.07s real, drop into
  held slow-mo (0.12) for 0.42s → cubic-eased "whip" back to 1.0 over 0.22s → 1.5s ragdoll fly →
  settle. All waits use `create_timer(..., ignore_time_scale=true)` so the timeline is wall-clock
  regardless of what time_scale we crashed out of; the whip tween uses `set_ignore_time_scale`.
  Guards (`if current_state != RAGDOLL: return`) bail cleanly if the run resets mid-sequence.
- **Debris** (`PlayerRagdoll._spawn_debris`): one-shot `GPUParticles3D` glass/metal shard burst
  (40, tumbling, gravity, emissive blue) + a bright unshaded spark burst (28, fast, short-lived)
  parented to the scene at the impact point; emitters self-free after burnout. Layers on top of
  the existing body-part gib burst.
- **Screen FX** (`shaders/screen_fx.gdshader`): new `impact_pulse` uniform drives an expanding
  white shockwave ring + a warm/cool per-channel edge fringe (faux chromatic aberration, **no
  screen read** — kept cheap for the perf pillar). Driven by `Juice.impact()` / `impact_pulse()`
  (new decaying value, `IMPACT_DECAY`), read each frame by `HUD._process` into the shader.
- **Audio** (`AudioManager.play_crash` + new `_play_crash_tumble`): metal crush + impact crack +
  pitched-down sub-boom + glass shatter on impact, then a delayed (0.34s) softer tumble crunch
  as the ragdoll lands.
- **Flash/shake/haptic** (`Main._on_player_crashed` + new `_on_crash_landing`): bumped trauma
  (1.25) + FOV kick (28) + `Juice.impact(1.0)`, a sharp white pop → warm-orange afterglow double
  flash, haptic 80, then a secondary landing thud (trauma 0.5 + FOV + haptic) at +0.36s.

**Files touched:** `scenes/player/PlayerController.gd`, `scenes/player/PlayerRagdoll.gd`,
`scripts/autoload/Juice.gd`, `scripts/autoload/AudioManager.gd`, `scenes/ui/HUD.gd`,
`scenes/main/Main.gd`, `shaders/screen_fx.gdshader`.

**Verified (per CLAUDE.md):** Clean headless boot, no `error|script|parse|invalid|shader`.
Exercised the full crash via the temporary `Main._ready` swap (`start_game` + a 0.6s-delayed
`_player.activate_ragdoll(Vector3(0,0,-40))`): `[Player] CRASH!` fired, the sequence ran to
settle over a 600-frame run with zero errors (particles + tweens + delayed timers all clean).
Ran **windowed** too (compiles shaders for real) — shader compiled clean. Swap restored from
`/tmp/Main.gd.bak`, confirmed test code gone, re-ran a clean boot.

**Unverified / risk:** No GPU/visual confirmation — **human should playtest** the actual look &
feel: the hit-stop→slow-mo→whip *timing* (tuned by feel, not playtested), debris readability/
density, the shockwave-ring + chroma-fringe intensity (could be too strong), and whether the
double flash reads as one pop or two. Debris is 40+28 particles/crash, unverified on mobile GPU
(follow-up noted). The chromatic effect is a *faux* edge-fringe (no screen read) for perf, not
true post-process CA — flag if the human wants the real thing (costs a back-buffer copy/frame).

## 2026-06-19 — Meta-progression coin shop (iter 6, Build mode)

**What & why:** Shipped the top NOW item and the single biggest retention lever (VISION
rubric #6 Progression, the joint-lowest audit score of 2). Persistent `coins` previously had
ONE use — paying for a mid-run continue — so there was almost no reason to grind them. Now
there's a permanent-upgrade shop: coins buy power that persists between runs and visibly
escalates how each run starts.

**How it works:**
- **Shop UI** (`FrontEnd._show_shop` + `_make_upgrade_row` + `_buy_upgrade`): a title-screen
  `UPGRADES ◎n` button opens a list of upgrade rows (PanelContainer + Labels + a BUY button —
  deliberately plain controls, NO custom `_draw`, so it's headless-verifiable). Each row shows
  name, description, ●/○ level pips + `LV n/max`, and a `◎cost` / `MAX` button. The whole shop
  is rebuilt on each purchase so level, next cost and the coin balance always reflect state.
  BUY plays `play_unlock` on success / `play_ui` when unaffordable.
- **5 tiered upgrades** (`GameManager.UPGRADES`, next-cost = base + step·level):
  SIDEARM (max 3 — start each run with a Pistol, +1 gun level per tier), AIR DASH (max 1 —
  start with a mid-air double jump), COIN MAGNET (max 1 — always-on magnet), GUARDIAN (max 2 —
  start with N free no-coin revives), LUCKY CHARM (max 4 — +25% coins/run per level).
- **Persistence + API** (`GameManager`): owned levels live in `_upgrades`, saved to the existing
  `user://highscore.cfg` under a new `[upgrades]` section (back-compatible — missing keys → 0).
  Added `upgrade_level/max/is_maxed/cost`, `can_buy_upgrade`, `buy_upgrade` (deduct→bump→emit
  `upgrade_purchased`→save), `coin_multiplier`, and `_apply_meta_upgrades()` called at the end of
  `start_game` (AFTER the per-run manager resets so it layers on a clean slate): sets
  `PowerUpManager.air_jumps`, `PowerUpManager.permanent_magnet`, `free_continues`, and grants
  N starting PISTOLs. `end_game` now scales the coin payout by `coin_multiplier()`.
- **Free revives**: new `GameManager.free_continues` is spent before coins in `do_continue`, and
  `can_continue` returns true on a free revive even when coins are short. `ContinueScreen` shows
  "★ FREE REVIVE ★ (n left)" instead of a coin cost when one is available.
- **PowerUpManager**: new `permanent_magnet` bool (cleared in `reset`, set by `_apply_meta_upgrades`);
  `is_magnet_active()` now returns true while it's set, so the Coin magnet + HUD indicator light up
  for the whole run with no orb needed.

**Files touched:** `scripts/autoload/GameManager.gd`, `scripts/autoload/PowerUpManager.gd`,
`scenes/ui/FrontEnd.gd`, `scenes/ui/ContinueScreen.gd`, `BACKLOG.md`, `tools/overnight/JOURNAL.md`.

**Verified (per CLAUDE.md):** Clean headless boot (no `error|script|parse|invalid|shader`).
Exercised the **apply logic** via the documented `Main._ready` swap (`_shop_test`): bought all 5
upgrades, confirmed cost tiering (e.g. STARTGUN 120→260), maxed STARTGUN→3 (`maxed=true`) and
COINMULT→4 (`coin_multiplier()=2.0`), then `start_game` reported `air_jumps=1 perm_magnet=true
free_revives=1 guns={PISTOL:3}`. Exercised the **shop UI** windowed (temp `begin()→_show_shop` +
a real `_buy_upgrade` → rebuild): built + purchased + rebuilt with zero errors (`[SHOPUI]... lvl=1`).
Restored `Main.gd` from `/tmp/Main.gd.bak` and `FrontEnd.begin()`, removed all test code (grep
confirms none remains), reset the dev save's `[upgrades]` to 0 (the test had bought them), re-ran a
clean headless boot.

**Unverified / risk — human should decide/playtest:**
- **Economy balance** is a first guess: costs 120–580 vs ~`score/10·charm` coins/run. Tune so the
  first upgrade lands in a few runs but a full board is a real grind. (`GameManager.UPGRADES` costs.)
- **Shop layout at real resolution**: 5 rows + heading + balance + BACK via `_new_root`'s
  CenterContainer; should fit 720p+, but if more upgrades are added it'll want a ScrollContainer.
- The dev save (`user://highscore.cfg`) is currently `high=99999`, `coins=2200`, all upgrades 0 —
  left generous so the shop can be playtested immediately. New `[upgrades]` keys are additive.
- Buy SFX reuse `play_unlock`/`play_ui`; a dedicated "ka-ching" + a row punch/particle would make
  spending feel better (follow-up logged). Skins remain free (gating them is a logged follow-up).

## 2026-06-19 — Accessibility & options screen (iter 7, Build mode)

**What & why:** Shipped the top NOW item and attacked the joint-lowest audit score (#10
Accessibility, 2). The game's juice is deliberately heavy (big trauma, double crash flashes,
impact chroma ring) and there was previously NO way to tame it — a hard blocker at a top-10
quality bar and a real comfort/photosensitivity issue. Now there's a proper options surface.

**How it works:**
- **One knob governs all callers** (the key design choice): rather than touch the 57 Juice
  call-sites, the scaling lives *at the source* in `Juice`, read live from `Settings` each call
  so changes apply instantly:
  - `add_trauma(a)` / `kick_fov(deg)` multiply by `Settings.shake_scale` (0..1).
  - `flash(...)` intensity and `impact(amount)` multiply by `_flash_scale()` (1.0 normally,
    0.3 when REDUCE FLASHES is on — a soft floor, not full-off, so feedback still reads).
  - `haptic(ms)` early-returns when `Settings.haptics_on` is false.
  - Safe re: autoload order (Juice loads before Settings): these are only called during
    gameplay, long after all autoloads `_ready`; helpers still guard `if Settings`.
- **Persistence** (`Settings`): new `shake_scale`/`haptics_on`/`reduce_flashes`, saved under a
  new `[accessibility]` section of `user://settings.cfg` (back-compatible — missing keys default),
  with `set_shake_scale`/`set_haptics_on`/`set_reduce_flashes` setters that clamp + save.
- **UI — two surfaces:**
  - **Front-end SETTINGS panel** (`FrontEnd._show_settings`, reached from a new title button):
    a full options screen — MUSIC + SFX rows (slider + on/off, matching the pause style) and an
    ACCESSIBILITY section with a SCREEN SHAKE 0–100% slider (live % readout), HAPTICS toggle, and
    REDUCE FLASHES toggle. All plain Controls (no custom `_draw`) so it's headless-verifiable.
    The shake slider **previews live**: each step fires `Juice.add_trauma(0.5)`, and since Main
    keeps compositing the camera in MENU, the world behind the dim actually shakes at the strength
    you're selecting (scaled by the new value itself — drag to 0% and it stops).
  - **Pause menu**: the same 3 rows appended to the existing audio panel
    (`PauseMenu._make_shake_row` + `_make_toggle_row`), so the options are reachable mid-run too.

**Files touched:** `scripts/autoload/Settings.gd`, `scripts/autoload/Juice.gd`,
`scenes/ui/FrontEnd.gd`, `scenes/ui/PauseMenu.gd`, `BACKLOG.md`, `tools/overnight/JOURNAL.md`.

**Verified (per CLAUDE.md):** Clean headless boot, no `error|script|parse|invalid|shader`.
Exercised the full path windowed via the temporary `Main._ready` swap (`_settings_test`): built
the front-end SETTINGS panel (no errors), then drove the knobs through Settings→Juice — shake 0%
→ `Juice._trauma == 0.000` after `add_trauma(1.0)`; shake 50% adds trauma; reduce-flashes →
`Juice._impact == 0.300` after `impact(1.0)`; haptics-off gate + a `flash` call all ran clean.
Restored `Main.gd` from `/tmp/Main.gd.bak` (confirmed `_settings_test` gone) and re-ran a clean
boot. Test left the dev save's accessibility values at defaults (the test restores them).

**Unverified / risk — human should playtest/decide:**
- **Feel of the defaults & ranges:** shake defaults to 100% (current behaviour); confirm the
  slider feels right end-to-end and whether 0% should fully kill shake (it does) vs a small floor.
- **Reduce-flashes scope:** currently dampens the white `flash` + the `impact` shockwave ring to
  0.3, but NOT the per-channel chroma edge-fringe in `screen_fx.gdshader` (that's driven by the
  same `impact_pulse`, so it IS reduced proportionally — but the speed-line vignette is untouched).
  Decide if reduce-flashes should also calm speed-lines/bullet-time desaturation.
- No GPU/visual confirmation of the live shake-preview look or panel layout at real resolution
  (the front-end panel is now title + 2 audio rows + section label + 3 accessibility rows + BACK;
  should fit 720p+ but verify).

---

## 2026-06-19 — Deep audit (iter 8) + control-crispness pass (jump buffer + coyote)

**Mode:** Deep-audit (iteration 8 = multiple of 4). Booted clean headless; re-read the core
scripts critically (PlayerController, GameManager, CarSpawner, Main) with iters 5-7's changes in
mind. Iters 5-7 had attacked the iter-4 lows (Audio, Progression, Accessibility), so this audit
re-scores to find the new floor.

**Rubric scorecard (harsh critic, 1–5):**
1. **Core fun & game loop — 3.** Stacking guns + level-up pick + dodge/combo + biomes + shop +
   PB chase make a real loop. But the near-miss combo (the natural "greed" hook) is buried —
   GameManager tracks `combo` up to ×9 yet it barely shows. No boss/pursuer beat, no flow-state
   escalation. The depth is there; the *moment-to-moment thrill spikes* aren't surfaced.
2. **Game feel / responsiveness — 3 → ~3.5 after this ship.** Variable jump, eased steering,
   speed-FOV, lean/flair are good. The flagged gap (jump input buffering / coyote time) is what
   this iteration fixes. Lateral easing still untuned.
3. **Juice & feedback — 4.** Crash, level-up, near-miss, gantry, star, game-over celebration all
   strong. Standing gap: **coin pickup** is still near-silent (logged since iter 4).
4. **Visual polish & art direction — 3 (joint-lowest).** Real post stack (ACES, glow, grade, fog)
   + per-biome fog/ambient/sun, but NO env particles, weather, per-biome skybox, or player
   rim-light. Up close it still reads as assembled Kenney kits, not an art-directed world.
5. **Audio — 3.5.** Per-gun SFX (iter 5) fixed the loadout fantasy; playlist + drone + pooled
   pitched SFX. Still no adaptive-music layers or milestone stingers.
6. **Progression & retention — 3.** Shop (iter 6) + PB/best-distance recap (iter 4) lifted this
   off 2. Still no daily/missions, no leaderboard, skins ungated.
7. **Onboarding & UX — 3.** Front-end cards + improved recap; still no tutorial / teaching moment.
8. **Difficulty & balance — 3 (joint-lowest).** Sensible ramp + always-dodgeable gap + traffic
   eases at speed, but gun balance is unvalidated and there's no dynamic difficulty. First-guess
   curves throughout (XP, economy, spawn).
9. **Performance & stability — 3.** Clean, no errors, but still **no pooling** (cars/coins/
   projectiles/particles instantiate+free) — worst-case carnage unmeasured.
10. **Accessibility & options — 3.** Shake/haptics/flash toggles (iter 7) lifted this off 2;
    still no colorblind, motion-blur, remap, or text-scale.

**Lowest cluster: #1 Core fun (3), #4 Visual polish (3), #8 Difficulty (3).** Per VISION priority
(fun → feel → looks), refilled BACKLOG "NOW" with 4 scoped items attacking #1 and #4: a visible
greed/risk multiplier, flow-state escalation, per-biome environmental particles/atmosphere, and a
player rim-light + stronger per-biome grade.

**Shipped this iteration (the best fully-completable + headless-verifiable one):** the
**control-crispness pass** — jump input buffering + coyote time (rubric #2 Game feel, the
longest-standing flagged gap; chosen over the visual items because it's pure logic, fully
verifiable headless, and directly serves the #1-priority "feel"). A jump pressed a few frames
BEFORE landing — the common case when you're descending toward traffic and out of air-jumps —
was silently eaten; now it's buffered (`JUMP_BUFFER_TIME` 0.13s) and auto-fires the instant the
player lands, so a slightly-early tap bounces straight into the next jump. Added `COYOTE_TIME`
(0.10s) grace for a late ground-jump after leaving the floor (mostly latent on the flat-collision
road but future-proofs ledges/hills). Refactored `request_jump()` → `_try_jump() -> bool` + buffer
arm on failure; consumed the buffer in the JUMPING→RUNNING landing transition; topped up coyote
each grounded frame; cleared both windows in `revive()`.

**Files touched:** `scenes/player/PlayerController.gd`, `BACKLOG.md`, `tools/overnight/JOURNAL.md`.

**Verified (per CLAUDE.md):** Clean headless boot (no `error|script|parse|invalid|shader`).
Exercised the full path via the documented `Main._ready` swap (`_feel_test`): forced `start_game`,
enabled the jump ability, ground-jumped (state→JUMPING vy=16.0), fell to y=0.26 descending
(vy=-14.7) and pressed jump while out of air-jumps → `_jump_buffer_t=0.130` (buffered, not lost) →
on landing the buffer fired automatically (`rejumped=true`, state JUMPING, vy=16.0). Restored
`Main.gd` from `/tmp/Main.gd.bak` (grep confirms `_feel_test`/`FEELTEST` gone, `_front_end.begin()`
back), re-ran a clean headless boot.

**Unverified / risk — human should playtest:** the *feel* of the 0.13s buffer / 0.10s coyote —
confirm an early tap reads as crisp/responsive and never as an unwanted "double jump I didn't ask
for"; tune the windows if needed. Lateral easing (`move_speed`/`lateral_accel`) was deliberately
left unchanged this pass (don't alter feel blind) — logged as a follow-up. Coyote is largely
dormant given the flat collision road (the player only leaves the ground by jumping), so the real
felt win here is the buffer; coyote is correctness/future-proofing.

---

## 2026-06-19 — Visible greed / risk multiplier (iter 9, Build mode)

**What & why:** Shipped the top NOW item — the #1-priority "Core fun" lever from the iter-8
audit. The near-miss **combo** (up to ×9) was fully tracked in GameManager but surfaced only as
a tiny "COMBO x2" label that scrolled by unnoticed. The greed/risk loop (thread traffic tight to
keep your multiplier hot, or play safe and lose it) is the moment-to-moment thrill engine of a
runner, and it was invisible. This makes it the loudest thing on screen the instant it's earned.

**How it works:**
- **HUD GREED meter** (`HUD._build_combo_meter` + `_update_combo_meter` + `_on_combo_changed`,
  replacing the old `_build_combo_label`): a "GREED" overline, a chunky **outlined ×N** (font 78)
  and a **draining heat bar**, stacked in a centered VBox at 15.5% screen height (upper third,
  clear of the road/player). On each near-miss the number snaps to the new combo, **punches**
  bigger at higher tiers (`1.32 + 0.05·combo`), and the whole meter shifts color **hot-orange →
  gold → white-hot** (`_combo_color`, lerp over 2→MAX_COMBO). The heat bar width tracks
  `GameManager.combo_fraction()` each frame; under 34% the meter **pulses with rising urgency**
  (blink rate + scale scale up as it empties) — a "use it or lose it" cue — then cools to ×1 with
  a **shrink-fade** (`_hide_combo_meter`).
- **GameManager**: new `combo_fraction()` (the near-miss timer normalized over `COMBO_WINDOW`,
  0 when idle) drives the bar. The combo now **also resets to ×1 in `do_continue()`** — a crash
  you paid to survive still cools the greed — not only on the 3s timeout.
- **Audio**: `AudioManager.play_nearmiss(combo=1)` now **raises the whoosh pitch +0.085 per tier**,
  so a hot streak reads as escalating, tightening tension. `Main._on_near_miss` passes the live
  `GameManager.combo` (GameManager's near-miss handler runs first — autoload connects before the
  scene — so the combo is already incremented when Main reads it; default arg keeps the
  jump-ability's `play_nearmiss()` call unchanged).

**Files touched:** `scripts/autoload/GameManager.gd`, `scripts/autoload/AudioManager.gd`,
`scenes/main/Main.gd`, `scenes/ui/HUD.gd`, `BACKLOG.md`, `tools/overnight/JOURNAL.md`.

**Verified (per CLAUDE.md):** Clean headless boot (no `error|script|parse|invalid|shader`).
Exercised the full path **windowed** (real renderer for the meter tweens/heat bar) via the
documented `Main._ready` swap (`_combo_test`): fired 12 near-misses and watched the combo climb
**×2→×9 and cap** at MAX_COMBO, the heat refill to **1.00** on each, then — feeding stopped — the
bar **drain linearly** (0.79 → 0.63 → 0.46 → 0.29 → 0.13) and **cool to ×1** at empty with the
box fading out (`boxvis` true→false), all error-free. Restored `Main.gd` from `/tmp/Main.gd.bak`
(grep confirms `_combo_test`/`COMBOTEST` gone, `_front_end.begin()` back; the `play_nearmiss(combo)`
edit is intentionally retained), re-ran a clean headless boot.

**Unverified / risk — human should playtest:** no GPU/visual confirmation of the *look*. Check
the meter's placement/size at real resolution (centered at 15.5% vertical, font 78 + a 212px bar
— confirm it never masks the next obstacle/safe gap, the "readable chaos" pillar), the
tier-color/punch feel, the urgency-pulse intensity at low heat, and whether the rising whoosh
pitch is exciting vs shrill at ×9 (tune the `+0.085/tier` bump in `AudioManager.play_nearmiss`).
The combo→×1 reset on a paid continue is new behavior (intended). Logical follow-up, already the
next NOW item: **flow-state escalation** — tie this hot streak to music/grade/spawn density so a
hot combo feels hot across the whole world, not just on the HUD.
