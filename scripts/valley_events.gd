class_name ValleyEvents
extends Node
## Small, funny things that happen in the farming valley now and then, in the open for the hero to see and
## to help with, for a small reward (see Events.gift_paid):
##   The ladder: on some mornings the farmhand Veit climbs the ladder against the barn house to fetch
##     something, looks down and cannot get back. He hangs there shouting for help until the hero
##     shakes the ladder steady (walk into it), or he gets down by himself before noon, very grumpy.
##   The scarecrow: on some afternoons a crow lands on the scarecrow's hat, caws, and the scarecrow
##     tips over. The hero stands it up again; if not, the farmer does by the evening.
##   Hannes' nap: at noon he sits down by the well and snores (the rest in ValleyFolk).
## A day's event happens once, whether it was helped or not. Everything is built from the map: no ladder
## where the ground is not free, and none without the farmhand.

const KIND := "tal_ereignis"
const LADDER := "leiter"
const SCARECROW := "vogelscheuche"
## Where they stand: tiles of the valley map "Apfeltal".
const LADDER_CELL := Vector2i(42, 90)
## The scarecrow stands in the middle of the sunflower field (see SunflowerRiddle), between this tile and the one below it.
const SCARECROW_CELL := Vector2i(61, 88)
## The hours the events happen in.
const LADDER_HOURS := Vector2(9.5, 11.5)
const SCARECROW_HOURS := Vector2(14.0, 16.5)
const SCARECROW_RESET := 18.0
## How many days in a hundred an event happens (rolled once a day from the day's number).
const LADDER_CHANCE := 70
const SCARECROW_CHANCE := 60
## What the hero is paid for helping (copper).
const LADDER_REWARD := 6
const SCARECROW_REWARD := 4
const CALLS := ["Hilfe! Hilfe! Ich komme nicht mehr runter!", "Jemand muss die Leiter halten!", "Veit steckt fest! Veit, das bin ich!", "Nicht nach unten schauen, nicht nach unten schauen...", "Ich wollte doch nur die Taube vom Dach holen!"]
const CALL_EVERY := Vector2(5.0, 8.0)
const THANKS_LADDER := "Danke, Fremder! Ich schulde dir was. Sag Hannes nichts davon."
const GRUMBLE_LADDER := "Ich bin selbst runtergekommen. Ich wollte nur die Aussicht genießen."
const CAW := "Kraah!"
const THANKS_SCARECROW := "Du hast die Vogelscheuche gerettet! Die Krähen hatten sie schon aufgegeben."
const LADDER_HEIGHT := 2.3
## The hero must be this near (metres) for the crow to come: nobody sees it from afar.
const NEAR := 110.0

var level: Outdoor
var _clock := 0.0
## 0: nothing, 1: the farmhand on his way, 2: stuck on the ladder, 3: over for today.
var ladder_phase := 0
var scare_phase := 0
var _ladder_day := -1
var _scare_day := -1
var _veit: Villager
var _hannes: Villager
var _ladder_station := {}
var _scare_station := {}
var _ladder: Node3D
var _scare: Node3D
var _crow: Node3D
var _next_call := 0.0
var _zzz: Label3D


func setup(lvl: Outdoor) -> void:
	level = lvl
	name = "ValleyEvents"
	for v: Villager in level.villagers:
		if v.role == "χ":
			_veit = v
		elif v.role == "φ":
			_hannes = v
	if _veit != null and _free(LADDER_CELL):
		_ladder = _build_ladder()
		_ladder.position = level.cell_to_world(LADDER_CELL)
		add_child(_ladder)
	if _free(SCARECROW_CELL):
		_scare = ScarecrowModel.build()
		_scare.position = SunflowerRiddle.centre()
		add_child(_scare)
		level._add_solid(_scare.position, Vector3(0.9, 2.0, 0.9))


func _free(c: Vector2i) -> bool:
	return level.cell_char(c) in [".", CropFields.SUNFLOWER] and level.is_open(c)


## Whether the event of this kind happens on `day` (a fixed roll per day, so it is the same however often one asks).
static func happens(day: int, salt: int, chance: int) -> bool:
	return absi(hash("%d:%d" % [day, salt])) % 100 < chance


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.5 or level == null or level.hour < 0.0:
		return
	var dt := _clock
	_clock = 0.0
	_tick_ladder(dt)
	_tick_scarecrow(dt)
	_tick_nap()


# --- The ladder ----------------------------------------------------------------

func _tick_ladder(dt: float) -> void:
	if _ladder == null or _veit == null or not is_instance_valid(_veit):
		return
	var hour := level.hour
	var foot := level.cell_to_world(LADDER_CELL) + Vector3(-1.2, 0, 0)
	if _ladder_day != level.day:
		_ladder_day = level.day
		ladder_phase = 0
	var in_window := hour >= LADDER_HOURS.x and hour < LADDER_HOURS.y
	match ladder_phase:
		0:
			if in_window and happens(level.day, 1, LADDER_CHANCE) and not _veit.at_home and not _veit.night and not level.village_alarm.raised:
				ladder_phase = 1
				_veit._job = {"id": "ladder"}
				_veit._walk_to(foot, Villager.WALK_SPEED * 1.2, "work")
		1:
			if not in_window:
				ladder_phase = 3
			elif _veit._task != "walk" and _flat(_veit.global_position, foot) < 2.5:
				_climb(foot)
		2:
			_veit.global_position = Vector3(foot.x, _veit.global_position.y, foot.z)
			_next_call -= dt
			if _next_call <= 0.0:
				_next_call = randf_range(CALL_EVERY.x, CALL_EVERY.y)
				Effects.head_text(level, _veit, 5.4, Lang.t(CALLS[randi() % CALLS.size()]), Color(1.0, 0.8, 0.5))
			if hour >= LADDER_HOURS.y:
				_climb_down(false)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _climb(foot: Vector3) -> void:
	ladder_phase = 2
	_next_call = 0.5
	_veit._job = {"id": "stuck", "anim": "Cheer", "face": foot + Vector3(2, 0, 0)}
	_veit._start("work", 9999.0)
	var tween := create_tween()
	tween.tween_property(_veit._model, "position:y", LADDER_HEIGHT, 1.6)
	_ladder_station = {"kind": KIND, "what": LADDER, "cell": LADDER_CELL, "pos": foot + Vector3(0.6, 0, 0), "used": false}
	level.stations.append(_ladder_station)


## Veit is down again: helped by the hero, or by himself.
func _climb_down(helped: bool) -> void:
	ladder_phase = 3
	if _ladder_station.has("used"):
		_ladder_station.used = true
		level.stations.erase(_ladder_station)
	var tween := create_tween()
	tween.tween_property(_veit._model, "position:y", 0.0, 1.2)
	_veit._job = {}
	_veit._start("idle", 2.0)
	Effects.head_text(level, _veit, 3.2, Lang.t(THANKS_LADDER if helped else GRUMBLE_LADDER), Color(0.96, 0.9, 0.7))


# --- The scarecrow -------------------------------------------------------------

func _tick_scarecrow(dt: float) -> void:
	if _scare == null:
		return
	var hour := level.hour
	if _scare_day != level.day:
		_scare_day = level.day
		scare_phase = 0
		_stand_up(false)
	match scare_phase:
		0:
			if hour >= SCARECROW_HOURS.x and hour < SCARECROW_HOURS.y and happens(level.day, 2, SCARECROW_CHANCE) and not level.village_alarm.raised \
					and level.player != null and _flat(level.player.global_position, _scare.position) < NEAR:
				scare_phase = 1
				_land_crow()
		3:
			if hour >= SCARECROW_RESET:
				_stand_up(false)
				scare_phase = 4


## The crow flies in, sits on the hat, caws, and the scarecrow goes over.
func _land_crow() -> void:
	_crow = _build_crow()
	var top := _scare.position + Vector3(0, ScarecrowModel.PERCH, 0)
	add_child(_crow)
	_crow.position = top + Vector3(14, 6, -10)
	var fly := create_tween()
	fly.tween_property(_crow, "position", top, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fly.tween_callback(func() -> void:
		if not is_instance_valid(_crow):
			return
		Effects.head_text(level, _crow, 0.6, Lang.t(CAW), Color(0.85, 0.85, 0.9))
		var tip := create_tween()
		tip.tween_interval(1.6)
		tip.tween_property(_scare, "rotation:z", 1.5, 1.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tip.tween_callback(_fallen))


func _fallen() -> void:
	scare_phase = 3
	if is_instance_valid(_crow):
		var away := create_tween()
		away.tween_property(_crow, "position", _crow.position + Vector3(-18, 9, 12), 1.8).set_trans(Tween.TRANS_SINE)
		away.tween_callback(_crow.queue_free)
	_scare_station = {"kind": KIND, "what": SCARECROW, "cell": SCARECROW_CELL, "pos": _scare.position + Vector3(-1.6, 0, 1.0), "used": false}
	level.stations.append(_scare_station)


func _stand_up(helped: bool) -> void:
	if _scare != null:
		_scare.rotation.z = 0.0
	if _scare_station.has("used"):
		_scare_station.used = true
		level.stations.erase(_scare_station)
	_scare_station = {}
	if is_instance_valid(_crow):
		_crow.queue_free()
	if helped and _hannes != null and is_instance_valid(_hannes):
		Effects.head_text(level, _hannes, 3.4, Lang.t(THANKS_SCARECROW), Color(0.96, 0.9, 0.7))


# --- Hannes' nap ---------------------------------------------------------------

func _tick_nap() -> void:
	if _hannes == null or not is_instance_valid(_hannes):
		return
	var napping: bool = _hannes._job.get("id", "") == "rest" and _hannes._task == "work" and not _hannes.at_home
	if napping and _zzz == null:
		_zzz = Label3D.new()
		_zzz.text = "Zzz"
		_zzz.font = SpeechBubble.FONT
		_zzz.font_size = 90
		_zzz.pixel_size = 0.011
		_zzz.outline_size = 14
		_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_zzz.no_depth_test = true
		_zzz.modulate = Color(0.85, 0.9, 1.0)
		_zzz.position = Vector3(0.4, 2.2, 0)
		_hannes.add_child(_zzz)
	elif not napping and _zzz != null:
		_zzz.queue_free()
		_zzz = null
	elif napping:
		_zzz.position.y = 2.2 + 0.15 * sin(Time.get_ticks_msec() / 400.0)


# --- The hero helps ------------------------------------------------------------

## The hero ran into the ladder or the scarecrow (see Game._use_station).
func help(what: String) -> void:
	if what == LADDER and ladder_phase == 2:
		_climb_down(true)
		Events.bus().gift_paid.emit(LADDER_REWARD, Lang.t("Du hältst die Leiter fest. Veit kommt zitternd herunter."))
	elif what == SCARECROW and scare_phase == 3:
		_stand_up(true)
		scare_phase = 4
		Events.bus().gift_paid.emit(SCARECROW_REWARD, Lang.t("Du stellst die Vogelscheuche wieder auf."))


## The prompt beside the ladder or the scarecrow.
static func prompt(station: Dictionary) -> String:
	if station.get("what", "") == LADDER:
		return Lang.t("Dagegenlaufen, um die Leiter festzuhalten")
	return Lang.t("Dagegenlaufen, um die Vogelscheuche aufzustellen")


# --- The props -----------------------------------------------------------------

## A tall wooden ladder, leaning with its top against the house to the east.
func _build_ladder() -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var b := WeatheredProps.Builder.new()
	var wood := WeatheredProps.TIMBER
	var lean := 0.62
	var top := 3.5
	for side in [-0.34, 0.34]:
		b.bar(Vector3(-0.6, 0, side), Vector3(-0.6 + lean, top, side), 0.045, WeatheredProps.vary(wood[1], rng, 0.07), WeatheredProps.WOOD, 7)
	var rungs := 9
	for i in rungs:
		var t := (i + 0.7) / (rungs + 0.4)
		var x := -0.6 + lean * t
		b.bar(Vector3(x, t * top, -0.34), Vector3(x, t * top, 0.34), 0.026, WeatheredProps.vary(wood[0], rng, 0.08), WeatheredProps.WOOD, 6)
	b.finish(root, Vector3(1.2, 0, 0))
	return root


func _build_crow() -> Node3D:
	var root := Node3D.new()
	var b := WeatheredProps.Builder.new()
	var black := Color(0.08, 0.08, 0.1)
	b.frustum(Vector3(0, 0.0, 0), Vector2(0.2, 0.34), Vector2(0.14, 0.2), 0.2, black, WeatheredProps.FRESH, Basis(Vector3.RIGHT, 0.25))
	b.box(Vector3(0, 0.18, 0.2), Vector3(0.12, 0.12, 0.14), black, WeatheredProps.FRESH)
	b.frustum(Vector3(0, 0.2, 0.3), Vector2(0.04, 0.02), Vector2(0.01, 0.01), 0.1, Color(0.3, 0.26, 0.2), WeatheredProps.FRESH, Basis(Vector3.RIGHT, -PI * 0.5))
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * 0.13, 0.1, -0.02), Vector3(0.04, 0.1, 0.3), black.lightened(0.05), WeatheredProps.FRESH, Basis(Vector3.FORWARD, side * 0.5))
	b.box(Vector3(0, 0.08, -0.26), Vector3(0.1, 0.03, 0.22), black, WeatheredProps.FRESH)
	b.finish(root, Vector3.ZERO, false, true)
	return root
