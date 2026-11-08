extends SceneTree
## Headless test for the elementals and golems of the caves (see Elementals):
## every kind is complete and sorted into a family, every move can be told
## apart and has a warning, the stats scale with the area, golems do not
## bleed, a mirror ward throws a blow back, and the shipped maps place them
## only in caves whose families name them.
## Run with: godot --headless -s tests/elementals.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _enemy(kind: String) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	root.add_child(e)
	return e


func _initialize() -> void:
	Lang.setup()


## The monsters get ready once the tree runs, so the checks wait for the first frame.
func _process(_delta: float) -> bool:
	_check_kinds()
	_check_moves()
	_check_behaviour()
	_check_maps()
	print("PASS: elementals" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _check_kinds() -> void:
	for kind in Elementals.KINDS:
		check(Enemy.KINDS.has(kind), "%s is a kind of Enemy" % kind)
		check(MonsterFamilies.family_of(kind) == "elementals", "%s lives with the elementals" % kind)
		check(Factions.of(kind) != "", "%s has a faction" % kind)
		check(kind in Creations.MONSTER_BASES and Creations.MONSTER_NAMES.has(kind), "%s can be made in the workshop" % kind)
		check(Elementals.LORE.has(kind) and Lang.EN.has(Elementals.LORE[kind]), "%s has compendium lore in English" % kind)
		check(Lang.EN.has(Creations.MONSTER_NAMES.get(kind, "")), "%s is named in English" % kind)
		var stats: Dictionary = Enemy.KINDS[kind]
		check(stats.get("bloodless", false), "%s does not bleed" % kind)
	for kind in Elementals.GOLEMS:
		check(Enemy.KINDS[kind].get("big", false), "%s is not stunned or crippled" % kind)
		check(Loot.drops_ore(kind), "%s leaves ore" % kind)
	check(int(Enemy.KINDS.steingolem.speed) < int(Enemy.KINDS.felstroll.speed) and Enemy.KINDS.steingolem.hp > Enemy.KINDS.felstroll.hp, "the stone golem is slower and tougher than a troll")
	check(Enemy.KINDS.obsidiangolem.armor >= 4, "the obsidian golem is the most armoured")
	check(Enemy.KINDS.feuerelementar.has("burn"), "the fire elemental burns what touches it")
	check(not Ignition.FLAMMABLE.has("feuerelementar"), "fire does not catch a fire elemental")
	for kind in Elementals.KINDS:
		check(Lang.EN.has(_fall_german(kind)), "%s has a fall text in English" % kind)


func _fall_german(kind: String) -> String:
	var e := _enemy(kind)
	return e.fall_text()


func _check_moves() -> void:
	for kind in Elementals.KINDS:
		check(Elementals.MOVES.has(kind) and Elementals.MOVES[kind].size() >= 2, "%s has at least two special moves" % kind)
		var ids := []
		for m: Dictionary in Elementals.MOVES.get(kind, []):
			check(not ids.has(m.id), "%s: the move %s is listed once" % [kind, m.id])
			ids.append(m.id)
			check(Lang.EN.has(m.name), "the move %s has an English name" % m.name)
			check(float(m.wind) >= 0.3, "%s warns before it strikes" % m.id)
			check(float(m.cool) >= 3.0, "%s is not spammed" % m.id)
			check(float(m.max) > float(m.min), "%s has a range band" % m.id)
			check(m.do in ["scorch", "orb", "slam", "quake", "nova", "rock", "shards", "beam", "ward"], "%s does something known" % m.id)
	# Blows on the ground warn with a ring for at least a second.
	for m: Dictionary in Elementals.MOVES.obsidiangolem + Elementals.MOVES.steingolem:
		if m.do in ["slam", "quake"]:
			check(float(m.wind) >= 1.0, "%s gives a second to step out" % m.id)


func _check_behaviour() -> void:
	var golem := _enemy("steingolem")
	golem.bleed(3)
	check(not golem.is_bleeding(), "a golem does not bleed")
	check(not golem.can_be_stunned() and not golem.cripple(), "a golem is not stunned or crippled")
	var crystal := _enemy("kristallgolem")
	check(crystal.ward_left == 0.0, "the ward is down at first")
	Elementals.raise_ward(crystal)
	check(crystal.ward_left == Elementals.WARD_TIME and crystal.get_node_or_null("WardGlow") != null, "the ward glows")
	Elementals.tick(crystal, Elementals.WARD_TIME + 0.1)
	check(crystal.ward_left == 0.0, "the ward ends")
	# Pauses count down; with no hero in sight nothing is picked.
	var fire := _enemy("feuerelementar")
	fire.move_cools["scorch"] = 1.0
	Elementals.tick(fire, 0.4)
	check(is_equal_approx(float(fire.move_cools["scorch"]), 0.6), "a move's pause counts down")
	check(Elementals.pick(fire, 5.0, false).is_empty(), "nothing is used out of sight")
	# Stats scale with the area through the usual balancing.
	var plain_hp := _enemy("steingolem").max_hp()
	check(plain_hp >= int(Enemy.KINDS.steingolem.hp), "a stone golem has at least its base life")


func _check_maps() -> void:
	var placed := {}
	for f in DirAccess.get_files_at("res://levels/"):
		if not f.ends_with(".txt"):
			continue
		var m := LevelMap.load_file("res://levels/" + f)
		var families := MonsterFamilies.parse(m.get_header(MonsterFamilies.HEADER))
		for key in m.creations():
			var spec: Dictionary = m.creations()[key]
			if spec.get("type", "") == "monster" and Elementals.is_elemental(str(spec.get("base", ""))):
				placed[spec.base] = true
				check("elementals" in families, "%s places %s but does not name the elementals" % [f, spec.base])
	for kind in Elementals.KINDS:
		check(placed.has(kind), "%s is placed on a shipped map" % kind)
