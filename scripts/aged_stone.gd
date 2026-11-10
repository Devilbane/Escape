class_name AgedStone
## The old stone look of the village buildings, to match the temple: the
## stone itself (shaders/aged_stone.gdshader), ivy climbing up the walls
## from the ground and bird nests up on the roofs (the birds that live in
## them are VillageBirds).
##
## Ivy and nests are found on any building's own meshes: ivy roots where a
## large, upright outer wall meets the ground (never beside the door) and
## climbs that wall, and a nest sits on the highest flat ledge (a chimney or
## a tower top). All the ivy of the village is one MultiMesh of leaves, drawn
## in one go.

const SHADER := preload("res://shaders/aged_stone.gdshader")
const TRIM := "res://assets/chapel/trim_sheet.png"
## The grain of the timber: the villagers' beams (VillageHouse.WOOD_TEX).
const WOOD_TEX := "res://assets/house/wood_floor.jpg"

## Stone tints for the villagers' houses: grey, sandstone, a warmer and a
## cooler one, picked per house.
const HOUSE_TINTS := [Color(0.80, 0.78, 0.74), Color(0.88, 0.80, 0.66), Color(0.84, 0.74, 0.64),
		Color(0.74, 0.76, 0.76), Color(0.86, 0.84, 0.78)]
## The tint of the KayKit buildings' walls.
const KIT_TINT := Color(0.84, 0.81, 0.76)

## The graveyard's stone: cool greys and one weathered sandstone, picked per
## gravestone; how much older it looks than the village; how grey the strong
## colours (the crypt's roof) have turned.
const GRAVE_TINTS := [Color(0.60, 0.61, 0.60), Color(0.66, 0.65, 0.62), Color(0.55, 0.57, 0.57),
		Color(0.70, 0.64, 0.55)]
const GRAVE_AGE := 1.5
const GRAVE_FADE := 0.75

## The mountains' rock (see rock_material): how weathered, how much lichen.
const ROCK_SHADER := preload("res://shaders/mountain_rock.gdshader")
const ROCK_AGE := 1.1
const ROCK_LICHEN := 0.35
## A colour more saturated than this is wood or metal, not stone (see
## ruin_material).
const RUIN_WOOD := 0.3

## Ivy: how many patches a building gets at most, how high they climb
## (metres above the ground), how far from the door they keep, and the
## leaves' size.
const IVY_PATCHES := 7
const IVY_HEIGHT := Vector2(3.0, 7.5)
const IVY_DOOR_GAP := 1.5
## Share of the leaves a vine keeps (the ivy is thinned by 30%), the least
## distance (metres) between two leaves, and how often a vine forks.
const IVY_KEEP := 0.62
const IVY_CAP := 0.7
const IVY_SPACING := 0.14
## Branchy ivy (the guild hall): how often a vine sends a branch out sideways,
## and for how many steps (of 0.16 m) it runs along the wall before it climbs on.
const BRANCH_RUN_CHANCE := 0.07
const BRANCH_RUN := Vector2i(10, 22)
const IVY_BRANCHING := 0.12
## The doorway itself stays free of leaves up to this height (metres) and
## this far (metres) from the door's spot, so the ivy frames a door.
const DOOR_CLEAR := Vector2(1.4, 3.6)
## The final sweep over every entrance (see clear_doors): half the width, and how far
## (metres) behind and in front of the door's spot it reaches.
const DOOR_SWEEP := 1.9
const DOOR_SWEEP_DEPTH := Vector2(3.5, 2.6)
## The side facing the camera (south) is dealt this many turns of patches
## where every other side gets one, so the fronts wear the most ivy.
const FRONT_TURNS := 3
## Leaves in one patch at most, so the whole village's ivy stays cheap.
const PATCH_LEAVES := 280
## Old ivy on the buildings that stand on their own, away from the square
## (see Outdoor._standalone): more patches, climbing up to the eaves and the
## gable tips, and from the top of the wall a little way up the roof.
const OLD_IVY_PATCHES := 8
const OLD_IVY_HEIGHT := Vector2(5.5, 11.0)
const OLD_PATCH_LEAVES := 420
const OLD_IVY_FOOT := 1.8
const OLD_IVY_FILL := 0.5
## Half the size of the clear middle of a window (across, up), in metres.
const WINDOW_CLEAR := Vector2(0.6, 0.7)
## How far (metres) round a glass window the ivy keeps off.
const GLASS_CLEAR := 0.45
## The share of leaves kept in the outer ring of a window's extra clear room.
const STRAND_KEEP := 0.25
## How far (metres, along the slope) old ivy creeps up a roof, and the
## steepest a roof may be (its normal's y at least) to be crept on.
const ROOF_CREEP := Vector2(0.5, 2.0)
const ROOF_SLOPE := 0.25
const LEAF_SIZE := Vector2(0.3, 0.46)
## The smallest wall (square metres) ivy grows on.
const IVY_WALL := 0.6
## How many times the leaves of a building's one side all its sides together get.
const IVY_TOTAL_SHARE := 1.2
## Shades of the leaves: mostly dark green, now and then an autumn red.
const LEAF_COLOURS := [Color(0.22, 0.36, 0.14), Color(0.17, 0.29, 0.11), Color(0.28, 0.42, 0.16),
		Color(0.20, 0.33, 0.17), Color(0.36, 0.40, 0.14), Color(0.48, 0.22, 0.12)]

## A nest needs a ledge at least this high over the ground (metres) and
## this large (square metres).
const NEST_HEIGHT := 3.5
const NEST_LEDGE := 0.2

static var _mats := {}
static var _grained := {}


## The aged stone for a KayKit building, from its palette texture. Its
## windows (white on `windows`) glow with set_shader_parameter("glow", ...).
static func kit_material(palette: Texture2D, windows: Texture2D) -> ShaderMaterial:
	var key := "kit_%d" % (palette.get_instance_id() if palette else 0)
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("palette", palette)
		mat.set_shader_parameter("use_palette", true)
		mat.set_shader_parameter("tint", KIT_TINT)
		mat.set_shader_parameter("trim", load(TRIM))
		mat.set_shader_parameter("glow_mask", windows)
		mat.set_shader_parameter("soft_joints", 1.0)
		mat.set_shader_parameter("uneven_roofs", 1.0)
		mat.set_shader_parameter("wood_tex", load(WOOD_TEX))
		mat.set_shader_parameter("wood_grain", 1.0)
		_mats[key] = mat
	return _mats[key]


## A KayKit building's mesh with the direction of its wood's grain: each
## triangle's vertex colour holds the way its beam runs (rgb, as dir * 0.5 +
## 0.5; alpha 0.5 marks it), which the shader lays the grain along. A beam's
## face is a long rectangle cut into two triangles; the longer of the two
## edges that are not the diagonal runs along the beam, on its sides as well
## as on its front. Made once per mesh and shared.
static func grained_mesh(mesh: Mesh) -> Mesh:
	if mesh == null:
		return mesh
	var key := mesh.get_instance_id()
	if _grained.has(key):
		return _grained[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var mat := mesh.surface_get_material(s)
		if arrays[Mesh.ARRAY_BONES] != null or mesh.surface_get_blend_shape_arrays(s).size() > 0:
			out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
			out.surface_set_material(out.get_surface_count() - 1, mat)
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() if idx.size() > 0 else verts.size()
		var order := PackedInt32Array()
		order.resize(count)
		for i in count:
			order[i] = idx[i] if idx.size() > 0 else i
		var flat := []
		flat.resize(Mesh.ARRAY_MAX)
		flat[Mesh.ARRAY_VERTEX] = _pick_v3(verts, order)
		if arrays[Mesh.ARRAY_NORMAL] != null:
			flat[Mesh.ARRAY_NORMAL] = _pick_v3(arrays[Mesh.ARRAY_NORMAL], order)
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tan: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var t2 := PackedFloat32Array()
			t2.resize(count * 4)
			for i in count:
				for k in 4:
					t2[i * 4 + k] = tan[order[i] * 4 + k]
			flat[Mesh.ARRAY_TANGENT] = t2
		for uv_slot in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			if arrays[uv_slot] != null:
				var uvs: PackedVector2Array = arrays[uv_slot]
				var u2 := PackedVector2Array()
				u2.resize(count)
				for i in count:
					u2[i] = uvs[order[i]]
				flat[uv_slot] = u2
		var cols := PackedColorArray()
		cols.resize(count)
		var pos: PackedVector3Array = flat[Mesh.ARRAY_VERTEX]
		for t in range(0, count - 2, 3):
			var d := grain_of(pos[t], pos[t + 1], pos[t + 2])
			var c := Color(d.x * 0.5 + 0.5, d.y * 0.5 + 0.5, d.z * 0.5 + 0.5, 0.5)
			cols[t] = c
			cols[t + 1] = c
			cols[t + 2] = c
		flat[Mesh.ARRAY_COLOR] = cols
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flat)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	_grained[key] = out
	return out


## The way the grain runs on a triangle: along the longer of its two edges
## that are not the longest one (the diagonal of a rectangle).
static func grain_of(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var edges := [b - a, c - b, a - c]
	edges.sort_custom(func(x: Vector3, y: Vector3) -> bool: return x.length_squared() > y.length_squared())
	var e: Vector3 = edges[1]
	return e.normalized() if e.length_squared() > 0.0 else Vector3.RIGHT


static func _pick_v3(src: PackedVector3Array, order: PackedInt32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(order.size())
	for i in order.size():
		out[i] = src[order[i]]
	return out


## The aged stone of a villager's house walls, in one tint.
static func house_material(tint: Color) -> ShaderMaterial:
	var key := "house_%s" % tint.to_html()
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("use_palette", false)
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("trim", load(TRIM))
		mat.set_shader_parameter("soft_joints", 1.0)
		_mats[key] = mat
	return _mats[key]


## The graveyard's old stone (the KayKit Halloween models, which share one
## palette texture): older than the village, greyer, mossier, and the roof
## of the crypt faded to the grey of old slate. Gravestones (`hewn`) are cut
## from one piece and crusted with lichen; the crypt and the fence's low wall
## are laid in blocks. `shade` picks one of GRAVE_TINTS. With `glowing`
## (white where the palette glows, see the kit's windows), it is a material of
## its own.
static func grave_material(palette: Texture2D, hewn: bool, shade := 0, glowing: Texture2D = null) -> ShaderMaterial:
	var key := "grave_%d_%d_%d_%d" % [palette.get_instance_id() if palette else 0, int(hewn), shade,
			glowing.get_instance_id() if glowing else 0]
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("palette", palette)
		mat.set_shader_parameter("use_palette", true)
		mat.set_shader_parameter("tint", GRAVE_TINTS[shade % GRAVE_TINTS.size()])
		mat.set_shader_parameter("trim", load(TRIM))
		mat.set_shader_parameter("age", GRAVE_AGE)
		mat.set_shader_parameter("fade", GRAVE_FADE)
		mat.set_shader_parameter("blocks", 0.0 if hewn else 1.0)
		mat.set_shader_parameter("lichen", 1.0 if hewn else 0.4)
		if glowing:
			mat.set_shader_parameter("glow_mask", glowing)
		_mats[key] = mat
	return _mats[key]


## The weathered rock of the mountains (Mountains, LairMountain): their own
## painted faces with grain, strata, grime, rain streaks, moss and lichen laid
## over them (shaders/mountain_rock.gdshader), so the rock looks as old as
## the village stone. One material for all of them.
static func rock_material() -> ShaderMaterial:
	if not _mats.has("rock"):
		var mat := ShaderMaterial.new()
		mat.shader = ROCK_SHADER
		mat.set_shader_parameter("age", ROCK_AGE)
		mat.set_shader_parameter("lichen", ROCK_LICHEN)
		_mats["rock"] = mat
	return _mats["rock"]


## Old stone for a model that comes in plain colours (the dungeon kit's
## arch, columns and stairs at the dragon's lair): each colour greyed towards
## the graveyard's stone and hewn (the models carve their own blocks), as
## old as the graveyard. Strong colours (the wooden door) keep more of their
## own colour.
static func ruin_material(colour: Color) -> ShaderMaterial:
	var key := "ruin_%s" % colour.to_html()
	if not _mats.has(key):
		var l := colour.r * 0.3 + colour.g * 0.55 + colour.b * 0.15
		var hi := maxf(colour.r, maxf(colour.g, colour.b))
		var sat := (hi - minf(colour.r, minf(colour.g, colour.b))) / hi if hi > 0.001 else 0.0
		var stone: Color = GRAVE_TINTS[0]
		# Grey stone loses its own hue; wood and metal only fade.
		var tint := Color(l, l, l).lerp(colour, 0.55 if sat > RUIN_WOOD else 0.2)
		tint = tint.lerp(stone * (l / 0.6), 0.0 if sat > RUIN_WOOD else 0.5)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("use_palette", false)
		mat.set_shader_parameter("tint", Color(clampf(tint.r, 0, 1), clampf(tint.g, 0, 1), clampf(tint.b, 0, 1)))
		mat.set_shader_parameter("trim", load(TRIM))
		mat.set_shader_parameter("age", GRAVE_AGE)
		mat.set_shader_parameter("blocks", 0.0)
		mat.set_shader_parameter("lichen", 0.0 if sat > RUIN_WOOD else 0.35)
		_mats[key] = mat
	return _mats[key]


## Old timber for a plain-coloured wooden piece (the mine entrances' frames):
## the villagers' grain laid over the colour, faded and weathered like the
## rest of the old stone.
static func timber_material(colour: Color) -> ShaderMaterial:
	var key := "timber_%s" % colour.to_html()
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("use_palette", false)
		mat.set_shader_parameter("tint", colour)
		mat.set_shader_parameter("trim", load(TRIM))
		mat.set_shader_parameter("age", GRAVE_AGE)
		mat.set_shader_parameter("blocks", 0.0)
		mat.set_shader_parameter("lichen", 0.0)
		mat.set_shader_parameter("wood_tex", load(WOOD_TEX))
		mat.set_shader_parameter("wood_grain", 1.0)
		_mats[key] = mat
	return _mats[key]


# --- Finding walls and ledges -----------------------------------------------

## Every triangle a building shows, in world space: corners, normal, area.
## The building must be in the scene tree already.
static func triangles(node: Node3D) -> Array:
	var out: Array = []
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf := mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var glass := mat != null and mat.resource_name.begins_with("window")
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var count := idx.size() if idx.size() > 0 else verts.size()
			for t in range(0, count - 2, 3):
				var i0 := idx[t] if idx.size() > 0 else t
				var i1 := idx[t + 1] if idx.size() > 0 else t + 1
				var i2 := idx[t + 2] if idx.size() > 0 else t + 2
				var a := xf * verts[i0]
				var b := xf * verts[i1]
				var c := xf * verts[i2]
				var cr := (b - a).cross(c - a)
				var area := cr.length() * 0.5
				if area < 0.01:
					continue
				# Outwards, the way the mesh's own normals point (Godot's
				# front faces run clockwise, against the right-hand rule).
				var n := -cr.normalized()
				if normals.size() > 0 and (xf.basis * (normals[i0] + normals[i1] + normals[i2])).dot(n) < 0.0:
					n = -n
				var tri := {"a": a, "b": b, "c": c, "n": n, "area": area}
				if glass:
					tri["glass"] = true
				if uvs.size() > 0:
					tri["uv"] = (uvs[i0] + uvs[i1] + uvs[i2]) / 3.0
				out.append(tri)
	return out


## The upright outer walls, merged by plane: each is {"n", "d" (plane
## offset), "tris", "area", "foot", "top"}. Only those that stand on the
## ground are roots for ivy (see rooted); it climbs on to the others.
static func walls(tris: Array, middle: Vector3, ground: float) -> Array:
	var planes: Array = []
	for t: Dictionary in tris:
		var n: Vector3 = t.n
		if absf(n.y) > 0.12:
			continue
		var centre: Vector3 = (t.a + t.b + t.c) / 3.0
		var flat_out := Vector2(centre.x - middle.x, centre.z - middle.z)
		if flat_out.dot(Vector2(n.x, n.z)) <= 0.0:
			continue
		var d := n.dot(t.a)
		var plane: Dictionary = {}
		for p: Dictionary in planes:
			if (p.n as Vector3).dot(n) > 0.99 and absf(float(p.d) - d) < 0.06:
				plane = p
				break
		if plane.is_empty():
			plane = {"n": n, "d": d, "tris": [], "area": 0.0, "foot": INF, "top": -INF,
					"across": Vector3.UP.cross(n).normalized(), "flat": PackedVector2Array(), "rect": Rect2()}
			planes.append(plane)
		plane.tris.append(t)
		# The triangle laid flat on its wall (across, up), for quick tests.
		var across: Vector3 = plane.across
		for q: Vector3 in [t.a, t.b, t.c]:
			var f := Vector2(q.dot(across), q.y)
			plane.flat.append(f)
			plane.rect = Rect2(f, Vector2.ZERO) if plane.flat.size() == 1 else (plane.rect as Rect2).expand(f)
		plane.area += t.area
		plane.foot = minf(plane.foot, minf(t.a.y, minf(t.b.y, t.c.y)))
		plane.top = maxf(plane.top, maxf(t.a.y, maxf(t.b.y, t.c.y)))
	return planes.filter(func(p): return p.area >= 0.3)


## Old ivy also roots on walls that stand on a stone base (the KayKit
## buildings' walls start this high over the ground), growing out of the
## base's ledge.
static func rooted(planes: Array, ground: float, old := false, foot_max := 0.0) -> Array:
	var foot := maxf(foot_max, OLD_IVY_FOOT if old else 0.9)
	return planes.filter(func(p): return p.area >= IVY_WALL and p.foot < ground + foot and p.top > ground + 1.6)


## The highest flat ledge high up, where a nest can sit (INF if none).
static func nest_spot(tris: Array, ground: float) -> Vector3:
	var best := Vector3.INF
	for t: Dictionary in tris:
		if (t.n as Vector3).y < 0.85 or t.area < NEST_LEDGE:
			continue
		var centre: Vector3 = (t.a + t.b + t.c) / 3.0
		if centre.y < ground + NEST_HEIGHT:
			continue
		if best == Vector3.INF or centre.y > best.y:
			best = centre
	return best


## Whether a point (on the wall's plane) lies on the wall.
static func _on_wall(wall: Dictionary, p: Vector3) -> bool:
	var q := Vector2(p.dot(wall.across), p.y)
	if not (wall.rect as Rect2).grow(0.01).has_point(q):
		return false
	var flat: PackedVector2Array = wall.flat
	for i in range(0, flat.size(), 3):
		if Geometry2D.point_is_inside_triangle(q, flat[i], flat[i + 1], flat[i + 2]):
			return true
	return false


# --- Ivy -----------------------------------------------------------------------

## Grows ivy up a building's outer walls: leaves (transforms and colours) are
## added to `leaves`. `doors` are the spots in front of its doors, where no
## ivy grows. `old` ivy climbs much higher, up to the roof and on to it.
## `proud` holds the leaves out from walls whose stones stand proud of their plane (the castle's).
## `foot_max` lets ivy root on walls standing that high (the castle's towers
## start well above the ground). `windows` are the middles of window panes (world space): their middle
## stays clear of leaves, so the ivy frames a window but never covers it.
static func grow_ivy(tris: Array, middle: Vector3, ground: float, doors: Array, rng: RandomNumberGenerator, leaves: Dictionary, patches := IVY_PATCHES, old := false, windows: Array = [], foot_max := 0.0, proud := 0.0, window_room := 1.0, all_sides := false) -> void:
	var all_walls := walls(tris, middle, ground)
	var found := rooted(all_walls, ground, old, foot_max)
	# A wall up on a stone base that looks the way a door does holds that
	# door up there too (the KayKit buildings): no ivy grows from its foot.
	# (`all_sides`, the guild hall: its entrance wall wears ivy too, the gate itself stays clear.)
	found = found.filter(func(w): return all_sides or float(w.foot) < ground + 0.9 or foot_max > 0.0 or not doors.any(
			func(d: Vector3): return Vector2(d.x - middle.x, d.z - middle.z).normalized().dot(Vector2(w.n.x, w.n.z)) > 0.7))
	if found.is_empty():
		return
	# The roof's sloping faces, for old ivy to creep on to.
	var roofs: Array = []
	if old:
		roofs = tris.filter(func(t): return (t.n as Vector3).y > ROOF_SLOPE and (t.n as Vector3).y < 0.97 and t.c.y > ground + 2.0)
	# The sides of the building (walls looking the same way), the one facing
	# the camera (south) first: the patches are dealt round them one by one, so
	# every side of the building gets its share, not only the front.
	var sides: Array = []
	for w: Dictionary in found:
		var side: Array = []
		for s: Array in sides:
			if ((s[0] as Dictionary).n as Vector3).dot(w.n) > 0.9:
				side = s
				break
		if side.is_empty():
			sides.append([w])
		else:
			side.append(w)
	# The camera looks north from the south: a side turned right away from it
	# is never seen, so it grows no ivy (unless it is all there is).
	var seen := sides.filter(func(s: Array): return all_sides or ((s[0] as Dictionary).n as Vector3).z > -0.7)
	if not seen.is_empty():
		sides = seen
	sides.sort_custom(func(a: Array, b: Array): return (a[0].n as Vector3).z > (b[0].n as Vector3).z)
	# Every side gets as many patches as a building had on its one side before.
	patches *= sides.size()
	# Every side gets its patches, but each patch is thinner (fewer, larger
	# leaves), so the whole building wears about 1.2 times the leaves it had
	# on its one side and the village's leaf count stays near its old budget.
	# The turns: every side once, the front side (sorted first, if it faces
	# the camera) FRONT_TURNS times.
	var deal: Array = []
	for i in sides.size():
		var side0: Array = sides[i]
		deal.append(i)
		if i == 0 and not all_sides and (side0[0].n as Vector3).z > 0.5:
			for k in FRONT_TURNS - 1:
				deal.append(0)
	patches = patches * deal.size() / maxi(sides.size(), 1)
	var thin := minf(1.0, IVY_TOTAL_SHARE * 1.25 / float(deal.size()))
	var grown := 0
	for attempt in patches * 6:
		if grown >= patches:
			break
		# A wall of the side whose turn it is, by its size.
		var side: Array = sides[deal[attempt % deal.size()]]
		var side_area := 0.0
		for w: Dictionary in side:
			side_area += w.area
		var pick := rng.randf() * side_area
		var wall: Dictionary = side[-1]
		for w: Dictionary in side:
			pick -= w.area
			if pick <= 0.0:
				wall = w
				break
		var root: Vector3 = _root_on(wall, ground, rng)
		if root == Vector3.INF:
			continue
		# (Only a root down by the door is kept away: one high up on a tower above it is fine.)
		if root.y < ground + DOOR_CLEAR.y and doors.any(func(d: Vector3): return Vector2(d.x - root.x, d.z - root.z).length() < IVY_DOOR_GAP):
			continue
		_grow_patch(wall, all_walls, root, ground, rng, leaves, old, roofs, windows, thin, doors, proud, window_room, all_sides)
		grown += 1


## A spot at the foot of the wall, a little above the ground.
static func _root_on(wall: Dictionary, ground: float, rng: RandomNumberGenerator) -> Vector3:
	var n: Vector3 = wall.n
	var across := Vector3.UP.cross(n).normalized()
	var lo := INF
	var hi := -INF
	for t: Dictionary in wall.tris:
		for p: Vector3 in [t.a, t.b, t.c]:
			lo = minf(lo, p.dot(across))
			hi = maxf(hi, p.dot(across))
	var on_plane: Vector3 = n * float(wall.d)
	for i in 8:
		var s := rng.randf_range(lo + 0.4, hi - 0.4)
		var p := on_plane - across * on_plane.dot(across) + across * s
		p.y = maxf(float(wall.foot), ground) + 0.15
		if _on_wall(wall, p):
			return p
	return Vector3.INF


## A few tendrils climb from the root, wandering a little sideways and now
## and then branching; leaves grow along them, thickest near the ground.
## Old ivy climbs higher, and a tendril that runs out of wall below its
## reach creeps on up the roof above it.
static func _grow_patch(root_wall: Dictionary, all_walls: Array, root: Vector3, ground: float, rng: RandomNumberGenerator, leaves: Dictionary, old := false, roofs: Array = [], windows: Array = [], thin := 1.0, doors: Array = [], proud := 0.0, window_room := 1.0, branchy := false) -> void:
	var n: Vector3 = root_wall.n
	var across := Vector3.UP.cross(n).normalized()
	var height: Vector2 = OLD_IVY_HEIGHT if old else IVY_HEIGHT
	# Ivy rooted high up a wall (the castle's towers) climbs on from there.
	var base := root.y - 0.15 if root.y > ground + OLD_IVY_FOOT else ground
	var reach := base + rng.randf_range(height.x, height.y)
	var most: int = int((OLD_PATCH_LEAVES if old else PATCH_LEAVES) * thin * IVY_CAP)
	var bigger := 1.0 / sqrt(thin)
	# The walls in line with this one: the ivy climbs on up them where one
	# ends (a jutting upper floor, a ledge).
	var line := all_walls.filter(func(w): return (w.n as Vector3).dot(n) > 0.99)
	var tips: Array = []
	for i in (rng.randi_range(4, 7) if old else rng.randi_range(3, 5)):
		tips.append({"p": root + across * rng.randf_range(-0.6, 0.6), "drift": rng.randf_range(-0.6, 0.6), "wall": root_wall})
	var steps := 0
	var side_flip := 1.0
	var first: int = leaves.xforms.size()
	while not tips.is_empty() and steps < 600 and leaves.xforms.size() - first < most:
		steps += 1
		var tip: Dictionary = tips.pop_back()
		var p: Vector3 = tip.p
		var drift: float = tip.drift
		var wall: Dictionary = tip.wall
		# A runner (see BRANCH_RUN) first creeps sideways along the wall, rising a
		# little, then climbs on like any tendril.
		var run: int = tip.get("run", 0)
		var run_dir: float = tip.get("dir", 1.0)
		while p.y < reach:
			drift = clampf(drift + rng.randf_range(-0.35, 0.35), -0.9, 0.9)
			var next := p + Vector3.UP * 0.16 + across * drift * 0.1
			if run > 0:
				run -= 1
				next = p + across * run_dir * 0.16 + Vector3.UP * rng.randf_range(0.02, 0.07)
			if not _on_wall(wall, next):
				# Round the edge of a window or the wall: try straight up,
				# then on to a wall in line just above.
				next = p + Vector3.UP * 0.16
				if not _on_wall(wall, next):
					var hop := _wall_at(line, next)
					if hop.is_empty():
						if not roofs.is_empty() and p.y > ground + 3.0:
							_creep_roof(p, n, roofs, rng, leaves)
						break
					wall = hop
					next = next + n * (float(wall.d) - n.dot(next))
			p = next
			# Fuller near the ground, sparse at the top.
			var fill := clampf(1.0 - (p.y - base) / maxf(reach - base, 0.5), 0.0, 1.0)
			# Old ivy stays thick a long way up.
			if old:
				fill = maxf(fill, OLD_IVY_FILL)
			# Leaves sit along the vine, alternately to its left and right like
			# the leaves on a real shoot, and never on top of one another.
			side_flip = -side_flip
			for k in (2 if rng.randf() < fill * 0.5 else 1):
				var at := p + across * (side_flip * rng.randf_range(0.06, 0.22)) + Vector3.UP * (rng.randf_range(-0.05, 0.05) + k * 0.08)
				if rng.randf() < thin * IVY_KEEP and _on_wall(wall, at) and not _on_pane(at, n, windows) and not _in_window_room(at, n, windows, window_room, rng) and not _in_doorway(at, doors, ground) and not _crowded(at, leaves, first):
					_leaf(at + n * proud, n, across, rng, leaves, (0.75 + fill * 0.35) * bigger)
			if branchy and run == 0 and rng.randf() < BRANCH_RUN_CHANCE and tips.size() < 10:
				# A branch growing out sideways, and a tendril going up from its end.
				tips.append({"p": p, "drift": 0.0, "wall": wall, "run": rng.randi_range(BRANCH_RUN.x, BRANCH_RUN.y), "dir": 1.0 if rng.randf() < 0.5 else -1.0})
			elif rng.randf() < IVY_BRANCHING and tips.size() < 8:
				tips.append({"p": p, "drift": -drift, "wall": wall})


## Whether a leaf already lies this close to `at` among the patch's own
## leaves (from index `first` on), so leaves never pile up.
static func _crowded(at: Vector3, leaves: Dictionary, first: int) -> bool:
	var xf: Array = leaves.xforms
	for i in range(xf.size() - 1, maxi(first, xf.size() - 40) - 1, -1):
		if ((xf[i] as Transform3D).origin).distance_squared_to(at) < IVY_SPACING * IVY_SPACING:
			return true
	return false


## The last word on doors: drops every leaf standing in the doorway of any entrance
## (`doors`: dictionaries with `door` and `out`, in the same space as the leaves), whichever
## building grew it. The box is DOOR_SWEEP wide on each side, reaches DOOR_SWEEP_DEPTH
## behind the door's spot and in front of it, and DOOR_CLEAR.y high. Returns how many it dropped.
static func clear_doors(leaves: Dictionary, doors: Array) -> int:
	var dropped := 0
	var keep_x := []
	var keep_c := []
	for i in leaves.xforms.size():
		var at: Vector3 = (leaves.xforms[i] as Transform3D).origin
		var blocked := false
		for e: Dictionary in doors:
			var d: Vector3 = e.door
			var out: Vector3 = e.out
			var rel := Vector3(at.x - d.x, 0, at.z - d.z)
			var along := rel.dot(out)
			var across := absf(rel.dot(Vector3.UP.cross(out)))
			if across < DOOR_SWEEP and along > -DOOR_SWEEP_DEPTH.x and along < DOOR_SWEEP_DEPTH.y and at.y - d.y < DOOR_CLEAR.y:
				blocked = true
				break
		if blocked:
			dropped += 1
		else:
			keep_x.append(leaves.xforms[i])
			keep_c.append(leaves.colours[i])
	leaves.xforms = keep_x
	leaves.colours = keep_c
	return dropped


## Whether a leaf's spot is in a doorway (see DOOR_CLEAR).
static func _in_doorway(at: Vector3, doors: Array, ground: float) -> bool:
	for d: Vector3 in doors:
		if Vector2(at.x - d.x, at.z - d.z).length() < DOOR_CLEAR.x and at.y - ground < DOOR_CLEAR.y:
			return true
	return false


## Old ivy over the eaves: from the top of a wall (`p`, the wall looking
## along `n`) out under the overhang and on to the roof above, then a little
## way up its slope, the leaves lying flat on the tiles and thinning out.
static func _creep_roof(p: Vector3, n: Vector3, roofs: Array, rng: RandomNumberGenerator, leaves: Dictionary) -> void:
	# Only the roof faces close by are worth testing.
	var near := roofs.filter(func(t): return _near_xz(t, p, 3.0))
	if near.is_empty():
		return
	var on := {}
	for out in [0.1, 0.3, 0.5, 0.7, 0.9]:
		on = _roof_at(near, p + n * out, p.y - 0.2, p.y + 1.6)
		if not on.is_empty():
			break
	if on.is_empty():
		return
	var rn: Vector3 = on.n
	var along := Vector3.UP.cross(rn)
	along = along.normalized() if along.length() > 0.01 else Vector3.RIGHT
	var at: Vector3 = on.p
	# The wall meets the roof under its overhang: go down the slope to the
	# eaves' edge, so the ivy runs on from the wall without a bare strip.
	var downhill := -(Vector3.UP - rn * rn.y).normalized()
	var under := 0.0
	for i in 10:
		var lower := _roof_at(near, at + downhill * 0.1, at.y - 0.4, at.y + 0.1)
		if lower.is_empty():
			break
		at = lower.p
		under += 0.1
	# Over the edge: leaves hang down the eaves' edge, facing out like the
	# wall's, then turn on to the roof.
	var eave_across := Vector3.UP.cross(n).normalized()
	for k in 4:
		var spot := at + n * 0.08 + eave_across * rng.randf_range(-0.2, 0.2) - Vector3.UP * (0.08 + k * 0.12)
		_leaf(spot, n.lerp(rn, 0.3).normalized(), eave_across, rng, leaves, 0.95)
	var length := under + rng.randf_range(ROOF_CREEP.x, ROOF_CREEP.y)
	var drift := rng.randf_range(-0.5, 0.5)
	var went := 0.0
	while went < length:
		var fill := 1.0 - went / length
		for k in rng.randi_range(1, 2):
			var spot := at + along * rng.randf_range(-0.2, 0.2)
			_leaf(spot, rn, along, rng, leaves, 0.75 + fill * 0.3)
		# Up the slope (the roof's own up), wandering a little sideways.
		var up := (Vector3.UP - rn * rn.y).normalized()
		drift = clampf(drift + rng.randf_range(-0.3, 0.3), -0.8, 0.8)
		var next := at + up * 0.16 + along * drift * 0.08
		var still := _roof_at(near, next, next.y - 0.3, next.y + 0.3)
		if still.is_empty():
			break
		at = still.p
		rn = still.n
		went += 0.16


## The middles of the window panes of a building that has no list of them
## (the KayKit buildings): the pane triangles are the ones whose texture
## coordinates lie on the palette's window patch (`window_uv`); those close
## together are one pane.
static func window_panes(tris: Array, window_uv: Vector2) -> Array:
	var panes: Array = []
	for t: Dictionary in tris:
		if not t.has("uv") or (t.uv as Vector2).distance_to(window_uv) > 0.03:
			continue
		var centre: Vector3 = (t.a + t.b + t.c) / 3.0
		if not panes.any(func(p: Vector3): return p.distance_to(centre) < 0.9):
			panes.append(centre)
	return panes


## The boxes round the windows that are modelled as glass surfaces (the
## temple's tall windows): the glass triangles, grouped by where they touch.
## Leaves keep out of them (see _on_pane).
static func glass_boxes(tris: Array) -> Array:
	var boxes: Array = []
	for t: Dictionary in tris:
		if not t.has("glass"):
			continue
		var box := AABB(t.a, Vector3.ZERO).expand(t.b).expand(t.c)
		var merged := false
		for i in boxes.size():
			if (boxes[i] as AABB).grow(0.3).intersects(box):
				boxes[i] = (boxes[i] as AABB).merge(box)
				merged = true
				break
		if not merged:
			boxes.append(box)
	return boxes


## Whether a spot on a wall facing `n` lies over the middle of a window
## pane (a leaf there would hide it; the frame and shutters may be grown
## over). The leaf's own size reaches a little further.
static func _on_pane(at: Vector3, n: Vector3, windows: Array) -> bool:
	for win in windows:
		if win is AABB:
			if (win as AABB).grow(GLASS_CLEAR).has_point(at):
				return true
			continue
		var w: Vector3 = win
		var d := at - w
		if absf(d.dot(n)) > 0.5:
			continue
		var side := d - n * d.dot(n)
		if absf(side.y) < WINDOW_CLEAR.y and Vector2(side.x, side.z).length() < WINDOW_CLEAR.x:
			return true
	return false


## Extra room round the windows (`room` times the usual clearance): leaves keep
## off the inner part completely, and only now and then reach into the outer
## ring, so a window is left free with a few strands at its edges.
static func _in_window_room(at: Vector3, n: Vector3, windows: Array, room: float, rng: RandomNumberGenerator) -> bool:
	if room <= 1.0:
		return false
	for win in windows:
		if win is AABB:
			var outer := (win as AABB).grow(GLASS_CLEAR * room)
			if outer.has_point(at):
				return (win as AABB).grow(GLASS_CLEAR * (1.0 + (room - 1.0) * 0.5)).has_point(at) or rng.randf() > STRAND_KEEP
			continue
		var d: Vector3 = at - (win as Vector3)
		if absf(d.dot(n)) > 0.5:
			continue
		var side := d - n * d.dot(n)
		var across := Vector2(side.x, side.z).length() / (WINDOW_CLEAR.x * room)
		var up := absf(side.y) / (WINDOW_CLEAR.y * room)
		if across < 1.0 and up < 1.0:
			return maxf(across, up) < 0.6 or rng.randf() > STRAND_KEEP
	return false


## Whether a triangle's corners come within `r` (across the ground) of `p`.
static func _near_xz(t: Dictionary, p: Vector3, r: float) -> bool:
	var lo := Vector2(minf(t.a.x, minf(t.b.x, t.c.x)), minf(t.a.z, minf(t.b.z, t.c.z)))
	var hi := Vector2(maxf(t.a.x, maxf(t.b.x, t.c.x)), maxf(t.a.z, maxf(t.b.z, t.c.z)))
	return p.x > lo.x - r and p.x < hi.x + r and p.z > lo.y - r and p.z < hi.y + r


## The highest roof face straight above or below `p` with its surface
## between `lo` and `hi`: {"p" (the spot on it), "n"}, or empty.
static func _roof_at(roofs: Array, p: Vector3, lo: float, hi: float) -> Dictionary:
	var best := {}
	var q := Vector2(p.x, p.z)
	for t: Dictionary in roofs:
		var tn: Vector3 = t.n
		if not Geometry2D.point_is_inside_triangle(q, Vector2(t.a.x, t.a.z), Vector2(t.b.x, t.b.z), Vector2(t.c.x, t.c.z)):
			continue
		# The face's height at this spot, from its plane.
		var y: float = t.a.y - (tn.x * (p.x - t.a.x) + tn.z * (p.z - t.a.z)) / tn.y
		if y < lo or y > hi or (not best.is_empty() and y <= float(best.p.y)):
			continue
		best = {"p": Vector3(p.x, y, p.z), "n": tn}
	return best


## The wall in line on which a point (moved on to its plane) lies.
static func _wall_at(line: Array, p: Vector3) -> Dictionary:
	for w: Dictionary in line:
		var n: Vector3 = w.n
		var on := p + n * (float(w.d) - n.dot(p))
		if on.distance_to(p) < 0.7 and _on_wall(w, on):
			return w
	return {}


static func _leaf(at: Vector3, n: Vector3, across: Vector3, rng: RandomNumberGenerator, leaves: Dictionary, size: float) -> void:
	# The leaf's face looks out from the wall, tipped a little up or to the
	# side, and turned at random about its stem.
	var s := rng.randf_range(LEAF_SIZE.x, LEAF_SIZE.y) * size
	var b := Basis(across, n.cross(across), n)
	b = b.rotated(n, rng.randf_range(-PI, PI))
	b = b.rotated(across, rng.randf_range(-0.5, 0.2))
	leaves.xforms.append(Transform3D(b.scaled(Vector3(s, s, s)), at + n * rng.randf_range(0.04, 0.11)))
	var c: Color = LEAF_COLOURS[rng.randi() % (LEAF_COLOURS.size() if rng.randf() < 0.12 else LEAF_COLOURS.size() - 1)]
	leaves.colours.append(c * rng.randf_range(0.85, 1.15))


## A round shrub of ivy-like leaves standing on the ground at `at`, now
## and then in flower. Its leaves join the ivy's (one MultiMesh for both).
static func grow_bush(at: Vector3, rng: RandomNumberGenerator, leaves: Dictionary) -> void:
	var radius := rng.randf_range(0.8, 1.5)
	var tall := radius * rng.randf_range(0.7, 1.05)
	var count := int(50 + radius * 80)
	var flowers: Color = [Color(0.9, 0.5, 0.6), Color(0.95, 0.9, 0.85), Color(0.95, 0.8, 0.3), Color(0.7, 0.55, 0.9)][rng.randi() % 4]
	var in_flower := rng.randf() < 0.35
	for i in count:
		# A spot on the dome, the leaf looking out from its middle.
		var a := rng.randf() * TAU
		var up := sqrt(rng.randf())
		var out := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up)).normalized()
		var p := at + Vector3(out.x * radius, out.y * tall + 0.05, out.z * radius) * rng.randf_range(0.55, 1.0)
		var across := Vector3.UP.cross(out)
		across = across.normalized() if across.length() > 0.01 else Vector3.RIGHT
		var s := rng.randf_range(LEAF_SIZE.x, LEAF_SIZE.y) * 1.5
		var b := Basis(across, out.cross(across), out).rotated(out, rng.randf_range(-PI, PI))
		leaves.xforms.append(Transform3D(b.scaled(Vector3(s, s, s)), p))
		var c: Color = LEAF_COLOURS[rng.randi() % (LEAF_COLOURS.size() - 1)] * rng.randf_range(0.8, 1.1)
		if in_flower and out.y > 0.3 and rng.randf() < 0.18:
			c = flowers * rng.randf_range(0.85, 1.05)
		leaves.colours.append(c)


## A little ivy on a round basin (the village fountain) standing on the ground
## at `at`: a few light clumps that cling to the outside of the wall from the
## foot up, and one or two that spill over the rim. Its leaves join the ivy's.
static func grow_basin_ivy(at: Vector3, wall_radius: float, wall_top: float, rng: RandomNumberGenerator, leaves: Dictionary, clumps := 3) -> void:
	var start := rng.randf() * TAU
	for k in clumps:
		var a := start + TAU * float(k) / clumps + rng.randf_range(-0.4, 0.4)
		var spread := rng.randf_range(0.18, 0.3)
		var height := rng.randf_range(0.45, 1.0) * wall_top
		for i in rng.randi_range(22, 36):
			# Thickest at the foot, thinning out up the wall; the odd leaf
			# over the rim.
			var h := wall_top * pow(rng.randf(), 1.6) * (height / wall_top)
			var over := rng.randf() < 0.08
			var ang := a + rng.randf_range(-spread, spread) * (1.0 - h / (wall_top + 0.01) * 0.5)
			var out := Vector3(cos(ang), 0.0, sin(ang))
			var normal := (out + Vector3(0, 0.15 if not over else 0.8, 0)).normalized()
			var p := at + out * (wall_radius + 0.04) + Vector3(0, h + 0.1 if not over else wall_top + 0.05, 0)
			var across := Vector3.UP.cross(normal).normalized()
			var s := rng.randf_range(LEAF_SIZE.x, LEAF_SIZE.y)
			var b := Basis(across, normal.cross(across), normal).rotated(normal, rng.randf_range(-PI, PI))
			leaves.xforms.append(Transform3D(b.scaled(Vector3(s, s, s)), p))
			leaves.colours.append(LEAF_COLOURS[rng.randi() % (LEAF_COLOURS.size() - 1)] * rng.randf_range(0.8, 1.1))


## The leaves (ivy and shrubs) are drawn in square tiles of the map, one
## MultiMesh each, so a tile off screen or far from the camera is skipped
## whole instead of every leaf of the village being drawn every frame.
const LEAF_TILE := 16.0
## Tiles further than this (metres) from the camera are not drawn; the
## camera looks down from about 25 m, so this lies beyond the screen's edge.
const LEAF_RANGE := 80.0


## All the leaves, under one node "Ivy": one MultiMesh per tile of the map.
static func ivy_node(leaves: Dictionary) -> Node3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0, 0.3, 0)
	quad.material = leaf_material()
	var tiles := {}
	for i in leaves.xforms.size():
		var at: Vector3 = (leaves.xforms[i] as Transform3D).origin
		var key := Vector2i(floori(at.x / LEAF_TILE), floori(at.z / LEAF_TILE))
		if not tiles.has(key):
			tiles[key] = []
		tiles[key].append(i)
	var root := Node3D.new()
	root.name = "Ivy"
	for key: Vector2i in tiles:
		var picked: Array = tiles[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = picked.size()
		for k in picked.size():
			mm.set_instance_transform(k, leaves.xforms[picked[k]])
			mm.set_instance_color(k, leaves.colours[picked[k]])
		var node := MultiMeshInstance3D.new()
		node.name = "Leaves_%d_%d" % [key.x, key.y]
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = LEAF_RANGE
		root.add_child(node)
	return root


## A three-lobed ivy leaf with pale veins, its colour from each leaf.
static func leaf_material() -> StandardMaterial3D:
	if not _mats.has("leaf"):
		var size := 64
		var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				# The stem at the bottom middle; lobes left, right and up.
				var p := Vector2(x + 0.5 - size * 0.5, size * 0.88 - y - 0.5) / size
				var a := atan2(p.x, p.y)
				var r := p.length()
				var lobes := 0.3 + 0.17 * pow(absf(cos(a * 1.5)), 4.0)
				var edge := lobes * (1.0 if absf(a) < 2.2 else 0.0)
				if r < edge and p.y > -0.06:
					var vein := 1.0 - 0.25 * maxf(0.0, 1.0 - absf(fposmod(a + 0.5236, 1.0472) - 0.5236) * 40.0 * r)
					var shade := (0.8 + 0.2 * (1.0 - r / maxf(edge, 0.01))) * vein
					img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
				else:
					img.set_pixel(x, y, Color(0.5, 0.5, 0.5, 0.0))
		img.generate_mipmaps()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.7
		_mats["leaf"] = mat
	return _mats["leaf"]


# --- Nests ---------------------------------------------------------------------

## A nest of twigs: a ring of sticks laid round and round a dark hollow.
static func nest_mesh() -> Mesh:
	if _mats.has("nest_mesh"):
		return _mats["nest_mesh"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The hollow.
	var mid := Color(0.16, 0.11, 0.07)
	for i in 12:
		var a0 := TAU * i / 12.0
		var a1 := TAU * (i + 1) / 12.0
		for p: Vector3 in [Vector3(0, 0.06, 0), Vector3(cos(a1) * 0.3, 0.12, sin(a1) * 0.3), Vector3(cos(a0) * 0.3, 0.12, sin(a0) * 0.3)]:
			st.set_color(mid)
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	# The twigs.
	for i in 46:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.26, 0.4)
		var y := rng.randf_range(0.02, 0.2)
		var centre := Vector3(cos(a) * r, y, sin(a) * r)
		var along := Vector3(-sin(a), rng.randf_range(-0.3, 0.3), cos(a)).normalized()
		var b := Basis.looking_at(along, Vector3.UP)
		var shade := rng.randf_range(0.7, 1.2)
		_stick(st, centre, b, Vector3(0.035, 0.035, rng.randf_range(0.3, 0.5)), Color(0.38, 0.27, 0.16) * shade)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	_mats["nest_mesh"] = mesh
	return mesh


static func _stick(st: SurfaceTool, centre: Vector3, b: Basis, size: Vector3, colour: Color) -> void:
	var h := size * 0.5
	var corners := []
	for z: float in [-h.z, h.z]:
		for y: float in [-h.y, h.y]:
			for x: float in [-h.x, h.x]:
				corners.append(centre + b * Vector3(x, y, z))
	# Corner k: x bit 1, y bit 2, z bit 4. Each face clockwise from outside.
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	for f: Array in faces:
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(colour)
			st.add_vertex(corners[f[k]])
