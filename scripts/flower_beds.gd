class_name FlowerBeds
extends Node3D
## The flower beds in the paved lane of the farming valley: a row of little round beds set into the
## cobbles where the lane is two tiles wide, one at every corner the four lane tiles share (see find).
## Each is a soft, frayed patch of soil (no hard edges, it melts into the cobbles) with a ring of mossy
## pebbles round it and a dozen flowers in mixed colours.
##
## The flowers follow the seasons (see set_season, Weather.season):
##   spring  pale tulips and daisies, ankle high;
##   summer  full bloom in every colour;
##   autumn  rust, gold and burgundy, some heads already faded and brown;
##   winter  dry stalks, a few dark seed heads, frost on the soil and snow on the pebbles.
##
## Every kind of part is one MultiMesh (soil, pebbles, snow caps, stems, two kinds of flower heads), so the
## whole lane costs six draw calls however many beds it has, and a season change only rewrites the
## instances. The beds need no level to be built (tests show them on their own), but Outdoor finds their
## places (find), paves the ground under them (pave) and dresses them with the season.

## The soil patch's reach (metres from the bed's middle, where it has faded away).
const SOIL_RADIUS := 1.5
## The flowers grow within this reach, and the pebbles lie in a ring round it.
const PLANT_REACH := 1.0
const RING_FROM := 1.1
const RING_TO := 1.4
## Flowers and pebbles per bed.
const PLANTS := 24
const PEBBLES := 17
## No two flowers closer than this (metres).
const PLANT_GAP := 0.23
## Pebbles per ground-mask pixel's reach: the ground mask has 4 pixels to a tile (see Outdoor._build_ground).
const MASK_PX := 4

## How a season dresses the plants: how tall the stems stand, how big the heads are, the tint of stems
## and leaves, the soil, and the share of plants that carry a head at all.
const LOOK := {
	"spring": {"stem": 0.36, "head": 1.0, "green": Color(1.1, 1.22, 0.85), "soil": Color(0.4, 0.29, 0.2), "heads": 1.0},
	"summer": {"stem": 0.5, "head": 1.3, "green": Color(1.0, 1.0, 1.0), "soil": Color(0.36, 0.26, 0.18), "heads": 1.0},
	"autumn": {"stem": 0.43, "head": 1.15, "green": Color(1.75, 1.1, 0.5), "soil": Color(0.32, 0.23, 0.16), "heads": 0.85},
	"winter": {"stem": 0.2, "head": 0.7, "green": Color(1.35, 0.8, 0.5), "soil": Color(0.82, 0.86, 0.94), "heads": 0.3},
}
## The blooms of each season (a plant keeps its place in the list, so a bed keeps its pattern).
const BLOOMS := {
	"spring": [Color(1.0, 0.86, 0.3), Color(0.98, 0.96, 0.9), Color(0.98, 0.62, 0.74), Color(0.7, 0.72, 0.98), Color(0.96, 0.5, 0.45), Color(0.84, 0.7, 0.96)],
	"summer": [Color(0.88, 0.14, 0.2), Color(1.0, 0.8, 0.14), Color(0.6, 0.26, 0.86), Color(0.98, 0.97, 0.92), Color(1.0, 0.46, 0.62), Color(0.24, 0.42, 0.94)],
	"autumn": [Color(0.86, 0.42, 0.07), Color(0.86, 0.64, 0.12), Color(0.6, 0.12, 0.08), Color(0.74, 0.28, 0.08), Color(0.52, 0.18, 0.32), Color(0.8, 0.5, 0.1)],
	"winter": [Color(0.38, 0.28, 0.18), Color(0.46, 0.36, 0.24)],
}
## An autumn bloom that has faded: its colour, and how much smaller it is.
const FADED := Color(0.62, 0.5, 0.34)
const FADED_SHARE := 0.4

static var _meshes := {}
static var _materials := {}

var _season := ""
var _beds: Array[Vector3] = []
var _plants: Array = []
var _pebbles: Array = []
var _soil: Array = []
var _mm := {}


## The places of the beds on `level` (an Outdoor): the middle of every block of four dirt-path tiles
## within the village (the lane's seam, where the paving's joints once left bare squares).
static func find(level: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for y in level.height - 1:
		for x in level.width - 1:
			var ok := true
			for dy in 2:
				for dx in 2:
					var c := Vector2i(x + dx, y + dy)
					if level.cell_char(c) != "," or not level.near_village(c):
						ok = false
			if ok:
				out.append((level.cell_to_world(Vector2i(x, y)) + level.cell_to_world(Vector2i(x + 1, y + 1))) * 0.5)
	return out


## Paves the ground mask `img` solid round every bed (so no bare square of the cobbles' joints is left, the
## bed's own soil is drawn on top, see grow). `tile` is the tile size in metres.
static func pave(img: Image, spots: Array[Vector3], tile: float) -> void:
	for at in spots:
		var p := Vector2(at.x / tile + 0.5, at.z / tile + 0.5) * MASK_PX
		for y in range(floori(p.y - 4.0), ceili(p.y + 4.0)):
			for x in range(floori(p.x - 4.0), ceili(p.x + 4.0)):
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var m := img.get_pixel(x, y)
				var paved := clampf(3.2 - Vector2(x + 0.5, y + 0.5).distance_to(p), 0.0, 1.0)
				m.r = maxf(m.r, paved)
				m.g = maxf(m.g, paved)
				img.set_pixel(x, y, m)


## Plants the beds at `spots` (world positions, on the ground) as children of `parent`.
static func grow(parent: Node3D, spots: Array[Vector3], seed_value: int) -> FlowerBeds:
	var out := FlowerBeds.new()
	out.name = "FlowerBeds"
	parent.add_child(out)
	out._plant(spots, seed_value)
	return out


## Dresses every bed for season day `day` (see Weather.season).
func set_season(day: int) -> void:
	var season := Weather.season(day)
	if season == _season:
		return
	_season = season
	var look: Dictionary = LOOK[season]
	var blooms: Array = BLOOMS[season]
	var winter := season == Weather.WINTER
	var autumn := season == Weather.AUTUMN
	# The soil: dark and damp, or under frost.
	var soil: MultiMesh = _mm.soil
	for i in _soil.size():
		var s: Array = _soil[i]
		var tint: Color = look.soil
		var shade := 0.9 + 0.2 * float(s[2])
		soil.set_instance_color(i, Color(tint.r * shade, tint.g * shade, tint.b * shade))
	# Pebbles keep their moss, and wear a cap of snow in winter.
	var snow: MultiMesh = _mm.snow
	for i in _pebbles.size():
		var p: Array = _pebbles[i]
		var cap := Basis(Vector3.UP, p[1]).scaled(Vector3(p[2] * 0.9, p[2] * 0.4, p[2] * 0.9 * p[3])) if winter else Basis().scaled(Vector3.ONE * 0.0001)
		snow.set_instance_transform(i, Transform3D(cap, (p[0] as Vector3) + Vector3(0, p[2] * p[4] * 0.62, 0)))
	# The plants.
	var stems: MultiMesh = _mm.stems
	var daisies: MultiMesh = _mm.daisies
	var cups: MultiMesh = _mm.cups
	var d := 0
	var c := 0
	for i in _plants.size():
		var pl: Dictionary = _plants[i]
		var tall: float = look.stem * pl.height
		var green: Color = look.green
		var shade: float = pl.shade
		var basis := Basis(Vector3.UP, pl.turn).scaled(Vector3(1.0, tall, 1.0))
		stems.set_instance_transform(i, Transform3D(basis, pl.at))
		stems.set_instance_color(i, Color(green.r * shade, green.g * shade, green.b * shade))
		# Does it carry a head now? Each plant has its own dice, so winter keeps the same few.
		var heads: bool = pl.dice < look.heads
		var bloom: Color = blooms[pl.colour % blooms.size()]
		var size: float = look.head * pl.head * (1.0 if heads else 0.0)
		if autumn and pl.fade < FADED_SHARE and heads:
			bloom = FADED
			size *= 0.8
		if winter:
			bloom = blooms[pl.colour % blooms.size()]
		var top: Vector3 = (pl.at as Vector3) + Vector3(0, STEM_TOP * tall, 0) + Vector3(STEM_LEAN, 0, 0).rotated(Vector3.UP, pl.turn) * tall
		var head := Basis(Vector3.UP, pl.turn * 1.7) * Basis(Vector3.RIGHT, pl.nod).scaled(Vector3.ONE * maxf(size, 0.0001))
		if pl.kind == 0:
			daisies.set_instance_transform(d, Transform3D(head, top))
			daisies.set_instance_color(d, bloom)
			d += 1
		else:
			cups.set_instance_transform(c, Transform3D(head, top))
			cups.set_instance_color(c, bloom)
			c += 1


## The look the beds wear now ("" before the first season is set).
func season() -> String:
	return _season


## How many flower heads show now (for the tests): a head too small to see does not count.
func visible_heads() -> int:
	var n := 0
	for name in ["daisies", "cups"]:
		var mm: MultiMesh = _mm[name]
		for i in mm.instance_count:
			if mm.get_instance_transform(i).basis.get_scale().x > 0.01:
				n += 1
	return n


## How many beds there are.
func bed_count() -> int:
	return _beds.size()


# --- Planting --------------------------------------------------------------------

## Where a stem's tip lies on a unit-tall stem (see _stem), and how far it leans.
const STEM_TOP := 1.0
const STEM_LEAN := 0.05


func _plant(spots: Array[Vector3], seed_value: int) -> void:
	_beds = spots.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for at in _beds:
		_soil.append([at, rng.randf() * TAU, rng.randf()])
		# Flowers in loose clusters of one or two colours, so the bed reads as a bunch, not as confetti.
		var centres := []
		for k in 4:
			centres.append([Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.15, 0.7), rng.randi() % 6])
		var placed: Array[Vector2] = []
		var tries := 0
		while placed.size() < PLANTS and tries < 200:
			tries += 1
			var cluster: Array = centres[rng.randi() % centres.size()]
			var p: Vector2 = (cluster[0] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.5)
			if p.length() > PLANT_REACH or placed.any(func(q: Vector2): return q.distance_to(p) < PLANT_GAP):
				continue
			placed.append(p)
			_plants.append({
				"at": at + Vector3(p.x, 0.02, p.y), "turn": rng.randf() * TAU, "height": rng.randf_range(0.75, 1.25),
				"head": rng.randf_range(0.85, 1.25), "shade": rng.randf_range(0.85, 1.12),
				"colour": (cluster[1] + (rng.randi() % 2)) % 6, "kind": 0 if rng.randf() < 0.55 else 1,
				"dice": rng.randf(), "fade": rng.randf(), "nod": rng.randf_range(-0.3, 0.3),
			})
		# A few small stones lie in the bed among the flowers.
		for k in 5:
			var inner := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 0.95)
			var s := rng.randf_range(0.04, 0.07)
			_pebbles.append([at + Vector3(inner.x, s * 0.3, inner.y), rng.randf() * TAU, s, rng.randf_range(0.7, 1.2), rng.randf_range(0.5, 0.75)])
		# A ring of pebbles with gaps, bigger ones now and then.
		for k in PEBBLES:
			var a := TAU * (k + rng.randf_range(-0.3, 0.3)) / PEBBLES
			var r := rng.randf_range(RING_FROM, RING_TO)
			var s := rng.randf_range(0.09, 0.17) * (1.45 if rng.randf() < 0.2 else 1.0)
			var flat := rng.randf_range(0.7, 1.2)
			var lump := rng.randf_range(0.5, 0.75)
			_pebbles.append([at + Vector3(cos(a) * r, s * lump * 0.4, sin(a) * r), rng.randf() * TAU, s, flat, lump])
	_make_multimesh("soil", _soil_mesh(), _soil.size(), true)
	_make_multimesh("pebbles", _pebble_mesh(), _pebbles.size(), false)
	_make_multimesh("snow", _pebble_mesh(true), _pebbles.size(), false)
	_make_multimesh("stems", _stem_mesh(), _plants.size(), true)
	var daisies := _plants.filter(func(pl: Dictionary): return pl.kind == 0).size()
	_make_multimesh("daisies", _head_mesh(0), daisies, true)
	_make_multimesh("cups", _head_mesh(1), _plants.size() - daisies, true)
	# The soil and the pebbles never change, only their tint does.
	var soil: MultiMesh = _mm.soil
	for i in _soil.size():
		var s: Array = _soil[i]
		var size := SOIL_RADIUS * 2.0 * (0.92 + 0.14 * float(s[2]))
		soil.set_instance_transform(i, Transform3D(Basis(Vector3.UP, s[1]).scaled(Vector3(size, 1.0, size)), (s[0] as Vector3) + Vector3(0, 0.014, 0)))
	var pebbles: MultiMesh = _mm.pebbles
	for i in _pebbles.size():
		var p: Array = _pebbles[i]
		var basis := Basis(Vector3.UP, p[1]).scaled(Vector3(p[2], p[2] * p[4], p[2] * p[3]))
		pebbles.set_instance_transform(i, Transform3D(basis, p[0]))
		var grey := 0.85 + 0.25 * float(i % 7) / 7.0
		pebbles.set_instance_color(i, Color(grey, grey, grey * 0.97))


func _make_multimesh(key: String, mesh: Mesh, count: int, coloured: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.name = "Bed" + key.capitalize()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	_mm[key] = mm
	# Soil and snow caps start hidden-neutral; their tint is set by the season.
	if not coloured:
		for i in count:
			mm.set_instance_color(i, Color.WHITE)
	if key == "snow":
		for i in count:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3.ZERO))


# --- Meshes and textures -----------------------------------------------------------

## The soil: a flat square whose texture is a frayed round patch of earth, fading out at the rim.
static func _soil_mesh() -> Mesh:
	if _meshes.has("soil"):
		return _meshes["soil"]
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.albedo_texture = _soil_texture()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.render_priority = FogClouds.UNDER_FOG
	plane.material = m
	_meshes["soil"] = plane
	return plane


## Earth in grey tones (the season tints it): packed crumbs, darker damp hollows, small pale grit and
## now and then a root thread, inside a rim that fades out raggedly.
static func _soil_texture() -> Texture2D:
	var size := 192
	var big := FastNoiseLite.new()
	big.seed = 41
	big.frequency = 0.018
	big.fractal_octaves = 4
	var rim := FastNoiseLite.new()
	rim.seed = 77
	rim.frequency = 0.05
	rim.fractal_octaves = 3
	var grit := FastNoiseLite.new()
	grit.seed = 9
	grit.frequency = 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var r := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
			var edge := rim.get_noise_2d(x, y) * 0.16
			# Solid to about 80 % of the radius, then a soft, ragged fall-off.
			var a := smoothstep(0.98, 0.7, r + edge)
			var shade := 0.82 + 0.16 * big.get_noise_2d(x, y) + 0.1 * grit.get_noise_2d(x, y)
			# A darker, damper skirt just inside the rim.
			shade *= 1.0 - 0.18 * smoothstep(0.55, 0.85, r + edge)
			img.set_pixel(x, y, Color(shade, shade * 0.99, shade * 0.97, a))
	# Grit: small pale crumbs and a few dark pebbles pressed into the soil, and thin roots.
	for i in 150:
		var p := Vector2(rng.randf(), rng.randf()) * size
		if (p - Vector2(size, size) * 0.5).length() > size * 0.4:
			continue
		var light := rng.randf() < 0.6
		var rad := rng.randf_range(0.7, 1.9)
		for y in range(floori(p.y - rad), ceili(p.y + rad) + 1):
			for x in range(floori(p.x - rad), ceili(p.x + rad) + 1):
				if x < 0 or y < 0 or x >= size or y >= size or Vector2(x, y).distance_to(p) > rad:
					continue
				var c := img.get_pixel(x, y)
				var v := 1.12 if light else 0.62
				img.set_pixel(x, y, Color(minf(c.r * v, 1.0), minf(c.g * v, 1.0), minf(c.b * v, 1.0), c.a))
	for i in 7:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.1, 0.3) * size + Vector2(size, size) * 0.5
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for k in 34:
			p += dir * 1.1
			dir = dir.rotated(rng.randf_range(-0.25, 0.25))
			var px := Vector2i(p)
			if px.x >= 0 and px.y >= 0 and px.x < size and px.y < size and (p - Vector2(size, size) * 0.5).length() < size * 0.38:
				var c := img.get_pixelv(px)
				img.set_pixelv(px, Color(c.r * 0.66, c.g * 0.62, c.b * 0.55, c.a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A pebble: a lumpy ball, grey below and mossy green on top, with a speckled stone texture.
static func _pebble_mesh(snow := false) -> Mesh:
	var key := "snow" if snow else "pebble"
	if _meshes.has(key):
		return _meshes[key]
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 10
	ball.rings = 6
	var arrays := ball.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var bump := FastNoiseLite.new()
	bump.seed = 3
	bump.frequency = 1.3
	for i in verts.size():
		var n := verts[i].normalized()
		verts[i] = n * (1.0 + 0.16 * bump.get_noise_3dv(n * 2.0))
		if snow:
			cols.append(Color(0.96, 0.98, 1.0))
			continue
		var moss := smoothstep(0.35, 0.95, n.y + 0.9 * bump.get_noise_3dv(n * 3.0 + Vector3(9, 9, 9)))
		var stone := Color(0.74, 0.71, 0.65).lerp(Color(0.58, 0.55, 0.52), rng.randf() * 0.4)
		cols.append(stone.lerp(Color(0.34, 0.52, 0.2), moss * 0.85))
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_NORMAL] = _smooth_normals(arrays)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.albedo_texture = _speckle_texture()
	m.roughness = 0.6 if snow else 0.92
	mesh.surface_set_material(0, m)
	_meshes[key] = mesh
	return mesh


## Vertex normals of a mesh from its triangles, smooth over shared (equal) vertices.
static func _smooth_normals(arrays: Array) -> PackedVector3Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var sum := {}
	for t in idx.size() / 3:
		var a := verts[idx[t * 3]]
		var b := verts[idx[t * 3 + 1]]
		var c := verts[idx[t * 3 + 2]]
		var n := (b - a).cross(c - a)
		for v in [a, b, c]:
			var key := Vector3i((v * 1000.0).round())
			sum[key] = sum.get(key, Vector3.ZERO) + n
	var out := PackedVector3Array()
	for v in verts:
		out.append((sum[Vector3i((v * 1000.0).round())] as Vector3).normalized())
	return out


static func _speckle_texture() -> Texture2D:
	if _materials.has("speckle"):
		return _materials["speckle"]
	var noise := FastNoiseLite.new()
	noise.seed = 14
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for y in size:
		for x in size:
			var v := 0.82 + 0.3 * noise.get_noise_2d(x, y) + rng.randf_range(-0.06, 0.06)
			if rng.randf() < 0.04:
				v *= 0.7
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_materials["speckle"] = tex
	return tex


## A stem with a rosette of leaves at its foot and two small leaves up it, one unit tall (the instance's
## height scales it), the tint in the vertex colours.
static func _stem_mesh() -> Mesh:
	if _meshes.has("stem"):
		return _meshes["stem"]
	var st := _Soup.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var lean := Vector3(STEM_LEAN, 0, 0)
	for side: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0)]:
		st.blade(Vector3.ZERO, Vector3(0, STEM_TOP, 0), 0.026, 0.012, Color(0.34, 0.52, 0.18), lean, 0.0, side, 5)
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf_range(-0.25, 0.25)
		var out := Vector3(cos(a), 0, sin(a))
		var reach := rng.randf_range(0.12, 0.3)
		st.blade(Vector3(0, 0.015, 0), out * reach + Vector3(0, rng.randf_range(0.08, 0.2), 0), 0.11, 0.008, Color(0.3, 0.5, 0.17).lerp(Color(0.42, 0.6, 0.2), rng.randf()), Vector3(0, -rng.randf_range(0.05, 0.14), 0), 1.1, Vector3.ZERO, 4)
	for i in 2:
		var a := rng.randf() * TAU + i * PI
		var out := Vector3(cos(a), 0, sin(a))
		var y := 0.3 + 0.18 * i
		st.blade(Vector3(0, y, 0), out * 0.14 + Vector3(0, y + 0.1, 0), 0.05, 0.004, Color(0.32, 0.5, 0.16), Vector3(0, -0.04, 0), 0.8, Vector3.ZERO, 3)
	var mesh := st.finish(_leaf_material())
	_meshes["stem"] = mesh
	return mesh


## A flower head, its middle at the origin, facing up: a daisy (a flat star of petals round a seed disc) or a
## cup (a tulip's six petals standing round a middle). The bloom's colour is the instance's.
static func _head_mesh(kind: int) -> Mesh:
	var key := "head%d" % kind
	if _meshes.has(key):
		return _meshes[key]
	var st := _Soup.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 60 + kind
	var white := Color(1, 1, 1)
	if kind == 0:
		for ring in 2:
			var n := 9 if ring == 0 else 7
			for j in n:
				var a := TAU * (j + 0.5 * ring) / n + rng.randf_range(-0.08, 0.08)
				var out := Vector3(cos(a), 0, sin(a))
				var len := 0.11 if ring == 0 else 0.085
				var shade := white if ring == 0 else Color(0.9, 0.9, 0.9)
				st.blade(out * 0.02 + Vector3(0, 0.004 * ring, 0), out * len + Vector3(0, 0.025 + 0.01 * ring, 0), 0.05, 0.016, shade, Vector3(0, 0.01, 0), 0.7, Vector3(-out.z, 0, out.x), 3)
		st.disc(Vector3(0, 0.022, 0), 0.032, Color(0.5, 0.36, 0.08), 10, true)
		st.disc(Vector3(0, 0.03, 0), 0.02, Color(0.42, 0.28, 0.05), 8, true)
	else:
		for j in 6:
			var a := TAU * j / 6.0 + (0.5 if j % 2 == 1 else 0.0) * 0.0
			var out := Vector3(cos(a), 0, sin(a))
			var ring := 0.0 if j % 2 == 0 else 0.012
			st.blade(out * (0.02 + ring), out * (0.065 - ring) + Vector3(0, 0.13 - ring, 0), 0.058, 0.02, Color(0.92, 0.92, 0.92) if j % 2 == 1 else white, out * -0.022 + Vector3(0, 0.006, 0), 1.0, Vector3(-out.z, 0, out.x), 4)
		st.disc(Vector3(0, 0.012, 0), 0.026, Color(0.45, 0.3, 0.06), 8, true)
	var mesh := st.finish(_leaf_material())
	_meshes[key] = mesh
	return mesh


static func _leaf_material() -> StandardMaterial3D:
	if _materials.has("leaf"):
		return _materials["leaf"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.albedo_texture = CropFields._leaf_texture_cached()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.85
	_materials["leaf"] = m
	return m


## A bag of triangles with vertex colours, normals and texture coordinates (like CropFields' soup, with
## upward-facing normals so the thin blades are lit from above).
class _Soup extends RefCounted:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
		var n := (b - a).cross(c - a).normalized()
		# Blades are seen from both sides: light them as if they faced up where they lie flat.
		n = (n + Vector3.UP * 0.6 * signf(n.y if absf(n.y) > 0.05 else 1.0)).normalized()
		var us := [ua, ub, uc]
		var i := 0
		for p in [a, b, c]:
			verts.append(p)
			cols.append(col)
			norms.append(n)
			uvs.append(us[i])
			i += 1

	## A curved blade from `a` to `b` bending by `bend` (quadratic), swelling by `belly` in the middle, in
	## `segs` segments; `side` is the direction across it (along x z if left zero).
	func blade(a: Vector3, b: Vector3, wa: float, wb: float, col: Color, bend: Vector3, belly: float, side: Vector3, segs: int) -> void:
		var along := (b - a).normalized()
		var across := side
		if across == Vector3.ZERO:
			across = along.cross(Vector3.UP)
			if across.length() < 0.01:
				across = Vector3.RIGHT
		across = across.normalized()
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for i in segs + 1:
			var t := float(i) / segs
			var mid := a.lerp(b, t) + bend * t * t
			var w := lerpf(wa, wb, t) * (1.0 + 0.5 * belly * sin(PI * t))
			var l := mid - across * w * 0.5
			var r := mid + across * w * 0.5
			if i > 0:
				var t0 := float(i - 1) / segs
				tri(prev_l, prev_r, r, col, Vector2(0, t0), Vector2(1, t0), Vector2(1, t))
				tri(prev_l, r, l, col, Vector2(0, t0), Vector2(1, t), Vector2(0, t))
			prev_l = l
			prev_r = r

	## A flat disc facing up (`up`) or +Z.
	func disc(mid: Vector3, radius: float, col: Color, sides: int, up := false) -> void:
		for j in sides:
			var a0 := TAU * j / sides
			var a1 := TAU * (j + 1) / sides
			var p0 := mid + (Vector3(cos(a0), 0, sin(a0)) if up else Vector3(cos(a0), sin(a0), 0)) * radius
			var p1 := mid + (Vector3(cos(a1), 0, sin(a1)) if up else Vector3(cos(a1), sin(a1), 0)) * radius
			tri(mid, p1, p0, col, Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5))

	func finish(mat: Material) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, mat)
		return mesh
