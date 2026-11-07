extends SceneTree
## Headless test that spoken lines show in a compact multi-row speech bubble
## over the speaker (never one long row), and that the bubble goes when the
## line is over.
## Run with: godot --headless -s tests/speech_bubble.gd

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
	print("PASS: speech bubble" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	var long := "I have lived in this village for forty years and never once seen a dragon fly so low over the market."
	check(SpeechBubble.rows_of("Hello") == 1, "a short line is one row")
	var rows := SpeechBubble.rows_of(long)
	check(rows >= 2 and rows <= SpeechBubble.MAX_ROWS + 1, "a long line wraps into a few rows (%d)" % rows)
	game.load_level(game._outdoor_index(), false)
	var v: Villager = game.level.villagers[0]
	v.hush()
	v.say(long)
	var b: SpeechBubble = v._bubble
	check(b.is_shown(), "the bubble shows while the villager speaks")
	var size := b.body_size()
	check(size.x < 5.0, "the bubble is compact, not a long row (%.1f m)" % size.x)
	check(size.y > size.x * 0.2, "the bubble has several rows (%.1f x %.1f m)" % [size.x, size.y])
	v.hush()
	check(not b.is_shown(), "hushing removes the bubble at once")
