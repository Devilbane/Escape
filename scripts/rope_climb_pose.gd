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
	# Along the face: both hands high on the rock, the knees bent, the body kept upright.
	"shuffle": {"hips_y": -0.04, "spine": 6.0, "head": -24.0, "arm": 172.0, "elbow": 16.0, "hip_l": 34.0, "hip_r": 34.0, "knee_l": 64.0, "knee_r": 64.0},
	"kneel": ClimbPose.POSES["kneel"],
	"stand": {},
	# The foot feels for a hold while both hands keep the weight (the weight stays on the other leg).
	"probe_l": {"hips_y": -0.02, "spine": 8.0, "head": -30.0, "arm_l": 176.0, "elbow_l": 4.0, "arm_r": 150.0, "elbow_r": 22.0, "hip_l": 78.0, "knee_l": 105.0, "hip_r": 8.0, "knee_r": 22.0},
	"probe_r": {"hips_y": -0.02, "spine": 8.0, "head": -30.0, "arm_r": 176.0, "elbow_r": 4.0, "arm_l": 150.0, "elbow_l": 22.0, "hip_r": 78.0, "knee_r": 105.0, "hip_l": 8.0, "knee_l": 22.0},
	# Looking for the place for the nail, and testing the rope after it.
	"find_spot": {"spine": 6.0, "head": -24.0, "arm_l": 170.0, "elbow_l": 6.0, "arm_r": 140.0, "elbow_r": 48.0, "hip_l": 24.0, "hip_r": 8.0, "knee_l": 50.0, "knee_r": 60.0},
	"tug": {"spine": -8.0, "head": -12.0, "arm_l": 165.0, "elbow_l": 8.0, "arm_r": 105.0, "elbow_r": 55.0, "hip_l": 24.0, "hip_r": 8.0, "knee_l": 50.0, "knee_r": 60.0},
	# A slip, the rope going taut, the feet braced against the wall.
	"slip": {"hips_y": 0.05, "spine": -14.0, "head": 8.0, "arm_l": 165.0, "elbow_l": 10.0, "arm_r": 100.0, "elbow_r": 40.0, "hip_l": 58.0, "hip_r": -4.0, "knee_l": 90.0, "knee_r": 20.0},
	"rope_taut": {"spine": -18.0, "head": -4.0, "arm_l": 160.0, "elbow_l": 30.0, "arm_r": 172.0, "elbow_r": 14.0, "hip_l": 60.0, "hip_r": 40.0, "knee_l": 50.0, "knee_r": 40.0},
	"arrest": {"hips_y": -0.04, "spine": -10.0, "head": -10.0, "arm": 165.0, "elbow": 18.0, "hip_l": 84.0, "hip_r": 78.0, "knee_l": 22.0, "knee_r": 28.0},
	"rest": {"hips_y": -0.1, "spine": 14.0, "head": -14.0, "arm": 150.0, "elbow": 50.0, "hip_l": 28.0, "hip_r": 14.0, "knee_l": 50.0, "knee_r": 60.0},
	# Climbing down: a foot lowers to the next hold, hands let go one after the other.
	"down_l": {"spine": 10.0, "head": -26.0, "arm": 158.0, "elbow": 22.0, "hip_l": 10.0, "knee_l": 30.0, "hip_r": 50.0, "knee_r": 80.0},
	"down_r": {"spine": 10.0, "head": -26.0, "arm": 158.0, "elbow": 22.0, "hip_r": 10.0, "knee_r": 30.0, "hip_l": 50.0, "knee_l": 80.0},
}

## Keys of each phase: [when 0..1, pose]. The pull-up's hands take the weight at PULL_ROLL.
const PULL_ROLL := 0.4
## The pull-up has lifted the body by this point of the cycle.
const PULL_LIFTED := 0.78
const KEYS := {
	# Grab, the foot searches a hold, pull up.
	"pull_l": [[0.0, "hang"], [0.2, "reach_l"], [0.38, "reach_l"], [0.55, "probe_r"], [0.78, "pull"], [1.0, "hang"]],
	"pull_r": [[0.0, "hang"], [0.2, "reach_r"], [0.38, "reach_r"], [0.55, "probe_l"], [0.78, "pull"], [1.0, "hang"]],
	# Along the face (a traverse): the leading hand grips, the same-side foot feels for a hold, the body
	# shuffles over. It takes the weight at PULL_ROLL like a pull-up.
	"side_l": [[0.0, "hang"], [0.2, "reach_l"], [0.38, "reach_l"], [0.55, "probe_l"], [0.78, "shuffle"], [1.0, "hang"]],
	"side_r": [[0.0, "hang"], [0.2, "reach_r"], [0.38, "reach_r"], [0.55, "probe_r"], [0.78, "shuffle"], [1.0, "hang"]],
	# Find the spot, three blows, then clip the rope and test the hold.
	"hammer": [[0.0, "hang"], [0.1, "find_spot"], [0.22, "find_spot"], [0.32, "hammer_up"], [0.42, "hammer_hit"], [0.52, "hammer_up"], [0.62, "hammer_hit"], [0.72, "hammer_up"], [0.82, "hammer_hit"], [1.0, "hang"]],
	"thread": [[0.0, "hang"], [0.15, "thread"], [0.55, "thread"], [0.7, "tug"], [0.85, "tug"], [1.0, "hang"]],
	# Slip, fall, rope taut, arrest, stabilize.
	"slip": [[0.0, "reach_l"], [1.0, "slip"]],
	"fall": [[0.0, "slip"], [0.4, "fall"], [1.0, "fall"]],
	"arrest": [[0.0, "rope_taut"], [0.35, "rope_taut"], [0.6, "arrest"], [1.0, "hang"]],
	"rest": [[0.0, "hang"], [0.2, "rest"], [0.5, "hang"], [0.8, "rest"], [1.0, "hang"]],
	"desc_l": [[0.0, "hang"], [0.5, "down_l"], [1.0, "hang"]],
	"desc_r": [[0.0, "hang"], [0.5, "down_r"], [1.0, "hang"]],
	# Climb over the edge and stand up.
	"top": [[0.0, "pull"], [0.35, "push"], [0.6, "kneel"], [0.85, "kneel"], [1.0, "stand"]],
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
