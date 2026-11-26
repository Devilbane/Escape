class_name VillageHalls
extends RefCounted
## The village's halls one can walk into: the tavern, the shop, the post office, the Crown office
## and the adventurers' guild, built in the
## village's own style (a VillageHouse, stone plinth, timber framing, plaster and ivy) instead of
## the old kit models, each with a sign by its door and its own furniture inside (see WalkIn, which
## opens them like the villagers' houses). Usability first: a door in the middle of the front, a
## free way from it to the counter or desk, where the hall's keeper works by day (see KEEPERS and
## VillagePosts): Mira behind the shop counter, Clerk Gero at his desk in the Crown office among
## the land registers, Guild Master Ragna at hers in the guildhall, under the guild's banners (the
## guildhall has two storeys, a roof to train on and a cellar, see GuildHall).
##
## Each hall has its own switch in WalkIn.halls; with it off the hall is the old solid kit model.

## The map letters of the halls and what they are.
const KINDS := {"n": "tavern", "m": "shop", "o": "post", "k": "office", "w": "guild", "u": "mill", "Ø": "mage"}
## Who keeps which hall (villager roles), working behind its counter or desk by day.
const KEEPERS := {"tavern": "ö", "shop": "6", "office": "¢", "guild": "G", "mill": "ü"}
## How big a hall may grow (metres, inside its block): wider and deeper than a home, and the big
## halls on their three-by-three blocks bigger still.
const MAX_W := 9.4
const MAX_D := 6.4
const BIG := ["office", "guild"]
## Who sleeps in the bedrooms upstairs in a hall, by the kind of hall: Mira with her husband Bruno and
## their children Pip and Pippi above the shop, Anselm and Konrad above the post office, Gero and
## Ilse above the Crown office. One bed each, in this order along the back wall: the shop's first two
## beds are the parents', the last two the children's, behind a partition wall (see WalkIn._bedroom).
const HOME_OWNERS := {
	"shop": ["6", "3", "7", "pippi"],
	"post": ["M", "K"],
	"office": ["¢", "µ"],
}
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
## How far the tavern's pub sign reaches out from the wall (it is wider than a shield).
const PUB_SIGN_OUT := 1.6


## The style a hall's VillageHouse is built in (see VillageHouse.build).
static func style(ch: String) -> Dictionary:
	if KINDS.get(ch, "") == "mill":
		# A square stone storey under the kit's tower (see MillTower), no upper floor or roof.
		return {"max_w": MILL_W, "max_d": MILL_W, "door_x": 0.0, "tower": true}
	if KINDS.get(ch, "") == "mage":
		# Aldo and Odo's tower: three floors under a pyramid roof, a cellar under it (see MageTower).
		return MageTower.STYLE
	if KINDS.get(ch, "") == "guild":
		# Two storeys under a flat roof one trains on, a cellar under it (see GuildHall).
		return GuildHall.STYLE
	if KINDS.get(ch, "") in BIG:
		return {"max_w": BIG_W, "max_d": BIG_D, "door_x": 0.0}
	if KINDS.get(ch, "") == "post":
		# Side windows set toward the door, so each side wall has room for two notices as well.
		return {"max_w": MAX_W, "max_d": MAX_D, "door_x": 0.0, "side_front": POST_WINDOW_FRONT}
	if KINDS.get(ch, "") == "tavern":
		# Two metres wider and deeper than the other halls, so there is room for guests besides Fritz.
		# The brewer's ladder to his bed upstairs stands by the right wall near the door (see WalkIn._loft).
		return {"max_w": MAX_W - 1.4, "max_d": MAX_D + 1.0, "door_x": 0.0, "ladder_side": 1.0}
	return {"max_w": MAX_W, "max_d": MAX_D, "door_x": 0.0}


## How far from the front of the post office the middle of its side windows is.
const POST_WINDOW_FRONT := 1.5


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
	if String(rec.kind) == "mage":
		# No counter and no keeper: the mages' tower is a home (see MageTower).
		GuildHall.furnish(walk_in, rec, inside)
		return
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


## The tavern: kegs and barrels along the back wall to either side of the keeper's place (the
## middle stays free for him), a rail of tankards over the bar, taps and mugs on the bar, a hearth
## on the left wall with a rug before it, and two tables near the door with benches and a candle
## each. Fritz's table stands by the hearth, with a high-backed chair for him (see TavernBrewer).
static func _tavern(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var back := room.position.y
	var hall: Node3D = rec.node
	var half := room.size.x * 0.5
	var counter_w := minf(room.size.x * 0.55, 4.2)
	# Barrels along the back wall beyond the counter's ends, the keeper's middle left clear.
	var z := back + 0.21 + 0.05
	for side: float in [-1.0, 1.0]:
		var x := side * (counter_w * 0.5 + 0.5)
		var count := 0
		while absf(x) < half - 0.4:
			var barrel := WalkInFurniture.barrel()
			barrel.position = Vector3(x, floor_y, z)
			inside.add_child(barrel)
			x += side * 0.75
			count += 1
		if count > 0:
			walk_in._solid(rec, Vector3(side * (counter_w * 0.5 + 0.5 + (count - 1) * 0.375), floor_y + 0.5, z), Vector3(count * 0.75, 1.0, 0.42))
	# A rail of tankards on the wall over the keeper's head.
	var rail := WalkInFurniture.mug_rail(minf(counter_w, 3.0), 5)
	rail.position = Vector3(0, floor_y + 1.75, back)
	inside.add_child(rail)
	# On the bar: a keg on its cradle at the end, three taps over a drip tray, and mugs.
	var top := floor_y + COUNTER_HIGH
	var bar_z := back + BEHIND + COUNTER_DEEP * 0.5
	var keg := WalkInFurniture.keg()
	keg.position = Vector3(-counter_w * 0.5 + 0.45, top, bar_z - 0.05)
	inside.add_child(keg)
	var tray := WalkInFurniture.drip_tray(1.0)
	tray.position = Vector3(0.3, top, bar_z + 0.12)
	inside.add_child(tray)
	for x: float in [-0.1, 0.3, 0.7]:
		var tap := WalkInFurniture.beer_tap()
		tap.position = Vector3(x, top, bar_z - 0.02)
		inside.add_child(tap)
	for x: float in [-0.6, 1.25, 1.55]:
		var mug := WalkInFurniture.mug()
		mug.position = Vector3(x, top, bar_z + 0.08)
		inside.add_child(mug)
	# The hearth on the left wall, a rug before it.
	var hearth_z := back + room.size.y * 0.5 + 0.2
	var hearth := WalkInFurniture.hearth(1.5)
	hearth.position = Vector3(room.position.x, floor_y, hearth_z)
	hearth.rotation.y = PI * 0.5
	inside.add_child(hearth)
	walk_in._solid(rec, Vector3(room.position.x + 0.3, floor_y + 0.7, hearth_z), Vector3(0.6, 1.4, 1.6))
	var rug := WalkInFurniture.rug(Vector2(1.6, 1.3))
	rug.position = Vector3(room.position.x + 1.3, floor_y, hearth_z)
	rug.rotation.y = PI * 0.5
	inside.add_child(rug)
	rec["glows"] = [hearth.get_node("HearthGlow")]
	(hearth.get_node("HearthGlow") as Light3D).visible = false
	# A notice by the door side.
	var notice := WalkInFurniture.poster(PubSign.NAME, ["Bier vom Fass", "Suppe, Brot, Käse", "Anschreiben: Fritz"])
	notice.position = Vector3(half, floor_y + 1.85, back + room.size.y * 0.5 + 0.4)
	notice.rotation.y = -PI * 0.5
	inside.add_child(notice)
	# Tables with benches; Fritz's, on the left by the hearth, has his chair on the door side. The
	# right-hand side has a table further back for other guests.
	var table_z := room.end.y - 1.7
	# The right-hand front corner is the brewer's ladder up to his bed (see WalkIn._loft).
	var spots: Array = [[-1.0, table_z], [1.0, table_z - 1.7]]
	for spot: Array in spots:
		var side: float = spot[0]
		var tz: float = spot[1]
		var x := side * (half - 1.3)
		var table := WalkInFurniture.table(0.55)
		table.position = Vector3(x, floor_y, tz)
		inside.add_child(table)
		walk_in._solid(rec, Vector3(x, floor_y + 0.4, tz), Vector3(1.1, 0.8, 1.1))
		var candle := WalkInFurniture.table_candle()
		candle.position = Vector3(x, floor_y + 0.79, tz)
		inside.add_child(candle)
		for dz: float in [-0.85, 0.85]:
			var seat: Node3D
			if side < 0.0 and dz > 0.0:
				seat = WalkInFurniture.chair()
				seat.rotation.y = PI
			else:
				seat = WalkInFurniture.bench(1.3)
				seat.rotation.y = 0.0 if dz < 0.0 else PI
			seat.position = Vector3(x, floor_y, tz + dz)
			inside.add_child(seat)
			# One can sit on them: the chair for one, the bench for two (see Seats).
			if seat.name == "Chair":
				Seats.add_indoor(walk_in, rec, seat.position, seat.rotation.y, Vector3(0.5, 0.9, 0.5))
			else:
				Seats.add_indoor(walk_in, rec, seat.position, seat.rotation.y, Vector3(1.3, 0.5, 0.3), 0.485, [-0.32, 0.32])
	# Fritz's seat: on the chair, facing the table; the brewer brings his beer and stands beside it.
	var chair_at := Vector3(-(half - 1.3), floor_y, table_z + 0.85)
	var mug_spot := WalkInFurniture.mug()
	mug_spot.position = Vector3(-(half - 1.3), floor_y + 0.79, table_z + 0.25)
	mug_spot.visible = false
	inside.add_child(mug_spot)
	# Fritz's second place, for sleeping off the night: standing before the bar, folded over it
	# (see TavernBrewer.doze). By day he only ever sits at his table.
	var bar_front := Vector3(-counter_w * 0.25, floor_y, back + BEHIND + COUNTER_DEEP + 0.45)
	rec["seats"] = [{"role": TavernBrewer.GUEST, "kind": "table", "pos": hall.transform * chair_at, "rot": hall.rotation.y + PI,
			"serve": hall.transform * Vector3(-(half - 1.3) + 1.05, floor_y, table_z + 0.45), "mug": mug_spot},
			{"role": TavernBrewer.GUEST, "kind": "counter", "pos": hall.transform * bar_front, "rot": hall.rotation.y + PI,
			"serve": hall.transform * bar_front, "mug": mug_spot}]


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


## Half the width of a side window with its frame, and the space left between it and a notice.
const WINDOW_HALF := 0.55
const NOTICE_GAP := 0.15
## Pigeonholes for the letters on the back wall, parcels (stamped and not yet stamped) stacked by the
## side walls and a sack of letters by the door.
static func _post(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = rec.room
	var floor_y: float = rec.floor
	var back := room.position.y
	var holes_w := minf(room.size.x - 0.6, 3.6)
	var holes := WalkInFurniture.pigeonholes(holes_w, 1.8)
	holes.position = Vector3(0, floor_y + 0.5, back + 0.18)
	inside.add_child(holes)
	walk_in._solid(rec, Vector3(0, floor_y + 1.2, back + 0.18), Vector3(holes_w, 2.4, 0.36))
	var z := room.end.y - 1.3
	for side: float in [-1.0, 1.0]:
		# The corner by the ladder up to the bedrooms stays free (see WalkIn._bedroom).
		if side == WalkIn.ladder_side(0.0):
			continue
		var x := side * (room.size.x * 0.5 - 0.45)
		# Two parcels stacked, a stamped one under an unstamped one, and another beside them.
		var low := WalkInFurniture.parcel(Vector3(0.7, 0.32, 0.5), side < 0.0)
		low.position = Vector3(x, floor_y, z)
		low.rotation.y = side * 0.15
		inside.add_child(low)
		var high := WalkInFurniture.parcel(Vector3(0.5, 0.26, 0.4), side > 0.0)
		high.position = Vector3(x, floor_y + 0.32, z)
		high.rotation.y = -side * 0.3
		inside.add_child(high)
		var small := WalkInFurniture.parcel(Vector3(0.4, 0.22, 0.3), side < 0.0)
		small.position = Vector3(x, floor_y, z - 0.75)
		small.rotation.y = side * 0.4
		inside.add_child(small)
		walk_in._solid(rec, Vector3(x, floor_y + 0.4, z - 0.4), Vector3(0.8, 0.8, 1.7))
	# Post things on the counter: ledger and quill and a scale to the left, stamp, wax and a few letters to the right.
	var top := floor_y + COUNTER_HIGH
	var cz := back + BEHIND + COUNTER_DEEP * 0.5
	var on_top := [
		[WalkInFurniture.ledger_and_quill(), Vector3(-1.1, 0, 0.0), 0.2],
		[WalkInFurniture.parcel_scale(), Vector3(-0.4, 0, 0.0), 0.0],
		[WalkInFurniture.stamp_and_ink(), Vector3(0.45, 0, -0.08), 0.0],
		[WalkInFurniture.wax_and_seal(), Vector3(0.95, 0, 0.05), 0.0],
	]
	# Pulled in on a narrow counter (the items span about 2.6 metres).
	var squeeze := minf(1.0, (minf(room.size.x * 0.55, 4.2) - 0.7) / 2.6)
	for item in on_top:
		var thing: Node3D = item[0]
		thing.position = Vector3(item[1].x * squeeze, top, cz + item[1].z)
		thing.rotation.y = item[2]
		inside.add_child(thing)
	for k in 3:
		var letter := WalkInFurniture.envelope(0.2)
		letter.position = Vector3((1.4 + k * 0.03) * squeeze, top + 0.004 + k * 0.01, cz + 0.1)
		letter.rotation = Vector3(-PI * 0.5, 0.3 * k - 0.2, 0)
		inside.add_child(letter)
	# Notices on the side walls, in a row from the door: one, the window (see POST_WINDOW_FRONT),
	# one more, and the candle behind them (see WalkIn._sconces). The row is squeezed if the room
	# is short, so every notice has its place.
	var notices := [
		["Königliche Post", []],
		["Postdienste", ["Briefe: zu Fuß", "Pakete: per Karren", "Eilpost: per Reiter"]],
		["Postwege", ["Dorf – Mühle", "Dorf – Gilde", "Dorf – Burg"]],
		["Aushang", ["Nur gestempelte", "Pakete werden", "befördert"]],
	]
	var win_z := room.end.y - POST_WINDOW_FRONT
	var slots := [room.end.y - 0.45, win_z - WINDOW_HALF - NOTICE_GAP - 0.35]
	for i in notices.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		if side == WalkIn.ladder_side(0.0) and i < 2:
			continue # The front of that wall is the ladder's.
		var notice := WalkInFurniture.poster(notices[i][0], notices[i][1])
		notice.position = Vector3(side * room.size.x * 0.5, floor_y + 1.8, slots[i / 2])
		notice.rotation.y = -side * PI * 0.5
		inside.add_child(notice)
	var letters := WalkInFurniture.letter_sack()
	letters.position = Vector3(room.size.x * 0.5 - 1.4, floor_y, z - 0.2)
	inside.add_child(letters)


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


## The guildhall: two storeys and a roof to train on, a cellar under it (see GuildHall).
static func _guild(walk_in: WalkIn, rec: Dictionary, inside: Node3D) -> void:
	GuildHall.furnish(walk_in, rec, inside)


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
		# The corner by the ladder up to the bedrooms stays free (see WalkIn._bedroom).
		if side == WalkIn.ladder_side(0.0):
			continue
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
	# The tavern hangs the pub's painted board, Apples & Ivy! (see PubSign); the other halls a shield.
	# The mages' tower hangs the ebony and gilt board of Aldo and Odo (see MageSign).
	var board: Node3D
	if kind == "mage":
		board = MageSign.on_wall(SIGN_OUT, not flat)
	elif kind == "tavern":
		board = PubSign.on_wall(PUB_SIGN_OUT, not flat)
	else:
		board = HangingShield.on_wall(kind, SIGN_OUT, not flat)
	board.name = "HallSign"
	board.position = Vector3(-SIGN_ASIDE if flat else -1.0, VillageHouse.PLINTH + SIGN_HIGH, d * 0.5 + 0.02)
	hall.add_child(board)
	return board
