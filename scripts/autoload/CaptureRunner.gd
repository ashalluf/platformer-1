extends Node
## CaptureRunner — turns `--capture` into a headless screenshot run.
##
## Lives as an autoload so the capture session runs inside the real game loop,
## with real autoloads and real physics. See tools/capture.gd.

const CAPTURE_SESSION := preload("res://tools/capture.gd")

static var active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	active = true
	var session: Node = CAPTURE_SESSION.new()
	session.name = "CaptureSession"
	get_tree().root.call_deferred("add_child", session)
