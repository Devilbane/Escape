extends SceneTree
## Headless test for a thunderstorm while the hero builds a house with a cellar: lightning
## strikes the hero again and again while the house is redrawn every frame (which rebuilds
## the ground's floor slabs, see Outdoor.set_floor_holes). Nothing may call into a freed node:
## a release build crashes on that (the glow's one-shot sparks freed themselves before the
## glow ended), so no error may be logged, and the glow's light and sparks are gone after.
## Run with: godot --headless --fixed-fps 60 -s tests/storm_build.gd

const STRIKE_EVERY := 25
const LAST_FRAME := 5 + 60 * 4

var failures := 0
var game: Node
var frames := 0
var plan: HouseSketch
var errors := ErrorCounter.new()
## The hero's own lights (lantern and such), there before the storm.
var own_lights: Array = []


class ErrorCounter extends Logger:
	var seen: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		seen.append("%s (%s:%d %s) %s" % [code, file, line, function, rationale])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _start() -> void:
	game.hero_name = "Storm build test"
	game.escaped = true
	game.day_hour = 12.0
	game.set_weather(Weather.STORM, 4.0)
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var found := Rect2i()
	for y in range(game.level.height - 4):
		for x in range(game.level.grid[y].length() - 4):
			var r := Rect2i(x, y, 3, 3)
			if Plots.problem(game.level, r) == "":
				found = r
				break
		if found.size != Vector2i.ZERO:
			break
	Plots.register(game.level, game.hero_name, found)
	game.plot_marker.refresh()
	plan = game.house_sketcher.plan
	plan.deposit("steinblock", 20)
	plan.deposit("bauholz", 10)
	plan.sketch_dig(plan.cells_between(Vector2i(3, 3), Vector2i(4, 4)))
	plan.sketch_stairs(1, 3, "e")
	plan.ordered = true
	for i in 8:
		game.house_sketcher.work_once()
	# The hero stands beside the dug cellar, where the builder would.
	game.player.global_position = plan.cell_world(0, 0)
	game.player.reset_physics_interpolation()
	own_lights = game.player.find_children("*", "OmniLight3D", true, false)
	OS.add_logger(errors)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if frames == 5:
		_start()
		return false
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	if frames < LAST_FRAME:
		# Building: every placed piece redraws the house and its floor slabs.
		game.house_sketcher._redraw()
		# The test strikes on its own beat: the storm's own random strokes would land in the quiet end.
		lvl._strike_timer = 1000.0
		if frames % STRIKE_EVERY == 0 and frames < LAST_FRAME - 200:
			hero.hp = hero.max_hp
			hero._invulnerable = 0.0
			LightningStrike.hit(lvl, hero.global_position, hero)
			lvl.strike()
		return false
	OS.remove_logger(errors)
	for e in errors.seen:
		print("  logged: ", e)
	check(errors.seen.is_empty(), "nothing calls into a freed node during the storm (%d errors)" % errors.seen.size())
	check(not hero.dead, "the hero lives through it")
	# The last stroke was a while ago (> GLOW_TIME): its light and sparks are gone again.
	var lights := hero.find_children("*", "OmniLight3D", true, false).filter(
		func(l): return not own_lights.has(l) and not (l.get_parent() is StruckAfterglow))
	check(lights.is_empty(), "the glow's light goes out (%d left)" % lights.size())
	var slabs: Node = lvl._floor_slabs
	check(slabs.get_child_count() > 0, "the ground around the cellar still has its slabs")
	print("PASS: storm build" if failures == 0 else "FAILED: %d" % failures)
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
	return true
