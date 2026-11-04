class_name LairMountain
## The mountain the dragon's lair is dug into: a craggy, low-poly hill of
## grey rock that rises behind the stone arch, so the arch reads as the mouth
## of a cave in a mountainside instead of a door standing in the woods.
##
## Built at load time as one mesh from a height field: a few cone-shaped
## peaks, a steep rock face right behind the arch, and a jagged ridge, every
## face flat-shaded in its own shade of stone (moss on the gentle slopes,
## paler rock up high) to match the low-poly kits around it, and weathered
## like the village stone (AgedStone.rock_material).
##
## Local space: the origin is the foot of the arch's front, +z points out of
## the cave towards the hero. The rock only stands where the map has forest
## or the lair's own tiles: a narrow spur round the arch (the block) and,
## from one tile further back, the full width.

## Cone-shaped peaks: x, z, height, radius (metres).
const PEAKS := [
	Vector4(0.0, -13.0, 17.0, 15.0),
	Vector4(-10.0, -9.0, 10.5, 9.0),
	Vector4(9.5, -10.5, 12.0, 9.5),
	Vector4(-4.5, -21.0, 14.0, 11.0),
	Vector4(6.0, -22.0, 15.5, 10.0),
	Vector4(-15.0, -17.0, 8.0, 7.0),
	Vector4(15.5, -18.0, 9.0, 7.0),
]
## The rock face behind the arch: where it starts, how steeply it climbs and
## how high it gets before it leans back into the peaks.
const FACE_START := -0.7
const FACE_HEIGHT := 7.5
## How far the rock may reach: a spur as wide as the lair's tiles reaching
## to just behind the arch, and the whole width from the next row of tiles.
const SPUR_HALF := 4.2
const BACK_ROW := -3.6
const HALF_WIDTH := 19.0
const DEPTH := 32.0
## How steeply the rock may rise from the edge of where it may stand.
const FOOT_SLOPE := 2.6
## The grid of the height field, and how far its points are shaken about.
const STEP := 1.6
const JITTER := 0.5
## The foot sinks a little into the ground, so no seam shows.
const SINK := 0.25

const ROCK := Color(0.45, 0.42, 0.39)
const ROCK_DARK := Color(0.29, 0.27, 0.26)
const ROCK_HIGH := Color(0.63, 0.61, 0.58)
const MOSS := Color(0.29, 0.38, 0.21)
const EARTH := Color(0.33, 0.26, 0.19)


## How high the rock stands at (x, z), before any shaking.
static func height(x: float, z: float) -> float:
	var h := 0.0
	for p: Vector4 in PEAKS:
		var d := Vector2(x - p.x, z - p.y).length() / p.w
		if d < 1.0:
			h = maxf(h, p.z * pow(1.0 - d, 1.15))
	# The steep face the arch is set into, leaning back into the peaks.
	var face := minf((FACE_START - z) * 5.0, minf(FACE_HEIGHT + (-2.2 - z) * 0.4, 9.5))
	face *= (1.0 - smoothstep(4.5, 9.0, absf(x))) * (1.0 - smoothstep(9.0, 14.0, -z))
	h = maxf(h, face)
	return clampf(minf(h, _room(x, z) * FOOT_SLOPE), 0.0, 99.0)


## How far (x, z) lies inside the ground the rock may stand on (negative
## outside it).
static func _room(x: float, z: float) -> float:
	var back := z + DEPTH
	var spur := minf(SPUR_HALF - absf(x), FACE_START - z)
	var wide := minf(HALF_WIDTH - absf(x), BACK_ROW - z)
	return minf(maxf(spur, wide), back)


## Whether the rock covers (x, z) well enough that a tree there would stick
## out of it.
static func covers(x: float, z: float) -> bool:
	return height(x, z) > 1.0


## The mountain as one mesh, shaken by `seed_value` so it is the same every
## time the map is built.
static func build(seed_value: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var nx := int(ceil(HALF_WIDTH * 2.0 / STEP)) + 2
	var nz := int(ceil(DEPTH / STEP)) + 2
	var points := []
	for iz in nz + 1:
		var row := []
		for ix in nx + 1:
			var x := -HALF_WIDTH - STEP + ix * STEP
			var z := 0.4 - iz * STEP
			x += rng.randf_range(-JITTER, JITTER)
			z += rng.randf_range(-JITTER, JITTER)
			var h := height(x, z)
			if h > 0.5:
				# Craggy: higher rock is shaken more.
				h = maxf(0.3, h + rng.randf_range(-0.7, 0.7) * minf(1.0, h / 4.0))
			row.append(Vector3(x, h - SINK, z))
		points.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in nx:
			var a: Vector3 = points[iz][ix]
			var b: Vector3 = points[iz][ix + 1]
			var c: Vector3 = points[iz + 1][ix]
			var d: Vector3 = points[iz + 1][ix + 1]
			# Alternate the diagonal so the facets do not line up.
			if (ix + iz) % 2 == 0:
				_face(st, a, b, d, rng)
				_face(st, a, d, c, rng)
			else:
				_face(st, a, b, c, rng)
				_face(st, b, d, c, rng)
	# Weathered like the village stone (see AgedStone.rock_material).
	var mat := AgedStone.rock_material()
	var node := MeshInstance3D.new()
	node.name = "LairMountain"
	node.mesh = st.commit()
	node.material_override = mat
	return node


## One flat-shaded triangle in its own shade of stone. Faces that lie
## wholly below the ground are left out.
static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, rng: RandomNumberGenerator) -> void:
	if maxf(a.y, maxf(b.y, c.y)) <= 0.05:
		return
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
	if n.y > 0.72 and top < 10.0:
		colour = colour.lerp(MOSS, clampf((n.y - 0.72) * 3.5, 0.0, 0.75))
	colour = colour.lerp(ROCK_HIGH, smoothstep(10.0, 16.0, top) * 0.8)
	colour = colour.lerp(EARTH, 1.0 - smoothstep(0.2, 1.2, top))
	colour *= rng.randf_range(0.9, 1.08)
	colour.a = 1.0
	st.set_color(colour)
	st.set_normal(n)
	for p in [a, b, c]:
		st.add_vertex(p)
