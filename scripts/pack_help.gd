class_name PackHelp
extends RefCounted
## Monsters stand up for each other. When the hero strikes a monster that had not noticed them,
##  - every unaware monster of its own kind of folk with a clear line of sight to it (within
##    SEE_RANGE) turns to defend it, showing the red "!", and
##  - a few kinds also call for help (wolves howl, orcs roar, robbers shout): that call carries
##    CALLERS[kind].reach metres and wakes its friends without a line of sight. A caller that
##    falls to the very blow that woke it cannot call: striking hard is the way to cut it short.
## Slimes neither call nor answer. A monster far below the hero's level (cowed) stays out of it, and so
## does the hero's friend (see Factions). Once per monster per CALL_GAP seconds.

## How far a monster sees a mate being struck.
const SEE_RANGE := 14.0
const CALL_GAP := 8.0
const COLOR := Color(1.0, 0.75, 0.35)
## Who calls for help: the reach of the call in metres, the word over its head and the line in the log.
const CALLERS := {
	"wolf": {"reach": 20.0, "word": "AUUUUU!", "log": "Ein Wolf heult! Das Rudel kommt."},
	"eiswolf": {"reach": 20.0, "word": "AUUUUU!", "log": "Ein Wolf heult! Das Rudel kommt."},
	"ork": {"reach": 18.0, "word": "WAAAGH!", "log": "Ein Ork brüllt nach den Seinen."},
	"bergork": {"reach": 18.0, "word": "WAAAGH!", "log": "Ein Ork brüllt nach den Seinen."},
	"halsabschneider": {"reach": 16.0, "word": "Zu mir!", "log": "Ein Räuber ruft um Hilfe."},
	"schlaeger": {"reach": 16.0, "word": "Zu mir!", "log": "Ein Räuber ruft um Hilfe."},
	"wilderer": {"reach": 16.0, "word": "Zu mir!", "log": "Ein Räuber ruft um Hilfe."},
}


## `victim` has just been struck by the hero and still lives.
static func on_struck(victim: Enemy, hero_at: Vector3) -> void:
	if victim.level == null or victim.dead or victim.hp <= 0 or SlimeCoat.is_slime(victim):
		return
	if victim._help_cool > 0.0:
		return
	victim._help_cool = CALL_GAP
	var call: Dictionary = CALLERS.get(victim.kind, {})
	if not call.is_empty():
		_call(victim, call)
	for e in victim.level.enemies:
		if not is_instance_valid(e) or e == victim or not can_answer(e, victim):
			continue
		var d: float = e._flat_distance(victim)
		var hears: bool = not call.is_empty() and d < float(call.reach)
		var sees: bool = d < SEE_RANGE and victim.level.has_line_of_sight(e.global_position, victim.global_position)
		if hears or sees:
			e.join_defence(hero_at, victim.global_position)


## Whether `e` would come to the aid of `victim`: unaware, not a slime, of the same family, not rivals.
static func can_answer(e: Enemy, victim: Enemy) -> bool:
	if e.dead or e.is_hunting() or e.is_friend() or e.is_cowed() or SlimeCoat.is_slime(e):
		return false
	if LostMine.apart(e.global_position, victim.global_position) or Sewers.apart(e.global_position, victim.global_position):
		return false
	if Factions.kinds_are_rivals(e.kind, victim.kind):
		return false
	var family := MonsterFamilies.family_of(victim.kind)
	return family != "" and MonsterFamilies.family_of(e.kind) == family


## The call itself: a word over the head, a sound that carries and a line in the log.
static func _call(caller: Enemy, call: Dictionary) -> void:
	var word := Lang.t(str(call.word))
	Effects.head_text(caller.level, caller, 3.0 * float(caller._stats.size), word, COLOR)
	var voice: Array = caller._stats.get("voice", ["voice_" + caller.kind, 1.0, ""])
	Sfx.play(caller.level, "%s_%d" % [voice[0], randi() % 2], 6.0, caller.global_position, 0.8 * float(voice[1]))
	Events.say(caller._speaker_name(), word, caller.global_position)
	Events.tell(Lang.t(str(call.log)), COLOR)
