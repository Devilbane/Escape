extends SceneTree
## Headless test for the tentacles under the floor grates (see
## GrateTentacles): where they live, that the hero near a grate gets one roll
## every ROLL_EVERY seconds, that a warning comes before the blow, that
## staying on the grate hurts and stepping off in time does not, that the
## grate rests afterwards and only one tentacle stirs at a time.
## Run with: godot --headless --fixed-fps 60 -s tests/grate_tentacles.gd

var failures := 0
var game: Node
var frames := 0
var done := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
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
		print("PASS: grate tentacles")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await process_frame


func _index_of(file: String) -> int:
	for i in game.level_files.size():
		if game.level_files[i].get_file() == file:
			return i
	return -1


func _put(c: Vector2i) -> void:
	var p: Player = game.player
	p.path.clear()
	p.velocity = Vector3.ZERO
	p.global_position = game.level.cell_to_world(c)


func _tentacles() -> GrateTentacles:
	return game.level.get_node_or_null("GrateTentacles")


## The hero rests at full health and can neither block nor dodge.
func _fresh() -> void:
	var p: Player = game.player
	p.hp = p.max_hp
	p.block_chance = 0.0
	p.set("_invulnerable", 0.0)
	p.set("_down", 0.0)


func _run() -> void:
	var p: Player = game.player
	p.xp.clear()
	p.equipped.clear()
	p.refresh_stats()
	# Where they live: the first cell, safe places, homes and the open air have none.
	var found := ""
	for i in game.level_files.size():
		var file: String = game.level_files[i].get_file()
		game.load_level(i, false)
		var lvl: Level = game.level
		var t := _tentacles()
		var calm: bool = lvl.grates.is_empty() or lvl.safe or lvl.outdoor or lvl.is_home or file in GrateTentacles.CALM_FILES
		check((t == null) == calm, "%s: tentacles only where grates are and it is not calm" % file)
		if t:
			check(t.grates.size() == lvl.grates.size(), "%s: a tentacle under every grate" % file)
			var spikes := 1 + t.place_level / Traps.SPIKE_LEVELS
			check(t.damage() >= 1 and t.damage() <= spikes, "%s: the blow hurts no more than a spike trap (%d)" % [file, t.damage()])
			if found == "" and lvl.grates.size() >= 2:
				found = file
	check(found != "", "some level has tentacles under two grates or more")
	if found == "":
		done = true
		return
	game.load_level(_index_of(found), false)
	game.state = game.State.PLAYING
	var t := _tentacles()
	var cells: Array = t.grates.map(func(g): return g.cell)
	var a: Vector2i = cells[0]
	var b: Vector2i = cells[1]
	# Away from every grate: nothing happens, no rolls.
	_put(game.level.start_cell)
	t.chance = 1.0
	await _wait(0.5)
	var far_from_all: bool = t.grates.all(func(g): return t._flat(p.global_position, g) > GrateTentacles.NEAR)
	if far_from_all:
		check(t.rolls == 0 and not t.busy(), "no roll while the hero is far from the grates")

	# Near a grate with no luck: one roll at once, then one every two seconds.
	t.chance = 0.0
	t.rolls = 0
	_put(a)
	await _wait(0.1)
	check(t.rolls == 1, "the first roll comes as the hero steps near (%d)" % t.rolls)
	await _wait(GrateTentacles.ROLL_EVERY * 2.0 + 0.2)
	check(t.rolls == 3, "then one roll every %.0f seconds (%d)" % [GrateTentacles.ROLL_EVERY, t.rolls])
	check(not t.busy(), "a failed roll stirs nothing")

	# The roll succeeds and the hero stays: warning, then a blow.
	_fresh()
	var hits: Array = []
	t.struck.connect(func(hit): hits.append(hit))
	_put(game.level.start_cell)
	await _wait(0.1)
	t.chance = 1.0
	_put(a)
	await _wait(0.1)
	var g: Dictionary = t.grate_at(a)
	check(g.state == "tell", "a warning comes first (%s)" % g.state)
	check(g.node.visible and g.bubbles.emitting, "the tentacle peeks and bubbles rise")
	check(p.hp == p.max_hp, "the warning does not hurt")
	check(game.lore.has(GrateTentacles.LEARN), "the compendium learns of the tentacles")
	# A second grate stays quiet while this one stirs.
	var other: Dictionary = t.grate_at(b)
	await _wait(GrateTentacles.TELL_TIME + GrateTentacles.RISE_TIME + GrateTentacles.LASH_TIME + 0.2)
	check(hits == [true], "staying on the grate gets the hero hit (%s)" % [hits])
	check(p.hp == p.max_hp - t.damage(), "the blow deals %d (%d of %d left)" % [t.damage(), p.hp, p.max_hp])
	check(other.state == "idle", "only one tentacle stirs at a time")
	await _wait(GrateTentacles.HOLD_TIME + GrateTentacles.SINK_TIME + 0.2)
	check(g.state == "idle" and not g.node.visible, "the tentacle sinks back")
	check(g.rest > 0.0, "the grate rests after a strike")
	var rolled: int = t.rolls
	_put(a)
	_fresh()
	await _wait(2.5)
	check(g.state == "idle" and p.hp == p.max_hp, "a resting grate stays quiet")

	# The hero steps off during the warning: the blow misses.
	hits.clear()
	_fresh()
	g.rest = 0.0
	_put(game.level.start_cell)
	await _wait(0.1)
	_put(a)
	await _wait(0.3)
	check(g.state == "tell", "it stirs again once rested")
	var off: Vector3 = game.level.cell_to_world(a) + Vector3(GrateTentacles.HIT_REACH + 0.5, 0, 0)
	p.path.clear()
	p.global_position = off
	await _wait(GrateTentacles.TELL_TIME + GrateTentacles.RISE_TIME + GrateTentacles.LASH_TIME)
	check(hits == [false], "stepping off in time makes it miss (%s)" % [hits])
	check(p.hp == p.max_hp, "a miss does not hurt")
	done = true
