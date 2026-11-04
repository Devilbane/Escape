extends SceneTree
## Headless test for the rare loot of named bosses: the bandit chief, the
## dragon, the Mountain King and monsters named in the map workshop hold a
## small chance (Level.BOSS_RARE_CHANCE) to drop a piece of gear that is rare
## or better. Plain monsters never do, and the rare loot still never repeats
## on one level.
## Run with: godot --headless -s tests/boss_loot.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test_who()
	_test_chance()
	_test_rarity()
	_test_no_repeats()
	if failures == 0:
		print("PASS: boss loot")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _enemy(kind: String, custom := {}) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.custom = custom
	return e


## Which enemies count as named bosses.
func _test_who() -> void:
	for kind in ["hauptmann", "drache", "bergkoenig", "spinnenkoenigin"]:
		var e := _enemy(kind)
		check(Level.is_named_boss(e), "%s is a named boss" % kind)
		e.free()
	var named := _enemy("krieger", {"title": "Knochenfürst"})
	check(Level.is_named_boss(named), "a monster named in the map workshop is a named boss")
	named.free()
	for kind in ["krieger", "halsabschneider", "wolf", "hohle_mutter"]:
		var e := _enemy(kind)
		check(not Level.is_named_boss(e), "%s is not a named boss" % kind)
		e.free()


## The chance is small, a miss drops nothing, and a plain monster never drops.
func _test_chance() -> void:
	check(Level.BOSS_RARE_CHANCE > 0.0 and Level.BOSS_RARE_CHANCE <= 0.15, "the boss loot chance is small")
	var lvl := Level.new()
	var chief := _enemy("hauptmann")
	check(lvl.roll_boss_loot(chief, Level.BOSS_RARE_CHANCE + 0.01) == "", "a missed roll drops nothing")
	check(lvl.roll_boss_loot(chief, 0.0) != "", "a lucky roll drops something")
	var plain := _enemy("krieger")
	check(lvl.roll_boss_loot(plain, 0.0) == "", "a plain monster never drops boss loot")
	# The beginner dungeon's loot is common only: no bonus drop there.
	lvl.beginner_dungeon = true
	check(lvl.roll_boss_loot(chief, 0.0) == "", "no boss loot in the beginner dungeon")
	lvl.beginner_dungeon = false
	plain.free()
	chief.free()
	lvl.free()


## Whatever drops is rare or better, on shallow and deep levels alike.
func _test_rarity() -> void:
	for depth in [0, 3, 6, 9]:
		var lvl := Level.new()
		lvl.depth = depth
		for kind in ["hauptmann", "drache", "bergkoenig", "spinnenkoenigin"]:
			var e := _enemy(kind)
			var id := lvl.roll_boss_loot(e, 0.0)
			check(Items.ALL.has(id), "%s on depth %d drops real gear" % [kind, depth])
			if Items.ALL.has(id):
				check(Level.tier_of(id) in ["selten", "episch", "gottgeboren"], "%s is rare or better" % id)
			e.free()
		lvl.free()
	check(Level.tier_of("schwert") == "normal", "a plain sword is common")


## Boss loot follows the same rule as chests: no fine piece twice on a level,
## not even when it already lies in a chest there.
func _test_no_repeats() -> void:
	var lvl := Level.new()
	lvl.depth = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var seen := {}
	var chest := lvl.loot_item(rng, Level.tier_rank("selten"), HeroLevel.place_level(lvl))
	seen[chest] = true
	var boss := _enemy("bergkoenig", {"title": "Prüfung"})
	for i in 8:
		var id := lvl.roll_boss_loot(boss, 0.0)
		check(not seen.has(id), "%s repeats on one level" % id)
		seen[id] = true
	boss.free()
	lvl.free()
