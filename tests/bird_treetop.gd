extends SceneTree
## Headless test: a woods bird whose tree the hero stands under, with no other tree
## farther from the hero, must not burst up and land in the same treetop again and
## again (the bird "flying up and down" on the spot). It stays calm for a while.
## Run with: godot --headless -s tests/bird_treetop.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var level := Node3D.new()
	root.add_child(level)
	# Two treetops; the hero stands right between them, nearer to neither than the other.
	var tops: Array[Vector3] = [Vector3(0, 8, 0), Vector3(2, 8, 0)]
	var birds := VillageBirds.new(level, tops, [] as Array[Vector3], [] as Array[Vector3], 7, true)
	level.add_child(birds)
	var hero := Vector3(1, 0, 0)
	birds._hero_at = hero
	var b: Dictionary = birds.birds[0]
	b.state = "sit"
	var flights := 0
	for k in 40:
		birds._clock += 0.5
		birds._shy_away_wild(hero)
		if b.state == "fly":
			flights += 1
			# Let it land at once, as the loop would after a short hop.
			b.state = "sit"
			b.at = b.to
	check(flights <= 3, "a bird with nowhere to flee does not keep taking off (%d flights in 20 s)" % flights)
	print("bird_treetop: ", "OK" if failures == 0 else "FAILED")
	quit(1 if failures > 0 else 0)
