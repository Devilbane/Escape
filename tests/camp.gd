extends SceneTree
## Headless test for the camp (see Camp): with a bedroll in the bag the hero
## rolls out a camp with a campfire on a dungeon floor, but not without a
## bedroll, not in a fight and not with monsters close by. The camp's
## window saves the game; a game saved asleep at the camp wakes up there,
## lying on the bedroll, and gets up by the fire with no monster close.
## Walking away packs the camp up. The bedroll is carried, never worn, and
## the merchant keeps one for a hero who has none.
## Run with: godot --headless --fixed-fps 60 -s tests/camp.gd

const HERO := "Camp test"

var failures := 0
var game: Node
var frames := 0
var stage := 0
var clock := 0.0
var spot := Vector3.ZERO
var camp_pos := Vector3.ZERO
var lay_down := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: camp")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A spot on the floor with room for a camp and no monster near, or INF.
func _quiet_spot(level: Level) -> Vector3:
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if not Camp._open(level, level.cell_to_world(c)):
				continue
			var p: Vector3 = level.cell_to_world(c)
			if not Camp.monster_near(level, p) and not Camp.find_spot(level, p, Vector3.FORWARD).is_empty():
				return p
	return Vector3.INF


## A walkable spot far from `from`, or INF.
func _far_spot(level: Level, from: Vector3) -> Vector3:
	for y in level.height:
		for x in level.width:
			var p: Vector3 = level.cell_to_world(Vector2i(x, y))
			if Camp._open(level, p) and _flat(p, from) > Camp.LEAVE_RANGE + 4.0:
				return p
	return Vector3.INF


func _put_hero(p: Vector3) -> void:
	var player: Player = game.player
	player.global_position = Vector3(p.x, 0.0, p.z)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _process(delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	clock += delta
	var player: Player = game.player
	match stage:
		0:
			game.hero_name = HERO
			game.escaped = false
			game.load_level(2, false)
			game.state = game.State.PLAYING
			game.delete_save(game.save_path())
			stage = 1
		1:
			var level: Level = game.level
			check(not level.enemies.is_empty(), "the test floor has monsters")
			for text in ["Schlafrolle", "Lager", "Lager aufschlagen", "Dein Lager", "U: Lager", "Du packst dein Lager zusammen.", game.CAMP_LEARN,
					Items.ALL[Camp.ITEM].effect, "Hier drinnen schläfst du besser in einem Bett."]:
				check(Lang.EN.has(text), "'%s' has English" % text)
			# The bedroll: carried, never worn, sold by the merchant.
			check(Items.ALL.has(Camp.ITEM) and Items.is_bedroll(Camp.ITEM), "the bedroll is an item")
			player.bag.erase(Camp.ITEM)
			game.shop_stock.erase(Camp.ITEM)
			game.menus.open("haendler")
			check(game.shop_stock.has(Camp.ITEM), "the merchant sells a bedroll to a hero who has none")
			game.menus.close()
			# No camp without a bedroll.
			spot = _quiet_spot(level)
			check(spot != Vector3.INF, "there is a quiet spot for a camp")
			if spot == Vector3.INF:
				_finish()
				return true
			_put_hero(spot)
			game.camp_action()
			check(not game.has_camp(), "no camp without a bedroll")
			player.bag.append(Camp.ITEM)
			check(not player.equip(Camp.ITEM), "the bedroll cannot be worn")
			check(player.bag.has(Camp.ITEM), "the bedroll stays in the bag")
			# Not in a fight.
			player.fight_cooldown = 3.0
			game.camp_action()
			check(not game.has_camp(), "no camp in the middle of a fight")
			player.fight_cooldown = 0.0
			# Not with a monster close by.
			var e: Enemy = null
			for m in level.enemies:
				if is_instance_valid(m) and not m.dead and not m.is_level_boss():
					e = m
					break
			var home := e.global_position
			e.global_position = spot + Vector3(3, 0, 0)
			check(Camp.monster_near(level, spot), "a monster close by is noticed")
			game.camp_action()
			check(not game.has_camp(), "no camp with a monster close by")
			e.global_position = home
			# Not indoors.
			check(Camp.why_not(player, level, true) != "", "no camp inside a building")
			# Now it works: a camp and its window.
			game.camp_action()
			check(game.has_camp(), "a camp is pitched")
			check(game.menus.current == "nachtlager", "the camp's window opens (%s)" % game.menus.current)
			check(game.lore.has(game.CAMP_LEARN), "the compendium explains the camp")
			check(player.bag.has(Camp.ITEM), "the bedroll is not used up")
			if not game.has_camp():
				_finish()
				return true
			camp_pos = game.camp.global_position
			check(game.camp.get_parent() == level, "the camp lies on this floor")
			check(game.camp.find_children("*", "OmniLight3D", true, false).size() == 1, "the campfire gives light")
			check(Camp._open(level, game.camp.fire_spot()), "the fire burns on open floor")
			game.menus.close()
			# The camp key at the camp opens its window again.
			game.camp_action()
			check(game.menus.current == "nachtlager", "the camp key at the camp opens its window again")
			game.menus.close()
			# Asleep at the camp, then loaded again.
			check(game.save_game(true), "the game is saved at the camp")
			var data: Dictionary = game._read_save()
			check(not Camp.from_save(data.get("camp")).is_empty(), "the save knows the camp")
			check(game.save_info().get("camp", false), "the saved game says it was saved at a camp")
			var info: Dictionary = game.save_info()
			var plain := info.duplicate()
			plain.camp = false
			check(game.save_summary(info) != game.save_summary(plain), "the load window tells it was saved at a campfire")
			game._apply_save(data)
			game._after_load(data)
			game._start_playing()
			level = game.level
			check(game.has_camp(), "the camp is there again after loading")
			check(game.has_camp() and _flat(game.camp.global_position, camp_pos) < 0.05, "the camp is where it was pitched")
			check(not Camp.monster_near(level, camp_pos) or level.enemies.all(func(m): return not is_instance_valid(m) or m.is_queued_for_deletion() or m.is_level_boss() or m.kind == "waechter" or _flat(m.global_position, camp_pos) >= Camp.SAFE_RANGE),
					"no monster waits by the camp")
			check(game._waking and player.frozen, "the hero is still asleep after loading")
			check(_flat(player.global_position, game.camp.global_position) < 1.5, "the hero lies on the bedroll")
			clock = 0.0
			stage = 2
		2:
			if game._waking and clock < 12.0:
				return false
			check(not game._waking and game.state == game.State.PLAYING, "the hero gets up by the fire")
			check(not player.frozen or game.menus.is_open(), "the hero can move once up")
			check(_flat(player.global_position, camp_pos) < Camp.NEAR, "the hero stands at the camp")
			game.menus.close()
			# An ordinary save at the camp also loads there, on the feet.
			check(game.save_game(), "the game is saved awake at the camp")
			var data: Dictionary = game._read_save()
			game._apply_save(data)
			game._after_load(data)
			game._start_playing()
			check(not game._waking and game.has_camp(), "an awake save loads at the camp, on the feet")
			check(_flat(player.global_position, camp_pos) < Camp.NEAR, "an awake save loads beside the camp")
			# Walking away packs it up.
			var far := _far_spot(game.level, camp_pos)
			check(far != Vector3.INF, "there is a spot away from the camp")
			_put_hero(far)
			clock = 0.0
			stage = 3
		3:
			if clock < 0.3:
				return false
			check(not game.has_camp(), "walking away packs the camp up")
			check(player.bag.has(Camp.ITEM), "the bedroll goes back into the bag")
			check(game.save_game(), "the game is saved away from the camp")
			check(Camp.from_save(game._read_save().get("camp")).is_empty(), "a save away from the camp does not wake up there")
			_finish()
			return true
	return false
