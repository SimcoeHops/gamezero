## CarController — Individual car behavior
##
## Manages an approaching car's lifecycle:
##   APPROACHING → moves toward the player at the current highway speed.
##   CRUMPLED    → on collision, deforms mesh, enables physics, explodes debris.
##   DODGED      → when the car passes the player, registers a dodge and frees itself.

extends RigidBody3D

## Emitted when this car collides with the player.
signal car_crashed(impact_velocity: Vector3)

enum CarState { APPROACHING, CRUMPLED, DODGED }

## Current state of this car.
var state: CarState = CarState.APPROACHING

## Speed this car approaches the player (set by CarSpawner).
var approach_speed: float = 15.0

## Reference to the player node (set by CarSpawner).
var player_ref: Node3D = null

## Reference to the Highway (set by CarSpawner) for cosmetic curve following.
var highway_ref: Node3D = null

## The visual model node, offset laterally so the car follows the road's bend.
var _visual: Node3D = null

## Internal tracking for dodge detection.
var _passed_player: bool = false

## Seconds since this car crumpled (used to clean up flying debris promptly so it
## can't loiter on the road / rain back down on the player).
var _crumple_age: float = 0.0

## Lateral distance (m) under which a dodge counts as a near miss.
const NEAR_MISS_DIST := 2.2

# Resolved dynamically so crumple works regardless of which model is swapped in.
var _normal_mesh: MeshInstance3D = null
## This car's body tint, reused to colour the debris chunks on destruction.
var _tint: Color = Color(0.7, 0.7, 0.75)
@onready var _dodge_detector: Area3D = $DodgeDetector
@onready var _crash_particles: GPUParticles3D = $CrashParticles


func _ready() -> void:
	# Start as kinematic (frozen) — we move it manually
	freeze = true
	contact_monitor = true
	max_contacts_reported = 4
	add_to_group("cars")

	# Find the visual mesh under NormalMesh (model may have been swapped by the
	# spawner, so we can't rely on a fixed child name).
	_visual = get_node_or_null("NormalMesh")
	_normal_mesh = _find_first_mesh(_visual)

	# Connect dodge detector
	if _dodge_detector:
		_dodge_detector.body_entered.connect(_on_dodge_detector_body_entered)

	# Connect body collision for crash detection
	body_entered.connect(_on_body_entered)


## Applies a visual variant to this car: swaps the model, tints it, and scales
## it. Call this *before* add_child() (the spawner does). [param size] uniformly
## scales the whole body (visual + collision).
func apply_variant(model_scene: PackedScene, tint: Color, size: float) -> void:
	if model_scene:
		var old := get_node_or_null("NormalMesh") as Node3D
		var xform := old.transform if old else Transform3D()
		if old:
			remove_child(old)
			old.free()
		var new_model := model_scene.instantiate() as Node3D
		new_model.name = "NormalMesh"
		add_child(new_model)
		new_model.transform = xform

	_apply_tint(tint)
	scale = Vector3.ONE * size


## Tints every mesh surface under NormalMesh by multiplying its albedo, which
## keeps the model's texture detail while shifting its overall color.
func _apply_tint(color: Color) -> void:
	_tint = color
	var root := get_node_or_null("NormalMesh")
	if root == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	for mi in meshes:
		var base_mat := mi.get_active_material(0)
		# The Kenney kit ships a shared "colormap" palette texture that gives the
		# cars their windows, lights and wheels. Grab it (works for any
		# BaseMaterial3D the GLB imports as) so we can keep that detail.
		var tex: Texture2D = null
		if base_mat is BaseMaterial3D:
			tex = (base_mat as BaseMaterial3D).albedo_texture
		var mat := StandardMaterial3D.new()
		if tex:
			# Keep the colormap and let the chosen color come through as a gentle
			# tint, so each car reads as its hue but stays fully textured/detailed.
			mat.albedo_texture = tex
			# Richer body color (less washed out) so it reads as painted bodywork.
			mat.albedo_color = color.lerp(Color.WHITE, 0.4)
			# Glossy painted-metal finish: reflective, fairly smooth, with a
			# clear-coat sheen. Reflections off the world env sell "car" far better
			# than the old flat matte tint did.
			mat.metallic = 0.6
			mat.metallic_specular = 0.7
			mat.roughness = 0.32
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.6
			mat.clearcoat_roughness = 0.15
			# A touch of self-glow off the colormap keeps lights/windows readable at
			# night without flattening the paint.
			mat.emission_enabled = true
			mat.emission_texture = tex
			mat.emission = color.lerp(Color.WHITE, 0.4)
			mat.emission_energy_multiplier = 0.08
		else:
			# No texture available — fall back to a readable flat tint.
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 0.35
		mi.set_surface_override_material(0, mat)


func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh(child)
		if found:
			return found
	return null


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, out)


func _physics_process(delta: float) -> void:
	match state:
		CarState.APPROACHING:
			# Move toward camera (positive Z in our setup)
			position.z += approach_speed * delta

			# Auto-cleanup if way past the player
			if position.z > 20.0 and _passed_player:
				queue_free()

			# Cleanup if way too far past without dodge trigger
			if position.z > 30.0:
				queue_free()

		CarState.CRUMPLED:
			# The despawn tween normally shrinks the wreck away within ~1s; this is
			# just a backstop in case the tween is interrupted (and to catch a wreck
			# that somehow flies off the world).
			_crumple_age += delta
			if _crumple_age > 1.6 or global_position.y < -20.0 or global_position.length() > 100.0:
				queue_free()

		CarState.DODGED:
			# Continue forward then cleanup
			position.z += approach_speed * delta
			if position.z > 25.0:
				queue_free()

	# Once crumpled, physics owns the body — leave the mesh alone.
	if state != CarState.CRUMPLED:
		_apply_curve_visual()


## Offsets the visual model laterally to follow the road's cosmetic bend.
## The collision body stays on its true lane, so dodging is unaffected.
func _apply_curve_visual() -> void:
	if _visual == null:
		return
	if highway_ref and highway_ref.has_method("get_curve_offset"):
		_visual.position.x = highway_ref.get_curve_offset(global_position.z)
	# Ride the cosmetic hills so distant cars sit on the road, not above it.
	if highway_ref and highway_ref.has_method("get_height_offset"):
		_visual.position.y = highway_ref.get_height_offset(global_position.z)
	# Speed smear: only at high speed, and only along depth (Z) so the car's
	# lateral profile stays crisp for dodging.
	var smear := 1.0
	if approach_speed > 35.0:
		smear = 1.0 + clampf((approach_speed - 35.0) / 45.0, 0.0, 1.0) * 0.22
	_visual.scale.z = smear


## Whether this car is still a live threat (approaching, not already wrecked or
## dodged). The player uses this to ignore debris that flies back into its hitbox.
func is_live() -> bool:
	return state == CarState.APPROACHING


## Triggers the crumple/crash state.
## [param impact_point]: World-space point of collision.
## [param impact_velocity]: Velocity at moment of impact.
func crumple(impact_point: Vector3, impact_velocity: Vector3) -> void:
	if state == CarState.CRUMPLED:
		return

	state = CarState.CRUMPLED
	print("[Car] CRUMPLE! Speed: ", approach_speed)

	# Debris must not interact with the player (or anything else) anymore: once a
	# car is wrecked it's pure spectacle. Clearing its layer/mask stops it from
	# triggering the player's hitbox or physically shoving the player when a
	# gun-blasted / detonated car tumbles back through the runner.
	collision_layer = 0
	collision_mask = 0
	if _dodge_detector:
		_dodge_detector.set_deferred("monitoring", false)

	# Unfreeze to enable physics simulation
	freeze = false

	# Apply BeamNG-style mesh deformation
	if _normal_mesh and _normal_mesh.mesh:
		CrumpleDeformer.deform_mesh_instance(
			_normal_mesh,
			impact_point,
			clampf(approach_speed * 0.05, 0.3, 1.5),  # magnitude scales with speed
			2.0,   # radius
			0.5    # jitter
		)

	# Small impulse + spin so the wreck crunches and flips in place rather than
	# rocketing high into the air — it's about to burst into pieces and vanish,
	# so it shouldn't sail across the screen first.
	var explosion_dir := (global_position - impact_point).normalized()
	explosion_dir.y = 0.2
	apply_central_impulse(explosion_dir * (approach_speed * mass * 0.45))
	apply_torque_impulse(Vector3(
		randf_range(-30.0, 30.0),
		randf_range(-20.0, 20.0),
		randf_range(-30.0, 30.0)
	))

	# Start crash particles + burst the body into flying chunks.
	if _crash_particles:
		_crash_particles.emitting = true
	_spawn_debris()

	# Audio + a little shake for every car that's destroyed.
	AudioManager.play_car_hit()
	Juice.add_trauma(0.18)

	car_crashed.emit(impact_velocity)

	# Disappear fast — faster the quicker we're moving — by shrinking the crunched
	# body away, then freeing the whole car.
	_begin_despawn()


## Lifetime (seconds) of a wreck before it shrinks away. Shorter at high speed so
## the road clears quickly when you're flying along.
func _wreck_lifetime() -> float:
	var fast := clampf((approach_speed - 15.0) / 110.0, 0.0, 1.0)
	return lerpf(1.0, 0.45, fast)


## Shrinks the crunched body out of view after a brief beat, then frees the car.
func _begin_despawn() -> void:
	var life := _wreck_lifetime()
	var tw := create_tween()
	tw.tween_interval(maxf(life - 0.22, 0.0))
	if _visual:
		tw.tween_property(_visual, "scale", _visual.scale * 0.02, 0.22).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## Bursts a handful of small chunks out from the wreck that arc, tumble, and fade
## — the "exploded into pieces" payoff. Pure visual (no physics bodies), tinted to
## the car's colour, and self-cleaning.
func _spawn_debris() -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var origin := global_position + Vector3(0.0, 0.4, 0.0)
	var count := 8
	for i in count:
		var piece := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := randf_range(0.18, 0.5)
		bm.size = Vector3(s, s * randf_range(0.6, 1.2), s)
		piece.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _tint
		mat.metallic = 0.5
		mat.roughness = 0.4
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		piece.material_override = mat
		host.add_child(piece)
		piece.global_position = origin + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.6), randf_range(-0.4, 0.4))

		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.4), randf_range(-1.0, 1.0)).normalized()
		var target := piece.global_position + dir * randf_range(1.6, 3.4) + Vector3(0.0, -1.4, 0.0)
		var dur := randf_range(0.5, 0.8)
		var tw := piece.create_tween()
		tw.set_parallel(true)
		tw.tween_property(piece, "global_position", target, dur).set_ease(Tween.EASE_OUT)
		tw.tween_property(piece, "rotation", Vector3(randf() * TAU, randf() * TAU, randf() * TAU), dur)
		tw.tween_property(mat, "albedo_color:a", 0.0, dur).set_delay(dur * 0.4)
		tw.chain().tween_callback(piece.queue_free)


## Handles collision with the player's CharacterBody3D.
func _on_body_entered(body: Node) -> void:
	if state != CarState.APPROACHING:
		return

	if body is PlayerController:
		var impact_vel := Vector3(0, 0, approach_speed)
		var impact_point := global_position + Vector3(0, 0, 1.0)

		# Crumple this car
		crumple(impact_point, impact_vel)

		# Star power plows through; a mid-air stomp knocks us out and bounces off.
		if PowerUpManager.is_invincible():
			return
		if body.has_method("can_stomp") and body.can_stomp():
			body.stomp_bounce(impact_vel)
			return

		# Trigger player ragdoll.
		body.activate_ragdoll(impact_vel)


## Handles the dodge detector area trigger.
func _on_dodge_detector_body_entered(_body: Node) -> void:
	# The dodge detector is positioned behind the car.
	# When the player's body enters it, the car has passed without collision.
	# But actually, we detect dodges when the car passes the player Z position.
	pass


func _process(_delta: float) -> void:
	# Check if car has passed the player (dodge detection)
	if state == CarState.APPROACHING and not _passed_player:
		if player_ref and position.z > player_ref.position.z + 2.0:
			_passed_player = true
			state = CarState.DODGED
			ProgressionManager.register_dodge()
			# Close call? Reward it — and tell the world HOW close, so a hair's-breadth
			# graze earns a bigger thrill than a lazy near-miss (closeness 0..1, 1 = touching).
			var lateral := absf(global_position.x - player_ref.global_position.x)
			if lateral < NEAR_MISS_DIST:
				var closeness := clampf(1.0 - lateral / NEAR_MISS_DIST, 0.0, 1.0)
				ProgressionManager.register_near_miss(closeness)
