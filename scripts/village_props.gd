class_name VillageProps
extends RefCounted
## The village's hand-built things, in the weathered look (see
## WeatheredProps): Gorm's forge, the street lamps, the food pedestal and the
## workbenches of the crafting square. Each is laid out of rough stones,
## boards and iron parts into one or two meshes, so it looks hand-made and
## old but still draws cheaply. The stones, boards and iron are picked by
## random numbers seeded from where the thing stands, so it looks the same
## every time the village is built.

const W := preload("res://scripts/weathered_props.gd")

## The street lamp: where its lantern hangs from the post's foot (the light
## and the candle sit there, see Outdoor._build_lantern).
const LANTERN_AT := Vector3(0, 2.05, 1.0)


static func _rng_at(at: Vector3, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [salt, roundi(at.x * 10.0), roundi(at.z * 10.0)])
	return rng


static func _turn(rng: RandomNumberGenerator, yaw: float, tilt := 0.0) -> Basis:
	return Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf_range(-yaw, yaw), rng.randf_range(-tilt, tilt)))


# --- Stonework ------------------------------------------------------------------

## A wall of rough stones round a rectangle (`size`: x and z), laid in
## courses, each stone a little turned and of its own shade. The inside is
## filled, so the top can be covered.
static func stone_courses(b: WeatheredProps.Builder, middle: Vector3, size: Vector2, height: float, rng: RandomNumberGenerator, course := 0.3, shade := Color(1, 1, 1)) -> void:
	var courses := maxi(1, roundi(height / course))
	var h := height / courses
	var depth := 0.28
	b.box(middle, Vector3(size.x - depth, height, size.y - depth), W.STONES[1] * shade, W.STONE)
	for k in courses:
		var y := middle.y + k * h
		var shift := 0.5 if k % 2 == 1 else 0.0
		for side in 4:
			# Two long sides (along x) and two short ones (along z).
			var along_x := side < 2
			var length := size.x if along_x else size.y - depth * 2.0
			var sign_ := -1.0 if side % 2 == 0 else 1.0
			var x := -length * 0.5
			var first := true
			while x < length * 0.5 - 0.05:
				var piece := rng.randf_range(0.38, 0.62)
				if first:
					piece *= 0.5 + shift
					first = false
				piece = minf(piece, length * 0.5 - x)
				var centre := x + piece * 0.5
				var colour := W.vary(W.STONES[rng.randi() % W.STONES.size()] * shade, rng, 0.1)
				var out := depth * 0.5 + rng.randf_range(-0.02, 0.03)
				var at := Vector3(centre, y, sign_ * (size.y * 0.5 - out)) if along_x \
						else Vector3(sign_ * (size.x * 0.5 - out), y, centre)
				var dims := Vector3(piece - 0.03, h - 0.025, depth) if along_x else Vector3(depth, h - 0.025, piece - 0.03)
				b.box(middle + Vector3(at.x, 0, at.z) + Vector3(0, k * h + 0.012, 0), dims, colour, W.STONE, _turn(rng, 0.04, 0.02))
				x += piece


# --- The forge ------------------------------------------------------------------

## Gorm's forge on its tile (`pos` is the tile's middle): a hearth of rough
## stones with a bed of glowing coals under a sooty hood and chimney, a pair
## of bellows, an anvil with a hammer on an old stump, a quench tub and some
## iron bars. The flame and the light are added by the caller.
## Returns where the coals glow (the middle of their top).
static func build_forge(parent: Node3D, pos: Vector3) -> Vector3:
	var rng := _rng_at(pos, "forge")
	var b := WeatheredProps.Builder.new()
	# The hearth: three courses of stones, a rim of slabs, the coals inside.
	var hearth := Vector3(-0.5, 0, -0.7)
	stone_courses(b, hearth, Vector2(2.0, 1.5), 0.84, rng, 0.28)
	var rim_y := 0.84
	for z in [-0.66, 0.66]:
		b.box(hearth + Vector3(rng.randf_range(-0.03, 0.03), rim_y, z), Vector3(2.1, 0.12, 0.28),
				W.vary(W.STONES[2], rng), W.STONE, _turn(rng, 0.02))
	for x in [-0.92, 0.92]:
		b.box(hearth + Vector3(x, rim_y, 0), Vector3(0.3, 0.12, 1.06), W.vary(W.STONES[0], rng), W.STONE, _turn(rng, 0.03))
	# Lumps of charcoal over the glowing bed.
	for i in 16:
		var at := hearth + Vector3(rng.randf_range(-0.65, 0.65), rim_y + 0.02, rng.randf_range(-0.4, 0.4))
		var s := rng.randf_range(0.08, 0.16)
		b.box(at, Vector3(s, s * 0.7, s * 1.2), Color(0.09, 0.085, 0.08), W.STONE, _turn(rng, PI, 0.5))
	# The hood over the back of the hearth, narrowing into the chimney; both
	# blackened by soot higher up.
	var soot := Color(0.62, 0.6, 0.58)
	var back := hearth + Vector3(0, 0, -0.42)
	b.frustum(back + Vector3(0, rim_y + 0.12, 0), Vector2(1.7, 0.66), Vector2(0.92, 0.5), 0.9,
			W.STONES[3] * soot, W.STONE)
	stone_courses(b, back + Vector3(0, rim_y + 1.02, 0), Vector2(0.92, 0.56), 1.5, rng, 0.25, soot * 0.92)
	b.box(back + Vector3(0, rim_y + 2.52, 0), Vector3(1.1, 0.1, 0.74), W.STONES[2] * soot * 0.85, W.STONE, _turn(rng, 0.05))
	# A short lintel beam across the front of the hood.
	b.box(back + Vector3(0, rim_y + 0.98, 0.3), Vector3(1.2, 0.14, 0.14), W.TIMBER[3] * 0.75, W.WOOD)
	_bellows(b, hearth + Vector3(1.32, 0, -0.1), rng)
	_anvil(b, Vector3(0.8, 0, 0.8), 1.0, rng)
	_quench_tub(b, Vector3(-1.05, 0, 0.75), rng)
	# Iron bars waiting on the front of the rim, and tongs leaning on it.
	for i in 3:
		b.box(hearth + Vector3(-0.55 + i * 0.07, rim_y + 0.12, 0.66), Vector3(0.05, 0.05, 0.5), W.IRON_COLOUR, W.IRON, _turn(rng, 0.15))
	var tongs := hearth + Vector3(0.75, 0, 0.82)
	b.bar(tongs, tongs + Vector3(0.05, 0.86, -0.1), 0.018, W.IRON_COLOUR * 0.9, W.IRON, 4)
	b.bar(tongs + Vector3(0.08, 0, 0), tongs + Vector3(0.07, 0.86, -0.1), 0.018, W.IRON_COLOUR * 0.9, W.IRON, 4)
	b.finish(parent, pos)
	# The glowing bed of coals, just under the lumps.
	var coals := MeshInstance3D.new()
	var bed := BoxMesh.new()
	bed.size = Vector3(1.5, 0.06, 1.0)
	coals.mesh = bed
	coals.material_override = coals_material()
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coals.position = pos + hearth + Vector3(0, rim_y + 0.02, 0)
	parent.add_child(coals)
	return pos + hearth + Vector3(0, rim_y + 0.06, 0)


static func coals_material() -> StandardMaterial3D:
	var key := "coals"
	if not W._mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.06, 0.02)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.35, 0.08)
		m.emission_energy_multiplier = 1.8
		W._mats[key] = m
	return W._mats[key]


## A pair of bellows on a little trestle, its nozzle pointing into the hearth
## (towards -x).
static func _bellows(b: WeatheredProps.Builder, at: Vector3, rng: RandomNumberGenerator) -> void:
	for z in [-0.22, 0.22]:
		b.box(at + Vector3(0, 0, z), Vector3(0.1, 0.5, 0.08), W.vary(W.TIMBER[1], rng), W.WOOD)
	b.box(at + Vector3(0, 0.5, 0), Vector3(0.62, 0.06, 0.52), W.vary(W.TIMBER[0], rng), W.WOOD)
	# The leather, folded between the boards.
	b.frustum(at + Vector3(0.05, 0.56, 0), Vector2(0.58, 0.46), Vector2(0.5, 0.4), 0.14, Color(0.55, 0.44, 0.36), W.WOOD)
	b.box(at + Vector3(0.05, 0.7, 0), Vector3(0.62, 0.05, 0.48), W.vary(W.TIMBER[2], rng), W.WOOD, Basis(Vector3.BACK, 0.12))
	b.bar(at + Vector3(0.36, 0.73, 0), at + Vector3(0.58, 0.78, 0), 0.025, W.DARK_TIMBER, W.WOOD, 5)
	b.bar(at + Vector3(-0.25, 0.62, 0), at + Vector3(-0.48, 0.66, 0), 0.04, W.IRON_COLOUR, W.IRON, 6)


## An anvil on a stump, a hammer lying on its face. `s` scales it (1 at the
## forge, smaller on the fine metalwork bench, which has no stump).
static func _anvil(b: WeatheredProps.Builder, at: Vector3, s: float, rng: RandomNumberGenerator, stump := true) -> void:
	var y := 0.0
	if stump:
		b.cylinder(at, 0.36, 0.32, 0.55, W.DARK_TIMBER, W.WOOD, 9)
		# The light, cut top of the stump, and two roots.
		b.cylinder(at + Vector3(0, 0.55, 0), 0.31, 0.3, 0.015, W.TIMBER[2] * 1.2, W.WOOD, 9)
		for a in [0.6, 3.4]:
			var d := Vector3(cos(a), 0, sin(a))
			b.frustum(at + d * 0.33, Vector2(0.16, 0.12), Vector2(0.06, 0.06), 0.14, W.DARK_TIMBER, W.WOOD, Basis(Vector3.UP, -a))
		y = 0.565
	var iron := W.IRON_COLOUR * 0.85
	var o := at + Vector3(0, y, 0)
	b.frustum(o, Vector2(0.44, 0.34) * s, Vector2(0.26, 0.18) * s, 0.1 * s, iron, W.IRON)
	b.box(o + Vector3(0, 0.1, 0) * s, Vector3(0.2, 0.12, 0.15) * s, iron, W.IRON)
	b.frustum(o + Vector3(0, 0.22, 0) * s, Vector2(0.3, 0.16) * s, Vector2(0.6, 0.22) * s, 0.06 * s, iron, W.IRON)
	b.box(o + Vector3(0, 0.28, 0) * s, Vector3(0.62, 0.08, 0.22) * s, W.IRON_COLOUR, W.IRON)
	# The horn, a cone pointing along +x, and the square heel.
	b.cylinder(o + Vector3(0.3, 0.31, 0) * s, 0.065 * s, 0.008 * s, 0.3 * s, W.IRON_COLOUR, W.IRON, 8, Basis(Vector3.BACK, -PI * 0.5))
	b.box(o + Vector3(-0.38, 0.29, 0) * s, Vector3(0.14, 0.07, 0.16) * s, W.IRON_COLOUR, W.IRON)
	if s >= 1.0:
		var top := o + Vector3(-0.05, 0.36, 0)
		b.bar(top + Vector3(0, 0.02, -0.02), top + Vector3(0.05, 0.03, 0.34), 0.018, W.TIMBER[0], W.WOOD, 5)
		b.box(top + Vector3(-0.02, 0, -0.06), Vector3(0.16, 0.06, 0.06), W.IRON_COLOUR * 0.8, W.IRON, _turn(rng, 0.1))


## A half barrel of dark water for quenching hot iron.
static func _quench_tub(b: WeatheredProps.Builder, at: Vector3, rng: RandomNumberGenerator) -> void:
	b.cylinder(at, 0.32, 0.36, 0.52, W.vary(W.TIMBER[1], rng), W.WOOD, 12, Basis(), false)
	for y in [0.08, 0.4]:
		b.cylinder(at + Vector3(0, y, 0), 0.33 + y * 0.08 + 0.012, 0.335 + y * 0.08 + 0.012, 0.05, W.IRON_COLOUR * 0.8, W.IRON, 12, Basis(), false)
	b.cylinder(at, 0.33, 0.33, 0.02, W.DARK_TIMBER, W.WOOD, 12)
	# The water, dark, just below the rim.
	b.cylinder(at + Vector3(0, 0.44, 0), 0.34, 0.34, 0.01, Color(0.07, 0.08, 0.08), W.IRON, 12)


# --- The street lamp ------------------------------------------------------------

## A street lamp: a timber post on a stone foot, with an arm and a brace,
## and an iron lantern with glass panes hanging from the arm towards +z.
## `panes` glow at night (see Outdoor.set_hour).
static func build_lamp(parent: Node3D, pos: Vector3, panes: Material) -> void:
	var rng := _rng_at(pos, "lamp")
	var b := WeatheredProps.Builder.new()
	b.frustum(Vector3.ZERO, Vector2(0.56, 0.56), Vector2(0.42, 0.42), 0.28, W.vary(W.STONES[0], rng), W.STONE, _turn(rng, 0.2))
	b.box(Vector3(0, 0.28, 0), Vector3(0.17, 2.82, 0.17), W.vary(W.TIMBER[1], rng), W.WOOD, _turn(rng, 0.06))
	b.frustum(Vector3(0, 3.1, 0), Vector2(0.22, 0.22), Vector2(0.04, 0.04), 0.14, W.TIMBER[3], W.WOOD)
	# The arm and its brace.
	b.box(Vector3(0, 2.78, 0.6), Vector3(0.11, 0.12, 1.3), W.vary(W.TIMBER[0], rng), W.WOOD)
	b.bar(Vector3(0, 2.2, 0.06), Vector3(0, 2.76, 0.62), 0.04, W.TIMBER[3], W.WOOD, 5)
	# Iron: a strap round the post, the hook and a short chain.
	b.box(Vector3(0, 2.7, 0), Vector3(0.2, 0.05, 0.2), W.IRON_COLOUR, W.IRON)
	var lantern := LANTERN_AT
	b.bar(Vector3(0, 2.78, lantern.z), lantern + Vector3(0, 0.42, 0), 0.015, W.IRON_COLOUR, W.IRON, 4)
	# The lantern: a base plate, four corner posts, a peaked cap and a ring.
	var iron := W.IRON_COLOUR * 0.8
	b.frustum(lantern + Vector3(0, -0.26, 0), Vector2(0.18, 0.18), Vector2(0.3, 0.3), 0.06, iron, W.IRON)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		b.box(lantern + Vector3(corner.x * 0.13, -0.2, corner.y * 0.13), Vector3(0.03, 0.36, 0.03), iron, W.IRON)
	b.frustum(lantern + Vector3(0, 0.16, 0), Vector2(0.34, 0.34), Vector2(0.06, 0.06), 0.18, iron, W.IRON)
	b.cylinder(lantern + Vector3(0, 0.34, 0), 0.04, 0.04, 0.05, iron, W.IRON, 6)
	b.finish(parent, pos)
	# The glass, one thin box inside the frame: it glows at night.
	var glass := MeshInstance3D.new()
	var pane := BoxMesh.new()
	pane.size = Vector3(0.24, 0.34, 0.24)
	glass.mesh = pane
	glass.material_override = panes
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = pos + lantern - Vector3(0, 0.03, 0)
	parent.add_child(glass)


# --- The food pedestal ----------------------------------------------------------

## A tall pedestal of hewn stone (`height` metres, its top flat at that
## height): a stepped plinth, an eight-sided shaft and a stepped capital, with
## a few chips of stone fallen at its foot.
static func build_pedestal(parent: Node3D, pos: Vector3, height: float) -> void:
	var rng := _rng_at(pos, "pedestal")
	var b := WeatheredProps.Builder.new()
	var stone: Color = W.STONES[0]
	b.frustum(Vector3.ZERO, Vector2(1.8, 1.8), Vector2(1.74, 1.74), 0.18, W.vary(stone, rng), W.STONE, _turn(rng, 0.03))
	b.frustum(Vector3(0, 0.18, 0), Vector2(1.5, 1.5), Vector2(1.42, 1.42), 0.16, W.vary(stone, rng), W.STONE, _turn(rng, 0.03))
	var shaft := height - 0.34 - 0.36
	b.cylinder(Vector3(0, 0.34, 0), 0.62, 0.56, shaft, W.vary(W.STONES[2], rng, 0.04), W.STONE, 8, Basis(Vector3.UP, PI / 8.0))
	# Rings where the shaft was set, one drum on another.
	for k in [0.33, 0.66]:
		b.cylinder(Vector3(0, 0.34 + shaft * k, 0), 0.64 - 0.06 * k, 0.64 - 0.06 * k, 0.05, W.STONES[3], W.STONE, 8, Basis(Vector3.UP, PI / 8.0))
	b.frustum(Vector3(0, height - 0.36, 0), Vector2(1.2, 1.2), Vector2(1.5, 1.5), 0.14, W.vary(stone, rng), W.STONE)
	b.box(Vector3(0, height - 0.22, 0), Vector3(1.72, 0.22, 1.72), W.vary(stone, rng), W.STONE, _turn(rng, 0.02))
	for i in 4:
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.0, 1.25)
		var s := rng.randf_range(0.1, 0.2)
		b.box(Vector3(cos(a) * d, 0, sin(a) * d), Vector3(s, s * 0.6, s * 0.8), W.vary(stone, rng), W.STONE, _turn(rng, PI, 0.3))
	b.finish(parent, pos)


# --- The workbenches ------------------------------------------------------------

## A heavy, old workbench (`at`: the middle of its foot): a top of four
## boards along z, sturdy legs, side rails, a shelf of boards low down and a
## rail along the back (-x).
static func build_workbench(b: WeatheredProps.Builder, at: Vector3, rng: RandomNumberGenerator) -> void:
	var boards := 4
	var width := 1.3 / boards
	for i in boards:
		var x := -0.65 + width * (i + 0.5)
		b.box(at + Vector3(x, 0.9 + rng.randf_range(-0.008, 0.008), rng.randf_range(-0.03, 0.03)),
				Vector3(width - 0.015, 0.08, 2.6 + rng.randf_range(-0.04, 0.04)),
				W.vary(W.TIMBER[rng.randi() % W.TIMBER.size()], rng, 0.1), W.WOOD, _turn(rng, 0.004))
	for z in [-1.1, 1.1]:
		b.box(at + Vector3(0, 0.82, z), Vector3(1.2, 0.08, 0.12), W.DARK_TIMBER, W.WOOD)
		for x in [-0.53, 0.53]:
			b.box(at + Vector3(x, 0, z), Vector3(0.15, 0.82, 0.15), W.vary(W.DARK_TIMBER, rng), W.WOOD, _turn(rng, 0.05))
	for x in [-0.53, 0.53]:
		b.box(at + Vector3(x, 0.24, 0), Vector3(0.07, 0.1, 2.2), W.DARK_TIMBER, W.WOOD)
	for i in 3:
		b.box(at + Vector3(-0.36 + i * 0.36, 0.2, 0), Vector3(0.34, 0.04, 2.2), W.vary(W.TIMBER[3], rng), W.WOOD, _turn(rng, 0.01))
	b.box(at + Vector3(-0.56, 0.56, 0), Vector3(0.07, 0.1, 2.2), W.DARK_TIMBER, W.WOOD)


## The small anvil and a hearth of bricks for the fine metalwork bench.
static func dress_metalwork(b: WeatheredProps.Builder, top: Vector3, rng: RandomNumberGenerator) -> void:
	_anvil(b, top + Vector3(0.1, 0, -0.6), 0.55, rng, false)
	# A little hearth of rough bricks under the crucible.
	var brick := Color(0.74, 0.56, 0.48)
	for k in 3:
		for i in 2:
			var along := k % 2 == 0
			var off := Vector3(0, k * 0.08, -0.12 + i * 0.24) if along else Vector3(-0.12 + i * 0.24, k * 0.08, 0)
			var size := Vector3(0.5, 0.075, 0.22) if along else Vector3(0.22, 0.075, 0.5)
			b.box(top + Vector3(-0.1, 0, 0.65) + off, size, W.vary(brick, rng, 0.12), W.WOOD, _turn(rng, 0.05))
	b.cylinder(top + Vector3(-0.1, 0.24, 0.65), 0.09, 0.13, 0.16, Color(0.66, 0.62, 0.58), W.STONE, 10)


## The grinding wheel's frame, axle, stone wheel and crank.
static func dress_gem_wheel(b: WeatheredProps.Builder, top: Vector3, rng: RandomNumberGenerator) -> void:
	for z in [-0.75, -0.25]:
		b.box(top + Vector3(0, 0, z), Vector3(0.1, 0.52, 0.1), W.vary(W.DARK_TIMBER, rng), W.WOOD)
	b.box(top + Vector3(0, 0, -0.5), Vector3(0.34, 0.06, 0.66), W.DARK_TIMBER, W.WOOD)
	var turned := Basis(Vector3.RIGHT, PI * 0.5)
	b.cylinder(top + Vector3(0, 0.48, -0.85), 0.03, 0.03, 0.75, W.IRON_COLOUR, W.IRON, 6, turned)
	b.cylinder(top + Vector3(0, 0.48, -0.55), 0.4, 0.4, 0.1, Color(0.8, 0.78, 0.75), W.STONE, 18, turned)
	b.box(top + Vector3(0.12, 0.46, -0.08), Vector3(0.24, 0.04, 0.04), W.IRON_COLOUR, W.IRON)
	b.bar(top + Vector3(0.22, 0.46, -0.08), top + Vector3(0.22, 0.46, 0.04), 0.02, W.TIMBER[2], W.WOOD, 5)


## The cauldron on three legs over a few logs, and the mortar on the bench.
static func dress_alchemy(b: WeatheredProps.Builder, top: Vector3, cauldron: Vector3, rng: RandomNumberGenerator) -> void:
	b.cylinder(top + Vector3(0.1, 0, 0.35), 0.09, 0.13, 0.14, Color(0.78, 0.76, 0.72), W.STONE, 10)
	b.bar(top + Vector3(0.1, 0.08, 0.35), top + Vector3(0.2, 0.24, 0.3), 0.022, Color(0.74, 0.72, 0.69), W.STONE, 5)
	# The book of recipes: leather covers, pale pages.
	b.box(top + Vector3(0.0, 0, 0.85), Vector3(0.42, 0.03, 0.58), Color(0.6, 0.46, 0.36), W.WOOD, Basis(Vector3.UP, 0.1))
	b.box(top + Vector3(0.0, 0.03, 0.85), Vector3(0.39, 0.03, 0.54), Color(0.88, 0.82, 0.66), W.WOOD, Basis(Vector3.UP, 0.1))
	var iron := Color(0.5, 0.51, 0.53)
	for i in 3:
		var a := i * TAU / 3.0 + 0.3
		b.bar(cauldron + Vector3(cos(a) * 0.36, 0, sin(a) * 0.36), cauldron + Vector3(cos(a) * 0.28, 0.4, sin(a) * 0.28), 0.03, iron, W.IRON, 5)
	b.cylinder(cauldron + Vector3(0, 0.25, 0), 0.26, 0.4, 0.24, iron, W.IRON, 14)
	b.cylinder(cauldron + Vector3(0, 0.49, 0), 0.4, 0.42, 0.28, iron, W.IRON, 14, Basis(), false)
	b.cylinder(cauldron + Vector3(0, 0.75, 0), 0.45, 0.45, 0.05, iron, W.IRON, 14, Basis(), false)
	for i in 3:
		var a := i * TAU / 3.0 + rng.randf_range(-0.2, 0.2)
		var d := Vector3(cos(a), 0, sin(a))
		b.bar(cauldron - d * 0.45 + Vector3(0, 0.06, 0), cauldron + d * 0.45 + Vector3(0, 0.06, 0), 0.06, W.vary(W.TIMBER[1], rng), W.WOOD, 6)


# --- The holes in the ground ----------------------------------------------------

## The torn-up rim of a dark hole in the ground (see Outdoor._build_hole): a
## ragged lip of heaped earth round the opening, its inner side falling away
## into the dark, and a few roots hanging into it. The black of the hole
## itself is drawn by the caller, `opening` metres across, just above the
## ground.
static func build_hole_rim(parent: Node3D, pos: Vector3, opening: float) -> void:
	var rng := _rng_at(pos, "hole")
	var b := WeatheredProps.Builder.new()
	const SEGMENTS := 28
	# The profile from the dark inside out: [radius, height, colour].
	# Strong in colour, so the weathering reads them as earth (the mesh is
	# FRESH), not as boards.
	var deep := Color(0.08, 0.055, 0.03)
	var earth := Color(0.32, 0.23, 0.12)
	var crest := Color(0.5, 0.38, 0.2)
	var turf := Color(0.44, 0.39, 0.18)
	var profile := [[opening, 0.035, deep], [opening + 0.06, 0.16, deep], [opening + 0.12, 0.27, earth],
			[opening + 0.26, 0.36, crest], [opening + 0.55, 0.3, crest], [opening + 1.05, 0.0, turf]]
	# The lip rises and falls smoothly round the hole.
	var phase := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var rings: Array = []
	var normals: Array = []
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var wobble := 1.0 + 0.06 * sin(a * 3.0 + phase[0]) + 0.04 * sin(a * 5.0 + phase[1])
		var lift := 1.0 + 0.25 * sin(a * 2.0 + phase[2]) + 0.1 * sin(a * 7.0 + phase[0])
		var dir := Vector3(cos(a), 0, sin(a))
		var ring: Array[Vector3] = []
		for k in profile.size():
			var r: float = profile[k][0] * (1.0 if k == 0 else wobble)
			var h: float = profile[k][1] * (1.0 if k == 0 or k == profile.size() - 1 else lift)
			ring.append(dir * r + Vector3(0, h, 0))
		rings.append(ring)
		# Smooth normals across the profile, turned up and away from the slope.
		var around := dir.cross(Vector3.UP)
		var ns: Array[Vector3] = []
		for k in profile.size():
			var slope: Vector3 = ring[mini(k + 1, profile.size() - 1)] - ring[maxi(k - 1, 0)]
			var n := slope.cross(around).normalized()
			ns.append(n if n.y >= 0.0 else -n)
		normals.append(ns)
	for i in SEGMENTS:
		var j := (i + 1) % SEGMENTS
		for k in profile.size() - 1:
			var colour: Color = profile[k + 1][2] if k > 1 else deep
			b.quad_smooth(rings[i][k], rings[j][k], rings[j][k + 1], rings[i][k + 1],
					normals[i][k], normals[j][k], normals[j][k + 1], normals[i][k + 1], colour, W.FRESH)
	# Roots hanging into the dark.
	for i in 5:
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var from := dir * (opening + 0.12) + Vector3(0, 0.2, 0)
		var to := dir * (opening - rng.randf_range(0.3, 0.6)) + Vector3(0, rng.randf_range(-0.05, 0.08), 0) + dir.cross(Vector3.UP) * rng.randf_range(-0.3, 0.3)
		b.bar(from, to, rng.randf_range(0.02, 0.045), W.vary(W.DARK_TIMBER * 0.8, rng), W.WOOD, 5)
	b.finish(parent, pos, true, true)
