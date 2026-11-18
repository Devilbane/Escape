extends SceneTree
## Headless test for snow: a brief snowfall that builds up a layer of snow on every surface that
## faces the sky (and melts again), grey footprints in it, and the cold breath of the hero and
## the villagers. Down in the dungeon there is none of it.
## Run with: godot --headless --fixed-fps 60 -s tests/snow.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Snow test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(6)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_rules()
	_world()
	_prints()
	_caps()
	_breath()
	_winter()
	_dungeon()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: snow")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _settle() -> void:
	for i in 3:
		game._tick_clock(0.1)
		game._show_weather()


func _rules() -> void:
	check(Weather.SNOW in Weather.KINDS, "snow is a weather")
	for kind in Weather.KINDS:
		check(Weather.look(kind).has("snow"), "every look says how hard it snows: " + kind)
	check(float(Weather.look(Weather.SNOW).snow) > 0.9 and float(Weather.look(Weather.CLEAR).snow) == 0.0, "only the snow look has snowfall")
	check(float(Weather.look(Weather.SNOW).rain) == 0.0, "snow is not rain")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 40:
		var hours := Weather.spell(rng, Weather.SNOW)
		check(hours >= Weather.SNOW_MIN_HOURS and hours <= Weather.SNOW_MAX_HOURS, "a flurry is brief")
		check(hours <= Weather.MAX_HOURS * 0.6, "snowfall is shorter than other spells")
	var seen := {}
	for i in 600:
		seen[Weather.roll(12.0 + (i % 12), rng, Weather.CLEAR, true)] = true
	check(seen.has(Weather.SNOW), "snow comes up in the winter rolls")
	check(not seen.has(Weather.RAIN) and not seen.has(Weather.STORM), "no rain and no storm in winter")
	# The year: eight days of winter at the end of every one.
	var winter_days := 0
	for d in Weather.YEAR_DAYS:
		if Weather.is_winter(d):
			winter_days += 1
	check(winter_days == 8, "winter lasts 8 days (%d)" % winter_days)
	check(not Weather.is_winter(0) and Weather.is_winter(Weather.YEAR_DAYS - 1), "a year starts out of winter and ends in it")
	check(not Weather.is_winter(Weather.YEAR_DAYS), "the next year starts out of winter")
	check(Weather.for_season(Weather.RAIN, true) == Weather.SNOW and Weather.for_season(Weather.STORM, true) == Weather.SNOW, "in winter snow comes instead of rain")
	check(Weather.for_season(Weather.RAIN, false) == Weather.RAIN, "out of winter rain is rain")
	check(Weather.snow_cover(1.0, Weather.CLEAR, 60.0, true) > Weather.snow_cover(1.0, Weather.CLEAR, 60.0), "the snow melts slower in winter")
	check(Weather.word(Weather.SNOW) == "Schnee", "the HUD names the snow")
	# The layer builds up while it snows and melts after it, rain washes it off faster.
	var cover := 0.0
	cover = Weather.snow_cover(cover, Weather.SNOW, DayNight.DAY_LENGTH / 24.0 * Weather.SNOW_BUILD_HOURS * 0.5)
	check(is_equal_approx(cover, 0.5), "half the build time gives half the layer")
	check(Weather.snow_cover(1.0, Weather.SNOW, 1000.0) == 1.0, "the layer is never deeper than full")
	var dry := Weather.snow_cover(1.0, Weather.CLEAR, 60.0)
	var wet := Weather.snow_cover(1.0, Weather.RAIN, 60.0)
	check(dry < 1.0 and dry > 0.0, "the snow melts slowly in dry weather")
	check(wet < dry, "rain melts it faster")
	check(Weather.snow_cover(0.0, Weather.CLEAR, 1000.0) == 0.0, "there is no snow below nothing")
	check(Weather.COLD_FROM < Weather.PRINT_FROM, "breath shows before the prints do")


func _world() -> void:
	game.hero_name = HERO
	game.day_hour = 12.0
	game.set_weather(Weather.CLEAR, 4.0)
	game.snow_cover = 0.0
	game.load_level(game._outdoor_index(), false)
	_settle()
	var lvl: Outdoor = game.level
	check(lvl.snow != null and not lvl.snow.lies(), "a clear day has no snow")
	check(not Weather.cold and not game._snow.emitting, "no cold and no flakes on a clear day")
	game.set_weather(Weather.SNOW, 3.0)
	game.snow_cover = 0.6
	for i in 30:
		game._tick_clock(0.05)
	game._show_weather()
	check(lvl.snow.lies(), "the world is under snow")
	check(game._snow.emitting and game._snow.visible, "flakes fall")
	check(Weather.cold, "it is cold while it snows")
	var covered := 0
	var bare_wrong := 0
	for mi: MeshInstance3D in lvl.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay == lvl.snow.material:
			covered += 1
			var up: Node = mi
			while up != null and up != lvl:
				if SnowCover.bare(up):
					bare_wrong += 1
					break
				up = up.get_parent()
	print("snow overlays: %d meshes" % covered)
	check(covered > 20, "roofs, ground and props wear the snow layer (%d meshes)" % covered)
	check(bare_wrong == 0, "no creature is covered in snow")
	var shaded: ShaderMaterial = lvl.snow.material
	check(lvl.warm_spots.size() >= 3 and int(shaded.get_shader_parameter("warm_count")) == mini(lvl.warm_spots.size(), SnowCover.WARM_MAX), "fires, the forge and the chimneys keep the snow off (%d spots)" % lvl.warm_spots.size())
	var glowing := 0
	for mi: MeshInstance3D in lvl.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay == lvl.snow.material and mi.material_override is BaseMaterial3D and (mi.material_override as BaseMaterial3D).emission_enabled:
			glowing += 1
	check(glowing == 0, "nothing glowing (coals, embers) wears snow")
	check(float(shaded.get_shader_parameter("amount")) > 0.5, "the shader knows how thick the snow lies")
	# A new thing built while it snows gets its coat too.
	var late := MeshInstance3D.new()
	late.mesh = BoxMesh.new()
	lvl.add_child(late)
	check(late.material_overlay == lvl.snow.material, "a roof built in the snow is covered")
	# It melts away and the overlays come off again.
	game.set_weather(Weather.CLEAR, 4.0)
	game.snow_cover = 0.0
	game._tick_clock(0.05)
	check(not lvl.snow.lies(), "the snow is gone")
	var left := 0
	for mi: MeshInstance3D in lvl.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay == lvl.snow.material:
			left += 1
	check(left == 0, "no overlay is left once the snow melted")
	# The layer is kept in the saved game.
	game.snow_cover = 0.7
	check(game.save_game(), "the game is saved")
	var data: Dictionary = game._read_save(game.save_path())
	check(is_equal_approx(float(data.get("snow", -1.0)), 0.7), "the saved game holds the snow")
	game.snow_cover = 0.0
	game._apply_save(data)
	check(is_equal_approx(game.snow_cover, 0.7), "loading brings the snow back")
	data.erase("snow")
	game._apply_save(data)
	check(game.snow_cover == 0.0, "an older saved game wakes up to bare ground")


## The snow's body on the buildings: caps and icicles, hidden while the ground is bare and
## shown once snow lies, every vertex with the way to its full place.
func _caps() -> void:
	var lvl: Outdoor = game.level
	var caps: Array = SnowCaps.in_world(lvl)
	var verts := 0
	var ice := 0
	for cap: MeshInstance3D in caps:
		for i in cap.mesh.get_surface_count():
			var n: int = (cap.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			verts += n
			if cap.mesh.surface_get_material(i) == SnowCaps.ice_material():
				ice += n
	print("snow caps: %d buildings, %d vertices, %d of icicles" % [caps.size(), verts, ice])
	check(caps.size() >= 5, "the buildings wear caps of snow")
	check(ice > 0, "icicles hang from the eaves and windows")
	game.snow_cover = 0.0
	game._tick_clock(0.05)
	check(caps.all(func(c: MeshInstance3D): return not c.visible), "no caps on bare roofs")
	game.snow_cover = 1.0
	game._tick_clock(0.05)
	check(caps.all(func(c: MeshInstance3D): return c.visible), "the caps show while snow lies")
	check(caps.all(func(c: MeshInstance3D): return c.material_overlay == null), "no overlay on the caps")
	# The bush and ivy leaves take the cut-out snow, which keeps to their shape.
	var leafy := 0
	for leaves: GeometryInstance3D in lvl.find_children("Leaves_*", "MultiMeshInstance3D", true, false):
		var over := leaves.material_overlay as ShaderMaterial
		if over != null and over.shader == SnowCover.CUTOUT_SHADER:
			leafy += 1
	check(leafy > 0, "snow on the leaves of bushes and ivy")


func _prints() -> void:
	var lvl: Outdoor = game.level
	game.set_weather(Weather.SNOW, 3.0)
	game.snow_cover = 0.1
	game._tick_clock(0.05)
	var before := SnowPrints._live.size()
	lvl.snow_print(Vector3(1, 0, 1), 0.0)
	check(SnowPrints._live.size() == before, "no prints in a dusting of snow")
	game.snow_cover = 1.0
	game._tick_clock(0.05)
	lvl.snow_print(Vector3(1, 0, 1), 0.0)
	check(SnowPrints._live.size() == before + 1, "a print in the snow")
	# The deepest snow lies 0.03 + 0.03 m above the ground (snow_cover.gdshader): prints stay above it.
	check(SnowPrints.HEIGHT > 0.06, "prints lie above the deepest snow")
	for i in SnowPrints.MAX + 20:
		lvl.snow_print(Vector3(i * 0.1, 0, 0), 0.0)
	check(SnowPrints._live.size() <= SnowPrints.MAX, "only so many prints at once")
	# Every walker's print has a picture, and the toes lead the way it goes.
	for kind in SnowPrints.KINDS:
		check(SnowPrints.texture(kind) != null, "a %s print has a picture" % kind)
	for kind in SnowTrail.FEET:
		check(SnowPrints.KINDS.has(SnowTrail.FEET[kind][0]), "%s presses a known print" % kind)
	# Steps crunch in the snow, on any open ground, but the pace keeps to the ground beneath.
	var spot: Vector3 = lvl.spots.square[0]
	check(Surfaces.step_ground(lvl, spot) == Surfaces.SNOW, "a step in the snow crunches")
	check(Surfaces.ground(lvl, spot) != Surfaces.SNOW, "the snow does not change the pace")
	check(Surfaces.step_sound(Surfaces.SNOW).begins_with("step_snow_"), "snow plays its own steps")
	for i in Surfaces.STEP_SOUNDS:
		check(ResourceLoader.exists(Sfx.DIR + "step_snow_%d.wav" % i), "the snow step %d exists" % i)
	game.snow_cover = 0.1
	game._tick_clock(0.05)
	check(Surfaces.step_ground(lvl, spot) != Surfaces.SNOW, "a dusting of snow does not crunch")


func _breath() -> void:
	var lvl: Outdoor = game.level
	game.snow_cover = 1.0
	game.set_weather(Weather.SNOW, 3.0)
	game._tick_clock(0.05)
	game._show_weather()
	check(game.player.find_children("*", "Breath", true, false).size() == 1, "the hero has a breath")
	var breathers := 0
	for v: Villager in lvl.villagers:
		breathers += v.find_children("*", "Breath", true, false).size()
	check(breathers >= lvl.villagers.size() and breathers > 0, "every villager has a breath")
	var puff: Breath = null
	for v: Villager in lvl.villagers:
		for b: Breath in v.find_children("*", "Breath", true, false):
			if b.is_visible_in_tree():
				puff = b
	check(puff != null, "someone out in the village breathes")
	check(Weather.cold, "it is cold")
	if puff != null:
		puff._timer = 0.0
		puff._process(0.016)
		check(puff._puff.emitting, "a villager breathes out a cloud in the cold")
	game.set_weather(Weather.CLEAR, 4.0)
	game.snow_cover = 0.05
	game._show_weather()
	check(not Weather.cold, "no breath to see once the snow is nearly gone")


func _winter() -> void:
	var before: int = game.day
	game.escaped = true
	game.day = Weather.YEAR_DAYS - Weather.WINTER_DAYS - 1
	game.set_weather(Weather.RAIN, 4.0)
	game._new_day(true)
	check(Weather.is_winter(game.day), "the first day of winter")
	check(game.weather == Weather.SNOW, "winter begins with snow, the rain stops")
	game.set_weather(Weather.STORM, 2.0)
	check(game.weather == Weather.SNOW, "no storm in winter")
	check(game._clock_text().contains(Lang.t("Winter")), "the clock says it is winter")
	game.day = Weather.YEAR_DAYS - 1
	game._new_day(true)
	check(not Weather.is_winter(game.day), "winter ends after 8 days")
	game.set_weather(Weather.RAIN, 2.0)
	check(game.weather == Weather.RAIN, "after winter it can rain again")
	game.day = before


func _dungeon() -> void:
	game.set_weather(Weather.SNOW, 4.0)
	game.snow_cover = 1.0
	game.load_level(0, false)
	game._tick_clock(1.0)
	game._show_weather()
	check(not game._snow.emitting and not game._snow.visible, "no flakes down in the dungeon")
	check(not Weather.cold, "no cold breath down in the dungeon")
