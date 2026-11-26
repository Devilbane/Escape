class_name Beekeeper
extends RefCounted
## Imker Ambrosius (map letter ROLE), the beekeeper of the farming valley. He works among the hives of the apiary
## (see Apiary) all day, by the jobs of ValleyFolk, a veil over his straw hat (see BeeVeil), and sells his honey, the
## best in the valley, for copper (see Menus._build_beekeeper).
##
## Honey (HONEY) is an ingredient of the pouch (see Crafting.INGREDIENTS): the first jar teaches the recipe of the
## honey draught (RECIPE), a healing potion brewed from honey alone at the alchemist's table (see HealingPotions).

const ROLE := "β"
const KIND := "imker"
const HONEY := "honig"
const RECIPE := "honigtrank"
## What a jar costs before the village's goodwill takes its share off (see Game.trader_price), and the most one buy takes.
const PRICE := 8
const MOST := 10
## Shown in the compendium with the first jar of honey.
const LEARN := "Honig: Ambrosius, der Imker im Tal, verkauft ihn im Glas. Am Alchemistentisch braust du aus zwei Gläsern einen Heiltrank, so stark, wie dein Können ihn hergibt. Frag ihn nach dem Rezept, oder koste einfach."
## What the window says about the honey.
const NOTE := "Honig vom Apfeltal: goldgelb und dick, aus dem Nektar der Wiesenblumen. Der Imker nimmt nur, was die Bienen entbehren können. Am Alchemistentisch gibt er einem Heiltrank Kraft."


## The copper a jar costs the hero now.
static func price(game: Node) -> int:
	return maxi(1, game.trader_price(PRICE))


## How many jars the hero can buy: what the copper pays for, up to MOST.
static func affordable(game: Node) -> int:
	var each := price(game)
	return mini(game.coins / each, MOST)


## Buys up to `count` jars: as many as the copper pays for. Honey goes into the pouch of ingredients, so the bag never
## fills. The first jar teaches the recipe of the honey draught. Returns how many jars were bought.
static func buy(game: Node, count: int) -> int:
	var each := price(game)
	var bought := 0
	for i in count:
		if game.coins < each:
			break
		game.coins -= each
		bought += 1
	if bought == 0:
		return 0
	game.crafting.add(HONEY, bought, false)
	var learned: Array = game.crafting.learn_from_find(HONEY)
	Events.teach(LEARN)
	if not learned.is_empty():
		var names := learned.map(func(r: String) -> String: return Lang.t(Crafting.RECIPES[r].name))
		game.show_message(Lang.t("Neue Rezepte: %s") % ", ".join(names), 4.0, game.GOLD)
	Events.bus().traded.emit(ROLE)
	return bought
