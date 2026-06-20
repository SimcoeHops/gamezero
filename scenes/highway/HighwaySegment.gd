extends Node3D

@onready var left_slot: Node3D = $LeftSlot
@onready var right_slot: Node3D = $RightSlot

## Road dimensions (must match the PlaneMesh in HighwaySegment.tscn).
const SEGMENT_LEN := 20.0
const ROAD_HALF_WIDTH := 7.0
## X positions of the dashed lane-divider lines.
const LANE_DIVIDERS := [-4.125, -1.375, 1.375, 4.125]


func _ready() -> void:
	_build_road_markings()


## Builds glowing lane lines and curbs once. These live on the segment root
## (not the prop slots), so they survive clear_props() and scroll/curve with it.
func _build_road_markings() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.95, 0.93, 0.78)
	paint.roughness = 0.5
	paint.emission_enabled = true
	paint.emission = Color(0.95, 0.92, 0.72)
	paint.emission_energy_multiplier = 0.6

	# Solid edge lines.
	_add_box(Vector3(0.22, 0.04, SEGMENT_LEN), Vector3(-6.4, 0.03, 0.0), paint)
	_add_box(Vector3(0.22, 0.04, SEGMENT_LEN), Vector3(6.4, 0.03, 0.0), paint)

	# Dashed lane dividers.
	for x in LANE_DIVIDERS:
		_add_dashes(x, paint)

	# Raised curbs/shoulders between the road edge and the buildings.
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.24, 0.24, 0.27)
	curb.roughness = 0.95
	_add_box(Vector3(1.0, 0.18, SEGMENT_LEN), Vector3(-7.6, 0.09, 0.0), curb)
	_add_box(Vector3(1.0, 0.18, SEGMENT_LEN), Vector3(7.6, 0.09, 0.0), curb)


func _add_dashes(x: float, mat: StandardMaterial3D) -> void:
	var dash_len := 1.6
	var period := dash_len + 1.6
	var z := -SEGMENT_LEN * 0.5 + dash_len * 0.5
	while z < SEGMENT_LEN * 0.5:
		_add_box(Vector3(0.16, 0.04, dash_len), Vector3(x, 0.03, z), mat)
		z += period


func _add_box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func clear_props() -> void:
	for child in left_slot.get_children():
		child.queue_free()
	for child in right_slot.get_children():
		child.queue_free()

# Builds a varied streetscape of whole buildings along both sides of the road.
# A front row lines the street; a sparser, taller back row gives skyline depth.
func populate_dense_city(building_scenes: Array[PackedScene], scale_min: float = 4.0, scale_max: float = 6.0, density: float = 1.0) -> void:
	if building_scenes.size() == 0:
		return

	for side in [-1.0, 1.0]:
		var slot: Node3D = left_slot if side < 0.0 else right_slot
		var z := -SEGMENT_LEN * 0.5 + 1.0
		while z < SEGMENT_LEN * 0.5:
			# Front row — the street wall (sparser in rural biomes). Kept well off
			# the road: the slot sits at x=±8 and large building models are wide, so
			# a small depth used to let first-floor balconies/awnings hang over the
			# lanes. Bigger depth keeps the facades almost entirely off the road.
			if randf() < density:
				_spawn_building(slot, building_scenes.pick_random(), z, side, scale_min, scale_max, 3.8)
			# Occasional taller building set back for a layered skyline.
			if randf() < 0.45 * density:
				_spawn_building(slot, building_scenes.pick_random(), z + randf_range(-1.5, 1.5), side, scale_min * 1.1, scale_max * 1.35, 8.0)
			z += randf_range(4.5, 6.5)


func _spawn_building(parent_slot: Node3D, prop_scene: PackedScene, z_pos: float, side_dir: float, smin: float, smax: float, depth_base: float) -> void:
	var prop := prop_scene.instantiate() as Node3D
	if prop == null:
		return
	parent_slot.add_child(prop)

	# Push outward from the road edge (slot is already at x = ±8).
	var depth := depth_base + randf_range(0.0, 2.0)
	prop.position = Vector3(depth * side_dir, 0.0, z_pos)

	# Orthogonal rotation for variety; buildings read well from any face.
	prop.rotation_degrees.y = [0, 90, 180, 270][randi() % 4]

	# Independent height stretch so the skyline isn't uniform.
	var s := randf_range(smin, smax)
	var y_stretch := randf_range(0.85, 1.7)
	prop.scale = Vector3(s, s * y_stretch, s)
