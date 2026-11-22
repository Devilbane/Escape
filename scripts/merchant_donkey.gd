class_name MerchantDonkey
extends Node3D
## Zarek's donkey, who pulls his living wagon from village to village (see
## MerchantWagon). While the wagon is parked she rests in front of its
## shafts, unharnessed: mostly nibbling at her hay, now and then lifting her
## head to look about or dozing with it hung low. She stays where she is and
## needs no looking after; she comes and goes with the wagon.
##
## Model: "Donkey" from "Ultimate Animated Animals" by Quaternius (CC0, see
## assets/animals/LICENSE.txt).

const MODEL := "res://assets/animals/Donkey.glb"
## Fits the model to a donkey a little smaller than a horse, about as tall at
## the withers as the hero's shoulder.
const SCALE := 0.4
## What she does, with how likely each is and how long it lasts (seconds):
## eating is what she does most.
const MOODS := [["Eating", 0.6, [8.0, 16.0]], ["Idle", 0.25, [4.0, 8.0]], ["Idle_Headlow", 0.15, [6.0, 12.0]]]
const BLEND := 0.6

var _anim: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _left := 0.0


func _ready() -> void:
	_rng.seed = hash("zarek esel")
	OffscreenAnim.watch(self, 1.5)
	var model: Node3D = load(MODEL).instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false)
	for mood: Array in MOODS:
		_anim.get_animation(mood[0]).loop_mode = Animation.LOOP_LINEAR
	_next()
	# Not all in step with the last time the wagon came.
	_anim.seek(_rng.randf() * _anim.current_animation_length, true)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_next()


## What she does now (one of MOODS' animations).
func mood() -> String:
	return _anim.current_animation if _anim else ""


func _next() -> void:
	var roll := _rng.randf()
	for m: Array in MOODS:
		roll -= float(m[1])
		if roll <= 0.0 or m == MOODS[-1]:
			if _anim.current_animation != m[0]:
				_anim.play(m[0], BLEND)
			_left = _rng.randf_range(m[2][0], m[2][1])
			return
