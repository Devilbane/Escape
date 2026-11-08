extends SceneTree
## Headless test for the windmill (see Windmill): the village's mill has
## sails that turn about their own axis, slowly under clear skies, faster in
## the rain and fastest in a storm, hardly in fog; a change of weather eases
## the speed over instead of jumping. Near the mill the sails whoosh as they
## sweep past and the wood groans; far away it is silent.
## Run with: godot --headless --fixed-fps 60 -s tests/windmill.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Windmill test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(9)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_rules()
	_turning()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: windmill")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _rules() -> void:
	var clear := Windmill.speed_for(Weather.CLEAR)
	check(clear > 0.0, "the sails turn under clear skies")
	check(TAU / clear > 10.0, "under clear skies the sails turn slowly")
	check(Windmill.speed_for(Weather.FOG) < clear, "the still air of fog turns the sails slower")
	check(Windmill.speed_for(Weather.RAIN) > clear, "the wind of the rain turns them faster")
	check(Windmill.speed_for(Weather.STORM) > Windmill.speed_for(Weather.RAIN), "a storm turns them fastest")
	for kind in Weather.KINDS:
		check(Windmill.SPEEDS.has(kind), "every weather has a speed for the sails: " + kind)
	for take in ["windmill_whoosh_0", "windmill_whoosh_1", "windmill_whoosh_2", "windmill_groan_0", "windmill_groan_1", "windmill_groan_2"]:
		check(ResourceLoader.exists(Sfx.DIR + take + ".ogg"), "the sound is there: " + take)


func _players(level: Node) -> Array:
	return level.find_children("*", "AudioStreamPlayer3D", false, false).filter(
			func(p): return (p.stream.resource_path as String).get_file().begins_with("windmill_"))


func _turning() -> void:
	game.hero_name = HERO
	game.day_hour = 12.0
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	check(level.windmills.size() == 1, "the village has its windmill")
	if level.windmills.is_empty():
		return
	var mill: Windmill = level.windmills[0]
	check(mill.sails != null and mill.sails.name.contains("fan"), "the mill turns its sails, not the whole tower")
	var sail_mat := (mill.sails as MeshInstance3D).material_override as ShaderMaterial
	check(sail_mat != null and sail_mat.get_shader_parameter("canvas") == true, "the sails are woven canvas")
	check(sail_mat != null and sail_mat.get_shader_parameter("canvas_shadow") is Texture2D, "the canvas is shaded along its frame")
	var tower := mill.sails.get_parent() as Node3D
	var tower_basis := tower.global_transform.basis
	level.set_weather(Weather.CLEAR)
	mill.speed = Windmill.speed_for(Weather.CLEAR)
	# Far from the mill: the sails turn but nothing is heard.
	level.player.global_position = mill.sails.global_position + Vector3(Windmill.HEAR_RANGE + 20.0, 0, 0)
	var start := mill.sails.rotation.z
	var axis_before := mill.sails.global_transform.basis.z
	for i in 120:
		mill._process(1.0 / 60.0)
	check(not is_equal_approx(mill.sails.rotation.z, start), "the sails turn")
	check(mill.sails.global_transform.basis.z.is_equal_approx(axis_before), "the sails turn about their own axle")
	check(tower.global_transform.basis.is_equal_approx(tower_basis), "the tower itself stands still")
	check(_players(level).is_empty(), "far from the mill nothing is heard")
	# Near the mill: a whoosh for each sail that sweeps past.
	level.player.global_position = mill.sails.global_position + Vector3(6, -8, 6)
	var sweep := TAU / Windmill.SAILS / mill.speed
	for i in int(sweep * 60.0) + 5:
		mill._process(1.0 / 60.0)
	var whooshes := _players(level).filter(func(p): return (p.stream.resource_path as String).get_file().begins_with("windmill_whoosh"))
	check(whooshes.size() >= 1, "near the mill a sail whooshes as it sweeps past")
	mill._groan_timer = 0.0
	mill._process(1.0 / 60.0)
	var groans := _players(level).filter(func(p): return (p.stream.resource_path as String).get_file().begins_with("windmill_groan"))
	check(groans.size() >= 1, "the old wood groans now and then")
	# A storm: the sails pick up speed gently and end up fast.
	var quiet := mill.loudness(Windmill.WHOOSH_DB, 10.0)
	level.set_weather(Weather.STORM)
	mill._process(1.0 / 60.0)
	check(mill.speed < Windmill.speed_for(Weather.STORM) * 0.5, "the sails do not jump to storm speed")
	for i in 60 * 30:
		mill._process(1.0 / 60.0)
	check(absf(mill.speed - Windmill.speed_for(Weather.STORM)) < 0.05, "in a storm the sails turn at storm speed")
	check(mill.loudness(Windmill.WHOOSH_DB, 10.0) > quiet, "in a storm the sails whoosh louder")
	check(mill.loudness(Windmill.WHOOSH_DB, 30.0) < mill.loudness(Windmill.WHOOSH_DB, 5.0), "further away the mill is quieter")
