class_name WallClimb
extends RefCounted
## One climber on a WallMap: where they hang, the safe spots (nails) they set and the falls so far. The
## rules are RockClimb's, one square at a time: FIRST moves in a row from the ground earn a nail, NEXT
## from each nail the next one; a failed move is a slip (a try again at once), then a rest, and every failed
## try raises the chance of a fall (RockClimb.fall_chance); a fall off a surface or a jump is always a fall.
## A fall drops the climber to the last nail, or the ground; MAX_FALLS falls to a nail end the climb.
## Rolls come in as arguments (0..1, a roll at or above the chance fails), so a test can play it through.

enum Outcome { MOVED, TOP, NAILED, SLIPPED, RESTED, FELL, GAVE_UP, BLOCKED, BRACED, GRAZED, EXHAUSTED, CAMPED }

## The chance that a stone that hits an unbraced climber knocks them off the wall.
const KNOCK_OFF := 0.5

## Stamina is the hero's run meter (Player.max_stamina: seconds of running, Konstitution x 2; it comes back at
## Konstitution / 10 per second). Every move spends some of it: STEP_COST, plus MALUS_COST per point of the
## hold's malus, SURFACE_COST on a surface, the weather's cost, and a jump JUMP_COST plus JUMP_PER_METRE per
## metre of gap. Hanging still gives it back: on a good hold (malus at most GOOD_MALUS and no surface) or at a
## nail REST_GOOD times the usual rate, on any other hold REST_POOR times. Below TIRED_BELOW of the meter the
## chances shrink (down to TIRED_FLOOR of themselves at nothing), and with the meter empty the next move is a
## fall (EXHAUSTED: the arms give out).
const STEP_COST := 1.5
const MALUS_COST := 0.4
const SURFACE_COST := 1.5
const JUMP_COST := 4.0
const JUMP_PER_METRE := 1.0
const WEATHER_COST := {"rain": 0.75, "snow": 0.75, "storm": 1.5}

## Time. Every move takes a quarter of an hour (a jump a little more), catching breath on the wall 25 minutes.
## The climb starts at START_HOUR. From DUSK_HOUR the light fails (one level worse), from NIGHT_HOUR until
## DAWN_HOUR it is dark and cold (three levels worse, and every move costs NIGHT_COST times the breath).
## A rest place (marker "camp") lets the climber spend the night: they sleep until dawn and wake with a full
## meter; by day they rest three hours and get back BIVOUAC_DAY of the meter.
const START_HOUR := 8.0
const MOVE_HOURS := 0.25
const JUMP_HOURS := 0.3
const BREATH_HOURS := 0.4
const DUSK_HOUR := 18.0
const NIGHT_HOUR := 20.0
const DAWN_HOUR := 6.0
const DARK_LEVELS := [0, 1, 3]
const DARK_COST := [1.0, 1.15, 1.4]
const BREATH_GOOD := 0.4
const BREATH_POOR := 0.15
const BIVOUAC_DAY_HOURS := 3.0
const BIVOUAC_DAY := 0.7
const GOOD_MALUS := 2
const REST_GOOD := 4.0
const REST_POOR := 0.25
const TIRED_BELOW := 0.3
const TIRED_FLOOR := 0.4

## Jumps (a gap's far side) lean on the body, not only on Klettern: each point of Geschick above 10 adds a level to
## the climber's skill for the jump, each two points of Intuition above 10 add one (a feel for the moment).
## Before a jump the climber may judge the gap (see `judge`): a roll of Weisheit and Intuition. Weisheit plus
## Intuition above 20, plus the Klettern skill, is the judge level; the roll is accurate below JUDGE_BASE + JUDGE_PER_POINT x level, and
## otherwise the read is off by up to JUDGE_NOISE either way, or no read at all (above JUDGE_BLANK).
const JUDGE_BASE := 0.5
const JUDGE_PER_POINT := 0.02
const JUDGE_NOISE := 0.35
const JUDGE_BLANK := 0.92
const ATTRIBUTE_START := 10

var map: WallMap
var skill := 1
## The weather the climb is in (see WallWeather).
var weather := ""
## Whether the climber carries hammer, rope and a nail: only then are safe spots (nails) set.
var gear := true
## The meter (seconds of running) and what it holds at most and gets back per second at rest.
var stamina_max := 20.0
var stamina := 20.0
var recovery := 1.0
## The hero's Geschick, Intuition and Weisheit (all 10 at the start).
var dexterity := ATTRIBUTE_START
var intuition := ATTRIBUTE_START
var wisdom := ATTRIBUTE_START
## The time of day in hours (it keeps counting past 24).
var clock := START_HOUR
## Where the climber hangs; NOWHERE is the ground.
var cell := NOWHERE
var nail := NOWHERE
var nails: Array[Vector2i] = []
var streak := 0
var tries := 0
var falls := 0
var retry := true
## Metres fallen by the last fall.
var last_fall := 0.0
const NOWHERE := Vector2i(-1, -1)


func _init(wall: WallMap, level: int) -> void:
	map = wall
	skill = level


## Sets the meter from the hero's Konstitution, the way the run meter is (Player.max_stamina). Full.
func set_constitution(con: int) -> void:
	stamina_max = Player.RUN_SECONDS_PER_CON * con
	recovery = Player.RUN_RECOVERY_PER_CON * con
	stamina = stamina_max


## The levels Geschick and Intuition add to the skill for a jump.
func jump_bonus() -> int:
	return (dexterity - ATTRIBUTE_START) + (intuition - ATTRIBUTE_START) / 2


## Weisheit plus Intuition above the start plus the Klettern skill, the level of the climber's eye for a gap.
func judge_level() -> int:
	return (wisdom - ATTRIBUTE_START) + (intuition - ATTRIBUTE_START) + skill


## The chance of a move for this climber now: the rules' chance (a jump with the body's bonus), made worse by tiredness.
func chance_of(mv: Dictionary) -> float:
	var level := skill - dark_penalty() + (jump_bonus() if mv.kind == "jump" else 0)
	return WallRules.move_chance(map, mv, level, weather) * tired_factor()


## The climber judges a jump (`mv` of kind "jump"): a roll of the eye. Returns {"truth": the real chance,
## "shown": what the climber believes, "accurate": whether the eye was good, "text": the German words}.
func judge(mv: Dictionary, roll: float, noise_roll: float) -> Dictionary:
	var truth := chance_of(mv)
	var good := roll < clampf(JUDGE_BASE + JUDGE_PER_POINT * judge_level(), 0.2, 0.95)
	var shown := truth if good else clampf(truth + (noise_roll * 2.0 - 1.0) * JUDGE_NOISE, 0.0, 1.0)
	var text := "Der Sprung sieht lebensgefährlich aus."
	if not good and roll > JUDGE_BLANK:
		text = "Du kannst die Spalte nicht einschätzen."
	elif good and truth <= 0.0:
		text = "Die Spalte ist zu breit für dich: dir fehlt noch Können."
	elif shown >= 0.8:
		text = "Der Sprung sieht gut machbar aus."
	elif shown >= 0.55:
		text = "Der Sprung sieht machbar aus, aber knapp."
	elif shown >= 0.3:
		text = "Der Sprung sieht riskant aus."
	return {"truth": truth, "shown": shown, "accurate": good, "text": text}


## What a move costs the meter.
func cost(mv: Dictionary) -> float:
	var to: Vector2i = mv.to
	var c := STEP_COST + MALUS_COST * maxi(0, map.malus_at(to.x, to.y))
	if map.hazard_at(to.x, to.y) != WallMap.NONE:
		c += SURFACE_COST
	c += float(WEATHER_COST.get(weather, 0.0))
	if mv.kind == "jump":
		c += JUMP_COST + JUMP_PER_METRE * float(mv.span)
	return c * float(DARK_COST[darkness()])


## The hour of the day, 0 to 24.
func hour() -> float:
	return fposmod(clock, 24.0)


## 0 by day, 1 at dusk, 2 at night.
func darkness() -> int:
	var h := hour()
	if h >= NIGHT_HOUR or h < DAWN_HOUR:
		return 2
	return 1 if h >= DUSK_HOUR else 0


## The levels the failing light takes off the climber's skill.
func dark_penalty() -> int:
	return int(DARK_LEVELS[darkness()])


## The clock as "HH:MM".
func time_text() -> String:
	var h := hour()
	return "%02d:%02d" % [int(h), int((h - floor(h)) * 60.0)]


## Whether the climber hangs on a rest place (a ledge where they can spend the night).
func at_camp() -> bool:
	return not on_ground() and map.marker_at(cell.x, cell.y) == "camp"


## Catches breath on the wall: a part of the meter comes back (more on a good hold) and time passes.
func catch_breath() -> void:
	clock += BREATH_HOURS
	stamina = minf(stamina_max, stamina + stamina_max * (BREATH_GOOD if good_hold() else BREATH_POOR))


## Rests at a rest place: by evening or night until dawn with a full meter, by day for a few hours.
## Returns Outcome.CAMPED, or BLOCKED when there is no rest place here.
func bivouac() -> int:
	if not at_camp():
		return Outcome.BLOCKED
	if darkness() > 0 or hour() < DAWN_HOUR:
		clock += fposmod(DAWN_HOUR - hour(), 24.0)
		stamina = stamina_max
	else:
		clock += BIVOUAC_DAY_HOURS
		stamina = minf(stamina_max, stamina + stamina_max * BIVOUAC_DAY)
	streak = 0
	return Outcome.CAMPED


## The factor tiredness puts on a chance: 1 above TIRED_BELOW of the meter, falling to TIRED_FLOOR at empty.
func tired_factor() -> float:
	var share := stamina / maxf(0.01, stamina_max)
	if share >= TIRED_BELOW:
		return 1.0
	return TIRED_FLOOR + (1.0 - TIRED_FLOOR) * share / TIRED_BELOW


## Whether the climber hangs where they can rest well: on the ground, at a nail or on an easy hold.
func good_hold() -> bool:
	if on_ground() or cell == nail:
		return true
	return map.malus_at(cell.x, cell.y) <= GOOD_MALUS and map.hazard_at(cell.x, cell.y) == WallMap.NONE


## Hanging still for `delta` seconds: the meter comes back.
func recover(delta: float) -> void:
	stamina = minf(stamina_max, stamina + recovery * delta * (REST_GOOD if good_hold() else REST_POOR))


func on_ground() -> bool:
	return cell == NOWHERE


## The moves open to the climber now: from the ground a step up onto any hold in the bottom row.
func options() -> Array:
	if on_ground():
		var out := []
		for c in map.width:
			if map.is_start(c, map.height - 1):
				out.append({"to": Vector2i(c, map.height - 1), "dir": WallMap.UP, "kind": "step", "gap": -1, "span": 0.0})
		return out
	return map.moves_from(cell.x, cell.y)


## The move in direction `dir` (a WallMap direction), or an empty Dictionary when there is none.
func move_in(dir: int) -> Dictionary:
	for mv: Dictionary in options():
		if mv.dir == dir:
			return mv
	return {}


## Tries the move in `dir`. `roll` decides the hands, `fall_roll` a fall after a slip.
func go(dir: int, roll: float, fall_roll := 1.0) -> int:
	var mv := move_in(dir)
	if mv.is_empty():
		return Outcome.BLOCKED
	var to: Vector2i = mv.to
	if stamina <= 0.0 and not on_ground():
		var gave := _fall()
		return gave if gave == Outcome.GAVE_UP else Outcome.EXHAUSTED
	var chance := chance_of(mv)
	stamina = maxf(0.0, stamina - cost(mv))
	clock += JUMP_HOURS if mv.kind == "jump" else MOVE_HOURS
	if roll < chance:
		cell = to
		retry = true
		tries = 0
		streak += 1
		if map.is_top(to.x, to.y):
			return Outcome.TOP
		if gear and streak >= (RockClimb.FIRST if nails.is_empty() else RockClimb.NEXT):
			nail = to
			nails.append(to)
			streak = 0
			return Outcome.NAILED
		return Outcome.MOVED
	tries += 1
	var surface: bool = WallRules.square_risk(map, to.x, to.y, weather) > 0.0
	var skill_chance: float = WallRules.skill_chance(map, to.x, to.y, skill - dark_penalty(), weather) * tired_factor() if mv.kind == "step" else 1.0
	# A move the hands would have managed that the surface took, or a missed jump, is a fall.
	var surface_fail: bool = mv.kind == "jump" or (surface and roll < skill_chance)
	if surface_fail or fall_roll < minf(RockClimb.FALL_MAX, RockClimb.FALL_PER_TRY * tries):
		return _fall()
	if retry:
		retry = false
		return Outcome.SLIPPED
	retry = true
	return Outcome.RESTED


## A stone hits the climber (see WallStage): a climber who braced against the rock takes nothing, otherwise
## the stone knocks them off with KNOCK_OFF (`roll` below it) and else only grazes them.
func struck(braced: bool, roll: float) -> int:
	if on_ground():
		return Outcome.BRACED
	if braced:
		return Outcome.BRACED
	if roll < KNOCK_OFF:
		return _fall()
	return Outcome.GRAZED


func _fall() -> int:
	var from_up := 0.0 if on_ground() else float(map.height - cell.y)
	var to_up := 0.0 if nail == NOWHERE else float(map.height - nail.y)
	last_fall = maxf(0.0, (from_up - to_up) * WallMap.SQUARE)
	cell = nail
	streak = 0
	tries = 0
	retry = true
	if nail != NOWHERE:
		falls += 1
		if falls >= RockClimb.MAX_FALLS:
			return Outcome.GAVE_UP
	return Outcome.FELL
