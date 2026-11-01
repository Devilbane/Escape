class_name Horrors
extends CanvasLayer
## The nameless horrors: rare, huge monsters (see Enemy, "horror") that lurk
## in the creepy holes of the wild and, very rarely, deep in the dungeon.
## Nobody tells the hero about them. Before it shows itself a horror is only
## heard: a deep breathing in the dark, a word on the message line. The
## first time the hero sees one, time stalls for a heartbeat, the ground
## shakes, the edges of the screen run red and a bar at the top shows its
## life, under "???": nobody knows what it is. Only once one has fallen is it
## discovered: its name is spelled out across the screen and written into
## the compendium (see Game.learn), and from then on the bar shows its name.

## What each horror is called and what the compendium says about it, once
## discovered (the entry doubles as the mark that it is known).
const INFO := {
	"hohle_mutter": {"name": "Die Hohle Mutter",
		"lore": "Die Hohle Mutter: eine Spinne, so groß wie ein Fuhrwerk, hohl und uralt. Sie lauert in Löchern unter dem Wald, ihr Biss vergiftet, und ein Stich in den Rücken kitzelt sie nur."},
	"bleicher_waechter": {"name": "Der Bleiche Wächter",
		"lore": "Der Bleiche Wächter: ein riesiges, fahles Ding mit Fäusten wie Felsbrocken. Es wartet regungslos in der Tiefe, bis jemand nah genug ist, und schlägt härter zu als alles andere."},
	"schlund": {"name": "Der Schlund",
		"lore": "Der Schlund: eine schwarze, wabernde Masse, die unter alten Gräbern haust. Sie ist langsam, aber sie verschlingt, was sie erreicht, und ihr Gift brennt lange nach."},
}
const UNKNOWN := "???"
## The hero sees a horror for the first time within this distance (metres).
const REVEAL_RANGE := 18.0
## A horror is heard breathing in the dark from this far.
const DREAD_RANGE := 26.0
## The bar shows while the horror is this close.
const BAR_RANGE := 30.0
## The heartbeat when time stalls at the sight of one.
const STALL_SCALE := 0.3
const STALL_TIME := 0.8
const BAR_WIDTH := 460.0
const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const VIGNETTE := """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float edge = smoothstep(0.22, 0.78, d);
	COLOR = vec4(0.32, 0.0, 0.03, edge * strength);
}
"""

var game: Node
var level: Level
## The horror the bar is about right now.
var _shown: Enemy
var _seen := {}
var _dread_timer := 4.0
var _dread_said := false
var _flash := 0.0
var _vignette: ColorRect
var _box: VBoxContainer
var _name: Label
var _bar: ProgressBar
var _title: Label
var _subtitle: Label


func _init(owner_game: Node) -> void:
	game = owner_game
	layer = 3


func _ready() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = VIGNETTE
	_vignette.material = mat
	add_child(_vignette)

	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.offset_left = -BAR_WIDTH * 0.5
	_box.offset_right = BAR_WIDTH * 0.5
	_box.offset_top = 22
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 4)
	_box.modulate.a = 0.0
	add_child(_box)
	_name = _label(24, Color(0.85, 0.8, 0.9))
	_box.add_child(_name)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(BAR_WIDTH, 16)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.04, 0.02, 0.05, 0.85)
	back.border_color = Color(0.45, 0.4, 0.5, 0.9)
	back.set_border_width_all(2)
	back.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.06, 0.1)
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", back)
	_bar.add_theme_stylebox_override("fill", fill)
	_box.add_child(_bar)

	# The name of a horror just discovered, across the middle of the screen.
	var middle := VBoxContainer.new()
	middle.set_anchors_preset(Control.PRESET_FULL_RECT)
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)
	_title = _label(64, Color(0.9, 0.82, 0.62))
	_subtitle = _label(24, Color(0.85, 0.8, 0.9))
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	middle.add_child(_title)
	middle.add_child(_subtitle)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.03))
	l.add_theme_constant_override("outline_size", maxi(5, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A new level: forget the old one's horrors.
func watch(new_level: Level) -> void:
	level = new_level
	_shown = null
	_seen.clear()
	_dread_said = false
	_dread_timer = 4.0
	Engine.time_scale = 1.0
	level.enemy_killed.connect(_on_killed)


## Whether the hero already knows what this kind of horror is.
func known(kind: String) -> bool:
	return INFO.has(kind) and game.lore.has(INFO[kind].lore)


## What the bar calls it: its name once discovered, else "???".
func title_of(kind: String) -> String:
	return Lang.t(INFO[kind].name) if known(kind) else UNKNOWN


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 0.6)
	var near := INF
	var closest: Enemy = null
	if is_instance_valid(level) and level.player != null and game.state == game.State.PLAYING:
		var hero: Player = level.player
		for e in level.enemies:
			if not is_instance_valid(e) or e.dead or not e.is_horror():
				continue
			var d: float = e.global_position.distance_to(hero.global_position)
			if d < near:
				near = d
				closest = e
			if not _seen.has(e) and e.visible and d < REVEAL_RANGE and not hero.dead:
				_seen[e] = true
				_reveal(e)
		if closest != null and not _seen.has(closest) and near < DREAD_RANGE:
			_dread(delta, closest, near)
	# The red creeps in at the edges while one is near, and pulses like a
	# heartbeat once it hunts the hero.
	var dread := 0.0
	if closest != null and _seen.has(closest):
		dread = clampf(1.0 - near / BAR_RANGE, 0.0, 1.0) * 0.55
		if closest.is_hunting():
			dread *= 0.75 + 0.25 * absf(sin(Time.get_ticks_msec() * 0.0042))
	var strength := maxf(dread, _flash)
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", strength)
	_shown = closest if closest != null and _seen.has(closest) and near < BAR_RANGE else null
	var want: float = 1.0 if _shown != null and not game.menus.is_open() else 0.0
	_box.modulate.a = move_toward(_box.modulate.a, want, delta * 3.0)
	if _shown != null:
		_name.text = title_of(_shown.kind)
		_bar.max_value = _shown.max_hp()
		_bar.value = maxi(0, _shown.hp)


## Unseen, but heard: a deep breath somewhere in the dark.
func _dread(delta: float, e: Enemy, dist: float) -> void:
	_dread_timer -= delta
	if _dread_timer > 0.0:
		return
	var near := clampf(1.0 - dist / DREAD_RANGE, 0.0, 1.0)
	_dread_timer = lerpf(9.0, 4.0, near) * randf_range(0.8, 1.2)
	Sfx.play(level, "eerie_%d" % (randi() % 6), lerpf(-18.0, -4.0, near), e.global_position, 0.7)
	if not _dread_said:
		_dread_said = true
		game.show_message(Lang.t("Etwas Großes atmet in der Dunkelheit..."), 3.0)


## The first sight of it: time stalls, the ground shakes, the screen runs red.
func _reveal(e: Enemy) -> void:
	_flash = 1.0
	game._shake = 1.4
	Sfx.play(level, "rumble", 2.0, e.global_position)
	Sfx.play(level, "voice_koloss_%d" % (randi() % 2), 4.0, e.global_position, 0.4)
	Comic.pop(e.global_position + Vector3(0, 2.0, 0), "big")
	Effects.float_text(level, e.global_position + Vector3(0, 3.6 * float(Enemy.KINDS[e.kind].size), 0), "?!", Color(1.0, 0.25, 0.2), true)
	if known(e.kind):
		game.show_message(Lang.t("%s! Nicht schon wieder...") % Lang.t(INFO[e.kind].name), 3.0)
	else:
		game.show_message(Lang.t("Was... was ist DAS?!"), 3.0)
	e.alert(level.player.global_position)
	Engine.time_scale = STALL_SCALE
	get_tree().create_timer(STALL_TIME, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## One has fallen. The first of its kind is discovered: its name across the
## screen, and an entry in the compendium.
func _on_killed(e: Enemy) -> void:
	if not e.is_horror():
		return
	_flash = 0.6
	game._shake = 1.0
	Sfx.play(level, "rumble", 0.0, e.global_position)
	if known(e.kind):
		return
	game.learn(INFO[e.kind].lore)
	game.player.train("weisheit", 10.0)
	Sfx.play(game, "level_done", -1.0)
	_title.text = Lang.t(INFO[e.kind].name)
	_subtitle.text = Lang.t("Ein Grauen der Tiefe, nun nicht mehr namenlos. (Kompendium, Taste H)")
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_title, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.8).set_delay(0.4)
	tween.tween_interval(3.5)
	tween.tween_property(_title, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 1.0)
