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

## Enough emitters that the oldest cloud has died out before its turn comes round again.
const PUFFS := 3

var _pool: Array[CPUParticles3D] = []
var _next := 0
## The emitter that breathed last.
var _puff: CPUParticles3D
var _timer := 0.0


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
	for i in PUFFS:
		var puff := _make_puff()
		add_child(puff)
		_pool.append(puff)
	_puff = _pool[0]
	_timer = _rng.randf_range(0.0, EVERY.y)


## One emitter. A one-shot emitter that is restarted wipes its own live particles, so the
## breaths take turns on a few of them and each cloud drifts and fades out in full.
func _make_puff() -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.amount = 20
	puff.lifetime = 1.6
	puff.one_shot = true
	puff.explosiveness = 0.0
	puff.local_coords = false
	puff.emitting = false
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
	if not Weather.cold:
		return
	_timer -= delta
	if _timer > 0.0 or not is_visible_in_tree():
		return
	_timer = _rng.randf_range(EVERY.x, EVERY.y)
	exhale()


## Breathes one cloud out now, on the emitter that has been idle longest, so the clouds
## still in the air are left alone.
func exhale() -> void:
	_next = (_next + 1) % _pool.size()
	_puff = _pool[_next]
	_puff.restart()
