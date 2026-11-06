extends SceneTree
## Headless test for the villagers feeding the birds (see Villager.feed_birds
## and VillageBirds): now and then a villager idling in the street throws out
## a few handfuls of seed, the grains fly and land round a spot ahead of them,
## birds from the nests come down and peck the grains up, and a few sit on
## the feeder's head and shoulders until the feeder goes on.
## Run with: godot --headless --fixed-fps 60 -s tests/bird_feeding.gd

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
	for line: String in Villager.SEED_CALLS:
		check(Lang.EN.has(line), "the feeder's call has an English text: %s" % line)
	lvl.night = false
	# Nobody feeds the birds before the test says so.
	birds._seed_wait = 9999.0

	# A villager who walks about, idling on the market square near the nests.
	var feeder: Villager = null
	for v: Villager in lvl.villagers:
		if not v.keeps_spot() and v.goes_to_bed() and v.role != "7":
			feeder = v
			break
	check(feeder != null, "someone in the village can feed the birds")
	if feeder == null:
		_finish()
		return
	var square: Vector3 = _open_square(lvl, birds)
	feeder.global_position = lvl.to_global(square)
	feeder.reset_physics_interpolation()
	feeder._start("idle", 60.0)
	check(feeder.can_feed_birds(), "an idle villager in the street is free to feed the birds")

	# Perch points: the head above the shoulders, the shoulders either side.
	var head := feeder.perch_point(0)
	var left := feeder.perch_point(1)
	var right := feeder.perch_point(2)
	check(head.y > left.y + 0.5 and head.y > right.y + 0.5, "the head is above the shoulders (%s, %s, %s)" % [head, left, right])
	check(head.y > 1.8, "a bird on the head sits on top of it (%.2f)" % head.y)
	check(left.x * right.x < 0.0 and absf(left.x - right.x) > 0.6, "the shoulders are either side (%s, %s)" % [left, right])

	# The hero stands back, watching (near enough that the birds are awake).
	var hero: Player = game.player
	var watch := lvl.to_global(square + Vector3(9.0, 0.0, 0.0))

	# The feeder throws three handfuls; the grains fly and land round the spot.
	var tosses := [0]
	feeder.seeds_tossed.connect(func(_from: Vector3, _to: Vector3): tosses[0] += 1)
	check(birds.start_feeding(feeder), "a feeding starts")
	check(feeder.is_feeding() and not feeder.can_feed_birds(), "the villager stops to feed the birds")
	check(not feeder.can_chat(), "a feeder is not pulled into a chat")
	var spot: Vector3 = birds.feeding.spot
	var flew := false
	var came := 0
	var on_feeder := false
	var on_head := false
	var eaten_before := -1
	for i in 60 * 8:
		hero.global_position = watch
		await physics_frame
		flew = flew or birds.grains.any(func(g: Dictionary): return g.t > 0.1 and g.t < 0.9)
	var landed := birds.grains.filter(func(g: Dictionary): return g.t >= 1.0)
	check(flew, "the grains fly from the hand")
	check(tosses[0] == Villager.SEED_TOSSES, "three handfuls are thrown (%d)" % tosses[0])
	check(birds.grains.size() >= VillageBirds.SEED_GRAINS * 2, "each scatters a few grains (%d)" % birds.grains.size())
	check(not landed.is_empty() and landed.all(func(g: Dictionary): return VillageBirds._flat_distance(g.to, spot) <= VillageBirds.SEED_SPREAD + 0.01 and g.to.y < 0.1),
			"the grains land on the ground round the spot")
	check(birds.feeding.called, "the first handful calls the birds")
	var hand := lvl.to_local(feeder.hand_at())
	check(VillageBirds._flat_distance(hand, spot) > 0.8, "the seed lands ahead of the feeder, not at their feet")

	# The birds come: some peck among the grains, some sit on the feeder.
	for i in 60 * 14:
		hero.global_position = watch
		await physics_frame
		came = maxi(came, birds.birds.filter(func(b: Dictionary): return b.seeds and b.state == "peck" and VillageBirds._flat_distance(b.at, spot) < VillageBirds.SEED_SPREAD + 1.5).size())
		for b: Dictionary in birds.birds:
			if b.state == "perch":
				on_feeder = true
				var drawn := lvl.to_local(SmoothMotion.drawn_at(feeder))
				if int(b.perch) == 0 and b.at.y > drawn.y + 1.8 and VillageBirds._flat_distance(b.at, drawn) < 0.5:
					on_head = true
		if eaten_before < 0 and came > 0:
			eaten_before = birds.grains_left()
	check(came >= 2, "birds come down and peck among the grains (%d)" % came)
	check(birds.perched > 0 and on_feeder, "some birds land on the feeder")
	check(on_head or birds.perched < 2, "a bird sits on the feeder's head")
	check(birds.grains_left() < birds.grains.size(), "the birds peck up grains (%d of %d left)" % [birds.grains_left(), birds.grains.size()])
	check(birds.birds.filter(func(b: Dictionary): return b.seeds).size() <= VillageBirds.SEED_BIRDS, "not too many come")

	# The hero walks right up to a bird on the feeder: it flies off.
	var sitting := birds.birds.filter(func(b: Dictionary): return b.state == "perch")
	if sitting.is_empty():
		# The ones that sat there have fluttered down by now: seat one again.
		var b: Dictionary = birds.birds.filter(func(o: Dictionary): return not o.carry and o.feed <= 0.0 and int(o.perch) < 0)[0]
		var slot: int = birds.feeding.perch.find(-1)
		birds.feeding.perch[slot] = b.id
		b.perch = slot
		b.state = "perch"
		b.wait = 99.0
		sitting = [b]
	var shy: Dictionary = sitting[0]
	hero.global_position = lvl.to_global(Vector3(shy.at.x, 0.0, shy.at.z) + Vector3(0.6, 0.0, 0.0))
	await process_frame
	await process_frame
	check(shy.state != "perch" and int(shy.perch) == -1, "a bird on the feeder flies off when the hero walks right up")
	hero.global_position = watch

	# The feeder goes on: the birds on them fly off, the feeding ends, and
	# the seed left lies a while, then is gone.
	for i in 60 * 3:
		hero.global_position = watch
		await physics_frame
	feeder._start("idle", 0.0)
	feeder._next_task()
	for i in 10:
		hero.global_position = watch
		await physics_frame
	check(birds.feeding.is_empty(), "the feeding ends when the feeder goes on")
	check(not birds.birds.any(func(b: Dictionary): return b.state == "perch" or int(b.perch) >= 0), "no bird stays on a villager who walks off")
	birds._grain_left = 0.01
	await process_frame
	await process_frame
	check(birds.grains.is_empty(), "the seed left over is gone after a while")
	for i in 60 * 10:
		hero.global_position = watch
		await physics_frame
	check(not birds.birds.any(func(b: Dictionary): return b.seeds and b.state == "peck" and b.wait > VillageBirds.MARKET_STAY.y),
			"the birds go back to their day")

	# Now and then someone feeds them on their own; at night nobody does.
	feeder.global_position = lvl.to_global(square)
	feeder.reset_physics_interpolation()
	feeder._start("idle", 60.0)
	lvl.night = true
	birds._seed_wait = 0.0
	birds._mind_feeding(0.1, true)
	check(birds.feeding.is_empty(), "nobody feeds the birds at night")
	lvl.night = false
	birds._seed_wait = 0.0
	birds._mind_feeding(0.1, false)
	check(not birds.feeding.is_empty() and birds.feedings == 2, "by day an idle villager feeds the birds now and then")
	check(birds._seed_wait >= VillageBirds.SEED_EVERY.x, "and not again for a while")
	var by: Villager = birds.feeding.get("by")
	if by:
		by._start("idle", 0.0)
		by._next_task()
	birds._mind_feeding(0.1, false)
	_finish()


## An open spot of the market square near a nest, in the village's own space.
func _open_square(lvl: Outdoor, birds: VillageBirds) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for m: Vector3 in birds.market:
		if not lvl.is_open(lvl.world_to_cell(lvl.to_global(m))):
			continue
		for n: Vector3 in birds.nests:
			var d := VillageBirds._flat_distance(m, n)
			if d < best_d:
				best_d = d
				best = m
	if best == Vector3.INF:
		best = birds.ground[0]
	return Vector3(best.x, 0.0, best.z)


func _finish() -> void:
	if failures == 0:
		print("PASS: bird feeding")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
