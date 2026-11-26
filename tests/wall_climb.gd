extends SceneTree
## The mountaineer climbs the sample wall (see WallStage, WallClimb, WallWeather): up the scree path and across
## to the chimney over a 2 m crack (a traverse and a jump), up the chimney with its ice, across a 3 m crack
## to the overhang, and on to the summit, with the nails and the rope on the way. Then a slip on the ice, rain
## and a storm that change the wall under the climber, a stone from above that knocks them off, and the same
## stone with the climber braced against the rock, and the cloud band that fills the foot of the view once the
## climber is high. With SHOTS=<folder> it saves pictures of the key moments.
## Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --resolution 960x540 -s tests/wall_climb.gd

const SHOTS_SPEED := 4.0
var failures := 0
var shots := OS.get_environment("SHOTS")
var stage: WallStage
var map: WallMap
var jumps := 0
var traverses := 0
var nails_set := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
	Engine.time_scale = SHOTS_SPEED
	map = WallMap.load_file("res://walls/sample_three_paths.txt")
	stage = WallStage.new()
	stage.rng.seed = 5
	stage.setup(map, 20, true)
	root.size = Vector2i(960, 540)
	root.add_child(stage)
	stage.size = Vector2(960, 540)
	_run.call_deferred()


func _wait_idle() -> void:
	var guard := 0
	while stage.busy() and guard < 2000:
		await process_frame
		guard += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await _frames(3)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])


## One sure move: the hands hold (roll 0) and nothing falls.
func _go(dir: int, times := 1) -> void:
	for i in times:
		await _wait_idle()
		# The breath is tested in tests/wall_map.gd: here the climber is always fresh.
		stage.climb.stamina = stage.climb.stamina_max
		stage.climb.clock = 10.0
		var mv := stage.climb.move_in(dir)
		var out := stage.try_move(dir, 0.0, 1.0)
		check(out != WallClimb.Outcome.BLOCKED, "move %d from %s is open" % [dir, stage.climb.cell])
		if not mv.is_empty() and mv.kind == "jump":
			jumps += 1
		elif dir == WallMap.LEFT or dir == WallMap.RIGHT:
			traverses += 1
		if out == WallClimb.Outcome.NAILED:
			nails_set += 1


func _run() -> void:
	await _frames(5)
	await _shot("00_foot")
	# The scree path, then along row 17 (a traverse), the 2 m crack (a jump) and into the chimney.
	await _go(WallMap.UP, 7)
	check(stage.climb.cell == Vector2i(2, 17), "scree path to (2,17): %s" % stage.climb.cell)
	await _go(WallMap.RIGHT, 5)
	await _wait_idle()
	# The first push at the crack is a look (the eye rolls), the climber stays put.
	check(stage.step(WallMap.RIGHT) == WallClimb.Outcome.BLOCKED and stage.climb.cell == Vector2i(7, 17), "the first push at a crack only judges it")
	await _frames(3)
	await _shot("01_before_jump")
	check(stage.climb.cell == Vector2i(7, 17), "to the crack's edge: %s" % stage.climb.cell)
	await _go(WallMap.RIGHT)
	await _wait_idle()
	check(stage.climb.cell == Vector2i(10, 17), "jumped the crack to %s" % stage.climb.cell)
	await _shot("02_after_jump")
	await _go(WallMap.RIGHT)
	await _go(WallMap.UP, 3)
	await _wait_idle()
	await _shot("03_chimney")
	check(nails_set >= 2, "nails set on the way: %d" % nails_set)
	check(stage.climb.nails.size() == nails_set, "the climber's nails match")
	await _go(WallMap.LEFT)
	await _go(WallMap.UP, 3)
	# The 3 m crack at row 11: from (13,11) to (17,11).
	await _go(WallMap.RIGHT, 3)
	await _wait_idle()
	check(stage.climb.cell == Vector2i(13, 11), "to the 3 m crack: %s" % stage.climb.cell)
	await _go(WallMap.RIGHT)
	await _wait_idle()
	check(stage.climb.cell == Vector2i(17, 11), "jumped the 3 m crack: %s" % stage.climb.cell)
	await _shot("04_high_clouds")
	check(jumps == 2, "two jumps: %d" % jumps)
	check(traverses >= 8, "traverses along the face: %d" % traverses)
	await _go(WallMap.RIGHT)
	await _go(WallMap.UP, 7)
	await _wait_idle()
	await _shot("05_near_top")
	await _go(WallMap.UP, 4)
	await _wait_idle()
	await _frames(3)
	check(stage.climb.cell.y == 0, "on the top row: %s" % stage.climb.cell)
	check(stage._cloud_density > 0.5, "cloud band fills the foot of the view up here: %.2f" % stage._cloud_density)
	await _shot("06_summit")
	# Night on the wall: darker, and a rest place lets the climber sleep until dawn.
	stage.climb.clock = 22.0
	stage._update_status()
	await _frames(3)
	await _shot("09_night")
	check(stage.climb.darkness() == 2 and stage._sun.light_energy < 0.5, "night dims the light")
	stage.climb.cell = Vector2i(5, 13)
	stage.climb.stamina = 1.0
	check(stage.rest_here() == WallClimb.Outcome.CAMPED and stage.climb.stamina == stage.climb.stamina_max and stage.climb.darkness() == 0, "the rest place lets the climber sleep until morning")

	# A new climb: the ice makes a good hand fail, and a failure on a surface is a fall.
	stage.setup(map, 20, true)
	await _frames(3)
	await _go(WallMap.UP, 1)
	await _go(WallMap.UP, 5)
	var ice_cell := Vector2i(11, 18)
	check(stage.wall.hazard_at(ice_cell.x, ice_cell.y) == WallMap.ICE, "ice in the chimney")
	var chance := WallRules.step_chance(stage.wall, ice_cell.x, ice_cell.y, 99)
	check(chance <= 0.95 * (1.0 - WallRules.risk(WallMap.ICE)) + 0.0001 and chance < 0.8, "ice keeps its risk even at skill 99: %.2f" % chance)

	# Weather: rain makes the hold harder, a storm adds jumps' difficulty, the cold lays ice on the wall.
	stage.setup(map, 20, true)
	await _frames(3)
	var plain := WallRules.step_chance(map, 11, 22, 20)
	stage.set_weather(WallWeather.RAIN)
	check(WallRules.step_chance(stage.wall, 11, 22, 20, WallWeather.RAIN) < plain, "rain lowers the chance")
	stage.set_weather(WallWeather.SNOW)
	var iced := 0
	for r in stage.wall.height:
		for c in stage.wall.width:
			if stage.wall.hazard_at(c, r) == WallMap.ICE and map.hazard_at(c, r) != WallMap.ICE:
				iced += 1
	check(iced > 20, "the cold adds ice squares: %d" % iced)
	await _shot("07_snow")
	stage.set_weather(WallWeather.STORM)
	check(WallRules.jump_required(stage.wall, 2, WallWeather.STORM) > WallRules.jump_required(stage.wall, 2), "a storm asks more of a jump")
	await _frames(3)

	# A stone from above: the dust comes first, then the stone; unbraced it knocks the climber off.
	stage.setup(map, 20, true, WallWeather.STORM)
	stage.size = Vector2(960, 540)
	await _frames(3)
	stage._fall_timer = 99999.0
	await _go(WallMap.UP, 4)
	await _wait_idle()
	stage.rng.seed = 11
	var hp := [0]
	stage.hurt.connect(func(n: int) -> void: hp[0] += n)
	stage.start_rockfall(stage.feet.x)
	check(stage.stones.size() == 1 and not stage.stones[0].node.visible, "a warning first: the stone is not in view yet")
	await _frames(20)
	await _shot("08_rockfall_warning")
	var cell_before: Vector2i = stage.climb.cell
	var guard := 0
	while not stage.stones.is_empty() and guard < 900:
		await process_frame
		guard += 1
		if guard == 60:
			await _shot("09_stone_falls")
	check(hp[0] > 0, "the stone hurt the climber: %d" % hp[0])
	# The same with the climber braced against the rock.
	await _wait_idle()
	stage.force_brace = true
	var before: int = hp[0]
	var at: Vector2i = stage.climb.cell
	stage.start_rockfall(stage.feet.x)
	guard = 0
	while not stage.stones.is_empty() and guard < 900:
		await process_frame
		guard += 1
	check(hp[0] == before, "braced against the rock the stone does no harm")
	check(stage.climb.cell == at or stage.climb.cell == WallClimb.NOWHERE, "braced climber holds on")
	stage.force_brace = false
	print("climb: jumps=%d traverses=%d nails=%d cell_before=%s" % [jumps, traverses, nails_set, cell_before])
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	Engine.time_scale = 1.0
	quit(1 if failures > 0 else 0)
