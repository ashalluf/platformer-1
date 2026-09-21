class_name PauseMenu extends Control
## Pause.
##
## The world keeps rendering behind it, dimmed and desaturated by an overlay
## rather than by a shader swap: seeing where you were is most of why a pause
## screen feels good to open.

signal resumed()
signal quit_to_title()

var _menu: MenuList
var _font: Font
var _settings: SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

	_menu = MenuList.new()
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu)
	_menu.add_row("resume", "RESUME", "متابعة")
	_menu.add_row("settings", "SETTINGS", "الإعدادات")
	_menu.add_row("title", "QUIT TO TITLE", "الخروج")
	_menu.chosen.connect(_on_chosen)
	_layout()


func _layout() -> void:
	var view := get_viewport_rect().size
	_menu.origin = Vector2(view.x * 0.5 - 190.0, view.y * 0.46)
	_menu.width = 380.0


func _process(_delta: float) -> void:
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
				_menu.accept_input = true)
		"title":
			quit_to_title.emit()


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.04, 0.04, 0.05, 0.62))
	# Two rules framing the word, rather than a box around it.
	var y := view.y * 0.34
	UIKit.spaced(self, _font, Vector2(view.x * 0.5, y), "PAUSED", 30,
		UIKit.CREAM, 8.0, true)
	UIKit.rule(self, Vector2(view.x * 0.5 - 150.0, y + 16.0),
		Vector2(view.x * 0.5 + 150.0, y + 16.0), Color(1.0, 0.44, 0.16, 0.6), 2.0)

	UIKit.spaced(self, _font, Vector2(view.x * 0.5, view.y * 0.40), "SRIRACHA", 13,
		UIKit.DIM, 3.0, true)
	UIKit.spaced(self, _font, Vector2(view.x * 0.5, view.y * 0.425),
		str(Gx.sriracha), 20, UIKit.SAUCE_HOT, 2.0, true)
	UIKit.pips(self, Vector2(view.x * 0.5 - 48.0, view.y * 0.72), Gx.chain_count(), 5, 8.0, 24.0)
