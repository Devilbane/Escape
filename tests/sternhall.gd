extends SceneTree
## Headless test for Sternhall (see SternHall): the ruined keep north of the
## wolf hollow with its four floors. The star reliefs open the secret walls
## (a high one only from up high), the wardens fight in three phases and drop
## the key ring that opens the barred doors, the prisoner hands out his task,
## the listening eyes strike a hero who does not sneak, the chasm swallows
## whoever steps in and puts them back on firm ground, the flagstones crumble,
## the anvil and the shelf help the hero, the beds' rooms are safe, the fallen
## rise again, and taking the tome seals the gate, teaches the spell and
## leaves the drain as the only way out, up into the open.
## Run with: godot --headless --fixed-fps 60 -s tests/sternhall.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait := 0
var _life := 0
var _hidden := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: sternhall" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _enter(building: String) -> void:
	game.state = game.State.PLAYING
	game.go_inside(building)


func _hero() -> Player:
	var p: Player = game.player
	p.revive(p.global_position, false)
	p.hp = p.max_hp
	p._invulnerable = 0.0
	p.frozen = false
	p.set_sneaking(false)
	p.velocity = Vector3.ZERO
	return p


func _stern() -> SternHall:
	return game.level.stern


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if wait > 0:
		wait -= 1
		return false
	match stage:
		0:
			game.hero_name = "Stern test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			_check_open_air()
			_enter("stern1")
			wait = 50
			stage = 1
		1:
			_check_floor("stern1", "", "stern2")
			check(game.lore.has(SternHall.LORE), "the compendium learns of Sternhall on the way in")
			_check_warden()
			wait = 20
			stage = 2
		2:
			_check_key_ring()
			_check_respawn()
			_enter("stern2")
			wait = 50
			stage = 3
		3:
			_check_floor("stern2", "stern1", "stern3")
			_check_safe_rooms()
			_press_low_relief()
			wait = int(Level.SECRET_DELAY * 60) + 180
			stage = 4
		4:
			_check_relief_opened()
			_check_shelf()
			_check_prisoner()
			_check_eyes()
			_enter("stern3")
			wait = 50
			stage = 5
		5:
			_check_floor("stern3", "stern2", "stern4")
			_check_high_relief()
			_check_stations()
			_start_fall()
			wait = 120
			stage = 6
		6:
			_check_fall()
			_start_flagstone()
			wait = int(SternHall.CRUMBLE_AFTER * 60) + 20
			stage = 7
		7:
			_check_flagstone()
			_enter("stern4")
			wait = 50
			stage = 8
		8:
			_check_floor("stern4", "stern3", "")
			_check_theft()
			wait = 10
			stage = 9
		9:
			_check_spell()
			wait = 5
			stage = 10
		10:
			_use_drain()
			wait = 120
			stage = 11
		11:
			_check_drain()
			_finish()
			return true
	return false


func _check_open_air() -> void:
	var lvl: Outdoor = game.level
	for b in SternHall.FLOORS:
		check(game.interiors.has(b), "the floor %s exists" % b)
	check(lvl.doors.has(SternGate.BUILDING), "the open-air map has the gate of Sternhall")
	check(lvl.doors.has(SternHall.OUTLET), "the open-air map has the drain's grate")
	check(lvl.stations.any(func(s): return s.kind == "eingang" and s.building == SternGate.BUILDING), "running into the gate leads in")
	check(not lvl.stations.any(func(s): return s.get("building", "") == SternHall.OUTLET), "the grate does not open from outside")
	var way: Array = lvl.astar.get_id_path(lvl.world_to_cell(lvl.doors[SternHall.OUTLET]), lvl.world_to_cell(lvl.doors[SternGate.BUILDING]))
	check(not way.is_empty(), "a way leads from the drain's grate to the gate")


func _check_floor(building: String, up: String, down: String) -> void:
	var lvl: Level = game.level
	check(lvl.building == building and lvl.lair, "%s is a floor of Sternhall (%s)" % [building, lvl.building])
	check(lvl.stern != null and lvl.stern.is_inside_tree(), "%s runs Sternhall's controller" % building)
	check(lvl.up_to == up and lvl.down_to == down, "%s leads up to '%s' and down to '%s' (%s, %s)" % [building, up, down, lvl.up_to, lvl.down_to])
	check(not lvl.enemies.is_empty(), "monsters live on %s" % building)
	for e in lvl.enemies:
		if e is SternBoss or HeroLevel.FIXED.has(e.kind):
			continue
		check(e.rated_level >= 17 and e.rated_level <= 21, "%s on %s is a fight for level 18 to 20 (%d)" % [e.kind, building, e.rated_level])


func _check_safe_rooms() -> void:
	var stern := _stern()
	var lvl: Level = game.level
	check(not stern.safe_cells.is_empty(), "the cellars have a safe room")
	for c: Vector2i in stern.safe_cells:
		check(lvl.cell_char(c) not in "?/`*:", "a safe tile is no secret wall, bar or chasm")
	for e in lvl.enemies:
		check(not stern.is_safe(e.global_position), "no monster starts in a safe room (%s)" % e.kind)
	# A monster that walks in is put back at the threshold.
	var foe: Enemy = null
	for e in lvl.enemies:
		if not (e is SternBoss):
			foe = e
			break
	var inside: Vector2i = stern.safe_cells.keys()[0]
	if foe:
		var was := foe.global_position
		stern._keep_out()
		foe.global_position = lvl.cell_to_world(inside)
		stern._keep_out()
		check(foe.global_position.distance_to(was) < 0.1, "a monster cannot set foot in a safe room")


func _press_low_relief() -> void:
	var stern := _stern()
	var p := _hero()
	var low: Array = stern.reliefs.filter(func(r): return not r.high)
	check(not low.is_empty(), "the cellars have a star relief")
	for r in stern.reliefs:
		check(r.group >= 0 and r.star != null, "every relief opens a secret wall (%s)" % str(r.cell))
	if low.is_empty():
		return
	var r: Dictionary = low[0]
	_hidden = r.group
	check(stern.level.stations.any(func(s): return s.kind == SternHall.RELIEF and s.relief == r), "running into the relief presses it")
	stern._press(r, p)
	check(stern.level.taken.has(SternHall.opened_key(r.cell)), "the pressed relief is remembered")


func _check_relief_opened() -> void:
	var stern := _stern()
	if _hidden < 0:
		return
	for c: Vector2i in stern.groups[_hidden]:
		var open: bool = stern.level._secrets.any(func(s): return s.cell == c and s.open)
		check(open, "the relief opened its secret wall %s" % str(c))
		check(not stern.level.astar.is_point_solid(c), "the way through %s is free" % str(c))


func _check_warden() -> void:
	var lvl: Level = game.level
	var stern := _stern()
	var boss: SternBoss = null
	for e in lvl.enemies:
		if e is SternBoss:
			boss = e
	check(boss != null, "the courtyard has its warden")
	if boss == null:
		return
	check(boss.boss_title() == "Morgrim Aschenhand", "the warden is Morgrim (%s)" % boss.boss_title())
	check(lvl.get_children().any(func(n): return n is BossBar), "the warden has a health bar")
	check(boss.rated_level >= 18, "the warden is a fight for level 18 or more (%d)" % boss.rated_level)
	var before := lvl.enemies.size()
	boss.take_hit(int(boss.max_hp() * 0.45), boss.global_position + Vector3(0, 0, 1))
	check(boss.phase == 2, "below 60%% of its life the warden enters phase 2 (%d)" % boss.phase)
	check(lvl.enemies.size() > before, "in phase 2 the warden calls for help (%d -> %d)" % [before, lvl.enemies.size()])
	boss.take_hit(int(boss.max_hp() * 0.35), boss.global_position + Vector3(0, 0, 1))
	check(boss.phase == 3, "below 30%% it is enraged (%d)" % boss.phase)
	var p := _hero()
	p.global_position = boss.global_position + Vector3(0, 0, 2.5)
	var life := p.hp
	boss._burst(p)
	check(p.hp < life, "the burst hurts a hero inside the ring (%d -> %d)" % [life, p.hp])
	p.hp = p.max_hp
	p._invulnerable = 0.0
	p.global_position = boss.global_position + Vector3(0, 0, SternBoss.NOVA_RADIUS + 2.0)
	life = p.hp
	boss._burst(p)
	check(p.hp == life, "the burst misses a hero outside the ring")
	boss.take_hit(boss.max_hp() * 2, boss.global_position + Vector3(0, 0, 1))
	check(boss.dead, "the warden falls")
	check(not stern.key_ring.is_empty(), "the warden drops the key ring")
	check(lvl.taken.get(Level.slain_key(boss.get_meta("stern_cell")), null) is bool, "a warden stays dead")


func _check_key_ring() -> void:
	var stern := _stern()
	var p := _hero()
	check(not stern.bars.is_empty(), "the courtyard has barred doors")
	for gate in stern.bars:
		check(not gate.open and stern.level.astar.is_point_solid(gate.cell), "barred doors are shut until the key ring is found")
	if stern.key_ring.is_empty():
		return
	p.global_position = stern.key_ring.pos
	stern._check_key_ring()
	check(stern.level.taken.has(SternHall.KEYS_TAKEN), "the hero picks up the key ring")
	for gate in stern.bars:
		check(gate.open and not stern.level.astar.is_point_solid(gate.cell), "the key ring opens the barred doors")


func _check_respawn() -> void:
	var stern := _stern()
	var lvl: Level = game.level
	var foe: Enemy = null
	for e in lvl.enemies:
		if not (e is SternBoss) and not e.dead and e.has_meta("stern_cell"):
			foe = e
			break
	check(foe != null, "the courtyard has a monster of its own")
	if foe == null:
		return
	var c: Vector2i = foe.get_meta("stern_cell")
	foe.take_hit(9999, foe.global_position + Vector3(0, 0, 1))
	var key := Level.slain_key(c)
	check(lvl.taken.get(key, null) is float, "a fallen monster remembers when it fell")
	lvl.taken[key] = lvl.world_hours() - SternHall.RESPAWN_HOURS - 1.0
	var p := _hero()
	p.global_position = lvl.cell_to_world(c)
	stern._respawn()
	check(lvl.taken.has(key), "nothing rises while the hero stands there")
	# Far away, out of sight: it is back.
	var far := Vector2i(-1, -1)
	for y in lvl.height:
		for x in lvl.width:
			var at := Vector2i(x, y)
			if lvl.cell_char(at) in ".," and not lvl.astar.is_point_solid(at) and not stern.is_safe(lvl.cell_to_world(at)) \
					and lvl.cell_to_world(at).distance_to(lvl.cell_to_world(c)) > SternHall.RESPAWN_FAR + 2.0 \
					and not lvl.has_line_of_sight(lvl.cell_to_world(at), lvl.cell_to_world(c)):
				far = at
	if far.x < 0:
		print("note: no far spot for the respawn check")
		return
	p.global_position = lvl.cell_to_world(far)
	var count := lvl.enemies.size()
	stern._respawn()
	check(not lvl.taken.has(key) and lvl.enemies.size() > count, "the fallen rise again after %d game hours" % int(SternHall.RESPAWN_HOURS))
	# And wardens never do.
	lvl.taken["slain:0:0"] = true
	stern.forget_old_kills()
	check(lvl.taken.has("slain:0:0"), "a warden's death is kept")


func _check_prisoner() -> void:
	var stern := _stern()
	var p := _hero()
	check(not stern.prisoner.is_empty(), "the cellars hold a prisoner")
	if stern.prisoner.is_empty():
		return
	check(stern.prisoner.figure.display_name == "Alrik der Schreiber", "the prisoner is Alrik (%s)" % stern.prisoner.figure.display_name)
	p.bag.clear()
	stern.use(stern.prisoner, p)
	check(game.quests.is_active(SternHall.QUEST), "talking to Alrik starts his task")
	check(p.bag.has(SternHall.SEAL_RING), "Alrik hands over his signet ring (%s)" % str(p.bag))
	var given: int = p.bag.count(SternHall.SEAL_RING)
	stern.use(stern.prisoner, p)
	check(p.bag.count(SternHall.SEAL_RING) == given, "he gives the ring only once")


func _check_eyes() -> void:
	var stern := _stern()
	check(stern.eyes.size() >= 4, "the cellars have listening eyes (%d)" % stern.eyes.size())
	if stern.eyes.is_empty():
		return
	var eye: Dictionary = stern.eyes[0]
	var p := _hero()
	for e in stern.level.enemies:
		e.set_physics_process(false)
	p.global_position = eye.pos + Vector3(0, -1.85, 3.0)
	p.global_position.y = 0.0
	# Sneaking past, the eye does not hear.
	p.set_sneaking(true)
	p.velocity = Vector3(2, 0, 0)
	for i in 90:
		stern._tick_eyes(1.0 / 60.0, p)
	check(eye.charge <= 0.0 and p.hp == p.max_hp, "a sneaking hero passes an eye unheard")
	# Walking, it glows and then strikes.
	p.set_sneaking(false)
	p.velocity = Vector3(4, 0, 0)
	check(p.is_noisy(), "a walking hero is noisy")
	stern._tick_eyes(1.0 / 60.0, p)
	check(eye.charge > 0.0, "a noisy hero makes the eye glow")
	for i in int(SternHall.EYE_WARN * 60) + 5:
		p.velocity = Vector3(4, 0, 0)
		stern._tick_eyes(1.0 / 60.0, p)
	check(p.hp < p.max_hp, "the eye strikes a hero who keeps making noise (%d)" % p.hp)


func _check_high_relief() -> void:
	var stern := _stern()
	var p := _hero()
	var high: Array = stern.reliefs.filter(func(r): return r.high)
	check(not high.is_empty(), "the chasm floor has a high relief")
	if high.is_empty():
		return
	var r: Dictionary = high[0]
	p.global_position = stern.level.cell_to_world(r.face)
	stern._press(r, p)
	check(not stern.level.taken.has(SternHall.opened_key(r.cell)), "a high relief is out of reach from the floor")
	check(game.lore.has(SternHall.HIGH_LORE), "the compendium explains how to reach it")
	check(Crate.SIZE * 2.0 >= SternHall.HIGH_FEET and Crate.SIZE < SternHall.HIGH_FEET, "two crates reach a high relief, one does not")
	var crates: int = stern.level.crates.size()
	check(crates >= 2, "the chasm floor has crates to stack (%d)" % crates)


func _check_stations() -> void:
	var stern := _stern()
	var lvl: Level = game.level
	var p := _hero()
	var anvils: Array = lvl.stations.filter(func(s): return s.kind == SternHall.ANVIL)
	check(anvils.size() == 1, "the forge has an anvil")
	check(lvl.stations.any(func(s): return s.kind == "bett"), "the forge has a bed to save and rest")
	if not anvils.is_empty():
		check(stern.is_safe(anvils[0].pos), "the forge is a safe room")
		stern.use(anvils[0], p)


## The jail's guard room: a bed, the fountain and a shelf with a potion a day.
func _check_shelf() -> void:
	var stern := _stern()
	var lvl: Level = game.level
	var p := _hero()
	var shelves: Array = lvl.stations.filter(func(s): return s.kind == SternHall.SHELF)
	check(shelves.size() == 1, "the guard room has a potion shelf")
	check(lvl.stations.any(func(s): return s.kind == "bett"), "the guard room has a bed to save and rest")
	if shelves.is_empty():
		return
	check(stern.is_safe(shelves[0].pos), "the guard room is a safe room")
	var potions := func(): return lvl._pickups.filter(func(q): return q.get("id", "") == SternHall.POTION).size()
	var n: int = potions.call()
	stern.use(shelves[0], p)
	check(potions.call() == n + 1, "the shelf gives a healing potion")
	stern.use(shelves[0], p)
	check(potions.call() == n + 1, "only one a day")


func _start_fall() -> void:
	var stern := _stern()
	var p := _hero()
	# The archers across the chasm are not part of this check.
	for e in stern.level.enemies:
		e.set_physics_process(false)
	var lvl: Level = game.level
	check(not stern.pits.is_empty() and not stern.flagstones.is_empty(), "the chasm floor has a chasm and flagstones")
	stern._last_safe = lvl.cell_to_world(lvl.start_cell)
	_life = p.hp
	var pit: Vector2i = stern.pits.keys()[stern.pits.size() / 2]
	for c: Vector2i in stern.pits:
		var all_round := true
		for d in Level.DIRS:
			all_round = all_round and stern.pits.has(c + d)
		if all_round:
			pit = c
			break
	p.global_position = lvl.cell_to_world(pit)
	p.reset_physics_interpolation()


func _check_fall() -> void:
	var stern := _stern()
	var p: Player = game.player
	var lvl: Level = game.level
	check(p.hp < _life, "falling into the chasm hurts (%d -> %d)" % [_life, p.hp])
	check(not stern.is_pit(lvl.world_to_cell(p.global_position)), "the hero is back on firm ground")
	check(not p.frozen, "and can move again (falling %s, dead %s, at %s)" % [stern._falling, p.dead, str(p.global_position)])
	check(game.lore.has(SternHall.CHASM_LORE), "the compendium explains the chasm")


func _start_flagstone() -> void:
	var stern := _stern()
	var p := _hero()
	if stern.flagstones.is_empty():
		return
	var f: Dictionary = stern.flagstones[0]
	p.global_position = stern.level.cell_to_world(f.cell)
	p.reset_physics_interpolation()
	stern._tick_flagstones(1.0 / 60.0, p)
	check(f.state == "shaking", "a flagstone shakes once the hero steps on it (%s)" % f.state)


func _check_flagstone() -> void:
	var stern := _stern()
	if stern.flagstones.is_empty():
		return
	var f: Dictionary = stern.flagstones[0]
	check(f.state == "down" and stern.is_pit(f.cell), "a little later it falls (%s)" % f.state)
	f.t = 0.0
	stern._tick_flagstones(1.0 / 60.0, game.player)
	f.t = 0.0
	stern._tick_flagstones(1.0 / 60.0, game.player)
	check(f.state == "solid", "and rises again (%s)" % f.state)


func _check_theft() -> void:
	var stern := _stern()
	var lvl: Level = game.level
	var p := _hero()
	check(not stern.portcullis.is_empty() and not stern.portcullis.down, "the vault's portcullis stands open")
	check(not stern.portcullis.is_empty() and stern.portcullis.body.collision_layer == 0, "and lets the hero through")
	var tome: Array = lvl._pickups.filter(func(q): return q.get("id", "") == SternHall.TOME)
	check(tome.size() == 1, "the tome lies on its lectern")
	var drains: Array = lvl.stations.filter(func(s): return s.kind == SternHall.DRAIN)
	check(drains.size() == 1, "the vault has the old drain")
	if not drains.is_empty():
		check(_drain_hidden(lvl, drains[0].cell), "the drain lies behind a secret wall")
	check(not knows_spell(), "the hero does not know the spell yet")
	if tome.is_empty():
		return
	p.bag.clear()
	p.global_position = tome[0].node.global_position
	lvl._check_pickups()
	check(lvl.taken.has(SternHall.THEFT), "taking the tome wakes the keep")
	check(p.bag.has(SternHall.TOME), "the tome goes into the bag")
	check(knows_spell(), "reading it teaches the spell")
	check(stern.portcullis.down and stern.portcullis.body.collision_layer != 0, "the portcullis shuts behind the thief")
	check(lvl.astar.is_point_solid(stern.portcullis.cell), "no way out through the gate")
	check(stern.eyes.all(func(e): return e.dead), "the eyes burst")


func _drain_hidden(lvl: Level, drain: Vector2i) -> bool:
	# Every way from the floor's start to the drain passes a secret wall.
	var todo: Array[Vector2i] = [lvl.start_cell]
	var seen := {lvl.start_cell: true}
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in Level.DIRS:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			if n == drain:
				return false
			var ch := lvl.cell_char(n)
			if ch == "" or ch in "#?":
				continue
			seen[n] = true
			todo.append(n)
	return true


func knows_spell() -> bool:
	return game.knows_spell()


func _check_spell() -> void:
	var lvl: Level = game.level
	var p := _hero()
	var foe: Enemy = null
	for e in lvl.enemies:
		if not e.dead and not (e is SternBoss) and not e.is_friend():
			foe = e
			break
	check(foe != null, "a foe to cast at")
	if foe == null:
		return
	p.global_position = foe.global_position + Vector3(0, 0, 6.0)
	p.spell_wait = 0.0
	game.spell_action()
	check(p.spell_wait > 0.0, "casting starts the cooldown")
	var bolts := lvl.get_children().filter(func(n): return n is ArcaneBolt)
	check(bolts.size() == 1, "a bolt flies")
	if not bolts.is_empty():
		check(bolts[0].target == foe, "it flies at the nearest foe")
		check(bolts[0].damage == ArcaneBolt.damage_of(p) and bolts[0].damage >= 3, "it hits hard (%d)" % bolts[0].damage)
	game.spell_action()
	check(lvl.get_children().filter(func(n): return n is ArcaneBolt).size() == 1, "no second bolt while the power gathers")


func _use_drain() -> void:
	var lvl: Level = game.level
	var drains: Array = lvl.stations.filter(func(s): return s.kind == SternHall.DRAIN)
	if not drains.is_empty():
		game._use_station(drains[0])


func _check_drain() -> void:
	check(game.level is Outdoor, "the drain leads out into the open")
	if game.level is Outdoor:
		var at: Vector3 = game.level.doors[SternHall.OUTLET]
		check(game.player.global_position.distance_to(at) < Level.TILE * 2.0, "the hero comes out beside the drain's grate (%.1f m)" % game.player.global_position.distance_to(at))
	check(game.player.bag.has(SternHall.TOME), "with the tome")
