extends Node3D

## Emitted when the world advances to a new building/mood theme.
signal theme_changed(theme: Dictionary)

@export var scroll_speed: float = 15.0
@export var segment_length: float = 20.0
@export var num_segments: int = 15

## --- Cosmetic curve (Outrun-style) ---
## World Z plane (near the camera) where the curve offset is ~0, so the player
## and the point of collision stay put while the road bends into the distance.
const CURVE_Z_REF := 8.0
## Peak curvature magnitude. Offset grows quadratically with depth, so this is
## small; tune up for sharper bends. (~5–6 units of lateral shift at the horizon.)
@export var max_curvature: float = 0.0009
## Seconds between picking a new curve target (the road re-aims gradually).
@export var curve_retarget_interval: float = 5.0
## How quickly curvature eases toward its target (per second).
@export var curve_ease: float = 0.5

## Current curvature, read by cars (and the camera) to follow the bend.
var current_curvature: float = 0.0
var _target_curvature: float = 0.0
var _curve_timer: float = 0.0

## --- Cosmetic hills (Outrun-style) ---
## Like the curve, this is a perspective "lens": the road is dead flat near the
## camera (so dodging/collisions are untouched) and gently rolls up and down into
## the distance. The wave scrolls toward the camera at road speed.
@export var hill_amplitude: float = 1.6
@export var hill_wavelength: float = 95.0
## Total road distance travelled. Hills are keyed to this so they're stable world
## features that roll toward the camera, not an in-place wave.
var _road_travel: float = 0.0

## --- Themes ---
## Average distance (world units) between theme switches. Each zone's actual
## length is randomized around this (see [member theme_distance_min/max]) so the
## end-of-run journey map reads as a natural mix of short and long regions
## instead of identical evenly-spaced bands.
@export var theme_distance: float = 600.0
@export var theme_distance_min: float = 320.0
@export var theme_distance_max: float = 1100.0
var _distance: float = 0.0
## The randomized length of the zone currently being travelled.
var _zone_length: float = 600.0
var _theme_index: int = 0

const COMM := "res://assets/kenney_city-kit-commercial_2.1/Models/GLB format/"
const IND := "res://assets/kenney_city-kit-industrial_1.0/Models/GLB format/"
const URB := "res://assets/kenney_retro-urban-kit/Models/GLB format/"

# Biomes are visited in order, looping — a sense of travelling across regions.
const THEMES: Array[Dictionary] = [
	{
		"name": "DOWNTOWN",
		"buildings": [
			COMM + "building-a.glb", COMM + "building-c.glb", COMM + "building-e.glb",
			COMM + "building-g.glb", COMM + "building-i.glb", COMM + "building-k.glb",
			COMM + "building-m.glb", COMM + "building-n.glb",
			COMM + "building-skyscraper-a.glb", COMM + "building-skyscraper-c.glb",
			COMM + "building-skyscraper-e.glb",
		],
		"scale_min": 4.5, "scale_max": 7.0, "density": 1.0,
		"fog": Color(0.10, 0.08, 0.15),
		"ambient": Color(0.20, 0.10, 0.30),
		"light": Color(0.55, 0.70, 1.00),
	},
	{
		"name": "COUNTRYSIDE",
		"buildings": [
			URB + "tree-large.glb", URB + "tree-pine-large.glb", URB + "tree-park-large.glb",
			URB + "tree-park-pine-large.glb", URB + "tree-pine-small.glb", URB + "tree-small.glb",
			URB + "tree-shrub.glb",
			COMM + "low-detail-building-a.glb", COMM + "low-detail-building-d.glb",
		],
		"scale_min": 2.5, "scale_max": 4.5, "density": 0.6,
		"fog": Color(0.09, 0.18, 0.10),
		"ambient": Color(0.18, 0.32, 0.18),
		"light": Color(0.78, 1.00, 0.70),
	},
	{
		"name": "INDUSTRIAL",
		"buildings": [
			IND + "building-a.glb", IND + "building-c.glb", IND + "building-e.glb",
			IND + "building-h.glb", IND + "building-k.glb", IND + "building-n.glb",
			IND + "building-q.glb", IND + "building-t.glb",
			IND + "chimney-large.glb", IND + "chimney-medium.glb", IND + "detail-tank.glb",
		],
		"scale_min": 3.0, "scale_max": 5.0, "density": 0.95,
		"fog": Color(0.18, 0.12, 0.06),
		"ambient": Color(0.35, 0.22, 0.10),
		"light": Color(1.00, 0.72, 0.42),
	},
	{
		"name": "NEON CITY",
		"buildings": [
			COMM + "building-b.glb", COMM + "building-d.glb", COMM + "building-f.glb",
			COMM + "building-h.glb", COMM + "building-j.glb", COMM + "building-l.glb",
			COMM + "building-skyscraper-b.glb", COMM + "building-skyscraper-d.glb",
			COMM + "building-skyscraper-e.glb",
		],
		"scale_min": 4.5, "scale_max": 7.5, "density": 1.0,
		"fog": Color(0.16, 0.04, 0.20),
		"ambient": Color(0.30, 0.08, 0.40),
		"light": Color(1.00, 0.45, 0.95),
	},
]

var segment_scene: PackedScene = preload("res://scenes/highway/HighwaySegment.tscn")
var segments: Array[Node3D] = []

## Cache of loaded prop scenes, keyed by path.
var _scene_cache: Dictionary = {}


func _ready() -> void:
	_curve_timer = curve_retarget_interval
	_zone_length = randf_range(theme_distance_min, theme_distance_max)

	for i in range(num_segments):
		var segment := segment_scene.instantiate()
		$Segments.add_child(segment)
		segment.position.z = -i * segment_length
		segments.append(segment)
		_randomize_segment(segment)


func _process(delta: float) -> void:
	_update_curve(delta)
	_update_hills(delta)
	_update_theme(delta)

	for segment in segments:
		segment.position.z += scroll_speed * delta
		if segment.position.z > 25.0:
			# Place this segment behind the current furthest one.
			var furthest_z := 25.0
			for s in segments:
				if s.position.z < furthest_z:
					furthest_z = s.position.z
			segment.position.z = furthest_z - segment_length
			_randomize_segment(segment)
		# Bend the segment (and its scenery) to follow the curve: shift it
		# laterally AND yaw it to the curve's tangent, so the road and its lane
		# lines read as a continuous bend instead of offset straight chunks.
		segment.position.x = get_curve_offset(segment.position.z)
		segment.rotation.y = get_curve_yaw(segment.position.z)
		# Hills: sit the tile between the height field at its two edges and PITCH it
		# to span them. Because neighbours share an edge z, they evaluate the same
		# height there and meet exactly — a connected ramp, not stepped flat plates.
		var near_h := get_height_offset(segment.position.z + segment_length * 0.5)
		var far_h := get_height_offset(segment.position.z - segment_length * 0.5)
		segment.position.y = (near_h + far_h) * 0.5
		segment.rotation.x = atan2(far_h - near_h, segment_length)


## Lateral offset of the road at world Z [param z]. Zero near the camera and
## growing quadratically into the distance, so the bend reads in perspective
## without moving the player's dodge space.
func get_curve_offset(z: float) -> float:
	var depth := maxf(CURVE_Z_REF - z, 0.0)
	return current_curvature * depth * depth


## Heading (Y rotation) of the road at world Z [param z] — the tangent of the
## offset parabola. Used to yaw segments so the curve looks continuous.
func get_curve_yaw(z: float) -> float:
	var depth := maxf(CURVE_Z_REF - z, 0.0)
	return atan(-2.0 * current_curvature * depth)


## Vertical offset of the road at world Z [param z]. Flat near the camera, then
## rolling gently into the distance — cosmetic only (the dodge plane stays at 0).
func get_height_offset(z: float) -> float:
	var depth := maxf(CURVE_Z_REF - z, 0.0)
	# Stay flat through the near gameplay zone, ramp in only in the distance.
	var falloff := smoothstep(10.0, 38.0, depth)
	var freq := TAU / maxf(hill_wavelength, 1.0)
	# Key the wave to (z - distance travelled). Because a segment's z and the
	# travel both advance at scroll speed, (z - travel) stays constant for a given
	# segment as it scrolls in — so it holds its height and only eases flat near
	# the camera, instead of every tile pumping up and down in place.
	return sin((z - _road_travel) * freq) * hill_amplitude * falloff


func _update_hills(delta: float) -> void:
	_road_travel += scroll_speed * delta


func _update_curve(delta: float) -> void:
	_curve_timer -= delta
	if _curve_timer <= 0.0:
		_target_curvature = randf_range(-max_curvature, max_curvature)
		_curve_timer = curve_retarget_interval * randf_range(0.7, 1.3)
	current_curvature = lerpf(current_curvature, _target_curvature, clampf(delta * curve_ease, 0.0, 1.0))


func _update_theme(delta: float) -> void:
	_distance += scroll_speed * delta
	if _distance >= _zone_length:
		_distance = 0.0
		# Vary the next zone's length so regions are a natural mix of short/long.
		_zone_length = randf_range(theme_distance_min, theme_distance_max)
		_theme_index = (_theme_index + 1) % THEMES.size()
		theme_changed.emit(THEMES[_theme_index])


func get_current_theme() -> Dictionary:
	return THEMES[_theme_index]


func _randomize_segment(segment: Node3D) -> void:
	if not segment.has_method("clear_props"):
		return
	segment.clear_props()
	if segment.has_method("populate_dense_city"):
		var th: Dictionary = THEMES[_theme_index]
		segment.populate_dense_city(_current_theme_buildings(), th.get("scale_min", 4.0), th.get("scale_max", 6.0), th.get("density", 1.0))


func _current_theme_buildings() -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for path in THEMES[_theme_index]["buildings"]:
		var sc := _get_scene(path)
		if sc:
			out.append(sc)
	return out


func _get_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]
	var sc: PackedScene = null
	if ResourceLoader.exists(path):
		sc = load(path)
	_scene_cache[path] = sc
	return sc


func set_speed(new_speed: float) -> void:
	scroll_speed = new_speed
