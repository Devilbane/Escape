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
## Posts and rails of the fence: height of the posts and of the top rail.
const POST_HEIGHT := 1.25
const RAIL_HEIGHT := 0.95


## Whether a tile is part of the fence line (a post, or the gate).
static func is_fence(ch: String) -> bool:
	return ch == FENCE or ch == GATE


## Whether this map has the pen (a map redrawn in the workshop may not).
static func present(lvl: Outdoor) -> bool:
	return lvl.cell_char(PEN.position + Vector2i(0, -1)) == FENCE and lvl.cell_char(PEN.position + Vector2i(1, -1)) == GATE


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
