class_name VillageBell
extends RefCounted
## The village's warning bell: a classic church bell that tolls when something
## hostile happens in or at the village (a slime at the gate or the wall, the
## wall broken, a slime inside, a villager eaten). Whoever sees it reports it
## with Events.alarm(reason); Game rings the bell (see Game._ring_bell).
##
## The bell is rung for the whole village, not from one spot: the hero hears it
## anywhere on the open ground, but not in a dungeon. It rings at most once
## every COOLDOWN seconds, however many alarms come in, so it never spams. The
## town guard's alarm horn (WarHorn) shares this cooldown and sounds first.

const SOUND := "village_bell"
## The loudness of the bell, in dB.
const VOLUME_DB := -4.0
## Seconds before the bell may ring again (the sound itself lasts about 6).
const COOLDOWN := 30.0
## The reasons that ring it.
const REASONS := ["gate", "wall", "breach", "slime", "eaten"]

static var _last := -INF


## Whether the bell may ring at this time (seconds) for this reason; if so, it
## counts as rung now.
static func may_ring(now: float, reason: String) -> bool:
	if not reason in REASONS or now - _last < COOLDOWN:
		return false
	_last = now
	return true


## Forgets the last ring (a new game, a test).
static func reset() -> void:
	_last = -INF


## Rings the bell if the cooldown allows and the hero is on the open ground.
## Returns whether it rang.
static func ring(game: Node, reason: String, now := Time.get_ticks_msec() / 1000.0) -> bool:
	if not game.level is Outdoor or not may_ring(now, reason):
		return false
	# The guard blows the alarm horn first (see WarHorn); the bell tolls once it has
	# died away. Without a guard to blow it, the bell tolls at once.
	Sfx.play_after(game, WarHorn.blow(game.level), SOUND, VOLUME_DB)
	return true
