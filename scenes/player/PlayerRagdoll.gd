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


## Deactivates ragdoll and resets body parts.
func deactivate() -> void:
	is_active = false
	for part in _body_parts:
		part.freeze = true
		part.visible = false
		part.linear_velocity = Vector3.ZERO
		part.angular_velocity = Vector3.ZERO
