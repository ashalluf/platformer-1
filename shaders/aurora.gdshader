shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// Aurora curtain.
//
// A flat additive quad with hard edges reads as a pane of glass. This gives it
// vertical streaking, a soft top and bottom, and a slow horizontal drift, which
// is all an aurora actually is at this distance.

uniform vec4 tint : source_color = vec4(0.35, 1.0, 0.72, 1.0);
uniform float strength : hint_range(0.0, 4.0) = 0.9;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float streak_scale = 3.0;
uniform float drift_speed = 0.012;
uniform float base_fade : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 uv = UV;
	// Curtains hang: bright at the top, dissolving toward the bottom.
	float vertical = pow(1.0 - uv.y, 1.6) * smoothstep(0.0, 0.18, uv.y);

	// Two noise layers drifting at different rates give the ribboning.
	float a = texture(noise_tex, vec2(uv.x * streak_scale + TIME * drift_speed, uv.y * 0.4)).r;
	float b = texture(noise_tex, vec2(uv.x * streak_scale * 2.3 - TIME * drift_speed * 1.7,
		uv.y * 0.25)).r;
	float streak = pow(clamp(a * 0.65 + b * 0.55, 0.0, 1.0), 2.2);

	// Fade at the horizontal ends so the quad has no visible edge.
	float ends = smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x);

	ALBEDO = tint.rgb;
	ALPHA = vertical * streak * ends * strength * base_fade;
}
