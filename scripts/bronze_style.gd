class_name BronzeStyle
extends StyleBox
## The game's forged-bronze frame: a box with a hammered metal rim, a dark
## outline outside and a dark groove inside it, rivets in the corners of thick
## frames, and a flat ground inside.
##
## It answers to the same names as the StyleBoxFlat it replaces (bg_color,
## border_color, set_border_width_all, set_corner_radius_all, draw_center,
## set_expand_margin_all, shadow_color, shadow_size), so code that tints a
## frame for hover, a pick or a fade keeps working. The rim is a grey metal
## texture tinted with border_color: the house gold gives bronze, a blue border
## gives blue steel, and the border's alpha fades the rim.
##
## Unlike StyleBoxFlat, the content margins do not follow the border width on
## their own, except while they were never set: a border setter then keeps
## them equal to the border, as StyleBoxFlat does.

## The ground inside the frame.
@export var bg_color := Color(0.09, 0.066, 0.047, 0.92):
	set(v):
		bg_color = v
		emit_changed()
## The tint of the metal rim (and its alpha).
@export var border_color := Color(0.85, 0.66, 0.32, 0.8):
	set(v):
		border_color = v
		emit_changed()
@export var draw_center := true:
	set(v):
		draw_center = v
		emit_changed()
@export var border_width_left := 0:
	set(v):
		_follow_margin(SIDE_LEFT, border_width_left, v)
		border_width_left = v
		emit_changed()
@export var border_width_top := 0:
	set(v):
		_follow_margin(SIDE_TOP, border_width_top, v)
		border_width_top = v
		emit_changed()
@export var border_width_right := 0:
	set(v):
		_follow_margin(SIDE_RIGHT, border_width_right, v)
		border_width_right = v
		emit_changed()
@export var border_width_bottom := 0:
	set(v):
		_follow_margin(SIDE_BOTTOM, border_width_bottom, v)
		border_width_bottom = v
		emit_changed()
@export var corner_radius_top_left := 0:
	set(v):
		corner_radius_top_left = v
		emit_changed()
@export var corner_radius_top_right := 0:
	set(v):
		corner_radius_top_right = v
		emit_changed()
@export var corner_radius_bottom_right := 0:
	set(v):
		corner_radius_bottom_right = v
		emit_changed()
@export var corner_radius_bottom_left := 0:
	set(v):
		corner_radius_bottom_left = v
		emit_changed()
@export var expand_margin_left := 0.0:
	set(v):
		expand_margin_left = v
		emit_changed()
@export var expand_margin_top := 0.0:
	set(v):
		expand_margin_top = v
		emit_changed()
@export var expand_margin_right := 0.0:
	set(v):
		expand_margin_right = v
		emit_changed()
@export var expand_margin_bottom := 0.0:
	set(v):
		expand_margin_bottom = v
		emit_changed()
## A soft glow or shadow around the frame (the trade window's picked row).
@export var shadow_color := Color(0, 0, 0, 0.6):
	set(v):
		shadow_color = v
		emit_changed()
@export var shadow_size := 0:
	set(v):
		shadow_size = v
		emit_changed()
## Kept for StyleBoxFlat's callers; the frame is always smooth.
@export var anti_aliasing := true

## Frames at least this thick (the windows) get a rivet in each corner.
const RIVET_FROM := 8
## The length of a rim texture's middle part, which is stretched along a side.
const RIM_MIDDLE := 96
## The textures made so far, by their size, so each is made once.
static var _rims := {}
static var _grounds := {}
static var _rivet: ImageTexture
static var _glows := {}
static var _shine: ImageTexture


func set_border_width_all(width: int) -> void:
	border_width_left = width
	border_width_top = width
	border_width_right = width
	border_width_bottom = width


func get_border_width_min() -> int:
	return mini(mini(border_width_left, border_width_right), mini(border_width_top, border_width_bottom))


func set_border_width(side: Side, width: int) -> void:
	match side:
		SIDE_LEFT: border_width_left = width
		SIDE_TOP: border_width_top = width
		SIDE_RIGHT: border_width_right = width
		_: border_width_bottom = width


func get_border_width(side: Side) -> int:
	match side:
		SIDE_LEFT: return border_width_left
		SIDE_TOP: return border_width_top
		SIDE_RIGHT: return border_width_right
	return border_width_bottom


func set_corner_radius_all(radius: int) -> void:
	corner_radius_top_left = radius
	corner_radius_top_right = radius
	corner_radius_bottom_right = radius
	corner_radius_bottom_left = radius


func set_expand_margin_all(size: float) -> void:
	expand_margin_left = size
	expand_margin_top = size
	expand_margin_right = size
	expand_margin_bottom = size


func set_expand_margin(side: Side, size: float) -> void:
	match side:
		SIDE_LEFT: expand_margin_left = size
		SIDE_TOP: expand_margin_top = size
		SIDE_RIGHT: expand_margin_right = size
		_: expand_margin_bottom = size


## While a side's content margin was never set (or still follows the border),
## it keeps the border's width, as in StyleBoxFlat.
func _follow_margin(side: Side, old_width: int, new_width: int) -> void:
	var margin := get_content_margin(side)
	if margin < 0.0 or is_equal_approx(margin, old_width):
		set_content_margin(side, new_width)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)


func _draw(item: RID, rect: Rect2) -> void:
	rect = _get_draw_rect(rect)
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var width := maxi(maxi(border_width_left, border_width_right), maxi(border_width_top, border_width_bottom))
	if width > 0:
		# A side without a rim (the pull-out menu's edge on the screen's
		# border) has its rim pushed out past that side, out of sight.
		var hide := float(width + 2)
		rect = rect.grow_individual(hide if border_width_left == 0 else 0.0, hide if border_width_top == 0 else 0.0,
			hide if border_width_right == 0 else 0.0, hide if border_width_bottom == 0 else 0.0)
		# Even a hairline frame shows as metal.
		width = maxi(width, 2)
	var radius := maxi(maxi(corner_radius_top_left, corner_radius_top_right), maxi(corner_radius_bottom_left, corner_radius_bottom_right))
	# A corner may not take more than half the box.
	var fit := int(floor(minf(rect.size.x, rect.size.y) / 2.0)) - 1
	width = clampi(width, 0, maxi(fit, 0))
	radius = clampi(radius, 0, maxi(fit, 0))
	var rs := RenderingServer
	if shadow_size > 0 and shadow_color.a > 0.0:
		var glow := _glow(shadow_size)
		var grown := rect.grow(shadow_size)
		var c := float(shadow_size * 2)
		rs.canvas_item_add_nine_patch(item, grown, Rect2(Vector2.ZERO, glow.get_size()), glow.get_rid(), Vector2(c, c), Vector2(c, c),
			RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, shadow_color)
	var corner := float(maxi(width, radius) + 2)
	if draw_center and bg_color.a > 0.0:
		var ground := _ground(width, radius)
		rs.canvas_item_add_nine_patch(item, rect, Rect2(Vector2.ZERO, ground.get_size()), ground.get_rid(), Vector2(corner, corner), Vector2(corner, corner),
			RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, bg_color)
	if width <= 0 or border_color.a <= 0.0:
		return
	_draw_rim(item, rect, width, radius, corner)
	if width >= RIVET_FROM and minf(rect.size.x, rect.size.y) >= width * 6:
		var rivet := _rivet_texture()
		# As in the mock-up: a bead of about 14 px (on a window's rim) over
		# the corner, a little out past the rim's outer edge.
		var d := clampf(width * 1.35, 7.0, 16.0)
		var inset := width * 0.42
		# The mock-up's bead: pale gold at its lit top, copper around it.
		var tint := Color(RIVET.r * COPPER.r, RIVET.g * COPPER.g, RIVET.b * COPPER.b, border_color.a)
		for p in [rect.position + Vector2(inset, inset), Vector2(rect.end.x - inset, rect.position.y + inset),
				Vector2(rect.position.x + inset, rect.end.y - inset), rect.end - Vector2(inset, inset)]:
			rs.canvas_item_add_texture_rect(item, Rect2(p - Vector2(d, d) / 2.0, Vector2(d, d)), rivet.get_rid(), false, tint)
			# Polished metal: a white glint and a faint reflected light, not tinted.
			rs.canvas_item_add_texture_rect(item, Rect2(p - Vector2(d, d) / 2.0, Vector2(d, d)), _shine_texture().get_rid(), false, Color(1, 1, 1, border_color.a))


## The bronze's colour across the frame, as light falling over cast metal:
## bands of bright and dark bronze running diagonally from the top left to
## the bottom right of the whole box (the look of the chosen mock-up).
const METAL_STOPS := [
	[0.0, Color("f6d08a")], [0.18, Color("b9763a")], [0.4, Color("6a3b16")],
	[0.62, Color("c88b45")], [0.82, Color("7a4419")], [1.0, Color("e2a861")],
]
## The house bronze the bands are made for; another border colour shifts
## them by its ratio to this (a gold hover shines, a blue border is steel).
const METAL_BASE := Color(0.88, 0.66, 0.36)
## The rim texture's grey on the flat metal: the bands' colour divided by it
## is drawn there exactly, and the lit top edge can still be brighter.
const METAL_FLAT := 0.82
## A warmer, more intense copper over the mock-up's bands (the owner's wish):
## each band's red lifted a little, its blue taken down.
const COPPER := Color(1.08, 0.93, 0.78)
## The rivets' metal: a richer, deeper copper-gold than the rim (the owner's wish), before COPPER.
const RIVET := Color(1.0, 0.66, 0.3)
## How many pieces a side's middle is cut into, so the bands run smoothly.
const METAL_STEPS := 10


## The colour of the metal at `t` (0 at the top left, 1 at the bottom right),
## shifted by the border colour.
func metal_at(t: float) -> Color:
	var c: Color = METAL_STOPS[-1][1]
	for i in range(1, METAL_STOPS.size()):
		if t <= METAL_STOPS[i][0]:
			var a: Array = METAL_STOPS[i - 1]
			var b: Array = METAL_STOPS[i]
			c = (a[1] as Color).lerp(b[1], (t - a[0]) / (b[0] - a[0]))
			break
	c = Color(c.r * COPPER.r, c.g * COPPER.g, c.b * COPPER.b)
	var shifted: Color
	if absf(border_color.h - METAL_BASE.h) < 0.06 and border_color.s > 0.35:
		# A bronze or gold border is bronze: the same copper-brown metal,
		# only lighter or darker (a gold hover shines), never yellower.
		var light := clampf(border_color.v / METAL_BASE.v, 0.6, 1.2)
		shifted = Color(c.r * light, c.g * light, c.b * light)
	else:
		shifted = Color(c.r * border_color.r / METAL_BASE.r, c.g * border_color.g / METAL_BASE.g, c.b * border_color.b / METAL_BASE.b)
	# Too bright for a channel: dim the whole colour, so the bands keep
	# their light and dark instead of all turning flat white-gold.
	var top := maxf(shifted.r, maxf(shifted.g, shifted.b))
	if top > 1.0:
		shifted = Color(shifted.r / top, shifted.g / top, shifted.b / top)
	return Color(shifted.r / METAL_FLAT, shifted.g / METAL_FLAT, shifted.b / METAL_FLAT, border_color.a)


## The rim, drawn as a mesh over the rim texture (corners kept, sides
## stretched, like a nine-patch) so each point can take the metal's colour
## at its place in the box.
func _draw_rim(item: RID, rect: Rect2, width: int, radius: int, corner: float) -> void:
	var rim := _rim(width, radius)
	var tex := rim.get_size()
	var xs := _cuts(rect.position.x, rect.size.x, corner)
	var ys := _cuts(rect.position.y, rect.size.y, corner)
	var us := _cuts(0.0, tex.x, corner)
	var vs := _cuts(0.0, tex.y, corner)
	# 145 degrees in CSS: towards the bottom right, a little more down.
	var dir := Vector2(sin(deg_to_rad(145.0)), -cos(deg_to_rad(145.0)))
	var span := absf(rect.size.x * dir.x) + absf(rect.size.y * dir.y)
	var start := rect.position + Vector2(0.0 if dir.x >= 0.0 else rect.size.x, 0.0 if dir.y >= 0.0 else rect.size.y)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for j in ys.size():
		for i in xs.size():
			var at := Vector2(xs[i], ys[j])
			points.append(at)
			uvs.append(Vector2(us[i] / tex.x, vs[j] / tex.y))
			colors.append(metal_at(clampf((at - start).dot(dir) / maxf(span, 1.0), 0.0, 1.0)))
	var indices := PackedInt32Array()
	var n := xs.size()
	for j in ys.size() - 1:
		for i in n - 1:
			# The middle of the box has no rim: leave it out.
			if i > 0 and i < n - 2 and j > 0 and j < ys.size() - 2:
				continue
			var a := j * n + i
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	RenderingServer.canvas_item_add_triangle_array(item, indices, points, colors, uvs, PackedInt32Array(), PackedFloat32Array(), rim.get_rid())


## The places a side is cut at: its two corners and METAL_STEPS pieces between.
static func _cuts(from: float, length: float, corner: float) -> PackedFloat32Array:
	var cuts := PackedFloat32Array([from])
	var inner := maxf(length - 2.0 * corner, 0.0)
	for k in METAL_STEPS + 1:
		cuts.append(from + minf(corner, length / 2.0) + inner * k / METAL_STEPS)
	cuts.append(from + length)
	return cuts


## How far a point of a texture of `size` lies inside a rounded square with
## corners of `radius` (negative: outside).
static func _inside(x: float, y: float, size: int, radius: float) -> float:
	var half := size / 2.0
	var qx := absf(x - half) - (half - radius)
	var qy := absf(y - half) - (half - radius)
	var outside := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0)
	return radius - outside


## A hash of a texture cell, for the hammered dents: the same every time.
static func _noise(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


## The metal rim: grey, so border_color tints it. Its rows across the rim are
## lit as a rounded bar (bright in its middle), lighter on the top and left
## edges than on the bottom and right, with soft hammer dents.
static func _rim(width: int, radius: int) -> ImageTexture:
	var key := Vector2i(width, radius)
	if _rims.has(key):
		return _rims[key]
	var corner := maxi(width, radius) + 2
	var size := corner * 2 + RIM_MIDDLE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	for y in size:
		for x in size:
			var px := x + 0.5
			var py := y + 0.5
			var d := _inside(px, py, size, radius)
			if d <= 0.0 or d > width + 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var shade: float
			# As in the mock-up: a dark outline outside (2 px on thick rims,
			# 1 px on thin ones), a dark brown line inside, and between them
			# cast metal that is flat but for a lit top edge and a shaded
			# bottom edge; its colour comes from the bands (metal_at).
			var line := 2.0 if width >= 7 else 1.0
			if width >= 3 and d < line:
				shade = 0.1
			elif width >= 3 and d > width - line:
				shade = 0.3
			elif width < 3:
				# A thin rim: just the metal.
				shade = METAL_FLAT
			else:
				shade = METAL_FLAT
				var out := Vector2(px - half, py - half)
				var away := Vector2(signf(out.x) * maxf(absf(out.x) - (half - corner), 0.0),
					signf(out.y) * maxf(absf(out.y) - (half - corner), 0.0))
				if d < line + 1.0 and away.length() > 0.0:
					# The outer edge catches the light on top, falls dark below.
					var facing := away.normalized().dot(Vector2(0.0, -1.0))
					shade += 0.18 * facing if facing > 0.0 else 0.3 * facing
				# Polish: a bright line of reflected light running along the
				# rim a third of the way in, brightest on the sides facing the
				# light, and a slow sheen along each side.
				var t := (d - line) / maxf(width - 2.0 * line, 1.0)
				var gleam := clampf(1.0 - absf(t - 0.35) / 0.18, 0.0, 1.0)
				var lit := 0.6
				if away.length() > 0.0:
					lit = 0.6 + 0.4 * away.normalized().dot(Vector2(-0.7071, -0.7071))
				shade += 0.2 * gleam * lit
				var along := (px if absf(out.y) > absf(out.x) else py) / size
				shade += 0.06 * sin(along * TAU * 1.5 + (1.3 if out.y > 0.0 or out.x > 0.0 else 0.0))
				# A faint grain, so the metal is not plastic.
				shade += (_noise(x / 3, y / 3) - 0.5) * 0.05
			var alpha := clampf(d, 0.0, 1.0) * clampf(width + 0.5 - d + 0.5, 0.0, 1.0)
			shade = clampf(shade, 0.0, 1.0)
			img.set_pixel(x, y, Color(shade, shade, shade, alpha))
	var tex := ImageTexture.create_from_image(img)
	_rims[key] = tex
	return tex


## The ground inside the rim, white so bg_color tints it; it runs under the
## inner groove so no gap shows at the corners.
static func _ground(width: int, radius: int) -> ImageTexture:
	var key := Vector2i(width, radius)
	if _grounds.has(key):
		return _grounds[key]
	var corner := maxi(width, radius) + 2
	var size := corner * 2 + 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var edge := maxf(width - 1.5, 0.0)
	for y in size:
		for x in size:
			var d := _inside(x + 0.5, y + 0.5, size, radius) - edge
			img.set_pixel(x, y, Color(1, 1, 1, clampf(d + 0.5, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_grounds[key] = tex
	return tex


## A domed rivet head, lit from the top left.
static func _rivet_texture() -> ImageTexture:
	if _rivet:
		return _rivet
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var light := Vector3(-0.5, -0.6, 0.62).normalized()
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5 - size / 2.0, y + 0.5 - size / 2.0) / (size / 2.0 - 1.0)
			var r := p.length()
			if r > 1.05:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var alpha := clampf((1.05 - r) * 12.0, 0.0, 1.0)
			if r > 0.88:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.08, alpha))
				continue
			var q := p / 0.88
			var n := Vector3(q.x, q.y, sqrt(maxf(1.0 - q.length_squared(), 0.0)))
			var shade := clampf(0.3 + 0.75 * maxf(n.dot(light), 0.0), 0.0, 1.0)
			# A small bright glint.
			shade = minf(shade + pow(maxf(n.dot(light), 0.0), 18.0) * 0.6, 1.0)
			img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	_rivet = ImageTexture.create_from_image(img)
	return _rivet


## The polish on a rivet head: a bright glint at its lit top left and a
## faint band of reflected light along its lower right, in white with alpha,
## drawn over the tinted head.
static func _shine_texture() -> ImageTexture:
	if _shine:
		return _shine
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5 - size / 2.0, y + 0.5 - size / 2.0) / (size / 2.0 - 1.0)
			var r := p.length()
			if r > 0.86:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
				continue
			var glint := clampf(1.0 - (p - Vector2(-0.32, -0.36)).length() / 0.3, 0.0, 1.0)
			var reflect := clampf(1.0 - absf(r - 0.68) / 0.12, 0.0, 1.0) * clampf(p.normalized().dot(Vector2(0.7071, 0.7071)), 0.0, 1.0)
			var a := clampf(pow(glint, 1.5) * 0.95 + reflect * 0.3, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 0.98, 0.9, a))
	_shine = ImageTexture.create_from_image(img)
	return _shine


## A soft square glow that fades out over `size` pixels around the box.
static func _glow(size: int) -> ImageTexture:
	if _glows.has(size):
		return _glows[size]
	var full := size * 4 + 4
	var img := Image.create(full, full, false, Image.FORMAT_RGBA8)
	for y in full:
		for x in full:
			var d := _inside(x + 0.5, y + 0.5, full, size * 1.0)
			var a := clampf(d / size, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	var tex := ImageTexture.create_from_image(img)
	_glows[size] = tex
	return tex
