## HUD — in-game heads-up display.
##
## Score (animated roll-up), speed, combo multiplier, ability-unlock icons,
## milestone banners, active power-ups, floating near-miss popups, and the
## full-screen speed-line / vignette overlay.

extends Control

## The root padding container the safe-area insets are applied to.
@onready var _margin: MarginContainer = $MarginContainer
@onready var _score_label: Label = $MarginContainer/TopBar/ScoreLabel
@onready var _speed_label: Label = $MarginContainer/TopBar/SpeedLabel

## Minimum padding (in viewport units) kept on every edge, even with no notch.
const BASE_PADDING := 20
@onready var _milestone_banner: Label = $MilestoneBanner
@onready var _icon_jump: Control = $MarginContainer/AbilityBar/AbilityContainer/IconJump
@onready var _icon_bullet_time: Control = $MarginContainer/AbilityBar/AbilityContainer/IconBulletTime
@onready var _icon_weapon: Control = $MarginContainer/AbilityBar/AbilityContainer/IconWeapon

var _ability_icons: Dictionary = {}

# Runtime-created elements.
var _powerup_rt: RichTextLabel = null
var _last_powerup_count: int = 0

# Greed / near-miss combo meter (chunky ×N + draining "heat" bar).
var _combo_box: VBoxContainer = null
var _combo_over: Label = null
var _combo_num: Label = null
var _combo_heat_bg: Panel = null
var _combo_heat_fill: Panel = null
var _combo_heat_fill_sb: StyleBoxFlat = null
var _combo_hide_tw: Tween = null
const COMBO_BAR_SIZE := Vector2(212.0, 12.0)

var _coin_label: Label = null
var _fx_rect: ColorRect = null
var _fx_mat: ShaderMaterial = null

# XP / level bar.
var _xp_bg: Panel = null
var _xp_fill: Panel = null
var _level_label: Label = null
const XP_BAR_SIZE := Vector2(420.0, 12.0)
var _xp_display: float = 0.0

var _display_score: float = 0.0
## Smoothed flow-state heat driving the warm edge-glow shader uniform.
var _flow_display: float = 0.0


func _ready() -> void:
	_ability_icons = {
		&"jump": _icon_jump,
		&"bullet_time": _icon_bullet_time,
		&"weapon": _icon_weapon,
	}
	for icon in _ability_icons.values():
		if icon:
			icon.modulate = Color(0.3, 0.3, 0.3, 0.6)

	GameManager.score_updated.connect(_on_score_updated)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.coin_collected.connect(_on_coin_collected)
	GameManager.biome_changed.connect(_on_biome_changed)
	ProgressionManager.ability_unlocked.connect(_on_ability_unlocked)
	ProgressionManager.milestone_reached.connect(_on_milestone_reached)
	ProgressionManager.near_miss.connect(_on_near_miss)
	PowerUpManager.powerups_changed.connect(_update_powerups)
	GunManager.guns_changed.connect(_update_powerups)
	GunManager.gun_redirected.connect(_on_gun_redirected)
	PowerUpManager.star_started.connect(_on_star_started)
	PowerUpManager.star_ended.connect(_on_star_ended)
	PowerUpManager.pickup_announced.connect(_on_pickup_announced)
	GameManager.level_up.connect(_on_level_up)

	if _milestone_banner:
		_milestone_banner.visible = false
	if _score_label:
		_score_label.pivot_offset = _score_label.size * 0.5

	# Keep the HUD clear of the iPhone notch / Dynamic Island / home indicator.
	_apply_safe_area()
	# Re-apply if the window resizes or the reported safe area changes (iOS often
	# reports the real safe area a frame or two after launch / on rotation).
	get_tree().get_root().size_changed.connect(_apply_safe_area)

	_build_screen_fx()
	_build_star_banner()
	_build_powerup_label()
	_build_combo_meter()
	_build_coin_label()
	_build_xp_bar()
	_update_powerups()
	_update_speed_display()


## Insets the root MarginContainer by the OS safe area so the HUD never sits
## under the notch / Dynamic Island / home indicator. The safe area is reported
## in real window pixels, while the HUD lives in the (stretched) 2D viewport, so
## the pixel insets are converted to viewport units before being applied. We
## inset all four edges — in landscape the notch/Dynamic Island sits on a *side*,
## not just the top/bottom — and never go below the original 20px padding.
func _apply_safe_area() -> void:
	if _margin == null:
		return

	var safe := DisplayServer.get_display_safe_area()  # Rect2i, window/screen px
	var win := DisplayServer.window_get_size()          # Vector2i, window px

	# Per-edge insets in real window pixels (clamped to >= 0).
	var left_px := maxi(safe.position.x, 0)
	var top_px := maxi(safe.position.y, 0)
	var right_px := maxi(win.x - (safe.position.x + safe.size.x), 0)
	var bottom_px := maxi(win.y - (safe.position.y + safe.size.y), 0)

	# Convert window px -> viewport units. With "canvas_items" stretch the 2D
	# canvas can be a different size than the OS window, so scale by that ratio.
	var vp := get_viewport().get_visible_rect().size
	var sx := (vp.x / float(win.x)) if win.x > 0 else 1.0
	var sy := (vp.y / float(win.y)) if win.y > 0 else 1.0

	var ml := maxi(BASE_PADDING, int(round(left_px * sx)))
	var mr := maxi(BASE_PADDING, int(round(right_px * sx)))
	var mt := maxi(BASE_PADDING, int(round(top_px * sy)))
	var mb := maxi(BASE_PADDING, int(round(bottom_px * sy)))

	_margin.add_theme_constant_override("margin_left", ml)
	_margin.add_theme_constant_override("margin_right", mr)
	_margin.add_theme_constant_override("margin_top", mt)
	_margin.add_theme_constant_override("margin_bottom", mb)


func _process(delta: float) -> void:
	# Animated score roll-up.
	if _score_label:
		var goal := float(GameManager.score)
		if not is_equal_approx(_display_score, goal):
			var rate := (absf(goal - _display_score) * 8.0 + 30.0) * delta
			_display_score = move_toward(_display_score, goal, rate)
			_score_label.text = str(int(round(_display_score)))

	if GameManager.current_state == GameManager.GameState.PLAYING:
		_update_speed_display()
		if _fx_mat:
			var t := clampf((GameManager.highway_speed - 25.0) / 60.0, 0.0, 1.0)
			_fx_mat.set_shader_parameter("speed_intensity", t)
			_fx_mat.set_shader_parameter("impact_pulse", Juice.impact_pulse())
			# Ease the warm flow glow toward the live heat (fast cool on a crash).
			_flow_display = move_toward(_flow_display, GameManager.flow_heat,
				maxf(absf(GameManager.flow_heat - _flow_display) * 3.0, 0.4) * delta)
			_fx_mat.set_shader_parameter("flow_heat", _flow_display)
		# Refresh every frame so the per-power-up countdowns tick and the
		# about-to-expire warning blinks.
		_refresh_powerups()
		_update_star_banner()
		_update_xp_bar(delta)
		_update_combo_meter(delta)


# --------------------------------------------------------------- score / speed

func _on_score_updated(_score: int) -> void:
	# Punch the score label on every gain.
	if _score_label:
		var tw := create_tween()
		_score_label.scale = Vector2(1.18, 1.18)
		tw.tween_property(_score_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_speed_display() -> void:
	if _speed_label:
		_speed_label.text = "%.0f km/h" % (GameManager.highway_speed * 3.6)


# --------------------------------------------------------------- combo

## The GREED meter — a chunky escalating "×N" with a draining "heat" bar, the
## reward for greedily threading traffic instead of playing safe. The number grows
## and shifts hot-orange → gold → white-hot as the near-miss combo climbs; the bar
## drains over COMBO_WINDOW and the whole thing cools back to ×1 the instant it
## empties (or on a hit). Centered in the upper third, clear of the road action.
func _build_combo_meter() -> void:
	_combo_box = VBoxContainer.new()
	_combo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_combo_box.add_theme_constant_override("separation", 2)
	_combo_box.anchor_left = 0.0
	_combo_box.anchor_right = 1.0
	_combo_box.anchor_top = 0.155
	_combo_box.anchor_bottom = 0.155
	_combo_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_combo_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.visible = false
	add_child(_combo_box)

	_combo_over = Label.new()
	_combo_over.text = "GREED"
	_combo_over.add_theme_font_size_override("font_size", 19)
	_combo_over.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	_combo_over.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_combo_over.add_theme_constant_override("shadow_offset_x", 1)
	_combo_over.add_theme_constant_override("shadow_offset_y", 1)
	_combo_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.add_child(_combo_over)

	_combo_num = Label.new()
	_combo_num.text = "×2"
	_combo_num.add_theme_font_size_override("font_size", 78)
	_combo_num.add_theme_color_override("font_color", Color(1.0, 0.5, 0.15))
	_combo_num.add_theme_color_override("font_outline_color", Color(0.15, 0.03, 0.0, 0.9))
	_combo_num.add_theme_constant_override("outline_size", 8)
	_combo_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.add_child(_combo_num)

	# Heat bar: a fixed-width rounded track, centered, with a draining fill.
	_combo_heat_bg = Panel.new()
	_combo_heat_bg.custom_minimum_size = COMBO_BAR_SIZE
	_combo_heat_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_combo_heat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.05, 0.03, 0.02, 0.7)
	bg_sb.set_corner_radius_all(6)
	bg_sb.set_border_width_all(1)
	bg_sb.border_color = Color(1.0, 0.6, 0.3, 0.45)
	_combo_heat_bg.add_theme_stylebox_override("panel", bg_sb)
	_combo_box.add_child(_combo_heat_bg)

	_combo_heat_fill = Panel.new()
	_combo_heat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_heat_fill.position = Vector2(2, 2)
	_combo_heat_fill.size = Vector2(COMBO_BAR_SIZE.x - 4.0, COMBO_BAR_SIZE.y - 4.0)
	_combo_heat_fill_sb = StyleBoxFlat.new()
	_combo_heat_fill_sb.bg_color = Color(1.0, 0.55, 0.15, 0.95)
	_combo_heat_fill_sb.set_corner_radius_all(5)
	_combo_heat_fill.add_theme_stylebox_override("panel", _combo_heat_fill_sb)
	_combo_heat_bg.add_child(_combo_heat_fill)


## Tier color for a combo value: hot orange at ×2 → gold mid → white-hot at MAX.
func _combo_color(c: int) -> Color:
	var span := maxi(GameManager.MAX_COMBO - 2, 1)
	var t := clampf(float(c - 2) / float(span), 0.0, 1.0)
	if t < 0.5:
		return Color(1.0, 0.42, 0.12).lerp(Color(1.0, 0.82, 0.2), t / 0.5)
	return Color(1.0, 0.82, 0.2).lerp(Color(1.0, 1.0, 1.0), (t - 0.5) / 0.5)


func _on_combo_changed(combo: int) -> void:
	if _combo_box == null:
		return
	if combo > 1:
		if _combo_hide_tw and _combo_hide_tw.is_valid():
			_combo_hide_tw.kill()
		_combo_box.visible = true
		_combo_box.modulate.a = 1.0
		_combo_num.text = "×%d" % combo
		var col := _combo_color(combo)
		_combo_num.add_theme_color_override("font_color", col)
		_combo_over.add_theme_color_override("font_color", col.lerp(Color(1, 0.7, 0.4), 0.4))
		_combo_heat_fill_sb.bg_color = Color(col.r, col.g, col.b, 0.95)
		# Punch the number bigger at higher tiers so escalation reads physically.
		_combo_num.pivot_offset = _combo_num.size * 0.5
		var punch := 1.32 + 0.05 * float(combo)
		var tw := create_tween()
		_combo_num.scale = Vector2(punch, punch)
		tw.tween_property(_combo_num, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_hide_combo_meter()


## Cool-down animation when the combo breaks (timer drained or hit) — shrink + fade.
func _hide_combo_meter() -> void:
	if _combo_box == null or not _combo_box.visible:
		return
	if _combo_hide_tw and _combo_hide_tw.is_valid():
		_combo_hide_tw.kill()
	_combo_box.pivot_offset = _combo_box.size * 0.5
	_combo_hide_tw = create_tween()
	_combo_hide_tw.tween_property(_combo_box, "modulate:a", 0.0, 0.22)
	_combo_hide_tw.parallel().tween_property(_combo_num, "scale", Vector2(0.7, 0.7), 0.22).set_ease(Tween.EASE_IN)
	_combo_hide_tw.tween_callback(func(): _combo_box.visible = false)


## Drains the heat bar and breathes the number each frame while a combo is live.
func _update_combo_meter(_delta: float) -> void:
	if _combo_box == null or not _combo_box.visible:
		return
	var frac := GameManager.combo_fraction()
	_combo_heat_fill.size.x = (COMBO_BAR_SIZE.x - 4.0) * frac
	# As the heat runs out, pulse the whole meter with rising urgency so the
	# player feels the window closing — a "use it or lose it" cue.
	if frac <= 0.34:
		var urgency := 1.0 - frac / 0.34
		var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() * (0.012 + 0.02 * urgency))
		_combo_box.modulate.a = 0.55 + 0.45 * blink
		var s := 1.0 + 0.06 * urgency * blink
		_combo_num.pivot_offset = _combo_num.size * 0.5
		# Don't fight an active punch tween (scale > 1.05).
		if _combo_num.scale.x <= 1.06:
			_combo_num.scale = Vector2(s, s)
	else:
		_combo_box.modulate.a = 1.0


# --------------------------------------------------------------- popups

func _on_near_miss() -> void:
	_show_popup("NEAR MISS!", Color(0.6, 0.95, 1.0), 0.42)


## Comic-book explosion words when the player stomps a car.
const STOMP_WORDS := ["KABOOM!", "BAM!", "POW!", "SMASH!", "WHAM!", "BOOM!", "CRUNCH!", "KAPOW!"]

func show_stomp_boom() -> void:
	var word: String = STOMP_WORDS[randi() % STOMP_WORDS.size()]
	var col := Color(1.0, 0.7, 0.15).lerp(Color(1.0, 0.3, 0.2), randf())
	_show_popup(word, col, 0.4, 64)


## Quick ~0.8s flash of the just-collected power-up's name across the BOTTOM of
## the screen (clear of the road/action up top) — a second, easier-to-catch layer
## of feedback when the gate's own label whips by too fast to read.
func _on_pickup_announced(label_text: String, color: Color) -> void:
	if label_text == "":
		return
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 42)
	l.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.35))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Pinned across the bottom edge, lifted clear of the home indicator.
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_top = -108.0
	l.offset_bottom = -56.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)

	# Flash: snap in (with a little pop), hold, fade out — ~0.8s total.
	l.modulate.a = 0.0
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.18)
	tw.tween_callback(l.queue_free)


func _show_popup(text: String, color: Color, y_frac: float, font_size: int = 40) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(440, 60)
	l.pivot_offset = Vector2(220, 30)
	var vp := get_viewport_rect().size
	l.position = Vector2(vp.x * 0.5 - 220 + randf_range(-40, 40), vp.y * y_frac)
	add_child(l)

	var rise := create_tween()
	rise.tween_property(l, "position:y", l.position.y - 90.0, 0.8).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	rise.tween_callback(l.queue_free)

	var pop := create_tween()
	l.scale = Vector2(0.6, 0.6)
	pop.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --------------------------------------------------------------- abilities

func _on_ability_unlocked(ability_name: StringName) -> void:
	var icon: Control = _ability_icons.get(ability_name)
	if icon:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(icon, "modulate", Color.WHITE, 0.5)
		tween.parallel().tween_property(icon, "scale", Vector2(1.3, 1.3), 0.3)
		tween.tween_property(icon, "scale", Vector2.ONE, 0.2)


func _on_milestone_reached(dodge_count: int) -> void:
	if not _milestone_banner:
		return
	var text := ""
	match dodge_count:
		10: text = "JUMP UNLOCKED!"
		25: text = "BULLET TIME UNLOCKED!"
		50: text = "WEAPON UNLOCKED!"
		_: text = "MILESTONE: %d DODGES!" % dodge_count
	_milestone_banner.text = text
	_milestone_banner.visible = true

	var tween := create_tween()
	_milestone_banner.position.y = -60
	_milestone_banner.modulate.a = 0.0
	tween.tween_property(_milestone_banner, "position:y", 80.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(_milestone_banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(_milestone_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): _milestone_banner.visible = false)


# --------------------------------------------------------------- power-ups

func _build_powerup_label() -> void:
	# Vertical list pinned to the LEFT edge (was a single horizontal line that ran
	# straight across the screen into the player's view of the road). Smaller text,
	# one power-up per row, each with its own 30s countdown.
	_powerup_rt = RichTextLabel.new()
	_powerup_rt.bbcode_enabled = true
	_powerup_rt.fit_content = true
	_powerup_rt.scroll_active = false
	_powerup_rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_powerup_rt.custom_minimum_size = Vector2(176, 0)
	_powerup_rt.add_theme_font_size_override("normal_font_size", 21)
	_powerup_rt.add_theme_color_override("default_color", Color(0.85, 0.97, 1.0))
	# Rounded translucent panel so the active power-ups read clearly over the road.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.10, 0.55)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	sb.border_color = Color(0.5, 0.85, 1.0, 0.45)
	sb.set_border_width_all(2)
	_powerup_rt.add_theme_stylebox_override("normal", sb)
	_powerup_rt.position = Vector2(20, 104)
	_powerup_rt.visible = false
	add_child(_powerup_rt)


## Signal handler — pops the panel when the set of power-ups changes.
func _update_powerups() -> void:
	_refresh_powerups()
	var count := GunManager.owned.size() + (1 if PowerUpManager.speed_stacks > 0 else 0) \
		+ (1 if PowerUpManager.is_invincible() else 0) + (1 if PowerUpManager.is_magnet_active() else 0)
	if _powerup_rt and _powerup_rt.visible and count != _last_powerup_count:
		_last_powerup_count = count
		_powerup_rt.pivot_offset = Vector2.ZERO
		var tw := create_tween()
		_powerup_rt.scale = Vector2(1.15, 1.15)
		tw.tween_property(_powerup_rt, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The weapon-slot cap redirected an over-cap NEW pickup into deepening an owned
## gun. Without a cue the player just sees "the new gun didn't appear" and reads it
## as a dropped pickup. So: a brief toast above the gun panel naming what leveled,
## plus a punch on the panel to pull the eye to the row that grew.
func _on_gun_redirected(target_id: String, new_level: int) -> void:
	var nm := GunManager.gun_name(target_id)
	var col := GunManager.gun_color(target_id)
	var l := Label.new()
	l.text = "MAX GUNS · %s ▸ LV%d" % [nm, new_level]
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.4))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	# Pinned just above the left-edge power-up/gun panel (which sits at y=104).
	l.position = Vector2(22, 78)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.modulate.a = 0.0
	l.pivot_offset = Vector2.ZERO
	l.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.95)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(l, "position:y", l.position.y - 18.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
	# Punch the gun panel so the eye lands on the loadout that just deepened.
	if _powerup_rt and _powerup_rt.visible:
		_powerup_rt.pivot_offset = Vector2.ZERO
		var ptw := create_tween()
		_powerup_rt.scale = Vector2(1.16, 1.16)
		ptw.tween_property(_powerup_rt, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A light haptic tick so the redirect still registers as a reward, not a miss.
	Juice.haptic(18)


## Rebuilds the vertical power-up list with live countdowns (called every frame).
func _refresh_powerups() -> void:
	if _powerup_rt == null:
		return
	var lines: Array[String] = []
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	# Weapon-slot count, shown once the loadout is full so the cap is legible (a new
	# gun pickup now deepens an owned gun instead of opening a 7th slot).
	if GunManager.owned.size() >= GunManager.MAX_GUNS:
		lines.append("[color=#ffcf8a]▣ %d/%d GUNS[/color]" % [GunManager.owned.size(), GunManager.MAX_GUNS])
	# Owned auto-fire guns lead the list — they're the core of the loadout.
	for s in GunManager.status():
		var nm: String = s["name"]
		if int(s["level"]) > 1:
			nm += " ·%d" % int(s["level"])
		lines.append(_powerup_row(nm, float(s["time_left"]), blink))
	if PowerUpManager.speed_stacks > 0:
		lines.append(_powerup_row("SPEED x%d" % PowerUpManager.speed_stacks, PowerUpManager.speed_time_left(), blink))
	if PowerUpManager.is_invincible():
		lines.append(_powerup_row("STAR", PowerUpManager.star_time_left(), blink))
	if PowerUpManager.is_magnet_active():
		lines.append(_powerup_row("MAGNET", PowerUpManager.magnet_time_left(), blink))

	if lines.is_empty():
		_powerup_rt.visible = false
		return
	_powerup_rt.visible = true
	_powerup_rt.text = "\n".join(lines)


## One formatted row: name + remaining seconds, blinking red when about to expire.
func _powerup_row(nm: String, time_left: float, blink: float) -> String:
	var secs := int(ceil(maxf(time_left, 0.0)))
	if time_left > 0.0 and time_left <= PowerUpManager.WARN_TIME:
		# About to drop off — blink between hot red and pale yellow.
		var c := Color(1.0, 0.28, 0.2).lerp(Color(1.0, 0.96, 0.55), blink)
		return "[color=#%s]%s  %ds[/color]" % [c.to_html(false), nm, secs]
	return "[color=#d8f7ff]%s[/color]  [color=#7fd0ff]%ds[/color]" % [nm, secs]


# --------------------------------------------------------------- screen FX

## Slick "ENTERING <BIOME>" banner. Sweeps in near the TOP of the screen (under
## the score bar) so the area reveal reads clearly without blocking the action.
func _on_biome_changed(biome_name: String) -> void:
	if biome_name == "":
		return
	# Small overline + bold area name, stacked, anchored just below the top bar.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.085
	box.anchor_bottom = 0.085
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	add_child(box)

	var over := Label.new()
	over.text = "ⓘ  NOW ENTERING"
	over.add_theme_font_size_override("font_size", 20)
	over.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	over.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(over)

	var name_l := Label.new()
	name_l.text = biome_name
	name_l.add_theme_font_size_override("font_size", 46)
	name_l.add_theme_color_override("font_color", Color(1, 1, 1))
	name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_l)

	# Drop in from a touch higher, hold, then fade up and out.
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(box, "anchor_top", 0.105, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "anchor_bottom", 0.105, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.7)
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(box.queue_free)


func _build_coin_label() -> void:
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 30)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_coin_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_label.size = Vector2(220, 40)
	_coin_label.position = Vector2(get_viewport_rect().size.x - 244, 64)
	add_child(_coin_label)
	_on_coins_changed(GameManager.coins)


func _on_coins_changed(coins: int) -> void:
	# Text only — the in-run pickup juice (pop + floater) lives in _on_coin_collected so
	# it can react to the streak; non-pickup changes (shop/continue) just update the count.
	if _coin_label:
		_coin_label.text = "◎ %d" % coins


## Per-coin pickup juice: the counter punches (bigger + warmer as the rapid-collect
## streak climbs) and a "+1" floater rises and fades off the counter.
func _on_coin_collected(streak: int) -> void:
	if not _coin_label:
		return
	var t := clampf(float(streak) / 12.0, 0.0, 1.0)
	var col := Color(1.0, 0.85, 0.25).lerp(Color(1.0, 1.0, 0.85), t)
	_coin_label.add_theme_color_override("font_color", col)
	_coin_label.pivot_offset = _coin_label.size * 0.5
	var pop := 1.22 + 0.4 * t
	var tw := create_tween()
	_coin_label.scale = Vector2(pop, pop)
	tw.tween_property(_coin_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_coin_floater(streak, col)


func _spawn_coin_floater(streak: int, col: Color) -> void:
	var f := Label.new()
	f.text = "+1" if streak < 3 else "+1  x%d" % streak
	f.add_theme_font_size_override("font_size", 20 + mini(streak, 10))
	f.add_theme_color_override("font_color", col)
	f.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	f.size = Vector2(180, 30)
	var base := _coin_label.position + Vector2(_coin_label.size.x - 180, 36)
	f.position = base
	add_child(f)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(f, "position:y", base.y - 30.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(f.queue_free)


# --------------------------------------------------------------- star power

var _star_banner: Label = null
var _star_tint: ColorRect = null

func _build_star_banner() -> void:
	# Pulsing gold edge-glow over the whole screen.
	_star_tint = ColorRect.new()
	_star_tint.anchor_right = 1.0
	_star_tint.anchor_bottom = 1.0
	_star_tint.color = Color(1.0, 0.85, 0.2, 0.0)
	_star_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_star_tint)

	_star_banner = Label.new()
	_star_banner.text = "★ INVINCIBLE ★"
	_star_banner.add_theme_font_size_override("font_size", 44)
	_star_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25))
	_star_banner.add_theme_color_override("font_shadow_color", Color(0.2, 0.05, 0.0, 0.8))
	_star_banner.add_theme_constant_override("shadow_offset_x", 3)
	_star_banner.add_theme_constant_override("shadow_offset_y", 3)
	_star_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_star_banner.anchor_left = 0.0
	_star_banner.anchor_right = 1.0
	_star_banner.anchor_top = 0.2
	_star_banner.anchor_bottom = 0.2
	_star_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_star_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_star_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_banner.visible = false
	add_child(_star_banner)


func _on_star_started(_duration: float) -> void:
	if _star_banner:
		_star_banner.visible = true


func _on_star_ended() -> void:
	if _star_banner:
		_star_banner.visible = false
	if _star_tint:
		_star_tint.color.a = 0.0


func _update_star_banner() -> void:
	if _star_banner == null or not _star_banner.visible:
		return
	var p := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
	_star_banner.modulate = Color(1, 1, 1, 0.55 + 0.45 * p)
	_star_banner.scale = Vector2.ONE * (1.0 + 0.08 * p)
	_star_banner.pivot_offset = _star_banner.size * 0.5
	if _star_tint:
		_star_tint.color.a = 0.06 + 0.07 * p


# --------------------------------------------------------------- XP / level bar

## A slim centered level bar under the top edge — fills with dodges (XP) so the
## level-up card moment reads as earned, not random.
func _build_xp_bar() -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 0.0
	row.anchor_bottom = 0.0
	row.offset_top = 16.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_level_label = Label.new()
	_level_label.text = "LV 1"
	_level_label.add_theme_font_size_override("font_size", 24)
	_level_label.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	_level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_level_label)

	_xp_bg = Panel.new()
	_xp_bg.custom_minimum_size = XP_BAR_SIZE
	_xp_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.04, 0.06, 0.10, 0.6)
	bg_sb.set_corner_radius_all(6)
	bg_sb.set_border_width_all(1)
	bg_sb.border_color = Color(0.5, 0.8, 1.0, 0.4)
	_xp_bg.add_theme_stylebox_override("panel", bg_sb)
	row.add_child(_xp_bg)

	_xp_fill = Panel.new()
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_fill.position = Vector2(2, 2)
	_xp_fill.size = Vector2(0, XP_BAR_SIZE.y - 4)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.45, 0.85, 1.0, 0.95)
	fill_sb.set_corner_radius_all(5)
	_xp_fill.add_theme_stylebox_override("panel", fill_sb)
	_xp_bg.add_child(_xp_fill)


## Eases the fill toward the live XP fraction each frame.
func _update_xp_bar(delta: float) -> void:
	if _xp_fill == null:
		return
	var goal := GameManager.level_progress()
	_xp_display = move_toward(_xp_display, goal, maxf(absf(goal - _xp_display) * 6.0, 1.5) * delta)
	var w := (XP_BAR_SIZE.x - 4.0) * clampf(_xp_display, 0.0, 1.0)
	_xp_fill.size.x = w


func _on_level_up(level: int) -> void:
	# Snap the bar empty (it just drained into a level) and punch the badge.
	_xp_display = 0.0
	if _level_label:
		_level_label.text = "LV %d" % level
		_level_label.pivot_offset = _level_label.size * 0.5
		var tw := create_tween()
		_level_label.scale = Vector2(1.5, 1.5)
		tw.tween_property(_level_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_screen_fx() -> void:
	_fx_rect = ColorRect.new()
	_fx_rect.anchor_right = 1.0
	_fx_rect.anchor_bottom = 1.0
	_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_mat = ShaderMaterial.new()
	var shader := load("res://shaders/screen_fx.gdshader")
	if shader:
		_fx_mat.shader = shader
		_fx_rect.material = _fx_mat
	add_child(_fx_rect)
	move_child(_fx_rect, 0)  # draw behind the HUD widgets


## Resets the HUD for a new game.
func reset() -> void:
	_display_score = 0.0
	_flow_display = 0.0
	if _fx_mat:
		_fx_mat.set_shader_parameter("flow_heat", 0.0)
	if _score_label:
		_score_label.text = "0"
	for icon in _ability_icons.values():
		if icon:
			icon.modulate = Color(0.3, 0.3, 0.3, 0.6)
	if _milestone_banner:
		_milestone_banner.visible = false
	if _combo_hide_tw and _combo_hide_tw.is_valid():
		_combo_hide_tw.kill()
	if _combo_box:
		_combo_box.visible = false
		_combo_box.modulate.a = 1.0
	_xp_display = 0.0
	if _xp_fill:
		_xp_fill.size.x = 0.0
	if _level_label:
		_level_label.text = "LV 1"
