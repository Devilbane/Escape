class_name IceFish
extends Node3D
## Fish swimming under the ice of a frozen river or pond, seen from above like the game's camera sees it
## (they replace the fish the ground shader once drew from the side). They are the animated fish of the
## "Animated Fish Pack" by Quaternius (CC0, see assets/animals/fish/LICENSE.txt), shown as faint, ice-tinted
## shapes (see under_ice_fish.gdshader): each loops slowly round its own spot, on the water only.
##
## They are built the first time the ponds freeze (see Outdoor.set_ice) and shown while they are frozen.

const MODELS := [
	preload("res://assets/animals/fish/Fish1.fbx"),
	preload("res://assets/animals/fish/Fish2.fbx"),
]
const SHADER := preload("res://shaders/under_ice_fish.gdshader")
const MAX_FISH := 14
## Fish length (metres) and how fast it swims; a lazy pace under the ice.
const LENGTH_MIN := 0.38
const LENGTH_MAX := 0.56
const SPEED := 0.3
## How far from the bank a fish keeps (see Outdoor.pond_shore_at), and the ice it shows from.
const SHORE_MIN := 1.5
const SHOW_FROM := 0.6
## River fish seen from above: back colour and flank colour (perch, roach, trout, carp).
const COLOURS := [
	[Color(0.2, 0.28, 0.14), Color(0.66, 0.6, 0.34)],
	[Color(0.38, 0.42, 0.42), Color(0.78, 0.8, 0.76)],
	[Color(0.36, 0.28, 0.16), Color(0.72, 0.58, 0.32)],
	[Color(0.42, 0.3, 0.12), Color(0.8, 0.62, 0.3)],
]

var level: Outdoor
var _fish: Array[Dictionary] = []
var _fade := 0.0


## Puts fish on the open water of `ponds` (the pond tiles of the map, see Outdoor._pond_waters).
static func build(lvl: Outdoor, ponds: Array) -> IceFish:
	var school := IceFish.new()
	school.name = "IceFish"
	school.level = lvl
	lvl.add_child(school)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lvl.level_name + "eisfische")
	var spots: Array[Vector3] = []
	for w: Dictionary in ponds:
		var pos: Vector3 = w.pos
		if lvl.pond_shore_at(pos) >= SHORE_MIN + 0.3 and rng.randf() < 0.06:
			spots.append(pos)
	spots.shuffle()
	for i in mini(MAX_FISH, spots.size()):
		school._add_fish(spots[i], rng)
	school.set_process(false)
	school.visible = false
	return school


func _add_fish(home: Vector3, rng: RandomNumberGenerator) -> void:
	var kind := rng.randi() % MODELS.size()
	var model: Node3D = (MODELS[kind] as PackedScene).instantiate()
	var length := rng.randf_range(LENGTH_MIN, LENGTH_MAX)
	var holder := Node3D.new()
	holder.add_child(model)
	add_child(holder)
	# The models are modelled lying with their length along y and their back along z: turn the back up.
	model.rotation = Vector3(-PI * 0.5, 0, 0)
	# Whatever unit the model was made in, scale it to a river fish of `length` metres.
	var natural := 0.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var box := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		natural = maxf(natural, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	model.scale = Vector3.ONE * (length / maxf(natural, 0.0001))
	var palette: Array = COLOURS[rng.randi() % COLOURS.size()]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("back_color", Vector3((palette[0] as Color).r, (palette[0] as Color).g, (palette[0] as Color).b))
	mat.set_shader_parameter("flank_color", Vector3((palette[1] as Color).r, (palette[1] as Color).g, (palette[1] as Color).b))
	mat.set_shader_parameter("seed", rng.randf())
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and not player.get_animation_list().is_empty():
		var anim := player.get_animation_list()[0]
		player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		player.speed_scale = rng.randf_range(0.7, 1.1)
		player.play(anim)
		player.seek(rng.randf() * 1.2)
	holder.position = home + Vector3(0, 0.03, 0)
	_fish.append({"node": holder, "mat": mat, "home": home, "heading": rng.randf() * TAU, "t": rng.randf() * 20.0,
			"turn": rng.randf_range(0.25, 0.55), "speed": SPEED * rng.randf_range(0.7, 1.2)})


## How much of the water is frozen, 0 to 1 (see Outdoor.set_ice).
func set_ice(value: float) -> void:
	var on := value >= SHOW_FROM
	_fade = smoothstep(SHOW_FROM, 1.0, value)
	if visible != on:
		visible = on
		set_process(on)
	for f in _fish:
		(f.mat as ShaderMaterial).set_shader_parameter("fade", _fade)


func _process(delta: float) -> void:
	for f in _fish:
		var holder: Node3D = f.node
		f.t += delta
		var heading: float = f.heading + sin(f.t * 0.37 + f.turn * 9.0) * f.turn * delta * 2.0
		var dir := Vector3(sin(heading), 0, cos(heading))
		var step: float = f.speed * delta
		var next := holder.position + dir * step
		var home: Vector3 = f.home
		if level.pond_shore_at(next) < SHORE_MIN or next.distance_to(home) > 4.0:
			# Too near the bank or too far from home: turn back towards the home spot.
			var to_home := home - holder.position
			heading = lerp_angle(heading, atan2(to_home.x, to_home.z), minf(1.0, 3.0 * delta))
			dir = Vector3(sin(heading), 0, cos(heading))
			next = holder.position + dir * step * 0.5
		f.heading = heading
		holder.position = Vector3(next.x, holder.position.y, next.z)
		holder.rotation.y = heading + HEAD_TURN


## The models' heads are at their -y end, which points along +z once they are laid flat: already on the
## heading (sin h, cos h), so no extra turn.
const HEAD_TURN := 0.0
