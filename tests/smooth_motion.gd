extends SceneTree
## Headless test for smooth running (SmoothMotion): physics interpolation is
## on for the game, but only the bodies that move in physics ticks (hero,
## monsters, villagers, animals, the companion) are drawn between ticks; the
## rest of the world, the camera and the children of those bodies are not.
## The camera follows where the hero is drawn, and a hero put somewhere new
## is drawn there at once. Also: the comic bubbles' star is drawn once at the
## start, not at the first blow of each colour.
## Run with: godot --headless --fixed-fps 60 -s tests/smooth_motion.gd

var failures := 0
var game: Node
var frames := 0
var start_x := 0.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _children_ride_along(body: Node) -> bool:
	return body.get_children().all(func(c): return not c.is_physics_interpolated())


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		check(ProjectSettings.get_setting("physics/common/physics_interpolation"), "physics interpolation is on")
		check(is_physics_interpolation_enabled(), "the scene tree interpolates")
		check(is_zero_approx(ProjectSettings.get_setting("physics/common/physics_jitter_fix")), "no jitter fix fights the interpolation")
		check(root.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "the world is not interpolated by default")
		check(not Comic._shape.is_empty(), "the comic star is drawn when the game starts")
		game.load_level(game._outdoor_index())
		game.state = game.State.PLAYING
	if frames == 40:
		var hero: Player = game.player
		check(hero.is_physics_interpolated_and_enabled(), "the hero is drawn between ticks")
		check(_children_ride_along(hero), "the hero's model and the rest ride along, not interpolated themselves")
		check(not game.camera.is_physics_interpolated(), "the camera follows every frame, not between ticks")
		check(not game.level.is_physics_interpolated(), "the level itself is not interpolated")
		var enemies: Array = game.level.enemies.filter(func(e): return is_instance_valid(e))
		check(not enemies.is_empty() and enemies.all(func(e): return e.is_physics_interpolated() and _children_ride_along(e)), "monsters are drawn between ticks")
		var villagers: Array = game.level.find_children("*", "Villager", true, false)
		check(not villagers.is_empty() and villagers.all(func(v): return v.is_physics_interpolated()), "villagers are drawn between ticks")
		# A light added to the hero later rides along too.
		var lamp := OmniLight3D.new()
		hero.add_child(lamp)
		check(not lamp.is_physics_interpolated(), "a child added later is not interpolated itself")
		lamp.free()
		start_x = hero.global_position.x
		Input.action_press("ui_right")
	if frames == 100:
		var hero: Player = game.player
		Input.action_release("ui_right")
		# A second at walking pace (about 1.8 m/s, see Stride) is near two
		# metres; half a metre shows the hero moved.
		check(hero.global_position.x > start_x + 0.5, "the hero walked (%.2f m)" % (hero.global_position.x - start_x))
		# The camera follows where the hero is drawn.
		var drawn := SmoothMotion.drawn_at(hero)
		check(drawn.distance_to(hero.global_position) < 1.0, "the hero is drawn close to where they are (%.2f apart)" % drawn.distance_to(hero.global_position))
		# Put somewhere new: drawn there at once, no slide across the map.
		hero.global_position += Vector3(12, 0, 0)
		game._snap_camera()
	if frames == 101:
		var hero: Player = game.player
		check(SmoothMotion.drawn_at(hero).distance_to(hero.global_position) < 0.01, "a hero put somewhere new is drawn there at once, not sliding over (%.2f off)" % SmoothMotion.drawn_at(hero).distance_to(hero.global_position))
	if frames == 102:
		# A new colour only fills the ready star in: same size as the others.
		var tex: Texture2D = Comic.current._burst_texture(Color(0.3, 0.6, 0.4))
		check(tex.get_size() == Vector2(260, 200), "a bubble of a new colour still gets its star")
		var img := tex.get_image()
		check(Vector3(img.get_pixel(130, 100).r, img.get_pixel(130, 100).g, img.get_pixel(130, 100).b).distance_to(Vector3(0.3, 0.6, 0.4)) < 0.01, "the star is filled with its colour")
		check(img.get_pixel(0, 0).a == 0.0, "outside the star stays clear")
		game.delete_save(game.save_path())
		if failures == 0:
			print("PASS: smooth motion")
		else:
			print("FAILED: ", failures)
		return true
	return false
