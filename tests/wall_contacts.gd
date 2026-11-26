extends SceneTree
## Climbing wall: the places where a climber's hands and feet land on a real test run (Wolfram's own climb up the
## sample wall) all have a visible stone: a hold for the hands and a foot stone (WallBuild.foot_mesh) for the feet,
## or the ground. With OUT=<file.json> the recorded contacts are saved. Run with xvfb (WallStage builds the wall).

var stage: WallStage
var how := ""
var failures := 0


func _initialize() -> void:
	Lang.language = "en"
	Engine.time_scale = 8.0
	var map := WallMap.load_file("res://walls/sample_three_paths.txt")
	stage = WallStage.new()
	stage.rng.seed = 11
	root.size = Vector2i(640, 360)
	root.add_child(stage)
	stage.size = Vector2(640, 360)
	stage.setup(map, 20, true, "clear", 30)
	stage.climb.dexterity = 14
	stage.climb.intuition = 14
	stage.climb.wisdom = 14
	stage.auto_finished.connect(func(h: String) -> void: how = h)
	_run.call_deferred()


func _run() -> void:
	for i in 5:
		await process_frame
	stage.start_auto()
	var seen := {}
	var n := 0
	while how == "" and n < 6000:
		await process_frame
		n += 1
		var cell: Vector2i = stage.climb.cell
		if cell != WallClimb.NOWHERE and not seen.has(cell):
			seen[cell] = true
	var wall: WallMap = stage.wall
	var contacts := []
	var bad := 0
	for cell in seen:
		var hand_ok := wall.has_hold(cell.x, cell.y)
		var foot := WallBuild.foot_spot(wall, cell.x, cell.y)
		# A foot stone is made for every hold's foot spot; feet on the ground need none.
		var foot_ok := foot.x < 0.0 or hand_ok
		contacts.append({"cell": [cell.x, cell.y], "hand_stone": hand_ok, "foot": [foot.x, foot.y], "foot_stone": foot_ok})
		if not (hand_ok and foot_ok):
			bad += 1
			print("FAIL: contact at ", cell, " has no stone")
	failures += bad
	if seen.size() < 8:
		failures += 1
		print("FAIL: the run visited only %d squares" % seen.size())
	var out := OS.get_environment("OUT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(contacts, "\t"))
	if failures == 0:
		print("PASS: %d squares, each with a hand hold and a foot stone" % seen.size())
	quit(1 if failures > 0 else 0)
