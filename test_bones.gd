extends SceneTree

func _init():
	var char_scene = load("res://assets/kenney_animated-characters-protagonists/Model/characterMedium.fbx").instantiate()
	var run_scene = load("res://assets/kenney_animated-characters-protagonists/Animations/run.fbx").instantiate()
	
	var char_skel = char_scene.get_node("Root/Skeleton3D")
	var run_skel = run_scene.get_node("Root/Skeleton3D")
	
	print("Char bones: ", char_skel.get_bone_count())
	print("Run bones: ", run_skel.get_bone_count())
	quit()
