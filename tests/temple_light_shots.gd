extends SceneTree
## Screenshots of the village's temple glass light at night and in fog.
## Run with: SHOTS=<folder> godot -s tests/temple_light_shots.gd (needs a display); without SHOTS it only builds the village.

## name: [map letter of the door, camera offset from the front, look-at offset from the front]
const TARGETS := {
	"temple_side": ["s", Vector3(26, 9, 4), Vector3(0, 2, 1)],
	"temple_top": ["s", Vector3(22, 20, -2), Vector3(0, 0, -2)],
	"temple_front": ["s", Vector3(0, 7.5, 13), Vector3(0, 3.5, -3)],
}

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
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var hour := float(OS.get_environment("HOUR")) if OS.get_environment("HOUR") != "" else 22.0
	if OS.get_environment("FOG") != "":
		lvl.set_weather(Weather.FOG)
	game.day_hour = hour
	game._set_atmosphere(true)
	lvl.set_hour(hour)
	for name: String in TARGETS:
		var key: String = TARGETS[name][0]
		if shots == "" or not lvl.doors.has(key):
			continue
		var front: Vector3 = lvl.doors[key]
		game.player.global_position = front + Vector3(0, 0, 3)
		var cam := Camera3D.new()
		cam.fov = 55.0
		root.add_child(cam)
		cam.global_position = front + (TARGETS[name][1] as Vector3)
		cam.look_at(front + (TARGETS[name][2] as Vector3))
		cam.make_current()
		game.day_hour = hour
		await _wait(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
		cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: temple glass light shots")
	quit(0)
