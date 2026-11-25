class_name MountainFoot
extends RefCounted
## Where the mountains meet the open ground (see Mountains). The rock used to stand on the grass along a straight
## tile line, with a grey scree strip and a hard seam. The foot now spreads out over the meadow:
## - lobes: low extensions of the mountain itself (a mesh of its own, in its colours, with a collision shape so the
##   hero walks up onto them) that reach out of the foot in zig-zags and promontories, a metre or two in places and
##   five or six in others, so the base is no longer a straight wall;
## - mounds: low outliers like small mountains, up to half a character high, scattered a few metres out in the grass;
## - an apron of earth and gravel in the rock's colours under and round both (the meadow shader draws it from
##   `field`, its outline frays into the grass);
## - small things over all of it: stones, tufts of grass and weeds, and a few small boulders.
## The approach of every climbing spot (see ClimbSpots), a lane the width of the spot and its neighbours, is left walkable
## and clean, and fades into the foot over a few metres beside it.
## `style` picks the parts (the sketches of the foot compare them).

## How far the plain apron reaches out from the rock tiles' edge (metres).
const REACH := 3.0
## Field pixels per tile.
const PX := 4
## The lobes: the farthest one can reach (metres from the rock's edge), how high at the wall, the grid of their mesh.
const LOBE_MAX := 6.6
const LOBE_H := 1.0
const LOBE_STEP := 0.8
## Metres a lobe or a mound fades away over, beyond the clean approach of a climbing spot.
const CLEAR_FADE := 3.0
## The styles: "" is the old hard seam; "foot" has every part (see `has`).
const STYLES := ["", "foot"]
const PARTS := {
	"": [],
	"foot": ["apron", "gravel", "moss", "tufts", "stones", "rocks", "lobes", "mounds"],
}
static var style := "foot"

## The earth at the rock's foot, on the mesh and on the ground (see meadow.gdshader, foot_earth), and the moss and
## grass that creep up the rock's base.
const EARTH := Color(0.5, 0.44, 0.37)
## The ground letters the foot spreads over: open meadow and the scree of the passes (Notch Pass, say). Every
## rock tile of an Outdoor map gets a foot this way, so a new mountain needs nothing of its own.
## The foot's edge where it touches the rock: how opaque it is there, and how far out it is solid again (metres).
const EDGE_ALPHA := 0.5
const EDGE_FADE := 2.0
const OPEN := ".\'"
const GREEN := Color(0.3, 0.37, 0.16)


static func has(part: String) -> bool:
	return (PARTS[style] as Array).has(part)


# --- Where the rock is ----------------------------------------------------------------------------------------------

## The rectangles (metres) of the rock tiles within `tiles` tiles of the tile that holds (x, z).
static func _rects_near(level: Level, x: float, z: float, tiles: int) -> Array[Rect2]:
	var tile := Level.TILE
	var cx := roundi(x / tile)
	var cz := roundi(z / tile)
	var out: Array[Rect2] = []
	for dz in range(-tiles, tiles + 1):
		for dx in range(-tiles, tiles + 1):
			var t := Vector2i(cx + dx, cz + dz)
			if Mountains.is_rock(level, t):
				out.append(Rect2((t.x - 0.5) * tile, (t.y - 0.5) * tile, tile, tile))
	return out


## How far (metres) (x, z) lies from the nearest of `rects`, 0 inside one, INF when there are none.
static func _dist(rects: Array[Rect2], x: float, z: float) -> float:
	var best := INF
	for r in rects:
		var ox := maxf(0.0, maxf(r.position.x - x, x - r.end.x))
		var oz := maxf(0.0, maxf(r.position.y - z, z - r.end.y))
		best = minf(best, sqrt(ox * ox + oz * oz))
	return best


## How far inside the nearest of `rects` (x, z) lies (metres from its edge), 0 outside them all.
static func _depth(rects: Array[Rect2], x: float, z: float) -> float:
	var best := 0.0
	for r in rects:
		if r.has_point(Vector2(x, z)):
			best = maxf(best, minf(minf(x - r.position.x, r.end.x - x), minf(z - r.position.y, r.end.y - z)))
	return best


## How far (metres) `at` (x, z) lies from the nearest rock tile's edge, 0 inside the rock, or INF when there is none
## within two tiles.
static func rock_distance(level: Level, x: float, z: float) -> float:
	return _dist(_rects_near(level, x, z, 2), x, z)


## 0 on the approach of a climbing spot (its tile and the open ground in front of it), rising to 1 over CLEAR_FADE
## metres away from it.
static func clear_fade(level: Level, x: float, z: float) -> float:
	var tile := Level.TILE
	var fade := 1.0
	for s: Dictionary in ClimbSpots.spots(level):
		var c: Vector2i = s.cell
		var box := Rect2((c.x - 1.5) * tile, (c.y - 1.5) * tile, 3.0 * tile, 5.0 * tile)
		var ox := maxf(0.0, maxf(box.position.x - x, x - box.end.x))
		var oz := maxf(0.0, maxf(box.position.y - z, z - box.end.y))
		fade = minf(fade, smoothstep(0.0, CLEAR_FADE, sqrt(ox * ox + oz * oz)))
	return fade


## 0 on a building plot (and its clearance), rising to 1 over 2.5 m away from it, so the lobes taper off beside a
## plot instead of ending in a straight cut.
static func plot_fade(level: Outdoor, x: float, z: float) -> float:
	var p := Vector2(x, z)
	var fade := 1.0
	for area: Rect2 in level._plot_areas:
		var dist := p.clamp(area.position, area.end).distance_to(p) - Outdoor.PLOT_CLEARANCE - 0.3
		fade = minf(fade, smoothstep(0.0, 2.5, dist))
	return fade


static func _plain(level: Level, x: float, z: float) -> bool:
	var tile := Level.TILE
	var c := Vector2i(roundi(x / tile), roundi(z / tile))
	if c.x < 0 or c.y < 0 or c.x >= level.width or c.y >= level.height:
		return false
	return OPEN.contains(level.cell_char(c))


## The tiles the foot can touch: every tile within three tiles of a rock tile that borders open ground, and those round
## a mound. Found once per call of `scatter` and `field` (the map is big, the foot is a thin band along the rock).
static func _candidates(level: Outdoor, all_mounds: Array) -> Dictionary:
	var out := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if not Mountains.is_rock(level, c):
				continue
			var edge := false
			for d: Vector2i in dirs:
				if not Mountains.is_rock(level, c + d):
					edge = true
					break
			if not edge:
				continue
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var n := c + Vector2i(dx, dy)
					if n.x >= 0 and n.y >= 0 and n.x < level.width and n.y < level.height:
						out[n] = true
	var tile := Level.TILE
	for m: Dictionary in all_mounds:
		var mc := Vector2i(roundi(float(m.at.x) / tile), roundi(float(m.at.y) / tile))
		var reach := ceili((float(m.r) * 1.5 + 4.0) / tile) + 1
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var n := mc + Vector2i(dx, dy)
				if n.x >= 0 and n.y >= 0 and n.x < level.width and n.y < level.height:
					out[n] = true
	return out


# --- Lobes ----------------------------------------------------------------------------------------------------------

## How far out (metres from the rock's edge) the lobe at (x, z) reaches: a few big promontories, many short spurs,
## and a zig-zag in the outline.
static func lobe_reach(x: float, z: float) -> float:
	var big := fbm(x * 0.26 + 3.0, z * 0.26)
	var zig := fbm(x * 0.9 + 17.0, z * 0.9)
	return maxf(0.6, 1.0 + 4.6 * smoothstep(0.48, 0.78, big) + 1.2 * (zig - 0.5))


## The height (metres) of the mountain's foot lobes over (x, z): highest at the rock, sloping out to nothing at the
## lobe's outline, never on a path, a plot or a climbing spot's approach.
static func lobe_height(level: Level, rects: Array[Rect2], x: float, z: float) -> float:
	var d := _dist(rects, x, z)
	if d >= LOBE_MAX:
		return 0.0
	var reach := lobe_reach(x, z)
	# A little way into the rock the lobe goes on at full height and ends under the mountain's own mesh, so the two
	# meet with no gap.
	var tuck := 1.0
	if d <= 0.0:
		var depth := _depth(rects, x, z)
		if depth > 1.4:
			return 0.0
		tuck = 1.0 - smoothstep(0.8, 1.4, depth)
	else:
		if d >= reach or not _plain(level, x, z):
			return 0.0
	var fade := clear_fade(level, x, z)
	if d > 0.0 and level is Outdoor:
		fade = minf(fade, plot_fade(level as Outdoor, x, z))
	if fade <= 0.0:
		return 0.0
	var t := 1.0 - d / reach
	var h := LOBE_H * minf(1.0, reach / 3.6) * pow(t, 1.15) * (0.75 + 0.5 * fbm(x * 0.5 + 9.0, z * 0.5))
	h += (fbm(x * 2.8, z * 2.8) - 0.5) * 0.34 * t
	return maxf(0.0, h * fade * tuck - 0.02)


# --- Mounds ---------------------------------------------------------------------------------------------------------

## The mounds of `level`: [{at: Vector2 (x, z), r, h, seed}], found once and kept (they depend only on the map and the
## plots standing at the time).
static func mounds(level: Outdoor) -> Array:
	if level.has_meta("foot_mounds"):
		return level.get_meta("foot_mounds")
	var list := []
	if has("mounds"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(level.level_name + "hoeger")
		var tile := Level.TILE
		for y in level.height:
			for x in level.width:
				var c := Vector2i(x, y)
				if not OPEN.contains(level.cell_char(c)):
					continue
				var mid := level.cell_to_world(c)
				var rects := _rects_near(level, mid.x, mid.z, 3)
				if rects.is_empty():
					continue
				var dm := _dist(rects, mid.x, mid.z)
				if dm < 3.0 or dm > 9.5 or rng.randf() > 0.2:
					continue
				var at := Vector2(mid.x + rng.randf_range(-1.4, 1.4), mid.z + rng.randf_range(-1.4, 1.4))
				var r := rng.randf_range(1.3, 2.9)
				var m := {"at": at, "r": r, "h": clampf(0.25 * r, 0.4, 0.68), "seed": rng.randf() * 50.0}
				if _mound_ok(level, m, list, rects):
					list.append(m)
	level.set_meta("foot_mounds", list)
	return list


static func _mound_ok(level: Outdoor, m: Dictionary, list: Array, rects: Array[Rect2]) -> bool:
	var at: Vector2 = m.at
	var r: float = m.r
	if _dist(rects, at.x, at.y) < 2.2 or clear_fade(level, at.x, at.y) < 1.0:
		return false
	for k in 12:
		var a := TAU * k / 12.0
		var px := at.x + cos(a) * (r * 1.4 + 0.6)
		var pz := at.y + sin(a) * (r * 1.4 + 0.6)
		if not _plain(level, px, pz) or clear_fade(level, px, pz) < 1.0:
			return false
	if level.on_plot(Vector3(at.x, 0, at.y), r + 0.8):
		return false
	for o: Dictionary in list:
		if (o.at as Vector2).distance_to(at) < float(o.r) + r + 1.2:
			return false
	return true


## The height of mound `m` over (x, z): a low dome with a lobed outline, a flattish top and a little crag.
static func mound_height(m: Dictionary, x: float, z: float) -> float:
	var at: Vector2 = m.at
	var dx := x - at.x
	var dz := z - at.y
	var dist := sqrt(dx * dx + dz * dz)
	var ang := atan2(dz, dx)
	var seed_value: float = m.seed
	var rr: float = float(m.r) * (1.0 + 0.32 * (fbm(cos(ang) * 1.4 + seed_value, sin(ang) * 1.4 + seed_value * 0.5) * 2.0 - 1.0))
	if dist >= rr:
		return 0.0
	var t := 1.0 - dist / rr
	var s := smoothstep(0.0, 0.7, t)
	var h: float = float(m.h) * s + (fbm(x * 2.2 + seed_value, z * 2.2) - 0.5) * 0.2 * s
	return maxf(0.0, h - 0.02)


## Whether something at (x, z) with `margin` to spare would stand in a lobe or a mound (a tree, say).
static func covers(level: Level, x: float, z: float, margin: float) -> bool:
	if not (has("lobes") or has("mounds")) or not level is Outdoor:
		return false
	var rects := _rects_near(level, x, z, 3)
	if has("lobes"):
		for off in [Vector2.ZERO, Vector2(margin, 0), Vector2(-margin, 0), Vector2(0, margin), Vector2(0, -margin)]:
			if lobe_height(level, rects, x + off.x, z + off.y) > 0.02:
				return true
	for m: Dictionary in mounds(level as Outdoor):
		if (m.at as Vector2).distance_to(Vector2(x, z)) < float(m.r) * 1.4 + margin:
			return true
	return false


## The height of the foot's ground (lobes and mounds) at (x, z), for what lies on it.
static func ground_height(level: Outdoor, rects: Array[Rect2], near: Array, x: float, z: float) -> float:
	var h := lobe_height(level, rects, x, z) if has("lobes") else 0.0
	for m: Dictionary in near:
		h = maxf(h, mound_height(m, x, z))
	return h


# --- The apron on the ground ----------------------------------------------------------------------------------------

## The apron as one picture over the whole map, PX pixels to a tile: 1 inside the rock at its foot, falling to 0
## REACH metres out on the open ground, and round the lobes and mounds the same way.
static func field(level: Outdoor) -> Image:
	var img := Image.create(level.width * PX, level.height * PX, false, Image.FORMAT_R8)
	var tile := Level.TILE
	var all := mounds(level)
	for c: Vector2i in _candidates(level, all):
		var x := c.x
		var y := c.y
		var rock := Mountains.is_rock(level, c)
		var mid := level.cell_to_world(c)
		var rects := _rects_near(level, mid.x, mid.z, 3)
		var near: Array = all.filter(func(m: Dictionary) -> bool: return (m.at as Vector2).distance_to(Vector2(mid.x, mid.z)) < float(m.r) * 1.5 + 4.0 + tile)
		for py in PX:
			for px in PX:
				var sx := (x + (px + 0.5) / PX - 0.5) * tile
				var sz := (y + (py + 0.5) / PX - 0.5) * tile
				var d := 0.0 if rock else _dist(rects, sx, sz)
				var v := 0.0
				if d < REACH:
					v = 1.0 - d / REACH
				if not rock and d < LOBE_MAX and has("lobes") and _plain(level, sx, sz):
					var outer := d - lobe_reach(sx, sz)
					v = maxf(v, (1.0 - smoothstep(-0.2, 1.6, outer)) * 0.95 * plot_fade(level, sx, sz))
				for m: Dictionary in near:
					var ang := atan2(sz - float(m.at.y), sx - float(m.at.x))
					var edge := Vector2(sx, sz).distance_to(m.at) - float(m.r) * (1.0 + 0.32 * (fbm(cos(ang) * 1.4 + float(m.seed), sin(ang) * 1.4 + float(m.seed) * 0.5) * 2.0 - 1.0))
					v = maxf(v, (1.0 - smoothstep(-0.4, 2.0, edge)) * 0.9)
				if v > 0.0 and not rock:
					v *= clear_fade(level, sx, sz)
				if v > 0.0:
					img.set_pixel(x * PX + px, y * PX + py, Color(v, 0, 0, 1))
	return img


## Gives the ground shader the apron (or takes it away, for the old look).
static func apply(level: Outdoor) -> void:
	var mat: ShaderMaterial = level.get("_ground_mat")
	if mat == null:
		return
	if level.has_meta("foot_field_style") and level.get_meta("foot_field_style") != style:
		level.remove_meta("foot_field")
		level.remove_meta("foot_mounds")
	level.set_meta("foot_field_style", style)
	if not level.has_meta("foot_field"):
		level.set_meta("foot_field", ImageTexture.create_from_image(field(level)))
	mat.set_shader_parameter("foot_mask", level.get_meta("foot_field"))
	mat.set_shader_parameter("foot_apron", 1.0 if has("apron") else 0.0)
	mat.set_shader_parameter("foot_gravel", 1.0 if has("gravel") else 0.0)
	mat.set_shader_parameter("foot_moss", 1.0 if has("moss") else 0.0)


# --- The meshes -----------------------------------------------------------------------------------------------------

static var _meshes := {}


## A low rock of about unit size, flat on the bottom, in the mountain's colours, as one flat-shaded mesh.
static func _rock_mesh(seed_value: int) -> ArrayMesh:
	var key := "rock%d" % seed_value
	if _meshes.has(key):
		return _meshes[key]
	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.radius = 0.5
	sphere.height = 1.0
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var shaken := {}
	for i in verts.size():
		var v := verts[i]
		var k := Vector3i(roundi(v.x * 100.0), roundi(v.y * 100.0), roundi(v.z * 100.0))
		if not shaken.has(k):
			shaken[k] = Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.16, 0.16))
		v += shaken[k]
		v.y = maxf(v.y, -0.12)
		verts[i] = v
	arrays[Mesh.ARRAY_VERTEX] = verts
	var base := ArrayMesh.new()
	base.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(base, 0)
	st.deindex()
	st.generate_normals()
	var flat := st.commit()
	var out := SurfaceTool.new()
	out.begin(Mesh.PRIMITIVE_TRIANGLES)
	var data := flat.surface_get_arrays(0)
	var pos: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	for t in pos.size() / 3:
		var shade := rng.randf_range(0.85, 1.08)
		var up: float = nor[t * 3].y
		var colour := Mountains.ROCK.lerp(Mountains.ROCK_DARK, clampf((0.7 - up) * 1.2, 0.0, 0.7)) * shade
		colour = colour.lerp(Mountains.MOSS, clampf(up - 0.55, 0.0, 0.5) * 0.45)
		colour = colour.lerp(EARTH * 0.95, 0.3)
		colour.a = 1.0
		for k in 3:
			out.set_color(colour)
			out.set_normal(nor[t * 3 + k])
			out.add_vertex(pos[t * 3 + k])
	var mesh := out.commit()
	_meshes[key] = mesh
	return mesh


## A little clump of grass blades, leaning every way, dark at the root and brighter at the tips.
static func _tuft_mesh() -> ArrayMesh:
	if _meshes.has("tuft"):
		return _meshes["tuft"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 11:
		var angle := rng.randf() * TAU
		var out := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-out.z, 0, out.x)
		var root := out * rng.randf_range(0.0, 0.1)
		var tall := rng.randf_range(0.18, 0.38)
		var lean := rng.randf_range(0.05, 0.28)
		var tip := root + out * lean + Vector3(0, tall, 0)
		var wide := rng.randf_range(0.025, 0.04)
		var dark := Color(0.24, 0.28, 0.1)
		var light := Color(0.5, 0.56, 0.22).lerp(Color(0.68, 0.55, 0.22), rng.randf() * 0.7)
		for v in [[root - side * wide, dark], [root + side * wide, dark], [tip, light]]:
			st.set_color(v[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	var mesh := st.commit()
	_meshes["tuft"] = mesh
	return mesh


## The colour of the foot's rock at a point: the mountain's rock, warmed towards the earth of the apron, and the
## earth itself where the lobe thins out to the ground (so it melts into the apron), moss on the flat tops.
static func _rock_colour(x: float, z: float, h: float, up: float, greyer: float) -> Color:
	var c := Mountains.ROCK.lerp(EARTH, 0.4 - greyer) * 1.1
	c = c.lerp(Mountains.ROCK_DARK, clampf((0.93 - up) * 3.0, 0.0, 0.75))
	c *= 0.9 + 0.2 * fbm(x * 1.3 + 5.0, z * 1.3)
	c = c.lerp(EARTH * (0.92 + 0.16 * fbm(x * 0.7, z * 0.7)), 1.0 - smoothstep(0.02, 0.14, h))
	if has("moss"):
		c = c.lerp(Mountains.MOSS, clampf(up - 0.8, 0.0, 0.2) * 3.0 * smoothstep(0.35, 0.65, fbm(x * 0.9 + 31.0, z * 0.9)) * 0.28 * smoothstep(0.1, 0.3, h))
	c.a = 1.0
	return c


## A height field over `box` (x and z in metres), `step` apart, as a smooth mesh (null when nothing rises) and the
## triangles for a collision shape. `greyer` takes the rock's colour towards grey.
static func _terrain(box: Rect2, step: float, height: Callable, greyer: float, rects: Array[Rect2] = []) -> Dictionary:
	var nx := ceili(box.size.x / step)
	var nz := ceili(box.size.y / step)
	# One extra ring of heights all round, for the normals at the border.
	var hs := []
	for iz in range(-1, nz + 2):
		var row := PackedFloat32Array()
		for ix in range(-1, nx + 2):
			row.append(height.call(box.position.x + ix * step, box.position.y + iz * step))
		hs.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var count := 0
	var vert := func(ix: int, iz: int) -> Array:
		var h: float = hs[iz + 1][ix + 1]
		var n := Vector3(float(hs[iz + 1][ix]) - float(hs[iz + 1][ix + 2]), 2.0 * step, float(hs[iz][ix + 1]) - float(hs[iz + 2][ix + 1])).normalized()
		var x := box.position.x + ix * step
		var z := box.position.y + iz * step
		var colour := _rock_colour(x, z, h, n.y, greyer)
		# Where the foot meets the rock it is half see-through, and solid again EDGE_FADE metres out.
		if not rects.is_empty():
			colour.a = lerpf(EDGE_ALPHA, 1.0, smoothstep(0.2, EDGE_FADE, _dist(rects, x, z)))
		return [Vector3(x, h - 0.03, z), n, colour]
	for iz in nz:
		for ix in nx:
			var top := maxf(maxf(float(hs[iz + 1][ix + 1]), float(hs[iz + 1][ix + 2])), maxf(float(hs[iz + 2][ix + 1]), float(hs[iz + 2][ix + 2])))
			if top < 0.025:
				continue
			var a: Array = vert.call(ix, iz)
			var b: Array = vert.call(ix + 1, iz)
			var c: Array = vert.call(ix, iz + 1)
			var d: Array = vert.call(ix + 1, iz + 1)
			# The diagonals alternate by the point's place on the world's grid, so chunks that overlap draw the same triangles.
			var parity := (roundi(box.position.x / step) + ix + roundi(box.position.y / step) + iz) % 2
			var tris := [[a, b, d], [a, d, c]] if parity == 0 else [[a, b, c], [b, d, c]]
			for t: Array in tris:
				# Clockwise seen from above, as Godot wants its front faces.
				var u: Array = t[0]
				var v: Array = t[1]
				var w: Array = t[2]
				if ((v[0] - u[0]) as Vector3).cross(w[0] - u[0]).y > 0.0:
					var swap := v
					v = w
					w = swap
				for p: Array in [u, v, w]:
					st.set_color(p[2])
					st.set_normal(p[1])
					st.add_vertex(p[0])
					faces.append(p[0])
				count += 1
	if count == 0:
		return {}
	return {"mesh": st.commit(), "faces": faces}


static var _foot_rock: ShaderMaterial = null


## The rock of the foot: the mountain's stone with its edge towards the rock see-through (mountain_foot_rock.gdshader).
static func foot_material() -> ShaderMaterial:
	if _foot_rock == null:
		_foot_rock = ShaderMaterial.new()
		_foot_rock.shader = preload("res://shaders/mountain_foot_rock.gdshader")
		_foot_rock.set_shader_parameter("age", AgedStone.ROCK_AGE)
		_foot_rock.set_shader_parameter("lichen", AgedStone.ROCK_LICHEN)
	return _foot_rock


static func _place_terrain(root: Node3D, level: Outdoor, name: String, made: Dictionary) -> void:
	if made.is_empty():
		return
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = made.mesh
	node.material_override = foot_material()
	node.visibility_range_end = 90.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	# The hero walks up onto it: the same collision as the rest of the level's solid things.
	var body := StaticBody3D.new()
	body.name = name + "Body"
	body.collision_layer = level._walls_body.collision_layer
	body.collision_mask = level._walls_body.collision_mask
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(made.faces)
	shape.shape = concave
	body.add_child(shape)
	root.add_child(body)


static func _spread(root: Node3D, name: String, mesh: Mesh, material: Material, items: Array[Transform3D]) -> void:
	if items.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = items.size()
	for i in items.size():
		multi.set_instance_transform(i, items[i])
	var node := MultiMeshInstance3D.new()
	node.name = name
	node.multimesh = multi
	node.material_override = material
	# No visibility range: one multimesh spans the whole map, so its distance from the camera is that of its
	# middle, and the stones vanished from the foot as the hero walked by.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)


## Builds the foot's lobes and mounds, and strews the small things (the parts the style has) on `level`.
static func scatter(level: Outdoor) -> void:
	var old := level.get_node_or_null("MountainFoot")
	if old != null:
		level.remove_child(old)
		old.free()
	var root := Node3D.new()
	root.name = "MountainFoot"
	level.add_child(root)
	var tile := Level.TILE
	var all_mounds := mounds(level)
	var tiles := _candidates(level, all_mounds)
	# Lobes: chunks of 3 x 3 tiles.
	if has("lobes"):
		var chunk := 3
		var chunks := {}
		for c: Vector2i in tiles:
			if OPEN.contains(level.cell_char(c)):
				chunks[Vector2i(floori(float(c.x) / chunk), floori(float(c.y) / chunk))] = true
		for key: Vector2i in chunks:
			var cx := key.x * chunk
			var cy := key.y * chunk
			var box := Rect2((cx - 0.5) * tile - 1.5, (cy - 0.5) * tile - 1.5, mini(chunk, level.width - cx) * tile + 3.0, mini(chunk, level.height - cy) * tile + 3.0)
			var rects := _rects_near(level, box.get_center().x, box.get_center().y, 4)
			var height := func(x: float, z: float) -> float: return lobe_height(level, rects, x, z)
			_place_terrain(root, level, "Lobes%d_%d" % [cx, cy], _terrain(box, LOBE_STEP, height, 0.0, rects))
	for i in all_mounds.size():
		var m: Dictionary = all_mounds[i]
		var r: float = float(m.r) * 1.5
		var box := Rect2(float(m.at.x) - r, float(m.at.y) - r, r * 2.0, r * 2.0)
		var height := func(x: float, z: float) -> float: return mound_height(m, x, z)
		_place_terrain(root, level, "Mound%d" % i, _terrain(box, 0.4, height, 0.1))
	# Small things.
	var stone_part := has("stones")
	var tuft_part := has("tufts")
	var rock_part := has("rocks")
	if not (stone_part or tuft_part or rock_part):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.level_name + "fuss")
	var rocks: Array[Array] = [[], [], [], []]
	var pebbles: Array[Array] = [[], []]
	var tufts: Array[Transform3D] = []
	for c: Vector2i in tiles:
		if not OPEN.contains(level.cell_char(c)):
			continue
		var mid := level.cell_to_world(c)
		var rects := _rects_near(level, mid.x, mid.z, 3)
		var near: Array = all_mounds.filter(func(m: Dictionary) -> bool: return (m.at as Vector2).distance_to(Vector2(mid.x, mid.z)) < float(m.r) * 1.5 + 4.0 + tile)
		for i in 26:
			var at := Vector3(mid.x + rng.randf_range(-0.5, 0.5) * tile, 0.0, mid.z + rng.randf_range(-0.5, 0.5) * tile)
			var d := _dist(rects, at.x, at.z)
			var influence := 0.0
			if d < REACH:
				influence = 1.0 - d / REACH
			if d < LOBE_MAX and has("lobes"):
				influence = maxf(influence, 1.0 - smoothstep(-0.8, 2.2, d - lobe_reach(at.x, at.z)))
			for m: Dictionary in near:
				var ang := atan2(at.z - float(m.at.y), at.x - float(m.at.x))
				var edge := Vector2(at.x, at.z).distance_to(m.at) - float(m.r) * (1.0 + 0.32 * (fbm(cos(ang) * 1.4 + float(m.seed), sin(ang) * 1.4 + float(m.seed) * 0.5) * 2.0 - 1.0))
				influence = maxf(influence, 1.0 - smoothstep(-0.5, 2.2, edge))
			if influence <= 0.02:
				continue
			if clear_fade(level, at.x, at.z) < 1.0 or level.on_plot(at, 0.4):
				continue
			var ground := ground_height(level, rects, near, at.x, at.z)
			# The small things lie round the lobes and mounds, on the open ground where they show, never inside them.
			if not _bare(level, rects, near, at):
				continue
			at.y = ground
			var wander := fbm(at.x * 0.3, at.z * 0.3)
			if stone_part and rng.randf() < 0.9 * influence * (0.4 + 1.2 * wander):
				var r := rng.randf_range(0.06, 0.22)
				var tr := Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(r * rng.randf_range(1.0, 1.7), r * rng.randf_range(0.5, 0.9), r * rng.randf_range(1.0, 1.5))), at + Vector3(0, r * 0.1 - 0.02, 0))
				(pebbles[rng.randi() % 2] as Array).append(tr)
			if rock_part and rng.randf() < 0.05 * influence * (0.4 + 1.2 * wander):
				var r := rng.randf_range(0.25, 0.5)
				var tr := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3(r * rng.randf_range(0.9, 1.5), r * rng.randf_range(0.6, 1.0), r * rng.randf_range(0.9, 1.4))), at + Vector3(0, r * 0.1 - 0.03, 0))
				(rocks[rng.randi() % 4] as Array).append(tr)
			if tuft_part and ground < 0.3 and rng.randf() < 0.3 * influence * (0.3 + 1.4 * fbm(at.x * 0.5 + 9.0, at.z * 0.5)):
				var s := rng.randf_range(0.6, 1.2)
				tufts.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), at))
	var rock_mat := AgedStone.rock_material()
	for i in 4:
		var list: Array[Transform3D] = []
		list.assign(rocks[i])
		_spread(root, "Boulders%d" % i, _rock_mesh(11 + i), rock_mat, list)
	for i in 2:
		var list: Array[Transform3D] = []
		list.assign(pebbles[i])
		_spread(root, "Stones%d" % i, _rock_mesh(31 + i), rock_mat, list)
	if not tufts.is_empty():
		var grass := StandardMaterial3D.new()
		grass.vertex_color_use_as_albedo = true
		grass.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		grass.cull_mode = BaseMaterial3D.CULL_DISABLED
		grass.roughness = 1.0
		_spread(root, "Tufts", _tuft_mesh(), grass, tufts)


## Whether the ground round `at` (a stone's or tuft's reach) is free of lobes and mounds.
static func _bare(level: Outdoor, rects: Array[Rect2], near: Array, at: Vector3) -> bool:
	for off in [Vector2.ZERO, Vector2(0.6, 0), Vector2(-0.6, 0), Vector2(0, 0.6), Vector2(0, -0.6)]:
		if ground_height(level, rects, near, at.x + off.x, at.z + off.y) > 0.03:
			return false
	return true


## The height of the foot's ground (lobes and mounds) at (x, z), 0 where there is none: the fallen leaves and
## other litter lie on it (see SurfaceLife).
static func surface_at(level: Level, x: float, z: float) -> float:
	if not level is Outdoor or not (has("lobes") or has("mounds")):
		return 0.0
	var tile := Level.TILE
	var c := Vector2i(roundi(x / tile), roundi(z / tile))
	var out: Outdoor = level as Outdoor
	if not out.has_meta("foot_tiles"):
		out.set_meta("foot_tiles", _candidates(out, mounds(out)))
	if not (out.get_meta("foot_tiles") as Dictionary).has(c):
		return 0.0
	var rects := _rects_near(level, x, z, 3)
	var near: Array = mounds(out).filter(func(m: Dictionary) -> bool: return (m.at as Vector2).distance_to(Vector2(x, z)) < float(m.r) * 1.5 + 1.0)
	return ground_height(out, rects, near, x, z)


## Smooth value noise, 0..1.
static func fbm(x: float, z: float) -> float:
	if not _noise_ready:
		_noise.seed = 7
		_noise.frequency = 1.0
		_noise_ready = true
	return _noise.get_noise_2d(x, z) * 0.5 + 0.5


static var _noise := FastNoiseLite.new()
static var _noise_ready := false


## Sets the style on `level` and dresses it again (the sketches).
static func restyle(level: Outdoor, name: String) -> void:
	style = name
	level.remove_meta("foot_mounds")
	level.remove_meta("foot_tiles")
	apply(level)
	scatter(level)
	for node in level._mountain_nodes:
		if is_instance_valid(node):
			node.queue_free()
	level._mountain_nodes = Mountains.build(level, hash(level.level_name + "berge"), level._plot_areas)


## The foot dressed again after a plot was laid out beside the rock (see Outdoor).
static func rebuild(level: Outdoor) -> void:
	level.remove_meta("foot_mounds")
	level.remove_meta("foot_tiles")
	level.remove_meta("foot_field")
	apply(level)
	scatter(level)
