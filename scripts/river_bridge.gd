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


static func build(lvl: Outdoor, c: Vector2i) -> void:
	var pos := lvl.cell_to_world(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lvl.level_name + "bruecke") + c.x * 131 + c.y * 7919
	var b := WeatheredProps.Builder.new()
	var half := Outdoor.TILE * 0.5
	var step := Outdoor.TILE / PLANKS
	# Two beams under the deck, the planks across them.
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * (half - 0.55), 0.0, 0.0), Vector3(0.22, 0.06, Outdoor.TILE), W.vary(W.DARK_TIMBER, rng, 0.05), W.WOOD)
	for i in PLANKS:
		var z := -half + step * (i + 0.5)
		var lift := rng.randf_range(0.0, 0.012)
		b.box(Vector3(0, 0.03 + lift, z), Vector3(Outdoor.TILE - 0.1 - rng.randf_range(0.0, 0.2), DECK - 0.03, step - 0.045),
				W.vary(W.TIMBER[rng.randi() % W.TIMBER.size()], rng, 0.09), W.WOOD,
				Basis.from_euler(Vector3(0, rng.randf_range(-0.012, 0.012), 0)))
	# Rails on the open sides.
	for side in [-1, 1]:
		if is_bridge(lvl, c + Vector2i(side, 0)):
			continue
		var x: float = side * (half - 0.18)
		for z in [-half + 0.2, 0.0, half - 0.2]:
			b.box(Vector3(x, 0.0, z), Vector3(0.18, RAIL_POST, 0.18), W.vary(W.TIMBER[1], rng, 0.08), W.WOOD,
					Basis.from_euler(Vector3(0, rng.randf_range(-0.2, 0.2), rng.randf_range(-0.02, 0.02))))
		for h in [0.5, RAIL_POST - 0.1]:
			b.box(Vector3(x, h, 0.0), Vector3(0.1, 0.1, Outdoor.TILE), W.vary(W.TIMBER[rng.randi() % W.TIMBER.size()], rng, 0.07), W.WOOD)
	b.finish(lvl, pos)
