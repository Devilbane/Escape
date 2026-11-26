class_name BeeVeil
extends RefCounted
## The beekeeper's hat (see Beekeeper): a wide-brimmed hat of plaited straw with a band of brown cloth, and a
## fine net veil that hangs from the brim down to the shoulders, tucked in at the neck. Built in code and
## hung from the head bone (see HairLook.head_slot), like the postmaster's cap (see PostCap). Worn by a villager
## whose role has "veil": true. The straw has the texture of the skeps (see HiveModels.straw_texture), the net is a
## faint check of threads over see-through gauze.

## The head mesh's space (the Rogue's head: the face looks towards +z, the top of the head is at about y 2.19).
const BRIM_Y := 1.92
const BRIM_RADIUS := 0.74
## The brim droops this far at its edge.
const DROOP := 0.1
const CROWN_TOP := 2.36
const CROWN_RADIUS := 0.56
const NECK_Y := 1.42
const NECK_RADIUS := 0.55
const SIDES := 24

static var _hat: ArrayMesh = null
static var _veil: ArrayMesh = null
static var _net: ImageTexture = null


## Puts the hat and the veil on a model's head (once). Hair locks that would poke through are tucked away.
static func put_on(model: Node3D) -> void:
	var slot := HairLook.head_slot(model)
	if slot == null or slot.get_node_or_null("BeeVeil"):
		return
	var hat := MeshInstance3D.new()
	hat.name = "BeeVeil"
	hat.mesh = hat_mesh()
	hat.transform = slot.get_meta("bind")
	slot.add_child(hat)
	var veil := MeshInstance3D.new()
	veil.name = "Veil"
	veil.mesh = veil_mesh()
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hat.add_child(veil)
	HairLook.cover(model, true)


static func _vertex(st: SurfaceTool, r: float, y: float, a: float, u: float, v: float) -> void:
	st.set_uv(Vector2(u, v))
	st.add_vertex(Vector3(sin(a) * r, y, cos(a) * r))


## A band of quads between two rings, both faces drawn.
static func _band(st: SurfaceTool, r0: float, y0: float, r1: float, y1: float, v0: float, v1: float, turns: float) -> void:
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var u0 := turns * i / SIDES
		var u1 := turns * (i + 1) / SIDES
		for corner in [[r0, y0, a0, u0, v0], [r0, y0, a1, u1, v0], [r1, y1, a1, u1, v1], [r0, y0, a0, u0, v0], [r1, y1, a1, u1, v1], [r1, y1, a0, u0, v1]]:
			_vertex(st, corner[0], corner[1], corner[2], corner[3], corner[4])
		for corner in [[r0, y0, a0, u0, v0], [r1, y1, a1, u1, v1], [r0, y0, a1, u1, v0], [r0, y0, a0, u0, v0], [r1, y1, a0, u0, v1], [r1, y1, a1, u1, v1]]:
			_vertex(st, corner[0], corner[1], corner[2], corner[3], corner[4])


## The straw hat: the brim, a rolled edge, the crown with its dome and the band round it.
static func hat_mesh() -> ArrayMesh:
	if _hat:
		return _hat
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The brim: out and a little down, and a rolled rim.
	_band(st, CROWN_RADIUS - 0.05, BRIM_Y + 0.03, BRIM_RADIUS * 0.7, BRIM_Y, 0.0, 0.5, 3.0)
	_band(st, BRIM_RADIUS * 0.7, BRIM_Y, BRIM_RADIUS, BRIM_Y - DROOP, 0.5, 1.0, 3.0)
	_band(st, BRIM_RADIUS, BRIM_Y - DROOP, BRIM_RADIUS - 0.02, BRIM_Y - DROOP - 0.04, 1.0, 1.1, 3.0)
	# The crown, round and a little tapered, and its dome.
	_band(st, CROWN_RADIUS, BRIM_Y + 0.02, CROWN_RADIUS - 0.04, BRIM_Y + 0.26, 0.0, 0.4, 2.0)
	_band(st, CROWN_RADIUS - 0.04, BRIM_Y + 0.26, CROWN_RADIUS - 0.2, CROWN_TOP - 0.06, 0.4, 0.7, 2.0)
	_band(st, CROWN_RADIUS - 0.2, CROWN_TOP - 0.06, 0.05, CROWN_TOP, 0.7, 1.0, 2.0)
	st.generate_normals()
	var straw := HiveModels.straw_material().duplicate() as StandardMaterial3D
	straw.cull_mode = BaseMaterial3D.CULL_DISABLED
	straw.albedo_color = Color(0.98, 0.93, 0.82)
	st.set_material(straw)
	var mesh := st.commit()
	# The band round the crown, a dark cloth with a stitched edge.
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	_band(band, CROWN_RADIUS + 0.012, BRIM_Y + 0.05, CROWN_RADIUS - 0.01, BRIM_Y + 0.17, 0.0, 1.0, 6.0)
	band.generate_normals()
	var cloth := StandardMaterial3D.new()
	cloth.albedo_texture = HiveModels.wood_texture(Color(0.4, 0.27, 0.16))
	cloth.roughness = 1.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	band.set_material(cloth)
	band.commit(mesh)
	_hat = mesh
	return mesh


## A check of fine threads: the gauze is mostly clear.
static func net_texture() -> ImageTexture:
	if _net:
		return _net
	var size := 32
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var thread := x % 8 < 1 or y % 8 < 1
			img.set_pixel(x, y, Color(0.9, 0.9, 0.86, 0.5) if thread else Color(0.85, 0.88, 0.9, 0.03))
	img.generate_mipmaps()
	_net = ImageTexture.create_from_image(img)
	return _net


## The veil: a skirt of net from the brim to the neck, where it is tucked in.
static func veil_mesh() -> ArrayMesh:
	if _veil:
		return _veil
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_band(st, BRIM_RADIUS - 0.03, BRIM_Y - DROOP - 0.03, NECK_RADIUS + 0.05, NECK_Y + 0.25, 0.0, 1.0, 10.0)
	_band(st, NECK_RADIUS + 0.05, NECK_Y + 0.25, NECK_RADIUS - 0.03, NECK_Y, 1.0, 1.3, 10.0)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = net_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	st.set_material(mat)
	_veil = st.commit()
	return _veil
