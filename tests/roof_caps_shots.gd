extends SceneTree
## Screenshots of the cap shingles on the mage tower's hips and a village house's ridge (RoofCaps), in summer and winter.
## Run with: SHOTS=<folder> godot -s tests/roof_caps_shots.gd (needs a display); without SHOTS it only builds the village.

## name: [map letter of the door, camera offset from the front, look-at offset from the front]
const TARGETS := {
	"tower_roof": [Vector3(0, 9.0, 6.5), Vector3(0, 0.0, 0.0)],
	"tower_hip": [Vector3(-1.6, 2.2, 2.4), Vector3(0, 0.0, 0.0)],
	"tower_hip_far": [Vector3(-3.5, 4.5, 5.0), Vector3(0, 0.0, 0.0)],
	"house_ridge": [Vector3(0, 6.0, 8.5), Vector3(0, 0.0, 0.0)],
}
## season: [day, snow on the ground]
const SEASONS := {
	"summer": [Weather.SPRING_DAYS + 2, 0.0],
	"winter": [Weather.YEAR_DAYS - Weather.WINTER_DAYS + 1, 1.0],
}

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
var only := OS.get_environment("ONLY")


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
	for season: String in SEASONS:
		if OS.get_environment("SEASON") != "" and OS.get_environment("SEASON") != season:
			continue
		game.season_shift = int(SEASONS[season][0]) - Seasons.today()
		game.day_hour = 12.0
		game.snow_cover = SEASONS[season][1]
		game.set_weather(Weather.CLEAR, 100.0)
		game._weather_look = Weather.look(Weather.CLEAR)
		await _wait(10)
		var ts: Array = lvl.walk_in.buildings.filter(func(r): return r.kind == "mage")
		var tower: Node3D = ts[0].node
		var top := tower.global_transform * Vector3(0, float(ts[0].layout.deck) + MageTower.TOP_H + MageTower.PEAK * 0.45, 0)
		var shape: Dictionary = tower.get_meta("shape")
		var hw := (float(shape.w) + VillageHouse.JETTY * 2.0) * 0.5 + MageTower.OVERHANG
		var hd := (float(shape.d) + VillageHouse.JETTY * 2.0) * 0.5 + MageTower.OVERHANG
		var y0 := float(ts[0].layout.deck) + MageTower.TOP_H
		var hip := tower.global_transform * Vector3(hw * 0.5, y0 + MageTower.PEAK * 0.5, hd * 0.5)
		var door: Vector3 = lvl.walk_in.door_points(ts[0])[0]
		var house_front: Vector3 = lvl.doors["h"] + Vector3(0, 6.0, -4.0) if lvl.doors.has("h") else top
		for name: String in TARGETS:
			if shots == "" or (only != "" and not only.contains(name)):
				continue
			var look: Vector3 = (hip if name.begins_with("tower_hip") else top) if name.begins_with("tower") else house_front
			game.player.global_position = door + Vector3(0, 0, 7.0)
			game.player.reset_physics_interpolation()
			var cam := Camera3D.new()
			cam.fov = 50.0
			root.add_child(cam)
			cam.global_position = look + (TARGETS[name][0] as Vector3)
			cam.look_at(look + (TARGETS[name][1] as Vector3))
			cam.make_current()
			await _wait(80)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(shots.path_join("%s_%s.png" % [name, season]))
			cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: roof caps shots")
	quit(0)
