extends SceneTree
## Headless test for the warm-up at the start of a level (LevelWarmup):
## right after a level is loaded nothing in it is culled and time stands
## still, so every shader is built in the first, dark frame and that wait
## does not make the fade-in or the hero jump. A frame later culling and
## time are back to normal. Also: a second load right away does not leave
## anything with the warm-up margin.
## Run with: godot --headless -s tests/level_warmup.gd

var failures := 0
var game: Node
var frames := 0
var phase := 0
var margins := {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _geometry(node: Node, out: Array) -> Array:
	if node is GeometryInstance3D:
		out.append(node)
	for child in node.get_children():
		_geometry(child, out)
	return out


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match phase:
		0:
			# The margins every object had before the warm-up, by its path.
			game.load_level(1)
			LevelWarmup.finish()
			for g in _geometry(game.level, []):
				margins[game.level.get_path_to(g)] = g.extra_cull_margin
			game.load_level(1)
			var all: Array = _geometry(game.level, [])
			check(not all.is_empty(), "the level has something to draw")
			check(LevelWarmup.active(), "the warm-up runs right after the load")
			check(all.all(func(g): return g.extra_cull_margin == LevelWarmup.MARGIN), "nothing in the new level is culled in its first frame")
			check(Engine.time_scale == 0.0, "time stands still for the first frame")
			phase = 1
		1, 2:
			phase += 1
		3:
			check(not LevelWarmup.active(), "the warm-up is over after a frame or two")
			check(Engine.time_scale == 1.0, "time runs again")
			var wrong := 0
			for g in _geometry(game.level, []):
				var path: NodePath = game.level.get_path_to(g)
				if margins.has(path) and g.extra_cull_margin != margins[path]:
					wrong += 1
			check(wrong == 0, "every object has its own cull margin back (%d differ)" % wrong)
			check(_geometry(game.level, []).all(func(g): return not g.has_meta(LevelWarmup.KEY)), "no object keeps the warm-up mark")
			# Two loads in a row: the first level's objects are gone, the
			# second one's are warmed and handed back all the same.
			game.load_level(0)
			game.load_level(2)
			phase = 4
		4, 5:
			phase += 1
		6:
			check(Engine.time_scale == 1.0, "time runs again after two loads in a row")
			check(_geometry(game.level, []).all(func(g): return g.extra_cull_margin != LevelWarmup.MARGIN or g is Fog), "no object of the second level keeps the warm-up margin")
			game.delete_save(game.save_path())
			if failures == 0:
				print("PASS: level warm-up")
			else:
				print("FAILED: ", failures)
			quit(1 if failures > 0 else 0)
			return true
	return false
