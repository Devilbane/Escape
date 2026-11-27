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
## How far (metres) the crack of a gap runs on below it.
const GAP_RUN := 5.5
## How much narrower (share of the half width) the bottom of a gap is than its top.
const GAP_WEDGE := 0.4
## Knob height and radius of a hold of malus 0 (the radius shrinks with every malus point).
const KNOB_HEIGHT := 0.3
const KNOB_RADIUS := 0.5
const KNOB_SHRINK := 0.035
## The smallest hold (malus 9) is this wide and this high; the biggest (malus 0) is KNOB_RADIUS wide and KNOB_HEIGHT high.
## Share of the holds that flip from what their patch of the face would make them.
const POCKET_FLIP := 0.1
## A pocket keeps this far from every foot stone (a hold there is a stone), a decorative stone this far from a pocket,
## and foot stones this close side by side are joined by one rib.
const FOOT_CLEAR := Vector2(1.1, 0.7)
const DECOR_CLEAR := 1.0
const LEDGE_REACH := 1.8
## Foot stones this close on different levels get connecting stones (see filler_mesh).
const FILLER_REACH := 1.9
## Colour of the set-in stones: darkened by this and greyed towards the dark rock by STONE_WEATHER.
const STONE_SHADE := 0.86
const STONE_WEATHER := 0.2
## How much chalk dust the set-in stones wear on top, and the colour of their ice where the face is wet.
const STONE_CHALK := 0.55
const ICE_TINT := Color(0.72, 0.86, 0.98)
const KNOB_MIN_RADIUS := 0.22
const KNOB_HEIGHT_HARD := 0.11
## Share of chalk on the easiest and on the hardest hold (an easy jug is well chalked, a crimp hardly).
const CHALK_EASY := 0.85
const CHALK_HARD := 0.3
const ICE_LIFT := 0.035
const STONES_PER_SQUARE := 5
## Share of the plain squares that carry a decorative stone jutting out of the face (they are no holds).
const DECOR_SHARE := 0.2
## A climber hangs with the feet this far below the hand hold; the foot stone he stands on is made there.
const FOOT_DROP := 1.7
## A foot stone is made only where the feet are clear of the ground (on the ground he simply stands).
const FOOT_MIN_Y := 0.2
## How many squares wide the ledge of a rest place is (see camp_mesh).
const CAMP_LEDGE_WIDTH := 3.0
const FOOT_KINDS := ["rock_single_E", "rock_single_C", "rock_single_A"]

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
	var feet := b.foot_mesh()
	if feet != null:
		var fm := MeshInstance3D.new()
		fm.name = "FootStones"
		fm.mesh = feet
		fm.material_override = AgedStone.rock_material()
		root.add_child(fm)
	var camps := b.camp_mesh()
	if camps != null:
		var cm := MeshInstance3D.new()
		cm.name = "CampLedges"
		cm.mesh = camps
		cm.material_override = AgedStone.rock_material()
		root.add_child(cm)
	var filler := b.filler_mesh()
	if filler != null:
		var fi := MeshInstance3D.new()
		fi.name = "Filler"
		fi.mesh = filler
		fi.material_override = AgedStone.rock_material()
		root.add_child(fi)
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


## The places where a separate stone (foot stone, decorative stone) is set into the face: x, y and the radius of its
## footprint. The face swells into a mound around each, so the stone grows out of the rock and has no seam.
var _spots: Array = []
var _spots_made := false


func _stone_spots() -> Array:
	if _spots_made:
		return _spots
	_spots_made = true
	for f in _feet():
		_spots.append(Vector3(f.x, f.y - 0.08, 0.95))
	for r in map.height:
		for c in map.width:
			var d := decor_at(c, r)
			if d.x >= 0.0:
				_spots.append(Vector3(d.x, d.y, 0.3 + 0.2 * d.z))
	return _spots


## How far the face stands out (positive) or is sunk (negative) at a point of the wall's plane.
func depth_at(x: float, y: float) -> float:
	return _field(x, y).depth


## The face's depth where a body or a rope passes: the surface without the pockets cut into it, so that only a hand
## or a foot goes into a hole and everything else stays outside the rock.
func face_depth_at(x: float, y: float) -> float:
	var f := _field(x, y)
	return float(f.depth) + float(f.dip)


## The face's depth at a point, with the paint of the rock there: {"depth", "colour", "trench", "knob"}.
func _field(x: float, y: float) -> Dictionary:
	var d := _noise.get_noise_2d(x * 0.55, y * 0.55) * 0.14 + _fine.get_noise_2d(x * 2.9, y * 2.9) * 0.035
	var tone := 0.5 + _fine.get_noise_2d(x * 1.3 + 40.0, y * 1.3) * 0.6
	var col := ROCK_DARK.lerp(ROCK, clampf(tone, 0.0, 1.0))
	var c0 := int(floor(x))
	var r0 := map.height - 1 - int(floor(y))
	var knob := 0.0
	var chalk_share := 0.7
	var pocket := 0.0
	var dip := 0.0   # how deep the pockets cut the face here (the face without them is depth + dip)
	var rim := 0.0
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
				var ease := hold_ease(map.malus_at(c, r))
				if pocket_at(c, r):
					# A pocket: a hole in the face the hand reaches into (a big one is easy, a small finger hole hard),
					# dark inside with a chalked rim.
					var pr := lerpf(KNOB_MIN_RADIUS * 0.9, KNOB_RADIUS * 1.0, ease)
					var pd := Vector2(x, y).distance_to(centre)
					# Pockets side by side (across or one above the other) run together into one slot.
					for nb in [Vector2i(1, 0), Vector2i(0, 1)]:
						var nc: int = c + nb.x
						var nr: int = r + nb.y
						if map.inside(nc, nr) and map.has_hold(nc, nr) and pocket_at(nc, nr):
							pd = minf(pd, _segment_distance(Vector2(x, y), centre, square_centre(map, nc, nr)))
					if pd < pr * 1.35:
						var inner := 0.5 + 0.5 * cos(PI * minf(1.0, pd / pr))
						var cut := lerpf(0.18, 0.34, ease) * inner * (0.85 + 0.3 * _hash(c, r))
						d -= cut
						dip = maxf(dip, cut)
						pocket = maxf(pocket, inner)
						if pd >= pr * 0.8:
							rim = maxf(rim, 1.0 - absf(pd - pr * 1.05) / (pr * 0.3))
					continue
				var radius := lerpf(KNOB_MIN_RADIUS, KNOB_RADIUS, ease)
				# A hard hold is a thin, wide crimp (flatter than it is wide); an easy one a round, chunky jug.
				var squash := lerpf(0.62, 1.0, ease)
				# Every hold has its own outline: a little wider or narrower, turned and lopsided, whatever its difficulty.
				var hv := _hash(c * 5 + 2, r * 3 + 7)
				var hw := _hash(c * 9 + 4, r * 7 + 1)
				var off := (Vector2(x, y) - centre).rotated((hv - 0.5) * 0.9)
				off.x /= lerpf(0.8, 1.3, hw)
				off.x += off.y * (hv - 0.5) * 0.35
				var dist := Vector2(off.x, off.y / squash).length() / lerpf(0.88, 1.15, hv)
				if dist < radius:
					var k := 0.5 + 0.5 * cos(PI * dist / radius)
					if k * lerpf(0.35, 1.0, ease) >= knob:
						chalk_share = lerpf(CHALK_HARD, CHALK_EASY, ease)
					knob = maxf(knob, k * lerpf(0.35, 1.0, ease))
					# Sloping: the upper edge of a hard hold falls away, the lower lip stays.
					var slope := 1.0 - (1.0 - ease) * 0.5 * clampf(off.y / radius, 0.0, 1.0)
					d += lerpf(KNOB_HEIGHT_HARD, KNOB_HEIGHT, ease) * k * slope * (0.85 + 0.3 * _hash(c, r))
			match map.hazard_at(c, r):
				WallMap.WET:
					wet = maxf(wet, 1.0 - smoothstep(0.0, 0.7, _edge_distance(x, y, c, r)))
				WallMap.LOOSE:
					loose = maxf(loose, 1.0 - smoothstep(0.0, 0.5, _edge_distance(x, y, c, r)))
	# The mound around each set-in stone: the face swells towards it, darker at the foot (grime) with a dusting above.
	var mound := 0.0
	for sp in _stone_spots():
		var md := Vector2(x - sp.x, (y - sp.y) * 1.2).length()
		if md < sp.z * 1.7:
			mound = maxf(mound, 0.5 + 0.5 * cos(PI * md / (sp.z * 1.7)))
	# Foot stones side by side are joined by a rib along the same ledge.
	var rib := 0.0
	_stone_spots()
	for l in _ledges:
		var rd := _segment_distance(Vector2(x, y - 0.05), l[0], l[1])
		if rd < 0.5:
			rib = maxf(rib, 0.5 + 0.5 * cos(PI * rd / 0.5))
	d += mound * 0.12 + rib * 0.2
	mound = maxf(mound, rib)
	col = col.lerp(ROCK_DARK * 0.7, mound * 0.45)
	var trench := 0.0
	for g in map.gaps:
		var x0 := float(g.position.x)
		var x1 := float(g.end.x)
		var y0 := float(map.height - g.end.y)
		var y1 := float(map.height - g.position.y)
		# Widest at the top: the lower edge of the gap is a bit narrower (a wedge), and the crack below goes on to a needle.
		var half := (x1 - x0) * 0.5
		var up := clampf((y - y0) / maxf(0.01, y1 - y0), 0.0, 1.0)
		var shrink := half * GAP_WEDGE * (1.0 - up)
		var sd := _box_distance(x, y, x0 + shrink, x1 - shrink, y0, y1)
		var jag := _noise.get_noise_2d(x * 2.1 + 9.0, y * 2.1) * 0.34 + _fine.get_noise_2d(x * 6.0, y * 6.0 + 5.0) * 0.12
		var inside := -(sd + jag)
		trench = maxf(trench, smoothstep(0.0, 0.3, inside))
		# The crack runs on below the gap, a few steps down, tapering to a needle, so it reads as a break in the face
		# (not a cave); it keeps clear of the holds.
		if y < y0:
			var t := clampf((y0 - y) / GAP_RUN, 0.0, 1.0)
			var narrow := maxf(0.27, half * (1.0 - GAP_WEDGE) * (1.0 - t))
			var cx := (x0 + x1) * 0.5
			var side := narrow - absf(x - cx) + jag * 0.15
			var run := smoothstep(0.0, 0.2, side) * (1.0 - 0.2 * t) * (1.0 - knob * 0.5)
			trench = maxf(trench, run * 0.95)
	d -= trench * GAP_DEPTH
	col = col.lerp(ROCK_DARK * 0.15, smoothstep(0.1, 0.6, pocket) * 0.95)
	col = col.lerp(CHALK, clampf(rim, 0.0, 1.0) * 0.7)
	col = col.lerp(CHALK, knob * chalk_share * (0.6 + 0.8 * _hash(c0, r0)))
	col = col.lerp(MOSS.lerp(ROCK_DARK, 0.3), wet * (0.5 + 0.4 * _fine.get_noise_2d(x * 5.0, y * 5.0)))
	col = col.lerp(Color(0.6, 0.54, 0.47), loose * 0.35)
	col = col.lerp(Color(0.03, 0.03, 0.035), trench * 0.92)
	return {"depth": d, "colour": col, "trench": trench, "knob": knob, "dip": dip}


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


## How easy a hold of this malus looks: 1 for malus 0 (a big jug), 0 for malus 9 (a thin crimp).
static func hold_ease(malus: int) -> float:
	return 1.0 - clampf(float(malus) / 9.0, 0.0, 1.0)


## Whether the hold of square (c, r) is a pocket (a hole in the face the hand reaches into) rather than a stone that
## stands out of it. Every hold is one or the other, never both: the face changes between stone and hole in patches (so
## neighbours of one kind merge into a rib or a slot), and a hold where a foot stone sits is always a stone.
func pocket_at(c: int, r: int) -> bool:
	var key := Vector2i(c, r)
	if _pockets.has(key):
		return _pockets[key]
	var centre := square_centre(map, c, r)
	var hole := _noise.get_noise_2d(centre.x * 0.5 + 11.0, centre.y * 0.5) > -0.08
	if _hash(c * 3 + 1, r * 5 + 2) < POCKET_FLIP:
		hole = not hole
	if hole:
		for f in _feet():
			if absf(f.x - centre.x) < FOOT_CLEAR.x and absf(f.y - centre.y) < FOOT_CLEAR.y:
				hole = false
				break
	_pockets[key] = hole
	return hole


var _pockets := {}
var _foot_list: Array = []
var _foot_made := false
var _ledges: Array = []


## Where every foot stone is (x, y), and the ledges that join foot stones side by side on one level.
func _feet() -> Array:
	if _foot_made:
		return _foot_list
	_foot_made = true
	for r in map.height:
		for c in map.width:
			if map.has_hold(c, r):
				var spot := foot_spot(map, c, r)
				if spot.x >= 0.0:
					_foot_list.append(spot)
	for i in _foot_list.size():
		for j in range(i + 1, _foot_list.size()):
			var a: Vector2 = _foot_list[i]
			var b: Vector2 = _foot_list[j]
			if absf(a.y - b.y) < 0.35 and absf(a.x - b.x) < LEDGE_REACH:
				_ledges.append([a, b])
	return _foot_list


## The decorative stone of plain square (c, r) as (x, y, size), or (-1, -1, 0) when it has none. A decorative stone never
## sits on a hold, a gap, loose stones, or near a pocket.
func decor_at(c: int, r: int) -> Vector3:
	if map.has_hold(c, r) or map.gap_at(c, r) >= 0 or map.hazard_at(c, r) == WallMap.LOOSE:
		return Vector3(-1, -1, 0)
	if _hash(c * 29 + 3, r * 31 + 7) > DECOR_SHARE:
		return Vector3(-1, -1, 0)
	# Keep clear of the special spots (tar, edelweiss, door) so they are seen.
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if map.marker_at(c + dc, r + dr) in ["tar", "edelweiss", "door", "secret"]:
				return Vector3(-1, -1, 0)
	var h1 := _hash(c * 7 + 1, r * 5 + 2)
	var h2 := _hash(c * 11 + 5, r * 3 + 9)
	var centre := square_centre(map, c, r)
	var at := Vector2(centre.x + (h1 - 0.5) * 0.7, centre.y + (h2 - 0.5) * 0.7)
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if map.inside(c + dc, r + dr) and map.has_hold(c + dc, r + dr) and pocket_at(c + dc, r + dr):
				if at.distance_to(square_centre(map, c + dc, r + dr)) < DECOR_CLEAR:
					return Vector3(-1, -1, 0)
	return Vector3(at.x, at.y, 0.9 + 1.3 * h1)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)


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
	# Ice matters only where a hand or a foot goes: it lies on the hold stones and the foot stones, not on bare rock.
	var near := 0.0
	for sp in _ice_spots():
		near = maxf(near, 1.0 - smoothstep(sp.z * 0.55, sp.z, Vector2((x - sp.x) * 0.8, y - sp.y).length()))
	if near <= 0.0:
		return 0.0
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if not map.inside(c + dc, r + dr) or map.hazard_at(c + dc, r + dr) != WallMap.ICE:
				continue
			var centre := square_centre(map, c + dc, r + dr)
			var q := Vector2(absf(x - centre.x), absf(y - centre.y))
			var inside := 0.5 - maxf(q.x, q.y) + wobble
			best = maxf(best, smoothstep(-0.05, 0.28, inside))
	return best * near


var _ice_list: Array = []
var _ice_made := false


## The places on ice squares where the ice lies: every hold and the foot stone under it, as x, y and a radius.
func _ice_spots() -> Array:
	if _ice_made:
		return _ice_list
	_ice_made = true
	for r in map.height:
		for c in map.width:
			if map.hazard_at(c, r) == WallMap.ICE and map.has_hold(c, r):
				var centre := square_centre(map, c, r)
				_ice_list.append(Vector3(centre.x, centre.y, 0.8))
				var foot := foot_spot(map, c, r)
				if foot.x >= 0.0:
					_ice_list.append(Vector3(foot.x, foot.y, 1.0))
	return _ice_list


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
	return _weathered(st.commit())


## Where the feet of a climber on the hold of square (c, r) stand on the wall (x, y), or (-1, -1) when they stand on
## the ground. Every such place has a foot stone (see foot_mesh), so he never stands on air.
static func foot_spot(wall: WallMap, c: int, r: int) -> Vector2:
	var centre := square_centre(wall, c, r)
	if centre.y - FOOT_DROP < FOOT_MIN_Y:
		return Vector2(-1, -1)
	return Vector2(centre.x, centre.y - FOOT_DROP)


## The stones the feet stand on: a broad ledge jutting out of the face under every hold the climber can hang from.
func foot_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	var count := 0
	for r in map.height:
		for c in map.width:
			if not map.has_hold(c, r):
				continue
			var spot := foot_spot(map, c, r)
			if spot.x < 0.0:
				continue
			var h := _hash(c * 23 + 1, r * 19 + 6)
			var h2 := _hash(c * 31 + 4, r * 37 + 2)
			var h3 := _hash(c * 41 + 9, r * 43 + 5)
			# Three kinds of stone, each wider or narrower, higher or flatter and tilted differently, so no two look alike.
			var kind: String = FOOT_KINDS[int(h2 * 3.0) % 3]
			var mesh: ArrayMesh = NaturalRock.mesh(kind)
			if mesh == null:
				continue
			var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0 + (h3 - 0.5) * 16.0)) * Basis(Vector3.UP, (h - 0.5) * 1.3)
			var size := Vector3(lerpf(1.5, 2.5, h2), lerpf(1.35, 2.1, h3), lerpf(1.3, 1.9, h))
			if kind == "rock_single_A":
				size *= Vector3(1.25, 1.5, 1.3)   # the flat kind is made taller to carry a foot
			st.append_from(mesh, 0, Transform3D(basis.scaled(size), Vector3(spot.x + (h3 - 0.5) * 0.15, spot.y - 0.08, depth_at(spot.x, spot.y) - 0.07)))
			count += 1
	if count == 0:
		return null
	return _weathered(st.commit(), true)


## The ledge of every rest place (marker "camp"): a broad shelf of the wall's own stones, CAMP_LEDGE_WIDTH squares
## wide and jutting out far further than a foot stone, laid under the feet so the climber has a place to rest that
## shows from afar. Chalked on top like the stones that are used.
func camp_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	var count := 0
	for cell: Vector2i in map.markers:
		if map.markers[cell] != "camp":
			continue
		var spot := foot_spot(map, cell.x, cell.y)
		if spot.x < 0.0:
			continue
		var pieces := 5
		for i in pieces:
			var t := float(i) / (pieces - 1)
			var h1 := _hash(cell.x * 13 + i, cell.y * 7 + 3)
			var h2 := _hash(cell.x * 19 + 2, cell.y * 11 + i)
			var h3 := _hash(cell.x * 5 + i * 3, cell.y * 17 + 1)
			var mesh: ArrayMesh = NaturalRock.mesh(FOOT_KINDS[i % 3] if i != 2 else "rock_single_A")
			if mesh == null:
				continue
			var x := spot.x + (t - 0.5) * (CAMP_LEDGE_WIDTH - 0.9) + (h1 - 0.5) * 0.2
			var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0 + (h3 - 0.5) * 8.0)) * Basis(Vector3.UP, (h1 - 0.5) * 0.5)
			var size := Vector3(lerpf(2.5, 3.1, h2), lerpf(1.9, 2.4, h3), lerpf(2.3, 2.9, h1))
			if FOOT_KINDS[i % 3] == "rock_single_A" or i == 2:
				size *= Vector3(1.1, 1.3, 1.1)
			st.append_from(mesh, 0, Transform3D(basis.scaled(size), Vector3(x, spot.y - 0.1, depth_at(x, spot.y) - 0.1)))
			count += 1
		# One long flat slab under them all, so the shelf reads as a single ledge.
		var slab: ArrayMesh = NaturalRock.mesh("rock_single_A")
		if slab != null:
			var hs := _hash(cell.x * 3 + 8, cell.y * 5 + 1)
			var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0)) * Basis(Vector3.UP, (hs - 0.5) * 0.2)
			st.append_from(slab, 0, Transform3D(basis.scaled(Vector3(CAMP_LEDGE_WIDTH * 1.15, 1.5, 2.4)), Vector3(spot.x, spot.y - 0.3, depth_at(spot.x, spot.y) - 0.12)))
			count += 1
	if count == 0:
		return null
	return _weathered(st.commit(), true)


## Small connecting stones that fill the spaces between the foot stones (along each ledge and between neighbours on
## different levels) so the stones blend into one rocky face. They are only for the look: no hold, no foot, no climbing.
func filler_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	var count := 0
	var kinds := ["rock_single_A", "rock_single_C", "rock_single_E"]
	var feet := _feet()
	var pairs: Array = _ledges.duplicate()
	for i in feet.size():
		for j in range(i + 1, feet.size()):
			var a: Vector2 = feet[i]
			var b: Vector2 = feet[j]
			if absf(a.y - b.y) >= 0.35 and a.distance_to(b) < FILLER_REACH and _hash(int(a.x * 7.0) + i, int(b.y * 7.0) + j) < 0.3:
				pairs.append([a, b])
	for pair in pairs:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		var n := 1
		for k in n:
			var h1 := _hash(int(a.x * 10.0) + k * 7, int(a.y * 10.0) + int(b.x * 10.0))
			var h2 := _hash(int(b.y * 10.0) + k * 3, int(a.x * 10.0) + 5)
			var at := a.lerp(b, (k + 1.0) / (n + 1.0)) + Vector2((h1 - 0.5) * 0.25, (h2 - 0.5) * 0.3)
			var mesh: ArrayMesh = NaturalRock.mesh(kinds[int(h1 * 3.0) % 3])
			if mesh == null:
				continue
			var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0 + (h2 - 0.5) * 40.0)) * Basis(Vector3.UP, h1 * TAU)
			var size := lerpf(0.6, 1.2, h2)
			st.append_from(mesh, 0, Transform3D(basis.scaled(Vector3.ONE * size), Vector3(at.x, at.y - 0.05, depth_at(at.x, at.y) - 0.06)))
			count += 1
	if count == 0:
		return null
	return _weathered(st.commit())


## Decorative stones that jut out of the face here and there, only on plain squares (no hold, no gap, no loose
## stones), varied in kind, size and lean. They make the mountain look rocky and are not part of the climb.
func decor_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	var count := 0
	var kinds := ["rock_single_A", "rock_single_C", "rock_single_E"]
	for r in map.height:
		for c in map.width:
			var spot := decor_at(c, r)
			if spot.x < 0.0:
				continue
			var h1 := _hash(c * 7 + 1, r * 5 + 2)
			var h2 := _hash(c * 11 + 5, r * 3 + 9)
			var h3 := _hash(c * 17 + 2, r * 13 + 4)
			var x := spot.x
			var y := spot.y
			var mesh: ArrayMesh = NaturalRock.mesh(kinds[int(h3 * 3.0) % 3])
			if mesh == null:
				continue
			var factor := spot.z
			var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0 + (h2 - 0.5) * 70.0)) * Basis(Vector3.UP, h3 * TAU)
			st.append_from(mesh, 0, Transform3D(basis.scaled(Vector3.ONE * factor), Vector3(x, y, depth_at(x, y) - 0.08)))
			count += 1
	if count == 0:
		return null
	return _weathered(st.commit())


## The stones of a hidden door (marker "secret") at square (c, r): the very stones the wall itself is dressed with (the
## same rock meshes, in the same weathering, chalk and ice as the decorative stones), a few lapping over the door's
## opening so that nothing sets it apart from its neighbours. In wall coordinates, like the other stone meshes; the stage
## hangs them on the door's pivot.
func secret_mesh(c: int, r: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	var centre := square_centre(map, c, r)
	var kinds := ["rock_single_A", "rock_single_C", "rock_single_E"]
	var spots := [Vector3(-0.1, 0.05, 1.7), Vector3(0.12, 0.7, 1.8), Vector3(-0.06, 1.3, 1.6)]
	var count := 0
	for i in spots.size():
		var h1 := _hash(c * 7 + i, r * 5 + 2)
		var h2 := _hash(c * 11 + 5 + i, r * 3 + 9)
		var h3 := _hash(c * 17 + 2, r * 13 + 4 + i)
		var mesh: ArrayMesh = NaturalRock.mesh(kinds[int(h3 * 3.0) % 3])
		if mesh == null:
			continue
		var at: Vector3 = spots[i]
		var x := centre.x + at.x
		var y := centre.y + at.y
		var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0 + (h2 - 0.5) * 70.0)) * Basis(Vector3.UP, h3 * TAU)
		st.append_from(mesh, 0, Transform3D(basis.scaled(Vector3.ONE * at.z * (0.9 + 0.2 * h1)), Vector3(x, y, depth_at(centre.x, centre.y) - 0.08)))
		count += 1
	if count == 0:
		return null
	return _weathered(st.commit())


## The set-in stones take the face's weather: a shade darker and greyer than the plain mountain stone, so they sit in the
## rock instead of looking pale and stuck on. Like the wall they wear chalk dust on what faces up, and ice and frost
## where the face around them is wet.
func _weathered(mesh: ArrayMesh, used := false) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var colours = arrays[Mesh.ARRAY_COLOR]
	if colours == null:
		return mesh
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var out := PackedColorArray()
	for i in colours.size():
		var col: Color = colours[i].lerp(ROCK_DARK, STONE_WEATHER) * STONE_SHADE
		var n := normals[i] if i < normals.size() else Vector3.ZERO
		var up := clampf(n.y, 0.0, 1.0)
		var front := clampf(n.z, 0.0, 1.0)
		var c := int(floor(verts[i].x / WallMap.SQUARE))
		var r := map.height - 1 - int(floor(verts[i].y / WallMap.SQUARE))
		# Chalk comes off the hands and shoes: it lies on the tops of the stones that are used (a trace on the fronts),
		# hardly at all on stones nobody touches, and never on the underside.
		var chalk := (up * 0.9 + front * 0.2) * (STONE_CHALK if used else STONE_CHALK * 0.2)
		col = col.lerp(CHALK, chalk * (0.7 + 0.6 * _hash(c * 3 + 1, r * 7 + 2)))
		# Ice follows the water: it builds up thick on the tops where meltwater stands, as a thin frost on the fronts, and
		# not at all on the underside, which is sheltered; a patch breaks up at its edge.
		if _ice_at(c, r) or _ice_at(c, r - 1) or _ice_at(c, r - 2):
			var thick := maxf(up, front * 0.4)
			if n.y < -0.15:
				thick = 0.0
			thick *= 0.75 + 0.5 * _fine.get_noise_2d(verts[i].x * 6.0, verts[i].y * 6.0)
			col = col.lerp(ICE_TINT, clampf(thick, 0.0, 1.0) * 0.95)
		out.append(col)
	arrays[Mesh.ARRAY_COLOR] = out
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made


func _ice_at(c: int, r: int) -> bool:
	return map.inside(c, r) and map.hazard_at(c, r) == WallMap.ICE and map.has_hold(c, r)


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
