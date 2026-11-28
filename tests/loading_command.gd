extends SceneTree
## Headless test for the chat command that shows the loading screen again (see LoadingScreen.show_again).

var failed := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: ", what)

func _init() -> void:
	check(LoadingScreen.is_command("loading") and LoadingScreen.is_command("  Loading "), "the word is the command")
	check(not LoadingScreen.is_command("loading screen") and not LoadingScreen.is_command("hello"), "other lines are no command")
	var host := Control.new()
	root.add_child(host)
	var screen := LoadingScreen.show_again(host)
	check(screen != null and screen.get_parent() == host, "the screen opens")
	check(LoadingScreen.show_again(host) == null, "a second one is not stacked")
	screen.leave()
	check(screen._leaving, "leave starts the fade")
	var before := LoadingScreen.shown_at_start()
	LoadingScreen.choose_shown_at_start(false)
	check(not LoadingScreen.shown_at_start() and LoadingScreen.start(host, null, true) == null, "switched off, no screen at startup")
	LoadingScreen.choose_shown_at_start(true)
	check(LoadingScreen.shown_at_start(), "switched on again")
	LoadingScreen.choose_shown_at_start(before)
	check(LoadingScreen.can_reveal(2.0, true, true, false), "at the title the village is enough")
	check(not LoadingScreen.can_reveal(5.0, false, true, true), "in place but the village is not ready: hidden")
	check(LoadingScreen.can_reveal(5.0, true, true, true), "everything in place: revealed")
	check(LoadingScreen.can_reveal(LoadingScreen.GIVE_UP, false, true, false), "a stuck load gives way")
	print("loading_command: ", "OK" if failed == 0 else "%d failed" % failed)
	quit(1 if failed > 0 else 0)
