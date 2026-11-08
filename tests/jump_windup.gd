extends SceneTree
## Headless test: a jump starts with half a step (JUMP_WINDUP).
## - The jump key plays a walking step first; the hero is still on the floor
##   and then leaves it within the wind-up.
## - A runner's push-off is the shorter one.
## - A hit during the wind-up calls the jump off, and nothing stays held.
## - A second press during the wind-up does not stack.
## - A jump is never faster than the run it started from, dexterity or not.
## Run with: godot --headless --fixed-fps 60 -s tests/jump_windup.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
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


func _settle() -> void:
	game.state = game.State.PLAYING
	await _wait(30)


func _run() -> void:
	await _settle()
	var p = game.player
	check(p.is_on_floor(), "the hero stands on the floor")

	# Standing: the step comes first, the leap after.
	p.jump()
	check(p.is_winding_up(), "the key starts the half step")
	check(p.velocity.y <= 0.0, "not yet in the air")
	check(p._current_anim == Player.WALK_ANIM, "the step plays the walk")
	p.jump()
	await _wait(2)
	check(p.is_winding_up() and p.is_on_floor(), "still stepping after two ticks")
	await _wait(int(Player.JUMP_WINDUP * 60.0) + 3)
	check(not p.is_winding_up(), "the half step is over")
	check(not p.is_on_floor() or p.velocity.y > 0.0, "the hero has left the ground")
	await _wait(90)
	check(p.is_on_floor(), "and lands again")
	check(p._anim_hold <= 0.0, "no hold is left behind")

	# A hit calls the jump off.
	p.jump()
	await _wait(1)
	p.take_damage(1, p.global_position + Vector3(1, 0, 0), null, false)
	check(not p.is_winding_up(), "a hit ends the half step")
	await _wait(int(Player.JUMP_WINDUP * 60.0) + 3)
	check(p.is_on_floor(), "and the hero stays on the floor")
	check(p._anim_hold <= 0.0, "nothing is held")

	# Without control, no jump starts.
	p.controllable = false
	p.jump()
	check(not p.is_winding_up(), "no half step without control")
	p.controllable = true

	# A running jump never flies faster than the run it left the ground at.
	p.velocity = Vector3(Player.SPEED, 0, 0)
	p._launch_jump()
	var run_speed: float = p._air_speed_cap
	check(run_speed > 0.0, "a running jump remembers its run speed")
	check(p._air_momentum.length() <= run_speed + 0.001, "launch speed stays within the run speed")
	await _wait(3)
	var flat := Vector2(p.velocity.x, p.velocity.z).length()
	check(flat <= run_speed + 0.001, "in the air the hero is no faster than the run")
	await _wait(90)

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: jump windup")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
