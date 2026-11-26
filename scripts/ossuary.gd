class_name Ossuary
extends RefCounted
## The crypt under the graveyard as an ossuary (see OwlClock): along the walls of its rooms stand shelves with rows of
## skulls, each with a little name plate. Almost all names are made up, with a title in front (Mr., Captain, Baroness,
## Sergeant ...), some funny and some plain. Two are the ones the wandering trader asks for (see Quests,
## "zarek_schaedel"): Madame Medusa, with a few green snakes on her head, and Mr. Snoops, in a pair of tiny dark
## glasses. Bumping their shelf, the hero takes the skull when the task is open.
##
## Everything is built here, in code, when the level is made (Level calls dress): the shelves from textured wood, the
## skulls from one mesh made of spheres and boxes (bone and dark sockets), the plates with a Label3D each.

const KIND := "ossuary"
const MEDUSA := "schaedel_medusa"
const SNOOPS := "schaedel_snoops"
## How many shelf units at most, and how many skulls a unit holds (tiers by places).
const MAX_UNITS := 14
const TIERS := 3
const PLACES := 5
const WIDTH := 3.6
const DEPTH := 0.8
const HEIGHT := 2.6
## Where the two skulls stand: the shelf nearest to these cells of the crypt's map.
const MEDUSA_AT := Vector2i(3, 8)
const SNOOPS_AT := Vector2i(12, 18)

const SHELF_TEXT := "Regale voller Schädel, jeder mit einem Namensschild: Das Beinhaus der Gruft."
const TAKEN := "Du nimmst den Schädel von %s an dich."
const SEEN := "%s. Der Schädel grinst dich an, als wüsste er etwas."
const LORE := "Beinhaus: Unter dem Friedhof stehen Regale voller Schädel, jeder mit einem Namensschild. Zwei von ihnen, Madame Medusa und Herr Snoops, sucht der fahrende Händler Zarek."

const TITLES_M := ["Herr", "Hauptmann", "Feldwebel", "Baron", "Graf", "Doktor", "Pfarrer", "Professor", "Admiral", "Major", "Bürgermeister", "Bruder", "Meister", "Kommodore"]
const TITLES_F := ["Frau", "Fräulein", "Baronin", "Gräfin", "Schwester", "Äbtissin", "Professorin", "Doktorin"]
const FIRST_M := ["Hubertus", "Ottokar", "Cornelius", "Ignaz", "Egbert", "Percival", "Mortimer", "Adalbert", "Fridolin", "Balthasar",
		"Leopold", "Erasmus", "Siegmund", "Jeremias", "Isidor", "Thaddäus", "Kasimir", "Bartholomäus", "Lambert", "Xaver"]
const FIRST_F := ["Gundula", "Brunhilde", "Walburga", "Lucinda", "Kunigunde", "Dorothea", "Ottilie", "Rosalinde", "Philomena",
		"Hildegard", "Agathe", "Wilhelmine", "Cäcilie", "Edeltraud", "Gertrude", "Melusine", "Perpetua", "Sieglinde"]
const LAST := ["Knochenhauer", "Staubfeld", "Grabner", "Moderstein", "Totenmann", "Kerzenschein", "Schlotterbeck", "Bleichgesicht",
		"Zahnlücke", "Hohlkopf", "Mottenburg", "Spinnweb", "Klapperstein", "Kaltmann", "Sargnagel", "Bröselmann", "Dunkelfels",
		"Rostig", "Flüsterer", "Nachtigall", "Mondschein", "Eichenholz", "Habermann", "Pfennigfuchs", "Brummbär", "Müller",
		"Schmidt", "Becker", "Krause", "Hoffmann", "Weber", "Wagner", "Schulz", "Fischer"]
## Plain titled names, written out: some funny, some plain.
const NAMED := [
	["Hauptmann", "Bartholomäus Butterbrot"], ["Feldwebel", "Pfefferkorn"], ["Baron", "von Staubwedel"],
	["Frau", "Dorothea Dosenöffner"], ["Herr", "Müller"], ["Frau", "Schmidt"], ["Doktor", "Ignatz Autsch"],
	["Pfarrer", "Hilarius Amen"], ["Admiral", "Nelson Nassfuß"], ["Major", "Tom Tadel"], ["Baronin", "von Schnarchenberg"],
	["Fräulein", "Rosa Rührei"], ["Graf", "Zahl von Pfennig"], ["Herr", "Becker"], ["Schwester", "Agathe Aua"],
	["Bürgermeister", "Hubert Hopfen"], ["Meister", "Eder"], ["Professor", "Quirin Quark"], ["Kommodore", "Kielholz"],
	["Frau", "Hoffmann"], ["Herr", "Weber"], ["Gräfin", "Mathilde Mottenkugel"], ["Bruder", "Benedikt Brummel"],
	["Feldwebel", "Fritz Fussel"], ["Hauptmann", "Haudegen"], ["Herr", "Schulz"], ["Frau", "Wagner"],
	["Doktor", "Knut Knöchel"], ["Fräulein", "Lieselotte Lampenfieber"], ["Baron", "Bleiche von Grabstein"],
	["Herr", "Fischer"], ["Frau", "Krause"], ["Professor", "Dagobert Dunkel"], ["Äbtissin", "Hedwig Hall"],
	["Major", "Mauz"], ["Admiral", "Anker"],
]

static var _texture_cache := {}

## The cells along the crypt's walls where a unit of shelves fits: a plain floor cell with exactly one wall at its
## side, none of the cells round it a prop, a lever or a fire. Each is {"cell", "dir"}: dir points into the room.
static func candidates(lvl: Level) -> Array:
	var out := []
	var sides := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for y in lvl.height:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if lvl.cell_char(c) != ".":
				continue
			var walls := []
			for d: Vector2i in sides:
				if lvl.cell_char(c + d) == "#":
					walls.append(d)
			if walls.size() != 1:
				continue
			var clear := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not lvl.cell_char(c + Vector2i(dx, dy)) in ".,#":
						clear = false
			if clear:
				out.append({"cell": c, "dir": -walls[0]})
	return out


## The units to build: the candidates, thinned out to MAX_UNITS and with a unit at each of the two named
## skulls' places (the nearest candidate to MEDUSA_AT and SNOOPS_AT).
static func plan(lvl: Level) -> Array:
	var all := candidates(lvl)
	if all.is_empty():
		return []
	var medusa := _nearest(all, MEDUSA_AT)
	var snoops := _nearest(all, SNOOPS_AT)
	var picked := [medusa]
	if snoops != medusa:
		picked.append(snoops)
	var rest := all.filter(func(u): return u != medusa and u != snoops and _apart(u, picked))
	var step := maxf(1.0, float(rest.size()) / maxf(1.0, MAX_UNITS - picked.size()))
	var i := 0.0
	while int(i) < rest.size() and picked.size() < MAX_UNITS:
		var u: Dictionary = rest[int(i)]
		if _apart(u, picked):
			picked.append(u)
		i += step
	picked.sort_custom(func(a, b): return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	return picked.map(func(u): return {"cell": u.cell, "dir": u.dir, "key": MEDUSA if u == medusa else (SNOOPS if u == snoops else "")})


static func _nearest(all: Array, at: Vector2i) -> Dictionary:
	var best: Dictionary = all[0]
	for u: Dictionary in all:
		if Vector2(u.cell - at).length() < Vector2(best.cell - at).length():
			best = u
	return best


## No two units in neighbouring cells: a gap of floor between the shelves.
static func _apart(u: Dictionary, picked: Array) -> bool:
	for p: Dictionary in picked:
		if absi(p.cell.x - u.cell.x) <= 1 and absi(p.cell.y - u.cell.y) <= 1:
			return false
	return true


## The names of all the skulls, in the order the units hold them. Madame Medusa and Mr. Snoops are the entries
## the unit with their key takes in the middle of its middle tier.
static func names(count: int, seed_value: int) -> Array:
	var out: Array = []
	var seen := {}
	for e: Array in NAMED:
		out.append(e)
		seen["%s|%s" % [e[0], e[1]]] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var guard := 0
	while out.size() < count and guard < count * 20:
		guard += 1
		var female := rng.randf() < 0.45
		var title: String = (TITLES_F if female else TITLES_M)[rng.randi() % (TITLES_F.size() if female else TITLES_M.size())]
		var first: String = (FIRST_F if female else FIRST_M)[rng.randi() % (FIRST_F.size() if female else FIRST_M.size())]
		var last: String = LAST[rng.randi() % LAST.size()]
		var key := "%s|%s %s" % [title, first, last]
		if seen.has(key):
			continue
		seen[key] = true
		out.append([title, "%s %s" % [first, last]])
	# A shuffle, so the funny ones are spread over the shelves.
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## The plate text of a name entry [title, name], in the current language.
static func plate(entry: Array) -> String:
	return "%s %s" % [Lang.t(entry[0]), entry[1]]


# --- Building ------------------------------------------------------------------------------------

## Dresses the crypt (the level of building OwlClock.ID) with its shelves, skulls and plates, the blocks for them
## and one station per shelf unit.
static func dress(lvl: Level) -> void:
	var units := plan(lvl)
	var skull_mesh := _skull_mesh()
	var wood := _wood()
	var all_names := names(units.size() * TIERS * PLACES, hash(lvl.level_name))
	var next := 0
	var root := Node3D.new()
	root.name = "Ossuary"
	lvl.add_child(root)
	for u: Dictionary in units:
		var inward := Vector3(u.dir.x, 0, u.dir.y)
		var centre := lvl.cell_to_world(u.cell) - inward * (Level.TILE * 0.5 - DEPTH * 0.5 - 0.02)
		var unit := Node3D.new()
		unit.position = centre
		unit.rotation.y = atan2(inward.x, inward.z)
		root.add_child(unit)
		_shelves(unit, wood)
		var listed := []
		for tier in TIERS:
			for place in PLACES:
				var entry: Array = all_names[next % all_names.size()]
				next += 1
				var key := ""
				if u.key != "" and tier == 1 and place == PLACES / 2:
					key = u.key
					entry = ["Madame", "Medusa"] if key == MEDUSA else ["Herr", "Snoops"]
				var x := (place - (PLACES - 1) * 0.5) * (WIDTH - 0.5) / (PLACES - 1)
				var y := 0.1 + tier * 0.85 + 0.035
				var skull := _skull(skull_mesh, unit, Vector3(x, y, 0.02), (next * 37 % 100) / 100.0 - 0.5, key)
				_plate(unit, Vector3(x, y, DEPTH * 0.5 - 0.13), plate(entry))
				listed.append(plate(entry))
				if key != "":
					skull.name = "Skull_" + key
		# The shelves block the floor they stand on, no wider than themselves.
		var along := Vector3(WIDTH + 0.1, HEIGHT, DEPTH) if absf(inward.z) > 0.5 else Vector3(DEPTH, HEIGHT, WIDTH + 0.1)
		lvl._add_solid(centre, along)
		lvl.stations.append({"kind": KIND, "cell": u.cell, "pos": centre + inward * (DEPTH * 0.5 + 0.7), "touch": 2.3,
				"used": false, "skull": u.key, "names": listed, "unit": unit})


## The skull a key unit holds, to take off the shelf (null if there is none).
static func skull_node(s: Dictionary) -> Node3D:
	var unit: Node3D = s.get("unit")
	if unit == null or not is_instance_valid(unit) or s.skull == "":
		return null
	return unit.get_node_or_null("Skull_" + str(s.skull))


## The hero bumped a shelf (a station of KIND): the key skulls are taken when the task wants them.
static func use(game: Node, s: Dictionary) -> void:
	var key: String = s.skull
	if key == "":
		game.show_message(Lang.t(SHELF_TEXT), 5.0)
		game.learn(LORE)
		return
	var shown := Lang.t("Madame") + " Medusa" if key == MEDUSA else Lang.t("Herr") + " Snoops"
	var wanted: bool = game.quests.is_active(Quests.SKULLS) and not game.player.bag.has(key)
	if not wanted:
		game.show_message(Lang.t(SEEN) % shown, 5.0)
		game.learn(LORE)
		return
	if game.player.bag_size() - game.player.bag_used() <= 0:
		game.show_message(Lang.t("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg."), 3.0)
		return
	game.player.bag.append(key)
	var node := skull_node(s)
	if node != null:
		node.visible = false
	Events.bus().quest_item_given.emit()
	Events.tell(Lang.t(TAKEN) % shown, Color(0.9, 0.86, 0.7))
	game.learn(LORE)


## Hides the skulls the hero carries already (the crypt entered again).
static func hide_taken(lvl: Level, bag: Array) -> void:
	for s: Dictionary in lvl.stations:
		if s.kind != KIND or s.skull == "":
			continue
		var node := skull_node(s)
		if node != null:
			node.visible = not bag.has(s.skull)


## The frame of a shelf unit: two sides, a back and the boards.
static func _shelves(unit: Node3D, wood: Material) -> void:
	for sx in [-1.0, 1.0]:
		_box(unit, Vector3(0.09, HEIGHT, DEPTH), Vector3(sx * (WIDTH * 0.5), HEIGHT * 0.5, 0), wood)
	_box(unit, Vector3(WIDTH, HEIGHT, 0.05), Vector3(0, HEIGHT * 0.5, -DEPTH * 0.5 + 0.025), wood)
	for tier in TIERS + 1:
		_box(unit, Vector3(WIDTH, 0.07, DEPTH), Vector3(0, 0.065 + tier * 0.85, 0), wood)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


## A skull on the shelf, turned a little to the side. Medusa carries snakes, Snoops glasses.
static func _skull(mesh: Mesh, unit: Node3D, pos: Vector3, turn: float, key: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation.y = turn * 0.7
	m.scale = Vector3.ONE * 0.3
	unit.add_child(m)
	if key == MEDUSA:
		var green := StandardMaterial3D.new()
		green.albedo_color = Color(0.2, 0.55, 0.2)
		green.roughness = 0.5
		for i in 6:
			var angle := TAU * i / 6.0
			var snake := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.025
			cyl.bottom_radius = 0.05
			cyl.height = 0.55
			snake.mesh = cyl
			snake.material_override = green
			snake.position = Vector3(cos(angle) * 0.3, 0.92, sin(angle) * 0.3 - 0.05)
			snake.rotation = Vector3(sin(angle) * 0.7, 0, -cos(angle) * 0.7)
			m.add_child(snake)
	elif key == SNOOPS:
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.04, 0.04, 0.05)
		dark.metallic = 0.4
		dark.roughness = 0.2
		for sx in [-1.0, 1.0]:
			var lens := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.17
			disc.bottom_radius = 0.17
			disc.height = 0.04
			lens.mesh = disc
			lens.material_override = dark
			lens.position = Vector3(sx * 0.2, 0.42, 0.5)
			lens.rotation.x = PI * 0.5
			m.add_child(lens)
		var bridge := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.22, 0.03, 0.03)
		bridge.mesh = bar
		bridge.material_override = dark
		bridge.position = Vector3(0, 0.45, 0.5)
		m.add_child(bridge)
	return m


## A small brass plate lying on the board in front of a skull, tilted up to be read, with the name on it.
static func _plate(unit: Node3D, pos: Vector3, text: String) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 0.03, 0)
	holder.rotation.x = deg_to_rad(50.0)
	unit.add_child(holder)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.62, 0.5, 0.26)
	brass.metallic = 0.5
	brass.roughness = 0.5
	_box(holder, Vector3(0.56, 0.012, 0.15), Vector3.ZERO, brass)
	var label := Label3D.new()
	label.text = text
	label.font_size = 24
	label.outline_size = 0
	label.modulate = Color(0.12, 0.08, 0.04)
	label.rotation.x = deg_to_rad(-90.0)
	label.position = Vector3(0, 0.008, 0)
	label.pixel_size = clampf(0.46 / (maxf(float(text.length()), 8.0) * 24.0 * 0.55), 0.0006, 0.004)
	label.shaded = true
	label.double_sided = false
	label.no_depth_test = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	holder.add_child(label)


## The one skull mesh (face towards +z, cranium radius about 0.5): bone and, as a second surface, the dark sockets.
static func _skull_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var bone := SurfaceTool.new()
	bone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cranium := SphereMesh.new()
	cranium.radius = 0.5
	cranium.height = 1.0
	cranium.radial_segments = 20
	cranium.rings = 12
	bone.append_from(cranium, 0, Transform3D(Basis.from_scale(Vector3(0.95, 0.95, 1.1)), Vector3(0, 0.55, 0)))
	var cheeks := BoxMesh.new()
	cheeks.size = Vector3(0.66, 0.3, 0.5)
	bone.append_from(cheeks, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.18, 0.14)))
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.5, 0.14, 0.42)
	bone.append_from(jaw, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0.16)))
	var chin := BoxMesh.new()
	chin.size = Vector3(0.3, 0.1, 0.1)
	bone.append_from(chin, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.07, 0.36)))
	var teeth := BoxMesh.new()
	teeth.size = Vector3(0.44, 0.08, 0.06)
	bone.append_from(teeth, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0.4)))
	bone.set_material(_bone())
	bone.generate_normals()
	bone.commit(mesh)
	var dark := SurfaceTool.new()
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var socket := SphereMesh.new()
	socket.radius = 0.11
	socket.height = 0.22
	socket.radial_segments = 10
	socket.rings = 6
	for sx in [-1.0, 1.0]:
		dark.append_from(socket, 0, Transform3D(Basis.from_scale(Vector3(0.9, 1.15, 0.45)), Vector3(sx * 0.2, 0.42, 0.52)))
	var nose := BoxMesh.new()
	nose.size = Vector3(0.1, 0.15, 0.08)
	dark.append_from(nose, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.24, 0.52)))
	var gap := BoxMesh.new()
	gap.size = Vector3(0.012, 0.085, 0.01)
	for i in 6:
		dark.append_from(gap, 0, Transform3D(Basis.IDENTITY, Vector3(-0.15 + i * 0.06, 0.05, 0.435)))
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.03, 0.025, 0.02)
	shade.roughness = 1.0
	dark.set_material(shade)
	dark.generate_normals()
	dark.commit(mesh)
	return mesh


static func _bone() -> StandardMaterial3D:
	if _texture_cache.has("bone"):
		return _texture_cache.bone
	var n := FastNoiseLite.new()
	n.seed = 8
	n.frequency = 0.09
	n.fractal_octaves = 4
	var img := Image.create(96, 96, false, Image.FORMAT_RGB8)
	for y in 96:
		for x in 96:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var stain := clampf((n.get_noise_2d(x * 2.3 + 40, y * 2.3) - 0.2) * 1.6, 0.0, 1.0)
			var base := Color(0.88, 0.83, 0.68).lerp(Color(0.74, 0.66, 0.48), v)
			img.set_pixel(x, y, base.lerp(Color(0.5, 0.4, 0.26), stain * 0.45))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 0.85
	mat.uv1_scale = Vector3(2, 2, 1)
	_texture_cache["bone"] = mat
	return mat


## Dark old planks with long grain.
static func _wood() -> StandardMaterial3D:
	if _texture_cache.has("wood"):
		return _texture_cache.wood
	var n := FastNoiseLite.new()
	n.seed = 21
	n.frequency = 0.05
	n.fractal_octaves = 4
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var grain := n.get_noise_2d(x * 0.15, y * 2.2) * 0.5 + 0.5
			var knot := n.get_noise_2d(x * 1.5 + 90, y * 1.5) * 0.5 + 0.5
			var c := Color(0.27, 0.17, 0.09).lerp(Color(0.46, 0.31, 0.17), grain)
			img.set_pixel(x, y, c.darkened(0.25 * clampf(knot - 0.55, 0.0, 1.0) * 2.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 0.9
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
	_texture_cache["wood"] = mat
	return mat
