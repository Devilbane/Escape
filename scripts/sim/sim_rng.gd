class_name SimRng
extends RefCounted
## A seeded random source for rules that a server must be able to replay.
##
## The global randi()/randf() cannot be saved, replayed or shared between a
## client and a server. A SimRng can: the same seed gives the same rolls, and
## its state can be written into a save and read back. Each part of the rules
## takes its own stream (`stream("loot")`), so a new roll in one place never
## shifts the rolls in another.

var _rng := RandomNumberGenerator.new()
var _seed := 0


func _init(start_seed := 1) -> void:
	_seed = start_seed
	_rng.seed = start_seed


## The seed this source started from.
func get_seed() -> int:
	return _seed


## A separate source for one part of the rules, derived from this seed and the
## name. The same name always gives the same stream; it does not use up any
## roll of this source.
func stream(name: String) -> SimRng:
	return SimRng.new(hash([_seed, name]))


func roll() -> float:
	return _rng.randf()


## A whole number from a to b, both included.
func range_int(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func chance(p: float) -> bool:
	return _rng.randf() < p


## One element of the array (null when it is empty).
func pick(items: Array):
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## What to store in a save to carry on with the same rolls later.
func for_save() -> Dictionary:
	return {"seed": _seed, "state": str(_rng.state)}


static func from_save(saved) -> SimRng:
	var made := SimRng.new()
	if saved is Dictionary:
		made._seed = int(saved.get("seed", 1))
		made._rng.seed = made._seed
		made._rng.state = int(str(saved.get("state", made._rng.state)))
	return made
