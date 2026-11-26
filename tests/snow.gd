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
	WalkIn.lock_halls = false # these tests walk into halls at any hour (see tests/village_halls.gd for the locks)
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
	# In winter a thin flurry falls in any weather; a snowfall brings the full count.
	var rain := Weather.make_rain()
	var mist := Weather.make_mist()
	var flakes := Weather.make_snow()
	Weather.show_particles(rain, mist, Weather.look(Weather.CLEAR), 1.0, flakes, true)
	check(flakes.emitting and flakes.amount == Weather.WINTER_FLAKES, "a clear winter day has a few flakes")
	Weather.show_particles(rain, mist, Weather.look(Weather.SNOW), 1.0, flakes, true)
	check(flakes.emitting and flakes.amount == Weather.SNOW_FLAKES, "a winter snowfall brings them all")
	Weather.show_particles(rain, mist, Weather.look(Weather.CLEAR), 1.0, flakes, false)
	check(not flakes.emitting and flakes.amount == Weather.SNOW_FLAKES, "a clear day out of winter has none")
	# The flakes give no light of their own: they show only as much as light reaches them (the
	# moon of tonight's phase, lamps, the hero's lantern), and an unlit flake adds nothing.
	var flake_mat := (flakes.mesh as QuadMesh).material as ShaderMaterial
	var flake_code := flake_mat.shader.code if flake_mat else ""
	check(flake_mat != null and not flake_code.contains("unshaded") and flake_code.contains("blend_add") and flake_code.contains("void light()"), "snowflakes are lit by the light that reaches them, never glowing")
	for node: Node in [rain, mist, flakes]:
		node.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 40:
		var hours := Weather.spell(rng, Weather.SNOW)
		check(hours >= Weather.SNOW_MIN_HOURS and hours <= Weather.SNOW_MAX_HOURS, "a flurry is brief")
		check(hours <= Weather.MAX_HOURS * 0.6, "snowfall is shorter than other spells")
	var seen := {}
	for i in 600:
		seen[Weather.roll(12.0 + (i % 12), rng, Weather.CLEAR, Weather.WINTER)] = true
	check(seen.has(Weather.SNOW), "snow comes up in the winter rolls")
	check(not seen.has(Weather.RAIN) and not seen.has(Weather.STORM), "no rain and no storm in winter")
	# The year: a week of winter at the end of every one.
	var winter_days := 0
	for d in Weather.YEAR_DAYS:
		if Weather.is_winter(d):
			winter_days += 1
	check(winter_days == 7, "winter lasts 7 days (%d)" % winter_days)
	check(not Weather.is_winter(0) and Weather.is_winter(Weather.YEAR_DAYS - 1), "a year starts out of winter and ends in it")
	check(not Weather.is_winter(Weather.YEAR_DAYS), "the next year starts out of winter")
	check(Weather.for_season(Weather.RAIN, true) == Weather.SNOW and Weather.for_season(Weather.STORM, true) == Weather.SNOW, "in winter snow comes instead of rain")
	check(Weather.for_season(Weather.RAIN, false) == Weather.RAIN, "out of winter rain is rain")
	check(Weather.snow_cover(1.0, Weather.CLEAR, 100000.0, true) == 1.0, "winter snow does not melt in dry weather")
	check(Weather.snow_cover(1.0, Weather.CLEAR, 100000.0) == 0.0, "out of winter it melts")
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
	# Every creature that takes up room, the village cat, and a kind that extends a bare one (a bandit chief
	# is an enemy, a spider queen too) wears no snow on its back.
	var creatures: Array = get_nodes_in_group(Footprint.GROUP)
	if lvl.village_cat != null:
		creatures.append(lvl.village_cat)
	var coated := 0
	for mi: MeshInstance3D in lvl.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay == null:
			continue
		var holder: Node = mi
		while holder != null and holder != lvl:
			if holder in creatures:
				coated += 1
				break
			holder = holder.get_parent()
	check(coated == 0, "no animal or creature wears snow on its back (%d meshes)" % coated)
	var queen := CharacterBody3D.new()
	queen.set_script(load("res://scripts/spider_queen.gd"))
	check(SnowCover.bare(queen), "a kind that extends a bare one stays bare too")
	queen.free()
	check(lvl.village_cat == null or SnowCover.bare(lvl.village_cat), "the village cat wears no snow")
	var shaded: ShaderMaterial = lvl.snow.material
	check(lvl.warm_spots.size() >= 3 and int(shaded.get_shader_parameter("warm_count")) == mini(lvl.warm_spots.size(), SnowCover.WARM_MAX), "fires, the forge and the chimneys keep the snow off (%d spots)" % lvl.warm_spots.size())
	var glowing := 0
	for mi: MeshInstance3D in lvl.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay == lvl.snow.material and mi.material_override is BaseMaterial3D and (mi.material_override as BaseMaterial3D).emission_enabled:
			glowing += 1
	check(glowing == 0, "nothing glowing (coals, embers) wears snow")
	check(float(shaded.get_shader_parameter("amount")) > 0.5, "the shader knows how thick the snow lies")
	# The ground round the village houses one walks into takes snow up to their walls: only their
	# rooms are kept bare (see Outdoor.walk_in_room), not the whole block they stand on.
	var rooms := 0
	for rec in lvl.walk_in.buildings:
		var room := lvl.walk_in_room(rec.node)
		if not room.has_area():
			continue
		rooms += 1
		var block: Rect2i = rec.block
		var block_area := float(block.get_area()) * Outdoor.TILE * Outdoor.TILE
		var centre := (rec.node as Node3D).global_position
		check(room.has_point(Vector2(centre.x, centre.z)) and room.get_area() < block_area * 0.7, "%s keeps only its rooms bare (%s of a %.0f m² block)" % [rec.kind, room.size, block_area])
	check(rooms >= 3 and bool(shaded.get_shader_parameter("rooms_on")), "the snow knows the rooms of the houses (%d)" % rooms)
	# The temple keeps only its nave bare, not the grass round it.
	for rec in lvl.walk_in.buildings:
		if rec.kind == "temple":
			var nave := lvl.temple_room(rec.node)
			var block_area := float((rec.block as Rect2i).get_area()) * Outdoor.TILE * Outdoor.TILE
			check(nave.has_area() and nave.get_area() < block_area * 0.7, "the temple keeps only its nave bare (%s of a %.0f m² block)" % [nave.size, block_area])
	# Every storey under their roof is inside: the mask reaches up to the eaves, so no snow lies on
	# the upper floor's furniture and stairs (the guildhall's first floor).
	var mask: Texture2D = shaded.get_shader_parameter("room_mask")
	if mask != null and not lvl.walk_in.buildings.is_empty():
		var img := mask.get_image()
		var highest := 0.0
		for rec in lvl.walk_in.buildings:
			var at := (rec.node as Node3D).global_position
			var px := Vector2i(((Vector2(at.x, at.z) + Vector2.ONE * Outdoor.TILE * 0.5) / SnowCover.ROOM_STEP).floor())
			if lvl.walk_in_room(rec.node).has_area():
				highest = maxf(highest, img.get_pixelv(px).r * SnowCover.SHELTER_SCALE)
		check(highest > VillageHouse.PLINTH + VillageHouse.GROUND + 1.5, "the rooms reach up through the upper floor (%.2f m)" % highest)
	# The shader also knows each room's exact walls, so no strip of lawn stays bare outside them.
	if not lvl.walk_in.buildings.is_empty():
		var rects: PackedVector4Array = shaded.get_shader_parameter("room_rects")
		check(bool(shaded.get_shader_parameter("rooms_exact")) and rects.size() == int(shaded.get_shader_parameter("room_count")) and rects.size() > 0, "the rooms' exact walls are given to the snow shader (%d rooms)" % rects.size())
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
	var gates := lvl.find_children("GateSnow", "MeshInstance3D", true, false)
	check(gates.size() >= 1, "the dungeon gates wear snow, drifts and icicles")
	check(gates.all(func(g: MeshInstance3D): return g.is_in_group(SnowCaps.GROUP)), "gate snow melts with the rest")
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
	# Every walker's print (hero, townsfolk, animals, birds, monsters) goes through snow_print: it
	# lies at the fixed height, is lit like the snow (so it takes the colour of the hour's light, never a cold
	# grey of its own), and is a neutral grey darker than the snow at night, morning, noon and dusk.
	var snow_white := 0.9
	for light in [0.0, 0.25, 0.5, 0.75, 1.0]:
		lvl.snow.set_amount(1.0, light)
		for kind in SnowPrints.KINDS:
			var pr: MeshInstance3D = SnowPrints.leave(lvl, Vector3(2, 0, 2), 0.0, 1.0, kind, lvl.snow.daylight)
			var m := pr.material_override as StandardMaterial3D
			check(is_equal_approx(pr.global_position.y, SnowPrints.HEIGHT), "a %s print lies at the fixed height" % kind)
			check(m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "a %s print is lit like the snow" % kind)
			check(is_equal_approx(m.albedo_color.r, m.albedo_color.b), "a %s print is a neutral grey, not blue" % kind)
			check(m.albedo_color.v < snow_white * 0.75 and m.albedo_color.a > 0.8, "a %s print shows at light %.2f" % [kind, light])
	game.snow_cover = 1.0
	game._tick_clock(0.05)
	# The evening at 19:45, as the clock really brings it: the hero's boot shows there too.
	game.day_hour = 19.75
	game._tick_clock(0.05)
	game.snow_cover = 1.0
	game._tick_clock(0.05)
	lvl.snow_print(Vector3(3, 0, 3), 0.0)
	var evening: MeshInstance3D = SnowPrints._live.back() if SnowPrints._live.size() > 0 else null
	check(evening != null, "a print at 19:45")
	if evening != null:
		check((evening.material_override as StandardMaterial3D).albedo_color.v < 0.7, "the print at 19:45 is darker than the snow")
	check(SnowPrints.KINDS.has("bug"), "beetles press tiny tracks")
	var crawlers := SurfaceLife.new(lvl)
	crawlers._spawn("beetle", Vector3(5, 0, 5), "forest")
	var beetle: Node = crawlers.get_child(crawlers.get_child_count() - 1)
	check(SnowCover.bare(beetle), "a beetle wears no snow coat")
	crawlers.free()
	# Animals, wild or companion, press tracks in the snow, bigger than life so they read in the game view.
	for deer in ["reh", "hirsch"]:
		var trail := SnowTrail.new(deer)
		var at: Vector3 = lvl.player.global_position + Vector3(4, 0, 0)
		var pressed := SnowPrints._live.size()
		trail.follow(lvl, at)
		trail.follow(lvl, at + Vector3(0, 0, 1.0))
		trail.follow(lvl, at + Vector3(0, 0, 2.0))
		check(SnowPrints._live.size() > pressed, "a walking %s leaves prints" % deer)
	var walker := SnowTrail.new("walker")
	var pressed_by_walker := SnowPrints._live.size()
	var wat: Vector3 = lvl.player.global_position + Vector3(4, 0, 0)
	for z in 3:
		walker.follow(lvl, wat + Vector3(0, 0, float(z)))
	check(SnowPrints._live.size() > pressed_by_walker, "a skeleton on two legs still presses boots")
	check(SnowTrail.for_monster("krieger", "Skeleton_Warrior", false, 1.0) != null, "a skeleton leaves tracks")
	check(SnowTrail.for_monster("wolf", "Wolf", false, 1.0) != null, "a wolf leaves tracks")
	check(SnowTrail.for_monster("totengeist", "Skeleton_Rogue", true, 1.0) == null, "a ghost leaves none")
	check(SnowTrail.for_monster("slime", "Slime", false, 1.0) == null, "a slime leaves none")
	for i in SnowPrints.MAX + 20:
		lvl.snow_print(Vector3(i * 0.1, 0, 0), 0.0)
	check(SnowPrints._live.size() <= SnowPrints.MAX, "only so many prints at once")
	# Underground steps press nothing in the snow above, and the surface's prints hide while the hero is down there.
	SnowPrints.clear()
	var before_deep := SnowPrints._live.size()
	lvl.snow_print(Vector3(3, -2.5, 3), 0.0)
	check(SnowPrints._live.size() == before_deep, "a step underground presses no print on the surface")
	lvl.snow_print(Vector3(3, 0, 3), 0.0)
	SnowPrints.set_underground(true)
	check(not (SnowPrints._live.back() as MeshInstance3D).visible, "surface prints hide while the hero is underground")
	SnowPrints.set_underground(false)
	check((SnowPrints._live.back() as MeshInstance3D).visible, "surface prints show again up top")
	# A crowd of boots cannot push the animals' tracks out of the pool.
	SnowPrints.clear()
	for i in SnowPrints.MAX:
		lvl.snow_print(Vector3(i * 0.1, 0, 20), 0.0)
	for i in 30:
		lvl.snow_print(Vector3(i * 0.3, 0, 30), 0.0, 1.0, "hoof")
	var hooves := SnowPrints._live.filter(func(n): return n.get_meta("print_kind") == "hoof").size()
	check(hooves == 30, "hoof prints survive a crowd of boots (%d of 30)" % hooves)
	var kept: Node = SnowPrints._live[0]
	check(is_instance_valid(kept) and kept.visible, "prints stay (nothing fades them)")
	SnowPrints.clear()
	check(SnowPrints._live.is_empty(), "a new day wipes the prints")
	for i in 3:
		lvl.snow_print(Vector3(i, 0, 0), 0.0)
	# Going into a house frees the open air; coming back lays the day's prints down again.
	var other := Node3D.new()
	lvl.get_parent().add_child(other)
	SnowPrints.restore(other)
	check(SnowPrints._live.size() == 3 and SnowPrints._live[0].get_parent() == other, "the day's prints come back in a rebuilt world")
	SnowPrints.restore(lvl)
	other.free()
	# Each group has its own room: a full set of boots keeps its cap and never pushes out a beetle's dot.
	SnowPrints.clear()
	var dot := SnowPrints.leave(lvl, Vector3(0, 0, 7), 0.0, 1.0, "bug")
	for i in int(SnowPrints.ROOM["foot"]) + 5:
		SnowPrints.leave(lvl, Vector3(i * 0.05, 0, 6), 0.0, 1.0, "boot")
	var boots := SnowPrints._live.filter(func(n): return n.get_meta("print_kind") == "boot").size()
	check(boots == int(SnowPrints.ROOM["foot"]) and SnowPrints._live.has(dot), "a full set of boots keeps its cap and leaves the dot")
	# The snow melts: the prints go with it.
	game.snow_cover = 0.0
	game._tick_clock(0.05)
	check(SnowPrints._live.is_empty(), "the prints melt away with the snow")
	game.snow_cover = 1.0
	game._tick_clock(0.05)
	# Every walker's print has a picture, and the toes lead the way it goes.
	for kind in SnowPrints.KINDS:
		check(SnowPrints.texture(kind) != null, "a %s print has a picture" % kind)
	for species in Companions.SPECIES:
		check(SnowTrail.FEET.has(species), "the companion %s leaves tracks" % species)
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
	# A breath that has not been drawn yet starts blank and hidden: out of the cold it never emits,
	# and an unblanked buffer showed as clumps of coloured and dark balls by every villager.
	var fresh := Breath.new()
	var cold_puff := fresh._make_puff()
	var buffer := RenderingServer.multimesh_get_buffer(cold_puff.get_base())
	check(not cold_puff.emitting and not cold_puff.visible, "a new breath starts cold and hidden")
	check(buffer.size() == cold_puff.amount * 20 and Array(buffer).all(func(x: float) -> bool: return x == 0.0),
			"a new breath starts with a blank buffer")
	cold_puff.free()
	fresh.free()
	if puff != null:
		puff._timer = 0.0
		puff._process(0.016)
		check(puff._puff.emitting and puff._puff.visible, "a villager breathes out a cloud in the cold")
		puff._process(Breath.BLOW + 0.1)
		check(not puff._puff.emitting, "the breath stops by itself, the cloud drifts on")
		puff.exhale()
		check(puff._puff.emitting, "the next breath starts without restarting the emitter")
	game.set_weather(Weather.CLEAR, 4.0)
	game.snow_cover = 0.05
	game._show_weather()
	check(not Weather.cold, "no breath to see once the snow is nearly gone")


## Moves the seasons so that it is season day `d` (see Seasons) and lets the game notice it.
func _season_to(d: int) -> void:
	game.season_shift += d - game.season_day()
	game._check_season()
	# The HUD's season icon follows in the game's next refresh (see Game._update_hud): do it now.
	game._update_season_icon()


func _winter() -> void:
	var before: int = game.season_shift
	game.escaped = true
	_season_to(Weather.YEAR_DAYS - Weather.WINTER_DAYS - 1)
	check(game._season_icon.season == Weather.AUTUMN and game._season_icon.tooltip_text == Lang.t("Herbst"), "the HUD's season icon shows autumn")
	game.set_weather(Weather.RAIN, 4.0)
	_season_to(Weather.YEAR_DAYS - Weather.WINTER_DAYS)
	check(Weather.is_winter(game.season_day()), "the first day of winter")
	check(game.weather == Weather.SNOW, "winter begins with snow, the rain stops")
	game.set_weather(Weather.STORM, 2.0)
	check(game.weather == Weather.SNOW, "no storm in winter")
	check(game._season_icon.season == Weather.WINTER, "the season icon shows winter")
	_season_to(Weather.YEAR_DAYS - 1)
	check(Weather.is_winter(game.season_day()), "still winter on its last day")
	_season_to(Weather.YEAR_DAYS)
	check(not Weather.is_winter(game.season_day()), "winter ends after a week")
	check(game._season_icon.season == Weather.SPRING, "the season icon shows spring")
	game.set_weather(Weather.RAIN, 2.0)
	check(game.weather == Weather.RAIN, "after winter it can rain again")
	game.season_shift = before
	game._check_season()


func _dungeon() -> void:
	game.set_weather(Weather.SNOW, 4.0)
	game.snow_cover = 1.0
	game.load_level(0, false)
	game._tick_clock(1.0)
	game._show_weather()
	check(not game._snow.emitting and not game._snow.visible, "no flakes down in the dungeon")
	check(not Weather.cold, "no cold breath down in the dungeon")
