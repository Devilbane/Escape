class_name BareEarth
extends RefCounted
## The look of bare, dug earth: the floor and walls of a cellar left "bare" in the house
## builder. Not one flat brown but packed soil in several shades, damp darker hollows and
## drier, paler crusts, small grains of grit, a few pebbles and thin dark root threads.
##
## The picture is made once (same every time) and tiles seamlessly; the material spreads it
## over every face by its position in the world, so neighbouring squares and the walls join
## without seams. One material is shared by every bare face, so it costs no more than the
## flat colour did.

const SIZE := 256
## How many metres one copy of the picture covers.
const METRES := 1.6

const DAMP := Color(0.2, 0.15, 0.1)
const SOIL := Color(0.3, 0.23, 0.16)
const DRY := Color(0.42, 0.35, 0.27)
const CLAY := Color(0.38, 0.26, 0.17)
const GRIT := Color(0.55, 0.47, 0.37)
const ROOT := Color(0.19, 0.13, 0.08)
const PEBBLES := [Color(0.5, 0.47, 0.42), Color(0.42, 0.38, 0.33), Color(0.58, 0.52, 0.44), Color(0.36, 0.33, 0.3)]

static var _tex: Texture2D = null
static var _normal: Texture2D = null
static var _mat: StandardMaterial3D = null


## The shared material for bare earth.
static func material() -> StandardMaterial3D:
	if _mat:
		return _mat
	_build()
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = _tex
	_mat.normal_enabled = true
	_mat.normal_texture = _normal
	_mat.normal_scale = 0.8
	_mat.roughness = 0.95
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat.uv1_triplanar = true
	_mat.uv1_world_triplanar = true
	_mat.uv1_triplanar_sharpness = 4.0
	_mat.uv1_scale = Vector3.ONE / METRES
	return _mat


## The colour picture (for tests and previews).
static func texture() -> Texture2D:
	if not _tex:
		_build()
	return _tex


static func _noise(seed_: int, frequency: float, octaves: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_octaves = octaves
	return n.get_seamless_image(SIZE, SIZE)


static func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90211
	# Seamless noise comes from the engine in one go; only the mixing below runs per pixel.
	var broad := _noise(11, 0.006, 4) # damp hollows and dry crusts
	var clay := _noise(23, 0.009, 3) # reddish clay showing through
	var fine := _noise(37, 0.12, 3) # the crumbly surface
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var b := broad.get_pixel(x, y).r
			var c := clay.get_pixel(x, y).r
			var f := fine.get_pixel(x, y).r
			var col := SOIL
			col = col.lerp(DAMP, smoothstep(0.52, 0.2, b) * 0.6)
			col = col.lerp(DRY, smoothstep(0.5, 0.85, b) * 0.6)
			col = col.lerp(CLAY, smoothstep(0.55, 0.85, c) * 0.4)
			col = col.lightened((f - 0.5) * 0.28) if f > 0.5 else col.darkened((0.5 - f) * 0.35)
			img.set_pixel(x, y, col)
			height.set_pixel(x, y, Color(b * 0.35 + f * 0.65, 0, 0))
	# Grit: single pale or dark grains.
	for i in 1400:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		var light := rng.randf() < 0.6
		var col := img.get_pixel(x, y).lerp(GRIT if light else DAMP, rng.randf_range(0.35, 0.7))
		img.set_pixel(x, y, col)
		height.set_pixel(x, y, Color(0.9 if light else 0.2, 0, 0))
	# Roots: thin dark threads that wander across, sunk into the soil.
	for i in 6:
		var p := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
		var heading := rng.randf() * TAU
		var steps := rng.randi_range(40, 110)
		var thick := rng.randf() < 0.3
		for s in steps:
			heading += rng.randf_range(-0.35, 0.35)
			p += Vector2.from_angle(heading)
			var fade := 1.0 - float(s) / float(steps) * 0.6
			_dot(img, height, p, 0.9 if not thick else 1.6, ROOT, 0.8 * fade, 0.25)
			if rng.randf() < 0.04: # a hair root branching off
				var q := p
				var h2 := heading + rng.randf_range(-1.2, 1.2)
				for k in rng.randi_range(6, 16):
					h2 += rng.randf_range(-0.4, 0.4)
					q += Vector2.from_angle(h2)
					_dot(img, height, q, 0.5, ROOT, 0.5 * fade, 0.3)
	# Pebbles: small rounded stones, lit from above with a dark rim where they sit in the soil.
	for i in 34:
		var centre := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
		var r := rng.randf_range(2.5, 5.5) if rng.randf() < 0.8 else rng.randf_range(6.5, 10.0)
		var squash := rng.randf_range(0.6, 1.0)
		var turn := rng.randf() * TAU
		var stone: Color = PEBBLES[rng.randi() % PEBBLES.size()]
		var reach := int(ceil(r)) + 1
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var local := Vector2(dx, dy).rotated(-turn)
				var d := Vector2(local.x / r, local.y / (r * squash)).length()
				if d > 1.25:
					continue
				var px := posmod(int(centre.x) + dx, SIZE)
				var py := posmod(int(centre.y) + dy, SIZE)
				var under := img.get_pixel(px, py)
				if d > 1.0:
					img.set_pixel(px, py, under.lerp(DAMP, 0.5)) # the shadowed rim
					continue
				var dome := sqrt(1.0 - d * d)
				var lit := clampf(0.55 + dome * 0.3 - float(dy) / r * 0.25, 0.3, 1.1)
				img.set_pixel(px, py, (stone * lit).lerp(under, 0.12))
				height.set_pixel(px, py, Color(0.55 + dome * 0.45, 0, 0))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	height.convert(Image.FORMAT_RGBA8)
	height.bump_map_to_normal_map(6.0)
	height.generate_mipmaps()
	_normal = ImageTexture.create_from_image(height)


## A soft round dot on the colour and height pictures, wrapping round the edges.
static func _dot(img: Image, height: Image, at: Vector2, radius: float, colour: Color, strength: float, depth: float) -> void:
	var reach := int(ceil(radius))
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var d := Vector2(dx, dy).length() / maxf(radius, 0.01)
			if d > 1.0:
				continue
			var px := posmod(int(at.x) + dx, SIZE)
			var py := posmod(int(at.y) + dy, SIZE)
			var a := strength * (1.0 - d * 0.5)
			img.set_pixel(px, py, img.get_pixel(px, py).lerp(colour, a))
			var h := height.get_pixel(px, py).r
			height.set_pixel(px, py, Color(lerpf(h, depth, a), 0, 0))
