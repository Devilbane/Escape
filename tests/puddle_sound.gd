extends SceneTree
## Headless test: a step into a nearly dried-out puddle gives a soft squelch
## (splash_soft_*), quieter the drier it is, never the sharp burst of splashes
## that sounded like a little firecracker. A full puddle splashes as before.
## Run with: godot --headless -s tests/puddle_sound.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for i in 20:
		check(Puddles.splash_sound(Puddles.SPLASH_FILL).begins_with("splash_soft_"), "a nearly dry puddle squelches softly")
		check(Puddles.splash_sound(Puddles.SOFT_FILL - 0.01).begins_with("splash_soft_"), "a shallow puddle squelches softly")
		var deep := Puddles.splash_sound(1.0)
		check(deep.begins_with("splash_") and not deep.begins_with("splash_soft_"), "a full puddle splashes")
	check(is_equal_approx(Puddles.splash_volume(1.0), 0.0), "a full puddle keeps its volume")
	check(is_equal_approx(Puddles.splash_volume(Puddles.SOFT_FILL), 0.0), "no jump in volume where the sounds switch")
	check(Puddles.splash_volume(Puddles.SPLASH_FILL) < Puddles.splash_volume(Puddles.SOFT_FILL - 0.05), "the drier, the quieter")
	check(Puddles.splash_volume(0.0) < 0.0, "a dry puddle is quiet")
	for n in ["splash_soft_0", "splash_soft_1", "splash_soft_2", "splash_0", "splash_3"]:
		check(ResourceLoader.exists("res://assets/sounds/%s.wav" % n), "%s exists" % n)
	print("PASS: puddle sound" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
