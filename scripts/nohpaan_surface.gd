class_name NohpaanSurface
extends RefCounted
## The painted surfaces of Nohpaan (see Nohpaan): limewashed plaster, red roof tiles, timber, slate flags,
## cedar bark and needles, rhododendron leaves, woven prayer cloth. Each is a small texture drawn once in
## code from noise (so no part of the valley is a flat colour) and cached, with a material built on it.

const SIZE := 128

static var _textures := {}
static var _materials := {}

## Per kind: the light and the dark colour of the texture and how it is drawn (see _paint).
const KINDS := {
	"plaster": {"light": Color(0.93, 0.9, 0.82), "dark": Color(0.66, 0.62, 0.54), "pattern": "stains", "scale": 0.05},
	"plinth": {"light": Color(0.6, 0.58, 0.54), "dark": Color(0.3, 0.29, 0.28), "pattern": "blocks", "scale": 0.09},
	"roof": {"light": Color(0.62, 0.22, 0.14), "dark": Color(0.28, 0.09, 0.06), "pattern": "tiles", "scale": 0.06},
	"timber": {"light": Color(0.5, 0.17, 0.11), "dark": Color(0.2, 0.07, 0.05), "pattern": "grain", "scale": 0.05},
	"wood": {"light": Color(0.5, 0.36, 0.22), "dark": Color(0.22, 0.15, 0.09), "pattern": "grain", "scale": 0.05},
	"slate": {"light": Color(0.5, 0.5, 0.52), "dark": Color(0.24, 0.25, 0.28), "pattern": "flags", "scale": 0.07},
	"bark": {"light": Color(0.42, 0.3, 0.2), "dark": Color(0.14, 0.09, 0.06), "pattern": "grain", "scale": 0.1},
	"needles": {"light": Color(0.22, 0.4, 0.24), "dark": Color(0.06, 0.15, 0.1), "pattern": "needles", "scale": 0.16},
	"leaf": {"light": Color(0.3, 0.5, 0.2), "dark": Color(0.08, 0.2, 0.08), "pattern": "leaves", "scale": 0.12},
	"copper": {"light": Color(0.85, 0.55, 0.3), "dark": Color(0.35, 0.2, 0.12), "pattern": "grain", "scale": 0.08},
	"gold": {"light": Color(1.0, 0.82, 0.38), "dark": Color(0.62, 0.42, 0.12), "pattern": "stains", "scale": 0.1},
	"cloth": {"light": Color(0.95, 0.9, 0.8), "dark": Color(0.7, 0.64, 0.55), "pattern": "weave", "scale": 0.05},
	"water": {"light": Color(0.38, 0.68, 0.72), "dark": Color(0.08, 0.22, 0.3), "pattern": "stains", "scale": 0.04},
	"stone": {"light": Color(0.74, 0.73, 0.7), "dark": Color(0.38, 0.38, 0.38), "pattern": "stains", "scale": 0.12},
	"ice": {"light": Color(0.86, 0.95, 1.0), "dark": Color(0.5, 0.72, 0.9), "pattern": "stains", "scale": 0.07},
}


## The texture of `kind` (a key of KINDS): seamless, drawn on first use.
static func texture(kind: String) -> ImageTexture:
	if not _textures.has(kind):
		_textures[kind] = ImageTexture.create_from_image(_paint(kind))
	return _textures[kind]


## A material of `kind`, tinted by `tint`, with a texture. Shared: the same arguments give the same material.
static func material(kind: String, tint := Color.WHITE, rough := 0.9, repeat := 1.0, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f|%.2f|%.2f" % [kind, tint.to_html(), rough, repeat, glow]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture(kind)
		m.albedo_color = tint
		m.roughness = rough
		m.uv1_scale = Vector3.ONE * repeat
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = Color(tint.r, tint.g, tint.b) * 0.6 + Color(0.4, 0.3, 0.1) * 0.4
			m.emission_energy_multiplier = glow
		_materials[key] = m
	return _materials[key]


static func _paint(kind: String) -> Image:
	var def: Dictionary = KINDS[kind]
	var light: Color = def.light
	var dark: Color = def.dark
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = float(def.scale)
	noise.fractal_octaves = 3
	noise.seed = hash(kind)
	var fine := FastNoiseLite.new()
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fine.frequency = 0.35
	fine.seed = hash(kind) + 5
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var pattern: String = def.pattern
	for y in SIZE:
		for x in SIZE:
			# Wrap the noise so the tile repeats without a seam: blend it with itself shifted by half a tile.
			var n := _tile_noise(noise, x, y)
			var f := _tile_noise(fine, x, y)
			var t := 0.5 + n * 0.8
			var shade := 1.0
			match pattern:
				"blocks":
					var row := int(y / 32)
					var off := 16 if row % 2 == 1 else 0
					var bx := (x + off) % 32
					var by := y % 32
					var joint := bx < 2 or by < 2
					t = 0.5 + n * 0.7 + (float(absi(hash(Vector2i((x + off) / 32, row))) % 100) / 100.0 - 0.5) * 0.35
					shade = 0.45 if joint else 1.0 + f * 0.08
				"tiles":
					# Rows of scalloped tiles: a dark edge under each, a lighter belly.
					var row := y / 16
					var off := 8 if row % 2 == 1 else 0
					var bx := (x + off) % 16
					var by := y % 16
					var scallop := 11.0 + 4.0 * sin(float(bx) / 16.0 * PI)
					shade = 0.45 if float(by) > scallop else 0.85 + 0.3 * float(by) / 16.0
					t = 0.5 + n * 0.5 + (float(absi(hash(Vector2i((x + off) / 16, row))) % 100) / 100.0 - 0.5) * 0.5
				"grain":
					# Long fibres running along x.
					var g := fine.get_noise_2d(float(x) * 0.12, float(y) * 1.6)
					t = 0.5 + n * 0.4 + g * 0.5
					shade = 1.0 + f * 0.1
				"flags":
					var bx := x % 64
					var by := y % 64
					var joint := bx < 2 or by < 2
					t = 0.5 + n * 0.7 + (float(absi(hash(Vector2i(x / 64, y / 64))) % 100) / 100.0 - 0.5) * 0.4
					shade = 0.4 if joint else 1.0 + f * 0.1
				"needles":
					# Short flecks pointing every way.
					var g := fine.get_noise_2d(float(x) * 0.9, float(y) * 0.9)
					t = 0.5 + n * 0.6 + g * 0.6
					shade = 0.8 + 0.4 * absf(f)
				"leaves":
					# A vein pattern: oval leaves with a pale midrib.
					var cx := (x % 32) - 16
					var cy := (y % 32) - 16
					var d := absf(float(cx)) * 0.35 + float(cy) * float(cy) * 0.012
					var rib := absf(float(cx)) < 1.3
					t = 0.5 + n * 0.6 - d * 0.1
					shade = (1.25 if rib else 0.9 + 0.3 * absf(f))
				"weave":
					var warp := 0.5 + 0.5 * sin(float(x) * TAU / 4.0)
					var weft := 0.5 + 0.5 * sin(float(y) * TAU / 4.0)
					t = 0.5 + n * 0.5
					shade = 0.8 + 0.2 * (warp if (x / 4 + y / 4) % 2 == 0 else weft)
				_:
					shade = 1.0 + f * 0.06
			var c := dark.lerp(light, clampf(t, 0.0, 1.0)) * clampf(shade, 0.0, 1.4)
			img.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
	img.generate_mipmaps()
	return img


## Noise that repeats every SIZE pixels: four samples blended by distance to the tile's edges.
static func _tile_noise(noise: FastNoiseLite, x: int, y: int) -> float:
	var fx := float(x) / SIZE
	var fy := float(y) / SIZE
	var a := noise.get_noise_2d(x, y)
	var b := noise.get_noise_2d(x - SIZE, y)
	var c := noise.get_noise_2d(x, y - SIZE)
	var d := noise.get_noise_2d(x - SIZE, y - SIZE)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)
