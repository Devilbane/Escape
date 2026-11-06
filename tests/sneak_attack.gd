extends SceneTree
## Headless test: a sneak attack (a blow in the back of a foe that has not
## noticed the hero) deals three times the hero's maximum hit, with no roll,
## and no longer kills outright. The same foe struck face to face takes a
## plain blow.
## Run with: godot --headless --fixed-fps 60 -s tests/sneak_attack.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var foe: Enemy
var start_hp := 0
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
		print("PASS: sneak attack")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Puts one plain warrior right in front of the hero, too tough to fall,
## looking away from the hero (its back turned) or at them.
func _place(back_turned: bool) -> void:
	var player: Player = game.player
	if foe == null or not is_instance_valid(foe) or foe.dead:
		foe = Enemy.new()
		foe.kind = "krieger"
		foe.level = game.level
		game.level.add_child(foe)
		game.level.enemies.append(foe)
	player.face(Vector3(0, 0, 1))
	foe.hp = BIG_HP
	foe.hardening = 0
	foe._awake = false
	foe._cooldown = 99.0
	foe.global_position = player.global_position + Vector3(0, 0, 1.8)
	foe.velocity = Vector3.ZERO
	foe._model.rotation.y = 0.0 if back_turned else PI
	start_hp = foe.hp
	player.power = POWER
	player.hp = player.max_hp
	player._attack_cooldown = 0.0
	player._auto_cooldown = 99.0
	player._busy = 0.0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var player: Player = game.player
	match stage:
		0:
			player.power = POWER
			check(player.max_hit() in [POWER, POWER + 1], "the maximum hit is the power plus at most one heavy hit")
			check(player.sneak_attack_damage() == Player.SNEAK_ATTACK_FACTOR * player.max_hit(), "a sneak attack is three times the maximum hit")
			_place(true)
			check(foe.open_to_backstab(player.global_position), "an unaware foe with its back turned is open to a sneak attack")
			player.melee()
			stage_frames = 0
			stage += 1
		1:
			stage_frames += 1
			if stage_frames == 20:
				var lost := start_hp - foe.hp
				print("sneak attack: %d damage (max hit %d)" % [lost, player.max_hit()])
				check(lost == 3 * player.max_hit(), "the sneak attack deals exactly three times the maximum hit")
				check(not foe.dead, "a tough foe survives a sneak attack")
				stage += 1
		2:
			_place(false)
			check(not foe.open_to_backstab(player.global_position), "a foe looking at the hero is no sneak attack")
			player.melee()
			stage_frames = 0
			stage += 1
		3:
			stage_frames += 1
			if stage_frames == 20:
				var lost := start_hp - foe.hp
				print("plain blow: %d damage" % lost)
				check(lost in [POWER, POWER + 1], "face to face the blow is a plain one")
				stage += 1
		_:
			_finish()
			return true
	return false
