class_name HouseLooks
extends RefCounted
## The finished stone and wood of the houses the hero builds on a plot (see
## HouseSketcher), each taken from something in the village:
## - stone walls, garden walls and stone cellar walls: the blocks of the
##   temple's walls (temple_stone),
## - stone floors: the flagstones round the smith's forge, the village
##   square's paving (flagstones),
## - wooden floors: the weathered boards of the cattle pen (plank_floor),
## - wooden walls: the boards of the stairs in the old town houses
##   (stair_wood, see WoodStairs).
## Stone and the stairs' boards are laid in world space, so blocks and boards
## line up from one wall or floor piece to the next. Bare earth keeps its own
## look (BareEarth).

## Four courses of the temple's blocks (tools/make_temple_blocks.py).
const TEMPLE_BLOCKS := "res://assets/house/temple_blocks.png"
## How high (metres) the four courses stand: one wall's height, so a wall
## ends on a joint. How wide the picture is follows from its shape.
const BLOCK_BAND := 2.6
## The picture of the stairs' boards spans this much of a wall (metres): three
## boards up, its width along.
const BOARD_BAND := Vector2(1.3, 0.65)
## The pen's boards on a floor: how wide each is, the gap between two and how
## much their shade varies.
const PLANK_WIDTH := 0.2
const PLANK_GAP := 0.015
const PLANK_VARY := 0.08

static var _mats := {}


## The stone of the walls: the natural stonework of the village (StoneLook,
## shaders/house_stone.gdshader), or with StoneLook's "old" look the temple's
## wall blocks. Either way it is laid in world space, so the courses run level
## round the house from one wall piece to the next.
static func temple_stone() -> Material:
	if StoneLook.settings()["masonry"] > 0.0:
		if not _mats.has("natural"):
			var natural := ShaderMaterial.new()
			natural.shader = preload("res://shaders/house_stone.gdshader")
			StoneLook.apply(natural)
			_mats["natural"] = natural
		return _mats["natural"]
	if not _mats.has("stone"):
		var tex: Texture2D = load(TEMPLE_BLOCKS)
		var wide := BLOCK_BAND * float(tex.get_width()) / float(tex.get_height())
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.roughness = 0.9
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 8.0
		mat.uv1_scale = Vector3(1.0 / wide, 1.0 / BLOCK_BAND, 1.0 / wide)
		_mats["stone"] = mat
	return _mats["stone"]


## The flagstones of the village square (shaders/house_flagstones.gdshader).
static func flagstones() -> ShaderMaterial:
	if not _mats.has("flag"):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/house_flagstones.gdshader")
		_mats["flag"] = mat
	return _mats["flag"]


## The worn boards of the town houses' stairs, running level along a wall.
static func stair_wood() -> StandardMaterial3D:
	if not _mats.has("boards"):
		var mat := WoodStairs.material(Color(1.0, 0.97, 0.92))
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 8.0
		mat.uv1_scale = Vector3(1.0 / BOARD_BAND.x, 1.0 / BOARD_BAND.y, 1.0 / BOARD_BAND.x)
		_mats["boards"] = mat
	return _mats["boards"]


## A floor of the pen's boards filling a box `size` big round `middle`: boards
## along x side by side, each its own shade of weathered timber with a thin gap
## between (`tight`: none, for a roof, where snow lies on the boards and the gaps would show as
## dashes and seams). The same floor always gets the same boards.
static func plank_floor(middle: Vector3, size: Vector3, tight := false) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(middle.x * 10.0), roundi(middle.y * 10.0), roundi(middle.z * 10.0)))
	var b := WeatheredProps.Builder.new()
	# Dark underneath, where the gaps between the boards show.
	b.box(Vector3(0, -size.y * 0.5, 0), Vector3(size.x - 0.06, size.y - 0.02, size.z - 0.06), WeatheredProps.DARK_TIMBER * 0.45, WeatheredProps.WOOD)
	var count := maxi(1, roundi(size.z / PLANK_WIDTH))
	var wide := size.z / float(count)
	for i in count:
		var z := -size.z * 0.5 + wide * (float(i) + 0.5)
		var colour := WeatheredProps.vary(WeatheredProps.TIMBER[rng.randi() % WeatheredProps.TIMBER.size()], rng, PLANK_VARY)
		b.box(Vector3(0, -size.y * 0.5, z), Vector3(size.x, size.y, wide if tight else wide - PLANK_GAP), colour, WeatheredProps.WOOD)
	var holder := Node3D.new()
	var mi := b.finish(holder, middle)
	holder.remove_child(mi)
	holder.free()
	return mi
