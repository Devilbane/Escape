class_name Bookshelf
extends RefCounted
## The bookshelf on the ground floor of the hero's house, on the north wall (map letter "§", see Tiles.DUNGEON). It is part of
## every home from the start: nothing to buy or unlock. The hero runs into it to open the window of the
## book store (see HomeStores.BOOKS) and keeps every book there that they do not carry.
##
## The shelf shows what is stored: one book stands on it for every book kept, row by row from the
## bottom left, up to CAPACITY (a shelf holds that many books in view; more still go in, the number on
## its plaque keeps counting). A plaque on the top reads the exact number. Each book keeps its colour
## and height as the shelf fills, so a book taken out does not make the others change.
## Like the other pieces of a home (see HomeStoreFurniture) it turns its back to a wall beside it, is
## solid where it stands and is a station.

## The kind of its station, and the window it opens.
const KIND := "buecherregal"
## The node name of the shelf, and of the row of books on it.
const NODE := "Bookshelf"
const BOOKS_NODE := "Books"
const PLAQUE_NODE := "Plaque"

const OAK := Color(0.42, 0.28, 0.18)
const DARK_OAK := Color(0.3, 0.19, 0.12)
## The colours of the spines.
const SPINES := [Color(0.55, 0.12, 0.12), Color(0.15, 0.3, 0.5), Color(0.2, 0.42, 0.25), Color(0.5, 0.35, 0.15),
		Color(0.35, 0.18, 0.4), Color(0.6, 0.55, 0.4), Color(0.18, 0.18, 0.22), Color(0.65, 0.3, 0.1)]
## The size across the wall, how deep and how high it stands (metres).
const WIDTH := 3.2
const DEPTH := 0.8
const HEIGHT := 3.3
## How high the shelves lie above the floor, bottom to top.
const SHELVES := [0.2, 0.9, 1.6, 2.3]
## How many books stand in a row, and in view on the whole shelf.
const PER_ROW := 11
const CAPACITY := PER_ROW * 4
## How far apart the books stand across the shelf.
const PITCH := 0.25


## The shelf on tile `c`, its back on the wall beside it.
static func build(level: Level, c: Vector2i) -> Node3D:
	var pos := level.cell_to_world(c)
	var pivot := Node3D.new()
	pivot.name = NODE
	pivot.position = pos
	pivot.rotation.y = level._back_to_wall(c, level._facing_room(c))
	level.add_child(pivot)
	var oak := HomeStoreFurniture._mat(OAK, 0.85)
	var dark := HomeStoreFurniture._mat(DARK_OAK, 0.9)
	var back := -Level.TILE * 0.5 + 0.1
	var mid := back + DEPTH * 0.5
	# The back board, two sides, a plinth and the shelves.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH, HEIGHT, 0.06)), dark, Vector3(0, HEIGHT * 0.5, back + 0.03))
	for sx: float in [-1.0, 1.0]:
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(0.1, HEIGHT, DEPTH)), oak, Vector3(sx * (WIDTH * 0.5 - 0.05), HEIGHT * 0.5, mid))
	for y: float in SHELVES:
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH - 0.2, 0.06, DEPTH)), oak, Vector3(0, y, mid))
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH - 0.2, 0.08, DEPTH)), oak, Vector3(0, HEIGHT - 0.04, mid))
	# The plaque with the number, on a board over the top shelf.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(1.5, 0.3, 0.05)), dark, Vector3(0, HEIGHT - 0.2, back + DEPTH + 0.025))
	var books := Node3D.new()
	books.name = BOOKS_NODE
	pivot.add_child(books)
	var label := Label3D.new()
	label.name = PLAQUE_NODE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	label.pixel_size = 0.005
	label.font_size = 56
	label.outline_size = 6
	label.modulate = Color(0.95, 0.8, 0.4)
	label.outline_modulate = Color(0.1, 0.06, 0.03)
	label.position = Vector3(0, HEIGHT - 0.2, back + DEPTH + 0.06)
	pivot.add_child(label)
	# Solid across the shelf and a little in front, not the whole tile.
	var depth := DEPTH + 0.3
	var centre := pivot.transform * Vector3(0, 0, back + depth * 0.5)
	var size := pivot.transform.basis * Vector3(WIDTH, 0, depth)
	level._add_solid(Vector3(centre.x, 0, centre.z), Vector3(absf(size.x), 2.4, absf(size.z)))
	level.stations.append({"kind": KIND, "cell": c, "pos": pos, "used": false})
	refresh(level, 0)
	return pivot


## How many books stand on the shelf for `count` books kept.
static func shown(count: int) -> int:
	return clampi(count, 0, CAPACITY)


## The number on the plaque: "Books: 12".
static func plaque_text(count: int) -> String:
	return Lang.t("Bücher: %d") % maxi(count, 0)


## Puts the books on the shelf in the level for `count` books kept: one for
## each, up to CAPACITY, and the number on the plaque. Does nothing in a
## level without the shelf.
static func refresh(level: Level, count: int) -> void:
	var pivot := level.get_node_or_null(NODE)
	if pivot == null:
		return
	var books: Node3D = pivot.get_node(BOOKS_NODE)
	for old in books.get_children():
		books.remove_child(old)
		old.queue_free()
	var back := -Level.TILE * 0.5 + 0.1
	for i in shown(count):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("book:%d" % i)
		var row := floori(float(i) / PER_ROW)
		var col := i % PER_ROW
		var width := rng.randf_range(0.14, 0.2)
		var height := rng.randf_range(0.42, 0.6)
		var spine := HomeStoreFurniture._mat(SPINES[rng.randi() % SPINES.size()], 0.8)
		var x := (col - (PER_ROW - 1) * 0.5) * PITCH
		var y: float = SHELVES[row] + 0.03 + height * 0.5
		var book := HomeStoreFurniture._add(books, HomeStoreFurniture._box(Vector3(width, height, DEPTH * 0.7)), spine,
				Vector3(x, y, back + 0.06 + DEPTH * 0.35))
		book.name = "Book%d" % i
	var label: Label3D = pivot.get_node(PLAQUE_NODE)
	label.text = plaque_text(count)
