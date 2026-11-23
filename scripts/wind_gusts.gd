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
## The least a leaf or a piece of straw is carried (metres): a third of the screen's width.
const MIN_CROSS := 11.0
const MAX_PIECES := 40
## No new gust starts while this many pieces are still in the air (gusts may overlap).
const MAX_IN_AIR := 120
## Pieces are taken from this far round the hero (metres).
const NEAR := 2.5
const FAR := 15.0
## How far a piece travels in a breeze (metres), by what it is: leaves float far, chips skid.
const TRAVEL := {"leaf": Vector2(50.0, 90.0), "straw": Vector2(25.0, 50.0), "chip": Vector2(0.6, 1.5), "fallen": Vector2(0.4, 1.1)}
## How high it is lifted (metres).
const LIFT := {"leaf": Vector2(1.0, 2.2), "straw": Vector2(0.6, 1.5), "chip": Vector2(0.05, 0.2), "fallen": Vector2(0.02, 0.06)}
## How long a flight takes (seconds): slow, like a feather's.
const DURATION := Vector2(14.0, 22.0)
## The flight time the wobble and turning speeds were tuned for, and how much quicker than that
## they go: a long flight is not a slow one.
const TUNED_FOR := 7.75
const LIVELY := 2.0
## The gust sweeps along the wind: the furthest piece starts this long after the nearest (seconds).
const SWEEP := 5.0
## How much the wind's direction turns between gusts (radians, at most).
const TURN := 0.7
## How hard a gust blows on top of the weather's wind (1 is the weather's breeze): drawn at random
## for every gust, mostly light and slow, now and then strong and fast. It sets how many pieces are
## taken, how high and far they go and how quickly.
const FORCE := Vector2(0.3, 1.6)
## The tiles pieces may fly over and land on.
const OPEN := SurfaceLife.GROUND + SurfaceLife.PATH + SurfaceLife.SQUARE
## The winter flurry: flakes per gust, their size (metres), how far they are blown and how high.
## How thick the snow must lie (0 to 1, see SnowCover.amount) before the wind lifts any.
const SNOW_MIN := 0.25
## The foggy snow dust that flies with the flakes: soft puffs per gust, their size (metres, they grow as
## they go) and how faint they are at their thickest.
const PUFFS := 36
const PUFF_SIZE := Vector2(1.2, 2.8)
const PUFF_ALPHA := 0.17
const FLAKES := 80
const FLAKE_SIZE := 0.07
const FLAKE_TRAVEL := Vector2(18.0, 40.0)
const FLAKE_LIFT := Vector2(0.3, 2.2)

var life: SurfaceLife
## The pieces in the air: {entry, from, to, start, dur, lively, lift, axis, spin, yaw, light, and the settings of its erratic motion}.
var _moving: Array = []
## Seconds the node has run, and the clock every flight is told by (see _move).
var _now := 0.0
var _timer := 0.0
## The way the wind blows now (angle on the ground plane).
var _angle := 0.0
## The force of the gust now, and of the last one (for the tests).
var force := 1.0
var _rng := RandomNumberGenerator.new()
## The flurry of snow: its MultiMesh (made the first winter gust) and the flakes in the air.
var _snow: MultiMeshInstance3D
var _flakes: Array = []
## The dust puffs: their MultiMesh (made with the first flurry) and the ones in the air.
var _dust: MultiMeshInstance3D
var _puffs: Array = []
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
	return _moving.size() + _flakes.size() + _puffs.size()


func _process(delta: float) -> void:
	_now += delta
	if active() > 0:
		_move()
		_move_flakes()
		_move_puffs()
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
	if life.level.player == null or active() > MAX_IN_AIR:
		return 0
	_angle += _rng.randf_range(-TURN, TURN)
	var dir := Vector3(cos(_angle), 0, sin(_angle))
	var hero: Vector3 = life.level.player.global_position
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
				if e.size() > 5 and e[5]:
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
		# Not so far then: a wall or the water is in the way. But a leaf must still cross at least a
		# third of the screen (the camera shows about 33 m across) to look natural, or it stays put.
		var short := false
		for share in [0.5, 0.25]:
			if kind in ["leaf", "straw"] and dist * share < MIN_CROSS:
				break
			to = from + way * dist * share
			if _clear_way(from, to):
				short = true
				break
		if not short and kind in ["leaf", "straw"]:
			return false
		if not short and not _clear_way(from, to):
			return false
	var lift: Vector2 = LIFT[kind]
	var light := kind == "leaf" or kind == "straw"
	var dur := (_rng.randf_range(DURATION.x, DURATION.y) if light else _rng.randf_range(1.2, 2.2)) / _pace(s)
	var lively := dur / TUNED_FOR * LIVELY if light else 1.0
	if e.size() > 5:
		e[5] = true
	else:
		e.append(true)
	_moving.append({
		"entry": e, "from": from, "to": to,
		"start": _now + clampf((from - hero).dot(dir) / FAR * 0.5 + 0.5, 0.0, 1.0) * SWEEP + _rng.randf_range(0.0, 0.4),
		"dur": dur, "lively": lively,
		"lift": _rng.randf_range(lift.x, lift.y) * clampf(0.35 + 0.65 * s, 0.35, 1.5),
		"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.2, 1), _rng.randf_range(-1, 1)).normalized(),
		"spin": _rng.randf_range(2.0, 5.0) * lively if light else _rng.randf_range(0.05, 0.3),
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


## `v` with its three parts turned round `by` places (GDScript has no swizzles).
static func _roll(v: Vector3, by: int) -> Vector3:
	return Vector3(v.y, v.z, v.x) if by == 1 else Vector3(v.z, v.x, v.y)


func _noise_freqs() -> Vector3:
	return Vector3(_rng.randf_range(8.0, 22.0), _rng.randf_range(14.0, 34.0), _rng.randf_range(22.0, 48.0))


func _noise_phases() -> Vector3:
	return Vector3(_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU))


## How high a piece is at `t` (0 to 1) of its flight, as a share of its lift, with `n` (see erratic)
## the piece's own restlessness: it is lifted gently, then wanders up and down, surging and
## dropping at random with only a slight sink, and settles in the last stretch. Zero at both ends.
static func height_share(t: float, n: float) -> float:
	# Lifted gently over the first seconds, let down just as gently over the last 30 percent.
	var rise := smoothstep(0.0, 0.15, t)
	var settle := smoothstep(0.0, 0.3, 1.0 - t)
	return rise * settle * (1.0 - 0.25 * t) * clampf(0.85 + 0.2 * n, 0.6, 1.0)


func _move() -> void:
	var left: Array = []
	for m: Dictionary in _moving:
		var e: Array = m.entry
		if not is_instance_valid(e[0]):
			continue
		var t := clampf((_now - m.start) / m.dur, 0.0, 1.0)
		var flat: Transform3D = e[3]
		var yawed := Basis(Vector3.UP, m.yaw + m.spin)
		var key := "%d:%d" % [(e[0] as MultiMesh).get_instance_id(), e[1]]
		var lifted: bool = life._lifted.has(key)
		if t >= 1.0:
			# Lands: this is where the piece lies now.
			var home := Transform3D(yawed * flat.basis, flat.origin + (m.to - m.from))
			e[2] = home.origin
			e[3] = home
			if e.size() > 5:
				e[5] = false
			if not lifted:
				(e[0] as MultiMesh).set_instance_transform(e[1], home)
			continue
		left.append(m)
		if t <= 0.0 or lifted:
			continue
		var k: float = m.lively
		var share := height_share(t, erratic(t * k, m.fh, m.ph))
		var along: Vector3 = (m.to as Vector3) - (m.from as Vector3)
		var side_axis := Vector3.UP.cross(along).normalized()
		# Pushed this way and that on the way, but always on along the wind.
		var calm := smoothstep(0.0, 0.2, t) * smoothstep(0.0, 0.3, 1.0 - t)
		var sway := side_axis * erratic(t * k, m.fl, m.pl) * 1.5 * calm
		var surge := erratic(t * k, _roll(m.fl, 1), _roll(m.pl, 2)) * 0.025 * calm
		# From a recorded reference (see docs/wind_reference.md): about every quarter of a second
		# the leaf flips edge-on and back, it bobs very slightly, and it surges a little.
		var secs: float = t * m.dur
		var flip: float = sin(secs * TAU * m.flip_hz + m.flip_ph)
		var bob: float = sin(secs * TAU * 1.4 + m.bob_ph) * 0.025 * calm
		var basis := flat.basis
		if m.light:
			# Its own wild turning on all axes, never the same as its neighbour's.
			var yaw: float = m.yaw * t + m.spin * t + erratic(t * k, m.fa, m.pa) * 1.4 * calm
			basis = Basis(along.normalized(), flip * 0.7 * calm) * Basis(m.axis, erratic(t * k, m.fb, m.pb) * 1.2 * calm) * Basis(m.axis2, erratic(t * k, _roll(m.fa, 2), _roll(m.pb, 1)) * 1.0 * calm) * Basis(Vector3.UP, yaw) * flat.basis
		else:
			basis = Basis(Vector3.UP, m.yaw * t + m.spin * t) * flat.basis
		var origin: Vector3 = (m.from as Vector3).lerp(m.to, clampf(ease_out(t) + surge, 0.0, 1.0)) + sway + Vector3(0, m.lift * share + bob, 0)
		(e[0] as MultiMesh).set_instance_transform(e[1], Transform3D(basis, origin + (flat.origin - m.from)))
	_moving = left


## Fast at first as the gust takes it, slower as it drifts down.
static func ease_out(t: float) -> float:
	# Snatched up and driven off, as in the reference (a leaf crosses a screen in a second or two),
	# and carried at that same speed all the way down to the ground: no slowing at the end.
	# (A short ramp-up at the very start, so it does not jump from standing still.)
	const RAMP := 0.04
	var run := t * t / (2.0 * RAMP) if t < RAMP else t - RAMP * 0.5
	return run / (1.0 - RAMP * 0.5)


## Whether the snow on the ground is thick enough to be lifted (see SnowCover).
func _snow_thick() -> bool:
	var cover = life.level.get("snow")
	return cover != null and cover.lies() and cover.amount >= SNOW_MIN


## Whether snow lies on the ground at `at`: open ground (not water, not under a tree, a wall or a
## building), not under a roof and not near a fire, where the cover keeps clear (see SnowCover.set_warm).
func snow_lies_at(at: Vector3) -> bool:
	if not _snow_thick():
		return false
	if not OPEN.contains(life.level.cell_char(life.level.world_to_cell(at))):
		return false
	if life.level.has_method("is_roofed") and life.level.is_roofed(at):
		return false
	for h: Vector4 in life.level.get("warm_spots") if "warm_spots" in life.level else []:
		if Vector2(h.x - at.x, h.z - at.z).length() < h.w + 0.5:
			return false
	for r: Rect2 in life._holes + life._built:
		if r.has_point(Vector2(at.x, at.z)):
			return false
	return true


## Winter: a flurry of snow lifts off the ground round the hero, drifts along the wind and
## settles again (one MultiMesh of tiny flat flakes, hidden between gusts).
func _flurry(dir: Vector3, s: float, hero: Vector3) -> void:
	# Only where snow really lies: none on the ground, no flakes to lift.
	if not _snow_thick():
		return
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
		mat.billboard_keep_scale = true
		mat.albedo_color = Color(0.95, 0.97, 1.0, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_snow.material_override = mat
		_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_snow.extra_cull_margin = 60.0
		add_child(_snow)
	var count := mini((_snow.multimesh as MultiMesh).instance_count - _flakes.size(), roundi(FLAKES * s * quality_scale()))
	var taken := 0
	for i in count * 3:
		if taken >= count:
			break
		var at := hero + Vector3(_rng.randf_range(-FAR, FAR), 0, _rng.randf_range(-FAR, FAR)) * 0.8
		if not snow_lies_at(at):
			continue
		taken += 1
		var way := dir.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
		_flakes.append({
			"from": at + Vector3(0, 0.05, 0),
			"to": at + way * _rng.randf_range(FLAKE_TRAVEL.x, FLAKE_TRAVEL.y) * clampf(0.35 + 0.65 * s, 0.35, 1.6),
			"start": _now + clampf((at - hero).dot(dir) / FAR * 0.5 + 0.5, 0.0, 1.0) * SWEEP + _rng.randf_range(0.0, 0.6),
			"dur": _rng.randf_range(DURATION.x, DURATION.y) / _pace(s), "lively": LIVELY * 2.0,
			"lift": _rng.randf_range(FLAKE_LIFT.x, FLAKE_LIFT.y) * clampf(0.35 + 0.65 * s, 0.35, 1.5),
			"fh": _noise_freqs(), "ph": _noise_phases(), "fl": _noise_freqs(), "pl": _noise_phases(),
		})
	moved += taken
	_snow.visible = _flakes.size() > 0
	_dust_up(dir, s, hero)


## The foggy dust that rides with the snow: big, faint, soft puffs that swell as they drift on and
## fade in and out, started where snow lies like the flakes.
func _dust_up(dir: Vector3, s: float, hero: Vector3) -> void:
	if _dust == null:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		mm.mesh = quad
		mm.instance_count = int(PUFFS * 1.5)
		_dust = MultiMeshInstance3D.new()
		_dust.name = "SnowDust"
		_dust.multimesh = mm
		var soft := GradientTexture2D.new()
		soft.fill = GradientTexture2D.FILL_RADIAL
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(1.0, 0.5)
		soft.width = 64
		soft.height = 64
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		soft.gradient = ramp
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		mat.albedo_texture = soft
		mat.albedo_color = Color(0.92, 0.95, 1.0, 1.0)
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_dust.material_override = mat
		_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dust.extra_cull_margin = 60.0
		add_child(_dust)
	var count := mini((_dust.multimesh as MultiMesh).instance_count - _puffs.size(), roundi(PUFFS * s * quality_scale()))
	var taken := 0
	for i in count * 3:
		if taken >= count:
			break
		var at := hero + Vector3(_rng.randf_range(-FAR, FAR), 0, _rng.randf_range(-FAR, FAR)) * 0.8
		if not snow_lies_at(at):
			continue
		taken += 1
		var way := dir.rotated(Vector3.UP, _rng.randf_range(-0.4, 0.4))
		_puffs.append({
			"from": at + Vector3(0, 0.3, 0),
			"to": at + way * _rng.randf_range(FLAKE_TRAVEL.x, FLAKE_TRAVEL.y) * clampf(0.35 + 0.65 * s, 0.35, 1.6),
			"start": _now + clampf((at - hero).dot(dir) / FAR * 0.5 + 0.5, 0.0, 1.0) * SWEEP + _rng.randf_range(0.0, 0.6),
			"dur": _rng.randf_range(DURATION.x, DURATION.y) / _pace(s),
			"lift": _rng.randf_range(0.3, 1.2),
			"size": _rng.randf_range(PUFF_SIZE.x, PUFF_SIZE.y),
			"fh": _noise_freqs(), "ph": _noise_phases(),
		})
	_dust.visible = _puffs.size() > 0


func _move_puffs() -> void:
	if _puffs.is_empty():
		return
	var mm := _dust.multimesh
	var left: Array = []
	for m: Dictionary in _puffs:
		if _now - m.start < m.dur:
			left.append(m)
	var i := 0
	for m: Dictionary in left:
		var t := clampf((_now - m.start) / m.dur, 0.0, 1.0)
		var at: Vector3 = (m.from as Vector3).lerp(m.to, ease_out(t))
		at.y += m.lift * height_share(t, erratic(t * 2.0, m.fh, m.ph))
		var fade := smoothstep(0.0, 0.2, t) * smoothstep(0.0, 0.4, 1.0 - t)
		var size: float = m.size * (0.6 + 0.8 * t) * (1.0 if t > 0.0 else 0.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), at))
		mm.set_instance_color(i, Color(1, 1, 1, PUFF_ALPHA * fade))
		i += 1
	for k in range(i, mm.instance_count):
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	_puffs = left
	if left.is_empty():
		_dust.visible = false


func _move_flakes() -> void:
	if _flakes.is_empty():
		return
	var mm := _snow.multimesh
	var left: Array = []
	for m: Dictionary in _flakes:
		var t := clampf((_now - m.start) / m.dur, 0.0, 1.0)
		if t < 1.0:
			left.append(m)
	# Flakes in the air first; the rest of the instances are folded away to nothing.
	var i := 0
	for m: Dictionary in left:
		var t := clampf((_now - m.start) / m.dur, 0.0, 1.0)
		var at: Vector3 = (m.from as Vector3).lerp(m.to, ease_out(t))
		var share := height_share(t, erratic(t * m.lively, m.fh, m.ph))
		var swing := erratic(t * m.lively, m.fl, m.pl) * 1.2 * smoothstep(0.0, 0.2, t) * smoothstep(0.0, 0.3, 1.0 - t)
		at += Vector3(0, m.lift * share, 0) + Vector3.UP.cross((m.to as Vector3) - (m.from as Vector3)).normalized() * swing
		var scale_by := 1.0 if t > 0.0 else 0.0
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * scale_by), at))
		i += 1
	for k in range(i, mm.instance_count):
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	_flakes = left
	if left.is_empty():
		_snow.visible = false
