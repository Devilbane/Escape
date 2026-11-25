extends SceneTree
## Headless test for sowing in spring (see Sowing, CropFields.sow_near): spring starts on bare soil, a handful
## sows the nearest bare tile, sprouts grow over the days, unsown tiles are sown anyway after a few days, and a
## farmer sent to sow throws seed until a tile is sown, with the seed bag on his hip.
## Run with: godot --headless --fixed-fps 60 -s tests/sowing.gd

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
	return false


func _test() -> void:
	game.state = game.State.PLAYING
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	var fields: CropFields = level.crop_fields
	check(fields != null, "the valley has fields")
	level.set_season(Weather.SPRING_DAYS)
	level.set_season(0)
	check(fields.sowing_time(), "day 0 of spring is sowing time")
	var wheat: Array = fields.bare_tiles("≡")
	check(not wheat.is_empty(), "spring starts with bare wheat tiles")
	check(is_equal_approx(fields.tile_growth("≡", 0), CropFields.BARE), "a bare tile has nothing growing")
	# One handful: the nearest bare tile is sown, only that one.
	var at: Vector3 = wheat[0]
	check(fields.sow_near("≡", at + Vector3(0.5, 0, 0.5), 3.0), "a handful sows the tile it lands on")
	check(fields.bare_tiles("≡").size() == wheat.size() - 1, "exactly one tile is sown")
	check(not fields.sow_near("≡", at + Vector3(500, 0, 0), 6.0), "nothing is sown out of reach")
	var sown := -1
	for i in (fields._tiles["≡"] as Array).size():
		if fields._tiles["≡"][i].sown == 0:
			sown = i
	check(sown >= 0 and fields.tile_growth("≡", sown) == CropFields.SPROUT_STEPS[0], "the seed is a tiny sprout the day it goes in")
	# The sprouts grow with the days; the unsown tiles stay bare until the farmers' time is up.
	level.set_season(1)
	check(fields.tile_growth("≡", sown) == CropFields.SPROUT_STEPS[1], "the next day it is taller")
	level.set_season(2)
	check(fields.tile_growth("≡", sown) == CropFields.SPROUT_STEPS[2], "and taller again")
	var other := 1 if sown == 0 else 0
	check(fields.tile_growth("≡", other) == CropFields.BARE, "unsown soil is still bare on day 2")
	level.set_season(CropFields.AUTO_SOW_DAY)
	check(fields.tile_growth("≡", sown) == 1.0, "the sprouts have their full spring height after %d days" % CropFields.SPROUT_DAYS)
	check(fields.tile_growth("≡", other) > CropFields.BARE, "what nobody sowed is sown anyway")
	check(fields.bare_tiles("≡").is_empty() and not fields.any_bare(), "no soil is left waiting once the days are up")
	var mm: MultiMesh = fields._fields["≡"].mm
	var first: int = fields._tiles["≡"][other].first
	check(mm.get_instance_transform(first).basis.y.length() > 0.05, "the field shows the shoots")
	# Summer and the next spring: back to the full look, then bare soil again.
	level.set_season(Weather.SPRING_DAYS)
	check(fields.tile_growth("≡", other) == 1.0, "summer plants are full grown")
	level.set_season(Weather.YEAR_DAYS)
	check(not fields.bare_tiles("≡").is_empty(), "the next spring starts bare again")
	# A farmer sent to sow.
	level.hour = 9.0
	var veit: Villager = null
	for v: Villager in level.villagers:
		if v.role == "χ":
			veit = v
	check(veit != null, "Veit is in the valley")
	if veit == null:
		quit(1)
		return
	var sow_spots := ValleyFolk.edge_sow_spots(level, "≡")
	check(not sow_spots.is_empty(), "a sower can stand beside a bare tile")
	var job: Dictionary = {}
	for i in 40:
		job = ValleyFolk.pick(veit)
		if job.has("sow"):
			break
	check(job.has("sow") and job.anim == "Throw", "in spring the farmer picks a sowing job that throws seed")
	if job.has("sow"):
		var before: int = fields.bare_tiles(job.sow).size()
		veit.global_position = job.spot
		veit._job = job
		veit._start("work", 6.0)
		for i in 900:
			await physics_frame
			if fields.bare_tiles(job.sow).size() < before:
				break
		check(fields.bare_tiles(job.sow).size() < before, "the farmer sows a tile (%d bare before)" % before)
		check(veit._seed_bag != null and veit._seed_bag.visible, "he carries the seed bag while sowing")
		check(veit._sow_spray != null, "the handful flies out as a spray of seed")
		veit._start("idle", 1.0)
		check(not veit._seed_bag.visible, "the bag is put away when the work is done")
	# No sowing job once everything is sown.
	level.set_season(Weather.YEAR_DAYS + CropFields.AUTO_SOW_DAY)
	check(ValleyFolk.edge_sow_spots(level, "≡").is_empty(), "no sowing job is left when the soil is sown")
	game.delete_save(game.save_path())
	print("PASS: sowing" if failures == 0 else "FAILED: %d" % failures)
	quit(failures)
