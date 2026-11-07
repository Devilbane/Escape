class_name WallBrick
extends StaticBody3D
## One piece of the village wall (see VillageWall): a tile-long stretch of low
## stone wall, or the gate of the village. It has HP like a creature does, a
## slime can eat into it (hurt) and the stonemason builds it up again (mend).
##
## The wall shows what has happened to it: the stones go darker and greener
## where slime has been at them, fall off one after another as the HP run
## down (a gap in the wall before the brick is gone), and a destroyed brick
## is a heap of rubble that lets everyone through until it is mended. A
## number over the brick tells its HP while it is hurt.
##
## The gate is two wooden leaves between stone posts. Open, the leaves stand
## back along the way and nothing is in the passage; shut (by the villagers,
## see VillageWall) the leaves close it for everyone, and they can be broken
## like the rest of the wall (the gate then stays open until it is mended).

const MAX_HP := 1000
const LENGTH := Level.TILE
## The thickness and the height of the wall, as the blocks of the stonemason stack.
const THICK := StoneBlock.CELL
const COURSE := StoneBlock.HEIGHT
const COURSES := 2
const POST_COURSES := 3
## Where the gate leaves hang (their hinges), and how long and high they are.
const HINGE := 1.2
const LEAF_HEIGHT := 1.9
const LEAF_TIME := 0.6
## The stones of one stretch: course, middle along the wall, and whether it is a half block.
## They fall in this order as the HP run down, each below its own share of the HP.
const STONES := [
	[1, 1.2, false, 0.8], [1, -1.6, true, 0.65], [1, -0.4, false, 0.5],
	[0, 1.6, true, 0.35], [0, -1.2, false, 0.2], [0, 0.4, false, 0.08],
]
const GOO := Color(0.42, 0.62, 0.3)
const SHADE_STEPS := 8
const WOOD := Color(0.38, 0.26, 0.15)
const IRON := Color(0.2, 0.2, 0.22)

static var _wood_material: StandardMaterial3D
static var _iron_material: StandardMaterial3D

var level: Outdoor
var cell := Vector2i.ZERO
var gate := false
## The wall runs along x (its length) or along z.
var along_x := true
var hp := MAX_HP
## A gate is shut (everyone stops at it) or open. A stretch of wall is always shut.
var shut := true

var _visual := Node3D.new()
var _stones: Array[MeshInstance3D] = []
var _leaves: Array[Node3D] = []
var _body_shape: CollisionShape3D
var _leaf_shape: CollisionShape3D
var _label := Label3D.new()
var _swing: Tween
var _mended := 0.0
var _closedness := 1.0


func setup(owner_level: Outdoor, at: Vector2i, is_gate: bool, x_wise: bool) -> void:
	level = owner_level
	cell = at
	gate = is_gate
	along_x = x_wise
	shut = not is_gate
	position = level.cell_to_world(at)


func _ready() -> void:
	add_to_group("village_wall")
	add_child(_visual)
	_visual.rotation.y = 0.0 if along_x else PI * 0.5
	if gate:
		_build_gate()
	else:
		_build_wall()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.pixel_size = 0.01
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.9, 0.7)
	_label.position = Vector3(0, (POST_COURSES if gate else COURSES) * COURSE + 0.7, 0)
	_label.visible = false
	add_child(_label)
	_refresh()


# --- Building --------------------------------------------------------------------

func _block(parent: Node3D, pos: Vector3, half: bool, shade: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = StoneBlock.block_mesh()
	mi.material_override = StoneBlock.stone_material(shade)
	mi.position = pos
	if half:
		mi.scale.x = 0.5
	parent.add_child(mi)
	return mi


func _build_wall() -> void:
	for s in STONES:
		_stones.append(_block(_visual, Vector3(s[1], s[0] * COURSE, 0), s[2], StoneBlock.SHADES[0]))
	_body_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LENGTH, COURSES * COURSE, THICK)
	_body_shape.shape = box
	_body_shape.position.y = COURSES * COURSE * 0.5
	_add_collider(_body_shape)


func _build_gate() -> void:
	for side in [-1.0, 1.0]:
		var post := Node3D.new()
		post.position.x = side * (HINGE + THICK * 0.5)
		_visual.add_child(post)
		for k in POST_COURSES:
			_stones.append(_block(post, Vector3(0, k * COURSE, 0), true, StoneBlock.SHADES[k % 2]))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(THICK, POST_COURSES * COURSE, THICK)
		shape.shape = box
		shape.position = Vector3(post.position.x, POST_COURSES * COURSE * 0.5, 0)
		_add_collider(shape)
		var leaf := Node3D.new()
		leaf.position.x = side * HINGE
		_visual.add_child(leaf)
		var planks := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(HINGE, LEAF_HEIGHT, 0.16)
		planks.mesh = plank_mesh
		planks.material_override = _wood()
		planks.position = Vector3(-side * HINGE * 0.5, LEAF_HEIGHT * 0.5 + 0.1, 0)
		leaf.add_child(planks)
		for y in [0.5, 1.5]:
			var band := MeshInstance3D.new()
			var band_mesh := BoxMesh.new()
			band_mesh.size = Vector3(HINGE, 0.12, 0.2)
			band.mesh = band_mesh
			band.material_override = _iron()
			band.position = Vector3(-side * HINGE * 0.5, y, 0)
			leaf.add_child(band)
		_leaves.append(leaf)
	_leaf_shape = CollisionShape3D.new()
	var leaves := BoxShape3D.new()
	leaves.size = Vector3(HINGE * 2.0, LEAF_HEIGHT, 0.4)
	_leaf_shape.shape = leaves
	_leaf_shape.position.y = LEAF_HEIGHT * 0.5
	_add_collider(_leaf_shape)
	_set_leaves(1.0 if shut else 0.0)


func _add_collider(shape: CollisionShape3D) -> void:
	# The shape is turned with the wall, so a wall along z is as thick as one along x.
	if not along_x:
		shape.rotation.y = PI * 0.5
		shape.position = shape.position.rotated(Vector3.UP, PI * 0.5)
	add_child(shape)


static func _wood() -> StandardMaterial3D:
	if _wood_material == null:
		_wood_material = StandardMaterial3D.new()
		_wood_material.albedo_color = WOOD
		_wood_material.roughness = 0.9
	return _wood_material


static func _iron() -> StandardMaterial3D:
	if _iron_material == null:
		_iron_material = StandardMaterial3D.new()
		_iron_material.albedo_color = IRON
		_iron_material.roughness = 0.6
		_iron_material.metallic = 0.5
	return _iron_material


# --- State -----------------------------------------------------------------------

## Whether this brick stops everyone now: it stands, and a gate is shut.
func blocks() -> bool:
	return hp > 0 and shut


func is_damaged() -> bool:
	return hp < MAX_HP


func fraction() -> float:
	return float(hp) / float(MAX_HP)


## A slime (or anything else) eats into the brick. Returns whether it is gone now.
func hurt(amount: int) -> bool:
	if hp <= 0:
		return true
	hp = maxi(0, hp - maxi(1, amount))
	if hp == 0 and gate:
		# A broken gate hangs open until it is mended.
		shut = false
		if _swing != null:
			_swing.kill()
		_set_leaves(0.0)
	_refresh()
	if hp == 0:
		level.village_wall.changed(self)
		return true
	return false


## The mason builds the brick up. Returns whether it is whole again.
func mend(amount: float) -> bool:
	if hp >= MAX_HP:
		return true
	var was_gone := hp <= 0
	_mended += amount
	var whole := int(_mended)
	_mended -= whole
	hp = mini(MAX_HP, hp + whole)
	if was_gone and hp > 0:
		_refresh()
		level.village_wall.changed(self)
	else:
		_refresh()
	return hp >= MAX_HP


## The villagers shut the gate or open it. A broken gate stays open.
func close(on: bool) -> void:
	if not gate or shut == (on and hp > 0):
		return
	shut = on and hp > 0
	_leaf_shape.disabled = not blocks()
	_move_leaves(1.0 if shut else 0.0)
	level.village_wall.changed(self)


func _move_leaves(to: float) -> void:
	if _swing != null:
		_swing.kill()
	_swing = create_tween()
	_swing.tween_method(_set_leaves, _closedness, to, LEAF_TIME)


## 1 for leaves shut, 0 for leaves swung back along the way.
func _set_leaves(amount: float) -> void:
	_closedness = amount
	for i in _leaves.size():
		# The right hinge turns the other way round, so the leaves part to both sides.
		_leaves[i].rotation.y = (1.0 - amount) * PI * 0.5


# --- How it looks ---------------------------------------------------------------

func _refresh() -> void:
	var frac := fraction()
	if _body_shape != null:
		_body_shape.disabled = hp <= 0
	if _leaf_shape != null:
		_leaf_shape.disabled = not blocks()
	var damage := 1.0 - frac
	# The stones darken and take on the goo's green as the wall is eaten away.
	var step := roundi(damage * SHADE_STEPS) / float(SHADE_STEPS)
	for i in _stones.size():
		var stone := _stones[i]
		var base: Color = StoneBlock.SHADES[(cell.x * 7 + cell.y * 3 + i) % StoneBlock.SHADES.size()]
		var shade := base.darkened(0.45 * step).lerp(GOO, 0.3 * step)
		stone.material_override = StoneBlock.stone_material(shade)
		if gate:
			continue
		var share: float = STONES[i][3]
		_place_stone(stone, i, frac < share)
	if gate:
		for leaf in _leaves:
			leaf.visible = hp > 0
	_label.visible = is_damaged()
	_label.text = "%d / %d" % [hp, MAX_HP]


## A stone stays in the wall or lies on the ground beside it, where it fell.
func _place_stone(stone: MeshInstance3D, i: int, fallen: bool) -> void:
	var s: Array = STONES[i]
	if not fallen:
		stone.position = Vector3(s[1], s[0] * COURSE, 0)
		stone.rotation = Vector3.ZERO
		return
	var side := 1.0 if (i + cell.x + cell.y) % 2 == 0 else -1.0
	stone.position = Vector3(s[1] + 0.3 * side, 0.0, side * (THICK * 0.5 + 0.7 + 0.25 * (i % 3)))
	stone.rotation = Vector3(0.0, 0.5 * i + 0.3, 0.0)


# --- Reach ------------------------------------------------------------------------

## The distance on the ground from a point to the brick's body.
func distance_from(point: Vector3) -> float:
	return (nearest_point(point) - point).length()


## The point of the brick's body (on the ground) closest to a point.
func nearest_point(point: Vector3) -> Vector3:
	var half_x := LENGTH * 0.5 if along_x else THICK * 0.5
	var half_z := THICK * 0.5 if along_x else LENGTH * 0.5
	var at := global_position
	return Vector3(clampf(point.x, at.x - half_x, at.x + half_x), 0.0, clampf(point.z, at.z - half_z, at.z + half_z))
