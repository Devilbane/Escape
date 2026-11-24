class_name NpcKeywords
extends RefCounted
## The words that open a villager's window. Saying one in the chat line near them (see HeroChat)
## opens it, as clicking on them does; running into them opens nothing, they only remark which
## words they answer to (see remark). Plain villagers without a window have none: running into
## them gets a word out of them as before.
##
## "words" are shown in the remark, German with an English entry in scripts/lang/npc_keywords.gd
## (both languages are always understood); "secret" ones are never shown and have to be found out.
## A new window kind gets its entry here.

const KINDS := {
	"haendler": {"words": ["handeln", "kaufen"], "secret": []},
	"wanderhaendler": {"words": ["handeln", "kaufen"], "secret": []},
	"schmied": {"words": ["schmieden", "handeln"], "secret": []},
	"steinmetz": {"words": ["handeln", "kaufen"], "secret": []},
	"holzfaeller": {"words": ["handeln", "kaufen"], "secret": []},
	"raumausstatter": {"words": ["handeln", "kaufen"], "secret": []},
	"ü": {"words": ["handeln", "kaufen"], "secret": []},
	"bank": {"words": ["Bank", "Münzen"], "secret": []},
	"barbier": {"words": ["Haare", "Frisur"], "secret": []},
	"tempel": {"words": ["heilen", "Segen"], "secret": ["heilung", "segne"]},
	"plot_office": {"words": ["Land", "Grundstück"], "secret": []},
}


## The station kind's entry key: the Mill and the plot office use their own kind constants.
static func key(kind: String) -> String:
	if kind == Mill.KIND:
		return "ü"
	if kind == PlotOffice.KIND:
		return "plot_office"
	return kind


static func has(kind: String) -> bool:
	return KINDS.has(key(kind))


## The words shown for a kind, in the player's language.
static func shown(kind: String) -> Array:
	var out := []
	for w: String in KINDS[key(kind)].words:
		out.append(Lang.t(w))
	return out


## The remark of a villager the hero ran into: every shown word, no secret one.
static func remark(kind: String) -> String:
	var words := shown(kind)
	var quoted := Lang.t(" oder ").join(words.map(func(w: String) -> String: return "\"%s\"" % w))
	return Lang.t("Sag %s zu mir, dann bin ich für dich da.") % quoted


## Whether `text` holds a word that opens the window of this kind (shown or secret, either language).
static func matches(kind: String, text: String) -> bool:
	if not has(kind):
		return false
	var entry: Dictionary = KINDS[key(kind)]
	var words: Array = []
	for w: String in entry.words:
		words.append(w.to_lower())
		words.append(String(Lang.EN.get(w, w)).to_lower())
	for w: String in entry.secret:
		words.append(w.to_lower())
	return HeroChat._has_word(text.to_lower(), words)
