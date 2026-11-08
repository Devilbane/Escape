extends SceneTree
## Headless test: one enemy in reach gets a single strike at full power. Two or
## more in reach are met with a sweep: up to three of them are hit, each for
## half the damage (at least 1), and the fourth is spared. Attacked without a
## command, the hero fights back against the attacker; struck from afar with no
## knife to answer, the hero walks up and strikes back, gives up a long chase,
## and a step ends the chase at once.
## Run with: godot --headless --fixed-fps 60 -s tests/splash_attack.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var crowd: Array[Enemy] = []
var start_hp: Array[int] = []
const BIG_HP := 50
const POWER := 4


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: splash attack")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Puts `count` living skeletons in a row in front of the hero, facing them,
## too tough to fall, and remembers their life. Where the level has too few,
## more warriors join.
func _line_up(count: int) -> bool:
	var player: Player = game.player
	crowd.clear()
	start_hp.clear()
	for e in game.level.enemies:
		if is_instance_valid(e) and not e.dead and not e._stats.get("armored", false):
			crowd.append(e)
		if crowd.size() == count:
			break
	while crowd.size() < count:
		var e := Enemy.new()
		e.kind = "krieger"
		e.level = game.level
		game.level.add_child(e)
		game.level.enemies.append(e)
		crowd.append(e)
	player.face(Vector3(0, 0, 1))
	for i in crowd.size():
		var e := crowd[i]
		e.hp = BIG_HP
		e._cooldown = 99.0
		e.global_position = player.global_position + Vector3(0.9 * (i - (count - 1) * 0.5), 0, 1.8)
		e.velocity = Vector3.ZERO
		e._model.rotation.y = PI # Looking back at the hero: no backstab.
		start_hp.append(e.hp)
	player.power = POWER
	player.hp = player.max_hp
	player._attack_cooldown = 0.0
	# No blows on their own unless a stage asks for them.
	player._auto_cooldown = 99.0
	player._busy = 0.0
	return true


## A free floor cell between `near` and `far` metres away that the hero can
## reach on foot, or Vector3.INF.
func _walkable_spot_near(from: Vector3, near: float, far: float) -> Vector3:
	var lvl: Level = game.level
	var start := lvl.world_to_cell(from)
	var best := Vector3.INF
	var best_d := INF
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			var c := start + Vector2i(dx, dz)
			if not lvl.astar.is_in_boundsv(c) or lvl.astar.is_point_solid(c):
				continue
			var pos := lvl.cell_to_world(c)
			var d := from.distance_to(pos)
			if d < near or d > far or d >= best_d:
				continue
			if lvl.astar.get_id_path(start, c).size() < 2:
				continue
			best = pos
			best_d = d
	return best


## One skeleton a few tiles away strikes the hero, who stands idle with
## `knife_count` knives. False (after a FAIL) when there is no such spot.
func _far_attacker(knife_count: int) -> bool:
	var player: Player = game.player
	if not _line_up(1):
		check(false, "the level still has a skeleton")
		return false
	var spot := _walkable_spot_near(player.global_position, 5.0, 8.0)
	if spot == Vector3.INF:
		check(false, "a free spot a few tiles away")
		return false
	crowd[0].global_position = spot
	player.path.clear()
	player.stop_hunt()
	player._target = null
	player._chase_rest = 0.0
	player.knives = knife_count
	if knife_count == 0:
		while player.bag.has(Items.KNIFE): # Spares would be put into the belt at once.
			player.bag.erase(Items.KNIFE)
	player._auto_cooldown = 0.0
	_strike(crowd[0])
	return true


## `enemy` lands a light blow on the hero, who can be hurt right now.
func _strike(enemy: Enemy) -> void:
	var player: Player = game.player
	player.hp = player.max_hp
	player._invulnerable = 0.0
	player._down = 0.0
	player.take_damage(1, enemy.global_position, enemy)


func _lost(i: int) -> int:
	return start_hp[i] - crowd[i].hp


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var player: Player = game.player
	match stage:
		0:
			# One enemy: a single strike at full power (a heavy hit may add 1).
			if not _line_up(1):
				check(false, "the level has a skeleton")
				_finish()
				return true
			check(not player.would_splash(), "a lone enemy gets a strike")
			player.melee()
			stage_frames = 0
			stage += 1
		1:
			stage_frames += 1
			if stage_frames == 20:
				print("strike: %d damage" % _lost(0))
				check(_lost(0) in [POWER, POWER + 1], "the strike does full damage")
				stage += 1
		2:
			# Four enemies: a sweep hits three of them for half the damage.
			if not _line_up(4):
				print("only %d skeletons here, the sweep is checked with fewer" % crowd.size())
				if not _line_up(2):
					check(false, "the level has two skeletons")
					_finish()
					return true
			check(player.would_splash(), "a crowd gets a sweep")
			player.melee()
			stage_frames = 0
			stage += 1
		3:
			stage_frames += 1
			if stage_frames == 20:
				var hit := 0
				for i in crowd.size():
					print("sweep: skeleton %d took %d damage" % [i, _lost(i)])
					if _lost(i) > 0:
						hit += 1
						check(_lost(i) in [POWER / 2, (POWER + 1) / 2 + 1], "a sweep does half the damage")
				check(hit == mini(3, crowd.size()), "a sweep hits up to three enemies, got %d" % hit)
				stage += 1
		4:
			# Attacked with no command, the hero fights back.
			if not _line_up(1):
				check(false, "the level still has a skeleton")
				_finish()
				return true
			player._target = null
			player._auto_cooldown = 0.0
			player._invulnerable = 0.0
			var life := player.hp
			player.take_damage(1, crowd[0].global_position, crowd[0])
			print("attacked: life %d -> %d, invulnerable %.2f, down %.2f" % [life, player.hp, player._invulnerable, player._down])
			check(player.hp < life, "the blow lands")
			check(player._target == crowd[0], "the hero turns on the attacker")
			stage_frames = 0
			stage += 1
		5:
			stage_frames += 1
			if stage_frames == 90:
				print("fighting back: %d damage" % _lost(0))
				check(_lost(0) > 0, "the hero strikes back on their own")
				stage += 1
		6:
			# Sent after an enemy with a click, the hero walks up and strikes.
			if not _line_up(1):
				check(false, "the level still has a skeleton")
				_finish()
				return true
			var spot := _walkable_spot_near(player.global_position, 5.0, 8.0)
			if spot == Vector3.INF:
				print("no free spot a few tiles away, the charge is not checked")
				_finish()
				return true
			crowd[0].global_position = spot
			player._target = null
			player.knives = 5
			player.charge(crowd[0])
			stage_frames = 0
			stage += 1
		7:
			stage_frames += 1
			if stage_frames == 240:
				var d := player.global_position.distance_to(crowd[0].global_position)
				print("charge: %.1f m from the skeleton after 4 s, %d damage, %d knives left" % [d, _lost(0), player.knives])
				check(d < 5.0, "the hero walked up to the clicked skeleton")
				check(_lost(0) > 0, "the hero struck the clicked skeleton")
				check(player.knives == 5, "no knives thrown on the way")
				stage += 1
		8:
			# Struck from afar with no knives left: the hero walks up and strikes back.
			if not _far_attacker(0):
				_finish()
				return true
			check(player._hunt == crowd[0], "struck from afar, the hero goes after the attacker")
			stage_frames = 0
			stage += 1
		9:
			stage_frames += 1
			if stage_frames == 240:
				var d := player.global_position.distance_to(crowd[0].global_position)
				print("strike back: %.1f m from the attacker after 4 s, %d damage" % [d, _lost(0)])
				check(d < 5.0, "the hero walked up to the attacker")
				check(_lost(0) > 0, "the hero struck the attacker back")
				stage += 1
		10:
			# A step ends the chase at once.
			if not _far_attacker(0):
				_finish()
				return true
			Input.action_press("ui_right")
			stage_frames = 0
			stage += 1
		11:
			stage_frames += 1
			if stage_frames == 45: # Past the flinch from the blow.
				Input.action_release("ui_right")
				check(player._hunt == null, "a step ends the chase")
				stage += 1
		12:
			# A chase that runs out gives up, and the same foe is not chased again at once.
			if not _far_attacker(0):
				_finish()
				return true
			player._chase_left = 0.02
			stage_frames = 0
			stage += 1
		13:
			stage_frames += 1
			if stage_frames == 45:
				check(player._hunt == null and player.path.is_empty(), "a long chase gives up")
				_strike(crowd[0])
				check(player._hunt == null, "a foe given up on is not chased again at once")
				stage += 1
		14:
			# With knives and a clear shot, the hero answers from where they stand.
			if not _far_attacker(5):
				_finish()
				return true
			if game.level.has_clear_shot(player.global_position, crowd[0].global_position):
				check(player._hunt == null, "with knives in hand, the hero throws instead of chasing")
			else:
				print("no clear shot at the spot, the knife answer is not checked")
			stage += 1
		15:
			# An empty belt with spares in the bag is refilled, at the cost of two throws.
			player._attack_cooldown = 0.0
			player._busy = 0.0
			player.frozen = false
			player.ailments.erase("angst")
			player.knives = 0
			player.bag.append(Items.KNIFE)
			player.throw_knife()
			check(player.knives == 1 and player.spare_knives() == 0, "the empty belt is refilled from the bag")
			check(is_equal_approx(player._attack_cooldown, Player.KNIFE_REFILL_ATTACKS * Player.THROW_COOLDOWN), "the refill costs two throws")
			stage += 1
		_:
			_finish()
			return true
	return false
