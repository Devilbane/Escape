class_name HeroChat
extends RefCounted
## What the people of the village answer when the hero says something through
## the chat line (see ChatLine). The hero's words go into the event log and
## float over the hero's head (Game._hero_says); features hear them on the
## event bus (Events.hero_spoke), and this is the one that answers.
##
## The nearest free villager within REPLY_RANGE answers after a short pause:
## a greeting to a greeting, a goodbye, a thanks-you-are-welcome, and for
## anything else their usual line, the one they say when the hero talks to
## them (Villager.talk). Nobody near means no answer (the cell has none).
## The answer is said like any other line (Villager.say): a bubble over the
## head and a line in the event log.
##
## Every text is German and has an English entry in scripts/lang/hero_chat.gd.

## Villagers this close to the hero hear (metres).
const REPLY_RANGE := 9.0
## The pause before the answer, picked at random between the two (seconds).
const DELAY := Vector2(0.8, 1.5)

## Words that make a line a greeting, a goodbye or a thanks (lower case,
## German and English).
const GREETINGS := ["hallo", "hi", "hey", "moin", "grüß", "guten tag", "guten morgen", "guten abend", "servus", "hello", "good morning", "good evening", "good day"]
const FAREWELLS := ["tschüss", "tschuess", "tschau", "ciao", "auf wiedersehen", "bis bald", "bye", "goodbye", "farewell", "see you"]
const THANKS := ["danke", "dankeschön", "thanks", "thank you"]

const GREETING_REPLIES := [
	"Guten Tag, Fremder!",
	"Hallo! Schön, ein freundliches Wort zu hören.",
	"Sei gegrüßt! Wie geht es dir?",
]
const FAREWELL_REPLIES := [
	"Gehab dich wohl, Fremder!",
	"Auf bald! Pass auf dich auf.",
	"Mögen deine Wege sicher sein.",
]
const THANKS_REPLIES := [
	"Gern geschehen!",
	"Keine Ursache, Fremder.",
]

var game: Node
var _rng := RandomNumberGenerator.new()
var _turn := 0


func _init(owner_game: Node) -> void:
	game = owner_game
	_rng.randomize()


## The hero said `text` at `pos` (see Events.hero_spoke): the nearest free
## villager answers after a pause.
func on_hero_spoke(text: String, pos: Vector3) -> void:
	var who := listener(pos)
	if who == null:
		return
	var delay := _rng.randf_range(DELAY.x, DELAY.y)
	game.get_tree().create_timer(delay).timeout.connect(func() -> void: answer(who, text))


## The nearest villager near `pos` who is free to answer, or null.
func listener(pos: Vector3) -> Villager:
	# Only the village has villagers (the cells and the dungeon levels do not).
	if game.level == null or not "villagers" in game.level:
		return null
	var best: Villager = null
	var best_d := REPLY_RANGE
	for v in game.level.villagers:
		if not is_instance_valid(v) or not v.can_remark():
			continue
		var d := VillageTalk._flat(v.global_position, pos)
		if d <= best_d:
			best = v
			best_d = d
	return best


## `who` answers what the hero said, unless they have gone or the hero has.
func answer(who: Villager, text: String) -> void:
	if not is_instance_valid(who) or not who.is_inside_tree() or game.player == null:
		return
	if VillageTalk._flat(who.global_position, game.player.global_position) > REPLY_RANGE * 1.5:
		return
	var reply := reply_to(text)
	if reply == "":
		who.talk(game.player)
		return
	who.say(Lang.t(reply), game.player.global_position, VillageTalk.line_time(reply))


## The German answer to a greeting, a goodbye or a thanks, "" for anything
## else (then the villager says their usual line).
func reply_to(text: String) -> String:
	var low := text.to_lower()
	var pool: Array = []
	if _has_word(low, GREETINGS):
		pool = GREETING_REPLIES
	elif _has_word(low, FAREWELLS):
		pool = FAREWELL_REPLIES
	elif _has_word(low, THANKS):
		pool = THANKS_REPLIES
	if pool.is_empty():
		return ""
	_turn += 1
	return pool[_turn % pool.size()]


## Whether one of `words` is in `low` as a word of its own ("hi" is not in
## "nichts").
static func _has_word(low: String, words: Array) -> bool:
	for w in words:
		var from := 0
		while true:
			var at: int = low.find(w, from)
			if at < 0:
				break
			var before_ok: bool = at == 0 or not _is_letter(low[at - 1])
			var end: int = at + w.length()
			# A greeting may carry an ending ("grüße", "grüß dich").
			var after_ok: bool = end >= low.length() or not _is_letter(low[end]) or w == "grüß"
			if before_ok and after_ok:
				return true
			from = at + 1
	return false


static func _is_letter(c: String) -> bool:
	return c.to_lower() != c.to_upper()
