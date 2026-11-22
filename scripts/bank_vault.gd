class_name BankVault
extends RefCounted
## The bank of the Crown and its vault cellar, a walkable part of the village instead of a level
## of its own (the old "Der Tresorkeller", levels/12_der_tresorkeller.txt, is only used with the
## switch off). Like the forgotten mine (see LostMine), it is a house sketch drawn on the open-air
## map by HouseSketcher, every piece already built: the bank is a stone house with a flat roof
## behind a parapet on the bank's block, and stairs in its floor lead down into the vault cellar, dug under the
## ground round it with whole ground on top. Down there a wide aisle runs between two rows of
## lockers behind iron bars, each locker a room of its own (two cells wide, three deep), bigger
## than the old cellar's: every hero who rents one has a locker, with a name plate, their coins
## and their treasures to see through the bars (see refresh), and the hero's own opens when they
## run into its bars (the "tresor" station, see Menus._build_vault).
##
## The layout is LAYOUT, one letter per 2 m cell of the plot (PLOT, in map tiles):
##   " "  solid earth
##   "."  the stone hall at the foot of the stairs and the aisle
##   "U"  a locker (SLOTS gives the front-left cell of each, in the order they are rented)
##
## The switch: `on` below. Turned off (false), the bank is the old kit tower again and the vault
## the level of its own, reached through the banker's window.

## Whether the bank and its vault are walked into on the map (see the class notes).
static var on := true

## The plot the bank and the vault are drawn on (map tiles): the bank's block and the ground
## south and west of it, under the street and the pumpkin field.
const PLOT := Rect2i(46, 36, 16, 7)
## One string per row of cells, one letter per cell (see the class notes).
const LAYOUT := [
	"                                ",
	"                                ",
	"                                ",
	"                                ",
	"                                ",
	" UU UU UU UU UU      .  UU UU UU",
	" UU UU UU UU UU  ...... UU UU UU",
	" UU UU UU UU UU  ...... UU UU UU",
	" ...............................",
	" ...............................",
	" UU UU UU UU UU UU UU UU        ",
	" UU UU UU UU UU UU UU UU        ",
	" UU UU UU UU UU UU UU UU        ",
	"                                ",
]
## The bank house (cells of the plot), on the map's bank block: its floor, walls and roof.
const BANK := Rect2i(18, 2, 4, 4)
## The stairs down: their top cell in the bank's floor, and the way they go down (the cell at
## their foot, two cells on, is the first of the hall below).
const STAIRS_TOP := Vector2i(21, 3)
const STAIRS_DIR := "s"
## The lockers: the front-left cell of each (fronts on the aisle), in the order they are rented.
const SLOTS := [Vector2i(1, 5), Vector2i(4, 5), Vector2i(7, 5), Vector2i(10, 5), Vector2i(13, 5),
	Vector2i(24, 5), Vector2i(27, 5), Vector2i(30, 5),
	Vector2i(1, 10), Vector2i(4, 10), Vector2i(7, 10), Vector2i(10, 10), Vector2i(13, 10), Vector2i(16, 10),
	Vector2i(19, 10), Vector2i(22, 10)]
## A locker is this many cells wide and deep.
const LOCKER := Vector2i(2, 3)
## Where the lamps hang (cells).
const LAMPS := [Vector2i(19, 6), Vector2i(4, 8), Vector2i(10, 9), Vector2i(16, 8), Vector2i(23, 9), Vector2i(29, 8)]
const LAMP_COLOUR := Color(1.0, 0.78, 0.48)
const IRON := Color(0.2, 0.2, 0.22)
## How high a locker's name plate hangs over the floor.
const PLATE_HIGH := 2.0
## From how far (metres, to the middle of its bars) the hero runs into their own locker.
const TOUCH := 1.6
## The station of the hero's own locker (see Menus).
const KIND := "tresor"

static var _sketch: HouseSketch = null
static var _cells := {}
static var _inside := {}
static var _mats := {}
## The level and the node the lockers' contents are shown under (see refresh).
static var _shows: Node3D = null


## Every dug cell of the vault: Vector2i (plot cells) -> its LAYOUT letter.
static func cells() -> Dictionary:
	if _cells.is_empty():
		for y in LAYOUT.size():
			var row: String = LAYOUT[y]
			for x in row.length():
				if row[x] != " ":
					_cells[Vector2i(x, y)] = row[x]
	return _cells


## The bank and its vault as a house sketch, every piece built: the dug cells of stone under
## whole ground, the stairs, and the bank on top with its floor, walls, door, windows and roof.
static func sketch() -> HouseSketch:
	if _sketch != null:
		return _sketch
	var s := HouseSketch.new()
	s.plot = PLOT
	var built := HouseSketch.BUILT
	var stairs := HouseSketch.stairs_cells(STAIRS_TOP.x, STAIRS_TOP.y, STAIRS_DIR)
	for c: Vector2i in cells():
		s.pieces[HouseSketch.key_of(c.x, c.y, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.DIG, "state": built, "floor": "stone", "wall": "stone"}
		if not BANK.has_point(c):
			s.pieces[HouseSketch.key_of(c.x, c.y, HouseSketch.COVER_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.COVER, "state": built, "surface": HouseSketch.BURIED}
	s.pieces[HouseSketch.key_of(STAIRS_TOP.x, STAIRS_TOP.y, STAIRS_DIR, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.STAIRS, "state": built}
	# The bank: a stone floor over its cells (none over the stairs: the way down stays open), walls
	# of stone blocks under a flat roof with a stone parapet, the door to the north towards the banker.
	for y in range(BANK.position.y, BANK.end.y):
		for x in range(BANK.position.x, BANK.end.x):
			if not stairs.has(Vector2i(x, y)):
				s.pieces[HouseSketch.key_of(x, y, HouseSketch.COVER_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.COVER, "state": built, "surface": "stone"}
			s.pieces[HouseSketch.key_of(x, y, HouseSketch.CELL_ORIENT, 0)] = {"kind": HouseSketch.SLAB, "state": built}
	for x in range(BANK.position.x, BANK.end.x):
		for storey in [0, HouseSketch.RAIL_STOREY]:
			var kind := HouseSketch.WALL if storey == 0 else HouseSketch.STONE_FENCE
			s.pieces[HouseSketch.key_of(x, BANK.position.y, HouseSketch.ORIENT_X, storey)] = {"kind": kind, "state": built}
			s.pieces[HouseSketch.key_of(x, BANK.end.y, HouseSketch.ORIENT_X, storey)] = {"kind": kind, "state": built}
	for y in range(BANK.position.y, BANK.end.y):
		for storey in [0, HouseSketch.RAIL_STOREY]:
			var kind := HouseSketch.WALL if storey == 0 else HouseSketch.STONE_FENCE
			s.pieces[HouseSketch.key_of(BANK.position.x, y, HouseSketch.ORIENT_Y, storey)] = {"kind": kind, "state": built}
			s.pieces[HouseSketch.key_of(BANK.end.x, y, HouseSketch.ORIENT_Y, storey)] = {"kind": kind, "state": built}
	s.pieces[HouseSketch.key_of(door_cell().x, BANK.position.y, HouseSketch.ORIENT_X)].kind = HouseSketch.DOOR
	for at: Array in [[BANK.position.x, BANK.position.y, HouseSketch.ORIENT_X], [BANK.end.x - 1, BANK.position.y, HouseSketch.ORIENT_X],
			[BANK.position.x + 1, BANK.end.y, HouseSketch.ORIENT_X], [BANK.end.x - 2, BANK.end.y, HouseSketch.ORIENT_X],
			[BANK.position.x, BANK.position.y + 1, HouseSketch.ORIENT_Y], [BANK.end.x, BANK.position.y + 1, HouseSketch.ORIENT_Y]]:
		s.pieces[HouseSketch.key_of(at[0], at[1], at[2])].kind = HouseSketch.WINDOW
	s.floors_area = BANK
	_sketch = s
	return s


## The cell of the bank's door, in its north wall.
static func door_cell() -> Vector2i:
	return Vector2i(BANK.position.x + BANK.size.x / 2, BANK.position.y)


## The cells inside the bank's walls (see HouseGround.inside_cells), worked out once.
static func bank_inside() -> Dictionary:
	if _inside.is_empty():
		_inside = HouseGround.inside_cells(sketch())
	return _inside


## Whether map tile `c` lies over the vault or the bank: no plot may be marked out there (see Plots.problem).
static func covers_tile(c: Vector2i) -> bool:
	if not on or not PLOT.has_point(c):
		return false
	var first := (c - PLOT.position) * HouseSketch.CELLS_PER_TILE
	for dy in HouseSketch.CELLS_PER_TILE:
		for dx in HouseSketch.CELLS_PER_TILE:
			var cell := first + Vector2i(dx, dy)
			if cells().has(cell) or BANK.has_point(cell):
				return true
	return false


## The map tiles the bank stands on (they let sight and reach through: its walls stop them).
static func bank_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(BANK.position.y, BANK.end.y, HouseSketch.CELLS_PER_TILE):
		for x in range(BANK.position.x, BANK.end.x, HouseSketch.CELLS_PER_TILE):
			out.append(PLOT.position + Vector2i(x, y) / HouseSketch.CELLS_PER_TILE)
	return out


## The vault's cell under a world point (plot cells), whether or not it is dug.
static func cell_at(pos: Vector3) -> Vector2i:
	var origin := sketch().node_world(0, 0)
	return Vector2i(floori((pos.x - origin.x) / HouseSketch.CELL), floori((pos.z - origin.z) / HouseSketch.CELL))


## Whether a world point lies down in the vault (below the ground, within its cells).
static func holds(pos: Vector3) -> bool:
	return on and pos.y < -1.0 and cells().has(cell_at(pos))


## The middle of a cell's floor, down in the vault.
static func floor_at(c: Vector2i) -> Vector3:
	return sketch().cell_world(c.x, c.y) + Vector3(0, -HouseSketch.DEPTH, 0)


## The middle of a locker's floor.
static func locker_middle(slot: Vector2i) -> Vector3:
	var a := floor_at(slot)
	var b := floor_at(slot + LOCKER - Vector2i.ONE)
	return (a + b) * 0.5


## The middle of a locker's bars, on the line between it and the aisle (on the floor).
static func bars_middle(slot: Vector2i) -> Vector3:
	var mid := locker_middle(slot)
	var north := slot.y < 8
	var z := sketch().node_world(0, slot.y + LOCKER.y if north else slot.y).z
	return Vector3(mid.x, mid.y, z)


## Whether a locker's bars face north (the south row) or south (the north row), as the way out of it.
static func out_of(slot: Vector2i) -> Vector3:
	return Vector3(0, 0, 1) if slot.y < 8 else Vector3(0, 0, -1)


# --- What stands down there ---------------------------------------------------

## Builds everything in the vault that is no part of the sketch, under `parent` (shown only while
## the hero is down in a cellar): the bars before every locker, the lamps, and the lockers' contents
## (see refresh). The bars stop everyone.
static func build(level: Level, parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "VaultSolids"
	parent.add_child(body)
	var iron := _mat("iron", IRON, 0.6)
	for slot: Vector2i in SLOTS:
		_bars(parent, body, slot, iron)
	for c: Vector2i in LAMPS:
		_lamp(parent, c)
	_shows = Node3D.new()
	_shows.name = "VaultShows"
	parent.add_child(_shows)
	refresh(level)


## Iron bars across a locker's front, from wall to wall, floor to ceiling.
static func _bars(parent: Node3D, body: StaticBody3D, slot: Vector2i, iron: Material) -> void:
	var at := bars_middle(slot)
	var wide := LOCKER.x * HouseSketch.CELL
	var high := HouseSketch.DEPTH - HouseSketch.COVER_THICK
	var n := int(wide / 0.22)
	for i in n + 1:
		var x := -wide * 0.5 + i * wide / n
		_box(parent, at + Vector3(x, high * 0.5, 0), Vector3(0.05, high, 0.05), iron)
	for y: float in [0.12, high * 0.5, high - 0.12]:
		_box(parent, at + Vector3(0, y, 0), Vector3(wide, 0.07, 0.07), iron)
	_solid(body, at + Vector3(0, high * 0.5, 0), Vector3(wide, high, 0.2))


## A lamp hanging from the vault's ceiling: an iron cage round a warm glow.
static func _lamp(parent: Node3D, c: Vector2i) -> void:
	var at := floor_at(c) + Vector3(0, 2.05, 0)
	var iron := _mat("iron", IRON, 0.6)
	_box(parent, at + Vector3(0, 0.22, 0), Vector3(0.03, 0.2, 0.03), iron)
	_box(parent, at, Vector3(0.22, 0.26, 0.22), _mat("lamp_glass", LAMP_COLOUR, 0.0, 2.5))
	_box(parent, at + Vector3(0, 0.15, 0), Vector3(0.3, 0.05, 0.3), iron)
	_box(parent, at - Vector3(0, 0.15, 0), Vector3(0.3, 0.05, 0.3), iron)
	var light := OmniLight3D.new()
	light.light_color = LAMP_COLOUR
	light.light_energy = 2.4
	light.omni_range = 9.0
	light.position = at - Vector3(0, 0.1, 0)
	parent.add_child(light)


## Fills the lockers: one for every hero who rented one, in the order they rented, each with a
## name plate, their coins and their treasures; the hero's own opens when they run into its bars
## (a "tresor" station). Called again whenever something is put in or taken out (see Menus).
static func refresh(level: Level) -> void:
	if _shows == null or not is_instance_valid(_shows):
		return
	for child in _shows.get_children():
		child.queue_free()
	level.stations = level.stations.filter(func(s): return s.kind != KIND)
	var holders := Bank.vault_holders()
	var hero: String = level.hero
	for i in SLOTS.size():
		var slot: Vector2i = SLOTS[i]
		var owner: String = holders[i] if i < holders.size() else ""
		var show := Node3D.new()
		show.position = locker_middle(slot)
		_shows.add_child(show)
		var bars := bars_middle(slot)
		var plate := Label3D.new()
		plate.text = owner if owner != "" else Lang.t("Zu vermieten")
		plate.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
		plate.font_size = 48
		plate.pixel_size = 0.009
		plate.outline_size = 10
		plate.modulate = Color(1.0, 0.82, 0.4) if owner == hero and owner != "" else Color(0.85, 0.85, 0.9)
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.position = bars - show.position + Vector3(0, PLATE_HIGH, 0)
		show.add_child(plate)
		if owner == "":
			continue
		var gold := Bank.gold(owner)
		if gold > 0:
			# The same hoard as at home, but of the coins in this vault only (copper, as the bank keeps it).
			var heap_root := Node3D.new()
			heap_root.name = "VaultHoard"
			heap_root.position = Vector3(1.0, 0, -out_of(slot).z * 1.4)
			heap_root.scale = Vector3.ONE * 0.7
			show.add_child(heap_root)
			level._lay_heaps(heap_root, HomeHoard.mix(HomeHoard.stage_of(HomeHoard.wealth(gold, 0, 0)), {"kupfermuenze": gold}))
		var items := Bank.vault_items(owner)
		for k in items.size():
			if not Items.ALL.has(items[k]):
				continue
			var thing := level._item_model(items[k])
			thing.position = Vector3(-1.2 + (k % 3) * 1.2, 0.8, -out_of(slot).z * (-1.6 + (k / 3) * 1.1))
			thing.rotation.y = k * 0.7
			show.add_child(thing)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.85, 0.55)
		glow.light_energy = 1.2
		glow.omni_range = 4.0
		glow.position = Vector3(0, 2.0, 0)
		show.add_child(glow)
		if owner == hero:
			var at := bars + out_of(slot) * 0.6
			level.stations.append({"kind": KIND, "cell": level.world_to_cell(at), "pos": at, "used": false, "touch": TOUCH})


static func _mat(key: String, colour: Color, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 0.9 if metal == 0.0 else 0.45
		m.metallic = metal
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = colour
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


static func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


static func _solid(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
