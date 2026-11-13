class_name RemoteHero
extends Node3D
## Another player's hero, drawn where the server last saw it.
##
## It is only a picture: no collision, no rules. Places come ten times a
## second, so the figure glides towards the last one and turns to its facing,
## and plays the animation the other game is playing. It is moved per frame,
## not in physics ticks, so it stays out of physics interpolation (see
## SmoothMotion).

## How fast the figure catches up with a new place (1/s).
const FOLLOW := 12.0
## Farther than this, it jumps instead of gliding (a door, a fall).
const SNAP := 6.0
const NAME_TAG_HEIGHT := 2.55

var hero_name := "":
	set(value):
		hero_name = value
		if _tag:
			_tag.text = value
var _goal := Vector3.ZERO
var _facing := 0.0
var _model: Node3D
var _anim: AnimationPlayer
var _tag: Label3D
var _has_goal := false


func _ready() -> void:
	_model = preload("res://assets/characters/Rogue.glb").instantiate()
	add_child(_model)
	for part in Player.HIDDEN_PARTS:
		var node := _model.find_child(part, true, false)
		if node:
			node.visible = false
	_anim = _model.find_child("AnimationPlayer", true, false)
	_tag = Label3D.new()
	_tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tag.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	_tag.font_size = 30
	_tag.pixel_size = 0.011
	_tag.outline_size = 10
	_tag.outline_modulate = Color(0.05, 0.03, 0.06, 0.85)
	# Friends' names in a light blue, set apart from the warm white of the townsfolk.
	_tag.modulate = Color(0.7, 0.88, 1.0)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.position.y = NAME_TAG_HEIGHT
	_tag.text = hero_name
	add_child(_tag)
	_play("Idle")


## Where the other game says its hero is now.
func target(pos: Vector3, facing: float, anim: String) -> void:
	if not _has_goal or pos.distance_to(global_position) > SNAP:
		global_position = pos
	_goal = pos
	_facing = facing
	_has_goal = true
	_play(anim)


func _process(delta: float) -> void:
	if not _has_goal:
		return
	var t := 1.0 - exp(-FOLLOW * delta)
	global_position = global_position.lerp(_goal, t)
	if _model:
		_model.rotation.y = lerp_angle(_model.rotation.y, _facing, t)


func _play(anim: String) -> void:
	if _anim == null or anim == "" or not _anim.has_animation(anim):
		return
	if _anim.current_animation != anim:
		var a := _anim.get_animation(anim)
		if anim in ["Idle", "Running_A", "Walking_A", "Jump_Idle"] or anim.contains("Jog") or anim.contains("Sneak"):
			a.loop_mode = Animation.LOOP_LINEAR
		_anim.play(anim, 0.15)
