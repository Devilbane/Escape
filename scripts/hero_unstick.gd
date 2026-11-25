class_name HeroUnstick
extends RefCounted
## Gets the hero out of a spot they are wedged in (an oddly built corner, a gap of furniture and
## walls that is a hair too narrow).
##
## The hero counts as wedged only when they hold a direction for WEDGE_TIME seconds, get nowhere
## and cannot move a step in ANY direction (or they overlap solid geometry). Merely walking into a
## wall with free ground to the side or behind never counts. A wedged hero is set down on the
## nearest free spot that is on the same side: the spot must fit the body, have ground under it and
## be reachable in a straight line without crossing a wall, a barrier or a locked door, so a nudge
## never leads into a closed area.
##
## The "unstuck" chat command (dev builds only, see ENABLED) does the same on request.
##
## Every text is German and has an English entry in scripts/lang/unstick.gd.

## The one switch that gates the chat command, like Godmode.ENABLED: it belongs to the developer
## version only and is set to false in a player or release build.
const ENABLED := true
const COMMAND := "unstuck"
## How long a direction is held without getting anywhere before the hero counts as wedged (seconds).
const WEDGE_TIME := 1.0
## A step shorter than this fraction of the intended one is "getting nowhere".
const NO_PROGRESS := 0.2
## How far the hero tries to step when probing a direction (metres).
const PROBE := 0.12
## The rings searched for a free spot (metres from the hero) and the spots on each ring.
const RINGS := [0.6, 1.0, 1.5, 2.0, 2.6, 3.4, 4.4]
const SPOTS := 16
## An anchor farther away than this (metres) is out of date (a teleport, a long fall).
const MAX_ANCHOR := 6.0
## Free ground must be this close under a spot (metres), else it is a pit or a ledge.
const GROUND_REACH := 1.2
const DONE_TEXT := "Befreit."
const NONE_TEXT := "Hier ist kein freier Platz in der Nähe."

var _held := 0.0


static func is_command(line: String) -> bool:
	return ENABLED and line.strip_edges().to_lower() == COMMAND


## Called every physics tick: `wants` is whether the hero holds a direction, `got` and `meant`
## are the metres they moved and meant to move. Returns true once the hero has been stuck against
## something for WEDGE_TIME seconds (the caller then checks whether they are truly wedged).
func tick(wants: bool, got: float, meant: float, delta: float) -> bool:
	if not wants or meant <= 0.0 or got >= meant * NO_PROGRESS:
		_held = 0.0
		return false
	_held += delta
	if _held < WEDGE_TIME:
		return false
	_held = 0.0
	return true


## Whether the hero can move a step in no direction at all, or overlaps solid geometry.
static func is_wedged(hero: CharacterBody3D) -> bool:
	if _overlaps(hero, hero.global_transform):
		return true
	for i in 8:
		var a := TAU * i / 8.0
		var motion := Vector3(cos(a), 0.0, sin(a)) * PROBE
		if not hero.test_move(hero.global_transform, motion):
			return false
	return true


## The nearest free spot for the hero on their own side, or Vector3.INF when there is none.
## "Their own side" is the side of `anchor`, the last place they stood free (a hero sunk into
## a thin wall could be on either side of it by their own middle); without one it is where they stand.
static func find_spot(hero: CharacterBody3D, anchor := Vector3.INF) -> Vector3:
	var space := hero.get_world_3d().direct_space_state
	var from := hero.global_position
	if anchor == Vector3.INF or anchor.distance_to(from) > MAX_ANCHOR:
		anchor = from
	var chest := anchor + Vector3(0.0, 1.0, 0.0)
	var inside := _overlaps(hero, hero.global_transform)
	for ring: float in RINGS:
		var best := Vector3.INF
		var best_d := INF
		for i in SPOTS:
			var a := TAU * i / SPOTS
			var spot: Vector3 = from + Vector3(cos(a), 0.0, sin(a)) * ring
			var d := _fits(hero, space, spot, chest, inside)
			if d >= 0.0 and d < best_d:
				best_d = d
				best = spot + Vector3(0.0, d, 0.0)
		if best != Vector3.INF:
			return best
	return Vector3.INF


## Sets the hero on the nearest free spot (see find_spot). Returns whether one was found.
static func release(hero: CharacterBody3D, anchor := Vector3.INF) -> bool:
	var spot: Vector3 = find_spot(hero, anchor)
	if spot == Vector3.INF:
		return false
	hero.global_position = spot
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()
	return true


## The height to stand at on `spot` (relative to the hero's feet; -1 when the spot is no good):
## the body fits there, there is ground under it, and a straight line from the hero crosses nothing.
static func _fits(hero: CharacterBody3D, space: PhysicsDirectSpaceState3D, spot: Vector3, chest: Vector3, inside: bool) -> float:
	var down := PhysicsRayQueryParameters3D.create(spot + Vector3(0.0, 0.6, 0.0), spot + Vector3(0.0, -GROUND_REACH, 0.0), hero.collision_mask, [hero.get_rid()])
	var ground := space.intersect_ray(down)
	if ground.is_empty() or Vector3(ground.normal).y < 0.7:
		return -1.0
	var lift: float = ground.position.y - hero.global_position.y + 0.02
	var t := hero.global_transform
	t.origin = Vector3(spot.x, hero.global_position.y + lift, spot.z)
	if _overlaps(hero, t):
		return -1.0
	var line := PhysicsRayQueryParameters3D.create(chest, Vector3(spot.x, chest.y + lift, spot.z), hero.collision_mask, [hero.get_rid()])
	if not space.intersect_ray(line).is_empty():
		return -1.0
	# The body's own width must clear the line too, or it squeezes through a gap it could not walk.
	# (Not when the hero already overlaps something: every sweep would hit it at once.)
	if not inside and hero.test_move(hero.global_transform, Vector3(spot.x - hero.global_position.x, 0.0, spot.z - hero.global_position.z)):
		return -1.0
	return lift


static func _overlaps(hero: CharacterBody3D, at: Transform3D) -> bool:
	var shape: Shape3D = null
	var offset := Transform3D.IDENTITY
	for child in hero.get_children():
		if child is CollisionShape3D and not child.disabled:
			shape = child.shape
			offset = Transform3D(Basis.IDENTITY, child.position)
			break
	if shape == null:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	# A hair smaller than the body: standing flush against a wall is not overlapping it.
	q.margin = -0.02
	q.transform = at * offset
	q.collision_mask = hero.collision_mask
	q.exclude = [hero.get_rid()]
	return not hero.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
