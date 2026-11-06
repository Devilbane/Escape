class_name FireField
extends Node3D
## A patch of burning ground left by the dragon's fire (see Dragon). First a
## red ring glows on the floor for a moment as a warning; then it bursts into
## flame and burns for a while. Flames hurt the hero standing in them (not
## while jumping over them) and set them burning; dragons and the other
## monsters of the lair walk through them unharmed.

const RADIUS := 1.5
## How long a field burns, and how often it hurts whoever stands in it.
const BURN_TIME := 7.0
const TICK := 1.0
## The first touch of the flames burns harder.
const IGNITE_DAMAGE := 2
const DAMAGE := 1
## Above this height (metres) the hero is jumping over the flames.
const JUMP_CLEAR := 0.6
const WARN_COLOR := Color(1.0, 0.25, 0.1)
const FIRE_COLOR := Color(1.0, 0.5, 0.12)

## Soft round sprites for the flames, the glow on the ground and the sparks,
## made once and shared by every field: no hard square edges.
static var _soft: GradientTexture2D
static var _flame_mat: StandardMaterial3D
static var _glow_mat: StandardMaterial3D

var level: Level
## How far the field reaches (metres) and whether it casts its own light (a
## wide breath of many fields lights only some of them).
var radius := RADIUS
var lit := true
var warn := 0.0
var life := BURN_TIME
var burning := false
var _tick := 0.0
var _age := 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _floor: MeshInstance3D
var _flames: CPUParticles3D
var _light: OmniLight3D


## A field at `pos` that warns for `warn_time` seconds before it ignites.
static func spawn(owner_level: Level, pos: Vector3, warn_time: float, burn_time := BURN_TIME, reach := RADIUS, light := true) -> FireField:
	var f := FireField.new()
	f.level = owner_level
	f.radius = reach
	f.lit = light
	f.warn = warn_time
	f.life = burn_time
	owner_level.add_child(f)
	f.global_position = Vector3(pos.x, 0.04, pos.z)
	return f


## Whether a spot is inside a burning field.
func covers(pos: Vector3) -> bool:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length() < radius


func _ready() -> void:
	add_to_group("fire_field")
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.18
	torus.outer_radius = radius
	_ring.mesh = torus
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(WARN_COLOR, 0.8)
	_ring.material_override = _ring_mat
	add_child(_ring)
	if warn <= 0.0:
		_ignite()


## The shared soft sprite: bright in the middle, fading to nothing at the rim.
static func _soft_texture() -> GradientTexture2D:
	if _soft == null:
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		fade.add_point(0.45, Color(1, 1, 1, 0.55))
		_soft = GradientTexture2D.new()
		_soft.gradient = fade
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
		_soft.width = 64
		_soft.height = 64
	return _soft


## Flames and sparks add their light, so where fields overlap the fire
## glows brighter instead of piling up flat squares.
static func _flame_material() -> StandardMaterial3D:
	if _flame_mat == null:
		_flame_mat = StandardMaterial3D.new()
		_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flame_mat.no_depth_test = false
		_flame_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_flame_mat.vertex_color_use_as_albedo = true
		_flame_mat.albedo_texture = _soft_texture()
	return _flame_mat


static func _glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_glow_mat.albedo_texture = _soft_texture()
		_glow_mat.albedo_color = Color(0.9, 0.22, 0.03, 0.45)
	return _glow_mat


func _ignite() -> void:
	burning = true
	_tick = 0.0
	# The hard warning ring fades away: from now on the fire itself shows
	# where it burns.
	var fade := create_tween()
	fade.tween_property(_ring_mat, "albedo_color:a", 0.0, 0.35)
	# Glowing embers on the ground, soft at the edge, reaching a little past
	# the field so neighbours melt into one blaze.
	_floor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.6
	_floor.mesh = plane
	_floor.material_override = _glow_material()
	_floor.position.y = 0.01
	_floor.rotation.y = randf() * TAU
	add_child(_floor)
	_flames = _particles(int(22 * radius), 0.75, radius * 0.75, Vector2(0.9, 1.3), 1.0, 2.4)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.35, 0.35))
	ramp.set_color(1, Color(0.5, 0.05, 0.0, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.5, 0.1, 0.32))
	ramp.add_point(0.6, Color(0.85, 0.18, 0.02, 0.2))
	_flames.color_ramp = ramp
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.3, 1.0))
	grow.add_point(Vector2(1.0, 0.15))
	_flames.scale_amount_curve = grow
	_flames.angle_min = -180.0
	_flames.angle_max = 180.0
	_flames.preprocess = 0.3
	add_child(_flames)
	# Sparks drifting up out of the blaze.
	var sparks := _particles(int(6 * radius), 1.4, radius * 0.7, Vector2(0.12, 0.12), 1.6, 3.4)
	sparks.spread = 25.0
	var spark_ramp := Gradient.new()
	spark_ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	spark_ramp.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	sparks.color_ramp = spark_ramp
	add_child(sparks)
	if lit:
		_light = OmniLight3D.new()
		_light.light_color = FIRE_COLOR
		_light.light_energy = 1.8
		_light.omni_range = 4.5
		_light.position.y = 0.8
		add_child(_light)
	Sfx.play(self, "magic", -10.0, global_position, 0.6)
	_burn(IGNITE_DAMAGE)


## Particles rising from the field, drawn with the soft sprite.
func _particles(amount: int, lifetime: float, spread_radius: float, size: Vector2, speed_min: float, speed_max: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(4, amount)
	p.lifetime = lifetime
	p.randomness = 0.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread_radius
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = _flame_material()
	p.mesh = quad
	return p


func _physics_process(delta: float) -> void:
	_age += delta
	if not burning:
		warn -= delta
		# The warning ring pulses faster as the flames draw near.
		_ring_mat.albedo_color.a = 0.45 + 0.4 * absf(sin(_age * (6.0 + 10.0 / maxf(warn, 0.3))))
		if warn <= 0.0:
			_ignite()
		return
	life -= delta
	if _light:
		_light.light_energy = 1.6 + sin(_age * 17.0) * 0.3
	if life <= 0.0:
		set_physics_process(false)
		_flames.emitting = false
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3(0.01, 1.0, 0.01), 0.8)
		tween.tween_callback(queue_free)
		return
	_tick -= delta
	if _tick <= 0.0:
		_burn(DAMAGE)


## Hurts and sets alight the hero standing in the flames.
func _burn(amount: int) -> void:
	_tick = TICK
	if level == null or level.player == null:
		return
	var player: Player = level.player
	if player.dead or player.global_position.y > JUMP_CLEAR or not covers(player.global_position):
		return
	player.take_damage(amount, global_position, null, false)
	player.afflict("brand")
