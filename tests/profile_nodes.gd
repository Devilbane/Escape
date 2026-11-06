extends SceneTree
## Profiling helper (not a pass/fail test): times each script's _process and
## _physics_process on a level (the village by default) by calling it once
## more per frame, summed by script, with the slowest single call.
## Run with: godot --headless --fixed-fps 60 -s tests/profile_nodes.gd [-- hour level]

var game: Node
var frames := 0
var cost := {}
var count := {}
var worst := {}
var hour := 12.0
var lvl := 10

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1: hour = float(args[0])
	if args.size() >= 2: lvl = int(args[1])
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)

func _walk(n: Node, out: Array) -> void:
	if n.get_script() != null and (n.is_processing() or n.is_physics_processing()) and n.can_process():
		out.append(n)
	for c in n.get_children():
		_walk(c, out)

func _process(delta: float) -> bool:
	frames += 1
	if frames == 5:
		game.load_level(lvl)
		game.day_hour = hour
		game.state = game.State.PLAYING
	if frames < 70:
		return false
	if game.menus.is_open():
		game.menus.close()
	game.player.path.assign([game.player.global_position + Vector3.FORWARD.rotated(Vector3.UP, frames * 0.01) * 3.0])
	var nodes := []
	_walk(root, nodes)
	for n in nodes:
		var key: String = n.get_script().resource_path.get_file()
		if n.is_processing() and n.has_method("_process"):
			var a := Time.get_ticks_usec()
			n._process(delta)
			var k := key + " _process"
			var took := Time.get_ticks_usec() - a
			cost[k] = cost.get(k, 0) + took
			count[k] = count.get(k, 0) + 1
			if took > worst.get(k, 0): worst[k] = took
		if n.is_physics_processing() and n.has_method("_physics_process") and is_instance_valid(n):
			var a := Time.get_ticks_usec()
			n._physics_process(delta)
			var k := key + " _physics_process"
			var took := Time.get_ticks_usec() - a
			cost[k] = cost.get(k, 0) + took
			count[k] = count.get(k, 0) + 1
			if took > worst.get(k, 0): worst[k] = took
	if frames == 70 + 900:
		var keys := cost.keys()
		keys.sort_custom(func(x, y): return cost[x] > cost[y])
		for k in keys.slice(0, 25):
			print("%8.3f ms/frame  worst call %6.2f ms  %-40s (%d nodes)" % [cost[k] / 900.0 / 1000.0, worst[k] / 1000.0, k, count[k] / 900])
		game.delete_save(game.save_path())
		return true
	return false
