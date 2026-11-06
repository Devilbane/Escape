extends SceneTree
## Headless test for resting by the camp's fire on a dungeon floor (see
## Camp and Game.rest_at_camp): the camp's window offers the rest and tells
## the risk of an ambush; a quiet rest heals the hero fully and saves the
## game at the camp (so it is where they wake after blacking out); an
## ambush cuts the rest short with half the lost life back, saves nothing,
## and brings a few of the floor's own monsters, already on the hunt. A
## companion keeping watch lowers the risk, a stag stops it.
## Run with: godot --headless --fixed-fps 60 -s tests/camp_rest.gd
## With SHOTS=<folder> and a display it also saves pictures of the camp's
## window and of an ambush.

const HERO := "Camp rest test"

var failures := 0
var game: Node
var frames := 0
var stage := 0
var clock := 0.0
var before := 0
var known: Array = []


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
		print("PASS: camp_rest")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A spot on the floor with room for a camp and no monster near, or INF.
func _quiet_spot(level: Level) -> Vector3:
	for y in level.height:
		for x in level.width:
			var p: Vector3 = level.cell_to_world(Vector2i(x, y))
			if Camp._open(level, p) and not Camp.monster_near(level, p) and not Camp.find_spot(level, p, Vector3.FORWARD).is_empty() \
					and not Camp.ambush_cells(level, p, Camp.AMBUSHERS).is_empty():
				return p
	return Vector3.INF


func _buttons(node: Node) -> Array:
	return node.find_children("*", "Button", true, false).filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion())


func _shot(name: String) -> void:
	var shots := OS.get_environment("SHOTS")
	if shots != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(shots)
		root.get_texture().get_image().save_png(shots.path_join(name))


func _settled() -> bool:
	return game.state == game.State.PLAYING and not game.player.frozen


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
			for text in ["Am Feuer ausruhen", "Ausgeruht! Du hast wieder volles Leben.", game.CAMP_REST_LEARN,
					"Ein Hinterhalt! Ungeheuer schleichen sich an dein Lager heran.", "%s schlägt Alarm und weckt dich: Ein Hinterhalt!",
					"Mitten im Kampf kannst du dich nicht ausruhen."]:
				check(Lang.EN.has(text), "'%s' has English" % text)
			# The numbers the compendium tells are the game's.
			for chance in [Camp.AMBUSH_CHANCE, Camp.GUARDS.fuchs, Camp.GUARDS.reh]:
				check(game.CAMP_REST_LEARN.contains("(%d %%)" % roundi(chance * 100.0)), "the compendium tells the %d %% chance" % roundi(chance * 100.0))
			check(Camp.can_rest(level), "the hero can rest by the fire on a dungeon floor")
			level.outdoor = true
			check(not Camp.can_rest(level), "the open air has no rest by the fire")
			level.outdoor = false
			# Who may come: the floor's own plain monsters, never a boss.
			var kinds := Camp.ambush_kinds(level)
			check(not kinds.is_empty(), "monsters of this floor may creep up to the fire")
			for kind in kinds:
				check(not (kind in HeroLevel.BOSSES) and kind != "waechter" and not (kind in Enemy.HORRORS), "%s is a plain monster" % kind)
				check(level.monster_families.is_empty() or MonsterFamilies.fits(kind, level.monster_families), "%s belongs on this floor" % kind)
			# The guards.
			check(Camp.ambush_chance(level, "") == Camp.AMBUSH_CHANCE, "with nobody on watch the full chance")
			check(Camp.ambush_chance(level, "fuchs") < Camp.AMBUSH_CHANCE and Camp.ambush_chance(level, "reh") < Camp.AMBUSH_CHANCE, "a fox or a doe on watch makes an ambush rarer")
			check(Camp.ambush_chance(level, "hirsch") == 0.0, "nobody dares near a stag")
			# Pitch the camp.
			var spot := _quiet_spot(level)
			check(spot != Vector3.INF, "there is a quiet spot for a camp")
			if spot == Vector3.INF:
				_finish()
				return true
			player.global_position = Vector3(spot.x, 0.0, spot.z)
			player.velocity = Vector3.ZERO
			player.reset_physics_interpolation()
			if not player.bag.has(Camp.ITEM):
				player.bag.append(Camp.ITEM)
			game.camp_action()
			check(game.has_camp() and game.menus.current == "nachtlager", "a camp is pitched and its window opens")
			if not game.has_camp():
				_finish()
				return true
			var texts: Array = _buttons(game.menus._box).map(func(b): return b.text)
			check(Lang.t("Am Feuer ausruhen") in texts, "the camp's window offers the rest by the fire (%s)" % [texts])
			check(Lang.t("Schlafen und ausloggen") in texts, "it still offers to sleep and log out")
			check(game.menus.camp_risk_text().contains("%d" % roundi(Camp.AMBUSH_CHANCE * 100.0)), "the window tells the risk: %s" % game.menus.camp_risk_text())
			stage = 10
			clock = 0.0
		10:
			# A few frames for the window to settle, for the picture.
			if clock < 0.5:
				return false
			_shot("camp_window_%s.png" % (Lang.language if Lang.language != "" else "de"))
			game.menus.close()
			# Not in a fight.
			player.fight_cooldown = 3.0
			game.rest_at_camp(0.99)
			check(game.state == game.State.PLAYING and not player.frozen, "no rest in the middle of a fight")
			player.fight_cooldown = 0.0
			# A quiet rest.
			player.hp = 1
			game.rest_at_camp(0.99)
			check(player.frozen and game.state == game.State.TRANSITION, "the hero lies down to rest")
			clock = 0.0
			stage = 2
		2:
			if not _settled() and clock < 15.0:
				return false
			check(_settled(), "the hero gets up after the rest")
			check(player.hp == player.max_hp, "a quiet rest heals fully (%d / %d)" % [player.hp, player.max_hp])
			check(game.lore.has(game.CAMP_REST_LEARN), "the compendium explains the rest")
			check(game.has_slot_save(), "a quiet rest saves the game")
			var data: Dictionary = game._read_save()
			check(not Camp.from_save(data.get("camp")).is_empty(), "the save is at the camp, so the hero wakes there after blacking out")
			var place: Dictionary = game._wake_place(data)
			check(not place.camp.is_empty() and _flat(place.camp.pos, game.camp.global_position) < 0.05, "the wake-up place is this camp")
			check(game.has_camp() and _flat(player.global_position, game.camp.global_position) < Camp.NEAR, "the hero stands by the fire")
			# An ambush.
			game.delete_save(game.save_path())
			player.hp = 2
			known = game.level.enemies.duplicate()
			before = player.hp
			game.rest_at_camp(0.0)
			clock = 0.0
			stage = 3
		3:
			if not _settled() and clock < 15.0:
				return false
			check(_settled(), "the hero is up again after the ambush")
			check(player.hp > before and player.hp < player.max_hp, "an ambush leaves the wounds half healed (%d / %d)" % [player.hp, player.max_hp])
			check(player.hp == before + ceili((player.max_hp - before) / 2.0), "half the lost life comes back")
			check(not game.has_slot_save(), "an ambushed rest saves nothing")
			var fresh: Array = game.level.enemies.filter(func(e): return is_instance_valid(e) and not (e in known))
			check(fresh.size() >= 1 and fresh.size() <= Camp.AMBUSHERS, "a few monsters creep up (%d)" % fresh.size())
			var kinds := Camp.ambush_kinds(game.level)
			for e in fresh:
				check(e.kind in kinds, "%s is one of the floor's own" % e.kind)
				check(e.is_hunting(), "%s is after the hero" % e.kind)
				check(_flat(e.global_position, game.camp.global_position) <= Camp.AMBUSH_FAR + 2.0, "%s comes out of the dark close by" % e.kind)
			check(game.has_camp(), "the camp stays pitched")
			clock = 0.0
			stage = 4
		4:
			if clock < 1.2:
				return false
			_shot("camp_ambush.png")
			_finish()
			return true
	return false
