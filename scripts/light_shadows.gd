class_name LightShadows
extends Node
## Walls block light, and nothing else does: a torch, candle, fireplace or
## lantern does not shine through a wall into the room behind it or out of a
## house, while everything else is lit exactly as before.
##
## Light stops at walls through shadows, but only walls cast them: a wall piece
## of a dungeon (Level.WALL_PIECES) and every built part of a hero's house
## (HouseSketcher) carry the meta WALL, so everything drawn under them goes on
## WALL_LAYER, and every point light takes shadows from that layer alone
## (shadow_caster_mask). Lamps, their posts and frames, furniture, people and
## monsters never shade a point light; the moon keeps its shadows as before.
##
## A shadow-casting point light costs a few render passes, so not every light
## gets them. Every few ticks the lights nearest the hero (the ones that can
## reach the part of the world on screen) cast them, BUDGET at most, fading in
## and out; the rest stay plain.
##
## It watches the whole tree (SceneTree.node_added), so a new light source
## needs nothing extra. A light that must stay plain (a soft fill on the hero's
## face) sets the meta NO_SHADOW; a small glow (range under MIN_RANGE, a spell
## or a spark) stays plain on its own.

## How many lights cast shadows at once.
const BUDGET := 8
## Lights with a shorter reach are small glows: they stay plain.
const MIN_RANGE := 4.0
## How far outside its reach the hero may be for a light to still count: about
## what the camera shows around the hero.
const VIEW := 20.0
## How often the shadow-casting lights are picked again, in seconds.
const EVERY := 0.2
## A light that casts shadows keeps them until another is this much nearer, so
## two lights at about the same distance do not take turns.
const KEEP := 5.0
## How long a light's shadows take to fade in or out, in seconds: a light that
## gains or loses its shadows changes its look slowly instead of at once.
const FADE := 1.2
## The meta of a lamp inside a hero's built house (a candle stand, a wall torch, the fireplace).
## Walls all round it, so it needs its shadows most: it is picked before every lamp in the
## open, and a lamp in the open no longer takes its turn as the hero walks about. It never
## lights the spruces (UNSHADOWED_LAYER), which take no shadows and so would glow through
## the house's walls.
const INDOOR := &"indoor_light"
## The render layer of things drawn without shadows that stand round the houses: the spruces'
## fronds (see spruce_needles.gdshader). Walls cannot stop light on them, so indoor lamps
## leave them out of their light altogether (see _on_node_added and refresh).
const UNSHADOWED_LAYER := 1 << 15
## How much sooner an indoor lamp is picked (metres of distance, more than any outdoor lamp's).
const INDOOR_FIRST := 100.0
## The meta a light sets to never cast shadows.
const NO_SHADOW := &"no_wall_shadow"
## The meta of a node whose drawn parts are walls (see the top).
const WALL := &"blocks_light"
## The meta of a drawn floor inside a wall's node: it is lit but casts no shadow of its own.
## A floor that cast one would shade its own top face (shadow acne), in stripes that crawl
## over the boards as the hero's lantern moves. A floor with a room under it gets a thin
## shadow-only lid at its underside instead (see HouseSketcher._floor_box).
const FLOOR := &"lit_floor"
## The render layer of walls: the only thing point lights take shadows from.
const WALL_LAYER := 1 << 17
## The render layer of a lifted roof (see lift): it is not drawn, and only point
## lights take shadows from it, so the lamps of a house stay inside it while the
## hero looks in from above, and the moon still shines in.
const LID_LAYER := 1 << 16
## Shadow biases tuned for the thin walls of a built house (0.2 m).
const BIAS := 0.04
const NORMAL_BIAS := 0.6

## What the lights are picked around (the hero); without it, the camera.
var focus: Node3D
var _lights := {}
var _wait := 0.0
## The lights picked to cast shadows (by instance id).
var _picked := {}
## The lights whose shadows are fading in or out (by instance id).
var _fading := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for light: Node in get_tree().root.find_children("*", "Light3D", true, false):
		_on_node_added(light)
	for drawn: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		_on_node_added(drawn)


func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D:
		if is_wall(node):
			(node as GeometryInstance3D).layers |= WALL_LAYER
		elif takes_no_shadows(node):
			(node as GeometryInstance3D).layers |= UNSHADOWED_LAYER
	elif node is OmniLight3D or node is SpotLight3D:
		_lights[node.get_instance_id()] = node
		var light: Light3D = node
		light.shadow_enabled = false
		light.shadow_bias = BIAS
		light.shadow_normal_bias = NORMAL_BIAS
		light.shadow_caster_mask = WALL_LAYER | LID_LAYER


func _process(delta: float) -> void:
	_fade(delta / FADE)
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = EVERY
	refresh()


## Picks the lights that cast shadows now. Their shadows fade in, and those of
## the lights left out fade away; `at_once` skips the fade (a level's start).
func refresh(at_once := false) -> void:
	var at := _focus_point()
	var ranked: Array = []
	for id in _lights.keys():
		var held = _lights[id]
		if not is_instance_valid(held):
			_lights.erase(id)
			_picked.erase(id)
			_fading.erase(id)
			continue
		var light: Light3D = held
		if not light.is_inside_tree():
			_picked.erase(id)
			continue
		if light.has_meta(INDOOR):
			light.light_cull_mask &= ~UNSHADOWED_LAYER
		var score := shadow_score(light, at)
		if score == INF:
			_drop(light, at_once or not light.is_visible_in_tree())
			continue
		ranked.append([score - (KEEP if _picked.has(id) else 0.0) - (INDOOR_FIRST if light.has_meta(INDOOR) else 0.0), light])
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	for i in ranked.size():
		var light: Light3D = ranked[i][1]
		if i < BUDGET:
			_pick(light, at_once)
		else:
			_drop(light, at_once)
	if at_once:
		_fade(1.0)


func _pick(light: Light3D, at_once: bool) -> void:
	var id := light.get_instance_id()
	if _picked.has(id) and not _fading.has(id):
		return
	_picked[id] = true
	if not light.shadow_enabled:
		light.shadow_enabled = true
		light.shadow_opacity = 0.0
	if at_once:
		light.shadow_opacity = 1.0
		_fading.erase(id)
	elif light.shadow_opacity < 1.0:
		_fading[id] = light


func _drop(light: Light3D, at_once: bool) -> void:
	var id := light.get_instance_id()
	_picked.erase(id)
	if not light.shadow_enabled:
		_fading.erase(id)
		return
	if at_once:
		light.shadow_enabled = false
		_fading.erase(id)
	else:
		_fading[id] = light


## Moves the fading shadows a step towards their goal; a light whose shadows
## have faded away stops casting them.
func _fade(step: float) -> void:
	for id in _fading.keys():
		var held = _fading[id]
		if not is_instance_valid(held):
			_fading.erase(id)
			continue
		var light: Light3D = held
		var goal := 1.0 if _picked.has(id) else 0.0
		light.shadow_opacity = move_toward(light.shadow_opacity, goal, step)
		if light.shadow_opacity == goal:
			_fading.erase(id)
			if goal == 0.0:
				light.shadow_enabled = false


## Whether a light is picked to cast shadows (its shadows may still be fading in).
func casts(light: Light3D) -> bool:
	return _picked.has(light.get_instance_id())


## Lifts a roof or upper storey of a built house off while the hero is under it
## (`lifted`), or puts it back: lifted, it is not drawn and the moon shines in,
## but it still stops the light of the house's lamps, torches and fireplace, so
## they do not shine out over the walls onto the trees around.
static func lift(node: Node, lifted: bool) -> void:
	if node.get_meta(&"lifted", false) == lifted:
		return
	node.set_meta(&"lifted", lifted)
	var parts: Array = node.find_children("*", "GeometryInstance3D", true, false)
	if node is GeometryInstance3D:
		parts.append(node)
	for part: GeometryInstance3D in parts:
		if lifted:
			part.set_meta(&"drawn_as", [part.layers, part.cast_shadow])
			part.layers = LID_LAYER
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		elif part.has_meta(&"drawn_as"):
			var was: Array = part.get_meta(&"drawn_as")
			part.layers = was[0]
			part.cast_shadow = was[1]
			part.remove_meta(&"drawn_as")


## Whether a roof or storey is lifted off (see lift).
static func lifted(node: Node) -> bool:
	return node.get_meta(&"lifted", false)


## Whether a drawn thing is drawn with a material that takes no shadows (a spruce's fronds),
## up close or as a batch of many.
static func takes_no_shadows(node: Node) -> bool:
	var mat: Material = (node as GeometryInstance3D).material_override
	var mesh: Mesh = null
	if node is MeshInstance3D:
		mesh = (node as MeshInstance3D).mesh
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		mesh = (node as MultiMeshInstance3D).multimesh.mesh
	if mat == null and mesh != null:
		for i in mesh.get_surface_count():
			if _unshadowed(mesh.surface_get_material(i)):
				return true
	return _unshadowed(mat)


static func _unshadowed(mat: Material) -> bool:
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader == Fern.NEEDLE_SHADER


## Whether a drawn thing is part of a wall: it or one of its parents carries WALL, and it is
## no floor (FLOOR).
static func is_wall(node: Node) -> bool:
	var up := node
	while up != null:
		if up.has_meta(FLOOR):
			return false
		if up.has_meta(WALL):
			return true
		up = up.get_parent()
	return false


## How far the point is outside the light's reach (lower comes first), or INF
## when the light needs no shadows.
static func shadow_score(light: Light3D, at: Vector3) -> float:
	if light.has_meta(NO_SHADOW) or not light.is_visible_in_tree() or light.light_energy <= 0.0:
		return INF
	var reach := reach_of(light)
	if reach < MIN_RANGE:
		return INF
	var outside := light.global_position.distance_to(at) - reach
	return outside if outside < VIEW else INF


static func reach_of(light: Light3D) -> float:
	if light is OmniLight3D:
		return (light as OmniLight3D).omni_range
	if light is SpotLight3D:
		return (light as SpotLight3D).spot_range
	return 0.0


func _focus_point() -> Vector3:
	if is_instance_valid(focus) and focus.is_inside_tree():
		return focus.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


## How many lights are picked to cast shadows right now.
func shadowed() -> int:
	return _picked.size()
