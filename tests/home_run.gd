extends SceneTree
## Headless test for the way home (see HomeRun): the home button below the
## menu handle shows only once the hero has a house and a way home leads from
## where they stand, and its slot keeps the rail still when it comes and goes.
## A press sends the hero running home by the path finding: across the
## village to their own front door and in, and from a building of the village
## out of its way out first. A step of the player's own, a jump or a hit calls
## the run off; it does not set out while a foe is after the hero.
## Run with: godot --headless --fixed-fps 60 -s tests/home_run.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

const HERO := "Home run test"
## The most frames a run home may take (a minute and a half of play at 60 fps).
const MAX_FRAMES := 5400

var failures := 0
var game: Node
var frames := 0
var started := false
var mine := 0
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	if shots != "":
		Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	if mine > 0 and Homes.owner_of(mine) == HERO:
		Homes.release(mine)
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: home run")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await _wait(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


## Loads the village (or another level) and plays on.
func _load(index: int) -> void:
	game.load_level(index, false)
	game.state = game.State.PLAYING
	await _wait(3)


## The way home leads through the narrow neck by the village gate, where the woodcutter works:
## nobody stands in the way here (bumping into a villager would stop to talk, not run).
func _clear_the_way() -> void:
	var villagers = game.level.get("villagers")
	if villagers == null:
		return
	for v in villagers:
		if is_instance_valid(v):
			v.collision_layer = 0


## Waits until the hero is home, or the run ends, or time runs out.
func _wait_home() -> void:
	for i in MAX_FRAMES:
		await process_frame
		_clear_the_way()
		if game.level.is_home or (not game.home_run.active and game.state == game.State.PLAYING):
			break
	# Through the door: let the fade finish.
	await _wait(60)


func _rail_rects() -> Array:
	var out := []
	for b in game._quick_buttons.values():
		out.append(b.get_global_rect())
	out.append(game._drawer_handle.get_global_rect())
	return out


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	Homes.reload()
	for n in range(1, 40):
		if Homes.owner_of(n) == HERO:
			Homes.release(n)
	game.hero_name = HERO
	game.escaped = true
	game.home_claimed = false
	game.home_given = false
	var button: Button = game._home_button
	check(button != null, "there is a home button")

	# No home yet: no button, and X says why.
	await _load(game._outdoor_index())
	check(game.level is Outdoor, "the village is loaded")
	check(not button.visible, "without a home the button is hidden")
	check(game.home_run.start() != "", "without a home there is no way home")
	var before := _rail_rects()

	# The elder gives a house: the button shows, the rail stays where it was.
	mine = Homes.first_free(game.level.town_houses.size())
	check(mine > 0, "an empty house is free for the test")
	if mine == 0:
		_finish()
		return
	check(Homes.claim(HERO, mine), "the hero gets a house")
	await _wait(2)
	check(button.visible, "with a home the button shows")
	var after := _rail_rects()
	for i in before.size():
		check(before[i].is_equal_approx(after[i]), "the rail does not move when the home button shows (%d)" % i)
	var r := button.get_global_rect()
	var handle: Rect2 = game._drawer_handle.get_global_rect()
	var w: float = game._hud.get_viewport().get_visible_rect().size.x
	check(r.size.x >= 44.0 and r.size.y >= 44.0, "the home button is at least 44 x 44")
	check(r.size.is_equal_approx(game.QUICK_SIZE), "the home button is as big as the window icons")
	check(absf(r.end.x - w) < 1.0, "the home button touches the right edge")
	check(absf(r.position.x - handle.position.x) < 0.5, "the home button lines up with the handle")
	check(absf(r.position.y - handle.end.y - game.QUICK_HANDLE_GAP) < 0.5, "a wider gap sets the home button apart from the handle")
	check(button.tooltip_text.ends_with("(Taste X)") or button.tooltip_text.ends_with("(key X)"), "the tooltip names the key: " + button.tooltip_text)
	var keys: Array = game.menus.SHORTCUTS.map(func(s): return s[0])
	check(keys.has("Nach Hause laufen"), "the key is in the list of shortcuts")

	# From the village square home.
	# From where the hero comes out of the dungeon, on the graveyard.
	game.home_action()
	await _wait(2)
	check(game.home_run.active, "the button sends the hero home")
	check(button.button_pressed, "the button stays pressed on the way")
	check(not game.player.path.is_empty(), "the hero has a way to walk")
	await _wait(40)
	check(game.player.sprinting or game.player.winded, "the hero runs home")
	await _shot("home_run_on_the_way")
	await _wait_home()
	check(game.level.is_home, "the hero ran into their house")
	check(game.level.is_home and game.level.house_number == mine, "it is the hero's own house (%d)" % game.level.house_number)
	check(not game.home_run.active, "home, the run is over")
	check(not button.visible, "at home the button is hidden")

	# Out again: a step of the player's own calls the run off.
	await _load(game._outdoor_index())
	game.home_action()
	await _wait(10)
	check(game.home_run.active, "the hero sets out again")
	Input.action_press("ui_left")
	await _wait(2)
	Input.action_release("ui_left")
	check(not game.home_run.active, "a step of the player's own stops the run")
	check(not button.button_pressed, "the button is raised again")

	# A jump calls it off as well, and so does a hit.
	game.home_action()
	await _wait(5)
	game.player.jump()
	await _wait(2)
	check(not game.home_run.active, "a jump stops the run")
	await _wait(60)
	game.home_action()
	await _wait(5)
	check(game.home_run.active, "and once more on the way")
	game.player.hurt.emit(1)
	await _wait(2)
	check(not game.home_run.active, "a hit stops the run")
	check(game._message.text == Lang.t("Gefahr! Du bleibst stehen."), "and says why: " + game._message.text)
	# A second press of the button stops as well.
	game.home_action()
	await _wait(3)
	game.home_action()
	await _wait(2)
	check(not game.home_run.active, "a second press stops the run")

	# A foe after the hero: the run does not set out.
	var foe: Enemy = null
	for e in game.level.enemies:
		if is_instance_valid(e) and not e.dead and not e.is_friend():
			foe = e
			break
	if foe != null:
		var keep: Vector3 = foe.global_position
		foe.global_position = game.player.global_position + Vector3(4, 0, 0)
		foe.alert(game.player.global_position)
		check(game.home_run.danger(), "a foe on the hero's heels is danger")
		check(game.home_run.start() != "", "the run does not set out while a foe is after the hero")
		check(not game.home_run.active, "and the hero stays put")
		foe.global_position = keep
		foe.dead = true
		check(not game.home_run.danger(), "a slain foe is no danger")

	# Down in the vault cellar: out of its way out first, then home.
	await _load(game.interiors["b"])
	check(game.level.building == "b", "down in the vault cellar")
	check(button.visible, "the button shows in a building of the village")
	game.home_action()
	await _wait(2)
	check(game.home_run.active, "the hero sets out from the cellar")
	await _wait_home()
	check(game.level.is_home and game.level.house_number == mine, "from the cellar the hero ran all the way home")

	# The dungeon of the escape has no way home.
	await _load(0)
	check(not button.visible, "in the dungeon the button is hidden")
	check(game.home_run.start() != "", "in the dungeon there is no way home")
	_finish()
