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
## None of it fights or can be hurt. The birds are one MultiMesh and only fly
## while the hero is near, the squirrels are a few small meshes: the whole of
## it costs next to nothing.

## At most this many trees hold a bird, and this many a squirrel.
const MAX_BIRDS := 26
const MAX_SQUIRRELS := 9
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


func _ready() -> void:
	if birds:
		add_child(birds)
	for s in squirrels:
		add_child(s)


static func _swap(list: Array, a: int, b: int) -> void:
	var keep = list[a]
	list[a] = list[b]
	list[b] = keep


static func _too_close(spots: Array, at: Vector3, distance: float) -> bool:
	for s: Vector3 in spots:
		if Vector2(s.x - at.x, s.z - at.z).length() < distance:
			return true
	return false
