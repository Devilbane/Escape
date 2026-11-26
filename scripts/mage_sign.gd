class_name MageSign
extends RefCounted
## The sign of Aldo and Odo's tower: a board of dark ebony with an arched top and a gilt rim, a
## crescent moon and a four-pointed star in gilt on both faces and the mages' names in gilt lettering
## under them, hung by two chains from the same wrought-iron bracket as the pub's sign (PubSign).
## Hung out from the tower's front wall beside its door (VillageHalls.hang_sign).
## The names are the same in every language, so they need no Lang entry.

const NAME := "ALDO & ODO"
## The board, in metres, and its thickness: an arch of radius WIDE / 2 over a straight part.
const WIDE := 0.9
const TALL := 0.8
const THICK := 0.075
## How long the chains are, from the bracket down to the board's top, and how far the board's top
## hangs under them.
const CHAIN := 0.2
const DROP := 0.07
const EBONY := Color(0.17, 0.12, 0.11)
const GILT := Color(0.92, 0.72, 0.28)
const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")


## The board alone, its top middle at the origin, facing +z, painted on both faces.
static func board() -> Node3D:
	var root := Node3D.new()
	root.name = "Board"
	root.set_meta("name_text", NAME)
	var turn := Basis(Vector3.RIGHT, PI * 0.5) # A cylinder's axis along z.
	var radius := WIDE * 0.5
	var wood := WeatheredProps.Builder.new()
	var gilt := WeatheredProps.Builder.new()
	# The gilt rim: the same shape a little larger and thinner behind the ebony, so it shows round the edge.
	var rim := 0.03
	gilt.cylinder(Vector3(0, -radius, -THICK * 0.4), radius + rim, radius + rim, THICK * 0.8, GILT, WeatheredProps.FRESH, 24, turn)
	gilt.box(Vector3(0, -TALL, 0), Vector3(WIDE + rim * 2.0, TALL - radius, THICK * 0.8), GILT, WeatheredProps.FRESH)
	wood.cylinder(Vector3(0, -radius, -THICK * 0.5), radius, radius, THICK, EBONY, WeatheredProps.WOOD, 24, turn)
	wood.box(Vector3(0, -TALL, 0), Vector3(WIDE, TALL - radius, THICK), EBONY, WeatheredProps.WOOD)
	for side: float in [1.0, -1.0]:
		var z := side * (THICK * 0.5 + 0.004)
		var out := Basis(Vector3.RIGHT, side * PI * 0.5) # A disc's axis pointing out of this face.
		# The crescent: a gilt disc with an ebony disc over it, pushed aside.
		var moon := Vector3(-0.14, -0.4, z)
		gilt.cylinder(moon, 0.17, 0.17, 0.012, GILT, WeatheredProps.FRESH, 20, out)
		wood.cylinder(moon + Vector3(0.07, 0.03, side * 0.007), 0.145, 0.145, 0.012, EBONY, WeatheredProps.WOOD, 20, out)
		# The star: two long diamonds crossed and two short ones between them.
		var star := Vector3(0.2, -0.3, z)
		for k in 2:
			_bar(gilt, star, Vector2(0.05, 0.3), k * PI * 0.5)
			_bar(gilt, star, Vector2(0.035, 0.18), PI * 0.25 + k * PI * 0.5)
		# A few small stars scattered over the arch.
		for dot: Vector2 in [Vector2(0.0, -0.12), Vector2(-0.27, -0.27), Vector2(0.3, -0.52)]:
			_bar(gilt, Vector3(dot.x, dot.y, z), Vector2(0.04, 0.04), PI * 0.25)
		var label := Label3D.new()
		label.text = NAME
		label.font = FONT
		# A little soft, like paint on wood: drawn at lower resolution and filtered, not razor sharp.
		label.font_size = 30
		label.pixel_size = 0.0042
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		label.modulate = GILT
		label.outline_size = 0
		label.position = Vector3(0.0, -TALL + 0.1, z + side * 0.004)
		label.rotation.y = 0.0 if side > 0.0 else PI
		root.add_child(label)
	wood.finish(root, Vector3.ZERO, true)
	var lit := gilt.finish(root, Vector3.ZERO, false, true)
	lit.name = "Gilding"
	# Lit by itself, as bright as the lettering: the moon and star would otherwise go dull and rusty in shade.
	lit.material_override = _gilt_material()
	# Two iron rings on the top edge for the chains.
	for x: float in [-WIDE * 0.28, WIDE * 0.28]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.022
		ring.outer_radius = 0.04
		ring.rings = 10
		ring.ring_segments = 5
		root.add_child(HangingShield._part(ring, HangingShield._mat("iron", Color(0.18, 0.18, 0.2), 0.45, 0.6), Vector3(x, -0.02, 0.0), Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)))
	return root


## The sign on a bracket out from a wall, as PubSign.on_wall hangs its board: the root sits on the
## wall at the arm's height, the wall behind it (at -z) and the street at +z. With `across` the board
## hangs edgewise to the wall (the arm about `out` long); without, flat from a crossbar at the arm's end.
static func on_wall(out := 1.15, across := true) -> Node3D:
	var root := Node3D.new()
	root.name = "MageSign"
	root.set_meta("name_text", NAME)
	var b := WeatheredProps.Builder.new()
	PubSign._bracket(b, out)
	var hang_z := out * 0.56
	if across:
		for z: float in [hang_z - WIDE * 0.28, hang_z + WIDE * 0.28]:
			HangingShield._chain(root, Vector3(0, 0, z), CHAIN)
		var side_on := board()
		side_on.position = Vector3(0, -CHAIN - DROP, hang_z)
		side_on.rotation.y = PI * 0.5
		root.add_child(side_on)
	else:
		var bar_at := out - 0.05
		b.bar(Vector3(-WIDE * 0.4, 0, bar_at), Vector3(WIDE * 0.4, 0, bar_at), 0.02, PubSign.IRON_BLACK, WeatheredProps.IRON, 6)
		for x: float in [-WIDE * 0.28, WIDE * 0.28]:
			HangingShield._chain(root, Vector3(x, 0, bar_at), CHAIN)
		var flat := board()
		flat.position = Vector3(0, -CHAIN - DROP, bar_at)
		root.add_child(flat)
	b.finish(root, Vector3.ZERO, true)
	return root


## A flat gilt strip `size` (x, y) metres with its middle at `mid`, turned `angle` about the board's normal.
static func _bar(b: WeatheredProps.Builder, mid: Vector3, size: Vector2, angle: float) -> void:
	var turn := Basis(Vector3.BACK, angle)
	b.box(mid - turn * Vector3(0, size.y * 0.5, 0), Vector3(size.x, size.y, 0.012), GILT, WeatheredProps.FRESH, turn)


static var _gilt: StandardMaterial3D


## The gilding's material: unshaded, in the colour of the lettering (a Label3D is unshaded too).
static func _gilt_material() -> StandardMaterial3D:
	if _gilt == null:
		_gilt = StandardMaterial3D.new()
		_gilt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_gilt.albedo_color = GILT
	return _gilt
