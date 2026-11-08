extends SceneTree
## Headless test for the slime's health bar and level (see SlimeBar): a calm
## slime shows nothing, a hunting or hurt one near the hero shows a bar whose
## fill follows its life, with its level beside it; a bigger slime has a wider
## bar, but not as much wider as it is bigger; a far one stays hidden.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_bar.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: slime bar" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _spawn(at: Vector3, custom := {}, kind := "schleim") -> Enemy:
	var lvl: Level = game.level
	var e := Enemy.new()
	e.kind = kind
	e.level = lvl
	e.custom = custom
	lvl.add_child(e)
	e.global_position = at
	lvl.enemies.append(e)
	return e


func _bar(e: Enemy) -> SlimeBar:
	for c in e.get_children():
		if c is SlimeBar:
			return c
	return null


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	game.hero_name = "Slime bar test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var hero: Player = game.level.player
	var near := _spawn(hero.global_position + Vector3(4, 0, 0), {"hp": 40, "damage": 1})
	near.set_physics_process(false)
	var far := _spawn(hero.global_position + Vector3(80, 0, 0), {"hp": 40, "damage": 1})
	far.set_physics_process(false)
	var bar := _bar(near)
	check(bar != null, "a slime has a bar")
	if bar == null:
		_finish()
		return true
	check(not bar.wanted(), "an untouched, calm slime shows no bar")
	near.hp = near.max_hp() / 2
	check(bar.wanted(), "a hurt slime near the hero shows its bar")
	bar._process(1.0)
	check(bar.visible, "the bar is shown")
	check(absf(bar._fill.scale.x - 0.5) < 0.05, "the fill follows its life (%s)" % bar._fill.scale.x)
	check(bar._label.text == Lang.t("Stufe %d") % near.rated_level, "the level stands beside it (%s)" % bar._label.text)
	far.hp = 1
	check(not _bar(far).wanted(), "a far slime stays hidden")
	near.hp = near.max_hp()
	check(not bar.wanted(), "a healed, calm slime hides its bar again")
	var small := _spawn(hero.global_position + Vector3(0, 0, 4), {"kept_level": 2})
	var big := _spawn(hero.global_position + Vector3(0, 0, -4), {"kept_level": 18})
	var ws := _bar(small)._width
	var wb := _bar(big)._width
	check(wb > ws, "a bigger slime has a wider bar (%s, %s)" % [ws, wb])
	check(wb / ws < float(big._stats.size) / float(small._stats.size), "but not as much wider as it is bigger")
	check(wb <= SlimeBar.WIDTH_TOP, "and never over the cap")
	var tough := _spawn(hero.global_position + Vector3(-4, 0, 0), {"hp": 150}, "halsabschneider")
	tough.set_physics_process(false)
	var weak := _spawn(hero.global_position + Vector3(-4, 0, 4), {"hp": 60}, "halsabschneider")
	weak.set_physics_process(false)
	var named := _spawn(hero.global_position + Vector3(-4, 0, -4), {"hp": 150, "title": "Grimm"}, "halsabschneider")
	named.set_physics_process(false)
	check(_bar(tough) != null, "a monster over 100 life has a bar")
	check(_bar(weak) == null, "a monster of 100 life or less has none")
	if _bar(tough) != null and _bar(named) != null:
		tough.hp = 75
		var tb := _bar(tough)
		tb._process(1.0)
		check(absf(tb._fill.scale.x - 0.5) < 0.05, "its fill follows its life (%s)" % tb._fill.scale.x)
		check(tb._label.text == Lang.t("Stufe %d") % tough.rated_level, "its level stands beside it")
		var tag_y := 0.0
		for c in named.get_children():
			if c is Label3D:
				tag_y = c.position.y
		check(tag_y > _bar(named).position.y + 0.2 or tag_y >= named.tall + SlimeBar.HEAD_GAP + 0.3, "a name stays above the bar (%s)" % tag_y)
	_finish()
	return true
