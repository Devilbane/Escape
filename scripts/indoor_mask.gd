class_name IndoorMask
extends RefCounted
## Where the weather does not show: a map of the open air that tells, for every half metre of the
## ground, how high the house over it keeps the weather out (shaders/indoors.gdshaderinc). Under the
## roof of a self-built house (Outdoor.roofs, see HouseGround.roofed) and in a village room one walks into
## (WalkIn), up to the top of it, the fog clouds, the rain, the snowflakes, the mist and the leaves
## leave everything out. Outside they go on, so from in there the weather shows through the windows,
## the open door and over the walls, but none of it inside.
##
## The map is the global shader parameter `indoor_mask` (with `indoor_area`, see project.godot). It is
## built again only when the houses change (see mark): a new piece built, or the rooms opened.

## Metres of ground per pixel of the map.
const STEP := 0.5
## How many metres the full red of a pixel stands for (see INDOOR_SCALE in indoors.gdshaderinc).
const SCALE := 16.0
## How far the mask of a room reaches past its floor plan, over the walls (the walls are 0.2 m thick).
const WALL_PAD := STEP
## How deep a spot over a cellar has to lie (metres, below the ground) to be kept out of the weather.
const PIT_DEPTH := -0.2
## How high above the ground a spot in the margin must lie to be kept out of the weather (B of a pixel, see
## RING_FLOOR in indoors.gdshaderinc): the ground right outside a wall is open air, the wall's face is not.
const RING_FLOOR := 0.3
const MASK := "indoor_mask"
const AREA := "indoor_area"

## The level the map was built for, and whether it must be built again.
static var _for: WeakRef = null
static var _dirty := true
static var _rooms := -1
## The map as built last (for the tests).
static var image: Image


## The houses of the open air changed: build the map again on the next update.
static func mark() -> void:
	_dirty = true


## Keeps the map in step with `level` (call every frame; it only builds when something changed).
## Below ground there is no weather and no map.
static func update(level: Level) -> void:
	if not (level is Outdoor):
		if _for != null:
			off()
		return
	var out := level as Outdoor
	var rooms := _opened_rooms(out)
	if not _dirty and rooms == _rooms and _for != null and _for.get_ref() == level:
		return
	_dirty = false
	_rooms = rooms
	_for = weakref(level)
	build(out)


## No map: the weather shows everywhere.
static func off() -> void:
	_for = null
	_rooms = -1
	image = null
	RenderingServer.global_shader_parameter_set(AREA, Color(0, 0, 0, 0))


static func _opened_rooms(level: Outdoor) -> int:
	if level.walk_in == null:
		return 0
	var n := 0
	for rec: Dictionary in level.walk_in.buildings:
		if rec.get("opened", false):
			n += 1
	return n


## Builds the map of `level` and hands it to the shaders.
static func build(level: Outdoor) -> void:
	var corner := Vector2(-Level.TILE * 0.5, -Level.TILE * 0.5)
	var size := Vector2i(ceili(level.width * Level.TILE / STEP), ceili(level.height * Level.TILE / STEP))
	var img := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGB8)
	var any := false
	# The roofs of the self-built houses: each 2 m cell of the house lattice, up to its top.
	var per := int(round(HouseSketch.CELL / STEP))
	for c: Vector2i in level.roofs:
		var top := float(level.roofs[c])
		for dy in per:
			for dx in per:
				any = _raise(img, Vector2i(c.x * per + dx, c.y * per + dy), top) or any
	# The cellars: below the ground the weather stays out over the whole cellar and its stairs, also
	# where they reach beyond the roof (G of a pixel, see PIT_DEPTH in indoors.gdshaderinc).
	for c: Vector2i in level.pits:
		for dy in per:
			for dx in per:
				var px := Vector2i(c.x * per + dx, c.y * per + dy)
				if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height():
					var was := img.get_pixel(px.x, px.y)
					img.set_pixel(px.x, px.y, Color(was.r, 1.0, 0, 1))
					any = true
	# The village rooms one walks into: their floor plan, turned with the building, up to the ceiling.
	if level.walk_in != null:
		for rec: Dictionary in level.walk_in.buildings:
			if not rec.get("opened", false):
				continue
			var node: Node3D = rec.node
			if not is_instance_valid(node) or not node.is_inside_tree():
				continue
			# The walls stand just outside the floor plan: the room reaches a whole pixel into them, or the
			# wall tops and the inner faces of the walls seen from above stayed in the fog.
			var core: Rect2 = rec.room
			var room: Rect2 = core.grow(WALL_PAD)
			var xf := node.global_transform
			var top := (xf * Vector3(room.get_center().x, float(rec.top), room.get_center().y)).y
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for k in [room.position, Vector2(room.end.x, room.position.y), room.end, Vector2(room.position.x, room.end.y)]:
				var w := xf * Vector3(k.x, 0.0, k.y)
				lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.z))
				hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.z))
			var inv := xf.affine_inverse()
			for py in range(floori((lo.y - corner.y) / STEP), ceili((hi.y - corner.y) / STEP)):
				for px in range(floori((lo.x - corner.x) / STEP), ceili((hi.x - corner.x) / STEP)):
					var at := corner + (Vector2(px, py) + Vector2(0.5, 0.5)) * STEP
					var local := inv * Vector3(at.x, 0.0, at.y)
					if room.has_point(Vector2(local.x, local.z)):
						any = _raise(img, Vector2i(px, py), top, not core.has_point(Vector2(local.x, local.z))) or any
	image = img
	if not any:
		RenderingServer.global_shader_parameter_set(AREA, Color(0, 0, 0, 0))
		return
	RenderingServer.global_shader_parameter_set(MASK, ImageTexture.create_from_image(img))
	RenderingServer.global_shader_parameter_set(AREA, Color(corner.x, corner.y, STEP, 1.0))


## Raises the top kept dry at one pixel to `top` metres (never lowers it).
## `ring`: the pixel lies in the margin outside the floor plan (it keeps only what is above RING_FLOOR out of
## the weather); a pixel that is inside some floor plan stays whole.
static func _raise(img: Image, px: Vector2i, top: float, ring := false) -> bool:
	if px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height() or top <= 0.0:
		return false
	var v := clampf(top / SCALE, 0.0, 1.0)
	var was := img.get_pixel(px.x, px.y)
	if ring:
		if was.r <= 0.0:
			img.set_pixel(px.x, px.y, Color(v, was.g, 1, 1))
	elif v > was.r or was.b > 0.5:
		img.set_pixel(px.x, px.y, Color(maxf(v, was.r), was.g, 0, 1))
	return true


## Whether a world spot lies inside a house as the map has it (as the shaders read it).
static func covers(pos: Vector3) -> bool:
	if image == null:
		return false
	var px := Vector2i(floori((pos.x + Level.TILE * 0.5) / STEP), floori((pos.z + Level.TILE * 0.5) / STEP))
	if px.x < 0 or px.y < 0 or px.x >= image.get_width() or px.y >= image.get_height():
		return false
	var at := image.get_pixel(px.x, px.y)
	var low_ring: bool = at.b > 0.5 and pos.y < RING_FLOOR
	return (at.r * SCALE > 0.0 and pos.y < at.r * SCALE and not low_ring) or (at.g > 0.5 and pos.y < PIT_DEPTH)
