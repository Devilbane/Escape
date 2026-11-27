class_name VillageHouse
## The villagers' homes: old stone houses built from simple blocks at load
## time, of the same weathered stone as the temple (see AgedStone): stone
## walls, an upper floor that juts out a little over the street on a band of
## oak beams, a steep tiled roof with a chimney, shuttered windows and a plank
## door. Every house gets its own stone tint, roof shade, size and door side,
## so no two look the same. Ivy and bird nests are added by the village (see
## Outdoor._dress_building).
##
## Built facing south (+z, the door side) around the middle of its ground
## floor; the caller turns and places it. The textures are all CC0: wood and
## roof tiles from ambientCG (assets/house), stone and the door from the
## Modular Cathedral Kit (assets/chapel).

const WOOD_TEX := "res://assets/house/wood_floor.jpg"
const STONE_TEX := "res://assets/chapel/trim_sheet.png"
const DOOR_TEX := "res://assets/chapel/door_diffuse.png"
const ROOF_SHADER := preload("res://shaders/aged_roof.gdshader")

## Roof tints, picked per house (the stone tints are AgedStone.HOUSE_TINTS).
const ROOFS := [Color(1, 1, 1), Color(0.8, 0.72, 0.68), Color(0.72, 0.74, 0.8), Color(1.0, 0.86, 0.7)]
const TIMBER := Color(0.42, 0.30, 0.22)
## Where the stone blocks sit on the cathedral trim sheet: v from the top of
## four rows of blocks to their bottom, and how many metres those rows cover.
const STONE_V := Vector2(0.6, 0.92)
const STONE_BAND := 4.0
## The red roof tiles on the same sheet (the chapel's roof): u and v from
## corner to corner, and the patch of roof (metres) one copy of them covers. The rectangle is kept
## TILES_INSET (sheet fractions, 8 texels) inside the tiles' part of the sheet: the roof shader samples
## up to mip level 3 (8 texels wide), which would otherwise blend in the stone beyond the patch's
## edge and draw pale lines along the seams between patches that flicker as the camera moves.
const TILES_INSET := 8.0 / 512.0
const TILES_UV := Rect2(0.5 + TILES_INSET, 0.06 + TILES_INSET, 0.5 - TILES_INSET * 2.0, 0.235 - TILES_INSET * 2.0)
const TILES_PATCH := Vector2(2.4, 1.2)

## Heights (metres): stone plinth, ground floor, upper floor, and how far the
## upper floor juts out. Beams are this thick.
const PLINTH := 0.5
const GROUND := 3.0
const UPPER := 2.6
const JETTY := 0.3
const BEAM := 0.22
const ROOF_OVERHANG := 0.45

static var _mats := {}
## The flat tops of the small timber and stone things on the front of the house being built (door
## lintel, window sills and heads, the beams of the jetty, the doorstep), each four corners in the
## house's frame. Kept as meta "snow_ledges" so a dusting of snow lies on them even under the eaves
## (see SnowCaps.ledges_of). Noted only while a house is built (see _noting).
static var _ledges: Array = []
static var _noting := false
## The middles of the window panes of the house being built (kept on the
## house as meta "windows", so the ivy can leave them clear).
static var _panes: Array = []
## Which way each of those panes faces (meta "window_outs"), so the light can fall in front of it.
static var _outs: Array = []
## The place of the pane being built, which its glass carries (see WindowLights).
static var _pane_key := Vector2.ZERO
## The hinge (house frame, x and z) of the shutter leaf being built, and which way it swings shut (1
## or -1), which its mesh carries (see WindowLights.SHUTTER_SHADER).
static var _hinge := Vector2.ZERO
static var _swing := 1.0
## Where each shutter leaf's hinge is (the house's frame), meta "shutter_hinges": the shutters make a
## sound where they swing (see Outdoor._shutter_sounds).
static var _hinges: Array = []
## The windows of the rooms one walks into, while such a house is built (see hollow): each
## {at, out}, the middle of its outer face and the way it looks out (the house's frame). Every wall
## face they lie in is cut open there (see _face, _box), so one sees through the wall, and their
## glass is clear (see _window, _inner_window). Empty while a house is built that one cannot enter:
## its windows stay lit panes on the wall (see WindowLights).
static var _openings: Array = []
## The size of a window's opening through the wall (metres, across and high).
const OPENING := Vector2(0.8, 0.9)


## A house that fits into a footprint of `room` metres (x across the front,
## y deep). Its glowing window panes use `glass`, so the village can light
## them at night.
static func build(room: Vector2, rng: RandomNumberGenerator, glass: Material, style := {}) -> Node3D:
	_panes = []
	_outs = []
	_hinges = []
	_ledges = []
	_noting = true
	# A hall (see VillageHalls) may be wider and deeper than a home, its door in the middle.
	var w := clampf(room.x - 1.2 - JETTY * 2.0, 4.5, float(style.get("max_w", 7.0))) - rng.randf_range(0.0, 0.6)
	var d := clampf(room.y - 1.4 - JETTY * 2.0, 4.0, float(style.get("max_d", 6.0))) - rng.randf_range(0.0, 0.5)
	var ridge := rng.randf_range(2.6, 3.4)
	var door_x: float = [-1.0, 0.0, 1.0][rng.randi() % 3] * (w * 0.5 - 1.2)
	if style.has("door_x"):
		door_x = float(style.door_x)
	var uw := w + JETTY * 2.0
	var ud := d + JETTY * 2.0
	var cx := rng.randf_range(-0.3, 0.3) * uw
	var shape := {"w": w, "d": d, "ridge": ridge, "door_x": door_x, "cx": cx, "tower": bool(style.get("tower", false)),
			"flat": bool(style.get("flat", false)), "mage": bool(style.get("mage", false))}
	if style.has("ladder_side"):
		shape["ladder_side"] = float(style.ladder_side)
	# A hall may set its side windows toward the door (see VillageHalls.style): `side_front` metres
	# from the front of the room instead of in the middle, to leave the wall beside them clear.
	shape["side_z"] = d * 0.5 - WALL_THICK - float(style.side_front) if style.has("side_front") else 0.0
	var parts := {}
	_shape(shape, parts, parts, parts, parts)
	var eaves := PLINTH + GROUND + UPPER

	var house := Node3D.new()
	house.name = "House"
	house.set_meta("village_house", true)
	house.set_meta("door", Vector3(door_x, 0, d * 0.5))
	# The mouth of the chimney, where its evening smoke comes out (see ChimneySmoke).
	house.set_meta("chimney", Vector3(cx, eaves + ridge * 1.2 + 0.55, -ud * 0.22))
	house.set_meta("windows", _panes.duplicate())
	house.set_meta("window_outs", _outs.duplicate())
	house.set_meta("shutter_hinges", _hinges.duplicate())
	house.set_meta("snow_ledges", _ledges.duplicate())
	_noting = false
	shape["mats"] = _materials(rng, glass)
	var body := _mesh_of(parts, shape.mats)
	house.add_child(body)
	shape["body"] = body
	# What it is made of, so it can be built again hollow (see hollow and WalkIn).
	house.set_meta("shape", shape)
	_hang_door(house, Vector3(door_x, PLINTH, d * 0.5))
	return house


## The pieces of a house of the size in `shape` (see build), each into the parts of its group:
## `low` the ground floor's back and side walls and its plinth, `front` its front wall with the
## door and the windows in it, `up` the upper floor, the roof and the chimney, `step` the stone
## step before the door. All four the same dictionary builds the solid house as it always was;
## kept apart they make a house one can walk into (see hollow).
static func _shape(shape: Dictionary, low: Dictionary, front: Dictionary, up: Dictionary, step: Dictionary, walls := {}, roof = null, up_front = null) -> void:
	var w: float = shape.w
	var d: float = shape.d
	var ridge: float = shape.ridge
	var door_x: float = shape.door_x
	var cx: float = shape.cx
	var top := PLINTH + GROUND
	var eaves := top + UPPER
	# A flat roof one walks on (the guildhall, see GuildHall): built hollow, its upper floor is a room
	# with stairs up through the deck, so GuildHall builds that storey itself.
	var flat := bool(shape.get("flat", false))
	var hollow_flat := flat and low != front
	# Stone plinth, stone ground floor and the jutting upper floor. A hollow flat-roofed hall has
	# stairs down through its floor: no lid on the plinth, the boards are the floor.
	_box(low, "stone", Vector3(0, PLINTH * 0.5, 0), Vector3(w + 0.1, PLINTH, d + 0.1), Basis(), 2.0, [4] if hollow_flat else [])
	if low == front:
		_box(low, "plaster", Vector3(0, PLINTH + GROUND * 0.5, 0), Vector3(w, GROUND, d))
	else:
		# Hollow: no lid (the floor above is its ceiling), and the front wall has a doorway.
		if walls.is_empty():
			_box(low, "plaster", Vector3(0, PLINTH + GROUND * 0.5, 0), Vector3(w, GROUND, d), Basis(), 2.0, [0, 4])
		else:
			# Each wall in its own mesh (see hollow with `sides`): the back (face 1), right (2), left (3).
			for fi: int in walls:
				_box(walls[fi], "plaster", Vector3(0, PLINTH + GROUND * 0.5, 0), Vector3(w, GROUND, d), Basis(), 2.0, [0, 1, 2, 3, 4, 5].filter(func(k): return k != fi))
		_face(front, "plaster", Vector3(-w * 0.5, PLINTH, d * 0.5), Vector3.RIGHT, Vector3.UP, Vector2(w, GROUND),
				Rect2(door_x + w * 0.5 - HouseDoor.WIDTH * 0.5, 0.0, HouseDoor.WIDTH, HouseDoor.HEIGHT))
	var uw := w + JETTY * 2.0
	var ud := d + JETTY * 2.0
	var lid: Dictionary = up if roof == null else roof
	var up_face: Dictionary = up if up_front == null else up_front
	# A tower (the mill, see MillTower) has no upper floor and no roof of its own: only a band of
	# oak beams round the top of its stone storey, for the kit's tower to stand on.
	var tower := bool(shape.get("tower", false))
	if tower:
		_beams(up, w + 0.1, d + 0.1, top)
	else:
		if hollow_flat:
			pass # Under a flat roof the deck lies on the upper floor (no lid of plaster under it to hold snow).
		elif roof == null:
			_box(up, "plaster", Vector3(0, top + UPPER * 0.5, 0), Vector3(uw, UPPER, ud), Basis(), 2.0, [4] if flat else [])
		else:
			# A floor above one walks into (see hollow with a hatch): its back and side walls and its
			# underside, its front wall and its lid apart, so the roof and the front can hide.
			_box(up, "plaster", Vector3(0, top + UPPER * 0.5, 0), Vector3(uw, UPPER, ud), Basis(), 2.0, [0, 4])
			_box(up_front, "plaster", Vector3(0, top + UPPER * 0.5, 0), Vector3(uw, UPPER, ud), Basis(), 2.0, [1, 2, 3, 4, 5])
			_box(roof, "plaster", Vector3(0, top + UPPER * 0.5, 0), Vector3(uw, UPPER, ud), Basis(), 2.0, [0, 1, 2, 3, 5])
		# The upper floor rests on a band of oak beams.
		_beams(up, uw, ud, top)
		# The floor beams of the jetty poking out under the upper floor.
		for i in range(1, int(uw / 1.1)):
			var x := -uw * 0.5 + i * uw / int(uw / 1.1)
			_box(up, "timber", Vector3(x, top - 0.12, d * 0.5 + JETTY * 0.5), Vector3(0.18, 0.18, JETTY + 0.1))
			_box(up, "timber", Vector3(x, top - 0.12, -d * 0.5 - JETTY * 0.5), Vector3(0.18, 0.18, JETTY + 0.1))
	# Door, windows with shutters.
	_door(front, Vector3(door_x, PLINTH, d * 0.5), step)
	for x: float in _window_spots(w, door_x):
		_window(front, Vector3(x, PLINTH + 1.6, d * 0.5), 0.0)
	if not tower and not hollow_flat:
		for x: float in _window_spots(uw, INF):
			_window(up_face, Vector3(x, top + 1.3, ud * 0.5), 0.0)
	for side: float in [-1.0, 1.0]:
		if not tower and not hollow_flat:
			_window(up, Vector3(side * uw * 0.5, top + 1.3, 0), side * PI * 0.5)
		_window(walls.get(2 if side > 0.0 else 3, low), Vector3(side * w * 0.5, PLINTH + 1.6, float(shape.get("side_z", 0.0))), side * PI * 0.5)
	if tower:
		return
	if flat and bool(shape.get("mage", false)):
		# A mage tower (see MageTower): the deck is the floor of its top room, which solid has walls and
		# a pyramid roof in the same mesh; hollow, hollow() builds them apart.
		GuildHall.roof_shell(up, shape, false)
		if low == front:
			MageTower.solid_top(up, shape)
		return
	if flat:
		# The deck and its parapet instead of a pitched roof; hollow, the upper storey as a room.
		GuildHall.roof_shell(up, shape)
		return
	# The roof, its gables and the chimney.
	_gables(lid, uw, ud, eaves, ridge)
	_roof(lid, uw + ROOF_OVERHANG * 2.0, ud + ROOF_OVERHANG * 2.0, eaves, ridge, ud)
	_box(lid, "stone", Vector3(cx, eaves + ridge * 0.6, -ud * 0.22), Vector3(0.8, ridge * 1.2 + 0.8, 0.8), Basis(), 2.0, [4])
	_flue_rim(lid, Vector3(cx, eaves + ridge * 1.2 + 0.4, -ud * 0.22), 0.95)


## The top of a chimney: a timber rim round an open flue, dark inside, on a shaft whose top is
## at `top` (its middle). The snow lies on the rim only (the flue is left out, see
## AgedStone.triangles), and the smoke comes out of the opening (see the "chimney" meta of build).
const RIM_WIDTH := 0.2
const RIM_HIGH := 0.12


static func _flue_rim(parts: Dictionary, top: Vector3, outer: float) -> void:
	var mid := top + Vector3(0, 0.05, 0)
	var off := (outer - RIM_WIDTH) * 0.5
	for sign_ in [-1.0, 1.0]:
		_box(parts, "timber", mid + Vector3(off * sign_, 0, 0), Vector3(RIM_WIDTH, RIM_HIGH, outer))
		_box(parts, "timber", mid + Vector3(0, 0, off * sign_), Vector3(outer - RIM_WIDTH * 2.0, RIM_HIGH, RIM_WIDTH))
	# The dark of the flue, a little below the rim's top and over the shaft's open end.
	_box(parts, "flue", top + Vector3(0, 0.02, 0), Vector3(outer - RIM_WIDTH * 2.0, 0.04, outer - RIM_WIDTH * 2.0))


## How far the walls of a hollow house reach in from their outer faces (metres).
const WALL_THICK := 0.2
## How high the boards of a hollow house's floor lie over its plinth (clear of the plinth's top).
const FLOOR_LIFT := 0.02


## Builds a house made by `build` again as one that can be walked into, looking from outside
## exactly as before: the same pieces, now in four meshes (see _shape) so the upper floor with the
## roof and the front wall can be hidden while the hero is inside, and a fifth mesh for the room
## itself: boards on the floor, the inner faces of the walls, their tops, the doorway's sides and
## the windows seen from inside. The house must already be dressed (ivy, snow, see
## Outdoor._dress_building), which reads the solid mesh. Returns the new meshes by group
## ("low", "front", "up", "inside"); the plain dark panel behind the door is gone, the doorway
## now opens into the room.
static func hollow(house: Node3D, sides := false, hatch := Rect2()) -> Dictionary:
	var shape: Dictionary = house.get_meta("shape")
	var mats: Dictionary = shape.mats.duplicate()
	mats["floor"] = _textured("floor", WOOD_TEX, Color(0.78, 0.64, 0.5))
	_panes = []
	_outs = []
	_hinges = []
	var groups := {"low": {}, "front": {}, "up": {}, "inside": {}}
	var walls := {}
	if sides:
		# The back and side walls apart too, so whichever faces the camera can hide (see WalkIn).
		for key: String in ["back", "right", "left"]:
			groups[key] = {}
		walls = {1: groups.back, 2: groups.right, 3: groups.left}
	if bool(shape.get("flat", false)):
		shape["floor_cut"] = GuildHall.layout(shape).well
	var upper := hatch.size != Vector2.ZERO
	_openings = walk_in_windows(shape, upper or bool(shape.get("flat", false)))
	mats["curtain"] = curtain_cloth()
	if upper:
		# A floor above one walks into: the roof, the upper front wall and the upper room apart.
		for key: String in ["roof", "up_front", "up_inside"]:
			groups[key] = {}
		_shape(shape, groups.low, groups.front, groups.up, groups.low, walls, groups.roof, groups.up_front)
	else:
		_shape(shape, groups.low, groups.front, groups.up, groups.low, walls)
	_room(shape, groups.inside, groups.front, walls)
	if upper:
		_upper_room(shape, groups.up_inside, groups.up_front, hatch)
	if bool(shape.get("flat", false)):
		# The upper storey as a room of its own, each wall apart (see GuildHall.upper_storey).
		for key: String in GuildHall.UPPER_GROUPS:
			groups[key] = {}
		GuildHall.upper_storey(shape, groups)
		if bool(shape.get("mage", false)):
			# The top room under its pyramid roof, each wall apart (see MageTower.top_storey).
			for key: String in MageTower.TOP_GROUPS:
				groups[key] = {}
			MageTower.top_storey(shape, groups)
	_openings = []
	var body: MeshInstance3D = shape.body
	var out := {}
	for key: String in groups:
		var mi := _mesh_of(groups[key], mats)
		mi.name = "Walk" + key.capitalize()
		# The walls and roofs stop the light of the lamps and candles inside (see LightShadows):
		# without it a candle by the back wall lit the ivy and the snow outside through the wall.
		# The floors and the rooms' furnishing (inside) do not, or they would shade themselves.
		if not key in ["inside", "up_inside", "storey_room"]:
			mi.set_meta(LightShadows.WALL, true)
			# These meshes are the walls' outside (the inner faces are in "inside" and the like): no
			# indoor candle lights them, but they still stop its light (see LightShadows.OUTSIDE_WALL).
			mi.set_meta(LightShadows.OUTSIDE_WALL, true)
		house.add_child(mi)
		out[key] = mi
	house.remove_child(body)
	body.queue_free()
	shape.erase("body")
	var door: HouseDoor = house.get_meta("door_leaf")
	var recess := door.get_node_or_null("Recess")
	if recess:
		door.remove_child(recess)
		recess.queue_free()
	return out


## The windows of the rooms of `shape` one walks into (see _openings): the ground floor's, and
## the upper floor's when one walks into that too (`upstairs`). Each {at, out}, the house's frame.
static func walk_in_windows(shape: Dictionary, upstairs: bool) -> Array:
	var w: float = shape.w
	var d: float = shape.d
	var out := []
	for x: float in _window_spots(w, float(shape.door_x)):
		out.append({"at": Vector3(x, PLINTH + 1.6, d * 0.5), "out": Vector3.BACK})
	for side: float in [-1.0, 1.0]:
		out.append({"at": Vector3(side * w * 0.5, PLINTH + 1.6, float(shape.get("side_z", 0.0))), "out": Vector3(side, 0, 0)})
	if upstairs and not bool(shape.get("tower", false)):
		var uw := w + JETTY * 2.0
		var ud := d + JETTY * 2.0
		var top := PLINTH + GROUND
		for x: float in _window_spots(uw, INF):
			out.append({"at": Vector3(x, top + 1.3, ud * 0.5), "out": Vector3.BACK})
		for side: float in [-1.0, 1.0]:
			out.append({"at": Vector3(side * uw * 0.5, top + 1.3, 0), "out": Vector3(side, 0, 0)})
		if bool(shape.get("mage", false)):
			out.append_array(MageTower.windows(shape))
	return out


## How far behind the glass of such a window its curtains hang (metres): clear of the pane, so the
## two never fight over the same pixels, and still well inside the thickness of the wall.
const CURTAIN_GAP := 0.07


## The curtains of the windows one looks through: the cloth of the pane's own curtains (see
## WindowLights.CURTAIN_SHADER), cut out where they are open. The village drives its hour and glow
## (see Outdoor._house_glass); elsewhere it stays at noon.
static func curtain_cloth() -> ShaderMaterial:
	if not _mats.has("curtain_cloth"):
		var cloth := WindowLights.curtain_material(Color(1.0, 0.7, 0.36))
		# Named like glass, so the ivy keeps clear of it (see AgedStone.triangles).
		cloth.resource_name = "window_curtain"
		_mats["curtain_cloth"] = cloth
	return _mats["curtain_cloth"]


## The pane seen from inside the room: the same glass and curtains, but it never shines by itself
## (it is the room's own light that lights the room, and the pane would otherwise glow orange in a
## dark room, see WindowLights.glass_material). The village drives its hour (see Outdoor._house_glass).
static func inner_glass() -> ShaderMaterial:
	if not _mats.has("inner_glass"):
		var glass := WindowLights.glass_material(Color(1.0, 0.7, 0.36), true)
		glass.resource_name = "window_inner"
		_mats["inner_glass"] = glass
	return _mats["inner_glass"]


## The shutters' wood: the timber's look, swinging shut at night (see WindowLights.SHUTTER_SHADER).
## The village drives its hour (see Outdoor._house_glass).
static func shutters() -> ShaderMaterial:
	if not _mats.has("shutters"):
		var wood := WindowLights.shutter_material(load(WOOD_TEX), TIMBER)
		wood.resource_name = "shutters"
		_mats["shutters"] = wood
	return _mats["shutters"]


## One quad of curtains, the size of the opening, hanging at `at` and facing along `b`'s z (into the room), its UV
## in metres across the pane and its second UV the pane's key (see WindowLights.key).
static func _curtains(parts: Dictionary, at: Vector3, b: Basis) -> void:
	var st := _tool(parts, "curtain")
	var side := b * Vector3(OPENING.x * 0.5, 0, 0)
	var up := Vector3(0, OPENING.y * 0.5, 0)
	var n := b * Vector3(0, 0, 1)
	var corners := [at - side - up, at + side - up, at + side + up, at - side + up]
	var uvs := [Vector2(0, 0), Vector2(OPENING.x, 0), Vector2(OPENING.x, OPENING.y), Vector2(0, OPENING.y)]
	for k in [0, 2, 1, 0, 3, 2]:
		st.set_uv2(_pane_key)
		st.set_normal(n)
		st.set_uv(uvs[k])
		st.add_vertex(corners[k])


## The room inside a hollow house (see hollow): into `parts` the floor boards and the inner faces
## of the back and side walls, into `front` what belongs to the front wall (its inner face with the
## doorway, the doorway's sides and lintel, the windows' inner panes), so it hides with it.
static func _room(shape: Dictionary, parts: Dictionary, front: Dictionary, walls := {}) -> void:
	var w: float = shape.w
	var d: float = shape.d
	var door_x: float = shape.door_x
	var t := WALL_THICK
	var top := PLINTH + GROUND
	var half := HouseDoor.WIDTH * 0.5
	# The boards: over the whole ground floor, so the doorway gets a threshold (and open over
	# stairs down, see GuildHall: `floor_cut`, x and z in the house's frame).
	var cut: Rect2 = shape.get("floor_cut", Rect2())
	var hole := Rect2()
	if cut.size != Vector2.ZERO:
		hole = Rect2(cut.position.x + w * 0.5, d * 0.5 - cut.end.y, cut.size.x, cut.size.y)
	_face(parts, "floor", Vector3(-w * 0.5, PLINTH + FLOOR_LIFT, d * 0.5), Vector3.RIGHT, Vector3.FORWARD, Vector2(w, d), hole)
	# The inner faces of the walls, each turned to the room.
	_face(parts, "plaster", Vector3(-w * 0.5 + t, PLINTH, -d * 0.5 + t), Vector3.RIGHT, Vector3.UP, Vector2(w - t * 2.0, GROUND))
	_face(parts, "plaster", Vector3(-w * 0.5 + t, PLINTH, d * 0.5 - t), Vector3.FORWARD, Vector3.UP, Vector2(d - t * 2.0, GROUND))
	_face(parts, "plaster", Vector3(w * 0.5 - t, PLINTH, -d * 0.5 + t), Vector3.BACK, Vector3.UP, Vector2(d - t * 2.0, GROUND))
	var right := w * 0.5 - t
	_face(front, "plaster", Vector3(right, PLINTH, d * 0.5 - t), Vector3.LEFT, Vector3.UP, Vector2(w - t * 2.0, GROUND),
			Rect2(right - door_x - half, 0.0, HouseDoor.WIDTH, HouseDoor.HEIGHT))
	# The tops of the walls, seen from above once the floor above is hidden. With the walls apart
	# (a hall, see hollow) each top goes with its wall, so it hides with it.
	_face(walls.get(1, parts), "plaster", Vector3(-w * 0.5, top, -d * 0.5 + t), Vector3.RIGHT, Vector3.FORWARD, Vector2(w, t))
	_face(walls.get(3, parts), "plaster", Vector3(-w * 0.5, top, d * 0.5 - t), Vector3.RIGHT, Vector3.FORWARD, Vector2(t, d - t * 2.0))
	_face(walls.get(2, parts), "plaster", Vector3(w * 0.5 - t, top, d * 0.5 - t), Vector3.RIGHT, Vector3.FORWARD, Vector2(t, d - t * 2.0))
	_face(front, "plaster", Vector3(-w * 0.5, top, d * 0.5), Vector3.RIGHT, Vector3.FORWARD, Vector2(w, t))
	# The doorway's sides and the underside of its lintel, through the thickness of the wall.
	_face(front, "plaster", Vector3(door_x - half, PLINTH, d * 0.5), Vector3.FORWARD, Vector3.UP, Vector2(t, HouseDoor.HEIGHT))
	_face(front, "plaster", Vector3(door_x + half, PLINTH, d * 0.5 - t), Vector3.BACK, Vector3.UP, Vector2(t, HouseDoor.HEIGHT))
	_face(front, "plaster", Vector3(door_x - half, PLINTH + HouseDoor.HEIGHT, d * 0.5 - t), Vector3.RIGHT, Vector3.BACK, Vector2(HouseDoor.WIDTH, t))
	# The windows from inside: the pane (lit with the one outside, see WindowLights) and a sill.
	for x: float in _window_spots(w, door_x):
		_inner_window(front, Vector3(x, PLINTH + 1.6, d * 0.5), Vector3(x, PLINTH + 1.6, d * 0.5 - t), 0.0)
	for side: float in [-1.0, 1.0]:
		_inner_window(parts, Vector3(side * w * 0.5, PLINTH + 1.6, float(shape.get("side_z", 0.0))), Vector3(side * (w * 0.5 - t), PLINTH + 1.6, float(shape.get("side_z", 0.0))), side * PI * 0.5)


## The room on the floor above a hollow house (see hollow with a hatch): into `parts` the boards
## with the hatch (`hatch`, the house's frame, x and z) left open, the inner faces of the back and
## side walls with their windows and the tops of the walls (seen once the roof is hidden); into
## `front` the inner face of the front wall and its windows, so it hides with it.
static func _upper_room(shape: Dictionary, parts: Dictionary, front: Dictionary, hatch: Rect2) -> void:
	var t := WALL_THICK
	var uw: float = float(shape.w) + JETTY * 2.0
	var ud: float = float(shape.d) + JETTY * 2.0
	var top := PLINTH + GROUND
	var eaves := top + UPPER
	var corner := Vector3(-uw * 0.5 + t, top + FLOOR_LIFT, ud * 0.5 - t)
	_face(parts, "floor", corner, Vector3.RIGHT, Vector3.FORWARD, Vector2(uw - t * 2.0, ud - t * 2.0),
			Rect2(hatch.position.x - corner.x, corner.z - hatch.end.y, hatch.size.x, hatch.size.y))
	# The rim of the hatch, down through the floor's thickness.
	_box(parts, "timber", Vector3(hatch.get_center().x, top - 0.06, hatch.position.y - 0.03), Vector3(hatch.size.x + 0.12, 0.16, 0.06))
	_box(parts, "timber", Vector3(hatch.get_center().x, top - 0.06, hatch.end.y + 0.03), Vector3(hatch.size.x + 0.12, 0.16, 0.06))
	_box(parts, "timber", Vector3(hatch.position.x - 0.03, top - 0.06, hatch.get_center().y), Vector3(0.06, 0.16, hatch.size.y))
	_box(parts, "timber", Vector3(hatch.end.x + 0.03, top - 0.06, hatch.get_center().y), Vector3(0.06, 0.16, hatch.size.y))
	_face(parts, "plaster", Vector3(-uw * 0.5 + t, top, -ud * 0.5 + t), Vector3.RIGHT, Vector3.UP, Vector2(uw - t * 2.0, UPPER))
	_face(parts, "plaster", Vector3(-uw * 0.5 + t, top, ud * 0.5 - t), Vector3.FORWARD, Vector3.UP, Vector2(ud - t * 2.0, UPPER))
	_face(parts, "plaster", Vector3(uw * 0.5 - t, top, -ud * 0.5 + t), Vector3.BACK, Vector3.UP, Vector2(ud - t * 2.0, UPPER))
	_face(front, "plaster", Vector3(uw * 0.5 - t, top, ud * 0.5 - t), Vector3.LEFT, Vector3.UP, Vector2(uw - t * 2.0, UPPER))
	_face(parts, "plaster", Vector3(-uw * 0.5, eaves, -ud * 0.5 + t), Vector3.RIGHT, Vector3.FORWARD, Vector2(uw, t))
	_face(parts, "plaster", Vector3(-uw * 0.5, eaves, ud * 0.5 - t), Vector3.RIGHT, Vector3.FORWARD, Vector2(t, ud - t * 2.0))
	_face(parts, "plaster", Vector3(uw * 0.5 - t, eaves, ud * 0.5 - t), Vector3.RIGHT, Vector3.FORWARD, Vector2(t, ud - t * 2.0))
	_face(front, "plaster", Vector3(-uw * 0.5, eaves, ud * 0.5), Vector3.RIGHT, Vector3.FORWARD, Vector2(uw, t))
	for x: float in _window_spots(uw, INF):
		_inner_window(front, Vector3(x, top + 1.3, ud * 0.5), Vector3(x, top + 1.3, ud * 0.5 - t), 0.0)
	for side: float in [-1.0, 1.0]:
		_inner_window(parts, Vector3(side * uw * 0.5, top + 1.3, 0), Vector3(side * (uw * 0.5 - t), top + 1.3, 0), side * PI * 0.5)


## A window seen from inside: the pane of the window outside at `outer`, on the inner face at
## `inner`, facing into the room, with a wooden frame and a sill under it.
static func _inner_window(parts: Dictionary, outer: Vector3, inner: Vector3, turn: float) -> void:
	_pane_key = WindowLights.key(outer)
	var b := Basis(Vector3.UP, turn)
	var into := b * Vector3(0, 0, -1)
	if _is_opening(outer):
		# The opening through the wall (see _openings): its four sides, from the outer face to the
		# inner, each turned into the opening; the glass is in the middle (see _window).
		_reveals(parts, outer, inner, b)
	else:
		_box(parts, "glass_in", inner + into * 0.02, Vector3(0.8, 0.9, 0.04), b)
	_box(parts, "timber", inner + into * 0.04 - Vector3(0, 0.5, 0), Vector3(1.0, 0.1, 0.14), b)
	_box(parts, "timber", inner + into * 0.03 + Vector3(0, 0.5, 0), Vector3(1.0, 0.08, 0.08), b)
	for s: float in [-1.0, 1.0]:
		_box(parts, "timber", inner + into * 0.03 + b * Vector3(s * 0.46, 0, 0), Vector3(0.08, 1.0, 0.08), b)


## Whether the window with its outer middle at `at` opens through the wall (see _openings).
static func _is_opening(at: Vector3) -> bool:
	for o: Dictionary in _openings:
		if (o.at as Vector3).distance_to(at) < 0.05:
			return true
	return false


## The sides of a window's opening through the wall, from `outer` (the middle of its outer face) to
## `inner` (of its inner face), turned by `b` (the window looks out along b's z): the two jambs, the
## sill and the head, each facing into the opening.
static func _reveals(parts: Dictionary, outer: Vector3, inner: Vector3, b: Basis) -> void:
	var out := b * Vector3(0, 0, 1)
	var side := b * Vector3(1, 0, 0)
	var deep := (outer - inner).length()
	var hw := OPENING.x * 0.5
	var hh := OPENING.y * 0.5
	# u x v faces into the opening (see _face).
	_face(parts, "plaster", outer - side * hw - Vector3.UP * hh, -out, Vector3.UP, Vector2(deep, OPENING.y))
	_face(parts, "plaster", inner + side * hw - Vector3.UP * hh, out, Vector3.UP, Vector2(deep, OPENING.y))
	_face(parts, "plaster", outer - side * hw - Vector3.UP * hh, side, -out, Vector2(OPENING.x, deep))
	_face(parts, "plaster", inner - side * hw + Vector3.UP * hh, side, out, Vector2(OPENING.x, deep))


## A narrow town house for a row of them along a lane (see
## Outdoor._build_terrace): `room.x` across the front, so neighbours almost
## touch, and two storeys, the upper one jutting out a little over the
## street, with an attic under the roof. The gable faces the lane, the roof slopes down
## to the neighbours on either side, and a small sign over the door carries
## the house number. Built facing south (+z) like `build`.
static func build_narrow(room: Vector2, number: int, rng: RandomNumberGenerator, glass: Material) -> Node3D:
	_panes = []
	_outs = []
	_hinges = []
	_ledges = []
	_noting = true
	var w := room.x - 0.06
	var d := clampf(room.y - 1.6 - JETTY * 2.0, 4.0, 6.0) - rng.randf_range(0.0, 0.3)
	var ridge := w * rng.randf_range(0.62, 0.8)
	var door_x: float = [-1.0, 1.0][rng.randi() % 2] * (w * 0.5 - 1.0)
	var parts := {}
	_box(parts, "stone", Vector3(0, PLINTH * 0.5, 0), Vector3(w, PLINTH, d + 0.1))
	_box(parts, "plaster", Vector3(0, PLINTH + GROUND * 0.5, 0), Vector3(w - 0.04, GROUND, d))
	_door(parts, Vector3(door_x, PLINTH, d * 0.5))
	_window(parts, Vector3(-door_x, PLINTH + 1.6, d * 0.5), 0.0)
	_window(parts, Vector3(w * 0.25, PLINTH + 1.6, -d * 0.5), PI)
	# The upper storey, jutting out over the lane a little.
	var y0 := PLINTH + GROUND
	for k in range(1, NARROW_STOREYS):
		var sd := d + JETTY * k
		var z0 := JETTY * k * 0.5
		_box(parts, "plaster", Vector3(0, y0 + UPPER * 0.5, z0), Vector3(w - 0.04, UPPER, sd))
		_beams(parts, w - 0.04, sd, y0, z0)
		for x: float in [-w * 0.22, w * 0.22]:
			_box(parts, "timber", Vector3(x, y0 - 0.12, d * 0.5 + JETTY * (k - 0.5) + 0.02), Vector3(0.18, 0.18, JETTY + 0.1))
		for x: float in [-w * 0.25, w * 0.25]:
			_window(parts, Vector3(x, y0 + 1.3, z0 + sd * 0.5), 0.0)
		_window(parts, Vector3(-w * 0.25, y0 + 1.3, z0 - sd * 0.5), PI)
		y0 += UPPER
	# The roof: its ridge runs from the lane to the back, so it is built
	# turned a quarter round, in a surface of its own.
	var top_d := d + JETTY * (NARROW_STOREYS - 1)
	var top_z := JETTY * (NARROW_STOREYS - 1) * 0.5
	var roof_parts := {}
	_gables(roof_parts, top_d, w - 0.04, y0, ridge)
	_roof(roof_parts, top_d + ROOF_OVERHANG * 2.0, w + 0.16, y0, ridge, w)
	var cx := (-1.0 if door_x > 0.0 else 1.0) * w * 0.22
	_box(parts, "stone", Vector3(cx, y0 + ridge * 0.55, top_z - top_d * 0.25), Vector3(0.6, ridge * 1.1 + 0.8, 0.6), Basis(), 2.0, [4])
	_flue_rim(parts, Vector3(cx, y0 + ridge * 1.1 + 0.4, top_z - top_d * 0.25), 0.75)
	# The house sign: a board on a bracket over the door.
	_box(parts, "timber", Vector3(door_x, PLINTH + 2.75, d * 0.5 + 0.3), Vector3(0.08, 0.08, 0.6))
	_box(parts, "door", Vector3(door_x, PLINTH + 2.55, d * 0.5 + 0.55), Vector3(0.62, 0.42, 0.06))

	var house := Node3D.new()
	house.name = "TownHouse%d" % number
	house.set_meta("town_house", number)
	house.set_meta("door_x", door_x)
	house.set_meta("windows", _panes.duplicate())
	house.set_meta("window_outs", _outs.duplicate())
	house.set_meta("shutter_hinges", _hinges.duplicate())
	house.set_meta("snow_ledges", _ledges.duplicate())
	_noting = false
	var mats := _materials(rng, glass)
	house.add_child(_mesh_of(parts, mats))
	var roof := _mesh_of(roof_parts, mats)
	roof.name = "Roof"
	roof.rotation.y = PI * 0.5
	roof.position.z = top_z
	house.add_child(roof)
	var plate := Label3D.new()
	plate.name = "Number"
	plate.text = str(number)
	plate.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	plate.font_size = 64
	plate.pixel_size = 0.006
	plate.outline_size = 8
	plate.modulate = Color(1.0, 0.86, 0.5)
	# Clear of the board (its face is at +0.58), so the two never fight.
	plate.position = Vector3(door_x, PLINTH + 2.55, d * 0.5 + 0.63)
	house.add_child(plate)
	_hang_door(house, Vector3(door_x, PLINTH, d * 0.5))
	return house


## How many storeys a narrow town house has: ground floor and one above
## (the attic under the roof makes the home's third floor, see Homes).
const NARROW_STOREYS := 2


static func _materials(rng: RandomNumberGenerator, glass: Material) -> Dictionary:
	return {
		"plaster": AgedStone.house_material(AgedStone.HOUSE_TINTS[rng.randi() % AgedStone.HOUSE_TINTS.size()]),
		"timber": _textured("timber", WOOD_TEX, TIMBER),
		"roof": _roof_material(rng.randi() % ROOFS.size()),
		"stone": _textured("stone", STONE_TEX, Color(0.9, 0.88, 0.85)),
		"door": _textured("door", DOOR_TEX, Color.WHITE),
		"glass": glass,
		"glass_in": inner_glass(),
		"shutter": shutters(),
		"floor": _textured("floor", WOOD_TEX, Color(0.78, 0.64, 0.5)),
		"flue": _flue_material(),
	}


## One mesh with a surface per material from the parts' surface tools.
static func _mesh_of(parts: Dictionary, mats: Dictionary) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for key: String in parts:
		var st: SurfaceTool = parts[key]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


static func _window_spots(width: float, door_x: float) -> Array:
	var spots := []
	for x: float in [-width * 0.3, width * 0.3]:
		if absf(x - door_x) > 1.4:
			spots.append(x)
	return spots


## The band of beams a jutting floor rests on: a sill beam all round its
## foot, and one under the eaves.
static func _beams(parts: Dictionary, w: float, d: float, y0: float, z0 := 0.0) -> void:
	var hb := BEAM * 0.5
	for side: float in [-1.0, 1.0]:
		var z := side * (d * 0.5 + 0.02) + z0
		var x := side * (w * 0.5 + 0.02)
		for y: float in [y0 + hb, y0 + UPPER - hb]:
			_box(parts, "timber", Vector3(0, y, z), Vector3(w + 0.1, BEAM, BEAM))
			_box(parts, "timber", Vector3(x, y, z0), Vector3(BEAM, BEAM, d + 0.1))
			_note_top(Vector3(0, y, z), Vector3(w + 0.1, BEAM, BEAM))
			_note_top(Vector3(x, y, z0), Vector3(BEAM, BEAM, d + 0.1))


## How far the door posts reach out from the middle of the door (metres).
const DOOR_POST := 0.66


## A plank door under a beam, with a step of stone before it. The plank itself
## is not part of the house's mesh: it is a HouseDoor that swings open (see
## _hang_door).
static func _door(parts: Dictionary, at: Vector3, step = null) -> void:
	_box(parts, "timber", at + Vector3(0, 2.2, 0.08), Vector3(1.5, BEAM, BEAM))
	_note_top(at + Vector3(0, 2.2, 0.08), Vector3(1.5, BEAM, BEAM))
	for s: float in [-1.0, 1.0]:
		_box(parts, "timber", at + Vector3(s * DOOR_POST, 1.1, 0.08), Vector3(BEAM, 2.2, BEAM))
	var step_parts: Dictionary = parts if step == null else step
	_box(step_parts, "stone", Vector3(at.x, 0.1, at.z + 0.4), Vector3(1.5, 0.2, 0.7))
	_note_top(Vector3(at.x, 0.1, at.z + 0.4), Vector3(1.5, 0.2, 0.7))


## Hangs the plank door of the doorway at `at` on its hinge (the left side) and
## keeps it on the house as meta "door_leaf".
static func _hang_door(house: Node3D, at: Vector3) -> void:
	var w := HouseDoor.WIDTH
	var h := HouseDoor.HEIGHT
	var leaf := {}
	_box(leaf, "door", Vector3(w * 0.5, h * 0.5, 0), Vector3(w, h, 0.1))
	# The dark doorway behind the leaf, on the face of the wall.
	var recess := {}
	_box(recess, "recess", Vector3(w * 0.5, h * 0.5, -0.05), Vector3(w, h, 0.02))
	if not _mats.has("recess"):
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.03, 0.02, 0.02)
		dark.roughness = 1.0
		_mats["recess"] = dark
	var door := HouseDoor.new().setup(_mesh_of(recess, _mats), _mesh_of(leaf, {"door": _textured("door", DOOR_TEX, Color.WHITE)}))
	door.position = at + Vector3(-w * 0.5, 0, 0.06)
	house.add_child(door)
	house.set_meta("door_leaf", door)


## Notes the flat top of a box (as `_box` takes it) for the snow's dusting, while a house is built
## (see _ledges). Tilted boxes are left out: roofs carry their own snow.
static func _note_top(center: Vector3, size: Vector3, basis := Basis()) -> void:
	if not _noting or absf((basis * Vector3.UP).y) < 0.99:
		return
	var hx := basis * Vector3(size.x * 0.5 - 0.02, 0, 0)
	var hz := basis * Vector3(0, 0, size.z * 0.5 - 0.02)
	var top := center + basis * Vector3(0, size.y * 0.5, 0)
	_ledges.append(PackedVector3Array([top - hx - hz, top + hx - hz, top + hx + hz, top - hx + hz]))


## A window: a glowing pane in a frame, with open shutters either side.
static func _window(parts: Dictionary, at: Vector3, turn: float) -> void:
	_panes.append(at)
	_pane_key = WindowLights.key(at)
	var b := Basis(Vector3.UP, turn)
	var out := b * Vector3(0, 0, 1)
	_outs.append(out)
	var side := b * Vector3(1, 0, 0)
	if _is_opening(at):
		# A window of a room one walks into: an open hole through the wall. Seen from outside it is the
		# pane painted with its room and curtains (see WindowLights.GLASS_SHADER), one face only, in
		# the middle of the wall's thickness; seen from inside there is no pane and nothing to hide the
		# view, and the curtains hang on the room's side of it, facing in. Neither layer is see-through
		# glass or turned the same way as another, so nothing flickers against anything.
		_box(parts, "glass", at - out * WALL_THICK * 0.5, Vector3(OPENING.x, OPENING.y, 0.02), b, 2.0, [1, 2, 3, 4, 5])
		_curtains(parts, at - out * (WALL_THICK * 0.5 + CURTAIN_GAP), b * Basis(Vector3.UP, PI))
	else:
		_box(parts, "glass", at + out * 0.03, Vector3(0.8, 0.9, 0.06), b)
	_box(parts, "timber", at + out * 0.08 - Vector3(0, 0.5, 0), Vector3(1.0, 0.12, 0.16), b)
	_box(parts, "timber", at + out * 0.08 + Vector3(0, 0.5, 0), Vector3(1.0, 0.1, 0.12), b)
	_note_top(at + out * 0.08 - Vector3(0, 0.5, 0), Vector3(1.0, 0.12, 0.16), b)
	_note_top(at + out * 0.08 + Vector3(0, 0.5, 0), Vector3(1.0, 0.1, 0.12), b)
	# The shutters: three wooden planks each, held by a cross batten. (They used the chapel door's
	# picture, whose pale carving read as stone tiles on such small boards.)
	for s: float in [-1.0, 1.0]:
		var mid := at + side * s * 0.68 + out * 0.08
		# The leaf is hinged at the window's side and swings shut over it at night (see
		# WindowLights.SHUTTER_SHADER): outwards, never through the wall.
		var hinge := at + side * s * 0.47
		_hinge = Vector2(hinge.x, hinge.z)
		_hinges.append(hinge)
		var away := side * s
		_swing = 1.0 if away.z * out.x - away.x * out.z > 0.0 else -1.0
		for k in 3:
			_box(parts, "shutter", mid + side * (k - 1) * 0.15, Vector3(0.14, 0.95, 0.05), b)
		for y: float in [-0.3, 0.3]:
			_box(parts, "shutter", mid + out * 0.035 + Vector3(0, y, 0), Vector3(0.42, 0.07, 0.025), b)


## The two triangular gable ends under the roof, plastered, with a king post.
static func _gables(parts: Dictionary, w: float, d: float, eaves: float, ridge: float) -> void:
	var st := _tool(parts, "plaster")
	for side: float in [-1.0, 1.0]:
		var x := side * w * 0.5
		var a := Vector3(x, eaves, -d * 0.5)
		var b := Vector3(x, eaves, d * 0.5)
		var c := Vector3(x, eaves + ridge, 0)
		var n := Vector3(side, 0, 0)
		var tri := [a, b, c] if side > 0 else [a, c, b]
		for p: Vector3 in tri:
			st.set_normal(n)
			st.set_uv(Vector2(p.z, -p.y) * 0.5)
			st.add_vertex(p)
		_box(parts, "timber", Vector3(x + side * 0.03, eaves + ridge * 0.45, 0), Vector3(BEAM, ridge * 0.9, BEAM))
		_box(parts, "timber", Vector3(x + side * 0.03, eaves + BEAM * 0.5, 0), Vector3(BEAM, BEAM, d))


## Two tiled slopes meeting at the ridge (the ridge runs along x), and a
## ridge beam on top. Each slope is a board of timber under a grid of tile
## patches, each patch showing the tiles of the trim sheet once.
static func _roof(parts: Dictionary, w: float, d: float, eaves: float, ridge: float, wall_d: float) -> void:
	var slope := atan2(ridge, wall_d * 0.5)
	var len := d * 0.5 / cos(slope)
	var st := _tool(parts, "roof")
	# Each patch gets a random number in its vertex colour, so the aged roof
	# (shaders/aged_roof.gdshader) shades its tiles differently.
	var seeds := RandomNumberGenerator.new()
	seeds.seed = hash(Vector3(w, d, eaves))
	var cols := maxi(1, roundi(w / TILES_PATCH.x))
	var rows := maxi(1, roundi(len / TILES_PATCH.y))
	for side: float in [-1.0, 1.0]:
		var b := Basis(Vector3(1, 0, 0), side * slope)
		var mid := Vector3(0, eaves + ridge - sin(slope) * len * 0.5 + 0.1, side * d * 0.25)
		_box(parts, "timber", mid - b * Vector3.UP * 0.03, Vector3(w, 0.14, len), b)
		var n := b * Vector3.UP
		# From the ridge (row 0) down to the eaves.
		var along := b * Vector3(0, 0, side)
		var origin := mid + n * 0.08 - along * len * 0.5 - Vector3(w * 0.5, 0, 0)
		for r in rows:
			for c in cols:
				var p0 := origin + Vector3(c * w / cols, 0, 0) + along * (r * len / rows)
				var dx := Vector3(w / cols, 0, 0)
				var dz := along * (len / rows)
				var quad := [p0, p0 + dx, p0 + dx + dz, p0 + dz]
				var uvs := [TILES_UV.position, TILES_UV.position + Vector2(TILES_UV.size.x, 0),
						TILES_UV.end, TILES_UV.position + Vector2(0, TILES_UV.size.y)]
				var order := [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
				var seed_colour := Color(seeds.randf(), 0, 0)
				for k: int in order:
					st.set_color(seed_colour)
					st.set_normal(n)
					st.set_uv(uvs[k])
					st.add_vertex(quad[k])
	# The ridge board under the cap tiles, and the cap shingles over the ridge and down the two gable
	# edges (RoofCaps), which hide the hard line where the slopes and their boards end.
	var apex := eaves + ridge + 0.1 + 0.08 * cos(slope)
	_box(parts, "timber", Vector3(0, apex - 0.05, 0), Vector3(w + 0.04, 0.16, 0.2))
	RoofCaps.ridge(st, Vector3(-w * 0.5 - 0.05, apex, 0), Vector3(w * 0.5 + 0.05, apex, 0), tan(slope), hash(Vector3(w, d, ridge)))
	for side: float in [-1.0, 1.0]:
		var b := Basis(Vector3(1, 0, 0), side * slope)
		var n := b * Vector3.UP
		var down := b * Vector3(0, 0, side)
		for end: float in [-1.0, 1.0]:
			var top := Vector3(end * w * 0.5, apex, 0)
			RoofCaps.edge(st, top, top + down * len, n, Vector3(end, 0, 0), hash(Vector3(side, end, w)))


## A box into the surface for `key`: centre, size, turn. Its texture is laid
## by metres, so a long beam shows a long grain and not a stretched one.
static func _box(parts: Dictionary, key: String, center: Vector3, size: Vector3, basis := Basis(), tile := 2.0, skip: Array = []) -> void:
	var st := _tool(parts, key)
	var h := size * 0.5
	# Each face: its normal and the two axes across it.
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for fi in faces.size():
		if skip.has(fi):
			continue
		var f: Array = faces[fi]
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var su := absf(u.dot(size))
		var sv := absf(v.dot(size))
		var c := n * h
		var corners := [c - u * su * 0.5 - v * sv * 0.5, c + u * su * 0.5 - v * sv * 0.5,
				c + u * su * 0.5 + v * sv * 0.5, c - u * su * 0.5 + v * sv * 0.5]
		# A wall a window of a room one walks into looks out through: cut open there (see _face).
		if not _openings.is_empty() and n.y == 0.0:
			var at: Vector3 = center + basis * (corners[0] as Vector3)
			if not _openings_in(at, basis * u, basis * v, Vector2(su, sv)).is_empty():
				_face(parts, key, at, basis * u, basis * v, Vector2(su, sv))
				continue
		var uvs := [Vector2(0, 0), Vector2(su, 0), Vector2(su, sv), Vector2(0, sv)]
		# Clockwise seen from outside, which Godot draws as the front. Wound
		# the other way the camera saw the far insides of every box, dark and
		# flickering through each other (tests/house_faces.gd).
		for k in [0, 2, 1, 0, 3, 2]:
			if key == "glass" or key == "glass_in":
				st.set_uv2(_pane_key)
			elif key == "shutter":
				st.set_uv2(_hinge)
				st.set_color(Color(_swing * 0.5 + 0.5, 0, 0))
			st.set_normal(basis * n)
			st.set_uv(_uv(key, uvs[k], center, tile))
			st.add_vertex(center + basis * corners[k])


## The windows (see _openings) that pierce a wall face with its corner at `corner`, running `size`
## along `u` and `v` (unit axes): those looking out across the face, through the wall's thickness
## from it, inside its bounds. As rectangles on the face, from its corner.
static func _openings_in(corner: Vector3, u: Vector3, v: Vector3, size: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _openings.is_empty():
		return out
	var n := u.cross(v).normalized()
	if absf(n.y) > 0.1:
		return out
	for o: Dictionary in _openings:
		var at: Vector3 = o.at
		if absf(n.dot(o.out)) < 0.99:
			continue
		var rel := at - corner
		if absf(rel.dot(n)) > WALL_THICK + 0.05:
			continue
		var p := Vector2(rel.dot(u.normalized()), rel.dot(v.normalized()))
		if p.x <= 0.0 or p.y <= 0.0 or p.x >= size.x or p.y >= size.y:
			continue
		# Only a wall is cut, not the window's own frame or sill round the opening.
		if size.x < OPENING.x + 0.3 or size.y < OPENING.y + 0.3:
			continue
		out.append(Rect2(p - OPENING * 0.5, OPENING))
	return out


## The rectangles of a face of `size` around `holes` (from its corner, not overlapping one another):
## columns between the holes' sides, each cut where a hole crosses it.
static func _around(size: Vector2, holes: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if holes.is_empty():
		out.append(Rect2(Vector2.ZERO, size))
		return out
	var xs: Array[float] = [0.0, size.x]
	for h in holes:
		xs.append(clampf(h.position.x, 0.0, size.x))
		xs.append(clampf(h.end.x, 0.0, size.x))
	xs.sort()
	for i in xs.size() - 1:
		var x0 := xs[i]
		var x1 := xs[i + 1]
		if x1 - x0 <= 0.001:
			continue
		var cuts: Array[Vector2] = []
		for h in holes:
			if h.position.x < x1 - 0.0005 and h.end.x > x0 + 0.0005:
				cuts.append(Vector2(maxf(h.position.y, 0.0), minf(h.end.y, size.y)))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var y := 0.0
		for c in cuts:
			if c.x > y:
				out.append(Rect2(x0, y, x1 - x0, c.x - y))
			y = maxf(y, c.y)
		if y < size.y:
			out.append(Rect2(x0, y, x1 - x0, size.y - y))
	return out


## A flat rectangle into the surface for `key`: from its corner `corner` it runs `size.x` metres
## along `u` and `size.y` along `v`, and faces u x v (the way a face of _box with the same axes
## faces). Laid out like a face of _box, so its texture lines up with a box face in the same spot.
## `hole` (metres from the corner, along u and v) is left open: a doorway.
static func _face(parts: Dictionary, key: String, corner: Vector3, u: Vector3, v: Vector3, size: Vector2, hole := Rect2()) -> void:
	var holes: Array[Rect2] = []
	if hole.size != Vector2.ZERO:
		holes.append(hole)
	holes.append_array(_openings_in(corner, u, v, size))
	var rects := _around(size, holes)
	var st := _tool(parts, key)
	var n := u.cross(v)
	for r: Rect2 in rects:
		if r.size.x <= 0.001 or r.size.y <= 0.001:
			continue
		var uvs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for k in [0, 2, 1, 0, 3, 2]:
			var m: Vector2 = uvs[k]
			st.set_normal(n)
			st.set_uv(_uv(key, m, corner, 2.0))
			st.add_vertex(corner + u * m.x + v * m.y)


## Texture coordinates for a spot on a face, `m` metres from its corner.
static func _uv(key: String, m: Vector2, center: Vector3, tile: float) -> Vector2:
	match key:
		"stone":
			# Within the band of stone blocks on the trim sheet.
			return Vector2(m.x / 8.0, STONE_V.y - fposmod(m.y, STONE_BAND) / STONE_BAND * (STONE_V.y - STONE_V.x))
		"door":
			return Vector2(m.x / 4.0, 1.0 - m.y / 6.7)
		"glass", "glass_in":
			# The pane in metres, for the curtains painted behind it (see WindowLights.GLASS_SHADER).
			return m
		"timber", "shutter":
			# Grain along the length of the beam; a shift per beam.
			return Vector2(m.x / 3.0 + center.x * 0.37, m.y / 3.0 + center.y * 0.21)
	return m / tile


## The soot-black inside of a chimney's flue (named so the snow leaves it bare, see AgedStone.triangles).
static func _flue_material() -> StandardMaterial3D:
	if not _mats.has("flue"):
		var soot := StandardMaterial3D.new()
		soot.resource_name = "flue"
		soot.albedo_color = Color(0.03, 0.025, 0.02)
		soot.roughness = 1.0
		_mats["flue"] = soot
	return _mats["flue"]


static func _tool(parts: Dictionary, key: String) -> SurfaceTool:
	if not parts.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[key] = st
	return parts[key]


## The aged tiles of a roof (shaders/aged_roof.gdshader), in one of ROOFS.
static func _roof_material(shade: int) -> ShaderMaterial:
	var key := "roof_%d" % shade
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = ROOF_SHADER
		mat.set_shader_parameter("trim", load(STONE_TEX))
		mat.set_shader_parameter("tint", ROOFS[shade])
		_mats[key] = mat
	return _mats[key]


static func _textured(key: String, path: String, tint: Color) -> StandardMaterial3D:
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(path)
		mat.albedo_color = tint
		mat.roughness = 0.9
		_mats[key] = mat
	return _mats[key]
