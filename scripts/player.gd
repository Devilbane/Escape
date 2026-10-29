class_name Player
extends CharacterBody3D
## The hooded rogue. Moves with WASD / arrow keys or walks to a clicked spot,
## jumps, fights with a dagger up close and throws knives from afar.

signal hurt(amount: int)
signal defeated

const SPEED := 7.0
const JUMP_VELOCITY := 9.0
const GRAVITY := 26.0
const MAX_HP := 5
const MELEE_RANGE := 2.8
const HIDDEN_PARTS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

var level: Level
var controllable := true
## While frozen, the game moves the hero itself (e.g. up the exit stairs).
var frozen := false
var dead := false
var hp := MAX_HP
var knives := 5
var path: Array[Vector3] = []

var _model: Node3D
var _anim: AnimationPlayer
var _current_anim := ""
var _busy := 0.0
var _invulnerable := 0.0
var _attack_cooldown := 0.0
var _knockback := Vector3.ZERO


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
	hp = MAX_HP
	path.clear()
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
		face(target.global_position - global_position)
	_attack_cooldown = 0.5
	play_once("1H_Melee_Attack_Slice_Horizontal", 0.45)
	await get_tree().create_timer(0.18).timeout
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < MELEE_RANGE and (to.length() < 1.2 or facing().dot(to.normalized()) > 0.25):
			e.take_hit(1, global_position)


## Throws a knife at `aim` (a world position), or at the closest enemy in sight.
func throw_knife(aim = null) -> void:
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
	play_once("Throw", 0.45)
	await get_tree().create_timer(0.2).timeout
	Projectile.spawn(level, global_position + Vector3(0, 1.5, 0) + dir.normalized() * 0.6, dir, true)


func take_damage(amount: int, from: Vector3) -> void:
	if dead or _invulnerable > 0.0 or frozen:
		return
	hp -= amount
	_invulnerable = 0.9
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 10.0
	path.clear()
	Effects.float_text(level, global_position + Vector3(0, 3.2, 0), "-%d" % amount, Color(1, 0.3, 0.3))
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
	velocity = dir * SPEED + _knockback
	velocity.y = vy
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 45.0)
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	if dir != Vector3.ZERO:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-14.0 * delta))
	# Blink while invulnerable after a hit.
	_model.visible = dead or _invulnerable <= 0.0 or int(_invulnerable * 12.0) % 2 == 0
	if _busy > 0.0 or not controllable or dead:
		return
	if not is_on_floor():
		if _current_anim != "Jump_Full_Short":
			play("Jump_Idle")
		return
	play("Running_A" if dir != Vector3.ZERO else "Idle")
