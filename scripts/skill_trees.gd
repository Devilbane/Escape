class_name SkillTrees
extends RefCounted
## The skill trees: the hero's talents, drawn as a broad, flat tree in five
## tabs. The design is the user's own mind map (levels are still to be tuned):
## four affinities (Body, Soul, Nature, Craft) that tell where a hero's talents
## lie, the attributes as skills under Body and Soul, and the skills that grow
## from them. The Combat tab holds the weapon skills; their root, Weapons,
## needs the attributes of the Body tab.
##
## A node is one of four things:
##   affinity: Body, Soul, Nature, Craft. Never trained and never levelled; they
##     are given at character creation. For the "needs" of other skills an
##     affinity is always met.
##   attribute: Strength, Constitution, Dexterity, Intelligence, Intuition and
##     Wisdom, backed by the hero's attributes (Training.ATTRIBUTES): the level
##     is the value above its start, 0 to 20, so the damage, life and learning
##     speed they give stay as they are. The hero starts with the first level
##     of each, so a "needs level 1" on an attribute is met from the start.
##     Speed (Tempo) and jump length are results of Dexterity, the load and the
##     gear, not skills.
##   legacy: a skill the game trains today under its old German id
##     (Training.SKILLS and Training.CRAFTS). The saved training keeps its old
##     keys, so no hero loses anything; the tree only reads it. A node may sum
##     up several old ids (Metalwork is forging and steel making; its level is
##     the higher one).
##   none of these: planned, shown with what it needs, not trainable yet.
##
## Needs only count what the game has: a need on a planned skill is not asked
## for yet, and nothing in the game is locked by the tree today.
##
## Keys of a node:
##   name: the German name
##   tree, row: where it stands ("basic", "advanced" or "master": the band of
##     the tab it is drawn in; a node never needs one of a higher band)
##   levels: the most levels it will have once the tree is complete
##   attributes: the attributes that govern a legacy skill's rolls
##   needs: skill id -> level that must be reached first

const TREES := [
	["koerper", "Körper"],
	["kampf", "Kampf"],
	["seele", "Seele"],
	["natur", "Natur"],
	["handwerk", "Handwerk"],
]
const ROWS := ["basic", "advanced", "master"]

const ALL := {
	"body": {"name": "Körper", "tree": "koerper", "row": "basic", "levels": 20, "attributes": [], "affinity": true,},
	"strength": {"name": "Stärke", "tree": "koerper", "row": "basic", "levels": 20, "attributes": [], "needs": {"body": 1}, "attribute": "staerke",},
	"constitution": {"name": "Konstitution", "tree": "koerper", "row": "basic", "levels": 20, "attributes": [], "needs": {"body": 1}, "attribute": "konstitution",},
	"dexterity": {"name": "Geschick", "tree": "koerper", "row": "basic", "levels": 20, "attributes": [], "needs": {"body": 1}, "attribute": "geschick",},
	"climbing": {"name": "Klettern", "tree": "koerper", "row": "advanced", "levels": 20, "attributes": ["staerke", "geschick"], "needs": {"body": 1, "strength": 1, "constitution": 1, "dexterity": 1}, "legacy": ["klettern"],},
	"weaponless_fighting": {"name": "Waffenloser Kampf", "tree": "koerper", "row": "advanced", "levels": 20, "attributes": [], "needs": {"body": 1, "strength": 1, "constitution": 1, "dexterity": 1},},
	"stealth": {"name": "Schleichen", "tree": "koerper", "row": "advanced", "levels": 20, "attributes": ["geschick", "intelligenz"], "needs": {"dexterity": 1, "body": 1}, "legacy": ["schleichen"],},
	"armour": {"name": "Rüstung tragen", "tree": "koerper", "row": "advanced", "levels": 20, "attributes": ["staerke"], "needs": {"constitution": 1, "strength": 1}, "legacy": ["ruestung"],},
	"mountain_breath": {"name": "Bergatem", "tree": "koerper", "row": "master", "levels": 20, "attributes": ["staerke", "konstitution"], "needs": {"climbing": 1, "constitution": 1}, "legacy": ["bergatem"],},
	"windstep": {"name": "Windschritt", "tree": "koerper", "row": "master", "levels": 20, "attributes": ["geschick", "tempo"], "needs": {"dexterity": 1}, "legacy": ["windschritt"],},
	"weapons": {"name": "Waffen", "tree": "kampf", "row": "basic", "levels": 20, "attributes": [], "needs": {"dexterity": 1, "strength": 1, "constitution": 1},},
	"axe_fighting": {"name": "Axtkampf", "tree": "kampf", "row": "advanced", "levels": 20, "attributes": ["staerke"], "needs": {"weapons": 1}, "legacy": ["aexte"],},
	"sword_fighting": {"name": "Schwertkampf", "tree": "kampf", "row": "advanced", "levels": 20, "attributes": ["staerke", "geschick"], "needs": {"weapons": 1}, "legacy": ["klingen"],},
	"shield": {"name": "Schild", "tree": "kampf", "row": "advanced", "levels": 20, "attributes": [], "needs": {"weapons": 1},},
	"ranged_arms": {"name": "Fernwaffen", "tree": "kampf", "row": "advanced", "levels": 20, "attributes": [], "needs": {"weapons": 1},},
	"cleave": {"name": "Spalten", "tree": "kampf", "row": "master", "levels": 20, "attributes": [], "needs": {"axe_fighting": 1},},
	"block": {"name": "Blocken", "tree": "kampf", "row": "master", "levels": 20, "attributes": ["staerke", "geschick"], "needs": {"shield": 1}, "legacy": ["blocken"],},
	"parry": {"name": "Parieren", "tree": "kampf", "row": "master", "levels": 20, "attributes": [], "needs": {"shield": 1, "sword_fighting": 1},},
	"pierce": {"name": "Durchbohren", "tree": "kampf", "row": "master", "levels": 20, "attributes": [], "needs": {"sword_fighting": 1},},
	"shield_hide": {"name": "Schildversteck", "tree": "kampf", "row": "master", "levels": 20, "attributes": [], "needs": {"shield": 1, "throwing_knives": 1},},
	"throwing_knives": {"name": "Messerwurf", "tree": "kampf", "row": "master", "levels": 20, "attributes": ["geschick"], "needs": {"ranged_arms": 1}, "legacy": ["werfen"],},
	"soul": {"name": "Seele", "tree": "seele", "row": "basic", "levels": 20, "attributes": [], "affinity": true,},
	"intelligence": {"name": "Intelligenz", "tree": "seele", "row": "basic", "levels": 20, "attributes": [], "needs": {"soul": 1}, "attribute": "intelligenz",},
	"intuition": {"name": "Intuition", "tree": "seele", "row": "basic", "levels": 20, "attributes": [], "needs": {"soul": 1}, "attribute": "intuition",},
	"wisdom": {"name": "Weisheit", "tree": "seele", "row": "basic", "levels": 20, "attributes": [], "needs": {"soul": 1}, "attribute": "weisheit",},
	"spirituality": {"name": "Spiritualität", "tree": "seele", "row": "basic", "levels": 20, "attributes": [], "needs": {"soul": 1},},
	"arcana": {"name": "Arkana", "tree": "seele", "row": "advanced", "levels": 20, "attributes": ["intelligenz"], "needs": {"intelligence": 1, "wisdom": 1, "intuition": 1, "soul": 1}, "legacy": ["magie"],},
	"exploring": {"name": "Erkunden", "tree": "seele", "row": "advanced", "levels": 20, "attributes": ["intelligenz"], "needs": {"intuition": 1, "intelligence": 1}, "legacy": ["erkunden"],},
	"negotiation": {"name": "Verhandeln", "tree": "seele", "row": "advanced", "levels": 20, "attributes": [], "needs": {"soul": 1, "intuition": 1, "wisdom": 1},},
	"arcane_lore": {"name": "Arkankunde", "tree": "seele", "row": "master", "levels": 20, "attributes": [], "needs": {"arcana": 1, "wisdom": 1, "soul": 1},},
	"necromancy": {"name": "Nekromantie", "tree": "seele", "row": "master", "levels": 20, "attributes": ["intelligenz"], "needs": {"arcana": 1}, "legacy": ["nekromantie"],},
	"spiritual_lore": {"name": "Geisterkunde", "tree": "seele", "row": "master", "levels": 20, "attributes": [], "needs": {"wisdom": 1, "intuition": 1, "spirituality": 1},},
	"still_centre": {"name": "Stille Mitte", "tree": "seele", "row": "master", "levels": 20, "attributes": ["weisheit"], "needs": {"wisdom": 1}, "legacy": ["stille_mitte"],},
	"nature": {"name": "Natur", "tree": "natur", "row": "basic", "levels": 20, "attributes": [], "affinity": true,},
	"flora": {"name": "Flora", "tree": "natur", "row": "basic", "levels": 20, "attributes": [], "needs": {"nature": 1, "wisdom": 1, "intuition": 1},},
	"fauna": {"name": "Fauna", "tree": "natur", "row": "basic", "levels": 20, "attributes": [], "needs": {"nature": 1, "wisdom": 1, "intuition": 1},},
	"ore_minerals": {"name": "Erze & Mineralien", "tree": "natur", "row": "basic", "levels": 20, "attributes": [], "needs": {"nature": 1, "wisdom": 1, "intuition": 1},},
	"animal_lore": {"name": "Tierkunde", "tree": "natur", "row": "advanced", "levels": 20, "attributes": [], "needs": {"fauna": 1, "intuition": 1, "wisdom": 1, "nature": 1},},
	"magic_creatures_lore": {"name": "Zauberwesenkunde", "tree": "natur", "row": "master", "levels": 20, "attributes": [], "needs": {"arcana": 1, "animal_lore": 1, "intelligence": 1, "arcane_lore": 1, "nature": 1},},
	"craft": {"name": "Handwerk", "tree": "handwerk", "row": "basic", "levels": 20, "attributes": [], "affinity": true,},
	"lockpicking": {"name": "Schlösserknacken", "tree": "handwerk", "row": "basic", "levels": 20, "attributes": [], "needs": {"craft": 1, "dexterity": 1, "intuition": 1},},
	"metalwork": {"name": "Metallarbeit", "tree": "handwerk", "row": "basic", "levels": 20, "attributes": ["staerke"], "needs": {"dexterity": 1, "constitution": 1, "ore_minerals": 1, "craft": 1}, "legacy": ["schmiedekunst", "stahlkochen"],},
	"gemcutting": {"name": "Edelsteinschleifen", "tree": "handwerk", "row": "basic", "levels": 20, "attributes": [], "needs": {"dexterity": 1, "ore_minerals": 1, "craft": 1},},
	"fine_metalwork": {"name": "Feine Metallarbeit", "tree": "handwerk", "row": "advanced", "levels": 20, "attributes": ["geschick", "intelligenz"], "needs": {"metalwork": 1, "dexterity": 1, "craft": 1}, "legacy": ["feinschmieden"],},
	"alchemy": {"name": "Alchemie", "tree": "handwerk", "row": "advanced", "levels": 20, "attributes": ["intelligenz"], "needs": {"flora": 1, "arcana": 1, "fauna": 1, "ore_minerals": 1, "dexterity": 1, "craft": 1}, "legacy": ["alchemie"],},
	"mining": {"name": "Bergbau", "tree": "handwerk", "row": "advanced", "levels": 20, "attributes": [], "needs": {"intuition": 1, "strength": 1, "constitution": 1, "ore_minerals": 1, "craft": 1},},
	"runed_gems": {"name": "Runensteine", "tree": "handwerk", "row": "master", "levels": 20, "attributes": [], "needs": {"gemcutting": 1, "arcana": 1},},
	"charged_gems": {"name": "Geladene Steine", "tree": "handwerk", "row": "master", "levels": 20, "attributes": [], "needs": {"gemcutting": 1, "arcana": 1},},
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


## The node a skill id stands for: the id itself, or the node that carries the
## game's old German id of a skill ("klingen" is the node "sword_fighting");
## "" for an id the tree does not know.
static func node_of(id: String) -> String:
	if ALL.has(id):
		return id
	for node in ALL:
		if id in ALL[node].get("legacy", []):
			return node
	return ""


## Whether the game has the skill: an affinity, an attribute or a trained skill.
static func in_game(id: String) -> bool:
	var node := node_of(id)
	if node == "":
		return false
	var skill: Dictionary = ALL[node]
	return skill.has("affinity") or skill.has("attribute") or skill.has("legacy")


static func is_affinity(id: String) -> bool:
	return ALL.get(node_of(id), {}).has("affinity")


## The skill's German name.
static func name_of(id: String) -> String:
	return ALL[node_of(id)].name


## The most levels the game lets the hero train in a skill today.
static func level_cap(id: String) -> int:
	var node := node_of(id)
	if node == "" or is_affinity(node):
		return 0
	var skill: Dictionary = ALL[node]
	if skill.has("attribute"):
		return Training.attribute_cap(skill.attribute)
	var legacy: Array = skill.get("legacy", [])
	if legacy.is_empty():
		return 0
	if Monastery.SKILLS.has(legacy[0]):
		return Monastery.MAX_LESSONS
	return Training.skill_max(legacy[0])


## The level the hero has in a skill (0 for one the game does not have yet and
## for an affinity, which is not levelled).
@warning_ignore("integer_division")
static func level_of(hero: Player, id: String) -> int:
	var node := node_of(id)
	if node == "" or not in_game(node) or is_affinity(node):
		return 0
	var skill: Dictionary = ALL[node]
	if skill.has("attribute"):
		var attribute: Dictionary = Training.ATTRIBUTES[skill.attribute]
		return (hero.attribute(skill.attribute) - int(attribute.start)) / int(attribute.step)
	var best := 0
	for legacy in skill.legacy:
		best = maxi(best, hero.trained_level(legacy))
	return best


## The level that counts when another skill asks for this one: an affinity is
## always met, an attribute counts its starting level on top, a skill the game
## does not have yet is not asked for.
static func met_level(hero: Player, id: String) -> int:
	var node := node_of(id)
	if is_affinity(node):
		return 1000
	if not in_game(node):
		return 1000
	return level_of(hero, node) + (1 if ALL[node].has("attribute") else 0)


## "affinity" for Body, Soul, Nature and Craft, "known" (trained), "open" (can
## be trained now) or "locked" (something it needs is missing) for a skill the
## game has, "planned" for one it does not.
static func status(hero: Player, id: String) -> String:
	if is_affinity(id):
		return "affinity"
	if not in_game(id):
		return "planned"
	if level_of(hero, id) > 0:
		return "known"
	return "locked" if not unmet(hero, id).is_empty() else "open"


## What a skill still needs: entries {"skill": true, "id", "level"} for each
## skill level the hero has not reached.
static func unmet(hero: Player, id: String) -> Array:
	var out := []
	for entry in needs_of(id):
		if met_level(hero, entry.id) < entry.level:
			out.append(entry)
	return out


## Everything a skill needs: {"skill": true, "id", "level"}.
static func needs_of(id: String) -> Array:
	var out := []
	var skill: Dictionary = ALL[node_of(id)]
	for need in skill.get("needs", {}):
		out.append({"skill": true, "id": need, "level": int(skill.needs[need])})
	return out


## The skills that need this one.
static func opens(id: String) -> Array:
	var node := node_of(id)
	var out := []
	for other in ALL:
		if ALL[other].get("needs", {}).has(node):
			out.append(other)
	return out


## Whether a skill needs a skill of another tab (drawn with a star).
static func crosses_trees(id: String) -> bool:
	var skill: Dictionary = ALL[node_of(id)]
	for need in skill.get("needs", {}):
		if ALL[need].tree != skill.tree:
			return true
	return false
