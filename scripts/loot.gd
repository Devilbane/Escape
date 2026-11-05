class_name Loot
extends RefCounted
## What a fallen monster leaves behind, one table for every fight.
##
## Rarity and drop odds: every kill rolls once for a find, finest tier first,
## with these odds per kill (see ODDS): common 1 in 20 to 1 in 40, uncommon
## 1 in 80 to 1 in 160, rare 1 in 320 to 1 in 640, epic 1 in 1000 to 1 in
## 2500. Where in its range a monster lies goes by how tough it is (see
## toughness): the weakest get the long odds, the toughest (and every elite
## or named boss) the short ones. God-born pieces are not loot for now
## (TOP_TIER): no chest, kill or hoard holds one.
##
## Two kinds of monsters, two kinds of loot:
## - intelligent ones, and those who use the hero's kind of gear (the
##   skeletons, the bandits, orcs, trolls, dragons): coins with every kill
##   (all of them into the purse, copper coins as the money, see coins) and, with the odds above, a piece of gear of the
##   rolled tier, one they wore if they wore one of that tier;
## - the others, beasts without a mind (wolves, spiders, bats, yetis,
##   slimes): no coins and no gear but, with the odds above, food (common),
##   an ingredient of the place they live in (uncommon) or a part of their
##   body to keep as a trophy or use in a craft (rare), or nothing.
## The ghosts of the dungeon (Enemy "ghost": wraiths, banshees) were people
## once, but they have no hands and no pockets any more: they leave what a
## beast does, from a table of their own (ectoplasm, a crypt herb, a part of
## what they are).
## Slimes are beasts too, but they swallow what their victims carried: they
## also drop coins and gear like the intelligent ones (see SWALLOWS).
##
## A hundred coins of one metal melt down into one bar of it at Gorm's
## forge (see COINS and Forge.melt_coins). Trolls and the other creatures of
## the mountains also carry raw ore, on a roll of its own (see ore_find and
## Ore), which melts down into grams of the metals in it.

## The finest tier that can be looted: god-born pieces are not, for now.
const TOP_TIER := "episch"
## Per tier, plain to finest: [best, worst] odds as "1 in N kills".
const ODDS := {
	"normal": [20, 40],
	"ungewoehnlich": [80, 160],
	"selten": [320, 640],
	"episch": [1000, 2500],
}
## A monster with this much life (or more) gets the best odds of each range;
## one with 1 life the worst.
const TOUGH_HP := 30

## The kinds of Enemy.KINDS that count as intelligent besides the skeletons
## and the people (Enemy "human"), who are so anyway: orcs, the trolls (the
## rock troll and the Mountain King, a troll grown huge) and the dragons.
const INTELLIGENT := ["ork", "bergork", "felstroll", "bergkoenig", "drache", "brutdrache", "grosser_alter"]
## The trolls: the rock troll and the Mountain King. They and every other
## creature of the mountains carry raw ore (see ore_find).
const TROLLS := ["felstroll", "bergkoenig"]
## The beasts that swallow what their victims carried (see the top).
const SWALLOWS := ["schleim", "kristallschleim", "glutschleim", "schlund"]
## A slime holds each kind of coin only this often.
const SWALLOWED_COINS := 0.5

## The coins -> the metal their bar is of (see Forge.METALS). Iron and
## silver coins go into the purse (see Crafting.purse); copper coins
## are the hero's money (MONEY, counted in game.coins, see Crafting.have).
## The gold coins of old, now called ancient gold coins, are no more: every
## one is exchanged into a copper coin, one for one (see Game._apply_save).
const COINS := {"eisenmuenze": "eisen", "kupfermuenze": "kupfer", "silbermuenze": "silber", "goldmuenze": "gold"}
## New gold coins (not the ancient ones): only rare foes and finer, that is
## elites, horrors and bosses, of GOLD_FROM_LEVEL and up carry them,
## GOLD_COINS of them (see gold_coins). Their own pouch ingredient is their
## "new" mark: they are never morphed into copper or ancient gold, neither
## when an old save is loaded (that only touches the purse) nor at the bank.
const GOLD_COIN := "goldmuenze"
const GOLD_FROM_LEVEL := 25
const GOLD_COINS := [1, 3]
## The coin that is the hero's money.
const MONEY := "kupfermuenze"
## What a coin is worth in copper coins: 25 copper make a silver coin, 10
## silver a gold coin. The bank changes silver coins into copper at this
## rate (see exchange); gold coins it leaves alone (see GOLD_COIN). Iron coins are small change for the smith:
## they are only melted.
const COIN_VALUE := {"kupfermuenze": 1, "silbermuenze": 25, "goldmuenze": 250}
## The coins the bank changes into copper.
const CHANGED := ["silbermuenze"]
## How many coins of one metal melt into one bar.
const COINS_PER_BAR := 100
## How each coin looks lying on the floor.
const COIN_COLORS := {"eisenmuenze": Color(0.5, 0.5, 0.52), "kupfermuenze": Color(0.8, 0.43, 0.26), "silbermuenze": Color(0.86, 0.88, 0.93), "goldmuenze": Color(1.0, 0.78, 0.25)}

## What a beast leaves, by kind: "food" (common), "biome" (uncommon: one of
## these ingredients of where it lives) and "part" (rare: for a trophy or a
## craft). The ingredients are in Crafting.INGREDIENTS.
const CREATURES := {
	"wolf": {"food": "wildfleisch", "biome": ["baerlauch", "steinpilz"], "part": "wolfsfell"},
	"eiswolf": {"food": "wildfleisch", "biome": ["edelweiss"], "part": "wolfsfell"},
	"spinne": {"food": "spinnenei", "biome": ["steinpilz", "baerlauch"], "part": "giftdruese"},
	"spinnenkoenigin": {"food": "spinnenei", "biome": ["steinpilz", "trueffel"], "part": "giftdruese"},
	"hohle_mutter": {"food": "spinnenei", "biome": ["trueffel"], "part": "giftdruese"},
	"yeti": {"food": "wildfleisch", "biome": ["edelweiss"], "part": "yetifell"},
	"bleicher_waechter": {"food": "wildfleisch", "biome": ["edelweiss"], "part": "yetifell"},
	"fledermaus": {"food": "wildfleisch", "biome": ["hoehlenpilz", "glimmermoos"], "part": "fledermausfluegel"},
	"schleim": {"food": "schleimgelee", "biome": ["hoehlenpilz", "glimmermoos"], "part": "schleimkern"},
	"schlund": {"food": "schleimgelee", "biome": ["glimmermoos", "hoehlenpilz"], "part": "schleimkern"},
	"kristallschleim": {"food": "schleimgelee", "biome": ["grottenkristall"], "part": "schleimkern"},
	"glutschleim": {"food": "schleimgelee", "biome": ["grottenkristall"], "part": "schleimkern"},
	# The ghosts and ghouls of the deep dungeon.
	"totengeist": {"food": "ektoplasma", "biome": ["hoehlenpilz", "glimmermoos"], "part": "geisterschleier"},
	"banshee": {"food": "ektoplasma", "biome": ["glimmermoos", "hoehlenpilz"], "part": "bansheehaar"},
	"ghul": {"food": "grabstaub", "biome": ["hoehlenpilz", "glimmermoos"], "part": "ghulkralle"},
}
## Which part of a beast's table each tier gives (epic finds are gear only).
const CREATURE_TIERS := {"normal": "food", "ungewoehnlich": "biome", "selten": "part"}


## Whether a kind of monster is intelligent (or uses the hero's kind of
## gear): then it carries coins and maybe gear.
static func is_intelligent(kind: String) -> bool:
	var stats: Dictionary = Enemy.KINDS.get(kind, {})
	if stats.has("ghost"):
		return false
	return kind in INTELLIGENT or not stats.get("beast", false)


## Whether a fallen one of this kind may leave coins and gear: the
## intelligent ones, and the slimes with what they swallowed.
static func carries_valuables(kind: String) -> bool:
	return is_intelligent(kind) or kind in SWALLOWS


## How tough a monster is, 0 (1 life) to 1 (TOUGH_HP and more, an elite or a
## boss): where its odds lie in each tier's range.
static func toughness(hp: int, elite := false, boss := false) -> float:
	if elite or boss:
		return 1.0
	return clampf(float(hp - 1) / float(TOUGH_HP - 1), 0.0, 1.0)


## The chance per kill for a find of `tier` (0 for god-born or an unknown tier).
static func chance(tier: String, tough: float) -> float:
	if not ODDS.has(tier):
		return 0.0
	var odds: Array = ODDS[tier]
	return 1.0 / lerpf(float(odds[1]), float(odds[0]), clampf(tough, 0.0, 1.0))


## Rolls the find of one kill: a tier (a key of ODDS), or "" for none.
## `top` is the finest tier this roll can give (TOP_TIER at most). `roll` in
## 0..1, random when left out.
static func roll_tier(tough: float, top := TOP_TIER, roll := -1.0) -> String:
	if roll < 0.0:
		roll = randf()
	var tiers: Array = ODDS.keys()
	var last := mini(tiers.find(top), tiers.find(TOP_TIER))
	var sum := 0.0
	for i in range(last, -1, -1):
		sum += chance(tiers[i], tough)
		if roll < sum:
			return tiers[i]
	return ""


## What a beast of `kind` leaves for a rolled tier: an ingredient id, or ""
## (no find, an epic roll, or a kind without a table).
static func creature_find(kind: String, tier: String, rng: RandomNumberGenerator = null) -> String:
	var table: Dictionary = CREATURES.get(kind, {})
	var key: String = CREATURE_TIERS.get(tier, "")
	if table.is_empty() or key == "":
		return ""
	var what = table[key]
	if what is Array:
		var list: Array = what
		return str(list[(rng.randi() if rng else randi()) % list.size()])
	return str(what)


## The metal coins a fallen one leaves besides its purse (see Level.drop_kill_loot):
## pouch coin -> count. Every intelligent kill leaves iron coins, tougher
## ones copper and silver as well, more often and more of them. A slime
## holds each kind only now and then.
static func coins(kind: String, tough: float, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var out := {}
	if not carries_valuables(kind):
		return out
	var swallowed := not is_intelligent(kind)
	var iron := rng.randi_range(2, 5) + roundi(6.0 * tough)
	if not swallowed or rng.randf() < SWALLOWED_COINS:
		out["eisenmuenze"] = iron
	if rng.randf() < 0.4 + 0.5 * tough and (not swallowed or rng.randf() < SWALLOWED_COINS):
		out["kupfermuenze"] = rng.randi_range(1, 2 + roundi(3.0 * tough))
	if rng.randf() < 0.08 + 0.4 * tough and (not swallowed or rng.randf() < SWALLOWED_COINS):
		out["silbermuenze"] = rng.randi_range(1, 1 + roundi(2.0 * tough))
	return out


## Whether a fallen one of this kind may leave raw ore (see Ore): the trolls
## and every other creature of the mountains.
static func drops_ore(kind: String) -> bool:
	return kind in TROLLS or Enemy.KINDS.get(kind, {}).get("mountain", false)


## The ore a fallen one leaves on a roll of its own (with the same odds per
## tier): a lump of ore of that tier (see Ore.LUMPS; epic is noble ore with
## gems), or "" for none. `top` is the finest tier it can give.
static func ore_find(kind: String, tough: float, roll := -1.0, top := TOP_TIER) -> String:
	if not drops_ore(kind):
		return ""
	return Ore.lump_of_tier(roll_tier(tough, top, roll))


## Limestone for steel (see Forge.STEEL_RECIPE): the trolls and the other
## creatures of the mountains carry a few lumps this often, the trolls more.
const LIMESTONE_CHANCE := 0.5
const LIMESTONE := [1, 2]
const TROLL_LIMESTONE := [2, 4]


## The lumps of limestone a fallen one leaves (0 for none): only those that
## carry ore (see drops_ore), on a roll of its own. `roll` in 0..1, random
## when left out.
static func limestone_find(kind: String, roll := -1.0, rng: RandomNumberGenerator = null) -> int:
	if not drops_ore(kind):
		return 0
	if roll < 0.0:
		roll = rng.randf() if rng else randf()
	if roll >= LIMESTONE_CHANCE:
		return 0
	var span: Array = TROLL_LIMESTONE if kind in TROLLS else LIMESTONE
	return rng.randi_range(span[0], span[1]) if rng else randi_range(span[0], span[1])


## The new gold coins a fallen foe leaves: GOLD_COINS of them from an elite,
## a horror or a boss (`rare`) whose fight is for level GOLD_FROM_LEVEL or
## higher, none from anyone else.
static func gold_coins(rare: bool, fight_level: int, rng: RandomNumberGenerator = null) -> int:
	if not rare or fight_level < GOLD_FROM_LEVEL:
		return 0
	return rng.randi_range(GOLD_COINS[0], GOLD_COINS[1]) if rng else randi_range(GOLD_COINS[0], GOLD_COINS[1])


## Changes all the hero's coins of one kind (see CHANGED) into copper coins,
## the money, at COIN_VALUE. Returns how many copper coins that made.
static func exchange(game: Node, coin: String) -> int:
	if not coin in CHANGED:
		return 0
	var n: int = game.crafting.have(coin)
	game.crafting.take(coin, n)
	game.coins += n * int(COIN_VALUE[coin])
	return n * int(COIN_VALUE[coin])


## Whether an ingredient is one of the coins.
static func is_coin(id: String) -> bool:
	return COINS.has(id)
