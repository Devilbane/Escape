class_name VitalCircle
extends Node
## The wind-up of a vital blow (see Player._leap_strike): as the hero springs
## up, the weapon is swung down and round in one full circle, a streak of
## light following it, and comes up overhead just as the chop falls on the foe.
## Pure looks: the circle is laid over whatever the animation does and ends
## back on the animation's own pose, so the chop, the damage and the timing
## of the blow are untouched. One short-lived node that frees itself.

## Seconds the circle takes (the blade lands at Player.VITAL_HIT, so the circle
## is over just before the chop arrives and costs no time).
const CIRCLE_TIME := 0.3
## Seconds the streak stays after the blade has stopped circling: it follows the
## chop down and fades around the impact.
const TAIL_TIME := 0.2
## How many points of the streak are kept, and how long each lives (seconds).
const TRAIL_POINTS := 24
const TRAIL_LIFE := 0.22
const TRAIL_COLOR := Color(1.0, 0.82, 0.45)

var _hero: Node3D
var _part: Node3D
var _rest := Transform3D.IDENTITY
var _axis := Vector3.RIGHT
var _tip := Vector3.UP
var _clock := 0.0
## [time, tip, inner] points of the streak, oldest first.
var _samples: Array = []
var _streak: MeshInstance3D
var _mesh := ImmediateMesh.new()
var _mat: StandardMaterial3D


## Starts the circle on `hero`'s weapon: the held weapon, or the hero's own
## dagger when nothing is wielded. `ahead` is the way the hero faces. Returns
## the node (or null when there is no weapon part to swing).
static func start(hero: Node3D, level: Node, ahead: Vector3) -> VitalCircle:
	if hero == null or level == null or not level.is_inside_tree():
		return null
	var part := weapon_part(hero)
	if part == null:
		return null
	var circle := VitalCircle.new()
	circle.name = "VitalCircle"
	circle._hero = hero
	circle._part = part
	circle._rest = part.transform
	# Round a sideways axis: the blade goes forward and down first, then back
	# and up overhead, like a wheel turning towards the foe.
	circle._axis = Vector3.UP.cross(ahead).normalized() if ahead.length() > 0.01 else Vector3.RIGHT
	circle._tip = blade_end(part)
	hero.add_child(circle)
	circle._make_streak(level)
	return circle


## The part of the hero that is swung: what is held in the right hand, else
## the dagger there; null if the hero has neither.
static func weapon_part(hero: Node) -> Node3D:
	var hand := hero.find_child("handslot_r", true, false)
	if hand == null:
		return null
	var held := hand.get_node_or_null("Held") as Node3D
	if held != null:
		return held
	var knife := hand.get_node_or_null("Knife") as Node3D
	if knife != null and knife.visible:
		return knife
	return null


## The far end of a weapon in its own space: the point of its meshes farthest
## from the grip (the part's origin). Falls back to a short blade straight up.
static func blade_end(part: Node3D) -> Vector3:
	var far := Vector3.UP * 0.6
	var best := 0.0
	for node in part.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := mi.mesh.get_aabb()
		var local_to_part := _relative(mi, part)
		for i in 8:
			var p: Vector3 = local_to_part * box.get_endpoint(i)
			if p.length() > best:
				best = p.length()
				far = p
	return far


## The transform of `node` in the space of its ancestor `up`.
static func _relative(node: Node3D, up: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != up:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t


## How far round the circle the weapon is `t` seconds in (radians; a full turn
## at CIRCLE_TIME, and none after): slow to start, quick through the bottom.
static func angle_at(t: float) -> float:
	if t <= 0.0 or t >= CIRCLE_TIME:
		return 0.0
	var u := t / CIRCLE_TIME
	return TAU * (u * u * (3.0 - 2.0 * u))


func _make_streak(level: Node) -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_streak = MeshInstance3D.new()
	_streak.mesh = _mesh
	_streak.material_override = _mat
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streak.top_level = true
	_streak.extra_cull_margin = 4.0
	level.add_child(_streak)


func _process(delta: float) -> void:
	if not is_instance_valid(_part) or not is_instance_valid(_hero):
		_finish()
		return
	_clock += delta
	# The circle, laid over the animation's pose and turning about the grip.
	var parent := _part.get_parent() as Node3D
	var g := parent.global_transform * _rest
	var a := angle_at(_clock)
	g.basis = Basis(_axis, a) * g.basis
	_part.global_transform = g
	# The streak: the tip and a point part-way down the blade, as they are now.
	_samples.append([_clock, g * _tip, g * (_tip * 0.45)])
	_draw()
	if _clock >= CIRCLE_TIME + TAIL_TIME:
		_finish()


## Builds the ribbon between the tip's and the blade's path, newest end bright,
## the old end thin and faded.
func _draw() -> void:
	while not _samples.is_empty() and _clock - float(_samples[0][0]) > TRAIL_LIFE:
		_samples.pop_front()
	_mesh.clear_surfaces()
	if _samples.size() < 2:
		return
	var first := maxi(0, _samples.size() - TRAIL_POINTS)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(first, _samples.size()):
		var s: Array = _samples[i]
		var age := clampf((_clock - float(s[0])) / TRAIL_LIFE, 0.0, 1.0)
		var fade := (1.0 - age) * (1.0 - age)
		var c := Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, 0.85 * fade)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(s[1])
		_mesh.surface_set_color(Color(c.r, c.g, c.b, c.a * 0.15))
		_mesh.surface_add_vertex(s[2])
	_mesh.surface_end()


func _finish() -> void:
	# Back to the animation's own pose.
	if is_instance_valid(_part):
		_part.transform = _rest
	if is_instance_valid(_streak):
		_streak.queue_free()
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_streak):
		_streak.queue_free()
	if is_instance_valid(_part):
		_part.transform = _rest
