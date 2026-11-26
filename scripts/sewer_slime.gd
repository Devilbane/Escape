class_name SewerSlime
extends RefCounted
## Patches of slime on the sewers' floors: glossy, greenish-brown smears of muck that soak the
## bricks here and there on the walkway and in the chambers. Each patch is an irregular blob (a few
## merged lumps with a ragged, soft edge, never a square or a circle), lying flat on the floor.
## The hero who steps into one gets a loud, ugly squelch with every step and runs a little slower
## in it (see Surfaces.SLIME); purely cosmetic otherwise.
##
## All patches are drawn as quads of one mesh (a surface per size class) that share one picture per class, an atlas of
## blob pictures made in code (see CLASSES): colour, a wet shine (the roughness is low) and a bumpy normal
## map in one go, the blob's outline carried by the picture's alpha, which fades out softly. The same
## picture says whether a spot is slime (see at), so what the eye sees is what the foot feels.
## The squelches are made by tools/make_slime_squelch.py.

## The size classes. Every class has an atlas of its own whose blob pictures have about the same
## pixels per metre (PIXELS_PER_METRE_MIN and up), so a big puddle is drawn as sharply as a small one:
## the picture is made bigger, never stretched. Each: its name, pixels of one blob picture (square),
## how many blob pictures there are (the columns of the atlas are COLUMNS), the patch size range in
## metres (the blob fills most of its picture), and how much detail (bubbles, speckle) it carries
## compared to the smallest class (more area, more detail).
const CLASSES := [
	{"name": "small", "tile": 128, "blobs": 6, "size": Vector2(1.5, 2.4), "detail": 1.0},
	{"name": "medium", "tile": 224, "blobs": 4, "size": Vector2(2.8, 4.2), "detail": 1.9},
	{"name": "large", "tile": 384, "blobs": 3, "size": Vector2(4.8, 7.0), "detail": 3.3},
]
const COLUMNS := 3
## The least pixels per metre any class draws at (see CLASSES).
const PIXELS_PER_METRE_MIN := 50.0
## Where the small and medium patches lie: the share of the walkway cells and of the chamber cells that
## carry one, and how often a patch there is a medium one instead of a small one.
const WALKWAY_SHARE := 0.2
const CHAMBER_SHARE := 0.4
const WALKWAY_MEDIUM := 0.15
const CHAMBER_MEDIUM := 0.45
## Large patches: how many lie in each chamber (a sheet of muck over its floor). Smaller ones keep
## clear of them.
const LARGE_PER_CHAMBER := 2
## How high above the floor the patches lie (each a hair higher than the last, so overlaps never flicker).
const LIFT := 0.012
const LIFT_STEP := 0.0003
## The slowdown (see Surfaces.PACE): slime sticks to the boots, a little.
const PACE := 0.88
## A spot counts as slime where the picture is at least this opaque.
const SOLID := 0.5

static var _patches: Array = []
static var _masks: Array = []
static var _mats: Array = []


## The patches: each {"pos": Vector3 (centre, on the floor), "size": metres, "turn": radians, "kind": index of
## CLASSES, "blob": index of its picture in that class's atlas}.
static func patches() -> Array:
	if _patches.is_empty():
		_lay()
	return _patches


static func _add(rng: RandomNumberGenerator, kind: int, pos: Vector3) -> void:
	var cls: Dictionary = CLASSES[kind]
	_patches.append({
		"pos": pos + Vector3(0, LIFT + LIFT_STEP * _patches.size(), 0),
		"size": rng.randf_range(cls.size.x, cls.size.y),
		"turn": rng.randf() * TAU,
		"kind": kind,
		"blob": rng.randi() % int(cls.blobs),
	})


static func _lay() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalschleim")
	var cells := Sewers.cells()
	# The sheets first: some in the middle part of every chamber.
	var sheets: Array[Vector3] = []
	for room: Rect2i in Sewers.ROOMS:
		for i in LARGE_PER_CHAMBER:
			var c := Vector2i(rng.randi_range(room.position.x + 2, room.end.x - 3), rng.randi_range(room.position.y + 2, room.end.y - 3))
			if cells.has(c) and not Spooknortz.hides(c):
				var at := Sewers.floor_at(c) + Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
				_add(rng, 2, at)
				sheets.append(at)
	for c: Vector2i in cells:
		var kind: String = cells[c]
		if kind != "w" and kind != "r":
			continue
		if Spooknortz.hides(c):
			continue
		var chamber := kind == "r"
		if rng.randf() > (CHAMBER_SHARE if chamber else WALKWAY_SHARE):
			continue
		var at := Sewers.floor_at(c) + Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
		var under := false
		for sheet in sheets:
			if Vector2(at.x - sheet.x, at.z - sheet.z).length() < 2.6:
				under = true
		var medium := rng.randf() < (CHAMBER_MEDIUM if chamber else WALKWAY_MEDIUM)
		if not under:
			_add(rng, 1 if medium else 0, at)


## Whether a world point lies in slime: down in the sewers, on a patch's blob.
static func at(p: Vector3) -> bool:
	if p.y >= -1.0 or not Sewers.holds(p):
		return false
	_make_atlas()
	for patch: Dictionary in patches():
		var pos: Vector3 = patch.pos
		var size: float = patch.size
		var d := Vector2(p.x - pos.x, p.z - pos.z)
		if d.length_squared() > size * size * 0.25:
			continue
		var uv := d.rotated(-float(patch.turn)) / size + Vector2(0.5, 0.5)
		if _alpha(int(patch.kind), int(patch.blob), uv) >= SOLID:
			return true
	return false


## The alpha of blob `blob` of size class `kind` at `uv` (0 to 1 each way).
static func _alpha(kind: int, blob: int, uv: Vector2) -> float:
	var tile: int = CLASSES[kind].tile
	var x := (blob % COLUMNS) * tile + clampi(int(uv.x * tile), 0, tile - 1)
	var y := (blob / COLUMNS) * tile + clampi(int(uv.y * tile), 0, tile - 1)
	return (_masks[kind] as Image).get_pixel(x, y).a


## The sound of a step in slime: one of the squelches.
static func step_sound() -> String:
	return "slime_squelch_%d" % (randi() % 4)


## Lays the patches' mesh under `parent`: one surface (one draw call) per size class.
static func build(parent: Node3D) -> void:
	_make_atlas()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mesh: ArrayMesh = null
	for kind in CLASSES.size():
		for patch: Dictionary in patches():
			if int(patch.kind) != kind:
				continue
			var tile: int = CLASSES[kind].tile
			var rows := ceili(float(CLASSES[kind].blobs) / COLUMNS)
			var pos: Vector3 = patch.pos
			var half: float = float(patch.size) * 0.5
			var cell := Vector2(patch.blob % COLUMNS, patch.blob / COLUMNS)
			var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			var verts: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for k in corners:
				var w := (k * half).rotated(float(patch.turn))
				verts.append(pos + Vector3(w.x, 0, w.y))
				# Stay a half pixel inside the blob's own picture, or the next one's edge bleeds in.
				var inner := (k * 0.5 * (1.0 - 1.0 / tile) + Vector2(0.5, 0.5))
				uvs.append((cell + inner) / Vector2(COLUMNS, rows))
			for idx: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.set_uv(uvs[idx])
				st.add_vertex(verts[idx])
		st.generate_tangents()
		st.set_material(_mats[kind])
		mesh = st.commit(mesh)
		st.clear()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var node := MeshInstance3D.new()
	node.name = "SlimePatches"
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


# --- The picture ----------------------------------------------------------------------

## Makes the atlases (once), a picture and a material for every size class.
static func _make_atlas() -> void:
	if not _mats.is_empty():
		return
	for kind in CLASSES.size():
		var cls: Dictionary = CLASSES[kind]
		var tile: int = cls.tile
		var rows := ceili(float(cls.blobs) / COLUMNS)
		var w := COLUMNS * tile
		var h := rows * tile
		var colour := Image.create(w, h, true, Image.FORMAT_RGBA8)
		var height := PackedFloat32Array()
		height.resize(w * h)
		for b in int(cls.blobs):
			_paint(kind, b, colour, height)
		var mask := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				mask.set_pixel(x, y, Color(0, 0, 0, colour.get_pixel(x, y).a))
		_masks.append(mask)
		var normals := _normals(height, w, h, 5.0)
		colour.generate_mipmaps()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(colour)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# A faint glow of its own, so the muck reads in the dark between the lamps.
		mat.emission_enabled = true
		mat.emission_texture = mat.albedo_texture
		mat.emission_energy_multiplier = 0.18
		mat.normal_enabled = true
		mat.normal_texture = ImageTexture.create_from_image(normals)
		# Wet, but not a mirror: a soft sheen (a mirror shows the lamps as strange streaks).
		mat.roughness = 0.28
		mat.metallic_specular = 0.5
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats.append(mat)


## Paints blob `b` of size class `kind` into its place of the class's atlas: its colour and alpha into `colour`,
## how thick it lies into `height`. A bigger class has more lumps, bubbles and speckle, never a blurrier picture.
static func _paint(kind: int, b: int, colour: Image, height: PackedFloat32Array) -> void:
	var cls: Dictionary = CLASSES[kind]
	var tile: int = cls.tile
	var detail: float = cls.detail
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("schleimfleck%d_%d" % [kind, b])
	var w := colour.get_width()
	# The lumps it is made of: one big, a few small ones round it (x, y, radius in picture shares).
	var lumps: Array[Vector3] = [Vector3(0.5 + rng.randf_range(-0.04, 0.04), 0.5 + rng.randf_range(-0.04, 0.04), rng.randf_range(0.26, 0.31))]
	for i in rng.randi_range(2, 5) + int(detail) * 2 - 2:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(0.14, 0.22)
		lumps.append(Vector3(0.5 + cos(a) * dist, 0.5 + sin(a) * dist, rng.randf_range(0.06, 0.11)))
	var seed_ := hash("schleim%d_%d" % [kind, b])
	var ragged := Sewers._field(64, 6 + int(detail), seed_ + 1)
	var clots := Sewers._field(64, 5 + int(detail) * 2, seed_ + 2)
	var fine := Sewers._field(64, int(14 * detail), seed_ + 3)
	# Bubbles: little domes with a bright rim (x, y, radius), about the same size in metres in every class.
	var bubbles: Array[Vector3] = []
	for i in int(rng.randi_range(5, 10) * detail * detail):
		var a := rng.randf() * TAU
		var dist := rng.randf() * 0.22
		bubbles.append(Vector3(0.5 + cos(a) * dist, 0.5 + sin(a) * dist, rng.randf_range(0.012, 0.035) / sqrt(detail)))
	var ox := (b % COLUMNS) * tile
	var oy := (b / COLUMNS) * tile
	var deep := Color(0.22, 0.32, 0.08)
	var murk := Color(0.42, 0.52, 0.12)
	var pale := Color(0.62, 0.68, 0.26)
	var brown := Color(0.38, 0.27, 0.1)
	for py in tile:
		for px in tile:
			var u := (px + 0.5) / tile
			var v := (py + 0.5) / tile
			var edge_noise := _smooth(ragged, 64, u, v)
			# Metaball field: lumps add up, so they merge into one body.
			var f := 0.0
			for l in lumps:
				var dd := Vector2(u - l.x, v - l.y).length() / l.z
				if dd < 1.0:
					var q := 1.0 - dd * dd
					f += q * q
			if f <= 0.0:
				continue
			f *= 0.35 + 1.3 * edge_noise
			var a := smoothstep(0.1, 0.42, f)
			if a <= 0.0:
				continue
			var thick := smoothstep(0.1, 1.2, f)
			var n1 := _smooth(clots, 64, u, v)
			var n2 := _smooth(fine, 64, u, v)
			# Thin edges are pale and see-through, the thick middle dark and rich, with brown clots.
			var c := pale.lerp(murk, smoothstep(0.0, 0.5, thick)).lerp(deep, smoothstep(0.55, 1.0, thick) * 0.8)
			c = c.lerp(brown, smoothstep(0.45, 0.85, n1) * 0.6)
			c = c * (0.85 + 0.3 * n2)
			var hgt := a * (0.5 + 0.5 * thick) + (n2 - 0.5) * 0.12 * a
			for bu in bubbles:
				var dd := Vector2(u - bu.x, v - bu.y).length() / bu.z
				if dd < 1.0:
					hgt += sqrt(1.0 - dd * dd) * 0.35 * a
					if dd > 0.72:
						c = c.lerp(Color(0.85, 0.92, 0.55), 0.55)
			colour.set_pixel(ox + px, oy + py, Color(c.r, c.g, c.b, a * 0.93))
			height[(oy + py) * w + ox + px] = hgt
	# Keep a clear border round every picture.
	for k in tile:
		for edge in 3:
			for pos: Vector2i in [Vector2i(k, edge), Vector2i(k, tile - 1 - edge), Vector2i(edge, k), Vector2i(tile - 1 - edge, k)]:
				colour.set_pixel(ox + pos.x, oy + pos.y, Color(0, 0, 0, 0))
				height[(oy + pos.y) * w + ox + pos.x] = 0.0


## A wrapping field (see Sewers._field) read smoothly at (u, v) in 0..1.
static func _smooth(field: PackedFloat32Array, n: int, u: float, v: float) -> float:
	var fx := clampf(u, 0.0, 0.9999) * n
	var fy := clampf(v, 0.0, 0.9999) * n
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := field[iy * n + ix]
	var b := field[iy * n + (ix + 1) % n]
	var c := field[((iy + 1) % n) * n + ix]
	var d := field[((iy + 1) % n) * n + (ix + 1) % n]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## A normal map from a height field `w` x `h` (not wrapping: the edges are flat).
static func _normals(height: PackedFloat32Array, w: int, h: int, strength: float) -> Image:
	var img := Image.create(w, h, true, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var dx := height[y * w + mini(x + 1, w - 1)] - height[y * w + maxi(x - 1, 0)]
			var dy := height[mini(y + 1, h - 1) * w + x] - height[maxi(y - 1, 0) * w + x]
			var n := Vector3(-dx * strength * 8.0, -dy * strength * 8.0, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps(true)
	return img
