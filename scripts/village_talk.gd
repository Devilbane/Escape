class_name VillageTalk
extends RefCounted
## The people of Lindenhain talk to each other. Each villager wants something
## (GOALS), and many are tied to someone else (TIES): family, sweethearts,
## friends, rivals or an old grudge. Every so often two of them who are tied
## stop what they are doing, one walks over to the other, and they trade a
## few lines in their speech bubbles, one at a time, so the bubbles never
## cover each other. What they say depends on how they stand with each other,
## and also on the world:
##   - "after" lines once a task they care about is done (see Quests),
##   - "bounty" lines about today's notices on the board (see Bounties),
##   - lines about the hero once the hero is in their good books (see
##     Reputation),
##   - the weather, the night and fresh frights (see VillageWorries).
## Now and then any two villagers chat instead, tied or not: small talk,
## rumours and old stories (see VillageRumours).
## The hero who overhears a chat learns the tie; known ties are listed on the
## compendium's reputation page next to each villager's goal.
##
## Ties also count for reputation: help someone, and their family, friends
## and sweetheart hear about it gladly (CLOSE_WORD instead of the usual word of
## mouth); their rivals and grudge-holders do not care (no points).
##
## One rivalry can be mended: Hagen's whetstone for Gorm (the task
## "versoehnung") turns the two stubborn craftsmen into friends.
##
## Every text is German and has an English entry in Lang. Known ties are kept
## in the hero's saved game (see Game).

## Seconds until the first chat after the village is entered, and between
## chats after that (picked at random between the two).
const FIRST_CHAT := Vector2(8.0, 16.0)
const CHAT_EVERY := Vector2(18.0, 34.0)
## Only pairs with one of them this close to the hero start a chat (no one
## talks unheard), and the hero hears a line from this far.
const HEAR_RANGE := 24.0
## How far one of the pair walks to the other at most (metres).
const CHAT_REACH := 70.0
## Closer than this, nobody needs to walk over.
const CHAT_NEAR := 3.2
## A walk to the partner that takes longer than this is given up.
const WALK_LIMIT := 50.0
## The pause between two lines, after the last bubble has faded.
const LINE_GAP := 0.45
## Word of mouth for family, friends and sweethearts of the one the hero
## helped (the usual word of mouth is Reputation.WORD_OF_MOUTH).
const CLOSE_WORD := 10
## The key of a chat between any two (see start_rumour_chat) begins with this.
const RUMOUR_KEY := "plausch:"

## Kinds of tie: the name in the compendium and whether it is a warm one.
const KINDS := {
	"familie": {"name": "Familie", "close": true},
	"liebe": {"name": "Verliebt", "close": true},
	"freunde": {"name": "Freunde", "close": true},
	"rivalen": {"name": "Rivalen", "close": false},
	"groll": {"name": "Groll", "close": false},
}

## What each villager wants, shown on the compendium's reputation page.
const GOALS := {
	"0": "Will, dass Lindenhain wieder aufblüht, und misstraut den Steuern der Krone.",
	"1": "Will die besten Klingen im Tal schmieden, besser als Hagen je einen Stein behaut.",
	"2": "Will die Ernte vor dem Frost einbringen und Pip vom Friedhof fernhalten.",
	"3": "Will den Wald gesund halten und die Wilderer daraus vertreiben.",
	"4": "Will das Dorf vor den Räubern schützen, ohne die Hilfe der Gilde.",
	"5": "Will trinken, Geschichten hören und eines Tages seine Zeche zahlen.",
	"6": "Will ihre Schulden bei der Bank loswerden und ihren Laden vergrößern.",
	"7": "Will ein echter Abenteurer werden, wie der Held aus der Gruft.",
	"8": "Will das Rätsel der Gruft lösen, mit Büchern, nicht mit Gebeten.",
	"9": "Will den alten Brunnen rein halten und abends Ulrich sehen.",
	"K": "Will jede Neuigkeit als Erster ausrufen, vor allem vor dem Postmeister.",
	"O": "Will, dass die Toten in ihren Gräbern bleiben.",
	"G": "Will die Gilde groß machen und der Wache die Kopfgelder abjagen.",
	"M": "Will jeden Brief zustellen, pünktlich und bei jedem Wetter.",
	"Z": "Will jedem im Dorf einen neuen Look verpassen, sogar dem Gelehrten.",
	"Y": "Will jede Münze des Tals in seinem Tresor sehen.",
	"S": "Will eine Mauer um das ganze Dorf bauen.",
}

## Who is tied to whom. Every exchange is a list of lines, said in turn by
## a, b, a, ... "{hero}" becomes the hero's name, "{bounty}" the title of a
## notice on today's board. Optional:
##   "after"     task id -> exchanges, once that task is done;
##   "bounty"    exchanges while notices hang on the board;
##   "mended_by" a task that ends the quarrel: from then on the tie is
##               "mended_kind" and the pair says the "mended" exchanges.
const TIES := [
	{"a": "2", "b": "3", "kind": "familie", "talks": [
		["Bruno, hast du Holz für den Ofen?", "Zwei Körbe voll, Lene. Und einen Kuss dazu?", "Erst das Holz, dann der Kuss."],
		["Du riechst schon wieder nach Wirtshaus.", "Nur ein Bier mit Fritz, ehrlich!", "Ein Bier, sagt er. Wie jeden Abend."]]},
	{"a": "2", "b": "7", "kind": "familie", "talks": [
		["Pip! Du warst doch nicht am Friedhof?", "Nein, Mama! Nur ganz kurz am Zaun.", "Am Zaun ist schon zu nah!"],
		["Mama, darf ich Abenteurer werden?", "Erst wenn du die Kürbisse gegossen hast.", "Das machen echte Abenteurer nicht!"]]},
	{"a": "7", "b": "3", "kind": "familie", "talks": [
		["Papa, zeig mir, wie man die Axt schwingt!", "Wenn du so groß bist wie die Axt.", "Ich wachse jeden Tag!"]]},
	{"a": "5", "b": "3", "kind": "freunde", "talks": [
		["Bruno! Ich halte dir einen Platz frei.", "Danke, Fritz. Aber sag Lene nichts.", "Ich sage nie etwas. Fast nie."],
		["Na, Bruno, wie viele Bäume heute?", "Drei. Und du, wie viele Krüge?", "Auch drei. Wir sind ein fleißiges Dorf!"]],
		"after": {"wilderer": [["Die Wilderer sind fort, hab ich gehört.", "Dank {hero}. Endlich hacke ich wieder in Ruhe."]]}},
	{"a": "9", "b": "4", "kind": "liebe", "talks": [
		["Ulrich, du siehst durstig aus. Frisches Wasser?", "Für dich lasse ich sogar kurz die Wache stehen.", "Nur kurz! Sonst schimpft der Vorsteher."],
		["Kommst du heute Abend zum Brunnen?", "Wenn die Räuber mich lassen.", "Dann sorg dafür, dass sie dich lassen."]]},
	{"a": "9", "b": "O", "kind": "freunde", "talks": [
		["Elsbeth, der Tempel bekommt heute zwei Eimer.", "Du bist ein Segen, Hanna. Wirklich.", "Sag das meinen Armen."],
		["Betest du für Ulrich, wenn er am Pass ist?", "Jeden Abend, Hanna. Für ihn und für dich."]],
		"after": {"wasser": [["Hat {hero} dir meinen Eimer gebracht?", "Bis zum letzten Tropfen. Die Götter sahen es gern."]]}},
	{"a": "1", "b": "S", "kind": "rivalen", "talks": [
		["Hagen! Dein Klopfen übertönt mein Feuer.", "Mein Stein hält länger als dein Eisen, Gorm.", "Wir werden sehen, wer zuletzt hämmert."],
		["Deine Meißel sind stumpf, Hagen. Ich hör's bis hier.", "Dann schmiede mir bessere, wenn du kannst.", "Pah! Als ob ich für dich arbeite."]],
		"mended_by": "versoehnung", "mended_kind": "freunde", "mended": [
		["Der Wetzstein, Hagen. Meine Klingen waren nie schärfer.", "Und deine Meißel beißen in jeden Fels, Gorm.", "Vielleicht sind wir zusammen die Besten im Tal."],
		["Ein Tor aus Stein und Eisen für das Dorf?", "Du das Eisen, ich den Stein. Abgemacht."]]},
	{"a": "4", "b": "G", "kind": "rivalen", "talks": [
		["Die Wache schützt das Dorf, Ragna. Nicht deine Gilde.", "Deine Wache schläft, während meine Leute jagen.", "Ich schlafe nie im Dienst!"]],
		"bounty": [["Am Aushang hängt heute: „{bounty}“. Das erledigt die Wache.", "Die Wache? Das holt sich meine Gilde, wart's ab.", "Dann sehen wir, wer schneller ist."]],
		"after": {
			"raeuberplage": [["Der Pass ist ruhiger. Gute Arbeit der Wache.", "Der Wache? Das war {hero}. Und {hero} gehört bald zur Gilde."]],
			"hauptmann": [["Der Hauptmann ist gefallen. Die Krone ist zufrieden.", "Die Gilde hat gezahlt, Ulrich. Nicht die Krone.", "Hauptsache, die Straße ist sicher. Da sind wir uns einig."]]}},
	{"a": "K", "b": "M", "kind": "rivalen", "talks": [
		["Anselm, du hast die Neuigkeiten schon wieder vor mir erzählt!", "Ich trage die Briefe, Konrad. Ich lese sie nicht.", "Aber du erzählst sie weiter!"],
		["Hört, hört! Der Postmeister ist zu spät!", "Die Kutsche war zu spät, nicht ich.", "Das rufe ich morgen aus."]],
		"bounty": [["Hört, hört! Am Aushang hängt: „{bounty}“!", "Das hängt da seit dem Morgen, Konrad. Ich hab's als Erster gelesen."]]},
	{"a": "8", "b": "O", "kind": "rivalen", "talks": [
		["Die Toten stehen auf, weil der Boden verflucht ist. So steht es in meinen Büchern.", "Sie stehen auf, weil keiner mehr für sie betet, Odo.", "Dann bete du. Ich lese weiter."],
		["Wann warst du zuletzt im Tempel, Odo?", "Als ich ein Buch über Tempel las.", "Das zählt nicht."]]},
	{"a": "Y", "b": "6", "kind": "groll", "talks": [
		["Mira, deine Zinsen sind wieder fällig.", "Schon wieder? Du verdienst an meinem Brot mehr als ich.", "So ist das nun mal mit dem Gold."],
		["Ein guter Monat für den Laden, Mira?", "Gut genug, dass du nichts davon erfährst, Goldwin."]],
		"after": {"dolche": [["Ich höre, deine gestohlenen Dolche sind zurück.", "Dank {hero}. Und nein, die verpfände ich dir nicht."]]}},
	{"a": "5", "b": "Z", "kind": "freunde", "talks": [
		["Benno, schneid mir die Haare. Umsonst, unter Freunden.", "Unter Freunden kostet es das Doppelte, Fritz.", "Dann lass ich sie wachsen."],
		["Weißt du schon, was die Leute reden?", "Natürlich. Beim Barbier hört man alles.", "Und im Wirtshaus den Rest."]],
		"after": {"kuerbis": [["Lenes Kürbissuppe! {hero} hat den Kürbis gebracht.", "Dann spendiere ich {hero} einen Haarschnitt. Fast umsonst."]]}},
	{"a": "Z", "b": "8", "kind": "groll", "talks": [
		["Odo, dieser Bart! Lass mich nur ein bisschen schneiden.", "Kein Haar, Benno. Mein Bart denkt mit.", "Dann denkt er schlecht."],
		["Ein Irokese würde dich zehn Jahre jünger machen.", "Und zehnmal alberner aussehen lassen."]]},
	{"a": "0", "b": "M", "kind": "freunde", "talks": [
		["Anselm! Gibt es Post aus der Hauptstadt?", "Einen Brief, Aldo. Keine neuen Steuern, versprochen.", "Dann ist heute ein guter Tag."],
		["Ohne dich wüsste ich nichts von der Welt, Anselm.", "Und ohne deinen Tee käme ich nie durch meine Runde."]],
		"after": {"brief": [["Den Brief aus der Hauptstadt hat mir {hero} gebracht.", "Ich weiß. Jetzt habe ich einen Gehilfen, Aldo!"]]}},
	{"a": "7", "b": "4", "kind": "freunde", "talks": [
		["Ulrich, darf ich dein Schwert halten?", "Wenn du groß bist, Pip.", "Alle sagen: wenn du groß bist!"],
		["Hast du heute einen Räuber gefangen?", "Zwei. Aber verrat es keinem.", "Ich bin stumm wie ein Fisch!"]],
		"after": {"raeuberplage": [["Ulrich, ist {hero} stärker als du?", "Am Pass schon, Pip. Aber sag es keinem."]]}},
	{"a": "0", "b": "Y", "kind": "groll", "talks": [
		["Goldwin, die Krone will schon wieder mehr Steuern?", "Die Krone will, was ihr gehört, Vorsteher.", "Dem Dorf gehört auch etwas."],
		["Wie viele Höfe hat deine Bank diesen Winter gekauft?", "Nur die, die nicht zahlen konnten.", "Genau das meine ich."]]},
	{"a": "6", "b": "2", "kind": "freunde", "talks": [
		["Lene, deine Kürbisse gehen weg wie warmes Brot!", "Dann bring ich dir morgen zwei Körbe mehr.", "Und ich leg dir einen Käse zurück."],
		["War Pip wieder am Friedhof?", "Frag nicht. Pip macht mich noch grau."]]},
	{"a": "1", "b": "3", "kind": "freunde", "talks": [
		["Bruno, deine Axt klingt stumpf.", "Dann schärf sie mir, Gorm. Ich zahle mit Holz für deine Esse.", "Abgemacht. Holz kann ich immer brauchen."]]},
	{"a": "K", "b": "Y", "kind": "freunde", "talks": [
		["Goldwin, die Krone lässt grüßen.", "Und fragt sicher nach ihrem Gold.", "Wie immer."]]},
	{"a": "7", "b": "G", "kind": "freunde", "talks": [
		["Ragna, nimmst du mich in die Gilde auf?", "Zeig mir zuerst deine Narben.", "Ich hab mir gestern das Knie aufgeschlagen!", "Ein Anfang. Komm in zehn Jahren wieder."]]},
]

## Said about the hero once the first speaker thinks well of them (friendly
## or better): warm words between friends, boasting between rivals.
const HERO_TALKS := {
	"close": ["{hero} hat mir geholfen. Ein guter Mensch.", "Dann hilft {hero} hoffentlich auch mir."],
	"rival": ["Sogar {hero} kommt lieber zu mir als zu dir.", "Abwarten. {hero} weiß, wer hier etwas taugt."],
}

## Explained once in the compendium, the first time the hero overhears a chat.
const HOW_TO := "Die Leute in Lindenhain reden miteinander. Hör zu, dann erfährst du, wer verwandt, befreundet oder verfeindet ist. Hilfst du jemandem, freuen sich Familie und Freunde mit und denken noch besser von dir, seine Rivalen nicht. Alles steht im Kompendium (Taste H) unter „Ruf“."

var game: Node
## Ties the hero has overheard, by key (see key_of) -> true.
var known := {}
## How many chats each pair had this session, to take turns with the lines.
var _talks := {}
var _timer := 0.0
## The chat going on right now ({} when none): the tie, the two villagers,
## the lines still to come and the pause before the next one.
var _chat := {}


func _init(owner_game: Node = null) -> void:
	game = owner_game
	_timer = randf_range(FIRST_CHAT.x, FIRST_CHAT.y)


func clear() -> void:
	known.clear()
	_talks.clear()
	stop()
	_timer = randf_range(FIRST_CHAT.x, FIRST_CHAT.y)


static func key_of(tie: Dictionary) -> String:
	return "%s-%s" % [tie.a, tie.b]


static func tie_by_key(key: String) -> Dictionary:
	for tie in TIES:
		if key_of(tie) == key:
			return tie
	return {}


## The tie between two villagers ({} when there is none).
static func tie_between(a: String, b: String) -> Dictionary:
	for tie in TIES:
		if (tie.a == a and tie.b == b) or (tie.a == b and tie.b == a):
			return tie
	return {}


## Whether the quarrel behind a tie has been mended by the hero.
func is_mended(tie: Dictionary) -> bool:
	return tie.has("mended_by") and game != null and game.quests.is_done(tie.mended_by)


## The kind of a tie right now (a mended rivalry is a friendship).
func kind_of(tie: Dictionary) -> String:
	return tie.mended_kind if is_mended(tie) else tie.kind


## "close" (family, sweethearts, friends), "rival" (rivals, grudge) or ""
## (no tie): how `other` takes the news that the hero helped `role`.
func bond(role: String, other: String) -> String:
	var tie := tie_between(role, other)
	if tie.is_empty():
		return ""
	return "close" if KINDS[kind_of(tie)].close else "rival"


## The ties of one villager the hero has overheard, grouped for the
## compendium: [[kind name, "Name, Name"], ...] in the order of KINDS.
func known_ties_of(role: String) -> Array:
	var result := []
	for kind in KINDS:
		var names := []
		for tie in TIES:
			if not known.has(key_of(tie)) or kind_of(tie) != kind:
				continue
			if tie.a == role:
				names.append(Quests.villager_name(tie.b))
			elif tie.b == role:
				names.append(Quests.villager_name(tie.a))
		if not names.is_empty():
			result.append([Lang.t(KINDS[kind].name), ", ".join(names)])
	return result


# --- What they say --------------------------------------------------------------

## Every exchange a pair can have right now, each a list of [first speaker
## ("a" or "b"), lines in the chosen language].
func exchanges(tie: Dictionary) -> Array:
	var result := []
	var base: Array = tie.mended if is_mended(tie) else tie.talks
	for lines in base:
		result.append(["a", _fill(lines)])
	if game == null:
		return result
	var after: Dictionary = tie.get("after", {})
	for id in after:
		if game.quests.is_done(id):
			for lines in after[id]:
				result.append(["a", _fill(lines)])
	var notice := _bounty_title()
	if notice != "":
		for lines in tie.get("bounty", []):
			result.append(["a", _fill(lines, notice)])
	# Someone who thinks well of the hero speaks first about them.
	var close: bool = KINDS[kind_of(tie)].close
	var hero_lines: Array = HERO_TALKS["close" if close else "rival"]
	if game.reputation.level(tie.a) >= Reputation.FRIENDLY:
		result.append(["a", _fill(hero_lines)])
	elif game.reputation.level(tie.b) >= Reputation.FRIENDLY:
		result.append(["b", _fill(hero_lines)])
	return result


func _fill(lines: Array, notice := "") -> Array:
	var hero: String = game.hero_name if game and game.hero_name != "" else Lang.t("der Neue")
	var out := []
	for line in lines:
		out.append(Lang.t(line).replace("{hero}", hero).replace("{bounty}", notice))
	return out


## The title of a notice on today's board, or "" when none hangs there.
func _bounty_title() -> String:
	if game == null or game.bounties.posted.is_empty():
		return ""
	var id: String = game.bounties.posted[0]
	return Lang.t(Bounties.POOL[id].title) if Bounties.POOL.has(id) else ""


# --- Chats ----------------------------------------------------------------------

## Every frame in the village while the world runs: starts a chat now and
## then and plays the one going on.
func update(delta: float, village: Outdoor) -> void:
	if not _chat.is_empty():
		_run_chat(delta)
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(CHAT_EVERY.x, CHAT_EVERY.y)
	start_chat(village)


func is_chatting() -> bool:
	return not _chat.is_empty()


## The chat going on right now, for tests: its key, or "".
func current() -> String:
	return _chat.get("key", "")


## Picks a pair who are tied, both free, close enough to each other and to
## the hero, and starts them talking. `only` limits it to one tie (by key).
## Now and then (VillageRumours.CHAT_CHANCE) any two free villagers chat
## instead, about small things, a rumour or an old story.
## Returns whether a chat began.
func start_chat(village: Outdoor, only := "") -> bool:
	if not _chat.is_empty() or village == null or game == null:
		return false
	if only == "" and "village_rumours" in game and randf() < VillageRumours.CHAT_CHANCE:
		if start_rumour_chat(village):
			return true
	var by_role := {}
	for v in village.villagers:
		if is_instance_valid(v):
			by_role[v.role] = v
	var hero: Vector3 = game.player.global_position
	var options := []
	for tie in TIES:
		var key := key_of(tie)
		if only != "" and key != only:
			continue
		var a: Villager = by_role.get(tie.a)
		var b: Villager = by_role.get(tie.b)
		if a == null or b == null or not _free(a) or not _free(b):
			continue
		if _flat(a.global_position, b.global_position) > CHAT_REACH:
			continue
		if minf(_flat(a.global_position, hero), _flat(b.global_position, hero)) > HEAR_RANGE:
			continue
		options.append([tie, a, b])
	if options.is_empty():
		return false
	var pick: Array = options[randi() % options.size()]
	var tie: Dictionary = pick[0]
	var a: Villager = pick[1]
	var b: Villager = pick[2]
	var key := key_of(tie)
	var all := exchanges(tie)
	var count := int(_talks.get(key, 0))
	_talks[key] = count + 1
	var chosen: Array = all[count % all.size()]
	var first: String = chosen[0]
	var second := "b" if first == "a" else "a"
	var lines := []
	for i in chosen[1].size():
		lines.append([first if i % 2 == 0 else second, chosen[1][i]])
	return _begin(village, key, a, b, lines)


## Any two free villagers, one of them near the hero and the other close
## by, chat about small things, a rumour or an old story (see
## VillageRumours). Returns whether a chat began.
func start_rumour_chat(village: Outdoor) -> bool:
	if not _chat.is_empty() or village == null or game == null or not ("village_rumours" in game):
		return false
	var hero: Vector3 = game.player.global_position
	var free := []
	for v in village.villagers:
		if is_instance_valid(v) and _free(v):
			free.append(v)
	var near := []
	for v in free:
		if _flat(v.global_position, hero) <= HEAR_RANGE:
			near.append(v)
	near.shuffle()
	for a in near:
		# The closest free villager keeps them company.
		var b: Villager = null
		var best := CHAT_REACH
		for o in free:
			var d := _flat(a.global_position, o.global_position)
			if o != a and d <= best:
				best = d
				b = o
		if b == null:
			continue
		var said: Array = game.village_rumours.chat_for(a.role, b.role)
		if said.is_empty():
			continue
		var lines := []
		for entry in said:
			lines.append([entry[0], game.village_rumours.fill(entry[1])])
		return _begin(village, RUMOUR_KEY + key_of({"a": a.role, "b": b.role}), a, b, lines)
	return false


## Free for a chat, and not telling the hero a story just now.
func _free(v: Villager) -> bool:
	if not v.can_chat():
		return false
	return not ("village_rumours" in game and game.village_rumours.is_telling(v))


## Starts the chat between `a` and `b`: `lines` are [side ("a" or "b"),
## text] in the order said. A fresh fright or the weather may be on their
## minds instead (see VillageWorries).
func _begin(village: Outdoor, key: String, a: Villager, b: Villager, lines: Array) -> bool:
	var worry: Array = game.village_worries.chat_lines(village) if "village_worries" in game else []
	if not worry.is_empty():
		var filled := _fill(worry)
		lines = []
		for i in filled.size():
			lines.append(["a" if i % 2 == 0 else "b", filled[i]])
	var said := []
	for entry in lines:
		said.append([a if entry[0] == "a" else b, entry[1]])
	# Someone who keeps a stall or a post stays put; the other walks over.
	# If both stay put, the second one comes.
	var walker: Villager = null
	if _flat(a.global_position, b.global_position) > CHAT_NEAR:
		walker = a if b.keeps_spot() and not a.keeps_spot() else b
	var host: Villager = a if walker == b else b
	if walker != null and not walker.join_chat(host, true):
		return false
	host.join_chat(walker if walker else a, false)
	if walker == null:
		a.join_chat(b, false)
	_chat = {"key": key, "a": a, "b": b, "lines": said, "wait": 0.0, "time": 0.0}
	return true


func _run_chat(delta: float) -> void:
	# The village may be gone (the hero went elsewhere): then so is the chat.
	if not is_instance_valid(_chat.a) or not is_instance_valid(_chat.b):
		stop()
		return
	var a: Villager = _chat.a
	var b: Villager = _chat.b
	if a.chat_broken or b.chat_broken:
		stop()
		return
	_chat.time += delta
	if not (a.in_chat_place() and b.in_chat_place()):
		# Still on the way; anything else (night, the herald, a hero who
		# spoke to them) has taken them away.
		var on_way := (a.in_chat_place() or a.heading_to_chat()) and (b.in_chat_place() or b.heading_to_chat())
		if not on_way or _chat.time > WALK_LIMIT:
			stop()
		return
	_chat.wait -= delta
	if _chat.wait > 0.0:
		return
	var lines: Array = _chat.lines
	if lines.is_empty():
		stop()
		return
	var speaker: Villager = lines[0][0]
	var other: Villager = b if speaker == a else a
	# A line still being read (the speaker's own, or the partner's) is not
	# cut short: the bubbles take turns and never flicker.
	if speaker.is_busy_talking() or other._bubble_time > 0.0:
		return
	# Someone close by is talking (to the hero, say): the line waits its turn
	# instead of covering theirs.
	if speaker.talker_near(other) != null:
		return
	var text: String = lines.pop_front()[1]
	var time := line_time(text)
	speaker.chat_say(text, time)
	_chat.wait = time + LINE_GAP
	if game and _flat(speaker.global_position, game.player.global_position) <= HEAR_RANGE:
		_overheard(_chat.key)


## How long a line stays up: long enough to read it.
static func line_time(text: String) -> float:
	return clampf(2.0 + text.length() * 0.055, Villager.MIN_SAY_TIME + 0.5, 6.5)


func _overheard(key: String) -> void:
	if known.has(key) or key.begins_with(RUMOUR_KEY):
		return
	known[key] = true
	Events.teach(HOW_TO)


## Ends the chat going on: both go back to their day.
func stop() -> void:
	for side in ["a", "b"]:
		var v = _chat.get(side)
		if v != null and is_instance_valid(v):
			v.leave_chat()
	_chat = {}


static func _flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


# --- Saved game ---------------------------------------------------------------

func for_save() -> Array:
	return known.keys()


## Back from the saved game; unknown ties are left out, older saved games
## start with none known.
func load_from(saved) -> void:
	clear()
	if saved is Array:
		for key in saved:
			if not tie_by_key(str(key)).is_empty():
				known[str(key)] = true
