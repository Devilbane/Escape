extends SceneTree
## Headless test: a hero standing in the doorway of a locked door is never
## stuck there and is never struck through it.
## - A closed door blocks the line between its two sides (Level.door_between),
##   also for a hero standing right in its doorway (has_line_of_sight).
## - A monster behind the closed door does not strike the hero in the doorway.
## - The path finding sets out from the doorway (a click walks the hero out),
##   and walking away gets the hero out of it.
## - Once the door is open, nothing stands between the two sides any more.
## Run with: godot --headless --fixed-fps 60 -s tests/door_safety.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var door: Dictionary
var enemy: Enemy
var start_hp := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: door safety")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Across the door: +1 is the hero's side, -1 the monster's side.
func _side(way: float, depth: float) -> Vector3:
	var p: Vector3 = door.pos
	return p + (Vector3(0, 0, way * depth) if door.spans_x else Vector3(way * depth, 0, 0))


## The first living skeleton that fights with a blade.
func _pick_enemy(lvl: Level) -> Enemy:
	for e in lvl.enemies:
		if is_instance_valid(e) and not e.dead and not e.ranged:
			return e
	return null


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var player: Player = game.player
	var lvl: Level = game.level
	match stage:
		0:
			if lvl._doors.is_empty():
				check(false, "the first level has a door")
				_finish()
				return true
			door = lvl._doors[0]
			lvl.has_key = false
			check(not door.open, "the door starts locked")
			# Plain geometry: across the leaf is blocked, the same side is not,
			# and a line passing well beside the doorway is not either.
			check(lvl.door_between(_side(1, 1.2), _side(-1, 1.2)), "the closed door stands between its two sides")
			check(not lvl.door_between(_side(1, 1.2), _side(1, 3.0)), "nothing between two spots on the same side")
			var beside := Vector3(Level.TILE * 2.0, 0, 0) if door.spans_x else Vector3(0, 0, Level.TILE * 2.0)
			check(not lvl.door_between(_side(1, 1.0) + beside, _side(-1, 1.0) + beside), "a line beside the doorway does not pass the leaf")
			# The hero right in the doorway, a monster pressed against the
			# other side of the leaf: no line of sight between them.
			check(not lvl.has_line_of_sight(_side(-1, 1.1), _side(1, 1.1)), "no line of sight through the door to a hero in the doorway")
			check(not lvl.has_line_of_sight(_side(1, 1.1), _side(-1, 1.1)), "no line of sight through the door out of the doorway")
			enemy = _pick_enemy(lvl)
			if enemy == null:
				check(false, "the level has a skeleton with a blade")
				_finish()
				return true
			# Only this one skeleton takes part.
			for e in lvl.enemies:
				if is_instance_valid(e) and e != enemy:
					e.process_mode = Node.PROCESS_MODE_DISABLED
			# A long reach, so the hero in the doorway is well within it.
			enemy._stats = enemy._stats.duplicate()
			enemy._stats.reach = 3.5
			player.global_position = _side(1, 1.1)
			player.velocity = Vector3.ZERO
			player.hp = player.max_hp
			player._invulnerable = 0.0
			enemy.global_position = _side(-1, 0.5 + enemy.radius + 0.05)
			enemy._wake(player.global_position)
			enemy._cooldown = 0.0
			start_hp = player.hp
			stage_frames = 0
			stage = 1
		1:
			# Three seconds side by side with the leaf between them.
			player._invulnerable = 0.0
			stage_frames += 1
			if stage_frames >= 180:
				check(player.hp == start_hp, "the monster behind the closed door never struck the hero (life %d of %d)" % [player.hp, start_hp])
				# The hero's own blows do not pass the door either.
				player.global_position = _side(1, 1.1)
				enemy.global_position = _side(-1, 0.5 + enemy.radius + 0.05)
				check(not player.enemies_in_reach().has(enemy), "the hero cannot strike through the closed door")
				enemy.process_mode = Node.PROCESS_MODE_DISABLED
				# The path finding sets out from the doorway.
				var here: Vector2i = door.cell
				var away: Vector2i = lvl.world_to_cell(_side(1, Level.TILE * 2.0))
				check(lvl.astar.is_point_solid(here), "the locked doorway is solid for the path finding")
				var way := lvl.grid_path(here, away)
				check(not way.is_empty() and way[-1] == away, "a click walks the hero out of the doorway")
				check(lvl.astar.is_point_solid(here), "the doorway stays solid after the path is found")
				# A click away walks the hero out.
				player.global_position = _side(1, 1.1)
				player.walk_to(lvl.cell_to_world(away))
				check(not player.path.is_empty(), "the hero sets out from the doorway")
				stage_frames = 0
				stage = 2
		2:
			stage_frames += 1
			if stage_frames >= 60:
				check(lvl.world_to_cell(player.global_position) != door.cell, "the hero walked out of the doorway")
				# With the key the door opens, and nothing stands between the sides.
				lvl.has_key = true
				player.global_position = _side(1, 2.5)
				stage_frames = 0
				stage = 3
		3:
			stage_frames += 1
			if door.open or stage_frames >= 30:
				check(door.open, "the door opens with the key")
				check(not lvl.door_between(_side(1, 1.2), _side(-1, 1.2)), "an open door stands between nothing")
				_finish()
				return true
	return false
