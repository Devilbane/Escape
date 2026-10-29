extends SceneTree
## Headless smoke test: plays every level by walking to the key, the door and
## the exit. Run with: godot --headless -s tests/play_all_levels.gd

var game: Node
var step := 0
var timer := 0.0
var total := 0.0
var levels_done := 0


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _target(ch: String) -> Vector3:
	var lvl: Level = game.level
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) == ch:
				return lvl.cell_to_world(Vector2i(x, y))
	return Vector3.INF


func _process(delta: float) -> bool:
	total += delta
	timer += delta
	if total > 240.0:
		print("FAIL: timeout at level ", game.level_index + 1, " step ", step)
		return true
	if game.state == game.State.TITLE:
		game._start_playing()
		return false
	if game.state == game.State.WON:
		print("PASS: all ", game.level_files.size(), " levels finished, gold ", game.coins)
		return true
	if game.state != game.State.PLAYING or not game.player.controllable:
		return false
	var player: Player = game.player
	if timer < 0.5 or not player.path.is_empty():
		return false
	timer = 0.0
	match step:
		0:
			player.walk_to(_target("K"))
			step = 1
		1:
			if not game.level.has_key:
				print("  level ", game.level_index + 1, ": key not reached, retrying")
				step = 0
			else:
				print("  level ", game.level_index + 1, ": key collected")
				player.walk_to(_target("E"))
				step = 2
		2:
			player.walk_to(_target("E"))
	if game.level_index > levels_done:
		levels_done = game.level_index
		print("  reached level ", levels_done + 1)
		step = 0
	return false
