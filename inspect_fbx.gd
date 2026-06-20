extends SceneTree

func _init():
	var scene1 = load("res://assets/kenney_animated-characters-protagonists/Model/characterMedium.fbx")
	var scene2 = load("res://assets/kenney_car-kit/Models/GLB format/sedan-sports.glb")
	if scene1:
		print("--- Character ---")
		_print_tree(scene1.instantiate(), "")
	if scene2:
		print("--- Car ---")
		_print_tree(scene2.instantiate(), "")
	else:
		print("Failed to load scene")
	quit()

func _print_tree(node, indent):
	print(indent + node.name + " (" + node.get_class() + ")")
	if node is AnimationPlayer:
		print(indent + "  Animations: " + str(node.get_animation_list()))
	for child in node.get_children():
		_print_tree(child, indent + "  ")
