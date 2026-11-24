class_name RopeClimbPose
extends RefCounted
## The body of the hero climbing a rock face on a rope, as poses of the rig (see ClimbPose, whose bones
## and `apply` it uses): the hang, a hand reaching up and gripping, the pull-up, the swing of the hammer
## that drives an iron nail into the rock, the rope threaded through it, and a fall.
## Angles in degrees, per arm / leg where a key has _l or _r (see ClimbPose.apply).

const POSES := {
	"hang": {"hips_y": -0.05, "spine": 6.0, "head": -22.0, "arm": 168.0, "elbow": 8.0, "hip_l": 22.0, "hip_r": 8.0, "knee_l": 42.0, "knee_r": 58.0},
	"reach_l": {"hips_y": -0.02, "spine": 4.0, "head": -26.0, "arm_l": 178.0, "elbow_l": 4.0, "arm_r": 128.0, "elbow_r": 62.0, "hip_l": 12.0, "hip_r": 36.0, "knee_l": 55.0, "knee_r": 70.0},
	"reach_r": {"hips_y": -0.02, "spine": 4.0, "head": -26.0, "arm_r": 178.0, "elbow_r": 4.0, "arm_l": 128.0, "elbow_l": 62.0, "hip_l": 36.0, "hip_r": 12.0, "knee_l": 70.0, "knee_r": 55.0},
	"pull": {"hips_y": 0.04, "spine": 20.0, "chest": 6.0, "head": -14.0, "arm": 112.0, "elbow": 100.0, "hip_l": 62.0, "hip_r": 20.0, "knee_l": 96.0, "knee_r": 52.0},
	"push": {"hips_y": 0.08, "spine": 10.0, "head": -18.0, "arm": 150.0, "elbow": 25.0, "hip_l": 30.0, "hip_r": 14.0, "knee_l": 60.0, "knee_r": 30.0},
	# Hammering: the left hand holds on high, the right arm swings the hammer.
	"hammer_up": {"hips_y": -0.03, "spine": 8.0, "head": -22.0, "arm_l": 172.0, "elbow_l": 6.0, "arm_r": 150.0, "elbow_r": 112.0, "hip_l": 26.0, "hip_r": 10.0, "knee_l": 52.0, "knee_r": 64.0},
	"hammer_hit": {"hips_y": -0.03, "spine": 14.0, "head": -30.0, "arm_l": 172.0, "elbow_l": 6.0, "arm_r": 96.0, "elbow_r": 8.0, "hip_l": 26.0, "hip_r": 10.0, "knee_l": 52.0, "knee_r": 64.0},
	# Threading the rope through the nail: both hands together before the face.
	"thread": {"hips_y": -0.04, "spine": 8.0, "head": -34.0, "arm_l": 128.0, "elbow_l": 82.0, "arm_r": 120.0, "elbow_r": 96.0, "hip_l": 24.0, "hip_r": 8.0, "knee_l": 50.0, "knee_r": 62.0},
	"fall": {"hips_y": 0.0, "spine": -10.0, "head": 6.0, "arm_l": 150.0, "elbow_l": 24.0, "arm_r": 125.0, "elbow_r": 30.0, "hip_l": 46.0, "hip_r": 8.0, "knee_l": 84.0, "knee_r": 38.0},
	"kneel": ClimbPose.POSES["kneel"],
}

## Keys of each phase: [when 0..1, pose]. The pull-up's hands take the weight at PULL_ROLL.
const PULL_ROLL := 0.42
const KEYS := {
	"pull_l": [[0.0, "hang"], [0.28, "reach_l"], [0.42, "reach_l"], [0.75, "pull"], [1.0, "hang"]],
	"pull_r": [[0.0, "hang"], [0.28, "reach_r"], [0.42, "reach_r"], [0.75, "pull"], [1.0, "hang"]],
	"hammer": [[0.0, "hang"], [0.15, "hammer_up"], [0.3, "hammer_hit"], [0.42, "hammer_up"], [0.55, "hammer_hit"], [0.67, "hammer_up"], [0.8, "hammer_hit"], [1.0, "hang"]],
	"thread": [[0.0, "hang"], [0.2, "thread"], [0.8, "thread"], [1.0, "hang"]],
	"fall": [[0.0, "reach_l"], [0.3, "fall"], [1.0, "fall"]],
	"top": [[0.0, "pull"], [0.45, "push"], [0.7, "kneel"], [1.0, "kneel"]],
}


## The pose of `phase` (a key of KEYS) at time `u` (0..1).
static func at(phase: String, u: float) -> Dictionary:
	var keys: Array = KEYS[phase]
	u = clampf(u, 0.0, 1.0)
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if u <= float(b[0]) or i == keys.size() - 1:
			var span := maxf(0.001, float(b[0]) - float(a[0]))
			var t := smoothstep(0.0, 1.0, clampf((u - float(a[0])) / span, 0.0, 1.0))
			return ClimbPose.mix(POSES[a[1]], POSES[b[1]], t)
	return {}
