extends SceneTree
## Headless test for the time away (Offline): the time conversion, the rules
## of a day plan, what a plan earns, and the game's windows for it.
## Run with: godot --headless -s tests/offline_schedule.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test_time()
	_test_rules()
	_test_results()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


## The game needs a few frames to set itself up before its windows work.
func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test_game()
	if failures == 0:
		print("PASS: time away")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test_time() -> void:
	check(is_equal_approx(Offline.game_hours(600.0), 1.0), "10 real minutes are one hour")
	check(is_equal_approx(Offline.game_hours(4 * 3600.0), 24.0), "4 real hours are one day")
	check(is_equal_approx(Offline.game_hours(32 * 3600.0), 192.0), "32 real hours are 8 days")
	check(is_equal_approx(Offline.game_hours(100 * 3600.0), 192.0), "more than 32 hours is capped")
	check(Offline.game_hours(-50.0) == 0.0, "a clock that went back gives nothing")


func _test_rules() -> void:
	var allowed := {"job": ["wache"], "train": ["staerke"], "study": [], "craft": ["messer"]}
	var plan := Offline.normalized({"job": "wache", "job_hours": 20, "train": "staerke", "train_hours": 10, "rest_hours": 2}, allowed)
	check(plan.job_hours == Offline.JOB_MAX_HOURS, "a job lasts at most 12 hours")
	check(plan.rest_hours == Offline.REST_HOURS, "at least 8 hours of rest")
	check(Offline.planned_hours(plan) <= Offline.DAY_HOURS, "no more than a day")
	check(plan.train_hours == 4, "training loses what does not fit")
	var gone := Offline.normalized({"study": "fechtbuch", "study_hours": 5}, allowed)
	check(gone.study == "" and gone.study_hours == 0, "a book the hero lacks cannot be read")


func _test_results() -> void:
	var plan := Offline.normalized({"job": "wache", "job_hours": 12, "craft": "messer", "craft_hours": 4}, {"job": ["wache"], "craft": ["messer"]})
	var day := Offline.simulate(plan, 24.0)
	check(day.gold == 12 * Offline.JOBS.wache.gold, "a guard's day pays 12 hours")
	check(day.knives == 1, "4 hours of smithing make one knife")
	check(is_equal_approx(day.spent.rest, 8.0), "the day has its rest")
	# A day cut short: the job comes first.
	var short := Offline.simulate(plan, 5.0)
	check(is_equal_approx(short.spent.job, 5.0) and short.spent.rest == 0.0, "a short absence starts with the job")
	# Eight days of eight hours of strength training: slow, as the growth curve wants.
	var train := Offline.normalized({"train": "staerke", "train_hours": 8}, {"train": ["staerke"]})
	var week := Offline.simulate(train, 192.0)
	var value := Training.attribute_value("staerke", week.xp.staerke)
	check(value >= 11 and value <= 12, "8 days of training give one or two points of strength, got %d" % value)
	# The same week on a hero who already has 8 points buys no new point.
	var strong_xp := 5000.0
	var gain_strong := Training.attribute_value("staerke", strong_xp + week.xp.staerke) - Training.attribute_value("staerke", strong_xp)
	check(gain_strong == 0, "training slows down as the hero grows")


func _test_game() -> void:
	game.hero_name = "Testheld"
	game.player.bag.append("fechtbuch")
	var choices: Dictionary = game.away_choices()
	check("fechtbuch" in choices.study, "an owned book can be studied")
	check("staerke" in choices.train, "strength can be trained")
	# The windows build without errors.
	game.menus.open("bett")
	game.menus.open("plan")
	game.menus._change_hours("job", 1)
	game.menus._cycle_choice("train")
	game.menus._change_hours("train", 1)
	check(game.away_plan.job == "wache" and game.away_plan.job_hours == 1, "the plan window changes the plan")
	game.menus.close()
	game.away_plan = {"job": "wache", "job_hours": 10, "study": "fechtbuch", "study_hours": 4, "craft": "flicken", "craft_hours": 2, "rest_hours": 8}
	var coins: int = game.coins
	var knives: int = game.player.knives
	var away := {"plan": game.away_plan, "since": Time.get_unix_time_from_system() - 8 * 3600.0}
	game._return_from_away({"away": away})
	check(game.coins == coins + 2 * 10 * Offline.JOBS.wache.gold, "two days as a guard pay, got %d" % (game.coins - coins))
	check(game.player.knives == knives, "mending makes no knives")
	check(game.player.xp.get("klingen", 0.0) > 0.0, "reading the book of blades trains Klingen")
	check(game.menus.current == "rueckkehr", "the welcome-back window opens")
	check(game.away_report.size() >= 4, "the report tells what happened")
	for line in game.away_report:
		print("  ", line)
	game.menus.close()
