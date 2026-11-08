class_name SailCloth
extends RefCounted
## The windmill's sails (see Windmill): canvas stretched between the wooden
## lattice of each arm. The canvas is woven linen like the barber's tent
## (shaders/aged_stone.gdshader, `canvas`), and it lies in shadow where the
## lattice frames it: a soft dark edge along every bar.
##
## The shadow is not drawn by the light: the sails turn, and a baked shadow
## would turn with them. Instead the sail's own flat shape is read once from its
## mesh (which triangles are canvas by their colour on the palette, which are
## wood), painted into a small picture and blurred, and the shader looks it up
## by where it is on the sail, so the shadow always sits along the bars.

## The size of the picture of the sail, in pixels.
const SIZE := 160
## How far the shadow reaches from a bar, in pixels (of SIZE), and how
## strong it gets right at the bar (0 to 1).
const REACH := 4
const STRENGTH := 0.5
## A palette colour is canvas when it is lighter than this (the sails' pale
## sand; the wood of the frame and even the golden straw at the hub are darker).
const CANVAS_LIGHT := 0.7

static var _shadow: ImageTexture
static var _bounds := Vector4(-0.52, -0.52, 1.04, 1.04)


## Gives the sail mesh `mi` (the node a Windmill turns) its woven canvas
## and the shadow along its frame. `windows` is the glow mask of the kit's
## material, as in AgedStone.kit_material.
static func apply(mi: MeshInstance3D, windows: Texture2D) -> void:
	var source := mi.mesh
	var mat := mi.get_active_material(0)
	var palette: Texture2D = null
	if mat is StandardMaterial3D:
		palette = (mat as StandardMaterial3D).albedo_texture
	elif mat is ShaderMaterial:
		palette = (mat as ShaderMaterial).get_shader_parameter("palette")
	if source == null or palette == null:
		return
	if _shadow == null:
		_shadow = ImageTexture.create_from_image(shadow_image(source, palette.get_image()))
	var cloth := (AgedStone.kit_material(palette, windows)).duplicate() as ShaderMaterial
	cloth.set_shader_parameter("canvas", true)
	cloth.set_shader_parameter("canvas_shadow", _shadow)
	cloth.set_shader_parameter("canvas_rect", _bounds)
	cloth.set_shader_parameter("canvas_dark", STRENGTH)
	mi.material_override = cloth


## Whether this palette colour is the sail's canvas.
static func is_canvas(c: Color) -> bool:
	return c.r * 0.3 + c.g * 0.55 + c.b * 0.15 > CANVAS_LIGHT


## The shadow of the frame as a picture over the sail seen from the front
## (x right, y up, as the picture's rows count): 1 (white) right at a bar, fading to 0 further off, and
## 0 on the bars themselves.
static func shadow_image(mesh: Mesh, palette: Image) -> Image:
	var canvas := PackedByteArray()
	canvas.resize(SIZE * SIZE)
	var frame := PackedByteArray()
	frame.resize(SIZE * SIZE)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var tris: Array = []
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() if idx.size() > 0 else verts.size()
		for i in range(0, count - 2, 3):
			var ids := [i, i + 1, i + 2]
			if idx.size() > 0:
				ids = [idx[i], idx[i + 1], idx[i + 2]]
			var pts: Array[Vector2] = []
			var uv := Vector2.ZERO
			for k in ids:
				pts.append(Vector2(verts[k].x, verts[k].y))
				uv += uvs[k] / 3.0
				lo = lo.min(pts[-1])
				hi = hi.max(pts[-1])
			var px := palette.get_pixelv(Vector2i(clampi(int(uv.x * palette.get_width()), 0, palette.get_width() - 1),
					clampi(int(uv.y * palette.get_height()), 0, palette.get_height() - 1)))
			tris.append([pts, is_canvas(px)])
	var span := maxf(hi.x - lo.x, hi.y - lo.y) * 1.04
	var mid := (lo + hi) * 0.5
	_bounds = Vector4(mid.x - span * 0.5, mid.y - span * 0.5, span, span)
	for t in tris:
		_fill(canvas if t[1] else frame, t[0], span, mid)
	# Where the canvas is not covered by wood is canvas; the rest, bar or
	# bare air round the sail, throws the shadow.
	var open := PackedByteArray()
	open.resize(SIZE * SIZE)
	for i in SIZE * SIZE:
		open[i] = 1 if canvas[i] == 1 and frame[i] == 0 else 0
	var blocked := PackedFloat32Array()
	blocked.resize(SIZE * SIZE)
	for i in SIZE * SIZE:
		blocked[i] = 1.0 - float(open[i])
	var soft := _blur(_blur(blocked, true), false)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_R8)
	for y in SIZE:
		for x in SIZE:
			var v: float = soft[y * SIZE + x]
			img.set_pixel(x, y, Color(v * float(open[y * SIZE + x]), 0, 0))
	return img


## Paints one triangle (corners in the sail's x, y) into `pixels` as 1.
static func _fill(pixels: PackedByteArray, pts: Array, span: float, mid: Vector2) -> void:
	var p: Array[Vector2] = []
	for q: Vector2 in pts:
		p.append(((q - mid) / span + Vector2(0.5, 0.5)) * SIZE)
	var x0 := clampi(int(floorf(minf(p[0].x, minf(p[1].x, p[2].x)))), 0, SIZE - 1)
	var x1 := clampi(int(ceilf(maxf(p[0].x, maxf(p[1].x, p[2].x)))), 0, SIZE - 1)
	var y0 := clampi(int(floorf(minf(p[0].y, minf(p[1].y, p[2].y)))), 0, SIZE - 1)
	var y1 := clampi(int(ceilf(maxf(p[0].y, maxf(p[1].y, p[2].y)))), 0, SIZE - 1)
	var area := (p[1] - p[0]).cross(p[2] - p[0])
	if absf(area) < 0.0001:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2(x + 0.5, y + 0.5)
			var a := (p[1] - c).cross(p[2] - c) / area
			var b := (p[2] - c).cross(p[0] - c) / area
			if a >= 0.0 and b >= 0.0 and a + b <= 1.0:
				pixels[y * SIZE + x] = 1


## A box blur of REACH pixels along one axis, ending in a soft falloff.
static func _blur(src: PackedFloat32Array, along_x: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for line in SIZE:
		for i in SIZE:
			var sum := 0.0
			for d in range(-REACH, REACH + 1):
				var j := clampi(i + d, 0, SIZE - 1)
				sum += src[(line * SIZE + j) if along_x else (j * SIZE + line)]
			out[(line * SIZE + i) if along_x else (i * SIZE + line)] = sum / float(2 * REACH + 1)
	return out
