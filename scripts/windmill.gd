class_name Windmill
extends Node
## The windmill's sails turn slowly round, always, by day and by night. How
## fast goes by the weather (see Weather): a gentle turn under clear skies,
## brisker in the rain, hardly at all in the still air of fog, and fast in
## a thunderstorm. When the weather changes, the sails pick up speed or slow
## down gently instead of jumping to the new pace.
##
## Near the mill the hero hears it: each time a sail sweeps down past the
## tower its canvas whooshes in the wind, and now and then the old wooden
## axle groans. Both play through the Effects bus, quieter further away,
## and louder when the sails turn faster. The sounds are made by
## tools/make_windmill_sounds.py.

## How fast the sails turn in each weather (radians per second). Under
## clear skies one turn takes about 18 seconds.
const SPEEDS := {
	Weather.CLEAR: 0.35,
	Weather.RAIN: 0.6,
	Weather.FOG: 0.12,
	Weather.STORM: 1.5,
}
## How long the sails take to come most of the way to a new speed (seconds).
const EASE := 6.0
## The sails' cross has four arms: a whoosh for each.
const SAILS := 4
## The sounds: how loud right next to the mill, how much quieter per metre
## away, and from how far they are not heard at all (metres).
const WHOOSH_DB := -13.0
const GROAN_DB := -15.0
const DB_PER_METRE := 0.45
const HEAR_RANGE := 40.0
## Seconds between two groans of the wood, picked at random between these.
const GROAN_MIN := 7.0
const GROAN_MAX := 16.0
## Each whoosh and groan plays at a slightly different pitch.
const PITCH_SPREAD := 0.08

## The turning part of the model: the cross of sails.
var sails: Node3D
## The speed the sails turn at now (radians per second).
var speed: float = SPEEDS[Weather.CLEAR]
## How far round the sails have turned in all (radians).
var turned := 0.0
var _outdoor: Node
var _groan_timer := GROAN_MIN


## Finds the sails in a windmill model put up by Outdoor (the node whose
## name ends in "fan") and makes them turn. Returns null for a model
## without sails.
static func attach(outdoor: Node, model: Node3D) -> Windmill:
	var found := model.find_children("*fan*", "Node3D", true, false)
	if found.is_empty():
		return null
	var mill := Windmill.new()
	mill.name = "Windmill"
	mill.sails = found[0]
	mill._outdoor = outdoor
	mill._groan_timer = randf_range(GROAN_MIN * 0.5, GROAN_MAX)
	model.add_child(mill)
	return mill


## How fast the sails turn in this weather (radians per second).
static func speed_for(weather: String) -> float:
	return SPEEDS.get(weather, SPEEDS[Weather.CLEAR])


func _process(delta: float) -> void:
	var target := speed_for(_outdoor.weather if _outdoor else Weather.CLEAR)
	speed = lerpf(speed, target, 1.0 - exp(-delta * 3.0 / EASE))
	var before := floori(turned * SAILS / TAU)
	turned += speed * delta
	# The cross is flat in its own x-y plane and faces along its z axis, so
	# it turns about z.
	sails.rotation.z = fmod(turned, TAU)
	var dist := _hero_distance()
	if dist > HEAR_RANGE:
		return
	if floori(turned * SAILS / TAU) != before:
		_sound("windmill_whoosh_%d" % (randi() % 3), WHOOSH_DB, dist)
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = randf_range(GROAN_MIN, GROAN_MAX)
		_sound("windmill_groan_%d" % (randi() % 3), GROAN_DB, dist)


## How loud a sound of the mill is from this far away: quieter with the
## distance, louder the faster the sails turn (a storm whooshes loudest).
func loudness(base_db: float, dist: float) -> float:
	var pace := clampf(speed / SPEEDS[Weather.CLEAR], 0.3, 4.5)
	return base_db - dist * DB_PER_METRE + linear_to_db(pace) * 0.5


func _hero_distance() -> float:
	var hero: Node3D = _outdoor.player if _outdoor else null
	if hero == null or not is_inside_tree():
		return INF
	return hero.global_position.distance_to(sails.global_position)


func _sound(take: String, base_db: float, dist: float) -> void:
	Sfx.play_3d(_outdoor, take, loudness(base_db, dist), sails.global_position,
			1.0 + randf_range(-PITCH_SPREAD, PITCH_SPREAD))
