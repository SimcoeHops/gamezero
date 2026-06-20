// Highway UV-scroll shader
// Scrolls the road texture along the V axis to simulate forward motion.
// Control scroll_speed from GDScript via ShaderMaterial.set_shader_parameter().

shader_type spatial;

uniform float scroll_speed : hint_range(0.0, 100.0) = 5.0;
uniform sampler2D road_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 road_tint : source_color = vec4(0.15, 0.15, 0.18, 1.0);
uniform float texture_scale : hint_range(0.1, 20.0) = 4.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec2 uv = UV * texture_scale;
	uv.y += TIME * scroll_speed;

	vec4 tex_color = texture(road_texture, uv);
	ALBEDO = tex_color.rgb * road_tint.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
