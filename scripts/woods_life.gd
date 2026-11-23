class_name WoodsLife
extends Node3D
## The small wildlife of the woods outside the village, living in the trees
## along the forest's edge (Outdoor records them while it plants the forest):
##
## * Birds, the same colourful kinds as in the village (see VillageBirds,
##   its `wild` flock): one to a treetop, they flit from tree to tree and
##   down to the glades to peck about, and fly off to another tree when the
##   hero comes close.
## * Red squirrels (see Squirrel): they bound about at the foot of their tree
##   and run up the trunk when the hero comes close.
##
## * Hedgehogs (see Hedgehog): asleep in a ball under their tree by day, snuffling about
##   from dusk to dawn, and rolled up when the hero comes close. They live in the
##   woods and also in the village and at its edge.
##
## None of it fights or can be hurt. The birds are one MultiMesh and only fly
## while the hero is near, the squirrels are a few small meshes: the whole of
## it costs next to nothing.

## At most this many trees hold a bird, this many a squirrel, and this many a hedgehog
## (the hedgehogs under trees in the village and at its edge are counted apart).
const MAX_BIRDS := 26
const MAX_SQUIRRELS := 9
const MAX_HEDGEHOGS := 7
const MAX_VILLAGE_HEDGEHOGS := 4
## The least distance between two hedgehog homes (tiles).
const HEDGEHOG_SPACING := 8
## How many village hedgehogs keep an apple hoard, and between which distances (metres) from an
## apple tree they must live.
const MAX_HOARDERS := 2
const HOARD_FAR := 20.0
const HOARD_REACH := 55.0
## How far behind its tree's trunk (metres) a hoard lies.
const HOARD_BEHIND := 1.0
## The least distance between two bird trees, and between two squirrel trees (tiles).
const BIRD_SPACING := 3
const SQUIRREL_SPACING := 9
## How many glades (open spots by the forest) the birds peck on.
const MAX_GLADES := 40
## How far below its very top (metres) a bird's perch lies: the bird itself
## stands a little above it (see VillageBirds), on the tip of the tree.
const PERCH_BELOW := 0.2

var birds: VillageBirds
var squirrels: Array[Squirrel] = []
var hedgehogs: Array[Hedgehog] = []


## Builds the wildlife of `level` from the trees it recorded: dictionaries with
## pos (the trunk's foot), height, edge (the tile is next to open ground, or
## the tree stands on it), cell (a free tile beside it), leafy (a tree a
## squirrel can climb) and in_village. Call it once the level can tell free
## tiles (is_open).
func _init(level: Level, trees: Array, seed_text: String) -> void:
	name = "WoodsLife"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var spots := trees.filter(func(t: Dictionary): return not t.in_village and level.is_open(t.cell))
	# In a shuffled order (a Fisher-Yates shuffle on the level's own seed).
	for i in range(spots.size() - 1, 0, -1):
		_swap(spots, i, rng.randi_range(0, i))
	# The birds' treetops.
	var tops: Array[Vector3] = []
	for t: Dictionary in spots:
		if tops.size() >= MAX_BIRDS:
			break
		if _too_close(tops, t.pos, BIRD_SPACING * Level.TILE):
			continue
		tops.append(Vector3(t.pos.x, float(t.height) - PERCH_BELOW, t.pos.z))
	# The glades they come down to: free tiles beside the forest.
	var glades: Array[Vector3] = []
	var ground := spots.map(func(t: Dictionary): return level.cell_to_world(t.cell))
	for g: Vector3 in ground:
		if glades.size() >= MAX_GLADES:
			break
		if not _too_close(glades, g, Level.TILE * 2.0):
			glades.append(g)
	if not tops.is_empty():
		birds = VillageBirds.new(level, tops, glades, [] as Array[Vector3], hash(seed_text + "waldvoegel"), true)
	# The squirrels' trees: a leafy tree with open ground at its foot.
	var homes: Array[Vector3] = []
	for t: Dictionary in spots:
		if squirrels.size() >= MAX_SQUIRRELS:
			break
		if not t.leafy or not t.edge or _too_close(homes, t.pos, SQUIRREL_SPACING * Level.TILE):
			continue
		homes.append(t.pos)
		var s := Squirrel.new()
		s.setup(level, t)
		squirrels.append(s)
	# The hedgehogs live under any tree with open ground beside it: out in the woods, and
	# in the village and at its edge, among the gardens and hedges.
	var all := trees.filter(func(t: Dictionary): return level.is_open(t.cell))
	for i in range(all.size() - 1, 0, -1):
		_swap(all, i, rng.randi_range(0, i))
	var den: Array[Vector3] = []
	var wild_count := 0
	var village_count := 0
	for t: Dictionary in all:
		var in_village: bool = t.in_village
		if (in_village and village_count >= MAX_VILLAGE_HEDGEHOGS) or (not in_village and wild_count >= MAX_HEDGEHOGS - MAX_VILLAGE_HEDGEHOGS):
			continue
		if _too_close(den, t.pos, HEDGEHOG_SPACING * Level.TILE):
			continue
		den.append(t.pos)
		if in_village:
			village_count += 1
		else:
			wild_count += 1
		var h := Hedgehog.new()
		h.setup(level, t)
		hedgehogs.append(h)


## Gives the hedgehogs of the village an apple tree to fetch apples from and a hoard to keep them
## in (see Hedgehog): the MAX_HOARDERS that live between HOARD_FAR and HOARD_REACH metres from
## one of `apple_trees` (the village's apple trees, see Outdoor.square_trees), so that they carry
## their apple a good way through the village. The hoard lies hidden behind the trunk of the
## hedgehog's own tree, on the side away from the open ground.
func assign_hoards(apple_trees: Array) -> void:
	# Only trees a hedgehog can walk up to: with open ground within a tile of them.
	var reachable := []
	for t in apple_trees:
		var at_cell: Vector2i = hedgehogs[0].level.world_to_cell(t.node.position) if not hedgehogs.is_empty() else Vector2i.ZERO
		var open := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				open = open or hedgehogs[0].level.is_open(at_cell + Vector2i(dx, dy))
		if open:
			reachable.append(t)
	apple_trees = reachable
	var picks := []
	for h in hedgehogs:
		if not h.tree.in_village:
			continue
		# Its closest apple tree.
		var best := INF
		var at := Vector3.INF
		for t in apple_trees:
			var p: Vector3 = t.node.position
			var d := Vector2(p.x - h.tree.pos.x, p.z - h.tree.pos.z).length()
			if d < best:
				best = d
				at = p
		if best >= HOARD_FAR and best <= HOARD_REACH:
			picks.append([best, h, at])
	picks.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pick in picks.slice(0, MAX_HOARDERS):
		var h: Hedgehog = pick[1]
		var den: Vector3 = h.tree.pos
		var cell_at: Vector3 = h.level.cell_to_world(h.tree.cell)
		var side := Vector3(cell_at.x - den.x, 0.0, cell_at.z - den.z).normalized()
		var hoard := AppleHoard.new()
		# Behind the trunk, out of sight of the open ground.
		hoard.position = Vector3(den.x, 0.0, den.z) - side * HOARD_BEHIND
		add_child(hoard)
		h.apple_tree = Vector3(pick[2].x, 0.0, pick[2].z)
		h.hoard = hoard
		h.hoard_door = Vector3(den.x, 0.0, den.z) + side * HOARD_BEHIND


func _ready() -> void:
	if birds:
		add_child(birds)
	for s in squirrels:
		add_child(s)
	for h in hedgehogs:
		add_child(h)


static func _swap(list: Array, a: int, b: int) -> void:
	var keep = list[a]
	list[a] = list[b]
	list[b] = keep


static func _too_close(spots: Array, at: Vector3, distance: float) -> bool:
	for s: Vector3 in spots:
		if Vector2(s.x - at.x, s.z - at.z).length() < distance:
			return true
	return false
