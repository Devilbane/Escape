class_name GardenDecor
extends RefCounted
## The garden pieces of a self-built house (see HouseFurniture.KINDS, the kinds with "garden"):
## they stand outdoors on the plot, where no roof is built, and Ilse the furnisher sells them with
## the furniture. Their models are built here, and the grill cooks.
##
##   Blumenbeet    a bed of flowers edged with field stones
##   Blumenkübel   a wooden tub bound with iron, a bunch of flowers in it
##   Gartenfackel  a torch on a tall stake: it burns day and night and lights the garden
##   Gartenlaterne the village's street lamp (see VillageProps.build_lamp), its light steady
##   Grill         a brick barbecue with an iron grate over glowing coals
##
## The flowers go with the seasons (see stage): bright blooms in spring and summer, gold, orange and
## rust in autumn, and in winter only dark tufts and a few dry seed heads. The furnisher draws them
## again when the season turns (see HouseFurnisher._process).
##
## The grill: running into it grills what the hero carries in the ingredient pouch, wild meat first
## (the spoils of wild animals), else a perch (from fishing), and eating it gives life back (see
## grill). A hero with full life keeps the food.

## The station kind of the grill (see Game._use_station).
const GRILL := "grill"
## What the grill cooks, best first: ingredient, life it gives back, the line it says.
const GRILL_FOOD := [
	["wildfleisch", 4, "Wildfleisch vom Grill, außen knusprig, innen saftig. +%d Leben"],
	["barsch", 3, "Ein gegrillter Barsch mit Salz und Kräutern. +%d Leben"],
]
## How long the food sizzles on the grate before the hero eats (seconds).
const GRILL_TIME := 1.2
## What the compendium says once the hero has grilled.
const GRILL_LEARN := "Am Grill in deinem Garten grillst du Wildfleisch (Beute wilder Tiere) oder einen Barsch (Angeln) aus deinem Zutatenbeutel: Lauf dagegen, und das Essen gibt dir Leben zurück. Wildfleisch macht satter als Fisch. Bist du unverletzt, bleibt das Essen im Beutel."

## The seasons of the flowers.
const SPRING_SUMMER := 0
const AUTUMN := 1
const WINTER := 2
## The blooms of each season.
const BLOOMS := {
	SPRING_SUMMER: [Color(0.86, 0.16, 0.2), Color(0.98, 0.82, 0.2), Color(0.62, 0.3, 0.82), Color(0.96, 0.96, 0.92),
			Color(0.98, 0.5, 0.66), Color(0.3, 0.46, 0.9)],
	AUTUMN: [Color(0.84, 0.46, 0.09), Color(0.8, 0.62, 0.14), Color(0.62, 0.16, 0.08), Color(0.72, 0.3, 0.1), Color(0.5, 0.2, 0.32)],
	WINTER: [Color(0.42, 0.33, 0.22), Color(0.5, 0.42, 0.3)],
}
const LEAVES := {SPRING_SUMMER: Color(0.22, 0.48, 0.16), AUTUMN: Color(0.4, 0.4, 0.14), WINTER: Color(0.14, 0.24, 0.13)}
## Of the flowers, the share that wears a bloom in each season.
const BLOOMING := {SPRING_SUMMER: 1.0, AUTUMN: 0.75, WINTER: 0.25}
## The light of a garden torch (a touch stronger than indoors, no ceiling throws it back) and of the
## grill's coals.
const TORCH_ENERGY := 1.7
const TORCH_RANGE := 10.0
const COALS_ENERGY := 1.6
const COALS_RANGE := 6.0
## The steady light of the garden lamp (like the village's, see Outdoor._lantern_glow).
const LAMP_ENERGY := 2.2
const LAMP_RANGE := 11.0
const LAMP_COLOUR := Color(1.0, 0.74, 0.48)
## Where the lamp's post stands in its cell (its lantern hangs out over the middle, see
## VillageProps.LANTERN_AT).
const LAMP_POST := Vector3(0, 0, -0.5)


## The flowers' season on `day`.
static func stage(day: int) -> int:
	if Weather.is_winter(day):
		return WINTER
	return AUTUMN if Weather.is_autumn(day) else SPRING_SUMMER


## Builds the model of a garden piece into `root` (front +z, middle at the origin, on the ground)
## and returns its solids ({at, size}, local). `season` is a stage, `lights` gets [node, energy,
## range, flicker] for each light the furnisher should add (see HouseFurnisher._add_light).
static func build(root: Node3D, kind: String, season: int, level: Level, lights: Array) -> Array:
	var seed := hash("garden:%s:%s" % [kind, root.position.snapped(Vector3.ONE * 0.1)])
	match kind:
		"blumenbeet":
			_build_bed(root, season, seed)
			return [{"at": Vector3.ZERO, "size": Vector3(1.7, 0.3, 1.7)}]
		"blumenkuebel":
			_build_tub(root, season, seed)
			return [{"at": Vector3.ZERO, "size": Vector3(1.0, 0.6, 1.0)}]
		"gartenfackel":
			lights.append([_build_torch(root), TORCH_ENERGY, TORCH_RANGE, true])
			return [{"at": Vector3.ZERO, "size": Vector3(0.4, 1.9, 0.4)}]
		"gartenlaterne":
			var panes: Material = level._lantern_panes() if level is Outdoor else HomeStoreFurniture._mat(Color(1.0, 0.8, 0.5))
			VillageProps.build_lamp(root, LAMP_POST, panes)
			var at := Node3D.new()
			at.position = LAMP_POST + VillageProps.LANTERN_AT - Vector3(0, 0.1, 0)
			root.add_child(at)
			lights.append([at, LAMP_ENERGY, LAMP_RANGE, false])
			return [{"at": LAMP_POST, "size": Vector3(0.6, 3.0, 0.6)}]
		"grill":
			lights.append([_build_grill(root), COALS_ENERGY, COALS_RANGE, true])
			return [{"at": Vector3.ZERO, "size": Vector3(1.3, 1.0, 0.85)}]
	return []


## A bed of flowers: dark soil edged with field stones, and clumps of leaves with their blooms.
static func _build_bed(root: Node3D, season: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var soil := HomeStoreFurniture._mat(Color(0.2, 0.14, 0.09), 0.95)
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(1.5, 0.14, 1.5)), soil, Vector3(0, 0.07, 0))
	# The stone edge: a ring of flat field stones round the soil.
	for i in 20:
		var a := TAU * i / 20.0
		var r := 0.8
		var along := Vector3(clampf(cos(a) * 1.15, -1, 1) * r, 0.08, clampf(sin(a) * 1.15, -1, 1) * r)
		var grey := 0.42 + rng.randf() * 0.18
		var stone := HomeStoreFurniture._add(root, HomeStoreFurniture._sphere(0.12), HomeStoreFurniture._mat(Color(grey, grey * 0.97, grey * 0.92), 0.9), along)
		stone.scale = Vector3(1.3, 0.6, 1.1) * rng.randf_range(0.85, 1.15)
		stone.rotation.y = rng.randf() * TAU
	for i in 13:
		var at := Vector3(rng.randf_range(-0.55, 0.55), 0.14, rng.randf_range(-0.55, 0.55))
		_flower(root, at, season, rng, rng.randf_range(0.3, 0.55))


## A wooden tub with iron hoops, soil in it and a bunch of flowers.
static func _build_tub(root: Node3D, season: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var wood := HomeStoreFurniture._mat(Color(0.42, 0.27, 0.15), 0.85)
	var iron := HomeStoreFurniture._mat(Color(0.2, 0.19, 0.18), 0.5, 0.6)
	HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.42, 0.34, 0.5), wood, Vector3(0, 0.25, 0))
	HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.425, 0.4, 0.05), iron, Vector3(0, 0.42, 0))
	HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.37, 0.355, 0.05), iron, Vector3(0, 0.1, 0))
	HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.39, 0.39, 0.03), HomeStoreFurniture._mat(Color(0.2, 0.14, 0.09), 0.95), Vector3(0, 0.47, 0))
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.5
		var r := 0.0 if i == 0 else rng.randf_range(0.12, 0.28)
		_flower(root, Vector3(cos(a) * r, 0.48, sin(a) * r), season, rng, rng.randf_range(0.35, 0.6))


## One flower: a stem, a tuft of leaves at its foot and (in season) a bloom on top.
static func _flower(root: Node3D, at: Vector3, season: int, rng: RandomNumberGenerator, tall: float) -> void:
	var leaf := HomeStoreFurniture._mat(LEAVES[season] * rng.randf_range(0.85, 1.15), 0.8)
	var tuft := HomeStoreFurniture._add(root, HomeStoreFurniture._sphere(0.13), leaf, at + Vector3(0, 0.06, 0))
	tuft.scale = Vector3(1.2, 0.6, 1.2)
	if season == WINTER:
		tall *= 0.6
	var stem := HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.012, 0.016, tall), leaf, at + Vector3(0, tall * 0.5, 0))
	stem.rotation = Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	if rng.randf() > BLOOMING[season]:
		return
	var colours: Array = BLOOMS[season]
	var bloom_mat := HomeStoreFurniture._mat(colours[rng.randi() % colours.size()], 0.6)
	var top := at + Vector3(0, tall, 0) + Vector3(stem.rotation.z * -tall * 0.5, 0, stem.rotation.x * tall * 0.5)
	var bloom := HomeStoreFurniture._add(root, HomeStoreFurniture._sphere(0.07 if season != WINTER else 0.04), bloom_mat, top)
	bloom.scale = Vector3(1.3, 0.7, 1.3)
	if season != WINTER:
		# A yellow heart in the bloom.
		HomeStoreFurniture._add(root, HomeStoreFurniture._sphere(0.03), HomeStoreFurniture._mat(Color(0.95, 0.75, 0.2), 0.6), top + Vector3(0, 0.04, 0))


## A torch on a tall stake: an iron basket of pitch on top, its flame, and where its light hangs.
static func _build_torch(root: Node3D) -> Node3D:
	var wood := HomeStoreFurniture._mat(Color(0.36, 0.23, 0.13), 0.85)
	var iron := HomeStoreFurniture._mat(Color(0.18, 0.17, 0.16), 0.5, 0.6)
	HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.035, 0.05, 1.6), wood, Vector3(0, 0.8, 0))
	HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.12, 0.06, 0.18), iron, Vector3(0, 1.66, 0))
	HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.1, 0.1, 0.06), HomeStoreFurniture._mat(Color(0.08, 0.06, 0.05), 0.9), Vector3(0, 1.73, 0))
	var flame := Effects.make_flame()
	flame.position = Vector3(0, 1.8, 0)
	root.add_child(flame)
	var at := Node3D.new()
	at.position = Vector3(0, 2.05, 0)
	root.add_child(at)
	return at


## A brick barbecue: a stone stand, an iron fire box with glowing coals, a grate with sausages on
## it, and embers lifting off. Returns where the coals' light hangs.
static func _build_grill(root: Node3D) -> Node3D:
	var brick := HomeStoreFurniture._mat(Color(0.52, 0.26, 0.18), 0.9)
	var mortar := HomeStoreFurniture._mat(Color(0.62, 0.58, 0.52), 0.95)
	var iron := HomeStoreFurniture._mat(Color(0.14, 0.13, 0.12), 0.5, 0.6)
	# Two brick legs and a stone slab across them.
	for side in [-1, 1]:
		HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(0.24, 0.6, 0.7)), brick, Vector3(side * 0.5, 0.3, 0))
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(1.25, 0.1, 0.8)), mortar, Vector3(0, 0.65, 0))
	# The fire box, the coals in it and the grate over them.
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(1.1, 0.2, 0.66)), iron, Vector3(0, 0.8, 0))
	var coals := StandardMaterial3D.new()
	coals.albedo_color = Color(0.25, 0.08, 0.03)
	coals.emission_enabled = true
	coals.emission = Color(1.0, 0.36, 0.08)
	coals.emission_energy_multiplier = 1.6
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(1.0, 0.04, 0.56)), coals, Vector3(0, 0.9, 0))
	for i in 9:
		HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(1.04, 0.02, 0.02)), iron, Vector3(0, 0.96, -0.28 + i * 0.07))
	# Sausages on the grate.
	var sausage := HomeStoreFurniture._mat(Color(0.5, 0.24, 0.14), 0.55)
	for i in 3:
		var s := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.035
		cap.height = 0.32
		s.mesh = cap
		s.material_override = sausage
		s.position = Vector3(-0.25 + i * 0.22, 1.0, 0.05 * (i - 1))
		s.rotation = Vector3(PI * 0.5, 0, 0)
		root.add_child(s)
	var embers := Effects.make_forge_embers()
	embers.emission_box_extents = Vector3(0.45, 0.02, 0.25)
	embers.amount = 6
	embers.position = Vector3(0, 0.95, 0)
	root.add_child(embers)
	var at := Node3D.new()
	at.position = Vector3(0, 1.3, 0)
	root.add_child(at)
	return at


## The hero runs into their grill: the best food in the pouch sizzles a moment and is eaten.
static func grill(game: Node) -> void:
	var player: Player = game.player
	if player.hp >= player.max_hp:
		game.show_message(Lang.t("Du bist unverletzt und satt. Das Essen bleibt im Beutel."), 2.6)
		return
	var food := _food(game.crafting)
	if food.is_empty():
		game.show_message(Lang.t("Nichts zum Grillen: Bring Wildfleisch (Beute wilder Tiere) oder einen Barsch (Angeln) mit."), 3.2)
		return
	if game.get_meta("grilling", false):
		return
	game.set_meta("grilling", true)
	player.play_flourish("PickUp", 0.6)
	game.crafting.take(food[0])
	await game.get_tree().create_timer(GRILL_TIME).timeout
	game.set_meta("grilling", false)
	if not is_instance_valid(player) or player.hp <= 0:
		return
	var heal: int = food[1]
	player.hp = mini(player.max_hp, player.hp + heal)
	Sfx.play(game, "drink")
	var text: String = Lang.t(food[2]) % heal
	Effects.float_text(game.level, player.global_position + Vector3(0, 3.0, 0), Lang.t("+%d Leben") % heal, Color(1.0, 0.5, 0.55), true)
	game.show_message(text, 3.0)
	Events.teach(GRILL_LEARN)
	game._update_hud()


## The best food the pouch holds for the grill, as a GRILL_FOOD row, or [].
static func _food(crafting: Crafting) -> Array:
	for row in GRILL_FOOD:
		if crafting.have(row[0]) > 0:
			return row
	return []
