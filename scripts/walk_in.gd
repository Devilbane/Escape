class_name WalkIn
extends RefCounted
## The village buildings one can walk into, like a self-built house (see HouseSketcher): the four
## villagers' houses (see VillageHouse.hollow) and the temple (the chapel, see
## Outdoor._build_chapel). From outside they look exactly as they always did. Their door swings
## open as the hero comes up to it, and inside is a room: a floor, walls all round, windows one
## sees out of, and furniture (a table, a shelf, stores and a ladder up to the floor above in a
## house, pews and an altar in the temple). While the hero is inside:
## - the floor above, the roof and everything on them (ivy, snow, a nest, chimney smoke) are hidden,
##   and the front wall too (the temple's fades to a ghost of itself), so the camera sees in;
## - the room keeps the weather out (Outdoor.is_sheltered), and the hero sees out only through
##   the windows and the open door (see InsideView, Level.fixed_walls);
## - a warm light burns in a house.
## At night the villagers of the house they go home to climb its ladder to the floor above, where
## they sleep (see VillageBeds).
##
## The switches: `houses` and `temple` below. Turned off (false), that building is built the old way,
## a solid block one cannot enter, and nothing of this runs for it. They are static, so a test
## can turn them off; in the game they are only ever changed here.
static var houses := true
static var temple := true
## The halls rebuilt in the village's style to be walked into (see VillageHalls), each on its own:
## the tavern (n), the shop (m), the post office (o), the Crown office (k) and the adventurers'
## guild (w). Off, a hall is the old solid kit model again.
static var halls := {"n": true, "m": true, "o": true, "k": true, "w": true, "u": true}

## Map tiles of other buildings one walks into that let sight and reach through (the bank, see
## BankVault): their own walls stop them.
var open_cells := {}

## The heights on the hero (metres above their feet) whose sight lines a roof must both cross to
## count as covering them (see _mind_cover), and how long the roof stays off after (seconds).
const COVER_FEET := 0.3
const COVER_HEAD := 1.7
const COVER_LINGER := 0.4
## The hero this near the middle of a doorway (metres) opens its door.
const DOOR_REACH := 2.2
## The doorway as wide as the walls stop the hero (a little wider than the leaf, so the hero, 1.1 m
## across, fits through without catching on the frame).
const DOOR_GAP := 1.24
## How far in front of a house door the ramp up to its floor starts (metres): up the step and
## over the threshold, PLINTH high.
const RAMP := 1.0
## How long between two pushes on a door the hero stands at (seconds).
const PUSH_EVERY := 0.4
## The warm light in a house while the hero is inside.
const LAMP_COLOUR := Color(1.0, 0.76, 0.48)
const LAMP_ENERGY := 1.4
const LAMP_RANGE := 6.5
## How see-through the temple's front wall gets while the hero is inside (0 solid, 1 gone).
const FRONT_FADED := 0.8
const FADE_TIME := 0.25
## The beds of a house, on the floor above: as many as fit side by side along its back wall
## beside the hatch, at most this many.
const MAX_BEDS := 3
## The house ladder (see _furnish_house): how far in from the side wall the hatch's edge is, how
## far back from the front wall the ladder stands, and how far before the edge one stands at its foot.
const LADDER_EDGE_IN := 0.6
const LADDER_FROM_FRONT := 0.75
const LADDER_FOOT := 0.65
## How much of the floor above the hatch and the way from it to the beds keep free (metres across).
const HATCH_CLEAR := 1.7
## A bed's footprint across (CosyBed without its table) and the gap between two.
const BED_WIDE := CosyBed.RIGHT - CosyBed.LEFT
const BED_GAP := 0.1

## The temple in the kit's own metres (see Outdoor.CHAPEL_PARTS): the inside of its walls, how high
## they stand, the doorway (door_01 hangs on its left post, inside the front wall from NAVE_DOOR_Z to
## NAVE_WALL_OUT), the porch in front of it (doorway_01: a landing as high as NAVE_FLOOR, and steps
## down to the ground at PORCH_END), and the heights where the roof starts and the front wall's
## pieces stand. The nave's new floor lies level with the porch's landing.
const NAVE := Rect2(-10.5, -11.0, 21.0, 22.0)
const NAVE_WALL := 16.0
const NAVE_FLOOR := 1.0
const NAVE_DOOR_X := Vector2(-2.0, 2.0)
const NAVE_DOOR_Z := 11.0
const NAVE_WALL_OUT := 12.0
const PORCH_HALF := 4.0
const PORCH_LANDING := 15.2
const PORCH_END := 18.2
const NAVE_ROOF := 15.8
const NAVE_FRONT := 10.3
## A building's walls, by the way they face in its own frame: the front (its door, +z), the back,
## its left (-x) and right (+x).
const SIDES := ["front", "back", "left", "right"]
const SIDE_NORMALS := {"front": Vector3(0, 0, 1), "back": Vector3(0, 0, -1), "left": Vector3(-1, 0, 0), "right": Vector3(1, 0, 0)}
## How near a wall (metres) a leaf of ivy counts as growing on it (see split_ivy).
const ON_WALL := 0.45

var level: Node3D
## One entry per building (see claim): its node, its kind ("house" or "temple") and everything
## made for it.
var buildings: Array = []
## The building the hero stands in, or {}.
var hero_in: Dictionary = {}


func _init(lvl: Node3D) -> void:
	level = lvl


## Whether the building made for map letter `ch` can be walked into.
static func is_on(ch: String) -> bool:
	return ((ch == "h" or ch == "ß") and houses) or (ch == "s" and temple) or bool(halls.get(ch, false))


## Takes on a building before it is dressed (see Outdoor._dress_building), so its ivy can be sorted
## into what hides with the floor above or the front wall and what stays.
func claim(node: Node3D, kind: String, block: Rect2i) -> Dictionary:
	var rec := {"node": node, "kind": kind, "block": block, "up": [], "front": [], "ivy_up": {}, "ivy_front": {},
			"beds": [], "inside": false, "push": 0.0, "fade": 0.0}
	if VillageHalls.KINDS.values().has(kind):
		# A hall's door may face any way: whichever of its walls faces the camera hides (see SIDES).
		rec["sided"] = true
		for side: String in SIDES:
			rec[side] = rec.get(side, [])
			rec["ivy_" + side] = {}
	if kind != "temple":
		# A villagers' house or a hall (see VillageHalls): both are VillageHouses.
		var shape: Dictionary = node.get_meta("shape")
		var w: float = shape.w
		var d: float = shape.d
		var t := VillageHouse.WALL_THICK
		rec["room"] = Rect2(-w * 0.5 + t, -d * 0.5 + t, w - t * 2.0, d - t * 2.0)
		rec["floor"] = VillageHouse.PLINTH + VillageHouse.FLOOR_LIFT
		rec["top"] = VillageHouse.PLINTH + VillageHouse.GROUND
		rec["door"] = Vector3(float(shape.door_x), 0.0, d * 0.5)
		rec["wall_out"] = d * 0.5
		rec["upper_from"] = rec.top - 0.3
		rec["front_from"] = d * 0.5 - 0.4
	else:
		rec["room"] = NAVE
		rec["floor"] = NAVE_FLOOR + 0.03
		rec["top"] = NAVE_WALL
		rec["door"] = Vector3((NAVE_DOOR_X.x + NAVE_DOOR_X.y) * 0.5, 0.0, NAVE_DOOR_Z)
		rec["wall_out"] = NAVE_WALL_OUT
		rec["upper_from"] = NAVE_ROOF
		rec["front_from"] = NAVE_FRONT
	node.set_meta("walk_in", true)
	buildings.append(rec)
	return rec


func _record(node: Node) -> Dictionary:
	for rec in buildings:
		if rec.node == node:
			return rec
	return {}


## Whether `node` is a building taken on here.
func has(node: Node) -> bool:
	return not _record(node).is_empty()


## Splits the ivy grown on a claimed building (`leaves` as AgedStone.grow_ivy makes it, in the level's
## frame): the leaves up on the floor above and the roof and those on the front wall are kept for
## plant_ivy, the rest is returned for the village's own ivy.
func split_ivy(node: Node3D, leaves: Dictionary) -> Dictionary:
	var rec := _record(node)
	if rec.is_empty():
		return leaves
	var stay := {}
	var to_local := node.transform.affine_inverse()
	for pair: Array in [["xforms", "colours"], ["stems", "stem_colours"], ["grapes", "grape_colours"]]:
		var xforms: Array = leaves.get(pair[0], [])
		var colours: Array = leaves.get(pair[1], [])
		if not leaves.has(pair[0]):
			continue
		stay[pair[0]] = []
		stay[pair[1]] = []
		for i in xforms.size():
			var at: Vector3 = to_local * (xforms[i] as Transform3D).origin
			var into: Dictionary = stay
			if at.y >= float(rec.upper_from):
				into = rec.ivy_up
			elif rec.has("sided"):
				var side := _side_of(rec, at)
				if side != "":
					into = rec["ivy_" + side]
			elif at.z >= float(rec.front_from):
				into = rec.ivy_front
			if not into.has(pair[0]):
				into[pair[0]] = []
				into[pair[1]] = []
			into[pair[0]].append(xforms[i])
			into[pair[1]].append(colours[i] if i < colours.size() else Color.WHITE)
	return stay


## Notes what else hides with the floor above (snow caps, a nest, chimney smoke).
func add_upper(node: Node3D, part: Node3D) -> void:
	var rec := _record(node)
	if not rec.is_empty() and part != null:
		rec.up.append(part)


## Notes what else hides with the front wall (the temple's lamps).
func add_front(node: Node3D, part: Node3D) -> void:
	var rec := _record(node)
	if not rec.is_empty() and part != null:
		rec.front.append(part)


## Plants the ivy kept by split_ivy into the village's ivy (`ivy`, see AgedStone.ivy_node): its
## tiles become children of it like the others, so the seasons turn them too (see IvySeasons),
## and they hide with what they grow on.
func plant_ivy(ivy: Node3D) -> void:
	if ivy == null:
		return
	for i in buildings.size():
		var rec: Dictionary = buildings[i]
		for group: String in ["up"] + SIDES:
			if not rec.has("ivy_" + group):
				continue
			var leaves: Dictionary = rec["ivy_" + group]
			if (leaves.get("xforms", []) as Array).is_empty():
				continue
			# No leaf over a door, as with the village's own ivy.
			AgedStone.clear_doors(leaves, level.get("_entrances"))
			if (leaves.xforms as Array).is_empty():
				continue
			var made := AgedStone.ivy_node(leaves)
			for child in made.get_children():
				made.remove_child(child)
				child.name = "%s_walk%d%s" % [child.name, i, group]
				ivy.add_child(child)
				rec[group].append(child)
			made.free()


# --- Opening the buildings ----------------------------------------------------

## Makes a claimed house one can walk into (after it is dressed): hollow, with its walls, floor,
## doorway and furniture.
func open_house(house: Node3D) -> void:
	var rec := _record(house)
	if rec.is_empty():
		return
	var meshes := VillageHouse.hollow(house, rec.has("sided"))
	rec.up.append(meshes.up)
	rec.front.append(meshes.front)
	if rec.has("sided"):
		for side: String in ["back", "left", "right"]:
			rec[side].append(meshes[side])
	var leaf: HouseDoor = house.get_meta("door_leaf")
	rec.front.append(leaf)
	rec["leaf"] = leaf
	var shape: Dictionary = house.get_meta("shape")
	var w: float = shape.w
	var d: float = shape.d
	var door_x: float = shape.door_x
	var t := VillageHouse.WALL_THICK
	var floor_y: float = rec.floor
	var out := 0.15
	# The walls, from their inner faces to a little past the outer ones, and the floor.
	_solid(rec, Vector3(0, 2.0, -d * 0.5 + (t - out) * 0.5), Vector3(w + out * 2.0, 4.0, t + out))
	for s: float in [-1.0, 1.0]:
		_solid(rec, Vector3(s * (w * 0.5 + (out - t) * 0.5), 2.0, 0), Vector3(t + out, 4.0, d + out * 2.0))
	var gap_l := door_x - DOOR_GAP * 0.5
	var gap_r := door_x + DOOR_GAP * 0.5
	var z_front := d * 0.5 + (out - t) * 0.5
	_solid(rec, Vector3((-w * 0.5 - out + gap_l) * 0.5, 2.0, z_front), Vector3(gap_l + w * 0.5 + out, 4.0, t + out))
	_solid(rec, Vector3((w * 0.5 + out + gap_r) * 0.5, 2.0, z_front), Vector3(w * 0.5 + out - gap_r, 4.0, t + out))
	_solid(rec, Vector3(0, floor_y * 0.5, 0), Vector3(w, floor_y, d))
	rec["door_shape"] = _solid(rec, Vector3(door_x, 1.4, d * 0.5 - t * 0.5), Vector3(DOOR_GAP, 2.8, t))
	_ramp(rec, door_x, d * 0.5, floor_y)
	if rec.kind == "house" and rec.has("owner"):
		SmithCottage.furnish(self, rec)
	elif rec.kind == "house":
		_furnish_house(rec, w, d, door_x)
	else:
		VillageHalls.furnish(self, rec)
	_lamp(rec)
	_walls_of_house(rec, w, d, door_x)
	_finish(rec)


## Makes the claimed temple one can walk into: a floor of stone flags, its door swinging on its hinge,
## walls that stop the hero, pews and an altar.
func open_temple(chapel: Node3D) -> void:
	var rec := _record(chapel)
	if rec.is_empty():
		return
	var s := chapel.scale.x
	for part: Node in chapel.get_children():
		var p := part as Node3D
		if p == null:
			continue
		if p.position.y >= NAVE_ROOF or p.name == "ChapelPenguin":
			rec.up.append(p)
		elif p.position.z >= NAVE_DOOR_Z - 0.5 and absf(p.rotation.y) < 0.1:
			# The front wall: the kit's pieces start at their origin and run along +x, the side
			# walls (turned a quarter) are left standing.
			rec["front_pieces"] = rec.get("front_pieces", []) + [p]
	# The door: door_01 hangs on its left post, the leaf a HouseDoor turns (outwards, into the porch).
	var door_piece: Node3D = null
	for p: Node3D in rec.get("front_pieces", []):
		if p.name.begins_with("door_01"):
			door_piece = p
	if door_piece != null:
		var hinge := HouseDoor.new()
		hinge.name = "TempleDoor"
		hinge.position = door_piece.position
		chapel.add_child(hinge)
		chapel.remove_child(door_piece)
		door_piece.position = Vector3.ZERO
		hinge.leaf = door_piece
		hinge.add_child(door_piece)
		rec["leaf"] = hinge
		(level.get("house_doors") as Array).append(hinge)
	# Walls, in the kit's metres, the front one either side of the doorway and the porch's frame.
	var x1 := NAVE.end.x
	var thick := 1.6
	_solid_kit(rec, Vector3(0, NAVE_WALL * 0.5, NAVE.position.y - thick * 0.5), Vector3(x1 * 2.0 + thick * 2.0, NAVE_WALL, thick))
	for side: float in [-1.0, 1.0]:
		_solid_kit(rec, Vector3(side * (x1 + thick * 0.5), NAVE_WALL * 0.5, 0), Vector3(thick, NAVE_WALL, NAVE.size.y + thick * 2.0))
		var inner := NAVE_DOOR_X.y
		var outer := x1 + thick
		_solid_kit(rec, Vector3(side * (inner + outer) * 0.5, NAVE_WALL * 0.5, NAVE_DOOR_Z + 0.5), Vector3(outer - inner, NAVE_WALL, 1.0))
		_solid_kit(rec, Vector3(side * (inner + 1.0), NAVE_WALL * 0.5, NAVE_WALL_OUT + 0.5), Vector3(2.0, NAVE_WALL, 1.0))
	rec["door_shape"] = _solid_kit(rec, Vector3(rec.door.x, 4.0, NAVE_DOOR_Z + 0.65), Vector3(NAVE_DOOR_X.y - NAVE_DOOR_X.x, 8.0, 0.5))
	# The floor: the nave and the porch's landing, and steps down from it as a ramp.
	var floor_top: float = NAVE_FLOOR
	_solid_kit(rec, Vector3(0, floor_top * 0.5, (NAVE.position.y + NAVE_WALL_OUT) * 0.5), Vector3(NAVE.size.x, floor_top, NAVE_WALL_OUT - NAVE.position.y))
	_solid_kit(rec, Vector3(0, floor_top * 0.5, (NAVE_WALL_OUT + PORCH_LANDING) * 0.5), Vector3(PORCH_HALF * 2.0, floor_top, PORCH_LANDING - NAVE_WALL_OUT))
	var wedge := PackedVector3Array()
	for sx: float in [-PORCH_HALF, PORCH_HALF]:
		wedge.append(Vector3(sx, 0.0, PORCH_END))
		wedge.append(Vector3(sx, 0.0, PORCH_LANDING))
		wedge.append(Vector3(sx, floor_top, PORCH_LANDING))
	_wedge(rec, wedge)
	_furnish_temple(rec, chapel)
	_walls_of_temple(rec)
	_finish(rec)


## A box that stops everyone, `center` and `size` in the building's own frame (metres).
func _solid(rec: Dictionary, center: Vector3, size: Vector3) -> CollisionShape3D:
	var node: Node3D = rec.node
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(node.transform.basis.orthonormalized(), node.transform * center)
	_body().add_child(shape)
	return shape


## The same in the temple kit's metres (scaled down with the chapel).
func _solid_kit(rec: Dictionary, center: Vector3, size: Vector3) -> CollisionShape3D:
	var s: float = (rec.node as Node3D).scale.x
	var node: Node3D = rec.node
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size * s
	shape.shape = box
	shape.transform = Transform3D(node.transform.basis.orthonormalized(), node.transform * center)
	_body().add_child(shape)
	return shape


## The ramp up to a house floor through its doorway, over the step: a wedge from the ground RAMP
## metres out up to the floor at the face of the wall.
func _ramp(rec: Dictionary, door_x: float, wall: float, floor_y: float) -> void:
	var points := PackedVector3Array()
	for sx: float in [-0.8, 0.8]:
		points.append(Vector3(door_x + sx, 0.0, wall + RAMP))
		points.append(Vector3(door_x + sx, 0.0, wall))
		points.append(Vector3(door_x + sx, floor_y, wall))
	_wedge(rec, points)


## A wedge that stops everyone, from its corners in the building's own frame (scaled with it).
func _wedge(rec: Dictionary, points: PackedVector3Array) -> void:
	var node: Node3D = rec.node
	var shape := CollisionShape3D.new()
	var wedge := ConvexPolygonShape3D.new()
	var placed := PackedVector3Array()
	for p in points:
		placed.append(node.transform * p)
	wedge.points = placed
	shape.shape = wedge
	_body().add_child(shape)


## The level's own static body, which every wall of the open-air map is a box of.
func _body() -> StaticBody3D:
	return level.get("_walls_body")


# --- Furniture -------------------------------------------------------------------

## The ground floor of a house: a round table with stools, a shelf of stores on the back wall,
## barrels and a crate in the back corner on the door's side, and in the front corner away from
## the door an upright ladder up through a hatch to the floor above. The villagers sleep up there
## (see VillageBeds): as many beds as fit along its back wall beside the hatch, kept as places
## (`pos`, `rot`, `stand` like a bed one lies in, see Level.lie_spot). The ladder's climb is kept as
## `ladder` (where one stands at its foot), `ladder_edge` (on the hatch's edge, on the floor),
## `ladder_push` (the flat way from the foot to the top), `ladder_tall` and `ladder_top` (where one
## steps off upstairs), all world.
func _furnish_house(rec: Dictionary, w: float, d: float, door_x: float) -> void:
	var house: Node3D = rec.node
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var side := -1.0 if door_x >= 0.0 else 1.0
	var turn := house.transform.basis.orthonormalized()
	# The ladder, its climb across the room towards the side wall.
	var edge := Vector3(side * (room.end.x - LADDER_EDGE_IN), floor_y, room.end.y - LADDER_FROM_FRONT)
	var tall := float(rec.top) - floor_y
	var ladder := WalkInFurniture.upright_ladder(tall)
	ladder.position = edge
	ladder.rotation.y = 0.0 if side > 0.0 else PI
	house.add_child(ladder)
	_solid(rec, edge + Vector3(-side * WalkInFurniture.LADDER_BEFORE, 1.0, 0), Vector3(0.2, 2.0, WalkInFurniture.LADDER_WIDE + 0.1))
	var push := turn * Vector3(side, 0, 0)
	rec["ladder_push"] = push
	rec["ladder_edge"] = house.transform * edge
	rec["ladder_tall"] = tall * house.scale.y
	rec["ladder"] = house.transform * (edge - Vector3(side * LADDER_FOOT, 0, 0))
	rec["ladder_top"] = house.transform * (edge + Vector3(side * LadderPose.TOP_FORWARD, tall, 0))
	# The table in the middle, a little back from the way to the ladder, stools behind and beside it.
	var table_at := Vector3(-side * 0.3, floor_y, room.get_center().y - 0.3)
	var table := WalkInFurniture.table(0.55)
	table.position = table_at
	house.add_child(table)
	_solid(rec, table_at + Vector3(0, 0.4, 0), Vector3(1.1, 0.8, 1.1))
	for at: Vector3 in [Vector3(-0.8, 0, 0), Vector3(0.8, 0, 0), Vector3(0, 0, -0.8)]:
		var stool := WalkInFurniture.stool()
		stool.position = table_at + at
		house.add_child(stool)
	var mug := WalkInFurniture.mug()
	mug.position = table_at + Vector3(0.15, 0.79, -0.1)
	house.add_child(mug)
	# A shelf of stores on the back wall, on the ladder's side.
	var shelf_w := minf(1.8, room.size.x * 0.35)
	var shelf_at := Vector3(side * (room.size.x * 0.5 - shelf_w * 0.5 - 0.3), floor_y, room.position.y + 0.2)
	var shelf := WalkInFurniture.shelf(shelf_w, 1.9, 0.4, true)
	shelf.position = shelf_at
	house.add_child(shelf)
	_solid(rec, shelf_at + Vector3(0, 0.95, 0), Vector3(shelf_w, 1.9, 0.4))
	# Barrels, a crate and a sack in the back corner on the door's side.
	var corner := Vector3(-side * (room.end.x - 0.4), floor_y, room.position.y + 0.4)
	for k in 2:
		var barrel := WalkInFurniture.barrel()
		barrel.position = corner + Vector3(side * 0.7 * k, 0, 0)
		house.add_child(barrel)
	var crate := WalkInFurniture.crate(0.55)
	crate.position = corner + Vector3(0, 0, 0.75)
	crate.rotation.y = 0.2
	house.add_child(crate)
	var sack := WalkInFurniture.sack()
	sack.position = corner + Vector3(side * 1.35, 0, 0.05)
	house.add_child(sack)
	_solid(rec, corner + Vector3(side * 0.35, 0.45, 0.3), Vector3(1.4, 0.9, 1.4))
	# The beds upstairs: heads to the back wall, from the side wall away from the hatch.
	var t := VillageHouse.WALL_THICK
	var upper := Rect2(-w * 0.5 - VillageHouse.JETTY + t, -d * 0.5 - VillageHouse.JETTY + t,
			w + (VillageHouse.JETTY - t) * 2.0, d + (VillageHouse.JETTY - t) * 2.0)
	var up_y := float(rec.top) + VillageHouse.FLOOR_LIFT
	var count := clampi(int((upper.size.x - HATCH_CLEAR + BED_GAP) / (BED_WIDE + BED_GAP)), 1, MAX_BEDS)
	var origin_z := upper.position.y + 0.02 - CosyBed.HEAD
	for i in count:
		var mid := -side * (upper.end.x - 0.05 - BED_WIDE * 0.5 - i * (BED_WIDE + BED_GAP))
		var origin := Vector3(mid - (CosyBed.LEFT + CosyBed.RIGHT) * 0.5, up_y, origin_z)
		rec.beds.append({"pos": house.transform * origin, "rot": house.rotation.y, "by": null,
				"stand": house.transform * Vector3(mid + 0.1, up_y, origin_z + CosyBed.FOOT + 0.55)})


## The lamp that lights a house or hall while the hero is inside.
func _lamp(rec: Dictionary) -> void:
	var house: Node3D = rec.node
	var room: Rect2 = rec.room
	var lamp := OmniLight3D.new()
	lamp.name = "WalkInLamp"
	lamp.light_color = LAMP_COLOUR
	lamp.light_energy = LAMP_ENERGY
	lamp.omni_range = LAMP_RANGE
	lamp.position = Vector3(0, rec.top - 0.6, room.get_center().y)
	lamp.visible = false
	house.add_child(lamp)
	rec["lamp"] = lamp


## Pews in two rows either side of an aisle, facing the altar under the rose window, and the altar
## with its candles; a floor of stone flags.
func _furnish_temple(rec: Dictionary, chapel: Node3D) -> void:
	var s := chapel.scale.x
	var inside := Node3D.new()
	inside.name = "TempleInside"
	# The furniture is built in metres: undo the kit's scale.
	inside.scale = Vector3.ONE / s
	chapel.add_child(inside)
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor * s
	var floor_mesh := WalkInFurniture.flagstones(Vector2(room.size.x, room.size.y + 1.0) * s, floor_y)
	# Up at the floor's height, not on the ground: down there it lay in the grass and flickered with it.
	floor_mesh.position = Vector3(room.get_center().x * s, floor_y, (room.get_center().y + 0.5) * s)
	inside.add_child(floor_mesh)
	# The altar, under the rose window.
	var altar_z := (room.position.y + 2.2) * s
	var altar := WalkInFurniture.altar()
	altar.position = Vector3(0, floor_y, altar_z)
	inside.add_child(altar)
	_solid_kit(rec, Vector3(0, 2.5, altar_z / s), Vector3(WalkInFurniture.ALTAR_SIZE.x, 5.0, WalkInFurniture.ALTAR_SIZE.z) / s)
	# The pews: rows from the altar's front to the door, an aisle down the middle.
	var aisle := 1.7
	var pew_w := (room.size.x * s - aisle) * 0.5 - 0.35
	var first := altar_z + 1.9
	var last := (NAVE_DOOR_Z - 4.0) * s
	var rows := maxi(1, int((last - first) / WalkInFurniture.PEW_STEP) + 1)
	for r in rows:
		var z := first + r * WalkInFurniture.PEW_STEP
		for side: float in [-1.0, 1.0]:
			var x := side * (aisle * 0.5 + pew_w * 0.5)
			var pew := WalkInFurniture.pew(pew_w)
			pew.position = Vector3(x, floor_y, z)
			inside.add_child(pew)
			_solid_kit(rec, Vector3(x, 0.5, z) / s, Vector3(pew_w, 1.0, WalkInFurniture.PEW_DEPTH) / s)


# --- Walls that hide and stop (see Level.fixed_walls) ----------------------------

## The walls of a house for sight, reach, blows and shots, cut where the windows and the doorway are.
func _walls_of_house(rec: Dictionary, w: float, d: float, door_x: float) -> void:
	var t := VillageHouse.WALL_THICK
	var x0 := -w * 0.5
	var x1 := w * 0.5
	var zb := -d * 0.5 + t * 0.5
	var zf := d * 0.5 - t * 0.5
	var y: float = rec.floor
	var high := VillageHouse.GROUND
	var half := HouseDoor.WIDTH * 0.5
	_wall(rec, Vector3(x0, y, zb), Vector3(x1, y, zb), high)
	var front_gaps := VillageHouse._window_spots(w, door_x)
	var cuts := [[door_x - half, door_x + half, "door"]]
	for x: float in front_gaps:
		cuts.append([x - 0.4, x + 0.4, "window"])
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var at := x0
	for c: Array in cuts:
		_wall(rec, Vector3(at, y, zf), Vector3(c[0], y, zf), high)
		if c[2] == "door":
			_wall(rec, Vector3(c[0], y, zf), Vector3(c[1], y, zf), high, rec.leaf)
		else:
			_pane(rec, Vector3(c[0], y, zf), Vector3(c[1], y, zf), high)
		at = c[1]
	_wall(rec, Vector3(at, y, zf), Vector3(x1, y, zf), high)
	for side: float in [-1.0, 1.0]:
		var x := side * (w * 0.5 - t * 0.5)
		_wall(rec, Vector3(x, y, -d * 0.5), Vector3(x, y, -0.4), high)
		_pane(rec, Vector3(x, y, -0.4), Vector3(x, y, 0.4), high)
		_wall(rec, Vector3(x, y, 0.4), Vector3(x, y, d * 0.5), high)
	var corners: Array = [Vector3(x0, 0, -d * 0.5), Vector3(x1, 0, d * 0.5)]
	_roof_over(rec, corners, rec.top)


## The temple's walls, in the kit's metres: the stained glass is no window to look through.
func _walls_of_temple(rec: Dictionary) -> void:
	var x0 := NAVE.position.x - 0.5
	var x1 := NAVE.end.x + 0.5
	var z0 := NAVE.position.y - 0.5
	var zf := NAVE_DOOR_Z + 0.5
	_wall(rec, Vector3(x0, 0, z0), Vector3(x1, 0, z0), NAVE_WALL)
	_wall(rec, Vector3(x0, 0, z0), Vector3(x0, 0, zf), NAVE_WALL)
	_wall(rec, Vector3(x1, 0, z0), Vector3(x1, 0, zf), NAVE_WALL)
	_wall(rec, Vector3(x0, 0, zf), Vector3(NAVE_DOOR_X.x, 0, zf), NAVE_WALL)
	_wall(rec, Vector3(NAVE_DOOR_X.x, 0, zf), Vector3(NAVE_DOOR_X.y, 0, zf), NAVE_WALL, rec.get("leaf"))
	_wall(rec, Vector3(NAVE_DOOR_X.y, 0, zf), Vector3(x1, 0, zf), NAVE_WALL)
	_roof_over(rec, [Vector3(x0, 0, z0), Vector3(x1, 0, zf)], NAVE_WALL)


## A stretch of wall from `a` to `b` (the building's frame, on the floor it stands on), `high` tall,
## with the door that closes it if it is a doorway.
func _wall(rec: Dictionary, a: Vector3, b: Vector3, high: float, door: Node = null) -> void:
	var node: Node3D = rec.node
	var wa := node.global_transform * a
	var wb := node.global_transform * b
	var entry := {"a": Vector2(wa.x, wa.z), "b": Vector2(wb.x, wb.z), "y": wa.y, "h": high * node.scale.y}
	if door != null:
		entry["door"] = door
	(level.get("fixed_walls") as Array).append(entry)


## A window pane in a wall: seen through, but not reached, struck or shot through.
func _pane(rec: Dictionary, a: Vector3, b: Vector3, high: float) -> void:
	var node: Node3D = rec.node
	var wa := node.global_transform * a
	var wb := node.global_transform * b
	(level.get("fixed_windows") as Array).append({"a": Vector2(wa.x, wa.z), "b": Vector2(wb.x, wb.z), "y": wa.y, "h": high * node.scale.y})


## The ceiling over the room at `top` (the building's frame), between two corners.
func _roof_over(rec: Dictionary, corners: Array, top: float) -> void:
	var node: Node3D = rec.node
	var a := node.global_transform * Vector3(corners[0].x, top, corners[0].z)
	var b := node.global_transform * Vector3(corners[1].x, top, corners[1].z)
	var rect := Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(b.x - a.x), absf(b.z - a.z)))
	(level.get("fixed_floors") as Array).append({"rect": rect, "y": a.y})


## The block tiles of an opened building (no longer solid to sight and reach, see opens) and what
## shows from the start.
func _finish(rec: Dictionary) -> void:
	var cells := {}
	var block: Rect2i = rec.block
	for y in range(block.position.y, block.end.y):
		for x in range(block.position.x, block.end.x):
			cells[Vector2i(x, y)] = true
	rec["cells"] = cells
	rec["opened"] = true


# --- Questions about the buildings -----------------------------------------------

## Whether a map tile belongs to a building one can walk into: it does not block sight or reach by
## itself, its walls do (see Level.fixed_walls).
func opens(c: Vector2i) -> bool:
	if open_cells.has(c):
		return true
	for rec in buildings:
		if rec.get("opened", false) and rec.cells.has(c):
			return true
	return false


## The building whose room holds the point `pos` (world), or {}. `margin` widens the room.
func building_at(pos: Vector3, margin := 0.0) -> Dictionary:
	for rec in buildings:
		if not rec.get("opened", false):
			continue
		var node: Node3D = rec.node
		var p := node.global_transform.affine_inverse() * pos
		if p.y > float(rec.top):
			continue
		var room: Rect2 = rec.room
		if room.grow(margin / node.scale.x).has_point(Vector2(p.x, p.z)):
			return rec
	return {}


## Whether a point lies in a room, out of the weather.
func covers(pos: Vector3) -> bool:
	return not building_at(pos).is_empty()


## How high the floor is at `pos` (world) for someone walking in: the boards in a room and its
## doorway, the ramp up to a house door, the ground elsewhere.
func floor_at(pos: Vector3) -> float:
	for rec in buildings:
		if not rec.get("opened", false):
			continue
		var node: Node3D = rec.node
		var p := node.global_transform.affine_inverse() * pos
		var room: Rect2 = rec.room
		var door: Vector3 = rec.door
		var in_door := absf(p.x - door.x) <= DOOR_GAP * 0.5 / node.scale.x + 0.2
		var wall_out: float = rec.wall_out
		var floor_y: float = rec.floor
		if room.has_point(Vector2(p.x, p.z)) or (in_door and p.z >= room.end.y and p.z <= wall_out):
			return node.global_position.y + floor_y * node.scale.y
		if rec.kind == "temple" and absf(p.x) <= PORCH_HALF and p.z > wall_out and p.z < PORCH_END:
			return node.global_position.y + NAVE_FLOOR * node.scale.y * clampf((PORCH_END - p.z) / (PORCH_END - PORCH_LANDING), 0.0, 1.0)
		if rec.kind != "temple" and in_door and p.z > wall_out and p.z < wall_out + RAMP:
			return node.global_position.y + floor_y * (1.0 - (p.z - wall_out) / RAMP)
	return 0.0


## The way in for someone walking: a point just outside the door (on the ground) and one just inside
## it (on the floor), world.
func door_points(rec: Dictionary) -> Array[Vector3]:
	var node: Node3D = rec.node
	var door: Vector3 = rec.door
	var s := node.scale.x
	var room: Rect2 = rec.room
	var outside := node.global_transform * Vector3(door.x, 0.0, float(rec.wall_out) + (RAMP + 0.4) / s)
	var inside := node.global_transform * Vector3(door.x, float(rec.floor), room.end.y - 0.6 / s)
	return [outside, inside]


## The house whose door is nearest to `pos` within `reach` metres, or {}. A house that belongs to
## one villager alone (its "owner", see SmithCottage) is only theirs: `role` finds it first.
func house_near(pos: Vector3, reach := 9.0, role := "") -> Dictionary:
	var best := {}
	var best_d := reach
	for rec in buildings:
		if rec.kind != "house" or not rec.get("opened", false):
			continue
		var owner := String(rec.get("owner", ""))
		if owner != "" and owner != role:
			continue
		if owner != "" and owner == role:
			var at: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
			if Vector2(at.x - pos.x, at.z - pos.z).length() < reach:
				return rec
		var door: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
		var dist := Vector2(door.x - pos.x, door.z - pos.z).length()
		if dist < best_d:
			best = rec
			best_d = dist
	return best


## The way for the hero from `from` to `to` (world) when either lies inside a building one can walk
## into: through its door, along the grid outside. Empty when neither does (the grid alone does).
func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var a := building_at(from, 0.3)
	var b := building_at(to, 0.3)
	if a.is_empty() and b.is_empty():
		return out
	if not a.is_empty() and a.get("node") == b.get("node"):
		out.append(to)
		return out
	var start := from
	if not a.is_empty():
		var way := door_points(a)
		out.append(way[1])
		out.append(way[0])
		start = way[0]
	var goal := to
	var way_in: Array[Vector3] = []
	if not b.is_empty():
		way_in = door_points(b)
		goal = way_in[0]
	var cells: Array[Vector2i] = level.call("grid_path", level.call("world_to_cell", start), level.call("world_to_cell", goal))
	for c in cells.slice(1):
		out.append(level.call("cell_to_world", c))
	if not b.is_empty():
		out.append(way_in[0])
		out.append(way_in[1])
	out.append(to)
	return out


# --- Every frame -------------------------------------------------------------------

## Opens the doors before the hero, and hides the floor above and the front wall of the building the
## hero stands in.
func tick(hero: Node3D, delta: float) -> void:
	if hero == null or buildings.is_empty():
		return
	var at := hero.global_position
	var now := building_at(at, 0.1)
	if now.is_empty() and not hero_in.is_empty() and not building_at(at, 0.6).is_empty():
		now = hero_in # Still in the doorway: no flicker.
	if now.get("node") != hero_in.get("node"):
		if not hero_in.is_empty():
			_show_inside(hero_in, false)
		hero_in = now
		if not hero_in.is_empty():
			_show_inside(hero_in, true)
	var cam := level.get_viewport().get_camera_3d() if level.is_inside_tree() else null
	for rec in buildings:
		if not rec.get("opened", false):
			continue
		_mind_door(rec, at, delta)
		_mind_fade(rec, delta)
		if cam != null:
			_mind_cover(rec, cam.global_position, at, delta)


func _mind_door(rec: Dictionary, hero_at: Vector3, delta: float) -> void:
	var leaf = rec.get("leaf")
	if leaf == null or not is_instance_valid(leaf):
		return
	rec.push = float(rec.push) - delta
	var door: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
	if Vector2(door.x - hero_at.x, door.z - hero_at.z).length() < DOOR_REACH and rec.push <= 0.0:
		rec.push = PUSH_EVERY
		(leaf as HouseDoor).swing()
	var shape: CollisionShape3D = rec.get("door_shape")
	if shape:
		shape.disabled = (leaf as HouseDoor).openness() > 0.25


## The roof of a house or hall that hides the hero behind it from the camera, head to foot, is
## lifted off (with the floor above): the hero shows, and so does the room under it. It comes back
## once the hero is out from behind it again, a moment later so it does not flicker at the edge.
func _mind_cover(rec: Dictionary, cam: Vector3, hero_at: Vector3, delta: float) -> void:
	if rec.kind == "temple" or not (rec.node as Node3D).has_meta("shape"):
		return
	var covers := _covers(rec, cam, hero_at)
	var wait := float(rec.get("cover_wait", 0.0))
	wait = COVER_LINGER if covers else maxf(0.0, wait - delta)
	rec["cover_wait"] = wait
	var off := wait > 0.0
	if off != bool(rec.get("roof_off", false)):
		rec["roof_off"] = off
		_show_up(rec)


## Whether the roof and floor above of `rec` stand between the camera at `cam` and the whole hero
## at `hero_at`: the sight lines to their feet and to their head both pass through them.
func _covers(rec: Dictionary, cam: Vector3, hero_at: Vector3) -> bool:
	var node: Node3D = rec.node
	var shape: Dictionary = node.get_meta("shape")
	var out := VillageHouse.JETTY + VillageHouse.ROOF_OVERHANG
	var top: float = rec.top
	var high := VillageHouse.UPPER + float(shape.ridge) * 1.3
	var box := AABB(Vector3(-float(shape.w) * 0.5 - out, top, -float(shape.d) * 0.5 - out),
			Vector3(float(shape.w) + out * 2.0, high, float(shape.d) + out * 2.0))
	var to_local := node.global_transform.affine_inverse()
	var eye := to_local * cam
	for lift: float in [COVER_FEET, COVER_HEAD]:
		if box.intersects_segment(eye, to_local * (hero_at + Vector3(0, lift, 0))) == null:
			return false
	return true


## Shows the floor above and the roof unless the hero is inside or behind it (see _mind_cover).
func _show_up(rec: Dictionary) -> void:
	var shown := not bool(rec.inside) and not bool(rec.get("roof_off", false))
	for part in rec.up:
		if is_instance_valid(part):
			(part as Node3D).visible = shown


## Hides (or shows again) what stands between the camera and the room.
func _show_inside(rec: Dictionary, inside: bool) -> void:
	rec.inside = inside
	_show_up(rec)
	for side: String in SIDES:
		if not rec.has(side):
			continue
		# A house hides its front (its door faces the street, towards the camera); a hall hides
		# whichever walls face the camera.
		var hide := inside and (not rec.has("sided") or _faces_camera(rec, side))
		for part in rec[side]:
			if is_instance_valid(part):
				(part as Node3D).visible = not hide
	var lamp: OmniLight3D = rec.get("lamp")
	if lamp:
		lamp.visible = inside


## Which wall of a sided hall a leaf of ivy at `at` (the hall's frame) grows on, or "".
func _side_of(rec: Dictionary, at: Vector3) -> String:
	var shape: Dictionary = (rec.node as Node3D).get_meta("shape")
	var hw := float(shape.w) * 0.5
	var hd := float(shape.d) * 0.5
	if at.z >= hd - ON_WALL:
		return "front"
	if at.z <= -hd + ON_WALL:
		return "back"
	if at.x >= hw - ON_WALL:
		return "right"
	if at.x <= -hw + ON_WALL:
		return "left"
	return ""


## Whether a wall of a building faces the camera, which looks north (-z) from the south: it would
## stand between the camera and the room.
func _faces_camera(rec: Dictionary, side: String) -> bool:
	var normal: Vector3 = (rec.node as Node3D).global_transform.basis * (SIDE_NORMALS[side] as Vector3)
	return normal.normalized().z > 0.3


## The temple's front wall fades out while the hero is inside and back in once they leave.
func _mind_fade(rec: Dictionary, delta: float) -> void:
	if not rec.has("front_pieces"):
		return
	var goal := FRONT_FADED if rec.inside else 0.0
	var amount: float = rec.fade
	if is_equal_approx(amount, goal):
		return
	amount = move_toward(amount, goal, delta / FADE_TIME)
	rec.fade = amount
	if not rec.has("fade_meshes"):
		var meshes := []
		for p: Node3D in rec.front_pieces:
			meshes.append_array(WallFade._fadeable(p))
		rec["fade_meshes"] = meshes
	for m in rec.fade_meshes:
		if not is_instance_valid(m.mesh):
			continue
		if m.get("relief", false):
			(m.mesh as Node3D).visible = amount < 0.5
		if m.stone:
			(m.mesh as GeometryInstance3D).set_instance_shader_parameter("fade", amount)
		for i in m.plain.size():
			# Blended, not dithered: a see-through wall reads as glass, and the dither of
			# WallFade's alpha hash did not show through the kit's bricks. Solid again once
			# the hero is out, so the wall sorts like any other.
			var mat: BaseMaterial3D = m.plain[i]
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if amount > 0.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color.a = m.alpha[i] * (1.0 - amount)
