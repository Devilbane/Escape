class_name DamageNumber
extends Label3D
## A number (or a short word) that pops up above a creature's head, rises and
## slowly fades. Numbers over the same head never cover each other: a new one
## always starts at the head, and the older ones are pushed up out of its way,
## so a hero striking one foe again and again can read every blow.

## Seconds a number lives, from pop to gone.
const LIFE := 1.7
## How far a number drifts up on its own over its life.
const RISE := 1.0
## When the fade starts, and how long it takes.
const FADE_AT := 0.9
const FADE_TIME := LIFE - FADE_AT
## The smallest gap between two numbers over the same head, in world units
## along the screen's up.
## The glyphs are about 0.5 high, so this leaves a clear gap between lines.
const STEP := 0.8
## Seen from above, the head point sits low on the picture: a new number
## starts this far (along the screen's up) above it, off the hair or helmet.
const HEAD_GAP := 0.45
## More numbers than this over one head and the oldest one hurries its fade.
const MOST := 4
## The pop: a new number starts this much bigger and settles in POP_TIME.
const POP := 1.4
const POP_TIME := 0.14

## The numbers alive over each head, oldest first, keyed by the target's id.
static var _stacks := {}

var _key := 0
var _target: Node3D
var _offset := Vector3.ZERO
var _anchor := Vector3.ZERO
var _age := 0.0
## The extra height this number was pushed up by newer ones.
var _lift := 0.0
## The height above the head it is drawn at now (it slides toward its goal).
var _shown := 0.0
var _alpha := 1.0
var _outline_alpha := 1.0


## Shows `text` above `target`'s head (`offset` from its origin). The label
## lives under `parent`, so it stays on when the target dies.
static func show_over(parent: Node, target: Node3D, offset: Vector3, text: String, color: Color) -> DamageNumber:
	var label := DamageNumber.new()
	label.text = text
	label.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	label.font_size = 64
	label.pixel_size = 0.012
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.02, 0.06)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.outline_render_priority = 19
	label._alpha = color.a
	label._outline_alpha = label.outline_modulate.a
	label._target = target
	label._offset = offset
	label._anchor = target.global_position + offset
	label._key = target.get_instance_id()
	label.scale = Vector3.ONE * POP
	parent.add_child(label)
	label.global_position = label._anchor
	var stack: Array = _stacks.get(label._key, [])
	stack.append(label)
	_stacks[label._key] = stack
	# Too many at once: the oldest one skips ahead to its fade.
	if stack.size() > MOST:
		for old in stack.slice(0, stack.size() - MOST):
			old._age = maxf(old._age, LIFE - 0.25)
	return label


## The numbers alive over `target`, oldest first (for tests).
static func over(target: Node) -> Array:
	var stack: Array = _stacks.get(target.get_instance_id(), [])
	return stack.filter(func(n): return is_instance_valid(n))


## The height above the head this number is drawn at.
func height() -> float:
	return _shown


func _drift() -> float:
	var t := clampf(_age / LIFE, 0.0, 1.0)
	return RISE * (1.0 - pow(1.0 - t, 2.0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		_leave()
		return
	# Follow the head while the target lives (it may be knocked back).
	if is_instance_valid(_target) and _target.is_inside_tree():
		_anchor = _target.global_position + _offset
	var pop := clampf(_age / POP_TIME, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(POP, 1.0, pop * (2.0 - pop))
	var fade := clampf((_age - FADE_AT) / FADE_TIME, 0.0, 1.0)
	modulate.a = _alpha * (1.0 - fade)
	# The outline ignores `modulate`, so it has to fade on its own.
	outline_modulate.a = _outline_alpha * (1.0 - fade)
	# The newest number over a head places the whole stack, once a frame,
	# after the others have aged (it was added last, so it runs last).
	var stack: Array = _stacks.get(_key, [])
	if not stack.is_empty() and stack.back() == self:
		_place(stack)


## Lays out one head's numbers from the newest up: each one rises on its own,
## but always stays a full step above the next newer one.
static func _place(stack: Array) -> void:
	# The newest number starts a little clear of the head, never on it.
	var below := HEAD_GAP - STEP
	# The camera looks down at the floor at a slant, so "up" means up on the
	# screen: the numbers climb along the camera's up, not the world's, and a
	# step keeps its full height in the picture.
	var newest: DamageNumber = stack.back()
	var camera := newest.get_viewport().get_camera_3d()
	var up := camera.global_basis.y if camera else Vector3.UP
	for j in range(stack.size() - 1, -1, -1):
		var n: DamageNumber = stack[j]
		if not is_instance_valid(n):
			continue
		var goal := n._drift() + n._lift
		if goal < below + STEP:
			n._lift += below + STEP - goal
			goal = below + STEP
		# A push slides in quickly but never lets two numbers touch.
		n._shown = goal if n._age <= POP_TIME else maxf(lerpf(n._shown, goal, 0.5), below + STEP)
		n._shown = maxf(n._shown, 0.0)
		n.global_position = newest._anchor + up * n._shown
		below = n._shown


func _leave() -> void:
	_forget()
	queue_free()


func _forget() -> void:
	var stack: Array = _stacks.get(_key, [])
	stack.erase(self)
	if stack.is_empty():
		_stacks.erase(_key)


func _exit_tree() -> void:
	_forget()
