class_name SlimeLife
extends RefCounted
## A slime of the open air does not live for ever.
##
## - While there is neither rain, fog nor storm it slowly dries out: it loses
##   one level every FADE_SECONDS (it shrinks, and its water turns dull and
##   dusty). Wet weather stops the drying, and its colour comes back. A slime
##   that is down to level 1 and dries out once more is gone, and what it
##   gathered in its belly lies on the ground (see Level.spill_belly), the
##   townsfolk it swallowed free.
## - Slimes only belong to spring's bad weather (see SlimeGrowth.may_crawl): when the rain, storm or
##   fog clears, or the season turns, every slime of the open air retreats to the pond at once.
## - A slime that has crawled about for LIFESPAN seconds retreats to the
##   nearest pond (see Outdoor._pond_waters) and sinks into it. It takes
##   everything it gathered with it, but lets the townsfolk out on the bank.
## Both clocks run in real seconds of play, like the slime's growth, and
## need no random numbers.

## Seconds of dry weather per level lost.
const FADE_SECONDS := 60.0
## Seconds a slime lives before it goes back to the pond (one hour).
const LIFESPAN := 3600.0
## Seconds of dry weather until a slime is at its dullest, and seconds the
## colour needs to come back once it is wet again.
const DULL_SECONDS := 120.0
const WET_RECOVER := 20.0
## How far its water turns to this dusty colour at its dullest.
const DULL := Color(0.52, 0.46, 0.36)
const DULL_AMOUNT := 0.7
## How close to the bank (metres) it must be to sink.
const SHORE_REACH := 1.0
## Seconds it takes to melt away or sink.
## Seconds after which a slime that cannot reach the bank sinks where it stands.
const RETREAT_PATIENCE := 300.0
const VANISH_TIME := 1.6
const FADE_COLOUR := Color(0.85, 0.78, 0.55)

const LEARN := "Schleime trocknen aus: Solange es weder regnet noch nebelt, verliert ein Schleim jede Minute eine Stufe. Er schrumpft und wird matt und staubig. Ein Schleim ohne Stufe zerfließt und lässt zurück, was er gesammelt hat. Nach einer Stunde zieht ein Schleim zum nächsten Teich und versinkt darin, samt allem, was er gesammelt hat. Die Dorfbewohner in seinem Bauch lässt er am Ufer frei."


## Whether the weather keeps slimes wet.
static func is_wet(weather: String) -> bool:
	return weather == Weather.RAIN or weather == Weather.FOG or weather == Weather.STORM


## Whether this slime ages and dries: only the slimes of the open air.
static func ages(e: Enemy) -> bool:
	return e.level is Outdoor and SlimeGrowth.grows(e.kind) and not e.dead and e.swallowed_by == null and not e.vanishing


## One tick of a slime's life (from Enemy._physics_process).
static func tick(e: Enemy, delta: float) -> void:
	if not ages(e):
		return
	var outdoor: Outdoor = e.level
	var wet := is_wet(outdoor.weather)
	if wet:
		e.dryness = maxf(0.0, e.dryness - delta / WET_RECOVER)
	elif not e.retreating:
		e.dryness = minf(1.0, e.dryness + delta / DULL_SECONDS)
	e.show_dryness()
	e.slime_age += delta
	if not e.retreating and (e.slime_age >= LIFESPAN or not SlimeGrowth.may_crawl(outdoor.weather, outdoor.season_day)):
		start_retreat(e)
	if e.retreating or wet:
		return
	e.dry_time += delta
	if e.dry_time >= FADE_SECONDS:
		e.dry_time -= FADE_SECONDS
		fade_a_level(e)


## The slime loses a level, or dries up at level 1.
static func fade_a_level(e: Enemy) -> void:
	var old := e.rated_level
	if old <= 1:
		dry_up(e)
		return
	var target := old - 1
	var now := Enemy.fit_level(e.kind, e._stats, e.hardening, 1, target)
	if now >= old:
		# Nothing left to take away.
		dry_up(e)
		return
	e.rated_level = now
	e.life_bonus = e.life_bonus * now / old
	if e.blob and now < SlimeGrowth.BLOB_LEVEL:
		e.unblob()
	e.hp = mini(e.hp, e.max_hp())
	e._resize(SlimeGrowth.size_of(e))
	Effects.head_text(e.level, e, 2.2 * float(e._stats.size) + 0.6, Lang.t("Stufe %d") % now, FADE_COLOUR)


## Down to nothing: it melts away and lays down what it gathered.
static func dry_up(e: Enemy) -> void:
	e.vanishing = true
	e.level.spill_belly(e)
	SlimeGrowth.release_folk(e)
	Effects.head_text(e.level, e, 2.2 * float(e._stats.size), Lang.t("Der Schleim trocknet aus."), FADE_COLOUR)
	e.melt_away(false)


## The hour is up: the slime heads for the nearest pond.
static func start_retreat(e: Enemy) -> void:
	e.retreating = true
	e.shore = shore_for(e.level as Outdoor, e.global_position)
	e.snack = null
	e.meal = null
	e.foe = null
	e._wall_target = null
	e._path.clear()
	Effects.head_text(e.level, e, 2.2 * float(e._stats.size), Lang.t("Der Schleim zieht sich zum Teich zurück."), FADE_COLOUR)
	if e.level.player != null and e._flat_distance(e.level.player) < Enemy.SIGHT:
		Events.teach(LEARN)


## The bank spot beside the pond nearest to `from`, or INF without a pond:
## the open tile next to the water that is closest to `from`.
static func shore_for(outdoor: Outdoor, from: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for w in outdoor._pond_waters:
		var cell: Vector2i = w.cell
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := cell + Vector2i(dx, dy)
				if (dx == 0 and dy == 0) or not outdoor.is_open(c):
					continue
				var spot := outdoor.cell_to_world(c)
				var d := Vector2(spot.x - from.x, spot.z - from.z).length()
				if d < best_d:
					best_d = d
					best = spot
	return best


## The slime reached the bank: it lets the townsfolk out and sinks, with all
## it has gathered.
static func sink_into_pond(e: Enemy) -> void:
	e.vanishing = true
	SlimeGrowth.release_folk(e)
	e.belly.clear()
	e.clear_swallowed()
	Effects.head_text(e.level, e, 2.2 * float(e._stats.size), Lang.t("Der Schleim versinkt im Teich."), FADE_COLOUR)
	e.melt_away(true)


## The colours of a slime's water, `dryness` (0..1) of the way to dusty.
static func dulled(murk: Array, dryness: float) -> Array:
	if dryness <= 0.0:
		return murk
	var out := []
	for c: Color in murk:
		out.append(c.lerp(DULL, DULL_AMOUNT * dryness))
	return out
