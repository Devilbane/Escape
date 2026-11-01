extends SceneTree
## Headless test for the fox companion: a hero with sausages wins a wild fox
## over (it comes up and eats instead of bolting), after three sausages it
## follows the hero, digs up a hidden ingredient for them, stays theirs in
## the saved game and comes along down into the dungeon.
## Run with: godot --headless --fixed-fps 60 -s tests/fox.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var fox: Animal
var foxes_before := 0
var find_cell := Vector2i.ZERO


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path(game.hero_name))
	if failures == 0:
		print("PASS: fox")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Puts the hero `gap` metres from a spot, on open ground.
func _hero_near(lvl: Level, pos: Vector3, gap: float) -> void:
	var player: Player = game.player
	for i in 16:
		var dir := Vector3(sin(i * TAU / 16.0), 0, cos(i * TAU / 16.0))
		var p := pos + dir * gap
		if lvl.is_open(lvl.world_to_cell(p)):
			player.global_position = p
			player.velocity = Vector3.ZERO
			return
	player.global_position = pos + Vector3(gap, 0, 0)


func _foxes(lvl: Outdoor) -> int:
	return lvl.animals.filter(func(a): return a.kind == "fuchs").size()


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var lvl = game.level
	stage_frames += 1
	match stage:
		0:
			game.hero_name = "Fox test"
			game.escaped = true
			game.fox_trust = 0
			game.has_fox = false
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			lvl = game.level
			check(game.pet == null, "no fox goes with a new hero")
			check(lvl.hidden_finds.size() == Level.HIDDEN_OUTDOORS, "ingredients lie hidden in the open air (%d)" % lvl.hidden_finds.size())
			for f in lvl.hidden_finds:
				check(Items.is_ingredient(f.id) and Items.ALL[f.id].found == "outdoor", "%s grows in the open air" % f.id)
				check(lvl.is_open(f.cell), "a hidden ingredient lies on open ground")
				check(Lang.EN.has(Items.ALL[f.id].name), "%s has an English name" % f.id)
			check(Lang.EN.has(Items.ALL[Pet.FOOD].name) and Lang.EN.has(Items.ALL[Pet.FOOD].effect), "the sausage has an English text")
			check(Lang.EN.has(game.FOX_LEARN), "the compendium entry has an English text")
			# The shopkeeper always has sausages.
			game.menus.open("haendler")
			check(game.shop_stock.count(Pet.FOOD) >= 2, "the merchant sells sausages")
			game.menus.close()
			foxes_before = _foxes(lvl)
			fox = lvl.animals.filter(func(a): return a.kind == "fuchs")[0]
			game.player.bag.clear()
			for i in Pet.TRUST_NEEDED:
				game.player.bag.append(Pet.FOOD)
			check(fox.is_curious(), "a fox is curious about a hero with a sausage")
			_hero_near(lvl, fox.global_position, 6.0)
			stage_frames = 0
			stage = 1
		1:
			# The fox comes for the sausages instead of bolting.
			if is_instance_valid(fox):
				check(not fox.is_fleeing(), "the fox does not bolt from a hero with a sausage")
			if stage_frames == 60 and is_instance_valid(fox):
				check(fox.state in ["approach", "eat"], "the fox comes up to the hero (%s)" % fox.state)
			if not game.has_fox and stage_frames < 1200:
				return false
			check(game.fox_trust == Pet.TRUST_NEEDED, "the fox ate three sausages (%d)" % game.fox_trust)
			check(not game.player.bag.has(Pet.FOOD), "the sausages are gone from the bag")
			check(game.has_fox and game.pet != null and is_instance_valid(game.pet), "the fox now goes with the hero")
			check(_foxes(lvl) == foxes_before - 1, "the tamed fox left its meadow")
			check(not lvl.fox_tamable, "no second fox can be won over")
			# A hidden ingredient a few tiles away: the fox sniffs it out.
			var here: Vector2i = lvl.world_to_cell(game.player.global_position)
			find_cell = Vector2i(-1, -1)
			for r in range(2, 4):
				for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
					if find_cell.x < 0 and lvl.is_open(here + d):
						find_cell = here + d
			check(find_cell.x >= 0, "there is open ground near the hero")
			lvl.hidden_finds.clear()
			lvl.hidden_finds.append({"cell": find_cell, "id": "trueffel"})
			game.pet._rest = 0.0
			stage_frames = 0
			stage = 2
		2:
			if not lvl.hidden_finds.is_empty() and stage_frames < 900:
				return false
			check(lvl.hidden_finds.is_empty(), "the fox dug the truffle up")
			# The hero walks over and picks it up.
			game.player.global_position = lvl.cell_to_world(find_cell)
			stage_frames = 0
			stage = 3
		3:
			if stage_frames < 30:
				return false
			check(game.player.bag.has("trueffel"), "the hero picked up the truffle")
			check(not lvl.taken.has("trueffel"), "dug-up ingredients are not marked as taken")
			# The hero walks off: the fox follows.
			_hero_near(lvl, game.player.global_position, 12.0)
			stage_frames = 0
			stage = 4
		4:
			if stage_frames < 240:
				return false
			var gap := Pet._flat(game.pet.global_position - game.player.global_position).length()
			check(gap < Pet.FOLLOW_GAP + 1.5, "the fox follows the hero (%.1f m)" % gap)
			check(lvl.is_open(lvl.world_to_cell(game.pet.global_position)), "the fox stays on open ground")
			# Saved and loaded again: the fox is still the hero's.
			check(game.save_game(), "the game is saved")
			game.has_fox = false
			game.fox_trust = 0
			game._apply_save(game._read_save())
			stage_frames = 0
			stage = 5
		5:
			if stage_frames < 10:
				return false
			check(game.has_fox and game.fox_trust == Pet.TRUST_NEEDED, "the saved game keeps the fox")
			check(game.pet != null and is_instance_valid(game.pet), "the fox comes along after loading")
			check(_foxes(game.level) == foxes_before - 1, "the tamed fox is not back on its meadow")
			# Down in the dungeon the fox comes along, and finds hide there too.
			game.load_level(0, false)
			stage_frames = 0
			stage = 6
		6:
			if stage_frames < 30:
				return false
			lvl = game.level
			check(game.pet != null and game.pet.get_parent() == lvl, "the fox comes along into the dungeon")
			check(Pet._flat(game.pet.global_position - game.player.global_position).length() < 6.0, "the fox stays close in the dungeon")
			check(lvl.hidden_finds.size() == Level.HIDDEN_IN_DUNGEON, "ingredients lie hidden in the dungeon (%d)" % lvl.hidden_finds.size())
			for f in lvl.hidden_finds:
				check(Items.ALL[f.id].found == "dungeon", "%s grows in the dungeon" % f.id)
			_finish()
			return true
	return false
