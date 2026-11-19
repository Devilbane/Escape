extends SceneTree
## Headless test: villagers piled onto one spot come apart and walk on (see Villager._keep_apart):
## - several villagers standing exactly on each other, all facing the same way, separate;
## - several sent to the very same target do not stay in a clump, and each one gets there;
## - a clump that is walked on to different goals ends up spread out.
## Run with: godot --headless --fixed-fps 60 -s tests/villager_crowd.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


## The smallest distance between any two of the group, flat.
func _closest(group: Array) -> float:
	var best := INF
	for i in group.size():
		for j in range(i + 1, group.size()):
			var a: Vector3 = group[i].global_position
			var b: Vector3 = group[j].global_position
			best = minf(best, Vector2(a.x - b.x, a.z - b.z).length())
	return best


func _walkers(lvl: Outdoor, n: int) -> Array:
	var out := []
	for v: Villager in lvl.villagers:
		if out.size() >= n:
			break
		if not v.keeps_spot() and not v.at_home and v._info.plan != "stay":
			out.append(v)
	return out


func _run() -> void:
	game.hero_name = "Crowd test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	lvl.night = false
	var group := _walkers(lvl, 4)
	# No bump-chats here: a pair that stops to talk stands still on purpose.
	game.village_talk._bump_timer = 1.0e9
	check(group.size() == 4, "found four villagers who walk about")
	# The open village paving next to the hero.
	var spot: Vector3 = lvl.player.global_position + Vector3(6, 0, 0)

	# 1. Piled on one point, all facing the same way, standing still.
	for v: Villager in group:
		v._start("idle", 600.0)
		v.global_position = spot
		v.rotation.y = 0.0
		v.chat_partner = null
	await _wait(240)
	var room := Villager.PASSING_SPACE * 0.9
	check(_closest(group) >= room, "four villagers piled on one spot stand apart within 4 s (closest %.2f)" % _closest(group))

	# 1b. The same on one spot with the footprint pass off: the villagers' own pushing has to do it,
	# whichever way they face (the pass is only a backstop that cannot always find a free spot).
	for v: Villager in group:
		v.remove_from_group(Footprint.GROUP)
		v.global_position = spot
		v.rotation.y = 1.0
	await _wait(240)
	check(_closest(group) >= room, "villagers on one spot push themselves apart without the footprint pass (closest %.2f)" % _closest(group))
	for v: Villager in group:
		v.add_to_group(Footprint.GROUP)

	# 2. Same pile, then everybody is sent to one and the same target.
	for v: Villager in group:
		v.global_position = spot
		v.rotation.y = 0.0
	var target: Vector3 = spot + Vector3(0, 0, 8)
	for v: Villager in group:
		v._walk_to(target, Villager.WALK_SPEED, "idle")
	await _wait(480)
	check(_closest(group) >= room, "villagers walking to one target do not clump (closest %.2f)" % _closest(group))
	for v: Villager in group:
		check(v.global_position.distance_to(spot) > 3.0, "a villager walked on from the pile (%s %s path %d)" % [v.global_position, v._task, v._path.size()])

	# 3. Piled on one point and each told to walk off in another direction.
	for v: Villager in group:
		v.global_position = spot
	var start := spot
	for i in group.size():
		var ang := TAU * i / group.size()
		group[i]._walk_to(spot + Vector3(cos(ang), 0, sin(ang)) * 7.0, Villager.WALK_SPEED, "idle")
	await _wait(420)
	check(_closest(group) >= room, "a pile walking off in different ways spreads out (closest %.2f)" % _closest(group))
	for v: Villager in group:
		check(v.global_position.distance_to(start) > 2.0, "a villager got out of the pile (%s)" % v.global_position)

	# 4. A tie that cancels out: two villagers each tied to the other as a chat partner who
	# never arrived, and one more on the same spot. They still come apart.
	var trio := group.slice(0, 3)
	for v: Villager in trio:
		v._start("idle", 600.0)
		v.global_position = spot + Vector3(0.05 * trio.find(v), 0, 0)
	trio[0].chat_partner = trio[1]
	trio[1].chat_partner = trio[0]
	await _wait(600)
	check(_closest(trio) >= room, "a trio with a stale chat tie comes apart (closest %.2f)" % _closest(trio))
	for v: Villager in trio:
		v.chat_partner = null

	# 5. Two stand in a chat and a third is squeezed right between them, pushed from both sides
	# by the same amount. The third gets out of the middle.
	var pair := group.slice(0, 2)
	var third: Villager = group[2]
	pair[0].global_position = spot + Vector3(-0.7, 0, 0)
	pair[1].global_position = spot + Vector3(0.7, 0, 0)
	pair[0].stand_for_chat(pair[1])
	pair[1].stand_for_chat(pair[0])
	third._start("idle", 600.0)
	third.global_position = spot
	await _wait(600)
	check(Vector2(third.global_position.x - pair[0].global_position.x, third.global_position.z - pair[0].global_position.z).length() >= room \
		and Vector2(third.global_position.x - pair[1].global_position.x, third.global_position.z - pair[1].global_position.z).length() >= room, \
		"a villager squeezed between two chatting ones gets free (%s)" % third.global_position)
	for v: Villager in pair:
		v.leave_chat()

	if failures == 0:
		print("PASS: villager crowd")
	else:
		print("FAILED: ", failures)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
