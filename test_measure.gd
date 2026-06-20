extends SceneTree

func _init():
	var paths = [
		"res://assets/kenney_city-kit-roads/Models/GLB format/road-straight-barrier.glb",
		"res://assets/kenney_retro-urban-kit/Models/GLB format/road-asphalt-straight.glb"
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			var scene = load(path)
			var node = scene.instantiate()
			print("Model: ", path.get_file())
			_print_meshes(node)
	quit()

func _print_meshes(node):
	if node is MeshInstance3D:
		print("  AABB size: ", node.mesh.get_aabb().size)
	for c in node.get_children():
		_print_meshes(c)
