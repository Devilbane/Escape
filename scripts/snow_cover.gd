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
## Nodes of these kinds (and everything below them) stay bare.
const LEAVE_BARE := ["Villager", "Enemy", "Animal", "Pet", "Player", "FarmAnimal", "Projectile"]

## How many burning spots the shader knows (see set_warm).
const WARM_MAX := 32
## Single meshes narrower than this (metres) take no snow (see tiny).
const SMALLEST := 0.6

var material := ShaderMaterial.new()
var root: Node
var amount := 0.0
var _covered := false
var _warm_src: Array[Vector4] = []
var _meshes: Array[GeometryInstance3D] = []


func _init(world: Node) -> void:
	root = world
	material.shader = SHADER
	material.set_shader_parameter("amount", 0.0)


## Tells the shader where roofs stand over the ground (tiles of the grid where `roofed`
## has a true), so nothing under a roof gets snow.
func set_sky_mask(roofed: Array, width: int, height: int, tile: float) -> void:
	var img := Image.create(width, height, false, Image.FORMAT_R8)
	for c: Vector2i in roofed:
		img.set_pixel(c.x, c.y, Color(1, 0, 0, 1))
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
	material.set_shader_parameter("warm", list)
	material.set_shader_parameter("warm_count", mini(spots.size(), WARM_MAX))


## How thick the snow lies, 0 to 1, and how bright the light of the hour is.
func set_amount(value: float, daylight := 1.0) -> void:
	amount = clampf(value, 0.0, 1.0)
	material.set_shader_parameter("amount", amount)
	material.set_shader_parameter("daylight", clampf(daylight, 0.0, 1.0))
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
	if root.is_inside_tree() and not root.get_tree().node_added.is_connected(_on_node_added):
		root.get_tree().node_added.connect(_on_node_added)


func _uncover() -> void:
	_covered = false
	for mi in _meshes:
		if is_instance_valid(mi) and mi.material_overlay == material:
			mi.material_overlay = null
	_meshes.clear()
	if root.is_inside_tree() and root.get_tree().node_added.is_connected(_on_node_added):
		root.get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if _covered and root.is_ancestor_of(node):
		_add(node)


## Puts the overlay on `node` and everything below it, except what is left bare.
func _add(node: Node) -> void:
	if bare(node):
		return
	# Single meshes and the many copies of one (trees, bushes, ivy) alike.
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		var gi := node as GeometryInstance3D
		var has_mesh: bool = (gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null) \
				or (gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null)
		if has_mesh and gi.material_overlay == null and not cut_out(gi) and not tiny(gi):
			gi.material_overlay = material
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
