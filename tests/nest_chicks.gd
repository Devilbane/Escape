extends SceneTree
## Headless test for the eggs and chicks in the village nests (see
## VillageBirds): some nests hold eggs that rock now and then, others chicks
## that beg (stretching up, gaping, cheeping) while hungry; a parent that
## pulls up a worm takes it home and feeds them; and a hero with grain who
## stands below a nest of hungry chicks feeds them too.
## Run with: godot --headless --fixed-fps 60 -s tests/nest_chicks.gd

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
	game.load_level(game._outdoor_index(), false)
	await process_frame
	var lvl: Outdoor = game.level
	var birds: VillageBirds = lvl.birds
	check(birds != null, "the village has birds")
	if birds == null:
		_finish()
		return
	var chicks := birds.broods.filter(func(b: Dictionary): return b.chicks)
	var eggs := birds.broods.filter(func(b: Dictionary): return not b.chicks)
	check(not chicks.is_empty(), "some nests hold chicks (%d)" % chicks.size())
	check(not eggs.is_empty(), "some nests hold eggs (%d)" % eggs.size())
	check(birds.broods.size() < lvl.nests.size() or lvl.nests.size() <= 3, "not every nest has a brood (%d of %d)" % [birds.broods.size(), lvl.nests.size()])
	for brood: Dictionary in birds.broods:
		check(brood.count >= VillageBirds.BROOD_SIZE.x and brood.count <= VillageBirds.BROOD_SIZE.y, "a brood is two or three")
	check(Items.is_food(VillageBirds.SEEDS) and Lang.EN.has(Items.ALL[VillageBirds.SEEDS].name), "grain is food with an English name")

	# The hero can stand below every nest of chicks to feed it.
	for brood: Dictionary in chicks:
		var spot := _ground_below(lvl, lvl.nests[brood.nest])
		check(spot != Vector3.INF, "the ground below the chicks' nest at %s is walkable" % lvl.nests[brood.nest])

	# Hungry chicks beg: they stretch up and gape.
	lvl.player = null
	var brood: Dictionary = chicks[0]
	brood.full = 999.0
	for i in 120:
		birds._process(1.0 / 30.0)
	check(brood.beg < 0.05, "full chicks keep still (%.2f)" % brood.beg)
	brood.full = 0.0
	var pose: Array = brood.slots[0].pose
	var closed: Transform3D = pose[2]
	var head_low: Vector3 = (pose[1] as Transform3D).origin
	var gaped := false
	for i in 60:
		birds._process(1.0 / 30.0)
		var jaw: Transform3D = brood.slots[0].pose[2]
		var head: Transform3D = brood.slots[0].pose[1]
		if jaw.basis.z.angle_to(head.basis.z) > 0.3:
			gaped = true
	check(brood.beg > 0.9, "hungry chicks beg (%.2f)" % brood.beg)
	check(gaped, "begging chicks open their beaks wide")
	check((brood.slots[0].pose[1] as Transform3D).origin.y > head_low.y + 0.04, "begging chicks stretch their necks up")
	check(closed != brood.slots[0].pose[2], "the beak moves")

	# The eggs rock now and then.
	var rocked := false
	for i in 30 * 15:
		birds._process(1.0 / 30.0)
		for e: Dictionary in eggs:
			for slot: Dictionary in e.slots:
				rocked = rocked or slot.rocking > 0.0
	check(rocked, "now and then an egg rocks")

	# A parent brings a worm home and feeds the hungry chicks.
	for b: Dictionary in chicks:
		b.full = 0.0
	var carried := false
	var leaned := false
	var fed := false
	for i in 30 * 900:
		for b: Dictionary in chicks:
			# Keep them hungry until one is fed by a parent.
			if b.full > 0.0:
				fed = true
		if fed:
			break
		birds._process(1.0 / 30.0)
		for b: Dictionary in birds.birds:
			carried = carried or (b.carry and b.state == "fly")
			leaned = leaned or b.feed > 0.0
	check(carried, "a parent flies home with a worm in its beak")
	check(leaned, "the parent leans down into the nest to feed")
	check(fed, "the parent's worm fills the chicks")

	# Without grain the hero is told where to get some; with it, they feed
	# the chicks from below.
	var hero: Player = game.player
	lvl.player = hero
	VillageBirds._hinted = false
	hero.bag.clear()
	brood.full = 0.0
	var below := _ground_below(lvl, lvl.nests[brood.nest])
	hero.global_position = lvl.to_global(below)
	birds._process(1.0 / 30.0)
	check(VillageBirds._hinted, "a hero without grain is told where to get some")
	check(brood.full <= 0.0, "the chicks stay hungry without grain")
	hero.bag.append(VillageBirds.SEEDS)
	brood.full = 0.0
	birds._process(1.0 / 30.0)
	check(not hero.bag.has(VillageBirds.SEEDS), "the hero tosses up the grain")
	check(brood.full >= VillageBirds.HERO_FULL - 1.0 and birds.fed_by_hero == 1, "the hero's grain fills the chicks")
	check(game.lore.has(VillageBirds.LEARN), "the compendium tells about the chicks")
	# (A parent that happens to sit by the nest keeps them begging a while, so
	# give it a few seconds to fly off; which nests have parents shifts with the ivy.)
	var settled := false
	for i in 30 * 20:
		birds._process(1.0 / 30.0)
		settled = settled or brood.beg < 0.1
	check(settled, "fed chicks settle down (%.2f)" % brood.beg)

	# At night the chicks sleep.
	for b: Dictionary in chicks:
		b.full = 0.0
	lvl.night = true
	for i in 90:
		birds._process(1.0 / 30.0)
	check(chicks.all(func(b: Dictionary): return b.beg < 0.1 or birds.birds.any(func(p: Dictionary): return p.nest == b.nest and p.feed > 0.0)), "at night the chicks sleep")
	lvl.night = false
	_finish()


## A walkable spot (in the village's own space) within the hero's reach of
## the ground below a nest, or INF.
func _ground_below(lvl: Outdoor, nest: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := VillageBirds.FEED_REACH - 0.5
	var c := lvl.world_to_cell(lvl.to_global(nest))
	var reach := ceili(VillageBirds.FEED_REACH / Level.TILE) + 1
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := c + Vector2i(dx, dy)
			if not lvl.astar.is_in_boundsv(cell) or lvl.astar.is_point_solid(cell):
				continue
			var at := lvl.to_local(lvl.cell_to_world(cell))
			var d := Vector2(at.x - nest.x, at.z - nest.z).length()
			if d < best_d:
				best_d = d
				best = Vector3(at.x, 0.0, at.z)
	return best


func _finish() -> void:
	if failures == 0:
		print("PASS: nest chicks")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
