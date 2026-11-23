class_name VillagerPost
extends RefCounted
## When a villager's window may open. A shopkeeper, the smith or the herald only deal
## at their post (their home cell, see Villager.home) and not while the village is in
## danger: during an alarm, or when they are running, fighting or away from their post,
## bumping into them gets a short word instead of a window. Whoever keeps a hall one walks
## into (Mira, Gero, Ragna, Gorm, see VillageHalls.KEEPERS) deals only at their place in it,
## and sends the hero there (HALL_LINES). Pure rules in `refusal`; `for_station` reads them off
## the live game.

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
	if v.role == TavernBrewer.GUEST and VillagePosts.inside(v):
		# Fritz at his table in the tavern is as findable as anyone behind a counter.
		return refusal(alarm_on(level), v.endangered(), "", 0.0)
	var hall := VillageHalls.kept_by(v.role)
	if hall != "" and not VillagePosts.post_of(v).is_empty():
		# Whoever keeps a hall one walks into deals only at their place in it (see VillagePosts),
		# however far that is from their tile; anywhere else they send the hero there.
		var why := refusal(alarm_on(level), v.endangered(), "", 0.0)
		if why != "" or VillagePosts.at_post(v):
			return why
		return hall_line(hall, v.night)
	return refusal(alarm_on(level), v.endangered(), v._info.get("plan", ""), d)


## Where a hall's keeper sends the hero who runs into them outside it: in there by day, or there
## again in the morning once it has closed for the night (see VillageHalls.KEEPERS).
const HALL_LINES := {
	"shop": ["Komm zu mir in den Laden, dort handeln wir.", "Mein Laden hat zu. Komm morgen früh wieder."],
	"office": ["Komm zu mir ins Amt, an meinen Schreibtisch.", "Das Amt hat zu. Komm morgen früh wieder."],
	"guild": ["Komm zu mir in die Gildenhalle.", "Die Gildenhalle hat zu. Komm morgen früh wieder."],
	"mill": ["Komm zu mir in die Mühle, an meinen Tresen.", "Die Mühle hat zu. Komm morgen früh wieder."],
	"tavern": ["Komm rein ins Wirtshaus, ich zapfe dir was.", "Das Wirtshaus hat zu. Komm morgen früh wieder."],
}


## Whether `line` is one of the keepers' lines that send the hero to their hall.
static func is_hall_line(line: String) -> bool:
	for lines: Array in HALL_LINES.values():
		if lines.has(line):
			return true
	return false


## The line of `hall`'s keeper (German): by day or at night.
static func hall_line(hall: String, night: bool) -> String:
	var lines: Array = HALL_LINES.get(hall, [AWAY_LINE, AWAY_LINE])
	return lines[1 if night else 0]
