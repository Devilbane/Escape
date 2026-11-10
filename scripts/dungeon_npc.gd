class_name DungeonNpc
extends CharacterBody3D
## A person made in the map workshop (see Creations): stands on their tile in
## a dungeon, does what their pose says, and says their lines one after
## another when the hero runs into them (a "figur" station, see
## Level._build_creation and Game._use_station). Their name shows over the
## head, and the line in a bubble above it, like the villagers'.

var spec := {}
var display_name := ""
var _model: Node3D
var _anim: AnimationPlayer
var _bubble: SpeechBubble
var _name_tag: Label3D
var _bubble_time := 0.0
var _bubble_hold := 0.0
var _line := 0
var _turn_to := Vector3.INF


func setup(creation: Dictionary) -> void:
	spec = creation
	display_name = Creations.label_of(spec)


func _ready() -> void:
	add_to_group(Footprint.GROUP)
	var look := Creations.npc_look(spec)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.2
	shape.shape = capsule
	shape.position.y = 1.1
	add_child(shape)
	_model = load("res://assets/characters/%s.glb" % look.model).instantiate()
	_model.scale = Vector3.ONE * BodyLook.scale_of(look.sex)
	add_child(_model)
	Villager.dress_model(_model, look)
	BodyLook.apply(_model, look.sex)
	if look.model == "Rogue":
		HairLook.apply(_model, HairLook.checked(HairLook.DEFAULT))
	GearLook.dress_body(_model, "outfit")
	_anim = _model.find_child("AnimationPlayer", true, false)
	var pose: String = spec.get("pose", "Idle")
	if _anim and _anim.has_animation(pose):
		_anim.get_animation(pose).loop_mode = Animation.LOOP_LINEAR
		_anim.play(pose)
	_name_tag = _label(30, 2.75)
	_name_tag.text = display_name
	_name_tag.outline_modulate = Color(0.05, 0.03, 0.06, 0.85)
	_bubble = SpeechBubble.new()
	_bubble.position.y = 3.0 + 0.15
	add_child(_bubble)


func _label(font_size: int, height: float) -> Label3D:
	var l := Label3D.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	l.font_size = font_size
	l.pixel_size = 0.011
	l.outline_size = 12
	l.modulate = Color(1, 0.95, 0.85, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	l.position.y = height
	add_child(l)
	return l


## The hero ran into us: the next line, facing them. A line that has not
## shown long enough to be read stays (no flicker while the hero pushes).
func talk(hero: Node3D) -> void:
	if _bubble_hold > 0.0:
		return
	var lines: Array = spec.get("lines", [])
	if lines.is_empty():
		return
	var said := Lang.t(lines[_line % lines.size()])
	_bubble.show_line(display_name, said)
	Events.say(display_name, said, global_position)
	_line += 1
	_bubble_time = Villager.SAY_TIME
	_bubble_hold = Villager.MIN_SAY_TIME
	_turn_to = hero.global_position


func is_talking() -> bool:
	return _bubble_time > 0.0


func _process(delta: float) -> void:
	_bubble_time = maxf(0.0, _bubble_time - delta)
	_bubble_hold = maxf(0.0, _bubble_hold - delta)
	# The line shows in a speech bubble (and in the event log, see Events.say).
	if _bubble_time <= 0.0 and _bubble.is_shown():
		_bubble.hide_line()
	_name_tag.modulate.a = 1.0
	_name_tag.outline_modulate.a = 0.85
	if _turn_to != Vector3.INF:
		var d := _turn_to - global_position
		d.y = 0.0
		if d.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, delta * 6.0))
		if _bubble_time <= 0.0:
			_turn_to = Vector3.INF
