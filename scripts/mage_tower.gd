class_name MageTower
extends RefCounted
## The mage tower of Aldo and Odo, the village's two mages (map letter Ø, see VillageHalls): a tower
## of the village's stone and plaster one walks into, with three floors to walk on and a cellar
## under them, built on the machinery of the guildhall (see GuildHall, which lays the floors, the
## flights and the walls; WalkIn, which hides what is above the hero).
##
## - Ground floor, the entrance hall: two tapestries on the back wall (a mage fighting a dragon,
##   a mage fighting a demon), a rug, a table with a crystal ball, the stairs up on the right and
##   the stairs down to the cellar on the left, each behind a railing.
## - First floor, the library and reading room: tall bookcases, a long reading table with its
##   chairs, sofa chairs and a sofa on a rug, a globe and a reading lamp.
## - Second floor, the sleeping room under the pointed roof: two beds, a chest each, a wardrobe, a
##   telescope at the window and a table with candles. Aldo and Odo sleep here (see VillageBeds).
## - The cellar, the experiment room: a cauldron, an alchemist's bench with flasks, a stone circle
##   glowing on the floor, shelves of jars and a still. It is as large as the stairs let it be.
##
## The tower is a "flat" hall of the guild's size whose roof deck is the floor of the top room, which
## has four walls and a pyramid roof of its own: while the hero is inside, the roof lifts off from
## the second floor and the storeys above the hero hide (see WalkIn._show_up).

const KIND := "mage"
## The style of the hall's VillageHouse (see VillageHalls.style): as big as the guildhall's block.
const STYLE := {"max_w": 9.4, "max_d": 9.4, "door_x": 0.0, "flat": true, "mage": true}
## The top room's walls (metres over the deck), how high the pyramid roof rises over them, and how
## far it reaches out over the walls.
const TOP_H := 2.6
const PEAK := 5.2
const OVERHANG := 0.55
const SPIRE := 1.6
## The tapestries (metres across, high) and how high their lower edge hangs over the floor.
const TAPESTRY := Vector2(2.0, 2.25)
const TAPESTRY_FROM := 0.55
const DRAGON := "dragon"
const DEMON := "demon"
## The sleepers: Elder Aldo and Odo the scholar (see Villager.ROLES).
const OWNERS := ["0", "8"]
## The groups of the top room (see VillageHouse.hollow): each wall apart, and the roof.
const TOP_GROUPS := ["top_front", "top_back", "top_left", "top_right", "top_roof"]
const STONE := Color(0.62, 0.6, 0.66)
const VELVET := Color(0.42, 0.16, 0.34)
const VELVET_DARK := Color(0.3, 0.11, 0.25)
const GLOW := Color(0.62, 0.45, 1.0)
const LAB_LAMP := Color(0.72, 0.6, 1.0)

static var _pictures := {}


# --- The shell -----------------------------------------------------------------------

## The top room of the solid tower (see VillageHouse._shape): its walls with the windows in them, the
## beams, the roof and the spire, all in one mesh with the rest.
static func solid_top(parts: Dictionary, shape: Dictionary) -> void:
	var lay := GuildHall.layout(shape)
	var uw := float(shape.w) + VillageHouse.JETTY * 2.0
	var ud := float(shape.d) + VillageHouse.JETTY * 2.0
	var deck: float = lay.deck
	VillageHouse._box(parts, "plaster", Vector3(0, deck + TOP_H * 0.5, 0), Vector3(uw, TOP_H, ud), Basis(), 2.0, [4, 5])
	VillageHouse._beams(parts, uw, ud, deck)
	for x: float in VillageHouse._window_spots(uw, INF):
		VillageHouse._window(parts, Vector3(x, deck + 1.3, ud * 0.5), 0.0)
	for side: float in [-1.0, 1.0]:
		VillageHouse._window(parts, Vector3(side * uw * 0.5, deck + 1.3, 0), side * PI * 0.5)
	VillageHouse._window(parts, Vector3(0, deck + 1.3, -ud * 0.5), PI)
	roof(parts, shape)


## The top room built hollow (into `groups`, see VillageHouse.hollow): each of its four walls apart
## (`top_front`, `top_back`, `top_left`, `top_right`, so whichever faces the camera can hide, with its
## beams and the top of its wall), the roof (`top_roof`).
static func top_storey(shape: Dictionary, groups: Dictionary) -> void:
	var lay := GuildHall.layout(shape)
	var t := VillageHouse.WALL_THICK
	var uw := float(shape.w) + VillageHouse.JETTY * 2.0
	var ud := float(shape.d) + VillageHouse.JETTY * 2.0
	var deck: float = lay.deck
	var mid := deck + TOP_H * 0.5
	var eaves := deck + TOP_H
	var hb := VillageHouse.BEAM * 0.5
	var front: Dictionary = groups.top_front
	var back: Dictionary = groups.top_back
	VillageHouse._box(front, "plaster", Vector3(0, mid, ud * 0.5 - t * 0.5), Vector3(uw, TOP_H, t))
	VillageHouse._box(back, "plaster", Vector3(0, mid, -ud * 0.5 + t * 0.5), Vector3(uw, TOP_H, t))
	for y: float in [deck + hb, deck + TOP_H - hb]:
		VillageHouse._box(front, "timber", Vector3(0, y, ud * 0.5 + 0.02), Vector3(uw + 0.1, VillageHouse.BEAM, VillageHouse.BEAM))
		VillageHouse._box(back, "timber", Vector3(0, y, -ud * 0.5 - 0.02), Vector3(uw + 0.1, VillageHouse.BEAM, VillageHouse.BEAM))
	VillageHouse._face(front, "plaster", Vector3(-uw * 0.5, eaves, ud * 0.5), Vector3.RIGHT, Vector3.FORWARD, Vector2(uw, t))
	VillageHouse._face(back, "plaster", Vector3(-uw * 0.5, eaves, -ud * 0.5 + t), Vector3.RIGHT, Vector3.FORWARD, Vector2(uw, t))
	for x: float in VillageHouse._window_spots(uw, INF):
		var outer := Vector3(x, deck + 1.3, ud * 0.5)
		VillageHouse._window(front, outer, 0.0)
		VillageHouse._inner_window(front, outer, Vector3(x, deck + 1.3, ud * 0.5 - t), 0.0)
	var behind := Vector3(0, deck + 1.3, -ud * 0.5)
	VillageHouse._window(back, behind, PI)
	VillageHouse._inner_window(back, behind, Vector3(0, deck + 1.3, -ud * 0.5 + t), PI)
	for side: float in [-1.0, 1.0]:
		var group: Dictionary = groups.top_right if side > 0.0 else groups.top_left
		VillageHouse._box(group, "plaster", Vector3(side * (uw * 0.5 - t * 0.5), mid, 0), Vector3(t, TOP_H, ud - t * 2.0))
		for y: float in [deck + hb, deck + TOP_H - hb]:
			VillageHouse._box(group, "timber", Vector3(side * (uw * 0.5 + 0.02), y, 0), Vector3(VillageHouse.BEAM, VillageHouse.BEAM, ud + 0.1))
		VillageHouse._face(group, "plaster", Vector3(side * uw * 0.5 - (t if side > 0.0 else 0.0), eaves, ud * 0.5 - t), Vector3.RIGHT, Vector3.FORWARD, Vector2(t, ud - t * 2.0))
		var outer := Vector3(side * uw * 0.5, deck + 1.3, 0)
		VillageHouse._window(group, outer, side * PI * 0.5)
		VillageHouse._inner_window(group, outer, Vector3(side * (uw * 0.5 - t), deck + 1.3, 0), side * PI * 0.5)
	roof(groups.top_roof, shape)


## The windows of the top room that look out through its walls (see VillageHouse._openings).
static func windows(shape: Dictionary) -> Array:
	var lay := GuildHall.layout(shape)
	var uw := float(shape.w) + VillageHouse.JETTY * 2.0
	var ud := float(shape.d) + VillageHouse.JETTY * 2.0
	var y: float = float(lay.deck) + 1.3
	var out := []
	for x: float in VillageHouse._window_spots(uw, INF):
		out.append({"at": Vector3(x, y, ud * 0.5), "out": Vector3.BACK})
	out.append({"at": Vector3(0, y, -ud * 0.5), "out": Vector3.FORWARD})
	for side: float in [-1.0, 1.0]:
		out.append({"at": Vector3(side * uw * 0.5, y, 0), "out": Vector3(side, 0, 0)})
	return out


## The pyramid roof over the top room: a slab of timber under the eaves, four slopes of tiles (each a
## triangle in rows of tile patches, like VillageHouse._roof), a post at the peak with a gilded ball
## and a pennant.
static func roof(parts: Dictionary, shape: Dictionary) -> void:
	var lay := GuildHall.layout(shape)
	var uw := float(shape.w) + VillageHouse.JETTY * 2.0
	var ud := float(shape.d) + VillageHouse.JETTY * 2.0
	var y0: float = float(lay.deck) + TOP_H
	var hw := uw * 0.5 + OVERHANG
	var hd := ud * 0.5 + OVERHANG
	VillageHouse._box(parts, "timber", Vector3(0, y0 + 0.06, 0), Vector3(hw * 2.0, 0.12, hd * 2.0))
	var base := y0 + 0.12
	var apex := Vector3(0, y0 + PEAK, 0)
	var corners := [Vector3(-hw, base, -hd), Vector3(hw, base, -hd), Vector3(hw, base, hd), Vector3(-hw, base, hd)]
	var st := VillageHouse._tool(parts, "roof")
	var seeds := RandomNumberGenerator.new()
	seeds.seed = hash(Vector2(uw, ud))
	var uv := VillageHouse.TILES_UV
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var mid := (a + b) * 0.5
		var n := (b - a).cross(apex - a).normalized()
		if n.dot(mid - Vector3(0, base, 0)) < 0.0:
			n = -n
		var cols := maxi(2, roundi(a.distance_to(b) / VillageHouse.TILES_PATCH.x))
		var rows := maxi(3, roundi(mid.distance_to(apex) / VillageHouse.TILES_PATCH.y))
		for r in rows:
			var t0 := float(r) / rows
			var t1 := float(r + 1) / rows
			var l0 := a.lerp(apex, t0)
			var r0 := b.lerp(apex, t0)
			var l1 := a.lerp(apex, t1)
			var r1 := b.lerp(apex, t1)
			for c in cols:
				var f0 := float(c) / cols
				var f1 := float(c + 1) / cols
				var quad := [l0.lerp(r0, f0), l0.lerp(r0, f1), l1.lerp(r1, f1), l1.lerp(r1, f0)]
				var uvs := [Vector2(uv.position.x, uv.end.y), uv.end, Vector2(uv.end.x, uv.position.y), uv.position]
				var order := [0, 2, 1, 0, 3, 2]
				if ((quad[2] as Vector3) - (quad[0] as Vector3)).cross((quad[1] as Vector3) - (quad[0] as Vector3)).dot(n) > 0.0:
					order = [0, 1, 2, 0, 2, 3]
				var seed_colour := Color(seeds.randf(), 0, 0)
				for k: int in order:
					st.set_color(seed_colour)
					st.set_normal(n)
					st.set_uv(uvs[k])
					st.add_vertex(quad[k])
	# The post at the peak, the gilded ball and a pennant of the tower's violet.
	VillageHouse._box(parts, "timber", apex + Vector3(0, SPIRE * 0.45, 0), Vector3(0.12, SPIRE, 0.12))
	VillageHouse._box(parts, "timber", apex + Vector3(0, SPIRE * 0.12, 0), Vector3(0.4, 0.12, 0.4))
	VillageHouse._box(parts, "stone", apex + Vector3(0, SPIRE + 0.12, 0), Vector3(0.3, 0.3, 0.3), Basis(Vector3(1, 1, 1).normalized(), 0.6))
	VillageHouse._box(parts, "timber", apex + Vector3(0.5, SPIRE * 0.8, 0), Vector3(0.9, 0.34, 0.03))


# --- Furnishing ----------------------------------------------------------------------

## The rooms of the opened tower (see GuildHall.furnish, which has laid the floors, the walls and the
## flights): the entrance hall, the library, the sleeping room and the experiment room.
static func rooms(walk_in: WalkIn, rec: Dictionary, lay: Dictionary, inside: Node3D) -> void:
	_entrance(walk_in, rec, lay, inside)
	_library(walk_in, rec, lay)
	_bedroom(walk_in, rec, lay)
	_laboratory(walk_in, rec, lay)


## A piece of furniture of the tower: `thing` under `parent` at `at`, turned, with a solid round it.
static func _put(walk_in: WalkIn, rec: Dictionary, parent: Node3D, thing: Node3D, at: Vector3, turn := 0.0, size := Vector3.ZERO) -> Node3D:
	return GuildHall._put(walk_in, rec, parent, thing, at, turn, size)


static func _mat(key: String, colour: Color, rough := 0.85) -> StandardMaterial3D:
	return WalkInFurniture._plain(key, colour, rough)


## A material that glows (the potions, the crystal, the circle's runes).
static func _glow(key: String, colour: Color, energy := 2.0) -> StandardMaterial3D:
	var full := "mage_glow_" + key
	if not WalkInFurniture._mats.has(full):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.emission_enabled = true
		mat.emission = colour
		mat.emission_energy_multiplier = energy
		mat.roughness = 0.3
		WalkInFurniture._mats[full] = mat
	return WalkInFurniture._mats[full]


static func _ball(parent: Node3D, radius: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## A storey's own light (hidden until the hero is there, see WalkIn._show_inside).
static func _storey_lamp(rec: Dictionary, parent: Node3D, key: int, at: Vector3, colour := WalkIn.LAMP_COLOUR) -> OmniLight3D:
	var lamp := GuildHall._lamp(parent, at)
	lamp.light_color = colour
	rec["storey_lamps"] = rec.get("storey_lamps", {})
	rec.storey_lamps[key] = lamp
	return lamp


## The entrance hall: the two tapestries side by side on the back wall, a long runner from the door,
## a round table with a crystal ball, a stand of staves and two pillars of candles by the door.
static func _entrance(walk_in: WalkIn, rec: Dictionary, lay: Dictionary, inside: Node3D) -> void:
	var room: Rect2 = lay.room
	var y: float = lay.floor
	var back := room.position.y
	for pair: Array in [[DRAGON, -1.25], [DEMON, 1.25]]:
		hang_tapestry(inside, String(pair[0]), Vector3(float(pair[1]), y + TAPESTRY_FROM, back + 0.03))
	_put(walk_in, rec, inside, WalkInFurniture.rug(Vector2(2.0, room.size.y - 1.6)), Vector3(0, y + 0.002, 0.2))
	# The table with the crystal ball, in front of the tapestries, the way to the door kept free.
	var table := WalkInFurniture.table(0.5)
	_put(walk_in, rec, inside, table, Vector3(0, y, back + 1.7), 0.0, Vector3(1.0, 0.8, 1.0))
	_ball(inside, 0.17, Vector3(0, y + 0.97, back + 1.7), _glow("crystal", GLOW, 2.5))
	WalkInFurniture._cylinder(inside, 0.12, 0.05, Vector3(0, y + 0.8, back + 1.7), _mat("brass", Color(0.78, 0.6, 0.3), 0.4))
	var light := OmniLight3D.new()
	light.name = "CrystalGlow"
	light.light_color = GLOW
	light.light_energy = 0.7
	light.omni_range = 4.0
	light.position = Vector3(0, y + 1.1, back + 1.7)
	inside.add_child(light)
	# A stand of staves and wands by the back wall's left tapestry, a bench under the right one.
	_put(walk_in, rec, inside, WalkInFurniture.weapon_rack(1.1), Vector3(room.position.x + 1.3 + 1.9, y, back + 0.22), 0.0, Vector3(1.1, 1.5, 0.4))
	_put(walk_in, rec, inside, WalkInFurniture.bench(1.5), Vector3(room.end.x - 1.3 - 1.9, y, back + 0.3), 0.0, Vector3(1.5, 0.5, 0.35))
	# Candle stands in the back corners, the way from the door to the stairs kept free.
	for x: float in [room.position.x + 0.35, room.end.x - 0.35]:
		_put(walk_in, rec, inside, candle_stand(), Vector3(x, y, back + 0.35), 0.0, Vector3(0.4, 1.4, 0.4))


## A tall iron stand with a ring of lit candles.
static func candle_stand() -> Node3D:
	var root := Node3D.new()
	root.name = "CandleStand"
	var iron := _mat("iron", Color(0.22, 0.22, 0.24), 0.5)
	WalkInFurniture._cylinder(root, 0.16, 0.05, Vector3(0, 0.025, 0), iron)
	WalkInFurniture._cylinder(root, 0.025, 1.3, Vector3(0, 0.65, 0), iron)
	WalkInFurniture._cylinder(root, 0.2, 0.04, Vector3(0, 1.3, 0), _mat("brass", Color(0.78, 0.6, 0.3), 0.4))
	for i in 5:
		var a := TAU * i / 5.0
		var spot := Vector3(cos(a) * 0.14, 1.32, sin(a) * 0.14)
		WalkInFurniture._cylinder(root, 0.02, 0.14, spot + Vector3(0, 0.07, 0), _mat("wax", Color(0.95, 0.92, 0.82), 0.6))
		_ball(root, 0.018, spot + Vector3(0, 0.17, 0), _glow("flame", Color(1.0, 0.78, 0.4), 3.0))
	return root


## The library and reading room on the first floor: bookcases round the back and left walls, a
## long reading table with chairs on a rug, two sofa chairs and a sofa round it, a globe and a lamp.
static func _library(walk_in: WalkIn, rec: Dictionary, lay: Dictionary) -> void:
	var upper: Node3D = (rec.node as Node3D).get_node("GuildUpper")
	var room: Rect2 = lay.up_room
	var y: float = lay.up_floor
	var back := room.position.y
	var left := room.position.x
	# Bookcases along the back wall (the left wall stays clear: the stairs up come out there).
	var x := left + 1.2
	while x + 1.1 < room.end.x - 0.2:
		_put(walk_in, rec, upper, WalkInFurniture.bookcase(2.2, 2.3, 0.42), Vector3(x + 0.0, y, back + 0.22), 0.0, Vector3(2.2, 2.3, 0.42))
		x += 2.25
	# The reading corner: a rug, the long table with a candle, and the seats round it.
	var mid := Vector3(-0.9, y, -0.6)
	_put(walk_in, rec, upper, WalkInFurniture.rug(Vector2(4.2, 3.2)), mid + Vector3(0, 0.002, 0.2))
	var table := WalkInFurniture.desk(2.2, 0.8, 1.0)
	table.name = "ReadingTable"
	_put(walk_in, rec, upper, table, mid, 0.0, Vector3(2.2, 0.85, 1.0))
	_put(walk_in, rec, upper, WalkInFurniture.table_candle(), mid + Vector3(-0.7, 0.8, -0.1))
	_put(walk_in, rec, upper, WalkInFurniture.chair(), mid + Vector3(-0.5, 0, -0.95), 0.0)
	_put(walk_in, rec, upper, WalkInFurniture.chair(), mid + Vector3(0.6, 0, -0.95), 0.0)
	_put(walk_in, rec, upper, sofa_chair(), mid + Vector3(-1.6, 0, 0.0), PI * 0.5, Vector3(0.95, 0.9, 0.95))
	_put(walk_in, rec, upper, sofa_chair(), mid + Vector3(1.6, 0, 0.0), -PI * 0.5, Vector3(0.95, 0.9, 0.95))
	_put(walk_in, rec, upper, sofa_chair(1.9), mid + Vector3(0, 0, 1.55), PI, Vector3(1.9, 0.9, 0.95))
	# A globe on a stand, a floor lamp, a side table with a book by the sofa chair.
	_put(walk_in, rec, upper, globe(), Vector3(room.end.x - 0.6, y, room.end.y - 0.7), 0.4, Vector3(0.7, 1.4, 0.7))
	_put(walk_in, rec, upper, WalkInFurniture.table(0.28), mid + Vector3(-1.6, 0, 1.2), 0.0, Vector3(0.56, 0.75, 0.56))
	WalkInFurniture._box(upper, Vector3(0.3, 0.05, 0.22), mid + Vector3(-1.6, 0.8, 1.2), _mat("book_red", Color(0.5, 0.16, 0.15)), Basis(Vector3.UP, 0.4))
	var lamp := _storey_lamp(rec, upper, GuildHall.UPPER_STOREY, Vector3(0, y + 2.1, 0.5))
	lamp.light_energy = 1.0


## A sofa chair (an armchair of velvet, `wide` metres across, a two-seater when wide), its front
## towards +z: a wooden plinth, a cushion, a high back and rolled arms.
static func sofa_chair(wide := 0.95) -> Node3D:
	var root := Node3D.new()
	root.name = "SofaChair" if wide < 1.2 else "Sofa"
	var wood := WalkInFurniture._wood()
	var velvet := _mat("velvet", VELVET, 0.95)
	var dark := _mat("velvet_dark", VELVET_DARK, 0.95)
	var deep := 0.9
	WalkInFurniture._box(root, Vector3(wide, 0.16, deep), Vector3(0, 0.1, 0), wood)
	WalkInFurniture._box(root, Vector3(wide - 0.36, 0.2, deep - 0.3), Vector3(0, 0.28, 0.08), velvet)
	WalkInFurniture._box(root, Vector3(wide, 0.62, 0.22), Vector3(0, 0.58, -deep * 0.5 + 0.11), dark)
	for s: float in [-1.0, 1.0]:
		WalkInFurniture._box(root, Vector3(0.18, 0.42, deep), Vector3(s * (wide * 0.5 - 0.09), 0.37, 0), dark)
		WalkInFurniture._cylinder(root, 0.09, deep, Vector3(s * (wide * 0.5 - 0.09), 0.6, 0), velvet, Basis(Vector3.RIGHT, PI * 0.5))
	if wide > 1.2:
		# Two cushions on the seat of a sofa.
		for s: float in [-1.0, 1.0]:
			WalkInFurniture._box(root, Vector3(wide * 0.38, 0.1, 0.1), Vector3(s * wide * 0.22, 0.58, -deep * 0.25), velvet, Basis(Vector3.RIGHT, 0.5))
	return root


## A globe on a wooden stand.
static func globe() -> Node3D:
	var root := Node3D.new()
	root.name = "Globe"
	var wood := WalkInFurniture._wood()
	WalkInFurniture._cylinder(root, 0.22, 0.05, Vector3(0, 0.025, 0), wood)
	WalkInFurniture._cylinder(root, 0.03, 0.8, Vector3(0, 0.45, 0), wood)
	_ball(root, 0.36, Vector3(0, 1.1, 0), _mat("globe_sea", Color(0.2, 0.36, 0.55), 0.5))
	for k in 5:
		var a := 0.8 + k * 1.3
		_ball(root, 0.1, Vector3(cos(a) * 0.3, 1.1 + sin(a * 1.7) * 0.18, sin(a) * 0.3), _mat("globe_land", Color(0.38, 0.5, 0.28), 0.8))
	WalkInFurniture._box(root, Vector3(0.04, 0.84, 0.04), Vector3(0.38, 1.05, 0), wood)
	return root


## The sleeping room on the second floor, under the pointed roof: two beds along the back wall with
## a bedside table each, a chest at the foot of each, a wardrobe, a rug, a telescope at the front
## window and a table with candles. Aldo and Odo sleep here (see VillageBeds).
static func _bedroom(walk_in: WalkIn, rec: Dictionary, lay: Dictionary) -> void:
	var hall: Node3D = rec.node
	var roof: Node3D = rec.roof_node
	var room: Rect2 = lay.up_room
	var y: float = lay.deck
	var back := room.position.y
	var right := room.end.x
	var origin_z := back + 0.3 - CosyBed.HEAD
	_put(walk_in, rec, roof, WalkInFurniture.rug(Vector2(5.2, 3.0)), Vector3(0.9, y + 0.002, back + 2.6))
	var stand_z := origin_z + (CosyBed.FOOT + CosyBed.HEAD) * 0.5
	rec["ground_beds"] = true
	for spec: Array in [[-1.9, "AldoBed"], [1.7, "OdoBed"]]:
		var origin := Vector3(float(spec[0]), y, origin_z)
		var bed := CosyBed.build(roof, origin, 0.0, true)
		bed.name = String(spec[1])
		walk_in._solid(rec, Vector3(origin.x + (CosyBed.LEFT + CosyBed.TABLE_EDGE) * 0.5, y + 0.5, origin.z + (CosyBed.FOOT + CosyBed.HEAD) * 0.5),
				Vector3(CosyBed.TABLE_EDGE - CosyBed.LEFT, 1.0, CosyBed.FOOT - CosyBed.HEAD))
		var stand := hall.transform * Vector3(origin.x + CosyBed.LEFT - 0.6, y, stand_z)
		rec.beds.append({"pos": hall.transform * origin, "rot": hall.rotation.y, "by": null, "stand": stand})
		rec["ladder"] = stand
		rec["ladder_top"] = stand
		# A chest at the foot of the bed.
		_put(walk_in, rec, roof, WalkInFurniture.crate(0.7), Vector3(origin.x + 0.1, y, origin.z + CosyBed.FOOT + 0.45), 0.0, Vector3(0.9, 0.6, 0.6))
	rec["owner"] = OWNERS[0]
	rec["owners"] = OWNERS
	# A wardrobe in the back corner on the right, a bookcase between the beds' tables.
	_put(walk_in, rec, roof, WalkInFurniture.bookcase(1.5, 2.2, 0.5), Vector3(right - 0.3, y, back + 3.0), -PI * 0.5, Vector3(1.5, 2.2, 0.5))
	# A table with candles and a stool by the right wall, and the telescope at the window in front.
	_put(walk_in, rec, roof, WalkInFurniture.table(0.45), Vector3(right - 1.0, y, 1.0), 0.0, Vector3(0.9, 0.8, 0.9))
	_put(walk_in, rec, roof, WalkInFurniture.table_candle(), Vector3(right - 1.0, y + 0.79, 1.0))
	_put(walk_in, rec, roof, WalkInFurniture.stool(), Vector3(right - 1.9, y, 1.0))
	_put(walk_in, rec, roof, telescope(), Vector3(room.position.x + 1.5 + 1.5, y, room.end.y - 0.9), 0.0, Vector3(0.9, 1.2, 0.9))
	_storey_lamp(rec, roof, GuildHall.ROOF_STOREY, Vector3(0, y + 2.2, 0.0))


## A brass telescope on a tripod, looking out and up.
static func telescope() -> Node3D:
	var root := Node3D.new()
	root.name = "Telescope"
	var wood := WalkInFurniture._wood()
	var brass := _mat("brass", Color(0.78, 0.6, 0.3), 0.4)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var foot := Vector3(cos(a) * 0.35, 0, sin(a) * 0.35)
		var top := Vector3(0, 1.05, 0)
		var along := top - foot
		WalkInFurniture._box(root, Vector3(0.04, 0.04, along.length()), foot.lerp(top, 0.5), wood, Basis.looking_at(along.normalized(), Vector3.UP))
	var tube := WalkInFurniture._cylinder(root, 0.07, 1.3, Vector3(0, 1.3, 0.2), brass, Basis(Vector3.RIGHT, PI * 0.5 + 0.5))
	tube.name = "Tube"
	WalkInFurniture._cylinder(root, 0.1, 0.1, Vector3(0, 1.78, -0.28), brass, Basis(Vector3.RIGHT, PI * 0.5 + 0.5))
	return root


## The cellar under the tower, the mages' experiment room: stone walls and flags, the flight up along
## the left wall, a glowing circle on the floor, a cauldron, a bench of flasks, shelves of jars and a still.
## Its hole in the ground goes to the level (Outdoor.hall_holes).
static func _laboratory(walk_in: WalkIn, rec: Dictionary, lay: Dictionary) -> void:
	var hall: Node3D = rec.node
	var cellar: Node3D = rec.cellar_node
	var shape: Dictionary = hall.get_meta("shape")
	var y := GuildHall.CELLAR
	var h := GuildHall.HOLE
	walk_in._solid(rec, Vector3(0, y - 0.25, 0), Vector3(h * 2.0, 0.5, h * 2.0))
	cellar.add_child(WalkInFurniture.flagstones(Vector2(h * 2.0, h * 2.0), y + 0.005))
	var parts := {}
	var deep := -y
	VillageHouse._face(parts, "stone", Vector3(-h, y, -h), Vector3.RIGHT, Vector3.UP, Vector2(h * 2.0, deep))
	VillageHouse._face(parts, "stone", Vector3(-h, y, h), Vector3.FORWARD, Vector3.UP, Vector2(h * 2.0, deep))
	VillageHouse._face(parts, "stone", Vector3(h, y, -h), Vector3.BACK, Vector3.UP, Vector2(h * 2.0, deep))
	VillageHouse._face(parts, "stone", Vector3(h, y, h), Vector3.LEFT, Vector3.UP, Vector2(h * 2.0, deep))
	var c: Dictionary = lay.c
	VillageHouse._box(parts, "stone", Vector3(float(c.x1) + 0.1, y * 0.5, (h + float(c.foot)) * 0.5), Vector3(0.2, deep, h - float(c.foot)))
	var walls := VillageHouse._mesh_of(parts, shape.mats)
	walls.name = "CellarWalls"
	cellar.add_child(walls)
	# The way down, as for the guildhall (see GuildHall._cellar).
	var inner: Array[Vector3] = []
	for p in GuildHall.way(lay, GuildHall.GROUND_STOREY, GuildHall.ROOF_STOREY):
		inner.append(hall.transform * p)
	rec["inner_way"] = inner
	# The circle on the floor: two rings and runes of violet light on a disc of dark stone.
	var circle := Vector3(2.0, y, 0.3)
	_put(walk_in, rec, cellar, summoning_circle(), circle)
	# The cauldron on its fire at the back wall, the bench of flasks along the right wall.
	_put(walk_in, rec, cellar, cauldron(), Vector3(-0.2, y, -h + 0.95), 0.0, Vector3(1.3, 1.0, 1.3))
	var bench := WalkInFurniture.counter(3.2, 0.95, 0.8)
	bench.name = "AlchemistBench"
	_put(walk_in, rec, cellar, bench, Vector3(h - 0.5, y, 0.6), -PI * 0.5, Vector3(3.2, 1.0, 0.8))
	_flasks(cellar, Vector3(h - 0.5, y + 0.95, 0.6), -PI * 0.5)
	# Shelves of jars on the back wall, a still and a tank of glowing water by the front wall.
	_put(walk_in, rec, cellar, WalkInFurniture.bookcase(1.9, 2.2, 0.5), Vector3(1.9, y, -h + 0.26), 0.0, Vector3(1.9, 2.2, 0.5))
	_put(walk_in, rec, cellar, WalkInFurniture.bookcase(1.9, 2.2, 0.5), Vector3(3.2, y, -h + 0.26), 0.0, Vector3(1.9, 2.2, 0.5))
	_jars(cellar, Vector3(1.9, y, -h + 0.5))
	_jars(cellar, Vector3(3.2, y, -h + 0.5))
	_put(walk_in, rec, cellar, still(), Vector3(-0.4, y, h - 0.9), PI, Vector3(1.2, 1.4, 1.0))
	_put(walk_in, rec, cellar, WalkInFurniture.barrel(), Vector3(-2.0, y, h - 0.45), 0.0, Vector3(0.64, 0.9, 0.64))
	_put(walk_in, rec, cellar, WalkInFurniture.crate(0.7), Vector3(-1.2, y, h - 0.45), 0.2, Vector3(0.7, 0.7, 0.7))
	_put(walk_in, rec, cellar, WalkInFurniture.crate(0.6), Vector3(3.3, y, h - 0.4), 0.0, Vector3(0.6, 0.6, 0.6))
	# A lectern with an open spellbook beside the circle, a skull on it.
	_put(walk_in, rec, cellar, lectern(), Vector3(0.2, y, 1.9), PI * 0.8, Vector3(0.6, 1.2, 0.6))
	var lamp := _storey_lamp(rec, cellar, GuildHall.CELLAR_STOREY, Vector3(0.5, y + 2.1, 0.0), LAB_LAMP)
	lamp.light_energy = 1.2
	# The hole in the ground: the 2 m cells under the cellar (world, see Outdoor.set_floor_holes).
	var holes = walk_in.level.get("hall_holes")
	if holes is Array:
		var mid := hall.global_position if hall.is_inside_tree() else hall.position
		for i in range(-2, 2):
			for j in range(-2, 2):
				(holes as Array).append(Rect2(mid.x + i * 2.0, mid.z + j * 2.0, 2.0, 2.0))


## A circle of violet light on the floor: a dark disc with two glowing rings and runes between them.
static func summoning_circle() -> Node3D:
	var root := Node3D.new()
	root.name = "SummoningCircle"
	WalkInFurniture._cylinder(root, 1.55, 0.012, Vector3(0, 0.008, 0), _mat("circle_stone", Color(0.12, 0.1, 0.15), 0.8))
	for spec: Array in [[1.45, 1.36], [0.95, 0.88]]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.outer_radius = float(spec[0])
		torus.inner_radius = float(spec[1])
		torus.rings = 40
		torus.ring_segments = 4
		ring.mesh = torus
		ring.material_override = _glow("rune", GLOW, 2.2)
		ring.scale = Vector3(1, 0.04, 1)
		ring.position = Vector3(0, 0.02, 0)
		root.add_child(ring)
	for i in 8:
		var a := TAU * i / 8.0
		var at := Vector3(cos(a) * 1.16, 0.02, sin(a) * 1.16)
		WalkInFurniture._box(root, Vector3(0.1, 0.012, 0.24), at, _glow("rune", GLOW, 2.2), Basis(Vector3.UP, -a))
		WalkInFurniture._box(root, Vector3(0.2, 0.012, 0.06), at, _glow("rune", GLOW, 2.2), Basis(Vector3.UP, -a))
	var light := OmniLight3D.new()
	light.name = "CircleGlow"
	light.light_color = GLOW
	light.light_energy = 0.9
	light.omni_range = 4.5
	light.position = Vector3(0, 0.5, 0)
	root.add_child(light)
	return root


## An iron cauldron on a bed of embers, a green brew bubbling in it.
static func cauldron() -> Node3D:
	var root := Node3D.new()
	root.name = "Cauldron"
	var iron := _mat("cauldron_iron", Color(0.12, 0.12, 0.14), 0.45)
	WalkInFurniture._cylinder(root, 0.75, 0.08, Vector3(0, 0.04, 0), _glow("embers", Color(1.0, 0.4, 0.12), 1.6))
	for k in 3:
		var a := 0.4 + TAU * k / 3.0
		WalkInFurniture._box(root, Vector3(0.7, 0.12, 0.16), Vector3(cos(a) * 0.25, 0.16, sin(a) * 0.25), _mat("log", Color(0.22, 0.14, 0.08)), Basis(Vector3.UP, -a))
	_ball(root, 0.55, Vector3(0, 0.72, 0), iron).scale = Vector3(1, 0.85, 1)
	var brew := WalkInFurniture._cylinder(root, 0.43, 0.03, Vector3(0, 0.99, 0), _glow("brew", Color(0.3, 1.0, 0.45), 1.8))
	brew.name = "Brew"
	for k in 4:
		var a := k * 1.7
		_ball(root, 0.05 + 0.02 * (k % 2), Vector3(cos(a) * 0.22, 1.05 + 0.04 * k, sin(a) * 0.22), _glow("brew", Color(0.3, 1.0, 0.45), 1.8))
	var rim := TorusMesh.new()
	rim.outer_radius = 0.5
	rim.inner_radius = 0.43
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.material_override = iron
	rim_mi.position = Vector3(0, 1.0, 0)
	rim_mi.scale = Vector3(1, 0.6, 1)
	root.add_child(rim_mi)
	var light := OmniLight3D.new()
	light.name = "BrewGlow"
	light.light_color = Color(0.4, 1.0, 0.5)
	light.light_energy = 0.8
	light.omni_range = 3.6
	light.position = Vector3(0, 1.3, 0)
	root.add_child(light)
	return root


## Flasks and beakers of coloured liquid in a row on a bench at `at` (the bench's middle, its top
## height), the bench running along `turn`.
static func _flasks(parent: Node3D, at: Vector3, turn: float) -> void:
	var holder := Node3D.new()
	holder.name = "Flasks"
	holder.position = at
	holder.rotation.y = turn
	parent.add_child(holder)
	var colours := [Color(0.9, 0.2, 0.3), Color(0.25, 0.7, 1.0), Color(0.95, 0.8, 0.2), Color(0.4, 1.0, 0.4), Color(0.8, 0.35, 1.0)]
	for i in 5:
		var x := -1.2 + i * 0.58
		var colour: Color = colours[i]
		var glass := _mat("glass_pale", Color(0.82, 0.9, 0.95, 0.35), 0.1)
		WalkInFurniture._cylinder(holder, 0.1 + 0.02 * (i % 2), 0.2, Vector3(x, 0.1, 0), glass)
		WalkInFurniture._cylinder(holder, 0.085 + 0.02 * (i % 2), 0.12, Vector3(x, 0.07, 0), _glow("potion%d" % i, colour, 1.4))
		WalkInFurniture._cylinder(holder, 0.03, 0.12, Vector3(x, 0.26, 0), glass)
	# Over the middle, a retort: a glowing ball with a long neck.
	_ball(holder, 0.14, Vector3(0.3, 0.38, -0.12), _glow("retort", Color(0.5, 0.9, 1.0), 1.4))
	WalkInFurniture._cylinder(holder, 0.025, 0.3, Vector3(0.38, 0.55, -0.12), _mat("glass_pale", Color(0.82, 0.9, 0.95, 0.35), 0.1), Basis(Vector3.FORWARD, 0.9))


## Jars on the shelves of a bookcase standing at `at` (the cellar's frame): small glowing and plain
## jars in each row.
static func _jars(parent: Node3D, at: Vector3) -> void:
	var colours := [Color(0.6, 1.0, 0.5), Color(1.0, 0.6, 0.25), Color(0.6, 0.5, 1.0), Color(0.95, 0.9, 0.7)]
	for row in 3:
		for k in 4:
			var jar := WalkInFurniture._cylinder(parent, 0.08, 0.17, at + Vector3(-0.7 + k * 0.45, 0.42 + row * 0.6, 0.0), _glow("jar%d" % ((row + k) % 4), colours[(row + k) % 4], 0.9))
			jar.name = "Jar"


## A still: a copper pot over a small fire, a long neck bending to a flask, on a stone stand.
static func still() -> Node3D:
	var root := Node3D.new()
	root.name = "Still"
	var copper := _mat("copper", Color(0.72, 0.4, 0.22), 0.4)
	WalkInFurniture._box(root, Vector3(1.0, 0.5, 0.7), Vector3(0, 0.25, 0), _mat("still_stone", STONE, 0.95))
	_ball(root, 0.36, Vector3(-0.2, 0.86, 0), copper)
	WalkInFurniture._cylinder(root, 0.12, 0.3, Vector3(-0.2, 1.3, 0), copper)
	WalkInFurniture._cylinder(root, 0.04, 0.8, Vector3(0.1, 1.5, 0), copper, Basis(Vector3.FORWARD, PI * 0.5))
	WalkInFurniture._cylinder(root, 0.04, 0.5, Vector3(0.48, 1.25, 0), copper)
	WalkInFurniture._cylinder(root, 0.09, 0.2, Vector3(0.48, 0.65, 0), _glow("distillate", Color(0.9, 0.7, 1.0), 1.2))
	return root


## A lectern with an open book and a skull.
static func lectern() -> Node3D:
	var root := Node3D.new()
	root.name = "Lectern"
	var wood := WalkInFurniture._wood()
	WalkInFurniture._cylinder(root, 0.18, 0.05, Vector3(0, 0.025, 0), wood)
	WalkInFurniture._cylinder(root, 0.05, 0.95, Vector3(0, 0.5, 0), wood)
	WalkInFurniture._box(root, Vector3(0.6, 0.04, 0.45), Vector3(0, 1.0, 0), wood, Basis(Vector3.RIGHT, 0.4))
	WalkInFurniture._box(root, Vector3(0.5, 0.03, 0.34), Vector3(0, 1.05, -0.01), _mat("page", Color(0.9, 0.85, 0.7)), Basis(Vector3.RIGHT, 0.4))
	_ball(root, 0.09, Vector3(0.45, 0.14, 0.0), _mat("bone", Color(0.88, 0.85, 0.75)))
	return root


# --- The tapestries ------------------------------------------------------------------

## Hangs the tapestry `which` (DRAGON or DEMON) on a wall, its lower edge at `at`, its middle on `at.x`,
## facing +z with its back on the wall at `at.z`: a rod with golden knobs, the woven picture and a
## tassel on each lower corner.
static func hang_tapestry(parent: Node3D, which: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Tapestry_" + which
	root.position = at
	parent.add_child(root)
	var gold := _mat("tapestry_gold", Color(0.85, 0.68, 0.3), 0.4)
	var picture := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = TAPESTRY
	picture.mesh = quad
	var cloth := StandardMaterial3D.new()
	cloth.albedo_texture = picture_of(which)
	cloth.roughness = 1.0
	cloth.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.material_override = cloth
	picture.position = Vector3(0, TAPESTRY.y * 0.5, 0.02)
	root.add_child(picture)
	WalkInFurniture._cylinder(root, 0.03, TAPESTRY.x + 0.3, Vector3(0, TAPESTRY.y + 0.04, 0.04), WalkInFurniture._wood(), Basis(Vector3.FORWARD, PI * 0.5))
	for s: float in [-1.0, 1.0]:
		_ball(root, 0.06, Vector3(s * (TAPESTRY.x * 0.5 + 0.15), TAPESTRY.y + 0.04, 0.04), gold)
		WalkInFurniture._box(root, Vector3(0.05, 0.16, 0.05), Vector3(s * (TAPESTRY.x * 0.5 - 0.06), -0.06, 0.03), gold)
	return root


## The picture of a tapestry, drawn once: a mage against a dragon or against a demon, in woven colours
## inside a golden border.
static func picture_of(which: String) -> ImageTexture:
	if _pictures.has(which):
		return _pictures[which]
	var w := 256
	var h := 288
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	if which == DRAGON:
		_paint_dragon(img)
	else:
		_paint_demon(img)
	_weave(img)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_pictures[which] = tex
	return tex


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## Fills a polygon (points in pixels) with `c`.
static func _poly(img: Image, pts: Array, c: Color) -> void:
	var lo := 1 << 20
	var hi := -(1 << 20)
	for p: Vector2 in pts:
		lo = mini(lo, floori(p.y))
		hi = maxi(hi, ceili(p.y))
	for y in range(maxi(lo, 0), mini(hi, img.get_height() - 1) + 1):
		var xs: Array[float] = []
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			for x in range(roundi(xs[k]), roundi(xs[k + 1]) + 1):
				_px(img, x, y, c)


static func _disc(img: Image, centre: Vector2, radius: float, c: Color) -> void:
	for y in range(floori(centre.y - radius), ceili(centre.y + radius) + 1):
		for x in range(floori(centre.x - radius), ceili(centre.x + radius) + 1):
			if Vector2(x, y).distance_to(centre) <= radius:
				_px(img, x, y, c)


static func _glow_disc(img: Image, centre: Vector2, radius: float, c: Color) -> void:
	for y in range(floori(centre.y - radius), ceili(centre.y + radius) + 1):
		for x in range(floori(centre.x - radius), ceili(centre.x + radius) + 1):
			var d := Vector2(x, y).distance_to(centre) / radius
			if d < 1.0 and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				var k := pow(1.0 - d, 1.6)
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, k))


## A thick line from `a` to `b`.
static func _stroke(img: Image, a: Vector2, b: Vector2, width: float, c: Color) -> void:
	var n := ceili(a.distance_to(b))
	for i in n + 1:
		_disc(img, a.lerp(b, float(i) / maxf(1.0, n)), width * 0.5, c)


## A sky from `top` to `bottom`, with a few stars.
static func _sky(img: Image, top: Color, bottom: Color, stars := true) -> void:
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, top.lerp(bottom, pow(float(y) / img.get_height(), 1.3)))
	if stars:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 40:
			_disc(img, Vector2(rng.randf_range(14, 242), rng.randf_range(14, 150)), rng.randf_range(0.8, 1.6), Color(1.0, 0.95, 0.75))


## A mage, `s` times the size of the standard one (about 120 px high at 1), feet at `foot`, facing
## `face` (+1 right, -1 left), in robes of `robe`, a staff with a glowing orb raised towards the foe.
static func _mage(img: Image, foot: Vector2, s: float, face: float, robe: Color, orb: Color) -> void:
	var dark := robe.darkened(0.35)
	var f := func(x: float, y: float) -> Vector2: return foot + Vector2(x * face, y) * s
	# The staff, the robe, the arm, the beard, the face and the hat.
	_stroke(img, f.call(18, 0), f.call(26, -122), 5.0 * s, Color(0.45, 0.3, 0.18))
	_poly(img, [f.call(-26, 0), f.call(26, 0), f.call(12, -58), f.call(-12, -58)], robe)
	_poly(img, [f.call(-26, 0), f.call(-6, 0), f.call(-4, -58), f.call(-12, -58)], dark)
	_poly(img, [f.call(-12, -56), f.call(12, -56), f.call(8, -76), f.call(-8, -76)], robe)
	_stroke(img, f.call(8, -64), f.call(24, -78), 7.0 * s, robe)
	_disc(img, f.call(26, -82), 4.5 * s, Color(0.95, 0.8, 0.62))
	_poly(img, [f.call(-7, -70), f.call(7, -70), f.call(3, -52), f.call(-3, -52)], Color(0.92, 0.92, 0.95))
	_disc(img, f.call(0, -82), 8.0 * s, Color(0.95, 0.8, 0.62))
	_poly(img, [f.call(-14, -86), f.call(14, -86), f.call(0, -124)], dark)
	_poly(img, [f.call(-18, -84), f.call(18, -84), f.call(16, -90), f.call(-16, -90)], robe)
	_glow_disc(img, f.call(26, -128), 26.0 * s, orb)
	_disc(img, f.call(26, -128), 6.5 * s, Color(1, 1, 1))


static func _paint_dragon(img: Image) -> void:
	_sky(img, Color(0.07, 0.07, 0.2), Color(0.5, 0.18, 0.1))
	# Mountains and the glow of the fire behind them.
	_poly(img, [Vector2(0, 230), Vector2(40, 175), Vector2(80, 215), Vector2(130, 160), Vector2(190, 220), Vector2(230, 180), Vector2(256, 205), Vector2(256, 288), Vector2(0, 288)], Color(0.14, 0.1, 0.12))
	var red := Color(0.72, 0.1, 0.1)
	var dark := Color(0.42, 0.05, 0.08)
	# The dragon: wings, a coiling body, a long neck, a head with open jaws.
	_poly(img, [Vector2(150, 90), Vector2(236, 22), Vector2(230, 72), Vector2(250, 88), Vector2(222, 108), Vector2(232, 140), Vector2(190, 120), Vector2(170, 130)], dark)
	_poly(img, [Vector2(150, 96), Vector2(200, 44), Vector2(196, 78), Vector2(214, 92), Vector2(190, 108), Vector2(172, 126)], Color(0.62, 0.13, 0.12))
	_stroke(img, Vector2(236, 230), Vector2(210, 190), 26.0, red)
	_stroke(img, Vector2(210, 190), Vector2(170, 150), 30.0, red)
	_stroke(img, Vector2(170, 150), Vector2(150, 100), 22.0, red)
	_stroke(img, Vector2(236, 232), Vector2(252, 262), 10.0, red)
	_stroke(img, Vector2(236, 238), Vector2(190, 252), 8.0, dark)
	_disc(img, Vector2(150, 92), 17.0, red)
	_poly(img, [Vector2(140, 80), Vector2(96, 92), Vector2(100, 100), Vector2(142, 98)], red)
	_poly(img, [Vector2(142, 100), Vector2(98, 106), Vector2(106, 116), Vector2(146, 108)], dark)
	_poly(img, [Vector2(146, 78), Vector2(158, 52), Vector2(160, 80)], dark)
	_disc(img, Vector2(142, 84), 3.0, Color(1.0, 0.9, 0.2))
	# Belly plates.
	for i in 6:
		_stroke(img, Vector2(158 + i * 11, 160 + i * 6), Vector2(168 + i * 11, 152 + i * 6), 3.0, Color(0.92, 0.7, 0.35))
	# The fire from its jaws towards the mage.
	var flame := [Vector2(100, 100), Vector2(60, 90), Vector2(28, 128), Vector2(48, 132), Vector2(20, 168), Vector2(68, 146), Vector2(88, 124), Vector2(60, 116)]
	_poly(img, flame, Color(1.0, 0.5, 0.1))
	_poly(img, [Vector2(98, 102), Vector2(64, 100), Vector2(40, 128), Vector2(66, 128), Vector2(88, 116)], Color(1.0, 0.82, 0.25))
	# The mage, with a shield of light before him.
	_glow_disc(img, Vector2(52, 190), 60.0, Color(0.4, 0.7, 1.0, 0.8))
	_poly(img, [Vector2(0, 288), Vector2(256, 288), Vector2(256, 250), Vector2(0, 250)], Color(0.12, 0.08, 0.1))
	_mage(img, Vector2(52, 262), 1.25, 1.0, Color(0.3, 0.3, 0.85), Color(0.5, 0.85, 1.0))
	_stroke(img, Vector2(70, 150), Vector2(96, 200), 3.0, Color(0.6, 0.9, 1.0))


static func _paint_demon(img: Image) -> void:
	_sky(img, Color(0.05, 0.02, 0.1), Color(0.55, 0.08, 0.1), false)
	# Rising flames at the bottom.
	for i in 9:
		var x := 16.0 + i * 28.0
		_poly(img, [Vector2(x - 20, 288), Vector2(x - 6, 236 - (i % 3) * 14), Vector2(x + 4, 262), Vector2(x + 10, 226 - (i % 2) * 20), Vector2(x + 24, 288)], Color(1.0, 0.45, 0.08))
		_poly(img, [Vector2(x - 8, 288), Vector2(x, 256 - (i % 3) * 8), Vector2(x + 10, 288)], Color(1.0, 0.85, 0.3))
	var skin := Color(0.42, 0.06, 0.16)
	var dark := Color(0.2, 0.03, 0.1)
	# Wings, the body, arms with claws, the horned head with burning eyes.
	_poly(img, [Vector2(128, 120), Vector2(10, 40), Vector2(30, 100), Vector2(8, 130), Vector2(40, 150), Vector2(30, 190), Vector2(110, 170)], dark)
	_poly(img, [Vector2(128, 120), Vector2(246, 40), Vector2(226, 100), Vector2(248, 130), Vector2(216, 150), Vector2(226, 190), Vector2(146, 170)], dark)
	_poly(img, [Vector2(92, 110), Vector2(164, 110), Vector2(176, 200), Vector2(150, 250), Vector2(106, 250), Vector2(80, 200)], skin)
	_stroke(img, Vector2(96, 120), Vector2(60, 170), 16.0, skin)
	_stroke(img, Vector2(160, 120), Vector2(196, 170), 16.0, skin)
	for dx in [-8, 0, 8]:
		_stroke(img, Vector2(60 + dx, 170), Vector2(52 + dx, 196), 4.0, Color(0.9, 0.85, 0.7))
		_stroke(img, Vector2(196 + dx, 170), Vector2(204 + dx, 196), 4.0, Color(0.9, 0.85, 0.7))
	_disc(img, Vector2(128, 88), 24.0, skin)
	_poly(img, [Vector2(108, 74), Vector2(88, 30), Vector2(122, 62)], Color(0.9, 0.85, 0.7))
	_poly(img, [Vector2(148, 74), Vector2(168, 30), Vector2(134, 62)], Color(0.9, 0.85, 0.7))
	_poly(img, [Vector2(112, 86), Vector2(124, 92), Vector2(112, 94)], Color(1.0, 0.85, 0.2))
	_poly(img, [Vector2(144, 86), Vector2(132, 92), Vector2(144, 94)], Color(1.0, 0.85, 0.2))
	_glow_disc(img, Vector2(114, 90), 10.0, Color(1.0, 0.9, 0.3))
	_glow_disc(img, Vector2(142, 90), 10.0, Color(1.0, 0.9, 0.3))
	_poly(img, [Vector2(112, 106), Vector2(144, 106), Vector2(138, 114), Vector2(118, 114)], Color(0.1, 0.0, 0.04))
	# The mage in white and gold with a star of light cast at the demon.
	_glow_disc(img, Vector2(56, 214), 70.0, Color(1.0, 0.95, 0.6, 0.9))
	_mage(img, Vector2(60, 280), 1.0, 1.0, Color(0.88, 0.88, 0.95), Color(1.0, 0.95, 0.55))
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		_stroke(img, Vector2(86, 150) + Vector2(cos(a), sin(a)) * 10.0, Vector2(86, 150) + Vector2(cos(a), sin(a)) * 30.0, 3.0, Color(1.0, 0.95, 0.6))


## The woven look: a golden border with a darker band, and a faint grain of threads over it all.
static func _weave(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var grain := 0.93 + 0.07 * (1.0 if (x + y) % 3 == 0 else 0.0) + rng.randf_range(-0.03, 0.03)
			c = Color(c.r * grain, c.g * grain, c.b * grain, 1.0)
			var edge := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			if edge < 6:
				c = Color(0.86, 0.68, 0.3) * (0.9 + 0.1 * (1.0 if (x / 2 + y / 2) % 2 == 0 else 0.0))
			elif edge < 11:
				c = Color(0.3, 0.12, 0.16)
			elif edge < 13:
				c = Color(0.86, 0.68, 0.3)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
