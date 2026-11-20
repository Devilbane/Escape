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
##   arm: raise of both arms forward (180 = straight up);  elbow: bend of both elbows;
##   hip_l, hip_r: leg raised forward;  knee_l, knee_r: knee bent (shin folded back).

const PHASE_ORDER := ["stand", "crouch", "reach", "hang", "pull", "knee", "kneel"]

const POSES := {
	"stand": {},
	"crouch": {"hips_y": -0.16, "spine": 28.0, "chest": 6.0, "arm": -35.0, "elbow": 20.0, "hip_l": 70.0, "hip_r": 70.0, "knee_l": 100.0, "knee_r": 100.0},
	"reach": {"spine": -4.0, "arm": 170.0, "hip_l": 25.0, "hip_r": 5.0, "knee_l": 55.0, "knee_r": 30.0},
	"hang": {"spine": 0.0, "arm": 178.0, "hip_l": 12.0, "hip_r": 25.0, "knee_l": 25.0, "knee_r": 55.0},
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
	[0.17, "reach", -0.22, -1.38],
	[0.24, "hang", -0.20, -1.38],
	## The hold: when the climb reaches U_ROLL the pull-up may fail (see Player).
	[0.42, "pull", -0.08, -0.80],
	[0.56, "knee", 0.28, -0.22],
	[0.72, "kneel", 0.45, 0.0],
	[0.86, "kneel", 0.52, 0.0],
	[1.00, "stand", 0.60, 0.0],
]
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
			return {
				"pose": mix(POSES[k0[1]], POSES[k1[1]], t),
				"forward": lerpf(start_forward if k0[2] == null else float(k0[2]), start_forward if k1[2] == null else float(k1[2]), t),
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
	sk.set_bone_pose_position(hips, (base.hips.p as Vector3) + Vector3(0, float(pose.get("hips_y", 0.0)), 0))
	turn.call("spine", Vector3.RIGHT, angle.call("spine"))
	turn.call("chest", Vector3.RIGHT, angle.call("chest"))
	turn.call("head", Vector3.RIGHT, angle.call("head"))
	turn.call("ua_l", Vector3.BACK, -angle.call("arm"))
	turn.call("ua_r", Vector3.BACK, angle.call("arm"))
	turn.call("la_l", Vector3.BACK, -angle.call("elbow"))
	turn.call("la_r", Vector3.BACK, angle.call("elbow"))
	turn.call("ul_l", Vector3.RIGHT, -angle.call("hip_l"))
	turn.call("ul_r", Vector3.RIGHT, -angle.call("hip_r"))
	turn.call("ll_l", Vector3.RIGHT, angle.call("knee_l"))
	turn.call("ll_r", Vector3.RIGHT, angle.call("knee_r"))
