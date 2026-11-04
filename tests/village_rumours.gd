extends SceneTree
## Headless test for small talk, rumours and stories in the village (see
## VillageRumours): every line has its English, every villager has something
## to tell, every third word is a rumour or a story, a story goes on line by
## line while the hero stays close and stops when the hero walks off, a slain
## monster turns its rumour into news (kept in the saved game), and any two
## free villagers near the hero can chat about it.
## Run with: godot --headless -s tests/village_rumours.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Testheld Geruechte"


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
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: village rumours")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


func _free_everyone() -> void:
	for v in game.level.villagers:
		v._start("idle", 60.0)
		v._bubble_time = 0.0
		v._bubble_hold = 0.0


func _line_of(v: Villager) -> String:
	return v._bubble.text.get_slice("\n", 1)


func _english(line: String, what: String) -> void:
	check(Lang.EN.has(line), "%s: \"%s\" has an English text" % [what, line])


func _test() -> void:
	# The tables.
	for entry in VillageRumours.SMALL_TALK:
		var lines: Array = entry.lines if entry is Dictionary else entry
		check(lines.size() >= 2, "small talk has at least two lines")
		for line in lines:
			_english(line, "small talk")
	for id in VillageRumours.RUMOURS:
		var r: Dictionary = VillageRumours.RUMOURS[id]
		check(not r.tell.is_empty() and not r.chat.is_empty(), "%s can be told and chatted about" % id)
		for role in r.who + r.get("not", []):
			check(Villager.ROLES.has(role), "%s: %s is a villager" % [id, role])
		if r.has("quest"):
			check(Quests.ALL.has(r.quest), "%s: the task %s exists" % [id, r.quest])
		if r.has("slain"):
			check(r.has("after_tell") and r.has("after_chat"), "%s has news for after" % id)
		var all: Array = r.tell + r.get("after_tell", [])
		for lines in r.chat + r.get("after_chat", []):
			check(lines.size() >= 2, "%s: a chat has at least two lines" % id)
			all += lines
		for line in all:
			_english(line, id)
	for id in VillageRumours.STORIES:
		var s: Dictionary = VillageRumours.STORIES[id]
		check(s.lines.size() >= 2, "the story %s has a few lines" % id)
		for line in s.lines + [s.reply]:
			_english(line, id)
	_english(VillageRumours.HOW_TO, "the explanation")
	var rumours: VillageRumours = game.village_rumours
	for role in Villager.ROLES:
		check(not rumours.told_by(role).is_empty(), "villager %s has something to tell" % role)
		check(not rumours.told_by(role, true).is_empty(), "villager %s has a short rumour for the counter" % role)

	# Chats for any two: small things, a rumour or a story, and nobody talks
	# about themselves.
	var gorm_talk: Array = VillageRumours.SMALL_TALK[8].lines
	for i in 200:
		var said := rumours.chat_for("1", "5")
		check(said.size() >= 2, "Gorm and Fritz find something to talk about")
		check(said.size() < 2 or said[0][1] != gorm_talk[0], "Gorm does not ask whether one hears Gorm hammering")
		for entry in said:
			check(entry[0] in ["a", "b"], "each line has a side")
		for id in VillageRumours.STORIES:
			if said.size() > 1 and said[0][1] == VillageRumours.STORIES[id].lines[0]:
				var teller: String = "1" if said[0][0] == "a" else "5"
				check(teller in VillageRumours.STORIES[id].who, "the story %s is told by its teller" % id)
				check(said.back()[1] == VillageRumours.STORIES[id].reply and said.back()[0] != said[0][0], "the other one answers the story")

	# A fresh hero in the village by day.
	game.hero_name = HERO
	game.save_slot = 1
	game.met.clear()
	game.quests.clear()
	game.reputation.clear()
	game.village_talk.clear()
	rumours.clear()
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")
	if game.level.night:
		game.level.set_hour(12.0)
	game.village_worries.clear()
	_free_everyone()

	# Every third word with Fritz is a rumour or a story.
	var fritz := _villager("5")
	check(fritz != null, "Fritz lives in the village")
	if fritz == null:
		return
	game.player.global_position = fritz.global_position + Vector3(2, 0, 0)
	check(not rumours.tell(fritz), "the first word is his usual one")
	check(not rumours.tell(fritz), "and the second")
	check(rumours.tell(fritz), "the third is a rumour or a story")
	var options := rumours.told_by("5")
	var first: String = _line_of(fritz)
	check(fritz._bubble_time > 0.0, "Fritz says it")
	check(game.lore.has(VillageRumours.HOW_TO), "the compendium explains the rumours")
	var heard := false
	for o in options:
		if rumours.fill(o[0]) == first:
			heard = true
	check(heard, "what Fritz says is one of his: %s" % first)

	# A story goes on line by line while the hero listens.
	rumours._story = {}
	fritz._bubble_time = 0.0
	var story: Array = VillageRumours.STORIES.baer.lines
	rumours._talks["5"] = VillageRumours.TELL_EVERY - 1
	rumours._turns["tell-5"] = options.find(story)
	check(rumours.tell(fritz) and rumours.is_telling(fritz), "Fritz starts his bear story")
	var said := [_line_of(fritz)]
	for i in 600:
		fritz._update_bubble(0.1)
		rumours.update(0.1, game.level)
		if fritz._bubble_time > 0.0 and _line_of(fritz) != said.back():
			said.append(_line_of(fritz))
		if not rumours.is_telling(fritz) and fritz._bubble_time <= 0.0:
			break
	check(said.size() == story.size(), "the whole story is told: %d of %d lines" % [said.size(), story.size()])
	check(said.size() > 0 and said[0] == Lang.t(story[0]) and said.back() == Lang.t(story.back()), "in the right order")

	# The hero walks off: the story stops.
	fritz._bubble_time = 0.0
	rumours._talks["5"] = VillageRumours.TELL_EVERY - 1
	rumours._turns["tell-5"] = options.find(story)
	check(rumours.tell(fritz), "Fritz starts again")
	game.player.global_position = fritz.global_position + Vector3(VillageRumours.HEAR_RANGE + 5, 0, 0)
	fritz._bubble_time = 0.0
	rumours.update(0.1, game.level)
	check(not rumours.is_telling(fritz), "nobody tells a story to an empty street")

	# A trader only shares one line before the goods.
	for short in rumours.told_by("6", true):
		check(short.size() == 1, "a trader's rumour is a single line")

	# A slain dragon turns the rumour into news, also after a reload.
	var bruno_before := rumours.told_by("3")
	Events.bus().enemy_slain.emit("drache")
	check(rumours.is_settled("drache"), "the dragon is known to be slain")
	var bruno_after := rumours.told_by("3")
	check(bruno_after.has([VillageRumours.RUMOURS.drache.after_tell[0]]) and not bruno_before.has([VillageRumours.RUMOURS.drache.after_tell[0]]), "Bruno now tells of the slain dragon")
	var saved := rumours.for_save()
	rumours.clear()
	check(not rumours.is_settled("drache"), "cleared, nothing is slain")
	rumours.load_from(JSON.parse_string(JSON.stringify(saved)))
	check(rumours.is_settled("drache") and rumours.told_any, "the slain dragon is kept in the saved game")
	rumours.load_from(null)
	check(not rumours.is_settled("drache"), "an older saved game starts with nothing slain")

	# The bandit chief's task done counts too.
	check(not rumours.is_settled("hauptmann"), "the bandit chief still stands")
	game.quests.state["hauptmann"] = {"state": "done"}
	check(rumours.is_settled("hauptmann"), "with the task done, the bandit chief is news")
	game.quests.clear()

	# Any two free villagers near the hero chat; the hero learns no tie from it.
	game.village_talk.stop()
	rumours._story = {}
	_free_everyone()
	var lene := _villager("2")
	game.player.global_position = lene.global_position + Vector3(2, 0, 0)
	var talk: VillageTalk = game.village_talk
	check(talk.start_rumour_chat(game.level), "two villagers start a chat")
	check(talk.current().begins_with(VillageTalk.RUMOUR_KEY), "it is a chat between any two: %s" % talk.current())
	talk._timer = 1e9
	for i in 900:
		for v in game.level.villagers:
			v._physics_process(0.1)
		talk.update(0.1, game.level)
		if not talk.is_chatting():
			break
	check(not talk.is_chatting(), "the chat is over")
	check(talk.known.is_empty(), "no tie is learnt from a chat between any two")
	# Nobody telling the hero a story is pulled into a chat.
	_free_everyone()
	for v in game.level.villagers:
		if v != lene:
			v.visible = false
	var hanna := _villager("9")
	hanna.visible = true
	hanna.global_position = lene.global_position + Vector3(1.5, 0, 0)
	rumours._story = {"who": lene, "lines": ["x"], "wait": 1.0}
	check(not talk.start_rumour_chat(game.level), "a teller is not pulled into a chat")
	rumours._story = {}
	check(talk.start_rumour_chat(game.level), "once done, Lene and Hanna chat")
	talk.stop()
	for v in game.level.villagers:
		v.visible = true
