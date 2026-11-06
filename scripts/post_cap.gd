class_name PostCap
extends RefCounted
## The postmaster's peaked cap: a stiff navy crown that flares out to a flat
## top, a post-yellow band round it, a black lacquered peak over the eyes, a
## thin gold cord across the front and a small brass post horn above the band.
## Built in code, in the chunky low-poly shapes of the KayKit people, and hung
## from the head bone like the mohawk's crest (see HairLook.head_slot), so it
## moves with the head. Worn by a villager whose role has "cap": "post".

const NAVY := Color(0.13, 0.17, 0.32)
const POST_YELLOW := Color(0.98, 0.78, 0.2)
const PEAK_BLACK := Color(0.06, 0.06, 0.07)
const BRASS := Color(1.0, 0.78, 0.32)

## Where the cap sits, in the head mesh's space (the Rogue's head: the face
## looks towards +z, the top of the head is at about y 2.19).
const BAND_FOOT := 1.77
const BAND_HEIGHT := 0.17
const BAND_RADIUS := 0.53
## The crown puffs out over the band to FLARE_Y, then rises straight to the
## wider, flat top.
const FLARE_Y := 2.05
const TOP_Y := 2.23
const TOP_RADIUS := 0.65
## The peak reaches this far out in front of the head and dips this much.
const PEAK_REACH := 0.84
const PEAK_DIP := 0.08
const SIDES := 14

static var _mesh: ArrayMesh = null
static var _cord: ArrayMesh = null


## Puts the cap on a model's head (once). Hair locks that would poke through
## are tucked away (see HairLook.cover).
static func put_on(model: Node3D) -> void:
	var slot := HairLook.head_slot(model)
	if slot == null or slot.get_node_or_null("PostCap"):
		return
	var cap := MeshInstance3D.new()
	cap.name = "PostCap"
	cap.mesh = mesh()
	cap.transform = slot.get_meta("bind")
	# A bird perches on the flat top itself (see Villager._top_of_head).
	cap.set_meta("flat_top", true)
	slot.add_child(cap)
	var cord := MeshInstance3D.new()
	cord.name = "Cord"
	cord.mesh = _cord_mesh()
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap.add_child(cord)
	HairLook.cover(model, true)


## The cap itself, one mesh with its colours in the vertices.
static func mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var band_top := BAND_FOOT + BAND_HEIGHT
	# The navy crown under the band, and the yellow band round it.
	_ring(st, BAND_FOOT, BAND_RADIUS, BAND_FOOT + 0.06, BAND_RADIUS, NAVY)
	_ring(st, BAND_FOOT + 0.06, BAND_RADIUS + 0.012, band_top - 0.03, BAND_RADIUS + 0.012, POST_YELLOW)
	_ring(st, band_top - 0.03, BAND_RADIUS, band_top, BAND_RADIUS + 0.01, NAVY)
	# The crown flares out to the top, which overhangs it a little: a yellow
	# piping round the edge, then the flat, slightly domed top.
	_ring(st, band_top, BAND_RADIUS + 0.01, FLARE_Y, TOP_RADIUS, NAVY)
	_ring(st, FLARE_Y, TOP_RADIUS, TOP_Y - 0.03, TOP_RADIUS, NAVY)
	_ring(st, TOP_Y - 0.03, TOP_RADIUS, TOP_Y, TOP_RADIUS + 0.008, POST_YELLOW)
	_disc(st, TOP_Y, TOP_RADIUS + 0.008, TOP_Y + 0.025, NAVY)
	_peak(st)
	# The badge stands on the front of the crown, above the puff.
	_badge(st, Vector3(0, (FLARE_Y + TOP_Y - 0.03) * 0.5, TOP_RADIUS + 0.012), 0.0)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.75
	st.set_material(mat)
	_mesh = st.commit()
	return _mesh


## A band of quads round the crown from (y0, r0) up to (y1, r1). Flat shaded
## like the KayKit models: every quad gets its own corners.
static func _ring(st: SurfaceTool, y0: float, r0: float, y1: float, r1: float, colour: Color) -> void:
	st.set_smooth_group(-1)
	st.set_color(colour)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var b0 := Vector3(sin(a0) * r0, y0, cos(a0) * r0)
		var b1 := Vector3(sin(a1) * r0, y0, cos(a1) * r0)
		var t0 := Vector3(sin(a0) * r1, y1, cos(a0) * r1)
		var t1 := Vector3(sin(a1) * r1, y1, cos(a1) * r1)
		for p in [b0, b1, t1, b0, t1, t0]:
			st.add_vertex(p)
		# The inside, seen from below when the head tips back.
		for p in [b0, t1, b1, b0, t0, t1]:
			st.add_vertex(p)


## The top: a shallow cone from the rim (at `y`) up to the middle (`peak`).
static func _disc(st: SurfaceTool, y: float, r: float, peak: float, colour: Color) -> void:
	st.set_smooth_group(-1)
	st.set_color(colour)
	var mid := Vector3(0, peak, 0)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		st.add_vertex(Vector3(sin(a1) * r, y, cos(a1) * r))
		st.add_vertex(Vector3(sin(a0) * r, y, cos(a0) * r))
		st.add_vertex(mid)


## The stiff peak over the eyes: a half moon from the foot of the band out
## in front, dipping towards its edge, with a top, an underside and a rim.
static func _peak(st: SurfaceTool) -> void:
	st.set_smooth_group(-1)
	st.set_color(PEAK_BLACK)
	const STEPS := 10
	const SPREAD := 1.25
	const THICK := 0.025
	var inner := []
	var outer := []
	for k in STEPS + 1:
		var a := lerpf(-SPREAD, SPREAD, float(k) / STEPS)
		# Round in front, tucked into the band at the sides.
		var reach := lerpf(BAND_RADIUS + 0.02, PEAK_REACH, pow(cos(a / SPREAD * PI * 0.5), 0.7))
		inner.append(Vector3(sin(a) * BAND_RADIUS, BAND_FOOT + 0.02, cos(a) * BAND_RADIUS))
		outer.append(Vector3(sin(a) * reach * 0.82, BAND_FOOT + 0.02 - PEAK_DIP * (reach - BAND_RADIUS) / (PEAK_REACH - BAND_RADIUS), cos(a) * reach))
	var down := Vector3(0, -THICK, 0)
	for k in STEPS:
		var i0: Vector3 = inner[k]
		var i1: Vector3 = inner[k + 1]
		var o0: Vector3 = outer[k]
		var o1: Vector3 = outer[k + 1]
		for p in [i0, o0, o1, i0, o1, i1]:
			st.add_vertex(p)
		for p in [i0 + down, o1 + down, o0 + down, i0 + down, i1 + down, o1 + down]:
			st.add_vertex(p)
		for p in [o0, o0 + down, o1 + down, o0, o1 + down, o1]:
			st.add_vertex(p)


## The post horn on the front of the crown: a brass loop of a horn with its
## bell to one side, standing a little off the cloth and leaning back by
## `tilt` (radians), as the crown does.
static func _badge(st: SurfaceTool, at: Vector3, tilt: float) -> void:
	st.set_smooth_group(-1)
	st.set_color(BRASS)
	const STEPS := 12
	const R := 0.05
	const W := 0.017
	const DEPTH := 0.02
	# Flat on the badge's own plane (x right, y up), then leant back with the
	# crown and set in place.
	var lean := Transform3D(Basis(Vector3.RIGHT, tilt), at)
	var back := lean.basis * Vector3(0, 0, -DEPTH)
	var put := func(points: Array) -> void:
		var p: Array = points.map(func(q: Vector2) -> Vector3: return lean * Vector3(q.x, q.y, 0))
		_slab(st, p[0], p[1], p[2], p[3], back)
	# The coiled tube: a ring, open at the top left where the mouthpiece is.
	for k in STEPS - 2:
		var d0 := Vector2(sin(TAU * (k + 1) / STEPS), cos(TAU * (k + 1) / STEPS))
		var d1 := Vector2(sin(TAU * (k + 2) / STEPS), cos(TAU * (k + 2) / STEPS))
		put.call([d0 * (R - W), d0 * (R + W), d1 * (R + W), d1 * (R - W)])
	# The bell flares out to the right of the loop.
	var bell := Vector2(R + 0.015, R * 0.35)
	put.call([bell + Vector2(-0.03, 0.016), bell + Vector2(0.05, 0.05), bell + Vector2(0.05, -0.05), bell + Vector2(-0.03, -0.016)])
	# The mouthpiece, a short stub at the open end of the coil.
	var mouth := Vector2(-R * 0.45, R * 0.95)
	put.call([mouth + Vector2(-0.012, 0.025), mouth + Vector2(0.012, 0.025), mouth + Vector2(0.012, -0.03), mouth + Vector2(-0.012, -0.03)])


## A flat piece with a front at a..d (clockwise, seen from the front) and
## its edges reaching back by `back`.
static func _slab(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, back: Vector3) -> void:
	for p in [a, b, c, a, c, d]:
		st.add_vertex(p)
	for edge in [[a, b], [b, c], [c, d], [d, a]]:
		var p: Vector3 = edge[0]
		var q: Vector3 = edge[1]
		for v in [p, p + back, q + back, p, q + back, q]:
			st.add_vertex(v)


## The gold chin cord, across the front of the band just above the peak,
## on the navy strip under the yellow band.
static func _cord_mesh() -> ArrayMesh:
	if _cord:
		return _cord
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BRASS
	mat.metallic = 0.6
	mat.roughness = 0.35
	var segments := []
	var points := []
	var r := BAND_RADIUS + 0.018
	for k in 9:
		var a := lerpf(-1.05, 1.05, k / 8.0)
		points.append(Vector3(sin(a) * r, BAND_FOOT + 0.035, cos(a) * r))
	for k in points.size() - 1:
		segments.append([points[k], points[k + 1]])
	_cord = Effects.cord_mesh(segments, 0.014, mat)
	return _cord
