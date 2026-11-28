class_name PerfBenchmark
extends Node
## A developer's performance benchmark, started by a button of the test panel (see TestPanel): the hero is
## taken to three places of the village (the own house, the square by the mage tower, the open meadow), and
## at each one the seasons, the weather and the night are stepped through. For every condition it lets the
## world settle, measures the hero standing and then walking (CPU and GPU milliseconds the way the F1 plate
## shows them, see PerfOverlay) and takes a picture. Everything goes into user://benchmark/<time>/ (results.txt,
## results.csv and the pictures), so a build can be compared with the next one.

## Where the three places are: the map tile, or "" for the square by the mage tower.
const SPOTS := [
	{"name": "house", "cell": Vector2i(30, 26)},
	{"name": "square", "cell": Vector2i(-1, -1)},
	{"name": "meadow", "cell": Vector2i(77, 58)},
]
## The conditions at each place: name, season, weather, hour.
const CONDITIONS := [
	{"name": "autumn_clear_day", "season": Weather.AUTUMN, "weather": Weather.CLEAR, "hour": 12.0},
	{"name": "autumn_rain_day", "season": Weather.AUTUMN, "weather": Weather.RAIN, "hour": 12.0},
	{"name": "autumn_clear_night", "season": Weather.AUTUMN, "weather": Weather.CLEAR, "hour": 23.0},
	{"name": "winter_snow_day", "season": Weather.WINTER, "weather": Weather.SNOW, "hour": 9.0},
	{"name": "winter_snow_night", "season": Weather.WINTER, "weather": Weather.SNOW, "hour": 23.0},
	{"name": "summer_clear_day", "season": Weather.SUMMER, "weather": Weather.CLEAR, "hour": 12.0},
]
## Seconds to let the world settle after a change, to stand measured, and to walk measured.
const SETTLE := 3.0
const STAND := 4.0
const WALK := 4.0
## How far from the mage tower's door the square's spot lies (metres).
const TOWER_DISTANCE := 8.0

var running := false
var _game: Node
var _stop := false
var _folder := ""
var _lines: PackedStringArray = []
var _csv: PackedStringArray = []


## Starts (or, while it runs, stops) the benchmark of `game`.
func toggle(game: Node) -> void:
	if running:
		_stop = true
		return
	_game = game
	_run()


## Milliseconds of one frame the way PerfOverlay counts them: scripts and physics, drawing and setting up.
static func frame_cpu_ms(rid: RID) -> float:
	return (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0 \
			+ RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()


## Average, 95th percentile and highest of `values`.
static func summary(values: Array) -> Dictionary:
	if values.is_empty():
		return {"avg": 0.0, "p95": 0.0, "max": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for v: float in sorted:
		sum += v
	return {"avg": sum / sorted.size(), "p95": sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], "max": sorted[-1]}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_playing() -> void:
	while _game.state != _game.State.PLAYING:
		await get_tree().process_frame
	await _frames(5)


func _run() -> void:
	running = true
	_stop = false
	_lines = []
	_csv = ["spot,condition,phase,frames,fps,cpu_avg,cpu_p95,cpu_max,gpu_avg,gpu_p95,gpu_max"]
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	_folder = "user://benchmark/" + stamp
	DirAccess.make_dir_recursive_absolute(_folder)
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var game := _game
	var village: int = game._outdoor_index()
	var was := {"index": game.level_index, "cell": game.level.world_to_cell(game.player.global_position),
			"shift": game.season_shift, "hour": game.day_hour, "weather": game.weather, "god": game.player.godmode}
	game.player.godmode = true
	Events.tell(Lang.t("Leistungstest läuft. Ergebnisse in %s") % ProjectSettings.globalize_path(_folder), Color(0.75, 0.85, 1.0))
	_lines.append("Escape! benchmark %s, build %s, %s, %s" % [stamp, game.perf_overlay.session_version, RenderingServer.get_video_adapter_name(), OS.get_name()])
	_lines.append("%-8s %-20s %-6s %5s %6s | CPU avg   p95   max | GPU avg   p95   max" % ["spot", "condition", "phase", "fps", "frames"])
	for spot: Dictionary in SPOTS:
		if _stop:
			break
		await _go(spot, village)
		for cond: Dictionary in CONDITIONS:
			if _stop:
				break
			await _measure(spot, cond, rid)
	_finish(was, village)


## Takes the hero to a place of the village.
func _go(spot: Dictionary, village: int) -> void:
	var game := _game
	var cell: Vector2i = spot.cell
	if cell.x < 0:
		cell = _square_cell()
	game.teleport_to(village, false, "", cell)
	await _wait_playing()
	await _frames(30)


## A tile on the square next to the mage tower (the square's middle when the tower is not found).
func _square_cell() -> Vector2i:
	var level: Outdoor = _game.level
	var middle: Vector3 = level.spots.square[0]
	var tower := level.find_child("Hall_mage", true, false) as Node3D
	if tower == null:
		return level.world_to_cell(middle)
	var towards := (middle - tower.global_position)
	towards.y = 0.0
	var at := tower.global_position + towards.normalized() * TOWER_DISTANCE
	return level.world_to_cell(at)


func _measure(spot: Dictionary, cond: Dictionary, rid: RID) -> void:
	var game := _game
	game._season_command({"season": cond.season})
	game._sky_force({"weather": cond.weather, "hour": float(cond.hour), "winter": -1, "tour": "", "autumn": false})
	game.player.path.clear()
	await get_tree().create_timer(SETTLE).timeout
	for phase: String in ["stand", "walk"]:
		var cpu: Array = []
		var gpu: Array = []
		var t := 0.0
		var length := STAND if phase == "stand" else WALK
		var around: Vector3 = game.player.global_position
		while t < length and not _stop:
			await get_tree().process_frame
			var delta := get_process_delta_time()
			t += delta
			if phase == "walk":
				var angle := t * 0.9
				game.player.path.assign([around + Vector3(cos(angle), 0.0, sin(angle)) * 3.0])
			cpu.append(frame_cpu_ms(rid))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		game.player.path.clear()
		var c := summary(cpu)
		var g := summary(gpu)
		var fps := cpu.size() / maxf(t, 0.001)
		_lines.append("%-8s %-20s %-6s %5.0f %6d | %7.1f %5.1f %5.1f | %7.1f %5.1f %5.1f" % [spot.name, cond.name, phase, fps, cpu.size(), c.avg, c.p95, c.max, g.avg, g.p95, g.max])
		_csv.append("%s,%s,%s,%d,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [spot.name, cond.name, phase, cpu.size(), fps, c.avg, c.p95, c.max, g.avg, g.p95, g.max])
		if phase == "stand":
			var shot := get_viewport().get_texture().get_image() if DisplayServer.get_name() != "headless" else null
			if shot != null:
				shot.save_png("%s/%s_%s.png" % [_folder, spot.name, cond.name])
		_write()


func _write() -> void:
	for pair: Array in [["results.txt", _lines], ["results.csv", _csv]]:
		var f := FileAccess.open("%s/%s" % [_folder, pair[0]], FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(pair[1]) + "\n")


func _finish(was: Dictionary, village: int) -> void:
	var game := _game
	_write()
	game.player.godmode = bool(was.god)
	game.season_shift = int(was.shift)
	game._check_season()
	game._sky_force({"weather": String(was.weather), "hour": float(was.hour), "winter": -1, "tour": "", "autumn": false})
	game.teleport_to(int(was.index), false, "", was.cell)
	running = false
	Events.tell(Lang.t("Leistungstest beendet. Ergebnisse in %s") % ProjectSettings.globalize_path(_folder), Color(0.75, 0.85, 1.0))
