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
	label.text = words.pick_random()
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

	# Starts medium, stretches out like rubber, wobbles, then bursts.
	root.scale = Vector2.ONE * 0.6
	var tween := root.create_tween()
	tween.tween_property(root, "scale", Vector2(1.0, 0.82), 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "scale", Vector2(0.88, 1.04), 0.09).set_trans(Tween.TRANS_SINE)
	tween.tween_property(root, "scale", Vector2(1.14, 0.96), 0.09).set_trans(Tween.TRANS_SINE)
	tween.tween_property(root, "scale", Vector2(1.0, 1.08), 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(root, "scale", Vector2(1.08, 1.03), 0.08).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(root, "rotation", root.rotation + deg_to_rad(randf_range(-8.0, 8.0)), 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.16)
	# One last swell before it pops.
	tween.tween_property(root, "scale", Vector2(1.32, 1.26), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_burst.bind(root, fill, size))
	_pops.append({"node": root, "pos": world_pos + Vector3(randf_range(-0.6, 0.6), 3.2, 0), "age": 0.0})
	_place(_pops[-1])


func _process(delta: float) -> void:
	for p in _pops.duplicate():
		if not is_instance_valid(p.node):
			_pops.erase(p)
			continue
		p.age += delta
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


## Keeps a bubble over its spot in the world while it floats upwards.
func _place(p: Dictionary) -> void:
	var world: Vector3 = p.pos + Vector3(0, p.age * 0.8, 0)
	p.node.visible = not camera.is_position_behind(world)
	p.node.position = camera.unproject_position(world) - p.node.size * 0.5


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
