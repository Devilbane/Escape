extends SceneTree
## Screenshot of the compendium's Places page with the monster levels.
## Run with: SHOTS=<folder> godot -s tests/places_shots.gd (needs a display).

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Ivy"
	await _wait(10)
	for i in [3, 5, 10, 18]:
		game.learn("#%d" % i)
	game.menus.compendium_page = "orte"
	game.menus.open("kompendium")
	await _wait(20)
	if shots != "":
		root.get_viewport().get_texture().get_image().save_png(shots.path_join("places.png"))
	quit()
