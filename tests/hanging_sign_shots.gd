extends SceneTree
## Headless test: the village's hanging shop signs (HangingShield). Every hall, the smithy, the
## barber, the stonemason, the wood yard and the bank show a big shield with their mark,
## hung on two chains, high enough to walk under.
## Run with: godot --headless --fixed-fps 60 -s tests/hanging_sign_shots.gd
## With SHOTS=<folder> and a display it also saves pictures; ONLY=<name,...> limits them.

## name: map letter of the door the picture is taken at.
const PLACES := {
	"tavern": "n", "shop": "m", "post": "o", "office": "k", "guild": "w",
	"smithy": "j", "bank": "b",
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
	for name: String in PLACES:
		var key: String = PLACES[name]
		if not lvl.doors.has(key):
			continue
		var front: Vector3 = lvl.doors[key]
		game.player.global_position = front
		# The game's own view (pitch 54, a little closer than the farthest), and a closer look.
		if _wanted(name):
			var pitch := deg_to_rad(48.0)
			await _shot(name, front + Vector3(0, sin(pitch), cos(pitch)) * 16.0, front + Vector3(0, 0.5, -2.0))
			var out := _out_at(lvl, front)
			var side := Vector3(out.z, 0, -out.x)
			await _shot(name + "_close", front + out * 7.0 + side * 2.5 + Vector3(0, 4.0, 0), front - out * 1.5 + Vector3(0, 2.5, 0))
		# The sign is high enough to walk under, and stands clear of the way to the door.
		var sign := _sign_near(lvl, front)
		check(sign != null, "the %s has a hanging sign" % name)
		if sign != null and _wanted(name):
			# Face to face with the shield, to see its painting.
			var shield := _board_of(sign)
			var tall := PubSign.TALL if sign.has_meta("name_text") else HangingShield.TALL
			var mid := shield.global_position + shield.global_basis.y * -tall * 0.5
			var face := shield.global_basis.z.normalized()
			if face.dot(Vector3(0, 0, 1)) < 0.0 and absf(face.z) > 0.5:
				face = -face
			await _shot(name + "_sign", mid + face * 2.3 + Vector3(0, 0.4, 0), mid)
		if sign != null:
			var low := INF
			var hanging := _board_of(sign).find_children("*", "MeshInstance3D", true, false)
			if sign.has_node("NameBoard"):
				hanging.append(sign.get_node("NameBoard"))
			for mi: MeshInstance3D in hanging:
				low = minf(low, (mi.global_transform * mi.get_aabb()).position.y)
			check(low >= HangingShield.CLEAR - 0.15, "the %s's sign hangs high enough to walk under (%.2f)" % [name, low])
	game.delete_save(game.save_path())
	print("PASS: hanging sign shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The hanging sign nearest `front` (within 14 m), or null.
func _sign_near(lvl: Outdoor, front: Vector3) -> Node3D:
	var best: Node3D = null
	var near := 14.0
	for n: Node in lvl.find_children("*", "Node3D", true, false):
		if n.name in ["HallSign", "ShopSign", "BankSign"]:
			var shield := n.get_node_or_null("Shield") as Node3D
			if shield == null:
				shield = n.get_node_or_null("Board") as Node3D # the tavern's pub sign (see PubSign)
			if shield == null:
				continue
			var d := Vector2(shield.global_position.x - front.x, shield.global_position.z - front.z).length()
			if d < near:
				near = d
				best = n
	return best


## The shield of a hanging sign, or the board of the tavern's pub sign.
func _board_of(sign: Node3D) -> Node3D:
	return (sign.get_node_or_null("Shield") if sign.has_node("Shield") else sign.get_node("Board")) as Node3D


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
