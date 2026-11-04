extends SceneTree
## Headless test for the villagers grumbling about the weather and taking
## fright (see VillageWorries): every line has its English, bad weather and
## the night are worries, a scare on the event bus draws a cry from someone
## near the hero (but not from far away, and not twice in a row), a chat may
## be about the worry of the moment, nightfall and lightning report their
## scares, and a monster on the hunt among the villagers frightens them.
## Run with: godot --headless -s tests/village_worries.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Testheld Sorgen"


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
		print("PASS: village worries")
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
		v._start("idle", 30.0)
		v._bubble_time = 0.0
		v._bubble_hold = 0.0


## The lines said in the village while the worries run for `seconds`.
func _run(seconds: float, step := 0.1) -> Array:
	var said := []
	var worries: VillageWorries = game.village_worries
	var t := 0.0
	while t < seconds:
		worries.update(step, game.level)
		for v in game.level.villagers:
			if v._bubble_time > 0.0:
				var line: String = v._bubble.text.get_slice("\n", 1)
				if not said.has(line):
					said.append(line)
			v._update_bubble(step)
		t += step
	return said


func _german(lines: Array) -> Array:
	var out := []
	for line in lines:
		out.append(Lang.t(line))
	return out


func _test() -> void:
	# The tables.
	for kind in VillageWorries.MOODS:
		var mood: Dictionary = VillageWorries.MOODS[kind]
		check(mood.say.size() >= 3, "%s: there are a few lines to say" % kind)
		check(mood.chat.size() >= 1, "%s: there is a chat about it" % kind)
		for line in mood.say:
			check(Lang.EN.has(line), "%s: \"%s\" has an English text" % [kind, line])
		for lines in mood.chat:
			check(lines.size() >= 2, "%s: a chat has at least two lines" % kind)
			for line in lines:
				check(Lang.EN.has(line), "%s: \"%s\" has an English text" % [kind, line])
	for kind in VillageWorries.LASTING:
		check(VillageWorries.MOODS.has(kind), "the lasting worry %s has lines" % kind)
	for role in VillageWorries.ROLE_SAYS:
		check(Villager.ROLES.has(role), "villager %s exists" % role)
		for kind in VillageWorries.ROLE_SAYS[role]:
			check(VillageWorries.MOODS.has(kind), "%s: the worry %s exists" % [role, kind])
			for line in VillageWorries.ROLE_SAYS[role][kind]:
				check(Lang.EN.has(line), "%s: \"%s\" has an English text" % [role, line])
	var links: Array = Events.bus().scare_happened.get_connections()
	check(links.size() == 1, "the village listens to scares once: %d" % links.size())

	# A fresh hero in the village by day, under clear skies.
	game.hero_name = HERO
	game.met.clear()
	game.quests.clear()
	game.reputation.clear()
	game.village_talk.clear()
	game.load_level(game._outdoor_index(), false)
	var village: Outdoor = game.level
	check(village is Outdoor, "the village is loaded")
	if not village is Outdoor:
		return
	var worries: VillageWorries = game.village_worries
	worries.clear()
	game.village_talk._timer = 1e9
	village.set_hour(12.0)
	village.set_weather(Weather.CLEAR)
	check(worries.conditions(village).is_empty(), "a clear noon worries nobody: %s" % [worries.conditions(village)])
	var lene := _villager("2")
	check(lene != null, "Lene lives in the village")
	if lene == null:
		return
	_free_everyone()
	check(lene.can_remark(), "Lene at work can speak up")

	# The weather and the night.
	village.set_weather(Weather.RAIN)
	check(worries.conditions(village) == ["regen"], "rain is a worry: %s" % [worries.conditions(village)])
	village.set_weather(Weather.FOG)
	check(worries.conditions(village).has("nebel"), "so is fog")
	village.set_weather(Weather.STORM)
	check(worries.conditions(village).has("gewitter"), "so is a storm")
	village.set_weather(Weather.CLEAR)
	village.set_hour(6.0)
	check(worries.conditions(village) == ["kalt"], "the early morning is cold: %s" % [worries.conditions(village)])
	village.set_hour(12.0)

	# Far from the hero, nobody grumbles.
	game.player.global_position = Vector3(-500, 0, -500)
	_free_everyone()
	village.set_weather(Weather.RAIN)
	worries._remark_timer = 0.0
	var said := _run(2.0)
	check(said.is_empty(), "nobody grumbles to an empty street: %s" % [said])

	# Near the hero, someone grumbles about the rain.
	game.player.global_position = lene.global_position + Vector3(2, 0, 2)
	_free_everyone()
	worries._remark_timer = 0.0
	said = _run(1.0)
	var rain_lines := _german(VillageWorries.MOODS.regen.say)
	for role in VillageWorries.ROLE_SAYS:
		rain_lines += _german(VillageWorries.ROLE_SAYS[role].get("regen", []))
	check(said.size() == 1 and rain_lines.has(said[0]), "someone grumbles about the rain: %s" % [said])
	check(worries._remark_timer >= VillageWorries.REMARK_EVERY.x - 1.0, "and not again for a while")

	# The weather turning bad brings a grumble soon.
	village.set_weather(Weather.CLEAR)
	_run(0.2)
	worries._remark_timer = 999.0
	village.set_weather(Weather.FOG)
	_run(0.2)
	check(worries._remark_timer <= VillageWorries.AFTER_TURN.y, "fog rolling in brings a grumble soon (%.1f s)" % worries._remark_timer)
	village.set_weather(Weather.CLEAR)

	# A scare on the bus: a cry a moment later, about that scare.
	_free_everyone()
	worries._remark_timer = 999.0
	Events.scare("drache")
	check(worries.scare == "drache", "the dragon is on everyone's mind")
	said = _run(VillageWorries.CRY_DELAY.y + 0.5)
	var dragon_lines := _german(VillageWorries.MOODS.drache.say)
	for role in VillageWorries.ROLE_SAYS:
		dragon_lines += _german(VillageWorries.ROLE_SAYS[role].get("drache", []))
	check(said.size() == 1 and dragon_lines.has(said[0]), "someone cries out about the dragon: %s" % [said])
	# The same scare right after: no second cry.
	_free_everyone()
	Events.scare("drache")
	said = _run(VillageWorries.CRY_DELAY.y + 0.5)
	check(said.is_empty(), "a second scare of the same kind draws no second cry: %s" % [said])
	# A scare that lasts (weather) or is unknown is not a scare.
	worries.clear()
	Events.scare("regen")
	Events.scare("unbekannt")
	check(worries.scare == "" and worries._cry.is_empty(), "only real scares count")

	# A chat while a scare is fresh is about it.
	worries.clear()
	Events.scare("woelfe")
	worries._cry = {}
	var talks := 0
	for i in 20:
		var lines := worries.chat_lines(village)
		if not lines.is_empty():
			talks += 1
			check(VillageWorries.MOODS.woelfe.chat.has(lines), "the chat is about the wolves: %s" % [lines])
	check(talks >= 8, "most chats are about the fresh scare (%d of 20)" % talks)
	worries.scare_left = 0.01
	_run(0.1)
	check(worries.scare == "", "the scare is forgotten after a while")
	village.set_weather(Weather.CLEAR)
	check(worries.chat_lines(village).is_empty(), "with nothing on their minds, the pair talks as usual")
	# VillageTalk takes the worry when there is one.
	village.set_weather(Weather.STORM)
	Events.scare("blitz")
	worries._cry = {}
	_free_everyone()
	var pip := _villager("7")
	pip.global_position = lene.global_position + Vector3(1.5, 0, 0)
	game.player.global_position = lene.global_position + Vector3(2, 0, 2)
	var storm_talk := false
	for i in 8:
		_free_everyone()
		if game.village_talk.start_chat(village, "2-7"):
			var first: String = game.village_talk._chat.lines[0][1]
			var worry := []
			for lines in VillageWorries.MOODS.blitz.chat + VillageWorries.MOODS.gewitter.chat:
				worry.append(Lang.t(lines[0]))
			if worry.has(first):
				storm_talk = true
			game.village_talk.stop()
	check(storm_talk, "in a storm after a bolt, Lene and Pip talk about it")
	village.set_weather(Weather.CLEAR)

	# Lightning and nightfall report their scares.
	var heard := []
	var listen := func(kind: String) -> void: heard.append(kind)
	Events.bus().scare_happened.connect(listen)
	village.strike()
	check(heard.has("blitz"), "lightning frightens the village")
	village.day = 0
	while not Moon.is_full(village.day):
		village.day += 1
	village.set_hour(20.0)
	village.set_hour(22.0)
	check(heard.has("woelfe"), "a full-moon night falls with the wolves: %s" % [heard])
	village.set_hour(12.0)
	village.day += 1
	village.set_hour(22.0)
	check(heard.has("tote"), "an ordinary night falls with the dead: %s" % [heard])
	village.set_hour(12.0)
	while not Moon.is_new(village.day):
		village.day += 1
	village.set_hour(22.0)
	check(heard.has("grauen"), "a new-moon night falls with the horror: %s" % [heard])
	check(worries.conditions(village).has("dunkel") and worries.conditions(village).has("kalt"), "a new-moon night is dark and cold: %s" % [worries.conditions(village)])
	Events.bus().scare_happened.disconnect(listen)
	village.set_hour(12.0)

	# A monster on the hunt close to the villagers.
	worries.clear()
	_free_everyone()
	var monster: Enemy = null
	for e in village.enemies:
		if is_instance_valid(e) and not e.dead:
			monster = e
			break
	check(monster != null, "there is a monster in the open air")
	if monster != null:
		var was: Vector3 = monster.global_position
		var awake: bool = monster._awake
		monster.global_position = lene.global_position + Vector3(4, 0, 0)
		monster._awake = true
		worries._monster_timer = 0.0
		worries.update(0.1, village)
		check(worries.scare == "ungeheuer", "a hunting monster among them is a fright: %s" % worries.scare)
		monster._awake = awake
		monster.global_position = was
	worries.clear()
