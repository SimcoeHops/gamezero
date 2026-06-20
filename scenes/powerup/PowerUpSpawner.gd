## PowerUpSpawner — drops collectible orbs on the road at random lanes.
##
## Wired by Main.gd (player_ref / highway_ref). Spawns at randomized intervals
## while the game is PLAYING. Most orbs are beneficial; a fraction are drains.

extends Node3D

@export var spawn_interval_min: float = 3.2
@export var spawn_interval_max: float = 5.5
@export var spawn_z: float = -70.0
## Fraction of orbs that are power-downs.
@export var drain_chance: float = 0.18

## Fraction of (non-drain) gates that grant a gun rather than an orb effect.
@export var gun_chance: float = 0.4

var player_ref: Node3D = null
var highway_ref: Node3D = null

## Lane centers (matched to CarSpawner's 5 lanes across ±5.5).
var _lanes: Array[float] = [-5.5, -2.75, 0.0, 2.75, 5.5]

## Weighted pool of beneficial orb types (more entries = more common).
var _good_pool: Array[int] = []

var _orb_scene: PackedScene = preload("res://scenes/powerup/PowerUp.tscn")
var _timer: Timer = null

const COLORS := {
	PowerUpManager.Type.SPEED: Color(0.2, 0.8, 1.0),
	PowerUpManager.Type.MULTISHOT: Color(1.0, 0.6, 0.1),
	PowerUpManager.Type.LASER: Color(1.0, 0.2, 0.85),
	PowerUpManager.Type.NET: Color(0.3, 1.0, 0.4),
	PowerUpManager.Type.STAR: Color(1.0, 0.9, 0.2),
	PowerUpManager.Type.DRAIN: Color(1.0, 0.12, 0.12),
	PowerUpManager.Type.POW: Color(1.0, 0.35, 0.08),
	PowerUpManager.Type.JUMP_UP: Color(0.55, 1.0, 0.95),
	PowerUpManager.Type.MAGNET: Color(0.85, 0.3, 1.0),
}

## Short word shown floating in each gate so its effect is obvious at a glance.
const LABELS := {
	PowerUpManager.Type.SPEED: "SPEED",
	PowerUpManager.Type.MULTISHOT: "MULTI",
	PowerUpManager.Type.LASER: "LASER",
	PowerUpManager.Type.NET: "NET",
	PowerUpManager.Type.STAR: "STAR",
	PowerUpManager.Type.DRAIN: "DRAIN",
	PowerUpManager.Type.POW: "POW",
	PowerUpManager.Type.JUMP_UP: "JUMP",
	PowerUpManager.Type.MAGNET: "MAGNET",
}


func _ready() -> void:
	# Speed is common; star is rare.
	_good_pool = [
		PowerUpManager.Type.SPEED, PowerUpManager.Type.SPEED, PowerUpManager.Type.SPEED,
		PowerUpManager.Type.MULTISHOT, PowerUpManager.Type.MULTISHOT,
		PowerUpManager.Type.LASER,
		PowerUpManager.Type.NET,
		PowerUpManager.Type.STAR,
		PowerUpManager.Type.POW,
		PowerUpManager.Type.JUMP_UP, PowerUpManager.Type.JUMP_UP,
		PowerUpManager.Type.MAGNET, PowerUpManager.Type.MAGNET,
	]

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

	GameManager.state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.PLAYING:
		_reschedule()
	else:
		_timer.stop()


func _reschedule() -> void:
	_timer.wait_time = randf_range(spawn_interval_min, spawn_interval_max)
	_timer.start()


func _on_timeout() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		_spawn()
		_reschedule()


func _spawn() -> void:
	var orb := _orb_scene.instantiate()

	if randf() < drain_chance:
		# Power-down gate.
		orb.type = PowerUpManager.Type.DRAIN
		orb.color = COLORS.get(PowerUpManager.Type.DRAIN, Color.WHITE)
		orb.label_text = LABELS.get(PowerUpManager.Type.DRAIN, "")
	elif randf() < gun_chance:
		# Gun gate — grants a random stacking auto-fire gun.
		var gid := GunManager.random_gun_id()
		orb.gun_id = gid
		orb.color = GunManager.gun_color(gid)
		orb.label_text = GunManager.gun_name(gid)
	else:
		# Beneficial orb effect.
		var type: int = _good_pool.pick_random()
		orb.type = type
		orb.color = COLORS.get(type, Color.WHITE)
		orb.label_text = LABELS.get(type, "")

	orb.position = Vector3(_lanes.pick_random(), 0.0, spawn_z)
	orb.approach_speed = GameManager.highway_speed
	orb.player_ref = player_ref
	orb.highway_ref = highway_ref
	add_child(orb)
