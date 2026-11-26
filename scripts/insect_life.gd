class_name InsectLife
extends Node3D
## The small flying life of the open ground and the sounds that go with it, all of it near the hero only:
##
## * Fireflies drift over the meadows and blink in the dusk and the dark of a summer night (a few late in
##   spring, hardly any early in autumn).
## * Gnats hang in dancing clouds over the water on warm days and at dusk.
## * Butterflies flutter over the grass by day in spring and summer, and now and then settle with raised wings.
##   One mesh carries a body and two wings painted on an atlas of four kinds (see wing_atlas); a vertex shader
##   flaps the wings, so all of them are a single draw.
## * Crickets chirp (a loop of the chorus, see Soundscape, and single chirps from a spot near the hero), strongest
##   in summer nights, thinner in spring, fading through autumn, silent in winter; cicadas drone through the
##   summer day; an owl calls from the dark in the other seasons' nights too (not in winter).
##
## The fireflies, gnats and butterflies are drawn with MultiMeshes and only their handful near the hero are
## moved, every frame (so they stay uninterpolated, see CLAUDE.md "Smooth motion"); with nothing to show the
## node does not even run its frame step.

const WING_SHADER := preload("res://shaders/butterfly.gdshader")
const MAX_FIREFLIES := 48
const MAX_BUTTERFLIES := 14
const SWARMS := 3
const GNATS_PER_SWARM := 14
## Insects farther from the hero than this metres are brought back to him.
const RANGE := 20.0
## The butterflies' kinds on the atlas (two by two tiles): brimstone, peacock, swallowtail and azure blue.
const KINDS := 4
const TILE_PX := 96
## How high (metres) the insects fly over the ground.
const FIREFLY_HEIGHT := Vector2(0.4, 1.9)
const BUTTERFLY_HEIGHT := Vector2(0.5, 1.8)
## Wing span of a butterfly in metres (the mesh is a unit wide).
const SPAN := 0.34
## Where the chirps and the owl sound from (metres from the hero) and how loud (dB).
const CHIRP_DISTANCE := Vector2(3.5, 12.0)
const OWL_DISTANCE := Vector2(14.0, 26.0)
const CHIRP_VOLUME := -17.0
const OWL_VOLUME := -15.0
const OWLS := 2
const CRICKETS := 3

static var _atlas: ImageTexture
static var _glow: ImageTexture
static var _wing_mesh: ArrayMesh

var level: Outdoor
var ponds: Array = []
## How much of each kind is out now (0 to 1), from the season, the hour and the weather (see the level_* functions).
var fireflies_level := 0.0
var gnats_level := 0.0
var butterflies_level := 0.0
var crickets_level := 0.0
var cicadas_level := 0.0
var owl_chance := 0.0

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _since_check := 10.0
var _flies: MultiMeshInstance3D
var _gnat_mmi: MultiMeshInstance3D
var _wings: MultiMeshInstance3D
var _fly: Array[Dictionary] = []
var _swarm: Array[Dictionary] = []
var _bf: Array[Dictionary] = []
var _chirp_in := 4.0
var _owl_in := 30.0


## Hangs the insects on `lvl`, an open-air level with the water tiles `water` (see Outdoor._pond_waters).
static func grow(lvl: Outdoor, water: Array) -> InsectLife:
	var life := InsectLife.new()
	life.name = "InsectLife"
	life.level = lvl
	life.ponds = water
	lvl.add_child(life)
	life._build()
	return life


# --- How much of what is out -------------------------------------------------------------------

## How warm the season is for the insects (0 to 1) on season day `day`: a little in spring, full in summer, going
## out through the autumn, none in winter.
static func warmth(day: int) -> float:
	if Weather.is_winter(day):
		return 0.0
	if Weather.is_autumn(day):
		return lerpf(0.6, 0.05, clampf(float(Weather.autumn_day(day)) / float(Weather.AUTUMN_DAYS - 1), 0.0, 1.0))
	if Weather.is_spring(day):
		return 0.35
	return 1.0


## Whether the sky is dry enough for the insects: not in rain, storm or snow.
static func dry(weather: String) -> bool:
	return weather != Weather.RAIN and weather != Weather.STORM and weather != Weather.SNOW


## 0 in daylight, 1 in the dark of the night (the lamps' glow, see DayNight).
static func darkness(hour: float) -> float:
	return DayNight.glow_at(hour)


## The level of fireflies (0 to 1): only in the dusk and the dark, mostly in summer.
static func level_fireflies(day: int, hour: float, weather: String) -> float:
	if not dry(weather):
		return 0.0
	var season := warmth(day)
	if Weather.is_spring(day):
		season = 0.3
	elif Weather.is_autumn(day):
		season = 0.25 if Weather.autumn_day(day) < 2 else 0.0
	return season * smoothstep(0.35, 0.8, darkness(hour))


static func level_gnats(day: int, hour: float, weather: String) -> float:
	if not dry(weather):
		return 0.0
	return warmth(day) * (1.0 - 0.8 * smoothstep(0.5, 1.0, darkness(hour)))


static func level_butterflies(day: int, hour: float, weather: String) -> float:
	if not dry(weather) or Weather.is_winter(day):
		return 0.0
	var season := 1.0 if not Weather.is_spring(day) and not Weather.is_autumn(day) else (0.6 if Weather.is_spring(day) else (0.3 if Weather.autumn_day(day) < 2 else 0.0))
	return season * (1.0 - smoothstep(0.0, 0.5, darkness(hour))) * smoothstep(7.5, 10.5, hour) * (1.0 - smoothstep(17.0, 19.5, hour))


## The strength of the cricket chorus (also played by Soundscape): the whole night through, a little by day.
static func level_crickets(day: int, hour: float, weather: String) -> float:
	var rain := 0.0 if dry(weather) else 0.8
	return warmth(day) * (0.12 + 0.88 * darkness(hour)) * (1.0 - rain)


## The strength of the cicadas' drone (played by Soundscape): the sunny hours of the summer.
static func level_cicadas(day: int, hour: float, weather: String) -> float:
	if not dry(weather) or Weather.is_winter(day) or Weather.is_spring(day) or Weather.is_autumn(day):
		return 0.0
	return smoothstep(9.0, 12.0, hour) * (1.0 - smoothstep(17.0, 20.0, hour)) * (1.0 - darkness(hour))


## The chance (0 to 1) that the owl is about: the nights of every season but winter.
static func level_owl(day: int, hour: float, weather: String) -> float:
	if Weather.is_winter(day) or not dry(weather):
		return 0.0
	return smoothstep(0.5, 0.9, darkness(hour))


# --- Pictures ----------------------------------------------------------------------------------

## A soft round glow, white in the middle, for the fireflies and (tinted dark) the gnats.
static func glow_texture() -> ImageTexture:
	if _glow == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				var core := clampf(1.0 - d * 2.6, 0.0, 1.0)
				var halo := pow(clampf(1.0 - d, 0.0, 1.0), 2.2) * 0.55
				img.set_pixel(x, y, Color(1, 1, 1, clampf(core + halo, 0.0, 1.0)))
		_glow = ImageTexture.create_from_image(img)
	return _glow


## How far (u across from the hinge, v down from the front at -1 to 1) a point of a right wing lies inside its
## outline: below 1 inside, above 1 outside. The hinge is the left edge's middle.
static func wing_shape(u: float, v: float) -> float:
	# A big fore wing above the hinge's line and a rounder hind wing below it.
	var fore := Vector2((u - 0.5) / 0.52, (v + 0.4) / 0.5).length()
	var hind := Vector2((u - 0.42) / 0.4, (v - 0.4) / 0.46).length()
	return minf(fore, hind)


## The four butterflies painted on one atlas, two by two tiles of TILE_PX pixels: base colour with a darker fade towards
## the edge, veins from the hinge, a dark border with pale dots, and the peacock's eye spots. Alpha cuts the outline.
static func wing_atlas() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var img := Image.create(TILE_PX * 2, TILE_PX * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base := [Color(0.97, 0.88, 0.25), Color(0.72, 0.16, 0.1), Color(0.96, 0.85, 0.35), Color(0.33, 0.55, 0.9)]
	var edge := [Color(0.82, 0.62, 0.12), Color(0.35, 0.07, 0.06), Color(0.1, 0.08, 0.06), Color(0.13, 0.2, 0.42)]
	for kind in KINDS:
		var ox := (kind % 2) * TILE_PX
		var oy := (kind / 2) * TILE_PX
		for py in TILE_PX:
			for px in TILE_PX:
				var u := (px + 0.5) / TILE_PX
				var v := (py + 0.5) / TILE_PX * 2.0 - 1.0
				var r := wing_shape(u, v)
				if r >= 1.0:
					continue
				var col: Color = (base[kind] as Color).lerp(edge[kind], smoothstep(0.35, 1.0, r) * 0.8)
				# Veins: thin dark lines fanning out of the hinge.
				var ang := atan2(v, u + 0.02)
				var vein := 1.0 - smoothstep(0.0, 0.05, absf(sin(ang * 9.0)) * (0.6 + u) - 0.06)
				col = col.darkened(vein * 0.22 * smoothstep(0.1, 0.5, u))
				# A dark border with pale dots.
				var border := smoothstep(0.8, 0.93, r)
				if kind == 0:
					border *= 0.4
				col = col.lerp(Color(0.07, 0.05, 0.05), border * (0.9 if kind != 2 else 0.7))
				var dots := smoothstep(0.55, 0.8, sin(ang * 26.0)) * smoothstep(0.8, 0.84, r) * (1.0 - smoothstep(0.88, 0.92, r))
				col = col.lerp(Color(0.96, 0.94, 0.85), dots * (0.9 if kind in [1, 3] else 0.4))
				if kind == 1:
					# The peacock's eye on each wing: blue ring, black ring, a pale pupil.
					for eye: Vector3 in [Vector3(0.74, -0.55, 0.1), Vector3(0.62, 0.55, 0.075)]:
						var d := Vector2(u - eye.x, (v - eye.y) * 0.5).length() / eye.z
						if d < 1.0:
							col = Color(0.95, 0.9, 0.7) if d < 0.3 else (Color(0.08, 0.1, 0.45) if d < 0.62 else Color(0.05, 0.04, 0.04))
				if kind == 2:
					# The swallowtail's black stripes and its blue and red hind-wing spots.
					col = col.lerp(Color(0.06, 0.05, 0.05), smoothstep(0.6, 0.9, sin(u * 17.0 + v * 2.0)) * 0.8 * smoothstep(0.1, 0.4, u))
					if Vector2(u - 0.55, v - 0.62).length() < 0.07:
						col = Color(0.88, 0.24, 0.12)
				if kind == 3:
					# The azure blue's silvery sheen near the body.
					col = col.lerp(Color(0.7, 0.85, 1.0), (1.0 - smoothstep(0.0, 0.5, r)) * 0.5)
				var s := 1.0 - smoothstep(0.96, 1.0, r)
				img.set_pixel(ox + px, oy + py, Color(col.r, col.g, col.b, s))
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


## The butterfly mesh, one unit wide: two wings (four strips each, so they can curve) lying flat to the sides of a thin
## body with a head and two antennae along -z (the front). Vertex colour green marks the body (see butterfly.gdshader).
static func wing_mesh() -> ArrayMesh:
	if _wing_mesh != null:
		return _wing_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 0.5
	var strips := 4
	var depth := 0.62
	for side in [1.0, -1.0]:
		for i in strips:
			var x0 := half * float(i) / strips
			var x1 := half * float(i + 1) / strips
			# UV: u from the hinge outwards (0 to 1), v down the wing; on the left side the picture is mirrored.
			var corners := [[x0, -depth / 2.0, 0.0], [x1, -depth / 2.0, 0.0], [x1, depth / 2.0, 0.0], [x0, depth / 2.0, 0.0]]
			var order := [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
			for k in order:
				var c: Array = corners[k]
				var u := float(c[0]) / half
				var vv := (float(c[1]) / depth) + 0.5
				st.set_color(Color(1, 0, 0, 1))
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(u, vv))
				st.add_vertex(Vector3(float(c[0]) * side, 0.0, float(c[1]) - 0.0))
	# The body: two crossed strips and a head; the antennae are thin triangles.
	var body := [
		[Vector3(-0.012, 0.0, -0.22), Vector3(0.012, 0.0, -0.22), Vector3(0.016, 0.0, 0.25), Vector3(-0.016, 0.0, 0.25)],
		[Vector3(0.0, -0.014, -0.22), Vector3(0.0, 0.014, -0.22), Vector3(0.0, 0.018, 0.25), Vector3(0.0, -0.018, 0.25)],
	]
	for quad: Array in body:
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(0, 1, 0, 1))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(quad[k])
	for s in [1.0, -1.0]:
		for p in [Vector3(0.0, 0.0, -0.22), Vector3(0.012 * s, 0.0, -0.22), Vector3(0.05 * s, 0.03, -0.33)]:
			st.set_color(Color(0, 1, 0, 1))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(p)
	_wing_mesh = st.commit()
	return _wing_mesh


func _build() -> void:
	_rng.seed = hash(level.level_name + "insekten")
	_flies = _blob_instances(MAX_FIREFLIES, 0.34, true)
	_gnat_mmi = _blob_instances(SWARMS * GNATS_PER_SWARM, 0.075, false)
	for i in MAX_FIREFLIES:
		_fly.append({"home": Vector3.ZERO, "h": _rng.randf_range(FIREFLY_HEIGHT.x, FIREFLY_HEIGHT.y), "phase": _rng.randf() * TAU,
				"rate": _rng.randf_range(0.28, 0.5), "tint": _rng.randf()})
	for i in SWARMS * GNATS_PER_SWARM:
		_swarm.append({"phase": _rng.randf() * TAU, "rad": _rng.randf_range(0.2, 0.7), "rate": _rng.randf_range(1.5, 3.8),
				"up": _rng.randf_range(0.5, 1.6)})
	_swarm_centres = []
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = wing_mesh()
	mm.instance_count = MAX_BUTTERFLIES
	mm.custom_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 12, 120))
	_wings = MultiMeshInstance3D.new()
	_wings.name = "Butterflies"
	_wings.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = WING_SHADER
	mat.set_shader_parameter("wings", wing_atlas())
	_wings.material_override = mat
	_wings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wings)
	for i in MAX_BUTTERFLIES:
		_bf.append({"pos": Vector3.ZERO, "to": Vector3.ZERO, "heading": _rng.randf() * TAU, "kind": i % KINDS, "phase": _rng.randf() * TAU,
				"speed": _rng.randf_range(1.0, 1.9), "state": "fly", "wait": 0.0, "size": _rng.randf_range(0.8, 1.2), "bob": _rng.randf() * TAU,
				"pace": _rng.randf_range(22.0, 30.0), "lift": 0.0})
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, -100, 0)))
	_flies.visible = false
	_gnat_mmi.visible = false
	_wings.visible = false
	set_process(true)


## A MultiMesh of `count` billboard quads of `size` metres with the glow texture: bright and additive for the
## fireflies, soft and dark for the gnats.
func _blob_instances(count: int, size: float, bright: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if bright else BaseMaterial3D.BLEND_MODE_MIX
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_texture = glow_texture()
	mat.no_depth_test = false
	mat.disable_receive_shadows = true
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = count
	mm.custom_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 12, 120))
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, -100, 0)))
		mm.set_instance_color(i, Color(1, 1, 1, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


var _swarm_centres: Array[Vector3] = []


# --- The frame step ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if level == null or level.player == null:
		return
	_t += delta
	_since_check += delta
	if _since_check >= 0.5:
		_since_check = 0.0
		_refresh()
	var hero: Vector3 = (level.player as Node3D).global_position
	var surface: bool = hero.y >= Outdoor.UNDERGROUND_Y and not level.is_roofed(hero)
	_flies.visible = fireflies_level > 0.01 and surface
	_gnat_mmi.visible = gnats_level > 0.01 and surface and not _swarm_centres.is_empty()
	_wings.visible = butterflies_level > 0.01 and surface
	if _flies.visible:
		_step_fireflies(delta, hero)
	if _gnat_mmi.visible:
		_step_gnats(hero)
	if _wings.visible:
		_step_butterflies(delta, hero)
	if surface:
		_step_sounds(delta, hero)


## The levels for the season, hour and weather of the world now.
func _refresh() -> void:
	var hour := level.hour if level.hour >= 0.0 else 12.0
	fireflies_level = level_fireflies(level.season_day, hour, level.weather)
	gnats_level = level_gnats(level.season_day, hour, level.weather)
	butterflies_level = level_butterflies(level.season_day, hour, level.weather)
	crickets_level = level_crickets(level.season_day, hour, level.weather)
	cicadas_level = level_cicadas(level.season_day, hour, level.weather)
	owl_chance = level_owl(level.season_day, hour, level.weather)
	if gnats_level > 0.01 and level.player != null:
		_pick_swarms((level.player as Node3D).global_position)


## A meadow spot between `near` and `far` metres from `hero`: open ground, no roof; Vector3.INF when there is none.
func _meadow_near(hero: Vector3, near: float, far: float) -> Vector3:
	for i in 8:
		var a := _rng.randf() * TAU
		var p := hero + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(near, far)
		p.y = 0.0
		var cell := level.world_to_cell(p)
		if level.is_open(cell) and level.cell_char(cell) == "." and not level.is_roofed(p) and level.pond_shore_at(p) < 0.2:
			return p
	return Vector3.INF


func _step_fireflies(delta: float, hero: Vector3) -> void:
	var mm := _flies.multimesh
	var shown := int(ceil(MAX_FIREFLIES * fireflies_level))
	for i in MAX_FIREFLIES:
		var f: Dictionary = _fly[i]
		var home: Vector3 = f.home
		if i >= shown:
			mm.set_instance_color(i, Color(1, 1, 1, 0))
			continue
		if Vector2(home.x - hero.x, home.z - hero.z).length() > RANGE or home == Vector3.ZERO:
			var p := _meadow_near(hero, 2.0, RANGE - 2.0)
			if p == Vector3.INF:
				mm.set_instance_color(i, Color(1, 1, 1, 0))
				continue
			f.home = p
			home = p
		var ph: float = f.phase
		var drift := Vector3(sin(_t * 0.7 + ph) * 1.1 + sin(_t * 1.9 + ph * 2.0) * 0.25, sin(_t * 1.3 + ph) * 0.25, cos(_t * 0.55 + ph * 1.7) * 1.1)
		var at := Vector3(home.x, float(f.h), home.z) + drift
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		# A blink: it lights up quickly, glows and fades, then rests until the next one.
		var cycle := fmod(_t * float(f.rate) + ph / TAU, 1.0)
		var glow := smoothstep(0.0, 0.08, cycle) * (1.0 - smoothstep(0.1, 0.3, cycle))
		var tint := Color(0.78, 1.0, 0.3).lerp(Color(1.0, 0.95, 0.4), float(f.tint))
		mm.set_instance_color(i, Color(tint.r, tint.g, tint.b, glow * minf(1.0, fireflies_level * 1.6)))


## Up to SWARMS spots of water near the hero, where the gnats hang (a metre over the water's edge).
func _pick_swarms(hero: Vector3) -> void:
	var best: Array[Vector3] = []
	var dist: Array[float] = []
	for w: Dictionary in ponds:
		var p: Vector3 = w.pos
		var d := Vector2(p.x - hero.x, p.z - hero.z).length()
		if d > RANGE * 1.4:
			continue
		# Not on top of another swarm.
		var crowded := false
		for b in best:
			if Vector2(b.x - p.x, b.z - p.z).length() < 6.0:
				crowded = true
				break
		if crowded:
			continue
		best.append(p)
		dist.append(d)
	var order := range(best.size())
	order.sort_custom(func(a: int, b: int) -> bool: return dist[a] < dist[b])
	_swarm_centres = []
	for k in mini(SWARMS, order.size()):
		_swarm_centres.append(best[order[k]])


func _step_gnats(_hero: Vector3) -> void:
	var mm := _gnat_mmi.multimesh
	for i in SWARMS * GNATS_PER_SWARM:
		var s := i / GNATS_PER_SWARM
		if s >= _swarm_centres.size():
			mm.set_instance_color(i, Color(1, 1, 1, 0))
			continue
		var g: Dictionary = _swarm[i]
		var c: Vector3 = _swarm_centres[s]
		var a: float = _t * float(g.rate) + float(g.phase)
		var r: float = float(g.rad) * (0.8 + 0.5 * sin(_t * 0.9 + float(g.phase) * 3.0))
		var at := Vector3(c.x + cos(a) * r + sin(_t * 0.4 + s) * 0.4, 0.5 + float(g.up) + sin(a * 1.7) * 0.3, c.z + sin(a * 1.3) * r)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		mm.set_instance_color(i, Color(0.09, 0.08, 0.07, 0.75 * minf(1.0, gnats_level * 1.5)))


func _step_butterflies(delta: float, hero: Vector3) -> void:
	var mm := _wings.multimesh
	var shown := int(ceil(MAX_BUTTERFLIES * butterflies_level))
	for i in MAX_BUTTERFLIES:
		var b: Dictionary = _bf[i]
		var pos: Vector3 = b.pos
		if i >= shown:
			if pos != Vector3.ZERO:
				b.pos = Vector3.ZERO
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, -100, 0)))
			continue
		if pos == Vector3.ZERO or Vector2(pos.x - hero.x, pos.z - hero.z).length() > RANGE + 4.0:
			var p := _meadow_near(hero, 4.0, RANGE - 3.0)
			if p == Vector3.INF:
				continue
			p.y = _rng.randf_range(BUTTERFLY_HEIGHT.x, BUTTERFLY_HEIGHT.y)
			b.pos = p
			b.to = p
			b.state = "fly"
			b.wait = 0.0
			pos = p
		b.bob += delta * 6.0
		var open := 0.0
		match b.state:
			"fly", "land":
				b.wait -= delta
				var to: Vector3 = b.to
				var flat := Vector3(to.x - pos.x, 0, to.z - pos.z)
				if b.state == "fly" and (b.wait <= 0.0 or flat.length() < 0.5):
					_butterfly_choose(b, hero)
					to = b.to
					flat = Vector3(to.x - pos.x, 0, to.z - pos.z)
				var want := atan2(flat.x, flat.z)
				b.heading = lerp_angle(b.heading, want, minf(1.0, 2.6 * delta))
				var dir := Vector3(sin(b.heading), 0, cos(b.heading))
				pos += dir * float(b.speed) * delta
				# It bobs up and down with the wing beats and drifts to the height it wants.
				pos.y = move_toward(pos.y, to.y, 0.6 * delta) + sin(b.bob) * 0.012
				if b.state == "land" and flat.length() < 0.2:
					b.state = "rest"
					b.wait = _rng.randf_range(3.0, 7.0)
				open = 1.0
			"rest":
				b.wait -= delta
				pos.y = move_toward(pos.y, 0.12, 0.8 * delta)
				open = 0.0
				if b.wait <= 0.0:
					b.state = "fly"
					b.wait = 0.0
		b.pos = pos
		# Resting, the wings stand up together and open and close slowly; flying, they beat.
		var basis := Basis(Vector3.UP, float(b.heading) + PI).scaled(Vector3.ONE * SPAN * float(b.size))
		basis = basis * Basis(Vector3.RIGHT, -0.15 if open > 0.5 else 0.0)
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var rate: float = float(b.pace) if open > 0.5 else 1.4
		mm.set_instance_custom_data(i, Color(float(b.kind), float(b.phase), rate, 1.0 if open > 0.5 else 1.25))


## A butterfly's next leg: a meadow spot 2 to 7 metres away (towards a flower bed now and then), or it settles there.
func _butterfly_choose(b: Dictionary, hero: Vector3) -> void:
	var pos: Vector3 = b.pos
	var p := _meadow_near(pos, 2.0, 7.0)
	if p == Vector3.INF or Vector2(p.x - hero.x, p.z - hero.z).length() > RANGE:
		p = Vector3(hero.x, 0, hero.z) + (Vector3(pos.x - hero.x, 0, pos.z - hero.z) * -0.4)
	if not level.bed_spots.is_empty() and _rng.randf() < 0.3:
		var bed: Vector3 = level.bed_spots[_rng.randi() % level.bed_spots.size()]
		if Vector2(bed.x - hero.x, bed.z - hero.z).length() < RANGE:
			p = bed
	b.wait = _rng.randf_range(1.2, 3.2)
	if _rng.randf() < 0.18:
		p.y = 0.12
		b.state = "land"
	else:
		p.y = _rng.randf_range(BUTTERFLY_HEIGHT.x, BUTTERFLY_HEIGHT.y)
	b.to = p
	b.speed = _rng.randf_range(0.9, 1.9)


# --- Sounds --------------------------------------------------------------------------------------

## The single chirps near the hero and the owl far off (the loops are Soundscape's).
func _step_sounds(delta: float, hero: Vector3) -> void:
	if crickets_level > 0.15:
		_chirp_in -= delta
		if _chirp_in <= 0.0:
			_chirp_in = _rng.randf_range(2.5, 8.0) / crickets_level
			var a := _rng.randf() * TAU
			var d := _rng.randf_range(CHIRP_DISTANCE.x, CHIRP_DISTANCE.y)
			Sfx.play_3d(self, "cricket_%d" % (_rng.randi() % CRICKETS), CHIRP_VOLUME + linear_to_db(crickets_level) - d * 0.5,
					hero + Vector3(cos(a), 0, sin(a)) * d, _rng.randf_range(0.9, 1.12))
	if owl_chance > 0.5:
		_owl_in -= delta
		if _owl_in <= 0.0:
			_owl_in = _rng.randf_range(30.0, 90.0)
			var a := _rng.randf() * TAU
			var d := _rng.randf_range(OWL_DISTANCE.x, OWL_DISTANCE.y)
			Sfx.play_3d(self, "owl_%d" % (_rng.randi() % OWLS), OWL_VOLUME - d * 0.25, hero + Vector3(cos(a), 0, sin(a)) * d, _rng.randf_range(0.95, 1.05))
