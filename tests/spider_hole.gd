extends SceneTree
## Headless test for the spider hole: its first floor crawls with spiders
## that throw webs, its way down ("^") leads to the Queen's Nest below, and
## there the Spider Queen waits with her health bar at the top. At half her
## life she calls her brood, and one stab in the back does not end her.
## Run with: godot --headless --fixed-fps 60 -s tests/spider_hole.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var queen: SpiderQueen
var spiders_before := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: spider hole")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _alive(kind: String) -> Array:
	return game.level.enemies.filter(func(e): return is_instance_valid(e) and not e.dead and e.kind == kind)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	stage_frames += 1
	match stage:
		0:
			game.hero_name = "Spider test"
			game.escaped = true
			check(game.interiors.has("loch2") and game.interiors.has("loch2b"), "the spider hole has a floor below")
			game.load_level(game.interiors["loch2"], false)
			game.state = game.State.PLAYING
			stage = 1
			stage_frames = 0
		1:
			if stage_frames < 3:
				return false
			var lvl: Level = game.level
			check(_alive("spinne").size() >= 5, "spiders crawl in the spider hole: %d" % _alive("spinne").size())
			check(Enemy.KINDS.spinne.has("web"), "they throw webs")
			check(lvl.down_to == "loch2b", "its way down leads to the nest")
			var shafts: Array = lvl.stations.filter(func(s): return s.kind == "schacht")
			check(shafts.size() == 1 and shafts[0].building == "loch2b", "there is one way down")
			game.load_level(game.interiors["loch2b"], false)
			stage = 2
			stage_frames = 0
		2:
			if stage_frames < 3:
				return false
			var lvl: Level = game.level
			check(lvl.up_to == "loch2", "the nest leads back up into the spider hole")
			check(_alive("spinne").size() >= 6, "the nest crawls with spiders: %d" % _alive("spinne").size())
			var queens := _alive("spinnenkoenigin")
			check(queens.size() == 1, "one Spider Queen waits in the nest")
			if queens.size() != 1:
				_finish()
				return true
			queen = queens[0]
			check(queen is SpiderQueen, "she fights with a script of her own")
			check(queen.is_level_boss() and Level.is_named_boss(queen), "she is a boss")
			check(lvl.get_children().any(func(c): return c is BossBar and c.boss == queen), "her health bar is there")
			check(Lang.EN.has(queen.boss_title()), "her name has its English")
			check(Factions.of("spinnenkoenigin") != "", "she belongs to a faction")
			# A stab in the back hurts, but does not fell her.
			queen.take_hit(1, queen.global_position - queen.global_transform.basis.z * 2.0, "backstab")
			check(not queen.dead, "one stab in the back does not end her")
			spiders_before = _alive("spinne").size()
			var web: float = queen._stats.web
			queen.take_hit(queen.hp - queen.max_hp() / 2, queen.global_position + Vector3(2, 0, 0), "pierce")
			check(queen.phase == 2, "at half her life she calls her brood")
			check(queen._stats.web < web, "and throws her webs quicker")
			stage = 3
			stage_frames = 0
		3:
			if stage_frames < 3:
				return false
			check(_alive("spinne").size() == spiders_before + SpiderQueen.BROOD, "her young come out of the walls: %d -> %d" % [spiders_before, _alive("spinne").size()])
			_finish()
			return true
	return false
