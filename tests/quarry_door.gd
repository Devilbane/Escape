extends SceneTree
## Headless test: the door of the house beside the stonemason's quarry stays reachable
## on foot from the village square (the quarry hill must not wall it in).
## Run with: godot --headless --fixed-fps 60 -s tests/quarry_door.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level
	var mason: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == "S":
			mason = v
	check(mason != null, "the village has its stonemason")
	if mason != null:
		# The tile in front of the door of the house just above him.
		var front := mason.home + Vector2i(-1, -1)
		var square := Vector2i(51, 29)
		check(not lvl.astar.is_point_solid(front), "the tile in front of the door is open")
		var path := lvl.astar.get_id_path(front, square)
		check(path.size() > 0, "the door can be reached on foot from the square")
	print("PASS: quarry door" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
