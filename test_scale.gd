extends SceneTree

func _init():
	var road_path = "res://assets/kenney_retro-urban-kit/Models/GLB format/road-asphalt-straight.glb"
	var bldg_path = "res://assets/kenney_retro-urban-kit/Models/GLB format/wall-b-garage.glb"
	
	_measure(road_path, "Road")
	_measure(bldg_path, "Building")
	quit()

func _measure(path, label):
	var scene = load(path)
	if not scene: return
	var node = scene.instantiate()
	var aabb = AABB()
	var first = true
	var meshes = []
	_find_meshes(node, meshes)
	for m in meshes:
		if first:
			aabb = m.mesh.get_aabb()
			first = false
		else:
			aabb = aabb.merge(m.mesh.get_aabb())
	print(label, " AABB: pos=", aabb.position, " size=", aabb.size)

func _find_meshes(node, list):
	if node is MeshInstance3D:
		list.append(node)
	for c in node.get_children():
		_find_meshes(c, list)
