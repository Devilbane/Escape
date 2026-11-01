class_name Quests
extends RefCounted
## Small tasks the villagers of Lindenhain hand out: run into a villager who
## has work for you and they offer it, run into them again when it is done
## to get the reward. Three kinds of task:
##   kill     defeat `count` enemies of the kinds in `targets`
##   fetch    bring `count` of the item `item` (taken from the bag)
##   deliver  carry the item `item`, handed over by the giver, to villager `to`
## A task may need another one finished first (`after`), or the giver to
## think well of the hero first (`standing`, a Reputation level). The reward is
## `gold` and maybe an `item`. Every text is German and has an English entry
## in Lang; `remind` may hold one %d (how many are still missing).
## The state of every task is kept in the hero's saved game (see Game).

const BANDITS := ["halsabschneider", "wilderer", "schlaeger", "hauptmann"]
## How likely a cutthroat drops a bandit dagger while someone still wants them.
const DAGGER_DROP := 0.6

const ALL := {
	"raeuberplage": {"giver": "4", "kind": "kill", "targets": BANDITS, "count": 5, "gold": 25,
		"title": "Räuberplage",
		"goal": "Besiege 5 Räuber am Räuberpass, östlich des Marktplatzes.",
		"offer": "Die Räuber am Pass werden frech. Besiege fünf von ihnen, und die Krone zahlt dir 25 Gold.",
		"remind": "Noch %d Räuber, dann ist der Pass ruhiger.",
		"done": "Fünf Räuber weniger! Hier ist dein Sold von der Krone."},
	"dolche": {"giver": "6", "kind": "fetch", "item": "banditendolch", "count": 3, "gold": 30,
		"title": "Gestohlene Dolche",
		"goal": "Bring Krämerin Mira 3 Banditendolche. Die Halsabschneider am Räuberpass tragen sie.",
		"offer": "Die Halsabschneider vom Pass haben mir eine Kiste Dolche gestohlen. Bring mir drei zurück, dann zahle ich 30 Gold.",
		"remind": "Mir fehlen noch %d Dolche. Die Halsabschneider am Pass haben sie.",
		"done": "Meine Dolche! Danke dir, hier sind 30 Gold."},
	"brief": {"giver": "M", "kind": "deliver", "item": "brief", "to": "0", "gold": 10,
		"title": "Post für den Vorsteher",
		"goal": "Bring den Brief aus der Hauptstadt zu Dorfvorsteher Aldo.",
		"offer": "Ein Brief aus der Hauptstadt für den Dorfvorsteher! Bringst du ihn hin? Aldo gibt dir sicher etwas dafür.",
		"remind": "Der Brief ist für Dorfvorsteher Aldo. Er steht vor seinem Haus.",
		"done": "Ein Brief aus der Hauptstadt? Danke! Hier sind 10 Gold für deine Mühe."},
	"kuerbis": {"giver": "2", "kind": "deliver", "item": "kuerbis", "to": "5", "gold": 5, "reward": "lederstiefel",
		"title": "Kürbis für die Suppe",
		"goal": "Bring Bäuerin Lenes Kürbis zu Zecher Fritz im Wirtshaus.",
		"offer": "Fritz im Wirtshaus will Kürbissuppe. Bringst du ihm diesen Kürbis? Er hat ein Paar Stiefel für dich.",
		"remind": "Der Kürbis ist für Zecher Fritz. Er sitzt beim Wirtshaus.",
		"done": "Ein Kürbis von Lene! Endlich gibt es Suppe. Hier, die Stiefel und 5 Gold."},
	"wasser": {"giver": "9", "kind": "deliver", "item": "wassereimer", "to": "O", "gold": 8,
		"title": "Wasser für den Tempel",
		"goal": "Bring Wasserträgerin Hannas Eimer zu Priesterin Elsbeth am Tempel.",
		"offer": "Die Priesterin braucht frisches Wasser für den Tempel. Trägst du ihr diesen Eimer hin? Meine Arme sind lahm.",
		"remind": "Der Eimer ist für Priesterin Elsbeth am Tempel.",
		"done": "Frisches Wasser für den Tempel. Die Götter danken dir, und ich auch: 8 Gold."},
	"schlaeger": {"giver": "1", "kind": "kill", "targets": ["schlaeger"], "count": 3, "gold": 10, "reward": "kettenhemd",
		"title": "Grobe Schläger",
		"goal": "Besiege 3 Schläger mit Äxten am Räuberpass.",
		"offer": "Die Schläger vom Pass tragen Äxte, die sie mir nie bezahlt haben. Besiege drei von ihnen, dann bekommst du ein Kettenhemd.",
		"remind": "Noch %d Schläger. Dann schmiede ich dir dein Kettenhemd.",
		"done": "Das wird ihnen eine Lehre sein! Hier, ein Kettenhemd aus meiner Esse, und 10 Gold."},
	"wilderer": {"giver": "3", "kind": "kill", "targets": ["wilderer"], "count": 2, "gold": 18,
		"title": "Wilderer im Wald",
		"goal": "Besiege 2 Wilderer mit Armbrüsten am Räuberpass.",
		"offer": "Wilderer schießen im Wald auf alles, was sich bewegt. Besiege zwei von ihnen, dann zahle ich 18 Gold.",
		"remind": "Noch %d Wilderer. Pass auf ihre Bolzen auf!",
		"done": "Endlich kann ich wieder in Ruhe Holz hacken. Hier sind 18 Gold."},
	"hauptmann": {"giver": "G", "kind": "kill", "targets": ["hauptmann"], "count": 1, "after": "raeuberplage", "gold": 40, "reward": "schattenumhang",
		"title": "Der Räuberhauptmann",
		"goal": "Besiege den Räuberhauptmann am Lagerfeuer im Räuberlager.",
		"offer": "Die Wache sagt, du hast am Pass aufgeräumt. Jetzt der Hauptmann am Lagerfeuer! Besiege ihn, und die Gilde zahlt 40 Gold und einen Schattenumhang.",
		"remind": "Der Hauptmann sitzt am Lagerfeuer im Räuberlager. Nimm Heiltränke mit.",
		"done": "Der Hauptmann ist besiegt? Die Gilde ist stolz auf dich! Hier sind 40 Gold und ein Schattenumhang."},
	# Gorm and Hagen have quarrelled for years (see VillageTalk): this ends it.
	"versoehnung": {"giver": "S", "kind": "deliver", "item": "wetzstein", "to": "1", "gold": 12, "standing": 1,
		"title": "Ein Stein für den Schmied",
		"goal": "Bring Steinmetz Hagens Wetzstein zu Schmied Gorm an seiner Esse.",
		"offer": "Gorm und ich streiten seit Jahren. Bring ihm diesen Wetzstein aus meinem Bruch. Vielleicht ist dann endlich Ruhe.",
		"remind": "Der Wetzstein ist für Schmied Gorm an seiner Esse.",
		"done": "Von Hagen? Ein Wetzstein aus seinem Bruch... Der ist gut. Sag ihm Danke von mir. Hier sind 12 Gold."},
}

## Explained once in the compendium, the first time a villager hands out a task.
const HOW_TO := "Dorfbewohner geben dir Aufträge: Lauf gegen sie, wenn sie Arbeit für dich haben, und noch einmal, wenn du fertig bist, um die Belohnung abzuholen. Alle Aufträge stehen im Kompendium (Taste H) unter „Aufträge“."

var game: Node
## Task id -> {"state": "active" or "done", "count": progress of a kill task}.
## Tasks never offered are not in here.
var state := {}


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	state.clear()


func is_active(id: String) -> bool:
	return state.get(id, {}).get("state", "") == "active"


func is_done(id: String) -> bool:
	return state.get(id, {}).get("state", "") == "done"


## Whether a villager has this task for the hero right now.
func is_available(id: String) -> bool:
	if state.has(id):
		return false
	var after: String = ALL[id].get("after", "")
	if after != "" and not is_done(after):
		return false
	var standing := int(ALL[id].get("standing", 0))
	return standing <= 0 or (game != null and game.reputation.level(ALL[id].giver) >= standing)


## What is kept in the saved game: only plain values.
func for_save() -> Dictionary:
	return state.duplicate(true)


## Back from the saved game; unknown tasks and broken entries are left out,
## and older saved games without any tasks start with none.
func load_from(saved) -> void:
	state.clear()
	if not (saved is Dictionary):
		return
	for id in saved:
		var entry = saved[id]
		if not ALL.has(str(id)) or not (entry is Dictionary):
			continue
		var s := str(entry.get("state", ""))
		if s in ["active", "done"]:
			state[str(id)] = {"state": s, "count": int(entry.get("count", 0))}


## The name of the villager with this role letter, in the current language.
static func villager_name(role: String) -> String:
	return Lang.t(Villager.ROLES[role].name) if Villager.ROLES.has(role) else ""


## How far along a task is, for the quest log: "2 / 5", or "" for a delivery.
func progress(id: String) -> String:
	var q: Dictionary = ALL[id]
	match q.kind:
		"kill":
			return "%d / %d" % [mini(int(state.get(id, {}).get("count", 0)), q.count), q.count]
		"fetch":
			return "%d / %d" % [mini(_carried(q.item), q.count), q.count]
	return ""


## What still has to be done, in words: what the reminders say.
func missing(id: String) -> int:
	var q: Dictionary = ALL[id]
	match q.kind:
		"kill":
			return maxi(0, q.count - int(state.get(id, {}).get("count", 0)))
		"fetch":
			return maxi(0, q.count - _carried(q.item))
	return 0 if not game.player.bag.has(q.item) else 1


## The reward in words, e.g. "25 Gold, Kettenhemd".
static func reward_text(id: String) -> String:
	var q: Dictionary = ALL[id]
	var parts := []
	if q.get("gold", 0) > 0:
		parts.append(Lang.t("%d Gold") % q.gold)
	if q.has("reward"):
		parts.append(Items.item_name(q.reward))
	return ", ".join(parts)


func _carried(item: String) -> int:
	return game.player.bag.count(item)


func _bag_free() -> int:
	return game.player.bag_size() - game.player.bag.size()


## The mark over a villager's head: "?" when the hero can hand something in
## to them (a delivery for them, or their own task done), "!" when they have
## a new task to offer, "" otherwise.
func mark(role: String) -> String:
	for id in ALL:
		var q: Dictionary = ALL[id]
		if not is_active(id):
			continue
		if q.kind == "deliver":
			if q.to == role and game.player.bag.has(q.item):
				return "?"
		elif q.giver == role and missing(id) == 0:
			return "?"
	for id in ALL:
		if ALL[id].giver == role and is_available(id):
			return "!"
	return ""


# --- Talking ------------------------------------------------------------------

## The hero ran into a villager. If a task has something to say (a delivery
## arriving, a task done, a new one offered, or a reminder) the villager
## says it and this returns true; otherwise the villager just chats.
## Traders skip reminders, so running into them still opens their goods.
func talk(v: Villager, trader := false) -> bool:
	var role := v.role
	# A delivery for this villager.
	for id in ALL:
		var q: Dictionary = ALL[id]
		if q.kind == "deliver" and q.to == role and is_active(id) and game.player.bag.has(q.item):
			game.player.bag.erase(q.item)
			_finish(id, v)
			return true
	# A task this villager gave.
	for id in ALL:
		var q: Dictionary = ALL[id]
		if q.giver != role or not is_active(id):
			continue
		match q.kind:
			"kill", "fetch":
				if missing(id) == 0:
					if not _room_for_reward(id, q.count if q.kind == "fetch" else 0):
						v.meet()
						v.say(Lang.t("Gut gemacht! Mach Platz in deiner Tasche, dann bekommst du deine Belohnung."), game.player.global_position)
						return true
					if q.kind == "fetch":
						for i in q.count:
							game.player.bag.erase(q.item)
					_finish(id, v)
					return true
				if trader:
					continue
				v.meet()
				var remind := Lang.t(q.remind)
				v.say(remind % missing(id) if remind.contains("%d") else remind, game.player.global_position)
				return true
			"deliver":
				if not game.player.bag.has(q.item) and _bag_free() > 0:
					# Lost, sold or thrown away: here is another one.
					game.player.bag.append(q.item)
					v.meet()
					v.say(Lang.t("Du hast ihn nicht mehr? Hier, nimm noch einen. %s") % Lang.t(q.remind), game.player.global_position, 5.5)
					game.update_after_quest()
					return true
				if trader:
					continue
				v.meet()
				v.say(Lang.t(q.remind), game.player.global_position)
				return true
	# Something new to do.
	for id in ALL:
		if ALL[id].giver == role and is_available(id):
			return _offer(id, v)
	return false


func _offer(id: String, v: Villager) -> bool:
	var q: Dictionary = ALL[id]
	v.meet()
	if q.kind == "deliver":
		if _bag_free() <= 0:
			v.say(Lang.t("Ich hätte einen Auftrag für dich, aber deine Tasche ist voll."), game.player.global_position)
			return true
		game.player.bag.append(q.item)
	state[id] = {"state": "active", "count": 0}
	v.say(Lang.t(q.offer), game.player.global_position, 6.5)
	game.learn(HOW_TO)
	game.quest_news(Lang.t("Neuer Auftrag: %s") % Lang.t(q.title) + "\n" + Lang.t(q.goal), Color(1.0, 0.82, 0.4))
	return true


## Whether the bag can take the reward once `freed` items are handed over.
func _room_for_reward(id: String, freed := 0) -> bool:
	return not ALL[id].has("reward") or _bag_free() + freed > 0


func _finish(id: String, v: Villager) -> void:
	var q: Dictionary = ALL[id]
	state[id] = {"state": "done", "count": q.get("count", 1)}
	v.meet()
	v.say(Lang.t(q.done), game.player.global_position, 5.5)
	game.coins += int(q.get("gold", 0))
	if q.has("reward"):
		if _bag_free() > 0:
			game.player.bag.append(q.reward)
		else:
			# No room (a delivery fills the bag again): it waits in the chest.
			game.storage.append(q.reward)
	game.quest_reward(id)


# --- Fighting -----------------------------------------------------------------

## An enemy fell: count it for every kill task that wants its kind. Returns
## the item it should drop for a fetch task ("" for none).
func on_kill(kind: String) -> String:
	for id in ALL:
		var q: Dictionary = ALL[id]
		if q.kind != "kill" or not is_active(id) or not kind in q.targets:
			continue
		var count := int(state[id].count) + 1
		state[id].count = count
		if count == q.count:
			game.quest_news(Lang.t("Auftrag erfüllt: %s\nGeh zurück zu %s.") % [Lang.t(q.title), villager_name(q.giver)], Color(0.6, 1.0, 0.6))
		elif count < q.count:
			game.quest_news(Lang.t("%s: %d / %d") % [Lang.t(q.title), count, q.count], Color(0.85, 0.87, 0.92), 2.0)
	if kind == "halsabschneider" and is_active("dolche") and missing("dolche") > 0 and randf() < DAGGER_DROP:
		return "banditendolch"
	return ""


## The tasks for the quest log: the open ones first, newest last, then the
## finished ones.
func log_entries() -> Array:
	var open := []
	var done := []
	for id in ALL:
		if is_active(id):
			open.append(id)
		elif is_done(id):
			done.append(id)
	return open + done
