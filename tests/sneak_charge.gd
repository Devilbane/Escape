extends SceneTree
## Headless test: charging a foe that has not noticed the hero sends the hero
## round to its back, and the opening blow is a sneak attack. A foe that
## wakes on the way turns the hunt into a plain one.
## Run with: godot --headless --fixed-fps 60 -s tests/sneak_charge.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var foe: Enemy
const BIG_HP := 80
## The sneak attack's damage, read before the blow lands: the blow trains a skill,
## which can raise max_hit() afterwards.
var expected_blow := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _place() -> void:
	var player: Player = game.player
	if foe == null or not is_instance_valid(foe) or foe.dead:
		foe = Enemy.new()
		foe.kind = "krieger"
		foe.level = game.level
		game.level.add_child(foe)
		game.level.enemies.append(foe)
	foe.hp = BIG_HP
	foe.hardening = 0
	foe.wound.stop() # A wound from the last blow would bleed into the next check.
	foe._awake = false
	foe._cooldown = 99.0
	foe.global_position = player.global_position + Vector3(0, 0, 4.0)
	foe.velocity = Vector3.ZERO
	foe._model.rotation.y = PI # Faces the hero.
	player.set_sneaking(true)
	player.hp = player.max_hp
	player._attack_cooldown = 0.0
	player._auto_cooldown = 0.0
	player._busy = 0.0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var player: Player = game.player
	stage_frames += 1
	match stage:
		0:
			_place()
			check(foe.is_unaware(), "a fresh foe is unaware")
			expected_blow = player.sneak_attack_damage()
			player.charge(foe)
			check(player._sneak_hunt, "charging an unaware foe starts a sneak hunt")
			stage_frames = 0
			stage += 1
		1:
			foe._awake = false
			foe.velocity = Vector3.ZERO
			if foe.hp < BIG_HP:
				check(foe.hp == BIG_HP - expected_blow, "the opening blow is a sneak attack (hp %d, expected %d)" % [foe.hp, BIG_HP - expected_blow])
				stage += 1
				stage_frames = 0
			elif stage_frames > 600:
				check(false, "the hero never struck the unaware foe")
				stage += 1
				stage_frames = 0
		2:
			_place()
			player.charge(foe)
			foe._awake = true
			stage_frames = 0
			stage += 1
		3:
			check(not player._sneak_hunt, "a foe that wakes ends the sneak")
			player.stop_hunt()
			# Without a target the hero throws no knife at the far foe: one thrown now would
			# land in the next stage's check.
			player._target = null
			check(not player._sneak_hunt, "stopping the hunt clears the sneak")
			stage += 1
		4:
			# A foe the hero merely bumped into or fought back against is not struck while sneaking.
			_place()
			foe._awake = true
			foe.global_position = player.global_position + Vector3(0, 0, 1.0)
			player._engage(foe)
			player._target_chosen = false # Bumped into, not picked by a click.
			stage_frames = 0
			stage += 1
		5:
			foe._cooldown = 99.0
			player._auto_cooldown = 0.0
			player._attack_cooldown = 0.0
			if stage_frames > 90:
				check(foe.hp == BIG_HP, "no automatic attack while sneaking (hp %d, hunt %s, sneak_hunt %s, chosen %s, sneaking %s)" % [foe.hp, player._hunt, player._sneak_hunt, player._target_chosen, player.sneaking])
				player.set_sneaking(false)
				stage += 1
				stage_frames = 0
		6:
			foe._cooldown = 99.0
			if foe.hp < BIG_HP:
				stage += 1
			elif stage_frames > 120:
				check(false, "the hero should strike automatically once not sneaking")
				stage += 1
		_:
			if failures == 0:
				print("PASS: sneak charge")
			else:
				print("FAILED: ", failures)
			quit(1 if failures > 0 else 0)
			return true
	return false
