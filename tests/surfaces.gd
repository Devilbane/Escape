extends SceneTree
## Headless test for walking speed by ground (see Surfaces): stone floors,
## paving and paths keep the full pace, grass, soil and scree slow a little,
## rain puddles the most; the hero eases into the pace of the ground
## underfoot instead of jumping at a tile's edge, and so do the monsters.
## Run with: godot --headless --fixed-fps 60 -s tests/surfaces.gd

var failures := 0
var game: Node
var frames := 0
var _phase := 0
var _phase_at := 0
const HERO := "Surface test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: surfaces")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match _phase:
		0:
			_table()
			_easing()
			_dungeon_ground()
			_outdoor_ground()
			_stand_on(Surfaces.PATH)
			_next()
		1:
			if frames < _phase_at + 90:
				return false
			check(is_equal_approx(game.player.surface_pace, 1.0), "on the path the hero keeps the full pace (%.2f)" % game.player.surface_pace)
			_stand_on(Surfaces.GRASS)
			_next()
		2:
			if frames < _phase_at + 90:
				return false
			check(is_equal_approx(game.player.surface_pace, Surfaces.PACE[Surfaces.GRASS]), "on grass the hero slows to the grass pace (%.2f)" % game.player.surface_pace)
			_finish()
			return true
	return false


func _next() -> void:
	_phase += 1
	_phase_at = frames


func _table() -> void:
	for kind: String in Surfaces.PACE:
		var pace: float = Surfaces.PACE[kind]
		check(pace > 0.5 and pace <= 1.0, "%s slows at most by half (%.2f)" % [kind, pace])
	for kind in [Surfaces.STONE, Surfaces.WOOD, Surfaces.PAVING, Surfaces.PATH]:
		check(is_equal_approx(Surfaces.PACE[kind], 1.0), "%s keeps the full pace" % kind)
	check(Surfaces.PACE[Surfaces.GRASS] < 1.0, "grass is a little slower than the path")
	check(Surfaces.PACE[Surfaces.SCREE] < Surfaces.PACE[Surfaces.GRASS], "scree is slower than grass")
	for kind: String in Surfaces.PACE:
		check(Surfaces.PACE[Surfaces.PUDDLE] <= Surfaces.PACE[kind], "a puddle is the slowest ground (%s)" % kind)


func _easing() -> void:
	# A tick on new ground only nudges the pace; a second later it is there.
	var level: Level = game.level
	var p := Vector3.ZERO
	var target := Surfaces.pace_at(level, p)
	var now := Surfaces.ease_pace(0.5, level, p, 1.0 / 60.0)
	check(now > 0.5 and now < target, "one tick on new ground only nudges the pace")
	for i in 60:
		now = Surfaces.ease_pace(now, level, p, 1.0 / 60.0)
	check(is_equal_approx(now, target), "a second later the pace has eased in")
	check(is_equal_approx(Surfaces.pace_at(null, p), 1.0), "without a level the pace is full")


func _dungeon_ground() -> void:
	var level: Level = game.level
	check(not (level is Outdoor), "the game starts in the dungeon")
	var c := _find(level, ".")
	check(c != Vector2i(-1, -1) and level.ground_at(c) == Surfaces.STONE, "a dungeon floor is stone")
	level._set_cell(c, ",")
	check(level.ground_at(c) == Surfaces.DIRT, "a dirt floor is dirt")
	level._set_cell(c, ".")


func _outdoor_ground() -> void:
	game.hero_name = HERO
	game.state = game.State.PLAYING
	game.day_hour = 12.0
	game.set_weather(Weather.CLEAR, 8.0)
	game.puddle_water = 0.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	game._tick_clock(1.0)
	var level: Outdoor = game.level
	check(level.ground_at(_find(level, ":")) == Surfaces.PAVING, "the square is paving")
	check(level.ground_at(_find(level, ",")) == Surfaces.PATH, "a dirt path is a path")
	check(level.ground_at(_find(level, "'")) == Surfaces.SCREE, "mountain ground is scree")
	check(_find_ground(level, ".", Surfaces.GRASS) != Vector2i(-1, -1), "the open land is grass")
	# Rain: a puddle is slower than the ground it lies on.
	game.set_weather(Weather.RAIN, 8.0)
	game._tick_clock(80.0)
	var spot: Dictionary = level.puddles.spots[0]
	check(Surfaces.ground(level, spot.at) == Surfaces.PUDDLE, "in a full puddle the ground is a puddle")
	check(Surfaces.pace_at(level, spot.at) < Surfaces.pace_at(level, spot.at + Vector3(spot.radius * 2.0, 0, 0)), "a puddle is slower than beside it")
	game.set_weather(Weather.CLEAR, 8.0)
	game.puddle_water = 0.0
	game._tick_clock(DayNight.DAY_LENGTH / 24.0 * 5.0)


## Puts the hero, standing still, on open ground of `kind`.
func _stand_on(kind: String) -> void:
	var level: Level = game.level
	var c := _find_ground(level, "," if kind == Surfaces.PATH else ".", kind)
	check(c != Vector2i(-1, -1), "there is %s to stand on" % kind)
	var p: Player = game.player
	p.path.clear()
	p.global_position = level.cell_to_world(c) + Vector3(0, 0.05, 0)
	p.reset_physics_interpolation()
	check(Surfaces.ground(level, p.global_position) == kind, "the hero stands on %s" % kind)


func _find(level: Level, ch: String) -> Vector2i:
	for y in level.height:
		for x in level.width:
			if level.cell_char(Vector2i(x, y)) == ch:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## A tile of letter `ch` whose ground is `kind`, away from the map's edge.
func _find_ground(level: Level, ch: String, kind: String) -> Vector2i:
	for y in range(1, level.height - 1):
		for x in range(1, level.width - 1):
			var c := Vector2i(x, y)
			if level.cell_char(c) == ch and level.ground_at(c) == kind:
				return c
	return Vector2i(-1, -1)
