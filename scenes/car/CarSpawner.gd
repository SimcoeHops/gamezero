## CarSpawner — Timed car spawning with speed scaling
##
## Spawns Car.tscn instances at random lateral positions along the far
## end of the highway. Spawn rate and car speed increase over time
## to create escalating difficulty.

extends Node3D

## Base approach speed of cars (m/s) at t=0.
@export var base_speed: float = 15.0

## How much speed increases per second of gameplay.
@export var speed_acceleration: float = 0.3

## Maximum car speed cap.
@export var max_speed: float = 60.0

## Base interval between spawns (seconds) at t=0.
@export var base_spawn_interval: float = 1.5

## How much the spawn interval decreases per second of gameplay.
@export var interval_decay: float = 0.008

## Minimum spawn interval cap (seconds).
@export var min_spawn_interval: float = 0.35

## Z position where cars spawn (far end of highway).
@export var spawn_z: float = -70.0

## Half-width of the spawnable area (should match highway).
@export var spawn_half_width: float = 5.5

## Number of lanes cars are spawned across. A wave always leaves at least one
## lane open so the player can always dodge.
@export var lane_count: int = 5

## Every this many seconds of survival, the max cars-per-wave increases by one
## (capped at lane_count - 1). Lower = ramps up faster.
@export var difficulty_ramp_seconds: float = 12.0

## Candidate car models. Their differing shapes give natural size variety;
## the spawner also tints and scales each one.
const CAR_MODEL_PATHS: Array[String] = [
	"res://assets/kenney_car-kit/Models/GLB format/sedan.glb",
	"res://assets/kenney_car-kit/Models/GLB format/sedan-sports.glb",
	"res://assets/kenney_car-kit/Models/GLB format/hatchback-sports.glb",
	"res://assets/kenney_car-kit/Models/GLB format/suv.glb",
	"res://assets/kenney_car-kit/Models/GLB format/suv-luxury.glb",
	"res://assets/kenney_car-kit/Models/GLB format/taxi.glb",
	"res://assets/kenney_car-kit/Models/GLB format/police.glb",
	"res://assets/kenney_car-kit/Models/GLB format/van.glb",
	"res://assets/kenney_car-kit/Models/GLB format/delivery.glb",
	"res://assets/kenney_car-kit/Models/GLB format/truck.glb",
	"res://assets/kenney_car-kit/Models/GLB format/ambulance.glb",
]

## Vivid body colors the cars are tinted with.
const CAR_COLORS: Array[Color] = [
	Color(0.95, 0.18, 0.18),  # red
	Color(0.20, 0.45, 0.98),  # blue
	Color(0.98, 0.82, 0.15),  # yellow
	Color(0.20, 0.80, 0.32),  # green
	Color(0.96, 0.96, 0.98),  # white
	Color(0.80, 0.82, 0.86),  # silver (lightened)
	Color(0.98, 0.50, 0.12),  # orange
	Color(0.70, 0.25, 0.92),  # purple
	Color(0.20, 0.85, 0.85),  # cyan
	Color(0.98, 0.35, 0.65),  # pink
]

## Size tiers as (uniform scale, speed multiplier). All readable (>= 1.0).
## Bigger cars roll slower; the rare big rig is a real wall.
const SIZE_TIERS: Array[Vector2] = [
	Vector2(1.00, 1.00),
	Vector2(1.05, 0.97),
	Vector2(1.15, 0.92),
	Vector2(1.30, 0.86),
	Vector2(1.50, 0.80),
]

## Loaded model scenes (populated in _ready from CAR_MODEL_PATHS that exist).
var _car_model_scenes: Array[PackedScene] = []

## Lateral center positions of each lane, computed in _ready.
var _lane_x: Array[float] = []

## Reference to the player node (assigned by Main.gd).
var player_ref: Node3D = null

## Reference to the Highway node (for speed sync).
var highway_ref: Node3D = null

## Preloaded car scene.
var _car_scene: PackedScene = null

## Internal spawn timer.
@onready var _spawn_timer: Timer = $SpawnTimer

## Current computed speed.
var _current_speed: float = 15.0


func _ready() -> void:
	_car_scene = preload("res://scenes/car/Car.tscn")

	# Preload whichever car models are present on disk.
	for path in CAR_MODEL_PATHS:
		if ResourceLoader.exists(path):
			_car_model_scenes.append(load(path))

	# Compute evenly spread lane centers across the spawnable width.
	for i in lane_count:
		var t := float(i) / float(maxi(lane_count - 1, 1))
		_lane_x.append(lerpf(-spawn_half_width, spawn_half_width, t))

	if not _spawn_timer:
		_spawn_timer = Timer.new()
		_spawn_timer.name = "SpawnTimer"
		add_child(_spawn_timer)

	_spawn_timer.wait_time = base_spawn_interval
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	# Don't start spawning until game starts
	GameManager.state_changed.connect(_on_game_state_changed)


func _process(_delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var elapsed := GameManager.time_elapsed

	# Scale speed over time, then apply cumulative speed power-ups (can exceed
	# the normal cap — that's the "crazier" part).
	_current_speed = minf(base_speed + elapsed * speed_acceleration, max_speed) * PowerUpManager.speed_multiplier()
	GameManager.highway_speed = _current_speed

	# Scale spawn interval over time
	var interval := maxf(base_spawn_interval - elapsed * interval_decay, min_spawn_interval)
	_spawn_timer.wait_time = interval

	# Update highway scroll speed
	if highway_ref and highway_ref.has_method("set_speed"):
		highway_ref.set_speed(_current_speed)


## Spawns a single car at lane center [param x_pos] with a random visual variant.
func _spawn_car(x_pos: float) -> void:
	if _car_scene == null:
		push_error("[CarSpawner] Car scene not loaded")
		return

	var car := _car_scene.instantiate()

	# Pick a visual variant: model, color, and size tier (paired speed mod).
	var tier: Vector2 = SIZE_TIERS.pick_random()
	var model: PackedScene = _car_model_scenes.pick_random() if not _car_model_scenes.is_empty() else null
	var tint: Color = CAR_COLORS.pick_random()
	if car.has_method("apply_variant"):
		car.apply_variant(model, tint, tier.x)

	car.position = Vector3(x_pos, 0.0, spawn_z)
	car.approach_speed = _current_speed * tier.y
	car.player_ref = player_ref
	car.highway_ref = highway_ref

	add_child(car)


## Spawns a wave of cars. The wave size grows with survival time but always
## leaves at least one lane open, and lanes are distinct so cars never overlap.
func _on_spawn_timer_timeout() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var max_open := maxi(_lane_x.size() - 1, 1)
	var elapsed := GameManager.time_elapsed
	var max_cars := clampi(1 + int(elapsed / difficulty_ramp_seconds), 1, max_open)

	# Ease off the traffic once the game is genuinely fast — speed alone is the
	# challenge by then, and packed lanes start to feel unfair.
	if _current_speed > 40.0:
		max_cars = mini(max_cars, max_open - 1)
	if _current_speed > 55.0:
		max_cars = mini(max_cars, max_open - 2)
	max_cars = maxi(max_cars, 1)

	var count := randi_range(1, max_cars)

	var lanes := _lane_x.duplicate()
	lanes.shuffle()
	for i in count:
		_spawn_car(lanes[i])


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PLAYING:
		_spawn_timer.start()
	else:
		_spawn_timer.stop()


## Stops spawning and removes all existing cars.
func clear_all_cars() -> void:
	_spawn_timer.stop()
	for child in get_children():
		if child != _spawn_timer:
			child.queue_free()
