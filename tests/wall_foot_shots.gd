extends SceneTree
## Screenshots of the grass, flowers and mossy stones at the foot of the village's buildings
## (WallFoot), for each look and season: close views of the stretches of wall foot where most grows
## (picked once, from the first look, so every look is seen at the same places) and the game's own
## view over the first of them.
## Run with: SHOTS=<folder> [LOOKS=sparse,mossy] [SEASONS=summer,winter] godot -s tests/wall_foot_shots.gd
## (needs a display); without SHOTS it only builds the village and checks there is a fringe.

## How many places to look at, and how far apart they lie at least (metres).
const PLACES := 3
const APART := 25.0
## The close view: how far out from the wall and how high the camera stands (metres).
const CLOSE := Vector2(5.0, 3.0)
## The game's view: how far out the hero stands, and how far the camera is zoomed in (0 to 1).
const HERO_OUT := 3.5
const ZOOM := 0.75
## season: [day, snow on the ground]
const SEASONS := {
	"summer": [Weather.SPRING_DAYS + 2, 0.0],
	"autumn": [Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS + IvySeasons.TURN_DAYS - 1, 0.0],
	"winter": [Weather.YEAR_DAYS - Weather.WINTER_DAYS + 1, 1.0],
}

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
## The places to look at: [spot on the wall's foot, the way out from the wall].
var places: Array = []


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


func _list(env: String, all: Array) -> Array:
	var picked := OS.get_environment(env)
	return all if picked == "" else Array(picked.split(","))


## Every piece of the fringe (where it grows), from the batches' own record.
func _pieces(lvl: Outdoor) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for child in lvl.wall_foot.get_children():
		for xf: Transform3D in child.get_meta("grown")[0]:
			out.append(xf.origin)
	return out


## The PLACES stretches in the village where most grows, each with the way out from its building.
func _pick_places(lvl: Outdoor) -> void:
	var pieces := _pieces(lvl)
	var scored: Array = []
	for i in range(0, pieces.size(), 3):
		var p := pieces[i]
		# Among the village's buildings (not the graveyard's fence).
		if not lvl._in_village(lvl.world_to_cell(p)):
			continue
		var n := 0
		for q in pieces:
			if absf(q.x - p.x) < 3.0 and absf(q.z - p.z) < 3.0:
				n += 1
		scored.append([n, p])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	for s: Array in scored:
		var p: Vector3 = s[1]
		if places.any(func(pl): return (pl[0] as Vector3).distance_to(p) < APART):
			continue
		# The way out: away from the middle of the nearest building's outline.
		var best := INF
		var out := Vector3.BACK
		for outlines: Array in lvl._footprints.values():
			for outline: PackedVector2Array in outlines:
				var mid := Vector2.ZERO
				for q in outline:
					mid += q
				mid /= outline.size()
				var d := mid.distance_to(Vector2(p.x, p.z))
				if d < best:
					best = d
					out = Vector3(p.x - mid.x, 0, p.z - mid.y).normalized()
		# Only walls facing south, as the game's camera sees them.
		if out.z < 0.7:
			continue
		places.append([p, Vector3.BACK])
		if places.size() >= PLACES:
			break


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Ivy"
	await _wait(10)
	for look: String in _list("LOOKS", WallFoot.LOOKS.keys()):
		WallFoot.look = look
		Outdoor._dressed.clear()
		game.load_level(game._outdoor_index(), false)
		await _wait(30)
		var lvl: Outdoor = game.level
		if lvl.wall_foot == null or _pieces(lvl).is_empty():
			print("FAIL: no fringe for look %s" % look)
			quit(1)
			return
		print("look %s: %d pieces in %d batches" % [look, _pieces(lvl).size(), lvl.wall_foot.get_child_count()])
		if shots == "":
			continue
		if places.is_empty():
			_pick_places(lvl)
		for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
			layer.visible = false
		for season: String in _list("SEASONS", SEASONS.keys()):
			game.season_shift = int(SEASONS[season][0]) - Seasons.today()
			game.day_hour = 12.0
			game.snow_cover = SEASONS[season][1]
			game.set_weather(Weather.CLEAR, 100.0)
			game._weather_look = Weather.look(Weather.CLEAR)
			await _wait(10)
			for i in places.size():
				var at: Vector3 = places[i][0]
				var out: Vector3 = places[i][1]
				game.player.visible = false
				var cam := Camera3D.new()
				cam.fov = 55.0
				root.add_child(cam)
				cam.global_position = at + out * CLOSE.x + Vector3(0, CLOSE.y, 0) + out.cross(Vector3.UP) * 1.0
				cam.look_at(at - out * 0.5 + Vector3(0, 0.4, 0))
				cam.make_current()
				await _wait(20)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(shots.path_join("%s_%s_close%d.png" % [look, season, i + 1]))
				cam.queue_free()
			game.camera.make_current()
			game.player.visible = true
			game.player.global_position = (places[0][0] as Vector3) + (places[0][1] as Vector3) * HERO_OUT
			game.player.reset_physics_interpolation()
			game._zoom = ZOOM
			game._zoom_target = ZOOM
			await _wait(30)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(shots.path_join("%s_%s_game.png" % [look, season]))
	game.delete_save(game.save_path())
	print("PASS: wall foot shots")
	quit(0)
