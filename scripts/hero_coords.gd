class_name HeroCoords
extends RefCounted
## The hero's position as a readable line for screenshots and bug reports. F2 shows or hides it
## under the life bar (see Game._input and Game._place_hp_bar). It uses the map's tile
## coordinates, the same grid as the map files in levels/, so "(149, 127)" names one tile.
##
## Two lines: the area name with the tile, then the clock and the season.


## "Dorfplatz  (149, 127)": the area's name, then the tile column and row the hero stands on.
static func line(level: Level, hero_position: Vector3) -> String:
	var cell := level.world_to_cell(hero_position)
	return "%s  (%d, %d)" % [Lang.t(level.level_name), cell.x, cell.y]


## "21:30  Herbst": the clock (see DayNight.clock_text) and the season (a word of Seasons.WORDS, translated), for the
## second line under the coordinates. No part-of-day word: the HUD dropped those on purpose.
static func time_line(hour: float, season: String) -> String:
	return "%s  %s" % [DayNight.clock_text(hour), Lang.t(Seasons.WORDS.get(season, season)).capitalize()]
