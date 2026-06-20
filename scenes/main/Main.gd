## Main — Root scene orchestrator
##
## Wires the subsystems together, composites the camera each frame (curve lean +
## Juice shake + speed FOV), routes game events into Juice/AudioManager for
## feel, and handles the title / first-run flow.

extends Node3D

## How strongly the camera rolls into the road's curve.
@export var camera_roll_gain: float = 26.0
## Extra FOV (degrees) added at top speed for a sense of velocity.
@export var speed_fov_gain: float = 14.0

@onready var _camera: Camera3D = $Camera3D
@onready var _highway: Node3D = $Highway
@onready var _player: CharacterBody3D = $Player
@onready var _car_spawner: Node3D = $CarSpawner
@onready var _powerup_spawner: Node3D = $PowerUpSpawner
@onready var _coin_spawner: Node3D = $CoinSpawner
@onready var _world_env: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _front_end: Control = $CanvasLayer/FrontEnd
@onready var _hud: Control = $CanvasLayer/HUD

var _camera_base_pos: Vector3
var _base_fov: float = 65.0
var _camera_roll: float = 0.0


func _ready() -> void:
	if _camera:
		_camera_base_pos = _camera.position
		_base_fov = _camera.fov

	if _car_spawner:
		_car_spawner.player_ref = _player
		_car_spawner.highway_ref = _highway

	if _powerup_spawner:
		_powerup_spawner.player_ref = _player
		_powerup_spawner.highway_ref = _highway

	if _coin_spawner:
		_coin_spawner.player_ref = _player
		_coin_spawner.highway_ref = _highway

	GameManager.continued.connect(_on_continued)

	if _player:
		_player.crashed.connect(_on_player_crashed)
		_player.ability_activated.connect(_on_ability_activated)
		_player.bullet_time_changed.connect(_on_bullet_time_changed)
		if _hud and _hud.has_method("show_stomp_boom"):
			_player.car_stomped.connect(_hud.show_stomp_boom)

	ProgressionManager.ability_unlocked.connect(_on_unlock)
	ProgressionManager.near_miss.connect(_on_near_miss)

	if _highway and _highway.has_signal("theme_changed"):
		_highway.theme_changed.connect(_on_theme_changed)
		if _highway.has_method("get_current_theme"):
			_apply_theme(_highway.get_current_theme(), true)

	# First launch shows the title/character select; restarts jump straight in.
	if GameManager.current_state == GameManager.GameState.MENU:
		_front_end.begin()
	else:
		GameManager.start_game()


func _process(delta: float) -> void:
	if _camera == null:
		return

	# Speed-driven FOV widening + the decaying Juice kick.
	var speed_t := clampf((GameManager.highway_speed - 15.0) / 45.0, 0.0, 1.0)
	var target_fov := _base_fov + speed_t * speed_fov_gain + Juice.fov_kick()
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 8.0, 0.0, 1.0))

	# Lean into the curve, then layer the shake on top.
	var roll := 0.0
	if _highway and "current_curvature" in _highway:
		roll = -_highway.current_curvature * camera_roll_gain
	_camera_roll = lerpf(_camera_roll, roll, clampf(delta * 3.0, 0.0, 1.0))

	_camera.position = _camera_base_pos + Juice.shake_offset()
	_camera.rotation.z = _camera_roll + Juice.shake_roll()


# --------------------------------------------------------------- event feel

func _on_player_crashed(_impact_velocity: Vector3) -> void:
	Juice.add_trauma(1.25)
	Juice.kick_fov(28.0)
	Juice.impact(1.0)
	# Sharp white pop, then a warm afterglow during the slow-mo.
	Juice.flash(Color(1, 1, 1), 0.85, 0.18)
	get_tree().create_timer(0.06, true, false, true).timeout.connect(
		func() -> void: Juice.flash(Color(1.0, 0.55, 0.3), 0.32, 0.6)
	)
	Juice.haptic(80)
	AudioManager.play_crash()
	# Secondary "thud" + shake when the ragdoll slams the ground.
	get_tree().create_timer(0.36, true, false, true).timeout.connect(_on_crash_landing)


func _on_crash_landing() -> void:
	Juice.add_trauma(0.5)
	Juice.kick_fov(10.0)
	Juice.haptic(35)


func _on_ability_activated(ability_name: StringName) -> void:
	match ability_name:
		&"weapon":
			AudioManager.play_laser()
		&"jump":
			AudioManager.play_nearmiss()
		&"bullet_time":
			AudioManager.play_ui()
			Juice.flash(Color(0.4, 0.7, 1.0), 0.14, 0.35)


## Drains the world's color while Bullet Time is active for a cinematic feel.
func _on_bullet_time_changed(active: bool) -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var env := _world_env.environment
	var target_sat := 0.45 if active else 1.22
	var tw := create_tween()
	tw.tween_property(env, "adjustment_saturation", target_sat, 0.25)


func _on_unlock(_ability_name: StringName) -> void:
	AudioManager.play_unlock()
	Juice.flash(Color(1.0, 0.85, 0.2), 0.25, 0.5)
	Juice.add_trauma(0.25)
	Juice.haptic(40)


func _on_near_miss() -> void:
	AudioManager.play_nearmiss()
	Juice.add_trauma(0.14)
	Juice.flash(Color(0.6, 0.95, 1.0), 0.07, 0.18)
	Juice.haptic(12)
	Juice.hit_stop(0.05, 0.4)


## Paid continue: clear the danger and revive the player.
func _on_continued() -> void:
	if _car_spawner and _car_spawner.has_method("clear_all_cars"):
		_car_spawner.clear_all_cars()
	if _player and _player.has_method("revive"):
		_player.revive()
	Juice.flash(Color(0.3, 1.0, 0.5), 0.3, 0.4)
	Juice.add_trauma(0.3)


func _on_theme_changed(theme: Dictionary) -> void:
	_apply_theme(theme, false)
	GameManager.biome_changed.emit(theme.get("name", ""))
	GameManager.log_biome(theme.get("name", ""))


## Cross-fades the world fog/ambient color to match [param theme].
func _apply_theme(theme: Dictionary, instant: bool) -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var env := _world_env.environment
	var fog: Color = theme.get("fog", env.fog_light_color)
	var amb: Color = theme.get("ambient", env.ambient_light_color)
	var lit: Color = theme.get("light", _sun.light_color if _sun else Color.WHITE)

	if instant:
		env.fog_light_color = fog
		env.ambient_light_color = amb
		if _sun:
			_sun.light_color = lit
		return

	var tw := create_tween().set_parallel(true)
	tw.tween_property(env, "fog_light_color", fog, 3.0)
	tw.tween_property(env, "ambient_light_color", amb, 3.0)
	if _sun:
		tw.tween_property(_sun, "light_color", lit, 3.0)
