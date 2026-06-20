## Gantry — a procedural overhead structure spanning the highway.
##
## Cosmetic only (no collision — you always run under it). It exists to punctuate
## the biomes and SELL SPEED: it rushes the camera, rides the road's cosmetic
## curve + hills exactly like the cars and segments, then triggers a doppler
## whoosh + a quick shadow sweep + a light-and-camera kick as it passes overhead.
##
## Built entirely in code (no .tscn) so the spawner can tint/style it per biome.
extends Node3D

## Forward speed (m/s), kept in sync with the highway by the spawner each frame.
var speed: float = 15.0
## Highway node, for the curve/hill perspective "lenses" (same ones cars ride).
var highway_ref: Node3D = null
## Player node, to know where "overhead" is for the pass-under sweep.
var player_ref: Node3D = null

## Half-width of the road the gantry must clear, plus a little margin per pillar.
const HALF_WIDTH := 6.4
## Height of the cross-beam above the road.
const BEAM_H := 6.6
## World Z at which the structure is "overhead" and the whoosh/sweep fires. Sits
## between the player (z=6.5) and the camera (z=12) so it lands as it fills frame.
const SWEEP_Z := 9.0

## Accent (emissive) color for the sign/strips/light — set per biome.
var accent: Color = Color(1.0, 0.85, 0.4)
## When true this gantry carries a lit sign panel; otherwise it's a bare truss.
var has_sign: bool = true

var _swept: bool = false
var _prev_z: float = -999.0
var _sweep_light: OmniLight3D = null


func _ready() -> void:
	_build()
	_prev_z = position.z


func _build() -> void:
	var span := HALF_WIDTH * 2.0

	var strut_mat := StandardMaterial3D.new()
	strut_mat.albedo_color = Color(0.16, 0.17, 0.20)
	strut_mat.metallic = 0.7
	strut_mat.roughness = 0.45

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = accent.lerp(Color.WHITE, 0.2)
	accent_mat.emission_enabled = true
	accent_mat.emission = accent
	accent_mat.emission_energy_multiplier = 3.2

	# Two vertical pillars at the road edges.
	for side in [-1.0, 1.0]:
		var pillar := _box(Vector3(0.55, BEAM_H, 0.55), strut_mat)
		pillar.position = Vector3(side * (HALF_WIDTH + 0.1), BEAM_H * 0.5, 0.0)
		add_child(pillar)
		# A glowing foot-strip up each pillar for a touch of life.
		var strip := _box(Vector3(0.12, BEAM_H * 0.82, 0.12), accent_mat)
		strip.position = Vector3(side * (HALF_WIDTH + 0.38), BEAM_H * 0.5, 0.32)
		add_child(strip)

	# Top cross-beam connecting the pillars.
	var beam := _box(Vector3(span + 1.0, 0.7, 0.95), strut_mat)
	beam.position = Vector3(0.0, BEAM_H, 0.0)
	add_child(beam)
	# A second, thinner truss rail below it reads as a real gantry, not a slab.
	var rail := _box(Vector3(span + 0.4, 0.18, 0.18), accent_mat)
	rail.position = Vector3(0.0, BEAM_H - 0.55, 0.42)
	add_child(rail)

	if has_sign:
		# Hanging sign panel, lit so it pops against the sky.
		var sign := _box(Vector3(span * 0.5, 1.7, 0.22), accent_mat)
		sign.position = Vector3(0.0, BEAM_H - 1.35, 0.0)
		add_child(sign)
		# Dark frame behind the sign for contrast.
		var frame := _box(Vector3(span * 0.5 + 0.4, 2.1, 0.16), strut_mat)
		frame.position = Vector3(0.0, BEAM_H - 1.35, -0.12)
		add_child(frame)

	# A downward light slung under the beam — it sweeps over the player as the
	# gantry passes, the cheap-but-effective "drove under a lit structure" beat.
	_sweep_light = OmniLight3D.new()
	_sweep_light.light_color = accent
	_sweep_light.light_energy = 2.4
	_sweep_light.omni_range = span * 1.3
	_sweep_light.position = Vector3(0.0, BEAM_H - 1.0, 0.0)
	add_child(_sweep_light)


func _box(size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	return mi


func _process(delta: float) -> void:
	position.z += speed * delta

	# Ride the road's cosmetic curve + hills, exactly like cars and segments, so
	# the gantry sits ON the bending/rolling road instead of floating straight.
	if highway_ref:
		if highway_ref.has_method("get_curve_offset"):
			position.x = highway_ref.get_curve_offset(position.z)
		if highway_ref.has_method("get_curve_yaw"):
			rotation.y = highway_ref.get_curve_yaw(position.z)
		if highway_ref.has_method("get_height_offset"):
			position.y = highway_ref.get_height_offset(position.z)

	# Pass-under sweep: fire once as the structure crosses the overhead plane.
	if not _swept and _prev_z < SWEEP_Z and position.z >= SWEEP_Z:
		_swept = true
		_do_sweep()
	_prev_z = position.z

	# Despawn once well behind the camera.
	if position.z > 22.0:
		queue_free()


func _do_sweep() -> void:
	AudioManager.play_gantry_whoosh()
	# A quick dark "shadow sweep" (flash with a near-black color = a momentary dim)
	# plus a small camera/light kick for the physical whoosh of mass overhead.
	Juice.flash(Color(0.02, 0.02, 0.05), 0.34, 0.22)
	Juice.kick_fov(5.0)
	Juice.add_trauma(0.16)
	Juice.haptic(18)
	# Punch the under-light bright for the instant it's overhead, then let it fade.
	if _sweep_light:
		_sweep_light.light_energy = 6.0
		var tw := create_tween()
		tw.tween_property(_sweep_light, "light_energy", 2.4, 0.45)
