class_name MealBraziers
extends RefCounted
## In winter four iron braziers stand round the dining tables on the village
## square (see TownMeals) to warm the guests: a bowl of glowing coals on three
## legs, small flames and embers rising, a thin curl of smoke, and a warm light
## over the benches. They burn day and night all winter and are gone the rest of
## the year (set_winter; Outdoor.set_winter_wear calls it when winter comes and goes).
##
## They stand at the ends of the tables, between the canopy posts, so they warm
## the seats at both ends of each table and never stand in anyone's way: a table's
## tile is blocked, so nobody walks through the ends of it, and the nearest paths
## (along the next tile's middle, WalkRules.JITTER off at most) pass well clear.
## The hero walks round them (a box that is only solid while they burn).
##
## Their lights are out in the open, so they never cast shadows and take no slot
## of LightShadows' budget. Snow does not settle round them (Outdoor.warm_spots).

## Where a brazier stands: this far from its table's middle, along the table (metres).
const END := 2.45
## The brazier: how tall its rim stands, the bowl's radius at the rim and at its
## foot, and how far its three legs reach out.
const RIM := 0.95
const BOWL := Vector2(0.34, 0.18)
const BOWL_DEEP := 0.24
const LEG_REACH := 0.3
## The coals: their colours (dark to glowing) and how brightly they glow.
const COALS := [Color(0.95, 0.32, 0.06), Color(0.8, 0.18, 0.04), Color(0.3, 0.08, 0.04), Color(1.0, 0.55, 0.12)]
const COAL_GLOW := 2.2
## The light over each brazier: by day and at night, its colour and reach.
const LIGHT_DAY := 0.8
const LIGHT_NIGHT := 2.2
const LIGHT_RANGE := 6.0
const LIGHT_COLOUR := Color(1.0, 0.55, 0.24)

## The braziers' feet (world positions).
var spots: Array[Vector3] = []
## Whether they burn now (winter).
var burning := false
var lights: Array[OmniLight3D] = []
var _nodes: Array[Node3D] = []
var _solids: Array[CollisionShape3D] = []
var _fires: Array[CPUParticles3D] = []
var _glow := 0.0


## Where the braziers stand round `tables` (world positions): at both ends of the
## first and the last table (four for the square's two tables), along the tables' line.
static func places(tables: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if tables.is_empty():
		return out
	var ends: Array = [tables[0]] if tables.size() == 1 else [tables[0], tables[-1]]
	for t: Vector3 in ends:
		for side in [-1.0, 1.0]:
			out.append(t + Vector3(side * END, 0, 0))
	return out


## Builds the braziers round `tables` on `level` (hidden until winter, see set_winter).
func build(level: Node3D, tables: Array) -> void:
	spots = places(tables)
	var coal_mat := StandardMaterial3D.new()
	coal_mat.vertex_color_use_as_albedo = true
	coal_mat.roughness = 0.9
	coal_mat.emission_enabled = true
	coal_mat.emission = Color(1.0, 0.36, 0.08)
	coal_mat.emission_energy_multiplier = COAL_GLOW
	for i in spots.size():
		var at := spots[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("brazier|%s" % at)
		var node := Node3D.new()
		node.name = "Brazier"
		node.position = at
		node.visible = false
		level.add_child(node)
		_frame(node, rng)
		node.add_child(_coals(rng, coal_mat))
		var flame := Effects.make_flame()
		flame.position = Vector3(0, RIM + 0.08, 0)
		flame.scale = Vector3.ONE * 1.5
		flame.emitting = false
		node.add_child(flame)
		var embers := Effects.make_forge_embers()
		embers.name = "Embers"
		embers.amount = 8
		embers.emission_box_extents = Vector3(BOWL.x * 0.6, 0.02, BOWL.x * 0.6)
		embers.position = Vector3(0, RIM + 0.05, 0)
		embers.emitting = false
		node.add_child(embers)
		var smoke := ChimneySmoke.make()
		smoke.amount = 8
		smoke.lifetime = 3.2
		smoke.scale_amount_min = 0.35
		smoke.scale_amount_max = 0.55
		smoke.position = Vector3(0, RIM + 0.45, 0)
		smoke.emitting = false
		node.add_child(smoke)
		_fires.append_array([flame, embers, smoke])
		var light := OmniLight3D.new()
		light.name = "BrazierLight"
		light.light_color = LIGHT_COLOUR
		light.light_energy = LIGHT_DAY
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.5
		light.position = Vector3(0, RIM + 0.7, 0)
		light.visible = false
		# Out in the open: no wall for it to stop at, so it takes no shadow-casting slot.
		light.set_meta(LightShadows.NO_SHADOW, true)
		node.add_child(light)
		lights.append(light)
		_nodes.append(node)
		var solid: CollisionShape3D = level._add_box(level._walls_body, at + Vector3(0, RIM * 0.5, 0), Vector3(BOWL.x * 2.0, RIM, BOWL.x * 2.0))
		solid.disabled = true
		_solids.append(solid)
		# No snow round the fire, burning or not: the warm spots are fixed when the village is built.
		if "warm_spots" in level:
			level.warm_spots.append(Vector4(at.x, RIM, at.z, 1.4))


## The iron: three legs bowed out from under the bowl, a ring tying them, the bowl and its rim.
func _frame(node: Node3D, rng: RandomNumberGenerator) -> void:
	var b := WeatheredProps.Builder.new()
	var iron := WeatheredProps.IRON_COLOUR
	var dark := iron * 0.7
	var turn := rng.randf() * TAU
	for k in 3:
		var a := turn + TAU * k / 3.0
		var out := Vector3(cos(a), 0, sin(a))
		var foot := out * LEG_REACH
		var knee := out * (LEG_REACH * 0.7) + Vector3(0, RIM * 0.45, 0)
		var top := out * (BOWL.y * 0.9) + Vector3(0, RIM - BOWL_DEEP + 0.02, 0)
		b.bar(foot, knee, 0.025, iron, WeatheredProps.IRON, 5)
		b.bar(knee, top, 0.025, iron, WeatheredProps.IRON, 5)
		b.cylinder(foot, 0.05, 0.04, 0.03, dark, WeatheredProps.IRON, 6)
	# A ring round the legs halfway up.
	b.cylinder(Vector3(0, RIM * 0.42, 0), LEG_REACH * 0.72, LEG_REACH * 0.72, 0.03, dark, WeatheredProps.IRON, 12, Basis(), false)
	# The bowl, open at the top, and a thick rim.
	b.cylinder(Vector3(0, RIM - BOWL_DEEP, 0), BOWL.y, BOWL.x, BOWL_DEEP, iron, WeatheredProps.IRON, 12, Basis(), false)
	b.cylinder(Vector3(0, RIM - BOWL_DEEP, 0), BOWL.y * 0.98, BOWL.y * 0.98, 0.01, dark, WeatheredProps.IRON, 12)
	b.cylinder(Vector3(0, RIM - 0.03, 0), BOWL.x + 0.03, BOWL.x + 0.03, 0.04, dark, WeatheredProps.IRON, 12, Basis(), false)
	var frame := b.finish(node, Vector3.ZERO, false)
	frame.name = "Iron"
	frame.set_meta("no_snow", true)


## The heap of coals in the bowl: lumps glowing orange and dark.
func _coals(rng: RandomNumberGenerator, mat: Material) -> MeshInstance3D:
	var parts := []
	for i in 16:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (BOWL.x - 0.07)
		var size := rng.randf_range(0.045, 0.075)
		var y := RIM - 0.07 + (1.0 - r / BOWL.x) * 0.05 + rng.randf_range(-0.01, 0.02)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, 0.7, 1.2)), Vector3(cos(a) * r, y, sin(a) * r))
		parts.append([TownMeals._ball(size, size), xf, COALS[rng.randi() % COALS.size()]])
	var mi := MeshInstance3D.new()
	mi.name = "Coals"
	mi.mesh = TownMeals._merge(parts)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_snow", true)
	return mi


## Lights the braziers for winter or takes them away. `at_once` (a game loaded in winter) has the
## flames, embers and smoke going straight away.
func set_winter(on: bool, at_once := false) -> void:
	if on == burning and not at_once:
		return
	burning = on
	for node in _nodes:
		node.visible = on
	for solid in _solids:
		solid.set_deferred("disabled", not on)
	for light in lights:
		light.visible = on
	for p in _fires:
		p.emitting = on
		if on and at_once:
			p.restart()
	set_glow(_glow)


## The lights are brighter at night (`glow`: 0 by day, 1 at night, see DayNight.glow_at).
func set_glow(glow: float) -> void:
	_glow = glow
	for light in lights:
		light.light_energy = lerpf(LIGHT_DAY, LIGHT_NIGHT, glow)


## Whether a burning brazier lights or warms `pos` within `reach` metres.
func lights_up(pos: Vector3, reach: float) -> bool:
	if not burning:
		return false
	for at in spots:
		if Vector2(pos.x - at.x, pos.z - at.z).length() < reach:
			return true
	return false
