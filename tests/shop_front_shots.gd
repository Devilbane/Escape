extends SceneTree
## Headless test: what the shops and offices set out by their doors (ShopFronts). Every hall has its
## display, nothing of it stands in the way to the door or further out than ShopFronts.DEEP, and the
## bank has its strongbox and the smith his wares by his forge. Run with: godot --headless --fixed-fps 60 -s tests/shop_front_shots.gd
## With SHOTS=<folder> and a display it also saves pictures; ONLY=<name,...> limits them.

## name: map letter of the door the picture is taken at.
const PLACES := {
	"tavern": "n", "shop": "m", "post": "o", "office": "k", "guild": "w", "smithy": "j", "bank": "b",
}

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
var only := OS.get_environment("ONLY").split(",", false)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _wanted(name: String) -> bool:
	return shots != "" and (only.is_empty() or only.has(name))


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Mason"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(20)
	var lvl: Outdoor = game.level
	lvl.set_hour(10.5)
	var dressed := 0
	for n: Node in lvl.get_children():
		if not n.has_meta("hall"):
			continue
		var front := n.get_node_or_null("ShopFront") as Node3D
		check(front != null, "the %s sets out its wares" % n.get_meta("hall"))
		if front == null:
			continue
		dressed += 1
		for part: Array in front.get_meta("solids"):
			var mid: Vector3 = part[0]
			var size: Vector3 = part[1]
			check(absf(mid.x) - size.x * 0.5 >= ShopFronts.DOOR_FREE - 0.01, "the %s keeps its door free (%s)" % [n.get_meta("hall"), mid])
			check(mid.z + size.z * 0.5 <= ShopFronts.DEEP + 0.05, "the %s keeps the street free (%s)" % [n.get_meta("hall"), mid])
		for mi: MeshInstance3D in front.find_children("*", "MeshInstance3D", true, false):
			var box := front.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			if box.position.y < 2.0:
				check(box.position.x >= ShopFronts.DOOR_FREE - 0.05 or box.end.x <= -ShopFronts.DOOR_FREE + 0.05, "nothing of the %s's display stands before the door (%s)" % [n.get_meta("hall"), mi.get_parent().name])
	check(dressed >= 5, "the halls set out their wares (%d)" % dressed)
	check(lvl.find_child("BankStrongbox", true, false) != null, "the bank has its strongbox by the door")
	check(lvl.find_child("SmithWares", true, false) != null, "the smith sets out his wares by his forge")
	for name: String in PLACES:
		var key: String = PLACES[name]
		if not lvl.doors.has(key) or not _wanted(name):
			continue
		var front: Vector3 = lvl.doors[key]
		game.player.global_position = front
		var pitch := deg_to_rad(48.0)
		await _shot(name, front + Vector3(0, sin(pitch), cos(pitch)) * 16.0, front + Vector3(0, 0.5, -2.0))
		var out := _out_at(lvl, front)
		var side := Vector3(out.z, 0, -out.x)
		await _shot(name + "_close", front + out * 6.5 + side * 1.5 + Vector3(0, 3.5, 0), front - out * 2.0 + Vector3(0, 1.0, 0))
	game.delete_save(game.save_path())
	print("PASS: shop front shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The way out of the door nearest `front`.
func _out_at(lvl: Outdoor, front: Vector3) -> Vector3:
	var best := Vector3.BACK
	var near := INF
	for e: Dictionary in lvl._entrances:
		var d: float = (e.door as Vector3).distance_to(front)
		if d < near:
			near = d
			best = e.out
	return best


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
