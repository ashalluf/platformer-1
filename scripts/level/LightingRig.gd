class_name LightingRig
## Cinematographer in a box.
##
## A level declares a mood — time of day, sun angle, colour temperature, fog —
## and this builds the key / fill / rim setup and the Environment to match.
## Keeping it in one place is what stops World 1 drifting into five different
## looking games.
##
## It also owns the three things levels used to hand-roll and get wrong:
##   * light shafts (`shafts()`) — they only form downstream of an occluder,
##     and every level so far has put the volume on the wrong side,
##   * practical lights (`practical()`, `practical_spot()`) — consistent
##     falloff, fog contribution and flicker instead of five different guesses
##     at what "a lamp" means,
##   * colour grading (`Mood.grade_*`) — a real lift/gamma/gain through a
##     generated LUT, because saturation+contrast alone is why every level is
##     sliding toward the same orange.
##
## Read the EXPOSURE REFERENCE below before you touch a light energy.

# ---------------------------------------------------------------------------
# EXPOSURE REFERENCE — read this before changing any *_energy
# ---------------------------------------------------------------------------
#
# The whole thing is one equation and one curve.
#
#     linear_radiance  =  linear_albedo  x  light_energy  x  N.L
#
# Godot folds the Lambert 1/pi into the light's energy, so energy 1.0 puts a
# pure-white surface facing the light at linear 1.0. No hidden constants. If
# you doubt it, check it: TONE_MAPPER_LINEAR with tonemap_white 1.0, one key at
# energy 1.0, one white albedo facing it — the surface reads 255, not 152.
#
# `linear_albedo` is NOT the hex you typed. Hex is sRGB; the shader multiplies
# in linear, and the two are a long way apart in the darks:
#
#     hex                       sRGB   linear      hex                sRGB   linear
#     #F4F1EA thobe             0.957  0.905       #A8A296 concrete   0.659  0.392
#     #EFE6D2 calcareous ground 0.937  0.863       #B4AEA2 wall       0.706  0.456
#     #E8E2D2 sabkha crust      0.910  0.807       #6B5F55 shadow     0.420  0.147
#     #D8CEB6 prison slab       0.847  0.687       #4A4741 asphalt    0.290  0.068
#
# Asphalt is four times darker than a colour picker suggests. Most of "why is
# my dark material black" is this line and nothing else.
#
# AgX at its default look (agx_white 16.29, agx_contrast 1.25) then maps that
# linear value to the screen. These numbers are computed from the AgX transfer,
# not eyeballed — `agx_display()` further down is the same curve, so the table
# is reproducible and `Mood.debug_describe()` prints against it:
#
#     linear   0.02  0.05  0.12  0.18  0.35  0.50  1.00  2.00  4.50  16.0
#     screen   0.16  0.28  0.43  0.50  0.62  0.68  0.78  0.87  0.94  0.98
#     sRGB8      41    72   108   127   157   172   200   221   239   250
#
# and backwards, which is how you actually place a value:
#
#     screen   0.32   0.38   0.45   0.58   0.66   0.74   0.82   0.88   0.94
#     linear  0.064  0.093  0.138  0.286  0.455  0.748  1.325  2.251  4.796
#
# Note the shoulder. Past linear ~1.5 you buy almost no screen value, you only
# burn headroom. That is exactly how levels drift: the author cannot see the
# wall getting brighter, so they push the key, and the hero — who was already
# on the shoulder — stops separating from it.
#
# WORLD 1 TARGETS (from ART_DIRECTION: "shadow is never black", "Wanis is the
# brightest value in the frame"). Wanis's thobe is linear 0.905 and the pale
# ground is linear 0.863 — they are practically the same albedo, so his
# separation has to come from LIGHT, never from material value:
#
#     deep shade / interior       screen 0.30-0.40   linear 0.055-0.110
#     shaded world surface        screen 0.42-0.52   linear 0.120-0.200
#     key-lit world surface       screen 0.66-0.78   linear 0.455-1.000
#     hero thobe, front-lit       screen 0.80-0.86   linear 1.15-2.00
#     hero rim / chain specular   screen 0.92-0.97   linear 3.50-9.00
#     anything at all             never 1.00 — AgX clips hard at linear 16.5
#
# Which pins the key energies. For a surface facing the sun at N.L = 0.85:
#
#     concrete #A8A296 (0.392)   key 1.4 -> 0.66    key 2.8 -> 0.77   key 4.2 -> 0.83
#     slab     #D8CEB6 (0.687)   key 1.4 -> 0.75    key 2.8 -> 0.85   key 4.2 -> 0.89
#     ground   #EFE6D2 (0.863)   key 1.4 -> 0.79    key 2.8 -> 0.87   key 4.2 -> 0.91
#
# (Every number above comes out of `expose()` below. Re-derive them, do not
# trust them — that is the point of shipping the curve rather than a table.)
#
# So a level whose ground is pale calcareous wants a key in the 1.0-2.0 band,
# not 3+. Independently: every key energy written in ART_DIRECTION's colour
# script is between 0.85 and 1.60. The moods actually shipped run 3.1 (Brega)
# and 4.2 (Ajdabiya) — two to three stops hot, which is why the pale ground
# sits on the shoulder next to the hero and the frames flatten.
#
# Brega half-gets away with it because its key is behind the geometry and
# almost nothing in frame has an N.L above 0.2. Ajdabiya, front-lit, does not.
#
# `Mood.debug_describe()` prints the landing values for a mood so a capture can
# log what it was lit with. Use it before arguing with this table.
# ---------------------------------------------------------------------------


## Fixed-function presets for practical lights. Hand-rolled OmniLight3Ds are
## how five levels ended up with five different ideas of what a street lamp is
## worth; pick a bulb instead and override only what the shot needs.
enum Bulb {
	SODIUM,        ## 1900 K street lamp. The World 1 night signature.
	INCANDESCENT,  ## 3100 K interior / failing corridor strip.
	FLUORESCENT,   ## 5200 K shopfront tube.
	HEADLIGHT,     ## Car and truck headlamps. Long throw, hard fog cone.
	FLARE,         ## Burning gas, fires, muzzle wash. Warm and unstable.
	HAZARD,        ## Amber beacon / convoy hazards. Blinks by default.
	CASE,          ## Glass display counter, phone screen, monitor. Soft, near.
	MOONSPILL,     ## Cool bounce for a night interior. Fakes a window.
}

## Flicker shapes. These are cheap on purpose — one Node, one float write.
enum Flick {
	NONE,
	HUM,    ## Mains ripple. Barely visible; it stops a lamp reading as a decal.
	FAIL,   ## Fluorescent trying to strike. Long steady, sudden stutter.
	FIRE,   ## Smoothed noise. Flame, flare, muzzle wash.
	BLINK,  ## Hard square wave. Hazard beacons, warning strobes.
}

## kind -> [color, energy, range, fog_energy, attenuation, default flicker]
const BULBS := {
	Bulb.SODIUM:       [Color(1.000, 0.631, 0.231),  7.0, 16.0, 5.0, 2.0, Flick.HUM],
	Bulb.INCANDESCENT: [Color(1.000, 0.722, 0.467),  4.5,  8.0, 1.6, 2.0, Flick.NONE],
	Bulb.FLUORESCENT:  [Color(0.875, 0.941, 0.910),  3.2,  9.0, 1.2, 1.6, Flick.FAIL],
	Bulb.HEADLIGHT:    [Color(1.000, 0.941, 0.847),  9.0, 22.0, 2.4, 2.4, Flick.NONE],
	Bulb.FLARE:        [Color(1.000, 0.541, 0.235),  6.0, 12.0, 4.0, 2.0, Flick.FIRE],
	Bulb.HAZARD:       [Color(1.000, 0.690, 0.125),  5.0,  7.0, 2.0, 2.0, Flick.BLINK],
	Bulb.CASE:         [Color(0.918, 0.965, 0.933),  2.4,  6.0, 0.8, 1.4, Flick.NONE],
	Bulb.MOONSPILL:    [Color(0.784, 0.847, 1.000),  1.6, 14.0, 0.6, 1.8, Flick.NONE],
}

## One warning per run per category. A level that gets the shaft side wrong
## should be told once, not sixty times a second.
static var _warned := {}


class Mood extends RefCounted:

	# --- Key -----------------------------------------------------------------
	var sun_energy := 2.4
	var sun_color := Color(1.0, 0.86, 0.66)
	var sun_angles := Vector2(-42.0, 38.0)   ## pitch, yaw in degrees
	var sun_angular_distance := 1.1          ## soft shadow width
	var sun_fog_energy := 2.4                ## how hard the key writes into volumetrics
	## GI contribution of the key. ART_DIRECTION asks for 1.3; left at the
	## engine default so adopting it stays a deliberate per-level decision.
	var sun_indirect_energy := 1.0

	# --- Shadows -------------------------------------------------------------
	# Split fractions, not distances, which is what makes them tier-proof:
	# GraphicsDirector owns `directional_shadow_max_distance` and rewrites it
	# per quality tier (70 / 110 / 160 / 220), so anything expressed in metres
	# here is advisory. Fractions survive.
	#
	# At the HIGH tier's 160 these give 9.6 / 24 / 56 / 160. A side-on camera at
	# Z = +16 with a 34 deg FOV sees about 17 units of width and everything the
	# player can touch is inside 60 — so three of the four splits land on the
	# part of the world that matters and the fourth soaks up the skyline. The
	# engine defaults (0.1 / 0.2 / 0.5 -> 16 / 32 / 80) spend the first split on
	# scenery and leave the hero's own contact shadows in split 2.
	var shadow_splits := Vector3(0.06, 0.15, 0.35)
	var shadow_blend_splits := true
	var shadow_bias := 0.03
	var shadow_normal_bias := 0.8   ## 2.0 default peter-pans small props
	var shadow_opacity := 0.84
	var shadow_blur := 1.0
	## Advisory only — see the note above. Used when GraphicsDirector is absent
	## (tools, showcase scenes) and as the value the light is born with.
	var shadow_max_distance := 160.0

	# --- Fill rig ------------------------------------------------------------
	# Three lights, three jobs, and every one of them can be masked to a layer.
	# The hero is on render layer 2 (`WanisRig` sets `layers = 1 | 2`) and
	# nothing else in the project uses it, so mask 2 means "him and only him".
	# Note the asymmetry: because he also carries layer 1, there is no mask
	# that means "the world but not the hero" — to light the world alone the
	# hero would have to drop bit 1. Light him MORE, never the world less.

	## Fill 1 — the sky dome. Cool, broad, from above-front in a daylight level
	## and from below-front where the ground is the brighter source (Brega's
	## sabkha). This is the one that decides what shadow looks like.
	var fill_energy := 0.55
	var fill_color := Color(0.42, 0.55, 0.78)
	var fill_angles := Vector2(-18.0, -140.0)
	var fill_cull_mask := 0xFFFFF
	var fill_specular := 0.35   ## a sky fill has no specular in the real world

	## Fill 2 — the ground bounce. Warm, from below, and the single cheapest way
	## to stop an object reading as a sticker pasted on the background. Off by
	## default so existing moods are untouched; switch it on before you reach
	## for more key.
	var bounce_energy := 0.0
	var bounce_color := Color(1.0, 1.0, 1.0)
	var bounce_angles := Vector2(62.0, -20.0)   ## pitch positive = pointing up
	var bounce_cull_mask := 0xFFFFF
	var bounce_specular := 0.20
	## Multiply `bounce_color` by the sky's ground colour, so the bounce is
	## automatically the colour of the dirt it came off. Turn it off if you want
	## an authored bounce hue.
	var bounce_tint_from_ground := true

	## Fill 3 — the back / rim. Separates the subject from the background and is
	## the reason a 15%-of-frame-height hero reads at all.
	var rim_energy := 1.5
	var rim_color := Color(0.85, 0.72, 1.0)
	var rim_angles := Vector2(-6.0, 178.0)
	## Render layers the rim may touch. The hero is on layer 2; a rim that also
	## lights the world is just a second key and it flattens everything.
	var rim_cull_mask := 0xFFFFF
	var rim_specular := 1.2

	## A fill that touches only the hero layer. Lets the world sit in true
	## shadow while the character keeps a readable front value — the single
	## most useful light in a back-lit scene.
	var hero_fill_energy := 0.0
	var hero_fill_color := Color(0.78, 0.82, 0.92)
	var hero_fill_angles := Vector2(-12.0, -24.0)
	var hero_cull_mask := 2
	var hero_fill_specular := 1.2

	# --- Sky -----------------------------------------------------------------
	var sky_top := Color(0.22, 0.36, 0.62)
	var sky_horizon := Color(0.72, 0.68, 0.60)
	var ground_horizon := Color(0.38, 0.32, 0.27)
	var ground_bottom := Color(0.18, 0.14, 0.12)
	var sky_energy := 1.0
	## How fast the horizon colour gives way to the zenith colour. Low values
	## keep the warm band tight to the horizon instead of flooding the sky.
	var sky_curve := 0.15
	## Angular size of the sun disc the sky paints, in degrees.
	var sun_disc_size := 3.5
	var ground_curve := 0.2
	var volumetric_density := 0.0025

	var ambient_energy := 0.30
	var fog_color := Color(0.62, 0.58, 0.52)
	var fog_density := 0.0022
	## Atmospheric perspective: how far distant geometry is blended toward the
	## sky colour.
	##
	## This is the single strongest depth cue available to a 2.5D game and it
	## was hardcoded at 0.16, which is close enough to nothing that a frame's
	## foreground railing and its distant refinery came back at the same value
	## and the same haze -- one flat wall of clutter with no read of what is
	## near and what is far. Painters have used it since Leonardo; every
	## background in the reference art has it; Godot gives it away for free on
	## an Environment property.
	var fog_aerial := 0.62
	var fog_sun_scatter := 0.35
	var fog_emission := Color(0.35, 0.30, 0.26)
	var fog_anisotropy := 0.72
	## How much the volumetrics wash the sky. ART_DIRECTION calls for 0.0
	## (crisp sky, fog only in the world); left at the engine default so
	## adopting it is a visible, deliberate change per level.
	var volumetric_sky_affect := 1.0
	var volumetric_ambient_inject := 0.0

	# --- Light shafts --------------------------------------------------------
	# Shafts are not a post-process. They are volumetric fog that the key writes
	# into, minus the parts an occluder shadows — so all three of these have to
	# be true at once or you get nothing:
	#   1. `sun_fog_energy` high enough that the key is actually in the fog,
	#   2. `fog_anisotropy` >= ~0.55 so scattering is forward-biased,
	#   3. a FogVolume DOWNSTREAM of the occluder and on the camera's side of it.
	# (3) is the one every level got wrong, which is what `shafts()` fixes.

	var shafts_density := 0.0045
	var shafts_tint := Color(1.0, 0.90, 0.76)
	## Extra nudge toward the lens after the downstream offset. Use it when the
	## occluder is deep in the background and the cone needs pulling forward.
	var shafts_camera_bias := 0.0
	## Softness of the volume's own boundary. Too high and the shaft dissolves
	## before it reaches the floor; too low and the box edge is visible.
	var shafts_edge_fade := 0.30
	## Vertical density falloff. Zero on purpose: a shaft that thins with height
	## is a shaft that dies before it leaves the occluder. Ground mist wants
	## 1.0-1.5, shafts want 0.
	var shafts_height_falloff := 0.0
	## Low-frequency noise through the beam. This is the dust-in-the-light read
	## and it is the difference between a shaft and a triangle of haze.
	var shafts_noise := 0.45
	var shafts_noise_scale := 0.14

	# --- Tonemap -------------------------------------------------------------
	var tonemap := Environment.TONE_MAPPER_AGX
	var exposure := 1.0
	## Ignored under AgX — AgX takes its white point from `agx_white`. Kept
	## because four moods set it and it still applies under Filmic / ACES.
	var white := 6.0
	## The linear value that maps to display white. 16.29 is the engine default
	## and it is flat; ART_DIRECTION prescribes 9.5, which pulls about three
	## quarters of a stop of contrast back into the highlights. Defaulted to the
	## engine value so nobody's level silently re-grades — set it per mood.
	var agx_white := 16.29
	## AgX-internal contrast, applied before the display encode so it cannot
	## clip the gamut. This is the knob to reach for instead of
	## `adjustment_contrast`. ART_DIRECTION prescribes 1.45; 1.25 is default.
	var agx_contrast := 1.25

	# --- Glow ----------------------------------------------------------------
	var glow_intensity := 0.55
	var glow_bloom := 0.0        ## >0 is guaranteed washout; keep it at zero
	var glow_hdr_threshold := 1.05
	## One blown sun pixel at the 12.0 default floods the whole frame through
	## the glow buffer. 5.0 keeps a specular hit a specular hit.
	var glow_luminance_cap := 5.0
	var glow_blend_mode := Environment.GLOW_BLEND_MODE_SOFTLIGHT
	## Per-mip energy. 1 and 2 are the tight halo beside every bright edge —
	## that halo IS the cheap-bloom signature, so they stay at zero. The wide
	## cinematic falloff lives in 4-6.
	var glow_levels := [0.0, 0.0, 0.6, 1.0, 1.0, 0.0, 0.0]

	# --- Screen space --------------------------------------------------------
	var ssao_radius := 1.1
	var ssao_intensity := 2.2
	var ssil_intensity := 0.9

	# --- Depth of field ------------------------------------------------------
	var dof_distance := 0.0
	var dof_transition := 18.0
	var dof_amount := 0.10
	var dof_near_distance := 0.0     ## 0 disables the near blur
	var dof_near_transition := 4.0

	# --- Grade ---------------------------------------------------------------
	# Saturation and contrast are global scalars: they cannot make the shadows
	# cool while the highlights stay warm, which is the entire job of a grade
	# and the reason every level has been sliding toward the same orange. These
	# feed a generated 33^3 LUT on `adjustment_color_correction`.
	#
	# All of it operates in display-referred space (post-tonemap, post-BCS),
	# because that is where Godot applies the correction and it is where a
	# 0.5-is-mid-grey grade actually behaves. Identity values build no LUT at
	# all, so a mood that does not grade pays nothing.

	var grade_lift := Color(0.0, 0.0, 0.0, 1.0)    ## added everywhere; lands in the shadows
	var grade_gamma := Color(1.0, 1.0, 1.0, 1.0)   ## >1 opens the midtones
	var grade_gain := Color(1.0, 1.0, 1.0, 1.0)    ## slope; lands in the highlights
	## Shadow / highlight split-tone. 0.5 grey is neutral; push the shadows to
	## (0.45, 0.48, 0.58) for the cool-shade half of "warm key, cool shadow".
	var grade_shadow_tint := Color(0.5, 0.5, 0.5, 1.0)
	var grade_highlight_tint := Color(0.5, 0.5, 0.5, 1.0)
	## -1 cool .. +1 warm, and -1 green .. +1 magenta. Channel gains, applied
	## last, for the small correction you do not want to express as three.
	var grade_temperature := 0.0
	var grade_tint := 0.0
	## Blend the whole grade back toward the ungraded frame.
	var grade_strength := 1.0
	var grade_lut_size := 33

	var adjustment_saturation := 1.10
	var adjustment_contrast := 1.10
	var adjustment_brightness := 1.0


	## Three-way colour balance, the way a colourist thinks about it: nudge the
	## shadows, midtones and highlights around 0.5 grey and let this convert to
	## lift / gamma / gain.
	func set_three_way(shadows: Color, mids: Color, highs: Color) -> void:
		grade_lift = Color((shadows.r - 0.5) * 0.5, (shadows.g - 0.5) * 0.5,
			(shadows.b - 0.5) * 0.5)
		grade_gamma = Color(1.0 + (mids.r - 0.5) * 1.2, 1.0 + (mids.g - 0.5) * 1.2,
			1.0 + (mids.b - 0.5) * 1.2)
		grade_gain = Color(1.0 + (highs.r - 0.5) * 0.8, 1.0 + (highs.g - 0.5) * 0.8,
			1.0 + (highs.b - 0.5) * 0.8)


	func grades() -> bool:
		return not (grade_lift.is_equal_approx(Color(0, 0, 0, 1))
			and grade_gamma.is_equal_approx(Color(1, 1, 1, 1))
			and grade_gain.is_equal_approx(Color(1, 1, 1, 1))
			and grade_shadow_tint.is_equal_approx(Color(0.5, 0.5, 0.5, 1))
			and grade_highlight_tint.is_equal_approx(Color(0.5, 0.5, 0.5, 1))
			and is_zero_approx(grade_temperature)
			and is_zero_approx(grade_tint))


	## What this mood is actually doing, in numbers, for a capture log. Print it
	## from a level's `_ready` and the screenshot stops being an opinion.
	func debug_describe() -> String:
		var dir := LightingRig.key_direction(self)
		var lines := PackedStringArray()
		lines.append("--- LightingRig.Mood")
		lines.append("key      energy %.2f  angles (%.1f, %.1f)  dir (%.2f, %.2f, %.2f)  angular %.2f"
			% [sun_energy, sun_angles.x, sun_angles.y, dir.x, dir.y, dir.z, sun_angular_distance])
		lines.append("         colour (%.2f, %.2f, %.2f)  fog %.2f  indirect %.2f"
			% [sun_color.r, sun_color.g, sun_color.b, sun_fog_energy, sun_indirect_energy])
		lines.append("shadow   splits %.2f/%.2f/%.2f  max %.0f (GraphicsDirector overrides)  opacity %.2f  bias %.3f/%.2f"
			% [shadow_splits.x, shadow_splits.y, shadow_splits.z, shadow_max_distance,
				shadow_opacity, shadow_bias, shadow_normal_bias])
		lines.append("fill     sky %.2f  bounce %.2f  rim %.2f (mask 0x%X)  hero %.2f (mask 0x%X)  ambient %.2f"
			% [fill_energy, bounce_energy, rim_energy, rim_cull_mask, hero_fill_energy,
				hero_cull_mask, ambient_energy])
		lines.append("fog      depth %.5f  volumetric %.5f  anisotropy %.2f  sun_scatter %.2f  sky_affect %.2f"
			% [fog_density, volumetric_density, fog_anisotropy, fog_sun_scatter, volumetric_sky_affect])
		lines.append("shafts   density %.4f  noise %.2f  edge_fade %.2f  viable %s"
			% [shafts_density, shafts_noise, shafts_edge_fade,
				"yes" if shafts_viable() else "NO — see shafts_viable()"])
		lines.append("tonemap  %s  exposure %.2f  agx_white %.2f  agx_contrast %.2f  glow %.2f @ %.2f cap %.1f"
			% [_tonemap_name(), exposure, agx_white, agx_contrast, glow_intensity,
				glow_hdr_threshold, glow_luminance_cap])
		lines.append("grade    %s  sat %.2f  con %.2f  bri %.2f"
			% ["LUT %d^3" % grade_lut_size if grades() else "none", adjustment_saturation,
				adjustment_contrast, adjustment_brightness])

		# The part that actually stops drift: where this key lands the canon
		# surfaces. N.L 0.85 is a surface square-on to the sun.
		var refs := {"thobe #F4F1EA": 0.905, "ground #EFE6D2": 0.863,
			"slab #D8CEB6": 0.687, "concrete #A8A296": 0.392, "asphalt #4A4741": 0.068}
		var landing := PackedStringArray()
		for label: String in refs:
			var d: float = LightingRig.expose(refs[label], sun_energy, 0.85, exposure)
			landing.append("%s %.2f" % [label, d])
		lines.append("exposure lit at N.L 0.85 -> " + ", ".join(landing))
		# Trip point is a little above the 0.78 band so a level that is only
		# grazing it is not nagged; 0.80 on mid concrete means the pale
		# surfaces behind it are already on the shoulder.
		var ceiling: float = LightingRig.expose(0.392, sun_energy, 0.85, exposure)
		if ceiling > 0.80:
			lines.append("exposure WARNING: key-lit mid concrete lands at %.2f, past the"
				% ceiling + " 0.66-0.78 band. Everything paler than it is on the AgX"
				+ " shoulder and the hero has no headroom left. See EXPOSURE REFERENCE;"
				+ " LightingRig.key_for(0.392, 0.72) = %.2f." % LightingRig.key_for(0.392, 0.72))
		return "\n".join(lines)


	func _tonemap_name() -> String:
		match tonemap:
			Environment.TONE_MAPPER_LINEAR: return "LINEAR"
			Environment.TONE_MAPPER_REINHARDT: return "REINHARDT"
			Environment.TONE_MAPPER_FILMIC: return "FILMIC"
			Environment.TONE_MAPPER_ACES: return "ACES"
			Environment.TONE_MAPPER_AGX: return "AGX"
		return "?"


	## Cheap pre-flight for `shafts()`. Anisotropy below ~0.55 scatters evenly
	## and the beam never gathers; a key that does not write into the fog has
	## nothing to gather.
	func shafts_viable() -> bool:
		return sun_fog_energy >= 0.8 and fog_anisotropy >= 0.55 and volumetric_density > 0.0


static func neutral_studio() -> Mood:
	## Greybox mood: warm key, cool fill, enough contrast to judge silhouettes.
	var m := Mood.new()
	m.sun_energy = 3.4
	m.sun_color = Color(1.0, 0.91, 0.78)
	m.sun_angles = Vector2(-38.0, 42.0)
	m.fill_color = Color(0.46, 0.58, 0.80)
	m.fill_energy = 0.45
	m.rim_color = Color(0.62, 0.78, 1.0)
	m.rim_energy = 2.6
	m.sky_top = Color(0.14, 0.26, 0.52)
	m.sky_horizon = Color(0.74, 0.72, 0.66)
	m.ground_horizon = Color(0.30, 0.27, 0.25)
	m.ground_bottom = Color(0.14, 0.13, 0.13)
	m.fog_color = Color(0.60, 0.66, 0.74)
	m.fog_density = 0.0020
	return m


static func build(parent: Node3D, mood: Mood) -> WorldEnvironment:
	var env := Environment.new()

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = mood.sky_top
	sky_mat.sky_horizon_color = mood.sky_horizon
	sky_mat.ground_horizon_color = mood.ground_horizon
	sky_mat.ground_bottom_color = mood.ground_bottom
	sky_mat.sky_energy_multiplier = mood.sky_energy
	sky_mat.sun_angle_max = mood.sun_disc_size
	sky_mat.sun_curve = 0.18
	sky_mat.sky_curve = mood.sky_curve
	sky_mat.ground_curve = mood.ground_curve
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = mood.ambient_energy

	env.tonemap_mode = mood.tonemap
	env.tonemap_exposure = mood.exposure
	env.tonemap_white = mood.white
	# AgX ignores tonemap_white and takes these instead. Harmless under the
	# other tonemappers, so no branch.
	env.tonemap_agx_white = mood.agx_white
	env.tonemap_agx_contrast = mood.agx_contrast

	env.ssao_enabled = true
	env.ssao_radius = mood.ssao_radius
	env.ssao_intensity = mood.ssao_intensity
	env.ssao_detail = 0.6
	env.ssao_power = 2.0
	# The 0.06 default draws a bright halo just outside every silhouette, which
	# on a backlit hero reads as a cut-out.
	env.ssao_horizon = 0.10
	# A touch of light response stops AO reading as painted-on dirt.
	env.ssao_light_affect = 0.1

	env.ssil_enabled = true
	env.ssil_radius = 2.2   ## the 5.0 default bleeds background onto the hero
	env.ssil_intensity = mood.ssil_intensity

	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.4
	env.ssr_fade_out = 2.5

	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 1.0

	env.glow_enabled = true
	env.glow_intensity = mood.glow_intensity
	env.glow_bloom = mood.glow_bloom
	env.glow_hdr_threshold = mood.glow_hdr_threshold
	env.glow_hdr_luminance_cap = mood.glow_luminance_cap
	env.glow_blend_mode = mood.glow_blend_mode
	# glow_levels/N is not a real script property; it only exists through set().
	for i in range(mood.glow_levels.size()):
		env.set("glow_levels/%d" % (i + 1), float(mood.glow_levels[i]))
	env.glow_strength = 1.0

	env.fog_enabled = true
	env.fog_light_color = mood.fog_color
	env.fog_density = mood.fog_density
	env.fog_sun_scatter = mood.fog_sun_scatter
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = mood.fog_aerial

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = mood.volumetric_density
	env.volumetric_fog_albedo = mood.fog_color
	env.volumetric_fog_emission = mood.fog_emission
	env.volumetric_fog_emission_energy = 0.15
	env.volumetric_fog_gi_inject = 1.0
	env.volumetric_fog_ambient_inject = mood.volumetric_ambient_inject
	env.volumetric_fog_sky_affect = mood.volumetric_sky_affect
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_detail_spread = 2.0
	# The 0.2 default means no light shaft will ever form.
	env.volumetric_fog_anisotropy = mood.fog_anisotropy
	env.volumetric_fog_temporal_reprojection_amount = 0.68

	env.adjustment_enabled = true
	env.adjustment_saturation = mood.adjustment_saturation
	env.adjustment_contrast = mood.adjustment_contrast
	env.adjustment_brightness = mood.adjustment_brightness
	# Only pay for the LUT when the mood actually grades. An identity LUT is a
	# 33^3 texture fetch per pixel that changes nothing.
	if mood.grades():
		env.adjustment_color_correction = grade_lut(mood)

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	# Depth of field lives on CameraAttributes in Godot 4, not on Environment.
	# Near blur is what turns a foreground occluder into a shape rather than an
	# object competing with the subject.
	if mood.dof_near_distance > 0.0 or mood.dof_distance > 0.0:
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_amount = mood.dof_amount
		if mood.dof_near_distance > 0.0:
			ca.dof_blur_near_enabled = true
			ca.dof_blur_near_distance = mood.dof_near_distance
			ca.dof_blur_near_transition = mood.dof_near_transition
		if mood.dof_distance > 0.0:
			ca.dof_blur_far_enabled = true
			ca.dof_blur_far_distance = mood.dof_distance
			ca.dof_blur_far_transition = mood.dof_transition
		we.camera_attributes = ca
	we.add_to_group("world_environment")
	parent.add_child(we)

	var sun := _light(parent, "Sun", mood.sun_angles, mood.sun_color, mood.sun_energy, true,
		mood.sun_angular_distance, "sun", mood.sun_fog_energy)
	sun.light_indirect_energy = mood.sun_indirect_energy
	sun.directional_shadow_split_1 = mood.shadow_splits.x
	sun.directional_shadow_split_2 = mood.shadow_splits.y
	sun.directional_shadow_split_3 = mood.shadow_splits.z
	sun.directional_shadow_blend_splits = mood.shadow_blend_splits
	sun.directional_shadow_max_distance = mood.shadow_max_distance
	sun.shadow_bias = mood.shadow_bias
	sun.shadow_normal_bias = mood.shadow_normal_bias
	sun.shadow_opacity = mood.shadow_opacity
	sun.shadow_blur = mood.shadow_blur

	var fill := _light(parent, "Fill", mood.fill_angles, mood.fill_color, mood.fill_energy,
		false, 4.0, "")
	fill.light_cull_mask = mood.fill_cull_mask
	fill.light_specular = mood.fill_specular

	if mood.bounce_energy > 0.0:
		var tint := mood.bounce_color
		if mood.bounce_tint_from_ground:
			# The bounce is the colour of what it bounced off. Taking it from
			# the sky's ground band means it tracks the level's palette for
			# free instead of being a fourth colour someone has to maintain.
			tint = Color(tint.r * mood.ground_horizon.r, tint.g * mood.ground_horizon.g,
				tint.b * mood.ground_horizon.b)
			# Ground colours are dark; renormalise so the hue survives but the
			# author's energy still means what they typed.
			var peak: float = maxf(maxf(tint.r, tint.g), maxf(tint.b, 0.001))
			tint = Color(tint.r / peak, tint.g / peak, tint.b / peak)
		var bounce := _light(parent, "Bounce", mood.bounce_angles, tint, mood.bounce_energy,
			false, 6.0, "")
		bounce.light_cull_mask = mood.bounce_cull_mask
		bounce.light_specular = mood.bounce_specular

	var rim := _light(parent, "Rim", mood.rim_angles, mood.rim_color, mood.rim_energy, false, 2.0, "")
	rim.light_cull_mask = mood.rim_cull_mask
	rim.light_specular = mood.rim_specular

	if mood.hero_fill_energy > 0.0:
		var hero := _light(parent, "HeroFill", mood.hero_fill_angles, mood.hero_fill_color,
			mood.hero_fill_energy, false, 3.0, "")
		hero.light_cull_mask = mood.hero_cull_mask
		hero.light_specular = mood.hero_fill_specular

	return we


static func _light(parent: Node3D, name_: String, angles: Vector2, color: Color,
		energy: float, shadows: bool, angular: float, group: String,
		fog_energy := 0.0) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = name_
	l.rotation_degrees = Vector3(angles.x, angles.y, 0.0)
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = shadows
	l.light_angular_distance = angular
	if not shadows:
		# Fills feeding the volumetrics turn the fog into flat grey soup: the
		# shaft contrast comes from ONE light being occluded, and a second
		# unshadowed light fills the gaps back in.
		l.light_volumetric_fog_energy = 0.0
		# ProceduralSkyMaterial draws a disc for EVERY directional light. Fill
		# and rim lights are shaping tools, not suns, and must not paint one.
		l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	else:
		l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		l.light_volumetric_fog_energy = fog_energy
	if group != "":
		l.add_to_group(group)
	parent.add_child(l)
	return l


# ---------------------------------------------------------------------------
# Light shafts
# ---------------------------------------------------------------------------

## Direction the key TRAVELS, in world space. A DirectionalLight3D shines along
## its local -Z, so this is the euler basis applied to BACK-negated.
static func key_direction(mood: Mood) -> Vector3:
	var b := Basis.from_euler(Vector3(deg_to_rad(mood.sun_angles.x),
		deg_to_rad(mood.sun_angles.y), 0.0))
	return (b * Vector3(0.0, 0.0, -1.0)).normalized()


## Put light shafts downstream of something.
##
## `occluder` is the world position of the thing CUTTING the light — the pipe
## rack, the brise-soleil, the gap between two towers — not where you want the
## beams to appear. The volume is then placed so its leading face touches that
## point and the whole box lies on the far side of it along the key direction,
## which is the only place a shaft exists.
##
## This is the bit every level got wrong by hand. A shaft is only VISIBLE where
## the lit fog sits between the occluder and the lens, so if the key travels
## away from the camera (a front-lit level) the physically-correct placement is
## behind the occluder and out of sight. In that case pick a foreground
## occluder instead — you are warned once per run rather than left guessing.
static func shafts(parent: Node3D, mood: Mood, occluder: Vector3,
		size := Vector3(48.0, 16.0, 20.0), density := -1.0,
		name_ := "LightShafts") -> FogVolume:
	var dir := key_direction(mood)

	if not mood.shafts_viable():
		_warn_once("shafts_viable",
			"LightingRig.shafts(): this mood cannot form a shaft — sun_fog_energy %.2f "
			% mood.sun_fog_energy
			+ "(want >= 0.8), fog_anisotropy %.2f (want >= 0.55), volumetric_density %.5f."
			% [mood.fog_anisotropy, mood.volumetric_density])
	if dir.z < 0.0:
		_warn_once("shafts_side",
			"LightingRig.shafts(): the key travels away from the camera (dir.z %.2f), " % dir.z
			+ "so shafts form BEHIND the occluder at %s and the camera cannot see into them. "
			% str(occluder) + "Use a foreground occluder, or raise Mood.shafts_camera_bias.")

	# Support function of the box along the light direction: half its extent in
	# exactly that direction, so the near face lands on the occluder and the
	# volume opens away from it.
	var reach := 0.5 * (absf(size.x * dir.x) + absf(size.y * dir.y) + absf(size.z * dir.z))
	var centre := occluder + dir * reach + Vector3(0.0, 0.0, mood.shafts_camera_bias)

	var fv := _fog_box(parent, name_, centre, size,
		mood.shafts_density if density < 0.0 else density)
	var fm := fv.material as FogMaterial
	fm.albedo = mood.shafts_tint
	# Emission makes the whole volume glow at a constant value, which is the
	# fastest way to erase the contrast the shaft is made of.
	fm.emission = Color(0, 0, 0)
	fm.height_falloff = mood.shafts_height_falloff
	fm.edge_fade = mood.shafts_edge_fade
	if mood.shafts_noise > 0.0:
		fm.density_texture = _shaft_noise(mood)
	return fv


## Ground mist. Same machinery, opposite settings: it wants a height falloff so
## it lies on the floor, and a soft edge so the box never shows.
static func ground_mist(parent: Node3D, mood: Mood, centre: Vector3, size: Vector3,
		density := 0.055, name_ := "GroundMist") -> FogVolume:
	var fv := _fog_box(parent, name_, centre, size, density)
	var fm := fv.material as FogMaterial
	fm.albedo = mood.fog_color
	fm.emission = mood.fog_emission
	fm.height_falloff = 1.2
	fm.edge_fade = 0.5
	return fv


## The hero pocket: a negative-density ellipsoid parented to whatever follows
## the player, so he never hazes out while the background stays atmospheric.
## Strictly better than lowering the global fog, which flattens every layer.
static func hero_pocket(parent: Node3D, size := Vector3(13.0, 9.0, 9.0),
		density := -0.9) -> FogVolume:
	var fv := _fog_box(parent, "HeroPocket", Vector3.ZERO, size, density)
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var fm := fv.material as FogMaterial
	fm.height_falloff = 0.0
	fm.edge_fade = 0.6
	return fv


static func _fog_box(parent: Node3D, name_: String, centre: Vector3, size: Vector3,
		density: float) -> FogVolume:
	var fv := FogVolume.new()
	fv.name = name_
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = size
	fv.position = centre
	var fm := FogMaterial.new()
	fm.density = density
	fm.albedo = Color(1.0, 0.93, 0.82)
	fm.emission = Color(0.06, 0.045, 0.035)
	fm.height_falloff = 1.2
	fm.edge_fade = 0.5
	fv.material = fm
	parent.add_child(fv)
	return fv


static func _shaft_noise(mood: Mood) -> NoiseTexture3D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = mood.shafts_noise_scale
	n.fractal_octaves = 3
	var tex := NoiseTexture3D.new()
	tex.width = 32
	tex.height = 32
	tex.depth = 32
	tex.seamless = true
	tex.noise = n
	# Remap so the noise thins the beam rather than punching holes in it: the
	# floor keeps the shaft continuous, the peak gives it the dust variation.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0 - mood.shafts_noise, 1.0 - mood.shafts_noise,
		1.0 - mood.shafts_noise))
	ramp.set_color(1, Color.WHITE)
	tex.color_ramp = ramp
	return tex


# ---------------------------------------------------------------------------
# Practical lights
# ---------------------------------------------------------------------------

## Drives a light's energy. One Node, one float write per frame, deterministic
## enough that a capture of a flickering lamp is not a lottery.
class Flicker extends Node:
	var base := 1.0
	var mode: int = LightingRig.Flick.NONE
	var amount := 0.12
	var hz := 6.0
	var _t := 0.0
	var _seed := 0.0
	var _noise := FastNoiseLite.new()

	func _ready() -> void:
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_noise.frequency = 1.0
		# Offset per instance so a row of lamps does not pulse in unison, which
		# is the single clearest tell that they came out of a for-loop.
		_seed = randf() * 512.0

	func _process(delta: float) -> void:
		var light := get_parent() as Light3D
		if light == null:
			return
		_t += delta
		var k := 1.0
		match mode:
			LightingRig.Flick.HUM:
				k = 1.0 + sin(_t * hz * TAU) * amount * 0.5 \
					+ _noise.get_noise_2d(_seed, _t * hz * 0.5) * amount * 0.5
			LightingRig.Flick.FAIL:
				# Mostly on, with short stutters — a tube failing to strike.
				var w := _noise.get_noise_2d(_seed, _t * 1.4)
				k = 1.0 if w < 0.55 else 1.0 - amount * (0.4 + 0.6 * absf(sin(_t * 47.0)))
			LightingRig.Flick.FIRE:
				k = 1.0 + _noise.get_noise_2d(_seed, _t * hz) * amount
			LightingRig.Flick.BLINK:
				k = 1.0 if fmod(_t * hz, 2.0) < 1.0 else 0.0
		light.light_energy = base * maxf(k, 0.0)


## A practical: a light that exists in the fiction. Windows, lamps, flares,
## headlights, the sodium pole nobody turned off.
##
## The point of routing these through here is that they come out consistent —
## quadratic falloff instead of the engine's linear default, a fog contribution
## that matches the bulb rather than whatever the author last typed, distance
## fade so a street of them is affordable, and flicker as a parameter instead
## of a bespoke `_process` in every level script.
static func practical(parent: Node3D, at: Vector3, bulb: Bulb, energy := -1.0,
		range_ := -1.0, flick := -1, name_ := "") -> OmniLight3D:
	var spec: Array = BULBS[bulb]
	var l := OmniLight3D.new()
	l.name = name_ if name_ != "" else "Practical%s" % Bulb.keys()[bulb].capitalize()
	l.position = at
	l.light_color = spec[0]
	l.light_energy = spec[1] if energy < 0.0 else energy
	l.omni_range = spec[2] if range_ < 0.0 else range_
	l.light_volumetric_fog_energy = spec[3]
	# The engine's 1.0 attenuation is a linear ramp and it makes every lamp
	# read as a painted circle. 1.6-2.4 is the inverse-square-ish falloff that
	# gives a hot core and a long tail.
	l.omni_attenuation = spec[4]
	l.light_specular = 1.0
	# A street of practicals is only affordable if the far ones stop shading.
	l.distance_fade_enabled = true
	l.distance_fade_begin = 70.0
	l.distance_fade_length = 25.0
	l.distance_fade_shadow = 45.0
	parent.add_child(l)
	_attach_flicker(l, spec[5] if flick < 0 else flick)
	return l


## A practical with a direction: window slabs, door spill, headlights, anything
## that should throw a cone through the fog rather than a ball of light.
static func practical_spot(parent: Node3D, at: Vector3, aim: Vector3, bulb: Bulb,
		energy := -1.0, range_ := -1.0, angle := 45.0, shadows := true,
		flick := -1, name_ := "") -> SpotLight3D:
	var spec: Array = BULBS[bulb]
	var l := SpotLight3D.new()
	l.name = name_ if name_ != "" else "Spot%s" % Bulb.keys()[bulb].capitalize()
	l.position = at
	if not aim.is_equal_approx(at):
		# UP is degenerate for a lamp aimed straight down, which is most of
		# them; fall back to the world Z axis so the cone still points right.
		var up := Vector3.UP
		if absf((aim - at).normalized().dot(Vector3.UP)) > 0.999:
			up = Vector3.BACK
		l.look_at_from_position(at, aim, up)
	l.light_color = spec[0]
	l.light_energy = spec[1] if energy < 0.0 else energy
	l.spot_range = spec[2] if range_ < 0.0 else range_
	l.spot_angle = angle
	# Without angle attenuation the cone has a hard rim that reads as a stencil.
	l.spot_angle_attenuation = 1.4
	l.spot_attenuation = spec[4]
	l.light_volumetric_fog_energy = spec[3]
	# A practical only earns a shadow if something is meant to be cut out of
	# its beam — a door frame, a louvre, a railing. Otherwise it is pure cost.
	l.shadow_enabled = shadows
	l.shadow_bias = 0.04
	l.shadow_normal_bias = 1.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 70.0
	l.distance_fade_length = 25.0
	l.distance_fade_shadow = 45.0
	parent.add_child(l)
	_attach_flicker(l, spec[5] if flick < 0 else flick)
	return l


## Sculpt darkness back in. A standard film trick Godot supports natively, and
## the correct answer to "that corner is too bright" when the corner is bright
## because of bounce you otherwise want.
static func negative_fill(parent: Node3D, at: Vector3, energy := 0.7, range_ := 8.0,
		name_ := "NegativeFill") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = name_
	l.position = at
	l.light_negative = true
	l.light_energy = energy
	l.omni_range = range_
	l.omni_attenuation = 1.4
	parent.add_child(l)
	return l


static func _attach_flicker(light: Light3D, mode: int) -> void:
	if mode == Flick.NONE:
		return
	var f := Flicker.new()
	f.name = "Flicker"
	f.base = light.light_energy
	f.mode = mode
	match mode:
		Flick.HUM:
			f.amount = 0.06
			f.hz = 11.0
		Flick.FAIL:
			f.amount = 0.85
			f.hz = 1.0
		Flick.FIRE:
			f.amount = 0.28
			f.hz = 5.0
		Flick.BLINK:
			f.amount = 1.0
			f.hz = 1.6
	light.add_child(f)


# ---------------------------------------------------------------------------
# Colour grading
# ---------------------------------------------------------------------------

## Build the mood's grade as a 3D LUT for `Environment.adjustment_color_correction`.
##
## Godot samples this texture with the frame colour as the coordinate, AFTER
## tonemapping and after brightness/contrast/saturation, in display space. So
## texel (i, j, k) has to hold the graded value of the colour that samples it,
## which with linear filtering and no half-texel correction on Godot's side is
## ((i + 0.5) / N, ...). Get that offset wrong and the whole frame shifts.
##
## FORMAT_RGBF rather than RGB8 on purpose: a float texture is never sRGB-
## decoded on upload, so the LUT means exactly what it says, and there is no
## 8-bit quantisation to band the sky gradients this game is full of.
static func grade_lut(mood: Mood) -> ImageTexture3D:
	var n: int = maxi(mood.grade_lut_size, 2)
	var slices: Array[Image] = []
	for k in range(n):
		var img := Image.create_empty(n, n, false, Image.FORMAT_RGBF)
		var b := (float(k) + 0.5) / float(n)
		for j in range(n):
			var g := (float(j) + 0.5) / float(n)
			for i in range(n):
				var r := (float(i) + 0.5) / float(n)
				img.set_pixel(i, j, _grade_pixel(mood, Color(r, g, b)))
		slices.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBF, n, n, n, false, slices)
	return tex


static func _grade_pixel(mood: Mood, src: Color) -> Color:
	var v := src

	# Split-tone first, while the luminance still means what the author saw.
	# The tint colours are centred on 0.5, so neutral is a no-op multiply.
	var lum := v.r * 0.2126 + v.g * 0.7152 + v.b * 0.0722
	var w := smoothstep(0.15, 0.85, lum)
	var tint := Color(
		lerpf(mood.grade_shadow_tint.r, mood.grade_highlight_tint.r, w) * 2.0,
		lerpf(mood.grade_shadow_tint.g, mood.grade_highlight_tint.g, w) * 2.0,
		lerpf(mood.grade_shadow_tint.b, mood.grade_highlight_tint.b, w) * 2.0)
	v = Color(v.r * tint.r, v.g * tint.g, v.b * tint.b)

	# ASC CDL order: slope, offset, power. Expressed as gain / lift / gamma
	# because that is what the knobs are called on a grading panel, and gamma
	# is inverted so >1 opens the midtones the way an author expects.
	v = Color(v.r * mood.grade_gain.r + mood.grade_lift.r,
		v.g * mood.grade_gain.g + mood.grade_lift.g,
		v.b * mood.grade_gain.b + mood.grade_lift.b)
	v = Color(
		pow(maxf(v.r, 0.0), 1.0 / maxf(mood.grade_gamma.r, 0.01)),
		pow(maxf(v.g, 0.0), 1.0 / maxf(mood.grade_gamma.g, 0.01)),
		pow(maxf(v.b, 0.0), 1.0 / maxf(mood.grade_gamma.b, 0.01)))

	# Temperature and tint last: small channel gains for the correction you do
	# not want to spend three curves on.
	v = Color(v.r * (1.0 + mood.grade_temperature * 0.14),
		v.g * (1.0 - mood.grade_tint * 0.12),
		v.b * (1.0 - mood.grade_temperature * 0.14))

	# Soft knee instead of a hard clamp. A warm highlight push routinely takes
	# red past 1.0, and clamping there flat-lines the brightest part of the
	# frame — the sun face, the chain, the specular on a wet stone — into one
	# value. Rolling it off keeps the separation that is the whole point of
	# grading the highlights in the first place.
	v = Color(_knee(v.r), _knee(v.g), _knee(v.b))
	if mood.grade_strength < 1.0:
		v = src.lerp(v, clampf(mood.grade_strength, 0.0, 1.0))
	return v


static func _knee(x: float) -> float:
	const K := 0.90
	if x <= K:
		return maxf(x, 0.0)
	return K + (1.0 - K) * (1.0 - exp(-(x - K) / (1.0 - K)))


# ---------------------------------------------------------------------------
# Exposure maths — the same curve the reference at the top of this file uses
# ---------------------------------------------------------------------------

## AgX's neutral transfer: a linear scene value in, the display value (0-1,
## sRGB-encoded, i.e. what a screenshot's pixel reads) out.
##
## The AgX matrices are white-preserving in both directions, so on the neutral
## axis the whole transform collapses to log2 -> normalise -> sigmoid, and the
## final pow(2.2) is undone by the display encode. That is why this is a few
## lines rather than two 3x3s. Valid for the default look; `agx_white` and
## `agx_contrast` reshape it (a lower white raises everything above middle
## grey, a higher contrast steepens around it).
static func agx_display(linear: float) -> float:
	const MIN_EV := -12.4739311883324
	const MAX_EV := 4.02606881167227
	var t := clampf(linear, 1e-10, 16.5)
	var x := clampf(log(t) / log(2.0), MIN_EV, MAX_EV)
	x = (x - MIN_EV) / (MAX_EV - MIN_EV)
	var x2 := x * x
	var x4 := x2 * x2
	var x6 := x4 * x2
	var y := -17.86 * x6 * x + 78.01 * x6 - 126.7 * x4 * x + 92.06 * x4 \
		- 28.72 * x2 * x + 4.361 * x2 - 0.1718 * x + 0.002857
	return clampf(y, 0.0, 1.0)


## Where a surface lands on screen. `linear_albedo` is the LINEAR albedo — run
## a hex through `srgb_to_linear()` first, or take it from the table at the top.
static func expose(linear_albedo: float, energy: float, ndotl := 0.85,
		exposure := 1.0) -> float:
	return agx_display(linear_albedo * energy * ndotl * exposure)


## What key energy puts this albedo at that screen value. The inverse of the
## line above, solved by bisection because the sigmoid has no closed form.
static func key_for(linear_albedo: float, screen_target: float, ndotl := 0.85) -> float:
	var lo := 1e-4
	var hi := 40.0
	for _i in range(48):
		var mid := (lo + hi) * 0.5
		if agx_display(linear_albedo * mid * ndotl) < screen_target:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## Hex is sRGB, the shader multiplies in linear, and the gap is a factor of
## four in the darks. This is the conversion that stops "why is my asphalt
## black" happening a fifth time.
static func srgb_to_linear(c: float) -> float:
	if c <= 0.04045:
		return c / 12.92
	return pow((c + 0.055) / 1.055, 2.4)


static func albedo_linear(hex: Color) -> Vector3:
	return Vector3(srgb_to_linear(hex.r), srgb_to_linear(hex.g), srgb_to_linear(hex.b))


## Blackbody colour for a temperature in kelvin, so a level can say "2200 K"
## instead of guessing at an orange and drifting a little further each time.
## Tanner Helland's approximation; good from 1000 K to 12000 K.
##
## It returns the same kind of value as the hexes in ART_DIRECTION's colour
## script, so it is a drop-in for `sun_color` / `rim_color` and the two can be
## compared directly. Remember a warm tint costs luminance — the blue channel
## at 2200 K is about 0.15, so the same energy reads dimmer than at 5500 K.
static func kelvin(k: float) -> Color:
	var t := clampf(k, 1000.0, 12000.0) / 100.0
	var r := 255.0
	var g := 255.0
	var b := 255.0
	if t <= 66.0:
		g = 99.4708025861 * log(t) - 161.1195681661
		if t <= 19.0:
			b = 0.0
		else:
			b = 138.5177312231 * log(t - 10.0) - 305.0447927307
	else:
		r = 329.698727446 * pow(t - 60.0, -0.1332047592)
		g = 288.1221695283 * pow(t - 60.0, -0.0755148492)
	return Color(clampf(r, 0.0, 255.0) / 255.0, clampf(g, 0.0, 255.0) / 255.0,
		clampf(b, 0.0, 255.0) / 255.0)


static func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)
