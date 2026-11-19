class_name Snowman
extends Node3D
## The snowman Pip and Pippi build when the snow lies thick (see KidPlay): three balls of snow,
## coal eyes and buttons, a carrot nose, stick arms and a red scarf. There is only one in the
## village. He stands where the children first played in the snow, and they run round him and
## cheer in front of him between their snowball fights. When the snow melts he shrinks and is
## gone with the last of it (see Outdoor.set_snow).

## The snow must lie at least this thick for him to be built, and he is gone below MELTED.
const BUILD_FROM := 0.45
const MELTED := 0.12
## How far round him the children run (metres).
const RING := 1.7

var _size := 1.0


## The village's snowman: the one that stands, or a new one on open ground near `near`. Null when
## there is no room, or the snow is too thin.
static func ensure(level: Outdoor, near: Vector3) -> Snowman:
	if level.snowman != null and is_instance_valid(level.snowman):
		return level.snowman
	if level.snow == null or level.snow.amount < BUILD_FROM:
		return null
	var spot := find_spot(level, near)
	if spot == Vector3.INF:
		return null
	var man := Snowman.new()
	man.name = "Snowman"
	man.set_meta("no_snow", true)
	level.add_child(man)
	man.global_position = spot
	# He looks south, towards the way the camera looks at the village, give or take a little.
	man.rotation.y = Snowball._rng.randf_range(-0.5, 0.5)
	level.snowman = man
	man.set_daylight(level.snow.daylight)
	return man


## Open ground near `near` with room to run round it: the tile and its neighbours all open.
static func find_spot(level: Outdoor, near: Vector3) -> Vector3:
	var at := level.world_to_cell(near)
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := at + Vector2i(dx, dy)
				if _roomy(level, c):
					return level.cell_to_world(c)
	return Vector3.INF


static func _roomy(level: Outdoor, c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not FarmAnimal.may_stand(level, c + Vector2i(dx, dy)):
				return false
	return true


var _snow: ShaderMaterial


func _ready() -> void:
	# The same snow as the ground tiles (see snow.gdshaderinc).
	var snow := ShaderMaterial.new()
	snow.shader = load("res://shaders/snowman_snow.gdshader")
	_snow = snow
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color(0.06, 0.06, 0.07)
	coal.roughness = 0.6
	var carrot := StandardMaterial3D.new()
	carrot.albedo_color = Color(0.95, 0.45, 0.1)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.21, 0.12)
	var scarf := StandardMaterial3D.new()
	scarf.albedo_color = Color(0.75, 0.12, 0.12)
	scarf.roughness = 0.95
	# Three balls of snow, each a little squashed where it sits.
	_ball(0.55, 0.48, snow)
	_ball(0.4, 1.2, snow)
	_ball(0.29, 1.78, snow)
	# Coal eyes, a carrot nose, three coal buttons.
	for side in [-1, 1]:
		_bit(SphereMesh.new(), 0.035, Vector3(0.1 * side, 1.86, 0.25), coal)
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.045
	nose.height = 0.26
	var n := _part(nose, carrot)
	n.position = Vector3(0, 1.78, 0.36)
	n.rotation.x = PI * 0.5
	for i in 3:
		_bit(SphereMesh.new(), 0.04, Vector3(0, 1.0 + i * 0.17, 0.38 - absf(i - 1) * 0.02), coal)
	# Stick arms, crooked a little.
	for side in [-1, 1]:
		var arm := CylinderMesh.new()
		arm.top_radius = 0.018
		arm.bottom_radius = 0.025
		arm.height = 0.7
		var a := _part(arm, wood)
		a.position = Vector3(0.58 * side, 1.35, 0)
		a.rotation.z = -side * 1.05
	# The red scarf round the neck, an end hanging down.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.33
	var s := _part(ring, scarf)
	s.position = Vector3(0, 1.55, 0)
	s.scale = Vector3(1, 0.7, 1)
	var tail := BoxMesh.new()
	tail.size = Vector3(0.12, 0.38, 0.04)
	var t := _part(tail, scarf)
	t.position = Vector3(0.14, 1.36, 0.3)
	t.rotation.z = 0.15
	# An old, battered top hat, worn at a jaunty tilt.
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color(0.1, 0.09, 0.1)
	felt.roughness = 0.9
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.5, 0.12, 0.14)
	band.roughness = 0.8
	var hat := Node3D.new()
	hat.set_meta("no_snow", true)
	hat.position = Vector3(0, 1.93, 0)
	hat.rotation = Vector3(0.0, 0.0, 0.14)
	add_child(hat)
	_hat_part(hat, _cyl(0.27, 0.27, 0.03), Vector3(0, 0, 0), felt)
	_hat_part(hat, _cyl(0.16, 0.18, 0.3), Vector3(0, 0.165, 0), felt)
	_hat_part(hat, _cyl(0.183, 0.183, 0.06), Vector3(0, 0.06, 0), band)


func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 20
	return c


func _hat_part(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.set_meta("no_snow", true)
	parent.add_child(mi)


func _ball(radius: float, y: float, mat: Material) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 1.8
	var mi := _part(m, mat)
	mi.position.y = y


func _bit(m: SphereMesh, radius: float, at: Vector3, mat: Material) -> void:
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	_part(m, mat).position = at


func _part(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.set_meta("no_snow", true)
	add_child(mi)
	return mi


## Shrinks with the melting snow: full size while the snow lies thick, gone at MELTED.
## Tells the snow how bright the light of the hour is (`daylight` 0 night to 1 day), as the
## ground tiles are told: his glints of ice show by day only, and he never glows at night.
func set_daylight(daylight: float) -> void:
	if _snow != null:
		_snow.set_shader_parameter("daylight", clampf(daylight, 0.0, 1.0))


func melt_to(cover: float) -> void:
	_size = clampf((cover - MELTED) / (BUILD_FROM - MELTED), 0.0, 1.0)
	var s := lerpf(0.35, 1.0, _size)
	scale = Vector3(s, s, s)
