class_name BedRise
extends RefCounted
## Going to bed and getting up again, for the hero and for the villagers who sleep (see Game._climb_into_bed,
## VillageBeds). The body is posed bone by bone with ClimbPose's angles over the rig's standing pose, the
## way the horn is blown (see HornBlow): the game has no clips for it.
##
## Going to bed (TUCK_KEYS): a hop onto the mattress, sitting on its edge, then swinging the legs up,
## lying back on the pillow and pulling the blanket up to the chest (see BedBlanket).
## Waking up (RISE_KEYS): the blanket is pushed off, one leg and then the other swings out over the
## side of the bed, the sleeper sits on the rim, stretches both arms over the head, yawns with the eyes
## shut and the mouth wide open, shakes it off and slides down onto the floor.
##
## All places are in the bed's own space: x across (the side rail on the left at CosyBed.LEFT), y up,
## z along it with the foot towards +z. A key says where the hips are (`hips`), how far the body is
## tipped back (`tilt`, degrees: -90 lies on the back with the head at the pillows) and turned about the
## vertical (`yaw`, degrees, 0 faces the foot of the bed, -90 faces out over the left rail).
## `side` (-1 or 1) mirrors a sequence for a bed one gets out of on its right.

## Where the hips are, lying and sitting on the mattress, from the bed's origin. Lying: across, the middle of
## the mattress; along, the middle of the head (HEAD_REACH from the hips: it is a big round head) lies
## HEAD_ON_PILLOW below the middle of the pillows (see Level.PILLOW), so the face rests on them while the
## back of the head and the hair stay clear of the headboard and the wall behind it.
const LYING := Vector3((CosyBed.LEFT + CosyBed.RIGHT) * 0.5, 0.93, Level.PILLOW.z + HEAD_ON_PILLOW + HEAD_REACH)
## How far below the middle of the pillows (towards the foot) the middle of the head lies.
const HEAD_ON_PILLOW := 0.2
const SITTING := Vector3(-0.3, 0.97, 0.12)
## On the rim: the hips a little in from the rail, the thighs over the mattress and the shins hanging.
const RIM := Vector3(-0.42, 0.97, 0.12)
## Standing on the floor beside the bed: the hips' height above the floor.
const BESIDE := Vector3(-1.1, HIP_HEIGHT, 0.12)
## How far the middle of the head's mesh lies from the hips when lying on the back (rig units, body scale 1).
const HEAD_REACH := 1.276
## The hips' height above the model's origin when standing (rig units, at body scale 1).
const HIP_HEIGHT := 0.392

const POSES := {
	# On the back, legs straight, arms by the sides.
	"lie": {"arm": 12.0, "elbow": 14.0, "head": 4.0},
	# Hauling the blanket up: both hands at the cloth in front of the chest.
	"haul": {"arm": 58.0, "elbow": 70.0, "head": 4.0},
	# Sitting up in bed, legs stretched out ahead, hands propped behind.
	"sit_up": {"spine": 6.0, "head": -4.0, "arm": -28.0, "elbow": 8.0, "hip_l": 82.0, "hip_r": 82.0, "knee_l": 6.0, "knee_r": 6.0},
	# The first leg swings out over the rail while the other is still in bed.
	"leg_one": {"spine": 8.0, "head": -2.0, "arm": -10.0, "elbow": 10.0, "hip_l": 84.0, "knee_l": 8.0, "hip_r": 92.0, "knee_r": 34.0},
	# Both over the rail, the shins swinging.
	"legs_out": {"spine": 10.0, "head": 0.0, "arm": 6.0, "elbow": 16.0, "hip_l": 90.0, "knee_l": 52.0, "hip_r": 92.0, "knee_r": 84.0},
	# Sitting on the rim, shins hanging, hands on the mattress at the sides.
	"rim": {"spine": 12.0, "chest": 4.0, "head": 4.0, "arm": 4.0, "elbow": 10.0, "hip_l": 92.0, "knee_l": 92.0, "hip_r": 92.0, "knee_r": 92.0},
	# The stretch: both arms straight up, the back arched, the head thrown back.
	"stretch": {"spine": -10.0, "chest": -12.0, "head": -26.0, "arm": 176.0, "elbow": 4.0, "hip_l": 92.0, "knee_l": 92.0, "hip_r": 92.0, "knee_r": 92.0},
	# The arms come down, shoulders sag, the head nods forward.
	"slump": {"spine": 18.0, "chest": 6.0, "head": 10.0, "arm": 20.0, "elbow": 28.0, "hip_l": 92.0, "knee_l": 80.0, "hip_r": 92.0, "knee_r": 80.0},
	# Pushing off the rim: legs straightening, the body leaning forward.
	"slide": {"spine": 16.0, "chest": 4.0, "head": 0.0, "arm": 28.0, "elbow": 20.0, "hip_l": 40.0, "knee_l": 40.0, "hip_r": 40.0, "knee_r": 40.0},
	"stand": {},
}

## Going to bed, from the hero standing at the bed's side: [seconds, pose, tilt, yaw, hips, yawn (0..1), eyes shut].
const TUCK_KEYS := [
	[0.00, "stand", 0.0, -90.0, BESIDE, 0.0, false],
	[0.45, "slide", 0.0, -90.0, RIM + Vector3(-0.3, -0.35, 0.0), 0.0, false],
	[0.90, "slump", -2.0, -90.0, RIM, 0.0, false],
	[1.40, "rim", -2.0, -90.0, RIM, 0.0, false],
	[1.90, "legs_out", -10.0, -75.0, SITTING, 0.0, false],
	[2.50, "sit_up", -18.0, 0.0, SITTING, 0.0, false],
	[3.20, "haul", -75.0, 0.0, LYING, 0.0, false],
	[3.90, "lie", -84.0, 0.0, LYING, 0.0, true],
]
## Waking up, from lying asleep.
const RISE_KEYS := [
	[0.00, "lie", -84.0, 0.0, LYING, 0.0, true],
	[0.90, "haul", -80.0, 0.0, LYING, 0.0, true],
	[1.80, "sit_up", -16.0, 0.0, SITTING, 0.0, true],
	[2.60, "leg_one", -10.0, -45.0, SITTING, 0.0, false],
	[3.30, "legs_out", -4.0, -90.0, RIM, 0.0, false],
	[3.90, "rim", -2.0, -90.0, RIM, 0.0, false],
	[4.60, "stretch", 0.0, -90.0, RIM, 0.0, true],
	[5.30, "stretch", 0.0, -90.0, RIM, 1.0, true],
	[6.00, "stretch", 0.0, -90.0, RIM, 1.0, true],
	[6.70, "slump", 0.0, -90.0, RIM, 0.0, false],
	[7.30, "slump", 0.0, -90.0, RIM, 0.0, false],
	[7.90, "slide", 0.0, -90.0, RIM + Vector3(-0.3, -0.35, 0.0), 0.0, false],
	[8.40, "stand", 0.0, -90.0, BESIDE, 0.0, false],
]

## The moments of the waking up when the yawn starts (the stretch has reached its top) and the fox wakes.
const YAWN_AT := 4.9
const FOX_AT := 3.0
## Seconds the blanket is pushed off after the waking starts (it is off before the sleeper sits up).
const BLANKET_OFF_AT := 0.2
## And pulled up after going to bed starts.
const BLANKET_ON_AT := 3.0


const TUCK_LENGTH := 3.9
const RISE_LENGTH := 8.4


static func length(keys: Array) -> float:
	return float((keys[keys.size() - 1] as Array)[0])


## The state at `t` seconds into `keys`, mirrored for `side`: {pose, tilt, yaw, hips, yawn, shut}.
static func at(keys: Array, t: float, side := -1.0) -> Dictionary:
	t = clampf(t, 0.0, length(keys))
	var out := {}
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if t <= float(b[0]) or i == keys.size() - 1:
			var span := maxf(0.0001, float(b[0]) - float(a[0]))
			var k := smoothstep(0.0, 1.0, clampf((t - float(a[0])) / span, 0.0, 1.0))
			out = {
				"pose": ClimbPose.mix(POSES[a[1]], POSES[b[1]], k),
				"tilt": lerpf(float(a[2]), float(b[2]), k),
				"yaw": lerpf(float(a[3]), float(b[3]), k),
				"hips": (a[4] as Vector3).lerp(b[4], k),
				"yawn": lerpf(float(a[5]), float(b[5]), k),
				"shut": bool(a[6]) if k < 0.5 else bool(b[6]),
			}
			break
	if side > 0.0:
		out.yaw = -float(out.yaw)
		var p: Dictionary = out.pose
		var swapped := p.duplicate()
		for k in ["hip", "knee"]:
			swapped[k + "_l"] = p.get(k + "_r", 0.0)
			swapped[k + "_r"] = p.get(k + "_l", 0.0)
		out.pose = swapped
	return out


## Poses `model` (a body's model, on `skeleton` with `base` from ClimbPose.base_of) as `state` says, in the
## bed at `bed_pos` turned by `bed_rot`, and returns where the body's origin has to be (the world): the
## hips are where the state puts them, whatever the tilt and turn.
static func pose(model: Node3D, skeleton: Skeleton3D, base: Dictionary, state: Dictionary, bed_pos: Vector3, bed_rot: float, side := -1.0) -> Vector3:
	ClimbPose.apply(skeleton, base, state.pose)
	var scale := model.scale.x
	var turn := Basis(Vector3.UP, bed_rot + deg_to_rad(float(state.yaw))) * Basis(Vector3.RIGHT, deg_to_rad(float(state.tilt)))
	model.basis = turn.scaled(Vector3.ONE * scale)
	model.position = Vector3.ZERO
	var hips: Vector3 = state.hips
	if side > 0.0:
		hips.x = -0.15 - hips.x
	# Standing on the floor, a body of another size has its hips higher or lower (the mattress is the same for all).
	hips.y += HIP_HEIGHT * (scale - 1.0) * (1.0 - clampf((hips.y - HIP_HEIGHT) / (LYING.y - HIP_HEIGHT), 0.0, 1.0))
	# Lying, a bigger body's head is further from its hips: the hips move down the bed so the head stays put.
	hips.z += HEAD_REACH * (scale - 1.0) * clampf((hips.y - HIP_HEIGHT) / (LYING.y - HIP_HEIGHT), 0.0, 1.0)
	var world_hips := bed_pos + Basis(Vector3.UP, bed_rot) * hips
	return world_hips - turn * Vector3(0.0, HIP_HEIGHT * scale, 0.0)


## Opens the mouth of a face for a yawn (`amount` 0..1) and closes it again at 0: a dark oval on the
## head, built the first time.
static func yawn(model: Node3D, amount: float) -> void:
	var slot := HairLook.head_slot(model)
	if slot == null or not slot.has_meta("bind"):
		return
	var mouth := slot.get_node_or_null("Yawn") as MeshInstance3D
	if mouth == null:
		if amount <= 0.0:
			return
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 14
		sphere.rings = 8
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.05, 0.06)
		mat.roughness = 0.9
		mouth = MeshInstance3D.new()
		mouth.name = "Yawn"
		mouth.mesh = sphere
		mouth.material_override = mat
		mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slot.add_child(mouth)
	# In the head mesh's space, just under the nose where the lips are, opening wider and taller.
	mouth.transform = (slot.get_meta("bind") as Transform3D) * Transform3D(
			Basis.from_scale(Vector3(0.1, 0.14, 0.05) * amount + Vector3(0.001, 0.001, 0.001)),
			Vector3(0.0, BodyLook.LIP_HEIGHT - 0.04 * amount, BodyLook.LIP_FRONT - 0.01))
	mouth.visible = amount > 0.02


## Puts the weapon and the shield away (`armed` false) or takes them in hand again: nobody goes to bed with
## a knife in their hand. The hand slots hold whatever is carried (see Player._show_held).
static func arm(model: Node3D, armed: bool) -> void:
	for slot in ["handslot_r", "handslot_l"]:
		var hand := model.find_child(slot, true, false) as Node3D
		if hand != null:
			hand.visible = armed


## The model upright again, at its own scale and without any offset (after posing for bed).
static func clear(model: Node3D) -> void:
	var scale := model.scale.x
	model.basis = Basis.from_scale(Vector3.ONE * scale)
	model.position = Vector3.ZERO


## Which side of the bed one steps out of: -1 for the left rail, 1 for the right, the one `floor_spot`
## (where the floor beside the bed is open) lies on, the left when it lies at the foot.
static func side_for(bed_pos: Vector3, bed_rot: float, floor_spot: Vector3) -> float:
	var local := Basis(Vector3.UP, bed_rot).inverse() * (floor_spot - bed_pos)
	return 1.0 if local.x > 0.9 else -1.0


## Where one stands on the floor beside the bed (the world), on the side `side`.
static func beside(bed_pos: Vector3, bed_rot: float, side := -1.0) -> Vector3:
	var spot := BESIDE
	if side > 0.0:
		spot.x = -0.15 - spot.x
	return bed_pos + Basis(Vector3.UP, bed_rot) * spot


## How wide and tall a body is that tries a spot beside the bed (see choose_side): a little slimmer than the
## hero, so the bed's own solid next to the spot does not count, but a chest or a wall in the way does.
const PROBE_RADIUS := 0.3
const PROBE_HEIGHT := 1.5


## The side to step out of the bed by: the one `side_for` prefers unless something stands in the way
## there (a wall, a chest, another bed: a body that big stood on the floor where the feet land finds
## it, also low things like a chest, which a ray at hip height flew over), then the other one. If both
## are blocked, the one with the fewer things in the way. `level` is the node whose world holds the bed.
static func choose_side(level: Node3D, bed_pos: Vector3, bed_rot: float, floor_spot: Vector3, exclude: Array = []) -> float:
	var preferred := side_for(bed_pos, bed_rot, floor_spot)
	if level == null or not level.is_inside_tree():
		return preferred
	var space := level.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = PROBE_RADIUS
	capsule.height = PROBE_HEIGHT
	var best := preferred
	var best_hits := 1000
	for side: float in [preferred, -preferred]:
		var spot := beside(bed_pos, bed_rot, side)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.exclude = exclude
		query.transform = Transform3D(Basis(), Vector3(spot.x, bed_pos.y + 0.15 + PROBE_HEIGHT * 0.5, spot.z))
		var hits := space.intersect_shape(query, 8).size()
		if hits == 0:
			return side
		if hits < best_hits:
			best_hits = hits
			best = side
	return best


## Plays `keys` on `body` (a Player: bed_pose) as a step of `tween`, in the bed at `bed_pos` turned by `rot`;
## `events` is a list of [seconds, Callable] run once when that moment passes.
static func play(tween: Tween, body: Object, keys: Array, bed_pos: Vector3, rot: float, side: float, events: Array = []) -> void:
	var fired := {}
	tween.tween_method(func(t: float):
		body.bed_pose(at(keys, t, side), bed_pos, rot, side)
		for i in events.size():
			if not fired.has(i) and t >= float((events[i] as Array)[0]):
				fired[i] = true
				((events[i] as Array)[1] as Callable).call(), 0.0, length(keys), length(keys))
