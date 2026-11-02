extends SceneTree
## Headless test for the bandit chief, the boss of the robbers' pass: he has
## a health bar, calls his cutthroats below two thirds of his life, rams the
## hero with his shield, charges once enraged (and is dazed when he misses),
## shrugs off a single backstab, falls only once per saved game and drops his
## unique blade, which waits for the hero even after a reload.
## Run with: godot --headless --fixed-fps 60 -s tests/bandit_chief.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var chief: BanditChief
var knockdowns_before := 0
var hero_hp := 0
var dodged := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: bandit chief")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _heal() -> void:
	var player: Player = game.player
	player.hp = player.max_hp
	player.dead = false


## The hero stands `metres` in front of the chief, facing him.
func _face_chief(metres: float) -> void:
	var player: Player = game.player
	player.global_position = chief.global_position + chief.ahead() * metres
	player.velocity = Vector3.ZERO
	player.path.clear()


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	stage_frames += 1
	var lvl = game.level
	var player: Player = game.player
	match stage:
		0:
			game.hero_name = "Chief test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			lvl = game.level
			chief = lvl.chief
			check(chief != null and chief is BanditChief, "the chief of the pass is a boss")
			if chief == null:
				_finish()
				return true
			check(chief.max_hp() >= 20, "the chief has a boss's life (%d)" % chief.max_hp())
			check(lvl.boss_bar != null and not lvl.boss_bar.wanted(), "his health bar waits until the fight starts")
			check(Items.ALL.has(BanditChief.TROPHY) and Items.ALL[BanditChief.TROPHY].get("no_loot", false), "his blade is unique, never found elsewhere")
			check(not lvl.chief_defeated(), "a new game starts with the chief standing")
			_heal()
			_face_chief(2.0)
			stage = 1
			stage_frames = 0
		1:
			_heal()
			if stage_frames == 60:
				check(chief.is_hunting(), "the chief notices the hero in front of him")
				check(lvl.boss_bar.wanted(), "the health bar shows during the fight")
				# A backstab is no instant kill for him.
				var before := chief.hp
				chief.take_hit(1, player.global_position, "backstab")
				check(not chief.dead and chief.hp == before - BanditChief.BACKSTAB_FACTOR, "a stab in the back hurts the chief but does not end him")
				# Phase 2: below two thirds he calls his cutthroats.
				chief.take_hit(chief.hp - int(chief.max_hp() * 0.6), player.global_position)
				check(chief.phase == 2, "below two thirds of his life the chief enters phase 2")
				check(lvl.called_alive() == BanditChief.CALL_COUNT, "he calls %d cutthroats (%d came)" % [BanditChief.CALL_COUNT, lvl.called_alive()])
				check(lvl._called.all(func(e): return e.is_hunting()), "the called cutthroats join the fight at once")
				check(lvl.bandits_alive() + lvl.beasts_alive() == lvl._wild.filter(func(s): return not Enemy.KINDS[s.kind].get("mountain", false)).size(), "called cutthroats do not take any bandit's spot")
				# Shield bash next: the hero stands right in front of him.
				_face_chief(1.8)
				chief._bash_timer = 0.0
				chief._cooldown = 0.0
				knockdowns_before = player.knockdowns
				stage = 2
				stage_frames = 0
		2:
			if player.hp <= 2:
				_heal()
			if player.knockdowns > knockdowns_before:
				# Phase 3: enraged, he charges from afar.
				player._down = 0.0
				player._falling = 0.0
				_heal()
				chief.take_hit(chief.hp - int(chief.max_hp() * 0.3), player.global_position)
				check(chief.phase == 3, "below one third of his life the chief is enraged (phase 3)")
				_face_chief(9.0)
				chief._charge_timer = 0.0
				chief._bash_timer = 99.0
				stage = 3
				stage_frames = 0
			elif stage_frames > 300:
				check(false, "the chief's shield bash knocks the hero down")
				stage = 99
		3:
			_heal()
			player._invulnerable = 1.0
			if chief._charging > 0.0 and not dodged:
				# The hero steps aside as he comes running.
				dodged = true
				var side := chief._charge_dir.cross(Vector3.UP).normalized()
				player.global_position += side * 5.0
			if chief.is_dazed():
				check(dodged, "the chief winds up and charges the hero")
				var before := chief.hp
				chief.take_hit(1, player.global_position)
				check(chief.hp == before - 2, "a dazed chief takes double damage")
				stage = 4
				stage_frames = 0
			elif stage_frames > 400:
				check(false, "a missed charge leaves the chief dazed")
				stage = 99
		4:
			# Fell him.
			_heal()
			var pickups_before: int = lvl._pickups.size()
			var where: Vector3 = chief.global_position
			chief.take_hit(chief.hp, player.global_position)
			check(chief.dead, "the chief falls")
			check(lvl.chief_defeated() and game._looted_for_save().values().any(func(ids): return Outdoor.CHIEF_DEFEATED in ids), "his fall is kept in the saved game")
			var drops: Array = lvl._pickups.slice(pickups_before)
			check(drops.any(func(p): return p.get("id", "") == BanditChief.TROPHY), "he drops his unique blade")
			check(drops.filter(func(p): return p.kind == "coin").size() >= Outdoor.CHIEF_GOLD, "his purse spills plenty of gold")
			var spot: Array = lvl._wild.filter(func(s): return s.kind == "hauptmann")
			check(spot.size() == 1 and spot[0].timer == INF, "nobody takes the chief's place")
			print("the chief fell at ", where)
			stage = 5
			stage_frames = 0
		5:
			if stage_frames == 30:
				check(not lvl.boss_bar.wanted(), "the health bar goes once he has fallen")
				# Save, load the save, and come back to the pass: no chief,
				# but his blade still lies there, since nobody picked it up.
				check(game.save_game(), "the game saves")
				game._apply_save(game._read_save(game.save_path()))
				game.load_level(game._outdoor_index(), false)
				game.state = game.State.PLAYING
				stage = 6
				stage_frames = 0
		6:
			if stage_frames == 10:
				check(lvl.chief == null and lvl.enemies.all(func(e): return e.kind != "hauptmann"), "after a reload the chief stays beaten")
				var blades: Array = lvl._pickups.filter(func(p): return p.get("id", "") == BanditChief.TROPHY)
				check(blades.size() == 1, "his blade still waits where he fell")
				if blades.size() == 1:
					player.global_position = blades[0].node.global_position
					lvl._check_pickups()
				check(BanditChief.TROPHY in player.bag, "the hero picks up the blade")
				game.load_level(game._outdoor_index(), false)
				game.state = game.State.PLAYING
				stage = 7
				stage_frames = 0
		7:
			if stage_frames == 10:
				check(lvl._pickups.all(func(p): return p.get("id", "") != BanditChief.TROPHY), "once picked up, the blade is not there twice")
				check(Lang.t(BanditChief.TITLE) != "" , "the chief has a name")
				stage = 99
		99:
			_finish()
			return true
	return false
