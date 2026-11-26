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

const SHADER := preload("res://shaders/under_ice_fish.gdshader")
const MAX_FISH := 26
## The share of the water tiles that start a fish, and how many a pond or river gets at least (a body of
## water with more than BIG_BODY tiles gets two).
const DENSITY := 0.03
const BIG_BODY := 60
## Fish farther from the hero than this metres are paused and hidden (they cost nothing).
const ACTIVE_RANGE := 45.0
## Rings of ripples where a fish stirs just below the surface: how many can be spreading at once, how long
## one lasts (seconds), how wide it grows (metres across) and the pause between two (seconds).
const RING_SHADER := preload("res://shaders/water_ring.gdshader")
const RINGS := 6
const RING_LIFE := 2.6
const RING_SIZE := 1.7
const RING_PAUSE := Vector2(2.5, 6.0)
## Rings only show in open water: from this much ice on they stop.
const RING_ICE_MAX := 0.25
## A fish within RING_SCARE metres of a new ring bolts (DART_SPEED m/s) and dives DIVE_DEPTH metres in
## DART_TIME seconds, then stays away for GONE_TIME seconds.
const RING_SCARE := 1.4
const DART_SPEED := 1.9
const DART_TIME := 1.1
const DIVE_DEPTH := 0.7
## A startled fish first shakes its whole body for SHAKE_TIME seconds, then bolts.
const SHAKE_TIME := 0.7
const GONE_TIME := Vector2(8.0, 16.0)
## Deep in the open water a fish is a little dimmer (see _base_fade). Now and then one comes up to the
## surface (SURFACE_PAUSE seconds apart), breaks it with a ring, flicks its fin (a rolling wiggle) and dives
## away in zigzags, much as a startled fish does.
const DEEP_FADE := 0.9
const SURFACE_PAUSE := Vector2(14.0, 30.0)
const RISE_TIME := 1.6
const FLICK_TIME := 1.1
## Sounds (see tools/make_water_sounds.py): the soft splash of a fish at the surface and of its dive, the
## smaller splash of a ring, played from where they happen. Quieter the farther from the hero.
const SPLASHES := ["water_splash_0", "water_splash_1", "water_splash_2", "water_splash_3"]
const RIPPLES := ["water_ripple_0", "water_ripple_1", "water_ripple_2", "water_ripple_3"]
## Sounds fade by this many dB a metre from the hero and are not played from beyond SOUND_RANGE.
const SOUND_FALL := 0.45
const SOUND_RANGE := 38.0
## Fish length (metres) and how fast it swims; a lazy pace under the ice.
const LENGTH_MIN := 0.7
const LENGTH_MAX := 1.0
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
var _rings: MultiMesh
var _ring_age: Array[float] = []
var _next_ring := 3.0
var _next_surface := 8.0
var _ring_next := 0
var _ring_rng := RandomNumberGenerator.new()


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
	school._make_rings()
	return school


func _add_fish(home: Vector3, rng: RandomNumberGenerator, lane := {}) -> void:
	var length := rng.randf_range(LENGTH_MIN, LENGTH_MAX)
	var holder := Node3D.new()
	# A flat strip lying along z with its head at +z (the shader cuts the fish out of it, see under_ice_fish.gdshader).
	var plane := PlaneMesh.new()
	plane.size = Vector2(length * 0.56, length)
	plane.subdivide_width = 2
	plane.subdivide_depth = 20
	var model := MeshInstance3D.new()
	model.mesh = plane
	model.set_meta("head", Vector3(0, 0, 1))
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(model)
	add_child(holder)
	var palette: Array = COLOURS[rng.randi() % COLOURS.size()]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("back_color", Vector3((palette[0] as Color).r, (palette[0] as Color).g, (palette[0] as Color).b))
	mat.set_shader_parameter("flank_color", Vector3((palette[1] as Color).r, (palette[1] as Color).g, (palette[1] as Color).b))
	mat.set_shader_parameter("seed", rng.randf())
	mat.set_shader_parameter("len", length)
	mat.set_shader_parameter("sway", rng.randf() * TAU)
	model.material_override = mat
	holder.position = home + Vector3(0, 0.03, 0)
	_fish.append({"node": holder, "mat": mat, "home": home, "awake": true, "state": "swim", "timer": 0.0, "fade_from": 1.0, "zig": false, "heading": rng.randf() * TAU, "t": rng.randf() * 20.0,
			"lane": lane, "turn": rng.randf_range(0.25, 0.55), "speed": SPEED * rng.randf_range(0.7, 1.2)})


## How much of the water is frozen, 0 to 1 (see Outdoor.set_ice): in open water the fish are dark and clear,
## under the ice faint and ice-tinted.
func set_ice(value: float) -> void:
	_cover = smoothstep(SHOW_FROM, 1.0, value)
	for f in _fish:
		if f.state == "swim":
			(f.mat as ShaderMaterial).set_shader_parameter("fade", _base_fade())
		(f.mat as ShaderMaterial).set_shader_parameter("cover", _cover)


func _process(delta: float) -> void:
	_stir(delta)
	_since_check += delta
	if _since_check >= 0.5:
		_since_check = 0.0
		_wake_near()
	for f in _fish:
		if not f.awake:
			continue
		if f.state != "swim" and _startled(f, delta):
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


## The pool of rings: flat quads on the water, each aged by its custom data (see water_ring.gdshader).
func _make_rings() -> void:
	_ring_rng.seed = hash(level.level_name + "wellen")
	_rings = MultiMesh.new()
	_rings.transform_format = MultiMesh.TRANSFORM_3D
	_rings.use_custom_data = true
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(RING_SIZE, RING_SIZE)
	_rings.mesh = quad
	_rings.instance_count = RINGS
	for i in RINGS:
		_ring_age.append(1.0)
		_rings.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, -50, 0)))
		_rings.set_instance_custom_data(i, Color(1, 0, 0, 0))
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _rings
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 200.0
	add_child(mi)


## Ages the rings and now and then starts one beside a fish near the hero, in open water only.
func _stir(delta: float) -> void:
	if _rings == null:
		return
	for i in RINGS:
		if _ring_age[i] < 1.0:
			_ring_age[i] = minf(_ring_age[i] + delta / RING_LIFE, 1.0)
			_rings.set_instance_custom_data(i, Color(_ring_age[i], 0, 0, 0))
	_next_surface -= delta
	if _next_surface <= 0.0:
		_next_surface = _ring_rng.randf_range(SURFACE_PAUSE.x, SURFACE_PAUSE.y)
		if _cover <= RING_ICE_MAX:
			for f in _fish:
				if f.awake and f.state == "swim":
					surface_fish(f)
					break
	_next_ring -= delta
	if _next_ring > 0.0:
		return
	_next_ring = _ring_rng.randf_range(RING_PAUSE.x, RING_PAUSE.y)
	if _cover > RING_ICE_MAX:
		return
	var near: Array[Dictionary] = []
	for f in _fish:
		if f.awake and f.state == "swim":
			near.append(f)
	if near.is_empty():
		return
	# A ring can come up anywhere on the water round a fish's home, with or without a fish at it.
	var base: Dictionary = near[_ring_rng.randi() % near.size()]
	var at: Vector3 = (base.node as Node3D).position
	if _ring_rng.randf() < 0.5:
		var spot: Vector3 = base.home + Vector3(_ring_rng.randf_range(-2.5, 2.5), 0, _ring_rng.randf_range(-2.5, 2.5))
		if _on_water(spot, base.lane):
			at = spot
	_ring_at(at)
	# The fish that made the ring bolts away from it and dives out of sight; a fish the ring came up beside does the same.
	for f in near:
		var p: Vector3 = (f.node as Node3D).position
		if Vector2(p.x - at.x, p.z - at.z).length() < RING_SCARE:
			var away := Vector2(p.x - at.x, p.z - at.z)
			f.heading = atan2(away.x, away.y) if away.length() > 0.05 else f.heading
			f.state = "shake"
			f.timer = 0.0
			f.zig = false
			f.fade_from = _base_fade()
			_sound(SPLASHES, -10.0, p)


## A small splash where a fish bolts: a ring on the water, a few droplets thrown up and the splash sound.
func _bolt_splash(at: Vector3) -> void:
	_ring_at(at)
	_sound(SPLASHES, -6.0, at)
	var drops := Effects.make_sparkles(Color(0.82, 0.93, 1.0), true)
	drops.amount = 12
	drops.lifetime = 0.7
	drops.emission_sphere_radius = 0.08
	drops.spread = 40.0
	drops.initial_velocity_min = 0.8
	drops.initial_velocity_max = 1.6
	drops.position = Vector3(at.x, 0.06, at.z)
	add_child(drops)


## Plays a sound from `at`, softer the farther the hero is (none beyond SOUND_RANGE).
func _sound(names: Array, db: float, at: Vector3) -> void:
	var hero := level.player as Node3D
	var far := 0.0 if hero == null else Vector2(hero.global_position.x - at.x, hero.global_position.z - at.z).length()
	if far > SOUND_RANGE:
		return
	Sfx.play_3d(level, names[_ring_rng.randi() % names.size()], db - far * SOUND_FALL, at, _ring_rng.randf_range(0.92, 1.1))


## Starts a ring of ripples at `at`.
func _ring_at(at: Vector3) -> void:
	if _rings == null:
		return
	var i := _ring_next
	_ring_next = (_ring_next + 1) % RINGS
	_ring_age[i] = 0.0
	_sound(RIPPLES, -14.0, at)
	_rings.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(at.x, 0.05, at.z)))
	_rings.set_instance_custom_data(i, Color(0, 0, 0, 0))


## How much of a swimming fish shows: half in open water (it swims deep), all of it under the ice.
func _base_fade() -> float:
	return lerpf(DEEP_FADE, 1.0, _cover)


## Sends a fish up to break the surface: see _startled's "surface" state.
func surface_fish(f: Dictionary) -> void:
	f.state = "surface"
	f.timer = 0.0
	f.rung = false


## Whether `pos` is on the water this fish swims in: clear of the banks of a pond, or between the banks of a stream.
func _on_water(pos: Vector3, lane: Dictionary) -> bool:
	if lane.is_empty():
		return level.pond_shore_at(pos) >= SHORE_MIN
	var a: Vector3 = lane.from
	var line: Vector3 = lane.to - a
	var along := clampf((pos - a).dot(line) / maxf(line.length_squared(), 0.01), 0.0, 1.0)
	var nearest := a + line * along
	return Vector2(pos.x - nearest.x, pos.z - nearest.z).length() <= lane.half


## A fish startled by a ring: it bolts, sinking as it goes, until it is gone (see DART_TIME); it comes back
## later from its home spot, fading in (see GONE_TIME). Returns true while the fish is not swimming about.
func _startled(f: Dictionary, delta: float) -> bool:
	var holder: Node3D = f.node
	var mat: ShaderMaterial = f.mat
	match f.state:
		"surface":
			# Up from the deep, barely under the skin of the water, then a flick of the fin (a roll) in a ring.
			f.timer += delta
			# It drifts on a little, barely moving, while it comes up and flicks.
			var next := holder.position + Vector3(sin(f.heading), 0, cos(f.heading)) * 0.12 * delta
			if _on_water(next, f.lane):
				holder.position = Vector3(next.x, holder.position.y, next.z)
			var up: float = clampf(f.timer / RISE_TIME, 0.0, 1.0)
			holder.position.y = lerpf(0.03, 0.055, up)
			mat.set_shader_parameter("fade", lerpf(_base_fade(), 1.0, smoothstep(0.0, 1.0, up)))
			if up >= 1.0 and not f.rung:
				f.rung = true
				_sound(SPLASHES, -13.0, holder.position)
				_ring_at(holder.position)
			if f.timer > RISE_TIME:
				var flick: float = f.timer - RISE_TIME
				holder.rotation.z = sin(flick * 26.0) * 0.5 * sin(PI * clampf(flick / FLICK_TIME, 0.0, 1.0))
				if flick >= FLICK_TIME:
					holder.rotation.z = 0.0
					_ring_at(holder.position)
					_sound(SPLASHES, -9.0, holder.position)
					f.state = "dart"
					f.timer = 0.0
					f.zig = true
					f.fade_from = 1.0
					f.heading += _ring_rng.randf_range(-1.0, 1.0)
		"shake":
			# Rooted to the spot, the body shivers hard and the nose jitters, then it bolts.
			f.timer += delta
			var k: float = clampf(f.timer / SHAKE_TIME, 0.0, 1.0)
			mat.set_shader_parameter("shake", sin(PI * minf(k * 1.4, 1.0)) * 0.5 + 0.5 * k)
			holder.rotation.y = f.heading + HEAD_TURN + sin(f.timer * 45.0) * 0.18 * k
			if f.timer >= SHAKE_TIME:
				mat.set_shader_parameter("shake", 0.0)
				_bolt_splash(holder.position)
				f.state = "dart"
				f.timer = 0.0
		"dart":
			f.timer += delta
			if f.zig:
				# Erratic: the heading jerks about as the fish dives.
				f.heading += sin(f.timer * 17.0 + f.heading * 3.0) * 6.0 * delta
			var k: float = clampf(f.timer / DART_TIME, 0.0, 1.0)
			var dir := Vector3(sin(f.heading), 0, cos(f.heading))
			var next := holder.position + dir * DART_SPEED * (1.0 - k * 0.4) * delta
			if _on_water(next, f.lane):
				holder.position = Vector3(next.x, holder.position.y, next.z)
			holder.position.y = lerpf(holder.position.y if k < 0.02 else 0.03, -DIVE_DEPTH, k * k)
			holder.rotation.y = f.heading + HEAD_TURN
			mat.set_shader_parameter("fade", lerpf(f.fade_from, 0.0, smoothstep(0.35, 1.0, k)))
			if k >= 1.0:
				f.state = "gone"
				f.timer = _ring_rng.randf_range(GONE_TIME.x, GONE_TIME.y)
				holder.visible = false
		"gone":
			f.timer -= delta
			if f.timer <= 0.0:
				holder.position = Vector3(f.home.x, 0.03, f.home.z)
				holder.visible = f.awake
				f.state = "return"
				f.timer = 0.0
		"return":
			f.timer += delta
			mat.set_shader_parameter("fade", smoothstep(0.0, 3.0, f.timer))
			if f.timer >= 3.0:
				f.state = "swim"
				mat.set_shader_parameter("fade", _base_fade())
		_:
			return false
	return true


## Fish near the hero swim; the others are hidden and paused (see ACTIVE_RANGE).
func _wake_near() -> void:
	var hero := level.player as Node3D
	for f in _fish:
		var holder: Node3D = f.node
		var near := hero == null or holder.global_position.distance_to(hero.global_position) <= active_range
		if near != f.awake:
			f.awake = near
			holder.visible = near and f.state != "gone"
			holder.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED


## The models' heads are at their -y end, which points along +z once they are laid flat: already on the
## heading (sin h, cos h), so no extra turn.
const HEAD_TURN := 0.0
