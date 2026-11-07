class_name SternHall
extends Node3D
## Sternhall: the ruins of the star-mages' keep north of the wolf hollow, a
## place for heroes of level 18 to 20. Four floors ("building: stern1" to
## "stern4", levels/31 to 34): the ruined courtyard with the grave robbers,
## the cellars with the jail, the star chasm, and the vault, where the tome
## of unleashed power lies on its lectern. Taking it teaches the hero the
## spell of the arcane bolt (see ArcaneBolt) and seals the vault's gate: the
## way out is the old drain behind a hidden wall, up into the wolf hollow.
##
## One SternHall runs each of these floors (Level.stern). It builds the
## keep's own tiles (Tiles.DUNGEON, the "Sternhall" entries) and makes them
## work:
##   ] }  star reliefs in the walls: pressed, they open the nearest secret
##        wall (?) for good. A high one (}) is out of reach unless the hero
##        stands on something HIGH_FEET high (two crates, see Crate).
##   {    a heap of rubble as high as a man (SternLedge): climbed from a crate.
##   * :  the chasm and its crumbling flagstones. A stone falls CRUMBLE_AFTER
##        seconds after it is stepped on and rises again CRUMBLE_DOWN later.
##        A hero who steps into the chasm falls, loses FALL_SHARE of their
##        life and is back where they last stood on firm ground.
##   !    a listening eye: it hears a hero who does not sneak (Player.is_noisy)
##        within EYE_RANGE, glows for EYE_WARN seconds and, if the noise goes
##        on, strikes for EYE_SHARE of their life and wakes the monsters near.
##   /    barred doors: open once the hero picks up the key ring of the
##        floor's warden (a SternBoss with "keys").
##   `    the vault's portcullis: open until the tome is taken.
##   I ; ' )  the tome's lectern, an anvil (mends gear), a shelf with a
##        healing potion every day, and the drain out into the open.
##   -    a loose crate.
## The rooms with a bed are safe: no monster sets foot in them (they stop
## at the threshold), nothing rises again there and the keep leaves the hero
## in peace there. Monsters that fell rise again RESPAWN_HOURS game hours
## later, out of the hero's sight; the wardens never do. Underground, every
## EVENT_EVERY seconds something happens: a rockfall, an ambush of the dead,
## or the ghost of the archmagus with a word of advice.

const FLOORS := ["stern1", "stern2", "stern3", "stern4"]
## The underground floors have a mood of their own (see Mines.mood).
const THEME_YARD := "sternhof"
const THEME_VAULTS := "sterngruft"
const MOODS := {
	THEME_YARD: {"ambient": Color(0.5, 0.55, 0.68), "energy": 0.55, "light": Color(0.8, 0.85, 1.0)},
	THEME_VAULTS: {"ambient": Color(0.36, 0.3, 0.5), "energy": 0.3, "light": Color(0.75, 0.68, 1.0)},
}

## Letters that sit in the wall (they are walls to everything else).
const IN_WALL := "]}"
## Letters with no floor tile of their own.
const NO_FLOOR := "*:"

## Station kinds (see Game._use_station).
const RELIEF := "stern_relief"
const ANVIL := "stern_amboss"
const SHELF := "stern_regal"
const BARS := "stern_gitter"
const PRISONER := "stern_gefangener"
const DRAIN := "stern_abfluss"
const KINDS := [RELIEF, ANVIL, SHELF, BARS, PRISONER]
## The outdoor door the drain comes out of (see SternGate).
const OUTLET := "stern_abfluss"

## The tome, the prisoner's ring and his task (see Items, Quests).
const TOME := "foliant_der_kraft"
const SEAL_RING := "alriks_siegelring"
const QUEST := "sternhall_alrik"
const POTION := "heiltrank"

## Kept in Level.taken.
const KEYS_TAKEN := "stern:keys"
const THEFT := "stern:theft"
const QUEST_GIVEN := "stern:alrik"
const DRAIN_FOUND := "stern:drain"

const HIGH_FEET := 1.2
const FALL_DEEP := 0.9
const FALL_SHARE := 0.2
const CRUMBLE_AFTER := 1.1
const CRUMBLE_DOWN := 6.0
const CRUMBLE_RISE := 0.7
const EYE_RANGE := 12.0
const EYE_WARN := 0.7
const EYE_SHARE := 0.25
const EYE_REST := 3.0
const EYE_WAKES := 18.0
const MEND_POINTS := 40
const RESPAWN_HOURS := 8.0
const RESPAWN_FAR := 28.0
const RESPAWN_CHECK := 5.0
const SAFE_STEPS := 14
const EVENT_EVERY := Vector2(90.0, 180.0)
const FIRST_EVENT := 60.0
const ROCKFALL_SHARE := 0.15
const ROCK_RADIUS := 1.7
const ROCK_WARN := 1.3
const KEY_REACH := 1.5

## What the compendium says (see Events.teach).
const LORE := "Sternhall: die Ruine der Feste der Sterndeuter, nördlich der Wolfssenke. Grabräuber hausen im Hof, darunter liegen Gewölbe, ein Abgrund und das Sternengewölbe mit dem Folianten der Entfesselten Kraft. Sterne in den Wänden öffnen verborgene Wege. In Räumen mit einem Bett bist du sicher."
const EYE_LORE := "Lauschende Augen hören jeden Schritt, der nicht schleicht. Leuchtet ein Auge auf, schleiche sofort (Taste C), sonst trifft dich sein Blitz und weckt alles in der Nähe."
const CHASM_LORE := "Über dem Sternenschlund bröckeln die Steinplatten kurz nachdem du sie betrittst. Lauf (Umschalt) und spring (Leertaste) über die Lücken, ohne anzuhalten. Wer fällt, verliert ein Fünftel seiner Leben."
const HIGH_LORE := "Manche Sterne sitzen hoch in der Wand. Stell zwei Kisten übereinander (Kiste aufheben mit E, abstellen mit Q), steig hinauf und lauf gegen den Stern."
const SPELL_LORE := "Entfesselte Kraft: Der Foliant aus dem Sternengewölbe hat dich einen Zauber gelehrt. Taste 2 oder der Sternknopf am rechten Rand schleudert einen Bolzen reiner Kraft auf den nächsten Feind. Er durchschlägt jede Rüstung und trifft stärker, je klüger du bist (Intelligenz). Danach sammelt sich die Kraft einige Sekunden lang neu."
const DRAIN_LORE := "Hinter einer verborgenen Wand im Sternengewölbe führt ein alter Abfluss hinauf in die Wolfssenke: ein Weg hinaus, wenn das Fallgitter verschlossen ist."

## The ghost of the archmagus says one of these when he appears.
const WHISPERS := [
	"Wer schleicht, den hören meine Augen nicht.",
	"Die Sterne in den Wänden kennen die verborgenen Wege.",
	"Zwei Kisten übereinander, und kein Stern hängt zu hoch.",
	"Der Schlund verzeiht kein Zögern.",
	"Niemand, der meinen Folianten trägt, verlässt das Gewölbe durch das Tor.",
	"Ich war der Erste der Sterndeuter. Nun bin ich ihr letzter Wächter.",
]
const ARCHMAGUS := "Veyron"
const GHOST_COLOR := Color(0.55, 0.75, 1.0)

var level: Level
## In-wall reliefs: {"cell", "face" (the tile in front), "high", "star", "group"}.
var reliefs: Array = []
## The secret walls, each a list of connected "?" tiles.
var groups: Array = []
var pits := {}
var flagstones: Array = []
var eyes: Array = []
var bars: Array = []
var portcullis := {}
var lectern := {}
var safe_cells := {}
var key_ring := {}
## Where the warden who carries the key ring stands on the map.
var warden_cells: Array[Vector2i] = []
var prisoner := {}
var _ledges: Array = []
var _stars: Array = []
var _last_safe := Vector3.INF
var _falling := false
var _respawn_in := RESPAWN_CHECK
var _event_in := FIRST_EVENT
var _crate_check := 0.0
var _called: Array = []
var _shouted := false


static func is_floor(lvl: Level) -> bool:
	return lvl != null and lvl.building.begins_with("stern") and FLOORS.has(lvl.building)


static func mood(theme: String) -> Dictionary:
	return MOODS.get(theme, {})


func _init(owner_level: Level = null) -> void:
	level = owner_level
	name = "SternHall"


## Before the level is built: the reliefs in the walls become walls, so
## everything else (the wall pieces, sight, the walls' collision) treats them
## as such, and they are remembered here.
func prepare() -> void:
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			var ch := level.cell_char(c)
			if not IN_WALL.contains(ch):
				continue
			var face := Vector2i(-1, -1)
			for d in Level.DIRS:
				var n: Vector2i = c + d
				var nch := level.cell_char(n)
				if nch != "#" and not IN_WALL.contains(nch) and nch != "":
					face = n
					break
			reliefs.append({"cell": c, "face": face, "high": ch == "}", "star": null, "group": -1})
			level._set_cell(c, "#")


## Whether a tile has no floor tile of its own.
static func builds_floor(ch: String) -> bool:
	return not NO_FLOOR.contains(ch)


## Builds one of the keep's tiles (see Level._build_content).
func build_cell(c: Vector2i, ch: String) -> void:
	var pos := level.cell_to_world(c)
	match ch:
		"*":
			pits[c] = true
		":":
			flagstones.append({"cell": c, "node": SternParts.flagstone(level, c), "state": "solid", "t": 0.0})
		"{":
			var across_x := level.cell_char(c + Vector2i(0, -1)) == "#" or level.cell_char(c + Vector2i(0, 1)) == "#"
			var ledge := SternLedge.new(not across_x)
			ledge.position = pos
			level.add_child(ledge)
			_ledges.append(ledge)
			SternParts.rubble(level, c, not across_x)
		"!":
			var eye := SternParts.eye(level, pos)
			eye.merge({"cell": c, "pos": pos + Vector3(0, 1.85, 0), "charge": 0.0, "rest": 0.0, "dead": false})
			eyes.append(eye)
		"I":
			lectern = {"cell": c, "pos": pos, "glow": SternParts.lectern(level, pos)}
		";":
			SternParts.anvil(level, c)
			level.stations.append({"kind": ANVIL, "cell": c, "pos": pos, "used": false})
		"'":
			SternParts.shelf(level, c)
			level.stations.append({"kind": SHELF, "cell": c, "pos": pos, "used": false})
		")":
			SternParts.drain(level, c)
			level.stations.append({"kind": DRAIN, "cell": c, "pos": pos, "used": false})
		"/":
			var gate := level.add_grating(c)
			gate.merge({"open": false})
			bars.append(gate)
			level.stations.append({"kind": BARS, "cell": c, "pos": pos, "used": false, "gate": gate})
		"`":
			portcullis = level.add_grating(c)
			portcullis.merge({"down": true})
		"-":
			level.add_crate(pos + Vector3(0.3, 0, -0.2))


## After the tiles are built and the paths are laid (see Level.build): the
## chasm's depths, the reliefs, the secret walls they open, the safe rooms,
## and everything the hero changed here on an earlier visit.
func finish() -> void:
	var is_pit := func(n: Vector2i) -> bool: return pits.has(n) or _flagstone_at(n) != null
	for c in pits:
		SternParts.chasm(level, c, is_pit, _stars)
	for f in flagstones:
		SternParts.chasm(level, f.cell, is_pit, _stars)
	SternParts.starfield(level, _stars)
	_find_groups()
	for r in reliefs:
		if r.face.x < 0:
			continue
		var d: Vector2i = r.cell - r.face
		var wall_pos := level.cell_to_world(r.face) + Vector3(d.x, 0, d.y) * Level.TILE * 0.5
		var rot := atan2(-float(d.x), -float(d.y))
		r.star = SternParts.relief(level, wall_pos, rot, 3.3 if r.high else 1.5)
		r.group = _nearest_group(r.cell)
		level.stations.append({"kind": RELIEF, "cell": r.cell, "pos": wall_pos, "used": false, "relief": r})
		if level.taken.has(opened_key(r.cell)):
			SternParts.press_relief(r.star, true)
			_open_group(r.group, true)
	_find_safe_cells()
	_mark_safe_doors()
	for c in pits:
		level.astar.set_point_solid(c, true)
	for f in flagstones:
		level.astar.set_point_solid(f.cell, true)
	# The portcullis stands open until the theft.
	if not portcullis.is_empty():
		if level.taken.has(THEFT):
			level.astar.set_point_solid(portcullis.cell, true)
		else:
			portcullis.down = false
			portcullis.node.position.y = Level.GATE_SUNK
			portcullis.body.collision_layer = 0
			level.astar.set_point_solid(portcullis.cell, false)
	if level.taken.has(KEYS_TAKEN):
		for gate in bars:
			_open_bars(gate, true)
	for st in level.stations:
		if st.kind == "figur" and st.figure.spec.get("prisoner", false):
			st.kind = PRISONER
			prisoner = st
	if not lectern.is_empty():
		if level.taken.has(THEFT) or level.taken.has(TOME):
			lectern.glow.light_energy = 0.3
		else:
			level._drop_item(TOME, lectern.pos + Vector3(0, 0.6, 0), false)
	if level.taken.has(THEFT):
		for eye in eyes:
			_shatter_eye(eye, true)
	_event_in = FIRST_EVENT * randf_range(0.8, 1.4)


func _ready() -> void:
	level.enemy_killed.connect(_on_killed)
	level.item_collected.connect(_on_item_collected)
	# A warden who fell before his key ring was picked up left it where he stood.
	if not level.taken.has(KEYS_TAKEN):
		for c in warden_cells:
			if level.taken.get(Level.slain_key(c), null) is bool:
				_drop_key_ring(level.cell_to_world(c))
				break
	Events.teach(LORE)


static func opened_key(c: Vector2i) -> String:
	return "stern:open:%d:%d" % [c.x, c.y]


static func shelf_key(c: Vector2i) -> String:
	return "stern:shelf:%d:%d" % [c.x, c.y]


# --- Secret walls and reliefs ------------------------------------------------

func _find_groups() -> void:
	var seen := {}
	for s in level._secrets:
		var start: Vector2i = s.cell
		if seen.has(start):
			continue
		var group: Array[Vector2i] = []
		var todo: Array[Vector2i] = [start]
		seen[start] = true
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			group.append(c)
			for d in Level.DIRS:
				var n: Vector2i = c + d
				if not seen.has(n) and level.cell_char(n) == "?":
					seen[n] = true
					todo.append(n)
		groups.append(group)


func _nearest_group(c: Vector2i) -> int:
	var best := -1
	var best_d := INF
	for i in groups.size():
		for g: Vector2i in groups[i]:
			var d := Vector2(g - c).length()
			if d < best_d:
				best_d = d
				best = i
	return best


func _open_group(i: int, at_once := false) -> void:
	if i < 0 or i >= groups.size():
		return
	for c: Vector2i in groups[i]:
		level.open_secret_wall(c, at_once)


## The hero presses a relief: a high one only from up high.
func _press(r: Dictionary, player: Player) -> void:
	if level.taken.has(opened_key(r.cell)):
		Effects.float_text(level, r.star.global_position, Lang.t("Der Stern ist schon eingedrückt."), Color(0.85, 0.85, 0.85))
		return
	if r.high and (player.global_position.y < HIGH_FEET or not player.is_on_floor()):
		Events.teach(HIGH_LORE)
		Effects.float_text(level, r.star.global_position, Lang.t("Zu hoch! Du müsstest auf etwas Hohem stehen."), Color(1.0, 0.85, 0.6))
		return
	level.taken[opened_key(r.cell)] = true
	SternParts.press_relief(r.star)
	Sfx.play(self, "lever_pull", -2.0, r.star.global_position)
	Comic.pop(r.star.global_position, "lever")
	player.play_once("Interact", 0.5)
	player.train("intuition", 12.0)
	Events.bus().riddle_solved.emit("secret", HeroLevel.place_level(level))
	Events.tell(Lang.t("Der Stern gibt unter deiner Hand nach. Irgendwo in der Nähe mahlt Stein auf Stein."), Color(1.0, 0.85, 0.45))
	var here := level
	get_tree().create_timer(Level.SECRET_DELAY).timeout.connect(func():
		if not is_instance_valid(here) or here != level:
			return
		Events.bus().camera_punched.emit(1.2)
		if r.group >= 0 and r.group < groups.size():
			var at := level.cell_to_world(groups[r.group][0])
			Sfx.play(self, "rumble", 0.0, at)
			Comic.pop(at, "rumble")
		_open_group(r.group))


# --- Safe rooms --------------------------------------------------------------

## The tiles round each bed, as far as one walks without passing a secret
## wall, a heap of rubble, bars or the chasm: no monster sets foot there.
func _find_safe_cells() -> void:
	for y in level.height:
		for x in level.width:
			var bed := Vector2i(x, y)
			if level.cell_char(bed) != "B":
				continue
			var steps := {bed: 0}
			var todo: Array[Vector2i] = [bed]
			while not todo.is_empty():
				var c: Vector2i = todo.pop_front()
				safe_cells[c] = true
				if steps[c] >= SAFE_STEPS:
					continue
				for d in Level.DIRS:
					var n: Vector2i = c + d
					var ch := level.cell_char(n)
					if steps.has(n) or ch == "" or "#?{/`*:".contains(ch):
						continue
					steps[n] = steps[c] + 1
					todo.append(n)


## A faint star on the floor at each way into a safe room, so the hero
## learns to read it: the old wards of the star mages still hold here.
func _mark_safe_doors() -> void:
	for c: Vector2i in safe_cells:
		for d in Level.DIRS:
			var n: Vector2i = c + d
			var ch := level.cell_char(n)
			if safe_cells.has(n) or ch == "#" or ch == "":
				continue
			var at := level.cell_to_world(c) + Vector3(d.x, 0, d.y) * Level.TILE * 0.3
			var star := MeshInstance3D.new()
			star.mesh = SternParts.star_mesh(0.7, 0.3, 0.02)
			star.material_override = SternParts.material(SternParts.STAR_GOLD, 0.9, 0.7)
			star.rotation.x = -PI * 0.5
			star.position = at + Vector3(0, 0.03, 0)
			level.add_child(star)


func is_safe(pos: Vector3) -> bool:
	return safe_cells.has(level.world_to_cell(pos))


# --- Monsters ----------------------------------------------------------------

## A monster of the map's header made as a warden (see SternBoss), or null.
static func make_boss(spec: Dictionary) -> Enemy:
	if not spec.get("boss", false):
		return null
	var boss := SternBoss.new()
	boss.calls = str(spec.get("calls", ""))
	return boss


## Forgets the monsters that fell long enough ago (see Level._spawn_enemies):
## they are back. The wardens stay dead ("true").
func forget_old_kills() -> void:
	var now := level.world_hours()
	for key in level.taken.keys():
		var when = level.taken[key]
		if str(key).begins_with("slain:") and (when is float or when is int) and now - float(when) >= RESPAWN_HOURS:
			level.taken.erase(key)
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			var ch := level.cell_char(c)
			if level.creations.has(ch) and level.creations[ch].get("keys", false):
				warden_cells.append(c)


## Every monster the map puts here: wardens get their bar, nobody enters
## the safe rooms.
func on_spawned(e: Enemy, c: Vector2i) -> void:
	if e == null:
		return
	if e is SternBoss:
		level.add_child(BossBar.new(e))
	e.set_meta("stern_cell", c)


func _on_killed(e: Enemy) -> void:
	if not e.has_meta("stern_cell"):
		return
	var c: Vector2i = e.get_meta("stern_cell")
	if e is SternBoss:
		level.taken[Level.slain_key(c)] = true
		if warden_cells.has(c) and not level.taken.has(KEYS_TAKEN):
			_drop_key_ring(e.global_position)
	else:
		level.taken[Level.slain_key(c)] = level.world_hours()


## Monsters that fell long enough ago rise again where the map put them,
## when the hero is far and cannot see the spot.
func _respawn() -> void:
	var hero := level.player.global_position
	if is_safe(hero):
		return
	var now := level.world_hours()
	for key in level.taken.keys():
		var when = level.taken[key]
		if not str(key).begins_with("slain:") or not (when is float or when is int) or now - float(when) < RESPAWN_HOURS:
			continue
		var parts := str(key).split(":")
		var c := Vector2i(int(parts[1]), int(parts[2]))
		var at := level.cell_to_world(c)
		if at.distance_to(hero) < RESPAWN_FAR or level.has_line_of_sight(hero, at):
			continue
		level.taken.erase(key)
		level.spawn_map_enemy(c)


## A warden calls for help: `count` of `kind` come from round about.
func call_help(boss: Enemy, kind: String, count: int) -> void:
	_called = _called.filter(func(x): return is_instance_valid(x) and not x.dead)
	var home := level.world_to_cell(boss.global_position)
	var cells: Array[Vector2i] = []
	for y in range(-6, 7):
		for x in range(-6, 7):
			var c := home + Vector2i(x, y)
			var r := Vector2(x, y).length()
			if r >= 2.5 and r <= 6.0 and _open_floor(c):
				cells.append(c)
	cells.shuffle()
	for c in cells:
		if _called.size() >= count * 2 or count <= 0:
			break
		var e := _spawn_extra(kind, c)
		if e:
			_called.append(e)
			count -= 1


func _spawn_extra(kind: String, c: Vector2i) -> Enemy:
	if not Enemy.KINDS.has(kind):
		return null
	var e: Enemy = level._spawn_enemy(kind, c)
	if level.player:
		e.alert(level.player.global_position)
	var puff := Effects.make_sparkles(GHOST_COLOR, true)
	puff.position = level.cell_to_world(c) + Vector3(0, 1.0, 0)
	level.add_child(puff)
	return e


## A floor tile a monster may stand on: not a wall, furniture, the chasm or
## a safe room.
func _open_floor(c: Vector2i) -> bool:
	return level.astar.is_in_boundsv(c) and not level.astar.is_point_solid(c) and not safe_cells.has(c) \
			and level.cell_char(c) in ".,"


## Monsters stop at the threshold of a safe room.
func _keep_out() -> void:
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var c := level.world_to_cell(e.global_position)
		if safe_cells.has(c):
			if e.has_meta("stern_out"):
				e.global_position = e.get_meta("stern_out")
				e.reset_physics_interpolation()
		else:
			e.set_meta("stern_out", e.global_position)


# --- Keys and bars -----------------------------------------------------------

func _drop_key_ring(pos: Vector3) -> void:
	if not key_ring.is_empty():
		return
	key_ring = {"node": SternParts.key_ring(level, pos), "pos": pos}
	Sfx.play(self, "key", -2.0, pos)


func _check_key_ring() -> void:
	if key_ring.is_empty() or level.player == null:
		return
	var to: Vector3 = level.player.global_position - key_ring.pos
	if Vector2(to.x, to.z).length() > KEY_REACH:
		return
	level.taken[KEYS_TAKEN] = true
	var node: Node3D = key_ring.node
	key_ring = {}
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "position:y", 1.6, 0.35)
	tween.parallel().tween_property(node, "scale", Vector3.ONE * 0.01, 0.35)
	tween.tween_callback(node.queue_free)
	Sfx.play(self, "key", 0.0)
	Events.found(Lang.t("Der Schlüsselbund des Wärters! Alle Gittertüren dieser Ebene springen auf."), SternParts.STAR_GOLD)
	for gate in bars:
		_open_bars(gate)


func _open_bars(gate: Dictionary, at_once := false) -> void:
	if gate.open:
		return
	gate.open = true
	if is_instance_valid(gate.body):
		gate.body.queue_free()
	level.astar.set_point_solid(gate.cell, false)
	if at_once:
		gate.node.position.y = Level.GATE_SUNK
	else:
		var tween: Tween = create_tween()
		tween.tween_property(gate.node, "position:y", Level.GATE_SUNK, 1.4).set_ease(Tween.EASE_IN)
		Sfx.play(self, "door", -4.0, level.cell_to_world(gate.cell))
	for st in level.stations:
		if st.get("gate") == gate:
			st.used = true


# --- Stations ----------------------------------------------------------------

## The hero runs into one of the keep's things (see Game._use_station).
func use(s: Dictionary, player: Player) -> void:
	player.face(s.pos - player.global_position)
	match s.kind:
		RELIEF:
			_press(s.relief, player)
		BARS:
			Sfx.play(self, "door", -10.0, s.pos)
			Effects.float_text(level, s.pos + Vector3(0, 2.4, 0), Lang.t("Verschlossen. Den Schlüsselbund trägt der Wärter dieser Ebene."), Color(0.85, 0.85, 0.85))
		ANVIL:
			player.play_once("Interact", 0.6)
			var mended := player.mend_gear(MEND_POINTS)
			Sfx.play(self, "word_klack", -4.0, s.pos)
			if mended > 0:
				Events.found(Lang.t("Am alten Amboss klopfst du deine Ausrüstung wieder zurecht."), SternParts.STAR_GOLD)
			else:
				Effects.float_text(level, s.pos + Vector3(0, 2.0, 0), Lang.t("Deine Ausrüstung ist heil."), Color(0.85, 0.85, 0.85))
		SHELF:
			var today := int(level.world_hours() / 24.0)
			if int(level.taken.get(shelf_key(s.cell), -1)) == today:
				Effects.float_text(level, s.pos + Vector3(0, 2.0, 0), Lang.t("Das Regal ist leer. Morgen steht hier ein neuer Trank."), Color(0.85, 0.85, 0.85))
				return
			level.taken[shelf_key(s.cell)] = today
			player.play_once("Interact", 0.5)
			level._drop_item(POTION, s.pos + (player.global_position - s.pos).normalized() * 1.6, false)
		PRISONER:
			player.play("Idle")
			s.figure.talk(player)
			if not level.taken.has(QUEST_GIVEN) and player.bag_fits(SEAL_RING):
				level.taken[QUEST_GIVEN] = true
				Events.bus().quest_found.emit(QUEST)


# --- Every frame -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var player: Player = level.player as Player
	if player == null or player.dead:
		return
	_check_chasm(player, delta)
	_tick_flagstones(delta, player)
	_tick_eyes(delta, player)
	_check_key_ring()
	_keep_out()
	_crate_check -= delta
	if _crate_check <= 0.0:
		_crate_check = 0.4
		_drop_crates()
	_respawn_in -= delta
	if _respawn_in <= 0.0:
		_respawn_in = RESPAWN_CHECK
		_respawn()
	if level.theme == THEME_VAULTS and not is_safe(player.global_position) and not player.frozen:
		_event_in -= delta
		if _event_in <= 0.0:
			_event_in = randf_range(EVENT_EVERY.x, EVENT_EVERY.y)
			_surprise(player)
	if not prisoner.is_empty() and not _shouted and not level.taken.has(KEYS_TAKEN) \
			and player.global_position.distance_to(prisoner.pos) < 14.0:
		_shouted = true
		Events.say(Lang.t(prisoner.figure.display_name), Lang.t("Hilfe! Hier drüben! Der Kerkermeister trägt die Schlüssel!"), prisoner.pos)


# --- The chasm ---------------------------------------------------------------

func _flagstone_at(c: Vector2i):
	for f in flagstones:
		if f.cell == c:
			return f
	return null


## Whether the floor at c is gone: the chasm, or a flagstone that fell.
func is_pit(c: Vector2i) -> bool:
	if pits.has(c):
		return true
	var f = _flagstone_at(c)
	return f != null and f.state in ["down", "rising"]


## How far a point lies inside the chasm: its distance to the nearest edge
## with firm ground beyond (0 on firm ground).
func _depth_in_pit(pos: Vector3) -> float:
	var c := level.world_to_cell(pos)
	if not is_pit(c):
		return 0.0
	var local := pos - level.cell_to_world(c)
	var best := Level.TILE
	for d in Level.DIRS:
		if is_pit(c + d):
			continue
		best = minf(best, Level.TILE * 0.5 - (local.x * d.x + local.z * d.y))
	return best


func _check_chasm(player: Player, _delta: float) -> void:
	if _falling or player.frozen or not player.is_on_floor() or player.is_climbing():
		return
	var c := level.world_to_cell(player.global_position)
	if pits.is_empty() and flagstones.is_empty():
		return
	if _depth_in_pit(player.global_position) >= FALL_DEEP:
		_fall(player)
	elif not is_pit(c) and _flagstone_at(c) == null and player.global_position.y < 0.3:
		_last_safe = player.global_position


func _fall(player: Player) -> void:
	_falling = true
	Events.teach(CHASM_LORE)
	player.frozen = true
	player.path.clear()
	player.play("Jump_Idle", 0.1)
	Sfx.play(self, "swing", -2.0, player.global_position, 0.6)
	var tween: Tween = player.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(player, "global_position:y", -SternParts.CHASM_DEPTH + 1.0, 0.7).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.25)
	tween.tween_callback(func():
		_falling = false
		if not is_instance_valid(player) or player.level != level:
			return
		var back := _last_safe if _last_safe != Vector3.INF else level.cell_to_world(level.start_cell)
		player.global_position = Vector3(back.x, 0.0, back.z)
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		player.frozen = false
		player.take_damage(maxi(1, roundi(player.max_hp * FALL_SHARE)), player.global_position + Vector3(0, 0, 1), null, false)
		Effects.head_text(level, player, 2.6, Lang.t("Abgestürzt!"), Color(1.0, 0.5, 0.4))
		Events.bus().camera_punched.emit(0.8))


func _tick_flagstones(delta: float, player: Player) -> void:
	var under := level.world_to_cell(player.global_position)
	var standing := player.is_on_floor() and player.global_position.y < 0.3 and not _falling
	for f in flagstones:
		var node: Node3D = f.node
		match f.state:
			"solid":
				if standing and f.cell == under:
					f.state = "shaking"
					f.t = CRUMBLE_AFTER
					Sfx.play(self, "word_klack", -8.0, node.global_position, 0.6)
			"shaking":
				f.t -= delta
				node.position = level.cell_to_world(f.cell) + Vector3(randf_range(-0.05, 0.05), randf_range(-0.04, 0.0), randf_range(-0.05, 0.05))
				if f.t <= 0.0:
					f.state = "down"
					f.t = CRUMBLE_DOWN
					node.position = level.cell_to_world(f.cell)
					var tween: Tween = node.create_tween()
					tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
					tween.tween_property(node, "position:y", -SternParts.CHASM_DEPTH, 0.9).set_ease(Tween.EASE_IN)
					tween.parallel().tween_property(node, "rotation:z", randf_range(-0.6, 0.6), 0.9)
					Sfx.play(self, "rumble", -8.0, node.global_position, 1.5)
			"down":
				f.t -= delta
				if f.t <= 0.0:
					f.state = "rising"
					f.t = CRUMBLE_RISE
					node.rotation = Vector3.ZERO
					node.position = level.cell_to_world(f.cell) + Vector3(0, -2.5, 0)
					var tween: Tween = node.create_tween()
					tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
					tween.tween_property(node, "position:y", 0.0, CRUMBLE_RISE).set_ease(Tween.EASE_OUT)
			"rising":
				f.t -= delta
				if f.t <= 0.0:
					f.state = "solid"
					node.position = level.cell_to_world(f.cell)


## Crates set down over the chasm fall into it.
func _drop_crates() -> void:
	for crate in level.crates.duplicate():
		if not is_instance_valid(crate) or crate.global_position.y > 0.2:
			continue
		if _depth_in_pit(crate.global_position) < 0.4:
			continue
		level.crates.erase(crate)
		var tween: Tween = crate.create_tween()
		tween.tween_property(crate, "position:y", -SternParts.CHASM_DEPTH, 0.8).set_ease(Tween.EASE_IN)
		tween.tween_callback(crate.queue_free)


# --- The listening eyes -------------------------------------------------------

func _tick_eyes(delta: float, player: Player) -> void:
	for eye in eyes:
		if eye.dead:
			continue
		eye.rest = maxf(0.0, eye.rest - delta)
		var to: Vector3 = player.global_position + Vector3(0, 1.4, 0) - eye.pos
		var near := to.length() <= EYE_RANGE and level.has_line_of_sight(eye.pos, player.global_position)
		var ball: Node3D = eye.ball
		if near:
			ball.rotation.y = lerp_angle(ball.rotation.y, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))
		if eye.charge > 0.0:
			eye.charge -= delta
			var light: OmniLight3D = eye.light
			light.light_energy = lerpf(4.0, 0.8, eye.charge / EYE_WARN)
			if eye.charge <= 0.0:
				if near and player.is_noisy():
					_strike(eye, player)
				else:
					_calm_eye(eye)
		elif eye.rest <= 0.0 and near and player.is_noisy() and not player.frozen:
			eye.charge = EYE_WARN
			eye.iris.material_override = SternParts.material(Color(1.0, 0.85, 0.3), 3.0)
			Effects.float_text(level, eye.pos + Vector3(0, 0.8, 0), "!", Color(1.0, 0.85, 0.3))
			Sfx.play(self, "magic", -10.0, eye.pos, 1.6)
			Events.teach(EYE_LORE)


func _calm_eye(eye: Dictionary) -> void:
	eye.iris.material_override = SternParts.material(SternParts.VIOLET, 1.2)
	eye.light.light_energy = 0.6


func _strike(eye: Dictionary, player: Player) -> void:
	_calm_eye(eye)
	eye.rest = EYE_REST
	var from: Vector3 = eye.pos
	var to := player.global_position + Vector3(0, 1.2, 0)
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, from.distance_to(to))
	beam.mesh = box
	beam.material_override = SternParts.material(Color(1.0, 0.85, 0.3), 4.0, 0.9, true)
	level.add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	get_tree().create_timer(0.25).timeout.connect(beam.queue_free)
	Sfx.play(self, "magic", -2.0, from, 0.8)
	Events.bus().camera_punched.emit(0.4)
	player.take_damage(maxi(1, roundi(player.max_hp * EYE_SHARE)), from, null, false)
	for e in level.enemies:
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(from) < EYE_WAKES:
			e.alert(player.global_position)


func _shatter_eye(eye: Dictionary, at_once := false) -> void:
	if eye.dead:
		return
	eye.dead = true
	eye.ball.visible = false
	eye.light.light_energy = 0.0
	if not at_once:
		var shards := Effects.make_sparkles(SternParts.VIOLET, true)
		shards.position = eye.pos
		shards.amount = 40
		level.add_child(shards)
		Comic.pop(eye.pos, "break")


# --- The tome ----------------------------------------------------------------

func _on_item_collected(id: String) -> void:
	if id == TOME and not level.taken.has(THEFT):
		_theft()


## The tome is taken: the keep wakes. The gate behind the hero rises out of
## the floor, the eyes burst, the dead come for the thief, and the hero has
## to find another way out.
func _theft() -> void:
	level.taken[THEFT] = true
	Events.teach(SPELL_LORE)
	Events.teach(DRAIN_LORE if level.taken.has(DRAIN_FOUND) else LORE)
	Events.bus().camera_punched.emit(1.6)
	Sfx.play(self, "rumble", 0.0)
	Events.tell(Lang.t("Die Worte des Folianten brennen sich in deinen Geist: Du beherrschst die Entfesselte Kraft (Taste 2)!"), SternParts.VIOLET, 6.0)
	if not lectern.is_empty():
		lectern.glow.light_energy = 0.3
	if not portcullis.is_empty() and not portcullis.down:
		portcullis.down = true
		portcullis.body.collision_layer = 1
		level.astar.set_point_solid(portcullis.cell, true)
		var tween: Tween = create_tween()
		tween.tween_property(portcullis.node, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK)
	for eye in eyes:
		_shatter_eye(eye)
	var here := level
	get_tree().create_timer(2.0).timeout.connect(func():
		if not is_instance_valid(here) or here != level or level.player == null:
			return
		Events.tell(Lang.t("Hinter dir schießt ein Gitter aus dem Boden! Die Feste erwacht. Such einen anderen Weg hinaus!"), Color(1.0, 0.55, 0.4), 5.0)
		_apparition(level.player, Lang.t("Dieb! Die Sterne lassen dich nicht gehen!"))
		var cells: Array[Vector2i] = []
		for y in level.height:
			for x in level.width:
				var c := Vector2i(x, y)
				var d := level.cell_to_world(c).distance_to(level.player.global_position)
				if d > 9.0 and d < 22.0 and _open_floor(c) and level.has_line_of_sight(level.player.global_position, level.cell_to_world(c)):
					cells.append(c)
		cells.shuffle()
		var kinds := ["totengeist", "totengeist", "totengeist", "ghul"]
		for i in mini(kinds.size(), cells.size()):
			_spawn_extra(kinds[i], cells[i]))


# --- Surprises ---------------------------------------------------------------

func _surprise(player: Player) -> void:
	var roll := randf()
	if roll < 0.4:
		_rockfall(player)
	elif roll < 0.75:
		_ambush(player)
	elif not flagstones.is_empty() and roll < 0.85:
		_tremor()
	else:
		_apparition(player, Lang.t(WHISPERS[randi() % WHISPERS.size()]))


## Stones come down round the hero: rings on the floor show where, a moment
## before they hit. One always aims at where the hero stands.
func _rockfall(player: Player) -> void:
	Events.tell(Lang.t("Über dir knirscht der Fels!"), Color(1.0, 0.75, 0.5), 2.5)
	Events.bus().camera_punched.emit(0.4)
	Sfx.play(self, "rumble", -4.0, player.global_position)
	var spots: Array[Vector3] = [player.global_position]
	for i in 8:
		if spots.size() >= 4:
			break
		var at := player.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		var c := level.world_to_cell(at)
		if _open_floor(c) and spots.all(func(s): return s.distance_to(at) > 2.2):
			spots.append(at)
	for at in spots:
		var ring := SternParts.warning_ring(level, at, ROCK_RADIUS, Color(1.0, 0.4, 0.2))
		var rock := level._place("rubble_half", Vector3(at.x, 9.0, at.z), randf() * TAU)
		var tween: Tween = rock.create_tween()
		tween.tween_interval(ROCK_WARN - 0.35)
		tween.tween_property(rock, "position:y", 0.0, 0.35).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			ring.queue_free()
			Comic.pop(at, "rumble")
			var dust := Effects.make_sparkles(Color(0.7, 0.62, 0.5), true)
			dust.position = at + Vector3(0, 0.5, 0)
			level.add_child(dust)
			var hero: Player = level.player as Player
			if hero and not hero.dead and Vector2(hero.global_position.x - at.x, hero.global_position.z - at.z).length() < ROCK_RADIUS \
					and hero.global_position.y < 1.5:
				hero.take_damage(maxi(1, roundi(hero.max_hp * ROCKFALL_SHARE)), at, null, false))
		tween.tween_interval(6.0)
		tween.tween_property(rock, "scale", Vector3.ONE * 0.01, 0.6)
		tween.tween_callback(rock.queue_free)


## The dead come out of the walls: two of them, out of the hero's way.
func _ambush(player: Player) -> void:
	var kind := "totengeist" if level.monster_families.has("ghosts") else "wicht"
	var cells: Array[Vector2i] = []
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			var d := level.cell_to_world(c).distance_to(player.global_position)
			if d > 10.0 and d < 16.0 and _open_floor(c):
				cells.append(c)
	if cells.is_empty():
		return
	cells.shuffle()
	Events.tell(Lang.t("Kalte Hände greifen aus den Wänden!"), GHOST_COLOR, 2.5)
	for i in mini(2, cells.size()):
		_spawn_extra(kind, cells[i])


## The floor of the chasm shakes: every flagstone starts to crumble at once.
func _tremor() -> void:
	Events.tell(Lang.t("Die Feste bebt!"), Color(1.0, 0.75, 0.5), 2.5)
	Events.bus().camera_punched.emit(0.9)
	Sfx.play(self, "rumble", -2.0)
	for f in flagstones:
		if f.state == "solid":
			f.state = "shaking"
			f.t = CRUMBLE_AFTER + randf_range(0.0, 1.5)


## The ghost of the archmagus stands a few steps from the hero, says his
## piece and fades.
func _apparition(player: Player, line: String) -> void:
	var dir := player.facing() if player.facing().length() > 0.1 else Vector3.BACK
	var at := player.global_position + dir.normalized() * 5.0
	if not _open_floor(level.world_to_cell(at)):
		at = player.global_position + Vector3(2.5, 0, 2.5)
	var ghost := DungeonNpc.new()
	ghost.setup({"name": ARCHMAGUS, "model": "Mage", "sex": "male", "pose": "Spellcast_Raise",
			"colors": ["#4b3c6e", "#2e2a3a", "#c9b26a"], "show": ["Mage_Hat", "Mage_Cape", "2H_Staff"], "lines": [line]})
	level.add_child(ghost)
	ghost.global_position = Vector3(at.x, 0.3, at.z)
	ghost.look_at(Vector3(player.global_position.x, 0.3, player.global_position.z), Vector3.UP, true)
	SternParts.ghostly(ghost, GHOST_COLOR)
	ghost.collision_layer = 0
	ghost.talk(player)
	Sfx.play(self, "magic", -6.0, at, 0.5)
	var tween: Tween = ghost.create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(ghost, "scale", Vector3(0.01, 1.4, 0.01), 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(ghost.queue_free)
