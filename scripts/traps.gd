class_name Traps
extends Node3D
## Hidden traps in the dungeon, the dark holes, the dragon's lair and the
## mines. A trap lies unseen in the floor until the hero spots it or steps on
## it; then it shows, and stays known on that level (in Level.taken).
##
## Three kinds (KINDS):
##   stacheln (spike trap): spikes shoot up and hurt; a deft hero may jump
##     aside in time (see Player.spring_trap).
##   teleport (teleporter trap): a rune circle flings the hero to another
##     part of the same level.
##   falltuer (trapdoor): the floor gives way and the hero falls to the level
##     below (only where there is one, see PLACES and can_drop).
##
## Spotting: the first time the hero comes within SPOT_RANGE of a hidden trap
## and can see it, Intuition and the Erkunden skill get one roll (see
## spot_chance). The deeper the place (HeroLevel.place_level), the harder
## the roll and the more a trap hurts. A spotted trap trains Erkunden and
## earns a little experience (Events.trap_spotted).
##
## A known trap is marked by an amber frame on its tile, with the kind's own
## sign inside (holes, a rune ring or a hatch), and the hero's path finding
## goes around it. Jumping over a trap (Space) is always safe.
##
## Where traps lie is chosen by a random generator seeded with the level's
## name, so a level has its traps in the same places on every visit. The
## first two levels (the start and the spike hall) and safe places have none.

## The level files that have traps: how many, and which kinds may be there.
const ALL_KINDS := ["stacheln", "teleport", "falltuer"]
const NO_DROP := ["stacheln", "teleport"]
const PLACES := {
	"03_das_labyrinth.txt": {"count": 2, "kinds": ["stacheln", "falltuer"]},
	"04_die_gruft.txt": {"count": 2, "kinds": ALL_KINDS},
	"06_die_katakomben.txt": {"count": 3, "kinds": ALL_KINDS},
	"07_die_bibliothek.txt": {"count": 3, "kinds": ALL_KINDS},
	"08_die_knochengrube.txt": {"count": 3, "kinds": ALL_KINDS},
	"09_die_klingenhalle.txt": {"count": 3, "kinds": ALL_KINDS},
	"10_das_tor.txt": {"count": 3, "kinds": NO_DROP},
	"13_die_drachenhoehle.txt": {"count": 3, "kinds": NO_DROP},
	"15_das_offene_grab.txt": {"count": 2, "kinds": NO_DROP},
	"16_das_spinnenloch.txt": {"count": 2, "kinds": NO_DROP},
	"17_die_bleiche_tiefe.txt": {"count": 2, "kinds": NO_DROP},
	"19_die_kupfergrube.txt": {"count": 4, "kinds": NO_DROP},
	"20_die_kristallgrotte.txt": {"count": 4, "kinds": NO_DROP},
	"21_die_zwergenbinge.txt": {"count": 4, "kinds": ALL_KINDS},
	"22_die_glutstollen.txt": {"count": 4, "kinds": NO_DROP},
}
## Each kind: its German name (for messages, see Lang), the colour of the
## sign inside the amber frame and what the hero hears on spotting one.
const KINDS := {
	"stacheln": {"name": "Stachelfalle", "color": Color(0.62, 0.6, 0.58),
		"spotted": "Du entdeckst eine Stachelfalle! Geh außen herum oder spring darüber."},
	"teleport": {"name": "Teleportfalle", "color": Color(0.72, 0.5, 1.0),
		"spotted": "Du entdeckst eine Teleportfalle! Geh außen herum oder spring darüber."},
	"falltuer": {"name": "Falltür", "color": Color(0.5, 0.34, 0.2),
		"spotted": "Du entdeckst eine Falltür! Geh außen herum oder spring darüber."},
}
## What the compendium says about traps.
const LEARN := "Verborgene Fallen: In Verliesen, Höhlen und Minen liegen Stachelfallen, Teleportfallen und Falltüren unsichtbar im Boden. Kommst du in ihre Nähe, helfen dir Intuition und Erkunden, sie zu entdecken. Je tiefer der Ort, desto besser sind sie versteckt und desto mehr schmerzen sie. Eine entdeckte Falle ist orange umrandet: Geh außen herum oder spring darüber (Leertaste). Eine Falltür lässt dich eine Ebene tiefer stürzen."
## The frame every known trap gets: one warning colour for every kind.
const FRAME_COLOR := Color(1.0, 0.62, 0.25)

## Spotting: SPOT_BASE % at a place of level 0, SPOT_PER_LEVEL % less for
## each level of the place, plus Intuition (Player.intuition_bonus) and
## Erkunden (Training.EXPLORE_TRAP per level); never below SPOT_MIN or
## above SPOT_MAX.
const SPOT_BASE := 55
const SPOT_PER_LEVEL := 3
const SPOT_MIN := 5
const SPOT_MAX := 95
## How close (metres) the hero must come to a trap to have a chance to spot it.
const SPOT_RANGE := 9.0

## Spikes hurt 1 + place level / SPIKE_LEVELS; a fall through a trapdoor
## 1 + place level / FALL_LEVELS (Game._fall_through_trapdoor).
const SPIKE_LEVELS := 4
const FALL_LEVELS := 5
## How far from the middle of its tile a trap catches the hero (metres).
const REACH := 1.5
## Seconds before a spike trap or a teleporter can catch the hero again.
const REARM := 1.6
## A teleporter sends the hero at least this many tiles away.
const TELEPORT_MIN_TILES := 6
## Traps keep this many tiles away from the start, the exit and each other.
const KEEP_AWAY := 3
## A trap's four neighbouring tiles, and at least AROUND_DIAGONALS of the
## corner tiles (so the ring around it is unbroken but for one corner), must
## be one of these: open floor, a coin, the key or a
## monster's spot. So there is always a way around a trap.
const AROUND_OK := ".,cKMAZwGWvsJOeig"
const AROUND_DIAGONALS := 3
## How much longer a path over a known trap counts (see Level.SPIKE_DETOUR).
const DETOUR := 6.0
## Height of the frame and signs above the floor (DungeonLife.FLOOR_Y).
const MARK_Y := 0.08
const SPIKES_DOWN := -1.1

## The hero stepped on a teleporter and was moved to `to`.
signal teleported(to: Vector3)
## The hero fell through a trapdoor: the game takes them to the level below.
signal fell(damage: int)

var level: Level
## Each trap: {"cell", "kind", "known", "rolled", "node", "mark", "spikes",
## "hatch", "rest"}.
var traps: Array = []
## The level of the place, for spotting and damage (HeroLevel.place_level).
var place_level := 1
var _time := 0.0
## Set once the hero fell through a trapdoor: nothing more happens here.
var _gone := false

static var _materials := {}


## The traps for a level, or null when it has none. Called by Level.build
## once the grid and the path finding are set up.
static func make(owner_level: Level) -> Traps:
	var place: Dictionary = PLACES.get(owner_level.file, owner_level.trap_place)
	if place.is_empty() or owner_level.outdoor or owner_level.is_home:
		return null
	var t := Traps.new()
	t.level = owner_level
	t.name = "Traps"
	t.place_level = HeroLevel.place_level(owner_level)
	t._place(place.count, place.kinds)
	return t


## Reads the header "traps: 3 stacheln, falltuer" of a map: {"count",
## "kinds"}, or {} for none. Unknown kinds are left out.
static func parse_header(text: String) -> Dictionary:
	var parts := text.strip_edges().split(" ", false, 1)
	if parts.is_empty() or not parts[0].is_valid_int():
		return {}
	var kinds: Array = []
	if parts.size() > 1:
		for k in parts[1].split(","):
			if k.strip_edges() in ALL_KINDS and not k.strip_edges() in kinds:
				kinds.append(k.strip_edges())
	if kinds.is_empty():
		kinds = NO_DROP.duplicate()
	var count := clampi(int(parts[0]), 0, MAX_HEADER_TRAPS)
	return {} if count == 0 else {"count": count, "kinds": kinds}


## The most traps a map may ask for in its header.
const MAX_HEADER_TRAPS := 8


## Whether a trapdoor on this level has a level below to fall to: the
## previous floor of the dungeon (the hero climbs it upwards, so that one lies
## below), or the floor under a mine once its way down is open.
static func can_drop(owner_level: Level) -> bool:
	if owner_level.playtest:
		return false
	if owner_level.building == "":
		return owner_level.depth > 0
	return owner_level.down_to != "" and (owner_level.seal == "" or owner_level.taken.has("mines:seal_open"))


func _place(count: int, kinds: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.level_name + ":traps")
	var spots: Array[Vector2i] = []
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if _fits(c):
				spots.append(c)
	var drop := "falltuer" in kinds and can_drop(level)
	var plain: Array = kinds.filter(func(k): return k != "falltuer")
	while traps.size() < count and not spots.is_empty():
		var c: Vector2i = spots.pop_at(rng.randi() % spots.size())
		if traps.any(func(t): return _apart(t.cell, c) < KEEP_AWAY):
			continue
		# One trapdoor at most, and it comes first so every such level has one.
		var kind: String = "falltuer" if drop and traps.is_empty() else plain[rng.randi() % plain.size()]
		var known: bool = level.taken.has(key(c))
		traps.append({"cell": c, "kind": kind, "known": known, "rolled": known, "rest": 0.0})


## Open floor, well away from the start and the exit, with open floor all
## around.
func _fits(c: Vector2i) -> bool:
	if not ".,".contains(level.cell_char(c)) or level.grates.has(c):
		return false
	if _apart(c, level.start_cell) < KEEP_AWAY + 1:
		return false
	if level.exit_cell.x >= 0 and _apart(c, level.exit_cell) < KEEP_AWAY:
		return false
	var open := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if AROUND_OK.contains(level.cell_char(c + Vector2i(dx, dy))):
				open += 1
			elif dx == 0 or dy == 0:
				return false
	# The four sides and at least AROUND_DIAGONALS corners: a way around.
	return open >= 5 + AROUND_DIAGONALS


static func _apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## The key under which a known trap is kept in Level.taken.
static func key(c: Vector2i) -> String:
	return "trap:%d,%d" % [c.x, c.y]


func _ready() -> void:
	for t in traps:
		_build(t)
		if t.known:
			_show(t, false)


## The chance in percent to spot a hidden trap here.
func spot_chance() -> int:
	var hero: Player = level.player
	var bonus := 0
	if hero:
		bonus = hero.intuition_bonus() + hero.explore_bonus(Training.EXPLORE_TRAP)
	return clampi(SPOT_BASE - SPOT_PER_LEVEL * place_level + bonus, SPOT_MIN, SPOT_MAX)


## What spikes deal here.
func spike_damage() -> int:
	return 1 + place_level / SPIKE_LEVELS


## What a fall through a trapdoor here deals.
func fall_damage() -> int:
	return 1 + place_level / FALL_LEVELS


func _process(delta: float) -> void:
	_time += delta
	for t in traps:
		t.rest = maxf(0.0, t.rest - delta)
		if t.spikes and t.spikes.position.y > SPIKES_DOWN and t.rest < REARM - 0.7:
			t.spikes.position.y = move_toward(t.spikes.position.y, SPIKES_DOWN, delta * 3.0)
		if t.known and t.kind == "teleport":
			t.sign.rotation.y += delta * 0.6
	var hero: Player = level.player
	if _gone or hero == null or level.finished or hero.dead or hero.frozen:
		return
	for t in traps:
		var spot := level.cell_to_world(t.cell)
		var flat := Vector2(hero.global_position.x - spot.x, hero.global_position.z - spot.z)
		if not t.rolled and flat.length() <= SPOT_RANGE and level.has_line_of_sight(hero.global_position, spot):
			t.rolled = true
			if randi_range(1, 100) <= spot_chance():
				spot_trap(t)
		if t.rest <= 0.0 and absf(flat.x) < REACH and absf(flat.y) < REACH and hero.global_position.y < 0.6:
			spring(t)
			if _gone:
				return


## The hero noticed a hidden trap: it shows, and the game hears of it.
func spot_trap(t: Dictionary) -> void:
	if t.known:
		return
	t.rolled = true
	_show(t, true)
	var spot := level.cell_to_world(t.cell)
	Effects.float_text(level, spot + Vector3(0, 1.6, 0), Lang.t("Eine Falle!"), FRAME_COLOR)
	Sfx.play(level, "word_klick", -4.0, spot)
	Events.bus().trap_spotted.emit(t.kind, place_level)


## The hero stepped on a trap.
func spring(t: Dictionary) -> void:
	var hero: Player = level.player
	var spot := level.cell_to_world(t.cell)
	t.rest = REARM
	var was_known: bool = t.known
	_show(t, false)
	Events.teach(LEARN)
	match t.kind:
		"stacheln":
			t.spikes.position.y = 0.0
			Sfx.play(level, "word_stich", -2.0, spot)
			hero.spring_trap(spike_damage())
		"teleport":
			var to := _teleport_target(t.cell)
			if to.x < 0:
				return
			var arrive := level.cell_to_world(to)
			_flash(spot)
			_flash(arrive)
			Sfx.play(level, "magic", -2.0)
			hero.path.clear()
			hero.global_position = arrive
			hero.velocity = Vector3.ZERO
			# The hero arrives standing still; no trap at the far end.
			for other in traps:
				if other.cell == to:
					other.rest = REARM
			teleported.emit(arrive)
		"falltuer":
			_gone = true
			Sfx.play(level, "word_krach", -2.0, spot)
			var tween := create_tween()
			tween.tween_property(t.hatch, "rotation:x", deg_to_rad(-100), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fell.emit(fall_damage())
	if not was_known:
		Effects.float_text(level, spot + Vector3(0, 2.2, 0), Lang.t(KINDS[t.kind].name) + "!", FRAME_COLOR)


## Where the hero lands after falling through a trapdoor into `below`: a
## floor tile the start can be reached from (so the key and the doors still
## matter), a little away from it, with no monster close by and no trap.
static func landing_cell(below: Level) -> Vector2i:
	var start := below.start_cell
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	var spots: Array[Vector2i] = []
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in Level.DIRS:
			var n: Vector2i = c + d
			if seen.has(n) or not below.astar.is_in_boundsv(n) or below.astar.is_point_solid(n):
				continue
			seen[n] = true
			todo.append(n)
			if not ".,".contains(below.cell_char(n)) or _apart(n, start) < 3:
				continue
			if below.traps and not below.traps.trap_at(n).is_empty():
				continue
			var spot := below.cell_to_world(n)
			if below.enemies.any(func(e): return is_instance_valid(e) and not e.dead and Vector2(e.global_position.x - spot.x, e.global_position.z - spot.z).length() < Level.TILE * 2.5):
				continue
			spots.append(n)
	if spots.is_empty():
		return start
	spots.sort()
	return spots[randi() % spots.size()]


## A floor tile far from the trap that the hero can walk to from it (no
## locked door, gate or secret wall between), with no trap on it.
func _teleport_target(from: Vector2i) -> Vector2i:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	var far: Array[Vector2i] = []
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in Level.DIRS:
			var n: Vector2i = c + d
			if seen.has(n) or not level.astar.is_in_boundsv(n) or level.astar.is_point_solid(n):
				continue
			seen[n] = true
			todo.append(n)
			if ".,".contains(level.cell_char(n)) and _apart(n, from) >= TELEPORT_MIN_TILES and not traps.any(func(t): return t.cell == n):
				far.append(n)
	if far.is_empty():
		return Vector2i(-1, -1)
	far.sort()
	return far[randi() % far.size()]


## A trap becomes known: it shows, is kept as known, and paths go around it.
func _show(t: Dictionary, fade: bool) -> void:
	if not t.known:
		t.known = true
		t.rolled = true
		level.taken[key(t.cell)] = true
	level.astar.set_point_weight_scale(t.cell, DETOUR)
	if t.mark.visible:
		return
	t.mark.visible = true
	if fade:
		t.mark.scale = Vector3(1.3, 1.0, 1.3)
		create_tween().tween_property(t.mark, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)


func _flash(at: Vector3) -> void:
	var p := Effects.make_sparkles(KINDS.teleport.color, true)
	p.position = at + Vector3(0, 0.8, 0)
	level.add_child(p)


# --- Looks ------------------------------------------------------------------

func _build(t: Dictionary) -> void:
	var node := Node3D.new()
	node.position = level.cell_to_world(t.cell)
	add_child(node)
	t.node = node
	# The mark: an amber frame on the tile and the kind's sign inside. Hidden
	# until the trap is known.
	var mark := Node3D.new()
	mark.visible = false
	node.add_child(mark)
	t.mark = mark
	var frame := _material(FRAME_COLOR, 0.9)
	for side in 4:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.2, 0.03, 0.14)
		bar.mesh = box
		bar.material_override = frame
		bar.rotation.y = side * PI * 0.5
		bar.position = Vector3(sin(side * PI * 0.5), 0, cos(side * PI * 0.5)) * 1.6 + Vector3(0, MARK_Y, 0)
		mark.add_child(bar)
	t.spikes = null
	t.hatch = null
	t.sign = null
	match t.kind:
		"stacheln":
			_build_spikes(t, mark)
		"teleport":
			_build_rune_ring(t, mark)
		"falltuer":
			_build_hatch(t, mark)


## Nine holes in the floor, and the spikes below them that shoot up.
func _build_spikes(t: Dictionary, mark: Node3D) -> void:
	var hole := _material(Color(0.05, 0.04, 0.04), 0.0)
	var iron := _material(KINDS.stacheln.color, 0.0)
	var spikes := Node3D.new()
	spikes.position.y = SPIKES_DOWN
	t.node.add_child(spikes)
	t.spikes = spikes
	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.13
	spike_mesh.height = 1.0
	spike_mesh.radial_segments = 6
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = 0.16
	hole_mesh.bottom_radius = 0.16
	hole_mesh.height = 0.02
	hole_mesh.radial_segments = 10
	for gx in [-1, 0, 1]:
		for gz in [-1, 0, 1]:
			var at := Vector3(gx * 0.9, 0, gz * 0.9)
			var h := MeshInstance3D.new()
			h.mesh = hole_mesh
			h.material_override = hole
			h.position = at + Vector3(0, MARK_Y, 0)
			mark.add_child(h)
			var s := MeshInstance3D.new()
			s.mesh = spike_mesh
			s.material_override = iron
			s.position = at + Vector3(0, 0.5, 0)
			spikes.add_child(s)


## A faint ring of runes that turns slowly.
func _build_rune_ring(t: Dictionary, mark: Node3D) -> void:
	var glow := _material(KINDS.teleport.color, 1.4)
	var ring := Node3D.new()
	ring.position.y = MARK_Y
	mark.add_child(ring)
	t.sign = ring
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.12
	torus.rings = 32
	var circle := MeshInstance3D.new()
	circle.mesh = torus
	circle.scale = Vector3(1, 0.15, 1)
	circle.material_override = glow
	ring.add_child(circle)
	var rune_mesh := BoxMesh.new()
	rune_mesh.size = Vector3(0.12, 0.02, 0.32)
	for i in 6:
		var a := i * TAU / 6.0
		var rune := MeshInstance3D.new()
		rune.mesh = rune_mesh
		rune.material_override = glow
		rune.position = Vector3(sin(a), 0, cos(a)) * 0.65
		rune.rotation.y = a + (0.5 if i % 2 == 0 else -0.5)
		ring.add_child(rune)


## A wooden hatch with a dark hole beneath; it swings down when it gives way.
func _build_hatch(t: Dictionary, mark: Node3D) -> void:
	var wood := _material(KINDS.falltuer.color, 0.0)
	var dark := _material(Color(0.02, 0.015, 0.015), 0.0)
	var pit := MeshInstance3D.new()
	var pit_mesh := BoxMesh.new()
	pit_mesh.size = Vector3(2.6, 0.01, 2.6)
	pit.mesh = pit_mesh
	pit.material_override = dark
	pit.position.y = MARK_Y - 0.01
	t.node.add_child(pit)
	pit.visible = false
	# The hinge along the far edge; the planks hang from it.
	var hinge := Node3D.new()
	hinge.position = Vector3(0, MARK_Y, -1.3)
	mark.add_child(hinge)
	t.hatch = hinge
	t.pit = pit
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(0.8, 0.05, 2.6)
	for i in 3:
		var plank := MeshInstance3D.new()
		plank.mesh = plank_mesh
		plank.material_override = wood
		plank.position = Vector3((i - 1) * 0.86, 0, 1.3)
		hinge.add_child(plank)
	mark.visibility_changed.connect(func(): pit.visible = mark.visible)


static func _material(color: Color, glow: float) -> StandardMaterial3D:
	var k := "%s:%s" % [color, glow]
	if not _materials.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = glow
		_materials[k] = m
	return _materials[k]


# --- For the tests ----------------------------------------------------------

## The trap on a tile, or an empty dictionary.
func trap_at(c: Vector2i) -> Dictionary:
	for t in traps:
		if t.cell == c:
			return t
	return {}
