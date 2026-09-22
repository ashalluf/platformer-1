class_name SettingsPanel extends Control
## Settings, drawn.
##
## Left and right adjust the highlighted row. Every value writes straight
## through to Gx, which persists it and tells the directors, so there is no
## apply step and nothing to forget to save.
##
## The panel is a card on a grid: title block, a ruled body of rows, a footer of
## hints inside the card's own margin. Values are meters rather than bars — a
## bar with no scale is a loading screen, and this is a control surface.

signal closed()

const VOLUME_STEP := 0.1
const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH", "ULTRA"]
## Row id -> Gx setting key, for the rows that hold a 0..1 value.
const SETTING_KEYS := {
	"master": "master_volume", "music": "music_volume",
	"sfx": "sfx_volume", "shake": "screen_shake",
}

## Design-space card metrics. The card is a fixed measure, not a fraction of
## the frame: a settings list that stretches to 21:9 is a spreadsheet.
const CARD_W := 620.0
const PAD := 40.0
const ROW_H := 56.0
const HEADER := 120.0
const FOOTER := 64.0

var _menu: MenuList
var _font: Font
var _t := 0.0
var _open := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_font = ThemeDB.fallback_font

	_menu = MenuList.new()
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu.row_height = ROW_H
	add_child(_menu)
	# Sub-labels say what a setting actually touches. A settings screen that
	# makes you guess is a settings screen people change once and never revisit.
	_menu.add_row("master", "MASTER", "", true, "").icon = "sound"
	_menu.row_by_id("master").sub = "EVERYTHING"
	_menu.add_row("music", "MUSIC", "", true, "").icon = "sound"
	_menu.row_by_id("music").sub = "SCORE & AMBIENCE"
	_menu.add_row("sfx", "SOUND EFFECTS", "", true, "").icon = "sound"
	_menu.row_by_id("sfx").sub = "IMPACTS & PICKUPS"
	_menu.add_row("shake", "SCREEN SHAKE", "", true, "").icon = "shake"
	_menu.row_by_id("shake").sub = "CAMERA IMPULSE"
	_menu.add_row("quality", "GRAPHICS", "", true, "").icon = "screen"
	_menu.row_by_id("quality").sub = "SHADOWS & FOG"
	_menu.add_row("fullscreen", "FULLSCREEN", "", true, "").icon = "screen"
	_menu.add_row("back", "BACK", "رجوع").icon = "back"
	_menu.chosen.connect(_on_chosen)
	_layout()
	_refresh()


## Card geometry in design units, so the panel and the list agree without
## either of them knowing the resolution.
func _card() -> Rect2:
	var d := UIKit.design_rect(self).size
	var h := HEADER + _menu.rows.size() * ROW_H + FOOTER
	return Rect2(Vector2(round((d.x - CARD_W) * 0.5), round((d.y - h) * 0.5)),
		Vector2(CARD_W, h))


## Design-space rise of the whole card during the open animation. The list is
## a sibling node, so it has to be given the same number or the card slides out
## from under its own rows.
func _lift() -> float:
	return (1.0 - UIKit.out_quint(_open)) * 22.0


func _layout() -> void:
	var card := _card()
	_menu.origin = card.position + Vector2(PAD, HEADER) - Vector2(0.0, _lift())
	_menu.width = CARD_W - PAD * 2.0
	_menu.value_column = 104.0


func _process(delta: float) -> void:
	_t += delta
	_open = minf(_open + delta * 3.0, 1.0)
	_layout()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left", true):
		_adjust(-1)
	elif event.is_action_pressed("move_right", true):
		_adjust(1)
	elif event.is_action_pressed("pause"):
		_close()


func _adjust(dir: int) -> void:
	var row := _menu.current()
	if row == null:
		return
	match row.id:
		"master": _bump("master_volume", dir)
		"music": _bump("music_volume", dir)
		"sfx": _bump("sfx_volume", dir)
		"shake": _bump("screen_shake", dir)
		"quality":
			var q := int(Gx.get_setting("quality", 2))
			Gx.set_setting("quality", clampi(q + dir, 0, 3))
		"fullscreen":
			Gx.set_setting("fullscreen", not bool(Gx.get_setting("fullscreen", false)))
		_:
			return
	# Pitch tracks the direction so the ear knows which way the value went
	# before the eye has read the number.
	Audio.play_2d("ui", -8.0, 1.0 + dir * 0.06, "UI")
	_refresh()


func _bump(key: String, dir: int) -> void:
	var v: float = Gx.get_setting(key, 1.0)
	Gx.set_setting(key, snappedf(clampf(v + dir * VOLUME_STEP, 0.0, 1.0), 0.05))


func _refresh() -> void:
	for row: MenuList.Row in _menu.rows:
		match row.id:
			"master", "music", "sfx", "shake":
				row.value = _pct(SETTING_KEYS[row.id])
				row.bar = float(Gx.get_setting(SETTING_KEYS[row.id], 1.0))
			"quality":
				row.value = QUALITY_NAMES[clampi(int(Gx.get_setting("quality", 2)), 0, 3)]
				# Quality is a four-notch switch, so it gets a four-notch scale.
				row.bar = clampi(int(Gx.get_setting("quality", 2)), 0, 3) / 3.0
			"fullscreen":
				row.value = "ON" if Gx.get_setting("fullscreen", false) else "OFF"


func _pct(key: String) -> String:
	return "%d%%" % int(round(float(Gx.get_setting(key, 1.0)) * 100.0))


func _on_chosen(_i: int, id: String) -> void:
	if id == "back":
		_close()
	elif id == "fullscreen":
		_adjust(1)


func _close() -> void:
	Audio.play_2d("ui", -4.0, 0.85, "UI")
	closed.emit()
	queue_free()


func _draw() -> void:
	var view := get_viewport_rect().size
	var s := UIKit.ui_scale(self)
	var e := UIKit.out_quint(_open)
	var card := _card()
	# The card arrives from slightly below and settles; the dim comes with it.
	var lift := _lift() * s
	var box := Rect2(card.position * s - Vector2(0.0, lift), card.size * s)

	# Dim under the card, vignette and grain over everything at the end — see
	# the note in PauseMenu; the interface and the render share one grain.
	draw_rect(Rect2(Vector2.ZERO, view),
		Color(UIKit.SHADOW.r, UIKit.SHADOW.g, UIKit.SHADOW.b, 0.62 * e))

	var pts := UIKit.slab(self, box, Color(0.062, 0.057, 0.068, 0.93 * e),
		26.0 * s, 13.0 * s)
	UIKit.slab_outline(self, pts,
		Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, 0.55 * e),
		1.8 * s)

	var lx := box.position.x + PAD * s
	var rx := box.position.x + box.size.x - PAD * s

	UIKit.title_block(self, Vector2(lx, box.position.y + 44.0 * s),
		"الإعدادات", "SETTINGS",
		Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, e),
		rx - lx)

	# A quiet column header over the value column, so the numbers read as a
	# column rather than as loose text at the end of each row.
	var vh_size := UIKit.type_size(self, UIKit.MICRO)
	var vh_track := UIKit.type_track(self, UIKit.MICRO)
	var vh_w := UIKit.spaced_width(_font, "VALUE", vh_size, vh_track)
	# Lands on the same right edge the row values land on, not on the card's.
	UIKit.spaced(self, _font,
		Vector2(rx - vh_w - MenuList.ROW_PAD * s, box.position.y + (HEADER - 8.0) * s),
		"VALUE", vh_size, Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, 0.55 * e),
		vh_track)

	# Footer hints live inside the card's margin, on the card's own baseline.
	var fy := box.position.y + box.size.y - FOOTER * s + 14.0 * s
	UIKit.rule(self, Vector2(lx, fy - 12.0 * s), Vector2(rx, fy - 12.0 * s),
		Color(UIKit.SAUCE.r, UIKit.SAUCE.g, UIKit.SAUCE.b, 0.35 * e), 1.4 * s)
	UIKit.hints(self, Vector2(box.position.x + box.size.x * 0.5, fy),
		[["A D", "ADJUST"], ["SPACE", "TOGGLE"], ["ESC", "BACK"]],
		22.0 * s, true, e)

	UIKit.overlay(self, Rect2(Vector2.ZERO, view), 0.0, 0.6 * e, 0.045 * e, _t)
