class_name Breath
extends Node3D
## Frozen breath. In the cold (while snow falls or lies, see Weather.cold) the hero and every
## villager breathe out a big white cloud in front of the mouth every second or two, and it
## drifts up and thins out. Out of the cold nothing shows. One breath is a steady stream of soft particles
## from one shared texture and material, so a whole village of breathers costs next to nothing.

## How long between two breaths (seconds), at least and at most.
const EVERY := Vector2(1.3, 2.3)
## Where the mouth is on a model of full size (the model's own frame: +Z forward).
const MOUTH := Vector3(0, 1.32, 0.3)

static var _material: StandardMaterial3D
## Its own dice, so breathing never shifts the game's random rolls (hits, loot).
static var _rng := RandomNumberGenerator.new()

## How long one breath lasts (seconds).
const BLOW := 0.7

## While the breather walks, a second emitter lays a soft plume along the path, so the breath
## reads as one cloud trailing behind instead of single puffs left at every few steps.
const MOVING_SPEED := 0.4
## The plume runs on past the breath while moving, so it bridges to the next one.
const TRAIL_BLOW := 2.0

var _puff: CPUParticles3D
var _trail: CPUParticles3D
var _timer := 0.0
var _blow := 0.0
var _trail_blow := 0.0
var _last_pos := Vector3.ZERO
var _speed := 0.0


## Gives the model (a body's child) a breath of its own at its mouth.
static func attach(model: Node3D, mouth := MOUTH) -> Breath:
	var b := Breath.new()
	b.name = "Breath"
	b.position = mouth
	model.add_child(b)
	return b


## How bright the puffs are: dark at night, as the air is. Call it every so often with 0 to 1.
static func set_light(light: float) -> void:
	# No glow of its own: in the dark the breath is as dark as the air around it.
	var shade := clampf(light, 0.04, 1.0)
	var mat := _shared()
	mat.albedo_color = Color(shade, shade, minf(1.0, shade * 1.04), 0.75 * clampf(0.3 + light, 0.3, 1.0))


static func _shared() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_material.vertex_color_use_as_albedo = true
		_material.albedo_texture = Effects._soft_dot()
		_material.albedo_color = Color(1, 1, 1, 0.75)
	return _material


func _ready() -> void:
	_puff = _make_puff()
	add_child(_puff)
	_trail = _make_trail()
	add_child(_trail)
	_last_pos = global_position
	_timer = _rng.randf_range(0.0, EVERY.y)


## The one emitter. It runs on and off instead of being restarted: a restart wipes the
## particles still in the air, while switching it off only stops new ones, so each breath
## is a stream that drifts and fades out in full as the next one starts. (One emitter per
## breather, as before: every particle node draws from the game's random stream when made.)
func _make_puff() -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.amount = 20
	puff.lifetime = 1.6
	puff.one_shot = false
	puff.explosiveness = 0.0
	puff.local_coords = false
	puff.emitting = false
	# Particles otherwise draw their seed from the game's own random stream and would shift
	# every roll after them (hits, loot): this one takes its seed from the breath's own dice.
	puff.use_fixed_seed = true
	puff.seed = _rng.randi()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	quad.material = _shared()
	puff.mesh = quad
	puff.direction = Vector3(0, 0.18, 1)
	puff.spread = 7.0
	puff.gravity = Vector3(0, 0.3, 0)
	puff.initial_velocity_min = 0.7
	puff.initial_velocity_max = 0.85
	puff.damping_min = 0.3
	puff.damping_max = 0.5
	puff.scale_amount_min = 0.8
	puff.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 2.6))
	puff.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.2, Color(1, 1, 1, 0.55))
	fade.add_point(0.55, Color(1, 1, 1, 0.35))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	puff.color_ramp = fade
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return puff


## The plume for a walker: many small overlapping particles that stay where they were
## breathed out, so a moving mouth draws a continuous trail.
func _make_trail() -> CPUParticles3D:
	var t := CPUParticles3D.new()
	t.amount = 64
	t.lifetime = 1.2
	t.one_shot = false
	t.explosiveness = 0.0
	t.local_coords = false
	t.emitting = false
	t.use_fixed_seed = true
	t.seed = _rng.randi()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	quad.material = _shared()
	t.mesh = quad
	t.direction = Vector3(0, 0.25, 1)
	t.spread = 12.0
	t.gravity = Vector3(0, 0.25, 0)
	t.initial_velocity_min = 0.1
	t.initial_velocity_max = 0.35
	t.damping_min = 0.3
	t.damping_max = 0.5
	t.scale_amount_min = 0.7
	t.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.6))
	grow.add_point(Vector2(1, 2.4))
	t.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 0.4))
	fade.add_point(0.5, Color(1, 1, 1, 0.28))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	t.color_ramp = fade
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return t


func _process(delta: float) -> void:
	if delta > 0.0:
		var here := global_position
		_speed = lerpf(_speed, here.distance_to(_last_pos) / delta, minf(1.0, delta * 8.0))
		_last_pos = here
	var moving := _speed > MOVING_SPEED
	if _blow > 0.0:
		_blow -= delta
		if _blow <= 0.0:
			_puff.emitting = false
	# The plume follows the breath, but only while the breather is actually walking.
	_trail_blow = maxf(0.0, _trail_blow - delta)
	_trail.emitting = _trail_blow > 0.0 and moving
	if not Weather.cold:
		return
	_timer -= delta
	if _timer > 0.0 or not is_visible_in_tree():
		return
	_timer = _rng.randf_range(EVERY.x, EVERY.y)
	exhale()


## Breathes out now: the stream starts and stops by itself, clouds still in the air stay.
func exhale() -> void:
	_blow = BLOW
	_trail_blow = TRAIL_BLOW
	_puff.emitting = true
