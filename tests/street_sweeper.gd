extends SceneTree
## Headless test: Matthes the street sweeper (StreetSweeper, LeafSweep):
## - he lives on a walkway near the square, in a straw hat and a leather apron that winter clothes replace;
## - in autumn leaves are strewn over the walkways; a stroke of his broom heaps them up beside the way and the
##   wind carries them back after the hours it takes (LeafSweep.BACK_HOURS), so the way is strewn again;
## - sent out in autumn he sweeps a route and leaves the walkway clearer than it was.
## Run with: godot --headless -s tests/street_sweeper.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	game.hero_name = "Besom"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	# Mid-autumn, a clear morning.
	game.season_shift = (Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS / 2) - posmod(Seasons.today(), Weather.YEAR_DAYS)
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	game.snow_cover = 0.0
	lvl.set_hour(9.0)
	game.day_hour = 9.0
	for i in 30:
		await physics_frame
	game.weather = Weather.CLEAR
	check(Weather.is_autumn(lvl.season_day), "it is autumn")

	var sweeper: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == StreetSweeper.ROLE:
			sweeper = v
	check(sweeper != null, "the street sweeper is in the village")
	if sweeper == null:
		quit(1)
		return
	check(SurfaceLife.PATH.contains(lvl.cell_char(sweeper.home)), "he waits on a walkway")
	check(sweeper._model.find_child(StreetSweeper.HAT, true, false) != null, "he wears the straw hat")
	check(sweeper._model.find_child(StreetSweeper.APRON, true, false) != null, "he wears the apron")
	check(sweeper._model.find_child(StreetSweeper.HAT, true, false).visible, "the hat is on in autumn")

	var life: SurfaceLife = lvl.surface_life
	check(life.fallen != null and life.lane_total > 0, "leaves are strewn over the walkways (%d)" % life.lane_total)
	check(LeafSweep.wants(lvl), "autumn morning: he sweeps leaves")
	lvl.weather = Weather.STORM
	check(not LeafSweep.wants(lvl), "no leaf sweeping in a storm")
	lvl.weather = Weather.CLEAR
	lvl.set_hour(23.0)
	check(not LeafSweep.wants(lvl), "not at night")
	lvl.set_hour(9.0)

	# A stroke heaps the leaves beside the way.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var way := SnowSweep.route(lvl, sweeper.home, rng, Callable(LeafSweep, "is_clear").bind(lvl))
	check(way.size() >= 6, "a leaf route along a walkway was found (%d points)" % way.size())
	var before := 0
	for p in way:
		before += LeafSweep.leaves_near(lvl, p, LeafSweep.REACH)
	check(before > 0, "leaves lie along the route (%d)" % before)
	for k in way.size() - 1:
		var heading := (way[k + 1] - way[k]).normalized()
		for swing in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var head: Vector3 = way[k] + heading * 0.85 + heading.cross(Vector3.UP) * swing * LeafSweep.SWING
			LeafSweep.stamp(lvl, head, way[k], heading)
	var after := 0
	for p in way:
		after += LeafSweep.leaves_near(lvl, p, LeafSweep.REACH)
	check(after < before / 2, "the strokes clear the way (%d leaves before, %d after)" % [before, after])
	check(LeafSweep.swept_count() > 0, "heaps lie at its edges (%d clusters)" % LeafSweep.swept_count())
	# The heaps lie off the way, on the grass beside it, a little raised.
	var piled := 0
	for s: Array in LeafSweep._swept.values():
		var e: Array = s[0]
		if e[3].basis.get_scale().x > 1.2:
			piled += 1
	check(piled == LeafSweep.swept_count(), "swept clusters are heaped up bigger than they lay")

	# Hours later the wind has brought them back.
	var swept := LeafSweep.swept_count()
	lvl.world_hours += LeafSweep.BACK_HOURS * 0.3
	LeafSweep.advance(lvl)
	check(LeafSweep.swept_count() == swept, "a few hours on the heaps are still there")
	lvl.world_hours += LeafSweep.BACK_HOURS * 3.0
	LeafSweep.advance(lvl)
	check(LeafSweep.swept_count() == 0, "overnight the wind carried them all back")
	var again := 0
	for p in way:
		again += LeafSweep.leaves_near(lvl, p, LeafSweep.REACH)
	check(again == before, "the walkway is strewn as before (%d)" % again)

	# Sent out, he sweeps the route.
	sweeper._sweep_after = 0.0
	check(sweeper._sweep_out(), "he sets out with the broom")
	check(sweeper._sweep_kind == "leaves", "he is sweeping leaves")
	sweeper.global_position = way[0]
	sweeper._start("sweep", 120.0)
	for i in 240:
		game.weather = Weather.CLEAR
		await physics_frame
	check(LeafSweep.swept_count() > 0, "walking the route he heaped up leaves (%d)" % LeafSweep.swept_count())
	sweeper._start("idle", 1.0)
	check(sweeper._sweep == null and not sweeper._broom.visible, "the broom is put away afterwards")

	# Winter: the summer clothes go.
	LeafSweep.restore_all()
	game.season_shift += Weather.AUTUMN_DAYS
	for i in 5:
		await physics_frame
	lvl.winter_wear = true
	sweeper.update_wear(true)
	check(not sweeper._model.find_child(StreetSweeper.HAT, true, false).visible, "the straw hat is off in winter")
	check(not sweeper._model.find_child(StreetSweeper.APRON, true, false).visible, "the apron is off in winter")
	lvl.winter_wear = false
	sweeper.update_wear(true)
	check(sweeper._model.find_child(StreetSweeper.HAT, true, false).visible, "the straw hat is back in spring")

	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
