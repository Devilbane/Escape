class_name Crows
extends Node3D
## The crows of the farmland: in autumn and winter one or two flocks of them come down on the
## fields of the farming valley (see CropFields), strutting about on the stubble and pecking for
## grain. Walk up to them and the whole flock goes up at once, in a clatter of wings and a chorus
## of caws, circles over the fields calling to each other, drifts on to another field and drops
## down to peck again. They roost at night, and by spring and summer, when the crops stand high,
## they are gone.
##
## Each crow is an instance of the village birds' MultiMesh (see VillageBirds.bird_mesh and
## shaders/bird.gdshader, whose kind 7 is the crow: glossy black, with a blue-violet sheen, feather
## texture and a heavy beak), the wings beating in the vertex shader, so a whole flock costs one draw
## and a few lines a frame. A flock more than AWAKE_RANGE metres from the hero keeps still, and
## one that was in the air when the hero left simply lands.
## The calls and the clatter of wings are synthesised by tools/make_crow_sounds.py (our own work, CC0).
## Tested by tests/crows.gd.

## At most this many flocks live on a map, how many crows are in one, and how big a crow is drawn (a
## carrion crow is about 50 cm; the bird mesh is a small songbird).
const MAX_FLOCKS := 2
const FLOCK_SIZE := Vector2i(5, 8)
const SIZE := 2.5
## Beyond this distance from the hero (metres) a flock keeps still, and its calls are heard no farther
## than HEAR_RANGE.
const AWAKE_RANGE := 95.0
const HEAR_RANGE := 70.0
## The hours between which the crows are about: they roost at night.
const ACTIVE_FROM := 6.5
const ACTIVE_UNTIL := 18.0
## On the ground a flock goes up when the hero comes this close (metres), and then stays calm for
## CALM seconds after it lands, however near he is.
const SHY := 9.0
const CALM := 8.0
## A flock spreads this far (metres) over the field it feeds on, and the crows keep this much room.
const SPREAD := 2.2
const ROOM := 0.7
## A flight: the seconds the flock takes to rise (each crow setting off a little after the one before),
## to circle, and to come down; how fast they fly (metres a second), the radius of the circle and the
## height at which they fly (metres over the ground).
const RISE := 1.8
const CIRCLE := Vector2(9.0, 15.0)
const DOWN := 3.4
const SPEED := 6.5
const RADIUS := Vector2(7.0, 15.0)
const HEIGHT := Vector2(5.0, 10.0)
const STAGGER := 0.5
## The next field is at least this far from the one they leave (metres), and at least this far from
## the hero.
const MOVE_MIN := 14.0
const HERO_MIN := 16.0
## Wing beats: radians a second cruising, how much faster they flutter setting off and coming in, and
## how wide the wings swing then (see bird.gdshader).
const BEATS := 17.0
const FLUTTER := 2.6
const FLUTTER_SWING := 1.05
const SETTLE := 4.0
## On the ground: the seconds between two dips of the head, how long a dip lasts, how far and how
## long a hop is and how high.
const DIP_EVERY := Vector2(0.5, 1.8)
const DIP_TIME := 0.3
const HOP := Vector2(0.25, 0.7)
const HOP_TIME := 0.26
const HOP_HEIGHT := 0.06
const TURN := 8.0
## Seconds between two caws of a flock on the ground, and in the air.
const CAW_GROUND := Vector2(4.0, 11.0)
const CAW_AIR := Vector2(1.2, 3.0)
## Sound volumes: close by (dB), how fast they fade with distance (dB a metre beyond FADE_FROM) and
## how much quieter it is when the hero is under cover.
const CAW_DB := -5.0
const FLUTTER_DB := -3.0
const FADE_FROM := 10.0
const FADE_RATE := 0.4
const INDOORS_DB := -10.0
const CAWS := ["crow_caw_0", "crow_caw_1", "crow_caw_2", "crow_caw_3"]
const STARTLED := "crow_caw_4"
const FLUTTER_SOUND := "crow_flutter"
## How high the feet are over the ground, bare and over the snow (metres).
const FEET := 0.06
const ON_SNOW := 0.1

## Reported when the flock takes off, and for each call a crow makes (for the tests).
signal took_off(flock: int)
signal cawed(flock: int, sound: String)
signal landed(flock: int)

## Each flock: {"spot" (the field it is on, or leaves), "land" (the field it flies to), "state"
## ("ground" or "air"), "t" (seconds into the flight), "length" (its seconds), "dir" (circling left or
## right), "calm" (seconds it ignores the hero), "caw" (seconds to its next call), "crows" (indices)}.
var flocks: Array[Dictionary] = []
## Each crow: {"flock", "at", "from", "land" (where it comes down), "yaw", "face", "wing", "fold",
## "dip", "dipping", "hop", "hop_from", "hop_to", "phase", "angle" (on the circle), "radius", "alt",
## "delay" (seconds after the flock before it goes up), "pace", "bank", "pitch"}.
var crows: Array[Dictionary] = []
## Whether it is autumn or winter, so the crows are about at all (see set_season).
var active := false
var level: Node3D
var _fields: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _mm: MultiMesh
var _clock := 0.0
var _hero := Vector3.INF
var _covered := false
static var _mesh: Mesh


## Builds the flocks on the fields: `field_spots` are the middles of the field tiles (the low ones, the
## stubble, come first; see Outdoor), `tile` is their size, and `level_node` (or null) tells where snow lies.
func _init(level_node: Node3D, field_spots: Array[Vector3], tile: float, seed_text := "") -> void:
	name = "Crows"
	level = level_node
	_fields = field_spots
	_rng.seed = hash(seed_text + "kraehen")
	visible = false
	if _fields.is_empty():
		return
	var count := 1 if _fields.size() < 4 else MAX_FLOCKS
	var used: Array[Vector3] = []
	for f in count:
		var spot := _pick_field(used, 0.0)
		if spot == Vector3.INF:
			break
		used.append(spot)
		var flock := {"spot": spot, "land": spot, "state": "ground", "t": 0.0, "length": 0.0, "dir": 1.0,
				"calm": 0.0, "caw": _rng.randf_range(CAW_GROUND.x, CAW_GROUND.y), "crows": []}
		flocks.append(flock)
		for i in _rng.randi_range(FLOCK_SIZE.x, FLOCK_SIZE.y):
			(flock.crows as Array).append(crows.size())
			crows.append(_new_crow(flocks.size() - 1, spot))
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	# White instance colours: without any, the compatibility renderer gives the shader a vertex COLOR of
	# zero, and the parts and wings are lost (see VillageBirds).
	_mm.use_colors = true
	if _mesh == null:
		_mesh = VillageBirds.bird_mesh()
	_mm.mesh = _mesh
	_mm.instance_count = crows.size()
	for i in crows.size():
		_mm.set_instance_color(i, Color.WHITE)
	var node := MultiMeshInstance3D.new()
	node.name = "CrowMesh"
	node.multimesh = _mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = VillageBirds.SHADER
	node.material_override = mat
	# The whole flock is one box: cheap to cull, but never culled while it circles over the fields.
	node.extra_cull_margin = 100.0
	add_child(node)
	for i in crows.size():
		_show(i)


## Whether the crows are about at an hour (by day).
static func about_at(hour: float) -> bool:
	return hour >= ACTIVE_FROM and hour < ACTIVE_UNTIL


## Whether crows come to the fields on a season day: in autumn and in winter.
static func comes_in(day: int) -> bool:
	return Weather.is_autumn(day) or Weather.is_winter(day)


## Crows come in autumn and winter, and are gone the rest of the year.
func set_season(day: int) -> void:
	active = comes_in(day)
	if not active:
		visible = false


## A field tile for a flock: not within HERO_MIN of `hero_at` and at least MOVE_MIN from `from`, the
## nearer ones preferred, and not one of `avoid` (fields other flocks are on). Vector3.INF when there is none.
func _pick_field(avoid: Array[Vector3], min_from: float, from := Vector3.INF, hero_at := Vector3.INF) -> Vector3:
	var options: Array[Vector3] = []
	for f in _fields:
		if avoid.any(func(a: Vector3): return _flat(a, f) < 8.0):
			continue
		if from != Vector3.INF and _flat(from, f) < min_from:
			continue
		if hero_at != Vector3.INF and _flat(hero_at, f) < HERO_MIN:
			continue
		options.append(f)
	if options.is_empty():
		return Vector3.INF
	if from == Vector3.INF:
		return options[_rng.randi() % options.size()]
	# Take one of the three nearest to the one they leave: a hop over the fields, not across the map.
	options.sort_custom(func(a: Vector3, b: Vector3): return _flat(a, from) < _flat(b, from))
	return options[_rng.randi() % mini(3, options.size())]


func _new_crow(flock: int, spot: Vector3) -> Dictionary:
	var phase := _rng.randf() * TAU
	var at := _free_spot(spot, flock)
	return {"flock": flock, "at": at, "from": at, "land": at, "yaw": _rng.randf() * TAU, "face": _rng.randf() * TAU,
			"wing": phase, "fold": 1.0, "dip": _rng.randf_range(DIP_EVERY.x, DIP_EVERY.y), "dipping": 0.0,
			"hop": 0.0, "hop_from": at, "hop_to": at, "phase": phase, "angle": _rng.randf() * TAU,
			"radius": _rng.randf_range(RADIUS.x, RADIUS.y), "alt": _rng.randf_range(HEIGHT.x, HEIGHT.y),
			"delay": _rng.randf() * STAGGER, "pace": _rng.randf_range(0.85, 1.15), "bank": 0.0, "pitch": 0.0}


## A place on the field round `spot` with ROOM to the other crows of the flock.
func _free_spot(spot: Vector3, flock: int) -> Vector3:
	var best := spot
	for tries in 8:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * SPREAD
		var p := spot + Vector3(cos(a) * r, _feet(), sin(a) * r)
		best = p
		var crowded := false
		for c: Dictionary in crows:
			if c.flock == flock and _flat(c.land, p) < ROOM:
				crowded = true
				break
		if not crowded:
			break
	return best


## How high the crows' feet are over the ground of the fields (over the snow while it lies).
func _feet() -> float:
	var snow = level.get("snow") if level != null else null
	return ON_SNOW if snow != null and snow.lies() else FEET


## Moves the crows on by `delta` seconds. `hero` is where the hero is, `hour` the hour of the day and
## `covered` whether he is under a roof (the calls are quieter then).
func tick(delta: float, hero: Vector3, hour: float, covered := false) -> void:
	var out := not active or not about_at(hour)
	if visible == out:
		visible = not out
	if out:
		return
	_clock += delta
	hero = to_local(hero) if is_inside_tree() else hero
	_hero = hero
	_covered = covered
	for f in flocks.size():
		var flock := flocks[f]
		var near := _flat(flock.spot, hero) < AWAKE_RANGE or _flat(flock.land, hero) < AWAKE_RANGE
		if not near:
			if flock.state == "air":
				_land_now(f)
			continue
		if flock.state == "air":
			_fly(f, delta)
		else:
			_graze(f, delta, hero)
		for i: int in flock.crows:
			_show(i)


## Whether any of the flocks is in the air.
func flying() -> bool:
	return flocks.any(func(f: Dictionary): return f.state == "air")


# --- On the ground ----------------------------------------------------------------

func _graze(f: int, delta: float, hero: Vector3) -> void:
	var flock := flocks[f]
	flock.calm = maxf(0.0, float(flock.calm) - delta)
	if flock.calm <= 0.0:
		for i: int in flock.crows:
			if _flat(crows[i].at, hero) < SHY:
				startle(f)
				return
	flock.caw = float(flock.caw) - delta
	if flock.caw <= 0.0:
		flock.caw = _rng.randf_range(CAW_GROUND.x, CAW_GROUND.y)
		var voice: Dictionary = crows[(flock.crows as Array)[_rng.randi() % (flock.crows as Array).size()]]
		_caw(f, CAWS[_rng.randi() % CAWS.size()], voice.at)
	for i: int in flock.crows:
		var c := crows[i]
		c.fold = move_toward(float(c.fold), 1.0, delta * SETTLE)
		c.wing = fmod(float(c.wing) + delta * BEATS * lerpf(1.0, FLUTTER, 1.0 - float(c.fold)), TAU)
		c.yaw = lerp_angle(float(c.yaw), float(c.face), minf(1.0, delta * TURN))
		if c.hop > 0.0:
			c.hop = maxf(0.0, float(c.hop) - delta)
			var k := 1.0 - float(c.hop) / HOP_TIME
			c.at = (c.hop_from as Vector3).lerp(c.hop_to, k) + Vector3.UP * sin(PI * k) * HOP_HEIGHT
			continue
		if c.dipping > 0.0:
			c.dipping = float(c.dipping) - delta
			continue
		c.dip = float(c.dip) - delta
		if c.dip <= 0.0:
			c.dipping = DIP_TIME
			c.dip = _rng.randf_range(DIP_EVERY.x, DIP_EVERY.y)
		elif _rng.randf() < delta * 0.9:
			_hop(c, flock.spot)


## A crow turns a little and strides a short way that way, or only looks round; it keeps to its field
## and never closer to another crow than ROOM.
func _hop(c: Dictionary, spot: Vector3) -> void:
	c.face = float(c.yaw) + _rng.randf_range(-1.2, 1.2)
	if _rng.randf() < 0.3:
		return
	var from: Vector3 = c.at
	var to := from + Vector3(sin(c.face), 0, cos(c.face)) * _rng.randf_range(HOP.x, HOP.y)
	if _flat(to, spot) > SPREAD * 1.3:
		return
	for o: Dictionary in crows:
		if not is_same(o, c) and o.flock == c.flock and _flat(o.at, to) < ROOM * 0.6:
			return
	c.hop_from = from
	c.hop_to = to
	c.hop = HOP_TIME


# --- In the air -------------------------------------------------------------------

## The flock goes up: a clatter of wings and a startled chorus; it circles over the field, drifts on to
## another one (not one near the hero) and comes down there. Does nothing for a flock already in the air.
func startle(f: int) -> void:
	var flock := flocks[f]
	if flock.state == "air":
		return
	var avoid: Array[Vector3] = []
	for g in flocks.size():
		if g != f:
			avoid.append(flocks[g].land)
	var land := _pick_field(avoid, MOVE_MIN, flock.spot, _hero)
	if land == Vector3.INF:
		land = _pick_field(avoid, 0.0, flock.spot)
	if land == Vector3.INF:
		land = flock.spot
	flock.land = land
	flock.state = "air"
	flock.t = 0.0
	flock.length = RISE + _rng.randf_range(CIRCLE.x, CIRCLE.y) + DOWN
	flock.dir = 1.0 if _rng.randf() < 0.5 else -1.0
	flock.caw = 0.4
	for i: int in flock.crows:
		var c := crows[i]
		c.from = c.at
		c.hop = 0.0
		c.dipping = 0.0
		c.land = _free_spot(land, f)
		c.delay = _rng.randf() * STAGGER
		c.radius = _rng.randf_range(RADIUS.x, RADIUS.y)
		c.alt = _rng.randf_range(HEIGHT.x, HEIGHT.y)
		# Each starts the circle where it is, so nobody swings across the others on the way up.
		c.angle = atan2(float(c.at.z) - float(flock.spot.z), float(c.at.x) - float(flock.spot.x)) + _rng.randf_range(-0.6, 0.6)
		c.bank = 0.0
	took_off.emit(f)
	_clatter(f, FLUTTER_SOUND, FLUTTER_DB)
	_caw(f, STARTLED, flock.spot)


func _fly(f: int, delta: float) -> void:
	var flock := flocks[f]
	flock.t = float(flock.t) + delta
	var t: float = flock.t
	var length: float = flock.length
	# The middle of the circle drifts from the field they left to the one they come down on.
	var drift := smoothstep(RISE, length - DOWN, t)
	flock.caw = float(flock.caw) - delta
	if flock.caw <= 0.0 and t < length - 1.0:
		flock.caw = _rng.randf_range(CAW_AIR.x, CAW_AIR.y)
		var c := crows[(flock.crows as Array)[_rng.randi() % (flock.crows as Array).size()]]
		_caw(f, CAWS[_rng.randi() % CAWS.size()], c.at)
	for i: int in flock.crows:
		var c := crows[i]
		var was: Vector3 = c.at
		var phase_t: float = t - float(c.delay)
		if phase_t <= 0.0:
			# Not off yet: ruffling, the wings opening.
			c.fold = move_toward(float(c.fold), 0.0, delta * SETTLE * 1.5)
			c.wing = fmod(float(c.wing) + delta * BEATS * FLUTTER, TAU)
			continue
		var centre := (flock.spot as Vector3).lerp(flock.land, drift)
		var angle: float = c.angle + float(flock.dir) * phase_t * SPEED * float(c.pace) / float(c.radius)
		var up := Vector3.UP * (float(c.alt) + _feet())
		var orbit := centre + Vector3(cos(angle) * float(c.radius), 0.0, sin(angle) * float(c.radius)) + up
		var landing := t > length - DOWN
		var rise := phase_t < RISE
		var at := orbit
		if rise:
			var u := smoothstep(0.0, 1.0, phase_t / RISE)
			var top := (c.from as Vector3).lerp(orbit, u)
			# Up first, then out: a steep climb, not a ramp.
			top.y = lerpf(float(c.from.y), orbit.y, sqrt(clampf(phase_t / RISE, 0.0, 1.0)))
			at = top
		elif landing:
			var u := clampf((t - (length - DOWN)) / DOWN, 0.0, 1.0)
			# Where the crow would be on the circle as the descent begins, flying on to its spot.
			var a0: float = c.angle + float(flock.dir) * (length - DOWN - float(c.delay)) * SPEED * float(c.pace) / float(c.radius)
			var start := (flock.land as Vector3) + Vector3(cos(a0) * float(c.radius), float(c.alt) + _feet(), sin(a0) * float(c.radius))
			at = start.lerp(c.land, smoothstep(0.0, 1.0, u))
			# Dropping late, in a flare: high until near the end.
			at.y = lerpf(start.y, float(c.land.y), pow(u, 1.8))
		c.at = at
		var dir := at - was
		if delta > 0.0 and Vector2(dir.x, dir.z).length() > 0.001:
			var yaw := atan2(dir.x, dir.z)
			var turn := wrapf(yaw - float(c.yaw), -PI, PI) / delta
			c.bank = lerpf(float(c.bank), clampf(turn * 0.18, -0.5, 0.5), minf(1.0, delta * 5.0))
			c.yaw = yaw
		c.face = c.yaw
		c.fold = move_toward(float(c.fold), 0.0, delta * SETTLE * 2.0)
		var hard := _hard(phase_t, t, length)
		c.wing = fmod(float(c.wing) + delta * BEATS * lerpf(1.0, FLUTTER, hard) * (0.55 if _gliding(c, t) else 1.0), TAU)
		c.pitch = -0.3 if rise else (-0.4 if landing and t > length - DOWN * 0.4 else 0.12)
	if t >= length:
		_land_now(f)
		landed.emit(f)
		_clatter(f, FLUTTER_SOUND, FLUTTER_DB - 8.0)


## How hard a crow flutters in the air (0 to 1): fully as it rises and again as it comes in to land.
func _hard(phase_t: float, t: float, length: float) -> float:
	var up := 1.0 - smoothstep(RISE * 0.6, RISE + 1.6, phase_t)
	var down := smoothstep(length - 1.6, length - 0.2, t)
	return maxf(up, down)


## Whether a cruising crow holds its wings out and glides a moment (every so often, each in its time).
func _gliding(c: Dictionary, t: float) -> bool:
	return sin(t * 0.8 + float(c.phase)) > 0.55


## The flock is down at once at its landing field, each crow on its spot (when the hero left while they
## were up, or at the end of the flight).
func _land_now(f: int) -> void:
	var flock := flocks[f]
	flock.state = "ground"
	flock.spot = flock.land
	flock.t = 0.0
	flock.calm = CALM
	for i: int in flock.crows:
		var c := crows[i]
		c.at = c.land
		c.from = c.land
		c.hop = 0.0
		c.dipping = 0.0
		c.bank = 0.0
		c.pitch = 0.0
		c.dip = _rng.randf_range(DIP_EVERY.x, DIP_EVERY.y)
		_show(i)


# --- Sounds -----------------------------------------------------------------------

## A crow of flock `f` calls from `at`.
func _caw(f: int, sound: String, at: Vector3) -> void:
	cawed.emit(f, sound)
	_play(sound, CAW_DB, at, _rng.randf_range(0.9, 1.1))
	if sound == STARTLED:
		# The others join in, a moment apart.
		for k in 2:
			var timer := get_tree().create_timer(_rng.randf_range(0.2, 0.9)) if is_inside_tree() else null
			if timer != null:
				timer.timeout.connect(func(): if is_inside_tree(): _play(CAWS[_rng.randi() % CAWS.size()], CAW_DB - 2.0, at, _rng.randf_range(0.85, 1.15)))


## The clatter of the flock's wings.
func _clatter(f: int, sound: String, db: float) -> void:
	_play(sound, db, flocks[f].spot + Vector3(0, 1.0, 0), _rng.randf_range(0.95, 1.05))


func _play(sound: String, db: float, at: Vector3, pitch: float) -> void:
	if _hero == Vector3.INF or not is_inside_tree():
		return
	var d := _flat(at, _hero)
	if d > HEAR_RANGE:
		return
	var loud := db - FADE_RATE * maxf(0.0, d - FADE_FROM) + (INDOORS_DB if _covered else 0.0)
	if loud > -34.0:
		Sfx.play_3d(self, sound, loud, to_global(at), pitch)


# --- Drawing ----------------------------------------------------------------------

func _show(i: int) -> void:
	var c := crows[i]
	var flock := flocks[int(c.flock)]
	var flying: bool = flock.state == "air" and float(flock.t) > float(c.delay)
	var kind := (float(VillageBirds.CROW_KIND) + 0.5) / VillageBirds.SHADER_KINDS
	var basis := Basis(Vector3.UP, c.yaw).scaled(Vector3.ONE * SIZE)
	var settling := 1.0 - float(c.fold)
	var swing := 0.0
	if flying:
		var hard := _hard(float(flock.t) - float(c.delay), flock.t, flock.length)
		# Beating deep, then holding the wings out to glide.
		swing = lerpf(0.4 if _gliding(c, flock.t) else 0.85, FLUTTER_SWING, hard)
		basis = basis * Basis(Vector3.RIGHT, float(c.pitch)) * Basis(Vector3.FORWARD, float(c.bank))
	else:
		swing = settling * FLUTTER_SWING
		if flock.state == "ground":
			if c.dipping > 0.0:
				# The head goes down into the stubble and up again.
				basis = basis * Basis(Vector3.RIGHT, sin(PI * (1.0 - float(c.dipping) / DIP_TIME)) * 0.8)
			if settling > 0.0:
				basis = basis * Basis(Vector3.RIGHT, float(c.pitch) * settling) * Basis(Vector3.FORWARD, float(c.bank) * settling)
	_mm.set_instance_custom_data(i, Color(c.wing, swing, c.fold, kind))
	_mm.set_instance_transform(i, Transform3D(basis, c.at))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
