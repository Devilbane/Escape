extends SceneTree
## Headless test: in autumn most undergrowth bushes at the forest edge, and half the village's shrubs
## (more near the temple), have shed their leaves, and
## fallen leaves lie spread over the ground instead (Outdoor.UNDERGROWTH_AUTUMN_KEEP, SurfaceLife.set_autumn):
## - outside autumn every bush grows and no fallen leaves are laid (nothing to pay for);
## - in autumn only about UNDERGROWTH_AUTUMN_KEEP of the bushes keep their leaves, and thousands of
##   fallen leaves lie about, all in the ivy's autumn colours (IvySeasons.AUTUMN_COLOURS);
## - no shrub and no fallen leaves lie over the temple glass's light on the grass, in any season;
## - they lie on the open ground and the forest's edge, never on the middle of a path, and are drawn
##   in batches with a draw range;
## - when autumn ends the bushes grow again and the fallen leaves are hidden.
## Run with: godot --headless -s tests/autumn_leaves.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	game.hero_name = "Autumn leaves"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	var life := lvl.surface_life
	var spring := Seasons.TEST_DAY
	var autumn := SkyCommand.autumn_from(spring)
	check(not Weather.is_autumn(spring) and Weather.is_autumn(autumn), "the test days are a spring and an autumn day")
	lvl.set_season(spring)
	check(lvl.undergrowth != null and lvl.undergrowth_shed != null, "the undergrowth is split into bushes that keep and that shed their leaves")
	var kept := 0
	for b: Vector4 in lvl.undergrowth_bushes:
		if Outdoor._keeps_leaves(Vector3(b.x, b.y, b.z), Outdoor.UNDERGROWTH_AUTUMN_KEEP):
			kept += 1
	var share := float(kept) / float(maxi(1, lvl.undergrowth_bushes.size()))
	check(absf(share - Outdoor.UNDERGROWTH_AUTUMN_KEEP) < 0.07, "about %.0f%% of the undergrowth keeps its leaves in autumn (%.0f%%)" % [Outdoor.UNDERGROWTH_AUTUMN_KEEP * 100.0, share * 100.0])
	check(_leaves(lvl.undergrowth_shed) > _leaves(lvl.undergrowth), "more bushes shed their leaves in autumn than keep them")
	check(lvl.undergrowth_shed.visible, "outside autumn every undergrowth bush grows")
	check(life.fallen == null, "outside autumn no fallen leaves are laid")
	var t0 := Time.get_ticks_msec()
	lvl.set_season(autumn)
	var took := Time.get_ticks_msec() - t0
	print("fallen leaves: %d, laid in %d ms (litter %d)" % [life.fallen_total, took, life.litter_total])
	check(not lvl.undergrowth_shed.visible and lvl.undergrowth.visible, "in autumn most undergrowth has shed its leaves")
	check(life.fallen != null and life.fallen.visible, "in autumn fallen leaves lie on the ground")
	check(life.fallen_total > 150000 and life.fallen_total <= SurfaceLife.FALLEN_CAP, "thousands of fallen leaves, within the cap (%d)" % life.fallen_total)
	var batches := 0
	for mmi: MultiMeshInstance3D in life.fallen.get_children():
		batches += 1
		check(mmi.visibility_range_end > 0.0 and mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "fallen leaves cast no shadow and are not drawn from far away")
	check(batches > 10, "fallen leaves are drawn in batches (%d)" % batches)
	var off_colour := 0
	var rng := RandomNumberGenerator.new()
	for i in 500:
		if not _autumn_colour(SurfaceLife.fallen_colour(rng)):
			off_colour += 1
	check(off_colour == 0, "every fallen leaf has an autumn colour of the ivy (%d do not)" % off_colour)
	check(life.fallen_on_bare_ground() == 0, "no fallen leaves hide the temple glass's light on the grass (%d)" % life.fallen_on_bare_ground())
	var on_light := lvl.shrubs.filter(func(at: Vector3): return lvl.on_bare_ground(at, 1.5)).size()
	check(not lvl.bare_ground.is_empty() and on_light == 0, "no shrub stands on the temple glass's light on the grass (%d)" % on_light)
	check(life.litter_on_path_middles() == 0, "no fallen leaf lies on the middle of a path")
	var count := life.fallen_total
	lvl.set_season(autumn + 1)
	check(life.fallen_total == count, "the fallen leaves are laid only once")
	lvl.set_season(spring)
	check(lvl.undergrowth_shed.visible and not life.fallen.visible, "after autumn the bushes grow again and the fallen leaves are gone")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: autumn leaves")
	quit(1 if failures > 0 else 0)


func _leaves(node: Node3D) -> int:
	var n := 0
	for child in node.get_children():
		if child is MultiMeshInstance3D:
			n += (child as MultiMeshInstance3D).multimesh.instance_count
	return n


## Whether a colour is one of IvySeasons.AUTUMN_COLOURS, shaded darker or lighter.
func _autumn_colour(c: Color) -> bool:
	for a: Color in IvySeasons.AUTUMN_COLOURS:
		var k := c.r / a.r
		if k > 0.7 and k < 1.1 and absf(c.g - a.g * k) < 0.01 and absf(c.b - a.b * k) < 0.01:
			return true
	return false
