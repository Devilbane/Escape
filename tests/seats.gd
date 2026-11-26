extends SceneTree
## Headless test for sitting on the benches of the market square (see Seats):
## - every bench is a seat, blocked only where it is drawn,
## - a click on a bench walks the hero there, and they sit on it facing the
##   way the bench faces; running into it sits them down too,
## - sitting never holds the hero: any step, click, jump, attack or blow
##   stands them up at once, and a step moves them the same frame,
## - holding a key into the bench after getting up does not sit the hero
##   down again and again.
## Run with: godot --headless --fixed-fps 60 -s tests/seats.gd

var failures := 0
var game: Node
var frames := 0
var p: Player
var lv: Level


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await physics_frame


## Puts the hero on the spot in front of a seat, standing and calm.
func _beside(seat: Dictionary) -> void:
	p.stand_up()
	await _wait(60) # (getting up glides out first)
	p.path.clear()
	p.steer = Vector3.ZERO
	p.global_position = Seats.stand_spot(seat, lv, p.radius)
	p.velocity = Vector3.ZERO
	p._stood_at = -INF
	await _wait(3)
	for i in 120:
		if p.can_act():
			break
		await physics_frame


func _seated_right(seat: Dictionary, how: String) -> void:
	await _wait(50) # (the hero is lowered onto the seat over a moment, and the sit-down plays out)
	check(p.is_seated(), "%s: the hero sits" % how)
	var spot := Seats.sit_spot(seat)
	check(Vector2(p.global_position.x - spot.x, p.global_position.z - spot.z).length() < 0.05,
			"%s: the hero sits on the bench (%s, seat %s)" % [how, p.global_position, spot])
	check(p.facing().dot(Seats.front(seat)) > 0.99, "%s: the hero faces the way the bench faces" % how)


func _test() -> void:
	game.hero_name = "Seat test"
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(5)
	p = game.player
	lv = game.level
	# Nobody else on the square gets in the way of the test.
	for e in lv.enemies:
		e.set_physics_process(false)

	var seats: Array = lv.stations.filter(func(s): return s.kind == Seats.KIND and not s.has("indoor") and not s.get("barber", false))
	var benches := 0
	for y in lv.height:
		for x in lv.width:
			if lv.cell_char(Vector2i(x, y)) == "x":
				benches += 1
	check(benches > 0 and seats.size() == benches, "every bench is a seat (%d benches, %d seats)" % [benches, seats.size()])
	if seats.is_empty():
		_finish()
		return

	# Each bench is blocked by a box turned with it, as long and as narrow as
	# the bench, not by a square.
	for seat in seats:
		var box: CollisionShape3D = null
		for cs in lv._walls_body.get_children():
			if cs is CollisionShape3D and cs.shape is BoxShape3D \
					and Vector2(cs.position.x - seat.pos.x, cs.position.z - seat.pos.z).length() < 0.01:
				box = cs
		check(box != null, "the bench at %s is solid" % seat.cell)
		if box:
			check(is_equal_approx(box.shape.size.x, Seats.BENCH_SIZE.x) and is_equal_approx(box.shape.size.z, Seats.BENCH_SIZE.z),
					"the bench at %s is blocked where it is drawn (%s)" % [seat.cell, box.shape.size])
			check(is_equal_approx(box.rotation.y, seat.rot), "the bench's box at %s is turned with it" % seat.cell)

	# The bench by the fountain.
	var seat: Dictionary = seats[0]
	for s in seats:
		if s.pos.distance_to(lv.spots.well[0]) < seat.pos.distance_to(lv.spots.well[0]):
			seat = s

	# A click on the bench from a few steps away: the hero walks there and sits.
	await _beside(seat)
	# A few steps off along the bench (in front of it stands the fountain).
	p.global_position = Seats.stand_spot(seat, lv, p.radius) + Seats.front(seat).cross(Vector3.UP) * 3.0
	await _wait(3)
	game._click(seat.pos)
	for i in 300:
		await physics_frame
		if p.is_seated():
			break
	await _seated_right(seat, "a click on the bench")
	check(p.can_act(), "sitting does not hold the hero")
	await _wait(60)
	check(p.is_seated(), "the hero stays seated while the player does nothing")
	check(p._current_anim == Player.SIT_IDLE_ANIM, "the hero sits still on the bench (%s)" % p._current_anim)

	# A step stands the hero up and moves them in the same frame.
	var at := p.global_position
	p.steer = Seats.front(seat)
	await _wait(1)
	check(not p.is_seated(), "a step stands the hero up at once")
	check(p.velocity.length() > 1.0, "the step that stands the hero up moves them too")
	p.steer = Vector3.ZERO
	check(Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() > Seats.BENCH_SIZE.z * 0.5,
			"the hero stands up in front of the bench, not inside it")
	await _wait(10)
	check(lv.world_to_cell(p.global_position) == seat.cell or not lv.astar.is_point_solid(lv.world_to_cell(p.global_position)),
			"the hero is free to walk after standing up")

	# Running into the bench sits the hero down too.
	await _beside(seat)
	game._on_player_bumped(seat.pos)
	await _seated_right(seat, "running into the bench")

	# A click elsewhere, a jump, an attack and a blow each stand the hero up.
	var away: Vector3 = Seats.stand_spot(seat, lv, p.radius) + Seats.front(seat) * 6.0
	p.walk_to(away)
	check(not p.is_seated() and not p.path.is_empty(), "a click elsewhere stands the hero up and sends them off")
	for act in ["jump", "melee", "throw", "blow"]:
		await _beside(seat)
		game._use_station(seat)
		check(p.is_seated(), "%s: the hero sat down first" % act)
		if act != "blow":
			await _wait(50) # (the sit-down plays out first, only a blow cuts it short)
		match act:
			"jump":
				p.jump()
			"melee":
				p.melee()
			"throw":
				p.throw_knife()
			"blow":
				p._invulnerable = 0.0
				p.block_chance = 0.0
				p.take_damage(1, p.global_position + Seats.front(seat) * 2.0, null, false)
		check(not p.is_seated(), "a %s stands the hero up" % act)
	p.hp = p.max_hp

	# Sitting down always plays out: a step, a jump or a swing in the first moments waits for the end
	# of the animation (the hero stays on the seat), and a blow still gets the hero up at once.
	await _beside(seat)
	game._use_station(seat)
	var lowered := Seats.sit_spot(seat)
	p.jump()
	p.melee()
	for i in 20:
		p.steer = Seats.front(seat) # (held down, as a key is)
		await physics_frame
	check(p.is_seated() and p.sitting_down(), "a step while sitting down does not stand the hero up")
	check(p.velocity.length() < 0.1 and Vector2(p.global_position.x - lowered.x, p.global_position.z - lowered.z).length() < 0.6,
			"the hero is not carried off the seat while sitting down (%s, v %s)" % [p.global_position, p.velocity])
	for i in 60:
		p.steer = Seats.front(seat)
		await physics_frame
		if not p.is_seated():
			break
	check(not p.is_seated(), "once the sit-down has played out, the step stands the hero up (sat %.2f s)" % p._sit_time)
	p.steer = Vector3.ZERO
	# Neither lowering onto the seat nor getting up is faster than walking.
	await _beside(seat)
	var far := Seats.sit_spot(seat) + Seats.front(seat) * 1.6
	p.global_position = far
	p.velocity = Vector3.ZERO
	p.sit_down(Seats.sit_spot(seat), Seats.front(seat), Seats.stand_spot(seat, lv, p.radius))
	var span := Vector2(far.x - Seats.sit_spot(seat).x, far.z - Seats.sit_spot(seat).z).length()
	check(p._glide_len * Player.SPEED * Player.WALK_FACTOR >= span - 0.001,
			"the hero is lowered onto the seat no faster than they walk (%.2f s over %.2f m)" % [p._glide_len, span])
	await _wait(50)
	p.stand_up()
	var out := Vector2(p.global_position.x - Seats.stand_spot(seat, lv, p.radius).x, p.global_position.z - Seats.stand_spot(seat, lv, p.radius).z).length()
	check(p._glide_len * Player.SPEED * Player.WALK_FACTOR >= out - 0.001,
			"the hero steps off the seat no faster than they walk (%.2f s over %.2f m)" % [p._glide_len, out])

	# Getting up by pushing into the bench, and holding on: the hero does not
	# sit straight down again. Once they let go, the bench seats them again.
	await _beside(seat)
	game._use_station(seat)
	await _wait(50)
	p.steer = -Seats.front(seat)
	await _wait(1)
	check(not p.is_seated(), "a step into the bench stands the hero up")
	for i in 40:
		game._on_player_bumped(seat.pos)
		await physics_frame
	check(not p.is_seated(), "holding on into the bench does not sit the hero down again")
	p.steer = Vector3.ZERO
	await _wait(int(Player.SIT_AGAIN * 60.0) + 5)
	game._on_player_bumped(seat.pos)
	check(p.is_seated(), "after letting go, running into the bench sits the hero down again")
	p.stand_up()
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: seats")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
