## BiomeParticles — speed-reactive ambient atmosphere field.
##
## One GPUParticles3D that fills the volume around/in front of the camera with
## drifting motes that stream past as you run, giving each biome a distinct
## airborne identity (Downtown paper/litter, Countryside leaves/pollen,
## Industrial embers, Neon glowing motes). The single biggest "asset-flip →
## art-directed" jump: it unifies the Kenney kits under one atmosphere.
##
## - Speed-reactive: `speed_scale` tracks `GameManager.highway_speed` so the
##   field rushes past faster the faster you run (amplifies the speed pillar).
## - Flow-reactive: a hot clean streak (`GameManager.flow_heat`) thickens and
##   brightens the field, so "in the zone" feels denser and more alive.
## - Cross-fades on biome change: the particle color, density (`amount_ratio`),
##   fall direction and blend mode tween toward the new biome over a few seconds
##   so the air itself transitions between places — never a hard cut.
##
## Built entirely in code (no .tscn) so Main can drop it in and style it. Verify
## the spawn/lifecycle headless; the *look* needs a human playtest (GPU).

extends GPUParticles3D

## Per-biome recipe, keyed by the highway theme name. `color` is the particle
## tint (alpha = peak opacity); `glow` routes it through an additive, HDR-bright
## draw pass so the bloom post picks it up (embers/neon). `gravity_y` lets
## leaves fall and embers rise; `ratio` is the steady-state density.
const BIOMES := {
	"DOWNTOWN": {
		"color": Color(0.86, 0.84, 0.74, 0.5),  # pale paper / litter
		"glow": false, "gravity_y": -1.4, "ratio": 0.9, "drift": 1.0,
		"scale_min": 0.10, "scale_max": 0.26, "vel_min": 3.0, "vel_max": 7.5,
	},
	"COUNTRYSIDE": {
		"color": Color(0.78, 0.86, 0.34, 0.55),  # leaves / pollen
		"glow": false, "gravity_y": -1.8, "ratio": 0.7, "drift": 1.7,
		"scale_min": 0.13, "scale_max": 0.30, "vel_min": 2.5, "vel_max": 6.5,
	},
	"INDUSTRIAL": {
		"color": Color(1.5, 0.62, 0.16, 0.85),  # rising embers (HDR-bright)
		"glow": true, "gravity_y": 1.1, "ratio": 0.55, "drift": 1.3,
		"scale_min": 0.05, "scale_max": 0.15, "vel_min": 3.5, "vel_max": 8.0,
	},
	"NEON CITY": {
		"color": Color(1.4, 0.5, 1.35, 0.8),  # glowing magenta motes (HDR-bright)
		"glow": true, "gravity_y": 0.25, "ratio": 0.8, "drift": 0.8,
		"scale_min": 0.07, "scale_max": 0.20, "vel_min": 2.0, "vel_max": 5.5,
	},
}

const _DEFAULT := "DOWNTOWN"

var _pm: ParticleProcessMaterial
var _mat: StandardMaterial3D
var _color_tween: Tween
var _glow := false


func _ready() -> void:
	# Fill the volume around and ahead of the camera (camera at z≈12, looks -Z).
	position = Vector3(0.0, 6.5, -10.0)
	amount = 170
	lifetime = 6.0
	preprocess = 3.0  # start already full of particles, no warm-up emptiness
	explosiveness = 0.0
	randomness = 0.6
	fixed_fps = 30
	local_coords = false
	draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_pm.emission_box_extents = Vector3(15.0, 7.5, 26.0)
	_pm.direction = Vector3(0.0, 0.0, 1.0)  # stream toward / past the camera
	_pm.spread = 22.0
	_pm.flatness = 0.0
	_pm.turbulence_enabled = true
	_pm.turbulence_noise_strength = 1.2
	_pm.turbulence_noise_scale = 1.4
	_pm.turbulence_influence_min = 0.05
	_pm.turbulence_influence_max = 0.25
	_pm.alpha_curve = _build_alpha_curve()
	process_material = _pm

	# Soft round billboard sprite shared by all biomes; color comes from the
	# per-particle tint (set via the process material), blend mode flips per biome.
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat.billboard_keep_scale = true
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_texture = _build_dot_texture()
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_receive_shadows = true
	_mat.no_depth_test = false
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = _mat
	draw_pass_1 = quad

	emitting = true
	apply_biome(_DEFAULT, true)


func _process(_delta: float) -> void:
	# Speed-reactive: the field streams past faster the faster you run, and a
	# hot clean streak (flow_heat) pushes it harder still.
	var speed_t := clampf((GameManager.highway_speed - 12.0) / 48.0, 0.0, 1.0)
	var flow: float = GameManager.flow_heat
	speed_scale = lerpf(0.55, 2.3, speed_t) + flow * 0.5


## Re-style the field for [param biome_name]. Cross-fades color + density +
## fall direction over a few seconds (instant on first apply).
func apply_biome(biome_name: String, instant: bool = false) -> void:
	var cfg: Dictionary = BIOMES.get(biome_name, BIOMES[_DEFAULT])
	var col: Color = cfg["color"]
	var ratio: float = cfg["ratio"]
	var grav := Vector3(0.0, cfg["gravity_y"], 0.0)
	var glow: bool = cfg["glow"]

	# Per-biome motion + size apply immediately (only affects newly spawned
	# particles, so it eases in naturally as the field recycles).
	_pm.gravity = grav
	_pm.scale_min = cfg["scale_min"]
	_pm.scale_max = cfg["scale_max"]
	_pm.initial_velocity_min = cfg["vel_min"]
	_pm.initial_velocity_max = cfg["vel_max"]
	_pm.turbulence_noise_strength = 0.9 + float(cfg["drift"]) * 0.8

	# Blend mode flips with the glow flag (additive for embers/neon so they bloom).
	if glow != _glow or instant:
		_glow = glow
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glow else BaseMaterial3D.BLEND_MODE_MIX

	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()

	if instant:
		_pm.color = col
		amount_ratio = ratio
		return

	_color_tween = create_tween().set_parallel(true)
	_color_tween.tween_property(_pm, "color", col, 3.0)
	_color_tween.tween_property(self, "amount_ratio", ratio, 3.0)


## Alpha ramp over a particle's life: fade in, hold, fade out — no hard pops.
func _build_alpha_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.18, 1.0))
	curve.add_point(Vector2(0.72, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


## Soft round dot so each particle reads as a glowing mote, not a hard square.
func _build_dot_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.55, Color(1, 1, 1, 0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex
