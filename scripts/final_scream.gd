class_name FinalScream
extends SpeechBubble
## The last cry of someone who goes down in a fight: the hero or any monster
## or bandit that falls (Enemy._die, Player defeated). All eyes are on that
## moment: every other speech bubble and comic word vanishes at once, and no
## new one appears while the scream shows (SpeechBubble.silenced, Comic.pop).
## It stays three times as long as a normal line (Villager.SAY_TIME) and
## fades in and out three times as slowly, a drawn-out cry. Only one scream
## shows at a time: a newer fall takes over from an older one.
##
## Every text is German and has an English entry in scripts/lang/final_scream.gd.

## How much longer and slower than a normal bubble.
const SLOWER := 3.0
const SECONDS := Villager.SAY_TIME * SLOWER
## A pale, blood-tinged paper sets it apart from a normal line.
const SCREAM_PAPER := Color(1.0, 0.86, 0.82)

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

var _left := SECONDS


## `body` cries out as it falls: the scream rises from its head, `height`
## metres over its feet, under `parent` (the level, so it outlives a body that
## is removed). Returns the bubble.
static func scream(parent: Node, body: Node3D, speaker: String, line: String, height: float) -> FinalScream:
	if parent == null or not parent.is_inside_tree():
		return null
	if is_instance_valid(current):
		current.queue_free()
	for b in parent.get_tree().get_nodes_in_group(GROUP):
		if b is SpeechBubble:
			(b as SpeechBubble).hide_line(true)
	Comic.clear()
	var s := FinalScream.new()
	parent.add_child(s)
	s.global_position = body.global_position + Vector3(0, height, 0)
	current = s
	silenced_by = s
	s.show_line(speaker, line)
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


func _ready() -> void:
	super()
	fade = FADE / SLOWER
	_material.set_shader_parameter("paper", SCREAM_PAPER)


func holds_stage() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 and _target > 0.0:
		hide_line()
	super(delta)
	if _left <= 0.0 and not visible:
		if current == self:
			current = null
		queue_free()
