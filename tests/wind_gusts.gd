extends SceneTree
## Headless test: now and then a gust of wind stirs the light litter round the hero (WindGusts):
## - a gust sets a handful of leaves, straw and chips flying near the hero, and when it is over they
##   lie somewhere else, on open ground;
## - the litter's count does not change (nothing is added or lost), and nothing is drawn new;
## - the Performance preset has no gusts, and a storm blows harder than fog;
## - nothing lands in a dug hole.
## Run with: godot --headless -s tests/wind_gusts.gd

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
	game.hero_name = "Wind gusts"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	var life := lvl.surface_life
	var wind := life.gusts
	check(wind != null, "the surface life has its gusts")
	Graphics.preset = Graphics.BALANCED
	check(WindGusts.enabled() and not (Graphics.preset == Graphics.PERFORMANCE), "gusts are on in Balanced")
	Graphics.preset = Graphics.PERFORMANCE
	check(not WindGusts.enabled(), "the Performance preset has no gusts")
	Graphics.preset = Graphics.BALANCED

	var before := life.litter_total
	var started_count := wind.gust(1.0)
	check(started_count > 0, "a gust sets some pieces flying (%d)" % started_count)
	check(started_count <= WindGusts.MAX_PIECES, "a gust moves no more than the cap")
	# (Pairs, not a dictionary keyed by the entry: the entry's own contents change when it lands.)
	var origins: Array = []
	for m: Dictionary in wind._moving:
		origins.append([m.entry, (m.entry[2] as Vector3)])
	wind._now += 100.0
	wind._move()
	check(wind.active() == 0, "the gust is over and every piece has landed")
	var shifted := 0
	for pair: Array in origins:
		var o: Vector3 = pair[1]
		var now: Vector3 = pair[0][2]
		if Vector2(o.x - now.x, o.z - now.z).length() > 0.3:
			shifted += 1
		if pair[0][4] == "leaf" or pair[0][4] == "straw":
			check(Vector2(o.x - now.x, o.z - now.z).length() >= WindGusts.MIN_CROSS * 0.99, "a leaf is carried at least a third of the screen")
		var ch := lvl.cell_char(lvl.world_to_cell(now))
		check(WindGusts.OPEN.contains(ch), "a piece landed on open ground, not '%s'" % ch)
	check(shifted > 0, "pieces lie somewhere else after the gust (%d of %d)" % [shifted, origins.size()])
	check(life.litter_total == before, "no litter was added or lost")
	check(wind.gust(0.4) >= 0, "a weak gust works too")
	wind._now += 100.0
	wind._move()

	# Feather-like: a leaf's height is zero at both ends, rises early and sinks slowly.
	check(WindGusts.height_share(0.0, 0.5) < 0.001 and WindGusts.height_share(1.0, 0.5) < 0.001, "a leaf starts and lands on the ground")
	check(WindGusts.height_share(0.5, 1.0) > WindGusts.height_share(0.5, -1.0), "it wanders up and down on the way, as its restlessness goes")
	# Frequent in autumn, rare in other seasons.
	var autumn_day := SkyCommand.autumn_from(Seasons.TEST_DAY)
	lvl.set_season(autumn_day)
	var in_autumn := wind.every()
	lvl.set_season(Seasons.TEST_DAY)
	check(in_autumn.y < wind.every().x, "gusts are frequent in autumn and rare in spring")

	# Every gust has its own force, from light and slow to strong and fast.
	var lo := 9.0
	var hi := 0.0
	for i in 40:
		wind.gust(1.0)
		lo = minf(lo, wind.force)
		hi = maxf(hi, wind.force)
		wind._now += 100.0
		wind._move()
		wind._move_flakes()
	check(hi - lo > 0.5 and lo >= WindGusts.FORCE.x and hi <= WindGusts.FORCE.y, "gusts differ in force (%.2f to %.2f)" % [lo, hi])
	check(WindGusts._pace(0.3) < WindGusts._pace(1.6), "a strong gust carries its pieces faster than a light one")

	# Snow: flakes lift only where snow really lies.
	var winter_day := SkyCommand.day_for(Seasons.TEST_DAY, true)
	lvl.set_season(winter_day)
	lvl.snow.set_amount(0.0)
	wind._now += 200.0
	wind._move()
	wind._move_flakes()
	check(wind.gust(1.0) == 0, "no flakes lift while no snow lies")
	lvl.snow.set_amount(1.0)
	var flakes := wind.gust(1.0)
	check(flakes > 0, "flakes lift once snow lies (%d)" % flakes)
	for m: Dictionary in wind._flakes:
		check(wind.snow_lies_at(m.from), "a flake starts where snow lies, not under a roof, on water or by a fire")
	check(wind._puffs.size() > 0 and wind._dust.visible, "foggy dust puffs fly with the flakes (%d)" % wind._puffs.size())
	for m: Dictionary in wind._puffs:
		check(wind.snow_lies_at(m.from), "a dust puff starts where snow lies")
	wind._now += 200.0
	wind._move_flakes()
	wind._move_puffs()
	check(wind.active() == 0 and not wind._dust.visible, "flakes and dust are gone when the gust is over")
	lvl.snow.set_amount(0.0)
	lvl.set_season(Seasons.TEST_DAY)

	var storm := FlagWind.wind_for(Weather.STORM).x
	var fog := FlagWind.wind_for(Weather.FOG).x
	check(storm > fog, "a storm blows harder than fog")

	print("wind_gusts: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
