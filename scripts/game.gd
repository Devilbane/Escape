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
## Button text while the pointer is over the button: a lighter gold.
const BUTTON_HOVER_TEXT := Color(1.0, 0.92, 0.66)
## Raised by hand for every bigger update. The build number comes from GitHub.
const VERSION := "0.5"
## Filled in by GitHub with the number of each published build, so the
## version shown in the game changes with every update.
const BUILD := ""
## The saved games live in this folder, one file per slot ("platz_1.json",
## "platz_2.json", ...). The player picks the slot when a new game starts.
const SAVE_DIR := "user://spielstaende/"
## Test runs save into a folder of their own, so they never touch the
## player's saved games (see _ready).
const TEST_SAVE_DIR := "user://test_spielstaende/"
## How many slots the new game offers. Older versions could leave more saved
## games behind; those keep slots of their own above these.
const SAVE_SLOTS := 5
## The width of the note under the slot buttons.
const SLOT_NOTE_WIDTH := 1100
## Before there could be several saved games there was just this one file;
## on the first start it moves into a slot. Saved games of the versions with
## one file per hero name move into slots the same way.
const OLD_SAVE_FILE := "user://spielstand.json"

enum State { TITLE, PLAYING, TRANSITION, WON, OVER }

var state := State.TITLE
var _sound_button: Button
var _music_button: Button
var _music_slider: HSlider
var _effects_slider: HSlider
## The pull-out menu on the right edge of the screen that holds all the
## clickable buttons, its handle, and how far it is pulled out (0 to 1).
var _drawer: HBoxContainer
var _drawer_handle: Button
var _drawer_arrow: MenuArrow
var _drawer_open := false
var _drawer_t := 0.0
var _drawer_tween: Tween
## The column on the menu's edge that holds the quick window icons above the
## handle, and those icons by the window they open (see _setup_quick_bar).
var _drawer_rail: VBoxContainer
var _quick_buttons := {}
## The home button below the menu handle (see HomeRun).
var _home_button: Button
## The torch button below it: lights or puts out the hand torch (see HandTorch).
var _torch_button: Button
var _torch_count: Label
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
## What has been built onto the hero's house (upgrade id -> true, see
## HomeUpgrades), and the trophies won: enemy kind -> true for the first
## foe of each kind in HomeUpgrades.TROPHIES.
var home_upgrades := {}
var trophies := {}
## The villagers the hero has talked to, by role letter -> true. Once met,
## a villager wears their name over their head. Kept in the saved game.
var met := {}
## The villagers' tasks: offered, running and finished (see Quests). Kept in
## the saved game, so every hero has their own.
var quests := Quests.new(self)
## The hero's map of every level and the exploration journal (see Journal).
var journal := Journal.new(self)
## The first steps in the cell, one card at a time (see Tutorial).
var tutorial := Tutorial.new(self)
## Loot and speech at the left edge of the screen (see EventLog).
var event_log := EventLog.new()
## The card that shows a wall writing the hero noticed (see WritingCard).
var writing_card := WritingCard.new(self)
## How many mornings have dawned in the world above ground since the game
## began. The bounty board pins up fresh hunts each morning (see Bounties).
## The day turns at dawn, so the night after day d's evening, past midnight
## too, still counts as day d: that is when the wandering merchant comes
## (see Wanderer).
var day := 0
## The gold the old dragon's helpers heaped up in its lair, from the loot
## they gather on the open ground at night (see DragonHoard). Kept in the
## saved game.
var hoard := DragonHoard.new()
## The hunts on the bounty board: posted, taken on and paid (see Bounties).
## Kept in the saved game.
var bounties := Bounties.new(self)
## Known recipes and the ingredient pouch (see Crafting). Kept in the saved
## game, like the quests.
var crafting := Crafting.new(self)
## The fighting style the hero named and the masters' wishes (see Wishes).
## Kept in the saved game.
var wishes := Wishes.new(self)
## The line in the water, when the hero is fishing (see Fishing).
var fishing := Fishing.new(self)
## The way home at a press of the home button or X (see HomeRun).
var home_run := HomeRun.new(self)
## What each villager thinks of the hero (see Reputation): discounts,
## gossip and secret recipes. Kept in the saved game.
var reputation := Reputation.new(self)
## Who in the village is tied to whom, and their chats (see VillageTalk).
var village_talk := VillageTalk.new(self)
## The villager whose goods or services are open in a window right now
## (role letter), "" for none: their discount applies (see trader_price).
var trader_role := ""
## Counts down to the next look at who has a task (see refresh_quest_marks).
var _quest_mark_timer := 0.0
## The town house on Weavers' Lane the hero is inside right now (see Homes),
## or 0 when they are not in one.
var inside_house := 0
## Village buildings with floors of their own: building letter -> level index.
var interiors := {}
var coins := 0
## Iron bars for the smith's forge (see Forge), counted like gold.
var iron := 0
## The fine bars the hero has, by metal ("bronze", "silber", "gold"): melted
## at the forge or taken from the dragon's hoard, bought back by the smith
## (see Forge). Kept in the saved game.
var bars := {}
## The hero's companions (see Companions): {"kind", "name"} for each, the
## index of the one that goes with the hero (-1: none, they all wait at
## home), and how many gifts each kind of wild animal has eaten from the
## hero's hand so far. Kept in the saved game.
var companions: Array = []
var following := -1
var trust := {}
## The companion at the hero's side, and those waiting at home while the
## hero is in their house.
var pet: Pet = null
var home_pets: Array[Pet] = []
## Whether the hero has won a fox over (it may be at home).
var has_fox: bool:
	get:
		return owns_companion("fuchs")
## The nameless horrors: their reveal, their bar and their discovery.
var horrors: Horrors
## Drips, creaks, whispers and the like in the dark of the dungeon.
var dungeon_sounds: DungeonSounds
const FOX_LEARN := "Füchse auf den Wiesen sind scheu, aber eine Wurst (bei der Krämerin) lockt sie an: Trägst du eine bei dir, kommt ein Fuchs neugierig näher und frisst sie dir aus der Hand. Nach drei Würsten folgt er dir überallhin, auch ins Verlies. Seine Nase findet Zutaten, die im Boden versteckt sind: Er läuft hin, gräbt sie aus und lässt sie für dich liegen; aufgehoben kommen sie in deinen Zutatenbeutel."
## What the hero already took on each level, by level file: the ids of
## searched furniture and picked up coins (see Level.taken). Kept in the
## saved game, so looted chests stay empty.
var looted := {}
## The stone blocks the hero built with on each level, by level file (see
## Level.built). Kept in the saved game, so buildings stay standing.
var builds := {}
## What lies on the floor of each level, by level file (a town house adds its
## number: "haus.txt#2"), see Level.floor_items. Kept in the saved game, so
## dropped gear and unclaimed loot stay where they fell.
var floors := {}
## Secret rooms found this run; each one sharpens the eye for the next lever.
var secrets_found := 0
## Levels left in a row without finding their secret room.
var dry_levels := 0
## The hero has run into a villager once: from then on the hint that running
## into people talks to them is left out. Kept in the saved game.
var bumped_person := false
## How often each kind of explanatory hint came up, by kind (see _hint).
## Kept in the saved game: after HINT_SHOWINGS times a kind is left out.
var hints_shown := {}
const HINT_SHOWINGS := 2
## The hint kinds on screen this frame and the frame before.
var _hints_now := {}
var _hints_last := {}
## Stations that are a person; their hint goes once the hero bumped one.
const PERSON_STATIONS := ["npc", "bank", "barbier", "haendler", "steinmetz", "schmied", "wanderhaendler"]
## Lives the hero gets back for climbing to the next level.
const STAIRS_HEAL := 3
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
var _hp_bar: ProgressBar
var _hp_fill: StyleBoxFlat
## The hero's passing troubles (poison, a curse, burning, slowness) as icons
## under the life bar (see StatusIcon, hero_ailments).
var _status_row: HBoxContainer
## The hero's boons (stronger blows, speed, hardening) as icons in the status
## block at the top left, just above the event log (see hero_boons).
var _boon_row: HBoxContainer
## Gear to mend, points to spend, upgrades to build: icons under the hero
## level (see hero_notices).
var _notice_row: HBoxContainer
## The life bar: its size, and where its top sits on screen, as a share of
## the screen's height (centred across). It stays at that one spot, under
## where the hero stands in the normal view, whatever the camera does.
const HP_BAR_SIZE := Vector2(96, 8)
const HP_BAR_Y := 0.68
## How far the hero's arms and blade reach out from the feet, in metres: in
## the normal view the bar sits below all of it (tests/event_log.gd).
const HP_BAR_REACH := 1.8
## The bar's colour by the share of life left: green when whole, yellow at
## two thirds, red at one third, deep red near the end, blended between.
const HP_COLORS := [
	[1.0, Color(0.3, 0.8, 0.3)],
	[0.66, Color(0.95, 0.82, 0.2)],
	[0.33, Color(0.85, 0.2, 0.15)],
	[0.0, Color(0.42, 0.02, 0.05)],
]
## The run meter: seconds of running left, as a bar and in numbers.
var _run_bar: ProgressBar
var _xp_bar: ProgressBar
var _xp_label: Label
var _run_label: Label
var _run_fill: StyleBoxFlat
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
## The list of keys at the bottom left (see _setup_hud).
var _help: Label
## Messages that came before the newest one, oldest first, kept above it
## while they are still being read (see show_message), so a new message
## never covers an unread one.
var _message_kept: Array[Label] = []
var _message_box: VBoxContainer
## How long the newest message is meant to stay (see show_message).
var _message_duration := 0.0
## Space kept free left and right of centred on-screen texts.
const SCREEN_TEXT_MARGIN := 80
## Space kept free left and right of the message lines: past the event log
## and the first-steps card at the left edge (see EventLog, Tutorial).
const MESSAGE_MARGIN := EventLog.LEFT + Tutorial.CARD_WIDTH + 16.0
const MESSAGE_FONT_SIZE := 24
## How far above the bottom of the screen the messages sit (their lower edge).
const MESSAGE_BOTTOM := 175.0
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
## What the wandering merchant still has left, and the night he brought it
## for (-1: not rolled yet). A new visit brings new wares (see Wanderer).
var wanderer_stock: Array[String] = []
var wanderer_night := -1
var _title_buttons: Control
var _name_note: Label
## The hero's name, asked for when a new game starts; it goes into the ranking
## and stands over the hero's head like the townsfolk's names (Player.set_display_name).
var hero_name := "":
	set(value):
		hero_name = value
		if player:
			player.set_display_name(value)
## The map being tested from the workshop ("" while playing the game).
var playtest_file := ""
var _name_box: Control
## The folder of the saved games: SAVE_DIR, or TEST_SAVE_DIR in a test run.
var save_dir := SAVE_DIR
var old_save_file := OLD_SAVE_FILE
## The slot this hero's game is saved into.
var save_slot := 1
## The slot chosen in the name box for the new game, and its buttons.
var _new_slot := 1
var _slot_buttons := {}
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
## Set by the map workshop (see LevelEditor) to the map file to test: the game
## starts right on that map with a new hero, keeps nothing (no save, no
## ranking, no training) and goes back to the workshop at its exit.
const PLAYTEST_FLAG := &"escape_playtest_map"
const EDITOR_SCENE := "res://scenes/editor.tscn"
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
## While a heavy block is dragged: a faint ring on the floor around where it
## started, as far as it may go (Level.HEAVY_RANGE).
var _drag_ring: MeshInstance3D = null
var _drag_along_x := true
var _drag_spot := {}
var _drag_time := 0.0
var _drag_press := Vector2.ZERO
## A press shorter than this, without moving the block, is a click on it.
const DRAG_CLICK := 0.25
const HEAVY_LEARN := "Alte, schwere Steinblöcke liegen in manchen Kammern des Verlieses. In die Tasche passen sie nicht, aber sie rutschen über den Boden: E (oder ein Klick) schiebt einen ein Stück von dir weg, mit der Maus ziehst du ihn auf ein freies Feld in der Nähe, und ein Rechtsklick dabei dreht ihn. Weiter als 5 Felder von seinem alten Platz rückt kein Block; der helle Kreis beim Ziehen zeigt, wie weit. Liegt auf jeder Druckplatte einer Kammer ein Block, öffnet sich ihr Eisengitter."
const STONE_LEARN := "Steinblöcke kauft man beim Steinmetz im Dorf. Abstellen mit B (oder „Abstellen“ im Inventar): der Block legt sich quer vor dich, auf den Boden oder auf andere Blöcke. Mit der linken Maustaste greifst du einen Block, ziehst ihn auf ein anderes Feld in der Nähe und lässt los; ein Rechtsklick dabei dreht ihn. E nimmt einen Block wieder in die Tasche. Auf einen Block steigst du einfach hinauf, auf zwei mit einem Sprung. Skelette und Räuber können nicht klettern: Eine Mauer aus Blöcken hält sie fern, und sie müssen außen herum."


# --- The event bus -------------------------------------------------------------

## Who listens to what on the event bus (see Events): the features report
## there, and the game and the other features react, so they do not call
## each other. Listed in the order they hear it.
func _bus_links() -> Array:
	var bus := Events.bus()
	return [
		[bus.news_told, quest_news],
		[bus.lore_learned, learn],
		[bus.enemy_slain, Callable(Factions, "on_hero_kill")],
		[bus.enemy_slain, bounties.on_kill],
		[bus.quest_done, quest_reward],
		[bus.quest_done, reputation.on_quest_done],
		[bus.quest_item_given, update_after_quest],
		[bus.reputation_rose, reputation_rose],
		[bus.traded, reputation.on_trade],
		[bus.map_grew, map_notice],
		[bus.map_explored, map_explored],
		[bus.writing_found, writing_found],
		[bus.trap_spotted, trap_spotted],
		[bus.enemy_felled, xp_for_kill],
		[bus.quest_done, xp_for_task],
		[bus.bounty_paid, xp_for_bounty],
		[bus.riddle_solved, xp_for_riddle],
		[bus.hero_acted, tutorial.on_hero_acted],
		[bus.hero_acted, home_run.on_hero_acted],
		[bus.loot_found, event_log.add_loot],
		[bus.speech_said, heard],
		[bus.loot_carried_off, _on_loot_carried_off],
	]


func _enter_tree() -> void:
	for link in _bus_links():
		var heard: Signal = link[0]
		if not heard.is_connected(link[1]):
			heard.connect(link[1])


func _exit_tree() -> void:
	for link in _bus_links():
		var heard: Signal = link[0]
		if heard.is_connected(link[1]):
			heard.disconnect(link[1])


func _ready() -> void:
	Lang.setup()
	if get_tree().get_script() != null:
		# A headless test runs as a script of its own: its saves stay apart.
		save_dir = TEST_SAVE_DIR
		old_save_file = "user://test_spielstand.json"
	_move_old_saves()
	for f in DirAccess.get_files_at(LEVEL_DIR):
		if f.ends_with(".txt"):
			level_files.append(LEVEL_DIR + f)
	level_files.sort()
	# Gear made in the map workshop, so saved games that carry it know it.
	Creations.register_all()
	if Engine.has_meta(PLAYTEST_FLAG):
		playtest_file = str(Engine.get_meta(PLAYTEST_FLAG))
		Engine.remove_meta(PLAYTEST_FLAG)
		level_files.append(playtest_file)
	Training.keep = playtest_file == ""
	for i in level_files.size():
		for line in FileAccess.get_file_as_string(level_files[i]).split("\n"):
			if line.begins_with("building:") and not interiors.has(line.substr(9).strip_edges()):
				interiors[line.substr(9).strip_edges()] = i
	_setup_world()
	_setup_hud()
	tutorial.setup(_hud)
	writing_card.setup(_hud)
	var comic := Comic.new()
	comic.camera = camera
	add_child(comic)
	menus = Menus.new()
	add_child(menus)
	horrors = Horrors.new(self)
	add_child(horrors)
	dungeon_sounds = DungeonSounds.new(self)
	add_child(dungeon_sounds)
	Sfx.load_settings()
	Sfx.watch_focus(self)
	Sfx.click_on_buttons(get_tree())
	_update_sound_button()
	_ambience = Sfx.start_ambience(self)
	_rain_sound = Sfx.start_loop(self, "rain")
	Music.load_settings()
	Music.start(self)
	_update_music_controls()
	menus.setup(self, _hud)
	player = Player.new()
	add_child(player)
	player.set_display_name(hero_name)
	# The hand torch speaks through the message line (see HandTorch).
	player.torch.notice.connect(func(text: String, duration: float):
		if state == State.PLAYING:
			show_message(text, duration))
	player.hurt.connect(_on_player_hurt)
	player.leveled_up.connect(_on_leveled_up)
	player.ailments_changed.connect(_update_hud)
	player.regenerated.connect(_update_hud)
	player.defeated.connect(_on_player_defeated)
	player.bumped.connect(_on_player_bumped)
	player.trained.connect(_on_player_trained)
	if playtest_file != "":
		_start_playtest()
		return
	load_level(_start_level())
	_show_start_title("Escape!", Lang.t("Entkomme aus dem Verlies"))
	# The village gets ready behind the title, so the crypt door is quick later.
	WorldPreload.start(self)
	if Engine.has_meta(ASK_NAME_FLAG):
		# A language was just chosen: no extra click, the hero's name comes next.
		Engine.remove_meta(ASK_NAME_FLAG)
		new_game()


## Straight onto the map from the workshop, with a new hero called Tester.
func _start_playtest() -> void:
	hero_name = Lang.t("Tester")
	load_level(level_files.size() - 1)
	_title.visible = false
	_title_buttons.visible = false
	var back := _make_button(Lang.t("Zurück zur Werkstatt"), back_to_editor)
	back.custom_minimum_size = Vector2(260, 52)
	# Top middle, clear of the level name and life on the left and the
	# key, knives and gold on the right.
	back.set_anchors_preset(Control.PRESET_CENTER_TOP)
	back.grow_horizontal = Control.GROW_DIRECTION_BOTH
	back.offset_top = 24
	_hud.add_child(back)
	_start_playing()


## Leaves the test (or the title screen) for the map workshop.
func back_to_editor() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(EDITOR_SCENE)


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
	# The camera never comes nearer than a few metres to anything it shows,
	# so a near plane well off the lens leaves the depth buffer its precision
	# out at the houses and walls (with the default 0.05 faces a few
	# millimetres apart flickered through each other in the distance).
	camera.near = 0.5
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
		_moonlight()
		# Out in the open the weather is there at once, without a fade.
		_weather_look = Weather.look(weather)
		Weather.apply(_env, _moon, _weather_look)
	else:
		Weather.clear_air(_env)
		if player:
			player.set_night_dim(0.0)
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


## A label with outline and shadow (see UiKit.label).
static func _make_label(font: Font, size: int, color := Color.WHITE) -> Label:
	return UiKit.label(font, size, color)


## Every button of the game, in one look (see UiKit.button).
static func _make_button(text: String, action: Callable, on_press := false) -> Button:
	return UiKit.button(text, action, on_press)


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

	_drawer_handle = _make_button("", toggle_drawer, true)
	# 88 high: room for the arrow and "Menü", and for the home and torch
	# buttons below it between the gold line and the corner mark on a 720 px
	# screen (see _setup_torch_button).
	_drawer_handle.custom_minimum_size = Vector2(70, 88)
	_drawer_handle.add_theme_font_size_override("font_size", 16)
	_drawer_handle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = _drawer_handle.get_theme_stylebox(style).duplicate()
		box.corner_radius_top_right = 0
		box.corner_radius_bottom_right = 0
		_drawer_handle.add_theme_stylebox_override(style, box)
	_drawer_arrow = MenuArrow.new()
	_drawer_arrow.color = GOLD
	_drawer_handle.add_child(_drawer_arrow)
	_drawer_handle.resized.connect(_place_drawer_arrow)
	# The handle sits at the foot of a rail on the menu's edge; the quick
	# window icons stand above it, so all of it slides as one.
	_drawer_rail = VBoxContainer.new()
	_drawer_rail.add_theme_constant_override("separation", QUICK_GAP)
	_drawer_rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_drawer_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.add_child(_drawer_rail)
	_setup_quick_bar()
	var gap := Control.new()
	gap.custom_minimum_size.y = QUICK_HANDLE_GAP - QUICK_GAP * 2
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer_rail.add_child(gap)
	_drawer_rail.add_child(_drawer_handle)
	_setup_home_button()
	_setup_torch_button()

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
	# Map, compendium, inventory, character and quests have their own icons
	# on the menu's rail (QUICK_WINDOWS), so they are not repeated here.
	var windows := [["Laden", "laden"]]
	for w in windows:
		buttons.add_child(_make_button(Lang.t(w[0]), _open_from_drawer.bind(w[1]), true))
	# The game actions act the moment the pointer goes down (see _make_button).
	var do_jump := func(): if state == State.PLAYING: player.jump()
	var do_throw := func(): if state == State.PLAYING: player.throw_knife()
	var do_strike := func(): if state == State.PLAYING: player.melee()
	var do_crate := func(): if state == State.PLAYING and not menus.is_open(): crate_action()
	var do_stone := func(): if state == State.PLAYING and not menus.is_open(): stone_action()
	var do_quit := func():
		set_drawer_open(false)
		_on_quit_pressed()
	buttons.add_child(_make_button(Lang.t("Springen"), do_jump, true))
	buttons.add_child(_make_button(Lang.t("Werfen"), do_throw, true))
	buttons.add_child(_make_button(Lang.t("Schlagen"), do_strike, true))
	buttons.add_child(_make_button(Lang.t("Kiste"), do_crate, true))
	buttons.add_child(_make_button(Lang.t("Stein"), do_stone, true))
	buttons.add_child(_make_button(Lang.t("Angeln"), fish_action, true))
	buttons.add_child(_make_button(Lang.t("Schenken"), gift_action, true))
	_sound_button = _make_button("", _toggle_sound, true)
	buttons.add_child(_sound_button)
	_update_sound_button()
	_music_button = _make_button("", _toggle_music, true)
	buttons.add_child(_music_button)
	buttons.add_child(_make_button(Lang.t("Beenden"), do_quit, true))
	for b in buttons.get_children():
		b.custom_minimum_size = Vector2(150, 58)
		b.add_theme_font_size_override("font_size", 18)
	column.add_child(_make_music_slider())
	column.add_child(_make_effects_slider())
	_update_music_controls()
	_update_drawer_handle()
	_place_drawer(0.0)
	# Keeps the menu in place when a button's text changes its size.
	_drawer.minimum_size_changed.connect(func(): _place_drawer(_drawer_t))


## The windows opened most often, as small picture buttons on the right edge
## above the menu handle: window, German name, key and picture.
const QUICK_WINDOWS := [
	["karte", "Karte", "N", "kind:map"],
	["kompendium", "Kompendium", "H", "kind:book"],
	["inventar", "Inventar", "I", "kind:bag"],
	["charakter", "Charakter", "P", "kind:hero"],
	["auftraege", "Aufträge", "O", "kind:scroll"],
]
const QUICK_SIZE := Vector2(70, 48)
const QUICK_ICON := 30.0
## Between two icons, and between the last icon and the handle.
const QUICK_GAP := 8
## Between the handle and the groups above and below it: twice the gap
## inside a group, so the groups read apart (at least 2 * QUICK_GAP).
const QUICK_HANDLE_GAP := 16


## One icon per window in QUICK_WINDOWS, each with a tooltip that names the
## window and its key. The icon of the open window stays pressed; a click on
## it closes the window again, a click on another switches to that one.
func _setup_quick_bar() -> void:
	_drawer_rail.theme = _tooltip_theme()
	for w in QUICK_WINDOWS:
		var b := _make_button("", _toggle_window.bind(w[0]))
		b.toggle_mode = true
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.custom_minimum_size = QUICK_SIZE
		b.tooltip_text = Lang.t("%s (Taste %s)") % [Lang.t(w[1]), w[2]]
		for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var box: StyleBoxFlat = b.get_theme_stylebox(style).duplicate()
			box.corner_radius_top_right = 0
			box.corner_radius_bottom_right = 0
			b.add_theme_stylebox_override(style, box)
		var icon := ItemIcon.make(w[3], QUICK_ICON, true)
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.offset_left = -QUICK_ICON / 2.0
		icon.offset_top = -QUICK_ICON / 2.0
		icon.offset_right = QUICK_ICON / 2.0
		icon.offset_bottom = QUICK_ICON / 2.0
		b.add_child(icon)
		_drawer_rail.add_child(b)
		_quick_buttons[w[0]] = b


## The home button stands on the rail below the menu handle, set apart from
## it like the window icons above: a house, the same size as those icons.
## Its slot keeps its size while the button is hidden (no home yet, already
## home, no way home from here), so nothing on the rail ever moves. It stays
## pressed while the hero is on the way home; a second press stops.
func _setup_home_button() -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = QUICK_HANDLE_GAP - QUICK_GAP * 2
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer_rail.add_child(gap)
	var slot := Control.new()
	slot.custom_minimum_size = QUICK_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer_rail.add_child(slot)
	_home_button = _make_button("", home_action)
	_home_button.custom_minimum_size = QUICK_SIZE
	_home_button.toggle_mode = true
	_home_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_home_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home_button.tooltip_text = Lang.t("%s (Taste %s)") % [Lang.t("Nach Hause laufen"), "X"]
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = _home_button.get_theme_stylebox(style).duplicate()
		box.corner_radius_top_right = 0
		box.corner_radius_bottom_right = 0
		_home_button.add_theme_stylebox_override(style, box)
	var icon := ItemIcon.make("kind:house", QUICK_ICON, true)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -QUICK_ICON / 2.0
	icon.offset_top = -QUICK_ICON / 2.0
	icon.offset_right = QUICK_ICON / 2.0
	icon.offset_bottom = QUICK_ICON / 2.0
	_home_button.add_child(icon)
	_home_button.visible = false
	slot.add_child(_home_button)


## The torch button stands on the rail just below the home button, the same
## size: a torch, burning while the hand torch burns (the button stays
## pressed then), with the torches left in the bag in its corner. Like the
## home button its slot keeps its size while it is hidden (no torch at all),
## so nothing on the rail moves.
func _setup_torch_button() -> void:
	var slot := Control.new()
	slot.custom_minimum_size = QUICK_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer_rail.add_child(slot)
	_torch_button = _make_button("", torch_action)
	_torch_button.custom_minimum_size = QUICK_SIZE
	_torch_button.toggle_mode = true
	_torch_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_torch_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_torch_button.tooltip_text = Lang.t("%s (Taste %s)") % [Lang.t("Fackel anzünden oder löschen"), "V"]
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = _torch_button.get_theme_stylebox(style).duplicate()
		box.corner_radius_top_right = 0
		box.corner_radius_bottom_right = 0
		_torch_button.add_theme_stylebox_override(style, box)
	var icon := ItemIcon.make("kind:torch_out", QUICK_ICON, true)
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -QUICK_ICON / 2.0
	icon.offset_top = -QUICK_ICON / 2.0
	icon.offset_right = QUICK_ICON / 2.0
	icon.offset_bottom = QUICK_ICON / 2.0
	_torch_button.add_child(icon)
	# The count sits in a fixed box in the lower right corner, so a change
	# from 9 to 10 does not move it.
	_torch_count = _make_label(TEXT_FONT, 16)
	_torch_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_torch_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_torch_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_torch_count.offset_right = -6
	_torch_count.offset_bottom = -1
	_torch_button.add_child(_torch_count)
	_torch_button.visible = false
	slot.add_child(_torch_button)


## The torch button or V: lights a torch from the bag, or puts it out.
func torch_action() -> void:
	if state != State.PLAYING or player == null:
		return
	var why := player.torch.toggle()
	if why != "":
		show_message(why, 2.4)
	update_torch_button()


## Shows the torch button while the hero has a torch, pressed and burning
## while one burns, with the count of torches left in the bag.
func update_torch_button() -> void:
	if _torch_button == null or player == null:
		return
	var torch: HandTorch = player.torch
	var show := torch.lit or torch.has_torch()
	if _torch_button.visible != show:
		_torch_button.visible = show
	if _torch_button.button_pressed != torch.lit:
		_torch_button.set_pressed_no_signal(torch.lit)
	var icon: ItemIcon = _torch_button.get_node("Icon")
	var look := "kind:torch" if torch.lit else "kind:torch_out"
	if icon.what != look:
		icon.what = look
		icon.queue_redraw()
	var count := str(torch.spare()) if torch.spare() > 0 else ""
	if _torch_count.text != count:
		_torch_count.text = count


## The home button or X: sets out for home, or stops on the way.
func home_action() -> void:
	if state != State.PLAYING or not _shrine.is_empty():
		return
	var why := home_run.toggle()
	if why != "":
		show_message(why, 1.8)
	update_home_button()


## Shows the home button while a way home leads from here, pressed while the
## hero is on it.
func update_home_button() -> void:
	if _home_button == null:
		return
	var show := home_run.active or home_run.can_show()
	if _home_button.visible != show:
		_home_button.visible = show
	if _home_button.button_pressed != home_run.active:
		_home_button.set_pressed_no_signal(home_run.active)


## Tooltips in the house style: a dark panel with a golden border, gold text.
static func _tooltip_theme() -> Theme:
	var theme := Theme.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.03, 0.08, 0.95)
	box.border_color = Color(0.85, 0.66, 0.32, 0.8)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	theme.set_stylebox("panel", "TooltipPanel", box)
	theme.set_font("font", "TooltipLabel", TEXT_FONT)
	theme.set_font_size("font_size", "TooltipLabel", 16)
	theme.set_color("font_color", "TooltipLabel", GOLD)
	theme.set_color("font_outline_color", "TooltipLabel", Color.BLACK)
	theme.set_constant("outline_size", "TooltipLabel", 4)
	return theme


## A quick icon was clicked: closes its window if it is open, else opens it
## (closing any other window first).
func _toggle_window(menu: String) -> void:
	if state == State.PLAYING and _shrine.is_empty():
		if menus.current == menu:
			menus.close()
		else:
			if menus.is_open():
				menus.close()
			if player.can_act():
				set_drawer_open(false)
				menus.open(menu)
	_update_quick_bar()


## Keeps the icon of the open window pressed and all others raised.
func _update_quick_bar() -> void:
	if menus == null:
		return
	for menu in _quick_buttons:
		var b: Button = _quick_buttons[menu]
		var open: bool = menus.current == menu
		if b.button_pressed != open:
			b.set_pressed_no_signal(open)


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
	var hidden := size.x - _drawer_rail.get_combined_minimum_size().x
	_drawer.offset_left = -size.x + hidden * (1.0 - t)
	_drawer.offset_right = _drawer.offset_left + size.x
	_drawer.offset_top = -size.y / 2.0
	_drawer.offset_bottom = size.y / 2.0


func _update_drawer_handle() -> void:
	_drawer_handle.text = "\n" + Lang.t("Menü")
	_drawer_arrow.pointing_left = not _drawer_open


## Centres the arrow over the empty first line of the handle's text.
func _place_drawer_arrow() -> void:
	var font := _drawer_handle.get_theme_font("font")
	var line := font.get_height(_drawer_handle.get_theme_font_size("font_size"))
	var box := _drawer_arrow.custom_minimum_size
	_drawer_arrow.size = box
	_drawer_arrow.position = Vector2((_drawer_handle.size.x - box.x) / 2.0, (_drawer_handle.size.y - line) / 2.0 - box.y / 2.0)


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
	# Life as a slim bar under the hero's feet, its fill the share of life left,
	# MMO-style. It has one fixed size, so nothing moves as life changes.
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = HP_BAR_SIZE
	_hp_bar.size = HP_BAR_SIZE
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp_back := StyleBoxFlat.new()
	hp_back.bg_color = Color(0.06, 0.04, 0.08, 0.55)
	hp_back.border_color = Color(0.05, 0.02, 0.06, 0.6)
	hp_back.set_border_width_all(1)
	hp_back.set_corner_radius_all(3)
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.bg_color = hp_color(1.0)
	_hp_fill.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("background", hp_back)
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	_hp_bar.visible = false
	_hud.add_child(_hp_bar)
	# The hero's passing troubles (poison, a curse, burning, slowness) as
	# little red-framed icons in a row under the bar, where the eye is during
	# a fight, in a fixed order from its left edge, so an icon coming or
	# going never moves the others before it. Boons go to the status block
	# at the top left (_boon_row).
	_status_row = HBoxContainer.new()
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.add_theme_constant_override("separation", 4)
	_hud.add_child(_status_row)
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
	# The hero's level beside a bar of the experience towards the next one,
	# built like the run bar above it.
	var xp_row := HBoxContainer.new()
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_theme_constant_override("separation", 10)
	left.add_child(xp_row)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(170, 14)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = XP_COLOR
	xp_fill.set_corner_radius_all(6)
	_xp_bar.add_theme_stylebox_override("background", back.duplicate())
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_row.add_child(_xp_bar)
	_xp_label = _make_label(TEXT_FONT, 18, XP_COLOR)
	xp_row.add_child(_xp_label)
	# Things waiting for the hero (gear to mend, an upgrade to build) as little gold-framed icons under the hero level. The row
	# always keeps one icon's height, so the status block never grows.
	_notice_row = HBoxContainer.new()
	_notice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_row.add_theme_constant_override("separation", 4)
	_notice_row.custom_minimum_size = Vector2(0, StatusIcon.SIZE)
	left.add_child(_notice_row)
	# The hero's boons (stronger blows, speed, hardening) as green-framed
	# icons in a row of their own under the notices, the last line of the
	# status block, just above the event log. It also keeps one icon's height
	# when empty, and fills from its left edge in a fixed order.
	_boon_row = HBoxContainer.new()
	_boon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boon_row.add_theme_constant_override("separation", 4)
	_boon_row.custom_minimum_size = Vector2(0, StatusIcon.SIZE)
	left.add_child(_boon_row)
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
	_prompt = _make_label(TEXT_FONT, 20, Color(1, 1, 1, 0.9))
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

	# The message lines: the newest one always sits at the same place at the
	# bottom, and the ones before it, while still unread, above it. The box
	# grows upwards, so no line can ever cover another.
	_message_box = VBoxContainer.new()
	_message_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# The column stays clear of the event log and the first-steps card at the
	# left, and keeps centred.
	_message_box.offset_left = MESSAGE_MARGIN
	_message_box.offset_right = -MESSAGE_MARGIN
	_message_box.offset_top = -MESSAGE_BOTTOM
	_message_box.offset_bottom = -MESSAGE_BOTTOM
	_message_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_box.add_theme_constant_override("separation", MESSAGE_GAP)
	_hud.add_child(_message_box)
	_message = _message_line()
	_message_box.add_child(_message)

	# The keys at the bottom left help while the first steps are learned;
	# after that they go, to keep the screen clear (all keys are in the
	# compendium, H).
	var help := _make_label(TEXT_FONT, 15, Color(1, 1, 1, 0.8))
	_help = help
	help.text = Lang.t("WASD: laufen   Leertaste: springen   F: Schlag   R: Messer   V: Fackel   M: Ton\nI: Inventar   H: Kompendium   P: Charakter   L: Laden   C/Doppelklick: schleichen   Dagegenlaufen: benutzen   Tab: Menü\nMaus: Klick gehen, halten rennen (Umschalt), Rechtsklick: Messer (im Lauf: Sprung)")
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_left = 24
	help.offset_bottom = -26
	_hud.add_child(help)

	_hud.add_child(event_log)

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
	for entry in [[Lang.t("Spielstand laden"), open_load_window], [Lang.t("Neues Spiel"), new_game], [Lang.t("Karten-Werkstatt"), back_to_editor]]:
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
	var gifts := [Lang.t("+4 Leben"), Lang.t("+1 Kampfkraft"), Lang.t("+3% Tempo")]
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
		if not busy and not quests.talk(s.npc) and not crafting.talk(s.npc) and not wishes.talk(s.npc) and not reputation.tell_secret(s.npc) and not reputation.gossip(s.npc):
			s.npc.talk(player)
	elif s.kind == "eingang":
		go_inside(s.building, s.get("house", 0))
	elif s.kind == "schacht":
		_go_down_shaft(s)
	elif s.kind == "figur":
		# A person made in the map workshop (see DungeonNpc).
		player.face(s.pos - player.global_position)
		player.play("Idle")
		bumped_person = true
		s.figure.talk(player)
	elif s.kind == "tafel":
		player.face(s.pos - player.global_position)
		player.play("Idle")
		Events.bus().writing_found.emit(s.text)
		_refresh_seals()
	elif s.kind == Mines.CLUSTER:
		_mine_crystals(s)
	elif s.has("npc"):
		# A villager who trades: a word, then the goods. A task handed out or
		# finished comes first; the goods wait until the next time. While the
		# last line still shows, the goods open without a new word.
		if not busy and (quests.talk(s.npc, true) or reputation.tell_secret(s.npc)):
			player.face(s.pos - player.global_position)
			player.play("Idle")
			return
		if not busy and not reputation.gossip(s.npc):
			s.npc.talk(player)
		player.face(s.pos - player.global_position)
		trader_role = s.npc.role
		menus.open(s.kind)
	elif s.kind == "schrein":
		_open_shrine(s)
	elif s.kind == "brunnen":
		_drink(s)
	elif s.kind == Seats.KIND:
		player.sit_down(Seats.sit_spot(s), Seats.front(s), Seats.stand_spot(s, level, player.radius))
	else:
		player.face(s.pos - player.global_position)
		menus.bench = s.get("craft", "")
		menus.open(s.kind)


## How long the hero knocks at a crystal cluster before the crystals come off:
## two blows of the strike.
const DIG_BLOW := 0.42


## Running into a crystal cluster in a mine: two blows, then its crystals go
## into the pouch and it dims until the next morning (see Mines). The first
## crystals teach the recipes of the gem cutter's wheel.
func _mine_crystals(s: Dictionary) -> void:
	player.face(s.pos - player.global_position)
	if s.spent:
		player.play("Idle")
		show_message(Lang.t("Hier ist nichts mehr zu holen. Bis zum nächsten Morgen wachsen die Kristalle nach."), 2.4)
		return
	if s.get("digging", false):
		return
	s.digging = true
	player.path.clear()
	for blow in 2:
		player.play_once(Player.STRIKE_ANIM, DIG_BLOW * (2 - blow))
		Sfx.play(self, "word_klack", -4.0, s.pos, 1.3 + blow * 0.15)
		await get_tree().create_timer(DIG_BLOW).timeout
	s.digging = false
	if level == null or not level.stations.has(s):
		return
	var count := Mines.mine(level, s, day)
	if count <= 0:
		return
	Sfx.play(self, "word_zing", -4.0, s.pos, 1.2)
	var first := crafting.have(Mines.CRYSTAL_ID) == 0 and not crafting.found.has(Mines.CRYSTAL_ID)
	crafting.add(Mines.CRYSTAL_ID, count)
	Effects.float_text(level, s.pos + Vector3(0, 2.0, 0), "+%d %s" % [count, Crafting.ingredient_name(Mines.CRYSTAL_ID)], Mines.CRYSTAL, true)
	Events.found(Lang.t("%d Grottenkristalle kommen in deinen Zutatenbeutel.") % count, Mines.CRYSTAL)
	learn(Mines.CRYSTAL_LEARN)
	var learned := crafting.learn_from_find(Mines.CRYSTAL_ID)
	if first or not learned.is_empty():
		var names := learned.map(func(id): return Lang.t(Crafting.RECIPES[id].name))
		var text := Lang.t("Grottenkristalle! Schleife sie am Schleifrad im Dorf zu Schmuck.")
		if not names.is_empty():
			text += "\n" + Lang.t("Neue Rezepte: %s") % ", ".join(names)
		show_message(text, 4.0)


# --- Companions -----------------------------------------------------------------

## Whether the hero has a companion of this kind (at their side or at home).
func owns_companion(kind: String) -> bool:
	return companions.any(func(c): return c.kind == kind)


## The companion at the hero's side, or {}.
func companion() -> Dictionary:
	return companions[following] if following >= 0 and following < companions.size() else {}


## The perk of the companion at the hero's side goes into the hero's stats
## (see Companions); one at home gives nothing.
func apply_companion_perk() -> void:
	var c := companion()
	player.companion_perks = Companions.SPECIES[c.kind] if not c.is_empty() else {}
	player.refresh_stats()
	_update_hud()


## The hero's companion comes along to the new level (see Pet); in the
## hero's house the others wait in their corner.
func _spawn_pet(at := Vector3.INF) -> void:
	if is_instance_valid(pet):
		pet.queue_free()
	pet = null
	var c := companion()
	if not c.is_empty():
		pet = Pet.new()
		pet.setup(level, c.kind, c.name)
		level.add_child(pet)
		if at != Vector3.INF:
			pet.global_position = at
			pet._placed = true
		pet.dug_up.connect(_on_fox_dug_up)
	_spawn_home_pets()


## In the hero's house: the companions who stay at home rest on the straw
## in the corner by the door (see Level.companion_spots).
func _spawn_home_pets() -> void:
	for p in home_pets:
		if is_instance_valid(p):
			p.queue_free()
	home_pets.clear()
	if not level.is_home:
		return
	var spots: Array = level.companion_spots
	var k := 0
	for i in companions.size():
		if i == following or k >= spots.size():
			continue
		var p := Pet.new()
		p.setup(level, companions[i].kind, companions[i].name)
		level.add_child(p)
		p.rest_at(spots[k].pos, spots[k].rot)
		home_pets.append(p)
		k += 1


## Takes companion `index` along (or none with -1): the one at the hero's
## side so far stays at home. Only in the hero's house (see the companions
## window).
func take_companion(index: int) -> void:
	if index == following or index >= companions.size():
		return
	var from := Vector3.INF
	var i := 0
	for c in companions.size():
		if c == following:
			continue
		if c == index and i < home_pets.size() and is_instance_valid(home_pets[i]):
			from = home_pets[i].global_position
		i += 1
	following = index
	_spawn_pet(from)
	apply_companion_perk()


## Gives companion `index` a new name.
func rename_companion(index: int, text: String) -> void:
	if index < 0 or index >= companions.size():
		return
	companions[index].name = Companions.clean_name(text, companions[index].kind)
	for p in home_pets + [pet]:
		if is_instance_valid(p) and p.kind == companions[index].kind:
			p.given_name = companions[index].name


## A wild animal ate its food from the hero's hand. After the last gift it
## trusts the hero, comes along from now on and is given a name; the
## companion at the hero's side so far goes home to the hero's house.
func _on_animal_fed(animal: Animal) -> void:
	var kind := animal.kind
	var food := animal.food()
	if food == "" or owns_companion(kind) or not player.bag.has(food):
		return
	var species: Dictionary = Companions.SPECIES[kind]
	player.bag.erase(food)
	trust[kind] = int(trust.get(kind, 0)) + 1
	if kind == "fuchs":
		learn(FOX_LEARN)
	learn(Companions.LEARN)
	Sfx.play(self, "drink", -4.0)
	Effects.float_text(level, animal.global_position + Vector3(0, 1.8 if kind == "fuchs" else 2.6, 0), Lang.t("Mampf!"), Color(1.0, 0.7, 0.4), true)
	if trust[kind] < Companions.TRUST_NEEDED:
		show_message(Lang.t(species.fed) % [trust[kind], Companions.TRUST_NEEDED], 3.5)
		_update_hud()
		return
	var before := companion()
	companions.append(Companions.make(kind, species.default))
	following = companions.size() - 1
	if level is Outdoor:
		level.owned_companions.append(kind)
		level.taken[animal.tame_key()] = true
		level.animals.erase(animal)
	var spot := animal.global_position
	var turn := animal.rotation.y
	animal.queue_free()
	_spawn_pet(spot)
	pet.rotation.y = turn
	if kind == "fuchs":
		level.place_fox_baskets()
	apply_companion_perk()
	var hearts := Effects.make_sparkles(Color(1.0, 0.55, 0.6), true)
	hearts.position = spot + Vector3(0, 1.0, 0)
	level.add_child(hearts)
	var text := Lang.t(species.tamed)
	if not before.is_empty():
		text += "\n" + Lang.t("%s läuft nach Hause und wartet dort auf dich.") % before.name
	# A friend needs a name; what it brings is told once it has one.
	menus.naming = following
	menus.naming_message = text
	menus.open("gefaehrte_name")


## The fox dug up a hidden ingredient: it lies there for the hero to take.
func _on_fox_dug_up(id: String, pos: Vector3) -> void:
	level.lay_find(id, pos)
	Effects.float_text(level, pos + Vector3(0, 2.0, 0), Crafting.ingredient_name(id), Color(0.75, 0.9, 1.0), true)
	var fox_name: String = pet.given_name if is_instance_valid(pet) and pet.given_name != "" else Lang.t("Dein Fuchs")
	Events.found(Lang.t("%s hat etwas ausgegraben: %s!") % [fox_name, Rarity.marked(id)])


## A dug-up ingredient goes into the ingredient pouch, not the bag.
func _on_ingredient_collected(id: String) -> void:
	crafting.add(id)
	Sfx.play(self, "key", -3.0)
	Effects.float_text(level, player.global_position + Vector3(0, 3.0, 0), Crafting.ingredient_name(id), Color(0.7, 0.95, 0.5), true)
	Events.found(Lang.t("%s kommt in deinen Zutatenbeutel. Du findest ihn im Inventar (I) als eigenen Reiter.") % Rarity.marked(id), Color(0.7, 0.95, 0.5))


## The fountain: full life and every ailment gone, as often as you like.
func _drink(s: Dictionary) -> void:
	player.face(s.pos - player.global_position)
	var healed := player.hp < player.max_hp
	player.hp = player.max_hp
	var cured := player.cure()
	player.play_flourish("PickUp", 0.6)
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
	player.play_flourish("PickUp", 0.6)
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
	if player.bag_used() >= player.bag_size():
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
	if player.bag_used() >= player.bag_size():
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
	if not level.heavy_in_range(stone, stone.cell + dir, stone.along_x):
		return Lang.t("Weiter als 5 Felder von seinem Platz rückt der Block nicht.")
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
	if stone.heavy:
		_drag_ring = _range_ring(stone.home, Level.HEAVY_RANGE)
		level.add_child(_drag_ring)
	return true


## A thin, pale ring lying on the floor around `middle`.
func _range_ring(middle: Vector3, radius: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.07
	torus.outer_radius = radius + 0.07
	torus.rings = 96
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.3, 1.0)
	ring.position = Vector3(middle.x, 0.04, middle.z)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.92, 0.65, 0.55)
	ring.material_override = mat
	return ring


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
	elif spot.get("edge", false):
		show_message(Lang.t("Weiter als 5 Felder von seinem Platz rückt der Block nicht."), 1.6)
	elif not spot.is_empty() and not (spot.cell == stone.cell and spot.along_x == stone.along_x and spot.layer == stone.layer):
		show_message(Lang.t("Dort ist kein Platz für den Steinblock.") if level._flat_distance(StoneBlock.spot_of(spot.cell, spot.along_x, 0), player.global_position) <= Level.STONE_DRAG_RANGE else Lang.t("So weit reicht dein Wurf nicht."), 1.4)


func _end_drag() -> void:
	_drag_stone = null
	_drag_spot = {}
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null
	if _drag_ring != null and is_instance_valid(_drag_ring):
		_drag_ring.queue_free()
	_drag_ring = null


## The "Crate" button: picks up a crate in reach, else sets one down.
func crate_action() -> void:
	var why := ""
	if level.crate_in_reach(player) != null and player.bag_used() < player.bag_size():
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
			player.gift_hp += Player.SHRINE_LIFE
			player.hp += Player.SHRINE_LIFE
			text = Lang.t("Du fühlst dich zäher: +4 Leben")
		1:
			player.gift_power += Player.SHRINE_POWER
			text = Lang.t("Deine Hiebe werden härter: +1 Kampfkraft")
		2:
			player.gift_speed += Player.SHRINE_SPEED
			text = Lang.t("Deine Schritte werden leichter: +3% Tempo")
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
	player.play_flourish("PickUp", 0.6)
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
	_hp_bar.max_value = maxi(1, player.max_hp)
	_hp_bar.value = clampi(player.hp, 0, player.max_hp)
	# Green when whole, through yellow and red to deep red as life is lost
	# (poison shows as its icon under the bar).
	_hp_fill.bg_color = hp_color(float(player.hp) / maxf(1.0, player.max_hp))
	_update_status_icons()
	_show_hero_level()
	_coin_label.text = Lang.t("Gold: %d") % coins
	_knife_label.text = Lang.t("Messer: %d") % player.knives
	_key_label.text = Lang.t("Schlüssel gefunden") if level.has_key else Lang.t("Kein Schlüssel")
	_key_label.visible = not level.outdoor and level.building == ""
	_key_label.add_theme_color_override("font_color", GOLD if level.has_key else Color(1, 1, 1, 0.45))


## The hero's level and the experience towards the next one on the HUD.
## A free level point is told there too, until it is spent.
func _show_hero_level() -> void:
	var step := HeroLevel.progress(player.hero_xp)
	_xp_bar.max_value = maxi(1, step.y)
	_xp_bar.value = step.x if step.y > 0 else 1
	_xp_label.text = Lang.t("Heldenstufe %d") % player.hero_level()
	if player.free_points() > 0:
		_xp_label.text += "   " + Lang.t("Punkt frei (P)")


## The time of day for the HUD, e.g. "21:30, night, full moon", above
## ground only.
func _clock_text() -> String:
	if level == null or not (level.outdoor or level.building != ""):
		return ""
	var text := "%s, %s" % [DayNight.clock_text(day_hour), Lang.t(DayNight.part_of_day(day_hour))]
	if weather != Weather.CLEAR:
		text += ", " + Lang.t(Weather.word(weather))
	# At night the clock names tonight's moon (see Moon).
	if DayNight.is_night(day_hour):
		text += ", " + Lang.t(Moon.word(day))
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
		_moonlight()
		_weather_look = Weather.blend(_weather_look, Weather.look(weather), 1.0 - exp(-delta / Weather.FADE))
		_flash = maxf(0.0, _flash - delta * 3.0)
		# A stroke of lightning flickers: bright, a dip, bright again.
		var flicker := _flash * (0.45 if _flash > 0.55 and _flash < 0.75 else 1.0)
		Weather.apply(_env, _moon, _weather_look, flicker)
		if level is Outdoor:
			level.day = day
			level.set_hour(day_hour)
			level.set_weather(weather)
			if level.moon_night >= 0 and (Moon.is_full(level.moon_night) or Moon.is_new(level.moon_night)):
				learn(Moon.LORE)
	if _clock_text() != _clock_shown:
		_update_hud()


## The night is as bright as tonight's moon, the only light out there:
## silver and clear at full moon, nearly black at new moon (see Moon). Only
## the moon's share of the light changes (see DayNight.moon_at), so the day,
## dusk and dawn look the same whatever the moon.
func _moonlight() -> void:
	var bright := _night_light()
	# The hero's lantern shrinks to a small pool as the night darkens.
	if player:
		player.set_night_dim(1.0 - bright)
	if bright >= 1.0:
		return
	_moon.light_energy *= bright
	_env.ambient_light_energy *= bright
	var bg := _env.background_color
	_env.background_color = Color(bg.r * bright, bg.g * bright, bg.b * bright)


## How bright the open air is against the full moon's night: 1 by day and
## on full-moon nights, down to Moon.DARKEST on a new-moon night.
func _night_light() -> float:
	return lerpf(1.0, Moon.light(day), DayNight.moon_at(day_hour))


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
	if level != null:
		# Mined crystal clusters grow back with the morning.
		Mines.refresh_crystals(level, day, true)
	_dragon_morning(quiet)
	var expired := bounties.refresh(day)
	if quiet or not escaped:
		return
	var text := Lang.t("Ein neuer Morgen: frische Kopfgelder am Aushang.")
	if expired > 0:
		text += "\n" + Lang.t("Nicht erledigte Jagden vom Vortag sind verfallen: %d") % expired
	quest_news(text, Color(1.0, 0.82, 0.4), 4.0)


# --- The dragon's helpers ------------------------------------------------------

## A helper carried something off the open ground before the hero's eyes
## (see DragonHelpers): into the hoard. The first of a night gets a line in
## the event log, and the compendium learns of them.
func _on_loot_carried_off(kind: String, id: String) -> void:
	var first := int(hoard.tonight.things) == 0
	hoard.gather(kind, id)
	if first:
		Events.found(Lang.t("Kleine Drachlinge schwärmen aus dem Berg und tragen fort, was am Boden liegt."), DragonHoard.COLOR)
		learn(DragonHoard.LORE)


## The morning after a night: what still lay about in the open air, where
## the hero did not watch the helpers at work (in a building, below ground,
## asleep), they took unseen. Then the event log tells what the night brought.
func _dragon_morning(asleep := false) -> void:
	var outdoor := _outdoor_index()
	if outdoor >= 0:
		var key := level_files[outdoor].get_file()
		var watched: bool = not asleep and level is Outdoor and level.file == key
		if floors.has(key) and not watched:
			if level is Outdoor and level.file == key:
				# Asleep in the open: the things vanish from the ground too.
				for p in level.floor_pickups():
					var node: Node3D = level.take_from_floor(p)
					if node:
						node.queue_free()
					hoard.gather(str(p.floor[0]), str(p.floor[1]))
			hoard.sweep(floors[key])
	var to_elder := int(hoard.tonight.get("elder", 0)) > 0
	var text := hoard.morning_report()
	if text != "":
		Events.found(text, DragonHoard.COLOR)
		learn(DragonHoard.LORE)
	if to_elder:
		learn(DragonHoard.ELDER_LORE)


## The hero took the dragon's hoard in its lair: the coins into the purse,
## the bars into the hero's stores (see Forge.store): iron for the smith's
## forge, moon silver into the pouch, the fine bars for Gorm to buy.
func _on_hoard_taken() -> void:
	var had := hoard.take_all()
	var amount := int(had.get("coins", 0))
	had.erase("coins")
	var text := Forge.metals_text(had)
	if text != "":
		Events.found(Lang.t("Der Hort des Drachen: %s") % text, GOLD)
		Forge.store(self, had)
		Sfx.play_gear(level, "schwert", 0.0, player.global_position)
	if amount > 0:
		coins += amount
		Events.found(Lang.t("+%d Gold") % amount, GOLD)
		Sfx.play_coins(self, amount)
	_update_hud()


## The hero took the Great Old One's hoard (see ElderLair): the old dragon's
## own treasure the first time, and whatever the dragon helpers brought since.
## The coins go into the purse, the gear into the bag; what does not fit is
## left lying at the hero's feet.
func _on_elder_hoard_taken() -> void:
	var amount := 0
	var items: Array = []
	if not level.taken.has(ElderLair.ANCIENT_KEY):
		level.taken[ElderLair.ANCIENT_KEY] = true
		var ancient := ElderLair.ancient_loot(level)
		amount += int(ancient.coins)
		items += ancient.items
	var share := hoard.take_elder()
	amount += int(share.coins)
	items += share.items
	var left := 0
	for i in items.size():
		var id := str(items[i])
		if player.bag_fits(id):
			player.bag.append(id)
		else:
			left += 1
			var angle := TAU * i / maxf(1.0, items.size())
			level._drop_item(id, player.global_position + Vector3(cos(angle), 0, sin(angle)) * 1.8)
	if not items.is_empty():
		Events.found(Lang.t("Der Hort des Großen Alten: %s") % ", ".join(items.map(func(id): return Rarity.marked(str(id)))), ElderLair.GOLD)
		Sfx.play_rarity(level, Sfx.finest(items), 0.2, player.global_position)
	if amount > 0:
		coins += _gold(amount)
		Events.found(Lang.t("+%d Gold") % _gold(amount), GOLD)
		Sfx.play_coins(self, _gold(amount))
	show_message(Lang.t("Gold klirrt! Der Große Alte regt sich im Schlaf. Leise fort von hier!") if left == 0 \
			else Lang.t("Gold klirrt! Deine Tasche ist voll, der Rest liegt am Boden. Leise!"), 3.5, ElderLair.GOLD)
	_update_hud()


## The Great Old One woke up: there is no fighting it, only running.
func _on_elder_awakened() -> void:
	_shake = 1.6
	show_message(Lang.t("Der Große Alte erwacht! Flieh aus seinem Blick, bis er wieder einschläft!"), 4.5, Color(1.0, 0.45, 0.25))


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
	weather_hours = hours if hours > 0.0 else Weather.spell(_weather_rng, weather)


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
	Weather.show_particles(_rain, _mist, _weather_look, 1.0 - DayNight.glow_at(day_hour) + DayNight.moon_at(day_hour) * Moon.light(day) * 0.3)
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
	tutorial.restart()
	writing_card.hide_now()
	level = Outdoor.new() if Level.is_outdoor_file(level_files[index]) else Level.new()
	level.load_from_file(level_files[index])
	level.depth = index
	if playtest_file != "" and level_files[index] == playtest_file:
		level.playtest = true
		level.depth = 0
	var file := level_files[index].get_file()
	if not looted.has(file):
		looted[file] = {}
	level.taken = looted[file]
	if not builds.has(file):
		builds[file] = []
	level.built = builds[file]
	level.hero = hero_name
	level.house_number = inside_house if level.is_home else 0
	var floor_key := file if level.house_number == 0 else "%s#%d" % [file, level.house_number]
	if not floors.has(floor_key):
		floors[floor_key] = []
	level.floor_items = floors[floor_key]
	if level.lair:
		level.hoard = hoard.contents()
		level.elder_hoard = hoard.elder_contents()
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
	# The fog of war remembers what the hero saw here before (see Journal).
	journal.restore_fog(level)
	level.player = player
	player.level = level
	player.frozen = false
	player.controllable = true
	# Arriving on a level never heals by itself; climbing the stairs gives
	# STAIRS_HEAL (see _next_level) and the fountain heals fully.
	player.revive(level.cell_to_world(level.start_cell), false)
	player.face(Vector3.BACK)
	level.restore_taken()
	Mines.refresh_crystals(level, day)
	level.restore_floor()
	level.restore_stones()
	level.key_collected.connect(_on_key_collected)
	level.coins_collected.connect(_on_coins_collected)
	level.item_collected.connect(_on_item_collected)
	level.secret_found.connect(_on_secret_found)
	level.ingredient_collected.connect(_on_ingredient_collected)
	level.hide_ingredients()
	_spawn_pet()
	if has_fox:
		level.place_fox_baskets()
	apply_companion_perk()
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
	level.lair_won.connect(_on_lair_won)
	level.dragon_awakened.connect(_on_dragon_awakened)
	level.lair_exit_taken.connect(leave_lair)
	level.hoard_taken.connect(_on_hoard_taken)
	level.hoard_guarded.connect(func(): show_message(Lang.t("Glutschlund wacht über seinen Hort. Besiege den Drachen, dann gehört der Hort dir."), 3.0))
	level.elder_hoard_taken.connect(_on_elder_hoard_taken)
	level.elder_awakened.connect(_on_elder_awakened)
	level.elder_settled.connect(func(): show_message(Lang.t("Der Große Alte schläft wieder ein. Jetzt leise!"), 3.0))
	if ElderLair.is_floor(level):
		learn(ElderLair.LORE)
	if is_instance_valid(level.elder):
		var here := level
		get_tree().create_timer(4.8).timeout.connect(func():
			if level == here and state == State.PLAYING and is_instance_valid(here.elder) and here.elder.asleep:
				show_message(Lang.t("Der Große Alte schläft auf seinem Hort. Schleiche (Taste C), sonst wacht er auf!"), 4.5))
	level.stairs_taken.connect(_take_stairs)
	if level.traps:
		level.traps.teleported.connect(_on_trap_teleport)
		level.traps.fell.connect(_fall_through_trapdoor)
	level.boss_won.connect(_on_mine_boss_won)
	_refresh_seals()
	if horrors:
		horrors.watch(level)
	if level is Outdoor:
		level.notice.connect(func(text: String, duration: float): show_message(text, duration))
		level.home_claimed.connect(_on_home_claimed)
		level.food_basket.connect(_eat_from_basket)
		level.owned_companions = companions.map(func(c): return c.kind)
		level.animal_fed.connect(_on_animal_fed)
		level.lightning.connect(_on_lightning)
	if level.is_home:
		level.show_home_upgrades(home_upgrades, trophies)
	_pending_crate = null
	_end_drag()
	_set_atmosphere(level.outdoor)
	var mood := Mines.mood(level.theme)
	if not mood.is_empty():
		# A mine has a light of its own (see Mines.MOODS).
		_env.ambient_light_color = mood.ambient
		_env.ambient_light_energy = mood.energy
		_moon.light_color = mood.light
	if level is Outdoor:
		level.day = day
		level.set_hour(day_hour)
		level.set_weather(weather)
	_pending_search = {}
	_pending_station = {}
	if level.safe and restock:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		shop_stock.clear()
		# Always at least one weapon, shield, body armour and ring, then
		# the usual random wares on top: only plain gear (Items.merchant_sells).
		for slot in ["waffe", "schild", "ruestung", "ring"]:
			shop_stock.append(Items.random_ware(rng, slot))
		for i in 4:
			shop_stock.append(Items.random_ware(rng))
	_snap_camera()
	_update_hud()
	# Every shader the new level needs is built in its first, still dark
	# frame, and the time that takes does not count (see LevelWarmup).
	LevelWarmup.begin(level)


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
	_title_prompt.visible = true
	_title_sub.visible = true
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
	# The empty prompt line and the subtitle give their room to the name box
	# and its save slots, and the headline steps back a little.
	_title_prompt.visible = false
	_title_sub.visible = false
	_title_text.add_theme_font_size_override("font_size", 90)
	_name_box.visible = true
	_choose_sex(player.sex)
	_name_edit.text = hero_name
	_name_edit.grab_focus()
	_name_edit.select_all()
	_choose_slot(_free_slot())


## Picks the body of the new hero: the chosen button stays bright, and the
## question asks for a hero's or a heroine's name.
func _choose_sex(id: String) -> void:
	_new_sex = BodyLook.checked(id)
	for sex in _sex_buttons:
		_sex_buttons[sex].modulate = Color.WHITE if sex == _new_sex else Color(1, 1, 1, 0.5)
	_name_ask.text = Lang.t("Wie heißt deine Heldin?" if _new_sex == "female" else "Wie heißt dein Held?")


## The slot a new game takes unless the player picks another: the first free
## one, or else the one whose hero has come the least far.
func _free_slot() -> int:
	var weakest := 1
	for slot in range(1, SAVE_SLOTS + 1):
		var info := save_info(save_path(slot))
		if info.is_empty():
			return slot
		if is_stronger(save_info(save_path(weakest)), info):
			weakest = slot
	return weakest


## Picks the slot of the new game: its button stays bright, like the chosen
## body, and the line below says what is in it now.
func _choose_slot(slot: int) -> void:
	_new_slot = slot
	for s in _slot_buttons:
		var b: Button = _slot_buttons[s]
		var info := save_info(save_path(s))
		b.text = "%d · %s" % [s, info.name if not info.is_empty() else Lang.t("frei")]
		b.modulate = Color.WHITE if s == slot else Color(1, 1, 1, 0.5)
	var info := save_info(save_path(slot))
	if info.is_empty():
		_name_note.text = Lang.t("Platz %d ist frei.") % slot
		_name_note.add_theme_color_override("font_color", Menus.BLUE)
	else:
		_name_note.text = Lang.t("Platz %d: %s Das neue Spiel ersetzt diesen Spielstand.") % [slot, save_summary(info)]
		_name_note.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))


func _setup_name_box() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
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
	box.add_child(_name_edit)
	# The slot the game is saved into: one button per slot, with the name of
	# the hero in it or "free", after a caption in the same row.
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 10)
	box.add_child(slots)
	var slot_ask := _make_label(TEXT_FONT, 20, GOLD)
	slot_ask.text = Lang.t("Speichern auf Platz:")
	slots.add_child(slot_ask)
	for slot in range(1, SAVE_SLOTS + 1):
		var b := _make_button("%d" % slot, _choose_slot.bind(slot))
		b.custom_minimum_size = Vector2(156, 48)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		slots.add_child(b)
		_slot_buttons[slot] = b
	# The note's line is kept from the start, one line of fixed width, so
	# choosing another slot never moves the button below.
	_name_note = _make_label(TEXT_FONT, 18, Color(1.0, 0.75, 0.5))
	_name_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name_note.clip_text = true
	_name_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_note.custom_minimum_size = Vector2(SLOT_NOTE_WIDTH, 28)
	_name_note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_name_note)
	var go := _make_button(Lang.t("Los geht's"), _start_new_game)
	go.custom_minimum_size = Vector2(240, 64)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(go)


## "Los geht's": a slot holding a hero who has come further than a new one
## asks first (the "ueberschreiben" window); any other slot starts at once.
func _start_new_game() -> void:
	if not _name_box.visible or menus.is_open():
		return
	if is_stronger(save_info(save_path(_new_slot)), fresh_info()):
		_name_edit.release_focus()
		_title.visible = false
		menus.open("ueberschreiben")
		return
	begin_new_game()


## What a new game would look like in the load window, to compare it with
## the saved game it replaces.
func fresh_info() -> Dictionary:
	return {"level": _start_level() + 1, "coins": 0, "escaped": false, "home": false}


## The chosen slot was confirmed: its old saved game is gone, and the new
## hero sets out.
func begin_new_game() -> void:
	if not _name_box.visible:
		return
	hero_name = _name_edit.text.strip_edges()
	if hero_name == "":
		hero_name = Lang.t("Namenlos")
	save_slot = _new_slot
	delete_save(save_path(save_slot))
	_name_box.visible = false
	_name_edit.release_focus()
	coins = 0
	iron = 0
	bars = {}
	companions = []
	following = -1
	trust = {}
	escaped = false
	home_given = false
	home_claimed = false
	home_upgrades.clear()
	trophies.clear()
	secrets_found = 0
	dry_levels = 0
	bumped_person = false
	hints_shown.clear()
	_hints_last.clear()
	looted.clear()
	builds.clear()
	floors.clear()
	met.clear()
	quests.clear()
	journal.clear()
	day = 0
	bounties.clear()
	bounties.refresh(day)
	crafting.clear()
	wishes.clear()
	Factions.clear()
	fishing.stop()
	reputation.clear()
	village_talk.clear()
	storage.clear()
	shop_stock.clear()
	wanderer_stock.clear()
	wanderer_night = -1
	hoard.clear()
	away_plan = Offline.empty_plan()
	day_hour = DayNight.START_HOUR
	set_weather(Weather.CLEAR, Weather.FIRST_HOURS)
	player.knives = 5
	player.set_sex(_new_sex)
	player.set_hair(HairLook.DEFAULT)
	player.reset_gifts()
	# The hero keeps what they trained in earlier runs under this name.
	player.xp = Training.load_hero(hero_name)
	player.set_level_data(Training.load_level(hero_name))
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
	save_slot = slot_of(path)
	_leave_title(func():
		_apply_save(data)
		_after_load(data))
	# Closed only now, while leaving, so the title does not come back.
	menus.close()


## The saved game a click on the title continues: after a fall the fallen
## hero's own, otherwise the one saved last.
func _save_to_continue() -> String:
	if state == State.OVER:
		return save_path() if has_slot_save() else ""
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
	if _name_box.visible:
		# The overwrite question went back: the name box is still there.
		_title.visible = true
		_name_edit.grab_focus()
		return
	_show_start_title(_title_text.text, _title_sub.text)


## Loads a saved game, the one at path, in the middle of a run (from the
## "Laden" window). Any hero's saved game can be loaded, not only this one's.
func load_saved_game(path: String) -> void:
	if state != State.PLAYING or not FileAccess.file_exists(path):
		return
	var data := _read_save(path)
	save_slot = slot_of(path)
	state = State.TRANSITION
	player.frozen = true
	var tween := create_tween()
	_fade.color = Color(0, 0, 0, 0)
	tween.tween_property(_fade, "color:a", 1.0, 0.5)
	tween.tween_callback(func():
		player.frozen = false
		_apply_save(data)
		_after_load(data)
		_start_playing())


func _toggle_sound() -> void:
	Sfx.toggle_mute()
	_update_sound_button()


func _update_sound_button() -> void:
	if _sound_button:
		_sound_button.text = Lang.t("Ton: aus") if Sfx.muted else Lang.t("Ton: an")
	if _effects_slider and not is_equal_approx(_effects_slider.value, Sfx.volume):
		_effects_slider.set_value_no_signal(Sfx.volume)


func _toggle_music() -> void:
	Music.toggle_mute()
	_update_music_controls()


## A row with a volume: a label and a slider from silent to full.
func _make_volume_row(title: String, tooltip: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = Lang.t(title)
	label.add_theme_font_override("font", TEXT_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", GOLD)
	# Both rows' labels take the same width, so the sliders line up.
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 32)
	slider.tooltip_text = Lang.t(tooltip)
	slider.value = value
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


## The music volume row.
func _make_music_slider() -> Control:
	var row := _make_volume_row("Musik", "Lautstärke der Musik", Music.volume, _on_music_volume_changed)
	_music_slider = row.get_child(1)
	return row


## The sound effects volume row.
func _make_effects_slider() -> Control:
	var row := _make_volume_row("Effekte", "Lautstärke der Geräusche", Sfx.volume, _on_effects_volume_changed)
	_effects_slider = row.get_child(1)
	return row


func _on_effects_volume_changed(value: float) -> void:
	if is_equal_approx(value, Sfx.volume):
		return
	Sfx.set_volume(value)
	# Moving the slider up with the sound off (M) switches the sound back on.
	if Sfx.muted and value >= 0.01:
		Sfx.toggle_mute()
	_update_sound_button()


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
	if playtest_file != "":
		back_to_editor()
		return
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


## Name, hero level, map level, gold, slot and time of a saved game (by
## default this hero's), or nothing when there is none.
func save_info(path := "") -> Dictionary:
	if path == "":
		path = save_path()
	if not FileAccess.file_exists(path):
		return {}
	var data := _read_save(path)
	if not data.has("level") or not data.has("coins"):
		return {}
	# Games saved before there were several have no time of their own.
	var time := float(data.get("saved_at", FileAccess.get_modified_time(path)))
	var hero := str(data.get("name", Lang.t("Namenlos")))
	return {"path": path, "slot": slot_of(path), "name": hero, "hero_level": saved_hero_level(data, hero), "level": int(data.level) + 1, "coins": int(data.coins),
			"escaped": bool(data.get("escaped", false)), "home": bool(data.get("claimed", false)), "time": time}


## The hero level of a saved game. Games saved before the save kept the
## experience ("xp") take it from the hero's training (see Training.load_level),
## where it has always been kept by name; a hero with neither is on level 1.
static func saved_hero_level(data: Dictionary, hero: String) -> int:
	var xp = data.get("xp")
	if xp == null:
		xp = Training.load_level(hero).get("xp", 0)
	return HeroLevel.level_for(int(xp))


## Every saved game there is, the one saved last first.
func save_list() -> Array:
	var saves := []
	for f in DirAccess.get_files_at(save_dir):
		if slot_of(save_dir + f) > 0:
			var info := save_info(save_dir + f)
			if not info.is_empty():
				saves.append(info)
	saves.sort_custom(func(a, b): return a.time > b.time)
	return saves


## Who a saved game's hero is and where, in one sentence: "Ada, Heldenstufe 7,
## auf Ebene 3 mit 40 Gold.", at home, or on the graveyard. The hero level
## sits beside the name, as it belongs to the hero, not to the place.
static func save_summary(info: Dictionary) -> String:
	var who := Lang.t("%s, Heldenstufe %d,") % [info.name, int(info.get("hero_level", 1))]
	if info.home:
		return Lang.t("%s zu Hause mit %d Gold.") % [who, info.coins]
	if info.escaped:
		return Lang.t("%s auf dem Friedhof mit %d Gold.") % [who, info.coins]
	return Lang.t("%s auf Ebene %d mit %d Gold.") % [who, info.level, info.coins]


## Whether the hero of saved game a has come further than the one of b: their
## own house beats the graveyard, the graveyard beats the dungeon, a deeper
## level beats a higher one, and more gold settles the rest. Nothing (an
## empty slot) is never stronger.
static func is_stronger(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty():
		return false
	if b.is_empty():
		return true
	for key in ["home", "escaped", "level", "coins"]:
		var x := int(a[key])
		var y := int(b[key])
		if x != y:
			return x > y
	return false


## The time a game was saved, as the player's clock showed it.
static func save_time_text(time: float) -> String:
	var local := int(time) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]


func _read_save(path := "") -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path if path != "" else save_path()))
	return data if data is Dictionary else {}


func _apply_save(data: Dictionary) -> void:
	hero_name = data.get("name", Lang.t("Namenlos"))
	coins = int(data.coins)
	iron = int(data.get("iron", 0))
	bars = {}
	var saved_bars = data.get("bars", {})
	if saved_bars is Dictionary:
		for metal in saved_bars:
			if str(metal) in Forge.FINE and int(saved_bars[metal]) > 0:
				bars[str(metal)] = int(saved_bars[metal])
	var friends := Companions.from_save(data)
	companions = friends.list
	following = friends.following
	trust = friends.trust
	secrets_found = int(data.get("secrets", 0))
	dry_levels = int(data.get("dry", 0))
	bumped_person = bool(data.get("bumped_person", false))
	hints_shown.clear()
	_hints_last.clear()
	var saved_hints = data.get("hints", {})
	if saved_hints is Dictionary:
		for key in saved_hints:
			hints_shown[str(key)] = int(saved_hints[key])
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
	player.set_level_data(Training.load_level(hero_name))
	lore.assign(data.get("lore", []))
	# Wall writings saved before they were written in blood.
	for i in lore.size():
		lore[i] = Level.OLD_WRITINGS.get(lore[i], lore[i])
		if lore[i] == OLD_DARK_LEARN:
			lore[i] = DARK_LEARN
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
	floors.clear()
	var saved_floors = data.get("floors", {})
	if saved_floors is Dictionary:
		for key in saved_floors:
			if saved_floors[key] is Array:
				floors[str(key)] = (saved_floors[key] as Array).filter(func(e): return e is Array and e.size() >= 4)
	escaped = bool(data.get("escaped", false))
	home_upgrades = _known_keys(data.get("upgrades", []), HomeUpgrades.ALL)
	trophies = _known_keys(data.get("trophies", []), HomeUpgrades.TROPHIES)
	home_given = bool(data.get("home", false))
	home_claimed = home_given and bool(data.get("claimed", false))
	met.clear()
	var saved_met = data.get("met", [])
	if saved_met is Array:
		for role in saved_met:
			if Villager.ROLES.has(str(role)):
				met[str(role)] = true
	quests.load_from(data.get("quests", {}))
	# The chief may have fallen before his task was taken: it counts.
	quests.catch_up()
	journal.load_from(data.get("journal", {}))
	day = maxi(0, int(data.get("day", 0)))
	bounties.load_from(data.get("bounties", {}))
	bounties.refresh(day)
	crafting.load_from(data.get("crafting", {}))
	wishes.load_from(data.get("wishes", {}))
	reputation.load_from(data.get("reputation", {}))
	village_talk.load_from(data.get("ties", []))
	Factions.load_from(data.get("factions", {}))
	var plan = data.get("plan", {})
	away_plan = plan if plan is Dictionary and not plan.is_empty() else Offline.empty_plan()
	player.bag.assign(data.bag)
	player.home_hp = HomeUpgrades.trophy_hp(home_upgrades, trophies)
	player.refresh_stats()
	# Games saved before there was a clock wake up in the morning.
	day_hour = fposmod(float(data.get("hour", DayNight.START_HOUR)), 24.0)
	wanderer_night = int(data.get("wanderer_night", -1))
	hoard.load_from(data.get("hoard", {}))
	wanderer_stock.clear()
	var wares = data.get("wanderer", [])
	if wares is Array:
		for id in wares:
			if Items.ALL.has(str(id)) or Wanderer.is_ingredient(str(id)):
				wanderer_stock.append(str(id))
	# Games saved before there was weather wake up to clear skies.
	set_weather(str(data.get("weather", Weather.CLEAR)), float(data.get("weather_hours", Weather.FIRST_HOURS)))
	var index := clampi(int(data.level), 0, level_files.size() - 1)
	inside_house = 0
	var own_house := Homes.house_of(hero_name)
	var at_inn: bool = data.get("inn", false) and _is_inn_file(index)
	if at_inn:
		# Saved in the bed of an inn on the way: the hero wakes up there,
		# not back home, so the long road need not be walked again.
		pass
	elif escaped and home_claimed and own_house > 0 and interiors.has("^"):
		# The hero's own town house is the place to come back to: every
		# load wakes up beside its bed, wherever the game was saved.
		index = interiors["^"]
		inside_house = own_house
	elif escaped and _outdoor_index() >= 0:
		# Out of the dungeon, every load begins in the open air, wherever the
		# game was saved: on the graveyard, or in the hero's own house.
		index = _outdoor_index()
	load_level(index, false)
	if (level.is_home or level.inn) and level.bed_side != Vector3.ZERO:
		player.global_position = level.bed_side
	elif level is Outdoor and home_claimed and level.home_spot != Vector3.ZERO:
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


## The file of a slot's saved game, by default the slot of this hero.
func save_path(slot := 0) -> String:
	return save_dir + "platz_%d.json" % (slot if slot > 0 else save_slot)


## The slot of a saved game's file, or 0 when the file is not a slot.
static func slot_of(path: String) -> int:
	var file := path.get_file()
	if not (file.begins_with("platz_") and file.ends_with(".json")):
		return 0
	var number := file.trim_prefix("platz_").trim_suffix(".json")
	return int(number) if number.is_valid_int() and int(number) > 0 else 0


## Whether a slot holds a saved game, by default the slot of this hero.
func has_slot_save(slot := 0) -> bool:
	return FileAccess.file_exists(save_path(slot))


## Deletes a saved game (from the load window, or a slot a new game takes).
func delete_save(path: String) -> void:
	if path.begins_with(save_dir) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Saved games from older versions move into free slots, the one saved last
## first: the single file from before there could be several, and the files
## named after their hero from before there were slots. Each keeps its time.
func _move_old_saves() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var old := []
	if FileAccess.file_exists(old_save_file):
		old.append(old_save_file)
	for f in DirAccess.get_files_at(save_dir):
		if f.ends_with(".json") and slot_of(save_dir + f) == 0:
			old.append(save_dir + f)
	var moving := []
	for path in old:
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (data is Dictionary):
			continue
		if not data.has("saved_at"):
			data.saved_at = FileAccess.get_modified_time(path)
		moving.append([path, data])
	moving.sort_custom(func(a, b): return float(a[1].saved_at) > float(b[1].saved_at))
	var slot := 1
	for entry in moving:
		while has_slot_save(slot):
			slot += 1
		var file := FileAccess.open(save_path(slot), FileAccess.WRITE)
		if file == null:
			return
		file.store_string(JSON.stringify(entry[1]))
		file.close()
		if has_slot_save(slot):
			DirAccess.remove_absolute(entry[0])


## The level index of the open air outside the crypt, or -1 without one.
## Whether a boss that falls only once per saved game has fallen already
## (see Quests.ONCE_ONLY). The chief is remembered in the looted ids of the
## open-air map (see Outdoor.CHIEF_DEFEATED).
func boss_fallen(kind: String) -> bool:
	if kind != "hauptmann":
		return false
	for file in looted:
		if looted[file].has(Outdoor.CHIEF_DEFEATED):
			return true
	return false


func _outdoor_index() -> int:
	# Testing an open-air map from the workshop: out of a building onto that map.
	if playtest_file != "" and Level.is_outdoor_file(playtest_file):
		return level_files.size() - 1
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
	if playtest_file != "":
		return false
	Training.save_hero(hero_name, player.xp, player.level_data())
	journal.catch_up()
	var data := {
		"version": 1, "name": hero_name, "sex": player.sex, "xp": player.hero_xp, "level": level_index, "coins": coins, "iron": iron, "bars": bars, "secrets": secrets_found, "dry": dry_levels, "bumped_person": bumped_person, "hints": hints_shown, "hp": player.hp, "knives": player.knives,
		"gift_hp": player.gift_hp, "gift_power": player.gift_power, "gift_speed": player.gift_speed, "gift_armor": player.gift_armor,
		"equipped": player.equipped, "wear": player.wear, "hair": player.hair, "bag": player.bag, "storage": storage, "shop": shop_stock,
		"lore": lore, "plan": away_plan, "escaped": escaped, "home": _home_given_now(), "claimed": home_claimed,
		"upgrades": home_upgrades.keys(), "trophies": trophies.keys(),
		"saved_at": Time.get_unix_time_from_system(),
		"looted": _looted_for_save(), "met": met.keys(), "builds": _builds_for_save(), "floors": _floors_for_save(),
		"quests": quests.for_save(),
		"journal": journal.for_save(),
		"day": day, "bounties": bounties.for_save(),
		"crafting": crafting.for_save(),
		"wishes": wishes.for_save(),
		"reputation": reputation.for_save(),
		"ties": village_talk.for_save(),
		"factions": Factions.for_save(),
		"companions": {"list": companions, "following": following, "trust": trust},
		"hour": day_hour,
		"wanderer": wanderer_stock, "wanderer_night": wanderer_night,
		"hoard": hoard.for_save(),
		"weather": weather, "weather_hours": weather_hours,
		"inn": level.inn,
	}
	if going_away:
		data.away = {"plan": Offline.normalized(away_plan, away_choices()), "since": Time.get_unix_time_from_system()}
	var path := save_path()
	DirAccess.make_dir_recursive_absolute(save_dir)
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


## What lies on each level's floor, levels with nothing left out.
func _floors_for_save() -> Dictionary:
	var out := {}
	for key in floors:
		if not floors[key].is_empty():
			out[key] = floors[key]
	return out


## Sets an item from the bag down at the hero's feet, on this level's floor
## (see Level.put_on_floor). It stays there until picked up again.
func drop_on_floor(id: String) -> void:
	if level == null or player == null:
		return
	var ahead := -player.global_transform.basis.z
	ahead.y = 0.0
	var spot := player.global_position + (ahead.normalized() * 0.6 if ahead.length() > 0.01 else Vector3.ZERO)
	level.put_on_floor(id, spot)
	Sfx.play_gear(level, id, 0.0, spot)


## The looted ids per level file as plain lists, levels with none left out.
func _looted_for_save() -> Dictionary:
	var out := {}
	for file in looted:
		if not looted[file].is_empty():
			out[file] = looted[file].keys()
	return out


## The hero lies down in the safe room's bed: save, then back to the title.
## Whether a level file is an inn on the way (the line "inn:").
func _is_inn_file(index: int) -> bool:
	if index < 0 or index >= level_files.size():
		return false
	for line in FileAccess.get_file_as_string(level_files[index]).split("\n"):
		if line.begins_with("inn:"):
			return true
	return false


## Rests in the bed of an inn till the next morning without logging out:
## life full, poison and curses gone, and the game saved right there.
func rest_at_inn() -> void:
	if state != State.PLAYING or not level.inn:
		return
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	var tween := create_tween()
	var bed := _nearest_bed()
	if bed.is_empty():
		player.play("Lie_Down", 0.2)
	else:
		_climb_into_bed(tween, bed)
	tween.tween_interval(1.4)
	tween.tween_callback(_fall_asleep)
	tween.tween_interval(1.6)
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 1.2)
	tween.tween_callback(func():
		_stop_snoozing()
		if _dawn_between(day_hour, DayNight.WAKE_HOUR):
			_new_day(true)
		day_hour = DayNight.WAKE_HOUR
		set_weather(Weather.roll(day_hour, _weather_rng))
		player.hp = player.max_hp
		player.cure()
		player.global_position = level.bed_side if level.bed_side != Vector3.ZERO else player.global_position
		player.face(Vector3.BACK)
		player.play("Idle")
		_snap_camera()
		_update_hud()
		var saved := save_game()
		player.frozen = false
		state = State.PLAYING
		show_message(Lang.t("Ausgeruht! Ein neuer Morgen in den Bergen.") + "\n" + (Lang.t("Spiel gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!")), 3.5))
	tween.tween_property(_fade, "color:a", 0.0, 1.0)


## The bed's "stay awake": saves the game where the hero stands, without
## logging out, and shows the saved games. Closing that window carries on.
func stay_awake() -> void:
	var saved := save_game()
	menus.saved_now = "ok" if saved else "failed"
	menus.open("laden")


func sleep() -> void:
	# A night in the bed: the hero wakes up the next morning.
	if level.outdoor or level.building != "":
		if _dawn_between(day_hour, DayNight.WAKE_HOUR):
			_new_day(true)
		day_hour = DayNight.WAKE_HOUR
		# A new morning brings new weather.
		set_weather(Weather.roll(day_hour, _weather_rng))
	if level.inn:
		# A night in an inn's bed: the hero gets up rested.
		player.hp = player.max_hp
		player.cure()
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
	if is_instance_valid(pet):
		# The fox goes to bed too: into its basket beside the hero's bed. A
		# doe or a stag lies down where it is.
		pet.go_to_bed(level.fox_bed_near(bed.pos if not bed.is_empty() else player.global_position) if pet.kind == "fuchs" else Vector3.INF)
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


# --- Waking up -----------------------------------------------------------------

## True while a hero loaded from a bed save wakes up and gets out of bed.
var _waking := false
## The wake-up after a bed save, in seconds: asleep while the night fades,
## eyes open, a yawn, the fox wakes, the hero gets up, then hops down.
const WAKE_SLEEP := 2.2
const WAKE_YAWN := 0.5
const WAKE_STRETCH := 0.4
const WAKE_FOX := 0.5
const WAKE_HOP := 0.45


## Right after a saved game is loaded: a game saved in bed wakes up there
## (see _wake_in_bed); otherwise, or once out of bed, the welcome-back
## window tells what the hero did while the player was away.
func _after_load(data: Dictionary) -> void:
	if not _wake_in_bed(data, _return_from_away.bind(data)):
		_return_from_away(data)


## Whether the save was made by lying down in a bed (see sleep).
static func saved_in_bed(data: Dictionary) -> bool:
	var away = data.get("away", {})
	return away is Dictionary and not away.is_empty()


## A game saved in bed starts in bed: the hero lies there asleep, with the
## fox curled up in its basket, while the night fades. Then the hero opens
## their eyes and yawns, the fox wakes and hops out of its basket, and the
## hero gets up on the mattress and hops down beside the bed. `done` runs
## once the hero stands on the floor and can be moved again. Returns false
## (and does nothing) if the save was not made in bed or the level has no
## bed to wake up in.
func _wake_in_bed(data: Dictionary, done: Callable) -> bool:
	if not saved_in_bed(data):
		return false
	var bed := _nearest_bed()
	if bed.is_empty():
		return false
	# In the open air a load starts beside the hero's own house bed; a bed
	# anywhere else on the map is not the one the game was saved in.
	if level is Outdoor and _flat_gap(player.global_position, bed.pos) > Level.TILE * 2.0:
		return false
	_waking = true
	state = State.TRANSITION
	var rot: float = bed.get("rot", 0.0)
	var foot := Vector3(sin(rot), 0.0, cos(rot))
	var lie: Vector3 = bed.pos + foot * BED_LIE_OFFSET + Vector3(0, BED_MATTRESS_HEIGHT, 0)
	var floor_spot := _bedside(bed, foot)
	player.frozen = true
	player.path.clear()
	player.velocity = Vector3.ZERO
	player.global_position = lie
	player.face(foot)
	player.lie_asleep()
	var fox_wakes := false
	if is_instance_valid(pet) and pet.kind == "fuchs":
		var basket := level.fox_bed_near(bed.pos)
		if basket != Vector3.INF:
			pet.sleep_in_basket(basket)
			fox_wakes = true
	_fall_asleep()
	var tween := create_tween()
	tween.tween_interval(WAKE_SLEEP)
	tween.tween_callback(func():
		_stop_snoozing()
		player.set_asleep(false))
	# A moment later, once the last Z has drifted off, a big yawn.
	tween.tween_interval(WAKE_YAWN)
	tween.tween_callback(func():
		var slot := player.find_child("HeadSlot", true, false) as Node3D
		var head := slot.global_position if slot else player.global_position
		Effects.float_text(level, head + Vector3(0, 0.8, 0), Lang.t("Gähn!"), Color(0.85, 0.9, 1.0), true))
	tween.tween_interval(WAKE_STRETCH)
	if fox_wakes:
		tween.tween_callback(func():
			if is_instance_valid(pet):
				pet.wake_up(floor_spot))
		tween.tween_interval(WAKE_FOX)
	tween.tween_callback(player.get_up_from_bed)
	tween.tween_interval(Player.GET_UP_TIME)
	# Standing on the mattress: turn towards the floor and hop down.
	tween.tween_callback(func():
		player.face(floor_spot - player.global_position)
		player.play("Jump_Idle", 0.1))
	tween.tween_method(func(t: float):
		player.global_position = lie.lerp(floor_spot, t) + Vector3(0, sin(t * PI) * 0.5, 0), 0.0, 1.0, WAKE_HOP)
	tween.tween_callback(func():
		player.global_position = floor_spot
		player.play("Idle", 0.2)
		player.frozen = false
		_waking = false
		state = State.PLAYING
		done.call())
	return true


static func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Where the hero stands after getting out of `bed`: the open floor beside
## it (the same spot a load in the hero's own house starts on), or else in
## front of its foot.
func _bedside(bed: Dictionary, foot: Vector3) -> Vector3:
	if level is Outdoor and level.home_spot != Vector3.ZERO:
		return level.home_spot
	var cell: Vector2i = bed.get("cell", Vector2i(-1, -1))
	if cell != Vector2i(-1, -1):
		var side := level._open_side(cell)
		if side != cell:
			return level.cell_to_world(side)
	return bed.pos + foot * 2.2


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
	var crafts := Offline.RECIPES.keys().filter(reputation.can_craft)
	return {"job": jobs, "train": train, "study": books, "craft": crafts}


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
	var result := Offline.simulate(plan, hours, HomeUpgrades.has(home_upgrades, "werkstatt"))
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
	# Cut stone blocks go into the storage chest, as many as it still holds.
	var stones := 0
	for i in int(result.get("stones", 0)):
		if not HomeUpgrades.storage_fits(home_upgrades, storage, Menus.STONE):
			break
		storage.append(Menus.STONE)
		stones += 1
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
		elif Offline.RECIPES[plan.craft].makes == "stone":
			made = Lang.t("%d Steinblöcke (in der Truhe)") % stones
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
	# A hero waking up in bed is still busy getting up (see _wake_in_bed).
	state = State.TRANSITION if _waking else State.PLAYING
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


## How far from the hero a spoken line is still heard and written into the
## event log, in metres.
const HEAR_RANGE := 14.0


## A line someone said (see Events.say): into the event log when the hero is
## near enough to hear it.
func heard(speaker: String, text: String, pos: Vector3) -> void:
	if player == null or not player.is_inside_tree():
		return
	var d := pos - player.global_position
	d.y = 0.0
	if d.length() <= HEAR_RANGE:
		event_log.add_speech(speaker, text)


## The passing troubles the hero is in, as [kind, number] pairs in their
## fixed order (see StatusIcon): shown under the life bar.
func hero_ailments() -> Array:
	var out := []
	for kind in ["gift", "fluch", "brand"]:
		if player.ailments.has(kind):
			out.append([kind, ""])
	# Slower only from a heavy load (the curse that slows has its own icon,
	# and a little gear is normal); not while faster all the same.
	if not _hero_fast() and Items.load_factor(player.load_weight()) <= 1.0 - Items.MAX_WEIGHT_SLOW * 0.5:
		out.append(["slow", ""])
	return out


## The boons the hero has, as [kind, number] pairs in their fixed order (see
## StatusIcon): shown in the status block at the top left.
func hero_boons() -> Array:
	var out := []
	if player.power > 1:
		out.append(["power", str(player.power)])
	if _hero_fast():
		out.append(["fast", ""])
	if player.hardening > 0:
		out.append(["hardening", str(player.hardening)])
	return out


## Faster than normal from gifts, level or Tempo (leaving out the curse's
## slowness, which has an icon of its own).
func _hero_fast() -> bool:
	var unslowed := player.base_speed / (Player.CURSE_SLOW if player.ailments.has("fluch") else 1.0)
	return unslowed > Player.SPEED + 0.01


func _update_status_icons() -> void:
	_fill_icon_row(_status_row, hero_ailments())
	_fill_icon_row(_boon_row, hero_boons())
	_fill_icon_row(_notice_row, hero_notices())


## What a condition or notice icon means, in a sentence: shown when the
## pointer rests on the icon, and written into the event log when it first
## appears (touch has no pointer to rest).
func icon_text(kind: String, number: String) -> String:
	match kind:
		"gift": return Lang.t("Vergiftet: Du verlierst alle paar Sekunden ein Leben, nie das letzte. Ein Brunnen, ein Schrein oder ein Heiltrank heilt es.")
		"fluch": return Lang.t("Verflucht: Du bist langsamer. Es vergeht bald; ein Brunnen, ein Schrein oder ein Heiltrank heilt es sofort.")
		"brand": return Lang.t("Du brennst: Ein paar Sekunden lang verlierst du Leben, nie das letzte.")
		"power": return Lang.t("Kampfkraft %s: Deine Schläge treffen härter.") % number
		"fast": return Lang.t("Schneller als sonst: Tempo %d%%") % roundi(player.speed / Player.SPEED * 100.0)
		"slow": return Lang.t("Schwer beladen: Du läufst langsamer. Leg im Inventar (I) etwas ab.")
		"hardening": return Lang.t("Härtung %s: Jeder Treffer gegen dich wird um so viel schwächer, bleibt aber mindestens halb so stark.") % number
		"repair": return Lang.t("Abgenutzt: %s Teil(e) deiner Ausrüstung. Plane beim Schlafen „Ausrüstung ausbessern“ ein, sonst zerbrechen sie.") % number
		"upgrade": return Lang.t("Hagen der Steinmetz kann jetzt einen Ausbau für dein Haus bauen.")
	return ""


## Things waiting for the hero, as [kind, number] pairs (see StatusIcon):
## worn gear to mend (half its durability or more used up) and a home
## upgrade Hagen could build right now. (A free level point is told beside
## the hero level, with its key.)
func hero_notices() -> Array:
	var out := []
	var worn := 0
	for id in player.equipped.values():
		var durability: int = Items.ALL.get(id, {}).get("durability", 0)
		if durability > 0 and player.wear.get(id, 0) * 2 >= durability:
			worn += 1
	if worn > 0:
		out.append(["repair", str(worn)])
	for id in HomeUpgrades.ALL:
		if HomeUpgrades.why_not(id, home_upgrades, player.bag, storage, coins) == "":
			out.append(["upgrade", ""])
			break
	return out


## Shows `wanted` ([kind, number] pairs) as icons in `row`, rebuilt only
## when something changed.
func _fill_icon_row(row: HBoxContainer, wanted: Array) -> void:
	var shown := []
	for icon in row.get_children():
		shown.append([icon.kind, icon.value])
	if shown == wanted:
		return
	var had := []
	for icon in row.get_children():
		had.append(icon.kind)
		row.remove_child(icon)
		icon.queue_free()
	for c in wanted:
		var text := icon_text(c[0], c[1])
		row.add_child(StatusIcon.make(c[0], c[1], text))
		# A new icon is explained once in the event log as well.
		if not had.has(c[0]) and text != "" and state == State.PLAYING:
			Events.found(text, StatusIcon.log_color(c[0]))


## The life bar's colour for `share` of life left (0 to 1), see HP_COLORS.
static func hp_color(share: float) -> Color:
	share = clampf(share, 0.0, 1.0)
	for i in range(1, HP_COLORS.size()):
		var upper: Array = HP_COLORS[i - 1]
		var lower: Array = HP_COLORS[i]
		if share >= lower[0]:
			return (lower[1] as Color).lerp(upper[1], (share - lower[0]) / (upper[0] - lower[0]))
	return HP_COLORS.back()[1]


## Keeps the life bar and the icons under it at one fixed spot on screen:
## centred across, at HP_BAR_Y of the height. It does not follow the hero,
## so it never moves while the camera trails, shakes or zooms.
func _place_hp_bar() -> void:
	var on_screen := state == State.PLAYING and player != null and player.is_inside_tree() and not player.dead \
			and camera != null
	_hp_bar.visible = on_screen
	_status_row.visible = on_screen
	if not on_screen:
		return
	var screen := _hud.get_viewport().get_visible_rect().size
	_hp_bar.position = Vector2((screen.x - HP_BAR_SIZE.x) / 2.0, screen.y * HP_BAR_Y).round()
	_status_row.position = _hp_bar.position + Vector2(0, HP_BAR_SIZE.y + 5)


## News about a task (a new one, progress, done): a message and a word over
## the hero's head.
func quest_news(text: String, color: Color, duration := 4.0) -> void:
	show_message(text, duration)
	# The words floating up from the hero would cover the villager's speech
	# bubble right beside them: the message at the bottom says it already.
	if not _villager_talking_near_hero():
		Effects.float_text(level, player.global_position + Vector3(0, 3.2, 0), text.get_slice("\n", 0), color, true)
	_update_hud()


## Whether a villager whose speech bubble would lie over the hero's head is
## talking right now (see Villager.BUBBLE_ROOM).
func _villager_talking_near_hero() -> bool:
	if not level is Outdoor or player == null:
		return false
	for v in level.villagers:
		if is_instance_valid(v) and v.visible and v.is_talking() and Vector2(v.global_position.x - player.global_position.x, v.global_position.z - player.global_position.z).length() < Villager.BUBBLE_ROOM:
			return true
	return false


## A task is done: the reward, with a jingle.
func quest_reward(id: String) -> void:
	var q: Dictionary = Quests.ALL[id]
	if q.get("gold", 0) > 0:
		Sfx.play_coins(self, q.gold)
	else:
		Sfx.play(self, "key", -3.0)
	quest_news(Lang.t("Auftrag abgeschlossen: %s\nBelohnung: %s") % [Lang.t(q.title), Quests.reward_text(id)], GOLD, 4.5)


## A villager thinks better of the hero now: friendly, trusted or honoured.
## Several at once (word of mouth after a task) are told together, once the
## reward has been read.
func reputation_rose(role: String, new_level: int) -> void:
	# Only what changed, as one line in the event log: the whole list of
	# villagers is in the compendium (H, "Ruf") for whoever wants to look.
	var line := Lang.t("Ansehen bei %s: %s") % [Quests.villager_name(role), Reputation.level_name(new_level)]
	var off := roundi(Reputation.LEVELS[new_level].discount * 100.0)
	if off > 0:
		line += Lang.t(" (%d%% Rabatt)") % off
	Events.found(line, Menus.REPUTATION_COLOR)
	learn(Reputation.HOW_TO)


## A price in gold at the villager whose window is open (see trader_role).
func trader_price(gold: int) -> int:
	return reputation.price(trader_role, gold)


## The "!" and "?" over the villagers' heads. Looked at a few times a
## second, so kills, loot and a full or emptied bag show up on their own.
func refresh_quest_marks() -> void:
	if not (level is Outdoor):
		return
	for v in level.villagers:
		if is_instance_valid(v):
			var quest_mark := quests.mark(v.role)
			if quest_mark == "":
				quest_mark = crafting.mark(v.role)
			if quest_mark == "":
				quest_mark = wishes.mark(v.role)
			v.set_quest_mark(quest_mark)
	(level as Outdoor).set_board_mark(bounties.mark())


## Something in the bag changed because of a task.
func update_after_quest() -> void:
	Sfx.play(self, "key", -6.0)
	_update_hud()


## Explained once in the compendium, the first time a landmark goes on the map.
const MAP_LEARN := "Deine Karte füllt sich, während du erkundest: Was du gesehen hast, steht darauf, dazu jeder Ort, den du entdeckt hast, und jede Stelle, an der du etwas gefunden hast. Das Tagebuch daneben hält fest, wann und wo. Beides öffnest du mit N (oder mit dem Kartenbild am rechten Rand)."


## New landmarks have come into view: a short note, unless something more
## important is being said.
func map_notice(names: Array[String]) -> void:
	learn(MAP_LEARN)
	if not _message_busy():
		show_message(Lang.t("Neu auf deiner Karte: %s") % ", ".join(names), 2.4)


## How the Erkunden skill grows and what it is good for (for the compendium).
const EXPLORE_LEARN := "Erkunden ist eine Fertigkeit ohne Ausrüstung. Sie wächst, wenn du eine Karte ganz erkundest (95 % ihres Bodens gesehen, siehe Karte), und ein wenig mit jedem Geheimraum und jeder Inschrift. Jede Stufe gibt +3 %, einen Geheimraum zu entdecken, +4 %, beim Durchsuchen eine Fackel zu finden, und +8 %, eine Inschrift an der Wand zu bemerken."


## The hero has seen the whole of a map (see Journal.note_full_map).
func map_explored(file: String) -> void:
	player.train("erkunden", Training.EXPLORE_FULL_MAP)
	learn(EXPLORE_LEARN)
	Sfx.play(self, "secret", -6.0)
	show_message(Lang.t("Ganz erkundet: %s\nDein Blick für Verborgenes wird schärfer (Erkunden).") % journal.level_title(file), 4.0)


## The hero noticed a writing on a wall (see Level.reveal_writing) or read
## one again: it pops up on a card (see WritingCard) and goes into the
## compendium and the journal; a new one trains Erkunden a little.
func writing_found(text: String) -> void:
	if not lore.has(text):
		player.train("erkunden", Training.EXPLORE_WRITING_FOUND)
		# A rune tablet of the dwarves is a riddle of its own (see Mines).
		var rune: Variant = Mines.TABLETS.find_key(text)
		if rune != null:
			Events.bus().riddle_solved.emit("rune", HeroLevel.rune_level(rune))
		else:
			Events.bus().riddle_solved.emit("writing", HeroLevel.place_level(level))
		journal.write("Inschrift entdeckt", [], journal.current_file())
	learn(text)
	learn(EXPLORE_LEARN)
	Sfx.play(self, "secret", -8.0)
	if WritingCard.word_of(text) != "":
		writing_card.show_writing(text)
	else:
		show_message(Lang.t(text), 6.0)


## The hero spotted a hidden trap (see Traps): it trains Erkunden and earns
## a little experience, and the compendium explains traps.
func trap_spotted(text: String, place_level: int) -> void:
	player.train("erkunden", Training.EXPLORE_TRAP_FOUND)
	learn(Traps.LEARN)
	earn_xp(HeroLevel.time_xp(HeroLevel.TRAP_MINUTES, place_level, player.hero_level()))
	show_message(text, 3.5)


## A teleporter trap flung the hero across the level (see Traps).
func _on_trap_teleport(_to: Vector3) -> void:
	learn(Traps.LEARN)
	_snap_camera()
	if is_instance_valid(pet):
		pet.arrive()
	show_message(Lang.t("Eine Teleportfalle! Sie hat dich an einen anderen Ort geschleudert."), 3.0)


## The floor gave way under the hero (a trapdoor, see Traps): they fall to
## the level below, land somewhere near its start and take `damage`.
func _fall_through_trapdoor(damage: int) -> void:
	if state != State.PLAYING:
		return
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	player.velocity = Vector3.ZERO
	learn(Traps.LEARN)
	var tween := create_tween()
	tween.tween_property(player, "global_position:y", player.global_position.y - 3.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.45)
	tween.tween_callback(_land_below.bind(damage))


func _land_below(damage: int) -> void:
	if level.building == "":
		# Down to the floor below in the dungeon: the hero climbs the dungeon
		# upwards (the stairs lead to level_index + 1, see _next_level), so the
		# floor below is the one they came from. It is not a floor cleared, so
		# it does not count towards dry_levels.
		Training.save_hero(hero_name, player.xp, player.level_data())
		level.note_left()
		load_level(level_index - 1, false)
	else:
		load_level(interiors[level.down_to], false)
	player.global_position = level.cell_to_world(Traps.landing_cell(level))
	player.velocity = Vector3.ZERO
	player.face(Vector3.BACK)
	if is_instance_valid(pet):
		pet.arrive()
	_snap_camera()
	player.frozen = false
	state = State.PLAYING
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
	_announce_level()
	Sfx.play(self, "rumble", -4.0)
	_shake = 0.5
	# The landing hurts, even though arriving on a level gives a moment's grace.
	player._invulnerable = 0.0
	player.take_damage(damage, player.global_position + Vector3(0, 0, 1), null, false)
	var here := level
	get_tree().create_timer(3.8).timeout.connect(func():
		if level == here and state == State.PLAYING:
			show_message(Lang.t("Eine Falltür! Du bist eine Ebene tiefer gestürzt."), 3.0))
	if level.safe:
		_autosave()


## Records where the hero found something, for the map and the journal (see
## Journal.note_find): kind is e.g. "ingredient" or "fish", id the item id and
## name its German name. pos is where it was found in the current level.
func note_find(kind: String, id: String, name: String, pos: Vector3) -> bool:
	if level == null:
		return false
	return journal.note_find(kind, id, name, journal.current_file(), level.world_to_cell(pos))


## Remembers an explanation for the compendium, once.
## The wandering merchant's wares for tonight: a new visit brings new ones,
## and what was bought stays gone until then.
func wanderer_wares() -> Array[String]:
	if day != wanderer_night:
		wanderer_night = day
		wanderer_stock = Wanderer.stock_for(day, hero_name)
	return wanderer_stock


func learn(entry: String) -> void:
	if not lore.has(entry):
		lore.append(entry)
		# Understanding something new trains the mind.
		player.train("intelligenz", 5.0)


## Puts the message line at its place: above a wall writing's card while
## that shows (see WritingCard), else at MESSAGE_BOTTOM.
func place_message() -> void:
	var lift := maxf(MESSAGE_BOTTOM, writing_card.clearance())
	_message_box.offset_top = -lift
	_message_box.offset_bottom = -lift


## Shows a message at the bottom of the screen for `duration` seconds, in
## `color` (white, or gold for great news). A message that came just before
## and is not read yet moves up a line instead of being covered or lost.
func show_message(text: String, duration := 2.2, color := Color.WHITE) -> void:
	_keep_unread_message(text)
	_message.text = text
	_message_duration = duration
	place_message()
	_message.add_theme_color_override("font_color", color)
	_style_message(_message, _message_size(text))
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.25)
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.6)


## Space between two message lines, in pixels.
const MESSAGE_GAP := 8
## Seconds a message needs to be read: a second to look, then 60 ms per
## letter (the ux-ui guide's rule for toasts).
static func read_time(text: String) -> float:
	return 1.0 + text.length() * 0.06


## Very long messages get a smaller font so they stay at a few lines.
func _message_size(text: String) -> int:
	if text.length() > 160:
		return MESSAGE_FONT_SIZE - 4
	if text.length() > 90:
		return MESSAGE_FONT_SIZE - 2
	return MESSAGE_FONT_SIZE


func _style_message(line: Label, size: int) -> void:
	line.add_theme_font_size_override("font_size", size)
	line.add_theme_constant_override("outline_size", maxi(4, size / 6))


## Most unread messages kept above the newest one; an older one makes room.
const MESSAGE_KEPT := 2


func _message_line() -> Label:
	var line := _make_label(TEXT_FONT, MESSAGE_FONT_SIZE)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.modulate.a = 0.0
	return line


## The message on screen moves up a line and stays until it is read, when a
## new one comes before that. One read already, or the same text again, is
## simply replaced.
func _keep_unread_message(new_text: String) -> void:
	# Asked by the tween, not by the line's alpha: a message shown in the same
	# frame has not faded in yet, but it is still unread.
	if _message_tween == null or not _message_tween.is_running() or _message.text == "" or _message.text == new_text:
		return
	var shown := _message_tween.get_total_elapsed_time()
	var needed := minf(read_time(_message.text), _message_duration + 0.25)
	if shown >= needed:
		return
	var kept := _message_line()
	kept.text = _message.text
	kept.add_theme_color_override("font_color", _message.get_theme_color("font_color"))
	_style_message(kept, _message_size(_message.text))
	kept.modulate.a = _message.modulate.a
	_message_box.add_child(kept)
	_message_box.move_child(kept, _message.get_index())
	_message_kept.append(kept)
	while _message_kept.size() > MESSAGE_KEPT:
		_message_kept.pop_front().queue_free()
	var tween := kept.create_tween()
	tween.tween_property(kept, "modulate:a", 1.0, 0.15)
	tween.tween_interval(maxf(needed - shown, 0.8))
	tween.tween_property(kept, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func():
		_message_kept.erase(kept)
		kept.queue_free())


## The message lines on screen now, oldest first, the newest last (for tests).
func message_lines() -> Array[Label]:
	var lines: Array[Label] = []
	for line in _message_kept:
		if is_instance_valid(line) and not line.is_queued_for_deletion():
			lines.append(line)
	lines.append(_message)
	return lines


func _on_key_collected() -> void:
	level.has_key = true
	player.play_flourish("PickUp", 0.6)
	Sfx.play(self, "key")
	show_message(Lang.t("Du hast den Schlüssel gefunden!"))
	Events.found(Lang.t("Du hast den Schlüssel gefunden!"), GOLD)
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
	show_message(Lang.t("Alle Druckplatten sind belegt: Das Eisengitter versinkt im Boden!"), 3.5, GOLD)
	Events.bus().riddle_solved.emit("puzzle", HeroLevel.place_level(level))


## A lever torch found: a click and a golden message, then, a moment later,
## rumbling and shaking ground while the secret wall sinks.
func _on_secret_found(lever_pos: Vector3, wall_pos: Vector3) -> void:
	secrets_found += 1
	Events.bus().riddle_solved.emit("secret", HeroLevel.place_level(level))
	journal.note_secret(journal.current_file(), level.world_to_cell(wall_pos))
	level.secret_bonus = secrets_found
	player.train("weisheit", 5.0)
	player.train("erkunden", Training.EXPLORE_SECRET_FOUND)
	Comic.pop(lever_pos, "lever")
	Sfx.play(self, "lever_pull", -2.0, lever_pos)
	learn("Diese Fackelhalterung sieht seltsam aus.\nDu ziehst daran und hörst in der Ferne Stein, der sich bewegt!")
	show_message(Lang.t("Diese Fackelhalterung sieht seltsam aus.\nDu ziehst daran und hörst in der Ferne Stein, der sich bewegt!"), 4.5, GOLD)
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
	if Items.ALL.get(id, {}).get("slot", "") == "erz":
		# Where ore turned up goes on the map (see Journal).
		note_find("ore", id, Items.ALL[id].name, player.global_position)
	Sfx.play(self, "key", -3.0)
	Effects.float_text(level, player.global_position + Vector3(0, 3.0, 0), Items.item_name(id), Rarity.color(id), true)
	Events.found(Lang.t("Gefunden: %s (%s)") % [Rarity.marked(id), Items.describe(id)])
	_update_hud()


func _on_coins_collected(amount: int) -> void:
	coins += _gold(amount)
	Events.found(Lang.t("+%d Gold") % _gold(amount), GOLD)
	Sfx.play_coins(self, _gold(amount))
	_update_hud()


## Gold found, doubled by the lucky clover.
func _gold(amount: int) -> int:
	return amount * 2 if player.has_special("gluecksklee") else amount


## The vampire tooth gives back 1 life for every VAMPIRE_KILLS enemies slain.
const VAMPIRE_KILLS := 3
var _vampire_kills := 0


func _on_enemy_killed(enemy: Enemy) -> void:
	# A boss falls only once: if a rival lands the last blow in the hero's
	# fight, it still counts for the hero, or the task could never be done.
	if enemy.slain_by_rival and not (enemy is BanditChief):
		# Felled by a rival monster (see Factions): it counts for no task.
		if _reach(enemy.global_position) < RIVAL_KILL_HEARD:
			show_message(enemy.fall_text(), 2.5)
		return
	show_message(enemy.fall_text(), 2.5)
	_win_trophy(enemy.kind)
	var drop := quests.on_kill(enemy.kind)
	# Factions and bounties count it, and it is worth experience (see _bus_links).
	Events.bus().enemy_slain.emit(enemy.kind)
	Events.bus().enemy_felled.emit(enemy.rated_level, enemy.is_level_boss())
	if drop != "":
		level._drop_item(drop, enemy.global_position + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)))
	if player.has_special("vampirzahn"):
		_vampire_kills = mini(_vampire_kills + 1, VAMPIRE_KILLS)
	if player.has_special("vampirzahn") and _vampire_kills >= VAMPIRE_KILLS and player.hp < player.max_hp and not player.dead:
		_vampire_kills = 0
		player.hp += 1
		Effects.float_text(level, player.global_position + Vector3(0, 2.6, 0), "+1", Color(0.5, 1.0, 0.5))
		_update_hud()


## The dragon has fallen: the lair is won. A fanfare and a golden line
## first, then, once the dragon has hit the ground, a window that says so
## and offers the way out (see Menus "hoehle").
const LAIR_WON_DELAY := 3.0


## The Mountain King has fallen deep in the third mine.
func _on_mine_boss_won() -> void:
	Sfx.play(self, "level_done", -1.0)
	player.train("weisheit", 10.0)
	_shake = 1.2
	show_message(Lang.t("Der Bergkönig ist besiegt! Das Herz des Berges gehört dir."), 5.0, GOLD)


func _on_lair_won() -> void:
	var here := level
	Sfx.play(self, "level_done", -1.0)
	player.train("weisheit", 10.0)
	get_tree().create_timer(LAIR_WON_DELAY).timeout.connect(func():
		if level != here or state != State.PLAYING or player.dead:
			return
		if menus.is_open():
			# Busy in a window: the golden line alone tells the news.
			show_message(Lang.t("Höhle bezwungen! Der Drache ist tot."), 4.0)
			return
		menus.open("hoehle"))


## The dragon wakes: the lair shakes, its name in gold, and a word on how
## to fight it. Its health bar shows at the top (see BossBar).
func _on_dragon_awakened(dragon: Dragon) -> void:
	_shake = 1.4
	learn(DRAGON_LEARN)
	show_message(Lang.t("%s erwacht!") % Lang.t(dragon.boss_title()) + "\n" + Lang.t(DRAGON_LEARN), 5.0, GOLD)


const DRAGON_LEARN := "Rote Ringe am Boden zeigen, wo sein Feuer fällt: geh beiseite oder spring darüber. Nach dem Feueratem schnauft er, dann trifft deine Klinge doppelt."


## Out of the lair at once, through the glowing way out the fallen dragon
## left behind (or the "Leave the lair" button): back in front of the arch.
func leave_lair() -> void:
	if state != State.PLAYING or not level.lair or player.dead:
		return
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	Sfx.play(self, "magic", -2.0)
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0.9, 0.75, 0.4, 1.0), 0.5)
	tween.tween_callback(func():
		_leave_building()
		get_tree().create_timer(1.0).timeout.connect(func():
			if state == State.PLAYING:
				show_message(Lang.t("Du trittst mit dem Schatz des Drachen aus dem Steinbogen ins Freie."), 3.5)))


## Training raised an attribute or a skill: say so, the attributes louder.
## The German name of a combat skill or a craft (see Training).
static func _skill_or_craft_name(id: String) -> String:
	return Training.SKILLS[id].name if Training.SKILLS.has(id) else Training.CRAFTS[id].name


# --- Hero level -----------------------------------------------------------

## Experience for a felled monster (see HeroLevel.kill_xp).
func xp_for_kill(monster_level: int, boss: bool) -> void:
	earn_xp(HeroLevel.kill_xp(monster_level, player.hero_level(), boss))


## Experience for a villager's task or a wish (see HeroLevel.TASKS).
func xp_for_task(id: String) -> void:
	earn_xp(HeroLevel.task_xp(id, player.hero_level()), true)


func xp_for_bounty(id: String) -> void:
	earn_xp(HeroLevel.task_xp("bounty:" + id, player.hero_level()), true)


func xp_for_riddle(kind: String, place_level: int) -> void:
	earn_xp(HeroLevel.time_xp(HeroLevel.RIDDLES.get(kind, 1), place_level, player.hero_level()), true)


## Gives the hero experience and shows it over their head; a big amount
## (a task, a riddle) shows a little longer and higher.
func earn_xp(amount: int, big := false) -> void:
	if amount <= 0 or player == null:
		return
	# A clever hero gets more out of everything (see Player.clever_xp).
	amount = player.clever_xp(amount)
	if level != null and player.is_inside_tree():
		Effects.float_text(level, player.global_position + Vector3(0, 2.8 if big else 2.4, 0), Lang.t("+%d EP") % amount, XP_COLOR)
	player.gain_xp(amount)
	Training.save_hero(hero_name, player.xp, player.level_data())
	_update_hud()


## The colour of experience on the HUD and in floating numbers.
const XP_COLOR := Color(0.72, 0.62, 1.0)


func _on_leveled_up(new_level: int) -> void:
	var text := Lang.t("Heldenstufe %d! +1 Leben") % new_level
	if new_level % HeroLevel.CON_EVERY == 0:
		text += ", " + Lang.t("+1 Konstitution")
	if new_level % HeroLevel.SPEED_EVERY == 0:
		text += ", " + Lang.t("+1 % Tempo")
	if new_level % HeroLevel.POINT_EVERY == 0:
		text += "\n" + Lang.t("Ein Punkt für Stärke, Geschick oder Intelligenz: Taste P öffnet den Charakter.")
	if level != null and player.is_inside_tree():
		Effects.float_text(level, player.global_position + Vector3(0, 3.6, 0), Lang.t("Heldenstufe %d") % new_level, GOLD, true)
	Sfx.play(self, "level_done", -4.0)
	learn(LEVEL_LEARN)
	_update_hud()
	# A reward or a find told just now stays readable first.
	if _message_tween and _message_tween.is_running():
		await get_tree().create_timer(LEVEL_MESSAGE_WAIT).timeout
	show_message(text, 5.0)


## Seconds the level-up waits for a message already on screen.
const LEVEL_MESSAGE_WAIT := 3.0
## Explained once in the compendium, at the first level-up.
const LEVEL_LEARN := "Erfahrung (EP) bekommst du für besiegte Gegner, erfüllte Aufträge, Kopfgelder und gelöste Rätsel. Gegner weit unter deiner Heldenstufe bringen wenig. Jede Stufe gibt +1 Leben, jede 2. Stufe +1 % Tempo, jede 3. Stufe einen Punkt für Stärke, Geschick oder Intelligenz (im Charakter, Taste P) und jede 5. Stufe +1 Konstitution."


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
			text = Lang.t("Du wirst geübter: %s, Stufe %d") % [Lang.t(_skill_or_craft_name(id)), value]
	var attribute := Training.ATTRIBUTES.has(id)
	if attribute:
		# A stronger body is rare and big: a word over the hero and a message.
		Effects.float_text(level, player.global_position + Vector3(0, 3.4, 0), text.get_slice(":", 1).strip_edges(), GOLD)
		Sfx.play(self, "secret", -6.0)
		show_message(text, 3.5)
	else:
		# A skill grows often: one quiet line in the event log keeps the
		# screen clear for the game.
		Events.found(text, Color(0.65, 0.85, 1.0))
	learn("Eigenschaften wachsen sehr langsam durch Tun: Kämpfen macht stärker (Stärke: +1 Schaden im Nahkampf je Punkt, Lasten wiegen weniger), Treffer einstecken macht zäher (Konstitution, +1 Leben je Punkt), Laufen und Springen machen schneller (Tempo bis 150 %), Springen, Werfen und Fallen machen geschickter (Geschick: +1 Schaden mit Wurfmessern und +4 % Ausweichen je Punkt, weiter springen), Durchsuchen und Geheimnisse schärfen das Gespür (Intuition, +2 % je Punkt, Geheimräume zu entdecken), und alles, was du durchstehst, macht dich weiser (Weisheit: du lernst 5 % schneller je Punkt, ab 12 bieten Schreine eine vierte Gabe), und Neues zu verstehen macht klüger (Intelligenz: Fertigkeiten lernen 10 % schneller und 3 % mehr Erfahrung je Punkt; manche Dinge wie der Zauberhut brauchen sie). Fertigkeiten wachsen schneller, aber nur mit der passenden Ausrüstung. Alles bleibt deinem Helden über alle Läufe.")
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
	if station.get("kind", "") == Seats.KIND and (player.is_seated() or player.still_getting_up()):
		return
	if not station.is_empty():
		if station.has("npc") or PERSON_STATIONS.has(station.kind):
			bumped_person = true
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
	if obj.loot.has("item") and not player.bag_fits(obj.loot.item):
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
		Events.found(text, GOLD)
	elif loot.has("knives"):
		player.knives += loot.knives
		Sfx.play_after(self, found_after, "gear_metal_%d" % (randi() % 3), -8.0)
		text = Lang.t("+%d Wurfmesser") % loot.knives
		color = Color(0.8, 0.9, 1.0)
		Events.found(text, color)
	elif loot.has("potion"):
		Sfx.play(self, "drink")
		player.hp = mini(player.max_hp, player.hp + 2)
		text = Lang.t("Heiltrank! +2 Leben")
		if player.cure():
			text += "\n" + Lang.t("Dein Leiden ist geheilt.")
		color = Color(1.0, 0.5, 0.55)
		Events.found(text, color)
	if loot.has("item"):
		player.bag.append(loot.item)
		Sfx.play_find(self, loot.item, found_after + (0.25 if loot.has("gold") else 0.0))
		var found := Lang.t("Gefunden: %s (%s)") % [Rarity.marked(loot.item), Items.describe(loot.item)]
		text = Items.item_name(loot.item) if text.ends_with("leer") else text + "  +" + Items.item_name(loot.item)
		# The words over the chest take the colour of the piece found.
		color = Rarity.color(loot.item)
		Events.found(found)
	# An eye trained in exploring (Erkunden) finds a torch tucked away.
	var torch := player.bag_fits(HandTorch.ITEM) and randi_range(1, 100) <= player.explore_bonus(Training.EXPLORE_TORCH)
	if torch:
		player.bag.append(HandTorch.ITEM)
		if loot.is_empty():
			color = Color(1.0, 0.75, 0.4)
		Sfx.play_gear(self, HandTorch.ITEM, found_after + 0.25)
		text = Items.item_name(HandTorch.ITEM) if text.ends_with("leer") else text + "  +" + Items.item_name(HandTorch.ITEM)
		if not loot.has("item"):
			Events.found(Lang.t("Dein geübtes Auge findet eine Fackel, die hier versteckt lag."), Color(1.0, 0.75, 0.4))
		else:
			Events.found(Lang.t("Gefunden: %s") % Items.item_name(HandTorch.ITEM), Color(1.0, 0.75, 0.4))
	Effects.float_text(level, obj.icon_pos, text, color, true)
	if loot.is_empty() and not torch:
		Events.found(Lang.t("Du durchsuchst %s... nichts.") % Lang.t(_with_article(obj.label)), Color(0.8, 0.8, 0.85))
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
	home_run.on_hurt()
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
	if playtest_file != "":
		state = State.OVER
		show_message(Lang.t("Gefallen. Zurück zur Werkstatt..."), 2.0)
		get_tree().create_timer(2.0).timeout.connect(back_to_editor)
		return
	state = State.WON if escaped else State.OVER
	var entry := Ranking.add(hero_name, level_index + 1, level.level_name, coins, escaped)
	# Whatever the outcome, a whole run is a lesson.
	player.train("weisheit", 15.0)
	# What the hero trained stays with their name, fallen or free.
	Training.save_hero(hero_name, player.xp, player.level_data())
	if escaped:
		# The run is over, so this hero's saved game in the safe room is
		# gone too. The other slots keep theirs.
		delete_save(save_path())
		_show_title(Lang.t("Frei!"), Lang.t("%s ist entkommen und hat %d Gold erbeutet.") % [hero_name, coins], Lang.t("Klicken für ein neues Spiel"))
	elif has_slot_save():
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
	if level.is_home:
		# Out of the front door of the hero's own house, into the lane.
		player.face(Vector3.BACK)
		player.play("Walking_A")
		var out := create_tween()
		out.tween_property(player, "global_position", level.cell_to_world(level.exit_cell) + Vector3(0, 0, Level.TILE * 0.6), 0.5)
		out.parallel().tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.5)
		out.tween_callback(_next_level)
		if is_instance_valid(pet):
			pet.climb([level.cell_to_world(level.exit_cell) + Vector3(0, 0, Level.TILE * 0.3)], 0.5, 0.1)
		return
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
	# The fox comes up the stairs right behind the hero.
	if is_instance_valid(pet):
		var steps: Array = [foot + Vector3(0, 0, 0.1)]
		for k in range(1, 9):
			steps.append(foot + Vector3(0, 0.5 * k, -0.5 * k + 0.25))
		# Quick on its feet: it gains on the hero, so it is well up the
		# stairs before the next level.
		var dash := clampf(Pet._flat(steps[0] - pet.global_position).length() / Pet.RUN_SPEED, 0.15, 0.6)
		pet.climb(steps, STEP_TIME * 0.75, 0.2, false, dash)
	# Darken while the hero climbs the upper half of the stairs.
	create_tween().tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), STEP_TIME * 5.5) \
			.set_delay(0.15 + STEP_TIME * 3)


func _next_level() -> void:
	if playtest_file != "":
		back_to_editor()
		return
	if level.building != "":
		_leave_building()
		return
	Sfx.play(self, "level_done", -2.0)
	player.train("weisheit", 10.0)
	Training.save_hero(hero_name, player.xp, player.level_data())
	dry_levels = 0 if level.secret_opened() else dry_levels + 1
	if level.building == "" and not level.outdoor:
		level.note_left()
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
	if is_instance_valid(pet):
		# Out of the crypt door behind the hero.
		pet.global_position = start + Vector3(0, 0, -3.2)
		pet._placed = true
		pet.climb([start + Vector3(0.8, 0, -1.4)], 0.0, 0.5, true, 1.3)
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
	if Homes.house_of(hero_name) == 0 and level is Outdoor and not level.town_houses.is_empty():
		Homes.house_for(hero_name, level.town_houses.size())
	home_claimed = true
	home_given = true
	var saved := save_game()
	var text := Lang.t("Dein Haus ist jetzt dein Startpunkt. Spiel gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!")
	get_tree().create_timer(4.2).timeout.connect(func():
		if state == State.PLAYING:
			show_message(text, 3.0))


## Walks in at a village building's door, to its own floor. A town house
## on Weavers' Lane (`house` is its number) only lets in the hero who lives
## there; a hero without a house moves into the first empty one.
func go_inside(building: String, house := 0) -> void:
	if state != State.PLAYING or not interiors.has(building):
		return
	if house > 0 and not _may_enter_house(house):
		return
	inside_house = house
	_home_given_now()
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	if is_instance_valid(pet):
		# Through the door at the hero's heels.
		pet.climb([player.global_position], 0.0, 0.0)
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.5)
	tween.tween_callback(func():
		load_level(interiors[building], false)
		player.frozen = false
		state = State.PLAYING
		create_tween().tween_property(_fade, "color:a", 0.0, 0.6)
		_announce_level()
		if level.pitch_dark:
			_warn_of_darkness()
		if level.is_home and not home_claimed:
			# The first step into the hero's own house makes it home.
			get_tree().create_timer(4.6).timeout.connect(func():
				if state == State.PLAYING:
					show_message(Lang.t("Dein neues Zuhause! Im Bett speicherst du, in der Truhe lagerst du deine Schätze."), 4.0))
			_on_home_claimed())


## The entry from before torches were lit on request: a saved compendium
## gets the new one (see _apply_save).
const OLD_DARK_LEARN := "In manchen Löchern und Höhlen ist es stockfinster: Ohne Fackel siehst du kaum die eigene Hand, und auch mit einer nur wenige Schritte weit. Fackeln gibt es bei der Krämerin. Im Dunkeln brennt eine von selbst, drei Minuten lang, dann die nächste. Eine brennende Fackel sieht jedes Ungeheuer."
const DARK_LEARN := "In manchen Löchern und Höhlen ist es stockfinster: Ohne Fackel siehst du kaum die eigene Hand, und auch mit einer nur wenige Schritte weit. Fackeln gibt es bei der Krämerin. Zünde eine an, wenn du sie brauchst: mit der Fackel am rechten Rand oder der Taste V. Sie brennt drei Minuten lang, bis du sie löschst; was übrig bleibt, brennt beim nächsten Mal weiter. Eine brennende Fackel sieht jedes Ungeheuer."


## Down in a pitch-black place: a word on the darkness, and on torches if
## the hero has none.
func _warn_of_darkness() -> void:
	var here := level
	learn(DARK_LEARN)
	var none: bool = player.torch.left <= 0.0 and player.torch.spare() == 0
	get_tree().create_timer(4.8).timeout.connect(func():
		if level != here or state != State.PLAYING:
			return
		if none:
			show_message(Lang.t("Stockfinster! Ohne Fackel siehst du kaum die eigene Hand. (Die Krämerin verkauft Fackeln.)"), 4.0)
		elif player.torch.lit:
			show_message(Lang.t("Stockfinster. Deine Fackel wirft nur einen kleinen Lichtkreis."), 3.0)
		else:
			show_message(Lang.t("Stockfinster! Zünde eine Fackel an: die Fackel am rechten Rand oder Taste V."), 4.0))


## Whether the hero may go into town house `house`: their own, or an empty
## one while they have none (it becomes theirs). Says why not, if not.
func _may_enter_house(house: int) -> bool:
	var resident := Homes.owner_of(house)
	if resident == Homes.deed_name(hero_name):
		return true
	if resident != "":
		show_message(Lang.t("Hier wohnt %s. Die Tür ist verschlossen.") % resident, 2.5)
		return false
	var mine := Homes.house_of(hero_name)
	if mine > 0:
		show_message(Lang.t("Dieses Haus steht leer. Dein Haus ist Nr. %d.") % mine, 2.5)
		return false
	if not Homes.claim(hero_name, house):
		return false
	get_tree().create_timer(1.6).timeout.connect(func():
		if state == State.PLAYING:
			show_message(Lang.t("Haus Nr. %d gehört jetzt dir! Unten steht die Truhe, oben das Bett, und auf jedem Stockwerk ist Platz für Möbel.") % house, 5.0))
	return true


## The hero walked onto the stairs of their home: up or down a storey.
func _take_stairs(to: Vector3, up: bool, storey: int) -> void:
	if state != State.PLAYING:
		return
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	player.face(Vector3.FORWARD if up else Vector3.BACK)
	player.play("Walking_A")
	if is_instance_valid(pet):
		# Onto the stairs behind the hero.
		pet.climb([player.global_position, player.global_position + Vector3(0, 1.0 if up else -0.6, -0.8 if up else 0.4)], 0.35, 0.1)
	var tween := create_tween()
	tween.tween_property(player, "global_position", player.global_position + Vector3(0, 1.0 if up else -0.6, -0.8 if up else 0.4), 0.45)
	tween.parallel().tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.45)
	tween.parallel().tween_callback(func(): Sfx.play(player, "step_%d" % (randi() % 6), -14.0))
	tween.tween_callback(func():
		player.global_position = to
		player.velocity = Vector3.ZERO
		player.face(Vector3.BACK)
		player.play("Idle")
		if is_instance_valid(pet):
			pet.arrive()
		_snap_camera()
		player.frozen = false
		state = State.PLAYING
		show_message("%s · %s" % [Lang.t("Haus Nr. %d") % level.house_number, level.storey_name(storey)], 2.0))
	tween.tween_property(_fade, "color:a", 0.0, 0.45)


## The banker shows the hero down into the vault cellar.
func go_to_vaults() -> void:
	go_inside("b")


## Down the way in the floor of a mine to its next floor (see Mines). A
## sealed one opens only for a hero who knows both runes.
func _go_down_shaft(s: Dictionary) -> void:
	if not Mines.show_runes(s, lore):
		player.face(s.pos - player.global_position)
		Sfx.play(self, "door", -8.0)
		show_message(Lang.t(Mines.seal_text(lore)), 6.0)
		return
	if s.has("opened"):
		go_inside(s.building)
		return
	s.opened = true
	if level.seal != "" and not taken_here(MINES_SEAL_OPEN):
		# The first time: the slab grinds aside.
		level.taken[MINES_SEAL_OPEN] = true
		_shake = 0.8
		Sfx.play(self, "secret", -2.0)
		show_message(Lang.t("Beide Runen glühen auf, und die Steinplatte schiebt sich knirschend zur Seite. Der Weg in die Tiefe ist frei!"), 5.0)
		return
	go_inside(s.building)


const MINES_SEAL_OPEN := "mines:seal_open"


## Whether something is marked as done on this level (see Level.taken).
func taken_here(key: String) -> bool:
	return level != null and level.taken.has(key)


## Lights the runes the hero knows on every sealed way down of this floor.
func _refresh_seals() -> void:
	for st in level.stations:
		if st.kind == "schacht":
			Mines.show_runes(st, lore)


## Up the stairs of a building floor and out of its door into the village.
## A deeper floor of a mine leads up to the floor above instead, beside the
## way down the hero came by.
func _leave_building() -> void:
	if level.up_to != "" and interiors.has(level.up_to):
		load_level(interiors[level.up_to], false)
		if level.shaft_side != Vector3.ZERO:
			player.global_position = level.shaft_side
			player.face(Vector3.BACK)
		_snap_camera()
		state = State.PLAYING
		create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
		_announce_level()
		return
	var building: String = level.building
	if inside_house > 0:
		building += str(inside_house)
	inside_house = 0
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


## True while the camera may zoom: in play, with no window or shrine open.
func can_zoom() -> bool:
	return state == State.PLAYING and not menus.is_open() and _shrine.is_empty()


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
	_update_quick_bar()
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
	if state == State.PLAYING and level != null and not menus.is_open():
		journal.update(delta)
	_quest_mark_timer -= delta
	if _quest_mark_timer <= 0.0:
		_quest_mark_timer = 0.25
		refresh_quest_marks()
	# The villagers chat with each other while the world runs.
	if level is Outdoor and state == State.PLAYING and not menus.is_open() and level.process_mode != Node.PROCESS_MODE_DISABLED:
		village_talk.update(delta, level)
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
	_place_hp_bar()
	var dust := get_node("Dust") as Node3D
	dust.global_position = player.global_position + Vector3(0, 2.0, 0)
	_steer_by_mouse(delta)
	home_run.tick()
	update_home_button()
	update_torch_button()
	_update_drag(delta)
	_update_run_meter()
	tutorial.update(delta)
	_help.visible = tutorial.pending()
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
	_hints_now.clear()
	var station := level.nearest_station(player.global_position)
	var at_station: bool = not station.is_empty() and (level_index < 2 or station.kind != "schrein")
	# Only the first levels explain how to search; after that players know.
	_prompt.text = ""
	if not at_station and level_index < 2 and not near.is_empty() and not near.searched:
		_prompt.text = _hint("search", Lang.t("Dagegenlaufen, um %s zu untersuchen") % Lang.t(_with_article(near.label)))
	if player.is_seated():
		# Sitting: how to get up again, not how to sit down.
		_prompt.text = _hint("aufstehen", Lang.t("Laufen, klicken oder springen, um aufzustehen"))
	elif at_station and bumped_person and PERSON_STATIONS.has(station.kind):
		# The hero knows by now that running into people talks to them.
		_prompt.text = ""
	elif at_station:
		_prompt.text = _hint(station.kind, {
			"schrein": Lang.t("Dagegenlaufen, um den Schrein zu berühren"),
			"bett": Lang.t("Dagegenlaufen, um dich ins Bett zu legen"),
			"lager": Lang.t("Dagegenlaufen, um die Lagertruhe zu öffnen"),
			"haendler": Lang.t("Dagegenlaufen, um mit %s zu handeln") % station.npc.display_name if station.has("npc") else Lang.t("Dagegenlaufen, um mit dem Händler zu handeln"),
			"brunnen": Lang.t("Dagegenlaufen, um aus dem Brunnen zu trinken"),
			"npc": Lang.t("Dagegenlaufen, um mit %s zu reden") % station.npc.display_name if station.has("npc") else "",
			"bank": Lang.t("Dagegenlaufen, um mit %s zu reden") % station.npc.display_name if station.has("npc") else "",
			"barbier": Lang.t("Dagegenlaufen, um zu %s zu gehen") % station.npc.display_name if station.has("npc") else "",
			"eingang": Lang.t("Dagegenlaufen, um in das dunkle Loch hinabzusteigen") if String(station.get("building", "")).begins_with("loch") else Lang.t("Dagegenlaufen, um %s zu betreten") % Lang.t(station.get("name", "")),
			"tresor": Lang.t("Dagegenlaufen, um dein Schließfach zu öffnen"),
			"aushang": Lang.t("Dagegenlaufen, um den Aushang zu lesen"),
			"steinmetz": Lang.t("Dagegenlaufen, um bei %s Steinblöcke zu kaufen") % station.npc.display_name if station.has("npc") else "",
			"schmied": Lang.t("Dagegenlaufen, um mit %s an der Esse zu arbeiten") % station.npc.display_name if station.has("npc") else "",
			"werkbank": Lang.t(CraftingSquare.bench_of(station.get("craft", "")).get("prompt", "")),
			"wanderhaendler": Lang.t("Dagegenlaufen, um mit %s zu handeln") % station.npc.display_name if station.has("npc") else "",
			"hauswerkbank": Lang.t("Werkbank: Dagegenlaufen, um Wurfmesser zu schmieden oder Ausrüstung zu flicken"),
			"trophaeen": Lang.t("Trophäenwand: Dagegenlaufen, um zu sehen, welche Trophäen du hast und welche noch fehlen (je +1 Leben)"),
			"gefaehrten": Lang.t("Dagegenlaufen, um nach deinen Gefährten zu sehen"),
			"schacht": Lang.t("Dagegenlaufen, um in die Tiefe hinabzusteigen"),
			"tafel": Lang.t("Dagegenlaufen, um die Inschrift zu lesen"),
			Mines.CLUSTER: Lang.t("Abgebaut: Bis zum nächsten Morgen wachsen die Kristalle nach") if station.get("spent", false) else Lang.t("Dagegenlaufen, um Kristalle abzubauen"),
			Seats.KIND: Lang.t("Dagegenlaufen, um dich auf die Bank zu setzen"),
		}.get(station.kind, ""))
	elif _prompt.text == "" and level.crate_in_reach(player) != null:
		_prompt.text = _hint("crate", Lang.t("E oder Klick: Kiste aufheben"))
	elif _prompt.text == "" and _drag_stone != null:
		if _drag_stone.heavy and _drag_spot.get("edge", false):
			# Not a tutorial hint but the reason the block stops: always shown.
			_prompt.text = Lang.t("Weiter geht es nicht: höchstens 5 Felder von seinem Platz")
		elif _drag_stone.heavy:
			_prompt.text = _hint("drag_heavy", Lang.t("Loslassen: Block dorthin   Rechtsklick: drehen"))
		else:
			_prompt.text = _hint("drag", Lang.t("Loslassen: Steinblock dorthin   Rechtsklick: drehen"))
	elif _prompt.text == "" and level.stone_in_reach(player) != null:
		if level.stone_in_reach(player).heavy:
			_prompt.text = _hint("stone_heavy", Lang.t("E oder Klick: Block schieben   Ziehen: verschieben"))
		else:
			_prompt.text = _hint("stone", Lang.t("E oder Klick: Steinblock aufheben   Ziehen: verschieben"))
	# By the water the line can be cast, also next to the fountain.
	var fish_prompt := ""
	if fishing.state == Fishing.BITE:
		fish_prompt = Lang.t("G: Anschlagen!")
	elif fishing.is_fishing():
		fish_prompt = Lang.t("G: Leine einholen")
	elif not fishing.water_near().is_empty():
		fish_prompt = _hint("fish", Lang.t("G: Angeln"))
	if fish_prompt != "":
		_prompt.text = fish_prompt if _prompt.text == "" else _prompt.text + "   " + fish_prompt
	# Next to a monster that can be won over, a gift can be offered.
	var tame := gift_target()
	if tame != null and Factions.can_befriend(Factions.of(tame.kind)) and not tame.is_friend():
		var gift_prompt := _hint("gift", Lang.t("T: Geschenk anbieten"))
		if gift_prompt != "":
			_prompt.text = gift_prompt if _prompt.text == "" else _prompt.text + "   " + gift_prompt
	_count_hints()


## An explanatory hint of one kind ("bett", "search", "fish", ...): shown the
## first HINT_SHOWINGS times the hero comes near such a thing, then left out.
## A hint already on screen stays until the hero walks away.
func _hint(key: String, text: String) -> String:
	if text == "":
		return ""
	if not _hints_last.has(key) and int(hints_shown.get(key, 0)) >= HINT_SHOWINGS:
		return ""
	_hints_now[key] = true
	return text


## Counts each hint that came up this frame and was not on screen before.
func _count_hints() -> void:
	for key in _hints_now:
		if not _hints_last.has(key):
			hints_shown[key] = int(hints_shown.get(key, 0)) + 1
	_hints_last = _hints_now.duplicate()


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
	# Mouse wheel or + and - zoom the camera, but only while no window is open:
	# a list that is already scrolled to its end lets the wheel fall through to
	# here, and the camera behind the window must not move then.
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if event.pressed and can_zoom() and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(event.factor if event.factor > 0.0 else 1.0) if event.button_index == MOUSE_BUTTON_WHEEL_UP else zoom_by(-(event.factor if event.factor > 0.0 else 1.0))
		return
	if event is InputEventKey and event.pressed and can_zoom() and event.physical_keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
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
			if menus.is_open():
				# The load window's (or the overwrite question's) own buttons
				# choose; Esc goes back.
				if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
					menus.close()
				return
			if _name_box.visible or Lang.language == "":
				return
			if has_save() and not (event is InputEventKey and event.physical_keycode == KEY_N):
				continue_game()
			else:
				new_game()
		State.WON:
			new_game()
		State.OVER:
			if has_slot_save() and not (event is InputEventKey and event.physical_keycode == KEY_N):
				continue_game()
			else:
				new_game()
		State.PLAYING:
			if not _shrine.is_empty():
				if event is InputEventKey and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
					_choose_gift(event.physical_keycode - KEY_1)
				return
			if menus.is_open():
				if event is InputEventKey and event.physical_keycode in [KEY_I, KEY_H, KEY_P, KEY_N, KEY_O, KEY_ESCAPE]:
					menus.close()
				return
			# Any key or click of the player's own (but the sound, the menu
			# and the home key itself) calls the way home off.
			if home_run.active and not (event is InputEventKey and event.physical_keycode in [KEY_X, KEY_M, KEY_TAB]):
				home_run.stop()
			if event is InputEventKey:
				match event.physical_keycode:
					KEY_X:
						home_action()
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
					KEY_N:
						if player.can_act():
							menus.open("karte")
					KEY_O:
						if player.can_act():
							menus.open("auftraege")
					KEY_M:
						_toggle_sound()
					KEY_TAB:
						toggle_drawer()
					KEY_C:
						_toggle_sneak()
					KEY_V:
						torch_action()
					KEY_G:
						fish_action()
					KEY_T:
						gift_action()
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
						if playtest_file != "":
							back_to_editor()
						elif player.can_act():
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


## How close the hero must be to a monster to offer it a gift (metres).
const GIFT_RANGE := 5.0
## A monster felled by a rival this close to the hero is reported (metres).
const RIVAL_KILL_HEARD := 30.0


## The nearest living monster close enough for a gift, or null.
func gift_target() -> Enemy:
	if level == null or player == null:
		return null
	var best: Enemy = null
	var best_d := GIFT_RANGE
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead or not e.visible:
			continue
		var d := _reach(e.global_position)
		if d < best_d:
			best = e
			best_d = d
	return best


## Key T or the "Schenken" button: offers the nearest monster what its kind
## likes (see Factions). Each gift calms it for a while and earns its
## faction's favour; enough favour makes the whole faction the hero's friend.
func gift_action() -> void:
	if state != State.PLAYING or menus.is_open() or not _shrine.is_empty() or not player.can_act():
		return
	var e := gift_target()
	if e == null:
		show_message(Lang.t("Hier ist niemand, dem du etwas schenken könntest."), 1.6)
		return
	var faction := Factions.of(e.kind)
	var info: Dictionary = Factions.FACTIONS.get(faction, {})
	if not Factions.can_befriend(faction):
		show_message(Lang.t(info.get("refuse", "Damit ist kein Frieden zu machen.")), 2.2)
		return
	if e.is_friend():
		show_message(Lang.t(info.friend), 1.6)
		return
	var count := int(info.count)
	if info.gift == "gold":
		if coins < count:
			show_message(Lang.t(info.wish), 2.6)
			return
		coins -= count
		Sfx.play_coins(self, count)
	else:
		if crafting.have(info.gift) < count:
			show_message(Lang.t(info.wish), 2.6)
			return
		crafting.add(info.gift, -count)
		Sfx.play(self, "swing", -8.0)
	player.face(e.global_position - player.global_position)
	e.calm()
	var won := Factions.give(faction)
	Effects.float_text(level, e.global_position + Vector3(0, 2.6, 0), Lang.t("Freund!") if won else Lang.t("Danke!"), Color(1.0, 0.6, 0.75))
	if won:
		for other in level.enemies:
			if is_instance_valid(other) and not other.dead and Factions.of(other.kind) == faction:
				other.calm()
		Sfx.play(self, "secret", -6.0)
		learn(Factions.HOW_TO)
		quest_news(Lang.t(info.won), Color(1.0, 0.6, 0.75), 5.0)
	else:
		show_message(Lang.t(info.thanks) + "\n" + Lang.t("Gunst: %d von %d") % [floori(Factions.favour_of(faction)), int(Factions.FRIENDLY)], 3.0)
	_update_hud()


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
			if e.is_friend():
				# The hero's friends are not attacked (see Factions).
				show_message(Lang.t(Factions.FACTIONS[Factions.of(e.kind)].friend), 1.6)
				return
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


# --- Home upgrades (see HomeUpgrades) --------------------------------------

## The ids of a saved list that are still known, as a set.
static func _known_keys(saved, known: Dictionary) -> Dictionary:
	var out := {}
	if saved is Array:
		for id in saved:
			if known.has(str(id)):
				out[str(id)] = true
	return out


## The first foe of a mighty kind gives a trophy for the wall at home.
func _win_trophy(kind: String) -> void:
	if not HomeUpgrades.TROPHIES.has(kind) or trophies.has(kind):
		return
	trophies[kind] = true
	var text := Lang.t("Trophäe: %s") % Lang.t(HomeUpgrades.TROPHIES[kind])
	if HomeUpgrades.has(home_upgrades, "trophaeen"):
		text += "\n" + Lang.t("Sie kommt an die Trophäenwand in deinem Haus: +1 Leben.")
	get_tree().create_timer(2.6).timeout.connect(func():
		if state == State.PLAYING:
			show_message(text, 3.0))
	apply_home_bonus()
	if level.is_home:
		level.show_home_upgrades(home_upgrades, trophies)


## The life the trophy wall gives goes into the hero's stats.
func apply_home_bonus() -> void:
	player.home_hp = HomeUpgrades.trophy_hp(home_upgrades, trophies)
	player.refresh_stats()
	_update_hud()


## Hagen builds an upgrade onto the house: "" when done, else why not.
func build_home_upgrade(id: String) -> String:
	var why := HomeUpgrades.why_not(id, home_upgrades, player.bag, storage, coins)
	if why != "":
		return why
	HomeUpgrades.pay_stones(id, player.bag, storage)
	coins -= int(HomeUpgrades.ALL[id].gold)
	home_upgrades[id] = true
	learn(HomeUpgrades.LEARN)
	apply_home_bonus()
	if level.is_home:
		level.show_home_upgrades(home_upgrades, trophies)
	save_game()
	return ""
