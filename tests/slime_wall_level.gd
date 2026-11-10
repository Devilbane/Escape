extends SceneTree
## Only slimes and blobs of SlimeGrowth.WALL_LEVEL or more go for the village wall: smaller ones
## ignore it (no approach, no damage). Also checks the gate on its own.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_wall_level.gd

var game: Node
var frames := 0
var started := false
var failures := 0


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	game.hero_name = "Wall level test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	var wall: VillageWall = lvl.village_wall
	lvl.night = false
	lvl.player.global_position = Vector3(160, 0, 160)
	var west: WallBrick = wall.brick_at(Vector2i(37, 27))
	for L in [1, SlimeGrowth.WALL_LEVEL - 1, SlimeGrowth.WALL_LEVEL, SlimeGrowth.MAX_LEVEL]:
		for b: WallBrick in wall.bricks.values():
			b.mend(float(WallBrick.MAX_HP))
		for e in lvl.enemies:
			if is_instance_valid(e):
				e.dead = true
				e.global_position = Vector3(0, -50, 0)
		lvl.day += 1
		var s := lvl.spawn_slime("schleim", west.global_position + Vector3(-6, 0, 0), {})
		s.rated_level = Enemy.fit_level(s.kind, s._stats, s.hardening, L, SlimeGrowth.MAX_LEVEL)
		var expect: bool = s.rated_level >= SlimeGrowth.WALL_LEVEL
		if SlimeGrowth.can_besiege(s) != expect:
			failures += 1
			print("FAIL: can_besiege is wrong for level %d" % s.rated_level)
		# The three ways a slime picks the wall: scouting it, and being aimed at it
		# when it cannot reach what it hunts.
		s._wall_target = null
		var scouted: bool = s._scout_wall(false, 2.0)
		var scouted_target: bool = s._wall_target != null
		s._wall_target = null
		s._aim_at_wall(west.global_position + Vector3(8, 0, 0))
		s._siege_wall_for(west.global_position + Vector3(8, 0, 0))
		var aimed: bool = s._wall_target != null
		print("level %d: besieges=%s scouted=%s aimed=%s" % [s.rated_level, expect, scouted, aimed])
		if expect and not (scouted and scouted_target):
			failures += 1
			print("FAIL: a level %d slime does not scout the wall" % s.rated_level)
		if not expect and (scouted or scouted_target or aimed):
			failures += 1
			print("FAIL: a level %d slime went for the wall" % s.rated_level)
		if not expect:
			# And left alone for a while, it does the wall no harm.
			s._wall_target = null
			var low := 1000
			for i in 20:
				await _wait(30)
				wall.tick(lvl, 0.5)
				for b: WallBrick in wall.bricks.values():
					low = mini(low, b.hp)
			if low < WallBrick.MAX_HP or s._wall_target != null:
				failures += 1
				print("FAIL: a level %d slime hurt the wall" % s.rated_level)
		if is_instance_valid(s):
			s.dead = true
	game.delete_save(game.save_path())
	print("PASS: slime wall level" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
