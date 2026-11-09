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
## `gold` and maybe an `item`, or a `recipe` (see Crafting). A task with
## "wish": true is never offered by running into its giver: it starts when
## the hero picks that wish in the master's wish window (see Wishes). A task
## with "found": true is found out in the world instead (Sternhall's
## prisoner, see SternHall) and starts with Events.quest_found; its giver is
## who rewards it. A found task with an empty giver and a `source` text has
## no villager behind it (Brother Orlan in the Ashen Spire's archive, see
## AshSpire): its kind "potion" is done by handing him a healing potion, and its
## `note` stands for the reward. A task with an "area" (see AREAS) and a short
## "brief" also shows in the event log while the hero is in that area. Every text is German and has an English entry
## in Lang; `remind` may hold one %d (how many are still missing).
## The state of every task is kept in the hero's saved game (see Game).

const BANDITS := ["halsabschneider", "wilderer", "schlaeger", "hauptmann"]
## How likely a cutthroat drops a bandit dagger while someone still wants them.
const DAGGER_DROP := 0.6

## Places a task can be bound to (its "area"): while the hero is there, an open
## task shows pinned in the event log with its "brief" (see board).
## "outdoor": a named area of the open air (Journal.OUTDOOR_AREAS), "building":
## the building of a level, "prefix": every floor whose building starts so,
## "dungeon": any level of the dungeon.
const AREAS := {
	"pass": {"outdoor": "Räuberpass"},
	"spire4": {"building": "spire4"},
	"sternhall": {"prefix": "stern"},
	"dungeon": {"dungeon": true},
}

const ALL := {
	"raeuberplage": {"giver": "4", "kind": "kill", "targets": BANDITS, "count": 5, "gold": 25,
		"area": "pass", "brief": "Räuber am Pass besiegen",
		"title": "Räuberplage",
		"goal": "Besiege 5 Räuber am Räuberpass, östlich des Marktplatzes.",
		"offer": "Die Räuber am Pass werden frech. Besiege fünf von ihnen, und die Krone zahlt dir 25 Kupfer.",
		"remind": "Noch %d Räuber, dann ist der Pass ruhiger.",
		"done": "Fünf Räuber weniger! Hier ist dein Sold von der Krone."},
	"dolche": {"giver": "6", "kind": "fetch", "item": "banditendolch", "count": 3, "gold": 30,
		"area": "pass", "brief": "Banditendolche von Halsabschneidern holen",
		"title": "Gestohlene Dolche",
		"goal": "Bring Krämerin Mira 3 Banditendolche. Die Halsabschneider am Räuberpass tragen sie.",
		"offer": "Die Halsabschneider vom Pass haben mir eine Kiste Dolche gestohlen. Bring mir drei zurück, dann zahle ich 30 Kupfer.",
		"remind": "Mir fehlen noch %d Dolche. Die Halsabschneider am Pass haben sie.",
		"done": "Meine Dolche! Danke dir, hier sind 30 Kupfer."},
	"brief": {"giver": "M", "kind": "deliver", "item": "brief", "to": "0", "gold": 10,
		"title": "Post für den Vorsteher",
		"goal": "Bring den Brief aus der Hauptstadt zu Dorfvorsteher Aldo.",
		"offer": "Ein Brief aus der Hauptstadt für den Dorfvorsteher! Bringst du ihn hin? Aldo gibt dir sicher etwas dafür.",
		"remind": "Der Brief ist für Dorfvorsteher Aldo. Er steht vor seinem Haus.",
		"done": "Ein Brief aus der Hauptstadt? Danke! Hier sind 10 Kupfer für deine Mühe."},
	"kuerbis": {"giver": "2", "kind": "deliver", "item": "kuerbis", "to": "5", "gold": 5, "reward": "lederstiefel",
		"title": "Kürbis für die Suppe",
		"goal": "Bring Bäuerin Lenes Kürbis zu Zecher Fritz im Wirtshaus.",
		"offer": "Fritz im Wirtshaus will Kürbissuppe. Bringst du ihm diesen Kürbis? Er hat ein Paar Stiefel für dich.",
		"remind": "Der Kürbis ist für Zecher Fritz. Er sitzt beim Wirtshaus.",
		"done": "Ein Kürbis von Lene! Endlich gibt es Suppe. Hier, die Stiefel und 5 Kupfer."},
	"wasser": {"giver": "9", "kind": "deliver", "item": "wassereimer", "to": "O", "gold": 8,
		"title": "Wasser für den Tempel",
		"goal": "Bring Wasserträgerin Hannas Eimer zu Priesterin Elsbeth am Tempel.",
		"offer": "Die Priesterin braucht frisches Wasser für den Tempel. Trägst du ihr diesen Eimer hin? Meine Arme sind lahm.",
		"remind": "Der Eimer ist für Priesterin Elsbeth am Tempel.",
		"done": "Frisches Wasser für den Tempel. Die Götter danken dir, und ich auch: 8 Kupfer."},
	"schlaeger": {"giver": "1", "kind": "kill", "targets": ["schlaeger"], "count": 3, "gold": 10, "reward": "kettenhemd",
		"area": "pass", "brief": "Schläger am Pass besiegen",
		"title": "Grobe Schläger",
		"goal": "Besiege 3 Schläger mit Äxten am Räuberpass.",
		"offer": "Die Schläger vom Pass tragen Äxte, die sie mir nie bezahlt haben. Besiege drei von ihnen, dann bekommst du ein Kettenhemd.",
		"remind": "Noch %d Schläger. Dann schmiede ich dir dein Kettenhemd.",
		"done": "Das wird ihnen eine Lehre sein! Hier, ein Kettenhemd aus meiner Esse, und 10 Kupfer."},
	"wilderer": {"giver": "3", "kind": "kill", "targets": ["wilderer"], "count": 2, "gold": 18,
		"area": "pass", "brief": "Wilderer am Pass besiegen",
		"title": "Wilderer im Wald",
		"goal": "Besiege 2 Wilderer mit Armbrüsten am Räuberpass.",
		"offer": "Wilderer schießen im Wald auf alles, was sich bewegt. Besiege zwei von ihnen, dann zahle ich 18 Kupfer.",
		"remind": "Noch %d Wilderer. Pass auf ihre Bolzen auf!",
		"done": "Endlich kann ich wieder in Ruhe Holz hacken. Hier sind 18 Kupfer."},
	"hauptmann": {"giver": "G", "kind": "kill", "targets": ["hauptmann"], "count": 1, "after": "raeuberplage", "gold": 40, "reward": "schattenumhang",
		"area": "pass", "brief": "Räuberhauptmann am Lagerfeuer besiegen",
		"title": "Der Räuberhauptmann",
		"goal": "Besiege den Räuberhauptmann am Lagerfeuer im Räuberlager.",
		"offer": "Die Wache sagt, du hast am Pass aufgeräumt. Jetzt der Hauptmann am Lagerfeuer! Besiege ihn, und die Gilde zahlt 40 Kupfer und einen Schattenumhang.",
		"remind": "Der Hauptmann sitzt am Lagerfeuer im Räuberlager. Nimm Heiltränke mit.",
		"done": "Der Hauptmann ist besiegt? Die Gilde ist stolz auf dich! Hier sind 40 Kupfer und ein Schattenumhang."},
	# Gorm and Hagen have quarrelled for years (see VillageTalk): this ends it.
	"versoehnung": {"giver": "S", "kind": "deliver", "item": "wetzstein", "to": "1", "gold": 12, "standing": 1,
		"title": "Ein Stein für den Schmied",
		"goal": "Bring Steinmetz Hagens Wetzstein zu Schmied Gorm an seiner Esse.",
		"offer": "Gorm und ich streiten seit Jahren. Bring ihm diesen Wetzstein aus meinem Bruch. Vielleicht ist dann endlich Ruhe.",
		"remind": "Der Wetzstein ist für Schmied Gorm an seiner Esse.",
		"done": "Von Hagen? Ein Wetzstein aus seinem Bruch... Der ist gut. Sag ihm Danke von mir. Hier sind 12 Kupfer."},
	# Wishes Guild Master Ragna helps with (see Wishes): each earns a recipe.
	"wunsch_klingen": {"giver": "G", "wish": true, "kind": "kill", "targets": ["krieger"], "count": 5, "gold": 5, "recipe": "klingenring",
		"area": "dungeon", "brief": "Skelettkrieger im Verlies besiegen",
		"title": "Ein Ring für die Klinge",
		"goal": "Besiege 5 Skelettkrieger im Verlies. Ragna will sehen, wie du die Klinge führst.",
		"offer": "Zeig mir erst, wie du die Klinge führst: Besiege fünf Skelettkrieger im Verlies. Dann verrate ich dir, wie man den Ring macht.",
		"remind": "Noch %d Skelettkrieger. Ich will sehen, wie du die Klinge führst.",
		"done": "So führt man eine Klinge! Hier ist das Rezept für den Klingenring."},
	"wunsch_aexte": {"giver": "G", "wish": true, "kind": "kill", "targets": ["schlaeger"], "count": 3, "gold": 5, "recipe": "axtreif",
		"area": "pass", "brief": "Schläger am Pass besiegen",
		"title": "Ein Armreif für die Axt",
		"goal": "Besiege 3 Schläger am Räuberpass. Sie tragen Äxte wie du.",
		"offer": "Die Schläger am Pass schwingen Äxte. Besiege drei von ihnen, dann zeige ich dir, wie man den Armreif schmiedet.",
		"remind": "Noch %d Schläger am Pass.",
		"done": "Axt gegen Axt, und du stehst noch. Hier ist das Rezept für den Armreif der Axt."},
	"wunsch_blocken": {"giver": "G", "wish": true, "kind": "kill", "targets": ["schuetze"], "count": 4, "gold": 5, "recipe": "schildamulett",
		"title": "Ein Amulett für den Schild",
		"goal": "Besiege 4 Skelettschützen. Nachts schießen sie auf dem Friedhof, und im offenen Grab darunter lauern sie immer. Fang ihre Bolzen mit dem Schild ab.",
		"offer": "Ein Schild zeigt sich gegen Bolzen. Besiege vier Skelettschützen, nachts auf dem Friedhof oder unten im offenen Grab, dann bekommst du das Rezept.",
		"remind": "Noch %d Skelettschützen. Halt den Schild hoch!",
		"done": "Kein Bolzen kam durch, sehr gut. Hier ist das Rezept für das Amulett des Walls."},
	"wunsch_werfen": {"giver": "G", "wish": true, "kind": "kill", "targets": ["wilderer"], "count": 3, "gold": 5, "recipe": "wurfring",
		"area": "pass", "brief": "Wilderer am Pass besiegen",
		"title": "Ein Ring für den Wurf",
		"goal": "Besiege 3 Wilderer am Räuberpass. Sie schießen aus der Ferne, wie du.",
		"offer": "Die Wilderer am Pass kämpfen aus der Ferne. Besiege drei von ihnen, dann zeige ich dir den Ring für einen ruhigen Wurf.",
		"remind": "Noch %d Wilderer am Pass.",
		"done": "Ferne gegen Ferne, und du warst schneller. Hier ist das Rezept für den Wurfring."},
	"wunsch_schleichen": {"giver": "G", "wish": true, "kind": "kill", "targets": ["halsabschneider"], "count": 3, "gold": 5, "recipe": "schattenamulett",
		"area": "pass", "brief": "Halsabschneider am Pass besiegen",
		"title": "Ein Amulett für die Schatten",
		"goal": "Besiege 3 Halsabschneider am Räuberpass. Sie lauern im Schatten wie du.",
		"offer": "Die Halsabschneider am Pass lauern im Schatten. Besiege drei von ihnen, dann erzähle ich dir vom Amulett der stillen Schritte.",
		"remind": "Noch %d Halsabschneider am Pass.",
		"done": "Leise und schnell. Hier ist das Rezept für das Amulett der stillen Schritte."},
	"wunsch_ruestung": {"giver": "G", "wish": true, "kind": "kill", "targets": ["koloss"], "count": 2, "gold": 5, "recipe": "lastreif",
		"area": "dungeon", "brief": "Kolosse im Verlies besiegen",
		"title": "Ein Armreif für schwere Rüstung",
		"goal": "Besiege 2 Kolosse im Verlies. Ihre Schläge prüfen deine Rüstung.",
		"offer": "Zeig mir, dass deine Rüstung hält: Besiege zwei Kolosse im Verlies. Dann bekommst du das Rezept für den Armreif der leichten Last.",
		"remind": "Noch %d Kolosse im Verlies.",
		"done": "Deine Rüstung hat gehalten. Hier ist das Rezept für den Armreif der leichten Last."},
	# Found in the jail under Sternhall (see SternHall): Alrik the scribe.
	"sternhall_alrik": {"giver": "8", "found": true, "kind": "deliver", "item": "alriks_siegelring", "to": "8", "gold": 60, "reward": "heiltrank_stark",
		"area": "sternhall", "brief": "Alriks Siegelring zum Gelehrten bringen",
		"title": "Der Schreiber im Kerker",
		"goal": "Bring Alriks Siegelring zum Gelehrten im Dorf. Alrik sitzt im Kerker unter Sternhall.",
		"offer": "Bring meinen Siegelring dem Gelehrten im Dorf. Er soll wissen, dass ich noch lebe.",
		"remind": "Der Siegelring ist für den Gelehrten im Dorf.",
		"done": "Alriks Ring! Er lebt? Im Kerker von Sternhall... Ich schicke sofort nach der Akademie. Nimm 60 Kupfer und diesen starken Heiltrank."},
	# Found in the archive of the Ashen Spire (see AshSpire): Brother Orlan.
	"ash_orlan": {"giver": "", "found": true, "kind": "potion", "gold": 0, "note": "Zwei verborgene Orte im Aschenturm",
		"source": "Bruder Orlan im Archiv des Aschenturms",
		"area": "spire4", "brief": "Heiltrank zu Bruder Orlan bringen",
		"title": "Ein Trank für Bruder Orlan",
		"goal": "Bring Bruder Orlan im Archiv des Aschenturms einen Heiltrank. Er sitzt hinter den Gittern seiner Zelle.",
		"offer": "Ich bin wund. Ein Heiltrank, und ich verrate Euch ein Geheimnis dieser Zelle.",
		"remind": "Bruder Orlan wartet im Archiv auf einen Heiltrank.",
		"done": "Bruder Orlan trinkt den Trank und erzählt dir von zwei verborgenen Orten."},
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
	if state.has(id) or ALL[id].get("wish", false) or ALL[id].get("found", false):
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
	if q.kind == "potion":
		return 0 if potion_in_bag() != "" else 1
	return 0 if not game.player.bag.has(q.item) else 1


## The reward in words, e.g. "25 Gold, Kettenhemd".
static func reward_text(id: String) -> String:
	var q: Dictionary = ALL[id]
	var parts := []
	if q.get("gold", 0) > 0:
		parts.append(Lang.t("%d Kupfer") % q.gold)
	if q.has("reward"):
		parts.append(Items.item_name(q.reward))
	if q.has("note"):
		parts.append(Lang.t(q.note))
	if q.has("recipe"):
		parts.append(Lang.t("Rezept: %s") % Lang.t(Crafting.RECIPES[q.recipe].name))
	return ", ".join(parts)


## Whether the hero stands in the area `key` of AREAS right now.
func in_area(key: String) -> bool:
	if game == null or game.level == null or game.player == null or not AREAS.has(key):
		return false
	var level: Level = game.level
	var a: Dictionary = AREAS[key]
	if a.has("outdoor"):
		if not level.outdoor:
			return false
		var chars := ""
		for area in Journal.OUTDOOR_AREAS:
			if area[1] == a.outdoor:
				chars = area[0]
		return chars != "" and chars.contains(level.cell_char(level.world_to_cell(game.player.global_position)))
	if a.has("building"):
		return level.building == a.building
	if a.has("prefix"):
		return level.building.begins_with(a.prefix)
	return not level.outdoor and level.building == ""


## The open tasks bound to where the hero is, one short line each, for the
## event log: their brief and, for a count, how far along they are. A task
## with nothing left to do here (the kills counted, to be handed in in the
## village) is not listed.
func board() -> Array[String]:
	var out: Array[String] = []
	for id in ALL:
		var q: Dictionary = ALL[id]
		if not is_active(id) or not q.has("area") or not in_area(q.area):
			continue
		if q.kind in ["kill", "fetch"] and missing(id) == 0:
			continue
		var status := progress(id)
		out.append(Lang.t("Aufgabe: %s") % Lang.t(q.brief) + ("  (%s)" % status if status != "" else ""))
	return out


## The weakest healing potion in the bag, "" for none (what Brother Orlan takes).
func potion_in_bag() -> String:
	for id in ["heiltrank_schwach", "heiltrank", "heiltrank_stark"]:
		if game.player.bag.has(id):
			return id
	return ""


## Brother Orlan's task is done: the hero handed him a potion (see AshSpire).
## False when it was not taken on or is done already.
func finish_found(id: String) -> bool:
	if not is_active(id) or not ALL[id].get("found", false):
		return false
	state[id] = {"state": "done", "count": 1}
	Events.bus().quest_done.emit(id)
	return true


func _carried(item: String) -> int:
	return game.player.bag.count(item)


func _bag_free() -> int:
	return game.player.bag_size() - game.player.bag_used()


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
		if q.giver != role or not is_active(id) or q.get("found", false):
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
					Events.bus().quest_item_given.emit()
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


## A wish's task starts: the hero picked it in the master's wish window
## (see Wishes). False if it was taken already.
func start_wish(id: String, v: Villager) -> bool:
	if state.has(id) or not ALL[id].get("wish", false):
		return false
	state[id] = {"state": "active", "count": 0}
	v.meet()
	v.say(Lang.t(ALL[id].offer), game.player.global_position, 6.5)
	Events.teach(HOW_TO)
	Events.tell(Lang.t("Neuer Auftrag: %s") % Lang.t(ALL[id].title) + "\n" + Lang.t(ALL[id].goal), Color(1.0, 0.82, 0.4))
	return true


## A task found out in the world starts (see Events.quest_found): a delivery
## puts its item into the bag. False if it was taken already or the bag is full.
func start_found(id: String) -> bool:
	if not ALL.has(id) or state.has(id) or not ALL[id].get("found", false) or game == null:
		return false
	var q: Dictionary = ALL[id]
	if q.kind == "deliver":
		if _bag_free() <= 0:
			return false
		game.player.bag.append(q.item)
		Events.bus().quest_item_given.emit()
	state[id] = {"state": "active", "count": 0}
	Events.teach(HOW_TO)
	Events.tell(Lang.t("Neuer Auftrag: %s") % Lang.t(q.title) + "\n" + Lang.t(q.goal), Color(1.0, 0.82, 0.4))
	return true


func _offer(id: String, v: Villager) -> bool:
	var q: Dictionary = ALL[id]
	v.meet()
	if q.kind == "deliver":
		if _bag_free() <= 0:
			v.say(Lang.t("Ich hätte einen Auftrag für dich, aber deine Tasche ist voll."), game.player.global_position)
			return true
		game.player.bag.append(q.item)
	state[id] = {"state": "active", "count": 0}
	if catch_up(id) and _room_for_reward(id):
		# The boss fell before the task was given (e.g. the chief, felled
		# while clearing the pass for the guard): it is done at once.
		Events.teach(HOW_TO)
		_finish(id, v)
		return true
	v.say(Lang.t(q.offer), game.player.global_position, 6.5)
	Events.teach(HOW_TO)
	Events.tell(Lang.t("Neuer Auftrag: %s") % Lang.t(q.title) + "\n" + Lang.t(q.goal), Color(1.0, 0.82, 0.4))
	return true


## Kinds that fall only once per saved game and never come back (see
## Outdoor.chief_defeated). A kill task for one of them can never be counted
## once it has fallen, so it counts as done.
const ONCE_ONLY := ["hauptmann"]


## Marks open kill tasks for a once-only boss as done when the boss has
## fallen already: felled before the task was taken, or in a game saved
## before this rule. `only` limits it to one task. True if any task changed.
func catch_up(only := "") -> bool:
	if game == null or not game.has_method("boss_fallen"):
		return false
	var changed := false
	for id in ALL:
		var q: Dictionary = ALL[id]
		if (only != "" and id != only) or q.kind != "kill" or not is_active(id) or missing(id) == 0:
			continue
		var bosses: Array = q.targets.filter(func(t): return t in ONCE_ONLY)
		if bosses.size() != q.targets.size() or not bosses.all(func(t): return game.boss_fallen(t)):
			continue
		state[id].count = q.count
		changed = true
	return changed


## Whether the bag can take the reward once `freed` items are handed over.
func _room_for_reward(id: String, freed := 0) -> bool:
	return not ALL[id].has("reward") or _bag_free() + freed > 0


func _finish(id: String, v: Villager) -> void:
	var q: Dictionary = ALL[id]
	state[id] = {"state": "done", "count": q.get("count", 1)}
	v.meet()
	var said := Lang.t(q.done)
	if q.has("recipe"):
		game.crafting.learn_recipe(q.recipe)
		Events.teach(Crafting.HOW_TO)
	if q.get("wish", false):
		# The master points at the next wish that fits the hero best.
		var hint: String = game.wishes.next_hint(q.giver)
		if hint != "":
			said += " " + hint
	v.say(said, game.player.global_position, 7.0 if said != Lang.t(q.done) else 5.5)
	game.coins += int(q.get("gold", 0))
	if q.has("reward"):
		if game.player.bag_fits(q.reward):
			game.player.bag.append(q.reward)
		else:
			# No room (a delivery fills the bag again): it waits in the chest.
			game.storage.append(q.reward)
	Events.bus().quest_done.emit(id)


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
			Events.tell(Lang.t("Auftrag erfüllt: %s\nGeh zurück zu %s.") % [Lang.t(q.title), villager_name(q.giver)], Color(0.6, 1.0, 0.6))
		elif count < q.count:
			Events.tell(Lang.t("%s: %d / %d") % [Lang.t(q.title), count, q.count], Color(0.85, 0.87, 0.92), 2.0)
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
