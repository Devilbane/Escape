class_name FishingRod
extends Node3D
## The hero's fishing rod, held in the right hand while fishing (see Fishing).
## A cork grip with a brass reel under it, and a cane shaft with dark node
## rings, red thread wraps and little line guides that tapers to a fine tip.
## The shaft is built of joints, so it can bend: it whips through on the
## cast, droops a little at rest and curves down hard when a fish pulls.
##
## The rod lies along its local +Y axis, from the hand (the origin, in the
## middle of the grip) to the tip; local -Z is its underside, where the reel
## and the guides hang. Fishing turns it every frame (see aim).

## How many joints the shaft bends at, and how long each piece is (metres).
const PIECES := 4
const PIECE := 0.48
## How thick the shaft is at the grip and at the tip (radius, metres). Thick
## enough to read from the camera, high above the hero.
const BUTT_RADIUS := 0.034
const TIP_RADIUS := 0.011

const CORK := Color(0.74, 0.55, 0.34)
const CANE := Color(0.82, 0.66, 0.36)
const NODE_RING := Color(0.45, 0.3, 0.15)
const WRAP := Color(0.62, 0.1, 0.08)
const BRASS := Color(0.8, 0.62, 0.28)
const DARK_WOOD := Color(0.28, 0.17, 0.09)

## The joints of the shaft, from the grip out to the tip.
var joints: Array[Node3D] = []
## The very tip, where the line leaves the rod, and the reel's spool.
var tip: Node3D
var reel: Node3D


func _init() -> void:
	name = "FishingRod"
	_build()


## Turns the rod to point `pitch` radians above the ground towards `forward`
## (flat), wherever the hand is, and bends each joint by `bend` radians
## (below 0 bends the tip down, above 0 up).
func aim(forward: Vector3, pitch: float, bend: float) -> void:
	var f := Vector3(forward.x, 0, forward.z)
	f = f.normalized() if f.length() > 0.001 else Vector3.FORWARD
	var along := f * cos(pitch) + Vector3.UP * sin(pitch)
	var side := f.cross(Vector3.UP).normalized()
	var top := side.cross(along).normalized()
	global_basis = Basis(side, along, top)
	for joint in joints:
		joint.rotation = Vector3(bend, 0, 0)


func _build() -> void:
	var cork := _paint(CORK, 0.95)
	var wood := _paint(DARK_WOOD, 0.7)
	var brass := _paint(BRASS, 0.35, 0.8)
	var cane := _paint(CANE, 0.55)
	var ring := _paint(NODE_RING, 0.7)
	var wrap := _paint(WRAP, 0.6)
	# The butt cap, the cork grip with two dark bands, and the reel seat.
	_part(self, _tube(0.044, 0.04, 0.06), wood, Vector3(0, -0.23, 0))
	_part(self, _tube(0.04, 0.042, 0.4), cork, Vector3(0, 0.0, 0))
	for y in [-0.12, 0.1]:
		_part(self, _tube(0.044, 0.044, 0.02), wood, Vector3(0, y, 0))
	_part(self, _tube(0.036, 0.04, 0.1), brass, Vector3(0, 0.25, 0))
	# The reel: a brass spool on its side under the seat, with a crank.
	reel = Node3D.new()
	reel.position = Vector3(0, 0.25, -0.085)
	add_child(reel)
	_part(reel, _tube(0.012, 0.012, 0.05), brass, Vector3(0, 0, 0.035))
	var spool := _part(reel, _tube(0.07, 0.07, 0.05), brass, Vector3.ZERO)
	spool.rotation.z = PI / 2
	var core := _part(reel, _tube(0.05, 0.05, 0.056), _paint(Color(0.92, 0.92, 0.86), 0.8), Vector3.ZERO)
	core.rotation.z = PI / 2
	_part(reel, _tube(0.008, 0.008, 0.07), brass, Vector3(0.06, 0.03, 0)).rotation.z = PI / 2
	_part(reel, _ball(0.018), wood, Vector3(0.095, 0.03, 0))
	# The shaft: tapering pieces of cane, each on its own joint.
	var parent: Node3D = self
	var start := 0.3
	for i in PIECES:
		var joint := Node3D.new()
		joint.position = Vector3(0, start if i == 0 else PIECE, 0)
		parent.add_child(joint)
		joints.append(joint)
		var r0 := lerpf(BUTT_RADIUS, TIP_RADIUS, float(i) / PIECES)
		var r1 := lerpf(BUTT_RADIUS, TIP_RADIUS, float(i + 1) / PIECES)
		_part(joint, _tube(r1, r0, PIECE + 0.01), cane, Vector3(0, PIECE / 2.0, 0))
		# A dark node ring halfway, and a red thread wrap holding a guide.
		_part(joint, _tube(r0 * 1.2, r0 * 1.2, 0.02), ring, Vector3(0, PIECE * 0.5, 0))
		_part(joint, _tube(r1 * 1.4, r1 * 1.4, 0.05), wrap, Vector3(0, PIECE - 0.04, 0))
		_part(joint, _ring(maxf(r1 * 1.3, 0.016)), brass, Vector3(0, PIECE - 0.04, -r1 - 0.03))
		parent = joint
	tip = Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0, PIECE, 0)
	parent.add_child(tip)
	_part(tip, _ball(TIP_RADIUS * 1.4), wrap, Vector3.ZERO)


static func _tube(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return mesh


static func _ball(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


static func _ring(radius: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.6
	mesh.outer_radius = radius
	mesh.rings = 10
	mesh.ring_segments = 4
	return mesh


static func _paint(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
