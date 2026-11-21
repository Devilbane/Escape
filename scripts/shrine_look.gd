class_name ShrineLook
extends RefCounted
## The look of a household goddess's shrine (see HouseholdGods): a small marble aedicula on a
## polished walnut foot, finished like a piece from a master's workshop.
##
##   foot       polished walnut with a gilt band
##   plinth     veined marble with a carved relief on its front (a medallion with the winged
##              goddess between two acanthus scrolls), bead-and-reel trim in gilt
##   niche      a back wall of lapis lazuli with gold flecks, gilt filigree lace over it and
##              between the columns at the sides
##   columns    fluted marble shafts on gilt bases, under gilt capitals
##   roof       a marble entablature and pediment, a gilt rosette in the gable, gilt finials
##   goddess    veined marble on a gilt-ringed pedestal, a gilt girdle, wings of gilt feathers,
##              a halo with a sunburst of rays; two candles in gilt holders at her feet
##
## Every texture is painted once in code (marble veins, lapis, feathers, the relief and the
## filigree lace, each with its own normal map for the carving) and kept for every later shrine.

## The front edge of the shrine's middle, from the piece's middle (metres, see build).
const DEPTH := -0.45
const GOLD := Color(0.96, 0.76, 0.36)
const WALNUT := Color(0.42, 0.26, 0.16)
const LAPIS := Color(0.09, 0.15, 0.45)

## Textures and materials, made once.
static var _cache := {}


# --- Building ---------------------------------------------------------------------

## Builds the shrine into `root` (its front towards +z, its back on the cell's back edge, on the
## floor), the goddess in her own colours (`info`, see HouseholdGods.GODDESSES). Returns its
## solids ({at, size}, local).
static func build(root: Node3D, info: Dictionary) -> Array:
	var z := DEPTH
	var shrine := Node3D.new()
	shrine.name = "Shrine"
	root.add_child(shrine)
	var marble := marble_material(Color(0.97, 0.95, 0.91))
	var statue := marble_material(info.statue)
	var gilt := gilt_material(info.wings)
	var gold := gilt_material(GOLD)
	var wood := walnut_material()
	# The walnut foot with a gilt band along its top.
	_add(shrine, _box(Vector3(1.25, 0.12, 0.95)), wood, Vector3(0, 0.06, z))
	_add(shrine, _box(Vector3(1.27, 0.022, 0.97)), gold, Vector3(0, 0.125, z))
	# The marble plinth, its front carved, beads along its top and foot.
	_add(shrine, _box(Vector3(1.05, 0.62, 0.75)), marble, Vector3(0, 0.45, z))
	var relief := MeshInstance3D.new()
	relief.name = "Relief"
	var face := QuadMesh.new()
	face.size = Vector2(0.94, 0.52)
	relief.mesh = face
	relief.material_override = relief_material()
	relief.position = Vector3(0, 0.45, z + 0.376)
	shrine.add_child(relief)
	_beads(shrine, gold, Vector3(0, 0.765, z + 0.38), 1.0, 0.017)
	_beads(shrine, gold, Vector3(0, 0.155, z + 0.38), 1.0, 0.017)
	_add(shrine, _box(Vector3(1.17, 0.07, 0.87)), marble, Vector3(0, 0.8, z))
	# The niche: lapis behind, filigree lace over it and at the sides.
	_add(shrine, _box(Vector3(1.05, 1.16, 0.08)), lapis_material(), Vector3(0, 1.415, z - 0.33))
	var lace := filigree_material()
	_quad(shrine, Vector2(0.86, 1.0), lace, Vector3(0, 1.43, z - 0.285), 0.0, Vector3(2, 1, 1))
	for side: float in [-1.0, 1.0]:
		_quad(shrine, Vector2(0.56, 1.0), lace, Vector3(side * 0.505, 1.43, z - 0.01), side * PI * 0.5, Vector3(1.2, 1, 1))
	# Two fluted columns on gilt bases under gilt capitals, and two pilasters at the back.
	var fluted := fluted_material()
	for side: float in [-1.0, 1.0]:
		var x := side * 0.44
		for at_z: float in [z + 0.28, z - 0.25]:
			_add(shrine, _cylinder(0.075, 0.085, 0.05, 20), gold, Vector3(x, 0.86, at_z))
			_add(shrine, _cylinder(0.052, 0.058, 1.02, 20), fluted, Vector3(x, 1.395, at_z))
			_add(shrine, _cylinder(0.085, 0.058, 0.06, 20), gold, Vector3(x, 1.935, at_z))
			_add(shrine, _box(Vector3(0.17, 0.03, 0.17)), marble, Vector3(x, 1.98, at_z))
	# The entablature: a gilt frieze between marble bands, beads under the cornice.
	_add(shrine, _box(Vector3(1.17, 0.07, 0.82)), marble, Vector3(0, 2.03, z))
	_add(shrine, _box(Vector3(1.19, 0.035, 0.84)), gold, Vector3(0, 2.082, z))
	_beads(shrine, gold, Vector3(0, 2.1, z + 0.425), 1.18, 0.014)
	_add(shrine, _box(Vector3(1.3, 0.05, 0.92)), marble, Vector3(0, 2.125, z))
	# The pediment with a gilt rosette in its gable and three gilt finials.
	var roof := PrismMesh.new()
	roof.size = Vector3(1.3, 0.34, 0.9)
	_add(shrine, roof, marble, Vector3(0, 2.32, z))
	_rosette(shrine, gold, Vector3(0, 2.26, z + 0.452), 0.075)
	for spot: Vector3 in [Vector3(0, 2.5, z + 0.38), Vector3(-0.62, 2.17, z + 0.4), Vector3(0.62, 2.17, z + 0.4)]:
		_add(shrine, _cylinder(0.025, 0.035, 0.04, 12), gold, spot + Vector3(0, 0.0, 0))
		var cone := _add(shrine, _ball(0.035), gold, spot + Vector3(0, 0.06, 0))
		cone.scale = Vector3(1, 1.7, 1)
	_goddess(shrine, statue, gold, info, Vector3(0, 0.835, z))
	return [{"at": Vector3(0, 0, z), "size": Vector3(1.3, 2.5, 0.97)}]


## The goddess standing on her pedestal at `foot`: a long robe, a girdle, arms raised a little
## in blessing, her head with its hair knot, gilt wings of feathers and a halo with rays.
static func _goddess(shrine: Node3D, statue: Material, gold: Material, info: Dictionary, foot: Vector3) -> void:
	var y := foot.y
	var z := foot.z
	_add(shrine, _cylinder(0.15, 0.17, 0.1, 24), statue, Vector3(0, y + 0.05, z))
	_add(shrine, _torus(0.15, 0.165), gold, Vector3(0, y + 0.1, z))
	# The robe falls in a long bell; the girdle sits high under the breast.
	var robe := draped_material(info.statue)
	_add(shrine, _cylinder(0.07, 0.15, 0.48, 32), robe, Vector3(0, y + 0.34, z))
	_add(shrine, _torus(0.066, 0.08), gold, Vector3(0, y + 0.55, z))
	_add(shrine, _cylinder(0.045, 0.072, 0.14, 32), robe, Vector3(0, y + 0.64, z))
	# A mantle over her shoulders, her hands folded in front.
	var mantle := _add(shrine, _ball(0.085), robe, Vector3(0, y + 0.69, z - 0.005))
	mantle.scale = Vector3(1.05, 0.32, 0.7)
	var hands := _add(shrine, _ball(0.028), statue, Vector3(0, y + 0.58, z + 0.07))
	hands.scale = Vector3(1.3, 1.0, 0.9)
	_add(shrine, _cylinder(0.024, 0.03, 0.05, 12), statue, Vector3(0, y + 0.74, z))
	_add(shrine, _ball(0.062), statue, Vector3(0, y + 0.8, z))
	# Her hair gathered in a knot, under a gilt diadem.
	var hair := _add(shrine, _ball(0.066), statue, Vector3(0, y + 0.815, z - 0.012))
	hair.scale = Vector3(1.0, 0.95, 0.95)
	_add(shrine, _ball(0.035), statue, Vector3(0, y + 0.82, z - 0.07))
	var diadem := _add(shrine, _torus(0.06, 0.068), gold, Vector3(0, y + 0.835, z - 0.005))
	diadem.rotation.x = -0.35
	# Her wings: a broad upper wing and a long pinion below it, of gilt feathers.
	var feathers := feather_material(info.wings)
	for side: float in [-1.0, 1.0]:
		var wing := _add(shrine, _ball(0.22), feathers, Vector3(side * 0.17, y + 0.62, z - 0.08))
		wing.scale = Vector3(0.16, 1.2, 0.55)
		wing.rotation = Vector3(0, side * 0.35, -side * 0.5)
		var pinion := _add(shrine, _ball(0.2), feathers, Vector3(side * 0.13, y + 0.42, z - 0.1))
		pinion.scale = Vector3(0.12, 1.1, 0.4)
		pinion.rotation = Vector3(0, side * 0.3, -side * 0.22)
	# The halo with a sunburst of rays behind her head.
	var halo := _add(shrine, _torus(0.1, 0.118), gold, Vector3(0, y + 0.83, z - 0.1))
	halo.rotation.x = PI * 0.5
	for i in 16:
		var a := TAU * i / 16.0
		var long := 0.07 if i % 2 == 0 else 0.045
		var ray := _add(shrine, _cylinder(0.004, 0.007, long, 6), gold, Vector3(0, y + 0.83, z - 0.105) + Vector3(cos(a), sin(a), 0) * (0.12 + long * 0.5))
		ray.rotation.z = a - PI * 0.5
	# Two candles in gilt holders at her feet.
	var wax := HomeStoreFurniture._mat(Color(0.95, 0.92, 0.82), 0.6)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.75, 0.3)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.7, 0.25)
	glow.emission_energy_multiplier = 3.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 0.32, y, z + 0.22)
		_add(shrine, _cylinder(0.045, 0.03, 0.035, 14), gold, at + Vector3(0, 0.018, 0))
		_add(shrine, _torus(0.04, 0.05), gold, at + Vector3(0, 0.038, 0))
		_add(shrine, _cylinder(0.026, 0.026, 0.12, 12), wax, at + Vector3(0, 0.1, 0))
		var flame := _add(shrine, _ball(0.018), glow, at + Vector3(0, 0.18, 0))
		flame.scale = Vector3(1, 1.8, 1)


## A row of gilt beads, `width` long, centred on `at`, across x.
static func _beads(parent: Node3D, mat: Material, at: Vector3, width: float, radius: float) -> void:
	var count := int(width / (radius * 2.6))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _ball(radius)
	multi.instance_count = count
	for i in count:
		var x := -width * 0.5 + width * (i + 0.5) / count
		# Bead and reel: a round bead, then a flat one.
		var s := Vector3.ONE if i % 2 == 0 else Vector3(0.55, 0.8, 0.8)
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(s), Vector3(x, 0, 0)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = mat
	node.position = at
	parent.add_child(node)


## A gilt rosette facing +z: a ring of eight petals round a boss.
static func _rosette(parent: Node3D, mat: Material, at: Vector3, radius: float) -> void:
	var ring := _add(parent, _torus(radius * 0.8, radius), mat, at)
	ring.rotation.x = PI * 0.5
	for i in 8:
		var a := TAU * i / 8.0
		var petal := _add(parent, _ball(radius * 0.32), mat, at + Vector3(cos(a), sin(a), 0) * radius * 0.5)
		petal.scale = Vector3(0.7, 1.4, 0.5)
		petal.rotation.z = a - PI * 0.5
	_add(parent, _ball(radius * 0.28), mat, at + Vector3(0, 0, 0.01))


static func _add(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	return HomeStoreFurniture._add(parent, mesh, mat, at)


static func _quad(parent: Node3D, size: Vector2, mat: StandardMaterial3D, at: Vector3, turn: float, tiles: Vector3) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	var own := mat.duplicate() as StandardMaterial3D
	own.uv1_scale = tiles
	var mi := _add(parent, mesh, own, at)
	mi.rotation.y = turn


static func _box(size: Vector3) -> BoxMesh:
	return HomeStoreFurniture._box(size)


static func _cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var mesh := HomeStoreFurniture._cylinder(top, bottom, height)
	mesh.radial_segments = segments
	return mesh


## A smooth sphere (the furniture's own is coarse for small statues).
static func _ball(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh


static func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	return mesh


# --- Materials --------------------------------------------------------------------

## Polished white marble with grey veins, tinted.
static func marble_material(tint: Color) -> StandardMaterial3D:
	var key := "marble:" + tint.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _marble_textures()[0]
		m.albedo_color = tint
		m.normal_enabled = true
		m.normal_texture = _marble_textures()[1]
		m.normal_scale = 0.5
		m.roughness = 0.25
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 1.6
		_cache[key] = m
	return _cache[key]


## Gold leaf, a little hammered.
static func gilt_material(colour: Color) -> StandardMaterial3D:
	var key := "gilt:" + colour.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour.lightened(0.15)
		m.metallic = 0.7
		m.roughness = 0.32
		m.normal_enabled = true
		m.normal_texture = _hammered()
		m.normal_scale = 0.35
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 6.0
		_cache[key] = m
	return _cache[key]


## Polished walnut: the house's oak floor, darker, under a clear coat.
static func walnut_material() -> StandardMaterial3D:
	if not _cache.has("walnut"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/house/wood_floor.jpg")
		m.albedo_color = WALNUT
		m.roughness = 0.45
		m.clearcoat_enabled = true
		m.clearcoat = 0.6
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 1.2
		_cache["walnut"] = m
	return _cache["walnut"]


## Deep blue lapis lazuli with white clouds and gold flecks of pyrite.
static func lapis_material() -> StandardMaterial3D:
	if not _cache.has("lapis"):
		var size := 128
		var clouds := _noise(31, 0.03, size)
		var flecks := _noise(32, 0.25, size)
		var img := Image.create(size, size, false, Image.FORMAT_RGB8)
		for y in size:
			for x in size:
				var c := LAPIS.lerp(Color(0.2, 0.32, 0.68), clouds.get_pixel(x, y).r * 0.8)
				if clouds.get_pixel(x, y).r > 0.82:
					c = c.lerp(Color(0.75, 0.78, 0.85), (clouds.get_pixel(x, y).r - 0.82) * 2.5)
				if flecks.get_pixel(x, y).r > 0.86:
					c = GOLD
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.roughness = 0.3
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 1.5
		_cache["lapis"] = m
	return _cache["lapis"]


## Fluted marble for the columns: twelve flutes round the shaft.
static func fluted_material() -> StandardMaterial3D:
	if not _cache.has("fluted"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _marble_textures()[0]
		m.albedo_color = Color(0.97, 0.95, 0.91)
		m.normal_enabled = true
		m.normal_texture = _flutes(12, 5.0)
		m.roughness = 0.25
		_cache["fluted"] = m
	return _cache["fluted"]


## The statue's robe: marble falling in soft folds.
static func draped_material(tint: Color) -> StandardMaterial3D:
	var key := "draped:" + tint.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _marble_textures()[0]
		m.albedo_color = tint
		m.normal_enabled = true
		m.normal_texture = _flutes(18, 3.0)
		m.roughness = 0.28
		_cache[key] = m
	return _cache[key]


## Upright grooves round a cylinder (`count` of them), as a normal map.
static func _flutes(count: int, strength: float) -> ImageTexture:
	var key := "flutes:%d:%s" % [count, strength]
	if not _cache.has(key):
		var w := 16 * count
		var h := 8
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for x in w:
			var t := 0.5 + 0.5 * cos(float(x) / w * TAU * count)
			for y in h:
				img.set_pixel(x, y, Color(t, t, t))
		img.bump_map_to_normal_map(strength)
		img.generate_mipmaps()
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## The carved front of the plinth: veined marble, the relief's hollows a little shadowed.
static func relief_material() -> StandardMaterial3D:
	if not _cache.has("relief"):
		var w := 288
		var h := 160
		var height := _relief_heights(w, h)
		var veins: Image = _marble_textures()[2]
		var albedo := Image.create(w, h, false, Image.FORMAT_RGB8)
		var bump := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var v: float = height[y * w + x]
				var stone := veins.get_pixel(x % veins.get_width(), y % veins.get_height())
				albedo.set_pixel(x, y, stone * (0.6 + 0.4 * v))
				bump.set_pixel(x, y, Color(v, v, v))
		bump.bump_map_to_normal_map(7.0)
		albedo.generate_mipmaps()
		bump.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(albedo)
		m.albedo_color = Color(0.97, 0.95, 0.91)
		m.normal_enabled = true
		m.normal_texture = ImageTexture.create_from_image(bump)
		m.roughness = 0.3
		_cache["relief"] = m
	return _cache["relief"]


## Gilt filigree lace: scrolls curling off a stem, in a frame, open between the wires.
static func filigree_material() -> StandardMaterial3D:
	if not _cache.has("filigree"):
		var w := 128
		var h := 256
		var mask := _filigree_mask(w, h)
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var bump := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var v: float = mask[y * w + x]
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if v > 0.35 else 0.0))
				bump.set_pixel(x, y, Color(v, v, v))
		bump.bump_map_to_normal_map(4.0)
		img.generate_mipmaps()
		bump.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.albedo_color = GOLD.lightened(0.15)
		m.metallic = 0.7
		m.roughness = 0.3
		m.normal_enabled = true
		m.normal_texture = ImageTexture.create_from_image(bump)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache["filigree"] = m
	return _cache["filigree"]


## Gilt feathers for the wings: rows of overlapping feathers, each with its quill.
static func feather_material(colour: Color) -> StandardMaterial3D:
	var key := "feathers:" + colour.to_html()
	if not _cache.has(key):
		if not _cache.has("feather_normals"):
			var size := 128
			var cell := 16
			var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
			for y in size:
				for x in size:
					var row := y / cell
					var cx := (x + (cell / 2 if row % 2 == 1 else 0)) % cell - cell * 0.5
					var cy := float(y % cell)
					# Each feather is a dome, rounded at its tip (the bottom of the cell).
					var d := (cx * cx) / (cell * cell * 0.3) + pow(cy / cell, 2.0) * 0.9
					var v := clampf(1.0 - d, 0.0, 1.0)
					if absf(cx) < 0.8:
						v = maxf(v, 0.75)
					img.set_pixel(x, y, Color(v, v, v))
			img.bump_map_to_normal_map(6.0)
			img.generate_mipmaps()
			_cache["feather_normals"] = ImageTexture.create_from_image(img)
		var m := StandardMaterial3D.new()
		m.albedo_color = colour.lightened(0.15)
		m.metallic = 0.7
		m.roughness = 0.32
		m.normal_enabled = true
		m.normal_texture = _cache["feather_normals"]
		m.uv1_scale = Vector3(4, 3, 1)
		_cache[key] = m
	return _cache[key]


# --- Painted textures -------------------------------------------------------------

## Tileable noise, 0 to 1, as an image.
static func _noise(seed: int, frequency: float, size: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	noise.fractal_octaves = 4
	return noise.get_seamless_image(size, size)


## The marble: [albedo texture, normal texture, albedo image]. Veins run across in waves bent by
## the noise, so the pattern tiles.
static func _marble_textures() -> Array:
	if not _cache.has("marble_tex"):
		var size := 256
		var cloud := _noise(17, 0.012, size)
		var fine := _noise(18, 0.06, size)
		var img := Image.create(size, size, false, Image.FORMAT_RGB8)
		var bump := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var n := cloud.get_pixel(x, y).r
				var phase := TAU * (float(x) / size + float(y) / size) + n * 9.0
				var vein := pow(1.0 - absf(sin(phase)), 14.0)
				var hair := pow(1.0 - absf(sin(phase * 2.0 + fine.get_pixel(x, y).r * 6.0)), 30.0) * 0.5
				var c := Color(0.95, 0.94, 0.91).darkened((n - 0.5) * 0.1)
				c = c.lerp(Color(0.5, 0.5, 0.53), clampf(vein * 0.75 + hair * 0.5, 0.0, 1.0))
				img.set_pixel(x, y, c)
				var hgt := 1.0 - vein * 0.25
				bump.set_pixel(x, y, Color(hgt, hgt, hgt))
		var plain := img.duplicate() as Image
		img.generate_mipmaps()
		bump.bump_map_to_normal_map(2.0)
		bump.generate_mipmaps()
		_cache["marble_tex"] = [ImageTexture.create_from_image(img), ImageTexture.create_from_image(bump), plain]
	return _cache["marble_tex"]


## Small dents of beaten gold leaf, as a normal map.
static func _hammered() -> ImageTexture:
	if not _cache.has("hammered"):
		var img := _noise(23, 0.09, 64)
		img.convert(Image.FORMAT_RGBA8)
		img.bump_map_to_normal_map(1.5)
		img.generate_mipmaps()
		_cache["hammered"] = ImageTexture.create_from_image(img)
	return _cache["hammered"]


## The relief's heights (0 to 1): a raised frame with a groove inside, a medallion in the middle
## with the winged goddess, and an acanthus scroll curling out on each side.
static func _relief_heights(w: int, h: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	out.fill(0.35)
	var paint := func(at: Vector2, radius: float, height: float) -> void:
		for y in range(maxi(0, int(at.y - radius - 1)), mini(h, int(at.y + radius + 2))):
			for x in range(maxi(0, int(at.x - radius - 1)), mini(w, int(at.x + radius + 2))):
				var d := Vector2(x, y).distance_to(at)
				if d <= radius:
					var v := height * sqrt(1.0 - (d / radius) * (d / radius) * 0.6)
					out[y * w + x] = maxf(out[y * w + x], v)
	var line := func(a: Vector2, b: Vector2, radius: float, height: float) -> void:
		var steps := maxi(1, int(a.distance_to(b) / maxf(1.0, radius * 0.5)))
		for i in steps + 1:
			paint.call(a.lerp(b, float(i) / steps), radius, height)
	# The frame and its groove.
	for y in h:
		for x in w:
			var edge := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			if edge < 9:
				out[y * w + x] = 0.95 - edge * 0.02
			elif edge < 13:
				out[y * w + x] = 0.1
	var c := Vector2(w * 0.5, h * 0.5)
	# The medallion: a rim and a sunken field.
	for y in h:
		for x in w:
			var d := Vector2(x, y).distance_to(c)
			if d < 44.0 and d > 37.0:
				out[y * w + x] = 0.9
			elif d <= 37.0:
				out[y * w + x] = 0.25
	# The goddess: robe, head, and wings of five feathers on each side.
	line.call(c + Vector2(0, -12), c + Vector2(0, 26), 5.0, 0.85)
	paint.call(c + Vector2(0, 26), 9.0, 0.7)
	paint.call(c + Vector2(0, -20), 6.0, 0.9)
	for side: float in [-1.0, 1.0]:
		for i in 5:
			var a := deg_to_rad(-60.0 + i * 22.0)
			var dir := Vector2(cos(a) * side, sin(a))
			line.call(c + Vector2(side * 4, -8), c + Vector2(side * 4, -8) + dir * (30.0 - i * 3.0), 2.6, 0.8)
	# The scrolls: a stem from the medallion, curling into a spiral with leaves along it.
	for side: float in [-1.0, 1.0]:
		var centre := c + Vector2(side * 92.0, 4.0)
		var prev := c + Vector2(side * 44.0, 0.0)
		for i in 60:
			var t := float(i) / 59.0 * 3.2 * PI
			var r := 34.0 * (1.0 - t / (3.6 * PI))
			var p := centre + Vector2(-side * cos(t) * r, -sin(t) * r)
			line.call(prev, p, 3.2, 0.85)
			if i % 8 == 4:
				paint.call(p + (p - centre).normalized() * 7.0, 4.5, 0.7)
			prev = p
		paint.call(prev, 6.0, 0.9)
	# Smooth the carving's edges a little.
	for pass_i in 2:
		var soft := out.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var sum := 0.0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						sum += soft[(y + dy) * w + x + dx]
				out[y * w + x] = sum / 9.0
	return out


## The lace (0 to 1 where gold is): a frame, a stem up the middle with mirrored scrolls off it,
## rings and a quatrefoil at the top. Tiles side by side.
static func _filigree_mask(w: int, h: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	out.fill(0.0)
	var dot := func(at: Vector2, radius: float) -> void:
		for y in range(maxi(0, int(at.y - radius - 1)), mini(h, int(at.y + radius + 2))):
			for x in range(maxi(0, int(at.x - radius - 1)), mini(w, int(at.x + radius + 2))):
				var d := Vector2(x, y).distance_to(at)
				if d <= radius:
					out[y * w + x] = maxf(out[y * w + x], sqrt(1.0 - d / radius))
	var wire := func(a: Vector2, b: Vector2, radius: float) -> void:
		var steps := maxi(1, int(a.distance_to(b)))
		for i in steps + 1:
			dot.call(a.lerp(b, float(i) / steps), radius)
	var ring := func(at: Vector2, r: float, radius: float) -> void:
		for i in 48:
			wire.call(at + Vector2.from_angle(TAU * i / 48.0) * r, at + Vector2.from_angle(TAU * (i + 1) / 48.0) * r, radius)
	var cx := w * 0.5
	# The frame (half a frame on each side, so tiles meet in one wire).
	wire.call(Vector2(1, 1), Vector2(w - 2, 1), 2.2)
	wire.call(Vector2(1, h - 2), Vector2(w - 2, h - 2), 2.2)
	wire.call(Vector2(1, 1), Vector2(1, h - 2), 2.2)
	wire.call(Vector2(w - 2, 1), Vector2(w - 2, h - 2), 2.2)
	# The stem.
	wire.call(Vector2(cx, 40), Vector2(cx, h - 6), 2.0)
	# Scrolls in four tiers, each a C-curl ending in a little spiral, mirrored.
	for tier in 4:
		var base := Vector2(cx, 64 + tier * 48)
		for side: float in [-1.0, 1.0]:
			var centre := base + Vector2(side * 30, -10)
			var prev := base
			for i in 40:
				var t := float(i) / 39.0 * 2.6 * PI
				var r := 22.0 * (1.0 - t / (3.0 * PI))
				var p := centre + Vector2(-side * cos(t) * r, sin(t) * r)
				wire.call(prev, p, 1.6)
				prev = p
			dot.call(prev, 3.0)
		dot.call(base, 3.5)
	# A quatrefoil at the top with a ring round it.
	var top := Vector2(cx, 26)
	for i in 4:
		ring.call(top + Vector2.from_angle(TAU * i / 4.0 + PI * 0.25) * 8.0, 7.0, 1.4)
	ring.call(top, 20.0, 1.6)
	dot.call(top, 3.0)
	return out
