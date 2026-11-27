class_name ProspectGeology
extends RefCounted
## The ground of the open map as a prospector reads it (see Prospecting): which rocks lie where, what a
## handful of earth or a chip of mountain is made of, and which ore that points to. Pure rules with no
## nodes, so tests/prospecting.gd can check them without a game.
##
## The land is cut into patches (jittered cells of PATCH tiles); every patch has one of five ROCKS, the
## same for the ground and for the mountain above it. A spot's main rock is the rock of its nearest patch;
## near a border the rock of the next patch mixes in as the secondary rock, but only for the pairs
## geology allows (can_mix). On open ground a skin of weathered red sandstone often lies on top.
##
## A sample is {cell, source, main, main_pct, second, second_pct, trace_pct, traces, noise, noise_pct,
## anomaly, anomaly_pct} with the shares adding up to 100: the main rock 50 to 85 %, the secondary 15 to
## 40 % when there is one, trace elements 5 to 15 %, noise (a rock that means nothing) 1 to 5 % and now and
## then an anomaly of 1 to 3 %. The same cell and source always give the same sample.
##
## analyse() turns a sample into what the prospector tells: the most likely ore, how sure he is, how rich
## the vein and a warning where the sample misleads (fool's gold, a rock that lies deeper).

const GROUND := "boden"
const MOUNTAIN := "berg"

const SEDIMENT := "sediment"
const BASALT := "basalt"
const QUARTZ := "quarz"
const GNEISS := "gneis"
const KIMBERLITE := "kimberlit"
const ROCKS := [SEDIMENT, BASALT, QUARTZ, GNEISS, KIMBERLITE]
const ROCK_NAMES := {
	SEDIMENT: "Roter Sandstein", BASALT: "Basalt", QUARTZ: "Quarzgestein", GNEISS: "Gneis", KIMBERLITE: "Kimberlit",
}
const ROCK_COLORS := {
	SEDIMENT: Color(0.78, 0.42, 0.3), BASALT: Color(0.34, 0.35, 0.4), QUARTZ: Color(0.9, 0.88, 0.82),
	GNEISS: Color(0.62, 0.6, 0.68), KIMBERLITE: Color(0.3, 0.42, 0.34),
}
## How many patches of each rock there are (a patch's rock is drawn with these weights).
const PATCH_WEIGHTS := {SEDIMENT: 3.0, BASALT: 2.0, QUARTZ: 2.0, GNEISS: 2.0, KIMBERLITE: 1.2}
## Tiles per patch of one rock (the jittered cell of the land).
const PATCH := 18
const SALT := 7731

## The pairs of rocks that may mix (the others never do: kimberlite and basalt least of all). Red sandstone
## mixes with any other rock: it is the weathered debris on top, the rock that matters lies deeper.
const MIXES := [[GNEISS, QUARTZ], [BASALT, QUARTZ], [GNEISS, KIMBERLITE]]

## The ores a rock points to, with a weight each.
const ORES := {
	"eisen": "Eisen", "kupfer": "Kupfer", "silber": "Silber", "gold": "Gold",
	"edelstein": "Rubin und Smaragd", "diamant": "Diamant", "aether": "Ätherquarz", "mithril": "Mithril",
}
const ORE_COLORS := {
	"eisen": Color(0.72, 0.5, 0.4), "kupfer": Color(0.85, 0.5, 0.3), "silber": Color(0.82, 0.86, 0.92),
	"gold": Color(1.0, 0.82, 0.3), "edelstein": Color(0.9, 0.25, 0.4), "diamant": Color(0.7, 0.92, 1.0),
	"aether": Color(0.75, 0.55, 1.0), "mithril": Color(0.55, 0.9, 0.95), "": Color(0.6, 0.6, 0.6),
}
const ROCK_ORES := {
	SEDIMENT: {"eisen": 6.0, "gold": 0.6},
	BASALT: {"kupfer": 6.0, "silber": 3.0},
	QUARTZ: {"gold": 5.0, "silber": 4.0},
	GNEISS: {"edelstein": 6.0},
	KIMBERLITE: {"diamant": 5.0},
}
## Where two rocks meet ore is denser, and a diamond pipe of kimberlite breaking through gneiss most of all.
const CONTACT_BONUS := 1.5
const PIPE_BONUS := 2.0
## The sandstone skin: its ores count for this much when it is only debris on top of another rock.
const DEBRIS_FACTOR := 0.4

## The trace elements: where they occur and which ore they raise ("boost": the ore's weight is multiplied).
const TRACES := {
	"rost": {"name": "Rostflecken", "rocks": [SEDIMENT, QUARTZ], "boost": {SEDIMENT: {"eisen": 3.0}, QUARTZ: {"gold": 3.0}}},
	"malachit": {"name": "Grünspan", "rocks": [BASALT], "boost": {BASALT: {"kupfer": 4.0}}},
	"bleiglanz": {"name": "Bleiglanz", "rocks": [QUARTZ, BASALT], "boost": {QUARTZ: {"silber": 4.0}, BASALT: {"silber": 4.0}}},
	"glimmer": {"name": "Glimmer und Granat", "rocks": [GNEISS], "boost": {GNEISS: {"edelstein": 3.0}}},
	"olivin": {"name": "Olivin", "rocks": [KIMBERLITE], "boost": {KIMBERLITE: {"diamant": 4.0}}},
}
## Pyrite shines like gold but is fool's gold: it points to iron and sulphur, and gold seldom comes with it.
const DECOY := "pyrit"
const DECOY_NAME := "Pyrit"
const DECOY_ROCKS := [SEDIMENT, QUARTZ, BASALT]
const DECOY_GOLD := 0.35
const DECOY_IRON := 1.5
## The chance that a sample's trace elements are the true ones of its rock (else pyrite or plain dust).
const TRUE_TRACE := {GROUND: 0.6, MOUNTAIN: 0.85}
const DECOY_CHANCE := 0.5
## Anomalies point to the fantasy ores. They are rare; weathered ground hides them better than a fresh chip
## of mountain.
const ANOMALIES := {
	"resonanz": {"name": "Leuchtstaub", "rocks": [GNEISS, QUARTZ], "ore": "aether"},
	"sternenstaub": {"name": "Sternenstaub", "rocks": [KIMBERLITE, BASALT], "ore": "mithril"},
}
const ANOMALY_CHANCE := {GROUND: 0.07, MOUNTAIN: 0.14}
const ANOMALY_WEIGHT := 9.0
## On open ground a skin of sandstone lies over another rock this often.
const DEBRIS_CHANCE := 0.4

## How sure the prospector is: the best ore's share of all the ores the sample points to.
const SURE := 0.6
const MAYBE := 0.35
## Richness: poor, fair and rich, by chance (contact zones lift a tier).
const RICHNESS := ["arm", "mittel", "reich"]
const RICH_ODDS := [0.3, 0.5, 0.2]
## Under this much total weight a sample points to no ore at all.
const BARREN := 0.9


## Whether two rocks may share a sample.
static func can_mix(a: String, b: String) -> bool:
	if a == b:
		return false
	if a == SEDIMENT or b == SEDIMENT:
		return true
	var pair := [a, b]
	pair.sort()
	return MIXES.has(pair)


static func _hash(a: int, b: int, c: int) -> int:
	return hash([a, b, c, SALT])


## The site of the patch `cell` belongs to (a tile coordinate) and its rock.
static func _site(px: int, py: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(px, py, 1)
	var pos := Vector2((px + rng.randf_range(0.15, 0.85)) * PATCH, (py + rng.randf_range(0.15, 0.85)) * PATCH)
	var total := 0.0
	for r in ROCKS:
		total += PATCH_WEIGHTS[r]
	var pick := rng.randf() * total
	var rock: String = ROCKS[0]
	for r in ROCKS:
		pick -= PATCH_WEIGHTS[r]
		if pick <= 0.0:
			rock = r
			break
	return {"pos": pos, "rock": rock}


## The two nearest patches of a tile, nearest first: [{rock, dist}, {rock, dist}].
static func patches(cell: Vector2i) -> Array:
	var px := floori(float(cell.x) / PATCH)
	var py := floori(float(cell.y) / PATCH)
	var found: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var site := _site(px + dx, py + dy)
			found.append({"rock": site.rock, "dist": (site.pos as Vector2).distance_to(Vector2(cell))})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.dist < b.dist)
	# The second nearest patch of a different rock: a neighbour of the same rock changes nothing.
	var out: Array = [found[0]]
	for i in range(1, found.size()):
		if found[i].rock != found[0].rock:
			out.append(found[i])
			break
	if out.size() == 1:
		out.append({"rock": "", "dist": 1.0e9})
	return out


## The sample of a spot: the same cell and source always make the same one.
static func sample(cell: Vector2i, source: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(cell.x, cell.y, 2 if source == MOUNTAIN else 3)
	var near := patches(cell)
	var main: String = near[0].rock
	var second := ""
	var wanted := 0
	# Near a border the next patch's rock mixes in: the closer to the border, the more of it.
	var other: String = near[1].rock
	var closeness := float(near[0].dist) / maxf(float(near[1].dist), 0.01)
	if other != "" and closeness > 0.55 and can_mix(main, other):
		second = other
		wanted = roundi(lerpf(15.0, 40.0, clampf((closeness - 0.55) / 0.45, 0.0, 1.0)))
	# On open ground weathered red sandstone often lies over the rock beneath.
	if second == "" and source == GROUND and main != SEDIMENT and rng.randf() < DEBRIS_CHANCE:
		second = SEDIMENT
		wanted = rng.randi_range(15, 30)
	var anomaly := _roll_anomaly(main, second, source, rng)
	var noise_pct := rng.randi_range(1, 5)
	var anomaly_pct := rng.randi_range(1, 3) if anomaly != "" else 0
	var fixed := noise_pct + anomaly_pct
	var trace_pct := 0
	var main_pct := 0
	var second_pct := 0
	if second != "":
		trace_pct = rng.randi_range(5, 15)
		var rest := 100 - fixed - trace_pct
		second_pct = clampi(wanted, maxi(15, rest - 85), mini(40, rest - 50))
		main_pct = rest - second_pct
	else:
		# Alone, the main rock may not pass 85 %: the rest is made up of trace elements.
		trace_pct = rng.randi_range(maxi(5, 15 - fixed), 15)
		main_pct = 100 - fixed - trace_pct
	var noise := ""
	var candidates: Array = ROCKS.filter(func(r: String) -> bool: return r != main and r != second)
	noise = candidates[rng.randi() % candidates.size()]
	return {
		"cell": [cell.x, cell.y], "source": source,
		"main": main, "main_pct": main_pct, "second": second, "second_pct": second_pct,
		"trace_pct": trace_pct, "traces": _roll_traces(main, second, source, trace_pct, rng),
		"noise": noise, "noise_pct": noise_pct, "anomaly": anomaly, "anomaly_pct": anomaly_pct,
	}


static func _roll_anomaly(main: String, second: String, source: String, rng: RandomNumberGenerator) -> String:
	if rng.randf() >= float(ANOMALY_CHANCE[source if ANOMALY_CHANCE.has(source) else GROUND]):
		return ""
	var fitting: Array = []
	for id: String in ANOMALIES:
		var rocks: Array = ANOMALIES[id].rocks
		if rocks.has(main) or (second != "" and rocks.has(second)):
			fitting.append(id)
	return "" if fitting.is_empty() else fitting[rng.randi() % fitting.size()]


## The trace elements of a sample as [{id, pct}] adding up to `total`: the true ones of its rock, or
## pyrite where that can be, or just dust (nothing listed).
static func _roll_traces(main: String, second: String, source: String, total: int, rng: RandomNumberGenerator) -> Array:
	var true_ids: Array = []
	for id: String in TRACES:
		var rocks: Array = TRACES[id].rocks
		if rocks.has(main) or (second != "" and rocks.has(second)):
			true_ids.append(id)
	var ids: Array = []
	if not true_ids.is_empty() and rng.randf() < float(TRUE_TRACE[source if TRUE_TRACE.has(source) else GROUND]):
		ids.append(true_ids[rng.randi() % true_ids.size()])
		# A second true trace now and then.
		if true_ids.size() > 1 and rng.randf() < 0.3:
			var more: Array = true_ids.filter(func(i: String) -> bool: return i != ids[0])
			ids.append(more[rng.randi() % more.size()])
	elif (DECOY_ROCKS.has(main) or DECOY_ROCKS.has(second)) and rng.randf() < DECOY_CHANCE:
		ids.append(DECOY)
	var out: Array = []
	var left := total
	for i in ids.size():
		var share := left if i == ids.size() - 1 else maxi(1, roundi(total * 0.6))
		out.append({"id": ids[i], "pct": share})
		left -= share
	return out


## What a sample is made of as a list of [name, percent] in the order of their share, for the window.
static func composition(s: Dictionary) -> Array:
	var out: Array = [[ROCK_NAMES[s.main], int(s.main_pct)]]
	if str(s.second) != "":
		out.append([ROCK_NAMES[s.second], int(s.second_pct)])
	for t: Dictionary in s.traces:
		out.append([trace_name(str(t.id)), int(t.pct)])
	if int(s.trace_pct) > 0 and s.traces.is_empty():
		out.append(["Staub und Sand", int(s.trace_pct)])
	if str(s.anomaly) != "":
		out.append([ANOMALIES[s.anomaly].name, int(s.anomaly_pct)])
	out.append([ROCK_NAMES[s.noise], int(s.noise_pct)])
	return out


static func trace_name(id: String) -> String:
	return DECOY_NAME if id == DECOY else str(TRACES[id].name)


## The weight of every ore a sample points to (see the constants above).
static func odds(s: Dictionary) -> Dictionary:
	var w := {}
	var main: String = s.main
	var second: String = s.second
	var debris := second != "" and (main == SEDIMENT or second == SEDIMENT)
	for pair in [[main, int(s.main_pct)], [second, int(s.second_pct)]]:
		var rock: String = pair[0]
		if rock == "":
			continue
		var factor := float(pair[1]) / 100.0
		if debris and rock == SEDIMENT:
			factor *= DEBRIS_FACTOR
		for ore: String in ROCK_ORES[rock]:
			w[ore] = float(w.get(ore, 0.0)) + float(ROCK_ORES[rock][ore]) * factor
	# Where two true rocks meet (no mere debris) the ore is denser.
	if second != "" and not debris:
		for ore: String in w:
			w[ore] = float(w[ore]) * CONTACT_BONUS
		if [main, second].has(KIMBERLITE) and [main, second].has(GNEISS) and w.has("diamant"):
			w["diamant"] = float(w["diamant"]) * PIPE_BONUS
	for t: Dictionary in s.traces:
		var id := str(t.id)
		if id == DECOY:
			if w.has("gold"):
				w["gold"] = float(w["gold"]) * DECOY_GOLD
			w["eisen"] = float(w.get("eisen", 0.0)) + DECOY_IRON
			continue
		var boost: Dictionary = TRACES[id].boost
		for rock: String in boost:
			if rock == main or rock == second:
				for ore: String in boost[rock]:
					if w.has(ore):
						w[ore] = float(w[ore]) * float(boost[rock][ore])
	if str(s.anomaly) != "":
		w[ANOMALIES[s.anomaly].ore] = ANOMALY_WEIGHT
	return w


## What the prospector makes of a sample: {ore, chance, richness, also, warn, deeper}.
## ore: the most likely ore ("" when the ground is barren), chance: "sicher", "vielleicht" or "spur",
## richness: "arm", "mittel" or "reich", also: the next ore, warn: "pyrit" or "" and deeper: whether the
## real rock lies below a skin of debris. The same sample always gets the same answer.
static func analyse(s: Dictionary) -> Dictionary:
	var w := odds(s)
	var total := 0.0
	for ore: String in w:
		total += float(w[ore])
	var ranked: Array = w.keys()
	ranked.sort_custom(func(a: String, b: String) -> bool: return float(w[a]) > float(w[b]))
	var best: String = ranked[0] if not ranked.is_empty() else ""
	var next: String = ranked[1] if ranked.size() > 1 else ""
	var warn := ""
	for t: Dictionary in s.traces:
		if str(t.id) == DECOY:
			warn = DECOY
	var deeper: bool = str(s.second) != "" and (s.main == SEDIMENT or s.second == SEDIMENT)
	var out := {"ore": "", "chance": "spur", "richness": "arm", "also": "", "warn": warn, "deeper": deeper}
	if best == "" or total < BARREN:
		return out
	var share := float(w[best]) / total
	var rng := RandomNumberGenerator.new()
	var cell: Array = s.cell
	rng.seed = _hash(int(cell[0]), int(cell[1]), 4)
	var tier := 0
	var roll := rng.randf()
	if roll > RICH_ODDS[0]:
		tier = 1
	if roll > RICH_ODDS[0] + RICH_ODDS[1]:
		tier = 2
	var contact: bool = str(s.second) != "" and not deeper
	if contact:
		tier = mini(tier + 1, 2)
	out.ore = best
	out.chance = "sicher" if share >= SURE else ("vielleicht" if share >= MAYBE else "spur")
	out.richness = RICHNESS[tier]
	out.also = next if next != "" and float(w[next]) >= 0.5 * float(w[best]) else ""
	return out
