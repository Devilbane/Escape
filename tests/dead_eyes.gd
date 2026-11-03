extends SceneTree
## Headless test: a fallen person (a bandit, or the hero) has their eyes shut
## under two small red crosses (DeadEyes). They stay while the corpse rots and
## fade as the face goes; a skeleton or an animal keeps its own eyes. A hero
## who rises again opens them.
## Run with: godot --headless --fixed-fps 60 -s tests/dead_eyes.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	if shots != "":
		Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	if failures == 0:
		print("PASS: dead eyes")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## A foe of `kind` next to the hero, struck down at once.
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


func _alpha(model: Node3D) -> float:
	var crosses := DeadEyes.on(model).find_child("Crosses", true, false) as MeshInstance3D
	return (crosses.material_override as StandardMaterial3D).albedo_color.a


## The middle between the dead eyes of `who` (a model with DeadEyes on).
func _face(model: Node3D) -> Vector3:
	return (DeadEyes.on(model).get_child(0) as Node3D).global_transform * (BodyLook.EYE_CENTRE * Vector3(0, 1, 1))


## A look from above at `at` (the fallen lie on their backs), without the HUD.
func _shot(name: String, at: Vector3, back := 0.5, high := 1.5) -> void:
	if shots == "":
		return
	var hidden := []
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.global_position = at + Vector3(0, high, back)
	cam.look_at(at)
	cam.make_current()
	await _wait(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
	for layer in hidden:
		layer.visible = true


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	await _wait(5)
	var bandit := _fell("halsabschneider", Vector3(0, 0, 2.5))
	var brute := _fell("schlaeger", Vector3(2.0, 0, 2.5))
	var bones := _fell("krieger", Vector3(-2.0, 0, 2.5))
	var wolf := _fell("wolf", Vector3(0, 0, 5.0))
	for e in [bandit, brute]:
		check(DeadEyes.on(e._model) != null, "a fallen %s has red crosses for eyes" % e.kind)
	check(DeadEyes.on(bones._model) == null, "a skeleton keeps its own eyes")
	check(DeadEyes.on(wolf._model) == null, "a wolf keeps its own eyes")
	# Once is enough: no second pair over the first.
	DeadEyes.put_on(bandit._model)
	check(bandit._model.find_children(DeadEyes.NAME, "", true, false).size() == 1, "only one pair of crosses")
	# Let them fall and lie a while: the crosses stay, bright red, as the
	# face darkens.
	await _wait(150)
	await _shot("bandit_fresh", _face(bandit._model))
	await _shot("brute_fresh", _face(brute._model))
	await _shot("bandits_wide", bandit.global_position + Vector3(0, 0.3, 0), 3.0, 5.5)
	_corpse(bandit).age = 70.0
	await _wait(10)
	check(is_instance_valid(bandit) and DeadEyes.on(bandit._model) != null, "the crosses stay while the body rots")
	check(_alpha(bandit._model) >= 0.99, "the crosses are still bright on a rotting face")
	await _shot("bandit_rotting", _face(bandit._model))
	# The face rots away: the crosses fade with it and go with the body.
	var c := _corpse(bandit)
	c.age = float(Corpse.STYLES.flesh.end) + float(Corpse.STYLES.flesh.gone) * 0.5
	await _wait(2)
	check(_alpha(bandit._model) < 0.9, "the crosses fade as the face goes")
	c.age = 999.0
	await _wait(10)
	check(not is_instance_valid(bandit), "the body and its crosses are gone")
	# The hero falls: their eyes shut under crosses too, and open on rising.
	var hero: Player = game.player
	hero._invulnerable = 0.0
	hero.take_damage(9999, hero.global_position + Vector3(0, 0, 1), null, false)
	check(hero.dead, "the hero falls")
	check(DeadEyes.on(hero._model) != null, "a fallen hero has red crosses for eyes")
	await _wait(60)
	await _shot("hero_fallen", _face(hero._model))
	hero.revive(hero.global_position)
	check(DeadEyes.on(hero._model) == null, "a hero who rises opens their eyes")
	_finish()
