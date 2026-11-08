extends SceneTree
## Headless test for the special moves of the elementals and golems (see
## Elementals): each move, used against the hero in a built level, leaves
## what it should (a shot, a ring on the floor, a fire patch, a ward), a
## blow on the ground hurts a hero who stays inside its ring, and a hero who
## has jumped clear is not hurt. A crystal golem's ward bounces a blow back.
## Run with: godot --headless --fixed-fps 60 -s tests/elemental_fights.gd

var failures := 0
var game: Node
var stage := 0
var stage_frames := 0
var current: Enemy
var seen := false
var spot := Vector3.INF
## kind, move id, distance of the hero, what to look for in the level.
const CASES := [
	["feuerelementar", "scorch", 6.0, "FireField"],
	["feuerelementar", "fire_bolt", 6.0, "ElementalShot"],
	["obsidiangolem", "slam", 2.0, "GroundSlam"],
	["obsidiangolem", "shards", 6.0, "ElementalShot"],
	["steingolem", "quake", 2.0, "GroundSlam"],
	["steingolem", "rock", 6.0, "ElementalShot"],
	["kristallgolem", "ward", 3.0, "ward"],
	["kristallgolem", "burst", 3.0, "GroundSlam"],
	["kristallgolem", "beam", 6.0, "ElementalShot"],
]


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
	print("PASS: elemental fights" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _open_spot() -> Vector3:
	var lvl: Level = game.level
	for y in range(2, lvl.height - 2):
		for x in range(2, lvl.width - 8):
			var free := true
			for i in 6:
				var c := Vector2i(x + i, y)
				if not lvl.astar.is_in_boundsv(c) or lvl.astar.is_point_solid(c):
					free = false
					break
			if free:
				return lvl.cell_to_world(Vector2i(x, y))
	return Vector3.INF


func _spawn(kind: String, at: Vector3) -> Enemy:
	var lvl: Level = game.level
	var e := Enemy.new()
	e.kind = kind
	e.level = lvl
	lvl.add_child(e)
	e.global_position = at
	lvl.enemies.append(e)
	return e


func _has(name: String) -> bool:
	var lvl: Level = game.level
	for n in lvl.get_children():
		if n.get_class() != "Node" and n.get_script() != null and n.get_script().get_global_name() == name:
			return true
	return false


## A hero with plenty of life, standing and ready to be hurt.
func _heal() -> void:
	game.player.dead = false
	game.player.frozen = false
	game.player.max_hp = 500
	game.player.hp = 500
	game.player._invulnerable = 0.0
	game.player._down = 0.0
	game.player._regen_pause = 0.0
	game.player.armour_value = 0
	game.player.hardening = 0
	game.player.block_chance = 0.0


## Takes a monster out of the fight without freeing it (a freed monster leaves
## floating numbers that point at nothing).
func _retire(e: Enemy) -> void:
	if e == null or not is_instance_valid(e):
		return
	e.set_physics_process(false)
	e.global_position = Vector3(0, -50, 0)
	game.level.enemies.erase(e)


func _clear_effects() -> void:
	for n in game.level.get_children():
		if n is ElementalShot or n is GroundSlam or n is FireField:
			n.queue_free()


func _process(_delta: float) -> bool:
	if game.level == null or game.player == null:
		return false
	stage_frames += 1
	if stage == 0:
		if stage_frames == 10:
			game.hero_name = "Elemental test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
		if stage_frames < 40:
			return false
		spot = _open_spot()
		check(spot != Vector3.INF, "there is open ground for the test")
		if spot == Vector3.INF:
			_finish()
			return true
		stage = 1
		stage_frames = 0
		return false
	if stage <= CASES.size():
		var c: Array = CASES[stage - 1]
		if stage_frames == 1:
			_clear_effects()
			_retire(current)
			current = _spawn(c[0], spot)
			seen = false
			game.player.global_position = spot + Vector3(c[2], 0, 0)
			game.player.velocity = Vector3.ZERO
			_heal()
		elif stage_frames == 5:
			var move: Dictionary = {}
			for m: Dictionary in Elementals.MOVES[c[0]]:
				if m.id == c[1]:
					move = m
			check(not move.is_empty(), "%s has the move %s" % [c[0], c[1]])
			current._cooldown = 0.0
			Elementals.use(current, move, game.player)
			check(current.move_cools.get(c[1], 0.0) > 0.0, "%s: %s is on its pause" % [c[0], c[1]])
		if stage_frames > 5 and _has(c[3]):
			seen = true
		if stage_frames == 5 + 90:
			if c[3] == "ward":
				check(current.ward_left > 0.0, "%s: the ward is up" % c[0])
			else:
				# A shot that flew into the hero is gone, but it hurt them.
				check(seen or game.player.hp < game.player.max_hp, "%s: %s leaves a %s" % [c[0], c[1], c[3]])
			if c[1] in ["slam", "quake"]:
				check(game.player.hp < game.player.max_hp, "%s: standing in the ring hurts" % c[1])
			stage += 1
			stage_frames = 0
		return false
	if stage == CASES.size() + 1:
		# A hero in the air when the ground bursts is not hurt; one standing is.
		_retire(current)
		game.player.global_position = spot + Vector3(2.0, 0, 0)
		_heal()
		var ring := GroundSlam.spawn(game.level, null, spot, 3.8, 99.0, 4, Color.WHITE, false)
		game.player.global_position.y = 1.0
		ring._land()
		check(game.player.hp == 500, "a hero in the air is not hurt by the ground")
		var ring2 := GroundSlam.spawn(game.level, null, spot, 3.8, 99.0, 4, Color.WHITE, false)
		game.player.global_position.y = 0.0
		ring2._land()
		check(game.player.hp < 500, "a hero on the ground is hurt by it")
		stage += 1
		stage_frames = 0
		return false
	if stage == CASES.size() + 2:
		if stage_frames == 1:
			_retire(current)
			current = _spawn("kristallgolem", spot)
			game.player.global_position = spot + Vector3(2.0, 0, 0)
			_heal()
			current.hp = current.max_hp()
		elif stage_frames == 5:
			var before: int = game.player.hp
			current.take_hit(6, game.player.global_position, "hit")
			check(game.player.hp == before, "no blow comes back while the ward is down")
			Elementals.raise_ward(current)
			current.take_hit(6, game.player.global_position, "hit")
			check(game.player.hp < before, "a warded crystal golem bounces the blow back")
			stage += 1
			stage_frames = 0
		return false
	_finish()
	return true
