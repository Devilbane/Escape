class_name Blessing
extends RefCounted
## The gods of the village temple and the blessing a hero can carry. Priestess
## Elsbeth gives it (see Menus._build_temple): the hero picks one god, and
## the god's boon (and, for some, a burden) works at full strength, three
## thirds. Every rescue (see Rescue) takes one third away; after the third the
## hero is no longer blessed. Boon and burden shrink together with it.
##
## The first blessing of a hero is free. Later ones cost an offering, and a
## weakened blessing is renewed to full for a smaller offering per lost third.
## While blessed, a hero stays with their god; they can only choose another
## one when the blessing is gone.

## Explained once in the compendium, the first time a hero is blessed.
const LORE := "Im Tempel segnet dich Priesterin Elsbeth im Namen eines Gottes. Der Segen gibt dir einen Vorteil, manchmal gegen einen Preis, und hält drei Rettungen lang: Jedes Mal, wenn du bewusstlos wirst und gerettet wirst, verliert er ein Drittel seiner Stärke, und nach der dritten Rettung bist du nicht mehr gesegnet. Der erste Segen ist umsonst; später kostet er eine Gabe, und einen schwächer gewordenen Segen kannst du im Tempel erneuern."

## A full blessing is this many thirds.
const FULL := 3
## The offering for a new blessing after the first (copper), and for each
## lost third when a weakened blessing is renewed.
const OFFERING := 40
const RENEW := 15

## id -> name, what the god is lord of, a picture (see ItemIcon), and per third
## the boon and the burden: "hp" (life), "power", "hardening", "speed" (a share
## of the base speed, 0.03 = 3 %) and "block" (a share, 0.04 = 4 %).
const GODS := {
	"aurel": {"name": "Aurel", "title": "Vater des Herdes", "icon": "kind:heal_potion",
		"tale": "Er hält die Wunden der Müden geschlossen.",
		"boon": {"hp": 1}, "burden": {}},
	"korr": {"name": "Korr", "title": "der Eisenschmied", "icon": "kind:sword",
		"tale": "Er führt jede Hand, die einen Hammer oder ein Schwert hält.",
		"boon": {"power": 1}, "burden": {"speed": -0.02}},
	"skyra": {"name": "Skyra", "title": "Königin der Adler", "icon": "kind:boots",
		"tale": "Wer sie ruft, läuft, als hätte er Schwingen.",
		"boon": {"speed": 0.03}, "burden": {}},
	"dunmar": {"name": "Dunmar", "title": "Herr des tiefen Steins", "icon": "kind:shield",
		"tale": "Der Gott der Zwerge macht die Haut hart wie Fels, und die Füße schwer.",
		"boon": {"hardening": 1}, "burden": {"speed": -0.02}},
	"veyl": {"name": "Veyl", "title": "die Verhüllte", "icon": "kind:cloak",
		"tale": "Schläge gleiten an ihren Schützlingen vorbei wie an einem Schatten.",
		"boon": {"block": 0.04}, "burden": {}},
	"ashkar": {"name": "Ashkar", "title": "Fürst der Glut", "icon": "kind:flame",
		"tale": "Der Drachengott schenkt rohe Gewalt und nimmt dafür Leben.",
		"boon": {"power": 2}, "burden": {"hp": -1}},
}
## The order the temple lists them in.
const ORDER := ["aurel", "korr", "skyra", "dunmar", "veyl", "ashkar"]

## One line for each effect: the sign and the text, "%s" being the amount.
const EFFECT_TEXT := {
	"hp": "%s Leben",
	"power": "%s Kampfkraft",
	"hardening": "%s Härtung",
	"speed": "%s Tempo",
	"block": "%s Blockchance",
}


static func exists(god: String) -> bool:
	return GODS.has(god)


## "Aurel, Vater des Herdes".
static func full_name(god: String) -> String:
	return "%s, %s" % [Lang.t(GODS[god].name), Lang.t(GODS[god].title)]


## The title on the character page: "Gesegnet von Aurel (2/3)".
static func title(god: String, thirds: int) -> String:
	return Lang.t("Gesegnet von %s") % Lang.t(GODS[god].name) + " (%d/%d)" % [thirds, FULL]


## What the god gives, one effect per entry, at `thirds` of the strength:
## {"hp": 4, ...} (whole numbers for life, power and hardening; shares as
## fractions for speed and block).
static func effects(god: String, thirds: int) -> Dictionary:
	var out := {}
	if not GODS.has(god) or thirds <= 0:
		return out
	var k := clampi(thirds, 0, FULL)
	for part in ["boon", "burden"]:
		for id in GODS[god][part]:
			out[id] = GODS[god][part][id] * k
	return out


## The same, summed over the boon and the burden into one value per effect id.
static func amount(god: String, thirds: int, id: String) -> float:
	return float(effects(god, thirds).get(id, 0))


## "+6 Leben" / "−6 % Tempo": how one effect reads.
static func describe(id: String, value: float) -> String:
	var shown := ""
	if id == "speed" or id == "block":
		shown = "%+d %%" % roundi(value * 100.0)
	else:
		shown = "%+d" % roundi(value)
	shown = shown.replace("-", "−")
	return Lang.t(EFFECT_TEXT[id]) % shown


## The effect lines of a god at `thirds`: [[text, is_boon], ...].
static func lines(god: String, thirds: int) -> Array:
	var out := []
	var e := effects(god, thirds)
	for id in e:
		out.append([describe(id, e[id]), float(e[id]) > 0.0])
	return out


## What a blessing costs now: nothing for a hero's first, else the offering.
static func price_new(ever_blessed: bool) -> int:
	return OFFERING if ever_blessed else 0


## What renewing a weakened blessing costs (every lost third).
static func price_renew(thirds: int) -> int:
	return RENEW * maxi(0, FULL - thirds)


## A rescue takes one third. Returns true when the hero was blessed and now has
## less (or none).
static func weaken(hero: Player) -> bool:
	if hero.blessing_god == "" or hero.blessing_thirds <= 0:
		return false
	hero.blessing_thirds -= 1
	if hero.blessing_thirds <= 0:
		hero.blessing_thirds = 0
		hero.blessing_god = ""
	hero.refresh_stats()
	return true


## Receives a blessing of a god at full strength.
static func bless(hero: Player, god: String) -> void:
	hero.blessing_god = god
	hero.blessing_thirds = FULL
	hero.blessed_before = true
	hero.refresh_stats()


static func for_save(hero: Player) -> Dictionary:
	return {"god": hero.blessing_god, "thirds": hero.blessing_thirds, "before": hero.blessed_before}


static func load_from(hero: Player, data) -> void:
	hero.blessing_god = ""
	hero.blessing_thirds = 0
	hero.blessed_before = false
	if data is Dictionary:
		var god := String(data.get("god", ""))
		var thirds := clampi(int(data.get("thirds", 0)), 0, FULL)
		if GODS.has(god) and thirds > 0:
			hero.blessing_god = god
			hero.blessing_thirds = thirds
		hero.blessed_before = bool(data.get("before", false)) or hero.blessing_god != ""
