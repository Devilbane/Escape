class_name WallCaps
extends RefCounted
## Covers what the walls leave bare: the top of each wall, and its outer side
## where it faces the dark void behind the dungeon. The wall pieces are thin
## faces turned into the rooms, so without this the camera looks down onto
## nothing. Only the walls themselves are covered (the first wall tiles around
## the rooms), never the void as a whole, and nothing here has collision.
##
## It is cheap: one merged mesh for all walls, plus one small mesh for each
## near wall (the stretch between camera and room), which fades with the
## wall in front of the hero (see WallFade) so the cap never hides the hero.

## The top sits just under the wall pieces' own tops (WallFade.WALL_HEIGHT),
## so the two never flicker against each other where they overlap.
const TOP := WallFade.WALL_HEIGHT - 0.04
## World metres to one repeat of the wall texture.
const UV_SCALE := 0.25
## The caps' shader: the same flat look, with the see-through circle around the hero.
const CAP_SHADER := preload("res://shaders/cap_flat.gdshader")


## Builds the caps for `level` in `material` (its wall material, so a stone,
## bone, rock, obsidian or crystal dungeon is covered in its own look). Near
## walls are added to `near` so that they fade like the wall pieces.
static func build(level: Level, plain: Material, near: WallFade) -> void:
	var material := _cap_material(plain)
	var cap := _cap_cells(level)
	if cap.is_empty():
		return
	var far_tool := SurfaceTool.new()
	far_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_far := false
	for key in cap:
		var c: Vector2i = key
		var low := level._is_low_wall(c)
		var tool := far_tool
		if low:
			tool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		# A near wall's node sits on its room-side edge, like the wall piece.
		var edge := level.cell_to_world(c) + Vector3(0, 0, -level.TILE * 0.5)
		_add_cell(tool, level, cap, c, edge if low else Vector3.ZERO)
		if low:
			var node := _mesh_node(tool, material, edge)
			level.add_child(node)
			near.add(node)
		else:
			any_far = true
	if any_far:
		level.add_child(_mesh_node(far_tool, material, Vector3.ZERO))


## `plain`'s flat colour, drawn by the shader that also opens the see-through circle around the hero
## (see HeroReveal). A material that is not a plain one is kept as it is.
static func _cap_material(plain: Material) -> Material:
	if not plain is StandardMaterial3D:
		return plain
	var m := ShaderMaterial.new()
	m.shader = CAP_SHADER
	m.set_shader_parameter("albedo_color", (plain as StandardMaterial3D).albedo_color)
	return m


## The wall tiles that get a cap: every wall tile touching a room (also
## diagonally). Deeper wall tiles are void and stay uncovered.
static func _cap_cells(level: Level) -> Dictionary:
	var cap := {}
	if level.outdoor:
		return cap
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if level.cell_char(c) != "#":
				continue
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var n := c + Vector2i(dx, dy)
					if _inside(level, n) and level.cell_char(n) != "#":
						cap[c] = true
	return cap


static func _inside(level: Level, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < level.width and c.y < level.height


static func _mesh_node(tool: SurfaceTool, material: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = tool.commit()
	mi.material_override = material
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The top of one wall tile, and each of its sides that looks onto the void
## (a wall tile without a cap beside it, or the edge of the map). Sides that
## face a room already have the wall piece. Points are given relative to
## `origin`, where the mesh's node sits.
static func _add_cell(tool: SurfaceTool, level: Level, cap: Dictionary, c: Vector2i, origin: Vector3) -> void:
	var half: float = level.TILE * 0.5
	var mid := level.cell_to_world(c) - origin
	var nw := mid + Vector3(-half, TOP, -half)
	var ne := mid + Vector3(half, TOP, -half)
	var sw := mid + Vector3(-half, TOP, half)
	var se := mid + Vector3(half, TOP, half)
	_quad(tool, [nw, ne, se, sw], Vector3.UP, origin)
	var down := Vector3(0, -TOP, 0)
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = c + d
		if cap.has(n) or (_inside(level, n) and level.cell_char(n) != "#"):
			continue
		var a: Vector3
		var b: Vector3
		if d.y < 0:
			a = nw
			b = ne
		elif d.y > 0:
			a = se
			b = sw
		elif d.x < 0:
			a = sw
			b = nw
		else:
			a = ne
			b = se
		_quad(tool, [a, b, b + down, a + down], Vector3(d.x, 0, d.y), origin)


## One flat quad facing `normal`. Godot draws the clockwise side, so the corners
## are turned round when they run the other way.
static func _quad(tool: SurfaceTool, corners: Array, normal: Vector3, origin: Vector3) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	var turned: bool = (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(normal) > 0.0
	if turned:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		var v: Vector3 = corners[i]
		var w := v + origin
		tool.set_normal(normal)
		# Walls read their texture along the wall and up; the top along the floor.
		var uv := Vector2(w.x + w.z, -w.y) if absf(normal.y) < 0.5 else Vector2(w.x, w.z)
		tool.set_uv(uv * UV_SCALE)
		tool.add_vertex(v)
