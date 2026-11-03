class_name DragonHelpers
extends Node3D
## The old dragon's little helpers out in the open (see DragonHoard): at night
## small dragonlings flutter out of the lair's stone arch, one after another,
## each to something lying on the ground. It snatches it up, flies back into
## the mountain with it, and the hoard grows (Events.bus().loot_carried_off).
##
## They are shy: they wait while the hero stands right beside a thing, so
## nothing is snatched from under the hero's feet, and what the hero picks
## up first stays the hero's. At daybreak no new ones come out; the ones
## still out fly home. They are no foes: they cannot be fought and do no harm.

## At most this many out at once, one more every SPAWN_GAP seconds.
const MAX_OUT := 4
const SPAWN_GAP := 2.5
## How fast they fly (metres per second) and how high over the ground.
const SPEED := 7.0
const FLY_HEIGHT := 3.2
## They keep this far (metres) from the hero: a thing closer to the hero is
## left alone for now.
const SHY := 3.5
## The size of the dragon's model on them, and their ember-red tint.
const MODEL_SCALE := 0.16
const TINT := Color(1.0, 0.55, 0.3)

var level: Level
## Where they come out and go back in: the front of the arch.
var den := Vector3.ZERO
## The helpers out now: {"node", "target" (the pickup), "carry" (its node,
## once snatched), "home" (flying back)}.
var helpers: Array = []
var _spawn_timer := 0.0


func _init(l: Level, at: Vector3) -> void:
	level = l
	den = at
	name = "DragonHelpers"


func is_night() -> bool:
	return level is Outdoor and (level as Outdoor).night


func _process(delta: float) -> void:
	_spawn_timer = maxf(0.0, _spawn_timer - delta)
	if is_night() and _spawn_timer <= 0.0 and helpers.size() < MAX_OUT:
		var target := _next_target()
		if not target.is_empty():
			_send_out(target)
			_spawn_timer = SPAWN_GAP
	for h in helpers.duplicate():
		_fly(h, delta)


## The nearest thing on the ground to the den no helper is after yet and the
## hero does not stand beside.
func _next_target() -> Dictionary:
	var best := {}
	var best_dist := INF
	for p in level.floor_pickups():
		if helpers.any(func(h): return is_same(h.target, p)) or _hero_near(p.node.global_position):
			continue
		var d := _flat(p.node.global_position - den)
		if d < best_dist:
			best_dist = d
			best = p
	return best


func _hero_near(pos: Vector3) -> bool:
	var hero: Node3D = level.player
	return hero != null and is_instance_valid(hero) and _flat(hero.global_position - pos) < SHY


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _send_out(target: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Drachling"
	add_child(node)
	node.global_position = den + Vector3(0, 1.4, 0)
	var model: Node3D = load("res://assets/lair/Dragon.fbx").instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	node.add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TINT
		mat.emission_enabled = true
		mat.emission = TINT
		mat.emission_energy_multiplier = 0.35
		mi.material_override = mat
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("DragonArmature|Dragon_Flying"):
		anim.get_animation("DragonArmature|Dragon_Flying").loop_mode = Animation.LOOP_LINEAR
		anim.play("DragonArmature|Dragon_Flying")
		anim.speed_scale = 1.8
	var glow := OmniLight3D.new()
	glow.light_color = TINT
	glow.light_energy = 0.9
	glow.omni_range = 2.5
	node.add_child(glow)
	helpers.append({"node": node, "target": target, "carry": null, "home": false})


func _fly(h: Dictionary, delta: float) -> void:
	var node: Node3D = h.node
	if not is_instance_valid(node):
		helpers.erase(h)
		return
	var goal: Vector3
	if h.home:
		goal = den + Vector3(0, 1.4, 0)
	else:
		# The hero picked it up first, or walked up to it: back home.
		if not level._pickups.has(h.target) or not is_instance_valid(h.target.node) or _hero_near(h.target.node.global_position):
			h.home = true
			return
		var at: Vector3 = h.target.node.global_position
		var left := _flat(at - node.global_position)
		# High over the ground on the way, down to the thing at the end.
		goal = Vector3(at.x, lerpf(at.y + 0.6, FLY_HEIGHT, clampf(left / 6.0, 0.0, 1.0)), at.z)
	var step := goal - node.global_position
	var move := SPEED * delta
	if step.length() > 0.01:
		var flat := Vector3(step.x, 0, step.z)
		if flat.length() > 0.05:
			node.rotation.y = atan2(flat.x, flat.z)
	if step.length() <= move:
		node.global_position = goal
		if h.home:
			_go_in(h)
		else:
			_snatch(h)
		return
	node.global_position += step.normalized() * move


## Snatches the thing up: off the floor, held under the helper, and away.
func _snatch(h: Dictionary) -> void:
	var p: Dictionary = h.target
	var entry: Array = p.floor
	var carried := level.take_from_floor(p)
	h.home = true
	if carried == null:
		return
	Events.carried_off(str(entry[0]), str(entry[1]))
	carried.reparent(h.node, false)
	carried.position = Vector3(0, -0.5, 0)
	carried.scale = Vector3.ONE * 0.6
	for light in carried.find_children("*", "OmniLight3D", true, false):
		light.queue_free()
	h.carry = carried


## Home in the mountain: it shrinks into the arch and is gone.
func _go_in(h: Dictionary) -> void:
	helpers.erase(h)
	var node: Node3D = h.node
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.01, 0.3)
	tween.tween_callback(node.queue_free)
