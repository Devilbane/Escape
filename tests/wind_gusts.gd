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

	# Down in a cellar, the vault or the mine no wind blows.
	lvl.hero_cellar = [Rect2(-1000, -1000, 2000, 2000)]
	check(wind.below_cover() and wind.gust(1.0) == 0, "no gust blows while the hero is down in a cellar")
	lvl.hero_cellar = []
	check(not wind.below_cover(), "gusts blow again up on the ground")

	# In autumn most litter is heaps of fallen leaves: single leaves must lift off them and be carried
	# downwind, not shuffle on the spot.
	var autumn_first := SkyCommand.autumn_from(Seasons.TEST_DAY)
	lvl.set_season(autumn_first)
	check(life.fallen != null, "autumn's fallen leaves lie on the ground")
	var before := life.litter_total
	var started_count := wind.gust(1.0)
	check(started_count > 0, "a gust sets some leaves flying (%d)" % started_count)
	check(started_count <= WindGusts.MAX_PIECES, "a gust moves no more than the cap")
	var flying: Array = wind._moving.duplicate()
	check(wind._leaves != null or wind._moving.size() > 0, "the leaves fly as single leaves")
	var fixed := 0
	for m: Dictionary in flying:
		var from: Vector3 = m.from
		var to: Vector3 = m.to
		var flat := Vector2(to.x - from.x, to.z - from.z)
		check(flat.length() >= WindGusts.MIN_CROSS * 0.99, "a leaf is carried at least a third of the screen (%.1f m)" % flat.length())
		check(flat.normalized().x > 0.7, "it goes downwind, left to right across the screen")
		check(WindGusts.OPEN.contains(lvl.cell_char(lvl.world_to_cell(to))), "it lands on open ground")
		var home := false
		for e: Array in life._cell_litter.get(lvl.world_to_cell(from), []):
			if (e[4] == "leaf" or e[4] == "fallen") and Vector2(e[2].x - from.x, e[2].z - from.z).length() < 1.0:
				home = true
				break
		if home:
			fixed += 1
		# Carried on, never back and forth: its way along the wind only ever grows.
		var dir := flat.normalized()
		var last := -1.0e9
		var steps_back := 0
		for step in 21:
			var at := wind.pose(m, step / 20.0).origin
			var along := Vector2(at.x - from.x, at.z - from.z).dot(dir)
			if along < last - 0.5:
				steps_back += 1
			last = along
		check(steps_back == 0, "a leaf never goes back against the wind")
		check(absf(wind.pose(m, 1.0).origin.y - from.y) < 0.1, "it comes down on the ground")
	check(fixed > flying.size() / 2, "leaves start where leaves really lie (%d of %d)" % [fixed, flying.size()])
	# Half way through a flight the leaves are well away from where they lay.
	if flying.size() > 0:
		var far := 0
		for m: Dictionary in flying:
			var mid := wind.pose(m, 0.5).origin
			if Vector2(mid.x - m.from.x, mid.z - m.from.z).length() > WindGusts.MIN_CROSS * 0.3:
				far += 1
		check(far == flying.size(), "half way, every leaf is well on its way, not on the spot (%d of %d)" % [far, flying.size()])
	wind._now = wind._now + 3.0
	wind._move()
	check(wind._leaves != null and wind._leaves.visible, "the flying leaves are drawn")
	wind._now += 100.0
	wind._move()
	check(wind.active() == 0 and not wind._leaves.visible, "the gust is over and every leaf has settled and faded")
	check(life.litter_total == before, "no litter was added or lost")
	check(wind.gust(0.4) >= 0, "a weak gust works too")
	wind._now += 100.0
	wind._move()
	lvl.set_season(Seasons.TEST_DAY)

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
