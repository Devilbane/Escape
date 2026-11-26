class_name RopeClimbPose
extends RefCounted
## The body of the hero climbing a rock face on a rope, as poses of the rig (see ClimbPose, whose bones
## and `apply` it uses): the hang, a hand reaching up and gripping, the pull-up, the swing of the hammer
## that drives an iron nail into the rock, the rope threaded through it, and a fall.
## Angles in degrees, per arm / leg where a key has _l or _r (see ClimbPose.apply).

const POSES := {
	"hang": {"hips_y": -0.05, "spine": 6.0, "head": -22.0, "arm": 168.0, "elbow": 8.0, "hip_l": 22.0, "hip_r": 8.0, "knee_l": 42.0, "knee_r": 58.0, "abd_l": 16.0, "abd_r": 16.0},
	"reach_l": {"hips_y": -0.02, "spine": 4.0, "head": -26.0, "arm_l": 0.0, "out_l": 75.0, "lift_l": 75.0, "elbow_l": 0.0, "arm_r": 128.0, "elbow_r": 62.0, "hip_l": 6.0, "hip_r": 10.0, "knee_l": 8.0, "knee_r": 12.0, "abd_l": 14.0, "abd_r": 24.0},
	"reach_r": {"hips_y": -0.02, "spine": 4.0, "head": -26.0, "arm_r": 0.0, "out_r": 75.0, "lift_r": 75.0, "elbow_r": 0.0, "arm_l": 128.0, "elbow_l": 62.0, "hip_l": 10.0, "hip_r": 6.0, "knee_l": 12.0, "knee_r": 8.0, "abd_l": 24.0, "abd_r": 14.0},
	# Looking up for the next hold (a real climber pauses here, still, with the weight on the feet).
	# The wind-up before a push or a reach: sink down, bend both knees deep, arms straight.
	"sink": {"hips_y": -0.16, "spine": 10.0, "head": -30.0, "arm": 170.0, "elbow": 6.0, "hip_l": 62.0, "hip_r": 58.0, "knee_l": 96.0, "knee_r": 92.0, "abd_l": 26.0, "abd_r": 26.0},
	# The small hop before a reach (the springs of the sink let go): legs and arms fully stretched.
	"hop": {"hips_y": 0.06, "spine": 2.0, "head": -26.0, "arm": 178.0, "elbow": 0.0, "hip_l": 6.0, "hip_r": 4.0, "knee_l": 6.0, "knee_r": 4.0, "abd_l": 14.0, "abd_r": 14.0},
	# The rock-over (see the sketch in docs/climbing_animation_sheet.md): a foot stepped high with the knee out
	# wide (the frog stance), then the hips pushed in over that foot and the body stood up on it.
	"frog_l": {"hips_y": -0.1, "spine": 8.0, "head": -26.0, "arm_l": 0.0, "out_l": 75.0, "lift_l": 75.0, "elbow_l": 0.0, "arm_r": 130.0, "elbow_r": 50.0, "hip_l": 100.0, "knee_l": 112.0, "abd_l": 85.0, "hip_r": 6.0, "knee_r": 6.0, "abd_r": 24.0},
	"frog_r": {"hips_y": -0.1, "spine": 8.0, "head": -26.0, "arm_r": 0.0, "out_r": 75.0, "lift_r": 75.0, "elbow_r": 0.0, "arm_l": 130.0, "elbow_l": 50.0, "hip_r": 100.0, "knee_r": 112.0, "abd_r": 85.0, "hip_l": 6.0, "knee_l": 6.0, "abd_l": 24.0},
	"rock_l": {"hips_y": 0.04, "spine": 16.0, "head": -20.0, "arm_l": 0.0, "out_l": 75.0, "lift_l": 75.0, "elbow_l": 0.0, "arm_r": 120.0, "elbow_r": 70.0, "hip_l": 62.0, "knee_l": 72.0, "abd_l": 44.0, "hip_r": -4.0, "knee_r": 4.0, "abd_r": 14.0},
	"rock_r": {"hips_y": 0.04, "spine": 16.0, "head": -20.0, "arm_r": 0.0, "out_r": 75.0, "lift_r": 75.0, "elbow_r": 0.0, "arm_l": 120.0, "elbow_l": 70.0, "hip_r": 62.0, "knee_r": 72.0, "abd_r": 44.0, "hip_l": -4.0, "knee_l": 4.0, "abd_l": 14.0},
	"look": {"hips_y": -0.05, "spine": 8.0, "head": -40.0, "arm": 168.0, "elbow": 8.0, "hip_l": 22.0, "hip_r": 8.0, "knee_l": 42.0, "knee_r": 58.0, "abd_l": 16.0, "abd_r": 16.0},
	"pull": {"hips_y": 0.04, "spine": 20.0, "chest": 6.0, "head": -14.0, "arm": 112.0, "elbow": 100.0, "hip_l": 62.0, "hip_r": 20.0, "knee_l": 96.0, "knee_r": 52.0, "abd_l": 26.0, "abd_r": 20.0},
	"push": {"hips_y": 0.08, "spine": 10.0, "head": -18.0, "arm": 150.0, "elbow": 25.0, "hip_l": 30.0, "hip_r": 14.0, "knee_l": 60.0, "knee_r": 30.0, "abd_l": 18.0, "abd_r": 18.0},
	# Hammering: the left hand holds on high, the right arm swings the hammer.
	"hammer_up": {"hips_y": -0.03, "spine": 8.0, "head": -22.0, "arm_l": 172.0, "elbow_l": 6.0, "arm_r": 150.0, "elbow_r": 112.0, "hip_l": 26.0, "hip_r": 10.0, "knee_l": 52.0, "knee_r": 64.0},
	"hammer_hit": {"hips_y": -0.03, "spine": 14.0, "head": -30.0, "arm_l": 172.0, "elbow_l": 6.0, "arm_r": 96.0, "elbow_r": 8.0, "hip_l": 26.0, "hip_r": 10.0, "knee_l": 52.0, "knee_r": 64.0},
	# Threading the rope through the nail: both hands together before the face.
	"thread": {"hips_y": -0.04, "spine": 8.0, "head": -34.0, "arm_l": 128.0, "elbow_l": 82.0, "arm_r": 120.0, "elbow_r": 96.0, "hip_l": 24.0, "hip_r": 8.0, "knee_l": 50.0, "knee_r": 62.0},
	"fall": {"hips_y": 0.0, "spine": -10.0, "head": 6.0, "arm_l": 150.0, "elbow_l": 24.0, "arm_r": 125.0, "elbow_r": 30.0, "hip_l": 46.0, "hip_r": 8.0, "knee_l": 84.0, "knee_r": 38.0},
	# Along the face: both hands high on the rock, the knees bent, the body kept upright.
	"shuffle": {"hips_y": -0.04, "spine": 6.0, "head": -24.0, "arm": 172.0, "elbow": 16.0, "hip_l": 34.0, "hip_r": 34.0, "knee_l": 64.0, "knee_r": 64.0, "abd_l": 22.0, "abd_r": 22.0},
	# A traverse to the right (see TRAVERSE for the left): the leading hand reaches far out to the next hold,
	# the body tips towards it, the leading foot swings out and feels for a hold, then the weight goes over
	# and the other hand and foot follow. The hang above is where it starts and ends.
	"t_reach_r": {"hips_y": -0.03, "hips_x": 0.04, "lean": 5.0, "spine": 4.0, "head": -22.0, "arm_r": 0.0, "out_r": 90.0, "lift_r": 40.0, "elbow_r": 0.0, "arm_l": 176.0, "elbow_l": 6.0, "hip_l": 22.0, "hip_r": 10.0, "knee_l": 44.0, "knee_r": 56.0},
	"t_grip_r": {"hips_y": -0.03, "hips_x": 0.08, "lean": 8.0, "spine": 4.0, "head": -22.0, "arm_r": 0.0, "out_r": 90.0, "lift_r": 55.0, "elbow_r": 0.0, "arm_l": 176.0, "elbow_l": 6.0, "hip_l": 22.0, "hip_r": 10.0, "knee_l": 44.0, "knee_r": 56.0},
	"t_foot_r": {"hips_y": -0.02, "hips_x": 0.12, "lean": 12.0, "spine": 6.0, "head": -26.0, "arm_r": 0.0, "out_r": 90.0, "lift_r": 62.0, "elbow_r": 0.0, "arm_l": 174.0, "elbow_l": 8.0, "hip_l": 14.0, "hip_r": 0.0, "abd_r": 84.0, "knee_r": 0.0, "knee_l": 50.0},
	"t_shift_r": {"hips_y": -0.04, "hips_x": 0.0, "lean": -2.0, "spine": 6.0, "head": -24.0, "arm_r": 150.0, "elbow_r": 24.0, "arm_l": 160.0, "elbow_l": 30.0, "hip_l": 30.0, "abd_l": 22.0, "hip_r": 30.0, "knee_l": 62.0, "knee_r": 62.0},
	# The weight goes over onto the new hold: both feet stay on the rock, the trailing hand and foot follow.
	"t_over_r": {"hips_y": -0.03, "hips_x": 0.05, "lean": 3.0, "spine": 6.0, "head": -24.0, "arm_r": 0.0, "out_r": 40.0, "lift_r": 70.0, "elbow_r": 20.0, "arm_l": 160.0, "elbow_l": 24.0, "hip_l": 34.0, "abd_l": 30.0, "hip_r": 30.0, "abd_r": 16.0, "knee_l": 60.0, "knee_r": 60.0},
	"kneel": ClimbPose.POSES["kneel"],
	"stand": {},
	# The foot feels for a hold while both hands keep the weight (the weight stays on the other leg).
	"probe_l": {"hips_y": -0.02, "spine": 8.0, "head": -30.0, "arm_l": 176.0, "elbow_l": 4.0, "arm_r": 150.0, "elbow_r": 22.0, "hip_l": 78.0, "knee_l": 105.0, "hip_r": 8.0, "knee_r": 22.0, "abd_l": 36.0, "abd_r": 14.0},
	"probe_r": {"hips_y": -0.02, "spine": 8.0, "head": -30.0, "arm_r": 176.0, "elbow_r": 4.0, "arm_l": 150.0, "elbow_l": 22.0, "hip_r": 78.0, "knee_r": 105.0, "hip_l": 8.0, "knee_l": 22.0, "abd_r": 36.0, "abd_l": 14.0},
	# Looking for the place for the nail, and testing the rope after it.
	"find_spot": {"spine": 6.0, "head": -24.0, "arm_l": 170.0, "elbow_l": 6.0, "arm_r": 140.0, "elbow_r": 48.0, "hip_l": 24.0, "hip_r": 8.0, "knee_l": 50.0, "knee_r": 60.0},
	"tug": {"spine": -8.0, "head": -12.0, "arm_l": 165.0, "elbow_l": 8.0, "arm_r": 105.0, "elbow_r": 55.0, "hip_l": 24.0, "hip_r": 8.0, "knee_l": 50.0, "knee_r": 60.0},
	# A slip, the rope going taut, the feet braced against the wall.
	"slip": {"hips_y": 0.05, "spine": -14.0, "head": 8.0, "arm_l": 165.0, "elbow_l": 10.0, "arm_r": 100.0, "elbow_r": 40.0, "hip_l": 58.0, "hip_r": -4.0, "knee_l": 90.0, "knee_r": 20.0},
	"rope_taut": {"spine": -18.0, "head": -4.0, "arm_l": 160.0, "elbow_l": 30.0, "arm_r": 172.0, "elbow_r": 14.0, "hip_l": 60.0, "hip_r": 40.0, "knee_l": 50.0, "knee_r": 40.0},
	"arrest": {"hips_y": -0.04, "spine": -10.0, "head": -10.0, "arm": 165.0, "elbow": 18.0, "hip_l": 84.0, "hip_r": 78.0, "knee_l": 22.0, "knee_r": 28.0},
	"rest": {"hips_y": -0.1, "spine": 14.0, "head": -14.0, "arm": 150.0, "elbow": 50.0, "hip_l": 28.0, "hip_r": 14.0, "knee_l": 50.0, "knee_r": 60.0, "abd_l": 14.0, "abd_r": 14.0},
	# Climbing down: a foot lowers to the next hold, hands let go one after the other.
	"down_l": {"spine": 10.0, "head": -26.0, "arm": 158.0, "elbow": 22.0, "hip_l": 10.0, "knee_l": 30.0, "hip_r": 50.0, "knee_r": 80.0, "abd_l": 30.0, "abd_r": 14.0},
	"down_r": {"spine": 10.0, "head": -26.0, "arm": 158.0, "elbow": 22.0, "hip_r": 10.0, "knee_r": 30.0, "hip_l": 50.0, "knee_l": 80.0, "abd_r": 30.0, "abd_l": 14.0},
}

## Keys of each phase: [when 0..1, pose]. The pull-up's hands take the weight at PULL_ROLL.
const PULL_ROLL := 0.55
## The pull-up has lifted the body by this point of the cycle.
const PULL_LIFTED := 0.88
const KEYS := {
	# Grab, the foot searches a hold, pull up.
	# The rhythm of a real climb: look and settle, a quick reach, the grip, the foot placed and weighted, the
	# push up with the legs, rest in the hang. (See docs/climbing_animation_sheet.md.)
	"pull_l": [[0.0, "hang"], [0.08, "look"], [0.14, "sink"], [0.2, "sink"], [0.27, "hop"], [0.34, "reach_l"], [0.42, "reach_l"], [0.52, "frog_r"], [0.6, "frog_r"], [0.74, "rock_r"], [0.86, "push"], [1.0, "hang"]],
	"pull_r": [[0.0, "hang"], [0.08, "look"], [0.14, "sink"], [0.2, "sink"], [0.27, "hop"], [0.34, "reach_r"], [0.42, "reach_r"], [0.52, "frog_l"], [0.6, "frog_l"], [0.74, "rock_l"], [0.86, "push"], [1.0, "hang"]],
	# Along the face (a traverse to the right; the left is its mirror): look, a quick wide reach of the leading
	# hand, the grip, the leading foot swings out and is planted, a pause to shift the weight, the body goes
	# over onto the new foot, the trailing hand and foot follow.
	"side_r": [[0.0, "hang"], [0.08, "look"], [0.14, "sink"], [0.2, "sink"], [0.27, "hop"], [0.34, "t_reach_r"], [0.42, "t_grip_r"], [0.52, "t_foot_r"], [0.6, "t_foot_r"], [0.8, "t_over_r"], [0.9, "t_shift_r"], [1.0, "hang"]],
	"side_l": [],
	# Find the spot, three blows, then clip the rope and test the hold.
	"hammer": [[0.0, "hang"], [0.1, "find_spot"], [0.22, "find_spot"], [0.32, "hammer_up"], [0.42, "hammer_hit"], [0.52, "hammer_up"], [0.62, "hammer_hit"], [0.72, "hammer_up"], [0.82, "hammer_hit"], [1.0, "hang"]],
	"thread": [[0.0, "hang"], [0.15, "thread"], [0.55, "thread"], [0.7, "tug"], [0.85, "tug"], [1.0, "hang"]],
	# Slip, fall, rope taut, arrest, stabilize.
	"slip": [[0.0, "reach_l"], [1.0, "slip"]],
	"fall": [[0.0, "slip"], [0.4, "fall"], [1.0, "fall"]],
	"arrest": [[0.0, "rope_taut"], [0.35, "rope_taut"], [0.6, "arrest"], [1.0, "hang"]],
	"rest": [[0.0, "hang"], [0.2, "rest"], [0.5, "hang"], [0.8, "rest"], [1.0, "hang"]],
	"desc_l": [[0.0, "hang"], [0.14, "look"], [0.28, "look"], [0.55, "down_l"], [0.7, "down_l"], [1.0, "hang"]],
	"desc_r": [[0.0, "hang"], [0.14, "look"], [0.28, "look"], [0.55, "down_r"], [0.7, "down_r"], [1.0, "hang"]],
	# Climb over the edge and stand up.
	"top": [[0.0, "pull"], [0.35, "push"], [0.6, "kneel"], [0.85, "kneel"], [1.0, "stand"]],
}


## The pose of `phase` (a key of KEYS) at time `u` (0..1).
static func at(phase: String, u: float) -> Dictionary:
	if phase == "side_l":
		return mirrored(at("side_r", u))
	var keys: Array = KEYS[phase]
	u = clampf(u, 0.0, 1.0)
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if u <= float(b[0]) or i == keys.size() - 1:
			var span := maxf(0.001, float(b[0]) - float(a[0]))
			var t := smoothstep(0.0, 1.0, clampf((u - float(a[0])) / span, 0.0, 1.0))
			return ClimbPose.mix(_both(POSES[a[1]]), _both(POSES[b[1]]), t)
	return {}


## A pose with the arms' shared angles (arm, elbow) written out for each arm, so that mixing a pose that gives
## both arms one angle with one that gives them their own never passes through a stray angle.
static func _both(p: Dictionary) -> Dictionary:
	var out := p.duplicate()
	for k in ["arm", "elbow"]:
		if p.has(k):
			if not p.has(k + "_l"):
				out[k + "_l"] = p[k]
			if not p.has(k + "_r"):
				out[k + "_r"] = p[k]
			out.erase(k)
	return out


## The pose seen in a mirror: left and right swapped, the sideways shift and lean reversed.
static func mirrored(p: Dictionary) -> Dictionary:
	var out := {}
	for k: String in p:
		if k.ends_with("_l"):
			out[k.trim_suffix("_l") + "_r"] = p[k]
		elif k.ends_with("_r"):
			out[k.trim_suffix("_r") + "_l"] = p[k]
		elif k == "hips_x" or k == "lean":
			out[k] = -float(p[k])
		else:
			out[k] = p[k]
	return out
