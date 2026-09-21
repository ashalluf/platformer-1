extends Node3D
## Boot — decides what the game opens into.
##
## Keeps the entry point in one place: capture runs take over entirely, an
## explicit --level= jumps straight to a scene, everything else falls through
## to the default entry scene.

@export var default_scene := "res://levels/greybox/Greybox.tscn"


func _ready() -> void:
	if CaptureRunner.active:
		return   # the capture session owns the tree
	var requested := _cmdline_level()
	var target := requested if requested != "" else default_scene
	call_deferred("_go", target)


func _cmdline_level() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			return arg.substr(8)
	return ""


func _go(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Boot: scene not found: " + path)
		return
	get_tree().change_scene_to_file(path)
