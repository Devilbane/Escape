class_name StuckWatch
extends RefCounted
## A watchdog for everyone who walks on their own (villagers, animals, farm animals, the
## companion): a body that keeps playing its walk without getting any closer to where it
## is going (walking on the spot against something in the way, circling a path point,
## or waiting, finding the same way and being stopped again, over and over) is stuck.
## It then stands still with idle legs for REST seconds and tries again.
##
## Progress is measured along the way still ahead (see remaining()), not as the crow
## flies, so a path that first leads away from the goal round a house is progress too.
## A way that suddenly grows (a gate shut, a detour found) starts the measure again from
## there, and a goal that moves (the hero walking off) starts the watch afresh.

## How long a body may go without getting PROGRESS metres closer before it counts as stuck (seconds).
const PATIENCE := 5.0
## How much closer (metres along the way) counts as getting somewhere.
const PROGRESS := 0.6
## How long a stuck body stands still before it tries again (seconds).
const REST := 10.0
## A goal that moved this far is a new goal (metres).
const GOAL_MOVED := 1.0
## A way that grew by this much was found anew (metres): measured afresh from there.
const NEW_WAY := 1.5

var _goal := Vector3.INF
var _best := INF
var _since := 0.0


## Called every physics tick while the body is on its way to `goal`, `remaining` metres
## along its way from it. Returns true once it is stuck (and starts a fresh watch).
func tick(goal: Vector3, remaining: float, delta: float) -> bool:
	if _goal == Vector3.INF or Vector2(goal.x - _goal.x, goal.z - _goal.z).length() > GOAL_MOVED:
		_goal = goal
		_best = remaining
		_since = 0.0
		return false
	if remaining <= _best - PROGRESS:
		_best = remaining
		_since = 0.0
		return false
	if remaining > _best + NEW_WAY:
		_best = remaining
	_since += delta
	if _since >= PATIENCE:
		reset()
		return true
	return false


## Forgets the current goal: called whenever the body is not on its way.
func reset() -> void:
	_goal = Vector3.INF
	_best = INF
	_since = 0.0


## How far it still is from `from` along `path` (flat), then on to `goal` when it lies beyond the
## path's end (the hero a dog runs up to).
static func remaining(from: Vector3, path: Array[Vector3], goal := Vector3.INF) -> float:
	var total := 0.0
	var at := from
	for p in path:
		total += Vector2(p.x - at.x, p.z - at.z).length()
		at = p
	if goal != Vector3.INF:
		total += Vector2(goal.x - at.x, goal.z - at.z).length()
	return total
