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

---

## 2026-06-19 — Flow-state escalation (iter 10, Build mode)

**What & why:** Shipped the top NOW item — the explicit follow-up to iter 9's greed meter and
the #1-priority "Core fun" lever from the iter-8 audit. The greed *combo* is a short-term, per-
near-miss spike (3s window). What the runner was missing is the *long-term* escalation that
turns "I'm doing well" into a felt, mounting tension: the longer you survive WITHOUT crashing,
the hotter the whole world gets, and a crash visibly cools it. That's the flow-state loop.

**How it works — one central value, many consumers:**
- `GameManager.flow_heat` (0..1): ramps every PLAYING frame by `FLOW_RAMP` (1/70 → ~70s of pure
  clean survival to max) **plus** `FLOW_COMBO_GAIN · (combo−1)` — a hot greed combo stokes the
  heat *faster* (held ×9 reaches max in ~22s), so greedy lane-threading literally turns up the
  temperature ("builds on the greed multiplier" per the backlog). Reset to 0 in `start_game` and
  `do_continue`; snapped to 0 by a new `cool_flow()` called from `Main._on_player_crashed` the
  instant the player crashes.
- **Audio** (`AudioManager`): `_update_music_dynamics` lerps the music target from −3 dB (cold)
  to 0 dB (hot) so a clean run literally sounds bigger; `_process_footsteps` quickens/brightens/
  loudens the stride and shrinks the step interval with heat ("in the zone" sprinting). (The old
  procedural engine drone is dead code — `_setup_engine`/`_fill_engine` are never called since
  footsteps replaced it — so I tied audio to music + footsteps, not the drone.)
- **Visual** (`screen_fx.gdshader` + `HUD` + `Main`): a new `flow_heat` shader uniform adds a
  warm glow that creeps in from the screen **edges** (centre stays clear — the readability
  pillar) and breathes faster as it climbs; driven from `HUD._process` via an eased `_flow_display`
  (`move_toward`, fast cool on a crash, also reset/cleared in `HUD.reset`). Plus a subtle 3D grade
  nudge in `Main._process` (brightness 1.02→1.07, contrast 1.12→1.18 with heat) — saturation is
  left to Bullet Time so there's no conflict.
- **Density**: `CoinSpawner._reschedule` shortens the trail gap up to ~40% (floor 0.4s) and
  `GantrySpawner._arm_next` packs gantries ~30% closer (floor 35 m) when hot — a clean streak
  feels busier and more lucrative, then eases back out as it cools.

**Files touched:** `scripts/autoload/GameManager.gd`, `scripts/autoload/AudioManager.gd`,
`shaders/screen_fx.gdshader`, `scenes/ui/HUD.gd`, `scenes/main/Main.gd`,
`scenes/coin/CoinSpawner.gd`, `scenes/highway/GantrySpawner.gd`, `BACKLOG.md`, this journal.

**Verified (per CLAUDE.md):** Clean headless boot (no `error|script|parse|invalid|shader`).
Exercised the whole chain windowed (real renderer compiles the shader; real-time timers) via the
documented `Main._ready` swap (`_flow_test`): base clean ramp **0.0144/s**; with a held ×9 combo
**0.0464/s** (= FLOW_RAMP 0.0143 + 8·FLOW_COMBO_GAIN 0.004, confirming greed accelerates heat);
the shader `flow_heat` uniform eased toward its target; `adjustment_brightness`/`contrast` rose
above base; coin wait dropped to **1.77s** (base 2.2–4.0) and gantry `next_at` to **61 m** (base
~105) at flow 1.0; `cool_flow()` → **0.0000**. (First test pass exposed only that I forgot to hold
`_combo_timer`, so the combo fell back to ×1 — existing behaviour, not a feature bug; re-ran with
the timer held to confirm the accelerated ramp.) Restored `Main.gd` from `/tmp/Main.gd.bak` (grep
confirms `_flow_test`/`FLOWTEST` gone, `_front_end.begin()` back; the `cool_flow` + grade edits
intentionally retained), re-ran a clean headless boot.

**Unverified / risk — human should playtest:** no GPU/visual confirmation of the *look/feel*.
Key tuning knobs: the **~70s ramp** (does a typical run get hot enough to feel it? `FLOW_RAMP`),
the **warm-glow intensity** (0.55 mix + `smoothstep(0.08,1.0)` deadzone — could be too strong at
max heat or invisible early), whether the **−3→0 dB music swell** is perceptible or too subtle,
and whether the **tighter coin/gantry density** makes a hot run feel exciting vs cluttered (the
readability pillar — gantries at 61 m might feel busy). All gains are small/independent so any one
can be dialed without touching the others. Logged follow-up: a real adaptive-music **filter sweep**
(low-pass opening up on the Music bus with heat) would be a stronger audio cue than a volume swell
— skipped this pass to avoid blind mix risk on a no-speakers iteration.

---

## 2026-06-19 — Per-biome environmental particles & atmosphere (iter 11, Build mode)

**What & why:** Shipped the top NOW item — the iter-8 audit's single biggest "asset-flip →
art-directed" lever (#4 Visual polish, joint-lowest at 3) and a direct hit on VISION pillar #1
(speed you can feel). The road read as assembled Kenney kits in clean air; now the *air itself*
has identity and rushes past, so each biome feels like a designed place and the world streams by.

**How it works — one code-built field, restyled per biome:**
- `scenes/environment/BiomeParticles.gd` (new, no .tscn — built in code so Main can drop it in
  and style it) extends GPUParticles3D. It fills the volume around/ahead of the camera (box
  emission, extents 15×7.5×26 at z≈-10) with a soft radial-dot billboard mote, `amount` 170,
  6 s life with an **alpha-curve fade** (in/hold/out — no spawn/death pops) and `preprocess` 3 s
  so it boots already full instead of warming up empty.
- **Speed-reactive:** `_process` sets `speed_scale = lerp(0.55, 2.3, speed_t) + flow*0.5` from
  `GameManager.highway_speed` — the whole field (motion *and* respawn rate) streams past faster
  the faster you run, and a hot clean streak (`flow_heat`) drives it harder, tying into iter-10's
  flow system for cohesion.
- **Per-biome identity** via a `BIOMES` recipe + `apply_biome(name, instant)`: Downtown pale
  paper/litter (mix blend, gentle fall), Countryside green leaves/pollen (mix, faster fall + more
  sway), Industrial HDR-orange **embers** (additive so they bloom through the glow post, *rise*),
  Neon magenta **motes** (additive, slow drift). Each sets particle color/gravity/scale/velocity/
  turbulence.
- **Cross-fades on biome change** (the polish that keeps it from a hard cut): `apply_biome` tweens
  the process-material `color` and `amount_ratio` (density) over 3 s and applies the new fall
  direction immediately (eases in as particles recycle); glow biomes flip the draw-pass blend mode
  to additive. Wired from `Main._apply_theme` (instant on the first theme, tweened on changes), with
  the node instantiated in `Main._ready`.

**Files touched:** `scenes/environment/BiomeParticles.gd` (new), `scenes/main/Main.gd`,
`BACKLOG.md`, `tools/overnight/JOURNAL.md`.

**Verified (per CLAUDE.md):** Clean headless **and** windowed boot (no `error|script|parse|invalid|
shader`; windowed compiles the StandardMaterial3D + curve/gradient textures for real). Exercised
the full path via the documented `Main._ready` swap (`_biome_test`): `emitting=true amount=170
ratio≈0.9`; applied all 4 biomes and confirmed each gets the right color, gravity sign (leaves
fall -1.4/-1.8, embers rise +1.1, neon +0.25), `amount_ratio` (0.55–0.9) and **blend mode flip**
(0 mix ↔ 1 add for the glow biomes); after a frame of `_process`, `speed_scale` tracked the live
`highway_speed`+`flow_heat` (rose with speed). Restored `Main.gd` from `/tmp/Main.gd.bak` (grep
confirms `_biome_test`/`BTEST` gone, `_front_end.begin()` back), re-ran a clean headless boot.

**Unverified / risk — human should playtest (GPU, the *look* is unconfirmed):** density/size per
biome at real resolution (amount 170, ratios 0.55–0.9 — could read as too sparse or too busy),
whether the HDR ember/neon colors (1.4–1.5) bloom too hot through the existing glow post, the 3 s
cross-fade read on a biome change, and especially whether the field ever costs the "readable chaos"
pillar at top speed + full flow (it's behind/around the play space and faint, but confirm it never
masks the next obstacle). All knobs live in the `BIOMES` dict + the `speed_scale` range. The item's
*other half* — a subtle biome-tinted **near-camera haze** — currently leans on the existing themed
WorldEnvironment fog rather than a new haze pass; logged as a follow-up. Perf: one GPUParticles3D,
170 particles, unshaded billboard — cheap on desktop, unmeasured on mobile GPU (flag with the other
GPU-particle items if a perf pass happens).

---

## 2026-06-19 — Deep audit (iter 12) + first-run control tutorial

**Mode:** Deep-audit (iteration 12 = multiple of 4). Booted clean headless; re-read the core
systems critically with iters 9–11's changes in mind (GameManager, GunManager, CarSpawner,
ProgressionManager, PlayerController jump/stomp/unlock gating, Settings, Main wiring). Iters
9–11 attacked the iter-8 lows (#1 Core fun via greed meter + flow-state; #4 Visual polish via
biome particles), so this audit re-scores to find the new floor.

**Rubric scorecard (harsh critic, 1–5):**
1. **Core fun & game loop — 3.5.** Greed meter + flow-state + level-up pick + shop + biomes +
   PB chase now make a genuinely layered loop with short- AND long-term escalation. Two real
   gaps remain: (a) **guns are now TIMED** (20s stacking layers that expire — see GunManager
   `GUN_DURATION`), which quietly *undercuts* the "build-a-loadout power fantasy" pillar — you
   can't build a lasting arsenal, it constantly evaporates; (b) no boss/pursuer beat for peaks.
2. **Game feel / responsiveness — 3.5.** Jump buffer + coyote (iter 8), variable jump, eased
   steering, speed-FOV, lean/flair. Lateral easing still untuned; no speed-sensation pass
   (wind audio, FOV ramp curve, camera bob) beyond the existing FOV widen.
3. **Juice & feedback — 4.** Crash, level-up, near-miss, gantry, star, game-over celebration,
   flow glow all strong. **Standing gap, now flagged in FOUR audits: coin pickup is still
   near-silent** (no magnetize / rising chime / count-up pop / sparkle). It's the one dull
   moment in an otherwise loud game.
4. **Visual polish & art direction — 3.5.** Post stack (ACES/glow/grade/fog) + per-biome
   fog/ambient/sun + biome particles (iter 11). Still no per-biome skybox, weather, or player
   rim-light; cars still read a touch asset-flip in clean light.
5. **Audio — 3.5.** Per-gun SFX, playlist, footsteps, flow swell. No adaptive filter sweep, no
   milestone stingers.
6. **Progression & retention — 3.** Shop + PB/best-distance recap. **No daily/missions, no
   leaderboard, skins ungated** — the single biggest remaining retention surface.
7. **Onboarding & UX — 2 (LOWEST).** This is the real floor. There was **zero teaching**:
   abilities unlock progressively (jump@10 dodges, bullet-time@25, weapon@50) but the unlock
   was only a flash + a dim HUD icon — a new player has no idea a control became available or
   HOW to use it. No first-run guidance at all. A top-10 runner cannot ship this cold open.
   *(This iteration ships the fix — see below — lifting it toward 3.)*
8. **Difficulty & balance — 3 (joint-low).** Sensible time-based ramp + always-dodgeable gap +
   traffic eases past 40/55 m/s, but it's **fully open-loop** (no dynamic difficulty / no
   reaction to how the player is doing) and every curve (XP, economy, spawn, gun cooldowns) is
   a first guess. Gun balance unvalidated; the timed-gun model especially needs a balance look.
9. **Performance & stability — 3 (joint-low).** Clean, no errors, but still **no pooling** —
   cars/coins/projectiles/particles all instantiate+free; worst-case carnage (many guns × many
   cars × AOE explosions × debris) is unmeasured. The 60fps spell is unprotected under load.
10. **Accessibility & options — 3.** Shake/haptics/flash toggles (iter 7). No colorblind,
    motion-blur, remap, or text-scale yet.

**Lowest cluster: #7 Onboarding (2), then #8 Difficulty (3) and #9 Performance (3).** Per
VISION priority (fun → feel → looks) — onboarding gates whether a new player ever *reaches*
the fun, so it's the highest-leverage floor. Refilled BACKLOG "NOW" with scoped items attacking
#7, #8, #9, plus the timed-gun power-fantasy concern (a #1/#3 risk worth a human decision).

**Shipped this iteration (the best fully-completable + headless-verifiable one):** a
**non-blocking, play-integrated first-run control tutorial** — directly attacks the lowest
score (#7). New `scenes/ui/TutorialOverlay.gd` (code-built CanvasLayer, no .tscn, matching the
LevelUpScreen/BiomeParticles pattern), instantiated + handed the player in `Main._ready`. It
teaches each control **at the moment it becomes available, through play, never blocking**:
- **MOVE** prompt the instant the run starts → clears when the player has moved ≥2 m laterally.
- **JUMP** prompt fires *the instant jump unlocks* (the dodge-10 milestone) — turning the
  previously-opaque unlock flash into an actionable "TAP TO JUMP" → clears on the first jump.
- **STOMP** ("land on a car mid-jump") after the first jump → clears on the first `car_stomped`.
- An independent one-shot **"GUNS AUTO-FIRE!"** toast on the first gun pickup (the auto-fire
  model is non-obvious).
Each prompt fades/scales in (TRANS_BACK), breathes with a sine pulse, and on completion punches
**green with a ✓ + a pickup chime + haptic**, so doing the thing feels acknowledged. Shows
**only on the first run** — persisted via new `Settings.tutorial_seen` (saved under `[game]`,
back-compatible); marked seen the moment the pivotal JUMP lesson completes (so it never nags,
even if the player dies before reaching stomp), and on any run-ending state. A paid continue
re-entering PLAYING does NOT restart the pass (`_active` guard).

**Files touched:** `scenes/ui/TutorialOverlay.gd` (new), `scenes/main/Main.gd` (instantiate +
`set_player`), `scripts/autoload/Settings.gd` (`tutorial_seen` + load/save + `save_tutorial_seen`),
`BACKLOG.md`, `tools/overnight/JOURNAL.md`.

**Verified (per CLAUDE.md):** Clean headless boot (no `error|script|parse|invalid|shader`).
Exercised the **full step machine** via the documented `Main._ready` swap (`_tut_test`), both
headless and **windowed** (real renderer for the Labels/PanelContainer/tweens): reset
`tutorial_seen=false` → `start_game` → step=MOVE(1); moved the player x to 3.5 → step advanced
to JUMP_WAIT(2); emitted `ability_unlocked(&"jump")` → step JUMP(3); emitted
`ability_activated(&"jump")` → `tutorial_seen` flipped **true** and (after the 0.7 s green-confirm
delay) the STOMP(4) prompt showed; `add_gun("LASER")` → `toast_shown=true`; emitted `car_stomped`
→ FINISHED(5); after the end timer `_active=false`, `tutorial_seen` persisted true; and a second
`state_changed(PLAYING)` correctly did **not** re-begin (`_active=false`). Zero errors in either
pass. Restored `Main.gd` from `/tmp/Main.gd.bak` (grep confirms `_tut_test`/`TUT` gone,
`_front_end.begin()` back), reset the dev save's `tutorial_seen` back to **false** (so the human
sees the tutorial on their next launch), re-ran a clean headless boot.

**Unverified / risk — human should playtest (the *look/feel* is GPU-unconfirmed):** prompt
placement at real resolution (card centered at 70% screen height + toast at 58% — confirm they
never mask the next obstacle or clash with the centered greed meter at ~15.5%), the read of the
green ✓ confirm + chime, and especially the **timing/pacing**: does the JUMP prompt appearing at
the dodge-10 unlock feel well-placed, and is the 0.7 s confirm→next delay snappy or sluggish?
Tune `PROMPT_Y`/`TOAST_Y` + the timer durations in TutorialOverlay.gd. Note the MOVE step
auto-completes after only 2 m of lateral travel — on a packed first wave a player might dodge
that far before reading the prompt; acceptable (they *learned by doing*), but worth a look.
**Design flag for the human (not shipped):** the timed-gun model (guns expire after 20 s) is in
tension with the VISION "build-a-loadout power fantasy" pillar — logged as a NOW item to decide.

---

## 2026-06-19 — Coin pickup juice: "delicious" collection (iter 13, Build mode)

**What & why:** Closed the single most-repeatedly-flagged gap in the game — coin collection,
called out as "the one dull moment in an otherwise loud game" in **four consecutive deep
audits** (iters 4, 8, 12 + the iter-4 origin). Picked it over the open NOW structural items
because it's a pure juice/feel win (VISION: "Juice over features, Fun over everything"), fully
headless+windowed-verifiable, and low regression risk — exactly the safe, complete, *juicy*
increment the brief asks for, and it finally retires a standing liability. Before: a single
fixed-pitch blip + 0.04 trauma + instant `queue_free`; the magnet only worked with the orb.

**The four layers:**
- **Always-on grab magnet** (`scenes/coin/Coin.gd`): any coin within a gentle `AUTO_MAGNET_RADIUS`
  (2.6 m — deliberately *under* the 2.75 m lane gap so it never yanks a coin from an adjacent lane
  you didn't commit to; preserves the "weave to grab" skill) homes toward the player with a pull
  that **accelerates as it nears** (`lerpf(26, 7, dist/R)` → faster up close) for a snappy "snap-in"
  grab. The orb magnet keeps its larger `PowerUpManager.MAGNET_RADIUS` far-range pull (branch kept).
- **Rising-pitch "coin run"** (`GameManager` + `AudioManager`): new `coin_streak` ramps on rapid
  collects (`COIN_STREAK_WINDOW` 0.7 s, cap `COIN_STREAK_MAX` 16), ticked down in `_process` and
  reset in `start_game`. `play_coin(streak)` now climbs **+0.075 pitch/step** (cap 14) so a string
  of coins is a satisfying Mario-style ascending scale instead of one repeated zap.
- **Sparkle burst** (`Coin._spawn_sparkle`): a gold, additive, billboarded `CPUParticles3D`
  one-shot (8→16 sparks scaling with streak, 0.45 s life, gravity, alpha-fade `color_ramp` +
  shrink `scale_amount_curve`) at the exact pickup point. Parented to the **spawner** so it
  survives the coin's immediate `queue_free`; self-frees via a 0.8 s SceneTreeTimer.
- **HUD juice** (`scenes/ui/HUD.gd`): new `GameManager.coin_collected(streak)` signal drives a
  **streak-heated counter punch** (scale 1.22→1.62, color gold→white-hot as the streak climbs) and
  a rising, fading **"+1" floater** above the counter (reads "+1  xN" at streak ≥3). The old
  `coins_changed` handler now only sets the text (so shop/continue coin changes don't double-pop).

**Files touched:** `scripts/autoload/GameManager.gd` (`coin_collected` signal, `coin_streak` +
window const, streak logic in `collect_coin`, reset in `_process`/`start_game`),
`scripts/autoload/AudioManager.gd` (`play_coin(streak)`), `scenes/coin/Coin.gd` (auto-magnet +
`_spawn_sparkle`), `scenes/ui/HUD.gd` (`_on_coin_collected` + `_spawn_coin_floater`, text-only
`_on_coins_changed`), `BACKLOG.md`, this journal.

**Verified (per CLAUDE.md):** Clean headless boot (no `error|script|parse|invalid|shader`). One
caught bug en route: `CPUParticles3D` takes a raw `Curve`/`Gradient` for `scale_amount_curve`/
`color_ramp` (not the `CurveTexture`/`GradientTexture1D` wrappers GPU process-materials use) — the
parse error surfaced on the first boot and was fixed. Exercised the full chain via the documented
`Main._ready` swap (`_coin_test`), **headless and windowed**: rapid `collect_coin` ramped the
streak **1→5**, it **reset to 0** after a >0.7 s gap, a fresh collect went back to **1**; a real
`Coin` instance's `_spawn_sparkle(8)` added a `CPUParticles3D` to the spawner (`emitting=true`,
`amount=14` = 8 + int(8·0.8)) with no error; the HUD's `coin_collected` handler ran on all six
emissions cleanly. Restored `Main.gd` from `/tmp/Main.gd.bak` (grep confirms `_coin_test`/`COINTEST`
gone, `_front_end.begin()` back), re-ran a clean headless boot.

**Unverified / risk — human should playtest (GPU/feel unconfirmed):** the **auto-magnet feel** —
2.6 m radius + 7→26 m/s accelerating pull: does it read as forgiving without grabbing coins you
intentionally weaved past? (tune `AUTO_MAGNET_RADIUS` / the `lerpf` in `Coin._physics_process`). The
**streak pitch ramp** (+0.075/step, cap 14 → up to ~+1.05 pitch) — exciting vs shrill on a long
run? The **sparkle** density/brightness against the existing glow post (additive gold may bloom).
The **"+1" floater** placement (top-right, under the `◎` counter) and the streak-heated punch at
real resolution. All knobs are the named constants. Low-risk note: the floater + sparkle add a
transient `Label`/`CPUParticles3D` per coin (both self-free) — negligible, but it's the first
per-pickup allocation on the hot coin path, so it's worth a glance if/when the pooling item lands.

---

## 2026-06-19 — Dynamic difficulty: light, bounded rubber-banding (iter 14, Build mode)

**What & why:** Attacked the joint-low rubric floor **#8 Difficulty & balance (3)** with the
top open NOW item. The spawn/speed ramp was **fully open-loop** (pure `time_elapsed`) — a
player barely surviving and a player in deep flow got identical traffic, so deaths could feel
unfair on the way up and the ceiling never tightened for experts. Picked it over the two other
floors deliberately: **#9 pooling** is flagged high-regression-risk (lifecycle bugs pass smoke
yet break feel) — wrong call for an unsupervised overnight iter; **DECIDE timed-guns** needs a
human. DDA is additive, bounded, and safe: it layers a small signed nudge on top of the
existing ramp and can only move within hard clamps, so worst case it does *less* than intended,
never something broken.

**Design (kept deliberately subtle & invisible — visible rubber-banding feels patronizing):**
A single signed `difficulty_bias` in `[-1, +1]` on GameManager, 0 = the untouched time ramp.
- **+0.018 per dodge**, **+0.05 per near-miss** — steady control / skill flexes press it up.
- **−0.65 on crash** (in `cool_flow()`, the canonical crash hook, already wired from Main) —
  the clearest "struggling" signal → swing toward relief.
- **decays 0.06/s toward 0** in `_process` when nothing notable happens (a quiet stretch
  settles back to the plain ramp rather than staying biased).
- **continue** clamps to a firm **−0.6 relief floor** so a revived comeback isn't instantly
  brutal; **reset to 0** in `start_game`.
- Mapped to `difficulty_pressure()` → 0..1 (0 relief, 0.5 neutral, 1 pressure).

Crucially kept **separate from `flow_heat`** (which several systems consume for music/visual
feel) so none of that feel changes — DDA is its own narrow concern.

**CarSpawner consumption (both paths preserve the always-dodgeable-gap guarantee):**
- Spawn interval ×`lerp(1.14, 0.90, pressure)` — struggling gets ~12% more time between waves,
  deep flow ~10% less; still clamped to `min_spawn_interval`.
- Wave size: **+1 car** when `pressure > 0.78` (applied *before* the existing high-speed easing
  so speed-easing still wins late), **−1 car** when `pressure < 0.32`; final
  `clampi(max_cars, 1, lanes−1)` guarantees a gap regardless.

**Files touched:** `scripts/autoload/GameManager.gd` (`difficulty_bias` + 5 consts; gains in
`_on_dodge_registered`/`_on_near_miss`; drop in `cool_flow`; relief in `do_continue`; decay in
`_process`; reset in `start_game`; new `difficulty_pressure()`), `scenes/car/CarSpawner.gd`
(interval mult in `_process` + wave-size nudge in `_on_spawn_timer_timeout`), `BACKLOG.md`,
this journal.

**Verified (per CLAUDE.md):** Clean headless boot, no `error|script|parse|invalid|shader`
(ignored "resources still in use at exit"). Exercised the full signal chain via the documented
`Main._ready` swap (`_ddatest`, since the front-end never auto-starts headless): start
**bias 0.000 / pressure 0.500** → 20 dodges + 6 near-miss **bias 0.660 / p 0.830** (crosses the
0.78 pressure threshold) → crash **bias 0.010 / p 0.505** → 2nd crash **bias −0.640 / p 0.180**
(crosses the 0.32 relief threshold) → 3 s of decay from 0.9 → **0.720** → continue with prior
bias 0.2 → **−0.600 / p 0.200** (relief floor held). All clamps and thresholds behave; both
realistic-play extremes are reachable. Restored `Main.gd` from `/tmp/Main.gd.bak` (grep confirms
`_ddatest`/`DDATEST` gone, `_front_end.begin()` back) and re-ran a clean headless boot.

**Unverified / risk — human should playtest (feel is the whole point and is GPU/play-unconfirmed):**
the magnitudes are first guesses. Does the relief after a crash/continue read as *fair* without
feeling like the game went easy on you? Does the deep-flow +1 car land as "the game noticed I'm
good" or just "suddenly harder"? Tune the named knobs: `DDA_DODGE_GAIN`/`DDA_NEARMISS_GAIN`/
`DDA_CRASH_DROP`/`DDA_CONTINUE_RELIEF`/`DDA_DECAY` in GameManager and the `lerpf(1.14, 0.90, …)`
range + the `0.78`/`0.32` thresholds in CarSpawner. Note the system is intentionally **invisible**
(no HUD tell) — if it ever feels off it'll be hard to diagnose by eye; the print harness in the
`_ddatest` swap is the way to re-inspect the numbers. Follow-up logged: a broader end-to-end
difficulty-curve tuning pass once this is playtested.
