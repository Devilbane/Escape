class_name Bandana
extends RefCounted
## A cloth bandana tied round the head, worn by a villager whose role has "bandana" (Smith Gorm): a
## close cap of cloth over the crown, a band across the brow with a cream dot pattern, and a knot at
## the back of the head with two short tails. It is built in code in the chunky low-poly shapes of
## WinterHats and hung from the head bone, so it moves with the head. The cloth is dressed with the
## woven grain of GearLook ("cloth"), so it reads as dyed linen and not as plastic.
##
## Everything is measured from the head's box (WinterWear._head_box), so the same bandana fits any
## model. A winter hat takes its place (see WinterWear.put_on) and it comes back with the thaw.

const TAG := "Bandana"
const RED := Color(0.62, 0.14, 0.12)
const CREAM := Color(0.93, 0.85, 0.66)
const SIDES := 16
## How square the rings are (2 is round): the KayKit heads are rounded boxes.
const SQUARE := 2.6
## The band across the brow, measured down from the crown, and how far the cloth sits off the skin.
const BAND_TOP := 0.1
const BAND_DEPTH := 0.24
const ROOM := 1.06

const TEX_W := 128
const TEX_H := 64

static var _texture: ImageTexture = null
static var _mesh: Dictionary = {}


## Ties the bandana on the model's head (once).
static func put_on(model: Node3D, colour := RED) -> void:
	if model.find_child(TAG, true, false) != null:
		return
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone("head") < 0:
		return
	var slot := BoneAttachment3D.new()
	slot.name = TAG + "Slot"
	slot.bone_name = "head"
	var bind := skeleton.get_bone_global_rest(skeleton.find_bone("head")).affine_inverse()
	slot.set_meta("bind", bind)
	skeleton.add_child(slot)
	var cloth := MeshInstance3D.new()
	cloth.name = TAG
	cloth.mesh = GearLook.with_rest_positions(mesh(WinterWear._head_box(model), colour))
	cloth.material_override = GearLook._look(texture(colour), "cloth")
	cloth.transform = bind
	slot.add_child(cloth)


## Shows or hides the bandana (a winter hat goes over it).
static func show_on(model: Node3D, shown: bool) -> void:
	var cloth := model.find_child(TAG, true, false) as Node3D
	if cloth:
		cloth.visible = shown


## Whether the model wears a bandana.
static func is_worn(model: Node3D) -> bool:
	return model.find_child(TAG, true, false) != null


## The cloth's texture: the colour with a row of small cream dots along the band (the upper half
## of the picture, which the band's corners point at) and a plain, slightly paler weave below.
static func texture(colour := RED) -> ImageTexture:
	if _texture and colour == RED:
		return _texture
	var img := Image.create(TEX_W, TEX_H, true, Image.FORMAT_RGB8)
	img.fill(colour)
	var half := TEX_H / 2
	for row in 2:
		for k in 16:
			# Dots in a staggered grid, two texels wide.
			var cx := int((k + 0.25 + 0.5 * row) * TEX_W / 16.0) % TEX_W
			var cy := 8 + row * 14
			for dx in 2:
				for dy in 2:
					img.set_pixel((cx + dx) % TEX_W, (cy + dy) % half, CREAM)
	# A pale hem along the lower edge of the band and at the tails' ends.
	for x in TEX_W:
		img.set_pixel(x, half - 1, CREAM.darkened(0.1))
		img.set_pixel(x, TEX_H - 1, CREAM.darkened(0.1))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	if colour == RED:
		_texture = tex
	return tex


## The bandana, sized to the head's box, in one mesh.
static func mesh(box: AABB, colour := RED) -> ArrayMesh:
	var key := [box, colour]
	if _mesh.has(key):
		return _mesh[key]
	var top := box.end.y
	var rx := box.size.x * 0.5 * ROOM
	var rz := box.size.z * 0.5 * ROOM
	var cz := box.get_center().z
	var cx := box.get_center().x
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# The band across the brow: a little lower at the front than at the back, as it is tied.
	var y0 := top - BAND_TOP - BAND_DEPTH
	_band(st, y0, top - BAND_TOP, rx, rz, cx, cz, 0.04)
	# The cloth over the crown, closing in to the middle.
	var rings := [[top - BAND_TOP, 1.0, 0.0], [top - 0.03, 0.96, 0.02], [top + 0.04, 0.8, 0.0], [top + 0.09, 0.5, 0.0], [top + 0.11, 0.0, 0.0]]
	_dome(st, rings, rx, rz, cx, cz)
	# The knot and the two tails at the back.
	var back := cz - rz * 1.0
	var knot_y := top - BAND_TOP - BAND_DEPTH * 0.45
	_box(st, Vector3(cx, knot_y, back - 0.03), Vector3(0.17, 0.15, 0.14), 0.0)
	for side in [-1.0, 1.0]:
		_tail(st, Vector3(cx + side * 0.04, knot_y - 0.05, back - 0.08), side)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, StandardMaterial3D.new())
	_mesh[key] = m
	return m


## A point on the rounded square at the angle `a` (0 is the front, towards +z).
static func _on(a: float, y: float, rx: float, rz: float, cx: float, cz: float) -> Vector3:
	var s := sin(a)
	var c := cos(a)
	var k := 2.0 / SQUARE
	var x := signf(s) * pow(absf(s), k) * rx
	var z := signf(c) * pow(absf(c), k) * rz
	return Vector3(cx + x, y, cz + z)


## A closed ring of quads from y0 up to y1. `dip`: how much lower the front edge hangs than the back.
static func _band(st: SurfaceTool, y0: float, y1: float, rx: float, rz: float, cx: float, cz: float, dip: float) -> void:
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var d0 := dip * (0.5 + 0.5 * cos(a0))
		var d1 := dip * (0.5 + 0.5 * cos(a1))
		var b0 := _on(a0, y0 - d0, rx, rz, cx, cz)
		var b1 := _on(a1, y0 - d1, rx, rz, cx, cz)
		var t0 := _on(a0, y1, rx, rz, cx, cz)
		var t1 := _on(a1, y1, rx, rz, cx, cz)
		var u0 := float(i) / SIDES
		var u1 := float(i + 1) / SIDES
		_quad(st, [b0, b1, t1, t0], [Vector2(u0, 0.5), Vector2(u1, 0.5), Vector2(u1, 0.0), Vector2(u0, 0.0)])


## The crown: rings of [height, width factor, set-back] closed at the top, in the plain half of the
## picture.
static func _dome(st: SurfaceTool, rings: Array, rx: float, rz: float, cx: float, cz: float) -> void:
	for r in rings.size() - 1:
		var lo: Array = rings[r]
		var hi: Array = rings[r + 1]
		for i in SIDES:
			var a0 := TAU * i / SIDES
			var a1 := TAU * (i + 1) / SIDES
			var b0 := _on(a0, lo[0], rx * lo[1], rz * lo[1], cx, cz)
			var b1 := _on(a1, lo[0], rx * lo[1], rz * lo[1], cx, cz)
			var t0 := _on(a0, hi[0], rx * hi[1], rz * hi[1], cx, cz)
			var t1 := _on(a1, hi[0], rx * hi[1], rz * hi[1], cx, cz)
			_quad(st, [b0, b1, t1, t0], _plain(i + r))


## UVs that stay on the plain weave in the lower half of the picture, a texel or two from each edge.
static func _plain(k: int) -> Array:
	var u := 0.25 + 0.05 * (k % 3)
	return [Vector2(u, 0.62), Vector2(u + 0.05, 0.62), Vector2(u + 0.05, 0.7), Vector2(u, 0.7)]


## A small block of cloth: the knot.
static func _box(st: SurfaceTool, at: Vector3, size: Vector3, _lean: float) -> void:
	var h := size * 0.5
	var c := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		_quad(st, [at + c[f[0]], at + c[f[1]], at + c[f[2]], at + c[f[3]]], _plain(f[0]))


## One tail: a flat strip of cloth that hangs from the knot, splayed to its side and swinging a little
## out behind the head, ending in a point-cut hem.
static func _tail(st: SurfaceTool, from: Vector3, side: float) -> void:
	var drop := 0.28
	var wide := 0.07
	var drift := Vector3(side * 0.09, -drop, -0.1)
	var tip := from + drift
	var across := Vector3(wide, 0.0, 0.0)
	# The two faces of the strip, front and back, in the plain half; the hem at the foot is cream.
	var a := from - across
	var b := from + across
	var c := tip + across * 1.5
	var d := tip - across * 1.5
	var plain := [Vector2(0.3, 0.55), Vector2(0.4, 0.55), Vector2(0.4, 0.98), Vector2(0.3, 0.98)]
	_quad(st, [a, b, c, d], plain)
	_quad(st, [b, a, d, c], plain)


static func _quad(st: SurfaceTool, p: Array, uv: Array) -> void:
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[k])
		st.add_vertex(p[k])
