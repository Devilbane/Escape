class_name WoodcutterShift
## The woodcutter's working day and the timber he cuts.
##
## Bruno stays out at his trunk in the woods through his shift. He leaves it only
## for his breaks (a midday meal and supper), when the village raises the alarm
## (see Villager.alarm), and when his shift is over; then he strolls through the
## village like the others until he goes to bed.
##
## While he chops he cuts one piece of timber every SECONDS_PER_TIMBER real
## seconds into his stock, up to CAP. He sells timber from that stock (see
## Menus._build_woodcutter), so it can run out, and timber the hero sells back
## goes into it. A new game starts him with START pieces. When the hero is away
## from the open air (down a dungeon) nobody sees him, so his shift alone says
## whether he chops.

const START := 200
const CAP := 999
const SECONDS_PER_TIMBER := 20.0
## His shift, in hours of the day (see DayNight), and his breaks within it.
const SHIFT_START := 6.0
const SHIFT_END := 19.0
const BREAKS := [[12.0, 13.0], [17.0, 17.5]]


## Whether `hour` lies in one of his breaks.
static func on_break(hour: float) -> bool:
	return BREAKS.any(func(b: Array) -> bool: return hour >= float(b[0]) and hour < float(b[1]))


## Whether he is meant to be at his trunk at `hour`: within his shift and not on a break.
static func at_work(hour: float) -> bool:
	return hour >= SHIFT_START and hour < SHIFT_END and not on_break(hour)


## The stock after `delta` more seconds of chopping, with `carry` the seconds
## already chopped towards the next piece. Returns [stock, carry].
static func cut(stock: int, carry: float, delta: float) -> Array:
	if stock >= CAP:
		return [CAP, 0.0]
	carry += delta
	var pieces := int(carry / SECONDS_PER_TIMBER)
	carry -= pieces * SECONDS_PER_TIMBER
	return [mini(stock + pieces, CAP), carry]
