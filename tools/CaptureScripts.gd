class_name CaptureScripts
## Scripted input timelines for the capture harness.
##
## Each entry is [time_in_seconds, command]. Commands:
##   right | left | stop      set the movement axis
##   jump  | jumprelease      press / release jump (variable height lives here)
##   dash                     tap dash
##   fire | firestop          hold / release the trigger (full auto)
##   hold_jump                keep jump held (max height)
## Timelines are the project's automated playtest: if the controller regresses,
## the run through the movement lab stops reaching the same platforms.

const TIMELINES := {
	"idle": [],

	"walk": [
		[0.4, "right"],
		[3.0, "stop"],
		[3.6, "left"],
		[5.4, "stop"],
	],

	# Standstill jump, short hop, then a full running jump — the three cases
	# that expose variable jump height and air control.
	"jumps": [
		[0.5, "jump"], [0.62, "jumprelease"],
		[1.6, "jump"], [2.2, "jumprelease"],
		[2.8, "right"],
		[3.4, "jump"], [4.0, "jumprelease"],
		[5.0, "stop"],
	],

	# Full traverse of the movement lab: run-up, steps, gaps, ramps, dash gap.
	"demo": [
		[0.6, "right"],
		[2.05, "jump"], [2.45, "jumprelease"],
		[2.95, "jump"], [3.35, "jumprelease"],
		[3.75, "jump"], [4.15, "jumprelease"],
		[4.9, "jump"], [5.35, "jumprelease"],
		[5.9, "jump"], [6.35, "jumprelease"],
		[7.0, "jump"], [7.5, "jumprelease"],
		[8.4, "jump"], [8.9, "jumprelease"],
		[10.2, "jump"], [10.7, "jumprelease"],
		[12.0, "jump"], [12.3, "dash"], [12.55, "jumprelease"],
		[13.4, "jump"], [13.9, "jumprelease"],
		[15.0, "stop"],
	],

	# Ground jump held through the apex, so the thobe catches on the way down,
	# then a double jump into a second glide.
	"glide": [
		[0.5, "right"],
		[1.3, "jump"],
		[3.6, "jumprelease"],
		[3.9, "jump"],
		[6.4, "jumprelease"],
		[7.4, "stop"],
	],

	# Rifle: slung, raised, run-and-gun, then a burst mid-air where recoil
	# actually does something to the arc.
	"rifle": [
		[0.8, "fire"],
		[2.0, "firestop"],
		[2.4, "right"],
		[3.2, "fire"],
		[4.4, "firestop"],
		[5.0, "jump"], [5.35, "jumprelease"],
		[5.5, "fire"],
		[6.6, "firestop"],
		[7.2, "stop"],
	],

	"dash": [
		[0.5, "right"],
		[1.4, "dash"],
		[2.4, "jump"], [2.6, "dash"], [2.9, "jumprelease"],
		[4.0, "stop"],
		[4.6, "left"], [5.0, "dash"],
		[6.0, "stop"],
	],

	# Deliberately runs off the end of the world to exercise death + respawn.
	"fall": [
		[0.4, "right"],
		[6.0, "stop"],
	],
}


static func get_timeline(name_: String) -> Array:
	return TIMELINES.get(name_, TIMELINES["idle"])


static func names() -> Array:
	return TIMELINES.keys()
