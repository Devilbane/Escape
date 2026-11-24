extends SceneTree
## Ladders (HouseSketch.LADDER): one cell against a slab's edge or a pit wall,
## one timber, built after what they lean on; the hero climbs up and down them,
## companions do not (HouseFloors has no way over a ladder).
## Run with: godot --headless --fixed-fps 60 -s tests/house_ladder.gd

var failures := 0
var game: Node
var frames := 0
var plan: HouseSketch
var stage := ""
var waited := 0
var roof_ladder: Node3D
var cellar_ladder: Node3D


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
	else:
		print("  ok: ", what)


func _initialize() -> void:
	WalkIn.lock_halls = false # these tests walk into halls at any hour (see tests/village_halls.gd for the locks)
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	if OS.get_environment("SHOTS") != "":
		Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


## The rules of the plan, without a map.
func _plan_rules() -> void:
	var s := HouseSketch.new()
	s.plot = Rect2i(0, 0, 4, 4)
	check(s.problem_ladder(2, 3, "e", 0) == "no slab", "a ladder needs a slab to lean on")
	s.sketch_roof(s.cells_between(Vector2i(3, 3), Vector2i(4, 4)), HouseSketch.SLAB, 0)
	check(s.problem_ladder(2, 3, "e", 0) == "", "beside a slab a ladder fits")
	check(s.problem_ladder(3, 3, "e", 0) == "taken", "not under the slab itself")
	check(s.ladder_dir(2, 3, 0, Vector2(1, 0)) == "e", "it leans towards the slab")
	check(s.ladder_dir(2, 3, 0, Vector2(-1, 0)) == "e", "whichever edge is nearest the click, if only one fits")
	check(s.ladder_dir(4, 2, 0, Vector2(0, 1)) == "s", "from the north it leans south")
	check(s.sketch_ladder(2, 3, "e", 0), "a ladder is sketched")
	check(s.problem_ladder(2, 3, "s", 0) == "taken", "one ladder per cell")
	check(HouseSketch.cost_of(s.pieces[s.ladder_key(2, 3, 0)]) == {HouseSketch.TIMBER: 1}, "a ladder costs one timber")
	check(s.problem_roof(2, 3, 0) == "taken", "no slab over a ladder's foot")
	check(s.problem_upstairs(1, 3, "e") != "", "no stairs up through a ladder")
	# On the roof: a ladder from the flat roof up to a slab of the upper floor.
	check(s.problem_ladder(3, 3, "e", 1) == "no slab", "up on the roof a ladder needs a slab of the upper floor")
	s.sketch_roof([[4, 3, "c"]], HouseSketch.SLAB, 1)
	check(s.problem_ladder(3, 3, "e", 1) == "", "on the flat roof a ladder leans on the upper floor's slab")
	check(s.problem_ladder(2, 2, "e", 1) == "no roof", "but not in the air")
	# A railing on the edge stops it.
	s.sketch([[3, 4, "y"]], HouseSketch.STONE_FENCE, 1)
	check(s.problem_ladder(2, 4, "e", 0) == "railing", "no ladder through a railing")
	# The cellar: in a dug cell against the pit wall, to ground that is not dug.
	s.sketch_dig(s.cells_between(Vector2i(6, 3), Vector2i(7, 4)))
	check(s.problem_ladder(5, 3, "e", -1) == "no cellar", "in the cellar only in a dug cell")
	check(s.problem_ladder(6, 3, "e", -1) == "no ledge", "not against another dug cell")
	check(s.problem_ladder(6, 3, "w", -1) == "", "against the pit wall a ladder fits")
	check(s.sketch_ladder(6, 3, "w", -1), "a cellar ladder is sketched")
	check(s.problem_cover(6, 3) == "ladder", "no floor over a ladder in the cellar")
	check(s.problem_dig(5, 3) == "taken", "the ground at its top is not dug away")
	check(s.problem_stairs(4, 3, "e") != "", "no stairs down over a ladder's top")
	# Saved and read back.
	s.save("Ladder rules")
	HouseSketch._loaded = false
	var back := HouseSketch.of("Ladder rules", s.plot)
	check(back.count(HouseSketch.LADDER) == 2 and back.ladder_key(6, 3, -1) != "" and back.ladder_key(2, 3, 0) != "", "ladders are kept in the books")
	# Built after what it leans on, and keeps it standing.
	back.deposit(HouseSketch.TIMBER, 20)
	back.deposit(HouseSketch.STONE, 20)
	back.order()
	var order := []
	for i in 30:
		var r := back.build_next()
		if r.is_empty():
			break
		order.append(r.kind)
	check(order.rfind("ladder") > order.find("slab") and order.find("ladder") > order.rfind("dig"), "a ladder is built after its slab and its pit (%s)" % [order])
	check(back.count(HouseSketch.LADDER, HouseSketch.BUILT) == 2, "both ladders are built")
	check(back.erase_above(3, 3, 0) == "ladder needed", "a slab with a ladder against it stays")
	check(back.erase_above(2, 3, 0) == "" and back.pieces[back.ladder_key(2, 3, 0)].state == HouseSketch.DEMOLISH, "the eraser takes the ladder")
	check(back.erase_cell(6, 3) == "" and back.pieces[back.ladder_key(6, 3, -1)].state == HouseSketch.DEMOLISH, "in the cellar the eraser takes the ladder before the cell")
	check(back.erase_cell(6, 3) == "ladder needed", "and the cell stays while the ladder does")


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_plan_rules()
	if frames == 5:
		game.hero_name = "Ladder test"
		game.escaped = true
		game.load_level(game._outdoor_index(), false)
		game.state = game.State.PLAYING
		game.day_hour = 12.0
		game._title.visible = false
		game._fade.color = Color(0.03, 0.015, 0.04, 0.0)
		var found := Rect2i()
		for y in range(game.level.height - 5):
			for x in range(game.level.grid[y].length() - 5):
				var r := Rect2i(x, y, 4, 4)
				if Plots.problem(game.level, r) == "":
					found = r
					break
			if found.size != Vector2i.ZERO:
				break
		check(Plots.register(game.level, game.hero_name, found) == "", "a plot is registered")
		game.plot_marker.refresh()
		plan = game.house_sketcher.plan
		plan.deposit("steinblock", 20)
		plan.deposit("bauholz", 20)
		plan.sketch_roof(plan.cells_between(Vector2i(3, 3), Vector2i(4, 4)), HouseSketch.SLAB, 0)
		plan.sketch_ladder(2, 3, "e", 0)
		plan.sketch_dig(plan.cells_between(Vector2i(6, 1), Vector2i(7, 2)))
		plan.sketch_ladder(6, 1, "w", -1)
		plan.ordered = true
		for i in 20:
			if not game.house_sketcher.work_once():
				break
		check(plan.open_pieces() == 0, "slab, pit and ladders are built (%d left)" % plan.open_pieces())
		game.player.godmode = true
		for e in game.level.enemies:
			if is_instance_valid(e):
				e.queue_free()
		return false
	if frames == 30:
		# (The forgotten mine's ladder stands in its shaft, see LostMine, the sewers' shafts, see Sewers, and the villagers' houses
		# have their own ladders, see WalkIn._furnish_house: not this house's.)
		var ladders: Array = root.get_tree().get_nodes_in_group(Player.LADDER_GROUP).filter(func(l): return not LostMine.holds(l.get_meta("foot")) and not Sewers.holds(l.get_meta("foot")) and l.name != "LadderSpot")
		check(ladders.size() == 2, "two built ladders stand on the map (%d)" % ladders.size())
		for l: Node3D in ladders:
			if (l.get_meta("top") as Vector3).y > 1.0:
				roof_ladder = l
			else:
				cellar_ladder = l
		check(roof_ladder != null and cellar_ladder != null, "one up to the roof, one out of the cellar")
		# The ground floor's ladder fades with its floor (hidden from down in the cellar).
		var rungs := 0
		for part in (roof_ladder.get_parent() as Node3D).get_children():
			if part is MeshInstance3D and part.has_meta("ymin"):
				rungs += 1
		check(rungs > 0, "the ladder up to the roof fades with its floor")
		var floors: HouseFloors = game.level.house_floors
		var pit := plan.cell_world(7, 2) + Vector3(0, -HouseSketch.DEPTH, 0)
		check(floors == null or not floors.reachable(plan.cell_world(0, 0), pit), "a companion finds no way down a ladder")
		_walk_to(roof_ladder)
		stage = "up"
		return false
	if frames < 30:
		return false
	waited += 1
	var hero: Player = game.player
	match stage:
		"up":
			if waited in [60, 120]:
				_shot("ladder_up_%d" % waited)
			if hero.on_ladder() or waited < 20:
				return false
			_hold(Vector3.ZERO)
			var top: Vector3 = roof_ladder.get_meta("top")
			check(absf(hero.global_position.y - top.y) < 0.2, "clicking the ladder the hero climbs onto the roof (y %.2f)" % hero.global_position.y)
			_next("down")
			_walk_into(roof_ladder)
		"down":
			if hero.on_ladder() or waited < 20:
				return false
			_hold(Vector3.ZERO)
			check(absf(hero.global_position.y) < 0.2, "clicking the ladder at the roof edge the hero climbs down (y %.2f)" % hero.global_position.y)
			_walk_to(cellar_ladder)
			_next("out")
		"out":
			if waited in [60]:
				_shot("ladder_cellar_%d" % waited)
			if hero.on_ladder() or waited < 20:
				return false
			_hold(Vector3.ZERO)
			check(absf(hero.global_position.y) < 0.2, "in the cellar the ladder takes the hero up to the ground (y %.2f)" % hero.global_position.y)
			_next("in")
			_walk_into(cellar_ladder)
		"in":
			# (The click walks to the top first if the hero stepped off it: give the climb time to start.)
			if hero.on_ladder() or (waited < 90 and hero.global_position.y > -0.5):
				return false
			_hold(Vector3.ZERO)
			check(absf(hero.global_position.y + HouseSketch.DEPTH) < 0.2, "and back down into the cellar (y %.2f)" % hero.global_position.y)
			_finish()
	if waited > 900:
		check(false, "the climb \"%s\" ended in time" % stage)
		_finish()
	return false


## Puts the hero at the foot of `ladder` and clicks it.
func _walk_to(ladder: Node3D) -> void:
	game.player.global_position = (ladder.get_meta("foot") as Vector3) + Vector3(0, 0.05, 0)
	game.player.reset_physics_interpolation()
	game._snap_camera()
	_click(ladder)


## Climbs `ladder` from where the hero stands at its top (the click's ray is checked in ladder_exit.gd).
func _walk_into(ladder: Node3D) -> void:
	game.player.use_ladder(ladder)


## A click on the ladder's middle, as the camera sees it: the floor point the click picks is where that
## ray meets the floor.
func _click(ladder: Node3D) -> void:
	var edge: Vector3 = ladder.get_meta("edge")
	var mid := Vector3(edge.x, ((ladder.get_meta("foot") as Vector3).y + (ladder.get_meta("top") as Vector3).y) * 0.5, edge.z) - (ladder.get_meta("push") as Vector3) * 0.1
	var from: Vector3 = game.camera.global_position
	var dir := (mid - from).normalized()
	var floor_y: float = game.player.global_position.y
	game._click(from + dir * ((floor_y - from.y) / dir.y))


## Holds the arrow key that walks the hero along `dir` (one of the four flat axes), or lets go.
func _hold(dir: Vector3) -> void:
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(action)
	if dir.x > 0.5:
		Input.action_press("ui_right")
	elif dir.x < -0.5:
		Input.action_press("ui_left")
	elif dir.z > 0.5:
		Input.action_press("ui_down")
	elif dir.z < -0.5:
		Input.action_press("ui_up")


## A screenshot into $SHOTS, when it is set and something is drawn.
func _shot(name: String) -> void:
	var dir := OS.get_environment("SHOTS")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(name + ".png"))


func _next(what: String) -> void:
	stage = what
	waited = 0


func _finish() -> void:
	_hold(Vector3.ZERO)
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: house ladder" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
