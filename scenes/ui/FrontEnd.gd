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
