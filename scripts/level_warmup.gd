class_name LevelWarmup
## Hides the hitch at the start of a level.
##
## The renderer builds the shaders for a material, a light and a mesh kind
## the first time it draws them. On the web build every one of those takes
## a noticeable moment, and a fresh level brings many new ones at once: the
## first frame of a level took up to a few seconds, and more hitches
## followed while the hero walked and new things came into view. The whole
## lost time then landed in the next frame's delta, so the fade-in, the
## level's message and the hero's first steps jumped or seemed to hang.
##
## So, while the screen is still dark: for one frame nothing in the new
## level is culled (neither by the view nor by distance), and every shader it needs is built in that single frame.
## The next frame runs with time standing still (Engine.time_scale 0), so
## the long wait is swallowed instead of being played out all at once.
## Afterwards everything is culled as before.
##
## A level can ask for more such frames (`passes`, see WeatherWarmup): before each further frame
## one pass is run (it may switch on the haze of bad weather or show the rain), and its undo runs
## once that frame is drawn. Time stands still until the last one is drawn.
## Tested by tests/level_warmup.gd.

## Large enough that no camera ever culls the object (see also Fog).
const MARGIN := 16384.0
const KEY := &"warmup_margin"

static var _waiting: Array[GeometryInstance3D] = []
## The number of drawn frames when the warm-up began, or -1 without one.
static var _drawn_at := -1
## The process frame it began in.
static var _frame_at := 0
## The further warm-up frames still to come: each an Array [do, undo] of Callables.
static var _passes: Array = []
## The undo of the pass whose frame is being drawn.
static var _undo := Callable()


## Called once the level is built and in the tree. `passes` (each [do, undo]) adds one warm-up
## frame each, after the first.
static func begin(root: Node, passes: Array = []) -> void:
	finish()
	_passes = passes.duplicate()
	_collect(root)
	Engine.time_scale = 0.0
	_drawn_at = Engine.get_frames_drawn()
	_frame_at = Engine.get_process_frames()
	var tree := root.get_tree()
	if tree and not tree.process_frame.is_connected(_tick):
		tree.process_frame.connect(_tick)


## True while the warm-up frame is still to come or being paid for.
static func active() -> bool:
	return _drawn_at >= 0


## At the start of every frame (paused or not): once the warm-up frame has
## been drawn, culling and time go back to normal. The delta of this frame
## was already taken with time standing still. Where nothing is drawn (the
## headless tests, a minimised window) it ends a frame later all the same.
static func _tick() -> void:
	if _drawn_at < 0:
		return
	if Engine.get_frames_drawn() > _drawn_at or Engine.get_process_frames() > _frame_at + 1:
		_end_pass()
		if _passes.is_empty():
			finish()
			return
		var next: Array = _passes.pop_front()
		(next[0] as Callable).call()
		_undo = next[1]
		_drawn_at = Engine.get_frames_drawn()
		_frame_at = Engine.get_process_frames()


static func _end_pass() -> void:
	if _undo.is_valid():
		var undo := _undo
		_undo = Callable()
		undo.call()


static func finish() -> void:
	_end_pass()
	_passes.clear()
	for g in _waiting:
		if is_instance_valid(g) and g.has_meta(KEY):
			var kept: Array = g.get_meta(KEY)
			g.extra_cull_margin = kept[0]
			g.visibility_range_begin = kept[1]
			g.visibility_range_end = kept[2]
			g.remove_meta(KEY)
	_waiting.clear()
	if _drawn_at >= 0:
		_drawn_at = -1
		Engine.time_scale = 1.0
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.process_frame.is_connected(_tick):
		tree.process_frame.disconnect(_tick)


static func _collect(node: Node) -> void:
	if node is GeometryInstance3D and not node.has_meta(KEY):
		var g := node as GeometryInstance3D
		g.set_meta(KEY, [g.extra_cull_margin, g.visibility_range_begin, g.visibility_range_end])
		g.extra_cull_margin = MARGIN
		# Litter and plants that fade out with distance are drawn too.
		g.visibility_range_begin = 0.0
		g.visibility_range_end = 0.0
		_waiting.append(g)
	for child in node.get_children():
		_collect(child)
