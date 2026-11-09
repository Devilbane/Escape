class_name VillageFarm
extends RefCounted
## Puts the village's animals out on its meadows (see FarmAnimal): a flock of
## geese on the south meadow, a few goats on the west meadow with the boy Pip,
## who looks after them (see Villager, "herds"), sheep on the north-west
## meadow, two cows and a bull on the east meadow, and two dogs: a Shiba Inu
## that keeps Pip's goats company and a Husky at the farm in the south-east corner.
##
## The spots are given as tiles of the village map; each one is moved to the
## nearest tile where an animal may stand (see FarmAnimal.may_stand), and
## animals that find no such tile near it are left out, so a map that has been
## redrawn in the workshop never puts one inside a wall.

## kind, home tile, how many, coat (see FarmAnimal.coat).
const HERDS := [
	{"kind": "goose", "at": Vector2i(46, 40), "count": 6, "coats": ["", "", "", "", "", "grey"]},
	{"kind": "goat", "at": Vector2i(40, 30), "count": 4, "coats": ["", "brown", "", "black"]},
	{"kind": "sheep", "at": Vector2i(40, 23), "count": 4, "coats": [""]},
	{"kind": "dog", "at": Vector2i(41, 33), "count": 1, "coats": [""]},
	{"kind": "dog", "at": Vector2i(57, 40), "count": 1, "coats": ["black"]},
	{"kind": "cow", "at": Vector2i(59, 27), "count": 2, "coats": [""]},
	{"kind": "bull", "at": Vector2i(58, 31), "count": 1, "coats": [""]},
]
## Where Pip stands to mind the goats, next to the herd's home tile.
const PIP_AT := Vector2i(42, 31)
## How far from its tile the nearest standing place is looked for.
const SEARCH := 5


## Lets the animals out. Returns them, flocks wired up.
static func spawn(lvl: Outdoor) -> Array[FarmAnimal]:
	var all: Array[FarmAnimal] = []
	for herd in HERDS:
		var flock: Array[FarmAnimal] = []
		var taken: Array[Vector2i] = []
		var home := _place(lvl, herd.at, [])
		if home == Vector2i(-1, -1):
			continue
		for i in int(herd.count):
			var cell := _place(lvl, herd.at, taken)
			if cell == Vector2i(-1, -1):
				continue
			taken.append(cell)
			var a := FarmAnimal.new()
			a.setup(lvl, herd.kind, home, herd.coats[i % herd.coats.size()])
			lvl.add_child(a)
			a.global_position = lvl.cell_to_world(cell) + Vector3((i % 3 - 1) * 0.7, 0, (i / 3 - 0.5) * 0.7)
			a.reset_physics_interpolation()
			flock.append(a)
		for a in flock:
			a.mates = flock
		all.append_array(flock)
	return all


## The nearest tile to `at` where an animal may stand and none stands yet.
static func _place(lvl: Outdoor, at: Vector2i, taken: Array[Vector2i]) -> Vector2i:
	for r in range(0, SEARCH + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := at + Vector2i(dx, dy)
				if lvl.cell_char(c) == "." and FarmAnimal.may_stand(lvl, c) and not taken.has(c):
					return c
	return Vector2i(-1, -1)


## Where Pip stands to mind the goats, or INF when the village has none.
static func pip_spot(lvl: Outdoor) -> Vector3:
	if lvl.farm_animals.filter(func(a: FarmAnimal): return a.kind == "goat").is_empty():
		return Vector3.INF
	var c := _place(lvl, PIP_AT, [])
	return lvl.cell_to_world(c) if c != Vector2i(-1, -1) else Vector3.INF
