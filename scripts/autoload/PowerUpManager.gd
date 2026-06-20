## PowerUpManager — Autoload Singleton
##
## Tracks run-scoped power-up state collected from orbs: cumulative speed,
## the weapon fire mode + bullet count, and timed invincibility (the "star").
##
## Milestone abilities (jump / bullet-time / weapon) stay owned by
## [ProgressionManager]; these orb effects stack on top of them.

extends Node

## Emitted whenever any power-up state changes (for HUD binding).
signal powerups_changed()

## Emitted when invincibility starts / ends.
signal star_started(duration: float)
signal star_ended()

## Emitted when a jump orb grants FLY mode (the player handles the superman fly).
signal fly_requested(duration: float)

## Emitted the moment a gate is actually collected, carrying the power-up's name
## and colour so the HUD can flash a quick "what you just grabbed" banner — handy
## when the action is too fast to read the word on the gate itself.
signal pickup_announced(label: String, color: Color)


## Thin helper so the gate (which knows the label + colour for every pickup kind,
## gun or orb) can broadcast a collection to the HUD.
func announce_pickup(label: String, color: Color) -> void:
	if label != "":
		pickup_announced.emit(label, color)

## Orb kinds. DRAIN is the power-down. POW detonates every car on screen the
## instant it's collected (no fire-button needed). JUMP_UP grants double-jump,
## then FLY on subsequent pickups. MAGNET pulls nearby coins in.
enum Type { SPEED, MULTISHOT, LASER, NET, STAR, DRAIN, POW, JUMP_UP, MAGNET }

## Active weapon behavior when firing.
enum FireMode { BULLETS, LASER, NET }

## The star is a short, intense burst: it pauses your guns + their timers and
## blocks new pickups (except DRAIN), so it's deliberately brief.
const STAR_DURATION := 8.0
const FLY_DURATION := 15.0
const MAGNET_DURATION := 20.0
const MAGNET_RADIUS := 7.0
const SPEED_STEP := 0.12       ## +12% game speed per speed orb
const MAX_SPEED_STACKS := 12
const MAX_BULLETS := 7
## Every collected power-up lasts 20s, then that layer drops off (so the run
## can't snowball into permanent chaos). Same-type pickups stack as overlapping
## 20s timers.
const POWERUP_DURATION := 20.0
const WARN_TIME := 5.0

## Timed layers for collected speed orbs: remaining seconds, one entry per orb.
var _speed_layers: Array[float] = []
## Cumulative speed orbs currently active (= _speed_layers.size(); kept in sync).
var speed_stacks: int = 0
## Number of pellets fired in BULLETS mode.
var bullet_count: int = 1
## Current weapon behavior.
var fire_mode: FireMode = FireMode.BULLETS
## Extra mid-air jumps granted (0 = single jump, 1 = double jump).
var air_jumps: int = 0
## Always-on coin magnet from a purchased meta upgrade (set by GameManager at
## start_game). Keeps [method is_magnet_active] true for the whole run.
var permanent_magnet: bool = false

var _star_timer: float = 0.0
var _magnet_timer: float = 0.0


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Star power pauses EVERYTHING else: only the star itself counts down, while
	# guns + speed/magnet timers are frozen (held until the star wears off).
	if _star_timer > 0.0:
		_star_timer -= delta
		if _star_timer <= 0.0:
			_star_timer = 0.0
			star_ended.emit()
			powerups_changed.emit()
		return

	# Expire speed layers individually so stacked orbs drop off one at a time.
	if not _speed_layers.is_empty():
		var w := 0
		for i in range(_speed_layers.size()):
			var t := _speed_layers[i] - delta
			if t > 0.0:
				_speed_layers[w] = t
				w += 1
		if w != _speed_layers.size():
			_speed_layers.resize(w)
			speed_stacks = _speed_layers.size()
			powerups_changed.emit()

	if _magnet_timer > 0.0:
		_magnet_timer -= delta
		if _magnet_timer <= 0.0:
			_magnet_timer = 0.0
			powerups_changed.emit()


## Clears all power-up state for a new run.
func reset() -> void:
	_speed_layers.clear()
	speed_stacks = 0
	bullet_count = 1
	fire_mode = FireMode.BULLETS
	air_jumps = 0
	permanent_magnet = false
	_star_timer = 0.0
	_magnet_timer = 0.0
	powerups_changed.emit()


## Multiplier applied to the highway/car speed from collected speed orbs.
func speed_multiplier() -> float:
	return 1.0 + float(speed_stacks) * SPEED_STEP


func is_invincible() -> bool:
	return _star_timer > 0.0


func star_time_left() -> float:
	return _star_timer


## Longest remaining time across active speed layers (0 if none).
func speed_time_left() -> float:
	var tl := 0.0
	for t in _speed_layers:
		tl = maxf(tl, t)
	return tl


func is_magnet_active() -> bool:
	return _magnet_timer > 0.0 or permanent_magnet


func magnet_time_left() -> float:
	return _magnet_timer


## Applies an orb of [param type] to the run state.
func apply(type: Type) -> void:
	match type:
		Type.SPEED:
			# Push another 30s speed layer (stacks; oldest drops off first).
			if _speed_layers.size() < MAX_SPEED_STACKS:
				_speed_layers.append(POWERUP_DURATION)
			else:
				var mi := 0
				for i in range(1, _speed_layers.size()):
					if _speed_layers[i] < _speed_layers[mi]:
						mi = i
				_speed_layers[mi] = POWERUP_DURATION
			speed_stacks = _speed_layers.size()
		Type.MULTISHOT:
			# Weapon orbs now feed the auto-fire gun system (with its own 30s
			# stacking), so they actually fire on their own instead of relying on
			# a manual fire button that mobile doesn't have.
			GunManager.add_gun("SPREAD")
		Type.LASER:
			GunManager.add_gun("LASER")
		Type.NET:
			GunManager.add_gun("NET")
		Type.STAR:
			_star_timer = STAR_DURATION
			star_started.emit(STAR_DURATION)
		Type.DRAIN:
			_drain_one()
		Type.POW:
			_detonate_all()
		Type.JUMP_UP:
			# First jump orb grants double-jump; further ones grant FLY mode.
			if air_jumps < 1:
				air_jumps = 1
			else:
				fly_requested.emit(FLY_DURATION)
		Type.MAGNET:
			_magnet_timer = MAGNET_DURATION
	powerups_changed.emit()
	print("[PowerUp] Applied: ", Type.keys()[type])


## Instantly crumples every car on screen — fires from apply(), so it triggers
## the moment the orb is picked up (no key press).
func _detonate_all() -> void:
	for car in get_tree().get_nodes_in_group("cars"):
		var c := car as Node3D
		if c and c.has_method("crumple"):
			c.call("crumple", c.global_position + Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.0, 12.0))
	Juice.add_trauma(0.6)
	Juice.flash(Color(1.0, 0.6, 0.2), 0.4, 0.45)


## Strips one random active power (the power-down effect).
func _drain_one() -> void:
	var options: Array[String] = []
	if not _speed_layers.is_empty():
		options.append("speed")
	if not GunManager.owned.is_empty():
		options.append("gun")
	if _star_timer > 0.0:
		options.append("star")
	if options.is_empty():
		return
	match options.pick_random():
		"speed":
			_speed_layers.pop_back()
			speed_stacks = _speed_layers.size()
		"gun":
			GunManager.drain_one()
		"star":
			_star_timer = 0.0
			star_ended.emit()
