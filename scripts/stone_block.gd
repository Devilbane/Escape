class_name StoneBlock
extends Crate
## A rectangular block of carved stone ("steinblock" in Items) to build with:
## walls, steps, towers and small enclosures. The stonemason in the village
## sells them; they are carried in the bag and set down from the inventory
## onto the build grid in front of the hero. A block that lies on the floor
## can be grabbed with the left mouse button and dragged onto another spot
## within reach, where it lands on the floor or on top of other blocks.
##
## A block is twice as long as it is wide and high: it covers two cells of
## the build grid (CELL metres each), lying along x or along z, and stands on
## a layer (0 on the floor, 1 on top of a block, ...). It is a kind of Crate
## to the hero: walking into a block one layer high climbs it, a higher one
## needs a jump, just like crates.

## Edge of one build grid cell, and the height of a block (the same as a crate,
## so one block is a step up and two need a jump).
const CELL := Crate.SIZE
const HEIGHT := Crate.SIZE
## How many blocks fit on top of each other.
const MAX_LAYERS := 5
## Chamfer of the carved edges, and the gap left between neighbours so the
## joints between blocks show.
const BEVEL := 0.06
const JOINT := 0.02
## A few shades of grey-brown sandstone, so a wall does not look printed.
const SHADES: Array[Color] = [Color(0.5, 0.48, 0.44), Color(0.46, 0.45, 0.42), Color(0.53, 0.5, 0.45), Color(0.43, 0.42, 0.4)]
const STONE_SHADER := preload("res://shaders/stone.gdshader")

static var _mesh: ArrayMesh
static var _materials := {}

## The first of the two grid cells the block covers.
var cell := Vector2i.ZERO
## Lying along x (covers cell and cell + (1, 0)) or along z (cell + (0, 1)).
var along_x := true
var layer := 0


func _ready() -> void:
	add_to_group("stone")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL * 2.0, HEIGHT, CELL)
	shape.shape = box
	shape.position.y = HEIGHT * 0.5
	add_child(shape)
	model = make_model(SHADES[absi(cell.x * 7 + cell.y * 13 + layer * 5) % SHADES.size()])
	add_child(model)
	rotation.y = 0.0 if along_x else PI * 0.5


## Where a block on these cells and layer stands: the middle of its bottom.
static func spot_of(first: Vector2i, x_wise: bool, on_layer: int) -> Vector3:
	var x := (first.x + (1.0 if x_wise else 0.5)) * CELL
	var z := (first.y + (0.5 if x_wise else 1.0)) * CELL
	return Vector3(x, on_layer * HEIGHT, z)


## The first cell of a block lying with its middle as close to `point` as
## the grid allows.
static func cell_for(point: Vector3, x_wise: bool) -> Vector2i:
	return Vector2i(roundi(point.x / CELL - (1.0 if x_wise else 0.5)), roundi(point.z / CELL - (0.5 if x_wise else 1.0)))


## The two grid cells a block covers.
static func cells_of(first: Vector2i, x_wise: bool) -> Array[Vector2i]:
	return [first, first + (Vector2i(1, 0) if x_wise else Vector2i(0, 1))]


## The grid cell a point lies in.
static func grid_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))


func cells() -> Array[Vector2i]:
	return cells_of(cell, along_x)


## Puts the block onto its spot in the grid.
func place(first: Vector2i, x_wise: bool, on_layer: int) -> void:
	cell = first
	along_x = x_wise
	layer = on_layer
	position = spot_of(first, x_wise, on_layer)
	rotation.y = 0.0 if x_wise else PI * 0.5


func top() -> float:
	return global_position.y + HEIGHT


func covers(point: Vector3, margin := 0.0) -> bool:
	var half := Vector2(CELL + margin, CELL * 0.5 + margin) if along_x else Vector2(CELL * 0.5 + margin, CELL + margin)
	return absf(point.x - global_position.x) <= half.x and absf(point.z - global_position.z) <= half.y


## The carved block itself, lying along x with its bottom middle at the origin.
static func make_model(shade: Color) -> Node3D:
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = block_mesh()
	mi.material_override = stone_material(shade)
	holder.add_child(mi)
	return holder


## The rough, matt carved stone of the dungeon walls and the fountain on a
## plain colour (see Level._plain_stone), shared per shade.
static func stone_material(shade: Color) -> Material:
	var key := shade.to_html()
	if not _materials.has(key):
		var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		var stone := ShaderMaterial.new()
		stone.shader = STONE_SHADER
		stone.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
		stone.set_shader_parameter("albedo_color", shade)
		stone.set_shader_parameter("use_normal_map", false)
		stone.set_shader_parameter("strength", 1.7)
		_materials[key] = stone
	return _materials[key]


## A box with chamfered edges and corners, a little smaller than the block's
## room, so joints show between neighbours.
static func block_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var h := Vector3(CELL, HEIGHT * 0.5, CELL * 0.5) - Vector3.ONE * JOINT * 0.5
	var c := BEVEL
	var mid := Vector3(0, HEIGHT * 0.5, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Corner points: for each corner, the three points where its chamfer
	# triangle meets the faces (pulled in along the other two axes).
	var corner := func(s: Vector3, pulled_axis: int) -> Vector3:
		var p := Vector3(s.x * h.x, s.y * h.y, s.z * h.z)
		for axis in 3:
			if axis != pulled_axis:
				p[axis] -= s[axis] * c
		return p + mid
	var faces: Array = []
	# The six faces.
	for axis in 3:
		for side in [-1.0, 1.0]:
			var pts: Array[Vector3] = []
			var a := (axis + 1) % 3
			var b := (axis + 2) % 3
			for uv in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var s := Vector3.ZERO
				s[axis] = side
				s[a] = uv.x
				s[b] = uv.y
				pts.append(corner.call(s, axis))
			faces.append(pts)
	# The twelve chamfered edges.
	for axis in 3:
		var a := (axis + 1) % 3
		var b := (axis + 2) % 3
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var pts: Array[Vector3] = []
				for along in [-1.0, 1.0]:
					var s := Vector3.ZERO
					s[axis] = along
					s[a] = sa
					s[b] = sb
					pts.append(corner.call(s, a))
				for along in [1.0, -1.0]:
					var s := Vector3.ZERO
					s[axis] = along
					s[a] = sa
					s[b] = sb
					pts.append(corner.call(s, b))
				faces.append(pts)
	# The eight corner triangles.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz)
				var tri: Array[Vector3] = [corner.call(s, 0), corner.call(s, 1), corner.call(s, 2)]
				faces.append(tri)
	for pts in faces:
		_add_face(st, pts, mid)
	_mesh = st.commit()
	return _mesh


## A flat convex face, turned to face away from the block's middle (Godot
## shows triangles wound clockwise as seen from the front).
static func _add_face(st: SurfaceTool, pts: Array[Vector3], mid: Vector3) -> void:
	var centre := Vector3.ZERO
	for p in pts:
		centre += p
	centre /= pts.size()
	var n := (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	if n.dot(centre - mid) < 0.0:
		pts.reverse()
		n = -n
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i + 1], pts[i]]:
			st.set_normal(n)
			st.set_uv(Vector2(p.x + p.z, p.y))
			st.add_vertex(p)
