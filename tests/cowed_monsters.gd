extends SceneTree
## Headless test for cowed monsters (see Enemy.cowed_by): a monster whose
## level is less than half the hero's no longer goes for the hero, not even
## when called to the hunt, but a blow from the hero makes it fight back.
## A hero closer to its level is still hunted, and bosses always fight.
## Run with: godot --headless --fixed-fps 60 -s tests/cowed_monsters.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var wolf: Enemy
var spot := Vector3.INF
var weak_level := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: cowed monsters" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _spawn(kind: String, at: Vector3) -> Enemy:
	var lvl: Level = game.level
	var e := Enemy.new()
	e.kind = kind
	e.level = lvl
	lvl.add_child(e)
	e.global_position = at
	lvl.enemies.append(e)
	return e


## A free tile at least `far` metres from the hero and every monster, or INF.
func _open_spot(far: float) -> Vector3:
	var lvl: Level = game.level
	for y in range(2, lvl.height - 2):
		for x in range(2, lvl.width - 4):
			var free := true
			for i in 3:
				var c := Vector2i(x + i, y)
				if not lvl.astar.is_in_boundsv(c) or lvl.astar.is_point_solid(c):
					free = false
					break
			if not free:
				continue
			var at := lvl.cell_to_world(Vector2i(x, y))
			if at.distance_to(game.player.global_position) < far:
				continue
			if lvl.enemies.any(func(e): return is_instance_valid(e) and not e.dead and e.global_position.distance_to(at) < far):
				continue
			return at
	return Vector3.INF


func _set_hero_level(n: int) -> void:
	game.player.hero_xp = HeroLevel.total_for(n)


## The hero stands right by the wolf, at full life, and the wolf is set on them.
func _face_off() -> void:
	game.player.global_position = wolf.global_position + Vector3(2.0, 0, 0)
	game.player.velocity = Vector3.ZERO
	game.player.hp = game.player.max_hp
	wolf.alert(game.player.global_position)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match stage:
		0:
			game.hero_name = "Cowed test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			Factions.clear()
			var probe := Enemy.new()
			probe.kind = "wolf"
			probe.rated_level = 4
			# Cowed when its level < hero level / 2 + 2, so level 4 needs a hero above 4.
			check(not probe.cowed_by(4), "a hero at the boundary (monster level = half + 2) is still attacked")
			check(probe.cowed_by(5), "a hero just above the boundary is left alone")
			check(not probe.cowed_by(1), "a weak hero is attacked")
			probe.kind = "hauptmann"
			probe.rated_level = 4
			check(not probe.cowed_by(20), "a boss always fights")
			probe.free()
			spot = _open_spot(60.0)
			check(spot != Vector3.INF, "there is open ground for the test")
			if spot == Vector3.INF:
				_finish()
				return true
			wolf = _spawn("wolf", spot)
			stage_frames = 0
			stage = 1
		1:
			# The wolf is ready (and rated): now a hero far above it.
			stage_frames += 1
			if stage_frames < 3:
				return false
			weak_level = wolf.rated_level
			check(weak_level * 2 < HeroLevel.MAX, "the wolf is weak enough for the test (level %d)" % weak_level)
			_set_hero_level(mini(HeroLevel.MAX, weak_level * 2 + 1))
			check(wolf.is_cowed(), "the wolf is cowed by a hero of level %d" % game.player.hero_level())
			_face_off()
			stage_frames = 0
			stage = 2
		2:
			stage_frames += 1
			game.player.velocity = Vector3.ZERO
			if stage_frames < 180:
				return false
			check(not wolf.is_hunting(), "a cowed wolf does not hunt the hero")
			check(game.player.hp == game.player.max_hp, "a cowed wolf does not bite")
			# The hero strikes it: now it fights back.
			wolf.take_hit(1, game.player.global_position)
			stage_frames = 0
			stage = 3
		3:
			stage_frames += 1
			game.player.velocity = Vector3.ZERO
			if stage_frames < 60:
				return false
			check(wolf.dead or wolf.is_hunting(), "a struck wolf fights back")
			check(wolf.dead or not wolf.is_cowed(), "a struck wolf is no longer cowed")
			# A hero right at the boundary (wolf level = half + 2) is hunted as before.
			if is_instance_valid(wolf) and not wolf.dead:
				game.level.enemies.erase(wolf)
				wolf.queue_free()
			wolf = _spawn("wolf", spot)
			_set_hero_level(maxi(1, weak_level * 2 - 4))
			stage_frames = 0
			stage = 4
		4:
			stage_frames += 1
			if stage_frames < 3:
				return false
			if weak_level < 3:
				# Even a level-1 hero is above the boundary of such a weak wolf.
				_finish()
				return true
			check(not wolf.is_cowed(), "a hero at the boundary does not cow the wolf")
			_face_off()
			stage_frames = 0
			stage = 5
		5:
			stage_frames += 1
			game.player.velocity = Vector3.ZERO
			if stage_frames < 60:
				return false
			check(wolf.is_hunting(), "a wolf not cowed hunts the hero")
			_finish()
			return true
	return false
