class_name DragonHelpers
extends Node3D
## The old dragon's little helpers out in the open (see DragonHoard): at night
## small dragonlings flutter out of the lair's stone arch, one after another,
## each to something lying on the ground. It snatches it up, flies back into
## the mountain with it, and the hoard grows (Events.bus().loot_carried_off).
##
## They are shy: they wait while the hero stands right beside a thing, so
## nothing is snatched from under the hero's feet, and what the hero picks
## up first stays the hero's. They leave nothing behind: the more lies
## about, the more of them come out and the quicker (see out_limit). They
## collect only at night: at daybreak whoever is still out flies home (with
## what it already holds), and what still lies about waits on the ground for
## the next night. By day they stay in the mountain. They are no foes: they
## cannot be fought and do no harm.

## At least this many out at once, one more every SPAWN_GAP seconds; with
## much lying about up to MAX_OUT, one every MIN_GAP seconds.
const MIN_OUT := 4
const MAX_OUT := 12
const SPAWN_GAP := 2.5
const MIN_GAP := 0.6
## How fast they fly (metres per second) and how high over the ground.
const SPEED := 7.0
const FLY_HEIGHT := 3.2
## They keep this far (metres) from the hero: a thing closer to the hero is
## left alone for now.
const SHY := 3.5
## The size of the dragon's model on them, and their ember-red tint.
const MODEL_SCALE := 0.16
## How near (metres) to a tile point of their way they count it as reached.
const WAY_REACHED := 1.0
## What a tile beside an obstacle costs, against an open one (see way_round).
const CLOSE := 4.0
## Scale colours: each dragonling gets one of these (ember, amber, moss, teal,
## violet, rose) and a glowing eye that stands out against it.
const SCALES: Array[Color] = [
	Color(1.0, 0.45, 0.25), Color(0.95, 0.72, 0.25), Color(0.5, 0.8, 0.35),
	Color(0.3, 0.75, 0.75), Color(0.65, 0.45, 0.9), Color(0.95, 0.45, 0.65),
]
const EYE_COLOUR := Color(1.0, 0.95, 0.5)
## Each one flies at its own pace: its speed is SPEED times a factor in this
## range, and it bobs and weaves a little around the way so the swarm looks alive.
const PACE_MIN := 0.75
const PACE_MAX := 1.25
const BOB := 0.35
const WEAVE := 0.3
## How fast (radians per second) they can swing round: a change of direction
## is a smooth curve, not a snap. Near the goal they turn tighter, so they
## never circle it. They lean into a turn up to BANK radians.
const TURN := 9.0
const TURN_CLOSE := 14.0
const CLOSE_TO_GOAL := 2.0
const BANK := 0.5

var level: Level
## Where they come out and go back in: the front of the arch.
var den := Vector3.ZERO
## The helpers out now: {"node", "target" (the pickup), "carry" (its node,
## once snatched), "home" (flying back)}.
var helpers: Array = []
var _spawn_timer := 0.0
## Their own random numbers: the looks must not disturb the game's (map and
## village generation draw from the global ones).
var _rng := RandomNumberGenerator.new()


func _init(l: Level, at: Vector3) -> void:
	level = l
	den = at
	_rng.randomize()
	name = "DragonHelpers"


func is_night() -> bool:
	return level is Outdoor and (level as Outdoor).night


## Whether they are out at work: only at night.
func at_work() -> bool:
	return is_night()


## How many may be out at once: more the more lies about.
static func out_limit(lying: int) -> int:
	return clampi(MIN_OUT + lying / 3, MIN_OUT, MAX_OUT)


## How long until the next one comes out: shorter the more lies about.
static func spawn_gap(lying: int) -> float:
	return maxf(MIN_GAP, SPAWN_GAP / (1.0 + lying / 4.0))


func _process(delta: float) -> void:
	_spawn_timer = maxf(0.0, _spawn_timer - delta)
	if at_work() and _spawn_timer <= 0.0:
		var lying := _wanted().size()
		if helpers.size() < out_limit(lying):
			var target := _next_target()
			if not target.is_empty():
				_send_out(target)
				_spawn_timer = spawn_gap(lying)
	for h in helpers.duplicate():
		_fly(h, delta)


## What they are after now: everything on the floor list.
func _wanted() -> Array:
	return level.floor_pickups()


## The nearest thing on the ground to the den no helper is after yet and the
## hero does not stand beside.
func _next_target() -> Dictionary:
	var best := {}
	var best_dist := INF
	for p in _wanted():
		if helpers.any(func(h): return is_same(h.target, p)) or _hero_near(p.node.global_position):
			continue
		var d := _flat(p.node.global_position - den)
		if d < best_dist:
			best_dist = d
			best = p
	return best


func _hero_near(pos: Vector3) -> bool:
	var hero: Node3D = level.player
	return hero != null and is_instance_valid(hero) and _flat(hero.global_position - pos) < SHY


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _send_out(target: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Drachling"
	add_child(node)
	node.global_position = den + Vector3(0, 1.4, 0)
	var model: Node3D = load("res://assets/lair/Dragon.fbx").instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	node.add_child(model)
	var tint: Color = SCALES[_rng.randi() % SCALES.size()]
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		var is_eye := "eye" in String(mi.name).to_lower()
		mat.albedo_color = EYE_COLOUR if is_eye else tint
		mat.emission_enabled = true
		mat.emission = EYE_COLOUR if is_eye else tint
		mat.emission_energy_multiplier = 1.6 if is_eye else 0.35
		mi.material_override = mat
	var pace := _rng.randf_range(PACE_MIN, PACE_MAX)
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("DragonArmature|Dragon_Flying"):
		anim.get_animation("DragonArmature|Dragon_Flying").loop_mode = Animation.LOOP_LINEAR
		anim.play("DragonArmature|Dragon_Flying")
		anim.speed_scale = 1.8 * pace
		anim.seek(_rng.randf() * 0.8, true)
	var glow := OmniLight3D.new()
	glow.light_color = tint
	glow.light_energy = 0.9
	glow.omni_range = 2.5
	node.add_child(glow)
	helpers.append({"node": node, "target": target, "carry": null, "home": false,
		"pace": pace, "model": model, "phase": _rng.randf() * TAU})


func _fly(h: Dictionary, delta: float) -> void:
	var node: Node3D = h.node
	if not is_instance_valid(node):
		helpers.erase(h)
		return
	var goal: Vector3
	if h.home:
		goal = den + Vector3(0, 1.4, 0)
	else:
		# The day broke, the hero picked it up first, or walked up to it: back home.
		if not at_work() or not level._pickups.has(h.target) or not is_instance_valid(h.target.node) or _hero_near(h.target.node.global_position):
			h.home = true
			return
		var at: Vector3 = h.target.node.global_position
		var left := _flat(at - node.global_position)
		# High over the ground on the way, down to the thing at the end.
		goal = Vector3(at.x, lerpf(at.y + 0.6, FLY_HEIGHT, clampf(left / 6.0, 0.0, 1.0)), at.z)
	var step := goal - node.global_position
	var move := SPEED * float(h.get("pace", 1.0)) * delta
	# Round the buildings: follow the way on the tiles; only the last stretch is straight.
	var via: Variant = _via(h, goal)
	if via != null:
		var to_via: Vector3 = via - node.global_position
		step = Vector3(to_via.x, step.y, to_via.z)
	if step.length() <= move:
		node.global_position = goal
		if h.home:
			_go_in(h)
		else:
			_snatch(h)
		return
	# Turn gradually towards the wanted direction and fly along the curve.
	var want := Vector3(step.x, 0, step.z)
	var heading: Vector3 = h.get("heading", Vector3.ZERO)
	if heading == Vector3.ZERO:
		heading = want.normalized() if want.length() > 0.001 else Vector3.BACK
	var turned := 0.0
	if want.length() > 0.05:
		var close := _flat(goal - node.global_position) < CLOSE_TO_GOAL
		var limit := (TURN_CLOSE if close else TURN) * delta
		turned = clampf(heading.signed_angle_to(want.normalized(), Vector3.UP), -limit, limit)
		heading = heading.rotated(Vector3.UP, turned).normalized()
	h["heading"] = heading
	node.rotation.y = atan2(heading.x, heading.z)
	var rise := clampf(step.y, -move, move)
	var along := sqrt(maxf(0.0, move * move - rise * rise))
	node.global_position += heading * along + Vector3(0, rise, 0)
	# Lean into the turn, easing in and out.
	var lean := clampf(-turned / maxf(delta, 0.0001) / TURN, -1.0, 1.0) * BANK
	var model: Node3D = h.get("model")
	if model != null and is_instance_valid(model):
		model.rotation.z = lerpf(model.rotation.z, lean, clampf(8.0 * delta, 0.0, 1.0))
	_sway(h)


## A visual wobble only (the way itself stays straight): up and down, and a
## little sideways, each helper out of step with the others.
func _sway(h: Dictionary) -> void:
	var model: Node3D = h.get("model")
	if model == null or not is_instance_valid(model):
		return
	var t := Time.get_ticks_msec() / 1000.0 * float(h.pace) * 2.2 + float(h.phase)
	model.position = Vector3(sin(t * 0.7) * WEAVE, sin(t) * BOB, 0)


## The next tile point on the way round buildings and other obstacles to the
## goal, or null when the way is straight (or none is found). The way is found
## once per leg (to the thing, then home), with no random numbers.
func _via(h: Dictionary, goal: Vector3) -> Variant:
	var node: Node3D = h.node
	var leg: int = 1 if h.home else 0
	if h.get("leg", -1) != leg:
		h["leg"] = leg
		h["way"] = way_round(level, node.global_position, goal)
	var way: Array = h["way"]
	while way.size() > 1 and _flat(way[0] - node.global_position) < WAY_REACHED:
		way.pop_front()
	# The last tile point is the goal's own tile: head for the goal itself from there.
	if way.size() <= 1:
		return null
	return way[0]


## The way to `to` on the tiles, steering clear of buildings, trees and walls
## where the lanes allow: the dragonling's wings and the eaves reach further
## than a tile's own edge, so a walker's path hugging a wall would clip it. A
## tile beside an obstacle costs CLOSE times as much as an open one, so the way
## squeezes along a wall only where there is no roomier way round. A nook the
## tiles close off only corner to corner (the hero squeezes in between a tree
## and a lamp, say) is left through that gap: never straight through a
## building on the way home.
static func way_round(lvl: Level, from: Vector3, to: Vector3) -> Array[Vector3]:
	var a := lvl.world_to_cell(from)
	var b := lvl.world_to_cell(to)
	if not lvl.astar.is_in_boundsv(a) or not lvl.astar.is_in_boundsv(b):
		return WalkRules.path(lvl, from, to, null, true)
	var grid := _flight_grid(lvl, AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES)
	# Where it sets out it may stand in a solid tile (the arch).
	grid.set_point_solid(a, false)
	var cells := grid.get_id_path(a, b, true)
	if cells.is_empty() or cells[-1] != b:
		# No way on the tiles: let it slip between two corners.
		var loose := _flight_grid(lvl, AStarGrid2D.DIAGONAL_MODE_ALWAYS)
		loose.set_point_solid(a, false)
		var squeezed := loose.get_id_path(a, b, true)
		if not squeezed.is_empty() and (cells.is_empty() or squeezed[-1] == b):
			cells = squeezed
	if cells.is_empty():
		return WalkRules.path(lvl, from, to, null, true)
	var out: Array[Vector3] = []
	for c: Vector2i in cells.slice(1):
		out.append(lvl.cell_to_world(c))
	return out


## The level's tiles for a flyer: its obstacles solid, and the tiles beside
## them CLOSE times as dear as open ones.
static func _flight_grid(lvl: Level, diagonals: AStarGrid2D.DiagonalMode) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = lvl.astar.region
	grid.cell_size = lvl.astar.cell_size
	grid.diagonal_mode = diagonals
	grid.update()
	var size := grid.region.size
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if not lvl.astar.is_point_solid(c):
				continue
			grid.set_point_solid(c, true)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := c + Vector2i(dx, dy)
					if grid.is_in_boundsv(n):
						grid.set_point_weight_scale(n, CLOSE)
	return grid


## Snatches the thing up: off the floor, held under the helper, and away.
func _snatch(h: Dictionary) -> void:
	var p: Dictionary = h.target
	var entry: Array = p.floor
	var carried := level.take_from_floor(p)
	h.home = true
	if carried == null:
		return
	Events.carried_off(str(entry[0]), str(entry[1]), CoinPile.count_of(entry))
	carried.reparent(h.node, false)
	carried.position = Vector3(0, -0.5, 0)
	carried.scale = Vector3.ONE * 0.6
	for light in carried.find_children("*", "OmniLight3D", true, false):
		light.queue_free()
	h.carry = carried


## Home in the mountain: it shrinks into the arch and is gone.
func _go_in(h: Dictionary) -> void:
	helpers.erase(h)
	var node: Node3D = h.node
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.01, 0.3)
	tween.tween_callback(node.queue_free)
