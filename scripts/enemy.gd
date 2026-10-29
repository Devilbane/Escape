class_name Enemy
extends CharacterBody3D
## A skeleton guard. Warriors run at the hero and strike with a blade,
## archers keep their distance and shoot crossbow bolts.

signal died

const MELEE_RANGE := 2.0
const SIGHT := 26.0

var level: Level
var ranged := false
var hp := 3
var dead := false

var _model: Node3D
var _anim: AnimationPlayer
var _current_anim := ""
var _busy := 0.0
var _cooldown := 0.0
var _awake := false
var _path: Array[Vector3] = []
var _repath := 0.0
var _knockback := Vector3.ZERO
var _home := Vector3.ZERO


func _ready() -> void:
	hp = 2 if ranged else 3
	add_to_group("combatant")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 2.4
	shape.shape = capsule
	shape.position.y = 1.2
	add_child(shape)

	var scene: PackedScene = load("res://assets/enemies/Skeleton_Rogue.glb" if ranged else "res://assets/enemies/Skeleton_Warrior.glb")
	_model = scene.instantiate()
	add_child(_model)
	_model.rotation.y = PI
	var skeleton: Skeleton3D = _model.find_child("Skeleton3D", true, false)
	var hand := BoneAttachment3D.new()
	hand.bone_name = "handslot.r"
	skeleton.add_child(hand)
	hand.add_child(load("res://assets/weapons/Skeleton_Crossbow.gltf" if ranged else "res://assets/weapons/Skeleton_Blade.gltf").instantiate())
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A", "Walking_D_Skeletons", "Skeleton_Inactive_Standing_Pose"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	_home = global_position
	_cooldown = randf_range(0.5, 1.5)


func _play(anim_name: String, blend := 0.2) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_anim.play(anim_name, blend)


func _play_once(anim_name: String, duration: float) -> void:
	_current_anim = ""
	_play(anim_name, 0.1)
	_busy = duration


## Kind is "hit" for a blade or "knife" for a thrown knife; it picks the comic word.
func take_hit(damage: int, from: Vector3, kind := "hit") -> void:
	if dead:
		return
	hp -= damage
	_awake = true
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 9.0
	Effects.float_text(level, global_position + Vector3(0, 2.2, 0), "-%d" % damage, Color(1, 0.45, 0.35))
	if hp <= 0:
		Comic.pop(global_position, "break")
		_die()
	else:
		Comic.pop(global_position, "big" if damage >= 2 else kind)
		_play_once("Hit_A", 0.45)


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	_play_once("Death_A", 99.0)
	died.emit()
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(self, "position:y", -2.5, 2.0)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if dead or level == null or level.player == null:
		return
	_busy = maxf(0.0, _busy - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_repath -= delta
	var player: Player = level.player
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var sees := dist < SIGHT and level.has_line_of_sight(global_position, player.global_position)
	if sees and not player.dead:
		_awake = true
	visible = level.fog.is_cell_visible(level.world_to_cell(global_position))

	var move := Vector3.ZERO
	if _awake and not player.dead and _busy <= 0.0:
		if ranged and sees and dist < 22.0:
			_face(to_player)
			if _cooldown <= 0.0:
				_shoot(player)
		elif not ranged and dist < MELEE_RANGE:
			_face(to_player)
			if _cooldown <= 0.0:
				_strike(player)
		else:
			if _repath <= 0.0 or _path.is_empty():
				_repath = 0.5
				_path.clear()
				for c in level.astar.get_id_path(level.world_to_cell(global_position), level.world_to_cell(player.global_position), true).slice(1):
					_path.append(level.cell_to_world(c))
				if sees and _path.size() <= 1:
					_path.clear()
					_path.append(player.global_position)
			if not _path.is_empty():
				var to := _path[0] - global_position
				to.y = 0.0
				if to.length() < 0.4:
					_path.remove_at(0)
				else:
					move = to.normalized()
	var speed := 3.6 if ranged else 4.8
	velocity = move * speed + _knockback
	velocity.y = -9.0
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 40.0)
	move_and_slide()
	if move != Vector3.ZERO:
		_face(move, delta)
	if _busy > 0.0:
		return
	_play("Running_A" if move != Vector3.ZERO else "Idle")


func _face(dir: Vector3, delta := -1.0) -> void:
	var target := atan2(dir.x, dir.z)
	if delta < 0.0:
		_model.rotation.y = target
	else:
		_model.rotation.y = lerp_angle(_model.rotation.y, target, 1.0 - exp(-12.0 * delta))


func _strike(player: Player) -> void:
	_cooldown = 1.4
	_play_once("1H_Melee_Attack_Chop", 0.9)
	await get_tree().create_timer(0.45).timeout
	if dead or not is_inside_tree():
		return
	var d := player.global_position - global_position
	d.y = 0.0
	if d.length() < MELEE_RANGE + 0.6:
		player.take_damage(1, global_position, self)


func _shoot(player: Player) -> void:
	_cooldown = 2.4
	_play_once("1H_Ranged_Shoot", 0.7)
	await get_tree().create_timer(0.3).timeout
	if dead or not is_inside_tree():
		return
	var origin := global_position + Vector3(0, 1.4, 0)
	var target := player.global_position + Vector3(0, 1.2, 0)
	Projectile.spawn(level, origin, target - origin, false)
