## Juice — Autoload for game-feel: camera shake, hit-stop, FOV kick,
## screen flash, and haptics. Systems call into this; Main composites the
## camera state each frame from the values exposed here.

extends Node

## Trauma-based shake (Vlambeer-style): trauma decays, shake = trauma².
var _trauma: float = 0.0
## Additive FOV kick (degrees), decays back to 0.
var _fov_kick: float = 0.0

var _shake_offset: Vector3 = Vector3.ZERO
var _shake_roll: float = 0.0

var _noise := FastNoiseLite.new()
var _t: float = 0.0

var _flash: ColorRect = null

const TRAUMA_DECAY := 1.8
const MAX_OFFSET := 0.7
const MAX_ROLL := 0.10
const FOV_DECAY := 7.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 2.0
	_build_overlay()


func _process(delta: float) -> void:
	# Use a real (unscaled) tick so shake keeps moving during slow-mo/hit-stop.
	var rt := delta
	_t += 0.016

	_trauma = maxf(_trauma - TRAUMA_DECAY * rt, 0.0)
	_fov_kick = lerpf(_fov_kick, 0.0, clampf(rt * FOV_DECAY, 0.0, 1.0))

	var amt := _trauma * _trauma
	var s := _t * 28.0
	_shake_offset = Vector3(
		_noise.get_noise_2d(s, 0.0),
		_noise.get_noise_2d(0.0, s) * 0.7,
		0.0
	) * MAX_OFFSET * amt
	_shake_roll = _noise.get_noise_2d(s, 100.0) * MAX_ROLL * amt


## Adds shake energy (0..1 typical). Bigger hits add more.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.25)


## Kicks the camera FOV outward by [param deg]; decays automatically.
func kick_fov(deg: float) -> void:
	_fov_kick = maxf(_fov_kick, deg)


func shake_offset() -> Vector3:
	return _shake_offset


func shake_roll() -> float:
	return _shake_roll


func fov_kick() -> float:
	return _fov_kick


## Briefly freezes time for impact weight, then restores the previous scale.
## Uses a real-time timer so it works even at time_scale 0.
func hit_stop(duration: float = 0.07, scale: float = 0.02) -> void:
	var prev := Engine.time_scale
	# Don't stomp an active slow-mo (e.g. the crash sequence).
	if prev < 0.9:
		return
	Engine.time_scale = scale
	var timer := get_tree().create_timer(duration, true, false, true)
	await timer.timeout
	# Only restore if nothing else changed it meanwhile.
	if is_equal_approx(Engine.time_scale, scale):
		Engine.time_scale = prev


## Full-screen color flash that fades out.
func flash(color: Color = Color.WHITE, intensity: float = 0.5, fade: float = 0.25) -> void:
	if _flash == null:
		return
	_flash.color = Color(color.r, color.g, color.b, 1.0)
	_flash.modulate.a = intensity
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, fade)


## Mobile haptic pulse (no-op on desktop).
func haptic(ms: int = 30) -> void:
	var os := OS.get_name()
	if os == "iOS" or os == "Android":
		Input.vibrate_handheld(ms)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)

	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_flash.offset_left = 0.0
	_flash.offset_top = 0.0
	_flash.offset_right = 0.0
	_flash.offset_bottom = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
