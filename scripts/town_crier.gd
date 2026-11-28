class_name TownCrier
extends RefCounted
## Herald Konrad as the town crier. Three things belong to him here:
##
## The stage: his podium on the grass by the street north of the square, with the NEWS! sign beside it (see
## CrierPodium). When he calls the village (the daily news, a deed of the hero, the usual calls, see
## Outdoor._call_the_village), he walks to the podium's steps, climbs up, raises his loudhailer (see Loudhailer)
## to his mouth, speaks, lowers it and steps down again. That is the task "announce", an instance of this class
## for the herald, driven by Villager._physics_process.
##
## Making way: Matthes sweeps the footpath right through the herald's spot. When he comes close, Konrad steps
## aside, says a word of thanks for his work and goes back to his place when he has passed (see give_way).
##
## The sign's mouse-over (see sign_under_ray): its text is CrierNews.SIGN_TIP.

const ROLE := "K"
const TASK := "announce"
const WAIT_TASK := "makeway"

## The podium's tile, from the herald's home tile: on the grass to the north-west, clear of the footpath he and
## Matthes keep to, and of the doors to the north.
const PODIUM_CELL := Vector2i(-1, -1)

## The seconds of each part of the act.
const CLIMB_TIME := 1.7
const RAISE_TIME := 1.0
const SPEAK_TIME := 7.0
const LOWER_TIME := 0.8
const DESCEND_TIME := 1.5

## Where the loudhailer lies in the herald's hand and where it is held at the mouth, in metres from the head
## bone (the model's own turn; see _mouth).
const MOUTH_UP := 0.27
const MOUTH_OUT := 0.28
const HAND_TURN := Vector3(0.0, 0.0, 0.0)

## How close Matthes (and his broom) comes before Konrad steps aside, how far he steps, and how long he waits.
const WAY_REACH := 2.6
const WAY_STEP := 2.3
const WAY_WAIT := 4.5
## Seconds between two thanks.
const WAY_COOLDOWN := 50.0
const THANKS := [
	"Nur zu, Matthes, kehr! Dank dir sind unsere Wege immer so sauber.",
	"Ich gehe gern zur Seite, Matthes. Ein Dorf ist nur so reinlich wie sein Straßenfeger.",
	"Weiter so, Matthes! Deine Arbeit sieht jeder, nur sagt es dir selten einer.",
	"Platz für den fleißigsten Besen der Krone! Gut gemacht, Matthes.",
]

## The phases of an announcement, in order.
const PHASES := ["climb", "raise", "speak", "lower", "descend"]

var herald: Villager
var text := ""
var phase := ""
var clock := 0.0
var hailer: Node3D
var _hand: Node3D
var _from := Vector3.ZERO
var _thanks_at := -1000.0
var _spoke := false
var _dt := 0.016
## Matthes, whom he made way for, and whether he still owes him a word of thanks.
var way_for: Villager
var thanks_due := false


func _init(who: Villager) -> void:
	herald = who


# --- The stage -----------------------------------------------------------------------------------

## Builds the podium and the sign on the grass north-west of the herald's spot, if the map has it free, and
## remembers where everything stands in `level.crier_stage` ({} when there is no room).
static func build_stage(level: Outdoor) -> void:
	level.crier_stage = {}
	var herald := level.herald()
	if herald == null:
		return
	var cell := herald.home + PODIUM_CELL
	var sign_cell := cell + Vector2i(-1, 0)
	for c: Vector2i in [cell, cell + Vector2i(1, 0), sign_cell]:
		if not level.is_open(c) or level.cell_char(c) != ".":
			return
	var pos := level.cell_to_world(cell)
	CrierPodium.build(level, pos)
	level.crier_stage = {
		"pos": pos,
		"foot": pos + CrierPodium.STEP_FOOT,
		"stand": pos + CrierPodium.STAND,
		"sign": pos + CrierPodium.SIGN_AT + CrierPodium.BOARD_CENTRE,
	}
	level.add_stage_solids(pos, CrierPodium.BLOCK, pos + CrierPodium.SIGN_AT, CrierPodium.SIGN_BLOCK, [cell, sign_cell])


## Whether the ray from `from` along `dir` passes the sign's board close enough (the mouse is over it).
static func sign_under_ray(level: Object, from: Vector3, dir: Vector3) -> bool:
	if level == null or not level.get("crier_stage") is Dictionary or level.crier_stage.is_empty():
		return false
	var centre: Vector3 = level.crier_stage.sign
	return LadderClick.ray_miss(from, dir, centre - Vector3(0.8, 0, 0), centre + Vector3(0.8, 0, 0)) < 0.55


# --- The announcement ----------------------------------------------------------------------------

## Starts an announcement: he walks to the steps first. Returns false when there is no podium or he cannot go now.
static func begin(herald: Villager, line: String) -> bool:
	var level := herald.level
	if level == null or level.crier_stage.is_empty() or herald.at_home or not herald.visible or herald.is_announcing():
		return false
	if herald._crier == null:
		herald._crier = TownCrier.new(herald)
	herald._crier.text = line
	herald._crier.phase = ""
	herald.crier_walk(level.crier_stage.foot)
	return true


## One physics tick of the task: the climb, the raise, the speech, the lowering and the way down.
func step(delta: float) -> void:
	var stage: Dictionary = herald.level.crier_stage
	if stage.is_empty():
		herald.end_announce()
		return
	if phase == "":
		phase = "climb"
		clock = 0.0
		_from = herald.global_position
		_spoke = false
	clock += delta
	_dt = delta
	match phase:
		"climb":
			_climb(clock / CLIMB_TIME, stage)
			herald.play("Walking_B")
			if clock >= CLIMB_TIME:
				_next("raise")
		"raise":
			_face_crowd(delta)
			herald.play("Idle")
			_lay_hailer(ease(clamp(clock / RAISE_TIME, 0.0, 1.0), -2.0))
			if clock >= RAISE_TIME:
				_next("speak")
		"speak":
			_face_crowd(delta)
			herald.play("Idle")
			_lay_hailer(1.0)
			if not _spoke:
				_spoke = true
				herald.say(text, Vector3.INF, SPEAK_TIME)
			if clock >= SPEAK_TIME:
				_next("lower")
		"lower":
			_face_crowd(delta)
			herald.play("Idle")
			_lay_hailer(1.0 - ease(clamp(clock / LOWER_TIME, 0.0, 1.0), -2.0))
			if clock >= LOWER_TIME:
				_next("descend")
				_hold(false)
				_from = herald.global_position
		"descend":
			_climb(1.0 - clock / DESCEND_TIME, stage)
			herald.play("Walking_B")
			if clock >= DESCEND_TIME:
				herald.end_announce()


func _next(to: String) -> void:
	phase = to
	clock = 0.0


## The herald's place on the way up: along the steps and over the deck's edge to where he speaks. `f` runs from 0
## (at the foot of the steps) to 1 (at the lectern), and back down.
func _climb(f: float, stage: Dictionary) -> void:
	f = clampf(f, 0.0, 1.0)
	var foot: Vector3 = stage.foot
	var stand: Vector3 = stage.stand
	var pos: Vector3 = stage.pos
	var way := [foot, pos + Vector3(2.0, 0.22, 0.0), pos + Vector3(1.55, 0.44, 0.0), pos + Vector3(1.15, CrierPodium.DECK_H, stand.z - pos.z), stand]
	var at := f * float(way.size() - 1)
	var i := mini(int(at), way.size() - 2)
	var p: Vector3 = (way[i] as Vector3).lerp(way[i + 1], at - i)
	var heading := (way[i + 1] as Vector3) - (way[i] as Vector3)
	heading.y = 0.0
	herald.global_position = p
	if f < 1.0 and heading.length() > 0.01:
		herald.face(heading, _dt * 4.0)
	if f >= 1.0:
		herald.face(Vector3(0, 0, 1), _dt * 8.0)


func _face_crowd(delta: float) -> void:
	herald.face(Vector3(0, 0, 1), delta * 6.0)


## The loudhailer between his hand (0) and his mouth (1), laid on every tick.
func _lay_hailer(f: float) -> void:
	_hold(true)
	var model := herald.model()
	var hand_at := _hand.global_transform
	var facing := Vector3(sin(model.global_rotation.y), 0, cos(model.global_rotation.y))
	var mouth := _mouth(facing)
	# In the hand it lies along his forearm, the bell forward; at the mouth the bell points at the crowd, a little up.
	var hand_basis := Basis.looking_at(-(facing + Vector3(0, 0.1, 0)), Vector3.UP)
	var mouth_basis := Basis.looking_at(-(facing + Vector3(0, 0.12, 0)), Vector3.UP)
	hailer.global_transform = Transform3D(hand_basis.slerp(mouth_basis, f), hand_at.origin.lerp(mouth, f))


func _mouth(facing: Vector3) -> Vector3:
	var model := herald.model()
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skeleton.find_bone("head")
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	return head.origin + Vector3.UP * MOUTH_UP * model.scale.y + facing * MOUTH_OUT * model.scale.y


## The loudhailer in his hand, or put away.
func _hold(on: bool) -> void:
	if hailer == null:
		if not on:
			return
		_hand = herald.model().find_child("handslot_r", true, false)
		if _hand == null:
			return
		hailer = Loudhailer.build()
		hailer.top_level = true
		herald.model().add_child(hailer)
	hailer.visible = on
	if on and _hand == null:
		_hand = herald.model().find_child("handslot_r", true, false)


## The announcement is over (or called off): the horn away, the herald down on the ground.
func stop() -> void:
	_hold(false)
	phase = ""
	var level := herald.level
	if level != null and herald.global_position.y > 0.0:
		herald.global_position.y = 0.0


# --- Making way for Matthes ------------------------------------------------------------------------

## Called every tick Matthes sweeps, with the way he sweeps: the herald steps out of the way when Matthes comes
## near, thanks him once in a while and goes back to his place later.
static func give_way(sweeper: Villager, heading: Vector3) -> void:
	var level := sweeper.level
	var herald := level.herald() if level != null else null
	if herald == null or herald == sweeper or not herald.can_make_way():
		return
	var rel := herald.global_position - sweeper.global_position
	rel.y = 0.0
	if rel.length() > WAY_REACH or rel.normalized().dot(heading.normalized()) < -0.2:
		return
	var side := heading.cross(Vector3.UP).normalized()
	var first := 1.0 if rel.dot(side) >= 0.0 else -1.0
	for sign in [first, -first]:
		var to: Vector3 = herald.global_position + side * sign * WAY_STEP
		if level.is_open(level.world_to_cell(to)) and not WalkRules.blocked_at(level, to):
			herald.step_aside(to, sweeper)
			return


## One tick of waiting aside: he turns to Matthes and, the first tick, says his thanks.
func wait(delta: float) -> void:
	herald.play("Idle")
	if way_for != null and is_instance_valid(way_for):
		herald.face(way_for.global_position - herald.global_position, delta * 4.0)
	if thanks_due:
		thanks_due = false
		_thanks_at = Time.get_ticks_msec() / 1000.0
		var look := way_for.global_position if way_for != null and is_instance_valid(way_for) else Vector3.INF
		herald.say(Lang.t(THANKS[randi() % THANKS.size()]), look, 4.5)


## Whether Matthes is still close, so he stays aside a little longer.
func sweeper_near() -> bool:
	if way_for == null or not is_instance_valid(way_for):
		return false
	var rel := way_for.global_position - herald.global_position
	rel.y = 0.0
	return rel.length() < WAY_REACH * 0.8 and way_for.is_sweeping_now()


## Whether enough time has passed since his last thanks.
func may_thank(now: float) -> bool:
	return now - _thanks_at >= WAY_COOLDOWN


