class_name VoidFill
extends RefCounted
## Fills the darkness around a dungeon with a plain, flat version of its wall
## material: stone for the stone dungeon, bone, rock, obsidian or crystal for the
## cave styles. It is one big quad just under the floor, so every cell outside
## the walls is covered alike, also where a secret passage or room lies beyond
## them: the fill never shows where one is. It has no collision and no detail,
## and it stays dark and flat so the rooms keep the eye.

## How far the fill reaches past the map on every side (metres).
const MARGIN := 80.0
## Just under the floor (y = 0), so it never fights with the floors.
const DEPTH := -0.05

## The plain tone of the wall tops and outer sides in `style` ("" for the stone
## dungeon): the wall's own colour, evened out into one flat shade.
static func cap_tone(style: String) -> Color:
	if not WallThemes.known(style):
		return Color(0.33, 0.31, 0.29)
	var cols: Array = WallThemes.STYLES[style]["wall"]
	var c: Color = (cols[0] as Color).lerp(cols[1], 0.3)
	# Evened out: a little greyer than the wall, so glowing styles stay calm.
	var grey := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	return c.lerp(Color(grey, grey, grey), 0.45) * 0.85


## The fill is darker than the tops, so the rooms keep the eye and the wall tops
## still read as the edge of the dungeon.
static func tone(style: String) -> Color:
	return cap_tone(style) * 0.5


## One flat, matt shade, without texture or relief.
static func flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m


## The material of the wall tops and outer sides (see WallCaps).
static func cap_material(style: String) -> StandardMaterial3D:
	return flat(cap_tone(style))


## Adds the fill to `level` (not to open-air maps, nor to the home with its storeys).
static func build(level: Level) -> void:
	if level.outdoor or level.is_home:
		return
	var size := Vector2(level.width, level.height) * level.TILE + Vector2.ONE * MARGIN * 2.0
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = "VoidFill"
	mi.mesh = mesh
	mi.material_override = flat(tone(level.wall_style))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var first := level.cell_to_world(Vector2i.ZERO)
	var last := level.cell_to_world(Vector2i(level.width - 1, level.height - 1))
	mi.position = Vector3((first.x + last.x) * 0.5, DEPTH, (first.z + last.z) * 0.5)
	level.add_child(mi)
