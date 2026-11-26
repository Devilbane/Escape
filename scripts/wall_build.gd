class_name WallBuild
extends RefCounted
## Builds the 3D wall of a WallMap: the rock face with its holds, the cracks of its gaps, and the surfaces on
## it. Built from the map alone, the same every time.
##
## The wall stands in the plane of x (right) and y (up), the climber's side towards +z, one square a metre,
## the foot at y = 0 and the left edge at x = 0 (square (c, r) is at x = c + 0.5, y = height - r - 0.5).
## - ROCK: one smooth height field (RES points per metre) in the weathered mountain rock's material
##   (AgedStone.rock_material: grain, strata, grime, lichen), shaken by low and fine noise. A hold is a knob
##   that stands out of the face, the smaller the higher its malus (a hard hold is a small one), pale with
##   chalk. A gap is a ragged crack sunk into the face, black in its depth, with "N m²" written in it.
## - ICE: a glassy skin (wall_ice.gdshader) over the squares with ice, ragged at its edge.
## - LOOSE: a scatter of real boulders (NaturalRock) stuck to the face on loose-stone squares.
## - WET: dark green moss painted into the rock's colours.
## There is no plain-coloured part: every surface wears the shaders' grain.

## Height field points per metre and the slab behind the face.
const RES := 4
const BACK := -1.6
const GAP_DEPTH := 1.35
## Knob height and radius of a hold of malus 0 (the radius shrinks with every malus point).
const KNOB_HEIGHT := 0.3
const KNOB_RADIUS := 0.5
const KNOB_SHRINK := 0.035
const ICE_LIFT := 0.035
const STONES_PER_SQUARE := 5
## Share of the plain squares that carry a decorative stone jutting out of the face (they are no holds).
const DECOR_SHARE := 0.2

const ROCK := Color(0.47, 0.45, 0.43)
const ROCK_DARK := Color(0.3, 0.29, 0.29)
const CHALK := Color(0.76, 0.74, 0.7)
const MOSS := Color(0.2, 0.3, 0.14)
const ICE_SHADER := preload("res://shaders/wall_ice.gdshader")

var map: WallMap
var _noise := FastNoiseLite.new()
var _fine := FastNoiseLite.new()


## The whole wall as a node (Rock, Back, Ice, Stones and a label for every gap).
static func node(wall: WallMap) -> Node3D:
	var b := WallBuild.new(wall)
	var root := Node3D.new()
	root.name = "Wall"
	var rock := MeshInstance3D.new()
	rock.name = "Rock"
	rock.mesh = b.rock_mesh()
	rock.material_override = AgedStone.rock_material()
	root.add_child(rock)
	var back := MeshInstance3D.new()
	back.name = "Back"
	back.mesh = b._back_mesh()
	back.material_override = AgedStone.rock_material()
	root.add_child(back)
	var ice := b.ice_mesh()
	if ice != null:
		var mi := MeshInstance3D.new()
		mi.name = "Ice"
		mi.mesh = ice
		var mat := ShaderMaterial.new()
		mat.shader = ICE_SHADER
		mi.material_override = mat
		root.add_child(mi)
	var stones := b.stones_mesh()
	if stones != null:
		var st := MeshInstance3D.new()
		st.name = "Stones"
		st.mesh = stones
		st.material_override = AgedStone.rock_material()
		root.add_child(st)
	var decor := b.decor_mesh()
	if decor != null:
		var dm := MeshInstance3D.new()
		dm.name = "Decor"
		dm.mesh = decor
		dm.material_override = AgedStone.rock_material()
		root.add_child(dm)
	for i in wall.gaps.size():
		root.add_child(b._gap_label(i))
	return root


func _init(wall: WallMap) -> void:
	map = wall
	_noise.seed = 41
	_noise.frequency = 1.0
	_noise.fractal_octaves = 2
	_fine.seed = 97
	_fine.frequency = 1.0


## Where the centre of square (c, r) is on the wall's plane (x, y), in metres.
static func square_centre(wall: WallMap, c: int, r: int) -> Vector2:
	return Vector2((c + 0.5) * WallMap.SQUARE, (wall.height - r - 0.5) * WallMap.SQUARE)


## How far the face stands out (positive) or is sunk (negative) at a point of the wall's plane.
func depth_at(x: float, y: float) -> float:
	return _field(x, y).depth


## The face's depth at a point, with the paint of the rock there: {"depth", "colour", "trench", "knob"}.
func _field(x: float, y: float) -> Dictionary:
	var d := _noise.get_noise_2d(x * 0.55, y * 0.55) * 0.14 + _fine.get_noise_2d(x * 2.9, y * 2.9) * 0.035
	var tone := 0.5 + _fine.get_noise_2d(x * 1.3 + 40.0, y * 1.3) * 0.6
	var col := ROCK_DARK.lerp(ROCK, clampf(tone, 0.0, 1.0))
	var c0 := int(floor(x))
	var r0 := map.height - 1 - int(floor(y))
	var knob := 0.0
	var wet := 0.0
	var loose := 0.0
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var c := c0 + dc
			var r := r0 + dr
			if not map.inside(c, r):
				continue
			if map.has_hold(c, r):
				var centre := square_centre(map, c, r) + _jitter(c, r) * 0.1
				var radius := maxf(0.2, KNOB_RADIUS - KNOB_SHRINK * map.malus_at(c, r))
				var dist := Vector2(x, y).distance_to(centre)
				if dist < radius:
					var k := 0.5 + 0.5 * cos(PI * dist / radius)
					knob = maxf(knob, k)
					d += KNOB_HEIGHT * k * (0.85 + 0.3 * _hash(c, r))
			match map.hazard_at(c, r):
				WallMap.WET:
					wet = maxf(wet, 1.0 - smoothstep(0.0, 0.7, _edge_distance(x, y, c, r)))
				WallMap.LOOSE:
					loose = maxf(loose, 1.0 - smoothstep(0.0, 0.5, _edge_distance(x, y, c, r)))
	var trench := 0.0
	for g in map.gaps:
		var x0 := float(g.position.x)
		var x1 := float(g.end.x)
		var y0 := float(map.height - g.end.y)
		var y1 := float(map.height - g.position.y)
		var sd := _box_distance(x, y, x0, x1, y0, y1)
		var jag := _noise.get_noise_2d(x * 2.1 + 9.0, y * 2.1) * 0.34 + _fine.get_noise_2d(x * 6.0, y * 6.0 + 5.0) * 0.12
		var inside := -(sd + jag)
		trench = maxf(trench, smoothstep(0.0, 0.3, inside))
	d -= trench * GAP_DEPTH
	col = col.lerp(CHALK, knob * 0.7 * (0.6 + 0.8 * _hash(c0, r0)))
	col = col.lerp(MOSS.lerp(ROCK_DARK, 0.3), wet * (0.5 + 0.4 * _fine.get_noise_2d(x * 5.0, y * 5.0)))
	col = col.lerp(Color(0.6, 0.54, 0.47), loose * 0.35)
	col = col.lerp(Color(0.03, 0.03, 0.035), trench * 0.92)
	return {"depth": d, "colour": col, "trench": trench, "knob": knob}


## Signed distance of a point to a box (negative inside).
static func _box_distance(x: float, y: float, x0: float, x1: float, y0: float, y1: float) -> float:
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var qx := absf(x - cx) - (x1 - x0) * 0.5
	var qy := absf(y - cy) - (y1 - y0) * 0.5
	return Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0)


## How far (metres) a point is inside the square (c, r); 0 on its border.
func _edge_distance(x: float, y: float, c: int, r: int) -> float:
	var centre := square_centre(map, c, r)
	var q := Vector2(absf(x - centre.x), absf(y - centre.y))
	return maxf(0.0, 0.5 * WallMap.SQUARE - maxf(q.x, q.y))


static func _hash(c: int, r: int) -> float:
	return fposmod(sin(float(c) * 12.9898 + float(r) * 78.233) * 43758.5453, 1.0)


static func _jitter(c: int, r: int) -> Vector2:
	return Vector2(_hash(c, r) - 0.5, _hash(r + 7, c + 3) - 0.5)


## The face as one mesh.
func rock_mesh() -> ArrayMesh:
	var nx := map.width * RES
	var ny := map.height * RES
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for j in ny + 1:
		for i in nx + 1:
			var x := float(i) / RES
			var y := float(j) / RES
			var f := _field(x, y)
			verts.append(Vector3(x, y, f.depth))
			var colour: Color = f.colour
			cols.append(Color(colour.r, colour.g, colour.b, 1.0))
			uvs.append(Vector2(x, y))
	var idx := PackedInt32Array()
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			idx.append_array([a, a + 1, a + nx + 2, a, a + nx + 2, a + nx + 1])
	return _smooth_mesh(verts, cols, uvs, idx)


static func _smooth_mesh(verts: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for t in range(0, idx.size(), 3):
		var n := (verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]])
		for k in 3:
			normals[idx[t + k]] += n
	for i in normals.size():
		normals[i] = normals[i].normalized() if normals[i].length() > 0.0 else Vector3.BACK
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The slab behind the face (the dark bottom of the cracks) and the wall's sides.
func _back_mesh() -> ArrayMesh:
	var w := float(map.width)
	var h := float(map.height)
	var verts := PackedVector3Array([
		Vector3(0, 0, BACK), Vector3(w, 0, BACK), Vector3(w, h, BACK), Vector3(0, h, BACK),
		Vector3(0, 0, 0), Vector3(w, 0, 0), Vector3(w, h, 0), Vector3(0, h, 0)])
	var cols := PackedColorArray()
	for i in 8:
		cols.append(Color(ROCK_DARK.r * 0.6, ROCK_DARK.g * 0.6, ROCK_DARK.b * 0.6, 1.0))
	var uvs := PackedVector2Array()
	for v in verts:
		uvs.append(Vector2(v.x, v.y))
	var idx := PackedInt32Array([0, 2, 1, 0, 3, 2, 0, 4, 7, 0, 7, 3, 1, 6, 5, 1, 2, 6, 3, 7, 6, 3, 6, 2, 0, 1, 5, 0, 5, 4])
	return _smooth_mesh(verts, cols, uvs, idx)


## The ice as a skin over the face, or null with no ice. The vertex alpha is the thickness.
func ice_mesh() -> ArrayMesh:
	var any := false
	for r in map.height:
		for c in map.width:
			if map.hazard_at(c, r) == WallMap.ICE:
				any = true
	if not any:
		return null
	var nx := map.width * RES
	var ny := map.height * RES
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var cover := PackedFloat32Array()
	for j in ny + 1:
		for i in nx + 1:
			var x := float(i) / RES
			var y := float(j) / RES
			var cv := _ice_cover(x, y)
			cover.append(cv)
			verts.append(Vector3(x, y, depth_at(x, y) + ICE_LIFT + 0.03 * cv))
			cols.append(Color(1, 1, 1, cv))
	var idx := PackedInt32Array()
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			if cover[a] + cover[a + 1] + cover[a + nx + 1] + cover[a + nx + 2] < 0.04:
				continue
			idx.append_array([a, a + 1, a + nx + 2, a, a + nx + 2, a + nx + 1])
	if idx.is_empty():
		return null
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	return _smooth_mesh(verts, cols, uvs, idx)


## How thick the ice lies at a point (0..1): full inside a patch of ice squares, thinning to its ragged edge.
func _ice_cover(x: float, y: float) -> float:
	var c := int(floor(x))
	var r := map.height - 1 - int(floor(y))
	var wobble := _noise.get_noise_2d(x * 3.3 + 70.0, y * 3.3) * 0.22 + _fine.get_noise_2d(x * 8.0, y * 8.0) * 0.08
	var best := 0.0
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if not map.inside(c + dc, r + dr) or map.hazard_at(c + dc, r + dr) != WallMap.ICE:
				continue
			var centre := square_centre(map, c + dc, r + dr)
			var q := Vector2(absf(x - centre.x), absf(y - centre.y))
			var inside := 0.5 - maxf(q.x, q.y) + wobble
			best = maxf(best, smoothstep(-0.05, 0.28, inside))
	return best


## Loose boulders stuck to the face on the loose-stone squares (one mesh), or null.
func stones_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	var count := 0
	var kinds := ["rock_single_A", "rock_single_C", "rock_single_E"]
	for r in map.height:
		for c in map.width:
			if map.hazard_at(c, r) != WallMap.LOOSE:
				continue
			for k in STONES_PER_SQUARE:
				var h1 := _hash(c * 13 + k, r * 7 + k * 3)
				var h2 := _hash(c * 5 + k * 11, r * 17 + k)
				var h3 := _hash(c * 3 + k * 5, r * 19 + k * 7)
				var centre := square_centre(map, c, r)
				var x := centre.x + (h1 - 0.5) * 0.85
				var y := centre.y + (h2 - 0.5) * 0.85
				var mesh: ArrayMesh = NaturalRock.mesh(kinds[(c + r + k) % 3])
				var factor := 1.6 + 1.8 * h3
				var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0 + (h1 - 0.5) * 50.0)) * Basis(Vector3.UP, h3 * TAU)
				var xf := Transform3D(basis.scaled(Vector3.ONE * factor), Vector3(x, y, depth_at(x, y) - 0.02))
				st.append_from(mesh, 0, xf)
				count += 1
	if count == 0:
		return null
	return st.commit()


## Decorative stones that jut out of the face here and there, only on plain squares (no hold, no gap, no loose
## stones), varied in kind, size and lean. They make the mountain look rocky and are not part of the climb.
func decor_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	var count := 0
	var kinds := ["rock_single_A", "rock_single_C", "rock_single_E"]
	for r in map.height:
		for c in map.width:
			if map.has_hold(c, r) or map.gap_at(c, r) >= 0 or map.hazard_at(c, r) == WallMap.LOOSE:
				continue
			if _hash(c * 29 + 3, r * 31 + 7) > DECOR_SHARE:
				continue
			var h1 := _hash(c * 7 + 1, r * 5 + 2)
			var h2 := _hash(c * 11 + 5, r * 3 + 9)
			var h3 := _hash(c * 17 + 2, r * 13 + 4)
			var centre := square_centre(map, c, r)
			var x := centre.x + (h1 - 0.5) * 0.7
			var y := centre.y + (h2 - 0.5) * 0.7
			var mesh: ArrayMesh = NaturalRock.mesh(kinds[int(h3 * 3.0) % 3])
			if mesh == null:
				continue
			var factor := 0.9 + 1.3 * h1
			var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0 + (h2 - 0.5) * 70.0)) * Basis(Vector3.UP, h3 * TAU)
			st.append_from(mesh, 0, Transform3D(basis.scaled(Vector3.ONE * factor), Vector3(x, y, depth_at(x, y) - 0.03)))
			count += 1
	if count == 0:
		return null
	return st.commit()


## The gap's label: its area in square metres, written in the crack.
func _gap_label(index: int) -> Label3D:
	var g := map.gaps[index]
	var label := Label3D.new()
	label.name = "Gap%d" % index
	label.text = "%d m²" % int(round(map.gap_area(index)))
	label.font_size = 96
	label.pixel_size = 0.005
	label.outline_size = 24
	label.modulate = Color(0.95, 0.88, 0.7)
	label.outline_modulate = Color(0.02, 0.02, 0.03)
	label.shaded = false
	var mid := Vector2((g.position.x + g.end.x) * 0.5, map.height - (g.position.y + g.end.y) * 0.5)
	label.position = Vector3(mid.x, mid.y, 0.35)
	return label
