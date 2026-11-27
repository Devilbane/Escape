extends SceneTree
## Headless test for the rules of the hero's own mine (see MineWork): the sample as the baseline, hammer and
## fire, timbering, offline mining, the drift of the shares (mean-reverting, leaps only in valuable ores),
## hauling, the stockpile and processing.
## Run with: godot --headless -s tests/mine_work.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _sample(main: String, second := "", traces := [], anomaly := "") -> Dictionary:
	return {"cell": [10, 10], "source": "berg", "main": main, "main_pct": 70, "second": second, "second_pct": 20 if second != "" else 0,
			"trace_pct": 8, "traces": traces.map(func(t: String) -> Dictionary: return {"id": t, "pct": 8}),
			"noise": "gneis" if main != "gneis" else "basalt", "noise_pct": 2, "anomaly": anomaly, "anomaly_pct": 2 if anomaly != "" else 0}


func _mine(main: String, traces := [], anomaly := "") -> Dictionary:
	return MineWork.found("hero|n|1", Prospecting.mark_from(_sample(main, "", traces, anomaly)))


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# --- The sample is the baseline --------------------------------------------------------------
	var copper := _mine("basalt", ["malachit"])
	check(copper.shares.has("kupfer") and float(copper.shares.kupfer) > float(copper.shares.get("silber", 0.0)), "copper basalt starts with most of its ore as copper")
	check(copper.advances == 0 and copper.face == 0.0 and copper.stock.is_empty(), "a new mine is empty")
	check(copper.rock == "basalt" and not MineWork.is_hard(copper), "basalt is soft")
	var debris := MineWork.found("p", Prospecting.mark_from(_sample("sediment", "quarz")))
	check(debris.rock == "quarz" and MineWork.is_hard(debris), "under a skin of sandstone the real rock decides")
	check(MineWork.is_hard(_mine("quarz", ["rost"])) and MineWork.is_hard(_mine("gneis", ["glimmer"])), "quartz and gneiss are hard")

	# --- Hammer, fire, timbers ----------------------------------------------------------------------
	var m := _mine("basalt", ["malachit"])
	check(MineWork.advance(m, "hammer", rng).ok and m.advances == 1 and m.face == MineWork.ROCK_PER_ADVANCE, "a hammer advance breaks rock loose")
	check(MineWork.advance(m, "hammer", rng).ok, "a second advance")
	check(MineWork.needs_support(m) and not MineWork.advance(m, "hammer", rng).ok, "after %d advances a support is needed" % MineWork.SPAN)
	check(MineWork.why_not(m, "hammer") != "", "the hero is told why")
	check(MineWork.support(m) and not MineWork.needs_support(m), "a support lets the tunnel go on")
	check(not MineWork.support(m), "no support is set where none is needed")
	var hard := _mine("quarz", ["rost"])
	check(not MineWork.advance(hard, "hammer", rng).ok and MineWork.why_not(hard, "hammer").contains("hart"), "hard rock refuses hammer and chisel with a warning")
	check(MineWork.advance(hard, "fire", rng).ok and hard.fires == 1 and hard.advances == 1, "a blast of fire-setting is an advance")

	# --- Offline mining ------------------------------------------------------------------------------
	var off := _mine("basalt", ["malachit"])
	check(MineWork.offline_advances(off, 3.0) == 0, "under 4 hours nothing is done")
	check(MineWork.offline_advances(off, 4.0) == 1, "4 hours: one advance (25 %)")
	check(MineWork.offline_advances(off, 8.0) == 1, "8 hours away is still one day: at most 4 hours count")
	check(MineWork.offline_advances(off, 48.0) == 2, "two days away: two advances")
	check(MineWork.offline_advances(hard, 100.0) == 0, "hard rock is not mined while away")
	check(MineWork.catch_up(off, 100.0, rng) == 2, "the tunnel stops at the unpropped span (%d)" % off.advances)
	check(off.advances == MineWork.SPAN and MineWork.needs_support(off), "and waits for its support")

	# --- The drift of the shares -----------------------------------------------------------------------
	check(MineWork.p_up(0.05) > MineWork.p_up(0.3) and MineWork.p_up(0.3) > MineWork.p_up(0.55), "the higher the share, the less likely it rises")
	var last := 0.0
	for s in [0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.58]:
		var ratio := (1.0 - MineWork.p_up(s)) / MineWork.p_up(s)
		check(ratio > last, "stay-or-fall against rise grows with the share (%.2f: %.2f)" % [s, ratio])
		last = ratio
	# Many mines: a rich face (0.28) ends lower on average, a poor one (0.08) higher, and nothing passes the cap.
	var rich_sum := 0.0
	var poor_sum := 0.0
	var over := 0
	var sims := 200
	for i in sims:
		var r := {"shares": {"kupfer": 0.28}}
		var p := {"shares": {"kupfer": 0.04}}
		for step in 40:
			MineWork.drift(r, rng)
			MineWork.drift(p, rng)
		rich_sum += float(r.shares.kupfer)
		poor_sum += float(p.shares.kupfer)
		if float(r.shares.kupfer) > MineWork.CAP + 0.0001:
			over += 1
	check(over == 0, "no share passes the cap")
	check(rich_sum / sims < 0.28, "a rich face pulls back (mean %.3f)" % (rich_sum / sims))
	check(poor_sum / sims > 0.04, "a poor face recovers (mean %.3f)" % (poor_sum / sims))
	# Leaps: only valuable ores, very rare.
	var leaps_gold := 0
	var leaps_iron := 0
	for i in 20000:
		var a := {"shares": {"gold": 0.1, "eisen": 0.1}}
		MineWork.drift(a, rng)
		if float(a.shares.gold) > 0.1 * (1.0 + MineWork.STEP_MAX) + 0.0001:
			leaps_gold += 1
		if float(a.shares.eisen) > 0.1 * (1.0 + MineWork.STEP_MAX) + 0.0001:
			leaps_iron += 1
	check(leaps_iron == 0, "iron never leaps")
	check(leaps_gold > 0 and leaps_gold < 20000 * 0.05, "gold leaps now and then, very rarely (%d of 20000)" % leaps_gold)

	# --- Hauling, the stockpile, processing ----------------------------------------------------------
	var h := _mine("basalt", ["malachit"])
	MineWork.advance(h, "hammer", rng)
	check(is_equal_approx(MineWork.haul(h, MineWork.BUCKET_LOAD), MineWork.BUCKET_LOAD) and is_equal_approx(float(h.face), MineWork.ROCK_PER_ADVANCE - MineWork.BUCKET_LOAD), "a bucket trip carries its load")
	check(is_equal_approx(MineWork.haul(h, MineWork.CART_LOAD), MineWork.ROCK_PER_ADVANCE - MineWork.BUCKET_LOAD) and float(h.face) == 0.0, "a cart takes what is left")
	check(MineWork.haul(h, MineWork.CART_LOAD) == 0.0, "nothing is hauled from an empty face")
	check(is_equal_approx(float(h.stock_mass), MineWork.ROCK_PER_ADVANCE), "the stockpile holds all the hauled rock")
	var total := 0.0
	for ore: String in h.stock:
		total += float(h.stock[ore])
	check(total <= float(h.stock_mass) + 0.0001, "component masses never exceed the rock")
	# Two loads add up component by component.
	var before: float = float(h.stock.get("kupfer", 0.0))
	MineWork.advance(h, "hammer", rng)
	MineWork.haul(h, MineWork.CART_LOAD)
	check(float(h.stock.kupfer) > before and is_equal_approx(float(h.stock_mass), 2.0 * MineWork.ROCK_PER_ADVANCE), "stockpile masses add up across loads")
	check(not MineWork.stock_shares(h).is_empty() and float(MineWork.stock_shares(h).kupfer) <= MineWork.CAP + 0.0001, "the stockpile has shares")
	var rich := {"stock": {"kupfer": 20.0, "gold": 0.5}, "stock_mass": 100.0}
	var ore := MineWork.process(rich)
	check(ore.get("kupfer", 0) == 17 and not ore.has("gold") and rich.stock.is_empty() and float(rich.stock_mass) == 0.0, "washing keeps 85 %% of the whole units and empties the pile (%s)" % str(ore))

	# --- English -----------------------------------------------------------------------------------------
	for key in ["Der Stollen ist nicht abgestützt: Setz erst einen Stützbalken.", "Das Gestein ist zu hart für Schlägel und Eisen. Setz das Feuer an und lösche es mit Wasser."]:
		check(Lang.EN.has(key), "English for: " + key.substr(0, 40))
	if failures == 0:
		print("PASS: mine work")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
