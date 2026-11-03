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
	return seat.pos + front(seat) * SIT_FORWARD


## Where a hero `radius` wide stands up again: just in front of the seat,
## clear of its collision. A bench with its front to a wall or a tree is
## left from behind instead.
static func stand_spot(seat: Dictionary, level: Level, radius: float) -> Vector3:
	var size: Vector3 = seat.get("size", BENCH_SIZE)
	var out := size.z * 0.5 + radius + STAND_GAP
	var ahead := front(seat)
	var beyond := level.world_to_cell(seat.pos + ahead * Level.TILE)
	var behind := level.world_to_cell(seat.pos - ahead * Level.TILE)
	if level.astar.is_in_boundsv(beyond) and level.astar.is_point_solid(beyond) \
			and level.astar.is_in_boundsv(behind) and not level.astar.is_point_solid(behind):
		ahead = -ahead
	return seat.pos + ahead * out
