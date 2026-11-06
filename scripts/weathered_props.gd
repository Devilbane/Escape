class_name WeatheredProps
extends RefCounted
## The weathered look of the props outside: barrels, crates, sacks, lumber,
## stone heaps, rocks, pumpkins and tents (the KayKit models), and the pieces
## built in code (the forge, the workbenches, the food pedestal, the street
## lamps). They looked new and plastic next to the aged stone of the village
## and the graveyard (see AgedStone); shaders/weathered_prop.gdshader gives
## them grain, cracks, rust, lichen, moss, grime and faded colours.
##
## For speed, the pieces built in code are not a box per part any more: a
## Builder lays all the parts of one thing into a single mesh, its colours as
## vertex colours, so a whole forge draws in a call or two. Every material is
## shared.

const SHADER := preload("res://shaders/weathered_prop.gdshader")

## What a grey colour is on a piece (the alpha of its vertex colour, see
## Builder): iron, or stone. FRESH keeps strong colours as they are, for food
## (for a whole model or plain colour; a Builder mesh is made fresh as a whole
## by Builder.finish).
## Browns are wood and pale browns cloth whatever the kind.
const IRON := 0.0
const FRESH := 0.5
const STONE := 1.0
const WOOD := 1.0

## The KayKit models that are weathered when placed (see Outdoor._put), and
## what grey is on each. Models not listed keep their own look.
const MODELS := {
	"barrel": IRON, "crate_A_big": IRON, "crate_long_A": IRON, "crate_open": IRON,
	"sack": IRON, "wheelbarrow": IRON, "bucket_water": IRON, "resource_lumber": IRON,
	"tree_single_A_cut": IRON, "weaponrack": IRON, "flag_red": IRON, "flag_blue": IRON,
	"tent": IRON, "bench": IRON,
	"resource_stone": STONE, "rock_single_A": STONE, "rock_single_C": STONE, "rock_single_E": STONE,
	"pumpkin_orange": FRESH, "pumpkin_orange_jackolantern": FRESH, "pumpkin_yellow_small": FRESH,
}

## The warm greys of the village stone, a few browns of old timber, and iron,
## as painted (like the KayKit palette, before the weathering).
const STONES := [Color(0.76, 0.74, 0.7), Color(0.71, 0.7, 0.67), Color(0.8, 0.77, 0.71),
		Color(0.67, 0.66, 0.64)]
const TIMBER := [Color(0.72, 0.58, 0.45), Color(0.66, 0.53, 0.41), Color(0.76, 0.62, 0.48),
		Color(0.62, 0.5, 0.39)]
const DARK_TIMBER := Color(0.58, 0.46, 0.36)
const IRON_COLOUR := Color(0.6, 0.62, 0.64)

static var _mats := {}


## The weathered material of a model's palette texture.
static func palette_material(palette: Texture2D, kind: float) -> ShaderMaterial:
	var key := "pal_%d_%.2f" % [palette.get_instance_id(), kind]
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("palette", palette)
		mat.set_shader_parameter("source", 0)
		mat.set_shader_parameter("grey_stone", 1.0 if kind > 0.75 else 0.0)
		mat.set_shader_parameter("produce", absf(kind - FRESH) < 0.2)
		_mats[key] = mat
	return _mats[key]


## The weathered material of a model's palette texture, its cloth kept
## clean: fresh woven linen with no stains or grime (the barber's tent).
static func linen_material(palette: Texture2D, kind: float) -> ShaderMaterial:
	var key := "linen_%d_%.2f" % [palette.get_instance_id(), kind]
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("palette", palette)
		mat.set_shader_parameter("source", 0)
		mat.set_shader_parameter("grey_stone", 1.0 if kind > 0.75 else 0.0)
		mat.set_shader_parameter("linen", true)
		_mats[key] = mat
	return _mats[key]


## The material of the meshes a Builder makes. `fresh`: its strong colours
## are produce or earth (see FRESH), for the whole mesh.
static func vertex_material(fresh := false) -> ShaderMaterial:
	var key := "vertex_fresh" if fresh else "vertex"
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("source", 1)
		mat.set_shader_parameter("produce", fresh)
		_mats[key] = mat
	return _mats[key]


## The weathered material of one plain colour (a part made of a primitive
## mesh, such as the food on the pedestal).
static func colour_material(colour: Color, kind := WOOD) -> ShaderMaterial:
	var key := "col_%s_%.2f" % [colour.to_html(false), kind]
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("source", 2)
		mat.set_shader_parameter("base_colour", colour)
		mat.set_shader_parameter("grey_stone", 1.0 if kind > 0.75 else 0.0)
		mat.set_shader_parameter("produce", absf(kind - FRESH) < 0.2)
		_mats[key] = mat
	return _mats[key]


## Weathers a placed KayKit model, if it is one of MODELS.
static func weather_model(node: Node, model: String) -> void:
	if not MODELS.has(model):
		return
	var kind: float = MODELS[model]
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var source := mi.get_active_material(0) as StandardMaterial3D
		if source and source.albedo_texture:
			mi.material_override = palette_material(source.albedo_texture, kind)


## Gives a placed model (weathered already, see weather_model) clean linen
## for its cloth, keeping the weathered wood.
static func clean_linen(node: Node) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi.material_override as ShaderMaterial
		if m and m.shader == SHADER and m.get_shader_parameter("source") == 0:
			mi.material_override = linen_material(m.get_shader_parameter("palette"),
					STONE if m.get_shader_parameter("grey_stone") > 0.5 else IRON)


## Weathers the plain painted parts of something built from primitive meshes
## (a shop sign's post and board): every opaque, unlit-free colour that is not
## shiny metal or glowing. Shiny and glowing parts keep their look.
static func weather_plain(node: Node) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi.get_active_material(0) as StandardMaterial3D
		if m == null or m.albedo_texture or m.emission_enabled or m.metallic > 0.5 \
				or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		mi.material_override = colour_material(m.albedo_color)


## A colour a little lighter or darker, picked by `rng`, so that the stones
## of a wall or the boards of a table are not all alike.
static func vary(colour: Color, rng: RandomNumberGenerator, amount := 0.08) -> Color:
	var f := 1.0 + rng.randf_range(-amount, amount)
	return Color(colour.r * f, colour.g * f * (1.0 + rng.randf_range(-0.02, 0.02)), colour.b * f)


## Lays many parts into one mesh: boxes, frustums and cylinders, each in its
## own colour and kind (see IRON, STONE, FRESH, WOOD), with flat faces.
class Builder:
	var _st := SurfaceTool.new()
	var _empty := true

	func _init() -> void:
		_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## One triangle, front face turned towards `n`.
	func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
		# Godot draws the side whose corners run clockwise.
		if (b - a).cross(c - a).dot(n) > 0.0:
			var t := b
			b = c
			c = t
			var tn := nb
			nb = nc
			nc = tn
		_st.set_normal(na if na != Vector3.ZERO else n)
		_st.add_vertex(a)
		_st.set_normal(nb if nb != Vector3.ZERO else n)
		_st.add_vertex(b)
		_st.set_normal(nc if nc != Vector3.ZERO else n)
		_st.add_vertex(c)
		_empty = false

	func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
		_tri(a, b, c, n)
		_tri(a, c, d, n)

	func _colour(colour: Color, kind: float) -> void:
		_st.set_color(Color(colour.r, colour.g, colour.b, kind))

	## A box standing on `foot` (the middle of its bottom), turned by `basis`.
	func box(foot: Vector3, size: Vector3, colour: Color, kind := WOOD, basis := Basis()) -> void:
		frustum(foot, Vector2(size.x, size.z), Vector2(size.x, size.z), size.y, colour, kind, basis)

	## A box narrowing from `bottom` to `top` (x and z sizes), `height` tall,
	## standing on `foot`, turned by `basis`.
	func frustum(foot: Vector3, bottom: Vector2, top: Vector2, height: float, colour: Color, kind := WOOD, basis := Basis()) -> void:
		_colour(colour, kind)
		var lo: Array[Vector3] = []
		var hi: Array[Vector3] = []
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			lo.append(foot + basis * Vector3(corner.x * bottom.x * 0.5, 0, corner.y * bottom.y * 0.5))
			hi.append(foot + basis * Vector3(corner.x * top.x * 0.5, height, corner.y * top.y * 0.5))
		var mid := foot + basis * Vector3(0, height * 0.5, 0)
		for i in 4:
			var j := (i + 1) % 4
			var n := (lo[j] - lo[i]).cross(hi[i] - lo[i]).normalized()
			if n.dot((lo[i] + lo[j] + hi[i] + hi[j]) * 0.25 - mid) < 0.0:
				n = -n
			_quad(lo[i], lo[j], hi[j], hi[i], n)
		var up := basis.y.normalized()
		_quad(hi[0], hi[1], hi[2], hi[3], up)
		_quad(lo[0], lo[1], lo[2], lo[3], -up)

	## A cylinder (or a cone, with radius_top 0) standing on `foot`, its
	## axis along the basis' y, smooth round the side.
	func cylinder(foot: Vector3, radius_bottom: float, radius_top: float, height: float, colour: Color, kind := WOOD, segments := 10, basis := Basis(), caps := true) -> void:
		_colour(colour, kind)
		var up := basis.y.normalized()
		var slope := (radius_bottom - radius_top) / maxf(height, 0.001)
		for i in segments:
			var a0 := TAU * i / segments
			var a1 := TAU * (i + 1) / segments
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var b0 := foot + basis * (d0 * radius_bottom)
			var b1 := foot + basis * (d1 * radius_bottom)
			var t0 := foot + basis * (d0 * radius_top + Vector3(0, height, 0))
			var t1 := foot + basis * (d1 * radius_top + Vector3(0, height, 0))
			var n0 := (basis * (d0 + Vector3(0, slope, 0))).normalized()
			var n1 := (basis * (d1 + Vector3(0, slope, 0))).normalized()
			var nm := (n0 + n1).normalized()
			if radius_top > 0.0005:
				_tri(b0, b1, t1, nm, n0, n1, n1)
				_tri(b0, t1, t0, nm, n0, n1, n0)
			else:
				_tri(b0, b1, t0, nm, n0, n1, nm)
			if caps:
				if radius_top > 0.0005:
					_tri(foot + basis * Vector3(0, height, 0), t0, t1, up)
				_tri(foot, b0, b1, -up)

	## One four-cornered face, its front turned towards `outward`.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, kind: float, outward: Vector3) -> void:
		_colour(colour, kind)
		var n := (b - a).cross(d - a).normalized()
		if n.dot(outward) < 0.0:
			n = -n
		_quad(a, b, c, d, n)

	## A four-cornered face shaded smooth: each corner with its own normal.
	func quad_smooth(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, colour: Color, kind: float) -> void:
		_colour(colour, kind)
		var n := (na + nb + nc + nd).normalized()
		_tri(a, b, c, n, na, nb, nc)
		_tri(a, c, d, n, na, nc, nd)

	## A lying log or bar from `a` to `b`.
	func bar(a: Vector3, b: Vector3, radius: float, colour: Color, kind := WOOD, segments := 6) -> void:
		var axis := (b - a)
		var y := axis.normalized()
		var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		cylinder(a, radius, radius, axis.length(), colour, kind, segments, Basis(x, y, z))

	func is_empty() -> bool:
		return _empty

	## The mesh, in the weathered material, standing at `at` in `parent`.
	## Its parts were laid out round the mesh's own origin, which should be
	## on the ground: the grime and moss gather near it.
	## With `fresh`, its strong colours are produce or earth (see FRESH).
	func finish(parent: Node, at := Vector3.ZERO, shadows := true, fresh := false) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = _st.commit()
		mi.material_override = WeatheredProps.vertex_material(fresh)
		mi.position = at
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		return mi
