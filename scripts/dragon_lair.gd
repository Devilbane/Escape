class_name DragonLair
## Embermaw's lair below the stone arch in the woods: three floors deep, each
## a maze of its own (levels 13, 28 and 29, buildings E, E2 and E3).
##
## - E, the dragon's cave: a tangle of passages with loops and dead ends. A
##   key lies at the far end of a side branch; it opens the door to the room
##   with the way down ("^", see Mines).
## - E2, the sulphur passages: an iron gate bars the way down. It sinks once
##   the two old stone blocks in the puzzle hall lie on its pressure plates.
## - E3, Embermaw's hoard: a locked door seals the dragon's hall; a skeleton
##   brute guards the key at the other end of the passages.
##
## The floors hang together like the deep mine (headers "down:" and "up:").
## While the hero is down there, every floor remembers what they did on it:
## fallen monsters stay fallen, open doors open, keys taken, blocks pushed and
## gates sunk (Level.note_left), so climbing back up costs no progress. All of
## that is set back when the hero comes in through the arch again (reset):
## the monsters stand ready again and the doors are locked, as the lair always
## was. Chests searched and coins taken stay gone, like everywhere.
##
## Embermaw itself drops parts of its body when it falls (see parts): a scale
## and its blood every time, and now and then its glowing heart. They go into
## the ingredient pouch and teach the dragon recipes (see Crafting).
##
## Once the lair is won, leaving it shows what the hero carried out of it
## (snapshot, spoils and the window "beute" in Menus).

## The buildings of the lair's floors, from the top down.
const FLOORS := ["E", "E2", "E3"]

## The parts of the dragon, as Crafting ingredients, and the colour of each
## lump on the floor.
const SCALE := "drachenschuppe"
const BLOOD := "drachenblut"
const HEART := "glutherz"
const PART_COLOURS := {
	SCALE: Color(0.75, 0.22, 0.12),
	BLOOD: Color(0.55, 0.02, 0.06),
	HEART: Color(1.0, 0.55, 0.12),
}
## How often the fallen dragon leaves its glowing heart too.
const HEART_CHANCE := 0.5

## What the compendium says about the parts, the first time one is found.
const PARTS_LEARN := "Glutschlund hinterlässt, wenn er fällt, Teile seines Leibes: immer eine Schuppe und sein Blut, manchmal auch sein glühendes Herz. Sie kommen in deinen Zutatenbeutel; am Feinschmiedetisch auf dem Handwerkerplatz wird daraus Drachenschmuck."


## Whether `level` is one of the lair's floors.
static func is_floor(level: Level) -> bool:
	return level != null and level.lair and level.building in FLOORS


## What the dragon leaves this time: the scale and the blood, and the heart
## with a chance of HEART_CHANCE.
static func parts(rng: RandomNumberGenerator) -> Array:
	var out := [SCALE, BLOOD]
	if rng.randf() < HEART_CHANCE:
		out.append(HEART)
	return out


## Whether a key in Level.taken is progress made on a visit (see note_left),
## which the next visit starts without.
static func is_visit_progress(key: String) -> bool:
	return key.begins_with("slain:") or key.begins_with("door:") or key.begins_with("heavy:") \
			or key == Level.KEY_GONE or key == Level.GATES_OPEN


## A new visit through the arch: every floor forgets the fallen monsters,
## opened doors, keys and pushed blocks of the last one.
static func reset(looted: Dictionary, files: Array, interiors: Dictionary) -> void:
	for building in FLOORS:
		if not interiors.has(building):
			continue
		var file: String = str(files[interiors[building]]).get_file()
		var taken: Dictionary = looted.get(file, {})
		for key in taken.keys():
			if is_visit_progress(str(key)):
				taken.erase(key)


## What the hero has when stepping into the lair: gold, bars, the pouch and
## the bag.
static func snapshot(game: Node) -> Dictionary:
	return {"coins": game.coins, "iron": game.iron, "bars": game.bars.duplicate(),
			"pouch": game.crafting.pouch.duplicate(), "bag": game.player.bag.duplicate()}


## What the hero gained since `before` (see snapshot): "gold", "bars"
## (metal -> count, iron among them), "ingredients" (id -> count) and
## "items" (id -> count). Only gains count: a knife thrown or a piece of gear
## dropped down there takes nothing off.
static func spoils(before: Dictionary, game: Node) -> Dictionary:
	var out := {"gold": maxi(0, game.coins - int(before.get("coins", 0))), "bars": {}, "ingredients": {}, "items": {}}
	var iron: int = game.iron - int(before.get("iron", 0))
	if iron > 0:
		out.bars["eisen"] = iron
	var old_bars: Dictionary = before.get("bars", {})
	for metal in game.bars:
		var n := int(game.bars[metal]) - int(old_bars.get(metal, 0))
		if n > 0:
			out.bars[metal] = n
	var old_pouch: Dictionary = before.get("pouch", {})
	for id in game.crafting.pouch:
		var n := int(game.crafting.pouch[id]) - int(old_pouch.get(id, 0))
		if n > 0:
			out.ingredients[id] = n
	var old_bag := {}
	for id in before.get("bag", []):
		old_bag[id] = int(old_bag.get(id, 0)) + 1
	var bag := {}
	for id in game.player.bag:
		bag[id] = int(bag.get(id, 0)) + 1
	for id in bag:
		var n: int = bag[id] - int(old_bag.get(id, 0))
		if n > 0:
			out.items[id] = n
	return out


## Whether nothing at all was gained.
static func spoils_empty(s: Dictionary) -> bool:
	return int(s.get("gold", 0)) == 0 and s.get("bars", {}).is_empty() \
			and s.get("ingredients", {}).is_empty() and s.get("items", {}).is_empty()
