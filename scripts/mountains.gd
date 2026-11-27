class_name Mountains
## The high mountains far east of the wolf hollow: every "=" tile of the
## open-air map is solid rock, and this builds the rock as low-poly,
## smooth-shaded meshes in the style of the dragon's mountain (LairMountain),
## weathered like the village stone (AgedStone.rock_material).
##
## The rock rises steeply right where the walkable ground ends, then climbs
## on into peaks with snow on their tops. One rule keeps the hero in view:
## camera looks at the hero from the south, so rock that stands south of
## walkable ground may only rise as gently as the camera's line of sight
## (see SOUTH_SLOPE), and never hides the hero behind a cliff.
##
## Built at load time from the map alone, the same every time: one mesh per
## CHUNK x CHUNK tiles, so the parts out of view are not drawn.

## The letter of a rock tile (see Tiles.OUTDOOR).
const ROCK_LETTER := "="
## Tiles per mesh.
const CHUNK := 16
## The grid of the height field (metres) and how far its points are shaken.
const STEP := 2.0
const JITTER := 0.45
## The foot: how steeply the rock leaps up from the walkable ground, and
## how high that first wall gets before the slope eases.
const FOOT_SLOPE := 2.4
const FOOT_HEIGHT := 6.5
## Further in, the rock keeps climbing this much per metre, up to PEAK.
const CLIMB := 0.45
const PEAK := 26.0
## Peaks and crags on top: how high they reach and how wide they are.
const CRAGS := 9.0
const CRAG_SCALE := 0.045
## Rock south of walkable ground rises no steeper than this (height per
## metre away from that ground), below the camera's line of sight.
const SOUTH_SLOPE := 1.05
const SOUTH_LOOK := 8
const SINK := 0.25
## How many tiles the distance field reaches past the mesh.
const FIELD_MARGIN := 2
## Ground within this many metres of a rock tile's edge is where the hero's feet can be (the hero stops at
## the rock tile's edge, body radius 0.55): the rock stays flat out there, so nobody sinks into the face,
## and rises past it at CLEAR_SLOPE per metre.
const FEET_CLEAR := 0.35
const CLEAR_SLOPE := 7.0

const ROCK := Color(0.47, 0.45, 0.43)
const ROCK_DARK := Color(0.3, 0.29, 0.29)
const ROCK_HIGH := Color(0.62, 0.61, 0.6)
const MOSS := Color(0.32, 0.38, 0.24)
const SNOW := Color(0.72, 0.75, 0.81)  # the same off-white as the laid snow, see snow.gdshaderinc
const EARTH := Color(0.36, 0.33, 0.29)


## How far from the rock a tree trunk or a bush must stand (metres): the foot rises steeply right at the
## edge of the rock tiles, so anything closer would be cut off by the rock.
const TREE_CLEARANCE := 1.4
const BUSH_CLEARANCE := 1.8
## Where the foot eases from the flat ground into the slope (metres): a curve instead of a sharp crease.
const FOOT_ROUND := 1.6
## The rock's edge towards the open ground is see-through: how opaque it is at the edge, and how many metres into the rock
## it is solid again. The distance wanders, so the fade runs along no straight tile line.
const EDGE_ALPHA := 0.2
const EDGE_FADE := 2.6


## Whether a spot on the ground (x, z in metres) lies within `margin` of mountain rock, where the rock
## would clip a tree or a bush standing there.
static func near_rock(level: Level, x: float, z: float, margin: float) -> bool:
	var tile := Level.TILE
	var c := Vector2i(roundi(x / tile), roundi(z / tile))
	var reach := ceili(margin / tile) + 1
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var t := c + Vector2i(dx, dy)
			if not is_rock(level, t):
				continue
			var mid := level.cell_to_world(t)
			var ox := maxf(0.0, absf(x - mid.x) - tile * 0.5)
			var oz := maxf(0.0, absf(z - mid.z) - tile * 0.5)
			if ox * ox + oz * oz < margin * margin:
				return true
	# The foot's lobes and mounds (see MountainFoot) are part of the rock too.
	return MountainFoot.covers(level, x, z, margin)


## Whether a tile of `level` is mountain rock. Off the map, the nearest tile
## on the map decides, so the mountains run on past its edge.
static func is_rock(level: Level, c: Vector2i) -> bool:
	var inside := Vector2i(clampi(c.x, 0, level.width - 1), clampi(c.y, 0, level.height - 1))
	# A mine entrance is dug into the rock: its front row is a notch in the
	# rock face, and the rock rises behind it.
	var ch := level.cell_char(inside)
	if ch == "]":
		return level.cell_char(inside + Vector2i(0, 1)) == "]"
	return ch == ROCK_LETTER


## The height of the rock surface at x, z (metres), exactly as the mesh is drawn (the same triangles), or
## `INF` where there is no rock mesh. Props that cling to the rock face, such as a waterfall's water, are
## laid along it with this.
static func surface_at(level: Level, x: float, z: float) -> float:
	if not level.has_meta("mountain_grid"):
		return INF
	var grid: Dictionary = level.get_meta("mountain_grid")
	var origin: Vector2 = grid.origin
	var points: Array = grid.points
	var ix0 := floori((x - origin.x) / STEP)
	var iz0 := floori((z - origin.y) / STEP)
	for iz in range(iz0 - 1, iz0 + 2):
		for ix in range(ix0 - 1, ix0 + 2):
			if iz < 0 or ix < 0 or iz >= int(grid.nz) or ix >= int(grid.nx):
				continue
			var a: Vector3 = points[iz][ix]
			var b: Vector3 = points[iz][ix + 1]
			var c: Vector3 = points[iz + 1][ix]
			var d: Vector3 = points[iz + 1][ix + 1]
			# The same diagonals as in build().
			var tris := [[a, b, d], [a, d, c]] if (ix + iz) % 2 == 0 else [[a, b, c], [b, d, c]]
			for t: Array in tris:
				var h := _height_in(t[0], t[1], t[2], x, z)
				if h != INF:
					return h
	return INF


## The height of the triangle a, b, c over (x, z), or INF when the point lies outside it.
static func _height_in(a: Vector3, b: Vector3, c: Vector3, x: float, z: float) -> float:
	var det := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(det) < 0.000001:
		return INF
	var u := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / det
	var v := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / det
	var w := 1.0 - u - v
	if u < -0.0001 or v < -0.0001 or w < -0.0001:
		return INF
	return u * a.y + v * b.y + w * c.y


## Builds the mountains of `level`, adds them to it and returns their meshes.
## Nothing happens on a map without rock. The rock stays flat on `flat` (building
## plots, in metres on the ground, see Plots) and only rises past their edges.
static func build(level: Level, seed_value: int, flat: Array[Rect2] = []) -> Array:
	var built := []
	var area := Rect2i()
	var any := false
	for y in level.height:
		for x in level.width:
			if level.cell_char(Vector2i(x, y)) == ROCK_LETTER:
				area = Rect2i(x, y, 1, 1) if not any else area.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
				any = true
	if not any:
		return built
	# The grid points close enough to a plot that a shaken point could land on it.
	var level_ground: Array[Rect2] = []
	for plot in flat:
		level_ground.append(plot.grow(JITTER + 0.05))
	# Past the edge of the map the rock goes on a little way.
	area = area.grow(4)
	# The distance field reaches a little further than the mesh: a point at
	# the mesh's edge blends the tiles either side of it, and a tile missing
	# from the field counts as deep rock, which stood up a seam of rock on
	# open ground wherever the mesh's edge crossed it.
	var dist := _distance_field(level, area.grow(FIELD_MARGIN))
	var north := {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			north[Vector2i(x, y)] = _open_to_north(level, Vector2i(x, y))
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	noise.frequency = CRAG_SCALE
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tile := Level.TILE
	var origin := Vector2((area.position.x - 0.5) * tile, (area.position.y - 0.5) * tile)
	var nx := int(ceil(area.size.x * tile / STEP))
	var nz := int(ceil(area.size.y * tile / STEP))
	var shelves := ClimbSpots.shelves(level)
	var points := []
	for iz in nz + 1:
		var row := []
		for ix in nx + 1:
			var x := origin.x + ix * STEP
			var z := origin.y + iz * STEP
			# The points along the foot of the rock keep to the tile lines (the draw still happens, so the
			# later random numbers stay the same): a shaken point there would leave a lip of rock
			# standing on ground the hero can walk on.
			var jx := rng.randf_range(-JITTER, JITTER)
			var jz := rng.randf_range(-JITTER, JITTER)
			var shelf := -1.0
			for sh: Dictionary in shelves:
				var r: Rect2 = sh.rect
				# The terrace is flat from the middle of its tile back, the front row of points stays on the foot.
				if x >= r.position.x - 0.01 and x <= r.end.x + 0.01 and z >= r.position.y - 0.01 and z <= r.end.y - STEP * 0.5 + 0.01:
					shelf = sh.height
			if shelf < 0.0 and ix > 0 and ix < nx and iz > 0 and iz < nz and _distance_at(dist, x, z) > STEP * 1.25:
				x += jx
				z += jz
			var h := _height(dist, north, x, z, noise)
			if h > 0.0:
				h = minf(h, _clear_cap(level, x, z))
			if h > 1.0:
				# Craggy: higher rock is shaken more.
				h = maxf(0.6, h + rng.randf_range(-0.6, 0.6) * minf(1.0, h / 5.0))
			# Flat on a plot, after the shake so the rest of the rock stays as it was.
			if shelf >= 0.0:
				h = shelf
			if level_ground.any(func(r: Rect2) -> bool: return r.has_point(Vector2(x, z))):
				h = 0.0
			row.append(Vector3(x, h - SINK, z))
		points.append(row)
	# Kept for props that sit on the rock face (see surface_at).
	level.set_meta("mountain_grid", {"origin": origin, "nx": nx, "nz": nz, "points": points})
	# Smooth shading: every grid point gets one normal (the area-weighted mean of the
	# triangles that meet there) and one colour, shared by all of them. Faces then blend
	# into each other with no hard facet edges, and the snow laid over the rock (see
	# SnowCover) lifts along the same normals on both sides of a seam, so no thin line of
	# bare rock shows through it.
	var normals := _vertex_normals(points, nx, nz)
	var paint := []
	for iz in nz + 1:
		var row := []
		for ix in nx + 1:
			var p: Vector3 = points[iz][ix]
			var colour := _paint(p, normals[iz][ix], noise, rng)
			var inside := _distance_at(dist, p.x, p.z) + noise.get_noise_2d(p.x * 2.1 + 90.0, p.z * 2.1) * 1.6
			colour.a = lerpf(EDGE_ALPHA, 1.0, smoothstep(0.0, EDGE_FADE, inside))
			row.append(colour)
		paint.append(row)
	# Weathered like the village stone (see AgedStone.rock_material).
	var mat := AgedStone.rock_material()
	var per := int(CHUNK * tile / STEP)
	for cz in range(0, nz, per):
		for cx in range(0, nx, per):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			# The squares along the open ground, whose corners are see-through, go in a mesh of their own.
			var soft := SurfaceTool.new()
			soft.begin(Mesh.PRIMITIVE_TRIANGLES)
			var faces := 0
			var soft_faces := 0
			for iz in range(cz, mini(cz + per, nz)):
				for ix in range(cx, mini(cx + per, nx)):
					var corner := func(dx: int, dz: int) -> Array:
						return [points[iz + dz][ix + dx], normals[iz + dz][ix + dx], paint[iz + dz][ix + dx]]
					var a: Array = corner.call(0, 0)
					var b: Array = corner.call(1, 0)
					var c: Array = corner.call(0, 1)
					var d: Array = corner.call(1, 1)
					var edge := false
					for q: Array in [a, b, c, d]:
						if (q[2] as Color).a < 0.999:
							edge = true
					var into := soft if edge else st
					var n := 0
					# Alternate the diagonal so the facets do not line up.
					if (ix + iz) % 2 == 0:
						n = _smooth_face(into, a, b, d) + _smooth_face(into, a, d, c)
					else:
						n = _smooth_face(into, a, b, c) + _smooth_face(into, b, d, c)
					if edge:
						soft_faces += n
					else:
						faces += n
			if faces > 0:
				var node := MeshInstance3D.new()
				node.name = "Mountains"
				node.mesh = st.commit()
				node.material_override = mat
				level.add_child(node, true)
				built.append(node)
			if soft_faces > 0:
				var node := MeshInstance3D.new()
				node.name = "MountainsEdge"
				node.mesh = soft.commit()
				node.material_override = MountainFoot.foot_material()
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				level.add_child(node, true)
				built.append(node)
	return built


## Signed distance (metres) from each tile's middle to the edge of the
## walkable ground: positive inside the rock, negative on open ground.
static func _distance_field(level: Level, area: Rect2i) -> Dictionary:
	var tiles := {}
	var queue: Array[Vector2i] = []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			if is_rock(level, c):
				tiles[c] = INF
			else:
				tiles[c] = 0.0
				queue.append(c)
	# Chamfer distance in tiles from the nearest open tile's middle.
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if not tiles.has(n):
				continue
			var step := 1.0 if d.x == 0 or d.y == 0 else 1.414
			if float(tiles[n]) > float(tiles[c]) + step:
				tiles[n] = float(tiles[c]) + step
				queue.append(n)
	var out := {}
	for c in tiles:
		var t: float = tiles[c]
		out[c] = -Level.TILE * 0.5 if t == 0.0 else (minf(t, 40.0) - 0.5) * Level.TILE
	return out


## The most the rock may rise at a spot of the ground: nothing where the hero's feet can stand (more than
## FEET_CLEAR from every rock tile), then a steep rise towards the face.
static func _clear_cap(level: Level, x: float, z: float) -> float:
	var tile := Level.TILE
	var cx := roundi(x / tile)
	var cz := roundi(z / tile)
	var best := INF
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var t := Vector2i(cx + dx, cz + dz)
			if not is_rock(level, t):
				continue
			var mid := level.cell_to_world(t)
			var ox := maxf(0.0, absf(x - mid.x) - tile * 0.5)
			var oz := maxf(0.0, absf(z - mid.z) - tile * 0.5)
			best = minf(best, sqrt(ox * ox + oz * oz))
	# Inside a rock tile nothing is capped.
	if best == 0.0:
		return INF
	return maxf(0.0, FEET_CLEAR - best) * CLEAR_SLOPE


## The distance field between the tile middles, smoothly.
static func _distance_at(dist: Dictionary, x: float, z: float) -> float:
	var fx := x / Level.TILE
	var fz := z / Level.TILE
	var x0 := floori(fx)
	var z0 := floori(fz)
	var tx := fx - x0
	var tz := fz - z0
	var corners: Array[float] = []
	for c in [Vector2i(x0, z0), Vector2i(x0 + 1, z0), Vector2i(x0, z0 + 1), Vector2i(x0 + 1, z0 + 1)]:
		corners.append(float(dist.get(c, 40.0 * Level.TILE)))
	return lerpf(lerpf(corners[0], corners[1], tx), lerpf(corners[2], corners[3], tx), tz)


## Where the nearest walkable ground north of tile `t` ends (its southern
## edge, as z in metres), within a tile either side, or INF when there is
## none close by.
static func _open_to_north(level: Level, t: Vector2i) -> float:
	for k in range(0, SOUTH_LOOK + 1):
		for dx in [0, -1, 1]:
			var c := t + Vector2i(dx, -k)
			if not is_rock(level, c):
				return c.y * Level.TILE + Level.TILE * 0.5
	return INF


static func _height(dist: Dictionary, north: Dictionary, x: float, z: float, noise: FastNoiseLite) -> float:
	var d := _distance_at(dist, x, z)
	if d <= 0.0:
		return 0.0
	# The foot eases in: a curve over its first FOOT_ROUND metres, then the steep slope as before.
	var lifted := d * FOOT_SLOPE - FOOT_SLOPE * FOOT_ROUND * 0.5
	var foot := d * d * FOOT_SLOPE / (2.0 * FOOT_ROUND) if d < FOOT_ROUND else lifted
	var h := minf(foot, FOOT_HEIGHT) + maxf(0.0, d - FOOT_HEIGHT / FOOT_SLOPE) * CLIMB
	h = minf(h, PEAK)
	# Crags and peaks, growing in as the rock gets higher.
	h += (noise.get_noise_2d(x, z) * 0.5 + 0.5) * CRAGS * smoothstep(2.0, 14.0, d)
	var edge: float = north.get(Vector2i(roundi(x / Level.TILE), roundi(z / Level.TILE)), INF)
	if edge != INF:
		# The low rock on the open north side rises from nothing in a curve (not from a 0.4 m ledge with a straight,
		# angular outline), so its rim sinks under the ground and ends rounded.
		var s := maxf(0.0, z - edge)
		h = minf(h, 0.4 * smoothstep(0.0, 1.2, s) + s * SOUTH_SLOPE)
	return h


## The smooth normal of every grid point: the mean of the (upward) normals of the triangles around it,
## weighted by their area, built on the same diagonals as the mesh.
static func _vertex_normals(points: Array, nx: int, nz: int) -> Array:
	var sums := []
	for iz in nz + 1:
		var row := []
		for ix in nx + 1:
			row.append(Vector3.ZERO)
		sums.append(row)
	for iz in nz:
		for ix in nx:
			var a: Vector3 = points[iz][ix]
			var b: Vector3 = points[iz][ix + 1]
			var c: Vector3 = points[iz + 1][ix]
			var d: Vector3 = points[iz + 1][ix + 1]
			var tris := []
			if (ix + iz) % 2 == 0:
				tris = [[a, b, d, Vector2i(ix, iz), Vector2i(ix + 1, iz), Vector2i(ix + 1, iz + 1)],
						[a, d, c, Vector2i(ix, iz), Vector2i(ix + 1, iz + 1), Vector2i(ix, iz + 1)]]
			else:
				tris = [[a, b, c, Vector2i(ix, iz), Vector2i(ix + 1, iz), Vector2i(ix, iz + 1)],
						[b, d, c, Vector2i(ix + 1, iz), Vector2i(ix + 1, iz + 1), Vector2i(ix, iz + 1)]]
			for t in tris:
				var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
				if n.y < 0.0:
					n = -n
				for k in 3:
					var at: Vector2i = t[3 + k]
					sums[at.y][at.x] += n
	for iz in nz + 1:
		for ix in nx + 1:
			var n: Vector3 = sums[iz][ix]
			sums[iz][ix] = n.normalized() if n.length() > 0.0001 else Vector3.UP
	return sums


## The colour of one grid point: rock, moss, snow or earth by height and slope. Snow lies in patches (a
## noise shifts where it starts and how steep it may be), so it thins out and rock shows through on the
## steeper slopes instead of a hard line between white and grey faces.
static func _paint(p: Vector3, n: Vector3, noise: FastNoiseLite, rng: RandomNumberGenerator) -> Color:
	var top := p.y + SINK
	var patch := noise.get_noise_2d(p.x * 4.0 + 50.0, p.z * 4.0)
	var colour := ROCK.lerp(ROCK_DARK, clampf((0.85 - n.y) * 1.6, 0.0, 1.0))
	if n.y > 0.72 and top < 8.0:
		colour = colour.lerp(MOSS, clampf((n.y - 0.72) * 3.0, 0.0, 0.6))
	colour = colour.lerp(ROCK_HIGH, smoothstep(9.0, 16.0, top) * 0.7)
	# Snow lies on the high, gentle slopes, in patches.
	var line := 14.0 + patch * 2.5
	var steep := 0.45 + patch * 0.12
	if top > line and n.y > steep:
		colour = colour.lerp(SNOW, clampf((top - line) / 5.0, 0.0, 1.0) * clampf((n.y - steep) * 3.0, 0.0, 1.0))
	if MountainFoot.style == "":
		colour = colour.lerp(EARTH, 1.0 - smoothstep(0.2, 1.2, top))
	else:
		# The foot is earth in the colours of the apron on the ground in front of it, in patches that climb the rock
		# to different heights (and, where moss is wanted, grass that creeps up in tongues).
		var lump := noise.get_noise_2d(p.x * 1.7 + 11.0, p.z * 1.7) * 0.5 + 0.5
		var foot := 1.0 - smoothstep(0.1, 1.2 + 2.6 * lump, top)
		colour = colour.lerp(MountainFoot.EARTH * (0.88 + 0.24 * lump), foot)
		if MountainFoot.has("moss"):
			var tongue := (noise.get_noise_2d(p.x * 2.3 + 71.0, p.z * 2.3) * 0.5 + 0.5)
			colour = colour.lerp(MountainFoot.GREEN * (0.8 + 0.4 * lump), (1.0 - smoothstep(0.2, 0.5 + 1.4 * tongue, top)) * smoothstep(0.45, 0.65, tongue) * 0.8)
	colour *= rng.randf_range(0.95, 1.04)
	colour.a = 1.0
	return colour


## One triangle with the smooth normals and colours of its corners (each `[position, normal, colour]`); 1
## if it was added. Faces that lie wholly below the ground are left out.
static func _smooth_face(st: SurfaceTool, a: Array, b: Array, c: Array) -> int:
	if maxf(a[0].y, maxf(b[0].y, c[0].y)) <= 0.05:
		return 0
	var n: Vector3 = (b[0] - a[0]).cross(c[0] - a[0])
	if n.y > 0.0:
		# Godot's front faces wind clockwise as seen from the outside (above).
		var swap := b
		b = c
		c = swap
	for v in [a, b, c]:
		st.set_color(v[2])
		st.set_normal(v[1])
		st.add_vertex(v[0])
	return 1


## One flat-shaded triangle in its own shade of stone; 1 if it was added.
## Faces that lie wholly below the ground are left out.
static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, rng: RandomNumberGenerator) -> int:
	if maxf(a.y, maxf(b.y, c.y)) <= 0.05:
		return 0
	var n := (b - a).cross(c - a).normalized()
	if n.y > 0.0:
		# Godot's front faces wind clockwise as seen from the outside (above).
		var swap := b
		b = c
		c = swap
	else:
		n = -n
	var top := (a.y + b.y + c.y) / 3.0 + SINK
	var colour := ROCK.lerp(ROCK_DARK, clampf((0.85 - n.y) * 1.6, 0.0, 1.0))
	if n.y > 0.72 and top < 8.0:
		colour = colour.lerp(MOSS, clampf((n.y - 0.72) * 3.0, 0.0, 0.6))
	colour = colour.lerp(ROCK_HIGH, smoothstep(9.0, 16.0, top) * 0.7)
	# Snow lies on the high, gentle faces.
	if top > 14.0 and n.y > 0.45:
		colour = colour.lerp(SNOW, clampf((top - 14.0) / 5.0, 0.0, 1.0) * clampf((n.y - 0.45) * 3.0, 0.0, 1.0))
	colour = colour.lerp(EARTH, 1.0 - smoothstep(0.2, 1.2, top))
	colour *= rng.randf_range(0.92, 1.06)
	colour.a = 1.0
	st.set_color(colour)
	st.set_normal(n)
	for p in [a, b, c]:
		st.add_vertex(p)
	return 1
