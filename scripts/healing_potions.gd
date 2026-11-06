class_name HealingPotions
extends RefCounted
## Healing potions, brewed from a recipe at the alchemist's table on the
## crafting square (Crafting.RECIPES "heiltrank", craft "alchemie").
##
## How strong a brew turns out depends on the brewer: Intelligenz plus twice
## the level in Alchemie gives the brewing points (see brew_points), and the
## points pick one of three potencies (POTENCIES): low, medium or high. A
## potion heals a share of the hero's lives at once, a random share inside
## its potency's range, and then, whatever its potency, REGEN_PER_SECOND
## life every second for REGEN_TIME seconds. Like the old healing draughts
## of the dungeon it also cures what ails the hero (poison, curse...).
##
## Potions bundle STACK to a bag slot. They are drunk with the potion button
## left of the torch button on the right edge (or the key 1, or "Drink" in
## the inventory), at most once every COOLDOWN seconds; the button shows the
## time left as a shade that drains away and the seconds in its middle.
## Every hero carries one of these (Player.potions), ticked in the hero's
## physics step.

## The three potions, weakest first: their potency ("schwach", "mittel",
## "stark"), the share of the lives healed at once (from, to) and the
## brewing points from which they are brewed.
const POTIONS := {
	"heiltrank_schwach": {"potency": "schwach", "heal": [0.15, 0.20], "from": 0},
	"heiltrank": {"potency": "mittel", "heal": [0.25, 0.35], "from": 16},
	"heiltrank_stark": {"potency": "stark", "heal": [0.40, 0.60], "from": 26},
}
## The German words for the potencies, as the bench and the item cards say them.
const POTENCY_NAMES := {"schwach": "niedrig", "mittel": "mittel", "stark": "hoch"}
## How many potions share one bag slot.
const STACK := 5
## Seconds between two potions.
const COOLDOWN := 60.0
## After every potion: this much life per second, for this many seconds.
const REGEN_PER_SECOND := 1
const REGEN_TIME := 20
## The recipe and the craft that brews them.
const RECIPE := "heiltrank"
const CRAFT := "alchemie"
## Green, as healing numbers over the hero.
const HEAL_COLOR := Color(0.4, 0.92, 0.4)

## Explained once in the compendium, the first time the hero drinks one.
const LEARN := "Heiltränke braust du am Alchemistentisch auf dem Handwerkerplatz. Wie stark sie werden, hängt von deiner Intelligenz und deiner Stufe in Alchemie ab: niedrig heilt 15 bis 20 %, mittel 25 bis 35 % und hoch 40 bis 60 % deiner Leben. Danach heilt jeder Trank 20 Sekunden lang 1 Leben pro Sekunde. Trink mit Taste 1 oder dem Trank links neben der Fackel am rechten Rand, höchstens einmal pro Minute."

var player: Player
## Seconds until the next potion may be drunk.
var cooldown := 0.0
## Life pulses still to come from the last potion, one per second.
var pulses_left := 0
var _pulse_clock := 0.0


func _init(hero: Player = null) -> void:
	player = hero


static func is_potion(id: String) -> bool:
	return POTIONS.has(id)


## The brewing points of a brewer: Intelligenz + 2 x Alchemie.
static func points(intelligence: int, alchemy: int) -> int:
	return intelligence + 2 * alchemy


## The potion brewed with these brewing points.
static func brewed(brew_points: int) -> String:
	var best := "heiltrank_schwach"
	for id in POTIONS:
		if brew_points >= int(POTIONS[id].from):
			best = id
	return best


## The next stronger potion after this one, or "" for the strongest.
static func next_of(id: String) -> String:
	var ids := POTIONS.keys()
	var i := ids.find(id)
	return ids[i + 1] if i >= 0 and i + 1 < ids.size() else ""


## "niedrig", "mittel" or "hoch" in the player's language.
static func potency_name(id: String) -> String:
	return Lang.t(POTENCY_NAMES[POTIONS[id].potency])


## The hero's brewing points right now.
func brew_points() -> int:
	if player == null:
		return 0
	return points(player.attribute("intelligenz"), Training.skill_level(float(player.xp.get(CRAFT, 0.0)), CRAFT))


## Potions in the bag, of every potency.
func carried() -> int:
	if player == null:
		return 0
	var n := 0
	for id in POTIONS:
		n += player.bag.count(id)
	return n


## The potion the button drinks: the strongest one in the bag, or "".
func best() -> String:
	if player == null:
		return ""
	var ids := POTIONS.keys()
	ids.reverse()
	for id in ids:
		if player.bag.has(id):
			return id
	return ""


## Whether a potion is ready to be drunk (the cooldown is over).
func is_ready() -> bool:
	return cooldown <= 0.0


## Drinks a potion from the bag (the strongest when none is named). Returns
## "" when it worked, else why not.
func drink(id := "") -> String:
	if player == null or player.dead:
		return Lang.t("Du kannst jetzt nichts trinken.")
	if id == "":
		id = best()
	if id == "" or not player.bag.has(id):
		return Lang.t("Du hast keinen Heiltrank. Brau einen am Alchemistentisch.")
	if not is_ready():
		return Lang.t("Dein nächster Heiltrank wirkt erst in %d Sekunden.") % ceili(cooldown)
	player.bag.erase(id)
	var heal: Array = POTIONS[id].heal
	var amount := maxi(1, roundi(player.max_hp * randf_range(float(heal[0]), float(heal[1]))))
	var gained := mini(amount, player.max_hp - player.hp)
	player.hp += gained
	player.cure()
	cooldown = COOLDOWN
	pulses_left = REGEN_TIME
	_pulse_clock = 0.0
	if is_instance_valid(player.level):
		Effects.head_text(player.level, player, 2.4, "+%d" % gained, HEAL_COLOR)
	Sfx.play(player, "drink")
	player.regenerated.emit()
	return ""


## Counts the cooldown down and gives the life of the last potion, one pulse
## a second. A fallen hero loses what was still to come.
func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if pulses_left <= 0 or player == null:
		return
	if player.dead:
		pulses_left = 0
		return
	_pulse_clock += delta
	while _pulse_clock >= 1.0 and pulses_left > 0:
		_pulse_clock -= 1.0
		pulses_left -= 1
		if player.hp < player.max_hp:
			player.hp = mini(player.max_hp, player.hp + REGEN_PER_SECOND)
			player.regenerated.emit()


## Seconds left of the life over time, for the HUD.
func regen_left() -> int:
	return pulses_left
