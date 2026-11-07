class_name VitalStrike
extends RefCounted
## The show of a vital blow struck from a leap (see Player._leap_strike): a
## bright crescent that cuts across the foe, a ring of force and a puff of
## dust where the hero lands, a beat of slow motion, a punch of the camera
## and a deeper, layered thud. Pure looks and sound: the damage, the cooldown
## and the timing of the blow are untouched. Everything is a few meshes and a
## one-shot burst that free themselves, so it costs the client next to nothing.

## Seconds of (real) time the world crawls at impact, and how slowly.
const HIT_STOP := 0.09
const HIT_STOP_SCALE := 0.12
## How long the crescent and the ring last, in seconds.
const SLASH_TIME := 0.26
const RING_TIME := 0.45
## The camera punch, in seconds of Game's shake (see Events.camera_punched).
const PUNCH := 0.32

## The hit-stop that is running, so two quick blows never restore the speed
## of time too early or leave it slowed.
static var _stop_id := 0


## The wind-up flash as the hero leaves the ground: a puff of dust at the feet.
static func takeoff(level: Node, at: Vector3) -> void:
	if level == null or not level.is_inside_tree():
		return
	_dust(level, at, 0.6)


## The whole impact, as the blade lands on `foe` from `hero`.
static func impact(level: Node, hero: Node3D, foe: Node3D) -> void:
	if level == null or not level.is_inside_tree():
		return
	var to := foe.global_position - hero.global_position
	to.y = 0.0
	var ahead := to.normalized() if to.length() > 0.01 else Vector3.FORWARD
	var chest := foe.global_position + Vector3(0, 1.2, 0)
	_crescent(level, chest, ahead)
	_ring(level, hero.global_position + ahead * 0.6)
	_dust(level, hero.global_position + ahead * 0.6, 1.0)
	Sfx.play(level, "rumble", -3.0, chest, 1.6)
	Sfx.play(level, "anvil", -8.0, chest, 1.3)
	Sfx.play(level, "thunder", -14.0, chest, 2.4)
	Events.bus().camera_punched.emit(PUNCH)
	_hit_stop(level.get_tree())


## A slow beat: time crawls, then runs again after HIT_STOP real seconds. The
## timer ignores the time scale, so the beat is as long as it is meant to be.
static func _hit_stop(tree: SceneTree) -> void:
	_stop_id += 1
	var mine := _stop_id
	Engine.time_scale = HIT_STOP_SCALE
	tree.create_timer(HIT_STOP, true, false, true).timeout.connect(func():
		if mine == _stop_id:
			Engine.time_scale = 1.0)


## A curved blade of light that sweeps diagonally across the foe's chest and
## fades: a thin crescent cut from two circle arcs, glowing and unshaded.
static func _crescent(level: Node, at: Vector3, ahead: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var steps := 14
	var radius := 1.5
	for i in steps + 1:
		var t := float(i) / steps
		var a := lerpf(-1.0, 1.0, t)  # -1..1 across the cut
		var fat := sin(t * PI)  # thickest in the middle, a point at both ends
		# The arc bulges toward the hero: x across, z towards the hero.
		var base := Vector3(a * radius, 0.0, -0.45 * (1.0 - a * a))
		st.set_uv(Vector2(t, 0.0))
		st.add_vertex(base + Vector3(0, 0.22 * fat, 0.0))
		st.set_uv(Vector2(t, 1.0))
		st.add_vertex(base - Vector3(0, 0.22 * fat, 0.0))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 0.92, 0.65, 1.0)
	var slash := MeshInstance3D.new()
	slash.mesh = st.commit()
	slash.material_override = mat
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(slash)
	slash.global_position = at
	# Facing along `ahead`, tilted like a falling chop (top away from the hero).
	slash.look_at(at + ahead, Vector3.UP)
	slash.rotate_object_local(Vector3.FORWARD, deg_to_rad(-35.0))
	slash.scale = Vector3(0.5, 1.0, 1.0)
	var tween := slash.create_tween().set_parallel()
	tween.tween_property(slash, "scale", Vector3(1.25, 1.6, 1.0), SLASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, SLASH_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(slash.queue_free)


## A flat ring of force that spreads over the ground where the hero lands.
static func _ring(level: Node, at: Vector3) -> void:
	var mesh := Effects.ring_mesh(0.85, 1.0, 0.0, 0.0, 32, null)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.85, 0.5, 0.8)
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(ring)
	ring.global_position = at + Vector3(0, 0.08, 0)
	ring.scale = Vector3(0.3, 1.0, 0.3)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(2.6, 1.0, 2.6), RING_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, RING_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)


## Dust kicked up at the ground: a one-shot cloud of pale puffs that spreads
## sideways and settles. `size` scales how many and how wide.
static func _dust(level: Node, at: Vector3, size: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = int(18 * size)
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.95
	p.mesh = Effects._quad(0.5 * size, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 85.0
	p.gravity = Vector3(0, -1.0, 0)
	p.initial_velocity_min = 1.0 * size
	p.initial_velocity_max = 2.6 * size
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.78, 0.65, 0.0))
	ramp.add_point(0.15, Color(0.85, 0.78, 0.65, 0.5))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 0.78, 0.65, 0.0))
	p.color_ramp = ramp
	level.add_child(p)
	p.global_position = at + Vector3(0, 0.1, 0)
	p.emitting = true
	p.finished.connect(p.queue_free)
