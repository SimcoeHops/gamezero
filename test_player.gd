extends SceneTree

func _init():
	var scene = load("res://scenes/player/Player.tscn")
	var node = scene.instantiate()
	var ap = node.get_node("AnimationPlayer")
	print("AP root: ", ap.root_node)
	var root = ap.get_node(ap.root_node)
	print("Resolved root: ", root.name)
	var skel = root.get_node_or_null("Root/Skeleton3D")
	print("Resolved skel: ", skel)
	quit()
