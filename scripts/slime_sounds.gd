class_name SlimeSounds
extends RefCounted
## The slimes' sounds (built by tools/make_slime_sounds.py): a wet slurp now
## and then while a slime glides over the floor, and a gloopy squelch when it
## lashes out. They come from the slime's own spot (heard from its side of the
## screen) and are kept quiet on purpose:
## - Bigger slimes sound lower and a little louder, small ones higher and
##   softer (see pitch_for and loudness_db).
## - They fade with the distance from the hero and are gone beyond HEARD_FROM.
## - A crowd stays bearable: no more than MAX_PER_WINDOW slime sounds start in
##   any WINDOW seconds, however many slimes there are.

const GLIDES := 4
const ATTACKS := 3
## Beyond this many metres from the hero a slime makes no sound.
const HEARD_FROM := 14.0
## Within this distance the slime is at full volume.
const CLOSE := 3.0
## The loudness of a slurp and of a lash for a slime of size 1, close by.
const GLIDE_DB := -17.0
const ATTACK_DB := -9.0
## The sound budget: at most this many slime sounds per WINDOW seconds.
const MAX_PER_WINDOW := 3
const WINDOW := 0.4
## Seconds between slurps of a slime of size 1 (a bigger one slides slower).
const GLIDE_GAP := 0.6

static var _recent: Array[float] = []


## Lower for bigger slimes, higher for small ones.
static func pitch_for(size: float) -> float:
	return clampf(pow(maxf(size, 0.1), -0.45), 0.6, 1.4)


## Bigger slimes are louder, by 4 dB per doubling of the size, within 6 dB.
static func loudness_db(size: float) -> float:
	return clampf(4.0 * log(maxf(size, 0.1)) / log(2.0), -6.0, 6.0)


## How much quieter a slime is from this far away from the hero, in dB
## (0 up close, silent beyond HEARD_FROM).
static func distance_db(dist: float) -> float:
	if dist >= HEARD_FROM:
		return -INF
	return -22.0 * clampf((dist - CLOSE) / (HEARD_FROM - CLOSE), 0.0, 1.0)


## Seconds until the next slurp of a slime this size.
static func glide_gap(size: float) -> float:
	return GLIDE_GAP * sqrt(maxf(size, 0.3))


## Whether the budget allows one more slime sound right now (and uses it).
static func budget(now: float) -> bool:
	while not _recent.is_empty() and now - _recent[0] > WINDOW:
		_recent.remove_at(0)
	if _recent.size() >= MAX_PER_WINDOW:
		return false
	_recent.append(now)
	return true


static func _play(e: Enemy, sound: String, base_db: float) -> void:
	if e.level == null or e.level.player == null:
		return
	var size := float(e._stats.size)
	var db := base_db + loudness_db(size) + distance_db(e.global_position.distance_to(e.level.player.global_position))
	if db < -45.0 or not budget(Time.get_ticks_msec() / 1000.0):
		return
	Sfx.play_3d(e.level, sound, db, e.global_position, pitch_for(size) * randf_range(0.94, 1.06))


## Called every physics tick of a slime: a slurp now and then while it moves.
static func glide(e: Enemy, delta: float, moving: bool) -> void:
	if not moving:
		e._step_timer = 0.0
		return
	e._step_timer -= delta
	if e._step_timer > 0.0:
		return
	# Slimes that start together do not slurp together.
	e._step_timer = glide_gap(float(e._stats.size)) * randf_range(0.8, 1.3)
	_play(e, "slime_glide_%d" % (randi() % GLIDES), GLIDE_DB)


## A slime lashing out.
static func attack(e: Enemy) -> void:
	_play(e, "slime_attack_%d" % (randi() % ATTACKS), ATTACK_DB)
