class_name HouseFurniture
extends RefCounted
## The furniture of a hero's self-built house (see HouseSketch): what they bought from the
## interior furnisher in the village (Raumausstatterin Ilse, see Menus._build_furnisher) and
## where it stands. The same pieces as in the old town houses, working the same way: a bed to
## sleep in, the storage chest, the bookshelf, a fireplace, a trophy stand, the workshop's
## workbench and the three crafting benches of the crafting square.
##
## A piece is bought into the hero's furniture store ("owned", not the bag) and then put down
## in the house with the furnishing tool (see HouseFurnisher). It lies on the house's 2 m grid
## (HouseSketch.CELL), covers `size` cells (across, deep) and is turned in quarter turns: turn 0
## has its back to the north and its front to the south (towards the camera), each turn more
## turns it a quarter clockwise seen from above. It stands only inside the house, on a built
## floor under a built roof (see floor_problem), never across a wall, in front of a door, on
## stairs or on another piece. Picked up again, it goes back into the store. The garden pieces
## (flowers, garden torches and lamps, the grill; "garden" in KINDS) are the other way round: they
## stand only outdoors, on the plot's ground floor where no roof is built (see garden_problem).
##
## Pure data, kept in Storage apart from the saved games like the house plan.

const RECORD := "furniture"

## The kinds, in the order the furnisher shows them: picture, name, what it does, price in copper,
## size in grid cells (across, deep) and the window its station opens (see Game._use_station).
## A shrine names its household goddess ("goddess", see HouseholdGods).
const KINDS := {
	"bett": {"icon": "kind:bedroll", "name": "Bett", "price": 100, "size": Vector2i(2, 2), "station": "bett",
		"text": "Ein großes Bett mit Nachttisch. Schlaf bis zum Morgen oder logg dich aus, wie im Bett deines alten Hauses."},
	"truhe": {"icon": "kind:crate", "name": "Lagertruhe", "price": 50, "size": Vector2i(1, 1), "station": "lager",
		"text": "Öffnet deine Lagertruhe: dieselben Sachen wie in der Truhe deines alten Hauses und am Handwerkerplatz."},
	"regal": {"icon": "kind:book", "name": "Bücherregal", "price": 125, "size": Vector2i(2, 1), "station": Bookshelf.KIND,
		"text": "Stell deine Bücher hinein oder nimm sie heraus. Auf den Brettern steht ein Buch für jedes, das du aufbewahrst."},
	"kamin": {"icon": "kind:flame", "name": "Kamin", "price": 150, "size": Vector2i(1, 1), "station": "",
		"text": "Ein Kamin aus Feldsteinen mit Rauchfang. Das Feuer knistert und wärmt den Raum mit seinem Licht."},
	"trophaeen": {"icon": "kind:shield", "name": "Trophäenständer", "price": 150, "size": Vector2i(1, 1), "station": "trophaeen",
		"text": "Eine Regalwand aus Holz mit kleinen Fächern für die Trophäen mächtiger Gegner. Jede Trophäe darauf gibt +1 Leben, wie die Trophäenwand."},
	"werkbank": {"icon": "kind:hammer", "name": "Werkbank", "price": 125, "size": Vector2i(1, 1), "station": "hauswerkbank",
		"text": "Eisenbarren werden zu Wurfmessern, abgenutzte Ausrüstung wird geflickt, und Handwerk während du weg bist geht schneller."},
	"feinbank": {"icon": "kind:ring", "name": "Werkbank des Feinschmieds", "price": 250, "size": Vector2i(2, 1), "station": "werkbank", "bench": "+",
		"text": "Dieselbe Werkbank wie auf dem Handwerkerplatz: Ringe, Ketten und feiner Draht."},
	"schleifrad": {"icon": "kind:gem", "name": "Schleifrad", "price": 250, "size": Vector2i(2, 1), "station": "werkbank", "bench": "%",
		"text": "Dasselbe Schleifrad wie auf dem Handwerkerplatz: rohe Edelsteine schleifen."},
	"alchemie": {"icon": "kind:potion", "name": "Alchemistentisch", "price": 250, "size": Vector2i(2, 1), "station": "werkbank", "bench": "*",
		"text": "Derselbe Tisch wie auf dem Handwerkerplatz: Tränke und Tinkturen brauen."},
	"leuchter": {"icon": "kind:torch", "name": "Standleuchter", "price": 50, "size": Vector2i(1, 1), "station": "", "light": true,
		"text": "Ein eiserner Leuchter mit drei Kerzen. Er erhellt den Raum, und nachts sieht man dich in seinem Licht."},
	"fackel": {"icon": "kind:torch", "name": "Wandfackel", "price": 25, "size": Vector2i(1, 1), "station": "", "wall": true, "light": true,
		"text": "Eine Fackel in einer Halterung, an eine Wand gehängt. Sie erhellt den Raum, und nachts sieht man dich in ihrem Licht."},
	"bild_berge": {"icon": "kind:map", "name": "Gemälde: Berge", "price": 75, "size": Vector2i(1, 1), "station": "", "wall": true, "painting": 0,
		"text": "Ein gerahmtes Gemälde der Berge im Abendrot, für eine Wand."},
	"bild_see": {"icon": "kind:map", "name": "Gemälde: See", "price": 75, "size": Vector2i(1, 1), "station": "", "wall": true, "painting": 1,
		"text": "Ein gerahmtes Gemälde eines stillen Sees unter dem Mond, für eine Wand."},
	"bild_drache": {"icon": "kind:map", "name": "Gemälde: Drache", "price": 125, "size": Vector2i(1, 1), "station": "", "wall": true, "painting": 2,
		"text": "Ein gerahmtes Gemälde eines Drachen über dem Dorf, für eine Wand."},
	"schrein_maija": {"icon": "kind:goddess", "name": "Schrein der Maija", "price": 400, "size": Vector2i(1, 1), "station": "", "goddess": "maija",
		"text": "Ein kleiner Steinschrein mit der Statue der geflügelten Hausgöttin Maija, der Hüterin der Schlafenden."},
	# The garden: pieces for the open-air part of the plot (see GardenDecor), never under a roof.
	"blumenbeet": {"icon": "kind:flower", "name": "Blumenbeet", "price": 40, "size": Vector2i(1, 1), "station": "", "garden": true,
		"text": "Ein Beet voller Blumen, mit Feldsteinen eingefasst. Es blüht bunt im Sommer, golden im Herbst und ruht im Winter."},
	"blumenkuebel": {"icon": "kind:flower", "name": "Blumenkübel", "price": 30, "size": Vector2i(1, 1), "station": "", "garden": true,
		"text": "Ein Holzkübel mit Eisenreifen und einem Strauß Blumen darin, die mit den Jahreszeiten gehen."},
	"gartenfackel": {"icon": "kind:torch", "name": "Gartenfackel", "price": 30, "size": Vector2i(1, 1), "station": "", "garden": true, "light": true,
		"text": "Eine Fackel auf einem hohen Stab. Sie erhellt den Garten, und nachts sieht man dich in ihrem Licht."},
	"gartenlaterne": {"icon": "kind:flame", "name": "Gartenlaterne", "price": 80, "size": Vector2i(1, 1), "station": "", "garden": true, "light": true,
		"text": "Eine Laterne an einem Pfosten, wie die im Dorf. Ihr ruhiges Licht erhellt den Garten."},
	"grill": {"icon": "kind:sausage", "name": "Grill", "price": 120, "size": Vector2i(1, 1), "station": GardenDecor.GRILL, "garden": true, "light": true,
		"text": "Ein gemauerter Grill mit Eisenrost über glühender Kohle. Dagegenlaufen grillt Wildfleisch oder einen Barsch aus deinem Beutel: Essen gibt Leben zurück."},
}
## The furnisher's categories (see Menus._build_furnisher): title, picture, kinds.
const SECTIONS := [
	["moebel", "Möbel", "kind:house", ["bett", "truhe", "regal", "kamin", "trophaeen"]],
	["werkbaenke", "Werkbänke", "kind:hammer_anvil", ["werkbank", "feinbank", "schleifrad", "alchemie"]],
	["wand", "Licht und Wandschmuck", "kind:torch", ["leuchter", "fackel", "bild_berge", "bild_see", "bild_drache"]],
	["schreine", "Hausschreine", "kind:goddess", ["schrein_maija"]],
	["garten", "Garten", "kind:flower", ["blumenbeet", "blumenkuebel", "gartenfackel", "gartenlaterne", "grill"]],
]
## What the compendium says once the hero has met the furnisher.
const LEARN := "Bei Raumausstatterin Ilse am Dorfplatz kaufst du Möbel für dein selbst gebautes Haus: Bett, Lagertruhe, Bücherregal, Kamin, Trophäenständer, Werkbänke, Leuchter, Wandfackeln und Gemälde. Aufstellen kannst du sie im Bauplan mit \"Einrichten\": Möbel wählen, mit R oder Rechtsklick drehen, mit Linksklick abstellen. Sie stehen nur drinnen, auf gebautem Boden unter einem Dach, und tun dasselbe wie die Möbel deines alten Hauses. Fackeln und Gemälde hängen an einer gebauten Wand. Blumen, Gartenfackeln, Laternen und der Grill gehören in den Garten: auf den Boden deines Grundstücks, wo kein Dach ist."

## The floor a piece stands on, by storey (see HouseSketch: cellar, ground floor, upper floor).
const FLOORS := {-1: -HouseSketch.DEPTH, 0: 0.0, 1: HouseSketch.STOREY_HEIGHT}

static var _books := {}
static var _loaded := false

## kind -> how many the hero has bought and not put down yet.
var owned := {}
## The pieces that stand in the house: {"kind", "storey", "x", "y", "rot"}.
var placed: Array = []


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_books = {}
	var parsed = Storage.read(RECORD)
	if parsed is Dictionary and parsed.get("heroes", {}) is Dictionary:
		_books = parsed.heroes


static func reload() -> void:
	_loaded = false


## The hero's furniture, read from the books (none when they have bought nothing yet).
static func of(hero: String) -> HouseFurniture:
	_load()
	var f := HouseFurniture.new()
	var saved = _books.get(Homes.deed_name(hero), {})
	if not saved is Dictionary:
		return f
	var raw_owned = saved.get("owned", {})
	if raw_owned is Dictionary:
		for kind in raw_owned:
			if KINDS.has(str(kind)) and int(raw_owned[kind]) > 0:
				f.owned[str(kind)] = int(raw_owned[kind])
	var raw_placed = saved.get("placed", [])
	if raw_placed is Array:
		for p in raw_placed:
			if p is Array and p.size() == 5 and KINDS.has(str(p[0])) and FLOORS.has(int(p[1])):
				f.placed.append({"kind": str(p[0]), "storey": int(p[1]), "x": int(p[2]), "y": int(p[3]), "rot": posmod(int(p[4]), 4)})
	return f


func save(hero: String) -> void:
	_load()
	var raw := []
	for p in placed:
		raw.append([p.kind, p.storey, p.x, p.y, p.rot])
	_books[Homes.deed_name(hero)] = {"owned": owned, "placed": raw}
	Storage.write(RECORD, {"heroes": _books})


## How many pieces of a kind are waiting to be put down.
func count(kind: String) -> int:
	return int(owned.get(kind, 0))


## Every piece waiting to be put down.
func waiting() -> int:
	var n := 0
	for kind in owned:
		n += int(owned[kind])
	return n


## How many of a kind stand in the house.
func standing(kind: String) -> int:
	return placed.filter(func(p): return p.kind == kind).size()


func add(kind: String, n := 1) -> void:
	if KINDS.has(kind) and n > 0:
		owned[kind] = count(kind) + n


## The size of a piece on the grid, turned: (cells along x, cells along z).
static func footprint(kind: String, rot: int) -> Vector2i:
	var s: Vector2i = KINDS[kind].size
	return s if rot % 2 == 0 else Vector2i(s.y, s.x)


## The cells a piece covers when its north-west cell is (x, y).
static func cells(kind: String, x: int, y: int, rot: int) -> Array:
	var f := footprint(kind, rot)
	var out := []
	for dy in f.y:
		for dx in f.x:
			out.append(Vector2i(x + dx, y + dy))
	return out


## The turn of a piece as an angle about the up axis (its front is +z at turn 0).
static func angle(rot: int) -> float:
	return posmod(rot, 4) * PI * 0.5


## The middle of a piece on its floor, in the world.
static func centre(house: HouseSketch, kind: String, storey: int, x: int, y: int, rot: int) -> Vector3:
	var f := footprint(kind, rot)
	return house.node_world(x, y) + Vector3(f.x * HouseSketch.CELL * 0.5, FLOORS[storey], f.y * HouseSketch.CELL * 0.5)


## Why a cell of a storey is no floor for furniture, or "": "outside" the plot, "no floor" (nothing
## built to stand on), "no roof" (outdoors: furniture stands only under a built roof), "stairs".
static func floor_problem(house: HouseSketch, storey: int, c: Vector2i) -> String:
	if not house.cell_in_plot(c.x, c.y):
		return "outside"
	match storey:
		HouseSketch.CELLAR_STOREY:
			if not _built(house.pieces.get(HouseSketch.key_of(c.x, c.y, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY), {})):
				return "no floor"
			# The foot of the cellar stairs stays free, so the way down is never blocked.
			if house.stairs_to(c.x, c.y) != "":
				return "stairs"
		0:
			var hole := house.hole_key(c.x, c.y)
			if hole != "" and house.pieces[hole].state != HouseSketch.SKETCH \
					and (house.pieces[hole].kind == HouseSketch.STAIRS or not house.is_covered(c.x, c.y)):
				return "stairs" if house.pieces[hole].kind == HouseSketch.STAIRS else "no floor"
			if house.up_key(c.x, c.y) != "":
				return "stairs"
			if not _built(house.pieces.get(house.roof_key(c.x, c.y, 0), {})):
				return "no roof"
		1:
			var slab := house.slab_at(c.x, c.y, 0)
			if slab.get("kind", "") != HouseSketch.SLAB or not _built(slab):
				return "no floor"
			if _stairs_arrive(house).has(c):
				return "stairs"
			if not _built(house.pieces.get(house.roof_key(c.x, c.y, 1), {})):
				return "no roof"
		_:
			return "no floor"
	return ""


## Whether a kind belongs in the garden (outdoors, never under a roof).
static func in_garden(kind: String) -> bool:
	return bool(KINDS.get(kind, {}).get("garden", false))


## Why a cell of a storey is no ground for a garden piece, or "": "outside" the plot, "garden"
## (only on the ground floor's level), "no floor" (an open cellar hole), "stairs", "roof" (a built
## roof over it: that is indoors).
static func garden_problem(house: HouseSketch, storey: int, c: Vector2i) -> String:
	if not house.cell_in_plot(c.x, c.y):
		return "outside"
	if storey != 0:
		return "garden"
	var hole := house.hole_key(c.x, c.y)
	if hole != "" and house.pieces[hole].state != HouseSketch.SKETCH \
			and (house.pieces[hole].kind == HouseSketch.STAIRS or not house.is_covered(c.x, c.y)):
		return "stairs" if house.pieces[hole].kind == HouseSketch.STAIRS else "no floor"
	if house.up_key(c.x, c.y) != "":
		return "stairs"
	if _built(house.pieces.get(house.roof_key(c.x, c.y, 0), {})):
		return "roof"
	return ""


## The upper floor's cells where stairs up arrive: they stay free.
static func _stairs_arrive(house: HouseSketch) -> Dictionary:
	var out := {}
	for key in house.pieces:
		if house.pieces[key].kind == HouseSketch.UPSTAIRS:
			var p := HouseSketch.parts_of(key)
			out[HouseSketch.stairs_cells(p[1], p[2], p[3])[2]] = true
	return out


static func _built(piece: Dictionary) -> bool:
	return not piece.is_empty() and piece.get("state", HouseSketch.SKETCH) == HouseSketch.BUILT


## Whether a built door of a storey opens onto cell `c`: the cell in front of a door stays free.
static func _by_door(house: HouseSketch, storey: int, c: Vector2i) -> bool:
	for e in [[c.x, c.y, HouseSketch.ORIENT_X], [c.x, c.y + 1, HouseSketch.ORIENT_X], [c.x, c.y, HouseSketch.ORIENT_Y], [c.x + 1, c.y, HouseSketch.ORIENT_Y]]:
		var p := house.piece(e[0], e[1], e[2], storey)
		if p.get("kind", "") == HouseSketch.DOOR and p.get("state", "") != HouseSketch.SKETCH:
			return true
	return false


## Whether a kind hangs on a wall (a torch, a painting) instead of standing on the floor.
static func on_wall(kind: String) -> bool:
	return bool(KINDS.get(kind, {}).get("wall", false))


## The wall edge behind a wall piece on cell `c` turned by `rot`, as [x, y, orient]: at turn 0 it
## faces south, so its back is the cell's north edge.
static func back_edge(c: Vector2i, rot: int) -> Array:
	match posmod(rot, 4):
		1:
			return [c.x, c.y, HouseSketch.ORIENT_Y]
		2:
			return [c.x, c.y + 1, HouseSketch.ORIENT_X]
		3:
			return [c.x + 1, c.y, HouseSketch.ORIENT_Y]
	return [c.x, c.y, HouseSketch.ORIENT_X]


## Whether a plain built wall of a storey stands behind a wall piece.
static func wall_behind(house: HouseSketch, storey: int, c: Vector2i, rot: int) -> bool:
	var e := back_edge(c, rot)
	var p := house.piece(e[0], e[1], e[2], storey)
	return p.get("kind", "") == HouseSketch.WALL and p.get("state", "") != HouseSketch.SKETCH


## The index in `placed` of the piece covering a cell of a storey, or -1: a piece on the floor
## first, else one on a wall of the cell.
func piece_at(house_storey: int, c: Vector2i) -> int:
	var hung := -1
	for i in placed.size():
		var p: Dictionary = placed[i]
		if p.storey == house_storey and cells(p.kind, p.x, p.y, p.rot).has(c):
			if not on_wall(p.kind):
				return i
			if hung < 0:
				hung = i
	return hung


## The index of the floor piece covering a cell, or -1 (wall pieces left out).
func _floor_piece_at(house_storey: int, c: Vector2i) -> int:
	for i in placed.size():
		var p: Dictionary = placed[i]
		if p.storey == house_storey and not on_wall(p.kind) and cells(p.kind, p.x, p.y, p.rot).has(c):
			return i
	return -1


## Why a piece cannot be put down there, or "" when it can (see floor_problem; also "wall",
## "door", "taken" by another piece, "none" left to put down). `skip` is a placed index left out
## of the check (the piece being moved).
func problem(house: HouseSketch, kind: String, storey: int, x: int, y: int, rot: int, skip := -1) -> String:
	if not KINDS.has(kind):
		return "kind"
	var spots := cells(kind, x, y, rot)
	for c: Vector2i in spots:
		var why := garden_problem(house, storey, c) if in_garden(kind) else floor_problem(house, storey, c)
		if why != "":
			return why
	if on_wall(kind):
		# A torch or a painting hangs on a plain wall behind it, one to a wall.
		if not wall_behind(house, storey, Vector2i(x, y), rot):
			return "needs wall"
		for i in placed.size():
			var p: Dictionary = placed[i]
			if i != skip and p.storey == storey and on_wall(p.kind) and back_edge(Vector2i(p.x, p.y), p.rot) == back_edge(Vector2i(x, y), rot):
				return "taken"
		return ""
	# No wall may run through the piece.
	for c: Vector2i in spots:
		for next: Vector2i in [c + Vector2i(1, 0), c + Vector2i(0, 1)]:
			if spots.has(next):
				var e := HouseSketch.edge_between(c, next)
				if HouseSketch.HOUSE_WALLS.has(house.piece(e[0], e[1], e[2], storey).get("kind", "")):
					return "wall"
	for c: Vector2i in spots:
		if _by_door(house, storey, c):
			return "door"
	for c: Vector2i in spots:
		var at := _floor_piece_at(storey, c)
		if at != -1 and at != skip:
			return "taken"
	return ""


## Puts a waiting piece down. Returns "" or why not (see problem).
func place(house: HouseSketch, kind: String, storey: int, x: int, y: int, rot: int) -> String:
	if count(kind) <= 0:
		return "none"
	var why := problem(house, kind, storey, x, y, rot)
	if why != "":
		return why
	owned[kind] = count(kind) - 1
	if owned[kind] <= 0:
		owned.erase(kind)
	placed.append({"kind": kind, "storey": storey, "x": x, "y": y, "rot": posmod(rot, 4)})
	return ""


## Picks a standing piece up again: it goes back into the store. Returns its kind, or "".
func pick_up(index: int) -> String:
	if index < 0 or index >= placed.size():
		return ""
	var kind: String = placed[index].kind
	placed.remove_at(index)
	add(kind)
	return kind


## After the house changed (a wall, floor or roof taken down): every piece that no longer
## fits where it stands goes back into the store. Returns how many did.
func settle(house: HouseSketch) -> int:
	var moved := 0
	for i in range(placed.size() - 1, -1, -1):
		var p: Dictionary = placed[i]
		if problem(house, p.kind, p.storey, p.x, p.y, p.rot, i) != "":
			pick_up(i)
			moved += 1
	return moved


## Whether a trophy stand stands in the house: it shows the trophies like the trophy wall.
func has_trophy_stand() -> bool:
	return standing("trophaeen") > 0


## The home upgrades as the trophies count them: a trophy stand in the self-built house
## counts as the trophy wall (see HomeUpgrades.trophy_hp).
static func upgrades_with_stand(built: Dictionary, hero: String) -> Dictionary:
	if HomeUpgrades.has(built, "trophaeen") or not of(hero).has_trophy_stand():
		return built
	var out := built.duplicate()
	out["trophaeen"] = true
	return out


## The player's words for a problem.
static func reason(why: String) -> String:
	match why:
		"outside":
			return Lang.t("Das liegt außerhalb deines Grundstücks.")
		"no floor":
			return Lang.t("Hier ist kein gebauter Boden.")
		"no roof":
			return Lang.t("Möbel stehen nur drinnen: unter einem gebauten Dach.")
		"stairs":
			return Lang.t("Die Treppe muss frei bleiben.")
		"wall":
			return Lang.t("Da steht eine Wand im Weg.")
		"door":
			return Lang.t("Vor einer Tür muss Platz bleiben.")
		"taken":
			return Lang.t("Da steht schon ein Möbelstück.")
		"garden":
			return Lang.t("Das gehört in den Garten: auf den Boden deines Grundstücks, im Erdgeschoss.")
		"roof":
			return Lang.t("Das gehört in den Garten: unter freien Himmel, nicht unter ein Dach.")
		"needs wall":
			return Lang.t("Das gehört an eine Wand: Zeig auf eine gebaute Wand im Haus.")
		"none":
			return Lang.t("Davon hast du keins mehr zum Aufstellen.")
	return Lang.t("Das geht hier nicht.")
