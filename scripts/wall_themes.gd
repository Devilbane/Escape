class_name WallThemes
extends RefCounted
## The cave styles a map can give its walls and floors (header "walls:"):
## bone, rock, obsidian and crystal. Each style dresses the walls, the floor
## tiles and the rough floor of a map in one material family (see
## shaders/wall_theme.gdshader), built on the kit's block layout so the joints,
## edges and detail match the stone dungeon. Walls are darker than the floor in
## every style, so the two stay apart.

const SHADER := preload("res://shaders/wall_theme.gdshader")
## The same look without the fade, for the relief on the walls (see WallShapes).
const RELIEF_SHADER := preload("res://shaders/wall_theme_relief.gdshader")
const KIT_DIR := "res://assets/kit/"

## The surfaces: 0 wall, 1 floor tile, 2 rough floor.
const WALL := 0
const FLOOR := 1
const ROUGH_FLOOR := 2

## Per style: its number in the shader and the colours of its wall, floor and
## rough floor ("base" is the light colour, "dark" the shade in the crevices),
## plus the glow of crystal.
const STYLES := {
	"bone": {"id": 0, "wall": [Color(0.46, 0.42, 0.33), Color(0.17, 0.14, 0.09)],
			"floor": [Color(0.64, 0.58, 0.46), Color(0.26, 0.21, 0.14)],
			"rough": [Color(0.42, 0.37, 0.28), Color(0.17, 0.13, 0.09)]},
	"rock": {"id": 1, "wall": [Color(0.34, 0.31, 0.28), Color(0.14, 0.12, 0.11)],
			"floor": [Color(0.46, 0.42, 0.37), Color(0.2, 0.18, 0.15)],
			"rough": [Color(0.4, 0.34, 0.27), Color(0.17, 0.14, 0.11)]},
	"obsidian": {"id": 2, "wall": [Color(0.085, 0.075, 0.12), Color(0.03, 0.025, 0.055)],
			"floor": [Color(0.16, 0.14, 0.2), Color(0.06, 0.05, 0.09)],
			"rough": [Color(0.12, 0.1, 0.15), Color(0.045, 0.04, 0.07)]},
	"crystal": {"id": 3, "wall": [Color(0.2, 0.34, 0.58), Color(0.06, 0.1, 0.22)],
			"floor": [Color(0.4, 0.55, 0.7), Color(0.14, 0.2, 0.32)],
			"rough": [Color(0.32, 0.44, 0.6), Color(0.11, 0.16, 0.28)],
			"glow": Color(0.35, 0.8, 1.0)},
}


## How the two other variants differ from the first: a shift of the colour
## (hue towards, brightness) and how fine the pattern is. They stay close, so
## the three meet without a visible edge, and the shader mixes them smoothly
## in world space (see shaders/wall_theme.gdshader).
const VARIANTS := [
	{"shift": Color(0.04, 0.0, -0.03), "bright": 1.12, "scale": 1.35},
	{"shift": Color(-0.03, 0.02, 0.04), "bright": 0.9, "scale": 0.75},
]


## Splits a header value such as "crystal" or "crystal 2" into the style and the
## variant (-1: all three mixed; 0..2 one alone).
static func parse(text: String) -> Dictionary:
	var parts := text.strip_edges().split(" ", false)
	var style: String = parts[0] if parts.size() > 0 else ""
	var variant := -1
	if parts.size() > 1 and parts[1].is_valid_int():
		variant = clampi(parts[1].to_int() - 1, 0, 2)
	return {"style": style, "variant": variant}


static func _varied(c: Color, v: Dictionary) -> Color:
	return Color(clampf((c.r + v.shift.r) * v.bright, 0.0, 1.0), clampf((c.g + v.shift.g) * v.bright, 0.0, 1.0), clampf((c.b + v.shift.b) * v.bright, 0.0, 1.0))


static func known(style: String) -> bool:
	return STYLES.has(style)


static func names() -> Array:
	return STYLES.keys()


## The material of `surface` (WALL, FLOOR or ROUGH_FLOOR) in `style`, (the level shares
## each one among its tiles).
static func material(style: String, surface: int, variant := -1) -> ShaderMaterial:
	var def: Dictionary = STYLES[style]
	var key: String = ["wall", "floor", "rough"][surface]
	var colours: Array = def[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var set_name := "walls" if surface == WALL else "floor"
	m.set_shader_parameter("albedo_tex", load(KIT_DIR + set_name + "_albedo.png"))
	m.set_shader_parameter("normal_tex", load(KIT_DIR + set_name + "_normal.png"))
	m.set_shader_parameter("style", def.id)
	m.set_shader_parameter("surface", surface)
	m.set_shader_parameter("base_color", colours[0])
	m.set_shader_parameter("dark_color", colours[1])
	m.set_shader_parameter("variant", variant)
	for i in 2:
		var v: Dictionary = VARIANTS[i]
		var tag := "b" if i == 0 else "c"
		m.set_shader_parameter("base_" + tag, _varied(colours[0], v))
		m.set_shader_parameter("dark_" + tag, _varied(colours[1], v))
		m.set_shader_parameter("scale_" + tag, v.scale)
	m.set_shader_parameter("glow_color", def.get("glow", Color(0, 0, 0)))
	return m


static var _relief := {}


## The material of the shards, skulls and bones that stick out of the walls: the
## wall's, a little lighter so they stand out from it, on the shader without the
## fade (hundreds of them would exceed the engine's limit of meshes with an
## instance uniform). Shared per style and variant.
static func relief_material(style: String, variant := -1) -> ShaderMaterial:
	var key := "%s_%d" % [style, variant]
	if not _relief.has(key):
		var m := material(style, WALL, variant)
		m.shader = RELIEF_SHADER
		for tag in ["base_color", "base_b", "base_c"]:
			var c: Color = m.get_shader_parameter(tag)
			m.set_shader_parameter(tag, Color(minf(c.r * 1.35 + 0.02, 1.0), minf(c.g * 1.35 + 0.02, 1.0), minf(c.b * 1.35 + 0.02, 1.0)))
		_relief[key] = m
	return _relief[key]
