class_name SnowTrail
extends RefCounted
## The tracks one animal leaves in the snow as it walks (see SnowPrints): a print each `stride`
## metres, left and right a little apart, pointing the way it goes. Only animals near the hero
## leave any, so the far ones do not use up the prints the hero's own steps need.

## Animals farther from the hero than this leave no tracks (metres).
const NEAR := 26.0

## Which print each animal presses: [shape, size, stride in metres, sideways spread in metres].
const FEET := {
	"reh": ["hoof", 1.0, 0.75, 0.06],
	"hirsch": ["hoof", 1.15, 0.8, 0.07],
	"fuchs": ["paw", 1.0, 0.45, 0.05],
	"goat": ["hoof", 0.8, 0.5, 0.05],
	"billy": ["hoof", 0.9, 0.55, 0.05],
	"sheep": ["hoof", 0.8, 0.45, 0.05],
	"cow": ["hoof", 1.6, 0.8, 0.09],
	"bull": ["hoof", 1.8, 0.85, 0.1],
	"dog": ["paw", 1.2, 0.5, 0.06],
	"goose": ["bird", 1.7, 0.4, 0.06],
}

var _feet: Array
var _from := Vector3.INF
var _left := false


func _init(kind: String) -> void:
	_feet = FEET[kind]


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
	if step.length() < float(_feet[2]):
		return
	var heading := atan2(step.x, step.z)
	_left = not _left
	var apart := Vector3(cos(heading), 0, -sin(heading)) * float(_feet[3]) * (1.0 if _left else -1.0)
	level.snow_print(here + apart, heading, float(_feet[1]), _feet[0])
	_from = here
