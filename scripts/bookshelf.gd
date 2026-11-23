class_name Bookshelf
extends RefCounted
## The bookshelf on the ground floor of the hero's house, on the north wall (map letter "§", see Tiles.DUNGEON). It is part of
## every home from the start: nothing to buy or unlock. The hero runs into it to open the window of the
## book store (see HomeStores.BOOKS) and keeps every book there that they do not carry.
##
## The shelf shows what is stored: one book stands on it for every book kept, row by row from the
## bottom left, up to CAPACITY (a shelf holds that many books in view; more still go in, the number on
## its plaque keeps counting). A plaque on the top reads the exact number. Each book keeps its colour,
## size and binding as the shelf fills, so a book taken out does not make the others change.
## Like the other pieces of a home (see HomeStoreFurniture) it turns its back to a wall beside it, is
## solid where it stands and is a station.
##
## It is a handmade piece: two lathe-turned front posts on bun feet with finials, a cornice, shelves
## with a rounded front lip and a planked back. Every book is bound (see BINDINGS): a page block
## between two boards, raised bands, gilt tooling, a title label, brass corner caps or a clasp. Each
## book is one mesh with two shared materials (leather and paper in vertex colours, and metal), built
## once and kept, so a full shelf stays cheap.

## The kind of its station, and the window it opens.
const KIND := "buecherregal"
## The node name of the shelf, and of the row of books on it.
const NODE := "Bookshelf"
const BOOKS_NODE := "Books"
const PLAQUE_NODE := "Plaque"

## The boards, stained dark like walnut so the bindings stand out against the plank floor.
const OAK := Color(0.3, 0.18, 0.11)
const DARK_OAK := Color(0.17, 0.1, 0.06)
## The turned and moulded parts, a shade warmer than the boards.
const TURNED_OAK := Color(0.34, 0.2, 0.12)
const BRASS := Color(0.86, 0.66, 0.3)
## The colours of the covers.
const SPINES := [Color(0.55, 0.12, 0.12), Color(0.15, 0.3, 0.5), Color(0.2, 0.42, 0.25), Color(0.5, 0.35, 0.15),
		Color(0.35, 0.18, 0.4), Color(0.6, 0.55, 0.4), Color(0.18, 0.18, 0.22), Color(0.65, 0.3, 0.1)]
## How a book is bound: raised bands with a title label, a quarter binding with leather ends and
## brass caps, a clasped tome with brass corners and a strap, a cover with a tooled medallion.
const BINDINGS := ["bands", "quarter", "clasp", "tooled"]
const PAGES := Color(0.88, 0.82, 0.66)
const GOLD := Color(0.95, 0.74, 0.3)
const IRON := Color(0.36, 0.34, 0.33)
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
## The turned front post, bottom to top: radius and height (metres). It stands on a bun foot, has a
## vase between rings at each shelf and a neck under the cornice.
const POST := [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.12, 0.05), Vector2(0.12, 0.11), Vector2(0.09, 0.17),
		Vector2(0.07, 0.2), Vector2(0.105, 0.23), Vector2(0.105, 0.29), Vector2(0.065, 0.33),
		Vector2(0.06, 0.45), Vector2(0.085, 0.62), Vector2(0.075, 0.76), Vector2(0.052, 0.85),
		Vector2(0.095, 0.89), Vector2(0.095, 0.95), Vector2(0.052, 0.99),
		Vector2(0.06, 1.12), Vector2(0.085, 1.3), Vector2(0.075, 1.45), Vector2(0.052, 1.55),
		Vector2(0.095, 1.59), Vector2(0.095, 1.65), Vector2(0.052, 1.69),
		Vector2(0.06, 1.82), Vector2(0.085, 2.0), Vector2(0.075, 2.15), Vector2(0.052, 2.25),
		Vector2(0.095, 2.29), Vector2(0.095, 2.35), Vector2(0.052, 2.39),
		Vector2(0.06, 2.55), Vector2(0.085, 2.75), Vector2(0.06, 2.95), Vector2(0.05, 3.02),
		Vector2(0.1, 3.06), Vector2(0.1, 3.14), Vector2(0.0, 3.14)]
## The finial on top of a post, above the cornice: a collar, a ball and a little spike.
const FINIAL := [Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.03), Vector2(0.04, 0.05),
		Vector2(0.075, 0.1), Vector2(0.08, 0.14), Vector2(0.065, 0.19), Vector2(0.03, 0.22),
		Vector2(0.025, 0.25), Vector2(0.0, 0.32)]
## The sides of a turned part: enough to read round, few enough to stay cheap.
const TURNED_SIDES := 10

## Every book's mesh by its place on the shelf (see _book_mesh), and the two materials they share.
static var _books := {}
static var _cloth: StandardMaterial3D
static var _metal: StandardMaterial3D


## The shelf on tile `c`, its back on the wall beside it.
static func build(level: Level, c: Vector2i) -> Node3D:
	var pos := level.cell_to_world(c)
	var pivot := build_shelf(level, pos, level._back_to_wall(c, level._facing_room(c)))
	pivot.name = NODE
	var back := -Level.TILE * 0.5 + 0.1
	# Solid across the shelf and a little in front, not the whole tile.
	var depth := DEPTH + 0.3
	var centre := pivot.transform * Vector3(0, 0, back + depth * 0.5)
	var size := pivot.transform.basis * Vector3(WIDTH, 0, depth)
	level._add_solid(Vector3(centre.x, 0, centre.z), Vector3(absf(size.x), 2.4, absf(size.z)))
	level.stations.append({"kind": KIND, "cell": c, "pos": pos, "used": false})
	refresh(level, 0)
	return pivot


## The shelf itself at `pos`, turned by `rot`, its back half a tile behind `pos` (a shelf of a
## self-built house uses it too, see HouseFurnisher). No solid and no station: the caller adds them.
static func build_shelf(parent: Node, pos: Vector3, rot: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = rot
	parent.add_child(pivot)
	var oak := HomeStoreFurniture._mat(OAK, 0.8)
	var dark := HomeStoreFurniture._mat(DARK_OAK, 0.9)
	var turned := HomeStoreFurniture._mat(TURNED_OAK, 0.55)
	var brass := HomeStoreFurniture._mat(BRASS, 0.35, 0.8)
	var back := -Level.TILE * 0.5 + 0.1
	var front := back + DEPTH
	var mid := back + DEPTH * 0.5
	var post_x := WIDTH * 0.5 - 0.11
	var post_z := front - 0.11
	var top := POST[POST.size() - 1].y as float
	# The planked back: a dark board with raised battens between the planks.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH, HEIGHT, 0.06)), dark, Vector3(0, HEIGHT * 0.5, back + 0.03))
	for i in range(1, 6):
		var x := -WIDTH * 0.5 + WIDTH * i / 6.0
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(0.035, HEIGHT - 0.2, 0.02)), oak, Vector3(x, HEIGHT * 0.5, back + 0.07))
	# Two sides from the back to the turned posts, which carry the front.
	for sx: float in [-1.0, 1.0]:
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(0.1, top, DEPTH - 0.16)), oak,
				Vector3(sx * (WIDTH * 0.5 - 0.05), top * 0.5, back + (DEPTH - 0.16) * 0.5))
		var post := HomeStoreFurniture._add(pivot, _lathe(POST), turned, Vector3(sx * post_x, 0, post_z))
		post.name = "PostWest" if sx < 0.0 else "PostEast"
		HomeStoreFurniture._add(pivot, _lathe(FINIAL), turned, Vector3(sx * post_x, HEIGHT, post_z))
	# The shelves between the posts, each with a rounded lip along its front.
	var inner := WIDTH - 0.2
	for y: float in SHELVES:
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(inner, 0.06, DEPTH - 0.04)), oak, Vector3(0, y, mid - 0.02))
		var lip := HomeStoreFurniture._add(pivot, _rod(inner - 0.12, 0.035), turned, Vector3(0, y + 0.005, front - 0.06))
		lip.rotation.z = PI * 0.5
	# A kick board under the bottom shelf, set back between the feet.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(inner - 0.1, 0.17, 0.04)), dark, Vector3(0, 0.085, front - 0.12))
	# The cornice: a cove board under a top that overhangs the front and the posts.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH - 0.04, 0.08, DEPTH + 0.02)), turned, Vector3(0, top + 0.04, mid + 0.01))
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH + 0.06, HEIGHT - top - 0.08, DEPTH + 0.08)), oak,
			Vector3(0, (top + 0.08 + HEIGHT) * 0.5, mid + 0.04))
	# A half-round bead under the cornice's front edge.
	var bead := HomeStoreFurniture._add(pivot, _rod(WIDTH - 0.3, 0.03), turned, Vector3(0, top - 0.02, front - 0.02))
	bead.rotation.z = PI * 0.5
	# The plaque with the number, in a brass frame on a board over the top shelf.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(1.58, 0.36, 0.04)), brass, Vector3(0, HEIGHT - 0.2, back + DEPTH + 0.01))
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
	return pivot


## A turned part: the outline `profile` (radius, height) spun round the upright axis, with smooth
## normals along the outline so the beads and coves read round.
static func _lathe(profile: Array, sides := TURNED_SIDES) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	var normals: Array[Vector2] = []
	for i in n:
		var a: Vector2 = profile[maxi(i - 1, 0)]
		var b: Vector2 = profile[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		normals.append(Vector2(t.y, -t.x))
	for i in n - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		if p0 == p1:
			continue
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var quad := [[p0, normals[i], a0], [p1, normals[i + 1], a0], [p1, normals[i + 1], a1],
					[p0, normals[i], a0], [p1, normals[i + 1], a1], [p0, normals[i], a1]]
			for v in quad:
				var pt: Vector2 = v[0]
				var nm: Vector2 = v[1]
				var ang: float = v[2]
				var dir := Vector3(sin(ang), 0, cos(ang))
				st.set_normal((dir * nm.x + Vector3(0, nm.y, 0)).normalized())
				st.add_vertex(dir * pt.x + Vector3(0, pt.y, 0))
	return st.commit()


## A round rod `length` long, lying along the y axis (turn it to lie along a shelf).
static func _rod(length: float, radius: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


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
	refresh_shelf(pivot, count)


## Puts the books for `count` books kept on one shelf (see build_shelf).
static func refresh_shelf(pivot: Node, count: int) -> void:
	var books: Node3D = pivot.get_node(BOOKS_NODE)
	for old in books.get_children():
		books.remove_child(old)
		old.queue_free()
	var back := -Level.TILE * 0.5 + 0.1
	for i in shown(count):
		var look := book_look(i)
		var row := floori(float(i) / PER_ROW)
		var col := i % PER_ROW
		var size: Vector3 = look.size
		var x := (col - (PER_ROW - 1) * 0.5) * PITCH
		var y: float = SHELVES[row] + 0.03 + size.y * 0.5
		# The spines line up near the front of the shelf, the deeper books reach further back.
		var z := back + 0.08 + DEPTH * 0.72 - size.z * 0.5
		var book := MeshInstance3D.new()
		book.mesh = _book_mesh(i)
		book.position = Vector3(x, y, z)
		book.name = "Book%d" % i
		books.add_child(book)
	var label: Label3D = pivot.get_node(PLAQUE_NODE)
	label.text = plaque_text(count)


## How the book in place `i` looks, the same every time: its size (thickness, height, depth),
## cover colour and binding (one of BINDINGS).
static func book_look(i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("book:%d" % i)
	var binding: String = BINDINGS[rng.randi() % BINDINGS.size()]
	var width := rng.randf_range(0.14, 0.19)
	var height := rng.randf_range(0.42, 0.6)
	var depth := rng.randf_range(0.46, 0.56)
	if binding == "clasp":
		# A tome: thicker and taller.
		width = rng.randf_range(0.19, 0.22)
		height = rng.randf_range(0.54, 0.62)
	return {"size": Vector3(width, height, depth), "cover": SPINES[rng.randi() % SPINES.size()], "binding": binding}


## The bound book in place `i` for other furnishings (a library's bookcases, a pile on a desk): its look and
## its mesh, the same books that stand on the hero's shelf.
static func book_mesh(i: int) -> ArrayMesh:
	return _book_mesh(i)


## The mesh of the book in place `i`, built once (see _build_book).
static func _book_mesh(i: int) -> ArrayMesh:
	if not _books.has(i):
		_books[i] = _build_book(book_look(i))
	return _books[i]


## One bound book, centred on its middle, its spine facing +z: leather, cloth and paper in one
## surface, brass and gilt in a second.
static func _build_book(look: Dictionary) -> ArrayMesh:
	if _cloth == null:
		_cloth = StandardMaterial3D.new()
		_cloth.vertex_color_use_as_albedo = true
		_cloth.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		_cloth.roughness = 0.8
		_metal = StandardMaterial3D.new()
		_metal.vertex_color_use_as_albedo = true
		_metal.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		_metal.roughness = 0.4
		_metal.metallic = 0.5
	var size: Vector3 = look.size
	var w := size.x
	var h := size.y
	var d := size.z
	var cover: Color = look.cover
	var leather := cover.darkened(0.45)
	var soft := SurfaceTool.new()
	soft.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hard := SurfaceTool.new()
	hard.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face := d * 0.5
	var board := 0.014
	# The page block between two boards that stand a little proud of it, and the spine.
	_cube(soft, Vector3(0, 0, -0.008), Vector3(w - board * 2.0, h - 0.03, d - 0.03), PAGES)
	for sx: float in [-1.0, 1.0]:
		_cube(soft, Vector3(sx * (w * 0.5 - board * 0.5), 0, 0), Vector3(board, h, d), cover)
	_cube(soft, Vector3(0, 0, face - 0.012), Vector3(w, h, 0.024), cover)
	match look.binding:
		"bands":
			# Four raised bands across the spine, a dark label between the top two, gilt at both ends.
			for k in 4:
				var y := h * (0.28 - 0.17 * k)
				_cube(soft, Vector3(0, y, face + 0.004), Vector3(w + 0.006, 0.022, 0.016), leather)
			_cube(soft, Vector3(0, h * 0.195, face + 0.002), Vector3(w * 0.78, h * 0.1, 0.012), leather.darkened(0.3))
			_cube(hard, Vector3(0, h * 0.195, face + 0.009), Vector3(w * 0.55, 0.012, 0.004), GOLD)
			for sy: float in [-1.0, 1.0]:
				_cube(hard, Vector3(0, sy * (h * 0.5 - 0.035), face + 0.002), Vector3(w * 0.8, 0.01, 0.006), GOLD)
		"quarter":
			# Leather ends wrapped round the spine and onto the boards, capped in brass.
			for sy: float in [-1.0, 1.0]:
				_cube(soft, Vector3(0, sy * (h * 0.5 - h * 0.08), face - d * 0.15 + 0.004), Vector3(w + 0.008, h * 0.16, d * 0.3), leather)
				_cube(hard, Vector3(0, sy * (h * 0.5 - 0.012), face - 0.03 + 0.006), Vector3(w + 0.014, 0.026, 0.06), BRASS)
			_cube(hard, Vector3(0, h * 0.1, face + 0.002), Vector3(w * 0.6, 0.05, 0.006), GOLD)
		"clasp":
			# A tome: brass corners on all four spine corners, a strap round its middle with a buckle,
			# and a boss on the spine.
			for sy: float in [-1.0, 1.0]:
				for sx: float in [-1.0, 1.0]:
					_cube(hard, Vector3(sx * (w * 0.5 - 0.02), sy * (h * 0.5 - 0.03), face - 0.03),
							Vector3(0.05, 0.07, 0.07), BRASS)
			_cube(soft, Vector3(0, -h * 0.05, -0.004), Vector3(w + 0.01, 0.05, d + 0.014), leather.darkened(0.2))
			_cube(hard, Vector3(0, -h * 0.05, face + 0.006), Vector3(w * 0.55, 0.07, 0.012), BRASS)
			_cube(hard, Vector3(0, h * 0.22, face + 0.006), Vector3(0.05, 0.05, 0.012), GOLD, PI * 0.25)
			_cube(soft, Vector3(0, -h * 0.05, face + 0.013), Vector3(w * 0.22, 0.03, 0.006), leather.darkened(0.5))
		"tooled":
			# Gilt fillets at both ends, a tooled medallion in the middle with a dot above and below.
			for sy: float in [-1.0, 1.0]:
				_cube(hard, Vector3(0, sy * (h * 0.5 - 0.03), face + 0.002), Vector3(w * 0.9, 0.012, 0.006), GOLD)
				_cube(hard, Vector3(0, sy * (h * 0.5 - 0.055), face + 0.002), Vector3(w * 0.9, 0.006, 0.006), GOLD)
				_cube(hard, Vector3(0, sy * h * 0.17, face + 0.002), Vector3(0.022, 0.022, 0.006), GOLD, PI * 0.25)
			_cube(soft, Vector3(0, 0, face + 0.003), Vector3(w * 0.62, w * 0.62, 0.008), leather, PI * 0.25)
			_cube(hard, Vector3(0, 0, face + 0.008), Vector3(w * 0.4, w * 0.4, 0.006), GOLD, PI * 0.25)
	var mesh := soft.commit()
	mesh.surface_set_material(0, _cloth)
	hard.commit(mesh)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, _metal)
	return mesh


## A box of `size` round `centre`, turned by `roll` about the z axis (a diamond on a spine), in `colour`.
static func _cube(st: SurfaceTool, centre: Vector3, size: Vector3, colour: Color, roll := 0.0) -> void:
	var basis := Basis(Vector3(0, 0, 1), roll)
	var half := size * 0.5
	var faces := [[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
			[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
			[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)]]
	st.set_color(colour)
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := n * half
		var du := u * half
		var dv := v * half
		var corners := [c - du - dv, c + du - dv, c + du + dv, c - du + dv]
		st.set_normal(basis * n)
		for k: int in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(centre + basis * corners[k])
