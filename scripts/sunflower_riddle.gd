class_name SunflowerRiddle
extends Node3D
## The sunflower riddle of the farming valley: ten tiles of sunflowers (a block of 5 x 5 plants each, see
## CropFields.RIDDLE) form a code, with the scarecrow standing in the middle of the field.
##
## Standing by the scarecrow and saying the right words in the chat line (see ChatLine) sets off fireworks over the
## field and a message. Any number of times.
##
## Seasons: the heads stand up and show the code in summer and autumn; spring is the young plants and winter the cut
## stalks, with no heads to read. The words work in every season.
##
## The answer is kept out of the game's texts, the compendium, the patch notes, the tests and this repository: the
## code is stored scrambled and the answer only as a salted hash (see RiddleVault).

## The tiles of the riddle field on the valley map "Apfeltal": columns and rows of blocks.
const FIELD := Rect2i(59, 88, 5, 2)
## How near (metres) to the scarecrow the words must be said.
const NEAR := 7.0
## The flowers this close to the post are left out (metres).
const CLEAR_RADIUS := 0.7
## The congratulation.
const CONGRATS := "Congratz for solving Devilbane's first riddle!"
## How long the fireworks last, and how long until they can be set off again (seconds).
const SHOW_TIME := 9.0
const COLOURS := [Color(1.0, 0.35, 0.3), Color(1.0, 0.85, 0.3), Color(0.4, 0.8, 1.0), Color(0.6, 1.0, 0.5), Color(1.0, 0.5, 0.95), Color(1.0, 0.65, 0.25)]

var level: Level
var _busy := 0.0
var _rng := RandomNumberGenerator.new()


## The entry of the answer and the scrambled code (see RiddleVault): no answer is stored anywhere.
const ENTRY := {"salt": "a82e8a09d1db086fdfc668c5", "rounds": 60000, "hash": "514bb3989f86c07497f86f66a004a1360da2a1e14a4ac41a8ffa88511a1110a9"}
const CODE := "QRetkiuylOTDcA=="
## Lets a test stand in for the answer with an entry of its own; empty is the real one.
static var test_entry := {}


## The code: for each block in reading order, the number (1 to 25) of its light flower, 0 for a block without one.
static func marks() -> Array[int]:
	var out: Array[int] = []
	for v in RiddleVault.unscramble(CODE, ENTRY):
		out.append(int(v))
	return out


## The blocks the field has: columns times rows (the same as the words are long).
static func block_count() -> int:
	return FIELD.size.x * FIELD.size.y


## The middle of the field, where the scarecrow stands: on the line between the two rows of blocks.
static func centre() -> Vector3:
	return Vector3((FIELD.position.x + (FIELD.size.x - 1) * 0.5) * Level.TILE, 0.0, (FIELD.position.y + (FIELD.size.y - 1) * 0.5) * Level.TILE)


## Whether a line the hero said is the answer: case does not matter, nor spaces or marks between the words.
static func is_answer(text: String) -> bool:
	return RiddleVault.check(text, test_entry if not test_entry.is_empty() else ENTRY)


## The cells of the field's tiles, for the map.
static func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in FIELD.size.y:
		for x in FIELD.size.x:
			out.append(FIELD.position + Vector2i(x, y))
	return out


func setup(lvl: Level) -> void:
	level = lvl
	name = "SunflowerRiddle"
	_rng.seed = 17
	position = centre()


func _process(delta: float) -> void:
	_busy = maxf(0.0, _busy - delta)


## The hero said `text` at `pos` (see Events.hero_spoke).
func on_hero_spoke(text: String, pos: Vector3) -> void:
	if level == null or _busy > 0.0 or Vector2(pos.x - position.x, pos.z - position.z).length() > NEAR:
		return
	if not is_answer(text):
		return
	_busy = SHOW_TIME
	Events.bus().riddle_done.emit(RiddleCount.SUNFLOWER)
	Events.tell(CONGRATS, Color(1.0, 0.9, 0.5))
	Effects.float_text(level, position + Vector3(0, 4.2, 0), CONGRATS, Color(1.0, 0.92, 0.55))
	fireworks()


## Rockets rise over the field one after the other and burst.
func fireworks() -> void:
	var tw := create_tween()
	for i in 9:
		tw.tween_interval(0.35 + _rng.randf() * 0.5)
		var at := Vector3(_rng.randf_range(-9.0, 9.0), _rng.randf_range(6.5, 11.0), _rng.randf_range(-4.0, 4.0))
		var colour: Color = COLOURS[i % COLOURS.size()]
		tw.tween_callback(_rocket.bind(at, colour))


func _rocket(at: Vector3, colour: Color) -> void:
	var trail := Effects.make_sparkles(colour.lightened(0.3), true)
	trail.amount = 14
	trail.lifetime = 0.8
	trail.initial_velocity_min = 0.3
	trail.initial_velocity_max = 1.0
	trail.gravity = Vector3(0, -2.0, 0)
	add_child(trail)
	trail.position = Vector3(at.x, 0.3, at.z)
	var up := create_tween()
	up.tween_property(trail, "position:y", at.y, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	up.tween_callback(_burst.bind(at, colour))


func _burst(at: Vector3, colour: Color) -> void:
	var p := Effects.make_sparkles(colour, true)
	p.amount = 90
	p.lifetime = 1.9
	p.spread = 180.0
	p.emission_sphere_radius = 0.15
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.damping_min = 2.5
	p.damping_max = 3.5
	p.gravity = Vector3(0, -3.5, 0)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.2
	add_child(p)
	p.position = at
	p.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = colour
	flash.light_energy = 3.0
	flash.omni_range = 16.0
	add_child(flash)
	flash.position = at
	var fade := create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.9)
	fade.tween_callback(flash.queue_free)
