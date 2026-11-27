class_name BuiltShutters
extends Node3D
## The pair of wooden shutters on a window the hero built (see HouseSketcher):
## two leaves of boards, hinged at the sides of the opening on the outside face
## of the wall. Open, they lie flat against the wall beside the window; shut,
## they meet in the middle and cover the pane, so no light gets in or out.
##
## - E next to one of the hero's own windows opens or shuts its shutters
##   (`toggle`, see Game.window_action). Whether they are shut is kept with
##   the house plan (HouseSketch.shut), so it lasts over redraws and loads.
## - They are only seen: the pane already stops everyone (see HouseSketcher).
##
## The node stands at the middle of the opening's foot (on the sill), on the
## wall's outside face; its x axis runs along the wall and +z points outwards.

## How far a leaf turns from shut to open: nearly a half turn, so it lies
## against the wall.
const OPEN_ANGLE := PI * 0.97
## Seconds a full swing takes.
const SWING_TIME := 0.45
## The leaves: how thick, how many boards each.
const LEAF_THICK := 0.045
const BOARDS := 3

## The hour of the day (set by the village, see Outdoor.set_hour): the shutters of every window
## swing shut from the evening until the morning, whatever their owner left them at.
static var hour := 12.0
const SHUT_FROM := 19.5
const OPEN_FROM := 7.0


static func shut_by_night() -> bool:
	return hour >= SHUT_FROM or hour < OPEN_FROM


var width := 1.3
var height := 1.0
var shut := false
## Whether these are the hero's own shutters (only the owner opens and shuts them).
var own := false
## Called with the new state when the owner opens or shuts them.
var on_change := Callable()
## Colour of the boards (shutters marked for demolition are red).
var tint := Color(0, 0, 0, 0)

var leaves: Array[Node3D] = []
## 0 open, 1 shut.
var closed := 0.0


## Builds both leaves for an opening of `opening` (width, height).
func setup(opening: Vector2, is_shut := false) -> BuiltShutters:
	name = "BuiltShutters"
	width = opening.x
	height = opening.y
	shut = is_shut
	closed = 1.0 if shut else 0.0
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "Left" if side < 0.0 else "Right"
		hinge.position = Vector3(side * width * 0.5, 0, 0)
		hinge.add_child(_leaf_mesh(side))
		add_child(hinge)
		leaves.append(hinge)
	_pose()
	return self


## Opens shut shutters or shuts open ones. Returns whether they are shut now.
func toggle() -> bool:
	set_shut(not shut)
	return shut


func set_shut(on: bool) -> void:
	if on == shut:
		return
	shut = on
	if is_inside_tree():
		Sfx.play(self, "door", -14.0, global_position)
	if on_change.is_valid():
		on_change.call(on)


func _process(delta: float) -> void:
	var goal := 1.0 if shut or shut_by_night() else 0.0
	if closed == goal:
		return
	closed = move_toward(closed, goal, delta / SWING_TIME)
	_pose()


## Turns the leaves to how shut they are: the left one swings out and round to
## the left, the right one to the right.
func _pose() -> void:
	var open := (1.0 - closed) * OPEN_ANGLE
	if leaves.size() == 2:
		leaves[0].rotation.y = -open
		leaves[1].rotation.y = open


## One leaf, from its hinge (the node's origin) towards the middle of the
## window (`side` -1 for the left leaf, whose boards run along +x; +1 for the
## right one): upright boards, a ledge at top and bottom and a brace on the
## outside, two iron strap hinges and a small catch.
func _leaf_mesh(side: float) -> MeshInstance3D:
	var b := WeatheredProps.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if side < 0.0 else 13
	var red := tint.a > 0.0
	var wide := width * 0.5 - 0.01
	var dir := -side
	var board := wide / float(BOARDS)
	for i in BOARDS:
		var colour := tint if red else WeatheredProps.vary(WeatheredProps.TIMBER[rng.randi() % WeatheredProps.TIMBER.size()], rng, 0.08)
		b.box(Vector3(dir * board * (i + 0.5), 0.0, 0), Vector3(board - 0.008, height, LEAF_THICK), colour, WeatheredProps.WOOD)
	var dark := tint if red else WeatheredProps.DARK_TIMBER
	# The ledges and the brace, on both faces (an open shutter shows its back).
	for face: float in [1.0, -1.0]:
		var z: float = face * (LEAF_THICK * 0.5 + 0.015)
		for y in [0.08, height - 0.2]:
			b.box(Vector3(dir * wide * 0.5, y, z), Vector3(wide - 0.04, 0.12, 0.03), dark, WeatheredProps.WOOD)
		b.bar(Vector3(dir * 0.1, 0.22, z), Vector3(dir * (wide - 0.1), height - 0.24, z), 0.03, dark, WeatheredProps.WOOD, 4)
	if not red:
		var iron := WeatheredProps.IRON_COLOUR * 0.55
		var z_out := LEAF_THICK * 0.5 + 0.035
		for y in [0.12, height - 0.16]:
			b.box(Vector3(dir * wide * 0.3, y, z_out), Vector3(wide * 0.6, 0.04, 0.01), iron, WeatheredProps.IRON)
		# The catch where the two leaves meet.
		b.box(Vector3(dir * (wide - 0.05), height * 0.5 - 0.04, z_out), Vector3(0.06, 0.08, 0.01), iron, WeatheredProps.IRON)
	var holder := Node3D.new()
	var mi := b.finish(holder, Vector3.ZERO)
	holder.remove_child(mi)
	holder.free()
	mi.name = "Boards"
	return mi
