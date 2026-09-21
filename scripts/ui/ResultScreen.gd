class_name ResultScreen extends Control
## The card at the end of a run of a level — cleared, or out of lives.
##
## It reports, it does not celebrate. The level's own name in Arabic, what you
## picked up, whether the Iced Out bottle is still out there, and one prompt.
## A results screen that throws confetti at someone who just lost their last
## life is the wrong game.

signal dismissed(action: String)

enum Kind { CLEARED, GAME_OVER }

var kind: Kind = Kind.CLEARED
var entry: World.Entry
var sriracha := 0
var iced_out := false
var chain := false
var elapsed := 0.0

var _font: Font
var _kufi: Font
var _naskh: Font
var _t := 0.0
var _in := 0.0
var _armed := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_kufi = PropKit.font(PropKit.FONT_KUFI)
	_naskh = PropKit.font(PropKit.FONT_NASKH)
	Audio.play_2d("life" if kind == Kind.CLEARED else "hurt", -3.0,
		1.0 if kind == Kind.CLEARED else 0.7)


func _process(delta: float) -> void:
	_t += delta
	_in = minf(_in + delta * 1.7, 1.0)
	# Input is refused until the card has finished arriving, so nobody skips
	# the screen with the button they were already holding.
	if _in >= 1.0:
		_armed = true
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("attack") \
			or event.is_action_pressed("pause"):
		_armed = false
		Audio.play_2d("ui", -4.0, 1.2, "UI")
		dismissed.emit("continue" if kind == Kind.CLEARED else "retry")
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var view := get_viewport_rect().size
	var cx := view.x * 0.5
	var ease := _in * _in * (3.0 - 2.0 * _in)

	draw_rect(Rect2(Vector2.ZERO, view), Color(0.03, 0.028, 0.038, 0.82 * ease))

	var card := Rect2(Vector2(cx - 340.0, view.y * 0.20 - (1.0 - ease) * 26.0),
		Vector2(680.0, view.y * 0.515))
	var pts := UIKit.slab(self, card, Color(0.065, 0.060, 0.072, 0.94 * ease), 26.0, 14.0)
	var edge := UIKit.GOLD if kind == Kind.CLEARED else Color(0.72, 0.20, 0.16)
	UIKit.slab_outline(self, pts, Color(edge.r, edge.g, edge.b, 0.75 * ease), 2.4)

	var head_ar := "تم" if kind == Kind.CLEARED else "انتهت المحاولة"
	var head_en := "LEVEL CLEARED" if kind == Kind.CLEARED else "OUT OF LIVES"
	var hw := _kufi.get_string_size(head_ar, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var hy := card.position.y + 62.0
	draw_string(_kufi, Vector2(cx - hw * 0.5, hy), head_ar,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(UIKit.CREAM.r, UIKit.CREAM.g,
			UIKit.CREAM.b, ease))
	UIKit.spaced(self, _font, Vector2(cx, hy + 30.0), head_en, 20,
		Color(edge.r, edge.g, edge.b, ease), 6.0, true)
	UIKit.rule(self, Vector2(card.position.x + 46.0, hy + 52.0),
		Vector2(card.position.x + card.size.x - 46.0, hy + 52.0),
		Color(edge.r, edge.g, edge.b, 0.45 * ease), 2.0)

	if entry != null:
		var nw := _naskh.get_string_size(entry.name_ar, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 26).x
		draw_string(_naskh, Vector2(cx - nw * 0.5, hy + 92.0), entry.name_ar,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.82, 0.78, 0.74, ease))
		UIKit.spaced(self, _font, Vector2(cx, hy + 118.0), entry.name_en, 15,
			Color(0.66, 0.62, 0.60, ease), 3.0, true)

	# The tally. One row per thing, value right-aligned, so the eye reads down
	# the labels and across only where it cares.
	var rows := [
		["SRIRACHA", "%d" % sriracha, UIKit.SAUCE_HOT],
		["ICED OUT", "FOUND" if iced_out else "STILL OUT THERE",
			UIKit.GOLD if iced_out else UIKit.DIM],
		["CHAIN", "EARNED" if chain else "NOT YET",
			UIKit.GOLD if chain else UIKit.DIM],
		["TIME", "%d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], UIKit.CREAM],
	]
	var y := hy + 164.0
	for i in rows.size():
		var row: Array = rows[i]
		# Each row slides in behind the one above it.
		var ra := clampf((_in - 0.25 - i * 0.10) * 4.0, 0.0, 1.0)
		var lx := card.position.x + 66.0
		var rx := card.position.x + card.size.x - 66.0
		UIKit.spaced(self, _font, Vector2(lx + (1.0 - ra) * 14.0, y),
			str(row[0]), 15, Color(0.62, 0.59, 0.56, ra), 3.2)
		var tint: Color = row[2]
		var vw := _font.get_string_size(str(row[1]), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 17).x
		draw_string(_font, Vector2(rx - vw, y), str(row[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(tint.r, tint.g, tint.b, ra))
		y += 38.0

	# The prompt holds a dim baseline before the card is armed, so the bottom of
	# the card is never empty and the brightening reads as "now you may".
	var a := 0.14
	if _armed:
		a = 0.40 + 0.34 * sin(_t * 2.4)
	var prompt := "JUMP TO CONTINUE" if kind == Kind.CLEARED else "JUMP TO TRY AGAIN"
	UIKit.spaced(self, _font, Vector2(cx, card.position.y + card.size.y - 34.0),
		prompt, 14, Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, a), 4.0, true)
