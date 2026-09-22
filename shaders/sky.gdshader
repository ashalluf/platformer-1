shader_type sky;

// World 1's sky.
//
// ProceduralSkyMaterial is three colours and a lerp, which is why every Godot
// sky ever shipped reads the same. This is built around the two facts that
// make the eastern Libyan coast look like itself and nowhere else:
//
//   1. The sky does not fade linearly to the horizon. Air mass grows roughly
//      as 1/cos(zenith), so nearly all of the atmosphere you are looking
//      through sits in the last few degrees. The horizon colour has to decay
//      exponentially, which compresses it into a dense band instead of
//      bleeding halfway up the dome.
//   2. That band is milky with Saharan aerosol, not blue with water vapour.
//      Distance here goes pale WARM, never cool. It is the single most
//      location-specific lighting decision in the project and it lives in the
//      dust/band uniforms below.
//
// Everything is a uniform so a level tunes it by eye against a capture. Sun
// position is taken from the scene's own sky-writing DirectionalLight by
// default, so the disc can never drift away from the key that lights the world.

group_uniforms Gradient;
uniform vec3 zenith_color : source_color = vec3(0.10, 0.20, 0.42);
uniform vec3 mid_color : source_color = vec3(0.37, 0.48, 0.63);
uniform vec3 horizon_color : source_color = vec3(0.80, 0.76, 0.66);
// Below the horizon still feeds the radiance cubemap, so this is the ground
// bounce the whole scene gets on its up-facing surfaces. Black here is why so
// many Godot scenes read dead from underneath.
uniform vec3 ground_color : source_color = vec3(0.22, 0.19, 0.16);
// e-folding height of the horizon colour, measured in sin(altitude). Smaller
// is a tighter, denser, more atmospheric band. 0.16 is about 9 degrees.
uniform float horizon_falloff : hint_range(0.01, 1.0) = 0.16;
uniform float zenith_compression : hint_range(0.10, 4.0) = 1.10;
uniform float ground_falloff : hint_range(0.01, 1.0) = 0.35;
uniform float sky_energy : hint_range(0.0, 8.0) = 1.0;
group_uniforms;

group_uniforms Haze;
uniform vec3 band_color : source_color = vec3(0.835, 0.804, 0.741);
uniform float band_strength : hint_range(0.0, 1.0) = 0.50;
uniform float band_height : hint_range(0.005, 0.6) = 0.075;
uniform vec3 dust_color : source_color = vec3(0.78, 0.71, 0.60);
uniform float dust : hint_range(0.0, 1.0) = 0.35;
uniform float dust_height : hint_range(0.01, 1.2) = 0.24;
group_uniforms;

group_uniforms Sun;
// Direction TOWARD the sun, world space. Only used when use_scene_sun is
// dialled down or no directional light writes to the sky.
uniform vec3 sun_direction = vec3(0.64, 0.06, -0.77);
uniform float use_scene_sun : hint_range(0.0, 1.0) = 1.0;
uniform vec3 sun_color : source_color = vec3(1.0, 0.65, 0.34);
uniform float sun_intensity : hint_range(0.0, 60.0) = 14.0;
uniform float sun_angular_radius : hint_range(0.1, 14.0) = 1.2;
uniform float sun_edge_softness : hint_range(0.001, 1.0) = 0.14;
// Solar limb darkening: a real disc is ~35% dimmer at the edge than the
// centre. Leaving it flat is what makes a CG sun read as a white sticker.
uniform float sun_limb_darkening : hint_range(0.0, 1.0) = 0.62;
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.55, 0.22);
uniform float sun_glow_strength : hint_range(0.0, 20.0) = 2.6;
uniform float sun_glow_falloff : hint_range(4.0, 3000.0) = 420.0;
// The second, far wider lobe. Real skies lift for 40-60 degrees around the
// sun; without this the sky is a gradient with a dot painted on it.
uniform vec3 sun_halo_color : source_color = vec3(1.0, 0.72, 0.46);
uniform float sun_halo_strength : hint_range(0.0, 6.0) = 0.70;
uniform float sun_halo_falloff : hint_range(0.5, 40.0) = 3.2;
// How far the warm lift smears sideways along the horizon at the sun's
// azimuth. Low sun through heavy aerosol does this hard.
uniform float sun_horizon_spread : hint_range(0.0, 4.0) = 1.0;
// Extinction of the disc itself through the haze. Crank it and the sun
// becomes something you can look straight at, which is the ghibli look.
uniform float sun_haze_extinction : hint_range(0.0, 6.0) = 1.6;
group_uniforms;

group_uniforms Clouds;
uniform float wind_direction : hint_range(-3.15, 3.15) = 0.55;
// Both decks dissolve into the haze as they approach the horizon. Without it
// the plane projection stacks infinite cloud into the last two pixels.
uniform float cloud_horizon_fade : hint_range(0.0, 0.5) = 0.10;

uniform vec3 cirrus_color : source_color = vec3(0.95, 0.90, 0.86);
uniform vec3 cirrus_shadow_color : source_color = vec3(0.45, 0.45, 0.52);
uniform float cirrus_opacity : hint_range(0.0, 1.0) = 0.50;
uniform float cirrus_coverage : hint_range(0.0, 1.0) = 0.42;
uniform float cirrus_scale : hint_range(0.05, 6.0) = 0.60;
// Anisotropy is the whole trick: cirrus is the same noise as cumulus, run
// through a stretched frame so it draws in fibres instead of blobs. It
// LOWERS the frequency along the streak axis rather than raising it across —
// same shape on paper, but raising it aliases into a picket fence wherever
// the horizon projection compresses.
uniform float cirrus_stretch : hint_range(1.0, 24.0) = 5.0;
uniform float cirrus_angle : hint_range(-3.15, 3.15) = 0.35;
uniform float cirrus_speed : hint_range(0.0, 0.3) = 0.008;
uniform float cirrus_height : hint_range(0.5, 8.0) = 2.6;
// Cirrus needs a far wider fade than cumulus: it sits higher, so its
// projection compresses sooner and harder.
uniform float cirrus_horizon_fade : hint_range(0.02, 0.6) = 0.16;

uniform vec3 cumulus_color : source_color = vec3(0.98, 0.96, 0.92);
uniform vec3 cumulus_shadow_color : source_color = vec3(0.42, 0.44, 0.50);
uniform float cumulus_opacity : hint_range(0.0, 1.0) = 0.90;
uniform float cumulus_coverage : hint_range(0.0, 1.0) = 0.32;
uniform float cumulus_softness : hint_range(0.01, 0.6) = 0.17;
uniform float cumulus_scale : hint_range(0.05, 4.0) = 0.55;
uniform float cumulus_height : hint_range(0.2, 6.0) = 1.0;
uniform float cumulus_speed : hint_range(0.0, 0.3) = 0.012;
uniform float cumulus_detail : hint_range(0.0, 1.0) = 0.40;
uniform float cumulus_silver : hint_range(0.0, 8.0) = 2.4;
uniform float cumulus_light_step : hint_range(0.01, 2.0) = 0.32;
// Domain warp. The single biggest difference between "procedural cloud" and
// "photograph of a cloud": distort the sampling coordinates by more noise
// before reading the density, and the smooth fbm lobes fold into the billowing
// cauliflower stacks real cumulus actually has. Costs two extra fbm3 taps.
uniform float cumulus_warp : hint_range(0.0, 2.0) = 0.62;
// Second, finer erosion pass. The existing single tap eats the fbm edge; this
// one eats the edge of THAT, which is where the small-scale frill comes from.
uniform float cumulus_frill : hint_range(0.0, 1.0) = 0.45;
group_uniforms;

group_uniforms Night;
uniform vec3 star_color : source_color = vec3(0.86, 0.91, 1.0);
uniform float star_strength : hint_range(0.0, 4.0) = 0.0;
uniform float star_density : hint_range(20.0, 500.0) = 160.0;
uniform float star_threshold : hint_range(0.5, 0.999) = 0.955;
uniform float star_twinkle : hint_range(0.0, 1.0) = 0.45;
uniform float star_horizon_fade : hint_range(0.01, 0.8) = 0.22;

uniform vec3 aurora_low_color : source_color = vec3(0.22, 1.0, 0.68);
uniform vec3 aurora_high_color : source_color = vec3(0.45, 0.34, 0.95);
uniform float aurora_strength : hint_range(0.0, 4.0) = 0.0;
uniform float aurora_altitude : hint_range(0.0, 1.0) = 0.42;
uniform float aurora_thickness : hint_range(0.02, 0.8) = 0.18;
uniform float aurora_wave : hint_range(0.0, 0.6) = 0.16;
uniform float aurora_streak : hint_range(0.5, 24.0) = 6.0;
uniform float aurora_speed : hint_range(0.0, 0.5) = 0.05;
group_uniforms;


// Multiply-fract hash. The horizon projection below divides by EYEDIR.y, so
// cloud coordinates get large; sin()-based hashes lose precision there and
// stripe the sky with moire.
float hash21(vec2 p) {
	vec3 q = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fixed octave counts so the compiler unrolls. A uniform-driven loop bound
// here costs more than the octaves it saves.
float fbm5(vec2 p) {
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	float amp = 0.5;
	float sum = 0.0;
	float norm = 0.0;
	for (int i = 0; i < 5; i++) {
		sum += amp * vnoise(p);
		norm += amp;
		p = rot * p * 2.03;
		amp *= 0.5;
	}
	return sum / norm;
}

float fbm4(vec2 p) {
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	float amp = 0.5;
	float sum = 0.0;
	float norm = 0.0;
	for (int i = 0; i < 4; i++) {
		sum += amp * vnoise(p);
		norm += amp;
		p = rot * p * 2.03;
		amp *= 0.5;
	}
	return sum / norm;
}

float fbm3(vec2 p) {
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	float amp = 0.5;
	float sum = 0.0;
	float norm = 0.0;
	for (int i = 0; i < 3; i++) {
		sum += amp * vnoise(p);
		norm += amp;
		p = rot * p * 2.03;
		amp *= 0.5;
	}
	return sum / norm;
}

// Flat-plane projection of a view direction. This is what gives cloud decks
// their perspective: cells foreshorten toward the horizon for free, which no
// amount of 3D noise on a sphere will do.
vec2 cloud_plane(vec3 dir, float height, float scale) {
	return dir.xz / max(dir.y, 0.045) * height * scale;
}

float star_field(vec3 dir, float t) {
	vec3 p = dir * star_density;
	vec3 cell = floor(p);
	vec3 f = fract(p) - 0.5;
	float seed = hash31(cell);
	// One jittered star per cell. The cube-cell distortion toward the poles is
	// invisible at this density and costs four hashes instead of a texture.
	vec3 jitter = vec3(hash31(cell + 11.3), hash31(cell + 27.7), hash31(cell + 41.1)) - 0.5;
	float d = length(f - jitter * 0.7);
	float mag = smoothstep(star_threshold, 1.0, seed);
	// A core tight enough to read as a point, plus a halo wide enough to
	// survive tonemapping. Core alone lands under a pixel and disappears.
	float core = pow(clamp(1.0 - d * 2.8, 0.0, 1.0), 6.0);
	float halo = pow(clamp(1.0 - d * 1.5, 0.0, 1.0), 3.0) * 0.22;
	float twinkle = 1.0 - star_twinkle * 0.5 * (1.0 + sin(t * 2.7 + seed * 87.0));
	return mag * (core + halo) * twinkle;
}

// A ribbon hung at a fixed altitude, waving slowly and streaked vertically.
// That is all an aurora is at this distance, and a curtain shader on a quad
// cannot wrap the dome the way this does.
//
// Returns (intensity, position across the ribbon) so the caller can ramp the
// colour along the curtain's height. A single alpha gives a flat green wash.
vec2 aurora_band(vec3 dir, float t) {
	float az = atan(dir.z, dir.x);
	float wave = fbm3(vec2(az * 1.7 + t * aurora_speed, t * aurora_speed * 0.4));
	float centre = aurora_altitude + (wave - 0.5) * aurora_wave;
	float across = (dir.y - centre) / max(aurora_thickness, 0.001);
	// A tight core inside a soft bloom. One gaussian reads as a smudge; two
	// at different widths is what gives a curtain its bright lower edge.
	float core = exp(-across * across * 2.2);
	float bloom = exp(-across * across * 0.62);
	float streak = fbm4(vec2(az * aurora_streak - t * aurora_speed * 0.8, dir.y * 2.4));
	streak = pow(clamp(streak * 1.75, 0.0, 1.0), 2.6);
	return vec2((core * 0.90 + bloom * 0.18) * streak, across);
}


void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	float zen = max(up, 0.0);

	vec3 fallback_sun = normalize(sun_direction);
	// LIGHT0_DIRECTION points from the world toward the light, so it drops
	// straight in. Reading the scene's own key means the disc can never end up
	// somewhere the shadows disagree with.
	vec3 scene_sun = LIGHT0_ENABLED ? LIGHT0_DIRECTION : fallback_sun;
	vec3 sun_dir = normalize(mix(fallback_sun, scene_sun, use_scene_sun));
	float cos_sun = dot(dir, sun_dir);

	// ---- base gradient -------------------------------------------------
	float hz = exp(-zen / max(horizon_falloff, 0.001));
	vec3 col = mix(mid_color, horizon_color, hz);
	col = mix(col, zenith_color, pow(zen, zenith_compression));
	col = mix(col, ground_color, smoothstep(0.0, ground_falloff, -up));

	// ---- night layers, behind everything -------------------------------
	// Branching on a uniform is coherent across the whole draw, so the daytime
	// presets genuinely skip this rather than multiplying it by zero.
	if (star_strength > 0.001) {
		float fade = smoothstep(0.0, star_horizon_fade, up);
		col += star_color * star_field(dir, TIME) * star_strength * fade;
	}
	if (aurora_strength > 0.001) {
		vec2 au = aurora_band(dir, TIME);
		vec3 ac = mix(aurora_low_color, aurora_high_color, clamp(au.y * 0.55 + 0.5, 0.0, 1.0));
		col += ac * au.x * aurora_strength * smoothstep(0.0, 0.16, up);
	}

	// ---- scattering lobes around the sun -------------------------------
	float fwd = max(cos_sun, 0.0);
	float glow = pow(fwd, sun_glow_falloff) * sun_glow_strength;
	float halo = pow(fwd, sun_halo_falloff) * sun_halo_strength;
	// Azimuthal alignment: the warm lift runs sideways along the horizon under
	// the sun, it does not sit in a neat circle around it.
	vec2 eye_flat = dir.xz;
	vec2 sun_flat = sun_dir.xz;
	float denom = max(length(eye_flat) * length(sun_flat), 1e-4);
	float along = pow(max(dot(eye_flat, sun_flat) / denom, 0.0), 6.0);
	float spread = along * hz * sun_horizon_spread;

	col += sun_halo_color * halo;
	col += sun_glow_color * (glow + spread * 0.8);

	// ---- cloud decks ----------------------------------------------------
	vec2 wind = vec2(cos(wind_direction), sin(wind_direction));
	float deck_fade = smoothstep(0.0, cloud_horizon_fade, up);
	vec2 sun_az = normalize(sun_flat + vec2(1e-5, 0.0));

	float cirrus_a = 0.0;
	vec3 cirrus_rgb = cirrus_color;
	if (cirrus_opacity > 0.001) {
		// The projection floor is tied to the fade rather than being its own
		// number: clamping produces radial smears, so the clamp has to sit
		// entirely inside the region where the deck is already at zero alpha.
		float cirrus_floor = cirrus_horizon_fade * 0.8;
		vec2 cp = dir.xz / max(dir.y, cirrus_floor) * cirrus_height * cirrus_scale;
		float ca = cos(cirrus_angle);
		float sa = sin(cirrus_angle);
		cp = mat2(vec2(ca, sa), vec2(-sa, ca)) * cp;
		cp.x /= max(cirrus_stretch, 1.0);
		cp += wind * TIME * cirrus_speed;
		cp += (vec2(fbm3(cp * 0.8 + 4.4), fbm3(cp * 0.8 + 11.9)) - 0.5) * 0.35;
		float c = fbm4(cp);
		cirrus_a = smoothstep(1.0 - cirrus_coverage, 1.0 - cirrus_coverage + 0.26, c);
		cirrus_a *= cirrus_opacity * smoothstep(cirrus_floor, cirrus_horizon_fade * 2.0, up);
		// Thin ice crystals forward-scatter hard, so cirrus near the sun is
		// the brightest thing in the sky short of the disc.
		cirrus_rgb = mix(cirrus_shadow_color, cirrus_color, clamp(c * 1.3, 0.0, 1.0));
		cirrus_rgb += sun_glow_color * pow(fwd, 5.0) * 0.9;
	}

	float cumulus_a = 0.0;
	vec3 cumulus_rgb = cumulus_color;
	if (cumulus_opacity > 0.001) {
		vec2 cp = cloud_plane(dir, cumulus_height, cumulus_scale) + wind * TIME * cumulus_speed * 10.0;
		// Domain warp, sampled on its own slow drift so the cloud shapes
		// evolve rather than sliding past as a rigid sheet. Weather changes
		// shape as it crosses the sky and a rigid sheet is the tell that this
		// is a texture on a dome.
		if (cumulus_warp > 0.001) {
			vec2 q = vec2(fbm3(cp * 0.63 + vec2(1.7, 9.2) + wind * TIME * cumulus_speed * 2.0),
						  fbm3(cp * 0.63 + vec2(8.3, 2.8) - wind * TIME * cumulus_speed * 1.4));
			cp += (q - 0.5) * cumulus_warp;
		}
		float d = fbm5(cp);
		// Two erosion taps. The first eats the smooth fbm edge into a
		// cauliflower; the second eats the edge of that, which is where the
		// small-scale frill along a sunlit rim comes from.
		d -= vnoise(cp * 5.3 + 13.0) * cumulus_detail * 0.22;
		d -= vnoise(cp * 13.1 + 41.0) * cumulus_frill * 0.085;
		float thr = 1.0 - cumulus_coverage;
		cumulus_a = smoothstep(thr, thr + cumulus_softness, d);
		cumulus_a *= cumulus_opacity * deck_fade;

		// Silver lining: sample the density a short step toward the sun's
		// azimuth. Where it drops off we are on the sun-facing face of the
		// cloud, and that edge is what sells a cumulus as a solid body.
		float lit = fbm3(cp + sun_az * cumulus_light_step);
		float silver = clamp((d - lit) * cumulus_silver, 0.0, 1.0);
		float depth = clamp((d - thr) * 5.0, 0.0, 1.0);
		cumulus_rgb = mix(cumulus_color, cumulus_shadow_color, depth * (1.0 - silver * 0.85));
		cumulus_rgb += sun_glow_color * (silver * silver) * 1.4;
		cumulus_rgb += sun_glow_color * pow(fwd, 8.0) * 0.6;
	}

	col = mix(col, cirrus_rgb, cirrus_a);
	col = mix(col, cumulus_rgb, cumulus_a);
	float occlusion = 1.0 - clamp(cumulus_a * 0.95 + cirrus_a * 0.45 * (1.0 - cumulus_a), 0.0, 1.0);

	// ---- aerosol, in front of all of it --------------------------------
	float haze = dust * exp(-zen / max(dust_height, 0.001));
	// The haze itself is lit by the sun it sits in front of, so it warms
	// toward the sun's azimuth instead of staying a flat grey wash.
	vec3 haze_rgb = mix(dust_color, sun_glow_color, clamp(along * 0.55 * sun_horizon_spread, 0.0, 1.0));
	col = mix(col, haze_rgb, haze * 0.85);

	float band = exp(-abs(up) / max(band_height, 0.001));
	col = mix(col, band_color, band * band_strength);

	// ---- the disc, last, seen through everything -----------------------
	float ang = acos(clamp(cos_sun, -1.0, 1.0));
	float r = ang / max(radians(sun_angular_radius), 1e-4);
	float disc = 1.0 - smoothstep(1.0 - sun_edge_softness, 1.0 + sun_edge_softness * 0.4, r);
	float rc = min(r, 1.0);
	float limb = 1.0 - sun_limb_darkening * (1.0 - sqrt(max(1.0 - rc * rc, 0.0)));
	float sun_haze = dust * exp(-max(sun_dir.y, 0.0) / max(dust_height, 0.001));
	float extinction = exp(-sun_haze_extinction * sun_haze);
	col += sun_color * sun_intensity * disc * limb * extinction * occlusion;

	COLOR = col * sky_energy;
}
