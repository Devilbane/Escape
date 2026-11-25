class_name GlowMushrooms
extends RefCounted
## Glow mushrooms: the little lamps' mushrooms of the village (see MealGarland) also grow wild, in rare
## spots on the forest edge, in damp shade by the water and in the dark of the dungeons. By day they soak
## up the light and look pale and dull; towards dusk they take it on and glow through the night in their
## own colour, by the clock (see DayNight.glow_at), and fade again at dawn. They are what the village's
## lamps burn (the lanterns hold one each, see Outdoor._lantern_glow).
##
## The four kinds, from plain to finest, each its own colour and strength (and, like every ingredient, its
## rarity tier, see Rarity): the glow mushroom in the colour of the garland's lamps, the baby blue one, the
## purple one and the violet one with yellow spots. The finer, the rarer the patch.
##
## A patch is a little cluster of 1 to 7 mushrooms of one kind (one mesh, a few draw calls); it is picked by
## walking into it, and gives one mushroom for each that stood there. The patches are random and change with
## every new day: at most PATCHES_MAX stand in a map at a time (the same ones for everybody on a day, from the
## map's name and the day), and the ones nobody picked wither away at the next morning.
## The glow costs no light: it is the mushrooms' own emission and one flat, additive pool on the ground
## below each spot, and the whole of it follows one number per kind (set_glow).
## Tested by tests/glow_mushrooms.gd.

## The kinds, plainest first: the ingredient (see Crafting.INGREDIENTS), the colour it glows in, the pale
## colour it has by day, how strongly it glows, the size of its caps, and how often a patch is of this kind
## outdoors and underground (weights).
const KINDS := [
	{"id": "gluehpilz", "glow": MealGarland.GLOW_COLOUR, "pale": Color(0.78, 0.7, 0.58), "strength": 1.4,
		"cap": 0.1, "spots": false, "weight": 70, "deep": 40},
	{"id": "gluehpilz_blau", "glow": Color(0.55, 0.8, 1.0), "pale": Color(0.7, 0.76, 0.84), "strength": 1.6,
		"cap": 0.11, "spots": false, "weight": 20, "deep": 30},
	{"id": "gluehpilz_purpur", "glow": Color(0.72, 0.28, 0.95), "pale": Color(0.62, 0.52, 0.72), "strength": 1.9,
		"cap": 0.12, "spots": false, "weight": 8, "deep": 20},
	{"id": "gluehpilz_stern", "glow": Color(0.42, 0.2, 1.0), "pale": Color(0.5, 0.44, 0.7), "strength": 2.3,
		"cap": 0.13, "spots": true, "weight": 2, "deep": 10},
]
## The yellow of the epic kind's spots.
const SPOT_COLOUR := Color(1.0, 0.86, 0.2)
## How many patches a map has on a day, at most (PATCHES_MAX), and how likely each number is (1, 2, 3); the
## patches stand at least SPACING cells (tiles) apart.
const PATCHES_MAX := 3
const PATCH_COUNTS := [20, 40, 40]
const SPACING := 10
## How many mushrooms a patch has (1 to 7) and how often: mostly one to three, four and five less often,
## six and seven the rarest.
const SIZES := [26, 26, 20, 9, 8, 3, 2]
## Outdoors the spots keep this far (tiles) from the middle of the village.
const VILLAGE_CLEAR := 30.0
## A patch is picked by walking this close to it (metres).
const REACH := 1.0
## How big the pool of light on the ground is (metres across) and how strong, and how high above the ground it lies.
const POOL := 2.8
const POOL_STRENGTH := 0.4
## Underground the clock means nothing: the mushrooms glow at this share of the night's glow.
const DEEP_GLOW := 0.8
## How many looks each patch size has.
const VARIANTS := 3
## What the compendium says the first time one is picked.
const LEARN := "Glühpilze: Sie wachsen selten, am Waldrand, im feuchten Schatten am Wasser und tief im Verlies. Tagsüber saugen sie das Licht auf und sehen blass aus, nachts leuchten sie. Lauf gegen einen Fleck, um sie zu pflücken; jeden Morgen wachsen sie an anderen Stellen, nie mehr als drei Flecken in einer Karte. Je seltener die Farbe, desto seltener der Fleck: bernsteinfarben, himmelblau, purpurn, und violett mit gelben Tupfen. Alchemisten brauen Tränke daraus, und in den Laternen des Dorfes brennt ein Glühpilz."
const PICKED := "Du pflückst einen Glühpilz. Er pulsiert warm in deiner Hand."

## The cached meshes and materials: per kind.
static var _meshes := {}
static var _cap_mats := {}
static var _stem_mats := {}
static var _pool_mats := {}
static var _soil_mat: StandardMaterial3D
static var _lamp_mesh: ArrayMesh
## The glow the materials are at (set_glow): a new material starts there.
static var _glow := 0.0

const CAP_SHADER := """
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/gl_colour.gdshaderinc"
uniform vec3 pale_col;
uniform vec3 glow_col;
uniform vec3 spot_col = vec3(1.0, 0.86, 0.2);
uniform float spots = 0.0;
uniform float glow = 0.0;
uniform float strength = 3.0;
uniform vec2 tiling = vec2(8.0, 4.0);
uniform float fibre = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV * tiling;
	float n = vnoise(uv * 2.5) * 0.6 + vnoise(uv * 8.0) * 0.4;
	// Fibres down a stem, or the fine radial ribs of a cap.
	float rib = mix(0.5 + 0.5 * sin(UV.x * tiling.x * 6.2832 * 2.0), vnoise(vec2(UV.x * 40.0, UV.y * 2.0)), fibre);
	float shade = 0.72 + 0.38 * n + 0.1 * rib;
	float spot = 0.0;
	if (spots > 0.5) {
		vec2 g = UV * vec2(14.0, 7.0);
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		vec2 off = (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.4;
		spot = step(hash(id), 0.55) * smoothstep(0.27, 0.17, length(f - off)) * step(0.1, UV.y);
	}
	vec3 day = pale_col * shade;
	vec3 night = glow_col * shade;
	vec3 body = mix(day, night * 0.4, glow);
	body = mix(body, spot_col * 0.8, spot);
	ALBEDO = body;
	ROUGHNESS = 0.55;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 lit = night * (0.55 + 0.8 * n) + glow_col * fr * 0.5;
	lit = mix(lit, spot_col * 1.1, spot);
	// By day they only keep a faint warmth; the glow grows with the night.
	EMISSION = lit * strength * glow * glow + day * 0.04;
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
"""

const POOL_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/gl_colour.gdshaderinc"
uniform vec3 col;
uniform float glow = 0.0;
uniform float strength = 0.5;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = clamp(1.0 - d, 0.0, 1.0);
	a = a * a;
	ALBEDO = col * strength;
	ALPHA = a * glow * glow;
	ALBEDO = gl_colour(ALBEDO);
}
"""


## The kind (an index of KINDS) of an ingredient id, or -1.
static func kind_of(id: String) -> int:
	for i in KINDS.size():
		if KINDS[i].id == id:
			return i
	return -1


static func is_glow(id: String) -> bool:
	return kind_of(id) >= 0


## The glow colour of a kind.
static func colour(kind: int) -> Color:
	return KINDS[kind].glow


# --- Materials and meshes ----------------------------------------------------------------------

static func cap_material(kind: int) -> ShaderMaterial:
	if not _cap_mats.has(kind):
		var k: Dictionary = KINDS[kind]
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = CAP_SHADER
		mat.set_shader_parameter("pale_col", k.pale)
		mat.set_shader_parameter("glow_col", k.glow)
		mat.set_shader_parameter("spot_col", SPOT_COLOUR)
		mat.set_shader_parameter("spots", 1.0 if k.spots else 0.0)
		mat.set_shader_parameter("strength", k.strength)
		mat.set_shader_parameter("glow", _glow)
		_cap_mats[kind] = mat
	return _cap_mats[kind]


static func stem_material(kind: int) -> ShaderMaterial:
	if not _stem_mats.has(kind):
		var k: Dictionary = KINDS[kind]
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = CAP_SHADER
		mat.set_shader_parameter("pale_col", Color(0.9, 0.86, 0.76))
		mat.set_shader_parameter("glow_col", Color(0.9, 0.9, 0.9).lerp(k.glow, 0.45))
		mat.set_shader_parameter("strength", k.strength * 0.35)
		mat.set_shader_parameter("tiling", Vector2(6.0, 2.0))
		mat.set_shader_parameter("fibre", 1.0)
		mat.set_shader_parameter("glow", _glow)
		_stem_mats[kind] = mat
	return _stem_mats[kind]


static func pool_material(kind: int) -> ShaderMaterial:
	if not _pool_mats.has(kind):
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = POOL_SHADER
		mat.set_shader_parameter("col", KINDS[kind].glow)
		mat.set_shader_parameter("strength", POOL_STRENGTH)
		mat.set_shader_parameter("glow", _glow)
		_pool_mats[kind] = mat
	return _pool_mats[kind]


## Mossy earth under a cluster: a squashed lump with a noise texture, never a flat colour.
static func soil_material() -> StandardMaterial3D:
	if _soil_mat == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.06
		noise.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.noise = noise
		tex.width = 64
		tex.height = 64
		tex.seamless = true
		_soil_mat = StandardMaterial3D.new()
		_soil_mat.albedo_color = Color(0.3, 0.36, 0.22)
		_soil_mat.albedo_texture = tex
		_soil_mat.roughness = 1.0
		_soil_mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
	return _soil_mat


## One cluster of mushrooms as a single mesh: a moss mound, then `count` stems and caps of different sizes
## leaning a little. `variant` picks one of VARIANTS looks.
static func cluster_mesh(kind: int, count: int, variant: int) -> ArrayMesh:
	var key := kind * 100 + count * 10 + variant
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("glow%d/%d/%d" % [kind, count, variant])
	var cap_r: float = KINDS[kind].cap
	var caps := SurfaceTool.new()
	var stems := SurfaceTool.new()
	var soil := SurfaceTool.new()
	var mound := SphereMesh.new()
	var reach := 0.1 + 0.025 * count
	mound.radius = reach + 0.1
	mound.height = 0.2
	mound.radial_segments = 12
	mound.rings = 4
	soil.append_from(mound, 0, Transform3D(Basis().scaled(Vector3(1.0, 0.5, 1.0)), Vector3(0, 0.0, 0)))
	for i in count:
		var a := TAU * i / count + rng.randf_range(-0.4, 0.4)
		var out := 0.0 if i == 0 else rng.randf_range(0.5, 1.0) * reach
		var size := (1.5 if i == 0 else rng.randf_range(0.75, 1.25))
		var height := rng.randf_range(0.12, 0.2) * size
		var lean := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.28, 0.28))
		var foot := Vector3(cos(a) * out, 0.03, sin(a) * out)
		var stem := CylinderMesh.new()
		stem.top_radius = cap_r * 0.2 * size
		stem.bottom_radius = cap_r * 0.3 * size
		stem.height = height
		stem.radial_segments = 8
		stem.rings = 2
		stems.append_from(stem, 0, Transform3D(lean, foot + lean * Vector3(0, height * 0.5, 0)))
		var dome := SphereMesh.new()
		dome.radius = cap_r * size
		dome.height = cap_r * size * 1.1
		dome.is_hemisphere = true
		dome.radial_segments = 14
		dome.rings = 6
		caps.append_from(dome, 0, Transform3D(lean, foot + lean * Vector3(0, height - 0.005, 0)))
	var mesh := ArrayMesh.new()
	caps.generate_normals()
	caps.commit(mesh)
	mesh.surface_set_material(0, cap_material(kind))
	stems.generate_normals()
	stems.commit(mesh)
	mesh.surface_set_material(1, stem_material(kind))
	soil.generate_normals()
	soil.commit(mesh)
	mesh.surface_set_material(2, soil_material())
	_meshes[key] = mesh
	return mesh


## A single mushroom for a lantern's inside (the village's lamps burn glow mushrooms): the garland kind, one
## fat cap on a short stem, no soil.
static func lamp_mesh() -> ArrayMesh:
	if _lamp_mesh == null:
		var cap_r: float = KINDS[0].cap
		var dome := SphereMesh.new()
		dome.radius = cap_r * 1.4
		dome.height = cap_r * 1.5
		dome.is_hemisphere = true
		dome.radial_segments = 14
		dome.rings = 6
		var stem := CylinderMesh.new()
		stem.top_radius = cap_r * 0.3
		stem.bottom_radius = cap_r * 0.45
		stem.height = 0.14
		stem.radial_segments = 8
		stem.rings = 2
		var caps := SurfaceTool.new()
		caps.append_from(dome, 0, Transform3D(Basis(), Vector3(0, 0.14, 0)))
		var stems := SurfaceTool.new()
		stems.append_from(stem, 0, Transform3D(Basis(), Vector3(0, 0.07, 0)))
		_lamp_mesh = ArrayMesh.new()
		caps.generate_normals()
		caps.commit(_lamp_mesh)
		_lamp_mesh.surface_set_material(0, cap_material(0))
		stems.generate_normals()
		stems.commit(_lamp_mesh)
		_lamp_mesh.surface_set_material(1, stem_material(0))
	return _lamp_mesh


## The whole thing a mushroom lamp is: a node holding the mesh, for a lantern.
static func lamp_node() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "GlowMushroom"
	node.mesh = lamp_mesh()
	node.scale = Vector3.ONE * 0.6
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# --- Where they grow ------------------------------------------------------------------------------

## The tiles where a patch may grow on `level`: outdoors open grass beside the forest or the water, away from
## the village; underground floor beside a wall (damp corners), clear of everything that has a letter.
static func candidates(level: Level) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var outdoor := level is Outdoor
	var middle := Vector2.ZERO
	if outdoor:
		middle = (level as Outdoor).village_middle()
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			var ch := level.cell_char(c)
			if outdoor:
				if ch != "." or not (level as Outdoor).is_open(c) or Vector2(c).distance_to(middle) < VILLAGE_CLEAR:
					continue
				var shady := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
					shady = shady or level.cell_char(c + d) in ["#", "T", "~", ";", "≈"]
				if not shady:
					continue
			else:
				if ch != "." and ch != ",":
					continue
				var by_wall := false
				var clear := true
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var n := level.cell_char(c + Vector2i(dx, dy))
						if n == "#" and (dx == 0 or dy == 0):
							by_wall = true
						elif n != "#" and n != "." and n != ",":
							clear = false
				if not (by_wall and clear):
					continue
			out.append(c)
	return out


## Whether the map has glow mushrooms at all: no homes, nothing tiny, no burning mines.
static func grows_on(level: Level) -> bool:
	if level is Outdoor:
		return true
	return not level.is_home and level.width * level.height >= 400 and level.theme not in ["glut", "kupfer"]


## The kind of a patch: from the weights, by `rng` (underground the finer kinds are likelier).
static func pick_kind(rng: RandomNumberGenerator, deep: bool) -> int:
	var total := 0
	for k: Dictionary in KINDS:
		total += int(k.deep if deep else k.weight)
	var roll := rng.randi() % total
	for i in KINDS.size():
		roll -= int(KINDS[i].deep if deep else KINDS[i].weight)
		if roll < 0:
			return i
	return 0


## An index of `weights` picked by `rng`.
static func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0
	for w: int in weights:
		total += w
	var roll := rng.randi() % total
	for i in weights.size():
		roll -= int(weights[i])
		if roll < 0:
			return i
	return 0


## Notes the tiles of `level` where patches may grow (the map's meta "glow_cells"); nothing grows until refresh.
static func build(level: Level) -> void:
	level.set_meta("glow_cells", candidates(level) if grows_on(level) else [])
	level.set_meta("glow_patches", [])
	level.set_meta("glow_day", -1)


## The patches of a map on `day`: at most PATCHES_MAX, at random tiles, each {"cell", "pos", "kind", "count",
## "variant"}. The same for the same map and day.
static func patches_for(level: Level, day: int) -> Array:
	var cells: Array = level.get_meta("glow_cells", [])
	var out: Array = []
	if cells.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/gluehpilze/%d" % [level.level_name, day])
	var want := 1 + _weighted(rng, PATCH_COUNTS)
	var tries := 0
	while out.size() < want and tries < 200:
		tries += 1
		var c: Vector2i = cells[rng.randi() % cells.size()]
		if out.any(func(s: Dictionary) -> bool: return Vector2(s.cell).distance_to(Vector2(c)) < SPACING):
			continue
		var at := level.cell_to_world(c) + Vector3(rng.randf_range(-0.9, 0.9), 0.0, rng.randf_range(-0.9, 0.9))
		at.y = 0.0
		out.append({"cell": c, "pos": at, "kind": pick_kind(rng, not level is Outdoor), "count": 1 + _weighted(rng, SIZES),
				"variant": rng.randi() % VARIANTS})
	return out


# --- Growing, picking and the clock ---------------------------------------------------------------

## The key of patch `index` on `day` in the saved game (picked ones stay gone for the day).
static func patch_key(day: int, index: int) -> String:
	return "gp:%d:%d" % [day, index]


## How many patches stand grown right now.
static func grown(level: Level) -> int:
	return level._pickups.filter(func(p: Dictionary) -> bool: return str(p.get("id", "")).begins_with("gp:")).size()


## Lays the patches of `day` out: the ones of an earlier day wither away (`animate`: before the hero's eyes),
## today's grow, but not the ones picked today already. The picked ones of earlier days are dropped from the
## saved game.
static func refresh(level: Level, day: int, animate := false) -> void:
	if not level.has_meta("glow_cells"):
		return
	for key in level.taken.keys():
		if str(key).begins_with("gp:") and not str(key).begins_with("gp:%d:" % day):
			level.taken.erase(key)
	if int(level.get_meta("glow_day", -1)) != day:
		for p: Dictionary in level._pickups.duplicate():
			if str(p.get("id", "")).begins_with("gp:"):
				level._pickups.erase(p)
				_wither(level, p.node, animate)
		var patches := patches_for(level, day)
		level.set_meta("glow_patches", patches)
		level.set_meta("glow_day", day)
		for i in patches.size():
			var key := patch_key(day, i)
			if not level.taken.has(key):
				_grow(level, patches[i], key, animate)
	if not level is Outdoor:
		# Underground the clock means nothing (see DEEP_GLOW).
		set_glow(DEEP_GLOW)


static func _wither(level: Level, node: Node3D, animate: bool) -> void:
	if not is_instance_valid(node):
		return
	if animate and node.is_inside_tree():
		var tween := level.create_tween()
		tween.tween_property(node, "scale", Vector3.ONE * 0.01, 1.2)
		tween.tween_callback(node.queue_free)
	else:
		node.queue_free()


static func _grow(level: Level, patch: Dictionary, key: String, animate: bool) -> void:
	var kind: int = patch.kind
	var holder := Node3D.new()
	holder.name = "GlowMushrooms%s" % key.replace(":", "_")
	holder.position = patch.pos
	holder.rotation.y = patch.pos.x * 1.9
	var cluster := MeshInstance3D.new()
	cluster.name = "Cluster"
	cluster.mesh = cluster_mesh(kind, patch.count, patch.variant)
	cluster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cluster)
	var pool := MeshInstance3D.new()
	pool.name = "Pool"
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * POOL * (0.6 + 0.1 * patch.count)
	pool.mesh = quad
	pool.material_override = pool_material(kind)
	pool.position = Vector3(0, 0.04, 0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(pool)
	level.add_child(holder)
	level._pickups.append({"node": holder, "kind": "ingredient", "ingredient": KINDS[kind].id, "id": key,
			"radius": REACH, "count": int(patch.count)})
	if animate:
		holder.scale = Vector3.ONE * 0.01
		var tween := level.create_tween()
		tween.tween_property(holder, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The glow of the hour (0 by day, 1 at night, see DayNight.glow_at): the mushrooms take the light on at
## dusk, soak it up again at dawn. Every kind has its own materials, so this is a handful of uniforms.
static func set_glow(glow: float) -> void:
	var g := clampf(glow, 0.0, 1.0)
	_glow = g
	for mats in [_cap_mats, _stem_mats, _pool_mats]:
		for kind in mats:
			(mats[kind] as ShaderMaterial).set_shader_parameter("glow", g)
