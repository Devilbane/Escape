class_name EditorPalette
extends RefCounted
## The tiles of the map workshop (see LevelEditor): every letter of
## Tiles.DUNGEON (and of Tiles.OUTDOOR for the open-air map) in groups, with
## a German name for the player (see Lang) and the colour it is drawn in on
## the workshop's grid.

## [group name, letters]. tests/level_editor.gd checks that every letter of
## Tiles.DUNGEON is in exactly one group, so a new tile shows up here too.
const GROUPS := [
	["Boden und Wände", "#.,?=~j%"],
	["Wege", "PEDK<>^|"],
	["Fallen und Rätsel", "S_QT"],
	["Schätze", "cCkU&$"],
	["Einrichtung", "bxotfHFBLmhV+NXy"],
	["Monster", "MAZwGWrnlvsuqJOeigRYd@"],
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
	"H": "Schrein", "F": "Brunnen", "B": "Bett", "L": "Lagertruhe", "m": "Stahlbeschlagene Truhe", "h": "Zutatenbord", "V": "Händler",
	"+": "Platz für Möbel", "N": "Strohecke der Gefährten", "X": "Hort eines Grauens", "y": "Steinpferd",
	"M": "Skelettkrieger", "A": "Skelettschütze", "Z": "Skelettmagier", "w": "Skelettwicht",
	"G": "Skelettkoloss", "W": "Wächter in Rüstung", "v": "Fledermaus", "s": "Schleim",
	"u": "Spinne", "q": "Spinnenkönigin",
	"r": "Totengeist", "n": "Banshee", "l": "Ghul",
	"J": "Felstroll", "O": "Bergork", "e": "Eiswolf", "i": "Kristallschleim", "g": "Glutschleim",
	"R": "Drache", "Y": "Bergkönig",
	"&": "Epische Schatztruhe", "$": "Hort des Großen Alten", "d": "Brutdrache", "@": "Der Große Alte",
}

## What a few tiles need to work, shown under the palette when picked.
const NOTES := {
	"P": "Genau einer pro Karte: hier beginnt der Held.",
	"E": "Die Treppe steigt nach Norden: darüber gehört Wand hin.",
	"D": "Öffnet sich mit dem Schlüssel (K) oder dem eines Wächters.",
	"K": "Öffnet die verschlossene Tür (D).",
	"?": "Öffnet sich mit einer Fackel in der Nähe als Hebel.",
	"_": "Jede Platte braucht einen schweren Steinblock (Q).",
	"Q": "Der Held schiebt ihn auf eine Druckplatte (_), höchstens 5 Felder weit.",
	"|": "Senkt sich, wenn alle Druckplatten belegt sind.",
	"W": "Trägt den Schlüssel, wenn keiner auf der Karte liegt.",
	"H": "Der Held wählt hier eine Gabe.",
	"<": "Nur in Häusern: führt ins nächste Stockwerk.",
	">": "Nur in Häusern: führt ins Stockwerk darunter.",
	"R": "Ein Endgegner: gehört in eine Drachenhöhle.",
	"Y": "Ein Endgegner: gehört in eine Mine.",
	"q": "Ein Endgegner: gehört in ein Spinnenloch.",
	"@": "Unbesiegbar: schläft, bis ihn Lärm weckt. Gehört in den Hort des Großen Alten.",
	"$": "Gold und Ausrüstung: gehört vor den schlafenden Großen Alten (@).",
	"&": "Enthält ein episches Stück und viel Kupfer.",
	"m": "Nur in Häusern: Münzen, Barren, Erz und rohe Edelsteine.",
	"h": "Nur in Häusern: Kräuter, Pilze, Fische, Phiolen und Tierfutter. Gehört an eine Wand.",
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


## The open-air map (see Tiles.OUTDOOR, built by Outdoor): its own letters.
## The digits there are villagers, not creations.
const OUTDOOR_GROUPS := [
	["Gelände", "#.,:~;='"],
	["Natur", "Tdrtpy"],
	["Wege und Eingänge", "PREa([])>"],
	["Gebäude", "hjnmuskowb^IiBL"],
	["Dorf und Lager", "gzlexqFv!@NfC+%*$?"],
	["Dorfbewohner", "0123456789KOGMYZS"],
	["Wilde Gegner", "cAXQWHJU{}-/"],
	["Tiere", "DV&"],
]

const OUTDOOR_NAMES := {
	"#": "Wald", ".": "Wiese", ",": "Pfad", ":": "Gepflasterter Platz", "~": "Dorfteich",
	";": "Teich in der Wolfsmulde", "=": "Fels der Berge", "'": "Geröll",
	"T": "Baum", "d": "Toter Baum", "r": "Felsen", "t": "Baumstumpf mit Holz", "p": "Kürbisse", "y": "Kürbisfeld",
	"P": "Start vor der Gruft", "R": "Die Gruft", "E": "Weg in die Drachenhöhle", "a": "Tor im Zaun",
	"(": "Dunkles Loch", ">": "Findling über der verborgenen Grotte", "?": "Vergrabener Schatz", "[": "Bergschenke", "]": "Mineneingang", ")": "Höhle des Großen Alten",
	"h": "Haus", "j": "Schmiede", "n": "Wirtshaus", "m": "Markt", "u": "Windmühle", "s": "Tempel",
	"k": "Amt der Krone", "o": "Post", "w": "Abenteurergilde", "b": "Bank", "^": "Weberzeile",
	"I": "Hauswand", "i": "Holzboden", "B": "Bett", "L": "Truhe",
	"g": "Grab", "z": "Friedhofszaun", "l": "Laterne", "e": "Fässer, Kisten und Säcke", "x": "Bank zum Sitzen",
	"q": "Brunnen", "F": "Heilbrunnen", "v": "Sockel mit Futterkorb", "!": "Kopfgeldbrett",
	"@": "Platz des fahrenden Händlers", "N": "Zelt", "f": "Lagerfeuer", "C": "Schatztruhe der Räuber",
	"+": "Werkbank für Feinarbeit", "%": "Schleifrad", "*": "Alchemietisch", "$": "Deine Lagertruhe",
	"0": "Dorfvorsteher", "1": "Schmied", "2": "Bäuerin", "3": "Holzfäller", "4": "Wache", "5": "Zecher",
	"6": "Krämerin", "7": "Kind", "8": "Gelehrter", "9": "Wasserträgerin", "K": "Herold der Krone",
	"O": "Priesterin", "G": "Gildenmeister", "M": "Postmeister", "Y": "Bankier", "Z": "Barbier", "S": "Steinmetz",
	"c": "Halsabschneider", "A": "Wilderer", "X": "Schläger", "Q": "Räuberhauptmann", "W": "Wolf", "H": "Ork",
	"J": "Yeti", "U": "Spinne", "{": "Felstroll", "}": "Bergork", "-": "Eiswolf", "/": "Klippenschütze",
	"D": "Reh", "V": "Hirsch", "&": "Fuchs",
}

const OUTDOOR_NOTES := {
	"P": "Genau einer pro Karte: hier tritt der Held aus der Gruft.",
	"(": "Die Löcher zählen von oben nach unten: Loch n führt zu „building: loch<n>“.",
	"]": "Die Minen zählen von Westen nach Osten: Mine n führt zu „building: mine<n>“.",
	"?": "Erst sichtbar, wenn der Held die Schatzkarte aus einer Flaschenpost gelesen hat. Genau einer pro Karte.",
	">": "Rollt beiseite, wenn der Held die Schatzkarte gelesen hat, und führt zu „building: grotte“. Genau einer pro Karte.",
	"h": "Ein Gebäude ist ein Rechteck aus demselben Zeichen.",
	"^": "Ein Haus je Feld an der Vorderseite, von Westen nach Osten gezählt.",
}

const OUTDOOR_COLORS := {
	"#": Color(0.12, 0.22, 0.12), ".": Color(0.36, 0.5, 0.28), ",": Color(0.55, 0.45, 0.3),
	":": Color(0.55, 0.53, 0.5), "~": Color(0.25, 0.45, 0.7), ";": Color(0.2, 0.35, 0.6),
	"=": Color(0.35, 0.33, 0.36), "'": Color(0.5, 0.48, 0.45), "P": Color(0.3, 0.75, 0.35),
}
const OUTDOOR_GROUP_COLORS := [Color(0.36, 0.5, 0.28), Color(0.25, 0.4, 0.2), Color(0.8, 0.7, 0.4),
		Color(0.62, 0.42, 0.3), Color(0.55, 0.42, 0.3), Color(0.35, 0.55, 0.85), Color(0.8, 0.28, 0.25), Color(0.75, 0.6, 0.35)]


static func groups(outdoor := false) -> Array:
	return OUTDOOR_GROUPS if outdoor else GROUPS


static func group_of(letter: String, outdoor := false) -> int:
	var all := groups(outdoor)
	for i in all.size():
		if all[i][1].contains(letter):
			return i
	return -1


static func color_of(letter: String, outdoor := false) -> Color:
	var colors: Dictionary = OUTDOOR_COLORS if outdoor else COLORS
	if colors.has(letter):
		return colors[letter]
	var g := group_of(letter, outdoor)
	var group_colors: Array = OUTDOOR_GROUP_COLORS if outdoor else GROUP_COLORS
	return group_colors[g] if g >= 0 else Color(1, 0, 1)


## The name of a tile in the player's language; a creation's own name for
## its digit when one is given.
static func name_of(letter: String, creations := {}, outdoor := false) -> String:
	if outdoor:
		return Lang.t(OUTDOOR_NAMES.get(letter, "Unbekannt"))
	if creations.has(letter):
		return Creations.label_of(creations[letter])
	if Creations.LETTERS.contains(letter):
		return Lang.t("Freier Platz für ein Geschöpf")
	return Lang.t(NAMES.get(letter, "Unbekannt"))


static func note_of(letter: String, outdoor := false) -> String:
	var notes: Dictionary = OUTDOOR_NOTES if outdoor else NOTES
	return Lang.t(notes[letter]) if notes.has(letter) else ""


## Whether a tile is drawn as a wall (no letter on it).
static func is_wall(letter: String, outdoor := false) -> bool:
	return letter == " " or (letter == "#" and not outdoor)
