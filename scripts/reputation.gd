class_name Reputation
extends RefCounted
## How the villagers of Lindenhain think of the hero. Helping them earns
## reputation with each villager on their own:
##   a finished task       QUEST_GIVER with the villager who gave it,
##                         QUEST_RECEIVER with the one a delivery was for,
##                         and WORD_OF_MOUTH with everyone else the hero has
##                         met (word gets around in a small village):
##                         family and friends of the giver are glad to hear
##                         it (VillageTalk.CLOSE_WORD), rivals do not care;
##   trading               TRADE per purchase with a villager who trades
##                         (shopkeeper, smith, stonemason, barber), but only
##                         up to TRADE_CAP points: buying alone makes a
##                         customer, not a friend.
## Standing grows through four levels (see LEVELS). Each level brings more:
##   friendly   a small discount, and the villager shares gossip now and then
##              (tips about the world, and hints at who knows a secret recipe);
##   trusted    a bigger discount, and a villager who knows a secret recipe
##              (see SECRETS) teaches it the next time the hero talks to them;
##   honoured   the biggest discount.
## Secret recipes become crafting choices for the time away (see Offline).
## Everything is kept in the hero's saved game (see Game).

const QUEST_GIVER := 25
const QUEST_RECEIVER := 15
const WORD_OF_MOUTH := 5
const TRADE := 2
const TRADE_CAP := 30

## Standing levels, lowest first: points needed, name, discount on prices.
const LEVELS := [
	{"points": 0, "name": "Fremd", "discount": 0.0},
	{"points": 10, "name": "Freundlich", "discount": 0.05},
	{"points": 25, "name": "Vertraut", "discount": 0.10},
	{"points": 45, "name": "Geehrt", "discount": 0.20},
]
## Explained once in the compendium, the first time a villager thinks better
## of the hero.
const HOW_TO := "Ruf im Dorf: Wer den Leuten in Lindenhain hilft, gewinnt ihre Gunst. Erledigte Aufträge zählen am meisten, bei dem, der ihn gab, beim Empfänger und ein wenig bei allen, die du kennst. Einkäufe zählen auch, aber nur bis zu einem gewissen Grad. Freundliche Leute geben Rabatt und erzählen Neuigkeiten, vertraute verraten dir vielleicht ein Geheimrezept. Alles steht im Kompendium (Taste H) unter „Ruf“."
const FRIENDLY := 1
const TRUSTED := 2

## Villagers who know a secret recipe for the time away (Offline.RECIPES),
## and the words they use to pass it on once they trust the hero.
const SECRETS := {
	"1": {"recipe": "messer_gorm",
		"say": "Ich verrate dir etwas, das sonst keiner weiß: Härte die Klinge in Öl statt in Wasser. So ist ein Wurfmesser in zwei Stunden fertig statt in dreien.",
		"learn": "Gorms Geheimrezept: Wurfmesser, in Öl gehärtet, sind in 2 statt 3 Stunden fertig. Wähle es im Tagesplan unter „Handwerk“."},
	"6": {"recipe": "pflege_mira",
		"say": "Unter uns: Mein Lederfett aus Bienenwachs und Talg macht jede Rüstung wieder geschmeidig. Ich zeige dir, wie man es anrührt.",
		"learn": "Miras Geheimrezept: Mit ihrem Lederfett bessert dein Held 1 Punkt Haltbarkeit pro Stunde aus statt alle 2 Stunden. Wähle es im Tagesplan unter „Handwerk“."},
	"S": {"recipe": "steine_hagen",
		"say": "Du hast ein gutes Auge für Stein. Ich zeige dir, wo im Bruch der Fels richtig spaltet, dann behaust du dir deine Blöcke selbst.",
		"learn": "Hagens Geheimrezept: Dein Held behaut in der Zeit weg alle 4 Stunden einen Steinblock. Die Blöcke liegen danach in deiner Truhe. Wähle es im Tagesplan unter „Handwerk“."},
}

## What villagers share once they are friendly with the hero: tips about
## the world and hints at who knows a secret recipe. Every line is German
## and has an English entry in Lang.
const GOSSIP := {
	"0": ["Unter uns: Gorm hat ein Geheimnis für seine Wurfmesser. Er verrät es aber nur Leuten, denen er vertraut.",
		"Seit du da bist, schlafen die Leute ruhiger. Die Räuber am Pass fürchten dich."],
	"1": ["Hagen behaut seine Steine nicht wie andere Steinmetze. Hilf ihm, und er zeigt dir vielleicht, wie.",
		"Alte Waffen wirfst du besser nicht weg. Ich schmelze sie dir zu Eisen ein."],
	"2": ["Mira rührt ein Lederfett an, das jede Rüstung wieder geschmeidig macht. Das Rezept gibt sie nur Freunden.",
		"Auf dem Sockel südlich vom Markt steht ein Essenskorb. Mit zwei Kisten kommst du hinauf."],
	"3": ["Nördlich vom Weg zum Dorf steht ein alter Steinbogen im Wald. Darunter haust ein Drache, sagt man.",
		"Rehe und Füchse laufen weg, wenn du kommst. Schleich dich an, dann kommst du näher heran."],
	"4": ["Nachts sind die Räuber am Pass zäher und kommen schneller wieder. Geh lieber bei Tag hin.",
		"In der Wolfssenke nördlich vom Pass leben ein Yeti und zwei Orks. Nimm dich in Acht."],
	"5": ["Gorm schmiedet Wurfmesser schneller als jeder andere. Wie er das macht? Frag ihn, wenn er dich mag.",
		"Der Brunnen auf dem Markt heilt alles: Wunden, Gift, sogar Flüche. Prost!"],
	"6": ["Ein Rucksack auf dem Rücken, und deine Tasche fasst mehr. Die großen sind selten.",
		"Hagen kann dir zeigen, wie man Steinblöcke selbst behaut. Er redet aber nur mit Leuten, die er kennt."],
	"7": ["Im Labyrinth gibt es eine Kammer mit Steinen und Platten im Boden! Hat mir ein Händler erzählt.",
		"Die Toten auf dem Friedhof stehen nachts auf. Ich geh da nie hin!"],
	"8": ["In der Steinkammer im Labyrinth öffnet sich das Gitter, wenn auf jeder Platte ein Block liegt. Deine eigenen Steine gehen auch.",
		"Hinter jeder Ebene des Verlieses liegt ein geheimer Raum. Eine der Fackeln ist ein Hebel."],
	"9": ["Der Räuberhauptmann rammt dich mit dem Schild, wenn du zu nah stehst. Spring zur Seite, wenn er anstürmt!",
		"Mira hat da ein Lederfett, sagt man. Damit bessert man eine Rüstung doppelt so schnell aus."],
	"K": ["Die Krone zahlt gut für Räuber. Frag die Wache Ulrich.",
		"Eine Mauer aus Steinblöcken hält Räuber und Skelette auf. Sie können nicht klettern."],
	"O": ["Ein verwundeter Hauptmann bindet seine Wunden, wenn du fliehst. Bleib dran, wenn du ihn schwächst.",
		"Wer im Tempel betet, findet Ruhe. Wer im Bett schläft, auch, und sein Spiel ist gespeichert."],
	"G": ["Der Drache in der Höhle spuckt Feuer. Stell dich hinter eine Statue.",
		"Ein Stich in den Rücken fällt jedes Skelett, das dich noch nicht bemerkt hat."],
	"M": ["Ich trage die Post in jedes Haus. Bei Gorm riecht es immer nach Öl, nicht nach Wasser. Merkwürdig, oder?",
		"Der Bankier vermietet Schließfächer im Tresorkeller. Dort sieht man, was andere Helden besitzen."],
	"Z": ["Die Glatze zeigt deine Tätowierung am besten. Nur so als Hinweis.",
		"Gorm, Mira und Hagen haben jeder ein Geheimrezept. Hilf ihnen, dann verraten sie es dir vielleicht."],
	"Y": ["Gold auf der Bank ist sicher, auch wenn du im Verlies fällst.",
		"Wer den Leuten im Dorf hilft, bekommt bessere Preise. Ich sehe das an den Büchern der Händler."],
	"S": ["Stapel deine Blöcke versetzt, und lass keine Lücke breiter als ein Schritt. Sonst kommen die Räuber durch.",
		"Mira verkauft nicht nur Kram. Sie weiß auch, wie man Leder pflegt. Frag sie, wenn sie dich gut kennt."],
}
## Every this many talks with a friendly villager, they share gossip
## instead of their usual line.
const GOSSIP_EVERY := 2

var game: Node
## Role letter -> {"points": from helping, "trade": from trading}.
var standing := {}
## Ids of the secret recipes the hero has been taught.
var recipes: Array[String] = []
## Talks with each villager this session, to space out the gossip.
var _talks := {}


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	standing.clear()
	recipes.clear()
	_talks.clear()


func points(role: String) -> int:
	var s: Dictionary = standing.get(role, {})
	return int(s.get("points", 0)) + int(s.get("trade", 0))


## The standing level with a villager: 0 (stranger) to 3 (honoured).
func level(role: String) -> int:
	var p := points(role)
	var result := 0
	for i in LEVELS.size():
		if p >= LEVELS[i].points:
			result = i
	return result


static func level_name(index: int) -> String:
	return Lang.t(LEVELS[index].name)


func discount(role: String) -> float:
	return LEVELS[level(role)].discount if role != "" else 0.0


## A price in gold after the discount this villager gives the hero (at
## least 1 for anything that costs something).
func price(role: String, gold: int) -> int:
	if gold <= 0:
		return gold
	return maxi(1, roundi(gold * (1.0 - discount(role))))


## Points still needed for the next level, or 0 at the top.
func to_next(role: String) -> int:
	var next := level(role) + 1
	return 0 if next >= LEVELS.size() else LEVELS[next].points - points(role)


func knows_recipe(id: String) -> bool:
	return recipes.has(id)


## Whether a crafting recipe for the time away can be chosen: the plain
## ones always, the secret ones once a villager taught them.
func can_craft(id: String) -> bool:
	return Offline.RECIPES.has(id) and (not Offline.RECIPES[id].has("secret") or knows_recipe(id))


# --- Gaining standing ---------------------------------------------------------

## Adds points with a villager; tells the hero, and says so when the
## villager now thinks better of them.
func gain(role: String, amount: int, from_trade := false) -> void:
	if role == "" or not Villager.ROLES.has(role) or amount <= 0:
		return
	var s: Dictionary = standing.get(role, {"points": 0, "trade": 0})
	var before := level(role)
	if from_trade:
		var trade := int(s.get("trade", 0))
		amount = mini(amount, TRADE_CAP - trade)
		if amount <= 0:
			return
		s.trade = trade + amount
	else:
		s.points = int(s.get("points", 0)) + amount
	standing[role] = s
	var now := level(role)
	if now > before and game:
		game.reputation_rose(role, now)


## A task is done: the giver, the one who got the delivery and, by word of
## mouth, everyone else the hero knows.
func on_quest_done(id: String) -> void:
	var q: Dictionary = Quests.ALL[id]
	var receiver: String = q.get("to", "")
	gain(q.giver, QUEST_GIVER)
	if receiver != "":
		gain(receiver, QUEST_RECEIVER)
	if game:
		for role in game.met:
			if role != q.giver and role != receiver:
				gain(role, word_of_mouth(q.giver, role))


## What `role` thinks of the hero helping `helped`: more for family and
## friends, nothing for rivals (see VillageTalk).
func word_of_mouth(helped: String, role: String) -> int:
	if game == null or not ("village_talk" in game):
		return WORD_OF_MOUTH
	match game.village_talk.bond(helped, role):
		"close":
			return VillageTalk.CLOSE_WORD
		"rival":
			return 0
	return WORD_OF_MOUTH


## The hero bought something from a villager who trades.
func on_trade(role: String) -> void:
	gain(role, TRADE, true)


# --- Talking ------------------------------------------------------------------

## A trusted villager who knows a secret recipe teaches it (once). Returns
## true when they did, so nothing else is said this time.
func tell_secret(v: Villager) -> bool:
	if not SECRETS.has(v.role) or level(v.role) < TRUSTED:
		return false
	var secret: Dictionary = SECRETS[v.role]
	if knows_recipe(secret.recipe):
		return false
	recipes.append(secret.recipe)
	v.meet()
	v.say(Lang.t(secret.say), game.player.global_position, 7.0)
	game.learn(secret.learn)
	game.quest_news(Lang.t("Geheimes Rezept gelernt: %s") % Lang.t(Offline.RECIPES[secret.recipe].name), Color(0.75, 0.6, 1.0), 4.5)
	return true


## Every GOSSIP_EVERY talks a friendly villager shares some gossip instead
## of their usual line. Returns true when they did.
func gossip(v: Villager) -> bool:
	if not GOSSIP.has(v.role) or level(v.role) < FRIENDLY:
		return false
	var count := int(_talks.get(v.role, 0)) + 1
	_talks[v.role] = count
	if count % GOSSIP_EVERY != 0:
		return false
	var lines: Array = GOSSIP[v.role]
	v.meet()
	v.say(Lang.t(lines[(count / GOSSIP_EVERY - 1) % lines.size()]), game.player.global_position, 6.0)
	return true


# --- Saved game ---------------------------------------------------------------

## What is kept in the saved game: only plain values.
func for_save() -> Dictionary:
	return {"standing": standing.duplicate(true), "recipes": Array(recipes)}


## Back from the saved game; unknown villagers and recipes are left out,
## and older saved games start with nobody knowing the hero.
func load_from(saved) -> void:
	clear()
	if not (saved is Dictionary):
		return
	var s = saved.get("standing", {})
	if s is Dictionary:
		for role in s:
			var entry = s[role]
			if not Villager.ROLES.has(str(role)) or not (entry is Dictionary):
				continue
			standing[str(role)] = {
				"points": maxi(0, int(entry.get("points", 0))),
				"trade": clampi(int(entry.get("trade", 0)), 0, TRADE_CAP),
			}
	var r = saved.get("recipes", [])
	if r is Array:
		for id in r:
			if Offline.RECIPES.has(str(id)) and Offline.RECIPES[str(id)].has("secret") and not recipes.has(str(id)):
				recipes.append(str(id))
