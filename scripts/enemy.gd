class_name Enemy
extends CharacterBody3D
## A skeleton guard. Warriors run at the hero and strike with a blade,
## archers keep their distance and shoot crossbow bolts, mages cast magic
## orbs that curve after the hero, minions are small, quick and frail, and
## brutes are big, slow and hit twice as hard.

signal died

const SIGHT := 26.0
const POISON_CHANCE := 0.25
## Model, weapon, life, speed, damage, reach, scale and pause between attacks.
const KINDS := {
	"krieger": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Blade", "hp": 3, "speed": 4.8, "damage": 1, "reach": 2.0, "size": 1.0, "cooldown": 1.4},
	"schuetze": {"model": "Skeleton_Rogue", "weapon": "Skeleton_Crossbow", "hp": 2, "speed": 3.6, "damage": 1, "reach": 22.0, "size": 1.0, "cooldown": 2.4, "ranged": true},
	"magier": {"model": "Skeleton_Mage", "weapon": "Skeleton_Staff", "hp": 2, "speed": 3.4, "damage": 1, "reach": 20.0, "size": 1.0, "cooldown": 3.0, "ranged": true},
	"wicht": {"model": "Skeleton_Minion", "weapon": "Skeleton_Blade", "hp": 1, "speed": 6.4, "damage": 1, "reach": 1.8, "size": 0.8, "cooldown": 1.0},
	"koloss": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_A", "hp": 7, "speed": 3.3, "damage": 2, "reach": 2.5, "size": 1.5, "cooldown": 2.0, "tint": Color(0.72, 0.42, 0.34)},
}
## Which map letter places which kind.
const LETTERS := {"M": "krieger", "A": "schuetze", "Z": "magier", "w": "wicht", "G": "koloss"}

var level: Level
var kind := "krieger"
## Elite skeletons have two more life, move and strike faster, and show it
## with dark bones and glowing red eyes.
var elite := false
## Items the skeleton wears, from the same list as the hero's. Each one
## makes it stronger and may drop when it falls.
var gear: Array[String] = []
var ranged := false
var hp := 3
var dead := false
var _stats: Dictionary

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
	_stats = KINDS[kind].duplicate()
	if elite:
		_stats.hp += 2
		_stats.speed *= 1.15
		_stats.cooldown *= 0.8
		if not _stats.has("tint"):
			_stats.tint = Color(0.42, 0.38, 0.46)
	var power := 0
	for id in gear:
		var item: Dictionary = Items.ALL[id]
		_stats.hp += item.get("hp", 0)
		power += item.get("power", 0)
		_stats.speed *= 1.0 + item.get("speed", 0.0)
	# Strength makes blows come faster; a lot of it makes them hit harder too.
	_stats.cooldown /= 1.0 + 0.2 * power
	if power >= 3:
		_stats.damage += 1
	ranged = _stats.get("ranged", false)
	hp = _stats.hp
	add_to_group("combatant")
	var size: float = _stats.size
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6 * size
	capsule.height = 2.4 * size
	shape.shape = capsule
	shape.position.y = 1.2 * size
	add_child(shape)

	_model = load("res://assets/enemies/%s.glb" % _stats.model).instantiate()
	add_child(_model)
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * size
	var skeleton: Skeleton3D = _model.find_child("Skeleton3D", true, false)
	var weapon := _worn("waffe")
	if weapon.has("model") and not ranged:
		_hold(skeleton, "handslot.r", weapon.model)
	else:
		_hold(skeleton, "handslot.r", "res://assets/weapons/%s.gltf" % _stats.weapon)
	var shield := _worn("schild")
	if _stats.has("shield"):
		_hold(skeleton, "handslot.l", "res://assets/weapons/%s.gltf" % _stats.shield)
	elif shield.has("model"):
		_hold(skeleton, "handslot.l", shield.model)
	if _stats.has("tint"):
		for mesh in _model.find_children("*", "MeshInstance3D", true, false):
			if not mesh.name.ends_with("_Eyes"):
				_tint(mesh, _stats.tint)
	# Worn cloaks and armour colour the skeleton like they colour the hero.
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		var part := "umhang" if mesh.name.ends_with("_Cloak") or mesh.name.ends_with("_Cape") else "ruestung" if mesh.name.ends_with("_Body") else ""
		if part != "" and _worn(part).has("tint"):
			_tint(mesh, _worn(part).tint, _worn(part).get("metal", 0.0))
	if elite or kind == "koloss":
		_glowing_eyes()
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A", "Walking_D_Skeletons", "Skeleton_Inactive_Standing_Pose"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	_home = global_position
	_cooldown = randf_range(0.5, 1.5)


## How much wider than a normal skeleton this one is, so blades reach it.
func girth() -> float:
	return 0.6 * (float(_stats.size) - 1.0)


## The worn item for a slot, or an empty one.
func _worn(slot: String) -> Dictionary:
	for id in gear:
		if Items.ALL[id].slot == slot:
			return Items.ALL[id]
	return {}


func _hold(skeleton: Skeleton3D, bone: String, model: String) -> void:
	var hand := BoneAttachment3D.new()
	hand.bone_name = bone
	skeleton.add_child(hand)
	hand.add_child(load(model).instantiate())


const TINT_SHADER := preload("res://shaders/tint.gdshader")


## Recolours bones (brutes, elites) or worn cloaks and armour.
func _tint(mesh: MeshInstance3D, color: Color, metal := 0.0) -> void:
	var source := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if source == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = TINT_SHADER
	mat.set_shader_parameter("tex", source.albedo_texture)
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("metal", metal)
	mesh.material_override = mat


func _glowing_eyes() -> void:
	var eyes := _model.find_child("*_Eyes", true, false) as MeshInstance3D
	if eyes == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.05)
	mat.emission_energy_multiplier = 4.0
	eyes.material_override = mat
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.2, 0.1)
	glow.light_energy = 0.5
	glow.omni_range = 1.2
	glow.position = Vector3(0, 2.0 * _stats.size, 0.6 * _stats.size)
	add_child(glow)


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
	_knockback = away.normalized() * 9.0 / (_stats.size * _stats.size)
	Effects.float_text(level, global_position + Vector3(0, 2.2 * _stats.size, 0), "-%d" % damage, Color(1, 0.45, 0.35))
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
		if ranged and sees and dist < _stats.reach:
			_face(to_player)
			if _cooldown <= 0.0:
				_shoot(player)
		elif not ranged and dist < _stats.reach:
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
	velocity = move * float(_stats.speed) + _knockback
	velocity.y = -9.0
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 40.0)
	move_and_slide()
	if move != Vector3.ZERO:
		_face(move, delta)
	if _busy > 0.0:
		return
	_play("Running_A" if move != Vector3.ZERO else "Idle")
	# Feet keep pace with the ground; bigger skeletons take longer strides.
	var ground_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	_anim.speed_scale = clampf(ground_speed / (Player.RUN_ANIM_SPEED * float(_stats.size)), 0.5, 2.5) if _current_anim == "Running_A" else 1.0


func _face(dir: Vector3, delta := -1.0) -> void:
	var target := atan2(dir.x, dir.z)
	if delta < 0.0:
		_model.rotation.y = target
	else:
		_model.rotation.y = lerp_angle(_model.rotation.y, target, 1.0 - exp(-12.0 * delta))


func _strike(player: Player) -> void:
	_cooldown = _stats.cooldown
	var slow: float = _stats.size
	_play_once("1H_Melee_Attack_Chop", 0.9 * slow)
	_anim.speed_scale = 1.0 / slow
	await get_tree().create_timer(0.45 * slow).timeout
	_anim.speed_scale = 1.0
	if dead or not is_inside_tree():
		return
	var d := player.global_position - global_position
	d.y = 0.0
	if d.length() < float(_stats.reach) + 0.6:
		var before := player.hp
		player.take_damage(_stats.damage, global_position, self)
		# Minion blades are sometimes poisoned.
		if kind == "wicht" and player.hp < before and randf() < POISON_CHANCE:
			player.afflict("gift")


func _shoot(player: Player) -> void:
	_cooldown = _stats.cooldown
	var magic: bool = kind == "magier"
	_play_once("Spellcast_Shoot" if magic else "1H_Ranged_Shoot", 0.9 if magic else 0.7)
	await get_tree().create_timer(0.5 if magic else 0.3).timeout
	if dead or not is_inside_tree():
		return
	var origin := global_position + Vector3(0, 1.4, 0)
	var target := player.global_position + Vector3(0, 1.2, 0)
	Projectile.spawn(level, origin, target - origin, false, magic)
