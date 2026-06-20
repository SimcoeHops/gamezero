## GantrySpawner — places overhead gantries down the highway.
##
## Distance-based (not timed) so the spacing stays consistent whether you're
## crawling at the start or screaming at top speed: a gantry roughly every
## SPAWN_DISTANCE metres travelled, with a little jitter. Reads the current biome
## from the highway so each gantry is tinted to its world (and the Neon biome
## gets extra-hot signs). Cosmetic only.
extends Node3D

## Metres of travel between gantries (jittered each time).
@export var spawn_distance: float = 105.0
@export var spawn_distance_jitter: float = 35.0
## Z where a gantry first appears (matches the car far-spawn plane).
@export var spawn_z: float = -72.0

## Per-biome accent color for the gantry signs/lights, keyed by theme name.
const ACCENTS := {
	"DOWNTOWN": Color(1.0, 0.82, 0.40),     # warm amber city signage
	"COUNTRYSIDE": Color(0.45, 0.95, 0.55),  # highway green
	"INDUSTRIAL": Color(1.0, 0.62, 0.16),    # hazard orange
	"NEON CITY": Color(1.0, 0.18, 0.85),     # hot magenta neon
}
const DEFAULT_ACCENT := Color(0.6, 0.85, 1.0)

var player_ref: Node3D = null
var highway_ref: Node3D = null

var _gantry_script: GDScript = preload("res://scenes/highway/Gantry.gd")
var _distance_acc: float = 0.0
var _next_at: float = 0.0


func _ready() -> void:
	_arm_next()
	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: int) -> void:
	# Fresh run: clear any leftover gantries and reset the spacing accumulator.
	if new_state == GameManager.GameState.PLAYING:
		clear_all()
		_distance_acc = 0.0
		_arm_next()


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var speed: float = GameManager.highway_speed
	_distance_acc += speed * delta

	# Keep every live gantry moving at the current highway speed.
	for child in get_children():
		if child.has_method("_do_sweep"):  # it's a Gantry
			child.speed = speed

	if _distance_acc >= _next_at:
		_distance_acc = 0.0
		_arm_next()
		_spawn()


func _arm_next() -> void:
	# A hot flow-state packs the overhead gantries closer together so a long clean
	# streak feels busier and faster, then eases back out as the heat cools.
	var base := spawn_distance + randf_range(-spawn_distance_jitter, spawn_distance_jitter)
	_next_at = maxf(base * (1.0 - 0.3 * GameManager.flow_heat), 35.0)


func _spawn() -> void:
	var g := Node3D.new()
	g.set_script(_gantry_script)

	var theme_name := ""
	if highway_ref and highway_ref.has_method("get_current_theme"):
		theme_name = String(highway_ref.get_current_theme().get("name", ""))
	g.accent = ACCENTS.get(theme_name, DEFAULT_ACCENT)
	# Most carry a lit sign; the occasional bare truss adds variety.
	g.has_sign = randf() < 0.72
	g.highway_ref = highway_ref
	g.player_ref = player_ref
	g.speed = GameManager.highway_speed

	g.position = Vector3(0.0, 0.0, spawn_z)
	add_child(g)


func clear_all() -> void:
	for child in get_children():
		if child.has_method("_do_sweep"):
			child.queue_free()
