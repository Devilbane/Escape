class_name Projectile
extends Node3D
## A thrown dagger (from the hero), a crossbow bolt or a magic orb (from a
## skeleton). Orbs fly slower but curve after the hero.

const SPEED := 20.0
const LIFETIME := 2.0

var level: Level
var direction := Vector3.FORWARD
var from_player := true
var damage := 1
var magic := false
var _age := 0.0

const MAGIC_SPEED := 10.0
const MAGIC_TURN := 1.6
const CURSE_CHANCE := 0.35


static func spawn(owner_level: Level, origin: Vector3, dir: Vector3, by_player: bool, is_magic := false) -> Projectile:
	var p := Projectile.new()
	p.level = owner_level
	p.from_player = by_player
	p.magic = is_magic
	dir.y = 0.0
	p.direction = dir.normalized()
	owner_level.add_child(p)
	p.global_position = origin
	p.look_at(origin + p.direction, Vector3.UP)
	if is_magic:
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.35
		sphere.height = 0.7
		orb.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.75, 0.35, 1.0)
		orb.material_override = mat
		p.add_child(orb)
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.7, 0.3, 1.0)
		glow.light_energy = 2.0
		glow.omni_range = 4.0
		p.add_child(glow)
		p.add_child(Effects.make_sparkles(Color(0.8, 0.4, 1.0)))
		return p
	var model: Node3D = load("res://assets/weapons/dagger.gltf" if by_player else "res://assets/weapons/Skeleton_Arrow.gltf").instantiate()
	model.rotation.x = -PI * 0.5
	model.scale = Vector3.ONE * (1.4 if by_player else 2.0)
	p.add_child(model)
	if by_player:
		p.add_child(Effects.make_sparkles(Color(0.8, 0.9, 1.0)))
	return p


func _physics_process(delta: float) -> void:
	_age += delta
	if magic and not level.player.dead:
		var want := level.player.global_position - global_position
		want.y = 0.0
		var turn := clampf(direction.signed_angle_to(want.normalized(), Vector3.UP), -MAGIC_TURN * delta, MAGIC_TURN * delta)
		direction = direction.rotated(Vector3.UP, turn)
	var step := direction * (MAGIC_SPEED if magic else SPEED) * delta
	global_position += step
	if _age > (LIFETIME * 2.0 if magic else LIFETIME) or level.is_opaque(level.world_to_cell(global_position)):
		queue_free()
		return
	if from_player:
		for e in level.enemies:
			if is_instance_valid(e) and not e.dead and _hits(e.global_position):
				e.take_hit(damage, global_position - direction, "knife")
				queue_free()
				return
	else:
		var player: Player = level.player
		if not player.dead and _hits(player.global_position) and player.global_position.y < 1.2:
			var before := player.hp
			player.take_damage(1, global_position - direction)
			# A mage's orb sometimes curses whoever it hits.
			if magic and player.hp < before and randf() < CURSE_CHANCE:
				player.afflict("fluch")
			queue_free()


func _hits(target: Vector3) -> bool:
	return Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.9
