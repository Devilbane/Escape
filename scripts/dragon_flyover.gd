class_name DragonFlyover
extends Node3D
## Now and then, out in the open air, a dragon flies over: high up and out
## of sight, so all the hero sees is its huge shadow sweeping across the
## ground, wings beating. First a long, eerie scream far away in the
## mountains; then, as it comes over, the heavy whump of its wings on every
## downstroke, growing louder and passing overhead, and a piercing shriek
## right above the hero. It is rare (minutes apart), only above ground
## (Outdoor builds it; a dungeon never has one), and does no harm.
##
## Where the map has the dragon's lair (its stone arch, "E"), the dragon
## flies to or from that mountain. The scream comes from the side it comes from.
##
## The shadow is three flat shapes lying just above the ground: the body
## (head, neck, tail) and one wing on either side, whose span shrinks and
## grows as they beat, like the shadow of a real wing seen from below. Their
## pictures are drawn once, at load time (see _body_image, _wing_image). The
## shadow is as dark as the light allows: plain by day, faint by moonlight,
## nearly gone on a dark night or in fog, while its sounds still carry.
## Moved per frame (it is no physics body). Tested by tests/dragon_flyover.gd.

## The scream (built by tools/make_dragon_sounds.py) and how loud it is.
const SOUND := "dragon_scream"
const SOUND_DB := -5.0
## Its wing beats (one is picked each time) and the shriek as it passes right
## overhead, how loud they are this close, and how high up it flies (the
## sounds come from there).
const WING_SOUNDS := ["dragon_wingbeat_0", "dragon_wingbeat_1", "dragon_wingbeat_2"]
const WING_DB := -2.0
const SHRIEK_SOUNDS := ["dragon_shriek_0", "dragon_shriek_1"]
const SHRIEK_DB := 1.0
const HEIGHT := 30.0
## Seconds before the first flight after the hero steps out, and between two
## flights, at least and at most. Only counted while the open air runs.
const FIRST_WAIT := Vector2(120.0, 360.0)
const WAIT := Vector2(300.0, 720.0)
## How fast the shadow moves (metres a second), how far from the hero it
## starts and ends (well out of view), and how far to either side of the
## hero it may pass.
const SPEED := 24.0
const REACH := 75.0
const PASS_SIDE := 7.0
## The size of the dragon's shadow: a scale on the shapes below, at least
## and at most.
const SIZE := Vector2(0.9, 1.15)
## The shapes, in metres: the body box (width, length) and one wing box
## (span, depth), and where the wings join the body (ahead of its middle).
const BODY_BOX := Vector2(4.0, 16.0)
const WING_BOX := Vector2(11.0, 8.0)
const SHOULDER := 1.6
## Wing beats: how often (a second), how far the span shrinks on the
## upstroke, and how often the dragon glides a moment with its wings out.
const BEAT := 0.9
const FOLD := 0.5
const GLIDE_EVERY := 2.6
## How high over the ground the shadow lies (over the paving and the grass).
const LIFT := 0.12
## How dark the shadow is in full daylight (its alpha), and its colour.
const DARK := 0.5
const TINT := Color(0.04, 0.05, 0.09)
## The picture resolution: pixels per metre.
const PIXELS := 12.0
## The colour of its line in the event log.
const COLOR := Color(1.0, 0.55, 0.3)

var level: Level
## Where the dragon's mountain is (Vector3.INF on a map without the lair).
var lair := Vector3.INF
## Seconds until the next flight.
var wait := 0.0
## The flight now: whether one is under way, where it starts, its direction
## (flat, unit), how far it has come, how long it is, its size, and whether
## the scream was heard yet, how many wing beats were heard on this flight,
## and whether it shrieked overhead yet.
var flying := false
var from := Vector3.ZERO
var heading := Vector3.FORWARD
var travelled := 0.0
var length := 0.0
var size := 1.0
var screamed := false
var beats := 0
var shrieked := false
## How many flights there were (for the test).
var flights := 0

var _rng := RandomNumberGenerator.new()
var _time := 0.0
## Where in its beat the wings were last frame (0 to 1), to hear each downstroke once.
var _beat_phase := 0.0
## The hero's spot on this flight (the shriek comes when the dragon is over it).
var _near := Vector3.ZERO
var _body: MeshInstance3D
var _wings: Array[Node3D] = []
var _material: StandardMaterial3D
var _wing_material: StandardMaterial3D

## The pictures and the material, made once and shared by every flyover.
static var _body_tex: ImageTexture
static var _wing_tex: ImageTexture


func _init(l: Level, lair_at := Vector3.INF, seed_value := 0) -> void:
	level = l
	lair = lair_at
	name = "DragonFlyover"
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	wait = _rng.randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
	_build()
	_show(false)


func _build() -> void:
	if _body_tex == null:
		_body_tex = ImageTexture.create_from_image(_body_image())
		_wing_tex = ImageTexture.create_from_image(_wing_image())
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(TINT, 0.0)
	_material.albedo_texture = _body_tex
	_material.disable_receive_shadows = true
	_wing_material = _material.duplicate() as StandardMaterial3D
	_wing_material.albedo_texture = _wing_tex
	_body = _flat(BODY_BOX, _material)
	add_child(_body)
	for side in [1.0, -1.0]:
		# A joint at the shoulder; the wing lies out from it to one side, and
		# the joint's x scale beats it (mirrored on the left).
		var joint := Node3D.new()
		joint.position = Vector3(0, 0.01, -SHOULDER)
		add_child(joint)
		var wing := _flat(WING_BOX, _wing_material)
		wing.position = Vector3(WING_BOX.x * 0.5, 0, 0)
		joint.add_child(wing)
		joint.scale = Vector3(side, 1, 1)
		_wings.append(joint)


func _flat(box: Vector2, material: Material) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = box
	plane.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func _process(delta: float) -> void:
	var hero: Node3D = level.player if level else null
	if hero == null:
		return
	if flying:
		_fly(delta)
		return
	wait -= delta
	if wait <= 0.0:
		start(hero.global_position)


## Sends the dragon over, passing near `near` (the hero). In `direction`
## when given, else to or from the lair (or anywhere on a map without one).
func start(near: Vector3, direction := Vector3.ZERO) -> void:
	near.y = 0.0
	if direction == Vector3.ZERO:
		direction = _pick_direction(near)
	direction.y = 0.0
	heading = direction.normalized()
	var side := Vector3(-heading.z, 0, heading.x) * _rng.randf_range(-PASS_SIDE, PASS_SIDE)
	from = near + side - heading * REACH
	length = REACH * 2.0
	travelled = 0.0
	size = _rng.randf_range(SIZE.x, SIZE.y)
	screamed = false
	shrieked = false
	beats = 0
	flying = true
	flights += 1
	_near = near
	_time = _rng.randf() * 10.0
	_beat_phase = fposmod(_time / BEAT, 1.0)
	scale = Vector3.ONE * size
	# The head leads: the shapes' front is their -z.
	rotation = Vector3(0, atan2(-heading.x, -heading.z), 0)
	_place()
	# The scream first, from far off; the shadow reaches the hero a few
	# seconds later.
	_scream(near)


## To the dragon's mountain or away from it, half the time each; anywhere on
## a map without one.
func _pick_direction(near: Vector3) -> Vector3:
	if lair != Vector3.INF:
		var to_lair := Vector3(lair.x - near.x, 0, lair.z - near.z)
		if to_lair.length() > 1.0:
			# Not quite straight: the dragon sweeps in on a slant.
			var d := to_lair.normalized().rotated(Vector3.UP, _rng.randf_range(-0.35, 0.35))
			return d if _rng.randf() < 0.5 else -d
	var angle := _rng.randf() * TAU
	return Vector3(cos(angle), 0, sin(angle))


func _fly(delta: float) -> void:
	travelled += SPEED * delta
	_time += delta
	if travelled >= length:
		flying = false
		_show(false)
		wait = _rng.randf_range(WAIT.x, WAIT.y)
		return
	_place()
	_beat()
	_sounds()
	_material.albedo_color.a = DARK * light() * _fade()
	_wing_material.albedo_color.a = _material.albedo_color.a


## Shows or hides the shapes. The node itself stays visible, so the copy of
## the village built behind the title (WorldPreload) draws the shapes once
## and their shader is ready before the first flight.
func _show(on: bool) -> void:
	_body.visible = on
	for joint in _wings:
		(joint.get_child(0) as Node3D).visible = on


## Whether the shadow is on the ground now.
func is_shown() -> bool:
	return _body.visible


func _place() -> void:
	_show(true)
	global_position = from + heading * travelled + Vector3(0, LIFT, 0)


## The wings beat, with now and then a moment's glide with them spread
## (the beat eases out and in again).
func _beat() -> void:
	var beating := _beating()
	var open := 1.0 - FOLD * beating * (0.5 - 0.5 * cos(TAU * _time / BEAT))
	_wings[0].scale.x = open
	_wings[1].scale.x = -open


## How much the wings beat now (0 while gliding, 1 in full beat).
func _beating() -> float:
	return smoothstep(-0.3, 0.3, sin(TAU * _time / (GLIDE_EVERY * 2.0)))


## The sounds of the flight overhead: a wing beat as each downstroke starts
## (the wings are folded most halfway through the beat, see _beat), none
## while it glides; and the shriek once it is over the hero.
func _sounds() -> void:
	var phase := fposmod(_time / BEAT, 1.0)
	var downstroke := _beat_phase < 0.5 and phase >= 0.5
	_beat_phase = phase
	var hero: Node3D = level.player if level else null
	var hero_at: Vector3 = hero.global_position if hero else _near
	if downstroke and _beating() > 0.4:
		beats += 1
		_overhead(WING_SOUNDS[_rng.randi() % WING_SOUNDS.size()], WING_DB, hero_at)
	if not shrieked and travelled >= length * 0.5:
		shrieked = true
		_overhead(SHRIEK_SOUNDS[_rng.randi() % SHRIEK_SOUNDS.size()], SHRIEK_DB, hero_at)


## Plays one of its sounds from the dragon, high over its shadow: from that
## side, softer the farther off it is (as loud as `volume_db` straight
## overhead) and fading in and out at the ends of the path like the shadow.
## A bigger dragon sounds a little deeper.
func _overhead(sound: String, volume_db: float, hero_at: Vector3) -> void:
	var at := global_position + Vector3(0, HEIGHT, 0)
	var off := Vector3(at.x - hero_at.x, 0, at.z - hero_at.z)
	var distance := Vector2(off.length(), HEIGHT).length()
	var db := volume_db + 20.0 * log(HEIGHT / distance) / log(10.0)
	db += 20.0 * log(maxf(_fade(), 0.05)) / log(10.0)
	# Heard from its side, but placed near enough that the panning follows it.
	var spot := hero_at + (off.normalized() * minf(off.length(), 20.0) if off.length() > 0.1 else Vector3.ZERO) + Vector3(0, 8, 0)
	Sfx.play_3d(level, sound, db, spot, _rng.randf_range(0.95, 1.05) / size)


## The shadow fades in and out at the ends of its path (out of view anyway).
func _fade() -> float:
	var edge := 12.0
	return clampf(minf(travelled, length - travelled) / edge, 0.0, 1.0)


## How dark a shadow the light casts now, from 0 to 1: full by day, only as
## much as the moon gives at night, weaker in bad weather.
func light() -> float:
	var outdoor := level as Outdoor
	if outdoor == null or outdoor.hour < 0.0:
		return 1.0
	var night := DayNight.moon_at(outdoor.hour)
	var bright := lerpf(1.0, Moon.light(outdoor.day) * 0.6, night)
	var sun: float = Weather.look(outdoor.weather if outdoor.weather != "" else Weather.CLEAR).sun
	return clampf(bright * lerpf(0.35, 1.0, sun), 0.0, 1.0)


## The scream, from far off where the dragon comes from,
## a line in the event log, and a scare for the village.
func _scream(hero_at: Vector3) -> void:
	screamed = true
	var at := from
	# Heard from that side, but never so far it would be lost: a point on
	# the way there, a little off the hero.
	var dir := Vector3(at.x - hero_at.x, 0, at.z - hero_at.z)
	var spot := hero_at + (dir.normalized() * 20.0 if dir.length() > 0.1 else Vector3.ZERO) + Vector3(0, 8, 0)
	Sfx.play_3d(level, SOUND, SOUND_DB, spot, _rng.randf_range(0.9, 1.05))
	# Villagers nearby cry out and talk of the dragon a while (see VillageWorries).
	Events.scare("drache")
	Events.tell(Lang.t("Ein riesiger Schatten gleitet über das Land. Fern in den Bergen schreit ein Drache."), COLOR, 4.5)


# --- Pictures ------------------------------------------------------------------

## The body's shadow: head with horns, long neck, the trunk with its legs
## tucked in, and a long tail with a spade at its end. Image x is the body's
## width (left to right), image y its length from the snout (top) to the
## tail (bottom), so it lies along the shapes' -z.
static func _body_image() -> Image:
	return _paint(BODY_BOX, func(x: float, z: float) -> bool:
		var f := -z
		var p := Vector2(x, f)
		if _in_ellipse(p, Vector2(0, 1.0), Vector2(1.15, 2.7)):
			return true
		if _near_line(p, Vector2(0, 3.0), Vector2(0, 5.6), lerpf(0.5, 0.33, clampf((f - 3.0) / 2.6, 0, 1))):
			return true
		if _in_ellipse(p, Vector2(0, 6.2), Vector2(0.62, 0.9)):
			return true
		if _near_line(p, Vector2(0, 6.6), Vector2(0, 7.6), lerpf(0.42, 0.18, clampf((f - 6.6), 0, 1))):
			return true
		for s in [-1.0, 1.0]:
			if _near_line(p, Vector2(s * 0.35, 6.0), Vector2(s * 0.85, 5.1), 0.13):
				return true
			# Hind legs tucked back along the trunk, forelegs under the chest.
			if _in_ellipse(p, Vector2(s * 0.95, -1.0), Vector2(0.32, 0.8)):
				return true
			if _in_ellipse(p, Vector2(s * 0.85, 2.4), Vector2(0.22, 0.5)):
				return true
		var tail := [Vector2(0, -1.2), Vector2(0.35, -3.6), Vector2(-0.25, -5.8), Vector2(0.2, -7.3)]
		for i in tail.size() - 1:
			var k := float(i) / (tail.size() - 1)
			var r := lerpf(0.62, 0.14, k + (1.0 / 3.0) * clampf(inverse_lerp(tail[i].y, tail[i + 1].y, f), 0, 1))
			if _near_line(p, tail[i], tail[i + 1], r):
				return true
		# The spade at the tail's tip: a diamond.
		var tip := p - Vector2(0.2, -7.55)
		return absf(tip.x) / 0.45 + absf(tip.y) / 0.42 < 1.0)


## One wing's shadow (the right one; the left is the same, mirrored): the arm
## along the front edge out to the wrist, then the long fingers fanning back,
## with the skin between them hanging in scallops. Image x runs from the
## shoulder (left) out to the wing tip; image y from front (top) to back.
static func _wing_image() -> Image:
	var root_front := Vector2(0.0, 1.9)
	var elbow := Vector2(3.6, 2.8)
	var wrist := Vector2(5.6, 3.3)
	var tips := [Vector2(10.8, 0.9), Vector2(9.0, -1.9), Vector2(6.4, -3.5), Vector2(3.4, -3.2), Vector2(0.0, -1.8)]
	var outline := PackedVector2Array([root_front, elbow, wrist])
	outline.append_array(PackedVector2Array(tips))
	var middle := Vector2(4.5, 0.0)
	# The scallops: a bite out of the skin between each two finger tips.
	var bites: Array = []
	for i in tips.size() - 1:
		var a: Vector2 = tips[i]
		var b: Vector2 = tips[i + 1]
		var chord := a.distance_to(b)
		var mid := (a + b) * 0.5
		var out := (mid - middle).normalized()
		var sag := chord * 0.2
		var radius := (chord * chord / 4.0 + sag * sag) / (2.0 * sag)
		bites.append({"at": mid + out * (radius - sag), "r": radius})
	return _paint(WING_BOX, func(x: float, z: float) -> bool:
		var p := Vector2(x + WING_BOX.x * 0.5, -z)
		if _near_line(p, root_front, elbow, 0.38) or _near_line(p, elbow, wrist, 0.3):
			return true
		if _near_line(p, wrist, tips[0], 0.14):
			return true
		if not Geometry2D.is_point_in_polygon(p, outline):
			return false
		for bite in bites:
			if p.distance_to(bite.at) < bite.r:
				return false
		return true)


## Paints a shape (inside(x, z) in metres, centred on the box) into a
## picture, then softens its edge as a shadow from high up would be.
static func _paint(box: Vector2, inside: Callable) -> Image:
	var w := int(box.x * PIXELS)
	var h := int(box.y * PIXELS)
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var dark := Color(1, 1, 1, 1)
	for j in h:
		var z := (j + 0.5) / h * box.y - box.y * 0.5
		for i in w:
			var x := (i + 0.5) / w * box.x - box.x * 0.5
			if inside.call(x, z):
				image.set_pixel(i, j, dark)
			else:
				image.set_pixel(i, j, Color(1, 1, 1, 0))
	# Soft edges: down to a quarter and back up again.
	image.resize(maxi(1, w / 4), maxi(1, h / 4), Image.INTERPOLATE_LANCZOS)
	image.resize(w, h, Image.INTERPOLATE_CUBIC)
	return image


static func _in_ellipse(p: Vector2, centre: Vector2, radii: Vector2) -> bool:
	var d := (p - centre) / radii
	return d.length_squared() <= 1.0


static func _near_line(p: Vector2, a: Vector2, b: Vector2, radius: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= radius
