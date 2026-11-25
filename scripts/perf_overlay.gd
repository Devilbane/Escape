class_name PerfOverlay
extends CanvasLayer
## A small bronze plate in the top right corner that shows how the game runs:
## frames per second, the time one frame takes on the processor (CPU) and on
## the graphics card (GPU), each with a little graph of the last seconds, and
## the round trip to the server (ping) while playing together. F1 shows and
## hides it (see Game._input).
##
## Godot cannot tell how busy the processor or the graphics card is as a
## whole (a load in per cent), so the graphs show what the game itself spends
## on each frame, in milliseconds. A dim line marks 16.7 ms, the budget of a
## frame at 60 frames per second; a curve above it means frames are dropped.
##
## It is a layer of its own above the HUD and the windows, never takes the
## pointer, and has one fixed size, so changing numbers never move it. It sits
## under the "Game saved" plate (SaveNotice) and above the pull-out menu's rail,
## so it covers neither.

const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
## Distance from the screen's right edge: the pull-out menu's rail (its quick
## window icons, 70 wide) and a gap of 12, and from its top: below the save
## notice's plate.
const EDGE := 70 + 12
const TOP := 68
const WIDTH := 236.0
const GRAPH := Vector2(204, 26)
const TEXT_SIZE := 20
const SMALL_SIZE := 18
## How often the numbers and graphs take a new value (seconds), and how many
## values a graph keeps: 60 values of a tenth of a second, the last 6 seconds.
const STEP := 0.1
const HISTORY := 60
## The graphs' scale: 0 to 33.3 ms (30 frames per second), wider when a frame
## takes longer; the dim line is the 60 fps budget.
const SCALE_MS := 1000.0 / 30.0
const BUDGET_MS := 1000.0 / 60.0
const CPU_COLOR := Color(0.4, 0.92, 0.4)
const GPU_COLOR := Color(0.55, 0.75, 1.0)
const TEXT_COLOR := Color(1.0, 0.82, 0.4)

## The round trip to the server in milliseconds, or -1 when not connected
## (set by the game, see Game._setup_perf_overlay).
var ping_source: Callable = func() -> int: return -1

var plate: PanelContainer
var fps_label: Label
var ping_label: Label
var cpu_label: Label
var gpu_label: Label
var cpu_graph: Graph
var gpu_graph: Graph
## The values the last update showed, for tests.
var fps := 0.0
var cpu_ms := 0.0
var gpu_ms := 0.0
## The averages over everything measured since the plate was shown (hide and show it to start over).
var cpu_avg_ms := 0.0
var gpu_avg_ms := 0.0
var ping_ms := -1

var _since := 0.0
var _frames := 0
var _cpu_sum := 0.0
var _gpu_sum := 0.0
var _total_frames := 0
var _cpu_total := 0.0
var _gpu_total := 0.0


## A strip that draws the last values as a line, over a dim line at the
## budget of a 60 fps frame.
class Graph:
	extends Control

	var color := Color.WHITE
	var values := PackedFloat32Array()

	func add(value: float) -> void:
		values.append(value)
		if values.size() > HISTORY:
			values.remove_at(0)
		queue_redraw()

	func top_ms() -> float:
		var top := SCALE_MS
		for v in values:
			top = maxf(top, v)
		return top

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		var top := top_ms()
		var budget_y := size.y * (1.0 - BUDGET_MS / top)
		draw_line(Vector2(0, budget_y), Vector2(size.x, budget_y), Color(1, 1, 1, 0.22), 1.0)
		if values.size() < 2:
			return
		var points := PackedVector2Array()
		var step := size.x / float(HISTORY - 1)
		var x0 := size.x - step * float(values.size() - 1)
		for i in values.size():
			points.append(Vector2(x0 + step * i, size.y * (1.0 - clampf(values[i] / top, 0.0, 1.0))))
		# A faint fill under the line, then the line itself.
		var fill := points.duplicate()
		fill.append(Vector2(points[points.size() - 1].x, size.y))
		fill.append(Vector2(points[0].x, size.y))
		draw_colored_polygon(fill, Color(color, 0.18))
		draw_polyline(points, color, 1.5, true)


func _ready() -> void:
	layer = 5
	# Keeps measuring while the world is paused (a window open).
	process_mode = Node.PROCESS_MODE_ALWAYS
	plate = PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.anchor_left = 1.0
	plate.anchor_right = 1.0
	plate.offset_left = -EDGE - WIDTH
	plate.offset_right = -EDGE
	plate.offset_top = TOP
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.custom_minimum_size.x = WIDTH
	# The save notice's frame: a bronze rim around the HUD's dark ground.
	var frame := UiKit.frame_style(Color(0.09, 0.066, 0.047, 0.88), UiKit.BRONZE, 3, 6)
	frame.content_margin_left = 14
	frame.content_margin_right = 14
	frame.content_margin_top = 8
	frame.content_margin_bottom = 10
	plate.add_theme_stylebox_override("panel", frame)
	add_child(plate)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	plate.add_child(column)
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_row)
	fps_label = _label(TEXT_SIZE, TEXT_COLOR)
	fps_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(fps_label)
	ping_label = _label(SMALL_SIZE, TEXT_COLOR)
	ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ping_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(ping_label)
	cpu_label = _label(SMALL_SIZE, CPU_COLOR)
	column.add_child(cpu_label)
	cpu_graph = _graph(CPU_COLOR)
	column.add_child(cpu_graph)
	gpu_label = _label(SMALL_SIZE, GPU_COLOR)
	column.add_child(gpu_label)
	gpu_graph = _graph(GPU_COLOR)
	column.add_child(gpu_graph)
	visible = false
	set_process(false)
	_show_values()


func _label(text_size: int, color: Color) -> Label:
	var l := UiKit.label(FONT, UiKit.sized(text_size), color)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _graph(color: Color) -> Graph:
	var g := Graph.new()
	g.color = color
	g.custom_minimum_size = GRAPH
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func toggle() -> void:
	set_shown(not visible)


func set_shown(on: bool) -> void:
	visible = on
	set_process(on)
	# The graphics card's time is only measured while the plate shows.
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, on)
	_since = 0.0
	_frames = 0
	_cpu_sum = 0.0
	_gpu_sum = 0.0
	_total_frames = 0
	_cpu_total = 0.0
	_gpu_total = 0.0
	cpu_avg_ms = 0.0
	gpu_avg_ms = 0.0
	if on:
		cpu_graph.values.clear()
		gpu_graph.values.clear()
		ping_ms = ping_source.call()
		_show_values()


func _process(delta: float) -> void:
	var rid := get_viewport().get_viewport_rid()
	_frames += 1
	_cpu_sum += (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0 \
			+ RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
	_gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_since += delta
	if _since < STEP:
		return
	fps = Engine.get_frames_per_second()
	cpu_ms = _cpu_sum / _frames
	gpu_ms = _gpu_sum / _frames
	_total_frames += _frames
	_cpu_total += _cpu_sum
	_gpu_total += _gpu_sum
	cpu_avg_ms = _cpu_total / _total_frames
	gpu_avg_ms = _gpu_total / _total_frames
	ping_ms = ping_source.call()
	cpu_graph.add(cpu_ms)
	gpu_graph.add(gpu_ms)
	_since = 0.0
	_frames = 0
	_cpu_sum = 0.0
	_gpu_sum = 0.0
	_show_values()


func _show_values() -> void:
	fps_label.text = "%d FPS" % roundi(fps)
	ping_label.text = (Lang.t("Ping %d ms") % ping_ms) if ping_ms >= 0 else Lang.t("Ping: getrennt")
	cpu_label.text = Lang.t("CPU %.1f ms, Ø %.1f") % [cpu_ms, cpu_avg_ms]
	gpu_label.text = Lang.t("GPU %.1f ms, Ø %.1f") % [gpu_ms, gpu_avg_ms]
