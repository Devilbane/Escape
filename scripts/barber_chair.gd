class_name BarberChair
extends RefCounted
## The barber's chair under Benno's tent, turned to the street. Benno walks round to stand beside
## whoever sits in it, and the tent fades away while someone does, so the chair can be seen. It is a seat like the benches (see Seats): the hero runs into
## it or clicks it and sits down, a cape goes round their neck and Benno's window opens (talking to
## Benno opens nothing: he points to the chair). Picking a style or a colour starts a haircut (see
## BarberCut).
##
## Idle townsfolk now and then take the chair too, the way they rest on the benches (see BenchRest):
## they walk up, sit down, are given a trim and get up again. Whoever is in the chair, Benno turns to
## it and snips (see Villager.customer_at); a chair with a villager in it does not seat the hero.

## Metres from the tent's middle to the middle of the chair, to the south.
const UNDER := 0.5
## How far the hero sits forward of the hips-over-the-middle spot (metres): the backrest leans in over the
## seat, so the middle would sink the back into it and the feet into the footrest.
const SIT_SHIFT := 0.2
## Where Benno stands while he serves, from the chair's middle: up and to the left of the customer as the
## camera sees it (the camera looks north, the chair faces south), so he and his speech bubbles stay off them.
const BESIDE := Vector3(-0.95, 0.0, -0.85)
## Seconds the tent takes to fade away and come back.
const FADE := 0.5
## How often a villager with nothing to do takes the chair rather than a bench or an errand.
const CHANCE := 0.1
## The same for the women, who go for a haircut more often.
const CHANCE_WOMEN := 0.3
## How long a villager sits in it (seconds, at random between the two).
const STAY := Vector2(12.0, 24.0)
## A seated body this close to the seat (metres) is in the chair.
const HERO_IN := 0.9
## Seconds between sitting down and the window opening: the hero is down and the cape is on.
const OPEN_AFTER := 0.9
## The longest the window waits for Benno to reach his place (seconds).
const WAIT_MAX := 8.0
## The chair's touch distance: the hero runs into it from the front or the sides.
const TOUCH := 1.5
## How far outside the tent's roof edge (metres) the hero's presence makes it fade away, and where it comes back.
const NEAR := 1.0
const NEAR_OUT := 1.8

var station := {}
## The seat for villagers (see BenchRest): {"station", "sit", "front", "stand", "walk_to", "rest", "taker", "until"}.
var seat := {}
var barber: Villager
var cut := BarberCut.new()
var chair_pos := Vector3.ZERO
## Benno's tent over the chair (see Outdoor._build_barber_shop), shown unless someone sits.
var tent: Node3D
var _tent_gone := false
var _fade: Tween
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Builds the chair and its table under `tent_node`, which stands at `tent_at`, for `benno`.
func build(level: Outdoor, benno: Villager, tent_node: Node3D, tent_at: Vector3) -> void:
	barber = benno
	tent = tent_node
	chair_pos = tent_at + Vector3(0, 0, UNDER)
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
	station["forward"] = Seats.HIPS_BACK + SIT_SHIFT
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
	_open_when_ready(game, level, 0.0)


## Opens Benno's window once the hero is down and he has walked round to his place: the window stops the
## village, so opened sooner it would freeze him half way, in front of the customer. After WAIT_MAX seconds
## it opens anyway.
func _open_when_ready(game: Node, level: Outdoor, waited: float) -> void:
	game.get_tree().create_timer(0.2).timeout.connect(func():
		if not is_instance_valid(game) or game.level != level or not hero_in(level) or cut.active() or game.menus.is_open() or not barber_here():
			return
		var there := Vector2(barber.global_position.x - snip_spot_of_barber().x, barber.global_position.z - snip_spot_of_barber().z).length() <= 0.15
		if waited + 0.2 < OPEN_AFTER or (not there and waited < WAIT_MAX):
			_open_when_ready(game, level, waited + 0.2)
			return
		barber.say(Lang.t("Willkommen in meinem Stuhl! Was darf es sein?"), level.player.global_position)
		game.trader_role = barber.role
		game.menus.open("barbier"))


## Where Benno works.
func snip_spot_of_barber() -> Vector3:
	return chair_pos + BESIDE


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
	if seat.is_empty() or not BenchRest.rests_here(v) or v == barber or _rng.randf() >= (CHANCE_WOMEN if v.info_sex() == "female" else CHANCE):
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
		var guest: bool = v != null and is_instance_valid(v) and v.rests() and v.meal_seat == seat
		var seated: bool = guest and v.seated_on_bench()
		barber.customer_at = chair_pos if (in_chair or guest) else Vector3.INF
		barber.snip_spot = chair_pos + BESIDE
		barber.snips = cut.active() or seated
		_show_tent(not (in_chair or seated or _hero_near_tent(level)))


## Whether the hero stands under the tent or right beside it. Once the tent has faded it stays away a little
## further out, so it does not flicker at the edge.
func _hero_near_tent(level: Outdoor) -> bool:
	if tent == null or not is_instance_valid(tent) or level.player == null:
		return false
	var d := level.player.global_position - tent.global_position
	var reach := BarberTent.REACH + (NEAR_OUT if _tent_gone else NEAR)
	return absf(d.x) < reach and absf(d.z) < reach


## The tent over the chair fades away while someone sits or the hero stands under or beside it, and comes back after.
func _show_tent(shown: bool) -> void:
	if tent == null or not is_instance_valid(tent) or _tent_gone == (not shown):
		return
	_tent_gone = not shown
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if shown:
		tent.visible = true
	_fade = tent.create_tween().set_parallel(true)
	for mi: MeshInstance3D in tent.find_children("*", "MeshInstance3D", true, false):
		_fade.tween_property(mi, "transparency", 0.0 if shown else 1.0, FADE)
	if not shown:
		_fade.chain().tween_callback(func(): tent.visible = false)
