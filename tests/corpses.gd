extends SceneTree
## Headless test: a fallen monster no longer sinks into the floor. Its body
## stays where it fell, darkens and sags, and at the end leaves a stain and
## bones (a slime a puddle, a fog wraith nothing). Only a few corpses lie
## about at once, and the remnants are capped too.
## Run with: godot --headless --fixed-fps 60 -s tests/corpses.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait := 0
var fallen: Array[Enemy] = []
var fell_at: Array[Vector3] = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: corpses")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## A monster of `kind` next to the hero, struck down at once.
func _fell(kind: String, offset: Vector3) -> Enemy:
	var lvl: Level = game.level
	var e := Enemy.new()
	e.kind = kind
	e.level = lvl
	lvl.add_child(e)
	lvl.enemies.append(e)
	e.global_position = game.player.global_position + offset
	e._cooldown = 99.0
	e.take_hit(999, game.player.global_position, "hit", false)
	return e


func _corpse(e: Enemy) -> Corpse:
	for c in e.get_children():
		if c is Corpse:
			return c
	return null


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var lvl: Level = game.level
	match stage:
		0:
			for kind in ["krieger", "wolf", "schleim", "fog_wraith"]:
				var e := _fell(kind, Vector3(2.0 * fallen.size() - 3.0, 0, 3.0))
				fallen.append(e)
				fell_at.append(e.global_position)
				check(e.dead, "%s falls" % kind)
			check(Corpse.style_of(fallen[0]) == "bones", "a skeleton crumbles to bones")
			check(Corpse.style_of(fallen[1]) == "flesh", "a wolf rots")
			check(Corpse.style_of(fallen[2]) == "melt", "a slime melts")
			check(Corpse.style_of(fallen[3]) == "wisp", "a fog wraith blows away")
			stage += 1
		1:
			# Well past the old sinking time (3 s + 2 s), the bodies still lie there.
			wait += 1
			if wait < 60 * 7:
				return false
			for i in 3:
				var e := fallen[i]
				check(is_instance_valid(e), "%s still lies on the floor after 7 s" % e.kind)
				if is_instance_valid(e):
					check(absf(e.global_position.y - fell_at[i].y) < 0.01, "%s did not sink into the floor" % e.kind)
					check(_corpse(e) != null and _corpse(e)._overlay.albedo_color.a > 0.0, "%s darkens" % e.kind)
			check(not is_instance_valid(fallen[3]), "the fog wraith has blown away")
			check(fallen[2]._model.scale.y < _corpse(fallen[2])._scale0.y * 0.5, "the slime has run out flat")
			check(lvl.remnants.is_empty(), "nothing has rotted away yet")
			# Fast forward: the skeleton and the wolf come to their end.
			_corpse(fallen[0]).age = 200.0
			_corpse(fallen[1]).age = 200.0
			wait = 0
			stage += 1
		2:
			wait += 1
			if wait < 30:
				return false
			check(not is_instance_valid(fallen[0]), "the skeleton is gone")
			check(not is_instance_valid(fallen[1]), "the wolf is gone")
			check(is_instance_valid(fallen[2]), "the slime is still there")
			check(lvl.remnants.size() == 2, "a bone pile and a stain stay behind (%d)" % lvl.remnants.size())
			for r in lvl.remnants:
				check(r.get_child_count() == 2, "a remnant has a stain and bones")
			# Many dead at once: only the newest few lie about.
			for i in Corpse.MAX_CORPSES + 4:
				_fell("krieger", Vector3(-4.0 + i * 0.6, 0, -3.0))
			wait = 0
			stage += 1
		3:
			wait += 1
			if wait < 60 * 7:
				return false
			var lying := lvl.enemies.filter(func(e): return is_instance_valid(e) and e.dead).size()
			print("corpses lying: %d, remnants: %d" % [lying, lvl.remnants.size()])
			check(lying <= Corpse.MAX_CORPSES, "at most %d corpses lie about (%d)" % [Corpse.MAX_CORPSES, lying])
			check(lvl.corpses.size() <= Corpse.MAX_CORPSES, "the level keeps at most %d corpses" % Corpse.MAX_CORPSES)
			check(lvl.remnants.size() > 2, "the hurried ones left their bones")
			for i in Corpse.MAX_REMNANTS + 5:
				var bit := Corpse.remnant("bones", Vector3.ZERO, 1.0, Color.WHITE)
				lvl.add_child(bit)
				lvl.remnants.append(bit)
			_fell("wolf", Vector3(0, 0, 4))
			for c in lvl.corpses:
				c.age = 999.0
			wait = 0
			stage += 1
		4:
			wait += 1
			if wait < 30:
				return false
			var kept := lvl.remnants.filter(func(r): return is_instance_valid(r)).size()
			check(kept <= Corpse.MAX_REMNANTS, "at most %d remnants stay (%d)" % [Corpse.MAX_REMNANTS, kept])
			_finish()
			return true
	return false
