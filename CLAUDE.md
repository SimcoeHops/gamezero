# Crashman — Architecture & Asset Map

Endless-runner crash game. Godot 4.7, mobile renderer. You sprint down a highway,
dodge/jump/stomp traffic, grab power-ups, and ragdoll spectacularly on death.
This is **vibe-coded**: prioritize *fun* and game-feel over architectural purity.
Keep changes minimal and scoped; don't refactor what you weren't asked to touch.

## Autoloads (order matters — set in `project.godot`)
Load order is significant: `Settings` must load **before** `AudioManager` (AudioManager
calls `Settings.apply_audio()` in its `_ready`). Current order:
`ProgressionManager → GameManager → PowerUpManager → GunManager → InputSettings → Juice → Settings → AudioManager`.
Any new autoload that AudioManager depends on must be registered before it.

- **GameManager** (`scripts/autoload/GameManager.gd`) — run state machine (`GameState`:
  MENU/PLAYING/GAME_OVER/REVIVE_OFFER), `highway_speed`, `time_elapsed`, scoring
  (near-miss/combo), `start_game()` (resets PowerUp/Gun state — fresh run only, NOT on
  continue), `player_died()`. `state_changed(new_state)` drives spawners. Also tracks
  end-of-run recap data: `run_distance`, `top_speed`, `biome_log` (via `log_biome()`).
- **ProgressionManager** — ability unlocks + dodge/near-miss/milestone tracking.
  `register_dodge()`, `register_near_miss()`; signals `dodge_registered`, `near_miss`,
  `milestone_reached`, `ability_unlocked`.
- **PowerUpManager** — orb power-up state: `is_invincible()` (star), `speed_multiplier()`,
  `air_jumps`, legacy `fire_mode`/`bullet_count` (old manual-fire weapon, still wired to the
  "fire" button), `fly_requested`/`powerups_changed` signals. `Type` enum + `apply(type)`.
- **GunManager** (`scripts/autoload/GunManager.gd`) — the **auto-fire gun system**
  (Vampire-Survivors direction). `GUNS` dict = 8 guns (PISTOL/RAPID/SHOTGUN/LASER/MORTAR/
  SPREAD/MINIGUN/RAILGUN), each a distinct fire `Pattern`. `owned` = id→level; re-picking a
  gun levels it up (faster + more pellets). `_process` auto-fires every owned gun on its own
  cadence at the player's muzzle. Player calls `register_player(self, muzzle)`; pickups call
  `add_gun(id)`; `reset()` from `GameManager.start_game`. `summary()` feeds the HUD,
  `guns_changed` signal updates HUD + held-gun model.
- **Juice** — trauma camera shake, FOV kick, hit-stop, screen flash, haptics.
  Main composites the camera each frame from `Juice.shake_offset()/shake_roll()/fov_kick()`.
- **Settings** — persisted music/sfx volume + on/off + chosen character skin; applies to buses.
- **AudioManager** — builds Music/SFX buses at runtime (no bus-layout asset). Pooled,
  pitch-varied SFX (`play_crash/car_hit/laser/pickup/coin/unlock/nearmiss/drain/ui`).
  Real music playlist (`res://music/*.mp3`) played via a **shuffle bag** (`_play_order`):
  reshuffles + starts a fresh random track on each new run (state→PLAYING where prev !=
  REVIVE_OFFER, so a paid continue keeps its song); fade-in + menu ducking in
  `_update_music_dynamics`. Procedural synthwave fallback if no mp3s (`AudioStreamGenerator`;
  there is NO baked music asset). Also a speed-reactive engine drone.
- **InputSettings** — `get_move_axis()` and input remap helpers.

## Scene scripts
- `scenes/main/Main.gd` — root. Wires player/spawners, applies per-theme sun/fog/ambient
  (`_apply_theme`), composites camera from Juice. Front-end (`MENU` branch calls
  `_front_end.begin()`); see headless gotcha below.
- `scenes/player/PlayerController.gd` — `CharacterBody3D` state machine: RUNNING/JUMPING/
  BULLET_TIME/FIRING/FLYING/RAGDOLL/DEAD. Variable-height jump, double-jump→FLY,
  lateral easing. **Mario-style car stomp**: `can_stomp()` (true while JUMPING) +
  `stomp_bounce()` — airborne contact crumples the car and bounces instead of dying.
  Registers its `ProjectileSpawn` muzzle with GunManager and shows the most-recent gun GLB
  at a code-built `GunHold` node (`_update_held_gun`; cosmetic — orientation `rotation.y=PI`).
- `scenes/player/PlayerRagdoll.gd` — physics-bone gib burst on crash.
- `scenes/car/CarController.gd` — per-car lifecycle APPROACHING→CRUMPLED→DODGED.
  `apply_variant(model, tint, size)`, `crumple(point, vel)`, BeamNG-style mesh deform
  via `CrumpleDeformer`.
- `scenes/car/CarSpawner.gd` — wave spawning, speed/interval ramp, lane logic
  (always leaves a dodgeable gap). Car model list = `CAR_MODEL_PATHS` (GLB).
- `scenes/highway/Highway.gd` + `HighwaySegment.gd` — scrolling road, per-theme THEMES,
  cosmetic curve (`get_curve_offset`) + cosmetic **rolling hills** (`get_height_offset`).
  Both are perspective "lenses": flat near the camera (collisions unaffected), bending/rolling
  into the distance. Hills are keyed to `(z - _road_travel)` so crests are stable world
  features rolling toward you (NOT an in-place wave — that earlier bug looked like "tiles on
  pistons"). Each flat tile is set to its two EDGE heights and PITCHED (`rotation.x`) to span
  them; since neighbours share an edge z they meet exactly, so the road is a connected ramp
  with no gaps/steps. Cars (`CarController._apply_curve_visual`) and gates ride the hills
  visually. Ordered biomes: Downtown→Countryside→Industrial→Neon.
- `scenes/powerup/PowerUp.gd` + `PowerUpSpawner.gd` — pickups rendered as glowing **ring
  gates** you run through (TorusMesh + energy curtain + billboarded WORD + colored light).
  Spawner routes each gate to an orb effect, a power-down (`drain_chance`), or a **gun gate**
  (`gun_chance` → `PowerUp.gun_id` → `GunManager.add_gun`). `LABELS`/`COLORS` dicts.
- `scenes/coin/Coin.gd` + `CoinSpawner.gd` — coin trails, persistent `coins` meta.
- `scenes/projectile/Projectile.gd` — projectile for both the legacy weapon and the guns.
  Straight `-Z` travel; `piercing`; plus `aoe_radius` + `lob_gravity`/`lob_vy` (mortar arc +
  explosion) and `tint` (per-gun color). `_explode()` crumples cars in radius.
- `scenes/ui/` — `HUD.gd` (left-side active power-up + **gun** indicator panel via
  `GunManager.summary()`; biome "NOW ENTERING" labels now at **top** of screen; speed-line/
  vignette driver), `JourneyMap.gd` (end-of-run top-down recap: biome-colored road ribbon +
  stats, custom `_draw`, added to GameOverScreen), `FrontEnd.gd` (title→NEW GAME→8-char
  select), `PauseMenu.gd`, `GameOverScreen.gd`, `ContinueScreen.gd` (paid REVIVE_OFFER).
  `FrontEnd` runner cards render a **live 3D portrait** per skin via a per-card SubViewport
  (`_make_skin_preview`: characterMedium model + skin + front camera at -Z) — NOT the raw
  UV-atlas texture (which looked "weird"). Camera framing constants are in that function.
- `scripts/utils/CrumpleDeformer.gd` — vertex deformation helper.
- `shaders/screen_fx.gdshader` — speed lines + vignette; bullet-time desaturates the world.

## Collision model (IMPORTANT — easy to get wrong)
Cars are **frozen `RigidBody3D` moved by position**, which bypasses normal
`CharacterBody3D` collision response. So:
- **Primary** hit detection = the player's `PlayerHitbox` Area3D
  (`PlayerController._on_hitbox_body_entered`). Cars have `crumple()`.
- **Secondary** = `CarController._on_body_entered` (RigidBody contact_monitor) — less
  reliable for frozen bodies, so both paths exist and both must honor invincibility
  and `can_stomp()`. Keep the two in sync when changing crash/stomp behavior.

## Assets (`assets/`)
- **kenney_car-kit** — car GLB/FBX/OBJ. Uses a single shared **`colormap.png`** palette
  texture (`Models/<fmt>/Textures/colormap.png`) — UVs index color swatches (body/windows/
  wheels/lights). The GLBs import as `StandardMaterial3D` carrying that 512² texture.
  `CarController._apply_tint` PRESERVES it (albedo + emission texture) and tints gently
  (`color.lerp(WHITE, 0.55)`); do NOT overwrite `albedo_color` with a saturated flat color or
  you crush all the detail into a blob (the original "untextured cars" bug).
- **kenney_blaster-kit_2.1** — guns as **GLB** (`Models/GLB format/blaster-a..r.glb`,
  `grenade-a/b.glb`, already imported, ~0.8 m along Z) and FBX. Used by GunManager (`model`
  field) for the held-gun visual.
- **kenney_road-textures** — flat **top-down** map tiles (roads on grass/water). They look
  worse than the asphalt in a 3D perspective road, so they're earmarked for the top-down
  JourneyMap, not the road surface. The 3D road keeps `retro-urban-kit/.../asphalt.png`.
- **kenney_city-kit-roads** — 3D road pieces (small 1-unit top-down tiles; don't span the
  14 m highway cleanly).
- **kenney_3d-road-tiles** — present, but it's a low-poly *terrain* road-planning kit
  (sunken roads, grass, water; `Models/gLTF/roadTile_001..N.gltf`), NOT the overhead
  tunnels/gantries the old note imagined — these don't span the 14 m highway cleanly either.
  Overhead **gantries** were therefore built **procedurally** instead (`scenes/highway/
  Gantry.gd` + `GantrySpawner.gd`): code-built pillars/beam/sign + an under-light, tinted
  per biome (`ACCENTS`), riding the curve/hills like cars, with a doppler whoosh
  (`AudioManager.play_gantry_whoosh`) + dark "shadow sweep" flash + FOV/light kick on
  pass-under. The terrain tiles remain earmarked for a future top-down map use, not the road.
- **kenney_animated-characters-protagonists** — player + `Animations/run.fbx` (run anim
  loaded dynamically in `PlayerController._ready`). Also retro/blocky character kits,
  city-kit-commercial/industrial, retro-urban-kit, digital-audio + impact-sounds (SFX).
- `music/` — playlist mp3s (`1..4.mp3`, all imported). New mp3s need `--headless --import`
  once before `load()`; AudioManager builds the playlist dynamically, so just drop files in.

## Headless verification (macOS) — read before testing
Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`.
- No `timeout` on macOS — use `--quit-after <frames>` so Godot self-quits.
- Always pass an **absolute** `--path /Users/beng/Development/crashman/crashman`. A stray
  `cd` into a subfolder persists between Bash calls and breaks `--path .` ("no main scene").
- New `.mp3` / any new asset needs `--headless --import` once before it will `load()`.
- The front-end waits for input, so **headless never auto-starts gameplay**. To exercise
  gameplay headless: temporarily swap `Main._ready`'s MENU branch (`_front_end.begin()`)
  for `GameManager.start_game()`, run, then restore from a `/tmp` backup. To test guns, add
  `GunManager.add_gun("LASER")` etc. after the `start_game()` and watch for `[Car] CRUMPLE!`
  logs (auto-fire hitting cars proves the whole chain). To test the JourneyMap, also set
  `GameManager.run_distance`/`top_speed`/`biome_log` then call `GameManager.end_game()`.
- The dummy renderer may not call `_draw()` — to verify custom-drawn UI (e.g. JourneyMap),
  run **windowed** (omit `--headless`) with `--quit-after`; `_draw` then runs for real.
- Filter run output for `error|script|parse|invalid`. `"N resources still in use at exit"`
  is a benign shutdown warning, not a failure.
- Autoload edits to `project.godot` show false "Identifier not declared" errors in an open
  editor until **Project → Reload Current Project**.

## Working agreement
- Build **one feature at a time**, verify headless, then move on.
- Keep a running checklist of multi-part prompts in
  `~/.claude/projects/-Users-beng-Development-crashman-crashman/memory/` so progress
  survives context truncation. See `crashman-feel-overhaul.md` and any `*-checklist.md`.
- Ask, before deleting/overwriting unfamiliar work: did I create this? does it match its
  description?
