class_name Remains
extends RefCounted
## The skeleton a rotted corpse leaves behind (see Corpse): a real skeleton
## laid out along the dead body's own rig as it lies, so it keeps the body's
## size, pose and kind:
##   a skull at the head (a round one with a jaw for people, orcs and yetis;
##   a long one with a snout for beasts), with dark eye sockets and nose,
##   vertebrae down the neck, the back and the tail,
##   a ribcage arched over the chest, with a breastbone,
##   a pelvis where the legs join,
##   and the limbs (arms, legs, wings) as long bones with knobbed joints.
## A spider has no bones: it leaves its empty husk and its legs.
## Everything is one mesh (bone surface and socket surface) in the dirty bone
## look of the floor bones (DungeonLife._bone_material), built once when the
## corpse comes to its end.

## Bones of a rig that are no bones of the body: animation helpers, weapon
## slots, the root at the feet, ears, fingers and the face's helper bones.
const NOT_BONES := ["slot", "root", "ik", "pole", "target", "control", "ctrl", "ear",
	"pinky", "middle", "index", "thumb", "face", "nose", "ff"]
const SOCKET := Color(0.05, 0.04, 0.03)
const HUSK := Color(0.2, 0.15, 0.11)

static var _unit_cyl: CylinderMesh
static var _unit_ball: SphereMesh
static var _unit_box: BoxMesh
static var _socket_mat: StandardMaterial3D
static var _husk_mat: StandardMaterial3D

var _bones := SurfaceTool.new()
var _dark := SurfaceTool.new()
var _dark_used := false
var _bones_used := false


## Reads a rig as it lies: every real bone's spot on the floor (y = 0,
## measured from `at`), its nearest real parent and its name. Empty when
## there is no skeleton.
static func read_rig(skel: Skeleton3D, at: Vector3) -> Dictionary:
	if skel == null:
		return {}
	var pos: Array[Vector3] = []
	var names: Array[String] = []
	var real: Array[bool] = []
	var parent: Array[int] = []
	for i in skel.get_bone_count():
		var p := (skel.global_transform * skel.get_bone_global_pose(i)).origin - at
		pos.append(Vector3(p.x, 0.0, p.z))
		var n := skel.get_bone_name(i).to_lower()
		names.append(n)
		real.append(not NOT_BONES.any(func(w): return n.contains(w)))
	for i in skel.get_bone_count():
		var up := skel.get_bone_parent(i)
		while up >= 0 and not real[up]:
			up = skel.get_bone_parent(up)
		parent.append(up if real[i] else -2)
	var head := -1
	for i in names.size():
		if real[i] and names[i] == "head":
			head = i
	if head < 0:
		return {}
	return {"pos": pos, "name": names, "parent": parent, "head": head}


## The skeleton for `rig` as one MeshInstance3D. `beast` gives a long skull
## with a snout, `husk` a spider's shell instead of bones.
static func build(rig: Dictionary, beast: bool, husk: bool) -> MeshInstance3D:
	var r := Remains.new()
	return r._build(rig, beast, husk)


func _build(rig: Dictionary, beast: bool, husk: bool) -> MeshInstance3D:
	_bones.begin(Mesh.PRIMITIVE_TRIANGLES)
	_dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	_units()
	var pos: Array = rig.pos
	var parent: Array = rig.parent
	var names: Array = rig.name
	var head: int = rig.head
	# The spine: from the head up its parents to the pelvis.
	var spine: Array[int] = []
	var at := head
	while at >= 0:
		spine.push_front(at)
		at = parent[at]
	var pelvis: Vector3 = pos[spine[0]]
	var skull_at: Vector3 = pos[head]
	# A spider's head sits close to its body: its husk goes by its legs.
	var length := maxf(pelvis.distance_to(skull_at), 0.6 if husk else 0.4)
	# Forward along the body, from the pelvis to the head, and to its right.
	var fwd := (skull_at - pelvis).normalized() if pelvis.distance_to(skull_at) > 0.05 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	# The chest: the last spine bone that is neither neck nor head.
	var chest := pelvis
	for i in spine:
		if not names[i].contains("neck") and i != head:
			chest = pos[i]
	if chest.distance_to(pelvis) < length * 0.2:
		chest = pelvis + fwd * length * 0.45
	var thick := length * (0.045 if not beast else 0.035)
	if husk:
		_husk(pelvis, skull_at, fwd, right, length)
	else:
		_vertebrae(spine.map(func(i): return pos[i]), thick)
		_ribcage(chest, pelvis, fwd, right, length, beast)
		_pelvis(pelvis, fwd, right, length, beast)
		_skull(skull_at, fwd, right, length, beast)
	# Limbs and tails: every real bone off the spine, joint to joint.
	var on_spine := {}
	for i in spine:
		on_spine[i] = true
	for i in pos.size():
		var p: int = parent[i]
		if p < 0 or on_spine.has(i):
			continue
		var a: Vector3 = pos[p]
		var b: Vector3 = pos[i]
		var gap := a.distance_to(b)
		if gap < length * 0.06 or gap > length * (6.0 if husk else 2.5):
			continue
		if names[i].contains("tail"):
			_vertebra_run(a, b, thick * 0.8)
		elif names[i].contains("wing"):
			_long_bone(a, b, thick * 0.55)
		elif husk:
			_long_bone(a, b, thick * 0.7, _dark)
		else:
			_long_bone(a, b, thick)
	var mesh := ArrayMesh.new()
	if _bones_used:
		_bones.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, DungeonLife._bone_material())
	if _dark_used:
		_dark.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _husk_mat if husk else _socket_mat)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.name = "Skeleton"
	return inst


static func _units() -> void:
	if _unit_cyl != null:
		return
	_unit_cyl = CylinderMesh.new()
	_unit_cyl.top_radius = 0.5
	_unit_cyl.bottom_radius = 0.5
	_unit_cyl.height = 1.0
	_unit_cyl.radial_segments = 6
	_unit_cyl.rings = 1
	_unit_ball = SphereMesh.new()
	_unit_ball.radius = 0.5
	_unit_ball.height = 1.0
	_unit_ball.radial_segments = 10
	_unit_ball.rings = 6
	_unit_box = BoxMesh.new()
	_socket_mat = StandardMaterial3D.new()
	_socket_mat.albedo_color = SOCKET
	_socket_mat.roughness = 1.0
	_husk_mat = StandardMaterial3D.new()
	_husk_mat.albedo_color = HUSK
	_husk_mat.roughness = 0.7


## Adds `mesh` turned and stretched by `basis`, at `at`.
func _put(tool: SurfaceTool, mesh: PrimitiveMesh, basis: Basis, at: Vector3) -> void:
	if tool == _dark:
		_dark_used = true
	else:
		_bones_used = true
	tool.append_from(mesh, 0, Transform3D(basis, at))


## A rod of `thick` from `a` to `b`.
func _rod(a: Vector3, b: Vector3, thick: float, tool: SurfaceTool = null) -> void:
	var along := b - a
	var gap := along.length()
	if gap < 0.001:
		return
	var y := along / gap
	var side := y.cross(Vector3.UP)
	if side.length() < 0.01:
		side = y.cross(Vector3.RIGHT)
	var x := side.normalized()
	var z := x.cross(y)
	_put(tool if tool else _bones, _unit_cyl, Basis(x * thick, y * gap, z * thick), (a + b) * 0.5)


func _ball(at: Vector3, size: Vector3, basis := Basis(), tool: SurfaceTool = null) -> void:
	_put(tool if tool else _bones, _unit_ball, basis * Basis.from_scale(size), at)


func _box(at: Vector3, size: Vector3, basis := Basis(), tool: SurfaceTool = null) -> void:
	_put(tool if tool else _bones, _unit_box, basis * Basis.from_scale(size), at)


## A long bone lying on the floor: a shaft with a double knob at each end.
func _long_bone(a: Vector3, b: Vector3, thick: float, tool: SurfaceTool = null) -> void:
	var lift := Vector3(0, thick * 0.6, 0)
	_rod(a + lift, b + lift, thick, tool)
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP).normalized() * thick * 0.45
	for end: Vector3 in [a, b]:
		for s: float in [-1.0, 1.0]:
			_ball(end + lift + side * s, Vector3.ONE * thick * 1.25, Basis(), tool)


## Vertebrae along a run of joints (the spine through neck and head).
func _vertebrae(points: Array, thick: float) -> void:
	for i in range(1, points.size()):
		_vertebra_run(points[i - 1], points[i], thick)


func _vertebra_run(a: Vector3, b: Vector3, thick: float) -> void:
	var gap := a.distance_to(b)
	var count := maxi(1, int(gap / (thick * 2.2)))
	var dir := (b - a).normalized()
	var flat := dir.cross(Vector3.UP).normalized()
	var basis := Basis(flat, Vector3.UP, -dir) if flat.length() > 0.01 else Basis()
	for k in count:
		var at := a.lerp(b, (k + 0.5) / count) + Vector3(0, thick * 0.7, 0)
		_box(at, Vector3(thick * 2.0, thick * 1.3, thick * 1.4), basis)
		# The spiny knob on top of each vertebra.
		_ball(at + Vector3(0, thick * 0.7, 0), Vector3(thick, thick * 0.8, thick * 1.1), basis)


## Ribs arched over the chest on both sides, from the spine round to the
## breastbone, the lower ones shorter and open in front.
func _ribcage(chest: Vector3, pelvis: Vector3, fwd: Vector3, right: Vector3, length: float, beast: bool) -> void:
	var count := 8 if beast else 6
	var span := clampf(chest.distance_to(pelvis) * 0.8, length * 0.3, length * 0.6)
	var width := length * (0.2 if beast else 0.26)
	var high := length * (0.24 if beast else 0.22)
	var rib := length * 0.022
	for k in count:
		var t := float(k) / float(count - 1)
		var base := chest - fwd * span * t
		var w := width * (1.0 - 0.25 * t * t) * (0.8 + 0.2 * sin(t * PI))
		# The lower ribs stop short of the breastbone.
		var reach := PI * (0.95 if k < count - 2 else 0.7)
		for s: float in [-1.0, 1.0]:
			var last := base + Vector3(0, rib, 0)
			var steps := 7
			for j in range(1, steps + 1):
				var a := reach * j / steps
				var p := base + right * s * w * sin(a) + Vector3(0, rib + high * (1.0 - cos(a)) * 0.5, 0) - fwd * span * 0.08 * sin(a * 0.5)
				_rod(last, p, rib)
				last = p
	# The breastbone along the top of the cage.
	var top := Vector3(0, rib + high, 0)
	_box(chest - fwd * span * 0.3 + top, Vector3(length * 0.07, rib * 1.4, span * 0.65), Basis(right, Vector3.UP, -fwd))


## The pelvis: two broad wings of bone either side of the base of the spine.
func _pelvis(at: Vector3, fwd: Vector3, right: Vector3, length: float, beast: bool) -> void:
	var w := length * (0.14 if beast else 0.17)
	var basis := Basis(right, Vector3.UP, -fwd)
	for s: float in [-1.0, 1.0]:
		var wing := Basis(Vector3.UP, s * 0.5) * basis
		_ball(at + right * s * w + fwd * length * 0.05 + Vector3(0, length * 0.05, 0), Vector3(length * 0.2, length * 0.07, length * 0.16), wing)
	_box(at + Vector3(0, length * 0.04, 0), Vector3(length * 0.12, length * 0.06, length * 0.12), basis)


## The skull lying face up, crown away from the neck: a round one with a
## jaw, or a beast's with a long snout.
func _skull(at: Vector3, fwd: Vector3, right: Vector3, length: float, beast: bool) -> void:
	var basis := Basis(right, Vector3.UP, -fwd)
	if beast:
		var r := length * 0.17
		var crown := at + Vector3(0, r * 0.75, 0)
		_ball(crown, Vector3(r * 1.7, r * 1.4, r * 1.6), basis)
		# The snout runs on, away from the neck.
		var snout := crown + fwd * r * 1.5 - Vector3(0, r * 0.2, 0)
		_box(snout, Vector3(r * 0.9, r * 0.7, r * 1.8), basis)
		_ball(snout + fwd * r * 0.85, Vector3(r * 0.9, r * 0.7, r * 0.6), basis)
		# The lower jaw, a little open, beside the snout.
		_rod(crown - right * r * 0.4 - Vector3(0, r * 0.4, 0), snout + fwd * r * 0.8 - right * r * 0.35 - Vector3(0, r * 0.45, 0), r * 0.18)
		_rod(crown + right * r * 0.4 - Vector3(0, r * 0.4, 0), snout + fwd * r * 0.8 + right * r * 0.35 - Vector3(0, r * 0.45, 0), r * 0.18)
		for s: float in [-1.0, 1.0]:
			_ball(crown + right * s * r * 0.5 + fwd * r * 0.45 + Vector3(0, r * 0.55, 0), Vector3(r * 0.5, r * 0.3, r * 0.55), basis, _dark)
		_ball(snout + fwd * r * 1.05 + Vector3(0, r * 0.3, 0), Vector3(r * 0.35, r * 0.2, r * 0.25), basis, _dark)
		return
	var r := length * 0.3
	# Lying on its back: the face looks up, the crown points away.
	var crown := at + fwd * r * 0.35 + Vector3(0, r * 0.78, 0)
	_ball(crown, Vector3(r * 1.8, r * 1.55, r * 2.0), basis)
	# Cheekbones and upper teeth towards the neck, and the jaw below them.
	var face := crown - fwd * r * 0.75 + Vector3(0, r * 0.25, 0)
	_box(face, Vector3(r * 1.2, r * 0.7, r * 0.55), basis)
	var jaw := crown - fwd * r * 1.05 - Vector3(0, r * 0.25, 0)
	_box(jaw, Vector3(r * 1.0, r * 0.35, r * 0.45), basis)
	for s: float in [-1.0, 1.0]:
		_rod(jaw + right * s * r * 0.48, crown + right * s * r * 0.75 - fwd * r * 0.25 - Vector3(0, r * 0.2, 0), r * 0.18)
	# Teeth: a row of little knobs where face meets jaw.
	for k in 6:
		var x := (k - 2.5) / 2.5 * r * 0.45
		_ball(face - fwd * r * 0.3 + right * x + Vector3(0, -r * 0.05, 0), Vector3.ONE * r * 0.14)
	# Dark eye sockets and the nose hole, on the face looking up.
	for s: float in [-1.0, 1.0]:
		_ball(crown + right * s * r * 0.4 - fwd * r * 0.3 + Vector3(0, r * 0.62, 0), Vector3(r * 0.55, r * 0.35, r * 0.5), basis, _dark)
	_ball(crown - fwd * r * 0.68 + Vector3(0, r * 0.55, 0), Vector3(r * 0.22, r * 0.2, r * 0.3), basis, _dark)


## A spider's empty shell: the cracked back of its body and its head.
func _husk(body: Vector3, head: Vector3, fwd: Vector3, right: Vector3, length: float) -> void:
	var basis := Basis(right, Vector3.UP, -fwd)
	_ball(body - fwd * length * 0.6 + Vector3(0, length * 0.2, 0), Vector3(length * 1.0, length * 0.45, length * 1.2), basis, _dark)
	_ball(body + Vector3(0, length * 0.12, 0), Vector3(length * 0.6, length * 0.3, length * 0.6), basis, _dark)
	_ball(head + Vector3(0, length * 0.1, 0), Vector3(length * 0.4, length * 0.25, length * 0.35), basis, _dark)
