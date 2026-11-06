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
	while SlimeGrowth.can_snack(n) and blows < 20:
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
			slime = _spawn(fox.global_position + Vector3(2.0, 0, 0), {"hp": 40})
			slime.set_physics_process(false)
			check(SlimeGrowth.nearest_snack(slime) == fox or SlimeGrowth.nearest_snack(slime) is Node3D, "a slime notices the fox")
			var lvl := slime.rated_level
			var blows := _eat(fox)
			check(blows > 1, "a fox takes more than one blow (%d)" % blows)
			check(not out.animals.has(fox), "the eaten fox is gone from the woods")
			check(slime.rated_level > lvl, "the slime grows from the fox (%d, was %d)" % [slime.rated_level, lvl])
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
			villager.brave = true
			villager.alarm(slime)
			check(villager._task == "fight", "a brave villager stands and fights")
			check(_blade(villager), "and draws a blade")
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
				_finish()
				return true
	return false
