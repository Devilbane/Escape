extends SceneTree
## Headless test for the hero's name over the head: a new game shows the
## chosen name there in the townsfolk's name-tag look, a loaded game shows the
## saved name, and the tag stays well above the life bar under the feet.
## Run with: godot --headless -s tests/hero_name_tag.gd
## With SHOTS=<folder> and a display it also saves a screenshot there.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
const HERO := "Name tag test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
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


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## Waits until the title or loading fade is over and the hero is playing.
func _wait_playing() -> void:
	for i in 300:
		if game.state == game.State.PLAYING:
			break
		await process_frame
	await _wait(6)


func _run() -> void:
	var p: Player = game.player
	check(p.name_tag != null and p.name_tag.get_parent() == p, "the hero carries a name tag")

	game.new_game()
	game._name_edit.text = HERO
	game._start_new_game()
	await _wait_playing()
	check(p.name_tag.text == HERO and p.name_tag.visible, "the new hero's name stands over the head")

	# The same look as the dungeon folk's and townsfolk's name tags.
	var tag := p.name_tag
	check(tag.font_size == 30 and tag.billboard == BaseMaterial3D.BILLBOARD_ENABLED and tag.no_depth_test, "it looks like the other name tags and always faces the camera")
	check(tag.position.y > p.tall, "it floats above the head")

	# On screen it is well above the life bar, which hangs under the feet.
	var cam: Camera3D = game.camera
	var tag_y := cam.unproject_position(tag.global_position).y
	check(game._hp_bar.visible, "the life bar shows")
	check(tag_y + 20.0 < game._hp_bar.position.y, "the name and the life bar do not meet")

	# A loaded game brings its own name.
	game.save_game()
	game.hero_name = "Someone else"
	check(tag.text == "Someone else", "a new name shows at once")
	game.state = game.State.TITLE
	game.continue_game(game.save_path())
	await _wait_playing()
	check(tag.text == HERO, "a loaded game shows the saved hero's name")

	if shots != "":
		await _wait(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join("hero_name_tag.png"))

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: hero name tag")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
