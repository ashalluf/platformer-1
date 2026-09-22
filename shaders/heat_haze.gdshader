shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled,
	fog_disabled;

// Heat haze.
//
// A card you hang in front of anything hot — the flare stack, the cracking
// furnace, sun-baked asphalt, the mouth of a steam vent — that re-samples the
// screen behind it through a scrolling noise field. It is the cheapest
// believable "this air is 400 degrees" there is: no particles, no lights, one
// quad, one screen read.
//
// Three things have to be true or it reads as a bug rather than as air:
//
//  1. NO RECTANGLE. The failure mode of every screen-distortion quad is a
//     visible card edge where the warp stops. The mask here goes to exactly
//     zero at both vertical edges (sin() does that for free) and falls off
//     away from the heat source, so the effect has no boundary the eye can
//     find. It is also multiplied by low-frequency noise so the envelope
//     itself is not a clean lens shape.
//  2. HOT AIR RISES. The warp is biased upward every frame. A symmetric
//     wobble reads as underwater; a rising one reads as heat.
//  3. IT MUST NOT SMEAR THE HERO. Depth is sampled and anything standing in
//     FRONT of the card is excluded from the distortion, so Wanis walking past
//     a vent stays crisp while the pipework behind him boils. Without this the
//     effect quietly destroys character readability, which is the one thing
//     this game cannot trade away.
//
// ALPHA is the mask, so at strength 0 the card samples the screen it is
// covering and composites it back unchanged — the effect degrades to nothing
// instead of degrading to a grey box.

group_uniforms Warp;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D warp_noise : hint_default_black, repeat_enable, filter_linear_mipmap;
// In screen UV units. 0.012 is roughly 13 px of swim at 1080p, which is as far
// as this can go before it stops being air and starts being a heat gun.
uniform float strength : hint_range(0.0, 0.06) = 0.012;
uniform float noise_scale = 1.7;
uniform vec2 drift = vec2(0.04, -0.34);
uniform float churn : hint_range(0.0, 4.0) = 1.0;
// Constant upward bias on the warp vector, in warp units.
uniform float rise : hint_range(0.0, 1.0) = 0.30;

group_uniforms Mask;
// Where along the card the heat comes from: 1.0 = bottom edge (ground haze,
// vent mouth), 0.0 = top edge, 0.5 = a band through the middle (a flare tip
// hanging in the sky with air boiling above and below it).
uniform float source_v : hint_range(0.0, 1.0) = 1.0;
uniform float height_falloff : hint_range(0.2, 6.0) = 1.6;
uniform float edge_power : hint_range(0.5, 4.0) = 1.5;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float envelope_break : hint_range(0.0, 1.0) = 0.35;

group_uniforms Depth;
// Geometry nearer than (card - bias) is treated as being in front of the heat.
uniform float occlusion_bias : hint_range(0.0, 4.0) = 0.25;
uniform float occlusion_feather : hint_range(0.01, 4.0) = 0.60;
uniform float near_fade : hint_range(0.0, 8.0) = 1.20;

group_uniforms Tint;
// Hot air scatters: it lifts and slightly desaturates what you see through it.
uniform vec4 tint : source_color = vec4(1.0, 0.88, 0.74, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.10;
uniform float lift : hint_range(0.0, 0.5) = 0.02;


void fragment() {
	float t = TIME * churn;
	vec2 uv = UV * noise_scale;

	// Two decorrelated taps per octave. Sampling one channel twice would give
	// warp.x == warp.y, i.e. a purely diagonal slide, which reads as a texture
	// moving rather than as air moving.
	float nx = texture(warp_noise, uv + drift * t).r;
	float ny = texture(warp_noise, uv * 1.37 + vec2(0.41, 0.17) + drift * t * 1.23).r;
	float mx = texture(warp_noise, uv * 2.90 + drift * t * 1.90).r;
	float my = texture(warp_noise, uv * 3.21 + vec2(0.73, 0.29) + drift * t * 2.20).r;
	vec2 warp = (vec2(nx, ny) - 0.5) + (vec2(mx, my) - 0.5) * 0.45;
	warp.y -= rise;

	// sin() is exactly zero at UV.x 0 and 1, so the card has no vertical edge.
	float across = pow(clamp(sin(UV.x * PI), 0.0, 1.0), edge_power);
	float along = pow(clamp(1.0 - abs(UV.y - source_v), 0.0, 1.0), height_falloff);
	float envelope = texture(warp_noise, uv * 0.55 + drift * t * 0.35).r;
	float mask = across * along * opacity
		* mix(1.0, 0.45 + 1.10 * envelope, envelope_break);

	// Depth rejection. VERTEX is view space in fragment(), so -VERTEX.z is how
	// far the card itself is from the camera.
	float self_z = -VERTEX.z;
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV * 2.0 - 1.0, raw), 1.0);
	float scene_z = -(view.z / view.w);
	mask *= smoothstep(self_z - occlusion_bias - occlusion_feather,
		self_z - occlusion_bias, scene_z);
	// And never shove distortion into the lens when the camera pushes in.
	mask *= smoothstep(near_fade * 0.35, near_fade, self_z);
	mask = clamp(mask, 0.0, 1.0);

	// Clamped so a strong warp at the screen border cannot wrap around and
	// smear the opposite edge of the frame into shot.
	vec2 suv = clamp(SCREEN_UV + warp * strength * mask, vec2(0.002), vec2(0.998));
	vec3 col = textureLod(screen_tex, suv, 0.0).rgb;
	col = mix(col, col * tint.rgb, tint_amount);
	col += tint.rgb * lift * mask;

	ALBEDO = col;
	ALPHA = mask;
}
