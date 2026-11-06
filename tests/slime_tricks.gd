extends SceneTree
## Headless test for slime's tricks (see SlimeCoat): a slime takes only half
## of a knife, a bolt or an arrow (magic and fire in full); a blow on a slime
## may leave the striker slimed, slower on foot and between blows, coated in
## the slime's colour and dripping, until it wears off; and a slime spits a
## harmless gob, from a short reach and seldom, that slimes whoever it hits.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_tricks.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var spot := Vector3.INF
var slime: Enemy
var speed_before := 0.0
var cool_before := 0.0
var hp_before := 0


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
		print("PASS: slime tricks")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _spawn(kind: String, at: Vector3, custom := {}) -> Enemy:
	var lvl: Level = game.level
	var e := Enemy.new()
	e.kind = kind
	e.level = lvl
	e.custom = custom
	lvl.add_child(e)
	e.global_position = at
	lvl.enemies.append(e)
	return e


func _gone(e: Enemy) -> void:
	game.level.enemies.erase(e)
	e.queue_free()


## A straight row of free tiles at least `far` metres from the hero and every monster.
func _open_row(far: float) -> Vector3:
	var lvl: Level = game.level
	for y in range(2, lvl.height - 2):
		for x in range(2, lvl.width - 8):
			var free := true
			for i in 6:
				var c := Vector2i(x + i, y)
				if not lvl.astar.is_in_boundsv(c) or lvl.astar.is_point_solid(c):
					free = false
					break
			if not free:
				continue
			var at := lvl.cell_to_world(Vector2i(x, y))
			if at.distance_to(game.player.global_position) < far:
				continue
			if lvl.enemies.any(func(e): return is_instance_valid(e) and not e.dead and e.global_position.distance_to(at) < far):
				continue
			if not lvl.has_clear_shot(at, at + Vector3(Level.TILE * 5.0, 0, 0)):
				continue
			return at
	return Vector3.INF


func _coated(holder: Node3D) -> bool:
	if holder.get_node_or_null(SlimeCoat.NODE) == null:
		return false
	for mesh in holder.find_children("*", "MeshInstance3D", true, false):
		if (mesh as MeshInstance3D).material_overlay != null:
			return true
	return false


## Shots: half of a little shot, all of the rest.
func _check_shots() -> void:
	var hit := _spawn("schleim", spot + Vector3(0, -50, 0), {"hp": 40})
	var knifed := _spawn("schleim", spot + Vector3(3, -50, 0), {"hp": 40})
	var start := hit.hp
	check(knifed.hp == start, "two slimes alike for the test")
	hit.take_hit(6, hit.global_position + Vector3.FORWARD, "hit", false)
	knifed.take_hit(6, knifed.global_position + Vector3.FORWARD, "knife", false)
	var full := start - hit.hp
	var half := start - knifed.hp
	check(full > 0 and (half * 2 == full or half * 2 == full - 1), "a knife does half to a slime (%d of %d)" % [half, full])
	# Little knives add up: two of 1 do 1 between them.
	knifed.absorbed = 0.0
	var had := knifed.hp
	knifed.take_hit(1, knifed.global_position, "knife", false)
	knifed.take_hit(1, knifed.global_position, "knife", false)
	check(had - knifed.hp == 1, "two knives of 1 do 1 to a slime (%d)" % (had - knifed.hp))
	# A bolt from a rival is a little shot too; a mage's orb is not.
	var bolted := _spawn("schleim", spot + Vector3(6, -50, 0), {"hp": 40})
	var orbed := _spawn("schleim", spot + Vector3(9, -50, 0), {"hp": 40})
	bolted.hit_by_rival(6, null, true)
	orbed.hit_by_rival(6, null, false)
	check(start - orbed.hp == full, "magic hits a slime in full (%d)" % (start - orbed.hp))
	check(start - bolted.hp == half, "a bolt does half to a slime (%d)" % (start - bolted.hp))
	# Anything else takes a knife in full.
	var bandit := _spawn("halsabschneider", spot + Vector3(12, -50, 0), {"hp": 40})
	var bandit_hp := bandit.hp
	var rogue := _spawn("halsabschneider", spot + Vector3(15, -50, 0), {"hp": 40})
	bandit.take_hit(6, bandit.global_position, "knife", false)
	rogue.take_hit(6, rogue.global_position, "hit", false)
	check(bandit_hp - bandit.hp == bandit_hp - rogue.hp, "a bandit takes a knife in full (%d)" % (bandit_hp - bandit.hp))
	for e in [hit, knifed, bolted, orbed, bandit, rogue]:
		_gone(e)


## Slimed rivals: slower, coated; ghosts and slimes are not.
func _check_rivals() -> void:
	var bandit := _spawn("halsabschneider", spot + Vector3(0, -50, 0))
	var ghost := _spawn("totengeist", spot + Vector3(3, -50, 0))
	var other := _spawn("schleim", spot + Vector3(6, -50, 0))
	bandit.get_slimed(Color(1, 0, 0))
	check(bandit.slimed > 0.0, "a bandit gets slimed")
	check(_coated(bandit), "the slime shows on the bandit")
	ghost.get_slimed(Color(1, 0, 0))
	other.get_slimed(Color(1, 0, 0))
	check(ghost.slimed <= 0.0 and other.slimed <= 0.0, "slime does not stick to a ghost or a slime")
	bandit._tick_slime(SlimeCoat.TIME + 0.1)
	check(bandit.slimed <= 0.0, "the slime wears off a bandit")
	for e in [bandit, ghost, other]:
		_gone(e)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var player: Player = game.player
	stage_frames += 1
	match stage:
		0:
			game.hero_name = "Slime test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			spot = _open_row(60.0)
			check(spot != Vector3.INF, "there is open ground for the test")
			if spot == Vector3.INF:
				_finish()
				return true
			check(SlimeCoat.SPIT_REACH < float(Enemy.KINDS.schuetze.reach) * 0.5, "a slime spits far less far than an archer shoots")
			check(SlimeCoat.SPIT_COOL > float(Enemy.KINDS.schuetze.cooldown) * 2.0, "a slime spits far less often than an archer shoots")
			_check_shots()
			_check_rivals()
			# The hero strikes a slime until it sticks.
			player.global_position = spot
			player.reset_physics_interpolation()
			speed_before = player.speed
			slime = _spawn("schleim", spot + Vector3(0, -50, 0), {"hp": 40, "tint": Color(0.25, 0.55, 1.0)})
			for i in 40:
				if player.ailments.has(SlimeCoat.KIND):
					break
				player._touch_slime(slime)
			check(player.ailments.has(SlimeCoat.KIND), "a blow on a slime slimes the hero")
			check(player.speed < speed_before * 0.8, "slimed, the hero is slower (%.2f, was %.2f)" % [player.speed, speed_before])
			check(_coated(player), "the slime shows on the hero")
			check(player.slime_tint.is_equal_approx(Color(0.25, 0.55, 1.0)), "the hero wears the slime's own colour")
			var kinds: Array = game.hero_ailments().map(func(a): return a[0])
			check(SlimeCoat.KIND in kinds, "an icon under the life bar shows it: %s" % [kinds])
			check(game.icon_text(SlimeCoat.KIND, "") != "", "the icon explains itself")
			_gone(slime)
			player._attack_cooldown = 1.0
			stage = 1
			stage_frames = 0
		1:
			if stage_frames == 30:
				# Half a second: slimed arms come back by a third of it.
				check(player._attack_cooldown > 0.6, "slimed, the hero's blows come slower (%.2f left)" % player._attack_cooldown)
			if stage_frames > SlimeCoat.TIME * 60 + 20:
				check(not player.ailments.has(SlimeCoat.KIND), "the slime wears off the hero")
				check(not _coated(player), "and its coat is gone")
				check(absf(player.speed - speed_before) < 0.01, "the hero is as fast as before")
				# A slime spits at the hero from a few tiles away.
				player.global_position = spot + Vector3(5.0, 0, 0)
				player.reset_physics_interpolation()
				slime = _spawn("schleim", spot, {"hp": 40})
				# Held still, so it spits rather than crawls in to strike.
				slime.set_physics_process(false)
				player.reset_physics_interpolation()
				check(not slime.can_spit(player, 1.5, true), "right next to the hero a slime does not spit")
				check(not slime.can_spit(player, 12.0, true), "far off a slime does not spit")
				check(slime.can_spit(player, 5.0, true), "a few tiles off a slime spits")
				hp_before = player.hp
				slime._spit(player)
				check(not slime.can_spit(player, 5.0, true), "a slime does not spit again at once")
				stage = 2
				stage_frames = 0
		2:
			player.global_position = spot + Vector3(5.0, 0, 0)
			for n in game.level.get_children():
				if n is Projectile and n.gob:
					check(n.gob_colour.is_equal_approx(slime.slime_colour()), "the gob is of the slime's colour")
			if player.ailments.has(SlimeCoat.KIND) or stage_frames > 180:
				check(player.ailments.has(SlimeCoat.KIND), "the gob slimes the hero")
				check(player.hp >= hp_before, "the gob does no harm (%d, was %d)" % [player.hp, hp_before])
				_finish()
				return true
	return false
