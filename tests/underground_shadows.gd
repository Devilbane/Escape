extends SceneTree
## Headless test for UndergroundShadows: buried rooms far from the hero stop casting shadows and
## cast them again when the hero comes near.
## Run with: godot --headless -s tests/underground_shadows.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		game.load_level(10)
		game.state = game.State.PLAYING
		return false
	if frames < 30:
		return false
	_test()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: underground shadows")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	var us := UndergroundShadows.new()
	us.tick(game.level, game.player.global_position, UndergroundShadows.COLLECT_AFTER + 1.0)
	var pieces := us.counts().x
	check(pieces > 500, "the village's buried rooms are collected (%d pieces)" % pieces)
	# The hero far above every buried room: all of them are off.
	var far := Vector3(-5000, 0, -5000)
	us.update(far)
	check(us.counts().y == pieces, "far from everything all %d pieces are off (%d)" % [pieces, us.counts().y])
	# At the mine: the pieces round it cast again, the rest stay off.
	var mine: Vector3 = LostMine.floor_at(LostMine.cells().keys()[0])
	us.update(mine)
	var off := us.counts().y
	check(off < pieces, "near the mine some pieces cast shadows again (%d of %d off)" % [off, pieces])
	check(off > 0, "pieces beyond the range stay off (%d of %d off)" % [off, pieces])
	# The flag really is on the node: find a piece within range and one beyond it.
	var on := 0
	var gone := 0
	for g: GeometryInstance3D in game.level.find_children("*", "GeometryInstance3D", true, false):
		if g.global_position.y > UndergroundShadows.BURIED_Y:
			continue
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			gone += 1
		else:
			on += 1
	check(gone > 0 and on > 0, "buried nodes have both settings (%d on, %d off)" % [on, gone])
	# Back far away and near again: nothing is lost.
	us.update(far)
	us.update(mine)
	check(us.counts().y == off, "the same pieces are off after a round trip")
