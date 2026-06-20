# Overnight journal

Each iteration appends a short entry here: what changed, files touched, how it was verified,
and anything the human should review or decide. Newest at the bottom.

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
