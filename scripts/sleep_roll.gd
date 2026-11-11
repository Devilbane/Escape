class_name SleepRoll
extends RefCounted
## Skills grow in two steps: practice makes a level RIPE, a night makes it
## happen. The game never says a skill is ripe (no bar, no number): the
## skill tree shows only how the hero FEELS about it (see tip), and the
## feeling can be wrong.
##
## A night is at least NIGHT_SECONDS of real time away from the game (one per
## absence), and up to FIRST_NIGHTS_LEVEL any sleep in a bed counts as one at
## once, so a new player learns the ritual in the first hour. A night gives
## one roll per dream slot (see slots) to the ripest skills. The wait for a
## breakthrough is on average WAIT_SHARE of the nights the level took to fill,
## at least MIN_WAIT: the chance on the k-th night after ripening is
## base(F) x night quality x (1 + STREAK x (k - 1)), at most CHANCE_MAX.
## A roll at or under a tenth of the chance is a flash of insight
## (Geistesblitz): a head start into the next level.
##
## The state is one Dictionary kept with the hero (see Player.sleep_state):
##   {"nights": int, "mood": float, "run": int, "flash": bool,
##    "skills": {id: {"earned": level won so far, "fill": nights practised,
##      "wait": nights rolled in vain, "practised": bool, "ripe_seen": bool,
##      "img": self-image, "img_level": level it was drawn for,
##      "felt": the feeling as of the last night, "history": [...]}}}
## "earned" is the level the hero really has; training past it waits for the
## night. A skill without an entry is not held back (see entry).
##
## Every text is German with an English entry in scripts/lang/sleep_roll.gd.

const NIGHT_SECONDS := 8.0 * 3600.0
## Up to this hero level a sleep in any bed counts as a night at once.
const FIRST_NIGHTS_LEVEL := 10
const WAIT_SHARE := 0.3
const MIN_WAIT := 1.3
const STREAK := 0.5
const CHANCE_MAX := 0.95
## More than this many hours away is "well rested".
const RESTED_HOURS := 20.0
const RESTED := 1.05
const SLOTS := 3
const SLOTS_MAX := 6
const WISE_SLOT_1 := 14
const WISE_SLOT_2 := 18
## What the place of the night does to the chance.
const PLACES := {"ground": 0.8, "camp": 0.9, "bed": 1.0, "inn": 1.0, "home": 1.15}
## At most this share of a level carries over into the next one.
const CARRY := 0.1
## A flash of insight starts the next level a quarter of the way.
const HEAD_START := 0.25
## Extra practice past full raises the chance, up to this much.
const SURPLUS_MAX := 0.2
const HISTORY_KEEP := 30
## Share of the roll's chance that is a flash of insight.
const FLASH_SHARE := 0.1

## Feeling edges (felt progress, 0..) between the six bands.
const BAND_EDGES := [0.15, 0.40, 0.65, 0.90, 1.15]
const SPREAD_START := 0.28
const SPREAD_PER_WISDOM := 0.02
const SPREAD_MIN := 0.10
## Beginners overrate themselves a little.
const BASIC_BIAS := 1.1
const MOOD_SPREAD := 0.05
const MOOD_MISS := -0.08
const MOOD_WIN := 0.05
## Nights of missed rolls in a row after which the hero despairs.
const DESPAIR_RUN := 3

const SHOUTS := ["Ich hab’s!", "Na endlich!", "Ja! JA!", "Wusste ich’s doch!", "Hah! Geschafft!"]
const EUREKA := "Heureka!"
## Seconds a level's bubble stays over the hero, and the flash of insight's.
const BUBBLE_SECONDS := 2.5
const EUREKA_SECONDS := 4.0

## The feeling lines, by band (0 just starting .. 5 dreaming of it), each with
## its tone: plain, hopeful, funny, gloomy or extreme.
const FEELINGS := [
	[["plain", "Noch ganz am Anfang."], ["gloomy", "Das dauert ewig."], ["funny", "Ich habe keine Ahnung, was ich da tue."],
		["funny", "Meine Großmutter könnte das besser."], ["gloomy", "Wer hat sich das bloß ausgedacht?"],
		["extreme", "Hoffnungslos. Völlig hoffnungslos."], ["extreme", "Ein Huhn hätte mehr Talent."]],
	[["plain", "Langsam wird es."], ["gloomy", "So schwer …"], ["gloomy", "Ich gebe auf. Morgen vielleicht wieder."],
		["plain", "Zwei Schritte vor, einer zurück."], ["funny", "Immerhin habe ich mich nicht selbst verletzt."],
		["extreme", "Ich hasse alles daran."], ["extreme", "Warum tue ich mir das an?!"]],
	[["plain", "Es fühlt sich vertrauter an."], ["plain", "Manchmal klappt es, manchmal nicht."],
		["funny", "Ich glaube, ich mache Fortschritte. Glaube ich."], ["gloomy", "Wird das jemals etwas?"],
		["funny", "Nicht mehr peinlich, nur noch mittelmäßig."], ["extreme", "Halbwegs brauchbar. Ein Triumph!"],
		["extreme", "Ich bin weder Genie noch Idiot. Leider."]],
	[["plain", "Da tut sich etwas."], ["hopeful", "Es wird!"], ["hopeful", "Gestern ging es fast wie von selbst."],
		["funny", "Werde ich besser oder nur mutiger?"], ["gloomy", "Ich bin nah dran … oder?"],
		["extreme", "Etwas Großes kündigt sich an!"], ["extreme", "Ich spüre Macht. Oder Hunger."]],
	[["plain", "Es liegt mir auf der Zunge."], ["hopeful", "Ich bin nah dran."], ["hopeful", "Nur noch ein kleines Stück."],
		["gloomy", "Warum klappt es denn immer noch nicht?!"], ["hopeful", "Ich spüre es in den Fingerspitzen."],
		["extreme", "GLEICH! GLEICH! GLEICH!"], ["extreme", "Ich halte das nicht mehr aus!"]],
	[["plain", "Ich träume schon davon."], ["funny", "Das kann ich im Schlaf."], ["hopeful", "Heute Nacht passiert es. Ganz bestimmt."],
		["funny", "Ich bin ein Naturtalent!"], ["gloomy", "Wenn das jetzt nicht klappt, werde ich Bauer."],
		["extreme", "Ich bin eine Legende. Fast."], ["extreme", "Zittert, ihr Meister!"]],
]
## What lies ahead, by band: said after the feeling, like a second thought.
const AHEAD := [
	["Bis dahin ist es noch ein weiter Weg.", "Ich fange besser mal an."],
	["Ein paar Wochen wird es wohl noch dauern.", "Noch viel Übung liegt vor mir."],
	["Mit ein paar guten Tagen könnte es etwas werden.", "Die Hälfte ist wohl geschafft."],
	["Ein, zwei gute Abende noch.", "Lange kann es nicht mehr dauern."],
	["Eine Nacht darüber schlafen, dann sehen wir weiter.", "Morgen früh weiß ich mehr."],
	["Ich sollte einfach schlafen gehen.", "Mehr Übung bringt heute nichts mehr. Ein Bett wäre gut."],
]
const CONNECTORS := ["Außerdem:", "Dazu kommt:", "Und noch etwas:"]
const DESPAIR := "Ich werfe alles hin und werde Ziegenhirt. Ziegen urteilen nicht."
const MEGALOMANIA := "Ich bin unaufhaltsam. Ich bin das Schicksal. Ich bin müde."
const MAXED := "Mehr kann ich dazu nicht mehr lernen."


## A fresh state.
static func empty() -> Dictionary:
	return {"nights": 0, "mood": 0.0, "run": 0, "flash": false, "skills": {}}


## The state read back from the saved hero (anything unreadable is dropped).
static func checked(data) -> Dictionary:
	var out := empty()
	if not (data is Dictionary):
		return out
	out.nights = int(data.get("nights", 0))
	out.mood = float(data.get("mood", 0.0))
	out.run = int(data.get("run", 0))
	out.flash = bool(data.get("flash", false))
	var skills = data.get("skills", {})
	if skills is Dictionary:
		for id in skills:
			if Training.SKILLS.has(id) and skills[id] is Dictionary:
				var e: Dictionary = skills[id]
				var history: Array = []
				for h in e.get("history", []):
					if h is Dictionary:
						history.append({"level": int(h.get("level", 0)), "fill": int(h.get("fill", 1)),
							"wait": int(h.get("wait", 0)), "flash": bool(h.get("flash", false))})
				out.skills[id] = {"earned": int(e.get("earned", 0)), "fill": int(e.get("fill", 0)),
					"wait": int(e.get("wait", 0)), "practised": bool(e.get("practised", false)),
					"ripe_seen": bool(e.get("ripe_seen", false)), "img": float(e.get("img", 1.0)),
					"img_level": int(e.get("img_level", -1)), "felt": float(e.get("felt", 0.0)), "history": history}
	return out


## The skill's entry; a skill without one gets it now, at the level its
## training has reached (so a hero from before the nights keeps every level).
static func entry(state: Dictionary, id: String, xp: Dictionary) -> Dictionary:
	if not state.skills.has(id):
		state.skills[id] = {"earned": Training.skill_level(float(xp.get(id, 0.0)), id), "fill": 0, "wait": 0,
			"practised": false, "ripe_seen": false, "img": 1.0, "img_level": -1, "felt": 0.0, "history": []}
	return state.skills[id]


## The level the hero has won in `id`; the training level for a skill that is
## not held back yet.
static func earned(state: Dictionary, id: String, xp: Dictionary) -> int:
	var trained := Training.skill_level(float(xp.get(id, 0.0)), id)
	if not state.skills.has(id):
		return trained
	return mini(trained, int(state.skills[id].earned))


## Whether the training has filled the level (a night can give it now).
static func ripe(state: Dictionary, id: String, xp: Dictionary) -> bool:
	if not state.skills.has(id):
		return false
	var level := int(state.skills[id].earned)
	return level < Training.skill_max(id) and Training.skill_level(float(xp.get(id, 0.0)), id) > level


## Progress towards the next level as a share (1 and more: full), from the
## training past the level won.
static func progress(state: Dictionary, id: String, xp: Dictionary) -> float:
	var level := earned(state, id, xp)
	if level >= Training.skill_max(id):
		return 1.0
	return (float(xp.get(id, 0.0)) - Training.skill_xp_for(level)) / Training.skill_step_cost(level)


## Dream slots a night has: 3, one more at Weisheit 14 and 18 and one in the
## hero's own bed.
static func slots(wisdom: int, place: String) -> int:
	var n := SLOTS
	if wisdom >= WISE_SLOT_1:
		n += 1
	if wisdom >= WISE_SLOT_2:
		n += 1
	if place == "home":
		n += 1
	return mini(n, SLOTS_MAX)


## The chance (0..1) on the first night for a level that took `fill` nights
## to fill: set so that the average wait in an inn bed is WAIT_SHARE of it.
static func base_chance(fill: int) -> float:
	var target := maxf(MIN_WAIT, WAIT_SHARE * maxi(fill, 1))
	var low := 0.00001
	var high := 1.0
	for i in 40:
		var mid := (low + high) * 0.5
		if expected_wait(mid) > target:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


## The average number of nights to a breakthrough with this base chance.
static func expected_wait(base: float, quality := 1.0) -> float:
	var total := 0.0
	var alive := 1.0
	for k in range(1, 4000):
		total += alive
		alive *= 1.0 - minf(CHANCE_MAX, base * quality * (1.0 + STREAK * (k - 1)))
		if alive < 0.0001:
			break
	return total


## The chance (0..1) of night number `k` (1 = the first after ripening).
static func chance(fill: int, quality: float, k: int) -> float:
	return minf(CHANCE_MAX, base_chance(fill) * quality * (1.0 + STREAK * (k - 1)))


## Everything that bends the chance: the place, a long rest, the skill's
## attributes (2 % a point from 12) and practice past full.
static func quality(place: String, hours: float, attribute_average: float, surplus: float) -> float:
	var q: float = PLACES.get(place, 1.0)
	if hours > RESTED_HOURS:
		q *= RESTED
	q *= clampf(1.0 + 0.02 * (attribute_average - 12.0), 0.8, 1.3)
	q *= 1.0 + minf(SURPLUS_MAX, 0.1 * maxf(surplus, 0.0))
	return q


## Marks that the hero practised a skill today (see Player.train).
static func practise(state: Dictionary, id: String, xp: Dictionary) -> void:
	entry(state, id, xp).practised = true


## One night. `xp` is the hero's training (it keeps the head start of a flash
## of insight), `place` one of PLACES, `hours` the real hours away, `wisdom`
## the hero's Weisheit, `attributes` a Callable from a skill id to the
## average of its attributes, `day` any number to date the history by.
## Returns {"won": [{id, level, flash}], "missed": [id], "practised": [id]}.
static func night(state: Dictionary, xp: Dictionary, place: String, hours: float, wisdom: int,
		attributes: Callable, day: int, rng: RandomNumberGenerator) -> Dictionary:
	state.nights += 1
	var result := {"won": [], "missed": [], "practised": []}
	var candidates := []
	for id in state.skills:
		var e: Dictionary = state.skills[id]
		if e.practised:
			result.practised.append(id)
			if not e.ripe_seen:
				e.fill += 1
		if ripe(state, id, xp):
			e.ripe_seen = true
			candidates.append(id)
	# The ripest skills get the slots.
	candidates.sort_custom(func(a, b): return progress(state, a, xp) > progress(state, b, xp))
	var room := slots(wisdom, place)
	var flashed := false
	for id in candidates:
		if room <= 0:
			break
		room -= 1
		var e: Dictionary = state.skills[id]
		var extra := progress(state, id, xp) - 1.0
		var q := quality(place, hours, float(attributes.call(id)), extra)
		var c := chance(maxi(1, int(e.fill)), q, int(e.wait) + 1)
		var roll := rng.randi_range(1, 100)
		if roll <= roundi(c * 100.0):
			var flash := roll <= maxi(1, floori(c * 100.0 * FLASH_SHARE))
			_level_up(state, id, xp, flash, day)
			result.won.append({"id": id, "level": int(e.earned), "flash": flash})
			flashed = flashed or flash
		else:
			e.wait += 1
			result.missed.append(id)
	# The mood of the morning, and the feeling about every skill.
	var mood := rng.randf_range(-MOOD_SPREAD, MOOD_SPREAD)
	if not result.missed.is_empty() and result.won.is_empty():
		state.run += 1
		mood += MOOD_MISS
	elif not result.won.is_empty():
		state.run = 0
		mood += MOOD_WIN
	state.mood = mood
	state.flash = flashed
	for id in state.skills:
		state.skills[id].practised = false
		refresh_feeling(state, id, xp, wisdom, rng)
	return result


## The level is won: the history gets a line, the training past it is cut
## back to what carries over (a share of the level), and a flash of insight
## starts the next level a quarter of the way.
static func _level_up(state: Dictionary, id: String, xp: Dictionary, flash: bool, day: int) -> void:
	var e: Dictionary = state.skills[id]
	e.earned += 1
	e.history.append({"level": e.earned, "fill": maxi(1, int(e.fill)), "wait": int(e.wait) + 1, "flash": flash, "day": day})
	while e.history.size() > HISTORY_KEEP:
		e.history.pop_front()
	e.fill = 0
	e.wait = 0
	e.ripe_seen = false
	e.img_level = -1
	var base := Training.skill_xp_for(e.earned)
	var step := Training.skill_step_cost(e.earned)
	var carry := minf(float(xp.get(id, 0.0)) - base, CARRY * step)
	if flash:
		carry = maxf(carry, HEAD_START * step)
	xp[id] = base + maxf(carry, 0.0)


## Draws the self-image for the current level once, then sets the feeling
## from the real progress, the self-image and the mood.
static func refresh_feeling(state: Dictionary, id: String, xp: Dictionary, wisdom: int, rng: RandomNumberGenerator) -> void:
	var e: Dictionary = state.skills[id]
	if int(e.img_level) != int(e.earned):
		var spread := maxf(SPREAD_MIN, SPREAD_START - SPREAD_PER_WISDOM * (wisdom - 10))
		var bias := 1.0 if Training.tier(id) == 2 else BASIC_BIAS
		e.img = bias * exp(rng.randfn(0.0, spread))
		e.img_level = e.earned
	e.felt = progress(state, id, xp) * float(e.img) + float(state.mood)


## The band of a feeling: 0 just starting out .. 5 dreaming of it.
static func band(felt: float) -> int:
	var b := 0
	for edge in BAND_EDGES:
		if felt >= edge:
			b += 1
	return b


## The hero's own words about a skill: how it feels, and what lies ahead,
## in one flowing sentence, with no number. It depends on the feeling of the
## last night, so it changes only after a night away. `seed_extra` makes
## another hero's line different.
static func tip(state: Dictionary, id: String, xp: Dictionary, seed_extra := 0) -> String:
	if earned(state, id, xp) >= Training.skill_max(id):
		return Lang.t(MAXED)
	var e: Dictionary = entry(state, id, xp)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + int(state.nights) * 7919 + seed_extra
	if int(e.img_level) != int(e.earned):
		refresh_feeling(state, id, xp, 10, rng)
	var b := band(float(e.felt))
	var wanted := _tones(float(state.mood))
	var pool: Array = []
	var extreme := int(state.run) >= DESPAIR_RUN or bool(state.flash) or rng.randf() < 0.08
	for line in FEELINGS[b]:
		if (line[0] == "extreme") == extreme and (extreme or line[0] in wanted):
			pool.append(line[1])
	if pool.is_empty():
		for line in FEELINGS[b]:
			if line[0] != "extreme":
				pool.append(line[1])
	var first: String = pool[rng.randi_range(0, pool.size() - 1)]
	if int(state.run) >= DESPAIR_RUN:
		first = DESPAIR
	elif bool(state.flash):
		first = MEGALOMANIA
	var ahead: String = AHEAD[b][rng.randi_range(0, AHEAD[b].size() - 1)]
	return "%s %s %s" % [Lang.t(first), Lang.t(CONNECTORS[rng.randi_range(0, CONNECTORS.size() - 1)]), Lang.t(ahead)]


## The tones that fit the mood of the morning.
static func _tones(mood: float) -> Array:
	if mood < -0.03:
		return ["gloomy", "plain"]
	if mood > 0.03:
		return ["hopeful", "funny", "plain"]
	return ["plain", "funny"]


## One short feeling line for the event board (never a number).
static func short_line(state: Dictionary, id: String, rng: RandomNumberGenerator) -> String:
	var e: Dictionary = state.skills.get(id, {})
	var b := band(float(e.get("felt", 0.0)))
	var wanted := _tones(float(state.mood))
	var pool: Array = []
	for line in FEELINGS[b]:
		if line[0] in wanted:
			pool.append(line[1])
	if int(state.run) >= DESPAIR_RUN:
		return Lang.t(DESPAIR)
	if pool.is_empty():
		pool.append(FEELINGS[b][0][1])
	return Lang.t(pool[rng.randi_range(0, pool.size() - 1)])


## The past levels of a skill, newest first, as lines: level, nights
## practised and nights dreamt, a mark for a flash of insight. Never the
## level being worked on.
static func history_lines(state: Dictionary, id: String, count := 3) -> Array[String]:
	var lines: Array[String] = []
	var history: Array = state.skills.get(id, {}).get("history", [])
	for i in range(history.size() - 1, maxi(history.size() - 1 - count, -1), -1):
		var h: Dictionary = history[i]
		var line := Lang.t("Stufe %d: %s geübt, %s geträumt") % [h.level, _nights(int(h.fill)), _nights(int(h.wait))]
		if bool(h.get("flash", false)):
			line += " " + Lang.t("(Geistesblitz)")
		lines.append(line)
	return lines


static func _nights(n: int) -> String:
	return Lang.t("1 Nacht") if n == 1 else Lang.t("%d Nächte") % n
