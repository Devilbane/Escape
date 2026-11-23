class_name WallFoot
extends RefCounted
## Grass, small flowers and mossy stones at the foot of the village's buildings, so a wall does
## not meet the lawn in a hard, straight line.
##
## Along the bottom edge of every outer wall that stands on the ground (AgedStone.walls), now and
## then a small clump grows: a few tufts of grass, sometimes a flower or two, sometimes a stone
## with moss on its top. LOOKS says how often and what mix: LOOK in the village, WILD (denser and
## taller) out in the country (see look_for). Never in front
## of a door, never on the temple glass's light, and only the stones on paving or a path's stones
## (the caller's `open` test decides where the ground is free).
##
## The seasons (see IvySeasons.stage): spring and summer are green and flowering; in autumn the
## grass turns straw-coloured day by day and most flowers are gone; in winter the grass lies low
## and pale and there are no flowers. The stones keep their moss and take the snow like any other
## surface (SnowCover). Nothing here casts a shadow, and everything is drawn in batches (one
## MultiMesh per kind and TILE square), not drawn from far away (DRAW_RANGE), so the whole
## village's fringe costs a few draw calls.

## How a look grows its clumps: `step` metres between the places along the wall where a clump may
## grow, the `chance` that one does, how many tufts of grass a clump has (`grass`, at least and at
## most), the chance of flowers in it (`flower`, and how many: `flowers`), the chance of a stone (and
## how many: `stones`), how far out from the wall a clump reaches (`reach`, metres) and how large
## its grass grows and its stones lie (`size`, `stone_size`). Two more cover the edge all along:
## `lining`, the gap (metres) between the low tufts of a grass lining right against the wall (0: none),
## and `band`, whether a dark band of moss and earth lies along the wall's foot.
const LOOKS := {
	"sparse": {"step": 1.2, "chance": 0.4, "grass": Vector2i(1, 2), "flower": 0.25, "flowers": Vector2i(1, 1),
			"stone": 0.25, "stones": Vector2i(1, 1), "reach": 0.4, "size": 0.95, "stone_size": 1.0},
	"meadow": {"step": 0.8, "chance": 0.65, "grass": Vector2i(2, 4), "flower": 0.85, "flowers": Vector2i(2, 5),
			"stone": 0.1, "stones": Vector2i(1, 1), "reach": 0.6, "size": 1.05, "stone_size": 1.0},
	"mossy": {"step": 0.9, "chance": 0.6, "grass": Vector2i(1, 2), "flower": 0.1, "flowers": Vector2i(1, 2),
			"stone": 0.9, "stones": Vector2i(2, 4), "reach": 0.55, "size": 0.95, "stone_size": 1.3},
	"village": {"step": 0.6, "chance": 0.8, "grass": Vector2i(2, 3), "flower": 0.55, "flowers": Vector2i(1, 4),
			"stone": 0.7, "stones": Vector2i(1, 3), "reach": 0.6, "size": 1.0, "stone_size": 1.2, "lining": 0.26, "band": true},
	"overgrown": {"step": 0.5, "chance": 0.85, "grass": Vector2i(3, 6), "flower": 0.5, "flowers": Vector2i(1, 3),
			"stone": 0.35, "stones": Vector2i(1, 2), "reach": 0.7, "size": 1.25, "stone_size": 1.1, "lining": 0.24, "band": true},
}
## The look of the village's buildings (mossy stones and meadow flowers, mixed, over a grass lining and
## a band of moss and earth), and the wilder one of the buildings out in the country (the crypt, the graveyard's wall, the dragon's lair).
const LOOK := "village"
const WILD := "overgrown"
static var look := LOOK
static var wild := WILD
## A building's footprint leaves out the parts of its walls lower than this (metres): steps, plinths.
const FOOTPRINT_LOW := 0.5
## Walls this large (square metres) are a building's own sides: what stands no more than
## FOOTPRINT_PROUD metres proud of one (a doorway's jambs) is left out of its footprint.
const FOOTPRINT_LONG_WALL := 10.0
const FOOTPRINT_PROUD := 0.8
## A stone_row: metres between its stones (on average) and how large they lie.
const ROW_STEP := 0.38
const ROW_STONE_SIZE := 1.5
## Only walls whose foot is this close to the ground (metres) grow a fringe.
const FOOT := 0.15
## Room left clear in front of a door (metres from the spot before it).
const DOOR_CLEAR := 1.1
## The most pieces of each kind in the whole village.
const CAP := 14000
## The squares (metres) the pieces are batched by: one MultiMesh per kind and square.
const TILE := 48.0
## Batches further than this from the camera are not drawn (metres).
const DRAW_RANGE := 70.0

## The grass's summer greens, a fresh spring green, and straw for autumn and winter.
const GRASS := [Color(0.4, 0.6, 0.2), Color(0.34, 0.54, 0.18), Color(0.46, 0.64, 0.24), Color(0.3, 0.48, 0.17)]
const SPRING_GRASS := Color(1.08, 1.12, 0.9)
const STRAW := [Color(0.72, 0.62, 0.34), Color(0.62, 0.55, 0.3), Color(0.56, 0.5, 0.3), Color(0.66, 0.58, 0.4)]
## In winter the grass lies this low (times its height).
const WINTER_LOW := 0.55
## Flower colours: white, yellow, pale violet, pink, blue.
const FLOWER_COLOURS := [Color(0.97, 0.96, 0.92), Color(1.0, 0.86, 0.25), Color(0.74, 0.6, 0.95),
		Color(1.0, 0.62, 0.74), Color(0.5, 0.64, 1.0)]
## The share of flowers that still blooms in autumn.
const AUTUMN_FLOWERS := 0.2
## Stone tints (the moss on top is in the mesh).
const STONE_TINTS := [Color(0.92, 0.9, 0.86), Color(0.8, 0.79, 0.76), Color(0.86, 0.82, 0.74)]
const STONE_GREY := Color(0.56, 0.54, 0.5)
const MOSS := Color(0.3, 0.44, 0.16)

const KINDS := ["grass", "lining", "flower", "stone", "band"]
## The band of moss and earth: how long one patch is along the wall and how deep out from it
## (metres), the gap between patches, and its colours (moss greens and dark earth).
const BAND_SIZE := Vector2(1.6, 1.3)
const BAND_STEP := 0.8
const BAND_COLOURS := [Color(0.2, 0.28, 0.1, 0.95), Color(0.24, 0.32, 0.12, 0.9), Color(0.26, 0.2, 0.12, 0.95), Color(0.22, 0.18, 0.11, 0.9)]
## In autumn the band turns browner.
const BAND_AUTUMN := Color(1.15, 0.85, 0.7)

static var _meshes := {}


## The look for a building in the village or, `in_village` false, out in the country.
static func look_for(in_village: bool) -> String:
	return look if in_village else wild


## Grows the fringe of one building (its triangles `tris`, see AgedStone.triangles, standing on
## `ground` round `middle`) into `out` ({kind: {"xforms": [], "colours": []}}). `doors` are the
## spots before its doors; `open(spot, stone)` says whether a spot on the ground may grow anything
## (or, `stone`, take a stone: stones may lie on paving too).
static func grow(tris: Array, middle: Vector3, ground: float, doors: Array, rng: RandomNumberGenerator, out: Dictionary, open: Callable, kind_of_look := "") -> void:
	var l: Dictionary = LOOKS[kind_of_look if kind_of_look != "" else look]
	for kind: String in KINDS:
		if not out.has(kind):
			out[kind] = {"xforms": [], "colours": []}
	for wall: Dictionary in AgedStone.walls(tris, middle, ground):
		if float(wall.foot) > ground + FOOT:
			continue
		# The run of the wall's bottom edge, along the wall.
		var lo := INF
		var hi := -INF
		for f: Vector2 in wall.flat:
			if f.y < float(wall.foot) + 0.05:
				lo = minf(lo, f.x)
				hi = maxf(hi, f.x)
		if hi - lo < 0.5:
			continue
		var n: Vector3 = wall.n
		var across: Vector3 = wall.across
		var steps := floori((hi - lo) / float(l.step))
		for i in steps:
			if rng.randf() > float(l.chance):
				continue
			var a := lo + (float(i) + rng.randf_range(0.2, 0.8)) * float(l.step)
			var base := across * a + n * float(wall.d)
			base.y = ground
			if _at_door(doors, base):
				continue
			_clump(base, n, across, rng, l, out, open)
		# The lining: low tufts in a row right against the wall, a little irregular.
		var gap: float = l.get("lining", 0.0)
		if gap > 0.0:
			var a := lo + rng.randf() * gap
			while a < hi:
				var base := across * a + n * (float(wall.d) + rng.randf_range(0.0, 0.1))
				base.y = ground
				a += gap * rng.randf_range(0.7, 1.3)
				if _at_door(doors, base) or not open.call(base, false) or out.lining.xforms.size() >= CAP:
					continue
				var sz := rng.randf_range(0.8, 1.15)
				out.lining.xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sz, sz * rng.randf_range(0.8, 1.2), sz)), base))
				var c: Color = GRASS[rng.randi() % GRASS.size()] * rng.randf_range(0.85, 1.05)
				c.a = 1.0
				out.lining.colours.append(c)
		# The band: flat patches of moss and earth along the foot, half under the wall.
		if l.get("band", false):
			var a := lo + BAND_STEP * 0.5
			while a < hi:
				var base := across * a + n * (float(wall.d) + 0.15)
				base.y = ground + 0.012
				a += BAND_STEP * rng.randf_range(0.8, 1.2)
				if _at_door(doors, base) or not open.call(base, false) or out.band.xforms.size() >= CAP:
					continue
				var size := BAND_SIZE * rng.randf_range(0.85, 1.15)
				# The patch's x along the wall, its z out from it; turned a little, and either way up.
				var flip := 1.0 if rng.randf() < 0.5 else -1.0
				var b := Basis(across * flip * size.x, Vector3.UP, n * size.y).rotated(Vector3.UP, rng.randf_range(-0.12, 0.12))
				out.band.xforms.append(Transform3D(b, base))
				out.band.colours.append(BAND_COLOURS[rng.randi() % BAND_COLOURS.size()])


## Whether a spot lies too close to the spot before a door.
static func _at_door(doors: Array, base: Vector3) -> bool:
	return doors.any(func(d: Vector3): return Vector2(d.x - base.x, d.z - base.z).length() < DOOR_CLEAR)


## One clump at `base` (on the wall's foot), its wall facing `n`.
static func _clump(base: Vector3, n: Vector3, across: Vector3, rng: RandomNumberGenerator, l: Dictionary, out: Dictionary, open: Callable) -> void:
	var reach: float = l.reach
	var size: float = l.size
	var spots := {
		"grass": rng.randi_range(l.grass.x, l.grass.y),
		"flower": rng.randi_range(l.flowers.x, l.flowers.y) if rng.randf() < float(l.flower) else 0,
		"stone": rng.randi_range(l.stones.x, l.stones.y) if rng.randf() < float(l.stone) else 0,
	}
	for kind: String in spots:
		var batch: Dictionary = out[kind]
		for k in int(spots[kind]):
			if batch.xforms.size() >= CAP:
				break
			# Hugging the wall: most of it close in, less further out.
			var off := pow(rng.randf(), 1.6) * reach
			var along := rng.randf_range(-0.45, 0.45)
			var at := base + n * (off * (0.6 if kind == "stone" else 1.0) + (0.08 if kind == "stone" else 0.0)) + across * along
			if not open.call(at, kind == "stone"):
				continue
			var turn := Basis(Vector3.UP, rng.randf() * TAU)
			var xf: Transform3D
			var colour: Color
			match kind:
				"grass":
					var s := rng.randf_range(0.8, 1.3) * size * (1.0 - off / reach * 0.35)
					xf = Transform3D(turn.scaled(Vector3(s, s * rng.randf_range(0.85, 1.25), s)), at)
					colour = GRASS[rng.randi() % GRASS.size()] * rng.randf_range(0.9, 1.08)
				"flower":
					var s := rng.randf_range(0.8, 1.15)
					# A little lean, away from the wall.
					var lean := Basis(across, rng.randf_range(0.0, 0.25)) * turn
					xf = Transform3D(lean.scaled(Vector3.ONE * s), at + n * 0.05)
					colour = FLOWER_COLOURS[rng.randi() % FLOWER_COLOURS.size()]
				"stone":
					var s := rng.randf_range(0.2, 0.42) * float(l.stone_size)
					xf = _stone_xform(at, s, turn, rng)
					colour = STONE_TINTS[rng.randi() % STONE_TINTS.size()] * rng.randf_range(0.9, 1.05)
			colour.a = 1.0
			batch.xforms.append(xf)
			batch.colours.append(colour)


## A stone of size `s` lying at `at`, turned by `turn` and tilted a little, sunk a bit into the ground.
static func _stone_xform(at: Vector3, s: float, turn: Basis, rng: RandomNumberGenerator) -> Transform3D:
	var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.25))
	return Transform3D((tilt * turn).scaled(Vector3(s * rng.randf_range(1.0, 1.5), s, s * rng.randf_range(0.9, 1.3))), at - Vector3(0, s * 0.18, 0))


## A row of mossy stones all along the foot of a building's front wall (the walls facing `facing`, a
## storey high and standing on the ground), where the door's clearance would leave it bare: only the
## stretch within `clear` metres either side of `door` (its steps) stays free. For a front wider than
## its doorway, such as the temple's. Stones may lie on paving; `open` (at, true) has the last word.
static func stone_row(tris: Array, middle: Vector3, ground: float, facing: Vector3, door: Vector3, clear: float, rng: RandomNumberGenerator, out: Dictionary, open: Callable) -> void:
	if not out.has("stone"):
		out["stone"] = {"xforms": [], "colours": []}
	for wall: Dictionary in AgedStone.walls(tris, middle, ground):
		var n: Vector3 = wall.n
		if float(wall.foot) > ground + FOOT or float(wall.top) < ground + 1.5 or float(wall.area) < 1.0 or n.dot(facing) < 0.9:
			continue
		var lo := INF
		var hi := -INF
		for f: Vector2 in wall.flat:
			if f.y < float(wall.foot) + 0.05:
				lo = minf(lo, f.x)
				hi = maxf(hi, f.x)
		var across: Vector3 = wall.across
		var door_at := door.dot(across)
		var a := lo + rng.randf() * ROW_STEP * 0.5
		while a < hi:
			var here := a
			a += ROW_STEP * rng.randf_range(0.6, 1.4)
			if absf(here - door_at) < clear:
				continue
			for k in rng.randi_range(1, 2):
				var off := 0.08 + pow(rng.randf(), 1.4) * 0.4
				var at := across * clampf(here + rng.randf_range(-0.15, 0.15), lo + 0.1, hi - 0.1) + n * (float(wall.d) + off)
				at.y = ground
				if out.stone.xforms.size() >= CAP or not open.call(at, true):
					continue
				var s := rng.randf_range(0.24, 0.5) * ROW_STONE_SIZE * (1.0 - off * 0.5)
				out.stone.xforms.append(_stone_xform(at, s, Basis(Vector3.UP, rng.randf() * TAU), rng))
				var colour: Color = STONE_TINTS[rng.randi() % STONE_TINTS.size()] * rng.randf_range(0.9, 1.05)
				colour.a = 1.0
				out.stone.colours.append(colour)


## Where a building stands on the ground: the outline (convex, seen from above) of the feet of its
## real walls (a storey high, standing on the ground; not its steps, see FOOTPRINT_LOW). A doorway's
## jambs standing a little proud of a long wall are cut off at that wall (see FOOTPRINT_PROUD), so
## its foot is not left bare. Nothing grows inside another building's (terraced houses stand wall to
## wall). `middle` is the middle of the building.
static func footprint(tris: Array, middle: Vector3, ground: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var long_walls: Array = []
	for wall: Dictionary in AgedStone.walls(tris, middle, ground):
		if float(wall.foot) > ground + FOOT or float(wall.top) < ground + 1.5 or float(wall.area) < 1.0:
			continue
		if float(wall.area) >= FOOTPRINT_LONG_WALL:
			long_walls.append(wall)
		for t: Dictionary in wall.tris:
			# The wall itself, not a low step or plinth that shares its plane (the temple's steps
			# share their sides with the door's jambs): it stands upright, so its lower part,
			# seen from above, lies on its foot.
			if maxf(t.a.y, maxf(t.b.y, t.c.y)) < ground + FOOTPRINT_LOW:
				continue
			for q: Vector3 in [t.a, t.b, t.c]:
				if q.y < ground + 3.0:
					points.append(Vector2(q.x, q.z))
	if points.size() < 3:
		return PackedVector2Array()
	var hull := Geometry2D.convex_hull(points)
	for wall: Dictionary in long_walls:
		var n := Vector2((wall.n as Vector3).x, (wall.n as Vector3).z).normalized()
		var d := float(wall.d)
		var proud := -INF
		for q in hull:
			proud = maxf(proud, q.dot(n) - d)
		if proud <= 0.02 or proud > FOOTPRINT_PROUD:
			continue
		# Everything behind the wall's plane (a big square on its inner side).
		var along := Vector2(-n.y, n.x) * 1000.0
		var at := n * (d + 0.02)
		var behind := PackedVector2Array([at + along, at - along, at - along - n * 1000.0, at + along - n * 1000.0])
		var cut := Geometry2D.intersect_polygons(hull, behind)
		if not cut.is_empty():
			hull = cut[0]
	return hull


## Keeps only the pieces of `grown` (see grow) whose spot `open` still allows (the ways to the doors
## are paved after the buildings are dressed).
static func keep_open(grown: Dictionary, open: Callable) -> void:
	for kind: String in grown:
		var batch: Dictionary = grown[kind]
		var xforms: Array = []
		var colours: Array = []
		for i in batch.xforms.size():
			if open.call((batch.xforms[i] as Transform3D).origin, kind == "stone"):
				xforms.append(batch.xforms[i])
				colours.append(batch.colours[i])
		grown[kind] = {"xforms": xforms, "colours": colours}


## The batches for `grown` (see grow), as one node: per kind and tile one MultiMesh, holding its
## pieces as grown (meta "grown") for the seasons to change.
static func node(grown: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "WallFoot"
	for kind: String in KINDS:
		if not grown.has(kind):
			continue
		var batch: Dictionary = grown[kind]
		var tiles := {}
		for i in batch.xforms.size():
			var at: Vector3 = (batch.xforms[i] as Transform3D).origin
			var key := Vector2i(floori(at.x / TILE), floori(at.z / TILE))
			if not tiles.has(key):
				tiles[key] = []
			tiles[key].append(i)
		for key: Vector2i in tiles:
			var picked: Array = tiles[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh(kind)
			mm.instance_count = picked.size()
			var xforms: Array[Transform3D] = []
			var colours := PackedColorArray()
			for k in picked.size():
				xforms.append(batch.xforms[picked[k]])
				colours.append(batch.colours[picked[k]])
				mm.set_instance_transform(k, xforms[k])
				mm.set_instance_color(k, colours[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [kind.capitalize(), key.x, key.y]
			mmi.multimesh = mm
			mmi.set_meta("kind", kind)
			mmi.set_meta("grown", [xforms, colours])
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = DRAW_RANGE
			root.add_child(mmi)
	return root


## Snow lies at least this thick (0 to 1, see SnowCover) and the fringe is buried under it: the
## grass, flowers and the band of moss all vanish, so the snow runs right up to the wall's foot.
## The snow follows the weather, not the calendar, so this holds in any season.
const BURIED_FROM := 0.3


## Buries the fringe under `root` (see node) in the snow, or digs it out again, as `cover` (how thick
## the snow lies, 0 to 1) passes BURIED_FROM. The stones stay: the snow settles on them.
static func bury(root: Node3D, cover: float) -> void:
	if root == null:
		return
	var on := cover >= BURIED_FROM
	if bool(root.get_meta("buried", false)) == on:
		return
	root.set_meta("buried", on)
	_show(root)


## Shows or hides each batch by the season's stage and by the snow (see bury).
static func _show(root: Node3D) -> void:
	var winter := int(root.get_meta("season_stage", -1)) == IvySeasons.WINTER
	var buried := bool(root.get_meta("buried", false))
	for child in root.get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null or not mmi.has_meta("grown"):
			continue
		match String(mmi.get_meta("kind")):
			"grass", "lining":
				mmi.visible = not buried
			"flower", "band":
				mmi.visible = not buried and not winter


## Dresses the fringe under `root` (see node) for season day `day`. Does nothing while the stage holds.
static func apply(root: Node3D, day: int) -> void:
	if root == null:
		return
	var at := IvySeasons.stage(day)
	if int(root.get_meta("season_stage", -1)) == at:
		return
	root.set_meta("season_stage", at)
	var straw := 0.0
	if at == IvySeasons.WINTER:
		straw = 1.0
	elif at != IvySeasons.SPRING:
		straw = IvySeasons.turned(at)
	for child in root.get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null or not mmi.has_meta("grown"):
			continue
		var kind: String = mmi.get_meta("kind")
		var grown: Array = mmi.get_meta("grown")
		var mm := mmi.multimesh
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(mmi.name))
		match kind:
			"grass", "lining":
				var turned := 0
				for i in mm.instance_count:
					var t: Transform3D = grown[0][i]
					var c: Color = grown[1][i]
					var roll := rng.randf()
					var pick := rng.randi()
					if at == IvySeasons.SPRING:
						c = c * SPRING_GRASS
					elif roll < straw:
						c = STRAW[pick % STRAW.size()] * (c.v / 0.55)
						turned += 1
					if at == IvySeasons.WINTER:
						t.basis = t.basis.scaled(Vector3(1.15, WINTER_LOW, 1.15))
					c.a = 1.0
					mm.set_instance_transform(i, t)
					mm.set_instance_color(i, c)
				# How many tufts have turned to straw (for the tests).
				mmi.set_meta("straw", turned)
			"flower":
				# Autumn takes the flowers day by day, as it turns the grass, until only
				# AUTUMN_FLOWERS of them bloom; winter takes them all.
				var keep := 1.0 - straw * (1.0 - AUTUMN_FLOWERS)
				var shown := 0
				for i in mm.instance_count:
					var t: Transform3D = grown[0][i]
					if rng.randf() >= keep or at == IvySeasons.WINTER:
						t.basis = t.basis.scaled(Vector3.ZERO)
					else:
						shown += 1
					mm.set_instance_transform(i, t)
				# How many flowers bloom now (for the tests).
				mmi.set_meta("shown", shown)
			"band":
				# Under the snow in winter; browner as autumn turns the grass.
				for i in mm.instance_count:
					var c: Color = grown[1][i]
					var a := c.a
					c = c.lerp(c * BAND_AUTUMN, straw)
					c.a = a
					mm.set_instance_color(i, c)
	_show(root)


## The shared mesh of a kind.
static func mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		match kind:
			"grass":
				_meshes[kind] = _grass_mesh()
			"lining":
				_meshes[kind] = _grass_mesh(10, Vector2(0.3, 0.55), 77)
			"band":
				_meshes[kind] = _band_mesh()
			"flower":
				_meshes[kind] = _flower_mesh()
			"stone":
				_meshes[kind] = _stone_mesh()
	return _meshes[kind]


static func _material(cull_off: bool, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.roughness = roughness
	if cull_off:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A tuft of grass about half a metre high (by default; the lining's are lower and thinner):
## blades of two bent pieces fanning out, dark at their feet.
static func _grass_mesh(blades := 18, tall_range := Vector2(0.35, 0.7), dice := 4711) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = dice
	for i in blades:
		var a := TAU * i / blades + rng.randf_range(-0.35, 0.35)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x)
		var w := rng.randf_range(0.035, 0.05)
		var tall := rng.randf_range(tall_range.x, tall_range.y)
		var bend := rng.randf_range(0.25, 0.6)
		var foot := out * rng.randf_range(0.0, 0.14)
		var mid := foot + out * tall * bend * 0.35 + Vector3(0, tall * 0.55, 0)
		var tip := foot + out * tall * bend + Vector3(0, tall, 0)
		var rows := [[foot, w, 0.5], [mid, w * 0.75, 0.85], [tip, 0.0, 1.15]]
		for r in 2:
			var p0: Array = rows[r]
			var p1: Array = rows[r + 1]
			var a0: Vector3 = p0[0] - side * float(p0[1])
			var b0: Vector3 = p0[0] + side * float(p0[1])
			var a1: Vector3 = p1[0] - side * float(p1[1])
			var b1: Vector3 = p1[0] + side * float(p1[1])
			var quad := [[a0, p0[2]], [b0, p0[2]], [b1, p1[2]], [a0, p0[2]], [b1, p1[2]], [a1, p1[2]]]
			if r == 1:
				quad = quad.slice(0, 3)
			for v: Array in quad:
				var shade: float = v[1]
				st.set_color(Color(shade, shade, shade))
				st.set_normal((Vector3.UP * 0.8 + out * 0.4).normalized())
				st.add_vertex(v[0])
	st.set_material(_material(true, 0.85))
	return st.commit()


## A flat patch of moss and earth, one unit square (stretched per patch): soft and frayed at its rim,
## so it melts into the lawn. Drawn under the fog like the ground's own litter (SurfaceLife), and
## left bare of snow (it is hidden in winter).
static func _band_mesh() -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.albedo_texture = SurfaceLife._patch_texture(57, 0.09)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.render_priority = FogClouds.UNDER_FOG
	plane.material = m
	return plane


## A meadow flower about a third of a metre high: a thin green stem with a leaf, and a head of five
## petals round a darker eye. The petals are white in the mesh and take the instance's colour;
## the stem's green is dark enough that a tint hardly shows on it.
static func _flower_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := Color(0.32, 0.5, 0.2)
	var h := 0.42
	var up := Vector3(0.03, h, 0.02)
	var w := 0.016
	for tri: Array in [[Vector3(-w, 0, 0), Vector3(w, 0, 0), up + Vector3(w * 0.5, 0, 0)], [Vector3(-w, 0, 0), up + Vector3(w * 0.5, 0, 0), up - Vector3(w * 0.5, 0, 0)],
			[Vector3(0, 0, -w), Vector3(0, 0, w), up + Vector3(0, 0, w * 0.5)], [Vector3(0, 0, -w), up + Vector3(0, 0, w * 0.5), up - Vector3(0, 0, w * 0.5)]]:
		for v: Vector3 in tri:
			st.set_color(stem)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	# A leaf halfway up.
	var leaf_at := up * 0.35
	for v: Vector3 in [leaf_at, leaf_at + Vector3(0.12, 0.07, 0.03), leaf_at + Vector3(0.06, 0.09, -0.025)]:
		st.set_color(stem * 1.15)
		st.set_normal(Vector3.UP)
		st.add_vertex(v)
	# The head, tilted a little.
	var centre := up + Vector3(0, 0.005, 0)
	var tilt := Basis(Vector3.RIGHT, 0.35)
	var petals := 5
	var r := 0.09
	for i in petals:
		var a := TAU * i / petals
		var b := TAU * (i + 0.5) / petals
		var c := TAU * (i - 0.5) / petals
		var tip := centre + tilt * (Vector3(cos(a), 0.15, sin(a)) * r)
		var left := centre + tilt * (Vector3(cos(c), 0.05, sin(c)) * r * 0.45)
		var right := centre + tilt * (Vector3(cos(b), 0.05, sin(b)) * r * 0.45)
		for v: Vector3 in [centre, left, tip, centre, tip, right]:
			st.set_color(Color(1, 1, 1))
			st.set_normal(tilt * Vector3.UP)
			st.add_vertex(v)
	# The eye: a small raised dome, dark gold (tinted with the petals, it stays the darkest part).
	var eye := 0.03
	for i in 6:
		var a := TAU * i / 6.0
		var b := TAU * (i + 1) / 6.0
		for v: Vector3 in [centre + tilt * Vector3(0, 0.008, 0), centre + tilt * (Vector3(cos(a), 0.012, sin(a)) * eye), centre + tilt * (Vector3(cos(b), 0.012, sin(b)) * eye)]:
			st.set_color(Color(0.85, 0.55, 0.12))
			st.set_normal(tilt * Vector3.UP)
			st.add_vertex(v)
	st.set_material(_material(true, 0.7))
	return st.commit()


## A rounded field stone about one unit across (scaled down per stone), flat faced, its upper
## faces green with moss, the rest grey.
static func _stone_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1312
	var ring := 7
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for i in ring:
		var a := TAU * i / ring + rng.randf_range(-0.2, 0.2)
		low.append(Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.46, 0.55) + Vector3(0, rng.randf_range(-0.05, 0.05), 0))
		var b := a + PI / ring
		high.append(Vector3(cos(b), 0, sin(b)) * rng.randf_range(0.28, 0.36) + Vector3(0, rng.randf_range(0.4, 0.5), 0))
	var top := Vector3(rng.randf_range(-0.06, 0.06), 0.6, rng.randf_range(-0.06, 0.06))
	var bottom := Vector3(0, -0.2, 0)
	var tris: Array = []
	for i in ring:
		var j := (i + 1) % ring
		tris.append([low[i], high[i], low[j]])
		tris.append([low[j], high[i], high[j]])
		tris.append([high[i], top, high[j]])
		tris.append([low[i], low[j], bottom])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in tris:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		# Godot's front faces run clockwise seen from outside.
		var nrm := (c - a).cross(b - a).normalized()
		if nrm.dot((a + b + c) / 3.0 - Vector3(0, 0.15, 0)) < 0.0:
			nrm = -nrm
			var swap := b
			b = c
			c = swap
		var mossy := clampf((nrm.y - 0.25) / 0.45, 0.0, 1.0)
		var col := STONE_GREY.lerp(MOSS, mossy * rng.randf_range(0.75, 1.0)) * rng.randf_range(0.92, 1.06)
		for v: Vector3 in [a, b, c]:
			st.set_color(col)
			st.set_normal(nrm)
			st.add_vertex(v)
	st.set_material(_material(false, 0.95))
	return st.commit()
