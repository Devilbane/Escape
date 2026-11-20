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
## Nodes of these kinds (and everything below them) stay bare.
const LEAVE_BARE := ["Villager", "Enemy", "Animal", "Pet", "Player", "FarmAnimal", "Projectile", "VillageBirds", "Squirrel", "Eagle", "Rescue", "DragonFlyover", "Dragon"]

## How many burning spots the shader knows (see set_warm).
const WARM_MAX := 32
## Single meshes narrower than this (metres) take no snow (see tiny).
const SMALLEST := 0.6

var material := ShaderMaterial.new()
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
	_all.append(material)
	_all.append_array(SnowCaps.materials())
	_param("amount", 0.0)


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
	material.set_shader_parameter("sky_mask", ImageTexture.create_from_image(img))
	material.set_shader_parameter("grid_size", Vector2(width, height))
	material.set_shader_parameter("tile", tile)


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
			var over: ShaderMaterial = material if not cut_out(gi) else _cutout_for(gi)
			if over != null:
				gi.material_overlay = over
				_meshes.append(gi)
	for child in node.get_children():
		_add(child)


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
		# Copy what the others know so far.
		for param: String in ["amount", "daylight", "moon_glow", "warm", "warm_count"]:
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
	if script != null:
		var named: String = script.get_global_name()
		if named in LEAVE_BARE or named == "Puddles":
			return true
	return false
