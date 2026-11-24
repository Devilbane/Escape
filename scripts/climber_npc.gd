class_name ClimberNpc
extends RefCounted
## Kletterer Wolfram, the rock climber on the mountainside east of the stream (map letter ROLE).
## He climbs the face at SPOT_CELL all day, under the rules of ClimbSpots and RockClimb but without a slip
## (see ClimberRoute): up with nails and rope, a rest at the top with the view, down again taking
## everything out. Anyone who watches him for WATCH_HOURS of game time gets a rough idea of climbing: the
## Klettern skill becomes ripe, so one night's sleep makes it level 1 (see SleepRoll).
##
## He also sells climbing gear, dearer than Mira and in small numbers (see WARES, restocked every
## RESTOCK_DAYS days), and answers to the words in NpcKeywords. All of it is one window (see build).

const ROLE := "κ"
const KIND := "kletterer"
## The rock tile he climbs: the spot the hero can climb too, at the level its row in ClimbSpots asks for.
const SPOT_CELL := Vector2i(55, 57)

## What he asks in times Mira's price, what he has (id -> how many) and how many days he takes to get more.
const MARKUP := 2.0
const WARES := {"kletterhammer": 1, "kletterseil": 1, "kletterhelm": 1, "kletterschuhe": 1, "kletterhandschuhe": 1, "kletterhaken": 4}
const RESTOCK_DAYS := 3

## How near the hero must be to watch him, and for how many hours of game time.
const WATCH_RANGE := 20.0
const WATCH_HOURS := 1.0

## The compendium entry of the hero's rough idea of climbing (it also stands for "has watched him long enough").
const WATCHED := "Klettern: Du hast Wolfram lange genug beobachtet, um zu wissen, wie es geht: erst drei Züge, dann ein Nagel mit Seil, danach alle zwei Züge. Eine Nacht darüber schlafen, dann klappt es."
## What the hero is told at that moment.
const WATCHED_TELL := "Du hast eine ungefähre Vorstellung vom Klettern. Besser, du schläfst erst darüber, bevor du es selbst versuchst."
## The window's note when he has nothing left of a kind of ware.
const SOLD_OUT := "Ausverkauft: Wolfram hat nur wenig dabei."

## What he tells, one at a time (a different one each day).
const TALK := [
	"Die Wand am Bach ist mein Hausberg. Die anderen Wände musst du suchen, und sie sind höher.",
	"Drei Griffe, dann ein Nagel mit Seil. Danach alle zwei Griffe wieder. So bleibt man heil.",
	"Rutschst du ab, hängst du im letzten Nagel. Ohne Nagel hängst du nirgends.",
	"Nach einem Fehlgriff darfst du es gleich noch einmal versuchen. Danach: Atem holen.",
	"Dreimal ins Seil gefallen? Dann klettere hinunter. Der Berg läuft nicht weg.",
	"Helm, Schuhe, Handschuhe, Hammer und Seil: Wer alles trägt, klettert besser als die Summe der Teile.",
	"Sieh mir eine Stunde lang zu. Mehr als ich dir erzählen kann, siehst du an der Wand.",
]


## The restocked wares of the game: how many of each he has left.
static func wares(game: Node) -> Dictionary:
	if game.climber_day < 0 or game.day >= game.climber_day + RESTOCK_DAYS:
		game.climber_day = game.day
		game.climber_stock = WARES.duplicate()
	return game.climber_stock


## What he asks for a ware.
static func price(id: String) -> int:
	return maxi(1, roundi(Items.buy_price(id) * MARKUP))


## The line he tells today.
static func talk(game: Node) -> String:
	return Lang.t(TALK[posmod(game.day, TALK.size())])


## The hero watches him for `hours` of game time: after WATCH_HOURS the climbing skill is ripe.
static func watched(game: Node, hours: float) -> void:
	if game.lore.has(WATCHED):
		return
	game.climber_watch += hours
	if game.climber_watch < WATCH_HOURS:
		return
	game.climber_watch = 0.0
	Events.teach(WATCHED)
	game.player.train("klettern", Training.skill_xp_for(1))
	Events.tell(Lang.t(WATCHED_TELL), Color(0.8, 0.85, 1.0))


## Called by the climber on every physics tick: the hero in range, alive, looking on makes the hours count.
static func watch_tick(v: Villager, delta: float) -> void:
	var hero: Player = v.level.player if v.level != null else null
	if hero == null or hero.dead or hero.global_position.distance_to(v.global_position) > WATCH_RANGE:
		return
	Events.bus().climber_watched.emit(delta * 24.0 / DayNight.DAY_LENGTH)


## The window: his line for the day, his wares and what the hero can do to learn from him.
static func build(menus: Menus) -> void:
	var game: Node = menus.game
	var stock := wares(game)
	menus._add_label(Lang.t("Kletterer"), 38, game.GOLD, game.TITLE_FONT)
	var gear := []
	var goods := []
	for id: String in WARES:
		if int(stock.get(id, 0)) <= 0:
			continue
		var cost := price(id)
		var entry := {"key": "ware:" + id, "id": id, "name": Items.item_name(id), "price": Lang.t("%d Kupfer") % cost,
				"price_ok": Payment.can_pay(game, cost), "button": Lang.t("Kaufen"), "action": _buy.bind(menus, id),
				"enabled": Payment.can_pay(game, cost) and game.player.bag_fits(id), "count": int(stock[id])}
		(goods if Menus._is_consumable(id) else gear).append(entry)
	var empty := Lang.t("Nichts im Angebot.")
	menus._trade(Lang.t("Dein Kupfer: %d") % game.coins, [
		{"key": "gear", "title": Lang.t("Ausrüstung"), "icon": "kind:helmet", "entries": gear, "empty": empty, "gone": Lang.t("Ausverkauft")},
		{"key": "goods", "title": Lang.t("Verbrauchsgüter"), "icon": "kind:potion", "entries": goods, "empty": empty, "gone": Lang.t("Ausverkauft")},
	], null, "%s\n%s" % [talk(game), Lang.t("Wolfram hat nur wenig dabei und verlangt mehr als Mira. Nach drei Tagen hat er Nachschub.")])


static func _buy(menus: Menus, id: String) -> void:
	var game: Node = menus.game
	var stock := wares(game)
	var cost := price(id)
	if int(stock.get(id, 0)) <= 0:
		menus._note = Lang.t(SOLD_OUT)
	elif not Payment.can_pay(game, cost):
		menus._note = Lang.t("Dafür reicht dein Kupfer nicht.")
	elif not game.player.bag_fits(id):
		menus._note = Lang.t("Deine Tasche ist voll.")
	else:
		Payment.pay(game, cost)
		Events.bus().traded.emit(ROLE)
		game.player.bag.append(id)
		stock[id] = int(stock[id]) - 1
		menus._note = Lang.t("Gekauft: %s (%s)") % [Items.item_name(id), Items.describe(id)]
	menus._rebuild()
