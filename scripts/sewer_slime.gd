class_name SewerSlime
extends RefCounted
## Patches of slime on the sewers' floors: glossy, greenish-brown smears of muck that soak the
## bricks here and there on the walkway and in the chambers. Each patch is an irregular blob (a few
## merged lumps with a ragged, soft edge, never a square or a circle), lying flat on the floor.
## The hero who steps into one gets a loud, ugly squelch with every step and runs a little slower
## in it (see Surfaces.SLIME); purely cosmetic otherwise.
##
## All patches are drawn as quads of one mesh (one draw call) that share one picture, an atlas of
## BLOBS blob pictures made in code: colour, a wet shine (the roughness is low) and a bumpy normal
## map in one go, the blob's outline carried by the picture's alpha, which fades out softly. The same
## picture says whether a spot is slime (see at), so what the eye sees is what the foot feels.
## The squelches are made by tools/make_slime_squelch.py.

## Blob pictures in the atlas, and how many columns of them lie side by side.
const BLOBS := 8
const COLUMNS := 4
## Pixels of one blob picture (square).
const TILE := 160
## Where the patches lie: the share of the walkway cells and of the chamber cells that carry one.
const WALKWAY_SHARE := 0.2
const CHAMBER_SHARE := 0.5
## The size of a patch's picture in metres (the blob fills most of it), smallest and largest.
const SIZE := Vector2(1.7, 3.0)
## How high above the floor the patches lie (each a hair higher than the last, so overlaps never flicker).
const LIFT := 0.012
const LIFT_STEP := 0.0007
## The slowdown (see Surfaces.PACE): slime sticks to the boots, a little.
const PACE := 0.88
## A spot counts as slime where the picture is at least this opaque.
const SOLID := 0.5

static var _patches: Array = []
static var _mask: Image = null
static var _mat: StandardMaterial3D = null


## The patches: each {"pos": Vector3 (centre, on the floor), "size": metres, "turn": radians, "blob": index}.
static func patches() -> Array:
	if _patches.is_empty():
		_lay()
	return _patches


static func _lay() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalschleim")
	var cells := Sewers.cells()
	for c: Vector2i in cells:
		var kind: String = cells[c]
		if kind != "w" and kind != "r":
			continue
		if Spooknortz.hides(c):
			continue
		if rng.randf() > (CHAMBER_SHARE if kind == "r" else WALKWAY_SHARE):
			continue
		var off := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
		_patches.append({
			"pos": Sewers.floor_at(c) + off + Vector3(0, LIFT + LIFT_STEP * _patches.size(), 0),
			"size": rng.randf_range(SIZE.x, SIZE.y),
			"turn": rng.randf() * TAU,
			"blob": rng.randi() % BLOBS,
		})


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
		if _alpha(int(patch.blob), uv) >= SOLID:
			return true
	return false


## The alpha of blob `blob`'s picture at `uv` (0 to 1 each way).
static func _alpha(blob: int, uv: Vector2) -> float:
	var x := (blob % COLUMNS) * TILE + clampi(int(uv.x * TILE), 0, TILE - 1)
	var y := (blob / COLUMNS) * TILE + clampi(int(uv.y * TILE), 0, TILE - 1)
	return _mask.get_pixel(x, y).a


## The sound of a step in slime: one of the squelches.
static func step_sound() -> String:
	return "slime_squelch_%d" % (randi() % 4)


## Lays the patches' mesh under `parent`.
static func build(parent: Node3D) -> void:
	_make_atlas()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_mat)
	for patch: Dictionary in patches():
		var pos: Vector3 = patch.pos
		var half: float = float(patch.size) * 0.5
		var tile := Vector2(patch.blob % COLUMNS, patch.blob / COLUMNS)
		var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		var verts: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for k in corners:
			var w := (k * half).rotated(float(patch.turn))
			verts.append(pos + Vector3(w.x, 0, w.y))
			# Stay a half pixel inside the blob's own picture, or the next one's edge bleeds in.
			var inner := (k * 0.5 * (1.0 - 1.0 / TILE) + Vector2(0.5, 0.5))
			uvs.append((tile + inner) / Vector2(COLUMNS, BLOBS / COLUMNS))
		for idx: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.add_vertex(verts[idx])
	st.generate_tangents()
	var node := MeshInstance3D.new()
	node.name = "SlimePatches"
	node.mesh = st.commit()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


# --- The picture ----------------------------------------------------------------------

## Makes the atlas (once) and the material that shows it.
static func _make_atlas() -> void:
	if _mat != null:
		return
	var w := COLUMNS * TILE
	var h := (BLOBS / COLUMNS) * TILE
	var colour := Image.create(w, h, true, Image.FORMAT_RGBA8)
	var height := PackedFloat32Array()
	height.resize(w * h)
	_mask = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for b in BLOBS:
		_paint(b, colour, height)
	for y in h:
		for x in w:
			_mask.set_pixel(x, y, Color(0, 0, 0, colour.get_pixel(x, y).a))
	var normals := _normals(height, w, h, 5.0)
	colour.generate_mipmaps()
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = ImageTexture.create_from_image(colour)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A faint glow of its own, so the muck reads in the dark between the lamps.
	_mat.emission_enabled = true
	_mat.emission_texture = _mat.albedo_texture
	_mat.emission_energy_multiplier = 0.18
	_mat.normal_enabled = true
	_mat.normal_texture = ImageTexture.create_from_image(normals)
	# Wet: nearly a mirror, with a clear coat on top.
	_mat.roughness = 0.1
	_mat.metallic_specular = 0.9
	_mat.clearcoat_enabled = true
	_mat.clearcoat = 0.8
	_mat.clearcoat_roughness = 0.06
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


## Paints blob `b` into its place of the atlas: its colour and alpha into `colour`, how thick it lies into `height`.
static func _paint(b: int, colour: Image, height: PackedFloat32Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("schleimfleck%d" % b)
	var w := colour.get_width()
	# The lumps it is made of: one big, a few small ones round it (x, y, radius in picture shares).
	var lumps: Array[Vector3] = [Vector3(0.5 + rng.randf_range(-0.04, 0.04), 0.5 + rng.randf_range(-0.04, 0.04), rng.randf_range(0.26, 0.31))]
	for i in rng.randi_range(2, 5):
		var a := rng.randf() * TAU
		var dist := rng.randf_range(0.14, 0.22)
		lumps.append(Vector3(0.5 + cos(a) * dist, 0.5 + sin(a) * dist, rng.randf_range(0.06, 0.11)))
	var seed_ := hash("schleim%d" % b)
	var ragged := Sewers._field(32, 6, seed_ + 1)
	var clots := Sewers._field(32, 5, seed_ + 2)
	var fine := Sewers._field(32, 14, seed_ + 3)
	# Bubbles: little domes with a bright rim (x, y, radius).
	var bubbles: Array[Vector3] = []
	for i in rng.randi_range(5, 10):
		var a := rng.randf() * TAU
		var dist := rng.randf() * 0.2
		bubbles.append(Vector3(0.5 + cos(a) * dist, 0.5 + sin(a) * dist, rng.randf_range(0.012, 0.035)))
	var ox := (b % COLUMNS) * TILE
	var oy := (b / COLUMNS) * TILE
	var deep := Color(0.22, 0.32, 0.08)
	var murk := Color(0.42, 0.52, 0.12)
	var pale := Color(0.62, 0.68, 0.26)
	var brown := Color(0.38, 0.27, 0.1)
	for py in TILE:
		for px in TILE:
			var u := (px + 0.5) / TILE
			var v := (py + 0.5) / TILE
			var edge_noise := _smooth(ragged, 32, u, v)
			# Metaball field: lumps add up, so they merge into one body.
			var f := 0.0
			for l in lumps:
				var d := Vector2(u - l.x, v - l.y).length() / l.z
				if d < 1.0:
					var q := 1.0 - d * d
					f += q * q
			f *= 0.35 + 1.3 * edge_noise
			var a := smoothstep(0.1, 0.42, f)
			var thick := smoothstep(0.1, 1.2, f)
			var n1 := _smooth(clots, 32, u, v)
			var n2 := _smooth(fine, 32, u, v)
			# Thin edges are pale and see-through, the thick middle dark and rich, with brown clots.
			var c := pale.lerp(murk, smoothstep(0.0, 0.5, thick)).lerp(deep, smoothstep(0.55, 1.0, thick) * 0.8)
			c = c.lerp(brown, smoothstep(0.45, 0.85, n1) * 0.6)
			c = c * (0.85 + 0.3 * n2)
			var hgt := a * (0.5 + 0.5 * thick) + (n2 - 0.5) * 0.12 * a
			for bu in bubbles:
				var d := Vector2(u - bu.x, v - bu.y).length() / bu.z
				if d < 1.0:
					hgt += sqrt(1.0 - d * d) * 0.35 * a
					if d > 0.72:
						c = c.lerp(Color(0.85, 0.92, 0.55), 0.55)
			colour.set_pixel(ox + px, oy + py, Color(c.r, c.g, c.b, a * 0.93))
			height[(oy + py) * w + ox + px] = hgt
	# The same lumps may leave a stray speck of alpha at a picture's edge: keep a clear border.
	for k in TILE:
		for edge in 3:
			for pos: Vector2i in [Vector2i(k, edge), Vector2i(k, TILE - 1 - edge), Vector2i(edge, k), Vector2i(TILE - 1 - edge, k)]:
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
