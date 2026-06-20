## PlayerController — State Machine & Movement
##
## Manages the player's horizontal movement (clamped to highway bounds),
## ability activation, and state transitions including ragdoll on crash.

class_name PlayerController
extends CharacterBody3D

## Emitted when the player is hit by a car. Carries the car's velocity
## for camera shake and crumple magnitude calculations.
signal crashed(impact_velocity: Vector3)

## Emitted when the player activates an ability.
signal ability_activated(ability_name: StringName)

## Emitted when Bullet Time starts (true) or ends (false), for world FX.
signal bullet_time_changed(active: bool)

## Emitted when the player stomps (Mario-style) a car, for the "KABOOM!" popup.
signal car_stomped()

## Player state machine states.
enum State {
	RUNNING,       ## Default: lateral movement only
	JUMPING,       ## Vertical impulse active, still laterally mobile
	BULLET_TIME,   ## Engine.time_scale reduced, still mobile
	FIRING,        ## Brief fire animation lock (if desired)
	FLYING,        ## Superman fly mode — soaring above the cars
	RAGDOLL,       ## Physics ragdoll after crash
	DEAD,          ## Post-ragdoll, waiting for game over screen
}

## --- Exports ---

## Lateral movement speed in m/s.
@export var move_speed: float = 14.0

## Lateral acceleration (m/s²). Lower = floatier; higher = snappier.
@export var lateral_accel: float = 110.0

## Smoothed lateral velocity for weighty, eased steering.
var _lateral_vel: float = 0.0

## Direct-touch positioning: the world-X the runner is heading toward (where you
## last touched the road), and whether a touch target is pending. While a finger
## is down the runner tracks it; on release it glides to that spot and stops.
var _touch_target_x: float = 0.0
var _has_touch_target: bool = false

## How many jumps used since leaving the ground (1 = first jump in the air).
var _jumps_done: int = 0

## Variable-jump hold tracking.
var _jump_held: bool = false
var _jump_hold: float = 0.0

## Control-crispness: jump input buffering + coyote time. A jump pressed slightly
## BEFORE landing (or just after stepping off a ledge) should still fire, instead of
## being silently eaten — the single biggest "responsiveness" win in any platformer.
## How long a too-early jump press is remembered and re-tried on landing.
const JUMP_BUFFER_TIME := 0.13
## Grace window after leaving the ground in which a ground-jump still works.
const COYOTE_TIME := 0.10
## Countdown of the buffered jump (>0 = a jump is queued).
var _jump_buffer_t: float = 0.0
## Countdown of the coyote grace window (>0 = a late ground-jump is still allowed).
var _coyote_t: float = 0.0

## Altitude the player soars at during FLY mode.
@export var fly_altitude: float = 4.5
var _fly_timer: float = 0.0

## Half-width of the playable highway area (should match Highway).
@export var highway_half_width: float = 6.0

## Upward impulse when jumping (the initial pop of a tap).
@export var jump_impulse: float = 16.0

## Extra upward force applied while the jump button is held (variable height).
@export var jump_hold_force: float = 26.0

## Max seconds a held jump keeps rising.
@export var jump_max_hold: float = 0.24

## Gravity applied during jumps (m/s²).
@export var gravity: float = 40.0

## Upward bounce given when stomping a car mid-air (Mario-style). Lets a jump
## that lands on traffic pop back off instead of ending the run.
@export var stomp_bounce_impulse: float = 13.0

## Engine.time_scale during Bullet Time.
@export var bullet_time_scale: float = 0.2

## Seconds (real time) it takes for the world to ramp back to full speed after
## Bullet Time ends, instead of snapping back instantly.
@export var bullet_time_recover: float = 3.0
var _bt_ramping: bool = false
var _bt_ramp_start_ms: int = 0

## How long bullet time lasts in *scaled* seconds. (1.0 at 0.2 scale = 5 real seconds)
@export var bullet_time_duration: float = 1.0

## Cooldown between weapon shots (seconds).
@export var weapon_cooldown: float = 0.3

## Probability (0–1) that a jump becomes a front flip.
@export var front_flip_chance: float = 0.2

## --- Internal State ---

## The current player state.
var current_state: State = State.RUNNING

## Which abilities have been unlocked this run.
var abilities_unlocked: Dictionary = {
	&"jump": false,
	&"bullet_time": false,
	&"weapon": false,
}

## Whether bullet time is available (not on cooldown).
var _bullet_time_available: bool = true

## Whether the weapon is off cooldown.
var _weapon_ready: bool = true

## Active front-flip tween, if a flip is in progress (else null).
var _flip_tween: Tween = null

## Cached lateral input this frame (-1..1), used to lean the body into turns.
var _move_axis: float = 0.0

## Maximum cosmetic body lean (radians) at full steering.
const MAX_LEAN := 0.22
## How quickly the lean eases toward its target.
const LEAN_RESPONSE := 9.0
## Highway speed (m/s) at which the run animation plays at 1× speed.
const RUN_ANIM_BASE_SPEED := 15.0

## Procedural run-flair: organic sway + occasional stumbles. Cosmetic only —
## never affects movement, speed, or collision.
var _flair_noise := FastNoiseLite.new()
var _flair_t: float = 0.0
var _stumble_timer: float = 5.0
var _stumble_amt: float = 0.0

## --- Node References ---

@onready var _mesh: Node3D = $PlayerMesh
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _bt_timer: Timer = $AbilityTimers/BulletTimeTimer
@onready var _weapon_cd: Timer = $AbilityTimers/WeaponCooldown
@onready var _projectile_spawn: Marker3D = $ProjectileSpawn

@onready var _animation_player: AnimationPlayer = $AnimationPlayer

## Preloaded projectile scene for the Weapon ability.
var _projectile_scene: PackedScene = null

## Mount + currently-held gun model (cosmetic; the auto-fire lives in GunManager).
var _gun_hold: Node3D = null
var _held_gun_model: Node3D = null
var _held_gun_id: String = ""

## Star-power (invincibility) feedback.
var _skin_mat: StandardMaterial3D = null
var _star_light: OmniLight3D = null
var _star_active: bool = false
var _star_t: float = 0.0


func _ready() -> void:
	# Configure ability timers
	_bt_timer.wait_time = bullet_time_duration
	_bt_timer.one_shot = true
	_bt_timer.timeout.connect(_on_bullet_time_end)

	_weapon_cd.wait_time = weapon_cooldown
	_weapon_cd.one_shot = true
	_weapon_cd.timeout.connect(func(): _weapon_ready = true)

	# Connect to ProgressionManager ability unlock signals
	ProgressionManager.ability_unlocked.connect(_on_ability_unlocked)
	PowerUpManager.fly_requested.connect(_start_fly)
	# Touch: swipe up = jump, swipe down = slow-mo (mobile has no keyboard).
	InputSettings.jump_requested.connect(request_jump)
	InputSettings.bullet_time_requested.connect(request_bullet_time)
	PowerUpManager.star_started.connect(_on_star_started)
	PowerUpManager.star_ended.connect(_on_star_ended)

	# A bright pulsing aura light makes invincibility unmistakable.
	_star_light = OmniLight3D.new()
	_star_light.omni_range = 7.0
	_star_light.light_energy = 0.0
	_star_light.position = Vector3(0.0, 1.0, 0.0)
	_star_light.visible = false
	add_child(_star_light)

	_flair_noise.frequency = 1.0
	_flair_noise.seed = randi()

	# Lazy-load projectile scene
	if ResourceLoader.exists("res://scenes/projectile/Projectile.tscn"):
		_projectile_scene = load("res://scenes/projectile/Projectile.tscn")

	# Connect hitbox Area3D for collision detection with cars
	# (frozen RigidBody3D cars moved via position bypass CharacterBody3D collisions)
	var hitbox := get_node_or_null("PlayerHitbox") as Area3D
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

	# Load the running animation dynamically from run.fbx
	var anim_scene: Node = load("res://assets/kenney_animated-characters-protagonists/Animations/run.fbx").instantiate()
	if anim_scene:
		var imported_player := anim_scene.get_node("AnimationPlayer") as AnimationPlayer
		if imported_player and imported_player.has_animation("Root|Run"):
			var run_anim := imported_player.get_animation("Root|Run")
			var lib := AnimationLibrary.new()
			lib.add_animation("run", run_anim)
			
			if _animation_player:
				_animation_player.add_animation_library("", lib)
				_animation_player.get_animation("run").loop_mode = Animation.LOOP_LINEAR
				_animation_player.play("run")

	# Apply the player's chosen character skin. Also re-applied at the start of
	# every run (the player node is built once at scene load, but the runner is
	# chosen afterwards on the front-end, so _ready alone would lag a run behind).
	_apply_skin()
	GameManager.state_changed.connect(_on_game_state_changed)
	anim_scene.queue_free()

	# Slightly smaller runner so he doesn't block the view of oncoming traffic.
	if _mesh:
		_mesh.scale = Vector3(0.82, 0.82, 0.82)

	# Auto-fire guns: register our muzzle and show the gun we're carrying. The
	# held gun hangs off the runner's RIGHT HAND bone so it tracks the running
	# arm-swing and reads as actually held (a fixed body offset looked detached).
	var skel := get_node_or_null("PlayerMesh/Root/Skeleton3D") as Skeleton3D
	if skel and skel.find_bone("RightHand") != -1:
		var att := BoneAttachment3D.new()
		att.name = "GunHold"
		att.bone_name = "RightHand"
		skel.add_child(att)
		_gun_hold = att
	else:
		_gun_hold = Node3D.new()
		_gun_hold.name = "GunHold"
		_gun_hold.position = Vector3(0.38, 0.85, -0.15)
		add_child(_gun_hold)
	GunManager.register_player(self, _projectile_spawn)
	GunManager.guns_changed.connect(_update_held_gun)
	_update_held_gun()


## Applies the currently-selected character skin to the runner mesh.
func _apply_skin() -> void:
	var skin_path := Settings.selected_skin
	if not ResourceLoader.exists(skin_path):
		skin_path = Settings.DEFAULT_SKIN
	var skin_tex = load(skin_path)
	var mesh_node := get_node_or_null("PlayerMesh/Root/Skeleton3D/characterMedium") as MeshInstance3D
	if skin_tex and mesh_node:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = skin_tex
		mat.roughness = 0.8
		mesh_node.set_surface_override_material(0, mat)
		_skin_mat = mat


## Re-apply the chosen skin each time a fresh run begins.
func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.PLAYING:
		_apply_skin()


## Called when a physics body enters the player's hitbox Area3D.
func _on_hitbox_body_entered(body: Node) -> void:
	if current_state == State.RAGDOLL or current_state == State.DEAD:
		return
	# Ignore wrecked debris flying back through us — only live, approaching cars
	# are a threat (otherwise a gun-blasted car raining down would "kill" us).
	if body.has_method("is_live") and not body.is_live():
		return
	# Check if it's a car
	if body.has_method("crumple"):
		var impact_vel := Vector3(0, 0, body.approach_speed if "approach_speed" in body else 15.0)
		# Star power: plow through — destroy the car and keep running.
		if PowerUpManager.is_invincible():
			body.crumple(global_position, impact_vel)
			return
		# Mario-style stomp: if we're airborne, landing on a car knocks it out and
		# bounces us off instead of killing us. Saves the player from "bad luck"
		# crashes when jumping at high speed.
		if can_stomp():
			body.crumple(global_position, impact_vel)
			stomp_bounce(impact_vel)
			return
		var impact_point := global_position
		body.crumple(impact_point, impact_vel)
		activate_ragdoll(impact_vel)


## Whether the player is currently airborne in a way that should stomp a car
## (knock it out + bounce) rather than crash into it.
func can_stomp() -> bool:
	return current_state == State.JUMPING


## Pops the player back into the air after stomping a car. Assumes the car has
## already been crumpled by the caller.
func stomp_bounce(_impact_vel: Vector3) -> void:
	velocity.y = maxf(velocity.y, stomp_bounce_impulse)
	_jump_held = false  # don't let a held button keep adding lift after the bounce
	# Reward the stylish save and feed the combo, same as a clean dodge.
	ProgressionManager.register_dodge()
	# Announce the squash with a comic-book "KABOOM!" rather than a "near miss".
	car_stomped.emit()
	Juice.kick_fov(8.0)
	Juice.add_trauma(0.2)
	Juice.haptic(28)
	AudioManager.play_car_hit()


func _physics_process(delta: float) -> void:
	# Failsafe: if the player somehow leaves the world (e.g. flung off the road),
	# treat it as a crash so the run always ends instead of falling forever.
	if current_state != State.RAGDOLL and current_state != State.DEAD and global_position.y < -10.0:
		activate_ragdoll(Vector3.ZERO)
		return

	# Tick the input-buffer / coyote windows (real per-frame decay).
	if _jump_buffer_t > 0.0:
		_jump_buffer_t = maxf(_jump_buffer_t - delta, 0.0)
	if _coyote_t > 0.0:
		_coyote_t = maxf(_coyote_t - delta, 0.0)

	match current_state:
		State.RUNNING:
			# Grounded: keep the coyote window topped up so it only counts down once
			# the player actually leaves the floor.
			if is_on_floor():
				_coyote_t = COYOTE_TIME
			_handle_movement(delta)
			_handle_ability_input()
			_update_run_feel(delta)

		State.JUMPING:
			_handle_jump_hold(delta)
			_handle_movement(delta)
			_handle_air_jump()
			_apply_gravity(delta)
			move_and_slide()
			if is_on_floor() and velocity.y <= 0.0:
				velocity.y = 0.0
				_transition_to(State.RUNNING)
				# Honor a jump pressed just before touchdown: bounce straight back up.
				if _jump_buffer_t > 0.0:
					_jump_buffer_t = 0.0
					_coyote_t = COYOTE_TIME  # allow the buffered ground-jump to fire
					_try_jump()

		State.FLYING:
			# NOTE: deliberately no _handle_ability_input here. Letting jump /
			# bullet-time fire mid-flight used to yank the player out of FLYING
			# without cleaning up the pose + disabled collision, stranding them
			# frozen on their back at altitude. Fly only steers, then lands.
			_handle_movement(delta)
			global_position.y = lerpf(global_position.y, fly_altitude, clampf(delta * 4.0, 0.0, 1.0))
			_fly_timer -= delta
			if _fly_timer <= 0.0:
				_end_fly()

		State.BULLET_TIME:
			_handle_movement(delta)
			_handle_ability_input()
			_update_run_feel(delta)

		State.FIRING:
			_handle_movement(delta)

		State.RAGDOLL, State.DEAD:
			pass  # Physics bones handle everything


## Handles left/right movement and clamps position to highway bounds. Two schemes:
## touch = direct positioning (runner goes where your finger is), keyboard = the
## classic eased steering.
func _handle_movement(delta: float) -> void:
	# Live-update the target to the finger's spot on the road while it's down.
	if InputSettings.is_touch_active():
		_touch_target_x = _screen_to_world_x(InputSettings.get_touch_screen_pos())
		_has_touch_target = true

	if _has_touch_target:
		var goal := clampf(_touch_target_x, -highway_half_width, highway_half_width)
		# Track tightly while the finger is down (stay under it); glide a bit slower
		# to the tapped lane after release.
		var follow := 24.0 if InputSettings.is_touch_active() else 13.0
		var next_x := lerpf(global_position.x, goal, clampf(delta * follow, 0.0, 1.0))
		_move_axis = clampf((goal - global_position.x) * 2.5, -1.0, 1.0)  # body lean
		_lateral_vel = 0.0
		global_position.x = next_x
		# Once we've arrived after a release, hand control back (idle / keyboard).
		if not InputSettings.is_touch_active() and absf(next_x - goal) < 0.03:
			_has_touch_target = false
	else:
		var input_dir := InputSettings.get_move_axis()
		_move_axis = input_dir
		var target := input_dir * move_speed
		_lateral_vel = move_toward(_lateral_vel, target, lateral_accel * delta)
		var desired := global_position.x + _lateral_vel * delta
		var next_x := clampf(desired, -highway_half_width, highway_half_width)
		if not is_equal_approx(next_x, desired):
			_lateral_vel = 0.0  # bumped the edge
		global_position.x = next_x

	# Zero out X velocity after manual position set
	velocity.x = 0.0

	if current_state != State.JUMPING:
		move_and_slide()


## Projects a touch point onto the road (ground plane y=0) and returns its world
## X — i.e. the lateral spot on the road directly under the finger.
func _screen_to_world_x(screen_pos: Vector2) -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return global_position.x
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.00001:
		return global_position.x
	var t := -origin.y / dir.y  # distance to the y=0 ground plane
	if t <= 0.0:
		return global_position.x
	return (origin + dir * t).x


## Whether the player can jump: either the dodge-milestone unlocked it, OR they
## grabbed a JUMP orb (which used to silently do nothing until the milestone hit,
## so the first JUMP pickup "didn't work").
func _can_jump() -> bool:
	return abilities_unlocked[&"jump"] or PowerUpManager.air_jumps > 0


## Checks for ability-activation inputs. Jump / bullet-time are routed through the
## request_* methods so keyboard and touch (swipe up/down) share one code path.
func _handle_ability_input() -> void:
	if Input.is_action_just_pressed("jump"):
		request_jump()
	if Input.is_action_just_pressed("bullet_time"):
		request_bullet_time()
	if abilities_unlocked[&"weapon"] and Input.is_action_just_pressed("fire"):
		if _weapon_ready:
			_fire_projectile()


## Performs a jump appropriate to the current state: a ground jump from RUNNING /
## BULLET_TIME, or a mid-air (double) jump while already JUMPING. Called by both
## the keyboard input and the touch swipe-up signal. If the jump can't fire right
## now (airborne with no air-jump left, descending toward the ground), the press is
## BUFFERED and automatically re-tried the instant the player lands — so a tap a few
## frames early still bounces straight into the next jump instead of being lost.
func request_jump() -> void:
	if not _try_jump():
		_jump_buffer_t = JUMP_BUFFER_TIME


## Attempts to jump from the current state. Returns true only if a jump actually
## fired (so the caller knows whether to buffer the press).
func _try_jump() -> bool:
	if not _can_jump():
		return false
	match current_state:
		State.JUMPING:
			if _jumps_done <= PowerUpManager.air_jumps:
				_jumps_done += 1
				_begin_jump(jump_impulse * 0.92)
				ability_activated.emit(&"jump")
				Juice.kick_fov(5.0)
				Juice.haptic(16)
				_do_front_flip()  # double jumps always flip — it looks great
				return true
			return false
		State.RUNNING, State.BULLET_TIME:
			# Coyote time: a ground-jump is allowed for a grace window after leaving
			# the floor, so a jump pressed a hair too late still launches.
			if is_on_floor() or current_state == State.RUNNING or _coyote_t > 0.0:
				_transition_to(State.JUMPING)
				_jumps_done = 1
				_coyote_t = 0.0
				_begin_jump(jump_impulse)
				ability_activated.emit(&"jump")
				Juice.kick_fov(5.0)
				Juice.haptic(18)
				if randf() < front_flip_chance:
					_do_front_flip()
				return true
	return false


## Activates bullet time if unlocked and available. Shared by keyboard + swipe-down.
func request_bullet_time() -> void:
	if not abilities_unlocked[&"bullet_time"]:
		return
	if _bullet_time_available and current_state == State.RUNNING:
		_activate_bullet_time()


## Activates Bullet Time: slows engine time scale and starts duration timer.
func _activate_bullet_time() -> void:
	_transition_to(State.BULLET_TIME)
	_bullet_time_available = false
	_bt_ramping = false  # cancel any in-progress recovery ramp
	Engine.time_scale = bullet_time_scale
	_bt_timer.start()
	ability_activated.emit(&"bullet_time")
	bullet_time_changed.emit(true)
	print("[Player] Bullet Time activated")


## Fires the weapon using the current PowerUpManager fire mode.
func _fire_projectile() -> void:
	if _projectile_scene == null:
		push_warning("[Player] Projectile scene not loaded")
		return

	_weapon_ready = false
	_weapon_cd.start()

	match PowerUpManager.fire_mode:
		PowerUpManager.FireMode.BULLETS:
			_fire_bullets(PowerUpManager.bullet_count)
		PowerUpManager.FireMode.LASER:
			# Fast, piercing single beam.
			var laser := _spawn_projectile()
			if "piercing" in laser:
				laser.piercing = true
			if "speed" in laser:
				laser.speed = 95.0
		PowerUpManager.FireMode.NET:
			# Wide, slower, piercing sweep that crumples a cluster of cars.
			var net := _spawn_projectile()
			if "piercing" in net:
				net.piercing = true
			if "speed" in net:
				net.speed = 32.0
			net.scale = Vector3(4.0, 4.0, 1.5)

	ability_activated.emit(&"weapon")


## Spawns [param n] bullets in a small fan.
func _fire_bullets(n: int) -> void:
	var spread := 0.12
	var start := -spread * float(n - 1) * 0.5
	for i in n:
		var proj := _spawn_projectile()
		proj.rotation.y += start + spread * float(i)


## Instantiates a projectile at the muzzle and returns it.
func _spawn_projectile() -> Node3D:
	var proj := _projectile_scene.instantiate() as Node3D
	proj.global_transform = _projectile_spawn.global_transform
	get_tree().current_scene.add_child(proj)
	return proj


## Shows the most recently acquired gun in the runner's hand (cosmetic only —
## the actual auto-firing happens in GunManager).
func _update_held_gun() -> void:
	if _gun_hold == null:
		return
	var ids: Array = GunManager.owned.keys()
	if ids.is_empty():
		_held_gun_id = ""
		if _held_gun_model:
			_held_gun_model.queue_free()
			_held_gun_model = null
		return
	var id: String = ids.back()
	if id == _held_gun_id and _held_gun_model != null:
		return  # already holding this gun
	_held_gun_id = id
	if _held_gun_model:
		_held_gun_model.queue_free()
		_held_gun_model = null
	var model_name: String = GunManager.GUNS[id].get("model", "")
	var path := "res://assets/kenney_blaster-kit_2.1/Models/GLB format/%s.glb" % model_name
	if not ResourceLoader.exists(path):
		return
	var m := (load(path) as PackedScene).instantiate() as Node3D
	if _gun_hold is BoneAttachment3D:
		# The hand bone's pose carries a ~100x scale, so the gun is shrunk to read
		# at roughly its real size and yawed so the barrel points forward.
		m.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		m.scale = Vector3.ONE * 0.012
	else:
		m.rotation.y = PI             # barrel points forward (-Z), toward traffic
		m.scale = Vector3(1.1, 1.1, 1.1)
	_gun_hold.add_child(m)
	_held_gun_model = m


## Spins the player mesh a full forward rotation, synced to jump airtime.
## Purely cosmetic — the collision body is untouched.
func _do_front_flip() -> void:
	if _mesh == null:
		return

	# Airtime of the ballistic jump arc: rise + fall.
	var airtime := 2.0 * jump_impulse / gravity
	var base_x := _mesh.rotation.x

	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()

	_flip_tween = create_tween()
	_flip_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_flip_tween.tween_property(_mesh, "rotation:x", base_x + TAU, airtime)
	_flip_tween.tween_callback(_clear_flip)


## Stops any active flip and restores the mesh to an upright orientation.
func _clear_flip() -> void:
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = null
	if _mesh:
		_mesh.rotation.x = 0.0


## Transitions the state machine to [param new_state].
func _transition_to(new_state: State) -> void:
	var _old := current_state
	current_state = new_state
	# Additional state-entry logic can go here
	match new_state:
		State.RUNNING:
			# Landed — ensure the flip is finished and the mesh is upright.
			_clear_flip()
			_jumps_done = 0
		State.RAGDOLL:
			_collision.disabled = true


## Called by the collision system when a car hits the player.
## [param impact_velocity]: The velocity of the car at the moment of impact.
func activate_ragdoll(impact_velocity: Vector3) -> void:
	if current_state == State.RAGDOLL or current_state == State.DEAD:
		return

	print("[Player] CRASH! Impact velocity: ", impact_velocity)
	_transition_to(State.RAGDOLL)

	# Cancel any in-progress bullet-time recovery ramp.
	_bt_ramping = false

	# Hard hit-stop: a single frozen beat for maximum impact weight. The real
	# slow-mo and whip-back are choreographed on a wall-clock timeline below so
	# they read identically no matter what time_scale we crashed out of.
	Engine.time_scale = 0.001

	# Hide the animated mesh
	if _mesh:
		_mesh.visible = false

	# Burst the player into physics gibs + glass/spark debris — the payoff.
	var skeleton := get_node_or_null("RagdollSkeleton")
	if skeleton and skeleton.has_method("activate"):
		skeleton.activate(impact_velocity, global_position + Vector3(0, 0.9, 0))

	crashed.emit(impact_velocity)
	_run_crash_time_sequence()


## Choreographs the crash time-dilation on a real-time (unscaled) timeline:
## a brief frozen hit-stop, a held slow-mo to savour the ragdoll, then a fast
## "whip" back up to speed before the recap. Guards against the run resetting
## or the player reviving mid-sequence.
func _run_crash_time_sequence() -> void:
	var tree := get_tree()
	# Frozen hit-stop.
	await tree.create_timer(0.07, true, false, true).timeout
	if current_state != State.RAGDOLL:
		return
	# Drop into dramatic slow-mo and hold it.
	Engine.time_scale = 0.12
	await tree.create_timer(0.42, true, false, true).timeout
	if current_state != State.RAGDOLL:
		return
	# Whip back to full speed (real-time so it ignores its own slow-mo).
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_set_time_scale, 0.12, 1.0, 0.22)
	# Let the ragdoll fly and settle before the recap.
	await tree.create_timer(1.5, true, false, true).timeout
	if current_state != State.RAGDOLL:
		return
	_on_ragdoll_settled()


func _set_time_scale(v: float) -> void:
	Engine.time_scale = v


## Called after the ragdoll spectacle to transition to DEAD and offer a continue
## (or end the run).
func _on_ragdoll_settled() -> void:
	_transition_to(State.DEAD)
	GameManager.player_died()


## Revives the player after a paid continue: clears the ragdoll, re-centers,
## and resumes running.
func revive() -> void:
	var skeleton := get_node_or_null("RagdollSkeleton")
	if skeleton and skeleton.has_method("deactivate"):
		skeleton.deactivate()

	if _mesh:
		_mesh.visible = true
		_mesh.rotation.x = 0.0
		_mesh.rotation.z = 0.0

	_collision.disabled = false
	current_state = State.RUNNING
	_lateral_vel = 0.0
	velocity = Vector3.ZERO
	global_position.x = 0.0
	_bt_ramping = false
	_jump_buffer_t = 0.0
	_coyote_t = 0.0
	Engine.time_scale = 1.0

	if _animation_player and _animation_player.has_animation("run"):
		_animation_player.play("run")


## Callback from ProgressionManager when a new ability is unlocked.
func _on_ability_unlocked(ability_name: StringName) -> void:
	abilities_unlocked[ability_name] = true
	print("[Player] Ability unlocked: ", ability_name)


## Callback when Bullet Time timer expires. Rather than snapping back to full
## speed, kick off a gradual ramp (handled in _process on real time).
func _on_bullet_time_end() -> void:
	_bullet_time_available = true
	if current_state == State.BULLET_TIME:
		_transition_to(State.RUNNING)
	bullet_time_changed.emit(false)
	_bt_ramping = true
	_bt_ramp_start_ms = Time.get_ticks_msec()
	print("[Player] Bullet Time ended — ramping back up")


## Eases Engine.time_scale from bullet-time back to 1.0 over [member
## bullet_time_recover] real seconds. Uses wall-clock time so the slowed engine
## doesn't stretch the ramp itself.
func _process(delta: float) -> void:
	if _bt_ramping:
		var dur_ms := maxf(bullet_time_recover * 1000.0, 1.0)
		var t := clampf(float(Time.get_ticks_msec() - _bt_ramp_start_ms) / dur_ms, 0.0, 1.0)
		Engine.time_scale = lerpf(bullet_time_scale, 1.0, t)
		if t >= 1.0:
			Engine.time_scale = 1.0
			_bt_ramping = false

	if _star_active:
		_update_star_fx(delta)


## Strong, unmistakable invincibility feedback: a fast-cycling rainbow aura on
## the player plus an emissive shimmer on the runner's body.
func _update_star_fx(delta: float) -> void:
	_star_t += delta
	var hue := fmod(_star_t * 0.9, 1.0)
	var col := Color.from_hsv(hue, 0.85, 1.0)
	var pulse := 0.6 + 0.4 * sin(_star_t * 14.0)
	if _star_light:
		_star_light.light_color = col
		_star_light.light_energy = 3.0 + pulse * 4.0
	if _skin_mat:
		_skin_mat.emission_enabled = true
		_skin_mat.emission = col
		_skin_mat.emission_energy_multiplier = 0.6 + pulse * 0.9


func _on_star_started(_duration: float) -> void:
	_star_active = true
	_star_t = 0.0
	if _star_light:
		_star_light.visible = true
	Juice.flash(Color(1.0, 0.9, 0.3), 0.4, 0.6)
	Juice.haptic(40)


func _on_star_ended() -> void:
	_star_active = false
	if _star_light:
		_star_light.visible = false
		_star_light.light_energy = 0.0
	if _skin_mat:
		_skin_mat.emission_enabled = false


## Starts a jump and arms the variable-height hold window.
func _begin_jump(impulse: float) -> void:
	velocity.y = impulse
	_jump_held = true
	_jump_hold = 0.0


## Quick tap = short hop; holding the button keeps rising for a longer jump.
func _handle_jump_hold(delta: float) -> void:
	if _jump_held:
		if Input.is_action_pressed("jump") and velocity.y > 0.0 and _jump_hold < jump_max_hold:
			velocity.y += jump_hold_force * delta
			_jump_hold += delta
		else:
			_jump_held = false
	# Releasing early while still rising cuts the jump short.
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5
		_jump_held = false


## Applies gravity to the player during jump state.
func _apply_gravity(delta: float) -> void:
	velocity.y -= gravity * delta


## Mid-air re-jump (double jump), enabled by jump orbs (PowerUpManager.air_jumps).
func _handle_air_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		request_jump()  # request_jump handles the JUMPING (double-jump) case


## Enters FLY mode: soar above the cars in a superman pose for [param duration].
func _start_fly(duration: float) -> void:
	if current_state == State.RAGDOLL or current_state == State.DEAD:
		return
	# Cancel any bullet-time cleanly so its timer/ramp doesn't fight the flight.
	Engine.time_scale = 1.0
	_bt_ramping = false
	_bullet_time_available = true
	if _bt_timer:
		_bt_timer.stop()

	_fly_timer = duration
	_transition_to(State.FLYING)
	velocity = Vector3.ZERO
	_collision.disabled = true  # cars can't touch us up here anyway
	ability_activated.emit(&"jump")
	Juice.kick_fov(10.0)
	Juice.flash(Color(0.5, 0.8, 1.0), 0.25, 0.4)
	Juice.haptic(40)

	# Superman pose: pitch the mesh forward so he soars belly-down (not on his
	# back). The fly timer is counted down in the FLYING physics branch — no
	# SceneTreeTimer, which could stretch under time-scale or fire in the wrong
	# state and leave the pose stuck.
	if _mesh:
		var tw := create_tween()
		tw.tween_property(_mesh, "rotation:x", PI * 0.5, 0.3).set_trans(Tween.TRANS_BACK)


## Returns from FLY mode to running. Always restores the pose + collision (guarding
## only against death) so the player can never get stranded floating.
func _end_fly() -> void:
	if current_state == State.RAGDOLL or current_state == State.DEAD:
		return
	if _mesh:
		var tw := create_tween()
		tw.tween_property(_mesh, "rotation:x", 0.0, 0.3)
	# Glide back down to the road.
	var down := create_tween()
	down.tween_property(self, "global_position:y", 0.0, 0.4).set_trans(Tween.TRANS_QUAD)
	_collision.disabled = false
	velocity.y = 0.0
	if current_state == State.FLYING:
		_transition_to(State.RUNNING)


## Adds natural-running feel: the stride speeds up as the highway speeds up,
## and the body leans into lateral steering. Purely cosmetic (mesh only) and
## independent of the flip axis (X), so it never fights a front flip.
func _update_run_feel(delta: float) -> void:
	_flair_t += delta

	# Occasionally trigger a stumble (recovers on its own; never trips gameplay).
	_stumble_timer -= delta
	if _stumble_timer <= 0.0:
		_stumble_timer = randf_range(4.0, 9.0)
		if randf() < 0.6:
			_stumble_amt = 1.0
	_stumble_amt = maxf(_stumble_amt - delta * 2.2, 0.0)
	var stumble := sin(_stumble_amt * PI)  # eases 0→1→0 across the stumble

	if _animation_player and _animation_player.is_playing():
		var ratio := GameManager.highway_speed / RUN_ANIM_BASE_SPEED
		var fatigue := _flair_noise.get_noise_1d(_flair_t * 0.7) * 0.12  # tired wobble
		_animation_player.speed_scale = clampf(ratio + fatigue, 0.8, 2.3)

	if _mesh:
		var sway := _flair_noise.get_noise_1d(_flair_t * 1.3) * 0.06
		var hitch := stumble * 0.12 * (1.0 if int(_flair_t * 7.0) % 2 == 0 else -1.0)
		var target_lean := _move_axis * MAX_LEAN + sway + hitch
		var pitch := _flair_noise.get_noise_1d(_flair_t * 1.1 + 50.0) * 0.04 + stumble * 0.26
		var dip := stumble * -0.16

		var t := clampf(delta * LEAN_RESPONSE, 0.0, 1.0)
		_mesh.rotation.z = lerpf(_mesh.rotation.z, target_lean, t)
		_mesh.rotation.x = lerpf(_mesh.rotation.x, pitch, t)
		_mesh.position.y = lerpf(_mesh.position.y, dip, t)
