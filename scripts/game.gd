extends Node3D
## Game flow: title screen, loading levels, HUD, camera and transitions.

const LEVEL_DIR := "res://levels/"
const CAMERA_PITCH := 54.0
const CAMERA_DISTANCE := 22.0
const TITLE_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")
const TEXT_FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const GOLD := Color(1.0, 0.82, 0.4)

enum State { TITLE, PLAYING, TRANSITION, WON }

var state := State.TITLE
var level_files: Array[String] = []
var level_index := 0
var level: Level
var player: Player
var camera: Camera3D
var coins := 0
var _hurt_cooldown := 0.0

var _hud: CanvasLayer
var _level_label: Label
var _coin_label: Label
var _key_label: Label
var _message: Label
var _fade: ColorRect
var _title: Control
var _title_text: Label
var _title_sub: Label
var _title_prompt: Label
var _message_tween: Tween


func _ready() -> void:
	for f in DirAccess.get_files_at(LEVEL_DIR):
		if f.ends_with(".txt"):
			level_files.append(LEVEL_DIR + f)
	level_files.sort()
	_setup_world()
	_setup_hud()
	player = Player.new()
	add_child(player)
	load_level(0)
	_show_title("Escape!", "Entkomme aus dem Verlies", "Klicken oder eine Taste drücken")


# --- Setup ------------------------------------------------------------------

func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.03, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.32, 0.58)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.045, 0.03, 0.07)
	env.fog_density = 1.0
	env.fog_depth_begin = 24.0
	env.fog_depth_end = 55.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Faint cold moonlight from above gives every stone a soft shadow.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-62, 28, 0)
	moon.light_color = Color(0.6, 0.65, 1.0)
	moon.light_energy = 0.28
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)

	camera = Camera3D.new()
	camera.fov = 38.0
	camera.rotation_degrees = Vector3(-CAMERA_PITCH, 0, 0)
	add_child(camera)

	var dust := Effects.make_dust()
	dust.name = "Dust"
	add_child(dust)


func _make_label(font: Font, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


func _setup_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		top.add_theme_constant_override("margin_" + side, 24)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(top)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	_level_label = _make_label(TEXT_FONT, 26, GOLD)
	row.add_child(_level_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_key_label = _make_label(TEXT_FONT, 24)
	row.add_child(_key_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(32, 0)
	row.add_child(gap)
	_coin_label = _make_label(TEXT_FONT, 24, GOLD)
	row.add_child(_coin_label)

	_message = _make_label(TEXT_FONT, 30)
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message.offset_bottom = -60
	_message.modulate.a = 0.0
	_hud.add_child(_message)

	var help := _make_label(TEXT_FONT, 16, Color(1, 1, 1, 0.55))
	help.text = "Bewegen: WASD / Pfeiltasten, oder einfach hinklicken bzw. tippen"
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_bottom = -16
	_hud.add_child(help)

	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.015, 0.04, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_fade)

	_title = VBoxContainer.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.alignment = BoxContainer.ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_title)
	_title_text = _make_label(TITLE_FONT, 120, GOLD)
	_title_sub = _make_label(TEXT_FONT, 34)
	_title_prompt = _make_label(TEXT_FONT, 22, Color(1, 1, 1, 0.75))
	for l in [_title_text, _title_sub, _title_prompt]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.add_child(l)
	_title_sub.custom_minimum_size = Vector2(0, 70)


func _update_hud() -> void:
	_level_label.text = "Ebene %d: %s" % [level_index + 1, level.level_name]
	_coin_label.text = "Gold: %d" % coins
	_key_label.text = "Schlüssel gefunden" if level.has_key else "Kein Schlüssel"
	_key_label.add_theme_color_override("font_color", GOLD if level.has_key else Color(1, 1, 1, 0.45))


# --- Flow -------------------------------------------------------------------

func load_level(index: int) -> void:
	if level:
		level.queue_free()
	level_index = index
	level = Level.new()
	level.load_from_file(level_files[index])
	add_child(level)
	level.build()
	level.player = player
	player.level = level
	player.path.clear()
	player.global_position = level.cell_to_world(level.start_cell)
	player.face(Vector3.BACK)
	player.controllable = true
	level.key_collected.connect(_on_key_collected)
	level.coins_collected.connect(_on_coins_collected)
	level.door_opened.connect(func(): show_message("Die Tür öffnet sich knarrend..."))
	level.door_locked.connect(func(): show_message("Verschlossen. Finde den Schlüssel!"))
	level.player_hurt.connect(_on_player_hurt)
	level.exit_reached.connect(_on_exit_reached)
	_snap_camera()
	_update_hud()


func _show_title(text: String, sub: String, prompt: String) -> void:
	_title_text.text = text
	_title_sub.text = sub
	_title_prompt.text = prompt
	_title.modulate.a = 0.0
	_fade.color.a = 0.55
	create_tween().tween_property(_title, "modulate:a", 1.0, 1.2)
	var blink := create_tween().set_loops()
	blink.tween_property(_title_prompt, "modulate:a", 0.3, 0.9)
	blink.tween_property(_title_prompt, "modulate:a", 1.0, 0.9)


func _start_playing() -> void:
	state = State.PLAYING
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(_fade, "color:a", 0.0, 0.8)
	_announce_level()


func _announce_level() -> void:
	show_message("Ebene %d: %s\n%s" % [level_index + 1, level.level_name, level.hint], 3.5)


func show_message(text: String, duration := 2.2) -> void:
	_message.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.25)
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.6)


func _on_key_collected() -> void:
	level.has_key = true
	player.play_once("PickUp", 0.6)
	show_message("Du hast den Schlüssel gefunden!")
	_update_hud()


func _on_coins_collected(amount: int) -> void:
	coins += amount
	if amount > 1:
		show_message("Eine Truhe voller Gold! +%d" % amount)
	_update_hud()


func _on_player_hurt() -> void:
	if _hurt_cooldown > 0.0 or state != State.PLAYING:
		return
	_hurt_cooldown = 1.6
	player.controllable = false
	player.path.clear()
	player.play_once("Hit_A", 0.7)
	show_message("Autsch! Zurück zum Anfang.")
	var tween := create_tween()
	_fade.color = Color(0.5, 0.02, 0.02, 0.0)
	tween.tween_property(_fade, "color:a", 0.5, 0.12)
	tween.tween_interval(0.45)
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.3)
	tween.tween_callback(func():
		player.global_position = level.cell_to_world(level.start_cell)
		_snap_camera()
		player.controllable = true)
	tween.tween_property(_fade, "color:a", 0.0, 0.4)


func _on_exit_reached() -> void:
	state = State.TRANSITION
	player.controllable = false
	player.path.clear()
	player.face(Vector3.FORWARD)
	player.play("Walking_A")
	var top := level.cell_to_world(level.exit_cell) + Vector3(0, 4.5, -4.5)
	var tween := create_tween()
	tween.tween_property(player, "global_position", top, 1.8)
	tween.parallel().tween_property(_fade, "color:a", 1.0, 1.6).set_delay(0.4)
	tween.tween_callback(_next_level)


func _next_level() -> void:
	if level_index + 1 >= level_files.size():
		state = State.WON
		_show_title("Frei!", "Du bist entkommen und hast %d Gold erbeutet." % coins, "Klicken für ein neues Spiel")
		return
	load_level(level_index + 1)
	state = State.PLAYING
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
	_announce_level()


# --- Per frame --------------------------------------------------------------

func _camera_offset() -> Vector3:
	var pitch := deg_to_rad(CAMERA_PITCH)
	return Vector3(0, sin(pitch), cos(pitch)) * CAMERA_DISTANCE + Vector3(0, 1.0, 0)


func _snap_camera() -> void:
	camera.global_position = player.global_position + _camera_offset()


func _process(delta: float) -> void:
	_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)
	var target := player.global_position + _camera_offset()
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.0 * delta))
	var dust := get_node("Dust") as Node3D
	dust.global_position = player.global_position + Vector3(0, 2.0, 0)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed:
		return
	match state:
		State.TITLE:
			_start_playing()
		State.WON:
			coins = 0
			state = State.TRANSITION
			var tween := create_tween()
			tween.tween_property(_title, "modulate:a", 0.0, 0.4)
			tween.tween_callback(func():
				load_level(0)
				_start_playing())
		State.PLAYING:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				var origin := camera.project_ray_origin(event.position)
				var dir := camera.project_ray_normal(event.position)
				if dir.y < -0.01:
					player.walk_to(origin + dir * (-origin.y / dir.y))
