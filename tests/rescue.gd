extends SceneTree
## Headless test for the rescue (see Rescue): a hero whose life runs out on a
## dungeon floor is not dead. The bag as a whole (with the backpack and the
## ingredients) and the coins stay where they fell; other worn gear stays
## on, and the progress towards the next hero level is forgotten. The
## dwarves' emergency team carries the hero to the bed of the saved game,
## where they wake up with full life and the run goes on. Back at the spot,
## the bag, the backpack and the coins come back. On the surface it is
## an eagle that comes.
## Run with: godot --headless --fixed-fps 60 -s tests/rescue.gd

const HERO := "Rescue test"
const HERB := "baerlauch"
const ORE := "erzbrocken"

var failures := 0
var game: Node
var frames := 0
var stage := 0
var clock := 0.0
var fell_file := ""
var fell_at := Vector3.ZERO
var worn := {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: rescue")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _knock_out() -> void:
	var player: Player = game.player
	player.hp = 0
	player.dead = true
	player.defeated.emit()


func _put_hero(p: Vector3) -> void:
	var player: Player = game.player
	player.global_position = Vector3(p.x, 0.0, p.z)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _bundles(list: Array) -> Array:
	return list.filter(func(e): return Rescue.is_bundle(e))


func _process(delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	clock += delta
	var player: Player = game.player
	match stage:
		0:
			for text in [Rescue.LORE, "Du verlierst das Bewusstsein...", "Ein Adler stößt herab!", "Der Rettungstrupp der Zwerge ist unterwegs!",
					"Bergrettung!", "Ein Riesenadler hat dich bewusstlos davongetragen und hierher gebracht.",
					"Der Rettungstrupp der Zwerge hat dich bewusstlos aus der Tiefe getragen und hierher gebracht.",
					"Deine Tasche mit allem darin und %d Münzen liegen noch dort, wo du gefallen bist: %s.", "Du nimmst deine Tasche wieder an dich.",
					"Gedächtnisverlust: %d Erfahrung vergessen."]:
				check(Lang.EN.has(text), "'%s' has English" % text)
			game.hero_name = HERO
			game.escaped = false
			game.delete_save(game.save_path())
			# Slept in the refuge's bed on the first floor.
			game.load_level(0, false)
			game.state = game.State.PLAYING
			check(game.save_game(true), "the game is saved in bed")
			# Then down to the third floor, loaded with loot.
			game.load_level(2, false)
			game.state = game.State.PLAYING
			fell_file = game.level_files[2].get_file()
			player.bag.assign(["knochenhelm", "knochenhelm", "lederkappe"])
			player.equipped["waffe"] = "schwert"
			worn = player.equipped.duplicate()
			player.equipped["rucksack"] = "leinenrucksack"
			player.hero_xp = HeroLevel.total_for(3) + 40
			game.coins = 57
			game.crafting.add(HERB, 3, false)
			game.crafting.add(ORE, 2, false)
			fell_at = player.global_position
			_knock_out()
			check(player.bag.is_empty(), "the bag is left behind")
			check(game.coins == 0, "the coins are left behind")
			check(game.crafting.have(HERB) == 0 and game.crafting.have(ORE) == 0, "the ingredients are left behind")
			check(player.equipped == worn, "worn gear stays on, the backpack goes with the bag (%s)" % [player.equipped])
			check(player.hero_level() == 3 and player.hero_xp == HeroLevel.total_for(3), "amnesia: the progress towards the next level is forgotten, the level stays (%d)" % player.hero_xp)
			var here: Array = game.level.floor_items
			var packs := _bundles(here)
			check(packs.size() == 1, "the pack lies on the floor")
			check(packs.size() == 1 and _flat(Vector3(float(packs[0][2]), 0, float(packs[0][3])), fell_at) < 0.5, "the pack lies where the hero fell")
			var piles := here.filter(func(e): return e is Array and str(e[0]) == "coin")
			check(piles.size() == 1 and CoinPile.count_of(piles[0]) == 57, "the coins lie in a pile beside it")
			var rescue: Rescue = game.level.get_node_or_null("Rescue")
			check(rescue != null and not rescue.by_eagle, "below ground the dwarves come")
			check(rescue != null and rescue.find_children("Dwarf*", "", false, false).size() == 2, "two dwarves carry the stretcher")
			check(game.state == game.State.TRANSITION, "the hero lies unconscious")
			clock = 0.0
			stage = 1
		1:
			# Unconscious, the hero picks nothing up, not even their own pack.
			if clock < 0.5:
				return false
			check(player.bag.is_empty() and game.coins == 0, "nothing is picked up while unconscious")
			stage = 2
		2:
			if game.state != game.State.PLAYING and clock < Rescue.duration(false) + 15.0:
				return false
			check(game.state == game.State.PLAYING, "the hero gets up again")
			check(game.level_index == 0, "the hero wakes on the floor of the bed (%d)" % game.level_index)
			check(not player.dead and player.hp == player.max_hp, "with full life")
			check(game.lore.has(Rescue.LORE), "the compendium explains the rescue")
			check(_bundles(game.floors.get(fell_file, [])).size() == 1, "the pack still lies on the floor where the hero fell")
			var saved: Dictionary = game._read_save()
			check(int(saved.get("coins", -1)) == 0, "the game is saved after the rescue")
			check(_bundles(saved.get("floors", {}).get(fell_file, [])).size() == 1, "the saved game keeps the pack")
			# Back to the spot.
			game.load_level(2, false)
			game.state = game.State.PLAYING
			check(game.level.find_children("Bundle", "", true, false).size() == 1, "the pack is laid out again")
			_put_hero(fell_at + Vector3(6, 0, 0))
			clock = 0.0
			stage = 3
		3:
			if clock < 0.3:
				return false
			_put_hero(fell_at + Vector3(0.45, 0, 0.25))
			clock = 0.0
			stage = 4
		4:
			if clock < 0.6:
				return false
			check(player.bag.count("knochenhelm") == 2 and player.bag.has("lederkappe"), "the gear comes back (%s)" % [player.bag])
			check(game.crafting.have(HERB) == 3 and game.crafting.have(ORE) == 2, "the ingredients come back")
			check(game.crafting.ores.get(ORE, []).size() == 2, "the ore keeps its lumps")
			check(game.coins == 57, "the coins come back, not doubled (%d)" % game.coins)
			check(player.equipped.get("rucksack", "") == "leinenrucksack", "the backpack is worn again")
			check(_bundles(game.level.floor_items).is_empty(), "the empty pack is gone")
			# On the surface an eagle comes.
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			game.coins = 5
			_knock_out()
			var rescue: Rescue = game.level.get_node_or_null("Rescue")
			check(rescue != null and rescue.by_eagle, "on the surface an eagle comes")
			check(rescue != null and rescue.get_node_or_null("Eagle") != null, "the eagle is there")
			clock = 0.0
			stage = 5
		5:
			if game.state != game.State.PLAYING and clock < Rescue.duration(true) + 15.0:
				return false
			check(game.state == game.State.PLAYING and not player.dead, "the eagle brings the hero back up on their feet")
			check(game.level.outdoor, "out of the dungeon the hero wakes up in the open air")
			check(player.global_position.y < 3.0, "the hero is put down on the ground, not left in the sky")
			_finish()
			return true
	return false
