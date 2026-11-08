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
## Floor grates and stairs going down stay open: they lie below the fill, so a fill
## across them would hide them (see open_cells).
static func build(level: Level) -> void:
	if level.outdoor or level.is_home:
		return
	var mi := MeshInstance3D.new()
	mi.name = "VoidFill"
	mi.mesh = fill_mesh(level)
	var mat := flat(tone(level.wall_style))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = DEPTH
	level.add_child(mi)


## The tiles the fill leaves open, because something lies below the floor there: the
## floor grates (their pits), the way down of a mine ("^") and the exit stairs ("E"),
## which also reach into the tile behind them (the one to the north).
static func open_cells(level: Level) -> Dictionary:
	var open := {}
	for c: Vector2i in level.grates:
		open[c] = true
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			var ch := level.cell_char(c)
			if ch == "^":
				open[c] = true
			elif ch == "E":
				open[c] = true
				open[c + Vector2i(0, -1)] = true
	return open


## The fill's flat face as rectangles in the level's own space (y = 0): the whole map
## and its margin, less one tile for every open cell (see open_cells).
static func fill_mesh(level: Level) -> ArrayMesh:
	var half := level.TILE * 0.5
	var first := level.cell_to_world(Vector2i.ZERO)
	var last := level.cell_to_world(Vector2i(level.width - 1, level.height - 1))
	var x0 := first.x - half
	var x1 := last.x + half
	var z0 := first.z - half
	var z1 := last.z + half
	var open := open_cells(level)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	# The margin on all four sides.
	_quad(st, x0 - MARGIN, z0 - MARGIN, x1 + MARGIN, z0)
	_quad(st, x0 - MARGIN, z1, x1 + MARGIN, z1 + MARGIN)
	_quad(st, x0 - MARGIN, z0, x0, z1)
	_quad(st, x1, z0, x1 + MARGIN, z1)
	# The map, row by row, with a gap at each grate.
	for y in level.height:
		var za := z0 + y * level.TILE
		var run_from := x0
		for x in level.width:
			if not open.has(Vector2i(x, y)):
				continue
			var xa := x0 + x * level.TILE
			_quad(st, run_from, za, xa, za + level.TILE)
			run_from = xa + level.TILE
		_quad(st, run_from, za, x1, za + level.TILE)
	return st.commit()


## One upward-facing rectangle (nothing when it has no area).
static func _quad(st: SurfaceTool, xa: float, za: float, xb: float, zb: float) -> void:
	if xb - xa < 0.001 or zb - za < 0.001:
		return
	var a := Vector3(xa, 0, za)
	var b := Vector3(xb, 0, za)
	var c := Vector3(xb, 0, zb)
	var d := Vector3(xa, 0, zb)
	for v: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(v)
