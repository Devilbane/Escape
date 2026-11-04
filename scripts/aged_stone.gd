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
const IVY_PATCHES := 4
const IVY_HEIGHT := Vector2(3.0, 7.5)
const IVY_DOOR_GAP := 1.9
## Leaves in one patch at most, so the whole village's ivy stays cheap.
const PATCH_LEAVES := 280
const LEAF_SIZE := Vector2(0.3, 0.46)
## The smallest wall (square metres) ivy grows on.
const IVY_WALL := 0.6
## Shades of the leaves: mostly dark green, now and then an autumn red.
const LEAF_COLOURS := [Color(0.22, 0.36, 0.14), Color(0.17, 0.29, 0.11), Color(0.28, 0.42, 0.16),
		Color(0.20, 0.33, 0.17), Color(0.36, 0.40, 0.14), Color(0.48, 0.22, 0.12)]

## A nest needs a ledge at least this high over the ground (metres) and
## this large (square metres).
const NEST_HEIGHT := 3.5
const NEST_LEDGE := 0.2

static var _mats := {}


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
		_mats[key] = mat
	return _mats[key]


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
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
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
				out.append({"a": a, "b": b, "c": c, "n": n, "area": area})
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


static func rooted(planes: Array, ground: float) -> Array:
	return planes.filter(func(p): return p.area >= IVY_WALL and p.foot < ground + 0.9 and p.top > ground + 1.6)


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
## ivy grows.
static func grow_ivy(tris: Array, middle: Vector3, ground: float, doors: Array, rng: RandomNumberGenerator, leaves: Dictionary, patches := IVY_PATCHES) -> void:
	var all_walls := walls(tris, middle, ground)
	var found := rooted(all_walls, ground)
	if found.is_empty():
		return
	var total := 0.0
	for w: Dictionary in found:
		total += w.area
	var grown := 0
	for attempt in patches * 6:
		if grown >= patches:
			break
		# A wall, by its size; the first tries go to the walls that look
		# south, the way the camera looks at the village.
		var pick := rng.randf() * total
		var wall: Dictionary = found[-1]
		for w: Dictionary in found:
			pick -= w.area
			if pick <= 0.0:
				wall = w
				break
		var facing := found.filter(func(w): return (w.n as Vector3).z > 0.4)
		if grown == 0 and attempt < 6 and not facing.is_empty():
			wall = facing[rng.randi() % facing.size()]
		var root: Vector3 = _root_on(wall, ground, rng)
		if root == Vector3.INF:
			continue
		if doors.any(func(d: Vector3): return Vector2(d.x - root.x, d.z - root.z).length() < IVY_DOOR_GAP):
			continue
		_grow_patch(wall, all_walls, root, ground, rng, leaves)
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
static func _grow_patch(root_wall: Dictionary, all_walls: Array, root: Vector3, ground: float, rng: RandomNumberGenerator, leaves: Dictionary) -> void:
	var n: Vector3 = root_wall.n
	var across := Vector3.UP.cross(n).normalized()
	var reach := ground + rng.randf_range(IVY_HEIGHT.x, IVY_HEIGHT.y)
	# The walls in line with this one: the ivy climbs on up them where one
	# ends (a jutting upper floor, a ledge).
	var line := all_walls.filter(func(w): return (w.n as Vector3).dot(n) > 0.99)
	var tips: Array = []
	for i in rng.randi_range(3, 5):
		tips.append({"p": root + across * rng.randf_range(-0.6, 0.6), "drift": rng.randf_range(-0.6, 0.6), "wall": root_wall})
	var steps := 0
	var first: int = leaves.xforms.size()
	while not tips.is_empty() and steps < 600 and leaves.xforms.size() - first < PATCH_LEAVES:
		steps += 1
		var tip: Dictionary = tips.pop_back()
		var p: Vector3 = tip.p
		var drift: float = tip.drift
		var wall: Dictionary = tip.wall
		while p.y < reach:
			drift = clampf(drift + rng.randf_range(-0.35, 0.35), -0.9, 0.9)
			var next := p + Vector3.UP * 0.16 + across * drift * 0.1
			if not _on_wall(wall, next):
				# Round the edge of a window or the wall: try straight up,
				# then on to a wall in line just above.
				next = p + Vector3.UP * 0.16
				if not _on_wall(wall, next):
					var hop := _wall_at(line, next)
					if hop.is_empty():
						break
					wall = hop
					next = next + n * (float(wall.d) - n.dot(next))
			p = next
			# Fuller near the ground, sparse at the top.
			var fill := clampf(1.0 - (p.y - ground) / maxf(reach - ground, 0.5), 0.0, 1.0)
			for k in rng.randi_range(1, 1 + int(fill * 1.6)):
				var at := p + across * rng.randf_range(-0.2, 0.2) + Vector3.UP * rng.randf_range(-0.08, 0.08)
				if _on_wall(wall, at):
					_leaf(at, n, across, rng, leaves, 0.75 + fill * 0.35)
			if rng.randf() < 0.08 and tips.size() < 8:
				tips.append({"p": p, "drift": -drift, "wall": wall})


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


## All the leaves in one MultiMesh.
static func ivy_node(leaves: Dictionary) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0, 0.3, 0)
	quad.material = leaf_material()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = leaves.xforms.size()
	for i in mm.instance_count:
		mm.set_instance_transform(i, leaves.xforms[i])
		mm.set_instance_color(i, leaves.colours[i])
	var node := MultiMeshInstance3D.new()
	node.name = "Ivy"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


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
