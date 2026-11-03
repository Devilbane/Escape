extends SceneTree
## Headless test: damage numbers pop up over the foe's head, rise and fade.
## Hitting one foe again and again, every number stays readable: none covers
## another, and each one is gone after its short life.
## Run with: godot --headless --fixed-fps 60 -s tests/damage_numbers.gd

const HITS := 8
## Frames between two blows: faster than any hero can strike.
const EVERY := 9

var failures := 0
var game: Node
var frames := 0
var enemy: Enemy
var hits := 0
var since_hit := 0
var most_seen := 0
var closest := INF
var last_heights := {}
var rose := true
var faded := false
var done_at := -1


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: damage numbers")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if enemy == null:
		for e in game.level.enemies:
			if is_instance_valid(e) and not e.dead:
				enemy = e
				break
		if enemy == null:
			check(false, "the level has a foe")
			_finish()
			return true
		enemy.hp = 100000
	if hits < HITS and since_hit <= 0:
		enemy.take_hit(3 + hits, enemy.global_position + Vector3(0, 0, 2), "hit", false)
		hits += 1
		since_hit = EVERY
	since_hit -= 1
	var numbers := DamageNumber.over(enemy)
	most_seen = maxi(most_seen, numbers.size())
	# Settled numbers (a few frames after the last blow) must keep a clear gap.
	if since_hit < EVERY - 4:
		for i in range(1, numbers.size()):
			var g: float = numbers[i - 1].height() - numbers[i].height()
			closest = minf(closest, g)
	for n in numbers:
		var id: int = n.get_instance_id()
		if last_heights.has(id) and n.height() < last_heights[id] - 0.001:
			rose = false
		last_heights[id] = n.height()
		if n.modulate.a < 0.05:
			faded = true
		var head: float = enemy.global_position.y + 2.2 * enemy._stats.size
		if n.global_position.y < head - 0.01:
			check(false, "a number starts at the head, not below it")
	if hits >= HITS and numbers.is_empty() and done_at < 0:
		done_at = frames
	if done_at > 0 or frames > 600:
		check(hits == HITS, "all blows landed")
		check(most_seen >= 3, "several numbers show at once (saw %d)" % most_seen)
		check(most_seen <= DamageNumber.MOST + 2, "the stack stays short (saw %d)" % most_seen)
		check(closest >= DamageNumber.STEP * 0.95, "numbers never overlap (closest gap %.2f)" % closest)
		check(rose, "numbers only ever rise")
		check(faded, "numbers fade out")
		check(done_at > 0, "every number is gone after its life")
		_finish()
		return true
	return false
