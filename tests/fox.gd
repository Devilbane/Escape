extends SceneTree
## Headless test for the fox companion: a hero with sausages wins a wild fox
## over (it comes up and eats instead of bolting), after three sausages it
## follows the hero, digs up a hidden ingredient for them, stays theirs in
## the saved game, lounges about (sits, lies down, strolls) while the hero
## stands still, follows once the hero walks off, comes along down into the
## dungeon and climbs the stairs behind the hero.
## Run with: godot --headless --fixed-fps 60 -s tests/fox.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var fox: Animal
var foxes_before := 0
var find_cell := Vector2i.ZERO
var acts := {}
var posed := {}
var max_gap := 0.0
var off_ground := 0
var first_level: Node = null
var climbed_y := 0.0


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
			game.crafting.clear()
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			lvl = game.level
			check(game.pet == null, "no fox goes with a new hero")
			check(lvl.hidden_finds.size() == Level.HIDDEN_OUTDOORS, "ingredients lie hidden in the open air (%d)" % lvl.hidden_finds.size())
			for f in lvl.hidden_finds:
				check(Crafting.INGREDIENTS.has(f.id) and Crafting.INGREDIENTS[f.id].region == "Wildnis", "%s grows in the open air" % f.id)
				check(lvl.is_open(f.cell), "a hidden ingredient lies on open ground")
				check(Lang.EN.has(Crafting.INGREDIENTS[f.id].name) and Lang.EN.has(Crafting.INGREDIENTS[f.id].where), "%s has English texts" % f.id)
			check(Lang.EN.has(Items.ALL[Pet.FOOD].name) and Lang.EN.has(Items.ALL[Pet.FOOD].effect), "the sausage has an English text")
			check(Lang.EN.has(game.FOX_LEARN), "the compendium entry has an English text")
			# The shopkeeper always has sausages.
			game.menus.open("haendler")
			check(game.shop_stock.count(Pet.FOOD) >= 2, "the merchant sells sausages")
			# Buying one tells the hero where the foxes live, and the
			# compendium keeps it.
			game.lore.clear()
			game.coins = 10
			game.player.bag.clear()
			game.menus._buy(game.shop_stock.find(Pet.FOOD))
			check(game.player.bag.has(Pet.FOOD), "the hero bought a sausage")
			check(game.menus._note == Lang.t("Gekauft: Wurst. Füchse leben am Waldteich westlich vom Dorf."), "buying a sausage says where the foxes live")
			check(game.lore.has(Pet.WHERE), "the compendium says where the foxes live")
			for text in [Pet.WHERE, "Gekauft: Wurst. Füchse leben am Waldteich westlich vom Dorf."]:
				check(Lang.EN.has(text), "the fox hint has an English text")
			game.menus.close()
			# The hint must match the map: the foxes live west of the village
			# square, next to the woodland pond.
			var square := Vector3.ZERO
			for p in lvl.spots.square:
				square += p
			square /= lvl.spots.square.size()
			for s in lvl._animal_spots.filter(func(s): return s.kind == "fuchs"):
				var fox_pos: Vector3 = lvl.cell_to_world(s.cell)
				check(fox_pos.x < square.x - 40.0 and absf(fox_pos.z - square.z) < absf(fox_pos.x - square.x), "a fox meadow lies west of the village square")
				var near_pond := false
				for dy in range(-7, 8):
					for dx in range(-7, 8):
						if lvl.cell_char(s.cell + Vector2i(dx, dy)) == "~":
							near_pond = true
				check(near_pond, "a fox meadow lies by the woodland pond")
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
			check(game.crafting.have("trueffel") == 1, "the truffle went into the ingredient pouch")
			check(not game.player.bag.has("trueffel"), "the truffle is not in the bag")
			check(game.crafting.book_ingredients().has("trueffel"), "the ingredient book lists the truffle")
			check(not lvl.taken.has("trueffel"), "dug-up ingredients are not marked as taken")
			# The hero walks off: the fox follows.
			_hero_near(lvl, game.player.global_position, 12.0)
			stage_frames = 0
			stage = 4
		4:
			if stage_frames < 240:
				return false
			var gap := Pet._flat(game.pet.global_position - game.player.global_position).length()
			check(gap < Pet.LEASH + 0.5, "the fox follows the hero (%.1f m)" % gap)
			check(lvl.is_open(lvl.world_to_cell(game.pet.global_position)), "the fox stays on open ground")
			# The hero stands still a while: the fox lounges about.
			lvl.hidden_finds.clear()
			acts.clear()
			max_gap = 0.0
			stage_frames = 0
			stage = 7
		7:
			var pet: Pet = game.pet
			var gap := Pet._flat(pet.global_position - game.player.global_position).length()
			max_gap = maxf(max_gap, gap)
			if pet.state == "lounge":
				acts[pet._act] = true
			if pet.pose() != "":
				posed[pet.pose()] = maxf(posed.get(pet.pose(), 0.0), pet.pose_weight(pet.pose()))
			if not lvl.is_open(lvl.world_to_cell(pet.global_position)):
				off_ground += 1
			if stage_frames < 60 * 70:
				return false
			print("the fox did: ", acts.keys(), " posed: ", posed)
			check(acts.size() >= 3, "the fox does several things while the hero stands still (%s)" % [acts.keys()])
			check(posed.has("sit") or posed.has("lie"), "the fox sits or lies down near a resting hero")
			check(posed.values().any(func(w): return w > 0.95), "a pose fades in fully")
			check(max_gap <= Pet.LEASH + 0.3, "the lounging fox stays within its leash (%.1f m)" % max_gap)
			check(off_ground == 0, "the lounging fox stays on open ground")
			# The hero walks off: up it gets and follows.
			_hero_near(lvl, game.player.global_position, 14.0)
			stage_frames = 0
			stage = 8
		8:
			if stage_frames == 30:
				check(game.pet.state in ["follow", "seek"], "the fox gets up and follows when the hero walks off (%s)" % game.pet.state)
			if stage_frames < 300:
				return false
			check(Pet._flat(game.pet.global_position - game.player.global_position).length() < Pet.LEASH + 0.5, "the fox caught up")
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
			check(game.crafting.have("trueffel") == 1, "the saved game keeps the truffle in the pouch")
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
				check(Crafting.INGREDIENTS[f.id].region == "Verlies", "%s grows in the dungeon" % f.id)
			# Up the stairs: the fox climbs them right behind the hero.
			game.state = game.State.PLAYING
			first_level = game.level
			climbed_y = 0.0
			game._on_exit_reached()
			stage_frames = 0
			stage = 9
		9:
			if game.level == first_level and is_instance_valid(game.pet):
				if stage_frames == 30:
					check(game.pet.state == "climb", "the fox takes the stairs behind the hero (%s)" % game.pet.state)
				climbed_y = maxf(climbed_y, game.pet.global_position.y)
				return false
			if stage_frames < 200:
				return false
			check(climbed_y > 1.0, "the fox went up the steps (%.1f m)" % climbed_y)
			check(game.pet != null and is_instance_valid(game.pet) and game.pet.get_parent() == game.level, "the fox arrives on the next level")
			check(Pet._flat(game.pet.global_position - game.player.global_position).length() < Pet.LEASH + 0.5, "the fox is at the hero's side on the next level")
			check(game.pet.global_position.y < 0.1, "the fox stands on the floor of the next level")
			_finish()
			return true
	return false
