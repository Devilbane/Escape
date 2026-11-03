class_name WorldPreload
extends Node
## Gets the village ready while the game starts up, so stepping out of the
## crypt door later is quick.
##
## Most of the wait at that door was not building the village but drawing it
## for the first time: every new material, light and mesh kind needs its
## shader built first, and on the web build that took long enough for the
## browser to call the page unresponsive. Loading the villagers' and animals'
## models from disk came on top. Rain and mist turn on the fog, and every
## shader needs a fog version of its own; the see-through look of a sneaking
## hero, blood, floating numbers and sparks need theirs the first time they
## show. Built only then, those froze the screen for seconds (sneaking in the
## rain).
##
## So, behind the title screen, a copy of the village is built far below the
## dungeon (nothing in it moves, thinks or makes a sound), together with a
## sneaking copy of the hero and a sample of those effects. Nothing of it is
## culled, so the game's own camera draws it, though it is far out of view
## and leaves no pixel on the screen: a few materials at a time, one batch
## per frame so no single frame takes long, once in clear air and once in
## fog. While that runs the title's backdrop is fully dark, so the frames
## with fog are not seen.
##
## The renderer builds each shader in two versions, depending on whether the
## frame goes through a buffer of its own first (when something on screen
## reads what is behind it, like the dungeon's fog of war or water) or
## straight to the screen (the village, mostly). The game's view in the
## dungeon only ever builds the first kind, so a small hidden view of the
## same world, which sees nothing but the copy (VIEW_LAYER), builds the
## second kind in the same frames.
##
## What the shaders and models need is then kept (materials and scenes, see
## KEPT) and the copy is thrown away. When the hero really steps out, the
## village is built as always, but its shaders are ready and its models are
## in memory.
##
## Headless (the tests) nothing is drawn, so it does nothing there unless a
## test asks for it with force. Tested by tests/world_preload.gd.

## Distinct materials drawn per frame: small enough that a frame stays short
## even where each new shader takes a while.
const BATCH := 6
## How far below everything the copy is built.
const DEPTH := -5000.0
## Fog as thick as in light rain (see Weather.LOOKS): any amount builds the
## same shaders.
const FOG_DENSITY := 0.006
## The title's backdrop while nothing is being got ready (see Game._show_title).
const BACKDROP := 0.55
## The render layer only the copy is on, besides the usual one.
const VIEW_LAYER := 1 << 19
## The hidden view's size: small, only the shaders matter, not the picture.
const VIEW_SIZE := Vector2i(256, 256)

## What stays in memory once the copy is gone: the materials (and so their
## shaders), and the scenes of the models by their paths. Kept for the whole
## session, also over a scene reload (a language change).
static var KEPT := {}
static var done := false

var _game: Node
var _force := false
var _holder: Node3D
var _view: SubViewport
var _level: Level
var _groups: Array = []
var _next := 0
var _step := 0
## Whether the batch on show is being drawn in fog (its second frame).
var _foggy := false
var _fog_was := {}
var _fog_on := false


static func start(game: Node, force := false) -> WorldPreload:
	var p := WorldPreload.new()
	p._game = game
	p._force = force
	p.name = "WorldPreload"
	game.add_child(p)
	return p


## True once the village is ready, or when there is nothing to get ready.
static func is_ready() -> bool:
	return done


func _ready() -> void:
	if done or (DisplayServer.get_name() == "headless" and not _force):
		queue_free()
		return
	# It also works while the game is paused (menus open on the title screen).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_backdrop(1.0)


## Runs after the game's own _process (a child comes after its parent), so
## the fog set here is the fog the frame is drawn with.
func _process(_delta: float) -> void:
	_step += 1
	# A few frames first, so the title screen is up before the work starts.
	if _step < 3:
		return
	if _level == null:
		if not _build():
			_finish()
		return
	if _next > 0 and not _foggy and _can_fog():
		# The batch just drawn once more, in fog.
		_foggy = true
		_fog(true)
	else:
		_foggy = false
		_fog(false)
		if _next >= _groups.size():
			_finish()
			return
		_show_next_batch()
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## Builds the copy of the village (one frame).
func _build() -> bool:
	var index: int = _game._outdoor_index()
	if index < 0:
		return false
	_holder = Node3D.new()
	_holder.name = "VillageCopy"
	_holder.position = Vector3(0, DEPTH, 0)
	add_child(_holder)
	var file: String = _game.level_files[index]
	var lvl := Outdoor.new()
	lvl.load_from_file(file)
	lvl.depth = index
	# A copy of everything the build reads, so the game's own state is never
	# touched by it.
	lvl.taken = {}
	lvl.built = (_game.builds.get(file.get_file(), []) as Array).duplicate(true)
	lvl.floor_items = []
	lvl.hero = _game.hero_name
	lvl.night = DayNight.is_night(_game.day_hour)
	lvl.interiors = _game.interiors.duplicate(true)
	lvl.house_given = _game.home_given
	lvl._entered_once = _game.home_claimed
	lvl.met = _game.met.duplicate(true)
	# Nothing in the copy moves, thinks or makes a sound.
	lvl.process_mode = Node.PROCESS_MODE_DISABLED
	_level = lvl
	_holder.add_child(lvl)
	lvl.build()
	# The hidden view of the same world, which sees only the copy.
	_view = SubViewport.new()
	_view.size = VIEW_SIZE
	_view.msaa_3d = _game.get_viewport().msaa_3d
	_view.world_3d = _game.get_viewport().find_world_3d()
	_view.audio_listener_enable_3d = false
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	var cam := Camera3D.new()
	cam.fov = _game.camera.fov
	cam.near = _game.camera.near
	cam.far = _game.camera.far
	cam.cull_mask = VIEW_LAYER
	_view.add_child(cam)
	cam.global_transform = _game.camera.global_transform
	cam.current = true
	_add_samples(lvl.cell_to_world(lvl.start_cell))
	_collect()
	return true


## Things that first show up in play and each need shaders of their own:
## the see-through hero while sneaking (Player.look_sneaky), rain and mist,
## a pool of blood, a floating number, sparks, a spray and a flame. Only a
## copy of each, beside the copy of the village.
func _add_samples(at: Vector3) -> void:
	var player: Player = _game.player
	if player and player._model:
		var ghost: Node3D = player._model.duplicate()
		# Its own materials, so fading it leaves the real hero as they are.
		for mesh: MeshInstance3D in ghost.find_children("*", "MeshInstance3D", true, false):
			if mesh.material_override:
				mesh.material_override = mesh.material_override.duplicate()
			for i in mesh.get_surface_override_material_count():
				var m := mesh.get_surface_override_material(i)
				if m:
					mesh.set_surface_override_material(i, m.duplicate())
		_level.add_child(ghost)
		ghost.global_position = at
		player.look_sneaky(ghost, 0.65)
	BloodStains.lay(_level, at + Vector3(1, 0.02, 0), 7)
	var number := DamageNumber._make("12", Color(1, 0.3, 0.2))
	_level.add_child(number)
	number.global_position = at + Vector3(0, 2, 0)
	# Particles move only where time runs: beside the frozen village.
	var moving := Node3D.new()
	_holder.add_child(moving)
	for p: CPUParticles3D in [Weather.make_rain(), Weather.make_mist(), Effects.make_sparkles(Color(1, 0.9, 0.4)),
			Effects.make_spray(Color(0.6, 0.05, 0.05)), Effects.make_flame()]:
		moving.add_child(p)
		p.global_position = at + Vector3(0, 1, 0)
		p.emitting = true


## Sorts everything drawable in the copy by its materials, so a batch is a
## few new materials (and all that wear them).
func _collect() -> void:
	var by_key := {}
	var order: Array = []
	for g in _geometry(_holder, []):
		g.extra_cull_margin = LevelWarmup.MARGIN
		# Litter and plants fade out with distance (visibility range); the
		# copy is far away, and they must be drawn all the same.
		g.visibility_range_begin = 0.0
		g.visibility_range_end = 0.0
		g.layers |= VIEW_LAYER
		g.visible = false
		var key := _material_key(g)
		if not by_key.has(key):
			by_key[key] = []
			order.append(key)
		by_key[key].append(g)
		_keep(g)
	for key in order:
		_groups.append(by_key[key])


## Hides the last batch and shows the next one on its own.
func _show_next_batch() -> void:
	for i in range(maxi(0, _next - BATCH), _next):
		for g in _groups[i]:
			if is_instance_valid(g):
				g.visible = false
	var end := mini(_next + BATCH, _groups.size())
	for i in range(_next, end):
		for g in _groups[i]:
			if is_instance_valid(g):
				g.visible = true
	_next = end


## Fog only while the backdrop hides the picture completely.
func _can_fog() -> bool:
	return _game._fade.color.a > 0.99


## The dungeon behind the title never has fog: it stays out of the fog
## frames, or all its shaders would be built once more, for nothing.
func _fog(on: bool) -> void:
	if on == _fog_on:
		return
	_fog_on = on
	var env: Environment = _game._env
	if on:
		_fog_was = {"on": env.fog_enabled, "density": env.fog_density}
		env.fog_enabled = true
		env.fog_density = FOG_DENSITY
	else:
		env.fog_enabled = _fog_was.on
		env.fog_density = _fog_was.density
	var dungeon: Node3D = _game.level
	if dungeon and dungeon != _level and is_instance_valid(dungeon):
		dungeon.visible = not on


func _finish() -> void:
	done = true
	_fog(false)
	if _holder:
		_holder.queue_free()
	if _view:
		_view.queue_free()
	_set_backdrop(BACKDROP)
	queue_free()


## The title's dark backdrop: fully dark while the work goes on. Only while
## the title is still up, and only if nobody else changed it meanwhile.
func _set_backdrop(alpha: float) -> void:
	var fade: ColorRect = _game._fade
	if fade == null or _game.state != _game.State.TITLE:
		return
	if alpha < 1.0 and fade.color.a < 0.99:
		return
	if alpha >= 1.0 and not is_equal_approx(fade.color.a, BACKDROP):
		return
	fade.color.a = alpha


func _geometry(node: Node, out: Array) -> Array:
	if node is GeometryInstance3D:
		out.append(node)
	for child in node.get_children():
		_geometry(child, out)
	return out


## What a drawable wears: its override, else the materials of its surfaces.
func _materials(g: GeometryInstance3D) -> Array:
	var out: Array = []
	if g.material_override:
		out.append(g.material_override)
	if g.material_overlay:
		out.append(g.material_overlay)
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s)
				if m:
					out.append(m)
	elif g is MultiMeshInstance3D:
		var mm := (g as MultiMeshInstance3D).multimesh
		if mm and mm.mesh:
			for s in mm.mesh.get_surface_count():
				var m := mm.mesh.surface_get_material(s)
				if m:
					out.append(m)
	elif g is GPUParticles3D or g is CPUParticles3D:
		var mesh: Mesh = g.draw_pass_1 if g is GPUParticles3D else g.mesh
		if mesh:
			for s in mesh.get_surface_count():
				var m := mesh.surface_get_material(s)
				if m:
					out.append(m)
	return out


func _material_key(g: GeometryInstance3D) -> String:
	var ids: Array = []
	for m in _materials(g):
		ids.append(m.get_instance_id())
	ids.sort()
	# A skinned model needs a shader of its own kind.
	var skinned := g.get_parent() is Skeleton3D
	return "%s|%s|%s" % [g.get_class(), skinned, ids]


## Keeps what the real village will need again: the materials, and the
## scene a model came from (so it is not read from disk a second time).
func _keep(g: GeometryInstance3D) -> void:
	for m in _materials(g):
		KEPT[m] = true
	var n: Node = g
	while n and n != _holder:
		if n.scene_file_path != "" and not KEPT.has(n.scene_file_path):
			KEPT[n.scene_file_path] = load(n.scene_file_path)
		n = n.get_parent()
