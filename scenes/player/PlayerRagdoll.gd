## PlayerRagdoll — Ragdoll Activation Helper
##
## Manages the Skeleton3D / PhysicalBone3D setup for ragdoll physics.
## Attached to the RagdollSkeleton node inside the Player scene.
##
## Note: For CSG placeholder geometry, we simulate ragdoll with
## separate RigidBody3D "body parts" rather than a real Skeleton3D.
## This script manages those body parts.

extends Node3D

## The body part rigid bodies that make up the ragdoll.
var _body_parts: Array[RigidBody3D] = []

## Whether the ragdoll is currently active.
var is_active: bool = false


func _ready() -> void:
	# Collect all RigidBody3D children as body parts
	for child in get_children():
		if child is RigidBody3D:
			_body_parts.append(child)
			# Start frozen (kinematic-like behavior)
			child.freeze = true
			child.visible = false


## Activates ragdoll physics on all body parts.
## [param impact_velocity]: Car velocity at moment of impact.
## [param origin]: World-space position of the player at impact.
func activate(impact_velocity: Vector3, origin: Vector3) -> void:
	if is_active:
		return

	is_active = true

	for part in _body_parts:
		part.freeze = false
		part.visible = true
		part.global_position = origin + Vector3(
			randf_range(-0.2, 0.2),
			randf_range(0.0, 1.5),
			randf_range(-0.2, 0.2)
		)

		# Apply exaggerated impulse with randomness
		var impulse := impact_velocity * randf_range(2.0, 6.0)
		impulse.y = absf(impulse.y) + randf_range(5.0, 15.0)  # Always launch upward

		var torque := Vector3(
			randf_range(-20.0, 20.0),
			randf_range(-10.0, 10.0),
			randf_range(-20.0, 20.0),
		)

		part.apply_central_impulse(impulse)
		part.apply_torque_impulse(torque)

	# Glass/metal shards + sparks at the impact point — the visual crunch.
	_spawn_debris(origin, impact_velocity)


## Fires a one-shot debris burst (tumbling glass/metal shards + bright sparks)
## at the crash point, then frees the emitters once they finish. Parented to the
## current scene so the gibs keep their own world-space trajectory.
func _spawn_debris(origin: Vector3, impact_velocity: Vector3) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var aim := impact_velocity.normalized()
	if aim == Vector3.ZERO:
		aim = Vector3.UP

	# --- Tumbling shards (glass + metal chunks) -----------------------------
	var shards := GPUParticles3D.new()
	shards.one_shot = true
	shards.amount = 40
	shards.lifetime = 1.6
	shards.explosiveness = 1.0
	shards.local_coords = false
	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.1, 0.1, 0.025)
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.72, 0.86, 1.0)
	shard_mat.metallic = 0.85
	shard_mat.roughness = 0.12
	shard_mat.emission_enabled = true
	shard_mat.emission = Color(0.5, 0.75, 1.0)
	shard_mat.emission_energy_multiplier = 1.4
	shard_mesh.material = shard_mat
	shards.draw_pass_1 = shard_mesh
	var spm := ParticleProcessMaterial.new()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spm.emission_sphere_radius = 0.35
	spm.direction = (aim + Vector3.UP * 1.5).normalized()
	spm.spread = 75.0
	spm.initial_velocity_min = 4.0
	spm.initial_velocity_max = 13.0
	spm.gravity = Vector3(0, -24.0, 0)
	spm.angular_velocity_min = -720.0
	spm.angular_velocity_max = 720.0
	spm.scale_min = 0.5
	spm.scale_max = 1.6
	spm.damping_min = 1.0
	spm.damping_max = 3.0
	shards.process_material = spm
	host.add_child(shards)
	shards.global_position = origin
	shards.emitting = true

	# --- Bright sparks ------------------------------------------------------
	var sparks := GPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = 28
	sparks.lifetime = 0.55
	sparks.explosiveness = 1.0
	sparks.local_coords = false
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.05, 0.05, 0.05)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.85, 0.45)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.7, 0.25)
	spark_mat.emission_energy_multiplier = 4.0
	spark_mesh.material = spark_mat
	sparks.draw_pass_1 = spark_mesh
	var spkm := ParticleProcessMaterial.new()
	spkm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spkm.emission_sphere_radius = 0.2
	spkm.direction = Vector3.UP
	spkm.spread = 90.0
	spkm.initial_velocity_min = 8.0
	spkm.initial_velocity_max = 22.0
	spkm.gravity = Vector3(0, -30.0, 0)
	spkm.scale_min = 0.4
	spkm.scale_max = 1.2
	sparks.process_material = spkm
	host.add_child(sparks)
	sparks.global_position = origin + Vector3(0, 0.5, 0)
	sparks.emitting = true

	# Free the emitters after they've fully burned out.
	var tree := get_tree()
	tree.create_timer(shards.lifetime + 0.6).timeout.connect(shards.queue_free)
	tree.create_timer(sparks.lifetime + 0.6).timeout.connect(sparks.queue_free)


## Deactivates ragdoll and resets body parts.
func deactivate() -> void:
	is_active = false
	for part in _body_parts:
		part.freeze = true
		part.visible = false
		part.linear_velocity = Vector3.ZERO
		part.angular_velocity = Vector3.ZERO
