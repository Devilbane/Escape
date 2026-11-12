class_name NetPresence
extends RefCounted
## Where every player is, as far as the server believes it, and who sees whom.
##
## A game reports its hero's place with a "where" command (map, position,
## facing, animation). The server takes it only if the hero could have got
## there: no faster than MAX_SPEED since the last report (with a little slack
## for a late packet), unless the hero changed maps. Each player then sees the
## others on the same map within VIEW_RADIUS, nearest first, at most
## MAX_SEEN of them, so the traffic stays bounded however full the shard is.

## Faster than any hero can move in m/s (the run, dashes and knock-backs
## included), so only a cheat or a broken game is refused.
const MAX_SPEED := 16.0
## Distance a report may be off by anyway (a packet that came late).
const SLACK := 2.0
const VIEW_RADIUS := 60.0
const MAX_SEEN := 24

var _where := {}  # player id -> {"level", "pos", "facing", "anim", "at"}


## Takes a reported place; "" when it was taken, else the reason it was not.
func report(id: int, level: String, pos: Vector3, facing: float, anim: String, now: float) -> String:
	if not pos.is_finite() or not is_finite(facing):
		return "bad place"
	var last: Dictionary = _where.get(id, {})
	if not last.is_empty() and last.level == level:
		var allowed: float = MAX_SPEED * maxf(now - float(last.at), 0.0) + SLACK
		if (pos - last.pos).length() > allowed:
			return "too far"
	_where[id] = {"level": level, "pos": pos, "facing": facing, "anim": anim, "at": now}
	return ""


func forget(id: int) -> void:
	_where.erase(id)


func place_of(id: int) -> Dictionary:
	return _where.get(id, {})


## What player `id` sees: the other players on the same map within reach,
## nearest first, each as {id, pos, facing, anim}.
func seen_by(id: int) -> Array:
	var me: Dictionary = _where.get(id, {})
	if me.is_empty():
		return []
	var near := []
	for other in _where:
		if other == id:
			continue
		var it: Dictionary = _where[other]
		if it.level != me.level:
			continue
		var dist: float = (it.pos - me.pos).length()
		if dist <= VIEW_RADIUS:
			near.append([dist, {"id": other, "pos": it.pos, "facing": it.facing, "anim": it.anim}])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var seen := []
	for pair in near.slice(0, MAX_SEEN):
		seen.append(pair[1])
	return seen
