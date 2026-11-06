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

## Frames at least this thick get a rivet in each corner.
const RIVET_FROM := 5
## The length of a rim texture's middle part, which is stretched along a side.
const RIM_MIDDLE := 96
## The textures made so far, by their size, so each is made once.
static var _rims := {}
static var _grounds := {}
static var _rivet: ImageTexture
static var _glows := {}


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
	var rim := _rim(width, radius)
	rs.canvas_item_add_nine_patch(item, rect, Rect2(Vector2.ZERO, rim.get_size()), rim.get_rid(), Vector2(corner, corner), Vector2(corner, corner),
		RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, false, border_color)
	if width >= RIVET_FROM and minf(rect.size.x, rect.size.y) >= width * 6:
		var rivet := _rivet_texture()
		var d := clampf(width * 1.6, 10.0, 20.0)
		var inset := width / 2.0 + radius * 0.3 + 1.0
		var tint := Color(minf(border_color.r * 1.15, 1.0), minf(border_color.g * 1.15, 1.0), minf(border_color.b * 1.15, 1.0), border_color.a)
		for p in [rect.position + Vector2(inset, inset), Vector2(rect.end.x - inset, rect.position.y + inset),
				Vector2(rect.position.x + inset, rect.end.y - inset), rect.end - Vector2(inset, inset)]:
			rs.canvas_item_add_texture_rect(item, Rect2(p - Vector2(d, d) / 2.0, Vector2(d, d)), rivet.get_rid(), false, tint)


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
			# Thick rims get a 2 px dark outline and groove, thinner ones 1 px.
			var line := 2.0 if width >= 7 else 1.0
			if width >= 3 and (d < line or d > width - line):
				# The dark outline outside and the groove inside.
				shade = 0.08
			elif width < 3:
				# A thin rim: just the lit metal.
				shade = 0.8 + (_noise(x / 2, y / 2) - 0.5) * 0.12
			else:
				var t := clampf((d - line) / maxf(width - 2.0 * line, 1.0), 0.0, 1.0)
				# A raised bar: dark at its two feet, bright along its ridge; of its
				# two slopes the one facing the light (top left) is lit, the other
				# in shade.
				shade = 0.3 + 0.66 * sin(t * PI)
				var out := Vector2(px - half, py - half)
				var away := Vector2(signf(out.x) * maxf(absf(out.x) - (half - corner), 0.0),
					signf(out.y) * maxf(absf(out.y) - (half - corner), 0.0))
				if away.length() > 0.0:
					var facing := away.normalized().dot(Vector2(-0.7071, -0.7071))
					shade += 0.32 * cos(t * PI) * facing + 0.1 * facing
				# A slow sheen along each side, as light running over polished
				# metal (the sides are stretched, so it spans the whole side).
				var along := (px if absf(out.y) > absf(out.x) else py) / size
				shade += 0.12 * sin(along * TAU + (1.3 if out.y > 0.0 or out.x > 0.0 else 0.0))
				# Hammer dents: a soft blotch every few pixels.
				shade += (_noise(x / 3, y / 3) - 0.5) * 0.14 + (_noise(x, y) - 0.5) * 0.05
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
