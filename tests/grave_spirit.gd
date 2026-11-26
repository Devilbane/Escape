extends SceneTree
## Headless test of Archy Stanton's grave and the spirit of the unknown grave next to it (see GraveSpirit): both
## stones have their inscriptions and stand side by side, apart from Owlav's and the counter stone; only at
## midnight and only by the unknown grave does a spirit rise; words that are not the answer pay nothing and the
## right ones drop the coins once for the night. The real answer is never written here: the test stands in for
## it with an entry of its own.
## Run with: godot --headless -s tests/grave_spirit.gd

const TEST_WORDS := "mock turtle soup"

var failures := 0
var game: Node
var frames := 0


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
	GraveSpirit.test_entry = {}
	if Homes.house_of(game.hero_name) > 0:
		Homes.release(Homes.house_of(game.hero_name))
	game.delete_save(game.save_path())
	print("PASS: grave spirit" if failures == 0 else "FAILED: " + str(failures))
	quit(1 if failures > 0 else 0)
	return true


func _coins(lvl: Level) -> int:
	return CoinPile.coins_in(lvl._pickups)


func _test() -> void:
	game.hero_name = "Grave spirit test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	var lvl: Outdoor = game.level
	var pair := GraveSpirit.graves_of(lvl.level_name)
	check(not pair.is_empty(), "the valley has the pair of graves")
	check(pair.archy != OwlClock.grave_cell() and pair.unknown != OwlClock.grave_cell(), "neither is Owlav's grave")
	check(pair.archy != RiddleCount.grave_of(lvl.level_name) and pair.unknown != RiddleCount.grave_of(lvl.level_name), "nor the counter stone")
	check(absi(pair.archy.x - pair.unknown.x) + absi(pair.archy.y - pair.unknown.y) <= 2, "they stand side by side")
	var stones := lvl.stations.filter(func(s): return s.kind == GraveLore.KIND)
	var archy := stones.filter(func(s): return s.cell == pair.archy)
	var unknown := stones.filter(func(s): return s.cell == pair.unknown)
	check(archy.size() == 1 and archy[0].name == "Archy Stanton" and Lang.t(archy[0].text) != "", "Archy's grave is inscribed")
	check(unknown.size() == 1 and GraveLore.card(unknown[0]).contains("Unbekannt"), "the other says only Unknown")
	check(not GraveLore.card(unknown[0]).begins_with("\n"), "with no empty name line above it")
	var spirit: GraveSpirit = lvl.grave_spirit
	check(spirit != null, "the map has the spirit's place")
	if spirit == null:
		return
	var entry := RiddleVault.make_entry(TEST_WORDS, "", 40)
	GraveSpirit.test_entry = entry
	var grave := lvl.cell_to_world(pair.unknown)
	var by := grave + Vector3(0.9, 0, 0.6)
	var far := grave + Vector3(0, 0, 30)
	var dt := 0.1
	# By day, and at night off the hour, nothing rises.
	for h in [12.0, 20.0, 23.0, 1.0, 3.0]:
		for i in 5:
			spirit.tick(dt, by, h)
		check(not spirit.is_out(), "no spirit at %.0f o'clock" % h)
	# At midnight but far from the grave.
	for i in 5:
		spirit.tick(dt, far, 0.0)
	check(not spirit.is_out(), "none rises for someone far from the grave")
	check(GraveSpirit.is_midnight(23.6) and GraveSpirit.is_midnight(0.2) and not GraveSpirit.is_midnight(1.5), "the midnight hours")
	# At midnight by the grave it rises and fades in.
	for i in 40:
		spirit.tick(dt, by, 0.0)
	check(spirit.is_out(), "the spirit rises at midnight by the unknown grave")
	var before := _coins(lvl)
	# Wrong words pay nothing.
	spirit.on_hero_spoke("a wrong guess", by)
	spirit.on_hero_spoke(GraveLore.OWLAV.name, by)
	check(spirit.is_out() and _coins(lvl) == before, "wrong words pay nothing")
	# Words said far away are not heard.
	spirit.on_hero_spoke(TEST_WORDS, far)
	check(spirit.is_out() and _coins(lvl) == before, "words said far away are not heard")
	# The right words pay.
	spirit.on_hero_spoke(TEST_WORDS.to_upper() + "!", by)
	check(not spirit.is_out(), "the answer sends the spirit away")
	check(_coins(lvl) == before + GraveSpirit.PAYS, "and drops the coins (%d)" % (_coins(lvl) - before))
	for i in 40:
		spirit.tick(dt, by, 0.0)
	check(not spirit.is_out(), "it does not come back the same night")
	# The next midnight it does.
	for i in 5:
		spirit.tick(dt, by, 12.0)
	for i in 40:
		spirit.tick(dt, by, 23.8)
	check(spirit.is_out(), "it rises again the next midnight")
	# Without a spirit out, the words pay nothing.
	for i in 5:
		spirit.tick(dt, by, 12.0)
	for i in 40:
		spirit.tick(dt, by, 12.0)
	var coins := _coins(lvl)
	spirit.on_hero_spoke(TEST_WORDS, by)
	check(_coins(lvl) == coins, "by day the words pay nothing")
	# The real answer is only ever held as a hash.
	GraveSpirit.test_entry = {}
	check(not GraveSpirit.is_answer(TEST_WORDS) and not GraveSpirit.is_answer(""), "the real entry is not the test words")
	check(GraveSpirit.ENTRY.hash.length() == 64 and not GraveSpirit.ENTRY.has("answer"), "only a hash is stored")
