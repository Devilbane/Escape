extends SceneTree
## Headless test for the glowworm swarms of the night (see GlowwormSwarms):
## none by day or indoors, a few over the open land at night and more in the
## village, always over open ground, and put out again at dawn. They use no
## shader the other particles do not already need.
## Run with: godot --headless --fixed-fps 60 -s tests/glowworm_swarms.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _settle(lvl: Outdoor, hero: Player, hour: float, indoors := false, seconds := 20.0) -> void:
	for i in int(seconds * 4.0):
		lvl.glowworms.tick(0.25, hero.global_position, hour, indoors)


func _run() -> void:
	seed(7)
	game.load_level(game._outdoor_index(), false)
	await process_frame
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	var gw: GlowwormSwarms = lvl.glowworms
	check(gw != null, "the open air has glowworm swarms")
	if gw == null:
		_finish()
		return
	check(not GlowwormSwarms.out_at(12.0) and not GlowwormSwarms.out_at(18.0), "none by day or at dusk's start")
	check(GlowwormSwarms.out_at(22.0) and GlowwormSwarms.out_at(2.0), "out at night")
	check(not GlowwormSwarms.out_at(7.0), "gone by morning")
	check(GlowwormSwarms.swarms_for(true) > GlowwormSwarms.swarms_for(false), "more of them in the village")

	var village := Vector3.INF
	var wild := Vector3.INF
	for y in lvl.height:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if not lvl.is_open(c):
				continue
			if lvl._in_village(c) and village == Vector3.INF:
				village = lvl.cell_to_world(c)
			elif not lvl._in_village(c) and wild == Vector3.INF and lvl.cell_char(c) == ".":
				wild = lvl.cell_to_world(c)
	check(village != Vector3.INF, "the map has a village")

	hero.global_position = village
	_settle(lvl, hero, 12.0)
	check(gw.count() == 0, "no swarm by day")
	_settle(lvl, hero, 23.0)
	check(gw.count() == GlowwormSwarms.VILLAGE_SWARMS, "a village night has its swarms (%d)" % gw.count())
	for s in gw._swarms:
		var at: Vector3 = s.node.global_position
		check(gw._free(at), "a swarm hovers over open ground")
		check(at.y > 0.3 and at.y < 2.0, "at about head height (%.1f)" % at.y)
	_settle(lvl, hero, 23.0, true)
	check(gw.count() == 0, "none indoors")
	_settle(lvl, hero, 23.0)
	if wild != Vector3.INF:
		hero.global_position = wild
		_settle(lvl, hero, 23.0, false, 40.0)
		check(gw.count() <= GlowwormSwarms.WILD_SWARMS, "fewer outside the village (%d)" % gw.count())
		check(gw.count() >= 1, "some even out in the open (%d)" % gw.count())
	hero.global_position = village
	_settle(lvl, hero, 23.0, false, 10.0)
	_settle(lvl, hero, 9.0, false, 10.0)
	await process_frame
	check(gw.count() == 0, "put out at dawn")
	check(gw.get_child_count() == 0, "no leftover nodes (%d)" % gw.get_child_count())
	var swarm := GlowwormSwarms.make_swarm()
	var flame := Effects.make_flame()
	var a: StandardMaterial3D = swarm.mesh.material
	var b: StandardMaterial3D = flame.mesh.material
	check(a.shading_mode == b.shading_mode and a.blend_mode == b.blend_mode and a.billboard_mode == b.billboard_mode, "same material kind as the other glows")
	swarm.free()
	flame.free()
	game.delete_save(game.save_path())
	_finish()


func _finish() -> void:
	if failures == 0:
		print("PASS: glowworm swarms")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
