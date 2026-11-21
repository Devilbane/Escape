class_name BenchRest
extends RefCounted
## A rest on the benches round the village fountain. Townsfolk with nothing to
## do now and then sit down on one for a while, facing the water, and then go
## back to their day. It is one idle choice among the others, not a habit: a
## villager setting off on an errand or a stroll picks a bench instead only now
## and then (CHANCE, see Villager._next_task) and only when one is free.
##
## They sit the way the diners sit at the tables (see TownMeals): a few paces to
## the spot in front of the bench, down onto it, the chair idle, and up again on
## the same spot (Villager._dine). Benches are handed out here, one villager to
## a bench, in its middle, so nobody shares a seat and the clear gap between
## villagers (Villager.BODY_GAP) holds on the benches too.
##
## The hero comes first: a villager never takes the bench the hero sits on or
## stands right at, and a bench with a villager on it does not seat the hero
## (see taken).

## How often a villager with nothing to do picks a free bench over their usual errand.
const CHANCE := 0.3
## How long one stays seated (seconds, picked at random between the two).
const STAY := Vector2(18.0, 40.0)
## A villager never picks a bench while the hero is within this of its seat (metres).
const HERO_NEAR := 2.0
## Who never sits down here: the woodcutter (out in the woods) and the wandering merchant.
const STAY_AWAY := ["3", "%"]
## The day plans of those who may rest here: who has no stall or post to keep.
const PLANS := ["work", "sit", "stroll"]

## Every bench seat: {"station" (the bench's station, see Seats), "sit", "stand",
## "front", "rest": true, "taker" (a Villager or null), "until" (seconds left
## seated, -1 until they sit)}.
var seats: Array = []
var _built := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## The seats of the benches beside `level`'s fountains, gathered once the map is built.
## A rester steps up to the bench from behind, like the diners at the tables, where the
## ground behind it is open; otherwise from the front, between the bench and the fountain,
## walking the last few paces in from an open tile beside the bench ("walk_to").
func _build(level: Outdoor) -> void:
	_built = true
	for s: Dictionary in level.stations:
		if s.kind != Seats.KIND or not _by_fountain(level, s.cell):
			continue
		var sit := Seats.sit_spot(s)
		var front := Seats.front(s)
		var out: float = s.get("size", Seats.BENCH_SIZE).z * 0.5 + Villager.PASSING_SPACE * 0.6 + Seats.STAND_GAP
		var stand := sit - front * out
		var walk_to := stand
		if not level.is_open(level.world_to_cell(stand)):
			stand = sit + front * out
			walk_to = _open_beside(level, s.cell, stand)
			if walk_to == Vector3.INF:
				continue
		seats.append({"station": s, "sit": sit, "front": front, "stand": stand, "walk_to": walk_to,
				"rest": true, "taker": null, "until": -1.0})


## Whether the tile `c` is right beside a fountain (diagonals too).
static func _by_fountain(level: Outdoor, c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if level.cell_char(c + Vector2i(dx, dy)) == "F":
				return true
	return false


## The middle of the open tile beside `c` nearest to `to`, INF when none is open.
static func _open_beside(level: Outdoor, c: Vector2i, to: Vector3) -> Vector3:
	var best := Vector3.INF
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not level.is_open(c + d):
			continue
		var at := level.cell_to_world(c + d)
		if best == Vector3.INF or at.distance_to(to) < best.distance_to(to):
			best = at
	return best


## Whether `v` ever rests on the benches.
static func rests_here(v: Villager) -> bool:
	return v.meal_plan() in PLANS and not v.role in STAY_AWAY


## Now and then, a free bench for `v`, who has nothing to do: {} most of the
## time, and always when every bench is taken. The seat is theirs from now on.
func offer(level: Outdoor, v: Villager) -> Dictionary:
	if not rests_here(v) or _rng.randf() >= CHANCE:
		return {}
	var seat := free_seat(level)
	if seat.is_empty():
		return {}
	seat.taker = v
	seat.until = -1.0
	return seat


## A bench nobody has and the hero is not on or right at, {} when there is none.
func free_seat(level: Outdoor) -> Dictionary:
	if not _built:
		_build(level)
	var hero := level.player.global_position if level.player else Vector3.INF
	var free := []
	for s: Dictionary in seats:
		if s.taker != null:
			continue
		var at: Vector3 = s.sit
		if hero != Vector3.INF and Vector2(hero.x - at.x, hero.z - at.z).length() < HERO_NEAR:
			continue
		free.append(s)
	if free.is_empty():
		return {}
	return free[_rng.randi() % free.size()]


## Whether someone from the village sits on (or is on the way to) the bench of `station`.
func taken(station: Dictionary) -> bool:
	for s: Dictionary in seats:
		if s.station == station and s.taker != null and is_instance_valid(s.taker) and s.taker.rests():
			return true
	return false


## Counts down the rest of everyone seated, sends them off when it is over and
## frees the benches of those called away (an alarm, the herald, nightfall).
func tick(level: Outdoor, delta: float) -> void:
	if not _built:
		_build(level)
	for s: Dictionary in seats:
		var v = s.taker
		if v == null:
			continue
		if not is_instance_valid(v) or not v.rests() or v.meal_seat != s:
			if is_instance_valid(v) and v.meal_seat == s:
				v.forget_meal()
			s.taker = null
			continue
		if not v.seated_on_bench():
			continue
		if s.until < 0.0:
			s.until = _rng.randf_range(STAY.x, STAY.y)
		s.until -= delta
		if s.until <= 0.0 or level.village_alarm.raised:
			v.leave_meal()


## Everyone sitting on a bench right now.
func seated() -> Array:
	var out := []
	for s: Dictionary in seats:
		if s.taker != null and is_instance_valid(s.taker) and s.taker.seated_on_bench():
			out.append(s.taker)
	return out
