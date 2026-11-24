class_name RiverBridge
extends RefCounted
## The plank bridge over the river of the farming valley (map letter "‖"): the road from the village runs
## over it to the farmers' settlement. One tile at a time, a deck of weathered planks laid across the way
## (north to south) and rails along the sides where no other bridge tile lies beside it. The tiles stay
## walkable and the river tiles beside them are solid, so the rails only need to look the part. The ground
## draws water beneath the deck (see Outdoor._build_ground).

const W := preload("res://scripts/weathered_props.gd")
const PLANKS := 8
const DECK := 0.08
const RAIL_POST := 1.05


static func is_bridge(lvl: Outdoor, c: Vector2i) -> bool:
	return lvl.cell_char(c) == "‖"


## How far (metres) the deck runs on past the last bridge tile onto dry land, so it lands on the bank
## even where the soft shore of the ground picture draws water or ice a little beyond the tile.
const LANDING := 2.0


static func build(lvl: Outdoor, c: Vector2i) -> void:
	var pos := lvl.cell_to_world(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lvl.level_name + "bruecke") + c.x * 131 + c.y * 7919
	var b := WeatheredProps.Builder.new()
	var half := Outdoor.TILE * 0.5
	var step := Outdoor.TILE / PLANKS
	# The deck lands on the bank: it runs on past its end tiles, but not into the next tile of the river.
	var land_n := 0.0 if _continues(lvl, c + Vector2i(0, -1)) else LANDING
	var land_s := 0.0 if _continues(lvl, c + Vector2i(0, 1)) else LANDING
	var z0 := -half - land_n
	var z1 := half + land_s
	var planks := int(round((z1 - z0) / step))
	var pstep := (z1 - z0) / planks
	# Planks reach right across a seam to the next bridge tile, so no gap shows between the halves.
	var west := is_bridge(lvl, c + Vector2i(-1, 0))
	var east := is_bridge(lvl, c + Vector2i(1, 0))
	var x0 := -half - (0.06 if west else -0.05)
	var x1 := half + (0.06 if east else -0.05)
	# Beams under the deck, the planks across them.
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * (half - 0.55), 0.0, (z0 + z1) * 0.5), Vector3(0.22, 0.06, z1 - z0), W.vary(W.DARK_TIMBER, rng, 0.05), W.WOOD)
	b.box(Vector3(0, 0.0, (z0 + z1) * 0.5), Vector3(0.22, 0.06, z1 - z0), W.vary(W.DARK_TIMBER, rng, 0.05), W.WOOD)
	for i in planks:
		var z := z0 + pstep * (i + 0.5)
		var lift := rng.randf_range(0.0, 0.012)
		var a := x0 + (0.0 if west else rng.randf_range(0.0, 0.15))
		var e := x1 - (0.0 if east else rng.randf_range(0.0, 0.15))
		b.box(Vector3((a + e) * 0.5, 0.03 + lift, z), Vector3(e - a, DECK - 0.03, pstep - 0.045),
				W.vary(W.TIMBER[rng.randi() % W.TIMBER.size()], rng, 0.09), W.WOOD,
				Basis.from_euler(Vector3(0, rng.randf_range(-0.012, 0.012), 0)))
	# Rails on the open sides.
	var posts := [z0 + 0.2, (z0 + z1) * 0.5, z1 - 0.2]
	for side in [-1, 1]:
		if is_bridge(lvl, c + Vector2i(side, 0)):
			continue
		var x: float = side * (half - 0.18)
		for z in posts:
			b.box(Vector3(x, 0.0, z), Vector3(0.18, RAIL_POST, 0.18), W.vary(W.TIMBER[1], rng, 0.08), W.WOOD,
					Basis.from_euler(Vector3(0, rng.randf_range(-0.2, 0.2), rng.randf_range(-0.02, 0.02))))
		for h in [0.5, RAIL_POST - 0.1]:
			b.box(Vector3(x, h, (z0 + z1) * 0.5), Vector3(0.1, 0.1, z1 - z0), W.vary(W.TIMBER[rng.randi() % W.TIMBER.size()], rng, 0.07), W.WOOD)
	b.finish(lvl, pos)


## Whether the deck goes on over this tile (another bridge tile, or open river it still has to cross).
static func _continues(lvl: Outdoor, c: Vector2i) -> bool:
	return "‖≈~;".contains(lvl.cell_char(c))
