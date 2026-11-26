class_name SnowCover
extends RefCounted
## The layer of snow on every surface that faces the sky in the open air.
##
## One shared material (see snow_cover.gdshader) is laid over each mesh as its
## material overlay, so roofs, ledges, fence tops, rocks, branches and the ground
## all take snow without a change to their own materials. The material only draws
## where a surface faces up, and `amount` (0 to 1) decides how much of it is covered,
## so the layer builds up and melts away by changing a single number. While there
## is no snow at all the overlays are taken off again, so a bare village costs
## nothing. Creatures are left out: snow does not settle on anyone who walks about.

const SHADER := preload("res://shaders/snow_cover.gdshader")
## The same snow for cut-out cards (leaves of bushes and ivy), keeping to their shape.
const CUTOUT_SHADER := preload("res://shaders/snow_cutout.gdshader")
## Nodes of these kinds (and everything below them) stay bare, and so do the kinds that extend them (a
## BanditChief is an Enemy). Every animal and creature is here: none wears snow on its back.
const LEAVE_BARE := ["Villager", "Enemy", "Animal", "Pet", "Player", "FarmAnimal", "MerchantDonkey", "Projectile", "VillageBirds", "Owls", "Squirrel", "Hedgehog", "Eagle", "Rescue", "DragonFlyover", "Dragon", "VillageCat", "MerchantRaven"]

## How many burning spots the shader knows (see set_warm).
const WARM_MAX := 32
const HOUSE_SHADER := preload("res://shaders/snow_house.gdshader")
## Single meshes narrower than this (metres) take no snow (see tiny).
const SMALLEST := 0.6

var material := ShaderMaterial.new()
## The overlay of the houses built from the kit: the same snow, and wind-blown patches on their walls.
var house_material := ShaderMaterial.new()
var root: Node
var amount := 0.0
## How bright the light of the hour is on the snow, 0 night to 1 day (see set_amount).
var daylight := 1.0
## How bright the moon is on the snow, 0 to 1 (see snow.gdshaderinc).
var moon_glow := 0.0
var _covered := false
var _warm_src: Array[Vector4] = []
var _meshes: Array[GeometryInstance3D] = []
## Every snow material whose amount, light and fires are kept in step: the overlay, its cut-out
## copies (one per leaf texture) and the caps and icicles (see SnowCaps).
var _all: Array[ShaderMaterial] = []
var _cutouts := {}


func _init(world: Node) -> void:
	root = world
	material.shader = SHADER
	house_material.shader = HOUSE_SHADER
	_all.append(material)
	_all.append(house_material)
	_all.append_array(SnowCaps.materials())
	# The spruces' fronds draw their own snow (see spruce_needles.gdshader).
	_all.append(Fern.material(true))
	_param("amount", 0.0)


## Sets a parameter on both overlays (the plain one and the houses').
func _both(param: String, value: Variant) -> void:
	material.set_shader_parameter(param, value)
	house_material.set_shader_parameter(param, value)


## Sets a parameter on every snow material.
func _param(param: String, value: Variant) -> void:
	for m in _all:
		m.set_shader_parameter(param, value)


## Tells the shader where roofs stand over the ground (tiles of the grid where `roofed`
## has a true), so nothing under a roof gets snow.
## Pond tiles (`ponds`) are marked too: no snow settles on open water or on wind-swept ice.
func set_sky_mask(roofed: Array, width: int, height: int, tile: float, ponds: Array = []) -> void:
	var img := Image.create(width, height, false, Image.FORMAT_RG8)
	for c: Vector2i in roofed:
		img.set_pixel(c.x, c.y, Color(1, 0, 0, 1))
	for c: Vector2i in ponds:
		img.set_pixel(c.x, c.y, Color(0, 1, 0, 1))
	_both("sky_mask", ImageTexture.create_from_image(img))
	_both("grid_size", Vector2(width, height))
	_both("tile", tile)


## How many metres one pixel of the rooms mask stands for (see set_rooms).
const ROOM_STEP := 0.5
## How many rooms the shader can draw exactly (ROOM_MAX in snow_cover.gdshader).
const ROOM_MAX := 48


## Keeps the snow off the rooms of the buildings one walks into (see Outdoor.walk_in_room): each
## entry of `rooms` is [footprint (x/z), how high its rooms reach (metres)], and optionally how far
## its upper storey juts out past that and from which height (metres), drawn into a fine mask
## so the snow stops at the walls, the yard round a house takes snow, and nothing on any storey
## under the roof does.
func set_rooms(rooms: Array, width: int, height: int, tile: float) -> void:
	if rooms.is_empty():
		_both("rooms_on", false)
		return
	var size := Vector2i(ceili(width * tile / ROOM_STEP), ceili(height * tile / ROOM_STEP))
	var img := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RG8)
	var origin := Vector2.ONE * tile * -0.5
	var whole := Rect2i(Vector2i.ZERO, size)
	for entry: Array in rooms:
		var high := clampf(float(entry[1]) / SHELTER_SCALE, 0.0, 1.0)
		# The upper storey juts out over the ground floor's walls: from its floor up, the rooms reach
		# that far further (G: the height they start from there).
		if entry.size() > 3:
			var over: Rect2 = (entry[0] as Rect2).grow(float(entry[2]))
			var low := clampf(float(entry[3]) / SHELTER_SCALE, 0.0, 1.0)
			img.fill_rect(_pixels(over, origin).intersection(whole), Color(high, low, 0, 1))
		img.fill_rect(_pixels(entry[0], origin).intersection(whole), Color(high, 0, 0, 1))
	_both("room_mask", ImageTexture.create_from_image(img))
	_both("rooms_on", true)
	# The exact walls too (see the shader): the mask's pixels only follow them to within ROOM_STEP.
	var exact := rooms.size() <= ROOM_MAX
	if exact:
		var rects := PackedVector4Array()
		var extra := PackedVector4Array()
		for entry: Array in rooms:
			var r: Rect2 = entry[0]
			rects.append(Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
			# Without an upper storey the grow is zero from any height.
			extra.append(Vector4(float(entry[2]), float(entry[3]), 0, 0) if entry.size() > 3 else Vector4(0, 0, 0, 0))
		_both("room_rects", rects)
		_both("room_extra", extra)
		_both("room_count", rects.size())
	_both("rooms_exact", exact)


## The rooms mask's pixels that `r` (world x/z) covers (see set_rooms).
func _pixels(r: Rect2, origin: Vector2) -> Rect2i:
	var from := Vector2i(((r.position - origin) / ROOM_STEP).round())
	var to := Vector2i(((r.end - origin) / ROOM_STEP).round())
	return Rect2i(from, to - from)


## Gives the snow the ponds' shore (see Outdoor._build_shore), so it stops where the water
## and the ice begin in the same curves as the ground draws them, not along the pond tiles.
func set_shore(mask: Texture2D, reach: float) -> void:
	_both("shore_mask", mask)
	_both("shore_reach", reach)
	_both("shore_on", mask != null)


## Keeps the snow off the cellars the hero has dug: `mask` has a pixel for each 2 m cell of the
## map (null when nothing is dug).
func set_holes(mask: Texture2D) -> void:
	_both("hole_mask", mask)
	_both("holes_on", mask != null)


## The ground the herald has swept bare (see SnowSweep): `mask` is the sweep mask, laid over the map like the holes'.
func set_swept(mask: Texture2D) -> void:
	_both("swept_mask", mask)
	_both("swept_on", mask != null)
	_both("swept_refill", SnowSweep.REFILL_HOURS)
	_both("swept_step", SnowSweep.STEP)


## Hours of snowfall so far, the clock the swept ground fills in again by.
func set_swept_fall(hours: float) -> void:
	_both("swept_fall", hours)


## How many metres one step of the shelter mask's red stands for, times 255 (see snow.gdshaderinc).
const SHELTER_SCALE := 16.0


## Keeps the snow out of the self-built houses (see HouseGround.shelter): `shelters` maps a 2 m
## cell of the map to the height of the house's top over it; nothing settles below that height.
## The roofs keep their snow. `width` and `height` are the map's size in tiles.
func set_shelter(shelters: Dictionary, width: int, height: int, tile: float) -> void:
	var cells := Vector2i(width, height) * int(round(tile / HouseSketch.CELL))
	var img := Image.create(maxi(cells.x, 1), maxi(cells.y, 1), false, Image.FORMAT_R8)
	for c: Vector2i in shelters:
		if c.x >= 0 and c.y >= 0 and c.x < cells.x and c.y < cells.y:
			img.set_pixel(c.x, c.y, Color(clampf(float(shelters[c]) / SHELTER_SCALE, 0.0, 1.0), 0, 0, 1))
	_param("shelter_mask", ImageTexture.create_from_image(img) if not shelters.is_empty() else null)
	_param("shelter_on", not shelters.is_empty())
	_param("shelter_size", Vector2(cells) * HouseSketch.CELL)
	_param("shelter_shift", tile * 0.5)


## How many awnings the shader knows (see set_awnings).
const AWNING_MAX := 8


## Keeps the snow off what stands under an open awning (the canopies over the town's dining tables,
## see TownMeals.awnings): each entry is the ground it covers (x/z of its north-west and south-east
## corner) and, in its last value, how high it stands. The sky mask works per tile and blurs at its
## edges, so a bench poking out towards a tile's corner still took snow; this follows the cloth.
func set_awnings(list: Array) -> void:
	var rects := PackedVector4Array()
	var tops := PackedFloat32Array()
	for a: Array in list.slice(0, AWNING_MAX):
		rects.append(Vector4(a[0], a[1], a[2], a[3]))
		tops.append(a[4])
	while rects.size() < AWNING_MAX:
		rects.append(Vector4.ZERO)
		tops.append(-1000.0)
	_param("awnings", rects)
	_param("awning_tops", tops)
	_param("awning_count", mini(list.size(), AWNING_MAX))


## Where something burns: no snow settles within the radius (w) round each point (xyz), so fires,
## the forge's coals and its chimney, and the smoking chimneys stay clear. At most WARM_MAX.
func set_warm(spots: Array[Vector4]) -> void:
	# Kept, so spots added later while the world is built are known when the snow comes (see _cover).
	_warm_src = spots
	var list := PackedVector4Array()
	for i in mini(spots.size(), WARM_MAX):
		list.append(spots[i])
	while list.size() < WARM_MAX:
		list.append(Vector4(0, -1000, 0, 0))
	_param("warm", list)
	_param("warm_count", mini(spots.size(), WARM_MAX))


## How thick the snow lies, 0 to 1, and how bright the light of the hour is.
func set_amount(value: float, daylight_in := 1.0, moon := 0.0) -> void:
	amount = clampf(value, 0.0, 1.0)
	daylight = clampf(daylight_in, 0.0, 1.0)
	moon_glow = clampf(moon, 0.0, 1.0)
	_param("amount", amount)
	_param("daylight", daylight)
	_param("moon_glow", clampf(moon, 0.0, 1.0))
	if amount > 0.001 and not _covered:
		_cover()
	elif amount <= 0.001 and _covered:
		_uncover()


## Whether there is any snow on the world.
## Down in a cellar the surface's snow stays off whatever is left in view (see CellarView).
func set_underground(on: bool) -> void:
	_both("underground", on)


func lies() -> bool:
	return _covered


func _cover() -> void:
	_covered = true
	set_warm(_warm_src)
	_add(root)
	_show_caps(true)
	if root.is_inside_tree() and not root.get_tree().node_added.is_connected(_on_node_added):
		root.get_tree().node_added.connect(_on_node_added)


func _uncover() -> void:
	_covered = false
	for mi in _meshes:
		if is_instance_valid(mi) and mi.material_overlay is ShaderMaterial and _all.has(mi.material_overlay):
			mi.material_overlay = null
	_meshes.clear()
	_show_caps(false)
	if root.is_inside_tree() and root.get_tree().node_added.is_connected(_on_node_added):
		root.get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	# The tree reports every node of a subtree that comes in, so a mesh of a bare creature (the
	# eagle's feathers) arrives on its own: look at what it hangs from too.
	if _covered and root.is_ancestor_of(node) and not under_bare(node):
		_add(node)
		if node.is_in_group(SnowCaps.GROUP):
			(node as Node3D).visible = true


## Shows or hides the caps and icicles on the buildings of this world (see SnowCaps).
func _show_caps(on: bool) -> void:
	for cap in SnowCaps.in_world(root):
		cap.visible = on


## Puts the overlay on `node` and everything below it, except what is left bare.
func _add(node: Node) -> void:
	if bare(node):
		return
	# Single meshes and the many copies of one (trees, bushes, ivy) alike.
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		var gi := node as GeometryInstance3D
		var has_mesh: bool = (gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null) \
				or (gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null)
		if has_mesh and gi.material_overlay == null and not tiny(gi):
			var over: ShaderMaterial = (house_material if _of_house(gi) else material) if not cut_out(gi) else _cutout_for(gi)
			if over != null:
				gi.material_overlay = over
				_meshes.append(gi)
			
	for child in node.get_children():
		_add(child)


## Whether a mesh belongs to a house built from the village's kit (the villagers' homes, the smith's
## cottage, the town houses, the valley's farm houses), whose walls take wind-blown snow too.
static func _of_house(gi: Node) -> bool:
	var up: Node = gi.get_parent()
	for i in 3:
		if up == null:
			return false
		if up.has_meta("village_house") or up.has_meta("town_house"):
			return true
		up = up.get_parent()
	return false


## Whether a single mesh is too small to show its coat of snow (pebbles, twigs, crumbs): left
## bare, it saves a draw for each of the hundreds of them.
static func tiny(gi: GeometryInstance3D) -> bool:
	if not (gi is MeshInstance3D) or not gi.is_inside_tree():
		return false
	var ext: Vector3 = gi.get_aabb().size * gi.global_transform.basis.get_scale()
	return maxf(ext.x, ext.z) < SMALLEST


## Whether a mesh is drawn with see-through or cut-out parts (leaf cards, glass, water), whose
## holes the overlay cannot see (it would cover the whole card in white), or glows. Those stay bare.
static func cut_out(gi: GeometryInstance3D) -> bool:
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
	elif gi is MultiMeshInstance3D:
		mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	var mats: Array[Material] = [gi.material_override]
	if mesh != null:
		for i in mesh.get_surface_count():
			mats.append(mesh.surface_get_material(i))
			if gi is MeshInstance3D:
				mats.append((gi as MeshInstance3D).get_surface_override_material(i))
	for m in mats:
		# A material that draws its own snow (the spruces' fronds) takes no overlay.
		if m != null and m.has_meta("own_snow"):
			return true
		var base := m as BaseMaterial3D
		if base != null and base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
		# Glowing things (coals, embers, lit panes) are hot or lit from within: no snow on them.
		if base != null and base.emission_enabled:
			return true
	return false


## The snow for a mesh drawn with cut-out cards (leaves): a copy of the overlay that keeps to
## the shape in the alpha of its texture, one per texture. Null for see-through or glowing
## materials (glass, water, embers) and cards without a texture: those stay bare.
func _cutout_for(gi: GeometryInstance3D) -> ShaderMaterial:
	var base := _base_material(gi)
	if base == null or base.emission_enabled or base.albedo_texture == null:
		return null
	if base.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and base.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
		return null
	var key := "%d|%s|%s" % [base.albedo_texture.get_instance_id(), base.uv1_scale, base.uv1_offset]
	if not _cutouts.has(key):
		var m := ShaderMaterial.new()
		m.shader = CUTOUT_SHADER
		m.set_shader_parameter("cutout", base.albedo_texture)
		m.set_shader_parameter("uv_scale", base.uv1_scale)
		m.set_shader_parameter("uv_offset", base.uv1_offset)
		m.set_shader_parameter("alpha_scissor", base.alpha_scissor_threshold if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.5)
		# Leaves that hold snow on their upper rims too (the ivy, see IvySeasons.SNOW_CLING).
		m.set_shader_parameter("cling", float(base.get_meta("snow_cling", 0.0)))
		# Copy what the others know so far.
		for param: String in ["amount", "daylight", "moon_glow", "warm", "warm_count", "shelter_mask", "shelter_on", "shelter_size", "shelter_shift",
				"awnings", "awning_tops", "awning_count"]:
			m.set_shader_parameter(param, material.get_shader_parameter(param))
		_cutouts[key] = m
		_all.append(m)
	return _cutouts[key]


## The material a mesh is drawn with (its override, or its mesh's first surface).
static func _base_material(gi: GeometryInstance3D) -> BaseMaterial3D:
	if gi.material_override is BaseMaterial3D:
		return gi.material_override
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
		var over := (gi as MeshInstance3D).get_surface_override_material(0) if mesh != null and mesh.get_surface_count() > 0 else null
		if over is BaseMaterial3D:
			return over
	elif gi is MultiMeshInstance3D:
		mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	return mesh.surface_get_material(0) as BaseMaterial3D


## Whether this node hangs below something that is left bare (see bare).
func under_bare(node: Node) -> bool:
	var up := node.get_parent()
	while up != null and up != root:
		if bare(up):
			return true
		up = up.get_parent()
	return false


## Whether snow stays off this node: a creature, a puddle's water, a node marked "no_snow".
static func bare(node: Node) -> bool:
	if node.has_meta("no_snow") or node is GPUParticles3D or node is CPUParticles3D:
		return true
	var script: Script = node.get_script()
	# Walk up the script's bases too: a kind that extends a bare one is bare as well.
	while script != null:
		var named: String = script.get_global_name()
		if named in LEAVE_BARE or named == "Puddles":
			return true
		script = script.get_base_script()
	return false
