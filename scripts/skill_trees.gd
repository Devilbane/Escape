class_name SkillTrees
extends RefCounted
## The skill trees: every skill the game is growing towards, in eight trees,
## each with a basic row (20 levels), an advanced row (15) and a master row
## (10). The design is in the progression research (skill trees and gear,
## section 5); this is the part of it that is data.
##
## A skill is in the game when it is in Training.SKILLS or Training.CRAFTS
## ("in_game" here); the others are shown in the tree, with what they need
## and what they open, so the player can see where the hero is heading, but
## they cannot be trained yet. Each new tree skill that is built flips its
## "in_game" and gets its place in Training.
##
## Keys of a skill:
##   name: the German name (an in-game skill takes it from Training)
##   tree, row: where it stands ("basic", "advanced" or "master")
##   levels: the most levels it will have once the tree is complete
##   attributes: what governs it
##   needs: skill id -> level that must be reached first
##   attribute_needs: attribute id -> value that must be reached first
##   in_game: trained and used by the game today

const TREES := [
	["kampf", "Kampf"],
	["gewandtheit", "Gewandtheit"],
	["koerper", "Körper"],
	["wissen", "Wissen"],
	["feinhandwerk", "Feinhandwerk"],
	["alchemie_kueche", "Alchemie & Küche"],
	["arkanum", "Arkanum"],
	["schmiede", "Schmiede"],
]
const ROWS := ["basic", "advanced", "master"]

const ALL := {
	# --- Kampf
	"klingen": {"name": "Klingen", "tree": "kampf", "row": "basic", "levels": 20, "attributes": ["staerke", "geschick"], "in_game": true,},
	"aexte": {"name": "Äxte & Hämmer", "tree": "kampf", "row": "basic", "levels": 20, "attributes": ["staerke"], "in_game": true,},
	"blocken": {"name": "Blocken", "tree": "kampf", "row": "basic", "levels": 20, "attributes": ["staerke", "geschick"], "in_game": true,},
	"ruestung": {"name": "Rüstung tragen", "tree": "kampf", "row": "basic", "levels": 20, "attributes": ["staerke"], "in_game": true,},
	"schwertkampf": {"name": "Schwertkampf", "tree": "kampf", "row": "advanced", "levels": 15, "attributes": ["staerke", "geschick"], "needs": {"klingen": 10},},
	"wuchtkampf": {"name": "Wuchtkampf", "tree": "kampf", "row": "advanced", "levels": 15, "attributes": ["staerke"], "needs": {"aexte": 10}, "attribute_needs": {"staerke": 15},},
	"schildkampf": {"name": "Schildkampf", "tree": "kampf", "row": "advanced", "levels": 15, "attributes": ["staerke", "geschick"], "needs": {"blocken": 10},},
	"belastungsgewoehnung": {"name": "Belastungsgewöhnung", "tree": "kampf", "row": "advanced", "levels": 15, "attributes": ["staerke", "konstitution"], "needs": {"ruestung": 10}, "attribute_needs": {"konstitution": 14},},
	"klingenmeister": {"name": "Klingenmeister", "tree": "kampf", "row": "master", "levels": 10, "attributes": ["staerke", "geschick"], "needs": {"schwertkampf": 12}, "attribute_needs": {"geschick": 18},},
	"schlachtenbrecher": {"name": "Schlachtenbrecher", "tree": "kampf", "row": "master", "levels": 10, "attributes": ["staerke"], "needs": {"wuchtkampf": 12, "zaehigkeit": 8},},
	"schildwall": {"name": "Schildwall", "tree": "kampf", "row": "master", "levels": 10, "attributes": ["staerke", "konstitution"], "needs": {"schildkampf": 12, "belastungsgewoehnung": 8},},
	# --- Gewandtheit
	"werfen": {"name": "Messerwurf", "tree": "gewandtheit", "row": "basic", "levels": 20, "attributes": ["geschick"], "in_game": true,},
	"schleichen": {"name": "Schleichen", "tree": "gewandtheit", "row": "basic", "levels": 20, "attributes": ["geschick", "intelligenz"], "in_game": true,},
	"akrobatik": {"name": "Akrobatik", "tree": "gewandtheit", "row": "basic", "levels": 20, "attributes": ["geschick", "tempo"],},
	"fingerfertigkeit": {"name": "Fingerfertigkeit", "tree": "gewandtheit", "row": "basic", "levels": 20, "attributes": ["geschick", "intuition"],},
	"bogenschiessen": {"name": "Bogenschießen", "tree": "gewandtheit", "row": "advanced", "levels": 15, "attributes": ["geschick"], "needs": {"werfen": 6, "bogenbau": 1}, "attribute_needs": {"geschick": 14},},
	"meucheln": {"name": "Meucheln", "tree": "gewandtheit", "row": "advanced", "levels": 15, "attributes": ["geschick", "intuition"], "needs": {"schleichen": 10, "klingen": 5},},
	"ausweichen": {"name": "Ausweichen", "tree": "gewandtheit", "row": "advanced", "levels": 15, "attributes": ["geschick", "tempo"], "needs": {"akrobatik": 10},},
	"schloesser_fallen": {"name": "Schlösser & Fallen", "tree": "gewandtheit", "row": "advanced", "levels": 15, "attributes": ["geschick", "intuition"], "needs": {"fingerfertigkeit": 8, "erkunden": 5},},
	"scharfschuetze": {"name": "Scharfschütze", "tree": "gewandtheit", "row": "master", "levels": 10, "attributes": ["geschick", "intuition"], "needs": {"bogenschiessen": 12}, "attribute_needs": {"intuition": 16},},
	"schattenklinge": {"name": "Schattenklinge", "tree": "gewandtheit", "row": "master", "levels": 10, "attributes": ["geschick", "intuition"], "needs": {"meucheln": 12, "gifte": 5},},
	"klingentaenzer": {"name": "Klingentänzer", "tree": "gewandtheit", "row": "master", "levels": 10, "attributes": ["geschick", "tempo"], "needs": {"ausweichen": 12, "klingen": 15},},
	"meisterdieb": {"name": "Meisterdieb", "tree": "gewandtheit", "row": "master", "levels": 10, "attributes": ["geschick", "intuition"], "needs": {"schloesser_fallen": 12, "feinmechanik": 5},},
	# --- Körper
	"zaehigkeit": {"name": "Zähigkeit", "tree": "koerper", "row": "basic", "levels": 20, "attributes": ["konstitution"],},
	"ausdauer": {"name": "Ausdauer", "tree": "koerper", "row": "basic", "levels": 20, "attributes": ["konstitution", "tempo"],},
	"erholung": {"name": "Erholung", "tree": "koerper", "row": "basic", "levels": 20, "attributes": ["konstitution", "weisheit"],},
	"trinkfestigkeit": {"name": "Trinkfestigkeit", "tree": "koerper", "row": "basic", "levels": 20, "attributes": ["konstitution"],},
	"eisenhaut": {"name": "Eisenhaut", "tree": "koerper", "row": "advanced", "levels": 15, "attributes": ["konstitution"], "needs": {"zaehigkeit": 10},},
	"langlaeufer": {"name": "Langläufer", "tree": "koerper", "row": "advanced", "levels": 15, "attributes": ["konstitution", "tempo"], "needs": {"ausdauer": 10},},
	"lagerleben": {"name": "Lagerleben", "tree": "koerper", "row": "advanced", "levels": 15, "attributes": ["konstitution", "weisheit"], "needs": {"erholung": 8, "kochen": 5},},
	"unbeugsam": {"name": "Unbeugsam", "tree": "koerper", "row": "master", "levels": 10, "attributes": ["konstitution", "weisheit"], "needs": {"eisenhaut": 12}, "attribute_needs": {"weisheit": 16},},
	"zweiter_atem": {"name": "Zweiter Atem", "tree": "koerper", "row": "master", "levels": 10, "attributes": ["konstitution"], "needs": {"langlaeufer": 10, "erholung": 12},},
	# --- Wissen
	"erkunden": {"name": "Erkunden", "tree": "wissen", "row": "basic", "levels": 20, "attributes": ["intelligenz"], "in_game": true,},
	"naturkunde": {"name": "Naturkunde", "tree": "wissen", "row": "basic", "levels": 20, "attributes": ["intelligenz", "intuition"],},
	"heilkunde": {"name": "Heilkunde", "tree": "wissen", "row": "basic", "levels": 20, "attributes": ["intelligenz", "geschick"],},
	"schriftkunde": {"name": "Schriftkunde", "tree": "wissen", "row": "basic", "levels": 20, "attributes": ["intelligenz"],},
	"monsterkunde": {"name": "Monsterkunde", "tree": "wissen", "row": "basic", "levels": 20, "attributes": ["intelligenz"],},
	"tierkunde": {"name": "Tierkunde", "tree": "wissen", "row": "advanced", "levels": 15, "attributes": ["intuition"], "needs": {"naturkunde": 8}, "attribute_needs": {"intuition": 14},},
	"kraeuterkunde": {"name": "Kräuterkunde", "tree": "wissen", "row": "advanced", "levels": 15, "attributes": ["intelligenz", "intuition"], "needs": {"naturkunde": 8},},
	"wundarznei": {"name": "Wundarznei", "tree": "wissen", "row": "advanced", "levels": 15, "attributes": ["intelligenz", "geschick"], "needs": {"heilkunde": 10},},
	"runenkunde": {"name": "Runenkunde", "tree": "wissen", "row": "advanced", "levels": 15, "attributes": ["intelligenz"], "needs": {"schriftkunde": 10},},
	"monsterjagd": {"name": "Monsterjagd", "tree": "wissen", "row": "advanced", "levels": 15, "attributes": ["intelligenz"], "needs": {"monsterkunde": 10},},
	"bestienmeister": {"name": "Bestienmeister", "tree": "wissen", "row": "master", "levels": 10, "attributes": ["intuition"], "needs": {"tierkunde": 12},},
	"gelehrter": {"name": "Gelehrter", "tree": "wissen", "row": "master", "levels": 10, "attributes": ["intelligenz", "weisheit"], "needs": {"runenkunde": 10, "monsterjagd": 10},},
	# --- Feinhandwerk
	"feinschmieden": {"name": "Feinschmieden", "tree": "feinhandwerk", "row": "basic", "levels": 20, "attributes": ["geschick", "intelligenz"], "in_game": true,},
	"holzarbeit": {"name": "Holzarbeit", "tree": "feinhandwerk", "row": "basic", "levels": 20, "attributes": ["geschick", "staerke"],},
	"weben": {"name": "Weben", "tree": "feinhandwerk", "row": "basic", "levels": 20, "attributes": ["geschick"],},
	"lederarbeit": {"name": "Lederarbeit", "tree": "feinhandwerk", "row": "basic", "levels": 20, "attributes": ["geschick", "staerke"],},
	"edelsteinschleifen": {"name": "Edelsteinschleifen", "tree": "feinhandwerk", "row": "advanced", "levels": 15, "attributes": ["geschick", "intuition"], "needs": {"feinschmieden": 8}, "attribute_needs": {"intuition": 13},},
	"feinmechanik": {"name": "Feinmechanik", "tree": "feinhandwerk", "row": "advanced", "levels": 15, "attributes": ["geschick", "intelligenz"], "needs": {"feinschmieden": 10, "fingerfertigkeit": 5},},
	"bogenbau": {"name": "Bogenbau", "tree": "feinhandwerk", "row": "advanced", "levels": 15, "attributes": ["geschick", "staerke"], "needs": {"holzarbeit": 8},},
	"schneiderei": {"name": "Schneiderei", "tree": "feinhandwerk", "row": "advanced", "levels": 15, "attributes": ["geschick"], "needs": {"weben": 8},},
	"juwelier": {"name": "Juwelier", "tree": "feinhandwerk", "row": "master", "levels": 10, "attributes": ["geschick", "intelligenz"], "needs": {"edelsteinschleifen": 12},},
	"verzaubern": {"name": "Verzaubern", "tree": "feinhandwerk", "row": "master", "levels": 10, "attributes": ["intelligenz", "weisheit"], "needs": {"edelsteinschleifen": 10, "magie": 12},},
	# --- Alchemie & Küche
	"kochen": {"name": "Kochen", "tree": "alchemie_kueche", "row": "basic", "levels": 20, "attributes": ["intuition", "intelligenz"],},
	"alchemie": {"name": "Alchemie", "tree": "alchemie_kueche", "row": "basic", "levels": 20, "attributes": ["intelligenz"], "in_game": true,},
	"angeln": {"name": "Angeln", "tree": "alchemie_kueche", "row": "basic", "levels": 20, "attributes": ["geschick", "intuition"],},
	"gerben": {"name": "Gerben", "tree": "alchemie_kueche", "row": "advanced", "levels": 15, "attributes": ["intelligenz", "staerke"], "needs": {"alchemie": 5},},
	"gifte": {"name": "Gifte", "tree": "alchemie_kueche", "row": "advanced", "levels": 15, "attributes": ["intelligenz"], "needs": {"alchemie": 8},},
	"saeuren_salze": {"name": "Säuren & Salze", "tree": "alchemie_kueche", "row": "advanced", "levels": 15, "attributes": ["intelligenz"], "needs": {"alchemie": 10},},
	"elixiere": {"name": "Elixiere", "tree": "alchemie_kueche", "row": "master", "levels": 10, "attributes": ["intelligenz", "weisheit"], "needs": {"alchemie": 15, "magie": 8},},
	"transmutation": {"name": "Transmutation", "tree": "alchemie_kueche", "row": "master", "levels": 10, "attributes": ["intelligenz"], "needs": {"saeuren_salze": 12, "magie": 12},},
	# --- Arkanum
	"magie": {"name": "Arkane Energie", "tree": "arkanum", "row": "basic", "levels": 20, "attributes": ["intelligenz"], "in_game": true,},
	"meditation": {"name": "Meditation", "tree": "arkanum", "row": "basic", "levels": 20, "attributes": ["weisheit", "intelligenz"],},
	"elementarmagie": {"name": "Elementarmagie", "tree": "arkanum", "row": "advanced", "levels": 15, "attributes": ["intelligenz"], "needs": {"magie": 10},},
	"schutzzauber": {"name": "Schutzzauber", "tree": "arkanum", "row": "advanced", "levels": 15, "attributes": ["weisheit"], "needs": {"magie": 8, "meditation": 5},},
	"bannmagie": {"name": "Bannmagie", "tree": "arkanum", "row": "advanced", "levels": 15, "attributes": ["intelligenz", "weisheit"], "needs": {"magie": 8, "runenkunde": 5},},
	"heilzauber": {"name": "Heilzauber", "tree": "arkanum", "row": "advanced", "levels": 15, "attributes": ["weisheit"], "needs": {"magie": 8, "heilkunde": 8},},
	"erzmagier": {"name": "Erzmagier", "tree": "arkanum", "row": "master", "levels": 10, "attributes": ["intelligenz"], "needs": {"elementarmagie": 12}, "attribute_needs": {"intelligenz": 20},},
	"runenmagie": {"name": "Runenmagie", "tree": "arkanum", "row": "master", "levels": 10, "attributes": ["intelligenz", "weisheit"], "needs": {"bannmagie": 10, "runenkunde": 10},},
	# --- Schmiede
	"bergbau": {"name": "Bergbau", "tree": "schmiede", "row": "basic", "levels": 20, "attributes": ["staerke"],},
	"stahlkochen": {"name": "Stahlkochen", "tree": "schmiede", "row": "basic", "levels": 20, "attributes": ["intelligenz"], "in_game": true,},
	"schmiedekunst": {"name": "Schmiedekunst", "tree": "schmiede", "row": "basic", "levels": 20, "attributes": ["staerke"], "in_game": true,},
	"tiegelstahl": {"name": "Tiegelstahl", "tree": "schmiede", "row": "advanced", "levels": 15, "attributes": ["intelligenz"], "needs": {"stahlkochen": 10, "saeuren_salze": 5},},
	"waffenschmied": {"name": "Waffenschmied", "tree": "schmiede", "row": "advanced", "levels": 15, "attributes": ["staerke"], "needs": {"schmiedekunst": 10},},
	"ruestungsschmied": {"name": "Rüstungsschmied", "tree": "schmiede", "row": "advanced", "levels": 15, "attributes": ["staerke"], "needs": {"schmiedekunst": 10},},
	"meisterschmied": {"name": "Meisterschmied", "tree": "schmiede", "row": "master", "levels": 10, "attributes": ["staerke", "intelligenz"], "needs": {"waffenschmied": 12, "tiegelstahl": 8},},
	"runenschmied": {"name": "Runenschmied", "tree": "schmiede", "row": "master", "levels": 10, "attributes": ["intelligenz"], "needs": {"meisterschmied": 5, "runenkunde": 10, "magie": 10},},
}


static func tree_name(tree: String) -> String:
	for t in TREES:
		if t[0] == tree:
			return t[1]
	return tree


## The skills of a tree's row, in the order they are drawn.
static func in_row(tree: String, row: String) -> Array:
	var out := []
	for id in ALL:
		if ALL[id].tree == tree and ALL[id].row == row:
			out.append(id)
	return out


static func in_game(id: String) -> bool:
	return ALL.get(id, {}).get("in_game", false)


## The skill's German name; one the game has already keeps the name it has there.
static func name_of(id: String) -> String:
	if Training.SKILLS.has(id):
		return Training.SKILLS[id].name
	if Training.CRAFTS.has(id):
		return Training.CRAFTS[id].name
	return ALL[id].name


## The most levels the game lets the hero train in a skill today.
static func level_cap(id: String) -> int:
	return Training.skill_max(id) if in_game(id) else 0


## The level the hero has in a skill (0 for one the game does not have yet).
static func level_of(hero: Player, id: String) -> int:
	return hero.trained_level(id) if in_game(id) else 0


## "known" (trained), "open" (can be trained now) or "locked" (something it
## needs is missing) for a skill the game has, "planned" for one it does not.
static func status(hero: Player, id: String) -> String:
	if not in_game(id):
		return "planned"
	if level_of(hero, id) > 0:
		return "known"
	return "locked" if not unmet(hero, id).is_empty() else "open"


## What a skill still needs: entries {"skill": bool, "id", "level"} for each
## skill level and attribute value the hero has not reached.
static func unmet(hero: Player, id: String) -> Array:
	var out := []
	for entry in needs_of(id):
		var have := level_of(hero, entry.id) if entry.skill else hero.attribute(entry.id)
		if have < entry.level:
			out.append(entry)
	return out


## Everything a skill needs, skills first: {"skill": bool, "id", "level"}.
static func needs_of(id: String) -> Array:
	var out := []
	var skill: Dictionary = ALL[id]
	for need in skill.get("needs", {}):
		out.append({"skill": true, "id": need, "level": int(skill.needs[need])})
	for need in skill.get("attribute_needs", {}):
		out.append({"skill": false, "id": need, "level": int(skill.attribute_needs[need])})
	return out


## The skills that need this one.
static func opens(id: String) -> Array:
	var out := []
	for other in ALL:
		if ALL[other].get("needs", {}).has(id):
			out.append(other)
	return out


## Whether a skill needs a skill of another tree (drawn with an arrow).
static func crosses_trees(id: String) -> bool:
	for need in ALL[id].get("needs", {}):
		if ALL[need].tree != ALL[id].tree:
			return true
	return false
