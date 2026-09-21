class_name SettingsPanel extends Control
## Settings, drawn.
##
## Left and right adjust the highlighted row. Every value writes straight
## through to Gx, which persists it and tells the directors, so there is no
## apply step and nothing to forget to save.

signal closed()

const VOLUME_STEP := 0.1
const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH", "ULTRA"]
## Row id -> Gx setting key, for the rows that hold a 0..1 value.
const SETTING_KEYS := {
	"master": "master_volume", "music": "music_volume",
	"sfx": "sfx_volume", "shake": "screen_shake",
}

var _menu: MenuList
var _font: Font
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

	_menu = MenuList.new()
	_menu.origin = Vector2(0.0, 0.0)   ## positioned in _draw-time layout below
	_menu.width = 520.0
	add_child(_menu)
	_menu.add_row("master", "MASTER VOLUME", "", true, "")
	_menu.add_row("music", "MUSIC", "", true, "")
	_menu.add_row("sfx", "SOUND EFFECTS", "", true, "")
	_menu.add_row("shake", "SCREEN SHAKE", "", true, "")
	_menu.add_row("quality", "GRAPHICS", "", true, "")
	_menu.add_row("fullscreen", "FULLSCREEN", "", true, "")
	_menu.add_row("back", "BACK", "رجوع")
	_menu.chosen.connect(_on_chosen)
	_layout()
	_refresh()


func _layout() -> void:
	var view := get_viewport_rect().size
	_menu.origin = Vector2(view.x * 0.5 - 260.0, view.y * 0.32)


func _process(delta: float) -> void:
	_t += delta
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
			"quality": row.value = QUALITY_NAMES[clampi(int(Gx.get_setting("quality", 2)), 0, 3)]
			"fullscreen": row.value = "ON" if Gx.get_setting("fullscreen", false) else "OFF"


func _pct(key: String) -> String:
	return "%d%%" % int(round(float(Gx.get_setting(key, 1.0)) * 100.0))


func _on_chosen(_i: int, id: String) -> void:
	if id == "back":
		_close()


func _close() -> void:
	Audio.play_2d("ui", -4.0, 0.85, "UI")
	closed.emit()
	queue_free()


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.03, 0.03, 0.04, 0.72))

	var panel := Rect2(Vector2(view.x * 0.5 - 300.0, view.y * 0.18),
		Vector2(600.0, view.y * 0.64))
	var pts := UIKit.slab(self, panel, Color(0.07, 0.065, 0.075, 0.88), 22.0, 12.0)
	UIKit.slab_outline(self, pts, Color(1.0, 0.44, 0.16, 0.55), 2.0)

	UIKit.spaced(self, _font, Vector2(view.x * 0.5, view.y * 0.18 + 52.0),
		"SETTINGS", 26, UIKit.CREAM, 6.0, true)
	UIKit.rule(self, Vector2(panel.position.x + 40.0, view.y * 0.18 + 72.0),
		Vector2(panel.position.x + panel.size.x - 40.0, view.y * 0.18 + 72.0),
		Color(1.0, 0.44, 0.16, 0.45), 2.0)

	# A bar under each volume row, so the number is not the only read.
	for i in _menu.rows.size():
		var row: MenuList.Row = _menu.rows[i]
		if not SETTING_KEYS.has(row.id):
			continue
		var key: String = SETTING_KEYS[row.id]
		var v: float = Gx.get_setting(key, 1.0)
		var y := _menu.origin.y + i * _menu.row_height + _menu.row_height - 14.0
		var x0 := _menu.origin.x + 34.0
		var w := _menu.width - 200.0
		draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(1, 1, 1, 0.16), 3.0)
		draw_line(Vector2(x0, y), Vector2(x0 + w * v, y),
			UIKit.SAUCE_HOT if i == _menu.selected else UIKit.SAUCE, 3.0)

	UIKit.spaced(self, _font, Vector2(view.x * 0.5, panel.position.y + panel.size.y - 26.0),
		"LEFT / RIGHT TO ADJUST", 13, UIKit.DIM, 3.4, true)
