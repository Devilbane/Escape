class_name Player
extends CharacterBody3D
## The hooded rogue. Moves with WASD / arrow keys or walks to a clicked spot,
## jumps, fights with a dagger up close and throws knives from afar.

signal hurt(amount: int)
signal defeated
## Emitted when the hero runs into something solid, with a point just inside it.
signal bumped(point: Vector3)

const SPEED := 7.0
const JUMP_VELOCITY := 9.0
const GRAVITY := 26.0
const MAX_HP := 5
const MELEE_RANGE := 2.8
## Running into a skeleton starts a fight: the hero keeps swinging while
## standing next to it, and throws knives at it once the two are apart.
const ENGAGE_RANGE := MELEE_RANGE
const AUTO_MELEE_INTERVAL := 0.8
const AUTO_THROW_INTERVAL := 1.2
const AUTO_THROW_RANGE := 22.0
const HIDDEN_PARTS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

var level: Level
var controllable := true
## While frozen, the game moves the hero itself (e.g. up the exit stairs).
var frozen := false
var dead := false
var hp := MAX_HP
# Gifts from shrines, kept for the whole run.
var gift_hp := 0
var gift_power := 0
var gift_speed := 0.0
## Worn items by slot ("waffe", "schild", "amulett") and the bag of carried ones.
var equipped := {}
var bag: Array[String] = []
# Values from gifts and worn items together; see refresh_stats().
var max_hp := MAX_HP
var power := 1
var speed := SPEED
var knives := 5
var path: Array[Vector3] = []

var _model: Node3D
var _anim: AnimationPlayer
var _current_anim := ""
var _busy := 0.0
var _invulnerable := 0.0
var _attack_cooldown := 0.0
var _knockback := Vector3.ZERO
## The skeleton last fought up close, kept under fire from afar.
var _target: Enemy = null
var _auto_cooldown := 0.0
## Time left on an animation that plays while the hero keeps moving.
var _anim_hold := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.4
	shape.shape = capsule
	shape.position.y = 1.2
	add_child(shape)

	_model = preload("res://assets/characters/Rogue_Hooded.glb").instantiate()
	add_child(_model)
	for part in HIDDEN_PARTS:
		var node := _model.find_child(part, true, false)
		if node:
			node.visible = false
	_add_cape_logo()
	_add_trim()
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A", "Walking_A", "Jump_Idle"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("Idle")

	# A warm lantern glow around the hero, so the way ahead is never pitch black.
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.75, 0.5)
	lantern.light_energy = 1.1
	lantern.omni_range = 8.5
	lantern.position = Vector3(0, 3.2, 0.6)
	add_child(lantern)


## A golden cord along the edges of cape and hood, and a white feather on the hood.
func _add_trim() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.76, 0.28)
	gold.metallic = 0.7
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color(0.35, 0.22, 0.05)
	var cape := _model.find_child("Rogue_Cape", true, false) as MeshInstance3D
	if cape:
		var cord := MeshInstance3D.new()
		cord.mesh = Effects.cord_mesh(Effects.open_edges(cape.mesh), 0.028, gold)
		cape.add_child(cord)
	var head := _model.find_child("Rogue_Head_Hooded", true, false) as MeshInstance3D
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if head == null or skeleton == null:
		return
	# The hood is skinned to the head bone: move its rim into that bone's space.
	var bind := Transform3D.IDENTITY
	for i in head.skin.get_bind_count():
		if head.skin.get_bind_name(i) == "head":
			bind = head.skin.get_bind_pose(i)
	# The front edge of the hood around the face, read off the model (right half).
	var half := [Vector3(0, 1.80, 0.61), Vector3(0.11, 1.765, 0.565), Vector3(0.21, 1.735, 0.515),
		Vector3(0.28, 1.70, 0.48), Vector3(0.34, 1.66, 0.45), Vector3(0.415, 1.605, 0.425),
		Vector3(0.455, 1.48, 0.395), Vector3(0.43, 1.35, 0.385), Vector3(0.37, 1.275, 0.39),
		Vector3(0.26, 1.235, 0.425), Vector3(0.15, 1.22, 0.435), Vector3(0, 1.205, 0.425)]
	var loop := half.duplicate()
	for i in range(half.size() - 2, 0, -1):
		loop.append(half[i] * Vector3(-1, 1, 1))
	var rim := []
	for i in loop.size():
		rim.append([bind * loop[i], bind * loop[(i + 1) % loop.size()]])
	var attach := BoneAttachment3D.new()
	attach.bone_name = "head"
	skeleton.add_child(attach)
	var hood_cord := MeshInstance3D.new()
	hood_cord.mesh = Effects.cord_mesh(rim, 0.03, gold)
	attach.add_child(hood_cord)
	var feather := MeshInstance3D.new()
	feather.mesh = Effects.feather_mesh()
	feather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tucked in on the left side of the hood, sweeping up and back.
	feather.transform = Transform3D(Basis.from_euler(Vector3(-0.75, 0.0, -0.45)).scaled(Vector3.ONE * 1.3), bind * Vector3(0.47, 1.66, -0.05))
	attach.add_child(feather)


## The glowing devilbane emblem on the back of the cape.
func _add_cape_logo() -> void:
	var cape := _model.find_child("Rogue_Cape", true, false) as Node3D
	if cape == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.64)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/logo/devilbane_logo.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.3, 1.3, 1.3)
	quad.material = mat
	var logo := MeshInstance3D.new()
	logo.mesh = quad
	logo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Up near the shoulders, tilted to follow the cape's slope towards the hood.
	logo.position = Vector3(0, -0.36, -0.39)
	logo.rotation = Vector3(-0.3, PI, 0)
	cape.add_child(logo)


func play(anim_name: String, blend := 0.2) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_anim.play(anim_name, blend)


## Plays a one-off animation and pauses movement for its duration.
func play_once(anim_name: String, duration: float) -> void:
	_current_anim = ""
	play(anim_name, 0.1)
	_busy = duration


func face(direction: Vector3) -> void:
	_model.rotation.y = atan2(direction.x, direction.z)


func facing() -> Vector3:
	return Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))


func revive(at: Vector3) -> void:
	dead = false
	hp = max_hp
	path.clear()
	_target = null
	velocity = Vector3.ZERO
	global_position = at
	_invulnerable = 1.5
	_busy = 0.0
	play("Idle")


func walk_to(target: Vector3) -> void:
	var from := level.world_to_cell(global_position)
	var to := level.world_to_cell(target)
	path.clear()
	for c in level.astar.get_id_path(from, to, true).slice(1):
		path.append(level.cell_to_world(c))


func can_act() -> bool:
	return controllable and not frozen and not dead and _busy <= 0.0


func jump() -> void:
	if not controllable or frozen or dead or not is_on_floor():
		return
	velocity.y = JUMP_VELOCITY
	_current_anim = ""
	play("Jump_Full_Short", 0.1)


func _nearest_enemy(max_distance: float, need_sight: bool) -> Enemy:
	var best: Enemy = null
	var best_d := max_distance
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d and (not need_sight or level.has_line_of_sight(global_position, e.global_position)):
			best = e
			best_d = d
	return best


func melee() -> void:
	if not can_act() or _attack_cooldown > 0.0:
		return
	path.clear()
	var target := _nearest_enemy(MELEE_RANGE + 1.2, true)
	if target:
		_target = target
		face(target.global_position - global_position)
	_attack_cooldown = 0.5
	play_once("1H_Melee_Attack_Slice_Horizontal", 0.45)
	await get_tree().create_timer(0.18).timeout
	var hits := 0
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < MELEE_RANGE and (to.length() < 1.2 or facing().dot(to.normalized()) > 0.25):
			e.take_hit(power, global_position)
			hits += 1
	if hits == 0 and target:
		Comic.pop(global_position + facing() * 1.5, "miss")


## Throws a knife at `aim` (a world position), or at the closest enemy in sight.
## On the move the hero throws without stopping.
func throw_knife(aim = null, on_the_move := false) -> void:
	if not can_act() or _attack_cooldown > 0.0:
		return
	if knives <= 0:
		Effects.float_text(level, global_position + Vector3(0, 3.2, 0), "Keine Wurfmesser", Color(1, 1, 1, 0.8))
		return
	path.clear()
	var dir := facing()
	if aim is Vector3:
		dir = aim - global_position
	else:
		var target := _nearest_enemy(26.0, true)
		if target:
			dir = target.global_position - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = facing()
	face(dir)
	knives -= 1
	_attack_cooldown = 0.6
	if on_the_move:
		_current_anim = ""
		play("Throw", 0.1)
		_anim_hold = 0.45
	else:
		play_once("Throw", 0.45)
	await get_tree().create_timer(0.2).timeout
	Projectile.spawn(level, global_position + Vector3(0, 1.5, 0) + dir.normalized() * 0.6, dir, true).damage = power


func _engage(enemy: Enemy) -> void:
	if enemy.dead:
		return
	if _target != enemy:
		_auto_cooldown = 0.0
	_target = enemy


## Keeps fighting the current target: blade while next to it, knives from afar.
func _auto_attack() -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or _target.dead:
		_target = null
		return
	if not can_act() or _auto_cooldown > 0.0 or _attack_cooldown > 0.0:
		return
	var d := global_position.distance_to(_target.global_position)
	if d <= ENGAGE_RANGE:
		_auto_cooldown = AUTO_MELEE_INTERVAL
		melee()
	elif d <= AUTO_THROW_RANGE and knives > 0 and level.has_line_of_sight(global_position, _target.global_position):
		_auto_cooldown = AUTO_THROW_INTERVAL
		throw_knife(_target.global_position, true)


## A fresh hero for a new game: no gifts, no items.
func reset_gifts() -> void:
	gift_hp = 0
	gift_power = 0
	gift_speed = 0.0
	equipped = {}
	bag.clear()
	refresh_stats()


## Recomputes life, strength and speed from gifts and worn items,
## and shows the worn weapon and shield in the hero's hands.
func refresh_stats() -> void:
	var hp_bonus := gift_hp
	var power_bonus := gift_power
	var speed_bonus := gift_speed
	for slot in equipped:
		var item: Dictionary = Items.ALL[equipped[slot]]
		hp_bonus += item.get("hp", 0)
		power_bonus += item.get("power", 0)
		speed_bonus += item.get("speed", 0.0)
	max_hp = MAX_HP + hp_bonus
	power = 1 + power_bonus
	speed = SPEED * (1.0 + speed_bonus)
	hp = mini(hp, max_hp)
	_show_held("waffe", "handslot_r", "Knife")
	_show_held("schild", "handslot_l", "")


func _show_held(slot: String, hand_name: String, default_part: String) -> void:
	var hand := _model.find_child(hand_name, true, false)
	var old := hand.get_node_or_null("Held")
	if old:
		old.free()
	var id: String = equipped.get(slot, "")
	if default_part != "":
		hand.get_node(default_part).visible = id == ""
	if id != "" and Items.ALL[id].has("model"):
		var model: Node3D = load(Items.ALL[id].model).instantiate()
		model.name = "Held"
		hand.add_child(model)


## Moves a bag item into its slot; whatever was worn there goes into the bag.
func equip(id: String) -> void:
	var slot: String = Items.ALL[id].slot
	bag.erase(id)
	if equipped.has(slot):
		bag.append(equipped[slot])
	equipped[slot] = id
	refresh_stats()


## Takes off a worn item. False when the bag has no room for it.
func unequip(slot: String) -> bool:
	if not equipped.has(slot) or bag.size() >= Items.BAG_SIZE:
		return false
	bag.append(equipped[slot])
	equipped.erase(slot)
	refresh_stats()
	return true


func take_damage(amount: int, from: Vector3) -> void:
	if dead or _invulnerable > 0.0 or frozen:
		return
	hp -= amount
	_invulnerable = 0.9
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 10.0
	path.clear()
	Effects.float_text(level, global_position + Vector3(0, 2.2, 0), "-%d" % amount, Color(1, 0.3, 0.3))
	Comic.pop(global_position, "hurt")
	hurt.emit(amount)
	if hp <= 0:
		dead = true
		play_once("Death_A", 99.0)
		defeated.emit()
	else:
		play_once("Hit_A", 0.35)


func _keyboard_direction() -> Vector3:
	var x := 0.0
	var z := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		z -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		z += 1.0
	return Vector3(x, 0, z).normalized()


func _physics_process(delta: float) -> void:
	if frozen:
		return
	_busy = maxf(0.0, _busy - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_auto_cooldown = maxf(0.0, _auto_cooldown - delta)
	_anim_hold = maxf(0.0, _anim_hold - delta)
	_auto_attack()
	var dir := Vector3.ZERO
	if controllable and not dead and _busy <= 0.0:
		dir = _keyboard_direction()
		if dir != Vector3.ZERO:
			path.clear()
		elif not path.is_empty():
			var to := path[0] - global_position
			to.y = 0.0
			if to.length() < 0.3:
				path.remove_at(0)
			if not path.is_empty():
				to = path[0] - global_position
				to.y = 0.0
				dir = to.normalized()
	var vy := velocity.y - GRAVITY * delta
	velocity = dir * speed + _knockback
	velocity.y = vy
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 45.0)
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	if dir != Vector3.ZERO:
		for i in get_slide_collision_count():
			var hit := get_slide_collision(i)
			if dir.dot(-hit.get_normal()) > 0.5:
				var enemy := hit.get_collider() as Enemy
				if enemy:
					_engage(enemy)
				else:
					bumped.emit(hit.get_position() - hit.get_normal() * 0.2)
	if dir != Vector3.ZERO and _anim_hold <= 0.0:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-14.0 * delta))
	# Blink while invulnerable after a hit.
	_model.visible = dead or _invulnerable <= 0.0 or int(_invulnerable * 12.0) % 2 == 0
	if _busy > 0.0 or _anim_hold > 0.0 or not controllable or dead:
		return
	if not is_on_floor():
		if _current_anim != "Jump_Full_Short":
			play("Jump_Idle")
		return
	play("Running_A" if dir != Vector3.ZERO else "Idle")
