shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled,
	fog_disabled;

// Aurora curtain.
//
// An aurora is not a horizontal band with noise on it. It is a SHEET hanging in
// the magnetic field: the structure runs vertically in rays, the sheet has a
// hem at the bottom that folds and swings, and the whole thing dissolves
// upwards over a couple of hundred kilometres so there is no top edge at all.
// Anything with a visible boundary reads as a decal on the sky.
//
// Colour is not decoration either. Atomic oxygen at ~100 km gives the green at
// 557.7 nm; higher up, thinner, you get the red-violet 630 nm line. So green
// lives at the hem and magenta at the crown, and that vertical ramp is the one
// cue that makes a painted aurora read as a real one.
//
// Expects 0..1 UVs, so drive it with a QuadMesh — LevelKit's chamfered boxes
// carry planar UVs measured in METRES, which would put the whole profile
// outside its range and kill the shader silently.

uniform vec4 tint_hem : source_color = vec4(0.30, 1.00, 0.62, 1.0);
uniform vec4 tint_crown : source_color = vec4(0.72, 0.36, 1.00, 1.0);
uniform float strength : hint_range(0.0, 4.0) = 0.9;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
// Ribbons across the curtain. High across x, almost none along y: that
// anisotropy IS the look.
uniform float ray_scale : hint_range(1.0, 60.0) = 16.0;
uniform float drift_speed = 0.012;
uniform float base_fade : hint_range(0.0, 1.0) = 0.55;
// How much of the quad the hem swings through, and how fast it swings.
uniform float hem_height : hint_range(0.0, 0.6) = 0.26;
uniform float hem_speed : hint_range(0.0, 2.0) = 0.35;
// Low-frequency gaps. A curtain that spans its whole quad evenly is a rectangle.
uniform float presence_scale : hint_range(0.1, 6.0) = 1.3;


void fragment() {
	// QuadMesh: UV.y is 0 at the top, 1 at the bottom.
	float x = UV.x;

	// The hem. Two waves at different frequencies so the bottom edge swings as
	// one sheet rather than rippling like a flag — an aurora folds, it does not
	// flutter.
	float wave = sin(x * 7.0 + TIME * hem_speed) * 0.5
		+ sin(x * 19.0 - TIME * hem_speed * 0.63) * 0.5;
	float hem = 1.0 - hem_height * (0.5 + 0.5 * wave);
	// Renormalised so the hem always sits at v = 1 regardless of how it swung.
	float v = UV.y / max(hem, 0.05);

	// Vertical rays, two layers drifting at different rates so nothing repeats.
	float r1 = texture(noise_tex, vec2(x * ray_scale + TIME * drift_speed, v * 0.11)).r;
	float r2 = texture(noise_tex, vec2(x * ray_scale * 2.7 - TIME * drift_speed * 1.6,
		v * 0.07)).r;
	float rays = pow(clamp(r1 * 0.62 + r2 * 0.52, 0.0, 1.0), 2.6);

	// Vertical profile: a long fade in from nothing at the crown, a brightening
	// into the hem, then a soft release past it. Three smooth terms, no edges.
	float crown = pow(clamp(v, 0.0, 1.0), 1.5);
	float hem_glow = smoothstep(0.52, 1.0, v) * 1.5;
	float release = 1.0 - smoothstep(1.0, 1.22, v);
	float profile = (crown + hem_glow) * release;

	// Gaps across the sheet, drifting slower than the rays do.
	float presence = texture(noise_tex,
		vec2(x * presence_scale + TIME * drift_speed * 0.45, 0.37)).r;
	presence = smoothstep(0.26, 0.70, presence);

	// And no side edges either.
	float ends = smoothstep(0.0, 0.16, x) * smoothstep(1.0, 0.84, x);

	ALBEDO = mix(tint_crown.rgb, tint_hem.rgb, smoothstep(0.1, 0.95, v));
	ALPHA = clamp(rays * profile * presence * ends * strength * base_fade, 0.0, 1.0);
}
