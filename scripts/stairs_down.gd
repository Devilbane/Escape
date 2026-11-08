class_name StairsDown
extends RefCounted
## A flight of stone steps going down into the ground, instead of a flat black
## hole: every step is a little darker than the one above it, the risers face
## the way the hero comes from, walls and a lit rim frame the opening, and the
## bottom fades into the dark. Used by the stairs down of a home ("<" and ">"),
## the shafts of the mines and lairs ("^"), and as a picture for the doorway of
## the dragon's lair (see doorway_texture).

const STEPS := 7
## Height of one step (metres), so the flight is STEPS * RISE deep.
const RISE := 0.5
const STONE := Color(0.62, 0.58, 0.52)
const BOTTOM := Color(0.02, 0.015, 0.015)
const WALL_THICK := 0.3


## Builds the flight in the tile at `pos`, going down towards `dir` (a unit
## step on the ground: the far end of the flight lies that way). `tile` is the
## tile's width. Returns the node that holds the pieces.
static func build(parent: Node3D, pos: Vector3, tile: float, dir: Vector3 = Vector3(0, 0, -1)) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = atan2(-dir.x, -dir.z)
	parent.add_child(holder)
	var depth := STEPS * RISE
	var run := tile / float(STEPS)
	var width := tile - WALL_THICK * 2.0
	for i in STEPS:
		var shade := darkness(i, STEPS)
		var colour := STONE.lerp(BOTTOM, shade)
		# The tread: its top lies RISE lower than that of the step before.
		var top := -RISE * float(i + 1)
		var z := tile * 0.5 - run * (float(i) + 0.5)
		_box(holder, Vector3(width, 0.14, run), Vector3(0, top - 0.07, z), _stone(colour))
		# The riser under the previous step's edge, a shade darker than its
		# tread so the steps read as steps from above.
		var riser := colour.lerp(BOTTOM, 0.35)
		_box(holder, Vector3(width, RISE, 0.06), Vector3(0, top + RISE * 0.5, z + run * 0.5), _stone(riser))
	# The wall at the far end and the dark below, fading out.
	_box(holder, Vector3(width, depth + 1.0, 0.2), Vector3(0, -depth * 0.5 - 0.5, -tile * 0.5 - 0.1), _unshaded(BOTTOM))
	_box(holder, Vector3(width, 0.1, tile), Vector3(0, -depth - 0.05, 0), _unshaded(BOTTOM))
	# Side walls, in stone that darkens the deeper it goes (a few bands).
	var bands := 4
	for side in [-1.0, 1.0]:
		for b in bands:
			var h := (depth + 0.4) / float(bands)
			var y0 := 0.4 - h * (float(b) + 0.5)
			var wall_colour := STONE.lerp(BOTTOM, darkness(b, bands) * 0.9).darkened(0.25)
			_box(holder, Vector3(WALL_THICK, h, tile), Vector3(side * (tile - WALL_THICK) * 0.5, y0, 0), _stone(wall_colour))
	# The rim round the opening, standing a little above the floor.
	var rim := _stone(STONE.darkened(0.15))
	_box(holder, Vector3(tile, 0.18, 0.3), Vector3(0, 0.09, tile * 0.5 - 0.15), rim)
	_box(holder, Vector3(tile, 0.18, 0.3), Vector3(0, 0.09, -tile * 0.5 + 0.15), rim)
	for side in [-1.0, 1.0]:
		_box(holder, Vector3(0.3, 0.18, tile), Vector3(side * (tile * 0.5 - 0.15), 0.09, 0), rim)
	return holder


## How dark step `i` of `count` is, from 0 (lit, at the top) to 1 (black).
## Eased, so the first steps stay readable and the last fade away.
static func darkness(i: int, count: int) -> float:
	var t := float(i) / float(maxi(1, count - 1))
	return clampf(t * t * 0.55 + t * 0.4, 0.0, 1.0)


## A picture of a stairway seen from the front, going down into a doorway:
## the lit steps at the foot of the opening and the dark closing in above
## them, used for the black hole behind the lair's arch.
static func doorway_texture(glow := Color(0.55, 0.16, 0.06)) -> Texture2D:
	var w := 64
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var steps := 8
	for y in h:
		# The lower part of the picture is the flight: bands, lighter on the
		# top edge of each step, getting darker towards the top (further in).
		var v := float(y) / float(h - 1)
		var col := BOTTOM
		var floor_start := 0.30
		if v >= floor_start:
			var f := (v - floor_start) / (1.0 - floor_start)
			var band := f * float(steps)
			var within := band - floorf(band)
			var depth := 1.0 - f
			var light := STONE.lerp(BOTTOM, clampf(depth * 0.95, 0.0, 1.0))
			col = light * (0.8 + 0.4 * (1.0 - within))
			col = col.lerp(glow, clampf(depth * 0.35, 0.0, 0.35))
		else:
			col = BOTTOM.lerp(glow * 0.25, v / floor_start * 0.5)
		col.a = 1.0
		for x in w:
			var edge := absf(float(x) / float(w - 1) - 0.5) * 2.0
			var c := col.darkened(clampf(edge * edge * 0.6, 0.0, 0.6))
			c.a = 1.0
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _stone(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	return mat


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	return mat


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
