extends SceneTree
## Headless test for the mountains far to the east (see Mountains and Mines):
## a dangerous pass leads out of the wolf hollow, past a little tavern where
## the hero can rest, up to a high valley with three mines. Mines 1 and 2
## each keep a stone tablet with one of two runes; only a hero who has read
## both gets past the seal in mine 3, down to the ember tunnels and the
## heart of the mountain, where the Mountain King waits; once he falls, a
## golden way out leads back in front of the mine.
## Run with: godot --headless --fixed-fps 60 -s tests/mountains.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait := 0
var stage_frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: mountains, tavern and mines" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _station(lvl: Level, kind: String) -> Dictionary:
	for s in lvl.stations:
		if s.kind == kind:
			return s
	return {}


## Goes into a building floor at once, as the door would.
func _enter(building: String) -> void:
	game.state = game.State.PLAYING
	game.go_inside(building)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if wait > 0:
		wait -= 1
		return false
	match stage:
		0:
			game.hero_name = "Mountain test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			_check_open_air()
			stage = 1
		1:
			_enter("[")
			wait = 50
			stage = 2
		2:
			_check_tavern()
			stage = 3
			wait = 600
		3:
			check(game.state == game.State.PLAYING, "the hero gets up after resting")
			check(game.player.hp == game.player.max_hp, "resting in the tavern heals fully (%d / %d)" % [game.player.hp, game.player.max_hp])
			check(absf(game.day_hour - DayNight.WAKE_HOUR) < 0.5, "resting lasts till the morning (%.1f)" % game.day_hour)
			check(game.has_save() and game._read_save().get("inn", false), "resting saves the game in the tavern")
			# Loading that game wakes the hero in the tavern, not back home.
			game.home_claimed = true
			game._apply_save(game._read_save())
			check(game.level.inn and game.player.global_position.distance_to(game.level.bed_side) < 0.5, "a game saved in the tavern wakes up beside its bed")
			_enter("mine3")
			wait = 50
			stage = 4
		4:
			_check_seal_shut()
			_enter("mine1")
			wait = 50
			stage = 5
		5:
			_read_tablet("mine1", "kupfer")
			_enter("mine2")
			wait = 50
			stage = 6
		6:
			_read_tablet("mine2", "kristall")
			check(Mines.unsealed(game.lore), "both runes known after reading both tablets")
			_enter("mine3")
			wait = 50
			stage = 7
		7:
			var lvl: Level = game.level
			var shaft := _station(lvl, "schacht")
			check(not shaft.is_empty() and not shaft.has("slab"), "knowing both runes, the slab lies aside")
			game._use_station(shaft)
			check(lvl.taken.has(game.MINES_SEAL_OPEN), "the seal is remembered as open")
			game._use_station(shaft)
			wait = 50
			stage = 8
		8:
			var lvl: Level = game.level
			check(lvl.building == "mine3b" and lvl.theme == "glut", "the shaft leads down to the ember tunnels (%s)" % lvl.building)
			check(not _station(lvl, "schacht").is_empty(), "the ember tunnels go deeper still")
			# Up the stairs: back beside the shaft in the dwarves' halls.
			game._leave_building()
			wait = 30
			stage = 9
		9:
			var lvl: Level = game.level
			check(lvl.building == "mine3", "the stairs of the ember tunnels lead up to mine 3 (%s)" % lvl.building)
			check(lvl.shaft_side != Vector3.ZERO and game.player.global_position.distance_to(lvl.shaft_side) < 0.5, "coming up, the hero stands beside the shaft")
			_enter("mine3c")
			wait = 60
			stage = 10
		10:
			_check_king()
			# The golden way out shines up a moment after the king fell.
			wait = 150
			stage = 11
		11:
			var lvl: Level = game.level
			check(is_instance_valid(lvl.lair_exit), "where the king fell, a golden way out opens")
			if not is_instance_valid(lvl.lair_exit):
				_finish()
				return true
			var hammer: Array = lvl._pickups.filter(func(p): return p.get("id", "") == Mines.TROPHY)
			check(hammer.is_empty() or hammer[0].node.global_position.distance_to(lvl.lair_exit.global_position) > Level.LAIR_EXIT_RADIUS + 1.0,
					"the way out does not lie on the king's hammer")
			game.player.global_position = Vector3(lvl.lair_exit.global_position.x, game.player.global_position.y, lvl.lair_exit.global_position.z)
			game.player.velocity = Vector3.ZERO
			wait = 0
			stage_frames = 0
			stage = 12
		12:
			# Out through the fade, then a moment to settle (as in tests/dragon_lair.gd).
			stage_frames += 1
			var lvl: Level = game.level
			if not lvl is Outdoor:
				if stage_frames > 200:
					check(false, "the way out leads out of the mine into the open")
					_finish()
					return true
				return false
			if stage_frames < 60:
				return false
			var at: Vector3 = game.player.global_position
			var door: Vector3 = lvl.doors["mine3"]
			check(Vector2(at.x - door.x, at.z - door.z).length() < 3.0,
					"the hero stands in front of mine 3 (%.1f m away)" % Vector2(at.x - door.x, at.z - door.z).length())
			for id in ["mine1", "mine2"]:
				var other: Vector3 = lvl.doors[id]
				check(at.distance_to(other) > at.distance_to(door), "the way out leads to mine 3, not %s" % id)
			_finish()
			return true
	return false


func _check_open_air() -> void:
	var lvl: Outdoor = game.level
	var meshes := lvl.find_children("*Mountains*", "MeshInstance3D", false, false)
	check(meshes.size() >= 4, "the mountains are built as rock meshes (%d)" % meshes.size())
	for id in ["[", "mine1", "mine2", "mine3"]:
		check(lvl.doors.has(id), "the map has a door for %s" % id)
		check(game.interiors.has(id), "%s has a floor of its own" % id)
		check(lvl.stations.any(func(s): return s.kind == "eingang" and s.building == id), "running into %s leads in" % id)
	# The road: from the wolf hollow through the pass to the tavern, and on
	# up to every mine.
	var hollow := Vector2i(-1, -1)
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) == "J":
				hollow = Vector2i(x, y)
	check(hollow.x >= 0, "the yeti of the wolf hollow is on the map")
	for id in ["[", "mine1", "mine2", "mine3"]:
		var way: Array = lvl.astar.get_id_path(hollow, lvl.world_to_cell(lvl.doors[id]))
		check(not way.is_empty(), "a way leads from the wolf hollow to %s" % id)
	# The mines are numbered west to east.
	check(lvl.doors.mine1.x < lvl.doors.mine2.x and lvl.doors.mine2.x < lvl.doors.mine3.x, "mines numbered from west to east")
	# The pass is dangerous: tough monsters of the mountains, which do not
	# count as beasts of the wolf hollow.
	var kinds := {}
	for e in lvl.enemies:
		if is_instance_valid(e) and Enemy.KINDS[e.kind].get("mountain", false):
			kinds[e.kind] = kinds.get(e.kind, 0) + 1
	for kind in ["eiswolf", "bergork", "felstroll", "klippenschuetze"]:
		check(kinds.has(kind), "%s roams the pass" % kind)
		check(Factions.KINDS.has(kind), "%s belongs to a faction" % kind)
	var hollow_beasts := 0
	for e in lvl.enemies:
		if is_instance_valid(e) and not e.dead and e.is_beast() and not Enemy.KINDS[e.kind].get("mountain", false):
			hollow_beasts += 1
	check(lvl.beasts_alive() == hollow_beasts, "the pass's monsters are not counted in the wolf hollow")
	# Rock is as solid as the forest, and blocks sight.
	var rock := Vector2i(-1, -1)
	for x in range(lvl.width - 1, 0, -1):
		if lvl.cell_char(Vector2i(x, 1)) == "=":
			rock = Vector2i(x, 1)
			break
	check(rock.x >= 0 and lvl.astar.is_point_solid(rock) and lvl.is_opaque(rock), "mountain rock cannot be crossed or seen through")
	# Hard monsters for the hero they are made for (see Mines.BENCHMARK): every
	# mountain kind takes at least two blows, none fells the hero in fewer
	# than four, and the rock troll and the Mountain King take a real fight.
	for kind in Enemy.KINDS:
		var stats: Dictionary = Enemy.KINDS[kind]
		if not stats.get("mountain", false):
			continue
		var deep := 0 if kind == "bergkoenig" else Enemy.DEEPEST
		var life: int = stats.hp + deep / Enemy.HP_EVERY_LEVELS
		var hits := ceili(float(life) / Player.soak(Mines.BENCHMARK.power, stats.get("armor", 0)))
		var blow := Player.soak(stats.damage + deep / Enemy.DAMAGE_EVERY_LEVELS, Mines.BENCHMARK.hardening)
		var downs := ceili(float(Mines.BENCHMARK.life) / blow)
		print("%s: %d blows to fell, hits for %d, fells the hero in %d" % [kind, hits, blow, downs])
		check(hits >= 2, "%s takes more than one blow from the benchmark hero (%d)" % [kind, hits])
		check(blow >= 2 and downs >= 4, "%s hurts the benchmark hero but needs at least four hits (%d)" % [kind, downs])
	var troll: Dictionary = Enemy.KINDS.felstroll
	check(ceili(float(troll.hp + Enemy.DEEPEST / Enemy.HP_EVERY_LEVELS) / Player.soak(Mines.BENCHMARK.power, troll.armor)) >= 4, "a rock troll takes several blows")
	check(Enemy.KINDS.bergkoenig.hp / Player.soak(Mines.BENCHMARK.power, Enemy.KINDS.bergkoenig.armor) >= 12, "the Mountain King takes a long fight")


func _check_tavern() -> void:
	var lvl: Level = game.level
	check(lvl.building == "[" and lvl.inn and lvl.safe, "the tavern is a safe inn (%s)" % lvl.level_name)
	check(not _station(lvl, "bett").is_empty() and lvl.bed_side != Vector3.ZERO, "the tavern has a bed")
	check(not _station(lvl, "haendler").is_empty(), "the landlord trades")
	# The hero's storage chest stands in the tavern too, out in the room where
	# the hero can walk up to it and open it.
	var chest := _station(lvl, "lager")
	check(not chest.is_empty(), "the tavern has a storage chest")
	if not chest.is_empty():
		var reach := lvl._reachable()
		var beside := false
		for d in Level.DIRS:
			beside = beside or reach.has(chest.cell + d)
		check(beside, "the tavern's chest can be walked up to (%s)" % chest.cell)
		game._use_station(chest)
		check(game.menus.current == "lager", "bumping the tavern's chest opens the storage (%s)" % game.menus.current)
		game.menus.close()
	game.player.hp = 1
	game.player.global_position = lvl.bed_side
	game.rest_at_inn()
	check(game.state == game.State.TRANSITION, "lying down to rest")


func _check_seal_shut() -> void:
	var lvl: Level = game.level
	check(lvl.building == "mine3" and lvl.seal != "" and lvl.down_to == "mine3b", "mine 3 has a sealed way down")
	var shaft := _station(lvl, "schacht")
	check(not shaft.is_empty() and shaft.has("slab"), "a slab lies over the shaft")
	game._use_station(shaft)
	check(game.level == lvl and shaft.has("slab"), "without the runes the shaft stays shut")
	check(game._message.text.contains(Lang.t("Kupfergrube")) or game._message.text.contains("Kupfergrube"), "the seal says where the runes are")


func _read_tablet(building: String, theme: String) -> void:
	var lvl: Level = game.level
	check(lvl.building == building and lvl.theme == theme, "%s is the %s mine (%s)" % [building, theme, lvl.level_name])
	check(lvl.lair and not lvl.safe, "%s is full of monsters" % building)
	check(not lvl.enemies.is_empty(), "monsters live in %s" % building)
	var tablet := _station(lvl, "tafel")
	check(not tablet.is_empty(), "%s keeps a stone tablet" % building)
	var way: Array = lvl.astar.get_id_path(lvl.start_cell, lvl._open_side(tablet.cell) if lvl._open_side(tablet.cell) != tablet.cell else tablet.cell + Vector2i(-1, 0))
	check(not way.is_empty(), "the tablet of %s can be reached" % building)
	game._use_station(tablet)
	check(Mines.knows(game.lore, theme), "reading the tablet of %s teaches its rune" % building)


func _check_king() -> void:
	var lvl: Level = game.level
	check(lvl.building == "mine3c" and lvl.up_to == "mine3b", "the heart of the mountain lies below the ember tunnels")
	var king: Enemy = lvl.mine_boss
	check(king is MountainKing, "the Mountain King waits in the heart of the mountain")
	check(lvl.mine_boss_bar != null, "the Mountain King has a health bar")
	if not king is MountainKing:
		return
	check(king.max_hp() >= 300, "the Mountain King takes a long fight (%d)" % king.max_hp())
	king.take_hit(king.max_hp() / 2 + 6, king.global_position + Vector3(2, 0, 0), "pierce")
	check(king.phase == 2, "at half his life the Mountain King rages")
	king.take_hit(9999, king.global_position + Vector3(2, 0, 0), "pierce")
	check(king.dead and lvl.taken.has(Mines.KING_DEFEATED), "the fallen king is remembered")
	var hammer := lvl._pickups.filter(func(p): return p.get("item", "") == Mines.TROPHY or p.get("id", "").contains(Mines.TROPHY))
	check(Items.ALL.has(Mines.TROPHY) and Items.ALL[Mines.TROPHY].unique, "the king's hammer is unique")
