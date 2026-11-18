class_name Breath
extends Node3D
## Frozen breath. In the cold (while snow falls or lies, see Weather.cold) the hero and every
## villager breathe out a small white puff in front of the mouth every second or two, and it
## drifts up and thins out. Out of the cold nothing shows. One puff is a few soft particles
## from one shared texture and material, so a whole village of breathers costs next to nothing.

## How long between two breaths (seconds), at least and at most.
const EVERY := Vector2(1.3, 2.3)
## Where the mouth is on a model of full size (the model's own frame: +Z forward).
const MOUTH := Vector3(0, 1.32, 0.3)

static var _material: StandardMaterial3D
## Its own dice, so breathing never shifts the game's random rolls (hits, loot).
static var _rng := RandomNumberGenerator.new()

var _puff: CPUParticles3D
var _timer := 0.0


## Gives the model (a body's child) a breath of its own at its mouth.
static func attach(model: Node3D, mouth := MOUTH) -> Breath:
	var b := Breath.new()
	b.name = "Breath"
	b.position = mouth
	model.add_child(b)
	return b


## How bright the puffs are: dim at night, as the air is. Call it every so often with 0 to 1.
static func set_light(light: float) -> void:
	var shade := clampf(0.35 + light, 0.35, 1.0)
	var mat := _shared()
	mat.albedo_color = Color(shade, shade, minf(1.0, shade * 1.04), 0.75)


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
	_puff = CPUParticles3D.new()
	_puff.amount = 5
	_puff.lifetime = 1.3
	_puff.one_shot = true
	_puff.explosiveness = 0.55
	_puff.local_coords = false
	_puff.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.24, 0.24)
	quad.material = _shared()
	_puff.mesh = quad
	_puff.direction = Vector3(0, 0.18, 1)
	_puff.spread = 18.0
	_puff.gravity = Vector3(0, 0.3, 0)
	_puff.initial_velocity_min = 0.35
	_puff.initial_velocity_max = 0.7
	_puff.damping_min = 0.4
	_puff.damping_max = 0.9
	_puff.scale_amount_min = 0.5
	_puff.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.0))
	_puff.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 1.0))
	fade.add_point(0.5, Color(1, 1, 1, 0.6))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	_puff.color_ramp = fade
	_puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_puff)
	_timer = _rng.randf_range(0.0, EVERY.y)


func _process(delta: float) -> void:
	if not Weather.cold:
		return
	_timer -= delta
	if _timer > 0.0 or not is_visible_in_tree():
		return
	_timer = _rng.randf_range(EVERY.x, EVERY.y)
	_puff.restart()
