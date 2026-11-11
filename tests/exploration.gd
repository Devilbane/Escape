extends SceneTree
## Headless test for the Erkunden (exploring) skill: it needs no gear, a
## fully explored map trains it once (and goes into the journal and the
## save), and each level helps to notice secret levers, to find torches when
## searching, and to notice the writing on a wall of each dungeon level.
## Run with: godot --headless -s tests/exploration.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Exploration test"


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
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: exploration")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


## Training that reaches exactly this level of a skill.
func _xp_for(level: int) -> float:
	var total := 0.0
	var cost := Training.SKILL_FIRST
	for i in level:
		total += cost
		cost *= Training.SKILL_GROWTH
	return total


func _test() -> void:
	var p: Player = game.player
	var j: Journal = game.journal
	game.hero_name = HERO
	j.clear()
	game.lore.clear()
	p.xp.clear()
	p.equipped.clear()
	p.refresh_stats()

	# The skill: on the wheel, no gear needed, with English texts.
	check(Training.SKILLS.has("erkunden"), "Erkunden is a skill")
	check(Training.tier("erkunden") == 1, "Erkunden is a basic skill")
	check(p.skill_enabled("erkunden"), "Erkunden needs no gear")
	for text in ["Erkunden", game.EXPLORE_LEARN, CharacterPage.SKILL_EFFECTS.erkunden, "Vollständig erkundet", "Inschrift entdeckt",
			"(vollständig)", "Eine Inschrift!", "Dein geübtes Auge findet eine Fackel, die hier versteckt lag.",
			"Ganz erkundet: %s\nDein Blick für Verborgenes wird schärfer (Erkunden)."]:
		check(Lang.EN.has(text), "has English: " + text)
	# Writings found before they were written in blood (or before a text changed) map to today's texts.
	var texts_now: Array = Level.WRITINGS.map(func(w): return w[1])
	check(Level.OLD_WRITINGS.size() >= Level.WRITINGS.size() and Level.OLD_WRITINGS.values().all(func(t): return t in texts_now), "every old writing text maps to its new one")
	# Every carved word fits on its wall piece, in both languages.
	var font: Font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	for w in Level.WRITINGS:
		for word in [w[0], Lang.EN.get(w[0], w[0])]:
			var size := Level.writing_font_size(font, word, 0.01)
			var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.01
			check(width <= Level.WRITING_MAX_WIDTH, "%s fits on the wall: %.2f m at %d" % [word, width, size])
	for w in Level.WRITINGS:
		check(Lang.EN.has(w[1]), "the writing has English: " + w[1])
		check(Lang.EN.has(w[0]), "the carved word has English: " + w[0])

	# The tiles that count for a full map: ground in the part around the start.
	game.load_level(0)
	var file: String = game.level_files[0].get_file()
	var cells: Array = j.map_of(file).cells
	check(cells.has(game.level.start_cell), "the start counts for a full map")
	for c in cells:
		check(game.level.cell_char(c) != "#" and game.level.cell_char(c) != "?", "no wall counts for a full map: %s" % c)
	check(j.explored_share(file) < Journal.FULL_SHARE, "a new level is not fully explored")

	# Seeing the whole map trains Erkunden once.
	j.note_full_map(file)
	check(not j.is_full(file), "a level only partly seen is not full")
	var bytes: PackedByteArray = j._cells_of(file)
	for i in bytes.size():
		bytes[i] = 1
	check(is_equal_approx(j.explored_share(file), 1.0), "everything seen is 100 %%: %f" % j.explored_share(file))
	j.note_full_map(file)
	check(j.is_full(file), "a level seen whole is fully explored")
	var after: float = p.xp.get("erkunden", 0.0)
	check(after >= Training.EXPLORE_FULL_MAP, "a full map trains Erkunden: %f" % after)
	check(game.lore.has(game.EXPLORE_LEARN), "the compendium explains Erkunden")
	check(j.entries.any(func(e): return e.t == "Vollständig erkundet"), "the journal notes the full map")
	j.note_full_map(file)
	check(is_equal_approx(p.xp.get("erkunden", 0.0), after), "a full map trains only once")
	var saved := j.for_save()
	j.clear()
	j.load_from(JSON.parse_string(JSON.stringify(saved)))
	check(j.is_full(file), "a full map is kept in the save")

	# Each level helps to notice a secret lever.
	p.xp["erkunden"] = 0.0
	p.sleep_state.skills.erase("erkunden")
	game.level.secret_sure = false
	var base: int = game.level.secret_chance()
	p.xp["erkunden"] = _xp_for(3)
	p.sleep_state.skills.erase("erkunden")
	check(p.skill("erkunden") == 3, "Erkunden reached level 3: %d" % p.skill("erkunden"))
	check(game.level.secret_chance() == base + 3 * Training.EXPLORE_SECRET, "Erkunden 3 adds to the lever chance: %d -> %d" % [base, game.level.secret_chance()])

	# A writing on a wall of each dungeon level, hidden until noticed.
	var writing: Dictionary = game.level.writing()
	check(not writing.is_empty(), "the cell has a writing on a wall")
	check(not writing.label.visible, "the writing is hidden at first")
	# Written in blood: trickles under the letters, and stains on the floor
	# in front that form an arrow pointing at it, there from the start.
	check(writing.drips.size() >= 3, "blood runs down from the letters: %d trickles" % writing.drips.size())
	check(writing.drips.all(func(d): return d.get_parent() == writing.label), "the trickles show with the writing")
	var arrow: Node3D = game.level.get_node_or_null("BloodArrow")
	check(arrow != null and arrow.visible and arrow.get_child_count() > 8, "bloodstains on the floor point at the writing")
	if arrow:
		var front: Vector3 = game.level.cell_to_world(writing.cell)
		check(arrow.get_children().all(func(st): return absf(st.position.x - front.x) < Level.TILE / 2 and absf(st.position.z - front.z) < Level.TILE / 2),
				"the stains stay on the tile in front of the wall")
	check(game.level.writing_chance() == Level.WRITING_CHANCE + 3 * Training.EXPLORE_WRITING, "Erkunden adds to the writing chance")
	var before: float = p.xp.get("erkunden", 0.0)
	game.level.reveal_writing()
	check(writing.label.visible and writing.found, "a noticed writing shows on the wall")
	check(game.lore.has(writing.text), "the writing goes into the compendium")
	check(p.xp.get("erkunden", 0.0) > before, "a new writing trains Erkunden")
	check(j.entries.any(func(e): return e.t == "Inschrift entdeckt"), "the journal notes the writing")
	# A noticed writing stands out: a card with its word and clue, and
	# running into the wall reads it again.
	check(game.level.stations.has(writing.station) and writing.station.kind == "tafel", "a noticed writing can be read again")
	check(game.writing_card.showing(), "a noticed writing pops up on a card")
	check(game.writing_card._word.text == Lang.t(writing.word), "the card shows the carved word: %s" % game.writing_card._word.text)
	check(game.writing_card._text.text == Lang.t(writing.text), "the card shows what the writing says")
	game.writing_card.hide_now()
	game._use_station(writing.station)
	check(game.writing_card.showing(), "running into the wall shows the card again")
	# It stays known on the next visit.
	var here: int = game.level_index
	game.load_level(here, false)
	var again: Dictionary = game.level.writing()
	check(again.found and again.label.visible, "a noticed writing stays known on the next visit")
	check(game.level.stations.has(again.station), "and can still be read there")
	check(not game.writing_card.showing(), "a new visit does not pop the card up again")
	# Walking right up to a writing always notices it, even after a failed roll.
	var other := 1 if here != 1 else 2
	game.looted.erase(game.level_files[other].get_file())
	game.load_level(other, false)
	var near: Dictionary = game.level.writing()
	check(not near.found, "the next level's writing is hidden")
	near.rolled = true
	p.global_position = game.level.cell_to_world(near.cell)
	game.level._check_writing()
	check(near.found and near.label.visible, "walking right up to a writing notices it for sure")
	var texts := {}
	for i in 10:
		texts[Level.WRITINGS[i % Level.WRITINGS.size()][1]] = true
	check(texts.size() == 10, "the ten dungeon levels each have their own writing")
	for i in 10:
		game.load_level(i)
		check(not game.level.writing().is_empty(), "level %d has a writing" % (i + 1))
	game.load_level(game._outdoor_index(), false)
	check(game.level.writing().is_empty(), "the open air has no wall writing")

	# Searching: a torch now and then, more often the better the eye.
	game.load_level(0)
	check(_torches_found(0) == 0, "without Erkunden no extra torch turns up")
	p.xp["erkunden"] = _xp_for(10)
	p.sleep_state.skills.erase("erkunden")
	var found := _torches_found(10)
	check(found > 0, "with Erkunden 10 searching turns up torches: %d of 100" % found)

	# A lever torch works only up close, never from across the room.
	_test_lever_reach()


## Puts the hero in view of a lever torch but out of reach: nothing happens.
## Next to it, the lever is rolled (and, made sure, opens the secret wall).
func _test_lever_reach() -> void:
	var lv: Level = null
	var s := {}
	for i in 10:
		game.load_level(i)
		for sec in game.level._secrets:
			if sec.lever != null:
				lv = game.level
				s = sec
				break
		if lv != null:
			break
	check(lv != null, "a dungeon level has a lever torch")
	if lv == null:
		return
	check(Level.LEVER_RANGE == Level.SEARCH_RANGE, "a lever has the same reach as searching")
	lv.secret_sure = true
	var torch: Node3D = s.lever
	var lever_spot := lv.cell_to_world(s.lever_cell)
	var far := Vector2i(-1, -1)
	for y in lv.height:
		for x in lv.width:
			var c := Vector2i(x, y)
			if Level.SOLID.contains(lv.cell_char(c)):
				continue
			var spot := lv.cell_to_world(c)
			var d := Vector2(spot.x - torch.global_position.x, spot.z - torch.global_position.z).length()
			if d > Level.SEARCH_RANGE + 0.5 and d < 7.0 and lv.has_line_of_sight(spot, lever_spot):
				far = c
	check(far != Vector2i(-1, -1), "a spot in view of the lever but out of reach")
	if far != Vector2i(-1, -1):
		lv.player.global_position = lv.cell_to_world(far)
		lv._check_secrets()
		check(not s.rolled and not s.open, "a lever out of reach does nothing")
	lv.player.global_position = lever_spot
	lv._check_secrets()
	check(s.rolled and s.open, "a lever next to the hero opens the secret wall")


## Searches 100 empty boxes with the skill at a level; how many torches
## turned up.
func _torches_found(level: int) -> int:
	var p: Player = game.player
	p.xp["erkunden"] = _xp_for(level)
	p.sleep_state.skills.erase("erkunden")
	var torches := 0
	for i in 100:
		p.bag.clear()
		var obj := {"label": "Kiste", "pos": p.global_position, "icon_pos": p.global_position, "cell": Vector2i.ZERO,
			"touch_cell": Vector2i.ZERO, "searched": false, "loot": {}, "lid": null, "id": "test:%d" % i}
		game._search(obj)
		torches += p.bag.count(HandTorch.ITEM)
	p.bag.clear()
	return torches
