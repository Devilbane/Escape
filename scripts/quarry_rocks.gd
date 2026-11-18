class_name QuarryRocks
## The rock faces at the foot of the stonemason's quarry hill (see QuarryHill),
## where anybody may break stone for themselves: run into one and the hero
## chips STONE_YIELD blocks out of it (two blows, like the crystal clusters
## in the mines, see Mines), which go into the bag as stone blocks to build
## with. A broken rock face is rubble until the next morning, then it has
## grown back (kept in Level.taken as rock_key plus the day it was broken).

## The station kind of a rock face.
const KIND := "steinbruch"
## The item a rock face gives (see Items) and how many blocks one gives.
const STONE := "steinblock"
const STONE_YIELD := 2
## The rock faces stand on the hill's east foot: the tiles of the hill's last
## column, relative to the mason's tile, one per row.
const CELLS := [Vector2i(-2, -1), Vector2i(-2, 0), Vector2i(-2, 1)]
## How far east of its tile's middle a rock face stands (metres): at the foot
## of the hill, a little out into the open column beside it.
const OUT := 2.5
## A broken rock face's height, as a share of a whole one.
const RUBBLE := 0.3
const GREY := Color(0.52, 0.5, 0.47)
const CUT := Color(0.7, 0.68, 0.64)


## Builds the rock faces for a mason on `home` and adds them to `level`.
static func build(level: Outdoor, home: Vector2i) -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = GREY
	grey.roughness = 1.0
	var cut := StandardMaterial3D.new()
	cut.albedo_color = CUT
	cut.roughness = 0.9
	for offset in CELLS:
		var cell: Vector2i = home + offset
		var pos := level.cell_to_world(cell) + Vector3(OUT, 0, 0)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(cell)
		var root := Node3D.new()
		root.name = "QuarryRock"
		root.position = pos
		level.add_child(root)
		# Chunky, low boulders heaped against each other, with a pale cut face.
		for part in [[Vector3(-0.1, 0, 0), 0.8, 1.0], [Vector3(0.45, 0, -0.5), 0.55, 0.7], [Vector3(0.4, 0, 0.55), 0.5, 0.6]]:
			var boulder := MeshInstance3D.new()
			var shape := CylinderMesh.new()
			shape.radial_segments = 6
			shape.rings = 1
			shape.bottom_radius = float(part[1])
			shape.top_radius = float(part[1]) * 0.6
			shape.height = float(part[2])
			boulder.mesh = shape
			boulder.material_override = grey
			boulder.position = (part[0] as Vector3) + Vector3(0, shape.height * 0.5 - 0.05, 0)
			boulder.rotation.y = rng.randf() * TAU
			root.add_child(boulder)
		var face := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = Vector3(0.7, 0.12, 0.5)
		face.mesh = slab
		face.material_override = cut
		face.position = Vector3(-0.15, 0.97, 0)
		face.rotation.y = rng.randf_range(-0.4, 0.4)
		root.add_child(face)
		level._add_solid(pos, Vector3(1.9, 1.1, 2.0))
		level.stations.append({"kind": KIND, "cell": cell, "pos": pos, "used": false, "spent": false, "root": root})


## The key in Level.taken for the rock face at cell `c` broken on `day`.
static func rock_key(c: Vector2i, day: int) -> String:
	return "quarry:%d:%d@%d" % [c.x, c.y, day]


## The day the rock face at `c` was last broken, from Level.taken, or -1.
static func broken_on(taken: Dictionary, c: Vector2i) -> int:
	var prefix := "quarry:%d:%d@" % [c.x, c.y]
	for key in taken:
		if str(key).begins_with(prefix):
			return int(str(key).substr(prefix.length()))
	return -1


## Shows a rock face whole or broken down to rubble.
static func set_rock(station: Dictionary, spent: bool, animate := false) -> void:
	station.spent = spent
	var root: Node3D = station.root
	var height := RUBBLE if spent else 1.0
	if not animate or not root.is_inside_tree():
		root.scale = Vector3(1.0, height, 1.0)
		return
	root.create_tween().tween_property(root, "scale", Vector3(1.0, height, 1.0), 0.5 if spent else 1.6)


## The rock faces of `level` as the hero left them: one broken before `day`
## has grown back (its mark is gone), one broken today is still rubble.
## `animate`: grows back before the hero's eyes (a new morning).
static func refresh(level: Level, day: int, animate := false) -> void:
	for st in level.stations:
		if st.kind != KIND:
			continue
		var broken := broken_on(level.taken, st.cell)
		if broken >= 0 and broken < day:
			level.taken.erase(rock_key(st.cell, broken))
			broken = -1
		var spent := broken >= 0
		if spent != st.spent or not animate:
			set_rock(st, spent, animate)


## Marks a rock face as broken on `day` and shows it as rubble, with a puff of
## dust. Returns false when it was broken already.
static func mark_broken(level: Level, station: Dictionary, day: int) -> bool:
	if station.spent:
		return false
	level.taken[rock_key(station.cell, day)] = true
	set_rock(station, true, true)
	var chips := Effects.make_stone_chips()
	chips.position = station.pos + Vector3(0, 0.8, 0)
	level.add_child(chips)
	chips.restart()
	return true
