class_name WaterYoke
extends Node3D
## The shoulder yoke Hanna the water carrier wears: a curved, carved beam across the shoulders with a
## hemp rope and an iron hook at each end and a hooped wooden bucket on each hook. Hung from the chest
## bone, so it rides with her stride, and the buckets swing on their ropes: a little with each step,
## more when she hurries, and they settle when she stands. The buckets are empty on the way back to the
## fountain and full of water on the way to the shops and the tavern (see `full`, WaterRound).
## Her hands rest on the beam (see YokeArms).

## Where the beam rests, from the chest bone (the rig's own space: y up, the face towards +z).
const REST := Vector3(0, 0.3, -0.1)
## Half the beam's length; the ropes hang from its ends.
const HALF := 0.72
## How far the ends dip below the neck.
const DIP := 0.13
const ROPE := 0.4
const BUCKET_H := 0.3
const BUCKET_R_BOTTOM := 0.125
const BUCKET_R_TOP := 0.155

const OAK := Color(0.62, 0.45, 0.28)
const OAK_DARK := Color(0.5, 0.35, 0.21)
const OAK_PALE := Color(0.72, 0.55, 0.36)
const STAVE_TONES := [Color(0.66, 0.49, 0.31), Color(0.58, 0.42, 0.26), Color(0.7, 0.53, 0.34), Color(0.54, 0.39, 0.24)]
const LEATHER := Color(0.4, 0.26, 0.16)
const HEMP := Color(0.78, 0.68, 0.46)
const HOOP := Color(0.24, 0.23, 0.23)
const WET := Color(0.32, 0.22, 0.14)
const WATER := Color(0.2, 0.45, 0.62, 0.82)
## The swing of a bucket, in radians, walking and running.
const SWING_WALK := 0.1
const SWING_RUN := 0.17
## How fast the swing builds up and dies away (per second).
const EASE := 4.0

## Whether the buckets hold water.
var full := false:
	set(value):
		full = value
		for w in _water:
			w.visible = value
## The animation player whose clip is playing (for the step phase).
var player: AnimationPlayer
var _pivots: Array[Node3D] = []
var _water: Array[MeshInstance3D] = []
var _time := 0.0
var _swing := 0.0
var _roll := 0.0

static var _water_mat: StandardMaterial3D


## Hangs a yoke on `model`'s chest bone and returns it, or null if the rig has none.
static func attach(model: Node3D, anim: AnimationPlayer) -> WaterYoke:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty() or (found[0] as Skeleton3D).find_bone("chest") < 0:
		return null
	var sk: Skeleton3D = found[0]
	var slot := BoneAttachment3D.new()
	slot.name = "YokeSlot"
	slot.bone_name = "chest"
	sk.add_child(slot)
	var yoke := WaterYoke.new()
	yoke.name = "WaterYoke"
	yoke.player = anim
	yoke.position = REST
	slot.add_child(yoke)
	yoke.build()
	return yoke


## The beam's height above the neck at `x` along it: the ends curve down over the shoulders.
static func beam_y(x: float) -> float:
	var t := absf(x) / HALF
	return -DIP * t * t


func build() -> void:
	var w := VillageProps.W.WOOD
	var iron := VillageProps.W.IRON
	# The beam: a curved bar of oak in short, slightly tapering pieces, thicker over the shoulders.
	var b := VillageProps.W.Builder.new()
	var steps := 14
	for i in steps:
		var x0 := -HALF + 2.0 * HALF * i / steps
		var x1 := -HALF + 2.0 * HALF * (i + 1) / steps
		var thick := lerpf(0.058, 0.045, absf((x0 + x1) * 0.5) / HALF)
		b.bar(Vector3(x0, beam_y(x0), 0), Vector3(x1, beam_y(x1), 0), thick, OAK if i % 2 == 0 else OAK_DARK, w, 8)
	# Rounded knobs at the ends, a carved neck dip's worth of lighter wood, and growth rings on the cut ends.
	for s in [-1.0, 1.0]:
		b.cylinder(Vector3(s * (HALF - 0.01), beam_y(HALF), 0), 0.052, 0.06, 0.06, OAK_PALE, w, 10, Basis(Vector3.BACK, -s * PI / 2.0))
		b.cylinder(Vector3(s * (HALF + 0.05), beam_y(HALF), 0), 0.036, 0.03, 0.012, OAK_DARK, w, 10, Basis(Vector3.BACK, -s * PI / 2.0))
		# The strap that holds the rope at the end.
		b.cylinder(Vector3(s * (HALF - 0.06), beam_y(HALF) - 0.052, 0), 0.034, 0.034, 0.104, LEATHER, w, 8)
	b.bar(Vector3(-0.2, beam_y(0.2) + 0.005, 0), Vector3(0.2, beam_y(0.2) + 0.005, 0), 0.052, LEATHER, w, 10)
	# A worn pad on each shoulder.
	for s in [-1.0, 1.0]:
		b.bar(Vector3(s * 0.12, beam_y(0.12) + 0.004, 0), Vector3(s * 0.34, beam_y(0.34) + 0.004, 0), 0.05, LEATHER.lightened(0.08), w, 10)
	# Notches carved in the beam where the hands rest.
	for s in [-1.0, 1.0]:
		for k in 2:
			b.cylinder(Vector3(s * (0.43 + k * 0.05), beam_y(0.45) + 0.036, 0), 0.04, 0.04, 0.012, OAK_DARK.darkened(0.15), w, 8, Basis(Vector3.RIGHT, PI / 2.0))
	b.finish(self, Vector3.ZERO, true, true)
	# The two ropes with their hooks and buckets, each swinging from a pivot at the beam's end.
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "Bucket_L" if s < 0.0 else "Bucket_R"
		pivot.position = Vector3(s * (HALF - 0.06), beam_y(HALF) - 0.1, 0)
		add_child(pivot)
		_pivots.append(pivot)
		var h := VillageProps.W.Builder.new()
		# The rope, twisted: two thin strands, with a knot at the top and an iron hook on the end.
		h.bar(Vector3(0.007, 0, 0), Vector3(-0.007, -ROPE, 0.003), 0.008, HEMP, w, 5)
		h.bar(Vector3(-0.007, 0, 0), Vector3(0.007, -ROPE, -0.003), 0.008, HEMP.darkened(0.12), w, 5)
		h.cylinder(Vector3(0, -0.03, 0), 0.016, 0.016, 0.03, HEMP.darkened(0.2), w, 6)
		var hook_top := -ROPE
		h.bar(Vector3(0, hook_top, 0), Vector3(0, hook_top - 0.045, 0), 0.007, HOOP, iron, 5)
		h.bar(Vector3(0, hook_top - 0.045, 0), Vector3(0.025, hook_top - 0.07, 0), 0.007, HOOP, iron, 5)
		h.bar(Vector3(0.025, hook_top - 0.07, 0), Vector3(0.0, hook_top - 0.085, 0), 0.007, HOOP, iron, 5)
		h.finish(pivot, Vector3.ZERO, false, true)
		var bucket := Node3D.new()
		bucket.name = "Bucket"
		bucket.position = Vector3(0, hook_top - 0.085, 0)
		pivot.add_child(bucket)
		_build_bucket(bucket)
	full = false


## One bucket whose bail's top (the origin) hangs on the hook: staves, two iron hoops, a rope handle... an
## iron bail, and the water.
func _build_bucket(parent: Node3D) -> void:
	var w := VillageProps.W.WOOD
	var iron := VillageProps.W.IRON
	var rim := -0.15
	var bottom := rim - BUCKET_H
	var b := VillageProps.W.Builder.new()
	# The inside first: a dark, wet core that shows as the hollow under the rim.
	b.cylinder(Vector3(0, bottom + 0.02, 0), BUCKET_R_BOTTOM - 0.012, BUCKET_R_TOP - 0.02, BUCKET_H - 0.045, WET, w, 16)
	# Staves: each a slightly bowed plank, in four tones, with the odd darker one.
	var staves := 14
	for k in staves:
		var a := TAU * k / staves
		var out := Vector3(cos(a), 0, sin(a))
		var tone: Color = STAVE_TONES[k % STAVE_TONES.size()]
		var width := TAU * ((BUCKET_R_BOTTOM + BUCKET_R_TOP) * 0.5) / staves * 0.96
		var lean := atan2(BUCKET_R_TOP - BUCKET_R_BOTTOM, BUCKET_H)
		var basis := Basis(Vector3.UP, -a) * Basis(Vector3.BACK, lean)
		b.frustum(out * (BUCKET_R_BOTTOM + 0.006) + Vector3(0, bottom, 0), Vector2(0.026, width), Vector2(0.026, width * 1.04), BUCKET_H, tone, w, basis)
	# The bottom board, a little proud, and two iron hoops with a rivet each.
	b.cylinder(Vector3(0, bottom - 0.008, 0), BUCKET_R_BOTTOM + 0.004, BUCKET_R_BOTTOM + 0.004, 0.026, OAK_DARK, w, 16)
	for hp in [[0.045, 0.012], [BUCKET_H - 0.05, 0.016]]:
		var y: float = bottom + hp[0]
		var r := lerpf(BUCKET_R_BOTTOM, BUCKET_R_TOP, hp[0] / BUCKET_H) + 0.014
		b.cylinder(Vector3(0, y, 0), r, r, 0.03, HOOP, iron, 20, Basis(), false)
		b.cylinder(Vector3(0, y + 0.03, 0), r, r - 0.012, 0.004, HOOP, iron, 20, Basis(), false)
		b.cylinder(Vector3(r - 0.004, y + 0.012, 0), 0.01, 0.007, 0.012, HOOP.lightened(0.15), iron, 6, Basis(Vector3.BACK, -PI / 2.0))
	# The bail: an iron arc from lug to lug over the rim, to the hook.
	var lug := BUCKET_R_TOP + 0.012
	var seg := 10
	for i in seg:
		var a0 := PI * i / seg
		var a1 := PI * (i + 1) / seg
		b.bar(Vector3(-cos(a0) * lug, rim + sin(a0) * 0.15, 0), Vector3(-cos(a1) * lug, rim + sin(a1) * 0.15, 0), 0.006, HOOP, iron, 5)
	for s in [-1.0, 1.0]:
		b.cylinder(Vector3(s * lug, rim - 0.012, 0), 0.014, 0.014, 0.024, HOOP.lightened(0.1), iron, 6)
	b.finish(parent, Vector3.ZERO, true, true)
	# The water: a glossy disc just under the rim, so a full bucket shows it from above.
	var water := MeshInstance3D.new()
	water.name = "Water"
	var disc := CylinderMesh.new()
	disc.top_radius = BUCKET_R_TOP - 0.022
	disc.bottom_radius = BUCKET_R_TOP - 0.022
	disc.height = 0.012
	disc.radial_segments = 20
	water.mesh = disc
	water.material_override = _water_material()
	water.position = Vector3(0, rim - 0.015, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(water)
	_water.append(water)


static func _water_material() -> StandardMaterial3D:
	if _water_mat == null:
		_water_mat = StandardMaterial3D.new()
		_water_mat.albedo_color = WATER
		_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water_mat.roughness = 0.05
		_water_mat.metallic_specular = 0.9
	return _water_mat


## The swing of the buckets, forward and back, at `phase` (0..1) of a walk cycle: twice a cycle, one
## swing a step, `amount` radians wide; the second bucket lags a little behind the first.
static func swing_at(phase: float, amount: float, lag: float) -> float:
	return amount * sin(TAU * 2.0 * phase - lag)


func _process(delta: float) -> void:
	if not visible or _pivots.is_empty():
		return
	_time += delta
	var clip: String = player.current_animation if player != null else ""
	var moving: bool = player != null and player.is_playing() and clip != "Idle" and YokeArms.carries_in(clip)
	var amount := 0.0
	var phase := 0.0
	if moving and player.current_animation_length > 0.0:
		phase = player.current_animation_position / player.current_animation_length
		amount = SWING_RUN if clip.begins_with("Running") else SWING_WALK
	_swing = lerpf(_swing, amount, clampf(EASE * delta, 0.0, 1.0))
	# The beam rolls a little as the shoulders rise and fall, once a stride.
	_roll = lerpf(_roll, 0.03 * sin(TAU * phase) * (1.0 if moving else 0.0), clampf(EASE * 2.0 * delta, 0.0, 1.0))
	rotation.z = _roll
	for i in _pivots.size():
		var idle := 0.012 * sin(_time * 1.9 + i * 1.3)
		_pivots[i].rotation.x = swing_at(phase, _swing, 0.5 + 0.35 * i) + idle
		_pivots[i].rotation.z = -_roll * 0.8 + 0.01 * sin(_time * 1.4 + i)
