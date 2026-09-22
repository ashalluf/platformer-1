class_name PauseMenu extends Control
## Pause.
##
## The world keeps rendering behind it, dimmed and vignetted by an overlay
## rather than by a shader swap: seeing where you were is most of why a pause
## screen feels good to open.
##
## Laid out on a two-column grid in UIKit's design space — title block and menu
## in the left column, the state of the run in the right, contextual hints along
## the footer. Nothing is centred for want of a better idea.

signal resumed()
signal quit_to_title()

## Design-space grid. The margin is generous on purpose: a pause screen that
## crowds the frame edge looks like a debug overlay.
const MARGIN := 78.0
const COLUMN := 360.0

var _menu: MenuList
var _font: Font
var _settings: SettingsPanel
var _t := 0.0
var _open := 0.0
var _entry: World.Entry = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_font = ThemeDB.fallback_font
	_entry = World.entry(Gx.current_level_id)

	_menu = MenuList.new()
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu)
	_menu.add_row("resume", "RESUME", "متابعة").icon = "play"
	_menu.add_row("settings", "SETTINGS", "الإعدادات").icon = "gear"
	_menu.add_row("title", "QUIT TO TITLE", "الخروج").icon = "back"
	_menu.chosen.connect(_on_chosen)
	_layout()


## Design-space rise during the open animation, shared by the type block, the
## run card and the list — the list is a sibling node and would otherwise stay
## put while everything around it moved.
func _lift() -> float:
	return (1.0 - UIKit.out_quint(_open)) * 26.0


## The menu lives in design units, so the layout is the same arithmetic at
## every resolution and the only resolution-aware call in the file is ui_scale.
func _layout() -> void:
	_menu.origin = Vector2(MARGIN, 288.0 - _lift())
	_menu.width = COLUMN
	_menu.row_height = 58.0


func _process(delta: float) -> void:
	_t += delta
	_open = minf(_open + delta * 2.6, 1.0)
	_layout()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _settings != null:
		return
	if event.is_action_pressed("pause"):
		_on_chosen(0, "resume")


func _on_chosen(_i: int, id: String) -> void:
	match id:
		"resume":
			resumed.emit()
			queue_free()
		"settings":
			_menu.accept_input = false
			_settings = SettingsPanel.new()
			_settings.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_settings)
			_settings.closed.connect(func() -> void:
				_settings = null
				_menu.accept_input = true
				_menu.open())
		"title":
			quit_to_title.emit()


func _draw() -> void:
	var view := get_viewport_rect().size
	var s := UIKit.ui_scale(self)
	var d := view / s                      ## the frame in design units
	var e := UIKit.out_quint(_open)
	var full := Rect2(Vector2.ZERO, view)

	# Atmosphere is two passes around the content: the dim and the wedge of
	# shade go UNDER the type, the vignette and grain go OVER it at the end of
	# this function. Grain on top of everything is what stops the interface
	# looking like a layer pasted onto the render.
	draw_rect(full, Color(UIKit.SHADOW.r, UIKit.SHADOW.g, UIKit.SHADOW.b, 0.58 * e))
	UIKit.scrim(self, Rect2(Vector2.ZERO, Vector2(view.x * 0.52, view.y)),
		Color(UIKit.SHADOW.r, UIKit.SHADOW.g, UIKit.SHADOW.b, 0.5 * e),
		Color(UIKit.SHADOW.r, UIKit.SHADOW.g, UIKit.SHADOW.b, 0.0))

	# Everything in the block rises a little as it fades in.
	var lift := _lift() * s
	var m := MARGIN * s

	# Title block: Arabic first, Latin under it. Same block the other screens
	# use, which is most of why they look like one product.
	UIKit.title_block(self, Vector2(m, 176.0 * s - lift), "إيقاف مؤقت", "PAUSED",
		Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, e),
		COLUMN * 0.92 * s)

	# Where you are. Contextual, quiet, and the reason the block is not centred.
	if _entry != null:
		# The Latin hangs off the measured width of the Arabic rather than off a
		# guessed offset — Arabic advance widths vary far more than Latin caps do.
		var aw := UIKit.arabic(self, Vector2(m, 252.0 * s - lift), _entry.short_ar,
			UIKit.type_size(self, UIKit.LABEL),
			Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, 0.75 * e))
		UIKit.spaced(self, _font, Vector2(m + aw + 16.0 * s, 252.0 * s - lift),
			_entry.name_en, UIKit.type_size(self, UIKit.MICRO),
			Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, 0.9 * e),
			UIKit.type_track(self, UIKit.MICRO))

	_run_card(d, s, e, lift)

	# Footer hints, on the same left margin as everything else.
	UIKit.hints(self, Vector2(m, view.y - 62.0 * s),
		[["W S", "MOVE"], ["SPACE", "SELECT"], ["ESC", "RESUME"]],
		24.0 * s, false, e)

	UIKit.overlay(self, full, 0.0, 0.55 * e, 0.042 * e, _t)


## The state of the run, in the right column: the two numbers that matter, the
## gauge, and the chains. A pause screen that shows nothing about the run is a
## wasted screen.
func _run_card(d: Vector2, s: float, e: float, lift: float) -> void:
	var w := 296.0
	var x := d.x - MARGIN - w
	var card := Rect2(Vector2(x, 176.0) * s - Vector2(0.0, lift),
		Vector2(w, 252.0) * s)
	var pts := UIKit.slab(self, card, Color(0.055, 0.05, 0.062, 0.86 * e),
		20.0 * s, 11.0 * s)
	UIKit.slab_outline(self, pts,
		Color(UIKit.SAUCE.r, UIKit.SAUCE.g, UIKit.SAUCE.b, 0.45 * e), 1.6 * s)

	var lx := card.position.x + 30.0 * s
	var rx := card.position.x + card.size.x - 26.0 * s
	var y := card.position.y + 44.0 * s

	UIKit.arabic(self, Vector2(lx, y), "الجولة", UIKit.type_size(self, UIKit.LABEL),
		Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, 0.8 * e))
	var hsize := UIKit.type_size(self, UIKit.MICRO)
	var htrack := UIKit.type_track(self, UIKit.MICRO)
	var hw := UIKit.spaced_width(_font, "THIS RUN", hsize, htrack)
	UIKit.spaced(self, _font, Vector2(rx - hw, y), "THIS RUN", hsize,
		Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, e), htrack)
	UIKit.rule(self, Vector2(lx, y + 14.0 * s), Vector2(rx, y + 14.0 * s),
		Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, 0.4 * e),
		1.6 * s)

	_stat(Vector2(lx, y + 62.0 * s), rx, "SRIRACHA", str(Gx.sriracha),
		UIKit.SAUCE_HOT, e, s)
	_stat(Vector2(lx, y + 104.0 * s), rx, "LIVES", str(Gx.lives), UIKit.CREAM, e, s)

	# HEAT reads as the instrument it is in the HUD, so the two agree.
	UIKit.spaced(self, _font, Vector2(lx, y + 142.0 * s), "HEAT",
		UIKit.type_size(self, UIKit.MICRO),
		Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, e),
		UIKit.type_track(self, UIKit.MICRO))
	UIKit.meter(self, Rect2(Vector2(lx, y + 150.0 * s), Vector2(rx - lx, 13.0 * s)),
		Gx.heat_ratio(), Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g,
			UIKit.SAUCE_HOT.b, e), Gx.heat_ratio() >= 0.999, 6)

	UIKit.spaced(self, _font, Vector2(lx, y + 196.0 * s), "CHAINS",
		UIKit.type_size(self, UIKit.MICRO),
		Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, e),
		UIKit.type_track(self, UIKit.MICRO))
	UIKit.pips(self, Vector2(rx - 4.0 * s - 4.0 * 26.0 * s, y + 191.0 * s),
		Gx.chain_count(), 5, 8.0 * s, 26.0 * s)


## Label left, value right, on one baseline — the pattern every stat row in the
## game uses.
func _stat(at: Vector2, right: float, label: String, value: String,
		tint: Color, e: float, s: float) -> void:
	UIKit.spaced(self, _font, at, label, UIKit.type_size(self, UIKit.MICRO),
		Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, e),
		UIKit.type_track(self, UIKit.MICRO))
	var f := UIKit.latin(0.35)
	var size := UIKit.type_size(self, UIKit.HEAD)
	var track: float = UIKit.type_track(self, UIKit.HEAD) * 0.4
	var w := UIKit.spaced_width(f, value, size, track)
	UIKit.spaced(self, f, Vector2(right - w, at.y + 8.0 * s), value, size,
		Color(tint.r, tint.g, tint.b, e), track)
