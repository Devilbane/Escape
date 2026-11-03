extends SceneTree
## Headless test: many messages at once never cover each other.
## In one moment the hero gets a find message, a level-up, a stronger
## attribute, a finished task, experience, a blocked blow, a damage number,
## loot from a chest beside them and a comic bubble. Then, frame by frame:
## - no two floating words (over the hero or anywhere) overlap on screen,
## - no comic bubble lies on a floating word,
## - no two message lines at the bottom overlap, and a message that was not
##   read yet stays on screen above the newer one instead of vanishing.
## Run with: godot --headless --fixed-fps 60 -s tests/message_overlap.gd

const FIRST := "Gefunden: ein alter Schlüssel, der noch gelesen werden will."
## Frames to watch after everything was fired (the level-up waits 3 s).
const WATCH := 420

var failures := 0
var game: Node
var frames := 0
var fired_at := -1
var most_words := 0
var bubbles_seen := 0
var most_lines := 0
var first_kept := false
var level_up_told := false
var errors := {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


## Reports a failure once per kind, so a long overlap does not flood the log.
func once(ok: bool, kind: String, what: String) -> void:
	if ok or errors.has(kind):
		return
	errors[kind] = true
	check(false, what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: message overlap")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if fired_at < 0:
		_fire()
		fired_at = frames
		return false
	_check_frame()
	if frames - fired_at >= WATCH:
		check(most_words >= 5, "the hero's words show at once (saw %d)" % most_words)
		check(bubbles_seen > 0, "the comic bubble showed")
		check(most_lines >= 2, "unread messages stay as extra lines (saw %d)" % most_lines)
		check(first_kept, "the first message is not covered by the ones after it")
		check(level_up_told, "the level-up is told on the message line")
		_finish()
		return true
	return false


func _fire() -> void:
	var hero: Player = game.player
	var at := hero.global_position
	game.show_message(FIRST, 4.0)
	game._on_leveled_up(7)
	game._on_player_trained("staerke", 12)
	game.quest_news("Auftrag erledigt: Die Ratten im Keller", Color(1.0, 0.85, 0.3))
	Effects.float_text(game.level, at + Vector3(0, 2.4, 0), "+40 EP", game.XP_COLOR)
	hero._block(at + Vector3(0, 0, 2))
	Effects.head_text(game.level, hero, 2.2, "-3", Color(1, 0.3, 0.3))
	# Loot from a chest right beside the hero.
	Effects.float_text(game.level, at + Vector3(1.3, 1.0, 0.4), "+12 Gold  +Eisenhelm", Color(1.0, 0.85, 0.3), true)
	Comic.pop(at, "hurt")


func _check_frame() -> void:
	var camera: Camera3D = game.get_viewport().get_camera_3d()
	check(camera != null, "there is a camera")
	if camera == null:
		return
	# The floating words, once their pop has settled and while readable.
	var words: Array = []
	var rects: Array[Rect2] = []
	for n in DamageNumber.all():
		if n.modulate.a < 0.1 or n._age < DamageNumber.POP_TIME or camera.is_position_behind(n.global_position):
			continue
		words.append(n)
		rects.append(n.screen_rect(camera))
	most_words = maxi(most_words, words.size())
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			once(not rects[i].grow(-1).intersects(rects[j].grow(-1)), "words",
					"\"%s\" and \"%s\" overlap on screen" % [words[i].text, words[j].text])
	# The comic bubbles keep off the words (their jagged star fills less than
	# its box, so the box is taken a little smaller).
	for p in Comic.current._pops:
		if not is_instance_valid(p.node) or not p.settled or not p.node.visible:
			continue
		bubbles_seen += 1
		var box := Rect2(p.node.position, p.node.size).grow(-10)
		for i in rects.size():
			once(not box.intersects(rects[i]), "bubble",
					"a comic bubble covers \"%s\"" % words[i].text)
	# The message lines at the bottom.
	var lines: Array = game.message_lines().filter(func(l): return l.modulate.a > 0.05)
	most_lines = maxi(most_lines, lines.size())
	for i in lines.size():
		if lines[i].text == FIRST and i < lines.size() - 1:
			first_kept = true
		if lines[i].text.begins_with(Lang.t("Heldenstufe %d! +1 Leben").get_slice("%", 0)):
			level_up_told = true
		for j in range(i + 1, lines.size()):
			once(not lines[i].get_global_rect().grow(-1).intersects(lines[j].get_global_rect().grow(-1)), "lines",
					"message lines \"%s\" and \"%s\" overlap" % [lines[i].text, lines[j].text])
