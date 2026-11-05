class_name SongSheet
extends Control
## The words of Zecher Fritz's drinking song in a comic speech bubble over
## his head (see DrinkingSongs), so the player can sing along.
##
## The whole verse shows at once. The line he sings right now is marked with
## a note and fills with colour from left to right as he sings it, in time
## with its phrase of the tune; the lines already sung are dimmed and the ones
## still to come stay readable, so the player can read ahead.
##
## The bubble has one fixed size, set by the longest line of any song in
## either language, so a new line or a new song never reshapes it. It sits
## above his head with its tail pointing down at him; when that would cover
## the hero, the message over the hero's head or the bars under him, it moves
## to one side, or below his feet with the tail pointing up. It fades out while a window is open or he is off
## screen, and goes when the song is over or broken off.

const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
## Body text size (ux-ui guide: 18 to 20), at the game's text scale.
const FONT_SIZE := 20
## Space inside the bubble around the lines, and between two lines.
const PAD := Vector2(14, 12)
const LINE_GAP := 6.0
## The column left of the lines where the note marks the line sung now.
const MARKER := 24.0
## How far the tail reaches out of the bubble, and how wide it is where it
## leaves it.
const TAIL := 16.0
const TAIL_BASE := 22.0
const RADIUS := 18
const RIM_WIDTH := 3
## Paper and ink, as the comic words (see Comic): a light bubble with a dark
## rim and dark text on it.
const PAPER := Color(1.0, 0.96, 0.86)
const RIM := Color(0.06, 0.03, 0.06)
const INK := Color(0.16, 0.1, 0.08)
## The part of the line already sung (about 6 : 1 against the paper).
const SUNG := Color(0.62, 0.16, 0.05)
## How strongly the lines already sung, and those still to come, show.
const PAST_ALPHA := 0.42
const NEXT_ALPHA := 0.8
## Share of a line's time the colour takes to fill it: the phrase ends with a
## held note, so the words are all sung a little before it is over.
const FILL_SHARE := 0.9
## Seconds to fade in and out, and how long the last line stays after the
## verse is over before the bubble fades.
const FADE_IN := 0.2
const FADE_OUT := 0.3
const LINGER := 0.9
## Metres above the name tag where the tail points.
const ABOVE_TAG := 0.35
## Height of the hero from the feet to the top of the head (as Comic).
const BODY_HEIGHT := 2.3
## Screen edges kept free: the status line at the top and the buttons at the
## bottom (as Comic).
const KEEP_FREE := [16.0, 100.0, 16.0, 110.0]

var game: Node
var camera: Camera3D
## Whether the world runs right now (no window open, the game is being
## played); the bubble fades out while it does not.
var live := Callable()

var _singer: Villager
var _lines: Array = []
## Per line, the width of its text up to each letter (to colour the part sung).
var _widths: Array = []
## The line sung now (-1 before the first), its time and how long it has run.
var _line := -1
var _line_time := 1.0
var _elapsed := 0.0
var _alpha := 0.0
## Whether the verse is over, and the seconds until the bubble fades then.
var _over := false
var _ending := 0.0
## Where the bubble is: "above" the singer, "below", or to his "right" or "left".
var _where := "above"
## Where the tail's tip points, in the bubble's own coordinates.
var _tip := Vector2.ZERO
var _box := Vector2.ZERO
var _style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_style = StyleBoxFlat.new()
	_style.bg_color = PAPER
	_style.border_color = RIM
	_style.set_border_width_all(RIM_WIDTH)
	_style.set_corner_radius_all(RADIUS)
	_style.shadow_color = Color(0, 0, 0, 0.35)
	_style.shadow_size = 6
	_style.shadow_offset = Vector2(0, 3)
	_style.anti_aliasing = true
	_box = box_size()
	size = _box


static func _font_size() -> int:
	return UiKit.sized(FONT_SIZE)


static func _line_height() -> float:
	return FONT.get_height(_font_size())


## The bubble's size: room for the longest line of any song in German and in
## English, and for a whole verse. The same for every song and language.
static func box_size() -> Vector2:
	var widest := 0.0
	var most := 0
	for song in DrinkingSongs.SONGS:
		most = maxi(most, song.lines.size())
		for line: String in song.lines:
			for text: String in [line, Lang.EN.get(line, line)]:
				widest = maxf(widest, FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x)
	var height := most * _line_height() + (most - 1) * LINE_GAP
	return Vector2(ceilf(PAD.x * 2 + MARKER + widest), ceilf(PAD.y * 2 + height))


## Whether the bubble shows a song now (also while it fades out).
func shows() -> bool:
	return _singer != null and not _lines.is_empty()


## The lines of the verse shown, and the one sung now (-1 for none yet).
func lines() -> Array:
	return _lines.duplicate()


func line() -> int:
	return _line


## How much of the line sung now is coloured (0 to 1).
func progress() -> float:
	return clampf(_elapsed / maxf(0.01, _line_time * FILL_SHARE), 0.0, 1.0)


## Whether the bubble hangs below the singer (when above would cover the hero
## or his HUD).
func is_below() -> bool:
	return _where == "below"


## Where the bubble is: "above" the singer, "below", or to his "right" or "left".
func where() -> String:
	return _where


## `singer` sings line `index` of the verse `verse` (translated, without the
## song marks), for `time` seconds. A new verse replaces the one shown.
func sing(singer: Villager, verse: Array, index: int, time: float) -> void:
	if singer != _singer or verse != _lines:
		_singer = singer
		_lines = verse.duplicate()
		_widths.clear()
		for text: String in _lines:
			var widths := PackedFloat32Array([0.0])
			for i in text.length():
				widths.append(FONT.get_string_size(text.substr(0, i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x)
			_widths.append(widths)
		_box = box_size()
		size = _box
		_alpha = 0.0
		_spot = -1
	_line = index
	_line_time = maxf(0.01, time)
	_elapsed = 0.0
	_over = false
	visible = true
	step(0.0)


## The song is over. `cut`: broken off, so the bubble fades at once;
## otherwise the last line stays a moment for the eye to finish it.
func finish(cut := true) -> void:
	if not shows():
		return
	_over = true
	_ending = 0.0 if cut else LINGER


## Takes the bubble away at once.
func clear() -> void:
	_singer = null
	_lines.clear()
	_widths.clear()
	_line = -1
	_over = false
	_alpha = 0.0
	visible = false


func _process(delta: float) -> void:
	step(delta)


## Moves the song on by `delta` seconds and puts the bubble over the singer.
func step(delta: float) -> void:
	if not shows():
		visible = false
		return
	if not is_instance_valid(_singer) or not _singer.is_inside_tree():
		clear()
		return
	var running: bool = not live.is_valid() or live.call()
	if running:
		_elapsed += delta
	var want := 1.0
	if _over:
		if running:
			_ending -= delta
		if _ending <= 0.0:
			want = 0.0
	if not running:
		want = 0.0
	var anchors := _anchors()
	if anchors.is_empty():
		want = 0.0
	else:
		_place(anchors[0], anchors[1])
	var rate := (1.0 / FADE_IN) if want > _alpha else (1.0 / FADE_OUT)
	_alpha = move_toward(_alpha, want, rate * delta) if delta > 0.0 else _alpha
	if _over and _ending <= 0.0 and _alpha <= 0.0:
		clear()
		return
	modulate.a = _alpha
	visible = _alpha > 0.0 or want > 0.0
	queue_redraw()


## The screen points over the singer's head and at his feet ([] when he is
## off screen or behind the camera).
func _anchors() -> Array:
	if camera == null or not is_instance_valid(camera) or not _singer.is_visible_in_tree():
		return []
	var feet := SmoothMotion.drawn_at(_singer)
	var head := feet + Vector3(0, _singer.tag_height() + ABOVE_TAG, 0)
	if camera.is_position_behind(head) or camera.is_position_behind(feet):
		return []
	var head_s := camera.unproject_position(head)
	var feet_s := camera.unproject_position(feet)
	if not get_viewport_rect().has_point(feet_s) and not get_viewport_rect().has_point(head_s):
		return []
	return [head_s, feet_s]


## The spots tried for the bubble, best first. Each is [where the bubble is
## (above his head, beside him on the right or left, below his feet), and a
## shift as a share of the bubble's size].
const SPOTS := [["above", Vector2.ZERO], ["above", Vector2(-0.42, 0)], ["above", Vector2(0.42, 0)],
	["right", Vector2.ZERO], ["left", Vector2.ZERO], ["right", Vector2(0, -0.42)], ["left", Vector2(0, -0.42)],
	["right", Vector2(0, 0.42)], ["left", Vector2(0, 0.42)],
	["below", Vector2.ZERO], ["below", Vector2(-0.42, 0)], ["below", Vector2(0.42, 0)]]
## Room between the singer and a bubble beside him (pixels), past the tail.
const SIDE_ROOM := 22.0
## Which of SPOTS the bubble is at (-1: not placed yet).
var _spot := -1


## Puts the bubble at the first of SPOTS that keeps clear of the hero, his
## HUD and the event log, on screen, with the tail pointing at the singer.
func _place(head_s: Vector2, feet_s: Vector2) -> void:
	var blocked := _blocked()
	var best := 0
	var best_cover := INF
	var covers := []
	for i in SPOTS.size():
		var cover := _overlap(_spot_rect(i, head_s, feet_s), blocked)
		covers.append(cover)
		if cover < best_cover - 0.5:
			best = i
			best_cover = cover
	# Only move when the new spot is clearly better, so the bubble does not
	# jump to and fro while the hero walks past.
	if _spot < 0 or (covers[_spot] > 0.0 and best_cover < covers[_spot] * 0.5):
		_spot = best
	_where = SPOTS[_spot][0]
	var rect := _spot_rect(_spot, head_s, feet_s)
	position = rect.position.round()
	_tip = _spot_point(_where, head_s, feet_s) - position


## Where the tail points for a bubble at `where`: over the head, at the
## shoulders from the side, at the feet from below.
static func _spot_point(where: String, head_s: Vector2, feet_s: Vector2) -> Vector2:
	match where:
		"below":
			return feet_s
		"right", "left":
			return feet_s.lerp(head_s, 0.62)
	return head_s


func _spot_rect(i: int, head_s: Vector2, feet_s: Vector2) -> Rect2:
	var where: String = SPOTS[i][0]
	var point := _spot_point(where, head_s, feet_s)
	var pos := point - _box * 0.5 + (SPOTS[i][1] as Vector2) * _box
	match where:
		"above":
			pos.y = point.y - TAIL - _box.y
		"below":
			pos.y = point.y + TAIL
		"right":
			pos.x = point.x + SIDE_ROOM + TAIL
		"left":
			pos.x = point.x - SIDE_ROOM - TAIL - _box.x
	var screen := get_viewport_rect().grow_individual(-KEEP_FREE[0], -KEEP_FREE[1], -KEEP_FREE[2], -KEEP_FREE[3])
	pos.x = clampf(pos.x, screen.position.x, maxf(screen.position.x, screen.end.x - _box.x))
	pos.y = clampf(pos.y, screen.position.y, maxf(screen.position.y, screen.end.y - _box.y))
	return Rect2(pos, _box)


## What the bubble keeps off, each with how much covering it counts: the
## hero most, then the bars under him and the prompt beside him (drawn over
## the bubble), then the event log and the message lines over him. Pairs of
## [screen box, weight].
const HERO_WEIGHT := 4.0
const HUD_WEIGHT := 2.0


func _blocked() -> Array:
	var out := []
	if game == null:
		return out
	var hero: Node3D = game.get("player")
	if hero and hero.is_inside_tree() and not camera.is_position_behind(hero.global_position):
		# Where he stands: a tick off at most, which a box with room to spare
		# around him does not mind.
		var at := hero.global_position
		var feet := camera.unproject_position(at)
		var top := camera.unproject_position(at + Vector3(0, BODY_HEIGHT, 0))
		var height := absf(feet.y - top.y)
		out.append([Rect2(Vector2(feet.x - height * 0.4, minf(feet.y, top.y)), Vector2(height * 0.8, height * 1.15)).grow(6.0), HERO_WEIGHT])
	var log = game.get("event_log")
	if log is Control and log.is_visible_in_tree() and log.modulate.a > 0.05:
		out.append([(log as Control).get_global_rect(), 1.0])
	for method in ["message_rects", "hero_hud_rects"]:
		if game.has_method(method):
			for r: Rect2 in game.call(method):
				out.append([r.grow(6.0), HUD_WEIGHT if method == "hero_hud_rects" else 1.0])
	return out


static func _overlap(rect: Rect2, blocked: Array) -> float:
	var total := 0.0
	for b in blocked:
		total += (b[0] as Rect2).intersection(rect).get_area() * float(b[1])
	return total


func _draw() -> void:
	if not shows():
		return
	# The tail first, then the bubble over its root, then the tail's fill
	# again over the rim where it joins, so bubble and tail are one shape. The
	# tail leaves the bubble from the side that faces the singer.
	var half := TAIL_BASE * 0.5
	var root := Vector2.ZERO
	var along := Vector2.RIGHT
	var inward := Vector2.ZERO
	match _where:
		"above", "below":
			root = Vector2(clampf(_tip.x, RADIUS + half, _box.x - RADIUS - half), _box.y if _where == "above" else 0.0)
			inward = Vector2(0, -1 if _where == "above" else 1)
		_:
			root = Vector2(0.0 if _where == "right" else _box.x, clampf(_tip.y, RADIUS + half, _box.y - RADIUS - half))
			along = Vector2.DOWN
			inward = Vector2(1 if _where == "right" else -1, 0)
	var left := root - along * half
	var right := root + along * half
	draw_colored_polygon(PackedVector2Array([left, right, _tip]), RIM)
	draw_style_box(_style, Rect2(Vector2.ZERO, _box))
	var shrink := RIM_WIDTH * 1.4
	var back := ((_tip - left).normalized() + (_tip - right).normalized()).normalized()
	var deep := inward * (RIM_WIDTH + 1.0)
	draw_colored_polygon(PackedVector2Array([left + along * shrink + deep,
		right - along * shrink + deep, _tip - back * shrink * 2.2]), PAPER)

	var fs := _font_size()
	var line_h := _line_height()
	var ascent := FONT.get_ascent(fs)
	var x := PAD.x + MARKER
	for i in _lines.size():
		var y := PAD.y + i * (line_h + LINE_GAP)
		var text: String = _lines[i]
		var base := Vector2(x, y + ascent)
		if i == _line:
			_draw_note(Vector2(PAD.x + 6.0, y + line_h * 0.72), SUNG)
			var widths: PackedFloat32Array = _widths[i]
			var sung_w := widths[widths.size() - 1] * progress()
			var cut := 0
			while cut < text.length() and widths[cut + 1] <= sung_w + 0.5:
				cut += 1
			if cut > 0:
				draw_string(FONT, base, text.substr(0, cut), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SUNG)
			if cut < text.length():
				draw_string(FONT, base + Vector2(widths[cut], 0), text.substr(cut), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
		else:
			var a := PAST_ALPHA if i < _line else NEXT_ALPHA
			draw_string(FONT, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, a))


## A small eighth note with its head at `at`.
func _draw_note(at: Vector2, color: Color) -> void:
	draw_set_transform(at, -0.35, Vector2(1.3, 0.95))
	draw_circle(Vector2.ZERO, 4.2, color)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var stem := at + Vector2(4.8, -1.0)
	var top := stem + Vector2(0, -14.0)
	draw_line(stem, top, color, 2.0, true)
	draw_polyline(PackedVector2Array([top, top + Vector2(5.0, 4.0), top + Vector2(6.0, 9.0)]), color, 2.0, true)
