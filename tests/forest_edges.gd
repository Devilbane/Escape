extends SceneTree
## Headless test: at the edge of the woods, what looks walkable is walkable and what blocks looks
## blocked (see Outdoor._build_wall_collision):
## - the leaf-strewn floor in front of the edge trees can be walked on: the forest blocks from the
##   front of the crowns, not from the edge of the tile;
## - forest floor near the open ground that still blocks is hidden under a crown or undergrowth;
## - the woods stay shut all the same: walking from the open ground, the hero never gets further
##   into the forest than its edge tiles (no way opens between two tiles or across a thin strip);
## - the gaps just behind the edge are filled with trees, so no leafy clearing shows between them.
## Run with: godot --headless -s tests/forest_edges.gd

## How close to a crown or a bush blocked floor must lie to count as hidden (metres): the bushes
## are round and stand a little apart.
const HIDDEN_SLACK := 0.9
## The hero's body, as wide as the gaps it needs (metres).
const HERO_RADIUS := 0.3
## Sample points per metre.
const RES := 4

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
	game.hero_name = "Forest edges"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	var boxes := _boxes(lvl)
	var walk := 0
	var hidden_bad := 0
	var worst := Vector2i(-1, -1)
	for y in lvl.height:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if lvl.cell_char(c) != "#" or not lvl._beside_walkable(c) or lvl.under_lair_mountain(c):
				continue
			var tile := lvl._tile_rect(c)
			for iy in TILE_STEPS:
				for ix in TILE_STEPS:
					var p := tile.position + (Vector2(ix, iy) + Vector2.ONE * 0.5) * (Level.TILE / TILE_STEPS)
					var at := Vector3(p.x, 0, p.y)
					if not _blocked(boxes, p):
						walk += 1
						continue
					# Blocked floor the hero can see from the open ground must look blocked.
					# Floor right at the foot of the mountain rock grows no tree or bush (they would be cut
					# off by the rock, see Mountains.near_rock) and lies in the rock's shadow instead.
					if Mountains.near_rock(lvl, p.x, p.y, Mountains.BUSH_CLEARANCE):
						continue
					if _open_side_within(lvl, c, p, Outdoor.UNDERGROWTH_DEPTH) and not _hidden(lvl, c, at):
						hidden_bad += 1
						worst = c
	check(walk > 1000, "the leaves in front of the edge trees can be walked on (%d spots)" % walk)
	check(hidden_bad == 0, "blocked forest floor near the open ground is hidden under a crown or undergrowth (%d bare spots, e.g. tile %s)" % [hidden_bad, worst])
	_check_shut(lvl, boxes)
	_check_filled(lvl)
	print("PASS: forest edges" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


const TILE_STEPS := 8


## Every box of the walls' collision as a Rect2 on the ground (x, z), unturned boxes only; the
## turned ones (boulders) stand on rock tiles, not in the forest.
func _boxes(lvl: Outdoor) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for child in lvl._walls_body.get_children():
		var cs := child as CollisionShape3D
		if cs == null or not cs.shape is BoxShape3D:
			continue
		var size: Vector3 = (cs.shape as BoxShape3D).size
		var mid := cs.global_position
		var basis := cs.global_transform.basis
		var half := (basis * size * 0.5).abs()
		out.append(Rect2(mid.x - half.x, mid.z - half.z, half.x * 2.0, half.z * 2.0))
	return out


func _blocked(boxes: Array[Rect2], p: Vector2, grow := 0.0) -> bool:
	for b in boxes:
		if b.grow(grow).has_point(p):
			return true
	return false


## Whether a point lies within `depth` of a side of its tile's block that faces walkable ground.
func _open_side_within(lvl: Outdoor, c: Vector2i, p: Vector2, depth: float) -> bool:
	var b := lvl.forest_block(c)
	return (Outdoor.WALK.contains(lvl.cell_char(c + Vector2i(-1, 0))) and p.x - b.position.x < depth) \
			or (Outdoor.WALK.contains(lvl.cell_char(c + Vector2i(1, 0))) and b.end.x - p.x < depth) \
			or (Outdoor.WALK.contains(lvl.cell_char(c + Vector2i(0, -1))) and p.y - b.position.y < depth) \
			or (Outdoor.WALK.contains(lvl.cell_char(c + Vector2i(0, 1))) and b.end.y - p.y < depth)


func _hidden(lvl: Outdoor, c: Vector2i, at: Vector3) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for tree: Dictionary in lvl.forest_trees.get(c + Vector2i(dx, dy), []):
				if Vector2(at.x - tree.at.x, at.z - tree.at.z).length() < float(tree.crown) + HIDDEN_SLACK:
					return true
	for b: Vector4 in lvl.undergrowth_bushes:
		if Vector2(at.x - b.x, at.z - b.z).length() < b.w + HIDDEN_SLACK:
			return true
	# Beside a tree that stands on another tile (a lone "T" or a stump) or a building.
	return lvl.on_plot(at, 0.5)


## Flood fill over the ground (RES points a metre) from every walkable tile, through the forest
## tiles too, kept out of the walls' boxes by the hero's radius: nothing reaches a forest tile that
## is not beside the open ground.
func _check_shut(lvl: Outdoor, boxes: Array[Rect2]) -> void:
	var w := lvl.width * int(Level.TILE) * RES
	var h := lvl.height * int(Level.TILE) * RES
	var origin := Vector2(-0.5, -0.5) * Level.TILE
	var free := PackedByteArray()
	free.resize(w * h)
	for i in w * h:
		var px := i % w
		var py := i / w
		var c := Vector2i(px / (int(Level.TILE) * RES), py / (int(Level.TILE) * RES))
		var ch := lvl.cell_char(c)
		free[i] = 1 if ch == "#" or Outdoor.WALK.contains(ch) else 0
	# The boxes, grown by the hero's radius, marked off.
	for b in boxes:
		var g := b.grow(HERO_RADIUS)
		var x0 := maxi(0, floori((g.position.x - origin.x) * RES))
		var x1 := mini(w - 1, ceili((g.end.x - origin.x) * RES))
		var y0 := maxi(0, floori((g.position.y - origin.y) * RES))
		var y1 := mini(h - 1, ceili((g.end.y - origin.y) * RES))
		for py in range(y0, y1 + 1):
			for px in range(x0, x1 + 1):
				var p := origin + (Vector2(px, py) + Vector2.ONE * 0.5) / RES
				if g.has_point(p):
					free[py * w + px] = 0
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue := PackedInt32Array()
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) != "." :
				continue
			var i := (y * int(Level.TILE) * RES + int(Level.TILE) * RES / 2) * w + x * int(Level.TILE) * RES + int(Level.TILE) * RES / 2
			if free[i] == 1 and seen[i] == 0:
				seen[i] = 1
				queue.append(i)
	var head := 0
	var leaks := 0
	var leak_at := Vector2i(-1, -1)
	while head < queue.size():
		var i := queue[head]
		head += 1
		var px := i % w
		var py := i / w
		var c := Vector2i(px / (int(Level.TILE) * RES), py / (int(Level.TILE) * RES))
		if lvl.cell_char(c) == "#" and not lvl._beside_forest_edge(c):
			leaks += 1
			leak_at = c
			continue
		for n in [i - 1, i + 1, i - w, i + w]:
			if n < 0 or n >= w * h or seen[n] == 1 or free[n] == 0:
				continue
			if (n == i - 1 and px == 0) or (n == i + 1 and px == w - 1):
				continue
			seen[n] = 1
			queue.append(n)
	check(leaks == 0, "the woods stay shut: from the open ground nobody walks deeper into the forest than its edge (%d spots, e.g. tile %s)" % [leaks, leak_at])


## The forest tiles just behind the edge show no bare floor between the trees.
func _check_filled(lvl: Outdoor) -> void:
	var bare := 0
	var at_tile := Vector2i(-1, -1)
	for y in lvl.height:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if lvl.cell_char(c) != "#" or lvl._forest_depth(c) != 2:
				continue
			if lvl.under_lair_mountain(c):
				continue
			var mid := lvl.cell_to_world(c)
			if not lvl.under_crown(c, mid) and not lvl.on_plot(mid, 0.5):
				bare += 1
				at_tile = c
	check(bare == 0, "no bare forest floor right behind the edge trees (%d tiles, e.g. %s)" % [bare, at_tile])
