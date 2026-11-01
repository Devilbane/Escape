extends SceneTree
## Headless test for the bounty board on the village square: it stands in
## the village with a mark over it, shows the same hunts all day and fresh
## ones the next morning, hunts are taken on, counted and paid once, hunts
## not done by dawn expire, finished ones can still be handed in, and the
## board's state is kept in the saved game.
## Run with: godot --headless -s tests/bounties.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Bounty test"


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
	game.delete_save(game.save_path(HERO))
	if failures == 0:
		print("PASS: bounties")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _board() -> Dictionary:
	for s in game.level.stations:
		if s.kind == "aushang":
			return s
	return {}


## A hunt from today's board that wants this kind, or "".
func _posted_for(kind: String) -> String:
	for id in game.bounties.posted:
		if kind in Bounties.POOL[id].targets:
			return id
	return ""


func _test() -> void:
	# Every hunt is complete and has its English texts.
	for id in Bounties.POOL:
		var b: Dictionary = Bounties.POOL[id]
		check(b.count > 0 and b.gold > 0 and not b.targets.is_empty(), "%s has a count, a bounty and targets" % id)
		for kind in b.targets:
			check(Enemy.KINDS.has(kind), "%s: %s is a real enemy" % [id, kind])
		for key in ["title", "goal"]:
			check(Lang.EN.has(b[key]), "%s: the %s has an English text" % [id, key])
	check(Lang.EN.has(Bounties.HOW_TO), "the explanation has an English text")

	# The same day always shows the same hunts; the days do not all look alike.
	check(Bounties.pick(3) == Bounties.pick(3), "a day's hunts are always the same")
	check(Bounties.pick(3).size() == Bounties.POSTED, "the board shows %d hunts" % Bounties.POSTED)
	var differ := false
	for d in range(1, 8):
		if Bounties.pick(d) != Bounties.pick(0):
			differ = true
	check(differ, "the hunts change from day to day")

	# Dawn is passed going forward, also over midnight.
	check(game._dawn_between(4.9, 5.1), "4:54 to 5:06 passes dawn")
	check(not game._dawn_between(5.1, 23.0), "the day itself does not pass dawn")
	check(game._dawn_between(23.0, 7.0), "a night's sleep passes dawn")
	check(not game._dawn_between(6.0, 7.0), "a nap after dawn does not")

	# A new hero in the village: the board stands on the square.
	game.hero_name = HERO
	game.coins = 0
	game.day = 0
	game.escaped = true
	game.bounties.clear()
	game.bounties.refresh(0)
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")
	var board := _board()
	check(not board.is_empty(), "the bounty board stands in the village")
	check(game.level.station_at(board.pos) == board, "running into the board finds it")
	game.refresh_quest_marks()
	check(game.level.board_mark() == "!", "the board shows a ! while hunts are open")

	# Standing at the board, the hint line says what running into it does.
	game.state = game.State.PLAYING
	game.player.global_position = board.pos + Vector3(0, 0, 1.6)
	game._process(0.016)
	check(game._prompt.text == Lang.t("Dagegenlaufen, um den Aushang zu lesen"), "the hint line names the board, not <null>: %s" % game._prompt.text)
	check(Lang.EN.has("Dagegenlaufen, um den Aushang zu lesen"), "the board's hint has an English text")

	# Reading the board opens its window and explains it once.
	game._use_station(board)
	check(game.menus.current == "aushang", "running into the board opens it")
	check(game.lore.has(Bounties.HOW_TO), "the board is explained in the compendium")
	game.menus.close()

	# Take on a hunt and finish it.
	var id: String = game.bounties.posted[0]
	var hunt: Dictionary = Bounties.POOL[id]
	check(game.bounties.take(id), "a posted hunt can be taken on")
	check(not game.bounties.take(id), "the same hunt cannot be taken twice")
	check(not game.bounties.take("nonsense"), "an unknown hunt cannot be taken")
	game.bounties.on_kill("nobody")
	check(game.bounties.progress(id) == "0 / %d" % hunt.count, "other kinds do not count")
	for i in hunt.count - 1:
		game.bounties.on_kill(hunt.targets[0])
	check(not game.bounties.is_ready(id), "one short is not done")
	check(game.bounties.claim(id) == 0, "nothing is paid before the hunt is done")
	game.bounties.on_kill(hunt.targets[0])
	game.bounties.on_kill(hunt.targets[0])
	check(game.bounties.progress(id) == "%d / %d" % [hunt.count, hunt.count], "kills stop counting once done")
	game.refresh_quest_marks()
	check(game.level.board_mark() == "?", "the board shows a ? when a bounty waits")
	game.menus.open("aushang")
	game.menus._claim_bounty(id)
	game.menus.close()
	check(game.coins == hunt.gold, "the bounty is paid: %d gold" % hunt.gold)
	game.menus._claim_bounty(id)
	check(game.coins == hunt.gold, "the bounty is paid only once")
	check(not game.bounties.take(id), "a paid notice cannot be taken again today")

	# A hunt finished in time is paid after dawn; an unfinished one expires.
	var late: String = game.bounties.posted[1]
	var lazy: String = game.bounties.posted[2]
	game.bounties.take(late)
	game.bounties.take(lazy)
	for i in Bounties.POOL[late].count:
		game.bounties.taken[late] += 1
	game.day_hour = 4.99
	game.state = game.State.PLAYING
	game._tick_clock(1.0)
	check(game.day == 1, "the morning starts a new day")
	check(game.bounties.day == 1 and game.bounties.posted == Bounties.pick(1), "fresh hunts on the board")
	check(not game.bounties.is_taken(lazy), "the unfinished hunt expired")
	check(game.bounties.is_ready(late), "the finished hunt is still waiting")
	check(late in game.bounties.board_entries(), "the board still shows the finished hunt")
	check(game.bounties.claim(late) == Bounties.POOL[late].gold, "yesterday's finished hunt is paid")
	check(not late in game.bounties.board_entries() or late in game.bounties.posted, "and leaves the board")

	# The board is kept in the saved game.
	var open: String = game.bounties.posted[0]
	if game.bounties.is_open(open):
		game.bounties.take(open)
		game.bounties.on_kill(Bounties.POOL[open].targets[0])
	check(game.save_game(), "the game is saved")
	var saved: Dictionary = game.bounties.for_save()
	game.bounties.clear()
	game.day = 0
	game._apply_save(game._read_save(game.save_path(HERO)))
	check(game.day == 1, "the day is kept")
	check(game.bounties.for_save() == saved, "the board comes back as it was")

	# Saved games from before the board load fine.
	var data: Dictionary = game._read_save(game.save_path(HERO))
	data.erase("bounties")
	data.erase("day")
	game._apply_save(data)
	check(game.day == 0 and game.bounties.posted == Bounties.pick(0) and game.bounties.taken.is_empty(), "an older saved game starts with fresh notices")
	game.bounties.load_from({"day": 2, "posted": ["woelfe", "nonsense"], "taken": {"woelfe": 1, "nonsense": 3}, "paid": "broken"})
	check(game.bounties.posted == ["woelfe"] and game.bounties.taken.keys() == ["woelfe"], "broken or unknown entries are left out")

