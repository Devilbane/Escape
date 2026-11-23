class_name CropFields
extends Node3D
## The fields of the farming valley: wheat ("≡"), maize ("‡") and sunflowers ("☼"), each tile a patch of
## dark soil with its crop standing in rows (see Outdoor). The plants of a kind are one MultiMesh, so a
## whole field is a single draw call. They follow the seasons (see Weather.season):
##   spring  green shoots, ankle high;
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
## Plants in a row and between rows (metres): a tile is 4 m, so 8 x 8 tufts of wheat, 4 x 4 maize and sunflowers.
const SPACING := {"≡": 0.5, "‡": 1.0, "☼": 1.0}
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

var _fields := {}
var _season := ""
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
		for mid: Vector3 in cells[letter]:
			var n := int(round(tile / step))
			for ix in n:
				for iz in n:
					var at := mid + Vector3((ix + 0.5) * step - tile * 0.5, 0, (iz + 0.5) * step - tile * 0.5)
					at += Vector3(rng.randf_range(-0.12, 0.12) * step, 0, rng.randf_range(-0.12, 0.12) * step)
					spots.append([at, rng.randf() * TAU, rng.randf_range(0.85, 1.15), rng.randf()])
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
	return out


## Dresses every field for season day `day` (see Weather.season).
func set_season(day: int) -> void:
	var season := Weather.season(day)
	if season == _season:
		return
	_season = season
	for letter: String in _fields:
		var look: Array = LOOK[letter][season]
		var mm: MultiMesh = _fields[letter].mm
		var spots: Array = _fields[letter].spots
		for i in spots.size():
			var s: Array = spots[i]
			var grown: float = look[0] * s[2]
			var basis := Basis(Vector3.UP, s[1]).scaled(Vector3(1.0, grown, 1.0))
			mm.set_instance_transform(i, Transform3D(basis, s[0]))
			var tint: Color = look[1]
			var shade := 0.88 + 0.24 * float(s[3])
			mm.set_instance_color(i, Color(tint.r * shade, tint.g * shade, tint.b * shade))


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
	# Nine stalks in a loose bunch, each with an ear.
	for i in 9:
		var base := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		var lean := Vector3(rng.randf_range(-0.07, 0.07), 0, rng.randf_range(-0.07, 0.07))
		var h := HEIGHT[WHEAT] * rng.randf_range(0.85, 1.0)
		st.blade(base, base + lean + Vector3(0, h * 0.8, 0), 0.016, 0.008, stalk)
		st.blade(base + lean + Vector3(0, h * 0.8, 0), base + lean * 1.5 + Vector3(0, h, 0), 0.03, 0.004, ear)


static func _maize(st: _Soup) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var green := Color(0.5, 0.64, 0.24)
	var leaf := Color(0.42, 0.6, 0.2)
	var cob := Color(0.95, 0.78, 0.25)
	for k in 2:
		var base := Vector3(-0.2 + k * 0.4, 0, rng.randf_range(-0.15, 0.15))
		var h: float = HEIGHT[MAIZE] * rng.randf_range(0.9, 1.0)
		st.blade(base, base + Vector3(0, h, 0), 0.05, 0.02, green)
		# Long arching leaves.
		for j in 6:
			var turn := TAU * (j / 6.0) + k
			var out := Vector3(cos(turn), 0, sin(turn))
			var y := h * (0.28 + 0.1 * j)
			st.blade(base + Vector3(0, y, 0), base + out * 0.55 + Vector3(0, y + 0.1, 0), 0.07, 0.005, leaf)
		# A cob in its husk, and the tassel at the top.
		st.blade(base + Vector3(0.05, h * 0.55, 0), base + Vector3(0.13, h * 0.68, 0.04), 0.05, 0.03, cob)
		st.blade(base + Vector3(0, h, 0), base + Vector3(0.05, h + 0.22, 0), 0.02, 0.004, Color(0.86, 0.8, 0.46))


static func _sunflower(st: _Soup) -> void:
	var stalk := Color(0.38, 0.5, 0.2)
	var h: float = HEIGHT[SUNFLOWER]
	st.blade(Vector3.ZERO, Vector3(0, h, 0), 0.045, 0.03, stalk)
	st.blade(Vector3(0, h * 0.35, 0), Vector3(0.4, h * 0.38, 0.1), 0.09, 0.005, stalk)
	st.blade(Vector3(0, h * 0.5, 0), Vector3(-0.4, h * 0.52, -0.1), 0.09, 0.005, stalk)
	# The head looks south, toward the camera: a ring of petals round a dark disc.
	var head := Vector3(0, h, 0.04)
	var petal := Color(1.0, 0.8, 0.12)
	for j in 14:
		var a := TAU * j / 14.0
		var out := Vector3(cos(a), sin(a), 0.0)
		st.blade(head + out * 0.14, head + out * 0.5, 0.11, 0.015, petal, Vector3(0, 0, 1))
	st.disc(head + Vector3(0, 0, 0.03), 0.24, Color(0.32, 0.19, 0.08))


## A bag of triangles with vertex colours.
class _Soup extends RefCounted:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		var n := (b - a).cross(c - a).normalized()
		for p in [a, b, c]:
			verts.append(p)
			cols.append(col)
			norms.append(n)

	## A tapered, flat blade from `a` to `b`, `wa` wide at the start and `wb` at the end, its width along
	## `side` (a horizontal direction across it, turned to face away from the way it points by default).
	func blade(a: Vector3, b: Vector3, wa: float, wb: float, col: Color, side := Vector3.ZERO) -> void:
		var along := (b - a).normalized()
		var across := side
		if across == Vector3.ZERO:
			across = along.cross(Vector3.UP)
			if across.length() < 0.01:
				across = Vector3.RIGHT
			across = across.normalized()
		var l := a - across * wa * 0.5
		var r := a + across * wa * 0.5
		var tl := b - across * wb * 0.5
		var tr := b + across * wb * 0.5
		# Both faces, so no plant disappears seen from behind.
		tri(l, r, tr, col)
		tri(l, tr, tl, col)
		tri(l, tr, r, col)
		tri(l, tl, tr, col)
		# A second blade across the first gives the stalk some body.
		if side == Vector3.ZERO:
			var across2 := across.cross(along).normalized()
			var l2 := a - across2 * wa * 0.5
			var r2 := a + across2 * wa * 0.5
			var tl2 := b - across2 * wb * 0.5
			var tr2 := b + across2 * wb * 0.5
			tri(l2, r2, tr2, col)
			tri(l2, tr2, tl2, col)
			tri(l2, tr2, r2, col)
			tri(l2, tl2, tr2, col)

	func disc(mid: Vector3, radius: float, col: Color) -> void:
		for j in 10:
			var a0 := TAU * j / 10.0
			var a1 := TAU * (j + 1) / 10.0
			var p0 := mid + Vector3(cos(a0), sin(a0), 0) * radius
			var p1 := mid + Vector3(cos(a1), sin(a1), 0) * radius
			tri(mid, p0, p1, col)
			tri(mid, p1, p0, col)

	func finish() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_NORMAL] = norms
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.9
		mesh.surface_set_material(0, mat)
		return mesh
