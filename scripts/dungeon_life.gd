class_name DungeonLife
extends Node3D
## Small things that make a dungeon level feel lived in (and long abandoned):
## a layer of dust that gathers along the walls, bones, broken pottery,
## cobwebs in the corners and on the furniture, cockroaches and spiders that
## crawl about, and water that drips from the ceiling into small puddles.
##
## All of it is decoration: nothing here blocks the way or can be picked up.
## Everything is placed by a random generator seeded with the level's name, so
## a level looks the same every time it is played.

const TILE := Level.TILE
## Where the stone of the walls begins, measured from the middle of a tile.
const WALL_FACE := 1.7
const WALL_HEIGHT := 4.0
## How high webs climb a near wall (see _wall_top): as high as those walls
## once stood, so every web hangs where it always did.
const NEAR_WEB_TOP := 1.2
## The top of the floor tiles; the cobbles stick up a little.
const FLOOR_Y := 0.065
## Dust is batched in squares of this many tiles: the browser renderer lights
## each mesh with only a few lights, so one mesh for a whole level would miss
## most torches.
const DUST_CHUNK := 3
## Tiles that are open floor (no walls, furniture, doors or traps).
const OPEN_FLOOR := ".,cPKMAZwGW"
## Furniture that can carry a cobweb.
const WEBBED := "bxtkoCBL"
## No two cobwebs are nearer than this (seen from above), so they spread
## through the rooms instead of piling up in one spot.
const WEB_SPACING := 2.2
## Cobwebs keep this far from a wall torch: the flame would have burnt them.
const WEB_TORCH_GAP := 1.3
## How many differently spun cobweb images there are.
const WEB_KINDS := 3
## Critters only bother to move when the hero is this close.
const ACTIVE_RANGE := 30.0
## Critters scurry off when the hero comes this close.
const FLEE_RANGE := 3.2
const BONE_SHADER := preload("res://shaders/bone.gdshader")

var level: Level
var _rng := RandomNumberGenerator.new()
var _critters: Array = []
var _drips: Array = []
## The drip puddles on the floor: their middle and the half widths of the
## water across (x) and along (z). A step into one splashes (see in_puddle).
var puddles: Array[Dictionary] = []
var _time := 0.0

static var _dust_tex: Texture2D
static var _drift_tex: Texture2D
static var _web_texs: Array[Texture2D] = []
## Every cobweb on the level: its kind ("corner", "low_corner", "ledge",
## "prop", "prop_wall", "between"), its middle and the four corners of its
## sheet. The tests read it.
var webs: Array[Dictionary] = []
## Cobweb triangles waiting to be built, one SurfaceTool per patch of the
## level and web image (see DUST_CHUNK).
var _web_batches := {}
static var _materials := {}


func _init(owner_level: Level) -> void:
	level = owner_level
	name = "DungeonLife"


func _ready() -> void:
	_rng.seed = hash(level.level_name + ":life")
	var furniture := _furniture_boxes()
	_build_dust()
	_build_clutter()
	_build_furniture_webs(furniture)
	_build_corner_webs()
	_build_ledge_webs()
	_commit_webs()
	_build_drips()
	_spawn_critters()


# --- Tiles ------------------------------------------------------------------

func _is_open(c: Vector2i) -> bool:
	return OPEN_FLOOR.contains(level.cell_char(c))


func _is_wall(c: Vector2i) -> bool:
	return level.cell_char(c) == "#"


func _open_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in level.height:
		for x in level.width:
			if _is_open(Vector2i(x, y)) and not level.grates.has(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells


## A spot on the floor of a tile, pushed toward a wall next to it: dirt and
## rubbish gather at the edges, not in the middle of the way.
func _edge_spot(c: Vector2i) -> Vector3:
	var p := level.cell_to_world(c)
	var off := Vector2(_rng.randf_range(-1.3, 1.3), _rng.randf_range(-1.3, 1.3))
	var walls: Array[Vector2i] = []
	for d in Level.DIRS:
		if _is_wall(c + d):
			walls.append(d)
	if not walls.is_empty():
		var d: Vector2i = walls[_rng.randi() % walls.size()]
		var depth := _rng.randf_range(1.0, 1.45)
		if d.x != 0:
			off.x = d.x * depth
		else:
			off.y = d.y * depth
	return p + Vector3(off.x, FLOOR_Y, off.y)


## Whether a critter may stand on this spot: on open floor and off the walls.
func _free_spot(p: Vector3) -> bool:
	var c := level.world_to_cell(p)
	if not _is_open(c):
		return false
	var local := p - level.cell_to_world(c)
	if absf(local.x) > WALL_FACE - 0.1 and not _is_open(c + Vector2i(int(signf(local.x)), 0)):
		return false
	if absf(local.z) > WALL_FACE - 0.1 and not _is_open(c + Vector2i(0, int(signf(local.z)))):
		return false
	return true


# --- Materials and textures -------------------------------------------------

static func _material(key: String, color: Color, roughness := 0.85) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_materials[key] = m
	return _materials[key]


func _decal_material(key: String, tex: Texture2D) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 1.0
		_materials[key] = m
	return _materials[key]


## The floor dust is laid out by world position, so its patches run on
## across the tiles instead of repeating on each one.
func _dust_material() -> StandardMaterial3D:
	if not _materials.has("dust"):
		var m := _decal_material("dust_base", _dust_texture()).duplicate() as StandardMaterial3D
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / 14.0
		_materials["dust"] = m
	return _materials["dust"]


## Without mipmaps, so the thin threads do not fade away with the distance.
func _web_material(kind: int) -> StandardMaterial3D:
	var key := "web%d" % kind
	if not _materials.has(key):
		var m := _decal_material("web_base%d" % kind, _web_texture(kind)).duplicate() as StandardMaterial3D
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_materials[key] = m
	return _materials[key]


## Soft, patchy grey-brown dust that tiles seamlessly.
static func _dust_texture() -> Texture2D:
	if _dust_tex == null:
		_dust_tex = ImageTexture.create_from_image(_noise_image(7, 0.035, 0.0))
	return _dust_tex


## Dust that is thick at one edge (against the wall) and thins out.
static func _drift_texture() -> Texture2D:
	if _drift_tex == null:
		_drift_tex = ImageTexture.create_from_image(_noise_image(11, 0.06, 1.0))
	return _drift_tex


static func _noise_image(noise_seed: int, frequency: float, edge: float) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var size := 128
	var src := noise.get_seamless_image(size, size)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		# With an edge, the dust is thickest at the top row of the image.
		var gradient := 1.0 if edge == 0.0 else pow(1.0 - float(y) / (size - 1), 1.6)
		for x in size:
			var n := src.get_pixel(x, y).r
			var a := smoothstep(0.35, 0.9, n) * 0.42
			if edge > 0.0:
				a = clampf(a * 0.6 + gradient * 0.55, 0.0, 1.0) * gradient
			var grain := 0.92 + 0.16 * fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
			img.set_pixel(x, y, Color(0.66 * grain, 0.62 * grain, 0.55 * grain, a))
	return img


## A cobweb in a corner: threads fan out from the corner of the image (its
## top left) and sagging rings of silk join them. Three kinds: an ordinary
## web (0), a dense one with many close rings (1) and an old, torn one with
## gaps in its rings and a few broken threads (2).
static func _web_texture(kind := 0) -> Texture2D:
	if _web_texs.is_empty():
		for k in WEB_KINDS:
			_web_texs.append(ImageTexture.create_from_image(_web_image(k)))
	return _web_texs[kind]


static func _web_image(kind: int) -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711 + kind * 97
	var spokes: Array[float] = []
	var count: int = [7, 9, 6][kind]
	for i in count:
		spokes.append(lerpf(0.04, PI * 0.5 - 0.04, float(i) / (count - 1)) + rng.randf_range(-0.05, 0.05))
	var reach: Array[float] = []
	for a in spokes:
		# A torn web has a few threads that snapped short.
		var r := size * 1.05 if kind != 2 or rng.randf() < 0.6 else size * rng.randf_range(0.45, 0.8)
		reach.append(r)
		_line(img, Vector2.ZERO, Vector2(cos(a), sin(a)) * r, 0.95)
	var ring_r: float = [22.0, 14.0, 26.0][kind]
	var grow: Vector2 = [Vector2(1.22, 1.32), Vector2(1.14, 1.22), Vector2(1.25, 1.4)][kind]
	while ring_r < size * 0.98:
		for i in count - 1:
			if ring_r > minf(reach[i], reach[i + 1]):
				continue
			if kind == 2 and rng.randf() < 0.3:
				continue
			var a0 := spokes[i]
			var a1 := spokes[i + 1]
			var r0 := ring_r * rng.randf_range(0.95, 1.05)
			var r1 := ring_r * rng.randf_range(0.95, 1.05)
			var p0 := Vector2(cos(a0), sin(a0)) * r0
			var p1 := Vector2(cos(a1), sin(a1)) * r1
			# Each strand sags a little toward the corner.
			var mid := (p0 + p1) * 0.5 * 0.9
			_line(img, p0, mid, 0.85)
			_line(img, mid, p1, 0.85)
		ring_r *= rng.randf_range(grow.x, grow.y)
	if kind == 2:
		# A loose strand that hangs down from the torn edge.
		var from := Vector2(cos(spokes[2]), sin(spokes[2])) * size * 0.55
		_line(img, from, from + Vector2(rng.randf_range(10, 30), size * 0.4), 0.7)
	return img


static func _line(img: Image, a: Vector2, b: Vector2, alpha: float) -> void:
	var steps := int(a.distance_to(b)) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		# Three pixels wide, so the silk still shows from the camera far above.
		for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var x := int(p.x) + o.x
			var y := int(p.y) + o.y
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var old := img.get_pixel(x, y).a
			img.set_pixel(x, y, Color(0.92, 0.92, 0.9, maxf(old, alpha)))


# --- Dust ---------------------------------------------------------------------

func _build_dust() -> void:
	var chunks := {}
	for c in _open_cells():
		var key := Vector2i(floori(c.x / float(DUST_CHUNK)), floori(c.y / float(DUST_CHUNK)))
		if not chunks.has(key):
			chunks[key] = {"floor": [], "drift": []}
		var p := level.cell_to_world(c)
		chunks[key].floor.append([Transform3D(Basis(), p + Vector3(0, FLOOR_Y + 0.012, 0)), Color.WHITE])
		# A thicker drift of dust along every wall of the tile.
		for d in Level.DIRS:
			if not _is_wall(c + d):
				continue
			var yaw := atan2(float(d.x), float(d.y))
			var basis := Basis(Vector3.UP, yaw)
			var at := p + Vector3(d.x, 0, d.y) * (WALL_FACE - 0.6) + Vector3(0, FLOOR_Y + 0.018, 0)
			chunks[key].drift.append([Transform3D(basis, at), Color(1, 1, 1, _rng.randf_range(0.7, 1.0))])
	var floor_quad := PlaneMesh.new()
	floor_quad.size = Vector2(TILE, TILE)
	var drift_quad := PlaneMesh.new()
	# The thick edge of the texture faces the wall (+z of the turned quad).
	drift_quad.size = Vector2(TILE, 1.2)
	drift_quad.orientation = PlaneMesh.FACE_Y
	for key in chunks:
		_add_batch(floor_quad, _dust_material(), chunks[key].floor)
		_add_batch(drift_quad, _decal_material("drift", _drift_texture()), chunks[key].drift, true)


func _add_batch(mesh: Mesh, mat: Material, items: Array, flip_v := false) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		var t: Transform3D = items[i][0]
		if flip_v:
			# The plane's v runs toward -z; turn it so the thick edge meets the wall.
			t.basis = t.basis * Basis(Vector3.UP, PI)
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- Bones and pottery --------------------------------------------------------

func _build_clutter() -> void:
	for c in _open_cells():
		if c == level.start_cell:
			continue
		var roll := _rng.randf()
		if roll < 0.09:
			bone_pile(self, _edge_spot(c), _rng)
		elif roll < 0.16:
			broken_pot(self, _edge_spot(c), _rng)
		elif roll < 0.24:
			pebbles(self, _edge_spot(c), _rng)


## Old, dirty bone: yellowed, stained, with earth on the side it lies on
## (shaders/bone.gdshader). One material, shared by every bone and skull.
static func _bone_material() -> Material:
	if not _materials.has("bone"):
		var m := ShaderMaterial.new()
		m.shader = BONE_SHADER
		_materials["bone"] = m
	return _materials["bone"]


static func bone(length: float) -> Node3D:
	var piece := Node3D.new()
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = length
	cyl.radial_segments = 6
	cyl.rings = 1
	shaft.mesh = cyl
	shaft.rotation.z = PI * 0.5
	shaft.material_override = _bone_material()
	piece.add_child(shaft)
	var knob := SphereMesh.new()
	knob.radius = 0.075
	knob.height = 0.15
	knob.radial_segments = 6
	knob.rings = 3
	for end: float in [-0.5, 0.5]:
		for side: int in [-1, 1]:
			var k := MeshInstance3D.new()
			k.mesh = knob
			k.position = Vector3(end * length, 0, side * 0.045)
			k.material_override = _bone_material()
			piece.add_child(k)
	return piece


static func skull() -> Node3D:
	var piece := Node3D.new()
	var head := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.2
	dome.height = 0.36
	dome.radial_segments = 10
	dome.rings = 6
	head.mesh = dome
	head.scale = Vector3(1.0, 0.95, 1.15)
	head.position.y = 0.17
	head.material_override = _bone_material()
	piece.add_child(head)
	var jaw := MeshInstance3D.new()
	var jaw_box := BoxMesh.new()
	jaw_box.size = Vector3(0.24, 0.1, 0.16)
	jaw.mesh = jaw_box
	jaw.position = Vector3(0, 0.05, 0.13)
	jaw.material_override = _bone_material()
	piece.add_child(jaw)
	var socket := SphereMesh.new()
	socket.radius = 0.055
	socket.height = 0.09
	socket.radial_segments = 6
	socket.rings = 3
	for side: int in [-1, 1]:
		var eye := MeshInstance3D.new()
		eye.mesh = socket
		eye.position = Vector3(side * 0.08, 0.2, 0.19)
		eye.material_override = _material("socket", Color(0.05, 0.04, 0.03), 1.0)
		piece.add_child(eye)
	return piece


## A few bones on `parent` at `at`, sometimes with a skull.
static func bone_pile(parent: Node3D, at: Vector3, rng: RandomNumberGenerator, skull_chance := 0.45) -> void:
	var pile := Node3D.new()
	pile.position = at + Vector3(0, 0.04, 0)
	pile.rotation.y = rng.randf() * TAU
	parent.add_child(pile)
	for i in rng.randi_range(2, 5):
		var b := bone(rng.randf_range(0.35, 0.75))
		b.position = Vector3(rng.randf_range(-0.45, 0.45), 0.02 + i * 0.03, rng.randf_range(-0.45, 0.45))
		b.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * TAU, 0)
		pile.add_child(b)
	if rng.randf() < skull_chance:
		var head := skull()
		head.position = Vector3(rng.randf_range(-0.3, 0.3), -0.03, rng.randf_range(-0.3, 0.3))
		head.rotation = Vector3(rng.randf_range(-0.35, 0.2), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		pile.add_child(head)


## A curved piece of a clay pot's wall.
static func _shard_mesh(radius: float, span: float, tall: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 5
	for i in steps:
		var a0 := -span * 0.5 + span * i / steps
		var a1 := -span * 0.5 + span * (i + 1) / steps
		var p00 := Vector3(sin(a0) * radius, 0, cos(a0) * radius)
		var p10 := Vector3(sin(a1) * radius, 0, cos(a1) * radius)
		var top0 := tall * (0.7 + 0.3 * sin(a0 * 9.0 + radius * 20.0))
		var top1 := tall * (0.7 + 0.3 * sin(a1 * 9.0 + radius * 20.0))
		var p01 := p00 + Vector3(0, top0, 0)
		var p11 := p10 + Vector3(0, top1, 0)
		for v in [p00, p10, p11, p00, p11, p01]:
			st.set_normal(Vector3(v.x, 0, v.z).normalized())
			st.add_vertex(v)
	return st.commit()


static func _clay_material() -> StandardMaterial3D:
	if not _materials.has("clay"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.28, 0.17)
		m.roughness = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["clay"] = m
	return _materials["clay"]


static func broken_pot(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var spot := Node3D.new()
	spot.position = at
	spot.rotation.y = rng.randf() * TAU
	parent.add_child(spot)
	var radius := rng.randf_range(0.26, 0.36)
	if rng.randf() < 0.6:
		# The bottom of the pot still stands, its rim broken off.
		var base := MeshInstance3D.new()
		base.mesh = _shard_mesh(radius, TAU, rng.randf_range(0.18, 0.3))
		base.material_override = _clay_material()
		spot.add_child(base)
		var bottom := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.03
		disc.radial_segments = 12
		bottom.mesh = disc
		bottom.position.y = 0.02
		bottom.material_override = _clay_material()
		spot.add_child(bottom)
	for i in rng.randi_range(3, 6):
		var shard := MeshInstance3D.new()
		shard.mesh = _shard_mesh(radius, rng.randf_range(0.5, 1.3), rng.randf_range(0.12, 0.28))
		shard.material_override = _clay_material()
		var dist := rng.randf_range(0.35, 1.0)
		var dir := rng.randf() * TAU
		shard.position = Vector3(cos(dir) * dist, 0.03, sin(dir) * dist)
		# Most pieces lie on their side.
		shard.rotation = Vector3(rng.randf_range(1.2, 1.9) * (1 if rng.randf() < 0.5 else -1), rng.randf() * TAU, 0)
		spot.add_child(shard)


## A few loose stones fallen from the walls.
static func pebbles(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var stone := SphereMesh.new()
	stone.radius = 0.1
	stone.height = 0.14
	stone.radial_segments = 6
	stone.rings = 3
	for i in rng.randi_range(3, 7):
		var s := MeshInstance3D.new()
		s.mesh = stone
		s.scale = Vector3.ONE * rng.randf_range(0.5, 1.6)
		s.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		s.position = at + Vector3(rng.randf_range(-0.6, 0.6), 0.03, rng.randf_range(-0.6, 0.6))
		s.material_override = _material("pebble", Color(0.36, 0.33, 0.3), 0.95)
		parent.add_child(s)


# --- Cobwebs ------------------------------------------------------------------

## A sheet of web with its corner (where the threads meet) at `corner` and
## its two straight edges running to `a` and `b`; the far corner closes it.
## It is only spun when it keeps its distance from the other webs and from
## torches, and stays clear of the paths (see _web_fits). Returns whether it
## was spun.
func _web(web_kind: String, corner: Vector3, a: Vector3, b: Vector3) -> bool:
	var far := corner + (a - corner) + (b - corner)
	var mid := (corner + a + b + far) * 0.25
	if not _web_fits(web_kind, mid, [corner, a, b, far]):
		return false
	webs.append({"kind": web_kind, "mid": mid, "points": [corner, a, b, far]})
	# Each web gets one of the images, sometimes mirrored, and an age: old
	# webs are greyer and thinner.
	var image := _rng.randi() % WEB_KINDS
	if _rng.randf() < 0.5:
		var swap := a
		a = b
		b = swap
	var grey := _rng.randf_range(0.72, 1.0)
	var alpha := _rng.randf_range(0.75, 1.0)
	var cell := level.world_to_cell(mid)
	var key := Vector3i(floori(cell.x / float(DUST_CHUNK)), floori(cell.y / float(DUST_CHUNK)), image)
	if not _web_batches.has(key):
		var fresh := SurfaceTool.new()
		fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
		_web_batches[key] = fresh
	var st: SurfaceTool = _web_batches[key]
	var n := (a - corner).cross(b - corner).normalized()
	# The square image holds a quarter circle: map the sheet onto its two
	# straight edges and close it with the far corner.
	for v in [[corner, Vector2(0, 0)], [a, Vector2(1, 0)], [far, Vector2(1, 1)], [corner, Vector2(0, 0)], [far, Vector2(1, 1)], [b, Vector2(0, 1)]]:
		st.set_normal(n)
		st.set_color(Color(grey, grey, grey * 0.97, alpha * _rng.randf_range(0.85, 1.0)))
		st.set_uv(v[1])
		st.add_vertex(v[0])
	return true


## Whether a web may hang here: far enough from every other web and from
## the torches, and not over a floor grate, a door, a trap or anything else
## the hero must see clearly. Webs that reach down to the floor also keep
## out of corridors, so they never lie across the way.
func _web_fits(web_kind: String, mid: Vector3, points: Array) -> bool:
	var flat := Vector2(mid.x, mid.z)
	for w in webs:
		if flat.distance_to(Vector2(w.mid.x, w.mid.z)) < WEB_SPACING:
			return false
	for spot: Vector3 in level._torch_spots:
		if flat.distance_to(Vector2(spot.x, spot.z)) < WEB_TORCH_GAP:
			return false
	for p: Vector3 in points:
		var c := level.world_to_cell(p)
		if level.grates.has(c):
			return false
		var ch := level.cell_char(c)
		if not (_is_open(c) or _is_wall(c) or WEBBED.contains(ch)):
			return false
		if p.y < 0.6 and _is_open(c) and _is_corridor(c) and web_kind != "low_corner":
			return false
	return true


## A tile with walls on two opposite sides: a passage one tile wide.
func _is_corridor(c: Vector2i) -> bool:
	return (_is_wall(c + Vector2i(1, 0)) and _is_wall(c + Vector2i(-1, 0))) \
		or (_is_wall(c + Vector2i(0, 1)) and _is_wall(c + Vector2i(0, -1)))


## How high webs may climb the wall at `c`: the walls on the near side of a
## room turn see-through in front of the hero (see WallFade), so webs keep
## to the bottom of them instead of hanging in the air.
func _wall_top(c: Vector2i) -> float:
	return NEAR_WEB_TOP if level._is_low_wall(c) else WALL_HEIGHT


func _commit_webs() -> void:
	for key: Vector3i in _web_batches:
		var mi := MeshInstance3D.new()
		mi.mesh = (_web_batches[key] as SurfaceTool).commit()
		mi.material_override = _web_material(key.z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_web_batches.clear()


## Webs where two walls meet: mostly up under the top of the walls, some
## down in the corner on the floor. Where one of the walls is a near one,
## the web stays low (see _wall_top).
func _build_corner_webs() -> void:
	for c in _open_cells():
		for d: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			if not (_is_wall(c + Vector2i(d.x, 0)) and _is_wall(c + Vector2i(0, d.y))):
				continue
			if _rng.randf() > 0.85:
				continue
			var p := level.cell_to_world(c)
			var top := minf(_wall_top(c + Vector2i(d.x, 0)), _wall_top(c + Vector2i(0, d.y)))
			var base := p + Vector3(d.x * WALL_FACE, 0, d.y * WALL_FACE)
			if top > 2.0 and _rng.randf() < 0.75:
				var corner := base + Vector3(0, _rng.randf_range(2.6, 3.6), 0)
				var size := _rng.randf_range(1.2, 2.0)
				var drop := _rng.randf_range(0.4, 1.0)
				if _web("corner", corner, corner + Vector3(-d.x * size, -drop, 0), corner + Vector3(0, -drop, -d.y * size)) \
						and _rng.randf() < 0.4:
					_hanging_spider(corner + Vector3(-d.x * size * 0.4, -drop * 0.4, -d.y * size * 0.4))
			else:
				# Low in the corner, the threads climb both walls from the floor.
				var corner := base + Vector3(0, FLOOR_Y, 0)
				var rise := minf(top - 0.1, _rng.randf_range(0.7, 1.2))
				var size := _rng.randf_range(0.8, 1.3)
				_web("low_corner", corner, corner + Vector3(-d.x * size, rise, 0), corner + Vector3(0, rise, -d.y * size))


## Webs under the ceiling along a plain stretch of wall: spun from the top
## of the wall out into the room, hanging a little.
func _build_ledge_webs() -> void:
	for c in _open_cells():
		for d in Level.DIRS:
			var w: Vector2i = c + d
			if not _is_wall(w) or level._is_low_wall(w) or _rng.randf() > 0.45:
				continue
			var inward := Vector3(-d.x, 0, -d.y)
			var along := Vector3(absf(d.y), 0, absf(d.x)) * (1.0 if _rng.randf() < 0.5 else -1.0)
			var corner := level.cell_to_world(c) + Vector3(d.x, 0, d.y) * WALL_FACE \
				+ along * _rng.randf_range(-1.0, 0.4) + Vector3(0, _rng.randf_range(3.3, 3.85), 0)
			var span := _rng.randf_range(1.1, 1.8)
			var reach := _rng.randf_range(0.7, 1.1)
			var drop := _rng.randf_range(0.4, 0.9)
			if _web("ledge", corner, corner + along * span + Vector3(0, -0.15, 0), corner + inward * reach + Vector3(0, -drop, 0)) \
					and _rng.randf() < 0.15:
				_hanging_spider(corner + inward * reach * 0.5 + along * span * 0.3 + Vector3(0, -drop * 0.5, 0))


## The bounds of every piece of furniture, found from the meshes the level
## placed on its tile.
func _furniture_boxes() -> Dictionary:
	var boxes := {}
	for mi: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		var mid := box.get_center()
		var c := level.world_to_cell(mid)
		if not WEBBED.contains(level.cell_char(c)):
			continue
		if box.size.x > TILE * 0.95 or box.size.z > TILE * 0.95 or box.end.y < 0.4:
			continue
		boxes[c] = boxes[c].merge(box) if boxes.has(c) else box
	return boxes


## One web for most pieces of furniture, spun in one of several ways: down
## one side, in the nook where it meets the floor, up to the wall behind it,
## or across to the furniture next to it.
func _build_furniture_webs(boxes: Dictionary) -> void:
	for c: Vector2i in boxes:
		if _rng.randf() > 0.95:
			continue
		var box: AABB = boxes[c]
		var ways: Array[Callable] = [_web_down_side.bind(box), _web_in_nook.bind(box)]
		for d in Level.DIRS:
			if _is_wall(c + d) and not level._is_low_wall(c + d):
				ways.append(_web_to_wall.bind(box, c, d))
			if boxes.has(c + d):
				ways.append(_web_between.bind(box, boxes[c + d], d))
		# Shuffled with the level's own generator, so the webs hang the same
		# way every time the level is played.
		for i in range(ways.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var swap := ways[i]
			ways[i] = ways[j]
			ways[j] = swap
		# If the first way does not fit (too near another web, over a grate),
		# the next one is tried.
		for way in ways:
			if way.call():
				break


func _box_corner(box: AABB) -> Array:
	var sx: int = _rng.randi() % 2
	var sz: int = _rng.randi() % 2
	var corner := Vector3([box.position.x, box.end.x][sx], FLOOR_Y, [box.position.z, box.end.z][sz])
	var out := Vector3(-1.0 if sx == 0 else 1.0, 0, -1.0 if sz == 0 else 1.0)
	return [corner, out]


## Strung between the top edge and the floor, down one side.
func _web_down_side(box: AABB) -> bool:
	if box.size.y <= 0.8:
		return false
	var top := minf(box.end.y, 3.0)
	var pick := _box_corner(box)
	var corner: Vector3 = pick[0]
	var out: Vector3 = pick[1]
	var size := _rng.randf_range(1.0, 1.5)
	var along := Vector3(out.x, 0, 0) if _rng.randf() < 0.5 else Vector3(0, 0, out.z)
	return _web("prop", corner + Vector3(0, top - 0.03, 0), corner + along * size * 0.9, corner + Vector3(0, top - 0.03, 0) + along * size)


## In the nook where the furniture meets the floor.
func _web_in_nook(box: AABB) -> bool:
	var top := minf(box.end.y, 3.0)
	var pick := _box_corner(box)
	var corner: Vector3 = pick[0]
	var out: Vector3 = pick[1]
	var size := _rng.randf_range(1.0, 1.5)
	return _web("prop", corner, corner + Vector3(0, minf(top, size), 0), corner + out.normalized() * size * 1.2)


## From the wall behind the furniture down onto its top.
func _web_to_wall(box: AABB, c: Vector2i, d: Vector2i) -> bool:
	var top := minf(box.end.y, 3.0)
	var face := level.cell_to_world(c) + Vector3(d.x, 0, d.y) * WALL_FACE
	# The edge of the top that faces the wall, and how far it is from it.
	var edge_x := box.end.x if d.x > 0 else box.position.x
	var edge_z := box.end.z if d.y > 0 else box.position.z
	var gap := absf(face.x - edge_x) if d.x != 0 else absf(face.z - edge_z)
	if gap > 1.6:
		return false
	var side := 0 if _rng.randf() < 0.5 else 1
	var lateral := Vector3(absf(d.y), 0, absf(d.x))
	var inward := lateral * (1.0 if side == 0 else -1.0)
	var end_at := Vector3([box.position.x, box.end.x][side], 0, [box.position.z, box.end.z][side])
	var on_wall := Vector3(face.x if d.x != 0 else end_at.x, 0, face.z if d.y != 0 else end_at.z)
	var on_top := Vector3(edge_x if d.x != 0 else end_at.x, top - 0.02, edge_z if d.y != 0 else end_at.z)
	var high := top + _rng.randf_range(0.5, 1.0)
	var corner := on_wall + Vector3(0, high, 0)
	var size := minf(_rng.randf_range(0.8, 1.2), box.size.dot(lateral))
	return _web("prop_wall", corner, on_top, corner + inward * size + Vector3(0, -0.3, 0))


## Across the gap to the furniture on the next tile, from top to top.
func _web_between(box: AABB, other: AABB, d: Vector2i) -> bool:
	var top := minf(minf(box.end.y, other.end.y), 3.0) - 0.03
	var lateral := Vector3(absf(d.y), 0, absf(d.x))
	var from := (box.end if d.x > 0 or d.y > 0 else box.position).dot(Vector3(absf(d.x), 0, absf(d.y)))
	var to := (other.position if d.x > 0 or d.y > 0 else other.end).dot(Vector3(absf(d.x), 0, absf(d.y)))
	var gap := absf(to - from)
	if gap < 0.3 or gap > 2.6 or top < 0.5:
		return false
	# Along one of the two long edges the pieces share.
	var lo := maxf(box.position.dot(lateral), other.position.dot(lateral))
	var hi := minf(box.end.dot(lateral), other.end.dot(lateral))
	if hi - lo < 0.3:
		return false
	var at := lo if _rng.randf() < 0.5 else hi
	var axis := Vector3(absf(d.x), 0, absf(d.y))
	var corner := axis * from + lateral * at + Vector3(0, top, 0)
	var across := axis * to + lateral * at + Vector3(0, top, 0)
	return _web("between", corner, across, corner + Vector3(0, -minf(top, _rng.randf_range(0.6, 1.2)), 0))


# --- Dripping water -----------------------------------------------------------

func _build_drips() -> void:
	var cells := _open_cells()
	cells.erase(level.start_cell)
	if cells.is_empty():
		return
	var count := clampi(cells.size() / 45 + 1, 1, 3)
	for i in count:
		var c: Vector2i = cells[_rng.randi() % cells.size()]
		var p := level.cell_to_world(c) + Vector3(_rng.randf_range(-1.0, 1.0), FLOOR_Y, _rng.randf_range(-1.0, 1.0))
		var radius := _build_puddle(p)
		# The water's rim wobbles between 0.74 and 1.06 of its radius; a foot
		# well inside the mean edge is in the water.
		puddles.append({"pos": p, "rx": radius * 1.25 * 0.9, "rz": radius * 0.9, "drip": _drips.size()})
		var drop := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.05
		ball.height = 0.16
		ball.radial_segments = 6
		ball.rings = 3
		drop.mesh = ball
		drop.material_override = _water_material()
		drop.visible = false
		add_child(drop)
		var ripple := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.95
		ring.outer_radius = 1.0
		ring.rings = 16
		ring.ring_segments = 3
		ripple.mesh = ring
		ripple.material_override = _ripple_material()
		ripple.position = p + Vector3(0, 0.03, 0)
		ripple.scale = Vector3(0.1, 0.01, 0.1)
		ripple.visible = false
		add_child(ripple)
		_drips.append({"pos": p, "cell": c, "drop": drop, "ripple": ripple, "wait": _rng.randf_range(0.5, 3.0), "fall": -1.0, "wave": -1.0})


func _water_material() -> StandardMaterial3D:
	if not _materials.has("water"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.24, 0.27, 0.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic_specular = 1.0
		m.roughness = 0.04
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["water"] = m
	return _materials["water"]


func _wet_material() -> StandardMaterial3D:
	if not _materials.has("wet"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.08, 0.07, 0.06, 0.4)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.35
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["wet"] = m
	return _materials["wet"]


func _ripple_material() -> StandardMaterial3D:
	if not _materials.has("ripple"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.76, 0.8, 0.22)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials["ripple"] = m
	return _materials["ripple"]


## A small, irregular puddle with a dark wet rim around it. Gives back the
## radius of its water.
func _build_puddle(at: Vector3) -> float:
	var radius := _rng.randf_range(0.6, 0.9)
	for layer in [[radius * 1.35, 0.01, _wet_material()], [radius, 0.02, _water_material()]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		var steps := 28
		var rim: Array[Vector3] = []
		var wobble := _rng.randf() * TAU
		for i in steps:
			var a := TAU * i / steps
			var r: float = layer[0] * (0.8 + 0.2 * sin(a * 3.0 + wobble) + 0.06 * sin(a * 7.0 + wobble * 3.0))
			rim.append(Vector3(cos(a) * r * 1.25, 0, sin(a) * r))
		for i in steps:
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(rim[(i + 1) % steps])
			st.add_vertex(rim[i])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = layer[2]
		mi.position = at + Vector3(0, layer[1], 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	return radius


## The drip puddle a spot on the floor lies in, or an empty one.
func puddle_at(p: Vector3) -> Dictionary:
	for pd in puddles:
		var d: Vector3 = p - pd.pos
		if absf(d.y) > 0.5:
			continue
		var u: float = d.x / pd.rx
		var v: float = d.z / pd.rz
		if u * u + v * v <= 1.0:
			return pd
	return {}


## Whether a spot on the floor is in a drip puddle.
func in_puddle(p: Vector3) -> bool:
	return not puddle_at(p).is_empty()


## A foot lands in a drip puddle: its water rings out from the step.
func splash(at: Vector3) -> void:
	var pd := puddle_at(at)
	if pd.is_empty():
		return
	var d: Dictionary = _drips[pd.drip]
	d.ripple.position = Vector3(at.x, pd.pos.y + 0.03, at.z)
	d.wave = 0.0


func _update_drips(delta: float, hero: Vector3) -> void:
	for d in _drips:
		var near: bool = _flat(d.pos, hero) < ACTIVE_RANGE
		if d.fall >= 0.0:
			d.fall += delta
			var fall: float = d.fall
			var y := WALL_HEIGHT - 4.9 * fall * fall
			d.drop.position = d.pos + Vector3(0, maxf(y, 0.0), 0)
			d.drop.visible = level.fog.is_cell_visible(d.cell)
			if y <= 0.0:
				d.fall = -1.0
				d.drop.visible = false
				d.ripple.position = d.pos + Vector3(0, 0.03, 0)
				d.wave = 0.0
				if near:
					Sfx.play(self, "drip", -4.0, d.pos, _rng.randf_range(0.85, 1.2))
		elif near:
			d.wait -= delta
			if d.wait <= 0.0:
				d.wait = _rng.randf_range(1.2, 4.0)
				d.fall = 0.0
		if d.wave >= 0.0:
			d.wave += delta
			var k: float = d.wave / 0.9
			d.ripple.visible = k < 1.0 and level.fog.is_cell_visible(d.cell)
			d.ripple.scale = Vector3(0.1 + k * 0.6, 0.01, 0.1 + k * 0.6)
			d.ripple.transparency = k
			if k >= 1.0:
				d.wave = -1.0


# --- Critters -----------------------------------------------------------------

func _spawn_critters() -> void:
	var cells := _open_cells()
	cells.erase(level.start_cell)
	if cells.is_empty():
		return
	var roaches := clampi(cells.size() / 10, 2, 20)
	var spiders := clampi(cells.size() / 28, 1, 7)
	for i in roaches + spiders:
		var c: Vector2i = cells[_rng.randi() % cells.size()]
		var p := _edge_spot(c)
		if not _free_spot(p):
			p = level.cell_to_world(c) + Vector3(0, FLOOR_Y, 0)
		var spider := i >= roaches
		var node := _spider_model() if spider else _roach_model()
		node.position = p
		node.rotation.y = _rng.randf() * TAU
		add_child(node)
		_critters.append({
			"node": node, "spider": spider, "target": p, "wait": _rng.randf_range(0.0, 3.0),
			"speed": 0.0, "legs": node.get_meta("legs"), "step": _rng.randf() * TAU,
		})


func _leg(parent: Node3D, from: Vector3, yaw: float, length: float, mat: Material, legs: Array) -> void:
	var pivot := Node3D.new()
	pivot.position = from
	pivot.rotation.y = yaw
	pivot.set_meta("yaw", yaw)
	parent.add_child(pivot)
	var upper := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length * 0.55, 0.02, 0.02)
	upper.mesh = box
	upper.position = Vector3(length * 0.25, 0.05, 0)
	upper.rotation.z = 0.5
	upper.material_override = mat
	pivot.add_child(upper)
	var lower := MeshInstance3D.new()
	var box2 := BoxMesh.new()
	box2.size = Vector3(length * 0.55, 0.018, 0.018)
	lower.mesh = box2
	lower.position = Vector3(length * 0.68, 0.04, 0)
	lower.rotation.z = -0.7
	lower.material_override = mat
	pivot.add_child(lower)
	legs.append(pivot)


## A cockroach: a flat, glossy brown oval with six legs and long feelers.
## Larger than life, so it can be seen from the camera high above.
func _roach_model() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var shell := MeshInstance3D.new()
	var oval := SphereMesh.new()
	oval.radius = 0.14
	oval.height = 0.12
	oval.radial_segments = 10
	oval.rings = 5
	shell.mesh = oval
	shell.scale = Vector3(1.0, 1.0, 1.9)
	shell.position.y = 0.08
	shell.material_override = _material("roach", Color(0.28, 0.13, 0.05), 0.3)
	body.add_child(shell)
	var head := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.07
	dot.height = 0.09
	dot.radial_segments = 8
	dot.rings = 4
	head.mesh = dot
	head.position = Vector3(0, 0.07, 0.27)
	head.material_override = _material("roach_head", Color(0.12, 0.06, 0.03), 0.4)
	body.add_child(head)
	var dark := _material("roach_leg", Color(0.15, 0.07, 0.03), 0.6)
	for side: int in [-1, 1]:
		var feeler := MeshInstance3D.new()
		var thin := BoxMesh.new()
		thin.size = Vector3(0.012, 0.012, 0.42)
		feeler.mesh = thin
		feeler.position = Vector3(side * 0.07, 0.09, 0.48)
		feeler.rotation.y = side * 0.35
		feeler.material_override = dark
		body.add_child(feeler)
	var legs := []
	for i in 3:
		for side: int in [-1, 1]:
			_leg(body, Vector3(side * 0.08, 0.02, 0.12 - i * 0.12), (0.0 if side > 0 else PI) + side * (i - 1) * -0.5, 0.32, dark, legs)
	root.set_meta("legs", legs)
	return root


## A spider: a round, hairy-dark body and eight long, bent legs.
func _spider_model() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var mat := _material("spider", Color(0.09, 0.08, 0.08), 0.9)
	var belly := MeshInstance3D.new()
	var round := SphereMesh.new()
	round.radius = 0.16
	round.height = 0.26
	round.radial_segments = 10
	round.rings = 5
	belly.mesh = round
	belly.scale = Vector3(1.0, 1.0, 1.25)
	belly.position = Vector3(0, 0.14, -0.15)
	belly.material_override = mat
	body.add_child(belly)
	var front := MeshInstance3D.new()
	var small := SphereMesh.new()
	small.radius = 0.1
	small.height = 0.15
	small.radial_segments = 8
	small.rings = 4
	front.mesh = small
	front.position = Vector3(0, 0.11, 0.08)
	front.material_override = mat
	body.add_child(front)
	# A pale mark on its back.
	var mark := MeshInstance3D.new()
	var spot := SphereMesh.new()
	spot.radius = 0.06
	spot.height = 0.04
	mark.mesh = spot
	mark.position = Vector3(0, 0.27, -0.16)
	mark.material_override = _material("spider_mark", Color(0.55, 0.12, 0.08), 0.7)
	body.add_child(mark)
	var legs := []
	for i in 4:
		for side: int in [-1, 1]:
			var yaw := (0.0 if side > 0 else PI) + side * (i - 1.5) * -0.45
			_leg(body, Vector3(side * 0.06, 0.08, 0.12 - i * 0.06), yaw, 0.5, mat, legs)
	root.set_meta("legs", legs)
	return root


## A spider that lowers itself from its web on a thread and climbs back up.
func _hanging_spider(anchor: Vector3) -> void:
	var node := _spider_model()
	node.scale = Vector3.ONE * 0.8
	node.position = anchor
	node.rotation = Vector3(-PI * 0.5, _rng.randf() * TAU, 0)
	add_child(node)
	var thread := MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(0.012, 1.0, 0.012)
	thread.mesh = line
	thread.material_override = _material("thread", Color(0.85, 0.85, 0.82), 1.0)
	add_child(thread)
	_critters.append({
		"node": node, "hanging": true, "anchor": anchor, "thread": thread,
		"phase": _rng.randf() * TAU, "rate": _rng.randf_range(0.15, 0.3),
		"legs": node.get_meta("legs"), "step": 0.0,
	})


func _update_critters(delta: float, hero: Vector3) -> void:
	for cr in _critters:
		var node: Node3D = cr.node
		if _flat(node.position, hero) > ACTIVE_RANGE:
			node.visible = false
			if cr.has("thread"):
				cr.thread.visible = false
			continue
		var seen := level.fog.is_cell_visible(level.world_to_cell(node.position))
		node.visible = seen
		if cr.get("hanging", false):
			_update_hanging(cr, delta, seen)
			continue
		_update_crawler(cr, delta, hero)


func _update_hanging(cr: Dictionary, delta: float, seen: bool) -> void:
	cr.phase += delta * cr.rate
	# Mostly it waits low on its thread; now and then it climbs back up.
	var down := clampf(0.5 + sin(cr.phase * TAU) * 0.9, 0.0, 1.0)
	var length := lerpf(0.05, 1.9, down)
	var node: Node3D = cr.node
	node.position = cr.anchor - Vector3(0, length, 0)
	node.rotation.y += delta * 0.4 * sin(_time * 0.7 + cr.phase)
	var thread: MeshInstance3D = cr.thread
	thread.visible = seen and length > 0.1
	thread.scale.y = length
	thread.position = cr.anchor - Vector3(0, length * 0.5, 0)
	_wiggle(cr, 0.3 if absf(cos(cr.phase * TAU)) > 0.2 else 0.0, delta)


func _update_crawler(cr: Dictionary, delta: float, hero: Vector3) -> void:
	var node: Node3D = cr.node
	var spider: bool = cr.spider
	var away := Vector3(node.position.x - hero.x, 0, node.position.z - hero.z)
	var fleeing := away.length() < FLEE_RANGE
	if fleeing and cr.wait > 0.0:
		cr.wait = 0.0
		cr.target = node.position + away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * _rng.randf_range(2.5, 4.0)
	if cr.wait > 0.0:
		cr.wait -= delta
		cr.speed = 0.0
		_wiggle(cr, 0.0, delta)
		if not spider and _rng.randf() < delta * 0.8:
			# A roach at rest twitches now and then.
			node.rotation.y += _rng.randf_range(-0.4, 0.4)
		return
	var to: Vector3 = cr.target - node.position
	to.y = 0
	if to.length() < 0.08:
		cr.wait = _rng.randf_range(1.5, 6.0) if spider else _rng.randf_range(0.2, 2.5)
		_pick_target(cr)
		return
	var top := (2.4 if spider else 3.6) if fleeing else (0.9 if spider else 1.8)
	cr.speed = move_toward(cr.speed, top, delta * 12.0)
	var step := to.normalized() * minf(cr.speed * delta, to.length())
	var next := node.position + step
	if not _free_spot(next):
		cr.wait = _rng.randf_range(0.1, 0.6)
		_pick_target(cr)
		return
	node.position = next
	var yaw := atan2(step.x, step.z)
	node.rotation.y = lerp_angle(node.rotation.y, yaw, minf(1.0, delta * 14.0))
	_wiggle(cr, cr.speed, delta)


func _pick_target(cr: Dictionary) -> void:
	var node: Node3D = cr.node
	for attempt in 8:
		var dir := _rng.randf() * TAU
		var dist := _rng.randf_range(0.8, 3.5)
		var p := node.position + Vector3(cos(dir), 0, sin(dir)) * dist
		if _free_spot(p) and _free_spot(node.position.lerp(p, 0.5)):
			cr.target = p
			return
	cr.target = node.position


## Moves the legs in a quick trot while walking.
func _wiggle(cr: Dictionary, speed: float, delta: float) -> void:
	cr.step += delta * speed * 22.0
	var legs: Array = cr.legs
	for i in legs.size():
		var leg: Node3D = legs[i]
		var swing := sin(cr.step + (PI if i % 2 == 0 else 0.0)) * 0.35 if speed > 0.0 else 0.0
		leg.rotation.y = leg.get_meta("yaw") + swing


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _process(delta: float) -> void:
	_time += delta
	if level.player == null or level.fog == null:
		return
	var hero := level.player.global_position
	_update_critters(delta, hero)
	_update_drips(delta, hero)
