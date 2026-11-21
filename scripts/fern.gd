class_name Fern
extends RefCounted
## A low-poly fern, and the needle tree built from it.
##
## The fern: a rosette of FRONDS long fronds rising from the ground and arching over, each a stem
## with pairs of narrow leaflets down both sides, longest in the middle of the frond and short at
## its foot and tip (see _frond). Bright mid-green, the leaflets a shade lighter at their tips.
##
## The needle tree is stacked from the same fern (see needle_tree): each tier is TIER_FERNS ferns
## on top of each other, each turned a little further so their fronds fill the circle evenly; the
## next tier sits higher and is a bit smaller, and in the top tier the fronds bend upwards and
## close into the tree's tip. A wooden trunk runs up the middle, hidden above by the needles, and shows below the lowest tier.
##
## A frond is a card: a strip of a few flat quads following the frond's arch, wearing a picture of
## the stem and its leaflets painted once in code (see frond_texture), cut out where the picture
## is empty. Its colour comes from the vertices, so ferns and needle trees share the one picture.
## Every model is one mesh (the fronds, and a needle tree's trunk as a second surface), built once
## and shared (see _cache), so a whole forest of them costs a couple of draw calls per kind.

## How many fronds a fern has.
const FRONDS := 8
## Leaflet pairs along a frond (painted into the frond's picture).
const PAIRS := 9
## Quads along a fern's frond and along a needle tree's (whose fronds are shorter and many).
const SEGMENTS := 5
const LIGHT_SEGMENTS := 3
## The far needle tree's fronds (see needle_tree_mesh): fewer segments, and broader, so fewer of
## them (FAR_TIERS tiers of FAR_TIER_FERNS ferns of FAR_FRONDS fronds) still close the crown.
const FAR_SEGMENTS := 2
const FAR_WIDTH := 0.55
const FAR_TIERS := 19
const FAR_TIER_FERNS := 1
const FAR_FRONDS := 10
## The frond picture's size in pixels: across and along the frond.
const TEXTURE_SIZE := Vector2i(64, 256)
## How bright the picture is, times the vertex colour: the stem, a leaflet at its foot and tip.
const SHADE_STEM := 0.58
const SHADE_LEAF := 0.74
## The fern's green (its leaflets' tips; the picture darkens the rest), and the needle tree's: a
## dark, blue-tinged green that stays all year. Then the needle tree's bark.
const FERN_GREEN := Color(0.46, 0.72, 0.24)
const NEEDLE_GREEN := Color(0.2, 0.5, 0.37)
const BARK := Color(0.32, 0.22, 0.15)
## The needle tree: ferns in a tier, and how many tiers.
const TIER_FERNS := 4
const TIERS := 19
## How tall each step of a needle tree's shadow stand-in is (m, see needle_shadow_mesh).
const SHADOW_STEP := 0.45
## The needle tree: its height and how far its lowest branches reach (m).
const HEIGHT := 7.0
const REACH := 1.25
## How far below the cone's point the top tier sits (m).
const REACH_TOP := 1.2
## The needle trees' looks: how tall (times HEIGHT) and how full (times REACH) each variant is.
const NEEDLE_LOOKS := [Vector2(1.0, 1.0), Vector2(0.75, 1.1), Vector2(1.1, 1.25)]

const NEEDLE_SHADER := preload("res://shaders/spruce_needles.gdshader")

static var _cache := {}
static var _mats := {}
static var _bark_mat: StandardMaterial3D
static var _textures := {}


## A fern, `size` m across (about), as a mesh shared by every fern of that look. `variant` picks
## one of a few slightly different ferns.
static func fern_mesh(variant := 0) -> ArrayMesh:
	var key := "fern:%d" % variant
	if not _cache.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		_rosette(st, rng, Transform3D.IDENTITY, FRONDS, 1.25, 0.0, 0.0, FERN_GREEN, 0.0)
		st.set_material(material(false))
		_cache[key] = st.commit()
	return _cache[key]


## A needle tree as a shared mesh. Each `variant` has its own height and
## fullness (see NEEDLE_LOOKS), so a stand of them never looks copied. The `far` one, for trees
## further off than the eye can count fronds, has the same outline from far fewer, broader fronds.
static func needle_tree_mesh(variant := 0, far := false) -> ArrayMesh:
	var key := ("needle far:%d" if far else "needle:%d") % variant
	if not _cache.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var trunk := SurfaceTool.new()
		trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		var look: Vector2 = NEEDLE_LOOKS[posmod(variant, NEEDLE_LOOKS.size())]
		needle_tree(st, trunk, rng, look.x, look.y, far)
		st.set_material(material(true))
		trunk.set_material(bark_material())
		_cache[key] = trunk.commit(st.commit())
	return _cache[key]


## A stand-in for a needle tree `variant` that only casts its shadow: a lathe round its trunk that
## follows how far its branches reach at each height, a couple of hundred triangles instead of
## thousands (every shadow map draws every tree again).
static func needle_shadow_mesh(variant := 0) -> ArrayMesh:
	var key := "needle shadow:%d" % variant
	if not _cache.has(key):
		var tree := needle_tree_mesh(variant)
		var verts: PackedVector3Array = tree.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var top := tree.get_aabb().end.y
		var bins := maxi(4, ceili(top / SHADOW_STEP))
		var reach := PackedFloat32Array()
		reach.resize(bins + 1)
		for v in verts:
			var i := clampi(roundi(v.y / top * bins), 0, bins)
			reach[i] = maxf(reach[i], Vector2(v.x, v.z).length())
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sides := 8
		for i in bins:
			# The leafy part fills in; most of the reach is solid needles, the very tips are not.
			var r0 := reach[i] * 0.8
			var r1 := reach[i + 1] * 0.8
			var y0 := top * i / bins
			var y1 := top * (i + 1) / bins
			for k in sides:
				var a0 := TAU * k / sides
				var a1 := TAU * (k + 1) / sides
				var p := [Vector3(cos(a0) * r0, y0, sin(a0) * r0), Vector3(cos(a1) * r0, y0, sin(a1) * r0),
						Vector3(cos(a1) * r1, y1, sin(a1) * r1), Vector3(cos(a0) * r1, y1, sin(a0) * r1)]
				for j in [0, 2, 1, 0, 3, 2]:
					st.set_normal(Vector3(p[j].x, 0, p[j].z).normalized())
					st.add_vertex(p[j])
		st.set_material(bark_material())
		_cache[key] = st.commit()
	return _cache[key]


## How tall a needle tree `variant` stands (metres).
static func needle_height(variant: int) -> float:
	return needle_tree_mesh(variant).get_aabb().end.y


## A MeshInstance3D of a mesh (its materials come with it).
static func instance(mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


## How many triangles a mesh of these has, all its surfaces together.
static func triangles(mesh: ArrayMesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## The fronds' material: the frond picture (the needle tree's with broader leaflets), cut out where
## it is empty, times the vertex colours; both sides drawn. The needle tree's sways gently in the
## wind and takes no shadows (see spruce_needles.gdshader). Shared.
static func material(needles: bool) -> Material:
	if not _mats.has(needles):
		if needles:
			var sm := ShaderMaterial.new()
			sm.shader = NEEDLE_SHADER
			sm.set_shader_parameter("albedo_tex", frond_texture(true))
			_mats[needles] = sm
		else:
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.albedo_texture = frond_texture(false)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.4
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.9
			_mats[needles] = m
	return _mats[needles]


## The needle tree's trunk: plain bark, colour from the vertices. Shared.
static func bark_material() -> StandardMaterial3D:
	if _bark_mat == null:
		_bark_mat = StandardMaterial3D.new()
		_bark_mat.vertex_color_use_as_albedo = true
		_bark_mat.roughness = 0.95
	return _bark_mat


## The picture on every frond, TEXTURE_SIZE pixels, the frond's foot at the top (v = 0) and its
## tip at the bottom: a thin stem down the middle, narrowing, and PAIRS pairs of narrow pointed
## leaflets leaning towards the tip, longest in the middle of the frond. Grey, lighter towards the
## leaflets' tips; empty (clear) everywhere else. Painted once. The needle tree's leaflets are
## broader: hundreds of its fronds overlap, and from afar they must close into one dark mass.
static func frond_texture(needles: bool) -> ImageTexture:
	if _textures.has(needles):
		return _textures[needles]
	var w := TEXTURE_SIZE.x
	var h := TEXTURE_SIZE.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(SHADE_LEAF, SHADE_LEAF, SHADE_LEAF, 0.0))
	# Leaflets, in the picture's own units: x from -1 (one edge) to 1 (the other), y from 0 (the
	# foot) to 1 (the tip). Each is a triangle from the stem out to its tip.
	var leaflets := []
	for k in range(1, PAIRS + 1):
		var t := float(k) / (PAIRS + 1)
		var reach := sin(PI * clampf(t * 1.05, 0.08, 1.0)) * (1.0 - t * 0.35)
		var wide := (0.075 if needles else 0.04) * (1.0 - t * 0.45)
		for sign in [-1.0, 1.0]:
			leaflets.append([Vector2(0, t - wide), Vector2(0, t + wide), Vector2(sign * reach * 0.94, t + reach * 0.16)])
	for py in h:
		for px in w:
			var p := Vector2((px + 0.5) / w * 2.0 - 1.0, (py + 0.5) / h)
			# The stem.
			var stem := lerpf(0.07, 0.025, p.y)
			if absf(p.x) < stem:
				img.set_pixel(px, py, Color(SHADE_STEM, SHADE_STEM, SHADE_STEM, 1.0))
				continue
			for l in leaflets:
				var b := _inside(p, l[0], l[1], l[2])
				if b >= 0.0:
					var shade := lerpf(SHADE_LEAF, 1.0, b)
					img.set_pixel(px, py, Color(shade, shade, shade, 1.0))
					break
	img.generate_mipmaps()
	_textures[needles] = ImageTexture.create_from_image(img)
	return _textures[needles]


## Whether `p` lies in the triangle `a`, `b`, `c`: how far towards `c` it lies (0 to 1), or -1
## when outside.
static func _inside(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	var d := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(d) < 0.000001:
		return -1.0
	var wa := ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / d
	var wb := ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / d
	var wc := 1.0 - wa - wb
	if wa < 0.0 or wb < 0.0 or wc < 0.0:
		return -1.0
	return wc


## Adds a needle tree to `st`: the trunk, then TIERS tiers of TIER_FERNS ferns each, higher and
## smaller going up, the top tier's fronds bent upwards into the tip.
static func needle_tree(st: SurfaceTool, trunk: SurfaceTool, rng: RandomNumberGenerator, tall := 1.0, full := 1.0, far := false) -> void:
	var tiers := FAR_TIERS if far else TIERS
	var ferns := FAR_TIER_FERNS if far else TIER_FERNS
	# The shape of a real spruce: a slim cone about three times as tall as it is wide, its sides
	# straight from the lowest branches near the ground up to a pointed leader.
	var foot := 0.55
	# Where the cone's sides would meet. Each tier's branches reach in proportion to their height
	# below it, and the gaps between tiers shrink going up with the reach, so the ferns lie about
	# equally thick from the lowest tier to the top.
	var apex := HEIGHT * 0.9 * tall
	var last := apex - REACH_TOP * lerpf(1.0, tall, 0.5)
	var ratio := pow((apex - last) / (apex - foot), 1.0 / (tiers - 1))
	_cone(trunk, Vector3.ZERO, Vector3(0, last * 0.7, 0), 0.17 * lerpf(1.0, tall * full, 0.6), 0.015, BARK)
	var colour := NEEDLE_GREEN
	for tier in tiers:
		var t := float(tier) / (tiers - 1)
		# Halfway between even steps and steps in proportion to the reach: the narrow top has fewer
		# fronds round it, so its tiers need not crowd as close as the reach alone would put them.
		var below := lerpf((apex - foot) * pow(ratio, tier), lerpf(apex - foot, REACH_TOP, t), 0.5)
		var y := apex - below
		var reach := REACH * full * lerpf(1.0, tall, 0.5) * below / (apex - foot)
		# Low branches bend down towards the ground, the middle ones stand out level, the top ones
		# angle up and spread round the leader.
		var top := tier == tiers - 1
		var rise := 0.55 if top else lerpf(-0.25, 0.25, t)
		var droop := 0.4 if top else lerpf(2.1, 1.1, t)
		var size := reach * lerpf(1.1, 1.3, t) + 0.06
		var turn := rng.randf() * TAU
		for k in ferns:
			# Each fern of the tier turned a little further, so the fronds fill the circle evenly.
			var spin := turn + TAU / FRONDS * float(k) / ferns
			var xf := Transform3D(Basis(Vector3.UP, spin), Vector3(0, y + k * 0.06 * size, 0))
			_rosette(st, rng, xf, FAR_FRONDS if far else FRONDS, size, rise, droop, colour * lerpf(0.72, 1.05, t), 0.1 * size, true, far)
	# The leader: a thin shoot above the last tier with a few short fronds spreading round it.
	for k in (2 if far else 4):
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, last + 0.12 + k * 0.14, 0))
		_rosette(st, rng, xf, 6, 0.42 - k * 0.08, 0.7, 0.2 - k * 0.15, colour * 1.05, 0.0, true, far)


## Adds a rosette of `count` fronds `size` long round `xf`'s origin to `st`. `rise` lifts the
## fronds' start (0: they leave the middle at the fern's usual angle, 1: nearly straight up) and
## `droop` sets how far they arch over (negative: they curl up and in). `hub` is how far out from
## the middle the fronds start.
static func _rosette(st: SurfaceTool, rng: RandomNumberGenerator, xf: Transform3D, count: int, size: float, rise: float, droop: float, colour: Color, hub: float, light := false, far := false) -> void:
	for i in count:
		var a := TAU * i / count + rng.randf_range(-0.12, 0.12)
		var lift := lerpf(deg_to_rad(rng.randf_range(55.0, 70.0)), deg_to_rad(82.0), rise)
		var arch := droop if droop != 0.0 else rng.randf_range(1.3, 1.7)
		var length := size * rng.randf_range(0.85, 1.1)
		_frond(st, xf, a, lift, arch, length, hub, colour, light, far)


## One frond: from near the middle out along `a` (round the up axis), leaving at `lift` above the
## ground and bending down by `arch` (radians over its length): a card of SEGMENTS quads (a
## `light` frond, the needle tree's, LIGHT_SEGMENTS, a `far` one FAR_SEGMENTS and broader) as wide as its leaflets reach, wearing the
## frond picture. A fern's card is folded a little along its stem, as a real frond is.
static func _frond(st: SurfaceTool, xf: Transform3D, a: float, lift: float, arch: float, length: float, hub: float, colour: Color, light := false, far := false) -> void:
	var out := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-sin(a), 0, cos(a))
	var steps := FAR_SEGMENTS if far else LIGHT_SEGMENTS if light else SEGMENTS
	var half := length * (FAR_WIDTH if far else 0.32)
	var points := []
	var p := out * hub
	points.append(p)
	for s in steps:
		var t := (s + 0.5) / steps
		var elev := lift - arch * t
		var d := out * cos(elev) + Vector3.UP * sin(elev)
		p += d * (length / steps)
		# Never down into the ground: a frond that bends that far rests its end just above it.
		p.y = maxf(p.y, 0.06 - xf.origin.y)
		points.append(p)
	var fold := Vector3.ZERO if light else Vector3.UP * half * 0.18
	for s in steps:
		var v0 := float(s) / steps
		var v1 := float(s + 1) / steps
		var a0: Vector3 = points[s]
		var a1: Vector3 = points[s + 1]
		var mid0 := a0 + fold
		var mid1 := a1 + fold
		if light:
			_card(st, xf, colour, [a0 - side * half, Vector2(0, v0)], [a0 + side * half, Vector2(1, v0)], [a1 + side * half, Vector2(1, v1)], [a1 - side * half, Vector2(0, v1)])
		else:
			_card(st, xf, colour, [a0 - side * half, Vector2(0, v0)], [mid0, Vector2(0.5, v0)], [mid1, Vector2(0.5, v1)], [a1 - side * half, Vector2(0, v1)])
			_card(st, xf, colour, [mid0, Vector2(0.5, v0)], [a0 + side * half, Vector2(1, v0)], [a1 + side * half, Vector2(1, v1)], [mid1, Vector2(0.5, v1)])


## A quad of a frond's card, its corners [position, uv] in order round it.
static func _card(st: SurfaceTool, xf: Transform3D, colour: Color, c0: Array, c1: Array, c2: Array, c3: Array) -> void:
	var n: Vector3 = (xf.basis * ((c1[0] as Vector3) - (c0[0] as Vector3)).cross((c3[0] as Vector3) - (c0[0] as Vector3))).normalized()
	if n.y < 0.0:
		n = -n
	# Lit a little as if from above and outwards, so the cards read softly, not each its own glint.
	n = (n + Vector3.UP * 0.6).normalized()
	for c in [c0, c1, c2, c0, c2, c3]:
		st.set_color(colour)
		st.set_normal(n)
		st.set_uv(c[1])
		st.add_vertex(xf * (c[0] as Vector3))


## A tapering round trunk from `from` to `to`.
static func _cone(st: SurfaceTool, from: Vector3, to: Vector3, r0: float, r1: float, colour: Color) -> void:
	var sides := 7
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var n0 := Vector3(cos(a0), 0, sin(a0))
		var n1 := Vector3(cos(a1), 0, sin(a1))
		for v in [[from + n0 * r0, n0], [to + n1 * r1, n1], [from + n1 * r0, n1], [from + n0 * r0, n0], [to + n0 * r1, n0], [to + n1 * r1, n1]]:
			st.set_color(colour * (0.85 + 0.15 * v[1].x))
			st.set_normal(v[1])
			st.add_vertex(v[0])
