class_name Player
extends CharacterBody3D
## The hooded rogue. Moves with WASD / arrow keys, or walks to a clicked spot.

const SPEED := 7.0
const HIDDEN_PARTS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

var level: Level
var controllable := true
var path: Array[Vector3] = []

var _model: Node3D
var _anim: AnimationPlayer
var _current_anim := ""
var _busy := 0.0


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
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A", "Walking_A"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("Idle")

	# A warm lantern glow around the hero, so the way ahead is never pitch black.
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.75, 0.5)
	lantern.light_energy = 1.1
	lantern.omni_range = 7.5
	lantern.position = Vector3(0, 3.2, 0.6)
	add_child(lantern)


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


func walk_to(target: Vector3) -> void:
	var from := level.world_to_cell(global_position)
	var to := level.world_to_cell(target)
	path.clear()
	for c in level.astar.get_id_path(from, to, true).slice(1):
		path.append(level.cell_to_world(c))


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
	_busy = maxf(0.0, _busy - delta)
	var dir := Vector3.ZERO
	if controllable and _busy <= 0.0:
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
	velocity = dir * SPEED
	move_and_slide()
	position.y = 0.0
	if dir != Vector3.ZERO:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-14.0 * delta))
	if _busy > 0.0 or not controllable:
		return
	play("Running_A" if dir != Vector3.ZERO else "Idle")
