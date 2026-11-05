extends SceneTree
## Headless test for the flame jets in the walls (see FlameJets): where they
## sit, their beat of rest, warning and fire, and what the fire does to the hero.
## Run with: godot --headless --fixed-fps 60 -s tests/flame_jets.gd

var failures := 0
var game: Node
var frames := 0
var done := false
const HERO := "Flame test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(1)
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
		print("PASS: flame_jets")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _index_of(file: String) -> int:
	for i in game.level_files.size():
		if game.level_files[i].get_file() == file:
			return i
	return -1


func _enter(file: String) -> FlameJets:
	game.looted.erase(file)
	game.load_level(_index_of(file), false)
	game.state = game.State.PLAYING
	return game.level.flame_jets


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## Sets the hero down on a tile, standing still and unhurt.
func _put(c: Vector2i, height := 0.0) -> void:
	var p: Player = game.player
	p.path.clear()
	p.velocity = Vector3.ZERO
	p.global_position = game.level.cell_to_world(c) + Vector3(0, height, 0)
	p.hp = p.max_hp
	p._invulnerable = 0.0
	p._down = 0.0
	p.cure()


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO
	game.lore.clear()
	p.xp.clear()
	p.equipped.clear()
	p.hero_xp = 0
	p.refresh_stats()

	# Where the jets sit: in a plain wall, firing straight across open floor
	# to the wall opposite.
	for file in FlameJets.PLACES:
		var f := _enter(file)
		check(f != null, "%s has flame jets" % file)
		if f == null:
			continue
		check(f.jets.size() == FlameJets.PLACES[file], "%s has %d flame jets: %d" % [file, FlameJets.PLACES[file], f.jets.size()])
		var lv: Level = game.level
		for j in f.jets:
			check(lv.cell_char(j.wall) == "#", "%s: a nozzle sits in a wall %s" % [file, j.wall])
			check(j.dir != Vector2i(0, -1) and not lv._is_low_wall(j.wall), "%s: never in a low wall %s" % [file, j.wall])
			var n: int = j.cells.size()
			check(n >= FlameJets.MIN_TILES and n <= FlameJets.MAX_TILES, "%s: a lane of %d tiles" % [file, n])
			check(j.cells.all(func(c): return not lv.astar.is_point_solid(c)), "%s: the lane is open floor" % file)
			check(lv.cell_char(j.cells[n - 1] + j.dir) == "#", "%s: the fire ends at the wall opposite" % file)
			check(not lv.start_cell in j.cells, "%s: never over the start" % file)
			if lv.traps:
				check(j.cells.all(func(c): return lv.traps.trap_at(c).is_empty()), "%s: no hidden trap in a lane" % file)
		var others: Array = f.jets.map(func(j): return j.clock)
		check(others.size() < 2 or others[0] != others[1], "%s: each jet keeps its own beat" % file)
	for file in ["01_die_zelle.txt", "02_die_stachelhalle.txt", "05_die_zuflucht.txt", "11_die_freiheit.txt", "22_die_glutstollen.txt"]:
		game.load_level(_index_of(file), false)
		check(game.level.flame_jets == null, "%s has no flame jets" % file)
	var a: Array = _enter("09_die_klingenhalle.txt").jets.map(func(j): return [j.wall, j.dir])
	var b: Array = _enter("09_die_klingenhalle.txt").jets.map(func(j): return [j.wall, j.dir])
	check(a == b, "a level has its flame jets in the same places on every visit")

	# The beat: rest, warning, fire, and round again.
	var f := _enter("13_die_drachenhoehle.txt")
	f.set_process(false)
	var j: Dictionary = f.jets[0]
	j.clock = 0.0
	check(FlameJets.phase_of(j) == "rest", "a jet rests first")
	j.clock = FlameJets.REST + 0.1
	check(FlameJets.phase_of(j) == "warn", "then warns")
	j.clock = FlameJets.REST + FlameJets.WARN + 0.1
	check(FlameJets.phase_of(j) == "blast", "then fires")
	f._process(FlameJets.BLAST)
	check(FlameJets.phase_of(j) == "rest", "and rests again")
	check(not j.flames.emitting, "no flames at rest")

	# Every other jet out of the way: only jet `j` matters from here.
	for other in f.jets:
		if other != j:
			other.clock = 0.0
	var middle: Vector2i = j.cells[j.cells.size() / 2]

	# Resting and warning, the lane is safe.
	game.lore.clear()
	_put(middle)
	j.clock = 0.0
	f._process(0.0)
	check(p.hp == p.max_hp, "a resting jet does not hurt")
	check(game.lore.has(FlameJets.LEARN), "seeing a jet explains flame jets")
	j.clock = FlameJets.REST + 0.5
	f._process(0.0)
	check(p.hp == p.max_hp, "nor does a warning one")
	check(j.glow.emission_energy_multiplier > 0.0 and j.lane.emission_energy_multiplier > 0.0, "the warning glows")

	# Its fire hurts and sets the hero burning, once a blast.
	j.clock = FlameJets.REST + FlameJets.WARN - 0.01
	f._process(0.02 + FlameJets.REACH_TIME)
	check(j.flames.emitting, "the jet spits fire")
	check(p.hp < p.max_hp, "the fire hurts: %d / %d" % [p.hp, p.max_hp])
	check(p.hp >= p.max_hp - f.damage(), "as much as the place's spikes: %d" % (p.max_hp - p.hp))
	check(p.ailments.has("brand"), "and sets the hero burning")
	var after := p.hp
	p._invulnerable = 0.0
	f._process(0.1)
	check(p.hp == after, "once a blast")

	# Jumping does not help; stepping out of the lane does.
	_put(middle, 1.5)
	j.clock = FlameJets.REST + FlameJets.WARN + 0.5
	j.hit = false
	f._process(0.0)
	check(p.hp < p.max_hp, "jumping does not clear the fire")
	var beside: Vector2i = middle + Vector2i(j.dir.y, j.dir.x)
	_put(beside)
	j.hit = false
	f._process(0.0)
	check(p.hp == p.max_hp, "a tile beside the lane is safe")
	check(f.jet_at(middle) == j, "the lane is the jet's")

	# The fire runs out to the far wall at the start of a blast.
	var far: Vector2i = j.cells[j.cells.size() - 1]
	_put(far)
	j.clock = FlameJets.REST + FlameJets.WARN + 0.001
	j.hit = false
	check(not f.burns(j, p.global_position), "the fire has not reached the far end yet")
	j.clock = FlameJets.REST + FlameJets.WARN + FlameJets.REACH_TIME + 0.01
	check(f.burns(j, p.global_position), "a moment later it has")
	_put(far + j.dir * 2)
	check(not f.burns(j, p.global_position), "but not past the wall opposite")

	Lang.language = "en"
	Lang._apply()
	check(Lang.t(FlameJets.NAME) == "Flame trap", "the name in English")
	check(Lang.t(FlameJets.LEARN).begins_with("Flame traps:"), "the compendium in English")
	Lang.language = "de"
	Lang._apply()
	p.cure()
	done = true
