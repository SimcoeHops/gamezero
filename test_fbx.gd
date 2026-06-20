extends SceneTree

func _init():
	var scene = load("res://assets/kenney_animated-characters-protagonists/Animations/run.fbx")
	var node = scene.instantiate()
	_search_mesh(node)
	quit()

func _search_mesh(node):
	if node is MeshInstance3D:
		print("FOUND MESH: ", node.name)
	for child in node.get_children():
		_search_mesh(child)
