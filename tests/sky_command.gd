extends SceneTree
## Headless test for the chat line's weather and time commands (see
## SkyCommand, Game._sky_command): the words parse in any order and any part
## alone, a bad word lists the options, and the command forces the weather,
## the hour, the season and a full layer of snow.
## Run with: godot --headless --fixed-fps 60 -s tests/sky_command.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	for i in 10:
		await process_frame

	# The words.
	check(SkyCommand.parse("Hallo") == null, "other lines are no command")
	var a: Dictionary = SkyCommand.parse("weather:rain-noon")
	check(a.weather == Weather.RAIN and is_equal_approx(a.hour, 12.0) and a.winter == -1, "rain-noon")
	a = SkyCommand.parse("Weather:Snow")
	check(a.weather == Weather.SNOW and a.hour < 0.0, "snow alone")
	a = SkyCommand.parse("weather:-night")
	check(a.weather == "" and is_equal_approx(a.hour, 23.0), "night alone")
	a = SkyCommand.parse("time:14:30")
	check(is_equal_approx(a.hour, 14.5), "an hour with minutes")
	a = SkyCommand.parse("time:14")
	check(is_equal_approx(a.hour, 14.0), "an hour")
	a = SkyCommand.parse("weather:winter-fog-dusk")
	check(a.winter == 1 and a.weather == Weather.FOG and is_equal_approx(a.hour, 19.5), "season, weather and time")
	for w in ["clear", "rain", "fog", "storm", "snow"]:
		check(SkyCommand.parse("weather:" + w).weather == w, "weather " + w)
	for t in SkyCommand.TIMES:
		check(SkyCommand.parse("time:" + t).hour == SkyCommand.TIMES[t], "time " + t)
	check(SkyCommand.parse("weather:hail").error == "hail", "a bad word is named")
	check(SkyCommand.parse("time:25").has("error"), "25 is no hour")
	check(SkyCommand.parse("weather:").error == "", "an empty command lists the options")
	for line in SkyCommand.HELP:
		check(Lang.EN.has(line), "help has an English text: " + line)
	# The seasons.
	check(Weather.is_winter(SkyCommand.day_for(3, true)) and not Weather.is_winter(SkyCommand.day_for(26, false)), "season days")
	check(SkyCommand.day_for(26, false) == Weather.YEAR_DAYS, "spring is the next year's start")

	# The game.
	var news: Array = game.event_log.entries()
	var n := news.size()
	game._hero_says("weather:snow-noon")
	check(game.weather == Weather.SNOW and is_equal_approx(game.day_hour, 12.0), "snow at noon")
	check(is_equal_approx(game.snow_cover, 1.0), "snow lies fully")
	check(game.event_log.entries().size() > n and game.event_log.entries()[-1].contains("12:00"), "confirmation: %s" % game.event_log.entries()[-1])
	game._hero_says("weather:rain")
	check(game.weather == Weather.RAIN and is_equal_approx(game.day_hour, 12.0), "rain keeps the hour")
	game._hero_says("time:0")
	check(is_equal_approx(game.day_hour, 0.0) and game.weather == Weather.RAIN, "time keeps the weather")
	game._hero_says("weather:winter")
	check(Weather.is_winter(game.season_day()) and game.weather == Weather.SNOW and game.snow_cover == 1.0, "winter on")
	game._hero_says("weather:storm")
	check(not Weather.is_winter(game.season_day()) and game.weather == Weather.STORM, "a storm ends the winter")
	game._hero_says("weather:hail")
	check(game.event_log.entries()[-1].contains("weather:"), "options listed")
	game._hero_says("weather:spring")
	check(not Weather.is_winter(game.season_day()) and game.snow_cover == 0.0, "spring")

	# The season command.
	check(SkyCommand.parse_season("hello") == null and SkyCommand.parse_season("weather:winter") == null, "only season: lines")
	check(SkyCommand.parse_season("season:Autumn").season == Weather.AUTUMN and SkyCommand.parse_season("jahreszeit:frühling").season == Weather.SPRING, "season words, English and German")
	check(SkyCommand.parse_season("season:monsoon").error == "monsoon" and SkyCommand.parse_season("season:").has("error"), "unknown season")
	for season: String in Weather.SEASONS:
		for from in [0, 9, 17, 25]:
			var to := SkyCommand.season_start(from, season)
			check(Weather.season(to) == season and to >= from and to < from + Weather.YEAR_DAYS, "season:%s from day %d goes to day %d" % [season, from, to])
	check(SkyCommand.season_start(3, Weather.AUTUMN) == Weather.AUTUMN_FROM + IvySeasons.TURN_DAYS - 1, "season:autumn shows the turned leaves")
	check(SkyCommand.season_start(Weather.SPRING_DAYS + 3, Weather.SUMMER) == Weather.SPRING_DAYS + 3, "already in the season, the day stays")
	for word: String in ["season:winter", "season:spring", "season:summer", "season:autumn"]:
		game._hero_says(word)
		var season: String = SkyCommand.parse_season(word).season
		check(Weather.season(game.season_day()) == season, "%s switches the season" % word)
		check(game.event_log.entries()[-1].contains(Lang.t(SkyCommand.SEASON_NAMES[season])), "%s is confirmed: %s" % [word, game.event_log.entries()[-1]])
		if season == Weather.WINTER:
			check(game.weather == Weather.SNOW and game.snow_cover == 1.0, "winter: snow on the ground")
		else:
			check(game.weather == Weather.CLEAR and game.snow_cover == 0.0, "%s: clear and no snow" % season)
	game._hero_says("season:monsoon")
	check(game.event_log.entries()[-1].contains("season:"), "unknown season lists the options")
	check(Lang.EN.has(SkyCommand.SEASON_HELP), "season help has English")

	# The tour.
	check(SkyCommand.parse("weather:showcase").tour == "showcase" and SkyCommand.parse("weather:stop").tour == "stop", "tour words")
	check(SkyCommand.tour_at(0.0).weather == Weather.CLEAR and SkyCommand.tour_at(0.0).hour == 0.0, "tour starts clear at midnight")
	check(SkyCommand.tour_at(30.0).hour == 12.0 and SkyCommand.tour_at(65.0).weather == Weather.RAIN, "tour sweeps a day per weather")
	check(SkyCommand.tour_at(299.0).weather == Weather.SNOW and SkyCommand.tour_at(300.0).weather == Weather.CLEAR, "tour loops")
	game._hero_says("weather:showcase")
	check(game._tour_time == 0.0, "tour starts")
	for i in 20:
		await process_frame
	check(game._tour_time > 0.0, "tour runs")
	game._tick_tour(65.0)
	check(game.weather == Weather.RAIN, "tour moves on to rain")
	game._hero_says("weather:stop")
	check(game._tour_time < 0.0, "stop ends the tour")
	game._hero_says("weather:showcase")
	game._hero_says("weather:fog")
	check(game._tour_time < 0.0 and game.weather == Weather.FOG, "another command ends the tour")

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: sky_command")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
