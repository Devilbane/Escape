extends SceneTree
## Headless test for the dungeon shrines: the panel offers +5 life, +1
## attribute point and +1 Konstitution, and each gift adds exactly that to the
## hero. Taking a gift
## hands control straight back: the hero can act and walk the very next frame.
## Run with: godot --headless --fixed-fps 60 -s tests/shrine.gd

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
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _button_texts(node: Node, out: Array) -> Array:
	if node is Button and node.visible:
		out.append(node.text)
	for child in node.get_children():
		_button_texts(child, out)
	return out


func _test() -> void:
	game.hero_name = "Shrine test"
	game.load_level(0, false)
	game.state = game.State.PLAYING
	await _wait()
	var p: Player = game.player
	var shrine := {}
	for s in game.level.stations:
		if s.kind == "schrein":
			shrine = s
	check(not shrine.is_empty(), "the first floor has a shrine")
	if shrine.is_empty():
		_finish()
		return

	game._open_shrine(shrine)
	await _wait()
	var texts := " ".join(_button_texts(game._shrine_panel, []))
	for gift in ["+5 Leben", "+1 Attributpunkt", "+1 Konstitution"]:
		check(texts.contains(Lang.t(gift)), "the shrine offers %s (%s)" % [gift, texts])

	# Life: the most and the current life both grow by five.
	var max_before: int = p.max_hp
	p.hp = p.max_hp
	game._choose_gift(0)
	check(p.max_hp == max_before + 5, "+5 life raises the most life by 5 (%d -> %d)" % [max_before, p.max_hp])
	check(p.hp == p.max_hp, "+5 life fills the new life too (%d / %d)" % [p.hp, p.max_hp])
	check(game._shrine.is_empty() and not game._shrine_panel.visible, "the panel closes after a gift")

	# No wait after the gift: the hero answers at once, and a step ends the
	# little thank-you animation instead of waiting for it.
	check(p.can_act(), "the hero can act right after taking a gift")
	check(p.flourishing(), "the gift still shows its thank-you animation")
	# A click on the floor next to the hero, as the player would make it.
	var start := p.global_position
	for step in [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]:
		p.walk_to(start + step)
		if not p.path.is_empty():
			break
	check(not p.path.is_empty(), "there is floor to walk to next to the shrine")
	for i in 3:
		await physics_frame
	check(p.global_position.distance_to(start) > 0.01, "the hero walks the frame after a gift (moved %.3f)" % p.global_position.distance_to(start))
	check(not p.flourishing(), "walking ends the thank-you animation")
	check(p._current_anim != "PickUp", "the walk shows instead of the thank-you animation (%s)" % p._current_anim)

	# An attribute point: one more free point, spent like a level point,
	# and gone with the run.
	shrine.used = false
	game._open_shrine(shrine)
	var free_before: int = p.free_points()
	game._choose_gift(1)
	check(p.free_points() == free_before + 1, "+1 attribute point gives a free point (%d -> %d)" % [free_before, p.free_points()])
	var strength_before: int = p.attribute("staerke")
	var level_points_before: Dictionary = p.level_points.duplicate()
	check(p.spend_point("staerke"), "the shrine's point can be spent")
	check(p.attribute("staerke") == strength_before + 1, "the point raises Stärke by 1 (%d -> %d)" % [strength_before, p.attribute("staerke")])
	check(p.level_points == level_points_before, "the shrine's point is not kept as a level point")
	check(p.free_points() == free_before, "the point is spent (%d free)" % p.free_points())

	# Konstitution: one more, and one more life, filled.
	shrine.used = false
	game._open_shrine(shrine)
	var con_before: int = p.attribute("konstitution")
	max_before = p.max_hp
	p.hp = p.max_hp
	game._choose_gift(2)
	check(p.attribute("konstitution") == con_before + 1, "+1 Konstitution raises it by 1 (%d -> %d)" % [con_before, p.attribute("konstitution")])
	check(p.max_hp == max_before + 1, "+1 Konstitution gives one more life (%d -> %d)" % [max_before, p.max_hp])
	check(p.hp == p.max_hp, "the new life comes filled (%d / %d)" % [p.hp, p.max_hp])

	# A new run takes the shrine's gifts away again.
	p.reset_gifts()
	check(p.gift_points == 0 and p.gift_spent.is_empty() and p.gift_constitution == 0, "a new run starts without shrine gifts")
	check(p.attribute("staerke") == strength_before, "the spent shrine point goes with the run")
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: shrine gifts")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
