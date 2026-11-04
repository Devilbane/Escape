extends SceneTree
## Headless test for the spiders' webs: a web that hits the hero does no harm
## but sticks ("netz"), slows the hero for a few seconds with an icon under
## the life bar, and wears off again. A spider of the wolf hollow that sees
## the hero from afar throws one; right up close it only bites.
## Run with: godot --headless --fixed-fps 60 -s tests/spider_webs.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var hero_hp := 0
var free_speed := 0.0
var spider: Enemy
var thrown := false


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
		print("PASS: spider webs")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _webs_in_flight() -> int:
	var n := 0
	for c in game.level.get_children():
		if c is Projectile and c.web:
			n += 1
	return n


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var player: Player = game.player
	match stage:
		0:
			game.hero_name = "Web test"
			HeroLevel.dress(player, 7)
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			var lvl: Outdoor = game.level
			check(Enemy.KINDS.spinne.has("web") and Enemy.KINDS.hohle_mutter.has("web"), "spiders throw webs")
			check(not Enemy.KINDS.wolf.has("web"), "wolves do not")
			# A web thrown at the hero from a few steps away, out in the open.
			player.global_position = lvl.cell_to_world(lvl.start_cell)
			player.velocity = Vector3.ZERO
			player.hp = player.max_hp
			hero_hp = player.hp
			player.refresh_stats()
			free_speed = player.speed
			var origin := player.global_position + Vector3(0, 0.9, 3.0)
			var shot := Projectile.spawn(lvl, origin, player.global_position - origin, false, false, false, true)
			shot.damage = 0
			check(shot.web and not shot.magic and not shot.fire, "the web is its own kind of shot")
			stage_frames = 0
			stage = 1
		1:
			stage_frames += 1
			player.velocity = Vector3.ZERO
			if not player.ailments.has("netz") and stage_frames < 60:
				return false
			check(player.ailments.has("netz"), "the web sticks to the hero")
			check(player.hp == hero_hp, "the web does no harm (%d of %d)" % [player.hp, hero_hp])
			check(is_equal_approx(player.speed, free_speed * Player.WEB_SLOW), "the hero is slowed (%.2f, free %.2f)" % [player.speed, free_speed])
			check(player.ailments.netz <= Player.WEB_TIME, "the web holds only a few seconds")
			var kinds: Array = game.hero_ailments().map(func(c): return c[0])
			check("netz" in kinds, "an icon under the life bar shows the web: %s" % [kinds])
			check(not ("slow" in kinds), "the web is not taken for a heavy load")
			check(game.icon_text("netz", "") != "", "the web's icon explains itself")
			check(Lang.EN.has(Player.AILMENT_WORDS.netz), "the web's word has an English text")
			check(_webs_in_flight() == 0, "the web is gone once it hit")
			stage_frames = 0
			stage = 2
		2:
			stage_frames += 1
			if stage_frames < int((Player.WEB_TIME + 0.5) * 60.0):
				return false
			check(not player.ailments.has("netz"), "the web wears off")
			check(is_equal_approx(player.speed, free_speed), "the hero runs at full speed again (%.2f, free %.2f)" % [player.speed, free_speed])
			# Now a spider of the hollow, with the hero at a distance.
			var lvl: Outdoor = game.level
			for e in lvl.enemies:
				if is_instance_valid(e) and e.kind == "spinne" and not e.dead:
					spider = e
					break
			check(spider != null, "a spider is there to meet")
			if spider == null:
				_finish()
				return true
			# Right next to the hero, a spider bites instead.
			check(not spider.can_throw_web(Enemy.WEB_MIN - 1.0, true), "a spider right next to the hero does not throw")
			check(not spider.can_throw_web(Enemy.WEB_REACH + 1.0, true), "a spider far away does not throw")
			var spot := Vector3.INF
			for i in 16:
				var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
				var p := spider.global_position + dir * 8.0
				if not lvl.is_opaque(lvl.world_to_cell(p)) and lvl.has_line_of_sight(spider.global_position, p) \
						and lvl.has_clear_shot(spider.global_position, p):
					spot = p
					break
			check(spot != Vector3.INF, "an open spot 8 m from the spider")
			if spot == Vector3.INF:
				_finish()
				return true
			player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
			player.reset_physics_interpolation()
			player.velocity = Vector3.ZERO
			stage_frames = 0
			stage = 3
		3:
			stage_frames += 1
			if player.hp <= 2:
				player.hp = player.max_hp
			if not is_instance_valid(spider) or spider.dead:
				check(false, "the spider stays alive")
				_finish()
				return true
			# The spider has noticed the hero (how it notices is tested elsewhere).
			spider._wake(player.global_position)
			if _webs_in_flight() > 0 or player.ailments.has("netz"):
				thrown = true
			if thrown or stage_frames > 360:
				check(thrown, "the spider throws a web at the hero it sees from afar")
				_finish()
				return true
	return false
