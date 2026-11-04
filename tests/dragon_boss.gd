extends SceneTree
## Headless test for the dragon boss fight: the dragon of the lair has a
## health bar that waits until the fight starts, wakes with a roar, a stab
## in the back no longer kills it outright, its fire breath leaves burning
## fields that hurt and set the hero burning but not the dragon, it goes
## through three phases, takes double damage while winded, and its fire dies
## with it.
## Run with: godot --headless --fixed-fps 60 -s tests/dragon_boss.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var dragon: Dragon
var awakened := 0
var field: FireField
var hero_hp := 0
var dragon_hp := 0
var saw_rings := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(21)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: dragon boss")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _fields() -> Array:
	return game.level.get_tree().get_nodes_in_group("fire_field").filter(func(f): return is_instance_valid(f) and not f.is_queued_for_deletion())


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var player: Player = game.player
	# Keep the hero standing: this test is about the dragon's fire.
	if player.hp <= 3 and stage != 3:
		player.hp = player.max_hp
	match stage:
		0:
			game.hero_name = "Dragon test"
			# A hero of the level the place is made for, in its reference gear (see HeroLevel).
			HeroLevel.dress(game.player, 11)
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			game.player.global_position = game.level.doors.E
			# The dragon sleeps on the lair's third floor (see DragonLair).
			game.go_inside("E3")
			stage = 1
		1:
			stage_frames += 1
			if stage_frames < 60:
				return false
			var lvl: Level = game.level
			check(lvl.lair, "in the dragon's lair")
			dragon = lvl.dragon
			check(dragon != null and dragon is Dragon, "the lair's dragon is a boss")
			if dragon == null:
				_finish()
				return true
			check(dragon.max_hp() >= 30, "the dragon is tough (%d life)" % dragon.max_hp())
			check(lvl.dragon_bar != null and not lvl.dragon_bar.wanted(), "its health bar waits until the fight starts")
			lvl.dragon_awakened.connect(func(_d): awakened += 1)
			# A stab in the back of the sleeping dragon only hurts it.
			var behind := dragon.global_position - dragon.ahead() * 2.0
			check(dragon.open_to_backstab(behind), "the sleeping dragon can be stabbed in the back")
			dragon.take_hit(2, behind, "backstab")
			check(not dragon.dead and dragon.hp == dragon.max_hp() - 2 * Dragon.BACKSTAB_FACTOR, "a stab in the back no longer kills the dragon (%d life left)" % dragon.hp)
			player.knives = 0
			player.global_position = dragon.global_position + Vector3(-7.0, 0, 0)
			player.hp = player.max_hp
			dragon._wake(player.global_position)
			stage = 2
			stage_frames = 0
		2:
			# It wakes with a roar and soon draws breath: red rings on the
			# floor, which catch fire.
			stage_frames += 1
			if stage_frames == 30:
				check(awakened == 1, "the dragon wakes with a roar (intro)")
				check(game.level.dragon_bar.wanted(), "the health bar shows during the fight")
			var fields := _fields()
			if not fields.is_empty() and not saw_rings:
				saw_rings = true
				check(fields.any(func(f): return not f.burning), "red rings warn before the fire falls")
			if fields.any(func(f): return f.burning):
				check(saw_rings, "the breath came with a warning")
				stage = 3
				stage_frames = 0
			elif stage_frames > 900:
				check(false, "the dragon breathed no fire within 15 seconds")
				_finish()
				return true
		3:
			# Stand in a burning field, far from the dragon: it hurts and
			# sets the hero alight.
			if stage_frames == 0:
				player.global_position = game.level.cell_to_world(game.level.start_cell)
				player.velocity = Vector3.ZERO
				player.hp = player.max_hp
				player.cure()
				hero_hp = player.hp
				field = FireField.spawn(game.level, player.global_position, 0.3)
			stage_frames += 1
			player.global_position.x = field.global_position.x
			player.global_position.z = field.global_position.z
			if player.ailments.has("brand") and player.hp < hero_hp:
				stage = 4
				stage_frames = 0
			elif stage_frames > 150:
				check(player.hp < hero_hp, "the fire field hurts the hero")
				check(player.ailments.has("brand"), "the fire field sets the hero burning")
				stage = 4
				stage_frames = 0
		4:
			# A burning field under the dragon does not hurt it.
			if stage_frames == 0:
				FireField.spawn(game.level, dragon.global_position, 0.0)
				dragon_hp = dragon.hp
			stage_frames += 1
			if stage_frames < 150:
				return false
			check(dragon.hp >= dragon_hp, "dragons are not hurt by fire")
			# Three phases.
			dragon.hp = dragon.max_hp()
			dragon.phase = 1
			dragon.take_hit(int(dragon.max_hp() * 0.45), player.global_position, "hit", false)
			check(dragon.phase == 2, "below 60 %% of its life the dragon is furious (phase %d)" % dragon.phase)
			dragon.take_hit(int(dragon.max_hp() * 0.3), player.global_position, "hit", false)
			check(dragon.phase == 3, "below 30 %% of its life the dragon rages (phase %d)" % dragon.phase)
			# Winded, it takes double damage.
			dragon._winded = 1.0
			var before := dragon.hp
			dragon.take_hit(1, player.global_position, "hit", false)
			check(before - dragon.hp == 2, "a winded dragon takes double damage")
			check(dragon.is_dazed(), "the health bar can show it winded")
			# It falls, and its fire dies with it.
			dragon.take_hit(99, player.global_position)
			check(dragon.dead, "the dragon falls")
			check(game.level.lair_cleared, "the fallen dragon wins the lair")
			stage = 5
			stage_frames = 0
		5:
			stage_frames += 1
			if stage_frames < 5:
				return false
			check(_fields().is_empty(), "the dragon's fire dies with it")
			_finish()
			return true
	return false
