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
const TITLE_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")
const TEXT_FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const GOLD := Color(1.0, 0.82, 0.4)
## Raised by hand for every bigger update. The build number comes from GitHub.
const VERSION := "0.5"
## Filled in by GitHub with the number of each published build, so the
## version shown in the game changes with every update.
const BUILD := ""
const SAVE_FILE := "user://spielstand.json"

enum State { TITLE, PLAYING, TRANSITION, WON, OVER }

var state := State.TITLE
var _sound_button: Button
var level_files: Array[String] = []
var level_index := 0
var level: Level
var player: Player
var camera: Camera3D
var coins := 0
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
var _fade: ColorRect
var _title: Control
var _title_text: Label
var _title_sub: Label
var _title_prompt: Label
var _message_tween: Tween
var _pending_search := {}
var menus: Menus
## Items left in the safe room's storage chest, and what the merchant sells.
var storage: Array[String] = []
var shop_stock: Array[String] = []
var _title_buttons: Control
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
var _ranking_slot: Control
var _lang_row: Control
## Holding the left mouse button this long turns a click into running.
const HOLD_TO_RUN := 0.2
## How close to a clicked object's middle the hero walks before using it:
## half its size plus the hero's own width.
const WALK_UP_TO := 2.0
var _mouse_held := false
var _mouse_held_time := 0.0


func _ready() -> void:
	Lang.setup()
	for f in DirAccess.get_files_at(LEVEL_DIR):
		if f.ends_with(".txt"):
			level_files.append(LEVEL_DIR + f)
	level_files.sort()
	_setup_world()
	_setup_hud()
	var comic := Comic.new()
	comic.camera = camera
	add_child(comic)
	menus = Menus.new()
	add_child(menus)
	Sfx.load_settings()
	_update_sound_button()
	Sfx.start_ambience(self)
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
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Faint pale moonlight from above gives every stone a soft shadow.
	var moon := DirectionalLight3D.new()
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

	var quit := _make_button(Lang.t("Beenden"), _on_quit_pressed)
	quit.custom_minimum_size = Vector2(130, 44)
	quit.add_theme_font_size_override("font_size", 17)
	quit.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	quit.offset_right = -24
	quit.offset_top = 104
	_hud.add_child(quit)
	_sound_button = _make_button("", _toggle_sound)
	_sound_button.custom_minimum_size = Vector2(130, 44)
	_sound_button.add_theme_font_size_override("font_size", 17)
	_sound_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_sound_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_sound_button.offset_right = -24
	_sound_button.offset_top = 156
	_hud.add_child(_sound_button)
	_update_sound_button()

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
	help.text = Lang.t("WASD: laufen   Leertaste: springen   F: Schlag   R: Messer   M: Ton\nI: Inventar   H: Kompendium   L: Laden   C/Doppelklick: schleichen   Dagegenlaufen: benutzen\nMaus: Klick/halten laufen, Rechtsklick: Messer (im Lauf: Sprung)")
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

	# The "db" of the devilbane logo as a faint watermark in the corner,
	# above the buttons (the "HARDCORE" lettering below it is cut off).
	var mark := TextureRect.new()
	var db := AtlasTexture.new()
	db.atlas = preload("res://assets/logo/devilbane_logo.png")
	db.region = Rect2(0, 0, 480, 388)
	mark.texture = db
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mark.offset_left = -116
	mark.offset_top = -190
	mark.offset_right = -20
	mark.offset_bottom = -102
	mark.modulate = Color(1, 1, 1, 0.35)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(mark)

	var buttons := GridContainer.new()
	buttons.columns = 3
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_theme_constant_override("v_separation", 10)
	buttons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buttons.offset_right = -20
	buttons.offset_bottom = -20
	_hud.add_child(buttons)
	buttons.add_child(_make_button(Lang.t("Kompendium"), func(): if state == State.PLAYING and player.can_act() and not menus.is_open(): menus.open("kompendium")))
	buttons.add_child(_make_button(Lang.t("Laden"), func(): if state == State.PLAYING and player.can_act() and not menus.is_open(): menus.open("laden")))
	buttons.add_child(_make_button(Lang.t("Inventar"), func(): if state == State.PLAYING and player.can_act() and not menus.is_open(): menus.open("inventar")))
	buttons.add_child(_make_button(Lang.t("Springen"), func(): if state == State.PLAYING: player.jump()))
	buttons.add_child(_make_button(Lang.t("Werfen"), func(): if state == State.PLAYING: player.throw_knife()))
	buttons.add_child(_make_button(Lang.t("Schlagen"), func(): if state == State.PLAYING: player.melee()))

	_setup_shrine_panel()

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
	for entry in [[Lang.t("Spielstand laden"), continue_game], [Lang.t("Neues Spiel"), new_game]]:
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
	if s.kind == "schrein":
		_open_shrine(s)
	elif s.kind == "brunnen":
		_drink(s)
	else:
		player.face(s.pos - player.global_position)
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


func _update_hud() -> void:
	_level_label.text = Lang.t("Ebene %d: %s") % [level_index + 1, Lang.t(level.level_name)]
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
	_key_label.add_theme_color_override("font_color", GOLD if level.has_key else Color(1, 1, 1, 0.45))


# --- Flow -------------------------------------------------------------------

func load_level(index: int, restock := true) -> void:
	if level:
		level.queue_free()
	level_index = index
	level = Level.new()
	level.load_from_file(level_files[index])
	level.depth = index
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
	level.player_hurt.connect(player.spring_trap)
	level.enemy_killed.connect(_on_enemy_killed)
	level.exit_reached.connect(_on_exit_reached)
	_pending_search = {}
	_pending_station = {}
	if level.safe and restock:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		shop_stock.clear()
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
	if has_save():
		_show_title(text, sub, Lang.t("Klicken oder eine Taste: weiterspielen.  N: neues Spiel"))
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
	_name_edit.text = hero_name
	_name_edit.grab_focus()
	_name_edit.select_all()


func _setup_name_box() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.visible = false
	_title.add_child(box)
	_name_box = box
	var ask := _make_label(TEXT_FONT, 30, GOLD)
	ask.text = Lang.t("Wie heißt dein Held?")
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ask)
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
	box.add_child(_name_edit)
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
	secrets_found = 0
	dry_levels = 0
	storage.clear()
	shop_stock.clear()
	away_plan = Offline.empty_plan()
	player.knives = 5
	player.reset_gifts()
	# The hero keeps what they trained in earlier runs under this name.
	player.xp = Training.load_hero(hero_name)
	player.refresh_stats()
	_leave_title(func():
		player.hp = player.max_hp
		load_level(_start_level()))


func continue_game() -> void:
	if (state != State.TITLE and state != State.OVER) or not has_save():
		return
	var data := _read_save()
	_leave_title(func():
		_apply_save(data)
		_return_from_away(data))


## Loads the saved game in the middle of a run (from the "Laden" window).
func load_saved_game() -> void:
	if state != State.PLAYING or not has_save():
		return
	var data := _read_save()
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


## Name, level and gold of the saved game, or nothing when there is none.
func save_info() -> Dictionary:
	if not has_save():
		return {}
	var data := _read_save()
	return {"name": data.get("name", Lang.t("Namenlos")), "level": int(data.level) + 1, "coins": int(data.coins)}


func _read_save() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	return data if data is Dictionary else {}


func _apply_save(data: Dictionary) -> void:
	hero_name = data.get("name", Lang.t("Namenlos"))
	coins = int(data.coins)
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
	player.xp = Training.load_hero(hero_name)
	lore.assign(data.get("lore", []))
	var plan = data.get("plan", {})
	away_plan = plan if plan is Dictionary and not plan.is_empty() else Offline.empty_plan()
	player.bag.assign(data.bag)
	player.refresh_stats()
	load_level(clampi(int(data.level), 0, level_files.size() - 1), false)
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

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)


## Writes everything needed to wake up in this safe room later. True when
## the file is really there afterwards. Going away also writes the hero's
## plan for the time away and when the player left.
func save_game(going_away := false) -> bool:
	Training.save_hero(hero_name, player.xp)
	var data := {
		"version": 1, "name": hero_name, "level": level_index, "coins": coins, "secrets": secrets_found, "dry": dry_levels, "hp": player.hp, "knives": player.knives,
		"gift_hp": player.gift_hp, "gift_power": player.gift_power, "gift_speed": player.gift_speed, "gift_armor": player.gift_armor,
		"equipped": player.equipped, "wear": player.wear, "bag": player.bag, "storage": storage, "shop": shop_stock,
		"lore": lore, "plan": away_plan,
	}
	if going_away:
		data.away = {"plan": Offline.normalized(away_plan, away_choices()), "since": Time.get_unix_time_from_system()}
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return FileAccess.file_exists(SAVE_FILE)


## The hero lies down in the safe room's bed: save, then back to the title.
func sleep() -> void:
	var saved := save_game(true)
	# Say so at once, so nobody has to wonder whether the save went through.
	show_message(Lang.t("Spiel gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!"), 2.4)
	state = State.TRANSITION
	player.frozen = true
	player.play("Lie_Down", 0.2)
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 1.2)
	tween.tween_callback(func(): _show_start_title(Lang.t("Gute Nacht"), Lang.t("Dein Spiel ist gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!")))


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


## Remembers an explanation for the compendium, once.
func learn(entry: String) -> void:
	if not lore.has(entry):
		lore.append(entry)
		# Understanding something new trains the mind.
		player.train("intelligenz", 5.0)


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
	Sfx.play(self, "key")
	show_message(Lang.t("Du hast den Schlüssel gefunden!"))
	player.train("weisheit", 3.0)
	_update_hud()


## A lever torch found: a click and a golden message, then, a moment later,
## rumbling and shaking ground while the secret wall sinks.
func _on_secret_found(lever_pos: Vector3, wall_pos: Vector3) -> void:
	secrets_found += 1
	level.secret_bonus = secrets_found
	player.train("weisheit", 5.0)
	Comic.pop(lever_pos, "lever")
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
	Effects.float_text(level, player.global_position + Vector3(0, 3.0, 0), Items.item_name(id), Color(0.75, 0.9, 1.0))
	show_message(Lang.t("Gefunden: %s (%s)") % [Items.item_name(id), Items.describe(id)] + Lang.t("\nTaste I öffnet das Inventar."), 5.0)
	_update_hud()


func _on_coins_collected(amount: int) -> void:
	coins += _gold(amount)
	Sfx.play(self, "coin")
	_update_hud()


## Gold found, doubled by the lucky clover.
func _gold(amount: int) -> int:
	return amount * 2 if player.has_special("gluecksklee") else amount


func _on_enemy_killed() -> void:
	show_message(Lang.t("Das Skelett zerfällt zu Staub."), 2.5)
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
		Effects.float_text(level, obj.icon_pos, Lang.t("Schon durchsucht"), Color(0.8, 0.8, 0.8))
		return
	if obj.loot.has("item") and player.bag.size() >= Items.BAG_SIZE:
		if not _message_busy():
			show_message(Lang.t("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg."), 2.0)
		return
	player.play_once("Interact", 0.55)
	Sfx.play(self, "chest" if obj.label == "Schatztruhe" else "rummage", -3.0)
	var loot := level.search(obj)
	# Searching every nook trains a feeling for where things hide.
	player.train("intuition", 1.0)
	var text := Lang.t("%s: leer") % Lang.t(obj.label)
	var color := Color(0.8, 0.8, 0.85)
	if loot.has("gold"):
		Sfx.play(self, "coin")
		coins += _gold(loot.gold)
		text = Lang.t("+%d Gold") % _gold(loot.gold)
		color = GOLD
	elif loot.has("knives"):
		player.knives += loot.knives
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
		var found := Lang.t("Gefunden: %s (%s)") % [Items.item_name(loot.item), Items.describe(loot.item)]
		text = Items.item_name(loot.item) if text.ends_with("leer") else text + "  +" + Items.item_name(loot.item)
		color = Color(0.75, 0.9, 1.0)
		show_message(found + Lang.t("\nTaste I öffnet das Inventar."), 5.0)
	Effects.float_text(level, obj.icon_pos, text, color)
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
		# The run is over, so the saved game in the safe room is gone too.
		if has_save():
			DirAccess.remove_absolute(SAVE_FILE)
		_show_title(Lang.t("Frei!"), Lang.t("%s ist entkommen und hat %d Gold erbeutet.") % [hero_name, coins], Lang.t("Klicken für ein neues Spiel"))
	elif has_save():
		# A fallen hero may rise again in the safe room.
		_show_title(Lang.t("Gefallen"), Lang.t("%s fiel auf Ebene %d mit %d Gold.") % [hero_name, level_index + 1, coins], Lang.t("Klicken oder eine Taste: ab der Zuflucht weiterspielen.  N: neues Spiel"))
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
	tween.tween_callback(_next_level)
	# Darken while the hero climbs the upper half of the stairs.
	create_tween().tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), STEP_TIME * 5.5) \
			.set_delay(0.15 + STEP_TIME * 3)


func _next_level() -> void:
	Sfx.play(self, "level_done", -2.0)
	player.train("weisheit", 10.0)
	Training.save_hero(hero_name, player.xp)
	dry_levels = 0 if level.secret_opened() else dry_levels + 1
	if level_index + 1 >= level_files.size():
		_end_run(true)
		return
	load_level(level_index + 1)
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
	# One step below 0 looks from a little further out than the normal view.
	_zoom_target = clampf(_zoom_target + steps * ZOOM_STEP, -ZOOM_STEP, 1.0)


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
	_guardian_intro()
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
	if state != State.PLAYING or not _shrine.is_empty() or menus.is_open():
		_prompt.text = ""
		return
	if not _pending_station.is_empty() and player.can_act() and _arrived(_pending_station.pos):
		player.path.clear()
		if _reach(_pending_station.pos) <= Level.SEARCH_RANGE + 0.3:
			_use_station(_pending_station)
		_pending_station = {}
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
			"haendler": Lang.t("Dagegenlaufen, um mit dem Händler zu handeln"),
			"brunnen": Lang.t("Dagegenlaufen, um aus dem Brunnen zu trinken"),
		}[station.kind]


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
		_pending_search = {}
		_pending_station = {}


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
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed:
		return
	match state:
		State.TITLE:
			if _name_box.visible or Lang.language == "":
				return
			if has_save() and not (event is InputEventKey and event.physical_keycode == KEY_N):
				continue_game()
			else:
				new_game()
		State.WON:
			new_game()
		State.OVER:
			if has_save() and not (event is InputEventKey and event.physical_keycode == KEY_N):
				continue_game()
			else:
				new_game()
		State.PLAYING:
			if not _shrine.is_empty():
				if event is InputEventKey and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
					_choose_gift(event.physical_keycode - KEY_1)
				return
			if menus.is_open():
				if event is InputEventKey and event.physical_keycode in [KEY_I, KEY_H, KEY_ESCAPE]:
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
					KEY_M:
						_toggle_sound()
					KEY_C:
						_toggle_sneak()
					KEY_ESCAPE:
						if player.can_act():
							menus.open("beenden")
			elif event is InputEventMouseButton:
				var point = _mouse_to_floor(event.position)
				if point == null:
					return
				if event.button_index == MOUSE_BUTTON_RIGHT:
					# While running with the left button held, right click jumps.
					if _mouse_held and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and player.is_running():
						player.jump()
					else:
						player.throw_knife(point)
				elif event.button_index == MOUSE_BUTTON_LEFT:
					if event.double_click:
						_toggle_sneak()
					else:
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
	_eerie_timer -= delta
	if _eerie_timer > 0.0:
		return
	_eerie_timer = randf_range(25.0, 70.0)
	Sfx.play(self, "eerie_%d" % (randi() % EERIE_SOUNDS), randf_range(-14.0, -8.0))
