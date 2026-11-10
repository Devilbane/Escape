class_name WoodStairs
extends RefCounted
## The look of the stairs inside the player's houses: old, well-used wooden boards with
## dark grain, scuffs, a worn pale strip down the middle of every tread and dark edges.
## Used for the flight up (see build_up and Level._build_stairs) and for
## the flight down (see StairsDown.build with the "wood" look).

const SIZE := Vector2i(128, 64)
const BASE := Color(0.5, 0.33, 0.19)
const DARK := Color(0.24, 0.14, 0.08)
const WORN := Color(0.66, 0.5, 0.32)

static var _tex: Texture2D = null


## The picture of one tread or riser: boards running across it (left to right), each a little
## different in shade, wavy grain lines, knots and scuffs, and a worn pale strip in the
## middle (where the feet land) with dark, dirty edges front and back. Same every time.
static func texture() -> Texture2D:
	if _tex:
		return _tex
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var boards := 3
	var board_h := SIZE.y / boards
	var shade: Array[float] = []
	for b in boards:
		shade.append(rng.randf_range(-0.07, 0.07))
	var phase := rng.randf() * 6.0
	for y in SIZE.y:
		var b := mini(y / board_h, boards - 1)
		var v := float(y) / float(SIZE.y - 1)
		# 0 at the front and back edge of the tread, 1 in the middle.
		var mid := 1.0 - absf(v - 0.5) * 2.0
		var wear := smoothstep(0.35, 0.9, mid)
		for x in SIZE.x:
			var u := float(x) / float(SIZE.x)
			var grain := sin((float(y) * 1.7 + sin(u * 9.0 + phase + float(b)) * 3.0) * 0.9) * 0.5 + 0.5
			var col := BASE.lerp(DARK, grain * 0.45)
			col = col.lightened(shade[b])
			col = col.lerp(WORN, wear * 0.55)
			# A thin dark gap between boards.
			if y % board_h == 0 and y > 0:
				col = col.lerp(DARK, 0.8)
			# Dirt along the edges.
			col = col.lerp(DARK, (1.0 - smoothstep(0.0, 0.3, mid)) * 0.5)
			img.set_pixel(x, y, col)
	# Scuffs: short pale scratches, mostly where the feet land.
	for i in 26:
		var sx := rng.randi_range(0, SIZE.x - 14)
		var sy := rng.randi_range(SIZE.y / 5, SIZE.y * 4 / 5)
		var len := rng.randi_range(5, 14)
		for k in len:
			var px := sx + k
			var py := clampi(sy + int(float(k) * rng.randf_range(-0.2, 0.2)), 0, SIZE.y - 1)
			img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(0.8, 0.66, 0.46), 0.5))
	# Knots and dark nail heads.
	for i in 4:
		var kx := rng.randi_range(6, SIZE.x - 7)
		var ky := rng.randi_range(6, SIZE.y - 7)
		for dy in range(-2, 3):
			for dx in range(-3, 4):
				if dx * dx / 9.0 + dy * dy / 4.0 <= 1.0:
					img.set_pixel(kx + dx, ky + dy, DARK.lerp(BASE, 0.15))
	_tex = ImageTexture.create_from_image(img)
	return _tex


## A matt, worn wood material. `triplanar` for the kit's mesh (no fitting picture
## coordinates): the boards are then spread over the faces by position.
static func material(colour := Color.WHITE, triplanar := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture()
	mat.albedo_color = colour
	mat.roughness = 0.9
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if triplanar:
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.7, 0.7, 0.7)
	return mat


## Steps of the flight up, how much each rises and how deep it is (metres). They fill the
## tile's depth (4 m) the way the kit's stone stairs do, the top step against the north wall.
const UP_STEPS := 8
const UP_RISE := 0.5
const UP_RUN := 0.5
const UP_WIDTH := 4.0
const UP_TREAD_WIDTH := 3.5


## The flight up for a house, built from boards: every step is the same size and carries the
## same picture, so all treads (and all risers) match. The kit's mesh has no picture
## coordinates a wood skin could use, and spreading boards over it by position gave each step a
## different cut of the wood. `pos` is the middle of the tile; the flight climbs to the north.
static func build_up(parent: Node3D, pos: Vector3, tile: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var tread_mat := material(Color(1.0, 0.97, 0.92))
	var riser_mat := material(Color(0.62, 0.56, 0.5))
	for i in UP_STEPS:
		var top := UP_RISE * float(i + 1)
		# The south edge of step i; the first step meets the floor at the front of the tile.
		var front := tile * 0.5 - UP_RUN * float(i) - 0.1 * float(i == 0)
		var z := front - UP_RUN * 0.5
		_box(holder, Vector3(UP_WIDTH, top, UP_RUN), Vector3(0, top * 0.5, z), riser_mat)
		_box(holder, Vector3(UP_TREAD_WIDTH, 0.06, UP_RUN + 0.04), Vector3(0, top + 0.03, z - 0.02), tread_mat)
	return holder


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
