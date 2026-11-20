class_name LightShadows
extends Node
## Walls block light: a torch, candle, fireplace or lantern does not shine
## through a wall into the room behind it or out of a house.
##
## Light only stops at walls when it casts shadows, and a shadow-casting point
## light costs a few render passes, so not every light gets them. Every few
## ticks the lights nearest the hero (the ones that can reach the part of the
## world on screen) cast shadows, BUDGET at most; the rest stay plain. A light
## too far from the hero to light anything on screen does not need them.
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
## The meta a light sets to never cast shadows.
const NO_SHADOW := &"no_wall_shadow"
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


func _on_node_added(node: Node) -> void:
	if node is OmniLight3D or node is SpotLight3D:
		_lights[node.get_instance_id()] = node
		var light: Light3D = node
		light.shadow_enabled = false
		light.shadow_bias = BIAS
		light.shadow_normal_bias = NORMAL_BIAS


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
		var score := shadow_score(light, at)
		if score == INF:
			_drop(light, at_once or not light.is_visible_in_tree())
			continue
		ranked.append([score - (KEEP if _picked.has(id) else 0.0), light])
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
