## GameOverScreen — Post-crash score display with tap-to-restart
##
## Appears after the ragdoll spectacle settles. Shows final score,
## cars dodged, time survived, and high score. Tap anywhere or press
## any key to restart.

extends Control

const DIED_IMAGE := "res://assets/images/died1.png"

@onready var _panel: PanelContainer = $CenterContainer/Panel
@onready var _vbox: VBoxContainer = $CenterContainer/Panel/VBox
@onready var _title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var _score_label: Label = $CenterContainer/Panel/VBox/ScoreLabel
@onready var _time_label: Label = $CenterContainer/Panel/VBox/TimeLabel
@onready var _high_score_label: Label = $CenterContainer/Panel/VBox/HighScoreLabel
@onready var _restart_label: Label = $CenterContainer/Panel/VBox/RestartLabel
@onready var _new_record_label: Label = $CenterContainer/Panel/VBox/NewRecordLabel

var _can_restart: bool = false

## Left-side top-down recap map (built in code).
var _journey_map: Control = null

## Confetti emitters (built in code), fired on a new personal best.
var _confetti: Array[CPUParticles2D] = []
## Counts how many integer "steps" of a count-up have ticked, so the rising
## blip fires at a steady cadence rather than every frame.
var _tick_step: int = 0


func _ready() -> void:
	visible = false
	set_process_input(false)
	GameManager.state_changed.connect(_on_game_state_changed)
	_build_death_banner()
	_build_journey_map()
	_build_confetti()


## Drops the custom "died" artwork in at the top of the panel (replacing the
## plain WRECKED! text). Sized to a tidy banner so it doesn't swallow the screen.
func _build_death_banner() -> void:
	if not ResourceLoader.exists(DIED_IMAGE):
		return
	var tex := load(DIED_IMAGE) as Texture2D
	if tex == null:
		return
	var banner := TextureRect.new()
	banner.texture = tex
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_SCALE
	# Fixed banner width, height kept to the image's aspect ratio.
	var w := 420.0
	var ar := float(tex.get_height()) / float(tex.get_width())
	banner.custom_minimum_size = Vector2(w, w * ar)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _vbox:
		_vbox.add_child(banner)
		_vbox.move_child(banner, 0)
	# The artwork carries the "wrecked" message now, so hide the text title.
	if _title_label:
		_title_label.visible = false


## Creates the journey-recap map pinned to the left of the screen.
func _build_journey_map() -> void:
	_journey_map = Control.new()
	_journey_map.set_script(load("res://scenes/ui/JourneyMap.gd"))
	_journey_map.anchor_left = 0.0
	_journey_map.anchor_right = 0.0
	_journey_map.anchor_top = 0.0
	_journey_map.anchor_bottom = 1.0
	_journey_map.offset_left = 26.0
	_journey_map.offset_right = 360.0
	_journey_map.offset_top = 90.0
	_journey_map.offset_bottom = -40.0
	_journey_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_journey_map)


## Builds a small set of one-shot confetti emitters in bright party colors. They
## sit dormant until a new personal best fires them from above the panel. Several
## single-color emitters give multi-color confetti without a per-particle shader.
func _build_confetti() -> void:
	var colors := [
		Color(1.0, 0.84, 0.2),   # gold
		Color(0.3, 0.95, 1.0),   # cyan
		Color(1.0, 0.35, 0.75),  # magenta
		Color(0.45, 1.0, 0.5),   # green
		Color(1.0, 0.55, 0.2),   # orange
	]
	for col in colors:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.92
		p.amount = 22
		p.lifetime = 1.9
		p.direction = Vector2(0, -1)
		p.spread = 55.0
		p.gravity = Vector2(0, 900)
		p.initial_velocity_min = 380.0
		p.initial_velocity_max = 820.0
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		p.scale_amount_min = 4.0
		p.scale_amount_max = 9.0
		p.damping_min = 12.0
		p.damping_max = 40.0
		p.color = col
		# Fade the confetti out over its life so it doesn't pop off-screen.
		var ramp := Gradient.new()
		ramp.set_color(0, Color(col.r, col.g, col.b, 1.0))
		ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
		p.color_ramp = ramp
		p.z_index = 50
		add_child(p)
		_confetti.append(p)


## Fires the confetti burst from just above the panel, across the screen top.
func _burst_confetti() -> void:
	var vp := get_viewport_rect().size
	for i in _confetti.size():
		var p := _confetti[i]
		# Spread the emitters horizontally so confetti rains across the whole top.
		var fx := lerpf(0.28, 0.72, float(i) / maxf(_confetti.size() - 1, 1))
		p.position = Vector2(vp.x * fx, vp.y * 0.30)
		p.emitting = true
		p.restart()


func _input(event: InputEvent) -> void:
	if not _can_restart:
		return

	# Tap / click / any key to restart
	var should_restart := false

	if event is InputEventScreenTouch and event.pressed:
		should_restart = true
	elif event is InputEventMouseButton and event.pressed:
		should_restart = true
	elif event is InputEventKey and event.pressed and not event.echo:
		should_restart = true

	if should_restart:
		_can_restart = false
		set_process_input(false)
		GameManager.restart()


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.GAME_OVER:
			_show_game_over()
		GameManager.GameState.PLAYING:
			visible = false
			set_process_input(false)
			_can_restart = false


func _show_game_over() -> void:
	# Refresh the top-down journey recap from this run's data.
	if _journey_map and _journey_map.has_method("refresh"):
		_journey_map.refresh()

	var new_best: bool = GameManager.last_run_best_score
	var new_dist: bool = GameManager.last_run_best_distance

	# Stats start blanked-out at zero; the recap sequence counts them up.
	if _score_label:
		_score_label.text = "SCORE: 0"
	if _time_label:
		_time_label.text = ""
	if _high_score_label:
		_high_score_label.text = ""
		_high_score_label.modulate.a = 0.0

	# The record banner is hidden until the count-up lands its punchline.
	if _new_record_label:
		_new_record_label.visible = false
		_new_record_label.modulate.a = 0.0
		if new_best:
			_new_record_label.text = "★ NEW BEST ★"
			_new_record_label.add_theme_color_override("font_color", Color(1, 0.85, 0))
		elif new_dist:
			_new_record_label.text = "✦ FURTHEST RUN ✦"
			_new_record_label.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0))

	if _restart_label:
		_restart_label.text = "TAP TO RESTART"
		_restart_label.modulate.a = 0.0

	# Animate the panel in.
	visible = true
	modulate.a = 0.0
	if _panel:
		_panel.scale = Vector2(0.85, 0.85)

	var main_tween := create_tween()
	main_tween.set_ease(Tween.EASE_OUT)
	main_tween.tween_property(self, "modulate:a", 1.0, 0.4)
	if _panel:
		main_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	# Once the panel has landed, run the count-up + celebration beat.
	main_tween.tween_callback(_play_recap_sequence.bind(new_best, new_dist))


## Choreographs the recap once the panel is up: the hero SCORE ticks up from zero
## with a rising blip, the supporting stats punch in, and — on a personal best —
## a banner punches in with confetti + a fanfare. Restart unlocks only at the end
## so a reflexive tap can't skip the payoff.
func _play_recap_sequence(new_best: bool, new_dist: bool) -> void:
	var score: int = GameManager.score
	var count_dur := clampf(0.35 + float(score) / 4000.0, 0.45, 1.1)

	# Hero stat: count the score up with a climbing tick.
	_tick_step = 0
	var ticks := 14
	var seq := create_tween()
	seq.set_ease(Tween.EASE_OUT)
	seq.set_trans(Tween.TRANS_CUBIC)
	seq.tween_method(
		func(v: float) -> void:
			if _score_label:
				_score_label.text = "SCORE: %d" % int(round(v))
			var step := int((v / maxf(float(score), 1.0)) * ticks)
			if step != _tick_step:
				_tick_step = step
				AudioManager.play_count_tick(v / maxf(float(score), 1.0)),
		0.0, float(score), count_dur)

	# Supporting stats snap in together just after the score lands.
	seq.tween_callback(_reveal_support_stats)
	seq.tween_interval(0.18)
	# The punchline.
	seq.tween_callback(func() -> void: _finish_recap(new_best, new_dist))


## Fills in dodges/distance/time and the BEST line, fading them up under the score.
func _reveal_support_stats() -> void:
	if _time_label:
		_time_label.text = "%d DODGES  ·  %d m  ·  %.1fs" % [
			ProgressionManager.dodge_count, int(GameManager.run_distance), GameManager.time_elapsed
		]
	if _high_score_label:
		_high_score_label.text = "BEST  %d   ·   %d m\n+%d COINS  (TOTAL %d)" % [
			GameManager.high_score, int(GameManager.best_distance),
			GameManager.last_coins_earned, GameManager.coins
		]
		var tw := create_tween()
		tw.tween_property(_high_score_label, "modulate:a", 1.0, 0.25)


## The closing beat: celebrate a personal best (banner punch + confetti + fanfare)
## or play a softer sting, then unlock restart.
func _finish_recap(new_best: bool, new_dist: bool) -> void:
	if new_best or new_dist:
		if _new_record_label:
			_new_record_label.visible = true
			_new_record_label.modulate.a = 1.0
			_new_record_label.scale = Vector2(0.3, 0.3)
			_new_record_label.pivot_offset = _new_record_label.size * 0.5
			var punch := create_tween()
			punch.tween_property(_new_record_label, "scale", Vector2.ONE, 0.45) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			# Then settle into a gentle pulse.
			punch.tween_callback(_start_record_pulse)
		_burst_confetti()
		AudioManager.play_fanfare()
		var col := Color(1.0, 0.85, 0.2) if new_best else Color(0.4, 0.9, 1.0)
		Juice.flash(col, 0.28, 0.6)
		Juice.haptic(60)
	else:
		AudioManager.play_drain()

	# Reveal the restart prompt and arm it after a short grace window.
	if _restart_label:
		var tw := create_tween()
		tw.tween_property(_restart_label, "modulate:a", 1.0, 0.3)
	var arm := create_tween()
	arm.tween_interval(0.5)
	arm.tween_callback(func() -> void:
		_can_restart = true
		set_process_input(true))


## Gentle looping glow on the record banner once it has punched in.
func _start_record_pulse() -> void:
	if _new_record_label == null:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(_new_record_label, "modulate:a", 0.45, 0.6)
	tween.tween_property(_new_record_label, "modulate:a", 1.0, 0.6)
