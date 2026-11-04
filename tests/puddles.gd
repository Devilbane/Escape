extends SceneTree
## Headless test for the rain puddles above ground (see Puddles): they lie on
## open grass, path or square, fill up while it rains, stay a while after
## the rain and then dry up, the small ones first; the water level goes into
## the saved game and dries overnight; and a step into a puddle splashes.
## Run with: godot --headless --fixed-fps 60 -s tests/puddles.gd

var failures := 0
var game: Node
var frames := 0
var _splash_at := -1
var _drops_before := 0
const HERO := "Puddle test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(9)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: puddles")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if _splash_at < 0:
		_dry_ground()
		_rain_fills()
		_they_stay_then_dry()
		_saving()
		_step_in()
		_splash_at = frames
		return false
	# Let the hero settle on the ground first.
	if frames < _splash_at + 60:
		return false
	_splashed()
	_finish()
	return true


func _puddles() -> Puddles:
	return game.level.puddles


func _shown() -> int:
	return _puddles().spots.filter(func(s: Dictionary) -> bool: return (s.node as Node3D).visible).size()


func _tick(seconds: float) -> void:
	game._tick_clock(seconds)


func _dry_ground() -> void:
	game.hero_name = HERO
	game.state = game.State.PLAYING
	game.day_hour = 12.0
	game.set_weather(Weather.CLEAR, 8.0)
	game.puddle_water = 0.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	_tick(1.0)
	check(game.level is Outdoor and _puddles() != null, "the open air has its puddles")
	check(_puddles().spots.size() >= 20, "there are plenty of hollows for puddles (%d)" % _puddles().spots.size())
	for s in _puddles().spots:
		var c: Vector2i = game.level.world_to_cell(s.at)
		check(Puddles.GROUND.contains(game.level.cell_char(c)), "a puddle lies on grass, path or square")
		check(float(s.radius) >= Puddles.RADIUS.x * 0.99, "a puddle is a large one")
	check(_shown() == 0, "no puddles on a dry day")
	check(not game.level.in_puddle(_puddles().spots[0].at), "nothing splashes on dry ground")


func _rain_fills() -> void:
	game.set_weather(Weather.RAIN, 8.0)
	_tick(10.0)
	var early := _shown()
	check(game.puddle_water > 0.0 and game.puddle_water < 1.0, "the puddles fill up while it rains")
	_tick(60.0)
	check(is_equal_approx(game.puddle_water, 1.0), "an hour of rain fills the puddles")
	check(_shown() == _puddles().spots.size(), "every hollow has a puddle in the rain")
	check(early < _shown(), "the big puddles come first, then the small ones")
	var s: Dictionary = _puddles().spots[0]
	check(game.level.in_puddle(s.at), "the middle of a puddle is wet")
	check(not game.level.in_puddle(s.at + Vector3(s.radius * 2.0, 0, 0)), "beside a puddle is dry")
	check(not game.level.in_puddle(s.at + Vector3(0, 1.0, 0)), "up on a crate the hero is out of the puddle")
	check(ResourceLoader.exists("res://assets/sounds/splash_0.wav"), "there is a splash sound")


func _they_stay_then_dry() -> void:
	game.set_weather(Weather.CLEAR, 8.0)
	# An hour after the rain the puddles are still there.
	_tick(DayNight.DAY_LENGTH / 24.0)
	check(game.puddle_water > 0.6, "the puddles stay a while after the rain")
	check(_shown() > _puddles().spots.size() / 2, "most puddles are still there an hour after the rain")
	var sizes := _puddles().spots.map(func(s: Dictionary) -> float: return (s.node as Node3D).scale.x)
	check(sizes.max() < 1.0, "the puddles shrink as they dry")
	_tick(DayNight.DAY_LENGTH / 24.0 * 1.3)
	var mid := _shown()
	var big_left := true
	for s in _puddles().spots:
		if (s.node as Node3D).visible:
			continue
		# A dried-up puddle may not be bigger than one still there.
		for other in _puddles().spots:
			if (other.node as Node3D).visible and float(other.radius) < float(s.radius) - 0.25:
				big_left = false
	check(mid < _puddles().spots.size(), "the small puddles dry up first")
	check(big_left, "the big puddles last longest")
	_tick(DayNight.DAY_LENGTH / 24.0 * 1.0)
	check(is_zero_approx(game.puddle_water) and _shown() == 0, "three hours after the rain the ground is dry")


func _saving() -> void:
	game.set_weather(Weather.STORM, 8.0)
	_tick(15.0)
	check(game.puddle_water > 0.4, "a storm fills the puddles fast")
	var level: float = game.puddle_water
	check(game.save_game(), "the game is saved")
	var data: Dictionary = game._read_save(game.save_path())
	check(is_equal_approx(float(data.get("puddles", -1.0)), level), "the saved game holds the puddles")
	game.puddle_water = 0.0
	game._apply_save(data)
	check(is_equal_approx(game.puddle_water, level), "loading brings the puddles back")
	data.erase("puddles")
	game._apply_save(data)
	check(is_zero_approx(game.puddle_water), "an older saved game has dry ground")
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	game.set_weather(Weather.RAIN, 8.0)
	_tick(80.0)


## The hero runs east through the biggest puddle.
func _step_in() -> void:
	var biggest: Dictionary = _puddles().spots[0]
	for s in _puddles().spots:
		if float(s.radius) > float(biggest.radius):
			biggest = s
	var p: Player = game.player
	p.global_position = Vector3(biggest.at.x, 0.05, biggest.at.z)
	p.reset_physics_interpolation()
	p.play("Running_A")
	_drops_before = _drops()


func _drops() -> int:
	var n := 0
	for child in _puddles().get_children():
		if child is CPUParticles3D:
			n += 1
	return n


func _splashed() -> void:
	var p: Player = game.player
	check(game.level.in_puddle(p.global_position), "the hero stands in the puddle")
	# A few footfalls of the run, right in the puddle.
	p.play("Running_A")
	var length: float = p._anim.current_animation_length
	for landing in [0.17, 0.67]:
		p._last_phase = landing - 0.05
		p._anim.seek(length * (landing + 0.03), true)
		p._footsteps(5.0)
	check(_drops() > _drops_before, "a step into a puddle throws up a splash")
