## LevelUpScreen — the Vampire-Survivors "pick one of three" weapon choice.
##
## On a level-up, GameManager slows time to a crawl and emits [signal
## GameManager.level_up_offered]. This overlay snaps up three gun cards; tapping one
## adds/upgrades that gun and resumes play at full speed.
##
## NOTE on timing: while this screen is up, `Engine.time_scale` is ~0.08, so the
## `delta` passed to `_process` is scaled to a crawl too. All entrance animation is
## therefore driven by real wall-clock time (Time.get_ticks_msec), not `delta`, so
## the cards still snap in crisply no matter how slow the world is moving.

extends Control

## Per-card stagger and pop duration (real seconds).
const CARD_STAGGER := 0.07
const CARD_POP := 0.34

var _active := false
var _elapsed := 0.0
var _last_ms := 0
var _cards: Array[Control] = []
var _picked := false

var _dim: ColorRect = null
var _content: Control = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	set_process(false)
	set_process_input(false)
	GameManager.level_up_offered.connect(_on_offer)
	GameManager.level_up_resolved.connect(_teardown)


# ----------------------------------------------------------------- show / build

func _on_offer(choices: Array, level: int) -> void:
	_teardown()
	if choices.is_empty():
		return
	_active = true
	_picked = false
	_elapsed = 0.0
	_last_ms = Time.get_ticks_msec()
	visible = true
	set_process(true)
	set_process_input(true)

	# Dim + radial-ish darken so the cards own the screen.
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.05, 0.0)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow taps outside the cards
	add_child(_dim)

	_content = _build_content(choices, level)
	add_child(_content)

	# Punchy arrival feel.
	if AudioManager.has_method("play_unlock"):
		AudioManager.play_unlock()
	Juice.flash(Color(1.0, 0.92, 0.5), 0.22, 0.28)
	Juice.add_trauma(0.2)
	Juice.haptic(30)


func _build_content(choices: Array, level: int) -> Control:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var over := Label.new()
	over.text = "LEVEL  %d" % level
	over.add_theme_font_size_override("font_size", 26)
	over.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	over.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(over)

	var head := Label.new()
	head.text = "CHOOSE A WEAPON"
	head.add_theme_font_size_override("font_size", 58)
	head.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	head.add_theme_color_override("font_shadow_color", Color(0.95, 0.2, 0.45, 0.8))
	head.add_theme_constant_override("shadow_offset_x", 3)
	head.add_theme_constant_override("shadow_offset_y", 3)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	col.add_child(row)

	_cards.clear()
	for i in choices.size():
		var card := _make_card(choices[i])
		row.add_child(card)
		_cards.append(card)
	return root


## One weapon card — a styled Button carrying the gun's identity (color, name,
## blurb, level pips, and an add/upgrade badge).
func _make_card(choice: Dictionary) -> Button:
	var col: Color = choice.get("color", Color.WHITE)
	var lvl: int = int(choice.get("level", 0))
	var is_new: bool = bool(choice.get("is_new", true))
	var is_max: bool = bool(choice.get("is_max", false))

	var b := Button.new()
	b.custom_minimum_size = Vector2(228, 322)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _card_style(col, false))
	b.add_theme_stylebox_override("hover", _card_style(col, true))
	b.add_theme_stylebox_override("pressed", _card_style(col, true))
	b.add_theme_stylebox_override("focus", _card_style(col, false))
	b.pressed.connect(_pick.bind(String(choice.get("id", ""))))

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 18)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pad)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(v)

	# Badge: NEW / MAX / level-up arrow.
	var badge := Label.new()
	if is_new:
		badge.text = "✦ NEW ✦"
	elif is_max:
		badge.text = "MAX  LV %d" % lvl
	else:
		badge.text = "LV %d  →  %d" % [lvl, lvl + 1]
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.4))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(badge)

	# Big stylized icon chip in the gun's color.
	var icon := _make_icon(choice)
	v.add_child(icon)

	# Gun name.
	var name_l := Label.new()
	name_l.text = String(choice.get("name", "?"))
	name_l.add_theme_font_size_override("font_size", 30)
	name_l.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.55))
	name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)

	# Level pips: filled = owned, one bright = the level you'd gain.
	v.add_child(_make_pips(col, lvl, is_max))

	# Blurb.
	var blurb := Label.new()
	blurb.text = String(choice.get("blurb", ""))
	blurb.add_theme_font_size_override("font_size", 17)
	blurb.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(196, 0)
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(blurb)

	# Push the action hint to the bottom.
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(grow)

	var cta := Label.new()
	cta.text = "TAP TO ADD" if is_new else "TAP TO UPGRADE"
	cta.add_theme_font_size_override("font_size", 18)
	cta.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	cta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cta)

	# Start hidden for the staggered pop-in.
	b.modulate.a = 0.0
	b.scale = Vector2(0.7, 0.7)
	return b


## A rounded color chip with a pattern glyph, evoking the gun without loading a GLB.
func _make_icon(choice: Dictionary) -> Control:
	var col: Color = choice.get("color", Color.WHITE)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 92)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.22)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(col.r, col.g, col.b, 0.9)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)

	var glyph := Label.new()
	glyph.text = _glyph_for(int(choice.get("pattern", -1)))
	glyph.add_theme_font_size_override("font_size", 52)
	glyph.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.65))
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(glyph)
	return panel


## Picks a chunky glyph per firing pattern so each card reads at a glance.
func _glyph_for(pattern: int) -> String:
	match pattern:
		GunManager.Pattern.SINGLE: return "▸"
		GunManager.Pattern.BURST: return "⁝⁝"
		GunManager.Pattern.SHOTGUN: return "⋙"
		GunManager.Pattern.LASER: return "═"
		GunManager.Pattern.MORTAR: return "✺"
		GunManager.Pattern.SPREAD: return "⋔"
		GunManager.Pattern.MINIGUN: return "⁞⁞⁞"
		GunManager.Pattern.RAIL: return "➤"
		GunManager.Pattern.NET: return "▦"
	return "✦"


## A row of level pips (MAX_LEVEL dots): filled up to current level, plus a bright
## "gain" pip for the level this pick grants.
func _make_pips(col: Color, lvl: int, is_max: bool) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gain := lvl + (0 if is_max else 1)
	for i in GunManager.MAX_LEVEL:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < lvl:
			dot.color = col.lerp(Color.WHITE, 0.25)
		elif i < gain:
			dot.color = col.lerp(Color.WHITE, 0.7)  # the level you'd gain, brighter
		else:
			dot.color = Color(1, 1, 1, 0.16)
		row.add_child(dot)
	return row


func _card_style(col: Color, hot: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# Dark base tinted faintly toward the gun colour; brighter when hovered/pressed.
	var lift := 0.09 if hot else 0.05
	sb.bg_color = Color(0.06 + col.r * lift, 0.07 + col.g * lift, 0.11 + col.b * lift, 0.97 if hot else 0.92)
	sb.set_corner_radius_all(18)
	sb.border_color = col.lerp(Color.WHITE, 0.5) if hot else Color(col.r, col.g, col.b, 0.85)
	sb.set_border_width_all(4 if hot else 3)
	sb.shadow_color = Color(col.r, col.g, col.b, 0.5 if hot else 0.28)
	sb.shadow_size = 18 if hot else 10
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


# ----------------------------------------------------------------- animation

func _process(_delta: float) -> void:
	# Real wall-clock delta — the world's `delta` is crawling in slow-mo.
	var now := Time.get_ticks_msec()
	var rd := float(now - _last_ms) / 1000.0
	_last_ms = now
	_elapsed += rd

	# Fade the backdrop in over the first beat.
	if _dim:
		_dim.color.a = minf(0.6, _elapsed * 1.8)

	# Staggered pop-in per card.
	for i in _cards.size():
		var card := _cards[i]
		if not is_instance_valid(card):
			continue
		var t := clampf((_elapsed - i * CARD_STAGGER) / CARD_POP, 0.0, 1.0)
		var e := _ease_back(t)
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * lerpf(0.7, 1.0, e)
		card.modulate.a = clampf(t * 1.6, 0.0, 1.0)


## Overshoot ease-out (back) for a satisfying snap.
func _ease_back(t: float) -> float:
	var s := 1.70158
	var p := t - 1.0
	return p * p * ((s + 1.0) * p + s) + 1.0


# ----------------------------------------------------------------- pick / close

func _input(event: InputEvent) -> void:
	if not _active or _picked:
		return
	# Keyboard 1/2/3 as a convenience (desktop / testing).
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		match event.keycode:
			KEY_1: idx = 0
			KEY_2: idx = 1
			KEY_3: idx = 2
		if idx >= 0 and idx < _cards.size():
			var card := _cards[idx] as Button
			if card:
				card.emit_signal("pressed")


func _pick(gun_id: String) -> void:
	if _picked:
		return
	_picked = true
	var col := GunManager.gun_color(gun_id)
	if AudioManager.has_method("play_unlock"):
		AudioManager.play_unlock()
	Juice.flash(col.lerp(Color.WHITE, 0.3), 0.3, 0.32)
	Juice.add_trauma(0.35)
	Juice.kick_fov(12.0)
	Juice.haptic(45)
	# Resuming play restores time_scale and fires level_up_resolved → _teardown.
	GameManager.resolve_level_up(gun_id)


func _teardown() -> void:
	_active = false
	set_process(false)
	set_process_input(false)
	visible = false
	_cards.clear()
	if _dim and is_instance_valid(_dim):
		_dim.queue_free()
	_dim = null
	if _content and is_instance_valid(_content):
		_content.queue_free()
	_content = null
