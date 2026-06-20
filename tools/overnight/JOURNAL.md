# Overnight journal

Each iteration appends a short entry here: what changed, files touched, how it was verified,
and anything the human should review or decide. Newest at the bottom.

---

## 2026-06-19 — Level-up "choose your gun" moment (BACKLOG NOW #1)

**State found:** The working tree already held a near-complete implementation of the top
BACKLOG item (a prior iteration left it uncommitted/unjournaled). It was coherent and all its
dependencies existed (`GunManager.MAX_LEVEL`, `Pattern.NET`, `gun_color`, etc.). Per the
working agreement I did not overwrite it — I verified it, finished/hardened it, and documented it.

**What the feature does:** On a dodge-count threshold (7, then 19, 33, 49… widening), GameManager
enters a new `LEVEL_UP` state, drops `Engine.time_scale` to 0.08 (cinematic slow-mo), and emits
`level_up_offered(choices, level)`. `scenes/ui/LevelUpScreen.gd` snaps up 3 weapon cards
(new guns surfaced first, then owned guns as upgrades) with a staggered ease-back pop-in,
per-pattern glyph icon, level pips, NEW/MAX/→ badges, and a dim backdrop that swallows stray
taps. Tap (or keys 1/2/3) → `resolve_level_up(id)` adds/levels the gun, restores time_scale,
returns to PLAYING. Juice on offer + pick (flash, trauma, fov kick, haptic, `play_unlock`).

**Files touched (pre-existing in tree):** `scenes/ui/LevelUpScreen.gd` (new), `Main.tscn`
(wires the node), `GameManager.gd` (state/signals/cadence/resolve), `GunManager.gd` (blurbs +
`roll_level_up_choices`/`describe`), `AudioManager.gd` (keep music across LEVEL_UP resume),
`CarController.gd` + `PlayerController.gd` (collision guards during the choice).

**My change this iteration:** Added a `_physics_process` guard in `PlayerController.gd` so the
runner fully freezes into a tableau during the slow-mo choice (previously it still ran
movement/ability input at 0.08× — a slow drift + stray touch/fire could register through the
Input singleton, which the GUI dim doesn't block). Now the beat reads as a deliberate time-stop.

**Verification (headless, per CLAUDE.md):** (1) Plain front-end load — no error/script/parse/
invalid lines. (2) Temporary `Main._ready` swap to `start_game()` + 7 `register_dodge()` calls
to force an offer, with a real-time (`ignore_time_scale`) timer to `resolve_level_up("LASER")`.
Logs confirmed: offer fires (`state=4` LEVEL_UP, `level=2`), cards build with no errors,
resolve returns `state=1` PLAYING with `owned={"LASER":1}`. Restored `Main.gd` from `/tmp` backup
(confirmed zero diff vs baseline).

**Also present in tree (not mine):** the `assets/kenney_3d-road-tiles/` pack was added (the
asset BACKLOG #3 / overhead-tunnels needs). Left in place; it's the pack CLAUDE.md says was
missing. The CLAUDE.md note and the tunnels feature remain TODO.

**Human should playtest:** the slow-mo feel + card readability on-device (headless can't show
the rendered cards). Decide on the follow-ups logged in BACKLOG Done: distinct pick SFX / a real
"LEVEL UP" stinger (currently reuses the unlock chime), gun GLB on cards vs glyphs, and an
HUD XP bar so the next level-up is anticipated.

**Risk/unverified:** card visuals were not eyeballed (dummy renderer); build path is verified
but layout/spacing on a real phone aspect ratio is unconfirmed.
