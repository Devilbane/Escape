class_name Forge
extends RefCounted
## The blacksmith's forge in the village (Gorm the smith):
## - melting down: metal gear (weapons, shields, metal helmets, mail, plate,
##   rings, bracelets and amulets) becomes metal by its kind and rarity (see
##   melt_into; the dragon's hoard melts by the same table, see DragonHoard):
##   weapons and armour iron bars, more for pricier pieces, fine ones a bar
##   of bronze, silver or gold besides; jewellery bars of bronze, silver or
##   gold; magic pieces from rare on a lump of moon silver as well;
## - Gorm buys the bronze, silver and gold bars back for gold;
## - forging: iron bars and some gold become a new piece of metal gear; the
##   thunder weapons also take lumps of thunder ore from the bag (see Items,
##   "thunder"), and their blows may stun (see Enemy.shock);
## - steel: an iron bar, charcoal and limestone make a steel bar (see
##   make_steel), and steel gear ("set": "stahl" in Items.ALL) is forged
##   from steel bars only. Both ask for a level in a craft of the hero's
##   (see STEEL_MAKING and FORGING), which grows by working at the forge;
## - mending: worn armour and shields get their durability back for gold;
## - iron bars can also be bought from the smith;
## - buying: Gorm sells his own fine weapons and a kite shield ("smith" in
##   Items.ALL), which are found nowhere else.
## Iron bars are counted like gold (game.iron), the fine bars beside them
## (game.bars), the moon silver goes into the pouch (see Crafting); none of
## it is carried in the bag, and all of it is kept in the saved game.
## Gold prices drop when Gorm thinks well of the hero (see Reputation): the
## functions that take `game` give the price at the smith's window right now.
## Forging from bought iron costs about what the merchant asks for the piece;
## iron from melted loot makes it cheaper, and you choose what you get.

## What the compendium says about the forge, once the hero has been there.
const LEARN := "Schmied Gorm im Dorf arbeitet an seiner Esse: Er verkauft seine eigenen, besseren Waffen, die es sonst nirgends gibt, schmilzt Waffen, Schilde, Metallrüstungen und Schmuck zu Eisenbarren ein, schmiedet aus Eisen und etwas Kupfer neue Waffen, Schilde und Rüstungen, aus Donnererz vom Gewitter auch Donnerwaffen, deren Treffer Gegner kurz betäuben können, und bessert abgenutzte Rüstungen und Schilde gegen Kupfer aus. Eisenbarren verkauft er auch."
## What the compendium says about steel, once the hero has been at the forge.
## The levels are STEEL_MAKING_LEVEL and STEEL_FORGING_LEVEL.
const STEEL_LEARN := "An Gorms Esse kochst du Stahl: Ein Eisenbarren mit einer Holzkohle und einem Kalkstein wird ein Stahlbarren. Holzkohle verkauft Gorm, Kalkstein tragen Trolle und die Wesen der Berge bei sich. Stahl kochen kannst du ab Stahlkochen Stufe 3; das lernst du beim Einschmelzen von Ausrüstung, Erz und Münzen. Stahlrüstung gibt es nur aus Stahlbarren, und schmieden kannst du sie ab Schmiedekunst Stufe 4, die mit jedem geschmiedeten Stück wächst. Stahlrüstung ist immer selten oder besser."
## What one iron bar costs at the smith.
const IRON_PRICE := 10
## Materials of gear that melts down into iron (see Items, "material").
const MELTS := ["metal", "chain", "mixed"]
## Slots whose pieces are all metal (jewellery), whatever their material says.
const METAL_SLOTS := ["ring", "armreif", "amulett"]
## Gold per point of durability mended, at the least.
const MIN_MEND_PRICE := 2
## The metals gear melts into, in the order they are told: the German name of
## a bar (or lump), a short word for a price line, the colour of the bars,
## and what Gorm pays for one bar ("worth"). Iron and moon silver are not
## bought back: they are worth more forged (see forge) and in recipes.
const METALS := {
	"eisen": {"name": "Eisenbarren", "short": "Eisen", "color": Color(0.55, 0.57, 0.6)},
	"stahl": {"name": "Stahlbarren", "short": "Stahl", "color": Color(0.72, 0.8, 0.9)},
	"kupfer": {"name": "Kupferbarren", "short": "Kupfer", "color": Color(0.85, 0.48, 0.28)},
	"bronze": {"name": "Bronzebarren", "short": "Bronze", "color": Color(0.8, 0.5, 0.25), "worth": 150},
	"silber": {"name": "Silberbarren", "short": "Silber", "color": Color(0.85, 0.87, 0.92), "worth": 2500},
	"gold": {"name": "Goldbarren", "short": "Goldbarren", "color": Color(1.0, 0.8, 0.3), "worth": 25000},
	"mondsilbererz": {"name": "Mondsilbererz", "short": "Mondsilber", "color": Color(0.6, 0.75, 1.0)},
}
## What one gram of a fine metal is worth in copper coins, from the exchange
## rates: a coin weighs 10 g (see Ore.COIN_GRAMS), 25 copper coins make a
## silver coin and 10 silver coins a gold coin, so a gram of copper is worth
## 0.1, of silver 2.5 and of gold 25 copper coins; bronze, mostly copper,
## a little more than copper. A bar (Ore.GRAMS_PER_BAR) is worth a
## thousand grams: METALS "worth".
const GRAM_VALUE := {"kupfer": 0.1, "bronze": 0.15, "silber": 2.5, "gold": 25.0}
## A key in a melting table (see melt_into) for grams of a fine metal rather
## than bars: GRAMS + metal, e.g. "g:silber".
const GRAMS := "g:"
## The bars kept in game.bars besides the iron: the fine ones (copper bars
## come from melted coins and ore, see melt_coins) and steel (see
## make_steel). Gorm buys back those with a "worth"; a copper bar is a
## hundred of the coins the hero pays with, and steel is worth more forged,
## so neither is sold.
const FINE := ["kupfer", "bronze", "silber", "gold", "stahl"]
## The fine metal of a piece by its rarity (see rarity, common to god-born):
## jewellery is made of it, and fine weapons and armour have fittings of it
## besides their iron.
const PRECIOUS := ["bronze", "bronze", "silber", "gold", "gold"]
const FITTINGS := ["", "", "bronze", "silber", "gold"]
## Magic pieces from this rarity on leave a lump of moon silver.
const MOON_FROM := 2

## Steel. A steel bar is an iron bar, burnt with charcoal for its carbon and
## limestone as a flux to take the slag away (STEEL_RECIPE). Gorm sells the
## charcoal (CHARCOAL_PRICE); the limestone the trolls and the creatures of
## the mountains carry (see Loot.limestone_find). Steel gear is always rare
## or finer (see Items.RARITY).
const STEEL := "stahl"
const CHARCOAL := "holzkohle"
const LIMESTONE := "kalkstein"
const STEEL_RECIPE := {"eisen": 1, "holzkohle": 1, "kalkstein": 1}
const CHARCOAL_PRICE := 2
## The hero's two crafts at the forge (Training.CRAFTS): Schmiedekunst
## (forging) grows with every piece forged, Stahlkochen (steel making) with
## every piece, lump of ore or heap of coins melted and every steel bar made.
## Making steel bars needs STEEL_MAKING_LEVEL, forging steel gear
## STEEL_FORGING_LEVEL.
const FORGING := "schmiedekunst"
const STEEL_MAKING := "stahlkochen"
const STEEL_MAKING_LEVEL := 3
const STEEL_FORGING_LEVEL := 4
## Training for each piece forged, each melt and each steel bar made.
const FORGE_XP := 10.0
const MELT_XP := 4.0
const STEEL_XP := 6.0


## The slots of metal gear priced by the iron in it (see armour_iron):
## armour, gloves and shoes for the iron and steel sets, and the weapons.
const ARMOUR_SLOTS := ["schild", "kopf", "ruestung", "handschuhe", "schuhe", "waffe"]


## Whether a piece is steel gear: forged from steel bars, melted into them.
static func is_steel(id: String) -> bool:
	return Items.ALL.has(id) and str(Items.ALL[id].get("set", "")) == "stahl"


## The hero's level in one of the forge's crafts (FORGING, STEEL_MAKING).
static func craft_level(game: Node, craft: String) -> int:
	if game == null or game.player == null:
		return 0
	return Training.skill_level(float(game.player.xp.get(craft, 0.0)), craft)


## Why the hero cannot make a steel bar right now, or "".
static func why_no_steel(game: Node) -> String:
	if craft_level(game, STEEL_MAKING) < STEEL_MAKING_LEVEL:
		return Lang.t("Für Stahl brauchst du Stahlkochen Stufe %d.") % STEEL_MAKING_LEVEL
	var missing := []
	for ingredient in STEEL_RECIPE:
		var short: int = int(STEEL_RECIPE[ingredient]) - int(game.crafting.have(ingredient))
		if short > 0:
			missing.append("%d %s" % [short, Crafting.ingredient_name(ingredient)])
	if not missing.is_empty():
		return Lang.t("Es fehlt: %s") % ", ".join(missing)
	return ""


## Makes one steel bar from STEEL_RECIPE and trains steel making. Returns ""
## on success, else why not.
static func make_steel(game: Node) -> String:
	var why := why_no_steel(game)
	if why != "":
		return why
	for ingredient in STEEL_RECIPE:
		if ingredient == "eisen":
			game.iron -= int(STEEL_RECIPE[ingredient])
		else:
			game.crafting.take(ingredient, int(STEEL_RECIPE[ingredient]))
	store(game, {STEEL: 1})
	game.player.train(STEEL_MAKING, STEEL_XP, false)
	return ""


## Buys charcoal into the pouch. Returns "" on success, else why not.
static func buy_charcoal(game: Node, count: int) -> String:
	var price := charcoal_price(game)
	if count <= 0 or game.coins < price * count:
		return Lang.t("Dafür reicht dein Kupfer nicht.")
	game.coins -= price * count
	game.crafting.add(CHARCOAL, count, false)
	return ""


## What one piece of charcoal costs the hero.
static func charcoal_price(game: Node = null) -> int:
	return _discounted(game, CHARCOAL_PRICE)


## The iron bars in a piece of metal gear (a weapon, a shield, a helmet,
## mail or plate): one bar per kilo it weighs, as a bar is a kilo of metal (see Ore)
## or a hundred coins. 0 for anything else. Its worth (Items.ALL "price") is
## that iron at IRON_PRICE a bar plus the smith's work.
static func armour_iron(id: String) -> int:
	if not Items.ALL.has(id):
		return 0
	var item: Dictionary = Items.ALL[id]
	if not str(item.slot) in ARMOUR_SLOTS or not str(item.get("material", "")) in MELTS:
		return 0
	return maxi(1, roundi(float(item.get("weight", 1))))


## Whether the smith can melt an item down.
static func can_melt(id: String) -> bool:
	if not Items.ALL.has(id):
		return false
	var item: Dictionary = Items.ALL[id]
	return item.get("material", "") in MELTS or item.slot in METAL_SLOTS


## Iron bars an item melts down into.
static func melt_yield(id: String) -> int:
	return int(melt_into(id).get("eisen", 0))


## How rare a piece is, 0 (common) to 4 (god-born) (see Items.RARITY).
static func rarity(id: String) -> int:
	return Level.rank_of(id)


## Whether a piece is jewellery or a charm rather than a weapon or armour.
static func _is_trinket(id: String) -> bool:
	return str(Items.ALL[id].slot) in METAL_SLOTS or str(Items.ALL[id].slot) == "spezial"


## The one melting table, for the smith and the dragon alike: what a piece
## melts into, metal (see METALS) -> count. Empty for what does not melt.
## - weapons, shields and metal armour: iron bars (a bar per kilo of
##   armour, one for every 8 coins of a weapon's price), and from rare on
##   grams of the fine metal of their fittings, worth a quarter of its price;
## - jewellery: grams of the fine metal of its rarity, worth half its price
##   (see GRAM_VALUE; a gram at the least);
## - magic pieces from rare on: a lump of moon silver as well.
## `any`: the dragon's fire melts more than Gorm's forge; a piece that is no
## metal (a bone helmet, a charm) gives fine metal like jewellery. Grams are
## keyed GRAMS + metal.
static func melt_into(id: String, any := false) -> Dictionary:
	var out := {}
	if not Items.ALL.has(id) or not (can_melt(id) or any):
		return out
	var item: Dictionary = Items.ALL[id]
	var r := rarity(id)
	if can_melt(id) and not _is_trinket(id):
		# Metal armour gives back its iron, a bar per kilo; weapons one bar
		# for every 8 gold of their price.
		# Steel gear gives back steel bars.
		out[STEEL if is_steel(id) else "eisen"] = armour_iron(id) if armour_iron(id) > 0 else maxi(1, roundi(int(item.price) / 8.0))
		if FITTINGS[r] != "" and str(item.slot) in Items.SLOTS:
			out[GRAMS + FITTINGS[r]] = grams_worth(FITTINGS[r], int(item.price) / 4.0)
	else:
		var metal: String = PRECIOUS[r]
		out[GRAMS + metal] = grams_worth(metal, int(item.price) / 2.0)
	if item.get("magic", false) and r >= MOON_FROM:
		out["mondsilbererz"] = 1
	return out


## How many grams of a fine metal are worth `copper` copper coins (one at
## the least).
static func grams_worth(metal: String, copper: float) -> int:
	return maxi(1, roundi(copper / float(GRAM_VALUE.get(metal, 1.0))))


## Whether a key of a melting table names a metal: bars of one of METALS, or
## grams of one (GRAMS + metal).
static func is_metal_key(key: String) -> bool:
	return METALS.has(key) or (key.begins_with(GRAMS) and METALS.has(key.substr(GRAMS.length())))


## Metals in METALS order as a list of words: "2× Eisenbarren, 40 g Silber"
## (translated), or short for a price line: "+2 Eisen, +40 g Silber".
static func metals_text(bars: Dictionary, short := false) -> String:
	var parts := []
	for metal in METALS:
		var n := int(bars.get(metal, 0))
		if n > 0:
			parts.append(("+%d %s" if short else "%d× %s") % [n, Lang.t(METALS[metal].short if short else METALS[metal].name)])
		var g := int(bars.get(GRAMS + metal, 0))
		if g > 0:
			parts.append(("+%d g %s" if short else "%d g %s") % [g, Lang.t(METALS[metal].short)])
	return ", ".join(parts)


## Adds grams of a metal to game.metal_grams; every Ore.GRAMS_PER_BAR grams
## of one with bars (not the unknown metal) become a bar of it. Returns the
## new bars, metal -> count.
static func add_grams(game: Node, grams: Dictionary) -> Dictionary:
	var bars := {}
	for metal in grams:
		var total := int(game.metal_grams.get(metal, 0)) + int(grams[metal])
		if metal != Ore.UNKNOWN and total >= Ore.GRAMS_PER_BAR:
			bars[metal] = total / Ore.GRAMS_PER_BAR
			total %= Ore.GRAMS_PER_BAR
		game.metal_grams[metal] = total
	store(game, bars)
	return bars


## Puts metal into the hero's stores: iron bars, fine bars, moon silver into
## the pouch.
static func store(game: Node, bars: Dictionary) -> void:
	for metal in bars:
		var n := int(bars[metal])
		if n <= 0:
			continue
		if str(metal).begins_with(GRAMS):
			add_grams(game, {str(metal).substr(GRAMS.length()): n})
			continue
		match metal:
			"eisen":
				game.iron += n
			"mondsilbererz":
				game.crafting.add("mondsilbererz", n, false)
			_:
				if metal in FINE:
					game.bars[metal] = int(game.bars.get(metal, 0)) + n


## Sells the hero's fine bars of one metal to Gorm (`count` of them, all
## when -1). Returns "" on success, else why not.
static func sell_bars(game: Node, metal: String, count := -1) -> String:
	var have := int(game.bars.get(metal, 0))
	if not metal in FINE or not METALS[metal].has("worth") or have <= 0:
		return Lang.t("Davon hast du keine Barren.")
	var n := have if count < 0 else mini(count, have)
	game.bars[metal] = have - n
	if int(game.bars[metal]) <= 0:
		game.bars.erase(metal)
	game.coins += n * int(METALS[metal].worth)
	return ""


## Melts COINS_PER_BAR coins of one metal from the purse (see Loot.COINS)
## into one bar of it: iron coins into an iron bar, copper and silver coins
## into fine bars. Returns "" on success, else why not.
static func melt_coins(game: Node, coin: String) -> String:
	if not Loot.is_coin(coin):
		return Lang.t("Das schmilzt Gorm nicht ein.")
	if game.crafting.have(coin) < Loot.COINS_PER_BAR:
		return Lang.t("Für einen Barren braucht Gorm %d Münzen.") % Loot.COINS_PER_BAR
	game.crafting.take(coin, Loot.COINS_PER_BAR)
	store(game, {Loot.COINS[coin]: 1})
	game.player.train(STEEL_MAKING, MELT_XP, false)
	return ""


## Melts the oldest lump of ore of size `id` (see Ore): only now, in the
## fire, is it rolled what the lump holds (Ore.makeup), so the yield cannot
## be foreseen. Its metal goes into game.metal_grams gram by gram, the slag
## is thrown away, and every Ore.GRAMS_PER_BAR grams of iron, copper, silver
## or gold become a bar of it (the unknown metal stays in grams); the uncut
## gems in noble ore go into the purse. Returns {"why": "" on success, else
## why not; "share": part -> percent it held; "grams": metal -> grams it
## gave; "slag": grams of slag thrown away; "bars": metal -> new bars;
## "gems": their carats}.
static func melt_ore(game: Node, id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var lumps: Array = game.crafting.ores.get(id, [])
	if not Ore.is_ore(id) or lumps.is_empty():
		return {"why": Lang.t("Davon hast du kein Erz."), "share": {}, "grams": {}, "slag": 0, "bars": {}, "gems": []}
	var inside := Ore.makeup(id, rng)
	var weight := int(lumps[0].get("grams", 0))
	var grams := Ore.metal_grams(weight, inside.share)
	var gems: Array = inside.gems
	game.crafting.take(id, 1)
	for carat in gems:
		game.crafting.add_gem(Ore.UNCUT, int(carat))
	var bars := add_grams(game, grams)
	game.player.train(STEEL_MAKING, MELT_XP, false)
	return {"why": "", "share": inside.share, "grams": grams, "slag": Ore.slag_grams(weight, inside.share), "bars": bars, "gems": gems}


## Cuts the hero's oldest uncut gem: it loses 15-50 % of its weight (see
## Ore.cut_weight) and becomes a cut gem. Returns {"why", "from", "to"}
## (carat before and after).
static func cut_gem(game: Node) -> Dictionary:
	var uncut: Array = game.crafting.gems.get(Ore.UNCUT, [])
	if uncut.is_empty():
		return {"why": Lang.t("Du hast keinen ungeschliffenen Edelstein."), "from": 0, "to": 0}
	var from := int(uncut[0])
	var to := Ore.cut_weight(from)
	game.crafting.take(Ore.UNCUT, 1)
	game.crafting.add_gem(Ore.CUT, to)
	return {"why": "", "from": from, "to": to}


## Sells the hero's oldest cut gem to Gorm (see Ore.gem_worth). Returns ""
## on success, else why not.
static func sell_gem(game: Node) -> String:
	var cut: Array = game.crafting.gems.get(Ore.CUT, [])
	if cut.is_empty():
		return Lang.t("Du hast keinen geschliffenen Edelstein.")
	game.coins += Ore.gem_worth(int(cut[0]))
	game.crafting.take(Ore.CUT, 1)
	return ""


## What the thunder weapons are forged from besides iron and gold.
const THUNDER_ORE := "donnererz"


## Every piece the smith can forge: the metal weapons, shields and armour,
## and the thunder weapons.
static func recipes() -> Array:
	var ids := []
	for id in Items.ALL:
		var item: Dictionary = Items.ALL[id]
		if item.get("material", "") in MELTS and (not item.get("no_loot", false) or item.has("thunder")):
			ids.append(id)
	ids.sort_custom(func(a, b): return Items.ALL[a].price < Items.ALL[b].price)
	return ids


## Gorm's own wares, cheapest first: only the smith sells them. The top tier
## of each kind (the war hammer, the kite shield) he only forges, from the
## hero's iron (see Items.merchant_sells).
static func wares() -> Array:
	var ids := Items.ALL.keys().filter(func(id): return Items.ALL[id].get("smith", false) and Items.merchant_sells(id))
	ids.sort_custom(func(a, b): return Items.ALL[a].price < Items.ALL[b].price)
	return ids


## A gold price after the discount at the smith's window (unchanged without
## a game, or when the window was not opened at Gorm).
static func _discounted(game: Node, gold: int) -> int:
	return game.trader_price(gold) if game else gold


## What one of Gorm's wares costs the hero.
static func ware_price(game: Node, id: String) -> int:
	return _discounted(game, Items.buy_price(id))


## What one iron bar costs the hero.
static func iron_price(game: Node = null) -> int:
	return _discounted(game, IRON_PRICE)


## Buys one of Gorm's wares into the bag. Returns "" on success, else why not.
static func buy(game: Node, id: String) -> String:
	var p: Player = game.player
	if not wares().has(id):
		return Lang.t("Das verkauft Gorm nicht.")
	var price := ware_price(game, id)
	if game.coins < price:
		return Lang.t("Dafür reicht dein Kupfer nicht.")
	if p.bag_used() >= p.bag_size():
		return Lang.t("Deine Tasche ist voll.")
	game.coins -= price
	p.bag.append(id)
	return ""


## What forging a piece costs: {"iron": bars, "steel": steel bars (0 but for
## steel gear, which takes them in place of iron), "gold": coins, "ore": lumps
## of thunder ore from the bag (0 but for the thunder weapons)}: one iron bar
## for every 4 gold of the piece's worth and half its worth in gold, so that
## from bought iron it costs about what a merchant asks (Items.buy_price).
## Metal armour takes its own iron instead (see armour_iron) and the rest of
## its worth in gold for the work.
static func forge_cost(id: String, game: Node = null) -> Dictionary:
	var price: int = Items.ALL[id].price
	var ore := int(Items.ALL[id].get("thunder", 0))
	var iron := armour_iron(id)
	if iron > 0:
		# Metal armour: its iron, a bar per kilo, and gold for the work; steel
		# gear the same in steel bars.
		var gold := _discounted(game, maxi(1, price - iron * IRON_PRICE))
		if is_steel(id):
			return {"iron": 0, "steel": iron, "gold": gold, "ore": ore}
		return {"iron": iron, "steel": 0, "gold": gold, "ore": ore}
	var bars := ceili(price / 4.0)
	if is_steel(id):
		return {"iron": 0, "steel": bars, "gold": _discounted(game, price / 2), "ore": ore}
	return {"iron": bars, "steel": 0, "gold": _discounted(game, price / 2), "ore": ore}


## The Schmiedekunst level forging a piece needs: STEEL_FORGING_LEVEL for
## steel gear, none for the rest.
static func forge_level(id: String) -> int:
	return STEEL_FORGING_LEVEL if is_steel(id) else 0


## Whether the hero has everything forging a piece takes (room in the bag
## aside).
static func can_afford(game: Node, id: String) -> bool:
	var cost := forge_cost(id, game)
	return game.iron >= cost.iron and int(game.bars.get(STEEL, 0)) >= cost.steel and game.coins >= cost.gold \
			and game.player.bag.count(THUNDER_ORE) >= cost.ore and craft_level(game, FORGING) >= forge_level(id)



## Gold for mending one point of durability of a piece.
static func mend_price(id: String, game: Node = null) -> int:
	return _discounted(game, maxi(MIN_MEND_PRICE, int(Items.ALL[id].price) / 10))


## Every worn-down piece the hero has, worn first, then in the bag, each once.
static func worn_down(p: Player) -> Array:
	var ids := []
	var order: Array = p.equipped.values()
	order.append_array(p.bag)
	for id in order:
		if int(p.wear.get(id, 0)) > 0 and not ids.has(id):
			ids.append(id)
	return ids


## Gold to mend a piece completely.
static func mend_cost(p: Player, id: String, game: Node = null) -> int:
	return int(p.wear.get(id, 0)) * mend_price(id, game)


## Melts the bag item at `index` down. Returns "" on success, else why not.
static func melt(game: Node, index: int) -> String:
	var p: Player = game.player
	if index < 0 or index >= p.bag.size():
		return Lang.t("Da ist nichts.")
	var id: String = p.bag[index]
	if not can_melt(id):
		return Lang.t("%s lässt sich nicht einschmelzen.") % Items.item_name(id)
	p.bag.remove_at(index)
	if not p.bag.has(id) and not p.equipped.values().has(id):
		p.wear.erase(id)
	store(game, melt_into(id))
	game.player.train(STEEL_MAKING, MELT_XP, false)
	return ""


## Forges a new piece into the bag. Returns "" on success, else why not.
static func forge(game: Node, id: String) -> String:
	var p: Player = game.player
	var cost := forge_cost(id, game)
	if craft_level(game, FORGING) < forge_level(id):
		return Lang.t("Für Stahl brauchst du Schmiedekunst Stufe %d.") % forge_level(id)
	if game.iron < cost.iron:
		return Lang.t("Dafür hast du zu wenig Eisen.")
	if int(game.bars.get(STEEL, 0)) < cost.steel:
		return Lang.t("Dafür hast du zu wenig Stahl.")
	if game.coins < cost.gold:
		return Lang.t("Dafür reicht dein Kupfer nicht.")
	if p.bag.count(THUNDER_ORE) < cost.ore:
		return Lang.t("Dafür hast du zu wenig Donnererz. Es glimmt nur bei Gewitter neben den Felsen.")
	for _i in cost.ore:
		p.bag.erase(THUNDER_ORE)
	if not p.bag_fits(id):
		# The ore went in vain: put it back.
		for _i in cost.ore:
			p.bag.append(THUNDER_ORE)
		return Lang.t("Deine Tasche ist voll.")
	game.iron -= cost.iron
	if cost.steel > 0:
		game.bars[STEEL] = int(game.bars[STEEL]) - cost.steel
		if int(game.bars[STEEL]) <= 0:
			game.bars.erase(STEEL)
	game.coins -= cost.gold
	p.bag.append(id)
	p.train(FORGING, FORGE_XP, false)
	return ""


## Mends a piece as far as the gold goes. Returns "" on success, else why not.
static func mend(game: Node, id: String) -> String:
	var p: Player = game.player
	if int(p.wear.get(id, 0)) <= 0:
		return Lang.t("%s ist wie neu.") % Items.item_name(id)
	var price := mend_price(id, game)
	if game.coins < price:
		return Lang.t("Dafür reicht dein Kupfer nicht.")
	while int(p.wear.get(id, 0)) > 0 and game.coins >= price:
		p.wear[id] = int(p.wear[id]) - 1
		game.coins -= price
	if int(p.wear[id]) <= 0:
		p.wear.erase(id)
	return ""


## Buys iron bars. Returns "" on success, else why not.
static func buy_iron(game: Node, count: int) -> String:
	var price := iron_price(game)
	if count <= 0 or game.coins < price * count:
		return Lang.t("Dafür reicht dein Kupfer nicht.")
	game.coins -= price * count
	game.iron += count
	return ""
