class_name IceCover
extends RefCounted
## The ice on the village ponds (see Weather.ice for when it forms and thaws).
##
## While it freezes, ice creeps in from the banks over the water of every pond until only one
## small hole is left in the middle, kept open by the villagers for fishing. Once the pond is
## frozen over, the hero can walk on it (the tiles stop blocking the way), except for the
## tile of the hole, and the line can only be cast into the hole (it is the pond's only
## entry in `Outdoor.fishing_waters`). The way-finding (`Level.astar`) opens the ice too, so a
## click on the hole walks the hero out across the ice to its edge (see Fishing.click_water).
## When the ice thaws, everything is as it was.

const SHADER_HOLES := 4
## How far the open hole reaches from the middle of its tile (metres).
const HOLE_RADIUS := 1.0
## From this much ice on, the pond is solid enough to walk on and to fish through the hole.
const FROZEN_FROM := 0.9

var amount := 0.0
var frozen := false
var level: Level
var ponds: Array
var material: ShaderMaterial
## One entry per pond water: the hole that stays open (see Fishing.WATERS), as a fishing water.
var holes: Array = []


func _init(world: Level, pond_tiles: Array, ground: ShaderMaterial) -> void:
	level = world
	ponds = pond_tiles
	material = ground
	holes = _pick_holes()
	var shown := PackedVector3Array()
	for i in SHADER_HOLES:
		if i < holes.size():
			shown.append(Vector3(holes[i].pos.x, holes[i].pos.z, HOLE_RADIUS))
		else:
			shown.append(Vector3(0, 0, 0))
	if material != null:
		material.set_shader_parameter("ice_holes", shown)
		material.set_shader_parameter("ice", 0.0)


## The tile of each pond (a group of pond tiles that touch) nearest to its middle holds the hole.
func _pick_holes() -> Array:
	var out: Array = []
	var seen := {}
	for w: Dictionary in ponds:
		if seen.has(w.cell):
			continue
		var group: Array = []
		var queue: Array = [w]
		seen[w.cell] = true
		while not queue.is_empty():
			var at: Dictionary = queue.pop_back()
			group.append(at)
			for other: Dictionary in ponds:
				if not seen.has(other.cell) and other.water == w.water \
						and absi(other.cell.x - at.cell.x) + absi(other.cell.y - at.cell.y) == 1:
					seen[other.cell] = true
					queue.append(other)
		var middle := Vector3.ZERO
		for g: Dictionary in group:
			middle += g.pos
		middle /= group.size()
		var best: Dictionary = group[0]
		for g: Dictionary in group:
			if (g.pos - middle).length() < (best.pos - middle).length():
				best = g
		best["hole"] = true
		out.append({"water": best.water, "pos": best.pos, "reach": HOLE_RADIUS, "round": true,
				"surface": best.surface, "ice": true})
	return out


## How thick the ice lies, 0 open water to 1 solid.
func set_amount(value: float) -> void:
	amount = clampf(value, 0.0, 1.0)
	if material != null:
		material.set_shader_parameter("ice", amount)
	var now := amount >= FROZEN_FROM
	if now == frozen:
		return
	frozen = now
	for w: Dictionary in ponds:
		if not w.get("hole", false):
			(w.shape as CollisionShape3D).set_deferred("disabled", frozen)
			if level.astar.is_in_boundsv(w.cell):
				level.astar.set_point_solid(w.cell, not frozen)
		level.fishing_waters.erase(w)
	for h: Dictionary in holes:
		level.fishing_waters.erase(h)
	if frozen:
		level.fishing_waters.append_array(holes)
	else:
		level.fishing_waters.append_array(ponds)
