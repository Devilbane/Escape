extends SceneTree
## Headless test for fishing: the fountain, the village pond and the pond in
## the wolf hollow hold fish; the line is cast with G by the water, a bite
## has to be struck in time, rare fish bite only in their own water and at
## their own hours, every fish goes into the ingredient pouch, Hanna's
## Amulet of the Deep recipe calls for them, and catching a silver pike
## clears its smudged line.
## Run with: godot --headless -s tests/fishing.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Fishing test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


## The game needs a few frames to set itself up first.
func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path(HERO))
	if failures == 0:
		print("PASS: fishing")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


## Presses G, as soon as the hero may act again (casting and landing a
## catch hold the hero for a moment).
func _key_g() -> void:
	game.player._busy = 0.0
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	key.pressed = true
	game._unhandled_input(key)


func _water(kind: String) -> Dictionary:
	for w in game.level.fishing_waters:
		if w.water == kind:
			return w
	return {}


## Puts the hero on dry ground beside a water, facing it.
func _stand_by(w: Dictionary) -> void:
	var lvl: Outdoor = game.level
	for i in 16:
		var dir := Vector3(sin(i * TAU / 16.0), 0, cos(i * TAU / 16.0))
		var p: Vector3 = w.pos + dir * (w.reach + 1.4 if w.round else w.reach * 1.42 + 0.8)
		if lvl.is_open(lvl.world_to_cell(p)) and Level.water_distance(w, p) < Fishing.RANGE:
			game.player.global_position = Vector3(p.x, 0, p.z)
			game.player.velocity = Vector3.ZERO
			return
	check(false, "there is dry ground beside the %s" % w.water)


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


func _test() -> void:
	game.hero_name = HERO
	game.escaped = true
	game.crafting.clear()
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	check(game.level is Outdoor, "the village is loaded")
	var fishing: Fishing = game.fishing
	var player: Player = game.player

	# Every text has its English.
	check(Lang.EN.has(Fishing.HOW_TO), "the fishing how-to has an English text")
	for kind in Fishing.WATERS:
		for row in Fishing.WATERS[kind]:
			check(row[0] in ["", "muenze"] or Crafting.INGREDIENTS.has(row[0]), "%s: %s is an ingredient" % [kind, row[0]])
			check(row[2] in ["", "nacht", "daemmerung"], "%s: %s bites at a known time" % [kind, row[0]])
	for text in ["Angeln", "G: Angeln", "G: Anschlagen!", "G: Leine einholen"]:
		check(Lang.EN.has(text), "\"%s\" has an English text" % text)

	# The three waters.
	var count := {}
	for w in game.level.fishing_waters:
		count[w.water] = count.get(w.water, 0) + 1
	check(count.get("brunnen", 0) == 1, "the village has one fountain to fish in")
	check(count.get("teich", 0) >= 4, "the village pond holds fish")
	check(count.get("senke", 0) >= 4, "the wolf hollow has a pond")

	# What bites when.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for hour in [2.0, 6.0, 12.0, 19.0, 23.0]:
		for i in 400:
			for kind in Fishing.WATERS:
				seen["%s %s %d" % [kind, Fishing.roll(kind, hour, rng), int(hour)]] = true
	check(seen.has("senke mondforelle 23") and seen.has("senke mondforelle 2"), "the moon trout bites at night")
	check(not seen.has("senke mondforelle 12") and not seen.has("senke mondforelle 6"), "the moon trout never bites by day")
	check(seen.has("teich silberhecht 6") and seen.has("teich silberhecht 19"), "the silver pike bites at dawn and dusk")
	check(not seen.has("teich silberhecht 12") and not seen.has("teich silberhecht 23"), "the silver pike hides at noon and midnight")
	check(seen.has("brunnen goldkarpfen 12") and seen.has("brunnen muenze 12"), "the fountain holds the golden carp and old coins")
	check(seen.has("teich barsch 12") and seen.has("senke barsch 12"), "perch bite in both ponds")
	for key in seen:
		check(not (key.begins_with("brunnen") and key.contains("barsch")), "no perch in the fountain")
		check(not key.contains("mondforelle") or key.begins_with("senke"), "the moon trout lives only in the wolf hollow")

	# Away from water there is nothing to fish in.
	player.global_position = game.level.spots.square[0]
	check(fishing.water_near().is_empty(), "no water in the middle of the square")
	check(fishing.press() != "", "casting away from water says why not")
	check(not fishing.is_fishing(), "no line is cast away from water")

	# Casting at the fountain with G, and drawing the line in again.
	_stand_by(_water("brunnen"))
	check(fishing.water_near().get("water", "") == "brunnen", "the fountain is in reach")
	_key_g()
	check(fishing.state == Fishing.WAITING, "G casts the line")
	check(is_instance_valid(fishing._float) and fishing._float.get_parent() == game.level, "a float lies on the water")
	check(game.lore.has(Fishing.HOW_TO), "the compendium explains fishing")
	_key_g()
	check(not fishing.is_fishing(), "G again draws the line in")

	# A bite: too slow and the fish is gone.
	var pouch_before: Dictionary = game.crafting.pouch.duplicate()
	var coins_before: int = game.coins
	_key_g()
	fishing.tick(Fishing.WAIT_MAX + 0.1)
	check(fishing.state == Fishing.BITE, "a fish bites after a while")
	fishing.tick(Fishing.BITE_TIME + 0.1)
	check(not fishing.is_fishing(), "the fish lets go when the hero is too slow")
	check(game.crafting.pouch == pouch_before and game.coins == coins_before, "nothing is caught when too slow")

	# Struck in time: something comes in and the line is free again.
	_key_g()
	fishing.bite()
	_key_g()
	check(not fishing.is_fishing(), "striking in time lands the catch")

	# Walking away, a blow or a window draw the line in.
	_key_g()
	player.global_position = game.level.spots.square[0]
	fishing.tick(0.05)
	check(not fishing.is_fishing(), "walking away draws the line in")
	_stand_by(_water("senke"))
	check(fishing.water_near().get("water", "") == "senke", "the wolf hollow pond is in reach")
	_key_g()
	check(fishing.is_fishing(), "the line goes into the wolf hollow pond")
	player.hp -= 1
	fishing.tick(0.05)
	check(not fishing.is_fishing(), "a blow scares the fish away")
	player.hp += 1
	_key_g()
	game.menus.open("inventar")
	fishing.tick(0.05)
	check(not fishing.is_fishing(), "opening a window draws the line in")
	game.menus.close()
	check(not is_instance_valid(fishing._float) or fishing._float.is_queued_for_deletion(), "the float is gone")

	# Catches go into the pouch; a coin is gold.
	game.crafting.clear()
	coins_before = game.coins
	fishing.take("muenze", player.global_position, game.level)
	check(game.coins == coins_before + 1, "an old coin is worth 1 gold")
	fishing.take("barsch", player.global_position, game.level)
	fishing.take("mondforelle", player.global_position, game.level)
	check(game.crafting.have("barsch") == 1 and game.crafting.have("mondforelle") == 1, "fish go into the ingredient pouch")
	check(game.crafting.book_ingredients().has("mondforelle"), "the ingredient book lists the moon trout")
	var trout: String = game.crafting.describe_ingredient("mondforelle")
	check(trout.contains("1 dabei") and trout.contains("Ort: Wolfssenke") and trout.contains("Zeit: nur nachts"), "the book says where and when the moon trout bites")
	check(trout.contains("Fundort entdeckt."), "catching the moon trout marks its place as found")
	fishing.take("", player.global_position, game.level)
	check(game.crafting.pouch.size() == 2, "weed is not kept")

	# Hanna's recipe needs the fish, and the silver pike clears its line.
	var hanna := _villager("9")
	check(hanna != null, "Hanna the water carrier lives in the village")
	if hanna:
		check(game.crafting.mark("9") == "!", "Hanna has a recipe for the hero")
		check(game.crafting.talk(hanna), "Hanna hands over her recipe")
	check(game.crafting.knows("tiefenamulett"), "the Amulet of the Deep is known")
	var recipe: String = game.crafting.describe("tiefenamulett")
	check(recipe.contains("Mondforelle 1 / 1") and recipe.contains("Barsch 1 / 3") and recipe.contains("Goldkarpfen 0 / 1"), "the recipe counts the fish caught")
	check(recipe.contains("Ein … Hecht, wenn …"), "the pike's line is smudged at first")
	fishing.take("silberhecht", player.global_position, game.level)
	check(game.crafting.describe("tiefenamulett").contains("wenn der Tag kommt oder geht"), "catching a silver pike clears the smudged line")
	fishing.take("goldkarpfen", player.global_position, game.level)
	game.crafting.add("barsch", 2)
	check(game.crafting.has_ingredients("tiefenamulett"), "with all the fish the recipe is complete")

	# Kept in the saved game, like everything in the pouch.
	check(game.save_game(), "the game is saved")
	var saved: Dictionary = game.crafting.for_save()
	game.crafting.clear()
	game._apply_save(game._read_save(game.save_path(HERO)))
	check(game.crafting.for_save() == saved, "the saved game brings the fish back")

	# The button in the pull-out menu.
	var found := false
	for b in game._drawer.find_children("*", "Button", true, false):
		if b.text == Lang.t("Angeln"):
			found = true
	check(found, "the pull-out menu has a Fish button")
