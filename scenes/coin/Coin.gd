## Coin — a collectible that scrolls down the road in trails. Weave to grab
## them; each adds to the persistent coin currency (and a little score).

extends Area3D

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

	# Magnet: home toward the player when active and within range.
	if player_ref and PowerUpManager.is_magnet_active():
		if global_position.distance_to(player_ref.global_position) < PowerUpManager.MAGNET_RADIUS:
			global_position = global_position.move_toward(player_ref.global_position, delta * 24.0)
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
		AudioManager.play_coin()
		Juice.add_trauma(0.04)
		queue_free()
