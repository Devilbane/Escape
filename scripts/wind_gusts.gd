class_name WindGusts
extends Node
## Now and then a gust of wind sweeps up the light litter lying around the hero: fallen leaves
## rise as high as a person and are blown on across the screen, chaotic and erratic (each pushed up, down and sideways on its own and turning every which way) but always along the wind, until they settle again,
## straw rides along, wood chips only skid and a heap of autumn
## leaves shifts a little. In winter there are no leaves to carry: the gust whirls up a flurry of
## snow instead (see _flurry).
##
## No two gusts are alike: each has a force of its own (see FORCE), from a light, slow drift that
## lifts a few leaves a little way to a strong, fast blow that carries many of them high and far.
##
## Autumn is the season of wind: a gust every ten to thirty seconds. In the other seasons they are
## rare (one every minute or two).
##
## It is cheap. The leaves are the litter's own MultiMesh instances (see SurfaceLife), moved a
## little each frame while a gust lasts and left where they land; the snow is one small MultiMesh
## that is hidden between gusts. Only the pieces of one gust are touched, and nothing runs between
## gusts but a timer. The Performance preset has no gusts, Quality has more of them.
##
## The weather tells the wind too (see FlagWind.WINDS): rare, weak gusts in fog, frequent, strong
## ones in a storm. Pieces only land on open ground (never in water, under a wall, in a dug hole,
## in a built house or on a tree's tile).

## Seconds between gusts under clear skies (at a wind strength of 1), at random in this range.
const EVERY_AUTUMN := Vector2(10.0, 30.0)
const EVERY_OTHER := Vector2(60.0, 140.0)
## Pieces one gust moves, before the wind's strength and the quality preset.
const PIECES := Vector2i(10, 18)
const MAX_PIECES := 40
## Pieces are taken from this far round the hero (metres).
const NEAR := 2.5
const FAR := 15.0
## How far a piece travels in a breeze (metres), by what it is: leaves float far, chips skid.
const TRAVEL := {"leaf": Vector2(14.0, 30.0), "straw": Vector2(8.0, 16.0), "chip": Vector2(0.6, 1.5), "fallen": Vector2(0.4, 1.1)}
## How high it is lifted (metres).
const LIFT := {"leaf": Vector2(1.0, 2.2), "straw": Vector2(0.6, 1.5), "chip": Vector2(0.05, 0.2), "fallen": Vector2(0.02, 0.06)}
## How long a flight takes (seconds): slow, like a feather's.
const DURATION := Vector2(6.0, 9.5)
## The gust sweeps along the wind: the furthest piece starts this long after the nearest (seconds).
const SWEEP := 2.0
## How much the wind's direction turns between gusts (radians, at most).
const TURN := 0.7
## How hard a gust blows on top of the weather's wind (1 is the weather's breeze): drawn at random
## for every gust, mostly light and slow, now and then strong and fast. It sets how many pieces are
## taken, how high and far they go and how quickly.
const FORCE := Vector2(0.3, 1.6)
## The tiles pieces may fly over and land on.
const OPEN := SurfaceLife.GROUND + SurfaceLife.PATH + SurfaceLife.SQUARE
## The winter flurry: flakes per gust, their size (metres), how far they are blown and how high.
const FLAKES := 80
const FLAKE_SIZE := 0.07
const FLAKE_TRAVEL := Vector2(10.0, 26.0)
const FLAKE_LIFT := Vector2(0.3, 2.2)

var life: SurfaceLife
## The pieces in the air: {entry, from, to, delay, dur, lift, axis, spin, yaw, light, and the settings of its erratic motion}.
var _moving: Array = []
var _clock := 0.0
var _timer := 0.0
## The way the wind blows now (angle on the ground plane).
var _angle := 0.0
## The force of the gust now, and of the last one (for the tests).
var force := 1.0
var _rng := RandomNumberGenerator.new()
## The flurry of snow: its MultiMesh (made the first winter gust) and the flakes in the air.
var _snow: MultiMeshInstance3D
var _flakes: Array = []
## Gusts so far and pieces they moved (for the tests).
var gusts := 0
var moved := 0


func _init(owner_life: SurfaceLife) -> void:
	life = owner_life
	name = "WindGusts"


func _ready() -> void:
	_rng.seed = hash(life.level.level_name + ":gusts")
	_angle = _rng.randf() * TAU
	_timer = _rng.randf_range(3.0, 10.0) if _autumn() else _rng.randf_range(EVERY_OTHER.x * 0.3, EVERY_OTHER.y * 0.5)


## Whether this quality preset has gusts at all.
static func enabled() -> bool:
	return Graphics.preset != Graphics.PERFORMANCE


## The share of the usual number of pieces a gust moves in this preset.
static func quality_scale() -> float:
	return 1.5 if Graphics.preset == Graphics.QUALITY else 1.0


func _season_day() -> int:
	return int(life.level.get("season_day")) if "season_day" in life.level else 0


func _autumn() -> bool:
	return Weather.is_autumn(_season_day())


func _winter() -> bool:
	return Weather.is_winter(_season_day())


## The seconds between gusts in the season (before the wind's strength).
func every() -> Vector2:
	return EVERY_AUTUMN if _autumn() else EVERY_OTHER


## How hard the wind blows in the level's weather (1 is a breeze).
func strength() -> float:
	return FlagWind.wind_for(life.level.get("weather") if "weather" in life.level else "").x


func active() -> int:
	return _moving.size() + _flakes.size()


func _process(delta: float) -> void:
	if active() > 0:
		_clock += delta
		_move()
		_move_flakes()
	if not enabled() or life.level.player == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var s := strength()
	var span := every()
	# Fog lies still; a storm blows often.
	_timer = _rng.randf_range(span.x, span.y) / clampf(s, 0.35, 2.6)
	if s >= 0.5:
		gust(s)


## Blows one gust now, with the wind at strength `s`: sets pieces of litter near the hero flying
## (in winter a flurry of snow). Returns how many pieces it set flying.
func gust(s: float) -> int:
	if life.level.player == null or active() > 0:
		return 0
	_angle += _rng.randf_range(-TURN, TURN)
	var dir := Vector3(cos(_angle), 0, sin(_angle))
	var hero: Vector3 = life.level.player.global_position
	_clock = 0.0
	gusts += 1
	# Weather and the gust's own force together.
	force = lerpf(FORCE.x, FORCE.y, pow(_rng.randf(), 1.4))
	s *= force
	if _winter():
		_flurry(dir, s, hero)
		return _flakes.size()
	var want := mini(MAX_PIECES, roundi(_rng.randi_range(PIECES.x, PIECES.y) * s * quality_scale()))
	var pool := _pool(hero)
	while want > 0 and not pool.is_empty():
		var at := _rng.randi() % pool.size()
		var e: Array = pool[at]
		pool.remove_at(at)
		if _launch(e, dir, s, hero):
			want -= 1
			moved += 1
	return _moving.size()


## The litter that may be stirred: leaves, straw, chips and heaps of fallen leaves round the hero.
func _pool(hero: Vector3) -> Array:
	var pool: Array = []
	var c: Vector2i = life.level.world_to_cell(hero)
	var reach := ceili(FAR / Level.TILE)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for e: Array in life._cell_litter.get(c + Vector2i(dx, dy), []):
				if not TRAVEL.has(e[4]) or (e[4] == "fallen" and not life._autumn):
					continue
				var o: Vector3 = e[2]
				var d := Vector2(o.x - hero.x, o.z - hero.z).length()
				if d < NEAR or d > FAR or not is_instance_valid(e[0]):
					continue
				if life._lifted.has("%d:%d" % [(e[0] as MultiMesh).get_instance_id(), e[1]]):
					continue
				pool.append(e)
	return pool


func _launch(e: Array, dir: Vector3, s: float, hero: Vector3) -> bool:
	var kind: String = e[4]
	var from: Vector3 = e[2]
	var span: Vector2 = TRAVEL[kind]
	var dist := _rng.randf_range(span.x, span.y) * clampf(0.35 + 0.65 * s, 0.35, 1.6)
	# A little off the wind's own way, as every piece catches it differently.
	var way := dir.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	var to := from + way * dist
	if not _clear_way(from, to):
		# Not so far then: a wall or the water is in the way.
		to = from + way * dist * 0.4
		if dist * 0.4 < 1.0 or not _clear_way(from, to):
			return false
	var lift: Vector2 = LIFT[kind]
	var light := kind == "leaf" or kind == "straw"
	_moving.append({
		"entry": e, "from": from, "to": to,
		"delay": clampf((from - hero).dot(dir) / FAR * 0.5 + 0.5, 0.0, 1.0) * SWEEP + _rng.randf_range(0.0, 0.4),
		"dur": (_rng.randf_range(DURATION.x, DURATION.y) if light else _rng.randf_range(1.2, 2.2)) / _pace(s),
		"lift": _rng.randf_range(lift.x, lift.y) * clampf(0.35 + 0.65 * s, 0.35, 1.5),
		"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.2, 1), _rng.randf_range(-1, 1)).normalized(),
		"spin": _rng.randf_range(2.0, 5.0) if light else _rng.randf_range(0.05, 0.3),
		"fh": _noise_freqs(), "ph": _noise_phases(),
		"fl": _noise_freqs(), "pl": _noise_phases(),
		"fa": _noise_freqs(), "pa": _noise_phases(),
		"fb": _noise_freqs(), "pb": _noise_phases(),
		"flip_hz": _rng.randf_range(3.0, 5.0), "flip_ph": _rng.randf_range(0.0, TAU), "bob_ph": _rng.randf_range(0.0, TAU),
		"axis2": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(),
		"yaw": _rng.randf_range(-1.5, 1.5) if light else _rng.randf_range(-0.5, 0.5),
		"light": light,
	})
	return true


## Whether the piece may fly from `a` to `b`: open ground all the way, and not into a hole or a house.
func _clear_way(a: Vector3, b: Vector3) -> bool:
	var steps := ceili(a.distance_to(b))
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		if not OPEN.contains(life.level.cell_char(life.level.world_to_cell(p))):
			return false
	for r: Rect2 in life._holes + life._built:
		if r.grow(0.4).has_point(Vector2(b.x, b.z)):
			return false
	return true


## How much faster than usual a gust of strength `s` carries its pieces: a light one is slow,
## a strong one quick.
static func _pace(s: float) -> float:
	return clampf(0.55 + 0.45 * s, 0.6, 1.5)


## A restless value between -1 and 1 that wanders as `t` runs (three sines of unrelated speed).
static func erratic(t: float, f: Vector3, ph: Vector3) -> float:
	return (sin(f.x * t + ph.x) + 0.6 * sin(f.y * t + ph.y) + 0.4 * sin(f.z * t + ph.z)) * 0.5


func _noise_freqs() -> Vector3:
	return Vector3(_rng.randf_range(8.0, 22.0), _rng.randf_range(14.0, 34.0), _rng.randf_range(22.0, 48.0))


func _noise_phases() -> Vector3:
	return Vector3(_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU))


## How high a piece is at `t` (0 to 1) of its flight, as a share of its lift, with `n` (see erratic)
## the piece's own restlessness: it is taken up quickly, then wanders up and down, surging and
## dropping at random with only a slight sink, and settles in the last stretch. Zero at both ends.
static func height_share(t: float, n: float) -> float:
	var rise := pow(minf(1.0, t / 0.1), 1.5)
	var settle := pow(minf(1.0, (1.0 - t) / 0.15), 1.5)
	return rise * settle * (1.0 - 0.35 * t) * clampf(0.55 + 0.5 * n, 0.05, 1.2)


func _move() -> void:
	var left: Array = []
	for m: Dictionary in _moving:
		var e: Array = m.entry
		if not is_instance_valid(e[0]):
			continue
		var t := clampf((_clock - m.delay) / m.dur, 0.0, 1.0)
		var flat: Transform3D = e[3]
		var yawed := Basis(Vector3.UP, m.yaw + m.spin)
		var key := "%d:%d" % [(e[0] as MultiMesh).get_instance_id(), e[1]]
		var lifted: bool = life._lifted.has(key)
		if t >= 1.0:
			# Lands: this is where the piece lies now.
			var home := Transform3D(yawed * flat.basis, flat.origin + (m.to - m.from))
			e[2] = home.origin
			e[3] = home
			if not lifted:
				(e[0] as MultiMesh).set_instance_transform(e[1], home)
			continue
		left.append(m)
		if t <= 0.0 or lifted:
			continue
		var share := height_share(t, erratic(t, m.fh, m.ph))
		var along: Vector3 = (m.to as Vector3) - (m.from as Vector3)
		var side_axis := Vector3.UP.cross(along).normalized()
		# Pushed this way and that on the way, but always on along the wind.
		var calm := minf(1.0, t / 0.1) * minf(1.0, (1.0 - t) / 0.15)
		var sway := side_axis * erratic(t, m.fl, m.pl) * 1.8 * calm
		var surge := erratic(t, m.fl.zxy, m.pl.yzx) * 0.04 * calm
		# From a recorded reference (see docs/wind_reference.md): about every quarter of a second
		# the leaf flips edge-on and back, it bobs about 1.4 times a second, and it surges a little.
		var secs: float = t * m.dur
		var flip: float = sin(secs * TAU * m.flip_hz + m.flip_ph)
		var bob: float = sin(secs * TAU * 1.4 + m.bob_ph) * 0.15 * calm
		var basis := flat.basis
		if m.light:
			# Its own wild turning on all axes, never the same as its neighbour's.
			var yaw: float = m.yaw * t + m.spin * t + erratic(t, m.fa, m.pa) * 2.2 * calm
			basis = Basis(along.normalized(), flip * 1.1 * calm) * Basis(m.axis, erratic(t, m.fb, m.pb) * 2.0 * calm) * Basis(m.axis2, erratic(t, m.fa.yzx, m.pb.zxy) * 1.6 * calm) * Basis(Vector3.UP, yaw) * flat.basis
		else:
			basis = Basis(Vector3.UP, m.yaw * t + m.spin * t) * flat.basis
		var origin: Vector3 = (m.from as Vector3).lerp(m.to, clampf(ease_out(t) + surge, 0.0, 1.0)) + sway + Vector3(0, m.lift * share + bob, 0)
		(e[0] as MultiMesh).set_instance_transform(e[1], Transform3D(basis, origin + (flat.origin - m.from)))
	_moving = left


## Fast at first as the gust takes it, slower as it drifts down.
static func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 1.6)


## Winter: a flurry of snow lifts off the ground round the hero, drifts along the wind and
## settles again (one MultiMesh of tiny flat flakes, hidden between gusts).
func _flurry(dir: Vector3, s: float, hero: Vector3) -> void:
	if _snow == null:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * FLAKE_SIZE
		mm.mesh = quad
		mm.instance_count = int(FLAKES * 1.5)
		_snow = MultiMeshInstance3D.new()
		_snow.name = "SnowFlurry"
		_snow.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color(0.95, 0.97, 1.0, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_snow.material_override = mat
		_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_snow.extra_cull_margin = 60.0
		add_child(_snow)
	var count := mini((_snow.multimesh as MultiMesh).instance_count, roundi(FLAKES * s * quality_scale()))
	for i in count:
		var at := hero + Vector3(_rng.randf_range(-FAR, FAR), 0, _rng.randf_range(-FAR, FAR)) * 0.8
		var way := dir.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
		_flakes.append({
			"from": at + Vector3(0, 0.05, 0),
			"to": at + way * _rng.randf_range(FLAKE_TRAVEL.x, FLAKE_TRAVEL.y) * clampf(0.35 + 0.65 * s, 0.35, 1.6),
			"delay": clampf((at - hero).dot(dir) / FAR * 0.5 + 0.5, 0.0, 1.0) * SWEEP + _rng.randf_range(0.0, 0.6),
			"dur": _rng.randf_range(DURATION.x, DURATION.y) / _pace(s),
			"lift": _rng.randf_range(FLAKE_LIFT.x, FLAKE_LIFT.y) * clampf(0.35 + 0.65 * s, 0.35, 1.5),
			"fh": _noise_freqs(), "ph": _noise_phases(), "fl": _noise_freqs(), "pl": _noise_phases(),
		})
	moved += count
	_snow.visible = true


func _move_flakes() -> void:
	if _flakes.is_empty():
		return
	var mm := _snow.multimesh
	var left: Array = []
	for m: Dictionary in _flakes:
		var t := clampf((_clock - m.delay) / m.dur, 0.0, 1.0)
		if t < 1.0:
			left.append(m)
	# Flakes in the air first; the rest of the instances are folded away to nothing.
	var i := 0
	for m: Dictionary in left:
		var t := clampf((_clock - m.delay) / m.dur, 0.0, 1.0)
		var at: Vector3 = (m.from as Vector3).lerp(m.to, ease_out(t))
		var share := height_share(t, erratic(t, m.fh, m.ph))
		var swing := erratic(t, m.fl, m.pl) * 1.2 * minf(1.0, t / 0.1) * minf(1.0, (1.0 - t) / 0.15)
		at += Vector3(0, m.lift * share, 0) + Vector3.UP.cross((m.to as Vector3) - (m.from as Vector3)).normalized() * swing
		var scale_by := 1.0 if t > 0.0 else 0.0
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * scale_by), at))
		i += 1
	for k in range(i, mm.instance_count):
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	_flakes = left
	if left.is_empty():
		_snow.visible = false
