extends SceneTree
## Headless test: the hero and a skeleton each take up their own spot. Put
## inside each other (or the hero on top of a skull), they are pushed apart,
## and neither strikes the other while they are stacked.
## Run with: godot --headless --fixed-fps 60 -s tests/no_stacking.gd

var failures := 0
var game: Node
var frames := 0
var enemy: Enemy
var stage := 0
var stage_frames := 0
var start_hp := 0
var stacked_frames := 0
var hits_while_stacked := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: no stacking")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## The first warrior skeleton of the level, or any living one.
func _pick_enemy() -> Enemy:
	var any: Enemy = null
	for e in game.level.enemies:
		if is_instance_valid(e) and not e.dead:
			if e.kind == "krieger":
				return e
			any = e
	return any


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var player: Player = game.player
	var lvl: Level = game.level
	match stage:
		0, 2:
			enemy = _pick_enemy()
			if enemy == null:
				check(false, "the level has a skeleton")
				_finish()
				return true
			# Stage 0: right inside the skeleton. Stage 2: standing on its skull.
			player.global_position = enemy.global_position + (Vector3(0, enemy.tall + 0.1, 0) if stage == 2 else Vector3(0.05, 0, 0))
			player.velocity = Vector3.ZERO
			enemy._wake(player.global_position)
			enemy._cooldown = 0.0
			start_hp = enemy.hp
			player.hp = player.max_hp
			check(lvl.stacked(player, enemy), "stage %d starts stacked" % stage)
			stacked_frames = 0
			hits_while_stacked = 0
			stage_frames = 0
			stage += 1
		1, 3:
			stage_frames += 1
			if lvl.stacked(player, enemy):
				stacked_frames += 1
				# The hero tries to strike while stacked; it must not land.
				player._attack_cooldown = 0.0
				player._busy = 0.0
				player.melee()
				if player.hp < player.max_hp or enemy.hp < start_hp:
					hits_while_stacked += 1
			if stage_frames == 120:
				var d := player.global_position - enemy.global_position
				d.y = 0.0
				var label := "inside" if stage == 1 else "on top"
				print("%s: stacked for %d frames, apart by %.2f m" % [label, stacked_frames, d.length()])
				check(not lvl.stacked(player, enemy), "%s: pushed apart after 2 seconds" % label)
				check(d.length() >= player.radius + enemy.radius - 0.1, "%s: both stand on their own spot" % label)
				check(hits_while_stacked == 0, "%s: no blows while stacked" % label)
				check(stacked_frames < 60, "%s: pushed apart within a second" % label)
				stage += 1
		_:
			_finish()
			return true
	return false
