extends SceneTree
## Headless test for playing together (CoopSession, RemoteHero, CoopWindow):
## the game hosts on this computer, a friend joins and walks up, the host sees
## the friend's hero with a name tag, the window keeps its size whatever it
## shows, and leaving takes everything away again.
## Run with: godot --headless -s tests/coop_play.gd
## With SHOTS=<folder> and a display it also saves a picture of the window
## while hosting with a friend.

var failures := 0
var game: Node
var frames := 0
var step := 0
var friend := NetClient.new()
var port := 24611
var panel_rect := Rect2()
var waited := 0
const HERO := "Coop test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	friend.poll()
	if frames < 5:
		return false
	var coop: CoopSession = game.coop
	match step:
		0:
			check(coop != null and not coop.is_on(), "nobody hosts or joins at the start")
			check(Menus.fixed_size(CoopWindow.KIND) != Vector2.ZERO, "the window has a fixed size")
			game.hero_name = HERO
			game.menus.open(CoopWindow.KIND)
			step = 1
		1:
			panel_rect = game.menus._panel.get_global_rect()
			check(CoopWindow.status(coop)[0] == Lang.t("Nicht verbunden."), "the window says nobody is connected")
			check(coop.host(port), "the game hosts on this computer")
			check(friend.connect_to("127.0.0.1", port, "Freundin") == OK, "a friend connects")
			step = 2
		2:
			if coop.mode == CoopSession.Mode.HOSTING and coop.client.is_welcomed() and friend.is_welcomed() and coop.others.size() == 1:
				check(coop.others.values() == ["Freundin"], "the host knows the friend by name")
				var place := coop.where()
				check(not place.is_empty() and place.level != "", "the host sends its hero's place")
				var near: Vector3 = game.player.global_position + Vector3(2, 0, 0)
				friend.send_command(Commands.make("where", {"level": place.level, "pos": near, "facing": 0.0, "anim": "Walking_A"}))
				step = 3
		3:
			if coop.figures.size() == 1:
				var figure: RemoteHero = coop.figures.values()[0]
				check(figure.get_parent() == game.level, "the friend's hero stands in the host's world")
				check(figure.hero_name == "Freundin", "the friend's hero carries her name")
				check(game.menus._panel.get_global_rect() == panel_rect, "hosting and a full list do not resize the window")
				check(CoopWindow.status(coop)[0].contains(str(port)), "the window says the game is hosted, and on which port")
				var shots := OS.get_environment("SHOTS")
				if shots != "" and DisplayServer.get_name() != "headless":
					DirAccess.make_dir_recursive_absolute(shots)
					root.get_texture().get_image().save_png(shots.path_join("coop_window.png"))
				friend.leave()
				step = 4
		4:
			if coop.figures.is_empty() and coop.others.is_empty():
				check(coop.is_on(), "the host stays on when a friend leaves")
				coop.leave()
				check(not coop.is_on() and coop.server == null, "leaving closes the server")
				check(game.menus._panel.get_global_rect() == panel_rect, "leaving does not resize the window")
				game.menus.close()
				# A second game cannot take a port that is in use.
				var other := CoopSession.new()
				other.game = game
				root.add_child(other)
				var blocker := NetServer.new()
				blocker.start(port + 1)
				check(not other.host(port + 1) and other.problem == "port", "a port in use is refused with a reason")
				blocker.stop()
				other.queue_free()
				return _finish()
	waited += 1
	if waited > 900:
		check(false, "timed out at step %d" % step)
		return _finish()
	return false


func _finish() -> bool:
	game.coop.leave()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: coop play")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true
