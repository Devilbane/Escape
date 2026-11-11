class_name RuinedShrine
extends RefCounted
## The ruined shrine of Mirenna, Lady of Mercy, at the end of the Processional
## Way in the Forsaken Wasteland (see Wasteland): the pilgrimage destination
## of a hero who needs more healing than a potion gives.
##
## Letter `"` of a Level (Tiles.DUNGEON) builds it. Running into it opens its
## window (Menus._build_ruined_shrine): the hero can pray, which heals fully,
## lifts every ailment and reports the prayer on the event bus (see
## Events.mercy_prayed, where the cure for grave injuries connects), and can
## mend the shrine in three small steps by giving a few coins: light the lamp,
## raise the goddess's fallen head, free the spring. Each step is remembered
## in the level's `taken` and shows on the shrine at once.

## The station kind (see Game._use_station and Menus).
const KIND := "ruinenschrein"

## The three steps, in the order they are done. "cost" is in copper.
const STEPS := [
	{"id": "lamp", "name": "Die Lampe entzünden", "cost": 20, "icon": "kind:torch",
		"text": "Die Lampe der Herrin ist längst erloschen. Mit ein paar Münzen Öl brennt sie wieder und weist Pilgern den Weg."},
	{"id": "head", "name": "Das Haupt der Herrin aufrichten", "cost": 40, "icon": "kind:stone",
		"text": "Das steinerne Haupt der Herrin liegt im Sand. Mit einer Gabe für Steinmetz und Mörtel sieht sie wieder über ihr Haus."},
	{"id": "spring", "name": "Die Quelle freilegen", "cost": 80, "icon": "kind:potion",
		"text": "Unter dem Sand liegt die heilige Quelle der Herrin. Mit einer Gabe wird sie freigelegt und fließt wieder."},
]
## Remembered in Level.taken, one key a step.
const KEY_PREFIX := "mirenna:"

const LORE := "Weit hinter den Bergen, am Ende der Prozessionsstraße der Verlassenen Wüste, steht der verfallene Schrein der Gnädigen Herrin Mirenna. Wer dort betet, wird geheilt, und was kein Trank heilt, heilt ihre Hand. Mit kleinen Gaben lässt sich der Schrein Stück für Stück wieder herrichten: Lampe, Haupt und Quelle."

const STONE := Color(0.8, 0.7, 0.52)
const STONE_DARK := Color(0.62, 0.54, 0.4)
const LAMP_GOLD := Color(1.0, 0.78, 0.42)
const WATER := Color(0.4, 0.78, 0.95)

var level: Level
var pos := Vector3.ZERO
var _lamp_flame: MeshInstance3D
var _lamp_light: OmniLight3D
var _head: Node3D
var _water: Node3D
var _spring_light: OmniLight3D
var _motes: CPUParticles3D


static func key_of(id: String) -> String:
	return KEY_PREFIX + id


static func is_restored(lvl: Level, id: String) -> bool:
	return lvl != null and lvl.taken.has(key_of(id))


## How many of the three steps are done.
static func restored_count(lvl: Level) -> int:
	var n := 0
	for step in STEPS:
		if is_restored(lvl, step.id):
			n += 1
	return n


## The step to do next (a step needs the ones before it), or {} when the
## shrine is whole.
static func next_step(lvl: Level) -> Dictionary:
	for step in STEPS:
		if not is_restored(lvl, step.id):
			return step
	return {}


## Whether `lvl` is the floor with the shrine.
static func is_here(lvl: Level) -> bool:
	return lvl != null and lvl.stations.any(func(s): return s.kind == KIND)


## Builds the shrine on the tile `c` of `lvl`, its face to the north (the
## way the hero comes from), and puts its station on the level.
static func build(lvl: Level, c: Vector2i) -> void:
	var shrine := RuinedShrine.new()
	shrine.level = lvl
	shrine.pos = lvl.cell_to_world(c)
	shrine._make()
	lvl.stations.append({"kind": KIND, "cell": c, "pos": shrine.pos, "used": false, "shrine": shrine})
	lvl._add_solid(shrine.pos, Vector3(Level.TILE * 0.9, 2.0, Level.TILE * 0.9))
	shrine.refresh()


func _make() -> void:
	var holder := Node3D.new()
	holder.position = pos
	level.add_child(holder)
	var stone := SternParts.material(STONE)
	var dark := SternParts.material(STONE_DARK)
	# Three worn steps up to the altar, drifted over with sand.
	SternParts._box(holder, Vector3(6.4, 0.3, 3.6), dark, Vector3(0, 0.15, -0.9))
	SternParts._box(holder, Vector3(5.2, 0.3, 2.8), stone, Vector3(0, 0.45, -0.5))
	# The altar and the robed goddess behind it, her head missing.
	SternParts._box(holder, Vector3(2.6, 1.0, 1.1), stone, Vector3(0, 1.1, -0.3))
	SternParts._box(holder, Vector3(2.9, 0.18, 1.3), dark, Vector3(0, 1.69, -0.3))
	SternParts._box(holder, Vector3(1.3, 1.2, 1.3), stone, Vector3(0, 1.05, 1.0))
	var robe := CylinderMesh.new()
	robe.top_radius = 0.3
	robe.bottom_radius = 0.62
	robe.height = 2.4
	SternParts._mesh(holder, robe, stone, Vector3(0, 3.05, 1.0))
	var shoulders := SphereMesh.new()
	shoulders.radius = 0.38
	shoulders.height = 0.55
	SternParts._mesh(holder, shoulders, stone, Vector3(0, 4.2, 1.0))
	# Her open hands, held out to the pilgrim.
	for side in [-1.0, 1.0]:
		SternParts._box(holder, Vector3(0.22, 0.22, 0.9), stone, Vector3(side * 0.55, 3.55, 0.45), Vector3(0.5, 0, 0))
	# The head: it lies in the sand beside the altar until it is raised.
	_head = Node3D.new()
	holder.add_child(_head)
	var skull := SphereMesh.new()
	skull.radius = 0.34
	skull.height = 0.68
	SternParts._mesh(_head, skull, stone)
	SternParts._box(_head, Vector3(0.5, 0.1, 0.18), dark, Vector3(0, 0.3, 0.1), Vector3(0, 0, 0.1))
	# The lamp on a short post by the altar: dark until it is lit.
	SternParts._box(holder, Vector3(0.3, 1.5, 0.3), dark, Vector3(-2.2, 0.9, -0.3))
	SternParts._box(holder, Vector3(0.6, 0.5, 0.6), stone, Vector3(-2.2, 1.9, -0.3))
	var flame := SphereMesh.new()
	flame.radius = 0.2
	flame.height = 0.5
	_lamp_flame = SternParts._mesh(holder, flame, SternParts.material(LAMP_GOLD, 3.0), Vector3(-2.2, 1.95, -0.3))
	_lamp_light = SternParts._light(holder, LAMP_GOLD, 0.0, 9.0, Vector3(-2.2, 2.4, -0.6))
	# The spring: a dry basin by the steps, silted up with sand until freed.
	var basin := CylinderMesh.new()
	basin.top_radius = 1.0
	basin.bottom_radius = 1.1
	basin.height = 0.5
	SternParts._mesh(holder, basin, dark, Vector3(2.4, 0.25, -0.5))
	var pool := CylinderMesh.new()
	pool.top_radius = 0.82
	pool.bottom_radius = 0.82
	pool.height = 0.04
	_water = Node3D.new()
	_water.position = Vector3(2.4, 0.5, -0.5)
	holder.add_child(_water)
	SternParts._mesh(_water, pool, SternParts.material(WATER, 0.7, 0.85))
	_motes = Effects.make_sparkles(WATER)
	_motes.position = Vector3(0, 0.6, 0)
	_water.add_child(_motes)
	_spring_light = SternParts._light(holder, WATER, 0.0, 7.0, Vector3(2.4, 1.2, -0.7))
	# A fallen pillar and a standing stump of the colonnade that was.
	var drum := CylinderMesh.new()
	drum.top_radius = 0.5
	drum.bottom_radius = 0.55
	drum.height = 3.0
	SternParts._mesh(holder, drum, stone, Vector3(-3.4, 0.6, 1.8), Vector3(0, 0.6, PI * 0.5))
	SternParts._mesh(holder, drum, stone, Vector3(3.6, 1.4, 1.2))
	# Sand drifted into the corners.
	for spot in [Vector3(-2.6, 0.12, 1.4), Vector3(2.9, 0.12, 1.5), Vector3(1.0, 0.2, -1.8)]:
		SternParts._box(holder, Vector3(1.6, 0.4, 1.0), SternParts.material(Color(0.86, 0.74, 0.5)), spot, Vector3(0, spot.x, 0))


## Shows what the hero has mended so far.
func refresh() -> void:
	var lamp := RuinedShrine.is_restored(level, "lamp")
	_lamp_flame.visible = lamp
	_lamp_light.light_energy = 2.4 if lamp else 0.0
	var head := RuinedShrine.is_restored(level, "head")
	_head.position = Vector3(0, 4.7, 1.0) if head else Vector3(1.3, 0.35, -1.5)
	var spring := RuinedShrine.is_restored(level, "spring")
	_water.visible = spring
	_motes.emitting = spring
	_spring_light.light_energy = 1.6 if spring else 0.0


## A prayer: full life, every ailment lifted, and the word goes out on the
## event bus for what else Mirenna's hand mends (see Events.mercy_prayed).
static func pray(game: Node) -> void:
	var p: Player = game.player
	var gain := p.max_hp - p.hp
	p.hp += gain
	if gain > 0:
		Effects.float_text(game.level, p.global_position + Vector3(0, 2.6, 0), "+%d" % gain, Color(0.5, 1.0, 0.5))
	var cured := p.cure()
	var burst := Effects.make_sparkles(LAMP_GOLD, true)
	burst.position = p.global_position + Vector3(0, 1.0, 0)
	game.level.add_child(burst)
	Sfx.play(game, "secret", -6.0)
	var text := Lang.t("Du kniest vor der Gnädigen Herrin nieder. Wärme fließt durch dich, und alles Übel fällt von dir ab.") if cured \
			else (Lang.t("Du kniest vor der Gnädigen Herrin nieder. Wärme fließt durch dich, und deine Wunden schließen sich.") if gain > 0 \
			else Lang.t("Du kniest vor der Gnädigen Herrin nieder. Sie lächelt still: Dir fehlt nichts."))
	Events.tell(text, Color(1.0, 0.9, 0.6), 5.0)
	Events.teach(LORE)
	Events.bus().mercy_prayed.emit(restored_count(game.level))
	game._update_hud()


## Gives the copper for `id` and mends that part. "" when it worked, else why not.
static func restore(game: Node, id: String) -> String:
	var lvl: Level = game.level
	var step := next_step(lvl)
	if step.is_empty() or step.id != id:
		return Lang.t("Dieses Stück ist schon heil, oder ein anderes ist zuerst dran.")
	if game.coins < int(step.cost):
		return Lang.t("Dafür reicht dein Kupfer nicht.")
	game.coins -= int(step.cost)
	lvl.taken[key_of(id)] = true
	for s in lvl.stations:
		if s.kind == KIND:
			s.shrine.refresh()
	Sfx.play(game, "secret", -4.0)
	var told := {
		"lamp": "Die Lampe brennt wieder. Ihr goldenes Licht fällt auf den Altar.",
		"head": "Du richtest das Haupt der Herrin auf. Ihr steinernes Gesicht sieht wieder auf die Pilger hinab.",
		"spring": "Die Quelle bricht aus dem Sand und füllt das Becken mit klarem Wasser.",
	}
	Events.tell(Lang.t(told[id]), Color(1.0, 0.9, 0.6), 5.0)
	if next_step(lvl).is_empty():
		Events.tell(Lang.t("Der Schrein der Gnädigen Herrin ist wieder ganz. Du spürst ihren Segen."), Color(1.0, 0.9, 0.6), 6.0)
	game._update_hud()
	return ""
