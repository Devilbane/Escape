class_name WalkRules
extends RefCounted
## The rules everyone who walks the village and the woods keeps, villagers and
## animals alike (see Villager, Animal, FarmAnimal, Squirrel, VillageBirds):
## - nobody steps into a wall brick or a shut gate (an old step, a push or a walk
##   along a path made before the gate shut are all refused);
## - a refused walker stands still (idle legs, no gliding), waits MAKE_WAY seconds
##   and then looks for another way;
## - paths run along the tile centres, shifted by at most JITTER metres, so a walker
##   never cuts across a neighbouring tile;
## - bodies swing round to the way they go at TURN_RATE, they never snap.

## How far a path point may lie off its tile's centre (metres).
const JITTER := 0.6
## How long a walker waits in front of something in the way before it looks for another route (seconds).
const MAKE_WAY := 1.4
## How fast a body turns to face its way (per second, see turn()).
const TURN_RATE := 8.0


## Whether a point is inside a wall brick that stops everyone: a standing wall or a shut gate.
static func blocked_at(level: Object, point: Vector3) -> bool:
	if level == null:
		return false
	var wall = level.get("village_wall")
	if wall == null:
		return false
	var brick = wall.brick_at(level.world_to_cell(point))
	return brick != null and brick.blocks()


## Whether a body at `from` may move to `to`. Something already caught inside a
## block may always step out of it. `strict` (for moves that do not follow a path:
## a dog running up to the hero, a charge) also keeps it on walkable ground.
static func can_step(level: Object, from: Vector3, to: Vector3, strict := false) -> bool:
	if blocked_at(level, to) and not blocked_at(level, from):
		return false
	if strict and level != null and level.has_method("is_open"):
		var there: Vector2i = level.world_to_cell(to)
		if there != level.world_to_cell(from) and not level.is_open(there):
			return false
	return true


## The path along the tiles from `from` to `to`, each point shifted by up to JITTER
## (none with `exact`). Empty when there is no way.
static func path(level: Object, from: Vector3, to: Vector3, rng: RandomNumberGenerator, exact := false) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var cells: Array[Vector2i] = level.grid_path(level.world_to_cell(from), level.world_to_cell(to))
	for c in cells.slice(1):
		var p: Vector3 = level.cell_to_world(c)
		if not exact:
			p += Vector3(rng.randf_range(-JITTER, JITTER), 0.0, rng.randf_range(-JITTER, JITTER))
		out.append(p)
	return out


## Turns a body smoothly towards `direction` (flat), `rate` times per second.
static func turn(body: Node3D, direction: Vector3, delta: float, rate := TURN_RATE) -> void:
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	body.rotation.y = lerp_angle(body.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * rate))
