extends SceneTree
## Pictures of the graveyard's secrets (see BellGrave and GraveSpirit): the safety coffin with its bell on the post
## close up and from the graveyard, the bell swinging after the ring, Archy Stanton's grave beside the unknown one
## and the spirit that rises from it at midnight.
## SHOTS=<folder> saves the pictures.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/grave_secrets_shots.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var _cam: Camera3D
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
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


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _view(at: Vector3, offset: Vector3, look_at_offset := Vector3(0, 0.9, 0), fov := 50.0) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		root.add_child(_cam)
		_cam.make_current()
	_cam.fov = fov
	_cam.global_position = at + offset
	_cam.look_at(at + look_at_offset)


func _hide_hud() -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game._fade.color = Color(0, 0, 0, 0)


func _run() -> void:
	game._title.visible = false
	game.hero_name = "Grave secrets shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var lvl: Outdoor = game.level
	var coffin := BellGrave.graves_of(lvl.level_name)
	var duo := GraveSpirit.graves_of(lvl.level_name)
	var grave := lvl.cell_to_world(coffin.grave)
	var hero: Player = game.player
	game.day_hour = 12.0
	hero.global_position = lvl.cell_to_world(Vector2i(12, 12))
	hero.reset_physics_interpolation()
	await _wait(40)
	_hide_hud()
	# The bell on its post, close up and from the graveyard.
	_view(grave + Vector3(-0.1, 1.9, 0.9), Vector3(0.9, 0.1, 2.2), Vector3(0, 0, 0), 38.0)
	await _wait(5)
	await _shot("bell_close")
	_view(grave + Vector3(-0.1, 1.4, 0.9), Vector3(0.0, 0.5, 3.6), Vector3(0, 0, 0), 45.0)
	await _wait(5)
	await _shot("bell_post")
	_view(grave, Vector3(4.5, 3.0, 8.0), Vector3(0, 1.0, 0.5))
	await _wait(5)
	await _shot("bell_grave_wide")
	# The ring: the bell swings.
	var bell: BellGrave = lvl.bell_grave
	bell.tick(0.1, lvl.cell_to_world(coffin.centre), 22.0)
	check(bell.rang(), "the bell rings when the hero is by the middle")
	_view(grave + Vector3(-0.1, 1.9, 0.9), Vector3(0.9, 0.1, 2.2), Vector3(0, 0, 0), 38.0)
	await _wait(14)
	await _shot("bell_swinging")
	# Archy Stanton's grave and the unknown one beside it, and the spirit at midnight.
	var mid := lvl.cell_to_world(duo.unknown)
	_view(lvl.cell_to_world(duo.archy).lerp(mid, 0.5), Vector3(0, 3.0, 7.5), Vector3(0, 0.7, 0), 50.0)
	await _wait(5)
	await _shot("archy_and_unknown")
	var night := 0
	while not Moon.is_full(night):
		night += 1
	game.day = night
	game.day_hour = 0.0
	hero.global_position = mid + Vector3(0.0, 0.0, 2.0)
	hero.reset_physics_interpolation()
	await _wait(40)
	_hide_hud()
	var spirit: GraveSpirit = lvl.grave_spirit
	for i in 60:
		spirit.tick(0.1, hero.global_position, 0.0)
	await _wait(10)
	check(spirit.is_out(), "the spirit rises at midnight")
	# The hero steps back out of the picture (still near enough for the spirit to stay).
	hero.global_position = mid + Vector3(9.0, 0.0, 9.0)
	hero.reset_physics_interpolation()
	for i in 20:
		spirit.tick(0.1, hero.global_position, 0.0)
	_view(mid + Vector3(0.95, 0.0, 0.5), Vector3(-0.9, 1.4, 4.4), Vector3(0, 1.1, 0), 45.0)
	await _wait(8)
	await _shot("spirit")
	_view(mid, Vector3(3.5, 3.0, 8.0), Vector3(0, 1.0, 0.3), 50.0)
	await _wait(5)
	await _shot("spirit_wide")
	game.delete_save(game.save_path())
	print("PASS: grave secrets shots" if failures == 0 else "FAILED: " + str(failures))
	quit(1 if failures > 0 else 0)
