extends SceneTree
func _init():
	var path = "res://assets/kenney_city-kit-roads/Models/GLB format/road-straight-barrier.glb"
	var scene = load(path)
	var node = scene.instantiate()
	var aabb = node.get_child(0).mesh.get_aabb()
	print("City Road: pos=", aabb.position, " size=", aabb.size)
	quit()
