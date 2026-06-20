extends SceneTree

func _init():
	var action = "move_left"
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventKey.new()
	ev.physical_keycode = KEY_A
	InputMap.action_add_event(action, ev)
	
	print("move_left events:")
	for e in InputMap.action_get_events(action):
		print(" - ", e.as_text())
	quit()
