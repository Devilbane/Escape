class_name MonsterFamilies
extends RefCounted
## Which kinds of monsters live where. Every kind of Enemy belongs to one
## family, and every map in levels/ names the families that naturally live
## there in its header, "monsters: undead, wildlife" (several are allowed).
## A monster put on a map whose header does not name its family is out of
## place: the map workshop says so (LevelMap.validate), the game warns when
## it builds such a level (Level._spawn_enemies), and tests/monster_families.gd
## fails for any shipped map, and for the open air's own spawn tables (the
## risen dead, the weather's foes, the wolf pack, the chief's call).
##
## Families are not factions (see Factions): a faction says who fights whom,
## a family says where a monster belongs.
##
## The nameless horrors (see Horrors) belong to no family on purpose: they
## come up from below wherever they please, so they fit every map.

## The families and their German names (shown in the map workshop).
const FAMILIES := {
	"bandits": "Räuber",
	"undead": "Untote",
	"ghosts": "Geister",
	"wildlife": "Wildtiere",
	"fable": "Sagenwesen",
	"humans": "Menschen",
}
## A horror's family: it fits everywhere (see above).
const HORRORS := "horrors"
## The header key of a map.
const HEADER := "monsters"

## The family of every kind of Enemy (Enemy.KINDS).
const KINDS := {
	# The dead: skeletons of every size.
	"krieger": "undead", "schuetze": "undead", "magier": "undead", "wicht": "undead",
	"koloss": "undead", "waechter": "undead",
	# What is left of the dead when no bones are left: wraiths in the fog.
	"fog_wraith": "ghosts",
	# Robbers of the pass and the cliff archers of the mountain road.
	"halsabschneider": "bandits", "wilderer": "bandits", "schlaeger": "bandits", "hauptmann": "bandits",
	"klippenschuetze": "bandits",
	# Animals and the crawling things of caves.
	"wolf": "wildlife", "eiswolf": "wildlife", "spinne": "wildlife", "spinnenkoenigin": "wildlife",
	"fledermaus": "wildlife", "schleim": "wildlife", "kristallschleim": "wildlife", "glutschleim": "wildlife",
	# The creatures of legend: dragons and their brood, orcs, trolls, the yeti.
	"drache": "fable", "brutdrache": "fable", "grosser_alter": "fable",
	"ork": "fable", "bergork": "fable", "felstroll": "fable", "bergkoenig": "fable", "yeti": "fable",
	# The nameless horrors.
	"hohle_mutter": HORRORS, "bleicher_waechter": HORRORS, "schlund": HORRORS,
}


## The family of a kind ("" for a kind nobody has sorted yet).
static func family_of(kind: String) -> String:
	return KINDS.get(kind, "")


## The families named in a header value ("undead, ghosts"), known ones only.
static func parse(value: String) -> Array[String]:
	var out: Array[String] = []
	for part in value.split(",", false):
		var f := part.strip_edges()
		if FAMILIES.has(f) and not out.has(f):
			out.append(f)
	return out


## The names in a header value that are no family ("undaed" in "undaed, ghosts").
static func unknown(value: String) -> Array[String]:
	var out: Array[String] = []
	for part in value.split(",", false):
		var f := part.strip_edges()
		if f != "" and not FAMILIES.has(f):
			out.append(f)
	return out


## A header value for these families, in the order of FAMILIES.
static func to_value(families: Array) -> String:
	return ", ".join(FAMILIES.keys().filter(func(f): return f in families))


## Whether a monster of `kind` naturally lives where `families` do.
static func fits(kind: String, families: Array) -> bool:
	var f := family_of(kind)
	return f == HORRORS or f in families
