class_name Seats
## Places where the hero can sit down: the benches on the market square.
##
## A seat is a station of kind KIND (see Level.stations), so the hero sits
## the way they use everything else: run into it, or click it and the hero
## walks up to it first. They sit facing the way the seat faces (a bench on
## the square faces the fountain) with the chair animations.
##
## Sitting never holds the hero (see Player.sit_down): any step, click, jump,
## attack or blow stands them up at once, and the same input moves them. A
## hero who keeps pushing into the bench after standing up is not sat down
## again until they let go (see Player.still_getting_up).
##
## Townsfolk with nothing to do rest on the benches by the fountain now and
## then (see BenchRest); a bench someone sits on does not seat the hero.
##
## A new kind of seat (a stool, a chair) only needs its model, a collision box
## that fits it, and a station from Seats.station with its own size.

const KIND := "sitz"

## The bench model (assets/graveyard/bench.gltf) is 2.0 x 0.5 x 0.75 metres,
## placed 1.3 times as big: long side along its own x, seat facing its +z.
const BENCH_SCALE := 1.3
const BENCH_SIZE := Vector3(2.0, 0.5, 0.75) * BENCH_SCALE

## Where the hero's feet go while sitting: on the ground this far in front of
## the seat's middle. The chair animation then puts them on the seat (it
## fits the bench's height as it is).
const SIT_FORWARD := 0.12
## The gap between the front of the seat and the hero when they stand up.
const STAND_GAP := 0.15


## Seats in a building (a chair, a stool, a bench or a sofa in a hall, see add_indoor): the hero's hips
## sit this far behind where their feet go (Sit_Chair_Idle, measured from the bones), so a narrow seat
## is entered with the hips over its middle. The outdoor bench is deep enough not to care.
const HIPS_BACK := 0.4
## How high the hero's hips are over the floor in the sitting animation less a hand: the seat top the
## animation is made for. A seat of another height lifts or lowers the hero by the difference.
const SEAT_TOP := 0.45


## The station of a seat on tile `c`, at `pos`, turned by `rot` (its front
## then faces Vector3(sin(rot), 0, cos(rot))), `size` big as it is drawn.
static func station(c: Vector2i, pos: Vector3, rot: float, size := BENCH_SIZE) -> Dictionary:
	return {"kind": KIND, "cell": c, "pos": pos, "rot": rot, "size": size, "used": false}


## The way someone sitting on the seat looks.
static func front(seat: Dictionary) -> Vector3:
	var rot: float = seat.get("rot", 0.0)
	return Vector3(sin(rot), 0.0, cos(rot))


## Where the hero is put to sit on the seat.
static func sit_spot(seat: Dictionary) -> Vector3:
	return seat.pos + front(seat) * float(seat.get("forward", SIT_FORWARD)) + Vector3(0, float(seat.get("lift", 0.0)), 0)


## Where a hero `radius` wide stands up again: just in front of the seat,
## clear of its collision. A bench with its front to a wall or a tree is
## left from behind instead.
static func stand_spot(seat: Dictionary, level: Level, radius: float) -> Vector3:
	var size: Vector3 = seat.get("size", BENCH_SIZE)
	var out := size.z * 0.5 + radius + STAND_GAP
	var ahead := front(seat)
	if seat.has("stand"):
		return _stand_in_hall(seat, level, radius, out)
	var beyond := level.world_to_cell(seat.pos + ahead * Level.TILE)
	var behind := level.world_to_cell(seat.pos - ahead * Level.TILE)
	if level.astar.is_in_boundsv(beyond) and level.astar.is_point_solid(beyond) \
			and level.astar.is_in_boundsv(behind) and not level.astar.is_point_solid(behind):
		ahead = -ahead
	return seat.pos + ahead * out


## A stool of a hall at `local` (in the hall's frame) turned to face `toward`, a seat for one (see add_indoor).
static func add_stool(walk_in: WalkIn, rec: Dictionary, local: Vector3, toward: Vector3) -> void:
	var turn := atan2(toward.x - local.x, toward.z - local.z)
	add_indoor(walk_in, rec, local, turn, Vector3(0.4, 0.5, 0.4))


## A seat of a hall (see WalkIn): `size` is the furniture's box (x across, z deep, y high) at `local` in the
## hall's frame, turned by `turn` (front +z before turning), `top` the height of its seat. It is solid, so
## the hero runs into it (or clicks it) to sit. `across` lists where along its width a body sits (a bench
## or a sofa seats two). `stand` is 1.0 to get up in front of the seat, -1.0 behind it.
static func add_indoor(walk_in: WalkIn, rec: Dictionary, local: Vector3, turn: float, size: Vector3, top := 0.485, across := [0.0], stand := -1.0) -> void:
	var hall: Node3D = rec.node
	var level := walk_in.level as Level
	var turned := size if absf(sin(turn)) < 0.5 else Vector3(size.z, size.y, size.x)
	walk_in._solid(rec, local + Vector3(0, turned.y * 0.5, 0), turned)
	for along: float in across:
		var at: Vector3 = hall.transform * (local + Basis(Vector3.UP, turn) * Vector3(along, 0, 0))
		var rot := hall.rotation.y + turn
		var seat := station(level.world_to_cell(at), at, rot, Vector3(minf(size.x, 0.5), size.y, size.z))
		seat["indoor"] = true
		seat["forward"] = HIPS_BACK
		seat["lift"] = top - SEAT_TOP
		seat["stand"] = stand
		seat["touch"] = maxf(size.x, size.z) * 0.5 + 0.7
		level.stations.append(seat)


## Where one gets up from a seat of a hall: on the side it prefers (behind it or in front, see add_indoor),
## else the other, else beside it past the end of the furniture: the first place a body `radius` wide fits
## between the tables, the walls and the other seats. Hall floors are not on the level's grid, so this asks
## the physics.
static func _stand_in_hall(seat: Dictionary, level: Level, radius: float, out: float) -> Vector3:
	var ahead := front(seat) * float(seat.stand)
	var side := front(seat).cross(Vector3.UP)
	var tries: Array = [ahead * out, -ahead * out, ahead * (out + 0.25), -ahead * (out + 0.25)]
	for d: float in [0.5, 0.7, 0.9, 1.1, 1.3, 1.5, 1.8]:
		tries.append(side * d)
		tries.append(-side * d)
	# Slantwise, out between two pieces of furniture.
	for turn: float in [PI * 0.25, -PI * 0.25, PI * 0.75, -PI * 0.75]:
		for d: float in [out, out + 0.3]:
			tries.append(ahead.rotated(Vector3.UP, turn) * d)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.8
	var space := level.get_world_3d().direct_space_state
	for step: Vector3 in tries:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), seat.pos + step + Vector3(0, 0.75, 0))
		if level.player != null and level.player is CollisionObject3D:
			query.exclude = [(level.player as CollisionObject3D).get_rid()]
		if space.intersect_shape(query, 1).is_empty():
			return seat.pos + step
	return seat.pos + ahead * out
