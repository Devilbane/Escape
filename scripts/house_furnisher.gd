class_name HouseFurnisher
extends Node3D
## The furniture in the self-built houses on the open map (see HouseFurniture), and the
## furnishing tool the hero uses to put their own pieces down.
##
## Everyone's furniture stands in their houses for all to see; only the hero's own pieces are
## stations (bed, storage chest, bookshelf, trophy stand, weapon rack, workbenches), and they open the very
## windows of their counterparts in the old town house. The pieces are the same models too:
## the decorated bed, the iron-bound chest, the oak bookshelf (see Bookshelf), the stone
## fireplace with its chimney breast (see HomeFireplace), the workshop's table and the benches
## of the crafting square (see CraftingSquare).
##
## The tool opens from the blueprint tool's "Einrichten" button (the HUD's blueprint button opens that). It frames the
## plot like the blueprint tool, shows one storey at a time (the storeys above it fade away) and
## has a bar at the bottom with fixed sizes: one button per kind of furniture with the number
## waiting to be put down, the storey, turning, picking up, back to the blueprint and close. A
## ghost of the chosen piece follows the mouse on the storey's floor, green where it fits and red
## where it does not (the line below says why). Left click puts it down, R or right click turns
## it a quarter, and "Entfernen" (or the Delete key over a piece) takes a piece back into the store
## and stays chosen, so several can go in a row; to move a piece, drag it.

## The short names on the tool bar's buttons, in the order of HouseFurniture.KINDS.
const SHORT := {"bett": "Bett", "truhe": "Truhe", "kiste": "Kisten", "fass": "Fass", "eichentruhe": "Eichentruhe", "regal": "Regal", "kamin": "Kamin", "trophaeen": "Trophäen", WeaponRack.KIND: "Waffenständer",
	"werkbank": "Werkbank", "feinbank": "Feinbank", "schleifrad": "Schleifstein", "alchemie": "Alchemie",
	"hort": "Hort", "leuchter": "Leuchter", "fackel": "Wandfackel", "bild_berge": "Bild: Berge", "bild_see": "Bild: See", "bild_drache": "Bild: Drache",
	"schrein_maija": "Schrein: Maija",
	"blumenbeet": "Blumenbeet", "blumenkuebel": "Kübel", "gartenfackel": "Stabfackel", "gartenlaterne": "Laterne", "grill": "Grill", AppleTree.KIND: "Apfelbaum"}
## The tool bar's second row: the weapon rack, light, the walls and the shrines; the garden has the third. Everything
## else is on the first.
const SECOND_ROW := [WeaponRack.KIND, "hort", "leuchter", "fackel", "bild_berge", "bild_see", "bild_drache", "schrein_maija"]
## The light of a candle stand and a torch: the dungeon's wall torch, a little softer indoors.
const LIGHT_ENERGY := 1.55
const LIGHT_RANGE := 9.0
const LAMP_ATTENUATION := 1.3
## How far over the ground a light on a flat roof stops reaching (see roof_reach).
const ROOF_CLEARANCE := 0.4
## How far the back of the mounted torch's plate lies behind its origin.
const TORCH_BACK := 0.025
## A painting's frame (across, high) and how high its middle hangs (metres).
const PAINTING := Vector2(1.3, 1.0)
const PAINTING_HEIGHT := 1.55
## The painted pictures, by motif (see _painting_texture).
const PAINTINGS := ["res://assets/house/painting_mountains.jpg", "res://assets/house/painting_lake.jpg",
	"res://assets/house/painting_dragon.jpg"]
const PICK_UP := "aufheben"
## The kind of the hoard (see HouseFurniture.KINDS).
const HOARD := "hort"
const LEVEL_NAMES := {-1: "im Keller", 0: "im Erdgeschoss", 1: "im Obergeschoss", HouseFurniture.ROOF_STOREY: "auf dem Dach"}
const KIND_BUTTON := Vector2(130, 32)
const STATUS_WIDTH := 880.0
const OK_COLOR := Color(0.4, 0.95, 0.4, 0.45)
const BAD_COLOR := Color(1.0, 0.4, 0.35, 0.45)
const ON_COLOR := Color(1.0, 0.82, 0.4)
## How close the hero must come to a piece to use it, from its middle (metres).
const TOUCH := {"truhe": 1.4, "kiste": 1.4, "fass": 1.4, "eichentruhe": 1.4, "bett": 2.6, "regal": 2.4, WeaponRack.KIND: 2.4, "feinbank": 2.4, "schleifrad": 2.4, "alchemie": 2.4, "hort": 2.8}
const TOUCH_DEFAULT := 1.8
## How far outside its solid a bump still counts as running into a piece (metres).
const TOUCH_MARGIN := 0.4
## How tall a standing piece is to the mouse (see aim_point): the camera looks down at a slant,
## so the top of a chest is drawn over the floor of the cell behind it.
const PICK_HEIGHT := {"bett": 1.5, "regal": 2.4, "trophaeen": 2.5, WeaponRack.KIND: 2.2, "leuchter": 1.6, "kamin": 1.6, "schrein_maija": 1.6}
const PICK_HEIGHT_DEFAULT := 1.2
## The part of a wall a torch covers, to the mouse: how wide, from how high to how high (metres).
## A painting covers its frame (PAINTING, PAINTING_HEIGHT).
const PICK_TORCH := Vector3(0.6, 1.1, 2.3)
## How far out from the wall a torch or a painting is found by the mouse.
const PICK_WALL_DEPTH := 0.5
## The scale of the pieces that are too big or too tall for a 2 m cell and a 2.6 m storey.
const SHELF_SCALE := 0.75
const FIRE_SCALE := 0.72
const TABLE_SCALE := 0.8
## The trophy stand's shelf wall (metres): its width and depth, the boards' thickness, the kick
## board below the bottom shelf, and the height of each row of cubbies.
const STAND_WIDTH := 1.8
const STAND_DEPTH := 0.5
const STAND_BOARD := 0.05
const STAND_BOTTOM := 0.08
const STAND_ROW := 0.82
const STAND_COLS := 3
const STAND_ROWS := 3
## The trophies' size on the stand, against Level.TROPHY_STATUE (half again the old stand's 0.55).
const TROPHY_SCALE := 0.825
## The season the garden's flowers were last drawn in (see GardenDecor.stage), -1 before.
var _garden_stage := -1
## The season day the garden was last drawn on, and whether an apple tree stands in any garden:
## the trees grow and ripen by the day (see AppleTree), so they are drawn again when it turns.
var _garden_day := -1
var _has_trees := false
## Where the hero lies down in the bed, from its middle (see Game._climb_into_bed), and gets up.
const BED_OFFSET := Vector3(-0.55, 0, -0.44)

var game: Node
var active := false
## The kind chosen to put down, or PICK_UP.
var tool := ""
var rot := 0
var storey := 0
## The hero's furniture, and their house plan (the blueprint tool's).
var furniture: HouseFurniture
var _pieces := Node3D.new()
var _body := StaticBody3D.new()
var _ghost := Node3D.new()
var _ghost_key := ""
var _stations: Array = []
## The bookshelves, trophy stands and weapon racks of the hero's house, to show books, trophies
## and weapons.
var _shelves: Array = []
var _stands: Array = []
var _racks: Array = []
## The hoards of the hero's house: the holder of each one's coin heaps (see refresh_hoards).
var _hoards: Array = []
var _bar: PanelContainer
var _kind_buttons := {}
var _level_button: Button
var _turn_button: Button
var _pick_button: Button
var _status: Label
var _hint := ""
var _frame_pending := false
var _hover_cell := Vector2i(-1, -1)
## A placed piece held with the left mouse button and moved to another spot (see grab and drop):
## where it stood, the tool chosen before, and where on the screen it was grabbed.
var _held := {}
var _held_tool := ""
var _held_from := Vector2.ZERO
## The floor point under the mouse, for R over a placed piece (null when there is none).
var _mouse_point = null
## How far the mouse must move (pixels) before holding a piece counts as dragging, not a click.
const DRAG_START := 8.0


func _ready() -> void:
	add_child(_pieces)
	add_child(_body)
	add_child(_ghost)
	_build_bar()
	refresh()


func _exit_tree() -> void:
	if active and game != null:
		game.frame_pull = 0.0
	if is_instance_valid(_bar):
		_bar.queue_free()


func _process(_delta: float) -> void:
	_fade()
	# The flowers in the gardens follow the seasons.
	if game != null and game.level is Outdoor and (_garden_stage != GardenDecor.stage(game.level.season_day) \
			or (_has_trees and _garden_day != game.level.season_day)):
		refresh()
	if not active:
		return
	if _frame_pending and game.house_sketcher != null:
		_frame_pending = false
		game.house_sketcher.solve_frame(_bar)
	# The button let go anywhere (over the bar too, which keeps the release from the game).
	if dragging() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var at := game.get_viewport().get_mouse_position()
		drop(floor_point(at) if not game.menus.is_open() else null, at)
	if game.state == game.State.PLAYING and not game.menus.is_open():
		var spot = aim_point(game.get_viewport().get_mouse_position())
		if spot != null:
			hover(spot)


## The hero's house plan, or null without a plot.
func plan() -> HouseSketch:
	return game.house_sketcher.plan if game != null and game.house_sketcher != null else null


# --- Drawing --------------------------------------------------------------------

## Draws everyone's furniture again (after a purchase, a piece put down or picked up, or a
## change of the house: pieces that no longer fit go back into the store).
func refresh() -> void:
	if game == null or not game.level is Outdoor:
		return
	for s in _stations:
		game.level.stations.erase(s)
	_stations.clear()
	_shelves.clear()
	_stands.clear()
	_racks.clear()
	_hoards.clear()
	for child in _pieces.get_children():
		_pieces.remove_child(child)
		child.queue_free()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	furniture = HouseFurniture.of(game.hero_name)
	_garden_stage = GardenDecor.stage(game.level.season_day)
	_garden_day = game.level.season_day
	_has_trees = false
	var own := plan()
	if own != null:
		var moved := furniture.settle(own)
		if moved > 0:
			furniture.save(game.hero_name)
			Events.tell(Lang.t("Dein Haus hat sich verändert: %d Möbelstücke stehen wieder zum Aufstellen bereit.") % moved, ON_COLOR)
	var mine := Plots.plot_of(game.hero_name)
	for deed in Plots.all():
		var is_mine: bool = own != null and deed.rect == mine
		var house: HouseSketch = own if is_mine else HouseSketch.of(deed.owner, deed.rect)
		var theirs := furniture if is_mine else HouseFurniture.of(deed.owner)
		for i in theirs.placed.size():
			var p: Dictionary = theirs.placed[i]
			if not is_mine and theirs.problem(house, p.kind, p.storey, p.x, p.y, p.rot, i) != "":
				continue
			_draw_piece(house, p, is_mine)
	refresh_books()
	# Where a fire or a lamp burns in a house, the hero is seen at night (see Outdoor.is_lit).
	_note_lights()
	_fade(true)
	if active:
		_update_bar()


## Tells the level where a light burns in a house (a candle stand put out gives none).
func _note_lights() -> void:
	var lit: Array[Vector3] = []
	for light: Node3D in _pieces.find_children("*", "OmniLight3D", true, false):
		if light.visible:
			lit.append(light.global_position if light.is_inside_tree() else light.position)
	game.level.house_lights = lit


## The hero clicks their candle stand: its candles go out or are lit again, flames and light
## together, and the piece keeps it in the books (see CandleStand).
func toggle_candles(station: Dictionary) -> void:
	var at: Dictionary = station.get("piece", {})
	for p in furniture.placed:
		if p.kind == HouseFurniture.CANDLE_KIND and p.storey == at.get("storey") and p.x == at.get("x") and p.y == at.get("y"):
			var on: bool = p.has(CandleStand.OUT)
			if on:
				p.erase(CandleStand.OUT)
			else:
				p[CandleStand.OUT] = 1
			furniture.save(game.hero_name)
			var stand = station.get("stand")
			if stand is Node3D and is_instance_valid(stand):
				CandleStand.set_lit(stand, on)
			_note_lights()
			Sfx.play(game, "swing", -6.0, station.pos)
			game.show_message(Lang.t("Du zündest die Kerzen an.") if on else Lang.t("Du löschst die Kerzen."), 1.6)
			return


## One piece, solid, and (in the hero's own house) a station.
func _draw_piece(house: HouseSketch, p: Dictionary, is_mine: bool) -> void:
	var at := HouseFurniture.centre(house, p.kind, p.storey, p.x, p.y, p.rot)
	var root := Node3D.new()
	root.position = at
	root.rotation.y = HouseFurniture.angle(p.rot)
	root.set_meta("storey", p.storey)
	if indoors(p.kind):
		root.set_meta("no_snow", true)
	_pieces.add_child(root)
	var station := build_piece(root, p.kind, p)
	if p.kind == AppleTree.KIND:
		_has_trees = true
	for box in root.get_meta("solids", []):
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = box.size
		shape.shape = b
		shape.transform = root.transform * Transform3D(Basis.IDENTITY, box.at + Vector3(0, box.size.y * 0.5, 0))
		_body.add_child(shape)
	if not is_mine:
		return
	if p.kind == "regal":
		_shelves.append(root.get_meta("shelf"))
	elif p.kind == "trophaeen":
		_stands.append(root.get_meta("stand"))
	elif p.kind == WeaponRack.KIND:
		_racks.append(root.get_meta("rack"))
	elif p.kind == HOARD:
		_hoards.append(root.get_meta("hoard"))
	if station.is_empty():
		return
	station.pos = root.transform * station.get("pos", Vector3.ZERO)
	station.cell = game.level.world_to_cell(station.pos)
	station.used = false
	station.touch = TOUCH.get(p.kind, TOUCH_DEFAULT)
	# Only running into the piece itself uses it: not a candle stand or a chest that stands
	# within its touch beside it (see Level.station_at).
	var rects: Array[Rect2] = []
	for box in root.get_meta("solids", []):
		var aabb: AABB = root.transform * AABB(box.at - Vector3(box.size.x, 0, box.size.z) * 0.5, box.size)
		rects.append(Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z).grow(TOUCH_MARGIN))
	if not rects.is_empty():
		station.touch_rects = rects
	station.furniture = p.kind
	if station.has("side"):
		station.side = root.transform * station.side
	if station.has("spot"):
		station.spot = root.transform * station.spot
	if station.has("rot"):
		station.rot = root.rotation.y
	game.level.stations.append(station)
	_stations.append(station)


## Whether a piece of `kind` is furniture for the rooms (a bed, a shrine, a shelf ...), which never
## takes snow (see SnowCover.bare), even where the snow mask's coarse cells reach in past the walls;
## the garden's things (and the apple trees) stand outside and take it like the rest.
static func indoors(kind: String) -> bool:
	return kind != AppleTree.KIND and not HouseFurniture.KINDS.get(kind, {}).get("garden", false)


## Builds the model of a piece of `kind` into `root` (its front towards +z, its middle at the
## origin, on the floor). Notes its solids in the meta "solids" ({at, size}, local) and returns
## its station without a position in the world yet ({} for a piece without one). `piece` is the
## placed piece (an apple tree grows by its age, see AppleTree); {} draws a new one.
func build_piece(root: Node3D, kind: String, piece := {}) -> Dictionary:
	var level: Level = game.level
	var info: Dictionary = HouseFurniture.KINDS[kind]
	var solids := []
	var station := {}
	if info.station != "":
		station = {"kind": info.station, "pos": Vector3.ZERO}
	match kind:
		"bett":
			CosyBed.build(root, BED_OFFSET, 0.0)
			solids.append({"at": Vector3(0, 0, -0.47), "size": Vector3(2.6, 1.5, 3.0)})
			# The bed's own middle (where the hero lies, see Game._climb_into_bed), and beside its foot.
			station.pos = BED_OFFSET
			station.rot = 0.0
			station.side = Vector3(0, 0, 1.6)
			station.spot = Level.pillow_spot(BED_OFFSET, 0.0)
		"truhe":
			FittedChest.place(root, "brass", Vector3(0, 0, -0.35))
			# As big as the chest itself (see FittedChest), so the way between it and a bed stays free.
			solids.append({"at": Vector3(0, 0, -0.35), "size": Vector3(FittedChest.WIDTH, 1.2, FittedChest.DEPTH)})
		"kiste":
			level._place("crates_stacked", Vector3(0, 0, -0.1), 0.0, root)
			solids.append({"at": Vector3(0, 0, -0.1), "size": Vector3(1.3, 1.2, 1.3)})
		"fass":
			level._place("barrel_large", Vector3(0, 0, -0.1), 0.0, root)
			solids.append({"at": Vector3(0, 0, -0.1), "size": Vector3(1.0, 1.2, 1.0)})
		"eichentruhe":
			FittedChest.place(root, "oak", Vector3(0, 0, -0.35))
			solids.append({"at": Vector3(0, 0, -0.35), "size": Vector3(FittedChest.WIDTH, 1.2, FittedChest.DEPTH)})
		"regal":
			var shelf := Bookshelf.build_shelf(root, Vector3(0, 0, -HouseSketch.CELL * 0.5 + (Level.TILE * 0.5 - 0.1) * SHELF_SCALE), 0.0)
			shelf.scale = Vector3.ONE * SHELF_SCALE
			root.set_meta("shelf", shelf)
			solids.append({"at": Vector3(0, 0, -0.6), "size": Vector3(Bookshelf.WIDTH * SHELF_SCALE, 2.4, 0.75)})
		"kamin":
			var fire := HomeFireplace.build_into(root, {"pos": Vector3(0, 0, -HouseSketch.CELL * 0.5), "rot": 0.0})
			fire.scale = Vector3.ONE * FIRE_SCALE
			for glow: Light3D in fire.find_children("*", "Light3D", true, false):
				glow.set_meta(LightShadows.INDOOR, true)
			solids.append({"at": Vector3(0, 0, -HouseSketch.CELL * 0.5 + HomeFireplace.DEPTH * FIRE_SCALE * 0.5),
					"size": Vector3(HomeFireplace.WIDTH * FIRE_SCALE, 1.6, HomeFireplace.DEPTH * FIRE_SCALE)})
		"trophaeen":
			root.set_meta("stand", _build_stand(root))
			solids.append({"at": Vector3(0, 0, -HouseSketch.CELL * 0.5 + 0.1 + STAND_DEPTH * 0.5),
					"size": Vector3(STAND_WIDTH, STAND_BOTTOM + STAND_ROWS * STAND_ROW, STAND_DEPTH + 0.05)})
		WeaponRack.KIND:
			var rack := WeaponRack.build_rack(root, Vector3(0, 0, -HouseSketch.CELL * 0.5 + HouseSketcher.THICK * 0.5 + 0.02), 0.0)
			root.set_meta("rack", rack)
			solids.append({"at": Vector3(0, 0, -HouseSketch.CELL * 0.5 + HouseSketcher.THICK * 0.5 + WeaponRack.DEPTH * 0.5 + 0.05),
					"size": Vector3(WeaponRack.WIDTH, WeaponRack.HEIGHT, WeaponRack.DEPTH + 0.15)})
		"werkbank":
			var table := level._place("table_medium_decorated_A", Vector3(0, 0, -0.2), 0.0, root)
			table.scale = Vector3.ONE * TABLE_SCALE
			var stool := level._place("stool", Vector3(0, 0, 0.75), PI, root)
			stool.scale = Vector3.ONE * TABLE_SCALE
			solids.append({"at": Vector3(0, 0, -0.2), "size": Vector3(1.6, 1.2, 1.6)})
			station.spot = Vector3(0, Level.TABLE_TOP * TABLE_SCALE, -0.2)
		"feinbank", "schleifrad", "alchemie":
			# The bench of the crafting square faces east; turned so its front is the piece's front.
			var turn := Node3D.new()
			turn.rotation.y = -PI * 0.5
			turn.position = Vector3(0, 0, 0.5)
			root.add_child(turn)
			CraftingSquare.build_bench(turn, Vector3.ZERO, info.bench, hash("home bench:" + kind))
			solids.append({"at": Vector3(0, 0, 0), "size": Vector3(3.0, 1.2, 2.0)})
			station.craft = CraftingSquare.BENCHES[info.bench].craft
			# The bench top's middle, turned with the bench like its model.
			station.spot = turn.transform * CraftingSquare.TOP
		HOARD:
			# The very hoard of the town house (see Level._build_coin_hoard): a low plinth with the
			# heaps of the hero's coins on it, laid by refresh_hoards.
			var stone := HomeStoreFurniture._mat(Color(0.38, 0.36, 0.34), 0.95)
			HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(Level.HOARD_PLINTH, Level.HOARD_PLINTH + 0.1, 0.14), stone, Vector3(0, 0.07, 0))
			var heaps := Node3D.new()
			heaps.name = "Heaps"
			heaps.position = Vector3(0, 0.14, 0)
			root.add_child(heaps)
			root.set_meta("hoard", heaps)
			solids.append({"at": Vector3.ZERO, "size": Vector3(Level.HOARD_PLINTH * 1.6, 0.6, Level.HOARD_PLINTH * 1.6)})
			station.spot = Vector3(0, 0.5, 0)
		"leuchter":
			var iron := HomeStoreFurniture._mat(Color(0.18, 0.17, 0.16), 0.5, 0.6)
			HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.35, 0.4, 0.06), iron, Vector3(0, 0.03, 0))
			HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.04, 0.05, 1.3), iron, Vector3(0, 0.68, 0))
			HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.25, 0.08, 0.06), iron, Vector3(0, 1.34, 0))
			var candles := level._place("candle_triple", Vector3(0, 1.37, 0), 0.0, root)
			var glow := _add_light(root, Vector3(0, 1.9, 0))
			glow.set_meta(LightShadows.INDOOR, true)
			# A click puts the candles out: flames and light together, and it is kept (see toggle_candles).
			CandleStand.prepare(root, candles, glow)
			CandleStand.set_lit(root, not piece.has(CandleStand.OUT))
			station.spot = Vector3(0, 1.5, 0)
			station.stand = root
			station.piece = {"storey": piece.get("storey", 0), "x": piece.get("x", 0), "y": piece.get("y", 0)}
			solids.append({"at": Vector3.ZERO, "size": Vector3(0.6, 1.4, 0.6)})
		"fackel":
			var holder := Node3D.new()
			# Its iron plate flat against the wall's face (TORCH_BACK: the plate's back).
			holder.position = Vector3(0, 1.45, -HouseSketch.CELL * 0.5 + HouseSketcher.THICK * 0.5 + TORCH_BACK)
			root.add_child(holder)
			level._place("torch_mounted", Vector3.ZERO, 0.0, holder)
			var flame := Effects.make_flame()
			flame.position = Vector3(0, 0.78, 0.45)
			flame.scale = Vector3.ONE * 0.8
			holder.add_child(flame)
			_add_light(holder, Vector3(0, 1.0, 0.8)).set_meta(LightShadows.INDOOR, true)
		"bild_berge", "bild_see", "bild_drache":
			_build_painting(root, int(info.painting))
		_:
			if kind == AppleTree.KIND:
				var day: int = (level as Outdoor).season_day if level is Outdoor else 0
				solids.append_array(AppleTree.build(root, piece, day))
				station.piece = {"storey": piece.get("storey", 0), "x": piece.get("x", 0), "y": piece.get("y", 0)}
			elif info.get("garden", false):
				var lights := []
				solids.append_array(GardenDecor.build(root, kind, maxi(_garden_stage, 0), level, lights))
				for l in lights:
					_add_light(l[0], Vector3.ZERO, l[1], roof_reach(l[2], piece.get("storey", 0), l[0].position.y), l[3])
			elif info.has("goddess"):
				solids.append_array(HouseholdGods.build_shrine(root, info.goddess))
	root.set_meta("solids", solids)
	return station


## How far a garden light reaches, standing on a storey with its light `high` over the floor. On
## a flat roof it ends ROOF_CLEARANCE over the ground: its light stays a pool on the roof, and the
## house under it casts no second, lamp-made shadow round its foot next to the sun's (the house's
## walls shade a point light, see LightShadows).
static func roof_reach(reach: float, storey: int, high: float) -> float:
	if storey <= 0:
		return reach
	return minf(reach, HouseFurniture.FLOORS[storey] + high - ROOF_CLEARANCE)


## A warm light like a wall torch's, a little softer, that flickers. Its place counts as lit at
## night (see Outdoor.is_lit and refresh).
## A garden lamp's light is steady (`flicker` off) and its own lantern's colour.
func _add_light(parent: Node3D, at: Vector3, energy := LIGHT_ENERGY, reach := LIGHT_RANGE, flicker := true) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "FurnitureLight"
	light.light_color = Level.TORCH_COLOUR if flicker else GardenDecor.LAMP_COLOUR
	light.light_energy = energy
	light.omni_range = reach
	# The steady garden lamp keeps its old, steeper fall-off; only flames burn soft (see Level.TORCH_ENERGY).
	light.omni_attenuation = Level.TORCH_ATTENUATION if flicker else LAMP_ATTENUATION
	light.position = at
	parent.add_child(light)
	if not flicker:
		return light
	var glow := light.create_tween().set_loops()
	glow.tween_property(light, "light_energy", energy * 1.1, 0.25)
	glow.tween_property(light, "light_energy", energy * 0.88, 0.32)
	return light


## A framed painting on the wall behind the piece: a dark oak frame with a gilt edge and the
## painted picture (see _painting_texture).
func _build_painting(root: Node3D, motif: int) -> void:
	var back := -HouseSketch.CELL * 0.5 + 0.12
	var frame := HomeStoreFurniture._mat(Color(0.32, 0.2, 0.12), 0.6)
	var gilt := HomeStoreFurniture._mat(Color(0.85, 0.65, 0.3), 0.35, 0.8)
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(PAINTING.x + 0.16, PAINTING.y + 0.16, 0.06)), frame, Vector3(0, PAINTING_HEIGHT, back))
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(PAINTING.x + 0.04, PAINTING.y + 0.04, 0.07)), gilt, Vector3(0, PAINTING_HEIGHT, back + 0.005))
	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	var quad := QuadMesh.new()
	quad.size = PAINTING
	canvas.mesh = quad
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = _painting_texture(motif)
	paint.roughness = 0.9
	canvas.material_override = paint
	canvas.position = Vector3(0, PAINTING_HEIGHT, back + 0.045)
	root.add_child(canvas)


## The picture of a motif: 0 snowy peaks at dusk, 1 a lake under the full moon, 2 a dragon over
## the village. Oil paintings at 1040 x 800, made by tools/make_paintings.py.
static func _painting_texture(motif: int) -> Texture2D:
	return load(PAINTINGS[clampi(motif, 0, PAINTINGS.size() - 1)])


## The trophy stand: a wooden shelf wall against the back of its cell, with a grid of small
## shelves (STAND_COLS x STAND_ROWS cubbies), each holding one trophy on its coloured plinth.
## Returns the node the statuettes stand on (its origin at the bottom shelf's middle front).
func _build_stand(root: Node3D) -> Node3D:
	var oak := StandardMaterial3D.new()
	oak.albedo_texture = load("res://assets/house/wood_floor.jpg")
	oak.albedo_color = Color(0.55, 0.38, 0.26)
	oak.roughness = 0.8
	var dark := oak.duplicate() as StandardMaterial3D
	dark.albedo_color = Color(0.36, 0.24, 0.16)
	var back := -HouseSketch.CELL * 0.5 + 0.1
	var w := STAND_WIDTH
	var d := STAND_DEPTH
	var t := STAND_BOARD
	var top: float = STAND_BOTTOM + STAND_ROWS * STAND_ROW
	var mid := back + d * 0.5
	# The back board, the two sides, a kick board below and a crown on top.
	_board(root, Vector3(w, top, 0.04), dark, Vector3(0, top * 0.5, back + 0.02))
	for side: float in [-1.0, 1.0]:
		_board(root, Vector3(t, top, d), oak, Vector3(side * (w - t) * 0.5, top * 0.5, mid))
	_board(root, Vector3(w, STAND_BOTTOM, d), dark, Vector3(0, STAND_BOTTOM * 0.5, mid))
	_board(root, Vector3(w + 0.08, 0.06, d + 0.05), dark, Vector3(0, top + 0.03, mid + 0.01))
	# The shelves, and the dividers between the cubbies.
	for row in STAND_ROWS + 1:
		_board(root, Vector3(w - t, t, d), oak, Vector3(0, STAND_BOTTOM + row * STAND_ROW - t * 0.5, mid))
	var inner := w - 2.0 * t
	for col in range(1, STAND_COLS):
		var x := -inner * 0.5 + inner * col / STAND_COLS
		_board(root, Vector3(t, top - STAND_BOTTOM, d - 0.02), oak, Vector3(x, (top + STAND_BOTTOM) * 0.5, mid - 0.01))
	var shelf := Node3D.new()
	shelf.position = Vector3(0, STAND_BOTTOM, mid)
	root.add_child(shelf)
	return shelf


## One board of the trophy stand, `size` big, its middle at `at`.
static func _board(root: Node3D, size: Vector3, mat: Material, at: Vector3) -> void:
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(size), mat, at)


## Where each of `count` trophies stands on the shelf wall, from the stand's shelf node: the top
## row first, left to right. More trophies than cubbies squeeze in more to a row.
static func stand_slots(count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var cols := maxi(STAND_COLS, ceili(float(count) / STAND_ROWS))
	var inner := STAND_WIDTH - 2.0 * STAND_BOARD
	for i in count:
		var row := STAND_ROWS - 1 - i / cols
		var col := i % cols
		out.append(Vector3(-inner * 0.5 + inner * (col + 0.5) / cols, row * STAND_ROW, -0.01))
	return out


## How big the trophies stand on the shelf wall: TROPHY_SCALE, smaller when more than the
## cubbies have to share a row.
static func stand_scale(count: int) -> float:
	var cols := maxi(STAND_COLS, ceili(float(count) / STAND_ROWS))
	return TROPHY_SCALE * STAND_COLS / cols


## Puts the books kept, the weapons kept and the trophies won on the hero's shelves, racks and stands.
func refresh_books() -> void:
	refresh_hoards()
	var count := HomeStores.total(game.home_stores, HomeStores.BOOKS)
	for shelf in _shelves:
		if is_instance_valid(shelf):
			Bookshelf.refresh_shelf(shelf, count)
	var weapons: Dictionary = game.home_stores.get(HomeStores.WEAPONS, {})
	for rack in _racks:
		if is_instance_valid(rack):
			WeaponRack.refresh_rack(rack, weapons)
	var shown := HomeUpgrades.trophies_shown(game.trophies)
	var slots := stand_slots(shown.size())
	var size := stand_scale(shown.size())
	for stand: Node3D in _stands:
		if not is_instance_valid(stand):
			continue
		for child in stand.get_children():
			stand.remove_child(child)
			child.queue_free()
		for i in shown.size():
			var statue: Node3D = game.level._trophy_statue(shown[i])
			if statue == null:
				continue
			statue.scale = Vector3.ONE * size
			statue.position = slots[i]
			stand.add_child(statue)


## Lays the coins the hero has (purse and chest, see Game.hoard_coins) as heaps on their hoards.
## Only a changed mix is drawn again.
func refresh_hoards() -> void:
	if _hoards.is_empty():
		return
	var held: Dictionary = game.hoard_coins()
	var mix := HomeHoard.mix(HomeHoard.stage_of(HomeHoard.wealth(int(held.get("kupfermuenze", 0)),
			int(held.get("silbermuenze", 0)), int(held.get("goldmuenze", 0)))), held)
	for heaps: Node3D in _hoards:
		if is_instance_valid(heaps) and heaps.get_meta("shown", {}) != mix:
			heaps.set_meta("shown", mix)
			game.level._lay_heaps(heaps, mix)


## The storeys above the one the hero is on (or looks at in the tool) fade away with the roofs
## (see HouseSketcher._update_fade), and their furniture with them.
func _fade(force := false) -> void:
	if game == null or game.house_sketcher == null:
		return
	var limit: int = game.house_sketcher.fade_storey
	if not force and _pieces.get_meta("limit", 100) == limit:
		return
	_pieces.set_meta("limit", limit)
	for root: Node3D in _pieces.get_children():
		root.visible = int(root.get_meta("storey", 0)) <= limit


# --- The tool -------------------------------------------------------------------

func enter() -> void:
	if plan() == null:
		game.show_message(Lang.t("Du hast noch kein Grundstück. Das Amt der Krone trägt es dir ein."), 3.0)
		return
	active = true
	_frame_pending = true
	furniture = HouseFurniture.of(game.hero_name)
	if tool == "" or (tool != PICK_UP and furniture.count(tool) == 0):
		tool = _first_waiting()
	game.house_sketcher.view_storey = storey
	_bar.visible = true
	_hint = Lang.t("Einrichten: Möbel wählen, mit R oder Rechtsklick drehen, mit Linksklick abstellen. Aufgestellte Möbel mit gedrückter Maustaste verschieben.") if furniture.waiting() > 0 \
			else Lang.t("Keine Möbel zum Aufstellen. Raumausstatterin Ilse am Dorfplatz verkauft welche.")
	game.show_message(_hint, 4.0)
	_update_bar()


func leave() -> void:
	if not active:
		return
	active = false
	game.frame_pull = 0.0
	_bar.visible = false
	cancel_drag()
	_clear_ghost()
	if game.house_sketcher != null:
		game.house_sketcher.view_storey = HouseSketcher.NO_VIEW
	furniture.save(game.hero_name)


## Back to the blueprint tool.
func to_blueprint() -> void:
	leave()
	game.house_sketcher.enter()


## Where the camera looks while the tool is open (the blueprint tool's framing of the plot).
func view_centre() -> Vector3:
	return game.house_sketcher.view_centre() + Vector3(0, HouseFurniture.FLOORS[storey], 0)


func _first_waiting() -> String:
	for kind in HouseFurniture.KINDS:
		if furniture.count(kind) > 0:
			return kind
	return PICK_UP


func select(next: String) -> void:
	tool = next
	# Garden pieces stand only outdoors on the ground floor's level: the tool shows it. The roof
	# lights may stay on a level above, where flat roofs are.
	if HouseFurniture.in_garden(next) and storey != 0 and not (HouseFurniture.on_roof(next) and storey > 0):
		storey = 0
		game.house_sketcher.view_storey = storey
	_clear_ghost()
	_update_bar()


func turn() -> void:
	# R over a placed piece turns that piece where it stands (not while one is held).
	if not dragging() and _mouse_point != null and plan() != null:
		var i := _piece_under(_mouse_point)
		if i >= 0:
			turn_placed(i)
			return
	rot = (rot + 1) % 4
	var cell := _hover_cell
	_clear_ghost()
	_hover_cell = cell
	if _hover_cell.x >= 0:
		_show_ghost()


func cycle_level() -> void:
	storey = next_level(storey, plan())
	game.house_sketcher.view_storey = storey
	_clear_ghost()
	_update_bar()


## The level after `from` in the level button's round: ground floor, upper floor, the roof over
## the upper floor (only once a slab is built up there), cellar.
static func next_level(from: int, house: HouseSketch) -> int:
	if from == 1 and house != null and _has_top_roof(house):
		return HouseFurniture.ROOF_STOREY
	return {0: 1, 1: -1, HouseFurniture.ROOF_STOREY: -1, -1: 0}.get(from, 0)


## Whether a slab is built over the upper floor anywhere: a flat roof up there.
static func _has_top_roof(house: HouseSketch) -> bool:
	for key in house.pieces:
		var p: Dictionary = house.pieces[key]
		if p.kind == HouseSketch.SLAB and p.state == HouseSketch.BUILT and HouseSketch.parts_of(key)[0] == HouseSketch.MAX_STOREY:
			return true
	return false


## Keys and mouse buttons while the tool is open. Returns whether the event was used.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		match event.physical_keycode:
			KEY_ESCAPE:
				leave()
				return true
			KEY_R:
				turn()
				return true
			KEY_DELETE:
				return remove_under_mouse()
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			turn()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			var spot = aim_point(event.position)
			if spot != null and (_hangs_here() or not grab(spot, event.position)):
				click(spot)
			return true
	return false


## Turns a placed piece a quarter (or as far as it must) to the next way it fits where it
## stands. Returns whether it turned.
func turn_placed(i: int) -> bool:
	var house := plan()
	if house == null or i < 0 or i >= furniture.placed.size():
		return false
	var p: Dictionary = furniture.placed[i].duplicate()
	var name := Lang.t(HouseFurniture.KINDS[p.kind].name)
	furniture.pick_up(i)
	var why := ""
	for step in range(1, 4):
		var r: int = (p.rot + step) % 4
		var problem := furniture.problem(house, p.kind, p.storey, p.x, p.y, r)
		if problem == "":
			furniture.place(house, p.kind, p.storey, p.x, p.y, r, p)
			furniture.save(game.hero_name)
			Sfx.play(game, "gear_soft_0", -4.0)
			_say(Lang.t("%s gedreht.") % name)
			_clear_ghost()
			refresh()
			return true
		if why == "":
			why = problem
	_put_back(house, p)
	furniture.save(game.hero_name)
	_say(HouseFurniture.reason(why) + " " + Lang.t("%s lässt sich hier nicht drehen.") % name)
	return false


## The placed piece under a point of the shown floor, or -1: a torch or a painting when the point
## is close to the wall it hangs on, otherwise the floor piece of the cell.
func _piece_under(point: Vector3) -> int:
	var house := plan()
	if house == null:
		return -1
	var c := house.cell_at(point)
	var mid := house.cell_world(c.x, c.y)
	for i in furniture.placed.size():
		var p: Dictionary = furniture.placed[i]
		if p.storey != storey or not HouseFurniture.on_wall(p.kind) or Vector2i(p.x, p.y) != c:
			continue
		var back := Vector3(-sin(HouseFurniture.angle(p.rot)), 0, -cos(HouseFurniture.angle(p.rot)))
		if (Vector3(point.x, 0, point.z) - Vector3(mid.x, 0, mid.z)).dot(back) > HouseSketch.CELL * 0.25:
			return i
	return furniture.piece_at(storey, c)


## Whether a torch or a painting in stock is chosen: it hangs on walls over the floor pieces, so
## the mouse over a bed shows where it would hang instead of taking hold of the bed.
func _hangs_here() -> bool:
	return tool != PICK_UP and tool != "" and HouseFurniture.on_wall(tool) and furniture.count(tool) > 0


## Whether a placed piece is held to be dragged.
func dragging() -> bool:
	return not _held.is_empty()


## A left press on the floor: a placed piece under it is lifted and follows the mouse until the
## button is let go (see drop). Returns whether a piece was taken.
func grab(point: Vector3, screen := Vector2.ZERO) -> bool:
	var house := plan()
	if house == null or dragging():
		return false
	var i := _piece_under(point)
	if i < 0:
		return false
	_held = furniture.placed[i].duplicate()
	_held_tool = tool
	_held_from = screen
	furniture.pick_up(i)
	furniture.save(game.hero_name)
	tool = _held.kind
	rot = _held.rot
	refresh()
	_clear_ghost()
	_hover_cell = Vector2i(_held.x, _held.y)
	_show_ghost()
	_update_bar()
	_say(Lang.t("%s: mit gedrückter Maustaste an einen anderen Platz ziehen, R dreht.") % Lang.t(HouseFurniture.KINDS[tool].name))
	return true


## The left button let go while a piece is held: it is put down where the mouse is, or back where
## it stood when it does not fit there. A press and let go without moving is a plain click: with
## "pick up" chosen, the piece goes back into the store.
func drop(point, screen := Vector2.INF) -> void:
	if not dragging():
		return
	var house := plan()
	var held := _held
	_held = {}
	var moved := screen == Vector2.INF or screen.distance_to(_held_from) >= DRAG_START
	var name := Lang.t(HouseFurniture.KINDS[held.kind].name)
	if not moved and _held_tool == PICK_UP:
		furniture.save(game.hero_name)
		Sfx.play(game, "gear_soft_0", -4.0)
		_say(Lang.t("%s entfernt: Es liegt wieder im Lager.") % name)
		_end_drag(PICK_UP)
		return
	var why := "same"
	if moved and point != null and house != null:
		hover(point)
		why = furniture.place(house, held.kind, storey, _hover_cell.x, _hover_cell.y, rot, held)
	if why == "":
		Sfx.play(game, "gear_soft_0", -2.0)
		_say(Lang.t("%s steht jetzt hier.") % name)
	else:
		_put_back(house, held)
		_say(Lang.t("Gedrückt halten und ziehen, um %s zu verschieben.") % name if why == "same" \
				else HouseFurniture.reason(why) + " " + Lang.t("%s bleibt, wo es war.") % name)
	furniture.save(game.hero_name)
	_end_drag(_held_tool)


## Lets go of a held piece without moving it (the tool closes, a window opens).
func cancel_drag() -> void:
	if not dragging():
		return
	var held := _held
	_held = {}
	_put_back(plan(), held)
	furniture.save(game.hero_name)
	_end_drag(_held_tool)


func _put_back(house: HouseSketch, held: Dictionary) -> void:
	if house != null:
		furniture.place(house, held.kind, held.storey, held.x, held.y, held.rot, held)


func _end_drag(next_tool: String) -> void:
	tool = next_tool
	if tool != PICK_UP and furniture.count(tool) == 0:
		tool = _first_waiting()
	_clear_ghost()
	refresh()
	_update_bar()


## The point on the shown storey's floor under a point of the screen, or null.
func floor_point(screen: Vector2):
	var cam: Camera3D = game.camera
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if dir.y > -0.01:
		return null
	var y: float = HouseFurniture.FLOORS[storey]
	return origin + dir * ((y - origin.y) / dir.y)


## The floor point the mouse aims at: when the mouse is over a placed piece of the shown storey,
## a point that _piece_under turns into that piece (the middle of a standing piece, or close to
## the wall behind a torch or a painting), else floor_point. Seen from the slanted camera, the
## top of a chest covers the floor of the cell behind it, and a torch above it is drawn over
## the cell behind that, so a plain floor point missed both. While a torch or a painting in
## stock is chosen, it is the plain floor point (it hangs on walls over the floor pieces).
func aim_point(screen: Vector2):
	var spot = floor_point(screen)
	var house := plan()
	if house == null or dragging() or _hangs_here():
		return spot
	var cam: Camera3D = game.camera
	var hit := _aimed_piece(house, cam.project_ray_origin(screen), cam.project_ray_normal(screen))
	if hit < 0:
		return spot
	var p: Dictionary = furniture.placed[hit]
	var mid := HouseFurniture.centre(house, p.kind, p.storey, p.x, p.y, p.rot)
	if HouseFurniture.on_wall(p.kind):
		var back := Vector3(-sin(HouseFurniture.angle(p.rot)), 0, -cos(HouseFurniture.angle(p.rot)))
		mid += back * HouseSketch.CELL * 0.4
	return mid


## The placed piece of the shown storey that a ray from the camera meets first, or -1.
func _aimed_piece(house: HouseSketch, from: Vector3, dir: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in furniture.placed.size():
		var p: Dictionary = furniture.placed[i]
		if p.storey != storey:
			continue
		var at = pick_box(house, p).intersects_ray(from, dir)
		if at != null and (at - from).length() < best_d:
			best_d = (at - from).length()
			best = i
	return best


## The box a placed piece fills for the mouse: its cells up to its height, or for a torch or a
## painting the strip of wall it hangs on.
static func pick_box(house: HouseSketch, p: Dictionary) -> AABB:
	var f := HouseFurniture.footprint(p.kind, p.rot)
	var floor_y: float = HouseFurniture.FLOORS[p.storey]
	var corner := house.node_world(p.x, p.y)
	if not HouseFurniture.on_wall(p.kind):
		var inset := 0.1
		var size := Vector3(f.x * HouseSketch.CELL - inset * 2, PICK_HEIGHT.get(p.kind, PICK_HEIGHT_DEFAULT), f.y * HouseSketch.CELL - inset * 2)
		return AABB(Vector3(corner.x + inset, floor_y, corner.z + inset), size)
	var mid := HouseFurniture.centre(house, p.kind, p.storey, p.x, p.y, p.rot)
	var back := Vector3(-sin(HouseFurniture.angle(p.rot)), 0, -cos(HouseFurniture.angle(p.rot))).round()
	var spread := PICK_TORCH
	if HouseFurniture.KINDS[p.kind].has("painting"):
		spread = Vector3(PAINTING.x, PAINTING_HEIGHT - PAINTING.y * 0.5, PAINTING_HEIGHT + PAINTING.y * 0.5)
	var across := Vector3(absf(back.z), 0, absf(back.x)) * spread.x
	var deep := Vector3(absf(back.x), 0, absf(back.z)) * PICK_WALL_DEPTH
	var centre := mid + back * (HouseSketch.CELL * 0.5 - PICK_WALL_DEPTH * 0.5)
	var size := across + deep + Vector3(0, spread.z - spread.y, 0)
	return AABB(Vector3(centre.x - size.x * 0.5, floor_y + spread.y, centre.z - size.z * 0.5), size)


## The north-west cell of the chosen piece with its middle under a floor point.
func _anchor(point: Vector3) -> Vector2i:
	var house := plan()
	var f := HouseFurniture.footprint(tool, rot)
	var origin := house.node_world(0, 0)
	var fx := (point.x - origin.x) / HouseSketch.CELL - f.x * 0.5
	var fz := (point.z - origin.z) / HouseSketch.CELL - f.y * 0.5
	return Vector2i(roundi(fx), roundi(fz))


func hover(point: Vector3) -> void:
	_mouse_point = point
	var house := plan()
	if house == null:
		return
	# Over a placed piece with nothing held: it can be dragged or turned.
	if tool != PICK_UP and not dragging() and not _hangs_here():
		var under := _piece_under(point)
		if under >= 0:
			var p: Dictionary = furniture.placed[under]
			var key := "over:%s:%d:%d:%d" % [p.kind, p.x, p.y, p.rot]
			if key != _ghost_key:
				_clear_ghost()
				_ghost_key = key
				_footprint_marker(house, p.kind, p.x, p.y, p.rot, Color(ON_COLOR, 0.45))
				_say(Lang.t("%s: gedrückt ziehen verschiebt, R dreht.") % Lang.t(HouseFurniture.KINDS[p.kind].name))
			return
		if _ghost_key.begins_with("over:"):
			_clear_ghost()
	if tool == PICK_UP and not dragging():
		var c := house.cell_at(point)
		var i := _piece_under(point)
		var key := "pick:-1"
		if i >= 0:
			var q: Dictionary = furniture.placed[i]
			key = "pick:%s:%d:%d:%d" % [q.kind, q.x, q.y, q.rot]
		if key == _ghost_key:
			return
		_clear_ghost()
		_ghost_key = key
		_hover_cell = c
		if i >= 0:
			var p: Dictionary = furniture.placed[i]
			_footprint_marker(house, p.kind, p.x, p.y, p.rot, BAD_COLOR)
			_say(Lang.t("Klicken, um %s zu entfernen. Gedrückt ziehen verschiebt, R dreht.") % Lang.t(HouseFurniture.KINDS[p.kind].name))
		else:
			_say(Lang.t("Klicke ein Möbelstück an, um es zu entfernen, oder zieh es an einen anderen Platz."))
		return
	if tool == "":
		return
	var at := _anchor(point)
	if HouseFurniture.on_wall(tool):
		# A torch or a painting turns its back to the nearest built wall of the cell.
		at = house.cell_at(point)
		var best := rot
		var best_d := INF
		var mid := house.cell_world(at.x, at.y)
		for r in 4:
			if not HouseFurniture.wall_behind(house, storey, at, r):
				continue
			var back := Vector3(-sin(HouseFurniture.angle(r)), 0, -cos(HouseFurniture.angle(r)))
			var d := (mid + back * HouseSketch.CELL * 0.5 - Vector3(point.x, 0, point.z)).length()
			if d < best_d:
				best_d = d
				best = r
		if best != rot:
			rot = best
			_ghost_key = ""
	if at == _hover_cell and _ghost.get_child_count() > 0:
		return
	_hover_cell = at
	_show_ghost()


func _show_ghost() -> void:
	var house := plan()
	if house == null or tool == "" or tool == PICK_UP:
		return
	var why := furniture.problem(house, tool, storey, _hover_cell.x, _hover_cell.y, rot)
	if furniture.count(tool) <= 0 and not dragging():
		why = "none"
	var key := "%s:%d:%s" % [tool, rot, why == ""]
	if key != _ghost_key:
		for child in _ghost.get_children():
			_ghost.remove_child(child)
			child.queue_free()
		_ghost_key = key
		var model := Node3D.new()
		model.name = "Model"
		_ghost.add_child(model)
		build_piece(model, tool)
		_ghostly(model, OK_COLOR if why == "" else BAD_COLOR)
	var model: Node3D = _ghost.get_node("Model")
	model.position = HouseFurniture.centre(house, tool, storey, _hover_cell.x, _hover_cell.y, rot) + Vector3(0, 0.02, 0)
	model.rotation.y = HouseFurniture.angle(rot)
	for child in _ghost.get_children():
		if child != model:
			_ghost.remove_child(child)
			child.queue_free()
	_footprint_marker(house, tool, _hover_cell.x, _hover_cell.y, rot, OK_COLOR if why == "" else BAD_COLOR)
	if dragging():
		_say(Lang.t("Loslassen: %s hier abstellen. R dreht.") % Lang.t(HouseFurniture.KINDS[tool].name) if why == "" else HouseFurniture.reason(why))
		return
	_say(Lang.t("Linksklick: %s abstellen. R oder Rechtsklick: drehen.") % Lang.t(HouseFurniture.KINDS[tool].name) if why == "" else HouseFurniture.reason(why))


## Turns a built model into a see-through ghost of one colour: no lights, flames or signs.
static func _ghostly(node: Node, colour: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for child in node.find_children("*", "", true, false):
		if child is MeshInstance3D:
			child.material_override = mat
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif child is Light3D or child is GPUParticles3D or child is CPUParticles3D or child is Label3D:
			child.visible = false


## A flat mark on the floor over the cells of a piece.
func _footprint_marker(house: HouseSketch, kind: String, x: int, y: int, r: int, colour: Color) -> void:
	var f := HouseFurniture.footprint(kind, r)
	var mark := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(f.x * HouseSketch.CELL - 0.1, f.y * HouseSketch.CELL - 0.1)
	mark.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.material_override = mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position = HouseFurniture.centre(house, kind, storey, x, y, r) + Vector3(0, 0.05, 0)
	_ghost.add_child(mark)


func _clear_ghost() -> void:
	_ghost_key = ""
	_hover_cell = Vector2i(-1, -1)
	for child in _ghost.get_children():
		_ghost.remove_child(child)
		child.queue_free()


## A left click on the shown floor: put the chosen piece down, or pick one up.
func click(point: Vector3) -> void:
	var house := plan()
	if house == null:
		return
	if tool == PICK_UP:
		var i := _piece_under(point)
		if i < 0:
			return
		var kind := furniture.pick_up(i)
		furniture.save(game.hero_name)
		Sfx.play(game, "gear_soft_0", -4.0)
		_say(Lang.t("%s entfernt: Es liegt wieder im Lager.") % Lang.t(HouseFurniture.KINDS[kind].name))
		refresh()
		_update_bar()
		return
	if tool == "":
		return
	if _piece_under(point) >= 0 and not _hangs_here():
		_say(HouseFurniture.reason("taken"))
		return
	hover(point)
	# A tree put down from the store is planted today (see AppleTree).
	var growth := {"planted": game.level.season_day} if tool == AppleTree.KIND else {}
	var why := furniture.place(house, tool, storey, _hover_cell.x, _hover_cell.y, rot, growth)
	if why != "":
		_say(HouseFurniture.reason(why))
		return
	furniture.save(game.hero_name)
	Sfx.play(game, "gear_soft_0", -2.0)
	var name := Lang.t(HouseFurniture.KINDS[tool].name)
	if furniture.count(tool) == 0:
		tool = _first_waiting()
	_clear_ghost()
	refresh()
	_update_bar()
	_say(Lang.t("%s steht.") % name)


## The Delete key: the piece under the mouse goes back into the store, whichever tool is chosen.
## Returns whether a piece was taken.
func remove_under_mouse() -> bool:
	if dragging() or _mouse_point == null or plan() == null:
		return false
	var i := _piece_under(_mouse_point)
	if i < 0:
		return false
	var kind := furniture.pick_up(i)
	furniture.save(game.hero_name)
	Sfx.play(game, "gear_soft_0", -4.0)
	_say(Lang.t("%s entfernt: Es liegt wieder im Lager.") % Lang.t(HouseFurniture.KINDS[kind].name))
	_clear_ghost()
	refresh()
	_update_bar()
	return true


func _say(text: String) -> void:
	_hint = text
	if _status != null:
		_status.text = text


# --- The bar --------------------------------------------------------------------

func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.visible = false
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.offset_bottom = -8
	var style := UiKit.panel_style(UiKit.BRONZE)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_bar.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_bar.add_child(box)
	# Rows 1 to 3: the pieces, each with the number waiting to be put down; light and the walls
	# on the second row, the garden on the third.
	var kinds := _row(box)
	var lights := _row(box)
	var garden := _row(box)
	for kind in HouseFurniture.KINDS:
		var b := _small_button("", select.bind(kind), KIND_BUTTON.x)
		b.tooltip_text = Lang.t(HouseFurniture.KINDS[kind].name)
		(garden if HouseFurniture.in_garden(kind) else lights if kind in SECOND_ROW else kinds).add_child(b)
		_kind_buttons[kind] = b
	# Row 4: the storey, turning, picking up, back to the blueprint, close.
	var options := _row(box)
	_level_button = _small_button("", cycle_level, 250)
	options.add_child(_level_button)
	_turn_button = _small_button(Lang.t("Drehen (R)"), turn, 130)
	options.add_child(_turn_button)
	_pick_button = _small_button(Lang.t("Entfernen"), select.bind(PICK_UP), 130)
	_pick_button.tooltip_text = Lang.t("Klicke ein aufgestelltes Möbelstück an, um es zurück ins Lager zu legen (Taste Entf über dem Stück).")
	options.add_child(_pick_button)
	options.add_child(_small_button(Lang.t("Bauplan"), to_blueprint, 130))
	options.add_child(_small_button(Lang.t("Schließen"), leave, 130))
	_status = UiKit.label(UiKit.TEXT_FONT, 14, Color(1.0, 0.75, 0.5))
	_status.custom_minimum_size = Vector2(STATUS_WIDTH, 20)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_status)
	if game != null and game._hud != null:
		game._hud.add_child(_bar)
	else:
		add_child(_bar)


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	return row


## A small button like the blueprint tool's: low, small text, a fixed width.
func _small_button(text: String, action: Callable, width: float) -> Button:
	var b: Button = UiKit.button(text, action)
	b.custom_minimum_size = Vector2(width, KIND_BUTTON.y)
	b.add_theme_font_size_override("font_size", 14)
	b.clip_text = true
	return b


func _update_bar() -> void:
	if _bar == null or furniture == null:
		return
	for kind in _kind_buttons:
		var b: Button = _kind_buttons[kind]
		var n := furniture.count(kind)
		b.text = "%s %d" % [Lang.t(SHORT[kind]), n]
		b.disabled = n == 0
		_mark(b, kind == tool)
	_mark(_pick_button, tool == PICK_UP)
	_pick_button.disabled = furniture.placed.is_empty()
	_turn_button.disabled = false
	_level_button.text = Lang.t("Ebene: %s") % Lang.t(LEVEL_NAMES[storey])
	_status.text = _hint


## Shows a tool button as chosen (like the blueprint tool's).
func _mark(b: Button, on: bool) -> void:
	b.add_theme_color_override("font_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
	b.add_theme_color_override("font_hover_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
	if not b.has_meta("normal"):
		b.set_meta("normal", b.get_theme_stylebox("normal"))
	b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed") if on else b.get_meta("normal"))
