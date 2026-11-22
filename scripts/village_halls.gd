class_name VillageHalls
extends RefCounted
## The village's halls one can walk into: the tavern, the shop, the post office, the Crown office
## and the adventurers' guild, built in the
## village's own style (a VillageHouse, stone plinth, timber framing, plaster and ivy) instead of
## the old kit models, each with a sign by its door and its own furniture inside (see WalkIn, which
## opens them like the villagers' houses). Usability first: a door in the middle of the front, a
## free way from it to the counter or desk, where the hall's keeper works by day (see KEEPERS and
## VillagePosts): Mira behind the shop counter, Clerk Gero at his desk in the Crown office among
## the land registers, Guild Master Ragna at hers in the guildhall, between its tavern corner and
## its training corner.
##
## Each hall has its own switch in WalkIn.halls; with it off the hall is the old solid kit model.

## The map letters of the halls and what they are.
const KINDS := {"n": "tavern", "m": "shop", "o": "post", "k": "office", "w": "guild", "u": "mill"}
## Who keeps which hall (villager roles), working behind its counter or desk by day.
const KEEPERS := {"shop": "6", "office": "¢", "guild": "G", "mill": "ü"}
## How big a hall may grow (metres, inside its block): wider and deeper than a home, and the big
## halls on their three-by-three blocks bigger still.
const MAX_W := 9.4
const MAX_D := 6.4
const BIG := ["office", "guild"]
const BIG_W := 9.8
const BIG_D := 8.6
## The mill's stone storey (metres across, square).
const MILL_W := 6.4
## The desk of the Crown office and the guildhall: lower than a counter, and deeper.
const DESK_HIGH := 0.85
const DESK_DEEP := 0.8
const DESK_WIDE := 2.4
## Behind a counter: how far it stands from the back wall (the keeper's room), and how deep it is.
const BEHIND := 1.1
const COUNTER_DEEP := 0.6
const COUNTER_HIGH := 1.0
## The sign: how far out from the wall its arm reaches and how high it hangs.
const SIGN_OUT := 1.15
const SIGN_HIGH := 3.0
## How far beside the door a sign hung flat to the wall is, so it clears the doorway.
const SIGN_ASIDE := 1.65


## The style a hall's VillageHouse is built in (see VillageHouse.build).
static func style(ch: String) -> Dictionary:
	if KINDS.get(ch, "") == "mill":
		# A square stone storey under the kit's tower (see MillTower), no upper floor or roof.
		return {"max_w": MILL_W, "max_d": MILL_W, "door_x": 0.0, "tower": true}
	if KINDS.get(ch, "") in BIG:
		return {"max_w": BIG_W, "max_d": BIG_D, "door_x": 0.0}
	return {"max_w": MAX_W, "max_d": MAX_D, "door_x": 0.0}


## The kind of hall the villager of `role` keeps, or "".
static func kept_by(role: String) -> String:
	for kind: String in KEEPERS:
		if KEEPERS[kind] == role:
			return kind
	return ""


## Furnishes an opened hall (see WalkIn.open_house): the counter, and what goes with the kind.
static func furnish(walk_in: WalkIn, rec: Dictionary) -> void:
	var hall: Node3D = rec.node
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var inside := Node3D.new()
	inside.name = "HallInside"
	hall.add_child(inside)
	var back := room.position.y
	# A counter, or in the big halls a desk.
	var desk := String(rec.kind) in BIG
	var deep := DESK_DEEP if desk else COUNTER_DEEP
	var counter_z := back + BEHIND + deep * 0.5
	var counter_w := DESK_WIDE if desk else minf(room.size.x * 0.55, 4.2)
	var counter := WalkInFurniture.desk(counter_w, DESK_HIGH, deep) if desk else WalkInFurniture.counter(counter_w, COUNTER_HIGH, deep)
	counter.position = Vector3(0, floor_y, counter_z)
	inside.add_child(counter)
	walk_in._solid(rec, Vector3(0, floor_y + 0.6, counter_z), Vector3(counter_w, 1.2, deep))
	# Whoever keeps the hall stands behind the counter, facing the door.
	rec["posts"] = [{"pos": hall.transform * Vector3(0, floor_y, back + BEHIND * 0.5), "rot": hall.rotation.y,
			"front": hall.transform * Vector3(0, floor_y, counter_z + deep * 0.5 + 0.6)}]
	match String(rec.kind):
		"tavern":
			_tavern(walk_in, rec, inside)
		"shop":
			_shop(walk_in, rec, inside)
		"post":
			_post(walk_in, rec, inside)
		"office":
			_office(walk_in, rec, inside)
		"guild":
			_guild(walk_in, rec, inside)
		"mill":
			_mill(walk_in, rec, inside)


## Barrels along the back wall behind the bar, two tables with stools either side of the way in.
static func _tavern(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var back := room.position.y
	_along_back(walk_in, rec, inside, func(): return WalkInFurniture.barrel(), 0.75, 0.42)
	var table_z := room.end.y - 1.6
	for side: float in [-1.0, 1.0]:
		var x := side * (room.size.x * 0.5 - 1.2)
		var table := WalkInFurniture.table(0.55)
		table.position = Vector3(x, floor_y, table_z)
		inside.add_child(table)
		walk_in._solid(rec, Vector3(x, floor_y + 0.4, table_z), Vector3(1.1, 0.8, 1.1))
		for dz: float in [-0.85, 0.85]:
			var stool := WalkInFurniture.stool()
			stool.position = Vector3(x, floor_y, table_z + dz)
			inside.add_child(stool)
	# Mugs on the bar.
	for x: float in [-0.9, -0.5, 0.7]:
		var mug := WalkInFurniture.mug()
		mug.position = Vector3(x, floor_y + COUNTER_HIGH, back + BEHIND + COUNTER_DEEP * 0.5)
		inside.add_child(mug)


## Shelves of goods along the back wall, sacks and crates by the side walls.
static func _shop(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var back := room.position.y
	var shelf_w := room.size.x - 0.6
	var shelf := WalkInFurniture.shelf(shelf_w, 2.1, 0.4, true)
	shelf.position = Vector3(0, floor_y, back + 0.2)
	inside.add_child(shelf)
	walk_in._solid(rec, Vector3(0, floor_y + 1.0, back + 0.2), Vector3(shelf_w, 2.0, 0.4))
	_by_the_sides(walk_in, rec, inside)


## Pigeonholes for the letters on the back wall, parcels stacked by the side walls.
static func _post(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var back := room.position.y
	var holes_w := minf(room.size.x - 0.6, 3.6)
	var holes := WalkInFurniture.pigeonholes(holes_w, 1.8)
	holes.position = Vector3(0, floor_y + 0.5, back + 0.18)
	inside.add_child(holes)
	walk_in._solid(rec, Vector3(0, floor_y + 1.2, back + 0.18), Vector3(holes_w, 2.4, 0.36))
	_by_the_sides(walk_in, rec, inside)


## The Crown office: the land registers on bookcases along the back wall behind the clerk's desk,
## blue banners of the Crown on the side walls and a bench along each for those who wait.
static func _office(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var back := room.position.y
	var case_w := minf(2.0, (room.size.x - 0.8) * 0.5)
	for side: float in [-1.0, 1.0]:
		var books := WalkInFurniture.bookcase(case_w, 2.2, 0.4)
		books.position = Vector3(side * (case_w * 0.5 + 0.3), floor_y, back + 0.2)
		inside.add_child(books)
		walk_in._solid(rec, books.position + Vector3(0, 1.0, 0), Vector3(case_w, 2.0, 0.4))
	_benches(walk_in, rec, inside, Color(0.25, 0.35, 0.8))


## The guildhall: the guild master's desk at the back under the guild's banners, a tavern corner on
## the left (barrels, tables and stools) and a training corner on the right (a rack of weapons and a
## straw dummy).
static func _guild(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var back := room.position.y
	var half := room.size.x * 0.5
	for x: float in [-1.6, 1.6]:
		var flag := WalkInFurniture.banner(Color(0.6, 0.2, 0.15), 1.6)
		flag.position = Vector3(x, floor_y + 2.6, back)
		inside.add_child(flag)
	# The tavern corner.
	for k in 2:
		var cask := WalkInFurniture.barrel()
		cask.position = Vector3(-half + 0.45 + k * 0.7, floor_y, back + 0.45)
		inside.add_child(cask)
	walk_in._solid(rec, Vector3(-half + 0.8, floor_y + 0.5, back + 0.45), Vector3(1.5, 1.0, 0.75))
	var table_x := -half + 1.5
	for table_z: float in [back + 2.6, room.end.y - 1.8]:
		var table := WalkInFurniture.table(0.55)
		table.position = Vector3(table_x, floor_y, table_z)
		inside.add_child(table)
		walk_in._solid(rec, Vector3(table_x, floor_y + 0.4, table_z), Vector3(1.1, 0.8, 1.1))
		for dx: float in [-0.85, 0.85]:
			var stool := WalkInFurniture.stool()
			stool.position = Vector3(table_x + dx, floor_y, table_z)
			inside.add_child(stool)
		var mug := WalkInFurniture.mug()
		mug.position = Vector3(table_x + 0.15, floor_y + 0.79, table_z - 0.1)
		inside.add_child(mug)
	# The training corner.
	var rack_w := 1.8
	var rack := WalkInFurniture.weapon_rack(rack_w)
	rack.position = Vector3(half - rack_w * 0.5 - 0.2, floor_y, back + 0.2)
	inside.add_child(rack)
	walk_in._solid(rec, rack.position + Vector3(0, 0.75, 0), Vector3(rack_w, 1.5, 0.4))
	for dz: float in [2.6, room.size.y - 1.8]:
		var dummy := WalkInFurniture.dummy()
		dummy.position = Vector3(half - 1.3, floor_y, back + dz)
		dummy.rotation.y = -0.5
		inside.add_child(dummy)
		walk_in._solid(rec, dummy.position + Vector3(0, 0.8, 0), Vector3(0.6, 1.6, 0.6))


## The mill room: the millstones in the front corner on the left, under their hopper, with the
## shaft up to the sails, sacks of flour and grain heaped by the right wall, and the miller behind
## his counter at the back (see furnish).
static func _mill(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var stones := WalkInFurniture.millstones()
	var at := Vector3(room.position.x + 1.1, floor_y, room.end.y - 1.6)
	stones.position = at
	inside.add_child(stones)
	walk_in._solid(rec, at + Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.8))
	rec["millstones"] = stones
	# Sacks of flour and grain along the right wall, a crate beside them.
	var right := room.end.x
	for i in 4:
		var sack := WalkInFurniture.flour_sack()
		sack.position = Vector3(right - 0.4 - (i % 2) * 0.55, floor_y, room.end.y - 0.6 - (i / 2) * 0.75)
		sack.rotation.y = 0.4 * i
		inside.add_child(sack)
	walk_in._solid(rec, Vector3(right - 0.65, floor_y + 0.4, room.end.y - 0.95), Vector3(1.2, 0.8, 1.5))
	var crate := WalkInFurniture.crate(0.6)
	crate.position = Vector3(right - 0.45, floor_y, room.position.y + 0.45)
	inside.add_child(crate)
	walk_in._solid(rec, crate.position + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6))


## A bench along each side wall, facing in, a banner of `colour` above it.
static func _benches(walk_in: WalkIn, rec: Dictionary, inside: Node3D, colour: Color) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var z := room.position.y + room.size.y * 0.62
	var long := minf(2.4, room.size.y * 0.4)
	for side: float in [-1.0, 1.0]:
		var x := side * (room.size.x * 0.5 - 0.4)
		var bench := WalkInFurniture.pew(long)
		bench.position = Vector3(x, floor_y, z)
		bench.rotation.y = side * PI * 0.5
		inside.add_child(bench)
		walk_in._solid(rec, Vector3(x, floor_y + 0.5, z), Vector3(0.7, 1.0, long))
		var flag := WalkInFurniture.banner(colour, 1.4)
		flag.position = Vector3(side * room.size.x * 0.5, floor_y + 2.6, z - long * 0.5 - 0.8)
		flag.rotation.y = -side * PI * 0.5
		inside.add_child(flag)


## A row of things (`make` returns one) along the back wall, `step` apart, `deep` from the wall.
static func _along_back(walk_in: WalkIn, rec: Dictionary, inside: Node3D, make: Callable, step: float, deep: float) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var z := room.position.y + deep * 0.5 + 0.05
	var count := int((room.size.x - 0.4) / step)
	for i in count:
		var x := -(count - 1) * step * 0.5 + i * step
		var thing: Node3D = make.call()
		thing.position = Vector3(x, floor_y, z)
		inside.add_child(thing)
	walk_in._solid(rec, Vector3(0, floor_y + 0.5, z), Vector3(count * step, 1.0, deep))


## Crates and sacks against the side walls, in front of the counter, leaving the middle free.
static func _by_the_sides(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var z := room.end.y - 1.3
	for side: float in [-1.0, 1.0]:
		var x := side * (room.size.x * 0.5 - 0.45)
		var crate := WalkInFurniture.crate(0.7)
		crate.position = Vector3(x, floor_y, z)
		crate.rotation.y = side * 0.15
		inside.add_child(crate)
		var sack := WalkInFurniture.sack()
		sack.position = Vector3(x, floor_y, z - 0.85)
		inside.add_child(sack)
		walk_in._solid(rec, Vector3(x, floor_y + 0.4, z - 0.4), Vector3(0.8, 0.8, 1.7))


## Hangs the hall's sign beside its door: an iron bracket out from the front wall under the upper
## storey, and on two chains a big shield with the hall's mark (a mug for the tavern, scales for the
## shop, a post horn, the Crown's crown, the guild's crossed swords; see HangingShield), so
## each is easy to tell from the street. It hangs high enough to walk under, beside the doorway.
## A hall whose front looks along the camera's view (south) shows the shield flat to its wall; the
## others hang it edgewise to the wall, so from the high camera it is seen face on too.
static func hang_sign(hall: Node3D, kind: String) -> Node3D:
	var shape: Dictionary = hall.get_meta("shape")
	var d: float = shape.d
	var out_dir := Basis(Vector3.UP, hall.rotation.y) * Vector3.BACK
	var flat := out_dir.z > 0.7
	var board := HangingShield.on_wall(kind, SIGN_OUT, not flat)
	board.name = "HallSign"
	board.position = Vector3(-SIGN_ASIDE if flat else -1.0, VillageHouse.PLINTH + SIGN_HIGH, d * 0.5 + 0.02)
	hall.add_child(board)
	return board
