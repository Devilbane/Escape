extends SceneTree
## Every slime outside the village wall eats into it (see VillageWall.siege_brick,
## Enemy._scout_wall), with nobody to hunt: slimes of every level, left to the
## wall's defenders, must break through in at least one attempt of three, and
## each of them must at least leave a mark on the wall.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_siege.gd

var game: Node
var frames := 0
var started := false
var failures := 0


func _initialize() -> void:
	seed(11)
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
	game.hero_name = "Siege test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	var wall: VillageWall = lvl.village_wall
	lvl.night = false
	lvl.player.global_position = Vector3(160, 0, 160)
	var levels := [1, 4, 8, 12]
	var west: WallBrick = wall.brick_at(Vector2i(37, 27))
	var wins := 0
	var tries := 0
	for L in levels:
		var won := 0
		for rep in 3:
			for b: WallBrick in wall.bricks.values():
				b.mend(float(WallBrick.MAX_HP))
			for v in lvl.villagers:
				v.global_position = lvl.spots.square[0]
				v._start("idle", 600.0)
			for e in lvl.enemies:
				if is_instance_valid(e):
					e.dead = true
					e.global_position = Vector3(0, -50, 0)
			lvl.day += 1
			var s := lvl.spawn_slime("schleim", west.global_position + Vector3(-12, 0, 0), {})
			s.rated_level = Enemy.fit_level(s.kind, s._stats, s.hardening, L, 25)
			var t := 0
			var broke := false
			var low := 1000
			while t < 90 * 60 and is_instance_valid(s) and not s.dead:
				await _wait(30)
				t += 30
				wall.tick(lvl, 0.5)
				for b: WallBrick in wall.bricks.values():
					low = mini(low, b.hp)
					if b.hp <= 0:
						broke = true
				if broke:
					break
			tries += 1
			if low >= WallBrick.MAX_HP:
				failures += 1
				print("FAIL: a level %d slime never touched the wall" % L)
			if broke:
				won += 1
				wins += 1
			print("L%d rep%d: broke=%s t=%ds low=%d slime_hp=%s dmg=%d" % [L, rep, broke, t / 60, low, str(s.hp) if is_instance_valid(s) else "gone", int(s._stats.damage)])
			if is_instance_valid(s):
				s.dead = true
	print("slimes that broke the wall: %d of %d" % [wins, tries])
	if wins * 3 < tries:
		failures += 1
		print("FAIL: fewer than one attempt in three broke the wall")
	await _villager_first(lvl, wall, west)
	game.delete_save(game.save_path())
	print("PASS: slime siege" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## A villager standing out in the open, 25 m from the slime and out of its sight
## range, is hunted instead of the wall: the slime closes in on it and the wall
## stays whole.
func _villager_first(lvl: Outdoor, wall: VillageWall, west: WallBrick) -> void:
	for b: WallBrick in wall.bricks.values():
		b.mend(float(WallBrick.MAX_HP))
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.dead = true
			e.global_position = Vector3(0, -50, 0)
	var v: Villager = lvl.villagers[0]
	var start := west.global_position + Vector3(-12, 0, 0)
	var s := lvl.spawn_slime("schleim", start, {})
	v.global_position = start + Vector3(-25, 0, 0)
	v._start("idle", 600.0)
	var reach := SlimeGrowth.reachable_villager(s)
	if reach == null:
		print("SKIP: no villager reachable from the test spot")
		s.dead = true
		return
	var d0 := s._flat_distance(v)
	await _wait(240)
	var low := 1000
	for b: WallBrick in wall.bricks.values():
		low = mini(low, b.hp)
	if low < WallBrick.MAX_HP:
		failures += 1
		print("FAIL: a slime with a villager to reach still ate into the wall")
	if is_instance_valid(s) and not s.dead and s._flat_distance(v) >= d0 - 2.0 and not v.has_meta("slime_life"):
		failures += 1
		print("FAIL: the slime did not go for the villager")
	if is_instance_valid(s):
		s.dead = true
