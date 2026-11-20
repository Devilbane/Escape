class_name HouseFurnisher
extends Node3D
## The furniture in the self-built houses on the open map (see HouseFurniture), and the
## furnishing tool the hero uses to put their own pieces down.
##
## Everyone's furniture stands in their houses for all to see; only the hero's own pieces are
## stations (bed, storage chest, bookshelf, trophy stand, workbenches), and they open the very
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
## it a quarter, and "Aufheben" takes a piece back into the store (to move it, pick it up and put
## it down again).

## The short names on the tool bar's buttons, in the order of HouseFurniture.KINDS.
const SHORT := {"bett": "Bett", "truhe": "Truhe", "regal": "Regal", "kamin": "Kamin", "trophaeen": "Trophäen",
	"werkbank": "Werkbank", "feinbank": "Feinbank", "schleifrad": "Schleifstein", "alchemie": "Alchemie",
	"leuchter": "Leuchter", "fackel": "Wandfackel", "bild_berge": "Bild: Berge", "bild_see": "Bild: See", "bild_drache": "Bild: Drache"}
## The tool bar's second row: light and the walls. Everything else is on the first.
const SECOND_ROW := ["leuchter", "fackel", "bild_berge", "bild_see", "bild_drache"]
## The light of a candle stand and a torch: the dungeon's wall torch, a little softer indoors.
const LIGHT_ENERGY := 2.4
const LIGHT_RANGE := 9.0
## A painting's frame (across, high) and how high its middle hangs (metres).
const PAINTING := Vector2(1.3, 1.0)
const PAINTING_HEIGHT := 1.55
## The painted pictures, made once (see _painting_texture).
static var _paintings := {}
const PICK_UP := "aufheben"
const LEVEL_NAMES := {-1: "im Keller", 0: "im Erdgeschoss", 1: "im Obergeschoss"}
const KIND_BUTTON := Vector2(130, 32)
const STATUS_WIDTH := 880.0
const OK_COLOR := Color(0.4, 0.95, 0.4, 0.45)
const BAD_COLOR := Color(1.0, 0.4, 0.35, 0.45)
const ON_COLOR := Color(1.0, 0.82, 0.4)
## How close the hero must come to a piece to use it, from its middle (metres).
const TOUCH := {"bett": 2.6, "regal": 2.4, "feinbank": 2.4, "schleifrad": 2.4, "alchemie": 2.4}
const TOUCH_DEFAULT := 1.8
## The scale of the pieces that are too big or too tall for a 2 m cell and a 2.6 m storey.
const SHELF_SCALE := 0.75
const FIRE_SCALE := 0.72
const TABLE_SCALE := 0.8
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
## The bookshelves and trophy stands of the hero's house, to show books and trophies.
var _shelves: Array = []
var _stands: Array = []
var _bar: PanelContainer
var _kind_buttons := {}
var _level_button: Button
var _turn_button: Button
var _pick_button: Button
var _status: Label
var _hint := ""
var _frame_pending := false
var _hover_cell := Vector2i(-1, -1)


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
	if not active:
		return
	if _frame_pending and game.house_sketcher != null:
		_frame_pending = false
		game.house_sketcher.solve_frame(_bar)
	if game.state == game.State.PLAYING and not game.menus.is_open():
		var spot = floor_point(game.get_viewport().get_mouse_position())
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
	for child in _pieces.get_children():
		_pieces.remove_child(child)
		child.queue_free()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	furniture = HouseFurniture.of(game.hero_name)
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
	var lit: Array[Vector3] = []
	for light: Node3D in _pieces.find_children("*", "OmniLight3D", true, false):
		lit.append(light.global_position if light.is_inside_tree() else light.position)
	game.level.house_lights = lit
	_fade(true)
	if active:
		_update_bar()


## One piece, solid, and (in the hero's own house) a station.
func _draw_piece(house: HouseSketch, p: Dictionary, is_mine: bool) -> void:
	var at := HouseFurniture.centre(house, p.kind, p.storey, p.x, p.y, p.rot)
	var root := Node3D.new()
	root.position = at
	root.rotation.y = HouseFurniture.angle(p.rot)
	root.set_meta("storey", p.storey)
	_pieces.add_child(root)
	var station := build_piece(root, p.kind)
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
	if station.is_empty():
		return
	station.pos = root.transform * station.get("pos", Vector3.ZERO)
	station.cell = game.level.world_to_cell(station.pos)
	station.used = false
	station.touch = TOUCH.get(p.kind, TOUCH_DEFAULT)
	station.furniture = p.kind
	if station.has("side"):
		station.side = root.transform * station.side
	if station.has("rot"):
		station.rot = root.rotation.y
	game.level.stations.append(station)
	_stations.append(station)


## Builds the model of a piece of `kind` into `root` (its front towards +z, its middle at the
## origin, on the floor). Notes its solids in the meta "solids" ({at, size}, local) and returns
## its station without a position in the world yet ({} for a piece without one).
func build_piece(root: Node3D, kind: String) -> Dictionary:
	var level: Level = game.level
	var info: Dictionary = HouseFurniture.KINDS[kind]
	var solids := []
	var station := {}
	if info.station != "":
		station = {"kind": info.station, "pos": Vector3.ZERO}
	match kind:
		"bett":
			level._place("bed_decorated", BED_OFFSET, 0.0, root)
			solids.append({"at": Vector3(0, 0, -0.47), "size": Vector3(2.6, 1.5, 3.0)})
			# The bed's own middle (where the hero lies, see Game._climb_into_bed), and beside its foot.
			station.pos = BED_OFFSET
			station.rot = 0.0
			station.side = Vector3(0, 0, 1.6)
		"truhe":
			level._place("chest", Vector3(0, 0, -0.35), 0.0, root)
			solids.append({"at": Vector3(0, 0, 0), "size": Vector3(1.7, 1.2, 1.8)})
		"regal":
			var shelf := Bookshelf.build_shelf(root, Vector3(0, 0, -HouseSketch.CELL * 0.5 + (Level.TILE * 0.5 - 0.1) * SHELF_SCALE), 0.0)
			shelf.scale = Vector3.ONE * SHELF_SCALE
			root.set_meta("shelf", shelf)
			solids.append({"at": Vector3(0, 0, -0.6), "size": Vector3(Bookshelf.WIDTH * SHELF_SCALE, 2.4, 0.75)})
		"kamin":
			var fire := HomeFireplace.build_into(root, {"pos": Vector3(0, 0, -HouseSketch.CELL * 0.5), "rot": 0.0})
			fire.scale = Vector3.ONE * FIRE_SCALE
			solids.append({"at": Vector3(0, 0, -HouseSketch.CELL * 0.5 + HomeFireplace.DEPTH * FIRE_SCALE * 0.5),
					"size": Vector3(HomeFireplace.WIDTH * FIRE_SCALE, 1.6, HomeFireplace.DEPTH * FIRE_SCALE)})
		"trophaeen":
			root.set_meta("stand", _build_stand(root))
			solids.append({"at": Vector3(0, 0, -0.55), "size": Vector3(1.8, 1.0, 0.8)})
		"werkbank":
			var table := level._place("table_medium_decorated_A", Vector3(0, 0, -0.2), 0.0, root)
			table.scale = Vector3.ONE * TABLE_SCALE
			var stool := level._place("stool", Vector3(0, 0, 0.75), PI, root)
			stool.scale = Vector3.ONE * TABLE_SCALE
			solids.append({"at": Vector3(0, 0, -0.2), "size": Vector3(1.6, 1.2, 1.6)})
		"feinbank", "schleifrad", "alchemie":
			# The bench of the crafting square faces east; turned so its front is the piece's front.
			var turn := Node3D.new()
			turn.rotation.y = -PI * 0.5
			turn.position = Vector3(0, 0, 0.5)
			root.add_child(turn)
			CraftingSquare.build_bench(turn, Vector3.ZERO, info.bench, hash("home bench:" + kind))
			solids.append({"at": Vector3(0, 0, 0), "size": Vector3(3.0, 1.2, 2.0)})
			station.craft = CraftingSquare.BENCHES[info.bench].craft
		"leuchter":
			var iron := HomeStoreFurniture._mat(Color(0.18, 0.17, 0.16), 0.5, 0.6)
			HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.35, 0.4, 0.06), iron, Vector3(0, 0.03, 0))
			HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.04, 0.05, 1.3), iron, Vector3(0, 0.68, 0))
			HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.25, 0.08, 0.06), iron, Vector3(0, 1.34, 0))
			level._place("candle_triple", Vector3(0, 1.37, 0), 0.0, root)
			_add_light(root, Vector3(0, 1.9, 0))
			solids.append({"at": Vector3.ZERO, "size": Vector3(0.6, 1.4, 0.6)})
		"fackel":
			var holder := Node3D.new()
			holder.position = Vector3(0, 1.45, -HouseSketch.CELL * 0.5 + 0.5)
			root.add_child(holder)
			level._place("torch_mounted", Vector3.ZERO, 0.0, holder)
			var flame := Effects.make_flame()
			flame.position = Vector3(0, 0.78, 0.45)
			flame.scale = Vector3.ONE * 0.8
			holder.add_child(flame)
			_add_light(holder, Vector3(0, 1.0, 0.8))
		"bild_berge", "bild_see", "bild_drache":
			_build_painting(root, int(info.painting))
	root.set_meta("solids", solids)
	return station


## A warm light like a wall torch's, a little softer, that flickers. Its place counts as lit at
## night (see Outdoor.is_lit and refresh).
func _add_light(parent: Node3D, at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "FurnitureLight"
	light.light_color = Level.TORCH_COLOUR
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = Level.TORCH_ATTENUATION
	light.position = at
	parent.add_child(light)
	var glow := light.create_tween().set_loops()
	glow.tween_property(light, "light_energy", LIGHT_ENERGY * 1.1, 0.25)
	glow.tween_property(light, "light_energy", LIGHT_ENERGY * 0.88, 0.32)


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


## The picture of a motif, painted once into a small texture: 0 the mountains at dusk, 1 a lake
## under the moon, 2 a dragon over the village.
static func _painting_texture(motif: int) -> ImageTexture:
	if _paintings.has(motif):
		return _paintings[motif]
	var w := 128
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var skies := [[Color(0.98, 0.62, 0.32), Color(0.42, 0.25, 0.45)], [Color(0.12, 0.16, 0.32), Color(0.03, 0.05, 0.14)],
			[Color(0.75, 0.82, 0.92), Color(0.45, 0.6, 0.85)]]
	var sky: Array = skies[motif]
	for y in h:
		for x in w:
			img.set_pixel(x, y, (sky[1] as Color).lerp(sky[0], float(y) / h))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + motif
	match motif:
		0:
			_disc(img, Vector2(92, 40), 11, Color(1.0, 0.85, 0.5))
			for m in [[20, 30, 46], [64, 22, 60], [108, 34, 42]]:
				_peak(img, m[0], m[1], m[2], Color(0.25, 0.2, 0.3), Color(0.92, 0.9, 0.95))
			_band(img, 76, h, Color(0.2, 0.32, 0.18), Color(0.12, 0.2, 0.1))
		1:
			_disc(img, Vector2(36, 24), 9, Color(0.95, 0.95, 0.85))
			for i in 40:
				img.set_pixel(rng.randi_range(0, w - 1), rng.randi_range(0, 50), Color(0.9, 0.9, 1.0))
			_peak(img, 90, 40, 70, Color(0.06, 0.08, 0.14), Color(0.06, 0.08, 0.14))
			_band(img, 62, h, Color(0.1, 0.18, 0.32), Color(0.04, 0.08, 0.18))
			for y in range(64, 92, 3):
				for x in range(32 - (y - 62) / 4, 40 + (y - 62) / 4):
					img.set_pixel(x, y, Color(0.75, 0.78, 0.7))
		2:
			_band(img, 70, h, Color(0.35, 0.5, 0.25), Color(0.25, 0.38, 0.18))
			for i in 5:
				var hx := 14 + i * 22
				img.fill_rect(Rect2i(hx, 58, 14, 14), Color(0.8, 0.72, 0.6))
				for r in 8:
					img.fill_rect(Rect2i(hx - 2 + r, 50 + r, 18 - r * 2, 1), Color(0.6, 0.2, 0.15))
			# The dragon: a red body and two wings against the sky.
			var red := Color(0.7, 0.12, 0.08)
			img.fill_rect(Rect2i(52, 26, 30, 6), red)
			img.fill_rect(Rect2i(80, 22, 8, 7), red)
			img.fill_rect(Rect2i(36, 30, 18, 3), red)
			for r in 14:
				img.fill_rect(Rect2i(58 + r / 2, 12 + r, 14 - r / 2, 1), red.darkened(0.2))
			_disc(img, Vector2(88, 24), 1, Color(1.0, 0.85, 0.3))
	# A few brush strokes of noise, so it looks painted rather than printed.
	for i in 600:
		var x := rng.randi_range(0, w - 2)
		var y := rng.randi_range(0, h - 1)
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(img.get_pixel(x + 1, y), 0.5).darkened(rng.randf_range(-0.06, 0.08)))
	var tex := ImageTexture.create_from_image(img)
	_paintings[motif] = tex
	return tex


static func _disc(img: Image, at: Vector2, r: int, colour: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r:
				var p := Vector2i(at) + Vector2i(x, y)
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
					img.set_pixelv(p, colour)


## A mountain peak at x with its top at `top` and half its foot `half` wide, snow on its tip.
static func _peak(img: Image, x0: int, top: int, half: int, rock: Color, snow: Color) -> void:
	for y in range(top, img.get_height()):
		var span := int(float(y - top) / (img.get_height() - top) * half * 2.0)
		for x in range(x0 - span, x0 + span + 1):
			if x >= 0 and x < img.get_width():
				img.set_pixel(x, y, snow if y < top + 8 else rock)


static func _band(img: Image, from_y: int, to_y: int, top: Color, bottom: Color) -> void:
	for y in range(from_y, to_y):
		for x in img.get_width():
			img.set_pixel(x, y, top.lerp(bottom, float(y - from_y) / maxf(1.0, to_y - from_y)))


## A trophy stand: an oak shelf on a low plinth with a back board and two small banners. Returns
## the node the statuettes stand on.
func _build_stand(root: Node3D) -> Node3D:
	var oak := StandardMaterial3D.new()
	oak.albedo_texture = load("res://assets/house/wood_floor.jpg")
	oak.albedo_color = Color(0.55, 0.38, 0.26)
	oak.roughness = 0.8
	var back := -HouseSketch.CELL * 0.5 + 0.1
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(1.8, 1.7, 0.08)), oak, Vector3(0, 1.75, back))
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(1.8, 0.9, 0.7)), oak, Vector3(0, 0.45, back + 0.4))
	for side: float in [-1.0, 1.0]:
		var banner: Node3D = game.level._place("banner_shield_brown", Vector3(side * 0.65, 1.3, back + 0.06), 0.0, root)
		banner.scale = Vector3.ONE * 0.35
	var shelf := Node3D.new()
	shelf.position = Vector3(0, 0.9, back + 0.4)
	root.add_child(shelf)
	return shelf


## Puts the books kept and the trophies won on the hero's shelves and stands.
func refresh_books() -> void:
	var count := HomeStores.total(game.home_stores, HomeStores.BOOKS)
	for shelf in _shelves:
		if is_instance_valid(shelf):
			Bookshelf.refresh_shelf(shelf, count)
	for stand: Node3D in _stands:
		if not is_instance_valid(stand):
			continue
		for child in stand.get_children():
			stand.remove_child(child)
			child.queue_free()
		var shown := HomeUpgrades.trophies_shown(game.trophies)
		for i in shown.size():
			var statue: Node3D = game.level._trophy_statue(shown[i])
			if statue == null:
				continue
			statue.scale = Vector3.ONE * 0.55
			statue.position.x = -0.75 + 1.5 * (i + 0.5) / shown.size()
			stand.add_child(statue)


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
	_hint = Lang.t("Einrichten: Möbel wählen, mit R oder Rechtsklick drehen, mit Linksklick abstellen.") if furniture.waiting() > 0 \
			else Lang.t("Keine Möbel zum Aufstellen. Raumausstatterin Ilse am Dorfplatz verkauft welche.")
	game.show_message(_hint, 4.0)
	_update_bar()


func leave() -> void:
	if not active:
		return
	active = false
	game.frame_pull = 0.0
	_bar.visible = false
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
	_clear_ghost()
	_update_bar()


func turn() -> void:
	rot = (rot + 1) % 4
	var cell := _hover_cell
	_clear_ghost()
	_hover_cell = cell
	if _hover_cell.x >= 0:
		_show_ghost()


func cycle_level() -> void:
	storey = {0: 1, 1: -1, -1: 0}[storey]
	game.house_sketcher.view_storey = storey
	_clear_ghost()
	_update_bar()


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
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			turn()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			var spot = floor_point(event.position)
			if spot != null:
				click(spot)
			return true
	return false


## The point on the shown storey's floor under a point of the screen, or null.
func floor_point(screen: Vector2):
	var cam: Camera3D = game.camera
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if dir.y > -0.01:
		return null
	var y: float = HouseFurniture.FLOORS[storey]
	return origin + dir * ((y - origin.y) / dir.y)


## The north-west cell of the chosen piece with its middle under a floor point.
func _anchor(point: Vector3) -> Vector2i:
	var house := plan()
	var f := HouseFurniture.footprint(tool, rot)
	var origin := house.node_world(0, 0)
	var fx := (point.x - origin.x) / HouseSketch.CELL - f.x * 0.5
	var fz := (point.z - origin.z) / HouseSketch.CELL - f.y * 0.5
	return Vector2i(roundi(fx), roundi(fz))


func hover(point: Vector3) -> void:
	var house := plan()
	if house == null:
		return
	if tool == PICK_UP:
		var c := house.cell_at(point)
		var i := furniture.piece_at(storey, c)
		_hover_cell = c
		_clear_ghost()
		if i >= 0:
			var p: Dictionary = furniture.placed[i]
			_footprint_marker(house, p.kind, p.x, p.y, p.rot, BAD_COLOR)
			_say(Lang.t("Klicken, um %s aufzuheben.") % Lang.t(HouseFurniture.KINDS[p.kind].name))
		else:
			_say(Lang.t("Klicke ein Möbelstück an, um es aufzuheben."))
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
	if furniture.count(tool) <= 0:
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
		var i := furniture.piece_at(storey, house.cell_at(point))
		if i < 0:
			return
		var kind := furniture.pick_up(i)
		furniture.save(game.hero_name)
		Sfx.play(game, "gear_soft_0", -4.0)
		_say(Lang.t("%s aufgehoben: Es steht wieder zum Aufstellen bereit.") % Lang.t(HouseFurniture.KINDS[kind].name))
		tool = kind
		refresh()
		_update_bar()
		return
	if tool == "":
		return
	hover(point)
	var why := furniture.place(house, tool, storey, _hover_cell.x, _hover_cell.y, rot)
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
	# Rows 1 and 2: the pieces, each with the number waiting to be put down; light and the walls
	# on the second row.
	var kinds := _row(box)
	var lights := _row(box)
	for kind in HouseFurniture.KINDS:
		var b := _small_button("", select.bind(kind), KIND_BUTTON.x)
		b.tooltip_text = Lang.t(HouseFurniture.KINDS[kind].name)
		(lights if kind in SECOND_ROW else kinds).add_child(b)
		_kind_buttons[kind] = b
	# Row 3: the storey, turning, picking up, back to the blueprint, close.
	var options := _row(box)
	_level_button = _small_button("", cycle_level, 250)
	options.add_child(_level_button)
	_turn_button = _small_button(Lang.t("Drehen (R)"), turn, 130)
	options.add_child(_turn_button)
	_pick_button = _small_button(Lang.t("Aufheben"), select.bind(PICK_UP), 130)
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
	_turn_button.disabled = tool == PICK_UP
	_level_button.text = Lang.t("Ebene: %s") % Lang.t(LEVEL_NAMES[storey])
	_status.text = _hint


## Shows a tool button as chosen (like the blueprint tool's).
func _mark(b: Button, on: bool) -> void:
	b.add_theme_color_override("font_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
	b.add_theme_color_override("font_hover_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
	if not b.has_meta("normal"):
		b.set_meta("normal", b.get_theme_stylebox("normal"))
	b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed") if on else b.get_meta("normal"))
