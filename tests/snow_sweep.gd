extends SceneTree
## Headless test: Konrad the herald sweeps the snow off the village footpaths (SnowSweep):
## - he sweeps only in winter, with snow lying and none falling, in his hours and in daylight;
## - the route runs along footpath tiles;
## - a stroke of the broom leaves bare ground that takes no footprints, and the strip fills in
##   again after enough snowfall;
## - sent out, he walks the route with the broom in his hand and puts it away afterwards.
## Run with: godot --headless -s tests/snow_sweep.gd

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
	game.season_shift = (Weather.YEAR_DAYS - 3) - posmod(Seasons.today(), Weather.YEAR_DAYS)
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	game.snow_cover = 1.0
	lvl.set_hour(10.0)
	game.day_hour = 10.0
	for i in 40:
		await physics_frame
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	for i in 3:
		await physics_frame
	check(SnowSweep.in_shift(10.0) and not SnowSweep.in_shift(8.0) and not SnowSweep.in_shift(12.0), "his hours")
	check(SnowSweep.wants(lvl), "winter snow, clear sky, his hour: he sweeps")
	lvl.weather = Weather.SNOW
	check(not SnowSweep.wants(lvl), "no sweeping while it snows")
	lvl.weather = Weather.CLEAR

	var konrad: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == SnowSweep.ROLE:
			konrad = v
	check(konrad != null, "the herald is in the village")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var way := SnowSweep.route(lvl, konrad.home, rng)
	check(way.size() >= 6, "a route along a walkway was found (%d points)" % way.size())
	for p in way:
		check(SurfaceLife.PATH.contains(lvl.cell_char(lvl.world_to_cell(p))), "every point lies on a footpath tile")
		break

	# A stroke: bare at the middle, white far away, no footprints on it, wiped footprints.
	var spot := way[0]
	check(not SnowSweep.is_bare(lvl, spot), "snow covers the ground before the stroke")
	SnowSweep.stamp(lvl, spot)
	check(SnowSweep.is_bare(lvl, spot), "the stroke leaves bare ground")
	check(not SnowSweep.is_bare(lvl, spot + Vector3(3, 0, 0)), "ground 3 m away is still white")
	var prints_before := SnowPrints._records.size()
	lvl.snow_print(spot, 0.0)
	check(SnowPrints._records.size() == prints_before, "no footprint is pressed on swept ground")
	# The strip fills in once enough snow has fallen.
	SnowSweep._fall += SnowSweep.REFILL_HOURS * 1.1
	check(not SnowSweep.is_bare(lvl, spot), "after the snowfall the strip is white again")
	SnowSweep.reset()
	check(not SnowSweep.is_bare(lvl, spot), "the mask is gone when the snow melts")

	# Sent out, he walks the route with the broom, then puts it away.
	konrad._sweep_after = 0.0
	check(konrad._sweep_out(), "he sets out with the broom")
	check(konrad._broom != null and konrad._broom.visible, "the broom is in his hand")
	konrad.global_position = way[0]
	konrad._sweep_way = way
	konrad._start("sweep", 60.0)
	check(konrad._sweep != null, "the sweeping job begins")
	for i in 90:
		game.weather = Weather.CLEAR
		await physics_frame
	check(SnowSweep.is_bare(lvl, konrad.global_position), "the ground under him is swept")
	konrad._start("idle", 1.0)
	check(konrad._sweep == null and not konrad._broom.visible, "the broom is put away when he does something else")

	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
