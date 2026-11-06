extends SceneTree
## Headless test: comic bubbles sit close to the fight without covering it.
## - closest_spot puts a box flush beside a blocked box (one gap away), not a
##   ring step further, prefers above or beside over below, keeps to the
##   screen, and takes the least crowded spot when nothing is free.
## - In the game, a blow between the hero and a monster standing side by side
##   pops two bubbles that cover neither fighter, nor each other, nor the
##   life bar under the hero, and stay within reach of the fight.
## Run with: godot --headless --fixed-fps 60 -s tests/comic_placement.gd

## How far (in screen pixels) a bubble's centre may be from the fighter it
## belongs to: about one bubble and one fighter across.
const NEAR := 230.0

var failures := 0
var game: Node
var frames := 0
var foe: Enemy
var fired_at := -1


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
	_spots()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: comic placement")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _spots() -> void:
	var screen := Rect2(0, 0, 1280, 720)
	var center := Vector2(640, 360)
	var extent := Vector2(100, 80)
	# Nothing in the way: right on the point.
	check(Comic.closest_spot(center, extent, [], screen) == Vector2.ZERO, "a free point takes the bubble itself")
	# A fighter on the point: the bubble sits flush against its nearest side.
	var body := Rect2(600, 300, 80, 120)
	var off := Comic.closest_spot(center, extent, [body], screen)
	var box := Rect2(center + off - extent * 0.5, extent)
	check(not box.intersects(body), "the bubble keeps off the fighter")
	check(_flush(box, body), "the bubble sits right against the fighter (got %s)" % box)
	# A wide fighter: above it is nearer than beside it.
	var wide := Rect2(520, 320, 240, 100)
	off = Comic.closest_spot(center, extent, [wide], screen)
	check(off.y < 0.0 and off.x == 0.0, "the bubble goes above, not below (got %s)" % off)
	# Room above taken: beside, not below.
	var above := Rect2(560, 150, 160, 150)
	off = Comic.closest_spot(center, extent, [body, above], screen)
	box = Rect2(center + off - extent * 0.5, extent)
	check(not box.intersects(body) and not box.intersects(above), "the bubble keeps off both boxes")
	check(_flush(box, body), "the bubble moves flush beside the fighter (got %s)" % box)
	# Pressed against the screen's edge: it stays on screen.
	off = Comic.closest_spot(Vector2(20, 360), extent, [Rect2(0, 300, 80, 120)], screen)
	check(screen.encloses(Rect2(Vector2(20, 360) + off - extent * 0.5, extent)), "the bubble stays on screen")
	# Everything taken: the least crowded spot, not some far corner.
	off = Comic.closest_spot(center, extent, [screen], screen)
	check(off.length() <= Comic.REACH, "a full screen still keeps the bubble near")


## Whether `box` touches `body` along one side, a pixel off at most.
func _flush(box: Rect2, body: Rect2) -> bool:
	return absf(box.position.x - body.end.x) <= 1.0 or absf(box.end.x - body.position.x) <= 1.0 \
			or absf(box.position.y - body.end.y) <= 1.0 or absf(box.end.y - body.position.y) <= 1.0


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		if game.state == game.State.TITLE:
			game._start_playing()
		var lvl: Level = game.level
		foe = Enemy.new()
		foe.kind = "krieger"
		foe.level = lvl
		lvl.add_child(foe)
		lvl.enemies.append(foe)
		foe.global_position = game.player.global_position + Vector3(1.8, 0, 0.3)
		foe._cooldown = 99.0
		foe.set_physics_process(false)
	if frames == 12:
		foe.take_hit(1, game.player.global_position, "hit", false)
		Comic.pop(game.player.global_position, "hurt")
		fired_at = frames
	if fired_at > 0 and frames == fired_at + 3:
		_check()
		_finish()
		return true
	return false


func _check() -> void:
	var comic: Comic = Comic.current
	var cam: Camera3D = game.get_viewport().get_camera_3d()
	var pops: Array = comic._pops.filter(func(p): return is_instance_valid(p.node) and p.settled)
	check(pops.size() == 2, "both bubbles settled (saw %d)" % pops.size())
	var bodies: Array[Rect2] = [comic._body_rect(game.player), comic._body_rect(foe)]
	var boxes: Array[Rect2] = []
	for p in pops:
		var center: Vector2 = cam.unproject_position(p.pos) + p.offset
		var extent: Vector2 = p.node.size * Comic.FOOTPRINT
		var box := Rect2(center - extent * 0.5, extent)
		boxes.append(box)
		for b in bodies:
			check(not box.intersects(b), "a bubble covers a fighter (%s on %s)" % [box, b])
		check(center.distance_to(cam.unproject_position(p.pos)) <= NEAR,
				"a bubble sits near its fight (%.0f px away)" % center.distance_to(cam.unproject_position(p.pos)))
		for r: Rect2 in game.hero_hud_rects():
			check(not box.intersects(r), "a bubble covers the hero's life bar or prompt")
	if boxes.size() == 2:
		check(not boxes[0].intersects(boxes[1]), "the two bubbles keep apart")
