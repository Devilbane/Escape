extends SceneTree
## Headless test: the armoured guardian has 20 times a skeleton's life, so a
## normal blow wears it down without killing it, while a stab in the back still
## kills it in one blow, whatever its life.
## Run with: godot --headless -s tests/guardian_life.gd

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
	if frames < 5:
		return false
	_test()
	if failures == 0:
		print("PASS: guardian life")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _guardian() -> Enemy:
	var e := Enemy.new()
	e.kind = "waechter"
	e.level = game.level
	game.level.add_child(e)
	game.level.enemies.append(e)
	e.global_position = game.player.global_position + Vector3(0, 0, 2)
	return e


func _test() -> void:
	check(Enemy.KINDS.waechter.hp == 20, "the guardian's base life is 20")
	var normal := _guardian()
	var from: Vector3 = normal.global_position + Vector3(0, 0, 2)
	var full := normal.hp
	check(full >= 20, "the guardian starts with at least 20 life: %d" % full)
	normal.take_hit(3, from)
	check(not normal.dead and normal.hp < full, "a normal blow hurts it without killing it: %d of %d" % [normal.hp, full])
	var kills := 0
	while not normal.dead and kills < 100:
		normal.take_hit(3, from)
		kills += 1
	check(normal.dead, "normal blows can wear it down in the end")
	var stabbed := _guardian()
	check(stabbed.hp >= 20, "a second guardian has the full life")
	stabbed.take_hit(1, from, "backstab")
	check(stabbed.dead, "a stab in the back kills it in one blow, whatever its life")
