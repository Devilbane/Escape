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
## mine, crystal, fire, ancient halls, the spire, the open Sternhall courtyard). The hero's own house has a quiet
## hearth fire and nothing else; other rooms and houses have none: there the old
## cave air (Game._ambience) keeps playing.

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
}
## How strong the hearth's crackle is inside the hero's own house (0 to 1): a soft
## fire in the next corner, and the only sound there (the old cave air rests).
const HOME_FIRE := 0.5
## Words in a floor's name that make it a cave.
const CAVE_NAMES := ["hoehle", "loch", "grotte", "tiefe", "nest"]

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
		"sternhof":
			return "amb_forest_deep"  # open sky over the ruins: wind and leaves, not a drone
	if lair or walls in ["rock", "bone", "crystal", "obsidian"]:
		return "amb_cave_%d" % (pick % 3)
	for word in CAVE_NAMES:
		if seed_text.contains(word):
			return "amb_cave_%d" % (pick % 3)
	return "amb_dungeon_%d" % (pick % 3)


## The strength (0 to 1) of every outdoor loop at one spot. `near` is the
## nearness (0 to 1) of "forge", "fire", "market" and "fields"; `village` says
## the hero is among the houses; `rain` is how hard it rains (0 to 1).
static func outdoor_mix(village: bool, night: bool, near: Dictionary, rain: float) -> Dictionary:
	var mix := {}
	if village:
		mix["village_night" if night else "amb_village_day"] = 1.0
		if not night:
			mix["amb_townspeople"] = float(near.get("market", 0.0))
		mix["amb_blacksmith"] = float(near.get("forge", 0.0)) * (0.0 if night else 1.0)
	else:
		mix["amb_forest_night" if night else "amb_forest_day"] = 1.0
		if not night:
			mix["amb_forest_deep"] = 0.4
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


## What each loop should be at this moment, for the place Game is showing.
static func wanted(game: Node) -> Dictionary:
	var level: Level = game.level
	if level == null:
		return {}
	if level is Outdoor:
		if game.player == null:
			return {}
		var village: bool = level._in_village(level.world_to_cell(game.player.global_position))
		return outdoor_mix(village, DayNight.is_night(game.day_hour), nearness(level, game.player.global_position), float(game._weather_look.rain))
	if level.is_home:
		return {"amb_fire_camp": HOME_FIRE}
	var loop := dungeon_loop(level.theme, level.wall_style, level.lair, level.building, level.level_name)
	return {loop: 1.0} if loop != "" else {}


## Whether the floor below ground has a loop of its own (so the old cave air can rest).
static func covers_dungeon(level: Level) -> bool:
	return level != null and not level is Outdoor and (level.is_home or dungeon_loop(level.theme, level.wall_style, level.lair, level.building, level.level_name) != "")


## Called every frame by Game: fades every loop to its strength.
func tick(game: Node, delta: float) -> void:
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
			_players[sound] = player
		player.volume_db = float(LOOPS[sound]) + linear_to_db(now)
		if not player.playing:
			player.play()
