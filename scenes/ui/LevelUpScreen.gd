## LevelUpScreen — the "level up, choose a weapon" moment.
##
## Vampire-Survivors' core hook: every level-up freezes the run and offers three
## gun cards to pick from. Picking grants/levels that gun (GunManager.add_gun),
## turning passive pickups into a meaningful choice and visible power growth.
##
## Drives off [signal GameManager.level_up]. Freezes via the scene-tree pause (this
## node is PROCESS_MODE_ALWAYS so its tweens still animate); restores the captured
## time-scale on resume so an in-flight Bullet Time isn't clobbered.

extends Control

## Card geometry.
const CARD_SIZE := Vector2(248, 340)
const CARD_COUNT := 3

var _queue: Array[int] = []
var _active: bool = false
var _resolving: bool = false
var _saved_time_scale: float = 1.0

var _root: Control = null
var _cards: Array = []
var _choice_ids: Array = []


func _ready() -> void:
	# Must keep ticking + animating while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	set_process_input(false)
	GameManager.level_up.connect(_on_level_up)
	GameManager.state_changed.connect(_on_state_changed)


func _on_level_up(level: int) -> void:
	_queue.append(level)
	if not _active:
		_advance()


## If the run ends (death/menu) while cards are queued, bail out cleanly so we
## never leave the tree paused under a game-over screen.
func _on_state_changed(new_state: int) -> void:
	if new_state != GameManager.GameState.PLAYING and (_active or not _queue.is_empty()):
		_queue.clear()
		_finish()


func _advance() -> void:
	if _queue.is_empty():
		_finish()
		return
	var level: int = _queue.pop_front()
	if not _active:
		_active = true
		_saved_time_scale = Engine.time_scale
		get_tree().paused = true
		set_process_input(true)
	AudioManager.play_unlock()
	_show_cards(level)


# --------------------------------------------------------------- build / show

func _show_cards(level: int) -> void:
	_resolving = false
	_clear_root()

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.0)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_root = dim
	_tween(dim, "color:a", 0.62, 0.22)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	dim.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var lv := Label.new()
	lv.text = "LEVEL %d" % level
	lv.add_theme_font_size_override("font_size", 34)
	lv.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lv)

	var heading := Label.new()
	heading.text = "CHOOSE A WEAPON"
	heading.add_theme_font_size_override("font_size", 66)
	heading.add_theme_color_override("font_color", Color(1, 0.97, 0.86))
	heading.add_theme_color_override("font_shadow_color", Color(0.95, 0.2, 0.45, 0.85))
	heading.add_theme_constant_override("shadow_offset_x", 4)
	heading.add_theme_constant_override("shadow_offset_y", 4)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heading)
	# Heading pops in from small.
	heading.pivot_offset = Vector2(360, 40)
	heading.scale = Vector2(0.7, 0.7)
	_tween(heading, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	vbox.add_child(row)

	_cards.clear()
	_choice_ids.clear()
	var choices := GunManager.roll_choices(CARD_COUNT)
	for i in choices.size():
		var c: Dictionary = choices[i]
		var card := _make_card(c, i + 1)
		row.add_child(card)
		_cards.append(card)
		_choice_ids.append(c["id"])
		# Staggered punch-in.
		card.pivot_offset = CARD_SIZE * 0.5
		card.scale = Vector2(0.6, 0.6)
		card.modulate.a = 0.0
		var delay := 0.06 + i * 0.07
		var t := _tween(card, "scale", Vector2.ONE, 0.34)
		t.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween(card, "modulate:a", 1.0, 0.2).set_delay(delay)

	var hint := Label.new()
	hint.text = "TAP A CARD"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


## Builds one tappable gun card themed to the gun's color.
func _make_card(choice: Dictionary, slot: int) -> Button:
	var id: String = choice["id"]
	var color: Color = GunManager.gun_color(id)
	var is_new: bool = choice["is_new"]
	var lvl: int = choice["level"]

	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_choose.bind(id))

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.11, 0.96)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = color
	sb.shadow_color = Color(color.r, color.g, color.b, 0.55)
	sb.shadow_size = 22
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", sb)

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 18)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pad)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	# Badge: NEW! or the level step.
	var badge := Label.new()
	if is_new:
		badge.text = "✦ NEW ✦"
		badge.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.3))
	else:
		badge.text = "LV %d → %d" % [lvl, lvl + 1]
		badge.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	badge.add_theme_font_size_override("font_size", 24)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(badge)

	# A glowing color slab as the gun's "portrait" (cheap, readable, on-theme).
	var slab := Panel.new()
	slab.custom_minimum_size = Vector2(0, 96)
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slab_sb := StyleBoxFlat.new()
	slab_sb.bg_color = color.lerp(Color(0.05, 0.05, 0.08), 0.25)
	slab_sb.set_corner_radius_all(12)
	slab_sb.shadow_color = Color(color.r, color.g, color.b, 0.5)
	slab_sb.shadow_size = 14
	slab.add_theme_stylebox_override("panel", slab_sb)
	col.add_child(slab)

	var glyph := Label.new()
	glyph.text = "►"
	glyph.add_theme_font_size_override("font_size", 54)
	glyph.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab.add_child(glyph)

	var name_lbl := Label.new()
	name_lbl.text = GunManager.gun_name(id)
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.45))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)

	var desc := Label.new()
	desc.text = GunManager.gun_desc(id)
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color(0.78, 0.85, 0.95))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD_SIZE.x - 40, 0)
	col.add_child(desc)

	var key := Label.new()
	key.text = "[%d]" % slot
	key.add_theme_font_size_override("font_size", 18)
	key.add_theme_color_override("font_color", Color(0.5, 0.6, 0.72))
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(key)

	return b


# --------------------------------------------------------------- selection

func _input(event: InputEvent) -> void:
	if not _active or _resolving:
		return
	# Number-key shortcuts (desktop / accessibility).
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		match event.keycode:
			KEY_1: idx = 0
			KEY_2: idx = 1
			KEY_3: idx = 2
		if idx >= 0 and idx < _choice_ids.size():
			_choose(_choice_ids[idx])
			get_viewport().set_input_as_handled()


func _choose(id: String) -> void:
	if _resolving:
		return
	_resolving = true

	var new_level := GunManager.add_gun(id)
	var color := GunManager.gun_color(id)
	AudioManager.play_pickup()

	# Punch the chosen card; dim the rest.
	var chosen_idx := _choice_ids.find(id)
	for i in _cards.size():
		var card: Control = _cards[i]
		if not is_instance_valid(card):
			continue
		if i == chosen_idx:
			var t := _tween(card, "scale", Vector2(1.16, 1.16), 0.18)
			t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_tween(card, "modulate:a", 0.15, 0.18)

	# Brief beat to register the pick, then resume / show the next queued level.
	var timer := get_tree().create_timer(0.34, true, false, true)
	timer.timeout.connect(_after_choice.bind(color, new_level))


func _after_choice(color: Color, _new_level: int) -> void:
	if _queue.is_empty():
		_finish()
		# Reward flash AFTER unpausing so it actually animates.
		Juice.flash(Color(color.r, color.g, color.b), 0.22, 0.5)
		Juice.add_trauma(0.32)
		Juice.kick_fov(8.0)
		Juice.haptic(35)
	else:
		_advance()


func _finish() -> void:
	if _active:
		Engine.time_scale = _saved_time_scale
		get_tree().paused = false
	_active = false
	_resolving = false
	set_process_input(false)
	_clear_root()


# --------------------------------------------------------------- helpers

func _clear_root() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_cards.clear()
	_choice_ids.clear()


## create_tween() that animates during the pause (real time, ignoring time_scale).
func _tween(obj: Object, property: String, final_val: Variant, dur: float) -> PropertyTweener:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	return tw.tween_property(obj, property, final_val, dur)
