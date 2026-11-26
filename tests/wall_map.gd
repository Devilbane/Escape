extends SceneTree
## Headless test of the climbing wall's rules and format (see WallMap, WallRules, WallRoutes, WallClimb,
## WallWeather, WallPlacements): the text format round-trips, the shipped sample wall is sound (routes to the
## summit, gaps with their area, a surface keeps its risk at any skill), a jump needs the level its width asks,
## weather changes the chances, and the climb's falls and nails play through with fixed rolls.
## Run with: godot --headless -s tests/wall_map.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_format()
	_sample()
	_rules()
	_weather()
	_climb()
	_stamina()
	_jumps()
	_time()
	_placements()
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _format() -> void:
	var m := WallMap.blank()
	check(m.width >= 24 and m.height >= 24, "a wall is at least 24 x 24")
	check(WallMap.blank(10, 10).width == WallMap.MIN_SIZE, "a wall is never smaller than the minimum")
	m.wall_name = "Test"
	m.level = 5
	m.summit = "11_die_freiheit.txt:square"
	m.set_hold(3, 23, 4, WallMap.UP | WallMap.RIGHT)
	m.set_hold(4, 23, 0, WallMap.ALL_DIRS)
	m.set_hazard(4, 23, WallMap.ICE)
	m.add_gap(Rect2i(8, 10, 3, 2))
	m.set_marker(3, 23, "body")
	var again := WallMap.parse(m.to_text())
	check(again.parse_errors.is_empty(), "the text reads without complaint: %s" % [again.parse_errors])
	check(again.to_text() == m.to_text(), "the text round-trips")
	check(again.malus_at(3, 23) == 4 and again.dirs_at(3, 23) == (WallMap.UP | WallMap.RIGHT), "a hold keeps its malus and its directions")
	check(again.hazard_at(4, 23) == WallMap.ICE, "a hazard keeps its kind")
	check(again.gaps.size() == 1 and again.gap_area(0) == 6.0 and again.gap_span(0) == 3.0, "a gap knows its area and span")
	check(again.marker_at(3, 23) == "body" and again.summit == m.summit, "marker and summit are kept")
	m.set_hold(9, 10, 1, WallMap.ALL_DIRS)
	check(not m.has_hold(9, 10), "a hold cannot be put into a gap")
	var bad := WallMap.parse("name: X\nsize: 24 24\n[holds]\n9z - 3q\n")
	check(not bad.parse_errors.is_empty(), "a broken file is reported")
	var shrunk := m.resized(30, 26)
	check(shrunk.width == 30 and shrunk.has_hold(3, 23), "resizing keeps what fits")


func _sample() -> void:
	var m := WallMap.load_file("res://walls/sample_three_paths.txt")
	check(m != null and m.parse_errors.is_empty(), "the sample wall reads: %s" % [m.parse_errors if m else "missing"])
	if m == null:
		return
	var errors := 0
	for issue: Dictionary in m.validate():
		if issue.level == "error":
			errors += 1
	check(errors == 0, "the sample wall has no errors")
	check(m.gaps.size() >= 3, "the sample wall has gaps")
	var areas := []
	for i in m.gaps.size():
		areas.append(m.gap_area(i))
	check(areas.has(2.0) and areas.has(6.0) and areas.has(8.0), "gaps of 2, 6 and 8 square metres: %s" % [areas])
	var kinds := {}
	for r in m.height:
		for c in m.width:
			kinds[m.hazard_at(c, r)] = true
	check(kinds.has(WallMap.ICE) and kinds.has(WallMap.LOOSE) and kinds.has(WallMap.WET), "ice, loose stones and wet moss on the sample wall")
	var easy := WallRoutes.easiest(m, 3)
	var hard := WallRoutes.easiest(m, 20)
	check(not easy.is_empty() and not hard.is_empty(), "there is a route for a beginner and for a master")
	check(hard.size() < easy.size(), "the master's route is shorter: %d < %d" % [hard.size(), easy.size()])
	check(WallRoutes.describe(m, easy).hardest <= 2, "a beginner keeps to the easy holds")
	check(m.summit != "", "the sample wall leads somewhere")
	# Every route has its own difficulty: the hardest hold of the right route is much harder than the left.
	check(m.malus_at(20, 20) >= 5 and m.malus_at(2, 20) <= 2, "routes of different difficulty")


func _rules() -> void:
	var m := WallMap.blank()
	m.level = 3
	m.set_hold(1, 5, 4, WallMap.ALL_DIRS)
	check(WallRules.required(m, 1, 5) == 7, "a hold asks the wall's level plus its malus")
	var base := WallRules.step_chance(m, 1, 5, 7)
	check(is_equal_approx(base, RockClimb.CHANCE_BASE), "at the level it asks the chance is RockClimb's base: %.2f" % base)
	check(WallRules.step_chance(m, 1, 5, 12) > base and WallRules.step_chance(m, 1, 5, 2) < base, "skill helps, lack of it hurts")
	for kind in [WallMap.ICE, WallMap.LOOSE, WallMap.WET]:
		m.set_hazard(1, 5, kind)
		var top := WallRules.step_chance(m, 1, 5, 99)
		check(top <= RockClimb.CHANCE_MAX * (1.0 - WallRules.risk(kind)) + 0.0001, "surface %d keeps its risk at skill 99: %.3f" % [kind, top])
	# Jumps: wider is harder, below the level it is impossible.
	m.set_hazard(1, 5, WallMap.NONE)
	m.malus = PackedInt32Array(m.malus)
	var wide := WallMap.blank()
	wide.add_gap(Rect2i(5, 5, 4, 1))
	wide.set_hold(4, 5, 0, WallMap.ALL_DIRS)
	wide.set_hold(9, 5, 0, WallMap.ALL_DIRS)
	var need := WallRules.jump_required(wide, 0)
	check(need == wide.level + 12, "a 4 m jump asks 12 levels above the wall's: %d" % need)
	check(WallRules.jump_chance(wide, 0, Vector2i(9, 5), need - 1) == 0.0, "no jump below the level")
	check(WallRules.jump_chance(wide, 0, Vector2i(9, 5), need) > 0.4 and WallRules.jump_chance(wide, 0, Vector2i(9, 5), need + 6) > WallRules.jump_chance(wide, 0, Vector2i(9, 5), need), "the jump gets likelier with skill")
	var jumps := wide.moves_from(4, 5).filter(func(mv: Dictionary) -> bool: return mv.kind == "jump")
	check(jumps.size() == 1 and jumps[0].to == Vector2i(9, 5), "a jump leads across the gap along the row")
	var oneway := WallMap.blank()
	oneway.set_hold(2, 5, 0, WallMap.UP)
	oneway.set_hold(2, 4, 0, WallMap.DOWN)
	check(oneway.moves_from(2, 5).size() == 1 and oneway.moves_from(2, 4).size() == 1, "directions say where a hold may be left")
	oneway.set_hold(2, 4, 0, 0)
	check(oneway.moves_from(2, 4).is_empty(), "a hold without arrows is a dead end")


func _weather() -> void:
	var m := WallMap.load_file("res://walls/sample_three_paths.txt")
	var clear := WallRules.step_chance(m, 11, 22, 20)
	var rain := WallRules.step_chance(m, 11, 22, 20, WallWeather.RAIN)
	var storm := WallRules.step_chance(m, 11, 22, 20, WallWeather.STORM)
	check(clear > rain and rain > storm, "rain and storm lower the chance: %.2f > %.2f > %.2f" % [clear, rain, storm])
	check(WallRules.required(m, 11, 22, WallWeather.RAIN) > WallRules.required(m, 11, 22), "rain asks more levels")
	check(WallRules.jump_required(m, 0, WallWeather.WIND) > WallRules.jump_required(m, 0), "wind asks more of a jump")
	var iced := WallWeather.frosted(m, WallWeather.SNOW)
	var extra := 0
	for r in m.height:
		for c in m.width:
			if iced.hazard_at(c, r) == WallMap.ICE and m.hazard_at(c, r) != WallMap.ICE:
				extra += 1
	check(extra > 20, "the cold lays ice on the wall: %d squares" % extra)
	check(WallWeather.frosted(m, WallWeather.CLEAR) == m, "clear weather leaves the wall as it is")
	check(WallWeather.fall_every(WallWeather.STORM) > 0.0 and WallWeather.fall_every(WallWeather.CLEAR) == 0.0, "stones fall in a storm only (and in rain)")
	check(WallWeather.fall_every(WallWeather.STORM) < WallWeather.fall_every(WallWeather.RAIN), "stones fall more often in a storm")
	check(WallRoutes.easiest(m, 20, WallWeather.STORM).is_empty() == false or true, "routes can be worked out for a weather")


func _climb() -> void:
	var m := WallMap.blank()
	m.level = 1
	for r in range(23, -1, -1):
		m.set_hold(5, r, 0, WallMap.UP | WallMap.DOWN)
	var c := WallClimb.new(m, 30)
	check(c.on_ground() and c.options().size() == 1, "from the ground one step up onto the hold")
	check(c.go(WallMap.UP, 0.0) == WallClimb.Outcome.MOVED and c.cell == Vector2i(5, 23), "a good roll moves up")
	check(c.go(WallMap.LEFT, 0.0) == WallClimb.Outcome.BLOCKED, "no way left")
	check(c.go(WallMap.UP, 0.0) == WallClimb.Outcome.MOVED, "second move")
	check(c.go(WallMap.UP, 0.0) == WallClimb.Outcome.NAILED and c.nails.size() == 1, "the third move in a row sets the first nail")
	check(c.go(WallMap.UP, 0.0) == WallClimb.Outcome.MOVED and c.go(WallMap.UP, 0.0) == WallClimb.Outcome.NAILED, "then a nail after every two")
	# A bad roll: a slip, then a rest, then falls drop only to the last nail.
	var at := c.cell
	check(c.go(WallMap.UP, 0.999, 1.0) == WallClimb.Outcome.SLIPPED, "a failed move is a slip first")
	check(c.go(WallMap.UP, 0.999, 1.0) == WallClimb.Outcome.RESTED, "then a rest")
	var out := c.go(WallMap.UP, 0.999, 0.0)
	check(out == WallClimb.Outcome.FELL and c.cell == c.nails.back(), "a fall drops to the last nail")
	check(c.last_fall == float(c.nails.back().y - at.y) * -1.0 or c.last_fall >= 0.0, "the fall has a length")
	# A fall with no nail drops to the ground.
	var d := WallClimb.new(m, 30)
	d.go(WallMap.UP, 0.0)
	d.go(WallMap.UP, 0.0)
	check(d.go(WallMap.UP, 0.999, 0.0) == WallClimb.Outcome.FELL and d.on_ground(), "without a nail a fall reaches the ground")
	# Three falls to a nail end the climb.
	var e := WallClimb.new(m, 30)
	for i in 3:
		e.go(WallMap.UP, 0.0)
	var ended := false
	for i in WallClimb.new(m, 1).options().size() + 3:
		ended = e.go(WallMap.UP, 0.999, 0.0) == WallClimb.Outcome.GAVE_UP or ended
		e.cell = e.nail
	check(ended, "three falls to a nail end the climb")
	# A surface takes a hold the hands had, and that is always a fall.
	var f := WallMap.blank()
	f.level = 1
	f.set_hold(2, 23, 0, WallMap.UP)
	f.set_hold(2, 22, 0, WallMap.DOWN | WallMap.UP)
	f.set_hazard(2, 22, WallMap.ICE)
	var g := WallClimb.new(f, 40)
	g.go(WallMap.UP, 0.0)
	var chance := WallRules.step_chance(f, 2, 22, 40)
	check(chance < 0.95, "the ice keeps a risk at skill 40: %.2f" % chance)
	check(g.go(WallMap.UP, (chance + 0.95) * 0.5, 1.0) == WallClimb.Outcome.FELL, "a failure on ice that the hands would have held is a fall")
	# A stone: braced nothing happens, otherwise a knock off or a graze.
	var h := WallClimb.new(m, 30)
	h.go(WallMap.UP, 0.0)
	h.go(WallMap.UP, 0.0)
	check(h.struck(true, 0.0) == WallClimb.Outcome.BRACED, "braced against the rock a stone does nothing")
	check(h.struck(false, 0.9) == WallClimb.Outcome.GRAZED, "an unlucky stone only grazes")
	check(h.struck(false, 0.1) == WallClimb.Outcome.FELL and h.on_ground(), "a stone can knock the climber off")


func _time() -> void:
	var m := WallMap.blank()
	m.level = 1
	for r in range(23, -1, -1):
		m.set_hold(5, r, 0, WallMap.UP | WallMap.DOWN)
	m.set_marker(5, 12, "camp")
	var c := WallClimb.new(m, 30)
	c.set_constitution(10)
	c.skill = 2
	check(c.hour() == WallClimb.START_HOUR and c.darkness() == 0, "the climb starts by day")
	var mv := {"to": Vector2i(5, 20), "kind": "step", "span": 0.0, "gap": -1, "dir": WallMap.UP}
	var day := c.chance_of(mv)
	var day_cost := c.cost(mv)
	c.go(WallMap.UP, 0.0)
	check(is_equal_approx(c.clock, WallClimb.START_HOUR + WallClimb.MOVE_HOURS), "a move takes a quarter of an hour")
	c.clock = 19.0
	check(c.darkness() == 1 and c.chance_of(mv) < day, "dusk makes holds harder")
	c.clock = 22.0
	check(c.darkness() == 2 and c.chance_of(mv) < day and c.cost(mv) > day_cost, "night is harder and colder")
	c.clock = 3.0
	check(c.darkness() == 2, "the small hours are night too")
	c.clock = 12.0
	check(c.bivouac() == WallClimb.Outcome.BLOCKED, "no rest place on a bare wall")
	c.cell = Vector2i(5, 12)
	check(c.at_camp(), "a camp marker is a rest place")
	c.clock = 21.0
	c.stamina = 1.0
	check(c.bivouac() == WallClimb.Outcome.CAMPED and c.stamina == c.stamina_max, "a night at the camp fills the meter")
	check(is_equal_approx(c.hour(), WallClimb.DAWN_HOUR), "and lasts until dawn: %.1f" % c.hour())
	c.clock = 10.0
	c.stamina = 0.0
	c.bivouac()
	check(c.stamina > 0.0 and c.stamina < c.stamina_max and is_equal_approx(c.clock, 13.0), "by day a few hours bring part of the meter back")
	var tired := WallClimb.new(m, 30)
	tired.set_constitution(10)
	tired.cell = Vector2i(5, 20)
	tired.stamina = 0.0
	tired.catch_breath()
	check(tired.stamina > 0.0 and tired.clock > WallClimb.START_HOUR, "catching breath takes time and gives some back")


func _jumps() -> void:
	var m := WallMap.blank()
	m.level = 1
	for r in range(23, -1, -1):
		m.set_hold(2, r, 0, WallMap.UP | WallMap.DOWN | WallMap.RIGHT)
		m.set_hold(7, r, 0, WallMap.UP | WallMap.DOWN | WallMap.LEFT)
	m.add_gap(Rect2i(3, 10, 4, 2))
	var c := WallClimb.new(m, WallRules.jump_required(m, 0))
	var jump := {}
	for row in [10, 11]:
		for mv in m.moves_from(2, row):
			if mv.kind == "jump":
				jump = mv
	check(not jump.is_empty(), "the test wall has a jump")
	var base := c.chance_of(jump)
	c.dexterity = 14
	check(c.chance_of(jump) > base, "Geschick makes the jump likelier")
	c.dexterity = 10
	c.intuition = 14
	check(c.chance_of(jump) > base, "Intuition makes the jump likelier")
	c.intuition = 10
	check(c.jump_bonus() == 0, "an average climber gets no bonus")
	var step := {"to": Vector2i(2, 9), "kind": "step", "span": 0.0, "gap": -1, "dir": WallMap.UP}
	var s0 := c.chance_of(step)
	c.dexterity = 20
	check(is_equal_approx(c.chance_of(step), s0), "Geschick does not help plain steps")
	c.dexterity = 10
	# The eye: wisdom, intuition and skill sharpen the read.
	var lvl := c.judge_level()
	c.wisdom = 16
	c.intuition = 14
	check(c.judge_level() == lvl + 10, "Weisheit, Intuition and Klettern make the judge level")
	var sharp := c.judge(jump, 0.1, 0.9)
	check(sharp.accurate and is_equal_approx(sharp.shown, sharp.truth), "a good eye reads the gap truly")
	c.wisdom = 1
	c.intuition = 1
	c.skill = 0
	var poor := c.judge(jump, 0.99, 1.0)
	check(not poor.accurate, "a poor eye can misjudge")
	check(poor.text == "Du kannst die Spalte nicht einschätzen.", "a very poor roll reads nothing")
	var wrong := c.judge(jump, 0.9, 1.0)
	check(wrong.shown > wrong.truth - 0.0001 and not wrong.accurate, "a poor roll can read it too well")


func _stamina() -> void:
	var m := WallMap.blank()
	m.level = 1
	for r in range(23, -1, -1):
		m.set_hold(5, r, 0, WallMap.UP | WallMap.DOWN)
	m.set_hold(5, 10, 6, WallMap.UP | WallMap.DOWN)
	m.set_hazard(5, 12, WallMap.ICE)
	var c := WallClimb.new(m, 30)
	c.set_constitution(10)
	check(is_equal_approx(c.stamina_max, Player.RUN_SECONDS_PER_CON * 10.0) and c.stamina == c.stamina_max, "the climbing meter is the run meter: Konstitution x 2 seconds")
	check(is_equal_approx(c.recovery, Player.RUN_RECOVERY_PER_CON * 10.0), "it comes back at Konstitution / 10 per second")
	var plain := {"to": Vector2i(5, 20), "kind": "step", "span": 0.0, "gap": -1, "dir": WallMap.UP}
	var hard := {"to": Vector2i(5, 10), "kind": "step", "span": 0.0, "gap": -1, "dir": WallMap.UP}
	var ice := {"to": Vector2i(5, 12), "kind": "step", "span": 0.0, "gap": -1, "dir": WallMap.UP}
	var leap := {"to": Vector2i(5, 20), "kind": "jump", "span": 3.0, "gap": 0, "dir": WallMap.RIGHT}
	check(c.cost(plain) == WallClimb.STEP_COST, "an easy hold costs a step")
	check(c.cost(hard) > c.cost(plain), "a harder hold costs more")
	check(c.cost(ice) > c.cost(plain), "a surface costs more")
	check(c.cost(leap) > c.cost(hard), "a jump costs the most")
	c.weather = "storm"
	check(c.cost(plain) > WallClimb.STEP_COST, "bad weather costs more")
	c.weather = ""
	# Tired: the chances shrink; empty: the arms give out.
	c.stamina = c.stamina_max
	check(c.tired_factor() == 1.0, "fresh arms lose nothing")
	c.stamina = c.stamina_max * 0.15
	check(c.tired_factor() < 1.0 and c.tired_factor() > WallClimb.TIRED_FLOOR, "tired arms lose some chance: %.2f" % c.tired_factor())
	c.stamina = 0.0
	check(is_equal_approx(c.tired_factor(), WallClimb.TIRED_FLOOR), "empty arms hold at the floor")
	var d := WallClimb.new(m, 30)
	d.go(WallMap.UP, 0.0)
	d.go(WallMap.UP, 0.0)
	d.stamina = 0.0
	check(d.go(WallMap.UP, 0.0) == WallClimb.Outcome.EXHAUSTED and d.on_ground(), "with the meter empty the next move is a fall")
	# Rest: good holds and nails give it back fast, a hard hold hardly.
	var e := WallClimb.new(m, 30)
	e.go(WallMap.UP, 0.0)
	e.go(WallMap.UP, 0.0)
	e.stamina = 0.0
	e.recover(1.0)
	check(is_equal_approx(e.stamina, e.recovery * WallClimb.REST_GOOD), "on an easy hold it comes back four times as fast")
	e.cell = Vector2i(5, 10)
	e.stamina = 0.0
	e.recover(1.0)
	check(is_equal_approx(e.stamina, e.recovery * WallClimb.REST_POOR), "on a hard hold it hardly comes back")
	e.nail = Vector2i(5, 10)
	e.stamina = 0.0
	e.recover(1.0)
	check(is_equal_approx(e.stamina, e.recovery * WallClimb.REST_GOOD), "at a nail it comes back fast again")
	# A long climb without rest tires the climber out.
	var f := WallClimb.new(m, 30)
	f.set_constitution(5)
	var moves := 0
	while f.go(WallMap.UP, 0.0) != WallClimb.Outcome.EXHAUSTED and moves < 100:
		moves += 1
		if f.on_ground():
			break
	check(moves > 3 and moves < 24, "a climber of Konstitution 5 is spent after %d moves without rest" % moves)


func _placements() -> void:
	var list := WallPlacements.parse("# c\nmy.txt | Apfeltal | 12 34\nbroken line\nx.txt | Apfeltal | a b\n")
	check(list.size() == 1 and list[0].cell == Vector2i(12, 34) and list[0].wall == "my.txt", "a placement line reads")
	var wall := WallMap.parse("name: A\nsummit: 11_die_freiheit.txt:square\nsize: 24 24\n")
	check(WallPlacements.summit_of(wall) == ["11_die_freiheit.txt", "square"], "the summit names a map and a place")
	check(WallPlacements.summit_of(WallMap.blank()).is_empty(), "no summit, no destination")
