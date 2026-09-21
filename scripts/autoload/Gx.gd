extends Node
## Gx — global game state, progression and settings.
##
## Single source of truth for run-state (sriracha, lives, heat), persistent
## progression (chains, level completion) and player settings. Everything that
## survives a scene change lives here; nothing here knows about scene structure.

signal sriracha_changed(count: int, delta: int)
signal heat_changed(heat: float)
signal heat_full()
signal lives_changed(lives: int)
signal chain_awarded(level_id: String, total: int)
signal ice_sriracha_changed(count: int, needed: int)
signal iced_out_found_signal(level_id: String)
signal setting_changed(key: String)

const SAVE_PATH := "user://libyan_gangstas.save"
const SETTINGS_PATH := "user://settings.cfg"

## Sriracha needed to fill the HEAT gauge (see DESIGN.md — Heat Dash).
const HEAT_PER_BOTTLE := 1.0
const HEAT_CAPACITY := 30.0
## Sriracha collected for a free life, DKC-banana style.
const SRIRACHA_PER_LIFE := 100

# --- Run state (resets on new run) ---
var sriracha: int = 0
var lives: int = 3
var heat: float = 0.0
var run_sriracha_since_life: int = 0
## Ice bonus level progress. 100 of these awards a chain.
var ice_sriracha: int = 0
const ICE_SRIRACHA_TARGET := 100
var current_level_id := ""

# --- Persistent progression ---
var chains: Dictionary = {}          ## level_id -> true once the chain is earned
var levels_cleared: Dictionary = {}  ## level_id -> best stats
var iced_out_found: Dictionary = {}  ## level_id -> true

# --- Settings ---
var settings := {
	"master_volume": 1.0,
	"music_volume": 0.85,
	"sfx_volume": 1.0,
	"screen_shake": 1.0,
	"fullscreen": false,
	"quality": 2,          ## 0 low, 1 medium, 2 high, 3 ultra
	"language": "en",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	load_game()


# --- Collectibles -----------------------------------------------------------

func add_sriracha(amount: int = 1) -> void:
	sriracha += amount
	run_sriracha_since_life += amount
	sriracha_changed.emit(sriracha, amount)

	var was_full := heat >= HEAT_CAPACITY
	heat = minf(heat + HEAT_PER_BOTTLE * amount, HEAT_CAPACITY)
	heat_changed.emit(heat)
	if not was_full and heat >= HEAT_CAPACITY:
		heat_full.emit()

	while run_sriracha_since_life >= SRIRACHA_PER_LIFE:
		run_sriracha_since_life -= SRIRACHA_PER_LIFE
		add_life(1)


func add_ice_sriracha(amount: int = 1) -> void:
	ice_sriracha = mini(ice_sriracha + amount, ICE_SRIRACHA_TARGET)
	ice_sriracha_changed.emit(ice_sriracha, ICE_SRIRACHA_TARGET)
	if ice_sriracha >= ICE_SRIRACHA_TARGET and current_level_id != "":
		award_chain(current_level_id)


func reset_ice_run() -> void:
	ice_sriracha = 0
	ice_sriracha_changed.emit(ice_sriracha, ICE_SRIRACHA_TARGET)


func find_iced_out() -> void:
	if current_level_id == "":
		return
	iced_out_found[current_level_id] = true
	iced_out_found_signal.emit(current_level_id)
	save_game()


func spend_heat(amount: float) -> bool:
	if heat < amount:
		return false
	heat -= amount
	heat_changed.emit(heat)
	return true


func heat_ratio() -> float:
	return heat / HEAT_CAPACITY


func add_life(amount: int = 1) -> void:
	lives += amount
	lives_changed.emit(lives)


func lose_life() -> int:
	lives -= 1
	lives_changed.emit(lives)
	return lives


func award_chain(level_id: String) -> void:
	if chains.has(level_id):
		return
	chains[level_id] = true
	chain_awarded.emit(level_id, chains.size())
	save_game()


func chain_count() -> int:
	return chains.size()


func reset_run() -> void:
	sriracha = 0
	heat = 0.0
	run_sriracha_since_life = 0
	lives = 3
	sriracha_changed.emit(sriracha, 0)
	heat_changed.emit(heat)
	lives_changed.emit(lives)


# --- Settings ---------------------------------------------------------------

func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	if settings.get(key) == value:
		return
	settings[key] = value
	setting_changed.emit(key)
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key: String in cfg.get_section_keys("settings"):
		if settings.has(key):
			settings[key] = cfg.get_value("settings", key)


# --- Save data --------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": 1,
		"chains": chains,
		"levels_cleared": levels_cleared,
		"iced_out_found": iced_out_found,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Gx: could not open save file for writing")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	chains = data.get("chains", {})
	levels_cleared = data.get("levels_cleared", {})
	iced_out_found = data.get("iced_out_found", {})
