class_name CraftingSquare
extends RefCounted
## The crafting square: the west side of the village's market square, next
## to Gorm's forge, where every hero finds all the workbenches and their own
## storage chest in one place. It is meant as the spot where players meet:
## everyone comes here to craft, sort their loot and show what they made.
##
## Map letters (outdoor levels, see Outdoor):
##   +  fine metalwork bench (a small anvil, a crucible, rings and wire)
##   %  gem cutter's wheel (a grinding wheel and glittering stones)
##   *  alchemist's table (bottles, and a cauldron bubbling over a fire)
##   $  your storage chest: the same chest as the one at home
## Gorm's forge (forging, melting, mending) stands right beside them, on the
## north side of the square (see Outdoor._build_forge).
##
## The benches are ready for the recipes (see the recipe crafting cycle):
## each one belongs to one craft, and a recipe names the craft it needs, so
## the bench of that craft is where the recipe is made. Until a hero knows
## such a recipe, a bench only tells what is done there.

## What the compendium says about the square, once the hero has used it.
const LEARN := "Am Marktplatz von Lindenhain, gleich neben Gorms Esse, steht der Handwerkerplatz: eine Werkbank fürs Feinschmieden, ein Schleifrad für Edelsteine, ein Tisch für die Alchemie und eine Truhe, in der deine Lagertruhe von zu Hause bereitsteht. Hier treffen sich alle, die etwas herstellen wollen."

## The benches, by map letter: the craft (as the recipes name it), the
## bench's name, its sign and what is done there.
const BENCHES := {
	"+": {
		"craft": "feinschmieden",
		"name": "Werkbank des Feinschmieds",
		"craft_line": "Handwerk: Feinschmieden",
		"sign": "Feinschmied",
		"icon": "ring",
		"prompt": "Dagegenlaufen, um an der Werkbank des Feinschmieds zu arbeiten",
		"text": "Ringe, Ketten, Fassungen und feiner Draht aus Silber, Gold und Eisen.",
	},
	"%": {
		"craft": "edelsteinschleifen",
		"name": "Schleifrad",
		"craft_line": "Handwerk: Edelsteinschleifen",
		"sign": "Edelsteine",
		"icon": "gem",
		"prompt": "Dagegenlaufen, um am Schleifrad Edelsteine zu schleifen",
		"text": "Rohe Steine werden hier geschliffen, bis sie Licht und Kraft fangen.",
	},
	"*": {
		"craft": "alchemie",
		"name": "Alchemistentisch",
		"craft_line": "Handwerk: Alchemie",
		"sign": "Alchemie",
		"icon": "flask",
		"prompt": "Dagegenlaufen, um am Alchemistentisch zu brauen",
		"text": "Kräuter, Pulver und seltene Zutaten werden hier zu Tränken und Tinkturen gebraut.",
	},
}
## The letter of the storage chest on the square.
const CHEST := "$"
## Every letter of the square.
const LETTERS := "+%*$"
const SIGN_FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")


## The bench of a craft, or {} if no bench on the square does it.
static func bench_of(craft: String) -> Dictionary:
	for letter in BENCHES:
		if BENCHES[letter].craft == craft:
			return BENCHES[letter]
	return {}


## Builds the piece of the square on one tile and adds its station to the
## level. The worker stands east of it, on the open square. The bench and the
## wood, stone and iron on it are one weathered mesh (see VillageProps); only
## what shines or glows has a material of its own.
static func build(level: Level, c: Vector2i, ch: String) -> void:
	var pos := level.cell_to_world(c)
	if ch == CHEST:
		_build_chest(level, c, pos)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bench:%s:%d:%d" % [ch, c.x, c.y])
	var b := WeatheredProps.Builder.new()
	VillageProps.build_workbench(b, Vector3(-0.7, 0, 0), rng)
	var top := Vector3(-0.7, 0.98, 0)
	match ch:
		"+":
			VillageProps.dress_metalwork(b, top, rng)
			_dress_metalwork(level, pos)
		"%":
			VillageProps.dress_gem_wheel(b, top, rng)
			_dress_gem_wheel(level, pos)
		"*":
			VillageProps.dress_alchemy(b, top, CAULDRON, rng)
			_dress_alchemy(level, pos)
	b.finish(level, pos)
	var bench: Dictionary = BENCHES[ch]
	_add_sign(level, pos, Lang.t(bench.sign), bench.icon)
	level._add_solid(pos + Vector3(-0.5, 0, 0), Vector3(2.0, 1.2, 3.0))
	level.stations.append({"kind": "werkbank", "craft": bench.craft, "cell": c, "pos": pos, "used": false})


# --- Pieces -------------------------------------------------------------------

## Where the alchemist's cauldron stands, from the middle of the tile: in
## front of the south end of the bench.
const CAULDRON := Vector3(0.55, 0, 1.15)


## The hero's storage chest, iron-bound, its lid turned to the square, with
## a sign so nobody walks past it.
static func _build_chest(level: Level, c: Vector2i, pos: Vector3) -> void:
	level._place("chest", pos + Vector3(-0.4, 0, 0), PI * 0.5)
	# A low plinth of two old slabs keeps it off the wet paving.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chest:%d:%d" % [c.x, c.y])
	var b := WeatheredProps.Builder.new()
	for z in [-0.58, 0.58]:
		b.box(Vector3(-0.4, 0, z), Vector3(1.9, 0.12, 1.12), WeatheredProps.vary(WeatheredProps.STONES[3], rng),
				WeatheredProps.STONE, Basis(Vector3.UP, rng.randf_range(-0.03, 0.03)))
	b.finish(level, pos)
	_add_sign(level, pos, Lang.t("Deine Truhe"), "chest")
	level._add_solid(pos + Vector3(-0.4, 0, 0), Vector3(2.0, 1.5, 2.4))
	level.stations.append({"kind": "lager", "cell": c, "pos": pos, "used": false})


## On the fine metalwork bench, besides the anvil and the hearth of bricks
## (see VillageProps.dress_metalwork): the metal glowing in the crucible, a
## gold ring and a coil of silver wire, and a warm light.
static func _dress_metalwork(level: Level, pos: Vector3) -> void:
	var top := pos + Vector3(-0.7, 0.98, 0)
	var glow := _mat(Color(0.4, 0.12, 0.02), 0.6)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.55, 0.15)
	glow.emission_energy_multiplier = 2.0
	var melt := CylinderMesh.new()
	melt.top_radius = 0.11
	melt.bottom_radius = 0.11
	melt.height = 0.02
	_mesh(level, melt, glow, top + Vector3(-0.1, 0.39, 0.65))
	# A finished ring and a coil of silver wire, catching the light.
	var gold := _mat(Color(0.95, 0.75, 0.3), 0.25, 1.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.05
	ring.outer_radius = 0.075
	_mesh(level, ring, gold, top + Vector3(0.3, 0.02, 0.05))
	var silver := _mat(Color(0.85, 0.87, 0.9), 0.3, 1.0)
	var coil := TorusMesh.new()
	coil.inner_radius = 0.1
	coil.outer_radius = 0.12
	_mesh(level, coil, silver, top + Vector3(0.05, 0.02, 0.15))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = top + Vector3(0.4, 0.8, 0.5)
	level.add_child(light)


## On the gem cutter's bench, besides the wheel (see
## VillageProps.dress_gem_wheel): cut stones in red, blue and green on a
## cloth, glittering.
static func _dress_gem_wheel(level: Level, pos: Vector3) -> void:
	var top := pos + Vector3(-0.7, 0.98, 0)
	_mesh(level, _box_mesh(Vector3(0.7, 0.01, 0.8)), WeatheredProps.colour_material(Color(0.3, 0.16, 0.34)), top + Vector3(0.05, 0.005, 0.6))
	var colours := [Color(0.9, 0.1, 0.15), Color(0.15, 0.35, 1.0), Color(0.1, 0.85, 0.35), Color(0.95, 0.85, 0.3), Color(0.7, 0.3, 0.95)]
	for i in colours.size():
		var gem := _mat(colours[i], 0.1, 0.2)
		gem.emission_enabled = true
		gem.emission = colours[i]
		gem.emission_energy_multiplier = 0.6
		var stone := PrismMesh.new()
		stone.size = Vector3(0.12, 0.1, 0.12)
		_mesh(level, stone, gem, top + Vector3(-0.15 + (i % 3) * 0.2, 0.06, 0.4 + (i / 3) * 0.3), Vector3(0, i * 0.7, 0))
	var sparkle := Effects.make_sparkles(Color(0.8, 0.9, 1.0))
	sparkle.emission_sphere_radius = 0.4
	sparkle.position = top + Vector3(0, 0.2, 0.55)
	level.add_child(sparkle)


## On and by the alchemist's table, besides the cauldron, the mortar and the
## book (see VillageProps.dress_alchemy): bottles of coloured brews, the
## green brew bubbling in the cauldron over a small fire, and its light.
static func _dress_alchemy(level: Level, pos: Vector3) -> void:
	var top := pos + Vector3(-0.7, 0.98, 0)
	var glass := [Color(0.3, 0.8, 0.4, 0.75), Color(0.7, 0.2, 0.8, 0.75), Color(0.9, 0.4, 0.15, 0.75), Color(0.3, 0.5, 0.95, 0.75)]
	for i in glass.size():
		var bottle := _mat(glass[i], 0.15)
		bottle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bottle.emission_enabled = true
		bottle.emission = Color(glass[i], 1.0)
		bottle.emission_energy_multiplier = 0.35
		var body := CylinderMesh.new()
		body.top_radius = 0.06
		body.bottom_radius = 0.09
		body.height = 0.22 + (i % 2) * 0.08
		_mesh(level, body, bottle, top + Vector3(-0.2 + (i % 2) * 0.25, body.height * 0.5, -0.9 + i * 0.22))
		var neck := CylinderMesh.new()
		neck.top_radius = 0.025
		neck.bottom_radius = 0.03
		neck.height = 0.1
		_mesh(level, neck, bottle, top + Vector3(-0.2 + (i % 2) * 0.25, body.height + 0.05, -0.9 + i * 0.22))
	var at := pos + CAULDRON
	var brew := _mat(Color(0.2, 0.7, 0.2), 0.3)
	brew.emission_enabled = true
	brew.emission = Color(0.35, 1.0, 0.3)
	brew.emission_energy_multiplier = 1.2
	var surface := CylinderMesh.new()
	surface.top_radius = 0.4
	surface.bottom_radius = 0.4
	surface.height = 0.02
	_mesh(level, surface, brew, at + Vector3(0, 0.72, 0))
	var fire := Effects.make_flame()
	fire.position = at + Vector3(0, 0.12, 0)
	fire.scale = Vector3.ONE * 0.8
	level.add_child(fire)
	var bubbles := Effects.make_sparkles(Color(0.5, 1.0, 0.45))
	bubbles.emission_sphere_radius = 0.3
	bubbles.position = at + Vector3(0, 0.95, 0)
	level.add_child(bubbles)
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 1.0, 0.4)
	light.light_energy = 1.4
	light.omni_range = 5.5
	light.position = at + Vector3(0, 1.4, 0)
	level.add_child(light)


static func _add_sign(level: Level, pos: Vector3, text: String, icon: String) -> void:
	var board := Effects.shop_sign(text, SIGN_FONT, icon)
	WeatheredProps.weather_plain(board)
	board.position = pos + Vector3(-1.6, 0, 1.75)
	level.add_child(board)
	level._add_solid(pos + Vector3(-1.6, 0, 1.75), Vector3(0.5, 2.6, 0.5))


# --- Helpers ------------------------------------------------------------------

static func _mat(color: Color, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _mesh(level: Level, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	level.add_child(mi)
