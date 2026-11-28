class_name CrownInsignia
extends RefCounted
## The crown's insignia: a golden crown with jewels on royal blue cloth, painted into a texture. The
## herald's tricorn carries it on its cockade (see CrierHat) and his podium on its banner and on the
## news sign (see CrierPodium). Drawn once and kept.

const BLUE := Color(0.13, 0.2, 0.52)
const BLUE_DARK := Color(0.07, 0.11, 0.32)
const GOLD := Color(0.96, 0.76, 0.28)
const GOLD_DARK := Color(0.55, 0.38, 0.1)
const RED := Color(0.78, 0.12, 0.14)

## The crown's outline in the unit square (y down): a band, three points and a dip between them.
const OUTLINE := [Vector2(0.18, 0.74), Vector2(0.12, 0.36), Vector2(0.31, 0.52), Vector2(0.5, 0.24),
		Vector2(0.69, 0.52), Vector2(0.88, 0.36), Vector2(0.82, 0.74)]

static var _cloth: ImageTexture
static var _badge: ImageTexture


## The insignia on a woven blue ground (banners, the sign's plaque).
static func cloth() -> ImageTexture:
	if _cloth == null:
		_cloth = ImageTexture.create_from_image(_paint(128, true))
	return _cloth


## The insignia on a round blue badge with a gold rim, transparent outside (the hat's cockade).
static func badge() -> ImageTexture:
	if _badge == null:
		_badge = ImageTexture.create_from_image(_paint(96, false))
	return _badge


static func _paint(size: int, square: bool) -> Image:
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 4711
	noise.frequency = 0.35
	var middle := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			# A fine weave: the threads cross every other pixel, a little uneven.
			var thread := 0.9 + 0.1 * float((x + y) % 2) + noise.get_noise_2d(x, y) * 0.06
			var ground := BLUE.lerp(BLUE_DARK, clampf(float(y) / size * 0.6, 0.0, 0.6)) * thread
			ground.a = 1.0
			if square:
				var edge := minf(minf(x, size - 1 - x), minf(y, size - 1 - y))
				if edge < size * 0.05:
					ground = GOLD.lerp(GOLD_DARK, 0.3 * thread)
				elif edge < size * 0.07:
					ground = BLUE_DARK
				img.set_pixel(x, y, ground)
			else:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(middle) / (size * 0.5)
				if d > 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
				elif d > 0.86:
					img.set_pixel(x, y, GOLD.lerp(GOLD_DARK, clampf((d - 0.86) * 5.0 + noise.get_noise_2d(x, y) * 0.2, 0.0, 1.0)))
				elif d > 0.8:
					img.set_pixel(x, y, BLUE_DARK)
				else:
					img.set_pixel(x, y, ground)
	_crown(img, size)
	img.generate_mipmaps()
	return img


## The crown itself: a dark shadow outline, the gold body shaded from top to bottom, a darker band with
## three jewels and an orb on each point.
static func _crown(img: Image, size: int) -> void:
	var shadow := PackedVector2Array()
	var body := PackedVector2Array()
	var centre := Vector2(0.5, 0.52)
	for p: Vector2 in OUTLINE:
		body.append(p * size)
		shadow.append((centre + (p - centre) * 1.08) * size)
	_fill(img, shadow, func(_p: Vector2) -> Color: return GOLD_DARK * 0.55)
	_fill(img, body, func(p: Vector2) -> Color:
		var f := clampf((p.y / size - 0.24) / 0.5, 0.0, 1.0)
		var shine := 0.12 * sin(p.x / size * 18.0)
		return GOLD.lerp(GOLD_DARK, f * 0.7).lightened(maxf(0.0, shine)))
	var band := PackedVector2Array([Vector2(0.17, 0.72) * size, Vector2(0.83, 0.72) * size,
			Vector2(0.82, 0.84) * size, Vector2(0.18, 0.84) * size])
	_fill(img, band, func(p: Vector2) -> Color: return GOLD_DARK.lerp(GOLD, 0.35 + 0.3 * sin(p.x * 0.5)))
	for jewel in [[0.3, RED], [0.5, Color(0.2, 0.55, 0.9)], [0.7, RED]]:
		_disc(img, Vector2(jewel[0], 0.78) * size, size * 0.032, jewel[1])
	for orb in [Vector2(0.12, 0.32), Vector2(0.5, 0.2), Vector2(0.88, 0.32)]:
		_disc(img, orb * size, size * 0.05, GOLD_DARK)
		_disc(img, (orb - Vector2(0.008, 0.008)) * size, size * 0.04, GOLD.lightened(0.15))


static func _fill(img: Image, polygon: PackedVector2Array, colour: Callable) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in polygon:
		lo = lo.min(p)
		hi = hi.max(p)
	for y in range(maxi(0, int(lo.y)), mini(img.get_height(), int(hi.y) + 1)):
		for x in range(maxi(0, int(lo.x)), mini(img.get_width(), int(hi.x) + 1)):
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, polygon):
				img.set_pixel(x, y, colour.call(p))


static func _disc(img: Image, at: Vector2, radius: float, colour: Color) -> void:
	for y in range(int(at.y - radius) - 1, int(at.y + radius) + 2):
		for x in range(int(at.x - radius) - 1, int(at.x + radius) + 2):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
					and Vector2(x + 0.5, y + 0.5).distance_to(at) <= radius:
				img.set_pixel(x, y, colour)
