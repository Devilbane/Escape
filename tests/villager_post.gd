extends SceneTree
## Headless test: a villager's window does not open during an alarm or away from their post
## (VillagerPost), and it closes when the alarm rings.
## Run with: godot --headless -s tests/villager_post.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path())
	print("PASS: villager post" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	check(VillagerPost.refusal(false, false, "shop", 1.0) == "", "at their post in peace the window opens")
	check(VillagerPost.refusal(true, false, "shop", 0.0) == VillagerPost.ALARM_LINE, "an alarm shuts the window")
	check(VillagerPost.refusal(false, true, "work", 0.0) == VillagerPost.ALARM_LINE, "a fleeing villager does not deal")
	check(VillagerPost.refusal(false, false, "shop", VillagerPost.POST_RADIUS + 1.0) == VillagerPost.AWAY_LINE, "away from the post: find me there")
	check(VillagerPost.refusal(false, false, "wander", 99.0) == "", "a wanderer has no post to be away from")
	check(Lang.EN.has(VillagerPost.ALARM_LINE) and Lang.EN.has(VillagerPost.AWAY_LINE), "both lines are translated")
	# Open window closes when the alarm rings.
	game.trader_role = "S"
	game.menus.open("haendler")
	check(game.menus.is_open(), "the window is open")
	Events.alarm("slime")
	check(not game.menus.is_open(), "the alarm closes the window")
	check(game.trader_role == "", "the trader is let go")
