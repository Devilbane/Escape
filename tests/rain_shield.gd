extends SceneTree
## Headless test for Elsbeth's rain shield (see RainShield): it rises when it rains on her in the open,
## stays down indoors and in dry weather, and fades away when the rain stops.
## Run with: godot --headless -s tests/rain_shield.gd --fixed-fps 60

var failures := 0
var game: Node
var frames := 0
var started := false
const STEP := 1.0 / 60.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5 or started:
		return false
	started = true
	_test()
	return false


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: rain shield" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _run(who: Villager, shield: RainShield, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		who._physics_process(STEP)
		shield._process(STEP)
		t += STEP


func _test() -> void:
	await _body()
	_finish()


func _body() -> void:
	check(Lang.EN.has(RainShield.CHANT), "the chant has an English text")
	var mesh := RainShield.build_dome()
	check(mesh.get_surface_count() == 1 and mesh.surface_get_array_len(0) > 100, "the dome has a surface")
	game.hero_name = "Testheld Regen"
	game.load_level(game._outdoor_index(), false)
	var village: Outdoor = game.level
	game.state = game.State.PLAYING
	game.village_talk._timer = 1e9
	game.village_worries._remark_timer = 1e9
	village.set_hour(12.0)
	var elsbeth: Villager
	for v: Villager in village.villagers:
		if v.role == RainShield.ROLE:
			elsbeth = v
	check(elsbeth != null, "Elsbeth is in the village")
	if elsbeth == null:
		return
	var shield: RainShield = elsbeth.get_node_or_null("RainShield")
	check(shield != null, "she carries a rain shield")
	if shield == null:
		return
	elsbeth.at_home = false
	elsbeth.visible = true
	elsbeth._start("work", 1e6)
	elsbeth.threat = null
	game.set_weather(Weather.CLEAR, 5.0)
	await process_frame
	await process_frame
	_run(elsbeth, shield, 1.0)
	check(not shield.up() and shield.amount() == 0.0 and not shield.visible, "no shield in dry weather")
	game.set_weather(Weather.RAIN, 5.0)
	await process_frame
	await process_frame
	_run(elsbeth, shield, 0.3)
	check(shield.casting() or shield.up(), "she starts the spell when the rain starts")
	_run(elsbeth, shield, RainShield.CAST_TIME + RainShield.SWELL_TIME + 0.5)
	check(shield.up() and shield.amount() >= 1.0 and shield.visible, "the shield is up after the cast")
	var puffs: GPUParticles3D = shield.get_node("Puffs")
	check(puffs.emitting, "raindrops burst into puffs on it")
	check(shield.find_children("*", "Node3D", true, false).size() <= 2, "no node per drop: a dome and one particle system")
	game.set_weather(Weather.CLEAR, 5.0)
	await process_frame
	await process_frame
	_run(elsbeth, shield, 0.5)
	check(not shield.up() and shield.amount() < 1.0 and shield.amount() > 0.0, "it fades once the rain stops")
	_run(elsbeth, shield, RainShield.FADE_TIME + 0.5)
	check(shield.amount() == 0.0 and not shield.visible and not puffs.emitting, "it is gone in the end")
	# Away from the open air (home, hidden): no shield even in the rain.
	game.set_weather(Weather.RAIN, 5.0)
	await process_frame
	await process_frame
	elsbeth.at_home = true
	_run(elsbeth, shield, 2.0)
	check(not shield.up(), "no shield while she is at home")
