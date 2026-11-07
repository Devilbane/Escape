extends SceneTree
## Headless test for bleeding (see Bleeding): only cutting hits open a wound;
## it bleeds as much life as the hit cost, 1 a second, twice as fast while
## moving; wounds add up; the hero never bleeds the last life and shows a
## blood drop with the life still to bleed; a cure closes the wound; a
## monster bleeds too and can bleed to death.
## Run with: godot --headless -s tests/bleeding.gd

var failures := 0
var game: Node
var frames := 0


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
	if frames == 5:
		_run()
	return false


## Lets a wound run for `seconds` in small steps; returns the life lost.
func _bleed_for(w: Bleeding, seconds: float, moving: bool) -> int:
	var lost := 0
	for i in roundi(seconds * 20.0):
		lost += w.run(0.05, moving)
	return lost


## Runs the hero's ailments for `seconds` in small steps.
func _ail_for(p: Player, seconds: float) -> void:
	for i in roundi(seconds * 20.0):
		p._tick_ailments(0.05)


func _run() -> void:
	# What cuts and what does not.
	check(Bleeding.weapon_cuts("schwert") and Bleeding.weapon_cuts("axt") and Bleeding.weapon_cuts(""), "blades, axes and the hero's dagger cut")
	check(not Bleeding.weapon_cuts("streitkolben") and not Bleeding.weapon_cuts("kriegshammer"), "maces and hammers do not cut")
	for kind in ["krieger", "schuetze", "koloss", "halsabschneider", "wilderer", "wolf", "spinne", "ghul"]:
		check(Bleeding.monster_cuts(kind, Enemy.KINDS[kind]), "%s cuts" % kind)
	for kind in ["magier", "banshee", "totengeist", "ork", "yeti", "schleim", "drache", "felstroll"]:
		check(not Bleeding.monster_cuts(kind, Enemy.KINDS[kind]), "%s does not cut" % kind)
	for kind in Bleeding.CLAWED:
		check(Enemy.KINDS.has(kind), "a clawed beast is a real kind: %s" % kind)

	# The roll: only a hit that cost life, with the chance.
	check(not Bleeding.rolls_wound(0, 1.0, 0.0), "a hit that cost nothing opens no wound")
	check(Bleeding.rolls_wound(2, Bleeding.CHANCE, Bleeding.CHANCE - 0.01), "a roll under the chance opens a wound")
	check(not Bleeding.rolls_wound(2, Bleeding.CHANCE, Bleeding.CHANCE + 0.01), "a roll over the chance does not")

	# The flow: the hit's life, 1 a second; twice as fast while moving.
	var w := Bleeding.new()
	check(w.open(3), "a first wound is fresh")
	check(_bleed_for(w, 0.95, false) == 0, "no life lost in the first second")
	check(_bleed_for(w, 2.1, false) == 3 and not w.active(), "standing: 3 life in 3 seconds, then it stops")
	w.open(3)
	check(_bleed_for(w, 1.55, true) == 3 and not w.active(), "moving: the same 3 life in half the time")
	# Wounds add up.
	w.open(2)
	check(not w.open(3), "a second wound is not fresh")
	check(w.left == 5, "wounds add up: %d" % w.left)
	check(_bleed_for(w, 10.0, false) == 5, "and bleed no more than both hits cost")

	# The hero: an icon with the life left, never the last life, cured by a cure.
	var p: Player = game.player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.cure()
	p.velocity = Vector3.ZERO
	p._knockback = Vector3.ZERO
	# Refreshing the stats (as every new ailment does) sets the life's top.
	p.refresh_stats()
	var top: int = p.max_hp
	check(top >= 5, "the hero has life enough for the test: %d" % top)
	p.hp = top
	p.bleed(4)
	check(p.ailments.has("blut"), "the hero bleeds")
	check(game.hero_ailments().has(["blut", "4"]), "a blood drop under the life bar with the life to bleed: %s" % [game.hero_ailments()])
	check(game.icon_text("blut", "4") != "", "the drop explains itself")
	_ail_for(p, 2.05)
	check(p.hp == top - 2, "standing, 2 life in 2 seconds: %d" % p.hp)
	check(game.hero_ailments().has(["blut", "2"]), "the drop counts down: %s" % [game.hero_ailments()])
	p.velocity = Vector3(p.speed, 0, 0)
	check(p.is_moving(), "walking counts as moving")
	_ail_for(p, 1.05)
	check(p.hp == top - 4 and not p.ailments.has("blut"), "moving, the last 2 life in one second, then it stops: %d" % p.hp)
	p.velocity = Vector3.ZERO
	p._knockback = Vector3(9, 0, 0)
	p.velocity = p._knockback
	check(not p.is_moving(), "being knocked back is not moving")
	p._knockback = Vector3.ZERO
	p.velocity = Vector3.ZERO
	p.hp = 2
	p.bleed(5)
	_ail_for(p, 8.0)
	check(p.hp == 1 and not p.dead, "bleeding never takes the last life: %d" % p.hp)
	p.hp = top
	p.bleed(5)
	check(p.cure(), "a fountain, shrine or potion cures bleeding")
	check(not p.wound.active() and not p.ailments.has("blut"), "the cure closes the wound")
	_ail_for(p, 3.0)
	check(p.hp == top, "a closed wound bleeds no more")

	# A monster: blunt blows never bleed, a cutting one may; it can bleed to death.
	var foe := Enemy.new()
	foe.kind = "krieger"
	foe.level = game.level
	game.level.add_child(foe)
	game.level.enemies.append(foe)
	foe.global_position = p.global_position + Vector3(40, 0, 0)
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	foe.hp = 10
	for i in 50:
		p.wound_foe(foe, 2, false)
	check(not foe.is_bleeding(), "a blunt blow never opens a wound")
	var opened := false
	for i in 50:
		opened = p.wound_foe(foe, 2, true) or opened
	check(opened and foe.is_bleeding(), "a cutting blow sometimes does")
	foe.wound.stop()
	check(not p.wound_foe(foe, 0, true, true), "a blow that cost nothing never bleeds")
	foe.bleed(3)
	for i in 70:
		foe._tick_bleeding(0.05)
	check(foe.hp == 7 and not foe.is_bleeding(), "the monster bled the 3 life of its wound: %d" % foe.hp)
	foe.hp = 2
	foe.bleed(4)
	for i in 70:
		foe._tick_bleeding(0.05)
	check(foe.dead and not foe.slain_by_rival, "it can bleed to death, as the hero's kill")

	# Blood on the floor: drops fall, leave spots, stains grow, the count is capped.
	var lv: Level = game.level
	var floor_at: Vector3 = p.global_position
	var blood := BloodDrops.of(lv)
	check(BloodDrops.of(lv) == blood, "a level keeps one BloodDrops")
	var bw := Bleeding.new()
	check(not bw.drips(1.0, false), "no wound, no drops")
	bw.open(3)
	check(bw.drips(0.0, false) and not bw.drips(0.5, false) and bw.drips(0.4, false), "a standing wound drips every 0.8 s")
	var before := 0
	for sp: Dictionary in blood._splats:
		before += 1 if sp.node.visible else 0
	for i in 3:
		BloodDrops.drip(lv, floor_at + Vector3(i * 2.0, 0, 0), 1.0)
	for i in 40:
		blood._process(0.05)
	var down := 0
	for sp: Dictionary in blood._splats:
		if sp.node.visible:
			down += 1
	check(down - before == 3, "falling drops leave spots: %d" % down)
	for i in 300:
		BloodDrops.pool(lv, floor_at + Vector3(i * 0.01, 0, 0), 0.4)
	check(blood._splats.size() == BloodDrops.MAX_SPLATS, "spots are capped and reused: %d" % blood._splats.size())
	check(blood._drops.size() <= BloodDrops.MAX_DROPS, "falling drops are capped")

	print("PASS: bleeding" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
