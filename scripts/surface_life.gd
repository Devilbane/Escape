class_name SurfaceLife
extends Node3D
## Small things that make the world above ground feel alive, as DungeonLife
## does for the dungeon: fallen leaves, twigs, pebbles, rubble, patches of
## bare earth and moss, tufts of grass, mushrooms, straw and wood chips in
## the village, gnawed bones in the wolf hollow, scree and lichen on the
## mountain road, and little creatures that crawl about in it: beetles,
## lines of ants, earthworms, snails and lizards on the warm mountain rock.
##
## Each part of the map gets its own mix (see BIOMES and RECIPES). It is all
## decoration: nothing here blocks the way or can be picked up. To stay
## cheap in the browser, the litter is drawn in batches (one MultiMesh per
## kind and CHUNK x CHUNK tiles, not drawn from far away), there are caps on
## how much is placed, and creatures only move while the hero is near.
##
## Paths stay readable: on a path tile, litter only lies along its verges,
## never on the middle of the way. Whatever lies on the floor to be picked
## up (dropped gear, spilt coins, loot) stays visible: litter around it is
## lifted away while it lies there (see _clear_around_loot).
##
## Everything is placed by a random generator seeded with the level's name,
## so the world looks the same every time it is played.

const TILE := Level.TILE
## Tiles per litter batch: each batch is lit by the lanterns near it only.
const CHUNK := 6
## Litter batches further than this from the camera are not drawn.
const DRAW_RANGE := 64.0
## The most pieces of litter on the whole map, and creatures.
const LITTER_CAP := 24000
const CRITTER_CAP := 60
const TRAIL_CAP := 12
const ANTS_PER_TRAIL := 14
## Creatures only move (and are drawn) while the hero is this close.
const ACTIVE_RANGE := 30.0
## Beetles and lizards scurry off when the hero comes this close.
const FLEE_RANGE := 3.2
## Litter this close to something lying on the floor is lifted away.
const LOOT_CLEAR := 1.2
const LOOT_CHECK_EVERY := 0.3
## On a path tile, litter keeps this far from the middle of the way.
const PATH_VERGE := 1.25

const VILLAGE := "village"
const FOREST := "forest"
const GRAVEYARD := "graveyard"
const HOLLOW := "hollow"
const PASS := "pass"
const MOUNTAIN := "mountain"
## Which letters mark which part of the map. Each tile belongs to the part
## of the nearest marker within BIOME_REACH tiles; the graveyard is the
## ground inside its fence, and everything else is forest.
const BIOMES := {
	VILLAGE: ":^hjnmskowbqF0123456789KOGMYZS+%*$x!@vIiBL",
	HOLLOW: "WHJU;",
	PASS: "NfCcAXQ",
	MOUNTAIN: "'[]{}-/",
}
const BIOME_REACH := 6
## Tiles where litter may lie: walkable ground ...
const GROUND := ".,Pa:'0123456789KOGMYZScAXQWHJUDV&@{}-/"
## ... and under trees, rocks, graves, stumps and tents (no creatures there).
const UNDER := "TdrgtpN"
const PATH := ",aP"
const SQUARE := ":"
const WATER := "~;"

## How many pieces of each kind lie on one tile, on average.
const RECIPES := {
	FOREST: {"leaf": 7.0, "twig": 2.0, "pebble": 1.0, "cone": 0.8, "moss": 0.5, "dirt": 0.3, "tuft": 2.2, "mushroom": 0.45},
	VILLAGE: {"leaf": 2.0, "straw": 3.0, "chip": 1.2, "pebble": 1.5, "twig": 0.6, "dirt": 0.5, "tuft": 1.3},
	GRAVEYARD: {"leaf": 6.0, "twig": 2.0, "pebble": 0.8, "moss": 0.9, "dirt": 0.4, "tuft": 1.0, "mushroom": 0.4},
	HOLLOW: {"leaf": 4.0, "twig": 2.5, "pebble": 1.5, "rubble": 0.35, "bone": 0.5, "moss": 0.5, "dirt": 0.4, "tuft": 2.0, "mushroom": 0.2},
	PASS: {"leaf": 1.5, "twig": 1.5, "pebble": 2.5, "rubble": 0.4, "bone": 0.25, "dirt": 0.8, "tuft": 0.8},
	MOUNTAIN: {"pebble": 4.0, "rubble": 1.2, "lichen": 0.6, "tuft": 0.8, "twig": 0.3},
}
## On a path or the paved square only these lie about, and fewer of them.
const PATH_KINDS := {"leaf": 0.35, "pebble": 0.5, "twig": 0.25, "straw": 0.3}
const SQUARE_KINDS := {"leaf": 0.15, "straw": 0.2, "pebble": 0.15}
## Under trees and rocks: what falls from them.
const UNDER_KINDS := {"leaf": 1.0, "twig": 1.0, "moss": 1.0, "mushroom": 1.0, "pebble": 0.5, "cone": 1.0, "lichen": 1.0}

## Creatures per tile, by part of the map.
const CREATURES := {
	FOREST: {"beetle": 0.05, "worm": 0.025, "snail": 0.015, "ants": 0.012},
	VILLAGE: {"beetle": 0.025, "worm": 0.01, "ants": 0.015},
	GRAVEYARD: {"beetle": 0.04, "worm": 0.05, "snail": 0.03},
	HOLLOW: {"beetle": 0.05, "worm": 0.015, "ants": 0.01},
	PASS: {"beetle": 0.03, "ants": 0.02},
	MOUNTAIN: {"lizard": 0.035, "beetle": 0.015},
}

## Colours of each kind (picked at random), and the parts of the map that
## have their own.
const COLOURS := {
	"leaf": [Color(0.55, 0.42, 0.16), Color(0.62, 0.32, 0.1), Color(0.45, 0.3, 0.14), Color(0.7, 0.55, 0.2), Color(0.35, 0.42, 0.15)],
	"leaf:graveyard": [Color(0.32, 0.24, 0.14), Color(0.4, 0.3, 0.16), Color(0.28, 0.25, 0.2)],
	"leaf:hollow": [Color(0.6, 0.22, 0.08), Color(0.52, 0.3, 0.1), Color(0.4, 0.18, 0.08)],
	"leaf:village": [Color(0.66, 0.52, 0.2), Color(0.5, 0.4, 0.18)],
	"twig": [Color(0.32, 0.22, 0.13), Color(0.4, 0.29, 0.18), Color(0.25, 0.19, 0.13)],
	"straw": [Color(0.82, 0.7, 0.38), Color(0.74, 0.6, 0.3)],
	"chip": [Color(0.72, 0.56, 0.36), Color(0.62, 0.46, 0.28)],
	"pebble": [Color(0.5, 0.48, 0.45), Color(0.42, 0.39, 0.35), Color(0.56, 0.52, 0.46)],
	"pebble:mountain": [Color(0.55, 0.54, 0.52), Color(0.46, 0.45, 0.44), Color(0.6, 0.58, 0.55)],
	"rubble": [Color(0.45, 0.43, 0.41), Color(0.52, 0.5, 0.47), Color(0.38, 0.36, 0.34)],
	"cone": [Color(0.4, 0.26, 0.14), Color(0.33, 0.21, 0.12)],
	"bone": [Color(0.8, 0.76, 0.64), Color(0.72, 0.68, 0.56)],
	"dirt": [Color(0.3, 0.22, 0.14, 0.75), Color(0.36, 0.27, 0.17, 0.65)],
	"dirt:pass": [Color(0.4, 0.31, 0.2, 0.8), Color(0.24, 0.2, 0.17, 0.7)],
	"moss": [Color(0.24, 0.38, 0.13, 0.85), Color(0.3, 0.42, 0.16, 0.8)],
	"lichen": [Color(0.5, 0.52, 0.36, 0.5), Color(0.58, 0.44, 0.24, 0.4), Color(0.46, 0.5, 0.44, 0.45)],
	"tuft": [Color(0.4, 0.6, 0.22), Color(0.48, 0.64, 0.25), Color(0.36, 0.52, 0.2)],
	"tuft:mountain": [Color(0.66, 0.62, 0.38), Color(0.56, 0.58, 0.36)],
	"tuft:pass": [Color(0.62, 0.58, 0.32), Color(0.5, 0.56, 0.26)],
	"mushroom": [Color(0.72, 0.16, 0.1), Color(0.55, 0.36, 0.2), Color(0.8, 0.66, 0.42)],
}
## Each kind: how big it is (smallest, largest) and how high it lies.
const SIZES := {
	"leaf": [0.2, 0.32], "twig": [0.35, 0.8], "straw": [0.2, 0.4], "chip": [0.8, 1.4],
	"pebble": [0.08, 0.2], "rubble": [0.18, 0.42], "cone": [0.08, 0.12], "bone": [0.3, 0.5],
	"dirt": [1.2, 2.6], "moss": [0.8, 1.8], "lichen": [0.5, 1.1], "tuft": [0.22, 0.42],
	"mushroom": [0.7, 1.2],
}
const PATCHES := ["dirt", "moss", "lichen"]

var level: Level
var _rng := RandomNumberGenerator.new()
## The part of the map each tile belongs to, row by row.
var _biome: PackedStringArray = []
## Batches being filled: "chunk_x,chunk_y,kind" -> [[Transform3D, Color], ...].
var _batches := {}
## Each tile's litter, for lifting it away from loot: [MultiMesh, index, position, transform].
var _cell_litter := {}
## Litter lifted away from loot right now: "multimesh_id:index" -> entry.
var _lifted := {}
var _loot_timer := 0.0
var _critters: Array = []
var _trails: Array = []
var _time := 0.0
## How much litter lies in each part of the map (for the tests).
var litter_by_biome := {}
var litter_total := 0

static var _textures := {}
static var _meshes := {}
static var _materials := {}


func _init(owner_level: Level) -> void:
	level = owner_level
	name = "SurfaceLife"


func _ready() -> void:
	_rng.seed = hash(level.level_name + ":surface")
	_map_biomes()
	_scatter_litter()
	_flush_batches()
	_place_creatures()


# --- Parts of the map ---------------------------------------------------------

## Spreads each part of the map out from its markers, one tile per step.
func _map_biomes() -> void:
	var w := level.width
	var h := level.height
	_biome.resize(w * h)
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	var queue: Array[Vector2i] = []
	for y in h:
		for x in w:
			var ch := level.cell_char(Vector2i(x, y))
			for b in BIOMES:
				if BIOMES[b].contains(ch):
					_biome[y * w + x] = b
					dist[y * w + x] = 0
					queue.append(Vector2i(x, y))
					break
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var d := dist[c.y * w + c.x]
		if d >= BIOME_REACH:
			continue
		for step in Level.DIRS:
			var n: Vector2i = c + step
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or dist[n.y * w + n.x] >= 0:
				continue
			dist[n.y * w + n.x] = d + 1
			_biome[n.y * w + n.x] = _biome[c.y * w + c.x]
			queue.append(n)
	var fence := _bounds_of("z")
	for y in h:
		for x in w:
			if fence.has_point(Vector2i(x, y)):
				_biome[y * w + x] = GRAVEYARD
			elif _biome[y * w + x] == "":
				_biome[y * w + x] = FOREST


func biome_of(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= level.width or c.y >= level.height:
		return FOREST
	return _biome[c.y * level.width + c.x]


func _bounds_of(ch: String) -> Rect2i:
	var r := Rect2i()
	for y in level.height:
		for x in level.width:
			if level.cell_char(Vector2i(x, y)) == ch:
				r = Rect2i(x, y, 1, 1) if r.size == Vector2i.ZERO else r.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	return r


# --- Litter -------------------------------------------------------------------

func _scatter_litter() -> void:
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			var ch := level.cell_char(c)
			if ch == "" or c == level.start_cell:
				continue
			var kinds: Dictionary = RECIPES[biome_of(c)]
			var factor := {}
			if PATH.contains(ch):
				factor = PATH_KINDS
			elif SQUARE.contains(ch):
				factor = SQUARE_KINDS
			elif UNDER.contains(ch):
				factor = UNDER_KINDS
			elif not GROUND.contains(ch):
				continue
			for kind in kinds:
				var n: float = kinds[kind]
				if not factor.is_empty():
					n *= factor.get(kind, 0.0)
				var count := int(n) + (1 if _rng.randf() < n - int(n) else 0)
				for i in count:
					if litter_total >= LITTER_CAP:
						return
					var spot := _litter_spot(c, ch)
					if spot.x == INF:
						continue
					_lay(kind, c, spot)


## A spot on a tile for a piece of litter, or INF when none fits. On a path,
## only on its verges; under a tree or rock, around its foot.
func _litter_spot(c: Vector2i, ch: String) -> Vector3:
	var p := level.cell_to_world(c)
	for attempt in 4:
		var off := Vector2(_rng.randf_range(-1.9, 1.9), _rng.randf_range(-1.9, 1.9))
		if PATH.contains(ch) and not _on_verge(c, off):
			continue
		if UNDER.contains(ch) and off.length() < 1.0:
			continue
		return p + Vector3(off.x, 0, off.y)
	return Vector3(INF, 0, 0)


## Whether a spot on a path tile lies on the verge, toward a side where the
## path does not go on.
func _on_verge(c: Vector2i, off: Vector2) -> bool:
	if absf(off.x) > PATH_VERGE and not PATH.contains(level.cell_char(c + Vector2i(int(signf(off.x)), 0))):
		return true
	if absf(off.y) > PATH_VERGE and not PATH.contains(level.cell_char(c + Vector2i(0, int(signf(off.y))))):
		return true
	return false


func _colour(kind: String, biome: String) -> Color:
	var list: Array = COLOURS.get(kind + ":" + biome, COLOURS[kind])
	var col: Color = list[_rng.randi() % list.size()]
	var shade := _rng.randf_range(0.85, 1.12)
	return Color(col.r * shade, col.g * shade, col.b * shade, col.a)


func _lay(kind: String, c: Vector2i, at: Vector3) -> void:
	var biome := biome_of(c)
	var size: Array = SIZES[kind]
	var s := _rng.randf_range(size[0], size[1])
	var yaw := _rng.randf() * TAU
	var basis := Basis(Vector3.UP, yaw)
	var lift := 0.0
	match kind:
		"leaf":
			# Lying flat, curled up a little at random.
			basis = basis * Basis(Vector3.RIGHT, _rng.randf_range(-0.25, 0.25)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.2, 0.2))
			basis = basis.scaled(Vector3(s, s, s * 0.7))
			lift = _rng.randf_range(0.012, 0.022)
		"twig":
			basis = basis.scaled(Vector3(s, 1, 1))
			lift = 0.02
		"straw":
			basis = basis * Basis(Vector3.FORWARD, _rng.randf_range(-0.1, 0.1))
			basis = basis.scaled(Vector3(s, 0.45, 0.45))
			lift = 0.012
		"chip":
			basis = basis.scaled(Vector3(s, 1, s * 0.8))
			lift = 0.015
		"pebble", "rubble":
			basis = Basis.from_euler(Vector3(_rng.randf() * TAU, yaw, _rng.randf() * TAU))
			basis = basis.scaled(Vector3(s, s * _rng.randf_range(0.5, 0.8), s * _rng.randf_range(0.8, 1.2)))
			lift = s * 0.15
		"cone":
			basis = basis * Basis(Vector3.RIGHT, PI * 0.5)
			basis = basis.scaled(Vector3(s, s * 1.7, s))
			lift = s * 0.45
		"bone":
			basis = basis.scaled(Vector3(s, 1, 1))
			lift = 0.04
		"dirt", "moss", "lichen":
			basis = basis.scaled(Vector3(s, 1, s * _rng.randf_range(0.6, 1.0)))
			# Each patch a hair higher than the last, so none flicker.
			lift = 0.003 + _rng.randf() * 0.006
		"tuft":
			basis = basis.scaled(Vector3(s, s * _rng.randf_range(0.8, 1.2), s))
		"mushroom":
			basis = basis * Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12))
			basis = basis.scaled(Vector3.ONE * s)
	var t := Transform3D(basis, at + Vector3(0, lift, 0))
	var col := _colour(kind, biome)
	if kind == "mushroom":
		# A pale stem under a coloured cap, a few together.
		_add("mushroom_stem", c, t, Color(0.86, 0.82, 0.72))
		_add("mushroom_cap", c, t, col)
		for i in _rng.randi_range(0, 2):
			var o := t.translated(Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)))
			o.basis = o.basis.scaled(Vector3.ONE * _rng.randf_range(0.55, 0.85))
			_add("mushroom_stem", c, o, Color(0.86, 0.82, 0.72))
			_add("mushroom_cap", c, o, col)
	else:
		_add(kind, c, t, col)
	litter_total += 1
	litter_by_biome[biome] = litter_by_biome.get(biome, 0) + 1


func _add(kind: String, c: Vector2i, t: Transform3D, col: Color) -> void:
	var key := "%d,%d,%s" % [floori(c.x / float(CHUNK)), floori(c.y / float(CHUNK)), kind]
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append([t, col, c])


func _flush_batches() -> void:
	for key: String in _batches:
		var kind := key.get_slice(",", 2)
		var items: Array = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh(kind)
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
			var c: Vector2i = items[i][2]
			if not _cell_litter.has(c):
				_cell_litter[c] = []
			_cell_litter[c].append([mm, i, (items[i][0] as Transform3D).origin, items[i][0]])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Litter_" + kind
		mmi.multimesh = mm
		mmi.material_override = _litter_material(kind)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = DRAW_RANGE
		add_child(mmi)
	_batches.clear()


## Lifts the litter away from everything that lies on the floor to be picked
## up, and puts it back once that is gone.
func _clear_around_loot() -> void:
	var near := {}
	for p in level._pickups:
		if not (p is Dictionary and is_instance_valid(p.get("node"))):
			continue
		var at: Vector3 = (p.node as Node3D).global_position
		var c := level.world_to_cell(at)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for e in _cell_litter.get(c + Vector2i(dx, dy), []):
					var o: Vector3 = e[2]
					if Vector2(o.x - at.x, o.z - at.z).length() < LOOT_CLEAR:
						near["%d:%d" % [(e[0] as MultiMesh).get_instance_id(), e[1]]] = e
	for k in _lifted:
		if not near.has(k):
			var e: Array = _lifted[k]
			(e[0] as MultiMesh).set_instance_transform(e[1], e[3])
	for k in near:
		if not _lifted.has(k):
			var e: Array = near[k]
			(e[0] as MultiMesh).set_instance_transform(e[1], Transform3D(Basis().scaled(Vector3.ZERO), e[2]))
	_lifted = near


## How many pieces of litter are lifted away from loot right now.
func lifted_count() -> int:
	return _lifted.size()


## Whether any piece of litter lies within `radius` of a spot (and is not lifted away).
func litter_near(at: Vector3, radius: float) -> int:
	var count := 0
	var c := level.world_to_cell(at)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for e in _cell_litter.get(c + Vector2i(dx, dy), []):
				var o: Vector3 = e[2]
				if Vector2(o.x - at.x, o.z - at.z).length() < radius \
						and not _lifted.has("%d:%d" % [(e[0] as MultiMesh).get_instance_id(), e[1]]):
					count += 1
	return count


## The middle line of every path tile, for the tests: litter never lies there.
func litter_on_path_middles() -> int:
	var count := 0
	for c: Vector2i in _cell_litter:
		if not PATH.contains(level.cell_char(c)):
			continue
		var mid := level.cell_to_world(c)
		for e in _cell_litter[c]:
			var o: Vector3 = e[2]
			if absf(o.x - mid.x) < PATH_VERGE and absf(o.z - mid.z) < PATH_VERGE:
				count += 1
	return count


# --- Meshes, textures, materials -------------------------------------------

func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	match kind:
		"leaf", "dirt", "moss", "lichen":
			var plane := PlaneMesh.new()
			plane.size = Vector2.ONE
			mesh = plane
		"twig", "straw":
			mesh = _twig_mesh()
		"chip":
			var box := BoxMesh.new()
			box.size = Vector3(0.12, 0.025, 0.07)
			mesh = box
		"pebble", "cone":
			var round := SphereMesh.new()
			round.radius = 0.5
			round.height = 1.0
			round.radial_segments = 6
			round.rings = 3
			mesh = round
		"rubble":
			mesh = _rubble_mesh()
		"bone":
			mesh = _bone_mesh()
		"tuft":
			mesh = _tuft_mesh()
		"mushroom_stem":
			var stem := CylinderMesh.new()
			stem.top_radius = 0.035
			stem.bottom_radius = 0.05
			stem.height = 0.16
			stem.radial_segments = 6
			stem.rings = 1
			var st := SurfaceTool.new()
			st.append_from(stem, 0, Transform3D(Basis(), Vector3(0, 0.08, 0)))
			mesh = st.commit()
		"mushroom_cap":
			var cap := SphereMesh.new()
			cap.radius = 0.12
			cap.height = 0.12
			cap.is_hemisphere = true
			cap.radial_segments = 8
			cap.rings = 3
			var st := SurfaceTool.new()
			st.append_from(cap, 0, Transform3D(Basis(), Vector3(0, 0.15, 0)))
			mesh = st.commit()
	_meshes[kind] = mesh
	return mesh


## A stick one metre long (scaled to its length), with a short fork.
func _twig_mesh() -> Mesh:
	var st := SurfaceTool.new()
	var stick := BoxMesh.new()
	stick.size = Vector3(1.0, 0.035, 0.035)
	st.append_from(stick, 0, Transform3D())
	var fork := BoxMesh.new()
	fork.size = Vector3(0.3, 0.025, 0.025)
	st.append_from(fork, 0, Transform3D(Basis(Vector3.UP, 0.6), Vector3(0.22, 0, 0.08)))
	return st.commit()


## A bone with knobs at both ends, one metre long (scaled to its length).
func _bone_mesh() -> Mesh:
	var st := SurfaceTool.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.035
	shaft.bottom_radius = 0.035
	shaft.height = 0.8
	shaft.radial_segments = 6
	shaft.rings = 1
	st.append_from(shaft, 0, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO))
	var knob := SphereMesh.new()
	knob.radius = 0.06
	knob.height = 0.12
	knob.radial_segments = 6
	knob.rings = 3
	for end: float in [-0.42, 0.42]:
		for side: float in [-0.04, 0.04]:
			st.append_from(knob, 0, Transform3D(Basis(), Vector3(end, 0, side)))
	return st.commit()


## A chunk of broken rock with flat faces, about one metre across.
func _rubble_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 271
	var points: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		points.append(Vector3(cos(a) * rng.randf_range(0.4, 0.55), rng.randf_range(-0.05, 0.1), sin(a) * rng.randf_range(0.4, 0.55)))
	var top := Vector3(rng.randf_range(-0.1, 0.1), 0.45, rng.randf_range(-0.1, 0.1))
	var bottom := Vector3(0, -0.25, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := points[i]
		var b := points[(i + 1) % 6]
		for tri in [[top, b, a], [bottom, a, b]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for v in tri:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


## A tuft of grass: a few blades fanning out, dark at their feet.
func _tuft_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var blades := 9
	for i in blades:
		var a := TAU * i / blades + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x) * 0.045
		var foot := out * rng.randf_range(0.0, 0.12)
		var tip := foot + out * rng.randf_range(0.25, 0.5) + Vector3(0, rng.randf_range(0.6, 1.0), 0)
		for v: Array in [[foot - side, 0.55], [foot + side, 0.55], [tip, 1.15]]:
			var shade: float = v[1]
			st.set_color(Color(shade, shade, shade))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	return st.commit()


func _litter_material(kind: String) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	match kind:
		"leaf":
			m.albedo_texture = _leaf_texture()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"dirt":
			m.albedo_texture = _patch_texture(23, 0.035)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 1.0
		"moss", "lichen":
			m.albedo_texture = _patch_texture(57 if kind == "moss" else 81, 0.09)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 1.0
		"tuft":
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"rubble", "pebble":
			m.roughness = 0.95
		"mushroom_cap":
			m.roughness = 0.6
	_materials[kind] = m
	return m


## A leaf: pointed at both ends, with a darker middle vein and a stalk.
static func _leaf_texture() -> Texture2D:
	if _textures.has("leaf"):
		return _textures.leaf
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (x + 0.5) / size * 2.0 - 1.0
			var v := (y + 0.5) / size * 2.0 - 1.0
			var width := 0.62 * pow(maxf(0.0, cos(u * PI * 0.5)), 0.8)
			var stalk := u < -0.75 and absf(v) < 0.05
			if absf(v) > width and not stalk:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
				continue
			var shade := 0.92 - 0.25 * absf(v) / maxf(width, 0.01)
			if absf(v) < 0.04 or stalk:
				shade = 0.62
			# Side veins running out from the middle.
			elif fposmod(u * 6.0 - absf(v) * 4.0, 1.0) < 0.12:
				shade *= 0.84
			img.set_pixel(x, y, Color(shade, shade, shade, 1))
	img.generate_mipmaps()
	_textures.leaf = ImageTexture.create_from_image(img)
	return _textures.leaf


## A soft, frayed round patch (bare earth, moss or lichen), fading out at its
## rim so it melts into the ground.
static func _patch_texture(noise_seed: int, frequency: float) -> Texture2D:
	var key := "patch%d" % noise_seed
	if _textures.has(key):
		return _textures[key]
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var size := 128
	var src := noise.get_image(size, size)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var r := Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			var n := src.get_pixel(x, y).r
			var a := smoothstep(0.3, 0.75, n + (1.0 - r) * 0.45 - 0.2) * smoothstep(1.0, 0.6, r)
			var grain := 0.85 + 0.3 * fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
			img.set_pixel(x, y, Color(grain, grain, grain, a))
	img.generate_mipmaps()
	_textures[key] = ImageTexture.create_from_image(img)
	return _textures[key]


func _material(key: String, color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic = metallic
		_materials[key] = m
	return _materials[key]


# --- Creatures ----------------------------------------------------------------

func _place_creatures() -> void:
	var wanted: Array = []
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if c == level.start_cell or not _walkable(c):
				continue
			var odds: Dictionary = CREATURES[biome_of(c)]
			for kind in odds:
				if _rng.randf() < odds[kind]:
					wanted.append([kind, c])
	# Spread over the whole map, then capped.
	for i in range(wanted.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = wanted[i]
		wanted[i] = wanted[j]
		wanted[j] = tmp
	for w in wanted:
		var kind: String = w[0]
		var at := level.cell_to_world(w[1]) + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
		if not _free_spot(at):
			continue
		if kind == "ants":
			if _trails.size() < TRAIL_CAP:
				_ant_trail(at)
		elif _critters.size() < CRITTER_CAP:
			_spawn(kind, at, biome_of(w[1]))


func _walkable(c: Vector2i) -> bool:
	return Outdoor.WALK.contains(level.cell_char(c)) and not WATER.contains(level.cell_char(c)) \
			and not level.astar.is_point_solid(c)


## Whether a creature may be at this spot: on walkable ground, out of the water.
func _free_spot(p: Vector3) -> bool:
	var c := level.world_to_cell(p)
	return c.x >= 0 and c.y >= 0 and c.x < level.width and c.y < level.height and _walkable(c)


func _near_water(c: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if WATER.contains(level.cell_char(c + Vector2i(dx, dy))):
				return true
	return false


func _spawn(kind: String, at: Vector3, biome: String) -> void:
	var node: Node3D
	match kind:
		"beetle":
			node = _beetle_model(biome)
		"lizard":
			node = _lizard_model()
		"snail":
			node = _snail_model()
		"worm":
			node = _worm_model()
	node.position = at
	node.rotation.y = _rng.randf() * TAU
	add_child(node)
	var cr := {
		"node": node, "kind": kind, "target": at, "wait": _rng.randf_range(0.0, 3.0), "speed": 0.0,
		"step": 0.0, "phase": _rng.randf() * TAU, "legs": node.get_meta("legs", []),
	}
	if kind == "worm":
		# Worms come up after rain; by ponds and in the graveyard's soil they
		# are always about.
		var c := level.world_to_cell(at)
		cr.always = biome == GRAVEYARD or _near_water(c)
		cr.down = 0.0
	_critters.append(cr)


## Builds a leg on a pivot that swings while the creature walks.
func _leg(parent: Node3D, from: Vector3, yaw: float, length: float, mat: Material, legs: Array) -> void:
	var pivot := Node3D.new()
	pivot.position = from
	pivot.rotation.y = yaw
	pivot.set_meta("yaw", yaw)
	parent.add_child(pivot)
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.02, 0.02)
	part.mesh = box
	part.position = Vector3(length * 0.45, -0.01, 0)
	part.rotation.z = -0.35
	part.material_override = mat
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(part)
	legs.append(pivot)


func _part(parent: Node3D, mesh: Mesh, at: Vector3, scale_by: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.scale = scale_by
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _ball(radius: float, segments := 8) -> SphereMesh:
	var key := "ball%.3f_%d" % [radius, segments]
	if not _meshes.has(key):
		var s := SphereMesh.new()
		s.radius = radius
		s.height = radius * 2.0
		s.radial_segments = segments
		s.rings = maxi(3, segments / 2)
		_meshes[key] = s
	return _meshes[key]


## A ground beetle: a glossy shell on six legs. Larger than life, so it can
## be seen from the camera high above. Firebugs (red) in the woods and the
## village, dark green ground beetles everywhere, blue-black dung beetles
## where the wild beasts roam.
func _beetle_model(biome: String) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var shell: StandardMaterial3D
	var roll := _rng.randf()
	if roll < 0.35 and biome in [FOREST, VILLAGE, GRAVEYARD]:
		shell = _material("firebug", Color(0.7, 0.14, 0.06), 0.45)
	elif roll < 0.7 and biome in [HOLLOW, PASS, MOUNTAIN]:
		shell = _material("dung_beetle", Color(0.08, 0.1, 0.22), 0.25, 0.5)
	else:
		shell = _material("ground_beetle", Color(0.07, 0.16, 0.09), 0.25, 0.5)
	var dark := _material("beetle_leg", Color(0.06, 0.05, 0.04), 0.6)
	_part(body, _ball(0.12, 10), Vector3(0, 0.08, -0.02), Vector3(1.0, 0.7, 1.45), shell)
	_part(body, _ball(0.065), Vector3(0, 0.07, 0.19), Vector3.ONE, dark)
	var legs := []
	for i in 3:
		for side: int in [-1, 1]:
			_leg(body, Vector3(side * 0.08, 0.05, 0.1 - i * 0.1), (0.0 if side > 0 else PI) + side * (i - 1) * -0.5, 0.2, dark, legs)
	root.set_meta("legs", legs)
	return root


## A lizard that basks on the warm stones of the mountain road and darts off.
func _lizard_model() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var skin := _material("lizard", Color(0.36, 0.42, 0.2), 0.55)
	_part(body, _ball(0.08), Vector3(0, 0.06, 0), Vector3(1.0, 0.6, 2.6), skin)
	_part(body, _ball(0.07), Vector3(0, 0.06, 0.26), Vector3(0.9, 0.6, 1.3), skin)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.045
	tail.bottom_radius = 0.0
	tail.height = 0.55
	tail.radial_segments = 6
	tail.rings = 1
	var t := _part(body, tail, Vector3(0, 0.05, -0.45), Vector3.ONE, skin)
	t.rotation.x = PI * 0.5
	root.set_meta("tail", t)
	var legs := []
	for front: float in [0.12, -0.12]:
		for side: int in [-1, 1]:
			_leg(body, Vector3(side * 0.06, 0.05, front), (0.0 if side > 0 else PI) + side * signf(front) * -0.4, 0.14, skin, legs)
	root.set_meta("legs", legs)
	return root


## A snail: a brown curled shell on a pale foot, with two feelers. It draws
## in when the hero comes close.
func _snail_model() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var foot_mat := _material("snail_foot", Color(0.62, 0.56, 0.46), 0.3)
	var foot := _part(body, _ball(0.07), Vector3(0, 0.03, 0.04), Vector3(0.8, 0.45, 2.6), foot_mat)
	_part(body, _ball(0.11, 10), Vector3(0, 0.12, -0.02), Vector3(0.75, 1.0, 1.0), _material("snail_shell", Color(0.5, 0.33, 0.16), 0.4))
	_part(body, _ball(0.045), Vector3(0, 0.13, -0.02), Vector3(0.9, 1.0, 1.0), _material("snail_curl", Color(0.33, 0.2, 0.1), 0.4)).position.x = 0.075
	var feelers := []
	for side: int in [-1, 1]:
		var f := _part(body, _box(Vector3(0.015, 0.12, 0.015)), Vector3(side * 0.03, 0.08, 0.2), Vector3.ONE, foot_mat)
		f.rotation.x = 0.5
		feelers.append(f)
	root.set_meta("foot", foot)
	root.set_meta("feelers", feelers)
	return root


## An earthworm: a row of pink segments that wriggles and digs back in.
func _worm_model() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var skin := _material("worm", Color(0.7, 0.4, 0.4), 0.35)
	var segments := []
	for i in 7:
		var r := 0.035 if i in [0, 6] else 0.045
		segments.append(_part(body, _ball(r, 6), Vector3(0, 0.035, 0.24 - i * 0.08), Vector3(1, 1, 1.4), skin))
	root.set_meta("segments", segments)
	return root


func _box(size: Vector3) -> BoxMesh:
	var key := "box%s" % size
	if not _meshes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_meshes[key] = b
	return _meshes[key]


## A line of ants marching between two spots, there and back, drawn in one go.
func _ant_trail(from: Vector3) -> void:
	var to := from
	for attempt in 8:
		var dir := _rng.randf() * TAU
		var p := from + Vector3(cos(dir), 0, sin(dir)) * _rng.randf_range(3.0, 5.5)
		if _free_spot(p):
			to = p
			break
	if to == from:
		return
	if not _meshes.has("ant"):
		var st := SurfaceTool.new()
		for part: Array in [[0.045, Vector3(0, 0.04, -0.06)], [0.025, Vector3(0, 0.035, 0.0)], [0.032, Vector3(0, 0.04, 0.05)]]:
			st.append_from(_ball(part[0], 6), 0, Transform3D(Basis().scaled(Vector3(1, 0.8, 1.2)), part[1]))
		_meshes.ant = st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _meshes.ant
	mm.instance_count = ANTS_PER_TRAIL
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material("ant", Color(0.12, 0.05, 0.03), 0.4)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	var ants := []
	for i in ANTS_PER_TRAIL:
		ants.append({"s": float(i) / ANTS_PER_TRAIL + _rng.randf_range(-0.02, 0.02), "back": i % 2 == 1,
				"speed": _rng.randf_range(0.8, 1.2)})
	var trail := {"node": mmi, "from": from, "to": to, "ants": ants, "bend": _rng.randf_range(0.2, 0.45),
			"phase": _rng.randf() * TAU}
	_trails.append(trail)
	_update_trail(trail, 0.0)


## Where on its trail an ant is (0 at one end, 1 at the other).
func _trail_point(trail: Dictionary, s: float, side: float) -> Vector3:
	var from: Vector3 = trail.from
	var to: Vector3 = trail.to
	var along := (to - from)
	var across := Vector3(-along.z, 0, along.x).normalized()
	var wave: float = sin(s * PI * 3.0 + trail.phase) * trail.bend * sin(s * PI)
	return from.lerp(to, s) + across * (wave + side)


func _update_trail(trail: Dictionary, delta: float) -> void:
	var mm: MultiMesh = (trail.node as MultiMeshInstance3D).multimesh
	var length := (trail.to as Vector3).distance_to(trail.from)
	for i in trail.ants.size():
		var ant: Dictionary = trail.ants[i]
		var ds: float = 0.35 * ant.speed * delta / length
		ant.s = fposmod(ant.s + ds, 1.0)
		var s: float = (1.0 - ant.s) if ant.back else ant.s
		var side := 0.07 if ant.back else -0.07
		var p := _trail_point(trail, s, side)
		var ahead := _trail_point(trail, clampf(s + (-0.02 if ant.back else 0.02), 0.0, 1.0), side)
		var dir := ahead - p
		var yaw := atan2(dir.x, dir.z) + sin(_time * 18.0 + i) * 0.15
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 1.4), p))


# --- Moving about -------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_loot_timer -= delta
	if _loot_timer <= 0.0:
		_loot_timer = LOOT_CHECK_EVERY
		_clear_around_loot()
	if level.player == null:
		return
	var hero := level.player.global_position
	var raining: bool = level.get("weather") == Weather.RAIN
	for cr in _critters:
		var node: Node3D = cr.node
		if _flat(node.position, hero) > ACTIVE_RANGE:
			node.visible = false
			continue
		node.visible = true
		match cr.kind:
			"worm":
				_update_worm(cr, delta, hero, raining)
			"snail":
				_update_snail(cr, delta, hero)
			_:
				_update_crawler(cr, delta, hero)
	for trail in _trails:
		var near := _flat(trail.from, hero) < ACTIVE_RANGE
		trail.node.visible = near
		if near:
			_update_trail(trail, delta)


func _update_crawler(cr: Dictionary, delta: float, hero: Vector3) -> void:
	var node: Node3D = cr.node
	var lizard: bool = cr.kind == "lizard"
	var away := Vector3(node.position.x - hero.x, 0, node.position.z - hero.z)
	var fleeing := away.length() < FLEE_RANGE
	if fleeing and cr.wait > 0.0:
		cr.wait = 0.0
		cr.target = node.position + away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * _rng.randf_range(2.5, 4.0)
	if cr.wait > 0.0:
		cr.wait -= delta
		cr.speed = 0.0
		_wiggle(cr, 0.0, delta)
		if _rng.randf() < delta * 0.6:
			node.rotation.y += _rng.randf_range(-0.4, 0.4)
		return
	var to: Vector3 = cr.target - node.position
	to.y = 0
	if to.length() < 0.08:
		# Lizards bask a long while; beetles only stop for a moment.
		cr.wait = _rng.randf_range(2.0, 8.0) if lizard else _rng.randf_range(0.3, 3.0)
		_pick_target(cr)
		return
	var top := (5.0 if lizard else 3.2) if fleeing else (3.0 if lizard else 1.2)
	cr.speed = move_toward(cr.speed, top, delta * (25.0 if lizard else 10.0))
	var step := to.normalized() * minf(cr.speed * delta, to.length())
	var next := node.position + step
	if not _free_spot(next):
		cr.wait = _rng.randf_range(0.1, 0.6)
		_pick_target(cr)
		return
	node.position = next
	node.rotation.y = lerp_angle(node.rotation.y, atan2(step.x, step.z), minf(1.0, delta * 14.0))
	_wiggle(cr, cr.speed, delta)
	if lizard and node.has_meta("tail"):
		(node.get_meta("tail") as Node3D).rotation.y = sin(cr.step * 0.5) * 0.4


func _pick_target(cr: Dictionary) -> void:
	var node: Node3D = cr.node
	var reach := 5.0 if cr.kind == "lizard" else 3.0
	for attempt in 8:
		var dir := _rng.randf() * TAU
		var p := node.position + Vector3(cos(dir), 0, sin(dir)) * _rng.randf_range(0.8, reach)
		if _free_spot(p) and _free_spot(node.position.lerp(p, 0.5)):
			cr.target = p
			return
	cr.target = node.position


## A snail creeps on slowly and draws in when the hero is close.
func _update_snail(cr: Dictionary, delta: float, hero: Vector3) -> void:
	var node: Node3D = cr.node
	var shy := _flat(node.position, hero) < 2.2
	var foot: Node3D = node.get_meta("foot")
	foot.scale.z = move_toward(foot.scale.z, 0.9 if shy else 2.6, delta * 4.0)
	for f: Node3D in node.get_meta("feelers"):
		f.visible = foot.scale.z > 2.0
	if shy:
		return
	var to: Vector3 = cr.target - node.position
	to.y = 0
	if to.length() < 0.05:
		_pick_target(cr)
		return
	var step := to.normalized() * minf(0.08 * delta, to.length())
	if _free_spot(node.position + step):
		node.position += step
		node.rotation.y = lerp_angle(node.rotation.y, atan2(step.x, step.z), minf(1.0, delta * 2.0))
	else:
		_pick_target(cr)


## A worm wriggles where it lies and creeps on a little. It digs in when the
## hero comes close, and stays below unless it rains (or the soil is damp).
func _update_worm(cr: Dictionary, delta: float, hero: Vector3, raining: bool) -> void:
	var node: Node3D = cr.node
	var out: bool = (cr.always or raining) and _flat(node.position, hero) > 2.4
	cr.down = move_toward(cr.down, 0.0 if out else 1.0, delta * 0.8)
	node.position.y = -0.12 * cr.down
	node.visible = cr.down < 0.99
	cr.phase += delta * 3.0
	var segments: Array = node.get_meta("segments")
	for i in segments.size():
		(segments[i] as Node3D).position.x = sin(cr.phase - i * 0.9) * 0.05
	if out:
		var ahead := node.position + node.basis.z * 0.04 * delta
		if _free_spot(ahead):
			node.position = Vector3(ahead.x, node.position.y, ahead.z)
		else:
			node.rotation.y += PI * 0.5
		node.rotation.y += sin(_time * 0.4 + cr.phase * 0.05) * delta * 0.3


## Moves the legs in a quick trot while walking.
func _wiggle(cr: Dictionary, speed: float, delta: float) -> void:
	cr.step += delta * speed * 22.0
	var legs: Array = cr.legs
	for i in legs.size():
		var leg: Node3D = legs[i]
		var swing := sin(cr.step + (PI if i % 2 == 0 else 0.0)) * 0.35 if speed > 0.0 else 0.0
		leg.rotation.y = leg.get_meta("yaw") + swing


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The creatures, for the tests.
func critters() -> Array:
	return _critters


func trails() -> Array:
	return _trails
