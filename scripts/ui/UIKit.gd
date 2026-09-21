class_name UIKit
## Shared drawing for the game's interface.
##
## Everything is drawn. A StyleBox with rounded corners is the default engine
## look the brief forbids, and it would fight the hand-made quality of the rest
## of the game. These are the shapes the whole UI is built from: a cut-corner
## slab, a chevron, letterspaced text, and a rule.
##
## The language: hard-edged, slightly skewed, cut corners on the leading edge —
## painted signage, not glass.

const CREAM := Color(0.96, 0.93, 0.86)
const INK := Color(0.07, 0.065, 0.075)
const SAUCE := Color(0.82, 0.13, 0.09)
const SAUCE_HOT := Color(1.0, 0.44, 0.16)
const GOLD := Color(1.0, 0.80, 0.32)
const DIM := Color(0.62, 0.60, 0.56)


## A slab with its leading corners cut. `skew` shears the top edge right.
static func slab(ci: CanvasItem, rect: Rect2, fill: Color, cut := 14.0,
		skew := 8.0) -> PackedVector2Array:
	var p := PackedVector2Array([
		rect.position + Vector2(cut + skew, 0.0),
		rect.position + Vector2(rect.size.x + skew, 0.0),
		rect.position + Vector2(rect.size.x, rect.size.y),
		rect.position + Vector2(cut, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y - cut),
		rect.position + Vector2(skew, cut),
	])
	ci.draw_colored_polygon(p, fill)
	return p


static func slab_outline(ci: CanvasItem, pts: PackedVector2Array, color: Color,
		width := 2.0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, width, true)


## The selection marker: a solid chevron pointing at the active row.
static func chevron(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, -size),
		at + Vector2(size * 1.15, 0.0),
		at + Vector2(0.0, size),
		at + Vector2(size * 0.35, 0.0),
	]), color)


## Letterspaced text. Godot cannot letterspace a draw_string, and tight default
## spacing is most of what makes engine UI look like engine UI.
static func spaced(ci: CanvasItem, font: Font, at: Vector2, text: String,
		size: int, color: Color, tracking := 3.0,
		align_center := false) -> float:
	var total := 0.0
	for i in text.length():
		total += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + tracking
	total -= tracking

	var x := at.x - (total * 0.5 if align_center else 0.0)
	for i in text.length():
		var ch := text[i]
		ci.draw_string(font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + tracking
	return total


## Text with a hard offset shadow. At speed a shadow separates from any
## background; an outline only thickens the glyph.
static func shadowed(ci: CanvasItem, font: Font, at: Vector2, text: String,
		size: int, color: Color, shadow := Color(0, 0, 0, 0.6),
		offset := Vector2(2.0, 3.0), center := false) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at - Vector2(w * 0.5 if center else 0.0, 0.0)
	ci.draw_string(font, p + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func rule(ci: CanvasItem, from: Vector2, to: Vector2, color: Color,
		width := 2.0) -> void:
	ci.draw_line(from, to, color, width, true)


## A row of diamond pips — chains earned out of a total.
static func pips(ci: CanvasItem, at: Vector2, filled: int, total: int,
		r := 8.0, gap := 22.0) -> void:
	for i in total:
		var c := at + Vector2(i * gap, 0.0)
		var d := PackedVector2Array([
			c + Vector2(0.0, -r), c + Vector2(r * 0.8, 0.0),
			c + Vector2(0.0, r), c + Vector2(-r * 0.8, 0.0),
		])
		if i < filled:
			ci.draw_colored_polygon(d, GOLD)
		else:
			var closed := d.duplicate()
			closed.append(d[0])
			ci.draw_polyline(closed, DIM * Color(1, 1, 1, 0.55), 1.6, true)
