class_name ElementalShot
extends Node3D
## A bolt, a rock, a shard or a ray thrown by an elemental or a golem (see
## Elementals). It flies straight on, slower than a crossbow bolt, so a hero
## who watches for the glow around the thrower can step aside, and it
## is stopped by walls and pillars. A hero who jumps clears it. A hit hurts,
## may set the hero alight ("effect" brand) and a shard may open a wound.

## How close to the hero (metres, flat) a shot counts as a hit.
const HIT_RADIUS := 0.9
## Above this height (metres) the hero is jumping over it.
const JUMP_CLEAR := 1.2

var level: Level
var shooter: Enemy
var direction := Vector3.FORWARD
var speed := 9.0
var damage := 1
var colour := Color(1.0, 0.5, 0.15)
## "brand" sets the hero alight on a hit, "" nothing more.
var effect := ""
## Whether a hit may open a wound (a shard of glass).
var cuts := false
## Seconds it flies before it fades.
var life := 2.5
var _age := 0.0


## Throws a shot from `origin` along `dir` (flat). `shape` is "orb", "rock",
## "shard" or "beam".
static func spawn(owner_level: Level, by: Enemy, origin: Vector3, dir: Vector3, shape: String, tint: Color, dmg: int, pace: float) -> ElementalShot:
	var s := ElementalShot.new()
	s.level = owner_level
	s.shooter = by
	s.damage = dmg
	s.speed = pace
	s.colour = tint
	dir.y = 0.0
	s.direction = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	owner_level.add_child(s)
	s.global_position = origin
	s.look_at(origin + s.direction, Vector3.UP)
	s._build(shape)
	return s


func _build(shape: String) -> void:
	var mesh := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	match shape:
		"rock":
			var rock := SphereMesh.new()
			rock.radius = 0.42
			rock.height = 0.8
			rock.radial_segments = 6
			rock.rings = 3
			mesh.mesh = rock
			mat.albedo_color = colour.darkened(0.2)
			mat.roughness = 1.0
		"shard":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.16
			cone.height = 0.9
			cone.radial_segments = 4
			cone.rings = 0
			mesh.mesh = cone
			# The tip leads.
			mesh.rotation.x = -PI * 0.5
			mat.metallic = 0.6
			mat.roughness = 0.15
			_glow(mat, 0.8)
		"beam":
			var ray := BoxMesh.new()
			ray.size = Vector3(0.2, 0.2, 1.8)
			mesh.mesh = ray
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_:
			var orb := SphereMesh.new()
			orb.radius = 0.35
			orb.height = 0.7
			mesh.mesh = orb
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 1.6
	light.omni_range = 3.5
	add_child(light)
	if shape == "orb":
		add_child(Effects.make_sparkles(colour))


func _glow(mat: StandardMaterial3D, energy: float) -> void:
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = energy


func _ready() -> void:
	SmoothMotion.follow_ticks(self)


func _physics_process(delta: float) -> void:
	if level == null or level.player == null:
		queue_free()
		return
	_age += delta
	var was := global_position
	global_position += direction * speed * delta
	if _age > life or level.is_opaque(level.world_to_cell(global_position)) or level.shot_blocked(was, global_position):
		queue_free()
		return
	var player: Player = level.player
	if player.dead or player.global_position.y >= JUMP_CLEAR:
		return
	var flat := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	if flat.length() >= HIT_RADIUS:
		return
	var before := player.hp
	player.take_damage(damage, global_position - direction, shooter)
	if is_instance_valid(shooter):
		player.defend_against(shooter)
	if player.hp < before:
		if effect != "":
			player.afflict(effect)
		if cuts and Bleeding.rolls_wound(before - player.hp):
			player.bleed(before - player.hp)
	queue_free()
