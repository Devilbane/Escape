extends SceneTree
## Headless test for the sunflower riddle (see SunflowerRiddle): the field in the valley map is ten tiles, the
## planted flowers spell the words when decoded from where the light-centred flowers stand (not from the marks the
## code hands out), the scarecrow stands in the middle and leaves every marked flower alone, and the words said by
## the scarecrow set off the fireworks and the message, but nowhere else.
## Run with: godot --headless --fixed-fps 60 -s tests/sunflower_riddle.gd

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
	if frames == 5:
		_test()
		game.delete_save(game.save_path())
		print("PASS: sunflower riddle" if failures == 0 else "FAILED: %d" % failures)
		quit(1 if failures > 0 else 0)
	return false


func _test() -> void:
	game.state = game.State.PLAYING
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	check(level.sunflower_riddle != null, "the riddle is set up in the valley")
	# The marks are numbers 1 to 25 and one per patch.
	var marks := SunflowerRiddle.marks()
	check(marks.size() == SunflowerRiddle.block_count(), "one mark per patch (%d)" % marks.size())
	for m in marks:
		check(m >= 0 and m <= SunflowerRiddle.PATCH * SunflowerRiddle.PATCH, "a mark is a flower of the patch: %d" % m)
	# The field on the map is the whole old field, all sunflowers.
	for c in SunflowerRiddle.cells():
		check(level.cell_char(c) == CropFields.SUNFLOWER, "tile %s of the field is sunflowers" % str(c))
	var fields: CropFields = level.crop_fields
	var plain: Dictionary = fields._fields[CropFields.RIDDLE]
	var marked: Dictionary = fields._fields[CropFields.MARKED]
	var centre := SunflowerRiddle.centre()
	var total: int = plain.spots.size() + marked.spots.size()
	check(total >= SunflowerRiddle.FIELD.size.x * SunflowerRiddle.FIELD.size.y * 16 - 4, "the field is full of flowers (%d)" % total)
	for s: Array in plain.spots:
		check(Vector2(s[0].x - centre.x, s[0].z - centre.z).length() >= SunflowerRiddle.CLEAR_RADIUS, "no flower stands at the post")
	# Decode from where the light flowers stand: the number of the light flower in each patch, in reading order.
	var found: Array[int] = []
	for i in SunflowerRiddle.block_count():
		found.append(0)
	var corner := SunflowerRiddle.corner()
	for s: Array in marked.spots:
		var f := SunflowerRiddle.patch_flower(int(floor(s[0].x - corner.x)), int(floor(s[0].z - corner.y)))
		check(not f.is_empty(), "a light flower lies in a patch")
		if not f.is_empty():
			check(found[f.patch] == 0, "at most one light flower in a patch")
			found[f.patch] = f.number
	check(found == marks, "the light flowers stand where the code says")
	# The patches touch each other: the lattice has no gaps (every flower of the field but the ones at the post).
	check(total == SunflowerRiddle.FIELD.size.x * SunflowerRiddle.FIELD.size.y * 16 - 1, "no gaps: only the flower at the post is missing (%d)" % total)
	# The scarecrow stands in the middle of the field.
	var ev: ValleyEvents = level.valley_events
	check(ev._scare != null and ev._scare.position.is_equal_approx(centre), "the scarecrow stands in the field's middle")
	# Saying it: the test brings words of its own. Case, spaces and marks do not matter, but it must be said by the scarecrow.
	var text := "open sesame"
	var _entry := RiddleVault.make_entry("opensesame", "testsalt", 50)
	SunflowerRiddle.test_entry = _entry
	check(SunflowerRiddle.is_answer(text.to_upper()) and SunflowerRiddle.is_answer("opensesame") and SunflowerRiddle.is_answer("  " + text + "!"), "case, spaces and marks do not matter")
	check(not SunflowerRiddle.is_answer("") and not SunflowerRiddle.is_answer("open") and not SunflowerRiddle.is_answer("hallo"), "other words are no answer")
	SunflowerRiddle.test_entry = {}
	check(not SunflowerRiddle.is_answer(text), "the test's words are no answer in the game")
	SunflowerRiddle.test_entry = _entry
	game._message.text = ""
	Events.hero_says(text, centre + Vector3(30, 0, 0))
	check(game._message.text != SunflowerRiddle.CONGRATS, "far from the scarecrow nothing happens")
	Events.hero_says(text, centre + Vector3(-3, 0, 4))
	check(game._message.text == SunflowerRiddle.CONGRATS, "by the scarecrow the words are rewarded: %s" % game._message.text)
	SunflowerRiddle.test_entry = {}
	check(level.sunflower_riddle._busy > 0.0, "the fireworks are on")
	# The code only shows with heads: summer and autumn.
	var seasons := {"spring": 3, "summer": Weather.SPRING_DAYS + 2, "autumn": Weather.AUTUMN_FROM + 1, "winter": Weather.YEAR_DAYS - 1}
	for season: String in seasons:
		fields.set_season(seasons[season])
		var heads: bool = (marked.mm as MultiMesh).mesh.get_surface_count() == 4
		check(heads == (season == "summer" or season == "autumn"), "%s: the heads %s" % [season, "show" if heads else "are hidden"])
