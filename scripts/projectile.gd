class_name Projectile
extends Node3D
## A thrown dagger (from the hero), a crossbow bolt or a magic orb (from a
## skeleton). Orbs fly slower but curve after the hero. The dragon's fire
## flies like an orb, burns for two and never curses.

const SPEED := 20.0
const LIFETIME := 2.0

var level: Level
var direction := Vector3.FORWARD
var from_player := true
## The skeleton that shot or cast it; the hero fights back against it.
var shooter: Node = null
## The rival monster it was aimed at (see Factions), or null when it flies
## at the hero. Aimed at a rival ("at_rival"), it hits only that one.
var foe: Enemy = null
var at_rival := false
## What the shot costs whoever it hits: the hero's knife or the shooter's own damage.
var damage := 1
var magic := false
var fire := false
var _age := 0.0

const MAGIC_SPEED := 5.5
const MAGIC_TURN := 0.8
const CURSE_CHANCE := 0.35


static func spawn(owner_level: Level, origin: Vector3, dir: Vector3, by_player: bool, is_magic := false, is_fire := false) -> Projectile:
	var p := Projectile.new()
	p.level = owner_level
	p.from_player = by_player
	p.magic = is_magic
	p.fire = is_fire
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
		mat.albedo_color = Color(1.0, 0.55, 0.15) if is_fire else Color(0.75, 0.35, 1.0)
		orb.material_override = mat
		p.add_child(orb)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.5, 0.15) if is_fire else Color(0.7, 0.3, 1.0)
		glow.light_energy = 2.0
		glow.omni_range = 4.0
		p.add_child(glow)
		p.add_child(Effects.make_sparkles(Color(1.0, 0.6, 0.2) if is_fire else Color(0.8, 0.4, 1.0)))
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
	var homing := Vector3.INF
	if at_rival:
		if is_instance_valid(foe) and not foe.dead:
			homing = foe.global_position
	elif not level.player.dead:
		homing = level.player.global_position
	if magic and homing != Vector3.INF:
		var want := homing - global_position
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
			# Knives fly past the hero's friends (see Factions).
			if is_instance_valid(e) and not e.dead and not e.is_friend() and _hits(e.global_position):
				e.take_hit(damage, global_position - direction, "knife")
				level.player.mark_fight()
				level.player.train("werfen", 1.0)
				if e.dead and e.kind == "magier":
					level.player.train("intelligenz", 4.0)
				queue_free()
				return
	elif at_rival:
		if is_instance_valid(foe) and not foe.dead and _hits(foe.global_position):
			foe.hit_by_rival(2 if fire else damage, shooter as Enemy if is_instance_valid(shooter) else null)
			queue_free()
	else:
		var player: Player = level.player
		if not player.dead and _hits(player.global_position) and player.global_position.y < 1.2:
			var before := player.hp
			player.take_damage(2 if fire else damage, global_position - direction)
			player.defend_against(shooter)
			# A mage's orb sometimes curses whoever it hits.
			if magic and not fire and player.hp < before and randf() < CURSE_CHANCE:
				player.afflict("fluch")
			queue_free()


func _hits(target: Vector3) -> bool:
	return Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.9
