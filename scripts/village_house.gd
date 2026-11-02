class_name VillageHouse
## The villagers' homes: half-timbered houses built from simple blocks at
## load time. A stone plinth, plastered walls held by dark oak beams and
## braces, an upper floor that juts out a little over the street, a steep
## tiled roof with a chimney, shuttered windows and a plank door. Every house
## gets its own plaster colour, roof shade, size and door side, so no two
## look the same.
##
## Built facing south (+z, the door side) around the middle of its ground
## floor; the caller turns and places it. The textures are all CC0: wood and
## roof tiles from ambientCG (assets/house), stone and the door from the
## Modular Cathedral Kit (assets/chapel).

const WOOD_TEX := "res://assets/house/wood_floor.jpg"
const STONE_TEX := "res://assets/chapel/trim_sheet.png"
const DOOR_TEX := "res://assets/chapel/door_diffuse.png"

## Plaster colours, and roof tints, picked per house.
const PLASTERS := [Color(0.93, 0.88, 0.76), Color(0.95, 0.92, 0.86), Color(0.90, 0.80, 0.62),
		Color(0.88, 0.76, 0.70), Color(0.84, 0.86, 0.80)]
const ROOFS := [Color(1, 1, 1), Color(0.8, 0.72, 0.68), Color(0.72, 0.74, 0.8), Color(1.0, 0.86, 0.7)]
const TIMBER := Color(0.42, 0.30, 0.22)
## Where the stone blocks sit on the cathedral trim sheet: v from the top of
## four rows of blocks to their bottom, and how many metres those rows cover.
const STONE_V := Vector2(0.6, 0.92)
const STONE_BAND := 4.0
## The red roof tiles on the same sheet (the chapel's roof): u and v from
## corner to corner, and the patch of roof (metres) one copy of them covers.
const TILES_UV := Rect2(0.5, 0.06, 0.5, 0.235)
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


## A house that fits into a footprint of `room` metres (x across the front,
## y deep). Its glowing window panes use `glass`, so the village can light
## them at night.
static func build(room: Vector2, rng: RandomNumberGenerator, glass: StandardMaterial3D) -> Node3D:
	var w := clampf(room.x - 1.2 - JETTY * 2.0, 4.5, 7.0) - rng.randf_range(0.0, 0.6)
	var d := clampf(room.y - 1.4 - JETTY * 2.0, 4.0, 6.0) - rng.randf_range(0.0, 0.5)
	var ridge := rng.randf_range(2.6, 3.4)
	var door_x: float = [-1.0, 0.0, 1.0][rng.randi() % 3] * (w * 0.5 - 1.2)
	var parts := {}
	var top := PLINTH + GROUND
	var eaves := top + UPPER
	# Stone plinth, plastered ground floor and the jutting upper floor.
	_box(parts, "stone", Vector3(0, PLINTH * 0.5, 0), Vector3(w + 0.1, PLINTH, d + 0.1))
	_box(parts, "plaster", Vector3(0, PLINTH + GROUND * 0.5, 0), Vector3(w, GROUND, d))
	var uw := w + JETTY * 2.0
	var ud := d + JETTY * 2.0
	_box(parts, "plaster", Vector3(0, top + UPPER * 0.5, 0), Vector3(uw, UPPER, ud))
	# The frame: posts, sills and rails, and braces on the long walls.
	_frame(parts, w, d, PLINTH, GROUND, door_x)
	_frame(parts, uw, ud, top, UPPER, INF)
	# The floor beams of the jetty poking out under the upper floor.
	for i in range(1, int(uw / 1.1)):
		var x := -uw * 0.5 + i * uw / int(uw / 1.1)
		_box(parts, "timber", Vector3(x, top - 0.12, d * 0.5 + JETTY * 0.5), Vector3(0.18, 0.18, JETTY + 0.1))
		_box(parts, "timber", Vector3(x, top - 0.12, -d * 0.5 - JETTY * 0.5), Vector3(0.18, 0.18, JETTY + 0.1))
	# Door, windows with shutters.
	_door(parts, Vector3(door_x, PLINTH, d * 0.5))
	for x: float in _window_spots(w, door_x):
		_window(parts, Vector3(x, PLINTH + 1.6, d * 0.5), 0.0)
	for x: float in _window_spots(uw, INF):
		_window(parts, Vector3(x, top + 1.3, ud * 0.5), 0.0)
	for side: float in [-1.0, 1.0]:
		_window(parts, Vector3(side * uw * 0.5, top + 1.3, 0), side * PI * 0.5)
		_window(parts, Vector3(side * w * 0.5, PLINTH + 1.6, 0), side * PI * 0.5)
	# The roof, its gables and the chimney.
	_gables(parts, uw, ud, eaves, ridge)
	_roof(parts, uw + ROOF_OVERHANG * 2.0, ud + ROOF_OVERHANG * 2.0, eaves, ridge, ud)
	var cx := rng.randf_range(-0.3, 0.3) * uw
	_box(parts, "stone", Vector3(cx, eaves + ridge * 0.6, -ud * 0.22), Vector3(0.8, ridge * 1.2 + 0.8, 0.8))
	_box(parts, "timber", Vector3(cx, eaves + ridge * 1.2 + 0.45, -ud * 0.22), Vector3(0.95, 0.12, 0.95))

	var house := Node3D.new()
	house.name = "House"
	house.set_meta("village_house", true)
	house.add_child(_mesh_of(parts, _materials(rng, glass)))
	return house


## A narrow town house for a row of them along a lane (see
## Outdoor._build_terrace): `room.x` across the front, so neighbours almost
## touch, and three storeys, each jutting out a little further over the
## street than the one below. The gable faces the lane, the roof slopes down
## to the neighbours on either side, and a small sign over the door carries
## the house number. Built facing south (+z) like `build`.
static func build_narrow(room: Vector2, number: int, rng: RandomNumberGenerator, glass: StandardMaterial3D) -> Node3D:
	var w := room.x - 0.06
	var d := clampf(room.y - 1.6 - JETTY * 2.0, 4.0, 6.0) - rng.randf_range(0.0, 0.3)
	var ridge := w * rng.randf_range(0.62, 0.8)
	var door_x: float = [-1.0, 1.0][rng.randi() % 2] * (w * 0.5 - 1.0)
	var parts := {}
	_box(parts, "stone", Vector3(0, PLINTH * 0.5, 0), Vector3(w, PLINTH, d + 0.1))
	_box(parts, "plaster", Vector3(0, PLINTH + GROUND * 0.5, 0), Vector3(w - 0.04, GROUND, d))
	_frame(parts, w - 0.04, d, PLINTH, GROUND, door_x)
	_door(parts, Vector3(door_x, PLINTH, d * 0.5))
	_window(parts, Vector3(-door_x, PLINTH + 1.6, d * 0.5), 0.0)
	_window(parts, Vector3(w * 0.25, PLINTH + 1.6, -d * 0.5), PI)
	# Two upper storeys, each jutting out over the lane a little more.
	var y0 := PLINTH + GROUND
	for k in range(1, NARROW_STOREYS):
		var sd := d + JETTY * k
		var z0 := JETTY * k * 0.5
		_box(parts, "plaster", Vector3(0, y0 + UPPER * 0.5, z0), Vector3(w - 0.04, UPPER, sd))
		_frame(parts, w - 0.04, sd, y0, UPPER, INF, z0)
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
	_box(parts, "stone", Vector3(cx, y0 + ridge * 0.55, top_z - top_d * 0.25), Vector3(0.6, ridge * 1.1 + 0.8, 0.6))
	_box(parts, "timber", Vector3(cx, y0 + ridge * 1.1 + 0.45, top_z - top_d * 0.25), Vector3(0.75, 0.12, 0.75))
	# The house sign: a board on a bracket over the door.
	_box(parts, "timber", Vector3(door_x, PLINTH + 2.75, d * 0.5 + 0.3), Vector3(0.08, 0.08, 0.6))
	_box(parts, "door", Vector3(door_x, PLINTH + 2.55, d * 0.5 + 0.55), Vector3(0.62, 0.42, 0.06))

	var house := Node3D.new()
	house.name = "TownHouse%d" % number
	house.set_meta("town_house", number)
	house.set_meta("door_x", door_x)
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
	return house


## How many storeys a narrow town house has: ground floor and two above.
const NARROW_STOREYS := 3


static func _materials(rng: RandomNumberGenerator, glass: StandardMaterial3D) -> Dictionary:
	return {
		"plaster": _plaster(PLASTERS[rng.randi() % PLASTERS.size()]),
		"timber": _textured("timber", WOOD_TEX, TIMBER),
		"roof": _textured("roof_%d" % (rng.randi() % ROOFS.size()), STONE_TEX, Color.WHITE),
		"stone": _textured("stone", STONE_TEX, Color(0.9, 0.88, 0.85)),
		"door": _textured("door", DOOR_TEX, Color.WHITE),
		"glass": glass,
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


## Posts at the corners and between, sill and rail beams, braces on the
## front and back. No post stands in front of the door.
static func _frame(parts: Dictionary, w: float, d: float, y0: float, h: float, door_x: float, z0 := 0.0) -> void:
	var hb := BEAM * 0.5
	for side: float in [-1.0, 1.0]:
		var z := side * (d * 0.5 + 0.02) + z0
		var x := side * (w * 0.5 + 0.02)
		# Sill and head beams all round.
		for y: float in [y0 + hb, y0 + h - hb]:
			_box(parts, "timber", Vector3(0, y, z), Vector3(w + 0.1, BEAM, BEAM))
			_box(parts, "timber", Vector3(x, y, z0), Vector3(BEAM, BEAM, d + 0.1))
		# A rail under the windows. On the door side it stops at the door
		# posts: run across the doorway, its face lay a few millimetres in
		# front of the door's and the two flickered through each other.
		var rail_y := y0 + h * 0.42
		var rail := Vector3(0, BEAM * 0.8, BEAM * 0.9)
		if side > 0.0 and absf(door_x) < w * 0.5:
			var gap := DOOR_REACH - 0.04
			for piece: Vector2 in [Vector2(-w * 0.5, door_x - gap), Vector2(door_x + gap, w * 0.5)]:
				if piece.y - piece.x > 0.01:
					_box(parts, "timber", Vector3((piece.x + piece.y) * 0.5, rail_y, z), rail + Vector3(piece.y - piece.x, 0, 0))
		else:
			_box(parts, "timber", Vector3(0, rail_y, z), rail + Vector3(w, 0, 0))
		# Corner posts.
		for s2: float in [-1.0, 1.0]:
			_box(parts, "timber", Vector3(s2 * (w * 0.5 + 0.02), y0 + h * 0.5, z), Vector3(BEAM, h, BEAM))
		# Posts along the long walls, braced at the ends.
		var bays := maxi(2, int(w / 1.6))
		for i in range(1, bays):
			var px := -w * 0.5 + i * w / bays
			if absf(px - door_x) < 0.9:
				continue
			_box(parts, "timber", Vector3(px, y0 + h * 0.5, z), Vector3(BEAM * 0.9, h, BEAM * 0.9))
		var bay := w / bays
		for end: float in [-1.0, 1.0]:
			if absf(end * (w * 0.5 - bay * 0.5) - door_x) < 1.0:
				continue
			var len := Vector2(bay, h).length()
			var tilt := atan2(h, bay) * end
			var b := Basis(Vector3(0, 0, 1), tilt)
			_box(parts, "timber", Vector3(end * (w * 0.5 - bay * 0.5), y0 + h * 0.5, z), Vector3(len, BEAM * 0.8, BEAM * 0.8), b)
		# A post in the middle of the gable walls.
		_box(parts, "timber", Vector3(x, y0 + h * 0.5, z0), Vector3(BEAM * 0.9, h, BEAM * 0.9))


## How far the door posts reach out from the middle of the door (metres).
const DOOR_POST := 0.66
const DOOR_REACH := DOOR_POST + BEAM * 0.5


## A plank door under a beam, with a step of stone before it.
static func _door(parts: Dictionary, at: Vector3) -> void:
	_box(parts, "door", at + Vector3(0, 1.05, 0.06), Vector3(1.1, 2.1, 0.1))
	_box(parts, "timber", at + Vector3(0, 2.2, 0.08), Vector3(1.5, BEAM, BEAM))
	for s: float in [-1.0, 1.0]:
		_box(parts, "timber", at + Vector3(s * DOOR_POST, 1.1, 0.08), Vector3(BEAM, 2.2, BEAM))
	_box(parts, "stone", Vector3(at.x, 0.1, at.z + 0.4), Vector3(1.5, 0.2, 0.7))


## A window: a glowing pane in a frame, with open shutters either side.
static func _window(parts: Dictionary, at: Vector3, turn: float) -> void:
	var b := Basis(Vector3.UP, turn)
	var out := b * Vector3(0, 0, 1)
	var side := b * Vector3(1, 0, 0)
	_box(parts, "glass", at + out * 0.03, Vector3(0.8, 0.9, 0.06), b)
	_box(parts, "timber", at + out * 0.07, Vector3(0.08, 0.9, 0.06), b)
	_box(parts, "timber", at + out * 0.07, Vector3(0.8, 0.08, 0.06), b)
	_box(parts, "timber", at + out * 0.08 - Vector3(0, 0.5, 0), Vector3(1.0, 0.12, 0.16), b)
	_box(parts, "timber", at + out * 0.08 + Vector3(0, 0.5, 0), Vector3(1.0, 0.1, 0.12), b)
	for s: float in [-1.0, 1.0]:
		_box(parts, "door", at + side * s * 0.68 + out * 0.08, Vector3(0.45, 0.95, 0.05), b)


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
	var cols := maxi(1, roundi(w / TILES_PATCH.x))
	var rows := maxi(1, roundi(len / TILES_PATCH.y))
	for side: float in [-1.0, 1.0]:
		var b := Basis(Vector3(1, 0, 0), side * slope)
		var mid := Vector3(0, eaves + ridge - sin(slope) * len * 0.5 + 0.1, side * d * 0.25)
		_box(parts, "timber", mid, Vector3(w, 0.14, len), b)
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
				for k: int in order:
					st.set_normal(n)
					st.set_uv(uvs[k])
					st.add_vertex(quad[k])
	_box(parts, "timber", Vector3(0, eaves + ridge + 0.14, 0), Vector3(w + 0.1, 0.24, 0.3))


## A box into the surface for `key`: centre, size, turn. Its texture is laid
## by metres, so a long beam shows a long grain and not a stretched one.
static func _box(parts: Dictionary, key: String, center: Vector3, size: Vector3, basis := Basis(), tile := 2.0) -> void:
	var st := _tool(parts, key)
	var h := size * 0.5
	# Each face: its normal and the two axes across it.
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var su := absf(u.dot(size))
		var sv := absf(v.dot(size))
		var c := n * h
		var corners := [c - u * su * 0.5 - v * sv * 0.5, c + u * su * 0.5 - v * sv * 0.5,
				c + u * su * 0.5 + v * sv * 0.5, c - u * su * 0.5 + v * sv * 0.5]
		var uvs := [Vector2(0, 0), Vector2(su, 0), Vector2(su, sv), Vector2(0, sv)]
		# Clockwise seen from outside, which Godot draws as the front. Wound
		# the other way the camera saw the far insides of every box, dark and
		# flickering through each other (tests/house_faces.gd).
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_normal(basis * n)
			st.set_uv(_uv(key, uvs[k], center, tile))
			st.add_vertex(center + basis * corners[k])


## Texture coordinates for a spot on a face, `m` metres from its corner.
static func _uv(key: String, m: Vector2, center: Vector3, tile: float) -> Vector2:
	match key:
		"stone":
			# Within the band of stone blocks on the trim sheet.
			return Vector2(m.x / 8.0, STONE_V.y - fposmod(m.y, STONE_BAND) / STONE_BAND * (STONE_V.y - STONE_V.x))
		"door", "glass":
			return Vector2(m.x / 4.0, 1.0 - m.y / 6.7)
		"timber":
			# Grain along the length of the beam; a shift per beam.
			return Vector2(m.x / 3.0 + center.x * 0.37, m.y / 3.0 + center.y * 0.21)
	return m / tile


static func _tool(parts: Dictionary, key: String) -> SurfaceTool:
	if not parts.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[key] = st
	return parts[key]


static func _textured(key: String, path: String, tint: Color) -> StandardMaterial3D:
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(path)
		mat.albedo_color = tint
		mat.roughness = 0.9
		if key.begins_with("roof"):
			mat.albedo_color = ROOFS[int(key.substr(5))]
		_mats[key] = mat
	return _mats[key]


## Lime plaster: the colour with a faint mottle, so the walls are not flat.
static func _plaster(colour: Color) -> StandardMaterial3D:
	var key := "plaster_%s" % colour.to_html()
	if not _mats.has(key):
		if not _mats.has("mottle"):
			var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for y in 64:
				for x in 64:
					var g := 0.9 + rng.randf() * 0.1 - (0.05 if rng.randf() < 0.04 else 0.0)
					img.set_pixel(x, y, Color(g, g, g))
			img.resize(256, 256, Image.INTERPOLATE_CUBIC)
			img.generate_mipmaps()
			_mats["mottle"] = ImageTexture.create_from_image(img)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.albedo_texture = _mats["mottle"]
		mat.roughness = 1.0
		_mats[key] = mat
	return _mats[key]
