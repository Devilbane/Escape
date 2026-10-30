class_name Enemy
extends CharacterBody3D
## A skeleton guard. Warriors run at the hero and strike with a blade,
## archers keep their distance and shoot crossbow bolts, mages cast magic
## orbs that curve after the hero, minions are small, quick and frail, and
## brutes are big, slow and hit twice as hard. A guardian wears armour no
## blade gets through: only a stab in the back, before it has noticed the
## hero, brings it down. It stands still and watches what it guards.
## Any skeleton that has not noticed the hero falls to such a stab at once.

signal died

const SIGHT := 26.0
## Noticing the hero. Eyes look ahead in a 120 degree cone and need light on
## the hero (a burning torch nearby, or the lantern when not sneaking). Ears
## hear all around, but not a hero who sneaks or stands still. Right up
## close, a skeleton always notices.
const SIGHT_CONE := deg_to_rad(60.0)
const HEARING := 10.0
const TOUCH := 2.2
## Seconds a hunting skeleton searches after losing the hero before it gives up.
const GIVE_UP := 5.0
const POISON_CHANCE := 0.25
## Model, weapon, life, speed, damage, reach, scale and pause between attacks.
const KINDS := {
	"krieger": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Blade", "hp": 3, "speed": 4.8, "damage": 1, "reach": 2.0, "size": 1.0, "cooldown": 1.4},
	"schuetze": {"model": "Skeleton_Rogue", "weapon": "Skeleton_Crossbow", "hp": 2, "speed": 3.6, "damage": 1, "reach": 22.0, "size": 1.0, "cooldown": 2.4, "ranged": true},
	"magier": {"model": "Skeleton_Mage", "weapon": "Skeleton_Staff", "hp": 2, "speed": 3.4, "damage": 1, "reach": 20.0, "size": 1.0, "cooldown": 3.0, "ranged": true},
	"wicht": {"model": "Skeleton_Minion", "weapon": "Skeleton_Blade", "hp": 1, "speed": 6.4, "damage": 1, "reach": 1.8, "size": 0.8, "cooldown": 1.0},
	"koloss": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_A", "hp": 7, "speed": 3.3, "damage": 2, "reach": 2.5, "size": 1.5, "cooldown": 2.0, "tint": Color(0.72, 0.42, 0.34)},
	"waechter": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_A", "hp": 1, "speed": 3.0, "damage": 2, "reach": 2.3, "size": 1.25, "cooldown": 1.6, "tint": Color(0.46, 0.5, 0.58), "armored": true},
}
## Which map letter places which kind.
const LETTERS := {"M": "krieger", "A": "schuetze", "Z": "magier", "w": "wicht", "G": "koloss", "W": "waechter"}
## A stab counts as from behind when it comes from outside this angle either
## side of where the skeleton looks.
const BEHIND := deg_to_rad(100.0)

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
## Seconds spent pushing without getting anywhere, and the sidestep out.
var _stuck := 0.0
## Seconds before spikes can hurt this skeleton again.
var _trap_cool := 0.0
var _detour := Vector3.ZERO
var _detour_time := 0.0
var _path: Array[Vector3] = []
var _repath := 0.0
var _knockback := Vector3.ZERO
## The post, taken where the skeleton stands on its first frame (the level
## places it only after it is ready).
var _home := Vector3.INF
## Where the hero was last noticed, and how long ago.
var _last_known := Vector3.ZERO
var _lost := 0.0
## A guard at rest looks around now and then.
var _look_angle := 0.0
var _look_timer := 0.0
## Where a guardian keeps looking while at its post.
var _watch := Vector3.INF
var _step_timer := 0.0
## How far the hero hears a skeleton walking in the dark.
const HEARD_FROM := 16.0


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
	# The colossus is a touch slimmer than it looks, so it fits through doors.
	capsule.radius = 0.6 * minf(size, 1.25)
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
	if elite or kind == "koloss" or kind == "waechter":
		_glowing_eyes()
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A", "Walking_D_Skeletons", "Skeleton_Inactive_Standing_Pose"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	_cooldown = randf_range(0.5, 1.5)
	_look_angle = randf() * TAU
	_model.rotation.y = _look_angle
	_look_timer = randf_range(2.0, 5.0)


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


## Has the guardian look at a spot (what it guards) while at its post.
func watch(at: Vector3) -> void:
	_watch = at
	var dir := at - global_position
	_look_angle = atan2(dir.x, dir.z)
	_model.rotation.y = _look_angle


## Which way the skeleton looks.
func ahead() -> Vector3:
	return Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))


## Whether a blade from `from` would be a stab in the back: from behind,
## and the skeleton has not noticed the hero.
func open_to_backstab(from: Vector3) -> bool:
	var to := from - global_position
	to.y = 0.0
	return not _awake and not dead and ahead().angle_to(to) > BEHIND


## Kind is "hit" for a blade, "knife" for a thrown knife or "backstab" for a
## stab in the back; it picks the comic word.
func take_hit(damage: int, from: Vector3, kind := "hit", wakes := true) -> void:
	if dead:
		return
	if kind == "backstab":
		damage = hp
	elif _stats.get("armored", false):
		# Blades glance off the guardian's armour, and it turns to fight.
		if wakes:
			_wake(from)
		Effects.float_text(level, global_position + Vector3(0, 2.2 * _stats.size, 0), Lang.t("Nur ein Stich in den Rücken!"), Color(0.8, 0.85, 0.95))
		Sfx.play(self, "hit", 0.0, global_position)
		Comic.pop(global_position, "block")
		return
	hp -= damage
	if wakes:
		_wake(from)
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 9.0 / (_stats.size * _stats.size)
	Effects.float_text(level, global_position + Vector3(0, 2.2 * _stats.size, 0), "-%d" % damage, Color(1, 0.45, 0.35))
	Sfx.play(self, "hit", 0.0, global_position)
	if hp <= 0:
		Comic.pop(global_position, "backstab" if kind == "backstab" else "break")
		Sfx.play(self, "bones", 0.0, global_position)
		_die()
	else:
		Comic.pop(global_position, "big" if damage >= 2 else kind)
		_play_once("Hit_A", 0.45)


## Spikes hurt skeletons too, once per thrust.
func hurt_by_trap(at: Vector3) -> void:
	if _trap_cool > 0.0 or dead or _stats.get("armored", false):
		return
	_trap_cool = 1.2
	take_hit(1, at, "hit", false)


## Waits at the edge of a spike trap that is up or about to strike, rather
## than walk into it. Already standing on one, it keeps going to get off.
func _mind_spikes(move: Vector3) -> Vector3:
	if move == Vector3.ZERO:
		return move
	var here := level.world_to_cell(global_position)
	var ahead := level.world_to_cell(global_position + move * Level.TILE * 0.45)
	if ahead != here and not level.is_spike_cell(here) and level.spike_danger(ahead):
		return Vector3.ZERO
	return move


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
	if _home == Vector3.INF:
		_home = global_position
	_busy = maxf(0.0, _busy - delta)
	_trap_cool = maxf(0.0, _trap_cool - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_repath -= delta
	var player: Player = level.player
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var sees := dist < SIGHT and level.has_line_of_sight(global_position, player.global_position)
	visible = level.fog.is_cell_visible(level.world_to_cell(global_position))
	if not player.dead and _notices(player, to_player, dist, sees):
		if not _awake:
			Effects.float_text(level, global_position + Vector3(0, 3.4 * _stats.size, 0), "!", Color(1.0, 0.3, 0.2))
		_wake(player.global_position)
	elif _awake:
		_lost += delta
		if _lost > GIVE_UP or player.dead:
			_awake = false
			_path.clear()
			_repath = 0.0

	var move := _step_out() if _busy <= 0.0 else Vector3.ZERO
	if move != Vector3.ZERO:
		pass # Out of the furniture first.
	elif _awake and not player.dead and _busy <= 0.0:
		if ranged and sees and _lost <= 0.0 and dist < _stats.reach:
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
				for c in level.astar.get_id_path(level.world_to_cell(global_position), level.world_to_cell(_last_known), true).slice(1):
					_path.append(level.cell_to_world(c))
				if _lost <= 0.0 and sees and _path.size() <= 1:
					_path.clear()
					_path.append(player.global_position)
			if not _path.is_empty():
				var to := _path[0] - global_position
				to.y = 0.0
				if to.length() < 0.4:
					_path.remove_at(0)
				else:
					move = to.normalized()
			elif _lost > 0.0:
				_look_around(delta)
	elif not _awake and not dead:
		move = _rest(delta)
	if _detour_time > 0.0 and move != Vector3.ZERO:
		_detour_time -= delta
		move = (move * 0.3 + _detour).normalized()
	move = _mind_spikes(move)
	velocity = move * float(_stats.speed) + _knockback
	velocity.y = -9.0
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 40.0)
	move_and_slide()
	if move != Vector3.ZERO:
		_face(move, delta)
	_check_stuck(delta, move)
	if _busy > 0.0:
		return
	_play("Running_A" if move != Vector3.ZERO else "Idle")
	_footfalls(delta, move != Vector3.ZERO, dist)
	# Feet keep pace with the ground; bigger skeletons take longer strides.
	var ground_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	_anim.speed_scale = clampf(ground_speed / (Player.RUN_ANIM_SPEED * float(_stats.size)), 0.5, 2.5) if _current_anim == "Running_A" else 1.0


## A skeleton hidden in the dark can still be heard: footsteps and a faint
## mark where they sound.
func _footfalls(delta: float, moving: bool, dist: float) -> void:
	_step_timer -= delta
	if visible or not moving or dist > HEARD_FROM or _step_timer > 0.0:
		return
	_step_timer = 0.8
	Sfx.play(level, "step_%d" % (randi() % 6), -16.0, global_position)
	Effects.float_text(level, global_position + Vector3(0, 1.0, 0), Lang.t("tapp"), Color(0.7, 0.7, 0.75, 0.6))


## Caught on a table corner or a door frame: step aside for a moment and
## look for a new way.
func _check_stuck(delta: float, move: Vector3) -> void:
	var ground_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if move == Vector3.ZERO or ground_speed > float(_stats.speed) * 0.3:
		_stuck = maxf(0.0, _stuck - delta)
		return
	_stuck += delta
	if _stuck < 0.5:
		return
	_stuck = 0.0
	_repath = 0.0
	_path.clear()
	var side := move.cross(Vector3.UP).normalized()
	var cell := level.world_to_cell(global_position + side * Level.TILE * 0.6)
	if level.astar.is_in_boundsv(cell) and level.astar.is_point_solid(cell):
		side = -side
	elif randf() < 0.3:
		side = -side
	_detour = side
	_detour_time = 0.6


## Pushed into a tile with a pillar or furniture, where neither paths nor
## the hero's blade reach well: walk out to the nearest free tile.
func _step_out() -> Vector3:
	var cell := level.world_to_cell(global_position)
	if not level.astar.is_in_boundsv(cell) or not level.astar.is_point_solid(cell):
		return Vector3.ZERO
	for d in Level.DIRS:
		if level.astar.is_in_boundsv(cell + d) and not level.astar.is_point_solid(cell + d):
			var to := level.cell_to_world(cell + d) - global_position
			to.y = 0.0
			return to.normalized()
	return Vector3.ZERO


## Whether the skeleton has spotted the hero and is after them.
func is_hunting() -> bool:
	return _awake and not dead


## Whether the skeleton sees or hears the hero right now.
func _notices(player: Player, to_player: Vector3, dist: float, sees: bool) -> bool:
	var in_view := ahead_angle(to_player) <= SIGHT_CONE
	# Right up close it notices, unless the hero sneaks up from behind.
	if dist < TOUCH and (in_view or not player.sneaking or _awake):
		return true
	if dist < HEARING and player.is_noisy():
		return true
	if not sees or not player.is_lit():
		return false
	# Once hunting, a skeleton keeps its eyes on the hero all around.
	return _awake or in_view


func ahead_angle(to: Vector3) -> float:
	return ahead().angle_to(to)


## Starts or keeps up the hunt, heading for where the hero was noticed.
func _wake(at: Vector3) -> void:
	_awake = true
	_lost = 0.0
	_last_known = at


## Off the hunt: walk back to the post, then stand guard and look around.
func _rest(delta: float) -> Vector3:
	var to_home := _home - global_position
	to_home.y = 0.0
	if to_home.length() < 1.0:
		_path.clear()
		if _watch != Vector3.INF:
			# A guardian turns back to what it guards and keeps still.
			_model.rotation.y = lerp_angle(_model.rotation.y, _look_angle, 1.0 - exp(-3.0 * delta))
		else:
			_look_around(delta)
		return Vector3.ZERO
	if _repath <= 0.0 or _path.is_empty():
		_repath = 1.0
		_path.clear()
		for c in level.astar.get_id_path(level.world_to_cell(global_position), level.world_to_cell(_home), true).slice(1):
			_path.append(level.cell_to_world(c))
		_path.append(_home)
	var to := _path[0] - global_position
	to.y = 0.0
	if to.length() < 0.4:
		_path.remove_at(0)
		return Vector3.ZERO
	return to.normalized() * 0.6


func _look_around(delta: float) -> void:
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(2.5, 5.0)
		_look_angle = _model.rotation.y + randf_range(-PI * 0.75, PI * 0.75)
	_model.rotation.y = lerp_angle(_model.rotation.y, _look_angle, 1.0 - exp(-3.0 * delta))


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
	Sfx.play(self, "swing", -4.0, global_position)
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
	Sfx.play(self, "magic" if magic else "bow_%d" % (randi() % 3), -2.0, global_position)
	Projectile.spawn(level, origin, target - origin, false, magic)
