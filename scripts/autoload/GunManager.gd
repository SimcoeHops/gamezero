## GunManager — Autoload for the stacking, auto-firing gun system.
##
## Guns are picked up from gates while running. Each distinct gun becomes its own
## weapon that AUTO-FIRES on its own cadence (Vampire-Survivors style) — you never
## press a button. Picking up the same gun again levels it up (faster / more
## pellets). All owned guns fire at once, so the loadout stacks into chaos.
##
## State lives here (so it survives the player ragdoll and resets per run); the
## actual muzzle + scene come from the player via [method register_player].

extends Node

## Emitted whenever the owned guns change (pickup / level-up / reset).
signal guns_changed()

## Emitted when a brand-new gun picked up beyond [constant MAX_GUNS] is redirected
## into deepening an already-owned gun instead of opening a 7th slot. Carries the
## gun it leveled + that gun's new level, so the HUD can explain to the player why
## the new gun "didn't appear" (otherwise the slot cap reads as a dropped pickup).
signal gun_redirected(target_id: String, new_level: int)

## Firing patterns.
enum Pattern { SINGLE, BURST, SHOTGUN, LASER, MORTAR, SPREAD, MINIGUN, RAIL, NET }

## Highest level a single gun can reach (also the cap on stacked timed layers).
const MAX_LEVEL := 5

## Maximum number of distinct guns owned at once (Vampire-Survivors weapon-slot
## cap). A brand-new gun picked up beyond this deepens an owned gun instead of
## opening a 7th slot — this is what bounds the runaway simultaneous-fire rate.
const MAX_GUNS := 6

## Per-gun fire-rate floor (seconds). 0.05 = a 20 shots/s ceiling on any single
## gun, so even a maxed RAPID/MINIGUN can't hose hard enough to threaten 60fps.
const MIN_COOLDOWN := 0.05

## Hard cap on a single gun's pellet count, so SHOTGUN/SPREAD can't balloon as
## they level.
const PELLET_CAP := 9

## How long a single gun pickup lasts before that layer drops off (seconds).
const GUN_DURATION := 20.0
## Remaining time (seconds) at/under which the HUD should warn the player.
const WARN_TIME := 5.0

## The gun roster. Each is a distinct, readable behavior. `model` is a GLB
## basename under the blaster kit; `color` drives the projectile, gate and HUD.
const GUNS := {
	"PISTOL": {
		"name": "PISTOL", "model": "blaster-a", "color": Color(1.0, 0.85, 0.25),
		"pattern": Pattern.SINGLE, "cooldown": 0.5, "speed": 70.0, "scale": 1.0,
	},
	"RAPID": {
		"name": "RAPID", "model": "blaster-b", "color": Color(1.0, 0.55, 0.1),
		"pattern": Pattern.BURST, "cooldown": 0.09, "speed": 80.0, "scale": 0.85,
		"burst_count": 14, "burst_pause": 1.4,
	},
	"SHOTGUN": {
		"name": "SHOTGUN", "model": "blaster-c", "color": Color(1.0, 0.4, 0.15),
		"pattern": Pattern.SHOTGUN, "cooldown": 0.85, "speed": 60.0, "scale": 1.0,
		"pellets": 5, "spread_deg": 26.0,
	},
	"LASER": {
		"name": "LASER", "model": "blaster-d", "color": Color(1.0, 0.2, 0.85),
		"pattern": Pattern.LASER, "cooldown": 0.35, "speed": 110.0, "scale": 0.9,
		"piercing": true,
	},
	"MORTAR": {
		"name": "MORTAR", "model": "grenade-a", "color": Color(0.5, 1.0, 0.4),
		"pattern": Pattern.MORTAR, "cooldown": 1.3, "speed": 26.0, "scale": 1.3,
		"aoe": 6.0, "lob_gravity": 22.0, "lob_vy": 7.0,
	},
	"SPREAD": {
		"name": "SPREAD", "model": "blaster-e", "color": Color(0.35, 0.85, 1.0),
		"pattern": Pattern.SPREAD, "cooldown": 0.55, "speed": 75.0, "scale": 1.0,
		"pellets": 3, "spread_deg": 20.0,
	},
	"MINIGUN": {
		"name": "MINIGUN", "model": "blaster-f", "color": Color(1.0, 0.95, 0.6),
		"pattern": Pattern.MINIGUN, "cooldown": 0.06, "speed": 90.0, "scale": 0.7,
		"spread_deg": 9.0,
	},
	"RAILGUN": {
		"name": "RAILGUN", "model": "blaster-g", "color": Color(0.7, 0.4, 1.0),
		"pattern": Pattern.RAIL, "cooldown": 1.6, "speed": 150.0, "scale": 1.8,
		"piercing": true,
	},
	"NET": {
		"name": "NET", "model": "blaster-r", "color": Color(0.3, 1.0, 0.55),
		"pattern": Pattern.NET, "cooldown": 0.95, "speed": 34.0, "scale": 1.0,
		"piercing": true, "width": 4.4,
	},
}

## One-line flavor for each gun, shown on the level-up choice cards.
const GUN_DESC := {
	"PISTOL": "Steady aimed shots",
	"RAPID": "Blistering bullet stream",
	"SHOTGUN": "Close-range buckshot",
	"LASER": "Instant piercing beam",
	"MORTAR": "Lobbed area blast",
	"SPREAD": "Three-way volley",
	"MINIGUN": "Relentless bullet hose",
	"RAILGUN": "Heavy piercing slug",
	"NET": "Wide crowd-clearing sweep",
}

## Stable, ordered list of gun ids (for random pickup).
var GUN_IDS: Array = GUNS.keys()

## Owned guns: id -> level (1..MAX_LEVEL). Derived from [member _stacks] and kept
## in sync so the HUD / held-gun visual / journey map can read it cheaply.
var owned: Dictionary = {}

## Timed layers per gun: id -> Array[float] of remaining seconds. Each pickup of a
## gun pushes another 20 s layer (so duplicates stack as overlapping timers); a
## layer drops off when it expires, lowering the gun's level, and the gun is gone
## once its last layer expires.
var _stacks: Dictionary = {}

## Per-gun firing runtime: id -> {cd: float, shots_left: int}.
var _fire_state: Dictionary = {}

## The player's muzzle marker + the player node (set by register_player).
var _muzzle: Node3D = null
var _player: Node3D = null

var _projectile_scene: PackedScene = null


func _ready() -> void:
	if ResourceLoader.exists("res://scenes/projectile/Projectile.tscn"):
		_projectile_scene = load("res://scenes/projectile/Projectile.tscn")


## The player registers its muzzle so guns know where to fire from.
func register_player(player: Node3D, muzzle: Node3D) -> void:
	_player = player
	_muzzle = muzzle


## Clears all guns (called from GameManager.start_game for a fresh run; a paid
## continue does NOT call this, so the loadout is kept).
func reset() -> void:
	owned.clear()
	_stacks.clear()
	_fire_state.clear()
	guns_changed.emit()


## Grants a gun, pushing another 20 s layer (re-picking the same gun stacks an
## extra overlapping layer, which levels it up: faster + more pellets). Returns
## the new level (= number of active layers).
func add_gun(id: String) -> int:
	if not GUNS.has(id):
		return 0
	# Weapon-slot cap: a brand-new gun beyond the cap is redirected into a level on
	# the lowest-level owned gun, so the pickup still rewards you — deeper, not wider.
	var redirected := false
	if not owned.has(id) and owned.size() >= MAX_GUNS:
		var low_id := _lowest_level_owned()
		if low_id != "":
			id = low_id
			redirected = true
	var arr: Array = _stacks.get(id, [])
	if arr.size() < MAX_LEVEL:
		arr.append(GUN_DURATION)
	else:
		# At the cap: refresh the soonest-to-expire layer instead of exceeding it.
		var mi := 0
		for i in range(1, arr.size()):
			if float(arr[i]) < float(arr[mi]):
				mi = i
		arr[mi] = GUN_DURATION
	_stacks[id] = arr
	owned[id] = arr.size()
	if not _fire_state.has(id):
		# Start ready to fire so a fresh pickup feels instant.
		_fire_state[id] = {"cd": 0.0, "shots_left": int(GUNS[id].get("burst_count", 0))}
	guns_changed.emit()
	if redirected:
		gun_redirected.emit(id, arr.size())
	return arr.size()


## The owned gun with the fewest active layers (ties → first found). "" if none.
## Used to redirect an over-cap pickup into deepening your weakest gun.
func _lowest_level_owned() -> String:
	var best := ""
	var best_lvl := 99999
	for oid in owned.keys():
		var lvl := int(owned[oid])
		if lvl < best_lvl:
			best_lvl = lvl
			best = oid
	return best


## Decrements every gun's layer timers, dropping expired layers (and the gun once
## empty). Emits [signal guns_changed] when anything changed.
func _tick_stacks(delta: float) -> void:
	if _stacks.is_empty():
		return
	var changed := false
	for id in _stacks.keys():
		var arr: Array = _stacks[id]
		var w := 0
		for i in range(arr.size()):
			var t := float(arr[i]) - delta
			if t > 0.0:
				arr[w] = t
				w += 1
		if w != arr.size():
			arr.resize(w)
			changed = true
		if arr.is_empty():
			_stacks.erase(id)
			owned.erase(id)
			_fire_state.erase(id)
		else:
			owned[id] = arr.size()
	if changed:
		guns_changed.emit()


## Removes one timed layer from a random gun (the DRAIN power-down). Returns true
## if something was actually removed.
func drain_one() -> bool:
	if _stacks.is_empty():
		return false
	var id: String = _stacks.keys().pick_random()
	var arr: Array = _stacks[id]
	arr.pop_back()
	if arr.is_empty():
		_stacks.erase(id)
		owned.erase(id)
		_fire_state.erase(id)
	else:
		owned[id] = arr.size()
	guns_changed.emit()
	return true


## Longest remaining time across a gun's layers (0 if not owned).
func time_left(id: String) -> float:
	var tl := 0.0
	for t in _stacks.get(id, []):
		tl = maxf(tl, float(t))
	return tl


## Rich per-gun status for the HUD: [{name, level, time_left}].
func status() -> Array:
	var out: Array = []
	for id in owned.keys():
		out.append({
			"name": GUNS[id]["name"],
			"level": int(owned[id]),
			"time_left": time_left(id),
		})
	return out


## A random gun id, for gate pickups.
func random_gun_id() -> String:
	return GUN_IDS[randi() % GUN_IDS.size()]


func gun_color(id: String) -> Color:
	return GUNS[id]["color"] if GUNS.has(id) else Color.WHITE


func gun_name(id: String) -> String:
	return GUNS[id]["name"] if GUNS.has(id) else id


func gun_desc(id: String) -> String:
	return GUN_DESC.get(id, "")


## Current level of an owned gun (0 if not owned).
func gun_level(id: String) -> int:
	return int(owned.get(id, 0))


## Builds a set of [param count] distinct gun choices for a level-up pick. Each is
## {id, level (current, 0=new), is_new}. Guns already maxed are skipped; at least
## one brand-new gun is offered when any remain undiscovered, for the thrill of it.
func roll_choices(count: int = 3) -> Array:
	var unowned: Array = []
	var upgradable: Array = []
	for id in GUN_IDS:
		var lvl := int(owned.get(id, 0))
		if lvl == 0:
			unowned.append(id)
		elif lvl < MAX_LEVEL:
			upgradable.append(id)
	# At the weapon-slot cap, stop offering new guns entirely — every pick should
	# now deepen an owned gun (the slot cap is the whole point).
	if owned.size() >= MAX_GUNS:
		unowned.clear()
	unowned.shuffle()
	upgradable.shuffle()

	var picks: Array = []
	# Lead choice: early on, expand the loadout with a new gun; once you own 3+ guns,
	# bias toward DEEPENING (~60% upgrade / 40% new) so power stacks visibly instead
	# of sprawling into ever-more weapons.
	var lead_upgrade := owned.size() >= 3 and not upgradable.is_empty() and randf() < 0.6
	if lead_upgrade:
		picks.append(upgradable.pop_back())
	elif not unowned.is_empty():
		picks.append(unowned.pop_back())
	elif not upgradable.is_empty():
		picks.append(upgradable.pop_back())
	# Fill the rest from a shuffled blend of what's left.
	var pool: Array = unowned + upgradable
	pool.shuffle()
	while picks.size() < count and not pool.is_empty():
		picks.append(pool.pop_back())

	var out: Array = []
	for id in picks:
		out.append({"id": id, "level": int(owned.get(id, 0)), "is_new": not owned.has(id)})
	return out


## Compact owned-gun list for the HUD, e.g. ["LASER", "RAPID·2"].
func summary() -> Array:
	var out: Array = []
	for id in owned.keys():
		var lvl: int = owned[id]
		out.append(GUNS[id]["name"] if lvl <= 1 else "%s·%d" % [GUNS[id]["name"], lvl])
	return out


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Star power freezes the whole loadout: guns stop firing AND their layer
	# timers are held, so you resume exactly where you left off when it wears off.
	if PowerUpManager.is_invincible():
		return

	# Timed layers keep ticking down regardless of whether we can fire.
	_tick_stacks(delta)

	# Stop auto-firing the instant the player dies. The run state is still PLAYING
	# during the death spectacle (ragdoll → continue offer), so without this the
	# guns keep blasting away under the "you died" screen.
	if _player and is_instance_valid(_player) and "current_state" in _player:
		if int(_player.current_state) >= int(PlayerController.State.RAGDOLL):
			return

	if owned.is_empty() or _muzzle == null or not is_instance_valid(_muzzle):
		return

	for id in owned.keys():
		var gun: Dictionary = GUNS[id]
		var st: Dictionary = _fire_state[id]
		st["cd"] -= delta
		if st["cd"] > 0.0:
			continue
		_fire(id, gun)
		# Schedule the next shot, honoring burst pauses and level speed-up.
		var level: int = owned[id]
		var speed_mult: float = pow(0.86, level - 1)  # higher level = faster
		var burst_count: int = int(gun.get("burst_count", 0))
		if burst_count > 0:
			st["shots_left"] = int(st["shots_left"]) - 1
			if st["shots_left"] <= 0:
				st["shots_left"] = burst_count
				st["cd"] = float(gun["burst_pause"]) * speed_mult
			else:
				st["cd"] = float(gun["cooldown"]) * speed_mult
		else:
			st["cd"] = float(gun["cooldown"]) * speed_mult
		# Per-gun fire-rate floor: caps any single gun at 20 shots/s so a maxed
		# RAPID/MINIGUN can't hose hard enough to threaten 60fps. The big burst-pause
		# is always well above the floor, so this only ever bites the rapid cadences.
		st["cd"] = maxf(float(st["cd"]), MIN_COOLDOWN)


## Fires one "tick" of a gun according to its pattern.
func _fire(id: String, gun: Dictionary) -> void:
	var level: int = owned[id]
	match int(gun["pattern"]):
		Pattern.LASER:
			# The laser is a true beam, not a pellet — instant, piercing. Its corridor
			# widens +0.5 m per level, so leveling LASER means catching more lanes.
			_fire_beam(gun, level)
		Pattern.RAIL:
			# Heavy piercing slug: its sweep corridor grows +0.5 m per level (base ~0.9 m)
			# so a deep RAILGUN punches a fat lane through a column of traffic.
			_spawn(gun, 0.0, {"hit_radius": 0.9 + 0.5 * float(level - 1)})
		Pattern.SINGLE, Pattern.NET:
			_spawn(gun, 0.0)
		Pattern.MINIGUN:
			# +1 parallel stream every 2 levels (2nd@L3, 3rd@L5) — depth = more lead
			# downrange, not just a faster single line. Jitter keeps the hose feel.
			var mjit: float = deg_to_rad(float(gun.get("spread_deg", 8.0)))
			_fire_streams(gun, 1 + (level - 1) / 2, mjit, deg_to_rad(5.0))
		Pattern.BURST:
			# RAPID: same parallel-stream reward as the minigun, tight and jitter-free.
			_fire_streams(gun, 1 + (level - 1) / 2, 0.0, deg_to_rad(3.5))
		Pattern.SHOTGUN, Pattern.SPREAD:
			# More pellets as the gun levels up, hard-capped so it can't balloon.
			var pellets: int = mini(int(gun.get("pellets", 3)) + (level - 1), PELLET_CAP)
			var spread: float = deg_to_rad(float(gun.get("spread_deg", 20.0)))
			var start: float = -spread * 0.5
			var stepa: float = spread / float(maxi(pellets - 1, 1))
			for i in pellets:
				_spawn(gun, start + stepa * float(i))
		Pattern.MORTAR:
			# +1 m blast radius per level, capped at +4 m, so a deep MORTAR craters
			# a whole cluster instead of just firing more often.
			var aoe: float = float(gun.get("aoe", 0.0)) + minf(float(level - 1), 4.0)
			_spawn(gun, 0.0, {"aoe": aoe})

	_play_shot(gun)


## Fires [param streams] parallel shots in a tight fan (RAPID/MINIGUN per-level
## reward). [param jitter] adds per-shot random spread on top (minigun hose feel).
func _fire_streams(gun: Dictionary, streams: int, jitter: float, fan_step: float) -> void:
	if streams <= 1:
		_spawn(gun, randf_range(-jitter, jitter) if jitter > 0.0 else 0.0)
		return
	var start := -fan_step * float(streams - 1) * 0.5
	for i in streams:
		var ja := randf_range(-jitter, jitter) if jitter > 0.0 else 0.0
		_spawn(gun, start + fan_step * float(i) + ja)


## Instantiates a projectile at the muzzle, yawed by [param angle_y] radians, and
## configures it from the gun definition.
func _spawn(gun: Dictionary, angle_y: float, overrides: Dictionary = {}) -> void:
	if _projectile_scene == null:
		return
	var proj: Node3D = _projectile_scene.instantiate()
	proj.global_transform = _muzzle.global_transform
	proj.rotate_y(angle_y)
	# Behavior params (Projectile reads these in _ready). `overrides` carries the
	# per-level boosts (MORTAR aoe, RAILGUN hit_radius) so the const GUNS dict stays
	# the base recipe.
	if "speed" in proj:
		proj.speed = float(gun.get("speed", 70.0))
	if "piercing" in proj:
		proj.piercing = bool(gun.get("piercing", false))
	if "aoe_radius" in proj:
		proj.aoe_radius = float(overrides.get("aoe", gun.get("aoe", 0.0)))
	if "lob_gravity" in proj:
		proj.lob_gravity = float(gun.get("lob_gravity", 0.0))
	if "lob_vy" in proj:
		proj.lob_vy = float(gun.get("lob_vy", 0.0))
	if "tint" in proj:
		proj.tint = gun.get("color", Color.WHITE)
	# A "width" gun (the NET) fires a wide, forgiving sweep that catches a whole
	# cluster of cars; everything else uses its uniform scale. The wide catch comes
	# from hit_radius (the swept test), NOT from a non-uniform body scale — Jolt
	# can't represent that on the collision shape, so only the visual mesh is
	# stretched and the Area3D body stays uniform.
	var width := float(gun.get("width", 0.0))
	if width > 0.0:
		if "hit_radius" in proj:
			proj.hit_radius = width * 0.5
		var mvis := proj.get_node_or_null("MeshInstance3D") as Node3D
		if mvis:
			mvis.scale = Vector3(width, maxf(width * 0.5, 1.0), 1.2)
	else:
		proj.scale = Vector3.ONE * float(gun.get("scale", 1.0))

	# Per-level sweep-corridor boost (RAILGUN). Applied after the width/scale block
	# so it overrides the default 0.9 m corridor without touching the visual scale.
	if overrides.has("hit_radius") and "hit_radius" in proj:
		proj.hit_radius = float(overrides["hit_radius"])

	var parent := get_tree().current_scene
	if parent:
		parent.add_child(proj)


## Fires the laser as an instant beam: crumples every car in a thin corridor down
## the muzzle's forward axis and flashes a fading beam mesh. Cheap and iOS-safe
## (no per-frame projectile, no shader).
func _fire_beam(gun: Dictionary, level: int = 1) -> void:
	if _muzzle == null or not is_instance_valid(_muzzle):
		return
	var origin: Vector3 = _muzzle.global_position
	var dir: Vector3 = -_muzzle.global_transform.basis.z.normalized()
	var length := 110.0
	# Corridor widens +0.5 m per level so a deep LASER scythes more lanes at once.
	var radius := 1.5 + 0.5 * float(level - 1)
	for car in get_tree().get_nodes_in_group("cars"):
		var c := car as Node3D
		if c == null or not c.has_method("crumple"):
			continue
		var to: Vector3 = c.global_position - origin
		var along := to.dot(dir)
		if along < 0.0 or along > length:
			continue
		if (to - dir * along).length() <= radius:
			c.crumple(c.global_position, dir * 80.0)
	_spawn_beam_visual(origin, dir, length, gun.get("color", Color(1.0, 0.2, 0.85)))


## Spawns a short-lived emissive beam mesh from [param origin] along [param dir].
func _spawn_beam_visual(origin: Vector3, dir: Vector3, length: float, color: Color) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.3, length)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = origin + dir * (length * 0.5)
	mi.look_at(mi.global_position + dir, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale:x", 0.15, 0.12)
	tw.parallel().tween_property(mi, "scale:y", 0.15, 0.12)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)
	tw.tween_callback(mi.queue_free)


func _play_shot(gun: Dictionary) -> void:
	# Throttle audio for the rapid guns so they don't drown everything out.
	var pattern := int(gun["pattern"])
	if pattern == Pattern.MINIGUN or pattern == Pattern.BURST:
		if randf() > 0.4:
			return
	# Each gun has its own voice so a stacked loadout sounds like distinct weapons.
	AudioManager.play_gun_shot(pattern)
