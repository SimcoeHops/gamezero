## ContinueScreen — shown when the player dies but can pay to continue.
## Tap within the countdown to revive; otherwise the run ends.

extends Control

const PROMPT_TIME := 4.0
const CONTINUE_IMAGE := "res://assets/images/continue1.png"

var _label: Label = null
var _time_left: float = 0.0
var _active: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Centered stack: custom artwork on top, prompt text below it.
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	if ResourceLoader.exists(CONTINUE_IMAGE):
		var tex := load(CONTINUE_IMAGE) as Texture2D
		if tex:
			var art := TextureRect.new()
			art.texture = tex
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_SCALE
			var w := 460.0
			var ar := float(tex.get_height()) / float(tex.get_width())
			art.custom_minimum_size = Vector2(w, w * ar)
			art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(art)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 52)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_label)

	GameManager.continue_offered.connect(_on_offer)
	GameManager.state_changed.connect(_on_state_changed)
	set_process(false)
	set_process_input(false)


func _on_offer(_cost: int) -> void:
	_active = true
	_time_left = PROMPT_TIME
	visible = true
	set_process(true)
	set_process_input(true)
	AudioManager.play_unlock()
	_refresh()


func _on_state_changed(new_state: int) -> void:
	if new_state != GameManager.GameState.REVIVE_OFFER:
		_dismiss()


func _process(delta: float) -> void:
	if not _active:
		return
	_time_left -= delta
	_refresh()
	if _time_left <= 0.0:
		_active = false
		_dismiss()
		GameManager.decline_continue()


func _refresh() -> void:
	if GameManager.free_continues > 0:
		_label.text = "CONTINUE?\n★ FREE REVIVE ★  (%d left)\n\nTAP  ·  %d" % [
			GameManager.free_continues, int(ceil(_time_left))
		]
	else:
		_label.text = "CONTINUE?\n%d COINS  (you have %d)\n\nTAP  ·  %d" % [
			GameManager.continue_cost, GameManager.coins, int(ceil(_time_left))
		]


func _input(event: InputEvent) -> void:
	if not _active:
		return
	var pressed: bool = (
		(event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventKey and event.pressed and not event.echo)
	)
	if pressed:
		_active = false
		_dismiss()
		GameManager.do_continue()


func _dismiss() -> void:
	visible = false
	set_process(false)
	set_process_input(false)
