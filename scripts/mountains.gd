class_name Mountains
## The high mountains far east of the wolf hollow: every "=" tile of the
## open-air map is solid rock, and this builds the rock as low-poly,
## flat-shaded meshes in the style of the dragon's mountain (LairMountain).
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

const ROCK := Color(0.47, 0.45, 0.43)
const ROCK_DARK := Color(0.3, 0.29, 0.29)
const ROCK_HIGH := Color(0.62, 0.61, 0.6)
const MOSS := Color(0.32, 0.38, 0.24)
const SNOW := Color(0.92, 0.94, 0.98)
const EARTH := Color(0.36, 0.33, 0.29)


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


## Builds the mountains of `level` and adds them to it. Nothing happens on a
## map without rock.
static func build(level: Level, seed_value: int) -> void:
	var area := Rect2i()
	var any := false
	for y in level.height:
		for x in level.width:
			if level.cell_char(Vector2i(x, y)) == ROCK_LETTER:
				area = Rect2i(x, y, 1, 1) if not any else area.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
				any = true
	if not any:
		return
	# Past the edge of the map the rock goes on a little way.
	area = area.grow(4)
	var dist := _distance_field(level, area)
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
	var points := []
	for iz in nz + 1:
		var row := []
		for ix in nx + 1:
			var x := origin.x + ix * STEP
			var z := origin.y + iz * STEP
			if ix > 0 and ix < nx and iz > 0 and iz < nz:
				x += rng.randf_range(-JITTER, JITTER)
				z += rng.randf_range(-JITTER, JITTER)
			var h := _height(dist, north, x, z, noise)
			if h > 1.0:
				# Craggy: higher rock is shaken more.
				h = maxf(0.6, h + rng.randf_range(-0.6, 0.6) * minf(1.0, h / 5.0))
			row.append(Vector3(x, h - SINK, z))
		points.append(row)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var per := int(CHUNK * tile / STEP)
	for cz in range(0, nz, per):
		for cx in range(0, nx, per):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var faces := 0
			for iz in range(cz, mini(cz + per, nz)):
				for ix in range(cx, mini(cx + per, nx)):
					var a: Vector3 = points[iz][ix]
					var b: Vector3 = points[iz][ix + 1]
					var c: Vector3 = points[iz + 1][ix]
					var d: Vector3 = points[iz + 1][ix + 1]
					# Alternate the diagonal so the facets do not line up.
					if (ix + iz) % 2 == 0:
						faces += _face(st, a, b, d, rng) + _face(st, a, d, c, rng)
					else:
						faces += _face(st, a, b, c, rng) + _face(st, b, d, c, rng)
			if faces == 0:
				continue
			var node := MeshInstance3D.new()
			node.name = "Mountains"
			node.mesh = st.commit()
			node.material_override = mat
			level.add_child(node, true)


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
	var h := minf(d * FOOT_SLOPE, FOOT_HEIGHT) + maxf(0.0, d - FOOT_HEIGHT / FOOT_SLOPE) * CLIMB
	h = minf(h, PEAK)
	# Crags and peaks, growing in as the rock gets higher.
	h += (noise.get_noise_2d(x, z) * 0.5 + 0.5) * CRAGS * smoothstep(2.0, 14.0, d)
	var edge: float = north.get(Vector2i(roundi(x / Level.TILE), roundi(z / Level.TILE)), INF)
	if edge != INF:
		h = minf(h, 0.4 + maxf(0.0, z - edge) * SOUTH_SLOPE)
	return h


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
