class_name RoofCaps
extends RefCounted
## Cap shingles along the ridge and the gable edges of a pitched roof: a row of curved ceramic
## tiles, each a little raised at one end so it rests on its neighbour like the ridge tiles of a
## real roof. Without them two slopes meet in a bare, hard line (and, snowed in, a dark thin
## crack). The tiles are made of the aged roof tiles' own sheet (aged_roof.gdshader) and share
## their surface, so they weather with the roof (their vertex colour's green marks them to the shader, which
## samples them softer); snow caps (SnowCaps) lie over them like over
## any other roof.

## How long one cap tile is, and how far the next one starts after it (they overlap).
const TILE_LONG := 0.4
const TILE_STEP := 0.32
## How thick a tile is, and how far one end is raised over the other (the overlap's step).
const THICK := 0.03
const LIFT := 0.035
## Half the width of a ridge cap, and how high its crown is over the line (metres).
const RIDGE_HALF := 0.36
const RIDGE_CROWN := 0.1
## How far the bevel at a ridge cap's rim reaches on down to the roof (metres).
const RIDGE_BEVEL := 0.12
## How far a gable cap reaches in over the roof, and out beyond its edge.
const EDGE_IN := 0.26
const EDGE_OUT := 0.07
## The tile sheet's single roof tile the caps show (the same sheet VillageHouse's roofs use).
## The rectangle is kept a texel inside the tile (TILE_INSET): its edges lie exactly on the roof shader's
## tile grid, where the shader's pick of "which tile is this" flips from pixel to pixel by rounding and
## shows a random neighbour's shade (a newer, redder tile came out as a dotted tile).
const TILE_INSET := 1.0 / 512.0
const TILE_UV := Rect2(0.5894 + TILE_INSET, 0.0932 + TILE_INSET, 0.0581 - TILE_INSET * 2.0, 0.0254 - TILE_INSET * 2.0)


## The tiles of a ridge cap, into `st` (a SurfaceTool of the roof surface: positions, normals, UVs and
## a vertex colour for the tile's own shade). From `a` to `b` along the ridge, with the crown over
## `a`/`b`'s height by `RIDGE_CROWN`; the two sides fall away `fall` high per metre out (the slope of
## the roof's two sides, as rise over run). A `descending` line (a hip, from the peak down to a
## corner) has its tiles overlap downhill, the upper one over the lower.
static func ridge(st: SurfaceTool, a: Vector3, b: Vector3, fall: float, seed: int, descending := false) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.1:
		return
	dir /= length
	var side := Vector3.UP.cross(dir).normalized()
	var profile: Array[Vector2] = []
	# From the left skirt over the crown to the right one: (across, up).
	for i in range(-4, 5):
		var u := float(i) / 4.0
		profile.append(Vector2(u * RIDGE_HALF, RIDGE_CROWN - absf(u) * RIDGE_HALF * fall - u * u * 0.04))
	# A bevel from each rim down to the roof, steeper than the slope but still facing the sky, so
	# snow settles on it and no dark wall stands round the cap.
	for s_ in [-1.0, 1.0]:
		var rim := RIDGE_HALF + RIDGE_BEVEL
		var bevel := Vector2(s_ * rim, -rim * fall - 0.012)
		if s_ < 0.0:
			profile.push_front(bevel)
		else:
			profile.append(bevel)
	_row(st, a, dir, length, Vector3.UP, side, profile, -LIFT if descending else LIFT, 0.03, 0.03, seed)


## The tiles of a gable edge cap along `a` (the top) to `b` (the eave), on a roof whose face looks along
## `up`; `out` is the way out over the edge. The cap wraps round the edge with a lip hanging over it.
static func edge(st: SurfaceTool, a: Vector3, b: Vector3, up: Vector3, out: Vector3, seed: int) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.1:
		return
	dir /= length
	var profile: Array[Vector2] = [
		Vector2(-EDGE_IN, 0.03), Vector2(-EDGE_IN * 0.5, 0.062), Vector2(0.0, 0.075),
		Vector2(EDGE_OUT * 0.6, 0.07), Vector2(EDGE_OUT, 0.05),
		Vector2(EDGE_OUT + 0.045, 0.0), Vector2(EDGE_OUT + 0.075, -0.07),
	]
	# Higher tiles overlap lower ones, so a tile's lower end is the raised one.
	_row(st, a, dir, length, up, out, profile, -LIFT, 0.0, 0.04, seed)


## A row of tiles along `dir` from `a`, `length` long. `profile` is the tile's top across the row
## (across along `side`, height along `up`); the tile's thickness shows under it, and a lip drops
## `skirt_in` at its first point and `skirt_out` at its last, down to the roof. A tile's start end is raised
## by `lift` (negative: its finish end), so the next one rests on it.
static func _row(st: SurfaceTool, a: Vector3, dir: Vector3, length: float, up: Vector3, side: Vector3,
		profile: Array[Vector2], lift: float, skirt_in: float, skirt_out: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var count := maxi(1, ceili((length - TILE_LONG) / TILE_STEP) + 1)
	# Spread the tiles so the last one ends exactly at the end of the row.
	var step := (length - TILE_LONG) / maxf(1.0, float(count - 1)) if count > 1 else 0.0
	var long := TILE_LONG if count > 1 else length
	for i in count:
		var at := a + dir * (step * i)
		# A touch of play in each tile: a little turned and shifted, never apart.
		var shift := side * rng.randf_range(-0.012, 0.012)
		var seed_colour := Color(rng.randf(), 0, 0)
		var ends: Array[float] = [maxf(lift, 0.0), maxf(-lift, 0.0)]
		var rings: Array = []
		for e in 2:
			var base := at + dir * (long * e) + shift + up * ends[e]
			var ring: Array[Vector3] = []
			for p: Vector2 in profile:
				ring.append(base + side * p.x + up * p.y)
			rings.append(ring)
		var n := profile.size()
		# The top: a strip between the two rings, the tile's picture across it.
		for k in n - 1:
			var r0: Array = rings[0]
			var r1: Array = rings[1]
			var quad: Array[Vector3] = [r0[k], r0[k + 1], r1[k + 1], r1[k]]
			var uv0 := TILE_UV.position + Vector2(0, TILE_UV.size.y * float(k) / (n - 1))
			var uvs: Array[Vector2] = [uv0, uv0 + Vector2(0, TILE_UV.size.y / (n - 1)),
					uv0 + Vector2(TILE_UV.size.x, TILE_UV.size.y / (n - 1)), uv0 + Vector2(TILE_UV.size.x, 0)]
			_quad(st, quad, uvs, up, seed_colour)
		# The thickness at both ends of the tile, down to under it.
		for e in 2:
			var ring: Array = rings[e]
			var outward := dir * (-1.0 if e == 0 else 1.0)
			for k in n - 1:
				var drop := THICK + absf(lift)
				var q: Array[Vector3] = [ring[k], ring[k + 1], (ring[k + 1] as Vector3) - up * drop, (ring[k] as Vector3) - up * drop]
				var cu := TILE_UV.position + TILE_UV.size * 0.5
				_quad(st, q, [cu, cu, cu, cu], outward, seed_colour)
		# The lips at the sides, down to the roof.
		for s in 2:
			var drop_by := skirt_in if s == 0 else skirt_out
			if drop_by <= 0.0:
				continue
			var idx := 0 if s == 0 else n - 1
			var r0: Array = rings[0]
			var r1: Array = rings[1]
			var p0: Vector3 = r0[idx]
			var p1: Vector3 = r1[idx]
			var q: Array[Vector3] = [p0, p1, p1 - up * drop_by, p0 - up * drop_by]
			var cu := TILE_UV.position + TILE_UV.size * 0.5
			_quad(st, q, [cu, cu, cu, cu], side * (-1.0 if s == 0 else 1.0), seed_colour)


## One quad of four points facing `outward`, wound the way the engine draws it as a front.
static func _quad(st: SurfaceTool, q: Array[Vector3], uvs: Array, outward: Vector3, colour: Color) -> void:
	var n := (q[1] - q[0]).cross(q[2] - q[0])
	if n.length() < 0.00001:
		n = (q[2] - q[0]).cross(q[3] - q[0])
	n = n.normalized()
	if n.dot(outward) < 0.0:
		n = -n
	# The engine draws clockwise triangles as front: with the normal towards the viewer, that is
	# the order whose cross product points away.
	var order: Array = [0, 1, 2, 0, 2, 3]
	var cross := (q[1] - q[0]).cross(q[2] - q[0])
	if cross.dot(n) > 0.0 or cross.length() < 0.00001 and (q[2] - q[0]).cross(q[3] - q[0]).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for k: int in order:
		st.set_color(Color(colour.r, 1.0, 0.0))
		st.set_normal(n)
		st.set_uv(uvs[k] as Vector2)
		st.add_vertex(q[k])
