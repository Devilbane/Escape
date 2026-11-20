class_name Seasons
extends RefCounted
## The seasons follow the real calendar, not the game's days: spring, summer, autumn and winter last
## one real week each (Weather.SEASON_DAYS), so the year comes round every four real weeks. A season
## turns at local midnight between Sunday and Monday.
##
## A "season day" (what Weather.is_winter, Weather.is_autumn and IvySeasons.stage take) counts real
## days: today() is the one the player's clock is on. Game.season_shift moves it for the sky command
## (weather:winter, weather:autumn, weather:spring) and is kept in the save.
##
## The headless tests (a script run with -s) must not depend on the week they run in: for them the
## clock stands still on TEST_DAY, the first day of summer, and a test moves Game.season_shift.

## Real days from 1970-01-01 to Monday 2026-11-16, the first day of an autumn.
const AUTUMN_MONDAY := 20773
## The season day the tests' clock stands on (see above).
const TEST_DAY := Weather.SPRING_DAYS


## The season day of `unix` (seconds, the system's clock by default), in the player's time zone.
static func today(unix := -1.0) -> int:
	if unix < 0.0:
		if _in_test():
			return TEST_DAY
		unix = Time.get_unix_time_from_system() + float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	var days := floori(unix / 86400.0)
	return days - AUTUMN_MONDAY + Weather.AUTUMN_FROM


## The name of the season on season day `day` ("spring", "summer", "autumn" or "winter").
static func name_of(day: int) -> String:
	if Weather.is_winter(day):
		return "winter"
	if Weather.is_autumn(day):
		return "autumn"
	if Weather.is_spring(day):
		return "spring"
	return "summer"


## Whether a test script runs the game (godot -s tests/<name>.gd): its main loop has a script.
static func _in_test() -> bool:
	var loop := Engine.get_main_loop()
	return loop != null and loop.get_script() != null
