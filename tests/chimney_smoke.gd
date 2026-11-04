extends SceneTree
## Headless test for the evening smoke from the village chimneys (see
## ChimneySmoke): every village house has a plume over its chimney; by day
## none smokes, in the evening the houses someone has come home to do and
## the empty ones do not, and late at night the fires burn down. The plume
## uses no shader the other particles do not already need.
## Run with: godot --headless --fixed-fps 60 -s tests/chimney_smoke.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Chimney smoke test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_rules()
	_by_day()
	_in_the_evening()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: chimney smoke")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _smoking() -> int:
	return game.level.chimneys.filter(func(c): return c.smoke.emitting).size()


func _home_at(door: Vector3) -> Array:
	return game.level.villagers.filter(func(v): return v.at_home and v.house_door() == door)


func _rules() -> void:
	check(not ChimneySmoke.smokes(12.0, 3), "no smoke at noon")
	check(not ChimneySmoke.smokes(18.0, 3), "no smoke before the village comes home")
	check(ChimneySmoke.smokes(21.5, 1), "smoke in the evening with someone at home")
	check(ChimneySmoke.smokes(0.5, 2), "the fire still burns just after midnight")
	check(not ChimneySmoke.smokes(22.0, 0), "an empty house never smokes")
	check(not ChimneySmoke.smokes(3.0, 2), "the fire has burnt down in the small hours")
	var plume := ChimneySmoke.make()
	var flame := Effects.make_flame()
	var a: StandardMaterial3D = plume.mesh.material
	var b: StandardMaterial3D = flame.mesh.material
	check(a.blend_mode == b.blend_mode and a.shading_mode == b.shading_mode and a.billboard_mode == b.billboard_mode
			and a.transparency == b.transparency and a.vertex_color_use_as_albedo == b.vertex_color_use_as_albedo,
			"the smoke needs no shader the flames do not already need")
	check(plume.angular_velocity_min == 0.0 and plume.angular_velocity_max == 0.0,
			"the smoke does not spin (a spinning billboard came out as green and yellow balls on some drivers)")
	check(not plume.emitting, "a new plume starts cold")
	plume.free()
	flame.free()


func _by_day() -> void:
	game.hero_name = HERO
	game.day_hour = 12.0
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	check(not level.chimneys.is_empty(), "the village houses have chimneys")
	check(level.chimneys.size() == level.spots.houses.size(), "every village house has its chimney")
	for c in level.chimneys:
		check(c.smoke.global_position.y > VillageHouse.PLINTH + VillageHouse.GROUND + VillageHouse.UPPER, "the smoke comes out over the roof")
	check(_smoking() == 0, "no chimney smokes by day")


func _in_the_evening() -> void:
	game.day_hour = 22.0
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	var lived_in := 0
	for c in level.chimneys:
		var home := _home_at(c.door).size()
		if home > 0:
			lived_in += 1
		check(c.smoke.emitting == (home > 0), "a house smokes in the evening exactly when someone is at home")
	check(lived_in > 0 and _smoking() == lived_in, "the houses the village came home to smoke")
	# Everyone leaves one house: its fire goes out.
	var house: Dictionary = level.chimneys.filter(func(c): return c.smoke.emitting)[0]
	for v in _home_at(house.door):
		v._hide_inside(false)
	level.set_hour(22.1)
	check(not house.smoke.emitting, "an empty house stops smoking")
	for v in level.villagers:
		if v.house_door() == house.door and v.goes_to_bed():
			v._hide_inside(true)
	level.set_hour(22.2)
	check(house.smoke.emitting, "the fire is lit again when they come back")
	# The night wears on and the fires burn down.
	game.day_hour = 2.0
	level.set_hour(2.0)
	check(_smoking() == 0, "the fires have burnt down by two in the night")
	# Saved games loaded late at night find the chimneys cold.
	game.load_level(game._outdoor_index(), false)
	check(_smoking() == 0, "a game loaded at two in the night finds the chimneys cold")
