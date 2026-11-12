class_name SimClock
extends RefCounted
## The rules' own time: a count of fixed ticks, not frames or wall-clock seconds.
##
## A server steps the world at a fixed rate whatever the frame rate is, and a
## client replays the same ticks. `advance(delta)` turns real seconds into the
## ticks that are due, so a caller runs its rules once per tick.

const TICK_RATE := 20
const TICK_SECONDS := 1.0 / TICK_RATE

var tick := 0
var _carry := 0.0


## Adds real seconds; returns how many whole ticks have come due.
func advance(delta: float) -> int:
	_carry += maxf(delta, 0.0)
	var due := int(_carry / TICK_SECONDS)
	_carry -= due * TICK_SECONDS
	tick += due
	return due


## Seconds of simulated time since the start.
func seconds() -> float:
	return tick * TICK_SECONDS


static func ticks_for(seconds_: float) -> int:
	return int(round(seconds_ * TICK_RATE))


func for_save() -> Dictionary:
	return {"tick": tick}


func load_from(saved) -> void:
	tick = int(saved.get("tick", 0)) if saved is Dictionary else 0
	_carry = 0.0
