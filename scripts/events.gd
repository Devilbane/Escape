class_name Events
extends RefCounted

## The event bus: features report what happened here, and whoever cares
## listens, so quests, bounties, reputation and the rest do not have to call
## the game (or each other) directly.
##
## There is one bus for the whole game, reached with Events.bus(). It is a
## plain static instance, not an autoload, so it works the same in the game
## and in the headless tests started with `godot -s`.
##
## Emitting a signal calls its listeners right away, in the order they
## connected, so moving a call onto the bus does not change when it happens.
##
## A listener that is an object method is dropped on its own when that object
## is freed. The game connects in _enter_tree and lets go in _exit_tree.

## Something the hero should read about a task, a hunt, a recipe or a catch:
## a message and a word over the hero's head (see Game.quest_news).
## Use Events.tell.
signal news_told(text: String, color: Color, duration: float)
## The hero understood something new: it goes into the compendium, once
## (see Game.learn). Use Events.teach.
signal lore_learned(entry: String)
## The hero slew an enemy of this kind (a rival monster's kill does not
## count). Factions and bounties count it.
signal enemy_slain(kind: String)
## The hero felled a monster rated at this hero level (see HeroLevel and
## Enemy.rated_level); bosses are worth more. It earns experience.
signal enemy_felled(level: int, boss: bool)
## A bounty from the board was paid out (see Bounties.claim).
signal bounty_paid(id: String)
## The hero solved a riddle: "puzzle" (block-pushing), "secret" (a secret
## room), "writing" (a wall writing) or "rune" (a dwarves' rune tablet), at a
## place of this level (see HeroLevel.RIDDLES). It earns experience.
signal riddle_solved(kind: String, place_level: int)
## A villager's task is done and its reward handed over (see Quests).
signal quest_done(id: String)
## Something went into or out of the bag because of a task.
signal quest_item_given()
## A villager thinks better of the hero now (see Reputation.LEVELS).
signal reputation_rose(role: String, new_level: int)
## The hero bought something from the villager with this role letter.
signal traded(role: String)
## New landmarks came into view and went onto the map (see Journal).
signal map_grew(names: Array)
## The hero has seen the whole of a map, the level file named (see
## Journal.note_full_map). It trains the Erkunden skill.
signal map_explored(file: String)
## The hero spotted a hidden trap of this kind ("stacheln", "teleport" or
## "falltuer", see Traps) at a place of this level. It trains Erkunden and
## earns a little experience.
signal trap_spotted(kind: String, place_level: int)

## The hero struck with the blade ("melee"), threw a knife ("throw") or
## jumped ("jump"). The first steps' cards listen (see Tutorial).
signal hero_acted(action: String)
## The hero noticed a writing on a wall (see Level, WallWritings): its
## German text, for the compendium and the journal.
signal writing_found(text: String)


static var _bus: Events = null


## The one bus of the game.
static func bus() -> Events:
	if _bus == null:
		_bus = Events.new()
	return _bus


## News for the hero to read (see news_told).
static func tell(text: String, color: Color, duration := 4.0) -> void:
	bus().news_told.emit(text, color, duration)


## Something new for the compendium (see lore_learned).
static func teach(entry: String) -> void:
	bus().lore_learned.emit(entry)
