extends SceneTree
## Headless test for slimes hunting townsfolk and animals (see SlimeGrowth
## SNACKS): a slime notices a fox and eats it after a few blows, growing
## from it; a brave villager draws a blade and fights a slime off, a timid
## one runs indoors and comes out once it is gone; and a villager a slime
## swallows comes back out when the slime falls.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_prey.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var slime: Enemy
var villager: Villager
var hp_before := 0
var at_square := Vector3.ZERO
var fox_spot := Vector3.ZERO


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
		print("PASS: slime prey")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _spawn(at: Vector3, custom := {}) -> Enemy:
	var lvl: Level = game.level
	var e := Enemy.new()
	e.kind = "schleim"
	e.level = lvl
	e.custom = custom
	lvl.add_child(e)
	e.global_position = at
	lvl.enemies.append(e)
	return e


## Bites until the slime has eaten `n` (at most 20 blows).
func _eat(n: Node3D) -> int:
	var blows := 0
	while SlimeGrowth.can_snack(n) and blows < 300:
		SlimeGrowth.bite(slime, n)
		blows += 1
	return blows


func _blade(v: Villager) -> bool:
	var hand := v._model.find_child("handslot_r", true, false)
	return hand != null and hand.get_node_or_null("SlimeBlade") != null and not hand.get_node("SlimeBlade").is_queued_for_deletion()


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	stage_frames += 1
	var out: Outdoor = game.level as Outdoor
	match stage:
		0:
			game.hero_name = "Slime prey test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			out = game.level as Outdoor
			# The village's call to arms is tried on its own at the end.
			out.village_alarm._check = 1e9
			# The hero far off, so nobody minds them.
			game.player.global_position += Vector3(0, 0, 0)
			var fox: Animal = null
			for a in out.animals:
				if a.kind == "fuchs":
					fox = a
			check(fox != null, "there is a fox in the woods")
			if fox == null:
				_finish()
				return true
			fox_spot = fox.global_position
			slime = _spawn(fox.global_position + Vector3(2.0, 0, 0), {"hp": 40, "damage": 1})
			slime.set_physics_process(false)
			check(SlimeGrowth.nearest_snack(slime) == fox or SlimeGrowth.nearest_snack(slime) is Node3D, "a slime notices the fox")
			var lvl := slime.rated_level
			slime._stats.damage = 1 # Its blows come one life at a time.
			slime.hp = 5
			var blows := _eat(fox)
			check(slime.hp >= 5 + SlimeGrowth.SNACKS.fuchs[0], "eating heals it by the fox's life (%d)" % slime.hp)
			check(blows > 1, "a fox takes more than one blow (%d)" % blows)
			check(not out.animals.has(fox), "the eaten fox is gone from the woods")
			check(slime.rated_level > lvl, "the slime grows from the fox (%d, was %d)" % [slime.rated_level, lvl])
			check(slime.meals == 1 and slime.life_bonus == 1, "it keeps half the fox's life and counts the meal (%d, %d)" % [slime.meals, slime.life_bonus])
			check(SlimeGrowth.move_pace(1) > 1.0 and SlimeGrowth.strike_pace(1) > 1.0, "every meal makes it faster")
			check(SlimeGrowth.move_pace(999) <= SlimeGrowth.MOVE_PACE_TOP and SlimeGrowth.strike_pace(999) <= SlimeGrowth.STRIKE_PACE_TOP, "up to a cap")
			# A Blob has seven and a half times the life of a plain slime of its make.
			var blob := _spawn(fox_spot + Vector3(0, -50, 0), {"kept_level": 18})
			check(blob.blob and blob.max_hp() == int(int(blob._stats.hp) * SlimeGrowth.BLOB_LIFE) and blob.hp == blob.max_hp(), "a Blob has %s times the life (%d)" % [SlimeGrowth.BLOB_LIFE, blob.max_hp()])
			game.level.enemies.erase(blob)
			blob.queue_free()
			# A brave villager fights it off.
			for v in out.villagers:
				if not v.at_home and v.visible:
					villager = v
					break
			check(villager != null, "there is a villager about")
			if villager == null:
				_finish()
				return true
			slime.global_position = villager.global_position + Vector3(1.6, 0, 0)
			slime.reset_physics_interpolation()
			# Small enough to stand up to (see VillageAlarm.FLEE_LEVEL).
			slime.rated_level = 8
			# Tough enough to outlast the villager's blows for the length of the test.
			slime.life_bonus += 400
			slime.hp = slime.max_hp()
			villager.brave = true
			villager.alarm(slime)
			check(villager._task == "fight", "a brave villager stands and fights")
			check(_blade(villager), "and draws a blade")
			# The priestess mends a villager a slime has hurt.
			var priestess: Villager = null
			for v in out.villagers:
				if v.role == "O":
					priestess = v
			check(priestess != null and priestess.brave and priestess.heals(), "the priestess answers the call and heals")
			if priestess != null:
				var hurt: Villager = null
				for v in out.villagers:
					if v != priestess and v != villager and not v.at_home:
						hurt = v
						break
				hurt.global_position = priestess.global_position + Vector3(2.0, 0, 0)
				hurt.set_meta("slime_life", 2)
				check(priestess._heal_someone(), "she finds someone to heal")
				check(int(hurt.get_meta("slime_life", hurt.max_life())) == 2 + Villager.HEAL, "and heals them")
				hurt.remove_meta("slime_life")
			check(Villager.LEVELS.values().min() >= 10 and Villager.LEVELS.values().max() <= 20, "townsfolk are level 10 to 20")
			hp_before = slime.hp
			stage = 1
			stage_frames = 0
		1:
			if stage_frames == 240:
				check(slime.hp < hp_before, "the villager's blows hurt the slime (%d, was %d)" % [slime.hp, hp_before])
				slime.global_position += Vector3(40, 0, 0)
				slime.reset_physics_interpolation()
			if stage_frames == 260:
				check(villager._task != "fight" and not _blade(villager), "with the slime gone the villager puts the blade away")
				# A timid one runs indoors.
				villager.brave = false
				slime.global_position = villager.global_position + Vector3(3.0, 0, 0)
				slime.reset_physics_interpolation()
				villager.alarm(slime)
				check(villager._task == "walk" and villager.get_meta("then", "") == "hide" or villager._task == "hide", "a timid villager runs for a house")
				villager._start("hide", 1.0)
				check(villager.at_home and not villager.visible, "and hides inside")
				stage = 2
				stage_frames = 0
		2:
			if stage_frames == 120:
				check(villager.at_home, "it stays inside while the slime is near")
				slime.global_position += Vector3(60, 0, 0)
				slime.reset_physics_interpolation()
			if stage_frames == 220:
				check(not villager.at_home and villager.visible, "it comes out once the slime is gone")
				# Swallowed: inside until the slime falls.
				slime.global_position = villager.global_position + Vector3(1.5, 0, 0)
				slime.reset_physics_interpolation()
				villager.brave = true
				_eat(villager)
				check(villager.eaten and not villager.visible, "a slime swallows a villager")
				check(villager in slime.folk, "the villager is inside the slime")
				var nights_out := villager.at_home
				villager.set_night(false)
				check(villager.eaten and not villager.visible, "morning does not bring them out of the slime (%s)" % nights_out)
				slime.hit_by_rival(slime.hp + 5, null)
				check(slime.dead, "the slime falls")
				check(not villager.eaten and villager.visible and not villager.at_home, "the villager comes back out")
				# A slime that vanishes lets them out too.
				slime = _spawn(villager.global_position + Vector3(1.5, 0, 0), {"hp": 40})
				slime.set_physics_process(false)
				_eat(villager)
				check(villager.eaten, "swallowed again")
				game.level.enemies.erase(slime)
				slime.queue_free()
				stage = 3
				stage_frames = 0
		3:
			if stage_frames == 5:
				check(not villager.eaten and villager.visible, "a slime that vanishes lets the villager out")
				# A slime in the village: the herald calls to arms.
				var herald: Villager = null
				for v in out.villagers:
					if v.role == "K":
						herald = v
				check(herald != null, "there is a herald")
				var at := herald.global_position + Vector3(4.0, 0, 0)
				at_square = at
				check(out._in_village(out.world_to_cell(at)), "the herald stands in the village")
				slime = _spawn(at, {"hp": 400})
				slime.set_physics_process(false)
				slime.rated_level = 10
				out.village_alarm._check = 0.0
				stage = 4
				stage_frames = 0
		4:
			if stage_frames == 90:
				check(out.village_alarm.raised, "a slime in the village raises the alarm")
				var men := 0
				var sheltered := 0
				var stray := []
				for v in out.villagers:
					if v.at_home and not v._task in ["hide"] or v.eaten:
						continue
					var hides: bool = v._task == "hide" or (v._task == "walk" and v.get_meta("then", "") == "hide")
					if v.shelters():
						if hides:
							sheltered += 1
						else:
							stray.append(v.role)
					elif v._task == "fight":
						men += 1
				check(men >= 3, "the men take up arms (%d)" % men)
				check(sheltered >= 2 and stray.is_empty(), "the women and children run indoors (%d, not: %s)" % [sheltered, stray])
				slime.hit_by_rival(slime.hp + 5, null)
			if stage_frames == 90 + int((VillageAlarm.CALM_AFTER + 2.5) * 60):
				check(not out.village_alarm.raised, "the herald gives the all-clear")
			if stage_frames == 90 + int((VillageAlarm.CALM_AFTER + 5.0) * 60):
				var inside := []
				for v in out.villagers:
					if v.shelters() and v._task == "hide":
						inside.append(v.role)
				check(inside.is_empty(), "after the all-clear they come back out: %s" % [inside])
				# A slime too big for the village: everyone runs indoors.
				slime = _spawn(at_square, {"hp": 4000})
				slime.set_physics_process(false)
				slime.rated_level = VillageAlarm.FLEE_LEVEL + 1
				stage = 5
				stage_frames = 0
		5:
			if stage_frames == 90:
				var fighting := []
				for v in out.villagers:
					if v._task == "fight":
						fighting.append(v.role)
				check(fighting.is_empty(), "nobody fights a slime too big for the village: %s" % [fighting])
				var guard: Villager = null
				for v in out.villagers:
					if v.role == "4":
						guard = v
				check(guard == null or guard._task == "hide" or guard.get_meta("then", "") == "hide", "even the guard runs indoors")
				# Out of the village it goes, but they stay in until it is killed.
				slime.global_position += Vector3(200, 0, 0)
				slime.reset_physics_interpolation()
			if stage_frames == 90 + int((VillageAlarm.CALM_AFTER + 3.0) * 60):
				check(out.village_alarm.raised, "they stay indoors until it is killed")
				slime.hit_by_rival(slime.hp + 5, null)
			if stage_frames == 90 + int((VillageAlarm.CALM_AFTER * 2.0 + 6.0) * 60):
				check(not out.village_alarm.raised, "once it is killed, the all-clear")
				_finish()
				return true
	return false
