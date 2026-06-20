extends SceneTree

func _init():
	var scene = load("res://assets/kenney_animated-characters-protagonists/Animations/run.fbx")
	var node = scene.instantiate()
	var ap = node.get_node("AnimationPlayer")
	var anim = ap.get_animation("Root|Run")
	print("Track 0 path: ", anim.track_get_path(0))
	quit()
