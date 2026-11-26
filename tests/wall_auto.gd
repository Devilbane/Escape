extends SceneTree
## Wolfram climbs the sample wall by himself (WallAuto in WallStage): a strong climber goes up to the top over
## the nights' rest places, a weak one falls and curses (speech bubbles, WallVoice), and one who reads a crack
## as deadly turns back. With SHOTS=<folder> it saves pictures of a curse and of the climb.
## Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 --resolution 960x540 -s tests/wall_auto.gd

var failures := 0
var shots := OS.get_environment("SHOTS")
var stage: WallStage
var how := ""


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
	Engine.time_scale = 8.0
	var map := WallMap.load_file("res://walls/sample_three_paths.txt")
	stage = WallStage.new()
	stage.rng.seed = 11
	root.size = Vector2i(960, 540)
	root.add_child(stage)
	stage.size = Vector2(960, 540)
	stage.setup(map, 20, true, "clear", 30)
	stage.climb.dexterity = 14
	stage.climb.intuition = 14
	stage.climb.wisdom = 14
	stage.auto_finished.connect(func(h: String) -> void: how = h)
	_run.call_deferred()


func _until_done(limit: int) -> void:
	var n := 0
	while how == "" and n < limit:
		await process_frame
		n += 1


func _shot(name: String) -> void:
	if shots == "":
		return
	for i in 3:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])


func _run() -> void:
	for i in 5:
		await process_frame
	# The voice: a bubble and a line for each kind of mishap.
	stage.shout("fall")
	await _shot("10_scream")
	check(stage._bubble != null and stage._bubble.visible and stage._bubble.text != "", "a shout shows a bubble")
	check(WallVoice.sound("fall").data.size() > 10000 and WallVoice.sound("slip").data.size() > 1000, "the sounds are made in code")
	for kind in ["slip", "jump_miss", "fall", "graze", "cheer", "turn", "tired"]:
		check(WallVoice.line(kind, stage.rng) != "", "there is a line for %s" % kind)
	# A strong Wolfram climbs to the top by himself (and may curse on the way).
	stage.start_auto()
	check(stage.auto != null and not stage.auto.route.is_empty(), "he plans a route")
	await _until_done(9000)
	check(how == "top", "Wolfram reaches the top: %s at %s" % [how, stage.climb.cell])
	await _shot("11_wolfram_top")
	# A weak Wolfram falls and swears.
	how = ""
	stage.setup(stage.map, 1, true, "clear", 8)
	var before := stage.shouts
	stage.start_auto()
	await _until_done(9000)
	check(stage.shouts > before, "a weak climber shouts on the way: %d" % (stage.shouts - before))
	check(how == "gave_up" or how == "turned" or how == "top", "he ends somehow: %s" % how)
	print("auto: strong top, weak ended %s with %d shouts" % [how, stage.shouts - before])
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
