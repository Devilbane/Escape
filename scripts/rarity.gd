class_name Rarity
extends RefCounted
## The colour code of items: every item's name is shown in the colour of its
## rarity, wherever a name appears (the inventory and its details, the
## storage chest and the vault, the merchants' rows and cards, the event log,
## the words over the hero's head when something is found).
##
## The tiers are the familiar ones of many role-playing games, from plain to
## finest: common (white), uncommon (green), rare (blue), epic (violet) and
## god-born (orange). How rare a piece is follows how useful and valuable
## it is (see Items.RARITY, one table for every item). Pieces the hero
## makes from a recipe ("crafted") are a tier of their own in turquoise,
## whatever their price, so the hero's own work is told apart at a glance.
##
## Colour is never the only cue (see the ux-ui guide, 8.3): the inventory's
## details and the merchants' cards also name the tier in words.
##
## The colours are bright enough for at least 4.5 : 1 against the game's
## dark windows (0.04, 0.03, 0.08) and stay apart from the window colours
## that mean something else: GOLD (titles, prices), the info BLUE and the
## reputation violet are lighter and paler than rare and epic.

const COMMON := Color(0.92, 0.92, 0.9)
const UNCOMMON := Color(0.35, 0.9, 0.35)
const RARE := Color(0.25, 0.55, 1.0)
const EPIC := Color(0.75, 0.42, 1.0)
const GODBORN := Color(1.0, 0.5, 0.1)
const CRAFTED := Color(0.25, 0.9, 0.85)

## The tier of what the hero made from a recipe (see Crafting).
const SELF_MADE := "gefertigt"
## Every tier, from plain to finest, then the hero's own work: its German
## name (translated with Lang.t) and its colour.
const TIERS := {
	"normal": {"name": "Gewöhnlich", "color": COMMON},
	"ungewoehnlich": {"name": "Ungewöhnlich", "color": UNCOMMON},
	"selten": {"name": "Selten", "color": RARE},
	"episch": {"name": "Episch", "color": EPIC},
	"gottgeboren": {"name": "Gottgeboren", "color": GODBORN},
	SELF_MADE: {"name": "Selbst gefertigt", "color": CRAFTED},
}

## Marks around an item id in a text for the event log, which shows the
## item's name there in its colour (see marked and to_bbcode). Two private
## use characters, so no real text ever holds them.
const MARK_OPEN := ""
const MARK_CLOSE := ""


## The tier of an item (a key of TIERS). Pieces made from a recipe are the
## hero's own work; ingredients flagged "rare" (the rare fish, the moon
## flower) are rare; anything else in Items goes by Items.RARITY (see
## Level.tier_of).
static func tier(id: String) -> String:
	if Items.ALL.has(id):
		if Items.ALL[id].get("crafted", false):
			return SELF_MADE
		return Level.tier_of(id)
	if Crafting.INGREDIENTS.get(id, {}).get("rare", false):
		return "selten"
	return "normal"


## The colour an item's name is shown in.
static func color(id: String) -> Color:
	return TIERS[tier(id)].color


## The tier's name in words, translated ("Rare", "Self-crafted").
static func label(id: String) -> String:
	return Lang.t(TIERS[tier(id)].name)


## The same colour a little lighter, for a button under the pointer.
static func hover(c: Color) -> Color:
	return c.lerp(Color.WHITE, 0.3)


## The name of an item or an ingredient, translated.
static func name_of(id: String) -> String:
	return Items.item_name(id) if Items.ALL.has(id) else Crafting.ingredient_name(id)


## An item's name, translated, in the colour of its rarity, as BBCode for a
## RichTextLabel.
static func bbcode(id: String) -> String:
	return "[color=#%s]%s[/color]" % [color(id).to_html(false), name_of(id).replace("[", "[lb]")]


## An item's place in a text for the event log: the log puts in its name in
## its colour (see to_bbcode). Elsewhere, use plain() to show the text.
static func marked(id: String) -> String:
	return MARK_OPEN + id + MARK_CLOSE


## A text with marked items as BBCode: each name in its colour. The rest of
## the text must already be escaped for BBCode.
static func to_bbcode(text: String) -> String:
	return _replace_marks(text, bbcode)


## A text with marked items as plain text: just their names.
static func plain(text: String) -> String:
	return _replace_marks(text, name_of)


static func _replace_marks(text: String, name_of: Callable) -> String:
	var out := ""
	var at := 0
	while true:
		var open := text.find(MARK_OPEN, at)
		if open < 0:
			break
		var close := text.find(MARK_CLOSE, open)
		if close < 0:
			break
		out += text.substr(at, open - at) + str(name_of.call(text.substr(open + 1, close - open - 1)))
		at = close + 1
	return out + text.substr(at)
