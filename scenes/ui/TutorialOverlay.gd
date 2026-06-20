## TutorialOverlay — non-blocking first-run teaching, taught through PLAY.
##
## Crashman drops new players into a fast lane with controls that aren't all
## available yet: lateral movement works from frame one, but JUMP only unlocks at
## 10 dodges and STOMP is an undiscoverable consequence of jumping onto a car. The
## old onboarding was a single flash + a dim HUD icon at the unlock — a new player
## had no idea a move had become available or HOW to perform it.
##
## This overlay teaches each control at the exact moment it matters, and only on
## the player's FIRST run (persisted via Settings.tutorial_seen). It never pauses
## or blocks: a prompt fades in low on screen, breathes, and clears itself the
## instant the player performs the action — with a green ✓ punch + chime so doing
## the thing feels acknowledged. Built entirely in code (no .tscn) so Main can
## drop it in and wire the player signals, matching the LevelUpScreen pattern.

extends CanvasLayer

## Lower-third vertical anchor (fraction of screen height) for the prompt — clear
## of the top biome banner and the centered greed meter (≈15.5%).
const PROMPT_Y := 0.70

## A small "GUNS AUTO-FIRE" toast appears here on the first gun pickup.
const TOAST_Y := 0.58

## Accent the prompt pulses in; turns green on completion.
const HINT_COLOR := Color(1.0, 0.92, 0.45)
const DONE_COLOR := Color(0.45, 1.0, 0.55)

var _player: Node = null

# Active-step bookkeeping. Steps run in sequence: MOVE → JUMP → STOMP.
enum Step { NONE, MOVE, JUMP_WAIT, JUMP, STOMP, FINISHED }
var _step: int = Step.NONE
var _active: bool = false          ## a first-run teaching pass is in progress
var _jump_unlocked: bool = false   ## jump ability has unlocked this run
var _start_x: float = 0.0          ## player lateral origin, for MOVE detection
var _toast_shown: bool = false     ## guns toast fired once

# UI nodes (built lazily).
var _root: Control = null
var _card: PanelContainer = null
var _title: Label = null
var _sub: Label = null
var _pulse_t: float = 0.0
var _toast: Label = null


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_ui()
	# Fresh-run detection + signal wiring. GunManager is an autoload; the player is
	# injected by Main via set_player() right after instantiation.
	GameManager.state_changed.connect(_on_state_changed)
	ProgressionManager.ability_unlocked.connect(_on_ability_unlocked)
	GunManager.guns_changed.connect(_on_guns_changed)


## Main injects the player so we can watch jump/stomp + poll lateral position.
func set_player(p: Node) -> void:
	_player = p
	if _player:
		if _player.has_signal("ability_activated"):
			_player.ability_activated.connect(_on_ability_activated)
		if _player.has_signal("car_stomped"):
			_player.car_stomped.connect(_on_car_stomped)


# ---------------------------------------------------------------- UI building

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# The main prompt card.
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.62)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(16)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.border_width_bottom = 3
	sb.border_color = HINT_COLOR
	_card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	_card.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", HINT_COLOR)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("outline_size", 10)
	vb.add_child(_title)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 21)
	_sub.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 0.92))
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_sub.add_theme_constant_override("outline_size", 6)
	vb.add_child(_sub)

	_card.modulate.a = 0.0
	_card.scale = Vector2(0.85, 0.85)
	_root.add_child(_card)

	# Independent "guns auto-fire" toast.
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("outline_size", 9)
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


# ----------------------------------------------------------------- lifecycle

func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.PLAYING:
		# Only teach on a genuine fresh run the player hasn't seen yet, and don't
		# restart a pass already running (a paid continue re-enters PLAYING).
		if _active:
			return
		if Settings and "tutorial_seen" in Settings and Settings.tutorial_seen:
			return
		_begin()
	else:
		# Any non-PLAYING state (crash offer, game over, menu) ends the pass.
		_end(false)


func _begin() -> void:
	_active = true
	_jump_unlocked = false
	_toast_shown = false
	_start_x = _player.global_position.x if _player else 0.0
	_set_step(Step.MOVE)


func _end(seen: bool) -> void:
	_active = false
	_step = Step.NONE
	_hide_card()
	if seen:
		_mark_seen()


## Persists that the player has been taught, so it never shows again.
func _mark_seen() -> void:
	if Settings and "tutorial_seen" in Settings and not Settings.tutorial_seen:
		Settings.tutorial_seen = true
		if Settings.has_method("save_tutorial_seen"):
			Settings.save_tutorial_seen()


# --------------------------------------------------------------- step machine

func _set_step(step: int) -> void:
	_step = step
	match step:
		Step.MOVE:
			_show_card("◄   MOVE   ►", "dodge the traffic")
		Step.JUMP:
			_show_card("JUMP!", "tap the screen  ·  or press Space")
		Step.STOMP:
			_show_card("STOMP FROM ABOVE", "land on a car mid-jump to crush it")
		_:
			_hide_card()


## Advances to the next teaching beat, flashing the current one green first.
func _complete_step(next: int) -> void:
	_confirm_card()
	# Jump is the pivotal control — once they've used it, mark the tutorial seen so
	# it never nags again, even if they don't reach the (bonus) stomp lesson.
	if _step == Step.JUMP:
		_mark_seen()

	if next == Step.JUMP_WAIT:
		# Movement learned, but jump isn't unlocked yet — wait silently for it.
		_step = Step.JUMP_WAIT
		get_tree().create_timer(0.55).timeout.connect(_hide_card)
		return
	if next == Step.FINISHED:
		_step = Step.FINISHED
		get_tree().create_timer(0.7).timeout.connect(func() -> void: _end(true))
		return
	# Otherwise show the next prompt after the green confirm reads.
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _active:
			_set_step(next)
	)


func _process(delta: float) -> void:
	if not _active:
		return
	# Lateral-movement detection for the MOVE step.
	if _step == Step.MOVE and _player and is_instance_valid(_player):
		if absf(_player.global_position.x - _start_x) >= 2.0:
			_complete_step(Step.JUMP_WAIT)

	# Breathing pulse on the live prompt (skip while a confirm tween owns scale).
	if _card and _card.modulate.a > 0.05 and _confirm_tw == null:
		_pulse_t += delta * 3.4
		var s := 1.0 + sin(_pulse_t) * 0.035
		_card.scale = Vector2(s, s)
	_layout()


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	if _card:
		_card.reset_size()
		var cs := _card.size * _card.scale
		_card.position = Vector2((vp.x - cs.x) * 0.5, vp.y * PROMPT_Y - cs.y * 0.5)
	if _toast:
		_toast.reset_size()
		_toast.position = Vector2((vp.x - _toast.size.x) * 0.5, vp.y * TOAST_Y)


# ------------------------------------------------------------- signal handlers

func _on_ability_unlocked(ability_name: StringName) -> void:
	if not _active:
		return
	if ability_name == &"jump":
		_jump_unlocked = true
		# Teach jump the instant it unlocks (if movement is already learned).
		if _step == Step.JUMP_WAIT or _step == Step.MOVE:
			_set_step(Step.JUMP)


func _on_ability_activated(ability_name: StringName) -> void:
	if not _active:
		return
	if ability_name == &"jump" and _step == Step.JUMP:
		_complete_step(Step.STOMP)


func _on_car_stomped() -> void:
	if not _active:
		return
	if _step == Step.STOMP:
		_complete_step(Step.FINISHED)


func _on_guns_changed() -> void:
	# One-time "your guns fire by themselves" toast on the first pickup — the
	# auto-fire model is non-obvious. Independent of the step machine.
	if _toast_shown or not _active:
		return
	if GunManager.owned.is_empty():
		return
	_toast_shown = true
	_show_toast("GUNS AUTO-FIRE!", "grab more gates to stack them")


# ------------------------------------------------------------------ card anim

var _confirm_tw: Tween = null
var _show_tw: Tween = null

func _show_card(title: String, sub: String) -> void:
	if _title:
		_title.text = title
		_title.add_theme_color_override("font_color", HINT_COLOR)
	if _sub:
		_sub.text = sub
	if _card == null:
		return
	_pulse_t = 0.0
	if _confirm_tw and _confirm_tw.is_valid():
		_confirm_tw.kill()
		_confirm_tw = null
	if _show_tw and _show_tw.is_valid():
		_show_tw.kill()
	AudioManager.play_ui()
	_layout()
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.8, 0.8)
	_show_tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_show_tw.tween_property(_card, "modulate:a", 1.0, 0.22)
	_show_tw.parallel().tween_property(_card, "scale", Vector2.ONE, 0.30)


## Flashes the current prompt green with a checkmark + punch + chime, then leaves
## it for the follow-up timer to clear/replace.
func _confirm_card() -> void:
	if _card == null:
		return
	if _title:
		_title.text = "✓  " + _title.text
		_title.add_theme_color_override("font_color", DONE_COLOR)
	AudioManager.play_pickup()
	Juice.haptic(20)
	if _show_tw and _show_tw.is_valid():
		_show_tw.kill()
	if _confirm_tw and _confirm_tw.is_valid():
		_confirm_tw.kill()
	_confirm_tw = create_tween()
	_confirm_tw.tween_property(_card, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_confirm_tw.tween_property(_card, "scale", Vector2.ONE, 0.12)
	_confirm_tw.tween_interval(0.18)
	_confirm_tw.tween_property(_card, "modulate:a", 0.0, 0.28)
	_confirm_tw.tween_callback(func() -> void: _confirm_tw = null)


func _hide_card() -> void:
	if _card == null:
		return
	if _confirm_tw and _confirm_tw.is_valid():
		_confirm_tw.kill()
		_confirm_tw = null
	if _show_tw and _show_tw.is_valid():
		_show_tw.kill()
		_show_tw = null
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.2)


func _show_toast(title: String, _sub_unused: String) -> void:
	if _toast == null:
		return
	_toast.text = title
	_layout()
	AudioManager.play_unlock()
	var tw := create_tween()
	_toast.modulate.a = 0.0
	_toast.scale = Vector2(0.9, 0.9)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_toast, "scale", Vector2.ONE, 0.28)
	tw.tween_interval(2.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
