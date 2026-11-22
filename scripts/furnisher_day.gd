class_name FurnisherDay
## The working day of Ilse the furnisher (Raumausstatterin Ilse, role ROLE).
##
## She keeps her stall on the square through her opening hours (OPEN): a morning
## and an afternoon stretch. Outside them she lives like the other townsfolk:
## she steps out of her house in the morning and strolls about the square before
## she opens, eats with the village at lunch and at dinner (see TownMeals), rests
## on a fountain bench now and then (see BenchRest), strolls again in the evening
## and goes to bed at nightfall. Lunch and dinner fall outside her hours, so the
## meals take her away from the stall only when it is shut.
##
## The hero can trade with her wherever she is: her station walks with her (see
## Villager._physics_process), so running into her at the table or on a bench opens
## her window too. During her hours she is always at the stall.

const ROLE := "µ"
## Her opening hours (see DayNight): from 8 until lunch starts gathering, and from
## half past one until the village sets off for dinner. The meals' first arrivals
## (TownMeals.meal_at) come an hour before the meal, at 11 and 18.
const OPEN := [[8.0, 11.0], [13.5, 18.0]]
## Her day plan (see Villager.ROLES) while she is open, and while she is not.
const AT_WORK := "stay"
const OFF_WORK := "stroll"


## Whether her stall is open at `hour`.
static func is_open(hour: float) -> bool:
	return OPEN.any(func(o: Array) -> bool: return hour >= float(o[0]) and hour < float(o[1]))


## Her day plan at `hour`: she keeps to her stall while it is open and strolls
## otherwise.
static func plan_at(hour: float) -> String:
	return AT_WORK if is_open(hour) else OFF_WORK
