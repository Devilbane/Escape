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
## A skill or monster lore grew: a brief word over the hero's head, such as
## "Skeleton lore +5%" (see Game.show_gain). Use Events.gain.
signal gain_shown(text: String, color: Color)
## The hero understood something new: it goes into the compendium, once
## (see Game.learn). Use Events.teach.
signal lore_learned(entry: String)
## The hero slew an enemy of this kind (a rival monster's kill does not
## count). Factions and bounties count it.
signal enemy_slain(kind: String)
## The hero struck this monster for the first time (a rival's blow, a trap
## or a bleed does not count); the game tells its name and level.
signal enemy_engaged(enemy: Node)
## The hero felled a monster rated at this hero level (see HeroLevel and
## Enemy.rated_level); bosses are worth more. It earns experience.
signal enemy_felled(level: int, boss: bool)
## A bounty from the board was paid out (see Bounties.claim).
signal bounty_paid(id: String)
## The hero solved a riddle: "puzzle" (block-pushing), "secret" (a secret
## room), "writing" (a wall writing) or "rune" (a dwarves' rune tablet), at a
## place of this level (see HeroLevel.RIDDLES). It earns experience.
signal riddle_solved(kind: String, place_level: int)
## The hero fished up a bottle with a treasure map in it (see Fishing and
## TreasureMaps): the map's id. Its spot shows in the world from now on.
signal treasure_map_found(id: String)
## A task was found away from the village, e.g. by freeing a prisoner (see
## Quests, "found"): its id. It starts at once.
signal quest_found(id: String)
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
## The hero spotted a hidden trap (see Traps) at a place of this level; text
## is what the hero makes of it, already translated. It trains Erkunden and
## earns a little experience.
signal trap_spotted(text: String, place_level: int)

## The hero struck with the blade ("melee"), threw a knife ("throw") or
## jumped ("jump"). The first steps' cards listen (see Tutorial).
signal hero_acted(action: String)
## Something struck hard enough to jolt the camera: `strength` in seconds of
## shake (see Game.punch_camera). A vital leap strike sends it (VitalStrike).
signal camera_punched(strength: float)
## The hero found something (loot): the line for the event log at the left
## edge of the screen, already translated (see EventLog). Item names in it
## may be marked with Rarity.marked, to show in their rarity's colour.
## Use Events.found.
signal loot_found(text: String, color: Color)
## Someone said a line out loud at `pos` (a villager, a dungeon dweller, a
## boss); the event log writes it down when the hero is near enough to hear
## it. Text and name are already translated. Use Events.say.
signal speech_said(speaker: String, text: String, pos: Vector3)
## The hero said something through the chat line (see ChatLine) at `pos`:
## the people near answer (see HeroChat). Use Events.hero_says.
signal hero_spoke(text: String, pos: Vector3)
## The hero noticed a writing on a wall (see Level, WallWritings): its
## German text, for the compendium and the journal.
signal writing_found(text: String)

## Something frightening happened above ground: "blitz" (lightning struck),
## "drache" (a dragon flew over), "woelfe" (a full-moon night fell),
## "grauen" (a new-moon night fell) or "tote" (night fell and the dead rise).
## The villagers near the hero cry out and talk about it (see
## VillageWorries). Use Events.scare.
signal scare_happened(kind: String)

## The old dragon's little helpers carried something off the open ground
## into its lair (see DragonHelpers): a floor entry's kind ("item" or
## "coin") and item id (a coin's metal), and how many (a pile of coins).
## The hoard counts it (see DragonHoard). Use Events.carried_off.
signal loot_carried_off(kind: String, id: String, count: int)


## Something hostile happens at the village that the villagers must be alarmed
## about: "gate" (a slime at a gate), "wall" (a slime at the wall), "breach"
## (a stretch of wall broke), "slime" (a slime inside the village) or "eaten"
## (a villager was eaten). The warning bell tolls (see VillageBell). Use Events.alarm.
signal village_alarmed(reason: String)


static var _bus: Events = null


## The one bus of the game.
static func bus() -> Events:
	if _bus == null:
		_bus = Events.new()
	return _bus


## News for the hero to read (see news_told).
static func tell(text: String, color: Color, duration := 4.0) -> void:
	bus().news_told.emit(text, color, duration)


## A brief word over the hero's head for a gain in a skill or in monster lore
## (see gain_shown). It does not go into the event log.
static func gain(text: String, color: Color) -> void:
	bus().gain_shown.emit(text, color)


## Loot for the event log (see loot_found).
static func found(text: String, color := EventLog.LOOT_COLOR) -> void:
	bus().loot_found.emit(text, color)


## A spoken line for the event log (see speech_said).
static func say(speaker: String, text: String, pos: Vector3) -> void:
	bus().speech_said.emit(speaker, text, pos)


## The hero said this out loud (see hero_spoke).
static func hero_says(text: String, pos: Vector3) -> void:
	bus().hero_spoke.emit(text, pos)


## Something hostile happens at the village (see village_alarmed).
static func alarm(reason: String) -> void:
	bus().village_alarmed.emit(reason)


## Something frightening happened (see scare_happened).
static func scare(kind: String) -> void:
	bus().scare_happened.emit(kind)


## The dragon's helpers carried this off (see loot_carried_off).
static func carried_off(kind: String, id: String, count := 1) -> void:
	bus().loot_carried_off.emit(kind, id, count)


## Something new for the compendium (see lore_learned).
static func teach(entry: String) -> void:
	bus().lore_learned.emit(entry)
