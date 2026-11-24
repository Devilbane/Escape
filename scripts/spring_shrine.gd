class_name SpringShrine
extends RefCounted
## The river goddess's shrine in the heart of the spring cave (see SpringCave, map letter "H" in
## "Die Quellhöhle"). It uses the shrine window (see Game._open_shrine) with her own three gifts, in the
## same three places: a safe one, one that trades life for strength, and one that heals. Once.

## The labels of the three buttons.
const GIFTS := ["+5 Leben", "+1 Attributpunkt\n(kostet 5 Leben)", "Volle Heilung"]
## What the hero may learn at the shrine, for the compendium.
const LEARN := "Im Herzen der Quellhöhle steht der Schrein der Flussherrin, die den Fluss aus dem Berg entlässt. Sie schenkt einmal eine Gabe: Leben, einen Attributpunkt gegen einen Teil des Lebens, oder volle Heilung. Der Wasserfall, der ihr Tor im Sommer verschließt, ist im Winter zu Eis erstarrt."
const LIFE_PRICE := 5
## The hero keeps at least this much life when paying the price.
const LEAST_LIFE := 15


## Gives gift `index` and returns the message, or "" when it cannot be given (the window stays open).
static func give(game, index: int) -> String:
	var hero: Player = game.player
	match index:
		0:
			hero.gift_hp += Player.SHRINE_LIFE
			hero.hp += Player.SHRINE_LIFE
			return Lang.t("Kühles Wasser umspielt dich: +5 Leben")
		1:
			if hero.max_hp - LIFE_PRICE < LEAST_LIFE:
				game.show_message(Lang.t("Dafür bist du zu schwach: Die Flussherrin nimmt dir kein Leben."), 2.5)
				return ""
			hero.gift_points += Player.SHRINE_POINTS
			hero.gift_hp -= LIFE_PRICE
			hero.refresh_stats()
			hero.hp = mini(hero.hp, hero.max_hp)
			return Lang.t("Die Flussherrin gibt dir einen Attributpunkt und nimmt dafür 5 Leben: verteile ihn auf der Charakterseite (P).")
		2:
			hero.refresh_stats()
			hero.hp = hero.max_hp
			return Lang.t("Die Quelle heilt alle deine Wunden.")
	return ""
