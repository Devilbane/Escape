class_name CapeWardrobe
extends RefCounted
## The cape wardrobe, on the first floor of the hero's house (map letter "(", see Tiles.DUNGEON). It is
## part of every home from the start: nothing to buy or unlock. The hero runs into it to open a window
## where they pick the picture on the back of their cape (see CapeDesigns, Menus._build_wardrobe).
## Like the other pieces of a home (see HomeStoreFurniture) it turns its back to a wall beside it, is
## solid where it stands and is a station.

## The kind of its station, and the window it opens.
const KIND := "umhangschrank"

const OAK := Color(0.42, 0.28, 0.18)
const DARK_OAK := Color(0.3, 0.19, 0.12)
const GOLD := Color(0.9, 0.7, 0.28)
## The size across the wall, how deep and how high it stands (metres).
const WIDTH := 2.4
const DEPTH := 1.1
const HEIGHT := 2.9


## The wardrobe on tile `c`, its back on the wall beside it.
static func build(level: Level, c: Vector2i) -> Node3D:
	var pos := level.cell_to_world(c)
	var pivot := Node3D.new()
	pivot.name = "CapeWardrobe"
	pivot.position = pos
	pivot.rotation.y = level._back_to_wall(c, level._facing_room(c))
	level.add_child(pivot)
	var oak := HomeStoreFurniture._mat(OAK, 0.85)
	var dark := HomeStoreFurniture._mat(DARK_OAK, 0.9)
	var gold := HomeStoreFurniture._mat(GOLD, 0.35, 0.8)
	var back := -Level.TILE * 0.5 + 0.1
	var mid := back + DEPTH * 0.5
	var front := back + DEPTH
	# The body, a plinth below it and a cornice on top.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH, HEIGHT - 0.35, DEPTH)), oak, Vector3(0, 0.15 + (HEIGHT - 0.35) * 0.5, mid))
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH + 0.12, 0.15, DEPTH + 0.1)), dark, Vector3(0, 0.075, mid + 0.02))
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH + 0.2, 0.2, DEPTH + 0.14)), dark, Vector3(0, HEIGHT - 0.1, mid + 0.04))
	# Two doors with raised panels, a dark seam between them and golden knobs.
	for sx: float in [-1.0, 1.0]:
		var x := sx * WIDTH * 0.25
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH * 0.5 - 0.14, HEIGHT - 0.9, 0.05)), dark, Vector3(x, 1.5, front + 0.02))
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH * 0.5 - 0.4, HEIGHT - 1.2, 0.05)), oak, Vector3(x, 1.5, front + 0.05))
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._sphere(0.07), gold, Vector3(sx * 0.16, 1.45, front + 0.12))
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(0.03, HEIGHT - 0.7, 0.06)), HomeStoreFurniture._mat(Color(0.08, 0.05, 0.03), 1.0), Vector3(0, 1.5, front + 0.05))
	# A golden crown ornament on the cornice, as a finial: a ball on a short post.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._cylinder(0.05, 0.12, 0.25), gold, Vector3(0, HEIGHT + 0.12, mid + 0.04))
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._sphere(0.11), gold, Vector3(0, HEIGHT + 0.32, mid + 0.04))
	# Solid where it stands, not the whole tile.
	var depth := DEPTH + 0.3
	var centre := pivot.transform * Vector3(0, 0, back + depth * 0.5)
	var size := pivot.transform.basis * Vector3(WIDTH, 0, depth)
	level._add_solid(Vector3(centre.x, 0, centre.z), Vector3(absf(size.x), 2.4, absf(size.z)))
	level.stations.append({"kind": KIND, "cell": c, "pos": pos, "used": false})
	return pivot
