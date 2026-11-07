class_name VillageAlarm
extends RefCounted
## The village rises against a slime (see SlimeGrowth, Villager.alarm).
##
## Once a slime crawls within the village (Outdoor._in_village), the herald
## (or, without him, the guard) calls the village to arms: the men take up
## blades and go for the nearest slime in the village, even from across the
## square (CALL_REACH), each with a weapon that suits them (see VillageArms:
## Pip throws knives, the priestess heals instead of striking), while the
## other women and children run into the
## houses (Villager.shelters) and stay there until the herald gives the
## all-clear, CALM_AFTER seconds after the last slime has left or fallen.
## Each look (CHECK_EVERY) also rallies whoever was not yet roused.
##
## A slime too big for the village (FLEE_LEVEL, above its strongest, see
## Villager.LEVELS) sends everyone indoors, the men too, and they stay there
## until it is killed: only the hero can deal with that one.

const CHECK_EVERY := 1.0
const CALM_AFTER := 6.0
## How far a villager called to arms goes to meet a slime.
const CALL_REACH := 45.0
const CALL := "Zu den Waffen! Ein Schleim ist im Dorf! Frauen und Kinder, in die Häuser!"
const FLEE := "Rettet euch! Ein riesiger Schleim! Alle in die Häuser!"
## From this level on a slime is too big for the village.
const FLEE_LEVEL := 21
const ALL_CLEAR := "Entwarnung! Der Schleim ist fort, das Dorf ist wieder sicher."
const NEWS := "Der Herold ruft das Dorf zu den Waffen: Ein Schleim ist im Dorf!"
const COLOR := Color(1.0, 0.75, 0.3)
## The roles that call the alarm, first the herald, else the guard.
const CALLERS := ["K", "4"]

## Whether the village is up in arms now.
var raised := false
## The slime too big to fight that has everyone indoors until it is killed.
var monster: Enemy = null
var _check := 0.0
var _clear := 0.0


func tick(o: Outdoor, delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_EVERY
	var slimes := intruders(o)
	if monster != null and (not is_instance_valid(monster) or monster.dead):
		monster = null
	for s in slimes:
		if too_big(s) and monster == null:
			monster = s
			var herald := caller(o)
			if herald != null:
				herald.call_to_arms(Lang.t(FLEE))
			Events.tell(Lang.t(FLEE), COLOR)
	if monster != null and not monster in slimes:
		slimes.append(monster)
	if not slimes.is_empty():
		_clear = 0.0
		if not raised:
			raised = true
			if monster == null:
				var herald := caller(o)
				if herald != null:
					herald.call_to_arms(Lang.t(CALL))
				Events.tell(Lang.t(NEWS), COLOR)
		_rally(o, slimes)
	elif raised:
		_clear += CHECK_EVERY
		if _clear >= CALM_AFTER:
			raised = false
			var herald := caller(o)
			if herald != null:
				herald.say(Lang.t(ALL_CLEAR))


static func too_big(slime: Enemy) -> bool:
	return slime.rated_level >= FLEE_LEVEL


## The living slimes within the village.
static func intruders(o: Outdoor) -> Array:
	var out := []
	for e in o.enemies:
		if is_instance_valid(e) and not e.dead and e.is_inside_tree() and SlimeGrowth.grows(e.kind) \
				and o._in_village(o.world_to_cell(e.global_position)) \
				and o.village_wall.is_inside(o.world_to_cell(e.global_position)):
			out.append(e)
	return out


## Who calls the alarm: the herald, else the guard, if out and about.
static func caller(o: Outdoor) -> Villager:
	for role in CALLERS:
		for v in o.villagers:
			if v.role == role and not v.eaten and not v.at_home and v.visible:
				return v
	return null


## Everyone out in the street takes up arms against the nearest slime in
## the village, or runs indoors.
func _rally(o: Outdoor, slimes: Array) -> void:
	for v in o.villagers:
		if v.eaten or v.at_home or not v.visible:
			continue
		var best: Enemy = null
		var best_d := INF
		for s in slimes:
			var d: float = s.global_position.distance_to(v.global_position)
			if d < best_d:
				best = s
				best_d = d
		# A slime too big to fight sends everyone indoors.
		if monster != null:
			best = monster
		if best != null:
			v.alarm(best, true)
