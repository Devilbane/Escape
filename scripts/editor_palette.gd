class_name EditorPalette
extends RefCounted
## The tiles of the map workshop (see LevelEditor): every letter of
## Tiles.DUNGEON in groups, with a German name for the player (see Lang) and
## the colour it is drawn in on the workshop's grid.

## [group name, letters]. tests/level_editor.gd checks that every letter of
## Tiles.DUNGEON is in exactly one group, so a new tile shows up here too.
const GROUPS := [
	["Boden und Wände", "#.,?=~j%"],
	["Wege", "PEDK<>^|"],
	["Fallen und Rätsel", "S_QT"],
	["Schätze", "cCkU"],
	["Einrichtung", "bxotfHFBLV+NXy"],
	["Monster", "MAZwGWvsJOeigRY"],
	["Eigene Geschöpfe", "1234567890"],
]

const NAMES := {
	"#": "Wand", ".": "Boden", ",": "Erdboden", "?": "Geheime Wand", "=": "Eisengitter",
	"~": "Glutspalte", "j": "Grubenstempel", "%": "Kristalle",
	"P": "Start", "E": "Ausgang (Treppe)", "D": "Verschlossene Tür", "K": "Schlüssel",
	"<": "Treppe hinauf", ">": "Treppe hinab", "^": "Weg nach unten", "|": "Eisentor",
	"S": "Stachelfalle", "_": "Druckplatte", "Q": "Schwerer Steinblock", "T": "Steintafel",
	"c": "Münze", "C": "Schatztruhe", "k": "Kleine Truhe", "U": "Tresor hinter Gittern",
	"b": "Fässer", "x": "Kisten", "o": "Säule", "t": "Tisch", "f": "Feuerschale",
	"H": "Schrein", "F": "Brunnen", "B": "Bett", "L": "Lagertruhe", "V": "Händler",
	"+": "Platz für Möbel", "N": "Strohecke der Gefährten", "X": "Hort eines Grauens", "y": "Steinpferd",
	"M": "Skelettkrieger", "A": "Skelettschütze", "Z": "Skelettmagier", "w": "Skelettwicht",
	"G": "Skelettkoloss", "W": "Wächter in Rüstung", "v": "Fledermaus", "s": "Schleim",
	"J": "Felstroll", "O": "Bergork", "e": "Eiswolf", "i": "Kristallschleim", "g": "Glutschleim",
	"R": "Drache", "Y": "Bergkönig",
}

## What a few tiles need to work, shown under the palette when picked.
const NOTES := {
	"P": "Genau einer pro Karte: hier beginnt der Held.",
	"E": "Die Treppe steigt nach Norden: darüber gehört Wand hin.",
	"D": "Öffnet sich mit dem Schlüssel (K) oder dem eines Wächters.",
	"K": "Öffnet die verschlossene Tür (D).",
	"?": "Öffnet sich mit einer Fackel in der Nähe als Hebel.",
	"_": "Jede Platte braucht einen schweren Steinblock (Q).",
	"Q": "Der Held schiebt ihn auf eine Druckplatte (_).",
	"|": "Senkt sich, wenn alle Druckplatten belegt sind.",
	"W": "Trägt den Schlüssel, wenn keiner auf der Karte liegt.",
	"H": "Der Held wählt hier eine Gabe.",
	"<": "Nur in Häusern: führt ins nächste Stockwerk.",
	">": "Nur in Häusern: führt ins Stockwerk darunter.",
	"R": "Ein Endgegner: gehört in eine Drachenhöhle.",
	"Y": "Ein Endgegner: gehört in eine Mine.",
}

## Colours on the grid. Letters not listed take their group's colour.
const COLORS := {
	"#": Color(0.17, 0.15, 0.18), ".": Color(0.42, 0.4, 0.38), ",": Color(0.45, 0.36, 0.26),
	"?": Color(0.3, 0.24, 0.36), "=": Color(0.35, 0.38, 0.44), "~": Color(0.85, 0.35, 0.12),
	"P": Color(0.3, 0.75, 0.35), "E": Color(0.95, 0.8, 0.35), "D": Color(0.6, 0.38, 0.2),
	"K": Color(1.0, 0.85, 0.2), "|": Color(0.5, 0.55, 0.62), "S": Color(0.62, 0.6, 0.58),
	"_": Color(0.55, 0.5, 0.4), "Q": Color(0.66, 0.62, 0.55),
}
const GROUP_COLORS := [Color(0.42, 0.4, 0.38), Color(0.8, 0.7, 0.4), Color(0.75, 0.5, 0.35),
		Color(0.95, 0.75, 0.25), Color(0.55, 0.42, 0.3), Color(0.8, 0.28, 0.25), Color(0.55, 0.45, 0.95)]


static func group_of(letter: String) -> int:
	for i in GROUPS.size():
		if GROUPS[i][1].contains(letter):
			return i
	return -1


static func color_of(letter: String) -> Color:
	if COLORS.has(letter):
		return COLORS[letter]
	var g := group_of(letter)
	return GROUP_COLORS[g] if g >= 0 else Color(1, 0, 1)


## The name of a tile in the player's language; a creation's own name for
## its digit when one is given.
static func name_of(letter: String, creations := {}) -> String:
	if creations.has(letter):
		return Creations.label_of(creations[letter])
	if Creations.LETTERS.contains(letter):
		return Lang.t("Freier Platz für ein Geschöpf")
	return Lang.t(NAMES.get(letter, "Unbekannt"))


## Whether a tile is drawn as a wall (no letter on it).
static func is_wall(letter: String) -> bool:
	return letter == "#" or letter == " "
