extends SceneTree
## Headless test for Nohpaan, the hidden valley, and the lessons of its monks (see Nohpaan, Monastery): the map
## loads with its monks, gates and way back; the lessons cost gold and ask for skill, and each does its small thing.
## Run with: godot --headless --fixed-fps 60 -s tests/nohpaan.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait := 0


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
	if wait > 0:
		wait -= 1
		return false
	match stage:
		0:
			game.hero_name = "Nohpaan test"
			game.escaped = true
			var index := Nohpaan.level_index(game)
			check(index >= 0, "the valley is among the game's levels")
			check(game.interiors.get(Nohpaan.BUILDING, -1) == index, "the building leads to the valley")
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			check(game.level.doors.has(Nohpaan.BUILDING), "the ledge of the summit garden is the way out of the valley")
			game.load_level(index, false)
			game.state = game.State.PLAYING
			wait = 30
			stage = 1
		1:
			var lvl: Level = game.level
			check(lvl.building == Nohpaan.BUILDING and lvl.theme == Nohpaan.THEME and lvl.wall_style == Nohpaan.WALLS, "inside the valley")
			check(not lvl.safe, "the valley has monsters")
			var teachers := {}
			for s: Dictionary in lvl.stations:
				if s.kind == "figur" and s.figure.spec.has("teaches"):
					teachers[s.figure.spec.teaches] = true
			check(teachers.size() == 3 and Monastery.SKILLS.keys().all(func(id): return teachers.has(id)), "three monks teach the three skills")
			check(lvl.stations.filter(func(s): return s.kind == Nohpaan.SEALED_KIND).size() == 2, "two sealed gates")
			check(lvl.exit_cell != Vector2i.ZERO, "the stairs back down")
			check(lvl.find_child("NohpaanLife", true, false) != null, "the valley lives (mist, wheels)")
			check(Mines.mood(Nohpaan.THEME).has("ambient"), "the valley has its own light")
			# Walking around a pillar of the gate stays open: the gate's cell is the only way in.
			var gate_cell := Vector2i(32, 16)
			check(lvl.cell_char(gate_cell) == Nohpaan.GATE and not Level.SOLID.contains(Nohpaan.GATE), "the gate is a way through")
			_lessons()
			if failures == 0:
				print("PASS")
			else:
				print("FAILED: ", failures)
			quit(failures)
	return false


func _lessons() -> void:
	var p: Player = game.player
	game.coins = 0
	check(Monastery.lessons(p, "bergatem") == 0 and not Monastery.knows_any(p), "no lessons at first")
	check(Monastery.climb_bonus(p) == 0 and Monastery.regen_bonus(p) == 0.0 and Monastery.dodge_bonus(p) == 0.0, "no bonus without lessons")
	check(Monastery.learn(game, "bergatem") != "", "a lesson needs the skill and the gold")
	game.coins = 100000
	check(Monastery.why_not(game, "bergatem") != "", "Bergatem asks for Klettern before the gold counts")
	p.xp["klettern"] = Training.skill_xp_for(10)
	p.xp["weisheit"] = 0.0
	var before_coins: int = Payment.worth(game)
	check(Monastery.learn(game, "bergatem") == "", "the first lesson is learned")
	check(Payment.worth(game) == before_coins - Monastery.price(1), "it costs its price")
	check(Monastery.lessons(p, "bergatem") == 1 and Monastery.knows_any(p), "one lesson learned")
	check(Monastery.learn(game, "bergatem") == "", "the second lesson")
	check(Monastery.learn(game, "bergatem") == "", "the third lesson")
	check(Monastery.learn(game, "bergatem") != "", "there is no fourth")
	check(Monastery.lessons(p, "bergatem") == 3 and Monastery.climb_bonus(p) == 3, "Bergatem gives three levels of Klettern in all")
	var base_klettern := Training.skill_level(float(p.xp["klettern"]), "klettern")
	check(p.skill("klettern") >= base_klettern + 3 or base_klettern + 3 > 10, "and Player.skill counts them")
	var regen_before := p.life_regen()
	p.xp["stille_mitte"] = Training.skill_xp_for(2)
	check(is_equal_approx(Monastery.regen_bonus(p), 2 * Monastery.REGEN_PER_LESSON) and p.life_regen() > regen_before, "Stille Mitte heals faster")
	var dodge_before := p.dodge_chance()
	p.xp["windschritt"] = Training.skill_xp_for(3)
	check(p.dodge_chance() > dodge_before, "Windschritt dodges more")
	check(Monastery.SKILLS.keys().all(func(id): return Training.CRAFTS.has(id) and SkillTrees.in_game(id)), "the lessons are skills of the trees")
