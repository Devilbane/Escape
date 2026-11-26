class_name GuildHall
extends RefCounted
## The adventurers' guildhall one walks into (map letter w, see VillageHalls): two storeys of the
## village's stone, timber and plaster under a flat roof, with stairs from the ground floor up to
## the upper floor, on up through a hatch onto the roof, and down into a cellar dug under the hall.
##
## - The ground floor keeps Guild Master Ragna's desk at the back under the guild's banners and a
##   tavern corner; the stairs up run along the right wall, the stairs down to the cellar along
##   the left one, each behind a wooden railing.
## - The upper floor is the guild's map room: a long table with the map of the land on it, stools,
##   a bookcase, chests and a rack of weapons. Its stairs to the roof run along the left wall.
## - The roof is the training ground: a deck of boards behind a stone parapet with merlons, a
##   large training mat, straw dummies, a rack of weapons and two ballistas looking out over the
##   parapet.
## - The cellar is Ragna's own room, where she sleeps (see VillageBeds): her bed, a bedside table,
##   a chest, a wardrobe, a stool, a rack of her own blades, and wine barrels.
##
## Usability first: every flight is straight and wide enough to walk, the way from the door to each
## flight stays free, every open edge has a railing (and a wall the hero cannot walk through), and
## the camera sees the storey the hero stands on: on the ground floor the storey above hides, on
## the upper floor the roof does and the walls facing the camera, down in the cellar the whole hall
## does (see WalkIn._show_storey and CellarView).
##
## The hall's own frame is VillageHouse's: x across the front, z towards the door (+z), y up from
## the ground. The cellar's hole in the ground (Outdoor.hall_holes, see Outdoor.set_floor_holes)
## is HOLE metres either side of the hall's middle, on the map's 2 m lattice.

## The style of the hall's VillageHouse (see VillageHalls.style).
const STYLE := {"max_w": 9.8, "max_d": 8.6, "door_x": 0.0, "flat": true}
## The groups of the upper storey's meshes (see VillageHouse.hollow): each wall apart, and the room.
const UPPER_GROUPS := ["storey_front", "storey_back", "storey_left", "storey_right", "storey_room"]
## The storeys, as WalkIn keeps them (rec.storey): the cellar, the ground floor, the upper floor, the roof.
const CELLAR_STOREY := -1
const GROUND_STOREY := 0
const UPPER_STOREY := 1
const ROOF_STOREY := 2
## Where the mage tower's library is crossed from the landing to the stairs up to the sleeping room: the aisle
## between its left sofa chair and the reading table (see MageTower._library).
const LIBRARY_AISLE := -1.8

## How wide a flight of stairs is, and how steep (metres up for each metre along).
const STAIR_WIDE := 1.4
const SLOPE := 0.62
## The cellar: its floor (metres below the ground) and how far its walls stand from the hall's middle.
const CELLAR := -2.5
const HOLE := 4.0
## The roof: how far the deck's boards lie over the eaves, how high the parapet stands over them
## (the low wall, and its merlons), how thick it is.
const DECK := 0.12
const PARAPET := 1.0
const PARAPET_LOW := 0.5
const PARAPET_THICK := 0.2
const MERLON := 0.6
## The railings round the stairs: how high, and how far apart their posts stand.
const RAIL := 1.0
const POST_EVERY := 1.1
## How far the hatch in the deck reaches on past the foot of the flight up to it, and the well
## down to the cellar past the foot of its flight: room for the hero's head (see Player.tall).
const HEAD_ROOM := 0.7
## How far before a flight's end the way onto it starts (see way).
const ONTO := 0.6
const GUILD_RED := Color(0.6, 0.2, 0.15)
const MAT_RED := Color(0.55, 0.16, 0.13)
const MAT_EDGE := Color(0.82, 0.74, 0.58)
const MAP_PAPER := Color(0.86, 0.78, 0.6)


## Where everything is, in the hall's frame, for a hall of the size in `shape` (VillageHouse's):
## the rooms, the heights of the floors, the three flights (each {"x0", "x1": across; "foot",
## "top": where along z its low and its high end are; "low", "high": their heights}) and the
## openings they rise through.
static func layout(shape: Dictionary) -> Dictionary:
	var w: float = shape.w
	var d: float = shape.d
	var t := VillageHouse.WALL_THICK
	var room := Rect2(-w * 0.5 + t, -d * 0.5 + t, w - t * 2.0, d - t * 2.0)
	var up_room := room.grow(VillageHouse.JETTY)
	var floor := VillageHouse.PLINTH + VillageHouse.FLOOR_LIFT
	var top := VillageHouse.PLINTH + VillageHouse.GROUND
	var up_floor := top + VillageHouse.FLOOR_LIFT
	var eaves := top + VillageHouse.UPPER
	var deck := eaves + DECK
	# Up from the ground floor along the right wall, rising from beside the door towards the back.
	var a_foot := room.end.y - 1.2
	var a := {"x0": room.end.x - STAIR_WIDE, "x1": room.end.x, "foot": a_foot, "top": a_foot - (up_floor - floor) / SLOPE,
			"low": floor, "high": up_floor}
	# Up from the upper floor to the roof along its left wall, rising towards the back.
	var b_foot := up_room.end.y - 1.2
	var b := {"x0": up_room.position.x, "x1": up_room.position.x + STAIR_WIDE, "foot": b_foot,
			"top": b_foot - (deck - up_floor) / SLOPE, "low": up_floor, "high": deck}
	# Down from beside the door along the cellar's left wall, falling towards the back.
	var c_top := room.end.y - 1.2
	var c := {"x0": -HOLE, "x1": -HOLE + STAIR_WIDE, "foot": c_top - (floor - CELLAR) / SLOPE, "top": c_top,
			"low": CELLAR, "high": floor}
	# Round what stands on the floors: from the landing upstairs past the stairwell's railing to the
	# front of the map room and the flight to the roof; on the ground floor and in the cellar past
	# the railing and the wall beside the flight down.
	# (Each nearest its flight first; the hero is wide, see Player.radius, so the way keeps clear.)
	a["high_via"] = [Vector3(float(a.x0) - ONTO - 0.1, up_floor, float(a.top) - ONTO)]
	b["low_via"] = [Vector3(float(b.x1) + ONTO + 0.1, up_floor, b_foot + ONTO), Vector3(float(a.x0) - ONTO - 0.1, up_floor, b_foot - 0.9)]
	c["low_via"] = [Vector3(float(c.x1) + ONTO + 0.1, CELLAR, float(c.foot) - ONTO)]
	var mage := bool(shape.get("mage", false))
	if mage:
		# The library's seats stand right by the stairwell's railing, so the way from the landing to the
		# flight to the sleeping room runs round the back of the reading corner and down its left aisle.
		# (Several points down the aisle, which has little to spare: the hero must not cut a corner into the table.)
		b["low_via"] = [Vector3(float(b.x1) + ONTO + 0.1, up_floor, b_foot + ONTO), Vector3(-2.4, up_floor, 1.4),
				Vector3(-2.2, up_floor, 0.5), Vector3(LIBRARY_AISLE, up_floor, -0.6), Vector3(LIBRARY_AISLE, up_floor, -1.6),
				Vector3(LIBRARY_AISLE, up_floor, float(a.top) - ONTO)]
		# Off the stairs to the sleeping room and clear of the hatch's corner before heading for a bed.
		b["high_via"] = [Vector3(float(b.x1) + ONTO + 0.1, deck, float(b.top) - ONTO), Vector3(float(b.x1) + ONTO + 0.1, deck, float(b.top) + 0.7)]
	return {"room": room, "up_room": up_room, "floor": floor, "top": top, "up_floor": up_floor, "eaves": eaves,
			"mage": mage, "wall_top": deck + (MageTower.TOP_H if mage else PARAPET),
			"deck": deck, "cellar": Rect2(-HOLE, -HOLE, HOLE * 2.0, HOLE * 2.0), "a": a, "b": b, "c": c,
			"well": Rect2(c.x0, float(c.foot) - HEAD_ROOM, STAIR_WIDE, float(c.top) - float(c.foot) + HEAD_ROOM),
			"stairwell": Rect2(a.x0, a.top, up_room.end.x - a.x0, a.foot - a.top),
			"hatch": Rect2(b.x0, b.top, STAIR_WIDE, b.foot - b.top + HEAD_ROOM)}


## How high a flight's steps are at `z` along it.
static func ramp(flight: Dictionary, z: float) -> float:
	var k := clampf((float(flight.foot) - z) / (float(flight.foot) - float(flight.top)), 0.0, 1.0)
	return lerpf(float(flight.low), float(flight.high), k)


## Whether the point (`p.x`, `p.z`, the hall's frame) is over a flight.
static func on_flight(flight: Dictionary, p: Vector3) -> bool:
	var z0 := minf(float(flight.foot), float(flight.top))
	var z1 := maxf(float(flight.foot), float(flight.top))
	return p.x >= float(flight.x0) and p.x <= float(flight.x1) and p.z >= z0 and p.z <= z1


## The storey of someone whose feet are at `y` (the hall's frame).
static func storey_of(lay: Dictionary, y: float) -> int:
	if y < -1.0:
		return CELLAR_STOREY
	if y < float(lay.top) - 0.5:
		return GROUND_STOREY
	if y < float(lay.eaves) - 0.2:
		return UPPER_STOREY
	return ROOF_STOREY


## The floor under `p` (the hall's frame), for someone whose feet are about at `p.y`: the boards
## of that storey or the steps of the flight they are on.
static func floor_y(lay: Dictionary, p: Vector3) -> float:
	if p.y >= float(lay.up_floor) - 0.6:
		if on_flight(lay.b, p):
			return ramp(lay.b, p.z)
		if on_flight(lay.a, p) and p.y < float(lay.up_floor) + 0.3:
			return ramp(lay.a, p.z) # Coming down again: the flight's top is at the upper floor.
		if p.y >= float(lay.deck) - 0.6:
			return lay.deck
		return lay.up_floor
	if on_flight(lay.a, p):
		return ramp(lay.a, p.z)
	if on_flight(lay.c, p):
		return ramp(lay.c, p.z)
	if p.y < -1.0:
		return CELLAR
	return lay.floor


## The points of the way (the hall's frame) up a flight: from its floor below round what stands
## there (its "low_via", farthest first), onto it, its foot, its top, off it, and on round what
## stands on the floor above (its "high_via").
static func _up_flight(flight: Dictionary) -> Array[Vector3]:
	var x := (float(flight.x0) + float(flight.x1)) * 0.5
	var along := signf(float(flight.top) - float(flight.foot))
	var foot := float(flight.foot)
	var top := float(flight.top)
	var out: Array[Vector3] = []
	var low: Array = flight.get("low_via", [])
	for i in range(low.size() - 1, -1, -1):
		out.append(low[i])
	out.append_array([Vector3(x, flight.low, foot - along * ONTO), Vector3(x, flight.low, foot), Vector3(x, flight.high, top),
			Vector3(x, flight.high, top + along * ONTO)])
	for p: Vector3 in flight.get("high_via", []):
		out.append(p)
	return out


## The flight (a, b or c) the point `p` (the hall's frame) is over, with the storeys at its low and its
## high end, or {} when it is over none: where a click on the steps themselves is aimed.
static func flight_at(lay: Dictionary, p: Vector3) -> Dictionary:
	var flights := [[lay.a, GROUND_STOREY, UPPER_STOREY], [lay.b, UPPER_STOREY, ROOF_STOREY], [lay.c, CELLAR_STOREY, GROUND_STOREY]]
	for entry: Array in flights:
		var f: Dictionary = entry[0]
		if on_flight(f, p) and p.y > float(f.low) - 0.3 and p.y < float(f.high) + 0.3 \
				and p.y < float(ramp(f, p.z)) + 1.5 and p.y > float(ramp(f, p.z)) - 0.8:
			return {"flight": f, "low": entry[1], "high": entry[2]}
	return {}


## The way (the hall's frame) from someone on `from` storey to the steps under `p`, for a click on a
## flight: along the floor to its foot and up it when they come from below (or on its own storey), or
## down to its top and onto it from above. Empty when `p` is over no flight (see `way`).
static func way_onto(lay: Dictionary, from: int, p: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var hit := flight_at(lay, p)
	if hit.is_empty():
		return out
	var f: Dictionary = hit.flight
	var x := (float(f.x0) + float(f.x1)) * 0.5
	var along := signf(float(f.top) - float(f.foot))
	if from <= int(hit.low):
		out.append_array(way(lay, from, int(hit.low)))
		var low: Array = f.get("low_via", [])
		for i in range(low.size() - 1, -1, -1):
			out.append(low[i])
		out.append(Vector3(x, f.low, float(f.foot) - along * ONTO))
		out.append(Vector3(x, f.low, f.foot))
	else:
		out.append_array(way(lay, from, int(hit.high)))
		var high: Array = f.get("high_via", [])
		for i in range(high.size() - 1, -1, -1):
			out.append(high[i])
		out.append(Vector3(x, f.high, float(f.top) + along * ONTO))
		out.append(Vector3(x, f.high, f.top))
	return out


## The way between two storeys of the hall (the hall's frame, the points between them): up or down
## the flights in turn. Empty on the same storey.
static func way(lay: Dictionary, from: int, to: int) -> Array[Vector3]:
	var flights := {CELLAR_STOREY: lay.c, GROUND_STOREY: lay.a, UPPER_STOREY: lay.b}
	var out: Array[Vector3] = []
	if to > from:
		for s in range(from, to):
			out.append_array(_up_flight(flights[s]))
	elif to < from:
		for s in range(from - 1, to - 1, -1):
			var down := _up_flight(flights[s])
			down.reverse()
			out.append_array(down)
	return out


# --- The shell -----------------------------------------------------------------------

## The flat roof on the upper storey (into the house's `parts`, see VillageHouse._shape): a deck of
## boards over the eaves, open over the stairs up (the hatch), and a low stone parapet round its
## edge with merlons on it.
static func roof_shell(parts: Dictionary, shape: Dictionary, with_parapet := true) -> void:
	var lay := layout(shape)
	var uw := float(shape.w) + VillageHouse.JETTY * 2.0
	var ud := float(shape.d) + VillageHouse.JETTY * 2.0
	var eaves: float = lay.eaves
	var deck: float = lay.deck
	var hatch: Rect2 = lay.hatch
	var hole := Rect2(hatch.position.x + uw * 0.5, ud * 0.5 - hatch.end.y, hatch.size.x, hatch.size.y)
	VillageHouse._face(parts, "floor", Vector3(-uw * 0.5, deck, ud * 0.5), Vector3.RIGHT, Vector3.FORWARD, Vector2(uw, ud), hole)
	# A frame of timber round the hatch, down through the deck.
	var frame := 0.08
	var under := deck - 0.3
	var mid := (deck + under) * 0.5
	VillageHouse._box(parts, "timber", Vector3(hatch.end.x + frame * 0.5, mid, hatch.get_center().y), Vector3(frame, deck - under, hatch.size.y))
	VillageHouse._box(parts, "timber", Vector3(hatch.get_center().x, mid, hatch.position.y - frame * 0.5), Vector3(hatch.size.x, deck - under, frame))
	VillageHouse._box(parts, "timber", Vector3(hatch.get_center().x, mid, hatch.end.y + frame * 0.5), Vector3(hatch.size.x, deck - under, frame))
	if not with_parapet:
		return # A mage tower's top floor has walls and a roof of its own (see MageTower).
	# The parapet: a low wall of stone on the edge, merlons on it.
	var pt := PARAPET_THICK
	var low := deck + PARAPET_LOW - eaves
	var high := PARAPET - PARAPET_LOW
	for side: float in [-1.0, 1.0]:
		VillageHouse._box(parts, "stone", Vector3(0, eaves + low * 0.5, side * (ud * 0.5 - pt * 0.5)), Vector3(uw, low, pt))
		VillageHouse._box(parts, "stone", Vector3(side * (uw * 0.5 - pt * 0.5), eaves + low * 0.5, 0), Vector3(pt, low, ud - pt * 2.0))
		var n := maxi(2, roundi(uw / (MERLON * 2.0)))
		for i in n:
			var x := -uw * 0.5 + (i + 0.5) * uw / n
			VillageHouse._box(parts, "stone", Vector3(x, eaves + low + high * 0.5, side * (ud * 0.5 - pt * 0.5)), Vector3(MERLON, high, pt + 0.04))
		var m := maxi(2, roundi(ud / (MERLON * 2.0)))
		for i in m:
			var z := -ud * 0.5 + (i + 0.5) * ud / m
			VillageHouse._box(parts, "stone", Vector3(side * (uw * 0.5 - pt * 0.5), eaves + low + high * 0.5, z), Vector3(pt + 0.04, high, MERLON))


## The upper storey built hollow (into `groups`, see VillageHouse.hollow): each of its four walls
## with its windows, outside and in, in a group of its own so whichever faces the camera can hide,
## and the boards of its floor, open over the stairs coming up from below.
static func upper_storey(shape: Dictionary, groups: Dictionary) -> void:
	var lay := layout(shape)
	var t := VillageHouse.WALL_THICK
	var uw := float(shape.w) + VillageHouse.JETTY * 2.0
	var ud := float(shape.d) + VillageHouse.JETTY * 2.0
	var top: float = lay.top
	var high := VillageHouse.UPPER
	var mid := top + high * 0.5
	VillageHouse._box(groups.storey_front, "plaster", Vector3(0, mid, ud * 0.5 - t * 0.5), Vector3(uw, high, t))
	VillageHouse._box(groups.storey_back, "plaster", Vector3(0, mid, -ud * 0.5 + t * 0.5), Vector3(uw, high, t))
	for side: float in [-1.0, 1.0]:
		var group: Dictionary = groups.storey_right if side > 0.0 else groups.storey_left
		VillageHouse._box(group, "plaster", Vector3(side * (uw * 0.5 - t * 0.5), mid, 0), Vector3(t, high, ud - t * 2.0))
		# The window in the middle of the wall, as on the solid house (see VillageHouse._shape).
		var outer := Vector3(side * uw * 0.5, top + 1.3, 0)
		VillageHouse._window(group, outer, side * PI * 0.5)
		VillageHouse._inner_window(group, outer, Vector3(side * (uw * 0.5 - t), top + 1.3, 0), side * PI * 0.5)
	for x: float in VillageHouse._window_spots(uw, INF):
		var outer := Vector3(x, top + 1.3, ud * 0.5)
		VillageHouse._window(groups.storey_front, outer, 0.0)
		VillageHouse._inner_window(groups.storey_front, outer, Vector3(x, top + 1.3, ud * 0.5 - t), 0.0)
	# The boards, open over the stairs up from the ground floor.
	var room: Rect2 = lay.up_room
	var well: Rect2 = lay.stairwell
	var hole := Rect2(well.position.x - room.position.x, room.end.y - well.end.y, well.size.x, well.size.y)
	VillageHouse._face(groups.storey_room, "floor", Vector3(room.position.x, lay.up_floor, room.end.y), Vector3.RIGHT, Vector3.FORWARD, room.size, hole)
	# The wall tops round the room, seen from above once the roof is off.
	VillageHouse._face(groups.storey_room, "plaster", Vector3(-uw * 0.5, lay.eaves - 0.001, ud * 0.5), Vector3.RIGHT, Vector3.FORWARD, Vector2(uw, t))
	VillageHouse._face(groups.storey_room, "plaster", Vector3(-uw * 0.5, lay.eaves - 0.001, -ud * 0.5 + t), Vector3.RIGHT, Vector3.FORWARD, Vector2(uw, t))


# --- Opening the hall ------------------------------------------------------------------

## Furnishes the opened guildhall (see VillageHalls.furnish, which has set Ragna's desk): the
## floors and walls one bumps into, the three flights with their railings, the furniture of every
## storey, the cellar under it all and Ragna's bed down there, and the way to it.
static func furnish(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var hall: Node3D = rec.node
	var shape: Dictionary = hall.get_meta("shape")
	var lay := layout(shape)
	rec["layout"] = lay
	var w: float = shape.w
	var d: float = shape.d
	var uw := w + VillageHouse.JETTY * 2.0
	var ud := d + VillageHouse.JETTY * 2.0
	# The floors: the ground floor's boards round the well down, the upper floor's round the
	# stairwell, the deck round the hatch; and the upper storey's walls, up to the parapet's top.
	_floor_around(walk_in, rec, Rect2(-w * 0.5, -d * 0.5, w, d), lay.well, 0.0, lay.floor)
	_floor_around(walk_in, rec, lay.up_room, lay.stairwell, float(lay.top) - 0.3, lay.up_floor)
	# (The deck is thin underneath: the hero is tall, see Player.tall, and walks under it upstairs.)
	_floor_around(walk_in, rec, Rect2(-uw * 0.5, -ud * 0.5, uw, ud), lay.hatch, float(lay.eaves) - 0.02, lay.deck)
	var t := VillageHouse.WALL_THICK
	var out := 0.15
	var y0: float = lay.top
	var y1: float = lay.wall_top
	var wall_mid := (y0 + y1) * 0.5
	for side: float in [-1.0, 1.0]:
		walk_in._solid(rec, Vector3(0, wall_mid, side * (ud * 0.5 + (out - t) * 0.5)), Vector3(uw + out * 2.0, y1 - y0, t + out))
		walk_in._solid(rec, Vector3(side * (uw * 0.5 + (out - t) * 0.5), wall_mid, 0), Vector3(t + out, y1 - y0, ud + out * 2.0))
	_flights(walk_in, rec, lay, inside)
	if bool(lay.mage):
		MageTower.rooms(walk_in, rec, lay, inside)
		return
	_ground_floor(walk_in, rec, lay, inside)
	_upper_floor(walk_in, rec, lay)
	_roof(walk_in, rec, lay)
	_cellar(walk_in, rec, lay)


## Boxes one walks on over `area` (the hall's frame) from `y0` to `y1`, open over `hole`.
static func _floor_around(walk_in: WalkIn, rec: Dictionary, area: Rect2, hole: Rect2, y0: float, y1: float) -> void:
	var rects: Array[Rect2] = [
		Rect2(area.position.x, area.position.y, hole.position.x - area.position.x, area.size.y),
		Rect2(hole.end.x, area.position.y, area.end.x - hole.end.x, area.size.y),
		Rect2(hole.position.x, area.position.y, hole.size.x, hole.position.y - area.position.y),
		Rect2(hole.position.x, hole.end.y, hole.size.x, area.end.y - hole.end.y),
	]
	for r in rects:
		if r.size.x > 0.01 and r.size.y > 0.01:
			walk_in._solid(rec, Vector3(r.get_center().x, (y0 + y1) * 0.5, r.get_center().y), Vector3(r.size.x, y1 - y0, r.size.y))


## A box that stops everyone, from its corners in the hall's frame.
static func _block(walk_in: WalkIn, rec: Dictionary, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	walk_in._solid(rec, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)))


## The three flights: their steps one walks up (a wedge each), what they look like, and the
## railings along their open sides and round the openings above them.
static func _flights(walk_in: WalkIn, rec: Dictionary, lay: Dictionary, inside: Node3D) -> void:
	var hall: Node3D = rec.node
	for key: String in ["a", "b", "c"]:
		var f: Dictionary = lay[key]
		var wedge := PackedVector3Array()
		for x: float in [float(f.x0), float(f.x1)]:
			wedge.append(Vector3(x, f.low, f.foot))
			wedge.append(Vector3(x, f.low, f.top))
			wedge.append(Vector3(x, f.high, f.top))
		walk_in._wedge(rec, wedge)
	var upper := _group_node(hall, "GuildUpper")
	rec.storey_room.append(upper)
	var cellar := Node3D.new()
	cellar.name = "GuildCellar"
	cellar.transform = hall.transform
	walk_in.level.add_child(cellar)
	rec["cellar_node"] = cellar
	_steps(inside, lay.a)
	_steps(upper, lay.b)
	_steps(cellar, lay.c)
	var a: Dictionary = lay.a
	var b: Dictionary = lay.b
	var c: Dictionary = lay.c
	var room: Rect2 = lay.room
	var up_room: Rect2 = lay.up_room
	var floor: float = lay.floor
	var up_floor: float = lay.up_floor
	var deck: float = lay.deck
	# Up from the ground floor: a balustrade along its open side, which goes on round the stairwell
	# upstairs; nothing slips through the gap over the jetty on the right either.
	_block(walk_in, rec, a.x0 - 0.1, a.x0, floor, up_floor + RAIL, a.top, a.foot)
	_block(walk_in, rec, room.end.x - 0.02, up_room.end.x, lay.top, up_floor + RAIL, a.top, a.foot)
	_block(walk_in, rec, a.x0 - 0.1, up_room.end.x, up_floor, up_floor + RAIL, a.foot, a.foot + 0.1)
	_slope_rail(inside, a, a.x0 - 0.05)
	_rail(upper, Vector3(a.x0 - 0.05, up_floor, a.top), Vector3(a.x0 - 0.05, up_floor, a.foot))
	_rail(upper, Vector3(a.x0 - 0.05, up_floor, a.foot + 0.05), Vector3(up_room.end.x, up_floor, a.foot + 0.05))
	# Up to the roof: a balustrade along it, and round the hatch on the deck.
	var hatch_end: float = (lay.hatch as Rect2).end.y
	_block(walk_in, rec, b.x1, b.x1 + 0.1, up_floor, deck + RAIL, b.top, b.foot)
	_block(walk_in, rec, b.x1, b.x1 + 0.1, float(lay.eaves) - 0.02, deck + RAIL, b.foot, hatch_end)
	_block(walk_in, rec, b.x0, b.x1 + 0.1, deck, deck + RAIL, hatch_end, hatch_end + 0.1)
	_slope_rail(upper, b, b.x1 + 0.05)
	var roof := _group_node(hall, "GuildRoof")
	rec.up.append(roof)
	rec["roof_node"] = roof
	_rail(roof, Vector3(b.x1 + 0.05, deck, b.top), Vector3(b.x1 + 0.05, deck, hatch_end))
	_rail(roof, Vector3(b.x0, deck, hatch_end + 0.05), Vector3(b.x1 + 0.05, deck, hatch_end + 0.05))
	# Down to the cellar: a railing along the well on the ground floor and across its far end (the
	# strip of floor between it and the wall is too narrow to walk), and a wall of stone beside the
	# flight down there.
	var well_end: float = (lay.well as Rect2).position.y
	_block(walk_in, rec, c.x1, c.x1 + 0.1, floor, floor + RAIL, well_end, c.top)
	_block(walk_in, rec, c.x0 - 0.4, c.x1 + 0.1, floor, floor + RAIL, well_end - 0.1, well_end)
	_block(walk_in, rec, c.x1, c.x1 + 0.2, CELLAR, 0.0, c.foot, HOLE)
	_rail(inside, Vector3(c.x1 + 0.05, floor, c.top), Vector3(c.x1 + 0.05, floor, well_end))
	_rail(inside, Vector3(c.x1 + 0.05, floor, well_end - 0.05), Vector3(room.position.x, floor, well_end - 0.05))


## A node under the hall for one storey's things.
static func _group_node(hall: Node3D, name: String) -> Node3D:
	var node := Node3D.new()
	node.name = name
	hall.add_child(node)
	return node


## The wooden steps of a flight (see WoodStairs.build_flight), under `parent` (the hall's frame).
static func _steps(parent: Node3D, f: Dictionary) -> void:
	var x := (float(f.x0) + float(f.x1)) * 0.5
	var along := signf(float(f.top) - float(f.foot))
	var length := absf(float(f.top) - float(f.foot))
	var flight := WoodStairs.build_flight(parent, Vector3(x, f.low, f.foot), Vector3(0, 0, along), length, float(f.high) - float(f.low), STAIR_WIDE)
	flight.name = "Flight"


## A wooden railing from `a` to `b` (on the floor, the hall's frame): posts and a hand rail RAIL high.
static func _rail(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var wood := WalkInFurniture._wood()
	var along := b - a
	var length := along.length()
	if length < 0.05:
		return
	var turn := Basis(Vector3.UP, atan2(along.x, along.z))
	var n := maxi(1, ceili(length / POST_EVERY))
	for i in n + 1:
		var at := a + along * (float(i) / n)
		WalkInFurniture._box(parent, Vector3(0.08, RAIL, 0.08), at + Vector3(0, RAIL * 0.5, 0), wood)
	WalkInFurniture._box(parent, Vector3(0.07, 0.07, length + 0.08), (a + b) * 0.5 + Vector3(0, RAIL, 0), wood, turn)
	WalkInFurniture._box(parent, Vector3(0.05, 0.05, length), (a + b) * 0.5 + Vector3(0, RAIL * 0.5, 0), wood, turn)


## A railing along a flight's side at `x`, following its slope: posts on the steps and a sloping rail.
static func _slope_rail(parent: Node3D, f: Dictionary, x: float) -> void:
	var wood := WalkInFurniture._wood()
	var foot := Vector3(x, f.low, f.foot)
	var top := Vector3(x, f.high, f.top)
	var n := maxi(2, ceili(absf(float(f.top) - float(f.foot)) / POST_EVERY))
	for i in n + 1:
		var at := foot.lerp(top, float(i) / n)
		WalkInFurniture._box(parent, Vector3(0.08, RAIL, 0.08), at + Vector3(0, RAIL * 0.5, 0), wood)
	var along := top - foot
	var turn := Basis.looking_at(along.normalized(), Vector3.UP)
	WalkInFurniture._box(parent, Vector3(0.07, 0.07, along.length() + 0.08), (foot + top) * 0.5 + Vector3(0, RAIL, 0), wood, turn)


## Puts `thing` (a piece of furniture) under `parent` at `at` (the hall's frame) turned `turn`, and
## a box of `size` round it that stops everyone (its foot on the floor), unless the size is zero.
static func _put(walk_in: WalkIn, rec: Dictionary, parent: Node3D, thing: Node3D, at: Vector3, turn := 0.0, size := Vector3.ZERO) -> Node3D:
	thing.position = at
	thing.rotation.y = turn
	parent.add_child(thing, true)
	if size != Vector3.ZERO:
		var turned := size if absf(sin(turn)) < 0.5 else Vector3(size.z, size.y, size.x)
		walk_in._solid(rec, at + Vector3(0, turned.y * 0.5, 0), turned)
	return thing


## The ground floor: banners over Ragna's desk, the tavern corner (two tables with stools and
## mugs, barrels under the landing), a rack of weapons on the back wall.
static func _ground_floor(walk_in: WalkIn, rec: Dictionary, lay: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = lay.room
	var y: float = lay.floor
	var back := room.position.y
	for x: float in [-1.0, 1.0]:
		var flag := WalkInFurniture.banner(GUILD_RED, 1.4)
		flag.position = Vector3(x, y + 2.5, back)
		inside.add_child(flag)
	# The tavern corner: a table either side of the aisle from the door to the desk.
	for spot: Vector3 in [Vector3(-1.5, y, 0.3), Vector3(1.6, y, 0.3)]:
		_put(walk_in, rec, inside, WalkInFurniture.table(0.55), spot, 0.0, Vector3(1.1, 0.8, 1.1))
		# (Stools at the tables' front and back only: the aisle side stays wide enough for the hero, and the
		# outer sides are the flights' way and the stairs' rail.)
		var stools: Array = [Vector3(0, 0, 0.85), Vector3(0, 0, -0.85)]
		for at: Vector3 in stools:
			_put(walk_in, rec, inside, WalkInFurniture.stool(), spot + at)
			Seats.add_stool(walk_in, rec, spot + at, spot)
		_put(walk_in, rec, inside, WalkInFurniture.mug(), spot + Vector3(0.15, 0.79, -0.1))
	# Barrels in the back corner on the left, beyond the well; a rack of weapons in the one on the
	# right, under the landing upstairs.
	for k in 2:
		_put(walk_in, rec, inside, WalkInFurniture.barrel(), Vector3(room.position.x + 0.45 + k * 0.72, y, back + 0.45), 0.0, Vector3(0.64, 0.9, 0.64))
	var rack_w := 1.5
	_put(walk_in, rec, inside, WalkInFurniture.weapon_rack(rack_w), Vector3(room.end.x - rack_w * 0.5 - 0.15, y, back + 0.2), 0.0, Vector3(rack_w, 1.5, 0.4))


## The upper floor, the guild's map room: a long table with the map of the land on it and stools
## round it on a rug, a bookcase and chests on the back wall, banners, and a rack of weapons by
## the front wall.
static func _upper_floor(walk_in: WalkIn, rec: Dictionary, lay: Dictionary) -> void:
	var upper: Node3D = (rec.node as Node3D).get_node("GuildUpper")
	var room: Rect2 = lay.up_room
	var y: float = lay.up_floor
	var back := room.position.y
	var mid := Vector3(-0.3, y, 0.5)
	_put(walk_in, rec, upper, WalkInFurniture.rug(Vector2(3.6, 2.6)), mid)
	var table := WalkInFurniture.counter(2.4, 0.85, 1.1)
	table.name = "MapTable"
	_put(walk_in, rec, upper, table, mid, 0.0, Vector3(2.4, 0.9, 1.1))
	WalkInFurniture._box(upper, Vector3(1.7, 0.01, 0.85), mid + Vector3(0, 0.86, 0), WalkInFurniture._plain("guild_map", MAP_PAPER), Basis(Vector3.UP, 0.05))
	for dot: Vector3 in [Vector3(-0.5, 0, -0.2), Vector3(0.3, 0, 0.15), Vector3(0.6, 0, -0.25)]:
		WalkInFurniture._box(upper, Vector3(0.08, 0.04, 0.08), mid + dot + Vector3(0, 0.88, 0), WalkInFurniture._plain("guild_red", GUILD_RED))
	for spot: Vector3 in [Vector3(-1.6, 0, 0), Vector3(1.6, 0, 0), Vector3(-0.6, 0, 0.95), Vector3(0.6, 0, 0.95), Vector3(-0.6, 0, -0.95), Vector3(0.6, 0, -0.95)]:
		_put(walk_in, rec, upper, WalkInFurniture.stool(), mid + spot)
		Seats.add_stool(walk_in, rec, mid + spot, mid)
	_put(walk_in, rec, upper, WalkInFurniture.bookcase(2.2, 2.0, 0.4), Vector3(-0.6, y, back + 0.2), 0.0, Vector3(2.2, 2.0, 0.4))
	for x: float in [1.3, 2.05]:
		_put(walk_in, rec, upper, WalkInFurniture.crate(0.6), Vector3(x, y, back + 0.4), 0.0, Vector3(0.6, 0.6, 0.6))
	for x: float in [-2.7, 1.7]:
		var flag := WalkInFurniture.banner(GUILD_RED, 1.2)
		flag.position = Vector3(x, y + 2.2, back)
		upper.add_child(flag)
	_put(walk_in, rec, upper, WalkInFurniture.weapon_rack(1.6), Vector3(0.6, y, room.end.y - 0.2), PI, Vector3(1.6, 1.5, 0.4))
	var lamp := _lamp(upper, Vector3(0, y + 2.1, 0))
	rec["storey_lamps"] = rec.get("storey_lamps", {})
	rec.storey_lamps[UPPER_STOREY] = lamp


## The roof, the training ground: a large mat in the middle, three straw dummies at the back, a
## rack of weapons along the parapet on the right and two ballistas looking out over the front.
static func _roof(walk_in: WalkIn, rec: Dictionary, lay: Dictionary) -> void:
	var roof: Node3D = rec.roof_node
	var y: float = lay.deck
	var room: Rect2 = lay.up_room
	var mat := Node3D.new()
	mat.name = "TrainingMat"
	WalkInFurniture._box(mat, Vector3(3.6, 0.04, 3.4), Vector3(0, 0.02, 0), WalkInFurniture._plain("mat_edge", MAT_EDGE))
	WalkInFurniture._box(mat, Vector3(3.2, 0.05, 3.0), Vector3(0, 0.025, 0), WalkInFurniture._plain("mat_red", MAT_RED))
	for k in 3:
		WalkInFurniture._box(mat, Vector3(3.22, 0.052, 0.04), Vector3(0, 0.026, -1.0 + k * 1.0), WalkInFurniture._plain("mat_seam", MAT_RED.darkened(0.3)))
	_put(walk_in, rec, roof, mat, Vector3(0.9, y, 0.7))
	for x: float in [-1.2, 0.8, 2.8]:
		_put(walk_in, rec, roof, WalkInFurniture.dummy(), Vector3(x, y, room.position.y + 0.9), 0.0, Vector3(0.6, 1.6, 0.6))
	_put(walk_in, rec, roof, WalkInFurniture.weapon_rack(1.8), Vector3(room.end.x - 0.2, y, 0.7), -PI * 0.5, Vector3(1.8, 1.5, 0.4))
	for x: float in [room.end.x - 1.1, -1.9]:
		var gun := HouseBallista.new()
		gun.name = "GuildBallista"
		_put(walk_in, rec, roof, gun, Vector3(x, y, room.end.y - 1.0), 0.0, Vector3(1.0, 1.6, 1.4))


## The cellar under the hall, Ragna's own room: stone walls and flags, the flight down along its
## left wall, her bed by the back wall with a bedside table, a chest at its foot, a wardrobe, a
## table and a stool, a rack of her blades and barrels of wine; lit by a lamp. Its hole in the
## ground goes to the level (Outdoor.hall_holes), and Ragna sleeps here (see VillageBeds).
static func _cellar(walk_in: WalkIn, rec: Dictionary, lay: Dictionary) -> void:
	var hall: Node3D = rec.node
	var cellar: Node3D = rec.cellar_node
	var shape: Dictionary = hall.get_meta("shape")
	var y := CELLAR
	var h := HOLE
	# The floor one stands on (the ground's own is open here) and the flags on it.
	walk_in._solid(rec, Vector3(0, y - 0.25, 0), Vector3(h * 2.0, 0.5, h * 2.0))
	var flags := WalkInFurniture.flagstones(Vector2(h * 2.0, h * 2.0), y + 0.005)
	cellar.add_child(flags)
	# The walls, each facing into the room (the one nearest the camera shows its back and is not drawn).
	var parts := {}
	var deep := -y
	VillageHouse._face(parts, "stone", Vector3(-h, y, -h), Vector3.RIGHT, Vector3.UP, Vector2(h * 2.0, deep))
	VillageHouse._face(parts, "stone", Vector3(-h, y, h), Vector3.FORWARD, Vector3.UP, Vector2(h * 2.0, deep))
	VillageHouse._face(parts, "stone", Vector3(h, y, -h), Vector3.BACK, Vector3.UP, Vector2(h * 2.0, deep))
	VillageHouse._face(parts, "stone", Vector3(h, y, h), Vector3.LEFT, Vector3.UP, Vector2(h * 2.0, deep))
	# The wall beside the flight down (it falls towards the back, where its landing is).
	var c: Dictionary = lay.c
	VillageHouse._box(parts, "stone", Vector3(float(c.x1) + 0.1, y * 0.5, (h + float(c.foot)) * 0.5), Vector3(0.2, deep, h - float(c.foot)))
	var walls := VillageHouse._mesh_of(parts, shape.mats)
	walls.name = "CellarWalls"
	cellar.add_child(walls)
	# Ragna's bed, its head to the right wall, the bedside table on its right (towards the front).
	var turn := -PI * 0.5
	var origin := Vector3(h - 0.02 + CosyBed.HEAD, y, -0.2)
	var bed := CosyBed.build(cellar, origin, turn, true)
	bed.name = "GuildMasterBed"
	var foot_x := origin.x - CosyBed.FOOT
	walk_in._solid(rec, Vector3((foot_x + h) * 0.5, y + 0.5, origin.z + (CosyBed.LEFT + CosyBed.RIGHT) * 0.5),
			Vector3(h - foot_x, 1.0, CosyBed.RIGHT - CosyBed.LEFT))
	walk_in._solid(rec, Vector3(h - 0.35, y + 0.4, origin.z + (CosyBed.RIGHT + CosyBed.TABLE_EDGE) * 0.5), Vector3(0.6, 0.8, CosyBed.TABLE_EDGE - CosyBed.RIGHT))
	var stand := hall.transform * Vector3(origin.x - (CosyBed.FOOT + CosyBed.HEAD) * 0.5, y, origin.z + CosyBed.LEFT - 0.6)
	rec.beds.append({"pos": hall.transform * origin, "rot": hall.rotation.y + turn, "by": null, "stand": stand})
	rec["ground_beds"] = true
	rec["ladder"] = stand
	rec["ladder_top"] = stand
	rec["owner"] = VillageHalls.KEEPERS.guild
	# The way down to it from inside the door (see VillageBeds).
	var inner: Array[Vector3] = []
	for p in way(lay, GROUND_STOREY, CELLAR_STOREY):
		inner.append(hall.transform * p)
	rec["inner_way"] = inner
	# Her things: a chest at the bed's foot, a rug beside it, a wardrobe and a rack of her blades on
	# the back wall, a stool in the front, and wine barrels along the front wall.
	_put(walk_in, rec, cellar, WalkInFurniture.crate(0.7), Vector3(foot_x - 0.5, y, origin.z), 0.0, Vector3(0.7, 0.7, 0.7))
	_put(walk_in, rec, cellar, WalkInFurniture.rug(Vector2(2.2, 1.4)), Vector3(origin.x - 0.4, y + 0.005, origin.z + CosyBed.LEFT - 0.75))
	_put(walk_in, rec, cellar, WalkInFurniture.bookcase(1.8, 2.0, 0.5), Vector3(h - 1.3, y, -h + 0.25), 0.0, Vector3(1.8, 2.0, 0.5))
	_put(walk_in, rec, cellar, WalkInFurniture.weapon_rack(1.4), Vector3(-0.2, y, -h + 0.2), 0.0, Vector3(1.4, 1.5, 0.4))
	# A stool to sit on by the bed (no little table in the way).
	var stool_at := Vector3(-0.3, y, 2.4)
	_put(walk_in, rec, cellar, WalkInFurniture.stool(), stool_at)
	Seats.add_stool(walk_in, rec, stool_at, Vector3(0, y, 0))
	for k in 3:
		_put(walk_in, rec, cellar, WalkInFurniture.barrel(), Vector3(1.6 + k * 0.75, y, h - 0.45), 0.0, Vector3(0.64, 0.9, 0.64))
	var lamp := _lamp(cellar, Vector3(0.5, y + 2.1, 0.0))
	rec["storey_lamps"] = rec.get("storey_lamps", {})
	rec.storey_lamps[CELLAR_STOREY] = lamp
	# The hole in the ground: the 2 m cells under the cellar (world, see Outdoor.set_floor_holes).
	var holes = walk_in.level.get("hall_holes")
	if holes is Array:
		var mid := hall.global_position if hall.is_inside_tree() else hall.position
		for i in range(-2, 2):
			for j in range(-2, 2):
				(holes as Array).append(Rect2(mid.x + i * 2.0, mid.z + j * 2.0, 2.0, 2.0))


## A warm lamp of a storey (hidden until the hero is there, see WalkIn._show_inside).
static func _lamp(parent: Node3D, at: Vector3) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = "StoreyLamp"
	lamp.light_color = WalkIn.LAMP_COLOUR
	lamp.light_energy = WalkIn.LAMP_ENERGY
	lamp.omni_range = WalkIn.LAMP_RANGE
	lamp.omni_attenuation = WalkIn.LAMP_FALLOFF
	lamp.position = at
	lamp.visible = false
	# Walls all round it (see LightShadows.INDOOR), or it lit the snow outside through the wall.
	lamp.set_meta(LightShadows.INDOOR, true)
	parent.add_child(lamp)
	return lamp
