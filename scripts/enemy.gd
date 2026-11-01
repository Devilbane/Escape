class_name Enemy
extends CharacterBody3D
## A skeleton guard. Warriors run at the hero and strike with a blade,
## archers keep their distance and shoot crossbow bolts, mages cast magic
## orbs that curve after the hero, minions are small, quick and frail, and
## brutes are big, slow and hit twice as hard. A guardian wears armour no
## blade gets through: only a stab in the back, before it has noticed the
## hero, brings it down. It stands still and watches what it guards.
## Any skeleton that has not noticed the hero falls to such a stab at once.
##
## Out in the open the same class runs the bandits of the robbers' pass:
## people, not bones, in the adventurer models. They roam around their camp
## instead of standing guard, taunt the hero instead of groaning, and drop
## gold and gear when they fall (see Outdoor).

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
## A guardian never strays farther than this from its post: it breaks off
## the hunt and walks back, so running out of its hall always works.
const LEASH := 14.0
const POISON_CHANCE := 0.25
## Model, weapon, life, speed, damage, reach, scale and pause between attacks.
const KINDS := {
	"krieger": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Blade", "hp": 3, "speed": 4.8, "damage": 1, "reach": 2.0, "size": 1.0, "cooldown": 1.4},
	"schuetze": {"model": "Skeleton_Rogue", "weapon": "Skeleton_Crossbow", "hp": 2, "speed": 3.6, "damage": 1, "reach": 22.0, "size": 1.0, "cooldown": 2.4, "ranged": true},
	"magier": {"model": "Skeleton_Mage", "weapon": "Skeleton_Staff", "hp": 2, "speed": 3.4, "damage": 1, "reach": 20.0, "size": 1.0, "cooldown": 3.0, "ranged": true},
	"wicht": {"model": "Skeleton_Minion", "weapon": "Skeleton_Blade", "hp": 1, "speed": 6.4, "damage": 1, "reach": 1.8, "size": 0.8, "cooldown": 1.0},
	"koloss": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_A", "hp": 7, "speed": 3.3, "damage": 2, "reach": 2.5, "size": 1.5, "cooldown": 2.0, "tint": Color(0.72, 0.42, 0.34)},
	"waechter": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_A", "hp": 1, "speed": 3.0, "damage": 2, "reach": 2.3, "size": 1.25, "cooldown": 1.6, "tint": Color(0.46, 0.5, 0.58), "armored": true},
	# The bandits of the open wild: "human" kinds use the adventurer models
	# ("dir"), keep only the body parts in "parts", wear clothes in "colors"
	# (body, legs, hat or cape) and "roam" around where they were placed.
	"halsabschneider": {"model": "Rogue", "dir": "characters", "weapon": "dagger", "hp": 3, "speed": 5.2, "damage": 1, "reach": 1.9, "size": 1.0, "cooldown": 1.1,
		"human": true, "roam": true, "parts": ["Rogue_Cape"], "colors": [Color(0.32, 0.3, 0.28), Color(0.28, 0.24, 0.2), Color(0.22, 0.2, 0.18)]},
	"wilderer": {"model": "Rogue", "dir": "characters", "weapon": "Skeleton_Crossbow", "hp": 2, "speed": 4.0, "damage": 1, "reach": 20.0, "size": 1.0, "cooldown": 2.6, "ranged": true,
		"human": true, "roam": true, "parts": [], "colors": [Color(0.3, 0.42, 0.26), Color(0.36, 0.3, 0.22), Color(1, 1, 1)]},
	"schlaeger": {"model": "Barbarian", "dir": "characters", "weapon": "axe_1handed", "hp": 6, "speed": 3.8, "damage": 2, "reach": 2.3, "size": 1.15, "cooldown": 1.8,
		"human": true, "roam": true, "parts": ["Barbarian_Hat"], "colors": [Color(0.5, 0.36, 0.28), Color(0.3, 0.26, 0.22), Color(0.4, 0.3, 0.22)]},
	# The chief is the boss of the pass (see BanditChief).
	"hauptmann": {"model": "Knight", "dir": "characters", "weapon": "sword_1handed", "shield": "shield_round", "hp": 20, "speed": 4.2, "damage": 2, "reach": 2.2, "size": 1.1, "cooldown": 1.4,
		"human": true, "roam": true, "parts": ["Knight_Cape"], "colors": [Color(0.45, 0.14, 0.12), Color(0.22, 0.2, 0.2), Color(0.5, 0.1, 0.1)]},
}
## Which map letter places which kind.
const LETTERS := {"M": "krieger", "A": "schuetze", "Z": "magier", "w": "wicht", "G": "koloss", "W": "waechter"}
## The letters of the open-air map that place bandits (see Outdoor).
const WILD_LETTERS := {"c": "halsabschneider", "A": "wilderer", "X": "schlaeger", "Q": "hauptmann"}
## Body parts every adventurer model keeps; the rest shows only when a kind asks for it.
const BODY_PARTS := ["Body", "Head", "ArmLeft", "ArmRight", "LegLeft", "LegRight"]
## How far from home a roaming bandit wanders (tiles), and how far it will
## chase the hero (metres) before it gives up and strolls back.
const ROAM_TILES := 4
const LEASH_ROAM := 48.0
## A stab counts as from behind when it comes from outside this angle either
## side of where the skeleton looks.
const BEHIND := deg_to_rad(100.0)

var level: Level
var kind := "krieger"
## Elite skeletons have two more life, move and strike faster, and show it
## with dark bones and glowing red eyes.
var elite := false
## Out at night (see Outdoor): a bandit is bolder, with two more life and
## quicker blows; a skeleton risen from its grave roams the graveyard
## instead of standing guard.
var night := false
## A risen skeleton caught by the dawn sinks back into its grave as soon as
## it is off the hunt.
var _dawn := false
## Items the skeleton wears, from the same list as the hero's. Each one
## makes it stronger and may drop when it falls.
var gear: Array[String] = []
var ranged := false
var hp := 3
var dead := false
var _stats: Dictionary
## The spot the skeleton takes up (see Level.push_apart).
var radius := 0.6
var tall := 2.4

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
## Every kind has a voice of its own (voice_<kind>_0 and _1), so the hero
## can tell what lurks nearby. Out of sight, a word shows where it came from.
const VOICE_RANGE := 18.0
const VOICE_WORDS := {"krieger": "knurr", "schuetze": "zisch", "magier": "murmel",
	"wicht": "kicher", "koloss": "GROLL", "waechter": "klirr"}
## What a bandit shouts while it hunts the hero.
const TAUNTS := ["Her mit dem Gold!", "Den schnappen wir uns!", "Dein Beutel oder dein Leben!", "Keiner kommt hier durch!"]
var _voice_timer := 0.0
## Where a roaming bandit is strolling to, and how long it lingers there.
var _roam_pause := 0.0


func _ready() -> void:
	_stats = KINDS[kind].duplicate()
	if elite:
		_stats.hp += 2
		_stats.speed *= 1.15
		_stats.cooldown *= 0.8
		if not _stats.has("tint"):
			_stats.tint = Color(0.42, 0.38, 0.46)
	if night and is_human():
		_stats.hp += 2
		_stats.cooldown *= 0.85
		_stats.speed *= 1.08
	elif night:
		_stats.roam = true
	var power := 0
	var gear_weight := 0.0
	for id in gear:
		var item: Dictionary = Items.ALL[id]
		_stats.hp += item.get("hp", 0)
		power += item.get("power", 0)
		_stats.speed *= 1.0 + item.get("speed", 0.0)
		gear_weight += Items.weight(id)
	# Skeletons carry their gear's weight just like the hero.
	_stats.speed *= Items.load_factor(gear_weight)
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
	radius = 0.6 * minf(size, 1.25)
	tall = 2.4 * size
	capsule.radius = radius
	capsule.height = tall
	shape.shape = capsule
	shape.position.y = 1.2 * size
	add_child(shape)

	_model = load("res://assets/%s/%s.glb" % [_stats.get("dir", "enemies"), _stats.model]).instantiate()
	add_child(_model)
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * size
	if is_human():
		_dress()
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
	for a in ["Idle", "Running_A", "Walking_A", "Walking_D_Skeletons", "Skeleton_Inactive_Standing_Pose"]:
		if _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	_cooldown = randf_range(0.5, 1.5)
	_look_angle = randf() * TAU
	_model.rotation.y = _look_angle
	_look_timer = randf_range(2.0, 5.0)
	_voice_timer = randf_range(2.0, 10.0)


## How much wider than a normal skeleton this one is, so blades reach it.
func girth() -> float:
	return 0.6 * (float(_stats.size) - 1.0)


## Whether this is a person (a bandit) rather than a skeleton.
func is_human() -> bool:
	return _stats.get("human", false)


## Bandits keep only their body and the parts their kind asks for, and
## wear clothes in their kind's colours (body, legs, hat or cape). A worn
## cloak from the gear shows as the model's own cape.
func _dress() -> void:
	var parts: Array = _stats.get("parts", [])
	var colors: Array = _stats.get("colors", [])
	if _worn("umhang").has("tint"):
		for mi: MeshInstance3D in _model.find_children("*_Cape", "MeshInstance3D", true, false):
			parts = parts + [String(mi.name)]
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		var base := ""
		for b in BODY_PARTS:
			if part.ends_with("_" + b):
				base = b
		if base == "" and not part in parts:
			mi.visible = false
			continue
		var color := Color.WHITE
		if base == "Body":
			color = colors[0]
		elif base.begins_with("Leg"):
			color = colors[1]
		elif base.begins_with("Arm"):
			color = Color.WHITE.lerp(colors[0], 0.5)
		elif base == "":
			color = colors[2]
		if color != Color.WHITE:
			var mat := mi.get_active_material(0)
			if mat is StandardMaterial3D:
				var dyed: StandardMaterial3D = mat.duplicate()
				dyed.albedo_color = color
				mi.material_override = dyed


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
		Comic.pop(global_position, "block")
		return
	hp -= damage
	if wakes:
		_wake(from)
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 9.0 / (_stats.size * _stats.size)
	Effects.float_text(level, global_position + Vector3(0, 2.2 * _stats.size, 0), "-%d" % damage, Color(1, 0.45, 0.35))
	# The comic word below makes the sound of the blow.
	if hp <= 0:
		if is_human():
			# No bones to rattle: a person goes down with a thud.
			Comic.pop(global_position, "backstab" if kind == "backstab" else "big")
			Sfx.play(self, "hit", -2.0, global_position)
		else:
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


## Dawn has come: back into the grave, now or once the hunt is over.
func sink_at_dawn() -> void:
	_dawn = true


## Sinks into the earth and is gone: no fall, no loot.
func _sink() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	_play("Idle")
	var tween := create_tween()
	tween.tween_property(self, "position:y", -2.8, 2.2)
	tween.tween_callback(queue_free)


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
	if _dawn and not _awake:
		_sink()
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
	# Under the open sky there is no fog of war: everything shows.
	visible = level.fog == null or level.fog.is_cell_visible(level.world_to_cell(global_position))
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
	var leash := LEASH if _watch != Vector3.INF else LEASH_ROAM if _stats.get("roam", false) else INF
	if _awake and _home != Vector3.INF and global_position.distance_to(_home) > leash:
		_awake = false
		_path.clear()
		_repath = 0.0

	var move := _step_out() if _busy <= 0.0 else Vector3.ZERO
	if move != Vector3.ZERO:
		pass # Out of the furniture first.
	elif _awake and not player.dead and _busy <= 0.0:
		if level.stacked(self, player):
			pass # Inside the hero's spot: no blow or shot until pushed apart.
		elif ranged and sees and _lost <= 0.0 and dist < _stats.reach:
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
		move = _roam(delta) if _stats.get("roam", false) else _rest(delta)
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
	# Off the hunt, a bandit strolls; skeletons shuffle back to their post.
	var strolling: bool = move != Vector3.ZERO and move.length() < 0.7 and (is_human() or _stats.get("roam", false))
	var walk: String = "Walking_D_Skeletons" if not is_human() and _anim.has_animation("Walking_D_Skeletons") else "Walking_A"
	_play(walk if strolling else "Running_A" if move != Vector3.ZERO else "Idle")
	_footfalls(delta, move != Vector3.ZERO, dist)
	_voice(delta, dist)
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
	Sfx.play(level, "step_%d" % (randi() % 6), lerpf(-24.0, -10.0, 1.0 - dist / HEARD_FROM), global_position)
	Effects.float_text(level, global_position + Vector3(0, 1.0, 0), Lang.t("tapp"), Color(0.7, 0.7, 0.75, 0.6))


## Now and then a groan, hiss, murmur or clank. The nearer the skeleton, the
## louder, more often and more urgent its voice; on the hunt it never stops.
func _voice(delta: float, dist: float) -> void:
	_voice_timer -= delta
	if _voice_timer > 0.0:
		return
	# 0 at the edge of hearing, 1 right next to the hero.
	var near := clampf(1.0 - dist / VOICE_RANGE, 0.0, 1.0)
	_voice_timer = lerpf(11.0, 2.5, near) * randf_range(0.7, 1.3)
	if _awake:
		_voice_timer *= 0.5
	if near <= 0.0:
		return
	if is_human():
		# A bandit has no groan of its own: it shouts while it hunts.
		if _awake:
			Effects.float_text(level, global_position + Vector3(0, 3.0 * _stats.size, 0), Lang.t(TAUNTS[randi() % TAUNTS.size()]), Color(1.0, 0.85, 0.6, 0.9))
		return
	var db := lerpf(-28.0, 2.0, pow(near, 1.4)) + (3.0 if _awake else 0.0)
	Sfx.play(level, "voice_%s_%d" % [kind, randi() % 2], db, global_position, lerpf(0.9, 1.1, near))
	if not visible:
		var word: String = Lang.t(VOICE_WORDS[kind])
		if near > 0.6:
			word = word.to_upper() + "!"
		Effects.float_text(level, global_position + Vector3(0, 1.6, 0), word, Color(0.75, 0.72, 0.8, lerpf(0.4, 0.9, near)))


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


## Sets the skeleton on the hero at once, e.g. a cutthroat called by the chief.
func alert(at: Vector3) -> void:
	_wake(at)


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
	if not _awake:
		# A stroll's path is no use on the hunt.
		_path.clear()
		_repath = 0.0
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


## A bandit off the hunt strolls from one spot near its home to the next,
## lingers a while, looks around and moves on.
func _roam(delta: float) -> Vector3:
	if _roam_pause > 0.0:
		_roam_pause -= delta
		_look_around(delta)
		return Vector3.ZERO
	if _path.is_empty():
		var home_cell := level.world_to_cell(_home)
		var here := level.world_to_cell(global_position)
		for attempt in 8:
			var c := home_cell + Vector2i(randi_range(-ROAM_TILES, ROAM_TILES), randi_range(-ROAM_TILES, ROAM_TILES))
			if c == here or not level.astar.is_in_boundsv(c) or level.astar.is_point_solid(c):
				continue
			for p in level.astar.get_id_path(here, c, true).slice(1):
				_path.append(level.cell_to_world(p) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)))
			if not _path.is_empty():
				break
		if _path.is_empty():
			_roam_pause = 2.0
			return Vector3.ZERO
	var to := _path[0] - global_position
	to.y = 0.0
	if to.length() < 0.5:
		_path.remove_at(0)
		if _path.is_empty():
			_roam_pause = randf_range(2.0, 7.0)
		return Vector3.ZERO
	return to.normalized() * 0.45


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
	if d.length() < float(_stats.reach) + 0.6 and not level.stacked(self, player):
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
	if dead or not is_inside_tree() or level.stacked(self, player):
		return
	var origin := global_position + Vector3(0, 1.4, 0)
	var target := player.global_position + Vector3(0, 1.2, 0)
	Sfx.play(self, "magic" if magic else "bow_%d" % (randi() % 3), -2.0, global_position)
	Projectile.spawn(level, origin, target - origin, false, magic).shooter = self
