class_name HomeHoard
extends RefCounted
## The hoard at home: an upgrade of the hero's town house (see HomeUpgrades, "hort") that shows
## the hero's wealth as heaps of coins. It grows in STAGES stages, from a few loose coins to a
## mountain of them, and its mix of metals follows the coins the hero carries: someone with 200
## copper and 50 silver sees four copper coins for each silver coin. The heaps are drawn with
## CoinPile, so they glint and glow like any pile of coins lying about.
##
## Everything here is pure: the coins go in, the stage and the heaps come out.

## How many stages the hoard has (stage 0 is no wealth at all: the bare plinth).
const STAGES := 20
## The wealth (in copper) each stage needs: STEPS[i] is the wealth of stage i + 1.
const STEPS := [1, 10, 25, 50, 100, 200, 350, 600, 1000, 1600, 2500, 4000, 6000, 9000, 13000, 19000, 28000, 40000, 60000, 100000]
## The metals of the hoard, from the one the hero has most of in the money to the rarest.
const METALS := ["kupfermuenze", "silbermuenze", "goldmuenze"]
## How many coins the heaps show together at the first and the last stage.
const SHOWN_FIRST := 4
const SHOWN_LAST := 4600


## The hero's wealth in copper: every coin at its worth (see Loot.COIN_VALUE).
static func wealth(copper: int, silver: int, gold: int) -> int:
	return maxi(copper, 0) + maxi(silver, 0) * int(Loot.COIN_VALUE["silbermuenze"]) + maxi(gold, 0) * int(Loot.COIN_VALUE["goldmuenze"])


## The stage of a wealth: 0 for none, up to STAGES.
static func stage_of(worth: int) -> int:
	var stage := 0
	for need in STEPS:
		if worth >= need:
			stage += 1
	return stage


## How many coins all the heaps show together at a stage (0 at stage 0): they grow by the same
## factor from one stage to the next.
static func shown_at(stage: int) -> int:
	if stage <= 0:
		return 0
	var t := float(clampi(stage, 1, STAGES) - 1) / float(STAGES - 1)
	return roundi(SHOWN_FIRST * pow(float(SHOWN_LAST) / SHOWN_FIRST, t))


## The coins each metal's heap shows at a stage: the shown coins split in the ratio of the coins the
## hero holds of each metal (largest remainder), and a metal the hero has at all never vanishes.
## Returns metal -> count, with only the metals that have a heap.
static func mix(stage: int, held: Dictionary) -> Dictionary:
	var total := shown_at(stage)
	var have := 0
	for m in METALS:
		have += maxi(int(held.get(m, 0)), 0)
	var out := {}
	if total <= 0 or have <= 0:
		return out
	var owned: Array = METALS.filter(func(m): return int(held.get(m, 0)) > 0)
	total = maxi(total, owned.size())
	var left := total
	var rest := []
	for m in owned:
		var exact := float(total) * int(held[m]) / have
		out[m] = maxi(1, int(exact))
		left -= out[m]
		rest.append([exact - int(exact), m])
	rest.sort_custom(func(a, b): return a[0] > b[0])
	var i := 0
	while left > 0 and not rest.is_empty():
		out[rest[i % rest.size()][1]] += 1
		left -= 1
		i += 1
	# A heap given a coin it did not earn gives it back from the biggest.
	while left < 0:
		var big: String = owned[0]
		for m in owned:
			if out[m] > out[big]:
				big = m
		out[big] -= 1
		left += 1
	return out


## The text told when the hero walks up to the hoard.
static func describe(stage: int, held: Dictionary) -> String:
	if stage <= 0:
		return Lang.t("Dein Hort ist noch leer. Münzen in deiner Börse und in der Truhe lassen ihn wachsen.")
	return Lang.t("Dein Hort: Stufe %d von %d. Kupfer %d, Silber %d, Gold %d.") % [stage, STAGES,
			int(held.get("kupfermuenze", 0)), int(held.get("silbermuenze", 0)), int(held.get("goldmuenze", 0))]
