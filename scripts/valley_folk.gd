class_name ValleyFolk
extends RefCounted
## The people of the farming valley and what they do all day (day plan "farm", see Villager).
##
## Each time a farmer is free, they pick one job that fits the season and the hour, walk to its place
## (the edge of a field, the river bank, the well, a door, the flock) and spend a while at it with the
## job's own movement. Noon is a rest at the well. Nobody does the same job twice in a row, and the
## spots are found from the map, so a map that has been redrawn still works. Night, beds and doors are
## the village's own business (see Villager.set_night).
##
## Jobs: {id, say, seasons (empty: all year), from/to (hours; a job with them is only done then, and goes first), who (role letters), where,
## anim, sow (true: the seed goes in the ground, see edge_sow_spots), extra}. `where` is a field letter (see CropFields), "river", "well", "door", "flock" or "edge" (any field).

const FARMERS := "φψχλ"
## Their lines of the day, said now and then over their head: German, with English in scripts/lang/valley.gd.
const SAY_CHANCE := 0.45
const SAY_RANGE := 22.0

const JOBS := [
	{"id": "plough", "say": "Ich pflüge den Acker für die Aussaat.", "seasons": ["spring"], "who": "φχ", "where": "≡", "anim": "1H_Melee_Attack_Chop"},
	{"id": "sow_wheat", "say": "Der Weizen kommt in die Erde.", "seasons": ["spring"], "who": "φψχ", "where": "≡", "anim": "Throw", "sow": true},
	{"id": "sow_maize", "say": "Hier säe ich den Mais.", "seasons": ["spring"], "who": "φχ", "where": "‡", "anim": "Throw", "sow": true},
	{"id": "sow_sun", "say": "Die Sonnenblumenkerne brauchen Sonne und Geduld.", "seasons": ["spring"], "who": "ψ", "where": "☼", "anim": "Throw", "sow": true},
	{"id": "water", "say": "Wasser vom Fluss für die Setzlinge!", "seasons": ["spring", "summer"], "who": "ψχ", "where": "river", "anim": "PickUp"},
	{"id": "weed_maize", "say": "Unkraut zwischen dem Mais. Es wächst schneller als der Mais selbst.", "seasons": ["summer"], "who": "φχ", "where": "‡", "anim": "PickUp"},
	{"id": "weed_sun", "say": "Die Sonnenblumen sehen aus wie lauter kleine Sonnen.", "seasons": ["summer"], "who": "ψ", "where": "☼", "anim": "PickUp"},
	{"id": "scythe", "say": "Der Weizen ist reif. Jetzt wird gemäht!", "seasons": ["summer"], "who": "φχ", "where": "≡", "anim": "1H_Melee_Attack_Chop"},
	{"id": "harvest_maize", "say": "Die Maiskolben sind prall und gelb.", "seasons": ["autumn"], "who": "φψχ", "where": "‡", "anim": "PickUp"},
	{"id": "harvest_sun", "say": "Sonnenblumenkerne für den Winter, und für die Vögel.", "seasons": ["autumn"], "who": "ψ", "where": "☼", "anim": "PickUp"},
	{"id": "stubble", "say": "Die Stoppeln bleiben stehen, die Tiere freuen sich.", "seasons": ["autumn"], "who": "φ", "where": "≡", "anim": "Interact"},
	{"id": "sacks", "say": "Die Säcke müssen in die Scheune, bevor es regnet.", "seasons": ["summer", "autumn"], "who": "χ", "where": "door", "anim": "PickUp"},
	{"id": "firewood", "say": "Brennholz für den Winter, nie genug davon.", "seasons": ["autumn", "winter"], "who": "φχ", "where": "door", "anim": "2H_Melee_Attack_Chop"},
	{"id": "mend", "say": "Die Geräte müssen wieder in Schuss kommen.", "seasons": ["winter", "spring"], "who": "φχ", "where": "door", "anim": "Interact"},
	{"id": "fetch_ice", "say": "Das Wasser am Fluss ist halb gefroren. Brr.", "seasons": ["winter"], "who": "ψ", "where": "river", "anim": "PickUp"},
	{"id": "garden", "say": "Ein paar Rüben und Kohl im Garten halten sich auch im Winter.", "seasons": ["winter", "spring", "autumn"], "who": "ψ", "where": "door", "anim": "PickUp"},
	{"id": "flock", "say": "Meine Schafe sind brav, solange keiner pfeift.", "seasons": [], "who": "λ", "where": "flock", "anim": "Idle"},
	{"id": "flock_look", "say": "Der Wolf kommt nie bis ins Tal. Hoffe ich.", "seasons": [], "who": "λ", "where": "flock", "anim": "Interact"},
	# The beekeeper (see Beekeeper) works among the hives of the apiary (see Apiary), all year round.
	{"id": "tend", "say": "Ich sehe nach dem Stock. Die Bienen dürfen ruhig zusehen.", "seasons": ["spring", "summer"], "who": "β", "where": "hive", "anim": "Interact"},
	{"id": "smoke", "say": "Etwas Rauch, und die Bienen bleiben ruhig. Meistens.", "seasons": ["spring", "summer"], "who": "β", "where": "hive", "anim": "Idle"},
	{"id": "swarm", "say": "Im Sommer schwärmen sie. Dann laufe ich mit dem Korb hinterher.", "seasons": ["summer"], "who": "β", "where": "hive", "anim": "PickUp"},
	{"id": "honey", "say": "Die Waben sind voll! Der erste Honig der Saison.", "seasons": ["summer", "autumn"], "who": "β", "where": "hive", "anim": "PickUp"},
	{"id": "wrap", "say": "Im Winter bekommen die Stöcke ein Strohkleid. Die Bienen frieren nie.", "seasons": ["autumn", "winter"], "who": "β", "where": "hive", "anim": "Interact"},
	{"id": "quiet", "say": "Hör mal: Im Winter summt der Stock leise wie eine Katze.", "seasons": ["winter", "spring"], "who": "β", "where": "hive", "anim": "Idle"},
	{"id": "rest", "say": "Mittagspause! Ein Schluck Wasser, ein Stück Brot.", "seasons": [], "from": 12.0, "to": 13.5, "who": "φψχ", "where": "well", "anim": "Idle"},
]


## The job a farmer takes next: {id, say, spot, face, anim}, or {} when there is nothing to do.
static func pick(v: Villager, last_id := "") -> Dictionary:
	var level: Outdoor = v.level
	var season := Weather.season(level.season_day)
	var hour := level.hour
	var choices: Array = []
	for job: Dictionary in JOBS:
		if not String(job.who).contains(v.role):
			continue
		if not (job.seasons as Array).is_empty() and not season in job.seasons:
			continue
		if job.has("from") and not (hour >= float(job.from) and hour < float(job.to)):
			continue
		if job.get("sow", false):
			# Sowing goes on tile after tile while some soil lies bare, and not a day longer.
			if edge_sow_spots(level, job.where).is_empty():
				continue
		elif job.id == last_id and not job.has("from"):
			continue
		choices.append(job)
	# The rest at noon overrides everything else.
	for job: Dictionary in choices:
		if job.has("from"):
			choices = [job]
			break
	if choices.is_empty():
		return {}
	choices.shuffle()
	for job: Dictionary in choices:
		var place := _place(level, v, job)
		if not place.is_empty():
			# Hannes does not just rest at noon: he sits down and dozes off (see ValleyEvents).
			var anim: String = "Sit_Floor_Idle" if job.id == "rest" and v.role == "φ" else job.anim
			var out := {"id": job.id, "say": job.say, "spot": place.spot, "face": place.face, "anim": anim}
			if job.get("sow", false):
				out["sow"] = job.where
			return out
	return {}


## A place for the job: where to stand and what to face, or {}.
static func _place(level: Outdoor, v: Villager, job: Dictionary) -> Dictionary:
	var where: String = job.where
	var spots: Array = []
	if where == "river":
		spots = bank_spots(level)
	elif where == "well":
		spots = well_spots(level)
	elif where == "door":
		spots = door_spots(level)
	elif where == "flock":
		spots = flock_spots(level)
	elif where == "hive":
		spots = hive_spots(level)
	elif CropFields.LETTERS.contains(where):
		spots = edge_sow_spots(level, where) if job.get("sow", false) else edge_spots(level, where)
	if spots.is_empty():
		return {}
	if job.get("sow", false):
		# Along the rows: on to the bare tile nearest to where the sower stands now.
		var here := v.global_position
		spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.spot.distance_squared_to(here) < b.spot.distance_squared_to(here))
		return spots[v._rng.randi() % mini(spots.size(), 3)]
	# Nearest few to the farmer's home, one of them by chance: the whole farm is worked, not one corner.
	var home := level.cell_to_world(v.home)
	var sorted := spots.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.spot.distance_squared_to(home) < b.spot.distance_squared_to(home))
	var pool := sorted.slice(0, mini(sorted.size(), 14))
	return pool[v._rng.randi() % pool.size()]


## Where a farmer can stand beside the fields of a letter: free ground next to a tile of the field, each
## facing it. Found once per level.
static func edge_spots(level: Outdoor, letter: String) -> Array:
	var key := "valley_edge_" + String(CropFields.NAMES[letter])
	if level.has_meta(key):
		return level.get_meta(key)
	var out: Array = []
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if level.cell_char(c) != letter:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if level.is_open(c + d) and level.cell_char(c + d) in ".,":
					out.append({"spot": level.cell_to_world(c + d), "face": level.cell_to_world(c)})
	level.set_meta(key, out)
	return out


## The spots beside the bare tiles of a field still waiting for the seed (see CropFields.bare_tiles): a sower
## stands beside the next tile to sow, so he works along the rows. Empty outside spring or when all is sown.
static func edge_sow_spots(level: Outdoor, letter: String) -> Array:
	if level.crop_fields == null:
		return []
	var bare: Array = level.crop_fields.bare_tiles(letter)
	if bare.is_empty():
		return []
	var out: Array = []
	for e: Dictionary in edge_spots(level, letter):
		for mid: Vector3 in bare:
			if Vector2(mid.x - e.face.x, mid.z - e.face.z).length() < 0.5:
				out.append(e)
				break
	return out


## The river bank: free grass beside the water.
static func bank_spots(level: Outdoor) -> Array:
	if level.has_meta("valley_bank"):
		return level.get_meta("valley_bank")
	var out: Array = []
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if level.cell_char(c) != "≈":
				continue
			for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if level.is_open(c + d) and level.cell_char(c + d) == ".":
					out.append({"spot": level.cell_to_world(c + d), "face": level.cell_to_world(c)})
	level.set_meta("valley_bank", out)
	return out


## The wells of the valley: beside each, a free tile.
static func well_spots(level: Outdoor) -> Array:
	var out: Array = []
	for y in range(level.height - 1, -1, -1):
		if y < Outdoor.VALLEY_FROM:
			break
		for x in level.width:
			var c := Vector2i(x, y)
			if level.cell_char(c) != "q":
				continue
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if level.is_open(c + d):
					out.append({"spot": level.cell_to_world(c + d), "face": level.cell_to_world(c)})
					break
	return out


## The doors of the valley's houses, with a spot out in front.
static func door_spots(level: Outdoor) -> Array:
	var out: Array = []
	for h: Vector3 in level.spots.houses:
		if level.world_to_cell(h).y >= Outdoor.VALLEY_FROM:
			out.append({"spot": h, "face": h + Vector3(0, 0, -2)})
	return out


## In front of the hives of the apiary (see Apiary), facing them.
static func hive_spots(level: Outdoor) -> Array:
	var out: Array = []
	if level.apiary == null:
		return out
	for h: Dictionary in level.apiary.hives:
		var spot: Vector3 = h.pos + h.front * 1.15
		spot.y = 0.0
		if level.is_open(level.world_to_cell(spot)):
			out.append({"spot": spot, "face": h.pos})
	return out


## Beside the sheep of the valley.
static func flock_spots(level: Outdoor) -> Array:
	var out: Array = []
	for a: FarmAnimal in level.farm_animals:
		if a.kind == "sheep" and level.world_to_cell(a.global_position).y >= Outdoor.VALLEY_FROM:
			var c := level.world_to_cell(a.global_position)
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if level.is_open(c + d):
					out.append({"spot": level.cell_to_world(c + d), "face": a.global_position})
					break
	return out
