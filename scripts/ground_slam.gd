class_name GroundSlam
extends Node3D
## A blow on the ground that comes after a warning (see Elementals): a ring
## of the blow's colour glows on the floor and pulses faster for `warn`
## seconds, then the ground bursts. Whoever stands inside the ring takes the
## damage, unless they jump over it. A "quake" also throws a running hero to
## the ground.

const JUMP_CLEAR := 0.6

var level: Level
var shooter: Enemy
var radius := 3.0
var warn := 1.0
var damage := 3
var colour := Color(0.8, 0.7, 0.5)
var knocks_down := false
var _age := 0.0
var _burst := false
var _ring: MeshInstance3D
var _mat: StandardMaterial3D


static func spawn(owner_level: Level, by: Enemy, pos: Vector3, reach: float, warn_time: float, dmg: int, tint: Color, quake := false) -> GroundSlam:
	var g := GroundSlam.new()
	g.level = owner_level
	g.shooter = by
	g.radius = reach
	g.warn = warn_time
	g.damage = dmg
	g.colour = tint
	g.knocks_down = quake
	owner_level.add_child(g)
	g.global_position = Vector3(pos.x, 0.05, pos.z)
	return g


func _ready() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.2
	torus.outer_radius = radius
	_ring.mesh = torus
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(colour, 0.7)
	_ring.material_override = _mat
	add_child(_ring)


func _physics_process(delta: float) -> void:
	_age += delta
	if _burst:
		return
	# The ring pulses faster as the blow comes down.
	_mat.albedo_color.a = 0.45 + 0.4 * absf(sin(_age * (6.0 + 10.0 / maxf(warn - _age, 0.3))))
	if _age >= warn:
		_land()


func _land() -> void:
	_burst = true
	Sfx.play(self, "hit", -2.0, global_position, 0.6)
	var flash := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.12
	flash.mesh = disc
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(colour.lightened(0.3), 0.6)
	flash.material_override = flash_mat
	add_child(flash)
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(flash_mat, "albedo_color:a", 0.0, 0.5)
	fade.tween_property(_mat, "albedo_color:a", 0.0, 0.5)
	fade.chain().tween_callback(queue_free)
	if level == null or level.player == null:
		return
	var player: Player = level.player
	var flat := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	if player.dead or player.global_position.y > JUMP_CLEAR or flat.length() > radius:
		return
	var before := player.hp
	player.take_damage(damage, global_position, shooter, false)
	if knocks_down and player.hp < before and not player.dead:
		player.knock_down()
