class_name Payment
extends RefCounted
## One way to pay a price in copper (see Loot.MONEY). The hero pays with copper coins first and,
## when they do not reach, with silver coins and then gold coins at Loot.COIN_VALUE. A coin is
## never cut: the merchant gives the change back in copper coins. Every place that spends money
## asks `can_pay` and then calls `pay`; nobody subtracts game.coins by hand.


## What the hero's coins are worth together, in copper.
static func worth(game: Node) -> int:
	return game.coins + _silver(game) * int(Loot.COIN_VALUE["silbermuenze"]) + _gold(game) * int(Loot.COIN_VALUE["goldmuenze"])


## Whether the hero's coins together reach `price` copper.
static func can_pay(game: Node, price: int) -> bool:
	return worth(game) >= price


## Which coins pay `price` out of the given purse: {"kupfermuenze", "silbermuenze", "goldmuenze"}
## coins handed over, and "change" in copper coins coming back. An empty dictionary when the
## purse does not reach the price. Copper goes first, then as few silver coins as it takes, then gold.
static func plan(price: int, copper: int, silver: int, gold: int) -> Dictionary:
	price = maxi(price, 0)
	if copper + silver * int(Loot.COIN_VALUE["silbermuenze"]) + gold * int(Loot.COIN_VALUE["goldmuenze"]) < price:
		return {}
	var s_val := int(Loot.COIN_VALUE["silbermuenze"])
	var g_val := int(Loot.COIN_VALUE["goldmuenze"])
	var cu := mini(copper, price)
	var need := price - cu
	var ag := 0
	var ap := 0
	if need > 0:
		# Silver first; gold only when all the silver together falls short.
		if silver * s_val >= need:
			ap = ceili(float(need) / s_val)
		else:
			ap = silver
			need -= ap * s_val
			ag = ceili(float(need) / g_val)
			need = 0
			# Gold that overshoots may leave silver coins unspent: take back what is not needed.
			var paid := cu + ap * s_val + ag * g_val
			while ap > 0 and paid - s_val >= price:
				ap -= 1
				paid -= s_val
	var total := cu + ap * s_val + ag * g_val
	return {"kupfermuenze": cu, "silbermuenze": ap, "goldmuenze": ag, "change": total - price}


## Pays `price` copper. Returns the plan (see plan) once the coins are taken and the change is
## in the purse, or an empty dictionary when the hero cannot pay (nothing is taken then). When
## silver or gold was handed over, the news says what was paid and what came back.
static func pay(game: Node, price: int) -> Dictionary:
	var p := plan(price, game.coins, _silver(game), _gold(game))
	if p.is_empty():
		return p
	game.coins -= int(p["kupfermuenze"])
	if int(p["silbermuenze"]) > 0:
		game.crafting.take("silbermuenze", int(p["silbermuenze"]))
	if int(p["goldmuenze"]) > 0:
		game.crafting.take("goldmuenze", int(p["goldmuenze"]))
	game.coins += int(p["change"])
	var line := describe(p)
	if line != "":
		Events.tell(line, Color(1.0, 0.85, 0.3))
	return p


## "Paid with 1 silver (change: 5 copper)." for a plan that used silver or gold, else "".
static func describe(p: Dictionary) -> String:
	if p.is_empty() or (int(p["silbermuenze"]) == 0 and int(p["goldmuenze"]) == 0):
		return ""
	var parts := []
	if int(p["kupfermuenze"]) > 0:
		parts.append(Lang.t("%d Kupfer") % int(p["kupfermuenze"]))
	if int(p["silbermuenze"]) > 0:
		parts.append(Lang.t("%d Silber") % int(p["silbermuenze"]))
	if int(p["goldmuenze"]) > 0:
		parts.append(Lang.t("%d Gold") % int(p["goldmuenze"]))
	var text := Lang.t("Bezahlt mit %s.") % ", ".join(parts)
	if int(p["change"]) > 0:
		text += " " + Lang.t("Wechselgeld: %d Kupfer.") % int(p["change"])
	return text


static func _silver(game: Node) -> int:
	return game.crafting.have("silbermuenze") if game.crafting else 0


static func _gold(game: Node) -> int:
	return game.crafting.have("goldmuenze") if game.crafting else 0
