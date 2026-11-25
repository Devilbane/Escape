class_name PubSign
extends RefCounted
## The village pub's sign, in the old English way: a painted board of dark green with the name,
## Apples & Ivy!, in gilt lettering and a medallion of red and green apples among ivy leaves (see
## tools/make_pub_sign_painting.py), hung by two iron rings from a wrought-iron bracket with scrolls.
## Two ways to hang it, as with the shop shields (see HangingShield):
##  - on_wall: a bracket out from the tavern's front wall (VillageHalls.hang_sign);
##  - on_post: a bracket on a turned wooden post on a stone foot, standing free on the square
##    (Outdoor._square_pub_sign), the board facing south with its back painted too.
## Both hang high enough to walk under (see CLEAR), and only the post itself is solid.
## The pub's name is the same in every language, so it needs no Lang entry.

const NAME := "Apples & Ivy!"
## The board, in metres, and its thickness.
const WIDE := 1.3
const TALL := 0.95
const THICK := 0.08
## The moulding round the board's edge: how wide it is and how far it stands out of both faces.
const LIP := 0.035
const LIP_RISE := 0.02
## How long the chains are, from the bracket down to the board's top.
const CHAIN := 0.2
## The lowest point of a hanging sign stays this high above the ground, so the hero walks under it.
const CLEAR := 2.0
## The post: how tall, and how far its bracket reaches out sideways (along +x).
const POST_HIGH := 3.9
const ARM_OUT := 1.8
## The painted faces (see tools/make_pub_sign_painting.py): pub_sign.jpg and its normal map.
const PAINTING := "res://assets/signs/pub_sign%s"

const IRON_BLACK := Color(0.34, 0.35, 0.37)
const TIMBER := Color(0.46, 0.34, 0.24)
const TIMBER_DARK := Color(0.32, 0.22, 0.15)
const STONE_GREY := Color(0.7, 0.68, 0.64)

static var _face: StandardMaterial3D


## The board alone, its top middle at the origin, facing +z: the painting on both faces (the back
## reads the right way round too), a wooden moulding round the edge and a cornice on top, and two
## iron rings on the cornice for the chains.
static func board() -> Node3D:
	var root := Node3D.new()
	root.name = "Board"
	root.set_meta("name_text", NAME)
	var core := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDE, TALL, THICK)
	core.mesh = box
	core.material_override = WeatheredProps.colour_material(TIMBER_DARK)
	core.position = Vector3(0, -TALL * 0.5, 0)
	root.add_child(core)
	for side: float in [1.0, -1.0]:
		var face := MeshInstance3D.new()
		face.name = "Face"
		var quad := QuadMesh.new()
		quad.size = Vector2(WIDE, TALL)
		face.mesh = quad
		face.material_override = face_material()
		face.position = Vector3(0, -TALL * 0.5, side * (THICK * 0.5 + 0.002))
		face.rotation.y = 0.0 if side > 0.0 else PI
		root.add_child(face)
	var b := WeatheredProps.Builder.new()
	var depth := THICK + LIP_RISE * 2.0
	b.box(Vector3(0, -LIP, 0), Vector3(WIDE, LIP, depth), TIMBER)
	b.box(Vector3(0, -TALL, 0), Vector3(WIDE, LIP, depth), TIMBER)
	for x: float in [-1.0, 1.0]:
		b.box(Vector3(x * (WIDE * 0.5 - LIP * 0.5), -TALL + LIP, 0), Vector3(LIP, TALL - LIP * 2.0, depth), TIMBER)
	# The cornice: a wider cap on top, with a thin step under it.
	b.box(Vector3(0, 0, 0), Vector3(WIDE + 0.08, 0.05, depth + 0.04), TIMBER_DARK)
	b.box(Vector3(0, 0.05, 0), Vector3(WIDE + 0.03, 0.025, depth), TIMBER)
	# A small turned drop at each bottom corner.
	for x: float in [-1.0, 1.0]:
		b.cylinder(Vector3(x * (WIDE * 0.5 - 0.04), -TALL - 0.07, 0), 0.0, 0.035, 0.07, TIMBER_DARK, WeatheredProps.WOOD, 8)
	b.finish(root, Vector3.ZERO, true)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.022
	ring.outer_radius = 0.04
	ring.rings = 10
	ring.ring_segments = 5
	for x: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = ring
		eye.material_override = WeatheredProps.colour_material(IRON_BLACK, WeatheredProps.IRON)
		eye.position = Vector3(x * WIDE * 0.38, 0.09, 0)
		eye.rotation = Vector3(PI * 0.5, 0, PI * 0.5)
		root.add_child(eye)
	return root


## The painted face: the painting with its relief from the normal map.
static func face_material() -> StandardMaterial3D:
	if _face != null:
		return _face
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.76
	var colour := PAINTING % ".jpg"
	if ResourceLoader.exists(colour):
		mat.albedo_texture = load(colour)
	else:
		mat.albedo_color = Color(0.09, 0.27, 0.16)
	var normals := PAINTING % "_n.png"
	if ResourceLoader.exists(normals):
		mat.normal_enabled = true
		mat.normal_texture = load(normals)
		mat.normal_scale = 1.0
	_face = mat
	return mat


## The sign on a bracket out from a wall. The root sits on the wall at the arm's height; the wall is
## behind it (at -z) and the street at +z. With `across` the board hangs edgewise to the wall, seen
## from along the street (it needs an arm about `out` = 1.6 long); without, it hangs flat in front of
## the wall from a crossbar at the arm's end, seen from across the street.
static func on_wall(out := 1.6, across := true) -> Node3D:
	var root := Node3D.new()
	root.name = "PubSign"
	root.set_meta("name_text", NAME)
	var b := WeatheredProps.Builder.new()
	var plate := _bracket(b, out)
	var hang_z := out * 0.56
	if across:
		for z: float in [hang_z - WIDE * 0.38, hang_z + WIDE * 0.38]:
			HangingShield._chain(root, Vector3(0, 0, z), CHAIN)
		var sign_board := board()
		sign_board.position = Vector3(0, -CHAIN - 0.07, hang_z)
		sign_board.rotation.y = PI * 0.5
		root.add_child(sign_board)
	else:
		var bar_at := out - 0.05
		b.bar(Vector3(-WIDE * 0.5, 0, bar_at), Vector3(WIDE * 0.5, 0, bar_at), 0.02, IRON_BLACK, WeatheredProps.IRON, 6)
		for x: float in [-WIDE * 0.38, WIDE * 0.38]:
			HangingShield._chain(root, Vector3(x, 0, bar_at), CHAIN)
		var flat := board()
		flat.position = Vector3(0, -CHAIN - 0.07, bar_at)
		root.add_child(flat)
	b.finish(root, Vector3.ZERO, true)
	root.set_meta("plate", plate)
	return root


## The sign on a post standing on the ground (the root, at the post's foot), the bracket reaching
## along +x and the board hanging flat under it, facing +z, its middle `ARM_OUT` * 0.53 out from the
## post. The post is a turned timber on a stone foot, with a collar and a finial.
static func on_post() -> Node3D:
	var root := Node3D.new()
	root.name = "PubSignPost"
	root.set_meta("name_text", NAME)
	var b := WeatheredProps.Builder.new()
	# The foot: two stone steps. The post: a tapered timber with a collar low down and one under the cap.
	b.box(Vector3(0, 0, 0), Vector3(0.62, 0.16, 0.62), STONE_GREY, WeatheredProps.STONE)
	b.frustum(Vector3(0, 0.16, 0), Vector2(0.46, 0.46), Vector2(0.36, 0.36), 0.14, STONE_GREY, WeatheredProps.STONE)
	b.cylinder(Vector3(0, 0.3, 0), 0.13, 0.095, POST_HIGH - 0.3, TIMBER, WeatheredProps.WOOD, 12)
	b.cylinder(Vector3(0, 0.9, 0), 0.125, 0.125, 0.07, TIMBER_DARK, WeatheredProps.WOOD, 12)
	b.cylinder(Vector3(0, POST_HIGH - 0.45, 0), 0.115, 0.115, 0.07, TIMBER_DARK, WeatheredProps.WOOD, 12)
	b.cylinder(Vector3(0, POST_HIGH, 0), 0.13, 0.04, 0.1, TIMBER_DARK, WeatheredProps.WOOD, 12)
	b.cylinder(Vector3(0, POST_HIGH + 0.1, 0), 0.04, 0.0, 0.16, IRON_BLACK, WeatheredProps.IRON, 8)
	b.finish(root, Vector3.ZERO, true)
	# The bracket, turned so its arm runs along +x, bolted to the post just under the cap.
	var arm_y := POST_HIGH - 0.32
	var iron := WeatheredProps.Builder.new()
	_bracket(iron, ARM_OUT, true)
	var bracket := iron.finish(root, Vector3(0, arm_y, 0), true)
	bracket.name = "Bracket"
	bracket.rotation.y = PI * 0.5
	var mid := ARM_OUT * 0.53
	for x: float in [mid - WIDE * 0.38, mid + WIDE * 0.38]:
		HangingShield._chain(root, Vector3(x, arm_y - 0.02, 0), CHAIN)
	var sign_board := board()
	sign_board.position = Vector3(mid, arm_y - 0.02 - CHAIN - 0.07, 0)
	root.add_child(sign_board)
	return root


## The bottom of a sign hung on a post, above the ground.
static func post_low_point() -> float:
	return POST_HIGH - 0.32 - 0.02 - CHAIN - 0.07 - TALL - 0.07


## The wrought-iron bracket laid into `b`: an arm along +z from the origin, a wall plate behind it
## and a brace under it from the plate's foot to the arm, with two scrolls in the corner between
## them and a curl at the arm's end. With `on_post` the plate is a clasp round a post's cap
## instead. Returns the plate's size.
static func _bracket(b: WeatheredProps.Builder, out: float, on_post := false) -> Vector3:
	var iron := IRON_BLACK
	var kind := WeatheredProps.IRON
	var plate := Vector3(0.16, 0.62, 0.04)
	if on_post:
		# A clasp: two bands round the post and a boss in the middle.
		for y: float in [-0.2, 0.04]:
			b.cylinder(Vector3(0, y, 0), 0.14, 0.14, 0.05, iron, kind, 12)
	else:
		b.box(Vector3(0, -plate.y + 0.08, plate.z * 0.5), plate, iron, kind)
		for y: float in [-0.5, -0.12]:
			b.cylinder(Vector3(0, y, plate.z + 0.012), 0.022, 0.012, 0.016, iron, kind, 8, Basis(Vector3.RIGHT, PI * 0.5))
	var wall := 0.0 if not on_post else 0.1
	# The arm, a square bar a touch thicker near the wall.
	b.bar(Vector3(0, 0, wall), Vector3(0, 0, out), 0.022, iron, kind, 6)
	b.bar(Vector3(0, 0, wall), Vector3(0, 0, out * 0.3), 0.03, iron, kind, 6)
	# The brace: from low on the plate up to a point two thirds along the arm.
	var foot := Vector3(0, -0.5, wall + 0.02)
	var top := Vector3(0, -0.02, out * 0.74)
	b.bar(foot, top, 0.016, iron, kind, 6)
	# The scrolls in the corner: a big spiral curling into the corner under the arm, a smaller one
	# the other way near the brace, and a curl at the arm's end that turns up and back.
	_scroll(b, Vector3(0, -0.2, wall + out * 0.2), Vector3(0, 0, 1), Vector3(0, 1, 0), 0.13, 1.6, 1.0, 0.012)
	_scroll(b, Vector3(0, -0.16, wall + out * 0.58), Vector3(0, 0, 1), Vector3(0, 1, 0), 0.09, 1.4, -1.0, 0.011)
	_scroll(b, Vector3(0, 0.1, out - 0.07), Vector3(0, 0, 1), Vector3(0, 1, 0), 0.1, 1.5, 1.0, 0.012, PI * 0.5)
	# A little finial at the arm's end.
	b.cylinder(Vector3(0, 0, out), 0.03, 0.0, 0.1, iron, kind, 8, Basis(Vector3.RIGHT, PI * 0.5))
	# Collars where the scrolls and the brace meet the arm, and a rivet row along the arm.
	for z: float in [out * 0.3, out * 0.74]:
		b.cylinder(Vector3(0, 0, z - 0.02), 0.034, 0.034, 0.04, iron, kind, 8, Basis(Vector3.RIGHT, PI * 0.5), true)
	return plate


## A spiral of iron bar in the plane of `u` and `v` round `centre`: from `radius` in to a third of
## it over `turns` turns, starting at `start` radians; `dir` -1 runs it the other way round.
static func _scroll(b: WeatheredProps.Builder, centre: Vector3, u: Vector3, v: Vector3, radius: float, turns: float, dir: float, thick: float, start := 0.0) -> void:
	var steps := 28
	var prev := Vector3.ZERO
	for i in steps + 1:
		var t := float(i) / steps
		var a := start + dir * t * turns * TAU
		var r := radius * (1.0 - t * 0.7)
		var p := centre + (u * cos(a) + v * sin(a)) * r
		if i > 0:
			b.bar(prev, p, thick, IRON_BLACK, WeatheredProps.IRON, 5)
		prev = p
