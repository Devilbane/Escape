class_name Turning
extends RefCounted
## Natural turns for walkers that move on their own (animals, monsters): a body
## heads along a heading that swings towards the way it wants at a limited rate,
## so a change of direction is a small arc, not a snap on the spot. A big body
## turns slowly, a small one quickly, and a hunter that has noticed the hero
## turns much faster so that chases and charges stay sharp.

## Radians per second for a body of size 1.0 that strolls.
const CALM_RATE := 4.0
## A hunter, or an animal on the run, turns this many times faster.
const ALERT_FACTOR := 2.5
## The fastest turn and the slowest turn (radians per second).
const MAX_RATE := 14.0
const MIN_RATE := 1.8
## A body facing right away from its goal still moves at this share of its pace
## (so it swings round in an arc and never spins on the spot).
const MIN_PACE := 0.3


## How fast a body of `size` (1.0 is a man) may turn, in radians per second.
static func rate(size: float, alert: bool) -> float:
	var r := CALM_RATE / maxf(size, 0.3)
	if alert:
		r *= ALERT_FACTOR
	return clampf(r, MIN_RATE, MAX_RATE)


## The heading after one step: `heading` turned towards `want` by at most
## `turn_rate * delta` radians (both flat; `want` need not be normalised).
static func steer(heading: Vector3, want: Vector3, delta: float, turn_rate: float) -> Vector3:
	want.y = 0.0
	heading.y = 0.0
	if want.length() < 0.001:
		return heading
	if heading.length() < 0.001:
		return want.normalized()
	var from := atan2(heading.x, heading.z)
	var to := atan2(want.x, want.z)
	var angle := rotate_toward(from, to, turn_rate * delta)
	return Vector3(sin(angle), 0.0, cos(angle))


## Share of the pace kept while the heading is `off` radians away from the
## wanted way: all of it when lined up, MIN_PACE when facing away.
static func pace(heading: Vector3, want: Vector3) -> float:
	want.y = 0.0
	heading.y = 0.0
	if want.length() < 0.001 or heading.length() < 0.001:
		return 1.0
	var c := heading.normalized().dot(want.normalized())
	return clampf(0.5 + 0.5 * c, MIN_PACE, 1.0)
