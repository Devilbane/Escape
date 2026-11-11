class_name Injury
extends RefCounted
## The injury a rescue leaves (see Rescue): the blow that felled the hero hurts
## for far longer than the fall. Being rescued is meant to be an exception the
## hero wants to avoid.
##
## An injury has a KIND (what is hurt, and so what the hero cannot do) and a
## SEVERITY (how strong the effect is and how long it lasts):
##
##   leg     Gebrochenes Bein   no jumping; from serious on no running either
##   arm     Gebrochener Arm    no shield
##   head    Kopfwunde          Intelligenz down
##   scars   Tiefe Narben       every skill down
##
##   minor, serious, grave: each also costs life and speed (see TUNING).
##
## Minor and serious injuries mend with nights of sleep in a bed, an inn or a
## camp, or at once by a prayer at the healing goddess's altar in the village
## temple for an offering. A grave one never mends by itself and the village
## altar cannot help: only a pilgrimage to the distant forgotten shrine does
## (see pilgrimage_heal). A hero carries one injury at a time; a worse one
## replaces a milder one. All numbers live in TUNING and the chances below.

const LEG := "leg"
const ARM := "arm"
const HEAD := "head"
const SCARS := "scars"
const MINOR := "minor"
const SERIOUS := "serious"
const GRAVE := "grave"

## The kinds, in the order they are rolled, with their names and how much
## longer (and dearer to pray away) they take than an arm or head injury.
const KINDS := {
	LEG: {"name": "Gebrochenes Bein", "long": 1.5},
	ARM: {"name": "Gebrochener Arm", "long": 1.0},
	HEAD: {"name": "Kopfwunde", "long": 1.0},
	SCARS: {"name": "Tiefe Narben", "long": 2.0},
}
const SEVERITIES := [MINOR, SERIOUS, GRAVE]

## Everything a severity changes, in one place:
##   hp      max life lost
##   speed   share of the base speed lost
##   drop    points of Intelligenz (head) or levels of every skill (scars) lost
##   nights  nights of rest to mend it (0: never by rest)
##   price   what a prayer at the village altar costs (copper); grave: none
##   run     whether a broken leg still allows running
const TUNING := {
	MINOR: {"hp": 2, "speed": 0.05, "drop": 1, "nights": 3, "price": 40, "run": true},
	SERIOUS: {"hp": 4, "speed": 0.10, "drop": 2, "nights": 7, "price": 120, "run": false},
	GRAVE: {"hp": 6, "speed": 0.20, "drop": 3, "nights": 0, "price": 0, "run": false},
}
## The chances (summing to 1) of each severity: when an ordinary foe, a fall,
## poison or fire felled the hero, and when a boss did (see Enemy.is_level_boss).
const CHANCES := {
	"normal": {MINOR: 0.65, SERIOUS: 0.28, GRAVE: 0.07},
	"boss": {MINOR: 0.0, SERIOUS: 0.40, GRAVE: 0.60},
}
const SEVERITY_NAMES := {MINOR: "leicht", SERIOUS: "schwer", GRAVE: "bleibend"}

const LORE := "Wer bewusstlos gerettet wird, trägt eine Verletzung davon: ein gebrochenes Bein (kein Springen, später auch kein Rennen), einen gebrochenen Arm (kein Schild), eine Kopfwunde (weniger Intelligenz) oder tiefe Narben (alle Fertigkeiten schwächer). Leichte und schwere heilen nach einigen Nächten im Bett; schwere heilt auch ein Gebet am Altar der Heilgöttin Mirenna im Dorftempel. Gegen eine bleibende Verletzung hilft nur eine Pilgerreise zum fernen, vergessenen Schrein. Nach einem Bosskampf ist die Verletzung meist schwer oder bleibend."


## The severity a rescue leaves, by what felled the hero: `roll` (0 to 1) picks
## from the chances of a boss or of anything else.
static func severity_for(attacker: Node, roll := -1.0) -> String:
	var boss: bool = attacker != null and attacker.has_method("is_level_boss") and attacker.is_level_boss()
	var chances: Dictionary = CHANCES["boss" if boss else "normal"]
	var at := randf() if roll < 0.0 else roll
	for severity in SEVERITIES:
		at -= float(chances[severity])
		if at < 0.0:
			return severity
	return SEVERITIES[-1]


## A random kind of injury (`roll`, 0 to 1, picks one for the tests).
static func random_kind(roll := -1.0) -> String:
	var kinds: Array = KINDS.keys()
	return kinds[mini(kinds.size() - 1, int((randf() if roll < 0.0 else roll) * kinds.size()))]


static func has(hero: Player) -> bool:
	return hero.injury != ""


## "Gebrochenes Bein (schwer)".
static func title(kind: String, severity: String) -> String:
	return "%s (%s)" % [Lang.t(KINDS[kind].name), Lang.t(SEVERITY_NAMES[severity])]


static func tuning(severity: String) -> Dictionary:
	return TUNING.get(severity, TUNING[MINOR])


## Gives the hero an injury unless they carry an equal or worse one already.
## Returns whether the hero now has the new one.
static func give(hero: Player, kind: String, severity: String) -> bool:
	if not KINDS.has(kind) or not TUNING.has(severity):
		return false
	if hero.injury != "" and SEVERITIES.find(severity) <= SEVERITIES.find(hero.injury_severity):
		return false
	hero.injury = kind
	hero.injury_severity = severity
	hero.injury_rest = 0
	hero.refresh_stats()
	return true


## Nights of rest an injury needs, 0 when rest never mends it.
static func nights(kind: String, severity: String) -> int:
	var base: int = tuning(severity).nights
	return 0 if base <= 0 else roundi(base * float(KINDS[kind].long))


static func nights_left(hero: Player) -> int:
	if hero.injury == "":
		return 0
	var need := nights(hero.injury, hero.injury_severity)
	return 0 if need <= 0 else maxi(1, need - hero.injury_rest)


## One night's rest. Returns true when the injury mended with it.
static func rest(hero: Player) -> bool:
	if hero.injury == "" or nights(hero.injury, hero.injury_severity) <= 0:
		return false
	hero.injury_rest += 1
	if hero.injury_rest >= nights(hero.injury, hero.injury_severity):
		heal(hero)
		return true
	return false


static func heal(hero: Player) -> void:
	hero.injury = ""
	hero.injury_severity = ""
	hero.injury_rest = 0
	hero.refresh_stats()


## Whether the village temple's altar can heal it: not a grave injury.
static func heals_at_village(hero: Player) -> bool:
	return hero.injury != "" and hero.injury_severity != GRAVE


## The pilgrimage's end: the hero prays at the forgotten, ruined shrine in the
## deserted lands, and the injury is lifted whatever it is. Returns true when
## there was one.
static func pilgrimage_heal(hero: Player) -> bool:
	if hero.injury == "":
		return false
	heal(hero)
	return true


## What the goddess asks for at the village altar, after the blessing's mercy
## (see Blessing.mercy).
static func prayer_price(hero: Player) -> int:
	if not heals_at_village(hero):
		return 0
	var base := float(tuning(hero.injury_severity).price) * float(KINDS[hero.injury].long)
	return roundi(base * (1.0 - Blessing.mercy(hero)))


# --- What an injury does -------------------------------------------------------

## Life lost and speed lost (a share), for the stats.
static func life_lost(hero: Player) -> int:
	return int(tuning(hero.injury_severity).hp) if hero.injury != "" else 0


static func speed_lost(hero: Player) -> float:
	return float(tuning(hero.injury_severity).speed) if hero.injury != "" else 0.0


## Intelligenz points lost (a head injury).
static func attribute_drop(hero: Player, id: String) -> int:
	return int(tuning(hero.injury_severity).drop) if hero.injury == HEAD and id == "intelligenz" else 0


## Levels lost on every skill (deep scars).
static func skill_drop(hero: Player) -> int:
	return int(tuning(hero.injury_severity).drop) if hero.injury == SCARS else 0


## Whether the hero cannot jump (a broken leg), run (a broken leg, serious or
## worse) or use a shield (a broken arm).
static func cannot_jump(hero: Player) -> bool:
	return hero.injury == LEG


static func cannot_run(hero: Player) -> bool:
	return hero.injury == LEG and not tuning(hero.injury_severity).run


static func cannot_use_shield(hero: Player) -> bool:
	return hero.injury == ARM


## The effects as lines of text, one each: what the hero loses or cannot do.
static func effect_lines(kind: String, severity: String) -> Array:
	var t := tuning(severity)
	var out := [Blessing.describe("hp", -float(t.hp)), Blessing.describe("speed", -float(t.speed))]
	match kind:
		LEG:
			out.append(Lang.t("Kein Springen") if t.run else Lang.t("Kein Springen, kein Rennen"))
		ARM:
			out.append(Lang.t("Kein Schild"))
		HEAD:
			out.append(Lang.t("Intelligenz −%d") % int(t.drop))
		SCARS:
			out.append(Lang.t("Alle Fertigkeiten −%d") % int(t.drop))
	return out


static func effect_text(kind: String, severity: String) -> String:
	return ", ".join(effect_lines(kind, severity))


## How it mends, in a sentence.
static func how_to_heal(kind: String, severity: String) -> String:
	var need := nights(kind, severity)
	if need <= 0:
		return Lang.t("Heilt nicht von selbst. Nur eine Pilgerreise zum fernen, vergessenen Schrein heilt sie.")
	return Lang.t("Heilt nach %d Nächten im Bett, oder durch ein Gebet im Tempel.") % need


static func for_save(hero: Player) -> Dictionary:
	return {"kind": hero.injury, "severity": hero.injury_severity, "rest": hero.injury_rest}


static func load_from(hero: Player, data) -> void:
	hero.injury = ""
	hero.injury_severity = ""
	hero.injury_rest = 0
	if data is Dictionary and KINDS.has(String(data.get("kind", ""))) and TUNING.has(String(data.get("severity", ""))):
		hero.injury = String(data.kind)
		hero.injury_severity = String(data.severity)
		hero.injury_rest = maxi(0, int(data.get("rest", 0)))
