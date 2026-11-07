extends SceneTree
## Headless test: what a slime carries in its belly (see Enemy.belly,
## Level.spill_belly) all comes out where it falls, however it falls, and
## nothing of it still shows inside its melting body afterwards.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_belly.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var spot := Vector3.INF
var slime: Enemy
var eater: Enemy
var swords_before := 0


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
	if failures == 0:
		print("PASS: slime belly")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## How many of `id` lie on the floor within `reach` of `at`.
func _on_floor(id: String, at: Vector3, reach := 6.0) -> int:
	var n := 0
	for p in game.level._pickups:
		if p.get("kind", "") == "item" and p.get("id", "") == id and is_instance_valid(p.node) \
				and Vector2(p.node.global_position.x - at.x, p.node.global_position.z - at.z).length() < reach:
			n += 1
	return n


## The swallowed things still showing inside `e`'s body.
func _shown(e: Enemy) -> int:
	if not is_instance_valid(e) or e._model == null:
		return 0
	return e._model.get_children().filter(func(c): return c.has_meta(Enemy.BELLY_PIECE) and not c.is_queued_for_deletion()).size()


## A slime of the open air at `at`, as the level makes them, with `loot` in its belly.
func _slime(at: Vector3, level: int, loot: Array) -> Enemy:
	var out: Outdoor = game.level
	var e := out.spawn_slime("schleim", at, {"kept_level": level})
	if not loot.is_empty():
		e.belly.append({"victim": null, "loot": loot})
		e.show_swallowed(loot)
	return e


func _open_spot() -> Vector3:
	var lvl: Level = game.level
	for y in range(4, lvl.height - 4):
		for x in range(4, lvl.width - 4):
			var free := true
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					var c := Vector2i(x + dx, y + dy)
					if lvl.astar.is_point_solid(c):
						free = false
			if not free:
				continue
			var at := lvl.cell_to_world(Vector2i(x, y))
			if at.distance_to(game.player.global_position) < 40.0:
				continue
			if lvl.enemies.any(func(e): return is_instance_valid(e) and e.global_position.distance_to(at) < 30.0):
				continue
			return at
	return Vector3.INF


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	stage_frames += 1
	match stage:
		0:
			game.hero_name = "Belly test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			game.level.village_alarm._check = 1e9
			spot = _open_spot()
			check(spot != Vector3.INF, "there is open ground for the test")
			if spot == Vector3.INF:
				_finish()
				return true
			# The hero fells a slime with a sword and an axe in it.
			slime = _slime(spot, 8, [["item", "schwert"], ["item", "axt"]])
			check(_shown(slime) == 2, "the sword and the axe show inside the slime (%d)" % _shown(slime))
			slime.take_hit(99999, slime.global_position + Vector3.FORWARD, "hit", false)
			stage = 1
			stage_frames = 0
		1:
			if stage_frames == 10:
				check(slime.dead, "the slime is felled")
				check(_on_floor("schwert", spot) >= 1, "the sword lies where the slime fell")
				check(_on_floor("axt", spot) >= 1, "the axe lies where the slime fell")
				check(slime.belly.is_empty(), "the belly is empty")
				check(_shown(slime) == 0, "nothing shows inside the melting slime any more (%d)" % _shown(slime))
				# A slime swallows another with a sword in it, then a villager fells it.
				spot += Vector3(12, 0, 0)
				slime = _slime(spot, 5, [["item", "schwert"]])
				eater = _slime(spot + Vector3(1.5, 0, 0), 12, [["item", "axt"]])
				swords_before = _on_floor("schwert", spot)
				slime.hit_by_rival(99999, eater)
				stage = 2
				stage_frames = 0
		2:
			if stage_frames == 90:
				check(slime.dead and slime.swallowed_by == eater, "the bigger slime swallowed the smaller")
				check(_on_floor("schwert", spot) == swords_before, "the swallowed slime's sword went into the bigger one")
				var things := []
				for meal in eater.belly:
					things.append_array(meal.loot)
				check(things.any(func(t): return t[0] == "item" and t[1] == "schwert"), "the sword is in the bigger slime's belly %s" % [things])
				check(_shown(eater) >= 2, "the sword and the axe (and the smaller one's own loot) show in the bigger slime (%d)" % _shown(eater))
				spot = eater.global_position
				eater.hit_by_rival(99999, null)
				stage = 3
				stage_frames = 0
		3:
			if stage_frames == 10:
				check(eater.dead, "the villagers' blows fell it")
				check(_on_floor("schwert", spot) >= swords_before + 1, "the sword comes out where it fell")
				check(_on_floor("axt", spot) >= 1, "the axe comes out where it fell")
				check(_shown(eater) == 0, "nothing shows inside it any more (%d)" % _shown(eater))
				_finish()
				return true
	return false
