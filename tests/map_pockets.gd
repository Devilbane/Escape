extends SceneTree
## Looks for closed pockets in the village's ground: the free floor round the cow pen and the
## village square is sampled with the hero's own body (a capsule, 1.1 m wide) every half metre and
## flood-filled. A small patch of free ground that is cut off from the rest (a gap between trees,
## a building and a fence that the hero could be wedged into) fails the test; big fenced areas
## (the pen) are fine. Slow, so it runs every night.
## Run with: godot --headless --fixed-fps 60 -s tests/map_pockets.gd

## A cut-off patch of free ground smaller than this many half-metre cells is a pocket.
const POCKET := 160
var game: Node
var frames := 0
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
	return false
func _run() -> void:
	game.hero_name = "Probe"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	for i in 5:
		await physics_frame
	var lv: Outdoor = game.level
	var p: Player = game.player
	var pen: Rect2i = Corral.PEN
	var centre := lv.cell_to_world(pen.position + pen.size / 2)
	print("pen centre ", centre)
	var space := lv.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 2.4
	var step := 0.5
	var half := 24.0
	var n := int(half * 2.0 / step)
	var free := {}
	for iz in n:
		for ix in n:
			var at := Vector3(centre.x - half + ix * step, 0.0, centre.z - half + iz * step)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 1.3, 0))
			q.collision_mask = p.collision_mask
			q.exclude = [p.get_rid()]
			if space.intersect_shape(q, 1).is_empty():
				free[Vector2i(ix, iz)] = true
	# components
	var seen := {}
	var comps := []
	for s in free:
		if seen.has(s):
			continue
		var todo := [s]
		seen[s] = true
		var cells := []
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			cells.append(c)
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var nx: Vector2i = c + d
				if free.has(nx) and not seen.has(nx):
					seen[nx] = true
					todo.append(nx)
		comps.append(cells)
	comps.sort_custom(func(a, b): return a.size() > b.size())
	var bad := 0
	for i in range(1, comps.size()):
		if comps[i].size() < POCKET:
			bad += 1
			var c: Vector2i = comps[i][0]
			print("FAIL: a pocket of ", comps[i].size(), " cells at ", Vector3(centre.x - half + c.x * step, 0, centre.z - half + c.y * step))
	print("components: ", comps.size(), " largest ", comps[0].size())
	print("PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(bad)
