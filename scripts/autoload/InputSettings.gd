## InputSettings — Autoload for input configuration
##
## Manages the active input scheme (keyboard arrows, WASD, or touch/swipe)
## and persists the user's preference to disk.

extends Node

signal input_scheme_changed(scheme: InputScheme)

## Emitted by an upward swipe (jump) / downward swipe (bullet-time) on touch.
signal jump_requested()
signal bullet_time_requested()

enum InputScheme {
	ARROWS,      ## Arrow keys (←/→)
	WASD,        ## A/D keys
	TOUCH_SWIPE, ## Touch/swipe on mobile
}

## The currently active input scheme.
var current_scheme: InputScheme = InputScheme.ARROWS

## Touch state. Movement is direct positioning: the runner tracks the finger's
## position on the road, so we just expose the current touch point.
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_pos: Vector2 = Vector2.ZERO
var _is_touching: bool = false
var _swipe_direction: float = 0.0  # legacy relative steer (unused by movement now)
## Whether this touch has already fired a vertical (jump/slow-mo) flick.
var _vert_fired: bool = false

## Minimum swipe distance (pixels) to register.
const SWIPE_THRESHOLD: float = 30.0

## Deadzone for continuous touch steering.
const TOUCH_DEADZONE: float = 15.0

## Vertical travel (pixels) for a swipe up/down to count as a jump / slow-mo flick.
const VERT_FLICK: float = 70.0

const SAVE_PATH := "user://input_settings.cfg"
var _config := ConfigFile.new()


func _ready() -> void:
	_load_settings()
	_apply_input_map()


## Touch is always handled (regardless of the chosen keyboard scheme) so the game
## is playable on mobile out of the box: hold-and-drag left/right to steer, flick
## up to jump, flick down for slow-mo. Real touch events only fire on touch
## devices, so this never interferes with mouse/keyboard on desktop.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event.position
			_touch_pos = event.position
			_is_touching = true
			_vert_fired = false
		else:
			_is_touching = false

	elif event is InputEventScreenDrag and _is_touching:
		_touch_pos = event.position
		var dx: float = event.position.x - _touch_start_pos.x
		var dy: float = event.position.y - _touch_start_pos.y
		# A clearly-vertical flick fires jump (up) / slow-mo (down) once per touch.
		# Horizontal finger position drives movement directly (see PlayerController),
		# so vertical-only gestures don't move the runner.
		if not _vert_fired and absf(dy) > VERT_FLICK and absf(dy) > absf(dx):
			_vert_fired = true
			if dy < 0.0:
				jump_requested.emit()
			else:
				bullet_time_requested.emit()


## Whether a finger is currently down (drives direct-position movement).
func is_touch_active() -> bool:
	return _is_touching


## The current touch point in viewport coordinates (for projecting onto the road).
func get_touch_screen_pos() -> Vector2:
	return _touch_pos


## Returns the keyboard lateral input axis (-1 to 1). Touch movement is handled
## separately via direct positioning, not this axis.
func get_move_axis() -> float:
	return Input.get_axis("move_left", "move_right")


## Sets the input scheme and persists the choice.
func set_scheme(scheme: InputScheme) -> void:
	current_scheme = scheme
	_save_settings()
	input_scheme_changed.emit(scheme)
	print("[InputSettings] Scheme changed to: ", InputScheme.keys()[scheme])


## Cycles to the next input scheme.
func cycle_scheme() -> void:
	var next := (current_scheme + 1) % InputScheme.size()
	set_scheme(next as InputScheme)


func _apply_input_map() -> void:
	var actions = ["move_left", "move_right", "jump", "bullet_time", "fire"]
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)

	# Always bind both WASD and Arrows for keyboard schemes
	_bind_key("move_left", KEY_LEFT)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_RIGHT)
	_bind_key("move_right", KEY_D)
	
	# Jump: Space, Up arrow, W.
	_bind_key("jump", KEY_SPACE)
	_bind_key("jump", KEY_UP)
	_bind_key("jump", KEY_W)
	# Bullet time: Down arrow, S, plus legacy B / Shift.
	_bind_key("bullet_time", KEY_DOWN)
	_bind_key("bullet_time", KEY_S)
	_bind_key("bullet_time", KEY_B)
	_bind_key("bullet_time", KEY_SHIFT)
	_bind_key("fire", KEY_F)


func _bind_key(action: String, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)



func _load_settings() -> void:
	if _config.load(SAVE_PATH) == OK:
		var scheme_idx := _config.get_value("input", "scheme", 0) as int
		if scheme_idx >= 0 and scheme_idx < InputScheme.size():
			current_scheme = scheme_idx as InputScheme


func _save_settings() -> void:
	_config.set_value("input", "scheme", current_scheme)
	_config.save(SAVE_PATH)
