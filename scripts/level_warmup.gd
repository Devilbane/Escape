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
## Tested by tests/level_warmup.gd.

## Large enough that no camera ever culls the object (see also Fog).
const MARGIN := 16384.0
const KEY := &"warmup_margin"

static var _waiting: Array[GeometryInstance3D] = []
## The number of drawn frames when the warm-up began, or -1 without one.
static var _drawn_at := -1
## The process frame it began in.
static var _frame_at := 0


## Called once the level is built and in the tree.
static func begin(root: Node) -> void:
	finish()
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
		finish()


static func finish() -> void:
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
