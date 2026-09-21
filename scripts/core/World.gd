class_name World
## The canon level manifest.
##
## One table, read by the map screen, the collection screen and the level flow,
## so the order of World 1 is stated exactly once. Levels that are not built
## yet carry an empty `scene` — the map draws them locked rather than pretending
## they exist, which is honest and also stops a menu from crashing into nothing.

## A level's place in the world. `chain_id` is the key Gx stores progression
## under; it matches the `level_id` each Stage assigns itself.
class Entry extends RefCounted:
	var chain_id := ""
	var name_en := ""
	var name_ar := ""
	var subtitle := ""        ## the one line that says what this level is
	var scene := ""           ## "" means not built yet
	var kind := "run"         ## run | vehicle | boss
	var map := Vector2.ZERO   ## position on the world map, 0..1 of the map field

	func _init(id: String, en: String, ar: String, sub: String,
			path: String, k: String, at: Vector2) -> void:
		chain_id = id
		name_en = en
		name_ar = ar
		subtitle = sub
		scene = path
		kind = k
		map = at

	func built() -> bool:
		return scene != ""


## World 1 — Eastern Libya, west to east, the way the coast road actually runs.
static func world_one() -> Array:
	return [
		Entry.new("brega", "BREGA PRISON BREAKOUT", "هروب من سجن البريقة",
			"Out of the cell block, through the petrochemical yard.",
			"res://levels/brega/Brega.tscn", "run", Vector2(0.10, 0.62)),
		Entry.new("ajdabiya", "AJDABIYA CROSSROADS", "مفترق أجدابيا",
			"Where every road east meets. Market stalls and rooftops.",
			"", "run", Vector2(0.31, 0.50)),
		Entry.new("highway", "HIGHWAY TO BENGHAZI", "الطريق إلى بنغازي",
			"Two hundred kilometres of coast road, at speed.",
			"", "vehicle", Vector2(0.54, 0.42)),
		Entry.new("garyounis", "GARYOUNIS UNIVERSITY", "جامعة قاريونس",
			"Colonnades, courtyards, and nobody where they should be.",
			"", "run", Vector2(0.75, 0.33)),
		Entry.new("benghazi", "BENGHAZI", "بنغازي",
			"Home. And whatever is waiting in it.",
			"", "boss", Vector2(0.91, 0.22)),
	]


## Every chain the collection screen has a slot for, in canon order.
static func chain_slots() -> Array:
	return world_one()


static func entry(chain_id: String) -> Entry:
	for e: Entry in world_one():
		if e.chain_id == chain_id:
			return e
	return null


## Index of the furthest level the player may enter: everything cleared, plus
## the next one. Levels that are not built yet stop the line.
static func unlocked_count() -> int:
	var list := world_one()
	var n := 1
	for i in list.size():
		var e: Entry = list[i]
		if Gx.levels_cleared.has(e.chain_id):
			n = mini(i + 2, list.size())
	return n
