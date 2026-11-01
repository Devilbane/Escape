extends SceneTree
## Headless test for the hero's map and journal: the dungeon map fills in from
## the fog of war, the open air around the hero, landmarks go on the map and
## into the journal once seen, finds are counted per spot, the days are
## counted, the map window shows both pages, and all of it survives a save.
## Run with: godot --headless -s tests/journal.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Journal test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path(HERO))
	if failures == 0:
		print("PASS: journal")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


## Lets the journal look around as if some time had passed.
func _look() -> void:
	if game.level.fog != null:
		game.level.fog._recompute(game.player.global_position)
	game.journal._timer = 0.0
	game.journal.update(0.0)


func _place(file: String, kind: String) -> Dictionary:
	for p in game.journal.places_on(file):
		if p.kind == kind:
			return p
	return {}


func _test() -> void:
	var j: Journal = game.journal
	game.hero_name = HERO
	j.clear()
	check(j.mapped_files().is_empty(), "a new hero has no map")

	# Every name on the map has an English text.
	for table in [Journal.DUNGEON_MARKS, Journal.OUTDOOR_MARKS]:
		for ch in table:
			check(Lang.EN.has(table[ch][1]), "%s has an English name" % table[ch][1])
	for area in Journal.OUTDOOR_AREAS:
		check(Lang.EN.has(area[1]), "%s has an English name" % area[1])
	for text in ["Betreten: %s", "Entdeckt: %s", "Gefunden: %s", "Geheimraum entdeckt", "Tag %d, %s", game.MAP_LEARN]:
		check(Lang.EN.has(text), "the journal text has English: " + text)

	# The cell: the map fills in from what the hero sees.
	game.load_level(0)
	var cell: String = game.level_files[0].get_file()
	check(j.current_file() == cell, "the journal knows the level the hero is on")
	_look()
	check(j.has_map(cell), "the first level has a map once the hero looks around")
	check(j.is_explored(cell, game.level.start_cell), "the start is on the map")
	check(not j.is_explored(cell, Vector2i(6, 1)), "the stairs behind the door are not on the map yet")
	check(j.entries.size() >= 1 and j.entries[0].t == "Betreten: %s", "the journal notes arriving on the level")
	var shrine := _place(cell, "shrine")
	check(not shrine.is_empty(), "the cell has a shrine landmark")
	check(j.is_seen(cell, shrine), "the shrine in view is on the map")
	var stairs := _place(cell, "stairs")
	check(not stairs.is_empty() and not j.is_seen(cell, stairs), "the stairs out of sight are not")
	game.player.global_position = game.level.cell_to_world(Vector2i(6, 3))
	_look()
	check(j.is_seen(cell, stairs), "walking into the room puts the stairs on the map")
	check(j.entries.any(func(e): return e.t == "Entdeckt: %s" and e.a == ["Treppe"]), "the journal notes the stairs")
	check(game.lore.has(game.MAP_LEARN), "the compendium explains the map")

	# A secret room is marked on the map.
	j.note_secret(cell, Vector2i(13, 7))
	j.note_secret(cell, Vector2i(13, 7))
	check(j.secrets[cell].size() == 1, "a secret room is marked once")

	# Finds: the same thing close by counts on one spot.
	check(game.note_find("ingredient", "testkraut", "Testkraut", game.level.cell_to_world(Vector2i(3, 7))), "a first find is a new spot")
	check(not game.note_find("ingredient", "testkraut", "Testkraut", game.level.cell_to_world(Vector2i(3, 7)) + Vector3(1, 0, 0)), "a find on the same spot is not")
	check(game.note_find("ingredient", "testkraut", "Testkraut", game.level.cell_to_world(Vector2i(10, 8))), "a find further off is a new spot")
	check(j.spots_of("testkraut").size() == 2, "both spots are listed")
	check(int(j.spots_of("testkraut")[0].count) == 2, "the first spot counts two finds")

	# The open air: what lies around the hero goes on the map.
	game.load_level(game._outdoor_index())
	var outside: String = game.level_files[game._outdoor_index()].get_file()
	_look()
	check(j.has_map(outside), "the open air has a map")
	check(j.is_explored(outside, game.level.start_cell), "the crypt door is on the map")
	check(j.is_seen(outside, _place(outside, "crypt")), "the crypt is a landmark seen at once")
	var bank := {}
	for p in j.places_on(outside):
		if p.name == "Bank der Krone":
			bank = p
	check(not bank.is_empty() and not j.is_seen(outside, bank), "the bank far away is not on the map yet")
	game.player.global_position = game.level.cell_to_world(Vector2i(bank.x, bank.y + 2))
	_look()
	check(j.is_seen(outside, bank), "walking up to the bank puts it on the map")
	check(j.mapped_files() == [cell, outside], "two maps, in the order of the game")

	# The days turn over at midnight.
	var day := j.day
	game.day_hour = 23.5
	j.update(0.0)
	game.day_hour = 0.5
	j.update(0.0)
	check(j.day == day + 1, "a new day begins after midnight")

	# The window: both pages, and maps of both levels.
	game.state = game.State.PLAYING
	game.menus.map_page = "karte"
	game.menus.open("karte")
	check(game.menus.current == "karte", "the map window opens")
	check(game.menus._map_file == outside, "it shows the level the hero is on")
	var view: MapView = game.menus._box.find_child("MapView", true, false)
	check(view != null and view.hero_at != Vector2.INF, "the map shows where the hero stands")
	check(view != null and view.numbered_places().size() >= 2, "the map numbers the landmarks seen")
	game.menus.map_page = "tagebuch"
	game.menus._rebuild()
	check(game.menus._box.find_child("MapView", true, false) == null, "the journal page has no map")
	game.menus.close()

	# Saved and loaded again, everything is still there.
	var explored_before := (j.explored[cell] as PackedByteArray).duplicate()
	var log_before := j.entries.size()
	check(game.save_game(), "the game saves")
	j.clear()
	game._apply_save(game._read_save(game.save_path(HERO)))
	check(j.explored.has(cell) and j.explored[cell] == explored_before, "the map of the cell is kept")
	check(j.is_seen(outside, bank), "the bank stays on the map")
	check(j.entries.size() == log_before, "the journal is kept")
	check(j.spots_of("testkraut").size() == 2, "the finds are kept")
	check(j.secrets.get(cell, []).size() == 1, "the secret room is kept")
	check(j.day == day + 1, "the day of the journey is kept")
	var text := j.entry_text(j.entries[0])
	check(text[0].contains(","), "a journal line tells the day and hour")
