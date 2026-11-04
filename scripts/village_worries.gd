class_name VillageWorries
extends RefCounted
## The people of Lindenhain grumble about the weather and take fright at
## what goes on around them. Two kinds of worry:
##   - the weather and the night, which last a while (MOODS keys "regen",
##     "nebel", "gewitter", "kalt", "dunkel"): every so often someone near
##     the hero grumbles about it, once more right after the weather turns;
##   - scares, which happen at one moment (MOODS keys "blitz", "drache",
##     "woelfe", "grauen", "tote", "ungeheuer"): features report them on the
##     event bus with Events.scare(kind), and a moment later someone near the
##     hero cries out. A monster that hunts the hero close to the villagers
##     is noticed here itself ("ungeheuer").
## While a scare is fresh, and now and then in bad weather, the chats of
## VillageTalk are about it too (see chat_lines).
##
## A line is said like any other (Villager.say): it goes into the event log
## when the hero is near enough to hear it. Only someone the hero can hear
## speaks up, so nobody grumbles to an empty street.
##
## Every text is German and has an English entry in scripts/lang/village_worries.gd.

## Seconds between two grumbles about the weather or the night (picked at
## random between the two), and after the weather has just turned.
const REMARK_EVERY := Vector2(35.0, 65.0)
const AFTER_TURN := Vector2(4.0, 8.0)
## Seconds between a scare and the cry it draws.
const CRY_DELAY := Vector2(1.2, 2.5)
## The same kind of scare draws no second cry this soon (seconds): a storm
## strikes every few seconds, and nobody cries out at each bolt.
const CRY_GAP := 45.0
## How long a scare stays on everyone's mind (seconds): chats begun in that
## time are about it.
const SCARE_MEMORY := 120.0
## How likely a chat is about the worry of the moment: a fresh scare, or the
## weather and the night.
const SCARE_CHAT_CHANCE := 0.75
const MOOD_CHAT_CHANCE := 0.4
## A hunting monster this close to a villager frightens them (metres).
const MONSTER_NEAR := 14.0
## Only villagers this close to the hero speak up (see VillageTalk.HEAR_RANGE).
const HEAR_RANGE := VillageTalk.HEAR_RANGE
## Moon phases dark enough to frighten (see Moon.PHASES): the new moon and
## the thin crescents on each side of it.
const DARK_PHASES := [0, 1, 7]
## Before the morning is warm: the chill after the night (hours).
const CHILL_UNTIL := 7.5

## What is said about each worry: "say" lines one villager says on their
## own, "chat" exchanges for two (said in turn, see VillageTalk).
const MOODS := {
	"regen": {
		"say": ["Schon wieder Regen. Meine Stiefel werden nie mehr trocken.",
			"Bei dem Wetter jagt man keinen Hund vor die Tür.",
			"Es schüttet wie aus Eimern!",
			"Der Weg ist nur noch Schlamm."],
		"chat": [["Nass bis auf die Knochen, und es hört nicht auf.", "Gut für die Felder, schlecht für die Laune.", "Meine Laune braucht keinen Regen."],
			["Hast du gesehen? Am Waldteich kriechen bei Regen Schleime aus dem Wasser.", "Igitt. Dann bleibe ich lieber im Trockenen."]]},
	"nebel": {
		"say": ["Man sieht ja die Hand vor Augen nicht.",
			"Bei Nebel treiben Geister zwischen den toten Bäumen. Ich bleib hier.",
			"Dieser Nebel kriecht einem in die Knochen.",
			"Wer da? Ach, nur ein Busch."],
		"chat": [["Hörst du das? Da draußen im Nebel.", "Das ist nur der Wind. Hoffe ich.", "Dann geh du nachsehen."],
			["Im Nebel könnte sich jeder Räuber bis an die Häuser schleichen.", "Sag so etwas nicht, sonst schlafe ich heute gar nicht."]]},
	"gewitter": {
		"say": ["Der Himmel brennt! Alle unter ein Dach!",
			"Hoffentlich schlägt es nicht in mein Haus ein.",
			"Die Götter zürnen heute.",
			"Bei dem Donner wackeln ja die Fensterläden!"],
		"chat": [["Ein Gewitter wie dieses hab ich lange nicht erlebt.", "Bleib bloß weg von den Felsen. Da schlägt der Blitz am liebsten ein.", "Ich bleib weg von allem. Außer vom Ofen."],
			["Zählst du auch zwischen Blitz und Donner?", "Drei. Zwei. Es kommt näher!"]]},
	"kalt": {
		"say": ["Brr, ist das kalt heute.",
			"Ich spür meine Finger nicht mehr.",
			"Die Kälte kriecht unter jeden Mantel.",
			"Wer jetzt kein Feuer im Ofen hat, friert."],
		"chat": [["Kalt ist es geworden.", "Der Frost kommt früh dieses Jahr.", "Dann rücken wir eben näher ans Feuer."]]},
	"dunkel": {
		"say": ["So dunkel war es lange nicht. Kein Mond, kein Stern.",
			"In so einer Nacht geht keiner gern allein vor die Tür.",
			"Bleib im Licht der Laternen, Fremder.",
			"Wenn der Mond fehlt, kriecht das Grauen aus den Löchern."],
		"chat": [["Ohne Mond sieht man nicht, was da draußen lauert.", "Und was da draußen lauert, sieht uns.", "Danke. Jetzt fürchte ich mich noch mehr."]]},
	"blitz": {
		"say": ["Der hat eingeschlagen! Ganz in der Nähe!",
			"Bei allen Göttern, war das ein Knall!",
			"Hast du den Blitz gesehen? Mir zittern die Knie."],
		"chat": [["Der Blitz eben, der war nah.", "Zu nah. Mir klingeln noch die Ohren."]]},
	"drache": {
		"say": ["Was war das für ein Schrei?!",
			"Ein Schatten über dem Dorf! War das ein Drache?",
			"Duckt euch! Der Drache fliegt über uns!",
			"Hoffentlich hat er keinen Hunger."],
		"chat": [["Hast du den Schrei gehört? Aus den Bergen?", "Das war ein Drache. So schreit nichts anderes.", "Dann bete ich, dass er in den Bergen bleibt."],
			["Ein Schatten, so groß wie der Tempel!", "Und wenn er wiederkommt? Unsere Dächer sind aus Stroh!"]]},
	"woelfe": {
		"say": ["Hört ihr die Wölfe heulen? Es ist Vollmond.",
			"Bei Vollmond jagt das Rudel. Haltet die Türen zu!",
			"Die Wölfe sind unruhig heute Nacht."],
		"chat": [["Das Heulen aus der Senke wird lauter.", "Vollmond. Da jagen sie im Rudel.", "Dann bleibt meine Tür heute verriegelt."]]},
	"grauen": {
		"say": ["Neumond. Die Löcher atmen wieder.",
			"Etwas Großes kriecht da draußen herum. Ich spür es.",
			"Riechst du das? Kalt und modrig, aus den Löchern."],
		"chat": [["Neumond. Etwas kriecht aus den Löchern ans Dorf.", "Die Alten sagen, es frisst Licht.", "Dann zünde ich heute jede Kerze an."]]},
	"tote": {
		"say": ["Schnell nach Hause! Auf dem Friedhof regen sich die Toten.",
			"Die Nacht kommt. Hört ihr die Gräber knarren?",
			"Ich hasse die Nacht. Da stehen die Toten auf."],
		"chat": [["Auf dem Friedhof klappern wieder die Knochen.", "Solange sie dort bleiben, soll es mir recht sein."]]},
	"ungeheuer": {
		"say": ["Hilfe! Ein Ungeheuer!",
			"Lauf! Da kommt etwas!",
			"Holt die Wache!",
			"Bleib mir vom Leib, du Biest!"],
		"chat": [["Hast du das Biest gesehen? Mitten bei uns!", "Ich hab mich hinter dem Fass versteckt.", "Ich auch. Hinter dir."]]},
}
## Kinds that last a while (the weather and the night); the rest are scares.
const LASTING := ["regen", "nebel", "gewitter", "kalt", "dunkel"]

## Lines of their own for some villagers, said instead of the usual ones
## every other time.
const ROLE_SAYS := {
	"2": {"regen": ["Endlich Regen! Die Kürbisse danken es.", "Regnet es zu lange, faulen mir die Rüben."],
		"kalt": ["Der Frost! Das Korn muss rein, sofort!"]},
	"4": {"kalt": ["Wache stehen in dieser Kälte. Wofür mache ich das?"],
		"dunkel": ["Keine Mondnacht für eine Wache. Ich sehe mein eigenes Schwert kaum."],
		"ungeheuer": ["Zurück, Bestie! Hier hält die Wache!"],
		"tote": ["Ich halte Wache. Die Toten kommen nicht ins Dorf."]},
	"5": {"kalt": ["Gegen die Kälte hilft nur ein Krug. Oder zwei."],
		"regen": ["Regen? Dann bleibe ich eben noch ein Weilchen sitzen."],
		"drache": ["Ein Drache! Wirt, noch einen Krug, schnell!"]},
	"7": {"drache": ["Ein Drache! Ein echter Drache! Mama, hast du ihn gesehen?"],
		"gewitter": ["Wenn es donnert, verstecke ich mich unter dem Bett."],
		"tote": ["Mama sagt, wenn ich nicht ins Bett gehe, holen mich die Toten."]},
	"8": {"drache": ["Ein Drache! In meinen Büchern stand, sie seien längst ausgestorben."],
		"nebel": ["Nebel ist nur Wasser in der Luft. Kein Grund zur Furcht. Glaube ich."]},
	"9": {"regen": ["Wenigstens muss ich heute weniger Wasser schleppen."],
		"kalt": ["Hoffentlich friert der Brunnen nicht zu."]},
	"M": {"regen": ["Bei jedem Wetter, hab ich geschworen. Warum hab ich das geschworen?"],
		"nebel": ["Bei dem Nebel finde ich kein einziges Haus."]},
	"O": {"dunkel": ["Möge das Licht des Tempels uns durch diese dunkle Nacht führen."],
		"grauen": ["Ihr Götter, beschützt uns vor dem, was aus der Tiefe kommt."],
		"gewitter": ["Die Götter sprechen im Donner. Hören wir zu."]},
}

var game: Node
## The kind of the fresh scare ("" for none) and how long it stays on
## everyone's mind.
var scare := ""
var scare_left := 0.0
## A cry still to come: its kind and the seconds until then ({} for none).
var _cry := {}
## When each kind of scare last drew a cry (seconds of `_clock`).
var _cried := {}
var _clock := 0.0
var _remark_timer := 0.0
## The weather when we last looked, to notice a turn.
var _weather := ""
## How many times each kind has been spoken of, to take turns with the lines.
var _turns := {}
var _monster_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _init(owner_game: Node = null) -> void:
	game = owner_game
	_rng.randomize()
	clear()


func clear() -> void:
	scare = ""
	scare_left = 0.0
	_cry = {}
	_cried.clear()
	_turns.clear()
	_weather = ""
	_clock = 0.0
	_remark_timer = _rng.randf_range(REMARK_EVERY.x, REMARK_EVERY.y)


## Something frightening happened (see Events.scare): someone near the hero
## cries out in a moment, and the chats are about it for a while.
func on_scare(kind: String) -> void:
	if not MOODS.has(kind) or LASTING.has(kind):
		return
	if game == null or not (game.level is Outdoor):
		return
	scare = kind
	scare_left = SCARE_MEMORY
	if _clock - float(_cried.get(kind, -1e9)) >= CRY_GAP:
		_cry = {"kind": kind, "wait": _rng.randf_range(CRY_DELAY.x, CRY_DELAY.y)}


## The lasting worries right now: the weather and the night (see LASTING).
func conditions(village: Outdoor) -> Array:
	var out := []
	if village == null:
		return out
	match village.weather:
		Weather.RAIN: out.append("regen")
		Weather.FOG: out.append("nebel")
		Weather.STORM: out.append("gewitter")
	var hour: float = village.hour
	if village.night or (hour >= DayNight.NIGHT_UNTIL and hour < CHILL_UNTIL):
		out.append("kalt")
	if village.night and village.moon_night >= 0 and Moon.phase(village.moon_night) in DARK_PHASES:
		out.append("dunkel")
	return out


## What a chat beginning now should be about: an exchange of German lines,
## or [] for the pair's usual talk.
func chat_lines(village: Outdoor) -> Array:
	var kind := ""
	if scare != "" and _rng.randf() < SCARE_CHAT_CHANCE:
		kind = scare
	else:
		var now := conditions(village)
		if not now.is_empty() and _rng.randf() < MOOD_CHAT_CHANCE:
			kind = now[_rng.randi() % now.size()]
	if kind == "":
		return []
	var all: Array = MOODS[kind].chat
	return all[_take_turn("chat-" + kind) % all.size()]


## Every frame in the village while the world runs (next to VillageTalk.update).
func update(delta: float, village: Outdoor) -> void:
	if village == null or game == null:
		return
	_clock += delta
	if scare_left > 0.0:
		scare_left -= delta
		if scare_left <= 0.0:
			scare = ""
	_watch_monsters(delta, village)
	if not _cry.is_empty():
		_cry.wait -= delta
		if _cry.wait <= 0.0:
			var kind: String = _cry.kind
			_cry = {}
			if speak_up(village, kind):
				_cried[kind] = _clock
	# The weather has just turned bad: someone grumbles soon.
	if village.weather != _weather:
		if _weather != "" and village.weather != Weather.CLEAR:
			_remark_timer = minf(_remark_timer, _rng.randf_range(AFTER_TURN.x, AFTER_TURN.y))
		_weather = village.weather
	_remark_timer -= delta
	if _remark_timer > 0.0:
		return
	_remark_timer = _rng.randf_range(REMARK_EVERY.x, REMARK_EVERY.y)
	var now := conditions(village)
	if not now.is_empty():
		speak_up(village, now[_rng.randi() % now.size()])


## A monster after the hero close to the villagers: a fright of its own.
func _watch_monsters(delta: float, village: Outdoor) -> void:
	_monster_timer -= delta
	if _monster_timer > 0.0:
		return
	_monster_timer = 0.5
	for e in village.enemies:
		if not is_instance_valid(e) or not e.is_hunting():
			continue
		for v in village.villagers:
			if is_instance_valid(v) and v.can_remark() and VillageTalk._flat(v.global_position, e.global_position) <= MONSTER_NEAR:
				on_scare("ungeheuer")
				return


## Someone close to the hero, free to talk, says a line about `kind`.
## Returns whether anyone did.
func speak_up(village: Outdoor, kind: String) -> bool:
	if game.village_talk.is_chatting():
		return false
	var hero: Vector3 = game.player.global_position
	var options := []
	for v in village.villagers:
		if is_instance_valid(v) and v.can_remark() and VillageTalk._flat(v.global_position, hero) <= HEAR_RANGE and v.talker_near() == null:
			options.append(v)
	if options.is_empty():
		return false
	var who: Villager = options[_rng.randi() % options.size()]
	var text := Lang.t(line_for(who.role, kind))
	who.say(text, Vector3.INF, VillageTalk.line_time(text))
	return true


## The next line a villager says about `kind` (German): their own every
## other time, when they have one.
func line_for(role: String, kind: String) -> String:
	var turn := _take_turn(role + "-" + kind)
	var own: Array = ROLE_SAYS.get(role, {}).get(kind, [])
	if not own.is_empty() and turn % 2 == 0:
		return own[(turn / 2) % own.size()]
	var all: Array = MOODS[kind].say
	return all[_take_turn("say-" + kind) % all.size()]


func _take_turn(key: String) -> int:
	var n := int(_turns.get(key, 0))
	_turns[key] = n + 1
	return n
