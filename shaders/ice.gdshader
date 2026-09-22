shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley,
	specular_schlick_ggx;

// Ice.
//
// The failure mode this shader exists to kill is "pale blue box". A flat tint
// plus a fresnel ramp gives you a box that happens to be blue; it does not give
// you ice, because it gets three facts wrong.
//
//  1. Ice is a VOLUME. Light that goes in has to get back out, and the further
//     it travels the more red it loses — that absorption is the entire reason
//     glacier ice is blue and a chip off the same block is white. So the body
//     colour here saturates along a thickness measured per fragment, not a
//     constant. A snow lip, an icicle, a small shard: white. A six metre wall
//     block: its full deep tint. One term, and the level stops being stacked
//     boxes of a single value.
//  2. Ice has CONTENTS. Cracks and trapped air sit inside the slab, so they
//     must slide against the surface as the camera moves. We march the
//     refracted view ray a couple of slices deep and accumulate ridged noise;
//     it is the relative slide between the slices that reads as depth, not the
//     noise itself.
//  3. Ice is WET. There is a specular sheen on it even at -20, and the
//     up-facing faces carry a rime that is brighter, rougher and slightly
//     crystalline compared to the ice underneath.
//
// Refraction reads the screen copy. On an opaque material that copy is a frame
// stale, which at 60 Hz nobody has ever caught, and it is composited ADDITIVELY
// on purpose: if the buffer has nothing to give (first frame, or a renderer
// that never filled it) the term goes to zero instead of punching a black hole
// through the level. Never ship an effect whose failure mode is a hole.

group_uniforms Body;
// `ice_deep` is the tint, and it means literally the colour a thick piece of
// this ice goes. That is deliberately not an absorption coefficient: nobody can
// predict what a coefficient will look like on a twenty-six metre shelf.
uniform vec4 ice_deep : source_color = vec4(0.055, 0.215, 0.375, 1.0);
uniform vec4 ice_bright : source_color = vec4(0.46, 0.76, 0.94, 1.0);
// Master knob. MaterialLab builds every ice material in this game and it does
// not pass a clarity uniform — it bakes clarity into roughness_value. Rather
// than reach into a file this shader does not own, a negative value means
// "recover whatever the factory implied"; a positive value overrides it.
uniform float clarity : hint_range(-1.0, 1.0) = -1.0;
uniform float depth_gain : hint_range(0.0, 4.0) = 1.6;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.10;
uniform float internal_glow : hint_range(0.0, 4.0) = 0.18;
// Scales the measured half-thickness. Turn it down on background masses that
// are modelled huge but should not read as opaque navy.
uniform float thickness_scale : hint_range(0.02, 4.0) = 1.0;

group_uniforms Interior;
uniform float crack_density : hint_range(0.0, 3.0) = 1.0;
uniform float crack_scale : hint_range(0.05, 4.0) = 0.45;
uniform float crack_sharpness : hint_range(1.0, 24.0) = 9.0;
uniform float bubble_amount : hint_range(0.0, 3.0) = 0.7;
uniform float bubble_scale : hint_range(1.0, 40.0) = 7.0;
// Slice separation in metres. This is the parallax budget: too small and the
// interior sticks to the surface, too large and it swims.
uniform float parallax_depth : hint_range(0.0, 4.0) = 0.9;
// The march is the expensive part of this shader and it is invisible past a
// few metres, so it is faded out rather than paid for on every background box.
uniform float interior_fade_start = 16.0;
uniform float interior_fade_end = 44.0;

group_uniforms Rime;
uniform vec4 frost_color : source_color = vec4(0.80, 0.88, 0.96, 1.0);
// Coverage: how much of an up-facing surface takes rime at all.
uniform float frost_amount : hint_range(0.0, 1.0) = 0.55;
// Strength: how hard that rime whitens and roughens what it covers. Split from
// coverage because a thin hard rime and a thick soft one are different weather.
uniform float rime_amount : hint_range(0.0, 2.0) = 1.0;
uniform float frost_sharpness : hint_range(1.0, 12.0) = 2.6;
uniform sampler2D frost_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float frost_scale = 0.6;
// Rime has relief. Two extra taps give a gradient and a gradient is a normal —
// cheaper than shipping a frost normal map, and it stays in register with the
// mask that placed the frost in the first place.
uniform float frost_relief : hint_range(0.0, 3.0) = 0.9;

group_uniforms Refraction;
// filter_linear, not filter_linear_mipmap: asking for mips on the screen copy
// makes the renderer build a whole mip chain every frame, and a one-tap
// refraction offset of three screen percent has no use for them.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// 0.035 of SCREEN_UV is forty-five pixels at 1280 wide. That is not a one-tap
// refraction, it is a displaced copy of the framebuffer laid over every ice
// surface in the scene — and because the result is ADDED to the emission term
// below rather than blended, overlapping seracs compound it. Measured on an
// IceBonus01 capture that produced two things at once: an image that read as
// uniformly out of focus above the water line, and a contrast ratio of 2.3:1
// in a scene whose lighting budget was set to 3.2:1, because every ice surface
// was adding a smeared copy of its own background back into itself.
//
// Ten pixels is a refraction. Forty-five is a smear.
uniform float refraction : hint_range(0.0, 2.0) = 0.18;
uniform float refraction_offset : hint_range(0.0, 0.2) = 0.008;

group_uniforms Sheen;
// A second, much smoother specular lobe over whatever the surface is. It is
// the difference between "cold stone" and "ice you would not walk on".
uniform float sheen : hint_range(0.0, 1.0) = 0.55;

group_uniforms Sparkle;
uniform float sparkle_amount : hint_range(0.0, 8.0) = 3.0;
// Cells per metre. Small and sparse: a glint is a point of light, not a tile.
uniform float sparkle_density = 26.0;
uniform float sparkle_threshold : hint_range(0.5, 0.999) = 0.982;
// Past this, a glint is smaller than a pixel and all it can do is alias.
uniform float sparkle_fade_distance = 34.0;

varying vec3 world_pos;
varying vec3 world_nrm;
varying vec3 local_pos;
varying vec3 local_nrm;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	local_pos = VERTEX;
	local_nrm = NORMAL;
}


float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}


float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}


// A sparse field of points with a smooth radial falloff. The version this
// replaced filled whole hash cells, which is exactly why the ice looked like it
// had confetti stuck to it.
float glint_field(vec3 p, float thresh) {
	vec3 cell = floor(p);
	float s = hash13(cell);
	if (s < thresh) {
		return 0.0;
	}
	vec3 f = p - cell;
	vec3 jit = vec3(hash13(cell + 1.7), hash13(cell + 5.1), hash13(cell + 9.3));
	float k = (s - thresh) / max(1.0 - thresh, 1e-4);
	return smoothstep(0.30, 0.0, length(f - jit)) * k;
}


void fragment() {
	vec3 n = normalize(world_nrm);
	vec3 wv = normalize(CAMERA_POSITION_WORLD - world_pos);
	float cl = clarity >= 0.0 ? clarity : clamp((0.55 - roughness_value) / 0.47, 0.0, 1.0);

	// --- Thickness ----------------------------------------------------------
	// Distance from the model origin to this face along its own normal, i.e.
	// half the slab in the direction we are looking into it. LevelKit centres
	// every chamfered box on its origin, so for the vocabulary the levels are
	// actually built from this is exact, and it degrades sanely for anything
	// else. Grazing angles travel further through the same slab.
	float half_thick = dot(abs(local_pos), abs(normalize(local_nrm)));
	float facing = clamp(dot(n, wv), 0.0, 1.0);
	// Clamped, and it has to be. Absorption through an unbounded path takes a
	// twenty-six metre shelf to zero, and a black platform is not deep ice, it
	// is a bug. Past about six metres real glacier ice has saturated anyway:
	// it goes no deeper, it just stops getting any lighter.
	float path = clamp(half_thick * 2.0 * thickness_scale / max(facing, 0.35),
		0.0, 6.0);
	// Saturating exponential rather than raw Beer-Lambert, so `ice_deep` keeps
	// meaning what an artist expects it to mean — the colour a thick piece goes
	// — instead of being an absorption coefficient nobody can predict.
	float saturation = 1.0 - exp(-path * depth_gain * 0.55);
	vec3 body = mix(ice_bright.rgb, ice_deep.rgb, saturation);

	// Grazing is also where reflection takes over from transmission, so the
	// silhouette of every mass comes back up to white. Thickness and fresnel
	// pull against each other and the narrow band where they cross is the
	// bright rind you see on a real serac.
	float fres = pow(1.0 - facing, 3.4);
	body = mix(body, ice_bright.rgb, fres * 0.72);

	// --- Interior -----------------------------------------------------------
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(interior_fade_start, interior_fade_end, dist);
	float veins = 0.0;
	float bubbles = 0.0;
	if (near > 0.001 && cl > 0.02) {
		// Refracted ray into the slab; ice is n = 1.31.
		vec3 rd = refract(-wv, n, 0.763);
		rd = dot(rd, rd) < 1e-5 ? -wv : normalize(rd);

		vec3 s0 = world_pos + rd * parallax_depth * 0.6;
		vec3 s1 = world_pos + rd * parallax_depth * 2.1;

		// Ridged noise: the zero crossing of a noise field is a surface, and a
		// thin band either side of it is a crack. Plain fbm would read as
		// marble, which is a rock, which is the wrong material entirely.
		float f0 = vnoise(s0 * crack_scale) * 0.65
			+ vnoise(s0 * crack_scale * 2.13 + 11.3) * 0.35;
		float f1 = vnoise(s1 * crack_scale * 1.9 + 4.7);
		veins = pow(clamp(1.0 - abs(f0 * 2.0 - 1.0), 0.0, 1.0), crack_sharpness)
			+ pow(clamp(1.0 - abs(f1 * 2.0 - 1.0), 0.0, 1.0), crack_sharpness) * 0.45;
		bubbles = glint_field(s1 * bubble_scale, 0.968);

		veins *= crack_density * cl * near;
		bubbles *= bubble_amount * cl * near;
	}

	// --- Rime ---------------------------------------------------------------
	// Rime accretes on anything facing up, and the line where it stops is never
	// a clean latitude — it is broken by whatever it is sitting on.
	float up = clamp(n.y, 0.0, 1.0);
	vec2 rp = world_pos.xz * frost_scale;
	float grain = texture(frost_noise, rp).r;
	float rime = clamp(pow(up, frost_sharpness) * frost_amount * rime_amount
		* (0.45 + 0.85 * grain), 0.0, 1.0);

	// --- Composite ----------------------------------------------------------
	ALBEDO = mix(body, frost_color.rgb, rime);
	ROUGHNESS = mix(roughness_value, 0.80, rime);
	METALLIC = 0.0;
	SPECULAR = mix(0.85, 0.45, rime);
	CLEARCOAT = sheen * (1.0 - rime * 0.6);
	CLEARCOAT_ROUGHNESS = mix(0.04, 0.24, rime);
	AO = mix(1.0, 0.84, rime);
	AO_LIGHT_AFFECT = 0.35;

	if (rime > 0.02 && frost_relief > 0.0) {
		float e = 0.6;
		float gx = texture(frost_noise, rp + vec2(e, 0.0)).r - grain;
		float gz = texture(frost_noise, rp + vec2(0.0, e)).r - grain;
		// x1.5, not x5.0. At five, a rimed surface has its normal swung further
		// by the frost noise than the surface's own orientation contributes —
		// so every up-facing face in the level shaded as noise rather than as
		// a plane, and the serac field lost its form. Frost relief is meant to
		// be a texture on a surface, not a replacement for it.
		NORMAL = normalize(NORMAL
			+ mat3(VIEW_MATRIX) * vec3(-gx, 0.0, -gz) * frost_relief * rime * 1.5);
	}

	// Thin ice lets the world through. Offsetting the screen sample along the
	// view-space normal is a one-tap refraction that is indistinguishable from
	// the real thing at this camera distance.
	float thin = (1.0 - clamp(path * 0.42, 0.0, 1.0)) * (1.0 - rime) * cl;
	vec3 transmitted = vec3(0.0);
	if (refraction > 0.0 && thin > 0.01) {
		vec2 off = normalize(NORMAL).xy * refraction_offset * (0.35 + 0.65 * thin);
		transmitted = texture(screen_tex,
			clamp(SCREEN_UV + off, vec2(0.003), vec2(0.997))).rgb * refraction * thin;
	}

	vec3 glow = ice_bright.rgb * internal_glow * (0.25 + 0.75 * facing) * (1.0 - rime);
	glow += ice_bright.rgb * veins * 0.55;
	glow += vec3(0.86, 0.95, 1.0) * bubbles * 0.6;
	glow += transmitted;

	// Quantising the glint lattice by the view direction is what makes glints
	// wink as the camera moves. A sparkle that sits still reads as dirt.
	float glint_fade = 1.0 - smoothstep(sparkle_fade_distance * 0.5,
		sparkle_fade_distance, dist);
	if (glint_fade > 0.002 && sparkle_amount > 0.0) {
		float g = glint_field(world_pos * sparkle_density + floor(wv * 6.0),
			sparkle_threshold);
		glow += vec3(1.0) * g * sparkle_amount * glint_fade * (0.5 + 0.5 * rime);
	}

	EMISSION = glow;
	// Thin ice is lit from behind as well as in front; this is what makes a
	// snow lip or an icicle read as translucent rather than as white paint.
	BACKLIGHT = ice_bright.rgb * thin * 0.35;
	RIM = 0.7;
	RIM_TINT = 0.25;
}
