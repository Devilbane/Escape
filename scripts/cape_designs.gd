class_name CapeDesigns
extends RefCounted
## The pictures the hero can wear on the back of their cape, chosen at the
## cape wardrobe on the first floor of the house (see CapeWardrobe, Menus._build_wardrobe).
## The choice is kept in the saved game (Game.save: "cape") as the index into DESIGNS; a game
## saved before the wardrobe has none and wears the first design, the devilbane logo.

## Name (German, translated through Lang), the picture (or "" for a blank cape) and a line about it.
const DESIGNS := [
	{"name": "Devilbane-Wappen", "picture": "res://assets/logo/devilbane_logo.png",
		"text": "Das glühende Zeichen auf dem Rücken."},
	{"name": "Sbinortz", "picture": "res://assets/logo/cape_sbinortz.png",
		"text": "Der Name in goldenen Buchstaben, darunter eine edelsteinbesetzte goldene Krone."},
	{"name": "Schlicht", "picture": "",
		"text": "Ein ganz leerer Umhang."},
]
const DEFAULT := 0


## `value` (from a save, so it can be anything) as a valid design index.
static func checked(value) -> int:
	if value is int or value is float:
		var i := int(value)
		if i >= 0 and i < DESIGNS.size():
			return i
	return DEFAULT


## The picture of a design, or null for the blank cape.
static func texture(design: int) -> Texture2D:
	var path: String = DESIGNS[checked(design)].picture
	return load(path) as Texture2D if path != "" else null
