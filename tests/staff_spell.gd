extends SceneTree
## Headless test for Elsbeth's spell with her staff (see StaffSpell): now and then she raises the
## staff and intones, then the staff glows for a while and fades away again.
## Run with: godot --headless -s tests/staff_spell.gd --fixed-fps 60

var failures := 0
var game: Node
var frames := 0
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
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path())
	print("PASS: staff spell" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	for line in StaffSpell.CHANTS:
		check(Lang.EN.has(line), "the chant has an English text: " + line)
	game.hero_name = "Testheld Zauber"
	game.load_level(game._outdoor_index(), false)
	var village: Outdoor = game.level
	game.state = game.State.PLAYING
	game.village_talk._timer = 1e9
	game.village_worries._remark_timer = 1e9
	village.set_hour(12.0)
	var elsbeth: Villager
	for v: Villager in village.villagers:
		if v.role == StaffSpell.ROLE:
			elsbeth = v
	check(elsbeth != null, "Elsbeth is in the village")
	if elsbeth == null:
		return
	var spell: StaffSpell = elsbeth.get_node_or_null("StaffSpell")
	check(spell != null, "she carries a staff spell")
	if spell == null:
		return
	check(not spell.glowing() and spell.glow() == 0.0, "the staff does not glow at first")
	elsbeth._start("work", 1e6)
	elsbeth.threat = null
	var said := []
	var hear := func(who: String, text: String, _pos: Vector3) -> void: said.append(text)
	Events.bus().speech_said.connect(hear)
	spell.cast()
	check(spell.chanting(), "she chants")
	check(said.size() == 1 and StaffSpell.CHANTS.has(said[0]), "she intones one of her chants")
	check(elsbeth._current_anim == StaffSpell.POSE, "she raises her staff")
	var peak := 0.0
	var seconds := 0.0
	var glowed_after_chant := false
	while seconds < StaffSpell.CHANT_TIME + StaffSpell.GLOW_TIME + 2.0:
		elsbeth._physics_process(STEP)
		spell._process(STEP)
		seconds += STEP
		peak = maxf(peak, spell.glow())
		if seconds > StaffSpell.CHANT_TIME + 0.2 and not glowed_after_chant:
			glowed_after_chant = spell.glowing()
	check(glowed_after_chant, "the staff glows once the spell is cast")
	check(peak > 0.9, "the glow reaches full strength: %.2f" % peak)
	check(not spell.glowing() and spell.glow() == 0.0, "the glow has faded in the end")
	var tip := elsbeth.find_child("2H_Staff", true, false)
	var lit := false
	for l in tip.find_children("*", "OmniLight3D", true, false):
		lit = lit or (l as OmniLight3D).visible
	check(not lit, "the staff's light is out again")
	Events.bus().speech_said.disconnect(hear)
	# Her work goes on in between: it is Idle, the spell only comes now and then.
	spell._wait = 0.1
	for i in 30:
		elsbeth._physics_process(STEP)
	check(spell.chanting() or spell.glowing(), "after her wait she casts again by herself")
