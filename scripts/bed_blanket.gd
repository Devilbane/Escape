class_name BedBlanket
extends RefCounted
## The blanket on a bed (the hero's cosy bed, an inn's cot or a villager's bed, see CosyBed): a woollen
## cloth that lies in a rumpled heap at the foot of the bed, is pulled up over the sleeper when they
## have lain down (`tuck`) and is pushed off again when they wake (`push_off`). It is one mesh in
## the bed's own space, so it turns, moves and hides (a floor above, see InsideView) with the bed.
##
## It is made once per bed, the first time somebody tucks in, and stays on the bed afterwards.

## The node name of the blanket under its bed.
const NODE := "Blanket"
## The group the cosy beds are in (see CosyBed.build), to find the bed at a place.
const BEDS := "cosy_beds"
## How near (metres, flat) a bed's origin has to be to the place asked for.
const NEAR := 0.4

## Where the blanket's foot end lies from the bed's origin: across the middle of the mattress, just
## inside the footboard, and on top of the quilt.
const FOOT := Vector3(CosyBed.LEFT * 0.5 + CosyBed.RIGHT * 0.5, CosyBed.MATTRESS_TOP + 0.1, 1.2)
## The cloth's top edge lies at the sleeper's chin: a little over the hips' distance from the head.
const TOP_Z := BedRise.LYING.z - 0.78
## The cloth: how wide (across) and how long (along, from the foot end towards the head), and the
## cells of its grid.
const WIDTH := 1.28
const LENGTH := FOOT.z - TOP_Z
const CELLS := Vector2i(14, 22)
## How the cloth lies: scale along the bed and up (see `_heap`): over the sleeper, and at rest, thrown back
## flat over the foot half of the mattress (never a tent: the cloth falls down onto the bed).
const FLAT := Vector2(1.0, 1.0)
const HEAP := Vector2(0.55, 0.22)
const SHOVED := Vector2(0.55, 0.22)
## The cloth's colours: a faded blue wool with a darker stripe, its hem a little lighter.
const WOOL := Color(0.36, 0.45, 0.58)
const STRIPE := Color(0.27, 0.34, 0.46)
const HEM := Color(0.8, 0.76, 0.66)
## Seconds the blanket takes to be pulled up, and to be pushed off.
const PULL_TIME := 1.0
const PUSH_TIME := 0.8


## The blanket of the bed standing at `pos` (in the world, turned by `rot`) in `level`, built on first
## use: under the cosy bed there if there is one, else under a stand-in node at the bed.
static func of(level: Node, pos: Vector3, rot: float) -> Node3D:
	var host: Node3D = null
	if level != null and level.is_inside_tree():
		for bed: Node3D in level.get_tree().get_nodes_in_group(BEDS):
			if is_instance_valid(bed) and level.is_ancestor_of(bed) and _flat(bed.global_position, pos) < NEAR:
				host = bed
				break
	if host == null:
		var key := "BlanketBed_%d_%d_%d" % [roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0)]
		host = level.get_node_or_null(key) as Node3D
		if host == null:
			host = Node3D.new()
			host.name = key
			level.add_child(host)
			host.global_position = pos
			host.rotation.y = rot
	var cloth := host.get_node_or_null(NODE) as Node3D
	if cloth == null:
		cloth = _build()
		host.add_child(cloth)
		_heap(cloth, HEAP, 0.0)
		cloth.visible = false
	return cloth


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Pulls the blanket up over the sleeper lying in the bed at `pos`: from the heap at the foot, in
## `PULL_TIME` seconds after `delay`, or lying there at once (`at_once`). Returns the blanket.
static func tuck(level: Node, pos: Vector3, rot: float, at_once := false, delay := 0.0) -> Node3D:
	var cloth := of(level, pos, rot)
	_stop(cloth)
	cloth.visible = true
	if at_once:
		_heap(cloth, FLAT, 0.0)
		return cloth
	_heap(cloth, HEAP, 0.0)
	var tween := cloth.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	cloth.set_meta("tween", tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	# Hauled up with a jerk, overshooting a little before it settles.
	tween.tween_method(func(t: float): _heap(cloth, HEAP.lerp(FLAT, t), sin(t * PI)), 0.0, 1.0, PULL_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return cloth


## Throws the blanket back off the sleeper, over `time` seconds after `delay`: it falls down flat onto the
## foot half of the mattress and stays there until the next one tucks in.
static func push_off(level: Node, pos: Vector3, rot: float, at_once := false, delay := 0.0, time := PUSH_TIME) -> void:
	var cloth := of(level, pos, rot)
	_stop(cloth)
	if not cloth.visible:
		return
	if at_once:
		_heap(cloth, SHOVED, 0.0)
		return
	var from := Vector2(cloth.scale.z, cloth.scale.y)
	var tween := cloth.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	cloth.set_meta("tween", tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	# It slides down towards the foot and drops onto the mattress, the way a thrown-back cloth does.
	tween.tween_method(func(t: float): _heap(cloth, from.lerp(SHOVED, t), 0.0), 0.0, 1.0, time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Whether a blanket lies over somebody in the bed at `pos` right now.
static func covers(level: Node, pos: Vector3, rot: float) -> bool:
	var cloth := of(level, pos, rot)
	return cloth.visible and cloth.scale.z > 0.9


static func _stop(cloth: Node3D) -> void:
	if not cloth.has_meta("tween"):
		return
	var old = cloth.get_meta("tween")
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	cloth.remove_meta("tween")


## Lays the cloth out: `size` is its length along the bed (x) and its height (y) as a part of the full
## cloth, `flutter` lifts it for a moment while it is being hauled (0 = lying still).
static func _heap(cloth: Node3D, size: Vector2, flutter: float) -> void:
	cloth.scale = Vector3(1.0, size.y, size.x)
	cloth.position = FOOT + Vector3(0.0, flutter * 0.22, 0.0)
	# A heap that has been kicked down lies a little askew.
	cloth.rotation.y = lerpf(0.0, 0.14, clampf((1.0 - size.x) * 1.2, 0.0, 1.0))


## The cloth over the sleeper, from its foot end (the node's origin) up the bed towards the head (-z):
## it humps over the body, falls away at both sides, ripples across the bed and has a pale hem folded
## over at its top edge.
static func _build() -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := CELLS.x
	var rows := CELLS.y
	var heights: Array = []
	for j in rows + 1:
		for i in cols + 1:
			heights.append(_height(float(i) / cols, float(j) / rows))
	for j in rows:
		for i in cols:
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var u := float(i + k.x) / cols
				var v := float(j + k.y) / rows
				var colour := STRIPE if int(v * 7.0) % 2 == 0 and v < 0.9 else WOOL
				if v > 0.93:
					colour = HEM
				st.set_color(colour)
				st.add_vertex(Vector3((u - 0.5) * WIDTH, heights[(j + k.y) * (cols + 1) + i + k.x], -v * LENGTH))
	st.index()
	st.generate_normals()
	var mat := CosyBed.wool(Color(0.95, 0.95, 0.95), 0.35)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cloth := MeshInstance3D.new()
	cloth.name = NODE
	cloth.mesh = st.commit()
	cloth.material_override = mat
	return cloth


## How high the cloth lies over the quilt at `u` across (0..1) and `v` along (0 = foot, 1 = head edge).
static func _height(u: float, v: float) -> float:
	var across := absf(u - 0.5) * 2.0
	# The sleeper's body: a rounded hump, higher over the chest than over the feet.
	var hump := 0.36 + 0.04 * smoothstep(0.1, 0.75, v)
	var body := hump * sqrt(maxf(0.0, 1.0 - pow(across, 2.2) * 1.15))
	# Past the body the cloth falls away over the mattress's edge.
	var drape := 0.3 * smoothstep(0.62, 1.0, across)
	var ripple := 0.012 * sin(v * 24.0 + across * 5.0) * (1.0 - across * 0.5)
	# The top edge is folded over: a low roll.
	var roll := 0.035 * smoothstep(0.88, 0.96, v) * (1.0 - smoothstep(0.96, 1.0, v) * 0.5)
	return body - drape + ripple + roll
