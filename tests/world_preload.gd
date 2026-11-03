extends SceneTree
## Headless test for getting the village ready behind the title screen
## (WorldPreload): a copy of the village is built far below the dungeon, with
## a sneaking copy of the hero and samples of rain, blood and the like, drawn
## a few materials per frame in clear air and in fog behind a dark title
## backdrop, and thrown away again, keeping its materials and model scenes.
## The real hero keeps their plain look, and fog and backdrop are as before. The game itself is not touched: its level,
## its saved state and its scene tree are as before, and nothing of the copy
## is left. Headless it does nothing unless asked (no shaders to build).
## Run with: godot --headless -s tests/world_preload.gd

var failures := 0
var game: Node
var frames := 0
var preload_node: WorldPreload
var level_before: Node
var met_before := {}
var builds_before := {}
var batches := 0
var fog_before := false
var foggy_frames := 0
var dark_while := true
var dungeon_hidden_in_fog := true


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		check(root.find_child("WorldPreload", true, false) == null, "headless, nothing is got ready by itself")
		level_before = game.level
		met_before = game.met.duplicate(true)
		builds_before = game.builds.duplicate(true)
		fog_before = game._env.fog_enabled
		preload_node = WorldPreload.start(game, true)
		return false
	if frames < 3:
		return false
	if is_instance_valid(preload_node) and preload_node._holder:
		dark_while = dark_while and game._fade.color.a > 0.99
		if game._env.fog_enabled:
			foggy_frames += 1
			dungeon_hidden_in_fog = dungeon_hidden_in_fog and not game.level.visible
		var shown := 0
		for g in preload_node._geometry(preload_node._holder, []):
			if g.visible:
				shown += 1
		if preload_node._next > 0:
			batches += 1
			check(shown > 0, "every batch shows something")
	if not WorldPreload.done and frames < 600:
		return false
	_finish()
	return true


func _finish() -> void:
	check(WorldPreload.done, "the village is ready")
	check(batches > 1, "it is drawn in several batches, one per frame (%d)" % batches)
	var materials := 0
	var scenes := 0
	for k in WorldPreload.KEPT:
		if k is Material:
			materials += 1
		elif k is String and WorldPreload.KEPT[k] is PackedScene:
			scenes += 1
	check(materials > 10, "the village's materials are kept (%d)" % materials)
	check(scenes > 0, "the villagers' and animals' models are kept (%d)" % scenes)
	check(game.level == level_before, "the game's level is still the one it was")
	check(not (game.level is Outdoor), "the game is still in the dungeon")
	check(game.met == met_before, "whom the hero met is untouched")
	check(game.builds == builds_before, "what the hero built is untouched")
	check(root.find_child("VillageCopy", true, false) == null, "the copy is gone")
	check(root.find_children("*", "SubViewport", true, false).filter(func(v): return v.get_parent() is WorldPreload).is_empty(), "the hidden view is gone")
	check(dark_while, "the title's backdrop is fully dark while the copy is drawn")
	check(is_equal_approx(game._fade.color.a, WorldPreload.BACKDROP), "the title's backdrop is back to normal afterwards")
	check(foggy_frames > 0, "the copy is also drawn in fog (%d frames)" % foggy_frames)
	check(game._env.fog_enabled == fog_before, "the fog is as it was afterwards")
	check(dungeon_hidden_in_fog, "the dungeon is left out of the frames with fog")
	check(game.level.visible, "the dungeon is shown again afterwards")
	check(root.find_children("*", "Outdoor", true, false).is_empty(), "no copy of the village is left")
	check(Engine.time_scale == 1.0, "time runs normally")
	var faded := 0
	for mesh: MeshInstance3D in game.player._model.find_children("*", "MeshInstance3D", true, false):
		var mats: Array = [mesh.material_override]
		for i in mesh.get_surface_override_material_count():
			mats.append(mesh.get_surface_override_material(i))
		for m in mats:
			if m is ShaderMaterial and (m as ShaderMaterial).shader in [Player.GHOST_SHADER, HairLook.FADE_SHADER, Player.TINT_FADE_SHADER]:
				faded += 1
	check(faded == 0, "the real hero is not see-through (%d faded parts)" % faded)
	var ghosts := 0
	for k in WorldPreload.KEPT:
		if k is ShaderMaterial and (k as ShaderMaterial).shader == Player.GHOST_SHADER:
			ghosts += 1
	check(ghosts > 0, "the sneaking look's materials were drawn and kept (%d)" % ghosts)
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: world preload (%d materials, %d scenes, %d batches)" % [materials, scenes, batches])
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
