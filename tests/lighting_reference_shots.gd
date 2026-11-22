extends SceneTree
## Reference pictures of everything that depends on the lighting, taken through the game's own
## camera from fixed spots: the village through the day, the moon's phases, the weather and the
## seasons, the hero's own lantern (open, hooded, with a hand torch), lit windows, the forge and the
## braziers, the rooms one walks into, the cellars, the bank's vault, the forgotten mine and a set of
## dungeon floors. Taken once with one renderer and again with another, the two sets show what a
## renderer change does to the light (tools/lighting_compare.py puts them side by side and
## measures the difference).
##
## Run with (needs a display; --fixed-fps 10 lets fades settle within a few frames):
##   SHOTS=<folder> godot --fixed-fps 10 -s tests/lighting_reference_shots.gd
## Add --rendering-method <gl_compatibility|mobile|forward_plus> to choose the renderer.
## GRAPHICS=<quality|balanced|performance> picks the graphics preset (see Graphics); without it
## the pictures are taken at "balanced", the picture the game had before the presets.
## ONLY=<word,word> retakes only the shots whose name contains one of the words; LIST=1 only prints
## the names. Without SHOTS it loads the village, visits every spot and takes no pictures.
## Besides the pictures it writes <folder>/manifest.json: the renderer and every shot's settings.

const SUMMER := Weather.SPRING_DAYS + 2
const AUTUMN := Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS + IvySeasons.TURN_DAYS - 1
const WINTER := Weather.YEAR_DAYS - Weather.WINTER_DAYS + 1
## Nights (Game.day) with a full, a half and a new moon (see Moon.phase).
const FULL_MOON := Moon.FULL - Moon.FIRST_PHASE
const HALF_MOON := 2 - Moon.FIRST_PHASE
const NEW_MOON := Moon.CYCLE - Moon.FIRST_PHASE

## The village shots: [name, place, hour, weather, season day, night, hero, zoom].
## place: a key of _places(). hero: "" (open lantern), "sneak" (hooded) or "torch" (hand torch lit).
## zoom: 0 the normal view from above, 1 the close view.
const VILLAGE := [
	# The square through the day.
	["square_noon", "square", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["square_dawn", "square", 6.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["square_dusk", "square", 19.5, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["square_late_dusk", "square", 20.4, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	# The moon's phases.
	["square_night_full_moon", "square", 23.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["square_night_half_moon", "square", 23.0, Weather.CLEAR, SUMMER, HALF_MOON, "", 0.0],
	["square_night_new_moon", "square", 23.0, Weather.CLEAR, SUMMER, NEW_MOON, "", 0.0],
	# The weather.
	["square_noon_rain", "square", 12.0, Weather.RAIN, SUMMER, FULL_MOON, "", 0.0],
	["square_noon_storm", "square", 12.0, Weather.STORM, SUMMER, FULL_MOON, "", 0.0],
	["square_noon_fog", "square", 12.0, Weather.FOG, SUMMER, FULL_MOON, "", 0.0],
	["square_night_fog", "square", 23.0, Weather.FOG, SUMMER, FULL_MOON, "", 0.0],
	["square_night_rain", "square", 23.0, Weather.RAIN, SUMMER, FULL_MOON, "", 0.0],
	# The seasons.
	["square_noon_autumn", "square", 12.0, Weather.CLEAR, AUTUMN, FULL_MOON, "", 0.0],
	["square_noon_winter", "square", 12.0, Weather.CLEAR, WINTER, FULL_MOON, "", 0.0],
	["square_noon_snowfall", "square", 12.0, Weather.SNOW, WINTER, FULL_MOON, "", 0.0],
	["square_noon_winter_fog", "square", 12.0, Weather.FOG, WINTER, FULL_MOON, "", 0.0],
	["square_night_winter", "square", 23.0, Weather.CLEAR, WINTER, FULL_MOON, "", 0.0],
	["square_night_snowfall", "square", 23.0, Weather.SNOW, WINTER, HALF_MOON, "", 0.0],
	# The hero's own light, close up.
	["hero_noon", "street", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 1.0],
	["hero_night_full_moon", "street", 23.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 1.0],
	["hero_night_new_moon", "street", 23.0, Weather.CLEAR, SUMMER, NEW_MOON, "", 1.0],
	["hero_night_new_moon_hooded", "street", 23.0, Weather.CLEAR, SUMMER, NEW_MOON, "sneak", 1.0],
	["hero_night_new_moon_torch", "street", 23.0, Weather.CLEAR, SUMMER, NEW_MOON, "torch", 1.0],
	["hero_night_new_moon_torch_wide", "street", 23.0, Weather.CLEAR, SUMMER, NEW_MOON, "torch", 0.0],
	["hero_night_fog", "street", 23.0, Weather.FOG, SUMMER, HALF_MOON, "", 1.0],
	# Lamps, windows and fires.
	["lamp_night_new_moon", "lamp", 23.0, Weather.CLEAR, SUMMER, NEW_MOON, "", 0.0],
	["windows_night", "house_front", 23.0, Weather.CLEAR, SUMMER, HALF_MOON, "", 0.0],
	["windows_night_winter", "house_front", 23.0, Weather.CLEAR, WINTER, HALF_MOON, "", 0.0],
	["temple_night", "temple_front", 23.0, Weather.CLEAR, SUMMER, HALF_MOON, "", 0.0],
	["temple_night_fog", "temple_front", 23.0, Weather.FOG, SUMMER, HALF_MOON, "", 0.0],
	["temple_noon", "temple_front", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["forge_noon", "forge", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["forge_night", "forge", 23.0, Weather.CLEAR, SUMMER, NEW_MOON, "", 0.0],
	["braziers_night", "braziers", 22.0, Weather.CLEAR, SUMMER, HALF_MOON, "", 0.0],
	["braziers_night_winter", "braziers", 22.0, Weather.CLEAR, WINTER, HALF_MOON, "", 0.0],
	["gate_night", "gate", 23.0, Weather.CLEAR, SUMMER, HALF_MOON, "", 0.0],
	# The rooms one walks into.
	["house_inside_noon", "house_inside", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["house_inside_night", "house_inside", 23.0, Weather.CLEAR, SUMMER, HALF_MOON, "", 0.0],
	["temple_inside_noon", "temple_inside", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["temple_inside_night", "temple_inside", 23.0, Weather.CLEAR, SUMMER, HALF_MOON, "", 0.0],
	["tavern_inside_night", "tavern_inside", 23.0, Weather.CLEAR, SUMMER, HALF_MOON, "", 0.0],
	["guild_inside_noon", "guild_inside", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["guild_inside_night", "guild_inside", 23.0, Weather.CLEAR, SUMMER, HALF_MOON, "", 0.0],
	["bank_hall_noon", "bank_hall", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	# Under the ground.
	["guild_cellar", "guild_cellar", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["guild_cellar_close", "guild_cellar", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 1.0],
	["bank_vault", "bank_vault", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["bank_vault_night", "bank_vault", 23.0, Weather.CLEAR, SUMMER, NEW_MOON, "", 0.0],
	["mine_shaft", "mine_shaft", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["mine_gallery", "mine_gallery", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["mine_silver", "mine_silver", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 0.0],
	["mine_silver_close", "mine_silver", 12.0, Weather.CLEAR, SUMMER, FULL_MOON, "", 1.0],
]

## The dungeon shots: [name, part of the level file's name, hero, zoom], the hero at the floor's start.
const DUNGEONS := [
	["dungeon_cell", "01_die_zelle", "", 0.0],
	["dungeon_cell_hooded", "01_die_zelle", "sneak", 0.0],
	["dungeon_cell_close", "01_die_zelle", "", 1.0],
	["dungeon_crypt", "04_die_gruft", "", 0.0],
	["dungeon_library", "07_die_bibliothek", "", 0.0],
	["dungeon_vault_cellar", "12_der_tresorkeller", "", 0.0],
	["dungeon_dragon_cave", "13_die_drachenhoehle", "", 0.0],
	["dungeon_open_grave_dark", "15_das_offene_grab", "", 0.0],
	["dungeon_open_grave_torch", "15_das_offene_grab", "torch", 0.0],
	["dungeon_copper_mine", "19_die_kupfergrube", "", 0.0],
	["dungeon_crystal_grotto", "20_die_kristallgrotte", "", 0.0],
	["dungeon_ember_tunnels", "22_die_glutstollen", "", 0.0],
	["dungeon_ash_spire", "31_die_aschenzinne", "", 0.0],
	["dungeon_star_vault", "37_die_kellergewoelbe", "", 0.0],
	["dungeon_desert", "40_die_verlassene_wueste", "", 0.0],
]

## Frames a shot waits before the picture (at --fixed-fps 10: lamp shadows fade in over 1.2 s).
const SETTLE := 16
## Frames more after the season, the place's depth or the floor changed.
const SETTLE_LONG := 30

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
var only := OS.get_environment("ONLY").split(",", false)
var taken: Array = []
var _season := -1
var _place := ""
var failures := 0
## How far (metres) the hero may drift from a shot's spot while the picture settles.
const STRAY := 2.0


func _initialize() -> void:
	if OS.get_environment("LIST") != "":
		for s: Array in VILLAGE + DUNGEONS:
			print(s[0])
		quit(0)
		return
	# The same dice every run, so villagers, flames and leaves start alike.
	seed(20261122)
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	Bank.reload()
	Bank.rent_vault("Light test")
	Bank.deposit("Light test", 120)
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _wanted(name: String) -> bool:
	if only.is_empty():
		return true
	for word: String in only:
		if name.contains(word):
			return true
	return false


## Where the hero stands for each place (world coordinates), found from the map itself so the
## spots survive a rebuilt village.
func _places(lvl: Outdoor) -> Dictionary:
	var at := {}
	var fountain := lvl.get_node_or_null("VillageFountain") as Node3D
	at["square"] = (fountain.global_position if fountain else lvl.spots.square[0] as Vector3) + Vector3(0, 0.1, 6.0)
	at["street"] = (lvl.spots.square[0] as Vector3) + Vector3(-6.0, 0.1, 4.0)
	at["lamp"] = Vector3(lvl._lamps[3].global_position.x + 1.5, 0.1, lvl._lamps[3].global_position.z + 2.5)
	at["house_front"] = (lvl.spots.houses[0] as Vector3) + Vector3(0, 0.1, 3.0)
	at["temple_front"] = (lvl.doors["s"] as Vector3) + Vector3(0, 0.1, 5.0)
	var embers := lvl.get_node_or_null("ForgeEmbers") as Node3D
	at["forge"] = (embers.global_position if embers else lvl.spots.square[0] as Vector3) * Vector3(1, 0, 1) + Vector3(1.5, 0.1, 4.0)
	at["braziers"] = ((lvl.meals.tables[0] as Vector3) + (lvl.meals.tables[-1] as Vector3)) * 0.5 + Vector3(0, 0.1, -4.0)
	at["gate"] = (lvl.doors["R"] as Vector3) + Vector3(0, 0.1, 4.0)
	for rec: Dictionary in lvl.walk_in.buildings:
		var key: String = rec.kind + "_inside"
		if at.has(key) or not rec.has("room"):
			continue
		var room: Rect2 = rec.room
		at[key] = (rec.node as Node3D).global_transform * Vector3(room.get_center().x, rec.floor, room.get_center().y + room.size.y * 0.25)
		if rec.kind == "guild":
			at["guild_cellar"] = (rec.node as Node3D).global_transform * Vector3(-0.8, GuildHall.CELLAR + 0.1, 0.6)
	at["bank_hall"] = BankHall.world(Vector2(4.2, 4.2)) + Vector3(0, 0.1, 0)
	at["bank_vault"] = BankVault.floor_at(Vector2i(8, 9)) + Vector3(0, 0.1, 0)
	at["mine_shaft"] = LostMine.floor_at(Vector2i(42, 29)) + Vector3(0, 0.1, 0)
	at["mine_gallery"] = LostMine.floor_at(Vector2i(31, 31)) + Vector3(0, 0.1, 0)
	at["mine_silver"] = LostMine.floor_at(Vector2i(27, 29)) + Vector3(0, 0.1, 0)
	return at


## The hero's own light: the lantern open or hooded, the hand torch lit or out.
func _dress_hero(hero_look: String) -> void:
	var hero: Player = game.player
	hero.set_sneaking(hero_look == "sneak")
	var torch: HandTorch = hero.torch
	if torch == null:
		return
	if (hero_look == "torch") != torch.lit:
		if not torch.has_torch():
			hero.bag.append(HandTorch.ITEM)
		torch.toggle()


func _zoom(zoom: float) -> void:
	game._zoom = zoom
	game._zoom_target = zoom


## Waits for the picture to settle, holding the hour, and saves it.
func _take(name: String, hour: float, wait: int, facts: Dictionary) -> void:
	for i in wait:
		game.day_hour = hour
		await process_frame
	facts["name"] = name
	taken.append(facts)
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("shot ", name)


## Waits `wait` frames with the hero standing at `spot`, holding the hour. Something may carry the
## hero off meanwhile (an eagle's flight, a door stepped into, a blow): then the hero is put back
## and the wait starts again, three times at most. False when the hero would not stay.
func _hold(spot: Vector3, hour: float, wait: int) -> bool:
	for attempt in 3:
		var stayed := true
		for i in wait:
			game.day_hour = hour
			await process_frame
			if not is_instance_valid(game.level) or not game.level is Outdoor or not is_instance_valid(game.player):
				return false
			var at: Vector3 = game.player.global_position
			if Vector2(at.x - spot.x, at.z - spot.z).length() > STRAY or absf(at.y - spot.y) > STRAY:
				stayed = false
				break
		if stayed:
			return true
		game.player.global_position = spot
		game.player.velocity = Vector3.ZERO
		game._snap_camera()
	return false


func _hide_hud() -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false


func _run() -> void:
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Light test"
	# The settings file may name another preset: the pictures are taken with the one asked for.
	var graphics := OS.get_environment("GRAPHICS")
	Graphics.preset = graphics if graphics in Graphics.PRESETS else Graphics.BALANCED
	Graphics.apply(root)
	game.escaped = true
	await _wait(5)
	if VILLAGE.any(func(s): return _wanted(s[0])):
		await _village()
	for shot: Array in DUNGEONS:
		if _wanted(shot[0]):
			await _dungeon(shot)
	if shots != "":
		var manifest := {
			"method": RenderingServer.get_current_rendering_method(),
			"driver": RenderingServer.get_current_rendering_driver_name(),
			"adapter": RenderingServer.get_video_adapter_name(),
			"size": [root.size.x, root.size.y],
			"engine": Engine.get_version_info().string,
			"graphics": Graphics.preset,
			"shots": taken,
		}
		var file := FileAccess.open(shots.path_join("manifest.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	game.delete_save(game.save_path())
	var wanted := (VILLAGE + DUNGEONS).filter(func(s): return _wanted(s[0])).size()
	if taken.size() < wanted:
		failures += wanted - taken.size()
	if failures > 0:
		print("FAILED: lighting reference shots (%d of %d taken)" % [taken.size(), wanted])
	else:
		print("PASS: lighting reference shots (%d)" % taken.size())
	quit(1 if failures > 0 else 0)


func _village() -> void:
	var lvl: Outdoor = null
	var places := {}
	for shot: Array in VILLAGE:
		var name: String = shot[0]
		if not _wanted(name):
			continue
		if not is_instance_valid(lvl) or game.level != lvl:
			# The first shot, or the hero left the village (a door, a flight): load it again.
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			await _wait(20)
			lvl = game.level
			places = _places(lvl)
			_place = ""
		var place: String = shot[1]
		if not places.has(place):
			failures += 1
			print("FAIL: ", name, ": no ", place, " on this map")
			continue
		var hour: float = shot[2]
		var season: int = shot[4]
		var winter := Weather.is_winter(season)
		var wait := SETTLE
		if season != _season or place != _place:
			wait += SETTLE_LONG
		_season = season
		_place = place
		game.season_shift = season - Seasons.today()
		game.day = shot[5]
		game.day_hour = hour
		game.snow_cover = 1.0 if winter else 0.0
		game.puddle_water = 1.0 if shot[3] in [Weather.RAIN, Weather.STORM] and not winter else 0.0
		game.set_weather(shot[3], 100.0)
		game._weather_look = Weather.look(game.weather)
		lvl.set_winter_wear(winter, true)
		if wait > SETTLE and place != "street":
			# Up to the surface first: CellarView keeps the cellar the hero went down into, so a
			# jump from one cellar straight into another would leave the first one showing.
			game.player.global_position = places["street"]
			await _wait(3)
		game.player.global_position = places[place]
		game.player.velocity = Vector3.ZERO
		_dress_hero(shot[6])
		_zoom(shot[7])
		game._snap_camera()
		_hide_hud()
		var facts := {"place": place, "hour": hour, "weather": shot[3], "season_day": season,
				"moon": Moon.word(shot[5]), "hero": shot[6], "zoom": shot[7]}
		if not await _hold(places[place], hour, wait):
			failures += 1
			print("FAIL: ", name, ": the hero did not stay at ", place)
			continue
		await _take(name, hour, 0, facts)
	_dress_hero("")
	_zoom(0.0)


func _dungeon(shot: Array) -> void:
	var index := -1
	for i in game.level_files.size():
		if (game.level_files[i] as String).contains(shot[1]):
			index = i
	if index < 0:
		print("SKIP ", shot[0], ": no floor ", shot[1])
		return
	var wait := SETTLE
	if _place != shot[1]:
		game.load_level(index, false)
		game.state = game.State.PLAYING
		wait += SETTLE_LONG
		_place = shot[1]
		_season = -1
	_dress_hero(shot[2])
	_zoom(shot[3])
	game._snap_camera()
	_hide_hud()
	await _take(shot[0], game.day_hour, wait, {"place": shot[1], "hero": shot[2], "zoom": shot[3]})
	_dress_hero("")
	_zoom(0.0)
