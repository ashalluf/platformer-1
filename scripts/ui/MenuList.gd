class_name MenuList extends Control
## A keyboard/controller menu, drawn.
##
## No Button nodes: a focused Button draws a themed rectangle and that is the
## exact default look this project is not allowed to have. This owns its own
## selection, input and drawing, and reports which row was chosen.
##
## Geometry is authored in UIKit's 720-tall design space — `origin`, `width` and
## `row_height` are design units, multiplied by `UIKit.ui_scale()` at draw time.
## That is why a caller can hard-code `origin = Vector2(96, 336)` and still be
## correct at 4K.
##
## A row is a grid, not a string: [chevron][icon][label / sub-label][meter]
## [value or Arabic]. The value column is measured from the right edge, so
## values line up down the list however long the labels are.

signal chosen(index: int, id: String)
signal changed(index: int, id: String)

class Row extends RefCounted:
	var id := ""
	var label := ""
	var arabic := ""
	var enabled := true
	var value := ""       ## right-aligned, for settings rows
	var sub := ""         ## a quiet second line under the label
	var icon := ""        ## see `_icon()`; "" draws none
	var bar := -1.0       ## 0..1 draws a meter in the row; < 0 draws none

## Inner padding of a row, design units. Public because a screen that draws a
## column header over the list has to land on the same column the rows use.
const ROW_PAD := 22.0

var rows: Array[Row] = []
var selected := 0
var row_height := 54.0     ## design units
var origin := Vector2(120.0, 320.0)  ## design units
var width := 420.0         ## design units
var font: Font
var arabic_font: Font
var accept_input := true
## Design-space width reserved on the right for values, so columns align.
var value_column := 92.0

var _pulse := 0.0
var _slide := 0.0
var _sweep := 1.0     ## 0..1 wipe across the newly selected row
var _kick := 0.0      ## chevron overshoot impulse, decays
var _intro := 0.0     ## rows fly in on open
var _dir := 0         ## direction of the last move, for the overshoot
var _t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	arabic_font = PropKit.font(PropKit.FONT_NASKH)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Repeat is needed for the slabs' printed tooth; set once here rather than
	# letting the first _draw flip it.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func add_row(id: String, label: String, arabic := "", enabled := true, value := "") -> Row:
	var r := Row.new()
	r.id = id
	r.label = label
	r.arabic = arabic
	r.enabled = enabled
	r.value = value
	rows.append(r)
	return r


func current() -> Row:
	return rows[selected] if selected >= 0 and selected < rows.size() else null


func row_by_id(id: String) -> Row:
	for r: Row in rows:
		if r.id == id:
			return r
	return null


## Replay the entry animation — for a panel that is shown again rather than
## rebuilt.
func open() -> void:
	_intro = 0.0
	_sweep = 0.0


func ui_scale() -> float:
	return UIKit.ui_scale(self)


## Screen-space rect of the whole list. Any screen that wants to align a
## column, a rule or a caption to the menu should ask for this rather than
## re-deriving the numbers — the list is the one that knows how design units
## became pixels.
func column_rect() -> Rect2:
	var s := ui_scale()
	return Rect2(origin * s,
		Vector2(width * s, maxf(rows.size(), 1) * row_height * s))


## Screen-space rect of a row, for a screen that needs to line something up
## with the list (the settings panel does).
func row_rect(i: int) -> Rect2:
	var s := ui_scale()
	return Rect2(Vector2(origin.x, origin.y + i * row_height) * s,
		Vector2(width, row_height - 10.0) * s)


func _process(delta: float) -> void:
	_t += delta
	_pulse = fmod(_pulse + delta * 2.2, TAU)
	_slide = UIKit.damp(_slide, float(selected), 18.0, delta)
	_sweep = minf(_sweep + delta * 3.4, 1.0)
	_kick = maxf(_kick - delta * 3.2, 0.0)
	_intro = minf(_intro + delta, 2.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not accept_input or rows.is_empty():
		return
	if event.is_action_pressed("move_up", true):
		_step(-1)
	elif event.is_action_pressed("move_down", true):
		_step(1)
	elif event.is_action_pressed("confirm") or event.is_action_pressed("jump") \
			or event.is_action_pressed("attack"):
		var r := current()
		if r and r.enabled:
			Audio.play_2d("ui", -4.0, 1.25, "UI")
			_sweep = 0.0
			chosen.emit(selected, r.id)


func _step(dir: int) -> void:
	var start := selected
	for i in rows.size():
		selected = wrapi(selected + dir, 0, rows.size())
		if rows[selected].enabled:
			break
	if selected != start:
		Audio.play_2d("ui", -10.0, 0.95, "UI")
		_sweep = 0.0
		_kick = 1.0
		_dir = 1 if (selected - start) > 0 else -1
		changed.emit(selected, rows[selected].id)


func _draw() -> void:
	if rows.is_empty():
		return
	var s := ui_scale()
	var rh := row_height * s
	var w := width * s
	var org := origin * s
	var cut := 12.0 * s
	var skew := 7.0 * s
	var val_w := value_column * s
	var pad := ROW_PAD * s

	# Does any row carry an icon? If none does, the label column starts at the
	# left pad — a reserved-but-empty gutter is the sort of thing that makes a
	# menu look misaligned for no reason anyone can name.
	var has_icons := false
	for r: Row in rows:
		if r.icon != "":
			has_icons = true
			break
	var label_x := org.x + pad + (30.0 * s if has_icons else 0.0)

	for i in rows.size():
		var r: Row = rows[i]
		var active := i == selected

		# Entry: each row eases in from the left, staggered down the list. The
		# stagger is what makes it read as a list arriving rather than a panel
		# appearing.
		var e: float = UIKit.out_cubic(clampf((_intro - i * 0.055) / 0.34, 0.0, 1.0))
		if e <= 0.001:
			continue
		var dx: float = (1.0 - e) * -46.0 * s
		# The active row slides a little further out of the column, so the
		# selection has depth as well as colour.
		if active:
			dx += UIKit.out_cubic(_sweep) * 7.0 * s

		var rect := Rect2(Vector2(org.x + dx, org.y + i * rh), Vector2(w, rh - 10.0 * s))

		var fill := UIKit.INK
		fill.a = (0.80 if active else 0.44) * e
		if not r.enabled:
			fill.a = 0.30 * e
		# The focused row rises off the page — the shadow shift is doing as much
		# work as the colour change is.
		var lift: float = (1.0 + UIKit.out_cubic(_sweep) * 1.1) if active else 1.0
		var pts := UIKit.slab(self, rect, fill, cut, skew, lift)

		if active:
			# Sauce wipes in from the leading edge and stops.
			UIKit.sweep_fill(self, pts, UIKit.out_quint(_sweep),
				Color(UIKit.SAUCE.r, UIKit.SAUCE.g, UIKit.SAUCE.b, 0.5 * e))
			var glow := UIKit.SAUCE_HOT.lerp(UIKit.GOLD, 0.25 + 0.25 * sin(_pulse))
			UIKit.slab_outline(self, pts, Color(glow.r, glow.g, glow.b, e), 2.2 * s)
			# A hot bar on the cut edge: the light source of the row.
			draw_line(pts[4], pts[5],
				Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, e),
				3.4 * s, true)
			draw_line(pts[5], pts[0],
				Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, 0.7 * e),
				2.0 * s, true)
		elif not r.enabled:
			# Struck through, deliberately. Faded-only rows read as a bug.
			UIKit.hatch(self, pts, Color(UIKit.SHADOW.r, UIKit.SHADOW.g,
				UIKit.SHADOW.b, 0.30 * e), 10.0 * s, 1.4 * s)
			UIKit.slab_outline(self, pts,
				Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, 0.18 * e), 1.2 * s)

		var text_col := UIKit.CREAM
		if not r.enabled:
			text_col = Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, 0.55)
		elif not active:
			text_col = UIKit.CREAM.lerp(UIKit.DIM, 0.35)
		text_col.a *= e

		if has_icons and r.icon != "":
			_icon(r.icon, Rect2(Vector2(org.x + dx + pad * 0.7,
				rect.position.y + rect.size.y * 0.5 - 9.0 * s),
				Vector2(18.0, 18.0) * s),
				Color(text_col.r, text_col.g, text_col.b,
					text_col.a * (1.0 if active else 0.7)), active)

		# Label baseline sits high in the row when there is a sub-line under it.
		var has_second := r.sub != ""
		var base_y := rect.position.y + rect.size.y * (0.46 if has_second else 0.63)
		UIKit.spaced(self, font, Vector2(label_x + dx, base_y), r.label,
			UIKit.type_size(self, UIKit.BODY), text_col,
			UIKit.type_track(self, UIKit.BODY), false, 0.22 if active else 0.0)

		if r.sub != "":
			UIKit.spaced(self, font, Vector2(label_x + dx, base_y + 15.0 * s), r.sub,
				UIKit.type_size(self, UIKit.MICRO),
				Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, 0.8 * e),
				UIKit.type_track(self, UIKit.MICRO))

		var right := rect.position.x + rect.size.x - pad

		if r.value != "":
			# Values are set in the Latin face at BODY rank, right-aligned on a
			# fixed column so the eye can run straight down them.
			var vf := UIKit.latin(0.25 if active else 0.0)
			var vsize := UIKit.type_size(self, UIKit.BODY)
			var vtrack: float = UIKit.type_track(self, UIKit.BODY) * 0.55
			var vw := UIKit.spaced_width(vf, r.value, vsize, vtrack)
			var vcol := Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g,
				UIKit.SAUCE_HOT.b, e) if active else text_col
			UIKit.spaced(self, vf, Vector2(right - vw, base_y), r.value, vsize,
				vcol, vtrack)
			right -= maxf(vw, val_w * 0.45) + 16.0 * s

		if r.arabic != "":
			# ARABIC IS NEVER LETTERSPACED — the glyphs are joined and tracking
			# severs the joins. One draw_string, right-aligned, TextServer does
			# the shaping and the bidi.
			var box := val_w * 2.0
			UIKit.arabic(self, Vector2(right - box,
					rect.position.y + rect.size.y * (0.42 if has_second else 0.58)),
				r.arabic, int(UIKit.type_size(self, UIKit.BODY) * 0.95),
				Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, e)
					if active else Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, e),
				HORIZONTAL_ALIGNMENT_RIGHT, box)

		if r.bar >= 0.0:
			# The meter gets its own column at 54% of the row rather than sitting
			# under the label: label and sub-label own the left, the instrument
			# and its number own the right. Stacking them collides the moment a
			# sub-label is longer than a word.
			var bar_x := rect.position.x + rect.size.x * 0.54
			var bar_rect := Rect2(
				Vector2(bar_x, rect.position.y + rect.size.y * 0.5 - 6.0 * s),
				Vector2(right - 14.0 * s - bar_x, 12.0 * s))
			if bar_rect.size.x > 40.0 * s:
				UIKit.meter(self, bar_rect, r.bar,
					UIKit.SAUCE_HOT if active else UIKit.SAUCE, active)

	# The chevron leads the highlight: it travels past the new row in the
	# direction of the move and settles back, and recoils horizontally at the
	# same time. Overshoot is the cheapest way to make a cursor feel like it
	# has mass.
	var recoil := sin(_kick * PI)
	var cy := org.y + _slide * rh + (rh - 10.0 * s) * 0.5 + recoil * _dir * 6.0 * s
	var breathe := sin(_pulse) * 2.5 * s
	var intro_a: float = clampf(_intro / 0.4, 0.0, 1.0)
	UIKit.chevron(self, Vector2(org.x - 20.0 * s + breathe - recoil * 7.0 * s, cy),
		10.0 * s * (1.0 + recoil * 0.18),
		Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, intro_a))


## Row icons, drawn. A small vocabulary of marks in the game's own shape
## language — diamonds, chevrons, slabs — rather than an icon font nobody in
## this project has licensed.
func _icon(kind: String, box: Rect2, col: Color, active: bool) -> void:
	var c := box.position + box.size * 0.5
	var r := box.size.x * 0.5
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.6, -r), c + Vector2(r, 0.0),
				c + Vector2(-r * 0.6, r)]), col)
		"back":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(r * 0.6, -r), c + Vector2(-r, 0.0),
				c + Vector2(r * 0.6, r), c + Vector2(r * 0.1, 0.0)]), col)
		"chain":
			for k in 2:
				var o := c + Vector2((k - 0.5) * r * 0.9, 0.0)
				var d := PackedVector2Array([
					o + Vector2(0.0, -r * 0.8), o + Vector2(r * 0.55, 0.0),
					o + Vector2(0.0, r * 0.8), o + Vector2(-r * 0.55, 0.0)])
				var closed := d.duplicate()
				closed.append(d[0])
				draw_polyline(closed, col, maxf(1.0, r * 0.22), true)
		"gear":
			# A cut octagon reads as machinery without pretending to be a cog.
			var pts := PackedVector2Array()
			for k in 8:
				var a := TAU * k / 8.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 if k % 2 == 0 else 0.72))
			draw_colored_polygon(pts, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.3, -r * 0.3), c + Vector2(r * 0.3, -r * 0.3),
				c + Vector2(r * 0.3, r * 0.3), c + Vector2(-r * 0.3, r * 0.3)]),
				Color(UIKit.INK.r, UIKit.INK.g, UIKit.INK.b, col.a))
		"ice":
			for k in 3:
				var a := PI * k / 3.0 + (0.3 if active else 0.0)
				var v := Vector2(cos(a), sin(a)) * r
				draw_line(c - v, c + v, col, maxf(1.0, r * 0.22), true)
		"map":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, r), c + Vector2(-r * 0.7, -r * 0.2),
				c + Vector2(0.0, -r), c + Vector2(r * 0.7, -r * 0.2)]), col)
		"sound":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r, -r * 0.4), c + Vector2(-r * 0.3, -r * 0.4),
				c + Vector2(r * 0.3, -r), c + Vector2(r * 0.3, r),
				c + Vector2(-r * 0.3, r * 0.4), c + Vector2(-r, r * 0.4)]), col)
		"screen":
			draw_rect(Rect2(c - Vector2(r, r * 0.72), Vector2(r * 2.0, r * 1.44)),
				col, false, maxf(1.0, r * 0.2))
		"shake":
			draw_polyline(PackedVector2Array([
				c + Vector2(-r, 0.0), c + Vector2(-r * 0.4, -r * 0.8),
				c + Vector2(r * 0.2, r * 0.8), c + Vector2(r, 0.0)]),
				col, maxf(1.0, r * 0.24), true)
		_:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, -r * 0.8), c + Vector2(r * 0.6, 0.0),
				c + Vector2(0.0, r * 0.8), c + Vector2(-r * 0.6, 0.0)]), col)
