extends SceneTree
## Headless test for the villagers talking to each other (see VillageTalk):
## every tie and line is sound and has its English, a chat walks one villager
## over to the other and plays its lines one bubble at a time, the hero who
## overhears it learns the tie, a hero who speaks up ends it without the text
## flickering, and ties count for reputation and the reconciliation task.
## Run with: godot --headless -s tests/village_talk.gd

const HEROES := ["Testheld Gerede"]

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	for hero in HEROES:
		game.delete_save(game.save_path(hero))
	if failures == 0:
		print("PASS: village talk")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


## Runs into a villager the way the game does it, as a fresh visit.
func _bump(role: String) -> void:
	for s in game.level.stations:
		if s.get("npc") == _villager(role):
			s.npc._update_bubble(Villager.MIN_SAY_TIME)
			game._use_station(s)
			if game.menus.is_open():
				game.menus.close()
			return
	check(false, "villager %s has a station" % role)


## Lets the village and the chat run for `seconds`, in small steps.
func _run(seconds: float, step := 0.1) -> Array:
	var said := []
	var talk: VillageTalk = game.village_talk
	# Only the chats the test starts itself.
	talk._timer = 1e9
	var t := 0.0
	while t < seconds:
		for v in game.level.villagers:
			v._physics_process(step)
		talk.update(step, game.level)
		for v in game.level.villagers:
			if v._bubble_time > 0.0 and v._bubble_time > VillageTalk.line_time(v._bubble.text.get_slice("\n", 1)) - step * 1.5:
				var line: String = v._bubble.text
				if said.is_empty() or said.back() != line:
					said.append(line)
		t += step
	return said


func _place_hero_near(v: Villager) -> void:
	game.player.global_position = v.global_position + Vector3(3, 0, 3)


func _test() -> void:
	# The tables.
	var keys := {}
	for tie in VillageTalk.TIES:
		var key := VillageTalk.key_of(tie)
		check(not keys.has(key) and VillageTalk.tie_between(tie.b, tie.a) == tie, "%s is listed once" % key)
		keys[key] = true
		check(Villager.ROLES.has(tie.a) and Villager.ROLES.has(tie.b) and tie.a != tie.b, "%s ties two villagers" % key)
		check(VillageTalk.KINDS.has(tie.kind), "%s has a known kind" % key)
		var all: Array = tie.talks + tie.get("bounty", []) + tie.get("mended", [])
		for id in tie.get("after", {}):
			check(Quests.ALL.has(id), "%s: the task %s exists" % [key, id])
			all += tie.after[id]
		if tie.has("mended_by"):
			check(Quests.ALL.has(tie.mended_by) and VillageTalk.KINDS.has(tie.mended_kind), "%s can be mended" % key)
		for lines in all:
			check(lines.size() >= 2, "%s: an exchange has at least two lines" % key)
			for line in lines:
				check(Lang.EN.has(line), "%s: \"%s\" has an English text" % [key, line])
	for kind in VillageTalk.KINDS:
		check(Lang.EN.has(VillageTalk.KINDS[kind].name), "the kind %s has an English name" % kind)
	for group in VillageTalk.HERO_TALKS:
		for line in VillageTalk.HERO_TALKS[group]:
			check(Lang.EN.has(line), "\"%s\" has an English text" % line)
	for role in Outdoor.VILLAGERS:
		check(VillageTalk.GOALS.has(role) and Lang.EN.has(VillageTalk.GOALS[role]), "villager %s wants something, in English too" % role)
	check(Lang.EN.has(VillageTalk.HOW_TO), "the explanation has an English text")
	check(Lang.EN.has(Items.ALL.wetzstein.name) and Lang.EN.has(Items.ALL.wetzstein.effect), "the whetstone has English texts")

	# A fresh hero in the village by day.
	game.hero_name = HEROES[0]
	game.met.clear()
	game.quests.clear()
	game.reputation.clear()
	game.village_talk.clear()
	game.player.bag.clear()
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")
	var talk: VillageTalk = game.village_talk
	var lene := _villager("2")
	var pip := _villager("7")
	check(lene != null and pip != null, "Lene and Pip live in the village")
	if lene == null or pip == null:
		return
	if game.level.night:
		game.level.set_hour(12.0)
	for v in game.level.villagers:
		v._start("idle", 30.0)
		v._bubble_time = 0.0
		v._bubble_hold = 0.0

	# Nobody talks where the hero cannot hear it.
	game.player.global_position = Vector3(-500, 0, -500)
	check(not talk.start_chat(game.level, "2-7"), "no chat far from the hero")

	# Mother and child: one walks over, they talk in turns.
	_place_hero_near(lene)
	check(talk.start_chat(game.level, "2-7"), "a chat between Lene and Pip begins")
	check(lene.chat_partner == pip and pip.chat_partner == lene, "they are each other's partners")
	check(lene.heading_to_chat() or pip.heading_to_chat() or (lene.in_chat_place() and pip.in_chat_place()), "one walks over, or they are close already")
	check(not lene.can_chat() and not pip.can_chat(), "nobody else can pull them into a second chat")
	# Until they stand together: then they are side by side.
	var waited := 0.0
	while not (lene.in_chat_place() and pip.in_chat_place()) and waited < VillageTalk.WALK_LIMIT:
		for v in [lene, pip]:
			v._physics_process(0.1)
		waited += 0.1
	check(lene.global_position.distance_to(pip.global_position) < Villager.CHAT_GAP + 1.5, "they stand close together (%.1f m)" % lene.global_position.distance_to(pip.global_position))
	var said := _run(60.0)
	check(not talk.is_chatting(), "the chat is over after a minute")
	check(lene.chat_partner == null and pip.chat_partner == null, "both are free again")
	check(said.size() >= 2, "at least two lines were said (%d)" % said.size())
	var first: Array = VillageTalk.TIES[1].talks[0]
	check(said.size() > 0 and said[0] == "%s:\n%s" % [lene.display_name, Lang.t(first[0])], "Lene starts: %s" % [said[0] if said.size() > 0 else "-"])
	check(said.size() > 1 and said[1].begins_with(pip.display_name + ":"), "Pip answers")
	check(talk.known.has("2-7"), "the hero overheard the tie")
	check(game.lore.has(VillageTalk.HOW_TO), "the compendium explains the chats")
	check(talk.known_ties_of("7").size() == 1 and talk.known_ties_of("7")[0][1] == lene.display_name, "Pip's family is known: Lene")

	# Two bubbles never show at once.
	for v in game.level.villagers:
		v._start("idle", 30.0)
	check(talk.start_chat(game.level, "2-7"), "a second chat begins")
	var both := false
	for i in 400:
		for v in [lene, pip]:
			v._physics_process(0.1)
		talk._timer = 1e9
		talk.update(0.1, game.level)
		if lene._bubble_time > 0.0 and pip._bubble_time > 0.0:
			both = true
	check(not both, "the two bubbles take turns")
	talk.stop()

	# The hero speaks up: no flicker while a line is fresh, then the chat ends.
	for v in game.level.villagers:
		v._start("idle", 30.0)
		v._bubble_time = 0.0
		v._bubble_hold = 0.0
	lene.global_position = pip.global_position + Vector3(1.5, 0, 0)
	check(talk.start_chat(game.level, "2-7"), "a third chat begins right where they stand")
	_run(0.2)
	var speaker := lene if lene._bubble_time > 0.0 else pip
	check(speaker._bubble_time > 0.0, "a line is up")
	var line := speaker._bubble.text
	var station: Dictionary = speaker.station
	game._use_station(station)
	check(speaker._bubble.text == line, "a bump on a fresh chat line does not swap the text")
	speaker._update_bubble(Villager.MIN_SAY_TIME)
	game._use_station(station)
	check(speaker._bubble.text != line, "after the pause the hero gets an answer")
	_run(0.2)
	check(not talk.is_chatting() and lene.chat_partner == null and pip.chat_partner == null, "speaking to one of them ends the chat")

	# Reputation: family and friends of the one helped are glad, rivals not.
	var rep: Reputation = game.reputation
	check(talk.bond("2", "3") == "close" and talk.bond("1", "S") == "rival" and talk.bond("2", "Y") == "", "bonds between villagers")
	for role in ["2", "3", "5", "Y", "Z"]:
		game.met[role] = true
	game.quests.state["kuerbis"] = {"state": "active", "count": 0}
	game.player.bag.append("kuerbis")
	_bump("5")
	check(game.quests.is_done("kuerbis"), "the pumpkin reached Fritz")
	check(rep.points("3") == VillageTalk.CLOSE_WORD, "Lene's husband is glad to hear it")
	check(rep.points("Y") == Reputation.WORD_OF_MOUTH, "someone with no tie to Lene hears the usual")
	rep.clear()
	game.met["4"] = true
	game.met["G"] = true
	game.quests.state["raeuberplage"] = {"state": "done", "count": 5}
	Events.bus().quest_done.emit("raeuberplage")
	check(rep.points("G") == 0, "the guard's rival does not care")
	check(rep.points("9") == 0, "Hanna is not met, so she heard nothing")

	# Talk about the world: the bounty board and finished tasks.
	game.bounties.posted = ["woelfe"]
	var lines := []
	for ex in talk.exchanges(VillageTalk.tie_by_key("4-G")):
		lines += ex[1]
	var notice := Lang.t(Bounties.POOL.woelfe.title)
	check(lines.any(func(l): return l.contains(notice)), "the guard and the guild master talk about today's notice")
	check(lines.any(func(l): return l.contains(game.hero_name)), "and about the hero who cleared the pass")
	check(not lines.any(func(l): return l.contains("{")), "no placeholder is left in the lines")

	# Gorm and Hagen: rivals until Hagen's whetstone reaches the forge.
	var ties := VillageTalk.tie_by_key("1-S")
	check(talk.kind_of(ties) == "rivalen", "the smith and the stonemason are rivals")
	check(not game.quests.is_available("versoehnung"), "Hagen keeps his quarrel to himself from strangers")
	rep.gain("S", Reputation.LEVELS[Reputation.FRIENDLY].points)
	check(game.quests.is_available("versoehnung"), "a friend of Hagen's hears about the quarrel")
	game.refresh_quest_marks()
	check(_villager("S").quest_mark() == "!", "Hagen shows a ! for his task")
	_bump("S")
	check(game.quests.is_active("versoehnung") and game.player.bag.has("wetzstein"), "Hagen hands over the whetstone")
	_bump("1")
	check(game.quests.is_done("versoehnung") and not game.player.bag.has("wetzstein"), "Gorm takes the whetstone")
	check(talk.kind_of(ties) == "freunde" and talk.bond("1", "S") == "close", "the two are friends now")
	var mended: Array = talk.exchanges(ties)
	check(mended[0][1][0] == Lang.t(ties.mended[0][0]), "they talk like friends now")

	# The compendium lists goals and overheard ties.
	game.met["7"] = true
	game.menus.compendium_page = "ruf"
	game.menus.open("kompendium")
	var texts := []
	for l in game.menus._box.find_children("*", "Label", true, false):
		texts.append(l.text)
	check(texts.any(func(t): return t.contains(Lang.t(VillageTalk.GOALS["7"]))), "the reputation page shows what Pip wants")
	check(texts.any(func(t): return t.contains(Lang.t("Familie")) and t.contains(lene.display_name)), "and that Lene is Pip's family")
	game.menus.close()
	game.menus.compendium_page = "wissen"

	# Kept in the saved game.
	var saved := talk.for_save()
	talk.clear()
	check(talk.known.is_empty(), "a new hero knows no ties")
	talk.load_from(saved + ["x-y"])
	check(talk.known.has("2-7") and not talk.known.has("x-y"), "known ties come back, unknown ones are left out")
	check(game.save_game(), "the game saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path(HEROES[0])))
	check(data.get("ties", []).has("2-7"), "the saved game keeps the overheard ties")
