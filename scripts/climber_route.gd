class_name ClimberRoute
extends RefCounted
## The rock climber's day (see ClimberNpc): he climbs the face the hero can learn on, again and again,
## under the same rules as the hero (RockClimb: three pull-ups, then a nail and the rope, then a nail
## after every two pull-ups), but he never slips. At the top he sits down at the edge and enjoys the view,
## then climbs down hold by hold, taking his nails and the rope out on the way, and starts over.
## The Villager hands every physics tick of the task "climb" to `step`.

enum Phase { WAIT, PULL, HAMMER, THREAD, TOP, VIEW, STAND, STEP_OVER, DOWN, UNCLIP }

## Seconds at the foot before each climb, and at the top before he gets up again.
const WAIT_SECONDS := 6.0
const VIEW_SECONDS := 40.0
const STAND_SECONDS := 1.6
## A little faster than the hero's first pull-ups: he has done this a thousand times.
const PULL_SECONDS := 1.15
const DOWN_SECONDS := 0.9
const UNCLIP_SECONDS := 1.5
const DIR := Vector3(0, 0, -1)
## How far back from the middle of the terrace (towards the rock) he stands and sits: the flat top ends a metre
## in front of the middle, and his legs reach out in front of him when he sits.
const SEAT_BACK := 0.7
## The Klettern level the rules are played with: a master, so his pull-ups always hold.
const SKILL := 30
## What he says at the top, one after another.
const VIEW_LINES := ["Was für eine Aussicht!", "Da unten liegt das ganze Tal.", "Hier oben hört dich keiner, und das ist gut so.", "Ah, der Wind!"]

var spot := {}
var rules: RockClimb
var phase := Phase.WAIT
var u := 0.0
var y := 0.0
var from := 0.0
var left := true
var start := Vector3.ZERO
var rope: Node3D = null
var nails_left: Array[float] = []
var line := 0
var unclipped := false


## The route of the climber `v` on the spot at ClimberNpc.SPOT_CELL, or null when this map has none.
static func make(v: Villager) -> ClimberRoute:
	var spot := ClimbSpots.at(v.level, ClimberNpc.SPOT_CELL)
	if spot.is_empty():
		return null
	var route := ClimberRoute.new()
	route.spot = spot
	var mid := v.level.cell_to_world(spot.cell)
	route.start = Vector3(mid.x, 0.0, mid.z + Level.TILE * 0.5 + v.radius + 0.05)
	return route


## Where the face is at height `h` (the body hangs in front of it).
func place_at(h: float) -> Vector3:
	return start + DIR * (2.0 * h / maxf(0.5, float(spot.height))) + Vector3(0, h, 0)


func surface(h: float, radius: float) -> Vector3:
	return start + DIR * (2.0 * h / maxf(0.5, float(spot.height)) + radius) + Vector3(0, h, 0)


## Back at the foot, ready for the next climb.
func reset(v: Villager) -> void:
	rules = RockClimb.new(float(spot.height), int(spot.level), SKILL)
	phase = Phase.WAIT
	u = 0.0
	y = 0.0
	nails_left.clear()
	unclipped = false
	_drop_rope()
	ClimberOutfit.hammer_in_hand(v._model, false)


func _drop_rope() -> void:
	if rope != null and is_instance_valid(rope):
		rope.queue_free()
	rope = null


## Called when the climber is taken off the wall by something else (an alarm, a fright): down on the
## ground, the rope gone, standing again.
func leave(v: Villager) -> void:
	if v._model == null:
		return
	_drop_rope()
	ClimberOutfit.hammer_in_hand(v._model, false)
	if phase != Phase.WAIT:
		v.unpose_body()
		v.global_position = start
		v.reset_physics_interpolation()
	phase = Phase.WAIT


func begin(v: Villager) -> void:
	reset(v)
	v.global_position = start
	v.rotation.y = PI
	v.reset_physics_interpolation()
	v.play("Idle")


func step(v: Villager, delta: float) -> void:
	v._task_time = 600.0
	if rules == null:
		begin(v)
	match phase:
		Phase.WAIT:
			u += delta / WAIT_SECONDS
			v.global_position = start
			v.rotation.y = PI
			v.play("Idle")
			if u >= 1.0:
				v.play("Idle")
				_begin_pull(v)
		Phase.PULL:
			u = minf(1.0, u + delta / PULL_SECONDS)
			var lift := smoothstep(RopeClimbPose.PULL_ROLL, RopeClimbPose.PULL_LIFTED, u)
			_pose(v, RopeClimbPose.at("pull_l" if left else "pull_r", u))
			_place(v, from + RockClimb.PULL * lift)
			if u >= 1.0:
				var result := rules.pull(0.0, true)
				match result:
					RockClimb.Result.TOP:
						phase = Phase.TOP
						u = 0.0
					RockClimb.Result.PITON:
						phase = Phase.HAMMER
						u = 0.0
					_:
						_begin_pull(v)
		Phase.HAMMER:
			u = minf(1.0, u + delta / Player.ROCK_HAMMER_SECONDS)
			ClimberOutfit.hammer_in_hand(v._model, u > 0.22 and u < 0.9)
			_pose(v, RopeClimbPose.at("hammer", u))
			if u >= 1.0:
				rules.set_nail()
				nails_left.append(rules.safe)
				_add_nail(v)
				phase = Phase.THREAD
				u = 0.0
		Phase.THREAD:
			u = minf(1.0, u + delta / Player.ROCK_THREAD_SECONDS)
			_pose(v, RopeClimbPose.at("thread", u))
			if u >= 1.0:
				_begin_pull(v)
		Phase.TOP:
			u = minf(1.0, u + delta / Player.ROCK_TOP_SECONDS)
			_pose(v, RopeClimbPose.at("top", u))
			v.global_position = _edge().lerp(_terrace(v), smoothstep(0.3, 1.0, u))
			_rope_update(v)
			if u >= 1.0:
				phase = Phase.VIEW
				u = 0.0
				line = 0
				v.unpose_body()
				v.rotation.y = 0.0
				v.play("Sit_Floor_Idle")
		Phase.VIEW:
			u += delta / VIEW_SECONDS
			v.global_position = _terrace(v)
			if v._bubble_time <= 0.0 and u > 0.1 + 0.22 * line and line < VIEW_LINES.size():
				v.say(Lang.t(VIEW_LINES[line]))
				line += 1
			if u >= 1.0:
				phase = Phase.STAND
				u = 0.0
				v.rotation.y = PI
				v.play("Idle")
		Phase.STAND:
			u = minf(1.0, u + delta / STAND_SECONDS)
			v.global_position = _terrace(v)
			if u >= 1.0:
				phase = Phase.STEP_OVER
				u = 1.0
		Phase.STEP_OVER:
			# The way up over the edge, played backwards.
			u = maxf(0.0, u - delta / Player.ROCK_TOP_SECONDS)
			_pose(v, RopeClimbPose.at("top", u))
			v.global_position = _edge().lerp(_terrace(v), smoothstep(0.3, 1.0, u))
			_rope_update(v)
			if u <= 0.0:
				y = float(spot.height)
				left = true
				phase = Phase.DOWN
				u = 0.0
		Phase.DOWN:
			u = minf(1.0, u + delta / DOWN_SECONDS)
			_pose(v, RopeClimbPose.at("desc_l" if left else "desc_r", u))
			_place(v, maxf(0.0, y - delta / DOWN_SECONDS))
			if u >= 1.0:
				left = not left
				u = 0.0
			if not nails_left.is_empty() and y <= nails_left.back() + 0.001:
				phase = Phase.UNCLIP
				u = 0.0
				unclipped = false
			elif y <= 0.001:
				_land(v)
		Phase.UNCLIP:
			u = minf(1.0, u + delta / UNCLIP_SECONDS)
			ClimberOutfit.hammer_in_hand(v._model, u > 0.55)
			_pose(v, RopeClimbPose.at("thread" if u < 0.55 else "hammer", u if u < 0.55 else (u - 0.55) / 0.45 * 0.5))
			if u >= 0.8 and not unclipped:
				unclipped = true
				_remove_nail(nails_left.pop_back())
			if u >= 1.0:
				ClimberOutfit.hammer_in_hand(v._model, false)
				phase = Phase.DOWN
				u = 0.0
				if y <= 0.001:
					_land(v)
	if rope != null and phase in [Phase.PULL, Phase.HAMMER, Phase.THREAD, Phase.DOWN, Phase.UNCLIP]:
		_rope_update(v)


func _begin_pull(v: Villager) -> void:
	phase = Phase.PULL
	u = 0.0
	from = y
	left = not left
	if rope == null:
		_make_rope(v)


func _land(v: Villager) -> void:
	v.unpose_body()
	v.global_position = start
	v.rotation.y = PI
	v.reset_physics_interpolation()
	_drop_rope()
	ClimberOutfit.hammer_in_hand(v._model, false)
	rules = RockClimb.new(float(spot.height), int(spot.level), SKILL)
	nails_left.clear()
	y = 0.0
	phase = Phase.WAIT
	u = 0.0
	v.play("Idle")


func _pose(v: Villager, pose: Dictionary) -> void:
	v.pose_body(pose)


func _place(v: Villager, h: float) -> void:
	y = h
	v.global_position = place_at(h)


## Where the edge of the terrace is, hanging, and where he stands on it.
func _edge() -> Vector3:
	return start + DIR * 2.0 + Vector3(0, float(spot.height), 0)


func _terrace(v: Villager) -> Vector3:
	return ClimbSpots.top(v.level, spot) + Vector3(0, 0, -SEAT_BACK)


# --- The nails and the rope ----------------------------------------------------------------------

func _make_rope(v: Villager) -> void:
	rope = Node3D.new()
	rope.name = "ClimberRope"
	v.level.add_child(rope)


func _add_nail(v: Villager) -> void:
	var nail := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.012
	mesh.height = 0.22
	nail.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.32, 0.35)
	mat.metallic = 0.7
	mat.roughness = 0.45
	nail.material_override = mat
	nail.name = "Nail%d" % int(round(rules.safe * 10.0))
	nail.rotation.x = PI * 0.5
	nail.position = surface(rules.safe + 0.9, v.radius) - DIR * 0.08
	rope.add_child(nail)


func _remove_nail(h: float) -> void:
	if rope == null:
		return
	var nail := rope.get_node_or_null("Nail%d" % int(round(h * 10.0)))
	if nail != null:
		nail.queue_free()


## The rope from the foot of the face through every nail to his belt.
func _rope_update(v: Villager) -> void:
	if rope == null:
		return
	var points: Array[Vector3] = [surface(0.0, v.radius) + Vector3(0, 0.05, 0) - DIR * 0.15]
	for h in nails_left:
		points.append(surface(h + 0.9, v.radius) - DIR * 0.15)
	points.append(v.global_position + Vector3(0, 0.9, 0))
	var segs := rope.find_children("Seg*", "MeshInstance3D", false, false)
	while segs.size() < points.size() - 1:
		var seg := MeshInstance3D.new()
		seg.name = "Seg%d" % segs.size()
		var m := CylinderMesh.new()
		m.top_radius = 0.022
		m.bottom_radius = 0.022
		m.height = 1.0
		m.radial_segments = 6
		seg.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.5, 0.3)
		mat.roughness = 0.95
		seg.material_override = mat
		rope.add_child(seg)
		segs.append(seg)
	for i in segs.size():
		var seg := segs[i] as MeshInstance3D
		seg.visible = i < points.size() - 1
		if not seg.visible:
			continue
		var a := points[i]
		var b := points[i + 1]
		var length := maxf(0.01, a.distance_to(b))
		seg.global_position = (a + b) * 0.5
		var up := (b - a) / length
		var axis := Vector3.UP.cross(up)
		var basis := Basis(axis.normalized(), Vector3.UP.angle_to(up)) if axis.length() > 0.001 else Basis()
		seg.global_basis = basis.scaled(Vector3(1, length, 1))
