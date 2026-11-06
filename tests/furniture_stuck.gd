extends SceneTree
## Headless test for furniture the hero could get stuck on:
## - every piece blocks only where it is drawn (its collision box lies within
##   its meshes, and a table or trunk turned on its side is blocked the long
##   way round, not by a fixed square),
## - a hero standing on the free edge of a tile with furniture can still walk
##   off it by a click (the path finding sets out from that tile),
## - a skeleton pressing against the hero, or a blow, never shoves the hero
##   onto a tile with furniture.
## Run with: godot --headless --fixed-fps 60 -s tests/furniture_stuck.gd

## Pieces whose collision is fitted to their meshes (see Level._add_fitted_solid).
const FITTED := "bkxtCLBoy"
## Pieces that are long and narrow: whichever way they are turned, they are
## blocked the long way round, never by a square.
const LONG := "kt"
## How far a collision box may differ from the drawn piece (metres).
const SLACK := 0.12

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


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await _check_maps()
	await _check_walk_off()
	await _check_no_shove()
	await _check_boulders()
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The drawn bounds of the pieces on each tile, found from the meshes.
func _drawn(lv: Level) -> Dictionary:
	var drawn := {}
	for mi: MeshInstance3D in lv.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.size.x > Level.TILE * 0.95 or box.size.z > Level.TILE * 0.95 or box.end.y < 0.1:
			continue
		var c := lv.world_to_cell(box.get_center())
		drawn[c] = drawn[c].merge(box) if drawn.has(c) else box
	return drawn


## The collision boxes and cylinders of the pieces, by tile, as flat AABBs.
func _solids(lv: Level) -> Dictionary:
	var solids := {}
	for cs in lv._walls_body.get_children():
		if not cs is CollisionShape3D:
			continue
		var size := Vector3.ZERO
		if cs.shape is BoxShape3D:
			size = cs.shape.size
		elif cs.shape is CylinderShape3D:
			size = Vector3(cs.shape.radius * 2.0, cs.shape.height, cs.shape.radius * 2.0)
		if size.x <= 0.0 or size.x >= Level.TILE:
			continue
		solids[lv.world_to_cell(cs.global_position)] = AABB(cs.global_position - size * 0.5, size)
	return solids


func _check_maps() -> void:
	var dir := DirAccess.open("res://levels")
	var seen := {}
	for file in dir.get_files():
		var path: String = "res://levels/" + file
		if not file.ends_with(".txt") or Level.is_outdoor_file(path):
			continue
		var lv := Level.new()
		lv.load_from_file(path)
		root.add_child(lv)
		lv.build()
		var drawn := _drawn(lv)
		var solids := _solids(lv)
		for c in solids:
			var ch := lv.cell_char(c)
			if not FITTED.contains(ch) or not drawn.has(c):
				continue
			seen[ch] = true
			var s: AABB = solids[c]
			var m: AABB = drawn[c]
			var where := "%s: '%s' at %s" % [file, ch, c]
			check(s.position.x >= m.position.x - SLACK and s.end.x <= m.end.x + SLACK
					and s.position.z >= m.position.z - SLACK and s.end.z <= m.end.z + SLACK,
					"%s blocks more than is drawn (blocked %s, drawn %s)" % [where, s, m])
			if LONG.contains(ch):
				check(maxf(s.size.x, s.size.z) > minf(s.size.x, s.size.z) * 1.5,
						"%s is blocked by a square, not along its length (%s)" % [where, s])
		lv.queue_free()
		await process_frame
	for ch in FITTED.substr(0, 5):
		check(seen.has(ch), "the maps still have the piece '%s'" % ch)


## A table tile in the first cell and the side of it the hero can stand on.
func _table_spot(lv: Level) -> Dictionary:
	var solids := _solids(lv)
	for c in solids:
		if lv.cell_char(c) != "t":
			continue
		for d in Level.DIRS:
			if lv.astar.is_point_solid(c + d):
				continue
			var s: AABB = solids[c]
			var mid := lv.cell_to_world(c)
			var half := absf(Vector3(d.x, 0, d.y).dot(s.size)) * 0.5
			var gap := Level.TILE * 0.5 - half
			if gap < game.player.radius + 0.3:
				continue
			return {"cell": c, "dir": Vector3(d.x, 0, d.y), "free": c + d, "edge": half, "mid": mid}
	return {}


## The hero stands beside the table, on its own tile: a click still walks
## them away.
func _check_walk_off() -> void:
	game.load_level(0, false)
	await _wait(3)
	var lv: Level = game.level
	var p: Player = game.player
	var spot := _table_spot(lv)
	check(not spot.is_empty(), "the cell has a table with room beside it")
	if spot.is_empty():
		return
	for e in lv.enemies:
		e.set_physics_process(false)
	p.global_position = spot.mid + spot.dir * (spot.edge + p.radius + 0.1)
	p.velocity = Vector3.ZERO
	await _wait(2)
	check(lv.world_to_cell(p.global_position) == spot.cell, "the hero stands on the table's tile")
	var target: Vector2i = spot.free
	p.walk_to(lv.cell_to_world(target))
	check(not p.path.is_empty(), "a click finds a way off the table's tile")
	await _wait(120)
	check(lv.world_to_cell(p.global_position) == target, "the hero walked off the table's tile (now at %s)"
			% lv.world_to_cell(p.global_position))


## A skeleton pressed into the hero, and a blow from the other side, both
## pushing the hero towards the table: the hero stays on the free tile.
func _check_no_shove() -> void:
	var lv: Level = game.level
	var p: Player = game.player
	var spot := _table_spot(lv)
	var enemy: Enemy = null
	for e in lv.enemies:
		if is_instance_valid(e) and not e.dead:
			enemy = e
	check(enemy != null and not spot.is_empty(), "the cell has a skeleton to push with")
	if enemy == null or spot.is_empty():
		return
	var free_mid := lv.cell_to_world(spot.free)
	var toward: Vector3 = -spot.dir
	# The hero right at the border of the table's tile, the skeleton inside
	# them on the far side.
	var at := free_mid + toward * (Level.TILE * 0.5 - 0.05)
	p.global_position = at
	p.velocity = Vector3.ZERO
	enemy.set_physics_process(false)
	enemy.global_position = at - toward * 0.3
	for i in 60:
		lv._push_apart(1.0 / 60.0)
		await physics_frame
		check(lv.world_to_cell(p.global_position) == spot.free, "a skeleton shoved the hero onto the table's tile")
		if lv.world_to_cell(p.global_position) != spot.free:
			break
	enemy.global_position = free_mid + Vector3(0, 0, 40)
	check(lv.shoves_onto_furniture(p, toward * 0.2), "a shove towards the table counts as onto furniture")
	check(not lv.shoves_onto_furniture(p, -toward * 0.2), "a shove away from the table does not")
	# A blow from the free side throws the hero towards the table.
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.block_chance = 0.0
	p.hp = p.max_hp
	p._invulnerable = 0.0
	p.take_damage(1, at - toward * 2.0, null, false)
	await _wait(40)
	check(lv.world_to_cell(p.global_position) == spot.free, "a blow threw the hero onto the table's tile")


## Out in the open the boulders (r) are drawn up to about 4 m wide: their
## collision follows that shape, so the hero cannot squeeze in between two
## of them into the drawn rock. And from a boulder's tile a click still finds
## a free tile to set out from.
func _check_boulders() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(3)
	var lv: Level = game.level
	var p: Player = game.player
	var space := p.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = p.radius
	capsule.height = p.tall
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.exclude = [p.get_rid()]
	var boulders := 0
	for node in lv.get_children():
		if not node is Node3D or not String(node.scene_file_path).contains("rock_single") or node.scale.x < 5.0:
			continue
		boulders += 1
		var own := Level.footprint(node, node)
		for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			# Well inside the drawn rock, towards each side of it.
			var local: Vector3 = own.get_center() + side * own.size * 0.4
			var spot: Vector3 = node.transform * local
			query.transform = Transform3D(Basis(), Vector3(spot.x, p.tall * 0.5 + 0.1, spot.z))
			check(not space.intersect_shape(query, 1).is_empty(),
					"the hero fits inside the boulder at %s (%s)" % [lv.world_to_cell(node.position), spot])
		var c := lv.world_to_cell(node.position)
		var out := lv.set_out_cell(lv.cell_to_world(c))
		check(lv.astar.is_in_boundsv(out) and not lv.astar.is_point_solid(out),
				"no free tile to set out from beside the boulder at %s" % c)
	check(boulders > 5, "the open-air map has boulders (%d)" % boulders)
