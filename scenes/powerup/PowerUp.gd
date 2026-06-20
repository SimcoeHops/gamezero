## PowerUp — a glowing GATE that scrolls down the road toward the player.
##
## You collect it by running through the ring. Set [member type], [member color]
## and [member label_text] before adding it to the tree (the spawner does). On
## contact with the player it applies its effect via [PowerUpManager] and frees
## itself. The big lit ring + floating word make each power-up unmistakable.

extends Area3D

## One of PowerUpManager.Type.
var type: int = 0

## Display / emission color.
var color: Color = Color.WHITE

## Short word shown floating in the gate (e.g. "SPEED", "STAR", "LASER").
var label_text: String = ""

## If set, this gate grants a gun (GunManager id) instead of a PowerUpManager
## effect. The [member type] is ignored when this is non-empty.
var gun_id: String = ""

## Forward scroll speed (matched to the road by the spawner).
var approach_speed: float = 15.0

var player_ref: Node3D = null
var highway_ref: Node3D = null

var _t: float = 0.0

@onready var _gate: Node3D = $Gate
var _ring: MeshInstance3D
var _curtain: MeshInstance3D
var _label: Label3D
var _light: OmniLight3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_gate()


## Builds the gate visuals in code so each gate is tinted to its power-up:
## a bright emissive ring, a translucent energy curtain, a floating word, and
## a colored light that spills onto the road so it's easy to spot from far off.
func _build_gate() -> void:
	# Ring you run through.
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.28
	torus.rings = 24
	torus.ring_segments = 16
	_ring.mesh = torus
	_ring.rotation_degrees.x = 90.0  # stand the donut up so the hole faces the player
	_ring.material_override = _glow_material(color, 3.2, 1.0)
	_gate.add_child(_ring)

	# Translucent energy curtain filling the ring.
	_curtain = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.05, 2.05)
	_curtain.mesh = quad
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.albedo_color = Color(color.r, color.g, color.b, 0.14)
	_curtain.mesh.material = cm
	_curtain.position.z = -0.02
	_gate.add_child(_curtain)

	# Floating word so the player instantly knows what the gate grants.
	_label = Label3D.new()
	_label.text = label_text
	_label.font_size = 130
	_label.outline_size = 30
	_label.modulate = Color(1, 1, 1)
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.pixel_size = 0.0042
	_label.position = Vector3(0, 0, 0.05)
	_label.render_priority = 2
	_gate.add_child(_label)

	# Colored glow on the road around the gate.
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 3.0
	_light.omni_range = 7.0
	_light.position = Vector3(0, 0.1, 0)
	_gate.add_child(_light)


## Emissive, lightly transparent material for the ring.
func _glow_material(c: Color, emission_energy: float, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(c.r, c.g, c.b, alpha)
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = emission_energy
	mat.metallic = 0.0
	mat.roughness = 0.4
	return mat


func _physics_process(delta: float) -> void:
	position.z += approach_speed * delta
	_t += delta

	# Gentle pulse + spin so the gate shimmers and draws the eye.
	var pulse := 1.0 + sin(_t * 4.0) * 0.06
	_gate.scale = Vector3(pulse, pulse, pulse)
	if _ring:
		_ring.rotation.z = _t * 1.4
	if _light:
		_light.light_energy = 2.6 + sin(_t * 4.0) * 0.8

	# Follow the road's cosmetic curve + hills (visual only) and bob a touch.
	var curve := 0.0
	var hill := 0.0
	if highway_ref and highway_ref.has_method("get_curve_offset"):
		curve = highway_ref.get_curve_offset(global_position.z)
	if highway_ref and highway_ref.has_method("get_height_offset"):
		hill = highway_ref.get_height_offset(global_position.z)
	_gate.position.x = curve
	_gate.position.y = 1.2 + hill + sin(_t * 2.0) * 0.06

	if position.z > 20.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is PlayerController:
		# While the star is active you can't pick up any NEW power (gun or orb) —
		# the only thing that gets through is a DRAIN. Let the gate scroll on past
		# harmlessly instead of collecting it.
		if PowerUpManager.is_invincible():
			var is_drain := gun_id == "" and type == PowerUpManager.Type.DRAIN
			if not is_drain:
				return
		# Gun gates grant a stacking auto-fire gun; everything else is an orb effect.
		if gun_id != "":
			GunManager.add_gun(gun_id)
			PowerUpManager.announce_pickup(label_text, color)
			AudioManager.play_unlock()
			Juice.flash(color, 0.2, 0.3)
			Juice.add_trauma(0.16)
			Juice.haptic(24)
			queue_free()
			return
		PowerUpManager.apply(type)
		PowerUpManager.announce_pickup(label_text, color)
		# Feedback: drains feel bad, everything else feels good.
		if type == PowerUpManager.Type.DRAIN:
			AudioManager.play_drain()
			Juice.flash(Color(1.0, 0.2, 0.2), 0.22, 0.3)
			Juice.haptic(40)
		else:
			AudioManager.play_pickup()
			Juice.flash(color, 0.18, 0.25)
			Juice.add_trauma(0.12)
			Juice.haptic(18)
			if type == PowerUpManager.Type.STAR:
				Juice.flash(Color(1.0, 0.9, 0.3), 0.35, 0.5)
		queue_free()
