## CrumpleDeformer — Static Utility
##
## Procedurally deforms a mesh to simulate vehicle crumple on impact.
## Inspired by BeamNG.drive's soft-body deformation aesthetic.
##
## Usage:
##   var deformed := CrumpleDeformer.deform(mesh_instance, impact_point, impact_magnitude)
##   mesh_instance.mesh = deformed

class_name CrumpleDeformer
extends RefCounted


## Deforms vertices of [param source_mesh] near [param impact_point_local]
## (in local space of the mesh). Returns a new [ArrayMesh] with the
## deformation applied.
##
## [param impact_point_local]: The collision point in mesh-local coordinates.
## [param magnitude]: How far vertices are displaced (meters). Higher = more crumpled.
## [param radius]: Radius of influence around the impact point.
## [param jitter]: Random lateral displacement factor for asymmetry (0.0–1.0).
static func deform(
	source_mesh: Mesh,
	impact_point_local: Vector3,
	magnitude: float = 0.5,
	radius: float = 1.5,
	jitter: float = 0.4
) -> ArrayMesh:
	if source_mesh == null:
		push_error("[CrumpleDeformer] source_mesh is null")
		return ArrayMesh.new()

	var mdt := MeshDataTool.new()
	var array_mesh: ArrayMesh

	# Convert to ArrayMesh if needed
	if source_mesh is ArrayMesh:
		array_mesh = source_mesh.duplicate() as ArrayMesh
	else:
		# For primitive meshes (BoxMesh, etc.), generate an ArrayMesh
		array_mesh = ArrayMesh.new()
		for surf_idx in source_mesh.get_surface_count():
			var arrays := source_mesh.surface_get_arrays(surf_idx)
			array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if array_mesh.get_surface_count() == 0:
		push_warning("[CrumpleDeformer] Mesh has no surfaces to deform")
		return array_mesh

	# Process surface 0 (primary surface)
	var err := mdt.create_from_surface(array_mesh, 0)
	if err != OK:
		push_error("[CrumpleDeformer] Failed to create MeshDataTool: ", err)
		return array_mesh

	var vertex_count := mdt.get_vertex_count()

	for i in vertex_count:
		var vert := mdt.get_vertex(i)
		var dist := vert.distance_to(impact_point_local)

		if dist < radius:
			# Falloff: vertices closer to impact deform more
			var falloff := 1.0 - (dist / radius)
			falloff = falloff * falloff  # quadratic falloff for natural look

			# Primary displacement: push vertex toward/past the impact point
			var direction := (impact_point_local - vert).normalized()
			var displacement := direction * magnitude * falloff

			# Jitter: random lateral offset for asymmetric crumpling
			var jitter_vec := Vector3(
				randf_range(-jitter, jitter),
				randf_range(-jitter * 0.5, jitter * 0.5),
				randf_range(-jitter, jitter)
			) * falloff

			vert += displacement + jitter_vec
			mdt.set_vertex(i, vert)

	# Commit modified vertices back to mesh
	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)

	return array_mesh


## Convenience overload that works with a [MeshInstance3D] directly.
## Deforms in-place by replacing the mesh resource.
static func deform_mesh_instance(
	mesh_instance: MeshInstance3D,
	impact_point_world: Vector3,
	magnitude: float = 0.5,
	radius: float = 1.5,
	jitter: float = 0.4
) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		push_error("[CrumpleDeformer] MeshInstance3D or its mesh is null")
		return

	# Convert impact point from world space to mesh-local space
	var impact_local := mesh_instance.to_local(impact_point_world)

	var deformed := deform(mesh_instance.mesh, impact_local, magnitude, radius, jitter)
	mesh_instance.mesh = deformed
