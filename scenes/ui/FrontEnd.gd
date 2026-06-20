## FrontEnd — title screen and character select.
##
## Flow: Title (NEW GAME) → Character Select → GameManager.start_game().
## Hides itself once play begins; only shown on a fresh launch (restarts skip
## straight back into the run).

extends Control

const PROT := "res://assets/kenney_animated-characters-protagonists/Skins/"
const RETRO := "res://assets/kenney_animated-characters-retro/Skins/"
const CHAR_MODEL := "res://assets/kenney_animated-characters-protagonists/Model/characterMedium.fbx"
const IDLE_ANIM := "res://assets/kenney_animated-characters-protagonists/Animations/idle.fbx"

const CHARACTERS := [
	{"name": "SKATER", "skin": PROT + "skaterMaleA.png"},
	{"name": "SKATER F", "skin": PROT + "skaterFemaleA.png"},
	{"name": "CRIMINAL", "skin": PROT + "criminalMaleA.png"},
	{"name": "CYBORG", "skin": PROT + "cyborgFemaleA.png"},
	{"name": "HUMAN", "skin": RETRO + "humanMaleA.png"},
	{"name": "HUMAN F", "skin": RETRO + "humanFemaleA.png"},
	{"name": "ZOMBIE", "skin": RETRO + "zombieMaleA.png"},
	{"name": "ZOMBIE F", "skin": RETRO + "zombieFemaleA.png"},
]

var _root: Control = null


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.state_changed.connect(_on_state_changed)


func begin() -> void:
	_show_title()


func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.PLAYING:
		_clear()


func _clear() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()
	_root = null


func _new_root() -> VBoxContainer:
	_clear()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_root = dim

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	dim.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	return vbox


func _show_title() -> void:
	var vbox := _new_root()

	var title := Label.new()
	title.text = "CRASHMAN"
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	title.add_theme_color_override("font_shadow_color", Color(0.95, 0.2, 0.45, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stats := Label.new()
	stats.text = "BEST  %d        ◎ %d" % [GameManager.high_score, GameManager.coins]
	stats.add_theme_font_size_override("font_size", 30)
	stats.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var play := Button.new()
	play.text = "NEW GAME"
	play.custom_minimum_size = Vector2(320, 80)
	play.add_theme_font_size_override("font_size", 44)
	play.pressed.connect(_show_character_select)
	vbox.add_child(play)

	var shop := Button.new()
	shop.text = "UPGRADES  ◎ %d" % GameManager.coins
	shop.custom_minimum_size = Vector2(320, 60)
	shop.add_theme_font_size_override("font_size", 30)
	shop.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	shop.pressed.connect(_show_shop)
	vbox.add_child(shop)

	var settings_btn := Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.custom_minimum_size = Vector2(320, 56)
	settings_btn.add_theme_font_size_override("font_size", 28)
	settings_btn.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	settings_btn.pressed.connect(_show_settings)
	vbox.add_child(settings_btn)


## The meta-progression shop: spend persisted coins on permanent upgrades that
## apply at the start of every run. Rebuilt wholesale on each purchase so levels,
## costs and the coin balance always reflect the latest state.
func _show_shop() -> void:
	AudioManager.play_ui()
	var vbox := _new_root()

	var heading := Label.new()
	heading.text = "UPGRADE SHOP"
	heading.add_theme_font_size_override("font_size", 56)
	heading.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heading)

	var coin_lbl := Label.new()
	coin_lbl.text = "◎ %d  COINS" % GameManager.coins
	coin_lbl.add_theme_font_size_override("font_size", 34)
	coin_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(coin_lbl)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	vbox.add_child(list)
	for id in GameManager.UPGRADES.keys():
		list.add_child(_make_upgrade_row(id))

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220, 56)
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(_show_title)
	vbox.add_child(back)


## One upgrade row: name + description + level pips on the left, a BUY (cost) /
## MAX button on the right, framed in the upgrade's accent colour.
func _make_upgrade_row(id: String) -> Control:
	var u: Dictionary = GameManager.UPGRADES[id]
	var lvl := GameManager.upgrade_level(id)
	var maxl := GameManager.upgrade_max(id)
	var color: Color = u["color"]

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.14, 0.92)
	sb.set_border_width_all(2)
	sb.border_color = Color(color.r, color.g, color.b, 0.55)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.custom_minimum_size = Vector2(660, 0)
	panel.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = u["name"]
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", color)
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = u["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 18)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
	info.add_child(desc_lbl)

	var pips := ""
	for i in maxl:
		pips += "●" if i < lvl else "○"
	var pip_lbl := Label.new()
	pip_lbl.text = "%s   LV %d/%d" % [pips, lvl, maxl]
	pip_lbl.add_theme_font_size_override("font_size", 18)
	pip_lbl.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.9))
	info.add_child(pip_lbl)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(160, 66)
	buy.add_theme_font_size_override("font_size", 26)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if GameManager.upgrade_is_maxed(id):
		buy.text = "MAX"
		buy.disabled = true
	else:
		buy.text = "◎ %d" % GameManager.upgrade_cost(id)
		buy.disabled = not GameManager.can_buy_upgrade(id)
		buy.pressed.connect(_buy_upgrade.bind(id))
	hbox.add_child(buy)

	return panel


func _buy_upgrade(id: String) -> void:
	if GameManager.buy_upgrade(id):
		AudioManager.play_unlock()
	else:
		AudioManager.play_ui()
	_show_shop()  # rebuild to reflect the new level, cost and balance


func _show_character_select() -> void:
	AudioManager.play_ui()
	var vbox := _new_root()

	var heading := Label.new()
	heading.text = "CHOOSE YOUR RUNNER"
	heading.add_theme_font_size_override("font_size", 56)
	heading.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	vbox.add_child(grid)

	for c in CHARACTERS:
		grid.add_child(_make_character_button(c))


func _make_character_button(c: Dictionary) -> Button:
	var skin: String = c["skin"]
	var b := Button.new()
	b.custom_minimum_size = Vector2(168, 220)
	b.pressed.connect(_choose.bind(skin))

	# Live 3D portrait so cards show the actual runner, not the raw UV-atlas texture.
	var preview := _make_skin_preview(skin)
	if preview:
		preview.set_anchors_preset(Control.PRESET_FULL_RECT)
		preview.offset_top = 6
		preview.offset_bottom = -34
		preview.offset_left = 6
		preview.offset_right = -6
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(preview)

	var name_lbl := Label.new()
	name_lbl.text = c["name"]
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top = -30
	name_lbl.offset_bottom = -4
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_lbl)
	return b


## Applies the idle animation to [param ch] and freezes it at [param t] seconds so
## the runner stands in a natural, relaxed pose. No-op if the idle clip is missing.
func _pose_idle(sv: SubViewport, ch: Node3D, t: float) -> void:
	if not ResourceLoader.exists(IDLE_ANIM):
		return
	var src: Node = load(IDLE_ANIM).instantiate()
	var imp := src.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if imp and imp.has_animation("Root|Idle"):
		var ap := AnimationPlayer.new()
		sv.add_child(ap)
		ap.root_node = ap.get_path_to(ch)
		var lib := AnimationLibrary.new()
		lib.add_animation("idle", imp.get_animation("Root|Idle"))
		ap.add_animation_library("", lib)
		ap.play("idle")
		ap.advance(t)
		ap.pause()
	src.queue_free()


## Builds a small SubViewport that renders the character model wearing [param skin]
## as a front-facing portrait, returned as a TextureRect ready to drop on a card.
## Falls back to null if the model can't be loaded.
func _make_skin_preview(skin: String) -> TextureRect:
	if not ResourceLoader.exists(CHAR_MODEL):
		return null
	var char_scene := load(CHAR_MODEL) as PackedScene
	if char_scene == null:
		return null

	var sv := SubViewport.new()
	sv.size = Vector2i(220, 300)
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_2X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var ch := char_scene.instantiate() as Node3D
	sv.add_child(ch)
	# Apply the chosen skin to the body mesh (same node the game skins).
	var mesh_node := ch.get_node_or_null("Root/Skeleton3D/characterMedium") as MeshInstance3D
	if mesh_node and ResourceLoader.exists(skin):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(skin)
		mat.roughness = 0.85
		mesh_node.set_surface_override_material(0, mat)

	# Pose the runner in a relaxed idle stance (arms down at the sides) instead of
	# the rigid bind T-pose, frozen at a per-character offset so each card stands a
	# little differently. A tiny per-character yaw adds variety while still facing
	# the camera. The idle animation orients the model toward +Z, so the camera
	# sits on the +Z side (below) to capture the face.
	var variant := absi(skin.hash())
	_pose_idle(sv, ch, fmod(float(variant % 1000) * 0.0011, 1.0667))
	ch.rotation_degrees.y = float(variant % 19) - 9.0  # ~ -9°..+9°

	# Key light from the front so the face reads, not a silhouette.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-22.0, 12.0, 0.0)
	light.light_energy = 1.6
	sv.add_child(light)

	# Camera framing the runner head-to-toe with headroom. The skinned mesh reports
	# a near-empty get_aabb() and the skeleton scales the model to ~3 m tall, so the
	# distance/height are hand-tuned (verified by rendering the preview). Camera is
	# on the +Z side because the idle pose faces +Z.
	var fov := 34.0
	var center := Vector3(0.0, 1.55, 0.0)
	var dist := 8.2
	var cam := Camera3D.new()
	cam.fov = fov
	cam.position = center + Vector3(0.0, 0.0, dist)
	cam.look_at_from_position(cam.position, center, Vector3.UP)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.72)
	env.ambient_light_energy = 1.6
	cam.environment = env
	sv.add_child(cam)

	var tr := TextureRect.new()
	tr.texture = sv.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The SubViewport must live in the tree to render — park it inside the TextureRect.
	tr.add_child(sv)
	return tr


func _choose(skin: String) -> void:
	Settings.set_skin(skin)
	AudioManager.play_unlock()
	_clear()
	GameManager.start_game()


# ----------------------------------------------------------------- settings
## Full options screen: audio (music/sfx) + accessibility (shake, haptics,
## reduce-flashes). The shake slider previews live — the world behind the dim
## actually shakes as you drag, since Main keeps compositing the camera in MENU.
func _show_settings() -> void:
	AudioManager.play_ui()
	var vbox := _new_root()

	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 56)
	heading.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heading)

	vbox.add_child(_audio_row("MUSIC", Settings.music_volume, Settings.music_on,
		Callable(Settings, "set_music_volume"), Callable(Settings, "set_music_on")))
	vbox.add_child(_audio_row("SFX", Settings.sfx_volume, Settings.sfx_on,
		Callable(Settings, "set_sfx_volume"), Callable(Settings, "set_sfx_on")))

	var sect := Label.new()
	sect.text = "ACCESSIBILITY"
	sect.add_theme_font_size_override("font_size", 22)
	sect.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	sect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sect)

	vbox.add_child(_shake_row())
	vbox.add_child(_toggle_row("HAPTICS", Settings.haptics_on,
		Callable(Settings, "set_haptics_on")))
	vbox.add_child(_toggle_row("REDUCE FLASHES", Settings.reduce_flashes,
		Callable(Settings, "set_reduce_flashes")))

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220, 56)
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(_show_title)
	vbox.add_child(back)


## A combined "label + volume slider + on/off" row (matches the pause menu).
func _audio_row(label_text: String, vol: float, on: bool, vol_cb: Callable, on_cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(560, 0)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(190, 0)
	name_label.add_theme_font_size_override("font_size", 28)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = vol
	slider.custom_minimum_size = Vector2(240, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float): vol_cb.call(v))
	row.add_child(slider)

	var toggle := CheckButton.new()
	toggle.button_pressed = on
	toggle.toggled.connect(func(p: bool): on_cb.call(p))
	row.add_child(toggle)
	return row


## The screen-shake intensity row: a 0–100% slider with a live readout that also
## fires a little trauma each step so you feel the strength you're choosing.
func _shake_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(560, 0)

	var name_label := Label.new()
	name_label.text = "SCREEN SHAKE"
	name_label.custom_minimum_size = Vector2(190, 0)
	name_label.add_theme_font_size_override("font_size", 28)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.shake_scale
	slider.custom_minimum_size = Vector2(220, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var pct := Label.new()
	pct.text = "%d%%" % roundi(Settings.shake_scale * 100.0)
	pct.custom_minimum_size = Vector2(70, 0)
	pct.add_theme_font_size_override("font_size", 26)
	pct.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)

	slider.value_changed.connect(func(v: float):
		Settings.set_shake_scale(v)
		pct.text = "%d%%" % roundi(v * 100.0)
		Juice.add_trauma(0.5))  # live preview — scaled by the new value itself
	return row


## A label + CheckButton toggle row for a boolean accessibility option.
func _toggle_row(label_text: String, on: bool, setter: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(560, 0)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 28)
	row.add_child(name_label)

	var toggle := CheckButton.new()
	toggle.button_pressed = on
	toggle.toggled.connect(func(p: bool):
		setter.call(p)
		AudioManager.play_ui())
	row.add_child(toggle)
	return row
