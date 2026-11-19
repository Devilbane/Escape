class_name Corral
extends RefCounted
## The cattle pen on the village's east meadow (see VillageFarm): a wooden
## fence of posts and rails round the grass where the two cows and the bull
## live, one gate on its north side, a water trough, a pile of hay and a
## bucket inside. The fence is a letter of the village map (FENCE, one tile
## each, solid for the hero and not walkable for the villagers and animals);
## the gate (GATE) is a walkable tile. The herd never leaves the pen: its
## animals pick their spots only inside PEN (see FarmAnimal.pen).

const W := preload("res://scripts/weathered_props.gd")

## The letters on the map.
const FENCE := "§"
const GATE := "¤"
## The grass inside the fence, in tiles of the village map.
const PEN := Rect2i(57, 25, 5, 4)
## The open shelter in the pen's north-east corner: a roof on posts over a straw floor, with a
## trough along its back. The cattle lie down here when it rains or snows, and at night.
const SHELTER := Rect2i(60, 25, 2, 1)
## Resting places under the roof, as x offsets from its middle (one each for the cows and the bull).
const REST_X := [-2.5, 0.0, 2.5]
const REST_Z := 0.45
## Posts and rails of the fence: height of the posts and of the top rail.
const POST_HEIGHT := 1.25
const RAIL_HEIGHT := 0.95


## Whether a tile is part of the fence line (a post, or the gate).
static func is_fence(ch: String) -> bool:
	return ch == FENCE or ch == GATE


## Whether this map has the pen (a map redrawn in the workshop may not).
static func present(lvl: Outdoor) -> bool:
	return lvl.cell_char(PEN.position + Vector2i(0, -1)) == FENCE and lvl.cell_char(PEN.position + Vector2i(1, -1)) == GATE


## Whether the pen's shelter stands on this map.
static func has_shelter(lvl: Outdoor) -> bool:
	if not present(lvl):
		return false
	for y in range(SHELTER.position.y, SHELTER.end.y):
		for x in range(SHELTER.position.x, SHELTER.end.x):
			if lvl.cell_char(Vector2i(x, y)) != ".":
				return false
	return true


## The middle of the shelter's floor.
static func shelter_middle(lvl: Outdoor) -> Vector3:
	var a := lvl.cell_to_world(SHELTER.position)
	var b := lvl.cell_to_world(SHELTER.end - Vector2i.ONE)
	return (a + b) * 0.5


## Where the animal of this slot (0 to 2) lies down under the roof.
static func rest_spot(lvl: Outdoor, slot: int) -> Vector3:
	return shelter_middle(lvl) + Vector3(REST_X[clampi(slot, 0, REST_X.size() - 1)], 0.0, REST_Z)


## Whether the weather or the hour sends the cattle under the roof.
static func wants_shelter(lvl: Outdoor) -> bool:
	return lvl.night or [Weather.RAIN, Weather.STORM, Weather.SNOW].has(lvl.weather)


static func _rng_at(pos: Vector3, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [salt, roundi(pos.x * 10.0), roundi(pos.z * 10.0)])
	return rng


## One tile of fence: a post in its middle and two rails towards each
## neighbouring piece of fence. Solid where it is drawn.
static func build_fence(lvl: Outdoor, c: Vector2i) -> void:
	var pos := lvl.cell_to_world(c)
	var rng := _rng_at(pos, "corral")
	var b := WeatheredProps.Builder.new()
	_post(b, Vector3.ZERO, rng)
	var half := Outdoor.TILE * 0.5
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not is_fence(lvl.cell_char(c + dir)):
			continue
		var d := Vector3(dir.x, 0, dir.y)
		var along_x: bool = dir.y == 0
		for h in [POST_HEIGHT * 0.32, POST_HEIGHT * 0.62, POST_HEIGHT * 0.92]:
			var size := Vector3(half, 0.17, 0.1) if along_x else Vector3(0.1, 0.17, half)
			b.box(d * half * 0.5 + Vector3(0, h - 0.055 + rng.randf_range(-0.015, 0.015), 0), size, W.vary(W.TIMBER[rng.randi() % W.TIMBER.size()], rng, 0.08), W.WOOD)
		lvl._add_solid(pos + d * half * 0.5, Vector3(half, 1.3, 0.35) if along_x else Vector3(0.35, 1.3, half))
	lvl._add_solid(pos, Vector3(0.45, 1.5, 0.45))
	b.finish(lvl, pos)


## The gate: two tall posts either side of the opening and a leaf swung open
## against the fence. The tile stays walkable (the hero walks in); the animals
## are kept in by their pen, not by the gate.
static func build_gate(lvl: Outdoor, c: Vector2i) -> void:
	var pos := lvl.cell_to_world(c)
	var rng := _rng_at(pos, "corral_gate")
	var across := is_fence(lvl.cell_char(c + Vector2i(1, 0))) or is_fence(lvl.cell_char(c + Vector2i(-1, 0)))
	var turn := 0.0 if across else PI * 0.5
	var basis := Basis(Vector3.UP, turn)
	var b := WeatheredProps.Builder.new()
	var half := Outdoor.TILE * 0.5
	for side in [-1.0, 1.0]:
		_post(b, basis * Vector3(side * (half - 0.2), 0, 0), rng, 0.3)
	# The leaf, opened inwards along the fence: three boards and a brace.
	var hinge := basis * Vector3(-(half - 0.2), 0, 0.45)
	for h in [0.3, 0.65, 1.0]:
		var a := hinge + Vector3(0, h, 0)
		var z := basis * Vector3(0.0, 0, 1.7)
		b.bar(a, a + z, 0.07, W.vary(W.TIMBER[rng.randi() % W.TIMBER.size()], rng, 0.08), W.WOOD, 5)
	b.bar(hinge + Vector3(0, 0.3, 0), hinge + basis * Vector3(0, 0, 1.7) + Vector3(0, 1.0, 0), 0.04, W.TIMBER[3], W.WOOD, 5)
	b.finish(lvl, pos)
	for side in [-1.0, 1.0]:
		lvl._add_solid(pos + basis * Vector3(side * (half - 0.2), 0, 0), Vector3(0.5, 1.6, 0.5))


static func _post(b: WeatheredProps.Builder, at: Vector3, rng: RandomNumberGenerator, extra := 0.0) -> void:
	var height := POST_HEIGHT + extra
	b.box(at, Vector3(0.28, height, 0.28), W.vary(W.TIMBER[1], rng, 0.08), W.WOOD, Basis.from_euler(Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.03, 0.03))))
	b.frustum(at + Vector3(0, height, 0), Vector2(0.34, 0.34), Vector2(0.14, 0.14), 0.1, W.TIMBER[3], W.WOOD)


## What stands inside, along the south side where the guild's wall is (the
## herd never stands there, see VillageFarm): a long trough, a heap of hay
## bales and a bucket, so the grass stays free.
static func build_props(lvl: Outdoor) -> void:
	var south := PEN.end.y - 1
	var trough_at := lvl.cell_to_world(Vector2i(PEN.position.x + 1, south))
	var rng := _rng_at(trough_at, "trough")
	var b := WeatheredProps.Builder.new()
	b.box(Vector3(-1.3, 0.0, -0.35), Vector3(2.6, 0.5, 0.7), W.vary(W.TIMBER[1], rng, 0.06), W.WOOD)
	b.box(Vector3(-1.2, 0.5, -0.25), Vector3(2.4, 0.04, 0.5), Color(0.2, 0.3, 0.38), W.FRESH)
	for x in [-1.2, 1.2]:
		b.box(Vector3(x - 0.07, 0.0, -0.38), Vector3(0.14, 0.62, 0.76), W.DARK_TIMBER, W.WOOD)
	b.finish(lvl, trough_at)
	lvl._add_solid(trough_at, Vector3(2.8, 0.6, 0.9))
	# Hay: low bales with a loose heap and a few straws on the ground.
	var hay_at := lvl.cell_to_world(Vector2i(PEN.position.x + 3, south))
	var hay := WeatheredProps.Builder.new()
	var straw := Color(0.82, 0.68, 0.34)
	hay.box(Vector3(-1.5, 0, -0.35), Vector3(1.1, 0.55, 0.7), W.vary(straw, rng, 0.08), W.FRESH, Basis(Vector3.UP, 0.08))
	hay.box(Vector3(-0.3, 0, -0.3), Vector3(1.1, 0.55, 0.7), W.vary(straw, rng, 0.08), W.FRESH, Basis(Vector3.UP, -0.05))
	hay.box(Vector3(-0.9, 0.55, -0.3), Vector3(1.0, 0.5, 0.65), W.vary(straw, rng, 0.08), W.FRESH, Basis(Vector3.UP, 0.2))
	hay.frustum(Vector3(1.0, 0, -0.1), Vector2(0.9, 0.9), Vector2(0.2, 0.2), 0.7, W.vary(straw, rng, 0.1), W.FRESH)
	for k in 6:
		var a := rng.randf() * TAU
		hay.box(Vector3(cos(a) * 1.6, 0, sin(a) * 0.8), Vector3(0.4, 0.04, 0.12), W.vary(straw, rng, 0.1), W.FRESH, Basis(Vector3.UP, a))
	hay.finish(lvl, hay_at)
	lvl._add_solid(hay_at + Vector3(-0.2, 0, -0.1), Vector3(3.0, 1.0, 1.0))
	lvl._put("bucket_water", lvl.cell_to_world(Vector2i(PEN.position.x + 2, south)) + Vector3(1.0, 0, 1.0), 0.6, Outdoor.PROP_SCALE * 0.5)


## The thatch of the shelter's roof in `roof`: courses of straw bundles from the eaves up, each lying
## a little higher than the one below and fraying at its lower edge, then loose strands along the
## slope and a roll of straw over the ridge. `at` and `slope` place the roof's middle and its tilt.
static func _thatch(roof: WeatheredProps.Builder, at: Vector3, slope: Basis, width: float, length: float, rng: RandomNumberGenerator) -> void:
	var straw := Color(0.76, 0.62, 0.32)
	var courses := 6
	var step := length / courses
	for i in courses:
		var z := length * 0.5 - step * (i + 0.2)
		var raise := 0.1 + 0.045 * i
		var x := -width * 0.5 - 0.1
		while x < width * 0.5 + 0.1:
			var w := rng.randf_range(0.35, 0.65)
			var ragged := rng.randf_range(-0.14, 0.2) if i == 0 else rng.randf_range(-0.05, 0.1)
			var local := Vector3(x + w * 0.5, raise, z + ragged * 0.5)
			var bundle := Basis(Vector3.UP, rng.randf_range(-0.07, 0.07)) * Basis(Vector3.RIGHT, rng.randf_range(-0.04, 0.04))
			roof.box(at + slope * local, Vector3(w + 0.03, 0.16, step * 1.5 + ragged), W.vary(straw, rng, 0.1), W.FRESH, slope * bundle)
			x += w
	# Hanging fringe along the eaves.
	var x2 := -width * 0.5
	while x2 < width * 0.5:
		var local2 := Vector3(x2, 0.1, length * 0.5 + 0.05)
		roof.box(at + slope * local2, Vector3(rng.randf_range(0.08, 0.2), 0.1, rng.randf_range(0.2, 0.45)), W.vary(straw, rng, 0.12), W.FRESH, slope * Basis(Vector3.RIGHT, rng.randf_range(0.2, 0.7)))
		x2 += rng.randf_range(0.1, 0.28)
	# Loose strands that run down the slope.
	for k in 360:
		var local3 := Vector3(rng.randf_range(-width * 0.5, width * 0.5), 0.1 + 0.045 * courses * rng.randf() + 0.1, rng.randf_range(-length * 0.5, length * 0.5))
		var c := W.vary(straw.lerp(Color(0.92, 0.8, 0.45), rng.randf()), rng, 0.1)
		roof.box(at + slope * local3, Vector3(0.035, 0.02, rng.randf_range(0.4, 0.9)), c, W.FRESH, slope * Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)))
	# The ridge: a thick roll along the top edge.
	var ridge := at + slope * Vector3(0, 0.3, -length * 0.5 + 0.1)
	roof.cylinder(ridge - Vector3(width * 0.5 + 0.1, 0, 0), 0.22, 0.2, width + 0.2, W.vary(straw, rng, 0.05), W.FRESH, 8, Basis(Vector3.BACK, -PI / 2.0))


## Gives the roof its snow caps (see SnowCaps): built from one stand-in slab, so the many bundles
## of the thatch need not be searched.
static func _snow_on_roof(lvl: Outdoor, at: Vector3, roof_at: Vector3, slope: Basis, width: float, length: float) -> void:
	var top := 0.5
	var corners: Array[Vector3] = []
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		corners.append(lvl.global_position + at + roof_at + slope * Vector3(c.x * width * 0.5, top, c.y * length * 0.5))
	var n := (slope * Vector3.UP).normalized()
	var tris: Array = []
	for t in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = corners[t[0]]
		var b: Vector3 = corners[t[1]]
		var c: Vector3 = corners[t[2]]
		tris.append({"a": a, "b": b, "c": c, "n": n, "area": (b - a).cross(c - a).length() * 0.5})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shelter snow")
	var caps := SnowCaps.build(tris, lvl.global_position.y, [], rng, -lvl.global_position, 0.6)
	var node := SnowCaps.node_for(caps)
	if node:
		lvl.add_child(node)


## The shelter: four posts, a back wall of boards, a thatched roof sloping to the front, a floor of
## straw and a long trough along the back. Open to the pen on the south side and to both ends.
static func build_shelter(lvl: Outdoor) -> void:
	var at := shelter_middle(lvl)
	var rng := _rng_at(at, "shelter")
	var b := WeatheredProps.Builder.new()
	var half_x := Outdoor.TILE * SHELTER.size.x * 0.5 - 0.3
	var back := -Outdoor.TILE * SHELTER.size.y * 0.5 + 0.3
	var front := Outdoor.TILE * SHELTER.size.y * 0.5 - 0.3
	var back_top := 3.1
	var front_top := 2.5
	var tilt := atan2(back_top - front_top, front - back)
	# Posts: the back ones taller, so the roof runs off to the front.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * half_x, 0, back), Vector3(0.3, back_top, 0.3), W.vary(W.TIMBER[1], rng, 0.08), W.WOOD)
		b.box(Vector3(sx * half_x, 0, front), Vector3(0.3, front_top, 0.3), W.vary(W.TIMBER[1], rng, 0.08), W.WOOD)
	# Beams along the top of the posts, and a back wall of three boards.
	b.box(Vector3(0, back_top - 0.25, back), Vector3(half_x * 2.0, 0.22, 0.2), W.DARK_TIMBER, W.WOOD)
	b.box(Vector3(0, front_top - 0.25, front), Vector3(half_x * 2.0, 0.22, 0.2), W.DARK_TIMBER, W.WOOD)
	for h in [0.2, 0.85, 1.5, 2.15]:
		b.box(Vector3(0, h, back - 0.12), Vector3(half_x * 2.0, 0.55, 0.1), W.vary(W.TIMBER[rng.randi() % W.TIMBER.size()], rng, 0.08), W.WOOD)
	# The roof: planks under a thatch of overlapping courses of straw bundles (see _thatch).
	var slope := Basis(Vector3.RIGHT, tilt)
	var middle_z := (back + front) * 0.5
	var roof_at := Vector3(0, (back_top + front_top) * 0.5 - 0.06, middle_z)
	var roof_w := Outdoor.TILE * SHELTER.size.x
	var roof_l := front - back + 1.0
	b.box(roof_at, Vector3(roof_w - 0.1, 0.16, roof_l), W.vary(W.TIMBER[3], rng, 0.06), W.WOOD, slope)
	var thatch := Color(0.74, 0.6, 0.3)
	var roof := WeatheredProps.Builder.new()
	_thatch(roof, roof_at, slope, roof_w, roof_l, rng)
	var roof_mesh := roof.finish(lvl, at)
	# Snow lies on it as real caps (SnowCaps), not as the flat white the overlay paints.
	roof_mesh.set_meta("no_snow", true)
	_snow_on_roof(lvl, at, roof_at, slope, roof_w, roof_l)
	# The floor: a thick mat of straw, its edge frayed over the grass, with loose strands on top.
	var fw := roof_w - 0.1
	var fd := Outdoor.TILE * SHELTER.size.y - 0.1
	b.box(Vector3(0, 0, 0), Vector3(fw, 0.05, fd), W.vary(thatch, rng, 0.05), W.FRESH)
	for k in 420:
		var p := Vector3(rng.randf_range(-fw * 0.5 - 0.2, fw * 0.5 + 0.2), 0.05 + rng.randf() * 0.06, rng.randf_range(-fd * 0.5 - 0.2, fd * 0.5 + 0.2))
		var c := W.vary(thatch.lerp(Color(0.9, 0.78, 0.42), rng.randf() * 0.7), rng, 0.1)
		b.box(p, Vector3(rng.randf_range(0.5, 1.3), 0.018, 0.045), c, W.FRESH, Basis(Vector3.UP, rng.randf() * TAU))
	for x in [-3.2, 3.1]:
		b.frustum(Vector3(x, 0.06, back + 0.7), Vector2(1.0, 0.8), Vector2(0.3, 0.3), 0.4, W.vary(thatch, rng, 0.08), W.FRESH, Basis(Vector3.UP, rng.randf() * TAU))
	# The trough along the back: water at one end, hay in the rest.
	var trough_z := back + 0.45
	b.box(Vector3(0.3, 0, trough_z), Vector3(5.2, 0.55, 0.62), W.vary(W.TIMBER[1], rng, 0.06), W.WOOD)
	b.box(Vector3(-1.2, 0.55, trough_z), Vector3(1.8, 0.03, 0.42), Color(0.2, 0.3, 0.38), W.FRESH)
	b.box(Vector3(1.3, 0.55, trough_z), Vector3(3.0, 0.14, 0.42), W.vary(thatch, rng, 0.08), W.FRESH)
	for x in [-2.2, 2.8]:
		b.box(Vector3(x, 0, trough_z), Vector3(0.16, 0.66, 0.7), W.DARK_TIMBER, W.WOOD)
	b.finish(lvl, at)
	for sx in [-1.0, 1.0]:
		lvl._add_solid(at + Vector3(sx * half_x, 0, back), Vector3(0.45, back_top, 0.45))
		lvl._add_solid(at + Vector3(sx * half_x, 0, front), Vector3(0.45, front_top, 0.45))
	lvl._add_solid(at + Vector3(0, 0, back + 0.2), Vector3(half_x * 2.0, 1.4, 0.9))
