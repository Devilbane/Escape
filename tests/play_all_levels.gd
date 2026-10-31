extends SceneTree
## Headless smoke test: plays every level like a (very determined) player.
## It fights skeletons, searches every object, grabs the key and leaves by
## the stairs. Out of the dungeon, it walks to the village elder and then
## into its new house, up to the bed. Run with: godot --headless --fixed-fps 60 -s tests/play_all_levels.gd
## (--fixed-fps makes the run deterministic and much faster than real time).

var game: Node
var total := 0.0
var timer := 0.0
var searched := 0
var reached := 0
var gifts := 0
var equips := 0
## Death ends a run, but the bot is no expert fighter: it gets healed when it
## is down to its last two lives (a brute hits for 2), and the test counts
## how often that was needed.
var rescues := 0
var backstabs := 0
## Where the hero stood a moment ago, to notice it walking into a corner.
var _last_spot := Vector3.INF
var _still := 0.0


func _initialize() -> void:
	seed(int(OS.get_environment("TEST_SEED")) if OS.has_environment("TEST_SEED") else 1)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _cell_of(ch: String) -> Vector3:
	var lvl: Level = game.level
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) == ch:
				return lvl.cell_to_world(Vector2i(x, y))
	return Vector3.INF


func _process(delta: float) -> bool:
	total += delta
	timer += delta
	if total > 2400.0:
		print("FAIL: timeout at level ", game.level_index + 1)
		return true
	if game.state == game.State.TITLE:
		game._start_playing()
		return false
	if game.state == game.State.PLAYING and game.player.hp <= 2 and not game.player.dead:
		game.player.hp = game.player.max_hp
		rescues += 1
	if game.state == game.State.OVER:
		print("FAIL: the hero fell on level ", game.level_index + 1)
		return true
	if game.state == game.State.WON:
		# A whole run of fighting and running must have trained the hero,
		# but only a little: about one point per attribute.
		var trained := {}
		for id in game.player.xp:
			trained[id] = roundi(game.player.xp[id])
		print("  trained ", trained, ", attributes ", Training.ATTRIBUTES.keys().map(func(id): return game.player.attribute(id)))
		if game.player.xp.get("staerke", 0.0) <= 0.0 or game.player.xp.get("tempo", 0.0) <= 0.0:
			print("FAIL: fighting and running trained nothing")
			return true
		print("PASS: all ", game.level_files.size(), " levels finished, gold ", game.coins, ", searched ", searched, ", shrine gifts ", gifts, ", bag emptied ", equips, ", worn ", game.player.equipped.values(), ", rescued ", rescues, "x, backstabs ", backstabs)
		return true
	if game.level_index > reached:
		reached = game.level_index
		print("  reached level ", reached + 1)
		# Entering the safe room must have saved the game right there.
		if game.level.safe and not game.level.outdoor and game.level.building == "" and (not game.has_save() or int(game.save_info().level) != reached + 1):
			print("FAIL: no autosave on entering the safe room, level ", reached + 1)
			return true
	var player: Player = game.player
	# A shrine asks for a choice: take each gift once over the run.
	if not game._shrine.is_empty():
		game._choose_gift(gifts % 3)
		gifts += 1
		return false
	if game.menus.is_open():
		game.menus.close()
		return false
	if OS.has_environment("TEST_DEBUG") and int(total * 10) % 50 == 0:
		print("  t=%d lvl=%d pos=%s hp=%d knives=%d path=%d busy=%s state=%d key=%s" % [total, game.level_index + 1, game.level.world_to_cell(player.global_position), player.hp, player.knives, player.path.size(), player.can_act(), game.state, game.level.has_key])
	if game.state != game.State.PLAYING or not player.can_act():
		return false
	var lvl: Level = game.level
	if lvl.building != "":
		return _in_building(lvl, player)
	if lvl.outdoor:
		return _back_outside(lvl, player) if _was_in_cellar else _village(lvl, player)

	# Caught on a shrine or a table edge with somewhere to go: step aside.
	if player.global_position.distance_to(_last_spot) > 0.3:
		_last_spot = player.global_position
		_still = 0.0
	else:
		_still += delta
		if _still > 4.0:
			_still = 0.0
			var side := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU) * 2.5
			player.path.assign([player.global_position + side])
			return false

	# Fight anything close by.
	for e in lvl.enemies:
		if is_instance_valid(e) and not e.dead and e.kind != "waechter" and lvl.has_line_of_sight(player.global_position, e.global_position):
			var d := player.global_position.distance_to(e.global_position)
			if d < Player.MELEE_RANGE + e.girth() - 0.2:
				player.melee()
				return false
			if d < 14.0:
				if player.knives > 0:
					player.throw_knife()
				elif lvl.world_to_cell(e.global_position) == lvl.world_to_cell(player.global_position):
					# Same tile: the path finder has nothing to do, so step straight at it.
					player.path.assign([e.global_position])
				elif player.path.is_empty():
					player.walk_to(e.global_position)
					if player.path.is_empty():
						# It stands where the path finder cannot go (by a pillar): step straight at it.
						player.path.assign([e.global_position])
				return false

	# An armoured guardian only falls to a stab in the back: sneak round
	# behind it while it stands guard; while it hunts, just carry on.
	var guardian: Enemy = null
	for e in lvl.enemies:
		if is_instance_valid(e) and not e.dead and e.kind == "waechter":
			if e.is_hunting():
				# Spotted: run back to the start until it gives up and returns.
				if player.sneaking:
					game._toggle_sneak()
				if player.path.is_empty():
					player.walk_to(_cell_of("P"))
				return false
			guardian = e
	if guardian:
		var near_it := guardian.global_position.distance_to(player.global_position) < 27.0
		if near_it != player.sneaking and lvl.enemies.all(func(e): return not is_instance_valid(e) or not e.is_hunting()):
			game._toggle_sneak()
		if guardian.open_to_backstab(player.global_position) and player.global_position.distance_to(guardian.global_position) < Player.MELEE_RANGE + guardian.girth() - 0.4:
			player.melee()
			backstabs += 1
			return false
		if guardian.open_to_backstab(player.global_position) and player.global_position.distance_to(guardian.global_position) < Level.TILE * 1.2:
			# Right behind it: step straight up to it.
			player.path.assign([guardian.global_position])
		elif player.path.is_empty():
			# Keep to the dark rim: round the far corner behind it, then up its back.
			var back: Vector3 = guardian.global_position - guardian.ahead() * Level.TILE * 2.0
			var target: Vector3 = guardian.global_position - guardian.ahead() * Level.TILE * 0.9
			if not guardian.open_to_backstab(player.global_position):
				var side := guardian.ahead().cross(Vector3.UP) * Level.TILE * 3.0
				if player.global_position.distance_to(guardian.global_position - side) < player.global_position.distance_to(guardian.global_position + side):
					side = -side
				target = back + side if lvl.cell_char(lvl.world_to_cell(back + side)) != "#" else back
			elif player.global_position.distance_to(back) > Level.TILE * 0.7:
				target = back
			player.walk_to(target)
			if player.path.is_empty():
				player.path.assign([target])
		return false
	elif player.sneaking:
		game._toggle_sneak()

	if timer < 0.4 or not player.path.is_empty():
		return false
	timer = 0.0

	# Search the nearest object that is still closed, then key, then exit.
	# A full bag would block chests: try on everything, then throw the rest away.
	if player.bag.size() >= Items.BAG_SIZE:
		for id in player.bag.duplicate():
			player.equip(id)
		player.bag.clear()
		equips += 1
	# A little extra reach, since walking stops up to 0.3 m short of a path point.
	var near := lvl.nearest_interactable(player.global_position, Level.SEARCH_RANGE + 0.5)
	if not near.is_empty() and not near.searched:
		game._search(near)
		searched += 1
		return false
	# Run into the shrine, like a player would.
	var shrine := lvl.nearest_station(player.global_position)
	if not shrine.is_empty() and shrine.kind == "schrein":
		player.path.assign([shrine.pos])
		return false
	for s in lvl.stations:
		if s.kind == "schrein" and not s.used:
			player.walk_to(s.pos)
			return false
	for obj in lvl.interactables:
		if not obj.searched:
			var path := lvl.astar.get_id_path(lvl.world_to_cell(player.global_position), obj.cell, true)
			if not path.is_empty() and lvl.cell_to_world(path[-1]).distance_to(obj.pos) <= Level.SEARCH_RANGE:
				player.walk_to(obj.pos)
				if player.path.is_empty():
					# Right next to it but off to one side: run into it like a player.
					player.path.assign([obj.pos])
				return false
	if not lvl.has_key and not lvl._doors.all(func(d): return d.open):
		var key_cell := _cell_of("K")
		if key_cell == Vector3.INF:
			# A guardian carries the key: go to it, and the sneak above takes over.
			for e in lvl.enemies:
				if is_instance_valid(e) and not e.dead and e.kind == "waechter":
					key_cell = e.global_position
			if key_cell == Vector3.INF:
				# The guardian fell: the key lies where it stood.
				for p in lvl._pickups:
					if p.kind == "key" and is_instance_valid(p.node):
						key_cell = p.node.global_position
		player.walk_to(key_cell)
	elif not lvl._doors.all(func(d): return d.open):
		# Head for the door first: from a secret room the stairs can seem
		# closer than the way round to them.
		var door := _cell_of("D")
		if player.global_position.distance_to(door) < 8.0:
			# Path finding stops a step short: run into it like a player.
			player.path.assign([door])
		else:
			player.walk_to(door)
	else:
		player.walk_to(_cell_of("E"))
	return false


## Out in the open: the escape is in the ranking and saved, the elder hands
## over the house, the villagers go about their day, and the hero walks home.
var _village_time := 0.0
var _slept := false
func _village(lvl: Outdoor, player: Player) -> bool:
	_village_time += 1.0 / 60.0
	if not game.escaped:
		print("FAIL: stepping out of the crypt did not count as an escape")
		return true
	if not game.has_save() or int(game.save_info().level) != game.level_index + 1:
		print("FAIL: no autosave on stepping out of the crypt")
		return true
	if not player.path.is_empty():
		return false
	if not lvl.house_given:
		var elder: Node3D = lvl.villagers.filter(func(v): return v.role == "0")[0]
		player.walk_to(elder.global_position, 3.0)
		return false
	var bed: Dictionary = lvl.stations.filter(func(s): return s.kind == "bett")[0]
	if not _slept and player.global_position.distance_to(bed.pos) > Level.SEARCH_RANGE:
		player.walk_to(bed.pos, 2.0)
		if player.path.is_empty():
			print("FAIL: no way to the bed in the hero's house")
			return true
		return false
	_slept = true
	var moved: int = lvl.villagers.filter(func(v): return v.global_position.distance_to(lvl.cell_to_world(v.home)) > 1.0).size()
	if moved == 0:
		print("FAIL: no villager moved from their spot")
		return true
	# Then over to the bank and down into its vault cellar.
	var door: Vector3 = lvl.doors["b"]
	if player.global_position.distance_to(door) > 3.0:
		player.walk_to(door, 2.0)
		if player.path.is_empty():
			print("FAIL: no way to the bank door")
			return true
		return false
	_moved = moved
	game.go_inside("b")
	return false


## Inside the bank's vault cellar, then up the stairs and out of the door.
var _moved := 0
var _was_in_cellar := false
func _in_building(lvl: Level, player: Player) -> bool:
	if lvl.building != "b" or lvl.floor_name != "keller":
		print("FAIL: the bank door led to ", lvl.level_name)
		return true
	if lvl._vault_slots.size() < 16:
		print("FAIL: the vault cellar has only ", lvl._vault_slots.size(), " cells")
		return true
	_was_in_cellar = true
	game._next_level()
	return false


func _back_outside(lvl: Outdoor, player: Player) -> bool:
	if player.global_position.distance_to(lvl.doors["b"]) > 3.0:
		print("FAIL: leaving the cellar did not lead out of the bank door")
		return true
	print("PASS: all ", game.level_files.size() - 2, " levels finished and home in the village after ", int(_village_time), " s, gold ", game.coins, ", searched ", searched, ", shrine gifts ", gifts, ", bag emptied ", equips, ", worn ", game.player.equipped.values(), ", rescued ", rescues, "x, backstabs ", backstabs, ", villagers away from their spot ", _moved, ", visited the vault cellar")
	return true
