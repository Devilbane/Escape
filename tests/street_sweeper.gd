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

	var tone: Color = sweeper._look.get("skin", Color.WHITE)
	check(tone.r <= 1.0 and tone.g <= 1.0 and tone.b <= 1.0, "his skin tone does not brighten the face (%s)" % str(tone))
	check(not sweeper._info.has("skin"), "his skin comes from the townsfolk looks, like the others")
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

	# The route marked by hand: the loop round the square comes first, every stretch of it.
	var marked := StreetSweeper.marked(lvl)
	check(marked.size() == StreetSweeper.MARKED.size(), "all the marked stretches fit the map (%d)" % marked.size())
	StreetSweeper.rested = {}
	var first := SnowSweep.route(lvl, sweeper.home, rng, Callable(LeafSweep, "is_clear").bind(lvl))
	check(not first.is_empty() and StreetSweeper.is_marked(lvl, lvl.world_to_cell(first[first.size() / 2])), "he starts on the marked route")
	var ring_cells := {}
	for st: Array in marked:
		for c in st:
			ring_cells[c] = true
	check(ring_cells.size() >= 50, "the marked route is a long way (%d tiles)" % ring_cells.size())
	StreetSweeper.rested = {}

	# One stretch after the other: he does not stop after the first, and the square is last.
	var clear := Callable(LeafSweep, "is_clear").bind(lvl)
	var cells := {}
	var stretches := 0
	var square_at := -1
	var interior := 0
	for round in 80:
		var next := SnowSweep.route(lvl, sweeper.home, rng, clear)
		if next.is_empty():
			break
		stretches += 1
		var on_square := false
		for k in next.size() - 1:
			var heading := (next[k + 1] - next[k]).normalized()
			for swing in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var head: Vector3 = next[k] + heading * 0.85 + heading.cross(Vector3.UP) * swing * LeafSweep.SWING
				LeafSweep.stamp(lvl, head, next[k], heading)
			if stretches > marked.size():
				cells[lvl.world_to_cell(next[k])] = true
		on_square = lvl.cell_char(lvl.world_to_cell(next.back())) == SurfaceLife.SQUARE
		for p in next:
			var pc: Vector2i = lvl.world_to_cell(p)
			if lvl.cell_char(pc) == SurfaceLife.SQUARE and not SnowSweep.is_rim(lvl, pc) and not StreetSweeper.is_marked(lvl, pc):
				interior += 1
		if stretches <= marked.size():
			on_square = false
		if on_square and square_at < 0:
			square_at = stretches
	check(stretches >= 3, "he works through several stretches, not one (%d, %d cells)" % [stretches, cells.size()])
	check(square_at < 0 or square_at > marked.size() + 5, "the square waits until the footpaths are done (square from stretch %d)" % square_at)
	check(interior == 0, "he sweeps only the rim and the marked loop, not the inside of the village centre (%d inner points)" % interior)
	check(cells.size() >= 40, "he covers many walkway tiles (%d)" % cells.size())
	var far := 0
	for c: Vector2i in cells:
		if absi(c.x - sweeper.home.x) + absi(c.y - sweeper.home.y) > 20:
			far += 1
	check(far > 10, "he gets far from his spot, through the gates and over gaps (%d tiles)" % far)
	LeafSweep.restore_all()

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

	# Walking over a walkway to anywhere (here: back home) he sweeps on the way.
	LeafSweep.restore_all()
	sweeper._en_route_prev = Vector3.INF
	sweeper._sweep_way = []
	for k in way.size():
		sweeper.global_position = way[k]
		sweeper._sweep_en_route(0.05)
	check(LeafSweep.swept_count() > 0, "walking along a walkway he sweeps on the way (%d)" % LeafSweep.swept_count())
	check(sweeper._broom != null and sweeper._broom.visible, "the broom is out while he walks the walkway")
	sweeper.global_position = Vector3(0, 0, 0)
	sweeper._sweep_en_route(0.05)
	check(not sweeper._broom.visible, "off the walkway the broom is put away")
	LeafSweep.restore_all()

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
