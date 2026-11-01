extends Node3D
## Game flow: title screen, loading levels, HUD, input, camera and transitions.

const LEVEL_DIR := "res://levels/"
const CAMERA_PITCH := 54.0
## Far enough out to show about half again as much dungeon as a close view.
const CAMERA_DISTANCE := 27.0
## Fully zoomed in (mouse wheel, + and -): close and low, to see the hero's face.
const CLOSE_PITCH := 22.0
const CLOSE_DISTANCE := 7.5
const ZOOM_STEP := 0.12
## How many zoom steps the camera can pull back beyond the normal view.
const ZOOM_OUT_STEPS := 2
const TITLE_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")
const TEXT_FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const GOLD := Color(1.0, 0.82, 0.4)
## Raised by hand for every bigger update. The build number comes from GitHub.
const VERSION := "0.5"
## Filled in by GitHub with the number of each published build, so the
## version shown in the game changes with every update.
const BUILD := ""
## Every hero has a saved game of their own, in this folder, one file each.
const SAVE_DIR := "user://spielstaende/"
## Before there could be several saved games there was just this one file;
## on the first start it moves into SAVE_DIR.
const OLD_SAVE_FILE := "user://spielstand.json"

enum State { TITLE, PLAYING, TRANSITION, WON, OVER }

var state := State.TITLE
var _sound_button: Button
var _music_button: Button
var _music_slider: HSlider
## The pull-out menu on the right edge of the screen that holds all the
## clickable buttons, its handle, and how far it is pulled out (0 to 1).
var _drawer: HBoxContainer
var _drawer_handle: Button
var _drawer_open := false
var _drawer_t := 0.0
var _drawer_tween: Tween
var level_files: Array[String] = []
var level_index := 0
var level: Level
var player: Player
var camera: Camera3D
var _env: Environment
var _moon: DirectionalLight3D
## The time of day above ground, in hours (see DayNight). Saved with the game.
var day_hour := DayNight.START_HOUR
## The clock as the HUD shows it right now.
var _clock_shown := ""
## The weather above ground (see Weather) and how many hours of the day it
## still lasts. Both are saved with the game.
var weather := Weather.CLEAR
var weather_hours := Weather.FIRST_HOURS
var _weather_rng := RandomNumberGenerator.new()
## The look of the sky as it moves towards the weather's own, and a stroke
## of lightning as it fades (1 to 0).
var _weather_look := Weather.look(Weather.CLEAR)
var _flash := 0.0
## The rain that falls and the mist that drifts around the hero, and the
## patter of the rain.
var _rain: CPUParticles3D
var _mist: CPUParticles3D
var _rain_sound: AudioStreamPlayer
var _ambience: AudioStreamPlayer
## Set once the hero has stepped out of the crypt into the open air: the run
## is in the ranking as an escape, and goes on in the village.
var escaped := false
## Whether the village elder has given the hero a house.
var home_given := false
## Set once the hero has walked into that house and made it their own: from
## then on it is where every saved game starts.
var home_claimed := false
## The villagers the hero has talked to, by role letter -> true. Once met,
## a villager wears their name over their head. Kept in the saved game.
var met := {}
## The villagers' tasks: offered, running and finished (see Quests). Kept in
## the saved game, so every hero has their own.
var quests := Quests.new(self)
## How many mornings have dawned in the world above ground since the game
## began. The bounty board pins up fresh hunts each morning (see Bounties).
var day := 0
## The hunts on the bounty board: posted, taken on and paid (see Bounties).
## Kept in the saved game.
var bounties := Bounties.new(self)
## Known recipes and the ingredient pouch (see Crafting). Kept in the saved
## game, like the quests.
var crafting := Crafting.new(self)
## The line in the water, when the hero is fishing (see Fishing).
var fishing := Fishing.new(self)
## Counts down to the next look at who has a task (see refresh_quest_marks).
var _quest_mark_timer := 0.0
## Village buildings with floors of their own: building letter -> level index.
var interiors := {}
var coins := 0
## Iron bars for the smith's forge (see Forge), counted like gold.
var iron := 0
## What the hero already took on each level, by level file: the ids of
## searched furniture and picked up coins (see Level.taken). Kept in the
## saved game, so looted chests stay empty.
var looted := {}
## The stone blocks the hero built with on each level, by level file (see
## Level.built). Kept in the saved game, so buildings stay standing.
var builds := {}
## Secret rooms found this run; each one sharpens the eye for the next lever.
var secrets_found := 0
## Levels left in a row without finding their secret room.
var dry_levels := 0
## Lives the hero gets back for climbing to the next level.
const STAIRS_HEAL := 5
## From this level on (counting from 0) a run that has found no secret room
## yet gets one for sure, and never more than this many levels pass without.
const FIRST_SURE_SECRET := 2
const MAX_DRY_LEVELS := 4
## Seconds of camera shake left.
var _shake := 0.0
## 0 is the normal view from above, 1 the close view; _zoom eases toward the target.
var _zoom := 0.0
var _zoom_target := 0.0

var _hud: CanvasLayer
var _level_label: Label
var _coin_label: Label
var _key_label: Label
var _hp_label: Label
## The run meter: seconds of running left, as a bar and in numbers.
var _run_bar: ProgressBar
var _run_label: Label
var _run_fill: StyleBoxFlat
var _gift_label: Label
var _shrine_panel: Control
## The fourth shrine gift, offered only to a wise hero.
var _wise_gift: Button
var _shrine: Dictionary = {}
var _pending_station: Dictionary = {}
## Everything the hero has been told so far, for the compendium (key H):
## level hints ("#<index>") and explanatory tips, in the order they came.
var lore: Array = []
var _knife_label: Label
var _prompt: Label
var _message: Label
## Space kept free left and right of centred on-screen texts.
const SCREEN_TEXT_MARGIN := 80
const MESSAGE_FONT_SIZE := 30
var _fade: ColorRect
var _title: Control
var _title_text: Label
var _title_sub: Label
var _title_prompt: Label
var _message_tween: Tween
var _pending_search := {}
## A crate the hero was sent to pick up with a click (see Crate).
var _pending_crate: Crate = null
var menus: Menus
## Items left in the safe room's storage chest, and what the merchant sells.
var storage: Array[String] = []
var shop_stock: Array[String] = []
var _title_buttons: Control
var _name_note: Label
## The hero's name, asked for when a new game starts; it goes into the ranking.
var hero_name := ""
var _name_box: Control
## The day the hero lives over and over while the player is away (see
## Offline), planned at the refuge's bed and kept in the saved game.
var away_plan := Offline.empty_plan()
## What the hero did while the player was away, line by line, for the
## welcome-back window.
var away_report: Array[String] = []
var _name_edit: LineEdit
## The body chosen for the new hero, and the buttons to pick it (see BodyLook).
var _new_sex := BodyLook.DEFAULT
var _sex_buttons := {}
var _name_ask: Label
var _ranking_slot: Control
var _lang_row: Control
## Engine flag set when a language is picked: it survives the scene reload,
## so the fresh title goes straight on to the name entry.
const ASK_NAME_FLAG := &"escape_ask_name_after_reload"
## Holding the left mouse button this long turns a click into running.
const HOLD_TO_RUN := 0.2
## How close to a clicked object's middle the hero walks before using it:
## half its size plus the hero's own width.
const WALK_UP_TO := 2.0
var _mouse_held := false
var _mouse_held_time := 0.0
## A stone block grabbed with the left mouse button and being dragged (see
## StoneBlock): the block, the see-through block showing where it would
## land, which way it lies there, where it lands, and how long it is held.
var _drag_stone: StoneBlock = null
var _drag_ghost: MeshInstance3D = null
var _drag_along_x := true
var _drag_spot := {}
var _drag_time := 0.0
var _drag_press := Vector2.ZERO
## A press shorter than this, without moving the block, is a click on it.
const DRAG_CLICK := 0.25
const HEAVY_LEARN := "Alte, schwere Steinblöcke liegen in manchen Kammern des Verlieses. In die Tasche passen sie nicht, aber sie rutschen über den Boden: E (oder ein Klick) schiebt einen ein Stück von dir weg, mit der Maus ziehst du ihn geradeaus, bis er anstößt. Liegt auf jeder Druckplatte einer Kammer ein Block, öffnet sich ihr Eisengitter."
const STONE_LEARN := "Steinblöcke kauft man beim Steinmetz im Dorf. Abstellen mit B (oder „Abstellen“ im Inventar): der Block legt sich quer vor dich, auf den Boden oder auf andere Blöcke. Mit der linken Maustaste greifst du einen Block, ziehst ihn auf ein anderes Feld in der Nähe und lässt los; ein Rechtsklick dabei dreht ihn. E nimmt einen Block wieder in die Tasche. Auf einen Block steigst du einfach hinauf, auf zwei mit einem Sprung. Skelette und Räuber können nicht klettern: Eine Mauer aus Blöcken hält sie fern, und sie müssen außen herum."


func _ready() -> void:
	Lang.setup()
	_move_old_save()
	for f in DirAccess.get_files_at(LEVEL_DIR):
		if f.ends_with(".txt"):
			level_files.append(LEVEL_DIR + f)
	level_files.sort()
	for i in level_files.size():
		for line in FileAccess.get_file_as_string(level_files[i]).split("\n"):
			if line.begins_with("building:") and not interiors.has(line.substr(9).strip_edges()):
				interiors[line.substr(9).strip_edges()] = i
	_setup_world()
	_setup_hud()
	var comic := Comic.new()
	comic.camera = camera
	add_child(comic)
	menus = Menus.new()
	add_child(menus)
	Sfx.load_settings()
	Sfx.watch_focus(self)
	_update_sound_button()
	_ambience = Sfx.start_ambience(self)
	_rain_sound = Sfx.start_loop(self, "rain")
	Music.load_settings()
	Music.start(self)
	_update_music_controls()
	menus.setup(self, _hud)
	player = Player.new()
	add_child(player)
	player.hurt.connect(_on_player_hurt)
	player.ailments_changed.connect(_update_hud)
	player.defeated.connect(_on_player_defeated)
	player.bumped.connect(_on_player_bumped)
	player.trained.connect(_on_player_trained)
	load_level(_start_level())
	_show_start_title("Escape!", Lang.t("Entkomme aus dem Verlies"))
	if Engine.has_meta(ASK_NAME_FLAG):
		# A language was just chosen: no extra click, the hero's name comes next.
		Engine.remove_meta(ASK_NAME_FLAG)
		new_game()


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
	env.ambient_light_color = Color(0.42, 0.40, 0.37)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A touch under neutral: the picture reads calmer and highlights keep
	# their detail. Torch pools in the dungeon still stand out against the
	# dark, as stealth only cares about the light geometry, not the exposure.
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.0
	_env = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Faint pale moonlight from above gives every stone a soft shadow.
	var moon := DirectionalLight3D.new()
	_moon = moon
	moon.rotation_degrees = Vector3(-62, 28, 0)
	moon.light_color = Color(0.82, 0.84, 0.9)
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

	_weather_rng.randomize()
	_rain = Weather.make_rain()
	add_child(_rain)
	_mist = Weather.make_mist()
	add_child(_mist)


## Dark dungeon air, or in the open the sky of the hour (see DayNight:
## by day the warm autumn light, at night a cool blue moonlight).
func _set_atmosphere(outdoor: bool) -> void:
	if outdoor:
		DayNight.apply(_env, _moon, day_hour)
		# Out in the open the weather is there at once, without a fade.
		_weather_look = Weather.look(weather)
		Weather.apply(_env, _moon, _weather_look)
	else:
		Weather.clear_air(_env)
		_env.background_color = Color(0, 0, 0)
		_env.ambient_light_color = Color(0.42, 0.40, 0.37)
		_env.ambient_light_energy = 0.3
		_env.adjustment_saturation = 1.0
		_moon.rotation_degrees = Vector3(-62, 28, 0)
		_moon.light_color = Color(0.82, 0.84, 0.9)
		_moon.light_energy = 0.28
	# No dripping cave water under the open sky.
	if _ambience:
		_ambience.volume_db = -30.0 if outdoor else -8.0


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


## All clickable buttons live in a menu that is pulled out from the right
## edge of the screen: click the handle (or press Tab) to slide it in, and
## again to slide it away. Only the handle shows while it is closed.
func _setup_drawer() -> void:
	_drawer = HBoxContainer.new()
	_drawer.add_theme_constant_override("separation", 0)
	_drawer.anchor_left = 1.0
	_drawer.anchor_right = 1.0
	_drawer.anchor_top = 0.5
	_drawer.anchor_bottom = 0.5
	_drawer.grow_vertical = Control.GROW_DIRECTION_BOTH
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_drawer)

	_drawer_handle = _make_button("", toggle_drawer)
	_drawer_handle.custom_minimum_size = Vector2(70, 120)
	_drawer_handle.add_theme_font_size_override("font_size", 16)
	_drawer_handle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for style in ["normal", "hover", "pressed"]:
		var box: StyleBoxFlat = _drawer_handle.get_theme_stylebox(style).duplicate()
		box.corner_radius_top_right = 0
		box.corner_radius_bottom_right = 0
		_drawer_handle.add_theme_stylebox_override(style, box)
	_drawer.add_child(_drawer_handle)

	var panel := PanelContainer.new()
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.03, 0.07, 0.85)
	back.border_color = Color(0.85, 0.66, 0.32, 0.8)
	back.set_border_width_all(2)
	back.border_width_right = 0
	back.corner_radius_bottom_left = 14
	back.corner_radius_top_left = 14
	back.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", back)
	_drawer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var buttons := GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_theme_constant_override("v_separation", 10)
	column.add_child(buttons)
	# Buttons that open a window also push the menu away again; the others
	# (actions and sound) leave it out so they can be clicked again.
	var windows := [["Inventar", "inventar"], ["Charakter", "charakter"], ["Kompendium", "kompendium"], ["Laden", "laden"]]
	for w in windows:
		buttons.add_child(_make_button(Lang.t(w[0]), _open_from_drawer.bind(w[1])))
	buttons.add_child(_make_button(Lang.t("Springen"), func(): if state == State.PLAYING: player.jump()))
	buttons.add_child(_make_button(Lang.t("Werfen"), func(): if state == State.PLAYING: player.throw_knife()))
	buttons.add_child(_make_button(Lang.t("Schlagen"), func(): if state == State.PLAYING: player.melee()))
	buttons.add_child(_make_button(Lang.t("Kiste"), func(): if state == State.PLAYING and not menus.is_open(): crate_action()))
	buttons.add_child(_make_button(Lang.t("Stein"), func(): if state == State.PLAYING and not menus.is_open(): stone_action()))
	buttons.add_child(_make_button(Lang.t("Angeln"), fish_action))
	_sound_button = _make_button("", _toggle_sound)
	buttons.add_child(_sound_button)
	_update_sound_button()
	_music_button = _make_button("", _toggle_music)
	buttons.add_child(_music_button)
	buttons.add_child(_make_button(Lang.t("Beenden"), func():
		set_drawer_open(false)
		_on_quit_pressed()))
	for b in buttons.get_children():
		b.custom_minimum_size = Vector2(150, 58)
		b.add_theme_font_size_override("font_size", 18)
	column.add_child(_make_music_slider())
	_update_music_controls()
	_update_drawer_handle()
	_place_drawer(0.0)
	# Keeps the menu in place when a button's text changes its size.
	_drawer.minimum_size_changed.connect(func(): _place_drawer(_drawer_t))


func _open_from_drawer(menu: String) -> void:
	if state == State.PLAYING and player.can_act() and not menus.is_open():
		set_drawer_open(false)
		menus.open(menu)


func toggle_drawer() -> void:
	set_drawer_open(not _drawer_open)


func is_drawer_open() -> bool:
	return _drawer_open


## Slides the pull-out menu in or out.
func set_drawer_open(open: bool) -> void:
	if _drawer == null or open == _drawer_open:
		return
	_drawer_open = open
	_update_drawer_handle()
	if _drawer_tween:
		_drawer_tween.kill()
	_drawer_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_method(_place_drawer, _drawer_t, 1.0 if open else 0.0, 0.25)


## Puts the menu `t` of the way out: 0 shows only the handle, 1 all of it.
func _place_drawer(t: float) -> void:
	_drawer_t = t
	var size := _drawer.get_combined_minimum_size()
	var hidden := size.x - _drawer_handle.get_combined_minimum_size().x
	_drawer.offset_left = -size.x + hidden * (1.0 - t)
	_drawer.offset_right = _drawer.offset_left + size.x
	_drawer.offset_top = -size.y / 2.0
	_drawer.offset_bottom = size.y / 2.0


func _update_drawer_handle() -> void:
	_drawer_handle.text = (">\n" if _drawer_open else "<\n") + Lang.t("Menü")


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
	var run_row := HBoxContainer.new()
	run_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_row.add_theme_constant_override("separation", 10)
	left.add_child(run_row)
	_run_bar = ProgressBar.new()
	_run_bar.show_percentage = false
	_run_bar.custom_minimum_size = Vector2(170, 14)
	_run_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_run_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.05, 0.1, 0.72)
	back.border_color = Color(0.85, 0.66, 0.32, 0.8)
	back.set_border_width_all(2)
	back.set_corner_radius_all(6)
	_run_fill = StyleBoxFlat.new()
	_run_fill.set_corner_radius_all(6)
	_run_bar.add_theme_stylebox_override("background", back)
	_run_bar.add_theme_stylebox_override("fill", _run_fill)
	run_row.add_child(_run_bar)
	_run_label = _make_label(TEXT_FONT, 18, Color(0.75, 0.95, 0.6))
	run_row.add_child(_run_label)
	_gift_label = _make_label(TEXT_FONT, 18, Color(0.65, 0.85, 1.0))
	left.add_child(_gift_label)
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


	# Centred texts span the screen width (minus a margin) and wrap onto
	# further lines instead of running off both edges.
	_prompt = _make_label(TEXT_FONT, 22, Color(1, 1, 1, 0.9))
	_prompt.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_left = SCREEN_TEXT_MARGIN
	_prompt.offset_right = -SCREEN_TEXT_MARGIN
	_prompt.offset_top = 70
	_prompt.offset_bottom = 70
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_prompt)

	_message = _make_label(TEXT_FONT, MESSAGE_FONT_SIZE)
	_message.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_message.offset_left = SCREEN_TEXT_MARGIN
	_message.offset_right = -SCREEN_TEXT_MARGIN
	_message.offset_top = -175
	_message.offset_bottom = -175
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message.modulate.a = 0.0
	_hud.add_child(_message)

	var help := _make_label(TEXT_FONT, 15, Color(1, 1, 1, 0.55))
	help.text = Lang.t("WASD: laufen   Leertaste: springen   F: Schlag   R: Messer   M: Ton\nI: Inventar   H: Kompendium   P: Charakter   L: Laden   C/Doppelklick: schleichen   Dagegenlaufen: benutzen   Tab: Menü\nMaus: Klick gehen, halten rennen (Umschalt), Rechtsklick: Messer (im Lauf: Sprung)")
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

	# The "db" of the devilbane logo as a faint watermark in the corner
	# (the "HARDCORE" lettering below it is cut off).
	var mark := TextureRect.new()
	var db := AtlasTexture.new()
	db.atlas = preload("res://assets/logo/devilbane_logo.png")
	db.region = Rect2(0, 0, 480, 388)
	mark.texture = db
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mark.offset_left = -116
	mark.offset_top = -108
	mark.offset_right = -20
	mark.offset_bottom = -20
	mark.modulate = Color(1, 1, 1, 0.35)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(mark)

	_setup_drawer()

	_setup_shrine_panel()

	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.015, 0.04, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_fade)

	_title = VBoxContainer.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.offset_left = SCREEN_TEXT_MARGIN
	_title.offset_right = -SCREEN_TEXT_MARGIN
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
	_ranking_slot = CenterContainer.new()
	_ranking_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(_ranking_slot)
	_title.move_child(_ranking_slot, _title_sub.get_index() + 1)
	_setup_name_box()
	_setup_language_row()
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 20)
	_title.add_child(title_row)
	_title_buttons = title_row
	for entry in [[Lang.t("Spielstand laden"), open_load_window], [Lang.t("Neues Spiel"), new_game]]:
		var b := _make_button(entry[0], entry[1])
		b.custom_minimum_size = Vector2(240, 64)
		title_row.add_child(b)


## The choice shown at a shrine: one of three gifts.
func _setup_shrine_panel() -> void:
	_shrine_panel = PanelContainer.new()
	_shrine_panel.set_anchors_preset(Control.PRESET_CENTER)
	_shrine_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shrine_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.88)
	style.border_color = Color(0.5, 0.75, 1.0, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(28)
	_shrine_panel.add_theme_stylebox_override("panel", style)
	_shrine_panel.visible = false
	_hud.add_child(_shrine_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_shrine_panel.add_child(box)
	var title := _make_label(TITLE_FONT, 40, Color(0.65, 0.85, 1.0))
	title.text = Lang.t("Schrein der Ahnen")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _make_label(TEXT_FONT, 22)
	sub.text = Lang.t("Wähle eine Gabe")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var gifts := [Lang.t("+1 Leben"), Lang.t("+1 Kampfkraft"), Lang.t("+7% Tempo")]
	for i in gifts.size():
		var b := _make_button(Lang.t("%s\n(Taste %d)") % [gifts[i], i + 1], _choose_gift.bind(i))
		b.custom_minimum_size = Vector2(200, 96)
		row.add_child(b)
	_wise_gift = _make_button(Lang.t("%s\n(Taste %d)") % [Lang.t("+1 Härtung"), 4], _choose_gift.bind(3))
	_wise_gift.custom_minimum_size = Vector2(200, 96)
	row.add_child(_wise_gift)


## Stops the dungeon while a window is open, so nothing can hurt the hero.
func set_world_paused(paused: bool) -> void:
	level.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	player.frozen = paused
	if paused:
		player.path.clear()
		player.play("Idle")


## Running into a shrine, the bed, the storage chest or the merchant.
func _use_station(s: Dictionary) -> void:
	_pending_station = {}
	# Still saying the last line: a new bump does not start a new one yet, or
	# the text flickers while the hero keeps pushing against the villager.
	var busy: bool = s.has("npc") and s.npc.is_busy_talking()
	if s.kind == "npc":
		player.face(s.pos - player.global_position)
		player.play("Idle")
		if not busy and not quests.talk(s.npc) and not crafting.talk(s.npc):
			s.npc.talk(player)
	elif s.kind == "eingang":
		go_inside(s.building)
	elif s.has("npc"):
		# A villager who trades: a word, then the goods. A task handed out or
		# finished comes first; the goods wait until the next time. While the
		# last line still shows, the goods open without a new word.
		if not busy and quests.talk(s.npc, true):
			player.face(s.pos - player.global_position)
			player.play("Idle")
			return
		if not busy:
			s.npc.talk(player)
		player.face(s.pos - player.global_position)
		menus.open(s.kind)
	elif s.kind == "schrein":
		_open_shrine(s)
	elif s.kind == "brunnen":
		_drink(s)
	else:
		player.face(s.pos - player.global_position)
		menus.bench = s.get("craft", "")
		menus.open(s.kind)


## The fountain: full life and every ailment gone, as often as you like.
func _drink(s: Dictionary) -> void:
	player.face(s.pos - player.global_position)
	var healed := player.hp < player.max_hp
	player.hp = player.max_hp
	var cured := player.cure()
	player.play_once("PickUp", 0.6)
	Sfx.play(self, "drink")
	var burst := Effects.make_sparkles(Color(0.5, 0.8, 1.0), true)
	burst.position = player.global_position + Vector3(0, 1.0, 0)
	level.add_child(burst)
	if cured:
		show_message(Lang.t("Das Wasser des Brunnens heilt dich von allem Übel."))
	elif healed:
		show_message(Lang.t("Das kühle Wasser heilt deine Wunden."))
	else:
		show_message(Lang.t("Du trinkst vom klaren Wasser."))
	_update_hud()


## The food basket on the village pedestal: bread, cheese and apples give
## back some life and, like a healing potion, cure what ails the hero.
func _eat_from_basket(heal: int) -> void:
	player.hp = mini(player.max_hp, player.hp + heal)
	var text := Lang.t("Essenskorb! +%d Leben") % heal
	if player.cure():
		text += "\n" + Lang.t("Dein Leiden ist geheilt.")
	player.play_once("PickUp", 0.6)
	Sfx.play(self, "drink")
	Effects.float_text(level, player.global_position + Vector3(0, 3.0, 0), text, Color(1.0, 0.5, 0.55), true)
	show_message(Lang.t("Brot, Käse und Äpfel: du isst dich satt. Der Korb füllt sich mit der Zeit wieder."), 3.5)
	learn("Kisten (Taste E: aufheben, Q: abstellen, oder der Knopf „Kiste“) kommen in deine Tasche und lassen sich wieder abstellen und stapeln. Läufst du gegen eine Kiste, kletterst du hinauf; eine höhere erreichst du mit einem Sprung. Der Essenskorb auf dem Sockel im Dorf ist nur von zwei gestapelten Kisten aus erreichbar.")
	_update_hud()


# --- Crates -------------------------------------------------------------------

## Picks up the crate in reach (the one nearest `near`, if given) into the
## bag. Returns "" on success, else why not.
func pick_up_crate(near := Vector3.INF) -> String:
	if not player.can_act() or player.is_climbing():
		return Lang.t("Gerade nicht.")
	var crate := level.crate_in_reach(player, near)
	if crate == null:
		return Lang.t("Keine Kiste in Reichweite.")
	if player.bag.size() >= player.bag_size():
		return Lang.t("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg.")
	player.path.clear()
	player.face(crate.global_position - player.global_position)
	player.play_once("Interact", 0.3)
	level.take_crate(crate)
	player.bag.append("kiste")
	Sfx.play(self, "gear_soft_%d" % (randi() % 2), -2.0)
	learn("Kisten (Taste E: aufheben, Q: abstellen, oder der Knopf „Kiste“) kommen in deine Tasche und lassen sich wieder abstellen und stapeln. Läufst du gegen eine Kiste, kletterst du hinauf; eine höhere erreichst du mit einem Sprung. Der Essenskorb auf dem Sockel im Dorf ist nur von zwei gestapelten Kisten aus erreichbar.")
	_update_hud()
	return ""


## Sets a crate from the bag down in front of the hero, on top of a crate
## standing there if there is one. Returns "" on success, else why not.
func put_down_crate() -> String:
	if not player.can_act() or player.is_climbing() or not player.is_on_floor():
		return Lang.t("Gerade nicht.")
	if not player.bag.has("kiste"):
		return Lang.t("Du trägst keine Kiste.")
	var spot := level.crate_spot(player, player.facing())
	if spot == Vector3.INF:
		return Lang.t("Hier ist kein Platz für die Kiste.")
	player.path.clear()
	player.play_once("Interact", 0.3)
	player.bag.erase("kiste")
	level.put_crate(spot)
	Sfx.play(self, "gear_book", -2.0, spot)
	_update_hud()
	return ""


# --- Stone blocks -------------------------------------------------------------

## Sets a stone block from the bag down in front of the hero, lying across
## their way, on the floor or on the blocks there. Returns "" on success,
## else why not.
func place_stone() -> String:
	if not player.can_act() or player.is_climbing() or not player.is_on_floor():
		return Lang.t("Gerade nicht.")
	if not player.bag.has(Menus.STONE):
		return Lang.t("Du trägst keinen Steinblock. Der Steinmetz im Dorf verkauft welche.")
	var spot := level.stone_spot_ahead(player, player.facing())
	if spot.is_empty():
		return Lang.t("Hier ist kein Platz für den Steinblock.")
	player.path.clear()
	player.play_once("Interact", 0.3)
	player.bag.erase(Menus.STONE)
	var stone := level.put_stone(spot.cell, spot.along_x, spot.layer)
	Sfx.play(self, "gear_book", -1.0, stone.global_position)
	learn(STONE_LEARN)
	_update_hud()
	return ""


## Takes the stone block in reach (or `stone`, if given and in reach) back
## into the bag. Returns "" on success, else why not.
func take_stone(stone: StoneBlock = null) -> String:
	if not player.can_act() or player.is_climbing():
		return Lang.t("Gerade nicht.")
	if stone == null:
		stone = level.stone_in_reach(player)
	elif level._flat_distance(player.global_position, stone.global_position) > Level.STONE_REACH or absf(stone.global_position.y - player.global_position.y) > 2.0 or not level.stone_free(stone):
		stone = null
	if stone == null:
		return Lang.t("Kein freier Steinblock in Reichweite.")
	if stone.heavy:
		return push_stone(stone)
	if player.bag.size() >= player.bag_size():
		return Lang.t("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg.")
	player.path.clear()
	player.face(stone.global_position - player.global_position)
	player.play_once("Interact", 0.3)
	level.take_stone(stone)
	player.bag.append(Menus.STONE)
	Sfx.play(self, "gear_soft_%d" % (randi() % 2), -2.0)
	_update_hud()
	return ""


## Pushes a heavy block (see StoneBlock.heavy) one grid cell away from the
## hero, along x or z, whichever way they face it most. Returns "" on
## success, else why not.
func push_stone(stone: StoneBlock) -> String:
	var away := stone.global_position - player.global_position
	var dir := Vector2i(1 if away.x > 0.0 else -1, 0) if absf(away.x) >= absf(away.z) else Vector2i(0, 1 if away.z > 0.0 else -1)
	player.path.clear()
	player.face(away)
	player.play_once("Interact", 0.3)
	learn(HEAVY_LEARN)
	if not level.push_stone(stone, dir):
		return Lang.t("Der Block rührt sich nicht: Etwas ist im Weg.")
	Sfx.play(self, "rumble", -14.0, stone.global_position)
	return ""


## The "Stone" button: sets a block down while carrying one, else takes the
## one in reach.
func stone_action() -> void:
	var why := ""
	if player.bag.has(Menus.STONE):
		why = place_stone()
	else:
		why = take_stone()
	if why != "":
		show_message(why, 1.6)


## The stone block under the mouse, or null.
func _stone_under(screen_pos: Vector2) -> StoneBlock:
	var hit := _ray_from_camera(screen_pos, [player.get_rid()])
	return hit.get("collider") as StoneBlock if not hit.is_empty() else null


func _ray_from_camera(screen_pos: Vector2, exclude: Array[RID]) -> Dictionary:
	var origin := camera.project_ray_origin(screen_pos)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_pos) * 200.0)
	ray.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(ray)


## Grabs a stone block with the mouse, if the hero can: it lies free and
## close enough. Returns whether a drag started.
func _grab_stone(screen_pos: Vector2) -> bool:
	if level == null or level.stones.is_empty() or not player.can_act() or player.is_climbing():
		return false
	var stone := _stone_under(screen_pos)
	if stone == null:
		return false
	if level._flat_distance(player.global_position, stone.global_position) > Level.STONE_DRAG_RANGE:
		show_message(Lang.t("Der Steinblock ist zu weit weg."), 1.4)
		return true
	if not level.stone_free(stone):
		show_message(Lang.t("Auf dem Steinblock liegt etwas oder steht jemand."), 1.4)
		return true
	_drag_stone = stone
	_drag_along_x = stone.along_x
	_drag_spot = {}
	_drag_time = 0.0
	_drag_press = screen_pos
	player.path.clear()
	_pending_search = {}
	_pending_station = {}
	_pending_crate = null
	_drag_ghost = MeshInstance3D.new()
	_drag_ghost.mesh = StoneBlock.block_mesh()
	_drag_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drag_ghost.material_override = mat
	_drag_ghost.visible = false
	level.add_child(_drag_ghost)
	return true


## Where the dragged block would land: the stone or floor under the mouse.
func _update_drag(delta: float) -> void:
	if _drag_stone == null:
		return
	if not is_instance_valid(_drag_stone) or not level.stones.has(_drag_stone) or state != State.PLAYING or menus.is_open():
		_end_drag()
		return
	_drag_time += delta
	var mouse := get_viewport().get_mouse_position()
	var hit := _ray_from_camera(mouse, [player.get_rid(), _drag_stone.get_rid()])
	var point = null
	if not hit.is_empty() and hit.normal.y > 0.7:
		point = hit.position
	else:
		point = _mouse_to_floor(mouse)
	if point == null:
		_drag_ghost.visible = false
		_drag_spot = {}
		return
	_drag_spot = level.stone_drop_spot(_drag_stone, point, _drag_along_x, player)
	var unmoved: bool = _drag_spot.cell == _drag_stone.cell and _drag_spot.along_x == _drag_stone.along_x and _drag_spot.layer == _drag_stone.layer
	_drag_ghost.visible = not unmoved
	var spot := StoneBlock.spot_of(_drag_spot.cell, _drag_spot.along_x, _drag_spot.layer)
	_drag_ghost.global_transform = Transform3D(Basis() if _drag_spot.along_x else Basis(Vector3.UP, PI * 0.5), spot)
	(_drag_ghost.material_override as StandardMaterial3D).albedo_color = Color(0.55, 1.0, 0.6, 0.4) if _drag_spot.ok else Color(1.0, 0.35, 0.3, 0.4)
	player.face(spot - player.global_position)


## Lets go of the dragged block: it flies onto the spot under the mouse,
## or, after a short click on it, goes into the bag when it is in reach.
func _drop_stone() -> void:
	if _drag_stone == null:
		return
	var stone := _drag_stone
	var spot := _drag_spot
	var quick := _drag_time < DRAG_CLICK and get_viewport().get_mouse_position().distance_to(_drag_press) < 12.0
	_end_drag()
	if not is_instance_valid(stone):
		return
	if spot.get("ok", false) and not quick:
		player.play_once("Throw", 0.45)
		level.move_stone(stone, spot.cell, spot.along_x, spot.layer)
		if stone.heavy:
			Sfx.play(self, "rumble", -12.0, stone.global_position)
			learn(HEAVY_LEARN)
		else:
			Sfx.play(self, "gear_book", -1.0, stone.global_position)
			learn(STONE_LEARN)
	elif quick:
		var why := take_stone(stone)
		if why != "":
			show_message(why, 1.6)
	elif not spot.is_empty() and not (spot.cell == stone.cell and spot.along_x == stone.along_x and spot.layer == stone.layer):
		show_message(Lang.t("Dort ist kein Platz für den Steinblock.") if level._flat_distance(StoneBlock.spot_of(spot.cell, spot.along_x, 0), player.global_position) <= Level.STONE_DRAG_RANGE else Lang.t("So weit reicht dein Wurf nicht."), 1.4)


func _end_drag() -> void:
	_drag_stone = null
	_drag_spot = {}
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null


## The "Crate" button: picks up a crate in reach, else sets one down.
func crate_action() -> void:
	var why := ""
	if level.crate_in_reach(player) != null and player.bag.size() < player.bag_size():
		why = pick_up_crate()
	elif player.bag.has("kiste"):
		why = put_down_crate()
	else:
		why = pick_up_crate()
	if why != "":
		show_message(why, 1.6)


func _open_shrine(s: Dictionary) -> void:
	_shrine = s
	_pending_station = {}
	player.face(s.pos - player.global_position)
	set_world_paused(true)
	# A wise hero sees one more way to take the shrine's blessing.
	_wise_gift.visible = player.attribute("weisheit") >= Training.WISE_SHRINE
	_shrine_panel.visible = true


func _choose_gift(index: int) -> void:
	if _shrine.is_empty():
		return
	var text := ""
	match index:
		0:
			player.gift_hp += 1
			player.hp += 1
			text = Lang.t("Du fühlst dich zäher: +1 Leben")
		1:
			player.gift_power += 1
			text = Lang.t("Deine Hiebe werden härter: +1 Kampfkraft")
		2:
			player.gift_speed += 0.07
			text = Lang.t("Deine Schritte werden leichter: +7% Tempo")
		3:
			if not _wise_gift.visible:
				return
			player.gift_armor += 1
			text = Lang.t("Deine Haut wird hart wie Rinde: +1 Härtung")
	player.train("weisheit", 5.0)
	set_world_paused(false)
	Sfx.play(self, "gift")
	if player.cure():
		text += "\n" + Lang.t("Dein Leiden ist geheilt.")
	player.refresh_stats()
	level.use_shrine(_shrine)
	_shrine = {}
	_shrine_panel.visible = false
	player.play_once("PickUp", 0.6)
	show_message(text)
	_update_hud()


func _version_text() -> String:
	return "Version " + VERSION + ("." + BUILD if BUILD != "" else "") + " · © 2026 devilbane · " + Lang.t("Alle Rechte vorbehalten")


## Shows how many seconds the hero can still run. Turns red while out of
## breath, until enough has come back to run again.
func _update_run_meter() -> void:
	var full := player.max_stamina()
	var left := full if player.stamina < 0.0 else player.stamina
	_run_bar.max_value = full
	_run_bar.value = left
	_run_fill.bg_color = Color(0.85, 0.3, 0.25) if player.winded else Color(0.55, 0.85, 0.4)
	_run_label.text = Lang.t("Rennen: %d s") % ceili(left)


func _update_hud() -> void:
	_level_label.text = Lang.t(level.level_name) if level.outdoor or level.building != "" else Lang.t("Ebene %d: %s") % [level_index + 1, Lang.t(level.level_name)]
	_clock_shown = _clock_text()
	if _clock_shown != "":
		_level_label.text += "    " + _clock_shown
	_hp_label.text = Lang.t("Leben: %d / %d") % [maxi(0, player.hp), player.max_hp]
	if player.hardening > 0:
		_hp_label.text += "    " + Lang.t("Härtung %d") % player.hardening
	var gifts := []
	if player.power > 1:
		gifts.append(Lang.t("Kampfkraft %d") % player.power)
	if absf(player.speed - Player.SPEED) > 0.01:
		gifts.append(Lang.t("Tempo %d%%") % roundi(player.speed / Player.SPEED * 100.0))
	if player.ailments.has("gift"):
		gifts.append(Lang.t("Vergiftet"))
	if player.ailments.has("fluch"):
		gifts.append(Lang.t("Verflucht"))
	_gift_label.text = "   ".join(gifts)
	_coin_label.text = Lang.t("Gold: %d") % coins
	_knife_label.text = Lang.t("Messer: %d") % player.knives
	_key_label.text = Lang.t("Schlüssel gefunden") if level.has_key else Lang.t("Kein Schlüssel")
	_key_label.visible = not level.outdoor and level.building == ""
	_key_label.add_theme_color_override("font_color", GOLD if level.has_key else Color(1, 1, 1, 0.45))


## The time of day for the HUD, e.g. "21:30, night", above ground only.
func _clock_text() -> String:
	if level == null or not (level.outdoor or level.building != ""):
		return ""
	var text := "%s, %s" % [DayNight.clock_text(day_hour), Lang.t(DayNight.part_of_day(day_hour))]
	if weather != Weather.CLEAR:
		text += ", " + Lang.t(Weather.word(weather))
	return text


## The world's clock runs while the hero is above ground (in the open or in
## a village building) and the world is not paused; the open air is lit for
## the hour. Down in the dungeon time stands still.
func _tick_clock(delta: float) -> void:
	if level == null or not (level.outdoor or level.building != ""):
		return
	if state == State.PLAYING and level.process_mode != Node.PROCESS_MODE_DISABLED:
		var before := day_hour
		day_hour = DayNight.advance(day_hour, delta)
		if _dawn_between(before, day_hour):
			_new_day()
		_tick_weather(delta)
	if level.outdoor:
		DayNight.apply(_env, _moon, day_hour)
		_weather_look = Weather.blend(_weather_look, Weather.look(weather), 1.0 - exp(-delta / Weather.FADE))
		_flash = maxf(0.0, _flash - delta * 3.0)
		# A stroke of lightning flickers: bright, a dip, bright again.
		var flicker := _flash * (0.45 if _flash > 0.55 and _flash < 0.75 else 1.0)
		Weather.apply(_env, _moon, _weather_look, flicker)
		if level is Outdoor:
			level.set_hour(day_hour)
			level.set_weather(weather)
	if _clock_text() != _clock_shown:
		_update_hud()


## Whether the clock passed dawn (see Bounties.DAWN) going forward from one
## hour to the other, at most one day later.
static func _dawn_between(from: float, to: float) -> bool:
	var dawn := Bounties.DAWN
	if to >= from:
		return from < dawn and to >= dawn
	return from < dawn or to >= dawn


## A new morning: fresh notices on the bounty board, and the hunts not
## finished in time are over.
func _new_day(quiet := false) -> void:
	day += 1
	var expired := bounties.refresh(day)
	if quiet or not escaped:
		return
	var text := Lang.t("Ein neuer Morgen: frische Kopfgelder am Aushang.")
	if expired > 0:
		text += "\n" + Lang.t("Nicht erledigte Jagden vom Vortag sind verfallen: %d") % expired
	quest_news(text, Color(1.0, 0.82, 0.4), 4.0)
## The weather runs on the clock: when its hours are up, the next weather
## comes, picked for the hour (see Weather.roll).
func _tick_weather(delta: float) -> void:
	weather_hours -= delta * 24.0 / DayNight.DAY_LENGTH
	if weather_hours <= 0.0:
		set_weather(Weather.roll(day_hour, _weather_rng, weather))


## Sets the weather for `hours` of the day (a random spell when not given).
## The open air follows in _tick_clock.
func set_weather(kind: String, hours := -1.0) -> void:
	weather = kind if kind in Weather.KINDS else Weather.CLEAR
	weather_hours = hours if hours > 0.0 else Weather.spell(_weather_rng)


## Rain and mist fall and drift around the hero in the open air only, and
## the rain patters as hard as it falls.
func _show_weather() -> void:
	var outside: bool = level != null and level.outdoor and player != null
	if not outside:
		_rain.emitting = false
		_rain.visible = false
		_mist.emitting = false
		_mist.visible = false
		if _rain_sound and _rain_sound.playing:
			_rain_sound.stop()
		return
	_rain.global_position = player.global_position + Vector3(0, Weather.RAIN_HEIGHT, 0)
	_mist.global_position = player.global_position + Vector3(0, 0.8, 0)
	Weather.show_particles(_rain, _mist, _weather_look, 1.0 - DayNight.glow_at(day_hour))
	if _rain_sound:
		var r: float = _weather_look.rain
		if r > 0.02:
			_rain_sound.volume_db = linear_to_db(r) - 10.0
			if not _rain_sound.playing:
				_rain_sound.play()
		elif _rain_sound.playing:
			_rain_sound.stop()


## Lightning struck (see Outdoor.strike): the sky flashes, and the thunder
## follows, later and softer the farther away it was.
func _on_lightning(at: Vector3) -> void:
	_flash = 1.0
	var far: float = level._flat_distance(player.global_position, at) if player else 0.0
	Sfx.play_after(self, clampf(far / 40.0, 0.15, 1.5), "thunder", -1.0 - far * 0.08)


# --- Flow -------------------------------------------------------------------

func load_level(index: int, restock := true) -> void:
	if level:
		level.queue_free()
	level_index = index
	level = Outdoor.new() if Level.is_outdoor_file(level_files[index]) else Level.new()
	level.load_from_file(level_files[index])
	level.depth = index
	var file := level_files[index].get_file()
	if not looted.has(file):
		looted[file] = {}
	level.taken = looted[file]
	if not builds.has(file):
		builds[file] = []
	level.built = builds[file]
	level.hero = hero_name
	if level is Outdoor:
		# Bandits who take their spots at night are tougher (see Outdoor.set_hour).
		level.night = DayNight.is_night(day_hour)
		level.interiors = interiors
		level.house_given = home_given
		level._entered_once = home_claimed
		level.met = met
	level.secret_bonus = secrets_found
	level.secret_sure = (secrets_found == 0 and index >= FIRST_SURE_SECRET) or dry_levels >= MAX_DRY_LEVELS
	add_child(level)
	level.build()
	level.player = player
	player.level = level
	player.frozen = false
	player.controllable = true
	# Arriving on a level never heals by itself; climbing the stairs gives
	# STAIRS_HEAL (see _next_level) and the fountain heals fully.
	player.revive(level.cell_to_world(level.start_cell), false)
	player.face(Vector3.BACK)
	level.restore_taken()
	level.restore_stones()
	level.key_collected.connect(_on_key_collected)
	level.coins_collected.connect(_on_coins_collected)
	level.item_collected.connect(_on_item_collected)
	level.secret_found.connect(_on_secret_found)
	level.bag_full.connect(func(): show_message(Lang.t("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg."), 2.0))
	level.door_opened.connect(func():
		Sfx.play(self, "door")
		Sfx.play(self, "chain", -6.0)
		show_message(Lang.t("Die Tür öffnet sich knarrend...")))
	level.door_locked.connect(func(): show_message(Lang.t("Verschlossen. Finde den Schlüssel!")))
	level.plates_changed.connect(_on_plates_changed)
	level.gate_opened.connect(_on_gate_opened)
	level.player_hurt.connect(player.spring_trap)
	level.enemy_killed.connect(_on_enemy_killed)
	level.exit_reached.connect(_on_exit_reached)
	if level is Outdoor:
		level.notice.connect(func(text: String, duration: float): show_message(text, duration))
		level.home_claimed.connect(_on_home_claimed)
		level.food_basket.connect(_eat_from_basket)
		level.lightning.connect(_on_lightning)
	_pending_crate = null
	_end_drag()
	_set_atmosphere(level.outdoor)
	if level is Outdoor:
		level.set_hour(day_hour)
		level.set_weather(weather)
	_pending_search = {}
	_pending_station = {}
	if level.safe and restock:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		shop_stock.clear()
		# Always at least one weapon, body armour, ring and amulet,
		# then the usual random wares on top.
		for slot in ["waffe", "ruestung", "ring", "amulett"]:
			shop_stock.append(Items.random_item(rng, 0, slot))
		for i in 4:
			shop_stock.append(Items.random_item(rng))
	_snap_camera()
	_update_hud()


func _show_title(text: String, sub: String, prompt: String) -> void:
	for child in _ranking_slot.get_children():
		child.queue_free()
	_name_box.visible = false
	_lang_row.visible = false
	_title_text.add_theme_font_size_override("font_size", 120)
	_title.visible = true
	_title_text.text = text
	_title_sub.text = sub
	_title_prompt.text = prompt
	_title.modulate.a = 0.0
	_fade.color.a = 0.55
	create_tween().tween_property(_title, "modulate:a", 1.0, 1.2)
	var blink := create_tween().set_loops()
	blink.tween_property(_title_prompt, "modulate:a", 0.3, 0.9)
	blink.tween_property(_title_prompt, "modulate:a", 1.0, 0.9)


## The title before a game: with a saved game it offers to carry on.
func _show_start_title(text: String, sub: String) -> void:
	state = State.TITLE
	if Lang.language == "":
		# The very first start: the language comes before anything else.
		_show_title(text, "Sprache wählen  ·  Choose your language", "")
		_title_buttons.visible = false
		_lang_row.visible = true
		return
	var saves := save_list()
	if not saves.is_empty():
		# A click carries on with the game saved last; the load window
		# offers every other one.
		_show_title(text, sub, Lang.t("Klicken oder eine Taste: als %s weiterspielen.  N: neues Spiel") % saves[0].name)
		_title_buttons.visible = true
	else:
		_show_title(text, sub, Lang.t("Klicken oder eine Taste drücken"))
		_title_buttons.visible = false
	_lang_row.visible = true


## Two buttons to switch between German and English on the title screen.
func _setup_language_row() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.visible = false
	_title.add_child(row)
	_lang_row = row
	for entry in [["Deutsch", "de"], ["English", "en"]]:
		var b := _make_button(entry[0], _choose_language.bind(entry[1]))
		b.custom_minimum_size = Vector2(180, 56)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		if Lang.language != "" and Lang.language != entry[1]:
			b.modulate = Color(1, 1, 1, 0.5)
		row.add_child(b)


## Every text was made in the old language, so the whole game starts afresh.
func _choose_language(code: String) -> void:
	if state != State.TITLE or _name_box.visible:
		return
	Engine.set_meta(ASK_NAME_FLAG, true)
	Lang.choose(code)
	get_tree().reload_current_scene()


## Asks for the hero's name; the game starts once it is given.
func new_game() -> void:
	if not state in [State.TITLE, State.WON, State.OVER] or _name_box.visible:
		return
	state = State.TITLE
	_title_buttons.visible = false
	_lang_row.visible = false
	_title_prompt.text = ""
	_name_box.visible = true
	_choose_sex(player.sex)
	_name_edit.text = hero_name
	_name_edit.grab_focus()
	_name_edit.select_all()
	_update_name_note(hero_name)


## Picks the body of the new hero: the chosen button stays bright, and the
## question asks for a hero's or a heroine's name.
func _choose_sex(id: String) -> void:
	_new_sex = BodyLook.checked(id)
	for sex in _sex_buttons:
		_sex_buttons[sex].modulate = Color.WHITE if sex == _new_sex else Color(1, 1, 1, 0.5)
	_name_ask.text = Lang.t("Wie heißt deine Heldin?" if _new_sex == "female" else "Wie heißt dein Held?")


## Warns when the name chosen already has a saved game: the new run takes
## its place the next time it is saved.
func _update_name_note(text: String) -> void:
	var hero := text.strip_edges()
	_name_note.text = Lang.t("%s hat schon einen Spielstand. Das neue Spiel ersetzt ihn beim nächsten Speichern.") % hero \
			if hero != "" and has_save_of(hero) else ""


func _setup_name_box() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.visible = false
	_title.add_child(box)
	_name_box = box
	# Hero or heroine: two buttons, the chosen one bright.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for entry in [["Held", "male"], ["Heldin", "female"]]:
		var b := _make_button(Lang.t(entry[0]), _choose_sex.bind(entry[1]))
		b.custom_minimum_size = Vector2(180, 56)
		row.add_child(b)
		_sex_buttons[entry[1]] = b
	_name_ask = _make_label(TEXT_FONT, 30, GOLD)
	_name_ask.text = Lang.t("Wie heißt dein Held?")
	_name_ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_ask)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.placeholder_text = Lang.t("Dein Name")
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(360, 60)
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_name_edit.add_theme_font_override("font", TEXT_FONT)
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.add_theme_stylebox_override("normal", Menus.panel_style(Color(0.85, 0.66, 0.32, 0.8)))
	_name_edit.add_theme_stylebox_override("focus", Menus.panel_style(GOLD))
	_name_edit.text_submitted.connect(func(_t): _start_new_game())
	_name_edit.text_changed.connect(_update_name_note)
	box.add_child(_name_edit)
	_name_note = _make_label(TEXT_FONT, 18, Color(1.0, 0.75, 0.5))
	_name_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_name_note)
	var go := _make_button(Lang.t("Los geht's"), _start_new_game)
	go.custom_minimum_size = Vector2(240, 64)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(go)


func _start_new_game() -> void:
	if not _name_box.visible:
		return
	hero_name = _name_edit.text.strip_edges()
	if hero_name == "":
		hero_name = Lang.t("Namenlos")
	_name_box.visible = false
	_name_edit.release_focus()
	coins = 0
	iron = 0
	escaped = false
	home_given = false
	home_claimed = false
	secrets_found = 0
	dry_levels = 0
	looted.clear()
	builds.clear()
	met.clear()
	quests.clear()
	day = 0
	bounties.clear()
	bounties.refresh(day)
	crafting.clear()
	fishing.stop()
	storage.clear()
	shop_stock.clear()
	away_plan = Offline.empty_plan()
	day_hour = DayNight.START_HOUR
	set_weather(Weather.CLEAR, Weather.FIRST_HOURS)
	player.knives = 5
	player.set_sex(_new_sex)
	player.set_hair(HairLook.DEFAULT)
	player.reset_gifts()
	# The hero keeps what they trained in earlier runs under this name.
	player.xp = Training.load_hero(hero_name)
	player.refresh_stats()
	_leave_title(func():
		player.hp = player.max_hp
		load_level(_start_level()))


## Carries on with a saved game from the title: the one at path, or else the
## one to continue with (see _save_to_continue).
func continue_game(path := "") -> void:
	if (state != State.TITLE and state != State.OVER) or _name_box.visible:
		return
	if path == "":
		path = _save_to_continue()
	if path == "" or not FileAccess.file_exists(path):
		return
	var data := _read_save(path)
	_leave_title(func():
		_apply_save(data)
		_return_from_away(data))
	# Closed only now, while leaving, so the title does not come back.
	menus.close()


## The saved game a click on the title continues: after a fall the fallen
## hero's own, otherwise the one saved last.
func _save_to_continue() -> String:
	if state == State.OVER:
		return save_path(hero_name) if has_save_of(hero_name) else ""
	var saves := save_list()
	return saves[0].path if not saves.is_empty() else ""


## The "Spielstand laden" button on the title: with just one saved game it
## carries on at once, with several the load window lets the player choose.
func open_load_window() -> void:
	if state != State.TITLE or _name_box.visible:
		return
	if save_list().size() <= 1:
		continue_game()
		return
	_title.visible = false
	menus.open("laden")


## The load window was closed on the title: the title comes back, up to
## date in case a saved game was deleted.
func load_window_closed() -> void:
	_show_start_title(_title_text.text, _title_sub.text)


## Loads a saved game, the one at path, in the middle of a run (from the
## "Laden" window). Any hero's saved game can be loaded, not only this one's.
func load_saved_game(path: String) -> void:
	if state != State.PLAYING or not FileAccess.file_exists(path):
		return
	var data := _read_save(path)
	state = State.TRANSITION
	player.frozen = true
	var tween := create_tween()
	_fade.color = Color(0, 0, 0, 0)
	tween.tween_property(_fade, "color:a", 1.0, 0.5)
	tween.tween_callback(func():
		player.frozen = false
		_apply_save(data)
		_start_playing()
		_return_from_away(data))


func _toggle_sound() -> void:
	Sfx.toggle_mute()
	_update_sound_button()


func _update_sound_button() -> void:
	if _sound_button:
		_sound_button.text = Lang.t("Ton: aus") if Sfx.muted else Lang.t("Ton: an")


func _toggle_music() -> void:
	Music.toggle_mute()
	_update_music_controls()


## A row with the music volume: a label and a slider from silent to full.
func _make_music_slider() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = Lang.t("Musik")
	label.add_theme_font_override("font", TEXT_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", GOLD)
	row.add_child(label)
	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.05
	_music_slider.focus_mode = Control.FOCUS_NONE
	_music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_music_slider.custom_minimum_size = Vector2(0, 32)
	_music_slider.tooltip_text = Lang.t("Lautstärke der Musik")
	_music_slider.value = Music.volume
	_music_slider.value_changed.connect(_on_music_volume_changed)
	row.add_child(_music_slider)
	return row


func _on_music_volume_changed(value: float) -> void:
	if is_equal_approx(value, Music.volume):
		return
	Music.set_volume(value)
	# Moving the slider up switches the music back on.
	if Music.muted and value >= Music.SILENT:
		Music.toggle_mute()
	_update_music_controls()


func _update_music_controls() -> void:
	if _music_button:
		_music_button.text = Lang.t("Musik: aus") if Music.muted else Lang.t("Musik: an")
	if _music_slider and not is_equal_approx(_music_slider.value, Music.volume):
		_music_slider.set_value_no_signal(Music.volume)


## In the game the quit button asks first. On the title and while naming the
## hero it leaves at once: the desktop version closes, the browser goes back
## to the title.
func _on_quit_pressed() -> void:
	if state == State.PLAYING:
		if player.can_act() and not menus.is_open():
			menus.open("beenden")
	elif state == State.TITLE:
		if not OS.has_feature("web"):
			get_tree().quit()
		elif _name_box.visible:
			get_tree().reload_current_scene()
		else:
			_close_tab()


## Browsers only let a page close a tab it opened itself. When the tab stays
## open, the game gives way to a goodbye page with a link to play again.
func _close_tab() -> void:
	var bye := Lang.t("Bis bald! Du kannst diesen Tab jetzt schließen.")
	var again := Lang.t("Nochmal spielen")
	JavaScriptBridge.eval("""
		window.close();
		setTimeout(function () {
			if (window.closed) return;
			document.body.innerHTML = '<div style="position:fixed;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:24px;background:#08040a;color:#f3d38a;font:24px Georgia,serif;text-align:center;padding:16px">'
				+ '<div>' + %s + '</div>'
				+ '<a href="" style="color:#c9a25a;font-size:18px">' + %s + '</a></div>';
		}, 300);
	""" % [JSON.stringify(bye), JSON.stringify(again)])


## Leaves the game for the title screen. A browser tab cannot close itself,
## so only the desktop version quits outright.
func quit_game() -> void:
	if state != State.PLAYING:
		return
	if not OS.has_feature("web"):
		get_tree().quit()
		return
	state = State.TRANSITION
	player.frozen = true
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.8)
	tween.tween_callback(func(): _show_start_title("Escape!", Lang.t("Entkomme aus dem Verlies")))


## Name, level, gold and time of a saved game (by default this hero's), or
## nothing when there is none.
func save_info(path := "") -> Dictionary:
	if path == "":
		path = save_path(hero_name)
	if not FileAccess.file_exists(path):
		return {}
	var data := _read_save(path)
	if not data.has("level") or not data.has("coins"):
		return {}
	# Games saved before there were several have no time of their own.
	var time := float(data.get("saved_at", FileAccess.get_modified_time(path)))
	return {"path": path, "name": str(data.get("name", Lang.t("Namenlos"))), "level": int(data.level) + 1, "coins": int(data.coins),
			"escaped": bool(data.get("escaped", false)), "home": bool(data.get("claimed", false)), "time": time}


## Every saved game there is, the one saved last first.
func save_list() -> Array:
	var saves := []
	for f in DirAccess.get_files_at(SAVE_DIR):
		if f.ends_with(".json"):
			var info := save_info(SAVE_DIR + f)
			if not info.is_empty():
				saves.append(info)
	saves.sort_custom(func(a, b): return a.time > b.time)
	return saves


## The time a game was saved, as the player's clock showed it.
static func save_time_text(time: float) -> String:
	var local := int(time) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]


func _read_save(path := "") -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path if path != "" else save_path(hero_name)))
	return data if data is Dictionary else {}


func _apply_save(data: Dictionary) -> void:
	hero_name = data.get("name", Lang.t("Namenlos"))
	coins = int(data.coins)
	iron = int(data.get("iron", 0))
	secrets_found = int(data.get("secrets", 0))
	dry_levels = int(data.get("dry", 0))
	storage.assign(data.storage)
	shop_stock.assign(data.shop)
	player.knives = int(data.knives)
	player.gift_hp = int(data.gift_hp)
	player.gift_power = int(data.gift_power)
	player.gift_speed = float(data.gift_speed)
	player.gift_armor = int(data.get("gift_armor", 0))
	player.equipped = data.equipped
	player.wear = data.get("wear", {})
	player.set_sex(str(data.get("sex", BodyLook.DEFAULT))) # Games saved before there were heroines have a hero.
	player.set_hair(data.get("hair", {}))
	player.xp = Training.load_hero(hero_name)
	lore.assign(data.get("lore", []))
	looted.clear()
	var saved_loot = data.get("looted", {})
	if saved_loot is Dictionary:
		for file in saved_loot:
			var ids := {}
			if saved_loot[file] is Array:
				for id in saved_loot[file]:
					ids[str(id)] = true
			looted[file] = ids
	builds.clear()
	var saved_builds = data.get("builds", {})
	if saved_builds is Dictionary:
		for file in saved_builds:
			if saved_builds[file] is Array:
				builds[str(file)] = (saved_builds[file] as Array).filter(func(e): return e is Array and e.size() >= 4)
	escaped = bool(data.get("escaped", false))
	home_given = bool(data.get("home", false))
	home_claimed = home_given and bool(data.get("claimed", false))
	met.clear()
	var saved_met = data.get("met", [])
	if saved_met is Array:
		for role in saved_met:
			if Villager.ROLES.has(str(role)):
				met[str(role)] = true
	quests.load_from(data.get("quests", {}))
	day = maxi(0, int(data.get("day", 0)))
	bounties.load_from(data.get("bounties", {}))
	bounties.refresh(day)
	crafting.load_from(data.get("crafting", {}))
	var plan = data.get("plan", {})
	away_plan = plan if plan is Dictionary and not plan.is_empty() else Offline.empty_plan()
	player.bag.assign(data.bag)
	player.refresh_stats()
	# Games saved before there was a clock wake up in the morning.
	day_hour = fposmod(float(data.get("hour", DayNight.START_HOUR)), 24.0)
	# Games saved before there was weather wake up to clear skies.
	set_weather(str(data.get("weather", Weather.CLEAR)), float(data.get("weather_hours", Weather.FIRST_HOURS)))
	var index := clampi(int(data.level), 0, level_files.size() - 1)
	if escaped and _outdoor_index() >= 0:
		# Out of the dungeon, every load begins in the open air, wherever the
		# game was saved: on the graveyard, or in the hero's own house.
		index = _outdoor_index()
	load_level(index, false)
	if level is Outdoor and home_claimed and level.home_spot != Vector3.ZERO:
		# The hero's own house is the place to come back to: next to the bed.
		player.global_position = level.home_spot
	player.hp = clampi(int(data.hp), 1, player.max_hp)
	player.cure()
	_update_hud()


func _leave_title(prepare: Callable) -> void:
	state = State.TRANSITION
	_title_buttons.visible = false
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		prepare.call()
		_start_playing())


# --- Saving -----------------------------------------------------------------

## Whether there is any saved game at all.
func has_save() -> bool:
	return not save_list().is_empty()


## The file of a hero's saved game. The name is hashed, so that any name
## makes a valid file name.
static func save_path(hero: String) -> String:
	return SAVE_DIR + hero.md5_text() + ".json"


func has_save_of(hero: String) -> bool:
	return FileAccess.file_exists(save_path(hero))


## Deletes a saved game from the load window.
func delete_save(path: String) -> void:
	if path.begins_with(SAVE_DIR) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## The one saved game from before there could be several becomes the saved
## game of its hero.
func _move_old_save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if not FileAccess.file_exists(OLD_SAVE_FILE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(OLD_SAVE_FILE))
	if not (data is Dictionary):
		return
	var target := save_path(str(data.get("name", Lang.t("Namenlos"))))
	if FileAccess.file_exists(target):
		return
	if not data.has("saved_at"):
		data.saved_at = FileAccess.get_modified_time(OLD_SAVE_FILE)
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(OLD_SAVE_FILE)


## The level index of the open air outside the crypt, or -1 without one.
func _outdoor_index() -> int:
	for i in level_files.size():
		if Level.is_outdoor_file(level_files[i]):
			return i
	return -1


## Whether the elder has handed the hero the house, kept up to date while in
## the village.
func _home_given_now() -> bool:
	if level is Outdoor:
		home_given = level.house_given
	return home_given


## Writes everything needed to wake up in this safe room later. True when
## the file is really there afterwards. Going away also writes the hero's
## plan for the time away and when the player left.
func save_game(going_away := false) -> bool:
	Training.save_hero(hero_name, player.xp)
	var data := {
		"version": 1, "name": hero_name, "sex": player.sex, "level": level_index, "coins": coins, "iron": iron, "secrets": secrets_found, "dry": dry_levels, "hp": player.hp, "knives": player.knives,
		"gift_hp": player.gift_hp, "gift_power": player.gift_power, "gift_speed": player.gift_speed, "gift_armor": player.gift_armor,
		"equipped": player.equipped, "wear": player.wear, "hair": player.hair, "bag": player.bag, "storage": storage, "shop": shop_stock,
		"lore": lore, "plan": away_plan, "escaped": escaped, "home": _home_given_now(), "claimed": home_claimed,
		"saved_at": Time.get_unix_time_from_system(),
		"looted": _looted_for_save(), "met": met.keys(), "builds": _builds_for_save(),
		"quests": quests.for_save(),
		"day": day, "bounties": bounties.for_save(),
		"crafting": crafting.for_save(),
		"hour": day_hour,
		"weather": weather, "weather_hours": weather_hours,
	}
	if going_away:
		data.away = {"plan": Offline.normalized(away_plan, away_choices()), "since": Time.get_unix_time_from_system()}
	var path := save_path(hero_name)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return FileAccess.file_exists(path)


## The stone blocks per level file, levels without any left out.
func _builds_for_save() -> Dictionary:
	var out := {}
	for file in builds:
		if not builds[file].is_empty():
			out[file] = builds[file]
	return out


## The looted ids per level file as plain lists, levels with none left out.
func _looted_for_save() -> Dictionary:
	var out := {}
	for file in looted:
		if not looted[file].is_empty():
			out[file] = looted[file].keys()
	return out


## The hero lies down in the safe room's bed: save, then back to the title.
func sleep() -> void:
	# A night in the bed: the hero wakes up the next morning.
	if level.outdoor or level.building != "":
		if _dawn_between(day_hour, DayNight.WAKE_HOUR):
			_new_day(true)
		day_hour = DayNight.WAKE_HOUR
		# A new morning brings new weather.
		set_weather(Weather.roll(day_hour, _weather_rng))
	var saved := save_game(true)
	# Say so at once, so nobody has to wonder whether the save went through.
	show_message(Lang.t("Spiel gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!"), 2.4)
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	var tween := create_tween()
	var bed := _nearest_bed()
	if bed.is_empty():
		player.play("Lie_Down", 0.2)
	else:
		_climb_into_bed(tween, bed)
	# Settled on the back, the hero closes their eyes and drifts off: a few
	# floating Z's and some soft snoring before the night falls.
	tween.tween_interval(1.9)
	tween.tween_callback(_fall_asleep)
	tween.tween_interval(2.6)
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 1.6)
	tween.tween_callback(func():
		_stop_snoozing()
		_show_start_title(Lang.t("Gute Nacht"), Lang.t("Dein Spiel ist gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!")))


## The letters drifting up from a sleeping hero, one after the other.
const SNOOZE_LETTERS := ["Z", "Z", "Z", "z", "z", "z"]
const SNOOZE_GAP := 0.5
var _snooze: Tween = null


func _fall_asleep() -> void:
	player.set_asleep(true)
	_stop_snoozing()
	_snooze = create_tween().set_loops()
	# One snore per breath, and a "ZZZzzz" rising with it.
	_snooze.tween_callback(func(): Sfx.play(self, "snore", -3.0, player.global_position, 1.0))
	for i in SNOOZE_LETTERS.size():
		_snooze.tween_callback(_float_snooze_letter.bind(i))
		_snooze.tween_interval(SNOOZE_GAP)


func _stop_snoozing() -> void:
	if _snooze:
		_snooze.kill()
		_snooze = null


## A Z rising from the sleeper's head, swaying a little as it fades away.
## The first ones are big, the later ones small, like "ZZZzzz".
func _float_snooze_letter(i: int) -> void:
	var slot := player.find_child("HeadSlot", true, false) as Node3D
	var from := (slot.global_position if slot else player.global_position) + Vector3(0.3, 0.9, 0)
	var label := Label3D.new()
	label.text = SNOOZE_LETTERS[i]
	label.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	label.font_size = 72 - i * 7
	label.pixel_size = 0.012
	label.outline_size = 12
	label.outline_modulate = Color(0.05, 0.03, 0.12, 0.9)
	label.modulate = Color(0.85, 0.9, 1.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.outline_render_priority = 19
	level.add_child(label)
	label.global_position = from
	var drift := Vector3(0.5 + 0.1 * i, 1.8, -0.2)
	var tween := label.create_tween()
	tween.tween_method(func(t: float):
		label.global_position = from + drift * t + Vector3(sin(t * TAU * 1.2) * 0.25, 0, 0), 0.0, 1.0, 2.4)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0).set_delay(1.4)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 1.0).set_delay(1.4)
	tween.tween_callback(label.queue_free)


## How high the mattress of the bed lies, and how far from the bed's middle
## towards its foot the hero stands before lying down. Lying down falls
## backwards, so this puts the body in the middle of the bed.
const BED_MATTRESS_HEIGHT := 0.83
const BED_LIE_OFFSET := 0.65


## The bed the hero just ran into: the closest one in the level.
func _nearest_bed() -> Dictionary:
	var best := {}
	var best_dist := INF
	for s in level.stations:
		if s.kind != "bett":
			continue
		var dist: float = player.global_position.distance_to(s.pos)
		if dist < best_dist:
			best_dist = dist
			best = s
	return best


## A little hop up onto the mattress, then the hero lies down on their back
## with the head on the pillow and the feet towards the foot of the bed.
func _climb_into_bed(tween: Tween, bed: Dictionary) -> void:
	var rot: float = bed.get("rot", 0.0)
	var foot := Vector3(sin(rot), 0.0, cos(rot))
	var spot: Vector3 = bed.pos + foot * BED_LIE_OFFSET + Vector3(0, BED_MATTRESS_HEIGHT, 0)
	var from := player.global_position
	player.velocity = Vector3.ZERO
	player.face(spot - from)
	player.play("Jump_Idle", 0.1)
	tween.tween_method(func(t: float):
		player.global_position = from.lerp(spot, t) + Vector3(0, sin(t * PI) * 0.6, 0), 0.0, 1.0, 0.45)
	tween.tween_callback(func():
		# Lying down falls backwards, so face the foot of the bed.
		player.face(foot)
		player.play("Lie_Down", 0.15))


# --- Time away ----------------------------------------------------------------

## What the hero can do while the player is away, right now: block -> ids.
## Jobs the hero is fit for, attributes and skills that can still grow (a
## skill only with its gear worn), books the hero owns (in the bag or the
## storage chest) and every recipe.
func away_choices() -> Dictionary:
	var jobs := Offline.JOBS.keys().filter(func(id): return player.can_use(Offline.JOBS[id].get("requires", {})))
	var train := []
	for id in Offline.TRAINABLE:
		if player.attribute(id) < Training.ATTRIBUTES[id].max:
			train.append(id)
	for id in Training.SKILLS:
		if player.skill_enabled(id) and Training.skill_level(player.xp.get(id, 0.0)) < Training.SKILL_MAX:
			train.append(id)
	var books := []
	var owned: Array = player.bag.duplicate()
	owned.append_array(storage)
	for id in owned:
		if Items.is_book(id) and not id in books:
			books.append(id)
	return {"job": jobs, "train": train, "study": books, "craft": Offline.RECIPES.keys()}


## Back after a sleep in the bed: the hero has lived the planned day for as
## long as the player was away. The result goes into the hero and the saved
## game, and a window tells what happened.
func _return_from_away(data: Dictionary) -> void:
	var away = data.get("away", {})
	if not (away is Dictionary) or away.is_empty():
		return
	var real_seconds := maxf(0.0, Time.get_unix_time_from_system() - float(away.get("since", 0.0)))
	var plan := Offline.normalized(away.get("plan", {}), away_choices())
	var hours := Offline.game_hours(real_seconds)
	var result := Offline.simulate(plan, hours)
	away_report = _apply_away(plan, result)
	away_report.push_front(Lang.t("Du warst %s weg, für %s vergingen %s.") % [
			_real_time_text(real_seconds), hero_name, Offline.duration_text(hours)])
	if real_seconds > Offline.MAX_REAL_SECONDS:
		away_report.append(Lang.t("Mehr als 8 Tage (32 Stunden) zählen nicht."))
	# Saving again without "away" makes sure the same time never counts twice.
	save_game()
	_update_hud()
	menus.open("rueckkehr")


## Gives the hero what the time away brought; returns a line for each thing.
func _apply_away(plan: Dictionary, result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var spent: Dictionary = result.spent
	var before := {}
	for id in Training.ATTRIBUTES:
		before[id] = player.attribute(id)
	for id in Training.SKILLS:
		before[id] = Training.skill_level(player.xp.get(id, 0.0))
	# No floating texts for each new point: the window lists them all.
	player.set_block_signals(true)
	for id in result.xp:
		player.train(id, result.xp[id])
	for id in result.study_xp:
		player.train(id, result.study_xp[id], false)
	player.set_block_signals(false)
	coins += int(result.gold)
	player.knives += int(result.knives)
	var repaired := _repair_gear(int(result.repairs))
	if spent.job > 0.0:
		lines.append(Lang.t("%s: %s, +%d Gold") % [Lang.t(Offline.JOBS[plan.job].name), Offline.duration_text(spent.job), result.gold])
	if spent.train > 0.0:
		lines.append(Lang.t("Training (%s): %s") % [_training_name(plan.train), Offline.duration_text(spent.train)])
	if spent.study > 0.0:
		lines.append(Lang.t("Gelesen (%s): %s") % [Items.item_name(plan.study), Offline.duration_text(spent.study)])
	if spent.craft > 0.0:
		var made := ""
		if Offline.RECIPES[plan.craft].makes == "knife":
			made = Lang.t("%d Wurfmesser") % result.knives
		else:
			made = Lang.t("%d Punkte Haltbarkeit") % repaired
		lines.append(Lang.t("%s: %s, %s") % [Lang.t(Offline.RECIPES[plan.craft].name), Offline.duration_text(spent.craft), made])
	if spent.rest > 0.0:
		# Each hour of rest heals an eighth of the hero's life; a full night
		# also cures poison and curses.
		player.hp = mini(player.max_hp, player.hp + ceili(spent.rest * player.max_hp / float(Offline.REST_HOURS)))
		if spent.rest >= Offline.REST_HOURS:
			player.cure()
		lines.append(Lang.t("Geruht: %s, Leben %d / %d") % [Offline.duration_text(spent.rest), player.hp, player.max_hp])
	for id in Training.ATTRIBUTES:
		if player.attribute(id) > before[id]:
			var shown := ("%d%%" % player.attribute(id)) if id == "tempo" else str(player.attribute(id))
			lines.append(Lang.t("%s steigt auf %s!") % [Lang.t(Training.ATTRIBUTES[id].name), shown])
	for id in Training.SKILLS:
		var now := Training.skill_level(player.xp.get(id, 0.0))
		if now > before[id]:
			lines.append(Lang.t("%s: Stufe %d!") % [Lang.t(Training.SKILLS[id].name), now])
	return lines


## Takes away up to `points` of wear, worn gear first; returns how many.
func _repair_gear(points: int) -> int:
	var done := 0
	var order: Array = player.equipped.values()
	order.append_array(player.bag)
	for id in order:
		while done < points and player.wear.get(id, 0) > 0:
			player.wear[id] -= 1
			done += 1
			if player.wear[id] <= 0:
				player.wear.erase(id)
	return done


func _training_name(id: String) -> String:
	if Training.is_skill(id):
		return Lang.t(Training.SKILLS[id].name)
	return Lang.t(Training.ATTRIBUTES[id].name)


## Real time like "5 Stunden 20 Minuten".
func _real_time_text(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	if minutes < 60:
		return Lang.t("%d Minuten") % minutes
	return Lang.t("%d Std. %d Min.") % [floori(minutes / 60.0), minutes % 60]


func _start_playing() -> void:
	state = State.PLAYING
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(_fade, "color:a", 0.0, 0.8)
	_announce_level()


func _announce_level() -> void:
	_guardian_tip = -1
	learn("#%d" % level_index)
	if level.outdoor or level.building != "":
		show_message("%s\n%s" % [Lang.t(level.level_name), Lang.t(level.hint)], 4.5)
		return
	show_message(Lang.t("Ebene %d: %s\n%s") % [level_index + 1, Lang.t(level.level_name), Lang.t(level.hint)], 3.5)


func _message_busy() -> bool:
	return _message.modulate.a > 0.05


## Name and hint of a level, read from its file, for the compendium.
func level_hint(index: int) -> Dictionary:
	var info := {"name": "", "hint": ""}
	if index < 0 or index >= level_files.size():
		return info
	for line in FileAccess.get_file_as_string(level_files[index]).split("\n"):
		if line.begins_with("name:"):
			info.name = line.substr(5).strip_edges()
		elif line.begins_with("hint:"):
			info.hint = line.substr(5).strip_edges()
	return info


## News about a task (a new one, progress, done): a message and a word over
## the hero's head.
func quest_news(text: String, color: Color, duration := 4.0) -> void:
	show_message(text, duration)
	Effects.float_text(level, player.global_position + Vector3(0, 3.2, 0), text.get_slice("\n", 0), color, true)
	_update_hud()


## A task is done: the reward, with a jingle.
func quest_reward(id: String) -> void:
	var q: Dictionary = Quests.ALL[id]
	if q.get("gold", 0) > 0:
		Sfx.play_coins(self, q.gold)
	else:
		Sfx.play(self, "key", -3.0)
	quest_news(Lang.t("Auftrag abgeschlossen: %s\nBelohnung: %s") % [Lang.t(q.title), Quests.reward_text(id)], GOLD, 4.5)


## The "!" and "?" over the villagers' heads. Looked at a few times a
## second, so kills, loot and a full or emptied bag show up on their own.
func refresh_quest_marks() -> void:
	if not (level is Outdoor):
		return
	for v in level.villagers:
		if is_instance_valid(v):
			var quest_mark := quests.mark(v.role)
			v.set_quest_mark(quest_mark if quest_mark != "" else crafting.mark(v.role))
	(level as Outdoor).set_board_mark(bounties.mark())


## Something in the bag changed because of a task.
func update_after_quest() -> void:
	Sfx.play(self, "key", -6.0)
	_update_hud()


## Remembers an explanation for the compendium, once.
func learn(entry: String) -> void:
	if not lore.has(entry):
		lore.append(entry)
		# Understanding something new trains the mind.
		player.train("intelligenz", 5.0)


func show_message(text: String, duration := 2.2) -> void:
	_message.text = text
	# Very long messages get a smaller font so they stay at a few lines.
	var size := MESSAGE_FONT_SIZE
	if text.length() > 160:
		size = MESSAGE_FONT_SIZE - 6
	elif text.length() > 90:
		size = MESSAGE_FONT_SIZE - 3
	_message.add_theme_font_size_override("font_size", size)
	_message.add_theme_constant_override("outline_size", maxi(4, size / 6))
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.25)
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.6)


func _on_key_collected() -> void:
	level.has_key = true
	player.play_once("PickUp", 0.6)
	Sfx.play(self, "key")
	show_message(Lang.t("Du hast den Schlüssel gefunden!"))
	player.train("weisheit", 3.0)
	_update_hud()


## A block came onto or off a pressure plate.
func _on_plates_changed(pressed: int, total: int) -> void:
	if pressed < total:
		show_message(Lang.t("Druckplatten: %d von %d") % [pressed, total], 1.8)
		learn(HEAVY_LEARN)


## Every pressure plate is pressed: the iron gate sinks into the floor.
func _on_gate_opened(pos: Vector3) -> void:
	_shake = 1.0
	Comic.pop(pos, "rumble")
	Sfx.play(self, "rumble", 0.0, pos)
	Sfx.play(self, "chain", -4.0, pos)
	show_message(Lang.t("Alle Druckplatten sind belegt: Das Eisengitter versinkt im Boden!"), 3.5)
	_message.add_theme_color_override("font_color", GOLD)
	get_tree().create_timer(3.8).timeout.connect(func(): _message.add_theme_color_override("font_color", Color.WHITE))


## A lever torch found: a click and a golden message, then, a moment later,
## rumbling and shaking ground while the secret wall sinks.
func _on_secret_found(lever_pos: Vector3, wall_pos: Vector3) -> void:
	secrets_found += 1
	level.secret_bonus = secrets_found
	player.train("weisheit", 5.0)
	Comic.pop(lever_pos, "lever")
	Sfx.play(self, "lever_pull", -2.0, lever_pos)
	learn("Diese Fackelhalterung sieht seltsam aus.\nDu ziehst daran und hörst in der Ferne Stein, der sich bewegt!")
	show_message(Lang.t("Diese Fackelhalterung sieht seltsam aus.\nDu ziehst daran und hörst in der Ferne Stein, der sich bewegt!"), 4.5)
	_message.add_theme_color_override("font_color", GOLD)
	get_tree().create_timer(4.8).timeout.connect(func(): _message.add_theme_color_override("font_color", Color.WHITE))
	var tier: Dictionary = Level.TIERS[level.secret_tier]
	var here := level
	await get_tree().create_timer(Level.SECRET_DELAY).timeout
	if level != here:
		return
	_shake = 1.6
	Comic.pop(wall_pos, "rumble")
	Sfx.play(self, "rumble", 0.0, wall_pos)
	Sfx.play(self, "secret", -4.0)
	Effects.float_text(level, wall_pos + Vector3(0, 1.5, 0), Lang.t("Geheimraum: %s") % Lang.t(tier.name), tier.color)


## A piece of gear a skeleton dropped.
func _on_item_collected(id: String) -> void:
	player.bag.append(id)
	Sfx.play(self, "key", -3.0)
	Effects.float_text(level, player.global_position + Vector3(0, 3.0, 0), Items.item_name(id), Color(0.75, 0.9, 1.0), true)
	show_message(Lang.t("Gefunden: %s (%s)") % [Items.item_name(id), Items.describe(id)] + Lang.t("\nTaste I öffnet das Inventar."), 5.0)
	_update_hud()


func _on_coins_collected(amount: int) -> void:
	coins += _gold(amount)
	Sfx.play_coins(self, _gold(amount))
	_update_hud()


## Gold found, doubled by the lucky clover.
func _gold(amount: int) -> int:
	return amount * 2 if player.has_special("gluecksklee") else amount


func _on_enemy_killed(enemy: Enemy) -> void:
	show_message(enemy.fall_text(), 2.5)
	var drop := quests.on_kill(enemy.kind)
	bounties.on_kill(enemy.kind)
	if drop != "":
		level._drop_item(drop, enemy.global_position + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)))
	if player.has_special("vampirzahn") and player.hp < player.max_hp and not player.dead:
		player.hp += 1
		Effects.float_text(level, player.global_position + Vector3(0, 2.6, 0), "+1", Color(0.5, 1.0, 0.5))
		_update_hud()


## Training raised an attribute or a skill: say so, the attributes louder.
func _on_player_trained(id: String, value: int) -> void:
	var text := ""
	match id:
		"staerke":
			text = Lang.t("Die vielen Kämpfe machen dich stärker: Stärke %d, +1 Kampfkraft") % value
		"konstitution":
			text = Lang.t("Dein Körper wird zäher: Konstitution %d, +1 Leben") % value
		"tempo":
			text = Lang.t("Deine Beine werden schneller: Tempo %d%%") % value
		"intuition":
			text = Lang.t("Dein Gespür wird feiner: Intuition %d") % value
		"geschick":
			text = Lang.t("Deine Hände und Füße werden flinker: Geschick %d") % value
		"intelligenz":
			text = Lang.t("Dein Verstand wird schärfer: Intelligenz %d") % value
		"weisheit":
			text = Lang.t("Du lernst aus allem, was geschah: Weisheit %d") % value
			if value == Training.WISE_SHRINE:
				text += "\n" + Lang.t("Die Schreine zeigen dir nun eine vierte Gabe.")
		_:
			text = Lang.t("Du wirst geübter: %s, Stufe %d") % [Lang.t(Training.SKILLS[id].name), value]
	var attribute := Training.ATTRIBUTES.has(id)
	Effects.float_text(level, player.global_position + Vector3(0, 3.4, 0), text.get_slice(":", 1).strip_edges() if attribute else Lang.t(Training.SKILLS[id].name) + " %d" % value,
			GOLD if attribute else Color(0.65, 0.85, 1.0))
	if attribute:
		Sfx.play(self, "secret", -6.0)
	show_message(text, 3.5 if attribute else 2.4)
	learn("Eigenschaften wachsen sehr langsam durch Tun: Kämpfen macht stärker (Stärke, +1 Kampfkraft je Punkt, Lasten wiegen weniger), Treffer einstecken macht zäher (Konstitution, +1 Leben je Punkt), Laufen und Springen machen schneller (Tempo bis 150 %), Springen, Werfen und Fallen machen geschickter (Geschick: weiter springen, Stacheln ausweichen), Durchsuchen und Geheimnisse schärfen das Gespür (Intuition, +2 % je Punkt, Geheimräume zu entdecken), und alles, was du durchstehst, macht dich weiser (Weisheit: du lernst 5 % schneller je Punkt, ab 12 bieten Schreine eine vierte Gabe), und Neues zu verstehen macht klüger (Intelligenz: manche Dinge wie der Zauberhut brauchen sie). Fertigkeiten wachsen schneller, aber nur mit der passenden Ausrüstung. Alles bleibt deinem Helden über alle Läufe.")
	_update_hud()


## Double click or C: sneak (slow, silent, hard to see) or walk normally.
func _toggle_sneak() -> void:
	if player.dead or not player.controllable:
		return
	if not player.sneaking and level.enemies.any(func(e): return is_instance_valid(e) and e.is_hunting()):
		show_message(Lang.t("Zu spät zum Schleichen: Du wurdest entdeckt!"), 1.6)
		return
	if not player.sneaking and player.fight_cooldown > 0.0:
		show_message(Lang.t("Noch zu aufgewühlt vom Kampf, um zu schleichen."), 1.6)
		return
	player.set_sneaking(not player.sneaking)
	if player.sneaking:
		learn("Schleichen (C oder Doppelklick): langsamer, lautlos, Laterne abgeblendet. Im Dunkeln sieht dich keiner, und von hinten bemerkt dich ein Skelett auch ganz nah nicht.")
	show_message(Lang.t("Du schleichst. Im Dunkeln sieht dich keiner.") if player.sneaking else Lang.t("Du gehst wieder normal."), 1.6)


## Running into an object searches it, running into a torch lights it or
## puts it out.
func _on_player_bumped(point: Vector3) -> void:
	if state != State.PLAYING or not player.can_act():
		return
	var torch := level.torch_touched(point)
	if not torch.is_empty():
		level.set_torch(torch, not torch.on)
		Sfx.play(self, "swing", -6.0)
		return
	var station := level.station_at(point)
	if not station.is_empty():
		_use_station(station)
		return
	var obj := level.unsearched_at(point)
	if not obj.is_empty():
		_search(obj)


func _search(obj: Dictionary) -> void:
	_pending_search = {}
	player.path.clear()
	player.face(obj.pos - player.global_position)
	if obj.searched:
		Effects.float_text(level, obj.icon_pos, Lang.t("Schon durchsucht"), Color(0.8, 0.8, 0.8), true)
		return
	if obj.loot.has("item") and player.bag.size() >= player.bag_size():
		if not _message_busy():
			show_message(Lang.t("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg."), 2.0)
		return
	player.play_once("Interact", 0.55)
	# A chest creaks open, anything else gets rummaged through; what was in
	# it sounds once the lid is up or the hands have found it.
	var chest: bool = obj.label in ["Truhe", "Schatztruhe"]
	if chest:
		Sfx.play_chest(self)
	else:
		Sfx.play(self, "rummage", -3.0)
	var found_after := 0.55 if chest else 0.2
	var loot := level.search(obj)
	# Searching every nook trains a feeling for where things hide.
	player.train("intuition", 1.0)
	var text := Lang.t("%s: leer") % Lang.t(obj.label)
	var color := Color(0.8, 0.8, 0.85)
	if loot.has("gold"):
		Sfx.play_coins(self, _gold(loot.gold), found_after)
		coins += _gold(loot.gold)
		text = Lang.t("+%d Gold") % _gold(loot.gold)
		color = GOLD
	elif loot.has("knives"):
		player.knives += loot.knives
		Sfx.play_after(self, found_after, "gear_metal_%d" % (randi() % 3), -8.0)
		text = Lang.t("+%d Wurfmesser") % loot.knives
		color = Color(0.8, 0.9, 1.0)
	elif loot.has("potion"):
		Sfx.play(self, "drink")
		player.hp = mini(player.max_hp, player.hp + 2)
		text = Lang.t("Heiltrank! +2 Leben")
		if player.cure():
			text += "\n" + Lang.t("Dein Leiden ist geheilt.")
		color = Color(1.0, 0.5, 0.55)
	if loot.has("item"):
		player.bag.append(loot.item)
		Sfx.play_gear(self, loot.item, found_after + (0.25 if loot.has("gold") else 0.0))
		var found := Lang.t("Gefunden: %s (%s)") % [Items.item_name(loot.item), Items.describe(loot.item)]
		text = Items.item_name(loot.item) if text.ends_with("leer") else text + "  +" + Items.item_name(loot.item)
		color = Color(0.75, 0.9, 1.0)
		show_message(found + Lang.t("\nTaste I öffnet das Inventar."), 5.0)
	Effects.float_text(level, obj.icon_pos, text, color, true)
	if loot.is_empty():
		show_message(Lang.t("Du durchsuchst %s... nichts.") % Lang.t(_with_article(obj.label)), 1.2)
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


## Death ends the run: it goes into the ranking with a skull.
func _on_player_defeated() -> void:
	state = State.TRANSITION
	show_message(Lang.t("Du wurdest besiegt..."), 2.0)
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.8)
	tween.tween_callback(func(): _end_run(false))


## Puts the finished run into the ranking and shows the list.
func _end_run(escaped: bool) -> void:
	state = State.WON if escaped else State.OVER
	var entry := Ranking.add(hero_name, level_index + 1, level.level_name, coins, escaped)
	# Whatever the outcome, a whole run is a lesson.
	player.train("weisheit", 15.0)
	# What the hero trained stays with their name, fallen or free.
	Training.save_hero(hero_name, player.xp)
	if escaped:
		# The run is over, so this hero's saved game in the safe room is
		# gone too. Other heroes keep theirs.
		if has_save_of(hero_name):
			DirAccess.remove_absolute(save_path(hero_name))
		_show_title(Lang.t("Frei!"), Lang.t("%s ist entkommen und hat %d Gold erbeutet.") % [hero_name, coins], Lang.t("Klicken für ein neues Spiel"))
	elif has_save_of(hero_name):
		# A fallen hero may rise again in the safe room, or once out of the
		# dungeon, on the graveyard or in their own house.
		var info := save_info()
		var place := Lang.t("Klicken oder eine Taste: in deinem Haus weiterspielen.  N: neues Spiel") if info.home \
				else Lang.t("Klicken oder eine Taste: ab dem Friedhof weiterspielen.  N: neues Spiel") if info.escaped \
				else Lang.t("Klicken oder eine Taste: ab der Zuflucht weiterspielen.  N: neues Spiel")
		_show_title(Lang.t("Gefallen"), Lang.t("%s fiel auf Ebene %d mit %d Gold.") % [hero_name, level_index + 1, coins], place)
	else:
		_show_title(Lang.t("Gefallen"), Lang.t("%s fiel auf Ebene %d mit %d Gold.") % [hero_name, level_index + 1, coins], Lang.t("Klicken für ein neues Spiel"))
	_title_text.add_theme_font_size_override("font_size", 90)
	_ranking_slot.add_child(Ranking.build(self, entry))


## Time for the hero to climb one exit step.
const STEP_TIME := 0.2


func _on_exit_reached() -> void:
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	player.face(Vector3.FORWARD)
	player.play("Walking_A")
	# The stairs rise northwards across the exit cell in 8 steps of half a metre:
	# step k (1..8) is 0.5 * k high, its middle 0.5 * k further north.
	var foot := level.cell_to_world(level.exit_cell) + Vector3(0, 0, Level.TILE * 0.5)
	var tween := create_tween()
	tween.tween_property(player, "global_position", foot + Vector3(0, 0, 0.1), 0.15)
	for k in range(1, 9):
		var step := foot + Vector3(0, 0.5 * k, -0.5 * k + 0.25)
		tween.tween_property(player, "global_position:z", step.z, STEP_TIME)
		tween.parallel().tween_property(player, "global_position:y", step.y, STEP_TIME * 0.6) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Each stair gets a footstep, just like walking.
		tween.parallel().tween_callback(func(): Sfx.play(player, "step_%d" % (randi() % 6), -14.0))
	tween.tween_callback(_next_level)
	# Darken while the hero climbs the upper half of the stairs.
	create_tween().tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), STEP_TIME * 5.5) \
			.set_delay(0.15 + STEP_TIME * 3)


func _next_level() -> void:
	if level.building != "":
		_leave_building()
		return
	Sfx.play(self, "level_done", -2.0)
	player.train("weisheit", 10.0)
	Training.save_hero(hero_name, player.xp)
	dry_levels = 0 if level.secret_opened() else dry_levels + 1
	if level_index + 1 >= level_files.size():
		_end_run(true)
		return
	load_level(level_index + 1)
	if level.outdoor:
		_step_out_of_crypt()
		return
	state = State.PLAYING
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
	_announce_level()
	# A breather on the stairs.
	var healed := mini(STAIRS_HEAL, player.max_hp - player.hp)
	if healed > 0:
		player.hp += healed
		_update_hud()
		Effects.float_text(level, player.global_position + Vector3(0, 2.6, 0), "+%d" % healed, Color(0.5, 1.0, 0.5))
	if level.safe:
		_autosave()


## Out of the dungeon at last: the hero walks out of the crypt door into the
## evening light. That is an escape, and it goes into the ranking; but the
## game goes on in the village.
func _step_out_of_crypt() -> void:
	state = State.TRANSITION
	player.frozen = true
	var start := level.cell_to_world(level.start_cell)
	var first := not escaped
	if first:
		escaped = true
		Ranking.add(hero_name, level_index + 1, level.level_name, coins, true)
	var healed := player.max_hp - player.hp
	player.hp = player.max_hp
	# Saved at once, before the walk out: from now on every load starts here,
	# on the graveyard in front of the crypt door (or in the hero's house,
	# once they have one).
	var saved := save_game()
	player.global_position = start + Vector3(0, 0, -3.2)
	player.face(Vector3.BACK)
	player.play("Walking_A")
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 1.2)
	tween.parallel().tween_property(player, "global_position", start, 1.6)
	tween.tween_callback(func():
		player.frozen = false
		player.play("Idle")
		state = State.PLAYING
		_announce_level()
		if healed > 0:
			_update_hud()
			Effects.float_text(level, player.global_position + Vector3(0, 2.6, 0), "+%d" % healed, Color(0.5, 1.0, 0.5))
		var text := Lang.t("Frei! %s ist entkommen und hat %d Gold erbeutet.") % [hero_name, coins] if first else ""
		text += ("\n" if text != "" else "") + (Lang.t("Spiel gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!"))
		get_tree().create_timer(4.8).timeout.connect(func():
			if state == State.PLAYING:
				show_message(text, 3.5)))


## The hero has walked into the house the elder gave and made it their own:
## it is the new place to come back to, saved at once.
func _on_home_claimed() -> void:
	home_claimed = true
	home_given = true
	var saved := save_game()
	var text := Lang.t("Dein Haus ist jetzt dein Startpunkt. Spiel gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!")
	get_tree().create_timer(4.2).timeout.connect(func():
		if state == State.PLAYING:
			show_message(text, 3.0))


## Walks in at a village building's door, to its own floor.
func go_inside(building: String) -> void:
	if state != State.PLAYING or not interiors.has(building):
		return
	_home_given_now()
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.5)
	tween.tween_callback(func():
		load_level(interiors[building], false)
		player.frozen = false
		state = State.PLAYING
		create_tween().tween_property(_fade, "color:a", 0.0, 0.6)
		_announce_level())


## The banker shows the hero down into the vault cellar.
func go_to_vaults() -> void:
	go_inside("b")


## Up the stairs of a building floor and out of its door into the village.
func _leave_building() -> void:
	var building := level.building
	load_level(_outdoor_index(), false)
	if level is Outdoor and level.doors.has(building):
		player.global_position = level.doors[building]
		player.face(Vector3.BACK)
	_snap_camera()
	state = State.PLAYING
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)


## Reaching a safe room saves the game at once, so the way there is never
## lost. The notice waits until the level message has had its say.
func _autosave() -> void:
	var saved := save_game()
	var text := Lang.t("Spiel gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!")
	get_tree().create_timer(4.2).timeout.connect(func():
		if state == State.PLAYING and level != null and level.safe:
			show_message(text, 2.4))


# --- Per frame --------------------------------------------------------------

func _camera_offset() -> Vector3:
	var pitch := deg_to_rad(lerpf(CAMERA_PITCH, CLOSE_PITCH, _zoom))
	var distance := lerpf(CAMERA_DISTANCE, CLOSE_DISTANCE, _zoom)
	# Up close the camera looks at the hero's chest instead of the feet.
	return Vector3(0, sin(pitch), cos(pitch)) * distance + Vector3(0, lerpf(1.0, 1.6, _zoom), 0)


func zoom_by(steps: float) -> void:
	# Steps below 0 look from further out (and a little more from above) than the normal view.
	_zoom_target = clampf(_zoom_target + steps * ZOOM_STEP, -ZOOM_OUT_STEPS * ZOOM_STEP, 1.0)


func _snap_camera() -> void:
	var p := player.global_position
	p.y = 0.0
	camera.global_position = p + _camera_offset()


## Tips on sneaking, shown one after another the first time the hero sees
## an armoured guardian on a level; -1 until then.
const GUARDIAN_TIPS := [
	"Vor dir wacht ein gepanzerter Wächter mit dem Schlüssel.\nKlingen und Messer prallen an ihm ab.\nNur ein Stich in den Rücken tötet ihn, mit einem einzigen Schlag.",
	"Drück C (oder Doppelklick), um zu schleichen, bevor du eintrittst.\nEr sieht nur, was im Licht seiner Feuerschale steht.\nAm dunklen Rand des Saals bist du unsichtbar.",
	"Schleich im Schatten um ihn herum, bis du in seinem Rücken stehst.\nDann tritt heran und schlag zu (F).\nEntdeckt er dich, lauf hinaus: Er gibt bald auf.",
]
var _guardian_tip := -1


## The first time the hero sees an armoured guardian, explains how to beat it.
func _guardian_intro() -> void:
	if state != State.PLAYING or _message_busy() or _guardian_tip >= GUARDIAN_TIPS.size():
		return
	if _guardian_tip < 0:
		# Told in the corridor, before the hall: the hero must sneak before
		# stepping into the guardian's sight.
		if not level.enemies.any(func(e): return is_instance_valid(e) and not e.dead and e.kind == "waechter" \
				and e.global_position.distance_to(player.global_position) < 34.0):
			return
		_guardian_tip = 0
	learn(GUARDIAN_TIPS[_guardian_tip])
	show_message(Lang.t(GUARDIAN_TIPS[_guardian_tip]), 6.5)
	_guardian_tip += 1


func _process(delta: float) -> void:
	_eerie(delta)
	_tick_clock(delta)
	_show_weather()
	# A skeleton on the hero's heels keeps the fight going, and a hero who
	# has been spotted cannot stay hidden.
	if state == State.PLAYING and level and level.enemies.any(func(e): return is_instance_valid(e) and e.is_hunting()):
		player.mark_fight()
		if player.sneaking:
			player.set_sneaking(false)
			show_message(Lang.t("Entdeckt! Du kannst nicht mehr schleichen."), 1.6)
	_guardian_intro()
	_quest_mark_timer -= delta
	if _quest_mark_timer <= 0.0:
		_quest_mark_timer = 0.25
		refresh_quest_marks()
	var p := player.global_position
	p.y = minf(p.y, 0.5) if not player.frozen else p.y
	_zoom = move_toward(_zoom, _zoom_target, delta * 2.5)
	camera.rotation_degrees.x = -lerpf(CAMERA_PITCH, CLOSE_PITCH, _zoom)
	var target := p + _camera_offset()
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.0 * delta))
	if _shake > 0.0:
		# The ground trembles while a secret wall sinks.
		_shake = maxf(0.0, _shake - delta)
		var strength := 0.25 * minf(1.0, _shake)
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * strength
	var dust := get_node("Dust") as Node3D
	dust.global_position = player.global_position + Vector3(0, 2.0, 0)
	_steer_by_mouse(delta)
	_update_drag(delta)
	_update_run_meter()
	if state == State.PLAYING:
		fishing.tick(delta)
	elif fishing.is_fishing():
		fishing.stop()
	if state != State.PLAYING or not _shrine.is_empty() or menus.is_open():
		_prompt.text = ""
		return
	if not _pending_station.is_empty() and player.can_act() and _arrived(_pending_station.pos):
		player.path.clear()
		if _reach(_pending_station.pos) <= Level.SEARCH_RANGE + 0.3:
			_use_station(_pending_station)
		_pending_station = {}
	if _pending_crate != null and player.can_act():
		if not is_instance_valid(_pending_crate) or not level.crates.has(_pending_crate):
			_pending_crate = null
		elif _arrived(_pending_crate.global_position) or _reach(_pending_crate.global_position) <= Level.CRATE_REACH:
			var crate_pos := _pending_crate.global_position
			_pending_crate = null
			if _reach(crate_pos) <= Level.CRATE_REACH:
				var why := pick_up_crate(crate_pos)
				if why != "":
					show_message(why, 1.6)
	if not _pending_search.is_empty() and player.can_act() and _arrived(_pending_search.pos):
		player.path.clear()
		if _reach(_pending_search.pos) <= Level.SEARCH_RANGE + 0.3:
			_search(_pending_search)
		_pending_search = {}
	var near := level.nearest_interactable(player.global_position)
	# Only the first levels explain how to search; after that players know.
	_prompt.text = Lang.t("Dagegenlaufen, um %s zu untersuchen") % Lang.t(_with_article(near.label)) if level_index < 2 and not near.is_empty() and not near.searched else ""
	var station := level.nearest_station(player.global_position)
	if not station.is_empty() and (level_index < 2 or station.kind != "schrein"):
		_prompt.text = {
			"schrein": Lang.t("Dagegenlaufen, um den Schrein zu berühren"),
			"bett": Lang.t("Dagegenlaufen, um dich ins Bett zu legen"),
			"lager": Lang.t("Dagegenlaufen, um die Lagertruhe zu öffnen"),
			"haendler": Lang.t("Dagegenlaufen, um mit %s zu handeln") % station.npc.display_name if station.has("npc") else Lang.t("Dagegenlaufen, um mit dem Händler zu handeln"),
			"brunnen": Lang.t("Dagegenlaufen, um aus dem Brunnen zu trinken"),
			"npc": Lang.t("Dagegenlaufen, um mit %s zu reden") % station.npc.display_name if station.has("npc") else "",
			"bank": Lang.t("Dagegenlaufen, um mit %s zu reden") % station.npc.display_name if station.has("npc") else "",
			"barbier": Lang.t("Dagegenlaufen, um zu %s zu gehen") % station.npc.display_name if station.has("npc") else "",
			"eingang": Lang.t("Dagegenlaufen, um %s zu betreten") % Lang.t(station.get("name", "")),
			"tresor": Lang.t("Dagegenlaufen, um dein Schließfach zu öffnen"),
			"steinmetz": Lang.t("Dagegenlaufen, um bei %s Steinblöcke zu kaufen") % station.npc.display_name if station.has("npc") else "",
			"schmied": Lang.t("Dagegenlaufen, um mit %s an der Esse zu arbeiten") % station.npc.display_name if station.has("npc") else "",
			"werkbank": Lang.t(CraftingSquare.bench_of(station.get("craft", "")).get("prompt", "")),
		}[station.kind]
	elif _prompt.text == "" and level.crate_in_reach(player) != null:
		_prompt.text = Lang.t("E oder Klick: Kiste aufheben")
	elif _prompt.text == "" and _drag_stone != null:
		_prompt.text = Lang.t("Loslassen: Block rutscht dorthin") if _drag_stone.heavy else Lang.t("Loslassen: Steinblock dorthin   Rechtsklick: drehen")
	elif _prompt.text == "" and level.stone_in_reach(player) != null:
		if level.stone_in_reach(player).heavy:
			_prompt.text = Lang.t("E oder Klick: Block schieben   Ziehen: rutschen lassen")
		else:
			_prompt.text = Lang.t("E oder Klick: Steinblock aufheben   Ziehen: verschieben")
	# By the water the line can be cast, also next to the fountain.
	var fish_prompt := ""
	if fishing.state == Fishing.BITE:
		fish_prompt = Lang.t("G: Anschlagen!")
	elif fishing.is_fishing():
		fish_prompt = Lang.t("G: Leine einholen")
	elif not fishing.water_near().is_empty():
		fish_prompt = Lang.t("G: Angeln")
	if fish_prompt != "":
		_prompt.text = fish_prompt if _prompt.text == "" else _prompt.text + "   " + fish_prompt


func _reach(pos: Vector3) -> float:
	return Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z).length()


## The hero has walked up to a clicked thing: at the end of the path, or close
## enough already (the last steps can be blocked by the thing itself).
func _arrived(pos: Vector3) -> bool:
	return player.path.is_empty() or _reach(pos) <= WALK_UP_TO + 0.6


## While the left mouse button is held down on the dungeon, the hero keeps
## running towards the cursor. A short click still walks, attacks or searches.
func _steer_by_mouse(delta: float) -> void:
	player.steer = Vector3.ZERO
	player.wants_run = false
	if not _mouse_held or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_held = false
		_mouse_held_time = 0.0
		return
	if state != State.PLAYING or not _shrine.is_empty() or menus.is_open():
		return
	_mouse_held_time += delta
	if _mouse_held_time < HOLD_TO_RUN:
		return
	var point = _mouse_to_floor(get_viewport().get_mouse_position())
	if point == null:
		return
	var to: Vector3 = point - player.global_position
	to.y = 0.0
	if to.length() > 0.6:
		player.steer = to.normalized()
		# Holding the button runs, for as long as the hero's breath lasts.
		player.wants_run = true
		_pending_search = {}
		_pending_station = {}


## Sees every input before buttons or the game use it, so the first click
## or key press anywhere can start the music.
func _input(event: InputEvent) -> void:
	Music.notice_input(event)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel or + and - zoom the camera.
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed and state == State.PLAYING:
			zoom_by(event.factor if event.factor > 0.0 else 1.0) if event.button_index == MOUSE_BUTTON_WHEEL_UP else zoom_by(-(event.factor if event.factor > 0.0 else 1.0))
		return
	if event is InputEventKey and event.pressed and state == State.PLAYING and event.physical_keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
		zoom_by(2.0 if event.physical_keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD] else -2.0)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_held = event.pressed
		if not event.pressed and _drag_stone != null:
			_drop_stone()
			return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed:
		return
	match state:
		State.TITLE:
			if _name_box.visible or Lang.language == "":
				return
			if menus.is_open():
				# The load window's own buttons choose; Esc goes back.
				if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
					menus.close()
				return
			if has_save() and not (event is InputEventKey and event.physical_keycode == KEY_N):
				continue_game()
			else:
				new_game()
		State.WON:
			new_game()
		State.OVER:
			if has_save_of(hero_name) and not (event is InputEventKey and event.physical_keycode == KEY_N):
				continue_game()
			else:
				new_game()
		State.PLAYING:
			if not _shrine.is_empty():
				if event is InputEventKey and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
					_choose_gift(event.physical_keycode - KEY_1)
				return
			if menus.is_open():
				if event is InputEventKey and event.physical_keycode in [KEY_I, KEY_H, KEY_P, KEY_ESCAPE]:
					menus.close()
				return
			if event is InputEventKey:
				match event.physical_keycode:
					KEY_SPACE:
						player.jump()
					KEY_F, KEY_J:
						player.melee()
					KEY_R, KEY_K:
						player.throw_knife()
					KEY_I:
						if player.can_act():
							menus.open("inventar")
					KEY_L:
						if player.can_act():
							menus.open("laden")
					KEY_H:
						if player.can_act():
							menus.open("kompendium")
					KEY_P:
						if player.can_act():
							menus.open("charakter")
					KEY_M:
						_toggle_sound()
					KEY_TAB:
						toggle_drawer()
					KEY_C:
						_toggle_sneak()
					KEY_G:
						fish_action()
					KEY_E:
						var why_not := ""
						if level.crate_in_reach(player) == null and level.stone_in_reach(player) != null:
							why_not = take_stone()
						else:
							why_not = pick_up_crate()
						if why_not != "":
							show_message(why_not, 1.6)
					KEY_B:
						var no_place := place_stone()
						if no_place != "":
							show_message(no_place, 1.6)
					KEY_Q:
						var no_room := put_down_crate()
						if no_room != "":
							show_message(no_room, 1.6)
					KEY_ESCAPE:
						if player.can_act():
							menus.open("beenden")
			elif event is InputEventMouseButton:
				var point = _mouse_to_floor(event.position)
				if point == null:
					return
				if event.button_index == MOUSE_BUTTON_RIGHT and _drag_stone != null:
					# Turns the dragged block a quarter round.
					_drag_along_x = not _drag_along_x
					return
				if event.button_index == MOUSE_BUTTON_RIGHT:
					# While running with the left button held, right click jumps.
					if _mouse_held and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and player.is_running():
						player.jump()
					else:
						player.throw_knife(point)
				elif event.button_index == MOUSE_BUTTON_LEFT:
					if _grab_stone(event.position):
						_mouse_held = false
					elif event.double_click:
						_toggle_sneak()
					else:
						_click(point)


## Key G or the "Angeln" button: casts the line by the water, strikes when
## a fish bites, or draws the line in (see Fishing).
func fish_action() -> void:
	if state != State.PLAYING or menus.is_open() or not _shrine.is_empty():
		return
	var why := fishing.press()
	if why != "":
		show_message(why, 1.6)


func _mouse_to_floor(screen_pos: Vector2):
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if dir.y > -0.01:
		return null
	return origin + dir * (-origin.y / dir.y)


func _click(point: Vector3) -> void:
	# Clicking an enemy attacks it: a strike when it is in reach, else the
	# hero walks up to it and strikes. Clicking an object searches it.
	player.stop_hunt()
	for e in level.enemies:
		if is_instance_valid(e) and not e.dead and e.visible and Vector2(e.global_position.x - point.x, e.global_position.z - point.z).length() < 1.6:
			if player.global_position.distance_to(e.global_position) < Player.MELEE_RANGE + 1.0:
				player.melee()
			else:
				player.charge(e)
			return
	# Clicking a crate picks it up: right away when it is in reach, else
	# after walking up to it.
	var crate := level.crate_at(point)
	_pending_crate = null
	if crate != null and crate == level.crate_in_reach(player, crate.global_position):
		var why := pick_up_crate(crate.global_position)
		if why != "":
			show_message(why, 1.6)
		return
	if crate != null and level.crate_on(crate) == null and player.global_position.y < crate.top() - 0.3 and _reach(crate.global_position) > Level.CRATE_REACH:
		_pending_crate = crate
		_pending_search = {}
		_pending_station = {}
		player.walk_to(crate.global_position, WALK_UP_TO)
		return
	var station := level.nearest_station(point, 2.2)
	if not station.is_empty():
		_pending_station = station
		_pending_search = {}
		player.walk_to(station.pos, WALK_UP_TO)
		return
	var obj := level.nearest_interactable(point, 2.2)
	if not obj.is_empty():
		_pending_search = obj
		_pending_station = {}
		player.walk_to(obj.pos, WALK_UP_TO)
		return
	_pending_search = {}
	_pending_station = {}
	player.walk_to(point)


## Seconds until the next far-off howl or scream somewhere in the dungeon.
var _eerie_timer := 20.0
const EERIE_SOUNDS := 6


## Now and then something howls, roars or screams far away in the dark.
## Never in a safe room.
func _eerie(delta: float) -> void:
	if state != State.PLAYING or level == null or level.safe:
		return
	if level and (level.outdoor or level.building != ""):
		return
	_eerie_timer -= delta
	if _eerie_timer > 0.0:
		return
	_eerie_timer = randf_range(25.0, 70.0)
	Sfx.play(self, "eerie_%d" % (randi() % EERIE_SOUNDS), randf_range(-14.0, -8.0))
