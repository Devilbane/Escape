class_name GratePits
extends Node3D
## What lies in the shallow pits under the floor grates (Level.grates): a bed
## of dirt, and on it the remains of something that fell in long ago. Each
## pit gets one of a few scenes: a whole skeleton stretched out (sometimes
## with its rusty sword), a heap of bones, stones broken from the walls, a
## smashed pot or a lost shield. A few pebbles and bones lie about in every
## pit, so no two look the same.
##
## Only decoration: it lies below the bars, where nothing can reach it. Placed
## by a random generator seeded with the level's name, so a level looks the
## same every time it is played.

## The bottom of the pit, as modelled in floor_tile_big_grate.glb.
const PIT_BOTTOM := -1.0
## The top of the dirt bed: everything lies on this.
const BED_Y := -0.93
## Half the width of the pit's floor (it is 3 m across), less a margin, so
## nothing pokes into the walls of the pit.
const REACH := 1.05
## How much of the pits get each scene (the rest of the roll: a lost shield).
const SKELETON_CHANCE := 0.32
const BONES_CHANCE := 0.26
const STONES_CHANCE := 0.18
const POT_CHANCE := 0.14
## How the earth on the pit's floor darkens the kit's pale rocky floor.
const EARTH_TINT := Color(0.42, 0.33, 0.25)
const WEAPONS_DIR := "res://assets/weapons/"

var level: Level
var _rng := RandomNumberGenerator.new()


func _init(owner_level: Level) -> void:
	level = owner_level
	name = "GratePits"


func _ready() -> void:
	_rng.seed = hash(level.level_name + ":pits")
	for c: Vector2i in level.grates:
		_fill(c)


## Fills the pit under the grate on `c`.
func _fill(c: Vector2i) -> void:
	var pit := Node3D.new()
	pit.name = "Pit_%d_%d" % [c.x, c.y]
	pit.position = level.cell_to_world(c)
	add_child(pit)
	# The dirt: the kit's rocky floor, shrunk to the pit's floor.
	var bed := Node3D.new()
	bed.position.y = PIT_BOTTOM + 0.01
	bed.scale = Vector3(0.76, 1.0, 0.76)
	pit.add_child(bed)
	level._place("floor_dirt_large", Vector3.ZERO, _rng.randi_range(0, 3) * PI * 0.5, bed)
	for mi: MeshInstance3D in bed.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _earth(mi.material_override)
	_mounds(pit)
	var roll := _rng.randf()
	if roll < SKELETON_CHANCE:
		_skeleton(pit, _spot(0.2))
		if _rng.randf() < 0.45:
			_weapon(pit, "Skeleton_Blade", _spot(0.6))
	elif roll < SKELETON_CHANCE + BONES_CHANCE:
		DungeonLife.bone_pile(pit, _spot(0.5) + Vector3(0, BED_Y, 0), _rng, 1.0)
		DungeonLife.bone_pile(pit, _spot(0.9) + Vector3(0, BED_Y, 0), _rng)
	elif roll < SKELETON_CHANCE + BONES_CHANCE + STONES_CHANCE:
		_stones(pit)
	elif roll < SKELETON_CHANCE + BONES_CHANCE + STONES_CHANCE + POT_CHANCE:
		DungeonLife.broken_pot(pit, _spot(0.5) + Vector3(0, BED_Y, 0), _rng)
	else:
		_weapon(pit, "Skeleton_Shield_Large_A", _spot(0.5))
		DungeonLife.bone_pile(pit, _spot(0.9) + Vector3(0, BED_Y, 0), _rng, 0.0)
	# Odds and ends in every pit.
	DungeonLife.pebbles(pit, _spot(0.9) + Vector3(0, BED_Y, 0), _rng)
	if _rng.randf() < 0.5:
		var b := DungeonLife.bone(_rng.randf_range(0.3, 0.6))
		b.position = _spot(1.0) + Vector3(0, BED_Y + 0.05, 0)
		b.rotation.y = _rng.randf() * TAU
		pit.add_child(b)


## The pit's floor material: the kit's rocky floor, darkened to damp earth.
static var _earth_cache := {}
static func _earth(stone: Material) -> Material:
	if stone == null or not stone is BaseMaterial3D:
		return stone
	if not _earth_cache.has(stone):
		var m := (stone as BaseMaterial3D).duplicate() as BaseMaterial3D
		m.albedo_color = m.albedo_color * EARTH_TINT
		_earth_cache[stone] = m
	return _earth_cache[stone]


## A few low heaps of earth washed in through the grate.
func _mounds(pit: Node3D) -> void:
	var heap := SphereMesh.new()
	heap.radius = 0.35
	heap.height = 0.7
	heap.radial_segments = 8
	heap.rings = 4
	for i in _rng.randi_range(2, 4):
		var m := MeshInstance3D.new()
		m.mesh = heap
		m.scale = Vector3(_rng.randf_range(0.8, 1.6), _rng.randf_range(0.12, 0.25), _rng.randf_range(0.8, 1.6))
		m.rotation.y = _rng.randf() * TAU
		m.position = _spot(1.0) + Vector3(0, BED_Y - 0.02, 0)
		m.material_override = DungeonLife._material("pit_earth", Color(0.24, 0.18, 0.13), 1.0)
		pit.add_child(m)


## A spot on the pit's floor (y 0), at most `reach` of REACH from the middle.
func _spot(reach: float) -> Vector3:
	return Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0)) * REACH * reach


## A skeleton stretched out on its back, head to feet along its own z axis
## (about 1.7 m long). Now and then a bone has gone missing.
func _skeleton(pit: Node3D, at: Vector3) -> void:
	var body := Node3D.new()
	body.position = at + Vector3(0, BED_Y, 0)
	body.rotation.y = _rng.randf() * TAU
	# A little smaller than life, so it fits the pit whichever way it lies.
	body.scale = Vector3.ONE * 0.8
	pit.add_child(body)
	var head := DungeonLife.skull()
	head.position = Vector3(0, -0.02, -0.82)
	# Face up, rolled a little to one side.
	head.rotation = Vector3(-PI * 0.5 + 0.25, 0, _rng.randf_range(-0.6, 0.6))
	body.add_child(head)
	# The spine.
	for i in 6:
		_lay_bone(body, 0.13, Vector3(0, 0.05, -0.6 + i * 0.14), PI * 0.5, 0.0)
	# The ribs, splayed out on both sides.
	for i in 4:
		for side: int in [-1, 1]:
			_lay_bone(body, 0.3 - i * 0.03, Vector3(side * 0.16, 0.06, -0.52 + i * 0.1), side * 0.25, 0.0)
	# The hips.
	var hips := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.36, 0.08, 0.18)
	hips.mesh = box
	hips.position = Vector3(0, 0.05, 0.25)
	hips.material_override = DungeonLife._bone_material()
	body.add_child(hips)
	# Arms from the shoulders, legs from the hips, each bent a little.
	for side: int in [-1, 1]:
		var arm := _rng.randf_range(-0.5, 0.3) * side
		_lay_bone(body, 0.32, Vector3(side * 0.28, 0.04, -0.42), PI * 0.5 + arm, 0.0)
		_lay_bone(body, 0.28, Vector3(side * 0.28 + sin(arm) * 0.3, 0.04, -0.12), PI * 0.5 + arm * 1.6, 0.0)
		var leg := _rng.randf_range(-0.25, 0.1) * side
		_lay_bone(body, 0.46, Vector3(side * 0.12 + sin(leg) * 0.2, 0.05, 0.52), PI * 0.5 + leg, 0.0)
		_lay_bone(body, 0.42, Vector3(side * 0.12 + sin(leg) * 0.6, 0.05, 0.96), PI * 0.5 + leg * 0.5, 0.0)


## One bone of a skeleton, its middle at `pos`, turned by `yaw` (0: along x).
## Sometimes missing: the rats took it.
func _lay_bone(body: Node3D, length: float, pos: Vector3, yaw: float, roll: float) -> void:
	if _rng.randf() < 0.1:
		return
	var b := DungeonLife.bone(length)
	b.position = pos
	b.rotation = Vector3(roll, yaw + _rng.randf_range(-0.08, 0.08), 0)
	body.add_child(b)


## Stones broken from the walls: a few big, flat ones and loose pebbles,
## with a bone or two under them.
func _stones(pit: Node3D) -> void:
	var stone := SphereMesh.new()
	stone.radius = 0.2
	stone.height = 0.28
	stone.radial_segments = 7
	stone.rings = 4
	for i in _rng.randi_range(3, 5):
		var s := MeshInstance3D.new()
		s.mesh = stone
		s.scale = Vector3(_rng.randf_range(0.9, 1.6), _rng.randf_range(0.6, 1.0), _rng.randf_range(0.9, 1.6))
		s.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3))
		s.position = _spot(0.85) + Vector3(0, BED_Y + 0.05, 0)
		s.material_override = DungeonLife._material("pit_stone", Color(0.4, 0.37, 0.34), 0.95)
		pit.add_child(s)
	DungeonLife.pebbles(pit, _spot(0.6) + Vector3(0, BED_Y, 0), _rng)
	DungeonLife.bone_pile(pit, _spot(0.8) + Vector3(0, BED_Y, 0), _rng, 0.3)


## A piece of a fallen skeleton's gear, lying flat on the dirt.
func _weapon(pit: Node3D, model: String, at: Vector3) -> void:
	var node: Node3D = load(WEAPONS_DIR + model + ".gltf").instantiate()
	node.scale = Vector3.ONE * 0.55
	node.rotation = Vector3(-PI * 0.5, _rng.randf() * TAU, 0)
	node.position = at + Vector3(0, BED_Y + 0.07, 0)
	pit.add_child(node)
