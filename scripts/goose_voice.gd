class_name GooseVoice
extends RefCounted
## The village geese's voices (built by tools/make_goose_sounds.py): a cackle of honks when a goose is
## startled awake, and an occasional honk now and then while it is up and about. They come from the
## goose's own spot, fade with the distance from the hero and are gone beyond HEARD_FROM. A whole flock
## waking together stays bearable: no more than MAX_PER_WINDOW goose sounds start in any WINDOW seconds.

const HONKS := 4
const ALARMS := 2
const HEARD_FROM := 30.0
const CLOSE := 5.0
const HONK_DB := -8.0
const ALARM_DB := -5.0
const MAX_PER_WINDOW := 3
const WINDOW := 0.6
## Seconds between idle honks of one goose (random in this range).
const GAP_MIN := 14.0
const GAP_MAX := 40.0

static var _recent: Array[float] = []


## Full volume close by, fading to silence at HEARD_FROM.
static func distance_db(dist: float) -> float:
	if dist >= HEARD_FROM:
		return -INF
	if dist <= CLOSE:
		return 0.0
	return -18.0 * (dist - CLOSE) / (HEARD_FROM - CLOSE)


static func budget(now: float) -> bool:
	_recent = _recent.filter(func(s: float) -> bool: return now - s < WINDOW)
	if _recent.size() >= MAX_PER_WINDOW:
		return false
	_recent.append(now)
	return true


static func _play(g: Node3D, sound: String, base_db: float) -> void:
	if g.level == null or g.level.player == null:
		return
	var db := base_db + distance_db(g.global_position.distance_to(g.level.player.global_position))
	if db < -45.0 or not budget(Time.get_ticks_msec() / 1000.0):
		return
	Sfx.play_3d(g.level, sound, db, g.global_position, randf_range(0.92, 1.1))


## A goose startled awake: a quick cackle.
static func startled(g: Node3D) -> void:
	_play(g, "goose_alarm_%d" % (randi() % ALARMS), ALARM_DB)


## One honk, now and then.
static func honk(g: Node3D) -> void:
	_play(g, "goose_honk_%d" % (randi() % HONKS), HONK_DB)


## Called every physics tick of an awake goose: counts down to the next honk.
static func chatter(g: Node3D, delta: float) -> void:
	g._voice_timer -= delta
	if g._voice_timer > 0.0:
		return
	g._voice_timer = randf_range(GAP_MIN, GAP_MAX)
	honk(g)
