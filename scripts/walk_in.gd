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
static var halls := {"n": true, "m": true, "o": true, "k": true, "w": true, "u": true, "Ø": true}

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
## The doorway as wide as the walls stop the hero (wider than the leaf, so the hero, 1.1 m across,
## walks straight through with 0.2 m to spare on each side and is never nudged by the frame).
const DOOR_GAP := 1.5
## How far in front of a house door the ramp up to its floor starts (metres): up the step and
## over the threshold, PLINTH high.
const RAMP := 1.0
## How long between two pushes on a door the hero stands at (seconds).
const PUSH_EVERY := 0.4
## Whether a hall whose keeper is not inside and awake keeps its door locked (see VillagePosts.locked);
## tests that walk into halls at any hour switch it off.
static var lock_halls := true
## How long between two "the door is locked" words to the hero (seconds).
const LOCKED_EVERY := 4.0
## The warm light in a house while the hero is inside.
const LAMP_COLOUR := Color(1.0, 0.76, 0.48)
const LAMP_ENERGY := 1.0
const LAMP_RANGE := 6.5
## How steeply the lamp's light falls off near it (Godot's omni_attenuation, 1 by default). It
## hangs under the ceiling over the middle of the room, where the keeper often stands: with the
## usual fall-off a miller's hat right under it glared white. A flatter one lights the room as
## before and the one under it far less.
const LAMP_FALLOFF := 0.5
## The candles in iron sconces on the walls inside (see _sconces): how high over a floor they hang
## (metres), and when they burn, each building from its own moment in LIGHT_FROM (hours, as the sun
## goes down) till its own bedtime in BED_TIME (hours, past midnight counted on from 24).
const SCONCE_HIGH := 1.95
const LIGHT_FROM := Vector2(18.9, 19.6)
const BED_TIME := Vector2(22.0, 25.0)
## How see-through the temple's front wall gets while the hero is inside (0 solid, 1 gone).
const FRONT_FADED := 0.8
const FADE_TIME := 0.25
## The walk between the altar and the first pews (metres), roomy for the hero.
const ALTAR_WALK := 1.7
## Sitting in the pews (see temple_seats): how close two may sit side by side (they share the pew evenly), how far in front of
## a pew's front edge one stands to sit down, and how far before the altar the priestess stands.
const SEAT_GAP := 0.75
## The closest two sit on one pew when the village is large, how far behind the last pew's back the
## standing row is, and how far off the middle (the way in from the door) its first place lies.
const SEAT_TIGHT := 0.65
const STAND_BACK := 0.5
const STAND_AISLE := 1.1
const SIT_STAND := 0.4
const PULPIT_GAP := 0.55
## A villagers' house's rug under the table (metres across, deep), and how high over the floor the
## candle shelf hangs on the back wall, and how far off the middle (away from the store shelf).
const RUG_SIZE := Vector2(2.2, 1.6)
const SHELF_HIGH := 1.75
const SHELF_OFF := 0.4
## The beds of a house, on the floor above: two along its back wall from the side away from the
## hatch, or one where the hatch leaves no room for a second. Two villagers to a house at most.
const MAX_BEDS := 2
## The house ladder (see _furnish_house): it stands by the side wall away from the door, the climb
## going from that wall into the room. How far in from the wall the hatch's edge is (the climb's
## edge), how far back from the front wall the middle of the ladder stands, how far from the edge
## towards the wall one stands at its foot, and the hatch's size (from the edge to the wall, and
## along it).
const LADDER_EDGE_IN := 1.25
const LADDER_FROM_FRONT := 0.6
const LADDER_FOOT := 0.65
const HATCH := Vector2(0.9, 0.9)
## Upstairs, round the hatch and the spot where the climb ends, the floor the beds keep clear of
## (metres from the hatch's edge into the room, and before the hatch towards the back).
const HATCH_CLEAR := Vector2(1.3, 0.45)
## How thick the floor above is under its boards (its collision slab).
const UPPER_SLAB := 0.3
## Feet this far below the floor above count as up there (on the ladder, the head above the boards).
const UPPER_FROM := 1.0
## The wall between the parents' and the children's beds upstairs: the extra gap it gets between the
## beds (metres), its height, and the doorway's width.
const PARTITION_GAP := 0.2
const PARTITION_HIGH := 2.5
const PARTITION_DOOR := 1.5
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
## How high the doorway's opening is and how tall the kit's door leaf is (kit metres, measured from the meshes).
const NAVE_DOORWAY_TOP := 7.67
const DOOR_LEAF_HEIGHT := 6.72
const NAVE_WALL_OUT := 12.0
const PORCH_HALF := 4.0
const PORCH_LANDING := 15.2
const PORCH_END := 18.2
const NAVE_ROOF := 15.8
const NAVE_FRONT := 10.3
## A building's walls, by the way they face in its own frame: the front (its door, +z), the back,
## its left (-x) and right (+x).
const SIDES := ["front", "back", "left", "right"]
## The walls of an upper storey one walks into (the guildhall's, see GuildHall), by side.
const STOREY_SIDES := ["storey_front", "storey_back", "storey_left", "storey_right"]
## The walls of a mage tower's top room (see MageTower), by side.
const TOP_SIDES := ["top_front", "top_back", "top_left", "top_right"]
const SIDE_NORMALS := {"front": Vector3(0, 0, 1), "back": Vector3(0, 0, -1), "left": Vector3(-1, 0, 0), "right": Vector3(1, 0, 0)}
## How near a wall (metres) a leaf of ivy counts as growing on it (see split_ivy).
const ON_WALL := 0.45

var level: Node3D
## One entry per building (see claim): its node, its kind ("house" or "temple") and everything
## made for it.
var buildings: Array = []
## The building the hero stands in, or {}.
var hero_in: Dictionary = {}
## Whether the hero is up on the floor above of that building (see is_upstairs).
var hero_up := false


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
		if bool(shape.get("flat", false)):
			# Two storeys and a roof one walks on, a cellar under them (see GuildHall): the hero is
			# inside up to over the parapet, and the storey they stand on shows (see _show_storey).
			var lay := GuildHall.layout(shape)
			rec["wall_high"] = rec.top
			rec["storey"] = GuildHall.GROUND_STOREY
			rec["high"] = float(lay.deck) + 2.5
			rec["eaves"] = lay.eaves
			if bool(shape.get("mage", false)):
				# The top room has walls and a roof (see MageTower): the weather keeps out up there too.
				rec["mage"] = true
				rec["deck_top"] = float(lay.deck) + MageTower.TOP_H - 0.02
				rec["high"] = float(lay.deck) + MageTower.TOP_H + MageTower.PEAK + MageTower.SPIRE
				rec["tower_roof"] = []
				# The ivy on the roof lifts off with it.
				rec["ivy_roof"] = {}
				rec["roof"] = rec.tower_roof
				for side: String in TOP_SIDES:
					rec[side] = []
					rec["ivy_" + side] = {}
			else:
				rec["deck"] = lay.deck
			rec["storey_room"] = []
			for side: String in STOREY_SIDES:
				rec[side] = []
				rec["ivy_" + side] = {}
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
				if rec.has("mage") and at.y >= float(rec.deck_top):
					# On the pyramid roof: it lifts off with it.
					into = rec.ivy_roof
				elif rec.has("mage") and at.y >= float(rec.eaves):
					# On a wall of the top room: it hides with that wall.
					var top_side := _side_of(rec, at)
					if top_side != "":
						into = rec["ivy_top_" + top_side]
				elif rec.has("storey_room") and at.y < float(rec.eaves):
					# On a wall of an upper storey one walks into: it hides with that wall.
					var up_side := _side_of(rec, at)
					if up_side != "":
						into = rec["ivy_storey_" + up_side]
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
		for group: String in ["up"] + SIDES + STOREY_SIDES + TOP_SIDES + ["roof"]:
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
	# A villagers' house has a floor above one climbs to; Gorm's cottage (see SmithCottage) does not.
	var upper: bool = (rec.kind == "house" and not rec.has("owner")) or rec.kind == "tavern" or VillageHalls.HOME_OWNERS.has(rec.kind)
	var hatch := hatch_of(house.get_meta("shape")) if upper else Rect2()
	var meshes := VillageHouse.hollow(house, rec.has("sided"), hatch)
	if upper:
		# The floor above one climbs to: its roof hides with the rest of `up`, its walls stay while
		# the hero is up there, its front wall hides, and its room shows only then.
		rec.up.append(meshes.roof)
		rec["up_walls"] = [meshes.up]
		rec["up_front"] = [meshes.up_front]
		rec["up_room"] = [meshes.up_inside]
		meshes.up_inside.visible = false
	else:
		rec.up.append(meshes.up)
	rec.front.append(meshes.front)
	if rec.has("sided"):
		for side: String in ["back", "left", "right"]:
			rec[side].append(meshes[side])
	if rec.has("storey_room"):
		rec.storey_room.append(meshes.storey_room)
		for side: String in STOREY_SIDES:
			rec[side].append(meshes[side])
	if rec.has("mage"):
		for side: String in TOP_SIDES:
			rec[side].append(meshes[side])
		rec.tower_roof.append(meshes.top_roof)
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
	# The walls, from their inner faces to a little past the outer ones, and the floor. Up to the
	# floor above where one can climb to it (its own walls stand further out, on the jetty), or up to
	# the floor above in a hall with an upper storey one walks into (GuildHall lays its own floor,
	# open over the stairs down).
	var high := float(rec.top) - UPPER_SLAB if upper else float(rec.get("wall_high", 4.0))
	var mid := high * 0.5
	_solid(rec, Vector3(0, mid, -d * 0.5 + (t - out) * 0.5), Vector3(w + out * 2.0, high, t + out))
	for s: float in [-1.0, 1.0]:
		_solid(rec, Vector3(s * (w * 0.5 + (out - t) * 0.5), mid, 0), Vector3(t + out, high, d + out * 2.0))
	var gap_l := door_x - DOOR_GAP * 0.5
	var gap_r := door_x + DOOR_GAP * 0.5
	var z_front := d * 0.5 + (out - t) * 0.5
	_solid(rec, Vector3((-w * 0.5 - out + gap_l) * 0.5, mid, z_front), Vector3(gap_l + w * 0.5 + out, high, t + out))
	_solid(rec, Vector3((w * 0.5 + out + gap_r) * 0.5, mid, z_front), Vector3(w * 0.5 + out - gap_r, high, t + out))
	if upper:
		_upper_solids(rec, w + VillageHouse.JETTY * 2.0, d + VillageHouse.JETTY * 2.0, hatch)
	if not rec.has("storey_room"):
		_solid(rec, Vector3(0, floor_y * 0.5, 0), Vector3(w, floor_y, d))
	rec["door_shape"] = _solid(rec, Vector3(door_x, 1.4, d * 0.5 - t * 0.5), Vector3(DOOR_GAP, 2.8, t))
	_ramp(rec, door_x, d * 0.5, floor_y)
	if rec.kind == "house" and rec.has("owner"):
		SmithCottage.furnish(self, rec)
	elif rec.kind == "house":
		_furnish_house(rec, w, d, door_x)
	else:
		VillageHalls.furnish(self, rec)
		if rec.kind == "tavern":
			_loft(rec, w, d, hatch)
		elif VillageHalls.HOME_OWNERS.has(rec.kind):
			# The shop, the post office and the Crown office have bedrooms upstairs, one bed for
			# each of the family or staff who live there (see VillageHalls.HOME_OWNERS).
			_bedroom(rec, w, d, hatch, VillageHalls.HOME_OWNERS[rec.kind])
	_lamp(rec)
	_sconces(rec)
	# Only a building one cannot walk into throws the light of its lit panes on the ground (see
	# WindowSpill): this one has clear windows, and its candles' light falls out through them. (The
	# pools are only taken away now: the ivy was laid out round them, as on every other house.)
	var spill := house.get_node_or_null("WindowSpill")
	if spill:
		house.remove_child(spill)
		spill.free()
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
		# The kit's leaf is 6.72 tall but its doorway 7.67: stretch it so no gap shows over the door.
		door_piece.scale.y = NAVE_DOORWAY_TOP / DOOR_LEAF_HEIGHT
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

## Which way from the middle the house ladder stands: by the side wall away from the door.
static func ladder_side(door_x: float) -> float:
	return -1.0 if door_x >= 0.0 else 1.0


## The ladder's side of a built house: a hall may choose it (shape "ladder_side", see
## VillageHalls.style), a house puts it away from the door.
static func ladder_side_of(shape: Dictionary) -> float:
	if shape.has("ladder_side"):
		return float(shape.ladder_side)
	return ladder_side(float(shape.door_x))


## The hatch in the floor above a villagers' house (see VillageHouse.hollow), in the house's frame
## (x, z): between the climb's edge and the side wall away from the door, near the front.
static func hatch_of(shape: Dictionary) -> Rect2:
	var side := ladder_side_of(shape)
	var r := float(shape.w) * 0.5 - VillageHouse.WALL_THICK
	var z := float(shape.d) * 0.5 - VillageHouse.WALL_THICK - LADDER_FROM_FRONT
	var near := r - LADDER_EDGE_IN
	var x0 := near if side > 0.0 else -(near + HATCH.x)
	return Rect2(x0, z - HATCH.y * 0.5, HATCH.x, HATCH.y)


## The floor above a house one can climb to: its slab round the hatch, and its walls (on the
## jetty, `uw` x `ud`) up to the eaves.
func _upper_solids(rec: Dictionary, uw: float, ud: float, hatch: Rect2) -> void:
	var top: float = rec.top
	var y := top + VillageHouse.FLOOR_LIFT - UPPER_SLAB * 0.5
	var x0 := -uw * 0.5
	var z0 := -ud * 0.5
	_solid(rec, Vector3((x0 + hatch.position.x) * 0.5, y, 0), Vector3(hatch.position.x - x0, UPPER_SLAB, ud))
	_solid(rec, Vector3((hatch.end.x - x0) * 0.5, y, 0), Vector3(-x0 - hatch.end.x, UPPER_SLAB, ud))
	_solid(rec, Vector3(hatch.get_center().x, y, (z0 + hatch.position.y) * 0.5), Vector3(hatch.size.x, UPPER_SLAB, hatch.position.y - z0))
	_solid(rec, Vector3(hatch.get_center().x, y, (hatch.end.y - z0) * 0.5), Vector3(hatch.size.x, UPPER_SLAB, -z0 - hatch.end.y))
	var t := VillageHouse.WALL_THICK
	var out := 0.15
	var mid := top + VillageHouse.UPPER * 0.5
	var high := VillageHouse.UPPER
	for s: float in [-1.0, 1.0]:
		_solid(rec, Vector3(0, mid, s * (ud * 0.5 + (out - t) * 0.5)), Vector3(uw + out * 2.0, high, t + out))
		_solid(rec, Vector3(s * (uw * 0.5 + (out - t) * 0.5), mid, 0), Vector3(t + out, high, ud + out * 2.0))


## The ladder up through the hatch, by the side wall `side` is on, with the places the climb is
## kept as (see _furnish_house).
func _put_ladder(rec: Dictionary, side: float, hatch: Rect2) -> void:
	var house: Node3D = rec.node
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var turn := house.transform.basis.orthonormalized()
	# The ladder: its climb goes from the side wall into the room.
	var edge := Vector3(side * (room.end.x - LADDER_EDGE_IN), floor_y, hatch.get_center().y)
	var tall := float(rec.top) + VillageHouse.FLOOR_LIFT - floor_y
	var ladder := WalkInFurniture.upright_ladder(tall)
	ladder.position = edge
	ladder.rotation.y = PI if side > 0.0 else 0.0
	house.add_child(ladder)
	var push := turn * Vector3(-side, 0, 0)
	rec["ladder_push"] = push
	rec["ladder_edge"] = house.transform * edge
	rec["ladder_tall"] = tall * house.scale.y
	rec["ladder"] = house.transform * (edge + Vector3(side * LADDER_FOOT, 0, 0))
	rec["ladder_top"] = house.transform * (edge + Vector3(-side * LadderPose.TOP_FORWARD, tall, 0))
	var spot := Node3D.new()
	spot.name = "LadderSpot"
	house.add_child(spot)
	spot.add_to_group(Player.LADDER_GROUP)
	spot.set_meta("push", push)
	spot.set_meta("edge", rec.ladder_edge)
	spot.set_meta("foot", rec.ladder)
	spot.set_meta("top", rec.ladder_top)
	spot.set_meta("visual", ladder)


## The tavern's loft: the brewer's ladder up to a room with his bed (see VillageBeds), the ladder
## on the side of the wall away from the door's tables (see VillageHalls.style); he is the only
## one who sleeps here.
func _loft(rec: Dictionary, w: float, d: float, hatch: Rect2) -> void:
	var side := ladder_side_of(shape_of(rec))
	_put_ladder(rec, side, hatch)
	_furnish_upstairs(rec, w, d, side, hatch, 1)
	rec["owner"] = VillageHalls.KEEPERS.tavern


## A hall's bedrooms upstairs (the shop, the post office, the Crown office): the ladder up on the
## side wall `ladder_side_of` names, and a bed along the back wall for each of `owners`, who sleep
## here and nowhere else (see house_near, VillageBeds).
func _bedroom(rec: Dictionary, w: float, d: float, hatch: Rect2, owners: Array) -> void:
	var side := ladder_side_of(shape_of(rec))
	_put_ladder(rec, side, hatch)
	# The shop's family has two bedrooms: the parents' beds first, then the children's (see _partition).
	_furnish_upstairs(rec, w, d, side, hatch, owners.size(), 2 if owners.size() == 4 else 0)
	for i in mini(owners.size(), rec.beds.size()):
		rec.beds[i]["for"] = owners[i]
	rec["owner"] = owners[0]
	rec["owners"] = owners


## The ground floor of a house: a round table with stools, a shelf of stores on the back wall,
## barrels and a crate in the back corner on the door's side, and by the side wall away from the
## door an upright ladder up through the hatch (see hatch_of) to the room on the floor above (see
## VillageHouse.hollow), where the villagers sleep (see VillageBeds): MAX_BEDS beds along its back
## wall, each kept as a place one lies in (`pos`, `rot`, `stand`, see Level.lie_spot). The climb is
## kept as `ladder` (where one stands at its foot), `ladder_edge` (on the hatch's edge, on the
## floor), `ladder_push` (the flat way from the foot to the top), `ladder_tall` and `ladder_top`
## (where one steps off upstairs), all world, and the hero climbs it too (Player.LADDER_GROUP).
func _furnish_house(rec: Dictionary, w: float, d: float, door_x: float) -> void:
	var house: Node3D = rec.node
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var side := ladder_side(door_x)
	var hatch := hatch_of(house.get_meta("shape"))
	_put_ladder(rec, side, hatch)
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
		Seats.add_stool(self, rec, stool.position, table_at)
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
	_make_homely(rec, table_at, side)
	_furnish_upstairs(rec, w, d, side, hatch)


## The room on the floor above: MAX_BEDS beds along the back wall, heads to it, from the side wall
## away from the hatch; a bed that would reach the floor kept clear round the hatch is left out
## (one bed always stays). They show only while the hero is up there (see _show_inside).
func _furnish_upstairs(rec: Dictionary, w: float, d: float, side: float, hatch: Rect2, beds := MAX_BEDS, split := 0) -> void:
	var house: Node3D = rec.node
	var t := VillageHouse.WALL_THICK
	var upper := Rect2(-w * 0.5 - VillageHouse.JETTY + t, -d * 0.5 - VillageHouse.JETTY + t,
			w + (VillageHouse.JETTY - t) * 2.0, d + (VillageHouse.JETTY - t) * 2.0)
	var up_y := float(rec.top) + VillageHouse.FLOOR_LIFT
	var room := Node3D.new()
	room.name = "Upstairs"
	room.visible = false
	house.add_child(room)
	rec.up_room.append(room)
	# The floor kept clear: the hatch, the spot the climb ends on and the way from it.
	var inner_edge := hatch.position.x if side > 0.0 else hatch.end.x
	var clear_x0 := inner_edge - HATCH_CLEAR.x if side > 0.0 else upper.position.x
	var clear_x1 := upper.end.x if side > 0.0 else inner_edge + HATCH_CLEAR.x
	var clear := Rect2(clear_x0, hatch.position.y - HATCH_CLEAR.y, clear_x1 - clear_x0, upper.end.y - hatch.position.y + HATCH_CLEAR.y)
	var origin_z := upper.position.y + 0.02 - CosyBed.HEAD
	# With a partition wall after bed `split - 1` the beds beyond it stand PARTITION_GAP further on.
	for i in beds:
		var shift := PARTITION_GAP if split > 0 and i >= split else 0.0
		var mid := -side * (upper.end.x - 0.05 - BED_WIDE * 0.5 - i * (BED_WIDE + BED_GAP) - shift)
		var foot_z := origin_z + CosyBed.FOOT + 0.55
		var takes := Rect2(mid - BED_WIDE * 0.5, upper.position.y, BED_WIDE, origin_z + CosyBed.FOOT - upper.position.y)
		if i > 0 and takes.intersects(clear):
			break
		var origin := Vector3(mid - (CosyBed.LEFT + CosyBed.RIGHT) * 0.5, up_y, origin_z)
		var bed := CosyBed.build(room, origin, 0.0, false)
		bed.name = "VillagerBed%d" % i
		_solid(rec, Vector3(mid, up_y + 0.5, origin_z + (CosyBed.HEAD + CosyBed.FOOT) * 0.5), Vector3(BED_WIDE, 1.0, CosyBed.FOOT - CosyBed.HEAD))
		rec.beds.append({"pos": house.transform * origin, "rot": house.rotation.y, "by": null,
				"stand": house.transform * Vector3(mid + 0.1, up_y, foot_z)})
	if split > 0 and rec.beds.size() > split:
		_partition(rec, room, upper, side, up_y, origin_z, split)


## The wall between two bedrooms upstairs (the parents' beds before `split`, the children's after
## it), standing in the gap the beds leave: planks from the floor to the eaves, running from the back
## wall to the front wall, with a doorway beyond the foot of the beds. A villager in a bed on the far
## side of it walks through the doorway (the bed's "via", see VillageBeds).
func _partition(rec: Dictionary, room: Node3D, upper: Rect2, side: float, up_y: float, origin_z: float, split: int) -> void:
	var house: Node3D = rec.node
	var gap_x := -side * (upper.end.x - 0.05 - split * (BED_WIDE + BED_GAP) + BED_GAP * 0.5 - PARTITION_GAP * 0.5)
	var back := upper.position.y
	var door_from := origin_z + CosyBed.FOOT + 0.25 - back
	var length := upper.end.y - back
	if door_from + PARTITION_DOOR + 0.3 > length:
		return # A house too shallow for a wall with a doorway: one room.
	var wall := WalkInFurniture.partition(length, PARTITION_HIGH, door_from, door_from + PARTITION_DOOR)
	wall.position = Vector3(gap_x, up_y, back)
	room.add_child(wall)
	var high := PARTITION_HIGH
	var thick := WalkInFurniture.PARTITION_THICK
	_solid(rec, Vector3(gap_x, up_y + high * 0.5, back + door_from * 0.5), Vector3(thick, high, door_from))
	var front_from := door_from + PARTITION_DOOR
	_solid(rec, Vector3(gap_x, up_y + high * 0.5, back + (front_from + length) * 0.5), Vector3(thick, high, length - front_from))
	var via := house.transform * Vector3(gap_x, up_y, back + door_from + PARTITION_DOOR * 0.5)
	# The ladder is on the children's side: the beds before the wall are reached through the doorway.
	for i in mini(split, rec.beds.size()):
		rec.beds[i]["via"] = via
	rec["partition"] = {"x": gap_x, "via": via}


## What makes a villagers' house look lived in and warmly lit: a rug under the table, and a shelf
## with a burning candle on the back wall between the store shelf and the barrels, whose glow
## lights the room with the house's lamp (see _show_inside).
func _make_homely(rec: Dictionary, table_at: Vector3, ladder_side: float) -> void:
	var house: Node3D = rec.node
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var rug := WalkInFurniture.rug(Vector2(minf(RUG_SIZE.x, room.size.x - 0.6), minf(RUG_SIZE.y, room.size.y - 0.6)))
	rug.position = Vector3(table_at.x, floor_y, table_at.z)
	house.add_child(rug)
	var shelf := WalkInFurniture.candle_shelf()
	shelf.position = Vector3(-ladder_side * SHELF_OFF, floor_y + SHELF_HIGH, room.position.y)
	house.add_child(shelf)
	var glow: OmniLight3D = shelf.get_node("CandleGlow")
	glow.visible = false
	rec["glows"] = [glow]


## The lamp that lights a house or hall while the hero is inside.
func _lamp(rec: Dictionary) -> void:
	var house: Node3D = rec.node
	var room: Rect2 = rec.room
	var lamp := OmniLight3D.new()
	lamp.name = "WalkInLamp"
	lamp.light_color = LAMP_COLOUR
	lamp.light_energy = LAMP_ENERGY
	lamp.omni_range = LAMP_RANGE
	lamp.omni_attenuation = LAMP_FALLOFF
	lamp.position = Vector3(0, rec.top - 0.6, room.get_center().y)
	lamp.set_meta(LightShadows.INDOOR, true)
	lamp.visible = false
	house.add_child(lamp)
	rec["lamp"] = lamp


## The candles in sconces on the side walls of a house or hall, one storey each, which burn from
## nightfall till the household goes to bed (see set_hour): their light falls out through the
## windows. On the ground floor two, in the back half of the room clear of the side windows (and in
## the guild hall along its left wall, away from its stairs); on a floor above one climbs to one
## more, which hides with that floor's walls.
func _sconces(rec: Dictionary) -> void:
	var house: Node3D = rec.node
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var back := room.position.y + room.size.y * 0.25
	if rec.get("kind", "") == "post":
		# The post office keeps the side wall's front stretch for its window and notices.
		back = room.position.y + 0.4
	var spots := []
	if rec.has("layout"):
		var lay: Dictionary = rec.layout
		var up_room: Rect2 = lay.up_room
		spots.append([house, Vector3(room.position.x, floor_y + SCONCE_HIGH, back), 1.0])
		spots.append([house, Vector3(room.position.x, floor_y + SCONCE_HIGH, room.end.y - room.size.y * 0.25), 1.0])
		var upper := house.get_node_or_null("GuildUpper") as Node3D
		if upper:
			spots.append([upper, Vector3(up_room.end.x, float(lay.up_floor) + SCONCE_HIGH, up_room.position.y + up_room.size.y * 0.3), -1.0])
	else:
		spots.append([house, Vector3(room.position.x, floor_y + SCONCE_HIGH, back), 1.0])
		spots.append([house, Vector3(room.end.x, floor_y + SCONCE_HIGH, back), -1.0])
		if not rec.get("up_walls", []).is_empty():
			var up := room.grow(VillageHouse.JETTY)
			var side := -ladder_side(float(shape_of(rec).door_x))
			var x := up.end.x if side > 0.0 else up.position.x
			spots.append([rec.up_walls[0], Vector3(x, float(rec.top) + VillageHouse.FLOOR_LIFT + SCONCE_HIGH - 0.4, up.position.y + up.size.y * 0.3), -side])
	var sconces := []
	for spot: Array in spots:
		var sconce := WalkInFurniture.sconce()
		sconce.position = spot[1]
		# Its back on the wall, facing into the room: +x off the left wall, -x off the right.
		sconce.rotation.y = PI * 0.5 * float(spot[2])
		(spot[0] as Node3D).add_child(sconce)
		sconces.append(sconce)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("sconces %s" % [rec.block])
	rec["sconces"] = sconces
	rec["light_from"] = dice.randf_range(LIGHT_FROM.x, LIGHT_FROM.y)
	rec["bedtime"] = dice.randf_range(BED_TIME.x, BED_TIME.y)


func shape_of(rec: Dictionary) -> Dictionary:
	return (rec.node as Node3D).get_meta("shape")


## Lights or puts out the candles on the walls of each building for the hour of the day.
func set_hour(hour: float) -> void:
	for rec in buildings:
		if not rec.has("sconces"):
			continue
		var lit := lit_at(float(rec.light_from), float(rec.bedtime), hour)
		if lit == rec.get("sconces_lit"):
			continue
		rec["sconces_lit"] = lit
		for sconce: Node3D in rec.sconces:
			if is_instance_valid(sconce):
				(sconce.get_node("Flame") as Node3D).visible = lit
				(sconce.get_node("SconceGlow") as Node3D).visible = lit


## Whether candles lit at hour `from` and put out at `bed` (past midnight counted on from 24) burn
## at `hour`.
static func lit_at(from: float, bed: float, hour: float) -> bool:
	var h := fposmod(hour, 24.0)
	if h < 12.0:
		h += 24.0
	return h >= from and h < bed


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
	var rows := temple_pews(room, s)
	var pew_w: float = rows.pew_w
	for z: float in rows.zs:
		for x: float in rows.xs:
			var pew := WalkInFurniture.pew(pew_w)
			pew.position = Vector3(x, floor_y, z)
			inside.add_child(pew)
			_solid_kit(rec, Vector3(x, 0.5, z) / s, Vector3(pew_w, 1.0, WalkInFurniture.PEW_DEPTH) / s)


## Where the temple's pews stand, in metres in the temple's own frame (`room` is the nave in the kit's
## metres, `s` the chapel's scale): {"pew_w": their length, "aisle": the walk between the two columns,
## "xs": the middle of each column, "zs": the middle of each row, "altar_z": the altar's middle}.
## The first row stands well clear of the altar: the walk between them is wider than the hero
## (1.1 m), or they wedged in there and could not get out.
static func temple_pews(room: Rect2, s: float) -> Dictionary:
	var altar_z := (room.position.y + 2.2) * s
	var aisle := 1.7
	var pew_w := (room.size.x * s - aisle) * 0.5 - 0.35
	var first := altar_z + WalkInFurniture.ALTAR_SIZE.z * 0.5 + ALTAR_WALK + WalkInFurniture.PEW_DEPTH * 0.5
	var last := (NAVE_DOOR_Z - 4.0) * s
	var count := maxi(1, int((last - first) / WalkInFurniture.PEW_STEP) + 1)
	var zs: Array[float] = []
	for r in count:
		zs.append(first + r * WalkInFurniture.PEW_STEP)
	var xs: Array[float] = []
	for side: float in [-1.0, 1.0]:
		xs.append(side * (aisle * 0.5 + pew_w * 0.5))
	return {"pew_w": pew_w, "aisle": aisle, "xs": xs, "zs": zs, "altar_z": altar_z}


## The places to sit in the temple's pews and the place to stand before the altar, world:
## {"seats": [{"sit", "stand", "aisle", "front", "row"}], "pulpit": {"stand", "front"}}.
## One sits in the middle of the pew's plank facing the altar and walks up to it from the gap in
## front of the row. `need` is how many want a place: the pews seat as many to a side as they must,
## from three to four (shoulder to shoulder at most, SEAT_TIGHT apart), and what they cannot hold
## stands in a row behind the last pew, facing the altar ("standing": true, sit == stand).
func temple_seats(rec: Dictionary, need := 0) -> Dictionary:
	var node: Node3D = rec.node
	var s := node.scale.x
	var xf := node.global_transform
	var lay := temple_pews(rec.room, s)
	var front := (xf.basis * Vector3(0, 0, -1)).normalized()
	var seats := []
	var zs: Array = lay.zs
	var fit := maxi(1, int(float(lay.pew_w) / SEAT_GAP))
	var tight := maxi(fit, int(float(lay.pew_w) / SEAT_TIGHT))
	var per_side := clampi(ceili(float(need) / maxf(1.0, zs.size() * 2.0)), fit, tight)
	for r in zs.size():
		var z: float = zs[r]
		var stand_z := z - WalkInFurniture.PEW_DEPTH * 0.5 - SIT_STAND
		for cx: float in lay.xs:
			var apart := float(lay.pew_w) / per_side
			for k in per_side:
				var x := cx + (k - (per_side - 1) * 0.5) * apart
				seats.append({"sit": xf * (Vector3(x, 0, z - 0.05) / s), "stand": xf * (Vector3(x, 0, stand_z) / s),
						"aisle": xf * (Vector3(0, 0, stand_z) / s), "front": front, "row": r})
	# Standing room behind the last pew, either side of the way in from the door.
	var back_z: float = float(zs.back()) + WalkInFurniture.PEW_DEPTH * 0.5 + STAND_BACK
	var reach: float = float(rec.room.size.x) * 0.5 * s - 0.6
	var x := STAND_AISLE
	while x <= reach:
		for side: float in [-1.0, 1.0]:
			var at: Vector3 = xf * (Vector3(side * x, 0, back_z) / s)
			seats.append({"sit": at, "stand": at, "aisle": xf * (Vector3(0, 0, back_z) / s), "front": front, "row": zs.size(), "standing": true})
		x += SEAT_TIGHT
	var altar_front: float = float(lay.altar_z) + WalkInFurniture.ALTAR_SIZE.z * 0.5 + PULPIT_GAP
	return {"seats": seats, "pulpit": {"stand": xf * (Vector3(0, 0, altar_front) / s), "front": -front}}


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
		var wz: float = float((rec.node.get_meta("shape") as Dictionary).get("side_z", 0.0))
		_wall(rec, Vector3(x, y, -d * 0.5), Vector3(x, y, wz - 0.4), high)
		_pane(rec, Vector3(x, y, wz - 0.4), Vector3(x, y, wz + 0.4), high)
		_wall(rec, Vector3(x, y, wz + 0.4), Vector3(x, y, d * 0.5), high)
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
		var room: Rect2 = rec.room
		if rec.has("high"):
			# A hall of several storeys (the guildhall): its room from the cellar up to the deck.
			if p.y > float(rec.high):
				continue
		elif p.y > float(rec.top) - UPPER_FROM:
			# Up on the floor above one can climb to: its room, on the jetty, up to the eaves.
			if rec.has("up_room") and p.y < float(rec.top) + VillageHouse.UPPER:
				var up := room.grow(VillageHouse.JETTY)
				if p.y > float(rec.top) and up.grow(margin / node.scale.x).has_point(Vector2(p.x, p.z)):
					return rec
			if p.y > float(rec.top):
				continue
		if room.grow(margin / node.scale.x).has_point(Vector2(p.x, p.z)):
			return rec
	return {}


## Whether `pos` (world) is up on the floor above of the building `rec`: on its boards, or up the
## ladder far enough to see over them.
func is_upstairs(rec: Dictionary, pos: Vector3) -> bool:
	if rec.is_empty() or not rec.has("up_room"):
		return false
	var p := (rec.node as Node3D).global_transform.affine_inverse() * pos
	return p.y > float(rec.top) - UPPER_FROM


## Whether the hero is up on the floor above of the house `rec` now.
func hero_upstairs_in(rec: Dictionary) -> bool:
	return hero_up and not rec.is_empty() and hero_in.get("node") == rec.get("node")


## Whether a point lies in a room, out of the weather.
func covers(pos: Vector3) -> bool:
	var rec := building_at(pos)
	if rec.is_empty():
		return false
	if rec.has("deck"):
		# Up on a roof one walks on (the guildhall's) the weather falls on the hero.
		var p := (rec.node as Node3D).global_transform.affine_inverse() * pos
		return p.y < float(rec.deck) - 0.3
	return true


## How high the floor is at `pos` (world) for someone walking in: the boards in a room and its
## doorway, the ramp up to a house door, the ground elsewhere. In a hall of several storeys (the
## guildhall, see GuildHall) `pos.y` tells which: the floor nearest under someone whose feet are
## about there, or the steps of the flight they are on.
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
		if rec.has("layout") and room.grow(VillageHouse.JETTY).has_point(Vector2(p.x, p.z)):
			return node.global_position.y + GuildHall.floor_y(rec.layout, p) * node.scale.y
		if rec.has("up_room") and p.y > float(rec.top) - UPPER_FROM and room.grow(VillageHouse.JETTY).has_point(Vector2(p.x, p.z)):
			return node.global_position.y + (float(rec.top) + VillageHouse.FLOOR_LIFT) * node.scale.y
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
		if (rec.kind != "house" and not rec.has("owner")) or not rec.get("opened", false):
			continue
		var owner := String(rec.get("owner", ""))
		var owned: bool = owner == role or (rec.get("owners", []) as Array).has(role)
		if owner != "" and not owned:
			continue
		if owner != "" and owned:
			var at: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
			if Vector2(at.x - pos.x, at.z - pos.z).length() < reach:
				return rec
		var door: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
		var dist := Vector2(door.x - pos.x, door.z - pos.z).length()
		if dist < best_d:
			best = rec
			best_d = dist
	return best


## Which house each villager without a house of their own sleeps in (role -> building record). Chosen
## the first time they are asked: the nearest house to `near` that still has a bed for them, so that no
## bed holds two and nobody is left at a door with no bed behind it.
var _homes := {}


func home_for(role: String, near: Vector3) -> Dictionary:
	if _homes.has(role) and is_instance_valid((_homes[role].node as Node3D)):
		return _homes[role]
	var best := {}
	var best_d := INF
	for rec in buildings:
		if rec.kind != "house" or rec.has("owner") or not rec.get("opened", false) or not rec.has("beds"):
			continue
		var tenants := 0
		for other: Dictionary in _homes.values():
			if is_same(other, rec):
				tenants += 1
		if tenants >= (rec.beds as Array).size():
			continue
		var door: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
		var dist := Vector2(door.x - near.x, door.z - near.z).length()
		if dist < best_d:
			best = rec
			best_d = dist
	if not best.is_empty():
		_homes[role] = best
	return best


## The building with a bedroom that is `role`'s alone, or {} (the shop's family, see VillageHalls.HOME_OWNERS).
func owned_house(role: String) -> Dictionary:
	for rec in buildings:
		if not rec.get("opened", false):
			continue
		if String(rec.get("owner", "")) == role or (rec.get("owners", []) as Array).has(role):
			return rec
	return {}


## The street spot in front of a house's door, where villagers meet it (as in Outdoor.spots.houses):
## the nearest of `spots` within a few metres, or the foot of its ramp.
func front_of(rec: Dictionary, spots: Array) -> Vector3:
	var door: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
	var best := door_points(rec)[0]
	var best_d := 8.0
	for spot: Vector3 in spots:
		var dist := Vector2(door.x - spot.x, door.z - spot.z).length()
		if dist < best_d:
			best = spot
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
		out.append_array(_between_storeys(a, from, to))
		out.append(to)
		return out
	var start := from
	if not a.is_empty():
		var way := door_points(a)
		out.append_array(_between_storeys(a, from, way[1]))
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
		out.append_array(_between_storeys(b, way_in[1], to))
	out.append(to)
	return out


## Where a click's ray (world) meets the door of a building the hero is not in: the spot just inside it, so
## a click on the door itself (which the ground plane would put in the wall, or past it) walks the hero in.
## Null when the ray misses every door (see Game._mouse_to_floor).
func door_under_ray(origin: Vector3, dir: Vector3) -> Variant:
	if not hero_in.is_empty():
		return null
	for rec in buildings:
		if not rec.get("opened", false) or not rec.has("door") or not rec.has("wall_out"):
			continue
		var node: Node3D = rec.node
		var inv := node.global_transform.affine_inverse()
		var o: Vector3 = inv * origin
		var d: Vector3 = inv.basis * dir
		if absf(d.z) < 0.001:
			continue
		var door: Vector3 = rec.door
		# The door's face: the outer plane of the front wall.
		var t := (float(rec.wall_out) - o.z) / d.z
		if t < 0.0:
			continue
		var p: Vector3 = o + d * t
		if absf(p.x - door.x) <= HouseDoor.WIDTH * 0.5 + 0.1 and p.y >= -0.2 and p.y <= HouseDoor.HEIGHT + 0.2:
			return door_points(rec)[1]
	return null


## Whether `pos` (world) is out of the hero's sight: in a building they are not in, or on a storey of the
## hall of several storeys they stand in that lies above theirs (see _show_up). A click through a roof must
## not pick a bed or a seat there.
func hidden_above_hero(pos: Vector3) -> bool:
	# Inside another building than the hero's (or one the hero is outside of): its rooms are out of sight.
	var there := building_at(pos, 0.0)
	if not there.is_empty() and there.get("node") != hero_in.get("node"):
		return true
	if hero_in.is_empty() or not hero_in.has("layout"):
		return false
	var node: Node3D = hero_in.node
	var p: Vector3 = node.global_transform.affine_inverse() * pos
	var lay: Dictionary = hero_in.layout
	if not Rect2(lay.up_room).grow(0.5).has_point(Vector2(p.x, p.z)):
		return false
	return GuildHall.storey_of(lay, p.y) > int(hero_in.storey)


## How far (metres) beside a flight of stairs a click still counts as a click on its steps.
const STEPS_CLICK_MARGIN := 0.6


## Whether `point` (world) is on the steps of a flight of the hall of several storeys the hero stands in.
func on_steps(point: Vector3) -> bool:
	if hero_in.is_empty() or not hero_in.has("layout"):
		return false
	var local: Vector3 = (hero_in.node as Node3D).global_transform.affine_inverse() * point
	return not GuildHall.flight_at(hero_in.layout, local).is_empty()


## Where a click's ray (world) meets what the hero can see inside the hall of several storeys they stand in
## (the guildhall, the mage tower): the steps of a flight they can see, or the boards of their own storey or
## one below. The game's own click lands on the ground plane, which for a raised step or upstairs floor is
## somewhere else entirely. Null when the ray meets none of them (see Game._mouse_to_floor).
func surface_under_ray(origin: Vector3, dir: Vector3) -> Variant:
	if hero_in.is_empty() or not hero_in.has("layout") or dir.y > -0.01:
		return null
	var node: Node3D = hero_in.node
	var inv := node.global_transform.affine_inverse()
	var lay: Dictionary = hero_in.layout
	var o: Vector3 = inv * origin
	var d: Vector3 = (inv.basis * dir).normalized()
	if d.y > -0.01:
		return null
	var storey := int(hero_in.storey)
	# The steps first: a flight with the hero's storey at one end shows from there.
	for entry: Array in [[lay.b, GuildHall.UPPER_STOREY, GuildHall.ROOF_STOREY], [lay.a, GuildHall.GROUND_STOREY, GuildHall.UPPER_STOREY],
			[lay.c, GuildHall.CELLAR_STOREY, GuildHall.GROUND_STOREY]]:
		var f: Dictionary = entry[0]
		if storey != int(entry[1]) and storey != int(entry[2]):
			continue
		var wide := f.duplicate()
		wide["x0"] = float(f.x0) - STEPS_CLICK_MARGIN
		wide["x1"] = float(f.x1) + STEPS_CLICK_MARGIN
		var t0 := (float(f.high) + 0.1 - o.y) / d.y
		var t1 := (float(f.low) - 0.1 - o.y) / d.y
		var steps := 120
		for i in steps + 1:
			var p: Vector3 = o + d * lerpf(t0, t1, float(i) / float(steps))
			# A little beside the flight counts as on it (a bigger spot to click), aimed at its steps.
			if GuildHall.on_flight(wide, p) and p.y <= GuildHall.ramp(f, p.z) + 0.3:
				p.x = clampf(p.x, float(f.x0) + 0.25, float(f.x1) - 0.25)
				p.y = GuildHall.ramp(f, p.z)
				return node.global_transform * p
	# Then the boards: the hero's storey, and those below it.
	var floors := [[GuildHall.ROOF_STOREY, lay.deck, lay.up_room, lay.hatch], [GuildHall.UPPER_STOREY, lay.up_floor, lay.up_room, lay.stairwell],
			[GuildHall.GROUND_STOREY, lay.floor, lay.room, null]]
	for entry: Array in floors:
		if int(entry[0]) > storey:
			continue
		var y: float = entry[1]
		var q: Vector3 = o + d * ((y - o.y) / d.y)
		var hole: Variant = entry[3]
		if (entry[2] as Rect2).has_point(Vector2(q.x, q.z)) and not (hole != null and (hole as Rect2).has_point(Vector2(q.x, q.z))):
			return node.global_transform * q
	return null


## The way up or down the stairs of a hall of several storeys (the guildhall, see GuildHall.way)
## from the storey of `from` to that of `to` (world), or nothing.
func _between_storeys(rec: Dictionary, from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not rec.has("layout"):
		return out
	var node: Node3D = rec.node
	var to_local := node.global_transform.affine_inverse()
	var a := GuildHall.storey_of(rec.layout, (to_local * from).y)
	var b := GuildHall.storey_of(rec.layout, (to_local * to).y)
	# A click on the steps themselves: to the end of the flight it is nearest from where one comes.
	var onto := GuildHall.way_onto(rec.layout, a, to_local * to)
	for p: Vector3 in (onto if not onto.is_empty() else GuildHall.way(rec.layout, a, b)):
		out.append(node.global_transform * p)
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
	var up := is_upstairs(now, at)
	if now.get("node") != hero_in.get("node") or up != hero_up:
		if not hero_in.is_empty() and now.get("node") != hero_in.get("node"):
			_show_inside(hero_in, false)
		hero_in = now
		hero_up = up
		if not hero_in.is_empty():
			_storey_of_hero(hero_in, at)
			_show_inside(hero_in, true, up)
	elif not hero_in.is_empty() and _storey_of_hero(hero_in, at):
		_show_inside(hero_in, true, hero_up)
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
	rec["lock_wait"] = float(rec.get("lock_wait", 0.0)) - delta
	var door: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
	var near: bool = Vector2(door.x - hero_at.x, door.z - hero_at.z).length() < DOOR_REACH
	# A hall without its keeper inside and awake is locked, unless the hero is inside it already
	# (they are never shut in).
	# A farm's door is bolted too while its farmer sleeps (see farmer_asleep).
	var asleep: bool = lock_halls and hero_in.get("node") != rec.node and farmer_asleep(rec)
	var locked: bool = asleep or (lock_halls and hero_in.get("node") != rec.node and VillagePosts.locked(level, rec))
	rec["locked"] = locked
	if near and locked:
		if float(rec.lock_wait) <= 0.0:
			rec.lock_wait = LOCKED_EVERY
			Events.tell(Lang.t("Die Tür ist verriegelt. Drinnen schläft jemand.") if asleep \
					else Lang.t("Die Tür ist verschlossen. Ihr Besitzer ist nicht da."), Color(1.0, 0.8, 0.5), 2.5)
	elif near and rec.push <= 0.0:
		rec.push = PUSH_EVERY
		(leaf as HouseDoor).swing()
	var shape: CollisionShape3D = rec.get("door_shape")
	if shape:
		shape.disabled = (leaf as HouseDoor).openness() > 0.25 and not locked


## Whether `rec` is a house of the farming valley (see Outdoor.VALLEY_FROM) with a farmer asleep in it:
## its door stays locked from the moment they lie down until they get up.
func farmer_asleep(rec: Dictionary) -> bool:
	if rec.kind != "house" or (rec.block as Rect2i).position.y < Outdoor.VALLEY_FROM:
		return false
	for bed: Dictionary in rec.get("beds", []):
		var by = bed.get("by")
		if by is Villager and is_instance_valid(by) and (by as Villager).is_asleep():
			return true
	return false


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
	var high := VillageHouse.UPPER + (GuildHall.PARAPET + 0.3 if bool(shape.get("flat", false)) else float(shape.ridge) * 1.3)
	if bool(shape.get("mage", false)):
		high = VillageHouse.UPPER + GuildHall.DECK + MageTower.TOP_H + MageTower.PEAK + MageTower.SPIRE
	var box := AABB(Vector3(-float(shape.w) * 0.5 - out, top, -float(shape.d) * 0.5 - out),
			Vector3(float(shape.w) + out * 2.0, high, float(shape.d) + out * 2.0))
	var to_local := node.global_transform.affine_inverse()
	var eye := to_local * cam
	for lift: float in [COVER_FEET, COVER_HEAD]:
		if box.intersects_segment(eye, to_local * (hero_at + Vector3(0, lift, 0))) == null:
			return false
	return true


## Whether a spot in the world lies on or just under a roof that is lifted off now (the hero
## inside, or behind it, see _mind_cover): what sits there (a bird on the chimney) goes with it, or
## it would hang in the air between the camera and the hero.
func roof_lifted_at(pos: Vector3) -> bool:
	for rec in buildings:
		if not rec.get("opened", false) or rec.kind == "temple":
			continue
		if not (bool(rec.get("inside", false)) or bool(rec.get("roof_off", false))):
			continue
		var node: Node3D = rec.node
		if not node.has_meta("shape"):
			continue
		var shape: Dictionary = node.get_meta("shape")
		var out := VillageHouse.JETTY + VillageHouse.ROOF_OVERHANG + 0.5
		var top: float = rec.top
		var box := AABB(Vector3(-float(shape.w) * 0.5 - out, top - 0.5, -float(shape.d) * 0.5 - out),
				Vector3(float(shape.w) + out * 2.0, 40.0, float(shape.d) + out * 2.0))
		if box.has_point(node.global_transform.affine_inverse() * pos):
			return true
	return false


## Notes which storey of a hall of several storeys (the guildhall) the hero at `at` stands on; true
## when it changed.
func _storey_of_hero(rec: Dictionary, at: Vector3) -> bool:
	if not rec.has("layout"):
		return false
	var y := ((rec.node as Node3D).global_transform.affine_inverse() * at).y
	var storey := GuildHall.storey_of(rec.layout, y)
	if storey == int(rec.storey):
		return false
	rec.storey = storey
	return true


## Shows the floor above and the roof unless the hero is inside or behind it (see _mind_cover).
## Up on the floor above of a house with one (see is_upstairs), its back and side walls and its
## room show while its roof and its front wall stay hidden. In a hall of several storeys (the
## guildhall) the storey the hero stands on shows, without whichever of its walls face the
## camera, and nothing above it does: on the roof everything shows.
func _show_up(rec: Dictionary) -> void:
	var inside := bool(rec.inside)
	var up := bool(rec.get("hero_up", false))
	var off := not inside and bool(rec.get("roof_off", false))
	var shown := not inside and not off
	if rec.has("storey_room"):
		var storey := int(rec.storey)
		var room_shown := shown or (inside and storey >= GuildHall.UPPER_STOREY)
		for part in rec.storey_room:
			if is_instance_valid(part):
				(part as Node3D).visible = room_shown
		for side: String in SIDES:
			var hide := not room_shown or (inside and storey == GuildHall.UPPER_STOREY and _faces_camera(rec, side))
			for part in rec["storey_" + side]:
				if is_instance_valid(part):
					(part as Node3D).visible = not hide
		if inside:
			shown = storey == GuildHall.ROOF_STOREY
	if rec.has("mage"):
		# The top room of a mage tower: its walls show from outside and from within it (those facing
		# the camera apart), its roof from outside only.
		var top_inside := inside and int(rec.storey) == GuildHall.ROOF_STOREY
		var outside := not inside and not off
		for side: String in SIDES:
			var hide := not (outside or top_inside) or (top_inside and _faces_camera(rec, side))
			for part in rec["top_" + side]:
				if is_instance_valid(part):
					(part as Node3D).visible = not hide
		for part in rec.tower_roof:
			if is_instance_valid(part):
				_lift(part, not outside)
	for part in rec.up:
		if is_instance_valid(part):
			_lift(part, not shown)
	for part in rec.get("up_walls", []):
		if is_instance_valid(part):
			_lift(part, not ((not inside or up) and not off))
	for part in rec.get("up_front", []):
		if is_instance_valid(part):
			_lift(part, not (not inside and not off))
	for part in rec.get("up_room", []):
		if is_instance_valid(part):
			(part as Node3D).visible = inside and up


## Lifts a roof, an upper wall or the floor above off (or puts it back): not drawn, but what of it
## casts a shadow still does (as LightShadows.lift), so the sun and the moon do not shine into the
## room while the hero looks in from behind the house or stands inside. What casts none (chimney
## smoke, the candles on the upper wall) is simply hidden, as before.
static func _lift(part: Node, lifted: bool) -> void:
	if not part is Node3D:
		return
	var node := part as Node3D
	if not _casts(node):
		# Remember whether it was shown, so putting it back never un-hides what is hidden on
		# purpose (the faint range circle of a ballista, see HouseBallista.show_range).
		if lifted:
			if not node.has_meta(&"lift_was_visible"):
				node.set_meta(&"lift_was_visible", node.visible)
			node.visible = false
		elif node.has_meta(&"lift_was_visible"):
			node.visible = bool(node.get_meta(&"lift_was_visible"))
			node.remove_meta(&"lift_was_visible")
		return
	node.set_meta(&"walk_in_lifted", lifted)
	if node is GeometryInstance3D and not _is_particles(node):
		var geo := node as GeometryInstance3D
		if lifted and not geo.has_meta(&"drawn_as"):
			geo.set_meta(&"drawn_as", [geo.layers, geo.cast_shadow])
			geo.layers = LightShadows.LID_LAYER
			geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		elif not lifted and geo.has_meta(&"drawn_as"):
			var was: Array = geo.get_meta(&"drawn_as")
			geo.layers = was[0]
			geo.cast_shadow = was[1]
			geo.remove_meta(&"drawn_as")
	for child in node.get_children():
		_lift(child, lifted)


## Whether a part of a building is drawn now: shown, and not lifted off (see _lift).
static func drawn(part: Node3D) -> bool:
	return part.visible and not part.get_meta(&"walk_in_lifted", false)


## Whether anything in `node` (or under it) casts a shadow when drawn.
static func _casts(node: Node3D) -> bool:
	if node is GeometryInstance3D and not _is_particles(node):
		var geo := node as GeometryInstance3D
		var cast: int = (geo.get_meta(&"drawn_as") as Array)[1] if geo.has_meta(&"drawn_as") else geo.cast_shadow
		if cast != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return true
	for child in node.get_children():
		if child is Node3D and _casts(child):
			return true
	return false


static func _is_particles(node: Node) -> bool:
	return node is GPUParticles3D or node is CPUParticles3D


## Hides (or shows again) what stands between the camera and the room.
## Up on the floor above (`up`), the roof and the upper front wall hide and the upper room shows,
## while the ground floor's front wall stays (it is below the hero).
func _show_inside(rec: Dictionary, inside: bool, up := false) -> void:
	rec.inside = inside
	rec["hero_up"] = up
	_show_up(rec)
	var storey := int(rec.get("storey", 0))
	if rec.has("layout"):
		# Down in the cellar the whole hall is out of the way (CellarView hides the rest up there).
		(rec.node as Node3D).visible = not (inside and storey == GuildHall.CELLAR_STOREY)
		for key: int in rec.get("storey_lamps", {}):
			var light: Light3D = rec.storey_lamps[key]
			if is_instance_valid(light):
				light.visible = inside and (key == storey or (key == GuildHall.CELLAR_STOREY and storey == GuildHall.GROUND_STOREY))
	for side: String in SIDES:
		if not rec.has(side):
			continue
		# A house hides its front (its door faces the street, towards the camera); a hall hides
		# whichever walls face the camera. Upstairs (in a house, or in a hall of several storeys)
		# the walls below stand.
		var hide := inside and not up and storey == GuildHall.GROUND_STOREY and (not rec.has("sided") or _faces_camera(rec, side))
		for part in rec[side]:
			if is_instance_valid(part):
				(part as Node3D).visible = not hide
	var lamp: OmniLight3D = rec.get("lamp")
	if lamp:
		lamp.visible = inside and storey == GuildHall.GROUND_STOREY
		lamp.position.y = float(rec.top) - 0.6 + (VillageHouse.UPPER if up else 0.0)
	for glow in rec.get("glows", []):
		if is_instance_valid(glow):
			(glow as Light3D).visible = inside


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
