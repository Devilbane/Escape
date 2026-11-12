extends SceneTree
## Headless test for NetPresence (scripts/net/net_presence.gd): the server
## takes a hero's place only if the hero could have got there, and each player
## sees the others on the same map within reach, nearest first.
## Run with: godot --headless -s tests/net_presence.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var p := NetPresence.new()
	check(p.report(1, "dorf", Vector3(0, 0, 0), 0.0, "idle", 0.0) == "", "a first place is taken")
	check(p.report(1, "dorf", Vector3(5, 0, 0), 0.0, "run", 1.0) == "", "running 5 m in a second is fine")
	check(p.report(1, "dorf", Vector3(200, 0, 0), 0.0, "run", 1.1) == "too far", "a jump across the map is refused")
	check(p.place_of(1).pos == Vector3(5, 0, 0), "a refused place does not move the hero")
	check(p.report(1, "gruft", Vector3(200, 0, 0), 0.0, "idle", 1.2) == "", "changing maps may land anywhere")
	check(p.report(1, "gruft", Vector3(INF, 0, 0), 0.0, "idle", 1.3) == "bad place", "a non-finite place is refused")

	# Who sees whom.
	p.report(2, "gruft", Vector3(210, 0, 0), 1.0, "walk", 1.3)
	p.report(3, "gruft", Vector3(230, 0, 0), 0.0, "idle", 1.3)
	p.report(4, "gruft", Vector3(200 + NetPresence.VIEW_RADIUS + 5, 0, 0), 0.0, "idle", 1.3)
	p.report(5, "dorf", Vector3(200, 0, 0), 0.0, "idle", 1.3)
	var seen := p.seen_by(1)
	var ids := seen.map(func(e): return e.id)
	check(ids == [2, 3], "the hero sees the near ones on the same map, nearest first")
	check(seen[0].anim == "walk" and is_equal_approx(seen[0].facing, 1.0), "a seen player carries facing and animation")
	check(p.seen_by(99).is_empty(), "a player with no place sees nobody")
	p.forget(2)
	check(p.seen_by(1).map(func(e): return e.id) == [3], "a player who left is not seen")

	# The crowd is capped.
	var crowd := NetPresence.new()
	for i in NetPresence.MAX_SEEN + 10:
		crowd.report(100 + i, "dorf", Vector3(i, 0, 0), 0.0, "idle", 0.0)
	check(crowd.seen_by(100).size() == NetPresence.MAX_SEEN, "nobody sees more than MAX_SEEN others")

	# The command itself.
	var where := Commands.make("where", {"level": "dorf", "pos": Vector3(1, 0, 2), "facing": 0.5, "anim": "idle"})
	check(Commands.check(where) == "", "a where command is well formed")
	where.level = ""
	check(Commands.check(where) != "", "a where without a map is refused")

	if failures == 0:
		print("PASS: net presence")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
