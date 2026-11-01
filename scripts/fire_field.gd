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

var level: Level
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
static func spawn(owner_level: Level, pos: Vector3, warn_time: float, burn_time := BURN_TIME) -> FireField:
	var f := FireField.new()
	f.level = owner_level
	f.warn = warn_time
	f.life = burn_time
	owner_level.add_child(f)
	f.global_position = Vector3(pos.x, 0.04, pos.z)
	return f


## Whether a spot is inside a burning field.
func covers(pos: Vector3) -> bool:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length() < RADIUS


func _ready() -> void:
	add_to_group("fire_field")
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.18
	torus.outer_radius = RADIUS
	_ring.mesh = torus
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(WARN_COLOR, 0.8)
	_ring.material_override = _ring_mat
	add_child(_ring)
	if warn <= 0.0:
		_ignite()


func _ignite() -> void:
	burning = true
	_tick = 0.0
	_ring_mat.albedo_color = Color(FIRE_COLOR, 0.9)
	# Scorched, glowing ground.
	_floor = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.02
	_floor.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.22, 0.05, 0.55)
	_floor.material_override = mat
	add_child(_floor)
	_flames = CPUParticles3D.new()
	_flames.amount = 36
	_flames.lifetime = 0.9
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = RADIUS * 0.8
	_flames.direction = Vector3.UP
	_flames.spread = 12.0
	_flames.gravity = Vector3(0, 2.5, 0)
	_flames.initial_velocity_min = 0.8
	_flames.initial_velocity_max = 2.0
	_flames.scale_amount_min = 0.6
	_flames.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.6)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.vertex_color_use_as_albedo = true
	quad.material = flame_mat
	_flames.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.35, 0.95))
	ramp.set_color(1, Color(0.8, 0.12, 0.02, 0.0))
	_flames.color_ramp = ramp
	add_child(_flames)
	_light = OmniLight3D.new()
	_light.light_color = FIRE_COLOR
	_light.light_energy = 1.8
	_light.omni_range = 4.5
	_light.position.y = 0.8
	add_child(_light)
	Sfx.play(self, "magic", -10.0, global_position, 0.6)
	_burn(IGNITE_DAMAGE)


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
