extends SceneTree
## Headless test: every doorway lets the hero walk straight through.
## - The bank's built door (HouseSketcher): a hero walking at the doorway within 0.15 m of its middle
##   goes through without being pushed sideways by the frame, and ends up inside.
## - The doorway is clearly wider than the hero (a built door and a village house door, see
##   HouseSketcher.DOOR_JAMB and WalkIn.DOOR_GAP), so the frame never catches them.
## Run with: godot --headless --fixed-fps 60 -s tests/door_walk_straight.gd

const HERO_WIDTH := 1.1
const SPARE := 0.15

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
	else:
		print("ok   ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	Bank.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	check(HouseSketch.CELL - 2.0 * HouseSketcher.DOOR_JAMB >= HERO_WIDTH + 2.0 * SPARE, "a built doorway is wider than the hero with room to spare")
	check(WalkIn.DOOR_GAP >= HERO_WIDTH + 2.0 * SPARE, "a village house's doorway is wider than the hero with room to spare")
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Door walker"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	for i in 10:
		await process_frame
	var hero: Player = game.player
	var cell := BankVault.sketch().cell_world(BankVault.door_cell().x, BankVault.door_cell().y)
	# The middle of the doorway: the door's blocker stands there.
	var mid := cell + Vector3(0, 0, -1.0)
	for dx: float in [0.0, 0.15, -0.15]:
		hero.global_position = mid + Vector3(dx, 0.1, -3.0)
		hero.reset_physics_interpolation()
		for i in 5:
			await physics_frame
		var target := mid + Vector3(dx, 0, 3.0)
		var drift := 0.0
		for i in 160:
			hero.path.clear()
			hero.path.append(target)
			await physics_frame
			if absf(hero.global_position.z - mid.z) < 1.5:
				drift = maxf(drift, absf(hero.global_position.x - mid.x - dx))
			if Vector2(hero.global_position.x - target.x, hero.global_position.z - target.z).length() < 0.3:
				break
		check(hero.global_position.z > mid.z + 1.0, "walking at the bank door %.2f m off its middle gets the hero inside" % dx)
		check(drift < 0.03, "and the frame does not push them sideways (%.3f m)" % drift)
	if failures == 0:
		print("PASS: door walk straight")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
