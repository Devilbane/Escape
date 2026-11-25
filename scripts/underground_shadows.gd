class_name UndergroundShadows
extends RefCounted
## The village stands on a stack of buried rooms: the forgotten mine, the sewers, the bank's vault
## and the cellars, thousands of boxes that all cast shadows into every light's shadow map each
## frame, though their stone lies under whole ground and nobody sees it from the street (see
## HouseSketch.BURIED). Only the ones near the hero need to cast: a torch in the mine shadows the
## walls round it, the sun never reaches them.
##
## So every buried piece beyond NEAR_RANGE (metres, flat) of the hero stops casting shadows, and
## starts again when the hero comes near. The pieces are collected once, a moment after the level
## is up; anything built later keeps its shadows, as before. Nothing but the shadow changes: the
## piece is still drawn and lit as ever.

## Pieces nearer than this to the hero cast shadows (further than any torch or lamp shines).
const NEAR_RANGE := 40.0
## Seconds between two looks at who is near.
const EVERY := 0.5
## A piece whose middle is deeper than this lies underground.
const BURIED_Y := -0.5
## Seconds after the level is up before the pieces are collected (the sketches are built by then).
const COLLECT_AFTER := 4.0

var _pieces: Array[GeometryInstance3D] = []
var _flat: Array[Vector2] = []
var _off: Array[bool] = []
var _clock := 0.0
var _age := 0.0
var _collected := false


## Called every frame by the level; `hero` is the hero's position, `root` the node whose buried
## pieces are collected.
func tick(root: Node3D, hero: Vector3, delta: float) -> void:
	_age += delta
	if not _collected:
		if _age < COLLECT_AFTER:
			return
		_collect(root)
		_clock = EVERY
	_clock += delta
	if _clock < EVERY:
		return
	_clock = 0.0
	update(hero)


## Gives every collected piece its shadow back or takes it away, by its distance to `hero`.
func update(hero: Vector3) -> void:
	var here := Vector2(hero.x, hero.z)
	var limit := NEAR_RANGE * NEAR_RANGE
	for i in _pieces.size():
		var far := _flat[i].distance_squared_to(here) > limit
		if far == _off[i]:
			continue
		var piece := _pieces[i]
		if not is_instance_valid(piece):
			continue
		_off[i] = far
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Collects the buried pieces under `root` that cast shadows now.
func _collect(root: Node3D) -> void:
	_collected = true
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON or not g.is_inside_tree():
			continue
		var at := g.global_position
		if at.y > BURIED_Y:
			continue
		_pieces.append(g)
		_flat.append(Vector2(at.x, at.z))
		_off.append(false)


## How many pieces are collected, and how many of them have their shadow off right now.
func counts() -> Vector2i:
	return Vector2i(_pieces.size(), _off.count(true))
