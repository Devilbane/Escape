extends SceneTree
## Headless test for the bed's "Sleep till morning" in the hero's town house
## (see Game.rest_till_morning): the window offers it beside the old "sleep
## and log out" and "stay awake"; sleeping at night moves the one world clock
## to WAKE_HOUR of the next day (a new day, hours counted into world_hours,
## full life, the game saved, the hero up again by the bed), and sleeping
## in the evening of the same day gives the same morning, never a second day.
## Run with: godot --headless --fixed-fps 60 -s tests/sleep_till_morning.gd

const HERO := "Sleep till morning test"

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
	if frames == 5:
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _find(node: Node, type: String, text: String) -> Control:
	if node.is_class(type) and node.text == text:
		return node
	for child in node.get_children():
		var found := _find(child, type, text)
		if found != null:
			return found
	return null


func _settled() -> bool:
	return game.state == game.State.PLAYING and not game.player.frozen


## Sleeps through from `hour`, by pressing the bed's button, and waits for the hero to be up.
func _sleep_from(hour: float) -> void:
	var m: Menus = game.menus
	game.day_hour = hour
	game.player.hp = 1
	m.open("bett")
	await _wait()
	var button := _find(m._box, "Button", Lang.t("Bis zum Morgen schlafen")) as Button
	check(button != null, "the bed offers to sleep till morning")
	if button == null:
		return
	button.pressed.emit()
	await _wait()
	check(m.current == "", "the window closes")
	check(game.state == game.State.TRANSITION and game.player.frozen, "the hero lies down")
	var waited := 0.0
	while not _settled() and waited < 20.0:
		await process_frame
		waited += 1.0 / 60.0


func _test() -> void:
	var m: Menus = game.menus
	game.hero_name = HERO
	game.escaped = true
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	var house := 1
	while Homes.owner_of(house) != "":
		house += 1
	check(Homes.claim(HERO, house), "the hero moves into a town house")
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	game.state = game.State.PLAYING
	await _wait()
	check(game.level.is_home, "the hero is in their town house")
	game.delete_save(game.save_path())

	for text in ["Bis zum Morgen schlafen", "Ausgeruht! Ein neuer Morgen."]:
		check(Lang.EN.has(text), "'%s' has English" % text)

	# The old choices are still there.
	m.open("bett")
	await _wait()
	check(_find(m._box, "Button", Lang.t("Schlafen und ausloggen")) != null, "sleep and log out is still offered")
	check(_find(m._box, "Button", Lang.t("Wach bleiben und speichern")) != null, "stay awake is still offered")
	m.close()

	# A night: from 23:00 to 7:00 the next day.
	var day: int = game.day
	var hours: float = game.world_hours
	await _sleep_from(23.0)
	check(is_equal_approx(game.day_hour, DayNight.WAKE_HOUR), "the clock stands at the morning hour (%s)" % game.day_hour)
	check(game.day == day + 1, "a new day has begun (%d -> %d)" % [day, game.day])
	check(is_equal_approx(game.world_hours - hours, 8.0), "eight hours passed in the world (%s)" % (game.world_hours - hours))
	check(game.player.hp == game.player.max_hp, "the hero is fully rested")
	check(game.has_slot_save(), "the game is saved")
	check(not DayNight.is_night(game.day_hour), "it is no longer night")
	check(game.player.global_position.distance_to(game.level.bed_side) < 1.0, "the hero stands by the bed")

	# Past midnight, before dawn: still the same calendar night, one day counted.
	day = game.day
	hours = game.world_hours
	await _sleep_from(2.0)
	check(is_equal_approx(game.day_hour, DayNight.WAKE_HOUR) and game.day == day + 1, "from 2:00 the morning of the same calendar day is a new day for the world once")
	check(is_equal_approx(game.world_hours - hours, 5.0), "five hours passed (%s)" % (game.world_hours - hours))

	# By day it skips to the next morning, too.
	hours = game.world_hours
	await _sleep_from(12.0)
	check(is_equal_approx(game.day_hour, DayNight.WAKE_HOUR), "from noon the next morning comes")
	check(is_equal_approx(game.world_hours - hours, 19.0), "nineteen hours passed (%s)" % (game.world_hours - hours))
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	if failures == 0:
		print("PASS: sleep till morning")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
