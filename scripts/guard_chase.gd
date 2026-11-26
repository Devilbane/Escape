class_name GuardChase
extends RefCounted
## Guard Ulrich on the heels of Spooknortz (see SpookRaid). When the town guard spots the thief on his night
## round he shouts that he should stop (a speech bubble and a shout, tools/make_guard_shout.py) and runs after
## him, but he never catches up: he holds back at GAP metres, and gives up when the thief is out of sight for
## LOST seconds or the chase has lasted MAX_TIME. Then he grumbles and goes back to his post.

## How fast he runs (the villagers' running pace) and how close he comes: never nearer than GAP metres.
const SPEED := 3.6
const GAP := 6.0
## How often he points his run at the thief again (seconds) and how often he shouts.
const RETARGET := 0.5
const SHOUT_EVERY := 4.5
## How long the chase lasts at most, and how long the thief may be out of sight before the guard gives up.
const MAX_TIME := 16.0
const LOST := 3.0
## Seconds after a chase before the guard takes up a new one.
const COOLDOWN := 20.0
## The shout's volume (dB) and how many shout sounds there are.
const SHOUT_DB := -4.0
const SHOUT_SOUNDS := 3
## Only a guard who is about his round chases: these are the tasks that may be broken off.
const FREE_TASKS := ["walk", "idle", "work", "watch"]

const SHOUTS := [
	"Halt! Stehenbleiben, du Dieb!",
	"Bleib stehen, du Schleicher!",
	"Haltet ihn! Stehen bleiben!",
	"Du da! Halt, im Namen des Dorfes!",
]
const GRUMBLES := [
	"Pah! Wieder entwischt. Ich gehe zurück auf meinen Posten.",
	"Verflixt, der ist zu flink für mich. Zurück auf Posten.",
	"Der Kerl ist wie ein Schatten... Genug für heute.",
]
const COLOR := Color(1.0, 0.75, 0.3)

var guard: Villager
var level: Outdoor
var time := 0.0
var shouts := 0
var catches := 0
var _lost := 0.0
var _retarget := 0.0
var _shout_in := 0.0


## Starts a chase after the thief for `guard`, or returns null when the guard is busy (an alarm, a fight, asleep).
static func start(g: Villager, lvl: Outdoor) -> GuardChase:
	if g == null or not is_instance_valid(g) or g.eaten or g.threat != null or g.at_home or not g.visible:
		return null
	if lvl.village_alarm.raised or not g.chase_free():
		return null
	var c := GuardChase.new()
	c.guard = g
	c.level = lvl
	return c


## One tick of the chase after the thief at `quarry`. Returns false when it is over (the guard has been
## sent back to his post, or has no business chasing any more).
func step(delta: float, quarry: Vector3) -> bool:
	if guard == null or not is_instance_valid(guard) or guard.eaten or guard.threat != null or level.village_alarm.raised:
		return false
	time += delta
	var here := guard.global_position
	if level.has_line_of_sight(here, quarry):
		_lost = 0.0
	else:
		_lost += delta
	if _lost >= LOST or time >= MAX_TIME:
		give_up()
		return false
	_shout_in -= delta
	if _shout_in <= 0.0 and _lost == 0.0:
		_shout_in = SHOUT_EVERY
		_shout()
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = RETARGET
		var flat := Vector3(quarry.x - here.x, 0, quarry.z - here.z)
		if flat.length() > GAP:
			guard.chase_toward(quarry, SPEED)
		else:
			guard.chase_halt(quarry)
	return true


func _shout() -> void:
	shouts += 1
	var line: String = SHOUTS[(shouts - 1 + randi()) % SHOUTS.size()]
	guard.say(Lang.t(line))
	Sfx.play(guard, "guard_shout_%d" % (randi() % SHOUT_SOUNDS), SHOUT_DB, guard.global_position)
	_retarget = 0.0


## He has lost the thief: a grumble, and back to the post.
func give_up() -> void:
	if guard == null or not is_instance_valid(guard):
		return
	guard.say(Lang.t(GRUMBLES[randi() % GRUMBLES.size()]))
	guard.back_to_post()
