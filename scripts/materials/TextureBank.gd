class_name TextureBank
## Real surface detail, from CC0 scans.
##
## `surface_weathered.gdshader` was always built to take these: it has a
## `detail_normal` slot marked hint_normal, a `detail_mask`, triplanar
## sampling, one-step parallax and a distance fade. What it was being fed was
## FastNoiseLite -- and fractal noise has no STRUCTURE. It undulates. Real
## concrete has aggregate, real cloth has a weave, real steel has pitting, and
## those are what a light has to catch for a surface to read as a material
## rather than as clay with a colour on it.
##
## So the procedural side keeps everything it was good at -- the chroma law,
## the weathering, the edge wear that finds a chamfer, dust by world normal --
## and only the micro-surface comes from a scan. Albedo is still generated, so
## no texture can smuggle a colour past MaterialLab.world_tint().
##
## 512x512, which is more than a triplanar detail tap resolves at this camera
## distance, and the whole set is under a megabyte.

const DIR := "res://assets/textures/"

## family -> ambientCG set backing it.
const SETS := {
	"concrete": "Concrete033",
	"plaster": "Plaster001",
	"metal": "PaintedMetal004",
	"rust": "Rust004",
	"ground": "Ground054",
	"fabric": "Fabric062",
}

static var _cache: Dictionary = {}


## Normal map for a family. Unknown families fall back to concrete rather than
## returning null, because a null in the slot silently drops all detail and the
## failure looks like "the textures did not help" instead of like a typo.
static func normal(family: String) -> Texture2D:
	return _load(family, "normal")


## Roughness/detail mask. The shader reads this as a greyscale modulation on
## albedo and roughness, which is exactly what a scanned roughness map is.
static func detail(family: String) -> Texture2D:
	return _load(family, "rough")


static func _load(family: String, kind: String) -> Texture2D:
	var set_name: String = SETS.get(family, SETS["concrete"])
	var key := set_name + "_" + kind
	if _cache.has(key):
		return _cache[key]
	var path := DIR + key + ".jpg"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	else:
		push_warning("TextureBank: missing %s" % path)
	_cache[key] = tex
	return tex
