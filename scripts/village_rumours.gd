class_name VillageRumours
extends RefCounted
## The people of Lindenhain pass the time: small talk, rumours and old
## stories. Three kinds of talk:
##   - SMALL_TALK: everyday chatter any two villagers may have;
##   - RUMOURS: hearsay about real things out in the world (the dragon under
##     the stone arch, the Great Old One, the pond monster, secret rooms, the
##     bandit chief, the Mountain King, ...). Each one is a hint the hero can
##     follow. Once the hero has dealt with the thing ("slain" an enemy of
##     that kind, or done the "quest"), the village talks about that instead
##     ("after_tell", "after_chat");
##   - STORIES: short tales, told by one teller in a few lines.
##
## Two ways to hear them:
##   - VillageTalk now and then picks any two free villagers near the hero
##     (not only those who are tied) and lets them chat about one of these
##     (see chat_for); a story there is told by its teller, the other
##     answers at the end;
##   - every TELL_EVERY-th time the hero talks to someone, they share a
##     rumour or tell a story of their own ("who" lists the tellers), line
##     after line while the hero stays close (see tell and update).
##
## Lines may hold "{hero}", the hero's name. Every text is German and has an
## English entry in scripts/lang/village_rumours.gd. The enemies the hero
## has slain that a rumour is about are kept in the saved game.

## Every this many words with the same villager, they share a rumour or a
## story instead of their usual line.
const TELL_EVERY := 3
## How likely a chat between two villagers is small talk, a rumour or a
## story (see VillageTalk.start_chat) instead of the talk of a tied pair.
const CHAT_CHANCE := 0.4
## Within such a chat: how likely a rumour or a story (the rest is small talk).
const RUMOUR_SHARE := 0.4
const STORY_SHARE := 0.25
## The pause between two lines of a story told to the hero, after the last
## bubble has faded (seconds).
const LINE_GAP := 0.5
## A story told to the hero stops when the hero walks this far away.
const HEAR_RANGE := VillageTalk.HEAR_RANGE

## Everyday chatter: exchanges said in turn by any two villagers. A
## Dictionary entry names the roles who never take part ("not"), so nobody
## talks about themselves.
const SMALL_TALK := [
	["Na, alles gut bei dir?", "Kann nicht klagen. Und wenn, hört ja keiner zu.", "Ich hör zu. Meistens."],
	{"not": ["2", "5"], "lines": ["Hast du schon gegessen?", "Lenes Kürbissuppe. Schon wieder.", "Es gibt Schlimmeres. Wenn Fritz kocht, zum Beispiel."]},
	["Mein Rücken bringt mich noch um.", "Dann trag weniger.", "Und wer trägt es dann?"],
	["Wie spät ist es eigentlich?", "Zu spät für die Arbeit, zu früh für ein Bier.", "Also genau richtig für ein Schwätzchen."],
	["Ich hab heute Nacht von Gold geträumt.", "Dann geh zur Bank. Da liegt welches.", "Nur leider nicht meins."],
	["{hero} ist immer noch im Dorf.", "Ein seltsamer Vogel, aber höflich.", "Höflicher als mancher hier."],
	["Meine Katze ist schon wieder weg.", "Die sitzt bestimmt am Teich und starrt die Fische an.", "Dann kommt sie heute Abend nass nach Hause."],
	["Was kochst du heute?", "Eintopf. Wie gestern.", "Und morgen?", "Den Rest von gestern."],
	{"not": ["1"], "lines": ["Hörst du Gorm hämmern?", "Seit Sonnenaufgang. Mein Kopf hämmert schon mit."]},
	["Weißt du was Neues?", "Nichts, was der Herold nicht schon dreimal ausgerufen hat.", "Dann ist ja alles beim Alten."],
	["Hast du die Vögel heute Morgen gehört?", "Laut wie ein Markt. Ich war wach, bevor der Hahn es war."],
	{"not": ["Y"], "lines": ["Der Bankier hat sich einen neuen Hut gekauft.", "Von unseren Zinsen, wette ich.", "Er steht ihm nicht einmal."]},
]

## Hearsay about the world. "who": the villagers who tell the hero about
## it; "tell": what they say; "chat": exchanges for two. Once an enemy of
## the kind "slain" has fallen to the hero, or the task "quest" is done,
## "after_tell" and "after_chat" are said instead. "not": roles left out of
## the chats.
const RUMOURS := {
	"drache": {"who": ["3", "5", "7", "G", "%"], "slain": "drache",
		"tell": ["Man sagt, unter dem Steinbogen im Wald schläft ein Drache auf einem Berg aus Gold.",
			"Nachts fliegen kleine Drachen aus dem Steinbogen und tragen fort, was draußen herumliegt. Lass nichts liegen!"],
		"chat": [["Hast du die kleinen Drachen gesehen, nachts über dem Wald?", "Sie tragen alles zum Steinbogen. Für den großen Drachen, heißt es.", "Dann lasse ich nie wieder etwas draußen liegen."]],
		"after_tell": ["Der Drache unter dem Steinbogen ist tot! {hero} hat ihn erschlagen, sagt man."],
		"after_chat": [["Der Drache unter dem Steinbogen ist tot.", "Ich weiß. {hero} war's. Endlich schlafe ich wieder ruhig."]]},
	"uralt": {"who": ["0", "8", "O", "%"], "slain": "grosser_alter",
		"tell": ["Hoch oben im Hochtal liegt eine Höhle. Darin schläft etwas, das älter ist als jeder Drache. Die Alten nennen es den Großen Alten.",
			"Drei Stockwerke tief unter den Bergen soll ein Schatz liegen, der jeden König arm aussehen lässt. Und auf ihm schläft der Große Alte."],
		"chat": [["Mein Großvater sprach vom Großen Alten in den Bergen.", "Ein Märchen, um Kinder zu erschrecken.", "Dann erklär mir, warum die Erde manchmal bebt."]],
		"after_tell": ["{hero} hat den Großen Alten in den Bergen bezwungen! Wer hätte das gedacht."],
		"after_chat": [["Seit {hero} in den Bergen war, ist es dort oben still.", "Der Große Alte ist fort. Ich hätte nie gedacht, dass ich das erlebe."]]},
	"teich": {"who": ["2", "5", "7", "9"],
		"tell": ["Im Dorfteich lebt ein kleines grünes Ungeheuer. Wenn du angelst, schnappt es dir manchmal den Köder weg.",
			"Auch im Tümpel der Wolfssenke lebt so ein Teichungeheuer. Es taucht auf, macht „Blubb!“ und schaut dich an."],
		"chat": [["Ich schwöre, im Teich hat mich etwas angeschaut!", "Das kleine Ungeheuer? Das klaut nur Köder.", "Es hatte Augen so groß wie Teller!", "Es hatte Augen so groß wie Erbsen. Ich hab's selbst gesehen."]]},
	"geheimraum": {"who": ["7", "8", "M", "Z"], "not": ["8"],
		"tell": ["Ein alter Abenteurer hat mir verraten: Im Verlies ist manche Fackel gar keine Fackel, sondern ein Hebel.",
			"An den Wänden des Verlieses stehen alte Schriften. Lies sie, sie verraten manches Geheimnis."],
		"chat": [["Im Verlies soll es Räume geben, die keiner findet.", "Weil keiner an den Fackeln zieht, sagt Odo.", "Odo sagt viel, wenn der Tag lang ist."]]},
	"hauptmann": {"who": ["4", "6", "K", "Y"], "slain": "hauptmann", "quest": "hauptmann",
		"tell": ["Der Räuberhauptmann am Pass trägt einen Schild so groß wie eine Tür. Wenn er anstürmt, spring zur Seite!",
			"Die Gilde zahlt gut für den Kopf des Räuberhauptmanns. Frag Ragna, wenn du dich traust."],
		"chat": [["Wieder ein Händler am Pass überfallen.", "Das war der Hauptmann mit seinem Riesenschild.", "Irgendwer muss ihm das Handwerk legen."]],
		"after_tell": ["Der Räuberhauptmann ist gefallen. Seitdem trauen sich die Händler wieder über den Pass."],
		"after_chat": [["Die Händler kommen wieder über den Pass.", "Seit {hero} den Hauptmann erledigt hat. Ein Segen."]]},
	"bergkoenig": {"who": ["1", "3", "G", "S"], "slain": "bergkoenig",
		"tell": ["Die Zwerge gruben einst tief im dritten Bergwerk. Ganz unten, im Herz des Berges, soll ein Felstroll als König hausen."],
		"chat": [["Warum haben die Zwerge das dritte Bergwerk verlassen?", "Weil unten im Berg einer König spielt. Ein Troll, so groß wie ein Haus.", "Und so einer will König sein?"]],
		"after_tell": ["Der Bergkönig ist gestürzt! Wer weiß, was die Zwerge da unten noch liegen ließen."],
		"after_chat": [["Der Bergkönig ist besiegt, hast du gehört?", "Von {hero}! Ich hätte mich nicht einmal in die Mine getraut."]]},
	"kristalle": {"who": ["6", "S", "Z"], "not": ["6"],
		"tell": ["Im zweiten Bergwerk wachsen Kristalle, die von selbst leuchten. Am Schleifrad auf dem Handwerkerplatz wird Schmuck daraus."],
		"chat": [["Hast du Miras neue Kette gesehen? Die leuchtet ja!", "Grottenkristall. Aus dem zweiten Bergwerk, geschliffen auf dem Handwerkerplatz.", "So eine will ich auch."]]},
	"grauen": {"who": ["3", "4", "O"],
		"tell": ["In den finsteren Löchern draußen in der Wildnis atmet etwas. Etwas Riesiges, das keinen Namen hat. Geh da nicht allein hin."],
		"chat": [["In den Löchern draußen atmet etwas. Ich hab es gehört.", "Das warst du selbst, vor lauter Angst.", "Lach nur. Du warst noch nie dort."]]},
	"wanderer": {"who": ["5", "6", "K"],
		"tell": ["Jede dritte Nacht kommt ein Händler mit einem Karren ins Dorf. Er hat Dinge, die es sonst nirgends gibt."],
		"chat": [["Der Wanderhändler war wieder da. Mitten in der Nacht.", "Hast du was gekauft?", "Mondsilber. Ich weiß nicht einmal, wofür."]]},
	"tentakel": {"who": ["4", "8", "9"],
		"tell": ["Hör im Verlies auf das Gurgeln unter den Bodengittern. Steigen Blasen auf, geh weg vom Gitter!"],
		"chat": [["Unter den Gittern im Verlies soll Wasser stehen. Und darin etwas mit Armen.", "Mit Armen? Wie ein Krake?", "Wie zehn Kraken."]]},
}

## Short tales: "who" may tell it, "lines" are the teller's, "reply" is what
## a listening villager says at the end of a chat.
const STORIES := {
	"gruft": {"who": ["0", "8", "O"],
		"lines": ["Man erzählt, die alte Gruft war einst ein Kloster.", "Dann gruben die Mönche zu tief und fanden etwas, das nicht gefunden werden wollte.", "Seitdem kam keiner mehr heraus. Bis auf {hero}."],
		"reply": "Mir läuft es kalt den Rücken herunter."},
	"baer": {"who": ["5"],
		"lines": ["Hab ich dir schon erzählt, wie ich einen Bären verjagt habe?", "Er stand plötzlich vor mir, groß wie ein Schrank.", "Ich hab ihm in die Augen geschaut und laut gerülpst.", "Er ist gerannt, als wäre der Drache hinter ihm her."],
		"reply": "Fritz, das war eine Kuh."},
	"brunnen": {"who": ["0", "9"],
		"lines": ["Weißt du, warum der Brunnen auf dem Markt heilt?", "Eine Heilerin warf einst ihren Ring hinein, bevor sie starb.", "Seitdem ist das Wasser gesegnet. Trink davon, wenn du verwundet bist."],
		"reply": "Ich trink lieber Bier. Das heilt auch. Irgendwie."},
	"skelette": {"who": ["4"],
		"lines": ["Als junger Wachmann stand ich einmal allein gegen drei Skelette.", "Das erste fiel. Das zweite fiel.", "Und das dritte hat mich bis ins Dorf gejagt. Seitdem trage ich einen Schild."],
		"reply": "Kluger Mann."},
	"friedhof": {"who": ["7"],
		"lines": ["Gestern war ich ganz allein am Friedhof!", "Da hat ein Skelett mit den Zähnen geklappert.", "Ich hab zurückgeklappert. Da ist es weggelaufen!"],
		"reply": "Pip! Du sollst doch nicht zum Friedhof!"},
	"steinbogen": {"who": ["3", "S"],
		"lines": ["Mein Vater hat den Steinbogen im Wald nie angefasst.", "Er sagte, die Steine seien warm, sogar im Winter.", "Jetzt weiß ich, warum. Dahinter liegt ein Drache."],
		"reply": "Und ich hab mich da früher zum Mittagsschlaf hingelegt."},
	"zwerge": {"who": ["1", "S"],
		"lines": ["Mein Meister hat noch mit einem Zwerg gehandelt.", "Der zahlte mit Erz, so rein, dass es im Dunkeln glühte.", "Eines Tages kam er nicht mehr. Seitdem sind die Bergwerke still."],
		"reply": "Vielleicht liegt das Erz da unten heute noch."},
	"muenze": {"who": ["Y"],
		"lines": ["Mein Großvater fischte einst eine einzige Goldmünze aus dem Brunnen.", "Er gab sie nicht aus. Er verlieh sie. Gegen Zinsen.", "Aus dieser einen Münze wurde die Bank der Krone."],
		"reply": "Und wir zahlen die Zinsen heute noch."},
}

## Explained once in the compendium, the first time the hero is told a
## rumour or a story.
const HOW_TO := "Gerüchte und Geschichten: Die Leute in Lindenhain reden gern. Sprich sie öfter an, dann erzählen sie dir Gerüchte und alte Geschichten. Manches Gerücht verrät, wo etwas Gefährliches haust oder ein Geheimnis wartet. Auch wenn zwei miteinander plaudern, lohnt es sich zuzuhören."

var game: Node
## The kinds of enemy the hero has slain that a rumour is about.
var slain := {}
## Whether the hero has been told one already (for the compendium note).
var told_any := false
## How many words the hero had with each villager, and how many times each
## list was used, to take turns.
var _talks := {}
var _turns := {}
## A story being told to the hero ({} for none): the teller, the lines
## still to come and the pause before the next one.
var _story := {}
var _rng := RandomNumberGenerator.new()


func _init(owner_game: Node = null) -> void:
	game = owner_game
	_rng.randomize()


func clear() -> void:
	slain.clear()
	told_any = false
	_talks.clear()
	_turns.clear()
	_story = {}


## An enemy fell to the hero (Events.bus().enemy_slain): rumours about it
## turn into news.
func on_slain(kind: String) -> void:
	for id in RUMOURS:
		if RUMOURS[id].get("slain", "") == kind:
			slain[kind] = true


## Whether the hero has dealt with what a rumour is about.
func is_settled(id: String) -> bool:
	var r: Dictionary = RUMOURS[id]
	if r.has("slain") and slain.has(r.slain):
		return true
	return r.has("quest") and game != null and game.quests.is_done(r.quest)


# --- Told to the hero -------------------------------------------------------

## The hero spoke to `v`: every TELL_EVERY-th time they share a rumour or
## start a story. `short`: one line only (someone about to trade). Returns
## whether they did.
func tell(v: Villager, short := false) -> bool:
	if is_telling(v):
		return true
	var count := int(_talks.get(v.role, 0)) + 1
	_talks[v.role] = count
	if count % TELL_EVERY != 0:
		return false
	var options := told_by(v.role, short)
	if options.is_empty():
		return false
	var pick: Array = options[_take_turn("tell-" + v.role) % options.size()]
	var lines := []
	for line in pick:
		lines.append(fill(line))
	v.meet()
	_say(v, lines.pop_front())
	if not lines.is_empty():
		_story = {"who": v, "lines": lines, "wait": 0.0}
	if not told_any:
		told_any = true
		Events.teach(HOW_TO)
	return true


## What `role` may tell the hero: one-line rumours ([line]) and, unless
## `short`, stories (their lines), all German.
func told_by(role: String, short := false) -> Array:
	var out := []
	for id in RUMOURS:
		var r: Dictionary = RUMOURS[id]
		if not role in r.who:
			continue
		var said: Array = r.after_tell if is_settled(id) and r.has("after_tell") else r.tell
		for line in said:
			out.append([line])
	if not short:
		for id in STORIES:
			if role in STORIES[id].who:
				out.append(STORIES[id].lines)
	return out


## Whether `v` is in the middle of telling the hero a story.
func is_telling(v: Villager) -> bool:
	return not _story.is_empty() and _story.who == v


## Every frame in the village while the world runs: the next line of a story
## told to the hero, once the last one has been read.
func update(delta: float, _village: Outdoor = null) -> void:
	if _story.is_empty():
		return
	var v = _story.who
	if not is_instance_valid(v) or v.at_home or not v.visible or v.chat_partner != null or game == null:
		_story = {}
		return
	if VillageTalk._flat(v.global_position, game.player.global_position) > HEAR_RANGE:
		_story = {}
		return
	if v._bubble_time > 0.0:
		_story.wait = LINE_GAP
		return
	_story.wait -= delta
	if _story.wait > 0.0:
		return
	var lines: Array = _story.lines
	_say(v, lines.pop_front())
	if lines.is_empty():
		_story = {}


func _say(v: Villager, text: String) -> void:
	var at: Vector3 = game.player.global_position if game and game.player else Vector3.INF
	v.say(text, at, VillageTalk.line_time(text))


# --- Chats between villagers ---------------------------------------------------

## A chat for two villagers (roles `a` and `b`), or [] when they have
## nothing to say: a list of ["a" or "b", German line], in the order said.
func chat_for(a: String, b: String) -> Array:
	var roll := _rng.randf()
	var result := []
	if roll < STORY_SHARE:
		result = _story_chat(a, b)
	elif roll < STORY_SHARE + RUMOUR_SHARE:
		result = _rumour_chat(a, b)
	if result.is_empty():
		result = _small_talk(a, b)
	return result


func _small_talk(a: String, b: String) -> Array:
	var options := []
	for entry in SMALL_TALK:
		var lines: Array = entry.lines if entry is Dictionary else entry
		var left_out: Array = entry.get("not", []) if entry is Dictionary else []
		if not (a in left_out or b in left_out):
			options.append(lines)
	if options.is_empty():
		return []
	return _in_turn(options[_take_turn("small") % options.size()])


func _rumour_chat(a: String, b: String) -> Array:
	var options := []
	for id in RUMOURS:
		var r: Dictionary = RUMOURS[id]
		if a in r.get("not", []) or b in r.get("not", []):
			continue
		var talks: Array = r.after_chat if is_settled(id) and r.has("after_chat") else r.chat
		options.append_array(talks)
	if options.is_empty():
		return []
	return _in_turn(options[_take_turn("rumour") % options.size()])


## A story one of the two can tell, the other answering at the end.
func _story_chat(a: String, b: String) -> Array:
	var options := []
	for id in STORIES:
		var s: Dictionary = STORIES[id]
		if a in s.who:
			options.append(["a", s])
		elif b in s.who:
			options.append(["b", s])
	if options.is_empty():
		return []
	var pick: Array = options[_take_turn("story") % options.size()]
	var teller: String = pick[0]
	var listener := "b" if teller == "a" else "a"
	var out := []
	for line in pick[1].lines:
		out.append([teller, line])
	out.append([listener, pick[1].reply])
	return out


static func _in_turn(lines: Array) -> Array:
	var out := []
	for i in lines.size():
		out.append(["a" if i % 2 == 0 else "b", lines[i]])
	return out


## A line in the chosen language, with the hero's name filled in.
func fill(line: String) -> String:
	var hero: String = game.hero_name if game and game.hero_name != "" else Lang.t("der Neue")
	return Lang.t(line).replace("{hero}", hero)


func _take_turn(key: String) -> int:
	var n := int(_turns.get(key, 0))
	_turns[key] = n + 1
	return n


# --- Saved game ---------------------------------------------------------------

func for_save() -> Dictionary:
	return {"slain": slain.keys(), "told": told_any}


## Back from the saved game; older saved games start with nothing slain.
func load_from(saved) -> void:
	clear()
	if not (saved is Dictionary):
		return
	var kinds = saved.get("slain", [])
	if kinds is Array:
		for kind in kinds:
			on_slain(str(kind))
	told_any = bool(saved.get("told", false))
