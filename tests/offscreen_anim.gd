extends SceneTree
## Headless test for OffscreenAnim: out of view, a body's animation player is
## driven by hand and steps only every few ticks, but over time it gets just as
## far as one that runs every frame; back in view it gets its own callback mode
## back. A player already driven by hand (a pet's) is left alone. Also: the
## village's villagers, monsters and animals all carry one.
## Run with: godot --headless --fixed-fps 60 -s tests/offscreen_anim.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _body(manual := false) -> Array:
	var body := Node3D.new()
	var player := AnimationPlayer.new()
	body.add_child(player)
	var anim := Animation.new()
	anim.length = 100.0
	var lib := AnimationLibrary.new()
	lib.add_animation(&"walk", anim)
	player.add_animation_library(&"", lib)
	if manual:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	root.add_child(body)
	player.play(&"walk")
	var watch := OffscreenAnim.watch(body)
	return [body, player, watch]


func _initialize() -> void:
	_run()


func _run() -> void:
	await _ticks(2)
	var made := _body()
	var player: AnimationPlayer = made[1]
	var watch: OffscreenAnim = made[2]
	var mode := player.callback_mode_process
	check(not watch.resting(), "nothing changes on its own while headless")
	watch.rest()
	check(watch.resting(), "out of view it rests")
	check(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "out of view the player is driven by hand")
	var at := player.current_animation_position
	await _ticks(OffscreenAnim.EVERY - 2)
	check(is_equal_approx(player.current_animation_position, at), "between steps the pose stands still")
	await _ticks(OffscreenAnim.EVERY * 10 + 2)
	var tick := 1.0 / Engine.physics_ticks_per_second
	var gone := player.current_animation_position - at
	check(gone >= tick * OffscreenAnim.EVERY * 10 - 0.001, "in steps it gets as far as every frame would (%.3f s)" % gone)
	watch.wake()
	check(not watch.resting(), "back in view it runs every frame")
	check(player.callback_mode_process == mode, "back in view the player gets its own mode back")
	at = player.current_animation_position
	await process_frame
	await process_frame
	check(player.current_animation_position > at, "back in view it moves on every frame")

	var pet := _body(true)
	(pet[2] as OffscreenAnim).rest()
	check(not (pet[2] as OffscreenAnim).resting(), "a player driven by hand is left alone")

	# Everyone that walks about in the village carries one.
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.load_level(10)
	await _ticks(10)
	var missing := 0
	var seen := 0
	for body in game.level.find_children("*", "", true, false):
		if body is Enemy or body is Villager or body is Animal or body is FarmAnimal:
			seen += 1
			if body.get_node_or_null("OffscreenAnim") == null:
				missing += 1
	check(seen > 10 and missing == 0, "every villager, monster and animal is watched (%d of %d missing)" % [missing, seen])
	game.delete_save(game.save_path())

	if failures == 0:
		print("PASS: off-screen animations")
	quit(1 if failures > 0 else 0)
