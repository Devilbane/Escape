extends SceneTree
## Slimes crawl about the open air only in spring, and only in rain, storm or fog (see
## SlimeGrowth.may_crawl): no slime spots in other seasons or in clear skies, and the slimes out
## there retreat to the pond when the weather clears or the season turns. Sewer slimes are not affected.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_spring_weather.gd

var game: Node
var frames := 0
var started := false
var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _slime_spots(lvl: Outdoor) -> int:
	return lvl._weather_foes.filter(func(s): return SlimeGrowth.grows(s.kind)).size()


func _run() -> void:
	game.hero_name = "Spring slimes test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	for i in 3:
		await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	var spring := 0
	var summer := Weather.SPRING_DAYS
	check(Weather.is_spring(spring) and not Weather.is_spring(summer), "day setup: spring and summer")
	for w in [Weather.RAIN, Weather.FOG, Weather.STORM]:
		check(SlimeGrowth.may_crawl(w, spring), "slimes may crawl in spring %s" % w)
		check(not SlimeGrowth.may_crawl(w, summer), "no slimes in summer %s" % w)
	check(not SlimeGrowth.may_crawl(Weather.CLEAR, spring), "no slimes in clear spring skies")
	check(not SlimeGrowth.may_crawl(Weather.SNOW, spring), "no slimes in snow")
	# Spots: only in spring.
	lvl.season_day = summer
	lvl.weather = ""
	lvl.set_weather(Weather.RAIN)
	check(_slime_spots(lvl) == 0, "summer rain has no slime spots")
	lvl.weather = ""
	lvl.season_day = spring
	lvl.set_weather(Weather.RAIN)
	check(_slime_spots(lvl) > 0, "spring rain has slime spots")
	# A slime out there retreats when the weather clears.
	var s := lvl.spawn_slime("schleim", lvl.player.global_position + Vector3(0, 0, 60), {"kept_level": 5})
	for i in 3:
		await physics_frame
	SlimeLife.tick(s, 0.1)
	check(not s.retreating, "in spring rain a slime stays")
	lvl.weather = Weather.CLEAR
	SlimeLife.tick(s, 0.1)
	check(s.retreating, "when the weather clears it retreats")
	var t := lvl.spawn_slime("schleim", lvl.player.global_position + Vector3(0, 0, 60), {"kept_level": 5})
	for i in 3:
		await physics_frame
	lvl.weather = Weather.RAIN
	lvl.season_day = summer
	SlimeLife.tick(t, 0.1)
	check(t.retreating, "when the season turns it retreats")
	if failures == 0:
		print("PASS: slime spring weather")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
