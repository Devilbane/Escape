class_name BushKinds
extends RefCounted
## The shrubs of the forest edge and the village come in many kinds, so a row of them never repeats itself
## (see AgedStone.grow_bush, Outdoor._plant_bushes, Outdoor._grow_undergrowth).
##
## A kind differs from the others in its shape (a round dome, a tall column, a low spreading mound, a cone,
## a vase of twigs), its size, the shape of its leaf (lobed, oval, lance, feathered, needles), its colours,
## the number of branches that show through the leaves, and its berries or blooms. Neighbouring bushes never
## share a kind (`recent`).
##
## Everything stays a few MultiMeshes per map tile: the leaves of each leaf shape are one MultiMesh, the
## berries and blooms (small details, drawn only near) another, the twigs of the shared stems. Each leaf
## shape has a textured card of its own (veins, a toothed or smooth edge, mottled shading), tinted by the
## instance colour. The seasons treat them like the ivy (see IvySeasons): green leaves turn in autumn,
## berries, blooms, red leaves and the dark evergreens (see IvySeasons.is_green) keep their colour.

## The leaf shapes, and each one's size against a plain leaf card (see AgedStone.LEAF_SIZE).
const LOBED := "lobed"
const OVAL := "oval"
const LANCE := "lance"
const FEATHER := "feather"
const NEEDLE := "needle"
const BERRY := "berry"
const BLOOM := "bloom"
## Berries and blooms are small: drawn only this close to the camera (metres). Leaves reach AgedStone.LEAF_RANGE.
const DETAIL_RANGE := 55.0
## Twigs are thin: the same.
const TWIG_RANGE := 55.0
## The profile of a bush's outline from the ground (0) to its top (1): how wide it is there, 0 to 1.
const DOME := 0
const COLUMN := 1
const CONE := 2
const VASE := 3
const MOUND := 4
## How many kinds the last bushes of a row must not repeat.
const RECENT := 2

const KINDS := [
	{"name": "round", "weight": 0.12, "radius": Vector2(0.8, 1.4), "tall": Vector2(0.7, 1.0), "profile": DOME,
		"leaf": LOBED, "size": 1.35, "count": 1.0, "twigs": 3, "on_twigs": 0.0, "bloom": 0.3,
		"palettes": [[Color(0.34, 0.52, 0.17), Color(0.42, 0.56, 0.18), Color(0.5, 0.58, 0.18), Color(0.3, 0.48, 0.2)],
			[Color(0.26, 0.45, 0.16), Color(0.34, 0.52, 0.17), Color(0.24, 0.42, 0.15)]]},
	{"name": "tall", "weight": 0.12, "radius": Vector2(0.45, 0.72), "tall": Vector2(2.4, 3.4), "profile": COLUMN,
		"leaf": OVAL, "size": 0.95, "count": 1.0, "twigs": 4, "on_twigs": 0.0,
		"palettes": [[Color(0.2, 0.4, 0.15), Color(0.25, 0.46, 0.17), Color(0.17, 0.35, 0.14)],
			[Color(0.38, 0.48, 0.17), Color(0.44, 0.52, 0.2), Color(0.34, 0.44, 0.16)]]},
	{"name": "low", "weight": 0.12, "radius": Vector2(1.2, 1.9), "tall": Vector2(0.3, 0.45), "profile": MOUND,
		"leaf": OVAL, "size": 1.25, "count": 0.85, "twigs": 2, "on_twigs": 0.0, "bloom": 0.45,
		"palettes": [[Color(0.5, 0.62, 0.2), Color(0.44, 0.58, 0.18), Color(0.56, 0.64, 0.22)],
			[Color(0.36, 0.55, 0.2), Color(0.3, 0.5, 0.18), Color(0.42, 0.58, 0.22)]]},
	{"name": "twiggy", "weight": 0.1, "radius": Vector2(0.7, 1.1), "tall": Vector2(1.3, 1.9), "profile": VASE,
		"leaf": LANCE, "size": 1.0, "count": 0.85, "twigs": 9, "on_twigs": 0.8,
		"palettes": [[Color(0.5, 0.56, 0.22), Color(0.58, 0.6, 0.28), Color(0.42, 0.5, 0.2)],
			[Color(0.4, 0.52, 0.2), Color(0.34, 0.46, 0.17)]]},
	{"name": "broad", "weight": 0.12, "radius": Vector2(0.9, 1.4), "tall": Vector2(0.85, 1.1), "profile": DOME,
		"leaf": OVAL, "size": 1.9, "count": 0.6, "twigs": 3, "on_twigs": 0.0, "bloom": 0.5, "bloom_size": 2.0,
		"palettes": [[Color(0.2, 0.42, 0.16), Color(0.16, 0.37, 0.14), Color(0.24, 0.46, 0.18)]]},
	{"name": "berry", "weight": 0.1, "radius": Vector2(0.7, 1.1), "tall": Vector2(0.9, 1.25), "profile": DOME,
		"leaf": OVAL, "size": 0.9, "count": 1.1, "twigs": 5, "on_twigs": 0.2, "berries": 38,
		"palettes": [[Color(0.3, 0.48, 0.2), Color(0.36, 0.52, 0.2), Color(0.26, 0.42, 0.17)]]},
	{"name": "evergreen", "weight": 0.12, "radius": Vector2(0.7, 1.2), "tall": Vector2(1.5, 2.3), "profile": CONE,
		"leaf": NEEDLE, "size": 1.3, "count": 0.85, "twigs": 3, "on_twigs": 0.0, "evergreen": true,
		"palettes": [[Color(0.13, 0.32, 0.26), Color(0.15, 0.34, 0.27), Color(0.12, 0.3, 0.25)],
			[Color(0.19, 0.34, 0.29), Color(0.16, 0.31, 0.28), Color(0.22, 0.36, 0.3)]]},
	{"name": "red", "weight": 0.06, "radius": Vector2(0.8, 1.3), "tall": Vector2(0.7, 1.0), "profile": DOME,
		"leaf": OVAL, "size": 0.85, "count": 1.15, "twigs": 6, "on_twigs": 0.3,
		"palettes": [[Color(0.42, 0.1, 0.12), Color(0.5, 0.14, 0.1), Color(0.34, 0.08, 0.1)],
			[Color(0.5, 0.28, 0.1), Color(0.42, 0.2, 0.08), Color(0.56, 0.34, 0.12)]]},
	{"name": "feathery", "weight": 0.08, "radius": Vector2(0.8, 1.3), "tall": Vector2(0.8, 1.15), "profile": DOME,
		"leaf": FEATHER, "size": 1.9, "count": 0.55, "twigs": 6, "on_twigs": 0.4, "bloom": 0.6, "bloom_size": 0.9,
		"palettes": [[Color(0.42, 0.58, 0.22), Color(0.36, 0.52, 0.2), Color(0.48, 0.6, 0.24)]]},
	{"name": "bramble", "weight": 0.06, "radius": Vector2(0.9, 1.4), "tall": Vector2(0.8, 1.1), "profile": VASE,
		"leaf": LOBED, "size": 0.85, "count": 0.5, "twigs": 12, "on_twigs": 0.65, "berries": 26, "berry_black": true,
		"palettes": [[Color(0.3, 0.46, 0.18), Color(0.38, 0.5, 0.2), Color(0.26, 0.4, 0.16)]]},
]

## Colours of the berries (red, orange, blue-black, purple) and of the blooms (pink, white, yellow, violet).
const BERRY_COLOURS := [Color(0.78, 0.1, 0.12), Color(0.9, 0.38, 0.08), Color(0.62, 0.08, 0.14), Color(0.3, 0.12, 0.4)]
const BERRY_BLACK := [Color(0.1, 0.07, 0.14), Color(0.16, 0.08, 0.2), Color(0.08, 0.06, 0.1)]
const BLOOM_COLOURS := [Color(0.95, 0.55, 0.65), Color(1.0, 0.95, 0.9), Color(0.98, 0.82, 0.3), Color(0.72, 0.58, 0.92)]
## The wood of the twigs (the stems' bark texture tints it): greys and browns.
const TWIG_COLOURS := [Color(0.72, 0.58, 0.44), Color(0.64, 0.52, 0.42), Color(0.78, 0.68, 0.54), Color(0.56, 0.46, 0.38)]

static var _mats := {}


## One kind's data by name.
static func kind(name: String) -> Dictionary:
	for k: Dictionary in KINDS:
		if k.name == name:
			return k
	return {}


## The index of the kind a bush gets: by weight, but never one of the `recent` bushes' kinds (the list
## is kept up to date here, RECENT long), so neighbours differ.
static func pick(rng: RandomNumberGenerator, recent: Array) -> int:
	var open := 0.0
	for i in KINDS.size():
		if not recent.has(i):
			open += float(KINDS[i].weight)
	var roll := rng.randf() * open
	var chosen := 0
	for i in KINDS.size():
		if recent.has(i):
			continue
		chosen = i
		roll -= float(KINDS[i].weight)
		if roll <= 0.0:
			break
	recent.append(chosen)
	while recent.size() > RECENT:
		recent.remove_at(0)
	return chosen


## The leaves of one leaf shape inside `leaves` (the dictionary AgedStone.ivy_node builds from).
static func layer(leaves: Dictionary, shape: String) -> Dictionary:
	if not leaves.has("shapes"):
		leaves["shapes"] = {}
	var shapes: Dictionary = leaves["shapes"]
	if not shapes.has(shape):
		shapes[shape] = {"xforms": [], "colours": []}
	return shapes[shape]


## Whether `leaves` holds anything at all (the plain leaves, the other leaf shapes).
static func has_any(leaves: Dictionary) -> bool:
	if not (leaves.xforms as Array).is_empty():
		return true
	for shape: Dictionary in (leaves.get("shapes", {}) as Dictionary).values():
		if not (shape.xforms as Array).is_empty():
			return true
	return false


## How wide the outline is at height `t` (0 to 1) for a profile, 0 to 1.
static func width_at(profile: int, t: float) -> float:
	match profile:
		COLUMN:
			return sqrt(maxf(0.0, 1.0 - pow(t, 3.0))) * (0.8 + 0.2 * sin(t * 6.0))
		CONE:
			return pow(1.0 - t, 0.85)
		VASE:
			return 0.3 + 0.7 * pow(t, 0.7) * (1.0 - 0.35 * t * t)
		MOUND:
			return pow(maxf(0.0, 1.0 - pow(t, 1.6)), 0.5)
		_:
			return sqrt(maxf(0.0, 1.0 - t * t))


## Grows one bush at `at`; returns its radius. `leaves` is where its leaves go, `evergreen_into` where an
## evergreen's go (they never shed), `recent` the kinds of the last bushes (see pick).
static func grow(at: Vector3, rng: RandomNumberGenerator, leaves: Dictionary, evergreen_into: Dictionary, recent: Array) -> float:
	return grow_kind(pick(rng, recent), at, rng, leaves, evergreen_into)


## Grows one bush of kind number `index` (see grow).
static func grow_kind(index: int, at: Vector3, rng: RandomNumberGenerator, leaves: Dictionary, evergreen_into := {}) -> float:
	var k: Dictionary = KINDS[index]
	if evergreen_into.is_empty():
		evergreen_into = leaves
	if bool(k.get("evergreen", false)):
		leaves = evergreen_into
	var radius := rng.randf_range((k.radius as Vector2).x, (k.radius as Vector2).y)
	var tall := radius * rng.randf_range((k.tall as Vector2).x, (k.tall as Vector2).y)
	var profile: int = k.profile
	var palettes: Array = k.palettes
	var palette: Array = palettes[rng.randi() % palettes.size()]
	var evergreen := bool(k.get("evergreen", false))
	# This bush's own tint and how much it leans.
	var tint := Color(rng.randf_range(0.93, 1.07), rng.randf_range(0.96, 1.05), rng.randf_range(0.93, 1.07))
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12)) * tall
	var shape := layer(leaves, k.leaf)
	var count := int((46.0 + radius * 70.0 + tall * 14.0) * float(k.count))
	var size := float(k.size) * 1.5 * rng.randf_range(0.9, 1.1)
	# The twigs: each rises from the foot, bends outward and ends in a tip where leaves cluster.
	var tips: Array[Vector3] = []
	var twigs := int(k.twigs) + rng.randi_range(-1, 1)
	for i in maxi(0, twigs):
		tips.append_array(_twig(at, radius, tall, profile, lean, rng, leaves))
	var on_twigs := float(k.on_twigs) if not tips.is_empty() else 0.0
	for i in count:
		var p: Vector3
		var out: Vector3
		if rng.randf() < on_twigs:
			var tip := tips[rng.randi() % tips.size()]
			p = tip + Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.15, 0.2), rng.randf_range(-0.22, 0.22))
			out = (p - at - Vector3(0, tall * 0.3, 0)).normalized()
		else:
			var a := rng.randf() * TAU
			var t := rng.randf_range(0.0, 1.0) if profile != CONE else pow(rng.randf(), 0.8)
			var reach := width_at(profile, t) * radius * rng.randf_range(0.6, 1.0)
			p = at + lean * t + Vector3(cos(a) * reach, t * tall + 0.05, sin(a) * reach)
			out = Vector3(cos(a) * reach / maxf(radius, 0.1), 0.35 + 0.9 * t, sin(a) * reach / maxf(radius, 0.1)).normalized()
		if out.length() < 0.1:
			out = Vector3.UP
		var across := Vector3.UP.cross(out)
		across = across.normalized() if across.length() > 0.01 else Vector3.RIGHT
		var s := rng.randf_range(AgedStone.LEAF_SIZE.x, AgedStone.LEAF_SIZE.y) * size
		var b := Basis(across, out.cross(across), out).rotated(out, rng.randf_range(-PI, PI))
		(shape.xforms as Array).append(Transform3D(b.scaled(Vector3(s, s, s)), p))
		# Darker low down inside the bush, lighter at the sunlit top.
		var height_t := clampf((p.y - at.y) / maxf(tall, 0.1), 0.0, 1.0)
		var c: Color = palette[rng.randi() % palette.size()] * tint
		c *= rng.randf_range(0.85, 1.0 if evergreen else 1.08) * lerpf(0.8, 1.08, height_t)
		c.a = 1.0
		(shape.colours as Array).append(c)
	_decorate(k, at, radius, tall, profile, lean, rng, leaves)
	return radius


## The blooms and berries of a bush, small cards on its outside.
static func _decorate(k: Dictionary, at: Vector3, radius: float, tall: float, profile: int, lean: Vector3, rng: RandomNumberGenerator, leaves: Dictionary) -> void:
	var bloom_colour: Color = BLOOM_COLOURS[rng.randi() % BLOOM_COLOURS.size()]
	var blooms := int(14.0 * (radius + 0.3)) if rng.randf() < float(k.get("bloom", 0.0)) else 0
	var berries := int(k.get("berries", 0))
	if berries > 0 and rng.randf() < 0.25:
		berries = 0
	var berry_colours: Array = BERRY_BLACK if bool(k.get("berry_black", false)) else BERRY_COLOURS
	var berry_colour: Color = berry_colours[rng.randi() % berry_colours.size()]
	for j in blooms + berries:
		var is_bloom := j < blooms
		var a := rng.randf() * TAU
		var t := rng.randf_range(0.15, 0.95) if is_bloom else rng.randf_range(0.05, 0.8)
		var reach := width_at(profile, t) * radius * rng.randf_range(0.85, 1.05)
		var p := at + lean * t + Vector3(cos(a) * reach, t * tall + 0.05, sin(a) * reach)
		var out := Vector3(cos(a) * reach / maxf(radius, 0.1), 0.35 + 0.9 * t, sin(a) * reach / maxf(radius, 0.1)).normalized()
		var across := Vector3.UP.cross(out)
		across = across.normalized() if across.length() > 0.01 else Vector3.RIGHT
		var s := (rng.randf_range(0.26, 0.38) * float(k.get("bloom_size", 1.0))) if is_bloom else rng.randf_range(0.13, 0.2)
		var b := Basis(across, out.cross(across), out).rotated(out, rng.randf_range(-PI, PI))
		# Pushed out a little from the leaves so they show.
		var shape := layer(leaves, BLOOM if is_bloom else BERRY)
		(shape.xforms as Array).append(Transform3D(b.scaled(Vector3(s, s, s)), p + out * 0.12))
		var c: Color = (bloom_colour * rng.randf_range(0.9, 1.05)) if is_bloom else (berry_colour if rng.randf() < 0.8 else berry_colours[rng.randi() % berry_colours.size()]) * rng.randf_range(0.85, 1.15)
		c.a = 1.0
		(shape.colours as Array).append(c)


## One twig: two bark strips from the foot, up and outward; returns the end point.
static func _twig(at: Vector3, radius: float, tall: float, profile: int, lean: Vector3, rng: RandomNumberGenerator, leaves: Dictionary) -> Array[Vector3]:
	var a := rng.randf() * TAU
	var dir := Vector3(cos(a), 0.0, sin(a))
	var foot := at + Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
	var t_end := rng.randf_range(0.6, 1.0)
	var end := at + lean * t_end + dir * width_at(profile, t_end) * radius * rng.randf_range(0.5, 0.95) + Vector3(0, t_end * tall + 0.05, 0)
	# A bend in the middle, bowing outward.
	var mid := (foot + end) * 0.5 + dir * radius * rng.randf_range(0.05, 0.2) + Vector3(0, rng.randf_range(-0.1, 0.15), 0)
	if not leaves.has("stems"):
		leaves["stems"] = []
		leaves["stem_colours"] = []
	var thick := rng.randf_range(0.04, 0.075)
	var wood: Color = TWIG_COLOURS[rng.randi() % TWIG_COLOURS.size()]
	for pair: Array in [[foot, mid, thick], [mid, end, thick * 0.7]]:
		var from: Vector3 = pair[0]
		var to: Vector3 = pair[1]
		var way := to - from
		var length := way.length()
		if length < 0.01:
			continue
		way /= length
		# The strip faces up and outward, so it shows from above and from the side.
		var n := (Vector3.UP * 0.8 + dir * 0.6)
		n = (n - way * n.dot(way)).normalized()
		var x := way.cross(n).normalized()
		(leaves.stems as Array).append(Transform3D(Basis(x * float(pair[2]), way * (length + 0.02), n), (from + to) * 0.5))
		(leaves.stem_colours as Array).append(wood * rng.randf_range(0.85, 1.15))
	return [end]


## The MultiMeshes of the other leaf shapes (and berries and blooms) in `leaves`, one per map tile and shape,
## under `root`; the plain leaves AgedStone.ivy_node builds itself.
static func nodes_into(root: Node3D, leaves: Dictionary) -> void:
	var shapes: Dictionary = leaves.get("shapes", {})
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0, 0.3, 0)
	for shape: String in shapes:
		var data: Dictionary = shapes[shape]
		var xf: Array = data.xforms
		if xf.is_empty():
			continue
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		mesh.center_offset = quad.center_offset
		mesh.material = material(shape)
		var tiles := {}
		for i in xf.size():
			var at: Vector3 = (xf[i] as Transform3D).origin
			var key := Vector2i(floori(at.x / AgedStone.LEAF_TILE), floori(at.z / AgedStone.LEAF_TILE))
			if not tiles.has(key):
				tiles[key] = []
			tiles[key].append(i)
		for key: Vector2i in tiles:
			var picked: Array = tiles[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = picked.size()
			var summer := PackedColorArray()
			for j in picked.size():
				mm.set_instance_transform(j, xf[picked[j]])
				mm.set_instance_color(j, data.colours[picked[j]])
				summer.append(data.colours[picked[j]])
			var node := MultiMeshInstance3D.new()
			node.name = "Leaves_%d_%d_%s" % [key.x, key.y, shape]
			node.multimesh = mm
			node.set_meta("summer", summer)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visibility_range_end = DETAIL_RANGE if shape == BERRY or shape == BLOOM else AgedStone.LEAF_RANGE
			root.add_child(node)


# --- Textures ---------------------------------------------------------------------------------------------

## The material of a leaf shape: its textured card, tinted by the instance colour.
static func material(shape: String) -> StandardMaterial3D:
	if _mats.has(shape):
		return _mats[shape]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture(shape)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.35 if shape == BERRY else (0.55 if shape == OVAL else 0.75)
	mat.set_meta("snow_cling", IvySeasons.SNOW_CLING)
	_mats[shape] = mat
	return mat


## A cheap hash noise in 0..1 for a pixel, for mottling.
static func _noise(x: int, y: int, seed_: int) -> float:
	return float(posmod(hash(Vector3i(x, y, seed_)), 1000)) / 1000.0


## The texture of a leaf shape, in greys (the instance colour tints it): leaf cards stand with the stem at
## the bottom middle, like AgedStone.leaf_material's.
static func texture(shape: String) -> ImageTexture:
	var size := 96 if shape == NEEDLE else 64
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) / float(size) - Vector2(0.5, 0.0)
			var v := _pixel(shape, p, x, y)
			img.set_pixel(x, y, Color(v, v, v, 1.0) if v >= 0.0 else Color(0.5, 0.5, 0.5, 0.0))
	# Coloured parts (the heart of a bloom) are painted over the greys.
	if shape == BLOOM:
		for y in size:
			for x in size:
				var q := Vector2(x + 0.5, y + 0.5) / float(size) - Vector2(0.5, 0.5)
				if q.length() < 0.09:
					var c := img.get_pixel(x, y)
					if c.a > 0.5:
						img.set_pixel(x, y, Color(0.95, 0.8, 0.3, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## One pixel of a leaf card: its grey, or -1 outside the leaf. `p` runs -0.5 to 0.5 across, 0 to 1 down.
static func _pixel(shape: String, p: Vector2, x: int, y: int) -> float:
	match shape:
		OVAL:
			return _blade(p, 0.1, 0.9, 0.34, 0.8, 7.0, x, y)
		LANCE:
			return _blade(p, 0.04, 0.95, 0.15, 1.0, 9.0, x, y)
		LOBED:
			return _lobed(p, x, y)
		FEATHER:
			return _feather(p, x, y)
		NEEDLE:
			return _needles(p, x, y)
		BERRY:
			return _berry(p)
		BLOOM:
			return _bloom(p)
	return -1.0


## A simple leaf: pointed at the tip (`top`) and rounded at the stem end (`bottom`), a midrib and slanting
## side veins, darker toward the edge and mottled.
static func _blade(p: Vector2, top: float, bottom: float, half: float, bulge: float, veins: float, x: int, y: int) -> float:
	var t := (bottom - p.y) / (bottom - top)
	if t < -0.06 or t > 1.0:
		return -1.0
	# The little leaf stalk.
	if t < 0.0:
		return 0.55 if absf(p.x) < 0.02 else -1.0
	var w := half * pow(sin(PI * pow(t, bulge * 0.85)), 0.75)
	var edge := absf(p.x) / maxf(w, 0.001)
	if edge > 1.0:
		return -1.0
	var shade := 0.82 + 0.18 * (1.0 - edge * edge) - 0.12 * pow(edge, 4.0)
	if absf(p.x) < 0.014 * (1.0 - t * 0.5):
		shade = 1.0
	else:
		# Side veins: slanting stripes, lighter than the blade.
		var stripe := absf(fposmod(t * veins - absf(p.x) * 4.0, 1.0) - 0.5)
		shade *= 1.0 - 0.16 * smoothstep(0.42, 0.5, stripe)
	shade *= 0.93 + 0.14 * _noise(x / 2, y / 2, 3)
	return clampf(shade, 0.0, 1.0)


## A lobed leaf with toothed edge and veins running out into each of its five lobes.
static func _lobed(p: Vector2, x: int, y: int) -> float:
	var q := Vector2(p.x, 0.88 - p.y)
	var a := atan2(q.x, q.y)
	var r := q.length()
	var lobes := 0.25 + 0.2 * pow(absf(cos(a * 2.5)), 2.0) + 0.02 * sin(a * 36.0)
	if r > lobes or absf(a) > 2.2 or q.y < -0.06:
		return -1.0
	var vein := absf(fposmod(a * 2.5 / PI * 2.0 + 0.5, 1.0) - 0.5)
	var shade := 0.84 + 0.16 * (1.0 - r / maxf(lobes, 0.01))
	shade *= 1.0 - 0.2 * smoothstep(0.1, 0.0, vein) * smoothstep(0.05, 0.2, r)
	shade *= 0.92 + 0.16 * _noise(x / 2, y / 2, 5)
	return clampf(shade, 0.0, 1.0)


## A feathered leaf: a stalk with pairs of small oval leaflets and one at the tip.
static func _feather(p: Vector2, x: int, y: int) -> float:
	if absf(p.x) < 0.012 and p.y > 0.05 and p.y < 0.95:
		return 0.6
	for pair in 4:
		var cy := 0.78 - float(pair) * 0.19
		for side in [-1.0, 1.0]:
			var c := Vector2(float(side) * 0.17, cy - 0.04)
			var d := p - c
			# Tilted toward the tip.
			d = d.rotated(float(side) * 0.55)
			var e := (d.x * d.x) / (0.15 * 0.15) + (d.y * d.y) / (0.07 * 0.07)
			if e < 1.0:
				return clampf((0.78 + 0.2 * (1.0 - e)) * (0.93 + 0.14 * _noise(x / 2, y / 2, 7)) * (1.0 - (0.18 if absf(d.y) < 0.008 else 0.0)), 0.0, 1.0)
	var tip := p - Vector2(0.0, 0.1)
	if (tip.x * tip.x) / (0.07 * 0.07) + (tip.y * tip.y) / (0.1 * 0.1) < 1.0:
		return 0.9
	return -1.0


## A feathery spray of needles: a woody stalk with short needles all along it, longest in the middle.
static func _needles(p: Vector2, x: int, y: int) -> float:
	if absf(p.x) < 0.012 and p.y > 0.02 and p.y < 0.95:
		return 0.5
	var best := -1.0
	for i in 12:
		var along := 0.08 + float(i) * 0.07
		var reach := 0.34 * sin(PI * clampf((along - 0.04) / 0.9, 0.0, 1.0)) + 0.05
		for side in [-1.0, 1.0]:
			# A needle leaves the stalk slanting toward the tip.
			var from := Vector2(0.0, 1.0 - along)
			var to := from + Vector2(float(side) * reach, -reach * 0.55)
			var seg := to - from
			var tt := clampf((p - from).dot(seg) / seg.length_squared(), 0.0, 1.0)
			var d := p.distance_to(from + seg * tt)
			if d < 0.045 * (1.0 - tt * 0.5):
				best = maxf(best, 0.62 + 0.38 * tt)
	if best < 0.0:
		return -1.0
	return clampf(best * (0.9 + 0.14 * _noise(x, y, 11)), 0.0, 1.0)


## A berry: a round ball, bright where it catches the light at the top left, dark at the rim.
static func _berry(p: Vector2) -> float:
	var q := p - Vector2(0.0, 0.5)
	var r := q.length()
	if r > 0.42:
		return -1.0
	var lit := clampf(1.0 - (q - Vector2(-0.1, -0.12)).length() / 0.5, 0.0, 1.0)
	var v := 0.5 + 0.5 * lit - 0.25 * pow(r / 0.42, 3.0)
	if (q - Vector2(-0.12, -0.14)).length() < 0.07:
		v = 1.0
	return clampf(v, 0.2, 1.0)


## A five-petalled bloom, white (the instance colour tints it) with a pale cleft in each petal.
static func _bloom(p: Vector2) -> float:
	var q := p - Vector2(0.0, 0.5)
	var r := q.length()
	var a := atan2(q.y, q.x)
	var petals := 0.3 + 0.13 * pow(absf(cos(a * 2.5)), 1.5)
	if r > petals:
		return -1.0
	var cleft := absf(fposmod(a * 5.0 / TAU, 1.0) - 0.5)
	var v := 0.82 + 0.18 * (1.0 - r / petals) - 0.15 * smoothstep(0.12, 0.0, cleft) * smoothstep(0.05, 0.25, r)
	return clampf(v, 0.0, 1.0)
