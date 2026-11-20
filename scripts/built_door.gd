class_name BuiltDoor
extends Node3D
## The door leaf of a doorway the hero built (a door in a house wall, or a gate
## in a garden wall, see HouseSketcher): plank boards on iron straps that turn on
## a hinge at one side of the opening.
##
## - Shut, the leaf stops everyone (a thin wall in the opening).
## - Whoever walks into it pushes it open: it swings away from them, stays
##   open while someone stands in the doorway, and shuts by itself HOLD seconds
##   after the last one is through.
## - E next to it opens it and keeps it open, or shuts it (`use`).
## - Of the monsters, only people (bandits and other humans, `DOOR_FAMILIES`)
##   push an unlocked door open; slimes, beasts, the dead and every other
##   monster are stopped by a shut door as by a wall, and get in only through
##   a door someone else holds open.
## - The owner can lock it (Shift+E, `set_locked`): a locked door shows a
##   padlock on both faces and opens only for its owner and their companions,
##   so villagers, animals and monsters stay out.
##
## The node stands on the floor in the middle of the opening; its x axis runs
## along the wall, z through it.

## How far the leaf turns when open (radians, about 92°).
const OPEN_ANGLE := 1.6
## Seconds a full swing takes, and how long it stays open after the last one
## has left the doorway.
const OPEN_TIME := 0.3
const HOLD := 1.0
## How far in front of and behind the leaf someone pushes it open (metres from
## the leaf; the hero's own half width is 0.55).
const PUSH_REACH := 0.75
## The leaf: how thick, how many boards, the gap at the floor.
const LEAF_THICK := 0.07
const BOARDS := 5
const FLOOR_GAP := 0.03
## The monster families (see MonsterFamilies) clever enough to open a door.
const DOOR_FAMILIES := ["bandits", "humans"]

var width := 1.3
var height := 2.4
## Garden gates: a lower leaf of boards with gaps between, and no lintel.
var gate := false
var locked := false
## Whether it is the hero's own door (only the owner locks and unlocks).
var own := false
## Kept open with E until shut again with E.
var held_open := false
## The hero (the owner's companions pass a locked door with them).
var hero: Node3D
## Called with the new state when the owner locks or unlocks it.
var on_lock := Callable()

var leaf: Node3D
var angle := 0.0
var _target := 0.0
var _hold := 0.0
## After the hero shut it with E while standing at it, it does not open for
## them again until they have stepped away once.
var _hero_waived := false
var _blocker: CollisionShape3D
var _sensor: Area3D
var _locks: Array[Node3D] = []
## Colour of the planks (a door marked for demolition is red).
var tint := Color(0, 0, 0, 0)


## Builds the leaf, its collision and the sensor. `opening` is the size of the
## doorway (width, height).
func setup(opening: Vector2, is_gate := false, is_locked := false) -> BuiltDoor:
	name = "BuiltDoor"
	width = opening.x
	height = opening.y
	gate = is_gate
	locked = is_locked
	leaf = Node3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(-width * 0.5 + 0.02, 0, 0)
	add_child(leaf)
	leaf.add_child(_leaf_mesh())
	for side: float in [1.0, -1.0]:
		var lock := _padlock(side)
		leaf.add_child(lock)
		_locks.append(lock)
	var body := StaticBody3D.new()
	body.name = "Blocker"
	_blocker = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 0.14)
	_blocker.shape = box
	_blocker.position = Vector3(0, height * 0.5, 0)
	body.add_child(_blocker)
	add_child(body)
	_sensor = Area3D.new()
	_sensor.name = "Sensor"
	_sensor.monitorable = false
	var reach := CollisionShape3D.new()
	var area := BoxShape3D.new()
	area.size = Vector3(width + 0.3, maxf(height, 1.8), PUSH_REACH * 2.0)
	reach.shape = area
	reach.position = Vector3(0, area.size.y * 0.5, 0)
	_sensor.add_child(reach)
	add_child(_sensor)
	_show_lock()
	return self


func is_open() -> bool:
	return absf(angle) > 0.5


## 0 when shut, 1 when open as far as it goes.
func openness() -> float:
	return clampf(absf(angle) / OPEN_ANGLE, 0.0, 1.0)


## Whether `body` may push the door open.
func may_pass(body: Node) -> bool:
	if body is Enemy and not opens_doors(body):
		return false
	if not locked:
		return true
	return own and hero != null and (body == hero or body is Pet)


## Whether a monster knows how to open a door (people do; a slime does not).
static func opens_doors(e: Enemy) -> bool:
	return MonsterFamilies.family_of(e.kind) in DOOR_FAMILIES and not e.is_ghost() and not e.is_beast()


## The hero's E at the door: opens it and keeps it open, or shuts it. Returns
## "" or why not (a locked door of someone else).
func use(from: Vector3) -> String:
	if not may_pass(hero):
		return Lang.t("Abgeschlossen.")
	if is_open() or _target != 0.0:
		held_open = false
		_target = 0.0
		_hold = 0.0
		_hero_waived = true
	else:
		held_open = true
		_open_from(from)
	return ""


## The owner locks or unlocks it. A door being locked also swings shut (once
## nobody stands in it).
func set_locked(on: bool) -> void:
	locked = on
	if on:
		held_open = false
		_hold = 0.0
		_target = 0.0
	_show_lock()
	if is_inside_tree():
		Sfx.play(self, "gear_soft_1", -4.0, global_position)
	if on_lock.is_valid():
		on_lock.call(on)


## The state another copy of this door (after the houses are drawn again)
## takes over, so a redraw does not slam a door shut.
func state() -> Dictionary:
	return {"angle": angle, "target": _target, "held": held_open, "hold": _hold}


func restore(s: Dictionary) -> void:
	angle = float(s.get("angle", 0.0))
	_target = float(s.get("target", 0.0))
	held_open = bool(s.get("held", false)) and not locked
	_hold = float(s.get("hold", 0.0))
	if leaf:
		leaf.rotation.y = angle
	_update_blocker()


func _physics_process(delta: float) -> void:
	if leaf == null:
		return
	var pusher: Node3D = null
	var hero_in := false
	for b in _sensor.get_overlapping_bodies():
		if not b is CharacterBody3D or not b.is_inside_tree():
			continue
		if b == hero:
			hero_in = true
			if _hero_waived:
				continue
		if may_pass(b) and (b.collision_layer != 0 or b == hero):
			pusher = b
	if not hero_in:
		_hero_waived = false
	if pusher != null:
		_hold = HOLD
		if _target == 0.0:
			_open_from(pusher.global_position)
	elif not held_open:
		_hold -= delta
		if _hold <= 0.0:
			_target = 0.0
	var turn := OPEN_ANGLE / OPEN_TIME * delta
	angle = move_toward(angle, _target, turn)
	leaf.rotation.y = angle
	_update_blocker()


## Swings away from `from` (a push door).
func _open_from(from: Vector3) -> void:
	var side := to_local(from).z
	if _target == 0.0 and is_inside_tree():
		Sfx.play(self, "door", -10.0, global_position)
	_target = OPEN_ANGLE if side >= 0.0 else -OPEN_ANGLE


## Shut, it is a wall; once it starts to open, the way is free.
func _update_blocker() -> void:
	if _blocker:
		_blocker.disabled = _target != 0.0 or absf(angle) > 0.05


func _show_lock() -> void:
	for l in _locks:
		l.visible = locked


## The leaf, its hinge side at the node's origin: boards side by side, two
## ledges and a brace on the back, iron straps on the front, a ring to pull.
func _leaf_mesh() -> MeshInstance3D:
	var b := WeatheredProps.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wide := width - 0.04
	var top := height - FLOOR_GAP - 0.02
	var board := wide / float(BOARDS)
	var red := tint.a > 0.0
	for i in BOARDS:
		var colour := tint if red else WeatheredProps.vary(WeatheredProps.TIMBER[rng.randi() % WeatheredProps.TIMBER.size()], rng, 0.08)
		# A gate's boards have gaps and pointed-ish tops of uneven height.
		var gap := 0.05 if gate else 0.008
		var tall := top - (rng.randf_range(0.0, 0.05) if gate else 0.0)
		b.box(Vector3(board * (i + 0.5), FLOOR_GAP, 0), Vector3(board - gap, tall, LEAF_THICK), colour, WeatheredProps.WOOD)
	var dark := tint if red else WeatheredProps.DARK_TIMBER
	# Ledges and the brace on both faces (the door is seen from both sides).
	for face: float in [1.0, -1.0]:
		var z: float = face * (LEAF_THICK * 0.5 + 0.02)
		for y in ([0.25, top - 0.3] if gate else [0.35, top * 0.5, top - 0.35]):
			b.box(Vector3(wide * 0.5, y - 0.07, z), Vector3(wide - 0.02, 0.14, 0.04), dark, WeatheredProps.WOOD)
		# The brace rises towards the hinge, clear of the handle on the other side.
		var lo := Vector3(wide - 0.12, 0.42, z) if not gate else Vector3(0.12, 0.32, z)
		var hi := Vector3(0.12, top * 0.5 - 0.08, z) if not gate else Vector3(wide - 0.12, top - 0.38, z)
		b.bar(lo, hi, 0.04, dark, WeatheredProps.WOOD, 4)
	if not gate:
		var iron := WeatheredProps.IRON_COLOUR * 0.55
		for face: float in [1.0, -1.0]:
			var z: float = face * (LEAF_THICK * 0.5 + 0.045)
			# Strap hinges reaching most of the way across.
			for y in [0.55, top - 0.55]:
				b.box(Vector3(wide * 0.36, y - 0.03, z), Vector3(wide * 0.68, 0.06, 0.012), iron, WeatheredProps.IRON)
			# The ring handle on its plate, on the side away from the hinge.
			b.box(Vector3(wide - 0.16, 1.02, z), Vector3(0.1, 0.16, 0.012), iron, WeatheredProps.IRON)
			b.bar(Vector3(wide - 0.16, 1.02, z), Vector3(wide - 0.16, 1.02, z + face * 0.06), 0.012, iron, WeatheredProps.IRON, 4)
			for k in 6:
				var a0 := TAU * k / 6.0
				var a1 := TAU * (k + 1) / 6.0
				var c := Vector3(wide - 0.16, 0.98, z + face * 0.07)
				b.bar(c + Vector3(sin(a0) * 0.06, -cos(a0) * 0.06 + 0.04, 0), c + Vector3(sin(a1) * 0.06, -cos(a1) * 0.06 + 0.04, 0), 0.01, iron, WeatheredProps.IRON, 4)
	else:
		# A gate has a latch bar instead of a ring.
		for face: float in [1.0, -1.0]:
			var z: float = face * (LEAF_THICK * 0.5 + 0.045)
			b.box(Vector3(wide - 0.14, top * 0.6, z), Vector3(0.22, 0.05, 0.02), WeatheredProps.IRON_COLOUR * 0.55, WeatheredProps.IRON)
	var holder := Node3D.new()
	var mi := b.finish(holder, Vector3.ZERO)
	holder.remove_child(mi)
	holder.free()
	mi.name = "Boards"
	return mi


## A hasp and padlock beside the handle, on one face (`side` +1 or −1 along z).
func _padlock(side: float) -> Node3D:
	var b := WeatheredProps.Builder.new()
	var wide := width - 0.04
	var y := (height - FLOOR_GAP) * 0.6 if gate else 1.32
	var z: float = side * (LEAF_THICK * 0.5 + 0.05)
	var iron := WeatheredProps.IRON_COLOUR * 0.5
	var brass := Color(0.78, 0.6, 0.25)
	# The hasp: an iron strap over the edge of the leaf.
	b.box(Vector3(wide - 0.06, y - 0.03, z), Vector3(0.2, 0.07, 0.015), iron, WeatheredProps.IRON)
	# The lock's body and its shackle.
	b.box(Vector3(wide - 0.06, y - 0.16, z + side * 0.025), Vector3(0.11, 0.12, 0.04), brass, WeatheredProps.IRON)
	b.bar(Vector3(wide - 0.1, y - 0.04, z + side * 0.025), Vector3(wide - 0.1, y + 0.03, z + side * 0.025), 0.012, iron, WeatheredProps.IRON, 4)
	b.bar(Vector3(wide - 0.02, y - 0.04, z + side * 0.025), Vector3(wide - 0.02, y + 0.03, z + side * 0.025), 0.012, iron, WeatheredProps.IRON, 4)
	b.bar(Vector3(wide - 0.1, y + 0.03, z + side * 0.025), Vector3(wide - 0.02, y + 0.03, z + side * 0.025), 0.012, iron, WeatheredProps.IRON, 4)
	var holder := Node3D.new()
	var mi := b.finish(holder, Vector3.ZERO)
	holder.remove_child(mi)
	holder.free()
	mi.name = "Padlock"
	return mi
