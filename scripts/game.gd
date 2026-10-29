extends Node3D
## Game flow: title screen, loading levels, HUD, input, camera and transitions.

const LEVEL_DIR := "res://levels/"
const CAMERA_PITCH := 54.0
## Far enough out to show about half again as much dungeon as a close view.
const CAMERA_DISTANCE := 27.0
const TITLE_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")
const TEXT_FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const GOLD := Color(1.0, 0.82, 0.4)
## Raised by hand for every bigger update. The build number comes from GitHub.
const VERSION := "0.3"

enum State { TITLE, PLAYING, TRANSITION, WON }

var state := State.TITLE
var level_files: Array[String] = []
var level_index := 0
var level: Level
var player: Player
var camera: Camera3D
var coins := 0

var _hud: CanvasLayer
var _level_label: Label
var _coin_label: Label
var _key_label: Label
var _hp_label: Label
var _knife_label: Label
var _prompt: Label
var _message: Label
var _fade: ColorRect
var _title: Control
var _title_text: Label
var _title_sub: Label
var _title_prompt: Label
var _message_tween: Tween
var _pending_search := {}


func _ready() -> void:
	for f in DirAccess.get_files_at(LEVEL_DIR):
		if f.ends_with(".txt"):
			level_files.append(LEVEL_DIR + f)
	level_files.sort()
	_setup_world()
	_setup_hud()
	player = Player.new()
	add_child(player)
	player.hurt.connect(_on_player_hurt)
	player.defeated.connect(_on_player_defeated)
	load_level(_start_level())
	_show_title("Escape!", "Entkomme aus dem Verlies", "Klicken oder eine Taste drücken")


## Lets a link like .../Escape/?level=3 jump straight to a level.
func _start_level() -> int:
	if OS.has_feature("web"):
		var param = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('level')")
		if param is String and param.is_valid_int():
			return clampi(int(param) - 1, 0, level_files.size() - 1)
	return 0


# --- Setup ------------------------------------------------------------------

func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.32, 0.58)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
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
	moon.directional_shadow_max_distance = 70.0
	add_child(moon)

	camera = Camera3D.new()
	camera.fov = 38.0
	camera.far = 200.0
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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(118, 64)
	b.add_theme_font_override("font", TEXT_FONT)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.05, 0.1, 0.72)
	normal.border_color = Color(0.85, 0.66, 0.32, 0.8)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.3, 0.2, 0.1, 0.85)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.button_down.connect(action)
	return b


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
	row.add_theme_constant_override("separation", 28)
	top.add_child(row)
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	_level_label = _make_label(TEXT_FONT, 26, GOLD)
	left.add_child(_level_label)
	_hp_label = _make_label(TEXT_FONT, 24, Color(1.0, 0.45, 0.42))
	left.add_child(_hp_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_key_label = _make_label(TEXT_FONT, 22)
	row.add_child(_key_label)
	_knife_label = _make_label(TEXT_FONT, 22, Color(0.8, 0.88, 1.0))
	row.add_child(_knife_label)
	_coin_label = _make_label(TEXT_FONT, 22, GOLD)
	row.add_child(_coin_label)

	_prompt = _make_label(TEXT_FONT, 22, Color(1, 1, 1, 0.9))
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = 70
	_hud.add_child(_prompt)

	_message = _make_label(TEXT_FONT, 30)
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message.offset_bottom = -175
	_message.modulate.a = 0.0
	_hud.add_child(_message)

	var help := _make_label(TEXT_FONT, 15, Color(1, 1, 1, 0.55))
	help.text = "WASD: laufen   Leertaste: springen   F: Schlag   R: Wurfmesser   E: untersuchen\nMaus: hinklicken zum Laufen und Untersuchen, Rechtsklick wirft ein Messer"
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_left = 24
	help.offset_bottom = -26
	_hud.add_child(help)

	var version := _make_label(TEXT_FONT, 14, Color(1, 1, 1, 0.4))
	version.text = _version_text()
	version.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.grow_horizontal = Control.GROW_DIRECTION_BOTH
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_bottom = -4
	_hud.add_child(version)

	var buttons := GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_theme_constant_override("v_separation", 10)
	buttons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buttons.offset_right = -20
	buttons.offset_bottom = -20
	_hud.add_child(buttons)
	buttons.add_child(_make_button("Suchen", _search_nearby))
	buttons.add_child(_make_button("Springen", func(): if state == State.PLAYING: player.jump()))
	buttons.add_child(_make_button("Werfen", func(): if state == State.PLAYING: player.throw_knife()))
	buttons.add_child(_make_button("Schlagen", func(): if state == State.PLAYING: player.melee()))

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
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_title.add_child(l)
	_title_sub.custom_minimum_size = Vector2(0, 70)


func _version_text() -> String:
	var text := "Version " + VERSION
	if FileAccess.file_exists("res://build_info.txt"):
		text += " · Build " + FileAccess.get_file_as_string("res://build_info.txt").strip_edges()
	return text


func _update_hud() -> void:
	_level_label.text = "Ebene %d: %s" % [level_index + 1, level.level_name]
	_hp_label.text = "Leben: %d / %d" % [maxi(0, player.hp), Player.MAX_HP]
	_coin_label.text = "Gold: %d" % coins
	_knife_label.text = "Messer: %d" % player.knives
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
	player.frozen = false
	player.controllable = true
	player.revive(level.cell_to_world(level.start_cell))
	player.face(Vector3.BACK)
	level.key_collected.connect(_on_key_collected)
	level.coins_collected.connect(_on_coins_collected)
	level.door_opened.connect(func(): show_message("Die Tür öffnet sich knarrend..."))
	level.door_locked.connect(func(): show_message("Verschlossen. Finde den Schlüssel!"))
	level.player_hurt.connect(func(): player.take_damage(1, player.global_position - player.facing()))
	level.enemy_killed.connect(func(): show_message("Das Skelett zerfällt zu Staub.", 1.4))
	level.exit_reached.connect(_on_exit_reached)
	_pending_search = {}
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
	_update_hud()


func _search_nearby() -> void:
	if state != State.PLAYING or not player.can_act():
		return
	var obj := level.nearest_interactable(player.global_position)
	if obj.is_empty():
		Effects.float_text(level, player.global_position + Vector3(0, 3.2, 0), "Hier gibt es nichts", Color(1, 1, 1, 0.8))
		return
	_search(obj)


func _search(obj: Dictionary) -> void:
	_pending_search = {}
	player.path.clear()
	player.face(obj.pos - player.global_position)
	if obj.searched:
		Effects.float_text(level, obj.icon_pos, "Schon durchsucht", Color(0.8, 0.8, 0.8))
		return
	player.play_once("Interact", 0.55)
	var loot := level.search(obj)
	var text := "%s: leer" % obj.label
	var color := Color(0.8, 0.8, 0.85)
	if loot.has("gold"):
		coins += loot.gold
		text = "+%d Gold" % loot.gold
		color = GOLD
	elif loot.has("knives"):
		player.knives += loot.knives
		text = "+%d Wurfmesser" % loot.knives
		color = Color(0.8, 0.9, 1.0)
	elif loot.has("potion"):
		player.hp = mini(Player.MAX_HP, player.hp + 2)
		text = "Heiltrank! +2 Leben"
		color = Color(1.0, 0.5, 0.55)
	Effects.float_text(level, obj.icon_pos, text, color)
	if loot.is_empty():
		show_message("Du durchsuchst %s... nichts." % _with_article(obj.label), 1.2)
	_update_hud()


func _with_article(label: String) -> String:
	match label:
		"Fass": return "das Fass"
		"Regal": return "das Regal"
		"Kiste": return "die Kiste"
		"Truhe", "Schatztruhe": return "die Truhe"
		"Tisch": return "den Tisch"
	return label


func _on_player_hurt(_amount: int) -> void:
	_update_hud()
	var tween := create_tween()
	_fade.color = Color(0.6, 0.02, 0.02, 0.0)
	tween.tween_property(_fade, "color:a", 0.35, 0.08)
	tween.tween_property(_fade, "color:a", 0.0, 0.35)


func _on_player_defeated() -> void:
	state = State.TRANSITION
	show_message("Du wurdest besiegt... und erwachst am Eingang.", 2.5)
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.6)
	tween.tween_callback(func():
		player.revive(level.cell_to_world(level.start_cell))
		_snap_camera()
		_update_hud()
		state = State.PLAYING)
	tween.tween_property(_fade, "color:a", 0.0, 0.6)


func _on_exit_reached() -> void:
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	player.face(Vector3.FORWARD)
	player.play("Walking_A")
	var top := level.cell_to_world(level.exit_cell) + Vector3(0, 4.5, -4.5)
	var tween := create_tween()
	tween.tween_property(player, "global_position", top, 1.8)
	tween.parallel().tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 1.6).set_delay(0.4)
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
	var p := player.global_position
	p.y = 0.0
	camera.global_position = p + _camera_offset()


func _process(delta: float) -> void:
	var p := player.global_position
	p.y = minf(p.y, 0.5) if not player.frozen else p.y
	var target := p + _camera_offset()
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.0 * delta))
	var dust := get_node("Dust") as Node3D
	dust.global_position = player.global_position + Vector3(0, 2.0, 0)
	if state != State.PLAYING:
		_prompt.text = ""
		return
	if not _pending_search.is_empty() and player.path.is_empty() and player.can_act():
		var reach := Vector2(player.global_position.x - _pending_search.pos.x, player.global_position.z - _pending_search.pos.z).length()
		if reach <= Level.SEARCH_RANGE + 0.3:
			_search(_pending_search)
		_pending_search = {}
	var near := level.nearest_interactable(player.global_position)
	_prompt.text = "E: %s untersuchen" % _with_article(near.label) if not near.is_empty() and not near.searched else ""


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed:
		return
	match state:
		State.TITLE:
			_start_playing()
		State.WON:
			coins = 0
			player.knives = 5
			state = State.TRANSITION
			var tween := create_tween()
			tween.tween_property(_title, "modulate:a", 0.0, 0.4)
			tween.tween_callback(func():
				load_level(0)
				_start_playing())
		State.PLAYING:
			if event is InputEventKey:
				match event.physical_keycode:
					KEY_SPACE:
						player.jump()
					KEY_F, KEY_J:
						player.melee()
					KEY_R, KEY_K:
						player.throw_knife()
					KEY_E:
						_search_nearby()
			elif event is InputEventMouseButton:
				var point = _mouse_to_floor(event.position)
				if point == null:
					return
				if event.button_index == MOUSE_BUTTON_RIGHT:
					player.throw_knife(point)
				elif event.button_index == MOUSE_BUTTON_LEFT:
					_click(point)


func _mouse_to_floor(screen_pos: Vector2):
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if dir.y > -0.01:
		return null
	return origin + dir * (-origin.y / dir.y)


func _click(point: Vector3) -> void:
	# Clicking an enemy attacks it, clicking an object searches it.
	for e in level.enemies:
		if is_instance_valid(e) and not e.dead and e.visible and Vector2(e.global_position.x - point.x, e.global_position.z - point.z).length() < 1.6:
			if player.global_position.distance_to(e.global_position) < Player.MELEE_RANGE + 1.0:
				player.melee()
			else:
				player.throw_knife(e.global_position)
			return
	var obj := level.nearest_interactable(point, 2.2)
	if not obj.is_empty():
		_pending_search = obj
		player.walk_to(obj.pos)
		return
	_pending_search = {}
	player.walk_to(point)
