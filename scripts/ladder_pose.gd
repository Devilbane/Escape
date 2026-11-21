class_name LadderPose
extends RefCounted
## The body of the hero on a built ladder (see Player._try_ladder and HouseSketcher._ladder),
## after the climbing sheet the player sent: hand over hand and foot over foot, the
## opposite hand and foot reaching for the next rung together, left and right taking turns.
## Going up, the hero steps onto the first rung with both hands on the rails, climbs, then
## pushes up on the hands planted on the edge, sets a knee on it, kneels and stands up.
## Going down is the same pull-over backwards, then the rungs down, and two rungs above the
## ground the hero lets go and hops off backwards, landing in a crouch.
##
## The climb is a list of keys, [seconds, forward, height, pose, arc]: forward is metres along
## the ladder's push from the edge it leans on (negative: in front of it, where the rungs
## are), height metres above the ladder's foot, pose a ClimbPose dictionary (with an angle for
## each arm, see ClimbPose.apply), and arc how far the way to this key bulges upwards (a hop).
## The first key stands where the hero started; its sideways offset fades by the second key.

## Where the hero's feet are on the rungs: this far before the edge (see HouseSketcher._ladder,
## which stands the rails 0.18 m before it, so the hands reach them).
const RUNG_FORWARD := -0.5
## The rungs: the first this high over the foot, then one every RUNG metres.
const RUNG := 0.3
## Seconds per rung, and the share of each rung's move that is eased (a pull and a breath,
## not a lift); the rest is steady.
const RUNG_TIME := 0.24
const RUNG_EASE := 0.6
## The feet stop climbing this far below the top (two rungs or so) for the pull-over.
const OVER_BELOW := 0.45
## Where the hop off the bottom lands: this far before the edge (the ladder's own cell is
## free, HouseSketch.problem_ladder), and how high the hop bulges.
const LAND_FORWARD := -0.95
const HOP_ARC := 0.18
## Where the hero stands at the top when the climb is done (HouseSketcher._ladder's "top").
const TOP_FORWARD := 0.7

const POSES := {
	"stand": {},
	## Both hands up on the rails, the left foot lifting onto the first rung.
	"grab": {"spine": 4.0, "head": -10.0, "arm_l": 118.0, "arm_r": 112.0, "elbow_l": 22.0, "elbow_r": 28.0,
		"hip_l": 40.0, "knee_l": 60.0, "hip_r": 5.0, "knee_r": 8.0},
	## Left hand reaching for the next rung, right hand pulling at the chest, right knee up
	## to the next rung (and its mirror). The rig's head is big and its arms are short, so
	## a hand straight up would vanish behind the head: the reach goes up and forward.
	"rung_l": {"spine": 6.0, "head": -12.0, "arm_l": 140.0, "elbow_l": 6.0, "arm_r": 86.0, "elbow_r": 58.0,
		"hip_l": 16.0, "knee_l": 22.0, "hip_r": 74.0, "knee_r": 100.0},
	"rung_r": {"spine": 6.0, "head": -12.0, "arm_r": 140.0, "elbow_r": 6.0, "arm_l": 86.0, "elbow_l": 58.0,
		"hip_r": 16.0, "knee_r": 22.0, "hip_l": 74.0, "knee_l": 100.0},
	## Over the top: hands planted on the edge, the body leaning onto them, a knee coming up.
	"over": {"spine": 34.0, "chest": 8.0, "head": -10.0, "arm_l": 58.0, "arm_r": 58.0, "elbow_l": 24.0, "elbow_r": 24.0,
		"hip_l": 96.0, "knee_l": 108.0, "hip_r": 12.0, "knee_r": 28.0},
	## Two rungs above the ground: arms straightening, legs gathering for the hop.
	"let_go": {"spine": -4.0, "head": -4.0, "arm_l": 104.0, "arm_r": 104.0, "elbow_l": 14.0, "elbow_r": 14.0,
		"hip_l": 30.0, "knee_l": 48.0, "hip_r": 30.0, "knee_r": 48.0},
	## In the air: hands off, arms out in front for balance, legs tucked a little.
	"hop": {"spine": 8.0, "head": 4.0, "arm_l": 60.0, "arm_r": 52.0, "elbow_l": 30.0, "elbow_r": 34.0,
		"hip_l": 40.0, "knee_l": 60.0, "hip_r": 32.0, "knee_r": 52.0},
}


## A pose by name: one of POSES, or ClimbPose's ("knee", "kneel", "crouch") with an angle for
## each arm.
static func pose(name: String) -> Dictionary:
	if POSES.has(name):
		return POSES[name]
	return sided(ClimbPose.POSES[name])


## `p` with its "arm" and "elbow" (both arms) split into one angle for each arm.
static func sided(p: Dictionary) -> Dictionary:
	var out := p.duplicate()
	for k in ["arm", "elbow"]:
		if out.has(k):
			out[k + "_l"] = out[k]
			out[k + "_r"] = out[k]
			out.erase(k)
	return out


## How many rungs the feet climb on a ladder `tall` metres from foot to top.
static func rungs_for(tall: float) -> int:
	return maxi(2, floori((tall - OVER_BELOW) / RUNG + 0.01))


## The keys of a climb up a ladder `tall` metres high, from `start_forward`.
static func up_keys(tall: float, start_forward: float) -> Array:
	var keys := [[0.0, start_forward, 0.0, pose("stand"), 0.0]]
	var t := 0.32
	keys.append([t, RUNG_FORWARD, 0.0, pose("grab"), 0.0])
	var n := rungs_for(tall)
	for k in range(1, n + 1):
		t += RUNG_TIME
		keys.append([t, RUNG_FORWARD, k * RUNG, pose("rung_l" if k % 2 == 1 else "rung_r"), 0.0])
	t += 0.34
	keys.append([t, RUNG_FORWARD + 0.08, tall - 0.25, pose("over"), 0.0])
	t += 0.3
	keys.append([t, 0.22, tall - 0.2, pose("knee"), 0.0])
	t += 0.28
	keys.append([t, 0.45, tall, pose("kneel"), 0.0])
	t += 0.34
	keys.append([t, TOP_FORWARD, tall, pose("stand"), 0.0])
	return keys


## The keys of a climb down a ladder `tall` metres high, from `start_forward` at its top.
static func down_keys(tall: float, start_forward: float) -> Array:
	var keys := [[0.0, start_forward, tall, pose("stand"), 0.0]]
	var t := 0.36
	keys.append([t, 0.45, tall, pose("kneel"), 0.0])
	t += 0.28
	keys.append([t, 0.22, tall - 0.2, pose("knee"), 0.0])
	t += 0.3
	keys.append([t, RUNG_FORWARD + 0.08, tall - 0.25, pose("over"), 0.0])
	var n := rungs_for(tall)
	t += 0.3
	keys.append([t, RUNG_FORWARD, n * RUNG, pose("rung_l" if n % 2 == 1 else "rung_r"), 0.0])
	for k in range(n - 1, 1, -1):
		t += RUNG_TIME
		keys.append([t, RUNG_FORWARD, k * RUNG, pose("rung_l" if k % 2 == 1 else "rung_r"), 0.0])
	t += 0.14
	keys.append([t, RUNG_FORWARD - 0.04, 2 * RUNG + 0.04, pose("let_go"), 0.0])
	t += 0.36
	keys.append([t, LAND_FORWARD, 0.0, pose("hop"), HOP_ARC])
	t += 0.12
	keys.append([t, LAND_FORWARD - 0.02, 0.0, pose("crouch"), 0.0])
	t += 0.34
	keys.append([t, LAND_FORWARD - 0.02, 0.0, pose("stand"), 0.0])
	return keys


## How long a climb of `keys` takes.
static func length(keys: Array) -> float:
	return float(keys.back()[0])


## The climb of `keys` at `t` seconds: {"pose", "forward", "height", "side"}, where side is
## how much of the starting sideways offset is left (1 at the start, 0 from the second key on).
static func at(keys: Array, t: float) -> Dictionary:
	t = clampf(t, 0.0, length(keys))
	for i in range(1, keys.size()):
		var k0: Array = keys[i - 1]
		var k1: Array = keys[i]
		if t <= float(k1[0]) or i == keys.size() - 1:
			var span := maxf(0.001, float(k1[0]) - float(k0[0]))
			var u := clampf((t - float(k0[0])) / span, 0.0, 1.0)
			var arc := float(k1[4])
			# A hop flies steadily; everything else eases in and out, the rungs only partly.
			var e := u if arc > 0.0 else smoothstep(0.0, 1.0, u)
			var climbing := absf(float(k1[2]) - float(k0[2])) <= RUNG + 0.01 and float(k1[1]) == RUNG_FORWARD and float(k0[1]) == RUNG_FORWARD
			if climbing:
				e = lerpf(u, smoothstep(0.0, 1.0, u), RUNG_EASE)
			return {
				"pose": ClimbPose.mix(k0[3], k1[3], smoothstep(0.0, 1.0, u)),
				"forward": lerpf(float(k0[1]), float(k1[1]), e),
				"height": lerpf(float(k0[2]), float(k1[2]), e) + arc * 4.0 * u * (1.0 - u),
				"side": 1.0 - e if i == 1 else 0.0,
			}
	return {"pose": {}, "forward": 0.0, "height": 0.0, "side": 0.0}
