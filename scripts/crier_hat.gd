class_name CrierHat
extends RefCounted
## The herald's official hat of the crown: a tricorn of black felt with the brim turned up in three places,
## edged in gold braid, a plume of white and blue feathers at the back left and, on the front point, a round
## cockade with the crown's insignia (see CrownInsignia). Worn from spring to autumn; in winter the herald's
## fur cap replaces it (see WinterWear, Villager.update_wear).
##
## Built in the head mesh's space (the Knight's head spans y 1.22 to 2.31), the face towards +z.

const TAG := "CrierHat"
const FELT := Color(0.2, 0.22, 0.36)
const BRAID := Color(0.97, 0.78, 0.3)
const WHITE := Color(0.96, 0.95, 0.9)
const BLUE := Color(0.2, 0.32, 0.78)

## The crown of the hat: its foot on the head, its height and its two radii (foot, top).
const CROWN_FOOT := 1.84
const CROWN_HEIGHT := 0.36
const CROWN_R := 0.6
const CROWN_TOP_R := 0.55
## The brim: its height at the crown, how far its middle sides and its three points reach, and how high
## the middle sides are turned up against the crown.
const BRIM_Y := 1.88
const SIDE_R := 0.8
const POINT_R := 1.14
const TURN_UP := 0.3
const SIDES := 36
const RINGS := 5

static var _mesh: ArrayMesh
static var _plume: ArrayMesh
static var _cockade: ArrayMesh
static var _felt_texture: ImageTexture


## Puts the hat on a model (once), on a slot at the head bone. The Knight's hair is part of its head mesh, so
## nothing needs tucking away.
static func put_on(model: Node3D) -> void:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or model.find_child(TAG, true, false) != null:
		return
	var bone := skeleton.find_bone("head")
	if bone < 0:
		return
	var slot := BoneAttachment3D.new()
	slot.name = TAG + "Slot"
	slot.bone_name = "head"
	skeleton.add_child(slot)
	var hat := MeshInstance3D.new()
	hat.name = TAG
	hat.mesh = mesh()
	# The hat is laid out in the rest space of the model: the bone's rest pose undoes it.
	hat.transform = skeleton.get_bone_global_rest(bone).affine_inverse()
	slot.add_child(hat)
	var feathers := MeshInstance3D.new()
	feathers.name = "Plume"
	feathers.mesh = plume()
	feathers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hat.add_child(feathers)
	var badge := MeshInstance3D.new()
	badge.name = "Cockade"
	badge.mesh = cockade()
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hat.add_child(badge)


## Shows the hat or hides it again (in winter the fur cap takes its place).
static func show_hat(model: Node3D, shown: bool) -> void:
	var hat := model.find_child(TAG, true, false) as Node3D
	if hat != null:
		hat.visible = shown


## Where the brim's edge lies at angle `a` (0 is the front point, going round): radius and height.
## Three points, 120 degrees apart (front, back left, back right), with the middle sides between them
## pulled in and turned up.
static func brim_edge(a: float) -> Vector2:
	var corner := pow(0.5 + 0.5 * cos(3.0 * a), 1.4)
	return Vector2(lerpf(SIDE_R, POINT_R, corner), BRIM_Y + TURN_UP * (1.0 - corner))


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# The brim, from the crown out to its edge, in rings. u runs round, v out.
	for k in RINGS:
		var f0 := float(k) / RINGS
		var f1 := float(k + 1) / RINGS
		for i in SIDES:
			var a0 := TAU * i / SIDES
			var a1 := TAU * (i + 1) / SIDES
			_quad(st, _brim_point(a0, f0), _brim_point(a1, f0), _brim_point(a1, f1), _brim_point(a0, f1),
					FELT, Vector2(float(i) / SIDES * 4.0, f0 * 0.45), Vector2(float(i + 1) / SIDES * 4.0, f1 * 0.45))
	# The braid along the brim's edge: a thin band, gold, woven (the lower half of the texture).
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var inner0 := _brim_point(a0, 0.93)
		var inner1 := _brim_point(a1, 0.93)
		var outer0 := _brim_point(a0, 1.0) + Vector3(0, 0.015, 0)
		var outer1 := _brim_point(a1, 1.0) + Vector3(0, 0.015, 0)
		_quad(st, inner0, inner1, outer1, outer0, BRAID, Vector2(float(i) / SIDES * 18.0, 0.55), Vector2(float(i + 1) / SIDES * 18.0, 0.95))
	# The crown: slightly tapering sides and a flat top with a rolled edge.
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var foot0 := Vector3(sin(a0) * CROWN_R, CROWN_FOOT, cos(a0) * CROWN_R)
		var foot1 := Vector3(sin(a1) * CROWN_R, CROWN_FOOT, cos(a1) * CROWN_R)
		var top0 := Vector3(sin(a0) * CROWN_TOP_R, CROWN_FOOT + CROWN_HEIGHT, cos(a0) * CROWN_TOP_R)
		var top1 := Vector3(sin(a1) * CROWN_TOP_R, CROWN_FOOT + CROWN_HEIGHT, cos(a1) * CROWN_TOP_R)
		_quad(st, foot0, foot1, top1, top0, FELT, Vector2(float(i) / SIDES * 4.0, 0.0), Vector2(float(i + 1) / SIDES * 4.0, 0.2))
		var mid := Vector3(0, CROWN_FOOT + CROWN_HEIGHT + 0.02, 0)
		for tri in [[top0, top1, mid]]:
			st.set_color(FELT)
			for p: Vector3 in tri:
				st.set_uv(Vector2(0.5 + p.x * 0.4, 0.2 + p.z * 0.1 + 0.3))
				st.add_vertex(p)
		# A braid band round the crown's foot.
		var band0 := Vector3(sin(a0) * (CROWN_R + 0.012), CROWN_FOOT + 0.02, cos(a0) * (CROWN_R + 0.012))
		var band1 := Vector3(sin(a1) * (CROWN_R + 0.012), CROWN_FOOT + 0.02, cos(a1) * (CROWN_R + 0.012))
		_quad(st, band0, band1, band1 + Vector3(0, 0.08, 0), band0 + Vector3(0, 0.08, 0), BRAID,
				Vector2(float(i) / SIDES * 18.0, 0.55), Vector2(float(i + 1) / SIDES * 18.0, 0.95))
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_texture = felt_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_mesh = st.commit()
	return _mesh


static func _brim_point(a: float, f: float) -> Vector3:
	var edge := brim_edge(a)
	var r := lerpf(CROWN_R - 0.03, edge.x, f)
	# The turned-up part rises late, close to the edge, so the brim lies flat near the crown.
	var y := lerpf(BRIM_Y, edge.y, pow(f, 1.6))
	return Vector3(sin(a) * r, y, cos(a) * r)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, uv0: Vector2, uv1: Vector2) -> void:
	st.set_color(colour)
	var uvs := [Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv1.y)]
	var pts := [a, b, c, a, c, d]
	for k in 6:
		st.set_uv(uvs[k])
		st.add_vertex(pts[k])


## Felt in the upper half (a nap with fine fibres, a few paler flecks), gold braid in the lower half (a plait
## running along, so it reads as a woven cord); the vertex colour dyes each.
static func felt_texture() -> ImageTexture:
	if _felt_texture != null:
		return _felt_texture
	var size := 128
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var fibres := FastNoiseLite.new()
	fibres.seed = 31
	fibres.frequency = 0.8
	var cloud := FastNoiseLite.new()
	cloud.seed = 32
	cloud.frequency = 0.05
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for y in size:
		for x in size:
			if y < size / 2:
				var n := fibres.get_noise_2d(x, y) * 0.5 + 0.5
				var c := cloud.get_noise_2d(x, y) * 0.5 + 0.5
				var v := 0.72 + 0.22 * n + 0.12 * c
				img.set_pixel(x, y, Color(v, v, v, 1.0))
			else:
				# A plait: slanted strands, each lit on one side.
				var strand := float((x + (y - size / 2) * 2) % 8) / 8.0
				var v := 0.7 + 0.3 * absf(strand - 0.5) * 2.0
				if (y - size / 2) % 16 < 2 or (y - size / 2) % 16 > 13:
					v *= 0.7
				img.set_pixel(x, y, Color(v, v, v, 1.0))
	img.generate_mipmaps()
	_felt_texture = ImageTexture.create_from_image(img)
	return _felt_texture


## The cockade on the front point: a round badge with the crown's insignia, standing a little out of the
## felt, with a pleated blue ribbon behind it.
static func cockade() -> ArrayMesh:
	if _cockade != null:
		return _cockade
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var at := Vector3(0, BRIM_Y + 0.2, POINT_R - 0.2)
	var tilt := Basis(Vector3.RIGHT, -0.5)
	var r := 0.17
	var n := 16
	# The ribbon: a ring of pleats behind the badge.
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var wide0 := r * (1.2 + 0.1 * float(i % 2))
		var wide1 := r * (1.2 + 0.1 * float((i + 1) % 2))
		var p0: Vector3 = at + tilt * Vector3(cos(a0) * wide0, sin(a0) * wide0, -0.03)
		var p1: Vector3 = at + tilt * Vector3(cos(a1) * wide1, sin(a1) * wide1, -0.03)
		var m: Vector3 = at + tilt * Vector3(0, 0, -0.02)
		st.set_color(Color.WHITE.darkened(0.25 * float(i % 2)))
		st.set_uv(Vector2(0.5, 0.13))
		st.add_vertex(m)
		st.set_uv(Vector2(0.5, 0.13))
		st.add_vertex(p0)
		st.set_uv(Vector2(0.5, 0.13))
		st.add_vertex(p1)
	# The badge: a disc with the insignia's picture.
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var m: Vector3 = at + tilt * Vector3(0, 0, 0.012)
		var p0: Vector3 = at + tilt * Vector3(cos(a0) * r, sin(a0) * r, 0.0)
		var p1: Vector3 = at + tilt * Vector3(cos(a1) * r, sin(a1) * r, 0.0)
		st.set_color(Color.WHITE)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(m)
		st.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 - sin(a0) * 0.5))
		st.add_vertex(p0)
		st.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 - sin(a1) * 0.5))
		st.add_vertex(p1)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_texture = CrownInsignia.badge()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_cockade = st.commit()
	return _cockade


## The plume: three curved feathers fanning from the back left point, white with a blue one between, each a
## tapering ribbon with a pale quill down its middle and fine barbs along both edges.
static func plume() -> ArrayMesh:
	if _plume != null:
		return _plume
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var root_angle := TAU / 3.0 + 0.0
	var root := Vector3(sin(root_angle) * 0.78, BRIM_Y + 0.17, cos(root_angle) * 0.78)
	var out := Vector3(sin(root_angle), 0, cos(root_angle))
	var side := Vector3.UP.cross(out)
	var feathers := [[WHITE, 0.0, 1.0], [BLUE, 0.35, 0.9], [WHITE, 0.7, 1.05]]
	for f in feathers:
		var spread: float = f[1]
		var length: float = 0.62 * float(f[2])
		var steps := 9
		var last := root
		var last_w := 0.0
		for s in range(1, steps + 1):
			var t := float(s) / steps
			# Up and out, then curling over and down at the tip, swung to the side by `spread`.
			var p := root + out * (0.5 * t * length + 0.7 * t * t * length) + Vector3.UP * (1.1 * t * length - 0.9 * t * t * length * 0.8) + side * spread * 0.25 * t
			var w := 0.13 * sin(t * PI * 0.85 + 0.2) * (1.0 - 0.3 * t)
			var dir := (p - last).normalized()
			var across := dir.cross(out).normalized() * (w + last_w) * 0.5
			var shade: Color = f[0] * (0.88 + 0.12 * float(s % 2))
			st.set_color(shade)
			for q in [last - dir.cross(out).normalized() * last_w, last + dir.cross(out).normalized() * last_w, p + across, last - dir.cross(out).normalized() * last_w, p + across, p - across]:
				st.set_uv(Vector2(0.5, 0.25))
				st.add_vertex(q)
			# The quill.
			st.set_color(Color(0.88, 0.84, 0.72))
			for q in [last - side * 0.004, last + side * 0.004, p + side * 0.004, last - side * 0.004, p + side * 0.004, p - side * 0.004]:
				st.set_uv(Vector2(0.5, 0.25))
				st.add_vertex(q + Vector3(0, 0.002, 0))
			last = p
			last_w = w
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_plume = st.commit()
	return _plume
