extends SceneTree
## Headless test for fishing: the fountain, the village pond and the pond in
## the wolf hollow hold fish; the line is cast with G by the water, a bite
## has to be struck in time, rare fish bite only in their own water and at
## their own hours, every fish goes into the ingredient pouch, Hanna's
## Amulet of the Deep recipe calls for them, and catching a silver pike
## clears its smudged line. The line flies well out over a pond, and the
## little pond monster can surface there (never in the fountain), then sink
## again or take the bait. The hero holds a rod while fishing and swings it
## for the cast.
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
	game.delete_save(game.save_path())
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
	# The rod: in the right hand instead of the knife, swung back and whipped
	# through on the cast; the float flies off its tip and splashes down.
	var hand: Node3D = player.find_child("handslot_r", true, false)
	check(is_instance_valid(fishing.rod) and fishing.rod.get_parent() == hand, "the hero holds a fishing rod in the right hand")
	check(not hand.get_node("Knife").visible, "the knife is put away while fishing")
	check(Fishing.rod_pitch(Fishing.SWING_BACK) > PI / 2.0, "the cast swings the rod back over the shoulder")
	check(Fishing.rod_pitch(Fishing.SWING_BACK + Fishing.SWING_WHIP) < Fishing.REST_PITCH, "and whips it forward")
	check(is_equal_approx(Fishing.rod_pitch(5.0), Fishing.REST_PITCH), "then the rod rests")
	check(Fishing.rod_bend(5.0, 0.3) < Fishing.rod_bend(5.0, 0.0), "the rod bends when the float is pulled under")
	check(fishing._float.position.distance_to(fishing._rod_tip()) < 0.5, "the float hangs at the rod's tip before the throw")
	fishing.tick(Fishing.RELEASE + Fishing.FLY_TIME * 0.5)
	check(fishing._float.position.y > fishing._float_rest.y + 0.5, "the float flies out in an arc")
	fishing.tick(Fishing.FLY_TIME)
	check(fishing._splashed and fishing._float.position.distance_to(fishing._float_rest) < 0.1, "the float lands on the water")
	check(game.lore.has(Fishing.HOW_TO), "the compendium explains fishing")
	_key_g()
	check(not fishing.is_fishing(), "G again draws the line in")
	check(fishing.rod == null and hand.get_node("Knife").visible, "the rod is put away and the knife is back")

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

	# The line flies well out over the ponds, but stays in the water.
	for kind in ["teich", "senke"]:
		var w := _water(kind)
		_stand_by(w)
		var from := player.global_position
		var spot := Fishing.float_spot(w, from, game.level.fishing_waters)
		var old := Fishing.edge_spot(w, from)
		var flat := Vector2(spot.x - from.x, spot.z - from.z).length()
		check(flat > Vector2(old.x - from.x, old.z - from.z).length() + 1.0, "%s: the line flies further out than the nearest edge" % kind)
		check(flat >= 3.5 and flat <= Fishing.CAST_REACH + 0.01, "%s: the float lands 3.5 to %.0f m out (%.1f)" % [kind, Fishing.CAST_REACH, flat])
		check(Fishing.is_deep(game.level.fishing_waters, kind, spot), "%s: the float lands clear of the shore" % kind)
	var basin := _water("brunnen")
	_stand_by(basin)
	var in_basin := Fishing.float_spot(basin, player.global_position, game.level.fishing_waters)
	check(Level.water_distance(basin, in_basin) <= 0.0, "the float stays in the fountain basin")

	# The pond monster: never in the fountain.
	_key_g()
	fishing.monster_rises(false)
	check(fishing.monster == null, "no pond monster in the fountain")
	_key_g()
	# In a pond it surfaces, holds the fish off, and sinks again.
	_stand_by(_water("teich"))
	_key_g()
	check(fishing.is_fishing() and is_instance_valid(fishing._line), "a line runs out to the float")
	fishing.timer = 5.0
	fishing.monster_rises(false)
	check(is_instance_valid(fishing.monster) and fishing.monster.get_parent() == game.level, "the pond monster surfaces in the pond")
	check(Fishing.is_deep(game.level.fishing_waters, "teich", fishing._monster_home, Fishing.MONSTER_SHORE_GAP), "it surfaces out on the water")
	check(game.lore.has(Fishing.MONSTER_LORE), "the compendium tells of the pond monster")
	var up := Fishing.MONSTER_RISE + Fishing.MONSTER_STAY + Fishing.MONSTER_SINK
	for i in int(up / 0.1) - 2:
		fishing.tick(0.1)
	check(fishing.state == Fishing.WAITING and fishing.timer == 5.0, "no fish bites while the monster is about")
	for i in 4:
		fishing.tick(0.1)
	check(fishing.monster == null and fishing.is_fishing(), "the monster sinks again and the line stays out")
	# Or it takes the bait, and the line comes in empty.
	pouch_before = game.crafting.pouch.duplicate()
	fishing.monster_rises(true)
	var monster := fishing.monster
	for i in int(up / 0.1) + 3:
		fishing.tick(0.1)
	check(not fishing.is_fishing(), "the monster takes the bait and the line comes in")
	check(not is_instance_valid(monster) or monster.is_queued_for_deletion(), "the monster is gone")
	check(game.crafting.pouch == pouch_before, "nothing is caught when the monster takes the bait")
	# It turns up now and then on its own.
	var visits := 0
	for i in 200:
		_key_g()
		if fishing._monster_due >= 0.0:
			visits += 1
		_key_g()
	check(visits > 10 and visits < 60, "the monster turns up now and then (%d of 200 casts)" % visits)
	for text in [Fishing.MONSTER_LORE, "Blubb!", "Neben dem Schwimmer taucht ein kleines Teichungeheuer auf!",
			"Das kleine Teichungeheuer schnappt sich deinen Köder und taucht damit ab!",
			"Das kleine Teichungeheuer taucht wieder ab. Du wartest weiter …"]:
		check(Lang.EN.has(text), "\"%s\" has an English text" % text)

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
	game._apply_save(game._read_save(game.save_path()))
	check(game.crafting.for_save() == saved, "the saved game brings the fish back")

	# The button in the pull-out menu.
	var found := false
	for b in game._drawer.find_children("*", "Button", true, false):
		if b.text == Lang.t("Angeln"):
			found = true
	check(found, "the pull-out menu has a Fish button")
