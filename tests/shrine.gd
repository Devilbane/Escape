extends SceneTree
## Headless test for the dungeon shrines: the panel offers +4 life, +1 power
## and +3 % speed, and each gift adds exactly that to the hero.
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
	for gift in ["+4 Leben", "+1 Kampfkraft", "+3% Tempo"]:
		check(texts.contains(Lang.t(gift)), "the shrine offers %s (%s)" % [gift, texts])

	# Life: the most and the current life both grow by four.
	var max_before: int = p.max_hp
	p.hp = p.max_hp
	game._choose_gift(0)
	check(p.max_hp == max_before + 4, "+4 life raises the most life by 4 (%d -> %d)" % [max_before, p.max_hp])
	check(p.hp == p.max_hp, "+4 life fills the new life too (%d / %d)" % [p.hp, p.max_hp])
	check(game._shrine.is_empty() and not game._shrine_panel.visible, "the panel closes after a gift")

	# Power: one more.
	shrine.used = false
	game._open_shrine(shrine)
	var power_before: int = p.power
	game._choose_gift(1)
	check(p.power == power_before + 1, "+1 power raises power by 1 (%d -> %d)" % [power_before, p.power])

	# Speed: three percent of the base speed on top.
	shrine.used = false
	game._open_shrine(shrine)
	var gift_before: float = p.gift_speed
	var speed_before: float = p.base_speed
	game._choose_gift(2)
	check(is_equal_approx(p.gift_speed - gift_before, 0.03), "+3 %% speed adds 0.03 (%.3f)" % (p.gift_speed - gift_before))
	check(p.base_speed > speed_before, "+3 %% speed makes the hero faster (%.3f -> %.3f)" % [speed_before, p.base_speed])
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: shrine gifts")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
