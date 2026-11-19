class_name GraveGate
extends Node3D
## A gate of the graveyard fence (the arch "arch_gate" with its two iron leaves).
## When the hero comes near, the leaves swing open with the grating creak of rusty
## hinges; when the hero has gone a little way off they swing shut again with a dull
## clang. The leaves have no collision of their own (the passage between the two posts
## is always free), so the gate only ever dresses the way in and out.

## The hero opens the gate within this distance (metres) and it closes beyond CLOSE_AT,
## so a hero standing on the edge does not set it flapping.
const OPEN_AT := 4.5
const CLOSE_AT := 6.5
## How far each leaf swings (radians) and how long that takes (seconds).
const OPEN_ANGLE := 1.75
const OPEN_TIME := 1.6
const CLOSE_TIME := 1.3
## The sounds: the opening creaks (one of OPEN_SOUNDS) and the closing one.
const OPEN_SOUNDS := ["gate_open_0", "gate_open_1"]
const CLOSE_SOUND := "gate_close_0"
const VOLUME_DB := -4.0

## The level the gate stands in, whose `player` (set after the level is built) is the hero.
var level: Level
## The two leaves and the way each turns: positive swings the leaf with the hinge at +x
## (the left one) out towards +z, negative the other.
var _leaves: Array[Node3D] = []
var _signs: Array[float] = []
var _open := false
var _tween: Tween


## Takes over the leaves of a placed arch (a node named for its left and right leaf) and
## tracks the hero of `lvl`. Returns the gate, or null when the model has no such leaves.
static func attach(arch: Node3D, lvl: Level) -> GraveGate:
	var left := arch.find_child("arch_gate_left", true, false) as Node3D
	var right := arch.find_child("arch_gate_right", true, false) as Node3D
	if left == null or right == null:
		return null
	var gate := GraveGate.new()
	gate.name = "GraveGate"
	gate.level = lvl
	gate._leaves = [left, right]
	gate._signs = [1.0, -1.0]
	arch.add_child(gate)
	return gate


func is_open() -> bool:
	return _open


func _process(_delta: float) -> void:
	var hero: Node3D = level.player if level else null
	if hero == null or not is_instance_valid(hero):
		return
	var d := Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
	if not _open and d < OPEN_AT:
		swing(true)
	elif _open and d > CLOSE_AT:
		swing(false)


## Opens or shuts the gate, with its sound.
func swing(open: bool) -> void:
	if open == _open:
		return
	_open = open
	if _tween:
		_tween.kill()
	var sound: String = OPEN_SOUNDS[randi() % OPEN_SOUNDS.size()] if open else CLOSE_SOUND
	Sfx.play(self, sound, VOLUME_DB, global_position)
	if not is_inside_tree():
		return
	_tween = create_tween().set_parallel(true)
	for i in _leaves.size():
		var to := OPEN_ANGLE * _signs[i] if open else 0.0
		var move := _tween.tween_property(_leaves[i], "rotation:y", to, OPEN_TIME if open else CLOSE_TIME)
		move.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A level taken away mid-swing leaves the gate shut.
func _exit_tree() -> void:
	if _tween:
		_tween.kill()
		_tween = null
