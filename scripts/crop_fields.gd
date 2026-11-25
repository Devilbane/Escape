class_name CropFields
extends Node3D
## The fields of the farming valley: wheat ("≡"), maize ("‡") and sunflowers ("☼"), each tile a patch of
## dark soil with its crop standing in rows (see Outdoor). The plants of a kind are one MultiMesh, so a
## whole field is a single draw call. They follow the seasons (see Weather.season):
##   spring  bare soil until the farmers sow it (see sow_near), then shoots that grow ankle high over a few days;
##   summer  wheat ripe and golden, maize tall and green, sunflowers in full yellow bloom;
##   autumn  wheat cut to stubble, maize dry and brown, sunflowers drooping and brown;
##   winter  stubble and cut stalks, pale and dull.
## Built from a list of ground positions per kind, so it needs no level (tests show it on its own).

const WHEAT := "≡"
const MAIZE := "‡"
const SUNFLOWER := "☼"
const LETTERS := "≡‡☼"
## Soil under the crops (the ground draws the same dark earth as the pumpkin field).
const NAMES := {"≡": "wheat", "‡": "maize", "☼": "sunflower"}
## Plants in a row and between rows (metres): a tile is 4 m, so 7 x 7 tufts of wheat, 4 x 4 maize and sunflowers.
const SPACING := {"≡": 0.57, "‡": 1.0, "☼": 1.0}
## Full height of a plant (metres, before the season scales it).
const HEIGHT := {"≡": 1.0, "‡": 1.9, "☼": 1.75}

## What each season does to a kind: [height scale, colour].
const LOOK := {
	"≡": {"spring": [0.3, Color(0.55, 1.15, 0.7)], "summer": [1.0, Color(1, 1, 1)],
			"autumn": [0.16, Color(0.9, 0.8, 0.6)], "winter": [0.12, Color(0.8, 0.76, 0.7)]},
	"‡": {"spring": [0.22, Color(0.7, 1.2, 0.7)], "summer": [1.0, Color(1, 1, 1)],
			"autumn": [0.95, Color(1.3, 0.95, 0.5)], "winter": [0.18, Color(0.8, 0.74, 0.62)]},
	"☼": {"spring": [0.2, Color(0.7, 1.2, 0.7)], "summer": [1.0, Color(1, 1, 1)],
			"autumn": [0.9, Color(0.55, 0.5, 0.38)], "winter": [0.16, Color(0.72, 0.68, 0.6)]},
}

## The days after sowing it takes a sprout to reach its spring height, and the spring day (0 is the first) on which
## fields nobody sowed are sown anyway (a rainy day, nobody about), so spring never ends with bare soil.
const SPROUT_DAYS := 3
const AUTO_SOW_DAY := 3
## How tall a sprout stands (a share of the spring height) at 0, 1 and 2 days after the seed went in.
const SPROUT_STEPS := [0.1, 0.4, 0.75]
## A field with nothing in it yet (a share of the height; not zero, so the transform stays valid).
const BARE := 0.001

var _fields := {}
var _season := ""
var _day := -1
## Per kind, the tiles: [{"mid": Vector3, "first": int, "count": int, "sown": int}] (spring day sown, -1 = bare).
var _tiles := {}
static var _meshes := {}


## Plants the fields: `cells` maps a letter to the middles of its tiles (world positions, tile size `tile`).
static func grow(parent: Node3D, cells: Dictionary, tile: float, seed_value: int) -> CropFields:
	var out := CropFields.new()
	out.name = "CropFields"
	parent.add_child(out)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for letter: String in cells:
		var spots: Array = []
		var step: float = SPACING[letter]
		var tiles: Array = []
		for mid: Vector3 in cells[letter]:
			tiles.append({"mid": mid, "first": spots.size(), "count": 0, "sown": -1})
			var n := int(round(tile / step))
			for ix in n:
				for iz in n:
					var at := mid + Vector3((ix + 0.5) * step - tile * 0.5, 0, (iz + 0.5) * step - tile * 0.5)
					at += Vector3(rng.randf_range(-0.12, 0.12) * step, 0, rng.randf_range(-0.12, 0.12) * step)
					spots.append([at, rng.randf() * TAU, rng.randf_range(0.85, 1.15), rng.randf()])
			tiles[-1].count = spots.size() - tiles[-1].first
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh(letter)
		mm.instance_count = spots.size()
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.name = String(NAMES[letter]).capitalize()
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.add_child(inst)
		out._fields[letter] = {"mm": mm, "spots": spots}
		out._tiles[letter] = tiles
	return out


## Dresses every field for season day `day` (see Weather.season). A new day in spring grows the sprouts on.
func set_season(day: int) -> void:
	var season := Weather.season(day)
	if season == _season and (season != Weather.SPRING or day == _day):
		return
	if season != Weather.SPRING:
		# The year's seed is gone with the harvest: next spring starts on bare soil again.
		for letter: String in _tiles:
			for t: Dictionary in _tiles[letter]:
				t.sown = -1
	_season = season
	_day = day
	for letter: String in _fields:
		for i in (_tiles[letter] as Array).size():
			_dress_tile(letter, i)


## The spring day (0 is the first) of season day `day`, or -1 outside spring.
func spring_day() -> int:
	return posmod(_day, Weather.YEAR_DAYS) if _season == Weather.SPRING else -1


## How tall a tile of kind `letter` stands now, as a share of the season's height: bare soil, sprouts or the
## full look of the season.
func tile_growth(letter: String, tile: int) -> float:
	if _season != Weather.SPRING:
		return 1.0
	var sown: int = _tiles[letter][tile].sown
	var today := spring_day()
	if sown < 0 and today >= AUTO_SOW_DAY:
		sown = AUTO_SOW_DAY
	if sown < 0:
		return BARE
	var age := today - sown
	return 1.0 if age >= SPROUT_STEPS.size() else SPROUT_STEPS[maxi(age, 0)]


func _dress_tile(letter: String, tile: int) -> void:
	var look: Array = LOOK[letter][_season]
	var mm: MultiMesh = _fields[letter].mm
	var spots: Array = _fields[letter].spots
	var t: Dictionary = _tiles[letter][tile]
	var growth := tile_growth(letter, tile)
	for i in range(t.first, t.first + t.count):
		var s: Array = spots[i]
		var grown: float = look[0] * s[2] * growth
		# Seedlings are narrow as well as short; bare soil shows no leaf at all.
		var width := minf(1.0, growth * 4.0)
		var basis := Basis(Vector3.UP, s[1]).scaled(Vector3(width, grown, width))
		mm.set_instance_transform(i, Transform3D(basis, s[0]))
		var tint: Color = look[1]
		var shade := 0.88 + 0.24 * float(s[3])
		mm.set_instance_color(i, Color(tint.r * shade, tint.g * shade, tint.b * shade))


## Whether the seed may still go in: the first spring days, before the rest is sown anyway (see AUTO_SOW_DAY).
func sowing_time() -> bool:
	return _season == Weather.SPRING and spring_day() < AUTO_SOW_DAY


## The tiles of kind `letter` nobody has sown yet this spring, as world positions of their middles (empty outside
## spring, or once every tile is sown).
func bare_tiles(letter: String) -> Array:
	var out: Array = []
	if not sowing_time() or not _tiles.has(letter):
		return out
	for t: Dictionary in _tiles[letter]:
		if t.sown < 0:
			out.append(t.mid)
	return out


## Whether any tile of any kind still lies bare, waiting for the seed.
func any_bare() -> bool:
	for letter: String in _tiles:
		if not bare_tiles(letter).is_empty():
			return true
	return false


## A farmer's handful lands at `at`: the nearest bare tile of kind `letter` within `reach` metres is sown (it
## starts to sprout at once and grows on with the days). True when a tile was sown.
func sow_near(letter: String, at: Vector3, reach: float) -> bool:
	if not sowing_time() or not _tiles.has(letter):
		return false
	var best := -1
	var best_d := reach * reach
	var tiles: Array = _tiles[letter]
	for i in tiles.size():
		if tiles[i].sown >= 0:
			continue
		var d := Vector2(tiles[i].mid.x - at.x, tiles[i].mid.z - at.z).length_squared()
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	tiles[best].sown = spring_day()
	_dress_tile(letter, best)
	return true


## How tall the plants of a kind stand now, as a share of their full height.
func height_scale(letter: String) -> float:
	return LOOK[letter][_season][0] if _season != "" else 1.0


## The look the fields wear now ("" before the first season is set).
func season() -> String:
	return _season


# --- The plants ------------------------------------------------------------------

static func _mesh(letter: String) -> ArrayMesh:
	if _meshes.has(letter):
		return _meshes[letter]
	var st := _Soup.new()
	match letter:
		WHEAT:
			_wheat(st)
		MAIZE:
			_maize(st)
		_:
			_sunflower(st)
	var mesh := st.finish()
	_meshes[letter] = mesh
	return mesh


static func _wheat(st: _Soup) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var stalk := Color(0.86, 0.74, 0.38)
	var ear := Color(0.92, 0.72, 0.28)
	var awn := Color(0.96, 0.86, 0.5)
	# Six stalks in a loose bunch: a curved stem, a drooping leaf, and an ear of paired kernels with awns.
	for i in 6:
		var base := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		var lean := Vector3(rng.randf_range(-0.09, 0.09), 0, rng.randf_range(-0.09, 0.09))
		var h := HEIGHT[WHEAT] * rng.randf_range(0.85, 1.0)
		var top := base + lean + Vector3(0, h * 0.78, 0)
		st.leaf(base, top, 0.02, 0.01, stalk, lean * 0.6, 1.0, Vector3.ZERO, 2)
		var turn := rng.randf() * TAU
		var out := Vector3(cos(turn), 0, sin(turn))
		st.leaf(base + Vector3(0, h * 0.25, 0), base + out * 0.3 + Vector3(0, h * 0.55, 0), 0.05, 0.004, Color(0.6, 0.66, 0.3), out * 0.25 + Vector3(0, -0.25, 0), 1.0, Vector3.ZERO, 3)
		# The ear: six pairs of kernels climbing the stalk, each pair a little smaller, long awns above.
		for k in 6:
			var y := top + Vector3(lean.x * 0.3 * k * 0.1, k * 0.055, lean.z * 0.3 * k * 0.1)
			var w := 0.05 - k * 0.005
			var side := Vector3(cos(turn), 0, sin(turn))
			st.leaf(y, y + side * w + Vector3(0, 0.05, 0), 0.026, 0.01, ear, Vector3.ZERO, 1.0, Vector3.ZERO, 1)
			st.leaf(y, y - side * w + Vector3(0, 0.05, 0), 0.026, 0.01, ear, Vector3.ZERO, 1.0, Vector3.ZERO, 1)
		var tip := top + Vector3(lean.x * 0.3, 0.36, lean.z * 0.3)
		for k in 2:
			var o := Vector3(cos(turn + k * 3.1), 0, sin(turn + k * 2.1)) * 0.05
			st.leaf(tip - Vector3(0, 0.06, 0), tip + o + Vector3(0, 0.16, 0), 0.008, 0.002, awn, o, 1.0, Vector3.ZERO, 1)


static func _maize(st: _Soup) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var green := Color(0.5, 0.64, 0.24)
	var leaf := Color(0.42, 0.6, 0.2)
	var husk := Color(0.62, 0.72, 0.34)
	var kern := Color(0.97, 0.8, 0.22)
	for k in 2:
		var base := Vector3(-0.2 + k * 0.4, 0, rng.randf_range(-0.15, 0.15))
		var h: float = HEIGHT[MAIZE] * rng.randf_range(0.9, 1.0)
		st.leaf(base, base + Vector3(0.03, h, 0.02), 0.06, 0.025, green, Vector3(0.05, 0, 0), 0.0)
		# Long arching leaves with a drooping tip and a pale midrib.
		for j in 7:
			var turn := TAU * (j / 7.0) * 1.0 + k * 1.3
			var out := Vector3(cos(turn), 0, sin(turn))
			var y := h * (0.22 + 0.095 * j)
			st.leaf(base + Vector3(0, y, 0), base + out * 0.62 + Vector3(0, y + 0.18, 0), 0.1, 0.006, leaf, Vector3(0, -0.5 - 0.05 * j, 0), 1.0)
		# Two cobs: green husk leaves round a core of yellow kernel rows, silk at the tip.
		for c in 2:
			var cy := h * (0.5 + 0.12 * c)
			var dir := Vector3(cos(k * 2.0 + c * 3.0), 0, sin(k * 2.0 + c * 3.0))
			var a := base + dir * 0.05 + Vector3(0, cy, 0)
			var b := a + dir * 0.1 + Vector3(0, 0.3, 0)
			st.leaf(a, b, 0.07, 0.05, kern, Vector3.ZERO, 0.0, Vector3.ZERO, 2)
			for q in 3:
				var o := Vector3(cos(q * 2.1), 0, sin(q * 2.1)) * 0.035
				st.leaf(a + o, b + o * 0.6, 0.05, 0.012, husk, o * 0.4, 0.0, Vector3.ZERO, 2)
			st.leaf(b, b + dir * 0.03 + Vector3(0, 0.1, 0), 0.012, 0.002, Color(0.8, 0.62, 0.35), Vector3(0.02, 0, 0), 0.0, Vector3.ZERO, 1)
		# The tassel: a fan of thin spikes at the top.
		for t in 5:
			var o := Vector3(cos(t * 1.26), 0, sin(t * 1.26)) * 0.16
			st.leaf(base + Vector3(0.03, h, 0.02), base + o + Vector3(0.03, h + 0.2, 0.02), 0.014, 0.003, Color(0.86, 0.8, 0.46), o * 0.3, 0.0, Vector3.ZERO, 1)


static func _sunflower(st: _Soup) -> void:
	var stalk := Color(0.38, 0.5, 0.2)
	var leaf := Color(0.34, 0.52, 0.18)
	var h: float = HEIGHT[SUNFLOWER]
	# A thick stem bowing a little toward the head, and broad heart-shaped leaves along it.
	st.leaf(Vector3.ZERO, Vector3(0, h, 0.05), 0.07, 0.045, stalk, Vector3(0, 0, 0.12), 0.0)
	for j in 5:
		var turn := j * 2.4
		var out := Vector3(cos(turn), 0, sin(turn))
		var y := h * (0.2 + 0.13 * j)
		var l := 0.46 - 0.04 * j
		st.leaf(Vector3(0, y, 0), out * l + Vector3(0, y + 0.1, 0), 0.26, 0.01, leaf, Vector3(0, -0.28, 0), 1.0)
	# The head looks south, toward the camera: green sepals behind, two rings of petals, the seed disc.
	var head := Vector3(0, h, 0.07)
	st.ring(head + Vector3(0, 0, -0.03), 0.27, 0.27, 0.03, Color(0.3, 0.42, 0.14), 14)
	var petal := Color(1.0, 0.8, 0.12)
	var petal2 := Color(0.96, 0.7, 0.08)
	for j in 13:
		var a := TAU * (j + 0.5) / 13.0
		var out := Vector3(cos(a), sin(a), 0.0)
		st.leaf(head + out * 0.2, head + out * 0.58 + Vector3(0, 0, 0.04), 0.11, 0.02, petal2, Vector3(0, 0, 1), 0.0)
	for j in 17:
		var a := TAU * j / 17.0
		var out := Vector3(cos(a), sin(a), 0.0)
		st.leaf(head + out * 0.16 + Vector3(0, 0, 0.02), head + out * 0.52 + Vector3(0, 0, 0.1), 0.12, 0.02, petal, Vector3(0, 0, 1), 0.0)
	# The seed disc: rings of brown and gold with a dark middle, like the spiral of seeds.
	st.disc(head + Vector3(0, 0, 0.05), 0.25, Color(0.4, 0.26, 0.1), 16)
	st.disc(head + Vector3(0, 0, 0.065), 0.19, Color(0.3, 0.18, 0.07), 16)
	st.disc(head + Vector3(0, 0, 0.075), 0.12, Color(0.45, 0.3, 0.1), 14)
	st.disc(head + Vector3(0, 0, 0.085), 0.06, Color(0.22, 0.13, 0.05), 10)
	for j in 24:
		var a := j * 2.39996
		var r := 0.24 * sqrt((j + 1.0) / 24.0)
		st.disc(head + Vector3(cos(a) * r, sin(a) * r, 0.095), 0.022, Color(0.62, 0.45, 0.16), 5)


## The veined leaf texture all plants share: a pale midrib, fine side veins and a little speckle; the vertex
## colour gives the hue.
static var _leaf_tex: ImageTexture


static func _leaf_texture_cached() -> ImageTexture:
	if _leaf_tex == null:
		_leaf_tex = _leaf_texture()
	return _leaf_tex


static func _leaf_texture() -> ImageTexture:
	var img := Image.create(32, 64, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in 64:
		for x in 32:
			var u := (x + 0.5) / 32.0
			var v := (y + 0.5) / 64.0
			var shade := 0.9 + rng.randf() * 0.1
			var mid := absf(u - 0.5)
			if mid < 0.045:
				shade = 1.12
			else:
				# Side veins run outwards and up from the midrib.
				var d := fposmod(v * 9.0 - mid * 3.2, 1.0)
				if d < 0.12:
					shade *= 1.07
				elif d > 0.86:
					shade *= 0.9
			var g := clampf(shade * 0.9, 0.0, 1.0)
			img.set_pixel(x, y, Color(g, g, g * 0.97, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A bag of triangles with vertex colours and texture coordinates.
class _Soup extends RefCounted:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
		var n := (b - a).cross(c - a).normalized()
		var us := [ua, ub, uc]
		var i := 0
		for p in [a, b, c]:
			verts.append(p)
			cols.append(col)
			norms.append(n)
			uvs.append(us[i])
			i += 1

	## A curved leaf or stem from `a` to `b`: it bends by `bend` towards its tip (quadratic), swells in the
	## middle by `belly` (0 for a straight stem), and is built from four segments with one face, the material draws both sides.
	func leaf(a: Vector3, b: Vector3, wa: float, wb: float, col: Color, bend: Vector3, belly: float, side := Vector3.ZERO, segs := 4) -> void:
		var along := (b - a).normalized()
		var across := side
		if across == Vector3.ZERO:
			across = along.cross(Vector3.UP)
			if across.length() < 0.01:
				across = Vector3.RIGHT
			across = across.normalized()
		var n := segs
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for i in n + 1:
			var t := float(i) / n
			var mid := a.lerp(b, t) + bend * t * t
			var w := lerpf(wa, wb, t) * (1.0 + 0.5 * belly * sin(PI * t))
			var l := mid - across * w * 0.5
			var r := mid + across * w * 0.5
			if i > 0:
				var t0 := float(i - 1) / n
				tri(prev_l, prev_r, r, col, Vector2(0, t0), Vector2(1, t0), Vector2(1, t))
				tri(prev_l, r, l, col, Vector2(0, t0), Vector2(1, t), Vector2(0, t))
			prev_l = l
			prev_r = r

	## A short band round a point (a flat ring facing +Z), for the sepals behind a flower head.
	func ring(mid: Vector3, r0: float, r1: float, depth: float, col: Color, sides: int) -> void:
		for j in sides:
			var a0 := TAU * j / sides
			var a1 := TAU * (j + 1) / sides
			var p0 := mid + Vector3(cos(a0), sin(a0), 0) * r0
			var p1 := mid + Vector3(cos(a1), sin(a1), 0) * r0
			var q0 := mid + Vector3(cos(a0), sin(a0), depth) * r1
			var q1 := mid + Vector3(cos(a1), sin(a1), depth) * r1
			tri(p0, p1, q1, col, Vector2(0.5, 0), Vector2(0.5, 0), Vector2(0.5, 1))
			tri(p0, q1, q0, col, Vector2(0.5, 0), Vector2(0.5, 1), Vector2(0.5, 1))

	func disc(mid: Vector3, radius: float, col: Color, sides := 10) -> void:
		for j in sides:
			var a0 := TAU * j / sides
			var a1 := TAU * (j + 1) / sides
			var p0 := mid + Vector3(cos(a0), sin(a0), 0) * radius
			var p1 := mid + Vector3(cos(a1), sin(a1), 0) * radius
			tri(mid, p0, p1, col, Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5))
			tri(mid, p1, p0, col, Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5))

	func finish() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		mat.albedo_texture = CropFields._leaf_texture_cached()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.9
		mesh.surface_set_material(0, mat)
		return mesh
