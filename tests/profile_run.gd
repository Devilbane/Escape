extends SceneTree
## Profiling helper (not a pass/fail test): lets the hero run in circles on a
## dungeon level and in the village, by day and by night, and prints how long
## the scripts take per frame and how many objects are made per second.
## Run with: godot --headless --fixed-fps 60 -s tests/profile_run.gd

var game: Node
var frames := 0
var phase := 0
var t := 0.0
var samples: Array[float] = []
var phys: Array[float] = []
var objects_at := 0
var resources_at := 0
var cases := []
var _last_us := 0


func _initialize() -> void:
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	cases = [[1, 12.0], [5, 12.0], [10, 12.0], [10, 23.5]]


func _process(delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if phase >= cases.size() * 2:
		game.delete_save(game.save_path())
		return true
	var c: Array = cases[phase / 2]
	if phase % 2 == 0:
		game.load_level(c[0])
		game.day_hour = c[1]
		game.state = game.State.PLAYING
		t = 0.0
		samples.clear()
		phys.clear()
		phase += 1
		return false
	t += delta
	if game.menus.is_open():
		game.menus.close()
	if t < 1.0:
		_last_us = Time.get_ticks_usec()
		objects_at = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		resources_at = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		return false
	game.player.path.assign([game.player.global_position + Vector3.FORWARD.rotated(Vector3.UP, t * 0.8) * 3.0])
	var now := Time.get_ticks_usec()
	samples.append((now - _last_us) / 1000.0)
	_last_us = now
	phys.append(Performance.get_monitor(Performance.OBJECT_COUNT))
	if t > 9.0:
		game.player.path.clear()
		samples.sort()
		phys.sort()
		var objs := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects_at
		var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) - resources_at
		print("%-24s clock %4.1f  frame ms median %.2f p95 %.2f p99 %.2f max %.2f | objects +%d resources +%d (8 s)" % [
			game.level.level_name, c[1],
			samples[samples.size() / 2], samples[int(samples.size() * 0.95)], samples[int(samples.size() * 0.99)], samples[-1], objs, res])
		phase += 1
	return false
