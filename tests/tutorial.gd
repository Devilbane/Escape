extends SceneTree
## Headless test for the first steps in the cell (see Tutorial): one card at
## a time explains walking, running, the dagger, the knives, sneaking (and how
## to stop) and jumping, with a pause between the cards. A card goes when the
## hero did what it says or after a while; learned cards do not come back, a
## new game shows them all again, and a window pauses them. The card keeps one
## size for every step in both languages.
## Run with: godot --headless --fixed-fps 60 -s tests/tutorial.gd

var failures := 0
var game: Node
var frames := 0
var t: Tutorial
const HERO := "Tutorial test"


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
	game.delete_save(game.save_path())
	_test()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: tutorial")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


## Lets `seconds` of play pass for the tutorial, a tenth of a second at a time.
func _tick(seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		var d := minf(0.1, left)
		t.update(d)
		left -= d


## Enters the cell afresh, with no message on screen.
func _enter_cell() -> void:
	game.load_level(0, false)
	game.state = game.State.PLAYING
	game._message.modulate.a = 0.0
	game.player.set_sneaking(false)


## Lets the current card go once the hero did it, then waits out the pause.
func _finish_and_next() -> void:
	_tick(Tutorial.DONE_SHOW + 0.1)
	check(t.step == -1, "after \"Done!\" the card goes and a pause follows")
	_tick(Tutorial.GAP + 0.1)


func _test() -> void:
	t = game.tutorial
	game.hero_name = HERO
	game.hints_shown.clear()
	var tutorial_links := Events.bus().hero_acted.get_connections().filter(func(c): return c.callable == Callable(t, "on_hero_acted"))
	check(tutorial_links.size() == 1, "the tutorial listens to the hero's actions once")
	_check_card_size()

	_enter_cell()
	check(t.pending(), "a new hero has every card still to see")
	check(t.step == -1, "no card before the level's name has gone")
	game._message.modulate.a = 1.0
	_tick(3.0)
	check(t.step == -1, "no card while a message is on screen")
	game._message.modulate.a = 0.0
	_tick(Tutorial.START_DELAY + 0.1)

	# 1: walking.
	check(t.step == 0, "the first card is about walking: %d" % t.step)
	check(t.card.visible, "the card is on screen")
	check(t._title.text == Lang.t("Gehen"), "it is titled walking: %s" % t._title.text)
	check(t._counter.text == Lang.t("Erste Schritte %d / %d") % [1, Tutorial.STEPS.size()], "it counts the steps: %s" % t._counter.text)
	check(t._done_label.text == "", "it is not done yet")
	for i in 3:
		game.player.global_position += Vector3(1.0, 0, 0)
		_tick(1.0)
	check(t._done, "walking a few metres does it")
	check(t._done_label.text == Lang.t("Geschafft!"), "it says done")
	check(int(game.hints_shown.get("tut_move", 0)) == game.HINT_SHOWINGS, "walking is learned")
	_finish_and_next()

	# 2: running, which the hero leaves be: the card goes after a while.
	check(t.step == 1, "the second card is about running: %d" % t.step)
	check(t._title.text == Lang.t("Rennen"), "it is titled running")
	_tick(Tutorial.MAX_SHOW - 1.0)
	check(t.step == 1, "a card stays a good while")
	# Ticks one tenth at a time until the card goes, so the pause is
	# measured from that moment on.
	var waited := 0.0
	while t.step != -1 and waited < 2.0:
		t.update(0.1)
		waited += 0.1
	check(t.step == -1, "a card nobody acts on goes after a while")
	check(int(game.hints_shown.get("tut_run", 0)) == 1, "running was shown once, not learned")
	_tick(Tutorial.GAP - 0.3)
	check(t.step == -1, "there is a pause between cards")
	_tick(0.4)

	# 3: the dagger.
	check(t.step == 2, "the third card is about the dagger: %d" % t.step)
	Events.bus().hero_acted.emit("jump")
	_tick(Tutorial.MIN_SHOW + 0.1)
	check(not t._done, "another action does not count")
	Events.bus().hero_acted.emit("melee")
	_tick(0.1)
	check(t._done, "a strike does it")
	_finish_and_next()

	# 4: the knives.
	check(t.step == 3, "the fourth card is about throwing knives: %d" % t.step)
	Events.bus().hero_acted.emit("throw")
	_tick(0.5)
	check(not t._done, "a card shows a moment before it can go")
	_tick(Tutorial.MIN_SHOW)
	check(t._done, "a throw does it")
	_finish_and_next()

	# 5 and 6: sneaking, and how to stop.
	check(t.step == 4, "the fifth card is about sneaking: %d" % t.step)
	game.player.set_sneaking(true)
	_tick(Tutorial.MIN_SHOW + 0.1)
	check(t._done, "sneaking does it")
	_finish_and_next()
	check(t.step == 5, "the sixth card tells how to stop sneaking: %d" % t.step)
	check(t._text.text.contains("C"), "it names the key")
	_tick(Tutorial.MIN_SHOW + 0.1)
	check(not t._done, "still sneaking, it stays")
	game.player.set_sneaking(false)
	_tick(0.1)
	check(t._done, "walking normally again does it")
	_finish_and_next()

	# 7: jumping, the last card.
	check(t.step == 6, "the last card is about jumping: %d" % t.step)
	Events.bus().hero_acted.emit("jump")
	_tick(Tutorial.MIN_SHOW + 0.1)
	check(t._done, "a jump does it")
	_finish_and_next()
	check(t.step == -1 and t._visit_over, "after the last card the tutorial is over")
	check(game._message.text == Lang.t("Alle Tasten findest du im Kompendium (H)."), "the end points to the compendium: %s" % game._message.text)
	_tick(20.0)
	check(t.step == -1, "nothing more comes in this visit")

	# A later visit to the cell shows only the card not learned yet.
	_enter_cell()
	_tick(Tutorial.GAP + 0.1)
	check(t.step == 1, "back in the cell, only running shows again: %d" % t.step)
	_tick(Tutorial.MAX_SHOW + 0.1)
	check(int(game.hints_shown.get("tut_run", 0)) == game.HINT_SHOWINGS, "running was shown twice now")
	_tick(Tutorial.GAP + 0.1)
	check(t.step == -1 and not t.pending(), "every card has had its turn")
	_enter_cell()
	_tick(10.0)
	check(t.step == -1, "a third visit shows nothing")

	# Other levels have no tutorial.
	game.hints_shown.clear()
	check(t.pending(), "a new game shows the cards again")
	game.load_level(1, false)
	game.state = game.State.PLAYING
	game._message.modulate.a = 0.0
	_tick(10.0)
	check(t.step == -1, "the next level shows no cards")

	# A window pauses the card and hides it meanwhile.
	_enter_cell()
	_tick(Tutorial.GAP + 0.1)
	check(t.step == 0, "the cell shows the first card again: %d" % t.step)
	var clock: float = t._clock
	game.menus.open("inventar")
	check(game.menus.is_open(), "the inventory opens")
	_tick(Tutorial.MAX_SHOW + 1.0)
	check(t.step == 0 and is_equal_approx(t._clock, clock), "the card waits while a window is open")
	check(not t.card.visible, "the card hides behind a window")
	game.menus.close()
	_tick(0.1)
	check(t.card.visible, "the card is back once the window is closed")

	# Leaving the cell takes the card away.
	game.load_level(1, false)
	_tick(0.1)
	check(t.step == -1 and not t.card.visible, "leaving the cell takes the card away")


## Every step's title fits on one line and its text in the room the card
## keeps for it, in German and in English, so the card never changes size.
func _check_card_size() -> void:
	var font: Font = game.TEXT_FONT
	var width: float = t._text.custom_minimum_size.x
	var line := font.get_height(Tutorial.TEXT_SIZE)
	for s in Tutorial.STEPS:
		for title in [s.title, Lang.EN.get(s.title, "")]:
			check(title != "", "\"%s\" has an English title" % s.title)
			check(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x <= width, "\"%s\" fits on one line" % title)
		for text in [s.text, Lang.EN.get(s.text, "")]:
			check(text != "", "\"%s\" has an English text" % s.text)
			var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, Tutorial.TEXT_SIZE)
			var lines := roundi(size.y / line)
			check(lines <= Tutorial.TEXT_LINES, "\"%s\" fits in %d lines: %d" % [text, Tutorial.TEXT_LINES, lines])
	var counter := Lang.t("Erste Schritte %d / %d") % [7, 7]
	check(font.get_string_size(counter + "   " + Lang.t("Geschafft!"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= width, "the top line fits")
