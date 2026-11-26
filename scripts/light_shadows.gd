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

## How many lights cast shadows at once, at most.
const BUDGET := 8
## How many do with the picked graphics preset (see Graphics): fewer on weak graphics cards.
static var budget := BUDGET
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
## The meta of a node whose drawn parts grow on the outside of walls (the ivy, vines and grapes): they
## go on UNSHADOWED_LAYER too, so no indoor lamp lights them through the wall.
const OUTSIDE_ONLY := &"lit_from_outside_only"
## The meta of the village's ground (the meadow's pieces): it goes on GROUND_LAYER, so the candles on the
## walls of the villagers' houses (WALL_CANDLE) do not light it through the windows.
const GROUND := &"village_ground"
const GROUND_LAYER := 1 << 14
## The meta of a candle on a wall, next to a window: its light would graze out through the pane onto the
## grass, so it leaves the ground out of its light. The room lamps keep theirs: the light through the
## windows is wanted.
const WALL_CANDLE := &"wall_candle"
## The meta of a wall mesh that is only the outside of the walls (the inner faces are a mesh of their own):
## it is drawn on UNSHADOWED_LAYER, which the lamps inside leave out of their light, so no candle glows on
## its stone, ledges and window frames. It is not what stops the light: a copy of it that is not drawn
## (WALL_SHADOW) sits on WALL_LAYER and casts the shadows.
const OUTSIDE_WALL := &"outside_wall"
const WALL_SHADOW := &"wall_shadow_copy"
## The render layer everything is drawn on unless told otherwise.
const DEFAULT_LAYER := 1
## How much sooner an indoor lamp is picked (metres of distance, more than any outdoor lamp's).
const INDOOR_FIRST := 100.0
## The meta of the two warm-up lamps (see warm_up): the picking leaves them alone.
const WARM := &"shadow_warmup"
## The warm-up lamps' reach: far enough to touch everything in a level or the village copy.
const WARM_RANGE := 1000.0
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
## The lamps made stronger while they cast shadows (see _match_lamps), by instance id: their
## own colour, and the colour written over it.
var _matched := {}
## The warm-up lamps lit for a level's warm-up frame (see warm_up), freed after it.
var _warm: Array[Light3D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for light: Node in get_tree().root.find_children("*", "Light3D", true, false):
		_on_node_added(light)
	for drawn: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		_on_node_added(drawn)


func _on_node_added(node: Node) -> void:
	if node.name == &"VillageCopy" and node.get_parent() is WorldPreload:
		# The copy of the village drawn behind the title: its shaders are built with walls'
		# shadows too, so a lamp that gains them in play has its shaders ready.
		warm_up(node as Node3D)
		return
	if node is GeometryInstance3D:
		if node.has_meta(GROUND):
			var ground := node as GeometryInstance3D
			ground.layers = (ground.layers & ~DEFAULT_LAYER) | GROUND_LAYER
		elif node.has_meta(WALL_SHADOW):
			(node as GeometryInstance3D).layers = WALL_LAYER
		elif node.has_meta(OUTSIDE_WALL) and node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			_split_outside_wall(node as MeshInstance3D)
		elif is_wall(node):
			(node as GeometryInstance3D).layers |= WALL_LAYER
		elif takes_no_shadows(node) or is_outside_only(node):
			# Moved off the default layer, not only onto this one: a light reaches whatever shares a
			# layer with its cull mask, so with layer 1 kept the indoor lamps still lit the spruces.
			var geo := node as GeometryInstance3D
			geo.layers = (geo.layers & ~DEFAULT_LAYER) | UNSHADOWED_LAYER
	elif node is OmniLight3D or node is SpotLight3D:
		var light: Light3D = node
		if light.has_meta(WARM):
			return
		_lights[node.get_instance_id()] = node
		light.shadow_enabled = false
		light.shadow_bias = BIAS
		light.shadow_normal_bias = NORMAL_BIAS
		light.shadow_caster_mask = WALL_LAYER | LID_LAYER


## Draws an outside wall (OUTSIDE_WALL) where the lamps inside do not light it, and lets a copy of it that
## is not drawn stop their light.
func _split_outside_wall(wall: MeshInstance3D) -> void:
	wall.layers = (wall.layers & ~DEFAULT_LAYER & ~WALL_LAYER) | UNSHADOWED_LAYER
	var copy := MeshInstance3D.new()
	copy.name = "WallShadow"
	copy.mesh = wall.mesh
	copy.set_meta(WALL_SHADOW, true)
	copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	copy.layers = WALL_LAYER
	wall.add_child.call_deferred(copy)


func _process(delta: float) -> void:
	if not _warm.is_empty() and not LevelWarmup.active():
		# The level's warm-up frame is drawn: back to the usual few lamps at once.
		for light in _warm:
			if is_instance_valid(light):
				light.queue_free()
		_warm.clear()
		refresh(true)
	_fade(delta / FADE)
	_match_lamps()
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
			if light.has_meta(WALL_CANDLE):
				light.light_cull_mask &= ~GROUND_LAYER
		var score := shadow_score(light, at)
		if score == INF:
			_drop(light, at_once or not light.is_visible_in_tree())
			continue
		ranked.append([score - (KEEP if _picked.has(id) else 0.0) - (INDOOR_FIRST if light.has_meta(INDOOR) else 0.0), light])
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	for i in ranked.size():
		var light: Light3D = ranked[i][1]
		if i < budget:
			_pick(light, at_once)
		else:
			_drop(light, at_once)
	if at_once:
		_fade(1.0)
		if LevelWarmup.active() and _warm.is_empty() and is_inside_tree():
			_warm = warm_up(self, at)


## Lights everything around `at` (under `parent`) for the frames it is drawn in with a
## wall-shadowed point light and spot light of nearly no strength, so the renderer builds
## every material's shaders for lamps with shadows now, in a dark warm-up frame. Built
## only when a lamp first gains its shadows as the hero walks (every few ticks one does),
## they made the game stutter. Returns the two lamps; they go with `parent`.
static func warm_up(parent: Node, at := Vector3.ZERO) -> Array[Light3D]:
	var omni := OmniLight3D.new()
	omni.omni_range = WARM_RANGE
	var spot := SpotLight3D.new()
	spot.spot_range = WARM_RANGE
	spot.spot_angle = 89.0
	var made: Array[Light3D] = [omni, spot]
	for light in made:
		light.set_meta(WARM, true)
		light.light_energy = 0.001
		light.shadow_enabled = true
		light.shadow_bias = BIAS
		light.shadow_normal_bias = NORMAL_BIAS
		light.shadow_caster_mask = WALL_LAYER | LID_LAYER
		parent.add_child(light)
	if parent is Node3D:
		omni.position = Vector3(0, 30, 0)
		spot.position = Vector3(0, 200, 0)
	else:
		omni.global_position = at + Vector3(0, 30, 0)
		spot.global_position = at + Vector3(0, 200, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	return made


func _pick(light: Light3D, at_once: bool) -> void:
	var id := light.get_instance_id()
	_walled_in(light, true)
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
		_walled_in(light, false)
		return
	if at_once:
		light.shadow_enabled = false
		_fading.erase(id)
		_walled_in(light, false)
	else:
		_fading[id] = light


## An indoor lamp (INDOOR) lights only while it casts its wall shadows: one left without them (more
## lit houses in view than the budget) would shine straight through its house's walls onto the ivy
## and the snow outside, so once its shadows have faded it lights nothing until it is picked again.
static func _walled_in(light: Light3D, shadowed: bool) -> void:
	if not light.has_meta(INDOOR):
		return
	if shadowed and light.has_meta(&"cull_was"):
		light.light_cull_mask = light.get_meta(&"cull_was")
		light.remove_meta(&"cull_was")
	elif not shadowed and not light.has_meta(&"cull_was"):
		light.set_meta(&"cull_was", light.light_cull_mask)
		light.light_cull_mask = 0


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
				_walled_in(light, false)


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


## Whether a drawn thing is ivy or another growth on the outside of walls (OUTSIDE_ONLY on it or a parent).
static func is_outside_only(node: Node) -> bool:
	var up := node
	while up != null:
		if up.has_meta(OUTSIDE_ONLY):
			return true
		up = up.get_parent()
	return false


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


## On the modern renderer a lamp that casts shadows shines Graphics.lamp() times stronger, fading
## in and out with its shadows, as OpenGL shows such a lamp brighter (see Graphics.LAMP_MATCH).
## Its colour carries the boost, not its strength: the lamps' owners keep setting and tweening their
## strength (flicker, dusk), and must read back what they set.
func _match_lamps() -> void:
	var boost := Graphics.lamp()
	for id in _lights.keys():
		var held = _lights[id]
		if not is_instance_valid(held) or not held is OmniLight3D:
			_matched.erase(id)
			continue
		var lamp: OmniLight3D = held
		var rec: Dictionary = _matched.get(id, {})
		if not lamp.shadow_enabled or boost == 1.0:
			if not rec.is_empty():
				# Its shadows are gone: back to its own colour, unless its owner set a new one.
				if lamp.light_color.is_equal_approx(rec.wrote):
					lamp.light_color = rec.color
				_matched.erase(id)
			continue
		if rec.is_empty():
			rec = {"color": lamp.light_color, "wrote": lamp.light_color}
			_matched[id] = rec
		# Whatever the owner set since the last frame is the lamp's own colour again.
		if not lamp.light_color.is_equal_approx(rec.wrote):
			rec.color = lamp.light_color
		var own: Color = rec.color
		var lit := own.srgb_to_linear() * lerpf(1.0, boost, lamp.shadow_opacity)
		lit.a = own.a
		lamp.light_color = lit.linear_to_srgb()
		rec.wrote = lamp.light_color
