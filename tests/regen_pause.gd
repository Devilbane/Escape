extends SceneTree
## Headless test for the healing pause: life from Konstitution comes back on its
## own, but rests for Player.REGEN_PAUSE_AFTER_HIT seconds after every blow that
## costs life, then goes on where it left off.
## Run with: godot --headless -s tests/regen_pause.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
	return false


## Runs the healing for this many seconds in small steps; returns life gained.
func _heal_for(p: Player, seconds: float) -> int:
	var before: int = p.hp
	var steps := roundi(seconds * 10.0)
	for i in steps:
		p._regenerate(0.1)
	return p.hp - before


func _run() -> void:
	var p: Player = game.player
	# The test drives the clock itself.
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.max_hp = 100
	p.hp = 50
	var per_pulse := p.attribute("konstitution") / Player.REGEN_PER_CON_DIVISOR
	check(per_pulse >= 1.0, "the hero heals at least one life per pulse: %.1f" % per_pulse)

	# Untouched, a pulse heals after REGEN_INTERVAL seconds.
	p._regen = 0.0
	p._regen_clock = 0.0
	check(_heal_for(p, Player.REGEN_INTERVAL - 0.2) == 0, "no healing before the interval")
	check(_heal_for(p, 0.3) > 0, "healing comes at the interval")

	# A blow just before the pulse holds it back for the pause.
	p._regen = 0.0
	p._regen_clock = Player.REGEN_INTERVAL - 0.5
	p._invulnerable = 0.0
	var hp_before: int = p.hp
	p.take_damage(4, p.global_position + Vector3(1, 0, 0), null, false)
	check(p.hp < hp_before, "the blow costs life")
	var hurt_hp: int = p.hp
	check(_heal_for(p, Player.REGEN_PAUSE_AFTER_HIT - 0.1) == 0, "no healing during the pause after a blow")
	check(p.hp == hurt_hp, "life stays put while the pause runs")
	# After the pause the clock goes on where it stopped: 0.5 s to the pulse.
	check(_heal_for(p, 0.3) == 0, "the pulse is not rushed after the pause")
	check(_heal_for(p, 0.5) > 0, "healing resumes after the pause")

	# Full life: nothing is pending.
	p.hp = p.max_hp
	p._regen_pause = 1.0
	p._regenerate(0.1)
	check(p._regen_pause == 0.0, "full life clears the pause")

	check(p.life_regen() > 0.0, "the shown rate stays the average rate")
	print("PASS: regen pause" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
