extends SceneTree
## Headless test: the hero's base speed (Tempo, gear, gifts, level) stops at
## Player.BASE_SPEED_CAP, while the run boost still applies on top of it.
## Run with: godot --headless --fixed-fps 60 -s tests/speed_cap.gd

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


func _run() -> void:
	var p: Node = game.player
	p.gift_speed = 0.0
	p.refresh_stats()
	check(not p.base_speed_capped, "an ordinary hero is not capped")
	var plain: float = p.base_speed
	p.gift_speed = 0.2
	p.refresh_stats()
	check(is_equal_approx(p.base_speed, plain * 1.2) and not p.base_speed_capped, "+20 %% below the cap counts fully (%.2f)" % p.base_speed)
	p.gift_speed = 2.0
	p.refresh_stats()
	var top: float = Player.SPEED * Player.BASE_SPEED_CAP
	check(p.base_speed_capped, "far over the cap is flagged")
	check(is_equal_approx(p.base_speed, top), "base speed stops at 150 %% (%.2f of %.2f)" % [p.base_speed, top])
	check(p.base_speed_wanted > Player.BASE_SPEED_CAP, "the uncapped total is still known")
	# Slowing ailments come after the cap.
	p.ailments["fluch"] = 5.0
	p.refresh_stats()
	check(is_equal_approx(p.base_speed, top * Player.CURSE_SLOW), "a curse slows the capped value")
	p.ailments.erase("fluch")
	p.refresh_stats()
	# Running still goes above the cap: pace = speed * WALK_FACTOR * run_boost, run_boost up to RUN_TOP.
	var walk: float = p.speed * Player.WALK_FACTOR
	var run: float = p.speed * Player.WALK_FACTOR * Player.RUN_TOP
	check(run > walk * 1.9 and run > top * Player.WALK_FACTOR, "running (%.2f m/s) exceeds the capped walk (%.2f)" % [run, walk])
	p.gift_speed = 0.0
	p.refresh_stats()
	print("speed_cap: ", "OK" if failures == 0 else "%d failure(s)" % failures)
	quit(failures)
