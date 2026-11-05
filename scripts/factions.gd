class_name Factions
extends RefCounted
## Not every monster is on the same side. Each kind belongs to a faction,
## and some factions are rivals: when two rivals meet, in the wild or in the
## dungeon, they fight each other (see Enemy.foe), and whoever wins leaves
## the loser's loot for the hero.
##
## - The dead (skeletons, fog wraiths) hate everything that lives.
## - The bandits of the pass and the beasts of the wolf hollow (wolves, orcs,
##   spiders, the yeti) are at war. The beasts share their hollow in peace.
## - The dragon's brood (bats, slimes, the dragon) wants the skeletons out
##   of its cave.
##
## Some factions can be won over with gifts (key T or the "Schenken" button,
## next to one of them). Each gift earns favour; at FRIENDLY the whole
## faction becomes the hero's friend: its members no longer attack, the
## hero's blade and knives pass them by, and they fall upon any monster
## that hunts the hero nearby. Slaying one of them costs favour; slaying
## their rivals earns a little, though never quite enough without a gift.
## The favour is kept in the saved game.

## Which faction each kind of Enemy belongs to.
const KINDS := {
	"krieger": "undead", "schuetze": "undead", "magier": "undead", "wicht": "undead",
	"koloss": "undead", "waechter": "undead", "fog_wraith": "undead",
	"halsabschneider": "bandits", "wilderer": "bandits", "schlaeger": "bandits", "hauptmann": "bandits",
	"wolf": "wolves", "ork": "orcs", "spinne": "spiders", "yeti": "yeti",
	"spinnenkoenigin": "spiders",
	"fledermaus": "brood", "schleim": "brood", "drache": "brood",
	# The nameless horrors (see Horrors) belong to nobody and fight nobody
	# but the hero.
	"hohle_mutter": "horrors", "bleicher_waechter": "horrors", "schlund": "horrors",
	# The beasts of the far mountains and their mines keep to themselves
	# and cannot be won over.
	"eiswolf": "mountain", "bergork": "mountain", "felstroll": "mountain", "klippenschuetze": "mountain",
	"kristallschleim": "mountain", "glutschleim": "mountain", "bergkoenig": "mountain",
	# The Great Old One and its brood below the high valley (see ElderLair).
	"brutdrache": "elder", "grosser_alter": "elder",
}

## The factions. "name" is shown in messages. A faction with a "gift" can be
## befriended: "gift" is an ingredient from the pouch (see Crafting) or
## "gold", "count" how many make one gift. "wish" is said when the hero has
## nothing it wants, "thanks" after a gift, "won" once it is friends and
## "friend" when the hero meets one of them afterwards.
## "refuse" is said by those that cannot be won over.
const FACTIONS := {
	"undead": {"name": "Die Toten",
		"refuse": "Die Toten wollen keine Geschenke. Sie wollen nur dich."},
	"bandits": {"name": "Die Räuber",
		"refuse": "Räuber nehmen dein Kupfer lieber mit Gewalt."},
	"spiders": {"name": "Die Spinnen",
		"refuse": "Die Spinne starrt dich mit acht Augen an. Mit ihr ist kein Frieden zu machen."},
	"brood": {"name": "Die Brut des Drachen",
		"refuse": "Die Brut des Drachen lässt sich nicht zähmen."},
	"mountain": {"name": "Die Bergbrut",
		"refuse": "In den Bergen gilt nur das Recht des Stärkeren. Geschenke bringen hier nichts."},
	"elder": {"name": "Die Brut des Großen Alten",
		"refuse": "Die Brut des Großen Alten bewacht seinen Hort. Für Geschenke hat sie nur Feuer übrig."},
	"horrors": {"name": "Die Namenlosen",
		"refuse": "Es hat keinen Hunger auf Geschenke. Es hat Hunger auf dich."},
	"wolves": {"name": "Die Wölfe", "gift": "barsch", "count": 1,
		"wish": "Wölfe mögen Fisch. Ein Barsch beißt im Tümpel der Wolfssenke.",
		"thanks": "Der Wolf schnappt sich den Barsch und wedelt mit dem Schwanz.",
		"won": "Das Rudel hat dich angenommen! Die Wölfe greifen dich nicht mehr an und kämpfen an deiner Seite.",
		"friend": "Die Wölfe sind deine Freunde."},
	"orcs": {"name": "Die Orks", "gift": "gold", "count": 6,
		"wish": "Orks wollen Kupfer sehen: 6 Münzen für einen Handschlag.",
		"thanks": "Der Ork beißt auf die Münzen und grunzt zufrieden.",
		"won": "Die Orks nennen dich Freund! Sie greifen dich nicht mehr an und kämpfen an deiner Seite.",
		"friend": "Die Orks sind deine Freunde."},
	"yeti": {"name": "Der Yeti", "gift": "barsch", "count": 2,
		"wish": "Der Yeti hat Hunger: zwei Barsche würden ihn milde stimmen.",
		"thanks": "Der Yeti verschlingt die Barsche mit einem Happs.",
		"won": "Der Yeti ist dein Freund! Er greift dich nicht mehr an und kämpft an deiner Seite.",
		"friend": "Der Yeti ist dein Freund."},
}

## Which factions fight each other on sight. Rivalry goes both ways.
const RIVALS := {
	"undead": ["bandits", "wolves", "orcs", "spiders", "yeti", "brood"],
	"bandits": ["wolves", "orcs", "spiders", "yeti"],
}

## Favour a faction needs to be the hero's friend.
const FRIENDLY := 3.0
## Favour each gift earns.
const GIFT_FAVOUR := 1.0
## Favour lost when the hero slays one of a faction.
const KILL_FAVOUR := -1.0
## Favour earned with a faction when the hero slays one of its rivals. It
## never brings a faction past FRIENDLY - 1: the last step takes a gift.
const RIVAL_KILL_FAVOUR := 0.25
## Favour sinks no lower than this, so a hero who slew many can still make peace.
const LOWEST := -6.0

## Explained once in the compendium, the first time a faction is won over.
const HOW_TO := "Nicht alle Ungeheuer sind Freunde: Räuber und die Bestien der Wolfssenke bekämpfen sich, und die Toten hassen alles, was lebt. Wölfe, Orks und den Yeti kannst du mit Geschenken für dich gewinnen (Taste T oder „Schenken“, nah bei ihnen): Wölfe mögen Barsch, Orks Kupfer, der Yeti zwei Barsche. Nach drei Geschenken greifen sie dich nicht mehr an und kämpfen an deiner Seite. Wer ihresgleichen erschlägt, verliert ihre Gunst."

## Faction id -> favour (see FRIENDLY). Kept in the saved game.
static var favour := {}


## The faction of a kind of Enemy, or "" for none.
static func of(kind: String) -> String:
	return KINDS.get(kind, "")


## Whether two factions fight each other.
static func are_rivals(a: String, b: String) -> bool:
	if a == "" or b == "" or a == b:
		return false
	return RIVALS.get(a, []).has(b) or RIVALS.get(b, []).has(a)


## Whether monsters of these two kinds fight each other when they meet.
static func kinds_are_rivals(kind_a: String, kind_b: String) -> bool:
	return are_rivals(of(kind_a), of(kind_b))


## Whether a faction can be won over with gifts.
static func can_befriend(faction: String) -> bool:
	return FACTIONS.get(faction, {}).has("gift")


static func favour_of(faction: String) -> float:
	return float(favour.get(faction, 0.0))


## Whether a faction is the hero's friend.
static func is_friendly(faction: String) -> bool:
	return can_befriend(faction) and favour_of(faction) >= FRIENDLY


## A gift was given. True when it made the faction the hero's friend.
static func give(faction: String) -> bool:
	if not can_befriend(faction) or is_friendly(faction):
		return false
	favour[faction] = minf(FRIENDLY, favour_of(faction) + GIFT_FAVOUR)
	return is_friendly(faction)


## The hero slew a monster of this kind: its faction minds, its rivals are glad.
static func on_hero_kill(kind: String) -> void:
	var slain := of(kind)
	if slain == "":
		return
	if can_befriend(slain):
		favour[slain] = maxf(LOWEST, minf(favour_of(slain), FRIENDLY - GIFT_FAVOUR) + KILL_FAVOUR)
	for f in FACTIONS:
		if can_befriend(f) and not is_friendly(f) and are_rivals(f, slain) and favour_of(f) < FRIENDLY - GIFT_FAVOUR:
			favour[f] = minf(FRIENDLY - GIFT_FAVOUR, favour_of(f) + RIVAL_KILL_FAVOUR)


static func clear() -> void:
	favour.clear()


## What is kept in the saved game: only plain values.
static func for_save() -> Dictionary:
	return favour.duplicate()


## Back from the saved game; unknown factions are left out, and older saved
## games start with no favour anywhere.
static func load_from(saved) -> void:
	clear()
	if not (saved is Dictionary):
		return
	for f in saved:
		if can_befriend(str(f)) and (saved[f] is float or saved[f] is int):
			favour[str(f)] = clampf(float(saved[f]), LOWEST, FRIENDLY)
