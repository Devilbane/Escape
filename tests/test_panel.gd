extends SceneTree
## Headless test for the testing panel (see TestPanel): it is closed at first, opens, keeps one
## fixed size whichever group shows, its buttons change the hour and the season, travel to the
## places, and switch godmode.
## Run with: godot --headless --fixed-fps 60 -s tests/test_panel.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _find(node: Node, type_name: String) -> Node:
	if node.get_script() != null and String(node.get_script().get_global_name()) == type_name:
		return node
	for c in node.get_children():
		var f := _find(c, type_name)
		if f != null:
			return f
	return null


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	for i in 10:
		await process_frame
	var panel: TestPanel = game._test_panel
	check(panel.visible, "the panel's tab shows while playing")
	check(not panel.open, "the box is closed at first")
	panel.toggle()
	await process_frame
	check(panel.open, "the tab opens the box")
	var size_before := panel.get_combined_minimum_size()
	for page in panel._pages:
		for p in panel._pages:
			p.visible = p == page
		await process_frame
		check(panel.get_combined_minimum_size() == size_before, "switching groups keeps the box's size")
	# Time of day and season.
	panel.picked.emit("time", 23.0)
	check(is_equal_approx(game.day_hour, 23.0), "the night button sets the hour")
	panel.picked.emit("time", 12.0)
	check(is_equal_approx(game.day_hour, 12.0), "the noon button sets the hour")
	for s in [Weather.WINTER, Weather.AUTUMN, Weather.SPRING, Weather.SUMMER]:
		panel.picked.emit("season", s)
		check(Weather.season(game.season_day()) == s, "the %s button sets the season" % s)
	# Godmode.
	panel.picked.emit("god", null)
	check(game.player.godmode and panel.god_button.button_pressed, "godmode on, the button looks pressed")
	check(Godmode.SPEED_FACTOR == 5.0, "godmode runs five times as fast")
	panel.picked.emit("god", null)
	check(not game.player.godmode and not panel.god_button.button_pressed, "godmode off again")
	# The climbing wall workshop opens from the hero page and its wall is there to edit.
	panel.picked.emit("wall", null)
	for i in 10:
		await process_frame
	var shop := _find(game, "WallWorkshop")
	check(shop != null and shop.map != null and shop.map.width >= 24, "the Kletterwand button opens the wall workshop")
	check(FileAccess.file_exists("res://walls/sample_three_paths.txt"), "the sample wall is shipped")
	if shop != null:
		shop.closed.emit()
		for i in 5:
			await process_frame
	# Every place exists.
	for place in TestPanel.PLACES:
		check(game.level_files.has(game.LEVEL_DIR + String(place[1])), "the level file %s exists" % place[1])
	check(LostMine.door_spot(0.0) != Vector3.ZERO, "the silver mine has a door spot")
	# Travelling: the starter dungeon and back to the farms.
	panel.picked.emit("travel", 2)
	for i in 120:
		await process_frame
	check(game.level_files[game.level_index].ends_with("01_die_zelle.txt"), "the start dungeon button loads the first level")
	panel.picked.emit("travel", 1)
	for i in 120:
		await process_frame
	check(game.level is Outdoor, "the farms button loads the open-air map")
	var farm: Vector3 = game.level.farm_spot(Vector3.ZERO)
	check(farm != Vector3.ZERO and game.player.global_position.distance_to(farm) < 3.0, "the hero stands in the fields")
	panel.picked.emit("travel", 5)
	for i in 120:
		await process_frame
	check(LostMine.door_spot(0.0).distance_to(Vector3(game.player.global_position.x, 0, game.player.global_position.z)) < 3.0, "the hero stands before the silver mine's hut")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures else 0)
