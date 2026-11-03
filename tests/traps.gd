extends SceneTree
## Headless test for the hidden traps (see Traps): where they lie, how
## Intuition and Erkunden help to spot them, what a spotted trap gives and
## keeps, and what spike traps, teleporters and trapdoors do to the hero.
## Run with: godot --headless --fixed-fps 60 -s tests/traps.gd

var failures := 0
var game: Node
var frames := 0
var done := false
const HERO := "Trap test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	# Spotting is a roll, and even a sharp eye has only Traps.SPOT_MAX (95 %):
	# a fixed seed keeps the test from failing about one run in twenty.
	# TEST_SEED tries another one.
	seed(int(OS.get_environment("TEST_SEED")) if OS.has_environment("TEST_SEED") else 1)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
	if not done:
		return frames > 20000
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: traps")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _index_of(file: String) -> int:
	for i in game.level_files.size():
		if game.level_files[i].get_file() == file:
			return i
	return -1


## Enters a level afresh, with nothing known about its traps.
func _enter(file: String) -> Traps:
	var i := _index_of(file)
	game.looted.erase(file)
	game.load_level(i, false)
	game.state = game.State.PLAYING
	return game.level.traps


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _first(t: Traps, kind: String) -> Dictionary:
	for trap in t.traps:
		if trap.kind == kind:
			return trap
	return {}


## Sets the hero down on a tile, standing still.
func _put(c: Vector2i) -> void:
	var p: Player = game.player
	p.path.clear()
	p.velocity = Vector3.ZERO
	p.global_position = game.level.cell_to_world(c)


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO
	game.lore.clear()
	p.xp.clear()
	p.equipped.clear()
	p.hero_xp = 0
	p.refresh_stats()

	# Where traps lie: the listed dungeons and mines, never the start, the
	# spike hall, the refuge or the open air.
	for file in Traps.PLACES:
		var t := _enter(file)
		check(t != null, "%s has traps" % file)
		if t == null:
			continue
		check(t.traps.size() == Traps.PLACES[file].count, "%s has %d traps: %d" % [file, Traps.PLACES[file].count, t.traps.size()])
		for trap in t.traps:
			check(t._fits(trap.cell), "%s: a trap on open floor with open floor around it %s" % [file, trap.cell])
			check(not trap.known and not trap.mark.visible, "%s: a trap is hidden at first" % file)
			check(trap.kind in Traps.PLACES[file].kinds, "%s: only its own kinds of trap" % file)
		var drops := t.traps.filter(func(x): return x.kind == "falltuer").size()
		check(drops <= 1, "%s: one trapdoor at most" % file)
		if "falltuer" in Traps.PLACES[file].kinds and Traps.can_drop(game.level):
			check(drops == 1, "%s has a trapdoor" % file)
	for file in ["01_die_zelle.txt", "02_die_stachelhalle.txt", "05_die_zuflucht.txt", "11_die_freiheit.txt", "18_die_bergschenke.txt", "23_das_herz_des_berges.txt"]:
		game.load_level(_index_of(file), false)
		check(game.level.traps == null, "%s has no traps" % file)
	var a: Array = _enter("06_die_katakomben.txt").traps.map(func(x): return x.cell)
	var b: Array = _enter("06_die_katakomben.txt").traps.map(func(x): return x.cell)
	check(a == b, "a level has its traps in the same places on every visit")
	# The sealed mine has no trapdoor until its way down is open.
	_enter("21_die_zwergenbinge.txt")
	check(not Traps.can_drop(game.level), "no trapdoor while the dwarves' seal is shut")
	game.looted["21_die_zwergenbinge.txt"] = {"mines:seal_open": true}
	game.load_level(_index_of("21_die_zwergenbinge.txt"), false)
	check(_first(game.level.traps, "falltuer").size() > 0, "an open seal lets a trapdoor drop to the floor below")

	# Spotting: harder in deeper places, easier with Intuition and Erkunden.
	var shallow := _enter("03_das_labyrinth.txt")
	var base_shallow := shallow.spot_chance()
	check(base_shallow == Traps.SPOT_BASE - Traps.SPOT_PER_LEVEL * shallow.place_level, "the chance to spot a trap: %d" % base_shallow)
	var deep := _enter("22_die_glutstollen.txt")
	check(deep.spot_chance() < base_shallow, "traps deep in the mines are harder to spot: %d < %d" % [deep.spot_chance(), base_shallow])
	check(deep.spike_damage() > shallow.spike_damage(), "and hurt more: %d > %d" % [deep.spike_damage(), shallow.spike_damage()])
	var plain := deep.spot_chance()
	p.xp["erkunden"] = 400.0
	var explore_level := p.skill("erkunden")
	check(explore_level > 0, "Erkunden is trained: %d" % explore_level)
	check(deep.spot_chance() == mini(Traps.SPOT_MAX, plain + explore_level * Training.EXPLORE_TRAP), "Erkunden helps to spot traps: %d" % deep.spot_chance())
	var with_skill := deep.spot_chance()
	p.xp["intuition"] = 600.0
	check(p.intuition_bonus() > 0 and deep.spot_chance() > with_skill, "Intuition helps to spot traps: %d" % deep.spot_chance())
	p.xp.clear()

	# A spotted trap shows, trains Erkunden, earns experience and is kept.
	var t := _enter("07_die_bibliothek.txt")
	var trap: Dictionary = t.traps[0]
	var cell: Vector2i = trap.cell
	var xp_before: int = p.hero_xp
	t.spot_trap(trap)
	check(trap.known and trap.mark.visible, "a spotted trap shows")
	check(p.xp.get("erkunden", 0.0) >= Training.EXPLORE_TRAP_FOUND, "spotting a trap trains Erkunden")
	check(p.hero_xp > xp_before, "spotting a trap earns experience: %d -> %d" % [xp_before, p.hero_xp])
	check(game.lore.has(Traps.LEARN), "the compendium explains traps")
	check(game.level.astar.get_point_weight_scale(cell) > 1.0, "paths go around a known trap")
	game.load_level(_index_of("07_die_bibliothek.txt"), false)
	var again: Dictionary = game.level.traps.trap_at(cell)
	check(again.known and again.mark.visible, "a spotted trap stays known on the next visit")

	# The hero comes close: one roll, and a sure eye spots it.
	t = _enter("08_die_knochengrube.txt")
	trap = t.traps[0]
	p.xp["intuition"] = 100000.0
	p.xp["erkunden"] = 100000.0
	var near: Vector2i = t.traps[0].cell + Vector2i(1, 0)
	_put(near)
	await _wait(3)
	check(trap.rolled, "coming close rolls to spot the trap")
	check(trap.known, "a sharp eye spots it: %d %%" % t.spot_chance())
	p.xp.clear()
	p.refresh_stats()

	# A spike trap hurts (Geschick at its start: no dodging).
	t = _enter("07_die_bibliothek.txt")
	trap = _first(t, "stacheln")
	check(not trap.is_empty(), "the library has a spike trap")
	if not trap.is_empty():
		p.hp = p.max_hp
		p._invulnerable = 0.0
		_put(trap.cell)
		await _wait(3)
		check(p.hp < p.max_hp, "the spikes hurt: %d / %d" % [p.hp, p.max_hp])
		check(trap.known and trap.mark.visible, "a sprung trap shows")
		check(game.lore.has(Traps.LEARN), "stepping on a trap explains traps")
		# A jump over a trap is safe.
		await _wait(120)
		p.hp = p.max_hp
		p._invulnerable = 0.0
		p.global_position = t.level.cell_to_world(trap.cell) + Vector3(0, 1.5, 0)
		t._process(0.0)
		check(p.hp == p.max_hp, "a jump over the spikes is safe")

	# A teleporter flings the hero across the level.
	var tele_file := ""
	for file in Traps.PLACES:
		if "teleport" in Traps.PLACES[file].kinds:
			t = _enter(file)
			if not _first(t, "teleport").is_empty():
				tele_file = file
				break
	check(tele_file != "", "some level has a teleporter")
	if tele_file != "":
		trap = _first(t, "teleport")
		_put(trap.cell)
		await _wait(3)
		var landed: Vector2i = game.level.world_to_cell(p.global_position)
		check(Traps._apart(landed, trap.cell) >= Traps.TELEPORT_MIN_TILES, "the teleporter flings the hero away: %s -> %s" % [trap.cell, landed])
		check(not game.level.astar.is_point_solid(landed), "onto open floor")

	# A trapdoor drops the hero to the floor below (the one before it), near its start.
	t = _enter("03_das_labyrinth.txt")
	trap = _first(t, "falltuer")
	check(not trap.is_empty(), "the labyrinth has a trapdoor")
	if not trap.is_empty():
		var from: int = game.level_index
		p.hp = p.max_hp
		_put(trap.cell)
		await _wait(60)
		check(game.level_index == from - 1, "the trapdoor drops the hero down a level: %d -> %d" % [from + 1, game.level_index + 1])
		check(game.state == game.State.PLAYING, "and the game goes on")
		var here: Vector2i = game.level.world_to_cell(p.global_position)
		check(here != game.level.start_cell and not game.level.astar.is_point_solid(here), "the hero lands on open floor: %s" % here)
		check(p.hp < p.max_hp, "the fall hurts")
	done = true
