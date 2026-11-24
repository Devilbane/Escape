extends SceneTree
## Headless test for Elsbeth's blessing round (see BlessRound) and her thawing of frozen Fritz:
## - the round has the temple, the entrances, the fountain and the smithy, each with an open standing place,
## - in the morning she sets out, walks to each place, raises her staff, says its line and the light is cast,
## - the round is done once a day, and an alarm or the night calls her off it,
## - frozen Fritz is found on the round and thawed for the day, and thanks her.
## Run with: godot --headless -s tests/bless_round.gd --fixed-fps 60

var failures := 0
var game: Node
var frames := 0
const STEP := 1.0 / 60.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path())
	print("PASS: bless round" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _run(village: Outdoor, seconds: float, each := Callable()) -> void:
	for i in int(seconds / STEP):
		for v: Villager in village.villagers:
			v._physics_process(STEP)
		if each.is_valid():
			each.call()


func _test() -> void:
	for line in BlessRound.SAYS.values():
		check(Lang.EN.has(line), "the blessing has an English text: " + line)
	check(Lang.EN.has(BlessRound.THANKS), "Fritz's thanks have an English text")
	check(is_equal_approx(BlessFx.strength_at(0.0), 0.0) and BlessFx.strength_at(2.0) > 0.99 \
			and BlessFx.strength_at(BlessFx.LIFE) == 0.0, "the light swells in, holds and fades out")
	if game.state == game.State.TITLE:
		game._start_playing()
	game.escaped = true
	game.hero_name = "Testheld Segen"
	game.load_level(game._outdoor_index(), false)
	var village: Outdoor = game.level
	game.state = game.State.PLAYING
	game.village_talk._timer = 1e9
	game.village_worries._remark_timer = 1e9
	village.house_given = true
	village.set_weather(Weather.CLEAR)
	for e in village.enemies:
		e.set_physics_process(false)
	var elsbeth: Villager
	var fritz: Villager
	for v: Villager in village.villagers:
		if v.role == BlessRound.ROLE:
			elsbeth = v
		if v.role == FrozenFritz.ROLE:
			fritz = v
		if v.at_home:
			v.set_night(false, true)
	check(elsbeth != null and fritz != null, "Elsbeth and Fritz are in the village")
	if elsbeth == null:
		return
	village.day = 10
	village.set_hour(8.4)
	var sites := BlessRound.sites(village)
	var kinds := sites.map(func(s: BlessRound.Site) -> String: return s.kind)
	for kind in [BlessRound.KIND_TEMPLE, BlessRound.KIND_GATE, BlessRound.KIND_FOUNTAIN, BlessRound.KIND_SMITHY]:
		check(kinds.has(kind), "the round has a place of kind " + kind)
	for s: BlessRound.Site in sites:
		check(village.is_open(village.world_to_cell(s.stand)), "%s has an open place to stand" % s.kind)
	check(kinds.find(BlessRound.KIND_TEMPLE) == 0, "the temple comes first")
	# Out of hours nothing is due.
	village.set_hour(12.0)
	check(BlessRound.due(village, -1).is_empty(), "nothing is due at noon")
	village.set_hour(8.4)
	check(not BlessRound.due(village, -1).is_empty(), "the round is due in the morning")
	check(BlessRound.due(village, village.day).is_empty(), "and not twice on one day")
	# Set out: stand somewhere free and let the round run.
	elsbeth.at_home = false
	elsbeth.visible = true
	elsbeth._start("work", 1.0)
	elsbeth._blessed_day = -1
	var said := []
	var hear := func(who: String, text: String, _pos: Vector3) -> void:
		if who == elsbeth.display_name:
			said.append(text)
	Events.bus().speech_said.connect(hear)
	var seen := {}
	var each := func() -> void:
		village.set_hour(8.6)
		if elsbeth._round != null and elsbeth._round.site() != null:
			seen[elsbeth._round.site().kind] = true
	elsbeth._next_task()
	check(elsbeth._task == "bless" or elsbeth._task == "walk", "she sets out on the round: %s" % elsbeth._task)
	_run(village, 420.0, each)
	check(seen.has(BlessRound.KIND_TEMPLE) and seen.has(BlessRound.KIND_SMITHY), "she went to the temple and on to the smithy")
	for kind in [BlessRound.KIND_TEMPLE, BlessRound.KIND_GATE, BlessRound.KIND_FOUNTAIN, BlessRound.KIND_SMITHY]:
		check(said.has(Lang.t(BlessRound.SAYS[kind])), "she said the blessing of the " + kind)
	var glows := village.find_children("BlessFx*", "", true, false).size()
	check(glows > 0, "the light of a blessing was cast")
	check(elsbeth._blessed_day == village.day, "the day's round is marked done")
	check(elsbeth._round == null, "the round is over")
	Events.bus().speech_said.disconnect(hear)
	# Fritz frozen: she finds him and thaws him.
	if fritz != null:
		fritz._start("frozen", 600.0)
		fritz._freeze()
		check(fritz.is_frozen(), "Fritz stands frozen")
		village.fritz_thawed_day = -1
		var spot := BlessRound.thaw_site(village)
		check(spot != null, "a frozen Fritz is a place on her way")
		elsbeth._round = null
		elsbeth._start("work", 1.0)
		village.set_hour(10.0)
		elsbeth._bless_out()
		check(elsbeth._task == "bless", "she goes to thaw Fritz")
		_run(village, 90.0, func(): village.set_hour(10.0))
		check(village.fritz_thawed_day == village.day, "the spell thaws Fritz for the day")
		check(not fritz.is_frozen(), "Fritz is free of the ice")
		check(not FrozenFritz.wants(village, false), "he does not freeze again that day")
