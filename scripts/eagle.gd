class_name Eagle
extends Node3D
## The giant eagle that carries a fallen hero home (see Rescue): a broad body
## with a white head, a hooked beak and a fierce brow, a white fanned tail, long
## broad wings and feathered legs ending in big talons. It is built once from a
## few small meshes (vertex colours, no textures) and posed from code, so the
## whole bird costs a handful of draws.
##
## Each wing has an arm (the broad inner wing with its row of scalloped flight
## feathers) and a hand at the wrist that carries six slotted finger feathers,
## like a real eagle's. They move as a bird's wings do (see pose):
##  - soaring: wings spread flat with a slight rise to the tips, hardly moving;
##  - flapping: the arm swings, the hand lags a little behind it and on the
##    upstroke is drawn in and swept back, the finger feathers folding closed;
##  - braking to land or hover: the wings go forward and flat against the air,
##    the tail drops and fans out, the head looks down, the feet reach forward.
## The legs tuck back in flight and hang with the toes spread to grab; closing
## the toes (grip) takes hold of the hero.
##
## It is built facing -Z and upright, in model units that SIZE turns into metres.

## How big the giant eagle is: one model unit in metres (a wing span of about 12).
const SIZE := 2.2
## How far the talons hang below the body at rest, in model units.
const HANG := 0.72

const DARK := Color(0.2, 0.125, 0.07)
const BROWN := Color(0.3, 0.19, 0.1)
const LIGHT := Color(0.42, 0.29, 0.16)
const TIP := Color(0.1, 0.065, 0.04)
const WHITE := Color(0.96, 0.94, 0.88)
const CREAM := Color(0.88, 0.82, 0.68)
const YELLOW := Color(0.97, 0.76, 0.12)
const CLAW := Color(0.12, 0.1, 0.08)

## Where the shoulders, the tail and the hips join the body.
const SHOULDER := Vector3(0.22, 0.1, -0.05)
const TAIL_AT := Vector3(0, 0.04, 0.68)
const HIP := Vector3(0.14, -0.1, -0.12)
## The wrist: where the arm ends and the hand begins (on the arm's own scale).
const ARM := 1.35

static var _material: StandardMaterial3D

## The wing beat, in turns: whole numbers of it are beats flown.
var phase := 0.0
var _wings: Array[Dictionary] = []
var _tail: Node3D
var _head: Node3D
var _legs: Array[Dictionary] = []


func _init() -> void:
	name = "Eagle"
	_build()


## Moves the wing beat on by `delta` seconds at `freq` beats a second.
## Returns true on the beat's downstroke (when it should be heard).
func beat(delta: float, freq: float) -> bool:
	var before := floorf(phase + 0.25)
	phase += delta * freq
	return floorf(phase + 0.25) > before


## Poses the eagle:
## `amp` 0 to 1 how hard the wings beat (0 soars on spread wings);
## `flare` 0 to 1 braking: wings forward and flat, tail down and fanned;
## `tuck` 0 to 1 the legs drawn up behind (flying) or hanging (0);
## `grip` 0 to 1 the toes closed; `look` 0 to 1 the head turned down.
func pose(amp: float, flare: float, tuck: float, grip: float, look: float) -> void:
	var a := phase * TAU
	var down := sin(a)
	var up_stroke := maxf(cos(a), 0.0) * amp
	for wing in _wings:
		var side: float = wing.side
		var shoulder: Node3D = wing.shoulder
		var wrist: Node3D = wing.wrist
		# The arm rises and falls; spread flat and slightly raised when soaring.
		var raise := lerpf(0.14, 0.02, amp) + amp * 0.78 * down
		shoulder.rotation = Vector3(0.38 * flare, -side * (0.06 - 0.2 * flare + 0.12 * up_stroke), side * raise)
		# The hand lags behind the arm, droops on the recovery, and is swept
		# back and drawn in then; the finger tips curl up when soaring.
		var hand := lerpf(0.06, 0.0, amp) + amp * 0.42 * sin(a - 1.0) - 0.12 * up_stroke
		wrist.rotation = Vector3(0.0, -side * (0.1 - 0.16 * flare + 0.38 * up_stroke), side * hand)
		wrist.scale = Vector3(1.0 - 0.24 * up_stroke, 1.0, 1.0)
	# The tail: a fan, dropping and spreading to brake, lifting when it dives.
	_tail.rotation.x = 0.7 * flare - 0.06 * amp * down
	_tail.scale = Vector3(1.0 + 0.4 * flare, 1.0, 1.0 + 0.1 * flare)
	_head.rotation.x = -0.45 * look + 0.05 * amp * down
	for leg in _legs:
		var pivot: Node3D = leg.pivot
		# Hanging: a little forward, reaching forward when braking; tucked back.
		pivot.rotation.x = lerpf(0.12 + 0.35 * flare, -1.25, tuck)
		(leg.front as Node3D).rotation.x = lerpf(0.1, -1.15, grip)
		(leg.back as Node3D).rotation.x = lerpf(-0.1, 1.0, grip)


# --- Building ---------------------------------------------------------------------

func _build() -> void:
	var core := Builder.new()
	# The body: a plump chest tapering to the tail and the neck.
	core.loft([
		[0.78, 0.02, 0.03, 0.03, 0.03, DARK], [0.55, 0.02, 0.12, 0.1, 0.11, DARK],
		[0.25, 0.04, 0.21, 0.17, 0.18, BROWN], [-0.05, 0.06, 0.26, 0.21, 0.22, BROWN],
		[-0.3, 0.09, 0.23, 0.2, 0.2, CREAM], [-0.5, 0.15, 0.15, 0.14, 0.14, WHITE],
		[-0.62, 0.2, 0.12, 0.12, 0.12, WHITE]], 12)
	# The head, the eyes under a hooded brow, and the hooked beak.
	var head := Builder.new()
	head.ball(Vector3(0, 0.24, -0.72), Vector3(0.15, 0.15, 0.17), WHITE, 12, 7)
	for side in [-1.0, 1.0]:
		head.ball(Vector3(side * 0.118, 0.265, -0.78), Vector3(0.045, 0.045, 0.045), YELLOW, 8, 5)
		head.ball(Vector3(side * 0.148, 0.262, -0.8), Vector3(0.02, 0.025, 0.025), CLAW, 6, 4)
		head.ball(Vector3(side * 0.108, 0.318, -0.775), Vector3(0.062, 0.026, 0.075), CREAM, 8, 4)
	head.loft([
		[-0.82, 0.205, 0.065, 0.08, 0.06, YELLOW], [-0.92, 0.2, 0.058, 0.075, 0.04, YELLOW],
		[-1.0, 0.185, 0.045, 0.06, 0.03, YELLOW], [-1.07, 0.15, 0.03, 0.045, 0.02, YELLOW],
		[-1.1, 0.105, 0.015, 0.025, 0.01, CLAW], [-1.105, 0.075, 0.004, 0.008, 0.004, CLAW]], 8)
	# The core is the body, the tail root and the shoulders' feathered cover.
	for side in [-1.0, 1.0]:
		core.ball(Vector3(side * 0.18, 0.16, -0.05), Vector3(0.14, 0.09, 0.3), DARK, 8, 5)
	_add_mesh(self, core.mesh(), Vector3.ZERO)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.2, -0.55)
	add_child(_head)
	_add_mesh(_head, head.mesh(), Vector3(0, -0.2, 0.55))
	# The tail, a fan of white feathers with scalloped tips.
	_tail = Node3D.new()
	_tail.position = TAIL_AT
	add_child(_tail)
	_add_mesh(_tail, _tail_mesh(), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		_build_wing(side)
		_build_leg(side)


func _build_wing(side: float) -> void:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(SHOULDER.x * side, SHOULDER.y, SHOULDER.z)
	add_child(shoulder)
	_add_mesh(shoulder, _arm_mesh(side), Vector3.ZERO)
	var wrist := Node3D.new()
	wrist.position = Vector3(ARM * side, 0.0, 0.0)
	shoulder.add_child(wrist)
	_add_mesh(wrist, _hand_mesh(side), Vector3.ZERO)
	_wings.append({"side": side, "shoulder": shoulder, "wrist": wrist})


## The broad inner wing as a strip: the leading edge, the line where the
## coverts end, and the trailing edge with a scallop for each flight feather.
static func _arm_mesh(side: float) -> Mesh:
	var b := Builder.new()
	var feathers := 7
	var cols := feathers * 2 + 1
	var lead := []
	var cover := []
	var trail := []
	for i in cols:
		var u := float(i) / float(cols - 1)
		var x := ARM * u * side
		var notch := i % 2 == 1
		var z_lead := -0.3 + 0.07 * u
		var z_cover := z_lead + 0.36 - 0.06 * u
		# The trailing edge is fullest near the body and tapers to the wrist.
		var z_trail := 0.56 - 0.2 * u * u - (0.085 if notch else 0.0)
		lead.append(b.v(Vector3(x, 0.025, z_lead), DARK))
		cover.append(b.v(Vector3(x, 0.015, z_cover), BROWN))
		trail.append(b.v(Vector3(x, -0.03, z_trail), TIP.lerp(LIGHT, 0.55) if notch else LIGHT))
	for i in cols - 1:
		b.quad(lead[i], lead[i + 1], cover[i + 1], cover[i])
		b.quad(cover[i], cover[i + 1], trail[i + 1], trail[i])
	return b.mesh()


## The hand: six finger feathers fanned out from the wrist, long slotted tips
## curving up, dark at the end. Built for the right wing (side 1), mirrored.
static func _hand_mesh(side: float) -> Mesh:
	var b := Builder.new()
	var lengths := [1.02, 1.16, 1.14, 1.02, 0.86, 0.68]
	for i in 6:
		var f := float(i) / 5.0
		var angle := lerpf(-0.1, 0.62, f)
		var dir := Vector3(cos(angle) * side, 0.0, sin(angle))
		var across := Vector3(-dir.z, 0.0, dir.x) * 0.5
		var root := Vector3(-0.06 * side, 0.0, -0.22 + 0.12 * i) - dir * 0.06
		var length: float = lengths[i]
		var width := 0.2
		var stations := [[0.0, 1.0, BROWN], [0.5, 0.97, DARK], [0.88, 0.78, TIP]]
		var verts := []
		for st: Array in stations:
			var s: float = st[0]
			var centre := root + dir * (length * s) + Vector3(0, 0.15 * s * s * length, 0)
			var half := across * (width * float(st[1]))
			verts.append([b.v(centre - half, st[2]), b.v(centre + half, st[2])])
		var tip := b.v(root + dir * length + Vector3(0, 0.15 * length, 0), TIP)
		for k in verts.size() - 1:
			b.quad(verts[k][0], verts[k][1], verts[k + 1][1], verts[k + 1][0])
		b.tri(verts[2][0], verts[2][1], tip)
	return b.mesh()


static func _tail_mesh() -> Mesh:
	var b := Builder.new()
	var cols := 13
	var length := 0.9
	var root := []
	var mid := []
	var tip := []
	for i in cols:
		var u := float(i) / float(cols - 1) * 2.0 - 1.0
		var notch := i % 2 == 1
		root.append(b.v(Vector3(u * 0.14, 0.0, 0.0), CREAM))
		mid.append(b.v(Vector3(u * 0.28, -0.015, length * 0.5), WHITE))
		tip.append(b.v(Vector3(u * 0.42, -0.04, length - (0.09 if notch else 0.0) - 0.1 * u * u), WHITE))
	for i in cols - 1:
		b.quad(root[i], root[i + 1], mid[i + 1], mid[i])
		b.quad(mid[i], mid[i + 1], tip[i + 1], tip[i])
	return b.mesh()


## A leg: the feathered "trousers", the yellow shank and a foot with its
## toes, three forward and one back, each ending in a dark claw.
func _build_leg(side: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(HIP.x * side, HIP.y, HIP.z)
	add_child(pivot)
	var down := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	var b := Builder.new()
	b.loft([[0.0, 0.0, 0.1, 0.1, 0.1, BROWN], [0.1, 0.0, 0.12, 0.12, 0.12, BROWN],
			[0.26, 0.0, 0.085, 0.085, 0.085, LIGHT], [0.32, 0.0, 0.05, 0.05, 0.05, YELLOW],
			[0.48, 0.0, 0.04, 0.04, 0.04, YELLOW]], 8, down)
	_add_mesh(pivot, b.mesh(), Vector3.ZERO)
	var front := Node3D.new()
	front.position = Vector3(0, -0.48, 0)
	pivot.add_child(front)
	var back := Node3D.new()
	back.position = Vector3(0, -0.48, 0)
	pivot.add_child(back)
	var toes := Builder.new()
	for yaw in [-0.38, 0.0, 0.38]:
		_toe(toes, yaw, 1.0)
	_add_mesh(front, toes.mesh(), Vector3.ZERO)
	var heel := Builder.new()
	_toe(heel, 0.0, -1.0, 0.7)
	_add_mesh(back, heel.mesh(), Vector3.ZERO)
	_legs.append({"pivot": pivot, "front": front, "back": back})


## One toe from the foot: forward (dir 1, towards -Z) or back, fanned by
## `yaw`, thick at the foot, then a curved dark claw.
static func _toe(b: Builder, yaw: float, dir: float, scale := 1.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw + (PI if dir > 0.0 else 0.0)), Vector3.ZERO)
	var long := 0.26 * scale
	b.loft([[0.0, 0.0, 0.035, 0.03, 0.025, YELLOW], [long * 0.5, 0.0, 0.03, 0.026, 0.022, YELLOW],
			[long, -0.005, 0.022, 0.02, 0.018, YELLOW], [long + 0.07, -0.04, 0.014, 0.014, 0.012, CLAW],
			[long + 0.1, -0.09, 0.003, 0.004, 0.003, CLAW]], 6, xf)


static func _add_mesh(parent: Node3D, mesh: Mesh, at: Vector3) -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.9
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _material
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)


## Collects triangles with a colour per vertex and turns them into a mesh.
class Builder:
	var pts: Array[Vector3] = []
	var cols: Array[Color] = []
	var idx: Array[int] = []

	func v(p: Vector3, c: Color) -> int:
		pts.append(p)
		cols.append(c)
		return pts.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		idx.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	## A tube along Z through rings [z, centre y, half width, height above,
	## height below, colour], closed at both ends; `xf` moves it into place.
	func loft(rings: Array, seg: int, xf := Transform3D.IDENTITY) -> void:
		var first := pts.size()
		for r: Array in rings:
			for k in seg:
				var a := TAU * k / seg
				var s := sin(a)
				var y: float = r[1] + (float(r[3]) if s > 0.0 else float(r[4])) * s
				v(xf * Vector3(float(r[2]) * cos(a), y, r[0]), r[5])
		for r in rings.size() - 1:
			for k in seg:
				var i0 := first + r * seg + k
				var i1 := first + r * seg + (k + 1) % seg
				tri(i0, i0 + seg, i1 + seg)
				tri(i0, i1 + seg, i1)
		for end in [0, rings.size() - 1]:
			var ring: Array = rings[end]
			var c := v(xf * Vector3(0, ring[1], ring[0]), ring[5])
			for k in seg:
				tri(c, first + end * seg + k, first + end * seg + (k + 1) % seg)

	func ball(at: Vector3, radius: Vector3, col: Color, around: int, rows: int) -> void:
		var first := pts.size()
		for i in rows + 1:
			var th := PI * i / rows
			for k in around:
				var ph := TAU * k / around
				v(at + Vector3(radius.x * sin(th) * cos(ph), radius.y * cos(th), radius.z * sin(th) * sin(ph)), col)
		for i in rows:
			for k in around:
				var i0 := first + i * around + k
				var i1 := first + i * around + (k + 1) % around
				tri(i0, i1, i0 + around)
				tri(i1, i1 + around, i0 + around)

	func mesh() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in pts.size():
			st.set_color(cols[i])
			st.add_vertex(pts[i])
		for k in idx:
			st.add_index(k)
		st.generate_normals()
		return st.commit()
