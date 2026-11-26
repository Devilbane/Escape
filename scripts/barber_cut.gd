class_name BarberCut
extends RefCounted
## A haircut in the barber's chair (see BarberChair): a barber's cape goes round the hero's neck when
## they sit down; once they have picked a style or a colour Benno works on their head for LENGTH
## seconds, snipping with his scissors, chatting the way barbers do, while a storm of hair bursts out of
## the head in the colour of the old hair and drifts down to the ground. Then the new look appears, in
## one more flurry, and the cape comes off.
##
## The coins are paid when the choice is made (see Menus._restyle); the look is only worn at the end. A
## hero who gets up in the middle has it at once.

## How long the cut takes (seconds).
const LENGTH := 20.0
## Seconds between two snips (shortest, longest).
const SNIP_GAP := Vector2(0.28, 0.6)
## Seconds between two remarks of Benno.
const CHAT_GAP := 4.4
## The clippings that lie on the ground at most.
const MAX_CLIPPINGS := 90
## How long a lock lies on the floor before it fades (seconds).
const LIE_TIME := 9.0
## Hairs in the continuous storm per second, and in the bursts at the start and end of the cut.
const STORM_RATE := 150
const BURST := 260

## What Benno says while he works, in turn (German, see Lang).
const CHAT := [
	"Halt schön still, dann wird es gut.",
	"Beim Barbier hört man alles. Ich sage nichts. Fast nichts.",
	"Fritz schuldet dem Brauer schon wieder Bier. Aber das habe ich nicht gesagt.",
	"Nicht nicken, sonst geht es schief!",
	"Du kommst aus der alten Gruft? Dann hast du es am nötigsten.",
	"Draußen im Wald soll es Wölfe geben. Hier drin ist es sicher, ich habe ja die Schere.",
	"Das Wetter ist wie meine Kunden: unberechenbar.",
	"Gleich erkennt dich keiner wieder. Im besten Sinn.",
	"Ein bisschen mehr hier, ein bisschen weniger da. Ein Kunstwerk!",
	"Früher habe ich nur Bärte gestutzt. Jetzt forme ich Menschen.",
]

## The new look while the cut goes on ({} when none), the seconds left (-1 when none).
var look := {}
var left := -1.0
var _running := false
## The cut is done and the hero still sits: no cape again until they have got up.
var served := false
var cape: Node3D
var _storm: CPUParticles3D
var _burst: CPUParticles3D
var _snip := 0.0
var _chat := 0.0
var _line := 0
var _colours: Array = []
var _lying: Array = []
var _rng := RandomNumberGenerator.new()
static var _cape_mesh: ArrayMesh


func _init() -> void:
	_rng.randomize()


func active() -> bool:
	return _running


# --- The cape -----------------------------------------------------------------------------------

## The cape: a bell of woven cloth from the neck, over the shoulders and arms, down over the lap, with a
## folds, a band at the neck and a small brass clasp. `model` is the hero's model (turned the way they sit).
static func make_cape() -> Node3D:
	var root := Node3D.new()
	root.name = "BarberCape"
	if _cape_mesh == null:
		_cape_mesh = _bell()
	var cloth := CosyBed.wool(Color(0.93, 0.93, 0.95), 0.1)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = _cape_mesh
	mi.material_override = cloth
	root.add_child(mi)
	var band := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.2
	tube.bottom_radius = 0.21
	tube.height = 0.05
	tube.radial_segments = 20
	band.mesh = tube
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.62, 0.1, 0.1)
	red.roughness = 0.8
	band.material_override = red
	band.position = Vector3(0, 1.04, -0.38)
	root.add_child(band)
	var clasp := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.025
	s.height = 0.05
	clasp.mesh = s
	clasp.material_override = BarberChairModel.brass()
	clasp.position = Vector3(0, 1.02, -0.18)
	root.add_child(clasp)
	return root


## The cape's shape: a lathe over a profile of (radius, height), pushed forward over the lap and
## rippled into folds that deepen towards the hem.
static func _bell() -> ArrayMesh:
	var profile := [Vector2(0.15, 1.06), Vector2(0.19, 1.03), Vector2(0.27, 0.98), Vector2(0.34, 0.88), Vector2(0.4, 0.74),
			Vector2(0.43, 0.64), Vector2(0.45, 0.57), Vector2(0.46, 0.53)]
	var segs := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array = []
	for i in profile.size():
		var t := float(i) / (profile.size() - 1)
		var row: Array = []
		for j in segs + 1:
			var a := TAU * j / segs
			var fold := 1.0 + 0.07 * t * sin(a * 9.0)
			var r: float = profile[i].x * fold
			var fwd := 0.0
			# The front hangs over the lap and the knees, the back over the chair.
			if sin(a) > 0.0:
				fwd = 0.12 * t * sin(a)
			row.append(Vector3(cos(a) * r * 1.12, profile[i].y - 0.1 * t * maxf(0.0, sin(a)) * 0.0, sin(a) * r * 0.9 + fwd))
		ring.append(row)
	for i in profile.size() - 1:
		for j in segs:
			var a: Vector3 = ring[i][j]
			var b: Vector3 = ring[i][j + 1]
			var c: Vector3 = ring[i + 1][j + 1]
			var d: Vector3 = ring[i + 1][j]
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(d)
	st.generate_normals()
	return st.commit()


## Puts the cape round the neck of `player`, fading in; does nothing when it is on.
func wear(player: Player) -> void:
	if cape != null and is_instance_valid(cape):
		return
	cape = make_cape()
	# The cape is made round the hero's seat: the shoulders are 0.4 behind where the feet are put.
	cape.position = Vector3(0, 0, 0)
	player._model.add_child(cape)
	cape.scale = Vector3(0.4, 0.4, 0.4)
	var tween := cape.create_tween()
	tween.tween_property(cape, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Takes the cape off, shrinking away.
func doff() -> void:
	if cape == null or not is_instance_valid(cape):
		cape = null
		return
	var old := cape
	cape = null
	var tween := old.create_tween()
	tween.tween_property(old, "scale", Vector3(0.3, 0.3, 0.3), 0.3)
	tween.tween_callback(old.queue_free)


# --- The cut ------------------------------------------------------------------------------------

## Starts the cut of `new_look`. The hero sits in the chair, Benno stands behind it.
func start(level: Outdoor, new_look: Dictionary) -> void:
	look = new_look
	left = LENGTH
	_running = true
	served = false
	_snip = 0.2
	_chat = 0.8
	_line = _rng.randi() % CHAT.size()
	_colours = hair_colours(level.player.hair.get("color", "natural"))
	_ensure_particles(level)
	_storm.emitting = true
	_burst_now(level)


## The colours the old hair sheds: the root, the middle and the tip, or the colours of the rainbow or of the fire.
static func hair_colours(colour: String) -> Array:
	if colour == "rainbow":
		return [Color(0.95, 0.2, 0.2), Color(1.0, 0.8, 0.2), Color(0.3, 0.85, 0.3), Color(0.25, 0.5, 0.95), Color(0.7, 0.35, 0.9)]
	if colour == "fire":
		return [Color(1.0, 0.25, 0.05), Color(1.0, 0.55, 0.1), Color(1.0, 0.85, 0.3)]
	return (HairLook.COLORS.get(colour, HairLook.COLORS["natural"]) as Array).duplicate()


func _ensure_particles(level: Outdoor) -> void:
	if _storm != null and is_instance_valid(_storm):
		_set_colours(_storm)
		_set_colours(_burst)
		return
	_storm = _make_particles(STORM_RATE * 1.8, 1.8, false)
	_burst = _make_particles(BURST, 1.9, true)
	level.add_child(_storm)
	level.add_child(_burst)
	_set_colours(_storm)
	_set_colours(_burst)


## A fountain of hair: thin little strands that burst out in every direction, tumble and drift down.
func _make_particles(amount: int, lifetime: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "HairStorm" if not one_shot else "HairBurst"
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.95 if one_shot else 0.0
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22
	p.direction = Vector3(0, 0.6, 0)
	p.spread = 180.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -1.3, 0)
	p.damping_min = 1.2
	p.damping_max = 2.4
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	p.tangential_accel_min = -1.5
	p.tangential_accel_max = 1.5
	var quad := QuadMesh.new()
	quad.size = Vector2(0.17, 0.017)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_color = Color.WHITE
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _set_colours(p: CPUParticles3D) -> void:
	var g := Gradient.new()
	var cols: Array = _colours if not _colours.is_empty() else [Color(0.5, 0.3, 0.2)]
	var offsets := PackedFloat32Array()
	var colours := PackedColorArray()
	for i in cols.size():
		offsets.append(0.0 if cols.size() == 1 else float(i) / (cols.size() - 1))
		colours.append((cols[i] as Color).darkened(0.3))
	if cols.size() == 1:
		offsets.append(1.0)
		colours.append((cols[0] as Color).darkened(0.3))
	g.offsets = offsets
	g.colors = colours
	p.color_initial_ramp = g


## Where the hair comes out: the top of the hero's head.
func head_at(level: Outdoor) -> Vector3:
	var slot := HairLook.head_slot(level.player._model)
	if slot != null:
		return slot.global_position + Vector3(0, 0.12, 0)
	return level.player.global_position + Vector3(0, 1.3, -0.4)


func _burst_now(level: Outdoor) -> void:
	_burst.global_position = head_at(level)
	_burst.restart()
	_burst.emitting = true


## One step of the cut: Benno snips, the storm blows, the hair rains down, Benno chats. True once it is over.
func tick(chair: BarberChair, level: Outdoor, delta: float) -> bool:
	if not active():
		return false
	left -= delta
	var at := head_at(level)
	_storm.global_position = at
	_snip -= delta
	if _snip <= 0.0:
		_snip = _rng.randf_range(SNIP_GAP.x, SNIP_GAP.y)
		Sfx.play(level, "snip_%d" % (_rng.randi() % 3), -7.0, at, _rng.randf_range(0.9, 1.15))
		for k in 3:
			_drop_lock(level, at)
	_chat -= delta
	if _chat <= 0.0 and left > 2.0:
		_chat = CHAT_GAP
		if chair.barber != null and is_instance_valid(chair.barber):
			chair.barber.say(Lang.t(CHAT[_line % CHAT.size()]), level.player.global_position, CHAT_GAP - 0.4)
		_line += 1
	return left <= 0.0


## A lock of hair that falls from the head to the floor beside the chair and lies there for a while.
func _drop_lock(level: Outdoor, from: Vector3) -> void:
	var lock := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(_rng.randf_range(0.06, 0.13), 0.004, 0.012)
	lock.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = (_colours[_rng.randi() % _colours.size()] as Color) if not _colours.is_empty() else Color(0.4, 0.2, 0.1)
	mat.roughness = 0.9
	lock.material_override = mat
	level.add_child(lock)
	lock.global_position = from + Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.15, 0.15))
	lock.rotation = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0, TAU), _rng.randf_range(-1, 1))
	var floor_y := level.player.global_position.y + 0.012
	var to := Vector3(from.x + _rng.randf_range(-0.9, 0.9), floor_y, from.z + _rng.randf_range(-0.9, 0.9))
	var fall := _rng.randf_range(1.3, 2.1)
	var tween := lock.create_tween().set_parallel(true)
	tween.tween_property(lock, "global_position:y", floor_y, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(lock, "global_position:x", to.x, fall).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(lock, "global_position:z", to.z, fall).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(lock, "rotation", Vector3(0, lock.rotation.y + _rng.randf_range(-3.0, 3.0), 0), fall)
	_lying.append(lock)
	if _lying.size() > MAX_CLIPPINGS:
		var old = _lying.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var fade := lock.create_tween()
	fade.tween_interval(fall + LIE_TIME + left * 0.0)
	fade.tween_property(lock, "scale", Vector3(0.01, 0.01, 0.01), 1.5)
	fade.tween_callback(lock.queue_free)


## The cut is over (`done`) or broken off because the hero got up: the new look is put on, one more
## flurry of hair, the cape comes off.
func finish(level: Outdoor, chair: BarberChair, done: bool) -> void:
	if not active():
		return
	left = -1.0
	_running = false
	served = true
	if _storm != null and is_instance_valid(_storm):
		_storm.emitting = false
	if _burst != null and is_instance_valid(_burst) and level.player != null:
		_burst_now(level)
	if not look.is_empty():
		level.player.set_hair(look)
	look = {}
	doff()
	var line := Lang.t("Fertig! Schau in den Spiegel: Das bin ich, Benno, der Meister der Schere!") if done \
			else Lang.t("Na gut, dann eben im Stehen. Hier, schon fertig.")
	if chair.barber != null and is_instance_valid(chair.barber):
		chair.barber.say(line, level.player.global_position)
	Events.tell(Lang.t("Schnipp, schnapp! Steht dir gut."), Color(0.95, 0.85, 0.5))
	Sfx.play(level, "snip_%d" % (_rng.randi() % 3), -4.0, level.player.global_position)
