class_name WallThemes
extends RefCounted
## The cave styles a map can give its walls and floors (header "walls:"):
## bone, rock, obsidian and crystal. Each style dresses the walls, the floor
## tiles and the rough floor of a map in one material family (see
## shaders/wall_theme.gdshader), built on the kit's block layout so the joints,
## edges and detail match the stone dungeon. Walls are darker than the floor in
## every style, so the two stay apart.

const SHADER := preload("res://shaders/wall_theme.gdshader")
const KIT_DIR := "res://assets/kit/"

## The surfaces: 0 wall, 1 floor tile, 2 rough floor.
const WALL := 0
const FLOOR := 1
const ROUGH_FLOOR := 2

## Per style: its number in the shader and the colours of its wall, floor and
## rough floor ("base" is the light colour, "dark" the shade in the crevices),
## plus the glow of crystal.
const STYLES := {
	"bone": {"id": 0, "wall": [Color(0.62, 0.57, 0.45), Color(0.22, 0.18, 0.12)],
			"floor": [Color(0.5, 0.45, 0.35), Color(0.2, 0.16, 0.11)],
			"rough": [Color(0.42, 0.37, 0.28), Color(0.17, 0.13, 0.09)]},
	"rock": {"id": 1, "wall": [Color(0.34, 0.31, 0.28), Color(0.14, 0.12, 0.11)],
			"floor": [Color(0.46, 0.42, 0.37), Color(0.2, 0.18, 0.15)],
			"rough": [Color(0.4, 0.34, 0.27), Color(0.17, 0.14, 0.11)]},
	"obsidian": {"id": 2, "wall": [Color(0.05, 0.045, 0.07), Color(0.015, 0.012, 0.025)],
			"floor": [Color(0.16, 0.14, 0.2), Color(0.06, 0.05, 0.09)],
			"rough": [Color(0.12, 0.1, 0.15), Color(0.045, 0.04, 0.07)]},
	"crystal": {"id": 3, "wall": [Color(0.2, 0.34, 0.58), Color(0.06, 0.1, 0.22)],
			"floor": [Color(0.4, 0.55, 0.7), Color(0.14, 0.2, 0.32)],
			"rough": [Color(0.32, 0.44, 0.6), Color(0.11, 0.16, 0.28)],
			"glow": Color(0.35, 0.8, 1.0)},
}


static func known(style: String) -> bool:
	return STYLES.has(style)


static func names() -> Array:
	return STYLES.keys()


## The material of `surface` (WALL, FLOOR or ROUGH_FLOOR) in `style`, (the level shares
## each one among its tiles).
static func material(style: String, surface: int) -> ShaderMaterial:
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
	m.set_shader_parameter("glow_color", def.get("glow", Color(0, 0, 0)))
	return m
