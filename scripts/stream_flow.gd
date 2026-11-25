class_name StreamFlow
extends Node3D
## Things drifting along a stretch of water: leaves, foam, bits of rubbish. They move at the pace of the
## current from one end of the stretch to the other, fade in and out at the ends and start over, so a
## stream or a channel visibly flows (the ground's water itself is a still picture). One MultiMesh, one
## draw call; the bits are flat on the surface and moved every frame (not physics bodies, see CLAUDE.md
## "Smooth motion": nothing here is interpolated).
##
## `from` and `to` are the middle line of the stretch (the surface height is `from.y`), `width` how far
## across it the bits spread, `kinds` the colours the bits take.

const LEAVES := [Color(0.62, 0.36, 0.12), Color(0.5, 0.3, 0.1), Color(0.42, 0.45, 0.14), Color(0.7, 0.5, 0.15)]
## Seasonal leaves of a river (see `seasonal`): the green ones of spring and summer, and the sticks the water
## now and then brings down. In autumn the leaves take the trees' autumn colours (IvySeasons.AUTUMN_COLOURS).
const GREEN_LEAVES := [Color(0.28, 0.42, 0.14), Color(0.36, 0.5, 0.16), Color(0.22, 0.36, 0.12), Color(0.42, 0.5, 0.2)]
const STICKS := [Color(0.3, 0.22, 0.14), Color(0.38, 0.28, 0.18), Color(0.26, 0.2, 0.12)]
## One stick for this many leaves (at least two sticks), and the share of the leaves that float in spring
## and summer; in winter there are none.
const STICK_EVERY := 8
const GREEN_SHARE := 0.5
const FOAM := [Color(0.62, 0.66, 0.62), Color(0.56, 0.6, 0.58)]
const RUBBISH := [Color(0.34, 0.26, 0.16), Color(0.45, 0.4, 0.3), Color(0.27, 0.3, 0.2), Color(0.55, 0.5, 0.4), Color(0.3, 0.22, 0.14)]
## How far from each end the bits fade (fraction of the length).
const FADE := 0.08
## The colour the bits turn once snow lies on them, and the snow cover (0 to 1, see Outdoor.set_snow)
## at which they start to turn and are fully white.
const SNOWY := Color(0.93, 0.96, 1.0)
const SNOW_FROM := 0.1
const SNOW_FULL := 0.8
## Group of every stream, so the weather can find them (see set_snow).
const GROUP := "stream_flow"

var from := Vector3.ZERO
var to := Vector3.ZERO
var width := 3.0
var speed := 0.5
var count := 60
var palette: Array = LEAVES
## Every `foam_every`-th bit is a long streak of foam instead.
var foam_every := 4
## Whether the bits are small bits of rubbish (bigger, squarer) instead of leaves.
var rubbish := false
## Leaves are real leaves (the ground leaves' shape and texture) that follow the season (see set_season)
## and are joined by a few sticks, instead of plain coloured bits.
var seasonal := false
## The bits are thin sticks (a rubbish flow of its own, see seasonal).
var stick := false

var _mm: MultiMesh
var _phase: Array[float] = []
var _across: Array[float] = []
var _size: Array[Vector2] = []
var _spin: Array[float] = []
var _wobble: Array[float] = []
var _time := 0.0
var _colours: Array[Color] = []
var _snowed := 0.0
var _sticks: StreamFlow
var _shown := 1.0


## One bit as a pointed oval lying flat on the water, one metre long (along z) and wide before it is scaled: a leaf,
## a streak of foam or a bit of bark. (A plain square would read as a floating square, not as a leaf.)
static func bit_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var steps := 8
	for i in steps:
		var a := float(i) / steps
		var b := float(i + 1) / steps
		var wa := 0.5 * pow(maxf(sin(PI * a), 0.0), 0.8)
		var wb := 0.5 * pow(maxf(sin(PI * b), 0.0), 0.8)
		var p0 := Vector3(-wa, 0, a - 0.5)
		var p1 := Vector3(wa, 0, a - 0.5)
		var p2 := Vector3(-wb, 0, b - 0.5)
		var p3 := Vector3(wb, 0, b - 0.5)
		for v: Vector3 in [p0, p2, p1, p1, p2, p3]:
			st.add_vertex(v)
	return st.commit()


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [from, to, count])
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = bit_mesh()
	_mm.instance_count = count
	for i in count:
		_phase.append(rng.randf())
		_across.append(rng.randf_range(-0.5, 0.5))
		_spin.append(rng.randf_range(-0.6, 0.6))
		_wobble.append(rng.randf() * TAU)
		var streak := foam_every > 0 and i % foam_every == 0
		if streak:
			_size.append(Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.08, 0.14)))
			_mm.set_instance_color(i, FOAM[rng.randi() % FOAM.size()])
		elif stick:
			_size.append(Vector2(rng.randf_range(0.45, 0.8), rng.randf_range(0.03, 0.05)))
			_mm.set_instance_color(i, palette[rng.randi() % palette.size()])
		elif rubbish:
			_size.append(Vector2(rng.randf_range(0.14, 0.36), rng.randf_range(0.1, 0.26)))
			_mm.set_instance_color(i, palette[rng.randi() % palette.size()])
		elif seasonal:
			_size.append(Vector2(rng.randf_range(0.26, 0.38), rng.randf_range(0.24, 0.34)))
			_mm.set_instance_color(i, palette[rng.randi() % palette.size()])
		else:
			_size.append(Vector2(rng.randf_range(0.16, 0.3), rng.randf_range(0.1, 0.18)))
			_mm.set_instance_color(i, palette[rng.randi() % palette.size()])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if seasonal:
		# The ground leaves' look: the five-lobed leaf of the ivy, cut out of a flat quad.
		var quad := QuadMesh.new()
		quad.orientation = PlaneMesh.FACE_Y
		_mm.mesh = quad
		mat.albedo_texture = AgedStone.leaf_material().albedo_texture
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	add_child(mi)
	for i in count:
		_colours.append(_mm.get_instance_color(i))
	add_to_group(GROUP)
	if seasonal:
		_sticks = StreamFlow.new()
		_sticks.name = "Sticks"
		_sticks.from = from
		_sticks.to = to
		_sticks.width = width
		_sticks.speed = speed
		_sticks.count = maxi(2, count / STICK_EVERY)
		_sticks.foam_every = 0
		_sticks.rubbish = true
		_sticks.stick = true
		_sticks.palette = STICKS
		add_child(_sticks)
		var world_now := get_parent() as Outdoor
		set_season(world_now.season_day if world_now != null else 0)
	# Built into a world where snow already lies: the bits are white from the start.
	var world := get_parent() as Outdoor
	if world != null and world.snow != null:
		set_snow(world.snow.amount)
	_place()


## Snow settles on the leaves and rubbish floating by: they turn white as the cover builds up and
## take their colours back as it melts away. `cover` is the snow on the open air, 0 to 1.
func set_snow(cover: float) -> void:
	if _sticks != null:
		_sticks.set_snow(cover)
	var white := smoothstep(SNOW_FROM, SNOW_FULL, cover)
	if _mm == null or absf(white - _snowed) < 0.01:
		return
	_snowed = white
	for i in count:
		_mm.set_instance_color(i, _colours[i].lerp(SNOWY, white))


## The season's leaves (seasonal flows only): the autumn colours in autumn, green in spring and summer,
## fewer of them than in autumn, and none in winter, when only the odd stick drifts by.
func set_season(day: int) -> void:
	if not seasonal or _mm == null:
		return
	var autumn := Weather.is_autumn(day)
	var colours: Array = IvySeasons.AUTUMN_COLOURS if autumn else GREEN_LEAVES
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|blaetter" % [from, to])
	for i in count:
		var c: Color = colours[rng.randi() % colours.size()] * rng.randf_range(0.8, 1.05)
		c.a = 1.0
		_colours[i] = c
	_shown = 0.0 if Weather.is_winter(day) else (1.0 if autumn else GREEN_SHARE)
	_mm.visible_instance_count = int(round(count * _shown))
	_snowed = -1.0
	var world := get_parent() as Outdoor
	set_snow(world.snow.amount if world != null and world.snow != null else 0.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_place()


## Puts every bit where it is `_time` seconds into its journey.
func _place() -> void:
	var line := to - from
	var length := line.length()
	if length < 0.01 or _mm == null:
		return
	var along := line / length
	var side := Vector3(-along.z, 0, along.x)
	var angle := atan2(along.x, along.z)
	for i in count:
		var t := fposmod(_phase[i] + _time * speed / length, 1.0)
		var fade := smoothstep(0.0, FADE, t) * smoothstep(1.0, 1.0 - FADE, t)
		var sway := sin(_time * 0.7 + _wobble[i]) * 0.12
		var at := from + along * (t * length) + side * (_across[i] * width + sway)
		var turn := angle + _spin[i] * sin(_time * 0.5 + _wobble[i]) + (0.0 if foam_every > 0 and i % foam_every == 0 else _spin[i])
		var basis := Basis(Vector3.UP, turn) * Basis.from_scale(Vector3(_size[i].y, 1.0, _size[i].x) * fade)
		_mm.set_instance_transform(i, Transform3D(basis, at))
