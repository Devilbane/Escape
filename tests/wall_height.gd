extends SceneTree
## Headless test for the near walls (WallFade): the walls between the camera
## and a room stand at full height on every floor, like every other wall.
## Only the stretch right in front of the hero turns see-through, and it
## turns solid again once the hero walks away.
## Run with: godot --headless --fixed-fps 60 -s tests/wall_height.gd

var failures := 0
var game: Node
var frames := 0
var index := 0
var wait := 0
var floors := 0
var pieces := 0
## The floor whose fading is tried out, and how far along that is.
var tried := false
var step := 0
var front: Node3D
var far: Node3D
var spot := Vector3.ZERO


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	check(floors > 0, "some floors have near walls at all")
	check(tried, "the fading was tried on some floor")
	# From the hero's feet, the line to the camera clears a 4 m wall after
	# about 2.9 m at the usual tilt; close up and low it reaches further, but
	# never past the camera.
	var usual := WallFade.reach_for(deg_to_rad(54.0), 27.0 * sin(deg_to_rad(54.0)))
	check(usual > 3.0 and usual < 4.5, "the usual camera fades walls up to %.1f m ahead" % usual)
	var close := WallFade.reach_for(deg_to_rad(22.0), 7.5 * sin(deg_to_rad(22.0)))
	check(close <= 7.5 * cos(deg_to_rad(22.0)) + WallFade.MARGIN + 0.01, "close up, only walls before the camera fade (%.1f m)" % close)
	if failures == 0:
		print("PASS: wall height (%d near wall pieces on %d floors)" % [pieces, floors])
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _check_level() -> void:
	var lvl: Level = game.level
	var file: String = game.level_files[index]
	var near: Array = lvl._near_walls._pieces
	if near.is_empty():
		return
	floors += 1
	pieces += near.size()
	for p in near:
		var node: Node3D = p.node
		check(is_equal_approx(node.scale.y, 1.0), "%s: a near wall at %s is lowered" % [file, lvl.world_to_cell(node.global_position)])


## Picks a near wall piece facing into a room (a room tile right north
## of it) and one far away from it.
func _pick(lvl: Level) -> bool:
	for p in lvl._near_walls._pieces:
		var node: Node3D = p.node
		if not is_instance_valid(node):
			continue
		var room := lvl.world_to_cell(node.global_position - Vector3(0, 0, Level.TILE * 0.5))
		if "#?".contains(lvl.cell_char(room)) or lvl.astar.is_point_solid(room):
			continue
		spot = lvl.cell_to_world(room)
		front = node
		for q in lvl._near_walls._pieces:
			if is_instance_valid(q.node) and (q.node as Node3D).global_position.distance_to(node.global_position) > 20.0:
				far = q.node
				return true
	return false


## Puts the hero right north of a near wall: that wall fades, a far one
## stays solid; then sends the hero far off and the wall turns solid again.
func _try_fading() -> bool:
	var lvl: Level = game.level
	var hero: Node3D = game.player
	step += 1
	if step == 1:
		if not _pick(lvl):
			step = 0
			return true
		hero.global_position = spot
		hero.reset_physics_interpolation()
	elif step == 30:
		check(lvl._near_walls.is_faded(front), "the near wall in front of the hero turns see-through")
		check(not lvl._near_walls.is_faded(far), "a near wall far from the hero stays solid")
		var amount: float = _amount(lvl, front)
		check(amount > 0.5, "the wall in front of the hero is drawn see-through (%.2f)" % amount)
		hero.global_position = spot + Vector3(0, 0, -3.0 * Level.TILE)
		hero.reset_physics_interpolation()
	elif step == 60:
		check(not lvl._near_walls.is_faded(front), "the wall turns solid again once the hero walks away")
		var amount: float = _amount(lvl, front)
		check(amount < 0.01, "the wall is drawn solid again (%.2f)" % amount)
		tried = true
		return true
	return false


## How far a near wall piece has faded, as its stone shader is told.
func _amount(lvl: Level, node: Node3D) -> float:
	for p in lvl._near_walls._pieces:
		if p.node == node:
			for m in p.meshes:
				if m.stone:
					return (m.mesh as GeometryInstance3D).get_instance_shader_parameter("fade")
			check(false, "the near wall at %s is of rough stone" % lvl.world_to_cell(node.global_position))
	return -1.0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if game.player:
		game.player.hp = game.player.max_hp
	if wait == 0:
		if index >= game.level_files.size():
			_finish()
			return true
		game.hero_name = "Wall test"
		game.load_level(index, false)
		game.state = game.State.PLAYING
	wait += 1
	if wait == 3:
		_check_level()
	if wait >= 3 and not tried and step >= 0:
		if not _try_fading():
			return false
	if wait >= 3:
		index += 1
		wait = 0
	return false
