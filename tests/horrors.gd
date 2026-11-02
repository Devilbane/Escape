extends SceneTree
## Headless test for the creepy holes, the hand torch and the nameless
## horrors: three dark holes lie in the wild, each with a way to it and a
## pitch-black cave below. Down there no torch burns on the walls and the
## hero sees hardly past their own tile, until a hand torch from the bag
## lights itself. The horror in its den is revealed with "???" on its bar,
## and once it has fallen it is discovered: named, and in the compendium.
## Back in the open the torch goes out and the lantern shines again.
## Run with: godot --headless --fixed-fps 60 -s tests/horrors.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var horror: Enemy


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	Engine.time_scale = 1.0
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: holes, torch and horrors")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _next() -> void:
	stage += 1
	stage_frames = 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if game.player:
		game.player.hp = game.player.max_hp
	stage_frames += 1
	match stage:
		0:
			game.hero_name = "Horror test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			var lvl: Outdoor = game.level
			check(lvl.holes.size() == 3, "three dark holes lie in the wild (%d)" % lvl.holes.size())
			for n in range(1, 4):
				var id := "loch%d" % n
				check(game.interiors.has(id), "hole %d leads down to a floor of its own" % n)
				check(lvl.stations.any(func(s): return s.kind == "eingang" and s.building == id), "running into hole %d climbs down" % n)
				var way: Array = lvl.astar.get_id_path(lvl.start_cell, lvl.world_to_cell(lvl.doors[id]))
				check(not way.is_empty(), "a way leads from the graveyard to hole %d" % n)
			game.player.bag.erase(HandTorch.ITEM)
			game.player.global_position = lvl.doors["loch1"]
			game.go_inside("loch1")
			_next()
		1:
			if stage_frames < 60:
				return false
			var lvl: Level = game.level
			check(lvl.building == "loch1" and lvl.pitch_dark and not lvl.safe, "the hole leads into a dark, unsafe cave (%s)" % lvl.level_name)
			check(lvl._torches.is_empty(), "no torch burns on the walls down there")
			check(not game.player.torch.lit, "without a torch in the bag none burns")
			var here := lvl.world_to_cell(game.player.global_position)
			check(lvl.fog.is_cell_visible(here), "the hero still sees the own tile")
			check(not lvl.fog.is_cell_visible(here + Vector2i(2, 1)), "but nothing two tiles away")
			game.player.bag.append(HandTorch.ITEM)
			game.player.bag.append(HandTorch.ITEM)
			_next()
		2:
			if stage_frames < 30:
				return false
			var lvl: Level = game.level
			var torch: HandTorch = game.player.torch
			check(torch.lit and torch.left > 0.0, "a torch from the bag lights itself in the dark")
			check(torch.spare() == 1, "it is taken from the bag (%d left)" % torch.spare())
			check(game.player.is_lit(), "a burning torch cannot be hooded")
			check(torch.light_reach() > HandTorch.DARK_REACH, "the torch lets the hero see a little farther")
			var den := Vector2i(-1, -1)
			for y in lvl.height:
				var x: int = lvl.grid[y].find("X")
				if x >= 0:
					den = Vector2i(x, y)
			check(den.x >= 0, "the cave has a horror's den")
			for e in lvl.enemies:
				if is_instance_valid(e) and e.is_horror():
					horror = e
			if horror == null:
				horror = lvl._spawn_enemy(lvl.horror_kind, den)
			check(horror.kind == "schlund", "the Maw lurks below the graveyard")
			check(not game.horrors.known(horror.kind), "nobody knows yet what it is")
			game.player.global_position = lvl.cell_to_world(den + Vector2i(1, 0))
			_next()
		3:
			if stage_frames < 40:
				return false
			check(game.horrors._seen.has(horror), "the first sight of it is a reveal")
			check(game.horrors.title_of(horror.kind) == Horrors.UNKNOWN, "its bar says ???")
			check(game.horrors._shown == horror, "its bar shows")
			horror.take_hit(999, game.player.global_position)
			_next()
		4:
			if stage_frames < 30:
				return false
			check(game.horrors.known(horror.kind), "the fallen horror is discovered")
			check(game.lore.has(Horrors.INFO[horror.kind].lore), "and written into the compendium")
			check(game.horrors.title_of(horror.kind) != Horrors.UNKNOWN, "from now on it has a name")
			check(Engine.time_scale == 1.0, "time runs normally again")
			game._leave_building()
			_next()
		5:
			if stage_frames < 30:
				return false
			check(game.level is Outdoor, "the stairs lead back out of the hole")
			check(not game.player.torch.lit, "in the open the torch goes out")
			check(is_equal_approx(game.player._lantern.light_energy, 1.1), "and the lantern shines as before")
			_finish()
			return true
	return false
