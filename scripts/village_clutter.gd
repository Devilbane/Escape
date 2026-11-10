class_name VillageClutter
extends RefCounted
## The little heaps of village goods (barrels, crates, planks, a handcart, a
## pile of stones, pumpkins), laid out by hand instead of dropped at random:
## every tile of them is one of a few tidy arrangements, and no two things in
## it touch. Each thing is `[model, x, z, yaw, scale]` from the middle of its
## tile (x and z in metres, the tile is Level.TILE across), so the layouts can
## be checked for overlaps without building the village (tests/village_clutter.gd).

## Where the models' footprints lie at scale 1, from their meshes: the middle
## of the footprint (x, z) and half of its width and depth (x, z).
const FOOTPRINTS := {
	"barrel": [0.0, 0.0, 0.101, 0.101],
	"crate_A_big": [0.0, 0.0, 0.105, 0.105],
	"crate_long_A": [0.0, 0.0, 0.2, 0.1],
	"sack": [0.0, -0.006, 0.053, 0.08],
	"wheelbarrow": [0.0, 0.04, 0.119, 0.253],
	"bucket_water": [0.0, 0.0, 0.07, 0.07],
	"resource_lumber": [0.0, 0.0, 0.343, 0.1655],
	"resource_stone": [0.0, 0.002, 0.211, 0.179],
	"tree_single_A_cut": [0.0, -0.008, 0.085, 0.081],
	"pumpkin_orange_jackolantern": [0.0, 0.0, 0.75, 0.7],
	"pumpkin_orange": [0.0, 0.0, 0.5, 0.5],
	"pumpkin_yellow_small": [0.0, 0.0, 0.3, 0.3],
}

## Barrels, crates and sacks ("e"): one of these per tile, picked by where
## the tile is. They stay inside the tile with a margin, so two heaps on
## neighbouring tiles never touch either.
const HEAPS := [
	# Planks lying beside a crate, a bucket and a sack.
	[["resource_lumber", 0.0, -1.05, 0.0, 4.2], ["crate_A_big", -1.0, 0.55, 0.15, 6.0],
			["bucket_water", 0.45, 0.5, 0.0, 6.0], ["sack", 1.45, 0.55, 0.0, 6.0]],
	# A handcart with a sack, two barrels and a bucket by it.
	[["wheelbarrow", -0.45, -0.95, 1.5708, 5.0], ["sack", 1.55, -0.95, 0.0, 6.0],
			["barrel", -1.2, 0.85, 0.0, 6.0], ["barrel", 0.2, 0.85, 0.0, 6.0], ["bucket_water", 1.45, 0.9, 0.0, 6.0]],
	# A heap of stones with barrels and a bucket.
	[["resource_stone", -0.6, -1.0, 0.0, 5.2], ["barrel", 1.3, -1.0, 0.0, 6.0],
			["barrel", -1.2, 0.8, 0.0, 6.0], ["bucket_water", 0.2, 0.85, 0.0, 6.0]],
	# A row of crates with a long one, a barrel and a bucket.
	[["crate_A_big", -1.2, -0.9, 0.0, 6.0], ["crate_A_big", 0.25, -0.9, 0.0, 6.0], ["bucket_water", 1.5, -0.9, 0.0, 6.0],
			["crate_long_A", -0.7, 0.85, 0.0, 6.0], ["barrel", 1.3, 0.85, 0.0, 6.0]],
]

## A tree stump with logs ("t"): the planks stand upright beside the stump.
const STUMP := [["tree_single_A_cut", -0.9, 0.0, 0.0, 6.0], ["resource_lumber", 0.8, 0.0, 1.5708, 3.2]]

## The pumpkins ("p").
const PUMPKINS := [["pumpkin_orange_jackolantern", -0.7, 0.2, 0.0, 1.0], ["pumpkin_orange", 0.8, -0.55, 0.0, 1.0],
		["pumpkin_yellow_small", 0.95, 0.75, 0.0, 1.0]]

## The least space left between two things of one layout (metres), and how
## far from the middle of its tile a layout reaches at most.
const MIN_GAP := 0.1
const REACH := 1.95


## The heap for tile `cell` of the level `level_name`.
static func heap_for(level_name: String, cell: Vector2i) -> Array:
	return HEAPS[absi(hash("%s|heap|%d|%d" % [level_name, cell.x, cell.y])) % HEAPS.size()]


## The four corners (x, z) of thing `item`'s footprint, turned and scaled the
## way Outdoor puts it down (rotation about y).
static func corners(item: Array) -> Array[Vector2]:
	var fp: Array = FOOTPRINTS[item[0]]
	var yaw: float = item[3]
	var s: float = item[4]
	var c := cos(yaw)
	var sn := sin(yaw)
	var out: Array[Vector2] = []
	for sign_ in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var px: float = fp[0] + sign_.x * fp[2]
		var pz: float = fp[1] + sign_.y * fp[3]
		out.append(Vector2(item[1] + (px * c + pz * sn) * s, item[2] + (-px * sn + pz * c) * s))
	return out


## How far apart two things are (negative when they overlap): the largest gap
## along any side of either footprint (separating axis test).
static func gap(a: Array, b: Array) -> float:
	var pa := corners(a)
	var pb := corners(b)
	var best := -INF
	for poly in [pa, pb]:
		for i in 4:
			var edge: Vector2 = poly[(i + 1) % 4] - poly[i]
			var axis := Vector2(-edge.y, edge.x).normalized()
			var lo_a := INF
			var hi_a := -INF
			var lo_b := INF
			var hi_b := -INF
			for p in pa:
				lo_a = minf(lo_a, p.dot(axis))
				hi_a = maxf(hi_a, p.dot(axis))
			for p in pb:
				lo_b = minf(lo_b, p.dot(axis))
				hi_b = maxf(hi_b, p.dot(axis))
			best = maxf(best, maxf(lo_a - hi_b, lo_b - hi_a))
	return best


## The smallest gap between any two things of `layout`.
static func tightest(layout: Array) -> float:
	var least := INF
	for i in layout.size():
		for j in range(i + 1, layout.size()):
			least = minf(least, gap(layout[i], layout[j]))
	return least


## The rectangle (x, z from the middle of the tile) all of `layout` lies in.
static func bounds(layout: Array) -> Rect2:
	var box := Rect2()
	var first := true
	for item in layout:
		for p in corners(item):
			if first:
				box = Rect2(p, Vector2.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box
