class_name MillTower
extends RefCounted
## The windmill one can walk into (map letter u, see VillageHalls): its ground storey is a hall in
## the village's own style (a VillageHouse of stone with a band of oak beams round its top, no
## upper floor or roof of its own), and on it stands the tower of the old kit windmill with its cap
## and its turning sails (see Windmill), cut off above the kit's own stone base so it stands on the
## new storey. While the hero is inside, the tower hides with the band (WalkIn's "up"), so the
## camera sees into the mill room: the millstones, the sacks of flour and the miller at his counter.

const MODEL := "building_windmill_red"
## Where the kit's tower starts over its own stone base (the kit's metres): everything lower is
## left out, the new stone storey stands in its place.
const CUT := 0.175
## How wide the kit's tower is at the cut (the kit's metres, across), which the scale fits to the
## stone storey below it.
const TOWER_WIDE := 0.76
## How much of the stone storey's width the tower takes.
const FIT := 0.96


## Puts the kit's tower, cap and sails onto the mill's stone storey `mill` (a VillageHouse built
## with VillageHalls.style("u")), returns the tower's node (a child of the level, placed and turned
## with the mill). `put` builds a kit model the way Outdoor does (Outdoor._put).
static func raise(mill: Node3D, put: Callable) -> Node3D:
	var shape: Dictionary = mill.get_meta("shape")
	var s := minf(float(shape.w), float(shape.d)) * FIT / TOWER_WIDE
	var top := VillageHouse.PLINTH + VillageHouse.GROUND
	var at := mill.transform * Vector3(0, top - CUT * s, 0)
	var node: Node3D = put.call(MODEL, at, mill.rotation.y, s)
	node.name = "MillTower"
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) == MODEL:
			mi.mesh = cut_below(mi.mesh, CUT)
	return node


## A copy of `mesh` without the triangles that lie wholly below `y` (its own frame).
static func cut_below(mesh: Mesh, y: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if index.is_empty():
			for i in verts.size():
				index.append(i)
		var kept := PackedInt32Array()
		for t in range(0, index.size() - 2, 3):
			if verts[index[t]].y >= y or verts[index[t + 1]].y >= y or verts[index[t + 2]].y >= y:
				kept.append(index[t])
				kept.append(index[t + 1])
				kept.append(index[t + 2])
		arrays[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(si))
	return out
