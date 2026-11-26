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
## The villager he fears: the town guard (Villager role "4", Ulrich), out and about at night. When the guard
## comes within DODGE metres and could see him, he slips away to cover (a spot out of the guard's sight,
## at most HIDE_REACH tiles (of 4 m) off, never on the way towards him) and lies low until no guard is within
## CLEAR metres for LAY_LOW seconds (at most COVER_MAX), then goes on. After HIDES_MAX hides in a night he
## gives the round up and goes home.
const GUARD_ROLE := "4"
const DODGE := 15.0
const CLEAR := 28.0
const HIDE_REACH := 4
const LAY_LOW := 2.0
const COVER_MAX := 45.0
const HIDES_MAX := 4
## How close the hero may stand to the drain (metres) for him to come out, and how close to see him.
const SHY := 12.0
const SEEN := 16.0

## How much room he leaves a villager (metres, centre to centre), and from how many times that he bends his
## way round them and how hard.
const ROOM := 1.3
const AWARE := 1.8
const LEAN_WEIGHT := 1.2
const ARRIVE_FREE := 2.0

## How see-through he is, 0 solid to 1 invisible.
const SEE_THROUGH := 0.65
const SNEAK_SHADER := preload("res://shaders/ghoul_sneak.gdshader")
## Marks the see-through materials he wears (for the tests).
const SEE_THROUGH_META := "see_through"

## The mist's colour: a cold pale grey.
const FOG := Color(0.7, 0.74, 0.8)

const SPOTTED := "Eine Gestalt huscht durch die dunklen Gassen. Auf dem Rücken trägt sie etwas, das klirrt."
const MORNING := "Am Morgen fehlen im Dorf wieder ein paar Kerzen, Äpfel und ein Löffel. Wer wohl nachts durch die Gassen schleicht?"
const CAUGHT := "„Erwischt!“ Spooknortz lässt das Bündel fallen und rennt zum Gully zurück."
const EMPTY := "Spooknortz legt den Finger an die Lippen und huscht weiter. Noch hat er nichts gestohlen."
const NOT_NOW := "Du hast das Diebesgut schon. Spooknortz huscht davon."
const FULL := "Spooknortz lässt das Bündel fallen, aber deine Tasche ist voll. Er rafft es wieder an sich und huscht davon."

enum { IDLE, WALK, LINGER_AT, FLEE, HIDE, COVER }

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
## The cell his current leg leads to, how many times he hid tonight (and in all), how long he has lain
## low and how long since he last looked for the guard.
var _goal := Vector2i.ZERO
var hid_tonight := 0
var hid := 0
var _cover_clock := 0.0
var _cover_wait := 0.0
var _guard_clock := 0.0


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
		hid_tonight = 0
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
	_guard_clock += delta
	if state in [WALK, LINGER_AT] and _guard_clock >= 0.25:
		_guard_clock = 0.0
		var guard := _guard_near(figure.global_position, DODGE, true)
		if guard != null:
			_take_cover(guard)
	match state:
		WALK, FLEE, HIDE:
			_walk(delta)
		LINGER_AT:
			_wait -= delta
			if _wait <= 0.0:
				_steal()
				_next_leg()
		COVER:
			_cover_clock += delta
			if _guard_near(figure.global_position, CLEAR, false) != null and _cover_clock < COVER_MAX:
				_cover_wait = LAY_LOW
			else:
				_cover_wait -= delta
			if _cover_wait <= 0.0:
				_come_out()


func _can_come_out(game: Node) -> bool:
	if Spooknortz.slain(game) or Spooknortz.hostile():
		return false
	if not village_asleep() or _guard_near(level.cell_to_world(START), DODGE, true) != null:
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
	# A sneak slips between people: nobody bumps into his body or gets stuck on it.
	figure.collision_layer = 0
	figure.collision_mask = 0
	var fog := _make_fog()
	figure.add_child(fog)
	fog.emitting = true
	_stoop()
	_fade()
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
	if not _path.is_empty():
		_goal = level.world_to_cell(_path[_path.size() - 1])
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
	# Like every walker he leaves the others room: his way bends round whoever is near, and where
	# the step would still carry him into someone he stops a moment and lets them pass.
	# (Within ARRIVE_FREE of the point he is making for he is left alone, so that he gets there.)
	var step := dir * speed * delta
	if dist > ARRIVE_FREE:
		dir = (dir + _lean_from_people() * LEAN_WEIGHT).normalized()
		step = _clear_step(dir * speed * delta)
	if step == Vector3.ZERO:
		_idle_pose(false)
		return
	figure.global_position += step
	figure._model.rotation.y = lerp_angle(figure._model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * delta))
	_idle_pose(true, speed)


## The lean away from the villagers and the wandering merchant who are close, flat (see Villager._separation).
func _lean_from_people() -> Vector3:
	var lean := Vector3.ZERO
	for o: Variant in level.people():
		if not is_instance_valid(o) or not o.visible or o.at_home:
			continue
		var away: Vector3 = figure.global_position - o.global_position
		away.y = 0.0
		var dist := away.length()
		if dist >= ROOM * AWARE:
			continue
		var out := away / dist if dist >= 0.01 else Vector3(1, 0, 0)
		lean += out * (1.0 - (dist - ROOM) / (ROOM * (AWARE - 1.0)) if dist > ROOM else 1.0)
	return lean


## Whether he may stand at `at`: open ground, and nobody within the room a villager leaves.
func _free_at(at: Vector3) -> bool:
	if level.astar.is_point_solid(level.world_to_cell(at)):
		return false
	for o: Variant in level.people():
		if not is_instance_valid(o) or not o.visible or o.at_home:
			continue
		var d: Vector3 = at - o.global_position
		d.y = 0.0
		if d.length() < ROOM * 0.7:
			return false
	return true


## `step` itself when he may take it, else the same step turned a little to either side, else nothing.
func _clear_step(step: Vector3) -> Vector3:
	var here := figure.global_position
	if _free_at(here + step):
		return step
	for turn in [0.6, -0.6, 1.2, -1.2]:
		var s := step.rotated(Vector3.UP, turn)
		if _free_at(here + s):
			return s
	# Already inside someone (they walked up to him): any step that gets him further out is fine.
	if not _free_at(here):
		for turn in [0.0, 0.6, -0.6, 1.2, -1.2]:
			var s := step.rotated(Vector3.UP, turn)
			if _nearest_person(here + s) > _nearest_person(here):
				return s
	return Vector3.ZERO


## How far the nearest villager is from `at` (metres, flat).
func _nearest_person(at: Vector3) -> float:
	var best := INF
	for o: Variant in level.people():
		if not is_instance_valid(o) or not o.visible or o.at_home:
			continue
		var d: Vector3 = at - o.global_position
		d.y = 0.0
		best = minf(best, d.length())
	return best


## The sneaking pose: bent forward and low, walking or standing.
func _stoop() -> void:
	if figure == null or not is_instance_valid(figure) or figure._model == null:
		return
	figure._model.rotation.x = SNEAK_LEAN
	figure._model.position.y = -SNEAK_DIP


## The wisp of mist he trails: a few small, faint puffs that rise from round his feet and hem and stay
## behind where he walked, so that a thin skirt of fog follows him without hiding him.
static func make_fog() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Fog"
	p.amount = 14
	p.lifetime = 2.4
	p.local_coords = false
	p.mesh = Effects._quad(1.1, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3.UP
	p.spread = 60.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.16
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(FOG, 0.0))
	ramp.add_point(0.25, Color(FOG, 0.32))
	ramp.add_point(0.7, Color(FOG, 0.22))
	ramp.set_color(ramp.get_point_count() - 1, Color(FOG, 0.0))
	p.color_ramp = ramp
	p.position.y = 0.3
	Effects.start_cold(p)
	return p


## Makes him half see-through: he is sneaking, a shadow among the shadows (see SEE_THROUGH).
func _fade() -> void:
	if figure == null or not is_instance_valid(figure) or figure._model == null:
		return
	for mi: MeshInstance3D in figure._model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var active := mi.get_active_material(i)
			var shown := 1.0 - SEE_THROUGH
			if active is ShaderMaterial and (active as ShaderMaterial).shader == Enemy.GHOUL_SHADER:
				# His rotten skin (see Enemy._rot_skin), the same, with an alpha.
				var skin := (active as ShaderMaterial).duplicate() as ShaderMaterial
				skin.shader = SNEAK_SHADER
				skin.set_shader_parameter("alpha", shown)
				skin.set_meta(SEE_THROUGH_META, true)
				mi.set_surface_override_material(i, skin)
			elif active is BaseMaterial3D:
				var m := active.duplicate() as BaseMaterial3D
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color.a = m.albedo_color.a * shown
				m.set_meta(SEE_THROUGH_META, true)
				mi.set_surface_override_material(i, m)


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
	if state == HIDE:
		state = COVER
		_cover_wait = LAY_LOW
		_cover_clock = 0.0
		_idle_pose(false)
	elif state == FLEE:
		_home()
	elif _lingers:
		state = LINGER_AT
		_wait = LINGER
		_idle_pose(false)
	else:
		_home()


## He takes something from the house: a sack hangs on his back from the first theft on.
## The nearest guard within `radius` metres of `from`, and (with `seen`) with a clear line of sight to it;
## null when there is none.
func _guard_near(from: Vector3, radius: float, seen: bool) -> Villager:
	var best: Villager = null
	var best_d := radius
	for v: Variant in level.villagers:
		if not is_instance_valid(v) or v.role != GUARD_ROLE or v.at_home or not v.visible:
			continue
		var d := _flat(v.global_position, from)
		if d < best_d and (not seen or level.has_line_of_sight(v.global_position, from)):
			best = v
			best_d = d
	return best


## The guard comes: he slips off to the nearest spot the guard cannot see (or gives up and goes home).
func _take_cover(guard: Villager) -> void:
	var here := level.world_to_cell(figure.global_position)
	if hid_tonight >= HIDES_MAX:
		_run_home(here)
		return
	var spot := _cover_cell(guard, here)
	if spot == here and level.has_line_of_sight(guard.global_position, figure.global_position):
		_run_home(here)
		return
	hid += 1
	hid_tonight += 1
	_path = _points(here, spot)
	_at = 1 if _path.size() > 1 else 0
	state = HIDE if _path.size() > 1 else COVER
	_cover_wait = LAY_LOW
	_cover_clock = 0.0
	_idle_pose(false)


## He gives the round up and heads for the drain.
func _run_home(here: Vector2i) -> void:
	_legs = []
	_goal = START
	_lingers = false
	_path = _points(here, START)
	_at = 1 if _path.size() > 1 else 0
	state = WALK


## A cell near `here` the guard cannot see, reached without going towards him; `here` when there is none.
func _cover_cell(guard: Villager, here: Vector2i) -> Vector2i:
	var gpos := guard.global_position
	var mine := figure.global_position
	var best := here
	var best_score := INF
	for dy in range(-HIDE_REACH, HIDE_REACH + 1):
		for dx in range(-HIDE_REACH, HIDE_REACH + 1):
			var c := here + Vector2i(dx, dy)
			if (dx == 0 and dy == 0) or Vector2(dx, dy).length() > HIDE_REACH or not level.astar.is_in_boundsv(c) or level.astar.is_point_solid(c):
				continue
			var w := level.cell_to_world(c)
			if level.has_line_of_sight(gpos, w) or _flat(gpos, w) < _flat(gpos, mine) - 1.0:
				continue
			var way := level.astar.get_id_path(here, c)
			if way.is_empty() or way.size() > HIDE_REACH + 4:
				continue
			var safe := true
			for p: Vector2i in way:
				if _flat(gpos, level.cell_to_world(p)) < 5.0:
					safe = false
					break
			if not safe:
				continue
			var score := float(way.size()) - _flat(gpos, w) * 0.2
			if score < best_score:
				best = c
				best_score = score
	return best


## The guard has gone: he sets out for his goal again.
func _come_out() -> void:
	var here := level.world_to_cell(figure.global_position)
	var way := _points(here, _goal)
	if way.is_empty() and here != _goal:
		_run_home(here)
		return
	_path = way
	_at = 1 if _path.size() > 1 else 0
	state = WALK
	_idle_pose(false)


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
	# Pale burlap (FRESH keeps the colour bright in the dark), a plump belly, a gathered neck and a twine tie.
	var burlap := Color(0.72, 0.6, 0.4)
	var f := Sewers.W.FRESH
	b.cylinder(Vector3(0, 0.5, -0.32), 0.22, 0.26, 0.4, burlap, f, 12)
	b.cylinder(Vector3(0, 0.82, -0.32), 0.26, 0.14, 0.22, burlap * 0.95, f, 12)
	b.cylinder(Vector3(0, 1.02, -0.32), 0.14, 0.07, 0.14, burlap, f, 10)
	b.cylinder(Vector3(0, 1.06, -0.32), 0.085, 0.085, 0.03, Color(0.45, 0.33, 0.2), f, 8)
	b.box(Vector3(0, 0.55, -0.58), Vector3(0.03, 0.4, 0.02), burlap * 0.75, f)
	b.finish(n, Vector3.ZERO, true, true)
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
