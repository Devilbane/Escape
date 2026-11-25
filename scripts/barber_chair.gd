class_name BarberChair
extends RefCounted
## The barber's chair beside Benno's tent. It stands right in front of him, turned to the street, so
## he stands behind whoever sits in it. It is a seat like the benches (see Seats): the hero runs into
## it or clicks it and sits down, a cape goes round their neck and Benno's window opens (talking to
## Benno opens nothing: he points to the chair). Picking a style or a colour starts a haircut (see
## BarberCut).
##
## Idle townsfolk now and then take the chair too, the way they rest on the benches (see BenchRest):
## they walk up, sit down, are given a trim and get up again. Whoever is in the chair, Benno turns to
## it and snips (see Villager.customer_at); a chair with a villager in it does not seat the hero.

## Metres from Benno to the middle of the chair, to the south: he stands behind its back.
const BEHIND := 1.25
## How often a villager with nothing to do takes the chair rather than a bench or an errand.
const CHANCE := 0.14
## How long a villager sits in it (seconds, at random between the two).
const STAY := Vector2(12.0, 24.0)
## A seated body this close to the seat (metres) is in the chair.
const HERO_IN := 0.9
## Seconds between sitting down and the window opening: the hero is down and the cape is on.
const OPEN_AFTER := 0.9
## The chair's touch distance: the hero runs into it from the front or the sides.
const TOUCH := 1.5

var station := {}
## The seat for villagers (see BenchRest): {"station", "sit", "front", "stand", "walk_to", "rest", "taker", "until"}.
var seat := {}
var barber: Villager
var cut := BarberCut.new()
var chair_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Builds the chair and its table in front of `benno`, who is already at his place.
func build(level: Outdoor, benno: Villager) -> void:
	barber = benno
	chair_pos = benno.global_position + Vector3(0, 0, BEHIND)
	var model := BarberChairModel.build()
	model.position = chair_pos
	level.add_child(model)
	# Solid where it is drawn: the chair, and the table beside it.
	var back := BarberChairModel.BACK_REACH
	var front := BarberChairModel.FRONT_REACH
	level._add_box(level._walls_body, chair_pos + Vector3(0, 0.5, (front - back) * 0.5), Vector3(1.02, 1.0, front + back))
	var table := chair_pos + BarberChairModel.TABLE_AT
	level._add_box(level._walls_body, table + Vector3(0, 0.45, 0), Vector3(BarberChairModel.TABLE_SIZE.x + 0.06, 0.9, BarberChairModel.TABLE_SIZE.y + 0.06))
	var size := Vector3(1.02, 1.0, 1.5)
	station = Seats.station(level.world_to_cell(chair_pos), chair_pos, 0.0, size)
	station["forward"] = Seats.HIPS_BACK
	station["lift"] = BarberChairModel.SEAT_TOP - Seats.SEAT_TOP
	station["touch"] = TOUCH
	station["barber"] = true
	level.stations.append(station)
	var sit := Seats.sit_spot(station)
	var ahead := Seats.front(station)
	var stand := sit + ahead * 0.5
	seat = {"station": station, "sit": sit, "front": ahead, "stand": stand, "walk_to": stand,
			"rest": true, "taker": null, "until": -1.0}


## Whether the hero sits in the chair.
func hero_in(level: Outdoor) -> bool:
	if station.is_empty() or level.player == null or not level.player.is_seated():
		return false
	var at := level.player.global_position
	var sit := Seats.sit_spot(station)
	return Vector2(at.x - sit.x, at.z - sit.z).length() < HERO_IN


## Whether Benno is at his chair and can work: not gone home, not away.
func barber_here() -> bool:
	return barber != null and is_instance_valid(barber) and barber.visible and not barber.at_home and not barber.night


## The hero has just sat down in the chair: the cape goes on, and the window opens once they are down.
func hero_sits(game: Node, level: Outdoor) -> void:
	cut.wear(level.player)
	if not barber_here():
		game.show_message(Lang.t("Benno ist gerade nicht da."), 2.6)
		return
	game.get_tree().create_timer(OPEN_AFTER).timeout.connect(func():
		if is_instance_valid(game) and game.level == level and hero_in(level) and not cut.active() and not game.menus.is_open() and barber_here():
			barber.say(Lang.t("Willkommen in meinem Stuhl! Was darf es sein?"), level.player.global_position)
			game.trader_role = barber.role
			game.menus.open("barbier"))


## Starts the cut of the look the hero picked (see Menus._restyle).
func order(level: Outdoor, look: Dictionary) -> void:
	cut.start(level, look)


## Whether a villager sits in the chair, or is on the way to it: the hero does not sit down then.
func taken(s: Dictionary) -> bool:
	if s != station:
		return false
	var v = seat.get("taker")
	return v != null and is_instance_valid(v) and v.rests() and v.meal_seat == seat


## Now and then the chair for a villager with nothing to do: {} most of the time, and when anyone
## sits in it, or Benno is not at his post.
func offer(level: Outdoor, v: Villager) -> Dictionary:
	if seat.is_empty() or not BenchRest.rests_here(v) or v == barber or _rng.randf() >= CHANCE:
		return {}
	if not barber_here() or seat.taker != null or cut.active() or level.village_alarm.raised:
		return {}
	var at := level.player.global_position if level.player else Vector3.INF
	var sit: Vector3 = seat.sit
	if at != Vector3.INF and Vector2(at.x - sit.x, at.z - sit.z).length() < BenchRest.HERO_NEAR:
		return {}
	seat.taker = v
	seat.until = -1.0
	return seat


## One step: the cape follows the hero, the cut goes on, a villager's turn runs out, and Benno
## turns to whoever sits in the chair and snips.
func tick(level: Outdoor, delta: float) -> void:
	if station.is_empty() or level.player == null:
		return
	var in_chair := hero_in(level)
	if cut.active():
		if not in_chair:
			cut.finish(level, self, false)
		elif cut.tick(self, level, delta):
			cut.finish(level, self, true)
	elif not in_chair:
		cut.doff()
		cut.served = false
	elif cut.cape == null and not cut.served:
		cut.wear(level.player)
	var v = seat.get("taker")
	if v != null:
		if not is_instance_valid(v) or not v.rests() or v.meal_seat != seat:
			if is_instance_valid(v) and v.meal_seat == seat:
				v.forget_meal()
			seat.taker = null
		elif v.seated_on_bench():
			if seat.until < 0.0:
				seat.until = _rng.randf_range(STAY.x, STAY.y)
			seat.until -= delta
			if seat.until <= 0.0 or level.village_alarm.raised or not barber_here():
				v.leave_meal()
	if barber != null and is_instance_valid(barber):
		var busy: bool = cut.active() or (v != null and is_instance_valid(v) and v.seated_on_bench())
		barber.customer_at = chair_pos if busy else Vector3.INF
