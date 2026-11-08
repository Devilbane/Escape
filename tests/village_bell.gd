extends SceneTree
## Headless test for the village's warning bell (tools/make_bell_sounds.py,
## VillageBell): the sound is part of the game and long enough to toll, every
## hostile reason rings it, an unknown reason does not, it rings at most once per
## cooldown, and Events.alarm reaches the game's bell.
## Run with: godot --headless -s tests/village_bell.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var stream := load(Sfx.DIR + VillageBell.SOUND + ".wav") as AudioStreamWAV
	check(stream != null, "the bell sound is part of the game")
	if stream:
		check(stream.get_length() > 3.0 and stream.get_length() < 10.0, "the bell tolls for a few seconds")
	VillageBell.reset()
	check(not VillageBell.may_ring(100.0, "bogus"), "an unknown reason does not ring the bell")
	check(VillageBell.may_ring(100.0, "slime"), "a slime in the village rings the bell")
	check(not VillageBell.may_ring(100.0 + VillageBell.COOLDOWN - 1.0, "breach"), "the bell does not spam")
	check(VillageBell.may_ring(100.0 + VillageBell.COOLDOWN + 1.0, "breach"), "it rings again after the cooldown")
	for reason in VillageBell.REASONS:
		VillageBell.reset()
		check(VillageBell.may_ring(0.0, reason), "%s rings the bell" % reason)
	# Only the open ground hears it.
	VillageBell.reset()
	check(not VillageBell.ring(_Dummy.new(), "slime", 500.0), "the bell is not heard outside the village")
	check(Events.bus().has_signal("village_alarmed"), "the bus carries village alarms")
	VillageBell.reset()
	if failures == 0:
		print("PASS: village bell")
	quit(1 if failures > 0 else 0)


class _Dummy extends Node:
	var level: Node = null
