class_name Comic
extends CanvasLayer
## Comic-book combat words ("ZACK!", "AUA!") that pop out of a jagged
## burst bubble over the fighters, wobble, and float away.

const FONT := preload("res://assets/fonts/Bangers-Regular.woff2")

const HIT_WORDS := ["ZACK!", "KLONK!", "WUMM!"]
const BIG_WORDS := ["KRACH!", "BOING!", "WAMM!"]
const KNIFE_WORDS := ["ZING!", "TSCHAK!"]
const HURT_WORDS := ["AUA!", "UFF!", "AUTSCH!"]
const BREAK_WORDS := ["KNACK!", "KLAPPER!"]
const MISS_WORDS := ["WUSCH!"]

## How much a bubble grows at most (with its tilt), so it is kept apart at full size.
const GROWN := 1.5
## Free pixels kept between a bubble and fighters or other bubbles.
const GAP := 6.0
## Height of a fighter from the feet to the top of the hood or helmet.
const BODY_HEIGHT := 2.3

## The one comic layer in the game, so anything can call Comic.pop().
static var current: Comic

var camera: Camera3D
var _bursts := {}
var _pops: Array = []


func _ready() -> void:
	current = self
	layer = 5


## Shows a word at a point in the world. Kind picks words and colours:
## "hit", "big", "knife", "hurt", "break" or "miss".
static func pop(world_pos: Vector3, kind: String) -> void:
	if current == null or current.camera == null:
		return
	current._pop(world_pos, kind)


func _pop(world_pos: Vector3, kind: String) -> void:
	var words: Array = {"hit": HIT_WORDS, "big": BIG_WORDS, "knife": KNIFE_WORDS,
		"hurt": HURT_WORDS, "break": BREAK_WORDS, "miss": MISS_WORDS}[kind]
	var fill: Color = {"hit": Color(1.0, 0.86, 0.15), "big": Color(1.0, 0.55, 0.1),
		"knife": Color(0.55, 0.9, 1.0), "hurt": Color(1.0, 0.25, 0.2),
		"break": Color(0.95, 0.92, 0.8), "miss": Color(1, 1, 1)}[kind]
	var size := 150.0 if kind == "big" else (100.0 if kind == "miss" else 125.0)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(size, size) * Vector2(1.75, 1.35)
	root.pivot_offset = root.size * 0.5
	root.rotation = deg_to_rad(randf_range(-12.0, 12.0))
	root.scale = Vector2.ONE * 0.05
	add_child(root)
	if kind != "miss":
		var burst := TextureRect.new()
		burst.texture = _burst_texture(fill)
		burst.stretch_mode = TextureRect.STRETCH_SCALE
		burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(burst)
	var label := Label.new()
	label.text = Lang.t(words.pick_random())
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", int(size * 0.34))
	label.add_theme_color_override("font_color", Color(0.12, 0.05, 0.1) if kind != "miss" else Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color.WHITE if kind != "miss" else Color(0.1, 0.05, 0.1))
	label.add_theme_constant_override("outline_size", int(size * 0.05))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)

	# Starts medium, stretches out like rubber, wobbles hard, then bursts.
	root.scale = Vector2.ONE * 0.55
	var tween := root.create_tween()
	for target in [Vector2(1.3, 0.62), Vector2(0.72, 1.3), Vector2(1.24, 0.8),
			Vector2(0.86, 1.16), Vector2(1.12, 0.92), Vector2(0.98, 1.06), Vector2(1.04, 1.0)]:
		tween.tween_property(root, "scale", target, 0.085).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	root.create_tween().tween_property(root, "rotation", root.rotation + deg_to_rad(randf_range(-10.0, 10.0)), 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.12)
	# Squeezes together once, then swells up and pops.
	tween.tween_property(root, "scale", Vector2(0.86, 1.2), 0.07).set_trans(Tween.TRANS_SINE)
	tween.tween_property(root, "scale", Vector2(1.45, 1.3), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_burst.bind(root, fill, size))
	var anchor := world_pos + Vector3(0, 1.0, 0)
	var pop := {"node": root, "pos": anchor, "offset": _free_spot(anchor, root.size * GROWN)}
	_pops.append(pop)
	_place(pop)


func _process(delta: float) -> void:
	for p in _pops.duplicate():
		if not is_instance_valid(p.node):
			_pops.erase(p)
			continue
		_place(p)


## The bubble bursts: it vanishes and jagged scraps fly off spinning.
func _burst(root: Control, fill: Color, size: float) -> void:
	if not is_instance_valid(root):
		return
	var center := root.position + root.size * 0.5
	root.queue_free()
	for i in 12:
		var angle := TAU * i / 12.0 + randf_range(-0.2, 0.2)
		var dir := Vector2(cos(angle), sin(angle)) * Vector2(1.3, 1.0)
		var shard := Polygon2D.new()
		var r := size * randf_range(0.13, 0.2)
		var points := PackedVector2Array([Vector2(-r, -r * 0.4), Vector2(r * 0.9, -r * 0.7), Vector2(r * 0.5, r * 0.8), Vector2(-r * 0.6, r * 0.5)])
		shard.polygon = points
		shard.color = fill
		var rim := Line2D.new()
		rim.points = points
		rim.closed = true
		rim.width = 3.0
		rim.default_color = Color(0.06, 0.03, 0.06)
		shard.add_child(rim)
		# The scraps start where the bubble's skin was and fly outwards.
		shard.position = center + dir * size * 0.5
		shard.rotation = randf() * TAU
		add_child(shard)
		var target := center + dir * size * randf_range(1.0, 1.4)
		var t := shard.create_tween()
		t.tween_property(shard, "position", target, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(shard, "rotation", shard.rotation + randf_range(-4.0, 4.0), 0.32)
		t.parallel().tween_property(shard, "scale", Vector2.ONE * 0.3, 0.32)
		t.parallel().tween_property(shard, "modulate:a", 0.0, 0.32).set_delay(0.08)
		t.tween_callback(shard.queue_free)


## Keeps a bubble at its spot beside the fight, even when the camera moves.
func _place(p: Dictionary) -> void:
	p.node.visible = not camera.is_position_behind(p.pos)
	p.node.position = camera.unproject_position(p.pos) + p.offset - p.node.size * 0.5


## Finds a place on screen near the fight where the bubble touches neither a
## fighter nor another bubble. Returns the offset from the fight's screen point.
func _free_spot(anchor: Vector3, extent: Vector2) -> Vector2:
	var center := camera.unproject_position(anchor)
	var blocked: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group("combatant"):
		var body := node as Node3D
		if body and body.is_visible_in_tree() and not camera.is_position_behind(body.global_position):
			blocked.append(_body_rect(body).grow(GAP))
	for p in _pops:
		if is_instance_valid(p.node):
			var other: Vector2 = camera.unproject_position(p.pos) + p.offset
			var other_extent: Vector2 = p.node.size * GROWN
			blocked.append(Rect2(other - other_extent * 0.5, other_extent).grow(GAP))
	# Keep clear of the status line at the top and the buttons at the bottom.
	var screen := get_viewport().get_visible_rect().grow_individual(-16, -100, -16, -110)
	var best := Vector2.ZERO
	var best_overlap := INF
	# Try rings of spots around the fight, closest first and from above round.
	var start := extent.length() * 0.3
	for ring in 14:
		var radius := start + ring * 20.0
		for step in 16:
			var angle := -PI / 2 + ceilf(step / 2.0) * TAU / 16.0 * (1.0 if step % 2 == 0 else -1.0)
			var offset := Vector2(cos(angle), sin(angle)) * radius * Vector2(1.2, 1.0)
			var rect := Rect2(center + offset - extent * 0.5, extent)
			if not screen.encloses(rect):
				continue
			var overlap := 0.0
			for b in blocked:
				overlap += b.intersection(rect).get_area()
			if overlap == 0.0:
				return offset
			if overlap < best_overlap:
				best_overlap = overlap
				best = offset
	return best


## The screen box around a fighter, from feet to the top of the head.
func _body_rect(body: Node3D) -> Rect2:
	var feet := camera.unproject_position(body.global_position)
	var head := camera.unproject_position(body.global_position + Vector3(0, BODY_HEIGHT, 0))
	var height := absf(feet.y - head.y)
	var width := height * 0.8
	return Rect2(Vector2(feet.x - width * 0.5, minf(feet.y, head.y)), Vector2(width, height + height * 0.15))


## A jagged comic explosion: coloured star with a thick black rim and speed lines.
func _burst_texture(fill: Color) -> Texture2D:
	var key := fill.to_html()
	if _bursts.has(key):
		return _bursts[key]
	const W := 260
	const H := 200
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(W, H) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	const POINTS := 13
	var radii: Array[float] = []
	for i in POINTS * 2:
		radii.append(rng.randf_range(0.86, 1.0) if i % 2 == 0 else rng.randf_range(0.58, 0.68))
	# Distance from the centre to the star's edge in a given direction (0..1 of the half size).
	var edge := func(angle: float) -> float:
		var t := fposmod(angle, TAU) / TAU * POINTS * 2
		var i := int(t)
		return lerpf(radii[i % radii.size()], radii[(i + 1) % radii.size()], t - i)
	var half := Vector2(W, H) * 0.5
	for y in H:
		for x in W:
			var d := (Vector2(x, y) - center) / half
			var r := d.length()
			var e: float = edge.call(d.angle()) * 0.84
			if r < e - 0.07:
				img.set_pixel(x, y, fill)
			elif r < e:
				img.set_pixel(x, y, Color(0.06, 0.03, 0.06))
			elif r < e + 0.03:
				img.set_pixel(x, y, Color(0.06, 0.03, 0.06, 0.5))
	# A few speed lines bursting out past the rim.
	for i in 10:
		var a := TAU * i / 10.0 + 0.2
		var dir := Vector2(cos(a), sin(a))
		for s in 30:
			var r := lerpf(0.9, 1.0, s / 29.0)
			var p := center + dir * half * r
			for o in [-1, 0, 1]:
				var q: Vector2 = (p + dir.orthogonal() * o).round()
				if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H:
					img.set_pixelv(Vector2i(q), Color(1, 1, 1, 0.9))
	var tex := ImageTexture.create_from_image(img)
	_bursts[key] = tex
	return tex
