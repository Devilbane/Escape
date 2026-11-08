class_name EmberCracks
## The glowing ember cracks ("~") in the floor of the ember tunnels below
## mine 3 (see Mines). They are not drawn tile by tile: one heat field lies
## over the whole floor, a soft bump round every crack tile plus a little
## noise, and the cracks are its contour lines. So a crack has a rough,
## uneven edge with no square tile showing, and cracks on neighbouring tiles
## run together into one long crack.
##
## Layers, from the outside in: scorched stone, a dull red rim and the
## glowing embers, with dark plates of crust floating on them and bright
## seams between the plates. Each layer
## is one mesh for the whole floor. A crack tile can be walked on but burns the hero (see scorch) and has a flame.
##
## The cracks light their surroundings like a torch (same colour, energy and
## reach as a wall torch, see Level.TORCH_COLOUR) and flicker the same way.
## Real lights are expensive, so crack tiles that lie close together share one
## light (see _cluster), and only the lights nearest to the hero shine at all
## (see MAX_LIT, update). The crack surface itself is emissive, so it stays
## bright whatever the light.

const GROUP := "ember_cracks"
## Heat above which the floor glows (the edge of a crack proper).
const GLOW := 0.56
## How far the heat of one crack tile reaches, in tiles.
const REACH := 1.0
## How much the noise moves the edge.
const ROUGH := 0.32
## Sample squares per tile side when tracing the edges.
const RES := 12

## name: [heat threshold, colour, glow, height]. The "crust" floats on the
## glow as dark plates and the "seams" glow brightest between them (see
## _field); the others are traced from the heat alone.
const LAYERS := {
	"scorched": [0.36, Color(0.1, 0.06, 0.045), 0.0, 0.025],
	"rim": [0.46, Color(0.45, 0.08, 0.03), 0.7, 0.04],
	"glow": [GLOW, Color(1.0, 0.33, 0.05), 1.5, 0.05],
	"crust": [0.66, Color(0.17, 0.08, 0.05), 0.3, 0.06],
	"seams": [0.6, Color(1.0, 0.72, 0.28), 2.2, 0.065],
}
## How wide the gaps between the crust plates are, and the bright line in them.
const GAP := 0.1
const SEAM := 0.035

## Damage in life per second: on a crack tile, and merely close to one.
const DAMAGE_ON := 3.0
const DAMAGE_NEAR := 1.0
## How close to a crack's edge, in tiles, the hero feels its heat.
const NEAR_RADIUS := 1.0
## Walkers' path finding counts a crack tile as this many steps.
const DETOUR := 8.0
const BURN_COLOUR := Color(1.0, 0.5, 0.15)

const META := "ember_cracks"
const LIGHTS_META := "ember_lights"
const OWED := "ember_owed"
const TOLD := "ember_told"
## Crack tiles within this many tiles of a cluster's first tile share its light.
const CLUSTER_TILES := 3.0
## Most ember lights that shine at once: the ones nearest to the hero.
const MAX_LIT := 6


## Builds crack tile `c` of `level`: its flame, light and solid block. The
## first one also draws the cracks of the whole floor.
static func build(level: Level, c: Vector2i, pos: Vector3) -> void:
	if not level.has_meta(META):
		_draw(level)
		_light(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	var flame := Effects.make_flame()
	flame.position = pos + Vector3(rng.randf_range(-0.5, 0.5), 0.4, rng.randf_range(-0.5, 0.5))
	flame.scale = Vector3.ONE * rng.randf_range(1.0, 1.4)
	level.add_child(flame)


## Life per second lost at `p` (in the level's space): DAMAGE_ON on a crack
## tile, DAMAGE_NEAR within NEAR_RADIUS tiles of one, else 0.
static func damage_rate(level: Level, p: Vector3) -> float:
	var cells: Dictionary = _data(level).cells
	var home := Vector2i(roundi(p.x / Level.TILE), roundi(p.z / Level.TILE))
	if cells.has(home):
		return DAMAGE_ON
	var reach := int(ceil(NEAR_RADIUS)) + 1
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := home + Vector2i(dx, dy)
			if not cells.has(c):
				continue
			var gap := Vector2(absf(p.x - c.x * Level.TILE), absf(p.z - c.y * Level.TILE)) - Vector2.ONE * Level.TILE * 0.5
			if Vector2(maxf(gap.x, 0.0), maxf(gap.y, 0.0)).length() <= NEAR_RADIUS * Level.TILE:
				return DAMAGE_NEAR
	return 0.0


## Burns the hero for `delta` seconds at damage_rate. Fractions of a life add
## up until a whole one is lost. The first burn of a visit is told once.
## Like other burns it never takes the last life, so a lost hero can walk out.
static func scorch(level: Level, hero: Player, delta: float) -> void:
	if hero.dead or not level.has_meta(LIGHTS_META):
		return
	var rate := damage_rate(level, hero.global_position)
	var owed: float = hero.get_meta(OWED, 0.0) + rate * delta
	if rate <= 0.0:
		hero.set_meta(OWED, 0.0)
		return
	if not level.has_meta(TOLD):
		level.set_meta(TOLD, true)
		Events.tell(Lang.t("Die Glut versengt dich! Nahe der Risse brennt es, auf ihnen noch mehr."), BURN_COLOUR, 5.0)
	var lost := mini(int(owed), hero.hp - 1)
	hero.set_meta(OWED, owed - int(owed))
	if lost > 0:
		hero.scorched(lost, BURN_COLOUR)


## Makes path finding avoid the crack tiles without forbidding them.
static func detour(level: Level) -> void:
	if not level.has_meta(LIGHTS_META):
		return
	for c in _data(level).cells:
		level.astar.set_point_weight_scale(c, DETOUR)


## The heat of the floor at `p` (in the level's space): about 1 in the
## middle of a crack tile, more where cracks meet, 0 well away from them.
static func heat(level: Level, p: Vector3) -> float:
	var data := _data(level)
	return _heat(data, p.x, p.z)


## Groups the crack tiles of `level` into clusters of tiles lying close
## together, greedily: each unassigned tile opens a cluster that takes every
## unassigned tile within CLUSTER_TILES of it. Returns the clusters' centres.
static func clusters(cells: Array) -> Array[Vector2]:
	var left := cells.duplicate()
	left.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var centres: Array[Vector2] = []
	while not left.is_empty():
		var seed_cell: Vector2i = left[0]
		var sum := Vector2.ZERO
		var rest := []
		var n := 0
		for c in left:
			if Vector2(c - seed_cell).length() <= CLUSTER_TILES:
				sum += Vector2(c)
				n += 1
			else:
				rest.append(c)
		centres.append(sum / n * Level.TILE)
		left = rest
	return centres


## Adds one torch-like light per cluster of cracks (all dark until `update`
## switches the nearest on) and lets the fog see by them.
static func _light(level: Level) -> void:
	var lights := []
	for centre in clusters(_data(level).cells.keys()):
		var light := OmniLight3D.new()
		light.light_color = Level.TORCH_COLOUR
		light.light_energy = Level.TORCH_ENERGY
		light.omni_range = Level.TORCH_RANGE
		light.omni_attenuation = Level.TORCH_ATTENUATION
		light.shadow_enabled = false
		light.position = Vector3(centre.x, 1.2, centre.y)
		level.add_child(light)
		level._light_spots.append(Vector3(centre.x, 0, centre.y))
		lights.append({"light": light, "seed": hash(centre) % 1000 / 10.0})
	level.set_meta(LIGHTS_META, lights)


## Per frame: flickers the ember lights like torches and keeps only the
## MAX_LIT ones nearest to `focus` switched on.
static func update(level: Level, focus: Vector3, time: float) -> void:
	if not level.has_meta(LIGHTS_META):
		return
	var lights: Array = level.get_meta(LIGHTS_META)
	var order := range(lights.size())
	order.sort_custom(func(a, b): return _flat(lights[a].light, focus) < _flat(lights[b].light, focus))
	for rank in order.size():
		var l: Dictionary = lights[order[rank]]
		var light: OmniLight3D = l.light
		light.visible = rank < MAX_LIT
		var s: float = l.seed + time * 9.0
		light.light_energy = Level.TORCH_ENERGY + sin(s) * 0.25 + sin(s * 2.3) * 0.15


static func _flat(light: Node3D, p: Vector3) -> float:
	return Vector2(light.position.x - p.x, light.position.z - p.z).length_squared()


static func _data(level: Level) -> Dictionary:
	if level.has_meta(META):
		return level.get_meta(META)
	var cells := {}
	for y in level.height:
		for x in level.grid[y].length():
			if level.cell_char(Vector2i(x, y)) == "~":
				cells[Vector2i(x, y)] = true
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 1213
	noise.frequency = 0.42
	noise.fractal_octaves = 3
	# The plates of crust: cells whose borders (where the distance to the
	# nearest and second nearest point is about the same) are the seams,
	# bent by a domain warp so they wander like real cracks.
	var veins := FastNoiseLite.new()
	veins.noise_type = FastNoiseLite.TYPE_CELLULAR
	veins.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	veins.seed = 877
	veins.frequency = 0.5
	veins.fractal_type = FastNoiseLite.FRACTAL_NONE
	veins.domain_warp_enabled = true
	veins.domain_warp_amplitude = 1.6
	veins.domain_warp_frequency = 0.3
	var data := {"cells": cells, "noise": noise, "veins": veins}
	level.set_meta(META, data)
	return data


static func _heat(data: Dictionary, x: float, z: float) -> float:
	var cells: Dictionary = data.cells
	var home := Vector2i(roundi(x / Level.TILE), roundi(z / Level.TILE))
	var sum := 0.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := home + Vector2i(dx, dy)
			if not cells.has(c):
				continue
			var d2 := (Vector2(x, z) - Vector2(c) * Level.TILE).length_squared() / (Level.TILE * Level.TILE * REACH * REACH)
			if d2 < 1.0:
				sum += (1.0 - d2) * (1.0 - d2)
	if sum <= 0.0:
		return 0.0
	return sum + ROUGH * (data.noise as FastNoiseLite).get_noise_2d(x, z)


## The field of layer `name` (above 0 inside it) from the heat `h` and the
## distance `edge` to the nearest seam between crust plates.
static func _field(name: String, h: float, edge: float) -> float:
	var above: float = h - LAYERS[name][0]
	match name:
		"crust":
			return minf(above, edge - GAP)
		"seams":
			return minf(above, SEAM - edge)
	return above


## Traces every layer over the tiles round the cracks and adds one mesh per
## layer to `level`.
static func _draw(level: Level) -> void:
	var data := _data(level)
	var cells: Dictionary = data.cells
	var area := {}
	for c in cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				area[c + Vector2i(dx, dy)] = true
	var step := Level.TILE / RES
	var polys := {}
	for name in LAYERS:
		polys[name] = PackedVector3Array()
	var veins: FastNoiseLite = data.veins
	for c in area:
		var origin := Vector2(c) * Level.TILE - Vector2.ONE * Level.TILE * 0.5
		var heats := PackedFloat32Array()
		var edges := PackedFloat32Array()
		heats.resize((RES + 1) * (RES + 1))
		edges.resize((RES + 1) * (RES + 1))
		for j in RES + 1:
			for i in RES + 1:
				var x := origin.x + i * step
				var z := origin.y + j * step
				heats[j * (RES + 1) + i] = _heat(data, x, z)
				edges[j * (RES + 1) + i] = veins.get_noise_2d(x, z) + 1.0
		for name in LAYERS:
			var layer: Array = LAYERS[name]
			var out: PackedVector3Array = polys[name]
			for j in RES:
				for i in RES:
					var k := [j * (RES + 1) + i, j * (RES + 1) + i + 1, (j + 1) * (RES + 1) + i + 1, (j + 1) * (RES + 1) + i]
					var v := []
					for n in 4:
						v.append(_field(name, heats[k[n]], edges[k[n]]))
					if v.max() <= 0.0:
						continue
					var x0 := origin.x + i * step
					var z0 := origin.y + j * step
					var corners := [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
					_square(out, corners, v, layer[3])
			polys[name] = out
	for name in LAYERS:
		var verts: PackedVector3Array = polys[name]
		if verts.is_empty():
			continue
		var layer: Array = LAYERS[name]
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		normals.fill(Vector3.UP)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := Mines._material(layer[1], layer[2])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if layer[2] == 0.0:
			mat.roughness = 1.0
		var mi := MeshInstance3D.new()
		mi.name = "EmberCracks_" + name
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_to_group(GROUP)
		level.add_child(mi)


## Marching squares: adds the part of one sample square where `v` > 0 (the
## square with its cold corners cut off, always convex) as a triangle fan.
static func _square(out: PackedVector3Array, corners: Array, v: Array, y: float) -> void:
	var poly: Array[Vector2] = []
	for n in 4:
		var m := (n + 1) % 4
		if v[n] > 0.0:
			poly.append(corners[n])
		if (v[n] > 0.0) != (v[m] > 0.0):
			var t: float = v[n] / (v[n] - v[m])
			poly.append((corners[n] as Vector2).lerp(corners[m], t))
	for n in range(1, poly.size() - 1):
		out.append(Vector3(poly[0].x, y, poly[0].y))
		out.append(Vector3(poly[n].x, y, poly[n].y))
		out.append(Vector3(poly[n + 1].x, y, poly[n + 1].y))
