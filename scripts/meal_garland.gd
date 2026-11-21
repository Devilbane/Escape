class_name MealGarland
extends RefCounted
## The frame round the dining tables on the village square (see TownMeals): tall
## wooden poles round the whole eating area, a rope running from the top of each
## pole to the next and sagging between them, poles and ropes overgrown with ivy,
## and many small lamps hanging from the ropes on short cords. By day the lamps
## are little amber globes; at dusk they light up with the tables' lanterns and
## light the area softly through the night (set_glow).
##
## The ivy is the village's own: its leaves, stems and grapes join the village's
## ivy (AgedStone.ivy_node), so they turn with the seasons like every other vine
## (IvySeasons) and cost one MultiMesh per map tile with all the rest.
##
## The poles never stand in anyone's way. Villagers walk from tile centre to tile
## centre (WalkRules.JITTER off the line at most), so every pole stands on the
## edge or corner of a tile nobody walks through: a tile outside the frame that
## is blocked already (the fountain, a bench, a lamp post) or that is blocked for
## it (block). The tiles inside the frame stay open, and between the blocked
## tiles round it there is a way in on every side.
##
## Light: the globes glow by themselves (an emissive MultiMesh, no light each),
## and each throws its own soft light round it without costing a real light: a
## halo of warm light in the air and on the ivy round the globe (HALO), and a
## small pool of light on the ground below it (POOL), all of them in two meshes
## with one additive material each (see _add_glow, as WindowSpill does for the
## windows). A few soft lights (LIGHTS) hang along the ropes and light the
## ground and the people walking under them. They are
## out in the open, far from any wall, so they never cast shadows (they keep out
## of LightShadows' budget, see LightShadows.NO_SHADOW).

## How far the frame stands round the tables' middles (metres): half a tile past
## the canopies, so the frame lines run along tile edges.
const MARGIN := Vector2(6.0, 6.0)
## The poles: how tall (well above the canopies' ridges), how thick, and the
## most room between two along a side (metres).
const POLE_HEIGHT := 4.3
const POLE_RADIUS := 0.12
const POLE_GAP := 7.0
## Where the rope is tied, below the pole's top, how thick it is, and how deep it
## sags in the middle of a span (share of the span's length).
const TIE := 0.14
const ROPE_RADIUS := 0.028
const SAG := 0.075
const ROPE_COLOUR := Color(0.6, 0.5, 0.34)
## The lamps: one every LAMP_EVERY metres along a rope, none closer to a pole than
## LAMP_CLEAR, each on a cord LAMP_DROP long (picked at random), its globe's size.
const LAMP_EVERY := 0.8
const LAMP_CLEAR := 0.45
const LAMP_DROP := Vector2(0.12, 0.36)
const GLOBE_RADIUS := 0.07
## The globes: their glass by day, the colour they glow in and how brightly at night.
const GLASS := Color(0.86, 0.68, 0.38)
const GLOW_COLOUR := Color(1.0, 0.72, 0.38)
const GLOBE_GLOW := 3.2
## Each globe's own soft light: the halo round it (its size across, metres, and
## strength) and the pool on the ground below it (its radius and strength).
## Neighbouring pools overlap into a soft band of light along the rope.
const HALO := 1.1
const HALO_STRENGTH := 0.55
const POOL := 1.35
const POOL_STRENGTH := 0.11
## The soft lights along the ropes: how many round the frame, how bright, how far they reach.
const LIGHTS := 6
const LIGHT_ENERGY := 1.15
const LIGHT_RANGE := 7.0
const LIGHT_COLOUR := Color(1.0, 0.76, 0.5)
## The ivy: leaves per metre up a pole (on its vines and between them), per metre
## along a rope, how many vines climb each pole, and how often a tendril hangs
## down from a rope (chance per LAMP_EVERY metres) and how long it is.
const POLE_VINES := 3
const POLE_LEAVES := 46
const ROPE_LEAVES := 32
const TENDRIL_CHANCE := 0.7
const TENDRIL_LENGTH := Vector2(0.25, 0.95)
const GRAPE_CHANCE := 0.07

## The poles' feet (world positions), in order round the frame.
var poles: Array[Vector3] = []
## The tiles blocked for the poles (see block).
var blocked: Array[Vector2i] = []
## The soft lights along the ropes.
var lights: Array[OmniLight3D] = []
## Where the lamps' globes hang (world positions).
var lamps: Array[Vector3] = []
## How many leaves the frame's ivy added to the village's.
var leaf_count := 0
var _globes: MultiMeshInstance3D
var _globe_mat: StandardMaterial3D
## The halos' and the pools' additive materials (their "glow" follows set_glow).
var halo_mat: ShaderMaterial
var pool_mat: ShaderMaterial
## The frame's corners: x/z of the north-west and south-east corner.
var _min := Vector2.ZERO
var _max := Vector2.ZERO


## The poles' feet round a frame from `lo` to `hi` (x and z): the four corners and
## as many between as keep the poles at most POLE_GAP apart, clockwise from the north-west.
static func pole_feet(lo: Vector2, hi: Vector2) -> Array[Vector3]:
	var corners := [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(lo.x, hi.y)]
	var out: Array[Vector3] = []
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n := maxi(1, ceili(a.distance_to(b) / POLE_GAP))
		for k in n:
			var p := a.lerp(b, float(k) / n)
			out.append(Vector3(p.x, 0, p.y))
	return out


## The point of the rope from `a` to `b` (the tie points at the poles' tops) at `t` (0 to 1): it sags most in the middle.
static func rope_at(a: Vector3, b: Vector3, t: float) -> Vector3:
	var sag := Vector2(b.x - a.x, b.z - a.z).length() * SAG
	return a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)


## Builds the frame round `tables` (world positions) on `level`, its ivy into `leaves` (the village's, see AgedStone.ivy_node).
func build(level: Node3D, tables: Array, leaves: Dictionary) -> void:
	if tables.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for t: Vector3 in tables:
		lo = Vector2(minf(lo.x, t.x), minf(lo.y, t.z))
		hi = Vector2(maxf(hi.x, t.x), maxf(hi.y, t.z))
	_min = lo - MARGIN
	_max = hi + MARGIN
	poles = pole_feet(_min, _max)
	var first: int = leaves.xforms.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("garland|%s" % [tables[0]])
	var node := Node3D.new()
	node.name = "MealGarland"
	level.add_child(node)
	var b := WeatheredProps.Builder.new()
	var tops: Array[Vector3] = []
	for foot in poles:
		_pole(b, foot, rng, leaves)
		tops.append(foot + Vector3(0, POLE_HEIGHT - TIE, 0))
		# Solid for the hero, as thin as it is drawn.
		level._add_solid(foot, Vector3(POLE_RADIUS * 2.4, POLE_HEIGHT, POLE_RADIUS * 2.4))
	var globes: Array[Transform3D] = []
	for i in tops.size():
		_rope(b, tops[i], tops[(i + 1) % tops.size()], rng, leaves, globes)
	var frame := b.finish(node)
	frame.name = "Poles"
	_add_globes(node, globes)
	_add_glow(node)
	_add_lights(node, tops)
	leaf_count = leaves.xforms.size() - first


## One pole at `foot`: a round timber with a little lean, a cap on its top and an
## iron ring the rope is tied to, the ivy climbing it in a few twisting vines.
func _pole(b: WeatheredProps.Builder, foot: Vector3, rng: RandomNumberGenerator, leaves: Dictionary) -> void:
	var wood := WeatheredProps.vary(WeatheredProps.TIMBER[1], rng)
	b.cylinder(foot, POLE_RADIUS * 1.1, POLE_RADIUS * 0.9, POLE_HEIGHT, wood, WeatheredProps.WOOD, 8)
	b.cylinder(foot + Vector3(0, POLE_HEIGHT, 0), POLE_RADIUS * 1.05, 0.02, 0.12, WeatheredProps.DARK_TIMBER, WeatheredProps.WOOD, 8)
	b.cylinder(foot + Vector3(0, POLE_HEIGHT - TIE - 0.04, 0), POLE_RADIUS * 1.0 + 0.02, POLE_RADIUS * 0.95 + 0.02, 0.08,
			WeatheredProps.IRON_COLOUR, WeatheredProps.IRON, 8)
	_pole_ivy(foot, rng, leaves)


## The ivy up a pole: POLE_VINES vines twisting round it from the ground to the
## top, thick with leaves all the way up, a clump of leaves at the foot and one
## where the ropes are tied.
func _pole_ivy(foot: Vector3, rng: RandomNumberGenerator, leaves: Dictionary) -> void:
	_ensure(leaves)
	var r := POLE_RADIUS + 0.02
	for v in POLE_VINES:
		var start := TAU * v / POLE_VINES + rng.randf_range(-0.4, 0.4)
		var turns := rng.randf_range(1.2, 2.2) * (1.0 if rng.randf() < 0.5 else -1.0)
		var reach := POLE_HEIGHT * rng.randf_range(0.92, 1.0)
		var steps := int(reach / 0.16)
		var last := Vector3.ZERO
		for s in steps + 1:
			var h := reach * s / steps
			var a := start + turns * TAU * h / POLE_HEIGHT
			var out := Vector3(cos(a), 0, sin(a))
			var at := foot + out * r + Vector3(0, h + 0.05, 0)
			if s > 0:
				var thick := lerpf(0.09, 0.04, h / POLE_HEIGHT)
				_stem(last, at, (out + Vector3(0, 0.1, 0)).normalized(), thick, rng, leaves)
			last = at
	# Leaves all round the pole, a little thinner up high, and a few standing out on short stalks.
	var count := int(POLE_LEAVES * POLE_HEIGHT)
	for i in count:
		var h := POLE_HEIGHT * pow(rng.randf(), 1.15)
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), rng.randf_range(-0.1, 0.45), sin(a)).normalized()
		var at := foot + Vector3(cos(a), 0, sin(a)) * r + Vector3(0, h + 0.05, 0)
		_leaf(at, out, rng, leaves, rng.randf_range(0.75, 1.05))
	# A clump at the foot, where the vines root, and one round the ropes' knot.
	for i in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.12, 0.45)
		var out := Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6).normalized()
		_leaf(foot + Vector3(cos(a) * d, rng.randf_range(0.02, 0.3), sin(a) * d), out, rng, leaves, rng.randf_range(0.8, 1.1))
	for i in 22:
		var a := rng.randf() * TAU
		var up := rng.randf_range(-0.3, 1.0)
		var out := Vector3(cos(a), up, sin(a)).normalized()
		_leaf(foot + Vector3(0, POLE_HEIGHT - TIE, 0) + out * rng.randf_range(0.14, 0.3), out, rng, leaves, rng.randf_range(0.7, 1.0))


## The rope from `a` to `b` (tie points), its ivy and its lamps (globes added to `globes`).
func _rope(b: WeatheredProps.Builder, a: Vector3, c: Vector3, rng: RandomNumberGenerator, leaves: Dictionary, globes: Array[Transform3D]) -> void:
	var length := Vector2(c.x - a.x, c.z - a.z).length()
	var pieces := maxi(8, int(length / 0.35))
	var prev := a
	for i in range(1, pieces + 1):
		var p := rope_at(a, c, float(i) / pieces)
		b.bar(prev, p, ROPE_RADIUS, WeatheredProps.vary(ROPE_COLOUR, rng, 0.05), WeatheredProps.WOOD, 5)
		prev = p
	_rope_ivy(a, c, length, rng, leaves)
	# The lamps, evenly along the rope, each on a cord of its own length.
	var count := int(floor((length - LAMP_CLEAR * 2.0) / LAMP_EVERY))
	var iron := WeatheredProps.IRON_COLOUR * 0.8
	for k in count + 1:
		var along := LAMP_CLEAR + (length - LAMP_CLEAR * 2.0) * (float(k) / maxf(count, 1))
		var hang := rope_at(a, c, along / length)
		var drop := rng.randf_range(LAMP_DROP.x, LAMP_DROP.y)
		var globe := hang - Vector3(0, drop + GLOBE_RADIUS, 0)
		b.bar(hang, globe + Vector3(0, GLOBE_RADIUS + 0.03, 0), 0.006, iron, WeatheredProps.IRON, 3)
		# A little iron cap over the globe.
		b.cylinder(globe + Vector3(0, GLOBE_RADIUS * 0.55, 0), GLOBE_RADIUS * 0.75, 0.015, 0.06, iron, WeatheredProps.IRON, 6)
		globes.append(Transform3D(Basis(), globe))
		lamps.append(globe)


## The ivy along a rope: two vines twisting round it, leaves thick along it (most
## of them turned up and out, where the eye sees them), and tendrils of leaves
## hanging down here and there, now and then with a bunch of grapes.
func _rope_ivy(a: Vector3, c: Vector3, length: float, rng: RandomNumberGenerator, leaves: Dictionary) -> void:
	_ensure(leaves)
	var dir := Vector3(c.x - a.x, 0, c.z - a.z).normalized()
	var side := Vector3.UP.cross(dir).normalized()
	var r := ROPE_RADIUS + 0.015
	for v in 2:
		var phase := PI * v + rng.randf_range(-0.5, 0.5)
		var pitch := rng.randf_range(0.6, 0.9)
		var steps := int(length / 0.14)
		var last := Vector3.ZERO
		for s in steps + 1:
			var t := float(s) / steps
			var ang := phase + TAU * t * length / pitch
			var out := Vector3.UP * cos(ang) + side * sin(ang)
			var at := rope_at(a, c, t) + out * r
			if s > 0:
				_stem(last, at, out, 0.035, rng, leaves)
			last = at
	var count := int(ROPE_LEAVES * length)
	for i in count:
		var t := rng.randf()
		var ang := rng.randf_range(-1.9, 1.9)
		var out := (Vector3.UP * cos(ang) + side * sin(ang)).normalized()
		_leaf(rope_at(a, c, t) + out * r, out, rng, leaves, rng.randf_range(0.6, 0.95))
	# Tendrils hanging down.
	var spots := int(length / LAMP_EVERY)
	for k in spots:
		if rng.randf() > TENDRIL_CHANCE:
			continue
		var t := (k + rng.randf_range(0.2, 0.8)) / spots
		var top := rope_at(a, c, t)
		var hang := rng.randf_range(TENDRIL_LENGTH.x, TENDRIL_LENGTH.y)
		var face := (side * (1.0 if rng.randf() < 0.5 else -1.0) + Vector3(0, 0.35, 0)).normalized()
		var sway := dir * rng.randf_range(-0.12, 0.12)
		var last := top
		var n := maxi(2, int(hang / 0.11))
		for s in range(1, n + 1):
			var f := float(s) / n
			var at := top + Vector3(0, -hang * f, 0) + sway * f * f
			_stem(last, at, face, 0.025, rng, leaves)
			last = at
			_leaf(at + dir * rng.randf_range(-0.05, 0.05), (face + dir * rng.randf_range(-0.5, 0.5)).normalized(), rng, leaves, lerpf(0.75, 0.5, f))
		if rng.randf() < GRAPE_CHANCE * 4.0:
			_grapes(last - Vector3(0, 0.04, 0), rng, leaves)
		elif rng.randf() < GRAPE_CHANCE:
			_grapes(top - Vector3(0, 0.08, 0), rng, leaves)


## The lamps' globes: one MultiMesh of small glass balls that glow at night (see set_glow).
func _add_globes(node: Node3D, globes: Array[Transform3D]) -> void:
	var ball := SphereMesh.new()
	ball.radius = GLOBE_RADIUS
	ball.height = GLOBE_RADIUS * 2.0
	ball.radial_segments = 8
	ball.rings = 4
	_globe_mat = StandardMaterial3D.new()
	_globe_mat.albedo_color = GLASS
	_globe_mat.roughness = 0.3
	_globe_mat.emission_enabled = true
	_globe_mat.emission = GLOW_COLOUR
	_globe_mat.emission_energy_multiplier = 0.0
	ball.material = _globe_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ball
	mm.instance_count = globes.size()
	for i in globes.size():
		mm.set_instance_transform(i, globes[i])
	_globes = MultiMeshInstance3D.new()
	_globes.name = "Globes"
	_globes.multimesh = mm
	_globes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(_globes)


## A halo turned to the camera, soft and round, its middle bright: one quad per
## globe, the corner's offset from the globe in UV2 (see _add_glow).
const HALO_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, fog_disabled, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.72, 0.38);
uniform float glow = 0.0;
uniform float strength = 0.5;
void vertex() {
	// Turned to the camera round the globe's middle (VERTEX), stretched by the corner's offset.
	VERTEX += (INV_VIEW_MATRIX[0].xyz * UV2.x + INV_VIEW_MATRIX[1].xyz * UV2.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = clamp(1.0 - length(p), 0.0, 1.0);
	ALBEDO = colour * (d * d * 0.7 + pow(d, 6.0) * 0.8) * glow * strength;
}
"""

## A round pool of light lying on the ground, brightest under the globe.
const POOL_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, fog_disabled, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.72, 0.38);
uniform float glow = 0.0;
uniform float strength = 0.1;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = clamp(1.0 - dot(p, p), 0.0, 1.0);
	ALBEDO = colour * d * d * glow * strength;
}
"""


## Each globe's own soft light: the halos in one mesh, the pools on the ground in another.
func _add_glow(node: Node3D) -> void:
	if lamps.is_empty():
		return
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var order := [0, 1, 2, 0, 2, 3]
	var halo_v := PackedVector3Array()
	var halo_uv := PackedVector2Array()
	var halo_off := PackedVector2Array()
	var pool_v := PackedVector3Array()
	var pool_uv := PackedVector2Array()
	for at in lamps:
		for k: int in order:
			var c: Vector2 = corners[k]
			halo_v.append(at)
			halo_uv.append((c + Vector2.ONE) * 0.5)
			halo_off.append(c * HALO * 0.5)
			pool_v.append(Vector3(at.x + c.x * POOL, 0.05, at.z + c.y * POOL))
			pool_uv.append((c + Vector2.ONE) * 0.5)
	halo_mat = _glow_material(HALO_SHADER, HALO_STRENGTH)
	pool_mat = _glow_material(POOL_SHADER, POOL_STRENGTH)
	var halo := _glow_mesh(halo_v, halo_uv, halo_off, halo_mat, "Halos")
	# The halos are moved in the shader: keep them from being culled while a globe's middle is off screen.
	halo.extra_cull_margin = HALO
	node.add_child(halo)
	node.add_child(_glow_mesh(pool_v, pool_uv, PackedVector2Array(), pool_mat, "Pools"))


static func _glow_material(code: String, strength: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("colour", Vector3(GLOW_COLOUR.r, GLOW_COLOUR.g, GLOW_COLOUR.b))
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("glow", 0.0)
	return mat


static func _glow_mesh(verts: PackedVector3Array, uvs: PackedVector2Array, offsets: PackedVector2Array, mat: Material, label: String) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not offsets.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = offsets
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Light, not a thing: snow never settles on it.
	mi.set_meta("no_snow", true)
	return mi


## LIGHTS soft lights spread evenly round the frame, just under the ropes.
func _add_lights(node: Node3D, tops: Array[Vector3]) -> void:
	var spans: Array = []
	var total := 0.0
	for i in tops.size():
		var span := Vector2(tops[(i + 1) % tops.size()].x - tops[i].x, tops[(i + 1) % tops.size()].z - tops[i].z).length()
		spans.append(span)
		total += span
	for k in LIGHTS:
		var s := total * (k + 0.5) / LIGHTS
		var i := 0
		while i < spans.size() - 1 and s > spans[i]:
			s -= spans[i]
			i += 1
		var at := rope_at(tops[i], tops[(i + 1) % tops.size()], s / spans[i]) - Vector3(0, LAMP_DROP.y + 0.1, 0)
		var light := OmniLight3D.new()
		light.name = "GarlandLight"
		light.light_color = LIGHT_COLOUR
		light.light_energy = 0.0
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.3
		light.position = at
		light.visible = false
		# Out in the open: no wall to stop it, so it never takes a shadow-casting slot.
		light.set_meta(LightShadows.NO_SHADOW, true)
		node.add_child(light)
		lights.append(light)


## Blocks the tiles the poles stand on the edge of, for the villagers' paths (see the class notes):
## for each pole, the tile just outside the frame beside it. Call after Outdoor's astar is set up.
## Square spots on those tiles are dropped, so nobody is sent to stand in one.
func block(level: Node3D) -> void:
	for foot in poles:
		# Out of the frame: west or east on its west and east sides, north or south on the others (both at a corner).
		var out := Vector3.ZERO
		if is_equal_approx(foot.x, _min.x):
			out.x = -1.0
		elif is_equal_approx(foot.x, _max.x):
			out.x = 1.0
		if is_equal_approx(foot.z, _min.y):
			out.z = -1.0
		elif is_equal_approx(foot.z, _max.y):
			out.z = 1.0
		var cell: Vector2i = level.world_to_cell(foot + out * 0.5)
		if not level.astar.is_in_boundsv(cell):
			continue
		if not level.astar.is_point_solid(cell):
			level.astar.set_point_solid(cell, true)
			blocked.append(cell)
	if blocked.is_empty():
		return
	for key in ["square", "market"]:
		var kept: Array = (level.spots[key] as Array).filter(func(p: Vector3) -> bool: return not level.world_to_cell(p) in blocked)
		level.spots[key].assign(kept)


## Lights the globes and the soft lights for the glow of the hour (0 by day, 1 at night, see DayNight.glow_at).
func set_glow(glow: float) -> void:
	var lit := smoothstep(0.05, 0.4, glow)
	for light in lights:
		light.light_energy = LIGHT_ENERGY * lit
		light.visible = lit > 0.01
	if _globe_mat:
		_globe_mat.emission_energy_multiplier = GLOBE_GLOW * lit
	for mat in [halo_mat, pool_mat]:
		if mat:
			mat.set_shader_parameter("glow", lit)


## Whether one of the soft lights lights `pos` within `reach` metres.
func lights_up(pos: Vector3, reach: float) -> bool:
	for light in lights:
		if light.visible and Vector2(pos.x - light.global_position.x, pos.z - light.global_position.z).length() < reach:
			return true
	return false


# --- Ivy pieces (in the village ivy's own format, see AgedStone) ---------------

static func _ensure(leaves: Dictionary) -> void:
	for key in ["stems", "stem_colours", "grapes", "grape_colours"]:
		if not leaves.has(key):
			leaves[key] = []


## A leaf at `at` looking out along `n`, turned at random about it.
static func _leaf(at: Vector3, n: Vector3, rng: RandomNumberGenerator, leaves: Dictionary, size: float) -> void:
	var across := Vector3.UP.cross(n)
	across = across.normalized() if across.length() > 0.05 else Vector3.RIGHT
	var s := rng.randf_range(AgedStone.LEAF_SIZE.x, AgedStone.LEAF_SIZE.y) * size
	var basis := Basis(across, n.cross(across), n).rotated(n, rng.randf_range(-PI, PI))
	leaves.xforms.append(Transform3D(basis.scaled(Vector3(s, s, s)), at + n * rng.randf_range(0.01, 0.05)))
	var colours: Array = AgedStone.LEAF_COLOURS
	leaves.colours.append((colours[rng.randi() % (colours.size() - 1)] as Color) * rng.randf_range(0.85, 1.15))


## A piece of woody stem from `a` to `b`, a flat strip facing `n`, `thick` wide.
static func _stem(a: Vector3, b: Vector3, n: Vector3, thick: float, rng: RandomNumberGenerator, leaves: Dictionary) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.001:
		return
	dir /= length
	var x := dir.cross(n)
	if x.length() < 0.01:
		return
	x = x.normalized()
	var face := x.cross(dir).normalized()
	leaves.stems.append(Transform3D(Basis(x * thick, dir * (length + 0.02), face), (a + b) * 0.5 + face * 0.01))
	leaves.stem_colours.append(AgedStone.STEM_COLOUR * rng.randf_range(0.8, 1.2))


## A bunch of grapes hanging at `at` (gone in winter, see IvySeasons).
static func _grapes(at: Vector3, rng: RandomNumberGenerator, leaves: Dictionary) -> void:
	leaves.grapes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.2)), at))
	leaves.grape_colours.append((AgedStone.GRAPE_RED if rng.randf() < AgedStone.GRAPE_RED_SHARE else AgedStone.GRAPE_COLOUR) * rng.randf_range(0.85, 1.2))
