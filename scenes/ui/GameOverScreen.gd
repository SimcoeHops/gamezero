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


func _ready() -> void:
	visible = false
	set_process_input(false)
	GameManager.state_changed.connect(_on_game_state_changed)
	_build_death_banner()
	_build_journey_map()


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

	# Populate stats
	if _score_label:
		_score_label.text = "SCORE: %d" % GameManager.score
	if _time_label:
		_time_label.text = "%d DODGES  ·  %.1fs" % [ProgressionManager.dodge_count, GameManager.time_elapsed]
	if _high_score_label:
		_high_score_label.text = "BEST: %d\n+%d COINS  (TOTAL %d)" % [GameManager.high_score, GameManager.last_coins_earned, GameManager.coins]

	# Check for new high score
	var is_new_record := GameManager.score >= GameManager.high_score and GameManager.score > 0
	if _new_record_label:
		_new_record_label.visible = is_new_record
		if is_new_record:
			# Pulsing animation for new record
			var tween := create_tween().set_loops()
			tween.tween_property(_new_record_label, "modulate:a", 0.3, 0.5)
			tween.tween_property(_new_record_label, "modulate:a", 1.0, 0.5)

	# A little audio/visual punctuation as the panel appears.
	if is_new_record:
		AudioManager.play_unlock()
		Juice.flash(Color(1.0, 0.85, 0.2), 0.2, 0.5)
	else:
		AudioManager.play_drain()

	if _restart_label:
		_restart_label.text = "TAP TO RESTART"

	# Animate in
	visible = true
	modulate.a = 0.0

	if _panel:
		_panel.scale = Vector2(0.8, 0.8)

	var main_tween := create_tween()
	main_tween.set_ease(Tween.EASE_OUT)
	main_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	if _panel:
		main_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)

	# Enable restart after a short delay (prevent accidental instant restart)
	main_tween.tween_interval(0.8)
	main_tween.tween_callback(func():
		_can_restart = true
		set_process_input(true)
	)
