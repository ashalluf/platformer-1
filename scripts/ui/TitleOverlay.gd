class_name TitleOverlay extends Control
## The game's face.
##
## Arabic-first logotype: the name set large in Kufi, with the Latin
## transliteration letterspaced underneath. That order is the point — this is a
## love letter to a place, and the place's script leads.
##
## Everything is anchored to the left column, because the frame behind it is
## the beauty benchmark and the right two thirds of that frame is the distance
## Wanis has to cover. Type does not get to stand in front of it.

const LOGO_AR := "ليبيان غانغستاز"
const LOGO_EN := "LIBYAN GANGSTAS"
const TAGLINE := "شرق ليبيا"

## Left margin and the width the type block is allowed to occupy, in pixels at
## a 1280-wide reference; both scale with the viewport.
const MARGIN := 0.075
const COLUMN := 0.42

var _t := 0.0
var _font: Font
var _kufi: Font
var _chains := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_kufi = PropKit.font(PropKit.FONT_KUFI)
	_chains = Gx.chain_count()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var x := view.x * MARGIN

	_scrim(view)

	# Arabic logotype, with a warm offset behind it doing the work of a bevel.
	var ar_size := int(view.y * 0.108)
	var ar_y := view.y * 0.235
	var off := maxf(3.0, view.y * 0.006)
	draw_string(_kufi, Vector2(x + off, ar_y + off), LOGO_AR,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ar_size, Color(0.52, 0.09, 0.04, 0.9))
	draw_string(_kufi, Vector2(x, ar_y), LOGO_AR,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ar_size, UIKit.CREAM)

	# Latin beneath, letterspaced wide.
	UIKit.spaced(self, _font, Vector2(x + 3.0, ar_y + view.y * 0.058), LOGO_EN,
		int(view.y * 0.033), UIKit.SAUCE_HOT, view.y * 0.0105)

	var tag_size := int(view.y * 0.024)
	draw_string(_kufi, Vector2(x + 3.0, ar_y + view.y * 0.098), TAGLINE,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, UIKit.DIM)

	# The rule that separates the name from the menu under it.
	var ry := ar_y + view.y * 0.125
	UIKit.rule(self, Vector2(x, ry), Vector2(x + view.x * COLUMN * 0.86, ry),
		Color(1.0, 0.44, 0.16, 0.55), 2.0)

	# Chains earned, bottom right — the only progress the title screen shows.
	# It sits over lit walkway, so it carries its own slab.
	var tray := Rect2(Vector2(view.x - 262.0, view.y - 70.0), Vector2(240.0, 36.0))
	UIKit.slab(self, tray, Color(0.05, 0.045, 0.06, 0.66), 10.0, 6.0)
	UIKit.spaced(self, _font, Vector2(view.x - 238.0, view.y - 46.0), "CHAINS",
		15, UIKit.DIM, 3.0)
	UIKit.pips(self, Vector2(view.x - 148.0, view.y - 52.0), _chains, 5, 8.0, 24.0)

	# A slow breathing prompt, so the screen is never completely static.
	var a := 0.40 + 0.32 * sin(_t * 2.0)
	UIKit.spaced(self, _font, Vector2(x + 3.0, view.y - 46.0), "JUMP TO SELECT",
		14, Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, a), 4.0)


## A soft wedge of shade down the left column. Not a panel — the dawn has to
## keep coming through it, it only has to drop the value enough for cream type
## to sit on a lit concrete wall.
func _scrim(view: Vector2) -> void:
	var w := view.x * 0.56
	var dark := Color(0.035, 0.030, 0.045, 0.62)
	var clear := Color(0.035, 0.030, 0.045, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, view.y),
			Vector2(0, view.y)]),
		PackedColorArray([dark, clear, clear, dark]))
	# A second, tighter pass under the type so the logotype never fights a
	# bright patch of sky.
	var w2 := view.x * 0.30
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w2, 0), Vector2(w2, view.y * 0.72),
			Vector2(0, view.y * 0.72)]),
		PackedColorArray([Color(0.02, 0.02, 0.03, 0.34), clear, clear,
			Color(0.02, 0.02, 0.03, 0.34)]))
