class_name FrozenFritz
extends Node3D
## Fritz in the snow. When the snow lies thick (see Outdoor.snow, SnowCover) he leaves the
## tavern for the market square and freezes solid there in the middle of a toast, his mug
## raised: an icy blue tint, snow on his head, shoulders, arm and mug, a sheet of ice under his
## boots and icicles hanging from the raised arm and the mug. Frozen, he cannot sing (see
## DrinkingSongs, which only asks a villager who is free to chat) and can only mumble when
## talked to. Birds like to land on him (see VillageBirds.start_frozen_perch). When the snow
## has melted and winter is over he thaws and goes back to his seat at the tavern.
##
## The villager side of it (walking to the square, holding the pose, thawing) is Villager's
## "frozen" task; this node is only what is drawn on and round him.

## Who freezes (see Villager.ROLES).
const ROLE := "5"
## He freezes once the snow lies at least this thick, and thaws when it is thinner than THAW_BELOW
## (a gap between the two, so he does not flicker while the snow comes and goes).
const FREEZE_FROM := 0.35
const THAW_BELOW := 0.12
## The toast he is frozen in: the animation and the second in it where the mug is held up beside
## his head.
const POSE := "Spellcast_Raise"
const POSE_TIME := 0.5
## What he mumbles through his frozen beard when talked to (German; see scripts/lang/frozen_fritz.gd).
const MUFFLED := [
	"B-b-brrr... Pro... pro... st...",
	"Mmpf... mein Krug... ist... gefroren...",
	"Fffrrrr... noch... ein... Bier...",
]
const SNOW := Color(0.95, 0.97, 1.0)
const ICE := Color(0.85, 0.95, 1.0, 0.7)

static var _tint: StandardMaterial3D
static var _snow_mat: StandardMaterial3D
static var _ice_mat: StandardMaterial3D
static var _frost_tex: ImageTexture
static var _frost_normal: ImageTexture
static var _frost_glints: ImageTexture

## Where a bird can sit on him, in the villager's own space: the head, the mug, the raised arm.
var perches: Array[Vector3] = []
var _body: Villager
var _tinted: Array[MeshInstance3D] = []


## Whether he should be frozen now: the snow lies thick enough (or, when `frozen` already, still
## thicker than it takes to thaw).
static func wants(level: Outdoor, frozen: bool) -> bool:
	if level == null or level.snow == null:
		return false
	# Once frozen he stays so for the whole winter, whatever the weather does to the snow.
	if frozen and Weather.is_winter(level.season_day):
		return true
	return level.snow.amount >= (THAW_BELOW if frozen else FREEZE_FROM)


## A place on the market square for him to stand in the open: the square's middle. Vector3.INF
## when the village has no market square.
static func spot(level: Outdoor) -> Vector3:
	var square: Array = level.spots.market
	if square.is_empty():
		return Vector3.INF
	var centre := Vector3.ZERO
	for p: Vector3 in square:
		centre += p
	centre /= square.size()
	var best := Vector3.INF
	for p: Vector3 in square:
		if not level.is_open(level.world_to_cell(p)):
			continue
		if best == Vector3.INF or p.distance_to(centre) < best.distance_to(centre):
			best = p
	return level.to_global(best) if best != Vector3.INF else Vector3.INF


## Freezes `body`, whose toast pose is already held: the ice over it, the snow and icicles on it.
static func freeze(body: Villager) -> FrozenFritz:
	var fx := FrozenFritz.new()
	fx.name = "FrozenFritz"
	fx.set_meta("no_snow", true)
	fx._body = body
	body.add_child(fx)
	fx._build()
	return fx


## Takes the ice away again.
func thaw() -> void:
	for mi in _tinted:
		if is_instance_valid(mi):
			mi.material_overlay = null
	_tinted.clear()
	queue_free()


func _build() -> void:
	var model: Node3D = _body._model
	var bones := _body._bones()
	# The pose is held, but the bones must really be in it before anything is hung on them, or the
	# icicles would hang where the arm was a moment ago.
	_body._anim.advance(0.0)
	bones.force_update_all_bone_transforms()
	var size: float = model.scale.x
	# Everything that is shown on him gets an icy sheen: skin, clothes and mug alike.
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree():
			mi.material_overlay = _tint_material()
			_tinted.append(mi)
	var head := _bone(bones, "head")
	var shoulder_r := _bone(bones, "upperarm.r")
	var shoulder_l := _bone(bones, "upperarm.l")
	var elbow := _bone(bones, "lowerarm.r")
	var hand := _bone(bones, "handslot.r")
	var top := _body.perch_point(0)
	var up := Vector3.UP * size
	# Snow: a cap on the head, a pad on each shoulder, one on the raised upper arm and a thick
	# one on top of the mug.
	_cap(top - up * 0.05, 0.62 * size, 0.2 * size)
	_cap(shoulder_l + Vector3(0.2, 0.16, 0) * size, 0.34 * size, 0.12 * size)
	_cap(shoulder_r + Vector3(-0.2, 0.16, 0) * size, 0.34 * size, 0.12 * size)
	_cap(shoulder_r.lerp(elbow, 0.55) + up * 0.1, 0.26 * size, 0.1 * size)
	_cap(hand + up * 0.22, 0.38 * size, 0.14 * size)
	# Icicles: under the mug, along the underside of the raised arm and off the elbow.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		_icicle(hand + Vector3(cos(a) * 0.12, -0.14, sin(a) * 0.12) * size, rng.randf_range(0.2, 0.42) * size, 0.03 * size)
	for k in 5:
		var along := 0.12 + k * 0.19
		_icicle(shoulder_r.lerp(elbow, along) - up * 0.08, rng.randf_range(0.14, 0.34) * size, 0.026 * size)
	for k in 3:
		_icicle(elbow.lerp(hand, 0.25 + k * 0.25) + Vector3(0.1, -0.04, 0) * size, rng.randf_range(0.16, 0.3) * size, 0.024 * size)
	_icicle(elbow - up * 0.12, 0.4 * size, 0.04 * size)
	# A sheet of ice under his boots.
	var sheet := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.8
	disc.bottom_radius = 0.85
	disc.height = 0.04
	disc.radial_segments = 20
	sheet.mesh = disc
	sheet.material_override = _ice_material()
	sheet.position = Vector3(0, 0.02, 0)
	sheet.set_meta("no_snow", true)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	# Where birds sit: on the snow of his head, on the mug, on the raised arm.
	perches = [top + up * 0.07, hand + up * 0.3, shoulder_r.lerp(elbow, 0.55) + up * 0.2]


## A bone's place in the villager's own space.
func _bone(bones: Skeleton3D, bone: String) -> Vector3:
	var mine := _body.global_transform.affine_inverse() * bones.global_transform
	return mine * bones.get_bone_global_pose(bones.find_bone(bone)).origin


func _cap(at: Vector3, width: float, height: float) -> void:
	var mi := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 10
	ball.rings = 5
	mi.mesh = ball
	mi.scale = Vector3(width, height, width)
	mi.position = at
	mi.material_override = _snow_material()
	mi.set_meta("no_snow", true)
	add_child(mi)


## An icicle hanging from `at`: wide where it grows, a point below.
func _icicle(at: Vector3, length: float, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = radius
	cone.bottom_radius = 0.0
	cone.height = length
	cone.radial_segments = 5
	cone.rings = 1
	mi.mesh = cone
	mi.position = at - Vector3.UP * length * 0.5
	mi.material_override = _ice_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_snow", true)
	add_child(mi)


## The frost the ice is made of, made once: (colour with alpha, bump, sparkles). Patches of white rime
## on pale blue ice, a bumpy surface for the light to break on, and a few tiny glints.
static func _frost() -> Array:
	if _frost_tex != null:
		return [_frost_tex, _frost_normal, _frost_glints]
	var side := 128
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	noise.frequency = 0.04
	noise.seed = 11
	var base: Image = noise.get_seamless_image(side, side)
	var frost := Image.create(side, side, true, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var v: float = base.get_pixel(x, y).r
			var rime := smoothstep(0.42, 0.78, v)
			var c := Color(0.62, 0.82, 0.97).lerp(Color(0.97, 0.99, 1.0), rime)
			c.a = lerpf(0.3, 0.85, rime)
			frost.set_pixel(x, y, c)
	frost.generate_mipmaps()
	var bump := base.duplicate() as Image
	bump.convert(Image.FORMAT_RGB8)
	bump.bump_map_to_normal_map(5.0)
	bump.generate_mipmaps()
	var glints := Image.create(side, side, true, Image.FORMAT_RGBA8)
	glints.fill(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 36:
		glints.set_pixel(rng.randi() % side, rng.randi() % side, Color(0.85, 0.95, 1.0))
	glints.generate_mipmaps()
	_frost_tex = ImageTexture.create_from_image(frost)
	_frost_normal = ImageTexture.create_from_image(bump)
	_frost_glints = ImageTexture.create_from_image(glints)
	return [_frost_tex, _frost_normal, _frost_glints]


## Frost on the material: rime patches, a bumpy surface and a few glints, wrapped round the body
## from all sides (the textures of the models are an atlas, so UVs would not do).
static func _frosted(mat: StandardMaterial3D, scale: float) -> void:
	var tex: Array = _frost()
	mat.albedo_texture = tex[0]
	mat.normal_enabled = true
	mat.normal_texture = tex[1]
	mat.normal_scale = 0.7
	mat.emission_enabled = true
	mat.emission_texture = tex[2]
	mat.emission = Color(0.8, 0.93, 1.0)
	mat.emission_energy_multiplier = 1.4
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(scale, scale, scale)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## The sheen over everything on him: a thin frosty shell, not a polished one. Dull and pale, white at
## the edges where it is thickest, patchy with rime.
static func _tint_material() -> StandardMaterial3D:
	if _tint == null:
		_tint = StandardMaterial3D.new()
		_tint.albedo_color = Color(0.85, 0.94, 1.0, 0.55)
		_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint.roughness = 0.7
		_tint.metallic_specular = 0.25
		_tint.rim_enabled = true
		_tint.rim = 0.8
		_tint.rim_tint = 0.2
		_frosted(_tint, 1.3)
	return _tint


static func _snow_material() -> StandardMaterial3D:
	if _snow_mat == null:
		_snow_mat = StandardMaterial3D.new()
		_snow_mat.albedo_color = SNOW
		_snow_mat.roughness = 0.9
	return _snow_mat


## Icicles and the sheet under his boots: clearer than the shell, but still scratched and cloudy, with
## no hard glare.
static func _ice_material() -> StandardMaterial3D:
	if _ice_mat == null:
		_ice_mat = StandardMaterial3D.new()
		_ice_mat.albedo_color = ICE
		_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ice_mat.roughness = 0.35
		_ice_mat.metallic_specular = 0.45
		_ice_mat.rim_enabled = true
		_ice_mat.rim = 0.6
		_ice_mat.rim_tint = 0.3
		_frosted(_ice_mat, 2.5)
		_ice_mat.emission_energy_multiplier = 1.0
	return _ice_mat
