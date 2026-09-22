extends Node
## InputDirector — owns the InputMap.
##
## Actions are built in code rather than baked into project.godot so that
## rebinding, controller support and persistence all run through one place.

signal bindings_changed()

const BINDINGS_PATH := "user://bindings.cfg"

## action -> { keys: [Key], buttons: [JoyButton], axes: [[JoyAxis, sign]] }
const DEFAULTS := {
	"move_left":  {"keys": [KEY_A, KEY_LEFT],  "buttons": [JOY_BUTTON_DPAD_LEFT],  "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"move_up":    {"keys": [KEY_W, KEY_UP],    "buttons": [JOY_BUTTON_DPAD_UP],    "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	"move_down":  {"keys": [KEY_S, KEY_DOWN],  "buttons": [JOY_BUTTON_DPAD_DOWN],  "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	"jump":       {"keys": [KEY_SPACE, KEY_Z], "buttons": [JOY_BUTTON_A],          "axes": []},
	"dash":       {"keys": [KEY_SHIFT, KEY_X], "buttons": [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER], "axes": []},
	"attack":     {"keys": [KEY_J, KEY_C],     "buttons": [JOY_BUTTON_B],          "axes": []},
	"confirm":    {"keys": [KEY_ENTER, KEY_KP_ENTER], "buttons": [JOY_BUTTON_A],  "axes": []},
	"pause":      {"keys": [KEY_ESCAPE, KEY_P],"buttons": [JOY_BUTTON_START],      "axes": []},
	"restart":    {"keys": [KEY_R],            "buttons": [JOY_BUTTON_BACK],       "axes": []},
	"photo":      {"keys": [KEY_F2],           "buttons": [],                      "axes": []},
}

const DEADZONE := 0.22

var _overrides: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_overrides()
	rebuild()


func rebuild() -> void:
	for action: String in DEFAULTS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, DEADZONE)
		var spec: Dictionary = _overrides.get(action, DEFAULTS[action])

		for key: int in spec.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

		for button: int in spec.get("buttons", []):
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)

		for axis_spec: Array in spec.get("axes", []):
			var ev := InputEventJoypadMotion.new()
			ev.axis = axis_spec[0]
			ev.axis_value = axis_spec[1]
			InputMap.action_add_event(action, ev)

	bindings_changed.emit()


func rebind(action: String, spec: Dictionary) -> void:
	_overrides[action] = spec
	rebuild()
	_save_overrides()


func reset_bindings() -> void:
	_overrides.clear()
	rebuild()
	_save_overrides()


## Horizontal stick/key input as a signed float, with a clean analog ramp.
func move_axis() -> float:
	return Input.get_axis("move_left", "move_right")


func _save_overrides() -> void:
	var cfg := ConfigFile.new()
	for action: String in _overrides:
		cfg.set_value("bindings", action, _overrides[action])
	cfg.save(BINDINGS_PATH)


func _load_overrides() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(BINDINGS_PATH) != OK:
		return
	for action: String in cfg.get_section_keys("bindings"):
		_overrides[action] = cfg.get_value("bindings", action)
