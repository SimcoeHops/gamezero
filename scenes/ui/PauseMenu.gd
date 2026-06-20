## PauseMenu — gear button (iOS) / Esc (desktop) opens a settings overlay with
## music & SFX volume sliders and on/off toggles. Pauses the game while open.

extends Control

var _gear: Button = null
var _panel: Control = null
var _open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_gear()
	_build_panel()
	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: int) -> void:
	_gear.visible = (new_state == GameManager.GameState.PLAYING)
	if new_state != GameManager.GameState.PLAYING and _open:
		_close()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _open or GameManager.current_state == GameManager.GameState.PLAYING:
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _open:
		_close()
	elif GameManager.current_state == GameManager.GameState.PLAYING:
		_open_menu()


func _open_menu() -> void:
	_open = true
	_panel.visible = true
	AudioManager.play_ui()
	get_tree().paused = true


func _close() -> void:
	_open = false
	_panel.visible = false
	AudioManager.play_ui()
	get_tree().paused = false


# ---------------------------------------------------------------- UI build

func _build_gear() -> void:
	_gear = Button.new()
	_gear.text = "⚙"
	_gear.add_theme_font_size_override("font_size", 34)
	_gear.custom_minimum_size = Vector2(60, 60)
	_gear.position = Vector2(20, 20)
	_gear.focus_mode = Control.FOCUS_NONE
	_gear.visible = false
	_gear.pressed.connect(_toggle)
	add_child(_gear)


func _build_panel() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_panel = dim

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	dim.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.custom_minimum_size = Vector2(520, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_make_audio_row("MUSIC", Settings.music_volume, Settings.music_on,
		Callable(Settings, "set_music_volume"), Callable(Settings, "set_music_on")))
	box.add_child(_make_audio_row("SFX", Settings.sfx_volume, Settings.sfx_on,
		Callable(Settings, "set_sfx_volume"), Callable(Settings, "set_sfx_on")))

	var resume := Button.new()
	resume.text = "RESUME"
	resume.custom_minimum_size = Vector2(0, 70)
	resume.add_theme_font_size_override("font_size", 36)
	resume.pressed.connect(_close)
	box.add_child(resume)

	var quit := Button.new()
	quit.text = "QUIT TO MENU"
	quit.custom_minimum_size = Vector2(0, 56)
	quit.add_theme_font_size_override("font_size", 26)
	quit.pressed.connect(_quit_to_menu)
	box.add_child(quit)


func _make_audio_row(label_text: String, vol: float, on: bool, vol_cb: Callable, on_cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(110, 0)
	name_label.add_theme_font_size_override("font_size", 30)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = vol
	slider.custom_minimum_size = Vector2(280, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float): vol_cb.call(v))
	row.add_child(slider)

	var toggle := CheckButton.new()
	toggle.button_pressed = on
	toggle.toggled.connect(func(p: bool): on_cb.call(p))
	row.add_child(toggle)

	return row


func _quit_to_menu() -> void:
	get_tree().paused = false
	_open = false
	_panel.visible = false
	GameManager.go_to_menu()
	get_tree().reload_current_scene()
