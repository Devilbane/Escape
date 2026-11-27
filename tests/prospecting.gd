extends SceneTree
## Headless test for prospecting (see Prospecting, ProspectGeology, Prospector):
## - the samples follow the geology rules: shares that add up, only the allowed mixes, noise and anomalies in
##   their limits, the same spot always the same sample, fantasy ores only with their anomaly;
## - every trace points to its ore, and pyrite (fool's gold) does not;
## - the Crown Prospector stands by the Crown Office and sells the bucket; the bucket is taken in hand, takes a
##   ground sample and a mountain sample (after the question), is handed in, and the result is a mark on the
##   map with a stake in the world; a saved game keeps all of it;
## - every text the feature shows has English.
## Run with: godot --headless --fixed-fps 60 -s tests/prospecting.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames >= 5 and not started and "state" in game:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## A handmade sample: main rock, optional second, traces and an anomaly.
func _made(main: String, second := "", traces := [], anomaly := "") -> Dictionary:
	return {"cell": [10, 10], "source": "berg", "main": main, "main_pct": 70, "second": second, "second_pct": 20 if second != "" else 0,
			"trace_pct": 8, "traces": traces.map(func(t: String) -> Dictionary: return {"id": t, "pct": 8}),
			"noise": "gneis" if main != "gneis" else "basalt", "noise_pct": 2, "anomaly": anomaly, "anomaly_pct": 2 if anomaly != "" else 0}


func _geology() -> void:
	var fantasy_without := 0
	var seen_second := {}
	var anomalies := 0
	var decoys := 0
	var same := true
	for x in range(0, 540, 4):
		for y in range(0, 300, 4):
			for src in [ProspectGeology.GROUND, ProspectGeology.MOUNTAIN]:
				var s := ProspectGeology.sample(Vector2i(x, y), src)
				var total: int = s.main_pct + s.second_pct + s.trace_pct + s.noise_pct + s.anomaly_pct
				check(total == 100, "the shares add up to 100 (%d at %d,%d)" % [total, x, y])
				check(s.main_pct >= 50 and s.main_pct <= 85, "the main rock is 50 to 85 %% (%d)" % s.main_pct)
				check(s.trace_pct >= 5 and s.trace_pct <= 15, "trace elements are 5 to 15 %% (%d)" % s.trace_pct)
				check(s.noise_pct >= 1 and s.noise_pct <= 5, "noise is 1 to 5 %% (%d)" % s.noise_pct)
				check(s.anomaly_pct == 0 or (s.anomaly_pct >= 1 and s.anomaly_pct <= 3), "an anomaly is 1 to 3 %%")
				check(ProspectGeology.ROCKS.has(s.noise) and s.noise != s.main and s.noise != s.second, "the noise is a third rock")
				if s.second != "":
					check(s.second_pct >= 15 and s.second_pct <= 40, "the secondary rock is 15 to 40 %% (%d)" % s.second_pct)
					check(ProspectGeology.can_mix(s.main, s.second), "only allowed mixes: %s + %s" % [s.main, s.second])
					seen_second["%s+%s" % [s.main, s.second]] = true
				else:
					check(s.second_pct == 0, "no secondary rock, no share")
				var trace_sum := 0
				for t: Dictionary in s.traces:
					trace_sum += int(t.pct)
				check(s.traces.is_empty() or trace_sum == s.trace_pct, "the traces make up the trace share")
				if s.anomaly != "":
					anomalies += 1
					var rocks: Array = ProspectGeology.ANOMALIES[s.anomaly].rocks
					check(rocks.has(s.main) or rocks.has(s.second), "an anomaly sits in a rock that carries it")
				for t: Dictionary in s.traces:
					if t.id == ProspectGeology.DECOY:
						decoys += 1
				var a := ProspectGeology.analyse(s)
				if a.ore in ["aether", "mithril"] and s.anomaly == "":
					fantasy_without += 1
				if src == ProspectGeology.GROUND and (x + y) % 40 == 0:
					same = same and ProspectGeology.sample(Vector2i(x, y), src) == s and ProspectGeology.analyse(s) == a
	check(fantasy_without == 0, "a fantasy ore never comes without its anomaly")
	check(same, "the same spot always gives the same sample and answer")
	check(anomalies > 50, "anomalies turn up now and then (%d)" % anomalies)
	check(decoys > 50, "fool's gold turns up now and then (%d)" % decoys)
	check(seen_second.size() >= 3, "the allowed mixes turn up (%s)" % str(seen_second.keys()))
	# The blocked pairs.
	check(not ProspectGeology.can_mix("kimberlit", "basalt") and not ProspectGeology.can_mix("basalt", "kimberlit"), "kimberlite and basalt never mix")
	check(ProspectGeology.can_mix("gneis", "quarz") and ProspectGeology.can_mix("quarz", "gneis"), "gneiss and quartz mix")
	check(ProspectGeology.can_mix("basalt", "quarz"), "basalt and quartz mix")
	check(ProspectGeology.can_mix("kimberlit", "gneis") and ProspectGeology.can_mix("kimberlit", "sediment"), "kimberlite breaks through gneiss and sandstone")
	check(ProspectGeology.can_mix("sediment", "basalt") and ProspectGeology.can_mix("quarz", "sediment"), "sandstone mixes with any rock")
	check(not ProspectGeology.can_mix("quarz", "kimberlit") and not ProspectGeology.can_mix("gneis", "basalt") and not ProspectGeology.can_mix("gneis", "gneis"), "no other mix")
	# The ground is weathered, the mountain fresh: a ground sample carries sandstone debris more often.
	var debris := 0
	var rock_debris := 0
	for x in range(0, 400, 5):
		for y in range(0, 200, 5):
			if ProspectGeology.sample(Vector2i(x, y), "boden").second == "sediment":
				debris += 1
			if ProspectGeology.sample(Vector2i(x, y), "berg").second == "sediment":
				rock_debris += 1
	check(debris > rock_debris, "open ground carries more weathered sandstone than the mountain (%d vs %d)" % [debris, rock_debris])


func _indicators() -> void:
	var cases := [
		["sedimentary iron", _made("sediment", "", ["rost"]), "eisen"],
		["copper in basalt", _made("basalt", "", ["malachit"]), "kupfer"],
		["silver in quartz", _made("quarz", "", ["bleiglanz"]), "silber"],
		["gold in quartz", _made("quarz", "", ["rost"]), "gold"],
		["gems in gneiss", _made("gneis", "", ["glimmer"]), "edelstein"],
		["diamond in kimberlite", _made("kimberlit", "", ["olivin"]), "diamant"],
		["aether quartz by its glow", _made("gneis", "", [], "resonanz"), "aether"],
		["mithril by stardust", _made("kimberlit", "", [], "sternenstaub"), "mithril"],
		["mithril in basalt by stardust", _made("basalt", "", [], "sternenstaub"), "mithril"],
	]
	for c in cases:
		var a := ProspectGeology.analyse(c[1])
		check(a.ore == c[2], "%s: %s (got %s)" % [c[0], c[2], a.ore])
	# Pyrite looks like gold but is not: gold in quartz turns to iron, and the prospector warns.
	var fool := ProspectGeology.analyse(_made("quarz", "", ["pyrit"]))
	var real := ProspectGeology.analyse(_made("quarz", "", ["rost"]))
	check(fool.warn == "pyrit" and real.warn == "", "pyrite is flagged as fool's gold")
	check(fool.ore != "gold", "fool's gold does not point to gold (%s)" % fool.ore)
	# Sandstone over another rock: the real rock lies deeper.
	var deeper := ProspectGeology.analyse(_made("sediment", "basalt", ["malachit"]))
	check(deeper.deeper and deeper.ore == "kupfer", "debris on basalt: copper, deeper (%s)" % str(deeper))
	# A diamond pipe through gneiss is richer in diamonds than plain kimberlite.
	var pipe := ProspectGeology.odds(_made("kimberlit", "gneis"))
	var plain := ProspectGeology.odds(_made("kimberlit"))
	check(float(pipe["diamant"]) > float(plain["diamant"]) * 0.7 * 1.5, "a diamond pipe is richer than plain kimberlite")
	# What the window and the legend say.
	check(Prospecting.report_text(real).begins_with("Gold"), "the report names the ore")
	check(Prospecting.composition_text(_made("basalt", "quarz", ["malachit"])).contains("Basalt 70 %"), "the composition names the shares")


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Prospecting test"
	game.coins = 100
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level
	var p: Prospecting = game.prospecting

	_geology()
	_indicators()

	# --- The man -------------------------------------------------------------------------------
	var man: Villager = null
	var clerk: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == Prospector.ROLE:
			man = v
		if v.role == "¢":
			clerk = v
	check(man != null, "the Crown Prospector stands in the village")
	check(man != null and man.station.kind == Prospector.KIND, "his station opens the prospector's window")
	check(man != null and clerk != null and man.global_position.distance_to(clerk.global_position) < 20.0, "he stands by the Crown Office (%.1f)" % (man.global_position.distance_to(clerk.global_position) if man and clerk else -1.0))
	check(Villager.ROLES.has(Prospector.ROLE) and Menus.fixed_size(Prospector.KIND) != Vector2.ZERO, "his window has its fixed size")

	# --- The bucket ----------------------------------------------------------------------------
	check(Items.ALL.has(Prospecting.BUCKET) and Items.ALL.has(Prospecting.FULL), "the bucket is an item, empty and full")
	check(p.toggle() != "" and not p.held, "without a bucket it cannot be taken in hand")
	game.coins = 10
	check(p.buy() != "" and not p.has_bucket(), "without the copper no bucket is sold")
	game.coins = 100
	game.trader_role = Prospector.ROLE
	game.menus.open(Prospector.KIND)
	await _wait(2)
	check(game.menus.current == Prospector.KIND, "the window opens")
	Prospector._buy(game.menus)
	check(p.has_bucket() and not p.is_full(), "the hero buys an empty bucket")
	check(game.coins == 100 - Prospecting.PRICE, "and pays for it")
	check(p.buy() != "", "a second bucket is not sold")
	game.menus.close()
	game.state = game.State.PLAYING

	# --- A ground sample -------------------------------------------------------------------------
	check(p.dig_here() != "" and not p.is_full(), "no sample while the bucket is not in hand")
	check(p.toggle() != "" and p.held, "the bucket is taken in hand")
	check(p.ready(), "an empty bucket in hand is ready")
	var spot := lvl.world_to_cell(game.player.global_position)
	var here := ProspectGeology.sample(spot, "boden")
	var why := p.dig_here()
	check(why == "", "the sample is taken (%s)" % why)
	check(p.digging, "the hero digs a moment")
	await create_timer(Prospecting.DIG_TIME + 0.3).timeout
	check(not p.digging and p.is_full(), "the bucket is full afterwards")
	check(game.player.bag.has(Prospecting.FULL) and not game.player.bag.has(Prospecting.BUCKET), "the bag holds the full bucket")
	check(p.sample.main == here.main and p.sample.main_pct == here.main_pct, "the sample is the one of the spot")
	check(p.dig_here() != "", "a full bucket takes no second sample")

	# --- Handing it in -----------------------------------------------------------------------------
	game.menus.open(Prospector.KIND)
	await _wait(2)
	Prospector._deliver(game.menus)
	check(not p.is_full() and p.analysing() and p.marks.is_empty(), "the sample is being analysed, no mark yet")
	check(absf(p.analysis_left() - Prospecting.ANALYSIS_SECONDS) < 5.0, "the analysis takes one real day")
	check(game.player.bag.has(Prospecting.BUCKET) and not game.player.bag.has(Prospecting.FULL), "the bucket is empty again")
	# While he analyses, he takes no other sample.
	game.player.bag[game.player.bag.find(Prospecting.BUCKET)] = Prospecting.FULL
	p.sample = ProspectGeology.sample(spot + Vector2i(5, 5), "boden")
	check(p.deliver().is_empty() and p.sample.has("main"), "no second sample while one is analysed")
	game.player.bag[game.player.bag.find(Prospecting.FULL)] = Prospecting.BUCKET
	p.sample = {}
	# A saved game keeps the analysis and its time.
	var kept := Prospecting.new(game)
	kept.load_from(p.for_save())
	check(kept.analysing() and absf(kept.analysis_left() - p.analysis_left()) < 1.0, "a saved game keeps the analysis running")
	p.tick()
	check(p.marks.is_empty(), "the result is not ready before the day is over")
	p.analysis.due = Time.get_unix_time_from_system() - 1.0
	p.tick()
	check(not p.analysing() and p.marks.size() == 1, "after the day the result leaves a mark")
	var mark: Dictionary = p.marks[0]
	check(mark.cell == [spot.x, spot.y] and mark.source == "boden" and mark.file == game.journal.current_file(), "the mark is at the spot")
	check(mark.report == ProspectGeology.analyse(here), "with the prospector's report")
	game.menus.close()
	game.state = game.State.PLAYING
	check(lvl.get_tree().get_nodes_in_group("prospect_stakes").size() == 1, "a stake marks the spot in the world")
	check(game.journal.prospect_marks(game.journal.current_file()).size() == 1, "the map knows the mark")
	# The map window builds with the mark: the legend names it.
	game.menus.open("karte")
	await _wait(3)
	check(game.menus.current == "karte", "the map opens with a mark on it")
	game.menus.close()
	game.state = game.State.PLAYING

	# --- A mountain sample ---------------------------------------------------------------------------
	game.player.hp = 999 # a wandering beast must not kill the hero and spill the bag
	var rock := _rock_edge(lvl)
	check(rock.size() == 2, "the map has a mountain tile beside open ground")
	if rock.size() == 2:
		var rock_cell: Vector2i = rock[0]
		var floor_cell: Vector2i = rock[1]
		game.player.global_position = lvl.cell_to_world(floor_cell)
		await _wait(3)
		check(p.ready(), "the empty bucket is in hand again")
		var plain := lvl.cell_to_world(floor_cell)
		check(not p.bumped(plain), "running into open ground asks nothing")
		check(p.bumped(lvl.cell_to_world(rock_cell)), "running into the mountain asks for a sample")
		await _wait(2)
		check(game.menus.current == Prospecting.ASK_KIND, "the question is a window")
		game.menus.close()
		game.state = game.State.PLAYING
		check(p.bumped(lvl.cell_to_world(rock_cell)), "straight after saying no the question stays quiet")
		check(game.menus.current != Prospecting.ASK_KIND, "no second question at once")
		p.pending_cell = rock_cell
		p.accept()
		await create_timer(Prospecting.DIG_TIME + 0.3).timeout
		check(p.is_full() and p.sample.source == "berg" and p.sample.cell == [rock_cell.x, rock_cell.y], "yes fills the bucket with mountain rock")
		var full_list := Prospecting.mark_from(p.sample)
		check(full_list.report.ore != "" or full_list.report.chance == "spur", "the mountain sample can be analysed")

	# --- Saving ------------------------------------------------------------------------------------------
	var saved := p.for_save()
	var json = JSON.parse_string(JSON.stringify(saved))
	var again := Prospecting.new(game)
	again.load_from(json)
	check(again.held == p.held and again.marks.size() == p.marks.size(), "a saved game keeps the bucket and the marks")
	check(again.sample == p.sample or again.sample.main == p.sample.main, "and the sample in it")
	if not again.marks.is_empty():
		check(again.marks[0].report == p.marks[0].report and again.marks[0].cell == p.marks[0].cell, "the marks read back whole")
	p.clear()
	check(p.marks.is_empty() and not p.held and p.sample.is_empty(), "a new game starts clean")
	again._drop_model()

	# --- English -------------------------------------------------------------------------------------------
	var keys: Array = [Villager.ROLES[Prospector.ROLE].name, "Kronprospektor", Prospecting.LEARN, Items.ALL[Prospecting.BUCKET].name, Items.ALL[Prospecting.FULL].name,
			Items.ALL[Prospecting.BUCKET].effect, Items.ALL[Prospecting.FULL].effect]
	for r: String in ProspectGeology.ROCKS:
		keys.append(ProspectGeology.ROCK_NAMES[r])
	for o: String in ProspectGeology.ORES:
		keys.append(ProspectGeology.ORES[o])
	for t: String in ProspectGeology.TRACES:
		keys.append(ProspectGeology.TRACES[t].name)
	for a: String in ProspectGeology.ANOMALIES:
		keys.append(ProspectGeology.ANOMALIES[a].name)
	keys.append_array([ProspectGeology.DECOY_NAME, "Staub und Sand"])
	keys.append_array(Prospecting.CHANCE_TEXT.values())
	keys.append_array(Prospecting.RICH_TEXT.values())
	# --- The mining licence ------------------------------------------------------------------------
	var scree := Rect2i()
	for y in range(lvl.height - 2):
		for x in range(lvl.grid[y].length() - 2):
			var r := Rect2i(x, y, 2, 2)
			if scree.size == Vector2i.ZERO and Plots.problem(lvl, r, Plots.MINING) == "":
				scree = r
	check(scree.size != Vector2i.ZERO, "there is scree for a licence")
	Plots.release(game.hero_name)
	var licensed := Prospecting.mark_from(_made("basalt", "", ["malachit"]))
	licensed.cell = [scree.position.x, scree.position.y]
	licensed["day"] = 1
	var barren := licensed.duplicate(true)
	barren.report = {"ore": "", "chance": "spur", "richness": "arm", "also": "", "warn": "", "deeper": false}
	p.marks = [licensed]
	check(p.licence_state(licensed) == "offer", "a good mark near scree gets an offer")
	check(p.licence_state(barren) == "barren", "barren rock gets no offer")
	var far := licensed.duplicate(true)
	far.cell = [1, 1]
	check(p.licence_state(far) == "none", "no scree near the spot, no licence")
	var price := p.licence_price(licensed)
	check(price == Plots.fee(Prospecting.licence_rect(lvl, licensed)) * Prospecting.LICENCE_FACTOR, "the licence costs the deed's fee times the factor")
	game.coins = 0
	check(p.buy_licence(licensed) != "" and Plots.plots_of(game.hero_name).is_empty(), "without the copper there is no licence")
	game.coins = 100000
	game.player.bag.erase(Prospecting.FULL)
	game.player.bag.erase(Prospecting.BUCKET)
	game.trader_role = Prospector.ROLE
	game.menus.open(Prospector.KIND)
	Prospector._licence(game.menus, licensed)
	var deeds := Plots.plots_of(game.hero_name)
	check(deeds.size() == 1 and deeds[0].kind == Plots.MINING, "the licence is a mining plot deed in the register")
	check(p.licence_state(licensed) == "owned", "the mark now shows the licence as owned")
	check(p.buy_licence(licensed) != "" and Plots.plots_of(game.hero_name).size() == 1, "no second licence for the same spot")
	check(PropertyRegister.rows(Plots.MINING, game.hero_name, lvl).size() == 1, "the register lists the mining plot")
	Prospector._show(game.menus, 0)
	check(game.menus.current == Prospector.KIND, "the window shows the chosen mark")
	game.menus.close()
	Plots.release(game.hero_name)

	for key in keys:
		check(Lang.EN.has(key), "English for: " + String(key).substr(0, 40))
	for line: String in Villager.ROLES[Prospector.ROLE].lines:
		check(Lang.EN.has(line), "English for his line: " + line.substr(0, 40))
	_end()


## A mountain tile beside walkable ground: [rock cell, floor cell], or [].
func _rock_edge(lvl: Outdoor) -> Array:
	for y in range(2, lvl.height - 2):
		for x in range(2, lvl.width - 2):
			var c := Vector2i(x, y)
			if Mountains.is_rock(lvl, c) and lvl.cell_char(c) == "=":
				var f := c + Vector2i(-1, 0)
				if lvl.cell_char(f) in [".", ","] and lvl.is_open(f):
					return [c, f]
	return []


func _end() -> void:
	if failures == 0:
		print("PASS: prospecting")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
