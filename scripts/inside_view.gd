class_name InsideView
extends RefCounted
## What the hero sees from inside a house: only what a window or an open door
## shows. While the hero stands inside a built house (see HouseGround.shelter)
## or their own house in the village, the villagers and animals out of sight
## (Level.has_line_of_sight: walls, roofs and shut doors hide them) are hidden,
## and come back the moment a window or open door shows them or the hero steps
## outside. Monsters ask Level.hero_sees on their own each tick (see Enemy).

## Seconds between two looks round (the hero cannot turn a wall into a window).
const EVERY := 0.1
## Marks a creature this hid, so only those are shown again.
const HIDDEN := &"hidden_by_walls"

var _wait := 0.0


## Hides or shows the villagers and animals of `level` (an Outdoor) as the hero sees them.
func tick(level: Outdoor, delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = EVERY
	var crowd: Array = []
	crowd.append_array(level.villagers)
	crowd.append_array(level.animals)
	for c in crowd:
		if not is_instance_valid(c) or not c.is_inside_tree():
			continue
		var node := c as Node3D
		var seen := level.hero_sees(node.global_position)
		if not seen and node.visible:
			node.visible = false
			node.set_meta(HIDDEN, true)
		elif seen and node.has_meta(HIDDEN):
			node.remove_meta(HIDDEN)
			# A villager who went home meanwhile stays out of sight.
			node.visible = not (node is Villager and (node as Villager).at_home)
