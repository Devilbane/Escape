class_name Warren
extends RefCounted
## A rabbit warren on a meadow: a burrow in the ground with a huddle of baby rabbits (the "€" of the
## map, see Animal kind "kit") hopping about its mouth. When the hero comes near they dive into the
## burrow and come out again once he is well away. The burrow is only a picture: it blocks nobody.

## How many kits live at one burrow.
const KITS := 5
## How far from the burrow's mouth a kit starts (metres).
const START_RADIUS := 1.1


## The burrow: a ring of loose earth round a dark hole, with a few pebbles.
static func burrow() -> Node3D:
	var root := Node3D.new()
	root.name = "Burrow"
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(0.34, 0.24, 0.15)
	earth.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.015, 0.01)
	dark.roughness = 1.0
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.62
	torus.rings = 16
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = earth
	ring.scale = Vector3(1.0, 0.45, 1.0)
	ring.position.y = 0.04
	root.add_child(ring)
	var hole := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.34
	disc.bottom_radius = 0.34
	disc.height = 0.02
	hole.mesh = disc
	hole.material_override = dark
	hole.position.y = 0.035
	root.add_child(hole)
	var stones := StandardMaterial3D.new()
	stones.albedo_color = Color(0.5, 0.48, 0.44)
	stones.roughness = 1.0
	for at in [Vector3(0.7, 0.0, 0.2), Vector3(-0.55, 0.0, 0.5), Vector3(0.15, 0.0, -0.7)]:
		var pebble := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.09
		ball.height = 0.12
		pebble.mesh = ball
		pebble.material_override = stones
		pebble.position = at + Vector3(0, 0.04, 0)
		root.add_child(pebble)
	return root


## Where kit number `i` of `KITS` starts, round the burrow at `centre`.
static func start_of(centre: Vector3, i: int) -> Vector3:
	var a := TAU * float(i) / float(KITS) + 0.4
	return centre + Vector3(sin(a), 0.0, cos(a)) * START_RADIUS
