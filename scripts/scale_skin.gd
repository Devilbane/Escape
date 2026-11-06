class_name ScaleSkin
extends RefCounted
## A scaly skin for dragon-like creatures: rows of overlapping round scales,
## each a little dome with a darker rim, drawn once into a small tiling
## texture and its normal map. Laid on a material with apply(); the material
## keeps its own colour (the texture only shades it), and the pattern is
## projected from three sides (triplanar), so it fits any mesh, also the
## simple shapes built in code. Used by the little pond monster (see
## Fishing.make_monster); any other scaly beast can use it the same way.

## Pixels of the texture across and down; it holds COLUMNS scales a row.
const SIZE := 128
const COLUMNS := 8

static var _colour: ImageTexture
static var _bumps: ImageTexture


## Gives `mat` the scales: `depth` is how deep they look (normal map
## strength), `per_metre` roughly how many scales fit into a metre of the
## mesh before it is scaled.
static func apply(mat: StandardMaterial3D, depth := 1.0, per_metre := 24.0) -> StandardMaterial3D:
	if _colour == null:
		_make()
	mat.albedo_texture = _colour
	mat.normal_enabled = true
	mat.normal_texture = _bumps
	mat.normal_scale = depth
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * per_metre / COLUMNS
	return mat


## How a point of the texture lies on its scale: [distance from the scale's
## middle (0) to its rim (1), and the scale's row]. Scales of a row sit half
## a scale apart from the row above, and each row overlaps the one below, so
## every scale shows its round lower half. Wraps at the edges, so the
## texture tiles.
static func scale_at(x: float, y: float) -> Array:
	var step := float(SIZE) / COLUMNS
	var rise := step * 0.5
	var radius := step * 0.62
	var row := floori(y / rise)
	for j in [row - 1, row, row + 1]:
		var shift := (step * 0.5) if posmod(j, 2) == 1 else 0.0
		var col := roundi((x - shift) / step)
		for i in [col - 1, col, col + 1]:
			var centre := Vector2(i * step + shift, j * rise)
			var d := Vector2(x, y).distance_to(centre) / radius
			if d < 1.0 and y >= centre.y - radius * 0.2:
				return [d, j]
	return [1.0, row]


static func _make() -> void:
	var colour := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var d: float = scale_at(x, y)[0]
			# Lighter in the middle of a scale, a dark rim at its edge.
			var shade := 1.0 - 0.3 * d * d
			if d > 0.82:
				shade *= 0.62
			colour.set_pixel(x, y, Color.WHITE * shade)
			var h := 1.0 - d * d
			height.set_pixel(x, y, Color(h, h, h))
	height.bump_map_to_normal_map(5.0)
	_colour = ImageTexture.create_from_image(colour)
	_bumps = ImageTexture.create_from_image(height)
