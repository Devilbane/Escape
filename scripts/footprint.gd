class_name Footprint
extends RefCounted
## Every creature claims its own place in the world: the hero, monsters, villagers, dungeon
## figures and the animals of the woods and the farm each take up a round footprint whose
## radius comes from their template (a monster's size, a villager's scale, an animal's kind).
## Nobody may stand inside another. When it happens anyway (a spawn, a teleport, a saved game
## loading, a call for help), the newest one is moved to the nearest open, reachable spot
## (see settle). Level runs this every few physics ticks.

## Radius (metres) of the animals, by kind (see Animal.KINDS and FarmAnimal.KINDS).
const WILD := {"reh": 0.45, "hirsch": 0.5, "fuchs": 0.3}
## The squirrel of the woods (see Squirrel); pets take the radius of their species (see Pet).
const SQUIRREL := 0.15
const FARM := {"goose": 0.25, "goat": 0.4, "sheep": 0.45, "billy": 0.45, "dog": 0.35, "cow": 0.75, "bull": 0.8}
## Who stands in each other's place only when they come nearer than this share of both radii:
## brushing past and the small give of a crowd are fine, standing inside one another is not.
const STACKED := 0.7
## Standing nearer than this share of both radii is on top of someone: that one is moved to
## a free spot at once. Between DEEP and STACKED the newest is only eased away (NUDGE m/s),
## so a flock or a crowd brushing past each other does not jump about.
const DEEP := 0.35
const NUDGE := 1.5
## Bodies above or below each other by more than this (a hero on a crate, a bird) do not stack.
const HEIGHT_GAP := 1.2
## How far (tiles) the search for a free spot reaches, and how often it runs (physics ticks).
const SEARCH_TILES := 5
const EVERY := 6
## Group every body that takes up room belongs to.
const GROUP := "footprint"


## The footprint radius of a body, from its template.
static func radius_of(body: Node) -> float:
	if body is Enemy or body is Player:
		return body.radius
	if body is Animal or body is Pet:
		return WILD.get(body.kind, 0.4)
	if body is Squirrel:
		return SQUIRREL
	if body is FarmAnimal:
		return FARM.get(body.kind, 0.4)
	if body is Villager:
		return body.radius
	return 0.5


## Whether a body is a peaceful animal: it has no hitbox of its own and claims no place from
## anyone else (a hero, villager or monster may stand where it grazes). Peaceful animals only
## ease away from each other so they do not pile up. The red-horned goat charges, so it claims
## its place like the monsters do.
static func peaceful(body: Node) -> bool:
	if body is Animal or body is Squirrel or body is Pet:
		return true
	return body is FarmAnimal and body.kind != "billy"


## Whether a body counts at all right now: in the world, awake and on the ground.
static func counts(body: Node) -> bool:
	if not is_instance_valid(body) or not body.is_inside_tree() or not (body is Node3D):
		return false
	if "dead" in body and body.dead:
		return false
	if "at_home" in body and body.at_home:
		return false
	if "eaten" in body and body.eaten:
		return false
	# A pet curled up in its basket by the bed, or waking there, stays where it lies.
	if body is Pet and body.state in ["bed", "wake"]:
		return false
	return (body as Node3D).visible


## Whether `body` could be moved: everyone but the hero.
static func movable(body: Node) -> bool:
	return not (body is Player)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Whether two bodies stand inside each other.
static func stacked(a: Node3D, b: Node3D) -> bool:
	if absf(a.global_position.y - b.global_position.y) > HEIGHT_GAP:
		return false
	return _flat(a.global_position, b.global_position) < (radius_of(a) + radius_of(b)) * STACKED


## Whether a body of `radius` at `point` would stand inside any of `others` (but `self_body`).
static func crowded(point: Vector3, radius: float, others: Array, self_body: Node = null) -> bool:
	for o in others:
		if o == self_body:
			continue
		if _flat(point, o.global_position) < (radius + radius_of(o)) * STACKED:
			return true
	return false


## Whether a body may stand at `point` on `level`: walkable ground, no wall or shut gate.
static func open_at(level: Level, point: Vector3) -> bool:
	var c: Vector2i = level.world_to_cell(point)
	if not level.astar.is_in_boundsv(c) or level.astar.is_point_solid(c):
		return false
	if level.has_method("is_open") and not level.is_open(c):
		return false
	return not WalkRules.blocked_at(level, point)


## The nearest open, reachable spot for `body` where nobody stands, or Vector3.INF.
static func free_spot(level: Level, body: Node3D, others: Array) -> Vector3:
	var r := radius_of(body)
	var here: Vector2i = level.world_to_cell(body.global_position)
	var best := Vector3.INF
	var best_d := INF
	var reach := {}
	for ring in range(0, SEARCH_TILES + 1):
		# Rings further out cannot beat a spot found on an earlier ring by more than a tile.
		if best_d < INF and (ring - 1) * Level.TILE > best_d:
			break
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var c := here + Vector2i(dx, dy)
				var centre: Vector3 = level.cell_to_world(c)
				for off in [Vector2.ZERO, Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(0, -1.2)]:
					var p := Vector3(centre.x + off.x, body.global_position.y, centre.z + off.y)
					var d := _flat(p, body.global_position)
					if d >= best_d or not open_at(level, p) or crowded(p, r, others, body):
						continue
					if not reach.has(c):
						reach[c] = c == here or not level.grid_path(here, c).is_empty()
					if reach[c]:
						best = p
						best_d = d
	return best


## Moves `body` to the nearest free spot; tells whether it found one.
static func settle(level: Level, body: Node3D, others: Array) -> bool:
	var spot := free_spot(level, body, others)
	if spot == Vector3.INF:
		return false
	body.global_position = spot
	body.reset_physics_interpolation()
	if body.has_method("footprint_moved"):
		body.footprint_moved()
	return true


## When a body first counted (physics tick), to tell the newest of two apart.
static func born(body: Node) -> int:
	if not body.has_meta("fp_born"):
		body.set_meta("fp_born", Engine.get_physics_frames())
	return body.get_meta("fp_born")


## Whether `a` came after `b` (a tie goes to the later made node).
static func newer(a: Node, b: Node) -> bool:
	var ta := born(a)
	var tb := born(b)
	return ta > tb or (ta == tb and a.get_instance_id() > b.get_instance_id())


## Finds everyone who stands inside another and moves the newest of each pair to a free spot.
## Returns how many were moved. Bodies are bucketed by tile so a crowd costs little.
static func resolve(level: Level) -> int:
	var bodies: Array = []
	for b in level.get_tree().get_nodes_in_group(GROUP):
		if counts(b):
			bodies.append(b)
	# Who claims a place: not the peaceful animals (they are only eased apart from each other).
	var claimers: Array = bodies.filter(func(x): return not peaceful(x))
	var grid := {}
	for b in bodies:
		var c: Vector2i = level.world_to_cell(b.global_position)
		if not grid.has(c):
			grid[c] = []
		grid[c].append(b)
	var moved := 0
	var done := {}
	for b in bodies:
		var c: Vector2i = level.world_to_cell(b.global_position)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for o in grid.get(c + Vector2i(dx, dy), []):
					if o == b or done.has(b) or done.has(o) or not stacked(b, o):
						continue
					# A pet keeps its own gap to the hero (see Pet.FOLLOW_GAP): hopping out of its basket beside the hero is no stacking.
					if (b is Player and o is Pet) or (b is Pet and o is Player):
						continue
					# The newest gives way; the hero never does.
					var mover: Node3D = b if newer(b, o) else o
					var stayer: Node3D = o if mover == b else b
					# One who keeps their spot (a shopkeeper) stays put if the other can move.
					if mover.has_method("keeps_spot") and mover.keeps_spot() and movable(stayer) and not (stayer.has_method("keeps_spot") and stayer.keeps_spot()):
						mover = stayer
					if not movable(mover):
						mover = stayer
					if not movable(mover):
						continue
					# A peaceful animal claims nothing from anyone but its own kind of easy-going company.
					var soft := peaceful(mover) or peaceful(stayer)
					if soft and not (peaceful(mover) and peaceful(stayer)):
						continue
					var gap := _flat(mover.global_position, stayer.global_position)
					var room := (radius_of(mover) + radius_of(stayer)) * STACKED
					if not soft and gap < (radius_of(mover) + radius_of(stayer)) * DEEP:
						if settle(level, mover, claimers):
							done[mover] = true
							moved += 1
					else:
						# Eased away from the other, never into a wall.
						var away := mover.global_position - stayer.global_position
						away.y = 0.0
						if away.length() < 0.01:
							var angle := float(mover.get_instance_id() % 628) / 100.0
							away = Vector3(cos(angle), 0.0, sin(angle))
						var step := minf(room - gap, NUDGE * EVERY / float(Engine.physics_ticks_per_second))
						var to: Vector3 = mover.global_position + away.normalized() * step
						if open_at(level, to):
							mover.global_position = to
							mover.reset_physics_interpolation()
							done[mover] = true
	return moved
