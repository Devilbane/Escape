class_name Soundscape
extends Node
## The ambient sound of the place the hero is in, from the Fantasy Ambience pack
## (built by tools/make_pack_sounds.py). Every loop plays on its own player and
## fades in and out (FADE seconds), so walking from the village into the woods,
## or the sky turning to night or rain, blends one soundscape into the next.
##
## Above ground, Game asks for the loops by where the hero stands (village,
## woods, beside the forge, the market, a campfire, the fields), the hour and the
## rain. Below ground, each floor has one loop by its setting (dungeon, cave,
## mine, crystal, fire, ancient halls, the spire, the ruined Sternhall courtyard, which sounds like a cave and has no birds). The hero's own house has a quiet
## hearth fire and nothing else; other rooms and houses have none: there the old
## cave air (Game._ambience) keeps playing.
##
## A cellar sounds like one: a house's cellar on the open ground (see HouseFloors),
## the cellar storey of the hero's town house and a building's cellar (the bank's
## vault) play the still, damp cellar loop (low room tone, a muffled rumble from
## outside, drips on stone, built by tools/make_cellar_sounds.py). Going down a
## cellar's stairs fades it in step by step as the hero sinks below the ground,
## and the outdoor loops fade to a faint OUTSIDE share of themselves.

## Seconds a loop takes to fade in or out.
const FADE := 3.0
## How far (in tiles) the hero hears a forge, a fire, the market or the fields.
const NEAR := 7
## The loudness of each loop at full strength, in dB (they are all cut to the same level).
const LOOPS := {
	"rain_light": -4.0, "rain": -4.0, "rain_heavy": -4.0,
	"village_night": -6.0, "amb_village_day": -6.0, "amb_townspeople": -10.0,
	"amb_blacksmith": -8.0, "amb_farm": -8.0, "amb_fire_camp": -8.0, "amb_fire_glow": -4.0,
	"amb_forest_day": -6.0, "amb_forest_deep": -6.0, "amb_forest_night": -6.0,
	"amb_dungeon_0": -4.0, "amb_dungeon_1": -4.0, "amb_dungeon_2": -4.0,
	"amb_cave_0": -4.0, "amb_cave_1": -4.0, "amb_cave_2": -4.0,
	"amb_mine_0": -4.0, "amb_mine_1": -4.0,
	"amb_magic_0": -4.0, "amb_magic_1": -4.0,
	"amb_astral_0": -4.0, "amb_astral_1": -4.0,
	"amb_cellar": -12.0,
	"crickets_loop": -14.0, "cicadas_loop": -17.0,
}
## How strong the hearth's crackle is inside the hero's own house (0 to 1): a soft
## fire in the next corner, and the only sound there (the old cave air rests).
const HOME_FIRE := 0.8
## The loop of a cellar.
const CELLAR := "amb_cellar"
## How much of the world above is still heard down in a cellar (0 to 1): the
## open-air loops, and in the town house the hearth upstairs.
const OUTSIDE := 0.15
## How deep (in metres below the ground) the hero must be in a built house's cellar
## to hear only the cellar: above it the outdoors and the cellar blend.
const CELLAR_DEEP := 1.8
## How much of the washy, echoing night-woods loop (Enchanted Forest, with its reverb baked in)
## stays in the night woods (0 to 1). The rest is replaced by the drier daytime woods bed
## (`amb_forest_deep`) so the night sounds less reverberant. Lower it for less reverb.
const NIGHT_WOODS_REVERB := 0.7
## Words in a floor's name that make it a cave.
const CAVE_NAMES := ["hoehle", "loch", "grotte", "tiefe", "nest"]

## The rain loops play through their own bus (see default_bus_layout.tres): under a roof (a built
## house or a village room one walks into, see Game._shelter) the rain still drums outside, but
## dull and quieter, as heard through the walls. Its low-pass filter falls from WEATHER_OPEN Hz
## in the open to WEATHER_INSIDE Hz indoors, and the bus is WEATHER_INSIDE_DB quieter in there.
const WEATHER_BUS := "Weather"
const WEATHER_LOOPS := ["rain_light", "rain", "rain_heavy"]
const WEATHER_OPEN := 20000.0
const WEATHER_INSIDE := 650.0
const WEATHER_INSIDE_DB := -7.0

var _players := {}
var _level := {}
var _want := {}
var _next_scan := 0.0


## The loop of an underground floor, from the headers of its map: "" for a room
## or house (it has none). `seed_text` (the level's name) picks between the
## loops of one kind, so a floor always sounds the same.
static func dungeon_loop(theme: String, walls: String, lair: bool, building: String, seed_text: String) -> String:
	if building != "" and not lair:
		return ""
	var pick := absi(hash(seed_text))
	match theme:
		"kupfer", "zwerge":
			return "amb_mine_%d" % (pick % 2)
		"kristall":
			return "amb_magic_1"
		"glut":
			return "amb_fire_glow"
		"uralt":
			return "amb_astral_%d" % (pick % 2)
		"zinne":
			return "amb_magic_0"
		"wueste":
			return "amb_forest_deep"  # the wind over the empty sand
		"nohpaan":
			return "amb_forest_deep"  # wind in the cedars
		"sternhof":
			return "amb_cave_%d" % (pick % 3)  # the ruined courtyard sounds like a cave: drips, low drone, echoes, no birds
	if lair or walls in ["rock", "bone", "crystal", "obsidian"]:
		return "amb_cave_%d" % (pick % 3)
	for word in CAVE_NAMES:
		if seed_text.contains(word):
			return "amb_cave_%d" % (pick % 3)
	return "amb_dungeon_%d" % (pick % 3)


## The strength (0 to 1) of every outdoor loop at one spot. `near` is the
## nearness (0 to 1) of "forge", "fire", "market" and "fields"; `village` says
## the hero is among the houses; `rain` is how hard it rains (0 to 1).
static func outdoor_mix(village: bool, night: bool, near: Dictionary, rain: float, insects := {}) -> Dictionary:
	var mix := {}
	# The insects of the season and the hour (see InsectLife): the cricket chorus and the cicadas' drone.
	var shy := 0.6 if village else 1.0
	for loop: String in ["crickets_loop", "cicadas_loop"]:
		var level := float(insects.get(loop, 0.0)) * shy
		if level > 0.01:
			mix[loop] = level
	if village:
		mix["village_night" if night else "amb_village_day"] = 1.0
		if not night:
			mix["amb_townspeople"] = float(near.get("market", 0.0))
		mix["amb_blacksmith"] = float(near.get("forge", 0.0)) * (0.0 if night else 1.0)
	else:
		mix["amb_forest_night" if night else "amb_forest_day"] = NIGHT_WOODS_REVERB if night else 1.0
		mix["amb_forest_deep"] = (1.0 - NIGHT_WOODS_REVERB) * 0.5 if night else 0.4
	mix["amb_farm"] = float(near.get("fields", 0.0)) * (0.0 if night else 1.0)
	mix["amb_fire_camp"] = float(near.get("fire", 0.0))
	if rain > 0.02:
		mix["rain_light"] = rain * (1.0 - smoothstep(0.25, 0.55, rain))
		mix["rain"] = rain * smoothstep(0.1, 0.4, rain) * (1.0 - smoothstep(0.6, 0.9, rain))
		mix["rain_heavy"] = rain * smoothstep(0.6, 0.9, rain)
	return mix


## How near the hero is to each kind of place on the open ground: for every
## kind, 0 beyond NEAR tiles and up to 1 on the spot.
static func nearness(level: Level, pos: Vector3) -> Dictionary:
	var letters := {"j": "forge", "f": "fire", "m": "market", ":": "market", "y": "fields", "u": "fields"}
	var near := {}
	var c := level.world_to_cell(pos)
	for dy in range(-NEAR, NEAR + 1):
		for dx in range(-NEAR, NEAR + 1):
			var kind: String = letters.get(level.cell_char(c + Vector2i(dx, dy)), "")
			if kind != "":
				near[kind] = maxf(float(near.get(kind, 0.0)), 1.0 - Vector2(dx, dy).length() / (NEAR + 1.0))
	return near


## How far down a built house's cellar `pos` is, from 0 (on the ground, or not
## in a cellar) to 1 (CELLAR_DEEP or more below it): halfway down the stairs the
## cellar and the outdoors blend.
static func cellar_depth(floors: HouseFloors, pos: Vector3) -> float:
	if floors == null or pos.y >= 0.0 or not floors.covers(pos):
		return 0.0
	if floors.storey_at(pos) != HouseFloors.CELLAR:
		return 0.0
	return clampf(-pos.y / CELLAR_DEEP, 0.0, 1.0)


## The open-air `mix` heard from a cellar `depth` deep (0 to 1): the outdoors
## fades to OUTSIDE of itself while the cellar loop rises.
static func cellar_mix(mix: Dictionary, depth: float) -> Dictionary:
	if depth <= 0.0:
		return mix
	var out := {}
	for sound in mix:
		out[sound] = float(mix[sound]) * lerpf(1.0, OUTSIDE, depth)
	out[CELLAR] = maxf(float(out.get(CELLAR, 0.0)), depth)
	return out


## Whether a floor below ground, from the headers of its map, is a building's
## cellar with no loop of its own (the bank's vault): it sounds like a cellar.
static func cellar_floor(building: String, lair: bool, floor_name: String) -> bool:
	return building != "" and not lair and floor_name == "cellar"


## The same, for a loaded floor.
static func is_cellar_floor(level: Level) -> bool:
	return cellar_floor(level.building, level.lair, level.floor_name)


## What each loop should be at this moment, for the place Game is showing.
static func wanted(game: Node) -> Dictionary:
	var level: Level = game.level
	if level == null:
		return {}
	if level is Outdoor:
		if game.player == null:
			return {}
		var pos: Vector3 = game.player.global_position
		var village: bool = level._in_village(level.world_to_cell(pos))
		var hour: float = game.day_hour
		var insects := {
			"crickets_loop": InsectLife.level_crickets(level.season_day, hour, game.weather),
			"cicadas_loop": InsectLife.level_cicadas(level.season_day, hour, game.weather),
		}
		var mix := outdoor_mix(village, DayNight.is_night(game.day_hour), nearness(level, pos), float(game._weather_look.rain), insects)
		return cellar_mix(mix, cellar_depth(level.house_floors, pos))
	if level.is_home:
		if game.player != null and level.storey_of(level.world_to_cell(game.player.global_position)) < 0:
			return {CELLAR: 1.0, "amb_fire_camp": HOME_FIRE * OUTSIDE}
		return {"amb_fire_camp": HOME_FIRE}
	if is_cellar_floor(level):
		return {CELLAR: 1.0}
	var loop := dungeon_loop(level.theme, level.wall_style, level.lair, level.building, level.level_name)
	return {loop: 1.0} if loop != "" else {}


## Whether the floor below ground has a loop of its own (so the old cave air can rest).
static func covers_dungeon(level: Level) -> bool:
	return level != null and not level is Outdoor and (level.is_home or is_cellar_floor(level) or dungeon_loop(level.theme, level.wall_style, level.lair, level.building, level.level_name) != "")


## Called every frame by Game: fades every loop to its strength.
func tick(game: Node, delta: float) -> void:
	muffle(float(game.get("_shelter")) if game.get("_shelter") != null else 0.0)
	_next_scan -= delta
	if _next_scan <= 0.0:
		_next_scan = 0.4
		_want = wanted(game)
	for sound: String in LOOPS:
		var goal := float(_want.get(sound, 0.0))
		var now := move_toward(float(_level.get(sound, 0.0)), goal, delta / FADE)
		_level[sound] = now
		var player: AudioStreamPlayer = _players.get(sound)
		if now <= 0.001:
			if player and player.playing:
				player.stop()
			continue
		if player == null:
			player = Sfx.start_loop(self, sound)
			if sound in WEATHER_LOOPS and AudioServer.get_bus_index(WEATHER_BUS) >= 0:
				player.bus = WEATHER_BUS
			_players[sound] = player
		player.volume_db = float(LOOPS[sound]) + linear_to_db(now)
		if not player.playing:
			player.play()


## How muffled the rain is: 0 out in the open, 1 under a roof (see WEATHER_BUS).
static func muffle(indoors: float) -> void:
	var bus := AudioServer.get_bus_index(WEATHER_BUS)
	if bus < 0:
		return
	var k := clampf(indoors, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus, WEATHER_INSIDE_DB * k)
	var filter := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	if filter != null:
		# Down in even steps of pitch, not of hertz, so the walls close in smoothly.
		filter.cutoff_hz = WEATHER_OPEN * pow(WEATHER_INSIDE / WEATHER_OPEN, k)
