extends SceneTree
## Headless test for the drip puddles in the dungeon (see DungeonLife): every
## dungeon floor has some, the hero standing in one is in the water and one
## standing beside it is not, and a step into one rings its water out from
## the foot (the splash sound plays with it, as in the rain puddles above).
## Run with: godot --headless --fixed-fps 60 -s tests/drip_puddles.gd

var failures := 0
var game: Node
var frames := 0
var _placed_at := -1
var _puddle: Dictionary
const HERO := "Drip puddle test"


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
		print("PASS: drip puddles")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if _placed_at < 0:
		_step_in()
		_placed_at = frames
		return false
	# Let the hero settle on the floor first.
	if frames < _placed_at + 60:
		return false
	_splashed()
	_finish()
	return true


func _step_in() -> void:
	game.hero_name = HERO
	game.load_level(0, false)
	game.state = game.State.PLAYING
	var life: DungeonLife = game.level.life
	check(life != null, "the first dungeon floor has its dust, webs and puddles")
	if life == null:
		return
	check(not life.puddles.is_empty(), "the first dungeon floor has drip puddles")
	if life.puddles.is_empty():
		return
	_puddle = life.puddles[0]
	var at: Vector3 = _puddle.pos
	check(game.level.in_puddle(at), "the middle of a drip puddle is in the water")
	check(not game.level.in_puddle(at + Vector3(float(_puddle.rx) + 0.3, 0, 0)), "beside a drip puddle is dry")
	var p: Player = game.player
	p.global_position = Vector3(at.x, 0.05, at.z)
	p.reset_physics_interpolation()
	p.play("Running_A")


func _splashed() -> void:
	if _puddle.is_empty():
		return
	var life: DungeonLife = game.level.life
	var p: Player = game.player
	check(game.level.in_puddle(p.global_position), "the hero stands in the drip puddle")
	var drip: Dictionary = life._drips[_puddle.drip]
	drip.wave = -1.0
	drip.fall = -1.0
	drip.wait = 100.0
	# A few footfalls of the run, right in the puddle.
	p.play("Running_A")
	var length: float = p._anim.current_animation_length
	for landing in [0.17, 0.67]:
		p._last_phase = landing - 0.05
		p._anim.seek(length * (landing + 0.03), true)
		p._footsteps(5.0)
	check(float(drip.wave) >= 0.0, "a step into a drip puddle sets its water rippling")
	var ripple: Node3D = drip.ripple
	check(Vector2(ripple.position.x, ripple.position.z).distance_to(Vector2(p.global_position.x, p.global_position.z)) < 0.01,
			"the ripples run out from the foot")
