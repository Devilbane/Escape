class_name ClimbPose
extends RefCounted
## The body of the hero climbing out of a pit onto the ground above, as poses of the rig
## (see the sketch in the climbing request: crouch, jump, grab the ledge with both hands,
## hang, pull up with a knee onto the edge, kneel, stand). The game has no climbing clip,
## so the climb is played by blending these poses bone by bone, with the body carried
## along a path (forward and up, in metres from the start spot and from the top of the
## ledge). Used by Player._pit_climb_step.
##
## A pose is angles in degrees, all "positive = forward / upward / bending":
##   hips_y: the hips' drop in metres (negative = lower);  spine, chest, head: lean forward;
##   arm: raise of both arms forward (180 = straight up);  elbow: bend of both elbows
##   (arm_l, arm_r, elbow_l, elbow_r: one arm's own, over arm and elbow);
##   hip_l, hip_r: leg raised forward;  knee_l, knee_r: knee bent (shin folded back).

const PHASE_ORDER := ["stand", "crouch", "reach", "hang", "pull", "knee", "kneel"]

const POSES := {
	"stand": {},
	"crouch": {"hips_y": -0.14, "spine": 0.0, "chest": 0.0, "head": -8.0, "arm": -30.0, "elbow": 20.0, "hip_l": 40.0, "hip_r": 40.0, "knee_l": 75.0, "knee_r": 75.0},
	"reach": {"spine": -4.0, "head": -20.0, "arm": 135.0, "hip_l": 10.0, "hip_r": 0.0, "knee_l": 50.0, "knee_r": 35.0},
	"hang": {"spine": 0.0, "head": -25.0, "arm": 125.0, "hip_l": 0.0, "hip_r": 0.0, "knee_l": 35.0, "knee_r": 55.0},
	"pull": {"spine": 24.0, "chest": 8.0, "head": -12.0, "arm": 120.0, "elbow": 105.0, "hip_l": 105.0, "hip_r": 12.0, "knee_l": 115.0, "knee_r": 30.0},
	"knee": {"hips_y": -0.12, "spine": 34.0, "chest": 6.0, "arm": 70.0, "elbow": 20.0, "hip_l": 95.0, "hip_r": -10.0, "knee_l": 95.0, "knee_r": 105.0},
	"kneel": {"hips_y": -0.18, "spine": 6.0, "arm": 25.0, "elbow": 35.0, "hip_l": 85.0, "hip_r": -2.0, "knee_l": 90.0, "knee_r": 110.0},
}

## The path: [when (0..1), pose, forward (m towards the wall, the wall's face is 0),
## height (m, 0 = the top of the ledge)]. The hero starts on the pit floor.
## A null forward or height at the first keys means where the hero starts.
const KEYS := [
	[0.00, "stand", null, null],
	[0.07, "crouch", null, null],
	[0.17, "reach", -0.45, -1.36],
	[0.24, "hang", -0.42, -1.36],
	## The hold: when the climb reaches U_ROLL the pull-up may fail (see Player).
	[0.42, "pull", -0.08, -0.80],
	[0.56, "knee", 0.28, -0.22],
	[0.72, "kneel", 0.45, 0.0],
	[0.86, "kneel", 0.52, 0.0],
	[1.00, "stand", 0.60, 0.0],
]
## Clearance of the wall: the most the hero may stand forward (m from the wall's face)
## so that no part of the body below the ledge top (the pit's side) sinks into the wall,
## for each fiftieth of the climb. Measured on the skinned rig by tools/climb_clearance.gd;
## tests/climb_pose.gd checks it still holds.
## From FREE_FROM on the hero is up on the ground, with no wall left to keep clear of.
const FREE_FROM := 0.70
const CLEAR_STEPS := 50
const CLEAR := [-0.57, -0.56, -0.54, -0.53, -0.52, -0.5, -0.64, -0.62, -0.49, -0.44, -0.5, -0.54, -0.56, -0.55, -0.5, -0.44, -0.44, -0.46, -0.47, -0.48, -0.45, -0.45, -0.44, -0.45, -0.46, -0.47, -0.48, -0.49, -0.47, -0.47, -0.47, -0.47, 0.13, 0.17, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0]
## Where the pull-up begins: the hang, and the moment the hands may slip.
const U_ROLL := 0.26

const BONES := {
	"hips": "hips", "spine": "spine", "chest": "chest", "head": "head",
	"ua_l": "upperarm.l", "ua_r": "upperarm.r", "la_l": "lowerarm.l", "la_r": "lowerarm.r",
	"ul_l": "upperleg.l", "ul_r": "upperleg.r", "ll_l": "lowerleg.l", "ll_r": "lowerleg.r",
}


## The pose (Dictionary of angles) blending `a` and `b` by `t`.
static func mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a.keys() + b.keys():
		out[k] = lerpf(float(a.get(k, 0.0)), float(b.get(k, 0.0)), t)
	return out


## The pose and the body's place (x: forward, y: height) at time `u` (0..1) of the climb.
## `start_height` is the height of the pit floor below the ledge top (negative),
## `start_forward` how far the hero stands from the wall face (negative).
static func at(u: float, start_height: float, start_forward := -0.4) -> Dictionary:
	u = clampf(u, 0.0, 1.0)
	for i in range(1, KEYS.size()):
		var k0: Array = KEYS[i - 1]
		var k1: Array = KEYS[i]
		if u <= float(k1[0]) or i == KEYS.size() - 1:
			var span := float(k1[0]) - float(k0[0])
			var t := smoothstep(0.0, 1.0, clampf((u - float(k0[0])) / span, 0.0, 1.0))
			var y0 := start_height if k0[3] == null else float(k0[3])
			var y1 := start_height if k1[3] == null else float(k1[3])
			var wanted := lerpf(start_forward if k0[2] == null else float(k0[2]), start_forward if k1[2] == null else float(k1[2]), t)
			return {
				"pose": mix(POSES[k0[1]], POSES[k1[1]], t),
				"forward": clear_of_wall(u, wanted),
				"height": lerpf(y0, y1, t),
			}
	return {"pose": {}, "forward": 0.0, "height": 0.0}


## The rotation each bone has in the standing pose (read once, from the rig as it stands).
static func base_of(sk: Skeleton3D) -> Dictionary:
	var base := {}
	for key in BONES:
		var i := sk.find_bone(BONES[key])
		base[key] = {"q": sk.get_bone_pose_rotation(i), "p": sk.get_bone_pose_position(i)}
	return base


## Poses the rig: `pose` as from at(), over the standing `base` (see base_of).
static func apply(sk: Skeleton3D, base: Dictionary, pose: Dictionary) -> void:
	var angle := func(k: String) -> float: return deg_to_rad(float(pose.get(k, 0.0)))
	var turn := func(bone: String, axis: Vector3, rad: float) -> void:
		var i := sk.find_bone(BONES[bone])
		sk.set_bone_pose_rotation(i, (base[bone].q as Quaternion) * Quaternion(axis, rad))
	turn.call("hips", Vector3.RIGHT, 0.0)
	var hips := sk.find_bone("hips")
	# hips_x shifts the body sideways and "lean" tips the spine to a side (a traverse, see RopeClimbPose).
	sk.set_bone_pose_position(hips, (base.hips.p as Vector3) + Vector3(float(pose.get("hips_x", 0.0)), float(pose.get("hips_y", 0.0)), 0))
	var spine_i := sk.find_bone(BONES["spine"])
	sk.set_bone_pose_rotation(spine_i, (base["spine"].q as Quaternion) * Quaternion(Vector3.RIGHT, angle.call("spine")) * Quaternion(Vector3.BACK, angle.call("lean")))
	turn.call("chest", Vector3.RIGHT, angle.call("chest"))
	turn.call("head", Vector3.RIGHT, angle.call("head"))
	# Each arm may have its own angle (arm_l, elbow_l, ...: a ladder climb, see LadderPose).
	var side := func(k: String, s: String) -> float: return deg_to_rad(float(pose.get(k + s, pose.get(k, 0.0))))
	# An arm may also reach out to its side (out_l, out_r: swung out; lift_l, lift_r: raised): the hand that
	# reaches along the face for the next hold, seen from behind.
	var ua_l := sk.find_bone(BONES["ua_l"])
	var ua_r := sk.find_bone(BONES["ua_r"])
	sk.set_bone_pose_rotation(ua_l, (base["ua_l"].q as Quaternion) * Quaternion(Vector3.RIGHT, angle.call("lift_l")) * Quaternion(Vector3.UP, -angle.call("out_l")) * Quaternion(Vector3.BACK, -side.call("arm", "_l")))
	sk.set_bone_pose_rotation(ua_r, (base["ua_r"].q as Quaternion) * Quaternion(Vector3.RIGHT, angle.call("lift_r")) * Quaternion(Vector3.UP, angle.call("out_r")) * Quaternion(Vector3.BACK, side.call("arm", "_r")))
	turn.call("la_l", Vector3.BACK, -side.call("elbow", "_l"))
	turn.call("la_r", Vector3.BACK, side.call("elbow", "_r"))
	# A leg may also swing out to its side (abd_l, abd_r): a foot reaching for a hold along the face.
	var ul_l := sk.find_bone(BONES["ul_l"])
	var ul_r := sk.find_bone(BONES["ul_r"])
	sk.set_bone_pose_rotation(ul_l, (base["ul_l"].q as Quaternion) * Quaternion(Vector3.RIGHT, -angle.call("hip_l")) * Quaternion(Vector3.BACK, -angle.call("abd_l")))
	sk.set_bone_pose_rotation(ul_r, (base["ul_r"].q as Quaternion) * Quaternion(Vector3.RIGHT, -angle.call("hip_r")) * Quaternion(Vector3.BACK, angle.call("abd_r")))
	turn.call("ll_l", Vector3.RIGHT, angle.call("knee_l"))
	turn.call("ll_r", Vector3.RIGHT, angle.call("knee_r"))


## `forward` held back so that the body stays clear of the wall (see CLEAR). The first
## moments of the climb, the step back into the crouch, ease the hero out of the wall.
static func clear_of_wall(u: float, forward: float) -> float:
	if CLEAR.is_empty():
		return forward
	var at := u * CLEAR_STEPS
	var i := clampi(int(at), 0, CLEAR_STEPS - 1)
	var limit := lerpf(float(CLEAR[i]), float(CLEAR[i + 1]), at - i)
	return lerpf(forward, minf(forward, limit), smoothstep(0.0, 0.07, u))


## How far the body reaches forward (z) among the parts that are below the ledge top, in
## metres from the rig's origin, with the feet at `height` (negative: below the ledge).
## The hands and forearms near the ledge top are left out: they grip it. Used to measure
## CLEAR (tools/climb_clearance.gd) and to check it (tests/climb_pose.gd).
static func front_below_ledge(sk: Skeleton3D, height: float) -> float:
	var front := -1e9
	for node in sk.get_children():
		var mi := node as MeshInstance3D
		if mi == null or mi.skin == null:
			continue
		var is_arm := str(mi.name).begins_with("Rogue_Arm")
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null:
				continue
			var per: int = bones.size() / points.size()
			for i in points.size():
				var p := Vector3.ZERO
				for k in per:
					var w: float = weights[i * per + k]
					if w > 0.0:
						var slot: int = bones[i * per + k]
						var bone := mi.skin.get_bind_bone(slot)
						if bone < 0:
							bone = sk.find_bone(mi.skin.get_bind_name(slot))
						p += w * ((sk.get_bone_global_pose(bone) * mi.skin.get_bind_pose(slot)) * points[i])
				var y := p.y + height
				if y < -0.06 and not (is_arm and y > -0.15):
					front = maxf(front, p.z)
	return front
