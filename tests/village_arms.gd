extends SceneTree
## Headless test for what the villagers fight a slime with (see VillageArms):
## the men carry blades that suit their trade, Pip throws knives from afar,
## and the priestess strikes no blow but heals the hurt, the hero too.
## Run with: godot --headless --fixed-fps 60 -s tests/village_arms.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var slime: Enemy
var pip: Villager
var hp_before := 0


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
		print("PASS: village arms")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _villager(out: Outdoor, role: String) -> Villager:
	for v in out.villagers:
		if v.role == role:
			return v
	return null


## Out in the street, as if it had been walking about.
func _out_and_about(v: Villager) -> void:
	v.at_home = false
	v.visible = true


func _held(v: Villager) -> Node:
	var hand := v._model.find_child("handslot_r", true, false)
	if hand == null:
		return null
	var blade := hand.get_node_or_null("SlimeBlade")
	return blade if blade != null and not blade.is_queued_for_deletion() else null


## Whether a weapon part of the model itself is in sight.
func _visible_weapon(v: Villager) -> bool:
	for part in Villager.WEAPON_PARTS:
		var m := v._model.find_child(part, true, false)
		if m is Node3D and (m as Node3D).visible:
			return true
	return false


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	stage_frames += 1
	var out: Outdoor = game.level as Outdoor
	match stage:
		0:
			game.hero_name = "Village arms test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			out = game.level as Outdoor
			out.village_alarm._check = 1e9
			# The table.
			check(VillageArms.style("7") == "throw" and VillageArms.style("O") == "heal" and VillageArms.style("4") == "melee", "Pip throws, the priestess heals, the guard fights close")
			check(VillageArms.weapon("4") != VillageArms.weapon("3"), "the guard and the woodcutter carry different weapons")
			check(Villager.HEAL == 8, "the priestess heals 8")
			check(not _villager(out, "7").shelters() and not _villager(out, "7").heals(), "Pip answers the call to arms")
			slime = Enemy.new()
			slime.kind = "schleim"
			slime.level = out
			slime.custom = {"hp": 60, "damage": 1}
			out.add_child(slime)
			out.enemies.append(slime)
			slime.set_physics_process(false)
			slime.rated_level = 8
			pip = _villager(out, "7")
			var guard := _villager(out, "4")
			var priestess := _villager(out, "O")
			check(pip != null and guard != null and priestess != null, "Pip, the guard and the priestess live in the village")
			if pip == null or guard == null or priestess == null:
				_finish()
				return true
			# The guard draws a sword, the priestess keeps her staff.
			_out_and_about(guard)
			guard.global_position = pip.global_position + Vector3(0, 0, 30)
			slime.global_position = guard.global_position + Vector3(1.5, 0, 0)
			slime.reset_physics_interpolation()
			guard.alarm(slime)
			check(guard._task == "fight" and _held(guard) != null, "the guard draws a blade")
			_out_and_about(priestess)
			priestess.alarm(slime)
			check(priestess._task == "fight" and _held(priestess) == null, "the priestess draws no blade")
			# The priestess heals the hero when no villager is hurt.
			game.player.global_position = priestess.global_position + Vector3(2, 0, 0)
			game.player.hp = 1
			check(priestess._heal_someone(), "she heals the hurt hero")
			check(game.player.hp == mini(game.player.max_hp, 1 + Villager.HERO_HEAL), "by %d (%d)" % [Villager.HERO_HEAL, game.player.hp])
			game.player.hp = game.player.max_hp
			check(not priestess._heal_someone(), "and nobody who is whole")
			priestess.calm_down()
			guard.calm_down()
			# Danger over: the blade stays out a moment, then goes back.
			check(guard.drawn(), "the guard's blade is still out right after the danger")
			guard._physics_process(Villager.SHEATHE_DELAY + 0.1)
			check(not guard.drawn(), "and is sheathed after the short delay")
			# At peace the guard shows no weapon, the woodcutter keeps his working axe.
			check(not _visible_weapon(guard), "the calm guard carries no visible weapon")
			check(_visible_weapon(_villager(out, "3")), "the woodcutter's working axe stays in sight")
			check(not _visible_weapon(_villager(out, "G")), "the guild master's axe is put away")
			guard.alarm(slime)
			check(guard.drawn() and not _visible_weapon(guard), "danger draws only the fighting blade")
			guard.calm_down()
			guard.alarm(slime)
			guard._physics_process(Villager.SHEATHE_DELAY + 0.1)
			check(guard.drawn(), "a new alarm cancels the sheathing")
			guard.calm_down()
			guard._physics_process(Villager.SHEATHE_DELAY + 0.1)
			# Pip throws knives from afar.
			_out_and_about(pip)
			slime.global_position = pip.global_position + Vector3(5.0, 0, 0)
			slime.reset_physics_interpolation()
			hp_before = slime.hp
			pip.alarm(slime)
			check(pip._task == "fight", "Pip stands up to the slime")
			check(_held(pip) != null, "with a dagger in his hand")
			stage = 1
			stage_frames = 0
		1:
			if stage_frames == 400:
				check(slime.hp < hp_before, "Pip's knives hurt the slime from a distance (%d, was %d)" % [slime.hp, hp_before])
				check(pip.global_position.distance_to(slime.global_position) > VillageArms.THROW_RANGE * 0.3 + 1.0, "Pip does not close to arm's length")
				_finish()
				return true
	return false
