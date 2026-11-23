class_name CellarView
extends Node3D
## Down in a house cellar the hero sees the cellar, not the surface: while they stand in
## one, the grass, trees, houses, villagers and animals up on the ground are hidden, and the
## ground round the cellar becomes the earth it is dug into, as if cut open (packed soil
## with rock showing through, see shaders/cellar_earth.gdshader), with a few half-buried
## stones and roots lying in it and roots hanging over the rim. It darkens away from the
## cellar, so the cellar reads as a room under the ground. Climbing out brings it all back.
##
## The house builder (HouseSketcher) owns it and tells it where the dug cells are (holes);
## while it is on, the storeys above fade as under a roof (HouseSketcher._update_fade) and
## no weather falls in (Game._under_roof).

## The hero counts as down in the cellar below this height, and as out of it above LEAVE
## (on the stairs between the two the view stays as it was, so it never flickers).
const BELOW := -0.5
const LEAVE := -0.2
## How far the earth reaches down behind the cellar's walls from the rim (see _earth_mesh):
## deeper than any wall stops under the ground.
const SKIRT := 0.4
## How far behind the rim the skirt hangs: a cellar wall standing right on the rim (the
## guildhall's) would otherwise share its plane and flicker against it.
const SKIRT_BEHIND := 0.05
## Feet higher than this stand on a floor over the cellar (a hall's ground floor), not down in it.
const OVERHEAD := 0.3
## Metres of earth round the cellar, beyond what the camera ever shows.
const REACH := 160.0
## Seconds between looks for things that came or went up on the surface.
const TICK := 0.2
const ROCK := Color(0.3, 0.28, 0.26)
const ROOT := Color(0.23, 0.16, 0.1)
## Metres from the cellar where the earth has sunk into darkness.
const DARK_REACH := 15.0

var game: Node
## Every dug cell on the map (Rect2 of x, z), set by the house builder.
var holes: Array = []
## Whether the hero is down in a cellar and the surface is hidden.
var active := false
## The dug cells of the cellar the hero is in.
var pit: Array = []
## The cellar's outline round all its cells (x, z).
var _outline := Rect2()
## Whether the cellar is a house's (at most SMALL_PIT cells), not a whole mine's.
var _small_pit := true
const SMALL_PIT := 64
## The things up on the surface this view has hidden, to show again, by instance id.
## Never keyed by the nodes themselves: things are freed while hidden (a spent effect, a
## footprint), and walking a Dictionary with freed objects among its keys can go round
## for ever in Godot (the game froze climbing out of a cellar). An id outlives its node.
var _hidden := {}
## Hidden things that show or hide themselves (monsters out of the fog, a candle at dusk): they
## are hidden again every frame, not only every TICK. By instance id, as _hidden.
var _restless := {}
var _earth: Node3D = null
var _tick := 0.0
## Frames left in which every frame looks for things that showed themselves again, right
## after the hero came down (whatever does so then is caught at once, not a TICK later).
var _fresh := 0
var _mat: ShaderMaterial = null


func _ready() -> void:
	# After everything that shows or hides itself in the frame, so the hiding holds.
	process_priority = 100


func _process(delta: float) -> void:
	var want := _wanted()
	if want != active:
		if want:
			_enter()
		else:
			_leave()
	if not active:
		return
	_tick -= delta
	if _fresh > 0:
		_fresh -= 1
		_tick = 0.0
	if _tick <= 0.0:
		_tick = TICK
		_hide_surface()
		return
	for id: int in _restless:
		var node := instance_from_id(id) as Node3D
		if node != null and node.visible and _hidden.has(id):
			node.visible = false


## Whether the view should be on: the hero is down in a cellar on the open-air map, and no
## building tool is open (the blueprint needs the ground to draw on).
func _wanted() -> bool:
	if game == null or not game.level is Outdoor or game.player == null or not is_instance_valid(game.player):
		return false
	var sketcher: HouseSketcher = game.house_sketcher
	if sketcher != null and sketcher.active:
		return false
	var pos: Vector3 = game.player.global_position
	if pos.y > (LEAVE if active else BELOW):
		return false
	if active and _in_pit(pos):
		return true
	return not pit_at(pos).is_empty()


## The dug cells of the cellar at `pos`: every hole joined to the one under it (on a side
## or a corner). The holes lie on the 2 m lattice (see lattice_of), so the cells are looked
## up by their place: a cellar of hundreds of cells (the forgotten mine, see LostMine) is
## found as fast as a small one.
func pit_at(pos: Vector3) -> Array:
	var places := _places(holes)
	var start := Vector2i.ZERO
	var inside := false
	for d: Vector2 in GROWN:
		var at := lattice_of(Vector2(pos.x, pos.z) + d)
		if places.has(at):
			start = at
			inside = true
			break
	if not inside:
		return []
	var found := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var a: Vector2i = todo.pop_back()
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var b := a + Vector2i(dx, dy)
				if not found.has(b) and places.has(b):
					found[b] = true
					todo.append(b)
	var out := []
	for at: Vector2i in found:
		out.append(holes[places[at]])
	return out


## The 2 m lattice cell (see HouseSketch.CELL) a point (x, z) lies in.
static func lattice_of(at: Vector2) -> Vector2i:
	return Vector2i(floori((at.x + Level.TILE * 0.5) / HouseSketch.CELL), floori((at.y + Level.TILE * 0.5) / HouseSketch.CELL))


## How far round a cell a point still counts as in it (the rim, see in_cells), as the
## offsets that find the cells within that reach.
const RIM := 0.3
const GROWN: Array[Vector2] = [Vector2.ZERO, Vector2(RIM, 0), Vector2(-RIM, 0), Vector2(0, RIM), Vector2(0, -RIM),
	Vector2(RIM, RIM), Vector2(-RIM, RIM), Vector2(RIM, -RIM), Vector2(-RIM, -RIM)]
## The last few lists of cells looked up by place, each as [list, places].
static var _known: Array = []
const KNOWN := 4


## The places of a list of cells (Rect2 of x, z on the lattice): lattice cell -> index. The
## last KNOWN lists asked for are kept, so asking again for one of them (the same Array,
## unchanged in size) is free.
static func _places(cells: Array) -> Dictionary:
	for k in _known:
		if is_same(k[0], cells) and (k[1] as Dictionary).size() == cells.size():
			return k[1]
	var out := {}
	for i in cells.size():
		var r: Rect2 = cells[i]
		out[lattice_of(r.position + Vector2(0.01, 0.01))] = i
	_known.push_front([cells, out])
	if _known.size() > KNOWN:
		_known.pop_back()
	return out


func _in_pit(pos: Vector3) -> bool:
	return in_cells(pit, pos)


## Whether someone whose feet are at `pos` is down in the cellar of `cells`: in its cells and
## not up on a floor over it (Ragna at her desk over her own cellar, see GuildHall).
static func down_in(cells: Array, pos: Vector3) -> bool:
	return pos.y < OVERHEAD and in_cells(cells, pos)


## Whether `pos` lies in (or on the rim of) one of the cells (Rect2 of x, z), below head height.
## Under a long cellar (the forgotten mine, the bank's vault, see SMALL_PIT) with whole ground
## over most of it, only what is down below it counts: geese and pumpkins up on the street over
## it are not in it.
static func in_cells(cells: Array, pos: Vector3) -> bool:
	if pos.y > 1.0 or (cells.size() > SMALL_PIT and pos.y > -0.5):
		return false
	if cells.size() < 24:
		for r: Rect2 in cells:
			if r.grow(RIM).has_point(Vector2(pos.x, pos.z)):
				return true
		return false
	var places := _places(cells)
	for d: Vector2 in GROWN:
		if places.has(lattice_of(Vector2(pos.x, pos.z) + d)):
			return true
	return false


func _enter() -> void:
	active = true
	pit = pit_at(game.player.global_position)
	_outline = pit[0]
	for r: Rect2 in pit:
		_outline = _outline.merge(r)
	_small_pit = pit.size() <= SMALL_PIT
	# Monsters, villagers and animals ask the map what the hero sees (see Outdoor.hero_sees).
	(game.level as Outdoor).hero_cellar = pit
	_build_earth()
	_set_underground(true)
	_tick = 0.0
	_fresh = 10
	_hide_surface()


func _leave() -> void:
	active = false
	pit = []
	if is_instance_valid(game.level) and game.level is Outdoor:
		(game.level as Outdoor).hero_cellar = []
	for id: int in _hidden:
		var node := instance_from_id(id) as Node3D
		if node != null:
			node.visible = true
	_hidden.clear()
	_restless.clear()
	_set_underground(false)
	if _earth != null:
		_earth.queue_free()
		_earth = null


## Tells the snow to keep off the cellar's own pieces while the hero is down here.
func _set_underground(on: bool) -> void:
	if is_instance_valid(game.level) and game.level is Outdoor and (game.level as Outdoor).snow != null:
		(game.level as Outdoor).snow.set_underground(on)


func _exit_tree() -> void:
	if active:
		_leave()


## Hides everything of the map that is not down in the cellar: the ground, trees and
## buildings, and whoever walks up there. Whoever comes down into the cellar shows again.
## The house builder's own pieces stay: the storeys above fade like under a roof.
func _hide_surface() -> void:
	var keep: Array = [game.house_sketcher, game.house_furnisher]
	for child in game.level.get_children():
		# Monsters, villagers and animals hide themselves out of the hero's sight (Outdoor.hero_sees).
		if not child is Node3D or keep.has(child) or child is Enemy or child is Villager or child is Animal:
			continue
		var node := child as Node3D
		var below := _in_pit(node.global_position)
		# A wide patch of ground whose middle happens to lie in the cellar is still surface, and so
		# is one whose middle lies over a long cellar's tunnels (the forgotten mine, see LostMine):
		# what lies on the ground up there never reaches down below it.
		if below and node is VisualInstance3D:
			var box: AABB = node.global_transform * (node as VisualInstance3D).get_aabb()
			below = _outline.grow(0.5).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)) \
					and (_small_pit or box.position.y < -0.5)
		var id := node.get_instance_id()
		if below:
			if _hidden.has(id):
				_hidden.erase(id)
				_restless.erase(id)
				node.visible = true
		elif node.visible:
			node.visible = false
			# A scripted thing may show itself again; anything else that did is watched from now on.
			if _hidden.has(id) or node.get_script() != null:
				_restless[id] = true
			_hidden[id] = true
	# Forget what was freed meanwhile, so the books stay as small as what is still there.
	for id: int in _hidden.keys():
		if instance_from_id(id) == null:
			_hidden.erase(id)
			_restless.erase(id)


## The earth round the cellar: a wide floor of earth at ground height with the cellar's
## shape left open, stones and roots in it.
func _build_earth() -> void:
	if _earth != null:
		_earth.queue_free()
	_earth = Node3D.new()
	_earth.name = "CellarEarth"
	# It is the earth under the ground, cut open: no snow settles on it in winter (see SnowCover).
	_earth.set_meta("no_snow", true)
	add_child(_earth)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for r: Rect2 in pit:
		low = low.min(r.position)
		high = high.max(r.end)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _earth_mesh(low, high)
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://shaders/cellar_earth.gdshader")
		var bare := BareEarth.material()
		_mat.set_shader_parameter("soil", bare.get_shader_parameter("soil"))
		_mat.set_shader_parameter("soil_normal", bare.get_shader_parameter("soil_normal"))
	_mat.set_shader_parameter("pit_min", low)
	_mat.set_shader_parameter("pit_max", high)
	_mat.set_shader_parameter("dark_reach", DARK_REACH)
	mesh.material_override = _mat
	_earth.add_child(mesh)
	# The same cellar always gets the same stones and roots.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(low.x), roundi(low.y)))
	_stones(rng, low, high)
	_lying_roots(rng, low, high)
	_hanging_roots(rng)


## A flat floor at ground height from far round the cellar up to its rim, open over the
## cellar's cells (they lie on a CELL grid from the outline's corner).
func _earth_mesh(low: Vector2, high: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var mid := (low + high) * 0.5
	var far_low := mid - Vector2(REACH, REACH)
	var far_high := mid + Vector2(REACH, REACH)
	# Four wide strips round the cellar's outline...
	_quad(st, Vector2(far_low.x, far_low.y), Vector2(far_high.x, low.y))
	_quad(st, Vector2(far_low.x, high.y), Vector2(far_high.x, far_high.y))
	_quad(st, Vector2(far_low.x, low.y), Vector2(low.x, high.y))
	_quad(st, Vector2(high.x, low.y), Vector2(far_high.x, high.y))
	# ... and inside it every cell that is not dug.
	var cell := HouseSketch.CELL
	var places := _places(pit)
	var y := low.y
	while y < high.y - 0.01:
		var x := low.x
		while x < high.x - 0.01:
			var centre := Vector2(x + cell * 0.5, y + cell * 0.5)
			var dug := places.has(lattice_of(centre))
			if not dug:
				_quad(st, Vector2(x, y), Vector2(x + cell, y + cell))
			x += cell
		y += cell
	# A skirt of earth down from the rim behind every cellar wall: under a cellar ceiling
	# (hidden down here) the wall stops a little under the ground, and through the gap
	# between it and this floor's edge the sky showed as a white line along the rim.
	for r: Rect2 in pit:
		var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var beyond := (a + b) * 0.5 + ((a + b) * 0.5 - r.get_center()).normalized() * cell * 0.5
			var open := false
			for other: Rect2 in pit:
				if other.has_point(beyond):
					open = true
					break
			if not open:
				var back := ((a + b) * 0.5 - r.get_center()).normalized() * SKIRT_BEHIND
				_skirt(st, a + back, b + back)
	return st.commit()


## A strip of earth hanging SKIRT metres down from the rim between `a` and `b`, seen from both sides.
static func _skirt(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var p := [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, -SKIRT, b.y), Vector3(a.x, -SKIRT, a.y)]
	for i in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
		st.set_uv(Vector2(p[i].x, p[i].z))
		st.add_vertex(p[i])


static func _quad(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var p := [Vector3(a.x, 0, a.y), Vector3(b.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(a.x, 0, b.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(Vector2(p[i].x, p[i].z))
		st.add_vertex(p[i])


## How far `at` lies outside the cellar's outline (0 inside it).
static func _away(at: Vector2, low: Vector2, high: Vector2) -> float:
	return (at - at.clamp(low, high)).length()


## How much light reaches the earth `away` metres from the cellar (as the earth's shader).
static func _dim(away: float) -> float:
	return lerpf(1.0, 0.05, smoothstep(1.0, DARK_REACH, away))


## Half-buried stones lying in the earth round the cellar, more near it, none on its rim.
func _stones(rng: RandomNumberGenerator, low: Vector2, high: Vector2) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROCK
	mat.roughness = 0.85
	var shape := SphereMesh.new()
	shape.radial_segments = 6
	shape.rings = 3
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 400:
		tries += 1
		var at := Vector2(rng.randf_range(low.x - 22.0, high.x + 22.0), rng.randf_range(low.y - 22.0, high.y + 22.0))
		var away := _away(at, low, high)
		if away < 0.9 or rng.randf() > 1.4 - away / 18.0:
			continue
		var stone := MeshInstance3D.new()
		stone.mesh = shape
		var size := rng.randf_range(0.25, 0.9) * (1.8 if rng.randf() < 0.12 else 1.0)
		stone.scale = Vector3(size * rng.randf_range(0.8, 1.4), size * rng.randf_range(0.35, 0.6), size * rng.randf_range(0.7, 1.2))
		stone.rotation.y = rng.randf() * TAU
		stone.position = Vector3(at.x, -size * 0.12, at.y)
		var tint := mat.duplicate() as StandardMaterial3D
		tint.albedo_color = ROCK.darkened(1.0 - rng.randf_range(0.8, 1.0) * _dim(away))
		stone.material_override = tint
		_earth.add_child(stone)
		placed += 1


## Roots running through the earth near the cellar, half sunk into it.
func _lying_roots(rng: RandomNumberGenerator, low: Vector2, high: Vector2) -> void:
	for i in 14:
		var at := Vector2(rng.randf_range(low.x - 9.0, high.x + 9.0), rng.randf_range(low.y - 9.0, high.y + 9.0))
		if _away(at, low, high) < 0.6:
			continue
		var heading := rng.randf() * TAU
		var thick := rng.randf_range(0.06, 0.13)
		var points: Array[Vector3] = [Vector3(at.x, -thick * 0.3, at.y)]
		for s in rng.randi_range(4, 8):
			heading += rng.randf_range(-0.6, 0.6)
			var next: Vector2 = Vector2(points[-1].x, points[-1].z) + Vector2.from_angle(heading) * rng.randf_range(0.5, 1.1)
			if _away(next, low, high) < 0.3:
				break
			points.append(Vector3(next.x, -thick * 0.3, next.y))
		_root(points, thick, _dim(_away(at, low, high)))


## Roots growing out of the earth over the cellar's rim and hanging down its walls.
func _hanging_roots(rng: RandomNumberGenerator) -> void:
	for r: Rect2 in pit:
		for side in 4:
			var dir: Vector2 = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)][side]
			var edge_mid := r.get_center() + dir * (HouseSketch.CELL * 0.5)
			# Only a rim that has earth beyond it (no other dug cell).
			var beyond := edge_mid + dir * 0.3
			var open := _places(pit).has(lattice_of(beyond))
			if open or rng.randf() > 0.6:
				continue
			var along := Vector2(-dir.y, dir.x)
			var start := edge_mid + along * rng.randf_range(-0.7, 0.7)
			var hang := rng.randf_range(0.5, 1.6)
			var lean := rng.randf_range(-0.25, 0.25)
			var thick := rng.randf_range(0.04, 0.08)
			var out := Vector3(dir.x, 0, dir.y)
			var side3 := Vector3(along.x, 0, along.y)
			var top := Vector3(start.x, 0, start.y)
			var points: Array[Vector3] = [top + out * rng.randf_range(0.4, 0.9) + Vector3(0, -0.02, 0), top + out * 0.05 + Vector3(0, 0.02, 0)]
			for k in 3:
				var f := float(k + 1) / 3.0
				points.append(top - out * (0.08 + 0.06 * f) + side3 * lean * f + Vector3(0, -hang * f, 0))
			_root(points, thick)


## A root: thin brown sticks from point to point, thinning towards its tip.
func _root(points: Array[Vector3], thick: float, light := 1.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROOT.darkened(1.0 - light)
	mat.roughness = 0.9
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var stick := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var t := 1.0 - float(i) / float(points.size()) * 0.6
		cyl.top_radius = thick * t
		cyl.bottom_radius = thick * (t - 0.6 / float(points.size()))
		cyl.height = length + thick
		cyl.radial_segments = 6
		cyl.rings = 1
		stick.mesh = cyl
		stick.material_override = mat
		var up := (a - b).normalized()
		var across := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
		stick.transform = Transform3D(Basis(across, up, across.cross(up)).orthonormalized(), (a + b) * 0.5)
		_earth.add_child(stick)
