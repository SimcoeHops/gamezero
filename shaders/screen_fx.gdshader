// Full-screen overlay: subtle vignette always, radial "warp" speed streaks
// that intensify with speed. Drawn over a transparent rect, no screen read,
// so it's cheap on the mobile renderer.

shader_type canvas_item;
render_mode blend_mix;

uniform float speed_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.85;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 streak_color : source_color = vec4(0.75, 0.88, 1.0, 1.0);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	float ang = atan(c.y, c.x);

	// Vignette toward the corners.
	float vig = smoothstep(0.55, 1.25, r) * vignette_strength;

	// Radial speed streaks, hashed by angle and animated outward.
	float a = (ang + 3.14159265) / 6.2831853;
	float lines = hash(floor(a * 150.0));
	float streak = step(0.84, lines) * smoothstep(0.22, 1.1, r);
	float anim = fract(r * 3.0 - TIME * 2.6);
	streak *= smoothstep(0.0, 0.35, anim) * (1.0 - anim);
	streak *= speed_intensity;

	vec3 col = vignette_color.rgb * vig + streak_color.rgb * streak;
	float alpha = clamp(vig + streak, 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
