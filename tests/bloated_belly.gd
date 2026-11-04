extends SceneTree
## Headless test for drinking too much at the village fountain (see
## BloatedBelly): ten quick sips are fine, the eleventh swells the belly,
## slows the hero to BloatedBelly.SLOW for three minutes and shows an icon
## with a countdown under the life bar. Nothing cures it but time, slow sips
## do not add up, and the dungeon's fountains never do it.
## Run with: godot --headless --fixed-fps 60 -s tests/bloated_belly.gd

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
		await physics_frame


func _fountain() -> Dictionary:
	for s in game.level.stations:
		if s.kind == "brunnen":
			return s
	return {}


func _bloated() -> bool:
	return game.player.ailments.has(BloatedBelly.KIND)


func _test() -> void:
	# The counter: quick sips add up, the eleventh is too much; a pause starts again.
	var counter := BloatedBelly.new()
	var t := 0.0
	var tripped := false
	for i in BloatedBelly.SIPS:
		tripped = counter.sip(t) or tripped
		t += 1.0
	check(not tripped and counter.count == BloatedBelly.SIPS, "ten quick sips are still fine (%d)" % counter.count)
	check(counter.sip(t), "the eleventh quick sip is too much")
	check(counter.count == 0, "after that the count starts again")
	var slow := BloatedBelly.new()
	tripped = false
	for i in 30:
		tripped = slow.sip(i * (BloatedBelly.SIP_GAP + 0.5)) or tripped
	check(not tripped, "slow sips never add up")
	check(counter.still_drinking(t + 0.1) and not counter.still_drinking(t + BloatedBelly.SIP_TIME + 0.01),
			"a new sip waits until the last one is drunk")
	check(BloatedBelly.countdown(180.0) == "3m" and BloatedBelly.countdown(61.0) == "2m" and BloatedBelly.countdown(45.2) == "46" and BloatedBelly.countdown(0.0) == "0",
			"the icon's countdown reads 3m, 2m, 46, 0 (%s %s %s)" % [BloatedBelly.countdown(180.0), BloatedBelly.countdown(61.0), BloatedBelly.countdown(45.2)])

	game.hero_name = "Belly test"
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait()
	var p: Player = game.player
	var fountain := _fountain()
	check(game.level.outdoor and not fountain.is_empty(), "the village has its fountain")
	if fountain.is_empty():
		_finish()
		return
	var normal_speed := p.base_speed
	var plain_body: Mesh = (p._model.find_child("Rogue_Body", true, false) as MeshInstance3D).mesh
	game.belly_sips = BloatedBelly.new()
	for i in BloatedBelly.SIPS:
		game._drink(fountain)
	check(not _bloated(), "ten sips at the village fountain are fine")
	game._drink(fountain)
	check(_bloated(), "the eleventh sip swells the belly")
	check(is_equal_approx(p.ailments.get(BloatedBelly.KIND, 0.0), BloatedBelly.TIME), "for three minutes")
	check(is_equal_approx(p.base_speed, normal_speed * BloatedBelly.SLOW), "the hero is much slower (%.2f of %.2f)" % [p.base_speed, normal_speed])
	check(p.base_speed > 0.0, "but can still move")
	var body := p._model.find_child("Rogue_Body", true, false) as MeshInstance3D
	check(BloatedBelly.is_swollen(p._model) and body.mesh != plain_body, "the belly shows on the hero")
	check(body.mesh.get_aabb().end.z > plain_body.get_aabb().end.z + 0.1, "it sticks out in front (%.2f vs %.2f)" % [body.mesh.get_aabb().end.z, plain_body.get_aabb().end.z])
	check(not game._hero_fast(), "the slowness is not mistaken for a boon")

	# The icon under the life bar, with the time left.
	game._update_status_icons()
	var icon: StatusIcon = null
	for c in game._status_row.get_children():
		if c.kind == BloatedBelly.KIND:
			icon = c
	check(icon != null, "an icon shows under the life bar")
	if icon:
		check(icon.value == "3m", "it counts down from 3m (%s)" % icon.value)
		check(icon.tooltip_text.contains("3:00"), "its explanation tells the time left (%s)" % icon.tooltip_text)
		check(Lang.EN.has("Zu viel Wasser getrunken: Dein Bauch ist prall und du bist viel langsamer. Noch %s, dann geht es von selbst vorbei."), "the explanation has English")
		p.ailments[BloatedBelly.KIND] = 42.0
		game._update_status_icons()
		var same: StatusIcon = null
		for c in game._status_row.get_children():
			if c.kind == BloatedBelly.KIND:
				same = c
		check(same == icon, "a ticking countdown keeps the same icon (so its tooltip stays)")
		check(icon.value == "42" and icon.tooltip_text.contains("0:42"), "and shows the new time (%s)" % icon.value)
		p.ailments[BloatedBelly.KIND] = BloatedBelly.TIME

	# Nothing cures it: not more water, not a cure for everything else.
	p.ailments["gift"] = 5.0
	game._drink(fountain)
	check(_bloated() and not p.ailments.has("gift"), "the fountain cures poison but not the belly")
	check(not p.cure(), "with only the belly left there is nothing to cure")
	check(_bloated(), "and the belly stays")
	# A new set of gear keeps the belly on the hero.
	p.refresh_stats()
	check(BloatedBelly.is_swollen(p._model), "dressing again keeps the belly")
	for l in BloatedBelly.LINES:
		check(Lang.EN.has(l), "the hero's line has English: %s" % l)

	# Time makes it go down again.
	p.ailments[BloatedBelly.KIND] = 0.05
	await _wait(10)
	check(not _bloated(), "after the time it wears off")
	check(is_equal_approx(p.base_speed, normal_speed), "the speed comes back (%.2f)" % p.base_speed)
	check(not BloatedBelly.is_swollen(p._model), "the belly goes down")
	await process_frame
	var left := false
	for c in game._status_row.get_children():
		left = left or c.kind == BloatedBelly.KIND
	check(not left, "and its icon is gone")

	# A fountain in the dungeon never does it.
	game.load_level(4, false)
	game.state = game.State.PLAYING
	await _wait()
	fountain = _fountain()
	check(not fountain.is_empty(), "the refuge has a fountain")
	game.belly_sips = BloatedBelly.new()
	for i in BloatedBelly.SIPS * 2:
		game._drink(fountain)
	check(not _bloated(), "the dungeon's fountain never swells the belly")
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: bloated belly")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
