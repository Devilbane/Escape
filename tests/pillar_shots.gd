extends SceneTree
## Headless test: stone pillars stop shots.
## - A pillar stands between two spots on either side of it: the view is not
##   blocked (has_line_of_sight), but a shot is (has_clear_shot, shot_blocked),
##   while a line one row over, past the pillar, is clear.
## - A crossbow bolt fired at the hero through the pillar stops at it and
##   never hurts the hero; one fired along the free row flies on past it.
## - A thrown knife stops at the pillar too.
## - An archer with the pillar in the way does not shoot; with a clear line
##   it does.
## Run with: godot --headless --fixed-fps 60 -s tests/pillar_shots.gd

const LEVEL := "03_das_labyrinth.txt"

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var lvl: Level
var pillar: Vector2i
var west: Vector3
var east: Vector3
var shot: Projectile
var free_shot: Projectile
var knife: Projectile
var furthest := -INF
var free_furthest := -INF
var knife_furthest := INF
var archer: Enemy
var start_hp := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: pillar shots")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## A pillar with open floor two tiles to the west and east of it and along
## the row below it, so a shot can fly past it on both lines.
func _find_pillar() -> Vector2i:
	for y in lvl.height:
		for x in lvl.grid[y].length():
			var c := Vector2i(x, y)
			if lvl.cell_char(c) != "o":
				continue
			var open := true
			for dx in range(-2, 3):
				for dy in [0, 1]:
					var n := c + Vector2i(dx, dy)
					if n != c and (lvl.is_opaque(n) or "o#Dx=|".contains(lvl.cell_char(n))):
						open = false
			if open:
				return c
	return Vector2i(-1, -1)


## The first living archer (a skeleton with a crossbow).
func _pick_archer() -> Enemy:
	for e in lvl.enemies:
		if is_instance_valid(e) and not e.dead and e.kind == "schuetze":
			return e
	return null


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var player: Player = game.player
	match stage:
		0:
			var index: int = -1
			for i in game.level_files.size():
				if game.level_files[i].get_file() == LEVEL:
					index = i
			check(index >= 0, "the level %s exists" % LEVEL)
			if index < 0:
				_finish()
				return true
			game.load_level(index, false)
			stage = 1
		1:
			lvl = game.level
			check(not lvl.shot_blockers.is_empty(), "the pillars of the level stop shots")
			pillar = _find_pillar()
			if pillar.x < 0:
				check(false, "the level has a pillar in an open room")
				_finish()
				return true
			for e in lvl.enemies:
				if is_instance_valid(e):
					e.process_mode = Node.PROCESS_MODE_DISABLED
			var middle := lvl.cell_to_world(pillar)
			west = middle - Vector3(Level.TILE * 2.0, 0, 0)
			east = middle + Vector3(Level.TILE * 2.0, 0, 0)
			var below := Vector3(0, 0, Level.TILE)
			check(lvl.has_line_of_sight(west, east), "the pillar does not hide the view (fog, noticing)")
			check(lvl.shot_blocked(west, east), "the pillar stands in the way of a shot")
			check(not lvl.has_clear_shot(west, east), "no clear shot through the pillar")
			check(not lvl.has_clear_shot(east, west), "no clear shot through the pillar the other way")
			check(lvl.has_clear_shot(west + below, east + below), "a clear shot along the free row past the pillar")
			# A bolt at the hero through the pillar, another along the free row.
			player.global_position = east + Vector3(0, 0, 0.2)
			player.velocity = Vector3.ZERO
			player.hp = player.max_hp
			player._invulnerable = 0.0
			start_hp = player.hp
			shot = Projectile.spawn(lvl, west + Vector3(0, 1.4, 0), Vector3.RIGHT, false)
			free_shot = Projectile.spawn(lvl, west + below + Vector3(0, 1.4, 0), Vector3.RIGHT, false)
			knife = Projectile.spawn(lvl, east + Vector3(0, 1.5, 0), Vector3.LEFT, true)
			stage_frames = 0
			stage = 2
		2:
			player._invulnerable = 0.0
			stage_frames += 1
			if is_instance_valid(shot):
				furthest = maxf(furthest, shot.global_position.x)
			if is_instance_valid(free_shot):
				free_furthest = maxf(free_furthest, free_shot.global_position.x)
			if is_instance_valid(knife):
				knife_furthest = minf(knife_furthest, knife.global_position.x)
			if stage_frames >= 60:
				var middle_x := lvl.cell_to_world(pillar).x
				check(not is_instance_valid(shot), "the bolt into the pillar is gone")
				check(furthest < middle_x, "the bolt stopped at the pillar (got to x %.1f, pillar at %.1f)" % [furthest, middle_x])
				check(player.hp == start_hp, "the bolt through the pillar never hurt the hero (life %d of %d)" % [player.hp, start_hp])
				check(free_furthest > middle_x + Level.TILE, "the bolt along the free row flew on past the pillar")
				check(knife_furthest > middle_x, "the thrown knife stopped at the pillar (got to x %.1f)" % knife_furthest)
				archer = _pick_archer()
				if archer == null:
					check(false, "the level has an archer")
					_finish()
					return true
				archer.process_mode = Node.PROCESS_MODE_INHERIT
				archer._stats = archer._stats.duplicate()
				archer._provoked = true  # a weak archer would ignore the hero (see Enemy.cowed_by)
				archer._stats.speed = 0.0
				archer.global_position = west
				archer.velocity = Vector3.ZERO
				player.global_position = east
				player.hp = player.max_hp
				archer._wake(player.global_position)
				archer._cooldown = 0.0
				stage_frames = 0
				stage = 3
		3:
			player._invulnerable = 0.0
			archer.global_position = west
			stage_frames += 1
			if stage_frames >= 60:
				check(archer._cooldown <= 0.0, "the archer with the pillar in the way did not shoot")
				# A clear line: the archer shoots.
				player.global_position = east + Vector3(0, 0, Level.TILE)
				archer.global_position = west + Vector3(0, 0, Level.TILE)
				archer._wake(player.global_position)
				stage_frames = 0
				stage = 4
		4:
			player._invulnerable = 0.0
			archer.global_position = west + Vector3(0, 0, Level.TILE)
			stage_frames += 1
			if archer._cooldown > 0.0 or stage_frames >= 90:
				check(archer._cooldown > 0.0, "the archer with a clear line shoots")
				_finish()
				return true
	return false
