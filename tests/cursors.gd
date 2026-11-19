extends SceneTree
## Headless test for the mouse cursors (Cursors): both pictures exist, are the same
## size and large, the hotspot lies on the arrow's tip (a solid pixel with empty
## ground above and to its left), and the game sets them up when it starts.
## Run with: godot --headless -s tests/cursors.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for tex in [Cursors.ARROW, Cursors.HAND]:
		var img: Image = tex.get_image()
		check(img.get_width() == 64 and img.get_height() == 64, "cursor is 64 x 64")
		var tip := Vector2i(Cursors.HOTSPOT)
		check(img.get_pixelv(tip + Vector2i(2, 4)).a > 0.9, "the arrow's body lies just below its tip")
		check(img.get_pixelv(tip - Vector2i(3, 0)).a < 0.2 and img.get_pixelv(tip - Vector2i(0, 3)).a < 0.2,
			"empty ground left of and above the tip")
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	check(src.contains("Cursors.setup()"), "the game sets the cursors up")
	print("cursors: ", "OK" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
