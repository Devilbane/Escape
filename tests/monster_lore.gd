extends SceneTree
## Headless test: monster knowledge (see MonsterLore). Slain monsters are
## counted per kind through the event bus; the count climbs named ranks whose
## chance of a vital hit never passes 50 %. A vital strike is a leap at the
## foe ending in an overhead chop, with a flash on the monster; it deals
## twice the hero's hardest blow with no roll, may slow the monster's attacks
## for the rest of the fight and may make it bleed; bleeding to death is the
## hero's kill. The counts go into the saved game, and the compendium shows them on
## a page of their own whose tabs still fit the window.
## Run with: godot --headless --fixed-fps 60 -s tests/monster_lore.gd
## With SHOTS=<folder> and a display it saves the compendium page.

var failures := 0
var game: Node
var frames := 0
var shots := OS.get_environment("SHOTS")
const BIG_HP := 500
const POWER := 4


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _foe(kind := "krieger") -> Enemy:
	# Alone with the hero: no sweep, nobody else strikes.
	for e in game.level.enemies:
		if is_instance_valid(e):
			e.queue_free()
	game.level.enemies.clear()
	var foe := Enemy.new()
	foe.kind = kind
	foe.level = game.level
	game.level.add_child(foe)
	game.level.enemies.append(foe)
	_ready_up(foe)
	return foe


## Puts the foe right in front of the hero again, facing them (no sneak
## attack), harmless and too tough to fall, and readies the hero's blade.
func _ready_up(foe: Enemy) -> void:
	var player: Player = game.player
	player.face(Vector3(0, 0, 1))
	player.hp = player.max_hp
	player._attack_cooldown = 0.0
	player._auto_cooldown = 99.0
	player.power = POWER
	player._busy = 0.0
	foe.hp = BIG_HP
	foe.hardening = 0
	foe._awake = false
	foe._cooldown = 99.0
	foe._knockback = Vector3.ZERO
	foe._bleed_ticks = 0
	foe.global_position = player.global_position + Vector3(0, 0, 1.8)
	foe.velocity = Vector3.ZERO
	foe._model.rotation.y = PI
	foe.reset_physics_interpolation()


func _test() -> void:
	seed(7)
	MonsterLore.clear()
	var player: Player = game.player

	# The curve: named steps, never past the cap.
	check(MonsterLore.vital_chance("krieger") == 0.0, "an unknown kind gives no vital hits")
	var last := -1.0
	for r in MonsterLore.RANKS:
		check(float(r[1]) > last and float(r[1]) <= MonsterLore.CAP, "each rank gives more, up to the cap")
		last = float(r[1])
	check(is_equal_approx(last, 0.5), "the last rank is the 50 % cap")
	MonsterLore.kills["krieger"] = 100000
	check(is_equal_approx(MonsterLore.vital_chance("krieger"), 0.5), "however many kills, the chance stays at 50 %")
	check(MonsterLore.kills_to_next("krieger") == 0, "the last rank has no next")
	MonsterLore.clear()

	# Kills arrive through the bus, and a new rank is told.
	for i in 4:
		Events.bus().enemy_slain.emit("wolf")
	check(MonsterLore.kill_count("wolf") == 4 and MonsterLore.rank_of("wolf") == 0, "four wolves: counted, no rank yet")
	Events.bus().enemy_slain.emit("wolf")
	check(MonsterLore.rank_of("wolf") == 1 and is_equal_approx(MonsterLore.vital_chance("wolf"), 0.05), "the fifth wolf reaches the first rank (5 %)")
	check(game._message.text.contains(Lang.t(MonsterLore.monster_name("wolf"))), "the new rank is told: %s" % game._message.text)
	check(game.lore.has(MonsterLore.LEARN), "the compendium learns how monster lore works")

	# Saved and loaded.
	var saved := MonsterLore.for_save()
	MonsterLore.clear()
	MonsterLore.load_from(JSON.parse_string(JSON.stringify(saved)))
	check(MonsterLore.kill_count("wolf") == 5, "the count comes back from the saved game")
	MonsterLore.load_from("nonsense")
	check(MonsterLore.kills.is_empty(), "an old saved game starts knowing nothing")

	# Vital damage: twice the hardest blow, no roll.
	player.power = POWER
	var hardest := POWER + (1 if player.skill_chance(player.weapon_skill()) > 0 else 0)
	check(player.vital_damage(POWER, player.weapon_skill()) == 2 * hardest, "a vital hit is twice the hardest blow")

	# Blows at a well-known kind: about half are vital, each exactly the vital damage.
	MonsterLore.kills["krieger"] = 1000
	var foe := _foe()
	var vitals := 0
	var plain := 0
	for i in 60:
		_ready_up(foe)
		foe.attack_slow = 1.0
		foe._bleed_ticks = 0
		player.melee()
		# The strike shows at once whether it will find a vital point.
		var thrust: bool = player._current_anim == Player.VITAL_ANIM
		await _wait(10)
		# Mid-leap the figure is off the ground and closer to the foe.
		var lunged: bool = player._model.position.y > 0.2 and player._model.position.z > 0.1
		await _wait(25)
		var lost := BIG_HP - foe.hp
		if lost == player.vital_damage(POWER, player.weapon_skill()):
			vitals += 1
			check(thrust and lunged, "a vital strike is a leap and an overhead chop")
			check(_has_flash(foe), "the vital point flashes")
		elif lost in [POWER, POWER + 1]:
			plain += 1
			check(not thrust and player._current_anim != Player.VITAL_ANIM, "a plain strike is the usual slice")
		else:
			check(false, "a blow is either plain or vital: %d (hp %d, bleeding %s)" % [lost, foe.hp, foe.is_bleeding()])
	print("vital hits: %d of 60, plain: %d" % [vitals, plain])
	check(vitals >= 15 and plain >= 15, "about half the blows find a vital point (%d of 60)" % vitals)

	# An unknown kind never gets one.
	MonsterLore.clear()
	vitals = 0
	for i in 15:
		_ready_up(foe)
		player.melee()
		await _wait(20)
		if BIG_HP - foe.hp > POWER + 1:
			print("unknown kind, lost %d" % (BIG_HP - foe.hp))
			vitals += 1
	check(vitals == 0, "no vital hits on a kind never slain")

	# Crippled: slower attacks until the fight is over.
	foe.hp = BIG_HP
	foe.attack_slow = 1.0
	check(foe.cripple(), "a plain monster can be crippled")
	check(foe.attack_slow == MonsterLore.SLOW_FACTOR, "crippled, it attacks slower")
	foe._cooldown = 1.0
	await physics_frame
	await physics_frame
	check(foe._cooldown > 1.0 - 2.0 / 60.0 / MonsterLore.SLOW_FACTOR - 0.01 and foe._cooldown < 1.0, "its attacks come round slower: %.3f" % foe._cooldown)
	foe._awake = false
	foe._lost = 999.0
	await physics_frame
	await physics_frame
	check(foe.attack_slow == 1.0 or foe.is_hunting(), "after the fight the slow wears off")

	# Bleeding: three drops of life, and bleeding to death is the hero's
	# kill. The hero steps away, so nobody else strikes it.
	player.global_position += Vector3(30, 0, 0)
	player.reset_physics_interpolation()
	foe.hp = 10
	foe.bleed()
	check(foe.is_bleeding(), "a vital hit can make it bleed")
	var t := 0.0
	while foe.is_bleeding() and t < 8.0:
		await physics_frame
		t += 1.0 / 60.0
	check(foe.hp == 10 - MonsterLore.BLEED_TICKS, "it bled %d life: %d left" % [MonsterLore.BLEED_TICKS, foe.hp])
	# Felled by its wound, it dies as from the hero's blow (no rival's kill),
	# so the level hands it on like any other kill (see Level enemy_killed).
	var fell := [false]
	foe.died.connect(func(): fell[0] = true)
	foe.hp = 1
	foe.bleed()
	t = 0.0
	while not foe.dead and t < 3.0:
		await physics_frame
		t += 1.0 / 60.0
	check(foe.dead and fell[0] and not foe.slain_by_rival, "bleeding to death is a kill of the hero's")

	# The compendium page, in both languages: the tabs fit the window.
	for kind in Creations.MONSTER_NAMES:
		MonsterLore.kills[kind] = 9999
	MonsterLore.kills["krieger"] = 12
	game.crafting.learn_recipe(Crafting.RECIPES.keys()[0])
	var old_language := Lang.language
	for lang in ["de", "en"]:
		# Switched for this run only (Lang.choose would save it for later tests).
		Lang.language = lang
		Lang._apply()
		game.menus.compendium_page = "monster"
		game.menus.open("kompendium")
		await _wait(4)
		var size: Vector2 = game.menus._panel.size
		check(size.x <= Menus.WINDOW_SIZES.kompendium.x + 60, "the compendium keeps its width with five tabs: %s" % size)
		var tabs: HBoxContainer = game.menus._box.get_child(1)
		check(tabs.get_child_count() == 5, "five tabs once monsters are known: %d" % tabs.get_child_count())
		for b: Button in tabs.get_children():
			var font := b.get_theme_font("font")
			var wide := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			check(wide <= b.size.x - 8, "the tab text fits (%s): %d in %d" % [b.text, wide, b.size.x])
		if shots != "":
			DirAccess.make_dir_recursive_absolute(shots)
			await _wait(4)
			root.get_texture().get_image().save_png(shots.path_join("monster_lore_%s.png" % lang))
		game.menus.close()
	Lang.language = old_language
	Lang._apply()
	_finish()


## Whether a vital hit's flash (a billboard quad, see Enemy.vital_burst) or
## its sparks are still on the foe.
func _has_flash(foe: Enemy) -> bool:
	for c in foe.get_children():
		if c is CPUParticles3D or (c is MeshInstance3D and c.mesh is QuadMesh):
			return true
	return false


func _finish() -> void:
	if failures == 0:
		print("PASS: monster lore")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
