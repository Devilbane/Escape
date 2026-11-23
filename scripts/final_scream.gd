class_name FinalScream
extends Node
## The last cry of someone who goes down in a fight: the hero or any monster
## or bandit that falls (Enemy._die, Player defeated). All eyes are on that
## moment: every other speech bubble and comic word vanishes at once, and no
## new one appears while the scream shows (SpeechBubble.silenced, Comic.pop).
## It is an action bubble, the same jagged burst as the combat words (Comic),
## that lasts about three seconds in all (TOTAL), pop-in and burst included,
## and then bursts. Only one scream shows at a time: a newer fall takes over
## from an older one.
##
## Every text is German and has an English entry in scripts/lang/final_scream.gd.

## The whole scream, from the first pop to the last scrap, lasts about this
## long for everyone (hero and monsters): the bubble's pop-in, its hold, the
## squeeze and the burst's scraps (see Comic._pop) all count towards it.
const TOTAL := 3.0
## Pop-in (7 wobbles of 0.085 s) and squeeze (0.07 + 0.08 s) around the hold.
const POP_IN := 0.595
const SQUEEZE := 0.15
## The scraps of the burst fly for this long.
const SCRAPS := 0.4
## How long the bubble holds still between pop-in and squeeze.
const SECONDS := TOTAL - POP_IN - SQUEEZE - SCRAPS
## How long the scream has the stage (silences other bubbles): until the burst.
const STAGE := SECONDS + POP_IN + SQUEEZE

const HERO_LINES := ["Neeein... nicht so...!", "Aaargh... mir wird schwarz...", "Das... war... zu viel..."]
## The cries per monster family (MonsterFamilies); horrors and unsorted kinds use "".
const LINES := {
	"bandits": ["Aaargh... mein Kupfer...!", "Verflucht... sollst du sein...!"],
	"humans": ["Neeein... Gnade...!", "Aaah... Mutter...!"],
	"undead": ["Ich... zer... falle...!", "Kla... ppp... errr...!"],
	"ghosts": ["Uuuuuaaaaahhh...!", "Ich... verwehe...!"],
	"wildlife": ["Jauuuuuuul...!", "Kriiieeeeek...!"],
	"fable": ["Kreeeiiiiisch...!", "Unmööööglich...!"],
	"": ["GRAAAAAAHHH...!", "Hhhhhaaaarrrgh...!"],
}

## The scream that has the stage right now.
static var current: FinalScream = null

var text := ""
var _left := STAGE
var _bubble: Control = null


## `body` cries out as it falls: the burst rises from its head, `height`
## metres over its feet. `speaker` is kept for callers; the burst shows only
## the cry. Returns the scream, or null when nothing can be shown.
static func scream(parent: Node, body: Node3D, speaker: String, line: String, height: float) -> FinalScream:
	if parent == null or not parent.is_inside_tree() or Comic.current == null:
		return null
	if is_instance_valid(current):
		current.queue_free()
	for b in parent.get_tree().get_nodes_in_group(SpeechBubble.GROUP):
		if b is SpeechBubble:
			(b as SpeechBubble).hide_line(true)
	Comic.clear()
	var s := FinalScream.new()
	s.text = line
	parent.add_child(s)
	current = s
	SpeechBubble.silenced_by = s
	s._bubble = Comic.scream(body.global_position + Vector3(0, height, 0), line, SECONDS)
	return s


## A random last cry for the hero.
static func hero_line() -> String:
	return Lang.t(HERO_LINES.pick_random())


## A random last cry for a monster of `kind`.
static func monster_line(kind: String) -> String:
	var lines: Array = LINES.get(MonsterFamilies.family_of(kind), LINES[""])
	return Lang.t(lines.pick_random())


## Whether a scream holds the stage right now.
static func showing() -> bool:
	return SpeechBubble.silenced()


func is_shown() -> bool:
	return is_instance_valid(_bubble)


func holds_stage() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	_left -= delta
	if _left <= -1.0 or (_left <= 0.0 and not is_shown()):
		if current == self:
			current = null
		queue_free()
