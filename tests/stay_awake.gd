extends SceneTree
## Headless test for the bed's "stay awake" in the hero's town house: the
## button saves the game without logging out and opens the saved games, which
## say where it was saved. "Keep playing" closes the window and the hero can
## act and walk at once.
## Run with: godot --headless --fixed-fps 60 -s tests/stay_awake.gd

const HERO := "Stay awake test"

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

	# Every new text has its English.
	for text in ["Wach bleiben und speichern", "Spielstände", "Spiel gespeichert auf Platz %d.", "Weiterspielen"]:
		check(Lang.EN.has(text), "'%s' has English" % text)

	m.open("bett")
	await _wait()
	check(_find(m._box, "Button", Lang.t("Weiter wach bleiben")) == null, "the old 'stay awake' button is gone")
	var awake := _find(m._box, "Button", Lang.t("Wach bleiben und speichern")) as Button
	check(awake != null, "the bed offers to stay awake and save")
	if awake == null:
		_finish()
		return
	awake.pressed.emit()
	await _wait()
	check(m.current == "laden", "staying awake opens the saved games (%s)" % m.current)
	check(FileAccess.file_exists(game.save_path()), "staying awake saved the game")
	var info: Dictionary = game.save_info(game.save_path())
	check(info.get("name", "") == HERO and not info.has("away"), "the save is the hero's and does not log out")
	check(_find(m._box, "Label", Lang.t("Spielstände")) != null, "the window is titled as the saved games")
	check(_find(m._box, "Label", Lang.t("Spiel gespeichert auf Platz %d.") % game.save_slot) != null, "the window says where the game was saved")
	check(_find(m._box, "Label", Lang.t("Was du seitdem erlebt hast, geht verloren.")) == null, "no warning about lost progress right after saving")
	check(_find(m._box, "Button", Lang.t("Laden")) != null, "the saved game is listed with its load button")

	var carry_on := _find(m._box, "Button", Lang.t("Weiterspielen")) as Button
	check(carry_on != null, "the window has a button to keep playing")
	if carry_on == null:
		_finish()
		return
	carry_on.pressed.emit()
	await _wait()
	var p: Player = game.player
	check(m.current == "" and m.saved_now == "", "keep playing closes the window")
	check(game.state == game.State.PLAYING, "the game carries on")
	check(p.can_act(), "the hero can act right after the window closes")
	var start := p.global_position
	for step in [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)]:
		p.walk_to(start + step)
		if not p.path.is_empty():
			break
	check(not p.path.is_empty(), "there is floor to walk to beside the hero")
	for i in 5:
		await physics_frame
	check(p.global_position.distance_to(start) > 0.01, "the hero walks after the window closes")

	# Opened from the title or the pull-out menu, it is the plain load window again.
	m.open("laden")
	await _wait()
	check(_find(m._box, "Label", Lang.t("Spielstand laden")) != null, "the load window keeps its own title")
	check(_find(m._box, "Button", Lang.t("Abbrechen")) != null, "the load window keeps its cancel button")
	m.close()
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	if failures == 0:
		print("PASS: stay awake")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
