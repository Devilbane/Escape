extends SceneTree
## Headless test for the dragon flying over the open air (see DragonFlyover):
## the open air has one and the dungeon none; it waits minutes before it
## flies; it screams first, then its shadow sweeps right past the hero, head
## first, and is gone again; it flies to or from the dragon's mountain; the
## shadow is a real one, cast by the sun or moon from shapes up the light's ray,
## one solid cut-out (wings as dark as the body), as plain as the light allows;
## its pictures have a body and wings;
## its wings are heard beating as it comes over and it shrieks right overhead;
## its sounds and its line in the event log are there.
## Run with: godot --headless --fixed-fps 60 -s tests/dragon_flyover.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Dragon flyover test"
const LINE := "Ein riesiger Schatten gleitet über das Land. Fern in den Bergen schreit ein Drache."


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
	game.hero_name = HERO
	_rules()
	_pictures()
	_in_the_dungeon()
	_in_the_open()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: dragon flyover")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _flyovers(node: Node, out: Array) -> Array:
	if node is DragonFlyover:
		out.append(node)
	for child in node.get_children():
		_flyovers(child, out)
	return out


func _rules() -> void:
	check(ResourceLoader.exists(Sfx.DIR + DragonFlyover.SOUND + ".wav"), "the scream is there")
	for sound in DragonFlyover.WING_SOUNDS + [DragonFlyover.SHRIEK]:
		check(ResourceLoader.exists(Sfx.DIR + sound + ".wav"), "the sound %s is there" % sound)
	check(Lang.EN.has(LINE), "the event log line has its English")
	check(DragonFlyover.FIRST_WAIT.x >= 60.0 and DragonFlyover.WAIT.x >= 180.0, "the dragon comes rarely: minutes apart")


func _pictures() -> void:
	var body := DragonFlyover._body_image()
	var w := body.get_width()
	var h := body.get_height()
	check(body.get_pixel(w / 2, int(h * 0.45)).a > 0.8, "the body's shadow is dark in its middle")
	check(body.get_pixel(1, 1).a < 0.05 and body.get_pixel(w - 2, h - 2).a < 0.05, "the body's picture is clear around it")
	check(body.get_pixel(w / 2, int(h * 0.1)).a > 0.5, "the head is at the front (the top of the picture)")
	var wing := DragonFlyover._wing_image()
	w = wing.get_width()
	h = wing.get_height()
	check(wing.get_pixel(int(w * 0.35), h / 2).a > 0.8, "the wing is dark near the shoulder")
	check(wing.get_pixel(w - 2, h - 2).a < 0.05, "behind the wing tip the picture is clear")


## The shadow is cast, not painted: the shapes are never seen, only their
## shadow, and each is a cut-out, so wings and body are one even shade.
func _real_shadow(fly: DragonFlyover) -> void:
	var meshes: Array = [fly._body]
	for joint in fly._wings:
		meshes.append(joint.get_child(0))
	for mesh: MeshInstance3D in meshes:
		check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "the dragon is never seen, only its shadow")
		var mat := (mesh.mesh as PlaneMesh).material as StandardMaterial3D
		check(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "the shadow is a solid cut-out, not see-through")
	check(fly._wing_material.transparency == fly._material.transparency, "the wings cast as dark a shadow as the body")


## The shapes fly over the shadow's spot, up the light's ray towards the
## sun or moon, high over the village but never far off.
func _up_the_ray(fly: DragonFlyover) -> void:
	var up := fly.global_position - fly.ground
	check(up.normalized().dot(fly.to_light()) > 0.99, "the shapes are up the light's ray from the shadow")
	check(fly.global_position.y > 4.0 and fly.global_position.y <= DragonFlyover.ALTITUDE + 0.01, "the shapes fly high over the ground (%.1f m)" % fly.global_position.y)
	check(up.length() <= DragonFlyover.RAY + 0.01, "the shapes are never far off up the ray (%.1f m)" % up.length())
	check(absf(fly.ground.y) < 0.01, "the shadow's spot is on the ground")


## The first night with a phase of the moon.
func _night_of(which: int) -> int:
	var night := 0
	while Moon.phase(night) != which:
		night += 1
	return night


func _in_the_dungeon() -> void:
	for i in game.level_files.size():
		if not Level.is_outdoor_file(game.level_files[i]):
			game.load_level(i, false)
			check(_flyovers(game.level, []).is_empty(), "no dragon flies over in the dungeon")
			return
	check(false, "there is a dungeon level")


func _in_the_open() -> void:
	game.day_hour = 12.0
	game.set_weather(Weather.CLEAR, 4.0)
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	game._tick_clock(0.0)
	var found := _flyovers(level, [])
	check(found.size() == 1, "the open air has one dragon flying over")
	if found.is_empty():
		return
	var fly: DragonFlyover = found[0]
	check(fly.lair != Vector3.INF and fly.lair == level._lair_mountain_at, "it knows where the dragon's mountain is")
	check(not fly.flying and not fly.is_shown(), "no shadow until it flies")
	check(fly.wait >= DragonFlyover.FIRST_WAIT.x and fly.wait <= DragonFlyover.FIRST_WAIT.y, "the first flight is minutes away")
	# By daylight under clear skies the shadow is plain; at night and in fog it fades.
	check(is_equal_approx(fly.light(), 1.0), "the shadow is plain by day")
	# The way it flies: to or from the mountain.
	var hero: Node3D = game.player
	var near := hero.global_position
	var line := Vector3(fly.lair.x - near.x, 0, fly.lair.z - near.z).normalized()
	for i in 12:
		var d: Vector3 = fly._pick_direction(near)
		check(absf(d.dot(line)) > 0.9, "it flies to or from the dragon's mountain")
	# The time comes: it flies by itself.
	var scares: Array = []
	Events.bus().scare_happened.connect(func(kind: String): scares.append(kind))
	fly.wait = 0.01
	fly._process(0.05)
	check(scares == ["drache"], "the scream gives the village a dragon scare (%s)" % [scares])
	check(fly.flying and fly.flights == 1, "when its time comes, the dragon flies over")
	check(fly.screamed, "the scream comes first")
	# A flight across, east to west, watched to its end.
	fly.flying = false
	fly.start(near, Vector3(-1, 0, 0))
	var front := -fly._body.global_transform.basis.z
	check(front.normalized().dot(Vector3(-1, 0, 0)) > 0.99, "the head leads the way")
	_real_shadow(fly)
	var closest := INF
	var seconds := 0.0
	while fly.flying and seconds < 30.0:
		fly._process(0.1)
		seconds += 0.1
		if fly.flying:
			check(fly.is_shown(), "the shadow lies on the ground while it flies")
			closest = minf(closest, Vector2(fly.ground.x - near.x, fly.ground.z - near.z).length())
			_up_the_ray(fly)
	check(closest <= DragonFlyover.PASS_SIDE + 1.0, "the shadow sweeps right past the hero (%.1f m)" % closest)
	check(seconds > 4.0 and seconds < 10.0, "it is over in a few seconds (%.1f s)" % seconds)
	check(not fly.flying and not fly.is_shown(), "then the shadow is gone")
	check(fly.beats >= 2, "its wings are heard beating as it comes over (%d beats)" % fly.beats)
	check(fly.shrieked, "it shrieks as it passes overhead")
	check(fly.wait >= DragonFlyover.WAIT.x and fly.wait <= DragonFlyover.WAIT.y, "the next flight is minutes away")
	# By moonlight: as plain as by day under a full moon, dimmer as the moon
	# wanes, all but gone on a new-moon night (the moon casts it).
	var by_day := fly.light()
	level.hour = 0.5
	level.day = _night_of(Moon.FULL)
	var full := fly.light()
	check(full >= by_day * 0.95, "under a full moon the shadow is as plain as by day (%.2f, by day %.2f)" % [full, by_day])
	level.day = _night_of(2)
	var half := fly.light()
	check(half > 0.1 and half < full * 0.6, "under a half moon it is dimmer (%.2f)" % half)
	level.day = _night_of(Moon.NEW)
	check(fly.light() < 0.1, "on a new-moon night the shadow is all but gone (%.2f)" % fly.light())
	# Under the evening's low sun and the night's high moon the shapes still
	# fly up the light's ray, never far off, so the shadow still passes the hero.
	for hour in [19.5, 0.5, 5.5, 13.0]:
		game.day_hour = hour
		game._tick_clock(0.0)
		fly.flying = false
		fly.start(near, Vector3(1, 0, 0))
		fly.travelled = fly.length * 0.5
		fly._place()
		_up_the_ray(fly)
		check(Vector2(fly.ground.x - near.x, fly.ground.z - near.z).length() <= DragonFlyover.PASS_SIDE + 0.5, "at %.1f h the shadow still passes the hero" % hour)
	fly.flying = false
	fly._show(false)
	level.hour = 12.0
	level.weather = Weather.FOG
	check(fly.light() < 0.8, "in fog the shadow is fainter (%.2f)" % fly.light())
