class_name Outdoor
extends Level
## The world above ground, reached by the last stairs of the dungeon: the hero
## steps out of a crypt onto a graveyard, follows a long path through the
## woods and comes to a village. Villagers go about their work there, and
## the village elder gives the hero an empty house with a bed and a chest.
##
## Map legend (one character per 4x4 m tile):
##   #  forest (trees, cannot be crossed)    .  grass         ,  dirt path
##   P  start, in front of the crypt door    ~  pond
##   R  the crypt (a block of tiles)         g  grave         d  dead tree
##   z  graveyard fence                      a  gate in the fence
##   l  lantern on a post                    p  pumpkins      r  rock
##   T  tree                                 t  tree stump with logs
##   e  barrels, crates and sacks            q  well
##   Buildings, each a rectangular block of the same letter:
##   h  house (half-timbered, see VillageHouse)   j  smithy   n  tavern   m  market   u  windmill
##   y  pumpkin field
##   %  Weavers' Lane: a row of narrow three-storey town houses, one per
##      tile across the front (see VillageHouse.build_narrow), numbered from
##      west to east. Every one is a home for a hero (see Homes), entered by
##      its own door; inside, all of them share the building floor with the
##      line "building: %" (bed, chest, stairs and room for furniture).
##   The hero's house: I  stone wall   i  wooden floor (a gap in the
##   walls is the door)   B  bed (save and log out)   L  chest (storage)
##   :  paved square         F  fountain (heals)   x  bench
##   More buildings: s  temple (a chapel)   k  office of the crown   o  post office
##   w  adventurers' guild   b  bank. A building turns its door to the square or path.
##   Villagers: 0 elder, 1 smith (melts, forges and mends gear at the forge
##   on the tile to his left, see Forge), 2 farmer, 3 woodcutter, 4 guard,
##   5 tavern guest, 6 shopkeeper (buys and sells), 7 child, 8 scholar,
##   9 water carrier, K herald of the crown, O priestess, G guild master,
##   M postmaster, Y banker, S stonemason (sells stone blocks to build with,
##   his stone yard is on the tile behind him). Now and then the herald calls out news on the square,
##   and the villagers come over to listen.
##   The robbers' pass east of the village: N tent   f campfire   C treasure chest
##   and the bandits who roam there and come back a while after they fall:
##   c cutthroat, A poacher (crossbow), X bruiser, Q bandit chief (see Enemy).
##   The world keeps the time of day (see DayNight): lanterns and the
##   windows of the houses glow at night, most villagers go home to sleep,
##   the dead rise from the graves and roam the graveyard until dawn, and
##   the bandits of the pass are bolder in the dark.
##   The wolf hollow north of the pass, where beasts roam and come back the
##   same way: W wolf, H orc, J yeti, U spider.
##   Peaceful animals that graze in the woods and bolt from the hero
##   (see Animal): D doe, V stag, & fox.
##   E  the way down into the dragon's lair: a stone arch over stairs into
##      the dark (a block of tiles, see Level "lair: yes")
##   v  a stone pedestal with a food basket on top, too high to reach from
##      the ground or from one crate: stack two crates beside it. Three
##      wooden crates lie close by (see Crate).

## A notice for the message line, e.g. when the house is handed over.
signal notice(text: String, duration: float)
## The hero walked into the house the elder gave for the first time: it is
## theirs now, and the place every saved game starts from.
signal home_claimed
## The hero has reached the food basket on the pedestal and eats.
signal food_basket(heal: int)

const GRAVEYARD_DIR := "res://assets/graveyard/"
const VILLAGE_DIR := "res://assets/village/"
## Tiles anyone can walk on. Everything else is solid.
const WALK := ".,Pai:0123456789KOGMYZScAXQWHJUDV&"
## Tiles of the robbers' camp: bare, trodden earth.
const CAMP := "NfC"
const VILLAGERS := "0123456789KOGMYZS"
const BLOCK_CHARS := "RhjnmuskowbE%"
const BLOCK_MODELS := {
	"R": "crypt", "j": "building_blacksmith_red", "n": "building_tavern_blue",
	"m": "building_market_green", "u": "building_windmill_red",
	"k": "building_castle_blue", "o": "building_home_A_yellow",
	"w": "building_barracks_red", "b": "building_tower_A_blue",
}
const BUILDING_NAMES := {
	"b": "die Bank der Krone", "s": "den Tempel", "k": "das Amt der Krone", "w": "die Abenteurergilde",
	"o": "die Post", "j": "die Schmiede", "n": "das Wirtshaus", "m": "den Laden",
	"E": "die Drachenhöhle",
}
## The herald calls out news this often (seconds, picked at random between the
## two bounds each time); the first call comes sooner.
const HERALD_EVERY_MIN := 160.0
const HERALD_EVERY_MAX := 240.0
const HERALD_FIRST_MIN := 50.0
const HERALD_FIRST_MAX := 75.0
const GRAVES := ["grave_A", "grave_B", "gravestone", "gravemarker_A", "gravemarker_B", "grave_A_destroyed"]
const PROPS := ["barrel", "crate_A_big", "sack", "wheelbarrow", "bucket_water", "resource_lumber", "resource_stone"]
## The village props come as table-top miniatures: this blows them up to
## the hero's size.
const PROP_SCALE := 6.0
## How far from the open ground trees still grow (in tiles).
const FOREST_DEPTH := 4
## Ground pieces are this many tiles across. Each piece is lit by the
## lanterns near it only, so many lanterns can burn at once.
const GROUND_CHUNK := 12
const TREE_SHADER := preload("res://shaders/tree.gdshader")
## The temple: a chapel from the Modular Cathedral Kit (see _build_chapel).
## Pieces in the kit's own metres, with the door looking south (+z): name,
## where it stands and how far it is turned (degrees).
const CHAPEL_DIR := "res://assets/chapel/"
const CHAPEL_PARTS := [
	["wall_01", Vector3(-12, 0, 11), 0.0], ["doorway_01", Vector3(-4, 0, 11), 0.0], ["wall_01", Vector3(4, 0, 11), 0.0],
	["door_01", Vector3(-2, 0, 11.4), 0.0],
	["wall_01", Vector3(12, 0, -11), 180.0], ["wall_rose_window_01", Vector3(4, 0, -11), 180.0], ["wall_01", Vector3(-4, 0, -11), 180.0],
	["wall_window_01", Vector3(11, 0, 12), 90.0], ["wall_window_01", Vector3(11, 0, 4), 90.0], ["wall_window_01", Vector3(11, 0, -4), 90.0],
	["wall_window_01", Vector3(-11, 0, -12), -90.0], ["wall_window_01", Vector3(-11, 0, -4), -90.0], ["wall_window_01", Vector3(-11, 0, 4), -90.0],
	["rooftop_01", Vector3(0, 16, 8), 0.0], ["rooftop_01", Vector3(0, 16, 0), 0.0], ["rooftop_01", Vector3(0, 16, -8), 0.0],
	["spire_01", Vector3(0, 16, 8), 0.0],
]
## Half the nave's width (x) and length (z), the height of its walls and of
## the gables under the roof, all in kit metres.
const CHAPEL_HALF := Vector2(12, 12)
const CHAPEL_EAVES := 16.0
const CHAPEL_GABLE_HEIGHT := 13.0
## The ground the chapel covers, steps included (kit metres), and the middle
## of it along z.
const CHAPEL_FOOT := Vector2(24, 30)
const CHAPEL_FOOT_MID := 3.0
## Where the bricks sit on the kit's trim sheet (v from top to bottom of four
## rows of bricks).
const GABLE_BRICK_V := Vector2(0.6, 0.92)

const HOUSE_ROOF_HEIGHT := 3.6
const WALL_HEIGHT := 4.0
## The elder calls the hero over from this far (metres).
const GREET_RANGE := 11.0
## Bandits: how likely each piece of gear is on them, how likely a worn
## piece drops when they fall, and the gold in their purse. The chief has
## more of everything.
const BANDIT_GEAR_CHANCE := 0.45
const BANDIT_DROP_CHANCE := 0.35
const CHIEF_GEAR_CHANCE := 0.6
const CHIEF_DROP_CHANCE := 0.5
## Seconds after a bandit falls until another takes its place, and how far
## away the hero must be for that to happen out of sight.
const BANDIT_RESPAWN := 150.0
const RESPAWN_FAR := 40.0
## The hero is warned about the pass (or the wolf hollow) when a bandit's
## (or a beast's) spot is this close (metres).
const WILD_WARNING_RANGE := 16.0
## Remembered in the saved game once the bandit chief has fallen: he does
## not come back. His spot stays empty from then on.
const CHIEF_DEFEATED := "boss:bandit_chief"
## Gold in the chief's purse, and how far from his post his cutthroats
## come running when he calls them (tiles).
const CHIEF_GOLD := 15
const CALL_FROM_TILES := Vector2i(5, 9)
## The pedestal with the food basket: how tall it is (metres), how far from
## the basket the hero can reach it, how high their feet must stand for that
## (on two stacked crates), the lives the food gives back, and the seconds
## until the basket is full again.
const PEDESTAL_HEIGHT := 3.2
const BASKET_REACH := 2.4
const BASKET_FEET := Crate.SIZE * 2.0 - 0.2
const BASKET_HEAL := 3
const BASKET_REFILL := 180.0
## Where the pedestal's crates lie, from the middle of its tile.
const PEDESTAL_CRATES: Array[Vector3] = [Vector3(-2.6, 0, 1.0), Vector3(2.5, 0, 1.6), Vector3(-1.4, 0, 3.0)]

var villagers: Array = []
## The peaceful animals of the woods (see Animal).
var animals: Array[Animal] = []
var _animal_spots: Array = []
## Has the elder handed the house over yet? Saved games wake up at home.
var house_given := false
## The villagers the hero has talked to, by role letter (see Villager.ROLES):
## their names stay over their heads. Shared with Game.met, so it is kept in
## the saved game.
var met := {}
## Where the hero wakes up in the house: next to the bed.
var home_spot := Vector3.ZERO
## Fronts of the village buildings: where villagers walk to.
var spots := {"houses": [], "square": [], "well": []}
## The narrow town houses of Weavers' Lane, by number - 1 (see _build_terrace).
var town_houses: Array[Node3D] = []

var _plants := {}
var _house_rect := Rect2i()
var _door_cell := Vector2i(-1, -1)
var _roof: Node3D
var _south_walls: Array = []
var _inside := false
var _entered_once := false
var _marker: Node3D
var _elder: Node3D
var _aabbs := {}
## Buildings with floors of their own: building letter -> level index.
var interiors := {}
## Where each building's door is, by building letter.
var doors := {}
var _herald: Node3D
var _herald_timer := randf_range(HERALD_FIRST_MIN, HERALD_FIRST_MAX)
## The bandits' spots: cell, kind, the bandit standing there (or null while
## it is gone), seconds until the next one arrives, and how many came so far.
var _wild: Array = []
var _wild_warned := false
var _beasts_warned := false
## The bandit chief while he stands, his health bar, and the cutthroats he
## called in to help (they do not come back once they fall).
var chief: BanditChief
var boss_bar: BossBar
var _called: Array[Enemy] = []
## The food basket: where it stands, its food, whether it is full, the
## seconds until it fills again, and whether the hero was told about it.
var _basket := {}

## Lanterns: how strongly they shine by day and at night, the glowing
## candle in each, and how far their light shows the hero to enemies.
const LAMP_DAY := 0.5
const LAMP_NIGHT := 3.2
const LAMP_REACH := 8.0
const CANDLE_GLOW := 5.0
var _lamps: Array[OmniLight3D] = []
## The bandits' campfires light up their camp at night too.
var _fires: Array[Vector3] = []
var _candles: Array[MeshInstance3D] = []
var _candle_mat: StandardMaterial3D
## Where the window panes of the village houses sit in the kit's palette
## texture: one small patch colours every pane. A mask over that patch lets
## the windows glow without touching walls or roofs.
const WINDOW_UV := Vector2(0.816, 0.292)
const WINDOW_LIGHT := Color(1.0, 0.7, 0.36)
const WINDOW_GLOW := 2.6
## The kit's material -> its copy with glowing windows.
var _window_mats := {}
var _window_mask: ImageTexture
## The hour the world was last lit for, and whether it is night.
var hour := -1.0
var night := false
## The dead of the graveyard: they rise from these graves at nightfall
## (kinds in turn), come back a while after they fall as long as it is
## night, and sink back into the earth at dawn. They never rise within
## sight of the hero.
const NIGHT_DEAD := 5
const NIGHT_DEAD_KINDS := ["krieger", "wicht", "krieger", "schuetze", "wicht"]
const NIGHT_DEAD_RESPAWN := 90.0
const NIGHT_DEAD_FAR := 14.0
## At night fallen bandits are replaced this much sooner.
const NIGHT_RESPAWN_FACTOR := 0.5
var _graves: Array[Vector2i] = []
var _risen: Array = []


func build() -> void:
	_rng.seed = hash(level_name)
	add_child(_walls_body)
	_build_ground()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			_build_outdoor_cell(c, cell_char(c))
	_build_blocks()
	_build_forest()
	_build_house()
	_build_wall_collision()
	_setup_astar()
	_flush_plants()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	_walls_body.add_child(floor_shape)
	_spawn_villagers()
	_spawn_wild()
	_spawn_animals()


# --- Ground -------------------------------------------------------------------

## One mask pixel per tile: red is path, green graveyard soil, both the
## paved square, blue water, alpha open ground (the forest floor is darker).
func _build_ground() -> void:
	var mask := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var fence := _bounds_of("z")
	var square := _bounds_of(":")
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			var path := 1.0 if ",aP".contains(ch) else 0.0
			var soil := 1.0 if (fence.has_point(c) and not ",aP".contains(ch)) or ch == "y" or CAMP.contains(ch) else 0.0
			# Paving stones: path and soil together mean the square.
			if square.has_point(c) and not BLOCK_CHARS.contains(ch):
				path = 1.0
				soil = 1.0
			var wet := 1.0 if ch == "~" else 0.0
			var open := 0.0 if ch == "#" else 1.0
			mask.set_pixel(x, y, Color(path, soil, wet, open))
	# A smoother mask gives softer edges between the tiles.
	mask.resize(width * 4, height * 4, Image.INTERPOLATE_BILINEAR)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/meadow.gdshader")
	mat.set_shader_parameter("ground_mask", ImageTexture.create_from_image(mask))
	mat.set_shader_parameter("grid_size", Vector2(width, height))
	mat.set_shader_parameter("tile", TILE)
	var margin := 10
	var size := GROUND_CHUNK * TILE
	for cy in range(-margin, height + margin, GROUND_CHUNK):
		for cx in range(-margin, width + margin, GROUND_CHUNK):
			var plane := PlaneMesh.new()
			plane.size = Vector2(size, size)
			var piece := MeshInstance3D.new()
			piece.mesh = plane
			piece.material_override = mat
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.position = Vector3((cx - 0.5) * TILE + size * 0.5, 0, (cy - 0.5) * TILE + size * 0.5)
			add_child(piece)


## The smallest rectangle around all tiles of one kind.
func _bounds_of(ch: String) -> Rect2i:
	var r := Rect2i()
	var first := true
	for y in height:
		for x in width:
			if cell_char(Vector2i(x, y)) == ch:
				if first:
					r = Rect2i(x, y, 1, 1)
					first = false
				else:
					r = r.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	return r


# --- Models -------------------------------------------------------------------

func _model_path(name: String) -> String:
	if name.begins_with("lair/"):
		return Level.LAIR_DIR + name.substr(5) + ".fbx"
	var path := GRAVEYARD_DIR + name + ".gltf"
	return path if ResourceLoader.exists(path) else VILLAGE_DIR + name + ".gltf"


func _put(name: String, pos: Vector3, rot := 0.0, s := 1.0, parent: Node = self) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load(_model_path(name))
	var node: Node3D = _scenes[name].instantiate()
	node.position = pos
	node.rotation.y = rot
	node.scale = Vector3.ONE * s
	if name.begins_with("tree"):
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = _tree_material(mi.get_active_material(0), not name.ends_with("_cut"))
	parent.add_child(node)
	return node


## The kit's trees are flat, even colours with a glossy shine: plastic. This
## gives their leaves clusters, speckle and a sway, and their bark a grain
## (see tree.gdshader), keeping the kit's palette texture. One material per
## palette, cached.
func _tree_material(mat: Material, wind := true) -> Material:
	var tex: Texture2D = (mat as StandardMaterial3D).albedo_texture if mat is StandardMaterial3D else null
	var key := "mat_tree_%d_%d" % [tex.get_instance_id() if tex else 0, int(wind)]
	if not _scenes.has(key):
		var bark := ShaderMaterial.new()
		bark.shader = TREE_SHADER
		bark.set_shader_parameter("albedo_tex", tex)
		bark.set_shader_parameter("wind", 1.0 if wind else 0.0)
		_scenes[key] = bark
	return _scenes[key]


## Many copies of one model (trees) are drawn together in one go.
func _plant(name: String, pos: Vector3, rot: float, s: float) -> void:
	if not _plants.has(name):
		_plants[name] = []
	_plants[name].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), pos))


func _flush_plants() -> void:
	for name in _plants:
		var scene: Node3D = load(_model_path(name)).instantiate()
		for part in _meshes_of(scene, Transform3D()):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = _plants[name].size()
			for i in mm.instance_count:
				mm.set_instance_transform(i, _plants[name][i] * part[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if name.begins_with("tree"):
				mmi.material_override = _tree_material((part[0] as Mesh).surface_get_material(0))
			add_child(mmi)
		scene.free()


## Every mesh in a model, with where it sits inside the model.
func _meshes_of(node: Node, xform: Transform3D) -> Array:
	var found := []
	for child in node.get_children():
		if not child is Node3D:
			continue
		var t: Transform3D = xform * child.transform
		if child is MeshInstance3D and child.mesh:
			found.append([child.mesh, t])
		found.append_array(_meshes_of(child, t))
	return found


## The size of a model, measured once.
func _aabb_of(name: String) -> AABB:
	if not _aabbs.has(name):
		var scene: Node3D = load(_model_path(name)).instantiate()
		var box := AABB()
		var first := true
		for part in _meshes_of(scene, Transform3D()):
			var b: AABB = part[1] * (part[0] as Mesh).get_aabb()
			box = b if first else box.merge(b)
			first = false
		scene.free()
		_aabbs[name] = box
	return _aabbs[name]


func _jitter(amount: float) -> Vector3:
	return Vector3(_rng.randf_range(-amount, amount), 0, _rng.randf_range(-amount, amount))


# --- Tiles --------------------------------------------------------------------

func _build_outdoor_cell(c: Vector2i, ch: String) -> void:
	var pos := cell_to_world(c)
	match ch:
		"P":
			start_cell = c
		"g":
			var grave: String = GRAVES[_rng.randi() % GRAVES.size()]
			_put(grave, pos + Vector3(0, 0, -0.6) + _jitter(0.3), _rng.randf_range(-0.15, 0.15))
			_graves.append(c)
			_add_solid(pos + Vector3(0, 0, -0.6), Vector3(2.0, 1.6, 1.0))
		"d":
			var tree: String = ["tree_dead_large", "tree_dead_medium", "tree_dead_small"][_rng.randi() % 3]
			_put(tree, pos + _jitter(0.5), _rng.randf() * TAU, _rng.randf_range(1.1, 1.4))
			_add_solid(pos, Vector3(1.4, 4, 1.4))
		"p":
			_put("pumpkin_orange_jackolantern", pos + Vector3(-0.4, 0, 0.2), _rng.randf_range(-0.5, 0.5))
			_put("pumpkin_orange", pos + Vector3(0.9, 0, -0.5), _rng.randf() * TAU)
			_put("pumpkin_yellow_small", pos + Vector3(0.6, 0, 0.9), _rng.randf() * TAU)
			_add_solid(pos, Vector3(2.4, 1.2, 2.2))
		"l":
			_build_lantern(pos)
		"r":
			var rock: String = ["rock_single_A", "rock_single_C", "rock_single_E"][_rng.randi() % 3]
			_put(rock, pos + _jitter(0.4), _rng.randf() * TAU, _rng.randf_range(7.0, 9.0))
			_add_solid(pos, Vector3(2.8, 1.6, 2.8))
		"T":
			_build_tree(pos, true)
			_add_solid(pos, Vector3(1.8, 4, 1.8))
		"t":
			_put("tree_single_A_cut", pos + Vector3(-0.6, 0, 0), _rng.randf() * TAU, PROP_SCALE)
			_put("resource_lumber", pos + Vector3(0.9, 0, 0.6), 0.4, PROP_SCALE * 0.8)
			_add_solid(pos, Vector3(2.6, 1.2, 2.6))
		"e":
			for i in 3:
				var prop: String = PROPS[_rng.randi() % PROPS.size()]
				_put(prop, pos + Vector3(-1.0 + i, 0, _rng.randf_range(-0.8, 0.8)), _rng.randf() * TAU, PROP_SCALE)
			_add_solid(pos, Vector3(3.2, 1.5, 2.6))
		"q":
			_put("building_well_yellow", pos, 0.0, 5.0)
			_add_solid(pos, Vector3(3.2, 2, 3.2))
			spots.well.append(pos + Vector3(0, 0, 2.6))
		"z":
			_build_fence(c, false)
		"a":
			_build_fence(c, true)
		"~":
			_add_solid(pos, Vector3(TILE, 1, TILE))
		"y":
			# Rows of pumpkins on dark soil, ready for the harvest.
			for row in 2:
				for col in 2:
					var kind: String = ["pumpkin_orange", "pumpkin_orange", "pumpkin_yellow_small"][_rng.randi() % 3]
					_put(kind, pos + Vector3(-1.0 + col * 2.0, 0, -1.0 + row * 2.0) + _jitter(0.3), _rng.randf() * TAU, _rng.randf_range(0.9, 1.3))
			_add_solid(pos, Vector3(TILE * 0.9, 1, TILE * 0.9))
		":":
			spots.square.append(pos)
		"F":
			_build_fountain(c)
			spots.well.append(pos + Vector3(0, 0, 2.6))
		"x":
			_build_bench(c)
		"v":
			_build_pedestal(c)
		"N":
			_build_tent(pos)
		"f":
			_build_campfire(pos)
		"C":
			_build_chest(c)
			# The robbers' hoard: richer than a chest in the dungeon.
			var loot_rng := RandomNumberGenerator.new()
			loot_rng.seed = hash("%s:hoard:%d:%d" % [level_name, c.x, c.y])
			interactables[-1].loot = {"gold": 20, "item": Items.random_item(loot_rng, 20)}
		_:
			if Enemy.WILD_LETTERS.has(ch):
				_wild.append({"cell": c, "kind": Enemy.WILD_LETTERS[ch], "enemy": null, "timer": 0.0, "wave": 0})
			elif Animal.LETTERS.has(ch):
				_animal_spots.append({"cell": c, "kind": Animal.LETTERS[ch]})


## A tall stone pedestal with a basket of bread, cheese and apples on top,
## and the crates to climb up to it lying close by.
func _build_pedestal(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.66, 0.63, 0.58)
	stone.roughness = 0.95
	_add_mesh_box(pos + Vector3(0, 0.15, 0), Vector3(1.7, 0.3, 1.7), stone)
	_add_mesh_box(pos + Vector3(0, PEDESTAL_HEIGHT * 0.5, 0), Vector3(1.25, PEDESTAL_HEIGHT - 0.5, 1.25), stone)
	_add_mesh_box(pos + Vector3(0, PEDESTAL_HEIGHT - 0.12, 0), Vector3(1.7, 0.24, 1.7), stone)
	_add_solid(pos, Vector3(1.7, PEDESTAL_HEIGHT, 1.7))
	# The basket: an open crate, filled with food that glints.
	var box := _aabb_of("crate_open")
	var s := 1.0 / maxf(0.01, maxf(box.size.x, box.size.z))
	var top := Vector3(pos.x, PEDESTAL_HEIGHT, pos.z)
	_put("crate_open", top - Vector3(box.get_center().x, box.position.y, box.get_center().z) * s, 0.0, s)
	var food := Node3D.new()
	food.position = top + Vector3(0, box.size.y * s * 0.8, 0)
	add_child(food)
	_add_food(food)
	food.add_child(Effects.make_sparkles(Color(1.0, 0.85, 0.45)))
	_basket = {"pos": top, "food": food, "full": true, "timer": 0.0, "hinted": false}
	for offset in PEDESTAL_CRATES:
		add_crate(pos + offset)


## A loaf, a wedge of cheese and a few apples, heaped in the basket.
func _add_food(parent: Node3D) -> void:
	var bread := StandardMaterial3D.new()
	bread.albedo_color = Color(0.72, 0.45, 0.2)
	var loaf := MeshInstance3D.new()
	var loaf_mesh := CapsuleMesh.new()
	loaf_mesh.radius = 0.16
	loaf_mesh.height = 0.6
	loaf.mesh = loaf_mesh
	loaf.material_override = bread
	loaf.rotation = Vector3(0, 0.5, PI * 0.5)
	loaf.position = Vector3(-0.1, 0.05, 0.05)
	parent.add_child(loaf)
	var cheese_mat := StandardMaterial3D.new()
	cheese_mat.albedo_color = Color(0.98, 0.8, 0.3)
	var cheese := MeshInstance3D.new()
	var wedge := CylinderMesh.new()
	wedge.top_radius = 0.2
	wedge.bottom_radius = 0.2
	wedge.height = 0.14
	wedge.radial_segments = 3
	cheese.mesh = wedge
	cheese.material_override = cheese_mat
	cheese.position = Vector3(0.2, 0.05, -0.15)
	parent.add_child(cheese)
	var apple_mat := StandardMaterial3D.new()
	apple_mat.albedo_color = Color(0.8, 0.1, 0.08)
	for spot in [Vector3(0.22, 0.08, 0.2), Vector3(0.05, 0.1, -0.25), Vector3(-0.28, 0.06, -0.18)]:
		var apple := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.1
		ball.height = 0.2
		apple.mesh = ball
		apple.material_override = apple_mat
		apple.position = spot
		parent.add_child(apple)


func _add_mesh_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


## The hero reaches the basket standing high enough beside it (on two
## stacked crates, or on the pedestal itself) and eats; it fills again
## after a while. Coming close on the ground tells them how to get up.
func _check_basket(delta: float) -> void:
	if _basket.is_empty() or not player is CharacterBody3D:
		return
	var food: Node3D = _basket.food
	if not _basket.full:
		_basket.timer -= delta
		if _basket.timer <= 0.0:
			_basket.full = true
			food.visible = true
		return
	var d := _flat_distance(player.global_position, _basket.pos)
	var hero := player as CharacterBody3D
	var climbing: bool = hero.has_method("is_climbing") and hero.is_climbing()
	if d <= BASKET_REACH and not climbing and hero.is_on_floor() and hero.global_position.y >= BASKET_FEET:
		_basket.full = false
		_basket.timer = BASKET_REFILL
		food.visible = false
		food_basket.emit(BASKET_HEAL)
	elif d <= 6.0 and not _basket.hinted and hero.global_position.y < 0.5:
		_basket.hinted = true
		notice.emit(Lang.t("Ganz oben auf dem Sockel steht ein Korb voller Essen. Staple zwei Kisten daneben, um ihn zu erreichen (E: Kiste aufheben, Q: abstellen)."), 5.0)


## A bandit's tent, its opening turned to the south, the camp's size.
func _build_tent(pos: Vector3) -> void:
	var box := _aabb_of("tent")
	var s := 3.4 / maxf(box.size.x, box.size.z)
	_put("tent", pos + _jitter(0.2), _rng.randf_range(-0.2, 0.2), s)
	_add_solid(pos, Vector3(3.2, 2.5, 3.2))


## Logs burning in a ring of stones, with a warm light over the camp.
func _build_campfire(pos: Vector3) -> void:
	_put("resource_lumber", pos + Vector3(0, 0, 0), 0.4, PROP_SCALE * 0.55)
	_put("resource_lumber", pos + Vector3(0, 0.25, 0), 1.9, PROP_SCALE * 0.55)
	for i in 6:
		var angle := i * TAU / 6.0 + _rng.randf_range(-0.2, 0.2)
		_put(["rock_single_A", "rock_single_C", "rock_single_E"][_rng.randi() % 3], pos + Vector3(cos(angle), 0, sin(angle)) * 1.3, _rng.randf() * TAU, _rng.randf_range(1.8, 2.4))
	var flame := Effects.make_flame()
	flame.position = pos + Vector3(0, 0.5, 0)
	flame.scale = Vector3.ONE * 2.6
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.28)
	light.light_energy = 3.5
	light.omni_range = 12.0
	light.omni_attenuation = 1.4
	light.position = pos + Vector3(0, 2.0, 0)
	add_child(light)
	_fires.append(pos)
	_add_solid(pos, Vector3(2.2, 1.5, 2.2))


## A bench on the square, its seat turned to the fountain.
func _build_bench(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var to := Vector3.ZERO
	for y in height:
		for x in width:
			if cell_char(Vector2i(x, y)) == "F":
				to = cell_to_world(Vector2i(x, y)) - pos
	var rot := atan2(to.x, to.z) if to.length() > 0.1 else 0.0
	_put("bench", pos, rot, 1.3)
	_add_solid(pos, Vector3(2.4, 1, 2.4))


## A post with a lantern hanging from its arm, glowing warm.
func _build_lantern(pos: Vector3) -> void:
	_put("post_lantern", pos, 0.0, 1.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = 2.2
	light.omni_range = 11.0
	light.position = pos + Vector3(0, 2.6, 1.1)
	add_child(light)
	_lamps.append(light)
	# A candle in the lantern that glows once the light fades.
	if _candle_mat == null:
		_candle_mat = StandardMaterial3D.new()
		_candle_mat.albedo_color = Color(1.0, 0.8, 0.5)
		_candle_mat.emission_enabled = true
		_candle_mat.emission = Color(1.0, 0.7, 0.35)
		_candle_mat.emission_energy_multiplier = 0.0
	var candle := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.15
	ball.height = 0.3
	candle.mesh = ball
	candle.material_override = _candle_mat
	candle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	candle.position = pos + Vector3(0, 2.05, 1.0)
	candle.visible = false
	add_child(candle)
	_candles.append(candle)
	_add_solid(pos, Vector3(0.7, 3, 0.7))


## A leafy tree, or near the graveyard an autumn pine or a bare one.
func _build_tree(pos: Vector3, single := false) -> void:
	var near_crypt := pos.distance_to(cell_to_world(start_cell)) < 13.0 * TILE
	var roll := _rng.randf()
	var rot := _rng.randf() * TAU
	var at := pos + _jitter(0.9 if not single else 0.3)
	if near_crypt and roll < 0.45:
		_plant(["tree_dead_large", "tree_dead_medium"][_rng.randi() % 2], at, rot, _rng.randf_range(1.2, 1.6))
	elif roll < 0.35 or (near_crypt and roll < 0.8):
		_plant(["tree_pine_orange_large", "tree_pine_yellow_large", "tree_pine_orange_medium", "tree_pine_yellow_medium"][_rng.randi() % 4], at, rot, _rng.randf_range(0.9, 1.25))
	elif roll < 0.75 or single:
		_plant(["tree_single_A", "tree_single_B"][_rng.randi() % 2], at, rot, _rng.randf_range(5.5, 7.5))
	else:
		_plant(["trees_A_medium", "trees_B_medium"][_rng.randi() % 2], at, rot, _rng.randf_range(3.0, 3.8))


## Trees on every forest tile close to the open ground. Further in there
## is only the dark forest floor, which the camera never gets to see much of.
func _build_forest() -> void:
	for y in range(-2, height + 2):
		for x in range(-2, width + 2):
			var c := Vector2i(x, y)
			if cell_char(c) != "#":
				continue
			var depth := _forest_depth(c)
			if depth > FOREST_DEPTH:
				continue
			if _rng.randf() < [1.0, 1.0, 0.9, 0.75, 0.6][depth]:
				_build_tree(cell_to_world(c))


## How many tiles from the nearest open ground (up to FOREST_DEPTH + 1).
func _forest_depth(c: Vector2i) -> int:
	for r in range(1, FOREST_DEPTH + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and cell_char(c + Vector2i(dx, dy)) != "#" \
						and c.x + dx >= 0 and c.y + dy >= 0 and c.x + dx < width and c.y + dy < height:
					return r
	return FOREST_DEPTH + 1


## An iron graveyard fence, running along its neighbours; a gate is an arch.
func _build_fence(c: Vector2i, gate: bool) -> void:
	var pos := cell_to_world(c)
	var across := "zaR".contains(cell_char(c + Vector2i(1, 0))) or "zaR".contains(cell_char(c + Vector2i(-1, 0)))
	var rot := 0.0 if across else PI * 0.5
	var along := Vector3(1, 0, 0) if across else Vector3(0, 0, 1)
	if gate:
		_put("arch_gate", pos, rot)
		_add_solid(pos + along * 1.9, Vector3(0.5, 4, 0.5))
		_add_solid(pos - along * 1.9, Vector3(0.5, 4, 0.5))
		return
	_put("fence" if _rng.randf() < 0.85 else "fence_broken", pos, rot)
	for end in [-1, 1]:
		var key := "pillar_%d_%d" % [roundi((pos.x + along.x * 2 * end) * 10), roundi((pos.z + along.z * 2 * end) * 10)]
		if not _scenes.has(key):
			_scenes[key] = true
			_put("fence_pillar", pos + along * 2.0 * end, rot)
	_add_solid(pos, Vector3(4, 2.2, 0.5) if across else Vector3(0.5, 2.2, 4))


# --- Buildings ----------------------------------------------------------------

## Each block of building tiles gets one building, scaled to fill it.
func _build_blocks() -> void:
	var seen := {}
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if not BLOCK_CHARS.contains(ch) or seen.has(c):
				continue
			var block := Rect2i(c, Vector2i.ONE)
			while cell_char(Vector2i(block.end.x, y)) == ch:
				block.size.x += 1
			while cell_char(Vector2i(x, block.end.y)) == ch:
				block.size.y += 1
			for by in range(block.position.y, block.end.y):
				for bx in range(block.position.x, block.end.x):
					seen[Vector2i(bx, by)] = true
			_build_block(ch, block)


func _build_block(ch: String, block: Rect2i) -> void:
	if ch == "E":
		_build_lair_entrance(block)
		return
	if ch == "%":
		_build_terrace(block)
		return
	var facing := _block_facing(block) if ch != "R" else Vector2i(0, 1)
	var rot := atan2(float(facing.x), float(facing.y))
	var turned := facing.x != 0
	var room := Vector2(block.size) * TILE * 0.92
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	var node: Node3D
	if ch == "s":
		node = _build_chapel(center, rot, room if not turned else Vector2(room.y, room.x))
	elif ch == "h":
		node = VillageHouse.build(room if not turned else Vector2(room.y, room.x), _rng, _house_glass())
		node.position = center
		node.rotation.y = rot
		add_child(node)
	else:
		var model: String = BLOCK_MODELS[ch]
		var box := _aabb_of(model)
		var model_size := Vector2(box.size.z, box.size.x) if turned else Vector2(box.size.x, box.size.z)
		var s := minf(room.x / model_size.x, room.y / model_size.y)
		var foot := (Vector3(box.position.x + box.size.x * 0.5, 0, box.position.z + box.size.z * 0.5) * s).rotated(Vector3.UP, rot)
		node = _put(model, center - foot, rot, s)
		if ch != "R":
			_light_windows(node)
	var solid := Vector3(block.size.x * TILE * 0.86, 4, block.size.y * TILE * 0.86)
	_add_solid(center, solid)
	var reach := Vector2(block.size) * TILE * 0.5 + Vector2(2.0, 2.0)
	var front := center + Vector3(facing.x * reach.x, 0, facing.y * reach.y)
	doors[ch] = front
	if interiors.has(ch):
		# Run into the door to go in.
		var door := center + Vector3(facing.x * (reach.x - 2.0), 0, facing.y * (reach.y - 2.0))
		stations.append({"kind": "eingang", "building": ch, "name": BUILDING_NAMES.get(ch, ""),
				"cell": world_to_cell(door - Vector3(facing.x, 0, facing.y) * 0.5), "pos": door, "used": false})
	if ch == "h":
		spots.houses.append(front)
	elif ch == "R":
		# A faint cold glow in the crypt door the hero came out of.
		var light := OmniLight3D.new()
		light.light_color = Color(0.6, 0.75, 1.0)
		light.light_energy = 1.4
		light.omni_range = 6.0
		light.position = center + Vector3(0, 2.0, block.size.y * TILE * 0.5 - 1.0)
		add_child(light)
		var motes := Effects.make_sparkles(Color(0.7, 0.85, 1.0))
		motes.position = center + Vector3(0, 2.0, block.size.y * TILE * 0.5 - 0.5)
		add_child(motes)
	elif ch in ["n", "m", "j", "s", "k", "o", "w", "b"]:
		spots.square.append(front)
	if ch == "w":
		# Banners and a rack of weapons by the guild door.
		var side := Vector3(-facing.y, 0, facing.x) * 2.2
		_put("weaponrack", front + side - Vector3(facing.x, 0, facing.y) * 0.8, rot, PROP_SCALE)
		_put("flag_red", front - side - Vector3(facing.x, 0, facing.y) * 0.8, rot, PROP_SCALE)
	elif ch == "k":
		var side := Vector3(-facing.y, 0, facing.x) * 4.0
		for flag in [-1, 1]:
			_put("flag_blue", front + side * flag - Vector3(facing.x, 0, facing.y) * 1.2, rot, PROP_SCALE)
	elif ch == "o":
		# Parcels waiting at the post office.
		var side := Vector3(-facing.y, 0, facing.x) * 2.4
		_put("crate_long_A", front + side - Vector3(facing.x, 0, facing.y) * 1.0, rot, PROP_SCALE)
		_put("crate_open", front - side - Vector3(facing.x, 0, facing.y) * 1.0, rot + 0.3, PROP_SCALE)
	node.set_meta("block", block)


## Weavers' Lane: the block is split into one narrow town house per tile
## along its front, wall to wall, each with its own number, door and colours.
## Every door leads into the hero homes' building floor (see Homes).
func _build_terrace(block: Rect2i) -> void:
	var facing := _block_facing(block)
	var rot := atan2(float(facing.x), float(facing.y))
	var across := Vector2i(absi(facing.y), absi(facing.x))
	var count := block.size.x if across.x != 0 else block.size.y
	var deep := block.size.y if across.x != 0 else block.size.x
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	# Numbered from west to east (or north to south).
	var step := Vector3(across.x, 0, across.y) * TILE
	var first := center - step * (count - 1) * 0.5
	var out := Vector3(facing.x, 0, facing.y)
	for i in count:
		var number := i + 1
		var at := first + step * i
		var house := VillageHouse.build_narrow(Vector2(TILE, deep * TILE * 0.92), number, _rng, _house_glass())
		house.position = at
		house.rotation.y = rot
		house.set_meta("block", block)
		add_child(house)
		town_houses.append(house)
		var door := at + Vector3(float(house.get_meta("door_x")), 0, 0).rotated(Vector3.UP, rot) + out * deep * TILE * 0.5
		doors["%" + str(number)] = door + out * 2.0
		if interiors.has("%"):
			stations.append({"kind": "eingang", "building": "%", "house": number, "reach": 1.6,
					"name": Lang.t("das Haus Nr. %d") % number,
					"cell": world_to_cell(door - out * 0.5), "pos": door, "used": false})
	_add_solid(center, Vector3(block.size.x * TILE, 4, block.size.y * TILE) * Vector3(1.0 if across.x != 0 else 0.86, 1, 1.0 if across.y != 0 else 0.86))


## The way down into the dragon's lair: an old stone arch from Quaternius'
## dungeon kit with its door hanging open, a black hole and stairs going down
## behind it, columns either side, skulls in the grass and a red glow from
## below. Run into the arch to go down.
func _build_lair_entrance(block: Rect2i) -> void:
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	var depth := block.size.y * TILE * 0.5
	var front := center + Vector3(0, 0, depth - 0.6)
	var arch := _put("lair/Arch", front, 0.0, 1.0)
	# The door swung open against the arch's side.
	_put("lair/Arch_Door", front + Vector3(-1.2, 0, 0.2), -PI * 0.55, 1.0)
	# Darkness in the opening, and the top steps sinking into it.
	var hole := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.3)
	hole.mesh = quad
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.02, 0.01, 0.015)
	hole.material_override = black
	hole.position = front + Vector3(0, 1.65, -0.35)
	add_child(hole)
	for i in 2:
		_put("lair/Stairs_Modular", front + Vector3(0, -0.55 - i * 0.9, 0.55 - i * 0.9), PI, 1.3)
	for side in [-1.0, 1.0]:
		_put("lair/Column2", front + Vector3(side * 2.9, 0, -0.1), 0.0, 0.9)
		_put("lair/Skull", front + Vector3(side * 2.2 + _rng.randf_range(-0.4, 0.4), 0, 1.6 + _rng.randf_range(0.0, 0.8)), _rng.randf() * TAU, 0.8)
	# A heap of rubble and earth over the vault behind the arch.
	_put("rock_single_A", center + Vector3(-2.2, 0, -1.0), 0.6, 3.0)
	_put("rock_single_C", center + Vector3(2.4, 0, -1.4), 2.2, 3.0)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.35, 0.15)
	glow.light_energy = 1.8
	glow.omni_range = 7.0
	glow.position = front + Vector3(0, 1.2, -0.8)
	add_child(glow)
	_add_solid(center, Vector3(block.size.x * TILE * 0.86, 4, block.size.y * TILE * 0.86))
	arch.set_meta("block", block)
	doors["E"] = front + Vector3(0, 0, 2.0)
	if interiors.has("E"):
		stations.append({"kind": "eingang", "building": "E", "name": BUILDING_NAMES.E,
				"cell": world_to_cell(front - Vector3(0, 0, 0.5)), "pos": front + Vector3(0, 0, 0.6), "used": false})


## The temple is a small stone chapel put together from the pieces of the
## Modular Cathedral Kit: a nave with tall windows down both sides, a rose
## window at the back, a pointed doorway with steps at the front, a tiled
## roof and a spire over the door. Its stained glass glows at night.
func _build_chapel(center: Vector3, rot: float, room: Vector2) -> Node3D:
	var chapel := Node3D.new()
	chapel.name = "Chapel"
	for part: Array in CHAPEL_PARTS:
		var piece: Node3D = load(CHAPEL_DIR + part[0] + ".fbx").instantiate()
		piece.position = part[1]
		piece.rotation.y = deg_to_rad(part[2])
		chapel.add_child(piece)
	for z in [CHAPEL_HALF.y - 1.0, -CHAPEL_HALF.y]:
		var gable := MeshInstance3D.new()
		gable.mesh = _chapel_gable()
		gable.position = Vector3(0, CHAPEL_EAVES, z)
		chapel.add_child(gable)
	_skin_chapel(chapel)
	# The kit is built to cathedral scale: shrink it to fit the block, and
	# move it so that the steps in front of the door stay inside it too.
	var s := minf(room.x / CHAPEL_FOOT.x, room.y / CHAPEL_FOOT.y)
	chapel.scale = Vector3.ONE * s
	chapel.rotation.y = rot
	chapel.position = center - (Vector3(0, 0, CHAPEL_FOOT_MID) * s).rotated(Vector3.UP, rot)
	add_child(chapel)
	return chapel


## Gives the chapel pieces the kit's textures: stone and bricks from the trim
## sheet, stained glass that can glow, and the wooden door.
func _skin_chapel(chapel: Node) -> void:
	if not _scenes.has("mat_chapel_trim"):
		var trim := StandardMaterial3D.new()
		trim.albedo_texture = load(CHAPEL_DIR + "trim_sheet.png")
		trim.roughness = 0.9
		var glass := StandardMaterial3D.new()
		glass.albedo_texture = load(CHAPEL_DIR + "window_diffuse.png")
		glass.emission_enabled = true
		# The stained glass itself glows, in its own colours (multiplied,
		# so the tint does not wash the panes out to white).
		glass.emission = Color(1.0, 0.92, 0.8)
		glass.emission_texture = load(CHAPEL_DIR + "window_diffuse.png")
		glass.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		glass.emission_energy_multiplier = 0.0
		var wood := StandardMaterial3D.new()
		wood.albedo_texture = load(CHAPEL_DIR + "door_diffuse.png")
		wood.roughness = 0.85
		_scenes["mat_chapel_trim"] = trim
		_scenes["mat_chapel_glass"] = glass
		_scenes["mat_chapel_wood"] = wood
		# The windows light up with the houses' at night (see set_hour).
		_window_mats[glass] = glass
	for mi: MeshInstance3D in chapel.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			var kind: String = mat.resource_name if mat else ""
			var key := "mat_chapel_trim"
			if kind.begins_with("window"):
				key = "mat_chapel_glass"
			elif kind == "door":
				key = "mat_chapel_wood"
			mi.set_surface_override_material(i, _scenes[key])


## The window panes of the villagers' houses: dark by day, warm at night
## (see set_hour).
func _house_glass() -> StandardMaterial3D:
	if not _scenes.has("mat_house_glass"):
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.16, 0.18, 0.22)
		glass.roughness = 0.25
		glass.emission_enabled = true
		glass.emission = WINDOW_LIGHT
		glass.emission_energy_multiplier = 0.0
		_scenes["mat_house_glass"] = glass
		_window_mats[glass] = glass
	return _scenes["mat_house_glass"]


## The kit's roof is open at both ends: a brick gable closes each one. It is
## built in strips so that each strip shows one band of the trim sheet's
## bricks, like the walls below.
func _chapel_gable() -> Mesh:
	if _scenes.has("mesh_chapel_gable"):
		return _scenes["mesh_chapel_gable"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strips := 4
	var strip := CHAPEL_GABLE_HEIGHT / strips
	for i in strips:
		var y0 := i * strip
		var y1 := y0 + strip
		var w0 := CHAPEL_HALF.x * (1.0 - y0 / CHAPEL_GABLE_HEIGHT)
		var w1 := CHAPEL_HALF.x * (1.0 - y1 / CHAPEL_GABLE_HEIGHT)
		var v0 := GABLE_BRICK_V.y
		var v1 := GABLE_BRICK_V.y - (GABLE_BRICK_V.y - GABLE_BRICK_V.x) * strip / 4.0
		for side in [1.0, 0.0]:
			# Both faces of the gable, each turned outwards.
			var n := Vector3(0, 0, 1.0 if side > 0.5 else -1.0)
			var quad := [Vector3(-w0, y0, side), Vector3(w0, y0, side), Vector3(w1, y1, side), Vector3(-w1, y1, side)]
			var uvs := [Vector2(-w0 / 8.0, v0), Vector2(w0 / 8.0, v0), Vector2(w1 / 8.0, v1), Vector2(-w1 / 8.0, v1)]
			var order := [0, 1, 2, 0, 2, 3] if side > 0.5 else [0, 2, 1, 0, 3, 2]
			for k in order:
				st.set_normal(n)
				st.set_uv(uvs[k])
				st.add_vertex(quad[k])
	var mesh := st.commit()
	_scenes["mesh_chapel_gable"] = mesh
	return mesh


## Gives a building windows that can glow: its kit material is swapped for
## a copy with an emission mask over the window panes (dark by day).
func _light_windows(node: Node) -> void:
	if _window_mask == null:
		# Image.create starts black: only the window patch shines.
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		var at := Vector2i(WINDOW_UV * 256.0)
		img.fill_rect(Rect2i(at - Vector2i(3, 3), Vector2i(7, 7)), Color.WHITE)
		_window_mask = ImageTexture.create_from_image(img)
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.get_active_material(0)
		if not mat is StandardMaterial3D:
			continue
		if not _window_mats.has(mat):
			var lit: StandardMaterial3D = mat.duplicate()
			lit.emission_enabled = true
			lit.emission = WINDOW_LIGHT
			lit.emission_texture = _window_mask
			# Multiply, not the default add: with "add" the emission colour
			# shines over the whole building and the mask only adds to it,
			# so every house glowed white at night.
			lit.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			lit.emission_energy_multiplier = 0.0
			_window_mats[mat] = lit
		mi.material_override = _window_mats[mat]


## Which way a building's door looks: towards the square if it borders it,
## else towards a path, else south.
func _block_facing(block: Rect2i) -> Vector2i:
	var best := Vector2i(0, 1)
	var best_score := 0
	for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var score := 0
		for y in range(block.position.y, block.end.y):
			for x in range(block.position.x, block.end.x):
				var n := Vector2i(x, y) + d
				if block.has_point(n):
					continue
				if cell_char(n) == ":":
					score += 3
				elif cell_char(n) == ",":
					score += 1
		# Doors facing away from the camera are only taken for the square.
		if d.y < 0:
			score = score - 1 if score >= 3 else 0
		if score > best_score:
			best_score = score
			best = d
	return best


# --- The hero's house ---------------------------------------------------------

## Stone walls from the dungeon kit around a wooden floor, under a tiled
## roof. Inside, the roof lifts off and the south wall drops low, like the
## walls in the dungeon, so the camera can look in.
func _build_house() -> void:
	_house_rect = _bounds_of("I")
	if _house_rect.size == Vector2i.ZERO:
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/house/wood_floor.jpg")
	wood.uv1_scale = Vector3(2, 2, 2)
	wood.roughness = 0.85
	var plank := PlaneMesh.new()
	plank.size = Vector2(TILE, TILE)
	for y in range(_house_rect.position.y, _house_rect.end.y):
		for x in range(_house_rect.position.x, _house_rect.end.x):
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if ch == "I":
				_add_box(_walls_body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(TILE, 4, TILE))
				continue
			var floor_piece := MeshInstance3D.new()
			floor_piece.mesh = plank
			floor_piece.material_override = wood
			floor_piece.position = cell_to_world(c) + Vector3(0, 0.03, 0)
			add_child(floor_piece)
			if y == _house_rect.end.y - 1:
				_door_cell = c
			_build_house_walls(c)
			if ch == "B":
				_place("bed_decorated", cell_to_world(c), 0.0)
				_add_solid(cell_to_world(c), Vector3(3.2, 1.5, 3.2))
				stations.append({"kind": "bett", "cell": c, "pos": cell_to_world(c), "rot": 0.0, "used": false})
				home_spot = cell_to_world(c + Vector2i(0, 1))
			elif ch == "L":
				_place("chest", cell_to_world(c), 0.0)
				_add_solid(cell_to_world(c), Vector3(2.4, 1.5, 2.4))
				stations.append({"kind": "lager", "cell": c, "pos": cell_to_world(c), "used": false})
	_build_house_pillars()
	_build_roof()


func _build_house_walls(c: Vector2i) -> void:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if cell_char(c + d) != "I":
			continue
		var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * TILE * 0.5
		var wall := _place("wall", pos, atan2(-float(d.x), -float(d.y)))
		if (c.x + c.y + d.x + d.y) % 2 != 0:
			wall.position.y += 0.02
		# Seen from outside, the inner face of the kit wall would show its
		# back: a second wall faces out.
		var outer := _place("wall", pos + Vector3(d.x, 0, d.y) * 0.02, atan2(float(d.x), float(d.y)))
		if d == Vector2i(0, 1) or c == _door_cell:
			_south_walls.append(wall)
			_south_walls.append(outer)


func _build_house_pillars() -> void:
	for vy in range(_house_rect.position.y + 1, _house_rect.end.y):
		for vx in range(_house_rect.position.x + 1, _house_rect.end.x):
			var cells := [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]
			var walls := cells.filter(func(cc): return cell_char(cc) == "I").size()
			if walls == 1 or walls == 3:
				var pillar := _place("pillar", Vector3(vx * TILE - TILE * 0.5, 0, vy * TILE - TILE * 0.5))
				if vy == _house_rect.end.y - 1:
					_south_walls.append(pillar)


func _build_roof() -> void:
	var w := (_house_rect.size.x - 1) * TILE + 1.6
	var d := (_house_rect.size.y - 1) * TILE + 1.6
	var tiles := StandardMaterial3D.new()
	tiles.albedo_texture = load("res://assets/house/roof_tiles.jpg")
	tiles.uv1_scale = Vector3(4.0, 3.0, 1)
	tiles.albedo_color = Color(0.85, 0.68, 0.6)
	tiles.roughness = 0.8
	var gable_mat := StandardMaterial3D.new()
	gable_mat.albedo_color = Color(0.36, 0.25, 0.17)
	gable_mat.roughness = 0.9
	_roof = Node3D.new()
	var center := cell_to_world(_house_rect.position) + Vector3(_house_rect.size.x - 1, 0, _house_rect.size.y - 1) * TILE * 0.5
	_roof.position = center + Vector3(0, WALL_HEIGHT, 0)
	add_child(_roof)
	# Two tiled slopes, the ridge running east to west, facing the camera.
	var slope := atan2(HOUSE_ROOF_HEIGHT, d * 0.5)
	var length := Vector2(d * 0.5, HOUSE_ROOF_HEIGHT).length() + 0.3
	for side in [1, -1]:
		var slab := BoxMesh.new()
		slab.size = Vector3(w, 0.3, length)
		var piece := MeshInstance3D.new()
		piece.mesh = slab
		piece.material_override = tiles
		piece.rotation.x = slope * side
		piece.position = Vector3(0, HOUSE_ROOF_HEIGHT * 0.5, d * 0.25 * side)
		_roof.add_child(piece)
	# Wooden gables close the ends.
	for side in [1, -1]:
		var gable := PrismMesh.new()
		gable.size = Vector3(d - 0.4, HOUSE_ROOF_HEIGHT - 0.1, 0.3)
		var piece := MeshInstance3D.new()
		piece.mesh = gable
		piece.material_override = gable_mat
		piece.rotation.y = PI * 0.5
		piece.position = Vector3((w * 0.5 - 0.7) * side, HOUSE_ROOF_HEIGHT * 0.5, 0)
		_roof.add_child(piece)
	# A chimney.
	var stack := BoxMesh.new()
	stack.size = Vector3(1.0, 2.4, 1.0)
	var chimney := MeshInstance3D.new()
	chimney.mesh = stack
	chimney.material_override = _kit_material("walls")
	chimney.position = Vector3(w * 0.25, HOUSE_ROOF_HEIGHT * 0.75, -d * 0.12)
	_roof.add_child(chimney)


func _in_house(c: Vector2i) -> bool:
	return _house_rect.has_point(c) and cell_char(c) != "I"


## A golden glow over the door of the hero's new house.
func _show_house_marker() -> void:
	if _door_cell.x < 0 or _marker != null:
		return
	_marker = Node3D.new()
	_marker.position = cell_to_world(_door_cell) + Vector3(0, 0, 1.0)
	add_child(_marker)
	var motes := Effects.make_sparkles(Color(1.0, 0.85, 0.4))
	motes.position.y = 2.0
	_marker.add_child(motes)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position.y = 3.0
	_marker.add_child(light)


## A saved game wakes up in the house the elder gave.
func wake_at_home() -> void:
	house_given = true
	_entered_once = true


# --- Villagers ----------------------------------------------------------------

func _spawn_villagers() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if not VILLAGERS.contains(ch):
				continue
			var v := Villager.new()
			v.setup(self, ch, c)
			add_child(v)
			v.global_position = cell_to_world(c)
			villagers.append(v)
			# The shopkeeper trades like the merchant in the refuge; the
			# banker and the barber open their own menus.
			var kind: String = {"6": "haendler", "Y": "bank", "Z": "barbier", "S": "steinmetz", "1": "schmied"}.get(ch, "npc")
			var station := {"kind": kind, "cell": c, "pos": cell_to_world(c), "used": false, "npc": v}
			v.station = station
			stations.append(station)
			if ch == "0":
				_elder = v
			elif ch == "K":
				_herald = v
			elif ch == "Z":
				_build_barber_shop(c + Vector2i(0, -1))
			elif ch == "S":
				_build_stone_yard(c + Vector2i(0, -1))
			elif ch == "1":
				_build_forge(c + Vector2i(-1, 0))


## The barber's stall on the tile behind him: a market tent with a striped
## barber's pole and a hanging sign with scissors at its front, so the shop
## is easy to spot on the square.
func _build_barber_shop(cell: Vector2i) -> void:
	var pos := cell_to_world(cell)
	var box := _aabb_of("tent")
	_put("tent", pos, 0.0, 3.6 / maxf(box.size.x, box.size.z))
	_add_solid(pos, Vector3(3.4, 2.6, 3.4))
	astar.set_point_solid(cell, true)
	var pole := Effects.barber_pole()
	pole.position = pos + Vector3(-2.0, 0, 1.9)
	add_child(pole)
	var board := Effects.shop_sign(Lang.t("Barbier"), preload("res://assets/fonts/Cinzel-Bold.woff2"))
	board.position = pos + Vector3(1.4, 0, 1.9)
	add_child(board)
	_add_solid(pos + Vector3(-2.0, 0, 1.9), Vector3(0.5, 2.6, 0.5))
	_add_solid(pos + Vector3(1.4, 0, 1.9), Vector3(0.5, 2.6, 0.5))


## The stonemason's yard on the tile behind him: blocks of carved stone
## stacked up for sale, a rough block on the trestle and a sign.
func _build_stone_yard(cell: Vector2i) -> void:
	var pos := cell_to_world(cell)
	# [offset of the block's bottom middle, turned to lie along z, shade]
	var heap := [
		[Vector3(-0.9, 0, -0.6), false, 0], [Vector3(0.75, 0, -0.6), false, 1],
		[Vector3(-0.05, StoneBlock.HEIGHT, -0.6), false, 2], [Vector3(-0.9, 0, 0.6), false, 3],
		[Vector3(0.75, 0, 0.6), false, 0],
	]
	for part in heap:
		var block := StoneBlock.make_model(StoneBlock.SHADES[part[2]])
		block.position = pos + part[0]
		block.rotation.y = PI * 0.5 if part[1] else _rng.randf_range(-0.05, 0.05)
		add_child(block)
	_add_solid(pos + Vector3(0.2, 0, 0), Vector3(3.4, StoneBlock.HEIGHT * 2.0, 2.6))
	astar.set_point_solid(cell, true)
	var board := Effects.shop_sign(Lang.t("Steinmetz"), preload("res://assets/fonts/Cinzel-Bold.woff2"))
	board.position = pos + Vector3(-1.6, 0, 1.9)
	add_child(board)
	_add_solid(pos + Vector3(-1.6, 0, 1.9), Vector3(0.5, 2.6, 0.5))


## The smith's forge on the tile beside him: a stone hearth with glowing
## coals and a warm light, an anvil on a tree stump, and a sign.
func _build_forge(cell: Vector2i) -> void:
	var pos := cell_to_world(cell)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.4, 0.38)
	stone.roughness = 0.95
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.2, 0.22)
	iron.metallic = 0.7
	iron.roughness = 0.45
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.27, 0.16)
	wood.roughness = 0.9
	var coals := StandardMaterial3D.new()
	coals.albedo_color = Color(0.3, 0.06, 0.02)
	coals.emission_enabled = true
	coals.emission = Color(1.0, 0.35, 0.08)
	coals.emission_energy_multiplier = 1.5
	# The hearth: a low stone block with glowing coals on top and a chimney.
	var hearth := pos + Vector3(-0.5, 0, -0.7)
	_add_mesh_box(hearth + Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 1.5), stone)
	_add_mesh_box(hearth + Vector3(0, 0.93, 0), Vector3(1.5, 0.08, 1.0), coals)
	_add_mesh_box(hearth + Vector3(0, 2.0, -0.55), Vector3(0.8, 2.2, 0.5), stone)
	var flame := Effects.make_flame()
	flame.position = hearth + Vector3(0, 1.0, 0)
	flame.scale = Vector3.ONE * 2.0
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.omni_attenuation = 1.4
	light.position = hearth + Vector3(0, 1.8, 0.4)
	add_child(light)
	# The anvil on its stump, in front of the hearth.
	var anvil := pos + Vector3(0.8, 0, 0.8)
	_add_mesh_box(anvil + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), wood)
	_add_mesh_box(anvil + Vector3(0, 0.68, 0), Vector3(0.3, 0.16, 0.28), iron)
	_add_mesh_box(anvil + Vector3(0, 0.85, 0), Vector3(0.85, 0.2, 0.36), iron)
	_add_mesh_box(anvil + Vector3(0.52, 0.88, 0), Vector3(0.22, 0.12, 0.2), iron)
	_add_solid(pos, Vector3(3.2, 1.2, 3.0))
	astar.set_point_solid(cell, true)
	var board := Effects.shop_sign(Lang.t("Schmiede"), preload("res://assets/fonts/Cinzel-Bold.woff2"))
	board.position = pos + Vector3(-1.5, 0, 1.6)
	add_child(board)
	_add_solid(pos + Vector3(-1.5, 0, 1.6), Vector3(0.5, 2.6, 0.5))


# --- Bandits ------------------------------------------------------------------

## The bandits of the pass take their spots when the world is built.
func _spawn_wild() -> void:
	for s in _wild:
		if s.kind == "hauptmann" and chief_defeated():
			# He fell in this game already. If his blade was left lying
			# there, it still waits where he fell.
			s.timer = INF
			if not taken.has(BanditChief.TROPHY):
				_drop_item(BanditChief.TROPHY, cell_to_world(s.cell))
			continue
		_spawn_bandit(s)


## Whether the bandit chief has fallen in this saved game.
## Lets the does, stags and foxes out onto their meadows.
func _spawn_animals() -> void:
	for s in _animal_spots:
		var a := Animal.new()
		a.setup(self, s.kind, s.cell)
		add_child(a)
		a.global_position = cell_to_world(s.cell)
		animals.append(a)


func chief_defeated() -> bool:
	return taken.has(CHIEF_DEFEATED)


## Puts a bandit (or a beast) on its spot. When it falls it leaves gold and
## maybe a piece of its gear, and after a while another comes to take its
## place. Beasts carry what their kind says (see "purse" and "gear_chance"
## in Enemy.KINDS): a wolf hardly anything, an orc or the yeti more.
func _spawn_bandit(s: Dictionary) -> void:
	var stats: Dictionary = Enemy.KINDS[s.kind]
	var is_chief: bool = s.kind == "hauptmann"
	var gear_chance: float = stats.get("gear_chance", CHIEF_GEAR_CHANCE if is_chief else BANDIT_GEAR_CHANCE)
	var purse: Array = stats.get("purse", [CHIEF_GOLD, CHIEF_GOLD] if is_chief else [1, 3])
	var e: Enemy = BanditChief.new() if is_chief else Enemy.new()
	e.kind = s.kind
	e.gear = _roll_gear(e.kind, s.cell, gear_chance, s.wave) if gear_chance > 0.0 else ([] as Array[String])
	# Bandits who come out at night are tougher (see Enemy.night).
	e.night = night
	e.level = self
	add_child(e)
	e.global_position = cell_to_world(s.cell)
	e.died.connect(func():
		enemy_killed.emit(e)
		_drop_gear(e, CHIEF_DROP_CHANCE if is_chief else BANDIT_DROP_CHANCE)
		_drop_coins(e.global_position, randi_range(purse[0], purse[1]))
		s.enemy = null
		s.timer = BANDIT_RESPAWN * (NIGHT_RESPAWN_FACTOR if night else 1.0)
		if is_chief:
			_on_chief_fallen(e))
	if is_chief:
		chief = e
		boss_bar = BossBar.new(e)
		add_child(boss_bar)
	s.enemy = e
	s.wave += 1
	enemies = enemies.filter(func(x): return is_instance_valid(x))
	enemies.append(e)


## The chief falls for good: remembered in the saved game, and his own
## blade drops where he fell.
func _on_chief_fallen(e: BanditChief) -> void:
	taken[CHIEF_DEFEATED] = true
	for s in _wild:
		if s.kind == "hauptmann":
			s.timer = INF
	chief = null
	_drop_item(BanditChief.TROPHY, e.global_position + Vector3(0.8, 0, 0.8))
	Sfx.play_gear(self, BanditChief.TROPHY, 0.4, e.global_position)
	notice.emit(Lang.t("Rabenherz ist besiegt! Seine Klinge gehört dir."), 5.0)


## The chief calls his cutthroats: they come running from around the camp,
## from the side away from the hero, and join the fight at once. No more
## than `count` of them at a time.
func call_reinforcements(from: Enemy, count: int) -> void:
	_called = _called.filter(func(x): return is_instance_valid(x) and not x.dead)
	var home := world_to_cell(from.global_position)
	var hero := player.global_position if player else from.global_position
	var cells: Array[Vector2i] = []
	for y in range(-CALL_FROM_TILES.y, CALL_FROM_TILES.y + 1):
		for x in range(-CALL_FROM_TILES.y, CALL_FROM_TILES.y + 1):
			var c := home + Vector2i(x, y)
			var r := Vector2(x, y).length()
			if r < CALL_FROM_TILES.x or r > CALL_FROM_TILES.y or not astar.is_in_boundsv(c) or astar.is_point_solid(c):
				continue
			cells.append(c)
	# Farthest from the hero first, so they come out of the camp.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return cell_to_world(a).distance_squared_to(hero) > cell_to_world(b).distance_squared_to(hero))
	var i := 0
	while _called.size() < count and i < cells.size():
		var e := Enemy.new()
		e.kind = "halsabschneider"
		e.level = self
		add_child(e)
		e.global_position = cell_to_world(cells[i])
		e.alert(hero)
		e.died.connect(func():
			enemy_killed.emit(e)
			_drop_coins(e.global_position, randi_range(0, 2)))
		enemies = enemies.filter(func(x): return is_instance_valid(x))
		enemies.append(e)
		_called.append(e)
		# Spread them out a little.
		i += 3


## How many of the chief's called cutthroats still stand.
func called_alive() -> int:
	return _called.filter(func(x): return is_instance_valid(x) and not x.dead).size()


## Fallen bandits are replaced once their time is up and the hero is not
## looking; the first time the hero comes near the pass, a warning.
func _mind_the_wild(delta: float) -> void:
	for s in _wild:
		if s.enemy != null:
			continue
		s.timer -= delta
		if s.timer <= 0.0 and _flat_distance(player.global_position, cell_to_world(s.cell)) > RESPAWN_FAR:
			_spawn_bandit(s)
	for s in _wild:
		var beast: bool = Enemy.KINDS[s.kind].get("beast", false)
		if (_beasts_warned if beast else _wild_warned) or _flat_distance(player.global_position, cell_to_world(s.cell)) >= WILD_WARNING_RANGE:
			continue
		if beast:
			_beasts_warned = true
			notice.emit(Lang.t("Die Wolfssenke! Wölfe, Orks, Spinnen und ein Yeti streifen hier umher."), 4.5)
		else:
			_wild_warned = true
			notice.emit(Lang.t("Der Räuberpass! Hier lauern Räuber. Wer sie besiegt, nimmt ihre Beute."), 4.5)


## How many bandits stand on the pass right now.
func bandits_alive() -> int:
	var n := 0
	for s in _wild:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead and s.enemy.is_human():
			n += 1
	return n


## How many beasts roam the wolf hollow right now.
func beasts_alive() -> int:
	var n := 0
	for s in _wild:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead and s.enemy.is_beast():
			n += 1
	return n


## Bumping into a villager: they walk around, so their tile is not enough.
## A door is hit anywhere along the front of its building.
func station_at(point: Vector3) -> Dictionary:
	# Doors of the town houses stand close together: the nearest one counts.
	var door := {}
	var door_distance := INF
	for s in stations:
		if s.has("npc") and s.npc.at_home:
			continue
		if s.has("npc") and _flat_distance(point, s.pos) < 1.6:
			return s
		if s.kind == "eingang":
			var d := _flat_distance(point, s.pos)
			if d < s.get("reach", 2.4) and d < door_distance:
				door = s
				door_distance = d
	if not door.is_empty():
		return door
	return super(point)


# --- Rules of the open air ----------------------------------------------------

func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, not WALK.contains(cell_char(c)))
	# Villagers and the hero keep to the paths where they can.
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) == ".":
				astar.set_point_weight_scale(c, 1.6)


## By day everything is lit. At night only the lanterns and the campfire
## show the hero to the eyes of enemies: a sneaking hero in the dark stays
## unseen.
func is_lit(pos: Vector3) -> bool:
	if not night:
		return true
	for lamp in _lamps:
		if _flat_distance(pos, lamp.global_position) < LAMP_REACH:
			return true
	for fire in _fires:
		if _flat_distance(pos, fire) < LAMP_REACH:
			return true
	return false


func is_opaque(c: Vector2i) -> bool:
	var ch := cell_char(c)
	return ch == "#" or ch == "I" or BLOCK_CHARS.contains(ch)


## Whether a tile is walkable ground (for villagers picking where to go).
func is_open(c: Vector2i) -> bool:
	return WALK.contains(cell_char(c)) and not astar.is_point_solid(c)


func _process(delta: float) -> void:
	super(delta)
	if player == null:
		return
	var cell := world_to_cell(player.global_position)
	var inside := _in_house(cell)
	if inside != _inside:
		_inside = inside
		_roof.visible = not inside
		for wall in _south_walls:
			create_tween().tween_property(wall, "scale:y", LOW_WALL_SCALE if inside else 1.0, 0.35)
		if inside and house_given and not _entered_once:
			_entered_once = true
			notice.emit(Lang.t("Dein neues Zuhause! Im Bett speicherst du, in der Truhe lagerst du deine Schätze."), 4.0)
			home_claimed.emit()
		if inside and _marker:
			_marker.queue_free()
			_marker = null
	_mind_the_wild(delta)
	_mind_the_night(delta)
	_check_basket(delta)
	_herald_timer -= delta
	if _herald and _herald_timer <= 0.0 and not night:
		_herald_timer = randf_range(HERALD_EVERY_MIN, HERALD_EVERY_MAX)
		_call_the_village()
	if not house_given and _elder and not _elder.at_home and _flat_distance(player.global_position, _elder.global_position) < GREET_RANGE:
		house_given = true
		_elder.greet_newcomer(player)
		_show_house_marker()
		notice.emit(Lang.t("Der Dorfvorsteher schenkt dir das leere Haus. Ein goldenes Licht zeigt dir die Tür."), 4.5)


## The herald rings the news across the square, and everyone in the village
## comes over to listen for a while: a reason to gather.
func _call_the_village() -> void:
	var stand: Vector3 = _herald.global_position
	_herald.proclaim()
	var ring: Array[Vector3] = []
	var at := world_to_cell(stand)
	for dy in range(-1, 5):
		for dx in range(-4, 5):
			var c := at + Vector2i(dx, dy)
			if cell_char(c) == ":" and absi(dx) + absi(dy) >= 2:
				ring.append(cell_to_world(c))
	ring.shuffle()
	var i := 0
	for v in villagers:
		if v == _herald or not v.comes_to_listen() or i >= ring.size():
			continue
		if _flat_distance(v.global_position, stand) > 22.0 * TILE * 0.5:
			continue
		v.gather_at(ring[i], stand)
		i += 1
	if player and _flat_distance(player.global_position, stand) < 30.0:
		notice.emit(Lang.t("Der Herold ruft auf dem Marktplatz aus. Das Dorf kommt zusammen."), 3.0)


# --- Day and night ------------------------------------------------------------

## Lights the village for an hour of the day (see DayNight) and, when night
## falls or the day breaks, sends the village to bed or wakes it, and calls
## the dead out of their graves or back into them. The first call after the
## world is built settles everything at once, without a word.
func set_hour(new_hour: float) -> void:
	var first := hour < 0.0
	hour = new_hour
	var glow := DayNight.glow_at(hour)
	for lamp in _lamps:
		lamp.light_energy = lerpf(LAMP_DAY, LAMP_NIGHT, glow)
	if _candle_mat:
		_candle_mat.emission_energy_multiplier = CANDLE_GLOW * glow
	for candle in _candles:
		candle.visible = glow > 0.02
	for mat in _window_mats.values():
		mat.emission_energy_multiplier = WINDOW_GLOW * glow
	var dark := DayNight.is_night(hour)
	if dark == night and not first:
		return
	night = dark
	for v in villagers:
		v.set_night(night, first)
	if night:
		_raise_dead()
	else:
		_lay_the_dead_to_rest()
	if not first:
		notice.emit(Lang.t("Die Nacht bricht herein. Das Dorf geht schlafen, und auf dem Friedhof regen sich die Toten.") if night
				else Lang.t("Ein neuer Tag bricht an. Die Toten kehren in ihre Gräber zurück."), 4.5)


## Nightfall: the dead get their spots on the paths beside the graves.
## They rise one by one in _mind_the_night, never where the hero can see.
func _raise_dead() -> void:
	if not _risen.is_empty():
		return
	var spots: Array[Vector2i] = []
	for g in _graves:
		var c := g + Vector2i(0, 1)
		if WALK.contains(cell_char(c)) and not spots.has(c):
			spots.append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name) + int(hour * 60.0)
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	for i in mini(NIGHT_DEAD, spots.size()):
		_risen.append({"cell": spots[i], "kind": NIGHT_DEAD_KINDS[i % NIGHT_DEAD_KINDS.size()], "enemy": null, "timer": 0.0})


## Dawn: the dead who are not fighting the hero sink back into the earth;
## the ones on the hero's heels follow as soon as they give up.
func _lay_the_dead_to_rest() -> void:
	for s in _risen:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead:
			s.enemy.sink_at_dawn()
	_risen.clear()


## The dead rise in the graveyard (and rise again a while after they fall)
## as long as it is night and the hero is not too close.
func _mind_the_night(delta: float) -> void:
	for s in _risen:
		if s.enemy != null:
			continue
		s.timer -= delta
		if s.timer <= 0.0 and _flat_distance(player.global_position, cell_to_world(s.cell)) > NIGHT_DEAD_FAR:
			_spawn_risen(s)


func _spawn_risen(s: Dictionary) -> void:
	var e := Enemy.new()
	e.kind = s.kind
	e.night = true
	e.level = self
	add_child(e)
	e.global_position = cell_to_world(s.cell)
	var dust := Effects.make_sparkles(Color(0.55, 0.8, 0.6), true)
	dust.position = e.global_position + Vector3(0, 0.6, 0)
	add_child(dust)
	e.died.connect(func():
		enemy_killed.emit(e)
		_drop_coins(e.global_position, randi_range(0, 2))
		s.enemy = null
		s.timer = NIGHT_DEAD_RESPAWN)
	s.enemy = e
	enemies = enemies.filter(func(x): return is_instance_valid(x))
	enemies.append(e)


## How many of the dead walk the graveyard right now.
func risen_alive() -> int:
	var n := 0
	for s in _risen:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead:
			n += 1
	return n
