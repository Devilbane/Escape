extends SceneTree
## Headless test for fishing: the fountain, the village pond and the pond in
## the wolf hollow hold fish; the line is cast with G by the water, a bite
## has to be struck in time (or let go for another bite in a row, which
## makes the catch rarer, until the row breaks off), rare fish bite only in their own water and at
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
			check(row[0] in ["", "muenze", "flasche", Fishing.RING] or Crafting.INGREDIENTS.has(row[0]), "%s: %s is an ingredient" % [kind, row[0]])
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

	# A bite: let go, the fish may bite again; when it does not, it is gone.
	var pouch_before: Dictionary = game.crafting.pouch.duplicate()
	var coins_before: int = game.coins
	_key_g()
	fishing.tick(Fishing.WAIT_MAX + 0.1)
	check(fishing.state == Fishing.BITE and fishing.bites == 1, "a fish bites after a while")
	fishing.let_go(true)
	check(fishing.state == Fishing.WAITING and fishing.timer <= Fishing.CHAIN_GAP_MAX, "let go, the float comes up and the fish may bite again soon")
	fishing.tick(Fishing.CHAIN_GAP_MAX + 0.05)
	check(fishing.state == Fishing.BITE and fishing.bites == 2, "the fish bites a second time in a row")
	fishing.let_go(false)
	check(not fishing.is_fishing() and fishing.bites == 0, "the row breaks off and the fish is gone")
	check(game.crafting.pouch == pouch_before and game.coins == coins_before, "nothing is caught when the row breaks off")
	# Striking into the pause between two bites loses the fish too.
	_key_g()
	fishing.bite()
	fishing.let_go(true)
	_key_g()
	check(not fishing.is_fishing() and game.crafting.pouch == pouch_before and game.coins == coins_before, "striking between two bites catches nothing")
	# Left alone, the bite times out by itself, and the row never runs past MAX_CHAIN.
	_key_g()
	for i in Fishing.MAX_CHAIN:
		fishing.bite()
		fishing.let_go(true)
	fishing.bite()
	fishing.tick(Fishing.BITE_TIME + 0.1)
	check(not fishing.is_fishing(), "after MAX_CHAIN bites the fish lets go for good")
	for text in ["Zu langsam! Der Fisch beißt nicht noch einmal und ist weg.", "Die Bissfolge reißt nach %d Bissen ab: Der Fisch ist weg!",
			"Der Schwimmer taucht wieder auf … beißt er noch einmal?", "%d. Biss in Folge! G: anschlagen, oder auf den nächsten warten.",
			"Zu früh angeschlagen! Der Fisch ist weg.", "Weg!", Fishing.HOW_TO]:
		check(Lang.EN.has(text), "\"%s\" has an English text" % text)

	# A longer row makes the catch rarer: less weed, more rare fish.
	var chain_rng := RandomNumberGenerator.new()
	for kind in ["brunnen", "teich", "senke"]:
		var hour := 6.0 if kind == "teich" else 23.0
		var tally := {1: {"": 0, "rare": 0}, 4: {"": 0, "rare": 0}}
		for row in tally:
			chain_rng.seed = 7
			for i in 2000:
				var got := Fishing.roll(kind, hour, chain_rng, row)
				if got == "":
					tally[row][""] += 1
				elif Fishing.is_rare(got):
					tally[row]["rare"] += 1
		check(tally[4][""] < tally[1][""] and tally[4]["rare"] > tally[1]["rare"] * 2, "%s: four bites in a row bring less weed and more rare fish (%s)" % [kind, tally])

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
	var looks := fishing.monster
	check(looks.find_children("Ear*", "", false, false).size() == 2, "the pond monster has two spiky ears")
	var scaly := false
	for mi: MeshInstance3D in looks.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.material_override as StandardMaterial3D
		if mat and mat.normal_texture != null and mat.uv1_triplanar:
			scaly = true
	check(scaly, "the pond monster has scaly skin (see ScaleSkin)")
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
	# Drawing the line in does not send the monster away: it stays up on its
	# own to the end of its visit, and casting again keeps it too.
	_key_g()
	fishing.monster_rises(false)
	var stays := fishing.monster
	_key_g()
	check(not fishing.is_fishing() and is_instance_valid(stays) and fishing.monster == stays, "drawing the line in leaves the monster up")
	_key_g()
	check(fishing.is_fishing() and fishing.monster == stays, "casting again keeps the monster up")
	fishing.timer = 0.05
	fishing.tick(0.1)
	check(fishing.state == Fishing.BITE, "a monster up on its own holds no fish off")
	_key_g()
	for i in int(up / 0.1) + 3:
		fishing.tick(0.1)
	check(fishing.monster == null and (not is_instance_valid(stays) or stays.is_queued_for_deletion()), "it sinks at the end of its visit")
	# Its pranks; and after taking the bait it wears the float as a hat.
	check(fishing.monster_hat, "the monster keeps the float it stole")
	_key_g()
	fishing.monster_rises(false)
	check(fishing.monster.get_node_or_null("Hat") != null, "it wears the stolen float as a hat")
	coins_before = game.coins
	for gag in Fishing.MONSTER_GAGS:
		fishing._gag(gag)
	check(game.coins == coins_before + 1, "the coin it spits out is worth 1 copper")
	var visits_before := fishing.monster_visits
	_key_g()
	_key_g()
	fishing.monster_rises(false)
	check(fishing.monster_visits >= visits_before and fishing.monster_visits >= 2, "casting again does not reset its visits")
	_key_g()
	for i in int(up / 0.1) + 3:
		fishing.tick(0.1)
	if fishing.is_fishing():
		_key_g()
	for text in ["Blubb?", "Pfft!", "Hihi!", "Rülps!", "Hier kommst du nicht ans Wasser.",
			"Das kleine Teichungeheuer taucht auf. Auf dem Kopf trägt es deinen gestohlenen Schwimmer, wie einen Hut!",
			"Das kleine Teichungeheuer taucht wieder auf. Es scheint dich zu kennen!",
			"Das Teichungeheuer spuckt dir einen Wasserstrahl mitten ins Gesicht und kichert.",
			"Das Teichungeheuer rülpst eine riesige Blase. Es schaut sehr verlegen drein.",
			"Das Teichungeheuer spuckt dir eine alte Münze vor die Füße. +1 Kupfer"]:
		check(Lang.EN.has(text), "\"%s\" has an English text" % text)

	# Clicking the water of a pond casts the line toward the clicked spot.
	var pond := _water("teich")
	_stand_by(pond)
	var aim := Fishing.float_spot(pond, player.global_position, game.level.fishing_waters)
	check(not fishing.water_at(aim).is_empty(), "the clicked spot is pond water")
	check(fishing.water_at(_water("brunnen").pos).is_empty(), "a click on the fountain still uses the fountain")
	player._busy = 0.0
	game._click(Vector3(aim.x, 0, aim.z))
	check(fishing.state == Fishing.WAITING, "a click on the water casts the line")
	check(Vector2(fishing._float_rest.x - aim.x, fishing._float_rest.z - aim.z).length() < 0.5, "the float lands where the water was clicked")
	game._click(Vector3(aim.x, 0, aim.z))
	check(not fishing.is_fishing(), "another click on the water draws the line in")
	# A spot to one side lands to that side, not on the straight cast.
	var side := Fishing.aim_spot(pond, player.global_position, aim + (aim - player.global_position).cross(Vector3.UP).normalized() * 2.0, game.level.fishing_waters)
	check(Fishing.is_deep(game.level.fishing_waters, "teich", side), "an aimed float lands clear of the shore")
	# From afar the hero walks to the shore first, then casts.
	player.global_position = game.level.spots.square[0]
	player.velocity = Vector3.ZERO
	player._busy = 0.0
	game._click(Vector3(aim.x, 0, aim.z))
	check(not fishing.is_fishing() and fishing._walk_kind == "teich" and not player.path.is_empty(), "a click on a far pond walks the hero there")
	var shore: Vector3 = player.path[-1]
	check(Level.water_distance(game.level.nearest_water(shore, 99.0), shore) <= Fishing.RANGE and game.level.nearest_water(shore, 99.0).water == "teich", "the walk ends on the shore of the pond")
	player.global_position = Vector3(shore.x, 0, shore.z)
	player.path.clear()
	fishing.tick(0.1)
	check(fishing.state == Fishing.WAITING and fishing._walk_kind == "", "at the shore the line goes out")
	_key_g()
	# A click elsewhere on the way forgets the pond.
	player.global_position = game.level.spots.square[0]
	game._click(Vector3(aim.x, 0, aim.z))
	game._click(game.level.spots.square[0] + Vector3(2, 0, 0))
	check(fishing._walk_kind == "", "a click elsewhere forgets the pond")
	player.path.clear()

	for text in [Fishing.MONSTER_LORE, "Blubb!", "Neben dem Schwimmer taucht ein kleines Teichungeheuer auf!",
			"Das kleine Teichungeheuer schnappt sich deinen Köder und taucht damit ab!",
			"Das kleine Teichungeheuer taucht wieder ab. Du wartest weiter …"]:
		check(Lang.EN.has(text), "\"%s\" has an English text" % text)

	# Better odds in a row: after five bites weed is rare.
	var row_weed := 0
	for i in 1000:
		if Fishing.roll("teich", 12.0, rng, Fishing.MAX_CHAIN) == "":
			row_weed += 1
	check(row_weed < 20, "after a long row of bites hardly any weed comes in (%d of 1000)" % row_weed)
	# A message in a bottle: coins and a note (once every treasure map is
	# found; see tests/treasure_maps.gd for the maps).
	for id in TreasureMaps.MAPS:
		game.treasure_maps.state[id] = TreasureMaps.DONE
	coins_before = game.coins
	fishing.take("flasche", player.global_position, game.level)
	check(game.coins >= coins_before + Fishing.BOTTLE_COINS[0] and game.coins <= coins_before + Fishing.BOTTLE_COINS[1], "a bottle holds a few coins")
	for note in Fishing.BOTTLE_NOTES:
		check(Lang.EN.has(note), "the bottle note %s has English" % note)
	# The long-lost ring: rare, once only, and kept in the saved game.
	check(Fishing.is_rare(Fishing.RING) and Items.ALL.has(Fishing.RING) and Lang.EN.has(Items.ALL[Fishing.RING].name), "the long-lost ring is a rare item")
	seen.clear()
	for i in 3000:
		seen[Fishing.roll("teich", 12.0, rng, 3)] = true
	check(seen.has(Fishing.RING), "the ring can be fished up in the village pond")
	fishing.ring_found = false
	fishing.take(Fishing.RING, player.global_position, game.level)
	check(fishing.ring_found and player.bag.has(Fishing.RING), "the ring goes into the bag")
	var ring_again := false
	for i in 3000:
		if Fishing.roll("teich", 12.0, rng, 3, true) == Fishing.RING:
			ring_again = true
	check(not ring_again, "the ring is fished up only once")
	game.save_game()
	check(game._read_save(game.save_path()).get("fished_ring", false) == true, "the saved game remembers the ring")
	player.bag.erase(Fishing.RING)

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
