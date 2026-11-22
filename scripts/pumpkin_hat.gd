class_name PumpkinHat
extends RefCounted
## A pumpkin for a child's head: in autumn Pip and Pippi now and then run about with a hollowed-out
## pumpkin pulled over the top of their heads, a jack-o'-lantern face cut into its front, a crooked
## green stem and a leaf on top. They wear it for a while, put it away again, and later fetch it
## once more (see Villager._mind_pumpkin): it is a game, not their clothes.
##
## Built in code, in the chunky low-poly shapes of the KayKit people, and hung from the head bone
## like the postmaster's cap (see PostCap), so it bobs with every step, cartwheel and somersault.
## One mesh is shared by everyone who wears it.

## Who plays with a pumpkin (roles, see Villager.ROLES).
const WEARERS := ["7", "pippi"]
## How long a child keeps the pumpkin on, and how long it stays off before the next time (seconds).
const ON_TIME := Vector2(40.0, 100.0)
const OFF_TIME := Vector2(90.0, 240.0)
## How long the pumpkin takes to pop on or off (seconds).
const POP := 0.25
const TAG := "PumpkinHat"

const ORANGE := Color(0.95, 0.52, 0.12)
const GROOVE := Color(0.8, 0.36, 0.08)
const CARVED := Color(0.3, 0.12, 0.03)
const STEM := Color(0.36, 0.42, 0.16)
const LEAF := Color(0.3, 0.55, 0.2)

## The pumpkin's outline from its rim up to its top, as (height, radius) in the head mesh's space
## (the Rogue's head: the face looks towards +z, the top of the head is at about y 2.19). The rim
## sits on the brow, above the eyes.
const PROFILE := [
	Vector2(1.74, 0.55), Vector2(1.84, 0.63), Vector2(1.98, 0.68), Vector2(2.13, 0.67),
	Vector2(2.28, 0.6), Vector2(2.41, 0.46), Vector2(2.5, 0.27), Vector2(2.54, 0.08),
]
const SIDES := 24
## The ribs: this many lobes, the grooves between them cut this deep (a share of the radius).
const RIBS := 8
const GROOVE_DEPTH := 0.07

static var _mesh: ArrayMesh = null


## Whether the pumpkin is on the model's head.
static func worn(model: Node3D) -> bool:
	var slot := HairLook.head_slot(model) if model else null
	return slot != null and slot.get_node_or_null(TAG) != null


## Puts the pumpkin on (once). Locks that would poke through are tucked away (see HairLook.cover).
static func put_on(model: Node3D, pop := false) -> void:
	var slot := HairLook.head_slot(model)
	if slot == null or slot.get_node_or_null(TAG):
		return
	var hat := MeshInstance3D.new()
	hat.name = TAG
	hat.mesh = mesh()
	hat.transform = slot.get_meta("bind")
	hat.set_meta("was_covered", slot.get_meta("covered", false))
	slot.add_child(hat)
	HairLook.cover(model, true)
	if pop and hat.is_inside_tree():
		var full := hat.scale
		hat.scale = full * 0.05
		hat.create_tween().tween_property(hat, "scale", full, POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Takes the pumpkin off again, and lets the hair out (unless something else covered it before).
static func take_off(model: Node3D) -> void:
	var slot := HairLook.head_slot(model) if model else null
	var hat := slot.get_node_or_null(TAG) if slot else null
	if hat == null:
		return
	slot.remove_child(hat)
	hat.queue_free()
	HairLook.cover(model, hat.get_meta("was_covered", false))


## The radius of the pumpkin at height `y` (on a rib's crest), from PROFILE.
static func radius_at(y: float) -> float:
	for i in PROFILE.size() - 1:
		var a: Vector2 = PROFILE[i]
		var b: Vector2 = PROFILE[i + 1]
		if y <= b.x:
			return lerpf(a.y, b.y, clampf((y - a.x) / (b.x - a.x), 0.0, 1.0))
	return PROFILE[-1].y


## How far out the skin bulges at angle `a` round the pumpkin: 1 on a rib, less in a groove.
static func _rib(a: float) -> float:
	return 1.0 - GROOVE_DEPTH * (1.0 - absf(cos(a * RIBS * 0.5)))


## A point on the pumpkin's skin at angle `a` and height `y`, `out` metres off it.
static func _skin(a: float, y: float, out := 0.0) -> Vector3:
	var r := radius_at(y) * _rib(a) + out
	return Vector3(sin(a) * r, y, cos(a) * r)


## The pumpkin, one mesh with its colours in the vertices.
static func mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# The ribbed body, ring by ring, darker down in the grooves. The inside shows from below.
	for row in PROFILE.size() - 1:
		var y0: float = PROFILE[row].x
		var y1: float = PROFILE[row + 1].x
		for i in SIDES:
			var a0 := TAU * i / SIDES
			var a1 := TAU * (i + 1) / SIDES
			var c := GROOVE.lerp(ORANGE, (_rib((a0 + a1) * 0.5) - 1.0 + GROOVE_DEPTH) / GROOVE_DEPTH)
			var b0 := _skin(a0, y0)
			var b1 := _skin(a1, y0)
			var t0 := _skin(a0, y1)
			var t1 := _skin(a1, y1)
			st.set_color(c)
			for p in [b0, t1, b1, b0, t0, t1]:
				st.add_vertex(p)
			st.set_color(CARVED)
			for p in [b0, b1, t1, b0, t1, t0]:
				st.add_vertex(p)
	_face(st)
	_stem(st)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.roughness = 0.7
	st.set_material(mat)
	_mesh = st.commit()
	return _mesh


## The jack-o'-lantern face on the front: two triangle eyes and a zigzag grin, cut a hair's breadth
## proud of the skin so they never flicker into it.
static func _face(st: SurfaceTool) -> void:
	st.set_color(CARVED)
	const OUT := 0.025
	# The eyes: points up, as (angle, height) corners.
	for side in [-1.0, 1.0]:
		var a: float = side * 0.36
		_flat(st, [_skin(a - 0.13, 2.06, OUT), _skin(a + 0.13, 2.06, OUT), _skin(a, 2.19, OUT)])
	# The nose, a small triangle between them.
	_flat(st, [_skin(-0.06, 1.99, OUT), _skin(0.06, 1.99, OUT), _skin(0.0, 2.04, OUT)])
	# The grin: a band from cheek to cheek with teeth cut into its top edge.
	const TEETH := 6
	const WIDE := 0.62
	for k in TEETH:
		var a0 := lerpf(-WIDE, WIDE, float(k) / TEETH)
		var a1 := lerpf(-WIDE, WIDE, float(k + 1) / TEETH)
		var mid := (a0 + a1) * 0.5
		# The grin curves up at the corners.
		var lift0 := 0.04 * pow(absf(a0) / WIDE, 2.0)
		var lift1 := 0.04 * pow(absf(a1) / WIDE, 2.0)
		var low0 := 1.87 + lift0
		var low1 := 1.87 + lift1
		var top0 := 1.94 + lift0
		var top1 := 1.94 + lift1
		var notch := 1.915 + 0.04 * pow(absf(mid) / WIDE, 2.0)
		_flat(st, [_skin(a0, low0, OUT), _skin(a1, low1, OUT), _skin(a1, top1, OUT), _skin(mid, notch, OUT)])
		_flat(st, [_skin(a0, low0, OUT), _skin(mid, notch, OUT), _skin(a0, top0, OUT)])


## A flat polygon (corners counter-clockwise seen from outside), as a fan, with its back too.
static func _flat(st: SurfaceTool, corners: Array) -> void:
	for k in range(1, corners.size() - 1):
		for p in [corners[0], corners[k], corners[k + 1]]:
			st.add_vertex(p)
		for p in [corners[0], corners[k + 1], corners[k]]:
			st.add_vertex(p)


## The crooked stem on top, leaning back a little, and one leaf at its foot.
static func _stem(st: SurfaceTool) -> void:
	st.set_color(STEM)
	const SEGS := 6
	var foot := Vector3(0, PROFILE[-1].x - 0.03, 0)
	var tip := foot + Vector3(0.03, 0.15, -0.05)
	for i in SEGS:
		var a0 := TAU * i / SEGS
		var a1 := TAU * (i + 1) / SEGS
		var b0 := foot + Vector3(sin(a0), 0, cos(a0)) * 0.07
		var b1 := foot + Vector3(sin(a1), 0, cos(a1)) * 0.07
		var t0 := tip + Vector3(sin(a0), 0, cos(a0)) * 0.045
		var t1 := tip + Vector3(sin(a1), 0, cos(a1)) * 0.045
		for p in [b0, b1, t1, b0, t1, t0]:
			st.add_vertex(p)
		st.add_vertex(t1)
		st.add_vertex(tip + Vector3(0, 0.01, 0))
		st.add_vertex(t0)
	st.set_color(LEAF)
	var base := foot + Vector3(0.05, 0.02, 0.02)
	_flat(st, [base, base + Vector3(0.16, 0.05, 0.06), base + Vector3(0.24, 0.02, 0.18), base + Vector3(0.08, 0.03, 0.14)])
