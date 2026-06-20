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
