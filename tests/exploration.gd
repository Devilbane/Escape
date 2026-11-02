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
	for w in Level.WRITINGS:
		check(Lang.EN.has(w[1]), "the writing has English: " + w[1])

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
	game.level.secret_sure = false
	var base: int = game.level.secret_chance()
	p.xp["erkunden"] = _xp_for(3)
	check(p.skill("erkunden") == 3, "Erkunden reached level 3: %d" % p.skill("erkunden"))
	check(game.level.secret_chance() == base + 3 * Training.EXPLORE_SECRET, "Erkunden 3 adds to the lever chance: %d -> %d" % [base, game.level.secret_chance()])

	# A writing on a wall of each dungeon level, hidden until noticed.
	var writing: Dictionary = game.level.writing()
	check(not writing.is_empty(), "the cell has a writing on a wall")
	check(not writing.label.visible, "the writing is hidden at first")
	check(game.level.writing_chance() == Level.WRITING_CHANCE + 3 * Training.EXPLORE_WRITING, "Erkunden adds to the writing chance")
	var before: float = p.xp.get("erkunden", 0.0)
	game.level.reveal_writing()
	check(writing.label.visible and writing.found, "a noticed writing shows on the wall")
	check(game.lore.has(writing.text), "the writing goes into the compendium")
	check(p.xp.get("erkunden", 0.0) > before, "a new writing trains Erkunden")
	check(j.entries.any(func(e): return e.t == "Inschrift entdeckt"), "the journal notes the writing")
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
	var found := _torches_found(10)
	check(found > 0, "with Erkunden 10 searching turns up torches: %d of 100" % found)


## Searches 100 empty boxes with the skill at a level; how many torches
## turned up.
func _torches_found(level: int) -> int:
	var p: Player = game.player
	p.xp["erkunden"] = _xp_for(level)
	var torches := 0
	for i in 100:
		p.bag.clear()
		var obj := {"label": "Kiste", "pos": p.global_position, "icon_pos": p.global_position, "cell": Vector2i.ZERO,
			"touch_cell": Vector2i.ZERO, "searched": false, "loot": {}, "lid": null, "id": "test:%d" % i}
		game._search(obj)
		torches += p.bag.count(HandTorch.ITEM)
	p.bag.clear()
	return torches
