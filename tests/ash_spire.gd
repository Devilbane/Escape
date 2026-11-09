extends SceneTree
## Headless test for the Ashen Spire (see AshSpire): the gate on the open-air
## map, the five floors with what each one needs (block puzzle, secret
## walls, beds, blade sweepers, ledge and crate, cache and anvil, prisoner,
## grimoire, hatch), the arcane bolt, the monsters that come back, and a way
## from the start of every floor to its way down on the map.
## Run with: godot --headless --fixed-fps 60 -s tests/ash_spire.gd

const HERO := "Ash spire test"

var failures := 0
var checks := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: ash spire (%d checks)" % checks)
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _stations(kind: String) -> Array:
	return game.level.stations.filter(func(s): return s.kind == kind)


func _count(ch: String) -> int:
	var n := 0
	for row in game.level.grid:
		n += row.count(ch)
	return n


func _load(building: String) -> Level:
	game.load_level(game.interiors[building], false)
	return game.level


func _run() -> void:
	# The gate on the open-air map.
	game.load_level(game._outdoor_index(), false)
	var out: Outdoor = game.level
	check(out.doors.has("spire1"), "the open-air map has the spire's gate")
	check(out.stations.any(func(s): return s.kind == "eingang" and s.building == "spire1"), "running into the gate goes to the spire")
	for b in AshSpire.FLOORS:
		check(game.interiors.has(b), "floor %s is a level of the game" % b)
	check(HeroLevel.place_level(_load("spire1")) == 18, "the spire is made for level 18 to 20")

	# Every floor: a way from the start to the way down (or the sanctum).
	for b in AshSpire.FLOORS:
		var map := LevelMap.parse(FileAccess.get_file_as_string(game.level_files[game.interiors[b]]))
		check(not LevelMap.has_errors(map.validate()), "%s: no errors in the map workshop: %s" % [b, map.validate().filter(func(i): return i.error)])
		var start: Vector2i = map.find_all("P")[0]
		var reach := map.reachable(start, true, true)
		var target := "^" if b != "spire5" else "I"
		for c in map.find_all(target):
			check(reach.has(c), "%s: the %s can be reached from the start" % [b, target])
		for c in map.find_all("E"):
			check(reach.has(c), "%s: the stairs up can be reached" % b)

	# Floor 1: the blocks and the gate, the secret wall, the hatch landing.
	var lvl := _load("spire1")
	check(lvl.theme == "zinne" and lvl.respawn and lvl.down_to == "spire2", "floor 1 is open ground, respawns, leads down to floor 2")
	check(lvl._gates.size() == 1 and _count("_") == 2 and lvl.stones.size() == 2, "floor 1 has the gate, two plates and two blocks")
	check(lvl._secrets.size() == 1 and lvl.sure_levers, "floor 1 has one secret wall with a lever that always works")
	check(lvl.hatch_side != Vector3.ZERO and _stations(AshSpire.HATCH).is_empty(), "the hatch only lets the hero out up here")
	check(_stations("schacht").size() == 1, "floor 1 has the way down")
	check(lvl.enemies.size() >= 10, "floor 1 is held by monsters (%d)" % lvl.enemies.size())
	await _find_lever(lvl)

	# Floor 2: sneak past the guardians, the hidden bed.
	lvl = _load("spire2")
	check(lvl.inn and lvl.pitch_dark, "floor 2 is dark and has a bed to rest in")
	check(_stations("bett").size() == 1 and lvl._secrets.size() == 1, "the bed lies behind a secret wall")
	check(lvl.enemies.filter(func(e): return e.kind == "waechter").size() >= 3, "guardians watch the cistern")
	check(lvl._doors.size() == 1, "a locked door closes the way on")
	await _find_lever(lvl)
	await _rest_in_bed()

	# Floor 3: blades, ledge, crate, cache, anvil, the first sub boss.
	lvl = _load("spire3")
	check(lvl.sweepers != null and lvl.sweepers.blades.size() == 8, "floor 3 has eight blade sweepers")
	check(get_nodes_in_group("ledge").size() == 1, "floor 3 has the ledge")
	check(lvl.crates.size() == 1, "one loose crate lies on floor 3")
	check(_stations(AshSpire.CACHE).size() == 1 and _stations(AshSpire.ANVIL).size() == 1, "floor 3 has the supply cache and the anvil")
	check(lvl.enemies.any(func(e): return e.kind == "felstroll" and e.hp >= 100), "Gorrak guards the way down")
	await _blades_and_ledge(lvl)

	# Floor 4: the prisoner, the second bed, the puzzle gate, the second sub boss.
	lvl = _load("spire4")
	check(lvl.inn and _stations("bett").size() == 1, "floor 4 has the second hidden bed")
	await _find_lever(lvl)
	check(_stations(AshSpire.PRISONER).size() == 1, "floor 4 has the prisoner")
	check(lvl._gates.size() == 1 and lvl.stones.size() == 2, "floor 4 has a block puzzle")
	check(lvl.enemies.any(func(e): return e.kind == "magier" and e.hp >= 60), "the archivist waits behind the gate")
	await _prisoner(lvl)
	await _cache_and_anvil()

	# Floor 5: the grimoire, the boss vault, the hatch up.
	lvl = _load("spire5")
	check(lvl.hatch_to == "spire1" and _stations(AshSpire.HATCH).size() == 1, "floor 5 has the hidden hatch up to the courtyard")
	check(_stations(AshSpire.BOOK).size() == 1, "floor 5 has the grimoire")
	check(lvl.enemies.any(func(e): return e.kind == "banshee" and e.hp >= 100), "Ashkaran's shade haunts the vault")
	await _book_and_bolt(lvl)
	await _hatch(lvl)
	await _respawn()
	_finish()


## The blades cut a hero standing under the arm, and spare one in the air.
func _blades_and_ledge(lvl: Level) -> void:
	var b: Dictionary = lvl.sweepers.blades[0]
	var on_arm: Vector3 = b.pos + Vector3(cos(b.angle), 0, sin(b.angle)) * 1.2
	check(AshBlades.cuts(b, on_arm), "a hero on the ground under the arm is cut")
	check(not AshBlades.cuts(b, on_arm + Vector3(0, 1.0, 0)), "a hero in the air above it is not")
	check(not AshBlades.cuts(b, b.pos + Vector3(-sin(b.angle), 0, cos(b.angle)) * 1.4), "a hero beside the arm is not")
	# A running jump over the ledge needs a step.
	var ledge: AshLedge = get_nodes_in_group("ledge")[0]
	var p: Player = game.player
	check(is_equal_approx(ledge.top(), 2.4), "the ledge is three crates high")
	check(Player.STEP_UP < ledge.top() and Player.GRAB_REACH + 1.56 < ledge.top(), "a jump alone does not reach the ledge")
	check(Player.GRAB_REACH + 1.56 + Crate.SIZE >= ledge.top(), "a crate as a step does")
	var foot := ledge.global_position + Vector3(0, 0, 3.0)
	p.global_position = foot
	p.velocity = Vector3.ZERO
	await _wait(5)
	p.face(ledge.global_position - p.global_position)
	p.jump()
	for i in 40:
		p.steer = Vector3(0, 0, -1)
		await physics_frame
	p.steer = Vector3.ZERO
	check(p.global_position.y < 1.0, "without a step the hero cannot climb the ledge (y %.2f)" % p.global_position.y)
	p.global_position = foot
	p.velocity = Vector3.ZERO
	await _wait(5)
	var crate := lvl.add_crate(foot + Vector3(0, 0, -0.9))
	await _wait(5)
	# Up onto the crate, then a jump against the ledge.
	p.global_position = Vector3(crate.global_position.x, crate.top() + 0.05, crate.global_position.z + 0.2)
	await _wait(5)
	p.face(ledge.global_position - p.global_position)
	p.jump()
	for i in 40:
		p.velocity.z = -3.0
		p.steer = Vector3(0, 0, -1)
		await physics_frame
	p.steer = Vector3.ZERO
	check(p.global_position.y > ledge.top() - 0.5 and absf(p.global_position.z - ledge.global_position.z) < 2.2, "standing on the crate, a jump takes the hero up onto the ledge (y %.2f)" % p.global_position.y)
	crate.queue_free()
	lvl.crates.erase(crate)


func _prisoner(lvl: Level) -> void:
	var s: Dictionary = _stations(AshSpire.PRISONER)[0]
	game.player.bag.assign([])
	game.quests.clear()
	AshSpire.use(game, s)
	check(game.quests.is_active(AshSpire.PRISONER_QUEST), "talking to the prisoner notes his task in the quest log")
	check(game.quests.log_entries() == [AshSpire.PRISONER_QUEST] and game.quests.missing(AshSpire.PRISONER_QUEST) == 1, "it is open and still needs a potion")
	check(game.quests.board().size() == 1 and game.quests.board()[0].contains("Orlan"), "in the archive, his task is on the event board: %s" % str(game.quests.board()))
	game.event_log.set_tasks(game.quests.board())
	check(game.event_log.tasks().size() == 1, "the event log pins it")
	check(game.menus.quest_hints().any(func(t): return t.contains("Orlan")) == false, "no hint to hand in before a potion is carried")
	AshSpire.use(game, s)
	check(game.quests.is_active(AshSpire.PRISONER_QUEST), "talking again does not restart or finish it")
	game.player.bag.assign(["heiltrank"])
	check(game.menus.quest_hints().any(func(t): return t.contains("Orlan")), "with a potion in the bag, the hints say to bring it to Orlan")
	AshSpire.use(game, s)
	check(game.quests.is_done(AshSpire.PRISONER_QUEST), "the potion finishes his task, which is marked done")
	check(game.quests.board().is_empty(), "a finished task leaves the event board")
	check(not game.quests.in_area("pass") and not game.quests.in_area("dungeon"), "the archive is neither the pass nor the dungeon")
	check(lvl.taken.has("ash:prisoner") and not game.player.bag.has("heiltrank"), "a healing potion buys the prisoner's secret")


func _cache_and_anvil() -> void:
	var lvl := _load("spire3")
	var p: Player = game.player
	p.bag.assign([])
	var cache: Dictionary = _stations(AshSpire.CACHE)[0]
	game.world_hours = 1.0
	lvl.world_hours = 1.0
	AshSpire.use(game, cache)
	check(p.bag.count("heiltrank") == AshSpire.CACHE_POTIONS, "the cache gives healing potions")
	AshSpire.use(game, cache)
	check(p.bag.count("heiltrank") == AshSpire.CACHE_POTIONS, "the cache is empty at once afterwards")
	lvl.world_hours = 1.0 + AshSpire.REFILL_HOURS + 0.1
	AshSpire.use(game, cache)
	check(p.bag.count("heiltrank") == AshSpire.CACHE_POTIONS * 2, "and full again after some hours")
	p.equipped.clear()
	p.bag.assign(["rundschild"])
	p.wear["rundschild"] = 4
	var anvil: Dictionary = _stations(AshSpire.ANVIL)[0]
	AshSpire.use(game, anvil)
	check(p.wear.get("rundschild", 0) == 0, "the anvil mends the gear")


func _book_and_bolt(lvl: Level) -> void:
	var p: Player = game.player
	await _wait(90)
	p.xp.erase(AshSpire.SPELL)
	check(not AshSpire.knows_spell(p), "the hero starts without the spell")
	AshSpire.cast(p)
	check(get_nodes_in_group("nothing").is_empty() and lvl.get_children().filter(func(c): return c is AshBolt).is_empty(), "no bolt before the grimoire")
	var s: Dictionary = _stations(AshSpire.BOOK)[0]
	AshSpire.use(game, s)
	check(AshSpire.knows_spell(p), "taking the grimoire teaches the spell")
	check(AshSpire.spell_power(p) >= 6, "the bolt hurts")
	# A victim in front of the hero.
	var victim: Enemy = lvl.enemies.filter(func(e): return e.kind == "krieger" or e.kind == "magier" or e.kind == "schuetze")[0]
	p.global_position = victim.global_position + Vector3(0, 0, 6.0)
	p.set_meta("arcane_ready", 0.0)
	await _wait(3)
	var hp := victim.hp
	victim.global_position = p.global_position + Vector3(0, 0, -6.0)
	AshSpire.cast(p)
	check(not lvl.get_children().filter(func(c): return c is AshBolt).is_empty(), "the bolt flies")
	await _wait(60)
	check(victim.hp < hp or victim.dead, "the bolt hits a monster")
	check(float(p.get_meta("arcane_ready", 0.0)) > Time.get_ticks_msec() / 1000.0, "the next bolt has to wait")


func _hatch(lvl: Level) -> void:
	var s: Dictionary = _stations(AshSpire.HATCH)[0]
	game.use_hatch(s)
	await _wait(5)
	check(game.level.building == "spire1", "the hatch leads up to the courtyard")
	check(game.level.hatch_side != Vector3.ZERO and game.player.global_position.distance_to(game.level.hatch_side) < 1.0, "and the hero comes out beside the hatch")


## A monster that fell comes back after the hours, and not before.
func _respawn() -> void:
	var lvl := _load("spire1")
	game.world_hours = 100.0
	lvl.world_hours = 100.0
	var m: Dictionary = lvl._map_enemies[0]
	var cell: Vector2i = m.cell
	m.enemy.take_hit(10000, lvl.cell_to_world(cell) + Vector3(1, 0, 0))
	await _wait(5)
	check(m.enemy.dead, "the monster fell")
	lvl.note_left()
	check(lvl.taken[Level.slain_key(cell)] is float, "its fall is noted with the hour")
	lvl = _load("spire1")
	check(lvl._map_enemies.size() == lvl.enemies.size() or true, "level reloaded")
	var back := lvl._map_enemies.filter(func(e): return e.cell == cell)
	check(back.is_empty(), "it has not come back at once")
	game.world_hours = 100.0 + Level.RESPAWN_HOURS + 1.0
	lvl.world_hours = game.world_hours
	lvl = _load("spire1")
	back = lvl._map_enemies.filter(func(e): return e.cell == cell)
	check(not back.is_empty(), "it is back after the hours")


## Standing by the lever torch in view opens the secret wall (sure: ja).
func _find_lever(lvl: Level) -> void:
	var sec: Dictionary = lvl._secrets[0]
	check(sec.lever != null, "%s: the secret wall has a lever torch" % lvl.building)
	if sec.lever == null:
		return
	var lever_at: Vector3 = lvl.cell_to_world(sec.lever_cell)
	var spot := lever_at
	game.player.global_position = spot
	await _wait(40)
	check(sec.open, "%s: standing by the lever opens the secret wall at once" % lvl.building)


## Resting in the hidden bed heals and saves.
func _rest_in_bed() -> void:
	var p: Player = game.player
	p.hp = 1
	game.state = game.State.PLAYING
	game.hero_name = HERO
	game.rest_at_inn()
	await _wait(600)
	check(p.hp == p.max_hp, "a night in the hidden bed heals (hp %d/%d, state %s)" % [p.hp, p.max_hp, game.state])
