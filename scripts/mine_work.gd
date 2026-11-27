class_name MineWork
extends RefCounted
## The rules of a hero's own mine, with no nodes (the world, the window and the saved game call these; see
## tests/mine_work.gd). A mine belongs to one mining plot (see Plots.MINING), only one mine to a plot, and
## starts from a prospecting mark (see Prospecting): the sample is the baseline of what the rock holds.
##
## The five stages of the mine:
## 1. Tunnelling ("Schlägel und Eisen"): every advance breaks the face by ADVANCE of a square metre of the plot.
##    With hammer and chisel it also goes on while the hero is away: one advance for every OFFLINE_HOURS hours,
##    at most OFFLINE_MAX_HOURS hours a day. Hard rock (quartz, gneiss) is too hard for that.
## 2. Fire-setting: in hard rock the hero lays a fire against the face and quenches it (a blast, wood and a
##    bucket of water); every blast is one advance. The hero is warned and has to do it themselves.
## 3. Timbering: every SPAN advances need a support (wood) before the next one, or the tunnel stays shut.
## 4. Hauling: the broken rock lies at the face until it is hauled out, a bucket at a time (BUCKET trips carry
##    BUCKET_LOAD) or by mine cart (CART_LOAD); the hauled rock is the stockpile, whose component masses add up.
## 5. Processing: stamping and washing (see process) turns the stockpile into ore.
##
## The yield: the shares of the ore components start from the sample and drift with every advance. The higher a
## share already is, the less likely it rises again and the more likely it stays or falls (it pulls back to the
## middle); now and then, very rarely and only for the valuable ores, a share leaps up.

const ADVANCE := 0.25
const OFFLINE_HOURS := 4.0
const OFFLINE_MAX_HOURS := 4.0
const SPAN := 2
## The rocks too hard for hammer and chisel: they need fire.
const HARD := [ProspectGeology.QUARTZ, ProspectGeology.GNEISS]
## What the face holds of each ore at the start, by the richness the prospector reported.
const START := {"arm": 0.08, "mittel": 0.16, "reich": 0.28}
## No share rises above this.
const CAP := 0.6
## The most a share may rise or fall at one advance (as a fraction of itself), and the chance of a leap.
const STEP_MIN := 0.05
const STEP_MAX := 0.25
const LEAP_CHANCE := 0.02
const LEAP_FACTOR := 1.6
## The ores a leap may happen in: the valuable ones.
const LEAP_ORES := ["gold", "diamant", "aether", "mithril", "edelstein"]
## Mass of rock one advance breaks, and what a bucket and a cart carry in one trip.
const ROCK_PER_ADVANCE := 8.0
const BUCKET_LOAD := 2.0
const CART_LOAD := 8.0
## How much of the ore in the stamped, washed rock is kept.
const RECOVERY := 0.85
## One unit of ore counts for this much mass.
const ORE_UNIT := 1.0
## The mine cart: timber to build it (see build_cart).
const CART_TIMBER := 4
## Grams of metal one unit of washed ore gives, and the units of a gem ore that make one uncut gem.
const GRAMS_PER_UNIT := 250
const UNITS_PER_GEM := 3
## The ores that come out as uncut gems; every other ore is a metal (mithril is the unknown metal).
const GEM_ORES := ["edelstein", "diamant", "aether"]


## A new mine over the prospecting mark `mark` (see Prospecting.mark_from) on the plot `plot_key`.
## {"plot", "rock", "shares", "start", "advances", "supports", "face", "stock", "fires", "mill"}.
static func found(plot_key: String, mark: Dictionary) -> Dictionary:
	var report: Dictionary = mark.report
	var sample: Dictionary = mark.sample
	var w := ProspectGeology.odds(sample)
	var best := float(w.get(str(report.ore), 0.0))
	var shares := {}
	if str(report.ore) != "" and best > 0.0:
		var base: float = START[str(report.richness)]
		for ore: String in w:
			var s := base * float(w[ore]) / best
			if s >= 0.01:
				shares[ore] = minf(s, CAP)
	return {
		"plot": plot_key, "rock": _rock_of(sample), "shares": shares, "start": shares.duplicate(),
		"advances": 0, "supports": 0, "face": 0.0, "stock": {}, "stock_mass": 0.0, "fires": 0,
	}


## The rock that makes the mine's walls: the main rock of the sample, or the rock under the debris.
static func _rock_of(sample: Dictionary) -> String:
	if str(sample.main) == ProspectGeology.SEDIMENT and str(sample.second) != "":
		return str(sample.second)
	return str(sample.main)


static func is_hard(mine: Dictionary) -> bool:
	return HARD.has(str(mine.rock))


## Whether a support has to be set before the next advance.
static func needs_support(mine: Dictionary) -> bool:
	return int(mine.advances) >= (int(mine.supports) + 1) * SPAN


## Why the hero cannot advance by `how` ("hammer" or "fire") now, or "" when they can.
static func why_not(mine: Dictionary, how: String) -> String:
	if needs_support(mine):
		return Lang.t("Der Stollen ist nicht abgestützt: Setz erst einen Stützbalken.")
	if how == "hammer" and is_hard(mine):
		return Lang.t("Das Gestein ist zu hart für Schlägel und Eisen. Setz das Feuer an und lösche es mit Wasser.")
	return ""


## One advance by hammer ("hammer") or by a blast of fire-setting ("fire"). Returns the change in
## {"ok", "why", "rock", "shares"} where rock is the mass broken loose at the face.
static func advance(mine: Dictionary, how: String, rng: RandomNumberGenerator) -> Dictionary:
	var why := why_not(mine, how)
	if why != "":
		return {"ok": false, "why": why, "rock": 0.0}
	mine["advances"] = int(mine.advances) + 1
	if how == "fire":
		mine["fires"] = int(mine.fires) + 1
	drift(mine, rng)
	mine["face"] = float(mine.face) + ROCK_PER_ADVANCE
	return {"ok": true, "why": "", "rock": ROCK_PER_ADVANCE}


## The chance that a share of size `s` rises at one advance, and that it falls. The higher the share, the
## smaller the first and the bigger the second: the ratio of "stays or falls" to "rises" only grows.
static func p_up(s: float) -> float:
	return maxf(0.005, 0.45 * pow(1.0 - clampf(s / CAP, 0.0, 1.0), 2.0))


static func p_down(s: float) -> float:
	return clampf(0.3 + 0.4 * (s / CAP), 0.0, 0.7)


## Lets every share rise, stay or fall, and now and then leap.
static func drift(mine: Dictionary, rng: RandomNumberGenerator) -> void:
	var shares: Dictionary = mine.shares
	for ore: String in shares.keys():
		var s := float(shares[ore])
		var roll := rng.randf()
		var step := rng.randf_range(STEP_MIN, STEP_MAX)
		if LEAP_ORES.has(ore) and rng.randf() < LEAP_CHANCE:
			s *= LEAP_FACTOR
		elif roll < p_up(s):
			s *= 1.0 + step
		elif roll < p_up(s) + p_down(s):
			s *= 1.0 - step
		shares[ore] = clampf(s, 0.0, CAP)


## The advances the hero's hammer makes while away `hours` hours: one for every OFFLINE_HOURS hours, no more
## than OFFLINE_MAX_HOURS hours a day. Hard rock and a tunnel without a support stand still.
static func offline_advances(mine: Dictionary, hours: float) -> int:
	if is_hard(mine) or hours < OFFLINE_HOURS:
		return 0
	var days := ceili(hours / 24.0)
	var usable := minf(hours, days * OFFLINE_MAX_HOURS)
	return int(floor(usable / OFFLINE_HOURS))


## Applies what the hammer did while the hero was away. Returns the number of advances made.
static func catch_up(mine: Dictionary, hours: float, rng: RandomNumberGenerator) -> int:
	var made := 0
	for i in offline_advances(mine, hours):
		if not advance(mine, "hammer", rng).ok:
			break
		made += 1
	return made


## Sets a support (wood). Returns whether one was needed.
static func support(mine: Dictionary) -> bool:
	if not needs_support(mine):
		return false
	mine["supports"] = int(mine.supports) + 1
	return true


## Hauls rock from the face to the stockpile: one trip with `load` mass. Returns the mass moved. The
## stockpile keeps the masses of every component, which add up.
static func haul(mine: Dictionary, carry: float) -> float:
	var moved := minf(float(mine.face), carry)
	if moved <= 0.0:
		return 0.0
	mine["face"] = float(mine.face) - moved
	var stock: Dictionary = mine.stock
	for ore: String in mine.shares:
		stock[ore] = float(stock.get(ore, 0.0)) + moved * float(mine.shares[ore])
	mine["stock_mass"] = float(mine.stock_mass) + moved
	return moved


## What one hauling trip carries: a bucket, or a cart once it is built.
static func trip_load(mine: Dictionary) -> float:
	return CART_LOAD if bool(mine.get("cart", false)) else BUCKET_LOAD


## Builds the mine cart (the caller takes the timber). Returns whether it was built.
static func build_cart(mine: Dictionary) -> bool:
	if bool(mine.get("cart", false)):
		return false
	mine["cart"] = true
	return true


## The share of each ore in the whole stockpile.
static func stock_shares(mine: Dictionary) -> Dictionary:
	var out := {}
	var mass := float(mine.stock_mass)
	if mass <= 0.0:
		return out
	for ore: String in mine.stock:
		out[ore] = float(mine.stock[ore]) / mass
	return out


## Stamps and washes the stockpile: returns {ore: units} kept and empties the stockpile.
static func process(mine: Dictionary) -> Dictionary:
	var out := {}
	for ore: String in mine.stock:
		var units := int(floor(float(mine.stock[ore]) * RECOVERY / ORE_UNIT))
		if units > 0:
			out[ore] = units
	mine["stock"] = {}
	mine["stock_mass"] = 0.0
	return out


## The stamp mill (pochen): crushes the stockpile into pulp, which waits for the washing trough. Returns the mass
## crushed.
static func stamp(mine: Dictionary) -> float:
	var mass := float(mine.stock_mass)
	if mass <= 0.0:
		return 0.0
	var pulp: Dictionary = mine.get("pulp", {})
	for ore: String in mine.stock:
		pulp[ore] = float(pulp.get(ore, 0.0)) + float(mine.stock[ore])
	mine["pulp"] = pulp
	mine["pulp_mass"] = float(mine.get("pulp_mass", 0.0)) + mass
	mine["stock"] = {}
	mine["stock_mass"] = 0.0
	return mass


## The washing trough: the pulp's heavy ore settles, the rest runs off. Returns {ore: units} kept.
static func wash(mine: Dictionary) -> Dictionary:
	var out := {}
	var pulp: Dictionary = mine.get("pulp", {})
	for ore: String in pulp:
		var units := int(floor(float(pulp[ore]) * RECOVERY / ORE_UNIT))
		if units > 0:
			out[ore] = units
	mine["pulp"] = {}
	mine["pulp_mass"] = 0.0
	return out


## What the washed ore is worth to the hero: {"grams": {metal: grams}, "gems": uncut gems}. Metals go to the forge's
## stores (see Forge.add_grams), gem ores become uncut gems; a part of a gem too small is lost.
static func yield_of(units: Dictionary) -> Dictionary:
	var grams := {}
	var gem_units := 0
	for ore: String in units:
		if GEM_ORES.has(ore):
			gem_units += int(units[ore])
		else:
			var metal := Ore.UNKNOWN if ore == "mithril" else ore
			grams[metal] = int(grams.get(metal, 0)) + int(units[ore]) * GRAMS_PER_UNIT
	return {"grams": grams, "gems": gem_units / UNITS_PER_GEM}
