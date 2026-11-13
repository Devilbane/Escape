extends SceneTree
## Headless test for Zarek the wandering merchant as a level 50 mage: a lot of
## life by the game's own formula, a staff only in danger, and spells at every
## slime in sight that fly as magic shots, from a distance.
## Run with: godot --headless --fixed-fps 60 -s tests/zarek_mage.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var slime: Enemy
var zarek: Villager
var hp_before := 0
var saw_shot := false
var worst := 0.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(9)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: zarek mage" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _gone() -> bool:
	return not is_instance_valid(slime) or slime.dead


func _staff() -> Node:
	var hand := zarek._model.find_child("handslot_r", true, false)
	var b := hand.get_node_or_null("SlimeBlade") if hand else null
	return b if b != null and not b.is_queued_for_deletion() else null


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	stage_frames += 1
	if stage > 0:
		game.day_hour = 22.0
		game.level.day = 1
	if stage > 0 and not is_instance_valid(zarek):
		check(false, "Zarek is still in the village (stage %d, frame %d, level wanderer %s)" % [stage, stage_frames, str(game.level.wanderer)])
		_finish()
		return true
	if stage > 0:
		var post: Vector3 = game.level.cell_to_world(zarek.home)
		var off := Vector2(zarek.global_position.x - post.x, zarek.global_position.z - post.z).length()
		worst = maxf(worst, off)
	match stage:
		0:
			check(VillageArms.style("%") == "cast", "Zarek is a caster")
			var probe := Villager.new()
			probe.role = "%"
			check(probe.fight_level() == 50, "Zarek is level 50")
			check(probe.max_life() == 50 * Villager.LIFE_PER_LEVEL and probe.max_life() > Villager.LEVELS["4"] * Villager.LIFE_PER_LEVEL * 2, "his life follows the level formula, far above the guard's")
			check(probe.blow() * VillageArms.BOLT_FACTOR > 40, "his spells hit hard")
			probe.free()
			game.hero_name = "Zarek mage test"
			game.day = 1
			game.day_hour = 21.5
			game.load_level(game._outdoor_index(), false)
			var out: Outdoor = game.level
			out.day = game.day
			out.set_hour(game.day_hour)
			zarek = out.wanderer
			check(zarek != null, "Zarek is in the village")
			if zarek == null:
				_finish()
				return true
			check(_staff() == null, "no staff in hand while all is quiet")
			slime = Enemy.new()
			slime.kind = "schleim"
			slime.level = out
			slime.custom = {"hp": 150, "damage": 1}
			out.add_child(slime)
			out.enemies.append(slime)
			slime.set_physics_process(false)
			slime.rated_level = 8
			slime.global_position = zarek.global_position + Vector3(7.0, 0, 0)
			slime.reset_physics_interpolation()
			slime.hp = 120
			hp_before = slime.hp
			stage = 1
			stage_frames = 0
		1:
			# Nobody has called him: he goes for the slime in sight himself.
			if zarek._task == "fight":
				check(_staff() != null, "the staff is out in danger")
				check(zarek.threat == slime, "he fights the slime he sees")
			for n in game.level.get_children():
				if n is Projectile and n.magic and n.at_rival:
					saw_shot = true
			if _gone() or stage_frames > 900:
				check(zarek._casts >= 1, "he cast spells")
				check(saw_shot, "his spells fly as magic shots")
				check(_gone() or slime.hp < hp_before, "the slime is hurt or slain")
				stage = 2
				stage_frames = 0
		2:
			if zarek.threat == null and zarek._task != "fight":
				stage = 3
				stage_frames = 0
			elif stage_frames > 600:
				check(false, "he calms down after the slime falls")
				_finish()
				return true
		3:
			if stage_frames > 400:
				check(_gone(), "the slime is gone")
				check(_staff() == null, "the staff goes back once the danger is over")
				check(worst < VillageArms.CAST_LEASH + 2.0, "he stays near his wagon (went %.1f m from it)" % worst)
				_finish()
				return true
	return false
