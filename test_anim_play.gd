extends SceneTree

func _init():
	# load autoloads
	var game_manager = load("res://scripts/autoload/GameManager.gd").new()
	var prog_manager = load("res://scripts/autoload/ProgressionManager.gd").new()
	var input_settings = load("res://scripts/autoload/InputSettings.gd").new()
	root.add_child(game_manager)
	root.add_child(prog_manager)
	root.add_child(input_settings)
	
	var scene = load("res://scenes/player/Player.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	
	# wait 2 frames for ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	var ap = node.get_node("AnimationPlayer")
	print("Is playing? ", ap.is_playing())
	print("Current anim: ", ap.current_animation)
	
	var skel = node.get_node("PlayerMesh/Root/Skeleton3D")
	print("Bone 0 pose: ", skel.get_bone_pose(0))
	quit()
