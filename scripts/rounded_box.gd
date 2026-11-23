class_name RoundedBox
extends RefCounted
## A box with rounded edges and corners, built in code, for pieces that should look hewn or worn
## rather than cut from a perfect block: the granite of the village wall (see Granite) and the
## planks and iron fittings of its gates (see GateWood).
##
## The box is laid out on a grid per face. Every grid point is pulled onto a rounded box (a
## rectangle shrunk by `radius`, then swelled by the same radius), so the edges bend over several
## small steps. `chips` then nibble the surface inwards by a random amount, how much depending on
## where the point lies: on a flat face, near an edge, or at a corner. Corners and edges end up
## chipped and uneven while the faces stay nearly flat. Points shared by two faces are one
## vertex, so the surface is closed and its normals are smooth.

## The distance from an edge (as a share of the radius) of the extra rings that round it off.
const RING := 0.3


## The mesh of a box of half extents `half` centred on the origin and then moved by `offset`.
## - radius: how round the edges are (metres); less than every half extent.
## - splits: how many cells the flat middle of each axis is cut into (at least 1).
## - chips: the deepest chip (metres) on a flat face, near an edge and at a corner.
## - smooth: more rings across each rounded edge (a rounder edge, more triangles).
static func make(half: Vector3, radius: float, splits: Vector3i, chips: Array, seed: int, offset := Vector3.ZERO, smooth := true) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var inner := half - Vector3.ONE * radius
	var coords: Array = []
	for a in 3:
		coords.append(_coords(half[a], radius, splits[a], smooth))
	var verts: Array[Vector3] = []
	var index_of := {}
	var grids: Array = []
	for axis in 3:
		for side in [-1.0, 1.0]:
			var a := (axis + 1) % 3
			var b := (axis + 2) % 3
			var grid: Array = []
			for i in coords[a].size():
				var row: Array[int] = []
				for j in coords[b].size():
					var p := Vector3.ZERO
					p[axis] = side * half[axis]
					p[a] = coords[a][i]
					p[b] = coords[b][j]
					var key := Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))
					if not index_of.has(key):
						index_of[key] = verts.size()
						verts.append(_shaped(p, half, inner, radius, chips, rng))
					row.append(index_of[key])
				grid.append(row)
			grids.append(grid)
	var indices := PackedInt32Array()
	var normals: Array[Vector3] = []
	normals.resize(verts.size())
	normals.fill(Vector3.ZERO)
	for grid in grids:
		for i in grid.size() - 1:
			for j in grid[i].size() - 1:
				var a: int = grid[i][j]
				var b: int = grid[i + 1][j]
				var c: int = grid[i + 1][j + 1]
				var d: int = grid[i][j + 1]
				_triangle(verts, normals, indices, a, b, c)
				_triangle(verts, normals, indices, a, c, d)
	var vertex_array := PackedVector3Array()
	var normal_array := PackedVector3Array()
	for i in verts.size():
		vertex_array.append(verts[i] + offset)
		normal_array.append(normals[i].normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The grid lines along one axis, from -half to half: the edges' rings, then the flat middle.
static func _coords(half: float, radius: float, splits: int, smooth: bool) -> Array[float]:
	var inner := half - radius
	var out: Array[float] = [-half]
	if smooth:
		out.append(-inner - radius * (1.0 - RING))
	out.append(-inner)
	for k in range(1, splits):
		out.append(-inner + 2.0 * inner * k / splits)
	out.append(inner)
	if smooth:
		out.append(inner + radius * (1.0 - RING))
	out.append(half)
	out.sort()
	return out


## Where a point of the box's surface ends up: pulled onto the rounded box, then chipped.
static func _shaped(p: Vector3, half: Vector3, inner: Vector3, radius: float, chips: Array, rng: RandomNumberGenerator) -> Vector3:
	var core := p.clamp(-inner, inner)
	var out := (p - core).normalized()
	var pos := core + out * radius
	# How many axes the point is in the rounded band of: 1 on a flat face, 2 at an edge, 3 at a corner.
	var bands := 0
	for a in 3:
		if absf(p[a]) > inner[a] + 0.0001:
			bands += 1
	var chip: float = chips[bands - 1]
	if chip > 0.0:
		pos -= out * rng.randf() * chip
		if bands >= 2:
			pos += Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * chip * 0.35
	return pos


## One triangle, wound clockwise as seen from outside (the box is centred on the origin), its
## area-weighted normal added to its three vertices.
static func _triangle(verts: Array[Vector3], normals: Array[Vector3], indices: PackedInt32Array, a: int, b: int, c: int) -> void:
	var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	var outward := (verts[a] + verts[b] + verts[c]) / 3.0
	if n.dot(outward) > 0.0:
		var swap := b
		b = c
		c = swap
		n = -n
	# `n` now faces inwards; the normals point outwards.
	for i in [a, b, c]:
		normals[i] -= n
	indices.append(a)
	indices.append(b)
	indices.append(c)
