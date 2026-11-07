extends SceneTree
## Headless test for the hoard and the crafting benches at home (see HomeHoard and
## HomeUpgrades): the hoard grows in 20 stages with the hero's wealth, its coins keep the ratio of the
## coins the hero holds, the benches built at home are the village's own benches (same craft, same
## window), and all of it is kept in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/home_hoard.gd

const HERO := "Home hoard test"

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


func _finish() -> void:
	game.delete_save(game.save_path())
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	print("PASS: home hoard" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _heaps(lvl: Level) -> Dictionary:
	var out := {}
	if lvl._hoard_root == null:
		return out
	for h in lvl._hoard_root.get_children():
		out[String(h.name).trim_prefix("Heap_")] = h
	return out


func _run() -> void:
	# The stages: 20 of them, rising with wealth.
	check(HomeHoard.STEPS.size() == HomeHoard.STAGES and HomeHoard.STAGES == 20, "the hoard has 20 stages")
	check(HomeHoard.stage_of(0) == 0 and HomeHoard.stage_of(1) == 1 and HomeHoard.stage_of(10 ** 7) == 20, "stages run from 0 to 20")
	var last := 0
	for i in HomeHoard.STEPS.size():
		check(HomeHoard.stage_of(HomeHoard.STEPS[i]) == i + 1, "wealth %d is stage %d" % [HomeHoard.STEPS[i], i + 1])
		check(HomeHoard.STEPS[i] > last, "the steps rise")
		last = HomeHoard.STEPS[i]
	var shown_last := 0
	for s in range(1, 21):
		check(HomeHoard.shown_at(s) > shown_last, "stage %d shows more coins than the one before" % s)
		shown_last = HomeHoard.shown_at(s)
	check(HomeHoard.shown_at(0) == 0, "stage 0 shows no coins")
	check(HomeHoard.wealth(200, 50, 0) == 200 + 50 * 25, "wealth counts every coin at its worth")

	# The mix keeps the ratio of the coins held: 200 copper to 50 silver is four to one.
	var mix := HomeHoard.mix(10, {"kupfermuenze": 200, "silbermuenze": 50, "goldmuenze": 0})
	check(mix.size() == 2 and not mix.has("goldmuenze"), "no gold, no gold heap")
	check(absi(mix["kupfermuenze"] - 4 * mix["silbermuenze"]) <= 4, "200 copper to 50 silver shows four copper for each silver")
	var big := HomeHoard.mix(20, {"kupfermuenze": 200, "silbermuenze": 50, "goldmuenze": 0})
	check(big["kupfermuenze"] == 4 * big["silbermuenze"], "the ratio is exact where the stage's coins divide evenly")
	check(mix["kupfermuenze"] + mix["silbermuenze"] == HomeHoard.shown_at(10), "the heaps add up to what the stage shows")
	for stage in range(1, 21):
		var m := HomeHoard.mix(stage, {"kupfermuenze": 7, "silbermuenze": 3, "goldmuenze": 1})
		var sum := 0
		for k in m:
			sum += m[k]
		check(m.size() == 3 and sum == maxi(HomeHoard.shown_at(stage), 3), "stage %d keeps all three metals and its total" % stage)
	check(HomeHoard.mix(0, {"kupfermuenze": 5}).is_empty() and HomeHoard.mix(5, {}).is_empty(), "no coins, no heaps")
	check(HomeHoard.mix(3, {"goldmuenze": 2}) == {"goldmuenze": HomeHoard.shown_at(3)}, "one metal fills the whole hoard")

	# At home.
	var p: Player = game.player
	game.hero_name = HERO
	game.escaped = true
	game.home_upgrades.clear()
	game.storage.clear()
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	var house := 1
	while Homes.owner_of(house) != "":
		house += 1
	Homes.claim(HERO, house)
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	var lvl: Level = game.level
	check(lvl.is_home, "the hero is in their town house")

	# Every new thing has its English, and the window keeps its size with so many upgrades.
	for id in ["feinbank", "schleifrad", "alchemie", "hort"]:
		check(HomeUpgrades.ALL.has(id) and Lang.EN.has(HomeUpgrades.ALL[id].name) and Lang.EN.has(HomeUpgrades.ALL[id].text), "%s has English texts" % id)
	check(Lang.EN.has(HomeUpgrades.LEARN), "the compendium entry has its English")

	# Build all four.
	p.bag.clear()
	for i in 30:
		p.bag.append("steinblock")
	game.coins = 500
	game.menus.open("ausbau")
	for id in ["feinbank", "schleifrad", "alchemie", "hort"]:
		game.menus._build_upgrade(id)
		check(game.home_upgrades.has(id), "%s is built" % id)
	check(game.menus.current == "ausbau", "the upgrade window stays open")
	var benches := lvl.stations.filter(func(s): return s.kind == "werkbank")
	var crafts := benches.map(func(s): return s.craft)
	check(benches.size() == 3 and "feinschmieden" in crafts and "edelsteinschleifen" in crafts and "alchemie" in crafts,
			"the three crafting benches stand in the house, each with its craft")
	for b in benches:
		check(b.get("upgrade", false), "a bench at home sits on a furniture spot")
	game.menus.bench = "alchemie"
	game.menus.open("werkbank")
	check(game.menus.current == "werkbank" and game.menus.bench == "alchemie", "a home bench opens the village bench's window")
	game.menus.close()

	# The hoard: empty plinth at first, then it follows the purse.
	check(_station_count(lvl, "hort") == 1, "the hoard is a station")
	game.coins = 0
	game._purse_key = []
	game._update_purse()
	lvl.show_hoard(game._held_coins())
	game.coins = 200
	lvl.show_hoard({"kupfermuenze": 200, "silbermuenze": 50, "goldmuenze": 0})
	var heaps := _heaps(lvl)
	check(heaps.has("kupfermuenze") and heaps.has("silbermuenze") and not heaps.has("goldmuenze"), "heaps for the metals held only")
	lvl.show_hoard({"kupfermuenze": 0, "silbermuenze": 0, "goldmuenze": 0})
	check(_heaps(lvl).is_empty(), "no coins, a bare plinth")
	lvl.show_hoard({"kupfermuenze": 100000, "silbermuenze": 3000, "goldmuenze": 400})
	check(_heaps(lvl).size() == 3, "a rich hero has all three heaps")

	# Kept in the saved game.
	check(game.save_game(), "the game saves")
	game.home_upgrades.clear()
	game._apply_save(game._read_save())
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	lvl = game.level
	check(game.home_upgrades.has("hort") and game.home_upgrades.has("feinbank"), "the upgrades are loaded again")
	check(_station_count(lvl, "hort") == 1 and lvl.stations.filter(func(s): return s.kind == "werkbank").size() == 3, "a loaded game rebuilds the hoard and the benches")
	_finish()


func _station_count(lvl: Level, kind: String) -> int:
	return lvl.stations.filter(func(s): return s.kind == kind).size()
