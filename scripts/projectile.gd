class_name Projectile
extends Node3D
## A thrown dagger (from the hero) or a crossbow bolt (from a skeleton).

const SPEED := 20.0
const LIFETIME := 2.0

var level: Level
var direction := Vector3.FORWARD
var from_player := true
var _age := 0.0


static func spawn(owner_level: Level, origin: Vector3, dir: Vector3, by_player: bool) -> Projectile:
	var p := Projectile.new()
	p.level = owner_level
	p.from_player = by_player
	dir.y = 0.0
	p.direction = dir.normalized()
	owner_level.add_child(p)
	p.global_position = origin
	p.look_at(origin + p.direction, Vector3.UP)
	var model: Node3D = load("res://assets/weapons/dagger.gltf" if by_player else "res://assets/weapons/Skeleton_Arrow.gltf").instantiate()
	model.rotation.x = -PI * 0.5
	model.scale = Vector3.ONE * (1.4 if by_player else 2.0)
	p.add_child(model)
	if by_player:
		p.add_child(Effects.make_sparkles(Color(0.8, 0.9, 1.0)))
	return p


func _physics_process(delta: float) -> void:
	_age += delta
	var step := direction * SPEED * delta
	global_position += step
	if _age > LIFETIME or level.is_opaque(level.world_to_cell(global_position)):
		queue_free()
		return
	if from_player:
		for e in level.enemies:
			if is_instance_valid(e) and not e.dead and _hits(e.global_position):
				e.take_hit(1, global_position - direction)
				queue_free()
				return
	else:
		var player: Player = level.player
		if not player.dead and _hits(player.global_position) and player.global_position.y < 1.2:
			player.take_damage(1, global_position - direction)
			queue_free()


func _hits(target: Vector3) -> bool:
	return Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.9
