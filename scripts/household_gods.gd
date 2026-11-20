class_name HouseholdGods
extends RefCounted
## The household goddesses: small winged statues in a stone shrine that the hero buys from the
## interior furnisher (see HouseFurniture.KINDS, the kinds with a "goddess") and puts down in
## their self-built house with the furnishing tool (see HouseFurnisher). Each goddess blesses the
## house in her own way, with perks that fit her nature (see GODDESSES and PERKS).
##
## The blessing holds while the hero is inside their own house (see HouseGround.shelter and
## Game._update_house_blessing). One blessing per house: if more than one shrine stands there,
## the one put down first counts, so a second shrine of the same goddess adds nothing.
##
## A new goddess needs an entry in GODDESSES, a shrine kind in HouseFurniture.KINDS (with
## "goddess" set to her id and an entry in HouseFurnisher.SHORT) and English for her texts.
## A new kind of perk needs a line in PERKS and the place in the game that uses it.

## The status icon of the blessing (see StatusIcon and Game.hero_boons).
const KIND := "hausgoettin"

## The goddesses: name, title, what the shrine's text says of her, her perks and the colours
## of her statue and wings.
##   regen    life per second while the hero is in the house (on top of their own recovery);
##            a night slept in the house's bed ends with full life as well
##   mending  how much faster injuries mend (see Injury.rest) for a night slept in the house's
##            bed: 1.0 is +100 %, every night counts twice
const GODDESSES := {
	"maija": {"name": "Maija", "title": "Hüterin der Schlafenden",
		"tale": "Die geflügelte Hausgöttin wacht über den Schlaf und die Wunden derer, die unter ihrem Dach wohnen.",
		"perks": {"regen": 5.0, "mending": 1.0},
		"statue": Color(0.93, 0.9, 0.84), "wings": Color(0.95, 0.78, 0.4)},
}

## One line for each perk, "%s" being the amount.
const PERKS := {
	"regen": "+%s Leben pro Sekunde, solange du in deinem Haus bist",
	"mending": "Verletzungen heilen %s %% schneller, wenn du im Bett deines Hauses schläfst",
}

const LEARN := "Hausschreine: Bei Raumausstatterin Ilse gibt es kleine Schreine mit den Statuen geflügelter Hausgöttinnen. Aufgestellt in deinem selbst gebauten Haus, segnet dich die Göttin, solange du darin bist, jede auf ihre Art. Maija, die Hüterin der Schlafenden, gibt +5 Leben pro Sekunde, und Verletzungen heilen doppelt so schnell, wenn du im Bett deines Hauses schläfst. Je Haus gilt ein Segen: der des Schreins, der zuerst aufgestellt wurde."


static func exists(goddess: String) -> bool:
	return GODDESSES.has(goddess)


## The goddess a furniture kind is the shrine of, or "".
static func of_kind(kind: String) -> String:
	return str(HouseFurniture.KINDS.get(kind, {}).get("goddess", ""))


## The goddess who blesses a house: the one whose shrine was put down first, or "".
static func of_house(furniture: HouseFurniture) -> String:
	if furniture == null:
		return ""
	for p in furniture.placed:
		var goddess := of_kind(p.kind)
		if exists(goddess):
			return goddess
	return ""


## How strong a goddess's perk is (0 for none, or for no goddess).
static func perk(goddess: String, id: String) -> float:
	if not exists(goddess):
		return 0.0
	return float(GODDESSES[goddess].perks.get(id, 0.0))


## The nights a night's rest counts for against an injury (see Injury.rest): 1, or more under
## a goddess who mends.
static func rest_nights(goddess: String) -> int:
	return 1 + roundi(perk(goddess, "mending"))


## "Maija, Hüterin der Schlafenden".
static func full_name(goddess: String) -> String:
	return "%s, %s" % [Lang.t(GODDESSES[goddess].name), Lang.t(GODDESSES[goddess].title)]


## What a goddess gives, one line per perk.
static func perk_lines(goddess: String) -> Array:
	var out := []
	if not exists(goddess):
		return out
	var perks: Dictionary = GODDESSES[goddess].perks
	for id in PERKS:
		if not perks.has(id):
			continue
		var amount := float(perks[id])
		var shown := str(roundi(amount * 100.0)) if id == "mending" else ("%d" % roundi(amount) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount)
		out.append(Lang.t(PERKS[id]) % shown)
	return out


## The status icon's explanation: whose blessing, and what it gives.
static func blessing_text(goddess: String) -> String:
	if not exists(goddess):
		return ""
	var lines := [Lang.t("Segen der Hausgöttin: %s") % full_name(goddess)]
	for line in perk_lines(goddess):
		lines.append("• " + line)
	return "\n".join(lines)


## Whether the hero is inside their own self-built house, and the goddess who blesses it then
## ("" when they are not, or no shrine stands there).
static func active(game: Node) -> String:
	if game == null or not game.level is Outdoor or game.player == null or not game.player.is_inside_tree():
		return ""
	if game.house_furnisher == null or game.house_sketcher == null:
		return ""
	var goddess := of_house(game.house_furnisher.furniture)
	if goddess == "":
		return ""
	return goddess if HouseGround.sheltered(game.house_sketcher.own_shelter, game.player.global_position) else ""


# --- The shrine -----------------------------------------------------------------

## Builds the shrine of `goddess` into `root` (its front towards +z, its back on the cell's back
## edge, on the floor): a stone plinth with a niche under a little gabled roof, and on it the
## goddess with her wings spread and a gilt halo, two candles at her feet. Returns its solids
## ({at, size}, local, as HouseFurnisher.build_piece notes them).
static func build_shrine(root: Node3D, goddess: String) -> Array:
	var info: Dictionary = GODDESSES.get(goddess, GODDESSES.values()[0])
	var stone := HomeStoreFurniture._mat(Color(0.4, 0.38, 0.36), 0.85)
	var pale := HomeStoreFurniture._mat(Color(0.55, 0.52, 0.48), 0.8)
	var marble := HomeStoreFurniture._mat(info.statue, 0.35)
	var gilt := HomeStoreFurniture._mat(info.wings, 0.3, 0.75)
	var z := -0.45
	var shrine := Node3D.new()
	shrine.name = "Shrine"
	root.add_child(shrine)
	# The plinth with a moulding at its top and foot.
	HomeStoreFurniture._add(shrine, HomeStoreFurniture._box(Vector3(1.15, 0.1, 0.85)), pale, Vector3(0, 0.05, z))
	HomeStoreFurniture._add(shrine, HomeStoreFurniture._box(Vector3(1.05, 0.7, 0.75)), stone, Vector3(0, 0.45, z))
	HomeStoreFurniture._add(shrine, HomeStoreFurniture._box(Vector3(1.15, 0.08, 0.85)), pale, Vector3(0, 0.84, z))
	# The niche: a back wall, two pillars, a lintel and a gabled roof.
	HomeStoreFurniture._add(shrine, HomeStoreFurniture._box(Vector3(1.05, 1.2, 0.1)), stone, Vector3(0, 1.48, z - 0.33))
	for side: float in [-1.0, 1.0]:
		HomeStoreFurniture._add(shrine, HomeStoreFurniture._cylinder(0.055, 0.065, 1.1), pale, Vector3(side * 0.44, 1.43, z + 0.28))
	HomeStoreFurniture._add(shrine, HomeStoreFurniture._box(Vector3(1.15, 0.1, 0.8)), pale, Vector3(0, 2.03, z))
	var roof := PrismMesh.new()
	roof.size = Vector3(1.3, 0.32, 0.9)
	HomeStoreFurniture._add(shrine, roof, stone, Vector3(0, 2.24, z))
	# The goddess on a round pedestal: a long robe, shoulders, a head, her wings and a halo.
	var foot := 0.88
	HomeStoreFurniture._add(shrine, HomeStoreFurniture._cylinder(0.15, 0.17, 0.1), pale, Vector3(0, foot + 0.05, z))
	HomeStoreFurniture._add(shrine, HomeStoreFurniture._cylinder(0.07, 0.15, 0.5), marble, Vector3(0, foot + 0.35, z))
	HomeStoreFurniture._add(shrine, HomeStoreFurniture._cylinder(0.05, 0.08, 0.14), marble, Vector3(0, foot + 0.67, z))
	HomeStoreFurniture._add(shrine, HomeStoreFurniture._sphere(0.075), marble, Vector3(0, foot + 0.8, z))
	for side: float in [-1.0, 1.0]:
		var wing := HomeStoreFurniture._add(shrine, HomeStoreFurniture._sphere(0.22), gilt, Vector3(side * 0.17, foot + 0.6, z - 0.08))
		wing.scale = Vector3(0.18, 1.25, 0.6)
		wing.rotation = Vector3(0, side * 0.35, -side * 0.45)
	var halo := TorusMesh.new()
	halo.inner_radius = 0.1
	halo.outer_radius = 0.125
	var ring := HomeStoreFurniture._add(shrine, halo, gilt, Vector3(0, foot + 0.82, z - 0.1))
	ring.rotation.x = PI * 0.5
	# Two votive candles at her feet.
	var wax := HomeStoreFurniture._mat(Color(0.95, 0.92, 0.82), 0.6)
	for side: float in [-1.0, 1.0]:
		HomeStoreFurniture._add(shrine, HomeStoreFurniture._cylinder(0.03, 0.03, 0.12), wax, Vector3(side * 0.32, foot + 0.06, z + 0.22))
		var flame := HomeStoreFurniture._add(shrine, HomeStoreFurniture._sphere(0.018), HomeStoreFurniture._mat(Color(1.0, 0.8, 0.35), 1.0), Vector3(side * 0.32, foot + 0.15, z + 0.22))
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.75, 0.3)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.7, 0.25)
		glow.emission_energy_multiplier = 3.0
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame.material_override = glow
		flame.scale = Vector3(1, 1.8, 1)
	return [{"at": Vector3(0, 0, z), "size": Vector3(1.2, 2.4, 0.9)}]
