class_name ResultScreen extends Control
## The card at the end of a run of a level — cleared, or out of lives.
##
## It reports, it does not celebrate. Four ranks, in this order and no other:
## the OUTCOME, the PLACE, the TALLY, the PROMPT. A results screen that throws
## confetti at someone who just lost their last life is the wrong game.
##
## The two outcomes are told apart by more than colour. CLEARED is warm, gold,
## solid-ruled, rises into frame and counts its tally up. OUT OF LIVES is cool,
## deep red, struck through with a hatch, drops in under its own weight and
## shows a tally that is already final. Read with the colour taken away, they
## are still obviously different screens.

signal dismissed(action: String)

enum Kind { CLEARED, GAME_OVER }

## The page unit, mirrored from TitleOverlay.Grid. Restated as a literal
## because a const that reaches into another class's inner class is a parse-order
## trap waiting to happen.
const U := 24.0

var kind: Kind = Kind.CLEARED
var entry: World.Entry
var sriracha := 0
var iced_out := false
var chain := false
var elapsed := 0.0

var _kufi: Font
var _naskh: Font
var _latin: Font
var _t := 0.0
var _in := 0.0
var _out := 0.0
var _armed := false
var _leaving := ""
var _counted := 0.0
var _ticked := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_kufi = UIKit.kufi()
	_naskh = UIKit.naskh()
	_latin = UIKit.latin(0.0)
	Audio.play_2d("life" if kind == Kind.CLEARED else "hurt", -3.0,
		1.0 if kind == Kind.CLEARED else 0.7)


func _process(delta: float) -> void:
	_t += delta
	_in = minf(_in + delta * 1.55, 1.0)
	# Input is refused until the card has finished arriving, so nobody skips
	# the screen with the button they were already holding.
	if _in >= 1.0 and _leaving == "":
		_armed = true

	if _leaving != "":
		_out = minf(_out + delta * 4.5, 1.0)
		if _out >= 1.0:
			var action := _leaving
			_leaving = ""
			dismissed.emit(action)
	else:
		_tally(delta)
	queue_redraw()


## The sriracha total counts rather than appearing, but only on a clear. After
## a death the number is not an achievement and should not behave like one.
func _tally(delta: float) -> void:
	if _in < 0.55 or sriracha <= 0:
		return
	if kind != Kind.CLEARED:
		_counted = float(sriracha)
		return
	_counted = minf(_counted + delta * maxf(float(sriracha) / 0.9, 24.0),
		float(sriracha))
	var n := int(_counted)
	if n > _ticked and n % maxi(1, int(sriracha / 14.0)) == 0:
		_ticked = n
		Audio.play_2d("ui", -21.0, 1.5 + 0.5 * (_counted / maxf(float(sriracha), 1.0)), "UI")


func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("attack") \
			or event.is_action_pressed("pause"):
		_armed = false
		Audio.play_2d("ui", -4.0, 1.2, "UI")
		# Let the card leave before the scene does. The signal fires at the end
		# of the exit, not the start of it — Stage frees this node the moment
		# it hears, so there is no second chance to animate.
		_leaving = "continue" if kind == Kind.CLEARED else "retry"
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var g := TitleOverlay.Grid.new(self)
	var view := get_viewport_rect().size
	var cleared := kind == Kind.CLEARED
	var accent := UIKit.GOLD if cleared else Color(0.74, 0.22, 0.17)

	# Arrival, and departure. A clear rises and settles; being out of lives
	# drops in and lands, with no overshoot at either end.
	var arrive := UIKit.out_back(_in, 1.15) if cleared else UIKit.out_cubic(_in)
	var fade := UIKit.out_quint(_in) * (1.0 - UIKit.out_cubic(_out))
	var travel := g.px(U * 1.4) * (1.0 - arrive)
	var slide := -travel if cleared else travel
	slide += g.px(U * 2.0) * UIKit.out_cubic(_out) * (-1.0 if cleared else 1.0)

	# The ground under the card: a dim, a vignette, grain. Cooler and heavier
	# when the run is over.
	UIKit.overlay(self, Rect2(Vector2.ZERO, view),
		(0.80 if cleared else 0.88) * fade, 0.55 * fade, 0.05 * fade, _t,
		UIKit.SHADOW if cleared else Color(0.03, 0.035, 0.055))

	var m := _metrics(g)
	var card: Rect2 = m["card"]
	card.position.y += slide

	var body := Color(0.075, 0.062, 0.058, 0.95 * fade) if cleared \
		else Color(0.050, 0.050, 0.064, 0.96 * fade)
	var pts := UIKit.slab(self, card, body, g.px(U * 1.1), g.px(U * 0.5))
	UIKit.slab_outline(self, pts, Color(accent.r, accent.g, accent.b, 0.80 * fade),
		maxf(1.6, g.px(2.6)))

	_outcome(g, m, card, accent, fade, slide)
	_place(g, m, card, fade, slide)
	_rows(g, m, card, slide)
	_prompt(g, m, card, fade, slide)


# --- Blocks -----------------------------------------------------------------

## Rank one: what happened. Arabic leads, Latin under it, a rule to close the
## block — the same shape every heading in the game takes.
func _outcome(g: TitleOverlay.Grid, m: Dictionary, card: Rect2, accent: Color,
		fade: float, slide: float) -> void:
	var cleared := kind == Kind.CLEARED
	var pad: float = m["pad"]
	# A two-letter word cannot carry the top rank of a card — it vanishes under
	# a letterspaced Latin line three times its width. The clear reads as a
	# sentence so the pairing has something to hold on to.
	var head_ar := "تم اجتياز المستوى" if cleared else "انتهت المحاولة"
	var head_en := "LEVEL CLEARED" if cleared else "OUT OF LIVES"
	var a := UIKit.out_quint(TitleOverlay.Grid.stage(_in, 0.18, 0.5)) * fade

	# Out of lives gets the same struck-through hatch MenuList uses on a row
	# you cannot pick. The language is already in the product; reuse it.
	if not cleared:
		var band := Rect2(card.position + Vector2(pad * 0.4, g.px(U * 1.0)),
			Vector2(card.size.x - pad * 0.8, m["head_h"]))
		var bpts := UIKit.slab(self, band, Color(0, 0, 0, 0), g.px(U * 0.4),
			g.px(U * 0.2))
		UIKit.hatch(self, bpts, Color(accent.r, accent.g, accent.b, 0.10 * a),
			g.px(11.0), g.px(1.6))

	UIKit.arabic(self, Vector2(card.position.x + pad, m["head_ar_y"] + slide),
		head_ar, m["head_ar"], Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, a),
		HORIZONTAL_ALIGNMENT_CENTER, card.size.x - pad * 2.0, true, 0.6)
	UIKit.spaced(self, UIKit.latin(0.3), Vector2(card.position.x + card.size.x * 0.5,
		m["head_en_y"] + slide), head_en, m["head_en"],
		Color(accent.r, accent.g, accent.b, a), m["head_track"], true)

	# Solid rule for a clear, broken rule for a run that ended. The form says
	# it before the colour does.
	var ry: float = m["rule_y"] + slide
	var x0 := card.position.x + pad
	var x1 := card.position.x + card.size.x - pad
	var col := Color(accent.r, accent.g, accent.b, 0.62 * a)
	if cleared:
		UIKit.rule(self, Vector2(x0, ry), Vector2(x1, ry), col, maxf(1.5, g.px(2.4)))
	else:
		var dash := g.px(U * 0.5)
		var x := x0
		while x < x1:
			UIKit.rule(self, Vector2(x, ry), Vector2(minf(x + dash, x1), ry), col,
				maxf(1.5, g.px(2.4)))
			x += dash * 2.0


## Rank two: where. Set quieter than the outcome and louder than the tally.
func _place(g: TitleOverlay.Grid, m: Dictionary, card: Rect2, fade: float,
		slide: float) -> void:
	if entry == null:
		return
	var pad: float = m["pad"]
	var a := UIKit.out_quint(TitleOverlay.Grid.stage(_in, 0.32, 0.5)) * fade
	var rise := (1.0 - UIKit.out_cubic(TitleOverlay.Grid.stage(_in, 0.32, 0.55))) \
		* g.px(U * 0.4)
	UIKit.arabic(self, Vector2(card.position.x + pad, m["place_ar_y"] + slide + rise),
		entry.name_ar, m["place_ar"], Color(0.86, 0.82, 0.77, a),
		HORIZONTAL_ALIGNMENT_CENTER, card.size.x - pad * 2.0)
	UIKit.spaced(self, _latin, Vector2(card.position.x + card.size.x * 0.5,
		m["place_en_y"] + slide + rise), entry.name_en, m["place_en"],
		Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, a), m["place_track"], true)


## Rank three: the tally. A ledger — label left, leader, value right — so the
## eye reads down the labels and across only where it cares. The two state
## rows carry a filled or empty gem as well as a word, because "FOUND" and
## "STILL OUT THERE" told apart by hue alone is not state clarity.
func _rows(g: TitleOverlay.Grid, m: Dictionary, card: Rect2, slide: float) -> void:
	var cleared := kind == Kind.CLEARED
	var pad: float = m["pad"]
	var lab_size: int = m["lab"]
	var val_size: int = m["val"]
	var rows := [
		["SRIRACHA", "%d" % int(round(_counted)), UIKit.SAUCE_HOT, -1],
		["ICED OUT", "FOUND" if iced_out else "STILL OUT THERE",
			UIKit.GOLD if iced_out else UIKit.DIM, 1 if iced_out else 0],
		["CHAIN", "EARNED" if chain else "NOT YET",
			UIKit.GOLD if chain else UIKit.DIM, 1 if chain else 0],
		["TIME", "%d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], UIKit.CREAM, -1],
	]
	var step: float = m["row_step"]
	var lx := card.position.x + pad
	var rx := card.position.x + card.size.x - pad
	# A clear reveals the ledger briskly; after a death it arrives slowly, one
	# line at a time, which is a different feeling for the same information.
	var beat := 0.085 if cleared else 0.16

	for i in rows.size():
		var row: Array = rows[i]
		var p := TitleOverlay.Grid.stage(_in, 0.42 + i * beat, 0.34)
		var a := UIKit.out_quint(p) * (1.0 - UIKit.out_cubic(_out))
		if a <= 0.004:
			continue
		var y: float = m["rows_y"] + i * step + slide
		var dx := (1.0 - UIKit.out_cubic(p)) * g.px(U * 0.55)

		var lw := UIKit.spaced(self, _latin, Vector2(lx + dx, y), str(row[0]),
			lab_size, Color(0.66, 0.63, 0.60, a), m["lab_track"])

		var tint: Color = row[2]
		var value := str(row[1])
		var mark: int = row[3]
		# Measured with the face it is drawn in, or an emboldened value drifts
		# off the right margin the other three are lined up on.
		var vf := UIKit.latin(0.2 if mark == 1 else 0.0)
		var vw := UIKit.spaced_width(vf, value, val_size, m["val_track"])
		var vx := rx - vw

		# State gem, when the row is a state rather than a quantity.
		if mark >= 0:
			var r := g.px(U * 0.26)
			vx -= r * 2.0 + g.px(U * 0.5)
			TitleOverlay.gem(self, Vector2(rx - vw - r - g.px(U * 0.5),
				y - val_size * 0.32), r, mark == 1,
				Color(tint.r, tint.g, tint.b, a))

		# Leader dots. A ledger without a leader makes the eye jump the gap and
		# land on the wrong row; this is the oldest fix in typesetting.
		var dot_from := lx + dx + lw + g.px(U * 0.6)
		var dot_to := vx - g.px(U * 0.6)
		var dx_step := g.px(U * 0.33)
		var dot := dot_from
		while dot < dot_to:
			draw_circle(Vector2(dot, y - val_size * 0.28), maxf(0.8, g.px(1.1)),
				Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, 0.16 * a))
			dot += dx_step

		UIKit.spaced(self, vf, Vector2(rx - vw, y), value, val_size,
			Color(tint.r, tint.g, tint.b, a), m["val_track"])


## Rank four: the prompt. It holds a dim baseline before the card is armed, so
## the bottom of the card is never empty and the brightening reads as "now".
func _prompt(g: TitleOverlay.Grid, m: Dictionary, card: Rect2, fade: float,
		slide: float) -> void:
	var a := 0.16
	if _armed:
		a = 0.45 + 0.32 * sin(_t * 2.4)
	UIKit.hints(self, Vector2(card.position.x + card.size.x * 0.5,
		m["prompt_y"] + slide),
		[["JUMP", "CONTINUE" if kind == Kind.CLEARED else "TRY AGAIN"]],
		g.px(U * 0.95), true, a * fade)


# --- Layout -----------------------------------------------------------------

## Every measurement the card needs, solved once per frame from the grid and
## the fonts' own metrics. The card's height falls out of its content; a fixed
## fraction of the viewport is how a card ends up with dead space at the bottom
## at one resolution and clipped type at another.
func _metrics(g: TitleOverlay.Grid) -> Dictionary:
	var w := g.px(minf(27.0 * U, g.w - TitleOverlay.Grid.MARGIN * 2.0))
	var pad := g.px(2.0 * U)

	var head_ar := int(UIKit.type_size(self, UIKit.TITLE) * UIKit.ARABIC_RATIO)
	var head_en := UIKit.type_size(self, UIKit.HEAD)
	var place_ar := int(UIKit.type_size(self, UIKit.HEAD) * UIKit.ARABIC_RATIO)
	var place_en := UIKit.type_size(self, UIKit.LABEL)
	var lab := UIKit.type_size(self, UIKit.LABEL)
	var val := UIKit.type_size(self, UIKit.BODY)

	var y := g.px(U * 1.9)
	var head_ar_y := y + _kufi.get_ascent(head_ar)
	var head_en_y := head_ar_y + _kufi.get_descent(head_ar) + g.px(U * 0.55)
	var rule_y := head_en_y + g.px(U * 0.85)
	var head_h := rule_y - g.px(U * 1.0) + g.px(U * 0.3)
	var place_ar_y := rule_y + g.px(U * 0.95) + _naskh.get_ascent(place_ar)
	var place_en_y := place_ar_y + _naskh.get_descent(place_ar) + g.px(U * 0.5)
	var rows_y := place_en_y + g.px(U * 1.9)
	var row_step := g.px(U * 1.55)
	var prompt_y := rows_y + row_step * 3.0 + g.px(U * 1.9)
	var h := prompt_y + g.px(U * 2.1)

	# Sat a little above centre: a card pinned to the exact middle reads as
	# low, because the eye puts the optical centre above the geometric one.
	var top := (g.px(g.h) - h) * 0.44
	var card := Rect2(Vector2((g.px(g.w) - w) * 0.5, top), Vector2(w, h))

	return {
		"card": card, "pad": pad, "head_h": head_h,
		"head_ar": head_ar, "head_en": head_en,
		"head_track": UIKit.type_track(self, UIKit.HEAD),
		"place_ar": place_ar, "place_en": place_en,
		"place_track": UIKit.type_track(self, UIKit.LABEL),
		"lab": lab, "lab_track": UIKit.type_track(self, UIKit.LABEL),
		"val": val, "val_track": UIKit.type_track(self, UIKit.BODY) * 0.6,
		"head_ar_y": top + head_ar_y, "head_en_y": top + head_en_y,
		"rule_y": top + rule_y,
		"place_ar_y": top + place_ar_y, "place_en_y": top + place_en_y,
		"rows_y": top + rows_y, "row_step": row_step,
		"prompt_y": top + prompt_y,
	}
