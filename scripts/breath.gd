class_name Breath
extends Node3D
## Frozen breath. In the cold (while snow falls or lies, see Weather.cold) the hero and every
## villager breathe out a big white cloud in front of the mouth every few seconds, and it
## drifts up and thins out. Out of the cold nothing shows. One breath is a steady stream of soft particles
## from one shared texture and material, so a whole village of breathers costs next to nothing.

## How long between two breaths (seconds), at least and at most.
const EVERY := Vector2(3.9, 6.9)
## Where the mouth is on a model of full size (the model's own frame: +Z forward).
const MOUTH := Vector3(0, 1.32, 0.3)

static var _material: StandardMaterial3D
## Its own dice, so breathing never shifts the game's random rolls (hits, loot).
static var _rng := RandomNumberGenerator.new()

## How long one breath lasts (seconds).
const BLOW := 1.6

## While the breather walks or runs, the same emitter puts out three times as many particles,
## so the breath reads as one soft cloud trailing behind instead of single puffs left at every
## few steps. (No second emitter: every particle node draws from the game's random stream when
## made, which would shift every roll after it.)
const MOVING_SPEED := 0.5
const STILL_SPEED := 0.25
const IDLE_AMOUNT := 32
const MOVING_AMOUNT := 100

var _puff: CPUParticles3D
var _timer := 0.0
var _blow := 0.0
var _moving := false
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
	_last_pos = global_position
	_timer = _rng.randf_range(0.0, EVERY.y)


## The one emitter. It runs on and off instead of being restarted: a restart wipes the
## particles still in the air, while switching it off only stops new ones, so each breath
## is a stream that drifts and fades out in full as the next one starts. (One emitter per
## breather, as before: every particle node draws from the game's random stream when made.)
func _make_puff() -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.amount = IDLE_AMOUNT
	puff.lifetime = 2.6
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


func _process(delta: float) -> void:
	if delta > 0.0:
		var here := global_position
		_speed = lerpf(_speed, here.distance_to(_last_pos) / delta, minf(1.0, delta * 8.0))
		_last_pos = here
	if not _moving and _speed > MOVING_SPEED:
		_set_moving(true)
	elif _moving and _speed < STILL_SPEED:
		_set_moving(false)
	if _blow > 0.0:
		_blow -= delta
		if _blow <= 0.0:
			_puff.emitting = false
	if not Weather.cold:
		return
	_timer -= delta
	if _timer > 0.0 or not is_visible_in_tree():
		return
	_timer = _rng.randf_range(EVERY.x, EVERY.y)
	exhale()


## Walkers get a denser stream with slower, wider-spread puffs that overlap along the path.
func _set_moving(moving: bool) -> void:
	_moving = moving
	_puff.amount = MOVING_AMOUNT if moving else IDLE_AMOUNT
	_puff.initial_velocity_min = 0.3 if moving else 0.7
	_puff.initial_velocity_max = 0.45 if moving else 0.85
	_puff.spread = 12.0 if moving else 7.0


## Breathes out now: the stream starts and stops by itself, clouds still in the air stay.
func exhale() -> void:
	_blow = BLOW
	_puff.emitting = true
