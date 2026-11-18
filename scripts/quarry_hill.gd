class_name QuarryHill
## The stonemason's quarry: a small hill of rock in the south-west corner of
## the village, cleared out of the forest beside his house. He works at its
## foot: a rough block lies where his hammer lands (see Outdoor._build_quarry),
## with cut blocks stacked beside it.
##
## The hill is built from the mason's tile alone, the same every time, in the
## flat-shaded style of the mountains (see Mountains). It is solid: one box
## per tile, as high as the rock there.

## The tiles of the hill, relative to the mason's tile: columns -6..-2 on his
## row and the two rows below him, and the column right beside him on the
## row of the stone he works at.
const ROWS := {-1: [-6, -2], 0: [-6, -1], 1: [-6, -1]}
## How high the rock gets and how far in from its edge it takes to get there
## (metres). Gentle enough that the camera, looking from the south, never
## loses the hero behind it (see Mountains.SOUTH_SLOPE).
const PEAK := 5.2
const REACH := 6.5
## The grid of the mesh (metres), and how far the heights are shaken.
const STEP := 1.0
const CRAG := 0.9
## Rock climbs in steps of this height, as cut by the quarrymen.
const TERRACE := 1.3


## The tiles of the hill for a mason on `home`.
static func tiles(home: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in ROWS:
		for dx in range(ROWS[dy][0], ROWS[dy][1] + 1):
			out.append(home + Vector2i(dx, dy))
	return out


## Builds the hill and adds it to `level`. `home` is the mason's tile.
static func build(level: Outdoor, home: Vector2i) -> void:
	var mine := {}
	for t in tiles(home):
		mine[t] = true
	var tile := Level.TILE
	var area := Rect2i(home.x - 6, home.y - 1, 6, 3)
	var origin := Vector2((area.position.x - 0.5) * tile, (area.position.y - 0.5) * tile)
	var nx := int(area.size.x * tile / STEP)
	var nz := int(area.size.y * tile / STEP)
	var noise := FastNoiseLite.new()
	noise.seed = hash("quarry")
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.12
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("quarry")
	var points := []
	for iz in nz + 1:
		var row := []
		for ix in nx + 1:
			var x := origin.x + ix * STEP
			var z := origin.y + iz * STEP
			var d := _inside(level, mine, x, z, tile)
			var h := 0.0
			if d > 0.0:
				var t := clampf(d / REACH, 0.0, 1.0)
				h = PEAK * t
				h += noise.get_noise_2d(x, z) * CRAG * 2.0 * minf(1.0, h)
				# Terraces: the lower slopes are cut into steps.
				h = lerpf(h, floorf(h / TERRACE) * TERRACE + TERRACE * 0.5, 0.45 * minf(1.0, h / 1.5))
				h = maxf(h, 0.15)
			row.append(Vector3(x, h, z))
		points.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := 0
	for iz in nz:
		for ix in nx:
			var a: Vector3 = points[iz][ix]
			var b: Vector3 = points[iz][ix + 1]
			var c: Vector3 = points[iz + 1][ix]
			var e: Vector3 = points[iz + 1][ix + 1]
			if (ix + iz) % 2 == 0:
				faces += Mountains._face(st, a, b, e, rng) + Mountains._face(st, a, e, c, rng)
			else:
				faces += Mountains._face(st, a, b, c, rng) + Mountains._face(st, b, e, c, rng)
	if faces > 0:
		var node := MeshInstance3D.new()
		node.name = "QuarryHill"
		node.mesh = st.commit()
		node.material_override = AgedStone.rock_material()
		level.add_child(node, true)
	# Solid, tile by tile, as high as the rock gets there.
	for t in mine:
		var top := 0.0
		for iz in range(nz + 1):
			for ix in range(nx + 1):
				var p: Vector3 = points[iz][ix]
				if absf(p.x - t.x * tile) <= tile * 0.5 and absf(p.z - t.y * tile) <= tile * 0.5:
					top = maxf(top, p.y)
		level._add_solid(level.cell_to_world(t), Vector3(tile, maxf(top, 1.0), tile))
		level.astar.set_point_solid(t, true)


## Metres from (x, z) to the nearest bit of ground that is not hill, positive
## inside the hill and 0 or less outside it. The forest round it counts as
## hill, so the rock runs on behind the trees; only open ground is its edge.
static func _inside(level: Outdoor, mine: Dictionary, x: float, z: float, tile: float) -> float:
	var here := Vector2i(roundi(x / tile), roundi(z / tile))
	if not mine.has(here):
		return 0.0
	var best := INF
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t := here + Vector2i(dx, dy)
			if mine.has(t):
				continue
			# Only open ground is an edge, not the forest round the hill.
			if level.cell_char(t) == "#":
				continue
			var lo := Vector2(t.x * tile - tile * 0.5, t.y * tile - tile * 0.5)
			var cx := clampf(x, lo.x, lo.x + tile)
			var cz := clampf(z, lo.y, lo.y + tile)
			best = minf(best, Vector2(x - cx, z - cz).length())
	return best if best < INF else REACH
