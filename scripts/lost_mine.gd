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
##   "o"  a stretch of the drifts where the silver runs: earthen floor, ore-bearing rock walls
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
	"            s  .....                                                    ",
	"            r  .....                                                    ",
	"            rrr.....                                                    ",
	"            r  .....                                                    ",
	"  .o.   rrrrr                                                           ",
	"  ...   r                                                               ",
	"   .    r                                                               ",
	"   .    r                                                               ",
	"   .    r                                                               ",
	"   .    rrr                                                             ",
	"   .      r                                                             ",
	"   .      r                                                             ",
	"   .      .                               L                             ",
	"   ........             ooooooo           .                        ..o. ",
	"          .             ooooooo           . ....                   .... ",
	"          .                .              . ....                     .  ",
	"    ............................................                     .  ",
	"    .               .              .        ....                     .  ",
	"  .....             .            .....        .                      .  ",
	"  .....             .            .....        ........................  ",
	"  .....             .            .....                   .              ",
	"  .....             .            .....                   .              ",
	"    .               .                                  ......           ",
	"    .               .                                  ..........       ",
	"    .               .                                  ......   .       ",
	"    .               .                                  ......   .       ",
	"    .               .                                           .       ",
	"    .................                                           .       ",
	"            .                                                   .       ",
	"            .                                               xxxxx       ",
	"          .....                                                         ",
	"          ..o..                                                         ",
	"                                                                        ",
]
## The raw rock of the cleft, a wall surface of the mine alone (see HouseSketcher._wall_material).
const ROCK := "rock"
## The rock the silver runs through: dark stone shot with bright veins (see ore_rock_material).
const ORE_ROCK := "ore_rock"
## The letters of dug cells, and the floor and wall each gets (HouseSketch.SURFACES, and ROCK).
const DUG := {".": ["", "wood"], "o": ["", ORE_ROCK], "L": ["", "wood"], "x": ["", "wood"], "r": ["", ROCK], "s": ["stone", "stone"], "D": ["stone", "stone"]}
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
## A miner's plank bed: the hero would rather not sleep down here.
const BED := "grubenbett"
## A vein of ore at the end of a drift, to hack lumps out of (see dig).
const VEIN := "erzader"
const KINDS := [NOTE, GATE, BED, VEIN]
const BED_WARN := "Auf dem modrigen Stroh schlafen, hier unten, wo es nachts im Fels klopft? Lieber nicht."

## The compendium's entry, learnt the first time the hero climbs down.
const LEARN := "Die vergessene Silbergrube: Unter der leeren Steigerhütte am Waldrand südlich des Dorfteichs führt eine Leiter in die Stollen, die zwölf Bergleute unter dem Wald gruben und dann verließen. Die Seiten des Steigerbuchs erzählen, warum."
const ENTERED := "Du steigst in eine vergessene Silbergrube hinab. Irgendwo hier unten liegen die Seiten eines Steigerbuchs."
## The foreman's log, page by page, and the cell each page lies in.
const NOTES := [
	["Steigerbuch, erster Tag: Unter dem Wald südlich des Dorfteichs haben wir Silber gefunden. Zwölf Mann, gutes Grubenholz und eine Hütte über dem Schacht. Wir werden reich, sagt Jorin. (Steiger Aldo Brenner)", Vector2i(45, 30)],
	["Steigerbuch, vierzigster Tag: Nachts klopft es im Fels. Drei Schläge, dann Stille. Die Männer sagen, das ist das Wasser. Wasser zählt nicht bis drei.", Vector2i(34, 34)],
	["Steigerbuch, zweiundfünfzigster Tag: Die Ader führt nach Westen, tiefer als jede Karte. Hinter dem Silber ist der Fels behauen, glatt wie Tempelstein. Jemand hat hier vor uns gegraben, lange vor dem Dorf.", Vector2i(24, 28)],
	["Steigerbuch, sechzigster Tag: Der Oststollen ist eingebrochen. Jorin und Matthes waren dahinter. Wir graben seit zwei Tagen. Das Klopfen ist lauter als unsere Hacken.", Vector2i(64, 42)],
	["Steigerbuch, einundsiebzigster Tag: Nur noch vier von uns. Wir haben eine Nische für die Göttin der Tiefe ausgehauen und Kerzen entzündet. Sie antwortet nicht. Das Tor antwortet.", Vector2i(3, 36)],
	["Letzter Eintrag: Ich habe das Tor am Ende der alten Gänge mit Eisen verkeilt und die Männer heimgeschickt. Wer dies findet: Öffne es nicht, ehe du weißt, wer auf der anderen Seite klopft. (A. Brenner)", Vector2i(20, 11)],
]
## What the gate says: the first time (kept in the compendium), and every time after.
const GATE_FIRST := "Ein steinernes Tor, alt wie der Berg, hinter einem Eisengitter, das eine schwere Kette und ein Schloss verschließen. Es rührt sich nicht. Von der anderen Seite klopft es dreimal."
const GATE_AGAIN := "Das Tor ist fest verschlossen. Noch."

## The stone portal round the hut's door: half the opening's width and the height of its arch's
## spring (metres), and its stone.
const PORTAL_HALF := 1.0
const PORTAL_HIGH := 2.3
const PORTAL_STONE := Color(0.47, 0.46, 0.43)
## How high a rail's middle lies: its top (0.07) stands clear of the door's threshold top (0.06), so the
## two never flicker where the rails cross the doorstep.
const RAIL_LIFT := 0.055
## The row of cells where the rails out of the door end, under the ore cart.
const RAIL_END := 23
## The crane at the hut's corner: how high its arm is and how far it reaches out (metres).
const CRANE_HIGH := 3.4
const CRANE_REACH := 1.6
## Where the miners' lamps hang (cells).
const LAMPS := [Vector2i(42, 30), Vector2i(46, 31), Vector2i(35, 35), Vector2i(31, 31), Vector2i(27, 29),
	Vector2i(20, 31), Vector2i(12, 31), Vector2i(20, 38), Vector2i(12, 42), Vector2i(4, 35), Vector2i(52, 34),
	Vector2i(58, 39), Vector2i(64, 40), Vector2i(10, 28)]
const LAMP_COLOUR := Color(1.0, 0.68, 0.36)
const LAMP_ENERGY := 2.6
const LAMP_RANGE := 8.5
## The one lamp still burning: at the foot of the ladder.
const LIT_LAMP := Vector2i(42, 30)
## Where water stands in puddles on the floor (cells).
const PUDDLES := [Vector2i(14, 31), Vector2i(26, 31), Vector2i(20, 35), Vector2i(4, 39), Vector2i(16, 42), Vector2i(3, 23),
	Vector2i(8, 28), Vector2i(12, 44), Vector2i(60, 34), Vector2i(66, 34), Vector2i(69, 32), Vector2i(58, 37), Vector2i(64, 41),
	Vector2i(8, 22), Vector2i(12, 14), Vector2i(46, 33), Vector2i(53, 34)]
## How likely a corner of two walls has a cobweb in it.
const WEB_CHANCE := 0.55
## The pale light of the old works' runes, cold and faint.
const RUNE_COLOUR := Color(0.45, 0.62, 1.0)
const TIMBER := Color(0.34, 0.23, 0.13)
## How far a chest's middle stands from the wall at its back (half its depth and a little room).
const CHEST_FROM_WALL := 0.55
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
static var _paths: AStarGrid2D = null
## The dead of the mine (see GUARDS), one entry each: {"kind", "cell", "enemy", "fell"}.
static var _guards: Array = []
## The day each vein (by its cell) was last hacked at (see dig).
static var _dug := {}

## The dead who keep the far drifts (kind, cell): the ore at their ends is
## theirs until they fall (see VEIN_GUARD). Each rises again a day after it fell.
const GUARDS := [
	["krieger", Vector2i(3, 24)], ["krieger", Vector2i(3, 20)],
	["ghul", Vector2i(11, 45)], ["wicht", Vector2i(13, 46)],
	["krieger", Vector2i(63, 34)], ["schuetze", Vector2i(69, 30)], ["krieger", Vector2i(68, 28)],
	["krieger", Vector2i(17, 16)], ["wicht", Vector2i(18, 18)],
]
## The ore veins at the ends of the long drifts: the cell in front of each and the wall it is in.
const VEINS := [[Vector2i(3, 19), Vector2i(0, -1)], [Vector2i(12, 46), Vector2i(0, 1)], [Vector2i(69, 28), Vector2i(0, -1)]]
## While one of the dead stands this near a vein (metres), nobody hacks at it in peace.
const VEIN_GUARD := 12.0
## What a vein gives: how many lumps, and how likely each size is (Ore.LUMPS, small to big).
const VEIN_LUMPS := [1, 2]
const VEIN_ODDS := {"erzbrocken_klein": 0.6, "erzbrocken": 0.3, "erzbrocken_gross": 0.1}
## At night the silver of the vein shows its moonsilver (see Crafting.INGREDIENTS) this often.
const MOONSILVER_CHANCE := 0.5
## Coins in the rags of one of the dead of the mine [least, most]: they fall to dust, the coins into the purse.
const GUARD_PURSE := [1, 4]
const VEIN_GUARDED := "Hier hackt niemand in Ruhe, solange die Toten dieses Stollens umgehen."
const VEIN_SPENT := "Die Ader gibt heute nichts mehr her. Komm an einem anderen Tag wieder."
const VEIN_FOUND := "Du schlägst Erz aus der Ader."


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
	s.abandoned = true
	_sketch = s
	return s


## The empty hut's inside (see HouseSketcher): nobody has swept it for years. Dust and dirt on the
## boards, a broken stool and loose planks, cobwebs in the corners under the roof, and a little
## cold light that falls in through the gaps in the roof, so it is not a black hole at night.
static func furnish_hut(parent: Node3D) -> void:
	var s := sketch()
	var lo := s.node_world(HUT.position.x, HUT.position.y)
	var hi := s.node_world(HUT.end.x, HUT.end.y)
	var inner := HouseSketcher.THICK * 0.5 + 0.02
	var top := HouseSketch.FLOOR_RISE + 0.004
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Dust and dirt in patches, thickest along the walls (not over the open shaft).
	var dust := _mat("dust", Color(0.22, 0.19, 0.15, 0.32))
	dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 16:
		var at := Vector3(rng.randf_range(lo.x + 0.5, hi.x - 0.5), top, rng.randf_range(lo.z + 0.5, hi.z - 0.5))
		if _over_shaft(s, at, 0.6):
			continue
		_box(parent, at, Vector3(rng.randf_range(0.4, 0.9), 0.004, rng.randf_range(0.3, 0.7)), dust, rng.randf() * TAU)
	# Loose planks, a toppled stool with a broken leg, a rag of sacking.
	var wood := _mat("hut_wood", TIMBER.lightened(0.1))
	var plank_at := s.cell_world(40, 27) + Vector3(0.2, top + 0.03, 0.1)
	_box(parent, plank_at, Vector3(1.6, 0.05, 0.22), wood, 0.4)
	_box(parent, plank_at + Vector3(0.1, 0.05, 0.25), Vector3(1.2, 0.05, 0.2), wood, 0.25)
	var stool := s.cell_world(40, 26) + Vector3(-0.2, 0, -0.3)
	var seat := _box(parent, stool + Vector3(0, 0.22, 0), Vector3(0.45, 0.06, 0.45), wood, 0.3)
	seat.rotation.z = 1.25
	for leg in [Vector3(0.14, 0.32, 0.14), Vector3(0.14, 0.32, -0.14), Vector3(0.12, 0.2, 0.0)]:
		var l := _box(parent, stool + Vector3(leg.x + 0.12, leg.y * 0.5 + 0.04, leg.z), Vector3(0.05, leg.y, 0.05), wood)
		l.rotation.z = 1.25 if leg.y > 0.3 else 0.3
	_box(parent, s.cell_world(41, 27) + Vector3(-0.3, top + 0.01, 0.4), Vector3(0.7, 0.02, 0.5), _mat("sacking", Color(0.4, 0.34, 0.24)), 0.8)
	# Cobwebs in the corners under the eaves, and one across the corner by the door.
	var web := _mat("web", Color(0.85, 0.85, 0.82, 0.32))
	web.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web.cull_mode = BaseMaterial3D.CULL_DISABLED
	var high := HouseSketcher.WALL_HEIGHT - 0.05
	for corner in [Vector2(lo.x + inner, lo.z + inner), Vector2(hi.x - inner, lo.z + inner), Vector2(lo.x + inner, hi.z - inner), Vector2(hi.x - inner, hi.z - inner)]:
		var sx := 1.0 if corner.x < (lo.x + hi.x) * 0.5 else -1.0
		var sz := 1.0 if corner.y < (lo.z + hi.z) * 0.5 else -1.0
		parent.add_child(_cobweb(Vector3(corner.x, high, corner.y), Vector3(sx, 0, 0), Vector3(0, 0, sz), rng.randf_range(0.7, 1.1), web))
	# A little moonlight through the gaps in the roof: cold and faint (by day it is lost).
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.68, 0.9)
	light.light_energy = 0.55
	light.omni_range = 5.5
	light.position = (lo + hi) * 0.5 + Vector3(0, 2.2, 0)
	parent.add_child(light)


## Round the hut outside, what the miners left when they went: a heap of grey ore with a glint
## in it, a stack of pit planks, a pick and a shovel against the wall, a tipped-over cart with a
## wheel off and a rusty bucket. East and west of the hut only: the path to its door stays clear.
static func furnish_yard(level: Level, parent: Node3D) -> void:
	var s := sketch()
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var wood := _mat("yard_wood", TIMBER.lightened(0.08))
	var old_wood := _mat("yard_old_wood", Color(0.36, 0.31, 0.26))
	var iron := _mat("rusty_iron", Color(0.36, 0.25, 0.18), 0.4)
	var ore := _mat("yard_ore", Color(0.17, 0.16, 0.17))
	var silver: Material = _silver()
	# West of the hut: the ore heap and the plank stack.
	var heap := s.cell_world(38, 26)
	for i in 18:
		var r := rng.randf_range(0.0, 0.9)
		var a := rng.randf() * TAU
		_ore_chunk(parent, heap + Vector3(cos(a) * r, 0.12 + (0.9 - r) * 0.4 * rng.randf(), sin(a) * r), rng.randf_range(0.26, 0.5), rng, ore, silver, i % 5 == 0)
	level._add_solid(heap, Vector3(1.6, 0.6, 1.6))
	var stack := s.cell_world(38, 27) + Vector3(0.2, 0, 0.4)
	for i in 5:
		_box(parent, stack + Vector3(rng.randf_range(-0.05, 0.05), 0.06 + i * 0.1, 0), Vector3(2.0, 0.08, 0.26), old_wood if i % 2 else wood, rng.randf_range(-0.08, 0.08))
		_box(parent, stack + Vector3(rng.randf_range(-0.05, 0.05), 0.06 + i * 0.1, 0.3), Vector3(1.9, 0.08, 0.26), wood if i % 2 else old_wood, rng.randf_range(-0.08, 0.08))
	level._add_solid(stack + Vector3(0, 0, 0.15), Vector3(2.0, 0.5, 0.7))
	# Against the hut's west wall: a pick and a shovel leaning.
	var wall := s.node_world(HUT.position.x, HUT.position.y + 2)
	var pick_at := wall + Vector3(-0.35, 0, -0.6)
	var handle := _box(parent, pick_at + Vector3(0, 0.6, 0), Vector3(0.05, 1.2, 0.05), wood)
	handle.rotation.z = -0.25
	var head := _box(parent, pick_at + Vector3(-0.15, 1.18, 0), Vector3(0.08, 0.06, 0.6), iron)
	head.rotation.z = -0.25
	var shovel_at := wall + Vector3(-0.3, 0, 0.3)
	var shaft := _box(parent, shovel_at + Vector3(0, 0.6, 0), Vector3(0.05, 1.2, 0.05), wood)
	shaft.rotation.z = -0.22
	var blade := _box(parent, shovel_at + Vector3(0.12, 0.1, 0), Vector3(0.04, 0.32, 0.26), iron)
	blade.rotation.z = -0.22
	# East of the hut: the tipped cart, a wheel lying beside it, spilt ore and a bucket.
	var cart := s.cell_world(44, 26) + Vector3(0.2, 0, 0)
	var body := _box(parent, cart + Vector3(0, 0.45, 0), Vector3(1.1, 0.7, 1.5), old_wood, 0.3)
	body.rotation.z = 1.3
	for z in [-0.5, 0.5]:
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.22
		cyl.bottom_radius = 0.22
		cyl.height = 0.08
		wheel.mesh = cyl
		wheel.material_override = iron
		wheel.position = cart + Vector3(-0.4 if z < 0.0 else 0.75, 0.04 if z > 0.0 else 0.62, z)
		wheel.rotation = Vector3(0, 0.3, 0.0 if z > 0.0 else PI * 0.5)
		parent.add_child(wheel)
	for i in 7:
		_ore_chunk(parent, cart + Vector3(rng.randf_range(0.5, 1.2), 0.08, rng.randf_range(-0.6, 0.6)), rng.randf_range(0.2, 0.36), rng, ore, silver, i % 3 == 0)
	level._add_solid(cart, Vector3(1.4, 0.9, 1.6))
	var bucket := MeshInstance3D.new()
	var pail := CylinderMesh.new()
	pail.top_radius = 0.2
	pail.bottom_radius = 0.16
	pail.height = 0.32
	bucket.mesh = pail
	bucket.material_override = iron
	bucket.position = s.cell_world(44, 27) + Vector3(-0.3, 0.12, 0.3)
	bucket.rotation = Vector3(1.4, 0.8, 0)
	parent.add_child(bucket)


## The mine's way in, as the old miners left it: a hewn stone portal round the hut's door with
## one lantern still burning beside it, rails running out of the door to an ore cart full of
## ore, a crane with a bucket hanging from its arm, a big cart wheel against the wall, barrels,
## crates, tools and fallen stones, and the corners of the walls broken off ragged and high.
## The way through the door stays free.
static func furnish_entrance(level: Level, parent: Node3D) -> void:
	var s := sketch()
	var rng := RandomNumberGenerator.new()
	rng.seed = 173
	var stone := _mat("portal_stone", PORTAL_STONE)
	var dark_stone := _mat("portal_stone_dark", PORTAL_STONE.darkened(0.18))
	var wood := _mat("yard_old_wood", Color(0.36, 0.31, 0.26))
	var iron := _mat("rusty_iron", Color(0.36, 0.25, 0.18), 0.4)
	var ore := _mat("yard_ore", Color(0.17, 0.16, 0.17))
	var silver: Material = _silver()
	var door_x := HUT.position.x + HUT.size.x / 2
	var first := parent.get_child_count()
	# The face of the door's wall (north), the door's middle on it.
	var face := s.node_world(door_x, HUT.position.y) + Vector3(HouseSketch.CELL * 0.5, 0, 0)
	var out := Vector3(0, 0, -1)
	var high := PORTAL_HIGH
	# The portal, on both faces of the wall (the way in from the path, and what one sees of it
	# from inside): two jambs of big hewn blocks, a round arch of wedge stones with a keystone,
	# and a timber lintel across the opening under it.
	for way in [out * 0.3, -out * 0.42]:
		for side in [-1.0, 1.0]:
			var y := 0.0
			var k := 0
			while y < high - 0.05:
				var h := minf(rng.randf_range(0.42, 0.6), high - y)
				var w := 0.56 if k % 2 == 0 else 0.46
				_box(parent, face + way + Vector3(side * (PORTAL_HALF + w * 0.5), y + h * 0.5, 0), Vector3(w, h - 0.03, 0.4), stone if k % 3 else dark_stone, rng.randf_range(-0.03, 0.03))
				y += h
				k += 1
			level._add_solid(face + way + Vector3(side * (PORTAL_HALF + 0.27), 0, 0), Vector3(0.56, high, 0.4))
			# A plinth under the jamb and a projecting impost block where the arch springs.
			_box(parent, face + way + Vector3(side * (PORTAL_HALF + 0.3), 0.12, 0), Vector3(0.72, 0.24, 0.52), dark_stone)
			_box(parent, face + way + Vector3(side * (PORTAL_HALF + 0.24), high - 0.09, 0), Vector3(0.74, 0.18, 0.5), dark_stone)
		# The arch: wedge stones, each a little wider outside than in, and a keystone that stands out.
		var ring := 13
		for i in ring:
			var a := PI * (float(i) + 0.5) / float(ring)
			var r := PORTAL_HALF + 0.24
			var key := i == ring / 2
			var at: Vector3 = face + way + Vector3(-cos(a) * r, high + sin(a) * r, 0)
			var wedge := _box(parent, at, Vector3(0.3 if not key else 0.36, 0.48 if not key else 0.62, 0.42 if not key else 0.5), stone if i % 2 else dark_stone)
			wedge.rotation.z = a - PI * 0.5
			if key:
				wedge.position += Vector3(0, 0.06, 0)
		_box(parent, face + way * 1.2 + Vector3(0, high - 0.12, 0), Vector3(PORTAL_HALF * 2.0 + 0.2, 0.22, 0.22), wood)
	# The lantern on an iron bracket on the right-hand jamb: the one light left burning.
	var lamp_at := face + out * 0.62 + Vector3(PORTAL_HALF + 0.3, 2.0, 0)
	_box(parent, lamp_at + Vector3(0, 0.36, 0.18), Vector3(0.05, 0.05, 0.5), iron)
	_box(parent, lamp_at + Vector3(0, 0.22, 0), Vector3(0.03, 0.26, 0.03), iron)
	_box(parent, lamp_at, Vector3(0.22, 0.3, 0.22), _mat("lamp_glass", LAMP_COLOUR, 0.0, 2.5))
	_box(parent, lamp_at + Vector3(0, 0.17, 0), Vector3(0.3, 0.05, 0.3), iron)
	_box(parent, lamp_at - Vector3(0, 0.17, 0), Vector3(0.3, 0.05, 0.3), iron)
	var glow := OmniLight3D.new()
	glow.light_color = LAMP_COLOUR
	glow.light_energy = 1.6
	glow.omni_range = 6.5
	glow.shadow_enabled = false
	glow.position = lamp_at + out * 0.2
	parent.add_child(glow)
	# Rails out of the door, from the middle of the hut to an ore cart by the path.
	var rail := _mat("rail", Color(0.3, 0.27, 0.25), 0.7)
	var sleeper := _mat("sleeper", TIMBER.darkened(0.25))
	var start := s.cell_world(door_x, HUT.position.y)
	var end := s.cell_world(door_x, RAIL_END)
	var steps := int(round(start.distance_to(end) / 0.66))
	for k in steps + 1:
		var at := start.lerp(end, float(k) / float(steps))
		_box(parent, at + Vector3(rng.randf_range(-0.05, 0.05), 0.015, 0), Vector3(1.1, 0.03, 0.16), sleeper, rng.randf_range(-0.08, 0.08))
	for side in [-0.38, 0.38]:
		_box(parent, (start + end) * 0.5 + Vector3(side, RAIL_LIFT, 0), Vector3(0.07, 0.03, start.distance_to(end) + 0.6), rail)
	# A short siding west of the way out, with the cart standing on it.
	var siding := s.cell_world(door_x - 2, RAIL_END + 1)
	for k in 4:
		_box(parent, siding + Vector3(0, 0.015, -0.99 + k * 0.66), Vector3(1.1, 0.03, 0.16), sleeper, rng.randf_range(-0.08, 0.08))
	for side in [-0.38, 0.38]:
		_box(parent, siding + Vector3(side, RAIL_LIFT, 0), Vector3(0.07, 0.03, 2.2), rail)
	var cart := siding + Vector3(0, 0, -0.2)
	_ore_cart(parent, cart, rng, wood, iron, ore, silver)
	level._add_solid(cart, Vector3(1.2, 1.2, 1.6))
	# The crane at the hut's north-east corner: a post, an arm out over the yard and a brace,
	# a rope and a bucket hanging from its end.
	var post := s.node_world(HUT.end.x, HUT.position.y) + Vector3(0.45, 0, -0.45)
	_box(parent, post + Vector3(0, CRANE_HIGH * 0.5, 0), Vector3(0.26, CRANE_HIGH, 0.26), wood)
	var arm_end := post + Vector3(0, CRANE_HIGH - 0.15, -CRANE_REACH)
	_box(parent, (post + Vector3(0, CRANE_HIGH - 0.15, 0) + arm_end) * 0.5, Vector3(0.2, 0.2, CRANE_REACH + 0.3), wood)
	var brace := _box(parent, post + Vector3(0, CRANE_HIGH - 0.75, -0.55), Vector3(0.14, 0.14, 1.5), wood)
	brace.rotation.x = -0.75
	_box(parent, arm_end + Vector3(0, -0.55, 0.1), Vector3(0.03, 1.1, 0.03), _mat("rope", Color(0.55, 0.47, 0.33)))
	var pail := MeshInstance3D.new()
	var tub := CylinderMesh.new()
	tub.top_radius = 0.24
	tub.bottom_radius = 0.19
	tub.height = 0.36
	pail.mesh = tub
	pail.material_override = wood
	pail.position = arm_end + Vector3(0, -1.28, 0.1)
	parent.add_child(pail)
	_box(parent, pail.position + Vector3(0, 0.08, 0), Vector3(0.5, 0.04, 0.04), iron)
	level._add_solid(post, Vector3(0.36, CRANE_HIGH, 0.36))
	# A big cart wheel leaning against the east wall.
	var lean := s.node_world(HUT.end.x, HUT.position.y + 1) + Vector3(0.3, 0, 0.2)
	var big := Node3D.new()
	big.position = lean + Vector3(0, 0.72, 0)
	big.rotation = Vector3(0, PI * 0.5, -0.22)
	parent.add_child(big)
	_spoked_wheel(big, 0.75, wood, iron)
	level._add_solid(lean, Vector3(0.5, 1.4, 1.5))
	# Barrels, crates and tools by the door, out of the way in.
	for spot: Array in [[Vector3(1.75, 0, -0.75), "barrel_small", 0.0], [Vector3(2.3, 0, -1.5), "barrel_small", 1.2]]:
		var at: Vector3 = face + spot[0]
		_age_prop(level._place(spot[1], at, spot[2], parent))
		level._add_solid(at, Vector3(0.8, 1.0, 0.8))
	# Two old crates of grey boards, one on the other, the top one askew.
	var crate_at := face + Vector3(1.7, 0, -2.6)
	for k in 2:
		var size := 0.75 - k * 0.15
		var mid := crate_at + Vector3(0.05 * k, 0.75 * k + size * 0.5, 0)
		_box(parent, mid, Vector3(size, size, size), wood, 0.3 + k * 0.5)
		for edge in [-1.0, 1.0]:
			_box(parent, mid + Vector3(0, edge * size * 0.42, 0), Vector3(size + 0.04, 0.08, size + 0.04), iron if k == 0 else wood, 0.3 + k * 0.5)
	level._add_solid(crate_at, Vector3(0.8, 1.35, 0.8))
	var tools := face + Vector3(-1.35, 0, -0.3)
	for t in 2:
		var h := _box(parent, tools + Vector3(t * 0.3, 0.6, 0), Vector3(0.05, 1.2, 0.05), wood)
		h.rotation.z = 0.2
		_box(parent, tools + Vector3(t * 0.3 + 0.12, 1.18 if t == 0 else 0.12, 0), Vector3(0.08, 0.06, 0.55) if t == 0 else Vector3(0.04, 0.3, 0.26), iron, 0.0)
	# The corners of the walls broken off ragged: piers of loose blocks, higher at two corners.
	for corner: Array in [[s.node_world(HUT.position.x, HUT.position.y), 1.4], [s.node_world(HUT.end.x, HUT.position.y), 0.7],
			[s.node_world(HUT.position.x, HUT.end.y), 0.6], [s.node_world(HUT.end.x, HUT.end.y), 1.2]]:
		var at: Vector3 = corner[0]
		var y := HouseSketcher.WALL_HEIGHT
		var top: float = HouseSketcher.WALL_HEIGHT + float(corner[1])
		var k := 0
		while y < top:
			var h := rng.randf_range(0.3, 0.45)
			_box(parent, at + Vector3(rng.randf_range(-0.08, 0.08), y + h * 0.5, rng.randf_range(-0.08, 0.08)), Vector3(0.6 - k * 0.06, h - 0.02, 0.6 - k * 0.06), stone if k % 2 else dark_stone, rng.randf_range(-0.2, 0.2))
			y += h
			k += 1
	# Fallen stones and rubble along the walls' feet.
	for i in 22:
		var side := rng.randi_range(0, 3)
		var t := rng.randf()
		var a := s.node_world(HUT.position.x, HUT.position.y)
		var b := s.node_world(HUT.end.x, HUT.end.y)
		var at := Vector3(lerpf(a.x, b.x, t), 0, a.z - 0.45) if side == 0 else Vector3(b.x + 0.45, 0, lerpf(a.z, b.z, t)) if side == 1 \
				else Vector3(lerpf(a.x, b.x, t), 0, b.z + 0.45) if side == 2 else Vector3(a.x - 0.45, 0, lerpf(a.z, b.z, t))
		# Not in the way to the door.
		if side == 0 and absf(at.x - face.x) < PORTAL_HALF + 0.7:
			continue
		var size := rng.randf_range(0.16, 0.42)
		var block := _box(parent, at + Vector3(0, size * 0.4, 0), Vector3(size * 1.3, size, size), stone if i % 3 else dark_stone, rng.randf() * TAU)
		block.rotation.x = rng.randf_range(-0.3, 0.3)
	_weather(parent, first, [stone, dark_stone], [wood, sleeper, _mat("rope", Color(0.55, 0.47, 0.33))], [iron, rail])


## Gives the entrance's pieces (children of `parent` from index `first` on) the look of the
## other buildings: blocks of `stones` become rounded hewn blocks of the walls' stone (see
## HouseLooks.temple_stone and StoneLook.rounded_box), and `woods` and `irons` take the
## weathered grain, cracks, rust and moss of the props outside (see WeatheredProps).
static func _weather(parent: Node3D, first: int, stones: Array, woods: Array, irons: Array) -> void:
	var nodes: Array[Node] = []
	for i in range(first, parent.get_child_count()):
		var child := parent.get_child(i)
		nodes.append(child)
		nodes.append_array(child.find_children("*", "MeshInstance3D", true, false))
	for n in nodes:
		var m := n as MeshInstance3D
		if m == null or m.material_override == null:
			continue
		var was: Material = m.material_override
		if was in stones:
			if m.mesh is BoxMesh:
				m.mesh = StoneLook.rounded_box((m.mesh as BoxMesh).size)
			m.material_override = HouseLooks.temple_stone()
		elif was in woods:
			m.material_override = WeatheredProps.colour_material((was as StandardMaterial3D).albedo_color.lightened(0.25), WeatheredProps.WOOD)
		elif was in irons:
			m.material_override = WeatheredProps.colour_material((was as StandardMaterial3D).albedo_color.lightened(0.2), WeatheredProps.IRON)


static func _wheel(at: Vector3, radius: float, thick: float, mat: Material, turn: Vector3) -> MeshInstance3D:
	var wheel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = thick
	wheel.mesh = cyl
	wheel.material_override = mat
	wheel.position = at
	wheel.rotation = turn
	return wheel


## A wooden mine cart standing on its rails (long way along Z): a tub of planks that widens
## towards the rim, an iron band round the rim and two more round the belly, corner straps,
## a mound of rough ore heaped over the top, two axles with iron-rimmed wheels and a
## coupling hook on each end.
static func _ore_cart(parent: Node3D, at: Vector3, rng: RandomNumberGenerator, wood: Material, iron: Material, ore: Material, silver: Material) -> void:
	var plank := wood
	# The floor and the four slanting walls (each leans out by about 0.2 rad).
	_box(parent, at + Vector3(0, 0.42, 0), Vector3(0.78, 0.07, 1.14), wood)
	for side in [-1.0, 1.0]:
		var wall := _box(parent, at + Vector3(side * 0.43, 0.7, 0), Vector3(0.07, 0.6, 1.3), plank)
		wall.rotation.z = -side * 0.2
		var end := _box(parent, at + Vector3(0, 0.7, side * 0.66), Vector3(1.02, 0.6, 0.07), plank)
		end.rotation.x = side * 0.14
		# Plank seams on the long walls.
		for k in [-0.15, 0.1]:
			var seam := _box(parent, at + Vector3(side * (0.45 + 0.05 * absf(k)), 0.7 + k, 0), Vector3(0.015, 0.012, 1.3), iron)
			seam.rotation.z = -side * 0.2
	# Iron bands: a heavy one round the rim, two round the belly, corner straps.
	for z in [-0.58, 0.0, 0.58]:
		for side in [-1.0, 1.0]:
			var band := _box(parent, at + Vector3(side * 0.47, 0.71, z), Vector3(0.045, 0.64, 0.07), iron)
			band.rotation.z = -side * 0.2
		_box(parent, at + Vector3(0, 0.42, z), Vector3(0.9, 0.05, 0.07), iron)
	for side in [-1.0, 1.0]:
		_box(parent, at + Vector3(side * 0.5, 1.02, 0), Vector3(0.07, 0.07, 1.36), iron)
		_box(parent, at + Vector3(0, 1.0, side * 0.69), Vector3(1.08, 0.07, 0.07), iron)
	# Axles, wheels with an iron tyre and hub, and a coupling hook at each end.
	for z in [-0.4, 0.4]:
		_box(parent, at + Vector3(0, 0.24, z), Vector3(0.9, 0.05, 0.05), iron)
		for side in [-1.0, 1.0]:
			var hub := at + Vector3(side * 0.42, 0.24, z)
			var turn := Vector3(0, 0, PI * 0.5)
			parent.add_child(_wheel(hub, 0.2, 0.05, iron, turn))
			parent.add_child(_wheel(hub - Vector3(side * 0.01, 0, 0), 0.16, 0.07, wood, turn))
			parent.add_child(_wheel(hub + Vector3(side * 0.04, 0, 0), 0.06, 0.06, iron, turn))
	for side in [-1.0, 1.0]:
		_box(parent, at + Vector3(0, 0.36, side * 0.78), Vector3(0.06, 0.06, 0.22), iron)
		var hook := _box(parent, at + Vector3(0, 0.36, side * 0.9), Vector3(0.14, 0.06, 0.06), iron)
		hook.rotation.y = 0.5
	# The load: a mound of rough ore, with silver showing in it.
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.34)
		var rise := 1.0 - r / 0.4
		_ore_chunk(parent, at + Vector3(cos(a) * r * 1.1, 0.92 + rise * 0.14 + rng.randf_range(0.0, 0.05), sin(a) * r * 1.7), rng.randf_range(0.24, 0.38), rng, ore, silver, i % 3 == 0)


## A big spoked cart wheel under `parent`, in its XY plane: an iron-shod rim, spokes and a hub.
static func _spoked_wheel(parent: Node3D, radius: float, wood: Material, iron: Material) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.09
	torus.outer_radius = radius
	torus.rings = 24
	var rim := MeshInstance3D.new()
	rim.mesh = torus
	rim.material_override = iron
	rim.rotation.x = PI * 0.5
	parent.add_child(rim)
	var felloe := TorusMesh.new()
	felloe.inner_radius = radius - 0.17
	felloe.outer_radius = radius - 0.08
	felloe.rings = 24
	var wood_rim := MeshInstance3D.new()
	wood_rim.mesh = felloe
	wood_rim.material_override = wood
	wood_rim.rotation.x = PI * 0.5
	parent.add_child(wood_rim)
	for i in 8:
		_box(parent, Vector3.ZERO, Vector3(0.06, radius * 2.0 - 0.25, 0.05), wood, 0.0).rotation.z = PI * float(i) / 8.0
	parent.add_child(_wheel(Vector3.ZERO, 0.12, 0.2, iron, Vector3(PI * 0.5, 0, 0)))


## Whether `at` lies over the open shaft (within `margin` of it), where nothing lies on the boards.
static func _over_shaft(s: HouseSketch, at: Vector3, margin: float) -> bool:
	var c := s.cell_world(SHAFT.x, SHAFT.y)
	return absf(at.x - c.x) < HouseSketch.CELL * 0.5 + margin and absf(at.z - c.z) < HouseSketch.CELL * 0.5 + margin


## A cobweb spun across a corner: a sagging sheet from `at` along the two walls (`a` and `b`, flat
## unit directions) and down, with a few threads drawn finer over it.
static func _cobweb(at: Vector3, a: Vector3, b: Vector3, size: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var down := Vector3(0, -size * 0.8, 0)
	# A fan of thin strips from the corner out to the wall edges, sagging in the middle.
	var rim: Array[Vector3] = []
	for i in 7:
		var t := float(i) / 6.0
		var edge: Vector3 = (a * size).lerp(b * size, t) + down * (1.0 - absf(t - 0.5) * 2.0) * 0.5
		rim.append(edge)
	for i in 6:
		st.add_vertex(at)
		st.add_vertex(at + rim[i])
		st.add_vertex(at + rim[i + 1])
	# Between the wall edges and down the corner: the hanging part.
	st.add_vertex(at + a * size)
	st.add_vertex(at + down)
	st.add_vertex(at + b * size)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


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


## The ground in front of the hut's door (north of it, on the path by the pond), `ground_y` high:
## where the testing panel's silver mine button puts the hero.
static func door_spot(ground_y: float) -> Vector3:
	var at := sketch().cell_world(HUT.position.x + HUT.size.x / 2, HUT.position.y - 2)
	return Vector3(at.x, ground_y, at.z)


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
		BED:
			return Lang.t("Dagegenlaufen, um dich hinzulegen")
		VEIN:
			return Lang.t("Dagegenlaufen, um Erz abzubauen")
	return ""


## The hero ran into a page of the log or the gate: it is read out (and the first time
## it goes into the compendium and trains Erkunden, like a writing on a wall).
static func use(game: Node, s: Dictionary) -> void:
	if s.kind == BED:
		game.show_message(Lang.t(BED_WARN), 3.5)
		return
	if s.kind == VEIN:
		dig(game, s)
		return
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


## Down in the mine (every frame the hero is): the dead rise at their posts, and the
## first time the compendium learns of the mine.
static func entered(game: Node) -> void:
	_rouse_guards(game.level)
	if game.lore.has(LEARN):
		return
	Events.teach(LEARN)
	Events.tell(Lang.t(ENTERED), Color(1.0, 0.82, 0.4))


# --- The dead, the ore and the ways down there -------------------------------

## The dead rise at their posts: each one not standing yet, and not fallen today
## (on a new day the fallen rise again).
static func _rouse_guards(level: Level) -> void:
	if _guards.size() != GUARDS.size():
		_guards.clear()
		for g: Array in GUARDS:
			_guards.append({"kind": g[0], "cell": g[1], "enemy": null, "fell": -1})
	var day := int(level.get("day")) if level.get("day") != null else 0
	for g: Dictionary in _guards:
		var e = g.enemy
		if e != null and is_instance_valid(e) and e.level == level:
			continue
		if e != null and is_instance_valid(e) and e.dead:
			continue
		if int(g.fell) == day:
			continue
		g.enemy = _raise(level, g)


static func _raise(level: Level, g: Dictionary) -> Enemy:
	var e := Enemy.new()
	e.kind = g.kind
	e.level = level
	level.add_child(e)
	e.global_position = floor_at(g.cell)
	e.reset_physics_interpolation()
	e.died.connect(func():
		level.enemy_killed.emit(e)
		g.fell = int(level.get("day")) if level.get("day") != null else 0
		# The dead of the mine fall to dust: their coins go straight into the purse.
		level.coins_collected.emit(randi_range(GUARD_PURSE[0], GUARD_PURSE[1]), CoinPile.MONEY, 0))
	level.enemies = level.enemies.filter(func(x): return is_instance_valid(x))
	level.enemies.append(e)
	return e


## The dead of the mine standing now (for the tests and the veins).
static func guards() -> Array:
	var out: Array = []
	for g: Dictionary in _guards:
		if g.enemy != null and is_instance_valid(g.enemy) and not g.enemy.dead:
			out.append(g.enemy)
	return out


## The hero hacks at a vein: not while the dead are near, once a day, a lump or two of ore,
## and at night now and then moonsilver.
static func dig(game: Node, s: Dictionary) -> void:
	var at: Vector3 = s.pos
	for e: Enemy in guards():
		if e.global_position.distance_to(at) < VEIN_GUARD:
			game.show_message(Lang.t(VEIN_GUARDED), 3.0, Color(1.0, 0.6, 0.5))
			return
	var day := int(game.level.get("day")) if game.level.get("day") != null else 0
	var key: Vector2i = s.vein
	if _dug.get(key, -1) == day:
		game.show_message(Lang.t(VEIN_SPENT), 3.0)
		return
	_dug[key] = day
	Sfx.play(game, "axe_hit_%d" % randi_range(0, 3), -6.0, null, 0.75)
	Events.tell(Lang.t(VEIN_FOUND), Color(0.8, 0.82, 0.88))
	for i in randi_range(VEIN_LUMPS[0], VEIN_LUMPS[1]):
		game.level.ingredient_collected.emit(_lump(randf()), 1, true)
	if game.level.get("night") and randf() < MOONSILVER_CHANCE:
		game.level.ingredient_collected.emit("mondsilbererz", 1, true)


## The size of lump a roll in 0..1 gives (see VEIN_ODDS).
static func _lump(roll: float) -> String:
	var sum := 0.0
	for id: String in VEIN_ODDS:
		sum += float(VEIN_ODDS[id])
		if roll < sum:
			return id
	return VEIN_ODDS.keys()[-1]


## Whether `a` and `b` are on two sides of the ground: one down in the mine, the other not.
## Nobody on one side sees, hears or reaches the other.
static func apart(a: Vector3, b: Vector3) -> bool:
	return holds(a) != holds(b)


## The way along the tunnels from `from` to `to`, both down in the mine: the middle of each
## cell after the first, then `to` itself. Empty when there is none.
static func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not holds(from) or not holds(to):
		return out
	var grid := _grid()
	var a := cell_at(from)
	var b := cell_at(to)
	if grid.is_point_solid(a) or grid.is_point_solid(b):
		return out
	var cells := grid.get_id_path(a, b)
	for i in range(1, cells.size() - 1):
		out.append(floor_at(cells[i]))
	if cells.size() > 1:
		out.append(Vector3(to.x, floor_at(b).y, to.z))
	return out


## Whether `b` can be seen from `a`, both down in the mine: no rock (and no rubble) between.
static func sight(a: Vector3, b: Vector3) -> bool:
	if not holds(a) or not holds(b):
		return false
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var steps := int(flat.length() / 0.25) + 1
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		if not _open(cell_at(Vector3(p.x, a.y, p.z))):
			return false
	return true


## The size of the mine's plot in cells (columns, rows of LAYOUT).
static func grid_size() -> Vector2i:
	return Vector2i(LAYOUT[0].length(), LAYOUT.size())


## The cells of the mine seen from `pos` (down in it): every open cell within `radius` cells
## with nothing but tunnel between, and the walls of rubble right next to those.
static func seen_from(pos: Vector3, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not holds(pos):
		return out
	var here := cell_at(pos)
	for y in range(here.y - radius, here.y + radius + 1):
		for x in range(here.x - radius, here.x + radius + 1):
			var c := Vector2i(x, y)
			if not cells().has(c) or Vector2(c - here).length() > radius + 0.5:
				continue
			var mid := floor_at(c) + Vector3(0, 0.1, 0)
			if _open(c) and sight(pos, mid):
				out.append(c)
			elif not _open(c):
				# Rubble shows where it chokes a tunnel the hero sees.
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if _open(c + d) and sight(pos, floor_at(c + d) + Vector3(0, 0.1, 0)):
						out.append(c)
						break
	return out


## Whether a shot flying from `a` to `b` hits the rock of the mine (or comes up out of it).
static func walled(a: Vector3, b: Vector3) -> bool:
	return not sight(a, b)


## The tunnels as a grid to find ways along (cells of the plot; rock and rubble are solid).
static func _grid() -> AStarGrid2D:
	if _paths != null:
		return _paths
	_paths = AStarGrid2D.new()
	_paths.region = Rect2i(0, 0, LAYOUT[0].length(), LAYOUT.size())
	_paths.cell_size = Vector2.ONE
	_paths.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_paths.update()
	for y in LAYOUT.size():
		for x in LAYOUT[0].length():
			_paths.set_point_solid(Vector2i(x, y), not _open(Vector2i(x, y)))
	return _paths


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
	# The miners' lamps went out long ago; only the one at the foot of the ladder still burns.
	for c: Vector2i in LAMPS:
		if c == LIT_LAMP:
			_lamp(parent, c)
		else:
			_dead_lamp(parent, c, rng)
	_puddles(parent, rng)
	_cobwebs(parent, rng)
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
	_powder_room(parent, body, rng)
	_ore_chamber(parent, body, rng)
	for v: Array in VEINS:
		_vein(level, parent, body, v[0], v[1], rng)


## A miner's lamp gone out: dark glass, hanging askew from its hook, or fallen and broken on the floor.
static func _dead_lamp(parent: Node3D, c: Vector2i, rng: RandomNumberGenerator) -> void:
	var iron := _mat("old_iron", IRON.darkened(0.2), 0.4)
	var glass := _mat("dead_glass", Color(0.16, 0.15, 0.13))
	if rng.randf() < 0.4:
		var at := floor_at(c) + Vector3(rng.randf_range(-0.5, 0.5), 0.12, rng.randf_range(-0.5, 0.5))
		var lamp := _box(parent, at, Vector3(0.22, 0.28, 0.22), glass)
		lamp.rotation = Vector3(PI * 0.5, rng.randf() * TAU, 0)
		_box(parent, at + Vector3(0.18, -0.08, 0.1), Vector3(0.3, 0.05, 0.3), iron, rng.randf() * TAU)
		for i in 4:
			_box(parent, at + Vector3(rng.randf_range(-0.4, 0.4), -0.1, rng.randf_range(-0.4, 0.4)), Vector3(0.06, 0.01, 0.04), glass, rng.randf() * TAU)
		return
	var at := floor_at(c) + Vector3(0, 1.95, 0)
	var hang := Node3D.new()
	hang.position = at + Vector3(0, 0.55, 0)
	hang.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
	parent.add_child(hang)
	_box(hang, Vector3(0, -0.2, 0), Vector3(0.03, 0.4, 0.03), iron)
	_box(hang, Vector3(0, -0.55, 0), Vector3(0.22, 0.28, 0.22), glass)
	_box(hang, Vector3(0, -0.39, 0), Vector3(0.3, 0.05, 0.3), iron)
	_box(hang, Vector3(0, -0.71, 0), Vector3(0.3, 0.05, 0.3), iron)


## Water seeping through the rock into puddles on the floor: dark and still, with a wet rim.
static func _puddles(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var water := _mat("puddle", Color(0.12, 0.15, 0.17, 0.75))
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.metallic_specular = 1.0
	water.roughness = 0.04
	var wet := _mat("wet_rim", Color(0.06, 0.05, 0.05, 0.45))
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.roughness = 0.3
	for c: Vector2i in PUDDLES:
		var at := floor_at(c) + Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
		var radius := rng.randf_range(0.4, 0.7)
		var wobble := rng.randf() * TAU
		for layer in [[radius * 1.3, 0.012, wet], [radius, 0.02, water]]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_normal(Vector3.UP)
			var rim: Array[Vector3] = []
			for i in 24:
				var a := TAU * i / 24.0
				var r: float = layer[0] * (0.8 + 0.2 * sin(a * 3.0 + wobble) + 0.06 * sin(a * 7.0 + wobble * 3.0))
				rim.append(Vector3(cos(a) * r * 1.3, 0, sin(a) * r))
			for i in 24:
				st.add_vertex(Vector3.ZERO)
				st.add_vertex(rim[(i + 1) % 24])
				st.add_vertex(rim[i])
			var m := MeshInstance3D.new()
			m.mesh = st.commit()
			m.material_override = layer[2]
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.position = at + Vector3(0, layer[1], 0)
			m.rotation.y = rng.randf() * TAU
			parent.add_child(m)


## Cobwebs up in the corners where two walls meet, thick in the far drifts nobody walked for years.
static func _cobwebs(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var mats: Array[StandardMaterial3D] = []
	for k in 3:
		var m := StandardMaterial3D.new()
		m.albedo_texture = DungeonLife._web_texture(k)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		m.albedo_color = Color(0.85, 0.85, 0.82, 0.8)
		m.roughness = 1.0
		mats.append(m)
	var top := HouseSketch.DEPTH - 0.08
	var half := HouseSketch.CELL * 0.5 - 0.06
	for c: Vector2i in cells():
		if not _open(c) or c == SHAFT:
			continue
		for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			# A corner of two walls: both neighbours on its sides are rock.
			if _open(c + Vector2i(d.x, 0)) or _open(c + Vector2i(0, d.y)):
				continue
			if rng.randf() > WEB_CHANCE:
				continue
			var size := rng.randf_range(0.5, 0.9)
			var corner := floor_at(c) + Vector3(d.x * half, top, d.y * half)
			var a := corner + Vector3(-d.x * size, -size * rng.randf_range(0.3, 0.8), 0)
			var b := corner + Vector3(0, -size * rng.randf_range(0.3, 0.8), -d.y * size)
			parent.add_child(_web_sheet(corner, a, b, mats[rng.randi() % 3]))


## A sheet of web from `corner` (where its threads meet) to `a` and `b` (see DungeonLife._web).
static func _web_sheet(corner: Vector3, a: Vector3, b: Vector3, mat: Material) -> MeshInstance3D:
	var far := a + b - corner
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal((a - corner).cross(b - corner).normalized())
	for v in [[corner, Vector2(0, 0)], [a, Vector2(1, 0)], [far, Vector2(1, 1)], [corner, Vector2(0, 0)], [far, Vector2(1, 1)], [b, Vector2(0, 1)]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## The powder room off the cleft: kegs burst open, crates smashed, a table broken in two,
## planks and black powder all over the floor.
static func _powder_room(parent: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var wood := _mat("old_wood", TIMBER.darkened(0.1))
	var powder := _mat("powder", Color(0.08, 0.08, 0.09))
	# Burst kegs: a ring of staves round a heap of spilt powder.
	for c: Vector2i in [Vector2i(15, 15), Vector2i(19, 15), Vector2i(19, 18)]:
		var mid := floor_at(c) + Vector3(0.3 * (1.0 if c.x > 17 else -1.0), 0, 0.3 * (1.0 if c.y > 16 else -1.0))
		_box(parent, mid + Vector3(0, 0.015, 0), Vector3(1.0, 0.02, 0.8), powder, rng.randf() * TAU)
		for i in 7:
			var a := TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)
			var stave := _box(parent, mid + Vector3(cos(a) * 0.35, 0.3, sin(a) * 0.35), Vector3(0.12, 0.6 * rng.randf_range(0.5, 1.0), 0.04), wood, -a)
			stave.rotation.x = rng.randf_range(-0.6, 0.6)
		_box(parent, mid + Vector3(0, 0.05, 0), Vector3(0.6, 0.04, 0.6), _mat("iron", IRON, 0.6), rng.randf())
		_solid(body, mid + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9))
	_broken_heap(parent, body, floor_at(Vector2i(15, 18)) + Vector3(-0.3, 0, 0.3), rng)
	# The broken table: two halves tipped against each other.
	var t := floor_at(Vector2i(17, 15)) + Vector3(0, 0, -0.3)
	for side in [-1.0, 1.0]:
		var half_top := _box(parent, t + Vector3(side * 0.45, 0.35, 0), Vector3(0.8, 0.07, 0.8), wood)
		half_top.rotation.z = side * 0.7
		_box(parent, t + Vector3(side * 0.75, 0.3, 0.3), Vector3(0.07, 0.6, 0.07), wood)
	_solid(body, t + Vector3(0, 0.4, 0), Vector3(1.8, 0.8, 0.9))
	DungeonLife.bone_pile(parent, floor_at(Vector2i(18, 17)), rng, 1.0)
	_strewn(parent, wood, Rect2i(15, 15, 5, 4), 14, rng)


## The ore chamber at the end of the south drift: baskets of ore, a broken barrow and picks,
## and the vein in its far wall (see VEINS).
static func _ore_chamber(parent: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var wood := _mat("old_wood", TIMBER.darkened(0.1))
	var ore := _mat("ore", Color(0.3, 0.29, 0.3))
	# Two wicker baskets of ore, one tipped over.
	for i in 2:
		var mid := floor_at(Vector2i(10 + i, 45)) + Vector3(-0.2, 0, -0.45)
		var basket := _box(parent, mid + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), _mat("wicker", Color(0.42, 0.33, 0.2)))
		if i == 1:
			basket.rotation.z = PI * 0.5
			basket.position.y = 0.3 + mid.y
		for k in 5:
			var lump := _box(parent, mid + Vector3(rng.randf_range(-0.3, 0.3) + (0.6 if i == 1 else 0.0), 0.62 if i == 0 else 0.1, rng.randf_range(-0.3, 0.3)), Vector3.ONE * rng.randf_range(0.14, 0.24), ore)
			lump.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		_solid(body, mid + Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.7))
	# A wheelbarrow with its wheel off.
	var barrow := floor_at(Vector2i(14, 45)) + Vector3(0.2, 0, -0.2)
	var tray := _box(parent, barrow + Vector3(0, 0.35, 0), Vector3(0.7, 0.3, 1.1), wood, 0.4)
	tray.rotation.x = 0.25
	for side in [-0.3, 0.3]:
		_box(parent, barrow + Vector3(side, 0.3, 0.8), Vector3(0.06, 0.06, 0.9), wood, 0.4)
	var wheel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.25
	cyl.height = 0.07
	wheel.mesh = cyl
	wheel.material_override = wood
	wheel.position = barrow + Vector3(-0.6, 0.04, 0.6)
	parent.add_child(wheel)
	_solid(body, barrow + Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 1.2))
	_broken_heap(parent, body, floor_at(Vector2i(10, 46)) + Vector3(-0.3, 0, 0.3), rng)
	DungeonLife.bone_pile(parent, floor_at(Vector2i(13, 45)) + Vector3(0, 0, -0.5), rng, 1.0)
	_strewn(parent, wood, Rect2i(10, 45, 5, 2), 8, rng)


## A heap of smashed crates against a wall: boards, a lid, a broken frame.
static func _broken_heap(parent: Node3D, body: StaticBody3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var wood := _mat("old_wood", TIMBER.darkened(0.1))
	for i in 7:
		var board := _box(parent, at + Vector3(rng.randf_range(-0.35, 0.35), 0.06 + i * 0.07, rng.randf_range(-0.35, 0.35)), Vector3(rng.randf_range(0.5, 0.9), 0.04, 0.16), wood, rng.randf() * TAU)
		board.rotation.x = rng.randf_range(-0.4, 0.4)
	var frame := _box(parent, at + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.06), wood, rng.randf() * TAU)
	frame.rotation.z = 0.9
	_solid(body, at + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9))


## Planks and splinters strewn over the floor of cells `area` (flat on the floor, nothing to trip on).
static func _strewn(parent: Node3D, wood: Material, area: Rect2i, n: int, rng: RandomNumberGenerator) -> void:
	for i in n:
		var c := Vector2i(rng.randi_range(area.position.x, area.end.x - 1), rng.randi_range(area.position.y, area.end.y - 1))
		_box(parent, floor_at(c) + Vector3(rng.randf_range(-0.7, 0.7), 0.025, rng.randf_range(-0.7, 0.7)), Vector3(rng.randf_range(0.2, 0.9), 0.03, rng.randf_range(0.06, 0.16)), wood, rng.randf() * TAU)


## A vein of ore in the wall at the end of a drift: dark lumps and glints of silver in the rock,
## broken stone at its foot and an old pick left by it. The hero runs into it to hack (see dig).
static func _vein(level: Level, parent: Node3D, body: StaticBody3D, c: Vector2i, wall: Vector2i, rng: RandomNumberGenerator) -> void:
	var out := Vector3(wall.x, 0, wall.y)
	var across := Vector3(-out.z, 0, out.x)
	var face := floor_at(c) + out * (HouseSketch.CELL * 0.5 - 0.08)
	var turn := atan2(out.x, out.z)
	var silver: Material = _silver()
	var ore := _mat("ore_vein", Color(0.24, 0.22, 0.25), 0.3)
	for i in 9:
		var lump := _ore_chunk(parent, face + across * rng.randf_range(-0.8, 0.8) + Vector3(0, rng.randf_range(0.3, 2.2), 0), rng.randf_range(0.4, 0.7), rng, ore, silver, i % 2 == 0)
		lump.rotation = Vector3(0, turn, rng.randf_range(-0.5, 0.5))
		lump.scale.z *= 0.45
	for i in 7:
		var streak := _box(parent, face - out * 0.06 + across * rng.randf_range(-0.8, 0.8) + Vector3(0, rng.randf_range(0.4, 2.1), 0), Vector3(rng.randf_range(0.2, 0.6), rng.randf_range(0.04, 0.09), 0.06), silver, turn)
		streak.rotation.z = rng.randf_range(-0.5, 0.5)
	var glint := OmniLight3D.new()
	glint.light_color = SILVER
	glint.light_energy = 0.5
	glint.omni_range = 2.5
	glint.position = face - out * 0.5 + Vector3(0, 1.2, 0)
	parent.add_child(glint)
	var rock := _mat("rubble", Color(0.36, 0.33, 0.3))
	for i in 8:
		var stone := _box(parent, face - out * rng.randf_range(0.2, 0.7) + across * rng.randf_range(-0.7, 0.7) + Vector3(0, 0.08, 0), Vector3.ONE * rng.randf_range(0.12, 0.28), rock)
		stone.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
	# An old pick leant against the rock.
	var pick := face - out * 0.25 + across * 0.6
	var handle := _box(parent, pick + Vector3(0, 0.5, 0), Vector3(0.06, 1.0, 0.06), _mat("timber", TIMBER), turn)
	handle.rotation.x = 0.25
	_box(parent, pick + Vector3(0, 1.0, 0) - out * 0.1, Vector3(0.5, 0.07, 0.07), _mat("iron", IRON, 0.6), turn + PI * 0.5)
	var at := floor_at(c) + out * 0.5
	level.stations.append({"kind": VEIN, "vein": c, "pos": at, "cell": level.world_to_cell(at), "used": false, "touch": 1.3})


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


## The rock around the silver: the cleft's cracked stone, darker and bluish, with thin pale
## veins of ore running through it (the bright tops of the noise), so the silver seems to grow
## out of the stone and not out of the timber.
static func ore_rock_material() -> StandardMaterial3D:
	if _mats.has("ore_rock_wall"):
		return _mats["ore_rock_wall"]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	noise.seed = 19
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.color_ramp = Gradient.new()
	tex.color_ramp.offsets = PackedFloat32Array([0.0, 0.55, 0.8, 0.9, 1.0])
	tex.color_ramp.colors = PackedColorArray([Color(0.12, 0.12, 0.14), Color(0.24, 0.24, 0.27), Color(0.34, 0.33, 0.35), Color(0.55, 0.58, 0.64), Color(0.8, 0.83, 0.9)])
	var bumps := NoiseTexture2D.new()
	bumps.noise = noise
	bumps.seamless = true
	bumps.width = 256
	bumps.height = 256
	bumps.as_normal_map = true
	bumps.bump_strength = 8.0
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = bumps
	m.roughness = 0.8
	m.metallic = 0.25
	m.metallic_specular = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.4, 0.4, 0.4)
	_mats["ore_rock_wall"] = m
	return m


## The raw silver of the mine: bright metal that glimmers now and then (see silver_glint.gdshader).
static func _silver() -> ShaderMaterial:
	if not _mats.has("silver_glint"):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/silver_glint.gdshader")
		m.set_shader_parameter("silver", SILVER.darkened(0.25))
		_mats["silver_glint"] = m
	return _mats["silver_glint"]


## A lump of ore: a rough, uneven chunk of dark rock with flecks and thin shards of silver
## sitting in its surface. A rich one carries more and bigger flecks and a small nugget.
static func _ore_chunk(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator, rock: Material, silver: Material, rich := false) -> MeshInstance3D:
	var chunk := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radial_segments = 7
	ball.rings = 4
	ball.radius = size * 0.5
	ball.height = size
	chunk.mesh = ball
	chunk.material_override = rock
	chunk.position = at
	chunk.scale = Vector3(rng.randf_range(0.85, 1.35), rng.randf_range(0.65, 1.0), rng.randf_range(0.85, 1.3))
	chunk.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
	parent.add_child(chunk)
	var r := size * 0.5
	for i in (5 if rich else 3):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
		var fleck := MeshInstance3D.new()
		var flake := BoxMesh.new()
		var w := r * rng.randf_range(0.35, 0.8 if rich else 0.55)
		flake.size = Vector3(w, r * 0.07, w * rng.randf_range(0.4, 0.9))
		fleck.mesh = flake
		fleck.material_override = silver
		fleck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fleck.position = dir * r * 0.93
		fleck.look_at_from_position(fleck.position, dir * r * 2.0, Vector3.UP)
		fleck.rotate_object_local(Vector3(0, 0, 1), rng.randf() * TAU)
		chunk.add_child(fleck)
	if rich:
		var nugget := MeshInstance3D.new()
		var bead := SphereMesh.new()
		bead.radial_segments = 6
		bead.rings = 3
		bead.radius = r * 0.22
		bead.height = r * 0.36
		nugget.mesh = bead
		nugget.material_override = silver
		nugget.position = Vector3(r * 0.3, r * 0.7, r * 0.2)
		chunk.add_child(nugget)
	return chunk


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


## Whether cell `c` is a plain stretch of tunnel running along `ahead`: open to neither side.
static func _straight(c: Vector2i, ahead: Vector2i) -> bool:
	var side := Vector2i(ahead.y, ahead.x)
	return not _open(c + side) and not _open(c - side)


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
		# None where the tunnel opens into a room or a crossing: from above a set there reads as
		# bars across the way.
		var ahead := Vector2i(0, 1) if along_z else Vector2i(1, 0)
		if not _straight(c + ahead, ahead) or not _straight(c - ahead, ahead):
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
## It stands with its back against a wall of its cell (the one `offset` leans towards, if that is a
## wall) and its front, where the lid opens, to the room.
static func _chest(level: Level, parent: Node3D, body: StaticBody3D, c: Vector2i, offset: Vector3, _turn := 0.0) -> void:
	var back := Vector2i.ZERO
	var best := -INF
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if cells().has(c + d):
			continue
		var lean := Vector2(d).dot(Vector2(offset.x, offset.z))
		if lean > best:
			best = lean
			back = d
	var along := Vector3(back.x, 0, back.y)
	# Along the wall it keeps its offset; across, its back stands just off the wall.
	var slide := offset - along * along.dot(offset)
	var pos := floor_at(c) + slide + along * (HouseSketch.CELL * 0.5 - CHEST_FROM_WALL)
	# The fitted chests open to their +Z: turned so that +Z points away from the wall.
	var turn := atan2(-along.x, -along.z)
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
## Gives a clean kit prop (a crate, a barrel) the worn grain, grime and rust of the props
## outside, so it does not shine among the old mine's things. A model with a palette keeps its
## colours, one with plain colours takes them darkened and aged.
static func _age_prop(node: Node) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var source := mi.get_active_material(0) as StandardMaterial3D
		if source == null or source.emission_enabled:
			continue
		if source.albedo_texture:
			mi.material_override = WeatheredProps.palette_material(source.albedo_texture, WeatheredProps.IRON)
		else:
			mi.material_override = WeatheredProps.colour_material(source.albedo_color.darkened(0.3), WeatheredProps.WOOD)


static func _piece(level: Level, parent: Node3D, body: StaticBody3D, piece: String, at: Vector3, turn: float, foot: Vector2, high := 1.2) -> Node3D:
	var node := level._place(piece, at, turn, parent)
	_age_prop(node)
	if foot != Vector2.ZERO:
		_solid(body, at + Vector3(0, high * 0.5, 0), Vector3(foot.x, high, foot.y))
	return node


## The tool store east of the shaft: crates, barrels, a rack of picks and the first page.
static func _tool_store(level: Level, parent: Node3D, body: StaticBody3D) -> void:
	_piece(level, parent, body, "crates_stacked", floor_at(Vector2i(47, 29)) + Vector3(0.2, 0, -0.2), 0.3, Vector2(1.4, 1.4), 1.8)
	_piece(level, parent, body, "barrel_small", floor_at(Vector2i(44, 32)) + Vector3(-0.4, 0, 0.4), 0.0, Vector2(0.8, 0.8))
	_piece(level, parent, body, "barrel_small", floor_at(Vector2i(45, 32)) + Vector3(-0.3, 0, 0.5), 1.0, Vector2(0.8, 0.8))
	_piece(level, parent, body, "box_large", floor_at(Vector2i(47, 31)) + Vector3(0.3, 0, 0), 0.2, Vector2(1.2, 1.2))
	# A rack of picks and shovels against the east wall (clear of the way out to the south).
	var wood := _mat("timber", TIMBER)
	var iron := _mat("iron", IRON, 0.6)
	var turn := PI * 0.5
	var b := Basis(Vector3.UP, turn)
	var rack := floor_at(Vector2i(47, 30)) + Vector3(0.72, 0, 0)
	_box(parent, rack + b * Vector3(0, 1.3, 0), Vector3(1.6, 0.08, 0.12), wood, turn)
	for i in 4:
		var x := -0.6 + i * 0.4
		var handle := _box(parent, rack + b * Vector3(x, 0.75, -0.08), Vector3(0.06, 1.4, 0.06), wood, turn)
		handle.rotation.z = 0.08
		_box(parent, rack + b * Vector3(x + 0.05, 1.42, -0.08), Vector3(0.5 if i % 2 == 0 else 0.22, 0.07, 0.07), iron, turn)
	_solid(body, rack + b * Vector3(0, 0.8, -0.1), Vector3(0.4, 1.6, 1.7))
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
		level.stations.append({"kind": BED, "pos": mid, "cell": level.world_to_cell(mid), "used": false, "touch": 1.4})
	_piece(level, parent, body, "table_medium_decorated_A", floor_at(Vector2i(34, 34)), PI * 0.5, Vector2(1.4, 1.8), 1.0)
	_piece(level, parent, body, "stool", floor_at(Vector2i(35, 34)) + Vector3(0.2, 0, 0), 0.4, Vector2.ZERO)
	_chest(level, parent, body, Vector2i(37, 33), Vector3(0.2, 0, -0.2), PI)


## The silver vein: bright streaks in the north wall of the chamber over the gallery,
## a pick left in the rock and broken stone on the floor.
static func _silver_vein(parent: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var silver: Material = _silver()
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
	var silver: Material = _silver()
	var load_rng := RandomNumberGenerator.new()
	load_rng.seed = 57
	for i in 9:
		_ore_chunk(parent, cart + Vector3(-0.3 + (i % 3) * 0.3, 1.08, -0.45 + (i / 3) * 0.45), 0.36, load_rng, _mat("ore", Color(0.3, 0.29, 0.3)), silver, i % 2 == 0)
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
		_ore_chunk(parent, heap + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.1, 0.5), rng.randf_range(-0.6, 0.6)), rng.randf_range(0.28, 0.52), rng, ore, silver, i % 4 == 0)
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
	# Against the west wall, facing east, out of the way from the north door to the south one.
	var turn := PI * 0.5
	var b := Basis(Vector3.UP, turn)
	var altar := (floor_at(Vector2i(2, 34)) + floor_at(Vector2i(2, 35))) * 0.5 + Vector3(-0.3, 0, 0)
	_box(parent, altar + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.9), stone, turn)
	_solid(body, altar + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.9))
	# The goddess: a rough stone figure with a pale glint for a face.
	_box(parent, altar + b * Vector3(0, 1.35, -0.1), Vector3(0.35, 0.7, 0.3), stone, turn)
	_box(parent, altar + b * Vector3(0, 1.82, -0.1), Vector3(0.24, 0.26, 0.24), stone, turn)
	_box(parent, altar + b * Vector3(0, 1.84, 0.03), Vector3(0.14, 0.05, 0.02), _mat("rune", RUNE_COLOUR, 0.0, 3.0), turn)
	for x in [-0.65, 0.65]:
		level._place("candle_triple", altar + b * Vector3(x, 1.0, 0.1), turn, parent)
	var coins := level._place("coin_stack_large", altar + b * Vector3(0.3, 1.0, 0.25), 0.4, parent)
	coins.scale = Vector3.ONE * 0.45
	_piece(level, parent, body, "stool", floor_at(Vector2i(3, 36)), 0.0, Vector2(0.8, 0.8), 0.7)
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


## The sealed gate at the end of the old works: a stone door behind a grille of iron bars that
## fills the passage from wall to wall and floor to roof, a heavy chain across it with a padlock,
## and runes glowing round it. It does not open.
static func _gate(level: Level, parent: Node3D, body: StaticBody3D) -> void:
	var stone := HouseLooks.temple_stone()
	var iron := _mat("gate_iron", Color(0.42, 0.42, 0.46), 0.75)
	var rust := _mat("gate_rust", Color(0.45, 0.26, 0.14), 0.3)
	var glow := _mat("rune", RUNE_COLOUR, 0.0, 3.0)
	var base := floor_at(GATE_CELL)
	var face := base + Vector3(0, 0, -0.85)
	var high := HouseSketch.DEPTH - 0.1
	# The frame: two jambs from wall to bars and a lintel under the roof.
	for side in [-1.0, 1.0]:
		_box(parent, face + Vector3(side * 0.86, high * 0.5, 0.05), Vector3(0.28, high, 0.34), stone)
	_box(parent, face + Vector3(0, high - 0.17, 0.05), Vector3(2.0, 0.34, 0.38), stone)
	# The door behind: dark stone with a glowing rune at its heart.
	_box(parent, face + Vector3(0, (high - 0.34) * 0.5, -0.06), Vector3(1.44, high - 0.34, 0.16), _mat("gate_stone", Color(0.17, 0.17, 0.2)))
	for i in 7:
		var a := float(i) / 6.0 * PI
		_box(parent, face + Vector3(cos(a) * 0.5, 1.85 + sin(a) * 0.16, 0.03), Vector3(0.07, 0.14, 0.02), glow)
	_box(parent, face + Vector3(0, 1.1, 0.03), Vector3(0.26, 0.26, 0.02), glow)
	# The grille in front: upright bars from the floor to the lintel, three bands across.
	var bars_z := 0.2
	for i in 8:
		var x := -0.63 + i * 0.18
		_box(parent, face + Vector3(x, (high - 0.34) * 0.5, bars_z), Vector3(0.06, high - 0.34, 0.06), iron)
		# Spikes at the foot, sunk into the flagstones.
		_box(parent, face + Vector3(x, 0.04, bars_z), Vector3(0.1, 0.08, 0.1), rust)
	for y in [0.3, 1.2, 2.0]:
		_box(parent, face + Vector3(0, y, bars_z + 0.04), Vector3(1.46, 0.1, 0.05), iron)
	# A heavy chain looped across the bars in an X, and a padlock where it meets.
	var lock_at := face + Vector3(0, 1.15, bars_z + 0.14)
	for end in [Vector3(-0.66, 1.9, 0), Vector3(0.66, 1.9, 0), Vector3(-0.66, 0.45, 0), Vector3(0.66, 0.45, 0)]:
		var from: Vector3 = face + end + Vector3(0, 0, bars_z + 0.1)
		var links := 6
		for k in links:
			var t := (float(k) + 0.5) / float(links)
			var link := _box(parent, from.lerp(lock_at, t), Vector3(0.1, 0.05, 0.03), rust)
			var d := lock_at - from
			# Every other link turned a quarter round its length, as chain links are.
			link.rotation = Vector3(0.0 if k % 2 == 0 else PI * 0.5, 0, atan2(d.y, d.x))
	_box(parent, lock_at + Vector3(0, -0.06, 0.02), Vector3(0.26, 0.24, 0.12), _mat("padlock", Color(0.5, 0.42, 0.22), 0.8))
	_box(parent, lock_at + Vector3(0, 0.1, 0.02), Vector3(0.18, 0.12, 0.04), iron)
	_box(parent, lock_at + Vector3(0, -0.08, 0.085), Vector3(0.04, 0.08, 0.01), _mat("keyhole", Color(0.05, 0.05, 0.06)))
	# Light: the runes' cold glow, and a lamp left hanging in front so the gate is seen from afar.
	var light := OmniLight3D.new()
	light.light_color = RUNE_COLOUR
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position = face + Vector3(0, 1.6, 0.9)
	parent.add_child(light)
	_lamp(parent, GATE_CELL + Vector2i(0, 1))
	_solid(body, face + Vector3(0, high * 0.5, 0.1), Vector3(2.0, high, 0.5))
	level.stations.append({"kind": GATE, "pos": base + Vector3(0, 0, -0.6), "cell": level.world_to_cell(base), "used": false, "touch": 1.6})
