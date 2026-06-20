## Coin — a collectible that scrolls down the road in trails. Weave to grab
## them; each adds to the persistent coin currency (and a little score).

extends Area3D

## A gentle always-on grab radius (smaller than the lane gap of 2.75 so it never
## yanks coins from an adjacent lane you didn't commit to — pure forgiveness/snap).
const AUTO_MAGNET_RADIUS := 2.6

var approach_speed: float = 15.0
var highway_ref: Node3D = null
var player_ref: Node3D = null

var _spin: float = 0.0
@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.84, 0.2)
		mat.metallic = 0.7
		mat.roughness = 0.25
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.78, 0.15)
		mat.emission_energy_multiplier = 1.5
		_mesh.material_override = mat


func _physics_process(delta: float) -> void:
	position.z += approach_speed * delta
	_spin += delta * 4.0

	# Magnet: the powerup pulls from far; otherwise a gentle close-range grab that
	# accelerates as the coin nears the player, so weaving near a coin snaps it in.
	if player_ref and is_instance_valid(player_ref):
		var dist := global_position.distance_to(player_ref.global_position)
		if PowerUpManager.is_magnet_active() and dist < PowerUpManager.MAGNET_RADIUS:
			global_position = global_position.move_toward(player_ref.global_position, delta * 24.0)
		elif dist < AUTO_MAGNET_RADIUS:
			var pull := lerpf(26.0, 7.0, dist / AUTO_MAGNET_RADIUS)
			global_position = global_position.move_toward(player_ref.global_position, delta * pull)
	if _mesh:
		_mesh.rotation.y = _spin
		var curve := 0.0
		if highway_ref and highway_ref.has_method("get_curve_offset"):
			curve = highway_ref.get_curve_offset(global_position.z)
		_mesh.position.x = curve
	if position.z > 20.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is PlayerController:
		GameManager.collect_coin()
		AudioManager.play_coin(GameManager.coin_streak)
		_spawn_sparkle(GameManager.coin_streak)
		Juice.add_trauma(0.04)
		queue_free()


## A short-lived gold sparkle burst at the pickup point. Parented to the spawner so
## it survives this coin's queue_free; self-frees after burnout. Brighter with streak.
func _spawn_sparkle(streak: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var t := clampf(float(streak) / 10.0, 0.0, 1.0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.88, 0.4)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	grad.set_color(1, Color(1.0, 0.7, 0.2, 0.0))

	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.1))

	var p := CPUParticles3D.new()
	p.mesh = quad
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 8 + int(8.0 * t)
	p.lifetime = 0.45
	p.direction = Vector3(0, 1, 0)
	p.spread = 75.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0 + 2.0 * t
	p.gravity = Vector3(0, -7.0, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.0 + 0.4 * t
	p.scale_amount_curve = sc
	p.color_ramp = grad
	parent.add_child(p)
	p.global_position = global_position
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)
