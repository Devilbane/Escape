class_name Stride
## Feet that stay put on the ground. Every walking body (the hero, villagers,
## monsters, animals, the companion) plays its walk or run at the rate that
## makes its planted foot travel backwards exactly as fast as the body moves
## forwards, so no foot slides over the floor. A body too fast for a gait
## steps up to the next one (walk, jog, run) instead of scurrying.
##
## Humans also rise a little onto their toes as the back foot rolls off the
## ground in the walk (see lift).
##
## The speeds in FEET are measured from the animations themselves:
## tests/stride.gd measures them again from the bones and fails when one is off.

## Metres per second a planted foot travels in each animation, played at
## normal speed on a model of scale 1. Keyed by rig: models sharing a rig
## share the animations.
const FEET := {
	# KayKit adventurers and skeletons (hero, villagers, bandits, skeletons).
	"kaykit": {"Walking_A": 0.82, "Walking_B": 0.87, "Walking_C": 0.54, "Walking_D_Skeletons": 0.55,
		"Running_B": 2.28, "Running_A": 4.10},
	# Orc and Yeti.
	"brute": {"Walk": 2.71, "Run": 7.51},
	# Wolf and fox.
	"hound": {"Walk": 2.38, "Gallop": 7.23},
	# Deer and stag.
	"deer": {"Walk": 2.64, "Gallop": 11.65},
	"spider": {"HumanArmature|Spider_Walk": 3.51},
	# Husky and Shiba Inu (the village dogs).
	"husky": {"Walk": 2.38, "Gallop": 5.87},
	"shiba": {"Walk": 2.38, "Gallop": 5.87},
	# Cow and bull (the village herd).
	"cow": {"Walk": 2.63, "Gallop": 9.56},
	# The village sheep (its animations were made for it, tools/build_sheep.gd).
	"sheep": {"Walk": 5.33, "Gallop": 18.88},
}
## Which rig each model file uses. A model not listed (the slime, bats,
## dragons) has no feet on the ground and plays at its own pace.
const RIGS := {
	"Rogue": "kaykit", "Knight": "kaykit", "Barbarian": "kaykit", "Mage": "kaykit",
	"Skeleton_Warrior": "kaykit", "Skeleton_Rogue": "kaykit", "Skeleton_Mage": "kaykit", "Skeleton_Minion": "kaykit",
	"Orc": "brute", "Yeti": "brute", "Wolf": "hound", "Fox": "hound", "Deer": "deer", "Stag": "deer",
	"Spider": "spider", "Husky": "husky", "ShibaInu": "shiba", "Cow": "cow", "Bull": "cow", "Sheep": "sheep",
}
## The walk, jog and run of each rig, slowest first (see gait).
const GAITS := {
	"kaykit": ["Walking_A", "Running_B", "Running_A"],
	"brute": ["Walk", "Run"],
	"hound": ["Walk", "Gallop"],
	"deer": ["Walk", "Gallop"],
	"spider": ["HumanArmature|Spider_Walk"],
	"husky": ["Walk", "Gallop"],
	"shiba": ["Walk", "Gallop"],
	"cow": ["Walk", "Gallop"],
	"sheep": ["Walk", "Gallop"],
}
## A walk plays at most this many times its normal pace; a body that walks
## faster is held back to it (see top_speed), or takes up the next gait.
const WALK_CADENCE := 2.2
## Playback limits for any gait: below, a stalled body still breathes;
## above, the fastest legs would blur.
const SLOWEST := 0.3
const FASTEST := 2.6
## A body steps up to the next gait once that gait would play at this share
## of its pace, and back down once the current one falls below SHIFT_DOWN.
## The gap between keeps it from flickering between two gaits.
const SHIFT_UP := 0.9
const SHIFT_DOWN := 0.72

## Where in a human walk cycle each back foot is highest on its toes (left,
## right), measured from the heel lift with the toes still down.
const PUSH_OFF := {"Walking_A": [0.47, 0.955], "Walking_B": [0.48, 0.955]}
## How high the body rises onto its toes (metres, on a model of scale 1),
## and over what share of the cycle it rises before the push-off and settles
## after it (into the next heel strike).
const LIFT_HEIGHT := 0.05
const LIFT_RISE := 0.16
const LIFT_SETTLE := 0.09
## Below this ground speed (m/s) a body stands still and stays flat-footed;
## from LIFT_MOVING on it lifts fully.
const LIFT_STILL := 0.15
const LIFT_MOVING := 0.6


## The rig of a model file name ("Rogue", "Wolf"), or "" for one without feet.
static func rig_of(model: String) -> String:
	return RIGS.get(model, "")


## How fast `anim` carries a model of `size` over the ground at normal
## playback (m/s), or 0 when it has no planted feet.
static func pace(rig: String, anim: String, size: float) -> float:
	return float(FEET.get(rig, {}).get(anim, 0.0)) * size


## The playback rate that keeps the planted feet of `anim` still on the
## ground at `ground_speed`. An animation without measured feet plays at 1.
static func playback(rig: String, anim: String, size: float, ground_speed: float) -> float:
	var p := pace(rig, anim, size)
	if p <= 0.0:
		return 1.0
	return clampf(ground_speed / p, SLOWEST, FASTEST)


## The fastest a body may walk in `anim` with its feet keeping up at a
## natural cadence (m/s); INF for an animation without measured feet.
static func top_speed(rig: String, anim: String, size: float) -> float:
	var p := pace(rig, anim, size)
	return p * WALK_CADENCE if p > 0.0 else INF


## The gait (animation) that fits `speed` best among `gaits` (slowest first)
## for a model of `size`, keeping `current` while it still fits.
static func gait(rig: String, gaits: Array, size: float, speed: float, current: String) -> String:
	var at := gaits.find(current)
	if at >= 0:
		var up_ok: bool = at + 1 < gaits.size() and pace(rig, gaits[at + 1], size) > 0.0 \
				and speed >= pace(rig, gaits[at + 1], size) * SHIFT_UP
		var down_ok: bool = at > 0 and speed < pace(rig, current, size) * SHIFT_DOWN
		if not up_ok and not down_ok:
			return current
	var pick: String = gaits[0]
	for g: String in gaits:
		if pace(rig, g, size) > 0.0 and speed >= pace(rig, g, size) * SHIFT_UP:
			pick = g
	return pick


## How far a human walking in `anim` at `ground_speed` (m/s) is lifted
## onto the toes right now (metres, for a model of `size`): a soft rise as
## the back heel peels off the ground, highest at the push-off, settling as
## the front heel lands. 0 for any other animation, and for a body standing
## still, even if its walk is still playing (held up, waiting, talking).
static func lift(player: AnimationPlayer, anim: String, size: float, ground_speed: float) -> float:
	if not PUSH_OFF.has(anim) or player == null or player.current_animation != anim:
		return 0.0
	var moving := smoothstep(LIFT_STILL, LIFT_MOVING, ground_speed)
	if moving <= 0.0:
		return 0.0
	var length := player.current_animation_length
	if length <= 0.0:
		return 0.0
	return LIFT_HEIGHT * size * moving * lift_at(anim, player.current_animation_position / length)


## The share (0..1) of the full lift at `phase` (0..1) of the walk cycle.
static func lift_at(anim: String, phase: float) -> float:
	var best := 0.0
	for p: float in PUSH_OFF.get(anim, []):
		var d := fposmod(phase - p + 0.5, 1.0) - 0.5
		var k := 0.0
		if d < 0.0 and d > -LIFT_RISE:
			k = 0.5 - 0.5 * cos(PI * (d + LIFT_RISE) / LIFT_RISE)
		elif d >= 0.0 and d < LIFT_SETTLE:
			k = 0.5 + 0.5 * cos(PI * d / LIFT_SETTLE)
		best = maxf(best, k)
	return best
