class_name SpeechBubble
extends Node3D
## A comic speech bubble over a person's head (villagers, see Villager, and
## people made in the map workshop, see DungeonNpc).
##
## The line is never one long row: it is wrapped into a compact block of a few
## short rows, with the speaker's name as a small heading row in the same
## bubble, so every row visibly belongs to one speaker. The bubble is a light
## paper panel with a dark rim and a tail that points straight down at the
## speaker (the same paper and ink as the comic words, see Comic and
## SongSheet). It always faces the camera, stays the same size on screen
## rows, and fades in and out as one piece.

const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const PIXEL_SIZE := 0.011
## Text size (at the game's text scale) of the line and of the name heading.
const TEXT_SIZE := 34
const NAME_SIZE := 26
## A title ("the Smith") sits under the name in a smaller size.
const TITLE_SIZE := 20
## Text widths (pixels) tried from the narrowest: the first that fits the line
## in at most MAX_ROWS rows wins, so short lines stay compact and long ones
## grow wider rather than taller.
const WIDTHS := [280, 340, 400]
const MAX_ROWS := 5
## Space between the text and the rim, and between the name and the line (metres).
const PAD := Vector2(0.28, 0.2)
const NAME_GAP := 0.08
const RADIUS := 0.3
const RIM := 0.05
const TAIL := Vector2(0.42, 0.4)
const PAPER := Color(1.0, 0.96, 0.86)
const RIM_COLOR := Color(0.06, 0.03, 0.06)
const INK := Color(0.16, 0.1, 0.08)
const NAME_INK := Color(0.62, 0.16, 0.05)
const FADE := 6.0

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;
uniform vec2 body = vec2(2.0, 1.0);
uniform float radius = 0.3;
uniform float rim = 0.05;
uniform vec2 tail = vec2(0.42, 0.4);
uniform vec4 paper : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform vec4 rim_color : source_color = vec4(0.06, 0.03, 0.06, 1.0);
uniform float alpha = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 size = body + vec2(0.0, tail.y);
	// Metres from the quad's centre, y up; the body sits on top, the tail below.
	vec2 p = (UV - 0.5) * size * vec2(1.0, -1.0);
	vec2 c = p - vec2(0.0, tail.y * 0.5);
	vec2 q = abs(c) - body * 0.5 + vec2(radius);
	float d_body = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	// The tail: a triangle from inside the body down to the tip.
	float tip = -size.y * 0.5;
	float top = -body.y * 0.5 + tail.y * 0.5 + 0.12;
	float half_w = tail.x * 0.5 * clamp((p.y - tip) / (top - tip), 0.0, 1.0);
	float d_tail = max(abs(p.x) - half_w, max(tip - p.y, p.y - top));
	float d = min(d_body, d_tail * 0.7);
	float aa = fwidth(d) * 1.2;
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float edge = 1.0 - smoothstep(-rim - aa, -rim + aa, d);
	vec3 col = mix(rim_color.rgb, paper.rgb, edge);
	ALBEDO = col;
	ALPHA = inside * alpha;
}
"""

var _panel: MeshInstance3D
var _material: ShaderMaterial
var _name: Label3D
var _title: Label3D
var _text: Label3D
## What is said, as "Name:\nline" (the log and the tests read it).
var text := ""
var _alpha := 0.0
var _target := 0.0
## The tail's tip sits at this node's origin: put the node where the bubble
## should touch the speaker.
var _size := Vector2.ZERO


func _init() -> void:
	visible = false


func _ready() -> void:
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	_material.shader = shader
	_material.render_priority = 20
	_material.set_shader_parameter("paper", PAPER)
	_material.set_shader_parameter("rim_color", RIM_COLOR)
	_material.set_shader_parameter("radius", RADIUS)
	_material.set_shader_parameter("rim", RIM)
	_material.set_shader_parameter("tail", TAIL)
	_panel = MeshInstance3D.new()
	_panel.mesh = QuadMesh.new()
	_panel.material_override = _material
	_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_panel)
	_name = _label(NAME_SIZE, NAME_INK)
	_title = _label(TITLE_SIZE, NAME_INK)
	_text = _label(TEXT_SIZE, INK)


func _label(size: int, colour: Color) -> Label3D:
	var l := Label3D.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.font = FONT
	l.font_size = UiKit.sized(size)
	l.pixel_size = PIXEL_SIZE
	l.outline_size = 0
	l.modulate = colour
	l.no_depth_test = true
	l.render_priority = 22
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(l)
	return l


## `text` broken into rows no wider than `width` pixels (words are never
## split, a single longer word keeps a row of its own).
static func wrap_rows(text: String, width: int) -> PackedStringArray:
	var size := UiKit.sized(TEXT_SIZE)
	var rows := PackedStringArray()
	var row := ""
	for word in text.split(" ", false):
		var tryout := word if row == "" else row + " " + word
		if row != "" and FONT.get_string_size(tryout, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			rows.append(row)
			row = word
		else:
			row = tryout
	if row != "":
		rows.append(row)
	return rows


## The rows of `text` at the narrowest width that sets it in at most MAX_ROWS
## rows (at the widest width when none does).
static func rows_for(text: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for w in WIDTHS:
		rows = wrap_rows(text, w)
		if rows.size() <= MAX_ROWS:
			break
	return rows


## Number of rows `text` takes.
static func rows_of(text: String) -> int:
	return rows_for(text).size()


## A villager's display name as [name, title]: "Hagen the Stonemason" (English)
## gives ["Hagen", "the Stonemason"], "Steinmetz Hagen" (German, title first)
## gives ["Hagen", "Steinmetz"]. A single word has an empty title.
static func split_speaker(speaker: String) -> PackedStringArray:
	var i := speaker.find(" the ")
	if i > 0:
		return PackedStringArray([speaker.substr(0, i), speaker.substr(i + 1)])
	i = speaker.find(" ")
	if i > 0:
		return PackedStringArray([speaker.substr(i + 1), speaker.substr(0, i)])
	return PackedStringArray([speaker, ""])


## Shows `text` said by `speaker`. With `titled` the speaker's name and title
## (see split_speaker) are set on two rows, which keeps the bubble narrow.
func show_line(speaker: String, text: String, titled := false) -> void:
	self.text = "%s:\n%s" % [speaker, text]
	var parts := split_speaker(speaker) if titled else PackedStringArray([speaker, ""])
	var rows := rows_for(text)
	var tsize := UiKit.sized(TEXT_SIZE)
	var nsize := UiKit.sized(NAME_SIZE)
	_text.text = "\n".join(rows)
	var widest := 0.0
	for r in rows:
		widest = maxf(widest, FONT.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x)
	var text_w := widest * PIXEL_SIZE
	var text_h := FONT.get_height(tsize) * rows.size() * PIXEL_SIZE
	_name.text = parts[0]
	_title.text = parts[1]
	_title.visible = parts[1] != ""
	var name_w := FONT.get_string_size(parts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, nsize).x * PIXEL_SIZE
	var name_h := FONT.get_height(nsize) * PIXEL_SIZE
	var tisize := UiKit.sized(TITLE_SIZE)
	var title_w := FONT.get_string_size(parts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, tisize).x * PIXEL_SIZE
	var title_h := FONT.get_height(tisize) * PIXEL_SIZE if parts[1] != "" else 0.0
	var inner_w := maxf(text_w, maxf(name_w, title_w))
	_size = Vector2(inner_w + PAD.x * 2.0, name_h + title_h + NAME_GAP + text_h + PAD.y * 2.0)
	_material.set_shader_parameter("body", _size)
	(_panel.mesh as QuadMesh).size = Vector2(_size.x, _size.y + TAIL.y)
	_panel.position.y = (_size.y + TAIL.y) * 0.5
	var top := TAIL.y + _size.y - PAD.y
	_name.position.y = top
	_title.position.y = top - name_h
	_text.position.y = top - name_h - title_h - NAME_GAP
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name.position.x = -name_w * 0.5
	_title.position.x = -title_w * 0.5
	_text.position.x = -text_w * 0.5
	visible = true
	_face_camera()
	_target = 1.0
	_alpha = 0.0
	_apply()


## A golden bubble (a flash of insight) in place of the paper one.
func set_gold(on: bool) -> void:
	_material.set_shader_parameter("paper", Color(1.0, 0.84, 0.3) if on else PAPER)


## Size of the bubble body in metres (without the tail).
func body_size() -> Vector2:
	return _size


## Fades out; with `at_once` it is gone without a fade.
func hide_line(at_once := false) -> void:
	_target = 0.0
	if at_once:
		_alpha = 0.0
		visible = false


func is_shown() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		return
	_face_camera()
	_alpha = move_toward(_alpha, _target, delta * FADE)
	_apply()
	if _alpha <= 0.0 and _target <= 0.0:
		visible = false


## The rows are laid out in the bubble's own plane, so the whole node turns to
## face the camera (the panel's shader does the same on its own).
func _face_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_basis = cam.global_basis


func _apply() -> void:
	_material.set_shader_parameter("alpha", _alpha)
	_name.modulate.a = _alpha
	_title.modulate.a = _alpha
	_text.modulate.a = _alpha
