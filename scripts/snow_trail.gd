class_name SnowTrail
extends RefCounted
## The tracks one animal leaves in the snow as it walks (see SnowPrints): a print each `stride`
## metres, left and right a little apart, pointing the way it goes. Only animals near the hero
## leave any, so the far ones do not use up the prints the hero's own steps need.

## Animals farther from the hero than this leave no tracks (metres).
const NEAR := 20.0
## Paws, hooves and bird feet are pressed this much bigger than life, so each kind can be told apart in the game view.
const SHOW := 1.7

## Which print each animal presses: [shape, size, stride in metres, sideways spread in metres].
const FEET := {
	"reh": ["hoof", 1.6, 0.6, 0.07],
	"hirsch": ["hoof", 1.8, 0.65, 0.08],
	"fuchs": ["paw", 1.0, 0.45, 0.05],
	"kaninchen": ["paw", 0.55, 0.8, 0.05],
	"kit": ["paw", 0.3, 0.4, 0.03],
	"goat": ["hoof", 0.8, 0.5, 0.05],
	"billy": ["hoof", 0.9, 0.55, 0.05],
	"sheep": ["hoof", 0.8, 0.45, 0.05],
	# Cattle press one print per hoof as it lands (see HOOVES), life-sized: about 12 x 16 cm.
	"cow": ["hoof", 0.6, 0.8, 0.09],
	"bull": ["hoof", 0.66, 0.85, 0.1],
	"dog": ["paw", 0.4, 0.5, 0.06],
	"squirrel": ["paw", 0.5, 0.3, 0.03],
	"hedgehog": ["paw", 0.5, 0.22, 0.03],
	"goose": ["bird", 0.68, 0.4, 0.06],
	"cat": ["paw", 0.45, 0.3, 0.03],
	# Monsters: the ones on two legs press boots, the wolf a paw (see for_monster).
	"walker": ["boot", 1.0, 0.7, 0.08],
	"wolf": ["paw", 1.5, 0.6, 0.06],
}

## Monsters that leave no tracks: ghosts float, slimes glide.
const TRACKLESS := ["Slime"]

## Where and when each hoof of the cow and bull lands, measured from the bones of their Walk and Gallop animations
## (tests/hoof_prints.gd measures them again): [share of the cycle at touchdown, sideways, forward], in the model's
## own space (metres at model scale 1, the model looks towards +Z).
const HOOVES := {
	"Walk": [[0.217, 0.570, -0.94], [0.392, 0.611, 2.63], [0.725, -0.570, -0.94], [0.95, -0.611, 2.64]],
	"Gallop": [[0.325, -0.570, -0.53], [0.5, 0.570, -0.49], [0.75, -0.611, 2.91], [0.933, 0.611, 2.71]],
}

var _feet: Array
var _beat := -1.0
var _beat_anim := ""
var _from := Vector3.INF
var _left := false


## How much bigger or smaller than the usual print this walker presses (a colossus's boot).
var scale := 1.0


func _init(kind: String, size := 1.0) -> void:
	_feet = FEET[kind]
	scale = size


## The tracks of a monster, or null when it leaves none (a ghost floats, a slime glides).
static func for_monster(kind: String, model: String, ghost: bool, size: float) -> SnowTrail:
	if ghost or TRACKLESS.has(model):
		return null
	return SnowTrail.new("wolf" if kind == "wolf" else "walker", size)


## Called every physics tick with where the animal is; presses a print once it has gone a stride.
func follow(level: Node, here: Vector3) -> void:
	if not level.has_method("snow_print") or level.get("snow") == null or level.snow.amount < Weather.PRINT_FROM:
		_from = Vector3.INF
		return
	var hero: Node3D = level.player
	if hero == null or here.distance_to(hero.global_position) > NEAR:
		_from = Vector3.INF
		return
	if _from == Vector3.INF:
		_from = here
		return
	var step := here - _from
	step.y = 0.0
	if step.length() < float(_feet[2]) * scale:
		return
	var heading := atan2(step.x, step.z)
	_left = not _left
	var apart := Vector3(cos(heading), 0, -sin(heading)) * float(_feet[3]) * scale * (1.0 if _left else -1.0)
	# Animal feet are tiny; drawn true to size they vanish at the game camera, so they are pressed bigger.
	var show := 1.0 if _feet[0] == "boot" else SHOW
	level.snow_print(here + apart, heading, float(_feet[1]) * scale * show, _feet[0])
	_from = here


## The tracks of a model walking or galloping on four feet: a print each time one of its hooves lands, where it lands.
## `rig` is the node the model hangs from (its scale and turn carry the hoof spots into the world), `player` the
## animation playing on it. Needs the animation to be Walk or Gallop; any other pose, or a snowless day, presses nothing.
func hoofbeats(level: Node, rig: Node3D, player: AnimationPlayer) -> void:
	var anim := player.current_animation
	var length := player.current_animation_length
	if not HOOVES.has(anim) or length <= 0.0 or not _snowy_near(level, rig.global_position):
		_beat = -1.0
		return
	var now := player.current_animation_position / length
	var last := _beat
	_beat = now
	if last < 0.0 or anim != _beat_anim:
		_beat_anim = anim
		return
	var forward := rig.global_transform.basis.z
	var heading := atan2(forward.x, forward.z)
	for hoof: Array in HOOVES[anim]:
		var at := float(hoof[0])
		var landed := (last < at and at <= now) if now >= last else (at > last or at <= now)
		if landed:
			var spot := rig.to_global(Vector3(float(hoof[1]), 0.0, float(hoof[2])))
			spot.y = rig.global_position.y
			level.snow_print(spot, heading, float(_feet[1]) * scale * SHOW, _feet[0])


func _snowy_near(level: Node, here: Vector3) -> bool:
	if not level.has_method("snow_print") or level.get("snow") == null or level.snow.amount < Weather.PRINT_FROM:
		return false
	var hero: Node3D = level.player
	return hero != null and here.distance_to(hero.global_position) <= NEAR
