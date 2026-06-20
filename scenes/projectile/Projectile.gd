## Projectile — weapon shot for the player's fire modes.
##
## Travels along its own forward (-Z) axis, so it can be aimed by rotating the
## instance (used for multi-shot spread). Crumples cars on contact. When
## [member piercing] is true it passes through and keeps going (laser / net).

extends Area3D

## Speed in m/s.
@export var speed: float = 50.0

## Maximum distance before auto-destruct.
@export var max_range: float = 80.0

## If true, the shot is not consumed on hit (hits multiple cars).
@export var piercing: bool = false

## If > 0, the shot crumples every car within this radius on impact (mortar).
@export var aoe_radius: float = 0.0

## If > 0, the shot arcs under gravity instead of flying straight (mortar lob).
@export var lob_gravity: float = 0.0

## Initial upward velocity for a lobbed shot.
@export var lob_vy: float = 0.0

## Optional per-gun color (alpha 0 = leave the default look).
var tint: Color = Color(0, 0, 0, 0)

## Hit corridor radius for the swept collision test (0 = use a sane default). The
## wide NET sets this large so it catches a cluster of cars.
@export var hit_radius: float = 0.0

var _distance_traveled: float = 0.0
var _vy: float = 0.0
## Once freed/exploded, stop doing any further work this frame.
var _dead: bool = false
## Cars already hit by a piercing shot, so it doesn't re-crumple them every frame.
var _hit_cars: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_vy = lob_vy
	_apply_tint()

	# Safety-net auto-destruct.
	var timer := Timer.new()
	timer.wait_time = max_range / speed + 0.5
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()


## Recolors the shot's mesh to the gun's color when a tint is supplied.
func _apply_tint() -> void:
	if tint.a <= 0.0:
		return
	var mi := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 3.0
	mi.set_surface_override_material(0, mat)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var step := speed * delta
	if lob_gravity > 0.0:
		# Ballistic lob: move forward along the ground plane, arc vertically.
		var fwd := -global_transform.basis.z
		fwd.y = 0.0
		if fwd.length() > 0.001:
			fwd = fwd.normalized()
		global_position += fwd * step
		global_position.y += _vy * delta
		_vy -= lob_gravity * delta
		_distance_traveled += step
		if global_position.y <= 0.25 and _vy < 0.0:
			_explode()
			return
	else:
		var from := global_position
		global_position += -global_transform.basis.z.normalized() * step
		_distance_traveled += step
		# Swept test along the path travelled this frame. Area3D.body_entered only
		# samples overlap at each physics step, so a fast shot can tunnel straight
		# through a thin car between steps — this catches those misses.
		_sweep_hit(from, global_position)
		if _dead:
			return

	if _distance_traveled >= max_range:
		_kill()


## Crumples any car whose centre is within the hit corridor of the segment
## [param a]→[param b] travelled this frame.
func _sweep_hit(a: Vector3, b: Vector3) -> void:
	var seg := b - a
	var seg_len2 := seg.length_squared()
	var r := (hit_radius if hit_radius > 0.0 else 0.9) + 0.6  # + car half padding
	for car in get_tree().get_nodes_in_group("cars"):
		var c := car as Node3D
		if c == null or not c.has_method("crumple"):
			continue
		if _hit_cars.has(c.get_instance_id()):
			continue
		var p := c.global_position
		var t := 0.0
		if seg_len2 > 0.000001:
			t = clampf((p - a).dot(seg) / seg_len2, 0.0, 1.0)
		if p.distance_to(a + seg * t) <= r:
			_hit(c)
			if _dead:
				return


func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body.has_method("crumple") and not _hit_cars.has(body.get_instance_id()):
		_hit(body)


## Applies this shot's effect to one car.
func _hit(car: Node) -> void:
	if aoe_radius > 0.0:
		_explode()
		return
	var impact_vel := -global_transform.basis.z.normalized() * speed
	car.crumple((car as Node3D).global_position, impact_vel)
	if piercing:
		_hit_cars[car.get_instance_id()] = true
	else:
		_kill()


## Frees the projectile and stops any further processing this frame.
func _kill() -> void:
	if _dead:
		return
	_dead = true
	queue_free()


## Crumples every car within [member aoe_radius] of the impact point, with a
## satisfying boom, then frees itself.
func _explode() -> void:
	var here := global_position
	for car in get_tree().get_nodes_in_group("cars"):
		var c := car as Node3D
		if c and c.has_method("crumple") and c.global_position.distance_to(here) <= aoe_radius:
			c.crumple(c.global_position, Vector3(0, 0, 12.0))
	Juice.add_trauma(0.35)
	Juice.flash(Color(1.0, 0.7, 0.25), 0.25, 0.35)
	AudioManager.play_crash()
	_kill()
