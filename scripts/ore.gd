class_name Ore
extends RefCounted
## Raw ore, the loot of trolls and the other beasts of the mountains (see
## Loot.ore_find): a lump of rock with metal in it that Gorm melts down at
## his forge (see Forge.melt_ore).
##
## Each lump has its own weight and its own make-up, rolled when the hero
## picks it up and kept with it in the pouch (Crafting.ores). The share of
## each part is rolled in this order, each from what is still left of the
## hundred: slag 25-60 %, iron 10-40 %, copper 5-40 %, silver 1-15 %, gold
## 1-5 %; whatever is left over is an unknown metal with a light blue glow.
## Melted, a lump gives as many grams of each metal as it holds; the slag is
## thrown away. Every GRAMS_PER_BAR grams of one metal make one bar of it,
## and what is left waits for the next lump (game.metal_grams). One coin
## weighs COIN_GRAMS, so a hundred coins make one bar, as at the forge.
##
## How heavy a lump is sets its rarity: small lumps of 500 to 999 g are
## common, lumps of 1 to 2 kg uncommon, big ones of 2.5 to 5 kg rare. Epic
## lumps are noble ore: 10-20 % slag, 5-15 % iron, 5-15 % copper, 10-20 %
## silver, 20-30 % gold, the rest the unknown metal, and one to five uncut
## gems inside. A gem's weight in carat sets its rarity (CARATS: 2-4 common,
## 5-11 uncommon, 12-18 rare, 19-22 epic, 23-24 god-born). Gorm cuts them
## (Forge.cut_gem), which grinds off 15-50 % of the weight, and buys the cut
## ones (Forge.sell_gem).

## The three sizes of lump: pouch ingredient (see Crafting.INGREDIENTS) ->
## its rarity tier and its weight range in grams.
const LUMPS := {
	"erzbrocken_klein": {"tier": "normal", "grams": [500, 999]},
	"erzbrocken": {"tier": "ungewoehnlich", "grams": [1000, 2000]},
	"erzbrocken_gross": {"tier": "selten", "grams": [2500, 5000]},
	"erzbrocken_episch": {"tier": "episch", "grams": [2500, 5000], "noble": true},
}
## The parts of a lump in the order they are rolled, with their share in
## percent [least, most]. "schlacke" is the slag; "unbekannt" the unknown
## metal takes what is left.
const PARTS := [["schlacke", 25, 60], ["eisen", 10, 40], ["kupfer", 5, 40], ["silber", 1, 15], ["gold", 1, 5]]
## Noble ore (the epic lumps): little slag, rich in silver and gold, and
## NOBLE_GEMS uncut gems inside.
const NOBLE_PARTS := [["schlacke", 10, 20], ["eisen", 5, 15], ["kupfer", 5, 15], ["silber", 10, 20], ["gold", 20, 30]]
const NOBLE_GEMS := [1, 5]

## The gems (pouch ingredients): uncut from noble ore, cut by Gorm. Each
## has its own weight in carat (Crafting.gems).
const UNCUT := "rohedelstein"
const CUT := "edelstein"
const GEMS := [UNCUT, CUT]
## A gem's rarity by its weight: tier -> [least, most] carat.
const CARATS := {
	"normal": [2, 4],
	"ungewoehnlich": [5, 11],
	"selten": [12, 18],
	"episch": [19, 22],
	"gottgeboren": [23, 24],
}
## How likely a gem of each tier is, relative to each other: as rare as the
## loot of that tier (see Loot.ODDS), god-born rarer still.
const CARAT_WEIGHTS := {"normal": 1.0 / 20, "ungewoehnlich": 1.0 / 80, "selten": 1.0 / 320, "episch": 1.0 / 1000, "gottgeboren": 1.0 / 5000}
## Cutting takes off this share of a gem's weight [least, most].
const CUT_LOSS := [0.15, 0.5]
## Gold Gorm pays for a cut gem, per carat, by its tier (common to god-born).
const GEM_GOLD_PER_CARAT := [1, 2, 3, 5, 8]
const SLAG := "schlacke"
const UNKNOWN := "unbekannt"
## The metals a lump holds, in the order they are told, with their German
## names (translated with Lang.t) and colours.
const METALS := {
	"eisen": {"name": "Eisen", "color": Color(0.6, 0.62, 0.66)},
	"kupfer": {"name": "Kupfer", "color": Color(0.85, 0.48, 0.28)},
	"silber": {"name": "Silber", "color": Color(0.88, 0.9, 0.95)},
	"bronze": {"name": "Bronze", "color": Color(0.8, 0.5, 0.25)},
	"gold": {"name": "Gold", "color": Color(1.0, 0.8, 0.3)},
	UNKNOWN: {"name": "Unbekanntes Metall", "color": Color(0.5, 0.85, 1.0)},
}
## Grams of one metal in one bar.
const GRAMS_PER_BAR := 1000
## What one coin weighs, of any metal.
const COIN_GRAMS := 10
## The colour of a lump lying on the ground: dark rock.
const ROCK := Color(0.42, 0.38, 0.36)


static func is_ore(id: String) -> bool:
	return LUMPS.has(id)


## The size of lump of a rarity tier ("" for epic or none).
static func lump_of_tier(tier: String) -> String:
	for id in LUMPS:
		if LUMPS[id].tier == tier:
			return id
	return ""


## Rolls one lump of the size `id`: {"grams": weight, "share": part ->
## percent}, the shares summing to 100.
static func roll(id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var range_g: Array = LUMPS.get(id, LUMPS["erzbrocken_klein"]).grams
	var noble: bool = LUMPS.get(id, {}).get("noble", false)
	var share := {}
	var left := 100
	for part in (NOBLE_PARTS if noble else PARTS):
		var pct := mini(rng.randi_range(int(part[1]), int(part[2])), left)
		share[part[0]] = pct
		left -= pct
	share[UNKNOWN] = left
	var gems := []
	if noble:
		for i in rng.randi_range(NOBLE_GEMS[0], NOBLE_GEMS[1]):
			gems.append(roll_carat(rng))
	return {"grams": rng.randi_range(int(range_g[0]), int(range_g[1])), "share": share, "gems": gems}


## The weight of a new uncut gem in carat: its tier rolled by CARAT_WEIGHTS,
## then a weight in that tier's range.
static func roll_carat(rng: RandomNumberGenerator = null) -> int:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var total := 0.0
	for tier in CARAT_WEIGHTS:
		total += CARAT_WEIGHTS[tier]
	var roll := rng.randf() * total
	var pick := "normal"
	for tier in CARAT_WEIGHTS:
		roll -= CARAT_WEIGHTS[tier]
		if roll <= 0.0:
			pick = tier
			break
	return rng.randi_range(int(CARATS[pick][0]), int(CARATS[pick][1]))


## A gem's rarity tier by its weight (anything under 2 carat is common).
static func gem_tier(carat: int) -> String:
	var out := "normal"
	for tier in CARATS:
		if carat >= int(CARATS[tier][0]):
			out = tier
	return out


## A gem's weight after cutting: 15 to 50 % of it is ground away (1 carat
## at the least is left).
static func cut_weight(carat: int, rng: RandomNumberGenerator = null) -> int:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return maxi(1, roundi(carat * (1.0 - rng.randf_range(CUT_LOSS[0], CUT_LOSS[1]))))


## What Gorm pays for a cut gem.
static func gem_worth(carat: int) -> int:
	return carat * GEM_GOLD_PER_CARAT[Level.tier_rank(gem_tier(carat))]


## The grams of each metal a lump gives when melted (no slag): metal ->
## grams, only the metals it holds.
static func metal_grams(lump: Dictionary) -> Dictionary:
	var out := {}
	var grams := int(lump.get("grams", 0))
	var share: Dictionary = lump.get("share", {})
	for metal in METALS:
		var g := floori(grams * int(share.get(metal, 0)) / 100.0)
		if g > 0:
			out[metal] = g
	return out


## A lump's make-up in words: "1840 g: 41 % slag, 22 % iron, ..." (translated).
static func describe(lump: Dictionary) -> String:
	var share: Dictionary = lump.get("share", {})
	var parts := ["%d %% %s" % [int(share.get(SLAG, 0)), Lang.t("Schlacke")]]
	for metal in METALS:
		if int(share.get(metal, 0)) > 0:
			parts.append("%d %% %s" % [int(share[metal]), Lang.t(METALS[metal].name)])
	var gems: Array = lump.get("gems", [])
	if not gems.is_empty():
		parts.append(Lang.t("%d ungeschliffene Edelsteine") % gems.size() if gems.size() > 1 else Lang.t("1 ungeschliffener Edelstein"))
	return "%d g: %s" % [int(lump.get("grams", 0)), ", ".join(parts)]


## Grams per metal in words: "412 g Eisen, 96 g Kupfer" (translated).
static func grams_text(grams: Dictionary) -> String:
	var parts := []
	for metal in METALS:
		if int(grams.get(metal, 0)) > 0:
			parts.append("%d g %s" % [int(grams[metal]), Lang.t(METALS[metal].name)])
	return ", ".join(parts) if not parts.is_empty() else Lang.t("nichts")
