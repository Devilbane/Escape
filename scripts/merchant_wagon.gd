class_name MerchantWagon
extends RefCounted
## Zarek's home on wheels: a barrel-topped living wagon he rolls into the
## village on his nights (see Wanderer, Outdoor._build_cart). It is a lived-in
## caravan, not a market cart: a plank body that flares out above the
## wheels under a curved roof with a raised skylight strip, a stovepipe that
## smokes, a stable door on the front porch with turned balusters and steps
## down between the shafts, glowing windows with violet shutters, and a rack
## at the back with his crates.
##
## It is handmade and well travelled: the boards differ a little in shade,
## the corners carry turned posts, the joints iron corner plates with rivets,
## the wheels red spokes with iron tyres and brass hub caps. And all sorts of
## things hang off it: copper pots, a pan and a ladle, herbs drying under the
## eaves, a string of garlic, a coil of rope, a bucket, a tin bath, a
## lantern on an iron crane by the merchant.
##
## Everything is built from simple shapes, merged into one mesh per
## material (a dozen or so draws for the whole wagon).
##
## His donkey pulls it (see MerchantDonkey): while the wagon is parked she
## rests in front of the shafts, unharnessed, nibbling at a heap of hay, with
## her collar hung on a shaft tip, a bucket of water beside her and a
## lantern on her tethering stake.
##
## Local frame: the origin is the centre of the cart's cell on the ground,
## +x the back (east, where Zarek stands), -x the front with the porch and
## the shafts, +z the side that faces the way up to him.

## The cells it stands on, from the cart's cell: its own, the one in front
## and the donkey's, in front of that.
const CELLS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-2, 0)]
## Its solid parts (centre, size): the body with its wheels and rack, the
## porch with the steps and the shafts lying on the ground, and the donkey
## with her hay.
const SOLIDS := [[Vector3(-0.85, 1.25, 0), Vector3(4.8, 2.5, 2.5)], [Vector3(-4.3, 0.5, 0), Vector3(2.0, 1.0, 1.5)],
		[Vector3(-7.4, 0.7, 0.4), Vector3(2.8, 1.4, 1.3)]]
## Where the donkey stands (local) and which way she faces (yaw; 0 faces +z):
## past the shaft tips, her head turned away from the wagon and down to the hay.
const DONKEY_AT := Vector3(-7.0, 0, 0.3)
const DONKEY_YAW := -PI * 0.5 + 0.3
const HAY_AT := Vector3(-8.45, 0, 0.8)
const STAKE_AT := Vector3(-6.2, 0, 1.75)

## The body: front and back wall, floor and top rail, and its half width at
## the floor and at the top (the sides flare out like a Reading wagon's).
const FRONT := -2.9
const BACK := 1.1
const FLOOR := 1.25
const TOP := 2.75
const HALF_LOW := 0.86
const HALF_TOP := 1.02
## The barrel roof: an arc of radius ROOF_R round ROOF_Y, from FRONT_EAVE to
## BACK_EAVE (it shelters the porch and the rack).
const ROOF_R := 1.27
const ROOF_Y := 2.13
const FRONT_EAVE := -3.65
const BACK_EAVE := 1.55
## The wheels: centre x, radius and how far out (z) they run.
const REAR_WHEEL := [0.35, 0.8, 1.14]
const FRONT_WHEEL := [-2.25, 0.58, 1.0]

## What each part is made of: colour, roughness, metallic, glow.
const MATS := {
	"wood_a": [Color(0.42, 0.28, 0.17), 0.9, 0.0, 0.0],
	"wood_b": [Color(0.36, 0.23, 0.14), 0.9, 0.0, 0.0],
	"wood_c": [Color(0.47, 0.32, 0.2), 0.88, 0.0, 0.0],
	"roof": [Color(0.24, 0.17, 0.12), 0.95, 0.0, 0.0],
	"turned": [Color(0.3, 0.18, 0.1), 0.55, 0.0, 0.0],
	"green": [Color(0.15, 0.28, 0.2), 0.75, 0.0, 0.0],
	"ochre": [Color(0.78, 0.56, 0.22), 0.6, 0.0, 0.0],
	"red": [Color(0.5, 0.14, 0.1), 0.7, 0.0, 0.0],
	"violet": [Color(0.42, 0.25, 0.55), 0.85, 0.0, 0.0],
	"iron": [Color(0.16, 0.16, 0.17), 0.55, 0.6, 0.0],
	"brass": [Color(0.78, 0.6, 0.28), 0.35, 0.8, 0.0],
	"copper": [Color(0.72, 0.38, 0.22), 0.4, 0.75, 0.0],
	"tin": [Color(0.6, 0.6, 0.62), 0.45, 0.7, 0.0],
	"glow": [Color(1.0, 0.76, 0.46), 0.5, 0.0, 3.0],
	"herb": [Color(0.34, 0.42, 0.2), 1.0, 0.0, 0.0],
	"herb_dry": [Color(0.55, 0.5, 0.26), 1.0, 0.0, 0.0],
	"lavender": [Color(0.5, 0.42, 0.66), 1.0, 0.0, 0.0],
	"garlic": [Color(0.88, 0.84, 0.74), 0.8, 0.0, 0.0],
	"chilli": [Color(0.62, 0.12, 0.08), 0.6, 0.0, 0.0],
	"rope": [Color(0.62, 0.5, 0.32), 1.0, 0.0, 0.0],
	"cloth": [Color(0.5, 0.2, 0.18), 1.0, 0.0, 0.0],
	"wicker": [Color(0.6, 0.46, 0.26), 0.95, 0.0, 0.0],
	"leaf": [Color(0.22, 0.4, 0.18), 0.9, 0.0, 0.0],
	"flower": [Color(0.85, 0.3, 0.3), 0.8, 0.0, 0.0],
	"leather": [Color(0.3, 0.17, 0.1), 0.7, 0.0, 0.0],
	"hay": [Color(0.74, 0.62, 0.32), 1.0, 0.0, 0.0],
}
const WOODS := ["wood_a", "wood_b", "wood_c"]
## The sides of a turned part.
const SIDES := 10

var _tools := {}
var _rng: RandomNumberGenerator
## Where the familiar can sit (local), filled in while building.
var perches: Array[Vector3] = []


## Builds the wagon: a Node3D with its meshes, its lights and its smoke (lit by
## kindle once it is in the level), and the spots the familiar likes in its
## meta "perches".
static func build(rng: RandomNumberGenerator) -> Node3D:
	var kit := MerchantWagon.new()
	kit._rng = rng
	var root := Node3D.new()
	root.name = "MerchantWagon"
	kit._undercarriage()
	kit._body()
	kit._roof()
	kit._porch()
	kit._rack()
	kit._hangings()
	kit._donkey_corner()
	kit._commit(root)
	kit._lights(root)
	var donkey := MerchantDonkey.new()
	donkey.name = "MerchantDonkey"
	donkey.position = DONKEY_AT
	donkey.rotation.y = DONKEY_YAW
	root.add_child(donkey)
	root.set_meta("perches", kit.perches)
	return root


# --- Building blocks -------------------------------------------------------------

func _tool(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


## Turned parts (plain meshes with normals only) go into a mesh of their own
## beside the primitives of the same material: mixed in one, they vanish.
func _add(key: String, mesh: Mesh, at: Transform3D) -> void:
	_tool(key + ("#turned" if mesh is ArrayMesh else "")).append_from(mesh, 0, at)


func _wood() -> String:
	return WOODS[_rng.randi() % WOODS.size()]


func _box(key: String, size: Vector3, at: Vector3, basis := Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(key, mesh, Transform3D(basis, at))


## A round rod along the y axis, turned by `basis`.
func _rod(key: String, length: float, radius: float, at: Vector3, basis := Basis.IDENTITY, sides := 8) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = sides
	mesh.rings = 1
	_add(key, mesh, Transform3D(basis, at))


## A rod from `a` to `b`.
func _rod_between(key: String, a: Vector3, b: Vector3, radius: float, sides := 6) -> void:
	var dir := b - a
	var up := dir.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up))
	_rod(key, dir.length(), radius, (a + b) * 0.5, basis, sides)


func _ball(key: String, radius: float, at: Vector3, squash := Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	_add(key, mesh, Transform3D(Basis.from_scale(squash), at))


## A ring of `radius` (to the middle of its tube) and tube `thick`, lying flat
## (in the xz plane) unless turned by `basis`.
func _ring(key: String, radius: float, thick: float, at: Vector3, basis := Basis.IDENTITY, sides := 20) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thick
	mesh.outer_radius = radius + thick
	mesh.rings = sides
	mesh.ring_segments = 6
	_add(key, mesh, Transform3D(basis, at))


## A turned part: `profile` (radius, height) spun round the y axis.
func _lathe(key: String, profile: Array, at: Transform3D, sides := SIDES) -> void:
	_add(key, MerchantWagon.lathe(profile, sides), at)


static func lathe(profile: Array, sides := SIDES) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	var normals: Array[Vector2] = []
	for i in n:
		var a: Vector2 = profile[maxi(i - 1, 0)]
		var b: Vector2 = profile[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		normals.append(Vector2(t.y, -t.x))
	for i in n - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		if p0 == p1:
			continue
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			for v in [[p0, normals[i], a0], [p1, normals[i + 1], a0], [p1, normals[i + 1], a1],
					[p0, normals[i], a0], [p1, normals[i + 1], a1], [p0, normals[i], a1]]:
				var pt: Vector2 = v[0]
				var nm: Vector2 = v[1]
				var ang: float = v[2]
				var dir := Vector3(sin(ang), 0, cos(ang))
				st.set_normal((dir * nm.x + Vector3(0, nm.y, 0)).normalized())
				st.add_vertex(dir * pt.x + Vector3(0, pt.y, 0))
	return st.commit()


## A turned spindle `height` tall and about `radius` thick: foot, bead, a
## vase swelling, a cove, a bead and a cap.
static func spindle(height: float, radius: float) -> Array:
	var out := []
	for p in [[0, 0], [1.0, 0], [1.0, 0.06], [0.7, 0.08], [0.7, 0.12], [1.15, 0.16], [0.7, 0.2], [0.55, 0.3],
			[0.85, 0.44], [1.0, 0.52], [0.85, 0.6], [0.55, 0.7], [0.6, 0.8], [1.15, 0.84], [0.7, 0.88],
			[0.7, 0.92], [1.0, 0.94], [1.0, 1.0], [0, 1.0]]:
		out.append(Vector2(p[0] * radius, p[1] * height))
	return out


## The roof's height over the arc at `z` (never below the top rail).
static func roof_at(z: float) -> float:
	return maxf(ROOF_Y + sqrt(maxf(ROOF_R * ROOF_R - z * z, 0.0)), TOP)


## The side's outward lean: its half width at height `y`.
static func half_at(y: float) -> float:
	return lerpf(HALF_LOW, HALF_TOP, clampf((y - FLOOR) / (TOP - FLOOR), 0.0, 1.0))


func _commit(root: Node3D) -> void:
	for key: String in _tools:
		var mi := MeshInstance3D.new()
		mi.name = key.replace("#", "_")
		mi.mesh = (_tools[key] as SurfaceTool).commit()
		var spec: Array = MATS[key.get_slice("#", 0)]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = spec[0]
		mat.roughness = spec[1]
		mat.metallic = spec[2]
		if spec[3] > 0.0:
			mat.emission_enabled = true
			mat.emission = spec[0]
			mat.emission_energy_multiplier = spec[3]
		mi.material_override = mat
		root.add_child(mi)


# --- The parts -------------------------------------------------------------------

## Chassis beams, the axles, the front turntable, the four wheels, the shafts
## and the pan box slung under the floor.
func _undercarriage() -> void:
	for z: float in [-0.6, 0.6]:
		_box("wood_b", Vector3(BACK - FRONT + 0.2, 0.16, 0.14), Vector3((FRONT + BACK) * 0.5, FLOOR - 0.1, z))
	var rx: float = REAR_WHEEL[0]
	var fx: float = FRONT_WHEEL[0]
	_rod("iron", REAR_WHEEL[2] * 2.0 + 0.1, 0.05, Vector3(rx, REAR_WHEEL[1], 0), Basis(Vector3.RIGHT, PI * 0.5))
	_rod("iron", FRONT_WHEEL[2] * 2.0 + 0.1, 0.045, Vector3(fx, FRONT_WHEEL[1], 0), Basis(Vector3.RIGHT, PI * 0.5))
	# Springs and blocks from the axles up to the beams.
	for z: float in [-0.6, 0.6]:
		_box("wood_a", Vector3(0.22, REAR_WHEEL[1] * 0 + FLOOR - 0.18 - REAR_WHEEL[1], 0.16), Vector3(rx, (FLOOR - 0.18 + REAR_WHEEL[1]) * 0.5, z))
		_box("iron", Vector3(0.9, 0.05, 0.08), Vector3(rx, REAR_WHEEL[1] + 0.06, z))
	_rod("iron", 0.06, 0.48, Vector3(fx, FLOOR - 0.22, 0), Basis.IDENTITY, 16)
	_box("wood_b", Vector3(0.24, FLOOR - 0.25 - FRONT_WHEEL[1], 1.4), Vector3(fx, (FLOOR - 0.25 + FRONT_WHEEL[1]) * 0.5, 0))
	for side: float in [-1.0, 1.0]:
		_wheel(Vector3(rx, REAR_WHEEL[1], side * REAR_WHEEL[2]), REAR_WHEEL[1], side)
		_wheel(Vector3(fx, FRONT_WHEEL[1], side * FRONT_WHEEL[2]), FRONT_WHEEL[1], side)
	# The shafts, resting on the ground in front, with a cross bar and iron tips.
	var root_x := fx - 0.2
	for side: float in [-1.0, 1.0]:
		var a := Vector3(root_x, FRONT_WHEEL[1] + 0.05, side * 0.58)
		var b := Vector3(FRONT - 2.55, 0.07, side * 0.66)
		_rod_between("wood_c", a, b, 0.055)
		_rod_between("iron", b.lerp(a, 0.04), b - (a - b).normalized() * 0.08, 0.065)
	_rod_between("wood_b", Vector3(root_x - 0.9, 0.62, -0.62), Vector3(root_x - 0.9, 0.62, 0.62), 0.045)
	# The pan box between the axles, with iron corners and a hasp.
	var px := -1.0
	_box("wood_a", Vector3(1.1, 0.42, 1.2), Vector3(px, FLOOR - 0.38, 0))
	for cx: float in [px - 0.55, px + 0.55]:
		for cz: float in [-0.6, 0.6]:
			_box("iron", Vector3(0.06, 0.44, 0.06), Vector3(cx, FLOOR - 0.38, cz))
	_box("iron", Vector3(0.1, 0.16, 0.02), Vector3(px, FLOOR - 0.3, 0.61))


## One wheel round `at`, its hub on the z axis: a turned hub with a brass cap,
## twelve red spokes, a red felloe and an iron tyre.
func _wheel(at: Vector3, radius: float, side: float) -> void:
	var lie := Basis(Vector3.RIGHT, PI * 0.5)
	_lathe("turned", [Vector2(0, -0.15), Vector2(0.07, -0.15), Vector2(0.1, -0.09), Vector2(0.115, 0.0),
			Vector2(0.1, 0.08), Vector2(0.075, 0.13), Vector2(0.08, 0.15), Vector2(0, 0.15)], Transform3D(lie, at))
	_ball("brass", 0.06, at + Vector3(0, 0, side * 0.16), Vector3(1, 1, 0.6))
	_ring("iron", 0.085, 0.012, at + Vector3(0, 0, side * 0.12), lie, 12)
	var spokes := 12 if radius > 0.7 else 10
	for i in spokes:
		var ang := TAU * i / spokes
		var dir := Vector3(-sin(ang), cos(ang), 0)
		_rod_between("red", at + dir * 0.09, at + dir * (radius - 0.07), 0.024, 5)
	_ring("red", radius - 0.065, 0.04, at, lie, 24)
	_ring("iron", radius - 0.015, 0.022, at, lie, 24)


## The walls: vertical boards in three shades between a green bottom and top
## rail, turned corner posts, iron corner plates, a window with violet shutters
## on each side, the back window, and the green ends shaped to the roof.
func _body() -> void:
	var tilt := atan((HALF_TOP - HALF_LOW) / (TOP - FLOOR))
	var height := TOP - FLOOR
	var mid_y := (FLOOR + TOP) * 0.5
	var mid_z := (HALF_LOW + HALF_TOP) * 0.5
	# The floor.
	_box("wood_b", Vector3(BACK - FRONT, 0.08, HALF_LOW * 2.0), Vector3((FRONT + BACK) * 0.5, FLOOR, 0))
	var board := 0.2
	var count := int((BACK - FRONT) / board)
	for side: float in [-1.0, 1.0]:
		var lean := Basis(Vector3.RIGHT, side * tilt)
		for i in count:
			var x := FRONT + board * (i + 0.5)
			_box(_wood(), Vector3(board - 0.012, height, 0.05), Vector3(x, mid_y, side * mid_z), lean)
		# The rails and the moulding under the eave.
		_box("green", Vector3(BACK - FRONT + 0.08, 0.14, 0.09), Vector3((FRONT + BACK) * 0.5, FLOOR + 0.07, side * (HALF_LOW + 0.02)), lean)
		_box("green", Vector3(BACK - FRONT + 0.08, 0.12, 0.09), Vector3((FRONT + BACK) * 0.5, TOP - 0.06, side * (HALF_TOP + 0.02)), lean)
		_box("ochre", Vector3(BACK - FRONT + 0.1, 0.035, 0.05), Vector3((FRONT + BACK) * 0.5, TOP - 0.14, side * (HALF_TOP + 0.05)), lean)
		_box("ochre", Vector3(BACK - FRONT + 0.1, 0.035, 0.05), Vector3((FRONT + BACK) * 0.5, FLOOR + 0.16, side * (HALF_LOW + 0.05)), lean)
		# Turned corner posts, leaning with the sides, and iron plates at the corners.
		for x: float in [FRONT, BACK]:
			var foot := Vector3(x, FLOOR, side * (HALF_LOW + 0.03))
			_lathe("ochre", MerchantWagon.spindle(height, 0.06), Transform3D(lean, foot))
			for y: float in [FLOOR + 0.25, TOP - 0.3]:
				var out := side * (MerchantWagon.half_at(y) + 0.06)
				var inward := -0.16 if x == BACK else 0.16
				_box("iron", Vector3(0.3, 0.07, 0.015), Vector3(x + inward, y, out), lean)
				_box("iron", Vector3(0.015, 0.07, 0.24), Vector3(x + (0.03 if x == BACK else -0.03), y, side * (MerchantWagon.half_at(y) - 0.08)))
				for r: float in [0.06, 0.2]:
					_ball("iron", 0.018, Vector3(x + inward * r / 0.16 * 0.9, y, out + side * 0.01))
		# Carved brackets under the eave between the posts.
		for x: float in [FRONT + 0.9, -0.9, BACK - 0.9]:
			_bracket(Vector3(x, TOP - 0.2, side * (HALF_TOP + 0.06)), side)
		_side_window(Vector3(-0.9, 2.05, side * (MerchantWagon.half_at(2.05) + 0.03)), side, lean)
	# The ends: boards up to the roof's arc, a green frame round the edge.
	for x: float in [FRONT, BACK]:
		var n := int(HALF_TOP * 2.0 / 0.17)
		for i in n:
			var z := -HALF_TOP + 0.17 * (i + 0.5)
			var top := MerchantWagon.roof_at(z) - 0.03
			_box(_wood(), Vector3(0.05, top - FLOOR, 0.158), Vector3(x, (top + FLOOR) * 0.5, z))
		var face := 0.035 if x == BACK else -0.035
		for i in 12:
			var a0 := lerpf(-1.0, 1.0, i / 12.0) * 0.9
			var a1 := lerpf(-1.0, 1.0, (i + 1) / 12.0) * 0.9
			var p0 := Vector3(x + face, ROOF_Y + cos(a0) * (ROOF_R - 0.04), sin(a0) * (ROOF_R - 0.04))
			var p1 := Vector3(x + face, ROOF_Y + cos(a1) * (ROOF_R - 0.04), sin(a1) * (ROOF_R - 0.04))
			_rod_between("green", p0, p1, 0.04, 5)
	# The back window, with a sill and a flower box.
	var back_out := BACK + 0.04
	_box("glow", Vector3(0.02, 0.5, 0.5), Vector3(back_out, 2.15, 0))
	_window_frame(Vector3(back_out + 0.01, 2.15, 0), Vector2(0.5, 0.5), true)
	for s: float in [-1.0, 1.0]:
		_box("violet", Vector3(0.03, 0.56, 0.3), Vector3(back_out + 0.03, 2.15, s * 0.44))
		_box("iron", Vector3(0.015, 0.03, 0.2), Vector3(back_out + 0.05, 2.32, s * 0.38))
		_box("iron", Vector3(0.015, 0.03, 0.2), Vector3(back_out + 0.05, 1.98, s * 0.38))


## A carved bracket: an ochre scroll of three steps, under the eave.
func _bracket(at: Vector3, side: float) -> void:
	for i in 3:
		var w := 0.06 + i * 0.05
		_box("ochre", Vector3(0.05, 0.06, w), at + Vector3(0, -0.16 + i * 0.06, -side * w * 0.5 + side * 0.04))
	_ball("ochre", 0.035, at + Vector3(0, -0.21, side * 0.03))


## A side window at `at`: a glowing pane in a cross of glazing bars, an ochre
## frame, shutters folded open in violet with iron hinge straps, and a box of
## flowers under it.
func _side_window(at: Vector3, side: float, lean: Basis) -> void:
	var size := Vector2(0.6, 0.55)
	_box("glow", Vector3(size.x, size.y, 0.02), at, lean)
	_window_frame(at + Vector3(0, 0, side * 0.012), size, false, lean)
	for s: float in [-1.0, 1.0]:
		var c := at + Vector3(s * (size.x * 0.5 + 0.2), 0, side * 0.03)
		_box("violet", Vector3(0.34, size.y + 0.06, 0.03), c, lean)
		_box("ochre", Vector3(0.22, size.y - 0.14, 0.01), c + Vector3(0, 0, side * 0.018), lean)
		for dy: float in [-0.18, 0.18]:
			_box("iron", Vector3(0.26, 0.03, 0.012), c + Vector3(-s * 0.04, dy, side * 0.02), lean)
	# The flower box.
	var box_at := at + Vector3(0, -size.y * 0.5 - 0.1, side * 0.1)
	_box("green", Vector3(size.x + 0.15, 0.14, 0.16), box_at)
	for i in 6:
		var x := -0.3 + i * 0.12 + _rng.randf_range(-0.02, 0.02)
		var top := box_at + Vector3(x, 0.1 + _rng.randf_range(0.0, 0.05), 0)
		_ball("leaf", 0.06, top, Vector3(1, 0.8, 1))
		if i % 2 == 0:
			_ball("flower", 0.03, top + Vector3(0.02, 0.05, side * 0.03))


func _window_frame(at: Vector3, size: Vector2, across_x: bool, lean := Basis.IDENTITY) -> void:
	var t := 0.05
	var d := 0.03
	if across_x:
		_box("ochre", Vector3(d, t, size.y + t * 2), at + Vector3(0, size.x * 0.5 + t * 0.5, 0))
		_box("ochre", Vector3(d, t, size.y + t * 2), at + Vector3(0, -size.x * 0.5 - t * 0.5, 0))
		_box("ochre", Vector3(d, size.x, t), at + Vector3(0, 0, size.y * 0.5 + t * 0.5))
		_box("ochre", Vector3(d, size.x, t), at + Vector3(0, 0, -size.y * 0.5 - t * 0.5))
		_box("green", Vector3(d, size.x, 0.025), at)
		_box("green", Vector3(d, 0.025, size.y), at)
		return
	_box("ochre", Vector3(size.x + t * 2, t, d), at + Vector3(0, size.y * 0.5 + t * 0.5, 0), lean)
	_box("ochre", Vector3(size.x + t * 2, t * 1.4, d + 0.03), at + Vector3(0, -size.y * 0.5 - t * 0.6, 0), lean)
	_box("ochre", Vector3(t, size.y, d), at + Vector3(size.x * 0.5 + t * 0.5, 0, 0), lean)
	_box("ochre", Vector3(t, size.y, d), at + Vector3(-size.x * 0.5 - t * 0.5, 0, 0), lean)
	_box("green", Vector3(0.025, size.y, d), at, lean)
	_box("green", Vector3(size.x, 0.025, d), at, lean)


## The barrel roof of dark boards with an ochre edge, the raised skylight
## strip along its top, the stovepipe and a canvas bundle tied on behind.
func _roof() -> void:
	var length := BACK_EAVE - FRONT_EAVE
	var mid_x := (BACK_EAVE + FRONT_EAVE) * 0.5
	var reach := asin(clampf((HALF_TOP + 0.1) / ROOF_R, 0.0, 1.0))
	var n := 14
	for i in n:
		var a := lerpf(-reach, reach, (i + 0.5) / n)
		var at := Vector3(mid_x, ROOF_Y + cos(a) * ROOF_R, sin(a) * ROOF_R)
		var w := ROOF_R * reach * 2.0 / n
		_box("roof", Vector3(length, 0.045, w + 0.01), at, Basis(Vector3.RIGHT, a))
	for side: float in [-1.0, 1.0]:
		var a := side * reach
		var edge := Vector3(mid_x, ROOF_Y + cos(a) * ROOF_R - 0.03, sin(a) * (ROOF_R + 0.02))
		_box("ochre", Vector3(length + 0.04, 0.07, 0.04), edge, Basis(Vector3.RIGHT, a))
	# The front and back edges of the roof, following the arc.
	for x: float in [FRONT_EAVE, BACK_EAVE]:
		for i in 12:
			var a0 := lerpf(-reach, reach, i / 12.0)
			var a1 := lerpf(-reach, reach, (i + 1) / 12.0)
			_rod_between("ochre", Vector3(x, ROOF_Y + cos(a0) * (ROOF_R + 0.02), sin(a0) * (ROOF_R + 0.02)),
					Vector3(x, ROOF_Y + cos(a1) * (ROOF_R + 0.02), sin(a1) * (ROOF_R + 0.02)), 0.03, 5)
	# The skylight strip ("mollicroft") with little glowing panes.
	var top := ROOF_Y + ROOF_R
	var m0 := FRONT + 0.5
	var m1 := BACK - 0.5
	_box("green", Vector3(m1 - m0, 0.26, 0.7), Vector3((m0 + m1) * 0.5, top + 0.08, 0))
	_box("roof", Vector3(m1 - m0 + 0.2, 0.05, 0.86), Vector3((m0 + m1) * 0.5, top + 0.23, 0))
	for side: float in [-1.0, 1.0]:
		var panes := 6
		for i in panes:
			var x := lerpf(m0, m1, (i + 0.5) / panes)
			_box("glow", Vector3(0.26, 0.13, 0.02), Vector3(x, top + 0.1, side * 0.355))
			_box("ochre", Vector3(0.04, 0.2, 0.03), Vector3(x + 0.17, top + 0.1, side * 0.36))
	perches.append(Vector3(m1 - 0.2, top + 0.26, 0.15))
	# The stovepipe with its iron cap, on the far side of the roof.
	var pipe := Vector3(FRONT + 0.75, MerchantWagon.roof_at(-0.55) - 0.05, -0.55)
	_rod("iron", 0.85, 0.07, pipe + Vector3(0, 0.42, 0), Basis.IDENTITY, 10)
	_rod("iron", 0.06, 0.1, pipe + Vector3(0, 0.12, 0), Basis.IDENTITY, 10)
	_lathe("iron", [Vector2(0, 0.0), Vector2(0.17, 0.0), Vector2(0.17, 0.02), Vector2(0.0, 0.14)], Transform3D(Basis.IDENTITY, pipe + Vector3(0, 0.95, 0)))
	_rod("iron", 0.1, 0.012, pipe + Vector3(0.1, 0.9, 0), Basis.IDENTITY, 4)
	_rod("iron", 0.1, 0.012, pipe + Vector3(-0.1, 0.9, 0), Basis.IDENTITY, 4)
	# A rolled canvas bundle and a small crate tied on the roof at the back.
	var roll := Vector3(BACK - 0.15, MerchantWagon.roof_at(0.5) + 0.12, 0.5)
	_rod("violet", 0.9, 0.16, roll, Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, 0.0), 10)
	for dx: float in [-0.28, 0.28]:
		_ring("rope", 0.165, 0.012, roll + Vector3(dx, 0, 0), Basis(Vector3.FORWARD, PI * 0.5), 12)
	var crate := Vector3(FRONT + 0.2, top + 0.02, 0.2)
	_crate(crate + Vector3(0, 0.2, 0), Vector3(0.5, 0.4, 0.45), 0.15)


## A crate of boards with iron corners, at its centre `at`.
func _crate(at: Vector3, size: Vector3, turn := 0.0) -> void:
	var b := Basis(Vector3.UP, turn)
	_box(_wood(), size, at, b)
	for y: float in [-0.3, 0.3]:
		_box("wood_b", Vector3(size.x + 0.02, 0.05, size.z + 0.02), at + Vector3(0, y * size.y * 1.4, 0), b)
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			_box("iron", Vector3(0.05, size.y + 0.01, 0.05), at + b * Vector3(sx * size.x, 0, sz * size.z), b)


## The front porch: a footboard at floor height, turned balusters with a
## rail on both sides, tall turned posts under the eave, the stable door with
## its upper half open on the warm room inside, a lantern, and steps down
## between the shafts.
func _porch() -> void:
	var x0 := FRONT_EAVE + 0.15
	var depth := FRONT - x0
	_box("wood_c", Vector3(depth, 0.08, HALF_LOW * 2.0 + 0.1), Vector3((FRONT + x0) * 0.5, FLOOR, 0))
	_box("green", Vector3(0.06, 0.16, HALF_LOW * 2.0 + 0.1), Vector3(x0, FLOOR - 0.06, 0))
	for side: float in [-1.0, 1.0]:
		var z := side * (HALF_LOW - 0.02)
		# The tall post at the front corner, up to the eave.
		var post_h := MerchantWagon.roof_at(z) - FLOOR - 0.05
		_lathe("turned", MerchantWagon.spindle(post_h, 0.055), Transform3D(Basis.IDENTITY, Vector3(x0 + 0.04, FLOOR + 0.04, z)))
		_bracket(Vector3(x0 + 0.04, FLOOR + post_h - 0.05, z), side)
		# The balusters along the side, under a rail.
		var n := 4
		for i in n:
			var x := lerpf(x0 + 0.16, FRONT - 0.08, (i + 0.5) / n)
			_lathe("turned", MerchantWagon.spindle(0.5, 0.03), Transform3D(Basis.IDENTITY, Vector3(x, FLOOR + 0.04, z)))
		_box("turned", Vector3(depth, 0.05, 0.08), Vector3((FRONT + x0) * 0.5 + 0.02, FLOOR + 0.57, z))
	perches.append(Vector3((FRONT + x0) * 0.5, FLOOR + 0.6, HALF_LOW - 0.02))
	# The door: a green frame, the lower half shut, the upper half swung open.
	var door_w := 0.72
	var door_h := 1.65
	var face := FRONT - 0.035
	_box("glow", Vector3(0.01, door_h * 0.5, door_w), Vector3(face + 0.02, FLOOR + door_h * 0.75, 0))
	_box("green", Vector3(0.05, 0.08, door_w + 0.16), Vector3(face, FLOOR + door_h + 0.04, 0))
	for s: float in [-1.0, 1.0]:
		_box("green", Vector3(0.05, door_h, 0.08), Vector3(face, FLOOR + door_h * 0.5, s * (door_w * 0.5 + 0.04)))
	_box("red", Vector3(0.04, door_h * 0.5, door_w), Vector3(face - 0.01, FLOOR + door_h * 0.25, 0))
	_box("ochre", Vector3(0.015, door_h * 0.5 - 0.16, door_w - 0.18), Vector3(face - 0.035, FLOOR + door_h * 0.25, 0))
	var hinge := Vector3(face - 0.02, FLOOR + door_h * 0.75, -door_w * 0.5)
	var swing := Basis(Vector3.UP, -1.25)
	_box("red", Vector3(0.04, door_h * 0.5 - 0.02, door_w), hinge + swing * Vector3(0, 0, door_w * 0.5), swing)
	for dy: float in [-0.22, 0.22]:
		_box("iron", Vector3(0.012, 0.035, door_w * 0.6), hinge + swing * Vector3(-0.025, dy, door_w * 0.3), swing)
		_box("iron", Vector3(0.012, 0.035, door_w * 0.6), Vector3(face - 0.035, FLOOR + door_h * 0.25 + dy * 0.7, -door_w * 0.2))
	_ball("brass", 0.03, Vector3(face - 0.05, FLOOR + door_h * 0.42, door_w * 0.36))
	# The steps: two stringers and three treads down to the ground.
	var foot := x0 - 0.7
	for z: float in [-0.34, 0.34]:
		_rod_between("wood_b", Vector3(x0 + 0.02, FLOOR - 0.02, z), Vector3(foot, 0.03, z), 0.035, 5)
	for i in 3:
		var t := (i + 1) / 4.0
		var p := Vector3(x0 + 0.02, FLOOR - 0.02, 0).lerp(Vector3(foot, 0.03, 0), t)
		_box(_wood(), Vector3(0.22, 0.04, 0.72), p)
	# The porch lantern, hanging from an iron hook under the eave.
	_lantern(Vector3(x0 + 0.2, FLOOR + 1.1, HALF_LOW - 0.25), 0.45)


## A lantern hanging from a chain `drop` long below `at`'s hook: an iron cap,
## a glowing glass, a brass base and a ring on top.
func _lantern(hook: Vector3, drop: float) -> void:
	var at := hook - Vector3(0, drop, 0)
	_rod("iron", drop - 0.15, 0.008, hook - Vector3(0, (drop - 0.15) * 0.5, 0), Basis.IDENTITY, 4)
	_ring("iron", 0.04, 0.008, at + Vector3(0, 0.12, 0), Basis(Vector3.RIGHT, PI * 0.5), 8)
	_lathe("iron", [Vector2(0, 0.0), Vector2(0.11, 0.0), Vector2(0.11, 0.015), Vector2(0.05, 0.08), Vector2(0, 0.09)], Transform3D(Basis.IDENTITY, at + Vector3(0, 0.02, 0)), 6)
	_rod("glow", 0.2, 0.075, at - Vector3(0, 0.1, 0), Basis.IDENTITY, 6)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		_rod("iron", 0.22, 0.007, at + Vector3(cos(a) * 0.08, -0.1, sin(a) * 0.08), Basis.IDENTITY, 3)
	_lathe("brass", [Vector2(0, 0), Vector2(0.09, 0.0), Vector2(0.1, 0.03), Vector2(0.08, 0.04), Vector2(0, 0.04)], Transform3D(Basis.IDENTITY, at - Vector3(0, 0.24, 0)), 8)


## The rack at the back under the eave: a slatted shelf with turned rails,
## crates, a barrel with iron hoops, a basket; and the iron crane with the
## big lantern by the merchant.
func _rack() -> void:
	var x1 := BACK_EAVE - 0.05
	var depth := x1 - BACK
	var cx := (BACK + x1) * 0.5
	for i in 5:
		var z := lerpf(-HALF_LOW, HALF_LOW, (i + 0.5) / 5.0)
		_box(_wood(), Vector3(depth, 0.05, 0.3), Vector3(cx, FLOOR - 0.02, z))
	for side: float in [-1.0, 1.0]:
		_box("wood_b", Vector3(0.08, 0.6, 0.08), Vector3(x1 - 0.04, FLOOR - 0.33, side * (HALF_LOW - 0.04)))
	for i in 4:
		var z := lerpf(-HALF_LOW, HALF_LOW, i / 3.0)
		_lathe("turned", MerchantWagon.spindle(0.42, 0.028), Transform3D(Basis.IDENTITY, Vector3(x1 - 0.03, FLOOR + 0.02, z)))
	_box("turned", Vector3(0.07, 0.05, HALF_LOW * 2.0 + 0.06), Vector3(x1 - 0.03, FLOOR + 0.46, 0))
	# What is stacked on it.
	_crate(Vector3(cx, FLOOR + 0.2, -0.45), Vector3(0.4, 0.36, 0.5), 0.0)
	_crate(Vector3(cx - 0.02, FLOOR + 0.55, -0.42), Vector3(0.32, 0.3, 0.38), 0.2)
	var barrel := Vector3(cx, FLOOR + 0.02, 0.12)
	var prof := []
	for p in [[0, 0], [0.15, 0], [0.18, 0.12], [0.19, 0.24], [0.18, 0.36], [0.15, 0.48], [0, 0.48]]:
		prof.append(Vector2(p[0], p[1]))
	_lathe(_wood(), prof, Transform3D(Basis.IDENTITY, barrel), 12)
	for y: float in [0.07, 0.41]:
		_ring("iron", 0.17, 0.012, barrel + Vector3(0, y, 0), Basis.IDENTITY, 14)
	perches.append(barrel + Vector3(0, 0.5, 0))
	var basket := Vector3(cx, FLOOR + 0.02, 0.6)
	_lathe("wicker", [Vector2(0, 0), Vector2(0.12, 0), Vector2(0.16, 0.2), Vector2(0.14, 0.2), Vector2(0, 0.04)], Transform3D(Basis.IDENTITY, basket), 10)
	_ring("wicker", 0.16, 0.015, basket + Vector3(0, 0.2, 0), Basis.IDENTITY, 12)
	for i in 4:
		_ball(["herb", "garlic", "chilli", "herb_dry"][i], 0.05, basket + Vector3(-0.06 + (i % 2) * 0.1, 0.2, -0.05 + (i / 2) * 0.09))
	# The crane by the merchant: an iron arm off the back corner, its brace,
	# and the lantern that lights his wares.
	var root := Vector3(x1 - 0.05, 2.65, HALF_TOP - 0.05)
	var tip := root + Vector3(0.5, 0.05, 0.35)
	_rod_between("iron", root, tip, 0.02, 5)
	_rod_between("iron", root - Vector3(0, 0.45, 0), tip.lerp(root, 0.4), 0.014, 4)
	_ball("iron", 0.03, tip)
	for i in 3:
		_ring("iron", 0.03, 0.006, root.lerp(tip, 0.3 + i * 0.2) + Vector3(0, 0.04, 0), Basis(Vector3.FORWARD, 0.4), 6)
	_lantern(tip, 0.42)


## Everything that hangs off the sides: herbs drying under the eaves, a
## garlic string, chillies, copper pots, a pan and a ladle, a kettle, a
## coil of rope, a bucket, and a tin bath on the far side.
func _hangings() -> void:
	var near := 1.0
	var far := -1.0
	var eave_z := HALF_TOP + 0.1
	# Herbs in bunches, hung upside down from a rod along the eave.
	for side: float in [near, far]:
		_rod_between("iron", Vector3(FRONT + 0.2, TOP - 0.02, side * eave_z), Vector3(BACK - 0.2, TOP - 0.02, side * eave_z), 0.01, 4)
	var herbs := ["herb", "herb_dry", "lavender", "herb", "herb_dry", "herb", "lavender"]
	var xs := [-2.65, -2.4, -2.12, -1.6, 0.0, 0.3, 0.62]
	for i in xs.size():
		var x: float = xs[i] + _rng.randf_range(-0.04, 0.04)
		_herb_bunch(Vector3(x, TOP - 0.03, eave_z + 0.02), herbs[i])
	for x: float in [-2.5, -1.9, 0.1, 0.6]:
		_herb_bunch(Vector3(x, TOP - 0.03, -eave_z - 0.02), herbs[_rng.randi() % herbs.size()])
	# Garlic and chillies on strings over the window.
	for i in 7:
		var t := i / 6.0
		var x := lerpf(-1.25, -0.55, t)
		var y := TOP - 0.1 - sin(t * PI) * 0.18
		_ball("garlic", 0.045, Vector3(x, y, eave_z + 0.03), Vector3(1, 0.85, 1))
	for i in 5:
		_rod("chilli", 0.11, 0.018, Vector3(-0.32, TOP - 0.12 - i * 0.09, eave_z + 0.03), Basis(Vector3.FORWARD, 0.3 * (1 if i % 2 == 0 else -1)), 5)
	_rod("rope", 0.5, 0.004, Vector3(-0.32, TOP - 0.28, eave_z + 0.02), Basis.IDENTITY, 3)
	# Under the floor between the wheels: hooks on the bottom rail with pots.
	var low := FLOOR + 0.02
	var rail_z := HALF_LOW + 0.08
	_pot(Vector3(-1.75, low, rail_z), 0.13, 0.15, "copper")
	_pot(Vector3(-1.38, low, rail_z), 0.1, 0.12, "copper")
	_pan(Vector3(-1.05, low, rail_z))
	_ladle(Vector3(-0.78, low, rail_z))
	_kettle(Vector3(-0.42, low, rail_z))
	# A bucket swinging under the floor behind the pan box.
	var bucket := Vector3(-0.15, FLOOR - 0.75, 0.35)
	_lathe("wood_b", [Vector2(0, 0), Vector2(0.12, 0), Vector2(0.15, 0.24), Vector2(0.135, 0.24), Vector2(0, 0.02)], Transform3D(Basis.IDENTITY, bucket), 10)
	_ring("iron", 0.14, 0.01, bucket + Vector3(0, 0.18, 0), Basis.IDENTITY, 12)
	_rod_between("iron", bucket + Vector3(0, 0.24, -0.14), Vector3(-0.15, FLOOR - 0.16, 0.35), 0.006, 3)
	_rod_between("iron", bucket + Vector3(0, 0.24, 0.14), Vector3(-0.15, FLOOR - 0.16, 0.35), 0.006, 3)
	# A coil of rope on a peg by the front corner.
	var coil := Vector3(FRONT + 0.4, 1.95, MerchantWagon.half_at(1.95) + 0.1)
	_rod("iron", 0.12, 0.015, coil + Vector3(0, 0.16, -0.05), Basis(Vector3.RIGHT, PI * 0.5), 4)
	for i in 4:
		_ring("rope", 0.17 - i * 0.008, 0.022, coil + Vector3(0, -i * 0.01, i * 0.012), Basis(Vector3.RIGHT, PI * 0.5 - 0.15), 14)
	# The tin bath on the far side, and a pan.
	var bath := Vector3(-1.4, 1.9, -(MerchantWagon.half_at(1.9) + 0.14))
	var bath_mesh := MerchantWagon.lathe([Vector2(0, 0), Vector2(0.28, 0.0), Vector2(0.34, 0.16), Vector2(0.31, 0.16), Vector2(0, 0.02)], 14)
	_add("tin", bath_mesh, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.5, 1, 1)), bath))
	_pan(Vector3(0.2, low, -rail_z), -1.0)
	_pot(Vector3(-0.3, low, -rail_z), 0.12, 0.14, "iron")


func _herb_bunch(hook: Vector3, kind: String) -> void:
	var drop := _rng.randf_range(0.05, 0.12)
	_rod("rope", drop, 0.005, hook - Vector3(0, drop * 0.5, 0), Basis.IDENTITY, 3)
	var top := hook - Vector3(0, drop, 0)
	var len := _rng.randf_range(0.26, 0.36)
	var w := _rng.randf_range(0.08, 0.12)
	var bunch := MerchantWagon.lathe([Vector2(0, 0), Vector2(w * 0.7, 0.03), Vector2(w, len * 0.35),
			Vector2(w * 0.6, len * 0.8), Vector2(0.02, len), Vector2(0, len)], 7)
	var tilt := Basis(Vector3.FORWARD, _rng.randf_range(-0.12, 0.12)) * Basis(Vector3.UP, _rng.randf() * TAU)
	_add(kind, bunch, Transform3D(tilt, top - tilt * Vector3(0, len, 0)))
	_ring("rope", 0.022, 0.008, top - Vector3(0, 0.03, 0), Basis.IDENTITY, 6)


## A pot hanging by its bail from a hook at `hook`.
func _pot(hook: Vector3, radius: float, height: float, key: String) -> void:
	var drop := 0.12
	var top := hook - Vector3(0, drop, 0)
	var at := top - Vector3(0, height, 0)
	_rod_between("iron", hook + Vector3(0, 0.04, 0), hook - Vector3(0, 0.02, 0), 0.008, 3)
	_lathe(key, [Vector2(0, 0), Vector2(radius * 0.8, 0), Vector2(radius, height * 0.3), Vector2(radius, height * 0.85),
			Vector2(radius * 1.08, height), Vector2(radius * 0.95, height), Vector2(0, height * 0.1)], Transform3D(Basis.IDENTITY, at), 12)
	_rod_between("iron", top + Vector3(-radius, 0, 0), hook, 0.006, 3)
	_rod_between("iron", top + Vector3(radius, 0, 0), hook, 0.006, 3)


## A frying pan hanging by its handle, its face to the side.
func _pan(hook: Vector3, side := 1.0) -> void:
	var handle := 0.3
	var pan_at := hook - Vector3(0, handle + 0.13, 0)
	_rod("iron", handle, 0.014, hook - Vector3(0, handle * 0.5, 0), Basis.IDENTITY, 5)
	_ring("iron", 0.02, 0.006, hook + Vector3(0, 0.01, 0), Basis(Vector3.RIGHT, PI * 0.5), 6)
	var dish := MerchantWagon.lathe([Vector2(0, 0), Vector2(0.11, 0), Vector2(0.14, 0.04), Vector2(0.13, 0.04), Vector2(0, 0.01)], 12)
	_add("iron", dish, Transform3D(Basis(Vector3.RIGHT, side * PI * 0.5), pan_at + Vector3(0, 0, side * 0.02)))


func _ladle(hook: Vector3) -> void:
	_rod("copper", 0.32, 0.01, hook - Vector3(0, 0.16, 0), Basis.IDENTITY, 4)
	_ball("copper", 0.055, hook - Vector3(0, 0.36, 0), Vector3(1, 0.6, 1))


func _kettle(hook: Vector3) -> void:
	var at := hook - Vector3(0, 0.34, 0)
	_lathe("copper", [Vector2(0, 0), Vector2(0.09, 0), Vector2(0.11, 0.07), Vector2(0.09, 0.15), Vector2(0.04, 0.18),
			Vector2(0.04, 0.2), Vector2(0, 0.21)], Transform3D(Basis.IDENTITY, at), 10)
	_rod_between("copper", at + Vector3(0.08, 0.06, 0), at + Vector3(0.18, 0.15, 0), 0.015, 4)
	_rod_between("iron", at + Vector3(-0.07, 0.17, 0), hook, 0.006, 3)
	_rod_between("iron", at + Vector3(0.07, 0.17, 0), hook, 0.006, 3)


## The donkey's corner in front of the shafts: a heap of hay for her to
## nibble, a wooden bucket of water, and her padded collar with its brass
## hames hung over the tip of the near shaft, ready for the road.
func _donkey_corner() -> void:
	for i in 7:
		var a := TAU * i / 7.0 + _rng.randf() * 0.4
		var r := 0.0 if i == 0 else _rng.randf_range(0.22, 0.36)
		_ball("hay", _rng.randf_range(0.24, 0.32), HAY_AT + Vector3(cos(a) * r, 0.1, sin(a) * r), Vector3(1.3, 0.7, 1.15))
	_ball("hay", 0.26, HAY_AT + Vector3(0.05, 0.3, -0.03), Vector3(1.2, 0.6, 1.1))
	# Loose stalks sticking out of the heap and strewn round it.
	for i in 16:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.25, 0.7)
		var p := HAY_AT + Vector3(cos(a) * r, 0.03 + _rng.randf() * 0.12, sin(a) * r)
		var d := Vector3(cos(a + _rng.randf_range(-0.8, 0.8)), _rng.randf_range(-0.1, 0.35), sin(a + _rng.randf_range(-0.8, 0.8))) * 0.18
		_rod_between("hay", p - d, p + d, 0.008, 4)
	# The bucket: staves in a ring, two iron hoops, a rope handle, water inside.
	var bucket := Vector3(-6.75, 0, 1.25)
	_lathe("wood_b", [Vector2(0, 0), Vector2(0.17, 0), Vector2(0.2, 0.36), Vector2(0.18, 0.36), Vector2(0.15, 0.04), Vector2(0, 0.04)],
		Transform3D(Basis.IDENTITY, bucket), 12)
	for y: float in [0.08, 0.28]:
		_ring("iron", 0.17 + y * 0.08, 0.012, bucket + Vector3(0, y, 0), Basis.IDENTITY, 14)
	_rod("tin", 0.01, 0.17, bucket + Vector3(0, 0.3, 0), Basis.IDENTITY, 12)
	_ring("rope", 0.19, 0.01, bucket + Vector3(0, 0.36, 0), Basis(Vector3.FORWARD, 1.2), 12)
	# A tethering stake with a lantern on its hook, so she is seen at night.
	_rod("wood_b", 1.5, 0.045, STAKE_AT + Vector3(0, 0.75, 0), Basis.IDENTITY, 6)
	_rod_between("iron", STAKE_AT + Vector3(0, 1.42, 0), STAKE_AT + Vector3(0.22, 1.42, 0), 0.015, 4)
	_lantern(STAKE_AT + Vector3(0.2, 1.42, 0), 0.25)
	# The collar, propped upright against the near shaft's tip: a padded
	# leather ring with two brass hames and a red cloth pad.
	var tip := Vector3(FRONT - 2.5, 0.0, 0.66)
	var lean := Basis(Vector3.UP, 0.3) * Basis(Vector3.FORWARD, 0.0) * Basis(Vector3.RIGHT, -0.35)
	var at := tip + Vector3(0.05, 0.36, 0.22)
	_ring("leather", 0.25, 0.07, at, lean * Basis(Vector3.RIGHT, PI * 0.5), 16)
	_ring("cloth", 0.2, 0.035, at + lean * Vector3(0, 0, -0.03), lean * Basis(Vector3.RIGHT, PI * 0.5), 14)
	for s: float in [-1.0, 1.0]:
		_rod("brass", 0.46, 0.022, at + lean * Vector3(s * 0.28, 0.05, 0.03), lean * Basis(Vector3.FORWARD, s * 0.2), 6)
		_ball("brass", 0.035, at + lean * Vector3(s * 0.24, 0.3, 0.03))


## The lights: the big lantern on the crane by the merchant, the porch
## lantern and the glow from the windows; smoke from the stovepipe.
func _lights(root: Node3D) -> void:
	var main := OmniLight3D.new()
	main.light_color = Color(1.0, 0.72, 0.62)
	main.light_energy = 2.4
	main.omni_range = 9.0
	main.position = Vector3(BACK_EAVE + 0.5, 2.15, HALF_TOP + 0.45)
	root.add_child(main)
	var porch := OmniLight3D.new()
	porch.light_color = Color(1.0, 0.75, 0.5)
	porch.light_energy = 1.2
	porch.omni_range = 4.5
	porch.position = Vector3(FRONT_EAVE + 0.35, FLOOR + 0.6, HALF_LOW)
	root.add_child(porch)
	var donkey := OmniLight3D.new()
	donkey.light_color = Color(1.0, 0.75, 0.5)
	donkey.light_energy = 1.4
	donkey.omni_range = 5.0
	donkey.position = STAKE_AT + Vector3(0.2, 1.0, 0)
	root.add_child(donkey)
	var smoke := ChimneySmoke.make()
	smoke.position = Vector3(FRONT + 0.75, MerchantWagon.roof_at(-0.55) + 1.05, -0.55)
	root.add_child(smoke)


## Lights the stove once the wagon stands in the level: the smoke is already
## up when he arrives.
static func kindle(wagon: Node3D) -> void:
	var smoke := wagon.get_node_or_null("ChimneySmoke") as CPUParticles3D
	if smoke:
		ChimneySmoke.light(smoke, true, true)
