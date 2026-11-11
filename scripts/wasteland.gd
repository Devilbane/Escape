class_name Wasteland
extends RefCounted
## The Forsaken Wasteland: a land far beyond the mountain tavern that the
## wind has blown empty, and at the end of its Processional Way the ruined
## shrine of Mirenna, Lady of Mercy (see RuinedShrine).
##
## On the open-air map a signposted pilgrims' path leads south from the
## mountain tavern's yard through ice wolves and a cliff archer to a gate cut
## into the rock (letter `"`, "building: wueste1"), with a signpost (`°`) at
## each end of the path. Inside (levels/40_die_verlassene_wueste.txt, theme
## "wueste") the way runs between broken pillars, past a wrecked caravan with
## its scavengers, dune jackals and the unquiet dead of pilgrims who never
## arrived, to the shrine. Old Sarra, the shrine's last servant, camps in a
## hut beside the way with a well: befriend her for the shrine's story and
## help, or walk past.
##
## In a Level (Tiles.DUNGEON) `"` is the shrine and `°` a dead tree.

## The building the gate leads to, and the theme of its map.
const BUILDING := "wueste1"
const THEME := "wueste"
## The light of the wasteland: a low, warm sun.
const MOODS := {
	THEME: {"ambient": Color(0.82, 0.68, 0.5), "energy": 0.62, "light": Color(1.0, 0.88, 0.64)},
}
## The sign on the path (German, see Lang).
const SIGN_TEXT := "Pilgerweg\nVerlassene Wüste"

const SAND := Color(0.82, 0.7, 0.5)
const SAND_DARK := Color(0.6, 0.5, 0.36)
const WOOD := Color(0.42, 0.3, 0.2)

const TREES := ["tree_dead_large", "tree_dead_medium", "tree_dead_small"]
const TREE_DIR := "res://assets/graveyard/"


static func mood(theme: String) -> Dictionary:
	return MOODS.get(theme, {})


## The gate in the rock: two sandstone pillars, one broken, a lintel with a
## sun, dark beyond, sand drifted over the step.
static func build_gate(outdoor: Outdoor, c: Vector2i) -> void:
	var pos := outdoor.cell_to_world(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	var stone := SternParts.material(SAND)
	var dark := SternParts.material(SAND_DARK)
	var black := SternParts.material(Color(0.02, 0.015, 0.012), 0.0, 1.0, true)
	SternParts._box(outdoor, Vector3(3.2, 4.4, 0.6), black, pos + Vector3(0, 2.2, -0.2))
	SternParts._box(outdoor, Vector3(1.3, 6.4, 1.5), stone, pos + Vector3(-2.3, 3.2, 0.2))
	SternParts._box(outdoor, Vector3(1.3, 4.0, 1.5), stone, pos + Vector3(2.3, 2.0, 0.2))
	SternParts._box(outdoor, Vector3(4.2, 0.9, 1.5), stone, pos + Vector3(-0.6, 5.0, 0.2))
	SternParts._box(outdoor, Vector3(4.6, 0.25, 1.4), dark, pos + Vector3(0, 0.12, 1.0))
	# The fallen top of the right pillar, half sunk into the sand.
	SternParts._box(outdoor, Vector3(1.2, 1.0, 1.3), stone, pos + Vector3(3.6, 0.5, 2.0), Vector3(0, 0.5, 0.2))
	# A faded sun over the doorway, the mark of Mirenna's pilgrims.
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.08
	SternParts._mesh(outdoor, disc, SternParts.material(Color(1.0, 0.8, 0.4), 0.8), pos + Vector3(-0.6, 5.0, 1.0), Vector3(PI * 0.5, 0, 0))
	for i in 4:
		SternParts._box(outdoor, Vector3(rng.randf_range(0.6, 1.4), 0.3, rng.randf_range(0.6, 1.2)), SternParts.material(Color(0.86, 0.74, 0.52)),
				pos + Vector3(rng.randf_range(-2.2, 2.2), 0.1, rng.randf_range(1.5, 3.2)), Vector3(0, rng.randf() * TAU, 0))
	SternParts._light(outdoor, Color(1.0, 0.78, 0.45), 0.9, 6.0, pos + Vector3(0, 1.6, 1.2))
	outdoor._add_solid(pos, Vector3(Level.TILE, 4.0, Level.TILE))
	outdoor.doors[BUILDING] = pos + Vector3(0, 0, Level.TILE * 0.8)
	if outdoor.interiors.has(BUILDING):
		outdoor.stations.append({"kind": "eingang", "building": BUILDING, "name": Outdoor.BUILDING_NAMES["\""],
				"cell": c, "pos": pos, "used": false})


## A signpost of the pilgrims' path: a post and a board, its face to the
## north, where the hero comes from, and an arrow pointing the way on.
static func build_signpost(outdoor: Outdoor, c: Vector2i) -> void:
	var pos := outdoor.cell_to_world(c)
	var wood := SternParts.material(WOOD)
	SternParts._box(outdoor, Vector3(0.28, 3.4, 0.28), wood, pos + Vector3(0, 1.7, 0))
	SternParts._box(outdoor, Vector3(2.5, 1.2, 0.14), wood, pos + Vector3(0, 2.9, -0.2))
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.9, 0.8, 0.14)
	SternParts._mesh(outdoor, arrow, wood, pos + Vector3(0, 1.85, -0.2), Vector3(0, 0, PI))
	var label := Label3D.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = Lang.t(SIGN_TEXT)
	label.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	label.font_size = 40
	label.pixel_size = 0.0085
	label.outline_size = 8
	label.modulate = Color(0.96, 0.9, 0.74)
	label.outline_modulate = Color(0.12, 0.08, 0.05, 0.9)
	label.position = pos + Vector3(0, 2.9, -0.3)
	label.rotation.y = PI
	outdoor.add_child(label)
	outdoor._add_solid(pos, Vector3(0.8, 3.0, 0.8))


## A dead tree on the tile `c` of the wasteland.
static func build_tree(lvl: Level, c: Vector2i) -> void:
	var pos := lvl.cell_to_world(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	var scene: PackedScene = load(TREE_DIR + TREES[rng.randi() % TREES.size()] + ".gltf")
	var tree: Node3D = scene.instantiate()
	tree.position = pos + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	tree.rotation.y = rng.randf() * TAU
	tree.scale = Vector3.ONE * rng.randf_range(1.1, 1.5)
	lvl.add_child(tree)
	lvl._add_solid(pos, Vector3(1.4, 4.0, 1.4))


## What the whole map gets on top of its tiles: wind-blown dust drifting
## across the sand.
static func dress(lvl: Level) -> void:
	var middle := lvl.cell_to_world(Vector2i(lvl.width / 2, lvl.height / 2))
	for i in 3:
		var dust := Effects.make_dust()
		dust.emission_box_extents = Vector3(lvl.width * Level.TILE * 0.17, 3.0, lvl.height * Level.TILE * 0.5)
		dust.position = middle + Vector3((i - 1) * lvl.width * Level.TILE * 0.33, 2.0, 0)
		dust.amount = 110
		dust.direction = Vector3(1, 0.1, 0.25)
		dust.initial_velocity_min = 0.8
		dust.initial_velocity_max = 1.8
		lvl.add_child(dust)
