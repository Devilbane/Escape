class_name AppleTree
extends RefCounted
## The apple tree of the garden (see GardenDecor and HouseFurniture.KINDS "apfelbaum"): Ilse sells
## it as a seedling, the hero plants it in the open-air part of their plot, and it grows through
## the years and follows the seasons.
##
## Growth goes by the season days (see Weather.season and Outdoor.season_day) since it was planted
## (the piece's "planted" in HouseFurniture.placed, kept in the furniture books with the house):
##   Setzling          its first season: a sprig tied to a stake;
##   Bäumchen          the rest of its first year: a thin trunk with a little crown;
##   Junger Apfelbaum  its second year: it blossoms in spring and bears a few apples;
##   Apfelbaum         from its third year on: a broad crown, white with blossom in spring, full of
##                     apples in summer and autumn.
## With a season of one real week that is a sapling after a week, a young tree bearing fruit after
## four weeks and a full-grown tree after eight.
##
## The seasons: blossom in spring, green leaves and red apples in summer, red, orange and gold
## leaves (and apples) in autumn, bare branches in winter with a few withered leaves left on the
## twigs. While snow lies (see SnowCover) it rests on the crown: ridges along the tops of the
## limbs, tufts in the forks and on the twigs' ends, and caps over the clumps of leaves when it
## snows in a season in leaf (see _snow). Running into a tree with apples picks
## them all into the bag (Items "apfel", which deer love, see Companions); a tree bears again the
## next season it is in fruit (once in summer, once in autumn).
##
## Moved or turned with the furnishing tool, it keeps its age; picked up into the store, or sent
## back when a roof is built over it, it is a seedling again.

## The furniture kind, and its station (see Game._use_station).
const KIND := "apfelbaum"
const STATION := "apfelbaum"
## What a picked apple is.
const APPLE := "apfel"

## The growth stages.
const SEEDLING := 0
const SAPLING := 1
const YOUNG := 2
const MATURE := 3
const STAGE_NAMES := ["Setzling", "Bäumchen", "Junger Apfelbaum", "Apfelbaum"]
## When each stage starts, in seasons since planting.
const STAGE_FROM := [0, 1, 4, 8]
## The apples a tree bears each season it is in fruit, by stage.
const APPLES := [0, 0, 4, 12]

## What the compendium says once the hero has picked apples.
const LEARN := "Apfelbäume: Bei Raumausstatterin Ilse kaufst du einen Setzling für deinen Garten (unter freiem Himmel auf deinem Grundstück). Er wächst mit den Jahreszeiten: nach einer Jahreszeit ist er ein Bäumchen, im zweiten Jahr ein junger Baum, der blüht und ein paar Äpfel trägt, ab dem dritten Jahr ein großer Apfelbaum. Im Frühling blüht er, im Sommer und im Herbst hängen Äpfel daran: Lauf dagegen, um sie zu pflücken. Rehe lieben Äpfel. Verschiebst du den Baum, behält er sein Alter; nimmst du ihn ins Lager, ist er wieder ein Setzling."

## Leaves by season, blossom and apple colours, bark.
const LEAF := {"spring": Color(0.4, 0.64, 0.24), "summer": Color(0.2, 0.44, 0.15)}
## How many of the leaves are still green in autumn, among the turned ones.
const AUTUMN_GREEN := 0.3
const AUTUMN_LEAVES := [Color(0.7, 0.4, 0.12), Color(0.72, 0.56, 0.18), Color(0.54, 0.22, 0.1), Color(0.46, 0.44, 0.16), Color(0.62, 0.3, 0.1)]
const BLOSSOM := [Color(0.98, 0.96, 0.94), Color(0.98, 0.84, 0.88), Color(0.96, 0.74, 0.8)]
const APPLE_COLOUR := Color(0.78, 0.12, 0.09)
## The unripened side of an apple, and how many apples hang on the model for each one a picking
## brings in.
const APPLE_GREEN := Color(0.56, 0.7, 0.16)
const HANGING := 5
const BARK := Color(0.33, 0.24, 0.17)
## The few withered leaves a bare tree keeps through the winter: their colours, how many of the
## twigs of a tree old enough to bear hold a bunch, and how many leaves in a bunch.
const WITHERED := [Color(0.42, 0.29, 0.16), Color(0.5, 0.36, 0.2), Color(0.36, 0.25, 0.15), Color(0.46, 0.38, 0.24)]
const WITHERED_SHARE := 0.3
const WITHERED_BUNCH := Vector2i(3, 6)
## The snow on the crown (see _snow): how deep it lies on a level limb against the limb's
## thickness, and the least and most; how thick it lies on a leaf against the leaf's length.
const SNOW_ON_LIMB := 1.1
const SNOW_LIMB_RANGE := Vector2(0.012, 0.075)
const SNOW_ON_LEAF := 0.16
## Single leaves on a full-sized clump of leaves (fewer on a smaller one).
const LEAVES_PER_CLUMP := 62
## The grass round a tree's foot: its radius for a seedling, and how much wider each stage.
const PATCH_RADIUS := 0.55
const PATCH_GROWS := 0.2
const GRASS := Color(0.3, 0.5, 0.17)
const GRASS_TIP := Color(0.48, 0.66, 0.26)
const STONES := [Color(0.42, 0.4, 0.36), Color(0.36, 0.35, 0.33), Color(0.47, 0.43, 0.37), Color(0.32, 0.32, 0.31), Color(0.4, 0.37, 0.32)]

## The shape of the tree at each stage: the trunk's height and thickness, how many limbs fork
## off its top, how far they reach and lean out, how many times they fork again (see _grow), and
## the size of a clump of leaves at a twig's end.
const SHAPES := [
	{"trunk": 0.3, "thick": 0.012, "limbs": 3, "reach": 0.18, "spread": 0.9, "depth": 0, "clump": 0.07},
	{"trunk": 1.15, "thick": 0.035, "limbs": 3, "reach": 0.58, "spread": 0.8, "depth": 1, "clump": 0.16},
	{"trunk": 2.05, "thick": 0.11, "limbs": 4, "reach": 1.2, "spread": 0.8, "depth": 2, "clump": 0.36},
	{"trunk": 2.85, "thick": 0.22, "limbs": 5, "reach": 1.65, "spread": 0.8, "depth": 3, "clump": 0.5},
]

static var _balls := {}
static var _mats := {}


## The length of a season in season days.
static func season_days() -> int:
	return maxi(1, Weather.YEAR_DAYS / 4)


## How many season days the tree has grown on `day` (never less than none).
static func age(piece: Dictionary, day: int) -> int:
	return maxi(0, day - int(piece.get("planted", day)))


## The growth stage of a tree on `day`.
static func stage(piece: Dictionary, day: int) -> int:
	var seasons := age(piece, day) / season_days()
	var out := SEEDLING
	for i in STAGE_FROM.size():
		if seasons >= STAGE_FROM[i]:
			out = i
	return out


## Which season of all time `day` is in (each harvest is kept by it).
static func season_index(day: int) -> int:
	return floori(float(day) / season_days())


## Whether the tree's season on `day` is one for apples (summer and autumn).
static func fruit_season(day: int) -> bool:
	var s := Weather.season(day)
	return s == Weather.SUMMER or s == Weather.AUTUMN


## How many apples hang on the tree on `day`.
static func apples(piece: Dictionary, day: int) -> int:
	if not fruit_season(day) or int(piece.get("picked", -999999)) == season_index(day):
		return 0
	return APPLES[stage(piece, day)]


## Season days until the tree first bears apples (0 once it does).
static func days_to_fruit(piece: Dictionary, day: int) -> int:
	return maxi(0, STAGE_FROM[YOUNG] * season_days() - age(piece, day))


## The prompt beside the tree.
static func prompt(piece: Dictionary, day: int) -> String:
	var n := apples(piece, day)
	if n > 0:
		return Lang.t("Dagegenlaufen, um %d Äpfel zu pflücken") % n
	var name := Lang.t(STAGE_NAMES[stage(piece, day)])
	var wait := days_to_fruit(piece, day)
	if wait > 0:
		return Lang.t("%s: Er trägt in %d Tagen zum ersten Mal Äpfel.") % [name, wait]
	if fruit_season(day):
		return Lang.t("%s: Abgeerntet. Zur nächsten Erntezeit reifen neue Äpfel.") % name
	return Lang.t("%s: Äpfel reifen im Sommer und im Herbst.") % name


## The prompt beside the hero's own tree a station belongs to.
static func station_prompt(game: Node, station: Dictionary) -> String:
	var piece := _own_piece(game.house_furnisher, station)
	return "" if piece.is_empty() else prompt(piece, game.level.season_day)


## The hero runs into their tree: every apple on it goes into the bag while there is room.
static func pick(game: Node, station: Dictionary) -> void:
	var furnisher: HouseFurnisher = game.house_furnisher
	var day: int = game.level.season_day
	var piece := _own_piece(furnisher, station)
	if piece.is_empty():
		return
	var n := apples(piece, day)
	if n <= 0:
		game.show_message(prompt(piece, day), 3.0)
		return
	var player: Player = game.player
	var got := 0
	while got < n and player.bag_fits(APPLE):
		player.bag.append(APPLE)
		got += 1
	if got == 0:
		game.show_message(Lang.t("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg."), 2.6)
		return
	# What did not fit stays lost: the tree is picked for this season.
	piece.picked = season_index(day)
	furnisher.furniture.save(game.hero_name)
	player.play_flourish("PickUp", 0.6)
	Sfx.play(game, "gear_soft_0", -2.0, station.pos)
	Effects.loot_text(game.level, player.global_position + Vector3(0, 3.0, 0), "+%d %s" % [got, Items.item_name(APPLE)], APPLE_COLOUR.lightened(0.3), DamageNumber.item_worth(APPLE))
	var said := Lang.t("Du pflückst einen Apfel.") if got == 1 else Lang.t("Du pflückst %d Äpfel.") % got
	if got < n:
		said += " " + Lang.t("Für mehr ist kein Platz in deiner Tasche.")
	game.show_message(said, 3.0)
	Events.teach(LEARN)
	furnisher.refresh()
	game._update_hud()


## The placed tree of the hero's furniture that a station belongs to, or {}.
static func _own_piece(furnisher: HouseFurnisher, station: Dictionary) -> Dictionary:
	var at: Dictionary = station.get("piece", {})
	for p in furnisher.furniture.placed:
		if p.kind == KIND and p.storey == at.get("storey") and p.x == at.get("x") and p.y == at.get("y"):
			return p
	return {}


## The village's apple trees: four full-grown ones round the fountain on the square, on the
## paved cells between its benches (the diagonal neighbours of the fountain). They follow the
## seasons like a garden tree, with apples to see in summer and autumn (not to pick: they belong
## to the village). A grown-up tree, planted long ago.
const VILLAGE_TREE := {"planted": -100000}
## Their size against a garden tree's.
const VILLAGE_SCALE := 1.0
## Round the fountain: the cells between the benches.
const ROUND_FOUNTAIN := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
## How far the trunk stands out of the cell's middle along each axis, away from the fountain (m).
const TRUNK_OUT := 1.1
## The gardens' apple trees (see plant_in_village): within this many tiles of a building, this many
## tiles apart at least, and this far from any door (m).
const GARDEN_REACH := 3
const TREE_SPACING := 3
const DOOR_CLEAR := 4.0
## The tiles that frame a grass pocket (see plant_in_pockets): paths, the paved square and street drains (flush with the street).
const PAVED := [",", ":", "\\", "Ξ"]
## A pocket's four tiles, from its top left one.
const POCKET_TILES: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ONE]
## How far the trunk steps aside along each axis from a lamp post on one of the pocket's tiles (m).
const POCKET_LAMP_STEP := 0.8


## Plants the apple trees round every fountain of `level` (an Outdoor) on paved square cells and
## returns them as [{node, cell, look}] (see dress). Their cells leave the square's spots (no stall
## or bird under a tree) but stay open for the walkers' paths.
static func plant_round_fountains(level: Node3D) -> Array:
	var out := []
	for y in level.height:
		for x in level.width:
			if level.cell_char(Vector2i(x, y)) != "F":
				continue
			for d: Vector2i in ROUND_FOUNTAIN:
				var c := Vector2i(x, y) + d
				if level.cell_char(c) != ":":
					continue
				var pos: Vector3 = level.cell_to_world(c)
				var node := Node3D.new()
				node.name = "SquareAppleTree"
				# Out towards the cell's far corner, away from the fountain: the walkers' paths run
				# through the middle of the cells (and round the fountain past this one), so the trunk
				# stands clear of them and the cell stays open (see Outdoor's astar).
				node.position = pos + Vector3(d.x, 0, d.y) * TRUNK_OUT
				node.rotation.y = hash("square apple:%s" % c) % 628 / 100.0
				node.scale = Vector3.ONE * VILLAGE_SCALE
				level.add_child(node)
				level._add_solid(node.position, Vector3(0.5, 2.5, 0.5))
				level.spots.square.erase(pos)
				level.spots.market.erase(pos)
				out.append({"node": node, "cell": c, "look": ""})
	return out


## More apple trees in the village, in the gardens: on grass in the village (Outdoor.near_village)
## within GARDEN_REACH tiles of a building, with nothing but grass, buildings or the village wall
## round the tile (no path, square, door or prop beside it, so no walker's way or doorway is
## blocked), no door or bush close by, not on or beside Zarek's camp (Outdoor.merchant_camp),
## and at least TREE_SPACING tiles from the next tree.
## Returned as [{node, cell, look, garden}] like plant_round_fountains (see dress).
static func plant_in_village(level: Node3D) -> Array:
	var out := []
	var taken: Array[Vector2i] = []
	var camp: Array[Vector2i] = []
	if level.has_method("merchant_camp"):
		camp = level.merchant_camp()
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if not _garden_cell(level, c) or camp.any(func(t: Vector2i): return maxi(absi(t.x - c.x), absi(t.y - c.y)) <= 1) or taken.any(func(t: Vector2i): return maxi(absi(t.x - c.x), absi(t.y - c.y)) < TREE_SPACING):
				continue
			var pos: Vector3 = level.cell_to_world(c)
			if level._entrances.any(func(e): return Vector2((e.door as Vector3).x - pos.x, (e.door as Vector3).z - pos.z).length() < DOOR_CLEAR) \
					or level.shrubs.any(func(s: Vector3): return Vector2(s.x - pos.x, s.z - pos.z).length() < 1.5):
				continue
			taken.append(c)
			var node := Node3D.new()
			node.name = "VillageAppleTree"
			node.position = pos
			node.rotation.y = hash("village apple:%s" % c) % 628 / 100.0
			node.scale = Vector3.ONE * VILLAGE_SCALE
			level.add_child(node)
			level._add_solid(node.position, Vector3(0.5, 2.5, 0.5))
			out.append({"node": node, "cell": c, "look": "", "garden": true})
	return out


## One more in each grass pocket of the village: a block of 2x2 grass tiles (one may hold a lamp post) framed by paths or the
## paved square on at least three of its sides (no prop, bush or door in it). The tree stands at the
## pocket's middle, the corner the four tiles share, so the walkers' ways through the tiles' middles
## stay open. Returned as [{node, cell, look, pocket}] like plant_in_village (see dress).
static func plant_in_pockets(level: Node3D, others: Array) -> Array:
	var out := []
	for y in level.height - 1:
		for x in level.width - 1:
			var c := Vector2i(x, y)
			if not _pocket(level, c):
				continue
			var pos: Vector3 = (level.cell_to_world(c) + level.cell_to_world(c + Vector2i.ONE)) * 0.5
			# A lamp post on one of its tiles: the trunk steps aside, away from it.
			for d: Vector2i in POCKET_TILES:
				if level.cell_char(c + d) == "l":
					pos -= Vector3(d.x * 2 - 1, 0, d.y * 2 - 1) * POCKET_LAMP_STEP
			if (others + out).any(func(t): return Vector2((t.node as Node3D).position.x - pos.x, (t.node as Node3D).position.z - pos.z).length() < TREE_SPACING * 4.0) \
					or level._entrances.any(func(e): return Vector2((e.door as Vector3).x - pos.x, (e.door as Vector3).z - pos.z).length() < DOOR_CLEAR) \
					or level.shrubs.any(func(s: Vector3): return Vector2(s.x - pos.x, s.z - pos.z).length() < 1.5):
				continue
			var node := Node3D.new()
			node.name = "PocketAppleTree"
			node.position = pos
			node.rotation.y = hash("pocket apple:%s" % c) % 628 / 100.0
			node.scale = Vector3.ONE * VILLAGE_SCALE
			level.add_child(node)
			level._add_solid(node.position, Vector3(0.5, 2.5, 0.5))
			out.append({"node": node, "cell": c, "look": "", "pocket": true})
	return out


## The apple trees that explain the fallen leaves (see plant_for_leaves): the village's and the
## surrounding areas' ground lies deep in autumn leaves but the woods are all spruce, so a few apple
## trees are spread out so that no leaf lies more than LEAF_REACH tiles from one (about one screen at
## the normal zoom, with the tree in the middle), or from the ivy and vines on the walls, which drop
## leaves in autumn too.
const LEAF_REACH := 6.0
## They keep this many tiles from any other apple tree, and this far (tiles) from graves, the crypt,
## the graveyard fence, the mountain's rock face and the climber.
const LEAF_SPACING := 3.0
const LEAF_KEEP_OUT := 4
const LEAF_KEEP_OUT_LETTERS := "gRz=κ"
## Where they grow: the open ground north of the farming valley (Outdoor.VALLEY_FROM), where leaves lie.
const LEAF_GROUND := ".,:'"


## Plants a few more apple trees (not for picking, like the others) so that every spot of the
## ground where fallen leaves lie has one within LEAF_REACH tiles: again and again the leaf tile
## farthest from every tree gets the tree closest to it, on grass with only grass and path tiles round
## it (so no door, walkway or prop is blocked), clear of doors, bushes, building plots, Zarek's camp,
## the hero's start, graves and rock faces. The graveyard (its dead trees) and the farming valley are left
## alone, and the ground leaves lie exactly as before (SurfaceLife does not know of these trees).
## Returned as [{node, cell, look, leaf}] like plant_in_village (see dress); `others` are the trees
## already planted.
static func plant_for_leaves(level: Node3D, others: Array) -> Array:
	var out := []
	var camp: Array[Vector2i] = []
	if level.has_method("merchant_camp"):
		camp = level.merchant_camp()
	var trees: Array[Vector2] = []
	for t in others:
		trees.append(Vector2((t.node as Node3D).position.x, (t.node as Node3D).position.z) / Level.TILE)
	# The tiles where leaves lie and the tiles a tree may stand on.
	var leaf_cells: Array[Vector2i] = []
	var spots: Array[Vector2i] = []
	for y in mini(level.height, Outdoor.VALLEY_FROM):
		for x in level.width:
			var c := Vector2i(x, y)
			if not LEAF_GROUND.contains(level.cell_char(c)) or _near_letters(level, c, LEAF_KEEP_OUT_LETTERS, LEAF_KEEP_OUT):
				continue
			leaf_cells.append(c)
			if _leaf_spot(level, c, camp):
				spots.append(c)
	# Ivy and vines on the walls drop leaves in autumn just as well: a leaf tile within LEAF_REACH
	# of one needs no tree (one point per half tile of ivy).
	var sources: Array[Vector2] = trees.duplicate()
	var seen := {}
	for xf: Transform3D in level._ivy.xforms:
		var at := Vector2(xf.origin.x, xf.origin.z) / Level.TILE
		var key := Vector2i((at * 2.0).floor())
		if not seen.has(key):
			seen[key] = true
			sources.append(at)
	var gap := PackedFloat32Array()
	gap.resize(leaf_cells.size())
	for i in leaf_cells.size():
		var best := 99999.0
		for t in sources:
			best = minf(best, Vector2(leaf_cells[i]).distance_to(t))
		gap[i] = best
	while true:
		var far := -1
		for i in leaf_cells.size():
			if gap[i] > LEAF_REACH and (far < 0 or gap[i] > gap[far]):
				far = i
		if far < 0:
			break
		# The spot nearest to that leaf, at least LEAF_SPACING from every tree.
		var pick := Vector2i(-1, -1)
		var best := INF
		for c in spots:
			var d := Vector2(c).distance_to(Vector2(leaf_cells[far]))
			if d < best and not trees.any(func(t: Vector2): return Vector2(c).distance_to(t) < LEAF_SPACING):
				best = d
				pick = c
		if pick.x < 0 or best > LEAF_REACH:
			# Nowhere to plant for it: leave it be.
			gap[far] = 0.0
			continue
		trees.append(Vector2(pick))
		for i in leaf_cells.size():
			gap[i] = minf(gap[i], Vector2(leaf_cells[i]).distance_to(Vector2(pick)))
		var node := Node3D.new()
		node.name = "LeafAppleTree"
		node.position = level.cell_to_world(pick)
		node.rotation.y = hash("leaf apple:%s" % pick) % 628 / 100.0
		node.scale = Vector3.ONE * VILLAGE_SCALE
		level.add_child(node)
		level._add_solid(node.position, Vector3(0.5, 2.5, 0.5))
		# Outside the village it grows wild: no grass patch and ring of stones at its foot.
		out.append({"node": node, "cell": pick, "look": "", "leaf": true, "wild": not level.near_village(pick)})
	return out


## Whether a tree may stand on tile `c` (see plant_for_leaves): grass, with only grass and path
## tiles round it, no door, bush or building plot close by, not at Zarek's camp or the hero's start.
static func _leaf_spot(level: Node3D, c: Vector2i, camp: Array[Vector2i]) -> bool:
	if level.cell_char(c) != "." or level.on_plot(level.cell_to_world(c), 3.0):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not ".,".contains(level.cell_char(c + Vector2i(dx, dy))):
				return false
	if camp.any(func(t: Vector2i): return maxi(absi(t.x - c.x), absi(t.y - c.y)) <= 1) or maxi(absi(level.start_cell.x - c.x), absi(level.start_cell.y - c.y)) <= 3:
		return false
	var pos: Vector3 = level.cell_to_world(c)
	return not (level._entrances.any(func(e): return Vector2((e.door as Vector3).x - pos.x, (e.door as Vector3).z - pos.z).length() < DOOR_CLEAR) \
			or level.shrubs.any(func(s: Vector3): return Vector2(s.x - pos.x, s.z - pos.z).length() < 1.5))


## Whether any tile within `reach` tiles of `c` holds one of the letters.
static func _near_letters(level: Node3D, c: Vector2i, letters: String, reach: int) -> bool:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var ch: String = level.cell_char(c + Vector2i(dx, dy))
			if ch != "" and letters.contains(ch):
				return true
	return false


## Whether the 2x2 tiles from `c` (its top left) are a grass pocket (see plant_in_pockets): grass,
## with at most one lamp post.
static func _pocket(level: Node3D, c: Vector2i) -> bool:
	var lamps := 0
	for d: Vector2i in POCKET_TILES:
		var ch: String = level.cell_char(c + d)
		if ch == "l":
			lamps += 1
		elif ch != ".":
			return false
		if not level.near_village(c + d):
			return false
	if lamps > 1:
		return false
	# The four sides, two tiles each: west, east, north, south.
	var sides := [[Vector2i(-1, 0), Vector2i(-1, 1)], [Vector2i(2, 0), Vector2i(2, 1)], [Vector2i(0, -1), Vector2i(1, -1)], [Vector2i(0, 2), Vector2i(1, 2)]]
	var framed := 0
	for side in sides:
		var paved := true
		for d: Vector2i in side:
			if not level.cell_char(c + d) in PAVED:
				paved = false
		if paved:
			framed += 1
	return framed >= 3


## Whether a tile is garden grass for a village apple tree (see plant_in_village).
static func _garden_cell(level: Node3D, c: Vector2i) -> bool:
	if level.cell_char(c) != "." or not level.near_village(c):
		return false
	var building := false
	for dy in range(-GARDEN_REACH, GARDEN_REACH + 1):
		for dx in range(-GARDEN_REACH, GARDEN_REACH + 1):
			var ch: String = level.cell_char(c + Vector2i(dx, dy))
			var beside := absi(dx) <= 1 and absi(dy) <= 1
			if beside and not (ch == "." or ch == "_" or ch == "§"):
				return false
			if not beside and Outdoor.VILLAGE_BLOCKS.contains(ch):
				building = true
	return building


## Draws the village's trees again when their look changes on `day` (the season, the apples).
static func dress(trees: Array, day: int) -> void:
	dress_end(dress_begin(trees, day))


## The first half of `dress`: clears the trees whose look changes and starts building them anew on
## the worker threads (each into a node of its own, with the same dice as ever), so that the caller
## can go on with other work meanwhile. Hand what it returns to `dress_end`, which puts the new
## trees in their places.
static func dress_begin(trees: Array, day: int) -> Dictionary:
	var look := "%s:%d" % [Weather.season(day), apples(VILLAGE_TREE, day)]
	var todo: Array[Node3D] = []
	var wild: Array[bool] = []
	for t in trees:
		if t.look == look:
			continue
		t.look = look
		var node: Node3D = t.node
		for child in node.get_children():
			node.remove_child(child)
			child.queue_free()
		todo.append(node)
		wild.append(t.get("wild", false))
	# A sapling's stake is made with shared furniture helpers; the few young trees go one by one.
	if todo.size() < 2 or stage(VILLAGE_TREE, day) <= SAPLING:
		for i in todo.size():
			build(todo[i], VILLAGE_TREE, day, wild[i])
		return {}
	# What the trees share is made once, here, before the threads need it.
	for roughness in [0.9, 0.7, 0.4]:
		_vertex_mat(roughness)
	_leaf_mat()
	for sides in [5, 6, 8]:
		_ball_arrays(sides)
	SnowCaps.cap_material()
	var at: Array[Vector3] = []
	for node in todo:
		at.append(node.position)
	var made: Array[Node3D] = []
	made.resize(todo.size())
	var grow := func(i: int) -> void:
		var tmp := Node3D.new()
		tmp.position = at[i]
		build(tmp, VILLAGE_TREE, day, wild[i])
		made[i] = tmp
	return {"todo": todo, "made": made, "grow": grow, "id": WorkerThreadPool.add_group_task(grow, todo.size(), -1, true, "Apple trees")}


## The second half of `dress`: waits for the trees `dress_begin` started and puts them in their places.
static func dress_end(pending: Dictionary) -> void:
	if pending.is_empty():
		return
	WorkerThreadPool.wait_for_group_task_completion(pending.id)
	var todo: Array[Node3D] = pending.todo
	var made: Array[Node3D] = pending.made
	for i in todo.size():
		var tmp := made[i]
		for child in tmp.get_children():
			tmp.remove_child(child)
			todo[i].add_child(child)
		for key in tmp.get_meta_list():
			todo[i].set_meta(key, tmp.get_meta(key))
		tmp.free()


## Builds the tree of `piece` as it looks on `day` (`wild`: without the patch of grass and stones at its foot) into `root` (on the ground, middle at the
## origin) and returns its solids ({at, size}, local): the trunk.
##
## A grown tree is a real skeleton of tapering, bending limbs: the trunk forks into strong limbs,
## each limb into branches and each branch into twigs (see _grow), and every twig ends in a clump
## of leaves, so the crown is full and its branches show only between the clumps. All the bark is
## one mesh, all the leaves one, the blossom and the apples one each (see _Parts), so a tree costs
## a handful of draw calls however many branches it has. The model notes how many apples, clumps,
## blossoms and limbs it has in the metas "apples", "leaves", "blossom" and "limbs".
static func build(root: Node3D, piece: Dictionary, day: int, wild := false) -> Array:
	var grown := stage(piece, day)
	var season := Weather.season(day)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("apple tree:%s" % root.position.snapped(Vector3.ONE * 0.1))
	var parts := _Parts.new()
	# Round its foot a patch of grass, bordered by a ring of small field stones.
	# (A `wild` tree, outside the village, stands straight in the ground like a natural one.)
	if not wild:
		parts.patch(rng, PATCH_RADIUS + grown * PATCH_GROWS)
	var shape: Dictionary = SHAPES[grown]
	if grown <= SAPLING:
		# The stake it is tied to, with a band of bast round both.
		var stake_h: float = shape.trunk + 0.25
		HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.018, 0.022, stake_h), HomeStoreFurniture._mat(Color(0.6, 0.48, 0.3), 0.85), Vector3(0.09, stake_h * 0.5, 0))
		HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(0.14, 0.03, 0.05)), HomeStoreFurniture._mat(Color(0.78, 0.68, 0.42), 0.9), Vector3(0.045, shape.trunk * 0.7, 0))
	# The skeleton: the trunk, and from its top the limbs, branches and twigs.
	var tips := []
	var forks := []
	var top := Vector3(rng.randf_range(-0.05, 0.05), shape.trunk, rng.randf_range(-0.05, 0.05)) * Vector3(grown, 1, grown)
	var trunk_mid := top * 0.5 + Vector3(rng.randf_range(-0.04, 0.04), 0, rng.randf_range(-0.04, 0.04)) * grown
	# A little flare where it meets the ground.
	parts.limb(Vector3.ZERO, Vector3(0, 0.2, 0) * minf(1.0, shape.trunk), shape.thick * 1.45, shape.thick * 1.05, BARK)
	parts.limb(Vector3.ZERO, trunk_mid, shape.thick, shape.thick * 0.88, BARK)
	parts.limb(trunk_mid, top, shape.thick * 0.88, shape.thick * 0.76, BARK)
	var limbs: int = shape.limbs
	var spin := rng.randf() * TAU
	for k in limbs:
		var a: float = spin + TAU * k / limbs + rng.randf_range(-0.3, 0.3)
		var out: float = shape.spread * rng.randf_range(0.85, 1.15)
		var dir := Vector3(cos(a) * out, 1.0, sin(a) * out).normalized()
		_grow(parts, rng, top, dir, shape.reach * rng.randf_range(0.85, 1.1), shape.thick * 0.62, shape.depth, tips, forks, season == Weather.WINTER)
	if grown >= YOUNG:
		# A leader straight up the middle, so the crown has a top.
		_grow(parts, rng, top, Vector3(rng.randf_range(-0.15, 0.15), 1, rng.randf_range(-0.15, 0.15)).normalized(), shape.reach * 0.8, shape.thick * 0.5, shape.depth - 1, tips, forks, season == Weather.WINTER)
	# The crown's middle, and how far it reaches.
	var centre := Vector3.ZERO
	for t in tips:
		centre += t
	centre /= maxf(1.0, tips.size())
	# The leaves: a clump at every twig's end, and a few more over the forks inside so no light
	# shows through the heart of the crown. Autumn lets a few fall already; winter all.
	var clumps := []
	if season != Weather.WINTER:
		for t in tips:
			if season == Weather.AUTUMN and rng.randf() < 0.12:
				continue
			clumps.append([t + Vector3(0, shape.clump * 0.25, 0), shape.clump * rng.randf_range(0.85, 1.15)])
		for f in forks:
			clumps.append([f + (f - centre).normalized() * shape.clump * 0.2 + Vector3(0, shape.clump * 0.3, 0), shape.clump * rng.randf_range(0.95, 1.25)])
		var low: float = centre.y - shape.reach * 1.2
		var high: float = centre.y + shape.reach
		for c in clumps:
			var colour: Color = AUTUMN_LEAVES[rng.randi() % AUTUMN_LEAVES.size()] if season == Weather.AUTUMN else LEAF.get(season, LEAF.summer)
			# The lower and inner clumps lie in the crown's shade.
			var shade := clampf((c[0].y - low) / maxf(high - low, 0.1), 0.0, 1.0)
			var size: float = c[1]
			parts.clump(rng, c[0], Vector3(1.12, 0.88, 1.12) * size, colour * lerpf(0.7, 1.08, shade) * rng.randf_range(0.92, 1.06), autumn_mix(rng, season))
	# In winter a few bunches of withered leaves still hang on the twigs of a tree old enough to bear.
	var withered := []
	if season == Weather.WINTER and grown >= YOUNG:
		for t in tips:
			if rng.randf() < WITHERED_SHARE:
				withered.append(t)
				for i in rng.randi_range(WITHERED_BUNCH.x, WITHERED_BUNCH.y):
					var hang := (Vector3(rng.randf_range(-1, 1), rng.randf_range(-1.2, 0.1), rng.randf_range(-1, 1))).normalized()
					var colour: Color = WITHERED[rng.randi() % WITHERED.size()] * rng.randf_range(0.85, 1.1)
					parts.leaf(t + hang * shape.clump * 0.12, hang, shape.clump * rng.randf_range(0.3, 0.42), rng.randf() * TAU, colour)
	# Blossom in spring, on a tree old enough to bear: on the outside of the clumps.
	var blossoms := 0
	if season == Weather.SPRING and grown >= YOUNG:
		for c in clumps:
			for i in 9:
				var at: Vector3 = c[0] + _on_clump(rng, c[1], (c[0] - centre).normalized() + Vector3(0, 0.4, 0))
				parts.blossom(at, shape.clump * 0.13, BLOSSOM[rng.randi() % BLOSSOM.size()])
				blossoms += 1
	# The apples, hanging on the outside and the underside of the outer clumps: more than a
	# picking brings in (HANGING times as many), so the tree looks laden.
	var n := apples(piece, day) * HANGING
	var outer := clumps.slice(0, maxi(1, tips.size())) if not clumps.is_empty() else [[centre, shape.clump]]
	for i in n:
		var c: Array = outer[(i * 7 + 3) % outer.size()]
		# Just outside the clump's leaves, where they show.
		var at: Vector3 = c[0] + _on_clump(rng, c[1], (c[0] - centre).normalized() * Vector3(1, 0, 1) + Vector3(0, -0.5, 0)) * 1.18
		# Red on the side the sun ripened, green on the other.
		var sunny := (Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.0), rng.randf_range(-1, 1))).normalized()
		parts.apple(at, 0.17 if grown == MATURE else 0.13, APPLE_COLOUR * rng.randf_range(0.86, 1.12), APPLE_GREEN * rng.randf_range(0.9, 1.08), sunny, rng.randf_range(-0.35, 0.35))
	parts.finish(root)
	var snow := _snow(parts.segments, parts.snowy, clumps, forks, tips, withered, shape, rng)
	if snow != null:
		root.add_child(snow)
	root.set_meta("apples", n)
	root.set_meta("withered", withered.size())
	root.set_meta("leaves", clumps.size())
	root.set_meta("single_leaves", parts.leaves_made)
	root.set_meta("blossom", blossoms)
	root.set_meta("limbs", parts.limbs)
	var thick: float = maxf(shape.thick * 2.4, 0.2) + 0.1
	return [{"at": Vector3.ZERO, "size": Vector3(thick, maxf(shape.trunk, 0.6), thick)}]


## One limb from `from` along `dir`, `length` long and `r` thick at its foot: two segments with a
## little bend, then (while `depth` lasts) two or three thinner, shorter limbs forking off its end,
## spread round it and leaning outwards and up. A limb with no more depth is a twig: its end goes
## into `tips`, and the ends of the limbs that forked into `forks`. Bare in winter, every twig
## shows two little shoots at its end.
static func _grow(parts: _Parts, rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, r: float, depth: int, tips: Array, forks: Array, bare: bool) -> void:
	var bend := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.5), rng.randf_range(-1, 1)) * 0.22
	var mid := from + dir * length * 0.5
	var end := mid + (dir + bend).normalized() * length * 0.5
	parts.limb(from, mid, r, r * 0.84, BARK)
	parts.limb(mid, end, r * 0.84, r * 0.68, BARK)
	if depth <= 0:
		tips.append(end)
		if bare:
			for s in 2:
				var shoot := (dir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.2, 0.9), rng.randf_range(-0.8, 0.8))).normalized()
				parts.limb(end, end + shoot * length * 0.35, r * 0.5, r * 0.2, BARK)
		return
	forks.append(end)
	var out := (dir + bend).normalized()
	var children := 3 if depth >= 2 or rng.randf() < 0.45 else 2
	var spin := rng.randf() * TAU
	for k in children:
		# Turn away from the parent's line round a ring, keeping a pull upwards and outwards.
		var side := out.cross(Vector3.UP if absf(out.y) < 0.95 else Vector3.RIGHT).normalized()
		var round_axis := side.rotated(out, spin + TAU * k / children)
		var child := out.rotated(round_axis, deg_to_rad(rng.randf_range(28.0, 48.0)))
		child = (child + Vector3(out.x, 0, out.z) * 0.25 + Vector3(0, 0.12, 0)).normalized()
		_grow(parts, rng, end, child, length * rng.randf_range(0.6, 0.72), r * 0.64, depth - 1, tips, forks, bare)


## The snow on a tree (one mesh, see SnowCaps: hidden until snow lies, then it grows out of the
## bark and the leaves as the snow deepens and sinks back as it melts), or null for a tree too
## small to hold any. It lies as a rounded ridge along the top of every limb that is not too
## steep, deepest on the level ones; in a tuft in every fork and on the end of every twig (over
## the withered leaves in winter); and as a little pad on every leaf of the crown's top and
## outside that faces the sky, so a crown in leaf turns white on top with its green showing
## between and under the pads.
static func _snow(segments: Array, snowy: Array, clumps: Array, forks: Array, tips: Array, withered: Array, shape: Dictionary, rng: RandomNumberGenerator) -> MeshInstance3D:
	var s := SnowCaps._Surface.new()
	for seg: Array in segments:
		_snow_ridge(s, seg[0], seg[1], seg[2], seg[3])
	var tuft: float = clampf(shape.clump * 0.32, 0.025, 0.16)
	for f: Vector3 in forks:
		_snow_tuft(s, f, tuft * rng.randf_range(0.8, 1.15), rng)
	if clumps.is_empty():
		for t: Vector3 in tips:
			if withered.has(t):
				_snow_tuft(s, t + Vector3(0, tuft * 0.15, 0), tuft * rng.randf_range(1.0, 1.3), rng)
			elif rng.randf() < 0.6:
				_snow_tuft(s, t, tuft * rng.randf_range(0.45, 0.7), rng)
	for outline: Array in snowy:
		_snow_on_leaf(s, outline, rng)
	if s.empty():
		return null
	var mesh := ArrayMesh.new()
	s.commit(mesh, SnowCaps.cap_material(), Vector3.ZERO)
	var node := SnowCaps.node_for(mesh)
	node.name = "Snow"
	return node


## A ridge of snow along the top of the limb from `a` to `b` (`r0` and `r1` thick): three rings
## across its top half, closed at both ends, its vertices on the bark and pushed up and out to
## the snow's full shape. Deepest in the limb's middle and on a level limb, none on an upright one.
static func _snow_ridge(s: SnowCaps._Surface, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var u := (b - a).normalized()
	var level := 1.0 - absf(u.y)
	if level < 0.15 or a.distance_to(b) < 0.01:
		return
	var top := (Vector3.UP - u * u.y).normalized()
	var side := top.cross(u).normalized()
	var deep := clampf(maxf(r0, r1) * SNOW_ON_LIMB, SNOW_LIMB_RANGE.x, SNOW_LIMB_RANGE.y) * smoothstep(0.15, 0.6, level)
	const ACROSS := [-1.4, -0.75, 0.0, 0.75, 1.4]
	var rings: Array[int] = []
	for t: float in [0.0, 0.5, 1.0]:
		var c := a.lerp(b, t)
		var r := lerpf(r0, r1, t)
		var d := deep * (1.0 if t == 0.5 else 0.6)
		rings.append(s.size())
		for th: float in ACROSS:
			var dir := top * cos(th) + side * sin(th)
			var lift := pow(maxf(cos(th), 0.0), 1.3)
			s.add(c + dir * r, (dir + Vector3.UP * 0.6).normalized(), Vector3.UP * d * lift + dir * d * 0.35 * lift)
	for i in 2:
		for k in ACROSS.size() - 1:
			s.quad(rings[i] + k, rings[i] + k + 1, rings[i + 1] + k + 1, rings[i + 1] + k)
	# The ends, rounded off past the ring.
	for e in [[0, -1.0, a, r0], [2, 1.0, b, r1]]:
		var ring: int = rings[e[0]]
		var out: Vector3 = u * float(e[1])
		var tip := s.size()
		s.add((e[2] as Vector3) + top * float(e[3]), (out + Vector3.UP).normalized(), Vector3.UP * deep * 0.35 + out * deep * 0.5)
		for k in ACROSS.size() - 1:
			s.tri(ring + k, ring + k + 1, tip)


## A little flattened mound of snow `r` wide sitting at `at` (a fork or a twig's end): every
## vertex starts at `at` and grows out to the mound's shape.
static func _snow_tuft(s: SnowCaps._Surface, at: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	const SIDES := 7
	var spin := rng.randf() * TAU
	var rings: Array[int] = []
	for lv: Vector2 in [Vector2(0.75, -0.12), Vector2(1.0, 0.2), Vector2(0.6, 0.5)]:
		rings.append(s.size())
		for k in SIDES:
			var a := spin + TAU * k / SIDES
			var out := Vector3(cos(a), 0, sin(a)) * lv.x * r * rng.randf_range(0.85, 1.15) + Vector3(0, lv.y * r, 0)
			s.add(at, (out + Vector3(0, r * 0.3, 0)).normalized(), out)
	var cap := s.size()
	s.add(at, Vector3.UP, Vector3(0, r * rng.randf_range(0.6, 0.72), 0))
	for i in rings.size() - 1:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			s.quad(rings[i] + k, rings[i] + k2, rings[i + 1] + k2, rings[i + 1] + k)
	var last := rings[rings.size() - 1]
	for k in SIDES:
		s.tri(last + k, last + (k + 1) % SIDES, cap)


## A pad of snow lying on a leaf (`outline`: foot, side, tip, side): a little short of its
## edges, thin at the rim and rounded up over its middle. It starts on the leaf and rises as
## the snow deepens.
static func _snow_on_leaf(s: SnowCaps._Surface, outline: Array, rng: RandomNumberGenerator) -> void:
	var mid: Vector3 = ((outline[0] as Vector3) + outline[1] + outline[2] + outline[3]) * 0.25
	var long := (outline[2] as Vector3).distance_to(outline[0])
	var thick := clampf(long * SNOW_ON_LEAF, 0.012, 0.045) * rng.randf_range(0.8, 1.2)
	var first := s.size()
	for p: Vector3 in outline:
		var rim := mid.lerp(p, 0.85)
		s.add(rim, ((rim - mid).normalized() * 0.5 + Vector3.UP).normalized(), Vector3.UP * thick * 0.25 + (rim - mid) * 0.12)
	var top := s.size()
	s.add(mid, Vector3.UP, Vector3.UP * thick)
	for k in 4:
		s.tri(first + k, first + (k + 1) % 4, top)


## In autumn a clump's leaves are not all one colour: the colours to pick from leaf by leaf (an
## empty list the rest of the year).
static func autumn_mix(rng: RandomNumberGenerator, season: String) -> Array:
	if season != Weather.AUTUMN:
		return []
	return [AUTUMN_LEAVES[rng.randi() % AUTUMN_LEAVES.size()], AUTUMN_LEAVES[rng.randi() % AUTUMN_LEAVES.size()]]


## A point on the skin of a clump of leaves of radius `r` (scaled like the clumps), leaning
## towards `towards` (a direction: outwards, up or down).
static func _on_clump(rng: RandomNumberGenerator, r: float, towards: Vector3) -> Vector3:
	var d := (Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() + towards * 0.9).normalized()
	return Vector3(d.x * 1.12, d.y * 0.88, d.z * 1.12) * r * 0.97


## The tree's meshes as they are built: the bark, the leaves, the blossom and the apples, each
## one mesh with the colours in its vertices.
class _Parts:
	var bark := SurfaceTool.new()
	var leaves := SurfaceTool.new()
	var flowers := SurfaceTool.new()
	var fruit := SurfaceTool.new()
	var ground := SurfaceTool.new()
	var limbs := 0
	var leaves_made := 0
	## Every limb as [from, to, r0, r1], and the outlines of the leaves that face the sky, for
	## the snow on them (see AppleTree._snow).
	var segments := []
	var snowy := []
	var _used := {}

	func _init() -> void:
		for st in [bark, leaves, flowers, fruit, ground]:
			st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## A tapering round limb from `from` to `to`, `r0` thick at its foot and `r1` at its end.
	func limb(from: Vector3, to: Vector3, r0: float, r1: float, colour: Color) -> void:
		var axis := to - from
		if axis.length() < 0.005:
			return
		var up := axis.normalized()
		var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
		var other := up.cross(side)
		var sides := 7 if r0 > 0.05 else 5
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var n0 := side * cos(a0) + other * sin(a0)
			var n1 := side * cos(a1) + other * sin(a1)
			var quad := [[from + n0 * r0, n0], [from + n1 * r0, n1], [to + n1 * r1, n1], [to + n0 * r1, n0]]
			for j in [0, 2, 1, 0, 3, 2]:
				bark.set_color(colour * (0.9 + 0.1 * n0.y))
				bark.set_normal(quad[j][1])
				bark.add_vertex(quad[j][0])
		limbs += 1
		segments.append([from, to, r0, r1])
		_used[bark] = true

	## The ground round the tree's foot, `radius` across: a flat disc of grass a shade richer than
	## the meadow, thick with short tufts of blades, and round its edge a ring of small, rounded
	## field stones, each its own size, shape and grey, set close but not in a perfect line.
	func patch(rng: RandomNumberGenerator, radius: float) -> void:
		var sides := 20
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			for v in [Vector3.ZERO, Vector3(cos(a1), 0, sin(a1)) * radius, Vector3(cos(a0), 0, sin(a0)) * radius]:
				ground.set_color(AppleTree.GRASS)
				ground.set_normal(Vector3.UP)
				ground.add_vertex(v + Vector3(0, 0.012, 0))
		# Tufts of grass all over it (not under the trunk).
		var tufts := roundi(110 * radius * radius)
		for i in tufts:
			var r := sqrt(rng.randf_range(0.04, 0.92)) * radius
			var at := Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU) * r
			for b in 3:
				var turn := rng.randf() * TAU
				var lean := Vector3(cos(turn), 0, sin(turn)) * rng.randf_range(0.01, 0.04)
				var side := Vector3(-sin(turn), 0, cos(turn)) * 0.012
				var tip := at + lean + Vector3(0, rng.randf_range(0.05, 0.11), 0)
				for v in [[at - side, AppleTree.GRASS], [at + side, AppleTree.GRASS], [tip, AppleTree.GRASS_TIP]]:
					ground.set_color(v[1])
					ground.set_normal(Vector3.UP)
					ground.add_vertex(v[0] + Vector3(0, 0.012, 0))
		# The stones round the edge.
		var arrays := AppleTree._ball_arrays(6)
		var around := 0.0
		while around < TAU - 0.05:
			var size := rng.randf_range(0.055, 0.09)
			var at := Vector3.RIGHT.rotated(Vector3.UP, around) * (radius + rng.randf_range(-0.02, 0.03))
			var colour: Color = AppleTree.STONES[rng.randi() % AppleTree.STONES.size()] * rng.randf_range(0.9, 1.08)
			_ball(ground, at + Vector3(0, size * 0.25, 0), Vector3(size * rng.randf_range(1.0, 1.4), size * rng.randf_range(0.55, 0.75), size * rng.randf_range(0.85, 1.15)), rng.randf() * TAU, colour, arrays)
			around += (size * 1.7) / radius
		_used[ground] = true

	## A clump of leaves round `at`, `scale` across (its radii): LEAVES_PER_CLUMP single leaves all
	## through it, each a pointed oval turned its own way, a little lighter at its tip. Most sit near
	## the clump's skin; those further in lie in its shade and are darker, so no light shows through
	## the crown's heart (no solid core: in autumn a core showed as a brown ball). In autumn the
	## leaves take their colours from `mix` one by one.
	func clump(rng: RandomNumberGenerator, at: Vector3, scale: Vector3, colour: Color, mix: Array) -> void:
		var count := roundi(AppleTree.LEAVES_PER_CLUMP * clampf(scale.x / 0.42, 0.35, 1.3))
		for i in count:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var depth := sqrt(rng.randf_range(0.06, 1.0))
			var foot := at + d * scale * depth * 1.02
			# In autumn most leaves have turned, AUTUMN_GREEN of them are still green.
			var tint := colour
			if not mix.is_empty():
				tint = AppleTree.LEAF.summer * rng.randf_range(0.8, 1.05) if rng.randf() < AppleTree.AUTUMN_GREEN \
						else (mix[rng.randi() % mix.size()] as Color).lerp(colour, 0.35)
			tint *= lerpf(0.6, 1.0, depth) * rng.randf_range(0.88, 1.1)
			var shape := leaf(foot, d, scale.x * rng.randf_range(0.42, 0.58), rng.randf() * TAU, tint)
			# The leaves on the crown's top and outside that face the sky hold snow when it falls.
			if d.y > 0.25 and depth > 0.6:
				snowy.append(shape)
		leaves_made += count

	## One leaf at `foot` on the outside of a clump (`out`: the way out of it), `size` long.
	## Returns its outline: foot, one side, tip, other side.
	func leaf(foot: Vector3, out: Vector3, size: float, turn: float, colour: Color) -> Array:
		# The leaf's line: outwards, tipped round `out` by `turn` and drooping a little.
		var side := out.cross(Vector3.UP if absf(out.y) < 0.9 else Vector3.RIGHT).normalized()
		var along := (out * 0.55 + side.rotated(out, turn) * 0.75 + Vector3.DOWN * 0.25).normalized()
		var across := along.cross(out).normalized()
		var tip := foot + along * size
		var mid := foot + along * size * 0.45
		var wide := size * 0.27
		var fold := out * size * 0.06
		var tip_colour := colour.lightened(0.12)
		var shades := [[foot, colour], [mid + across * wide + fold, colour], [tip, tip_colour], [mid - across * wide + fold, colour]]
		for j in [0, 1, 2, 0, 2, 3]:
			leaves.set_color(shades[j][1])
			# Lit as the clump is, from its middle outwards: soft, not every leaf its own glint.
			leaves.set_normal(out)
			leaves.add_vertex(shades[j][0])
		_used[leaves] = true
		return [shades[0][0], shades[1][0], shades[2][0], shades[3][0]]

	func blossom(at: Vector3, r: float, colour: Color) -> void:
		_ball(flowers, at, Vector3.ONE * r, 0.0, colour, AppleTree._ball_arrays(5))

	## An apple: red on the side that faces `sunny`, turning through a blush to green on the
	## other; `split` moves where the red gives way (more red or more green).
	func apple(at: Vector3, r: float, red: Color, green: Color, sunny: Vector3, split: float) -> void:
		var arrays := AppleTree._ball_arrays(8)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var scale := Vector3(1.0, 0.92, 1.0) * r
		for i in arrays[Mesh.ARRAY_INDEX] as PackedInt32Array:
			var ripe := smoothstep(-0.55, 0.45, normals[i].dot(sunny) + split)
			fruit.set_color(green.lerp(red, ripe))
			fruit.set_normal((normals[i] / scale).normalized())
			fruit.add_vertex(at + verts[i] * scale)
		_used[fruit] = true

	func _ball(st: SurfaceTool, at: Vector3, scale: Vector3, turn: float, colour: Color, arrays: Array) -> void:
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var b := Basis(Vector3.UP, turn)
		for i in index:
			st.set_color(colour)
			st.set_normal((b * (normals[i] / scale)).normalized())
			st.add_vertex(at + b * (verts[i] * scale))
		_used[st] = true

	## Puts the meshes into `root`, each named for what it is.
	func finish(root: Node3D) -> void:
		var named := [[bark, "Bark", AppleTree._vertex_mat(0.9)], [leaves, "Leaves", AppleTree._leaf_mat()],
				[flowers, "Blossom", AppleTree._vertex_mat(0.7)], [fruit, "Apples", AppleTree._vertex_mat(0.4)],
				[ground, "Ground", AppleTree._leaf_mat()]]
		for part in named:
			if not _used.has(part[0]):
				continue
			var mi := MeshInstance3D.new()
			mi.name = part[1]
			mi.mesh = (part[0] as SurfaceTool).commit()
			mi.material_override = part[2]
			root.add_child(mi)


## The vertices, normals and triangles of a low ball of radius 1 with `sides` segments round.
static func _ball_arrays(sides: int) -> Array:
	if not _balls.has(sides):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = sides
		mesh.rings = maxi(3, sides / 2)
		_balls[sides] = mesh.get_mesh_arrays()
	return _balls[sides]


## The leaves' material: colours from the vertices, both sides of every leaf drawn. Shared.
static func _leaf_mat() -> StandardMaterial3D:
	if not _mats.has("leaf"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		m.roughness = 0.85
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["leaf"] = m
	return _mats["leaf"]


## A material that takes its colour from the vertices. Shared by all trees.
static func _vertex_mat(roughness: float) -> StandardMaterial3D:
	var key := "%.2f" % roughness
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.roughness = roughness
	_mats[key] = m
	return m
