class_name IceFish
extends Node3D
## Fish swimming under the ice of a frozen river or pond, seen from above like the game's camera sees it
## (they replace the fish the ground shader once drew from the side). They are the animated fish of the
## "Animated Fish Pack" by Quaternius (CC0, see assets/animals/fish/LICENSE.txt), shown as faint, ice-tinted
## shapes (see under_ice_fish.gdshader): each loops slowly round its own spot, on the water only.
##
## They swim in the open water all year round, sparsely (a few to a river or pond, see DENSITY and MAX_FISH),
## darker and clearer in open water and veiled by the ice when it is frozen (see set_ice). They are built the
## first time the level runs (see Outdoor.set_ice), and only those near the hero are animated (see ACTIVE_RANGE).

const MODELS := [
	preload("res://assets/animals/fish/Fish1.fbx"),
	preload("res://assets/animals/fish/Fish2.fbx"),
]
const SHADER := preload("res://shaders/under_ice_fish.gdshader")
const MAX_FISH := 26
## The share of the water tiles that start a fish, and how many a pond or river gets at least (a body of
## water with more than BIG_BODY tiles gets two).
const DENSITY := 0.03
const BIG_BODY := 60
## Fish farther from the hero than this metres are paused and hidden (they cost nothing).
const ACTIVE_RANGE := 45.0
## Fish length (metres) and how fast it swims; a lazy pace under the ice.
const LENGTH_MIN := 0.38
const LENGTH_MAX := 0.56
const SPEED := 0.3
## How far from the bank a fish keeps (see Outdoor.pond_shore_at), and the ice it shows from.
const SHORE_MIN := 1.5
const SHOW_FROM := 0.6
## River fish seen from above: back colour and flank colour (perch, roach, trout, carp).
const COLOURS := [
	[Color(0.2, 0.28, 0.14), Color(0.66, 0.6, 0.34)],
	[Color(0.38, 0.42, 0.42), Color(0.78, 0.8, 0.76)],
	[Color(0.36, 0.28, 0.16), Color(0.72, 0.58, 0.32)],
	[Color(0.42, 0.3, 0.12), Color(0.8, 0.62, 0.3)],
]

var level: Outdoor
var _fish: Array[Dictionary] = []
## How far from the hero fish swim (see ACTIVE_RANGE); the test changes it.
var active_range := ACTIVE_RANGE
var _cover := 0.0
var _since_check := 0.0


## Puts fish on the water of `ponds` (the pond and river tiles of the map, see Outdoor._pond_waters) and along
## the stretches of stream the level lets run past (see StreamFlow). Every body of water gets a fish or two,
## the rest are scattered thinly.
static func build(lvl: Outdoor, ponds: Array) -> IceFish:
	var school := IceFish.new()
	school.name = "IceFish"
	school.level = lvl
	lvl.add_child(school)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lvl.level_name + "eisfische")
	# Group the tiles into bodies of water.
	var by_cell := {}
	for w: Dictionary in ponds:
		by_cell[w.cell] = w
	var seen := {}
	var spots: Array[Vector3] = []
	var guaranteed: Array[Vector3] = []
	for w: Dictionary in ponds:
		if seen.has(w.cell):
			continue
		var body: Array[Dictionary] = []
		var todo: Array = [w.cell]
		seen[w.cell] = true
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			body.append(by_cell[c])
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if by_cell.has(c + d) and not seen.has(c + d):
					seen[c + d] = true
					todo.append(c + d)
		var inland: Array[Vector3] = []
		for t in body:
			var pos: Vector3 = t.pos
			if lvl.pond_shore_at(pos) >= SHORE_MIN + 0.3:
				inland.append(pos)
				if rng.randf() < DENSITY:
					spots.append(pos)
		if not inland.is_empty():
			inland.shuffle()
			for i in mini(2 if body.size() > BIG_BODY else 1, inland.size()):
				guaranteed.append(inland[i])
	spots.shuffle()
	for g in guaranteed:
		school._add_fish(g, rng)
	for i in mini(MAX_FISH - guaranteed.size(), spots.size()):
		school._add_fish(spots[i], rng)
	# Streams and channels that are not pond tiles: a fish or two along each.
	for flow: StreamFlow in lvl.get_tree().get_nodes_in_group(StreamFlow.GROUP):
		if flow.get_parent() != lvl or flow.stick:
			continue
		# Flows over pond tiles are covered by the ponds above.
		if lvl.pond_shore_at((flow.from + flow.to) * 0.5) > -SHORE_MIN:
			continue
		for k in 2:
			var at := flow.from.lerp(flow.to, rng.randf_range(0.2, 0.8))
			school._add_fish(Vector3(at.x, 0, at.z), rng, {"from": flow.from, "to": flow.to, "half": maxf(flow.width * 0.5 - 0.7, 0.3)})
	school._wake_near()
	return school


func _add_fish(home: Vector3, rng: RandomNumberGenerator, lane := {}) -> void:
	var kind := rng.randi() % MODELS.size()
	var model: Node3D = (MODELS[kind] as PackedScene).instantiate()
	var length := rng.randf_range(LENGTH_MIN, LENGTH_MAX)
	var holder := Node3D.new()
	holder.add_child(model)
	add_child(holder)
	# The models are modelled lying with their length along y and their back along z: turn the back up.
	model.rotation = Vector3(-PI * 0.5, 0, 0)
	# Whatever unit the model was made in, scale it to a river fish of `length` metres.
	var natural := 0.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var box := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		natural = maxf(natural, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	model.scale = Vector3.ONE * (length / maxf(natural, 0.0001))
	var palette: Array = COLOURS[rng.randi() % COLOURS.size()]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("back_color", Vector3((palette[0] as Color).r, (palette[0] as Color).g, (palette[0] as Color).b))
	mat.set_shader_parameter("flank_color", Vector3((palette[1] as Color).r, (palette[1] as Color).g, (palette[1] as Color).b))
	mat.set_shader_parameter("seed", rng.randf())
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).mesh = smoothed(mi.mesh)
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and not player.get_animation_list().is_empty():
		var anim := player.get_animation_list()[0]
		player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		player.speed_scale = rng.randf_range(0.7, 1.1)
		player.play(anim)
		player.seek(rng.randf() * 1.2)
	holder.position = home + Vector3(0, 0.03, 0)
	_fish.append({"node": holder, "mat": mat, "home": home, "awake": true, "heading": rng.randf() * TAU, "t": rng.randf() * 20.0,
			"lane": lane, "turn": rng.randf_range(0.25, 0.55), "speed": SPEED * rng.randf_range(0.7, 1.2)})


## The same mesh with its normals averaged over the vertices that share a spot, so the faceted low-poly
## body shades as one round fish (the skin weights and everything else stay as they are).
static func smoothed(mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surf in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surf)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		if normals.size() != verts.size():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			continue
		var sums := {}
		for i in verts.size():
			var key := Vector3i((verts[i] * 20000.0).round())
			sums[key] = sums.get(key, Vector3.ZERO) + normals[i]
		var smooth := PackedVector3Array()
		smooth.resize(verts.size())
		for i in verts.size():
			smooth[i] = (sums[Vector3i((verts[i] * 20000.0).round())] as Vector3).normalized()
		arrays[Mesh.ARRAY_NORMAL] = smooth
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## How much of the water is frozen, 0 to 1 (see Outdoor.set_ice): in open water the fish are dark and clear,
## under the ice faint and ice-tinted.
func set_ice(value: float) -> void:
	_cover = smoothstep(SHOW_FROM, 1.0, value)
	for f in _fish:
		(f.mat as ShaderMaterial).set_shader_parameter("fade", 1.0)
		(f.mat as ShaderMaterial).set_shader_parameter("cover", _cover)


func _process(delta: float) -> void:
	_since_check += delta
	if _since_check >= 0.5:
		_since_check = 0.0
		_wake_near()
	for f in _fish:
		if not f.awake:
			continue
		var holder: Node3D = f.node
		f.t += delta
		var heading: float = f.heading + sin(f.t * 0.37 + f.turn * 9.0) * f.turn * delta * 2.0
		var dir := Vector3(sin(heading), 0, cos(heading))
		var step: float = f.speed * delta
		var next := holder.position + dir * step
		var home: Vector3 = f.home
		var lane: Dictionary = f.lane
		var off_water: bool
		if lane.is_empty():
			off_water = level.pond_shore_at(next) < SHORE_MIN
		else:
			# A stretch of stream: keep between its banks, on the line from `from` to `to`.
			var a: Vector3 = lane.from
			var line: Vector3 = lane.to - a
			var along := clampf((next - a).dot(line) / maxf(line.length_squared(), 0.01), 0.0, 1.0)
			var nearest := a + line * along
			off_water = Vector2(next.x - nearest.x, next.z - nearest.z).length() > lane.half
		if off_water or next.distance_to(home) > 4.0:
			# Too near the bank or too far from home: turn back towards the home spot.
			var to_home := home - holder.position
			heading = lerp_angle(heading, atan2(to_home.x, to_home.z), minf(1.0, 3.0 * delta))
			dir = Vector3(sin(heading), 0, cos(heading))
			next = holder.position + dir * step * 0.5
		f.heading = heading
		holder.position = Vector3(next.x, holder.position.y, next.z)
		holder.rotation.y = heading + HEAD_TURN


## Fish near the hero swim; the others are hidden and paused (see ACTIVE_RANGE).
func _wake_near() -> void:
	var hero := level.player as Node3D
	for f in _fish:
		var holder: Node3D = f.node
		var near := hero == null or holder.global_position.distance_to(hero.global_position) <= active_range
		if near != f.awake:
			f.awake = near
			holder.visible = near
			holder.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED


## The models' heads are at their -y end, which points along +z once they are laid flat: already on the
## heading (sin h, cos h), so no extra turn.
const HEAD_TURN := 0.0
