class_name SpookRaid
extends Node
## Spooknortz's nights in the village (see Spooknortz): when the village sleeps he climbs out of the
## street drain by the gate, sneaks through the lanes to two houses or stalls, lingers at each (and
## steals something, so a sack hangs on his back from then on) and goes home to the sewers before
## dawn. The hero may catch him in the act by running into him: he drops the stolen bundle and runs
## (the task of the stolen goods starts, see Spooknortz.QUEST). In the morning the village finds what
## is gone.
##
## He is the same body as in his den (an Enemy of kind Spooknortz.BODY, at rest, not on the level's
## list of foes), moved here in physics ticks along a route of the level's path grid. One raid a
## night, and none while he is slain, or fought, or the hero stands near the drain.

## The street drain he climbs out of (Sewers.GRILLES).
const START := Vector2i(44, 41)
## The houses he visits: the map letters of the tavern, the market, the smithy and the homes.
const HOUSES := "nmjo"
## How far from the drain he looks for a house (tiles).
const REACH := 16
## His pace (m/s): the same whether he is out for loot or heading home, and running away when caught.
## He always sneaks (stooped, see SNEAK_LEAN) without going any slower.
const PACE := 3.0
const RUN := 4.8
## How far he stoops forward (radians) and how far he sinks (metres) in his sneaking pose.
const SNEAK_LEAN := 0.5
const SNEAK_DIP := 0.18
## The share of the villagers who sleep at home before he dares to come out.
const MOSTLY_ASLEEP := 0.8
## Seconds he lingers at a house.
const LINGER := 3.5
## How close the hero may stand to the drain (metres) for him to come out, and how close to see him.
const SHY := 12.0
const SEEN := 16.0

## The fog's colour: a cold pale grey.
const FOG := Color(0.7, 0.74, 0.8)

const SPOTTED := "Eine Gestalt huscht durch die dunklen Gassen. Auf dem Rücken trägt sie etwas, das klirrt."
const MORNING := "Am Morgen fehlen im Dorf wieder ein paar Kerzen, Äpfel und ein Löffel. Wer wohl nachts durch die Gassen schleicht?"
const CAUGHT := "„Erwischt!“ Spooknortz lässt das Bündel fallen und rennt zum Gully zurück."
const EMPTY := "Spooknortz legt den Finger an die Lippen und huscht weiter. Noch hat er nichts gestohlen."
const NOT_NOW := "Du hast das Diebesgut schon. Spooknortz huscht davon."
const FULL := "Spooknortz lässt das Bündel fallen, aber deine Tasche ist voll. Er rafft es wieder an sich und huscht davon."

enum { IDLE, WALK, LINGER_AT, FLEE }

var level: Outdoor
var state := IDLE
var figure: Enemy = null
## How much he carries now, and how many things he has stolen tonight and in all.
var carried := 0
var tonight := 0
var total := 0
var _path: Array[Vector3] = []
var _at := 0
var _legs: Array = []
var _wait := 0.0
var _speed := PACE
var _done_tonight := false
var _told_morning := false
var _spotted := false
var _station := {}
var _sack: Node3D = null
var _catch_until := 0.0
var _clock := 0.0


func setup(lvl: Outdoor) -> void:
	level = lvl
	name = "SpookRaid"
	if level.cell_char(START) != "Ξ":
		set_physics_process(false)
		return
	_station = {"kind": Spooknortz.THIEF, "pos": Vector3(0, -500, 0), "cell": START, "used": false, "touch": 2.0}
	level.stations.append(_station)


func _game() -> Node:
	return level.get_parent()


func _physics_process(delta: float) -> void:
	step(delta)


## One tick of his night (the physics tick calls this; the tests drive it by hand).
func step(delta: float) -> void:
	_clock += delta
	var game := _game()
	if game == null or game.get("lore") == null:
		return
	if not level.night:
		_done_tonight = false
		_spotted = false
		if state == IDLE and tonight > 0 and not _told_morning:
			_told_morning = true
			Events.tell(Lang.t(MORNING), Color(1.0, 0.85, 0.5))
			tonight = 0
	else:
		_told_morning = false
	if state == IDLE:
		if level.night and not _done_tonight and _can_come_out(game):
			begin(game)
		return
	if figure == null or not is_instance_valid(figure):
		_stop()
		return
	if Spooknortz.slain(game) or Spooknortz.hostile():
		_stop()
		return
	_station.pos = figure.global_position
	_station.cell = level.world_to_cell(figure.global_position)
	if not _spotted and _flat(game.player.global_position, figure.global_position) < SEEN:
		_spotted = true
		Events.tell(Lang.t(SPOTTED), Color(0.8, 0.85, 1.0))
	match state:
		WALK, FLEE:
			_walk(delta)
		LINGER_AT:
			_wait -= delta
			if _wait <= 0.0:
				_steal()
				_next_leg()


func _can_come_out(game: Node) -> bool:
	if Spooknortz.slain(game) or Spooknortz.hostile():
		return false
	if not village_asleep():
		return false
	return _flat(game.player.global_position, level.cell_to_world(START)) >= SHY


## Whether most of the villagers who go to bed are at home asleep (with nobody to put to bed, yes).
func village_asleep() -> bool:
	var sleepers := 0
	var abed := 0
	for v: Variant in level.villagers:
		if not is_instance_valid(v) or not v.goes_to_bed():
			continue
		sleepers += 1
		if v.at_home:
			abed += 1
	return sleepers == 0 or float(abed) / sleepers >= MOSTLY_ASLEEP


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## He climbs out of the drain and starts on his round. `force` starts it though the night's raid is done.
func begin(game: Node, force := false) -> void:
	if state != IDLE or (_done_tonight and not force):
		return
	_legs = _plan()
	if _legs.is_empty():
		return
	_done_tonight = true
	carried = 0
	figure = Enemy.new()
	figure.kind = Spooknortz.BODY
	figure.custom = {"title": Spooknortz.NAME}
	figure.level = level
	level.add_child(figure)
	figure.global_position = level.cell_to_world(START)
	figure.reset_physics_interpolation()
	figure.set_physics_process(false)
	var fog := _make_fog()
	figure.add_child(fog)
	fog.emitting = true
	_stoop()
	_sack = null
	_speed = PACE
	_next_leg()


## The round: from the drain to two houses and back, each leg a list of path points.
func _plan() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("spooknortz_runde_%d" % int(level.world_hours / 24.0))
	var near: Array[Vector2i] = []
	for dy in range(-REACH, REACH + 1):
		for dx in range(-REACH, REACH + 1):
			var c := START + Vector2i(dx, dy)
			if not level.astar.is_in_boundsv(c) or level.astar.is_point_solid(c):
				continue
			if Vector2(dx, dy).length() < 5.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if HOUSES.contains(level.cell_char(c + d)):
					near.append(c)
					break
	near.sort()
	var picks: Array[Vector2i] = []
	var guard := 0
	while picks.size() < 2 and not near.is_empty() and guard < 40:
		guard += 1
		var c: Vector2i = near[rng.randi() % near.size()]
		var far_enough := true
		for p: Vector2i in picks:
			if Vector2(c - p).length() < 6.0:
				far_enough = false
		if far_enough and not level.astar.get_id_path(START, c).is_empty():
			picks.append(c)
	if picks.is_empty():
		return []
	var legs := []
	var from := START
	for c: Vector2i in picks:
		legs.append({"path": _points(from, c), "linger": true})
		from = c
	legs.append({"path": _points(from, START), "linger": false})
	return legs


func _points(a: Vector2i, b: Vector2i) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for c: Vector2i in level.astar.get_id_path(a, b):
		out.append(level.cell_to_world(c))
	return out


func _next_leg() -> void:
	if _legs.is_empty():
		_home()
		return
	var leg: Dictionary = _legs.pop_front()
	_path = leg.path
	_at = 1 if _path.size() > 1 else 0
	state = WALK
	_lingers = leg.linger
	_idle_pose(false)


var _lingers := false


func _walk(delta: float) -> void:
	var game := _game()
	var speed := _speed
	if _at >= _path.size():
		_arrived()
		return
	var target := _path[_at]
	target.y = figure.global_position.y
	var to := target - figure.global_position
	var dist := to.length()
	if dist <= speed * delta:
		figure.global_position = target
		_at += 1
		return
	var dir := to / dist
	figure.global_position += dir * speed * delta
	figure._model.rotation.y = lerp_angle(figure._model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * delta))
	_idle_pose(true, speed)


## The sneaking pose: bent forward and low, walking or standing.
func _stoop() -> void:
	if figure == null or not is_instance_valid(figure) or figure._model == null:
		return
	figure._model.rotation.x = SNEAK_LEAN
	figure._model.position.y = -SNEAK_DIP


## The thick fog he is always wrapped in: many broad, pale puffs that hang around him and drift on.
static func make_fog() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Fog"
	p.amount = 48
	p.lifetime = 5.0
	p.local_coords = false
	p.mesh = Effects._quad(3.6, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.6
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(FOG, 0.0))
	ramp.add_point(0.2, Color(FOG, 0.6))
	ramp.add_point(0.75, Color(FOG, 0.5))
	ramp.set_color(ramp.get_point_count() - 1, Color(FOG, 0.0))
	p.color_ramp = ramp
	p.position.y = 0.9
	Effects.start_cold(p)
	return p


func _make_fog() -> CPUParticles3D:
	return make_fog()


func _idle_pose(walking: bool, speed := 0.0) -> void:
	if figure == null or not is_instance_valid(figure) or figure._anim == null:
		return
	figure._play("Walking_A" if walking else "Idle")
	if walking:
		figure._anim.speed_scale = Stride.playback(figure._rig, figure._anim_of(figure._current_anim), figure._stride_size, speed)
	else:
		figure._anim.speed_scale = 1.0


func _arrived() -> void:
	if state == FLEE:
		_home()
	elif _lingers:
		state = LINGER_AT
		_wait = LINGER
		_idle_pose(false)
	else:
		_home()


## He takes something from the house: a sack hangs on his back from the first theft on.
func _steal() -> void:
	carried += 1
	tonight += 1
	total += 1
	if _sack == null and figure != null and is_instance_valid(figure):
		_sack = _make_sack()
		figure.add_child(_sack)


func _make_sack() -> Node3D:
	var n := Node3D.new()
	n.name = "Sack"
	var b := Sewers.W.Builder.new()
	b.frustum(Vector3(0, 0.55, -0.32), Vector2(0.3, 0.26), Vector2(0.1, 0.1), 0.6, Color(0.5, 0.42, 0.28), Sewers.W.WOOD)
	b.cylinder(Vector3(0, 1.12, -0.32), 0.1, 0.1, 0.06, Color(0.3, 0.22, 0.14), Sewers.W.WOOD, 8)
	b.finish(n)
	return n


func _home() -> void:
	_stop()


func _stop() -> void:
	state = IDLE
	if figure != null and is_instance_valid(figure):
		figure.queue_free()
	figure = null
	_sack = null
	_legs = []
	_path = []
	carried = 0
	if not _station.is_empty():
		_station.pos = Vector3(0, -500, 0)


## The hero ran into him in the street: stolen goods change hands, and he runs for the drain.
func caught(game: Node) -> void:
	if figure == null or state == IDLE or _clock < _catch_until:
		return
	_catch_until = _clock + 3.0
	if carried <= 0:
		game.show_message(Lang.t(EMPTY), 3.5)
		return
	var state_of: Dictionary = game.quests.state.get(Spooknortz.QUEST, {})
	if not state_of.is_empty():
		game.show_message(Lang.t(NOT_NOW), 3.5)
	elif game.quests.start_found(Spooknortz.QUEST):
		game.show_message(Lang.t(CAUGHT), 4.5, Color(1.0, 0.9, 0.6))
		carried = 0
		if _sack != null and is_instance_valid(_sack):
			_sack.queue_free()
		_sack = null
	else:
		game.show_message(Lang.t(FULL), 4.0)
	# Either way he heads for the drain.
	var here := level.world_to_cell(figure.global_position)
	_path = _points(here, START)
	_at = 1 if _path.size() > 1 else 0
	_legs = []
	_speed = RUN
	state = FLEE
