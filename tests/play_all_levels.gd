extends SceneTree
## Headless smoke test: plays every level like a (very determined) player.
## It fights skeletons, searches every object, grabs the key and leaves by
## the stairs. Run with: godot --headless -s tests/play_all_levels.gd

var game: Node
var total := 0.0
var timer := 0.0
var searched := 0
var reached := 0


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _cell_of(ch: String) -> Vector3:
	var lvl: Level = game.level
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) == ch:
				return lvl.cell_to_world(Vector2i(x, y))
	return Vector3.INF


func _process(delta: float) -> bool:
	total += delta
	timer += delta
	if total > 400.0:
		print("FAIL: timeout at level ", game.level_index + 1)
		return true
	if game.state == game.State.TITLE:
		game._start_playing()
		return false
	if game.state == game.State.WON:
		print("PASS: all ", game.level_files.size(), " levels finished, gold ", game.coins, ", searched ", searched)
		return true
	if game.level_index > reached:
		reached = game.level_index
		print("  reached level ", reached + 1)
	var player: Player = game.player
	if OS.has_environment("TEST_DEBUG") and int(total * 10) % 50 == 0:
		print("  t=%d lvl=%d pos=%s hp=%d knives=%d path=%d busy=%s state=%d key=%s" % [total, game.level_index + 1, game.level.world_to_cell(player.global_position), player.hp, player.knives, player.path.size(), player.can_act(), game.state, game.level.has_key])
	if game.state != game.State.PLAYING or not player.can_act():
		return false
	var lvl: Level = game.level

	# Fight anything close by.
	for e in lvl.enemies:
		if is_instance_valid(e) and not e.dead and lvl.has_line_of_sight(player.global_position, e.global_position):
			var d := player.global_position.distance_to(e.global_position)
			if d < 2.6:
				player.melee()
				return false
			if d < 14.0:
				if player.knives > 0:
					player.throw_knife()
				else:
					player.walk_to(e.global_position)
				return false

	if timer < 0.4 or not player.path.is_empty():
		return false
	timer = 0.0

	# Search the nearest object that is still closed, then key, then exit.
	var near := lvl.nearest_interactable(player.global_position)
	if not near.is_empty() and not near.searched:
		game._search(near)
		searched += 1
		return false
	for obj in lvl.interactables:
		if not obj.searched:
			var path := lvl.astar.get_id_path(lvl.world_to_cell(player.global_position), obj.cell, true)
			if not path.is_empty() and lvl.cell_to_world(path[-1]).distance_to(obj.pos) <= Level.SEARCH_RANGE:
				player.walk_to(obj.pos)
				return false
	if not lvl.has_key and not lvl._doors.all(func(d): return d.open):
		player.walk_to(_cell_of("K"))
	else:
		player.walk_to(_cell_of("E"))
	return false
