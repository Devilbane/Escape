class_name CoinPile
extends RefCounted
## Coins lying on the floor pile up: all coins of one metal that come down on
## the same spot (spilt from a purse, dropped by the fallen, put down by the
## hero) join one pile instead of lying about one by one. The more coins a
## pile holds, the bigger it is (a lone coin, a few coins, a stack, a heap),
## the more it glints and the faster it blinks. Every pile glows faintly in its
## metal's own colour, so it can be found in the dark, and that glow swells
## and fades slowly.
##
## A pile is one entry on the level's floor list (see Level.floor_items):
## ["coin", metal, x, z, count, own], where `own` is how many of the coins the
## hero put down themselves (the lucky clover doubles only what is found).
## Older saves have ["coin", "", x, z]: one gold coin.
##
## Kept cheap like CoinShine: one model per pile whatever its size, shared
## materials (per source, metal and size step), the glints and the glow are
## particle systems that never move, and nothing adds a light.

## The most coins one pile holds; more on the same spot start a new pile
## beside it.
const MAX := 10000
## How close (metres) coins must come down to an existing pile to join it.
const JOIN_RADIUS := 1.2

## The metals coins are made of: gold goes into the purse (game.coins), the
## others into the ingredient pouch (Crafting.INGREDIENTS) where they exist.
## Each has its colour (the coins' own tint, their glow and their glints) and
## a German name for the purse.
const GOLD := "goldmuenze"
## The metal of the hero's money: these coins go into the purse
## (game.coins); every other metal into the ingredient pouch.
const MONEY := GOLD
const METALS := {
	"goldmuenze": {"name": "Goldmünzen", "tint": Color(1.0, 0.82, 0.42), "glow": Color(1.0, 0.72, 0.25), "glint": Color(1.0, 0.95, 0.75)},
	"silbermuenze": {"name": "Silbermünzen", "tint": Color(0.7, 0.76, 0.88), "glow": Color(0.7, 0.82, 1.0), "glint": Color(0.92, 0.96, 1.0)},
	"kupfermuenze": {"name": "Kupfermünzen", "tint": Color(0.86, 0.42, 0.24), "glow": Color(1.0, 0.45, 0.22), "glint": Color(1.0, 0.82, 0.7)},
	"eisenmuenze": {"name": "Eisenmünzen", "tint": Color(0.42, 0.44, 0.48), "glow": Color(0.55, 0.72, 0.85), "glint": Color(0.85, 0.9, 0.95)},
}

## Every pile's glow is called this (the tests look for it).
const GLOW := "Glow"
## How far off (metres) a pile's glow is still drawn.
const GLOW_RANGE := 30.0
## Below this many coins they lie loose; from here on they form a heap.
const LOOSE := 6
## The most coin models one heap shows (its coins drawn in one go).
const HEAP_COINS := 140

static var _grey := {}
static var _tinted := {}
static var _halo_mesh := {}
static var _mound_material := {}


## The metal of a floor entry or pickup id ("" is money, from older saves).
static func metal_of(id: String) -> String:
	return id if METALS.has(id) else MONEY


## How many coins a floor entry holds (1 for older saves and loose items).
static func count_of(entry) -> int:
	return int(entry[4]) if entry is Array and entry.size() >= 5 else 1


## How many of those the hero put down themselves.
static func own_of(entry) -> int:
	return clampi(int(entry[5]), 0, count_of(entry)) if entry is Array and entry.size() >= 6 else 0


## How far up the pile is from a lone coin (0) to the biggest (1).
static func fullness(count: int) -> float:
	return clampf(log(float(maxi(count, 1))) / log(float(MAX)), 0.0, 1.0)


## The size of a pile on the floor: its radius in metres.
static func radius(count: int) -> float:
	if count < LOOSE:
		return 0.29 + 0.18 * minf(1.0, (count - 1) / 2.0) + 0.01 * count
	# The coins on the heap's rim stick out a little.
	return heap_radius(count) + 0.14


## The radius of the heap's mound: from a little hill of a few coins to a
## heap as tall as a knee for the most a pile holds.
static func heap_radius(count: int) -> float:
	var t := inverse_lerp(log(float(LOOSE)), log(float(MAX)), log(float(clampi(count, LOOSE, MAX))))
	return lerpf(0.4, 1.25, t)


## How many coin models a heap shows: more the bigger it is, up to HEAP_COINS.
static func heap_coins(count: int) -> int:
	return clampi(int(8.0 + sqrt(float(count)) * 1.3), 10, HEAP_COINS)


## How the glints blink on a pile of `count` coins: how many, how long each
## round lasts (shorter blinks more often), and how much of the round is the
## flash. A lone coin glints now and then; a big heap sparkles all the time.
static func glints_of(count: int) -> Dictionary:
	var t := fullness(count)
	return {
		"amount": clampi(1 + roundi(log(float(maxi(count, 1))) / log(2.0) * 0.7), 1, CoinShine.MAX_GLINTS),
		"lifetime": lerpf(1.8, 0.65, t),
		"pop": lerpf(0.35, 1.0, t),
	}


## How bright a pile glows in the dark (the halo's strongest alpha) and how
## far the glow reaches (metres).
static func glow_of(count: int) -> Dictionary:
	var t := fullness(count)
	return {"alpha": lerpf(0.28, 0.6, t), "size": radius(count) * 2.0 + lerpf(0.9, 2.2, t)}


## Builds what a pile of `count` coins of `metal` looks like into `holder`
## (cleared first): the coins, their glints and the glow under them.
static func dress(holder: Node3D, count: int, metal: String, level: Node) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(holder.get_instance_id())
	var points := PackedVector3Array()
	if count < LOOSE:
		# A few loose coins, the first in the middle, the others leaning on it.
		for i in count:
			var coin: Node3D = level._place("coin", Vector3.ZERO, rng.randf() * TAU, holder)
			coin.scale = Vector3.ONE * 1.6
			if i > 0:
				var angle := TAU * i / maxf(1.0, count - 1.0) + rng.randf_range(-0.4, 0.4)
				coin.position = Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.16, 0.2)
				coin.position.y = 0.04 if i % 2 == 0 else 0.0
				coin.rotation.x = rng.randf_range(-0.2, 0.2)
			points.append(coin.position + Vector3(0, 0.12, 0))
		_tint(holder, metal, count)
	else:
		points = _heap(holder, count, metal, level, rng)
	var look := glints_of(count)
	var glints := CoinShine.make(points, look.amount, look.lifetime, look.pop)
	glints.color_ramp = _tinted_ramp(glints.color_ramp, METALS[metal].glint)
	holder.add_child(glints)
	holder.add_child(_glow(count, metal))


## A heap: a low mound in the metal's colour, covered with the same coins
## that lie loose (one MultiMesh, so a big heap costs one draw), a few slid
## off round its foot. Returns points on its coins for the glints.
static func _heap(holder: Node3D, count: int, metal: String, level: Node, rng: RandomNumberGenerator) -> PackedVector3Array:
	# One coin, as placed and coloured anywhere else, lends its mesh and look.
	var probe: Node3D = level._place("coin", Vector3.ZERO, 0.0, holder)
	_tint(probe, metal, count)
	var mi := probe.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var coin_mesh := mi.mesh
	var coin_look := mi.material_override
	var in_coin := _inside(probe, mi)
	holder.remove_child(probe)
	probe.queue_free()
	var r := heap_radius(count)
	var h := r * 0.5
	var mound := MeshInstance3D.new()
	mound.name = "Mound"
	var shape := SphereMesh.new()
	shape.is_hemisphere = true
	shape.radius = 1.0
	shape.height = 1.0
	shape.radial_segments = 24
	shape.rings = 8
	mound.mesh = shape
	mound.scale = Vector3(r * 0.92, h * 0.9, r * 0.92)
	mound.material_override = _mound(coin_look as StandardMaterial3D, metal)
	holder.add_child(mound)
	var n := heap_coins(count)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = coin_mesh
	mm.instance_count = n
	var points := PackedVector3Array()
	for i in n:
		var around := rng.randf() * TAU
		var pos: Vector3
		var up: Vector3
		if i < n / 8:
			# Slid off: flat on the floor round the foot.
			pos = Vector3(cos(around), 0.0, sin(around)) * r * rng.randf_range(0.95, 1.2)
			up = Vector3.UP
		else:
			# On the mound, spread evenly over its face.
			var polar := acos(rng.randf_range(0.05, 1.0))
			pos = Vector3(sin(polar) * cos(around) * r, cos(polar) * h, sin(polar) * sin(around) * r)
			up = Vector3(pos.x / (r * r), pos.y / (h * h), pos.z / (r * r)).normalized()
			# Coins slump: they lie flatter than the slope.
			up = up.lerp(Vector3.UP, 0.35)
		# Lying on the slope, tilted a little and turned any which way.
		var tilt := Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
		up = (up + tilt).normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		var basis := Basis(side, up, side.cross(up)).rotated(up, rng.randf() * TAU)
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * 1.6), pos) * in_coin)
		if i % 3 == 0:
			points.append(pos + up * 0.08)
	var coins := MultiMeshInstance3D.new()
	coins.name = "Coins"
	coins.multimesh = mm
	coins.material_override = coin_look
	holder.add_child(coins)
	return points


## The mound under a heap's coins: the coins' colour, a shade deeper.
static func _mound(coin: StandardMaterial3D, metal: String) -> StandardMaterial3D:
	if _mound_material.has(coin):
		return _mound_material[coin]
	var m := coin.duplicate() as StandardMaterial3D
	m.albedo_texture = null
	m.emission_texture = null
	m.albedo_color = (METALS[metal].tint as Color).darkened(0.25)
	m.emission = METALS[metal].glow
	m.emission_energy_multiplier *= 0.5
	m.roughness = 0.5
	_mound_material[coin] = m
	return m


## The transform from `node`'s own space to `top`'s.
static func _inside(top: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != top:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## The glints' flash in the metal's own colour.
static func _tinted_ramp(ramp: Gradient, tint: Color) -> Gradient:
	var g := ramp.duplicate() as Gradient
	for i in g.get_point_count():
		var c := g.get_color(i)
		if c.a > 0.5:
			g.set_color(i, Color(tint.r, tint.g, tint.b, c.a))
	return g


## The coins in the metal's own colour, glowing a little more the bigger the
## pile (four steps, so the materials stay few).
static func _tint(holder: Node3D, metal: String, count: int) -> void:
	var step := clampi(int(fullness(count) * 4.0), 0, 3)
	for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		var source := mi.get_active_material(0) as StandardMaterial3D
		if source == null:
			continue
		var key := [source.resource_path if source.resource_path != "" else str(source.get_instance_id()), metal, step]
		if not _tinted.has(key):
			_tinted[key] = _make_tinted(source, metal, step)
		mi.material_override = _tinted[key]


static func _make_tinted(source: StandardMaterial3D, metal: String, step: int) -> StandardMaterial3D:
	var m := source.duplicate() as StandardMaterial3D
	var info: Dictionary = METALS[metal]
	m.emission_enabled = true
	m.emission_energy_multiplier = 0.1 + 0.04 * step
	if metal == GOLD:
		# Already polished by CoinShine: only a warmer glow as the pile grows.
		return m
	if m.albedo_texture != null:
		# The gold texture made grey, then coloured like the metal.
		m.albedo_texture = _greyed(m.albedo_texture)
		m.emission_texture = m.albedo_texture
		m.albedo_color = info.tint
	else:
		m.albedo_color = info.tint
	# Less of the warm torchlight mirrored and a little more of their own
	# glow than gold, so silver, copper and iron keep their colour by a fire.
	m.emission = info.glow
	m.emission_energy_multiplier = 0.1 + 0.03 * step
	m.metallic = 0.4
	m.metallic_specular = 0.5
	return m


static func _greyed(tex: Texture2D) -> Texture2D:
	if _grey.has(tex):
		return _grey[tex]
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	# Small is plenty for a coin, and quick to go over pixel by pixel.
	if img.get_width() > 128:
		img.resize(128, 128 * img.get_height() / img.get_width(), Image.INTERPOLATE_NEAREST)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var v := clampf((c.r * 0.3 + c.g * 0.59 + c.b * 0.11) * 1.15, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, c.a))
	var out := ImageTexture.create_from_image(img)
	_grey[tex] = out
	return out


## The glow under a pile: a soft round light on the floor in the metal's
## colour, swelling and fading slowly (each pile on its own beat). It is
## added onto what is under it, so it shows in the dark and hardly by day.
static func _glow(count: int, metal: String) -> CPUParticles3D:
	var look := glow_of(count)
	var p := CPUParticles3D.new()
	p.name = GLOW
	p.amount = 1
	p.lifetime = lerpf(3.2, 2.2, fullness(count))
	p.preprocess = p.lifetime * (1.0 + randf())
	p.local_coords = true
	p.mesh = _halo(metal)
	p.position.y = 0.04
	p.direction = Vector3.UP
	p.spread = 0.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.scale_amount_min = look.size
	p.scale_amount_max = look.size
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = GLOW_RANGE
	p.visibility_range_end_margin = 3.0
	p.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# A slow breath: dimmer, brighter, dimmer again, round and round.
	var g := Gradient.new()
	var low := Color(1, 1, 1, look.alpha * 0.55)
	g.set_color(0, low)
	g.set_color(1, low)
	g.add_point(0.5, Color(1, 1, 1, look.alpha))
	p.color_ramp = g
	return p


## A flat disc of soft light (1 m across, scaled per pile), one per metal.
static func _halo(metal: String) -> QuadMesh:
	if _halo_mesh.has(metal):
		return _halo_mesh[metal]
	const SIZE := 64
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_LA8)
	for y in SIZE:
		for x in SIZE:
			var u := (x + 0.5) / SIZE * 2.0 - 1.0
			var v := (y + 0.5) / SIZE * 2.0 - 1.0
			var d := sqrt(u * u + v * v)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.albedo_color = METALS[metal].glow
	mat.vertex_color_use_as_albedo = true
	mat.disable_fog = true
	mat.disable_receive_shadows = true
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.material = mat
	_halo_mesh[metal] = mesh
	return mesh
