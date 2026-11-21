class_name LostMine
extends RefCounted
## The forgotten silver mine under the woods south of the village pond: an empty
## foreman's hut at the forest's edge, a shaft in its floor with a ladder, and
## below it the tunnels a dozen miners cut and then left. It is not a level of
## its own: like a hero's self-built house (see HouseSketch), it is a house
## sketch drawn on the open-air map by HouseSketcher, every piece already built.
## Its cells are dug cellar cells, 2 m wide like the tunnels; all but the shaft
## lie under the ground, closed by a buried ceiling (HouseSketch.BURIED): the
## grass and the forest stay whole on top, and down there the surface hides as
## in any cellar (see CellarView).
##
## The layout is LAYOUT, one letter per 2 m cell of the plot (PLOT, in map
## tiles), drawn under the forest so no plot can ever be marked out over it:
##   " "  solid earth
##   "."  a tunnel or room of the miners: earthen floor, plank walls
##   "L"  the shaft under the hut: the ladder stands in it (up to the north)
##   "r"  the rock cleft the miners broke into: earthen floor, raw rock walls
##   "s"  the old hewn works, older than the village: flagstones, stone walls
##   "D"  the end of the old works: the sealed gate stands on its north side
##   "x"  a caved-in drift, dug but choked with rubble
##
## The foreman's log lies about in six pages (NOTES), one in each room, and
## tells what happened; the last one lies in a niche near the gate at the end.
## The gate does not open (yet): it is where the story goes on later.
## Everything down there is built once (see build) and shown only while the
## hero is down in a cellar (see HouseSketcher.deep).

## The plot the mine is drawn on (map tiles): the woods south-west of the pond.
const PLOT := Rect2i(1, 22, 36, 24)
## One string per row of cells, one letter per cell (see the class notes).
const LAYOUT := [
	"                                                                        ",
	"                                                                        ",
	"                                                                        ",
	"            D                                                           ",
	"            s                                                           ",
	"            s                                                           ",
	"            s                                                           ",
	"            s                                                           ",
	"            s                                                           ",
	"          sssss                                                         ",
	"          sssss   sss                                                   ",
	"          sssssssssss                                                   ",
	"          sssss   sss                                                   ",
	"            s                                                           ",
	"            s                                                           ",
	"            s                                                           ",
	"            r                                                           ",
	"            r                                                           ",
	"            r                                                           ",
	"        rrrrr                                                           ",
	"        r                                                               ",
	"        r                                                               ",
	"        r                                                               ",
	"        r                                                               ",
	"        rrr                                                             ",
	"          r                                                             ",
	"          r                                                             ",
	"          .                               L                             ",
	"          .             .......           .                             ",
	"          .             .......           . ....                        ",
	"          .                .              . ....                        ",
	"    ............................................                        ",
	"    .               .              .        ....                        ",
	"  .....             .            .....        .                         ",
	"  .....             .            .....        ............              ",
	"  .....             .            .....                   .              ",
	"  .....             .            .....                   .              ",
	"    .               .                                  ......           ",
	"    .               .                                  ..........       ",
	"    .               .                                  ......   .       ",
	"    .               .                                  ......   .       ",
	"    .               .                                           .       ",
	"    .................                                           .       ",
	"                                                                .       ",
	"                                                            xxxxx       ",
	"                                                                        ",
	"                                                                        ",
	"                                                                        ",
]
## The raw rock of the cleft, a wall surface of the mine alone (see HouseSketcher._wall_material).
const ROCK := "rock"
## The letters of dug cells, and the floor and wall each gets (HouseSketch.SURFACES, and ROCK).
const DUG := {".": ["", "wood"], "L": ["", "wood"], "x": ["", "wood"], "r": ["", ROCK], "s": ["stone", "stone"], "D": ["stone", "stone"]}
## The empty hut over the shaft (cells of the plot): its floor, roof and walls.
const HUT := Rect2i(40, 25, 3, 3)
## The shaft: the ladder's foot, open to the hut above; the ladder leads up towards LADDER_DIR.
const SHAFT := Vector2i(42, 27)
const LADDER_DIR := "n"
## Where the sealed gate stands: on the north side of this cell.
const GATE_CELL := Vector2i(12, 3)

## Station kinds: a page of the foreman's log, the sealed gate.
const NOTE := "grubenbuch"
const GATE := "grubentor"
const KINDS := [NOTE, GATE]

## The compendium's entry, learnt the first time the hero climbs down.
const LEARN := "Die vergessene Silbergrube: Unter der leeren Steigerhütte am Waldrand südlich des Dorfteichs führt eine Leiter in die Stollen, die zwölf Bergleute unter dem Wald gruben und dann verließen. Die Seiten des Steigerbuchs erzählen, warum."
const ENTERED := "Du steigst in eine vergessene Silbergrube hinab. Irgendwo hier unten liegen die Seiten eines Steigerbuchs."
## The foreman's log, page by page, and the cell each page lies in.
const NOTES := [
	["Steigerbuch, erster Tag: Unter dem Wald südlich des Dorfteichs haben wir Silber gefunden. Zwölf Mann, gutes Grubenholz und eine Hütte über dem Schacht. Wir werden reich, sagt Jorin. (Steiger Aldo Brenner)", Vector2i(45, 30)],
	["Steigerbuch, vierzigster Tag: Nachts klopft es im Fels. Drei Schläge, dann Stille. Die Männer sagen, das ist das Wasser. Wasser zählt nicht bis drei.", Vector2i(34, 34)],
	["Steigerbuch, zweiundfünfzigster Tag: Die Ader führt nach Westen, tiefer als jede Karte. Hinter dem Silber ist der Fels behauen, glatt wie Tempelstein. Jemand hat hier vor uns gegraben, lange vor dem Dorf.", Vector2i(24, 28)],
	["Steigerbuch, sechzigster Tag: Der Oststollen ist eingebrochen. Jorin und Matthes waren dahinter. Wir graben seit zwei Tagen. Das Klopfen ist lauter als unsere Hacken.", Vector2i(64, 42)],
	["Steigerbuch, einundsiebzigster Tag: Nur noch vier von uns. Wir haben eine Nische für die Göttin der Tiefe ausgehauen und Kerzen entzündet. Sie antwortet nicht. Das Tor antwortet.", Vector2i(2, 34)],
	["Letzter Eintrag: Ich habe das Tor am Ende der alten Gänge mit Eisen verkeilt und die Männer heimgeschickt. Wer dies findet: Öffne es nicht, ehe du weißt, wer auf der anderen Seite klopft. (A. Brenner)", Vector2i(20, 11)],
]
## What the gate says: the first time (kept in the compendium), and every time after.
const GATE_FIRST := "Ein steinernes Tor, alt wie der Berg, mit eisernen Keilen verschlossen. Es rührt sich nicht. Von der anderen Seite klopft es dreimal."
const GATE_AGAIN := "Das Tor ist fest verschlossen. Noch."

## Where the miners' lamps hang (cells).
const LAMPS := [Vector2i(42, 30), Vector2i(46, 31), Vector2i(35, 35), Vector2i(31, 31), Vector2i(27, 29),
	Vector2i(20, 31), Vector2i(12, 31), Vector2i(20, 38), Vector2i(12, 42), Vector2i(4, 35), Vector2i(52, 34),
	Vector2i(58, 39), Vector2i(64, 40), Vector2i(10, 28)]
const LAMP_COLOUR := Color(1.0, 0.68, 0.36)
const LAMP_ENERGY := 2.6
const LAMP_RANGE := 8.5
## The pale light of the old works' runes, cold and faint.
const RUNE_COLOUR := Color(0.45, 0.62, 1.0)
const TIMBER := Color(0.34, 0.23, 0.13)
const IRON := Color(0.22, 0.22, 0.24)
const SILVER := Color(0.82, 0.85, 0.9)
## Every this many cells along a straight tunnel stands a timber set (two posts and a cap).
const SET_EVERY := 3
## How high the cap of a timber set lies over the floor.
const CAP_HIGH := 2.2

static var _sketch: HouseSketch = null
static var _cells := {}
static var _mats := {}
static var _surface: Array = []
static var _inside := {}


## Every dug cell of the mine: Vector2i (plot cells) -> its LAYOUT letter.
static func cells() -> Dictionary:
	if _cells.is_empty():
		for y in LAYOUT.size():
			var row: String = LAYOUT[y]
			for x in row.length():
				if DUG.has(row[x]):
					_cells[Vector2i(x, y)] = row[x]
	return _cells


## The mine as a house sketch, every piece built: dug cells with their surfaces,
## the buried ceiling over all of them but the shaft, the ladder, and the hut on top.
static func sketch() -> HouseSketch:
	if _sketch != null:
		return _sketch
	var s := HouseSketch.new()
	s.plot = PLOT
	var built := HouseSketch.BUILT
	for c: Vector2i in cells():
		var look: Array = DUG[cells()[c]]
		s.pieces[HouseSketch.key_of(c.x, c.y, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.DIG, "state": built, "floor": look[0], "wall": look[1]}
		if c != SHAFT:
			s.pieces[HouseSketch.key_of(c.x, c.y, HouseSketch.COVER_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.COVER, "state": built, "surface": HouseSketch.BURIED}
	s.pieces[HouseSketch.key_of(SHAFT.x, SHAFT.y, HouseSketch.LADDER_ORIENTS[LADDER_DIR], HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.LADDER, "state": built}
	# The hut: a wooden floor and a pitched roof over its cells (no floor over the shaft: it stays open).
	for y in range(HUT.position.y, HUT.end.y):
		for x in range(HUT.position.x, HUT.end.x):
			if Vector2i(x, y) != SHAFT:
				s.pieces[HouseSketch.key_of(x, y, HouseSketch.COVER_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.COVER, "state": built, "surface": "wood"}
			s.pieces[HouseSketch.key_of(x, y, "rx", 0)] = {"kind": HouseSketch.SADDLE, "state": built}
	# Its walls, a door to the north (towards the path by the pond) with a window either side.
	for x in range(HUT.position.x, HUT.end.x):
		s.pieces[HouseSketch.key_of(x, HUT.position.y, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.WALL, "state": built}
		s.pieces[HouseSketch.key_of(x, HUT.end.y, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.WALL, "state": built}
	for y in range(HUT.position.y, HUT.end.y):
		s.pieces[HouseSketch.key_of(HUT.position.x, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": built}
		s.pieces[HouseSketch.key_of(HUT.end.x, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": built}
	var middle := HUT.position + HUT.size / 2
	s.pieces[HouseSketch.key_of(middle.x, HUT.position.y, HouseSketch.ORIENT_X)].kind = HouseSketch.DOOR
	s.pieces[HouseSketch.key_of(HUT.position.x, HUT.position.y, HouseSketch.ORIENT_X)].kind = HouseSketch.WINDOW
	s.pieces[HouseSketch.key_of(HUT.end.x - 1, HUT.position.y, HouseSketch.ORIENT_X)].kind = HouseSketch.WINDOW
	# Companions find floors round the hut only (see HouseFloors): the tunnels' cells are theirs anyway.
	s.floors_area = HUT
	_sketch = s
	return s


## The keys of the pieces above the ground and the ladder: the hut (see HouseSketcher._redraw,
## which draws the dug cells once and these every time).
static func surface_keys() -> Array:
	if not _surface.is_empty():
		return _surface
	var s := sketch()
	for key in s.pieces:
		var kind: String = s.pieces[key].kind
		if kind != HouseSketch.DIG and kind != HouseSketch.COVER:
			_surface.append(key)
	return _surface


## The cells inside the hut's walls (see HouseGround.inside_cells), worked out once.
static func hut_inside() -> Dictionary:
	if _inside.is_empty():
		_inside = HouseGround.inside_cells(sketch())
	return _inside


## Whether map tile `c` lies over the mine or its hut: no plot may be marked out there (see Plots.problem).
static func covers_tile(c: Vector2i) -> bool:
	if not PLOT.has_point(c):
		return false
	var first := (c - PLOT.position) * HouseSketch.CELLS_PER_TILE
	for dy in HouseSketch.CELLS_PER_TILE:
		for dx in HouseSketch.CELLS_PER_TILE:
			var cell := first + Vector2i(dx, dy)
			if cells().has(cell) or HUT.has_point(cell):
				return true
	return false


## The mine's cell under a world point (plot cells), whether or not it is dug.
static func cell_at(pos: Vector3) -> Vector2i:
	var origin := sketch().node_world(0, 0)
	return Vector2i(floori((pos.x - origin.x) / HouseSketch.CELL), floori((pos.z - origin.z) / HouseSketch.CELL))


## Whether a world point lies down in the mine (below the ground, within its cells).
static func holds(pos: Vector3) -> bool:
	return pos.y < -1.0 and cells().has(cell_at(pos))


## The middle of a cell's floor, down in the mine.
static func floor_at(c: Vector2i) -> Vector3:
	return sketch().cell_world(c.x, c.y) + Vector3(0, -HouseSketch.DEPTH, 0)


## Hints under the hero's feet for the mine's stations (see Game._prompt), "" for any other kind.
static func prompt(kind: String) -> String:
	match kind:
		NOTE:
			return Lang.t("Dagegenlaufen, um die Seite des Steigerbuchs zu lesen")
		GATE:
			return Lang.t("Dagegenlaufen, um das Tor zu untersuchen")
	return ""


## The hero ran into a page of the log or the gate: it is read out (and the first time
## it goes into the compendium and trains Erkunden, like a writing on a wall).
static func use(game: Node, s: Dictionary) -> void:
	var entry: String = s.get("text", GATE_FIRST)
	var text := entry
	if s.kind == GATE:
		Sfx.play(game, "thunder", -20.0)
		if game.lore.has(GATE_FIRST):
			text = GATE_AGAIN
	if not game.lore.has(entry):
		game.player.train("erkunden", Training.EXPLORE_WRITING_FOUND)
		Sfx.play(game, "secret", -8.0)
		Events.teach(entry)
	var said := Lang.t(text)
	game.show_message(said, maxf(6.0, 1.0 + 0.06 * said.length()), Color(1.0, 0.88, 0.62))


## Down for the first time: the compendium learns of the mine.
static func entered(game: Node) -> void:
	if game.lore.has(LEARN):
		return
	Events.teach(LEARN)
	Events.tell(Lang.t(ENTERED), Color(1.0, 0.82, 0.4))


# --- What lies about down there ---------------------------------------------

## Builds everything in the mine that is no part of the sketch, under `parent`
## (shown only while the hero is down there): timber sets along the tunnels, the
## lamps, the furniture of each room, the pages of the log, the chests, the cave-in
## and the sealed gate. The stations and chests go onto `level`.
static func build(level: Level, parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("vergessene_grube")
	var body := StaticBody3D.new()
	body.name = "MineSolids"
	parent.add_child(body)
	_timber_sets(parent)
	for c: Vector2i in LAMPS:
		_lamp(parent, c)
	_tool_store(level, parent, body)
	_bunk_room(level, parent, body)
	_silver_vein(parent, body, rng)
	_haulage(parent, body)
	_cave_in(parent, body, rng)
	_shrine(level, parent, body)
	_old_works(level, parent, body, rng)
	for i in NOTES.size():
		_page(level, parent, body, NOTES[i][1], NOTES[i][0], i)
	_gate(level, parent, body)


## The raw rock of the cleft's walls: grey stone, rough and cracked, laid in world space so it
## runs on from one wall panel to the next.
static func rock_material() -> StandardMaterial3D:
	if _mats.has("rock_wall"):
		return _mats["rock_wall"]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	noise.seed = 7
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.color_ramp = Gradient.new()
	tex.color_ramp.set_color(0, Color(0.2, 0.19, 0.18))
	tex.color_ramp.set_color(1, Color(0.5, 0.47, 0.43))
	var bumps := NoiseTexture2D.new()
	bumps.noise = noise
	bumps.seamless = true
	bumps.width = 256
	bumps.height = 256
	bumps.as_normal_map = true
	bumps.bump_strength = 6.0
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = bumps
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	_mats["rock_wall"] = m
	return m


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


static func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material, turn := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = at
	m.rotation.y = turn
	parent.add_child(m)
	return m


static func _solid(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


static func _open(c: Vector2i) -> bool:
	return cells().has(c) and cells()[c] != "x"


## Timber sets along the miners' tunnels: where a straight tunnel runs between two
## walls, every SET_EVERY cells two posts against the walls carry a cap across.
static func _timber_sets(parent: Node3D) -> void:
	var wood := _mat("timber", TIMBER)
	for c: Vector2i in cells():
		if cells()[c] != "." or c == SHAFT:
			continue
		var along_z := _open(c + Vector2i(0, 1)) and _open(c + Vector2i(0, -1)) and not _open(c + Vector2i(1, 0)) and not _open(c + Vector2i(-1, 0))
		var along_x := _open(c + Vector2i(1, 0)) and _open(c + Vector2i(-1, 0)) and not _open(c + Vector2i(0, 1)) and not _open(c + Vector2i(0, -1))
		if not (along_z and c.y % SET_EVERY == 0) and not (along_x and c.x % SET_EVERY == 0):
			continue
		var mid := floor_at(c)
		var across := Vector3(1, 0, 0) if along_z else Vector3(0, 0, 1)
		var thick := Vector3(0, 0, 0.24) if along_z else Vector3(0.24, 0, 0)
		for side in [-1.0, 1.0]:
			_box(parent, mid + across * side * 0.76 + Vector3(0, CAP_HIGH * 0.5, 0), Vector3(0.22, CAP_HIGH, 0.22), wood)
		_box(parent, mid + Vector3(0, CAP_HIGH + 0.11, 0), across * 1.76 + thick + Vector3(0, 0.22, 0), wood)


## A miner's lamp hanging from a hook in the roof: an iron cage round a warm glow.
static func _lamp(parent: Node3D, c: Vector2i) -> void:
	var at := floor_at(c) + Vector3(0, 1.95, 0)
	var iron := _mat("iron", IRON, 0.6)
	_box(parent, at + Vector3(0, 0.35, 0), Vector3(0.03, 0.4, 0.03), iron)
	_box(parent, at, Vector3(0.22, 0.28, 0.22), _mat("lamp_glass", LAMP_COLOUR, 0.0, 2.5))
	_box(parent, at + Vector3(0, 0.16, 0), Vector3(0.3, 0.05, 0.3), iron)
	_box(parent, at - Vector3(0, 0.16, 0), Vector3(0.3, 0.05, 0.3), iron)
	var light := OmniLight3D.new()
	light.light_color = LAMP_COLOUR
	light.light_energy = LAMP_ENERGY
	light.omni_range = LAMP_RANGE
	light.position = at - Vector3(0, 0.1, 0)
	parent.add_child(light)


## A chest to search (see Level.search), its loot rolled like any dungeon chest's.
static func _chest(level: Level, parent: Node3D, body: StaticBody3D, c: Vector2i, offset: Vector3, turn: float) -> void:
	var pos := floor_at(c) + offset
	var chest := FittedChest.place(parent, "oak", pos, turn)
	_solid(body, pos + Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 1.2))
	var obj: Dictionary = level._add_interactable("Truhe", pos, pos + Vector3(0, 2.0, 0), level.world_to_cell(pos))
	obj.id = "grube:%d,%d" % [c.x, c.y]
	obj.lid = FittedChest.lid_of(chest)
	if level.taken.has(obj.id):
		obj.searched = true
		if obj.lid:
			obj.lid.rotation.x -= obj.get("lid_open", Level.LID_OPEN)


## A dungeon kit piece (see Level._place) with a solid box round its foot.
static func _piece(level: Level, parent: Node3D, body: StaticBody3D, piece: String, at: Vector3, turn: float, foot: Vector2, high := 1.2) -> Node3D:
	var node := level._place(piece, at, turn, parent)
	if foot != Vector2.ZERO:
		_solid(body, at + Vector3(0, high * 0.5, 0), Vector3(foot.x, high, foot.y))
	return node


## The tool store east of the shaft: crates, barrels, a rack of picks and the first page.
static func _tool_store(level: Level, parent: Node3D, body: StaticBody3D) -> void:
	_piece(level, parent, body, "crates_stacked", floor_at(Vector2i(47, 29)) + Vector3(0.2, 0, -0.2), 0.3, Vector2(1.4, 1.4), 1.8)
	_piece(level, parent, body, "barrel_small", floor_at(Vector2i(44, 32)) + Vector3(-0.4, 0, 0.4), 0.0, Vector2(0.8, 0.8))
	_piece(level, parent, body, "barrel_small", floor_at(Vector2i(45, 32)) + Vector3(-0.3, 0, 0.5), 1.0, Vector2(0.8, 0.8))
	_piece(level, parent, body, "box_large", floor_at(Vector2i(47, 31)) + Vector3(0.3, 0, 0), 0.2, Vector2(1.2, 1.2))
	# A rack of picks and shovels against the south wall.
	var wood := _mat("timber", TIMBER)
	var iron := _mat("iron", IRON, 0.6)
	var rack := floor_at(Vector2i(46, 32)) + Vector3(0, 0, 0.72)
	_box(parent, rack + Vector3(0, 1.3, 0), Vector3(1.6, 0.08, 0.12), wood)
	for i in 4:
		var x := -0.6 + i * 0.4
		var handle := _box(parent, rack + Vector3(x, 0.75, -0.08), Vector3(0.06, 1.4, 0.06), wood)
		handle.rotation.z = 0.08
		_box(parent, rack + Vector3(x + 0.05, 1.42, -0.08), Vector3(0.5 if i % 2 == 0 else 0.22, 0.07, 0.07), iron)
	_solid(body, rack + Vector3(0, 0.8, -0.1), Vector3(1.7, 1.6, 0.4))
	_chest(level, parent, body, Vector2i(44, 29), Vector3(-0.2, 0, -0.2), PI * 0.5)


## The bunk room: plank beds along the walls, a table with a candle and the second page.
static func _bunk_room(level: Level, parent: Node3D, body: StaticBody3D) -> void:
	var wood := _mat("timber", TIMBER)
	var straw := _mat("straw", Color(0.55, 0.45, 0.25))
	var blanket := _mat("blanket", Color(0.35, 0.2, 0.16))
	# Three plank beds along the walls, head to the north.
	for mid: Vector3 in [floor_at(Vector2i(37, 34)) + Vector3(0.45, 0, 0.5), floor_at(Vector2i(37, 36)) + Vector3(0.45, 0, -0.2),
			floor_at(Vector2i(33, 36)) + Vector3(-0.45, 0, -0.3)]:
		var long := Vector3(0.9, 0, 1.9)
		_box(parent, mid + Vector3(0, 0.3, 0), long + Vector3(0, 0.1, 0), wood)
		_box(parent, mid + Vector3(0, 0.4, 0), long * 0.92 + Vector3(0, 0.1, 0), straw)
		_box(parent, mid + Vector3(0, 0.47, 0.25), Vector3(0.86, 0.05, 1.1), blanket, 0.03)
		_box(parent, mid + Vector3(0, 0.48, -0.7), Vector3(0.5, 0.1, 0.3), straw)
		for leg in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
			_box(parent, mid + Vector3(leg.x * 0.38, 0.13, leg.z * 0.86), Vector3(0.08, 0.26, 0.08), wood)
		_solid(body, mid + Vector3(0, 0.3, 0), long + Vector3(0, 0.6, 0))
	_piece(level, parent, body, "table_medium_decorated_A", floor_at(Vector2i(34, 34)), PI * 0.5, Vector2(1.4, 1.8), 1.0)
	_piece(level, parent, body, "stool", floor_at(Vector2i(35, 34)) + Vector3(0.2, 0, 0), 0.4, Vector2.ZERO)
	_chest(level, parent, body, Vector2i(37, 33), Vector3(0.2, 0, -0.2), PI)


## The silver vein: bright streaks in the north wall of the chamber over the gallery,
## a pick left in the rock and broken stone on the floor.
static func _silver_vein(parent: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var silver := _mat("silver", SILVER, 0.9, 0.25)
	for x in range(24, 31):
		var wall := floor_at(Vector2i(x, 28)) + Vector3(0, 0, -0.89)
		for i in 3:
			var streak := _box(parent, wall + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.5, 2.0), 0.0), Vector3(rng.randf_range(0.3, 0.9), rng.randf_range(0.04, 0.1), 0.06), silver)
			streak.rotation.z = rng.randf_range(-0.4, 0.4)
	var rock := _mat("rubble", Color(0.36, 0.33, 0.3))
	for i in 12:
		var c := Vector2i(rng.randi_range(25, 30), rng.randi_range(28, 29))
		var lump := _box(parent, floor_at(c) + Vector3(rng.randf_range(-0.7, 0.7), 0.08, rng.randf_range(-0.7, 0.7)), Vector3.ONE * rng.randf_range(0.12, 0.3), rock)
		lump.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
	# A pick stuck in the vein.
	var pick := floor_at(Vector2i(28, 28)) + Vector3(0.2, 0, -0.55)
	var handle := _box(parent, pick + Vector3(0, 1.1, 0.2), Vector3(0.06, 0.06, 0.9), _mat("timber", TIMBER))
	handle.rotation.x = -0.5
	_box(parent, pick + Vector3(0, 1.3, -0.2), Vector3(0.07, 0.5, 0.07), _mat("iron", IRON, 0.6))
	# The page lies on an upturned barrel.
	var barrel := floor_at(Vector2i(24, 28))
	_box(parent, barrel + Vector3(0, 0.4, 0), Vector3(0.7, 0.8, 0.7), _mat("timber", TIMBER))
	_solid(body, barrel + Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8))


## Rails from the tool store along the haulage way to the cart chamber, and a cart full of ore.
static func _haulage(parent: Node3D, body: StaticBody3D) -> void:
	var iron := _mat("rail", Color(0.3, 0.27, 0.25), 0.7)
	var wood := _mat("sleeper", TIMBER.darkened(0.25))
	var run: Array[Vector2i] = []
	for x in range(46, 57):
		run.append(Vector2i(x, 34))
	for y in range(34, 40):
		run.append(Vector2i(57, y))
	for c in run:
		var mid := floor_at(c)
		var along_x := c.x != 57
		var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		var across := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
		for k in 3:
			_box(parent, mid + axis * (-0.66 + k * 0.66) + Vector3(0, 0.03, 0), across * 1.1 + axis * 0.18 + Vector3(0, 0.06, 0), wood)
		for side in [-0.38, 0.38]:
			_box(parent, mid + across * side + Vector3(0, 0.09, 0), axis * 2.0 + across * 0.07 + Vector3(0, 0.07, 0), iron)
	# The cart at the end of the rails.
	var cart := floor_at(Vector2i(57, 38))
	_box(parent, cart + Vector3(0, 0.65, 0), Vector3(1.1, 0.7, 1.5), _mat("cart", TIMBER.lightened(0.05)))
	_box(parent, cart + Vector3(0, 0.98, 0), Vector3(0.95, 0.06, 1.35), _mat("ore", Color(0.3, 0.29, 0.3)))
	var silver := _mat("silver", SILVER, 0.9, 0.25)
	for i in 6:
		_box(parent, cart + Vector3(-0.3 + (i % 3) * 0.3, 1.03, -0.4 + (i / 3) * 0.7), Vector3(0.16, 0.1, 0.14), silver)
	for corner in [Vector3(-0.58, 0.25, -0.5), Vector3(0.58, 0.25, -0.5), Vector3(-0.58, 0.25, 0.5), Vector3(0.58, 0.25, 0.5)]:
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.22
		cyl.bottom_radius = 0.22
		cyl.height = 0.08
		wheel.mesh = cyl
		wheel.material_override = _mat("iron", IRON, 0.6)
		wheel.position = cart + corner
		wheel.rotation.z = PI * 0.5
		parent.add_child(wheel)
	_solid(body, cart + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.6))
	# A heap of ore waiting to be loaded, with a glint of silver in it.
	var ore := _mat("ore", Color(0.3, 0.29, 0.3))
	var heap := floor_at(Vector2i(60, 40)) + Vector3(0.2, 0, 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 14:
		var lump := _box(parent, heap + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.1, 0.5), rng.randf_range(-0.6, 0.6)), Vector3.ONE * rng.randf_range(0.2, 0.45), ore if i % 4 else silver)
		lump.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
	_solid(body, heap + Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 1.4))


## The caved-in east drift: rubble fills it from wall to wall; nobody gets past.
static func _cave_in(parent: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var rock := _mat("rubble_dark", Color(0.22, 0.2, 0.19))
	var earth := _mat("spoil", Color(0.26, 0.19, 0.13))
	for c: Vector2i in cells():
		if cells()[c] != "x":
			continue
		var mid := floor_at(c)
		_solid(body, mid + Vector3(0, 1.3, 0), Vector3(2.0, 2.6, 2.0))
		_box(parent, mid + Vector3(0, 0.9, 0), Vector3(1.9, 1.8, 1.9), earth, rng.randf_range(-0.1, 0.1))
		for i in 7:
			var stone := _box(parent, mid + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.2, 2.3), rng.randf_range(-0.8, 0.8)), Vector3.ONE * rng.randf_range(0.35, 0.8), rock)
			stone.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
	# A broken timber set lying askew in front of the rubble, and what is left of a miner.
	var front := floor_at(Vector2i(64, 43))
	var post := _box(parent, front + Vector3(-0.4, 0.5, 0.3), Vector3(0.22, 1.9, 0.22), _mat("timber", TIMBER))
	post.rotation.z = 1.0
	_box(parent, front + Vector3(0.2, 0.25, -0.2), Vector3(1.6, 0.22, 0.26), _mat("timber", TIMBER), 0.5)
	DungeonLife.bone_pile(parent, front + Vector3(0.5, 0, 0.5), rng, 1.0)
	# The page lies on a crate the miners dragged here.
	var crate := floor_at(Vector2i(64, 42))
	_box(parent, crate + Vector3(0, 0.35, 0), Vector3(0.8, 0.7, 0.8), _mat("timber", TIMBER))
	_solid(body, crate + Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.9))


## The miners' shrine to the goddess of the deep: an altar with candles, offerings
## and a small figure, the fifth page on a stool beside it.
static func _shrine(level: Level, parent: Node3D, body: StaticBody3D) -> void:
	var stone := HouseLooks.temple_stone()
	var altar := floor_at(Vector2i(4, 33)) + Vector3(0, 0, -0.3)
	_box(parent, altar + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.9), stone)
	_solid(body, altar + Vector3(0, 0.5, 0), Vector3(1.9, 1.0, 1.0))
	# The goddess: a rough stone figure with a pale glint for a face.
	_box(parent, altar + Vector3(0, 1.35, -0.1), Vector3(0.35, 0.7, 0.3), stone)
	_box(parent, altar + Vector3(0, 1.82, -0.1), Vector3(0.24, 0.26, 0.24), stone)
	_box(parent, altar + Vector3(0, 1.84, 0.03), Vector3(0.14, 0.05, 0.02), _mat("rune", RUNE_COLOUR, 0.0, 3.0))
	for x in [-0.65, 0.65]:
		level._place("candle_triple", altar + Vector3(x, 1.0, 0.1), 0.0, parent)
	var coins := level._place("coin_stack_large", altar + Vector3(0.3, 1.0, 0.25), 0.4, parent)
	coins.scale = Vector3.ONE * 0.45
	_piece(level, parent, body, "stool", floor_at(Vector2i(2, 34)), 0.0, Vector2(0.8, 0.8), 0.7)
	_chest(level, parent, body, Vector2i(6, 36), Vector3(0.2, 0, 0.2), -PI * 0.5)


## The old works: hewn columns in the antechamber, a dead man in the side niche and
## runes along the way to the gate.
static func _old_works(level: Level, parent: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	# Four hewn columns in the corners of the antechamber, each with a plinth and a capital.
	var stone := HouseLooks.temple_stone()
	for c in [Vector2i(10, 9), Vector2i(14, 9), Vector2i(10, 12), Vector2i(14, 12)]:
		var at: Vector3 = floor_at(c) + Vector3(0.45 * (-1.0 if c.x == 10 else 1.0), 0, 0.45 * (-1.0 if c.y == 9 else 1.0))
		_box(parent, at + Vector3(0, 0.1, 0), Vector3(0.8, 0.2, 0.8), stone)
		_box(parent, at + Vector3(0, 1.25, 0), Vector3(0.55, 2.1, 0.55), stone)
		_box(parent, at + Vector3(0, 2.4, 0), Vector3(0.8, 0.2, 0.8), stone)
		_solid(body, at + Vector3(0, 1.3, 0), Vector3(0.8, 2.6, 0.8))
	# A cold glow in the middle of the floor: a rune cut into the flagstones.
	var mid := (floor_at(Vector2i(12, 10)) + floor_at(Vector2i(12, 11))) * 0.5
	for i in 6:
		_box(parent, mid + Vector3(0, 0.012, 0), Vector3(0.9, 0.006, 0.06), _mat("rune", RUNE_COLOUR, 0.0, 3.0), float(i) * PI / 6.0)
	var hum := OmniLight3D.new()
	hum.light_color = RUNE_COLOUR
	hum.light_energy = 0.6
	hum.omni_range = 4.5
	hum.position = mid + Vector3(0, 0.6, 0)
	parent.add_child(hum)
	var glow := _mat("rune", RUNE_COLOUR, 0.0, 3.0)
	# Runes cut into the walls of the corridor to the gate, faintly glowing.
	for y in range(4, 9):
		var side := -1.0 if y % 2 == 0 else 1.0
		var at := floor_at(Vector2i(12, y)) + Vector3(side * 0.89, 1.5, 0)
		_box(parent, at, Vector3(0.03, 0.3, 0.06), glow)
		_box(parent, at + Vector3(0, 0.1, 0.08), Vector3(0.03, 0.06, 0.18), glow)
		_box(parent, at + Vector3(0, -0.12, -0.07), Vector3(0.03, 0.06, 0.14), glow)
	DungeonLife.bone_pile(parent, floor_at(Vector2i(19, 12)) + Vector3(0, 0, 0.4), rng, 1.0)
	DungeonLife.broken_pot(parent, floor_at(Vector2i(18, 10)) + Vector3(-0.3, 0, -0.4), rng)
	# The foreman's last page on a little stone ledge in the niche.
	var ledge := floor_at(Vector2i(20, 11)) + Vector3(0.45, 0, 0)
	_box(parent, ledge + Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.9), HouseLooks.temple_stone())
	_solid(body, ledge + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 1.0))
	_chest(level, parent, body, Vector2i(18, 12), Vector3(-0.2, 0, 0.2), PI)


## A page of the log: a sheet of paper on what it lies on (the hero runs into that).
static func _page(level: Level, parent: Node3D, body: StaticBody3D, c: Vector2i, text: String, index: int) -> void:
	var mid := floor_at(c)
	# How high the page lies: on a plank table, a table, a barrel, a crate, a stool, a ledge.
	var high: Array = [0.8, 1.0, 0.81, 0.71, 0.72, 0.91]
	var at := mid + Vector3(0, high[index], 0)
	if index == 0:
		var wood := _mat("timber", TIMBER)
		_box(parent, mid + Vector3(0, 0.76, 0), Vector3(1.0, 0.08, 0.7), wood)
		for leg in [Vector3(-0.42, 0, -0.28), Vector3(0.42, 0, -0.28), Vector3(-0.42, 0, 0.28), Vector3(0.42, 0, 0.28)]:
			_box(parent, mid + leg + Vector3(0, 0.37, 0), Vector3(0.07, 0.74, 0.07), wood)
		_solid(body, mid + Vector3(0, 0.4, 0), Vector3(1.1, 0.8, 0.8))
	elif index == 5:
		at += Vector3(0.45, 0, 0)
	var turn := 0.3 + index * 0.7
	_box(parent, at + Vector3(0, 0.005, 0), Vector3(0.32, 0.01, 0.42), _mat("paper", Color(0.86, 0.8, 0.64)), turn)
	_box(parent, at + Vector3(0, 0.012, 0), Vector3(0.22, 0.004, 0.3), _mat("ink", Color(0.42, 0.36, 0.3)), turn)
	level.stations.append({"kind": NOTE, "text": text, "pos": mid, "cell": level.world_to_cell(mid), "used": false, "touch": 1.6})


## The sealed gate at the end of the old works: a stone door in a hewn frame,
## iron bands and wedges across it, runes glowing round it. It does not open.
static func _gate(level: Level, parent: Node3D, body: StaticBody3D) -> void:
	var stone := HouseLooks.temple_stone()
	var iron := _mat("iron", IRON, 0.6)
	var glow := _mat("rune", RUNE_COLOUR, 0.0, 3.0)
	var base := floor_at(GATE_CELL)
	var face := base + Vector3(0, 0, -0.8)
	# The frame: two jambs and a lintel standing out of the wall.
	for side in [-1.0, 1.0]:
		_box(parent, face + Vector3(side * 0.74, 1.2, 0.05), Vector3(0.3, 2.4, 0.3), stone)
	_box(parent, face + Vector3(0, 2.42, 0.05), Vector3(1.8, 0.34, 0.34), stone)
	# The door: dark stone, banded and wedged with iron.
	_box(parent, face + Vector3(0, 1.12, -0.02), Vector3(1.2, 2.24, 0.2), _mat("gate_stone", Color(0.2, 0.2, 0.23)))
	for y in [0.45, 1.15, 1.85]:
		_box(parent, face + Vector3(0, y, 0.1), Vector3(1.26, 0.12, 0.05), iron)
	for x in [-0.42, 0.42]:
		var wedge := _box(parent, face + Vector3(x, 1.15, 0.16), Vector3(0.12, 0.5, 0.1), iron)
		wedge.rotation.x = 0.35
	# Runes round the door and a faint cold light from them.
	for i in 7:
		var a := float(i) / 6.0 * PI
		_box(parent, face + Vector3(cos(a) * 0.5, 2.0 + sin(a) * 0.14, 0.11), Vector3(0.07, 0.14, 0.02), glow)
	_box(parent, face + Vector3(0, 1.15, 0.13), Vector3(0.22, 0.22, 0.02), glow)
	var light := OmniLight3D.new()
	light.light_color = RUNE_COLOUR
	light.light_energy = 0.9
	light.omni_range = 5.0
	light.position = face + Vector3(0, 1.6, 0.8)
	parent.add_child(light)
	_solid(body, face + Vector3(0, 1.2, 0), Vector3(1.8, 2.4, 0.4))
	level.stations.append({"kind": GATE, "pos": base + Vector3(0, 0, -0.6), "cell": level.world_to_cell(base), "used": false, "touch": 1.6})
