class_name VillagerPost
extends RefCounted
## When a villager's window may open. A shopkeeper, the smith or the herald only deal
## at their post (their home cell, see Villager.home) and not while the village is in
## danger: during an alarm, or when they are running, fighting or away from their post,
## bumping into them gets a short word instead of a window. Pure rules in `refusal`;
## `for_station` reads them off the live game.

## How far from the post (metres, a tile is 4) still counts as "at their post".
const POST_RADIUS := 6.0
## The plans that keep a fixed post (see Villager.INFO plan); others roam by design.
const POST_PLANS := ["shop", "stay", "work", "sit"]

const ALARM_LINE := "Jetzt nicht, zu den Waffen!"
const AWAY_LINE := "Such mich an meinem Platz."


## "" when the window may open, else the German line to show (alarm: the village
## is up in arms; endangered: this villager is running or fighting; plan and
## distance: how far they stand from their post, in metres).
static func refusal(alarm: bool, endangered: bool, plan: String, distance: float) -> String:
	if alarm or endangered:
		return ALARM_LINE
	if plan in POST_PLANS and distance > POST_RADIUS:
		return AWAY_LINE
	return ""


## Whether the village is in danger right now (outdoors only).
static func alarm_on(level: Node) -> bool:
	if not level is Outdoor:
		return false
	return level.village_alarm.raised or level.village_wall.shut_wanted


## The line to show instead of the window of a person station, "" to open it.
static func for_station(level: Node, s: Dictionary) -> String:
	if not level is Outdoor or s.kind == "wanderhaendler" or not s.get("npc") is Villager:
		return ""
	var v: Villager = s.npc
	var post: Vector3 = level.cell_to_world(v.home)
	var d := Vector2(v.global_position.x - post.x, v.global_position.z - post.z).length()
	return refusal(alarm_on(level), v.endangered(), v._info.get("plan", ""), d)
