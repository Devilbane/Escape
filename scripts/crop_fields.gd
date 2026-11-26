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
			"autumn": [0.9, Color(0.62, 0.5, 0.36)], "winter": [0.16, Color(0.72, 0.68, 0.6)]},
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
		if letter == SUNFLOWER:
			(_fields[letter].mm as MultiMesh).mesh = _sunflower_mesh(sunflower_look(season))
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
		# Sunflower heads follow the sun: the plants only turn a little away from south.
		var yaw: float = (float(s[1]) / TAU - 0.5) * 1.4 if letter == SUNFLOWER else s[1]
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(width, grown, width))
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
			return _sunflower_mesh("bloom")
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


## The three looks of a sunflower plant: "bloom" (summer, the head looks at the sun), "droop" (autumn, the neck
## bows and the head hangs, petals wilted) and "young" (spring and winter: stalk and leaves, no head).
static func sunflower_look(season: String) -> String:
	match season:
		"summer":
			return "bloom"
		"autumn":
			return "droop"
	return "young"


static func _sunflower_mesh(look: String) -> ArrayMesh:
	var key := "☼" + look
	if _meshes.has(key):
		return _meshes[key]
	var stalk := _Soup.new()
	var leaf := _Soup.new()
	var petal := _Soup.new()
	var disc := _Soup.new()
	_sunflower(look, stalk, leaf, petal, disc)
	var mesh := ArrayMesh.new()
	stalk.commit(mesh, _sunflower_material(_stalk_texture_cached(), false, 0.85))
	leaf.commit(mesh, _sunflower_material(_sunflower_leaf_texture_cached(), true, 0.8))
	if look != "young":
		petal.commit(mesh, _sunflower_material(_petal_texture_cached(), false, 0.7))
		disc.commit(mesh, _sunflower_material(_disc_texture_cached(), false, 0.95))
	_meshes[key] = mesh
	return mesh


static func _sunflower_material(tex: Texture2D, scissor: bool, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_texture = tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = rough
	if scissor:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
	return mat


static func _sunflower(look: String, stalk: _Soup, leaves: _Soup, petals: _Soup, disc: _Soup) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var h: float = HEIGHT[SUNFLOWER]
	var stem_col := Color(0.5, 0.68, 0.3)
	var drooping := look == "droop"
	# The stem: a thick, hairy tube bowing a little towards the sun; in autumn the top bends over under the head.
	var p0 := Vector3.ZERO
	var p1 := Vector3(0, h * 0.5, 0.0)
	var p2 := Vector3(0, h * 1.02, 0.04)
	var p3 := Vector3(0, h, 0.05)
	if drooping:
		p2 = Vector3(0, h * 1.1, 0.12)
		p3 = Vector3(0, h * 0.86, 0.4)
	elif look == "young":
		p2 = Vector3(0, h * 0.95, 0.02)
		p3 = Vector3(0, h * 0.98, 0.03)
	var pts: Array = []
	var radii: Array = []
	for i in 9:
		var t := i / 8.0
		pts.append(p0.bezier_interpolate(p1, p2, p3, t))
		radii.append(lerpf(0.05, 0.034, t))
	stalk.tube(pts, radii, 7, stem_col)
	# Heart-shaped leaves on short stalks, in a spiral up the stem, big at the bottom and small at the top.
	for j in 7:
		var turn := j * 2.4 + 0.5
		var out := Vector3(cos(turn), 0, sin(turn))
		var tt := 0.14 + 0.085 * j
		var at: Vector3 = p0.bezier_interpolate(p1, p2, p3, tt)
		var l := 0.52 - 0.04 * j
		var w := 0.5 - 0.04 * j
		var shade := rng.randf_range(0.85, 1.05)
		var col := Color(0.5, 0.68, 0.26) * shade
		col.a = 1.0
		var tip := at + out * 0.13 + Vector3(0, 0.07, 0)
		stalk.tube([at, at.lerp(tip, 0.5) + Vector3(0, 0.035, 0), tip], [0.016, 0.013, 0.01], 4, stem_col)
		leaves.blade(tip, out, l, w, 0.06, 0.22 + (0.16 if drooping else 0.0) + 0.02 * j, col)
	if look == "young":
		return
	# The head: a dished seed disc in the middle, two rings of soft petals round it, green bracts behind.
	var normal := Vector3(0, 0.28, 1.0).normalized()
	if drooping:
		normal = Vector3(0, -0.55, 0.85).normalized()
	var centre: Vector3 = p3 + normal * 0.05
	var head := _Head.new(centre, normal)
	var rd := 0.16
	var rim := 0.34
	# Bracts and the green cup behind the disc.
	var cup: Array = []
	var cup_uv: Array = []
	for k in 4:
		var row: Array = []
		var rowuv: Array = []
		var rr := rd * (1.0 - 0.25 * k) * 1.05
		var zz := -0.012 - 0.03 * k
		for q in 17:
			var a := TAU * q / 16.0
			row.append(head.at(Vector3(cos(a) * rr, sin(a) * rr, zz)))
			rowuv.append(Vector2(q / 16.0 * 2.0, k * 0.1))
		cup.append(row)
		cup_uv.append(rowuv)
	stalk.grid(cup, cup_uv, Color(0.5, 0.68, 0.3))
	for q in 16:
		var a := TAU * (q + 0.5) / 16.0 + rng.randf_range(-0.06, 0.06)
		head.petal(stalk, a, rd * 0.78, 0.1, 0.06, -0.02, 0.0, 0.07 if not drooping else 0.12, Color(0.46, 0.64, 0.26), 3, 0.5)
	# Petals: a back ring and a front ring, rounded and a little drooping at the tips.
	var wilt := 0.5 if drooping else 1.0
	var back := 18
	for q in back:
		var a := TAU * q / back + rng.randf_range(-0.05, 0.05)
		var len := rim * 0.66 * wilt * rng.randf_range(0.88, 1.1)
		var shade := rng.randf_range(0.92, 1.02)
		head.petal(petals, a, rd * 0.92, len, 0.105, -0.012, 0.02, 0.1 + (0.02 if drooping else 0.0), Color(shade, shade * 0.95, shade * 0.9), 6, 1.0)
	for q in back:
		var a := TAU * (q + 0.5) / back + rng.randf_range(-0.05, 0.05)
		var len := rim * 0.62 * wilt * rng.randf_range(0.85, 1.1)
		var shade := rng.randf_range(1.02, 1.15)
		head.petal(petals, a, rd * 0.96, len, 0.1, 0.006, 0.03, 0.13 + (0.02 if drooping else 0.0), Color(shade, shade, shade), 6, 1.0)
	# The seed disc: a shallow dome. The texture carries the spiral of seeds, an olive middle and an orange ring.
	var rows: Array = []
	var uvs: Array = []
	var ring_r := [0.0, 0.03, 0.065, 0.1, 0.13, rd]
	for k in ring_r.size():
		var row: Array = []
		var rowuv: Array = []
		var rr: float = ring_r[k]
		var zz := 0.03 * (1.0 - pow(rr / rd, 2.0)) - 0.006 * (1.0 - rr / rd)
		for q in 21:
			var a := TAU * q / 20.0
			var x := cos(a) * rr
			var y := sin(a) * rr
			row.append(head.at(Vector3(x, y, zz)))
			rowuv.append(Vector2(0.5 + x / rd * 0.5, 0.5 - y / rd * 0.5))
		rows.append(row)
		uvs.append(rowuv)
	disc.grid(rows, uvs, Color.WHITE)


## A frame for the head of a flower: `at()` turns a point in head space (x right, y up, z out of the face) into plant space.
class _Head extends RefCounted:
	var centre: Vector3
	var out: Vector3
	var right := Vector3.RIGHT
	var up: Vector3

	func _init(c: Vector3, normal: Vector3) -> void:
		centre = c
		out = normal
		up = normal.cross(right).normalized()

	func at(p: Vector3) -> Vector3:
		return centre + right * p.x + up * p.y + out * p.z

	## A petal growing outwards at angle `a` from radius `r0`: a short strip of `rows` steps, widest near the base and
	## narrowing to a rounded tip, lifting off the face by `lift` and bowing back by `droop` towards the tip.
	func petal(st: _Soup, a: float, r0: float, length: float, width: float, z0: float, lift: float, droop: float, col: Color, rows: int, sharp: float) -> void:
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var grid: Array = []
		var uvs: Array = []
		for i in rows + 1:
			var s := float(i) / rows
			var w := width * pow(sin(PI * pow(s, 0.7) * 0.97), 0.6 * sharp) if s > 0.0 else width * 0.12
			var r := r0 + length * s
			var z := z0 + lift * s - droop * s * s
			var row: Array = []
			var rowuv: Array = []
			for c in 3:
				var u := c - 1.0
				var xy := dir * r + side * u * w * 0.5
				var zz := z + (0.012 * (1.0 - absf(u))) - 0.02 * u * u * width * 4.0 * s
				row.append(at(Vector3(xy.x, xy.y, zz)))
				rowuv.append(Vector2(0.5 + 0.5 * u, s))
			grid.append(row)
			uvs.append(rowuv)
		st.grid(grid, uvs, col)


static var _stalk_tex: ImageTexture
static var _sunflower_leaf_tex: ImageTexture
static var _petal_tex: ImageTexture
static var _disc_tex: ImageTexture


static func _stalk_texture_cached() -> ImageTexture:
	if _stalk_tex == null:
		_stalk_tex = _stalk_texture()
	return _stalk_tex


static func _sunflower_leaf_texture_cached() -> ImageTexture:
	if _sunflower_leaf_tex == null:
		_sunflower_leaf_tex = _sunflower_leaf_texture()
	return _sunflower_leaf_tex


static func _petal_texture_cached() -> ImageTexture:
	if _petal_tex == null:
		_petal_tex = _petal_texture()
	return _petal_tex


static func _disc_texture_cached() -> ImageTexture:
	if _disc_tex == null:
		_disc_tex = _disc_texture()
	return _disc_tex


## The hairy stalk: long fine streaks and a dusting of short pale bristles (tiles along the stem).
static func _stalk_texture() -> ImageTexture:
	var w := 32
	var hgt := 128
	var img := Image.create(w, hgt, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var streak: Array = []
	for x in w:
		streak.append(rng.randf_range(0.78, 1.0))
	for y in hgt:
		for x in w:
			var g: float = streak[x] * (0.9 + 0.1 * sin(y * 0.19 + x * 0.7))
			img.set_pixel(x, y, Color(g * 0.9, g * 0.95, g * 0.8, 1.0))
	# Bristles: short bright dashes, mostly upright and a little slanted.
	for i in 150:
		var bx := rng.randi_range(0, w - 1)
		var by := rng.randi_range(0, hgt - 1)
		var n := rng.randi_range(2, 5)
		var slant := rng.randf_range(-0.4, 0.4)
		for k in n:
			var px := posmod(int(round(bx + slant * k)), w)
			var py := posmod(by + k, hgt)
			img.set_pixel(px, py, Color(1.0, 1.0, 0.92, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A heart-shaped, saw-toothed leaf blade seen from above (base at v = 0, tip at v = 1): the outline is the alpha
## channel, with a pale midrib and curved side veins in the colour.
static func _sunflower_leaf_texture() -> ImageTexture:
	var w := 64
	var hgt := 128
	var img := Image.create(w, hgt, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for y in hgt:
		var v := (y + 0.5) / hgt
		for x in w:
			var u := (x + 0.5) / w - 0.5
			var au := absf(u)
			# Half-width of the blade at this height: round lobes at the base, then a long taper to a point.
			var half := 0.0
			if v < 0.24:
				half = 0.5 * sqrt(maxf(0.0, 1.0 - pow((0.24 - v) / 0.24, 2.0)))
			else:
				half = 0.5 * pow(maxf(0.0, 1.0 - (v - 0.24) / 0.76), 0.85)
			# The notch where the stalk joins, and the saw teeth along the edge.
			var tooth := fposmod(v * 16.0 + au * 5.0, 1.0)
			half *= 0.95 + 0.06 * tooth
			var notch := v < 0.12 and au < 0.07 * (1.0 - v / 0.12)
			var inside := au < half and not notch
			var g := 0.0
			if inside:
				var edge := clampf((half - au) / 0.05, 0.0, 1.0)
				g = 0.84 + rng.randf() * 0.1
				g *= 0.8 + 0.2 * edge
				# Midrib and side veins sweeping out and towards the tip.
				if au < 0.022:
					g = 1.15
				else:
					var d := fposmod(v * 8.0 - au * 5.5, 1.0)
					if d < 0.09:
						g *= 1.14
					elif d > 0.88:
						g *= 0.9
			var c := clampf(g, 0.0, 1.0)
			img.set_pixel(x, y, Color(c, c, c * 0.96, 1.0 if inside else 0.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A ray petal (base at v = 0, tip at v = 1): warm orange at the root, golden in the middle, with fine grooves along it.
static func _petal_texture() -> ImageTexture:
	var w := 32
	var hgt := 64
	var img := Image.create(w, hgt, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	for y in hgt:
		var v := (y + 0.5) / hgt
		var base := Color(0.96, 0.58, 0.04).lerp(Color(1.0, 0.8, 0.1), clampf(v * 2.2, 0.0, 1.0))
		base = base.lerp(Color(1.0, 0.86, 0.22), clampf((v - 0.7) * 2.0, 0.0, 1.0) * 0.6)
		for x in w:
			var u := (x + 0.5) / w
			var groove := 0.5 + 0.5 * cos(u * TAU * 4.0)
			var shade := 0.88 + 0.1 * groove + rng.randf() * 0.04
			if absf(u - 0.5) < 0.04:
				shade *= 0.93
			img.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The seed disc seen from the front: florets in a Fibonacci spiral, an olive middle fading to orange-brown rim.
static func _disc_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.06, 0.02, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var count := 760
	var reach := size * 0.5 - 3.0
	var scale_r := reach / sqrt(float(count))
	var golden := PI * (3.0 - sqrt(5.0))
	for n in count:
		var r := scale_r * sqrt(n + 0.5)
		var a := n * golden
		var cx := size * 0.5 + cos(a) * r
		var cy := size * 0.5 + sin(a) * r
		var rr := r / reach
		var col: Color
		if rr < 0.4:
			col = Color(0.26, 0.27, 0.07).lerp(Color(0.42, 0.36, 0.08), rr / 0.4)
		elif rr < 0.52:
			col = Color(0.42, 0.36, 0.08).lerp(Color(0.8, 0.42, 0.07), (rr - 0.4) / 0.12)
		else:
			col = Color(0.8, 0.42, 0.07).lerp(Color(0.6, 0.28, 0.05), (rr - 0.52) / 0.48)
		col = col * rng.randf_range(0.85, 1.12)
		var fr := 1.5 + 2.2 * rr
		var x0 := int(floor(cx - fr - 1))
		var x1 := int(ceil(cx + fr + 1))
		var y0 := int(floor(cy - fr - 1))
		var y1 := int(ceil(cy + fr + 1))
		for py in range(maxi(y0, 0), mini(y1, size - 1) + 1):
			for px in range(maxi(x0, 0), mini(x1, size - 1) + 1):
				var d := Vector2(px + 0.5 - cx, py + 0.5 - cy).length()
				if d <= fr:
					# Each floret is a little cone: lit on one side, so the spiral reads even in a few pixels.
					var lit := 1.12 - 0.3 * d / fr + 0.1 * ((px + 0.5 - cx) + (py + 0.5 - cy)) / fr * -0.5
					img.set_pixel(px, py, Color(col.r * lit, col.g * lit, col.b * lit, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


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

	## Appends this soup as one surface of `mesh` with material `mat`.
	func commit(mesh: ArrayMesh, mat: Material) -> void:
		if verts.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)

	## A smooth sheet through a grid of points (`rows` of `cols` points each) with matching texture coordinates;
	## the normals are averaged from the neighbouring points, or given.
	func grid(rows: Array, tex: Array, col: Color, normals: Array = []) -> void:
		var nr := rows.size()
		var nc: int = rows[0].size()
		var nrm: Array = []
		for i in nr:
			var line: Array = []
			for j in nc:
				if not normals.is_empty():
					line.append(normals[i][j])
					continue
				var i0 := maxi(i - 1, 0)
				var i1 := mini(i + 1, nr - 1)
				var j0 := maxi(j - 1, 0)
				var j1 := mini(j + 1, nc - 1)
				var n: Vector3 = (rows[i1][j] - rows[i0][j]).cross(rows[i][j1] - rows[i][j0])
				line.append(n.normalized() if n.length() > 0.00001 else Vector3.UP)
			nrm.append(line)
		for i in nr - 1:
			for j in nc - 1:
				for t in 2:
					var idx := [[i, j], [i + 1, j], [i + 1, j + 1]] if t == 0 else [[i, j], [i + 1, j + 1], [i, j + 1]]
					for k in idx:
						verts.append(rows[k[0]][k[1]])
						norms.append(nrm[k[0]][k[1]])
						uvs.append(tex[k[0]][k[1]])
						cols.append(col)

	## A round tube along `points` with a radius for each, `sides` faces and smooth normals; the texture repeats along it.
	func tube(points: Array, radii: Array, sides: int, col: Color) -> void:
		var rows: Array = []
		var tex: Array = []
		var nrm: Array = []
		var run := 0.0
		for i in points.size():
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, points.size() - 1)
			var t: Vector3 = (points[i1] - points[i0]).normalized()
			var n := t.cross(Vector3.RIGHT)
			if n.length() < 0.1:
				n = t.cross(Vector3.FORWARD)
			n = n.normalized()
			var b := t.cross(n).normalized()
			if i > 0:
				run += (points[i] - points[i - 1]).length()
			var row: Array = []
			var rowuv: Array = []
			var rown: Array = []
			for j in sides + 1:
				var a := TAU * j / sides
				var radial := n * cos(a) + b * sin(a)
				row.append(points[i] + radial * radii[i])
				rowuv.append(Vector2(float(j) / sides, run * 2.5))
				rown.append(radial)
			rows.append(row)
			tex.append(rowuv)
			nrm.append(rown)
		grid(rows, tex, col, nrm)

	## A broad leaf blade from `base`, growing outwards along the horizontal direction `out`: `length` long, `width` wide,
	## rising by `rise` and sagging by `droop` towards the tip, edges curling down a little. The texture gives its outline.
	func blade(base: Vector3, out: Vector3, length: float, width: float, rise: float, droop: float, col: Color) -> void:
		var side := out.cross(Vector3.UP).normalized()
		var rows: Array = []
		var tex: Array = []
		for i in 6:
			var s := i / 5.0
			var row: Array = []
			var rowuv: Array = []
			for c in 5:
				var u := c / 2.0 - 1.0
				var p := base + out * length * s + Vector3.UP * (rise * s - droop * s * s)
				p += side * u * width * 0.5
				p.y -= 0.05 * width * u * u * (0.4 + s) - 0.012 * (1.0 - absf(u))
				row.append(p)
				rowuv.append(Vector2(0.5 + 0.5 * u, s))
			rows.append(row)
			tex.append(rowuv)
		grid(rows, tex, col)

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
