class_name Tiles
## The map letters: one table per kind of map, letter -> what it places.
##
## This is the single place to look up a free letter and to claim a new one.
## Every map file in levels/ may only use letters listed here for its kind,
## and the letter tables in the code (Enemy.LETTERS, Animal.LETTERS,
## Villager.ROLES, ...) must not hand one letter to two things. The test
## tests/tile_letters.gd checks both, so two branches that pick the same
## letter clash here, in one line, instead of quietly on the map.
##
## To add a tile: claim the letter in the right table below (a letter can
## only be listed once per table, a second entry does not even parse), build
## it in Level._build_content or Outdoor._build_outdoor_cell (or add it to one
## of the letter tables there), then use it in the map.
##
## A blank in a map counts as a wall.

## Letters of every map built by Level: the dungeon levels and the floors
## inside buildings (vault, dragon's lair, homes, the holes and their caves).
const DUNGEON := {
	"#": "wall",
	".": "floor",
	",": "dirt floor",
	"P": "player start",
	"E": "exit stairs (the front door of a home)",
	"K": "key",
	"D": "locked door",
	"S": "spike trap",
	"c": "coin",
	"C": "treasure chest",
	"k": "small trunk",
	"b": "barrel",
	"x": "crates",
	"o": "pillar",
	"t": "table",
	"f": "fire bowl (always lit)",
	"M": "skeleton warrior (melee), see Enemy.LETTERS",
	"A": "skeleton archer (ranged)",
	"Z": "skeleton mage (magic orbs)",
	"w": "skeleton minion (small, quick)",
	"G": "skeleton brute (big, slow, hits hard)",
	"W": "guardian in armour (watches a hall)",
	"v": "bat (dragon's lair)",
	"s": "slime (dragon's lair)",
	"R": "dragon (dragon's lair)",
	"y": "stone horse statue (dragon's lair)",
	"H": "shrine: one gift (more life, strength or speed)",
	"B": "bed (save and log out)",
	"L": "storage chest",
	"V": "merchant",
	"F": "fountain: refills life, cures poison and curses",
	"?": "secret wall, opened by a lever torch",
	"=": "iron bars",
	"U": "a vault behind the bars (the bank's cellar)",
	"_": "pressure plate",
	"Q": "old, heavy stone block (see StoneBlock.heavy)",
	"|": "iron gate, sinks once every plate holds a block",
	"<": "stairs up to the next storey",
	">": "stairs down to the storey below",
	"+": "free floor kept for furniture (homes)",
	"X": "a horror's den (see Horrors)",
}

## Letters of the open-air map built by Outdoor.
const OUTDOOR := {
	"#": "forest (trees, cannot be crossed)",
	".": "grass",
	",": "dirt path",
	"P": "start, in front of the crypt door",
	"~": "village pond (fishing)",
	";": "wolf hollow pond (fishing, moon trout at night)",
	"R": "the crypt (a block of tiles)",
	"g": "grave",
	"d": "dead tree",
	"z": "graveyard fence",
	"a": "gate in the fence",
	"l": "lantern on a post",
	"p": "pumpkins",
	"r": "rock",
	"T": "tree",
	"t": "tree stump with logs",
	"e": "barrels, crates and sacks",
	"q": "well",
	"y": "pumpkin field",
	":": "paved square",
	"F": "fountain (heals)",
	"x": "bench",
	"v": "stone pedestal with a food basket, crates close by",
	"!": "bounty board",
	"@": "the wandering merchant's pitch",
	"(": "dark hole down into a cave of its own",
	# Buildings, each a rectangular block of the same letter (Outdoor.BLOCK_CHARS).
	"h": "house (half-timbered, see VillageHouse)",
	"j": "smithy",
	"n": "tavern",
	"m": "market",
	"u": "windmill",
	"s": "temple (a chapel)",
	"k": "office of the crown",
	"o": "post office",
	"w": "adventurers' guild",
	"b": "bank",
	"^": "Weavers' Lane: narrow town houses, one home per tile",
	"E": "the way down into the dragon's lair (a block of tiles)",
	# The hero's old house inside the village.
	"I": "house: stone wall",
	"i": "house: wooden floor",
	"B": "house: bed (save and log out)",
	"L": "house: chest (storage)",
	# Villagers (Outdoor.VILLAGERS, their roles in Villager.ROLES).
	"0": "village elder",
	"1": "smith (forge on the tile to his left)",
	"2": "farmer",
	"3": "woodcutter",
	"4": "guard",
	"5": "tavern guest",
	"6": "shopkeeper",
	"7": "child",
	"8": "scholar",
	"9": "water carrier",
	"K": "herald of the crown",
	"O": "priestess",
	"G": "guild master",
	"M": "postmaster",
	"Y": "banker",
	"Z": "barber",
	"S": "stonemason (stone yard on the tile behind him)",
	# The robbers' pass and the wolf hollow (Enemy.WILD_LETTERS).
	"N": "tent",
	"f": "campfire",
	"C": "treasure chest (the robbers' hoard)",
	"c": "cutthroat",
	"A": "poacher (crossbow)",
	"X": "bruiser",
	"Q": "bandit chief",
	"W": "wolf",
	"H": "orc",
	"J": "yeti",
	"U": "spider",
	# Peaceful animals (Animal.LETTERS).
	"D": "doe",
	"V": "stag",
	"&": "fox",
	# The crafting square (CraftingSquare.LETTERS).
	"+": "fine metalwork bench",
	"%": "gem cutter's wheel",
	"*": "alchemist's table",
	"$": "the hero's storage chest",
}
