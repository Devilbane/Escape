extends SceneTree
## Headless test for the rain puddles above ground (see Puddles): they lie on
## open grass, path or square, fill up while it rains, stay a while after
## the rain and then dry up, the small ones first; there are few, big ones
## (a quarter of those laid, with the same water) and a few small ones between,
## in the dips, in the ruts of the paths and along the houses; the
## water level goes into the saved game and dries overnight; and a step
## into a puddle splashes.
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
	var spots := _puddles().spots
	var laid := _puddles().laid_count
	check(laid >= 400, "many puddles are laid at first (%d)" % laid)
	# A quarter of them is left: fewer, much bigger puddles (the exact share moves a little whenever the map changes).
	check(spots.size() >= 60, "there are still puddles all over (%d)" % spots.size())
	check(spots.size() <= laid * 0.33, "about a quarter of the puddles is left (%d of %d)" % [spots.size(), laid])
	check(spots.size() >= laid * 0.08, "the puddles are not thinned out too far (%d of %d)" % [spots.size(), laid])
	# The same water lies on the ground.
	var area_ratio := _puddles().total_area() / _puddles().laid_area
	check(area_ratio > 0.9 and area_ratio < 1.04, "the water on the ground stays the same (%.3f)" % area_ratio)
	var small := spots.filter(func(s: Dictionary) -> bool: return float(s.radius) <= Puddles.SMALL_RADIUS).size()
	var small_on_walk := 0
	for s in spots:
		if float(s.radius) <= Puddles.SMALL_RADIUS and Puddles.WALKWAY.contains(game.level.cell_char(game.level.world_to_cell(s.at))):
			small_on_walk += 1
	print("puddles: laid %d, left %d, small %d, small on walkways %d, water ratio %.3f" % [laid, spots.size(), small, small_on_walk, _puddles().total_area() / _puddles().laid_area])
	check(small >= 1, "a few small puddles lie about in between (%d)" % small)
	check(small <= spots.size() / 10, "the small puddles are very few (%d)" % small)
	check(small_on_walk == 0, "no small puddle lies on a path or a square (%d)" % small_on_walk)
	var on_path := 0
	var by_house := 0
	var big := 0
	var apart := true
	for s in spots:
		var c: Vector2i = game.level.world_to_cell(s.at)
		check(Puddles.GROUND.contains(game.level.cell_char(c)), "a puddle lies on grass, path or square")
		check(float(s.radius) >= Puddles.RADIUS.x * 0.99 and float(s.radius) <= Puddles.RADIUS.y, "a puddle is of a puddle's size")
		check(not Puddles._beside(game.level, c, Puddles.WET), "no puddle runs into a pond or the well")
		if game.level.cell_char(c) == Puddles.PATH:
			on_path += 1
		if Puddles._beside(game.level, c, Outdoor.BLOCK_CHARS):
			by_house += 1
			check(float(s.radius) <= Puddles.EDGE_MERGED, "a puddle beside a house stays within its cap")
		if float(s.radius) > 3.0:
			big += 1
		for other in spots:
			if other != s and Vector2(s.at.x - other.at.x, s.at.z - other.at.z).length() < float(s.radius) + float(other.radius):
				apart = false
	check(on_path >= 8, "the paths have puddles in their ruts (%d)" % on_path)
	check(by_house >= 5, "the rain off the roofs leaves puddles by the houses (%d)" % by_house)
	check(big >= 25, "the deep dips hold sheets of water (%d)" % big)
	check(apart, "no two puddles run into each other")
	# Puddles that lay close together have run into one.
	var close := 0
	for s in spots:
		for other in spots:
			if other != s and Vector2(s.at.x - other.at.x, s.at.z - other.at.z).length() < (float(s.span) + float(other.span)) * Puddles.MERGE_GAP * 0.8:
				close += 1
	check(close <= spots.size() / 3, "close puddles are merged into one (%d pairs left)" % close)
	# The same map always gets the same puddles.
	var again := Puddles.new(game.level, hash(game.level.level_name + "pfuetzen"))
	check(again.spots.size() == spots.size() and again.spots[7].at == spots[7].at, "the puddles form in the same places every time")
	again.free()
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
	var sizes := _puddles().spots.map(func(s: Dictionary) -> float: return (s.node as Node3D).scale.x / float(s.radius))
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
