class_name WallFade
extends RefCounted
## The walls on the near side of a room, between the camera and the floor,
## stand at full height like every other wall. Only the stretch right in
## front of the hero turns see-through, so the hero never vanishes behind
## stone, and turns solid again once the hero has moved on.

const STONE_SHADER := preload("res://shaders/stone.gdshader")
## How see-through a wall in front of the hero gets (0 solid, 1 gone): the
## stone stays faintly there, so the room keeps its shape.
const FADED := 0.75
## How long a wall takes to fade out or back in, in seconds.
const FADE_TIME := 0.25
## How high the walls stand (the kit's wall pieces).
const WALL_HEIGHT := 4.0
## Sideways reach from the hero: the hero's own tile and the next one each
## way, with the side faces between them.
const SIDE_REACH := 6.0
## Extra depth beyond the line of sight, for the hero's width.
const MARGIN := 1.0
## How far the hero (or the camera's tilt) moves before the walls are
## checked again.
const RECHECK := 0.25

## Each near wall piece: its node, its meshes and whether it is faded now.
var _pieces: Array = []
var _last_at := Vector3.INF
var _last_pitch := INF


## Adds a wall piece (or pillar, doorway) on the near side of a room.
func add(node: Node3D) -> void:
	_pieces.append({"node": node, "meshes": [], "faded": false, "tween": null})


func size() -> int:
	return _pieces.size()


## Fades the pieces in front of `hero` and brings back the rest. Cheap when
## nothing moved: the walls are checked again only after the hero or the
## camera moved a little.
func update(owner: Node, hero: Node3D, camera: Camera3D) -> void:
	if hero == null or camera == null or _pieces.is_empty():
		return
	var at := SmoothMotion.drawn_at(hero)
	var pitch := -camera.global_rotation.x
	if at.distance_to(_last_at) < RECHECK and absf(pitch - _last_pitch) < 0.02:
		return
	_last_at = at
	_last_pitch = pitch
	var reach := reach_for(pitch, camera.global_position.y - at.y)
	for p in _pieces:
		var node: Node3D = p.node
		if not is_instance_valid(node):
			continue
		var pos := node.global_position
		var ahead := pos.z - at.z
		var faded := ahead > 0.0 and ahead < reach and absf(pos.x - at.x) <= SIDE_REACH
		if faded != p.faded:
			_fade(owner, p, faded)


## Makes every piece solid again and forgets where the hero was.
func reset(owner: Node) -> void:
	for p in _pieces:
		if p.faded and is_instance_valid(p.node):
			_fade(owner, p, false)
	_last_at = Vector3.INF
	_last_pitch = INF


## How far south of the hero a full-height wall can still hide some of the
## hero: from the hero's feet, the line to the camera climbs over the top of
## the wall after WALL_HEIGHT / tan(pitch) metres, and a wall behind the
## camera hides nothing. The camera's height above the hero, not where it
## is now, gives how far off it is, so a camera still catching up with the
## hero changes nothing.
static func reach_for(pitch: float, camera_above: float) -> float:
	var flat := maxf(tan(pitch), 0.05)
	var over := WALL_HEIGHT / flat
	var camera_off := maxf(camera_above, 0.0) / flat
	return minf(over, camera_off) + MARGIN


func _fade(owner: Node, p: Dictionary, faded: bool) -> void:
	p.faded = faded
	if p.meshes.is_empty():
		p.meshes = _fadeable(p.node)
	if p.tween != null and (p.tween as Tween).is_valid():
		(p.tween as Tween).kill()
	if p.meshes.is_empty():
		return
	var from: float = p.get("amount", 0.0)
	var tween := owner.create_tween()
	tween.tween_method(_apply.bind(p), from, FADED if faded else 0.0, FADE_TIME)
	p.tween = tween


## The meshes of a piece, each with how it fades: the rough stone of the
## walls has its own dither (stone.gdshader's `fade`); a plain material, such
## as the pillars', gets a copy of its own that dithers out by its alpha.
static func _fadeable(node: Node) -> Array:
	var out := []
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	# The skulls, bones and shards set into a themed wall have no fade of their
	# own (see WallThemes.relief_material): they vanish with the wall, so they
	# never hang in the air where the wall has dissolved.
	for extra in node.find_children("*", "MultiMeshInstance3D", true, false):
		out.append({"mesh": extra, "stone": false, "relief": true, "plain": [], "alpha": []})
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		if mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader == WallThemes.RELIEF_SHADER:
			out.append({"mesh": mi, "stone": false, "relief": true, "plain": [], "alpha": []})
			continue
		var stone := false
		var plain := []
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is ShaderMaterial and ((mat as ShaderMaterial).shader == STONE_SHADER or (mat as ShaderMaterial).shader == WallThemes.SHADER or (mat as ShaderMaterial).shader == WallCaps.CAP_SHADER):
				stone = true
			elif mat is BaseMaterial3D:
				var copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
				plain.append(copy)
				if mi.material_override == mat:
					mi.material_override = copy
				else:
					mi.set_surface_override_material(i, copy)
		out.append({"mesh": mi, "stone": stone, "plain": plain, "alpha": plain.map(func(m): return m.albedo_color.a)})
	return out


func _apply(amount: float, p: Dictionary) -> void:
	p.amount = amount
	for m in p.meshes:
		if not is_instance_valid(m.mesh):
			continue
		if m.get("relief", false):
			(m.mesh as Node3D).visible = amount < 0.5
		if m.stone:
			(m.mesh as GeometryInstance3D).set_instance_shader_parameter("fade", amount)
		for i in m.plain.size():
			m.plain[i].albedo_color.a = m.alpha[i] * (1.0 - amount)


## Whether the piece is see-through now (for the tests).
func is_faded(node: Node3D) -> bool:
	for p in _pieces:
		if p.node == node:
			return p.faded
	return false
