shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled,
	fog_disabled;

// The house particle shader: one material for every puff, plume and billow in
// the game.
//
// Why unshaded when the point is that smoke picks up the key light? Because
// real lighting on a camera-facing card is wrong by construction — the quad's
// normal always points at the camera, so a directional light either blasts
// every particle evenly or misses them all, and neither looks like smoke. What
// smoke actually does is scatter: it is bright where it is thin, bright when
// you look through it toward the sun, and it sits in the key light's colour
// rather than in white. All three of those are faked here, by hand, with
// uniforms an artist can push — which is also why every puff in a level can be
// re-keyed to that level's sun by changing two colours.
//
// The four things a StandardMaterial3D billboard cannot do, and this can:
//
//  * SOFT DEPTH. Particles fade out where they intersect geometry instead of
//    slicing it with a hard quad edge. This single feature is most of the
//    difference between "particle system" and "atmosphere".
//  * EROSION. The puff breaks up over its life instead of dissolving uniformly
//    to zero. Smoke thins into rags; it does not get transparent.
//  * PER-PARTICLE ROTATION, done here rather than left to the process
//    material, because we billboard by hand and therefore have to.
//  * SCATTER. See above.
//
// It is authored for billboard puffs. Velocity-stretched sparks want
// GPUParticles3D.transform_align instead, which this shader's hand-rolled
// billboard would override.

group_uniforms Shape;
uniform vec4 tint : source_color = vec4(0.72, 0.66, 0.58, 1.0);
// Optional mask on top of the built-in soft disc. Leave white for pure smoke.
uniform sampler2D shape_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float soft_edge : hint_range(0.01, 1.0) = 0.75;
uniform float alpha_scale : hint_range(0.0, 2.0) = 1.0;
// Values above 1.0 are deliberate: they are what the glow pass picks up. Keep
// it under ~1.5 for anything fire-coloured or it tonemaps to flat white.
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float fade_in : hint_range(0.0, 0.5) = 0.10;
uniform float fade_out : hint_range(0.0, 1.0) = 0.45;

group_uniforms Rotation;
uniform float custom_angle_scale = 1.0;
uniform float rotation_offset = 0.0;
uniform float rotation_random : hint_range(0.0, 3.2) = 3.14;

group_uniforms Erosion;
uniform sampler2D erode_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float erode_amount : hint_range(0.0, 1.0) = 0.65;
uniform float erode_scale = 1.6;
uniform float erode_softness : hint_range(0.02, 0.8) = 0.22;

group_uniforms Scatter;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 key_color : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.34, 0.40, 0.52, 1.0);
// World-space direction the key light travels (sun forward vector).
uniform vec3 key_dir = vec3(-0.55, -0.62, -0.55);
uniform float scatter : hint_range(0.0, 1.0) = 0.55;
uniform float back_scatter : hint_range(0.0, 1.0) = 0.45;
uniform float depth_fade : hint_range(0.0, 4.0) = 0.45;
uniform float near_fade : hint_range(0.0, 4.0) = 0.35;

varying float part_age;
varying float part_seed;


void vertex() {
	// A stable per-particle random. Hashing the world position would re-roll
	// every frame as the particle moves, and the erosion pattern would swim.
	part_seed = fract(sin(float(INSTANCE_ID) * 12.9898 + 4.137) * 43758.5453);
	// ParticleProcessMaterial packs the normalised age into CUSTOM.y and the
	// per-particle lifetime randomness into CUSTOM.w, so the real age is the
	// ratio of the two. Reading .w as the age — the obvious guess — makes every
	// puff in the game invisible, because .w sits at 1.0 and the life envelope
	// closes on frame one. The max() keeps this usable on a plain mesh, where
	// INSTANCE_CUSTOM is all zeros.
	part_age = clamp(INSTANCE_CUSTOM.y / max(INSTANCE_CUSTOM.w, 0.001), 0.0, 1.0);

	// Spin in the quad's own plane, before the billboard basis replaces the
	// model matrix. CUSTOM.x is the angle the process material integrated.
	float ang = INSTANCE_CUSTOM.x * custom_angle_scale + rotation_offset
		+ (part_seed - 0.5) * 2.0 * rotation_random;
	float ca = cos(ang);
	float sa = sin(ang);
	VERTEX.xy = vec2(VERTEX.x * ca - VERTEX.y * sa, VERTEX.x * sa + VERTEX.y * ca);

	// Hand-rolled billboard: take the camera's basis, keep the particle's
	// origin, then re-apply the per-particle scale the basis swap discarded.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}


void fragment() {
	// Soft disc in quad space, so it spins with the card.
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float shape = 1.0 - smoothstep(1.0 - soft_edge, 1.0, d);
	shape *= texture(shape_tex, UV).r;

	// Erosion: a rising cut through a noise field. The puff tears into rags
	// instead of fading out as a whole, which is what separates smoke from a
	// dimming sprite.
	vec2 nuv = UV * erode_scale + vec2(part_seed * 7.3, part_seed * 3.1);
	float n = texture(erode_noise, nuv).r;
	float cut = mix(-0.25, 1.0, part_age);
	float eroded = smoothstep(cut, cut + erode_softness, n);
	float a = shape * mix(1.0, eroded, erode_amount);

	// Life envelope. The fade-in matters: a puff that exists at full opacity on
	// frame one pops.
	a *= smoothstep(0.0, max(fade_in, 0.001), part_age);
	a *= 1.0 - smoothstep(1.0 - fade_out, 1.0, part_age);
	a *= COLOR.a * alpha_scale;

	// Soft particles. Without this every puff cuts a straight line across the
	// floor it is sitting on.
	float self_z = -VERTEX.z;
	if (depth_fade > 0.0) {
		float raw = texture(depth_tex, SCREEN_UV).r;
		vec4 view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV * 2.0 - 1.0, raw), 1.0);
		float scene_z = -(view.z / view.w);
		a *= clamp((scene_z - self_z) / depth_fade, 0.0, 1.0);
	}
	a *= smoothstep(near_fade * 0.25, max(near_fade, 0.001), self_z);

	// Scatter. Thin edges catch the most light, and looking through the puff
	// toward the key adds the rim that sells backlit smoke at dawn.
	vec3 kd = normalize((VIEW_MATRIX * vec4(normalize(key_dir), 0.0)).xyz);
	vec3 to_frag = normalize(VERTEX);
	float through = clamp(dot(to_frag, kd), 0.0, 1.0);
	float thin = 1.0 - clamp(shape, 0.0, 1.0);
	float lit = clamp(scatter * (0.30 + 0.70 * thin) + back_scatter * through * through,
		0.0, 1.0);

	ALBEDO = tint.rgb * COLOR.rgb * mix(shadow_color.rgb, key_color.rgb, lit) * brightness;
	ALPHA = clamp(a, 0.0, 1.0);
}
