class_name Comic
extends CanvasLayer
## Comic-book combat words ("ZACK!", "AUA!") that pop out of a jagged
## burst bubble over the fighters, wobble, and float away. Each word plays
## its own sound: the blow itself, or the hero's cry.

const FONT := preload("res://assets/fonts/Bangers-Regular.woff2")

const HIT_WORDS := ["ZACK!", "KLONK!", "WUMM!"]
const BIG_WORDS := ["KRACH!", "BOING!", "WAMM!"]
const KNIFE_WORDS := ["ZING!", "TSCHAK!"]
const HURT_WORDS := ["AUA!", "UFF!", "AUTSCH!"]
const BREAK_WORDS := ["KNACK!", "KLAPPER!"]
const MISS_WORDS := ["WUSCH!"]
const LEVER_WORDS := ["KLACK!", "KLICK!"]
const RUMBLE_WORDS := ["RUMMS!", "GRUMPEL!"]
const BACKSTAB_WORDS := ["STICH!", "RATSCH!"]
const BLOCK_WORDS := ["KLONG!", "PLONG!"]
const VITAL_WORDS := ["KRAWUMM!", "KABAMM!"]

## The sound each word makes: an impact for the blows, a cry for the hero's pain.
const SOUNDS := {"ZACK!": "word_zack", "KLONK!": "word_klonk", "WUMM!": "word_wumm",
	"KRACH!": "word_krach", "BOING!": "word_boing", "WAMM!": "word_wamm",
	"ZING!": "word_zing", "TSCHAK!": "word_tschak",
	"AUA!": "voice_aua", "UFF!": "voice_uff", "AUTSCH!": "voice_autsch",
	"KNACK!": "word_knack", "KLAPPER!": "word_klapper", "WUSCH!": "word_wusch",
	"KLACK!": "word_klack", "KLICK!": "word_klick", "RUMMS!": "word_rumms",
	"GRUMPEL!": "word_grumpel", "STICH!": "word_stich", "RATSCH!": "word_ratsch",
	"KLONG!": "word_klong", "PLONG!": "word_plong",
	"KRAWUMM!": "word_krach", "KABAMM!": "word_wamm"}
## In English the hero cries "OUCH!", "OOF!" and "OW!" instead.
const SOUNDS_EN := {"AUA!": "voice_autsch", "UFF!": "voice_uff", "AUTSCH!": "voice_au"}
## Loudness per kind; the whoosh of a miss sits quietly on top of the swing.
const VOLUME := {"hurt": -3.0, "miss": -8.0, "rumble": -4.0, "lever": -2.0}
## How much quieter a blow's word sounds when the hero's weapon already
## sounds that blow (see under_weapon): the word stays a soft echo of it.
const UNDER_WEAPON_DB := -9.0
## The kinds of word a blow makes.
const BLOW_KINDS := ["hit", "big", "break", "backstab", "block"]

## The frame in which the hero's weapon last sounded a blow, see under_weapon.
static var _weapon_frame := -1

## The room a bubble's star takes, as a share of its box. The star with its
## rim fills 80 % of the box; while it wobbles it stretches to 1.3 times along
## one side, and tilting barely widens it, as it is round. (The last swell
## just before it bursts reaches a few pixels further for a twentieth of a
## second, which the gap takes up.)
const FOOTPRINT := Vector2(1.04, 1.04)
## Free pixels kept between a bubble and fighters or other bubbles.
const GAP := 6.0
## Spots below the fight count this much farther away, so a bubble likes to
## sit above or beside the fighters rather than at their feet.
const BELOW_COST := 1.3
## How far from the fight a bubble may go before it takes the least crowded
## spot instead.
const REACH := 420.0
## Height of a fighter from the feet to the top of the hood or helmet.
const BODY_HEIGHT := 2.3

## The one comic layer in the game, so anything can call Comic.pop().
static var current: Comic

var camera: Camera3D
## Screen boxes the bubbles keep clear of besides the floating words: the
## message lines over the hero's head and the life bar under him (see
## Game.message_rects and Game.hero_hud_rects).
var avoid := Callable()
var _bursts := {}
var _pops: Array = []


func _ready() -> void:
	current = self
	layer = 5
	# Drawn now, while the game loads, not at the first blow.
	_burst_shape()


## Called as the hero's weapon lands: the blow words popped in this same
## frame play quietly, under the weapon's own impact (Sfx.play_weapon).
static func under_weapon() -> void:
	_weapon_frame = Engine.get_process_frames()


## Shows a word at a point in the world. Kind picks words and colours:
## "hit", "big", "knife", "hurt", "break", "miss", "lever", "rumble",
## "backstab", "block" or "vital" (a vital leap strike).
static func pop(world_pos: Vector3, kind: String) -> void:
	if current == null or current.camera == null:
		return
	current._pop(world_pos, kind)


func _pop(world_pos: Vector3, kind: String) -> void:
	var words: Array = {"hit": HIT_WORDS, "big": BIG_WORDS, "knife": KNIFE_WORDS,
		"hurt": HURT_WORDS, "break": BREAK_WORDS, "miss": MISS_WORDS,
		"lever": LEVER_WORDS, "rumble": RUMBLE_WORDS, "backstab": BACKSTAB_WORDS,
		"block": BLOCK_WORDS, "vital": VITAL_WORDS}[kind]
	var fill: Color = {"hit": Color(1.0, 0.86, 0.15), "big": Color(1.0, 0.55, 0.1),
		"knife": Color(0.55, 0.9, 1.0), "hurt": Color(1.0, 0.25, 0.2),
		"break": Color(0.95, 0.92, 0.8), "miss": Color(1, 1, 1),
		"lever": Color(1.0, 0.8, 0.3), "rumble": Color(0.8, 0.68, 0.5),
		"backstab": Color(0.85, 0.15, 0.25), "block": Color(0.72, 0.78, 0.88),
		"vital": Color(1.0, 0.72, 0.12)}[kind]
	var size := 112.0 if kind in ["big", "rumble", "backstab"] else (128.0 if kind == "vital" else (75.0 if kind == "miss" else 94.0))

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
	var word: String = words.pick_random()
	label.text = Lang.t(word)
	var sound: String = SOUNDS_EN.get(word, SOUNDS[word]) if Lang.language == "en" else SOUNDS[word]
	var volume: float = VOLUME.get(kind, 0.0)
	if kind in BLOW_KINDS and _weapon_frame == Engine.get_process_frames():
		volume += UNDER_WEAPON_DB
	Sfx.play(self, sound, volume, world_pos)
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
	# The spot is chosen at the end of the frame, once the words of the same
	# blow ("Blocked!", the damage number) float over the heads, so the
	# bubble keeps off them.
	var pop := {"node": root, "pos": anchor, "offset": Vector2.ZERO, "settled": false}
	root.visible = false
	_pops.append(pop)
	_settle.call_deferred(pop)


func _settle(pop: Dictionary) -> void:
	if not is_instance_valid(pop.node) or camera == null:
		return
	pop.offset = _free_spot(pop.pos, pop.node.size * FOOTPRINT)
	pop.settled = true
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
	if not p.settled:
		return
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
		if is_instance_valid(p.node) and p.settled:
			var other: Vector2 = camera.unproject_position(p.pos) + p.offset
			var other_extent: Vector2 = p.node.size * FOOTPRINT
			blocked.append(Rect2(other - other_extent * 0.5, other_extent).grow(GAP))
	blocked.append_array(text_columns(camera))
	if avoid.is_valid():
		for rect: Rect2 in avoid.call():
			blocked.append(rect.grow(GAP))
	# Keep clear of the status line at the top and the buttons at the bottom.
	var screen := get_viewport().get_visible_rect().grow_individual(-16, -100, -16, -110)
	return closest_spot(center, extent, blocked, screen)


## The offset from `center` of the closest box of size `extent` that lies
## inside `screen` and touches none of `blocked`. The box is tried hugging
## the edges of every blocked box (left, right, above, below), so it ends up
## right beside a fighter instead of a ring step away. Spots below count
## BELOW_COST times farther. With no free spot within REACH, the spot that
## covers the least is taken.
static func closest_spot(center: Vector2, extent: Vector2, blocked: Array[Rect2], screen: Rect2) -> Vector2:
	var half := extent * 0.5
	var xs: Array[float] = [center.x]
	var ys: Array[float] = [center.y]
	for b in blocked:
		xs.append(b.position.x - half.x - 0.5)
		xs.append(b.end.x + half.x + 0.5)
		ys.append(b.position.y - half.y - 0.5)
		ys.append(b.end.y + half.y + 0.5)
	var best := Vector2.ZERO
	var best_cost := INF
	var fallback := Vector2.ZERO
	var fallback_overlap := INF
	for x in xs:
		for y in ys:
			var offset := Vector2(x, y) - center
			var cost := Vector2(offset.x, offset.y * (BELOW_COST if offset.y > 0.0 else 1.0)).length()
			if cost >= best_cost or cost > REACH:
				continue
			var rect := Rect2(Vector2(x, y) - half, extent)
			if not screen.encloses(rect):
				continue
			var overlap := 0.0
			for b in blocked:
				overlap += b.intersection(rect).get_area()
			if overlap == 0.0:
				best = offset
				best_cost = cost
			elif overlap < fallback_overlap or (overlap == fallback_overlap and cost < fallback.length()):
				fallback_overlap = overlap
				fallback = offset
	return best if best_cost < INF else fallback


## The screen boxes of the words floating over heads and at spots (damage
## numbers, "Blocked!", a level-up, loot, see DamageNumber.columns), with
## the room above each stack that its words still rise into.
static func text_columns(cam: Camera3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for column in DamageNumber.columns(cam):
		out.append((column.rect as Rect2).grow(GAP))
	return out


## The screen box around a fighter, from feet to the top of the head.
func _body_rect(body: Node3D) -> Rect2:
	var feet := camera.unproject_position(body.global_position)
	var head := camera.unproject_position(body.global_position + Vector3(0, BODY_HEIGHT, 0))
	var height := absf(feet.y - head.y)
	var width := height * 0.8
	return Rect2(Vector2(feet.x - width * 0.5, minf(feet.y, head.y)), Vector2(width, height + height * 0.15))


## A jagged comic explosion: coloured star with a thick black rim and speed lines.
## The star's shape is drawn once (see _burst_shape); a colour only fills it in.
func _burst_texture(fill: Color) -> Texture2D:
	var key := fill.to_html()
	if _bursts.has(key):
		return _bursts[key]
	var shape := _burst_shape()
	var mask: Image = shape[0]
	var lines: Image = shape[1]
	var size := mask.get_size()
	var paint := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	paint.fill(fill)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.blit_rect_mask(paint, mask, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	img.blend_rect(lines, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(img)
	_bursts[key] = tex
	return tex


## The star's inside as a mask, and its rim and speed lines, the same for
## every colour. Drawing them pixel by pixel took some 30 ms, which used to
## be paid again for every new colour in the middle of a fight; now it is
## paid once, when the game starts (see _ready).
static var _shape: Array = []


static func _burst_shape() -> Array:
	if not _shape.is_empty():
		return _shape
	const W := 260
	const H := 200
	var mask := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var lines := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var center := Vector2(W, H) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	const POINTS := 13
	var radii: Array[float] = []
	for i in POINTS * 2:
		radii.append(rng.randf_range(0.86, 1.0) if i % 2 == 0 else rng.randf_range(0.58, 0.68))
	var count := radii.size()
	var rim := Color(0.06, 0.03, 0.06)
	var soft_rim := Color(0.06, 0.03, 0.06, 0.5)
	var half := Vector2(W, H) * 0.5
	for y in H:
		for x in W:
			var d := (Vector2(x, y) - center) / half
			var r := d.length()
			# Distance from the centre to the star's edge in this direction (0..1 of the half size).
			var t := fposmod(d.angle(), TAU) / TAU * count
			var i := int(t)
			var e := lerpf(radii[i % count], radii[(i + 1) % count], t - i) * 0.84
			if r < e - 0.07:
				mask.set_pixel(x, y, Color.WHITE)
			elif r < e:
				lines.set_pixel(x, y, rim)
			elif r < e + 0.03:
				lines.set_pixel(x, y, soft_rim)
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
					lines.set_pixelv(Vector2i(q), Color(1, 1, 1, 0.9))
	_shape = [mask, lines]
	return _shape
