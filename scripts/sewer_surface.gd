class_name SewerSurface
extends RefCounted
## What the village's sewers (see Sewers) show up on the open-air map, letter by letter:
##
##   "Ω"  the stream's grating: the little stream that runs down the pass from the valley's river ends
##        in a stone culvert head with an iron grille across it, where it dives under the village.
##        Two tiles wide; the first tile builds it all.
##   "Ψ"  the outfall: where the sewer's water comes out again, north of the village, a stone head
##        wall with a round arch, and the river that carries it off into the forest. Two tiles wide.
##   "Θ"  a manhole hatch: a stone kerb round a shaft with a heavy lid. The hero runs into the lid
##        and heaves it open; the shaft below has a ladder (see Sewers.hatch).
##   "Ξ"  a street drain: an iron grating in the paving, flush with the street, over the sewer's channel.
##
## The stream and the river below the outfall carry leaves, foam and the village's rubbish along
## (see StreamFlow), so the water is seen to flow.

const W := preload("res://scripts/weathered_props.gd")

const MOUTH := "Ω"
const OUTFALL := "Ψ"
const HATCH := "Θ"
const GRILLE := "Ξ"
## How far round a street drain no snow settles (it is warm there): the frame, the setts and a little more.
const GRILLE_WARM := 1.6
const LETTERS := "ΩΨΘΞ"

## The first tile of each two-tile piece (the other one lies to its east).
const MOUTH_TILE := Vector2i(44, 45)
const OUTFALL_TILE := Vector2i(37, 19)

const STONE := Color(0.62, 0.6, 0.56)
const DARK_STONE := Color(0.5, 0.49, 0.46)
const IRON := Color(0.26, 0.26, 0.28)
const RUST := Color(0.42, 0.24, 0.12)
## Dark forged iron of the hatch hinges, with rust over it.
const HINGE_IRON := Color(0.17, 0.15, 0.14)
## The stream: from where it leaves the river (tile rows) to the grating (south to north).
const STREAM_FROM_ROW := 67
const STREAM_TO_ROW := 46
## The river below the outfall: from the arch to the north.
const RIVER_TO_ROW := 4
## Station kind of a hatch's lid.
const LID := "kanalluke"
## The colour of snow on the heap caught at the grating, and the snow cover (see Outdoor.set_snow) from which it shows.
const SNOW := Color(0.94, 0.96, 1.0)
const SNOW_FROM := 0.3
const HEAP_GROUP := "grating_heap"
const SNOWY_META := "snowy"

static var _water: ShaderMaterial = null


static func is_letter(ch: String) -> bool:
	return LETTERS.contains(ch)


## Builds the piece of tile `c` (letter `ch`) on the map.
static func build(lvl: Outdoor, c: Vector2i, ch: String) -> void:
	match ch:
		MOUTH:
			if c == MOUTH_TILE:
				_mouth(lvl, c)
		OUTFALL:
			if c == OUTFALL_TILE:
				_outfall(lvl, c)
		HATCH:
			_hatch(lvl, c)
		GRILLE:
			_grille(lvl, c)


# --- Masonry helpers --------------------------------------------------------

## A wall of dressed blocks in courses: x from `x0` to `x1`, y from `y0` to `y1`, the face at `z`
## and `depth` deep, each block a little different in size, tone and set a hair out of line. A block whose
## middle `skip` says yes to is left out (an opening, an arch).
static func _courses(b: W.Builder, x0: float, x1: float, y0: float, y1: float, z: float, depth: float,
		rng: RandomNumberGenerator, skip := Callable()) -> void:
	var y := y0
	var row := 0
	while y < y1 - 0.01:
		var h := minf(rng.randf_range(0.26, 0.38), y1 - y)
		var x := x0 - (0.0 if row % 2 == 0 else rng.randf_range(0.2, 0.5))
		while x < x1 - 0.01:
			var w := rng.randf_range(0.45, 0.9)
			var left := maxf(x, x0)
			var right := minf(x + w, x1)
			if right - left > 0.12:
				var mid := Vector2((left + right) * 0.5, y + h * 0.5)
				if not (skip.is_valid() and skip.call(mid)):
					var out := rng.randf_range(0.0, 0.05)
					var tone := W.vary(STONES[rng.randi() % STONES.size()], rng, 0.07)
					b.frustum(Vector3((left + right) * 0.5, y, z + out * 0.5), Vector2(right - left - 0.03, depth + out), Vector2(right - left - 0.07, depth + out - 0.02), h - 0.03, tone, W.STONE)
			x += w
		y += h
		row += 1


const STONES := [Color(0.64, 0.62, 0.58), Color(0.58, 0.58, 0.55), Color(0.66, 0.62, 0.55), Color(0.55, 0.56, 0.52), Color(0.6, 0.57, 0.5)]


# --- The stream and its grating -----------------------------------------------

## The culvert head where the stream goes under the village: a wall of coursed blocks across both tiles
## with a wide opening, a lintel of great stones with a keystone, the opening barred with iron, and what
## the stream brought down caught in the bars.
static func _mouth(lvl: Outdoor, c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalgitter")
	var mid := lvl.cell_to_world(c) + Vector3(Level.TILE * 0.5, 0, 0)
	var half := Level.TILE
	var face := Level.TILE * 0.5 - 0.3
	var b := W.Builder.new()
	var open := half - 0.9
	var top := 2.1
	var sill := 1.5
	# The wall's face: courses of blocks everywhere but in the opening, up to the coping.
	_courses(b, -half, half, 0.0, top, face - 0.12, 0.5, rng, func(m: Vector2) -> bool: return absf(m.x) < open and m.y < sill)
	# The body behind it, and the earth-bank it holds back.
	b.box(Vector3(0, 0, -0.6), Vector3(half * 2.0, top - 0.1, 2.4), W.vary(DARK_STONE, rng), W.STONE)
	# The lintel: five great stones across the opening, a keystone in the middle standing proud.
	for i in 5:
		var w := open * 2.0 / 5.0
		var x := -open + w * (i + 0.5)
		var bump := 0.0
		if i == 2:
			bump = 0.18
		b.frustum(Vector3(x, sill, face - 0.05), Vector2(w - 0.04, 0.62 + bump), Vector2(w - 0.1, 0.56 + bump), top - sill - 0.02 + bump * 0.5, W.vary(STONES[i % STONES.size()], rng, 0.06), W.STONE)
	# A coping of long flat slabs with a drip edge.
	for i in 8:
		var w := half * 2.0 / 8.0
		b.frustum(Vector3(-half + w * (i + 0.5), top, 0.0), Vector2(w - 0.03, 3.7), Vector2(w - 0.1, 3.5), 0.16, W.vary(DARK_STONE, rng, 0.06), W.STONE)
	# The dark opening behind the bars, and a stone sill in the water.
	b.box(Vector3(0, 0, 0.0), Vector3(open * 2.0, sill, 2.6), Color(0.03, 0.04, 0.04), W.IRON)
	b.frustum(Vector3(0, -0.04, face + 0.28), Vector2(open * 2.0 + 0.4, 0.9), Vector2(open * 2.0 + 0.2, 0.7), 0.16, W.vary(DARK_STONE, rng, 0.05), W.STONE)
	# The bars: round, upright every 24 cm with a cap and a foot, three flat bands across riveted at every bar.
	var span := open * 2.0 - 0.2
	var bars := int(span / 0.24)
	for i in bars + 1:
		var x := -span * 0.5 + i * span / bars
		b.cylinder(Vector3(x, 0.0, face + 0.34), 0.026, 0.026, sill + 0.05, W.vary(IRON, rng, 0.06), W.IRON, 6)
		b.cylinder(Vector3(x, sill + 0.05, face + 0.34), 0.04, 0.0, 0.1, W.vary(IRON, rng, 0.06), W.IRON, 6)
	for y: float in [0.28, 0.8, 1.32]:
		b.box(Vector3(0, y, face + 0.34), Vector3(span, 0.09, 0.07), W.vary(RUST, rng, 0.1), W.IRON)
		for i in bars + 1:
			var x := -span * 0.5 + i * span / bars
			b.cylinder(Vector3(x, y + 0.09, face + 0.34), 0.035, 0.03, 0.03, W.vary(IRON, rng, 0.08), W.IRON, 6)
	# Wing walls where the pass's rock meets it, stepped down.
	for side in [-1.0, 1.0]:
		for k in 3:
			b.frustum(Vector3(side * (half + 0.3 + k * 0.4), 0, 0.0), Vector2(0.8, 3.2), Vector2(0.7, 3.0), 1.9 - k * 0.55, W.vary(STONES[k], rng, 0.07), W.STONE)
	b.finish(lvl, mid)
	# Whatever the stream brought down and the bars caught: sticks, planks, a heap of leaves, a rag. Kept in
	# two meshes: the brown heap, and the same heap under snow (it lies in the shore's bare zone, where
	# the snow layer does not settle), shown instead of it while snow lies (see set_snow).
	for snowy in [false, true]:
		var heap := W.Builder.new()
		_caught(heap, face, span, snowy)
		var mi := heap.finish(lvl, mid)
		mi.name = "CaughtSnowy" if snowy else "Caught"
		mi.set_meta(SNOWY_META, snowy)
		# The snowy heap draws its own snow, and the overlay on top of it would fight with it.
		mi.set_meta("no_snow", true)
		mi.visible = not snowy
		if snowy:
			mi.material_override = _snow_material()
		mi.add_to_group(HEAP_GROUP)
	set_snow(lvl, lvl.snow.amount if lvl.snow != null else 0.0)
	lvl._add_solid(mid + Vector3(0, 0, 0.0), Vector3(half * 2.0, 2.2, 3.6))
	_stream(lvl)


## The sticks, planks and leaves the stream brought down and the bars caught, in their own colours or, with
## `snowy`, under a coat of snow (the same pieces, in the same places).
static func _caught(b: W.Builder, face: float, span: float, snowy: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalgitter-heap")
	for i in 22:
		var x := rng.randf_range(-span * 0.5, span * 0.5)
		var long := rng.randf_range(0.4, 1.4)
		var turn := rng.randf_range(-0.6, 0.6) + (PI * 0.5 if i % 4 == 0 else 0.0)
		var colour: Color = W.vary(SNOW if snowy else W.TIMBER[i % W.TIMBER.size()], rng, 0.12)
		b.bar(Vector3(x - cos(turn) * long * 0.5, 0.05 + (i % 4) * 0.05, face + 0.5 + rng.randf() * 0.4),
				Vector3(x + cos(turn) * long * 0.5, 0.07 + (i % 3) * 0.05, face + 0.5 + rng.randf() * 0.4 + sin(turn) * long * 0.2), 0.025 + rng.randf() * 0.03,
				colour, W.WOOD, 5)
	for i in 14:
		var x := rng.randf_range(-span * 0.5, span * 0.5)
		var colour: Color = W.vary(SNOW if snowy else StreamFlow.LEAVES[i % StreamFlow.LEAVES.size()], rng, 0.1)
		b.frustum(Vector3(x, 0.0, face + 0.55 + rng.randf() * 0.5), Vector2(0.6 + rng.randf() * 0.6, 0.5 + rng.randf() * 0.4), Vector2(0.2, 0.2), 0.12 + rng.randf() * 0.1,
				colour, W.WOOD, Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)))


static var _snow_mat: StandardMaterial3D = null


## Snow on the heap: soft white with a fine grain, tinted per piece by the mesh's colours.
static func _snow_material() -> StandardMaterial3D:
	if _snow_mat == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.06
		noise.seed = 7
		var grain := NoiseTexture2D.new()
		grain.noise = noise
		grain.width = 128
		grain.height = 128
		grain.seamless = true
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		m.albedo_texture = grain
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.7, 0.7, 0.7)
		m.roughness = 0.85
		_snow_mat = m
	return _snow_mat


## Shows the heap at the grating brown or snowed over, by how thick the snow lies (0 to 1, see Outdoor.set_snow).
static func set_snow(lvl: Node, cover: float) -> void:
	if not lvl.is_inside_tree():
		return
	var snowed := cover >= SNOW_FROM
	for heap: Node3D in lvl.get_tree().get_nodes_in_group(HEAP_GROUP):
		heap.visible = bool(heap.get_meta(SNOWY_META)) == snowed


## The leaves, foam and bits of rubbish that drift down the stream to the grating.
static func _stream(lvl: Outdoor) -> void:
	var tile := Level.TILE
	var flow := StreamFlow.new()
	flow.name = "StreamFlow"
	flow.from = Vector3((MOUTH_TILE.x + 0.5) * tile, 0.06, (STREAM_FROM_ROW + 0.5) * tile)
	flow.to = Vector3((MOUTH_TILE.x + 0.5) * tile, 0.06, (STREAM_TO_ROW - 0.2) * tile)
	flow.width = tile * 2.0 - 1.6
	flow.speed = 0.55
	flow.count = 16
	flow.foam_every = 0
	flow.seasonal = true
	flow.palette = StreamFlow.GREEN_LEAVES
	lvl.add_child(flow)


# --- The outfall and the river below it ---------------------------------------

## The head wall where the sewer's water comes out again: coursed blocks across both tiles with a round
## arch in its face towards the north (a ring of voussoirs with a keystone), a rusty grille hanging half open
## from the crown, wing walls on the bank, and the water running out over a worn stone apron.
static func _outfall(lvl: Outdoor, c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalauslauf")
	var mid := lvl.cell_to_world(c) + Vector3(Level.TILE * 0.5, 0, 0)
	var half := Level.TILE
	var face := -(Level.TILE * 0.5 - 0.3)
	var b := W.Builder.new()
	var radius := 1.7
	var spring := 1.0
	var top := 3.0
	# The face: courses of blocks, left out inside the arch (the opening) and its ring.
	_courses(b, -half, half, 0.0, top, face - 0.12, 0.5, rng, func(m: Vector2) -> bool:
		return Vector2(m.x, m.y - spring).length() < radius + 0.55 if m.y >= spring else absf(m.x) < radius + 0.5)
	b.box(Vector3(0, 0, 0.5), Vector3(half * 2.0, top - 0.1, 2.9), W.vary(DARK_STONE, rng), W.STONE)
	# The arch: a ring of wedge stones round the opening, each turned to its place in the curve, the
	# keystone standing out at the crown; straight jamb stones below the springing.
	var stones := 15
	for i in stones:
		var a := PI * (float(i) + 0.5) / stones
		var radial := Vector3(-cos(a), sin(a), 0)
		var long := 0.62 if i != stones / 2 else 0.78
		var at := Vector3(0, spring, face - 0.06) + radial * (radius + 0.04)
		var turn := Basis.from_euler(Vector3(0, 0, PI * 0.5 - a))
		b.frustum(at, Vector2(0.42, 0.56), Vector2(0.5, 0.56), long + (0.04 if i == stones / 2 else 0.0), W.vary(STONES[i % STONES.size()], rng, 0.07), W.STONE, turn)
	for side in [-1.0, 1.0]:
		for k in 3:
			b.box(Vector3(side * (radius + 0.3), k * spring / 3.0, face - 0.06), Vector3(0.6, spring / 3.0 - 0.02, 0.56), W.vary(STONES[k], rng, 0.07), W.STONE)
	# A coping, and a string course under it.
	for i in 8:
		var w := half * 2.0 / 8.0
		b.frustum(Vector3(-half + w * (i + 0.5), top, 0.4), Vector2(w - 0.03, 3.4), Vector2(w - 0.1, 3.2), 0.16, W.vary(DARK_STONE, rng, 0.06), W.STONE)
	# The dark inside, and a rusty grille hanging half open from the crown, bars of different lengths.
	b.box(Vector3(0, 0, 0.3), Vector3(radius * 2.0 - 0.3, spring + radius - 0.1, 2.8), Color(0.03, 0.04, 0.04), W.IRON)
	for i in 9:
		var x := -radius + 0.35 + i * (radius * 2.0 - 0.7) / 8.0
		var crown := sqrt(maxf(radius * radius - x * x, 0.0)) + spring
		var drop := 0.9 + 0.35 * absf(sin(float(i) * 1.7))
		b.cylinder(Vector3(x, crown - drop - 0.1, face + 0.1), 0.024, 0.024, drop, W.vary(RUST, rng, 0.1), W.IRON, 6)
	b.box(Vector3(0, spring + radius - 0.22, face + 0.1), Vector3(radius * 2.0 - 0.5, 0.08, 0.07), W.vary(RUST, rng, 0.1), W.IRON)
	# Wing walls a little way out, stepped, to keep the bank.
	for side in [-1.0, 1.0]:
		for k in 3:
			b.frustum(Vector3(side * (half - 0.4 + k * 0.05), 0, face - 0.5 - k * 0.7), Vector2(0.8, 0.8), Vector2(0.7, 0.7), 1.3 - k * 0.38, W.vary(STONES[k], rng, 0.07), W.STONE)
	# The apron: worn slabs the water runs over, mossy at the edges.
	for i in 7:
		var x := -radius + 0.3 + i * (radius * 2.0 - 0.6) / 6.0
		b.frustum(Vector3(x, -0.02, face - 0.55 - rng.randf() * 0.3), Vector2(0.5, 0.9), Vector2(0.45, 0.8), 0.07, W.vary(Color(0.4, 0.44, 0.34), rng, 0.1), W.STONE)
	b.finish(lvl, mid)
	lvl._add_solid(mid + Vector3(0, 0, 0.1), Vector3(half * 2.0, 2.6, 3.6))
	# The water coming out: a sheet from the arch across the apron to the river.
	var sheet := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0 - 0.1, Level.TILE * 0.5 + 0.4)
	sheet.mesh = plane
	sheet.material_override = _outfall_water()
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.position = mid + Vector3(0, 0.05, face - plane.size.y * 0.5 + 0.35)
	lvl.add_child(sheet)
	_river(lvl)


static func _outfall_water() -> ShaderMaterial:
	if _water == null:
		_water = ShaderMaterial.new()
		_water.shader = preload("res://shaders/water.gdshader")
		_water.set_shader_parameter("deep_color", Vector3(0.2, 0.2, 0.1))
		_water.set_shader_parameter("shallow_color", Vector3(0.36, 0.34, 0.18))
		_water.set_shader_parameter("glow", 0.0)
		_water.set_shader_parameter("rings", 0.0)
	return _water


## The village's rubbish on its way down the river through the forest.
static func _river(lvl: Outdoor) -> void:
	var tile := Level.TILE
	var flow := StreamFlow.new()
	flow.name = "OutfallFlow"
	flow.from = Vector3((OUTFALL_TILE.x + 1.0) * tile, 0.06, (OUTFALL_TILE.y - 0.4) * tile)
	flow.to = Vector3((OUTFALL_TILE.x + 1.0) * tile, 0.06, RIVER_TO_ROW * tile)
	flow.width = tile * 2.0 - 1.6
	flow.speed = 0.6
	flow.count = 90
	flow.rubbish = true
	flow.palette = StreamFlow.RUBBISH
	lvl.add_child(flow)
	# And the leaves and sticks every river carries (see RiverFlow).
	var leaves := StreamFlow.new()
	leaves.name = "OutfallLeaves"
	leaves.from = flow.from
	leaves.to = flow.to
	leaves.width = flow.width
	leaves.speed = flow.speed
	leaves.count = 24
	leaves.foam_every = 0
	leaves.seasonal = true
	leaves.palette = StreamFlow.GREEN_LEAVES
	lvl.add_child(leaves)


# --- The street's grating and the manhole -------------------------------------

## A street drain: a cast-iron grating in a stone frame, flush with the street, over a dark slot, with
## a ring of setts round it. It carries on the ground; the sewer below has its own shaft of light
## under it (see Sewers).
static func _grille(lvl: Outdoor, c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("strassengitter") + c.x * 131 + c.y * 7919
	var mid := lvl.cell_to_world(c)
	var b := W.Builder.new()
	var wide := 2.2
	var deep := 1.1
	# The frame: four dressed stones, the top edge chamfered, set round the slot.
	for side in [-1.0, 1.0]:
		b.frustum(Vector3(0, 0, side * (deep * 0.5 + 0.17)), Vector2(wide + 0.7, 0.34), Vector2(wide + 0.5, 0.26), 0.06, W.vary(STONES[0], rng, 0.07), W.STONE)
		b.frustum(Vector3(side * (wide * 0.5 + 0.17), 0, 0), Vector2(0.34, deep), Vector2(0.26, deep - 0.06), 0.06, W.vary(STONES[1], rng, 0.07), W.STONE)
	# A ring of setts beyond it.
	for i in 14:
		var a := TAU * i / 14.0
		var at := Vector3(cos(a) * (wide * 0.5 + 0.8), 0, sin(a) * (deep * 0.5 + 0.8))
		b.frustum(at, Vector2(0.34, 0.3), Vector2(0.3, 0.26), 0.035, W.vary(STONES[i % STONES.size()], rng, 0.08), W.STONE, Basis.from_euler(Vector3(0, a + rng.randf() * 0.4, 0)))
	b.box(Vector3(0, 0.0, 0), Vector3(wide, 0.03, deep), Color(0.015, 0.02, 0.025), W.IRON)
	# The grating: bars with rounded tops every 9 cm, two cross ribs, a rim, rivets and a lifting eye.
	var bars := 17
	for i in bars:
		var x := -wide * 0.5 + 0.08 + i * (wide - 0.16) / (bars - 1)
		b.frustum(Vector3(x, 0.03, 0), Vector2(0.05, deep - 0.08), Vector2(0.03, deep - 0.08), 0.05, W.vary(IRON, rng, 0.08), W.IRON)
	for z: float in [-deep * 0.5 + 0.04, 0.0, deep * 0.5 - 0.04]:
		b.box(Vector3(0, 0.03, z), Vector3(wide, 0.045, 0.07), W.vary(RUST, rng, 0.1), W.IRON)
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * (wide * 0.5 - 0.035), 0.03, 0), Vector3(0.07, 0.06, deep), W.vary(RUST, rng, 0.1), W.IRON)
		b.cylinder(Vector3(side * (wide * 0.5 - 0.035), 0.09, deep * 0.3), 0.03, 0.022, 0.02, W.vary(IRON, rng, 0.08), W.IRON, 6)
		b.cylinder(Vector3(side * (wide * 0.5 - 0.035), 0.09, -deep * 0.3), 0.03, 0.022, 0.02, W.vary(IRON, rng, 0.08), W.IRON, 6)
	b.cylinder(Vector3(0, 0.075, 0), 0.07, 0.05, 0.03, W.vary(RUST, rng, 0.08), W.IRON, 8)
	# Leaves and silt caught on the bars.
	for i in 6:
		b.frustum(Vector3(rng.randf_range(-wide * 0.4, wide * 0.4), 0.075, rng.randf_range(-deep * 0.35, deep * 0.35)), Vector2(0.16, 0.1), Vector2(0.1, 0.06), 0.01,
				W.vary(StreamFlow.LEAVES[i % StreamFlow.LEAVES.size()], rng, 0.1), W.WOOD, Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)))
	var drain := b.finish(lvl, mid, false)
	# The drain breathes out the sewer's warm air: no snow settles on the iron, the frame or the setts,
	# nor on the street round it (see GRILLE_WARM). A layer of snow over such flat, close-set tops
	# would flicker against them.
	drain.set_meta("no_snow", true)
	lvl.warm_spots.append(Vector4(mid.x, 0.1, mid.z, GRILLE_WARM))


## A manhole: a stone kerb round the shaft, a heavy stone lid on it with iron straps. The lid is
## solid and a station: the hero runs into it and heaves it open, and it stays open (see Sewers.open_hatch).
## The shaft's cell and the way its ladder leans come from Sewers.HATCHES.
static func _hatch(lvl: Outdoor, c: Vector2i) -> void:
	var spec := Sewers.hatch_at(c)
	if spec.is_empty():
		return
	var shaft: Vector3 = Sewers.sketch().cell_world(spec.cell.x, spec.cell.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalluke") + c.x * 131 + c.y * 7919
	var kerb := W.Builder.new()
	var out := HouseSketch.CELL * 0.5 + 0.2
	# The kerb: two courses of dressed slabs round the opening with a chamfered cap, a collar of setts.
	for course in 2:
		var y := course * 0.14
		for side in [-1.0, 1.0]:
			for k in 2:
				var w := (out * 2.0 + 0.4) * 0.5
				var x := (k - 0.5) * w + rng.randf_range(-0.03, 0.03) * (course + 1)
				kerb.frustum(Vector3(side * out, y, x), Vector2(0.4, w - 0.03), Vector2(0.4, w - 0.03), 0.14, W.vary(STONES[(course + k) % STONES.size()], rng, 0.07), W.STONE)
				kerb.frustum(Vector3(x, y, side * out), Vector2(w - 0.03, 0.4), Vector2(w - 0.03, 0.4), 0.14, W.vary(STONES[(course + k + 1) % STONES.size()], rng, 0.07), W.STONE)
	for side in [-1.0, 1.0]:
		kerb.frustum(Vector3(side * out, 0.28, 0), Vector2(0.42, out * 2.0 + 0.44), Vector2(0.3, out * 2.0 + 0.3), 0.04, W.vary(DARK_STONE, rng, 0.06), W.STONE)
		kerb.frustum(Vector3(0, 0.28, side * out), Vector2(out * 2.0 - 0.4, 0.42), Vector2(out * 2.0 - 0.5, 0.3), 0.04, W.vary(DARK_STONE, rng, 0.06), W.STONE)
	for i in 16:
		var a := TAU * i / 16.0
		var r := out + 0.55
		kerb.frustum(Vector3(cos(a) * r, 0, sin(a) * r), Vector2(0.34, 0.3), Vector2(0.3, 0.26), 0.04, W.vary(STONES[i % STONES.size()], rng, 0.08), W.STONE, Basis.from_euler(Vector3(0, a + rng.randf() * 0.4, 0)))
	kerb.finish(lvl, Vector3(shaft.x, 0.0, shaft.z))
	var key := c
	var is_open: bool = Sewers.opened.has(key)
	# The lid, hinged on the side away from the ladder, so that open it stands up against the sky.
	var away: Vector2i = -HouseSketch.DOWN[spec.dir]
	var hinge := Node3D.new()
	hinge.name = "HatchLid"
	hinge.position = Vector3(shaft.x + away.x * (out - 0.2), 0.3, shaft.z + away.y * (out - 0.2))
	lvl.add_child(hinge)
	var lid := W.Builder.new()
	var span := out * 2.0 - 0.4
	var back := Vector3(-away.x, 0, -away.y) * (span * 0.5 + 0.2)
	lid.frustum(back, Vector2(span, span), Vector2(span - 0.14, span - 0.14), 0.16, W.vary(DARK_STONE, rng, 0.05), W.STONE)
	var top := Vector3(0, 0.16, 0)
	# An iron frame round the top edge, straps across the diagonals, a rivet in every corner.
	for side in [-1.0, 1.0]:
		lid.box(back + top + Vector3(side * (span * 0.5 - 0.1), 0, 0), Vector3(0.08, 0.03, span - 0.2), W.vary(IRON, rng, 0.05), W.IRON)
		lid.box(back + top + Vector3(0, 0, side * (span * 0.5 - 0.1)), Vector3(span - 0.2, 0.03, 0.08), W.vary(IRON, rng, 0.05), W.IRON)
		for other in [-1.0, 1.0]:
			lid.cylinder(back + top + Vector3(side * (span * 0.5 - 0.1), 0.03, other * (span * 0.5 - 0.1)), 0.04, 0.03, 0.025, W.vary(RUST, rng, 0.08), W.IRON, 6)
	for diag in [-1.0, 1.0]:
		lid.bar(back + top + Vector3(-span * 0.4, 0.015, -span * 0.4 * diag), back + top + Vector3(span * 0.4, 0.015, span * 0.4 * diag), 0.035, W.vary(IRON, rng, 0.05), W.IRON, 5)
	# The lifting ring: eight short bars round a plate.
	lid.cylinder(back + top, 0.11, 0.1, 0.03, W.vary(RUST, rng, 0.05), W.IRON, 10)
	for i in 8:
		var a := TAU * i / 8.0
		var p0 := back + top + Vector3(cos(a) * 0.17, 0.04, sin(a) * 0.17)
		var p1 := back + top + Vector3(cos(a + TAU / 8.0) * 0.17, 0.04, sin(a + TAU / 8.0) * 0.17)
		lid.bar(p0, p1, 0.018, W.vary(IRON, rng, 0.05), W.IRON, 5)
	# Two hinge straps at the edge it turns on: a long forged leaf along the lid, a knuckle of rolled iron
	# at the pin, a row of rivets and flakes of rust, all of dark, uneven metal (no bright bars).
	var along: Vector3 = Vector3(-away.x, 0, -away.y)
	var across: Vector3 = Vector3(away.y, 0, away.x)
	for side in [-1.0, 1.0]:
		var at: Vector3 = across * side * span * 0.28 + Vector3(0, 0.1, 0)
		var leaf: Vector3 = at + along * 0.22
		lid.frustum(leaf, Vector2(0.4 if away.x != 0 else 0.15, 0.4 if away.y != 0 else 0.15), Vector2(0.37 if away.x != 0 else 0.1, 0.37 if away.y != 0 else 0.1), 0.035, W.vary(HINGE_IRON, rng, 0.12), W.IRON)
		lid.frustum(leaf + along * 0.13 + Vector3(0, 0.02, 0), Vector2(0.12 if away.x != 0 else 0.2, 0.12 if away.y != 0 else 0.2), Vector2(0.1 if away.x != 0 else 0.16, 0.1 if away.y != 0 else 0.16), 0.03, W.vary(RUST, rng, 0.15), W.IRON)
		for k in 3:
			lid.cylinder(leaf + along * (0.12 * (k - 1)) + Vector3(0, 0.035, 0), 0.025, 0.02, 0.018, W.vary(RUST, rng, 0.2), W.IRON, 6)
		lid.cylinder(at + Vector3(0, 0.02, 0), 0.055, 0.05, 0.16, W.vary(HINGE_IRON, rng, 0.1), W.IRON, 8, Basis.from_euler(Vector3(PI * 0.5 if away.x == 0 else 0.0, 0, PI * 0.5 if away.x != 0 else 0.0)))
		lid.cylinder(at + across * side * 0.09 + Vector3(0, 0.02, 0), 0.065, 0.065, 0.03, W.vary(RUST, rng, 0.12), W.IRON, 8, Basis.from_euler(Vector3(PI * 0.5 if away.x == 0 else 0.0, 0, PI * 0.5 if away.x != 0 else 0.0)))
	lid.finish(hinge)
	var shape: CollisionShape3D = lvl._add_box(lvl._walls_body, Vector3(shaft.x, 0.5, shaft.z), Vector3(span + 0.6, 1.0, span + 0.6))
	if is_open:
		hinge.rotation = _lid_turn(away, deg_to_rad(105.0))
		shape.disabled = true
	# The station stays for good: running into the shut lid or clicking the hatch (shut or open) walks up
	# to the head of the ladder ("stand") and climbs down (see Sewers.use).
	var head := HouseSketch.ladder_top(spec.cell.x, spec.cell.y, HouseSketch.LADDER_ORIENTS[spec.dir])
	var stand := Sewers.sketch().cell_world(head.x, head.y)
	lvl.stations.append({"kind": LID, "cell": lvl.world_to_cell(shaft), "pos": Vector3(shaft.x, 0.0, shaft.z), "used": false,
			"touch": 1.9, "hinge": hinge, "shape": shape, "key": key, "away": away, "stand": Vector3(stand.x, 0.0, stand.z)})


## Swings the lid of station `s` shut again and makes it solid (see Sewers._close_later).
static func swing_shut(s: Dictionary) -> void:
	var hinge: Node3D = s.hinge
	if not is_instance_valid(hinge):
		return
	var tween := hinge.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(hinge, "rotation", Vector3.ZERO, 0.6)
	var shape: CollisionShape3D = s.shape
	if is_instance_valid(shape):
		shape.set_deferred("disabled", false)


## The rotation that swings a lid hinged on the side `away` up by `angle`.
static func _lid_turn(away: Vector2i, angle: float) -> Vector3:
	# Away along +x or -x turns about z; along +z or -z about x. The lid lies out from its hinge towards the shaft.
	if away.x != 0:
		return Vector3(0, 0, -angle * away.x)
	return Vector3(angle * away.y, 0, 0)


## Swings the lid of station `s` open (see Sewers.use).
static func swing_open(s: Dictionary) -> void:
	var hinge: Node3D = s.hinge
	if not is_instance_valid(hinge):
		return
	var tween := hinge.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(hinge, "rotation", _lid_turn(s.away, deg_to_rad(105.0)), 0.9)
	var shape: CollisionShape3D = s.shape
	if is_instance_valid(shape):
		shape.set_deferred("disabled", true)
