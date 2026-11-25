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
var _graphics_button: Button
var _effects_slider: HSlider
var _log_width_slider: HSlider
## The width of the labels in front of the pull-out menu's sliders, room for
## the longest in both languages ("Protokoll").
const SLIDER_LABEL_WIDTH := 90.0
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
## The blueprint button left of the home button: opens the house building tools
## on the hero's plot (see HouseSketcher.toggle).
var _blueprint_button: Button
## The torch button below it: lights or puts out the hand torch (see HandTorch).
var _torch_button: Button
var _torch_count: Label
## The potion button left of the torch button: drinks a healing potion (see
## HealingPotions), with the potions left in its corner and the cooldown as
## a shade and the seconds over it.
var _potion_button: Button
var _potion_count: Label
var _potion_shade: ColorRect
var _potion_wait: Label
## The spell button (see ArcaneBolt): a star, left of the potion button.
var _spell_button: Button
var _spell_shade: ColorRect
var _spell_wait: Label
var level_files: Array[String] = []
var level_index := 0
var level: Level
var player: Player
var light_shadows: LightShadows
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
## How much water lies in the rain puddles above ground, 0 dry to 1 full
## (see Weather.puddle_water and Puddles).
var puddle_water := 0.0
## How thick the snow lies above ground, 0 bare to 1 deep (see Weather.snow_cover and
## SnowCover). It builds up while it snows and melts again afterwards.
var snow_cover := 0.0
## How thickly the ponds are frozen over, 0 open water to 1 solid ice (see Weather.ice).
var ice_cover := 0.0
var weather_hours := Weather.FIRST_HOURS
var _weather_rng := RandomNumberGenerator.new()
## The look of the sky as it moves towards the weather's own, and a stroke
## of lightning as it fades (1 to 0).
var _weather_look := Weather.look(Weather.CLEAR)
## How far the view is inside a self-built house, 0 out in the open to 1 indoors (see
## HouseGround.shelter): no rain, snow, fog, mist or storm dark is drawn in there.
var _shelter := 0.0
## How long the view takes to move in or out of the weather (real seconds).
const SHELTER_FADE := 0.3
## The household goddess whose blessing the hero has now, inside their own house with her
## shrine ("" elsewhere, see HouseholdGods), and how often that is looked at (seconds).
var house_goddess := ""
var _house_blessing_clock := 0.0
const HOUSE_BLESSING_CHECK := 0.25
## How far the hour must move before the village's lamps, windows and fires are set again (game hours; some 0.2 seconds).
const HOUR_STEP := 0.004
var _flash := 0.0
## The rain that falls and the mist that drifts around the hero (its patter is
## part of the Soundscape).
var _rain: CPUParticles3D
var _mist: CPUParticles3D
var _snow: CPUParticles3D
var _leaves: LeafFall
var _clouds: FogClouds
var _ambience: AudioStreamPlayer
## The ambient soundscape of the place the hero is in (see Soundscape).
var _soundscape: Soundscape
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
## What lies in the steel-banded chest and on the ingredient board of the
## hero's house: store -> kind -> how many (see HomeStores). Kept in the
## saved game.
var home_stores := HomeStores.empty()
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
## The hero's chat line under the event log, and the villagers' answers
## (see ChatLine, HeroChat).
var chat_line := ChatLine.new()
var hero_chat := HeroChat.new(self)
## The card that shows a wall writing the hero noticed (see WritingCard).
var writing_card := WritingCard.new(self)
## How many mornings have dawned in the world above ground since the game
## began. The bounty board pins up fresh hunts each morning (see Bounties).
## The day turns at dawn, so the night after day d's evening, past midnight
## too, still counts as day d: that is when the wandering merchant comes
## (see Wanderer).
var day := 0
## How many season days the seasons are moved on from the real calendar (see Seasons, season_day):
## the sky command's doing, kept in the save.
var season_shift := 0
## The season day the world was last dressed for (see _check_season), SEASON_UNSEEN before the
## first look.
const SEASON_UNSEEN := -1000000000
var _season_seen := SEASON_UNSEEN
## Hours that passed in the world since the game began, sleep included (the
## clock of the floors whose monsters come back, see Level.respawn).
var world_hours := 0.0
## The gold the old dragon's helpers heaped up in its lair, from the loot
## they gather on the open ground at night (see DragonHoard). Kept in the
## saved game.
var hoard := DragonHoard.new()
## What the hero had on stepping through the arch into Embermaw's lair, and
## whether the dragon fell on this visit (see DragonLair and the window
## "beute", which shows the spoils on the way out).
var lair_before := {}
var lair_won_here := false
## What the hero carried out of the won lair (see DragonLair.spoils).
var lair_spoils := {}
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
## Treasure maps from messages in a bottle and where they lead (see TreasureMaps).
var treasure_maps := TreasureMaps.new(self)
## The way home at a press of the home button or X (see HomeRun).
var home_run := HomeRun.new(self)
## What each villager thinks of the hero (see Reputation): discounts,
## gossip and secret recipes. Kept in the saved game.
var reputation := Reputation.new(self)
## Who in the village is tied to whom, and their chats (see VillageTalk).
var village_talk := VillageTalk.new(self)
## What the villagers grumble about: the weather, the night and the frights
## of the world (see VillageWorries).
var village_worries := VillageWorries.new(self)
## Small talk, rumours and stories in the village (see VillageRumours).
var village_rumours := VillageRumours.new(self)
## Fritz's drinking songs at the tavern (see DrinkingSongs).
var drinking_songs := DrinkingSongs.new(self)
## Aldo's practice duel with Odo on the square (see MageDuel).
var mage_duel := MageDuel.new(self)
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
## The floor above each deeper floor (its "up:" line): building -> building.
var floor_above := {}
## The hero's money: copper coins (see Loot.MONEY; the gold coins of old
## were exchanged into them one for one).
var coins := 0
## Iron bars for the smith's forge (see Forge), counted like gold.
var iron := 0
## The fine bars the hero has, by metal ("bronze", "silber", "gold"): melted
## at the forge or taken from the dragon's hoard, bought back by the smith
## (see Forge). Kept in the saved game.
var bars := {}
## Grams of metal melted from ore not yet enough for a bar (see Ore and
## Forge.melt_ore), by metal, the unknown metal too. Kept in the saved game.
var metal_grams := {}
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
## The camp the hero rolled out on this level, if any (see Camp).
var camp: Camp = null
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
## The slimes of the open air while the hero is elsewhere (see
## SlimeGrowth.snapshot). Kept in the saved game, so they stay in the world.
var wild_slimes: Array = []
## Set when wild_slimes was just loaded or cleared: the level being left
## then belongs to the game before, and its slimes are not kept.
var _slimes_fresh := false
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
const PERSON_STATIONS := ["npc", "bank", PlotOffice.KIND, ClimberNpc.KIND, "raumausstatter", "barbier", "tempel", "haendler", "steinmetz", "holzfaeller", "schmied", "wanderhaendler", Mill.KIND, Beekeeper.KIND]
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
## Metres the camera is pulled further back than the zoom says (the blueprint tool uses it
## to fit a big plot on screen, see HouseSketcher.solve_frame).
var frame_pull := 0.0
## The free camera for screenshots (chat: camera:free): its own distance and tilt.
var free_camera := false
var free_pitch := CAMERA_PITCH
var free_distance := CAMERA_DISTANCE

var _hud: CanvasLayer
## The "Game saved" plate in the top right corner (see SaveNotice).
var save_notice: SaveNotice
## Frames per second, CPU and GPU time and ping under it, shown with F1 (see PerfOverlay).
var perf_overlay: PerfOverlay
var _level_label: Label
## The copper coins (the money) on the HUD; the silver and gold coins of the
## purse are counted after it (see _update_purse).
var _coin_label: Label
var _silver_label: Label
var _gold_label: Label
## The coin pictures before the counts, by coin id (see Loot.COINS).
var _coin_icons := {}
var _key_label: Label
## The key's picture before its line: bright once the key is found.
var _key_icon: ItemIcon
var _hp_bar: ProgressBar
var _hp_fill: StyleBoxTexture
## An invisible strip over the slim life bar, a little taller than it, that
## takes the pointer and shows the life in numbers (see _update_hud).
var _hp_hover: Control
## How far the life bar's hover strip reaches above and below the bar, in
## pixels (below it stops short of the ammunition row).
const HP_HOVER_ABOVE := 6.0
const HP_HOVER_BELOW := 4.0
## The hero's passing troubles (bleeding, poison, a curse, burning, slowness) as icons
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
const HP_BAR_SIZE := Vector2(120, 16)
const HP_BAR_Y := 0.68
## How far the hero's arms and blade reach out from the feet, in metres: in
## the normal view the bar sits below all of it (tests/event_log.gd).
const HP_BAR_REACH := 1.8
## The life bar's red, from its lit top to its dark foot (the mock-up's bar).
const HP_REDS := [Color("ff6a4a"), Color("b81c12"), Color("6e0a06")]
## The rim of the HUD's bars, and the heart beside the life bar.
const BAR_RIM := 4
const HEART_SIZE := 24.0
## The coin and key pictures in the purse plate at the top left.
const PURSE_ICON := 22.0
## The run meter: seconds of running left, as a bar and in numbers.
var _run_bar: ProgressBar
var _xp_bar: ProgressBar
## The rows of the run meter and of the experience bar: each takes the
## pointer as a whole (bar and label) for its tooltip.
var _run_row: HBoxContainer
var _xp_row: HBoxContainer
var _xp_label: Label
var _run_label: Label
var _run_fill: StyleBoxTexture
var _shrine_panel: Control
## "Blessings left" line on the shrine panel (beginner dungeon only).
var _shrine_left_label: Label
## The fourth shrine gift, offered only to a wise hero.
var _wise_gift: Button
## The Konstitution gift, whose amount depends on the dungeon.
var _constitution_gift: Button
var _shrine_title: Label
var _shrine_sub: Label
var _gift_buttons: Array[Button] = []
var _shrine: Dictionary = {}
var _pending_station: Dictionary = {}
## Everything the hero has been told so far, for the compendium (key H):
## level hints ("#<index>") and explanatory tips, in the order they came.
var lore: Array = []
## The hero's ammunition (see AMMO) as small icons with their counts, under
## the life bar left of the trouble icons; its count labels by ammo field.
var _ammo_row: HBoxContainer
var _ammo_counts := {}
## Every kind of ammunition shown under the life bar: the Player field that
## counts it, its icon (ItemIcon) and the text of its tooltip. Each has a
## slot of AMMO_SLOT, shown at 0 too (dimmed), so a count changing never
## moves anything.
const AMMO := [
	["knives", "kind:knife", "Wurfmesser griffbereit: %d von %d\nIm Rucksack: %d\nSchaden: %d je Treffer\nZerbricht bei %d%% der Würfe\nWerfen: Taste R oder rechte Maustaste"],
]
const AMMO_SLOT := Vector2(62, 26)
const AMMO_ICON := 20.0
const AMMO_COLOR := Color(0.8, 0.88, 1.0)
## Space between the ammunition and the trouble icons beside it.
const AMMO_GAP := 14.0
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
## The message lines float over the hero's head (see place_message): this
## wide at most, centred over the hero, their lower edge this many pixels
## above the top of the name over the head.
const MESSAGE_WIDTH := 480.0
const MESSAGE_HEAD_GAP := 12.0
## The message lines never rise into the status line at the top of the screen.
const MESSAGE_TOP := 110.0
## Where the messages sit (their lower edge, above the bottom of the screen)
## while there is no hero on screen to float over: the title, a level change.
const MESSAGE_BOTTOM := 175.0
var _fade: ColorRect
var _title: Control
var _title_text: Label
var _title_sub: Label
var _title_prompt: Label
var _message_tween: Tween
var _pending_search := {}
## How long (ms) after a search a chest says nothing when it is searched again (see _search).
const SEARCHED_QUIET := 2500
## A crate the hero was sent to pick up with a click (see Crate).
var _pending_crate: Crate = null
var menus: Menus
## Shows the building plots on the open map and marks out new ones (see Plots).
var plot_marker: PlotMarker
## The blueprint tool on the hero's plot (see HouseSketch).
var house_sketcher: HouseSketcher
## The furniture in the self-built houses and the tool to put it down (see HouseFurnisher).
var house_furnisher: HouseFurnisher
## Playing together with friends (see CoopSession); off unless the player hosts or joins.
var coop: CoopSession
## Items left in the safe room's storage chest, and what the merchant sells.
var storage: Array[String] = []
var shop_stock: Array[String] = []
## What the wandering merchant still has left, and the night he brought it
## for (-1: not rolled yet). A new visit brings new wares (see Wanderer).
var wanderer_stock: Array[String] = []
## What the rock climber still has to sell (id -> how many), the day he last restocked and the hours of
## game time the hero has watched him (see ClimberNpc).
var climber_stock := {}
var climber_day := -1
var climber_watch := 0.0
var wanderer_night := -1
## Finished pieces Gorm has on the shelf, id -> count (see Forge.restock): a few more each morning.
var smith_stock := {}
## The timber the woodcutter has cut and sells (see WoodcutterShift), and the
## seconds he has chopped towards the next piece.
var timber_stock := WoodcutterShift.START
var _timber_carry := 0.0
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
## Hours of reading each book id has given so far (see Offline.BOOK_HOURS).
var book_hours := {}
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
		[bus.climber_watched, _on_climber_watched],
		[bus.gain_shown, show_gain],
		[bus.enemy_slain, Callable(Factions, "on_hero_kill")],
		[bus.enemy_slain, bounties.on_kill],
		[bus.enemy_slain, Callable(MonsterLore, "on_hero_kill")],
		[bus.quest_done, quest_reward],
		[bus.quest_found, quests.start_found],
		[bus.quest_done, reputation.on_quest_done],
		[bus.quest_item_given, update_after_quest],
		[bus.reputation_rose, reputation_rose],
		[bus.gift_paid, _on_gift_paid],
		[bus.traded, reputation.on_trade],
		[bus.map_grew, map_notice],
		[bus.map_explored, map_explored],
		[bus.writing_found, writing_found],
		[bus.trap_spotted, trap_spotted],
		[bus.enemy_engaged, _on_enemy_engaged],
		[bus.enemy_felled, xp_for_kill],
		[bus.quest_done, xp_for_task],
		[bus.bounty_paid, xp_for_bounty],
		[bus.riddle_solved, xp_for_riddle],
		[bus.hero_acted, tutorial.on_hero_acted],
		[bus.hero_acted, home_run.on_hero_acted],
		[bus.camera_punched, punch_camera],
		[bus.loot_found, event_log.add_loot],
		[bus.speech_said, heard],
		[bus.hero_spoke, hero_chat.on_hero_spoke],
		[bus.loot_carried_off, _on_loot_carried_off],
		[bus.scare_happened, village_worries.on_scare],
		[bus.enemy_slain, village_rumours.on_slain],
		[bus.treasure_map_found, treasure_maps.read],
		[bus.village_alarmed, _ring_bell],
		[bus.village_alarmed, _close_villager_window],
		[bus.plot_registered, _clear_plot],
	]


## A plot was registered: the open map clears what reaches into it (see Outdoor.clear_plot).
func _clear_plot(rect: Rect2i) -> void:
	if level is Outdoor:
		(level as Outdoor).clear_plot(rect)


## The warning bell tolls (see Events.village_alarmed, VillageBell).
func _ring_bell(reason: String) -> void:
	VillageBell.ring(self, reason)


## A short jolt of the camera (see Events.camera_punched): it never cuts a
## longer shake that is already running.
func punch_camera(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _enter_tree() -> void:
	for link in _bus_links():
		var heard: Signal = link[0]
		if not heard.is_connected(link[1]):
			heard.connect(link[1])


func _exit_tree() -> void:
	if is_instance_valid(_parked):
		_parked.free()
	for link in _bus_links():
		var heard: Signal = link[0]
		if heard.is_connected(link[1]):
			heard.disconnect(link[1])


func _ready() -> void:
	Lang.setup()
	Cursors.setup()
	# Text that sets no size of its own follows the game's text scale too.
	if get_window().theme == null:
		var base := Theme.new()
		base.default_font_size = UiKit.sized(16)
		get_window().theme = base
	# Only the bodies that move in physics ticks are drawn between ticks (see SmoothMotion).
	SmoothMotion.off_below(get_tree().root)
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
		var building := ""
		var above := ""
		for line in FileAccess.get_file_as_string(level_files[i]).split("\n"):
			if line.begins_with("building:"):
				building = line.substr(9).strip_edges()
				if not interiors.has(building):
					interiors[building] = i
			elif line.begins_with("up:"):
				above = line.substr(3).strip_edges()
		if building != "" and above != "" and not floor_above.has(building):
			floor_above[building] = above
	_setup_world()
	# The event log's width is the player's (the slider in the pull-out menu).
	EventLog.load_settings()
	event_log.use_saved_width()
	_setup_hud()
	tutorial.setup(_hud)
	writing_card.setup(_hud)
	var comic := Comic.new()
	comic.camera = camera
	comic.avoid = func() -> Array[Rect2]:
		var rects := message_rects()
		rects.append_array(hero_hud_rects())
		return rects
	add_child(comic)
	menus = Menus.new()
	add_child(menus)
	horrors = Horrors.new(self)
	add_child(horrors)
	dungeon_sounds = DungeonSounds.new(self)
	add_child(dungeon_sounds)
	Graphics.load_settings()
	Graphics.apply(get_viewport())
	Sfx.load_settings()
	Sfx.watch_focus(self)
	Sfx.click_on_buttons(get_tree())
	_update_sound_button()
	_ambience = Sfx.start_ambience(self)
	_soundscape = Soundscape.new()
	add_child(_soundscape)
	Music.load_settings()
	Music.start(self)
	_update_music_controls()
	menus.setup(self, _hud)
	coop = CoopSession.new()
	coop.game = self
	add_child(coop)
	coop.changed.connect(func(): if menus.current == CoopWindow.KIND: menus._rebuild())
	player = Player.new()
	add_child(player)
	# Walls block the light of the lamps near the hero (see LightShadows).
	light_shadows = LightShadows.new()
	light_shadows.focus = player
	add_child(light_shadows)
	player.set_display_name(hero_name)
	# The hand torch speaks through the message line (see HandTorch).
	player.torch.notice.connect(func(text: String, duration: float):
		if state == State.PLAYING:
			show_message(text, duration))
	player.hurt.connect(_on_player_hurt)
	player.leveled_up.connect(_on_leveled_up)
	player.ailments_changed.connect(_update_hud)
	player.regenerated.connect(_update_hud)
	player.knives_settled.connect(_update_hud)
	player.defeated.connect(_on_player_defeated)
	player.bumped.connect(_on_player_bumped)
	player.trained.connect(_on_player_trained)
	if playtest_file != "":
		_start_playtest()
		return
	if defers_start_level():
		_rest_hero()
	else:
		load_level(_start_level())
	_show_start_title("Escape!", Lang.t("Entkomme aus dem Verlies"))
	# The village gets ready behind the title, so the crypt door is quick later.
	WorldPreload.start(self)
	LoadingScreen.start(_hud, self)
	if Engine.has_meta(ASK_NAME_FLAG):
		# A language was just chosen: no extra click, the hero's name comes next.
		Engine.remove_meta(ASK_NAME_FLAG)
		new_game()


## Whether the first level waits until a game really starts ("New", or a saved game's own level)
## instead of being built behind the title. Always, where a window is drawn; headless (the tests)
## the level is there at once, unless a test asks for the real thing with `lazy_start`.
static var lazy_start := false


func defers_start_level() -> bool:
	return lazy_start or DisplayServer.get_name() != "headless"


## The hero waits out of the world while no level is loaded: unseen, and nothing of them runs.
func _rest_hero() -> void:
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED


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
	# A lifted roof (see LightShadows.lift) still casts its shadow: no sun or moon shines into a
	# house while the hero looks in from behind it or stands inside.
	moon.shadow_caster_mask = 0xFFFFF | LightShadows.LID_LAYER
	# Shadows reach all the way to the camera's far plane, so the mountains'
	# shadows are always fully drawn instead of building up (or fading in)
	# as the hero walks towards them. The camera hangs about 27 m from the hero, so the
	# first ring reaches past everything around the hero (46 m): a prop on the hero's
	# side of a ring edge used to be shaded differently from one on the other side, and
	# a bench flipped between the two as the hero walked past it. Only the far ring is wide.
	# Two rings, not four: every ring draws the shadow casters in it once more each
	# frame. The first covers all the usual view; the second, coarser, only the far
	# land seen when zoomed in close.
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 200.0
	moon.directional_shadow_fade_start = 1.0
	moon.directional_shadow_split_1 = 0.23
	# Blend the rings so no hard edge of shade sweeps over the props as the hero walks.
	moon.directional_shadow_blend_splits = true
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
	_snow = Weather.make_snow()
	add_child(_snow)
	_leaves = Weather.make_leaves()
	add_child(_leaves)
	_clouds = FogClouds.new()
	add_child(_clouds)


## How strong the faint light from above is down in the dungeon.
const DUNGEON_MOON := 0.28

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
			player.set_dark(1.0)
		_env.background_color = Color(0, 0, 0)
		_env.ambient_light_color = Color(0.42, 0.40, 0.37)
		_env.ambient_light_energy = 0.3
		_env.adjustment_saturation = 1.0
		_moon.rotation_degrees = Vector3(-62, 28, 0)
		_moon.light_color = Color(0.82, 0.84, 0.9)
		_moon.light_energy = Graphics.sun(DUNGEON_MOON)
	# No dripping cave water under the open sky.
	if _ambience:
		# A floor with a loop of its own (see Soundscape) lets the old cave air rest.
		_ambience.volume_db = -30.0 if outdoor else (-80.0 if Soundscape.covers_dungeon(level) else -8.0)


## A label with outline and shadow (see UiKit.label).
static func _make_label(font: Font, size: int, color := Color.WHITE) -> Label:
	return UiKit.label(font, UiKit.sized(size), color)


## Every button of the game, in one look (see UiKit.button).
static func _make_button(text: String, action: Callable, on_press := false) -> Button:
	var b := UiKit.button(text, action, on_press)
	b.add_theme_font_size_override("font_size", UiKit.sized(b.get_theme_font_size("font_size")))
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

	_drawer_handle = _make_button("", toggle_drawer, true)
	# 88 high: room for the arrow and "Menü", and for the home and torch
	# buttons below it between the gold line and the corner mark on a 720 px
	# screen (see _setup_torch_button).
	_drawer_handle.custom_minimum_size = Vector2(70, 88)
	_drawer_handle.add_theme_font_size_override("font_size", UiKit.sized(16))
	_drawer_handle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: BronzeStyle = _drawer_handle.get_theme_stylebox(style).duplicate()
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
	_setup_blueprint_button()
	_setup_torch_button()
	_setup_potion_button()
	_setup_spell_button()

	var panel := PanelContainer.new()
	var back := BronzeStyle.new()
	back.bg_color = UiKit.PANEL_BG
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
	var windows := [["Laden", "laden"], ["Fertigkeiten", "fertigkeiten"], ["Mitspielen", CoopWindow.KIND]]
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
	buttons.add_child(_make_button(Lang.t("Land"), plot_action, true))
	buttons.add_child(_make_button(Lang.t("Angeln"), fish_action, true))
	buttons.add_child(_make_button(Lang.t("Schenken"), gift_action, true))
	buttons.add_child(_make_button(Lang.t("Lager"), _camp_from_drawer, true))
	_sound_button = _make_button("", _toggle_sound, true)
	buttons.add_child(_sound_button)
	_update_sound_button()
	_music_button = _make_button("", _toggle_music, true)
	buttons.add_child(_music_button)
	buttons.add_child(_make_button(Lang.t("Beenden"), do_quit, true))
	for b in buttons.get_children():
		b.custom_minimum_size = Vector2(150, 58)
		b.add_theme_font_size_override("font_size", UiKit.sized(18))
	column.add_child(_make_music_slider())
	column.add_child(_make_effects_slider())
	column.add_child(_make_log_width_slider())
	column.add_child(_make_graphics_row())
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
	["charakter", "Charakter", "P", "kind:stats"],
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
			var box: BronzeStyle = b.get_theme_stylebox(style).duplicate()
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
		var box: BronzeStyle = _home_button.get_theme_stylebox(style).duplicate()
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


## The blueprint button stands left of the home button, on the same line and as
## big, outside the rail so the rail keeps its height (like the potion button
## beside the torch): a blue sheet with a floor plan. It shows while the hero
## stands on their plot or near it, and stays pressed while the blueprint or the
## furnishing tool is open; a press opens the blueprint tool or closes the open
## tool. Its place is kept while it is hidden, so nothing moves.
func _setup_blueprint_button() -> void:
	var slot: Control = _home_button.get_parent()
	_blueprint_button = _make_button("", blueprint_action)
	_blueprint_button.custom_minimum_size = QUICK_SIZE
	_blueprint_button.toggle_mode = true
	_blueprint_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_blueprint_button.position = Vector2(-QUICK_SIZE.x - QUICK_GAP, 0)
	_blueprint_button.size = QUICK_SIZE
	_blueprint_button.tooltip_text = Lang.t("Hausbau: Bauplan und Einrichten")
	var icon := ItemIcon.make("kind:blueprint", QUICK_ICON, true)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -QUICK_ICON / 2.0
	icon.offset_top = -QUICK_ICON / 2.0
	icon.offset_right = QUICK_ICON / 2.0
	icon.offset_bottom = QUICK_ICON / 2.0
	_blueprint_button.add_child(icon)
	_blueprint_button.visible = false
	slot.add_child(_blueprint_button)


## The blueprint button: opens the blueprint tool on the hero's plot, or closes
## the building tool that is open.
func blueprint_action() -> void:
	if state != State.PLAYING or house_sketcher == null or menus.is_open():
		update_blueprint_button()
		return
	var why := house_sketcher.toggle()
	if why != "":
		show_message(why, 2.4)
	update_blueprint_button()


## Shows the blueprint button on or near the hero's plot, pressed while a
## building tool is open.
func update_blueprint_button() -> void:
	if _blueprint_button == null:
		return
	var show := house_sketcher != null and house_sketcher.can_show()
	if _blueprint_button.visible != show:
		_blueprint_button.visible = show
	var open := house_sketcher != null and (house_sketcher.active or (house_furnisher != null and house_furnisher.active))
	if _blueprint_button.button_pressed != open:
		_blueprint_button.set_pressed_no_signal(open)


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
		var box: BronzeStyle = _torch_button.get_theme_stylebox(style).duplicate()
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


## The potion button stands left of the torch button, on the same line and
## as big, outside the rail so the rail keeps its height: a red flask, the
## potions left in the bag in its corner. After a potion it is shaded from
## the top, the shade draining away over the minute until the next one may
## be drunk, with the seconds left in its middle. It shows while the hero
## carries a potion; its place is outside the rail, so nothing moves.
func _setup_potion_button() -> void:
	var slot: Control = _torch_button.get_parent()
	_potion_button = _make_button("", potion_action)
	_potion_button.custom_minimum_size = QUICK_SIZE
	_potion_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_potion_button.position = Vector2(-QUICK_SIZE.x - QUICK_GAP, 0)
	_potion_button.size = QUICK_SIZE
	_potion_button.tooltip_text = Lang.t("%s (Taste %s)") % [Lang.t("Heiltrank trinken"), "1"]
	var icon := ItemIcon.make("kind:heal_potion", QUICK_ICON, true)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -QUICK_ICON / 2.0
	icon.offset_top = -QUICK_ICON / 2.0
	icon.offset_right = QUICK_ICON / 2.0
	icon.offset_bottom = QUICK_ICON / 2.0
	_potion_button.add_child(icon)
	# The cooldown: a dark shade from the top, as tall as the share of the
	# minute still to wait, inside the button's rounded frame.
	_potion_shade = ColorRect.new()
	_potion_shade.color = Color(0.0, 0.0, 0.0, 0.62)
	_potion_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_potion_shade.anchor_right = 1.0
	_potion_shade.offset_left = 3
	_potion_shade.offset_right = -3
	_potion_shade.offset_top = 3
	_potion_shade.visible = false
	_potion_button.add_child(_potion_shade)
	_potion_wait = _make_label(TEXT_FONT, 18)
	_potion_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_potion_wait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_potion_wait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_potion_button.add_child(_potion_wait)
	# The count sits in a fixed box in the lower right corner, like the
	# torches', so a change from 9 to 10 does not move it.
	_potion_count = _make_label(TEXT_FONT, 16)
	_potion_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_potion_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_potion_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_potion_count.offset_right = -6
	_potion_count.offset_bottom = -1
	_potion_button.add_child(_potion_count)
	_potion_button.visible = false
	slot.add_child(_potion_button)


## The spell button stands left of the potion button, on the same line and
## as big: a violet star. It shows once the hero knows the spell from the
## tome of Sternhall (see ArcaneBolt). After a cast it is shaded from the top
## like the potion button, with the seconds left in its middle. Its place is
## kept outside the rail, so nothing moves when it appears.
func _setup_spell_button() -> void:
	var slot: Control = _torch_button.get_parent()
	_spell_button = _make_button("", spell_action)
	_spell_button.custom_minimum_size = QUICK_SIZE
	_spell_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_spell_button.position = Vector2(-2.0 * (QUICK_SIZE.x + QUICK_GAP), 0)
	_spell_button.size = QUICK_SIZE
	_spell_button.tooltip_text = Lang.t("%s (Taste %s)") % [Lang.t("Entfesselte Kraft wirken"), "2"]
	var icon := ItemIcon.make("kind:arcane", QUICK_ICON, true)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -QUICK_ICON / 2.0
	icon.offset_top = -QUICK_ICON / 2.0
	icon.offset_right = QUICK_ICON / 2.0
	icon.offset_bottom = QUICK_ICON / 2.0
	_spell_button.add_child(icon)
	_spell_shade = ColorRect.new()
	_spell_shade.color = Color(0.0, 0.0, 0.0, 0.62)
	_spell_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_shade.anchor_right = 1.0
	_spell_shade.offset_left = 3
	_spell_shade.offset_right = -3
	_spell_shade.offset_top = 3
	_spell_shade.visible = false
	_spell_button.add_child(_spell_shade)
	_spell_wait = _make_label(TEXT_FONT, 18)
	_spell_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spell_wait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spell_wait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spell_button.add_child(_spell_wait)
	_spell_button.visible = false
	slot.add_child(_spell_button)


## Whether the hero learned the spell from the tome of Sternhall.
func knows_spell() -> bool:
	return lore.has(SternHall.SPELL_LORE)


## The spell button or 2: casts the arcane bolt at the nearest foe.
func spell_action() -> void:
	if state != State.PLAYING or player == null or not knows_spell():
		return
	var why := ArcaneBolt.cast(player)
	if why != "":
		show_message(why, 2.0)
	update_spell_button()


## Shows the spell button once the spell is known, shaded while the power
## gathers again.
func update_spell_button() -> void:
	if _spell_button == null or player == null:
		return
	var known := knows_spell()
	if _spell_button.visible != known:
		_spell_button.visible = known
	if not known:
		return
	var waiting := player.spell_wait > 0.0
	if _spell_shade.visible != waiting:
		_spell_shade.visible = waiting
	if waiting:
		var inner := QUICK_SIZE.y - 6.0
		_spell_shade.offset_bottom = 3.0 + inner * player.spell_wait / ArcaneBolt.COOLDOWN
	var wait := str(ceili(player.spell_wait)) if waiting else ""
	if _spell_wait.text != wait:
		_spell_wait.text = wait


## Drinks a healing potion from the bag (the strongest, or the one named).
## Returns "" when it worked, else why not.
func drink_potion(id := "") -> String:
	if state != State.PLAYING or player == null:
		return ""
	var why: String = player.potions.drink(id)
	if why == "":
		Events.teach(HealingPotions.LEARN)
		_update_hud()
	update_potion_button()
	return why


## The potion button or 1: drinks the strongest potion in the bag.
func potion_action() -> void:
	var why := drink_potion()
	if why != "":
		show_message(why, 2.4)


## Shows the potion button while the hero carries a potion, with the count
## and, after a potion, the shade and the seconds until the next one.
func update_potion_button() -> void:
	if _potion_button == null or player == null:
		return
	var potions: HealingPotions = player.potions
	var count := potions.carried()
	if _potion_button.visible != (count > 0):
		_potion_button.visible = count > 0
	var text := str(count) if count > 0 else ""
	if _potion_count.text != text:
		_potion_count.text = text
	var waiting := potions.cooldown > 0.0
	if _potion_shade.visible != waiting:
		_potion_shade.visible = waiting
	if waiting:
		var inner := QUICK_SIZE.y - 6.0
		_potion_shade.offset_bottom = 3.0 + inner * potions.cooldown / HealingPotions.COOLDOWN
	var wait := str(ceili(potions.cooldown)) if waiting else ""
	if _potion_wait.text != wait:
		_potion_wait.text = wait


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
	var box := BronzeStyle.new()
	box.bg_color = Color(UiKit.PANEL_BG, 0.96)
	box.border_color = Color(0.85, 0.66, 0.32, 0.8)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	theme.set_stylebox("panel", "TooltipPanel", box)
	theme.set_font("font", "TooltipLabel", TEXT_FONT)
	theme.set_font_size("font_size", "TooltipLabel", UiKit.sized(16))
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


## How far the status block, the coin plate and the event log sit from the
## screen's left and top edges.
const HUD_EDGE := 16


## A bar's rim is laid just around it, outside its box: this moves the bar in
## by the rim's width so the rim, not the bar, lines up with the plate, the
## icon rows and the event log below.
func _rim_indent(bar: Control) -> Control:
	var holder := MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_theme_constant_override("margin_left", BAR_RIM)
	holder.add_child(bar)
	return holder


func _setup_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		top.add_theme_constant_override("margin_" + side, HUD_EDGE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Every HUD value explains itself on hover, in the house tooltip style.
	var tips := _tooltip_theme()
	top.theme = tips
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
	# Life as a bar under the hero's feet, its fill the share of life left,
	# MMO-style: a glossy red in a bronze rim, a heart at its left end. It
	# has one fixed size, so nothing moves as life changes.
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = HP_BAR_SIZE
	_hp_bar.size = HP_BAR_SIZE
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill = bar_fill(HP_REDS)
	_hp_bar.add_theme_stylebox_override("background", bar_back())
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	_hp_bar.add_child(bar_rim())
	var heart := ItemIcon.make("kind:heart", HEART_SIZE, true)
	heart.position = Vector2(-HEART_SIZE + 4.0, (HP_BAR_SIZE.y - HEART_SIZE) / 2.0)
	_hp_bar.add_child(heart)
	_hp_bar.visible = false
	_hp_bar.theme = tips
	_hud.add_child(_hp_bar)
	# The bar is only a few pixels high: a taller strip over it takes the
	# pointer, so its tooltip is easy to reach.
	_hp_hover = Control.new()
	_hp_hover.mouse_filter = Control.MOUSE_FILTER_PASS
	_hp_hover.position = Vector2(0, -HP_HOVER_ABOVE)
	_hp_hover.size = Vector2(HP_BAR_SIZE.x, HP_BAR_SIZE.y + HP_HOVER_ABOVE + HP_HOVER_BELOW)
	_hp_bar.add_child(_hp_hover)
	# The hero's passing troubles (poison, a curse, burning, slowness) as
	# little red-framed icons in a row under the bar, where the eye is during
	# a fight, in a fixed order from its left edge, so an icon coming or
	# going never moves the others before it. Boons go to the status block
	# at the top left (_boon_row).
	_status_row = HBoxContainer.new()
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.add_theme_constant_override("separation", 4)
	_status_row.theme = tips
	_hud.add_child(_status_row)
	_ammo_row = HBoxContainer.new()
	_ammo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_row.add_theme_constant_override("separation", 0)
	_ammo_row.theme = tips
	_hud.add_child(_ammo_row)
	for ammo in AMMO:
		var slot := Control.new()
		slot.custom_minimum_size = AMMO_SLOT
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		_ammo_row.add_child(slot)
		# A dark tile like the trouble icons', framed in steel blue (the
		# colour of the count), so it reads on any floor.
		var tile := Panel.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.size = Vector2(AMMO_SLOT.y, AMMO_SLOT.y)
		var box := BronzeStyle.new()
		box.bg_color = StatusIcon.TILE
		box.border_color = AMMO_COLOR
		box.set_border_width_all(2)
		tile.add_theme_stylebox_override("panel", box)
		slot.add_child(tile)
		var icon := ItemIcon.make(ammo[1], AMMO_ICON, true)
		icon.position = Vector2((AMMO_SLOT.y - AMMO_ICON) / 2.0, (AMMO_SLOT.y - AMMO_ICON) / 2.0)
		tile.add_child(icon)
		var count := _make_label(TEXT_FONT, 18, AMMO_COLOR)
		count.position = Vector2(AMMO_SLOT.y + 5, 0)
		count.size = Vector2(AMMO_SLOT.x - AMMO_SLOT.y - 5, AMMO_SLOT.y)
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(count)
		_ammo_counts[ammo[0]] = count
	var run_row := HBoxContainer.new()
	run_row.mouse_filter = Control.MOUSE_FILTER_PASS
	run_row.add_theme_constant_override("separation", 10)
	left.add_child(run_row)
	_run_row = run_row
	_run_bar = ProgressBar.new()
	_run_bar.show_percentage = false
	_run_bar.custom_minimum_size = Vector2(170, 14)
	_run_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_run_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_fill = bar_fill([Color.WHITE, Color(0.72, 0.72, 0.72), Color(0.42, 0.42, 0.42)])
	_run_bar.add_theme_stylebox_override("background", bar_back())
	_run_bar.add_theme_stylebox_override("fill", _run_fill)
	_run_bar.add_child(bar_rim())
	run_row.add_child(_rim_indent(_run_bar))
	_run_label = _make_label(TEXT_FONT, 18, Color(0.75, 0.95, 0.6))
	run_row.add_child(_run_label)
	# The hero's level beside a bar of the experience towards the next one,
	# built like the run bar above it.
	var xp_row := HBoxContainer.new()
	xp_row.mouse_filter = Control.MOUSE_FILTER_PASS
	xp_row.add_theme_constant_override("separation", 10)
	left.add_child(xp_row)
	_xp_row = xp_row
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(170, 14)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar.add_theme_stylebox_override("background", bar_back())
	_xp_bar.add_theme_stylebox_override("fill", bar_fill([Color("ffe58a"), Color("e0b33a"), Color("a87a18")]))
	_xp_bar.add_child(bar_rim())
	xp_row.add_child(_rim_indent(_xp_bar))
	_xp_label = _make_label(TEXT_FONT, 18, XP_COLOR)
	xp_row.add_child(_xp_label)
	# The gold (first, on the left edge) and the key (in a dungeon) on one line
	# under the experience bar, in the bars' label size. (Ammunition sits under
	# the life bar.)
	# They sit in a small bronze-framed plate, each after its picture.
	var purse_plate := PanelContainer.new()
	purse_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var plate := UiKit.frame_style(Color(0.09, 0.066, 0.047, 0.92), UiKit.BRONZE, BAR_RIM, 6)
	plate.content_margin_left = 12
	plate.content_margin_right = 14
	plate.content_margin_top = 4
	plate.content_margin_bottom = 4
	purse_plate.add_theme_stylebox_override("panel", plate)
	left.add_child(purse_plate)
	var purse_row := HBoxContainer.new()
	purse_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse_row.add_theme_constant_override("separation", 4)
	purse_plate.add_child(purse_row)
	# A copper, a silver and a gold coin, each with its count right after it:
	# the picture sits closer to its own count than to the next coin.
	var counts := {}
	for id in PURSE_COINS:
		if not counts.is_empty():
			purse_row.add_child(_purse_gap(10))
		var icon := ItemIcon.make(id, PURSE_ICON, true)
		_coin_icons[id] = icon
		purse_row.add_child(icon)
		var count := _make_label(TEXT_FONT, 18, Loot.COIN_COLORS[id].lerp(Color.WHITE, 0.3))
		count.mouse_filter = Control.MOUSE_FILTER_PASS
		purse_row.add_child(count)
		counts[id] = count
	_coin_label = counts[Loot.MONEY]
	_silver_label = counts["silbermuenze"]
	_gold_label = counts["goldmuenze"]
	purse_row.add_child(_purse_gap(18))
	_key_icon = ItemIcon.make("kind:key", PURSE_ICON, true)
	purse_row.add_child(_key_icon)
	_key_label = _make_label(TEXT_FONT, 18)
	_key_label.mouse_filter = Control.MOUSE_FILTER_PASS
	purse_row.add_child(_key_label)
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

	# The message lines: the newest one sits just over the hero's head, and
	# the ones before it, while still unread, above it. The box grows
	# upwards, so no line can ever cover another (see place_message).
	_message_box = VBoxContainer.new()
	_message_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_message_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_box.add_theme_constant_override("separation", MESSAGE_GAP)
	_hud.add_child(_message_box)
	_message = _message_line()
	_message_box.add_child(_message)

	# The keys at the bottom left help while the first steps are learned in
	# the beginner dungeon; after that, or outside it, they go, to keep the
	# screen clear (all keys are in the compendium, H).
	var help := _make_label(TEXT_FONT, 15, Color(1, 1, 1, 0.8))
	_help = help
	help.text = Lang.t("WASD: laufen   Leertaste: springen   F: Schlag   R: Messer   V: Fackel   M: Ton\nI: Inventar   H: Kompendium   P: Charakter   L: Laden   C/Doppelklick: schleichen   Dagegenlaufen: benutzen   Tab: Menü\nMaus: Klick gehen, halten rennen (Umschalt), Rechtsklick: Messer (im Lauf: Sprung)")
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_left = 24
	help.offset_bottom = -26
	_hud.add_child(help)

	_hud.add_child(event_log)
	_setup_chat_line()

	# The words of Fritz's drinking songs over his head, under the rest of
	# the HUD (see SongSheet).
	var sheet := SongSheet.new()
	sheet.game = self
	sheet.camera = camera
	sheet.live = func() -> bool: return level is Outdoor and menus != null and not menus.is_open()
	_hud.add_child(sheet)
	_hud.move_child(sheet, 0)
	drinking_songs.sheet = sheet

	var version := _make_label(TEXT_FONT, 14, Color(1, 1, 1, 0.4))
	version.text = _version_text()
	version.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.grow_horizontal = Control.GROW_DIRECTION_BOTH
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_bottom = -4
	_hud.add_child(version)

	# The new "db" logo (the app icon's 1024 px master, with mipmaps so it stays sharp at every
	# window size) as a faint watermark in the corner.
	var mark := TextureRect.new()
	mark.texture = preload("res://assets/logo/app_icon_1024.png")
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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

	save_notice = SaveNotice.new()
	add_child(save_notice)
	perf_overlay = PerfOverlay.new()
	perf_overlay.ping_source = func() -> int: return coop.client.ping_ms() if coop != null and coop.client != null else -1
	add_child(perf_overlay)

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
	var style := BronzeStyle.new()
	style.bg_color = UiKit.PANEL_BG
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
	_shrine_title = title
	var sub := _make_label(TEXT_FONT, 22)
	sub.text = Lang.t("Wähle eine Gabe")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	_shrine_sub = sub
	_shrine_left_label = _make_label(TEXT_FONT, 18, Color(0.65, 0.85, 1.0))
	_shrine_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_shrine_left_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var gifts := [Lang.t("+5 Leben"), Lang.t("+1 Attributpunkt"), Lang.t("+1 Konstitution")]
	for i in gifts.size():
		var b := _make_button(Lang.t("%s\n(Taste %d)") % [gifts[i], i + 1], _choose_gift.bind(i))
		b.custom_minimum_size = Vector2(200, 96)
		row.add_child(b)
		_gift_buttons.append(b)
		if i == 2:
			_constitution_gift = b
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
	var busy: bool = s.has("npc") and (s.npc.is_busy_talking() or village_rumours.is_telling(s.npc))
	if s.kind == "npc":
		player.face(s.pos - player.global_position)
		player.play("Idle")
		# Frozen solid, Fritz takes no quest, gossip or news: he only mumbles and stays as he is.
		if s.npc.is_frozen():
			if not busy:
				s.npc.talk(player)
		elif not busy and not quests.talk(s.npc) and not crafting.talk(s.npc) and not wishes.talk(s.npc) and not reputation.tell_secret(s.npc) and not reputation.gossip(s.npc) and not village_rumours.tell(s.npc):
			s.npc.talk(player)
	elif s.kind == "eingang":
		go_inside(s.building, s.get("house", 0), s.get("leaf"))
	elif s.kind == TreasureMaps.DIG or s.kind == TreasureMaps.BOULDER:
		treasure_maps.use(s)
	elif s.kind == SpringCave.KIND or s.kind == SpringCave.PLUG:
		SpringCave.use(self, s)
	elif s.kind == "schacht":
		_go_down_shaft(s)
	elif s.kind == SternHall.DRAIN:
		_climb_out_of_drain()
	elif SternHall.KINDS.has(s.kind) and level.stern:
		level.stern.use(s, player)
	elif s.kind in [AshSpire.BOOK, AshSpire.CACHE, AshSpire.ANVIL, AshSpire.HATCH, AshSpire.PRISONER]:
		AshSpire.use(self, s)
	elif LostMine.KINDS.has(s.kind):
		LostMine.use(self, s)
	elif s.kind == Sewers.KIND_LID:
		Sewers.use(self, s)
	elif Spooknortz.KINDS.has(s.kind):
		Spooknortz.use(self, s)
	elif s.kind == "figur":
		# A person made in the map workshop (see DungeonNpc).
		player.face(s.pos - player.global_position)
		player.play("Idle")
		bumped_person = true
		s.figure.talk(player)
	elif s.kind == "hort":
		player.face(s.pos - player.global_position)
		player.play("Idle")
		var held := hoard_coins()
		level.show_hoard(held)
		house_furnisher.refresh_hoards()
		show_message(HomeHoard.describe(HomeHoard.stage_of(HomeHoard.wealth(held.kupfermuenze, held.silbermuenze, held.goldmuenze)), held), 3.5, GOLD)
	elif s.kind == VillageWall.GATE_STATION:
		player.face(s.pos - player.global_position)
		if s.gate.let_through(player):
			Sfx.play(self, "swing", -6.0)
			show_message(Lang.t(VillageWall.PASS_LINE), 2.4)
	elif s.kind == "tafel":
		player.face(s.pos - player.global_position)
		player.play("Idle")
		Events.bus().writing_found.emit(s.text)
		_refresh_seals()
	elif s.kind == Mines.CLUSTER:
		_mine_crystals(s)
	elif s.kind == SilverSilk.KIND:
		_harvest_silk(s)
	elif s.kind == QuarryRocks.KIND:
		_break_stone(s)
	elif s.kind == WoodLogs.KIND:
		_chop_wood(s)
	elif s.kind == SummitGarden.SPRING_KIND:
		SummitGarden.drink(self, s)
	elif s.has("npc") and _villager_unavailable(s):
		pass
	elif s.has("npc"):
		# A villager who trades: a word, then the goods. A task handed out or
		# finished comes first; the goods wait until the next time. While the
		# last line still shows, the goods open without a new word.
		# The priestess still hands out her recipe and listens to wishes, like
		# any villager, before her temple window opens.
		var temple: bool = s.kind == "tempel"
		if not busy and (quests.talk(s.npc, true) or reputation.tell_secret(s.npc) or (temple and (crafting.talk(s.npc) or wishes.talk(s.npc)))):
			player.face(s.pos - player.global_position)
			player.play("Idle")
			return
		if not busy and not reputation.gossip(s.npc) and not village_rumours.tell(s.npc, true):
			s.npc.talk(player)
		player.face(s.pos - player.global_position)
		trader_role = s.npc.role
		menus.open(s.kind)
	elif s.kind == "schrein":
		_open_shrine(s)
	elif s.kind == WarHorn.KIND:
		# The hero walks round to the mouthpiece and blows (see HornBlow); the
		# villagers gather at the first blast.
		var why := WarHorn.hero_cannot()
		if why != "":
			player.face(s.pos - player.global_position)
			show_message(why, 3.0)
		else:
			player.blow_horn(WarHorn.hero_blow(level as Outdoor, player.global_position, func(text: String): show_message(text, 3.0)))
	elif s.kind == "brunnen":
		# Pushing on against the fountain drinks one sip at a time.
		if not belly_sips.still_drinking(_clock_now()):
			_drink(s)
	elif s.kind == GardenDecor.GRILL:
		player.face(s.pos - player.global_position)
		GardenDecor.grill(self)
	elif s.kind == AppleTree.STATION:
		player.face(s.pos - player.global_position)
		AppleTree.pick(self, s)
	elif s.kind == ValleyEvents.KIND:
		player.face(s.pos - player.global_position)
		if level is Outdoor and level.valley_events != null:
			level.valley_events.help(s.what)
	elif s.kind == HouseFurniture.CANDLE_STATION:
		player.face(s.pos - player.global_position)
		house_furnisher.toggle_candles(s)
	elif s.kind == Seats.KIND and level is Outdoor and level.bench_rest.taken(s):
		# Someone from the village rests there already (see BenchRest).
		player.face(s.pos - player.global_position)
		var taken_text := Lang.t("Auf dieser Bank sitzt schon jemand.")
		# Once per push against it, not every bump of a held key.
		if _message.text != taken_text or _message.modulate.a < 0.05:
			show_message(taken_text, read_time(taken_text))
	elif s.kind == Seats.KIND:
		player.sit_down(Seats.sit_spot(s), Seats.front(s), Seats.stand_spot(s, level, player.radius))
	else:
		player.face(s.pos - player.global_position)
		menus.bench = s.get("craft", "")
		menus.open(s.kind)


## A villager whose window must not open now (alarm, or away from their post, see
## VillagerPost): they say a short line instead. True when the window stays shut.
func _villager_unavailable(s: Dictionary) -> bool:
	var line := VillagerPost.for_station(level, s)
	if line == "":
		return false
	player.face(s.pos - player.global_position)
	player.play("Idle")
	# A keeper away from their hall still hands out or takes back a task (and tells a secret)
	# before sending the hero to the hall for the goods (see VillagerPost.HALL_LINES).
	if VillagerPost.is_hall_line(line) and not s.npc.is_busy_talking() and (quests.talk(s.npc, true) or reputation.tell_secret(s.npc)):
		return true
	if not s.npc.is_busy_talking():
		s.npc.say(Lang.t(line), player.global_position)
	return true


## The village is in danger: a villager's window that is open closes (see _bus_links).
func _close_villager_window(_reason: String) -> void:
	if trader_role != "" and menus != null and menus.is_open():
		menus.close()
		show_message(Lang.t(VillagerPost.ALARM_LINE), 2.4)


## How long the hero knocks at a crystal cluster before the crystals come off:
## two blows of the strike.
const DIG_BLOW := 0.42


## Running into a web of silver silk: one strand goes into the ingredient pouch and the web is gone
## (see SilverSilk).
func _harvest_silk(s: Dictionary) -> void:
	player.face(s.pos - player.global_position)
	player.play_once(Player.STRIKE_ANIM, DIG_BLOW)
	var count := SilverSilk.harvest(level, s)
	if count <= 0:
		return
	Sfx.play(self, "word_zing", -6.0, s.pos, 1.5)
	crafting.add(SilverSilk.ID, count)
	Effects.loot_text(level, s.pos + Vector3(0, 0.6, 0), "+%d %s" % [count, Crafting.ingredient_name(SilverSilk.ID)], SilverSilk.COLOUR, DamageNumber.item_worth(SilverSilk.ID))
	Events.found(Lang.t("Ein Strang Silberseide kommt in deinen Zutatenbeutel."), SilverSilk.COLOUR)
	learn(SilverSilk.LEARN)


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
	Effects.loot_text(level, s.pos + Vector3(0, 2.0, 0), "+%d %s" % [count, Crafting.ingredient_name(Mines.CRYSTAL_ID)], Mines.CRYSTAL, DamageNumber.item_worth(Mines.CRYSTAL_ID))
	Events.found(Lang.t("%d Grottenkristalle kommen in deinen Zutatenbeutel.") % count, Mines.CRYSTAL)
	learn(Mines.CRYSTAL_LEARN)
	var learned := crafting.learn_from_find(Mines.CRYSTAL_ID)
	if first or not learned.is_empty():
		var names := learned.map(func(id): return Lang.t(Crafting.RECIPES[id].name))
		var text := Lang.t("Grottenkristalle! Schleife sie am Schleifrad im Dorf zu Schmuck.")
		if not names.is_empty():
			text += "\n" + Lang.t("Neue Rezepte: %s") % ", ".join(names)
		show_message(text, 4.0)


## Running into a rock face of the stonemason's quarry: two blows, then it
## gives its stone blocks (as many as fit in the bag) and lies in rubble until
## the next morning (see QuarryRocks). A full bag leaves the rock whole.
func _break_stone(s: Dictionary) -> void:
	player.face(s.pos - player.global_position)
	if s.spent:
		player.play("Idle")
		show_message(Lang.t("Hier liegt nur noch Geröll. Bis zum nächsten Morgen wächst der Fels nach."), 2.4)
		return
	if s.get("digging", false):
		return
	if not player.bag_fits(QuarryRocks.STONE):
		player.play("Idle")
		show_message(Lang.t("Deine Tasche ist voll."), 2.0)
		return
	s.digging = true
	player.path.clear()
	for blow in 2:
		player.play_once(Player.STRIKE_ANIM, DIG_BLOW * (2 - blow))
		Sfx.play(self, "hit", -8.0, s.pos, 0.8 + blow * 0.1)
		await get_tree().create_timer(DIG_BLOW).timeout
	s.digging = false
	if level == null or not level.stations.has(s):
		return
	var count := 0
	while count < QuarryRocks.STONE_YIELD and player.bag_fits(QuarryRocks.STONE):
		player.bag.append(QuarryRocks.STONE)
		count += 1
	if count == 0 or not QuarryRocks.mark_broken(level, s, day):
		return
	Sfx.play(self, "gear_soft_0", -2.0, s.pos)
	Effects.loot_text(level, s.pos + Vector3(0, 1.8, 0), "+%d %s" % [count, Items.item_name(QuarryRocks.STONE)], Color(0.75, 0.73, 0.7), DamageNumber.item_worth(QuarryRocks.STONE))
	Events.found(Lang.t("%d Steinblöcke aus dem Steinbruch liegen in deiner Tasche.") % count, Color(0.75, 0.73, 0.7))
	_update_hud()


## Running into a felled trunk beside the woodcutter or a windfall in the woods:
## two blows of the axe, then it gives its timber (as many pieces as fit in the
## bag) and only its stump is left until the next morning (see WoodLogs). A full
## bag leaves the trunk whole.
func _chop_wood(s: Dictionary) -> void:
	player.face(s.pos - player.global_position)
	if s.spent:
		player.play("Idle")
		show_message(Lang.t("Hier ist nur noch ein Stumpf. Bis zum nächsten Morgen liegt hier wieder ein Stamm."), 2.4)
		return
	if s.get("digging", false):
		return
	if not player.bag_fits(WoodLogs.TIMBER):
		player.play("Idle")
		show_message(Lang.t("Deine Tasche ist voll."), 2.0)
		return
	s.digging = true
	player.path.clear()
	var blows: int = s.get("blows", 2)
	for blow in blows:
		player.play_once(Player.STRIKE_ANIM, DIG_BLOW * (blows - blow))
		Sfx.play(self, "hit", -8.0, s.pos, 0.6 + blow * 0.1)
		await get_tree().create_timer(DIG_BLOW).timeout
	s.digging = false
	if level == null or not level.stations.has(s):
		return
	var count := 0
	while count < int(s.get("yield", WoodLogs.TIMBER_YIELD)) and player.bag_fits(WoodLogs.TIMBER):
		player.bag.append(WoodLogs.TIMBER)
		count += 1
	if count == 0 or not WoodLogs.mark_chopped(level, s, day):
		return
	Sfx.play(self, "gear_soft_0", -2.0, s.pos)
	Effects.loot_text(level, s.pos + Vector3(0, 1.8, 0), "+%d %s" % [count, Items.item_name(WoodLogs.TIMBER)], WoodLogs.SAPWOOD, DamageNumber.item_worth(WoodLogs.TIMBER))
	Events.found(Lang.t("%d Bauholz liegen in deiner Tasche.") % count, WoodLogs.SAPWOOD)
	_update_hud()


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
		pet.gone_home.connect(send_companion_home)
	_spawn_home_pets()


## The companion could not follow the hero (down a pit without stairs: it goes
## up and down only by stairs, see Pet and HouseFloors; a trapdoor takes both
## down together) and lost sight of them: it runs home to the hero's house and
## waits in the companions' corner until the hero takes it along again.
func send_companion_home() -> void:
	var c := companion()
	if is_instance_valid(pet):
		pet.queue_free()
	pet = null
	if c.is_empty():
		return
	following = -1
	apply_companion_perk()
	Events.tell(Lang.t("%s läuft nach Hause und wartet dort auf dich.") % c.name, Color(1.0, 0.82, 0.55))


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
	Effects.loot_text(level, pos + Vector3(0, 2.0, 0), Crafting.ingredient_name(id), Color(0.75, 0.9, 1.0), DamageNumber.item_worth(id))
	var fox_name: String = pet.given_name if is_instance_valid(pet) and pet.given_name != "" else Lang.t("Dein Fuchs")
	Events.found(Lang.t("%s hat etwas ausgegraben: %s!") % [fox_name, Rarity.marked(id)])


## A dug-up ingredient goes into the ingredient pouch, not the bag.
## An ingredient picked up: `count` of it, from a fallen foe's loot when
## `from_loot` (see Level.drop_kill_loot), which puts no mark on the map.
func _on_ingredient_collected(id: String, count := 1, from_loot := false) -> void:
	crafting.add(id, count, not from_loot)
	if Loot.is_coin(id):
		Sfx.play_coins(self, mini(count, 5))
		Effects.loot_text(level, player.global_position + Vector3(0, 3.0, 0), "+%d %s" % [count, Crafting.ingredient_name(id)], Rarity.color(id),
				DamageNumber.copper_worth(count * Loot.COIN_VALUE.get(id, 1)))
		Events.found(Lang.t("Gefunden: %s") % ("%d× %s" % [count, Rarity.marked(id)]))
		_update_hud()
		return
	Sfx.play(self, "key", -3.0)
	Effects.loot_text(level, player.global_position + Vector3(0, 3.0, 0), Crafting.ingredient_name(id), Rarity.color(id) if from_loot else Color(0.7, 0.95, 0.5), DamageNumber.item_worth(id))
	if Crafting.in_purse(id):
		# Gems go in the purse, like the coins (see Crafting.purse).
		Events.found(Lang.t("%s kommt in deinen Geldbeutel. Du findest ihn im Inventar (I) als eigenen Reiter.") % Rarity.marked(id), Color(0.7, 0.95, 0.5))
	else:
		Events.found(Lang.t("%s kommt in deinen Zutatenbeutel. Du findest ihn im Inventar (I) als eigenen Reiter.") % Rarity.marked(id), Color(0.7, 0.95, 0.5))
	if GlowMushrooms.is_glow(id):
		learn(GlowMushrooms.LEARN)
		Events.tell(Lang.t(GlowMushrooms.PICKED), GlowMushrooms.colour(GlowMushrooms.kind_of(id)))
	if id == SummitGarden.INGREDIENT:
		learn(SummitGarden.PICKED_LEARN)
		Events.tell(Lang.t(SummitGarden.PICKED), Color(0.9, 0.95, 1.0))
	# A part of the fallen dragon teaches the recipe made from it.
	if DragonLair.PART_COLOURS.has(id):
		learn(DragonLair.PARTS_LEARN)
		var learned := crafting.learn_from_find(id)
		if not learned.is_empty():
			var names := learned.map(func(r): return Lang.t(Crafting.RECIPES[r].name))
			show_message(Lang.t("Neue Rezepte: %s") % ", ".join(names), 4.0, GOLD)


## The fountain: every ailment gone and full life, as often as you like; a
## level can set a fixed amount of life per drink instead (Level.fountain_heal).
func _drink(s: Dictionary) -> void:
	player.face(s.pos - player.global_position)
	var gain := player.max_hp - player.hp
	if level.fountain_heal > 0:
		gain = mini(level.fountain_heal, gain)
	var healed := gain > 0
	player.hp += gain
	if healed:
		Effects.float_text(level, player.global_position + Vector3(0, 2.6, 0), "+%d" % gain, Color(0.5, 1.0, 0.5))
	var cured := player.cure()
	player.play_flourish("PickUp", 0.6)
	Sfx.play(self, "drink")
	var burst := Effects.make_sparkles(Color(0.5, 0.8, 1.0), true)
	burst.position = player.global_position + Vector3(0, 1.0, 0)
	level.add_child(burst)
	if level.outdoor and belly_sips.sip(_clock_now()):
		_overdrink()
	elif cured:
		show_message(Lang.t("Das Wasser des Brunnens heilt dich von allem Übel."))
	elif healed:
		show_message(Lang.t("Das kühle Wasser heilt deine Wunden."))
	else:
		show_message(Lang.t("Du trinkst vom klaren Wasser."))
	_update_hud()


## Sips at the village fountain, to tell when the hero drinks too much.
var belly_sips := BloatedBelly.new()


## Seconds since the game started, for counting sips.
func _clock_now() -> float:
	return Time.get_ticks_msec() / 1000.0


## One sip too many at the village fountain: the belly swells, the hero
## waddles and says so (see BloatedBelly).
func _overdrink() -> void:
	player.bloat()
	var said := BloatedBelly.line()
	Effects.float_text(level, player.global_position + Vector3(0, 3.0, 0), said, Color(0.6, 0.85, 1.0))
	Events.say(hero_name, said, player.global_position)
	Sfx.play(self, "word_grumpel", -4.0, player.global_position)
	show_message(Lang.t("Dein Bauch ist prall voll Wasser. Drei Minuten lang watschelst du nur noch langsam."), 3.5)


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


## The door or gate the hero built (or another hero's) within reach, when no
## crate, stone block or backpack nearer claims the E key; else null.
func door_in_reach() -> BuiltDoor:
	if house_sketcher == null or player == null or level == null or not level is Outdoor:
		return null
	if level.crate_in_reach(player) != null or level.stone_in_reach(player) != null or level.pack_in_reach(player) != null:
		return null
	return house_sketcher.door_near(player.global_position)


## The shutters of one of the hero's own windows within reach, when no door,
## crate, stone block or backpack claims the E key; else null.
func shutters_in_reach() -> BuiltShutters:
	if house_sketcher == null or player == null or level == null or not level is Outdoor:
		return null
	if door_in_reach() != null or level.crate_in_reach(player) != null or level.stone_in_reach(player) != null \
			or level.pack_in_reach(player) != null:
		return null
	return house_sketcher.shutters_near(player.global_position)


## E at one of the hero's windows opens or shuts its shutters. Returns "" or why not.
func window_action(pair: BuiltShutters) -> String:
	if not player.can_act():
		return Lang.t("Gerade nicht.")
	player.face(pair.global_position - player.global_position)
	player.play_once("Interact", 0.3)
	pair.toggle()
	return ""


## E at a door opens or shuts it; Shift+E locks or unlocks the hero's own.
## Returns "" or why not.
func door_action(door: BuiltDoor, lock: bool) -> String:
	if not player.can_act():
		return Lang.t("Gerade nicht.")
	learn("Türen und Tore, die du baust, gehen auf, wenn du hineinläufst, und fallen hinter dir wieder zu. Taste E öffnet eine Tür und hält sie offen oder schließt sie. Doppelklick oder Umschalt+E schließt deine eigene Tür ab: Dann kommt niemand hindurch, auch du nicht, bis du wieder aufschließt. Ein Vorhängeschloss an der Tür zeigt, dass sie abgeschlossen ist.")
	player.face(door.global_position - player.global_position)
	if lock:
		if not door.own:
			return Lang.t("Das ist nicht deine Tür.")
		player.play_once("Interact", 0.3)
		door.set_locked(not door.locked)
		show_message(Lang.t("Abgeschlossen: Niemand kommt hindurch, bis du wieder aufschließt.") if door.locked else Lang.t("Aufgeschlossen."), 2.0)
		return ""
	var why := door.use(player.global_position)
	if why == "":
		player.play_once("Interact", 0.3)
	return why


## A double click on one of the hero's own built doors (at `point` on the
## floor) locks or unlocks it, like Shift+E. Returns whether the click was
## for a door, so it does not also toggle sneaking.
func _lock_door_by_double_click(point: Vector3) -> bool:
	if house_sketcher == null or player == null or level == null or not level is Outdoor:
		return false
	var door := house_sketcher.door_near(point, DOOR_CLICK_REACH)
	if door == null or not door.own:
		return false
	if door_in_reach() != door:
		show_message(Lang.t("Geh näher an die Tür, um sie abzuschließen."), 1.6)
		return true
	var why := door_action(door, true)
	if why != "":
		show_message(why, 1.6)
	return true


## How close to a door (metres) a double click counts as aimed at it.
const DOOR_CLICK_REACH := 1.0


## Sets a crate from the bag down right under the hero, who ends up standing
## on top of it. Returns "" on success, else why not.
func put_down_crate() -> String:
	if not player.can_act() or player.is_climbing() or not player.is_on_floor():
		return Lang.t("Gerade nicht.")
	if not player.bag.has("kiste"):
		return Lang.t("Du trägst keine Kiste.")
	var spot := level.crate_spot(player)
	var up := Vector3(spot.x, spot.y + Crate.SIZE + 0.02, spot.z)
	if spot == Vector3.INF or not player.has_room_at(up):
		return Lang.t("Hier ist kein Platz für die Kiste.")
	player.path.clear()
	player.bag.erase("kiste")
	level.put_crate(spot)
	player.lift_onto(up)
	Sfx.play(self, "gear_book", -2.0, spot)
	_update_hud()
	return ""


# --- Stone blocks -------------------------------------------------------------

## Sets a stone block from the bag down right under the hero, lying across
## the way they face; they end up standing on top of it. Returns "" on
## success, else why not.
func place_stone() -> String:
	if not player.can_act() or player.is_climbing() or not player.is_on_floor():
		return Lang.t("Gerade nicht.")
	if not player.bag.has(Menus.STONE):
		return Lang.t("Du trägst keinen Steinblock. Der Steinmetz im Dorf verkauft welche.")
	var spot := level.stone_spot_under(player, player.facing())
	if spot.is_empty():
		return Lang.t("Hier ist kein Platz für den Steinblock.")
	var base := StoneBlock.spot_of(spot.cell, spot.along_x, spot.layer)
	var up := base + Vector3(0, StoneBlock.HEIGHT + 0.02, 0)
	if not player.has_room_at(up):
		return Lang.t("Hier ist kein Platz für den Steinblock.")
	player.path.clear()
	player.bag.erase(Menus.STONE)
	var stone := level.put_stone(spot.cell, spot.along_x, spot.layer)
	player.lift_onto(up)
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
	if not player.bag_fits(Menus.STONE):
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
	elif level.stone_in_reach(player) == null and level.pack_in_reach(player) != null:
		why = push_floor_pack()
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


## A click on a backpack lying on the floor opens it, when the hero is close
## enough. Returns whether it was a click on a pack.
func _click_floor_pack(screen_pos: Vector2) -> bool:
	if level == null or level.packs.is_empty() or not player.can_act() or player.is_climbing():
		return false
	var hit := _ray_from_camera(screen_pos, [player.get_rid()])
	var pack := hit.get("collider") as FloorPack if not hit.is_empty() else null
	if pack == null:
		return false
	var why := open_floor_pack(pack)
	if why != "":
		show_message(why, 1.4)
	return true


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


## Shrine blessings the hero has left in the beginner dungeon.
func shrines_left() -> int:
	return maxi(0, Player.SHRINE_CAP_BEGINNER - player.beginner_shrines_used)


func _open_shrine(s: Dictionary) -> void:
	if level.beginner_dungeon and shrines_left() <= 0:
		_pending_station = {}
		show_message(Lang.t("Die Schreine sind verstummt."), 2.0)
		return
	_shrine = s
	_shrine_left_label.visible = level.beginner_dungeon
	_shrine_left_label.text = Lang.t("Segen übrig: %d") % shrines_left()
	_pending_station = {}
	player.face(s.pos - player.global_position)
	set_world_paused(true)
	if s.get("spring", false):
		# The river goddess: the same three places in the window, her own gifts, one with a price.
		_shrine_title.text = Lang.t("Schrein der Flussherrin")
		_shrine_sub.text = Lang.t("Sie schenkt dir eine Gabe. Eine kostet etwas.")
		for i in _gift_buttons.size():
			_gift_buttons[i].text = Lang.t("%s\n(Taste %d)") % [SpringShrine.GIFTS[i], i + 1]
		_wise_gift.visible = false
		Events.teach(SpringShrine.LEARN)
	else:
		_shrine_title.text = Lang.t("Schrein der Ahnen")
		_shrine_sub.text = Lang.t("Wähle eine Gabe")
		for i in 2:
			_gift_buttons[i].text = Lang.t("%s\n(Taste %d)") % [[Lang.t("+5 Leben"), Lang.t("+1 Attributpunkt")][i], i + 1]
		# A wise hero sees one more way to take the shrine's blessing.
		_wise_gift.visible = player.attribute("weisheit") >= Training.WISE_SHRINE
		_constitution_gift.text = Lang.t("%s\n(Taste %d)") % [Lang.t("+%d Konstitution") % shrine_constitution(), 3]
	_shrine_panel.visible = true


## How much Konstitution a shrine gives here: more in the beginner dungeon.
func shrine_constitution() -> int:
	return Player.SHRINE_CONSTITUTION_BEGINNER if level.beginner_dungeon else Player.SHRINE_CONSTITUTION


func _choose_gift(index: int) -> void:
	if _shrine.is_empty():
		return
	var text := ""
	if _shrine.get("spring", false):
		text = SpringShrine.give(self, index)
	else:
		text = _give_ancestor_gift(index)
	if text == "":
		return
	_finish_gift(text)


## The three gifts of an ancestors' shrine.
func _give_ancestor_gift(index: int) -> String:
	var text := ""
	match index:
		0:
			player.gift_hp += Player.SHRINE_LIFE
			player.hp += Player.SHRINE_LIFE
			text = Lang.t("Du fühlst dich zäher: +5 Leben")
		1:
			player.gift_points += Player.SHRINE_POINTS
			text = Lang.t("Die Ahnen schenken dir einen Attributpunkt: verteile ihn auf der Charakterseite (P).")
		2:
			# More Konstitution means more life; the new life comes filled.
			var before := player.max_hp
			var amount := shrine_constitution()
			player.gift_constitution += amount
			player.refresh_stats()
			player.hp += player.max_hp - before
			text = Lang.t("Du fühlst dich zäher: +%d Konstitution") % amount
		3:
			if not _wise_gift.visible:
				return ""
			player.gift_armor += 1
			text = Lang.t("Deine Haut wird hart wie Rinde: +1 Härtung")
	return text


## The shrine has given its gift: the bookkeeping and the message.
func _finish_gift(text: String) -> void:
	if level.beginner_dungeon:
		player.beginner_shrines_used += 1
		if shrines_left() <= 0:
			text += "\n" + Lang.t("Die Schreine sind verstummt.")
		else:
			text += "\n" + Lang.t("Segen übrig: %d") % shrines_left()
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


## What the run meter's texts were last made for (seconds left, winded, language),
## so the strings are built when one changes, not every frame.
var _run_meter_key := []


## Shows how many seconds the hero can still run. Turns red while out of
## breath, until enough has come back to run again.
func _update_run_meter() -> void:
	var full := player.max_stamina()
	var left := full if player.stamina < 0.0 else player.stamina
	_run_bar.max_value = full
	_run_bar.value = left
	var free := not player.in_combat() and not player.winded
	_run_fill.modulate_color = Color(0.85, 0.3, 0.25) if player.winded else (Color(0.4, 0.75, 0.9) if free else Color(0.55, 0.85, 0.4))
	var key := [ceili(left), player.winded, free, Lang.language]
	if key == _run_meter_key:
		return
	_run_meter_key = key
	_run_label.text = Lang.t("Rennen: frei") if free else Lang.t("Rennen: %d s") % ceili(left)
	var run_tip := Lang.t("So lange kannst du noch rennen. Im Gehen und Stehen kommt die Puste zurück.")
	run_tip += "\n" + Lang.t("Außerhalb eines Kampfes kostet Rennen keine Puste.")
	if player.winded:
		run_tip += "\n" + Lang.t("Außer Atem: Erst wenn sich die Leiste wieder etwas gefüllt hat, kannst du rennen.")
	_run_row.tooltip_text = run_tip


func _update_hud() -> void:
	_level_label.text = Lang.t(level.level_name) if level.outdoor or level.building != "" else Lang.t("Ebene %d: %s") % [level_index + 1, Lang.t(level.level_name)]
	_clock_shown = _clock_text()
	if _clock_shown != "":
		_level_label.text += "    " + _clock_shown
	_hp_bar.max_value = maxi(1, player.max_hp)
	_hp_bar.value = clampi(player.hp, 0, player.max_hp)
	_hp_hover.tooltip_text = hp_tip()
	_update_status_icons()
	_show_hero_level()
	_update_purse()
	_update_ammo()
	_key_label.text = Lang.t("Schlüssel gefunden") if level.has_key else Lang.t("Kein Schlüssel")
	# The lair's floors have locked doors too.
	_key_label.visible = not level.outdoor and (level.building == "" or (DragonLair.is_floor(level) and level.has_doors()))
	_key_icon.visible = _key_label.visible
	_key_icon.modulate.a = 1.0 if level.has_key else 0.4
	_key_label.add_theme_color_override("font_color", GOLD if level.has_key else Color(1, 1, 1, 0.45))
	_key_label.tooltip_text = Lang.t("Mit dem Schlüssel öffnest du die verschlossene Tür zur nächsten Ebene.") if level.has_key \
			else Lang.t("Irgendwo auf dieser Ebene liegt der Schlüssel zur verschlossenen Tür.")


## The coins on the HUD, in this order: copper (the money), silver, gold.
const PURSE_COINS := ["kupfermuenze", "silbermuenze", "goldmuenze"]


## A fixed gap in the purse line.
func _purse_gap(width: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.x = width
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## The coins the HUD was last drawn for; it is redrawn only when they change.
var _purse_key := []


## Counts the copper, silver and gold coins on the HUD, each after its
## picture. A metal the hero has none of is dimmed, like the missing key.
func _update_purse() -> void:
	if _coin_label == null:
		return
	var key := [coins_held(PURSE_COINS[0]), coins_held(PURSE_COINS[1]), coins_held(PURSE_COINS[2]), Lang.language]
	if key == _purse_key:
		return
	_purse_key = key
	if level != null and level.is_home:
		level.show_hoard(hoard_coins())
	var labels := {"kupfermuenze": _coin_label, "silbermuenze": _silver_label, "goldmuenze": _gold_label}
	var names := {"kupfermuenze": "Kupfermünzen: %d", "silbermuenze": "Silbermünzen: %d", "goldmuenze": "Goldmünzen: %d"}
	var worth := Loot.worth_text(key[0], key[1], key[2])
	for id in PURSE_COINS:
		var held := coins_held(id)
		var label: Label = labels[id]
		label.text = str(held)
		var shade := 1.0 if held > 0 else 0.45
		label.modulate.a = shade
		_coin_icons[id].modulate.a = shade
		var tip := Lang.t(names[id]) % held + "\n"
		if id == Loot.MONEY:
			tip += Lang.t("Dein Kupfer: Damit bezahlst du bei Händlern und Handwerkern.")
		elif id == "silbermuenze":
			tip += Lang.t("Eine Silbermünze ist %d Kupfer wert.") % Loot.COIN_VALUE[id]
		else:
			tip += Lang.t("Eine Goldmünze ist %d Kupfer wert.") % Loot.COIN_VALUE[id]
		# All three coins counted up into the higher metals; the coins stay as they are.
		tip += "\n" + Lang.t("Zusammen wert: %s") % worth
		label.tooltip_text = tip


## The hero's level and the experience towards the next one on the HUD.
## A free level point is told there too, until it is spent.
func _show_hero_level() -> void:
	var step := HeroLevel.progress(player.hero_xp)
	_xp_bar.max_value = maxi(1, step.y)
	_xp_bar.value = step.x if step.y > 0 else 1
	_xp_label.text = Lang.t("Stufe %d") % player.hero_level()
	if player.free_points() > 0:
		_xp_label.text += "   " + Lang.t("Punkt frei (P)")
	var tip := Lang.t("Stufe %d") % player.hero_level()
	if step.y > 0:
		tip += "\n" + Lang.t("Erfahrung: %d von %d bis zur nächsten Stufe") % [step.x, step.y]
	else:
		tip += "\n" + Lang.t("Die höchste Stufe ist erreicht.")
	if player.free_points() > 0:
		tip += "\n" + Lang.t("Du hast einen Punkt frei: Verteile ihn auf der Charakterseite (P).")
	_xp_row.tooltip_text = tip


## The life bar's tooltip: life in numbers, and while some is missing how
## fast it comes back now (or that a fresh hit has paused it).
func hp_tip() -> String:
	var tip := Lang.t("Leben: %d von %d") % [clampi(player.hp, 0, player.max_hp), player.max_hp]
	if player.hp >= player.max_hp:
		return tip
	if player.regen_paused():
		tip += "\n" + Lang.t("Erholung: nach dem Treffer kurz unterbrochen, dann %.1f pro Sekunde") % player.life_regen()
	else:
		tip += "\n" + Lang.t("Erholung: %.1f pro Sekunde") % player.life_regen()
	return tip


## The time of day for the HUD, e.g. "21:30, night, full moon". Down in
## the dungeon only the hour and the part of the day.
func _clock_text() -> String:
	if level == null:
		return ""
	var text := "%s, %s" % [DayNight.clock_text(day_hour), Lang.t(DayNight.part_of_day(day_hour))]
	# Down in the dungeon the time goes on, but sky and moon are out of sight.
	if not (level.outdoor or level.building != ""):
		return text
	# The season, always (see Seasons): it follows the real calendar, a week each.
	text += ", " + Lang.t(Seasons.WORDS[Weather.season(season_day())])
	if weather != Weather.CLEAR:
		text += ", " + Lang.t(Weather.word(weather))
	# At night the clock names tonight's moon (see Moon).
	if DayNight.is_night(day_hour):
		text += ", " + Lang.t(Moon.word(day))
	return text


## The world's clock runs wherever the hero is, down in the dungeon too,
## while the world is not paused; the open air is lit for the hour.
func _tick_clock(delta: float) -> void:
	if level == null:
		return
	_house_blessing_clock -= delta
	if _house_blessing_clock <= 0.0:
		_house_blessing_clock = HOUSE_BLESSING_CHECK
		_update_house_blessing()
	_soundscape.tick(self, delta)
	if state == State.PLAYING and level.process_mode != Node.PROCESS_MODE_DISABLED:
		var before := day_hour
		day_hour = DayNight.advance(day_hour, delta)
		world_hours += delta * 24.0 / DayNight.DAY_LENGTH
		level.world_hours = world_hours
		if _tour_time >= 0.0:
			_tick_tour(delta)
		elif _dawn_between(before, day_hour):
			_new_day()
		_tick_timber(delta)
		_tick_weather(delta)
		puddle_water = Weather.puddle_water(puddle_water, weather, delta)
		snow_cover = Weather.snow_cover(snow_cover, weather, delta, Weather.is_winter(season_day()))
		ice_cover = Weather.ice(ice_cover, snow_cover, weather, delta)
	if level.outdoor:
		DayNight.apply(_env, _moon, day_hour)
		_mine_dark = move_toward(_mine_dark, 1.0 if _in_lost_mine() else 0.0, delta / MINE_FADE)
		_moonlight()
		_weather_look = Weather.ease_look(_weather_look, Weather.look(weather), delta)
		_shelter = move_toward(_shelter, 1.0 if _under_roof() else 0.0, delta / SHELTER_FADE)
		_flash = maxf(0.0, _flash - delta * 3.0)
		# A stroke of lightning flickers: bright, a dip, bright again.
		var flicker := _flash * (0.45 if _flash > 0.55 and _flash < 0.75 else 1.0) * (1.0 - _shelter)
		Weather.apply(_env, _moon, _seen_look(), flicker)
		_moon.light_energy = Graphics.sun(_moon.light_energy, DayNight.moon_at(day_hour))
		_check_season()
		if level is Outdoor:
			level.day = day
			# The seasons follow the real calendar (see Seasons): clothes, trees and vines change
			# with the real day.
			var today := season_day()
			level.season_day = today
			level.set_winter_wear(Weather.is_winter(today))
			level.set_season(today)
			# The lamps, windows and fires follow the hour: a few times a second is plenty (a game
			# hour passes in 50 seconds), and the first call for a new level always goes through.
			if level.hour < 0.0 or absf(level.hour - day_hour) >= HOUR_STEP:
				level.set_hour(day_hour)
			level.set_weather(weather)
			level.set_puddles(puddle_water, _weather_look.rain, clampf(_env.ambient_light_energy / 0.52, 0.05, 1.0))
			level.set_snow(snow_cover, clampf(_env.ambient_light_energy / 0.52, 0.0, 1.0), lerpf(0.25, 1.0, Moon.light(day)) * DayNight.moon_at(day_hour))
			level.set_ice(ice_cover)
			if level.moon_night >= 0 and (Moon.is_full(level.moon_night) or Moon.is_new(level.moon_night)):
				learn(Moon.LORE)
	if _clock_text() != _clock_shown:
		_update_hud()


## The night is as bright as tonight's moon, the only light out there:
## a cool bluish sheen at full moon, nearly pitch black at new moon (see Moon). Only
## the moon's share of the light changes (see DayNight.moon_at), so the day,
## dusk and dawn look the same whatever the moon.
func _moonlight() -> void:
	var bright := _night_light()
	# Down in the mine the sky's light casts no shadows: the trees and houses on the ground
	# above must not throw theirs onto the mine floor.
	_moon.shadow_enabled = _mine_dark < 0.5
	# The hero's lantern shrinks to a small pool as the night darkens (not down in the mine:
	# there it shines as in a dungeon).
	if player:
		player.set_night_dim((1.0 - bright) * (1.0 - _mine_dark))
		# The soft light on the hero's face: at night, down in the mine and under a roof.
		player.set_dark(maxf(maxf(DayNight.glow_at(day_hour), _mine_dark), _shelter * 0.7))
	bright *= lerpf(1.0, MINE_LIGHT, _mine_dark)
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
	# The morning wipes the footprints out of the snow.
	SnowPrints.clear()
	Forge.restock(smith_stock, day, hero_name)
	if level != null:
		# Mined crystal clusters grow back with the morning.
		Mines.refresh_crystals(level, day, true)
		QuarryRocks.refresh(level, day, true)
		WoodLogs.refresh(level, day, true)
		SummitGarden.refresh(level, day, true)
		GlowMushrooms.refresh(level, day, true)
	_dragon_morning(quiet)
	var expired := bounties.refresh(day)
	if quiet or not escaped:
		return
	var text := Lang.t("Ein neuer Morgen: frische Kopfgelder am Aushang.")
	if expired > 0:
		text += "\n" + Lang.t("Nicht erledigte Jagden vom Vortag sind verfallen: %d") % expired
	quest_news(text, Color(1.0, 0.82, 0.4), 4.0)


## How many hours after the first morning of a season the villagers talk about it.
const SEASON_TALK_HOURS := 3.0
## How much quieter thunder is in a house (under a roof) and down in a cellar, in dB.
const THUNDER_INDOORS_DB := -8.0
const THUNDER_CELLAR_DB := -16.0
## How far winter fog by day is smoothed towards one even haze (0 patchy banks, 1 even haze).
const WINTER_EVEN := 0.1
## How much darker the winter fog banks are than the air, so they show as grey drifts against the bright snow
## instead of vanishing into it (1 = the air's own brightness).
const WINTER_SHADE := 0.7


## The season day the seasons are on: the real calendar's (see Seasons), moved by season_shift.
func season_day() -> int:
	return Seasons.today() + season_shift


## Notices a new season (the real calendar turned, or the sky command moved it) and tells of it
## (see _turn_of_season). The first look after a start or a load only takes note.
func _check_season() -> void:
	var now := season_day()
	if now == _season_seen:
		return
	var before := _season_seen
	_season_seen = now
	if before != SEASON_UNSEEN:
		_turn_of_season(now, before)


## The first day of winter brings snow at once (and stops any rain); the first day after it says
## spring is back (see Weather.is_winter).
func _turn_of_season(now: int, before: int) -> void:
	var winter := Weather.is_winter(now)
	if winter == Weather.is_winter(before):
		return
	if level is Outdoor:
		# The villagers have a word about it when they step out (see Villager.season_remark).
		level.season_talk = "winter" if winter else "spring"
		level.season_talk_until = world_hours + SEASON_TALK_HOURS
	if winter:
		set_weather(Weather.SNOW)
		if escaped:
			quest_news(Lang.t("Der Winter ist da! Eine Woche lang fällt Schnee statt Regen."), Color(0.8, 0.9, 1.0), 5.0)
	elif escaped:
		quest_news(Lang.t("Der Winter geht zu Ende. Der Schnee taut."), Color(0.7, 0.95, 0.7), 4.0)


# --- The dragon's helpers ------------------------------------------------------

## A helper carried something off the open ground before the hero's eyes
## (see DragonHelpers): into the hoard. The first of a night gets a line in
## the event log, and the compendium learns of them.
func _on_loot_carried_off(kind: String, id: String, count := 1) -> void:
	var first := int(hoard.tonight.things) == 0
	hoard.gather(kind, id, count)
	if first:
		Events.found(Lang.t("Kleine Drachlinge schwärmen aus dem Berg und tragen fort, was am Boden liegt."), DragonHoard.COLOR)
		learn(DragonHoard.LORE)


## The morning after a night: the helpers leave nothing lying, anywhere.
## In the open air before the hero's eyes they fly home at daybreak, and
## what is left waits for the next night (see DragonHelpers). On any other map the
## hero is on, or asleep, it is gone from the ground by morning, all but
## what lies right beside the awake hero. Every other map and building they
## swept unseen (see DragonHoard.sweep). Then the event log tells what the
## night brought.
func _dragon_morning(asleep := false) -> void:
	var here: Array = level.floor_items if level != null else []
	var reached_inside := false
	if level != null:
		var helpers: DragonHelpers = level.get_node_or_null("DragonHelpers")
		if helpers == null or asleep or not level is Outdoor:
			var things := 0
			for p in level.floor_pickups():
				if not asleep and player != null and DragonHelpers._flat(player.global_position - p.node.global_position) < DragonHelpers.SHY:
					continue
				var node: Node3D = level.take_from_floor(p)
				if node:
					node.queue_free()
				hoard.gather(str(p.floor[0]), str(p.floor[1]), CoinPile.count_of(p.floor))
				things += 1
			reached_inside = things > 0 and not level is Outdoor
	for key in floors:
		if is_same(floors[key], here):
			continue
		var before: int = floors[key].size()
		var went := hoard.sweep(floors[key])
		var file := str(key).get_slice("#", 0)
		if not went.is_empty():
			# Counted as taken, as if the hero had picked it up (a trophy is
			# not laid out again where it fell).
			if not looted.has(file):
				looted[file] = {}
			for id in went:
				looted[file][id] = true
		if floors[key].size() < before and not Level.is_outdoor_file(file):
			reached_inside = true
	var to_elder := int(hoard.tonight.get("elder", 0)) > 0
	var text := hoard.morning_report()
	if text != "":
		Events.found(text, DragonHoard.COLOR)
		learn(DragonHoard.LORE)
	if to_elder:
		learn(DragonHoard.ELDER_LORE)
	if reached_inside:
		learn(DragonHoard.EVERYWHERE_LORE)


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
		Events.found(Lang.t("+%d Kupfer") % amount, GOLD)
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
		Events.found(Lang.t("+%d Kupfer") % _gold(amount), GOLD)
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
		set_weather(Weather.roll(day_hour, _weather_rng, weather, Weather.season(season_day())))


## Sets the weather for `hours` of the day (a random spell when not given).
## The open air follows in _tick_clock.
func set_weather(kind: String, hours := -1.0) -> void:
	weather = Weather.for_season(kind if kind in Weather.KINDS else Weather.CLEAR, Weather.is_winter(season_day()))
	weather_hours = hours if hours > 0.0 else Weather.spell(_weather_rng, weather)


## The warm dust motes that drift in the lamplight around the hero (see Effects.make_dust) belong
## to the dungeon. Up on the open-air map, house cellars included, they are put out: in the dark
## there they read as snowflakes.
func _place_dust(at: Vector3) -> void:
	var dust := get_node("Dust") as CPUParticles3D
	dust.global_position = at + Vector3(0, 2.0, 0)
	var show := level != null and not level.outdoor
	if dust.visible != show:
		dust.visible = show
		dust.emitting = show


## Down in the forgotten mine (see LostMine) no daylight reaches: its lamps and the hero's
## lantern light it, as at night. _mine_dark eases from 0 (up on the ground) to 1 (down there)
## over MINE_FADE seconds; down there the light is MINE_LIGHT of what it is outside.
var _mine_dark := 0.0
const MINE_LIGHT := 0.15
const MINE_FADE := 1.2


func _in_lost_mine() -> bool:
	return level is Outdoor and player != null and house_sketcher != null and house_sketcher.cellar_view.active \
			and (LostMine.holds(player.global_position) or Sewers.holds(player.global_position))


## Whether the view is inside a self-built house: the hero stands in one or down in its cellar
## (see CellarView), or the furnisher looks into one (see HouseSketcher.view_storey). There is
## no weather in there.
func _under_roof() -> bool:
	if not level is Outdoor or player == null:
		return false
	if house_sketcher != null and (house_sketcher.view_storey != HouseSketcher.NO_VIEW or house_sketcher.cellar_view.active):
		return true
	return (level as Outdoor).is_roofed(player.global_position)


## The weather as it is seen: out in the open the weather's own look, inside a built house
## (see _shelter) a clear sky, so nothing of rain, fog or storm reaches the view in there.
func _seen_look() -> Dictionary:
	if _shelter <= 0.001:
		return _weather_look
	return Weather.blend(_weather_look, Weather.look(Weather.CLEAR), _shelter)


## Rain and mist fall and drift around the hero in the open air only, and
## the rain patters as hard as it falls. Inside a house (a built one or a village room one walks
## into) none of it shows, but it goes on outside: the rain, the snow, the mist, the leaves and the fog
## clouds leave out only what lies in there (see IndoorMask), so the hero sees the weather through the
## windows and the open door. Down in a cellar, or while the furnisher looks into a storey, there is
## no outside to see and nothing shows at all.
func _show_weather() -> void:
	IndoorMask.update(level)
	var shut_in: bool = house_sketcher != null and (house_sketcher.view_storey != HouseSketcher.NO_VIEW or house_sketcher.cellar_view.active)
	# Down a stair (below the ground, before the cellar view takes over) the falling leaves stay out too.
	var below_ground: bool = player != null and player.global_position.y < -0.3 and level is Outdoor
	var outside: bool = level != null and level.outdoor and player != null and not shut_in
	if not outside:
		_rain.emitting = false
		_rain.visible = false
		_mist.emitting = false
		_mist.visible = false
		_snow.emitting = false
		_snow.visible = false
		_leaves.visible = false
		Weather.cold = false
		_clouds.set_look(0.0, Weather.HAZE, 0.0)
		return
	Weather.cold = _shelter < 0.5 and (snow_cover >= Weather.COLD_FROM or float(_weather_look.snow) > 0.3)
	# The weather outside as it is (the shaders leave the inside of the houses out); only the
	# colour of the air follows the view (see _seen_look).
	var look := _weather_look
	var seen := _seen_look()
	_snow.global_position = player.global_position + Vector3(0, Weather.RAIN_HEIGHT * 0.6, 0)
	_leaves.anchor = player.global_position
	_rain.global_position = player.global_position + Vector3(0, Weather.RAIN_HEIGHT, 0)
	_mist.global_position = player.global_position + Vector3(0, 0.8, 0)
	var dusty := look.duplicate()
	dusty.mist = Weather.dusty_mist(look, day_hour)
	var winter_fog := Weather.is_winter(season_day())
	var haze := Weather.fog_haze(_env.fog_light_color, maxf(float(seen.mist), float(look.mist)), winter_fog)
	# One even haze at night. Over the winter snow the banks stay, only softened (WINTER_EVEN), so
	# winter fog still drifts in clouds; by day elsewhere the clouds are fully patchy.
	if winter_fog:
		haze = Color(haze.r * WINTER_SHADE, haze.g * WINTER_SHADE, haze.b * WINTER_SHADE, haze.a)
	var even := 0.0
	if DayNight.glow_at(day_hour) > 0.5:
		even = float(look.mist)
	elif winter_fog:
		even = float(look.mist) * WINTER_EVEN
	_clouds.set_look(dusty.mist, haze, even)
	# The mist patches are shaded by the light; the night's dust keeps them
	# moonlit rather than black.
	var light := 1.0 - DayNight.glow_at(day_hour) + DayNight.moon_at(day_hour) * Moon.light(day) * 0.3
	light = maxf(light, DayNight.glow_at(day_hour) * (1.0 - float(look.mist)) * 0.6)
	Weather.show_particles(_rain, _mist, dusty, light, _snow, Weather.is_winter(season_day()))
	Weather.show_leaves(_leaves, 0.0 if below_ground else Weather.leaf_strength(look, day_hour), light)
	Breath.set_light(light)


## Lightning struck (see Outdoor.strike): the sky flashes, and the thunder
## follows, later and softer the farther away it was.
func _on_lightning(at: Vector3) -> void:
	# The flash is dimmed under a roof (see _shelter in _tick_clock); down in a cellar it does not
	# reach at all, and the thunder only rumbles through, muffled.
	var cellar := level is Outdoor and not (level as Outdoor).hero_cellar.is_empty()
	_flash = 0.0 if cellar else 1.0
	var far: float = level._flat_distance(player.global_position, at) if player else 0.0
	var muffle := THUNDER_CELLAR_DB if cellar else THUNDER_INDOORS_DB * _shelter
	Sfx.play_after(self, clampf(far / 40.0, 0.15, 1.5), "thunder", -1.0 - far * 0.08 + muffle)


# --- Flow -------------------------------------------------------------------

## The open-air map, set aside while the hero is in a building they walked into by a door
## (see go_inside), so stepping out again puts it back instead of building the whole village,
## forest and mountains anew (that took many seconds). Null when nothing is set aside.
var _parked: Outdoor = null
var _parked_index := -1
## The day it was set aside on: a night slept indoors grows the mined rocks back on the way out.
var _parked_day := 0
## What the map was built from when it was set aside (see _outdoor_fingerprint).
var _parked_print := 0
## Set by go_inside for the next load_level: the open air it leaves is set aside, not freed.
var _park_next := false
## Set by _leave_building for the next load_level: the open air set aside may come back.
var _resume_next := false


## What the open-air map is built from that a stay indoors could change. When any of it
## changed, the map set aside is stale and is built anew on the way out.
func _outdoor_fingerprint(file: String) -> int:
	return var_to_str([
		hero_name, escaped, looted.get(file, {}), builds.get(file, []), floors.get(file, []),
		interiors, treasure_maps.state, home_given, home_claimed, met.keys(), secrets_found,
		companions, following, has_fox, home_upgrades.keys(), quests.for_save(), Plots.all(),
	]).hash()


## Takes the open air out of the scene tree and keeps it (see _parked).
func _park_outdoor() -> void:
	_drop_parked()
	_parked = level as Outdoor
	_parked_index = level_index
	_parked_day = day
	# The house builder's tools are made new for the map on the way out (see load_level).
	for tool in [plot_marker, house_sketcher, house_furnisher]:
		if is_instance_valid(tool):
			tool.queue_free()
	_parked.set_meta(Level.PARKED, true)
	remove_child(_parked)
	_parked_print = _outdoor_fingerprint(level_files[_parked_index].get_file())


## Forgets the open air set aside, if any.
func _drop_parked() -> void:
	if is_instance_valid(_parked):
		_parked.queue_free()
	_parked = null
	_parked_index = -1


## Puts the open air set aside back as the level, when it is the one asked for and nothing it
## was built from changed meanwhile. False (and the map set aside is dropped) otherwise.
func _resume_parked(index: int) -> bool:
	if not is_instance_valid(_parked) or index != _parked_index \
			or _outdoor_fingerprint(level_files[index].get_file()) != _parked_print:
		_drop_parked()
		return false
	level = _parked
	_parked = null
	_parked_index = -1
	level.remove_meta(Level.PARKED)
	add_child(level)
	return true


## The house builder's tools of the open air: marking a plot, sketching and furnishing a house.
func _make_build_tools() -> void:
	plot_marker = null
	house_sketcher = null
	house_furnisher = null
	if level is Outdoor:
		plot_marker = PlotMarker.new()
		plot_marker.game = self
		level.add_child(plot_marker)
		house_sketcher = HouseSketcher.new()
		house_sketcher.game = self
		level.add_child(house_sketcher)
		house_furnisher = HouseFurnisher.new()
		house_furnisher.game = self
		level.add_child(house_furnisher)
		plot_marker.refresh()


## The rest of load_level for the open air set aside (see _resume_parked): only what every
## arrival sets. The map, what lies on it and its signals are as the hero left them, and its
## shaders are built already, so there is no warm-up frame (see LevelWarmup).
func _load_parked(index: int) -> void:
	level_index = index
	tutorial.restart()
	writing_card.hide_now()
	var file := level_files[index].get_file()
	level.taken = looted[file]
	level.built = builds[file]
	level.floor_items = floors[file]
	level.night = DayNight.is_night(day_hour)
	level.world_hours = world_hours
	level.secret_bonus = secrets_found
	level.secret_sure = (secrets_found == 0 and index >= FIRST_SURE_SECRET) or dry_levels >= MAX_DRY_LEVELS
	_make_build_tools()
	level.player = player
	player.level = level
	player.frozen = false
	player.controllable = true
	player.revive(level.cell_to_world(level.start_cell), false)
	player.face(Vector3.BACK)
	# Its slimes are still out there (see _keep_slimes).
	wild_slimes = []
	_slimes_fresh = false
	if day != _parked_day:
		# A night went by indoors: what was mined or felled grows back (see _new_day).
		Mines.refresh_crystals(level, day, true)
		QuarryRocks.refresh(level, day, true)
		WoodLogs.refresh(level, day, true)
		SummitGarden.refresh(level, day, true)
		GlowMushrooms.refresh(level, day, true)
	_spawn_pet()
	apply_companion_perk()
	_refresh_seals()
	if horrors:
		horrors.watch(level)
	level.owned_companions = companions.map(func(c): return c.kind)
	_pending_crate = null
	_end_drag()
	_set_atmosphere(true)
	Graphics.lamp_match = Graphics.LAMP_MATCH
	level.day = day
	level.season_day = season_day()
	level.set_hour(day_hour)
	level.set_weather(weather)
	_pending_search = {}
	_pending_station = {}
	_snap_camera()
	_update_hud()
	light_shadows.refresh(true)


func load_level(index: int, restock := true) -> void:
	var park := _park_next
	var resume := _resume_next
	_park_next = false
	_resume_next = false
	if level:
		_keep_slimes()
		if park and level is Outdoor and not Level.is_outdoor_file(level_files[index]):
			_park_outdoor()
		else:
			level.queue_free()
	if Level.is_outdoor_file(level_files[index]):
		if resume and _resume_parked(index):
			_load_parked(index)
			return
		_drop_parked()
	level_index = index
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
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
		level.treasure = treasure_maps.state
		level.house_given = home_given
		level._entered_once = home_claimed
		level.met = met
	level.world_hours = world_hours
	level.secret_bonus = secrets_found
	level.secret_sure = (secrets_found == 0 and index >= FIRST_SURE_SECRET) or dry_levels >= MAX_DRY_LEVELS
	add_child(level)
	level.build()
	_make_build_tools()
	# The fog of war remembers what the hero saw here before (see Journal).
	journal.restore_fog(level)
	level.player = player
	player.level = level
	player.frozen = false
	player.controllable = true
	# Arriving on a level never heals by itself; climbing the stairs gives
	# STAIRS_HEAL (see _next_level) and the fountain heals (see _drink).
	player.revive(level.cell_to_world(level.start_cell), false)
	player.face(Vector3.BACK)
	level.restore_taken()
	if level is Outdoor:
		SlimeGrowth.restore(level, wild_slimes)
		wild_slimes = []
	_slimes_fresh = false
	Mines.refresh_crystals(level, day)
	QuarryRocks.refresh(level, day)
	WoodLogs.refresh(level, day)
	SummitGarden.refresh(level, day)
	GlowMushrooms.refresh(level, day)
	level.restore_floor()
	level.restore_stones()
	level.key_collected.connect(_on_key_collected)
	level.coins_collected.connect(_on_coins_collected)
	level.item_collected.connect(_on_item_collected)
	level.secret_found.connect(_on_secret_found)
	level.ingredient_collected.connect(_on_ingredient_collected)
	level.bundle_reached.connect(_on_bundle_reached)
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
		level.show_hoard(hoard_coins())
		refresh_bookshelf()
	_pending_crate = null
	_end_drag()
	_set_atmosphere(level.outdoor)
	Graphics.lamp_match = Graphics.LAMP_MATCH if level.outdoor else Graphics.LAMP_MATCH_DUNGEON
	var mood := Mines.mood(level.theme)
	if not mood.is_empty():
		# A mine has a light of its own (see Mines.MOODS).
		_env.ambient_light_color = mood.ambient
		_env.ambient_light_energy = mood.energy
		_moon.light_color = mood.light
		_moon.light_energy = Graphics.sun(DUNGEON_MOON)
	if level is Outdoor:
		level.day = day
		level.season_day = season_day()
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
	# frame, and the time that takes does not count (see LevelWarmup). The
	# lamps round the hero cast their shadows from that frame on, and for that
	# frame alone two faint lamps with shadows light the whole level, so the
	# shaders of every lamp that gains its shadows later are built in it too
	# (see LightShadows.warm_up). In the open air one more dark frame builds the
	# shaders of every other weather (see WeatherWarmup).
	LevelWarmup.begin(level, WeatherWarmup.passes(self))
	light_shadows.refresh(true)


func _show_title(text: String, sub: String, prompt: String) -> void:
	for child in _ranking_slot.get_children():
		child.queue_free()
	_name_box.visible = false
	_lang_row.visible = false
	_title_text.add_theme_font_size_override("font_size", UiKit.sized(120))
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
	_title_text.add_theme_font_size_override("font_size", UiKit.sized(90))
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
	_name_edit.add_theme_font_size_override("font_size", UiKit.sized(28))
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
	_drop_parked()
	if hero_name == "":
		hero_name = Lang.t("Namenlos")
	save_slot = _new_slot
	delete_save(save_path(save_slot))
	_name_box.visible = false
	_name_edit.release_focus()
	coins = 0
	iron = 0
	bars = {}
	metal_grams = {}
	companions = []
	following = -1
	trust = {}
	escaped = false
	home_given = false
	home_claimed = false
	home_upgrades.clear()
	home_stores = HomeStores.empty()
	trophies.clear()
	secrets_found = 0
	fishing.ring_found = false
	treasure_maps.clear()
	dry_levels = 0
	bumped_person = false
	hints_shown.clear()
	_hints_last.clear()
	looted.clear()
	builds.clear()
	floors.clear()
	wild_slimes = []
	_slimes_fresh = true
	met.clear()
	quests.clear()
	journal.clear()
	day = 0
	season_shift = 0
	bounties.clear()
	bounties.refresh(day)
	crafting.clear()
	wishes.clear()
	Factions.clear()
	MonsterLore.clear()
	fishing.stop()
	reputation.clear()
	village_talk.clear()
	village_worries.clear()
	village_rumours.clear()
	drinking_songs.clear()
	mage_duel.clear()
	storage.clear()
	shop_stock.clear()
	wanderer_stock.clear()
	climber_stock = {}
	climber_day = -1
	climber_watch = 0.0
	wanderer_night = -1
	smith_stock.clear()
	Forge.restock(smith_stock, day, hero_name)
	timber_stock = WoodcutterShift.START
	_timber_carry = 0.0
	hoard.clear()
	away_plan = Offline.empty_plan()
	book_hours.clear()
	day_hour = DayNight.START_HOUR
	world_hours = 0.0
	set_weather(Weather.CLEAR, Weather.FIRST_HOURS)
	puddle_water = 0.0
	snow_cover = 0.0
	ice_cover = 0.0
	player.knives = 5
	player.set_sex(_new_sex)
	player.set_hair(HairLook.DEFAULT)
	player.set_cape_design(CapeDesigns.DEFAULT)
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
	return _make_slider_row(title, tooltip, value, 0.0, 1.0, 0.05, on_change)


## A row of the pull-out menu's settings: a label and a slider. Every row's
## label takes the same width, so the sliders line up.
func _make_slider_row(title: String, tooltip: String, value: float, low: float, high: float, step: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = Lang.t(title)
	label.add_theme_font_override("font", TEXT_FONT)
	label.add_theme_font_size_override("font_size", UiKit.sized(18))
	label.add_theme_color_override("font_color", GOLD)
	label.custom_minimum_size = Vector2(SLIDER_LABEL_WIDTH, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
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


## The event log's width row: from narrow to the widest that keeps clear of
## the message line (see EventLog.set_width).
func _make_log_width_slider() -> Control:
	var row := _make_slider_row("Protokoll", "Breite des Ereignisprotokolls links", EventLog.width, EventLog.MIN_WIDTH, EventLog.MAX_WIDTH, EventLog.WIDTH_STEP, event_log.set_width)
	_log_width_slider = row.get_child(1)
	return row


## The graphics row: its button names the picked preset (see Graphics) and steps on to the next
## one, as the sound buttons do. The label lines up with the slider rows' labels.
func _make_graphics_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = Lang.t("Grafik")
	label.add_theme_font_override("font", TEXT_FONT)
	label.add_theme_font_size_override("font_size", UiKit.sized(18))
	label.add_theme_color_override("font_color", GOLD)
	label.custom_minimum_size = Vector2(SLIDER_LABEL_WIDTH, 0)
	row.add_child(label)
	_graphics_button = _make_button("", _next_graphics, true)
	_graphics_button.custom_minimum_size = Vector2(0, 44)
	_graphics_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_graphics_button)
	_update_graphics_button()
	return row


func _next_graphics() -> void:
	var at := Graphics.PRESETS.find(Graphics.preset)
	Graphics.choose(Graphics.PRESETS[(at + 1) % Graphics.PRESETS.size()], get_viewport())
	_update_graphics_button()


func _update_graphics_button() -> void:
	_graphics_button.text = Lang.t(Graphics.NAMES[Graphics.preset])
	# The tooltip says what every preset is for, the picked one first.
	var lines: Array[String] = [Lang.t(Graphics.HINTS[Graphics.preset])]
	for which: String in Graphics.PRESETS:
		if which != Graphics.preset:
			lines.append(Lang.t(Graphics.HINTS[which]))
	_graphics_button.tooltip_text = "\n".join(lines)


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
		if not menus.is_open():
			set_drawer_open(false)
			open_pause()
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
## Esc or the quit button: stops the world and opens the pause window, with
## buttons to play on or to quit. It opens even while the hero is busy
## (swinging, stumbling, afraid), as long as they are alive.
func open_pause() -> void:
	if state != State.PLAYING or player == null or player.dead or menus.is_open() or not _shrine.is_empty():
		return
	menus.open("beenden")


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
			"escaped": bool(data.get("escaped", false)), "home": bool(data.get("claimed", false)), "time": time,
			"camp": not Camp.from_save(data.get("camp")).is_empty()}


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
	if info.get("camp", false):
		if info.escaped:
			return Lang.t("%s an einem Lagerfeuer im Freien mit %d Kupfer.") % [who, info.coins]
		return Lang.t("%s an einem Lagerfeuer auf Ebene %d mit %d Kupfer.") % [who, info.level, info.coins]
	if info.home:
		return Lang.t("%s zu Hause mit %d Kupfer.") % [who, info.coins]
	if info.escaped:
		return Lang.t("%s auf dem Friedhof mit %d Kupfer.") % [who, info.coins]
	return Lang.t("%s auf Ebene %d mit %d Kupfer.") % [who, info.level, info.coins]


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
	return SaveFormat.upgrade(data) if data is Dictionary else {}


func _apply_save(data: Dictionary) -> void:
	_drop_parked()
	hero_name = data.get("name", Lang.t("Namenlos"))
	coins = int(data.coins)
	# A game saved before copper became the money held ancient gold coins:
	# each one is exchanged into a copper coin, one for one (see Loot.MONEY).
	if data.get("currency", "") != Loot.MONEY and coins > 0:
		Events.tell(Lang.t("Deine %d uralten Goldmünzen wurden eins zu eins in %d Kupfermünzen getauscht. Kupfer ist jetzt dein Geld.") % [coins, coins], GOLD, 8.0)
	iron = int(data.get("iron", 0))
	metal_grams = {}
	var saved_grams = data.get("metal_grams", {})
	if saved_grams is Dictionary:
		for metal in saved_grams:
			if Ore.METALS.has(str(metal)) and int(saved_grams[metal]) > 0:
				metal_grams[str(metal)] = int(saved_grams[metal])
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
	fishing.ring_found = bool(data.get("fished_ring", false))
	treasure_maps.load_from(data.get("treasure_maps", {}))
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
	player.gift_points = int(data.get("gift_points", 0))
	player.gift_constitution = int(data.get("gift_constitution", 0))
	player.beginner_shrines_used = int(data.get("beginner_shrines_used", 0))
	Blessing.load_from(player, data.get("blessing", {}))
	Injury.load_from(player, data.get("injury", {}))
	player.refresh_stats()
	player.gift_spent = {}
	var gift_spent = data.get("gift_spent", {})
	if gift_spent is Dictionary:
		for id in gift_spent:
			if id in HeroLevel.POINT_ATTRIBUTES:
				player.gift_spent[id] = int(gift_spent[id])
	player.equipped = data.equipped
	player.wear = data.get("wear", {})
	player.set_sex(str(data.get("sex", BodyLook.DEFAULT))) # Games saved before there were heroines have a hero.
	player.set_hair(data.get("hair", {}))
	player.set_cape_design(CapeDesigns.checked(data.get("cape", CapeDesigns.DEFAULT))) # Older games wear the devilbane logo.
	player.xp = Training.load_hero(hero_name)
	player.set_level_data(Training.load_level(hero_name))
	lore.assign(data.get("lore", []))
	# Wall writings saved before they were written in blood.
	for i in lore.size():
		lore[i] = Level.OLD_WRITINGS.get(lore[i], lore[i])
		if lore[i] == OLD_DARK_LEARN:
			lore[i] = DARK_LEARN
		elif lore[i] == OLD_KNIFE_LORE:
			lore[i] = KNIFE_LORE
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
	var saved_slimes = data.get("slimes", [])
	wild_slimes = saved_slimes if saved_slimes is Array else []
	_slimes_fresh = true
	floors.clear()
	var saved_floors = data.get("floors", {})
	if saved_floors is Dictionary:
		for key in saved_floors:
			if saved_floors[key] is Array:
				floors[str(key)] = (saved_floors[key] as Array).filter(func(e): return e is Array and e.size() >= 4)
	escaped = bool(data.get("escaped", false))
	home_upgrades = _known_keys(data.get("upgrades", []), HomeUpgrades.ALL)
	home_stores = HomeStores.load_from(data.get("home_stores", {}))
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
	season_shift = int(data.get("season_shift", 0))
	bounties.load_from(data.get("bounties", {}))
	bounties.refresh(day)
	crafting.load_from(data.get("crafting", {}))
	wishes.load_from(data.get("wishes", {}))
	reputation.load_from(data.get("reputation", {}))
	village_talk.load_from(data.get("ties", []))
	village_rumours.load_from(data.get("rumours", {}))
	Factions.load_from(data.get("factions", {}))
	MonsterLore.load_from(data.get("monster_lore", {}))
	var plan = data.get("plan", {})
	away_plan = plan if plan is Dictionary and not plan.is_empty() else Offline.empty_plan()
	book_hours.clear()
	var read = data.get("book_hours", {})
	if read is Dictionary:
		for id in read:
			book_hours[String(id)] = clampf(float(read[id]), 0.0, float(Offline.BOOK_HOURS))
	player.bag.assign(data.bag)
	player.home_hp = HomeUpgrades.trophy_hp(HouseFurniture.upgrades_with_stand(home_upgrades, hero_name), trophies)
	player.refresh_stats()
	# Games saved before there was a clock wake up in the morning.
	day_hour = fposmod(float(data.get("hour", DayNight.START_HOUR)), 24.0)
	world_hours = float(data.get("world_hours", 0.0))
	wanderer_night = int(data.get("wanderer_night", -1))
	_load_smith_stock(data.get("smith_stock", null))
	# Games saved before the woodcutter kept a stock start him with a full one.
	timber_stock = clampi(int(data.get("timber_stock", WoodcutterShift.START)), 0, WoodcutterShift.CAP)
	_timber_carry = 0.0
	hoard.load_from(data.get("hoard", {}))
	climber_stock = {}
	climber_day = -1
	climber_watch = 0.0
	var climber: Variant = data.get("climber", {})
	if climber is Dictionary and climber.get("stock") is Dictionary:
		climber_day = int(climber.get("day", -1))
		for id in climber.stock:
			if ClimberNpc.WARES.has(str(id)):
				climber_stock[str(id)] = clampi(int(climber.stock[id]), 0, int(ClimberNpc.WARES[str(id)]))
	wanderer_stock.clear()
	var wares = data.get("wanderer", [])
	if wares is Array:
		for id in wares:
			if Items.ALL.has(str(id)) or Wanderer.is_ingredient(str(id)):
				wanderer_stock.append(str(id))
	# Games saved before there was weather wake up to clear skies.
	set_weather(str(data.get("weather", Weather.CLEAR)), float(data.get("weather_hours", Weather.FIRST_HOURS)))
	puddle_water = clampf(float(data.get("puddles", 0.0)), 0.0, 1.0)
	snow_cover = clampf(float(data.get("snow", 0.0)), 0.0, 1.0)
	ice_cover = clampf(float(data.get("ice", 0.0)), 0.0, 1.0)
	_go_to_wake_place(_wake_place(data))
	player.hp = clampi(int(data.hp), 1, player.max_hp)
	player.cure()
	player.ailments.erase(VillageRun.KIND)
	var run_left := minf(float(data.get("village_run", 0.0)), VillageRun.TIME)
	if run_left > 0.0:
		player.ailments[VillageRun.KIND] = run_left
	_village_run_on = run_left > 0.0
	_update_hud()


## Where a saved game wakes up, by the hero's state as it is now (escaped,
## their own house): {"index": level, "house": town house number inside or 0,
## "inn": in an inn's bed, "camp": the camp (see Camp.from_save) or {},
## "built": the spot in the hero's self-built house (see _built_house_spot) or {}}.
func _wake_place(data: Dictionary) -> Dictionary:
	var index := clampi(int(data.get("level", 0)), 0, level_files.size() - 1)
	var house := 0
	var own_house := Homes.house_of(hero_name)
	var at_inn: bool = data.get("inn", false) and _is_inn_file(index)
	var camp_at := Camp.from_save(data.get("camp"))
	var built := {}
	if at_inn:
		# Saved in the bed of an inn on the way: the hero wakes up there,
		# not back home, so the long road need not be walked again.
		pass
	elif not _built_spot_of(data).is_empty() and _outdoor_index() >= 0:
		# Saved inside the hero's own self-built house or on its plot (any storey, its cellar or
		# its roof): the hero logs back in at that very spot (see _built_house_spot), even when a
		# camp still stands somewhere else in the open air.
		index = _outdoor_index()
		built = _built_spot_of(data)
		camp_at = {}
	elif not camp_at.is_empty():
		# Saved at a camp: the hero wakes up by its fire, wherever it was.
		pass
	elif escaped and home_claimed and own_house > 0 and interiors.has("^"):
		# The hero's own town house is the place to come back to: every
		# load wakes up beside its bed, wherever the game was saved.
		index = interiors["^"]
		house = own_house
	elif escaped and _outdoor_index() >= 0:
		# Out of the dungeon, every load begins in the open air, wherever the
		# game was saved: on the graveyard, or in the hero's own house.
		index = _outdoor_index()
	return {"index": index, "house": house, "inn": at_inn, "camp": {} if at_inn else camp_at, "built": built}


## Loads the level of a wake place (see _wake_place) and puts the hero there:
## at the camp, beside the bed, or where the level starts.
func _go_to_wake_place(place: Dictionary) -> void:
	inside_house = int(place.house)
	load_level(int(place.index), false)
	camp = null
	var camp_at: Dictionary = place.camp
	if not camp_at.is_empty():
		camp = Camp.pitch(level, camp_at.pos, camp_at.rot)
		Camp.clear_around(level, camp.global_position)
		player.global_position = camp.stand_spot()
		player.face(camp.global_position - player.global_position)
		_snap_camera()
	elif _put_in_built_house(place.get("built", {})):
		pass
	elif (level.is_home or level.inn) and level.bed_side != Vector3.ZERO:
		player.global_position = level.bed_side
	elif level is Outdoor and home_claimed and level.home_spot != Vector3.ZERO:
		# The hero's own house is the place to come back to: next to the bed.
		player.global_position = level.home_spot


## Where the hero stands in their own self-built house or on its plot (see HouseSketcher.holds):
## on any storey, down in its cellar or up on its roof, as {"pos": [x, y, z], "facing": angle};
## {} anywhere else. The saved game keeps it, so the hero logs back in there.
func _built_house_spot() -> Dictionary:
	if not level is Outdoor or house_sketcher == null or player == null or not house_sketcher.holds(player.global_position):
		return {}
	var at := player.global_position
	var look := player.facing()
	return {"pos": [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)], "facing": snappedf(atan2(look.x, look.z), 0.01)}


## The spot in the self-built house a saved game was made at, or {} (also for a broken record).
static func _built_spot_of(data: Dictionary) -> Dictionary:
	var spot = data.get("built_house", {})
	if not spot is Dictionary or not spot.get("pos") is Array or spot.pos.size() != 3:
		return {}
	return spot


## Puts the hero back at `spot` in their self-built house (see _built_house_spot), once the
## open air and its houses are built. False (and nothing moves) when there is no such spot,
## or the house no longer has a floor there (the plot given up, the cellar filled in, the
## floor above taken down): the hero then wakes up where they would have without it.
func _put_in_built_house(spot: Dictionary) -> bool:
	if spot.is_empty() or not level is Outdoor or house_sketcher == null:
		return false
	var at := Vector3(float(spot.pos[0]), float(spot.pos[1]), float(spot.pos[2]))
	if not house_sketcher.holds(at, true):
		return false
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	var turn := float(spot.get("facing", 0.0))
	player.face(Vector3(sin(turn), 0.0, cos(turn)))
	_snap_camera()
	return true


func _leave_title(prepare: Callable) -> void:
	state = State.TRANSITION
	_title_buttons.visible = false
	# The language buttons too: left in the faded title, they would lie
	# unseen across the middle of the screen and take the pointer from the
	# life bar and the knives under it.
	_lang_row.visible = false
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


## The hero's whole record, as it is saved: on this computer a save file, on a
## server the character it keeps. Its shape is versioned (see SaveFormat).
func hero_record() -> Dictionary:
	journal.catch_up()
	var data := {
		"version": SaveFormat.VERSION, "name": hero_name, "sex": player.sex, "xp": player.hero_xp, "level": level_index, "coins": coins, "currency": Loot.MONEY, "iron": iron, "bars": bars, "metal_grams": metal_grams, "secrets": secrets_found, "fished_ring": fishing.ring_found, "treasure_maps": treasure_maps.for_save(), "dry": dry_levels, "bumped_person": bumped_person, "hints": hints_shown, "hp": player.hp, "knives": player.knives,
		"gift_hp": player.gift_hp, "gift_power": player.gift_power, "gift_speed": player.gift_speed, "gift_armor": player.gift_armor,
		"gift_points": player.gift_points, "gift_spent": player.gift_spent, "gift_constitution": player.gift_constitution, "beginner_shrines_used": player.beginner_shrines_used,
		"blessing": Blessing.for_save(player), "injury": Injury.for_save(player),
		"equipped": player.equipped, "wear": player.wear, "hair": player.hair, "cape": player.cape_design, "bag": player.bag, "storage": storage, "shop": shop_stock,
		"lore": lore, "plan": away_plan, "book_hours": book_hours, "escaped": escaped, "village_run": snappedf(player.ailments.get(VillageRun.KIND, 0.0), 0.1), "home": _home_given_now(), "claimed": home_claimed,
		"upgrades": home_upgrades.keys(), "trophies": trophies.keys(), "home_stores": HomeStores.for_save(home_stores),
		"saved_at": Time.get_unix_time_from_system(),
		"looted": _looted_for_save(), "met": met.keys(), "builds": _builds_for_save(), "floors": _floors_for_save(), "slimes": _slimes_for_save(),
		"quests": quests.for_save(),
		"journal": journal.for_save(),
		"day": day, "season_shift": season_shift, "bounties": bounties.for_save(),
		"crafting": crafting.for_save(),
		"wishes": wishes.for_save(),
		"reputation": reputation.for_save(),
		"ties": village_talk.for_save(),
		"rumours": village_rumours.for_save(),
		"factions": Factions.for_save(),
		"monster_lore": MonsterLore.for_save(),
		"companions": {"list": companions, "following": following, "trust": trust},
		"hour": day_hour, "world_hours": world_hours,
		"climber": {"stock": climber_stock, "day": climber_day},
		"wanderer": wanderer_stock, "wanderer_night": wanderer_night, "smith_stock": smith_stock, "timber_stock": timber_stock,
		"hoard": hoard.for_save(),
		"weather": weather, "weather_hours": weather_hours, "puddles": puddle_water, "snow": snow_cover, "ice": ice_cover,
		"inn": level.inn,
	}
	var built := _built_house_spot()
	if not built.is_empty():
		data.built_house = built
	return data


## Writes everything needed to wake up in this safe room later. True when
## the file is really there afterwards. Going away also writes the hero's
## plan for the time away and when the player left.
func save_game(going_away := false) -> bool:
	if playtest_file != "":
		return false
	Training.save_hero(hero_name, player.xp, player.level_data())
	var data := hero_record()
	if has_camp():
		# Saved at a camp: the game wakes up there. The floor is kept as
		# the hero leaves it (monsters slain, doors open, the key), so it is
		# the same quiet spot after a reload. (The open air keeps no such
		# record: its monsters come back with the days anyway.)
		if not level.outdoor:
			level.note_left()
			data.looted = _looted_for_save()
		data.camp = camp.for_save()
	if going_away:
		data.away = {"plan": Offline.normalized(away_plan, away_choices()), "since": Time.get_unix_time_from_system()}
	var path := save_path()
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var saved := FileAccess.file_exists(path)
	if saved and save_notice != null:
		save_notice.flash()
	return saved


## The stone blocks per level file, levels without any left out.
func _builds_for_save() -> Dictionary:
	var out := {}
	for file in builds:
		if not builds[file].is_empty():
			out[file] = builds[file]
	return out


## What lies on each level's floor, levels with nothing left out.
## Notes the open air's slimes as the hero leaves it (see wild_slimes).
func _keep_slimes() -> void:
	if _slimes_fresh:
		_slimes_fresh = false
		return
	if level is Outdoor and is_instance_valid(level):
		wild_slimes = SlimeGrowth.snapshot(level)


## The slimes for the saved game: as they are now when the hero is in the
## open air, else as they were left.
func _slimes_for_save() -> Array:
	return SlimeGrowth.snapshot(level) if level is Outdoor and is_instance_valid(level) else wild_slimes


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
	if Items.is_backpack(id):
		var at := pack_spot()
		if at != Vector3.INF and level.put_pack(id, at) != null:
			Sfx.play_gear(level, id, 0.0, at)
			return
		# No room for a pack here: it falls at the hero's feet like any item.
	var ahead := -player.global_transform.basis.z
	ahead.y = 0.0
	var spot := player.global_position + (ahead.normalized() * 0.6 if ahead.length() > 0.01 else Vector3.ZERO)
	level.put_on_floor(id, spot)
	Sfx.play_gear(level, id, 0.0, spot)


## Where a backpack can be set down in front of the hero (it is solid, so it
## must not stand on them or in a wall): straight ahead, else to the sides.
## Vector3.INF when there is no room.
func pack_spot() -> Vector3:
	if level == null or player == null:
		return Vector3.INF
	var ahead := -player.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	for turn in [0.0, 0.8, -0.8, 1.6, -1.6]:
		for reach in [1.4, 1.8]:
			var at: Vector3 = player.global_position + ahead.rotated(Vector3.UP, turn) * reach
			at.y = 0.0
			if not level.pack_blocked(at):
				return at
	return Vector3.INF


## The floor pack being worked in its window (see FloorPack), or null.
var open_pack: FloorPack = null


## Opens the window of the pack in reach (or `pack`). Returns "" on success,
## else why not.
func open_floor_pack(pack: FloorPack = null) -> String:
	if not player.can_act() or player.is_climbing():
		return Lang.t("Gerade nicht.")
	if pack == null:
		pack = level.pack_in_reach(player)
	elif level._flat_distance(player.global_position, pack.global_position) > FloorPack.REACH:
		return Lang.t("Der Rucksack ist zu weit weg.")
	if pack == null:
		return Lang.t("Kein Rucksack in Reichweite.")
	player.path.clear()
	player.face(pack.global_position - player.global_position)
	player.play("Idle")
	open_pack = pack
	menus.open("bodenrucksack")
	return ""


## Pushes the pack in reach one step away from the hero. "" on success.
func push_floor_pack() -> String:
	var pack := level.pack_in_reach(player)
	if pack == null:
		return Lang.t("Kein Rucksack in Reichweite.")
	if not player.can_act() or player.is_climbing():
		return Lang.t("Gerade nicht.")
	player.path.clear()
	player.face(pack.global_position - player.global_position)
	player.play_once("Interact", 0.3)
	if not level.push_pack(pack, player.global_position):
		return Lang.t("Der Rucksack rührt sich nicht: Etwas ist im Weg.")
	Sfx.play(self, "gear_soft_%d" % (randi() % 2), -2.0)
	return ""


## Takes the open pack back into the bag; it must be empty.
func take_floor_pack(pack: FloorPack) -> String:
	if pack == null or not is_instance_valid(pack):
		return ""
	if not pack.is_empty():
		return Lang.t("Leere den Rucksack zuerst: Was darin liegt, bleibt darin.")
	if not player.bag_fits(pack.backpack()):
		return Lang.t("Deine Tasche ist voll.")
	var id := pack.backpack()
	if not level.take_pack(pack):
		return ""
	player.bag.append(id)
	Sfx.play(self, "gear_soft_%d" % (randi() % 2), -2.0)
	_update_hud()
	return ""


## Gives the hero throwing knives: ready in the belt up to Player.knife_cap,
## the rest into the bag, and what the bag cannot hold at their feet.
func give_knives(count: int) -> void:
	for i in player.add_knives(count):
		drop_on_floor(Items.KNIFE)
	_update_hud()


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


## Rests in the bed of an inn till the next morning without logging out
## (see rest_till_morning).
func rest_at_inn() -> void:
	if level.inn:
		rest_till_morning()


## Sleeps in a bed till the next morning without logging out: the one world
## clock jumps to WAKE_HOUR (a new day if dawn passes, with fresh weather,
## dry puddles and the respawn timers of every level moved on by the hours
## slept), life is full, poison and curses are gone, and the game is saved
## right there. Works in any bed: an inn, the hero's house, the refuge.
func rest_till_morning() -> void:
	if state != State.PLAYING:
		return
	state = State.TRANSITION
	# Lying down in the hero's own house, under a household goddess's blessing.
	var goddess := HouseholdGods.active(self)
	player.frozen = true
	player.path.clear()
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
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
		_rest_injury(goddess)
		if _dawn_between(day_hour, DayNight.WAKE_HOUR):
			_new_day(true)
		world_hours += fposmod(DayNight.WAKE_HOUR - day_hour, 24.0)
		day_hour = DayNight.WAKE_HOUR
		set_weather(Weather.roll(day_hour, _weather_rng, "", Weather.season(season_day())))
		# The puddles dried up overnight, and the snow melted (in winter it stays).
		puddle_water = 0.0
		if not Weather.is_winter(season_day()):
			snow_cover = 0.0
		player.hp = player.max_hp
		player.cure()
		_update_hud()
		var saved := save_game()
		var woke := Lang.t("Ausgeruht! Hier unten ist es immer Nacht, aber du bist wieder bei Kräften.") if AshSpire.is_floor(level) else Lang.t("Ausgeruht! Ein neuer Morgen in den Bergen.")
		show_message(woke + ("" if saved else "\n" + Lang.t("Speichern fehlgeschlagen!")), 3.5)
		# The night lifts while the hero is still lying there: the waking up plays from the bed.
		create_tween().tween_property(_fade, "color:a", 0.0, 1.0))
	if bed.is_empty():
		tween.tween_callback(func():
			var stand := level.bed_side if level.bed_side != Vector3.ZERO else player.global_position
			player.global_position = stand
			player.face(Vector3.BACK)
			player.set_asleep(false)
			player.play("Idle")
			_snap_camera()
			player.frozen = false
			state = State.PLAYING)
	else:
		var rot: float = bed.get("rot", 0.0)
		var floor_spot := _bedside(bed, Vector3(sin(rot), 0.0, cos(rot)))
		var side := BedRise.choose_side(level, bed.pos, rot, floor_spot, [player.get_rid()])
		_rise_from_bed(tween, bed, side, false, func():
			state = State.PLAYING)


## The camp's "rest by the fire" on a dungeon floor (see Camp): the hero
## lies down on the bedroll and sleeps a while. Mostly they get up rested,
## with full life, and the game is saved at the camp, which makes it the
## spot they wake up at after blacking out (see _wake_after_rescue). But
## now and then (Camp.ambush_chance) monsters creep up to the fire: the
## rest is cut short with only half the lost life back, nothing is saved,
## and the hero has to fight. A companion at their side keeps watch
## instead of lying down, which makes an ambush rarer, or stops it.
##
## `roll` is the dice for the ambush, for tests; below 0 it is rolled.
func rest_at_camp(roll := -1.0) -> void:
	if state != State.PLAYING or not has_camp() or not Camp.can_rest(level):
		return
	var why := Camp.why_no_rest(player, level)
	if why != "":
		show_message(why, 2.4)
		return
	var guard := camp_guard()
	var ambushed := (roll if roll >= 0.0 else randf()) < Camp.ambush_chance(level, guard)
	learn(CAMP_REST_LEARN)
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_lie_down_at_camp(tween)
	tween.tween_interval(1.9)
	tween.tween_callback(_fall_asleep)
	tween.tween_interval(1.6)
	if ambushed:
		tween.tween_callback(_camp_ambushed.bind(guard))
		return
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 1.2)
	tween.tween_callback(func():
		_stop_snoozing()
		player.set_asleep(false)
		player.hp = player.max_hp
		player.cure()
		player.global_position = camp.stand_spot()
		player.reset_physics_interpolation()
		player.face(camp.global_position - player.global_position)
		player.play("Idle")
		_snap_camera()
		_update_hud()
		var saved := save_game()
		player.frozen = false
		state = State.PLAYING
		show_message(Lang.t("Ausgeruht! Du hast wieder volles Leben.") + ("" if saved else "\n" + Lang.t("Speichern fehlgeschlagen!")), 3.5))
	tween.tween_property(_fade, "color:a", 0.0, 1.0)


const CAMP_REST_LEARN := "Im Verlies kannst du dich an deinem Lager ausruhen: Du bekommst volles Leben, das Spiel wird gespeichert, und nach einer Ohnmacht wachst du dort auf. Doch manchmal schleichen sich Ungeheuer an (30 %) und wecken dich mit nur halb geheilten Wunden. Ein Gefährte hält Wache: Mit Fuchs (10 %) oder Reh (15 %) wird es seltener, an einen Hirsch wagt sich keiner heran."


## The companion at the hero's side that keeps watch at the camp: its kind
## (see Camp.GUARDS), or "" when none goes with the hero.
func camp_guard() -> String:
	if not is_instance_valid(pet):
		return ""
	var kind: String = companion().get("kind", pet.kind)
	return kind if Camp.GUARDS.has(kind) else ""


## A rest by the fire cut short: a twig snaps, the hero wakes with half
## their lost life back and gets up, and the monsters step out of the dark
## and come for them. Nothing is saved.
func _camp_ambushed(guard: String) -> void:
	_stop_snoozing()
	player.set_asleep(false)
	player.hp = mini(player.max_hp, player.hp + ceili((player.max_hp - player.hp) / 2.0))
	_update_hud()
	Sfx.play(self, "word_knack", -2.0, camp.global_position)
	var slot := player.find_child("HeadSlot", true, false) as Node3D
	var head := slot.global_position if slot else player.global_position
	Effects.float_text(level, head + Vector3(0, 0.8, 0), "!", Color(1.0, 0.5, 0.3), true)
	var text := Lang.t("Ein Hinterhalt! Ungeheuer schleichen sich an dein Lager heran.")
	if guard != "":
		text = Lang.t("%s schlägt Alarm und weckt dich: Ein Hinterhalt!") % companion().get("name", Companions.species_name(guard))
	show_message(text, 3.5, Color(1.0, 0.75, 0.5))
	player.get_up_from_bed()
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(Player.GET_UP_TIME)
	tween.tween_callback(func():
		if has_camp():
			player.global_position = camp.stand_spot()
			player.reset_physics_interpolation()
		player.play("Idle", 0.2)
		player.frozen = false
		state = State.PLAYING
		_spawn_ambush())


## The monsters of an ambush (see Camp): a few of the floor's own kinds
## turn up out of the dark around the camp, already after the hero.
func _spawn_ambush() -> Array[Enemy]:
	var made: Array[Enemy] = []
	var kinds := Camp.ambush_kinds(level)
	if kinds.is_empty():
		return made
	var at := camp.global_position if has_camp() else player.global_position
	for c in Camp.ambush_cells(level, at, Camp.AMBUSHERS):
		var e: Enemy = level._spawn_enemy(kinds[randi() % kinds.size()], c)
		e.alert(player.global_position)
		made.append(e)
	return made


## The bed's "stay awake": saves the game where the hero stands, without
## logging out, and shows the saved games. Closing that window carries on.
func stay_awake() -> void:
	var saved := save_game()
	menus.saved_now = "ok" if saved else "failed"
	menus.open("laden")


## A night of rest mends what a rescue left (see Injury); in a bed of the hero's own house under
## a household goddess who mends (see HouseholdGods), the night counts for more.
func _rest_injury(goddess := "") -> void:
	var had := player.injury
	if had != "" and Injury.rest(player, HouseholdGods.rest_nights(goddess)):
		Events.tell(Lang.t("Deine Verletzung ist verheilt."), Color(0.55, 1.0, 0.6))
		_update_hud()
	elif had != "":
		_update_hud()


## A night in the bed, or by the fire of the camp (`at_camp`, see Camp):
## the game is saved, the hero lies down and falls asleep, and the player
## logs out.
func sleep(at_camp_now := false) -> void:
	at_camp_now = at_camp_now and has_camp()
	# A night in the bed: the hero wakes up the next morning. In their own house a household
	# goddess may bless the night (see HouseholdGods): wounds mend faster, and with her life per
	# second the hero wakes up with full life.
	var goddess := "" if at_camp_now else HouseholdGods.active(self)
	_rest_injury(goddess)
	if HouseholdGods.perk(goddess, "regen") > 0.0:
		player.hp = player.max_hp
	if level.outdoor or level.building != "":
		if _dawn_between(day_hour, DayNight.WAKE_HOUR):
			_new_day(true)
		world_hours += fposmod(DayNight.WAKE_HOUR - day_hour, 24.0)
		day_hour = DayNight.WAKE_HOUR
		# A new morning brings new weather, and the puddles dried up overnight.
		set_weather(Weather.roll(day_hour, _weather_rng, "", Weather.season(season_day())))
		puddle_water = 0.0
		if not Weather.is_winter(season_day()):
			snow_cover = 0.0
	if level.inn:
		# A night in an inn's bed: the hero gets up rested.
		player.hp = player.max_hp
		player.cure()
	var saved := save_game(true)
	# A failed save says so at once (a good one shows the save notice).
	if not saved:
		show_message(Lang.t("Speichern fehlgeschlagen!"), 2.4)
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var bed := {} if at_camp_now else _nearest_bed()
	if at_camp_now:
		_lie_down_at_camp(tween)
	elif bed.is_empty():
		player.play("Lie_Down", 0.2)
	else:
		_climb_into_bed(tween, bed)
	if is_instance_valid(pet):
		# The fox goes to bed too: into its basket beside the hero's bed. A
		# doe or a stag lies down where it is, and so does the fox at a camp.
		pet.go_to_bed(level.fox_bed_near(bed.pos if not bed.is_empty() else player.global_position) if pet.kind == "fuchs" and not at_camp_now else Vector3.INF)
	# Settled on the back, the hero closes their eyes and drifts off: a few
	# floating Z's and some soft snoring before the night falls.
	tween.tween_interval(1.9)
	tween.tween_callback(_fall_asleep)
	tween.tween_interval(2.6)
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 1.6)
	tween.tween_callback(func():
		_stop_snoozing()
		_log_out(saved))


## Set to false by tests that sleep and must live on afterwards.
var quit_on_log_out := true
## Sent when the player has slept and logged out, after the save was tried.
signal logged_out(saved: bool)


## The end of "sleep and log out": the game was saved first (see `sleep`), now
## the desktop version closes. A browser tab shows its goodbye page instead.
## If the save failed the game stays open on the title, so nothing is lost
## unseen.
func _log_out(saved: bool) -> void:
	logged_out.emit(saved)
	# Out of the bed pose, standing beside the bed, for the game that goes on (a test, the title).
	if player.in_bed_pose():
		var bed := _nearest_bed()
		var rot: float = bed.get("rot", 0.0)
		var spot := _bedside(bed, Vector3(sin(rot), 0.0, cos(rot))) if not bed.is_empty() else player.global_position
		player.bed_pose_end(spot, Vector3.BACK)
	if not quit_on_log_out:
		_show_start_title(Lang.t("Gute Nacht"), Lang.t("Dein Spiel ist gespeichert.") if saved else Lang.t("Speichern fehlgeschlagen!"))
		return
	if not saved:
		_show_start_title(Lang.t("Gute Nacht"), Lang.t("Speichern fehlgeschlagen!"))
	elif OS.has_feature("web"):
		_close_tab()
	else:
		get_tree().quit()


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
	label.font_size = UiKit.sized(72 - i * 7)
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


## How high the mattress of the bed lies (see Level.lie_spot, where the hero lies).
const BED_MATTRESS_HEIGHT := Level.MATTRESS_HEIGHT


## Where the hero lies in `bed`: on the mattress with the head on the pillows.
func _bed_lie_spot(bed: Dictionary) -> Vector3:
	return Level.lie_spot(bed.pos, bed.get("rot", 0.0), player.body_scale())


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


## A few steps onto the bedroll of the camp, then the hero lies down on
## their back with the head on its rolled-up end.
func _lie_down_at_camp(tween: Tween) -> void:
	var spot := camp.lie_spot()
	var from := player.global_position
	var foot := camp.foot()
	player.velocity = Vector3.ZERO
	player.face(spot - from)
	player.play("Walking_A", 0.1)
	tween.tween_method(func(t: float):
		player.global_position = from.lerp(spot, t), 0.0, 1.0, 0.5)
	tween.tween_callback(func():
		# Lying down falls backwards, so face the foot of the bedroll.
		player.face(foot)
		player.play("Lie_Down", 0.15)
		# Settling down, the head comes to rest up on the pillows.
		player.lean_on_pillow(true, 0.9))


## A game saved asleep at a camp starts there: the hero lies on the bedroll
## by the fire while the night fades, opens their eyes, yawns and gets up.
## `done` runs once the hero can move again. Returns false (and does
## nothing) if the game was not saved asleep at a camp.
func _wake_at_camp(data: Dictionary, done: Callable) -> bool:
	if not saved_in_bed(data) or Camp.from_save(data.get("camp")).is_empty() or not has_camp():
		return false
	_waking = true
	state = State.TRANSITION
	var lie := camp.lie_spot()
	var stand := Vector3(lie.x, camp.global_position.y, lie.z)
	player.frozen = true
	player.path.clear()
	player.velocity = Vector3.ZERO
	player.global_position = lie
	player.reset_physics_interpolation()
	player.face(camp.foot())
	player.lie_asleep()
	_fall_asleep()
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(WAKE_SLEEP)
	tween.tween_callback(func():
		_stop_snoozing()
		player.set_asleep(false))
	tween.tween_interval(WAKE_YAWN)
	tween.tween_callback(func():
		var slot := player.find_child("HeadSlot", true, false) as Node3D
		var head := slot.global_position if slot else player.global_position
		Effects.float_text(level, head + Vector3(0, 0.8, 0), Lang.t("Gähn!"), Color(0.85, 0.9, 1.0), true))
	tween.tween_interval(WAKE_STRETCH)
	tween.tween_callback(player.get_up_from_bed)
	tween.tween_interval(Player.GET_UP_TIME)
	tween.tween_callback(func():
		player.global_position = stand
		player.play("Idle", 0.2)
		player.frozen = false
		_waking = false
		state = State.PLAYING
		done.call())
	return true


## Goes to bed (see BedRise): a few steps to the side of the bed, then the hero sits on its rim, swings the
## legs up, lies back with the head on the pillows and pulls the blanket up (see BedBlanket). The weapon is
## put away first: nobody goes to bed with a knife in their hand.
func _climb_into_bed(tween: Tween, bed: Dictionary) -> void:
	var rot: float = bed.get("rot", 0.0)
	var foot := Vector3(sin(rot), 0.0, cos(rot))
	var side := BedRise.choose_side(level, bed.pos, rot, _bedside(bed, foot), [player.get_rid()])
	var spot := BedRise.beside(bed.pos, rot, side)
	var from := player.global_position
	player.velocity = Vector3.ZERO
	player.face(spot - from)
	player.play("Walking_A", 0.1)
	tween.tween_method(func(t: float):
		player.global_position = from.lerp(spot, t), 0.0, 1.0, 0.4)
	BedRise.play(tween, player, BedRise.TUCK_KEYS, bed.pos, rot, side, [
		[BedRise.BLANKET_ON_AT, func(): BedBlanket.tuck(level, bed.pos, rot)]])


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
	if not _wake_at_camp(data, _return_from_away.bind(data)) and not _wake_in_bed(data, _return_from_away.bind(data)):
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
	var floor_spot := _bedside(bed, foot)
	var side := BedRise.choose_side(level, bed.pos, rot, floor_spot, [player.get_rid()])
	player.frozen = true
	player.path.clear()
	player.velocity = Vector3.ZERO
	# Lying asleep under the blanket, in the pose the bed was gone to.
	player.bed_pose(BedRise.at(BedRise.RISE_KEYS, 0.0, side), bed.pos, rot, side)
	BedBlanket.tuck(level, bed.pos, rot, true)
	var fox_wakes := false
	if is_instance_valid(pet) and pet.kind == "fuchs":
		var basket := level.fox_bed_near(bed.pos)
		if basket != Vector3.INF:
			pet.sleep_in_basket(basket)
			fox_wakes = true
	_fall_asleep()
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(WAKE_SLEEP)
	tween.tween_callback(_stop_snoozing)
	_rise_from_bed(tween, bed, side, fox_wakes, func():
		_waking = false
		state = State.PLAYING
		done.call())
	return true


static func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Where the hero stands after getting out of `bed`: beside the foot of a bed in
## a self-built house, the open floor beside it (the same spot a load in the
## hero's own house starts on), or else in front of its foot.
func _bedside(bed: Dictionary, foot: Vector3) -> Vector3:
	# A bed of a self-built house: beside its own foot, on its own storey (see HouseFurnisher).
	if bed.get("side", Vector3.ZERO) != Vector3.ZERO:
		return bed.side
	if level is Outdoor and level.home_spot != Vector3.ZERO:
		return level.home_spot
	var cell: Vector2i = bed.get("cell", Vector2i(-1, -1))
	if cell != Vector2i(-1, -1):
		var side := level._open_side(cell)
		if side != cell:
			return level.cell_to_world(side)
	return bed.pos + foot * 2.2


## The waking up in bed (see BedRise), appended to `tween`: the blanket is pushed off, the legs swing out,
## the hero sits on the rim, stretches and yawns (the yawn with its own sound), the fox wakes and hops out
## of its basket (`fox_wakes`), and the hero slides down and stands beside the bed, where they stay.
## `done` runs once the hero can be moved again.
func _rise_from_bed(tween: Tween, bed: Dictionary, side: float, fox_wakes: bool, done: Callable) -> void:
	var rot: float = bed.get("rot", 0.0)
	var foot := Vector3(sin(rot), 0.0, cos(rot))
	var floor_spot := _bedside(bed, foot)
	BedRise.play(tween, player, BedRise.RISE_KEYS, bed.pos, rot, side, [
		[BedRise.BLANKET_OFF_AT, func(): BedBlanket.push_off(level, bed.pos, rot)],
		[BedRise.YAWN_AT, func():
			Sfx.play(self, "yawn", -4.0, player.global_position)
			var slot := player.find_child("HeadSlot", true, false) as Node3D
			var head := slot.global_position if slot else player.global_position
			Effects.float_text(level, head + Vector3(0, 0.8, 0), Lang.t("Gähn!"), Color(0.85, 0.9, 1.0), true)],
		[BedRise.FOX_AT, func():
			if fox_wakes and is_instance_valid(pet):
				pet.wake_up(floor_spot)]])
	# The hero stays exactly where the get-out animation left them, beside the bed, facing away from it:
	# no walk to another spot and no snap, only the clips take over from the posed bones. The end is a
	# method and not a lambda, and a watchdog finishes it if the tween ever dies half-way, so the hero
	# never stays lying in bed with closed eyes.
	_rise_pending = true
	_rise_tween = tween
	_rise_rot = rot
	_rise_side = side
	_rise_done = done
	tween.tween_callback(_finish_rise)
	get_tree().create_timer(RISE_WATCH).timeout.connect(_watch_rise)


## How often the watchdog of the waking up looks at the tween (seconds).
const RISE_WATCH := 0.5
var _rise_pending := false
var _rise_tween: Tween = null
var _rise_rot := 0.0
var _rise_side := 1.0
var _rise_done := Callable()


## The end of the waking up (see _rise_from_bed): up and standing beside the bed, eyes open, free to move.
## Runs once, from the tween or from the watchdog.
func _finish_rise() -> void:
	if not _rise_pending:
		return
	_rise_pending = false
	var done := _rise_done
	_rise_done = Callable()
	_stop_snoozing()
	if player.in_bed_pose():
		player.bed_pose_end(player.global_position, Basis(Vector3.UP, _rise_rot) * Vector3(_rise_side, 0.0, 0.0))
	player.set_asleep(false)
	player.frozen = false
	if done.is_valid():
		done.call()


## Watches the waking up: if its tween stopped before the end (an error in one of its steps, a freed
## node), the hero is released at once instead of lying in bed forever.
func _watch_rise() -> void:
	if not _rise_pending:
		return
	var alive := _rise_tween != null and _rise_tween.is_valid() and _rise_tween.is_running()
	if alive or get_tree().paused:
		get_tree().create_timer(RISE_WATCH).timeout.connect(_watch_rise)
		return
	_finish_rise()


# --- Time away ----------------------------------------------------------------

## What the hero can do while the player is away, right now: block -> ids.
## Jobs the hero is fit for, attributes and skills that can still grow (a
## skill only with its gear worn), books the hero owns (in the bag, the
## storage chest or on the bookshelf) and every recipe.
func away_choices() -> Dictionary:
	var jobs := Offline.JOBS.keys().filter(func(id): return player.can_use(Offline.JOBS[id].get("requires", {})))
	var train := []
	for id in Offline.TRAINABLE:
		if player.attribute(id) < Training.ATTRIBUTES[id].max:
			train.append(id)
	for id in Training.SKILLS:
		if player.skill_enabled(id) and player.trained_level(id) < Training.skill_max(id):
			train.append(id)
	var books := []
	var owned: Array = player.bag.duplicate()
	owned.append_array(storage)
	owned.append_array(home_stores.get(HomeStores.BOOKS, {}).keys())
	for id in owned:
		if Items.is_book(id) and not id in books and not Offline.book_used_up(book_hours, id):
			books.append(id)
	var crafts := Offline.RECIPES.keys().filter(reputation.can_craft)
	var house := []
	if _house_work_open():
		house.append(Offline.BUILD_HOUSE)
	return {"job": jobs, "train": train, "study": books, "craft": crafts, "build": house}


## The hero's house sketch, or null without a plot.
func _house_plan() -> HouseSketch:
	var plot := Plots.plot_of(hero_name)
	if plot.size == Vector2i.ZERO:
		return null
	return HouseSketch.of(hero_name, plot)


## True while the hero's sketch has pieces to build or to take down.
func _house_work_open() -> bool:
	var house := _house_plan()
	return house != null and house.open_pieces() > 0


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
	var read := float(book_hours.get(String(plan.study), 0.0))
	var result := Offline.simulate(plan, hours, HomeUpgrades.has(home_upgrades, "werkstatt") or HouseFurniture.of(hero_name).standing("werkbank") > 0, read)
	away_report = _apply_away(plan, result)
	var night := _sleep_night(real_seconds, data)
	away_report.push_front(Lang.t("Du warst %s weg, für %s vergingen %s.") % [
			_real_time_text(real_seconds), hero_name, Offline.duration_text(hours)])
	if real_seconds > Offline.MAX_REAL_SECONDS:
		away_report.append(Lang.t("Mehr als 8 Tage (32 Stunden) zählen nicht."))
	# Saving again without "away" makes sure the same time never counts twice.
	save_game()
	_update_hud()
	menus.open("rueckkehr")
	_tell_night(night)


## The night after the player was away `real_seconds`: at least
## SleepRoll.NIGHT_SECONDS, or any sleep while the hero is still new (see
## SleepRoll). Rolls the ripe skills and returns what happened, with where and
## how long the hero slept ({} if it was no night).
func _sleep_night(real_seconds: float, data: Dictionary) -> Dictionary:
	if real_seconds < SleepRoll.NIGHT_SECONDS and player.hero_level() > SleepRoll.FIRST_NIGHTS_LEVEL:
		return {}
	var place := "bed"
	if level != null and level.inn:
		place = "inn"
	elif has_camp() and not Camp.from_save(data.get("camp")).is_empty():
		place = "camp"
	elif level is Outdoor and _home_given_now():
		place = "home"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var wisdom := player.attribute("weisheit")
	var result := SleepRoll.night(player.sleep_state, player.xp, place, real_seconds / 3600.0, wisdom,
			func(id: String) -> float: return player.skill_attribute_average(id), day, rng)
	result.hours = real_seconds
	result.place = place
	result.lines = []
	for id in result.practised:
		if not result.missed.has(id) and not result.won.any(func(w): return w.id == id):
			result.missed.append(id)
	return result


## The event board message "since your last logout" and the speech bubbles of
## the levels the night gave (see SleepRoll): no summary window, no numbers.
func _tell_night(night: Dictionary) -> void:
	if night.is_empty():
		return
	var state: Dictionary = player.sleep_state
	var lines: Array[String] = [Lang.t("Seit deiner letzten Abmeldung:"),
			Lang.t("Geschlafen: %s (%s)") % [_real_time_text(float(night.hours)), Lang.t(SLEEP_PLACE_NAMES[night.place])]]
	for w in night.won:
		var line := Lang.t("%s: Stufe %d!") % [Lang.t(Training.SKILLS[w.id].name), w.level]
		if w.flash:
			line = Lang.t("Geistesblitz! ") + line
		lines.append(line)
		if CharacterPage.SKILL_EFFECTS.has(w.id):
			lines.append("  " + Lang.t(CharacterPage.SKILL_EFFECTS[w.id]))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shown := 0
	for id in night.missed:
		if shown >= 4:
			break
		shown += 1
		lines.append(Lang.t("Über %s: „%s“") % [Lang.t(Training.SKILLS[id].name), SleepRoll.short_line(state, id, rng)])
	Events.found("\n".join(lines), GOLD)
	_journal_night(night)
	Training.save_hero(hero_name, player.xp, player.level_data())
	if not night.won.is_empty():
		_show_breakthroughs(night.won)


## The journal notes a night that gave the skills a roll ("Resting"), and a
## line for every skill that broke through. Failed rolls get no line.
func _journal_night(night: Dictionary) -> void:
	if night.practised.is_empty() and night.won.is_empty() and night.missed.is_empty():
		return
	var file := journal.current_file()
	journal.write("Ausgeruht", [], file)
	for w in night.won:
		journal.write("Durchbruch im Schlaf: %s, Stufe %s", [Training.SKILLS[w.id].name, str(w.level)], file)


const SLEEP_PLACE_NAMES := {"ground": "unter freiem Himmel", "camp": "am Lagerfeuer", "bed": "im Bett", "inn": "im Gasthaus", "home": "im eigenen Bett"}


## A speech bubble over the waking hero for every level the night gave, one
## after the other; a flash of insight comes last, golden and longer.
func _show_breakthroughs(won: Array) -> void:
	var ordered := won.filter(func(w): return not w.flash)
	ordered.append_array(won.filter(func(w): return w.flash))
	var bubble := SpeechBubble.new()
	bubble.position.y = 3.2
	player.add_child(bubble)
	for w in ordered:
		if not is_instance_valid(player) or not is_instance_valid(bubble):
			return
		var who := "%s %d" % [Lang.t(Training.SKILLS[w.id].name), w.level]
		bubble.set_gold(w.flash)
		bubble.show_line(who, Lang.t(SleepRoll.EUREKA) if w.flash else Lang.t(SleepRoll.SHOUTS[randi() % SleepRoll.SHOUTS.size()]))
		if w.flash:
			Effects.float_text(level, player.global_position + Vector3(0, 4.2, 0), Lang.t(SleepRoll.EUREKA), Color(1.0, 0.85, 0.25))
			Sfx.play(self, "key", -2.0)
		await get_tree().create_timer(SleepRoll.EUREKA_SECONDS if w.flash else SleepRoll.BUBBLE_SECONDS).timeout
		if is_instance_valid(bubble):
			bubble.hide_line()
			await get_tree().create_timer(0.4).timeout
	if is_instance_valid(bubble):
		bubble.queue_free()


## Gives the hero what the time away brought; returns a line for each thing.
func _apply_away(plan: Dictionary, result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var spent: Dictionary = result.spent
	var before := {}
	for id in Training.ATTRIBUTES:
		before[id] = player.attribute(id)
	# No floating texts for each new point: the window lists them all.
	player.set_block_signals(true)
	for id in result.xp:
		player.train(id, result.xp[id])
	for id in result.study_xp:
		player.train(id, result.study_xp[id], false)
	player.set_block_signals(false)
	coins += int(result.gold)
	give_knives(int(result.knives))
	var repaired := _repair_gear(int(result.repairs))
	# Cut stone blocks go into the storage chest, as many as it still holds.
	var stones := 0
	for i in int(result.get("stones", 0)):
		if not HomeUpgrades.storage_fits(home_upgrades, storage, Menus.STONE):
			break
		storage.append(Menus.STONE)
		stones += 1
	if spent.job > 0.0:
		lines.append(Lang.t("%s: %s, +%d Kupfer") % [Lang.t(Offline.JOBS[plan.job].name), Offline.duration_text(spent.job), result.gold])
	if spent.train > 0.0:
		lines.append(Lang.t("Training (%s): %s") % [_training_name(plan.train), Offline.duration_text(spent.train)])
	if spent.study > 0.0:
		var book := String(plan.study)
		book_hours[book] = minf(float(Offline.BOOK_HOURS), float(book_hours.get(book, 0.0)) + float(result.study_read))
		lines.append(Lang.t("Gelesen (%s): %s") % [Items.item_name(book), Offline.duration_text(result.study_read)])
		if Offline.book_used_up(book_hours, book):
			lines.append(Lang.t("%s ist ausgelesen: du kannst nichts mehr daraus lernen.") % Items.item_name(book))
		else:
			lines.append(Lang.t("%s: noch %d Std. Lesestoff") % [Items.item_name(book), ceili(Offline.book_left(book_hours, book))])
	if spent.craft > 0.0:
		var made := ""
		if Offline.RECIPES[plan.craft].makes == "knife":
			made = Lang.t("%d Wurfmesser") % result.knives
		elif Offline.RECIPES[plan.craft].makes == "stone":
			made = Lang.t("%d Steinblöcke (in der Truhe)") % stones
		else:
			made = Lang.t("%d Punkte Haltbarkeit") % repaired
		lines.append(Lang.t("%s: %s, %s") % [Lang.t(Offline.RECIPES[plan.craft].name), Offline.duration_text(spent.craft), made])
	if spent.build > 0.0:
		lines.append_array(_build_away(int(result.get("pieces", 0)), spent.build))
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
	# Skills do not level up from training: that waits for the night (see
	# _sleep_night).
	return lines


## The hero works on the house while the player is away: up to `pieces`
## pieces, as far as the plot's stock pays for them.
func _build_away(pieces: int, hours: float) -> Array[String]:
	var lines: Array[String] = []
	var house := _house_plan()
	if house == null:
		return lines
	house.ordered = house.open_pieces() > 0
	var built := 0
	var demolished := 0
	var waiting := false
	for i in pieces:
		var step := house.build_next()
		if step.is_empty():
			break
		if step.has("why"):
			waiting = true
			break
		if step.did == "built":
			built += 1
		else:
			demolished += 1
	house.save(hero_name)
	if house_sketcher != null:
		house_sketcher.plan = null
		house_sketcher.refresh()
	lines.append(Lang.t("Hausbau: %s, %d Teile gebaut, %d abgerissen") % [Offline.duration_text(hours), built, demolished])
	if waiting:
		lines.append(Lang.t("Der Bau ruht: Es fehlt Material auf dem Grundstück."))
	elif house.open_pieces() == 0:
		lines.append(Lang.t("Das Haus steht, wie du es geplant hast."))
	return lines


## Takes away up to `points` of wear, worn gear first; returns how many.
func _repair_gear(points: int) -> int:
	var done := 0
	var order: Array = player.equipped.values()
	order.append_array(player.bag)
	for id in order:
		while done < points and player.wear.get(id, 0) > 0 and not Items.is_broken(id, player.wear[id]):
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
	if level.building == "spire1":
		Events.teach(AshSpire.LEARN_SPIRE)
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


## The chat line under the event log: on screen while the game is played,
## usable while no window or shrine is open. While the hero types, the walking
## keys stop (Player.typing).
func _setup_chat_line() -> void:
	chat_line.shown = func() -> bool: return state in [State.PLAYING, State.TRANSITION]
	chat_line.allowed = chat_allowed
	chat_line.set_hint()
	chat_line.said.connect(_hero_says)
	chat_line.opened.connect(func() -> void: player.typing = true)
	chat_line.closed.connect(func() -> void: player.typing = false)
	_hud.add_child(chat_line)


## The hero said a word that opens this villager's window (see NpcKeywords): it opens.
func ask_villager(v: Villager) -> void:
	if state != State.PLAYING or v.station.is_empty() or not player.can_act():
		return
	_use_station(v.station)


## Whether the hero may chat now.
func chat_allowed() -> bool:
	return state == State.PLAYING and not menus.is_open() and _shrine.is_empty() and player != null and not player.dead


## The hero said `text` through the chat line: it floats over the hero's head
## and goes into the event log (as every spoken line does), and whoever is
## near may answer (see HeroChat).
func _hero_says(text: String) -> void:
	var typed: Variant = Teleport.parse(text)
	if typed != null:
		_teleport_command(String(typed))
		return
	if Godmode.is_command(text):
		_toggle_godmode()
		return
	if HeroUnstick.is_command(text):
		_unstick_command()
		return
	var cam: Variant = CameraCommand.parse(text)
	if cam != null:
		_camera_command(cam)
		return
	var season: Variant = SkyCommand.parse_season(text)
	if season != null:
		_season_command(season)
		return
	var sky: Variant = SkyCommand.parse(text)
	if sky != null:
		_sky_command(sky)
		return
	if _teleport_waits_for(text):
		return
	var pos := player.global_position
	Effects.float_text(level, pos + Vector3(0, 3.0, 0), text, HERO_SAY_COLOR)
	Events.say(hero_name, text, pos)
	Events.hero_says(text, pos)


## Where the hero may always stand: the village square on the open map, else the level's start.
func _safe_home() -> Vector3:
	if level.get("spots") != null and not level.spots.square.is_empty():
		return level.spots.square[0]
	return level.cell_to_world(level.start_cell)


## The chat line's unstuck command (dev builds only, see HeroUnstick).
func _unstick_command() -> void:
	var how := HeroUnstick.release(player, player.free_spot, _safe_home())
	Events.tell(Lang.t(HeroUnstick.DONE_TEXT if how != "" else HeroUnstick.NONE_TEXT), TELEPORT_COLOR)


## The chat line's free camera (see CameraCommand).
func _camera_command(cmd: Dictionary) -> void:
	if cmd.has("help"):
		Events.found(Lang.t(CameraCommand.HELP), TELEPORT_COLOR)
		return
	var was := free_camera
	if cmd.has("off"):
		free_camera = false
	elif cmd.has("toggle"):
		free_camera = not free_camera
	else:
		free_camera = true
	if free_camera and not was:
		free_distance = CAMERA_DISTANCE
		free_pitch = CAMERA_PITCH
	if cmd.has("pitch"):
		free_pitch = cmd.pitch
	if free_camera != was:
		Events.tell(Lang.t(CameraCommand.ON_TEXT) if free_camera else Lang.t(CameraCommand.OFF_TEXT), TELEPORT_COLOR)


const HERO_SAY_COLOR := Color(1.0, 0.95, 0.8)
const TELEPORT_COLOR := Color(0.75, 0.85, 1.0)


## The chat line's "godmode": the hero cannot be harmed and runs three times
## as fast (see Godmode). Typing it again turns it off.
func _toggle_godmode() -> void:
	player.godmode = not player.godmode
	player.refresh_stats()
	if player.godmode:
		player.hp = player.max_hp
	Events.tell(Lang.t(Godmode.ON_TEXT) if player.godmode else Lang.t(Godmode.OFF_TEXT), TELEPORT_COLOR)


## The chat line's weather and time commands (see SkyCommand): force the
## weather, the hour and the season at once. A forced snow lays a full layer
## of snow, so winter can be checked at once.
func _sky_command(sky: Dictionary) -> void:
	if sky.has("error"):
		_sky_help(sky)
		return
	# Any sky command ends a running tour; "showcase" starts a new one.
	var was_touring := _tour_time >= 0.0
	_tour_time = -1.0
	if sky.tour == SkyCommand.TOUR_START:
		_tour_time = 0.0
		_tour_weather = ""
		Events.tell(Lang.t("Himmelstour an: jedes Wetter eine Minute lang durch Tag und Nacht. \"weather:stop\" beendet sie."), TELEPORT_COLOR)
		return
	if sky.tour == SkyCommand.TOUR_STOP:
		if was_touring:
			Events.tell(Lang.t("Himmelstour beendet."), TELEPORT_COLOR)
		return
	_sky_force(sky)


## Seconds into the sky tour, or -1 when none runs (see SkyCommand.tour_at).
var _tour_time := -1.0
var _tour_weather := ""


## One step of the sky tour: the hour sweeps through the day, and the weather
## changes each time it has swept a whole day.
func _tick_tour(delta: float) -> void:
	_tour_time += delta
	var now := SkyCommand.tour_at(_tour_time)
	day_hour = now.hour
	if now.weather != _tour_weather:
		_tour_weather = now.weather
		set_weather(_tour_weather, SkyCommand.HOLD_HOURS)
		if _tour_weather == Weather.SNOW:
			snow_cover = 1.0


func _sky_help(sky: Dictionary) -> void:
	if sky.error != "":
		Events.tell(Lang.t("Unbekanntes Wort \"%s\". Optionen:") % sky.error, TELEPORT_COLOR)
	else:
		Events.tell(Lang.t("Wetter und Zeit erzwingen. Optionen:"), TELEPORT_COLOR)
	for line in SkyCommand.HELP:
		Events.found(Lang.t(line), TELEPORT_COLOR)


## The chat line's season command (see SkyCommand.parse_season): the world switches to the season
## at once, with its leaves, vines and grapes, clothes, snow and the season's weather.
func _season_command(cmd: Dictionary) -> void:
	if cmd.has("error"):
		if cmd.error != "":
			Events.tell(Lang.t("Unbekannte Jahreszeit \"%s\".") % cmd.error, TELEPORT_COLOR)
		Events.found(Lang.t(SkyCommand.SEASON_HELP), TELEPORT_COLOR)
		return
	_tour_time = -1.0
	var season: String = cmd.season
	var now := season_day()
	season_shift += SkyCommand.season_start(now, season) - now
	_check_season()
	var winter := season == Weather.WINTER
	if level is Outdoor:
		# Everyone is dressed (or undressed) on the spot.
		level.set_winter_wear(winter, true)
	snow_cover = 1.0 if winter else 0.0
	puddle_water = 0.0
	set_weather(Weather.SNOW if winter else Weather.CLEAR, SkyCommand.HOLD_HOURS)
	# Show it at once, without the fade of the sky.
	_weather_look = Weather.look(weather)
	Events.tell(Lang.t("Jahreszeit: %s") % Lang.t(SkyCommand.SEASON_NAMES[season]), TELEPORT_COLOR)
	_update_hud()


## Forces the weather, hour and season a command names.
func _sky_force(sky: Dictionary) -> void:
	var parts: Array[String] = []
	var kind: String = sky.weather
	if sky.winter >= 0:
		var now := season_day()
		season_shift += (SkyCommand.autumn_from(now) if sky.get("autumn", false) else SkyCommand.day_for(now, sky.winter == 1)) - now
		if level is Outdoor:
			# The command is instant: everyone is dressed (or undressed) on the spot.
			level.set_winter_wear(sky.winter == 1, true)
		if sky.get("autumn", false):
			parts.append(Lang.t("Herbst an"))
		else:
			parts.append(Lang.t("Winter an") if sky.winter == 1 else Lang.t("Winter aus"))
	elif Weather.is_winter(season_day()) and kind in [Weather.RAIN, Weather.STORM]:
		# There is no rain or storm in winter (see Weather.for_season): end it.
		season_shift += SkyCommand.day_for(season_day(), false) - season_day()
		parts.append(Lang.t("Kein Regen im Winter: der Winter wurde beendet."))
	if sky.hour >= 0.0:
		day_hour = sky.hour
		parts.append(Lang.t("Uhrzeit: %s") % DayNight.clock_text(day_hour))
	if kind != "":
		set_weather(kind, SkyCommand.HOLD_HOURS)
		parts.append(Lang.t("Wetter: %s") % Lang.t(Weather.word(weather)))
		if weather == Weather.SNOW:
			snow_cover = 1.0
	if kind != "" or sky.winter >= 0:
		# Show it at once, without the fade of the sky.
		_weather_look = Weather.look(weather)
	if sky.winter >= 0 and kind == "":
		# Winter on lays snow on the ground; out of it, the ground is bare.
		snow_cover = 1.0 if sky.winter == 1 else 0.0
		if sky.winter == 1:
			set_weather(Weather.SNOW, SkyCommand.HOLD_HOURS)
			_weather_look = Weather.look(weather)
	Events.tell(Lang.t("Himmel: %s") % ", ".join(parts), TELEPORT_COLOR)
	_update_hud()


## The chat line's teleport command (see Teleport). "teleport" lists every
## place with its five-letter code in the event log and waits for the code as
## the next line; "teleport <code>" goes at once.
func _teleport_command(typed: String) -> void:
	var all := Teleport.areas(level_files)
	if typed == "":
		# The list goes straight into the event log, in the teleport colour:
		# as news each line would flash over the hero's head in turn.
		Events.found(Lang.t("Teleport: Orte und ihre Codes. Schreibe einen Code und drücke Enter."), TELEPORT_COLOR)
		for area in all:
			Events.found("%s  %s" % [String(area.code).to_upper(), Lang.t(area.name)], TELEPORT_COLOR)
		_teleport_waiting = true
		return
	_teleport_code(typed, all)


var _teleport_waiting := false


## Whether `text` was taken as a code while the list is waiting for one.
func _teleport_waits_for(text: String) -> bool:
	if not _teleport_waiting:
		return false
	if not Teleport.looks_like_code(text):
		_teleport_waiting = false
		return false
	_teleport_code(text, Teleport.areas(level_files))
	return true


func _teleport_code(code: String, all: Array) -> void:
	var area := Teleport.by_code(all, code)
	if area.is_empty():
		Events.tell(Lang.t("Kein Ort hat den Code \"%s\". Schreibe \"teleport\" für die Liste.") % code.strip_edges().to_upper(), TELEPORT_COLOR)
		return
	if teleport_to(int(area.index), bool(area.get("square", false))):
		_teleport_waiting = false


## Puts the hero at the entrance (the start) of level `index`, behind a short
## fade, as walking in would. Only while the hero can act (not in a
## transition, a shrine or a window): then nothing else is half done. The
## hero's camp is packed up, as it belongs to the place they leave.
func _to_village_square(wanted: bool) -> void:
	if wanted and level.get("spots") != null and not level.spots.square.is_empty():
		player.global_position = level.spots.square[0]
		player.reset_physics_interpolation()


func teleport_to(index: int, to_square := false) -> bool:
	if index < 0 or index >= level_files.size() or not chat_allowed():
		return false
	var name := Lang.t(level_hint(index).name)
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.4)
	tween.tween_callback(func():
		if index == level_index:
			# Already there: back to the entrance, the map stays as it is.
			player.global_position = level.cell_to_world(level.start_cell)
			player.velocity = Vector3.ZERO
			player.face(Vector3.BACK)
			_to_village_square(to_square)
		else:
			if DragonLair.is_floor(level):
				level.note_left()
			inside_house = 0
			pack_camp(false)
			load_level(index, false)
			_to_village_square(to_square)
		_snap_camera()
		if is_instance_valid(pet):
			pet.arrive()
		player.frozen = false
		state = State.PLAYING
		create_tween().tween_property(_fade, "color:a", 0.0, 0.5)
		_announce_level()
		if level.pitch_dark:
			_warn_of_darkness()
		Events.tell(Lang.t("Teleportiert: %s") % name, TELEPORT_COLOR))
	return true


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
	# Bleeding shows the life still to bleed away.
	if player.ailments.has("blut"):
		out.append(["blut", str(player.wound.left)])
	for kind in ["gift", "fluch", "brand", "netz", SlimeCoat.KIND, "angst"]:
		if player.ailments.has(kind):
			out.append([kind, ""])
	# A rescue's injury: the nights of rest still to go, "!" when rest cannot mend it.
	if player.injury != "":
		out.append(["injury", str(Injury.nights_left(player)) if Injury.nights_left(player) > 0 else "!"])
	if player.ailments.has(BloatedBelly.KIND):
		out.append([BloatedBelly.KIND, BloatedBelly.countdown(player.ailments[BloatedBelly.KIND])])
	# Slower only from a heavy load (the curse and the web that slow have their own icons,
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
	if player.protected():
		out.append([VillageRun.KIND, VillageRun.countdown(player.ailments[VillageRun.KIND])])
	if player.hardening > 0 or player.armour_value > 0:
		out.append(["hardening", str(player.hardening)])
	if house_goddess != "":
		out.append([HouseholdGods.KIND, ""])
	return out


## The blessing of the household goddess (see HouseholdGods): on while the hero is inside their
## own house with her shrine, off as soon as they leave it. Her life per second goes onto the
## hero's own recovery (see Player.bonus_regen), and her icon shows among the boons.
func _update_house_blessing() -> void:
	if player == null:
		return
	var goddess := HouseholdGods.active(self)
	player.bonus_regen = HouseholdGods.perk(goddess, "regen")
	if goddess == house_goddess:
		return
	house_goddess = goddess
	if goddess != "":
		Events.teach(HouseholdGods.LEARN)
	_update_hud()


## Faster than normal from gifts, level or Tempo (leaving out the curse's and
## the web's slowness, which have icons of their own).
func _hero_fast() -> bool:
	var unslowed := player.base_speed / (Player.CURSE_SLOW if player.ailments.has("fluch") else 1.0) \
			/ (Player.WEB_SLOW if player.ailments.has("netz") else 1.0) \
			/ (SlimeCoat.SLOW if player.ailments.has(SlimeCoat.KIND) else 1.0) \
			/ (BloatedBelly.SLOW if player.ailments.has(BloatedBelly.KIND) else 1.0)
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
		"blut": return Lang.t("Du blutest: Noch %s Leben fließen ab, eines pro Sekunde, doppelt so schnell, solange du läufst. Nie das letzte. Ein Brunnen, ein Schrein oder ein Heiltrank stillt die Blutung.") % number
		"gift": return Lang.t("Vergiftet: Du verlierst alle paar Sekunden ein Leben, nie das letzte. Ein Brunnen, ein Schrein oder ein Heiltrank heilt es.")
		"injury": return Injury.title(player.injury, player.injury_severity) + ": " + Injury.effect_text(player.injury, player.injury_severity) + "\n" + Injury.how_to_heal(player.injury, player.injury_severity) if player.injury != "" else ""
		"fluch": return Lang.t("Verflucht: Du bist langsamer. Es vergeht bald; ein Brunnen, ein Schrein oder ein Heiltrank heilt es sofort.")
		"brand": return Lang.t("Du brennst: Ein paar Sekunden lang verlierst du Leben, nie das letzte.")
		"netz": return Lang.t("Eingesponnen: Spinnenseide klebt an dir. Ein paar Sekunden lang bist du viel langsamer.")
		SlimeCoat.KIND: return Lang.t("Verschleimt: Schleim klebt an dir. Ein paar Sekunden lang läufst und schlägst du langsamer. Ein Brunnen, ein Schrein oder ein Heiltrank wäscht ihn ab.")
		"angst": return Lang.t("Verängstigt: Ein Geist hat dich in Panik versetzt. Ein paar Sekunden lang rennst du zum nächsten Ausgang. Weisheit, Intuition und Erkunden helfen, standhaft zu bleiben.")
		BloatedBelly.KIND: return Lang.t("Zu viel Wasser getrunken: Dein Bauch ist prall und du bist viel langsamer. Noch %s, dann geht es von selbst vorbei.") % BloatedBelly.long_countdown(player.ailments.get(BloatedBelly.KIND, 0.0))
		VillageRun.KIND: return Lang.t("Protected: nothing can hurt you for %s more. Run to the village and follow the way!") % VillageRun.long_countdown(player.ailments.get(VillageRun.KIND, 0.0))
		"power": return Lang.t("Kampfkraft %s: Deine Schläge treffen härter.") % number
		HouseholdGods.KIND: return HouseholdGods.blessing_text(house_goddess)
		"fast":
			var text := Lang.t("Schneller als sonst: Tempo %d%%") % roundi(player.speed / Player.SPEED * 100.0)
			if player.base_speed_capped:
				text += "\n" + Lang.t("Höchstgrenze erreicht: Das Grundtempo steigt nicht über %d %%. Rennen macht dich trotzdem schneller.") % roundi(Player.BASE_SPEED_CAP * 100.0)
			return text
		"slow": return Lang.t("Schwer beladen: Du läufst langsamer. Leg im Inventar (I) etwas ab.")
		"hardening": return Lang.t("Härtung %s: Jeder Treffer gegen dich wird um so viel schwächer, bleibt aber mindestens halb so stark.") % number \
				+ ("\n" + Lang.t("Rüstungswert %d %%: Was übrig bleibt, wird um diesen Anteil kleiner.") % player.armour_value if player.armour_value > 0 else "")
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
		if HomeUpgrades.why_not(id, home_upgrades, player.bag, storage, Payment.worth(self)) == "":
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
	# Only the numbers changed (a countdown): the icons stay and take the new
	# number and explanation, so a tooltip being read is not torn away.
	if shown.size() == wanted.size() and range(shown.size()).all(func(i): return shown[i][0] == wanted[i][0]):
		for i in wanted.size():
			var icon: StatusIcon = row.get_child(i)
			icon.set_number(wanted[i][1], icon_text(wanted[i][0], wanted[i][1]))
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



## The dark well of a HUD bar (life, running, experience).
static func bar_back() -> StyleBoxFlat:
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.07, 0.035, 0.02, 0.9)
	back.set_corner_radius_all(4)
	return back


## A HUD bar's fill: a glossy band from `colors` (top, middle, foot).
static func bar_fill(colors: Array) -> StyleBoxTexture:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 32
	var fill := StyleBoxTexture.new()
	fill.texture = tex
	return fill


## The bronze rim of a HUD bar: a frame with an empty middle, laid just
## around the bar, so the bar keeps its size and its fill shows whole.
static func bar_rim() -> Panel:
	var rim := Panel.new()
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rim.offset_left = -BAR_RIM
	rim.offset_top = -BAR_RIM
	rim.offset_right = BAR_RIM
	rim.offset_bottom = BAR_RIM
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiKit.frame_style(Color.TRANSPARENT, UiKit.BRONZE, BAR_RIM, 5)
	style.draw_center = false
	rim.add_theme_stylebox_override("panel", style)
	return rim


## Keeps the life bar and the icons under it at one fixed spot on screen:
## centred across, at HP_BAR_Y of the height. It does not follow the hero,
## so it never moves while the camera trails, shakes or zooms.
func _place_hp_bar() -> void:
	var on_screen := state == State.PLAYING and player != null and player.is_inside_tree() and not player.dead \
			and camera != null
	_hp_bar.visible = on_screen
	_status_row.visible = on_screen
	_ammo_row.visible = on_screen
	if not on_screen:
		return
	var screen := _hud.get_viewport().get_visible_rect().size
	_hp_bar.position = Vector2((screen.x - HP_BAR_SIZE.x) / 2.0, screen.y * HP_BAR_Y).round()
	# Under the bar from its left edge: the ammunition, then the troubles.
	_ammo_row.position = _hp_bar.position + Vector2(0, HP_BAR_SIZE.y + 5)
	_status_row.position = _ammo_row.position + Vector2(AMMO_SLOT.x * AMMO.size() + AMMO_GAP, 0)


## Writes the ammunition counts under the life bar; an empty kind is dimmed.
func _update_ammo() -> void:
	for ammo in AMMO:
		var n := int(player.get(ammo[0]))
		var count: Label = _ammo_counts[ammo[0]]
		count.text = str(n)
		var slot := count.get_parent() as Control
		slot.modulate.a = 1.0 if n > 0 else 0.45
		slot.tooltip_text = Lang.t(ammo[2]) % _ammo_tip_values(ammo[0], n)


## The numbers for an ammunition tooltip (see AMMO): for knives the ready
## count, how many can be ready, the spares in the bag, the damage of a
## throw and the chance in percent that a thrown knife breaks.
func _ammo_tip_values(field: String, n: int) -> Array:
	if field == "knives":
		return [n, player.knife_cap(), player.spare_knives(), player.throw_power(),
				roundi(Projectile.KNIFE_BREAK_CHANCE * 100.0)]
	return [n]


## News about a task (a new one, progress, done): a message over the hero's
## head (no extra word floats up there: it would only say the same twice).
func quest_news(text: String, _color: Color, duration := 4.0) -> void:
	show_message(text, duration)
	_update_hud()


## A task is done: the reward, with a jingle.
func quest_reward(id: String) -> void:
	var q: Dictionary = Quests.ALL[id]
	if q.get("gold", 0) > 0:
		Sfx.play_coins(self, q.gold)
	else:
		Sfx.play(self, "key", -3.0)
	quest_news(Lang.t("Auftrag abgeschlossen: %s\nBelohnung: %s") % [Lang.t(q.title), Quests.reward_text(id)], GOLD, 4.5)


## A few copper for a small favour (see ValleyEvents): into the purse, and a word about it.
func _on_gift_paid(copper: int, text: String) -> void:
	_on_coins_collected(copper)
	show_message(text, 3.5)


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
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
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
	player.reset_physics_interpolation()
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
## The woodcutter cuts timber into his stock while he chops at his trunk (see
## WoodcutterShift). Out of the open air nobody sees him: his shift says it.
func _tick_timber(delta: float) -> void:
	var chopping := WoodcutterShift.at_work(day_hour)
	if level is Outdoor:
		var cutter: Villager = null
		for v: Villager in level.villagers:
			if v.role == "3":
				cutter = v
		chopping = cutter != null and cutter.is_chopping()
	if not chopping:
		return
	var now := WoodcutterShift.cut(timber_stock, _timber_carry, delta)
	timber_stock = now[0]
	_timber_carry = now[1]


## Gorm's shelf from a saved game. An older save has none: it gets the shelf
## of its day, so Gorm has something from the start.
func _load_smith_stock(saved) -> void:
	smith_stock.clear()
	if saved is Dictionary:
		for id in saved:
			if Items.ALL.has(str(id)) and int(saved[id]) > 0:
				smith_stock[str(id)] = mini(int(saved[id]), Forge.STOCK_CAP)
	else:
		Forge.restock(smith_stock, day, hero_name)


func wanderer_wares() -> Array[String]:
	if day != wanderer_night:
		wanderer_night = day
		wanderer_stock = Wanderer.stock_for(day, hero_name)
		# A hero who has the map quest needs no more pieces.
		if quests.state.has(Wanderer.MAP_QUEST):
			wanderer_stock = wanderer_stock.filter(func(id): return not Wanderer.PIECES.has(id))
	return wanderer_stock


func _on_climber_watched(hours: float) -> void:
	ClimberNpc.watched(self, hours)


func learn(entry: String) -> void:
	if not lore.has(entry):
		lore.append(entry)
		# Understanding something new trains the mind.
		player.train("intelligenz", 5.0)


## Where the message lines float, as the lower edge's centre on screen
## (smoothed, see place_message), and how far they were lifted over the
## words rising from the hero's head while the current messages show.
var _message_at := Vector2.INF
var _message_lift := 0.0


## Puts the message lines at their place: centred just over the name above
## the hero's head, so the eye finds them where it already is. Words rising
## from the head (damage, experience, a level-up) never run through them:
## the lines move up out of their way, and only down again once nothing is
## shown. Without a hero on screen they sit low in the middle. Never under
## a wall writing's card (see WritingCard). Called every frame with `delta`
## to follow the hero smoothly; 0 puts them in place at once.
func place_message(delta := 0.0) -> void:
	var screen := _hud.get_viewport().get_visible_rect().size
	var width := minf(MESSAGE_WIDTH, screen.x - 2.0 * SCREEN_TEXT_MARGIN)
	var target := Vector2(screen.x / 2.0, screen.y - MESSAGE_BOTTOM)
	var head := _hero_head_on_screen()
	if head != Vector2.INF:
		target = head - Vector2(0, MESSAGE_HEAD_GAP)
	if _message_at == Vector2.INF or delta <= 0.0 or head == Vector2.INF or not _messages_shown():
		_message_at = target
	else:
		_message_at = _message_at.lerp(target, 1.0 - exp(-20.0 * delta))
	if not _messages_shown():
		_message_lift = 0.0
	# Across: centred over the hero, kept clear of the event log and the
	# first-steps card at the left where the screen is wide enough for that.
	var lowest_left := MESSAGE_MARGIN if screen.x - 2.0 * MESSAGE_MARGIN >= width else (screen.x - width) / 2.0
	var left := clampf(_message_at.x - width / 2.0, lowest_left, screen.x - lowest_left - width)
	var bottom := minf(_message_at.y, screen.y - maxf(writing_card.clearance(), 24.0))
	var height := _message_box.get_combined_minimum_size().y
	if head != Vector2.INF and _messages_shown():
		_message_lift = maxf(_message_lift, _lift_over_words(Rect2(left, bottom - height, width, height)))
	bottom -= _message_lift
	# Never up into the status line at the top.
	bottom = maxf(bottom, MESSAGE_TOP + height)
	_message_box.offset_left = round(left)
	_message_box.offset_right = round(left + width)
	_message_box.offset_top = round(bottom)
	_message_box.offset_bottom = round(bottom)


## The top of the name over the hero's head on screen, seen through the
## camera, for the hero standing on the ground (a jump does not toss the
## messages about); INF while no hero is on screen to float over.
func _hero_head_on_screen() -> Vector2:
	if state != State.PLAYING or player == null or not player.is_inside_tree() or player.dead or camera == null:
		return Vector2.INF
	# Where the hero is drawn this frame (between physics ticks), so the
	# lines move with the hero and do not judder (see SmoothMotion).
	var feet := SmoothMotion.drawn_at(player)
	if not player.frozen:
		feet.y = minf(feet.y, 0.5)
	var top := feet + Vector3(0, Player.NAME_TAG_TOP, 0)
	if camera.is_position_behind(top):
		return Vector2.INF
	return camera.unproject_position(top)


## How far `box` has to move up to clear the words rising over heads and at
## spots that it would lie on (see DamageNumber.columns).
func _lift_over_words(box: Rect2) -> float:
	var lift := 0.0
	for column in DamageNumber.columns(camera):
		var rect: Rect2 = column.rect
		var moved := Rect2(box.position - Vector2(0, lift), box.size)
		# Only the words that would start under or inside the lines push them;
		# a stack higher up on screen is left alone.
		if moved.intersects(rect.grow(2.0)) and rect.end.y > moved.position.y + moved.size.y * 0.5:
			lift = maxf(lift, box.end.y - rect.position.y + MESSAGE_GAP)
	return lift


## Whether a message line is on screen or about to fade in.
func _messages_shown() -> bool:
	if _message_tween != null and _message_tween.is_running():
		return true
	return not message_lines().filter(func(l): return l.modulate.a > 0.05 and l.text != "").is_empty()


## The screen boxes of the message lines that show, for the comic bubbles to
## keep clear of (see Comic.avoid).
func message_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for line in message_lines():
		if line.modulate.a > 0.05 and line.text != "":
			out.append(line.get_global_rect())
	return out


## The screen boxes of the HUD that rides under the hero (life bar, ammunition
## and status icons) and of the prompt beside him, for the song sheet to
## keep clear of (see SongSheet).
func hero_hud_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c: Control in [_hp_bar, _ammo_row, _status_row, _prompt]:
		if not c or not c.is_visible_in_tree() or c.modulate.a <= 0.05 or c.size == Vector2.ZERO:
			continue
		var rect := c.get_global_rect()
		if c is Label:
			# A label as wide as the screen: only its words count.
			var l := c as Label
			if l.text == "":
				continue
			var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			rect = Rect2(rect.get_center().x - w * 0.5, rect.position.y, w, rect.size.y)
		out.append(rect)
	return out


## Shows a message just over the hero's head for `duration` seconds, in
## `color` (white, or gold for great news), and writes it into the event
## log, where it can be read again later. A message that came just before
## and is not read yet moves up a line instead of being covered or lost.
func show_message(text: String, duration := 2.2, color := Color.WHITE) -> void:
	event_log.add_message(text, color)
	_keep_unread_message(text)
	_message.text = text
	_message_duration = duration
	_message.add_theme_color_override("font_color", color)
	_style_message(_message, _message_size(text))
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	place_message()
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
	line.add_theme_font_size_override("font_size", UiKit.sized(size))
	line.add_theme_constant_override("outline_size", maxi(3, UiKit.sized(size) / 6))


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
## Picked up again: the first time, the compendium explains thrown knives.
const KNIFE_LORE := Player.KNIFE_LORE
## The entry from before it said where new knives come from: a saved
## compendium gets the new one (see _apply_save).
const OLD_KNIFE_LORE := "Wurfmesser: Ein geworfenes Messer bleibt liegen, wo es landet, und du hebst es auf, wenn du darüberläufst. Bei einem von fünf Würfen zerbricht es allerdings. Griffbereit für den Kampf trägst du 3 Wurfmesser und eines mehr je zwei Stufen Messerwurf; weitere wandern in den Rucksack (10 auf einem Platz). Sobald kein Kampf mehr tobt, steckst du sie von dort nach."


func _on_item_collected(id: String) -> void:
	if id == Items.KNIFE:
		# A thrown knife picked up again: into the belt while it has room.
		give_knives(1)
		Sfx.play(self, "gear_metal_%d" % (randi() % 3), -10.0)
		Effects.loot_text(level, player.global_position + Vector3(0, 3.0, 0), Lang.t("+%d Wurfmesser") % 1, AMMO_COLOR, 0.0)
		Events.teach(KNIFE_LORE)
		return
	player.bag.append(id)
	if Items.ALL.get(id, {}).get("slot", "") == "erz":
		# Where ore turned up goes on the map (see Journal).
		note_find("ore", id, Items.ALL[id].name, player.global_position)
	Sfx.play(self, "key", -3.0)
	Effects.loot_text(level, player.global_position + Vector3(0, 3.0, 0), Items.item_name(id), Rarity.color(id), DamageNumber.item_worth(id))
	Events.found(Lang.t("Gefunden: %s (%s)") % [Rarity.marked(id), Items.describe(id)])
	_update_hud()


## Coins picked up off the floor. The money (copper, see Loot.MONEY) goes
## into the purse, and the lucky clover doubles what was found, not what the
## hero had put down themselves (`own`); the other metals go there too (see
## Crafting.purse).
func _on_coins_collected(amount: int, metal := CoinPile.MONEY, own := 0) -> void:
	own = clampi(own, 0, amount)
	if metal != CoinPile.MONEY:
		if Crafting.INGREDIENTS.has(metal):
			_on_ingredient_collected(metal, amount, true)
		return
	var gained := _gold(amount - own) + own
	coins += gained
	Events.found(Lang.t("+%d Kupfer") % gained, GOLD)
	Sfx.play_coins(self, gained)
	_update_hud()


## How many coins of `metal` the hero carries, all of them in the purse
## (copper counted in `coins`, the other metals in Crafting.purse).
func coins_held(metal: String) -> int:
	if metal == CoinPile.MONEY:
		return coins
	return crafting.have(metal) if Crafting.INGREDIENTS.has(metal) else 0


## The copper, silver and gold coins the hero holds, by metal (what the hoard at home shows).
func _held_coins() -> Dictionary:
	var out := {}
	for m in PURSE_COINS:
		out[m] = coins_held(m)
	return out


## The coins the hoard at home shows: the ones the hero carries together with the ones lying in
## the metal chest of the house (see HomeStores).
func hoard_coins() -> Dictionary:
	var out := _held_coins()
	out["kupfermuenze"] = int(out["kupfermuenze"]) + HomeStores.stored(self, HomeStores.COINS)
	for m in ["silbermuenze", "goldmuenze"]:
		out[m] = int(out[m]) + HomeStores.stored(self, m)
	return out


## The coin metals the hero can put down: gold always, the others while
## carried.
func coin_metals() -> Array:
	return CoinPile.METALS.keys().filter(func(m): return m == CoinPile.MONEY or coins_held(m) > 0)


## Puts `count` coins of `metal` down at the hero's feet, where they join a
## pile of that metal lying there (see Level.lay_coins). It stays until the
## hero steps away and comes back for it. Returns how many went down.
func put_coins_down(metal: String, count: int) -> int:
	count = clampi(count, 0, coins_held(metal))
	if count <= 0 or level == null or player == null:
		return 0
	if metal == CoinPile.MONEY:
		coins -= count
	else:
		crafting.take(metal, count)
	var ahead := -player.global_transform.basis.z
	ahead.y = 0.0
	var spot := player.global_position + (ahead.normalized() * 0.6 if ahead.length() > 0.01 else Vector3.ZERO)
	var pile: Dictionary = level.lay_coins(spot, count, metal, count)
	if not pile.is_empty():
		pile.wait = true
	Sfx.play_coins(level, count, 0.0, spot)
	_update_hud()
	return count


## Gold found, doubled by the lucky clover.
func _gold(amount: int) -> int:
	return amount * 2 if player.has_special("gluecksklee") else amount


## The vampire tooth gives back 1 life for every VAMPIRE_KILLS enemies slain.
const VAMPIRE_KILLS := 3
var _vampire_kills := 0


## The hero strikes a monster for the first time: its name and level.
func _on_enemy_engaged(enemy: Enemy) -> void:
	if enemy.merged:
		return
	Events.tell(Lang.t("%s, Stufe %d") % [Lang.t(MonsterLore.monster_name(enemy.kind)), enemy.rated_level], XP_COLOR, 2.5)


func _on_enemy_killed(enemy: Enemy) -> void:
	# A boss falls only once: if a rival lands the last blow in the hero's
	# fight, it still counts for the hero, or the task could never be done.
	if enemy.slain_by_rival and not (enemy is BanditChief):
		# Felled by a rival monster (see Factions): it counts for no task.
		if _reach(enemy.global_position) < RIVAL_KILL_HEARD:
			show_message(enemy.fall_text(), 2.5)
		return
	show_message(enemy.fall_text(), 2.5)
	if not enemy.merged:
		var xp := player.clever_xp(HeroLevel.kill_xp(enemy.rated_level, player.hero_level(), enemy.is_level_boss()))
		Events.tell(Lang.t("%s besiegt: Stufe %d, %d EP, %d Leben.") % [Lang.t(MonsterLore.monster_name(enemy.kind)), enemy.rated_level, xp, enemy.max_hp()], XP_COLOR, 3.0)
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
	show_message(Lang.t("Der Bergkönig ist besiegt! Das Herz des Berges gehört dir.") + "\n"
			+ Lang.t("Wo er fiel, leuchtet gleich ein goldener Ausgang. Tritt hinein, und du stehst wieder vor der Mine."), 5.0, GOLD)


func _on_lair_won() -> void:
	var here := level
	if DragonLair.is_floor(level):
		lair_won_here = true
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
	var news := Lang.t("Du trittst mit dem Schatz des Drachen aus dem Steinbogen ins Freie.") if DragonLair.is_floor(level) \
			else Lang.t("Du trittst aus dem Stollen der Mine ins Freie.")
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	Sfx.play(self, "magic", -2.0)
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0.9, 0.75, 0.4, 1.0), 0.5)
	tween.tween_callback(func():
		_leave_building(true)
		get_tree().create_timer(1.0).timeout.connect(func():
			if state == State.PLAYING:
				show_message(news, 3.5)))


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
		Effects.loot_text(level, player.global_position + Vector3(0, 2.8 if big else 2.4, 0), Lang.t("+%d EP") % amount, XP_COLOR,
				DamageNumber.xp_worth(amount, player.hero_level()))
	player.gain_xp(amount)
	Training.save_hero(hero_name, player.xp, player.level_data())
	_update_hud()


## The colour of experience on the HUD and in floating numbers.
const XP_COLOR := Color(0.72, 0.62, 1.0)


func _on_leveled_up(new_level: int) -> void:
	var text := Lang.t("Heldenstufe %d! +1 Leben") % new_level
	if new_level % HeroLevel.CON_EVERY == 0:
		text += ", " + Lang.t("+1 Konstitution")
	if HeroLevel.gives_speed(new_level):
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
const LEVEL_LEARN := "Erfahrung (EP) bekommst du für besiegte Gegner, erfüllte Aufträge, Kopfgelder und gelöste Rätsel. Gegner weit unter deiner Heldenstufe bringen wenig. Jede Stufe gibt +1 Leben, jede 2. Stufe bis Stufe 20 +1 % Tempo, jede 3. Stufe einen Punkt für Stärke, Geschick oder Intelligenz (im Charakter, Taste P) und jede 5. Stufe +1 Konstitution."


## The colour of the brief word over the hero when a skill grows.
const SKILL_GAIN_COLOR := Color(0.65, 0.85, 1.0)


## A skill or monster lore grew: a brief word over the hero's head. Words over
## one head stack, so several gains at once never cover each other.
func show_gain(text: String, color: Color) -> void:
	if player == null or level == null:
		return
	Effects.float_text(level, player.global_position + Vector3(0, 3.0, 0), text, color)


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
			text = Lang.t("%s +1") % Lang.t(_skill_or_craft_name(id))
	var attribute := Training.ATTRIBUTES.has(id)
	if attribute:
		# A stronger body is rare and big: a word over the hero and a message.
		Effects.float_text(level, player.global_position + Vector3(0, 3.4, 0), text.get_slice(":", 1).strip_edges(), GOLD)
		Sfx.play(self, "secret", -6.0)
		show_message(text, 3.5)
	else:
		# A skill grows often: a brief word over the hero's head, not a line
		# in the event log.
		Events.gain(text, SKILL_GAIN_COLOR)
	learn("Eigenschaften wachsen sehr langsam durch Tun: Kämpfen macht stärker (Stärke: +1 Schaden im Nahkampf je Punkt, Lasten wiegen weniger), Treffer einstecken macht zäher (Konstitution, +1 Leben je Punkt), Laufen und Springen machen schneller (Tempo bis 150 %), Springen, Werfen und Fallen machen geschickter (Geschick: +1 Schaden mit Wurfmessern und +4 % Ausweichen je Punkt, weiter springen), Durchsuchen und Geheimnisse schärfen das Gespür (Intuition, +2 % je Punkt, Geheimräume zu entdecken), und alles, was du durchstehst, macht dich weiser (Weisheit: du lernst 5 % schneller je Punkt, ab 12 bieten Schreine eine vierte Gabe), und Neues zu verstehen macht klüger (Intelligenz: Fertigkeiten lernen 10 % schneller und 3 % mehr Erfahrung je Punkt; manche Dinge wie der Zauberhut brauchen sie). Fertigkeiten wachsen schneller, aber nur mit der passenden Ausrüstung. Alles bleibt deinem Helden über alle Läufe.")
	_update_hud()


## The drawer's "Land" button: start marking a building plot, or start again
## (see PlotMarker). It works anywhere on the open map, so the hero does not
## have to go back to the clerk each time.
func plot_action() -> void:
	if state != State.PLAYING or menus.is_open() or not player.can_act():
		return
	if plot_marker == null:
		show_message(Lang.t("Land abstecken geht nur im Freien."), 2.0)
		return
	plot_marker.start()


## Double click or C: sneak (slow, silent, hard to see) or walk normally.
func _toggle_sneak() -> void:
	if player.dead or not player.controllable:
		return
	if not player.sneaking and _anyone_hunting():
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
	if not station.is_empty() and not level.can_reach(player.global_position, station.pos):
		station = {} # Run into a wall with it on the other side.
	if station.get("kind", "") == Seats.KIND and (player.is_seated() or player.still_getting_up()):
		return
	if station.get("kind", "") == Seats.KIND and not _pending_station.is_empty() and _pending_station != station:
		return # On the way to a seat that was clicked: another one passed by is not sat on.
	if station.has("spot") and not _walked_by_keys():
		# A bed or a workbench is run into by accident on the way somewhere clicked, or running
		# with the mouse held: the mouse uses it on its spot (see _click), the keys by running into it.
		return
	if not station.is_empty():
		if station.has("npc") or PERSON_STATIONS.has(station.kind):
			bumped_person = true
		# A villager with a window opens it for a click or a word (see NpcKeywords), never for a
		# bump, who may stand where the hero has to pass: they only remark which words they answer to.
		if station.has("npc") and NpcKeywords.has(station.kind):
			player.face(station.pos - player.global_position)
			player.play("Idle")
			var npc: Villager = station.npc
			if not npc.is_busy_talking() and not _villager_unavailable(station):
				npc.say(NpcKeywords.remark(station.kind), player.global_position)
			return
		_use_station(station)
		return
	var obj := level.unsearched_at(point)
	if not obj.is_empty() and level.can_reach(player.global_position, obj.pos):
		_search(obj)


## Whether the hero walks by the keys, not along a clicked path or steered by the held mouse.
func _walked_by_keys() -> bool:
	return player.path.is_empty() and player.steer == Vector3.ZERO


## Key E beside a bed or a workbench, with no door, crate or block to handle: uses it, as its
## spot is small for the mouse. False when none is in reach.
func _use_spot_station_by_key() -> bool:
	var station := level.nearest_station(player.global_position, Level.SEARCH_RANGE)
	if station.is_empty() or not station.has("spot") or not level.can_reach(player.global_position, station.pos):
		return false
	_use_station(station)
	return true


func _search(obj: Dictionary) -> void:
	_pending_search = {}
	player.path.clear()
	player.face(obj.pos - player.global_position)
	if obj.searched:
		# Just searched (the hero runs into it and a click to it arrives a moment later): the
		# finds are still rising over it, no second word. Else a small note, not a big find.
		if Time.get_ticks_msec() - int(obj.get("searched_at", -SEARCHED_QUIET)) >= SEARCHED_QUIET:
			Effects.loot_text(level, obj.icon_pos, Lang.t("Schon durchsucht"), Color(0.8, 0.8, 0.8), 0.0)
		return
	if obj.loot.has("item") and not player.bag_fits(obj.loot.item):
		if not _message_busy():
			show_message(Lang.t("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg."), 2.0)
		return
	obj.searched_at = Time.get_ticks_msec()
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
	if obj.has("treasure"):
		treasure_maps.opened(obj)
	# Searching every nook trains a feeling for where things hide.
	player.train("intuition", 1.0)
	var text := Lang.t("%s: leer") % Lang.t(obj.label)
	var color := Color(0.8, 0.8, 0.85)
	# "Empty" is only the text while nothing at all has been found; the check must not
	# compare the (translated) words, which broke in English.
	var nothing_yet := not (loot.has("gold") or loot.has("knives"))
	# How big the words over it are: the best of what was in it.
	var worth := 0.0
	if loot.has("gold"):
		Sfx.play_coins(self, _gold(loot.gold), found_after)
		coins += _gold(loot.gold)
		text = Lang.t("+%d Kupfer") % _gold(loot.gold)
		color = GOLD
		worth = DamageNumber.copper_worth(_gold(loot.gold))
		Events.found(text, GOLD)
	elif loot.has("knives"):
		give_knives(loot.knives)
		Sfx.play_after(self, found_after, "gear_metal_%d" % (randi() % 3), -8.0)
		text = Lang.t("+%d Wurfmesser") % loot.knives
		color = Color(0.8, 0.9, 1.0)
		worth = 0.1
		Events.found(text, color)
	if loot.has("item"):
		player.bag.append(loot.item)
		Sfx.play_find(self, loot.item, found_after + (0.25 if loot.has("gold") else 0.0))
		var found := Lang.t("Gefunden: %s (%s)") % [Rarity.marked(loot.item), Items.describe(loot.item)]
		text = Items.item_name(loot.item) if nothing_yet else text + "  +" + Items.item_name(loot.item)
		nothing_yet = false
		# The words over the chest take the colour of the piece found.
		color = Rarity.color(loot.item)
		worth = maxf(worth, DamageNumber.item_worth(loot.item))
		Events.found(found)
	# An eye trained in exploring (Erkunden) finds a torch tucked away.
	var torch := player.bag_fits(HandTorch.ITEM) and randi_range(1, 100) <= player.explore_bonus(Training.EXPLORE_TORCH)
	if torch:
		player.bag.append(HandTorch.ITEM)
		if loot.is_empty():
			color = Color(1.0, 0.75, 0.4)
		Sfx.play_gear(self, HandTorch.ITEM, found_after + 0.25)
		worth = maxf(worth, DamageNumber.item_worth(HandTorch.ITEM))
		text = Items.item_name(HandTorch.ITEM) if nothing_yet else text + "  +" + Items.item_name(HandTorch.ITEM)
		if not loot.has("item"):
			Events.found(Lang.t("Dein geübtes Auge findet eine Fackel, die hier versteckt lag."), Color(1.0, 0.75, 0.4))
		else:
			Events.found(Lang.t("Gefunden: %s") % Items.item_name(HandTorch.ITEM), Color(1.0, 0.75, 0.4))
	Effects.loot_text(level, obj.icon_pos, text, color, worth)
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


## Out of life, the hero is not dead but unconscious (see Rescue): what
## they looted stays where they fell, an eagle (on the surface) or the
## dwarves' emergency team (below ground) carries them to the bed they last
## slept in, and they wake up there with full life. Only a playtest from the
## workshop still ends, back in the workshop.
func _on_player_defeated() -> void:
	state = State.TRANSITION
	# The hero's last cry takes the stage (see FinalScream).
	FinalScream.scream(level, player, hero_name, FinalScream.hero_line(), 3.0)
	if playtest_file != "":
		show_message(Lang.t("Du wurdest besiegt..."), 2.0)
		var tween := create_tween()
		tween.tween_interval(1.6)
		tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.8)
		tween.tween_callback(func(): _end_run(false))
		return
	player.frozen = true
	player.path.clear()
	menus.close()
	var fell_on := level
	var lost := Rescue.drop_belongings(self)
	lost.xp = Rescue.forget(player)
	# The blessing grows thinner: a third of it is gone (see Blessing).
	var god := player.blessing_god
	lost.blessing = Blessing.weaken(player)
	lost.god = god
	# The blow that felled the hero leaves an injury, worse after a boss (see Injury).
	var felled_by: Node = player.felled_by if is_instance_valid(player.felled_by) else null
	lost.injury = ""
	var severity := Injury.severity_for(felled_by)
	if Injury.give(player, Injury.random_kind(), severity):
		lost.injury = player.injury
		lost.severity = player.injury_severity
	_update_hud()
	var eagle := Rescue.on_surface(level)
	show_message(Lang.t("Du verlierst das Bewusstsein...") + "\n" + (Lang.t("Ein Adler stößt herab!") if eagle else Lang.t("Der Rettungstrupp der Zwerge ist unterwegs!")), 3.0)
	Rescue.send(level, player,
			func(seconds: float): create_tween().tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), seconds),
			func(): _wake_after_rescue(eagle, lost, fell_on.level_name))


## The rescuers bring the hero to their latest safe spot: the bed of the
## saved game (or its camp), else where this floor begins. They wake up
## there, rested, and the game is saved.
func _wake_after_rescue(eagle: bool, lost: Dictionary, fell_on: String) -> void:
	if level.building == "" and not level.outdoor:
		# The floor stays as the hero left it (monsters slain, doors open).
		level.note_left()
	elif DragonLair.is_floor(level):
		level.note_left()
	var data := _read_save() if has_slot_save() else {"level": level_index}
	_go_to_wake_place(_wake_place(data))
	player.hp = player.max_hp
	player.cure()
	_snap_camera()
	_update_hud()
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2)
	var asleep := {"away": {"rescued": true}, "camp": data.get("camp")}
	var awake := func(): _rescued(eagle, lost, fell_on)
	if not _wake_at_camp(asleep, awake) and not _wake_in_bed(asleep, awake):
		state = State.PLAYING
		awake.call()


## Up again after a rescue: who brought the hero here, and where their
## things lie.
func _rescued(eagle: bool, lost: Dictionary, fell_on: String) -> void:
	var text := Lang.t("Ein Riesenadler hat dich bewusstlos davongetragen und hierher gebracht.") if eagle \
			else Lang.t("Der Rettungstrupp der Zwerge hat dich bewusstlos aus der Tiefe getragen und hierher gebracht.")
	if int(lost.items) + int(lost.coins) + int(lost.ingredients) > 0:
		text += "\n" + Lang.t("Deine Tasche, dein Zutatenbeutel und %d Münzen liegen noch dort, wo du gefallen bist: %s.") % [int(lost.coins), Lang.t(fell_on)]
	if int(lost.get("xp", 0)) > 0:
		text += "\n" + Lang.t("Gedächtnisverlust: %d Erfahrung vergessen.") % int(lost.xp)
	if String(lost.get("injury", "")) != "":
		text += "\n" + Lang.t("Verletzung: %s (%s)") % [Injury.title(lost.injury, lost.severity), Injury.effect_text(lost.injury, lost.severity)]
	if bool(lost.get("blessing", false)):
		var left := player.blessing_thirds
		var name := Lang.t(Blessing.GODS[lost.god].name)
		text += "\n" + (Lang.t("Der Segen von %s wird schwächer: %d von %d Dritteln bleiben.") % [name, left, Blessing.FULL] if left > 0 \
				else Lang.t("Der Segen von %s ist erloschen. Im Tempel kannst du dich neu segnen lassen.") % name)
	show_message(text, 6.0)
	Events.tell(text.replace("\n", " "), Color(1.0, 0.85, 0.45), 8.0)
	Events.teach(Rescue.LORE)
	Events.teach(Injury.LORE)
	save_game()


## The hero walked onto their pack (see Rescue): back with what fits.
func _on_bundle_reached(entry: Array) -> void:
	var pouch := Rescue.is_pouch(entry)
	var before := Rescue.contents(entry)
	if Rescue.take_back(self, entry):
		var after := Rescue.contents(entry)
		var items := int(before.items) - int(after.items)
		var ingredients := int(before.ingredients) - int(after.ingredients)
		var text := Lang.t("Du hast deinen verlorenen Zutatenbeutel wiedergefunden! Zutaten zurück: %d.") % ingredients if pouch \
				else Lang.t("Du hast deine verlorene Tasche wiedergefunden! Gegenstände zurück: %d.") % items
		if int(after.items) > 0:
			text += " " + Lang.t("Dein Rucksack ist voll, %d Gegenstände bleiben liegen.") % int(after.items)
		Sfx.play(self, "rummage", -3.0)
		Events.found(text, GOLD)
		show_message(text, 4.0)
		_update_hud()


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
		_show_title(Lang.t("Frei!"), Lang.t("%s ist entkommen und hat %d Kupfer erbeutet.") % [hero_name, coins], Lang.t("Klicken für ein neues Spiel"))
	elif has_slot_save():
		# A fallen hero may rise again in the safe room, or once out of the
		# dungeon, on the graveyard or in their own house.
		var info := save_info()
		var place := Lang.t("Klicken oder eine Taste: an deinem Lager weiterspielen.  N: neues Spiel") if info.camp \
				else Lang.t("Klicken oder eine Taste: in deinem Haus weiterspielen.  N: neues Spiel") if info.home \
				else Lang.t("Klicken oder eine Taste: ab dem Friedhof weiterspielen.  N: neues Spiel") if info.escaped \
				else Lang.t("Klicken oder eine Taste: ab der Zuflucht weiterspielen.  N: neues Spiel")
		_show_title(Lang.t("Gefallen"), Lang.t("%s fiel auf Ebene %d mit %d Kupfer.") % [hero_name, level_index + 1, coins], place)
	else:
		_show_title(Lang.t("Gefallen"), Lang.t("%s fiel auf Ebene %d mit %d Kupfer.") % [hero_name, level_index + 1, coins], Lang.t("Klicken für ein neues Spiel"))
	_title_text.add_theme_font_size_override("font_size", UiKit.sized(90))
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
		var out := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
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
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
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
	player.reset_physics_interpolation()
	player.face(Vector3.BACK)
	player.play("Walking_A")
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
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
		_start_village_run()
		if healed > 0:
			_update_hud()
			Effects.float_text(level, player.global_position + Vector3(0, 2.6, 0), "+%d" % healed, Color(0.5, 1.0, 0.5))
		var text := Lang.t("Frei! %s ist entkommen und hat %d Kupfer erbeutet.") % [hero_name, coins] if first else ""
		if not saved:
			text += ("\n" if text != "" else "") + Lang.t("Speichern fehlgeschlagen!")
		get_tree().create_timer(4.8).timeout.connect(func():
			if state == State.PLAYING and text != "":
				show_message(text, 3.5)))


## The run to the village (see VillageRun): starts the protection with the
## shout, as the hero steps out of the crypt. A new exit starts it again; it
## never stacks.
func _start_village_run() -> void:
	player.ailments[VillageRun.KIND] = VillageRun.TIME
	_village_run_on = true
	player._ailments_changed()
	show_message(Lang.t(VillageRun.START_TEXT), 7.0, VillageRun.COLOR)


## Whether the protection was running at the last look (to tell its end once).
var _village_run_on := false


## Ends the protection early at the village, and tells when it is over.
func _watch_village_run() -> void:
	if player == null or state != State.PLAYING:
		return
	var on := player.protected()
	if on and level is Outdoor and level._in_village(level.world_to_cell(player.global_position)):
		player.cure(VillageRun.KIND)
		show_message(Lang.t(VillageRun.END_VILLAGE_TEXT), 4.0, VillageRun.COLOR)
		_village_run_on = false
		return
	if _village_run_on and not on:
		show_message(Lang.t(VillageRun.END_TIME_TEXT), 4.0, Color(1.0, 0.75, 0.4))
	_village_run_on = on


## The hero has walked into the house the elder gave and made it their own:
## it is the new place to come back to, saved at once.
func _on_home_claimed() -> void:
	if Homes.house_of(hero_name) == 0 and level is Outdoor and not level.town_houses.is_empty():
		Homes.house_for(hero_name, level.town_houses.size())
	home_claimed = true
	home_given = true
	var saved := save_game()
	var text := Lang.t("Dein Haus ist jetzt dein Startpunkt.") if saved else Lang.t("Speichern fehlgeschlagen!")
	get_tree().create_timer(4.2).timeout.connect(func():
		if state == State.PLAYING:
			show_message(text, 3.0))


## Walks in at a village building's door, to its own floor. A town house
## on Weavers' Lane (`house` is its number) only lets in the hero who lives
## there; a hero without a house moves into the first empty one.
## `leaf`: the door of a village house, which swings open before the fade starts.
func go_inside(building: String, house := 0, leaf: HouseDoor = null) -> void:
	if state != State.PLAYING or not interiors.has(building):
		return
	if house > 0 and not _may_enter_house(house):
		return
	inside_house = house
	_home_given_now()
	if building == DragonLair.FLOORS[0] and level is Outdoor:
		# Through the arch: a new visit to the lair, set back as it always is.
		DragonLair.reset(looted, level_files, interiors)
		lair_before = DragonLair.snapshot(self)
		lair_won_here = false
	elif DragonLair.is_floor(level):
		# Down a floor of the lair: this one stays as the hero left it.
		level.note_left()
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	if is_instance_valid(pet):
		# Through the door at the hero's heels.
		pet.climb([player.global_position], 0.0, 0.0)
	var tween := create_tween()
	if is_instance_valid(leaf):
		leaf.swing()
		tween.tween_interval(HouseDoor.OPEN_TIME)
	tween.tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.5)
	tween.tween_callback(func():
		_park_next = true
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
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(player, "global_position", player.global_position + Vector3(0, 1.0 if up else -0.6, -0.8 if up else 0.4), 0.45)
	tween.parallel().tween_property(_fade, "color", Color(0.03, 0.015, 0.04, 1.0), 0.45)
	# A few steps on the hollow wooden boards of the house stairs (see StairSteps).
	tween.parallel().tween_callback(func(): StairSteps.flight(player, up))
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


## Up the rungs at the end of Sternhall's old drain (see SternHall): out
## through a rusty grate into the wolf hollow, the vault's hidden way out.
func _climb_out_of_drain() -> void:
	if state != State.PLAYING:
		return
	level.taken[SternHall.DRAIN_FOUND] = true
	Events.teach(SternHall.DRAIN_LORE)
	state = State.TRANSITION
	player.frozen = true
	player.path.clear()
	player.play("Jump_Idle", 0.1)
	Sfx.play(self, "door", -4.0)
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0.85, 0.9, 1.0, 1.0), 0.7)
	tween.tween_callback(func():
		player.frozen = false
		_leave_building(true, SternHall.OUTLET)
		get_tree().create_timer(1.0).timeout.connect(func():
			if state == State.PLAYING:
				show_message(Lang.t("Du stemmst das rostige Gitter auf und kriechst hinaus in die Wolfssenke."), 4.0)))


## Up a hidden hatch (see AshSpire): the hero comes out beside the hatch of
## the floor above.
func use_hatch(s: Dictionary) -> void:
	if not interiors.has(s.building):
		return
	level.note_left()
	load_level(interiors[s.building], false)
	if level.hatch_side != Vector3.ZERO:
		player.global_position = level.hatch_side
		player.face(Vector3.BACK)
	_snap_camera()
	state = State.PLAYING
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
	_announce_level()


## Whether something is marked as done on this level (see Level.taken).
func taken_here(key: String) -> bool:
	return level != null and level.taken.has(key)


## Lights the runes the hero knows on every sealed way down of this floor.
func _refresh_seals() -> void:
	for st in level.stations:
		if st.kind == "schacht":
			Mines.show_runes(st, lore)


## The top floor of the building `building` lies under: the one whose door
## stands in the open (see floor_above), e.g. "mine3" for "mine3c".
func top_floor(building: String) -> String:
	var seen := {}
	while floor_above.has(building) and not seen.has(building):
		seen[building] = true
		building = floor_above[building]
	return building


## Up the stairs of a building floor and out of its door into the village.
## A deeper floor of a mine leads up to the floor above instead, beside the
## way down the hero came by.
func _leave_building(all_the_way := false, door := "") -> void:
	if not all_the_way and level.up_to != "" and interiors.has(level.up_to):
		if DragonLair.is_floor(level):
			level.note_left()
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
	var from_lair := DragonLair.is_floor(level)
	if from_lair:
		# Every floor of the lair comes out of the one arch.
		building = DragonLair.FLOORS[0]
	else:
		# All the way out from a deeper floor (a mine's): out of its door.
		building = top_floor(building)
	if inside_house > 0:
		building += str(inside_house)
	inside_house = 0
	_resume_next = true
	load_level(_outdoor_index(), false)
	if building == SpringCave.ID and level is Outdoor and level.waterfall != null:
		# Out of the spring's cave: on the porch while the ice is open, in a thaw on the shore.
		level.doors[building] = SpringCave.exit_point(level, ice_cover)
	if door != "" and level is Outdoor and level.doors.has(door):
		player.global_position = level.doors[door]
		player.face(Vector3.BACK)
	elif level is Outdoor and level.doors.has(building):
		player.global_position = level.doors[building]
		player.face(Vector3.BACK)
	_snap_camera()
	state = State.PLAYING
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
	if from_lair and lair_won_here:
		_show_lair_spoils()


## Out of the won lair: a window lists what the hero carried out of it
## (see DragonLair.spoils), once the fade has cleared.
const SPOILS_DELAY := 1.2


func _show_lair_spoils() -> void:
	lair_won_here = false
	if lair_before.is_empty():
		# Loaded inside the lair: nothing to measure the spoils against.
		return
	lair_spoils = DragonLair.spoils(lair_before, self)
	lair_before = {}
	var here := level
	get_tree().create_timer(SPOILS_DELAY).timeout.connect(func():
		if level != here or state != State.PLAYING or player.dead:
			return
		if menus.is_open():
			menus.close()
		menus.open("beute"))


## Reaching a safe room saves the game at once, so the way there is never
## lost. The notice waits until the level message has had its say.
func _autosave() -> void:
	var saved := save_game()
	if saved:
		return
	get_tree().create_timer(4.2).timeout.connect(func():
		if state == State.PLAYING and level != null and level.safe:
			show_message(Lang.t("Speichern fehlgeschlagen!"), 2.4))


# --- Per frame --------------------------------------------------------------

func _camera_offset() -> Vector3:
	if free_camera:
		var tilt := deg_to_rad(free_pitch)
		return Vector3(0, sin(tilt), cos(tilt)) * free_distance + Vector3(0, 1.0, 0)
	var pitch := deg_to_rad(lerpf(CAMERA_PITCH, CLOSE_PITCH, _zoom))
	var distance := lerpf(CAMERA_DISTANCE, CLOSE_DISTANCE, _zoom) + frame_pull
	# Up close the camera looks at the hero's chest instead of the feet.
	return Vector3(0, sin(pitch), cos(pitch)) * distance + Vector3(0, lerpf(1.0, 1.6, _zoom), 0)


## True while the camera may zoom: in play, with no window or shrine open.
func can_zoom() -> bool:
	return state == State.PLAYING and not menus.is_open() and _shrine.is_empty()


func zoom_by(steps: float) -> void:
	if free_camera:
		free_distance = CameraCommand.distance_after(free_distance, steps)
		return
	# Steps below 0 look from further out (and a little more from above) than the normal view.
	_zoom_target = clampf(_zoom_target + steps * ZOOM_STEP, -ZOOM_OUT_STEPS * ZOOM_STEP, 1.0)


func _snap_camera() -> void:
	# The hero was put somewhere new: drawn there at once, not sliding over.
	player.reset_physics_interpolation()
	if is_instance_valid(pet):
		pet.reset_physics_interpolation()
	var p := player.global_position
	p.y = 0.0
	camera.global_position = p + _camera_offset()


## Tips on sneaking, shown one after another the first time the hero sees
## an armoured guardian on a level; -1 until then.
const GUARDIAN_TIPS := [
	"Vor dir wacht ein gepanzerter Wächter mit dem Schlüssel.\nEr hat zwanzigmal so viel Leben wie ein Skelett.\nNur ein Stich in den Rücken tötet ihn, mit einem einzigen Schlag.",
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


## The ladder under the mouse: it glows and the cursor turns into a hand, as for any button.
var _ladder_hover: Node3D


func _update_ladder_hover() -> void:
	var now: Node3D = null
	if state == State.PLAYING and level != null and player != null and camera != null and not menus.is_open() \
			and not (house_sketcher != null and house_sketcher.active) and not player.on_ladder() and player.can_act():
		var mouse := get_viewport().get_mouse_position()
		now = LadderClick.under_ray(get_tree(), player, camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if now == _ladder_hover:
		return
	if _ladder_hover != null and is_instance_valid(_ladder_hover):
		LadderClick.glow(_ladder_hover, false)
	_ladder_hover = now
	if now != null:
		LadderClick.glow(now, true)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if now != null else Input.CURSOR_ARROW)


## Whether any foe has noticed the hero (a loop, so no closure is made per frame).
func _anyone_hunting() -> bool:
	for e in level.enemies:
		if is_instance_valid(e) and e.is_hunting():
			return true
	return false


func _process(delta: float) -> void:
	if plot_marker != null and plot_marker.marking():
		var ground = _mouse_to_floor(get_viewport().get_mouse_position())
		if ground != null:
			plot_marker.hover(ground)
	elif house_sketcher != null and house_sketcher.active:
		var spot = _mouse_to_floor(get_viewport().get_mouse_position())
		if spot != null:
			house_sketcher.hover(spot)
	_update_ladder_hover()
	_update_quick_bar()
	_eerie(delta)
	_tick_clock(delta)
	_show_weather()
	WeatherWarmup.hold(self)
	# A skeleton on the hero's heels keeps the fight going, and a hero who
	# has been spotted cannot stay hidden.
	if state == State.PLAYING and level and _anyone_hunting():
		player.mark_fight()
		if player.sneaking:
			player.set_sneaking(false)
			show_message(Lang.t("Entdeckt! Du kannst nicht mehr schleichen."), 1.6)
	_guardian_intro()
	# A swollen belly and a bleeding wound count down under the life bar.
	if player != null and (player.ailments.has(BloatedBelly.KIND) or player.ailments.has("blut") or player.protected()):
		_update_status_icons()
	_watch_village_run()
	if state == State.PLAYING and level != null and not menus.is_open():
		journal.update(delta)
	_quest_mark_timer -= delta
	if _quest_mark_timer <= 0.0:
		_quest_mark_timer = 0.25
		refresh_quest_marks()
		# Tasks bound to this place stay pinned in the event log.
		if player != null and level != null:
			event_log.set_tasks(quests.board())
	# The villagers chat with each other while the world runs.
	if level is Outdoor and state == State.PLAYING and not menus.is_open() and level.process_mode != Node.PROCESS_MODE_DISABLED:
		village_talk.update(delta, level)
		village_worries.update(delta, level)
		village_rumours.update(delta, level)
		drinking_songs.update(delta, level)
		mage_duel.update(delta, level)
	# Where the hero is drawn this frame, between two physics ticks: the
	# camera follows that, so the running hero and the ground glide together
	# however many frames the screen shows between ticks.
	var drawn := SmoothMotion.drawn_at(player)
	var p := drawn
	p.y = minf(p.y, 0.5) if not player.frozen else p.y
	_zoom = move_toward(_zoom, _zoom_target, delta * 2.5)
	camera.rotation_degrees.x = -(free_pitch if free_camera else lerpf(CAMERA_PITCH, CLOSE_PITCH, _zoom))
	var target := p + _camera_offset()
	if house_sketcher != null and house_sketcher.active:
		# The blueprint tool looks at the whole plot, a little above the middle so
		# the tool bar at the bottom does not hide its near edge.
		target = house_sketcher.view_centre() + _camera_offset()
	elif house_furnisher != null and house_furnisher.active:
		# So does the furnishing tool, at the height of the storey it shows.
		target = house_furnisher.view_centre() + _camera_offset()
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.0 * delta))
	if _shake > 0.0:
		# The ground trembles while a secret wall sinks.
		_shake = maxf(0.0, _shake - delta)
		var strength := 0.25 * minf(1.0, _shake)
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * strength
	_place_hp_bar()
	_place_dust(drawn)
	_steer_by_mouse(delta)
	home_run.tick()
	update_home_button()
	update_blueprint_button()
	update_torch_button()
	update_potion_button()
	update_spell_button()
	_update_drag(delta)
	_update_run_meter()
	# Silver and gold coins come and go in many places (loot, trade, the forge).
	_update_purse()
	place_message(delta)
	tutorial.update(delta)
	_help.visible = help_shown()
	if state == State.PLAYING:
		fishing.tick(delta)
	elif fishing.is_fishing():
		fishing.stop()
	if state != State.PLAYING or not _shrine.is_empty() or menus.is_open():
		_prompt.text = ""
		return
	if has_camp() and Camp._flat(player.global_position, camp.global_position) > Camp.LEAVE_RANGE:
		pack_camp()
	if not _pending_station.is_empty() and player.can_act() and _arrived(_pending_station.get("stand", _pending_station.pos)):
		player.path.clear()
		var stand: Vector3 = _pending_station.get("stand", _pending_station.pos)
		if _reach(stand) <= Level.SEARCH_RANGE + 0.3 and _within_reach(stand):
			_use_station(_pending_station)
		_pending_station = {}
	if _pending_crate != null and player.can_act():
		if not is_instance_valid(_pending_crate) or not level.crates.has(_pending_crate):
			_pending_crate = null
		elif _arrived(_pending_crate.global_position) or _reach(_pending_crate.global_position) <= Level.CRATE_REACH:
			var crate_pos := _pending_crate.global_position
			_pending_crate = null
			if _reach(crate_pos) <= Level.CRATE_REACH and _within_reach(crate_pos):
				var why := pick_up_crate(crate_pos)
				if why != "":
					show_message(why, 1.6)
	if not _pending_search.is_empty() and player.can_act() and _arrived(_pending_search.pos):
		player.path.clear()
		if _reach(_pending_search.pos) <= Level.SEARCH_RANGE + 0.3 and _within_reach(_pending_search.pos):
			_search(_pending_search)
		_pending_search = {}
	var near := level.nearest_interactable(player.global_position)
	_hints_now.clear()
	var station := level.nearest_station(player.global_position)
	var at_station: bool = not station.is_empty() and (level_index < 2 or station.kind != "schrein") \
			and level.can_reach(player.global_position, station.pos)
	# Only the first levels explain how to search; after that players know.
	_prompt.text = ""
	if not at_station and level_index < 2 and not near.is_empty() and not near.searched and level.can_reach(player.global_position, near.pos):
		_prompt.text = _hint("search", Lang.t("Dagegenlaufen, um %s zu untersuchen") % Lang.t(_with_article(near.label)))
	if player.is_seated():
		# Sitting: how to get up again, not how to sit down.
		_prompt.text = _hint("aufstehen", Lang.t("Laufen, klicken oder springen, um aufzustehen"))
	elif at_station and station.has("npc") and NpcKeywords.has(station.kind):
		_prompt.text = _hint(station.kind, Lang.t("Klicken oder ein Wort sagen, um mit %s zu reden") % station.npc.display_name)
	elif at_station and bumped_person and PERSON_STATIONS.has(station.kind):
		# The hero knows by now that running into people talks to them.
		_prompt.text = ""
	elif at_station:
		_prompt.text = _hint(station.kind, {
			"schrein": Lang.t("Dagegenlaufen, um den Schrein zu berühren"),
			RuinedShrine.KIND: Lang.t("Dagegenlaufen, um am Schrein der Gnädigen Herrin zu beten"),
			"bett": Lang.t("Dagegenlaufen, um dich ins Bett zu legen"),
			"lager": Lang.t("Dagegenlaufen, um die Lagertruhe zu öffnen"),
			"metalltruhe": Lang.t("Dagegenlaufen, um die stahlbeschlagene Truhe für Metall und Edelsteine zu öffnen"),
			"zutatenbord": Lang.t("Dagegenlaufen, um ans Zutatenbord zu gehen"),
			Bookshelf.KIND: Lang.t("Dagegenlaufen, um Bücher ins Regal zu stellen oder zu nehmen"),
			WeaponRack.KIND: Lang.t("Dagegenlaufen, um Waffen in den Ständer zu stellen oder zu nehmen"),
			"haendler": Lang.t("Dagegenlaufen, um mit %s zu handeln") % station.npc.display_name if station.has("npc") else Lang.t("Dagegenlaufen, um mit dem Händler zu handeln"),
			"brunnen": Lang.t("Dagegenlaufen, um aus dem Brunnen zu trinken"),
			"npc": Lang.t("Dagegenlaufen, um mit %s zu reden") % station.npc.display_name if station.has("npc") else "",
			"bank": Lang.t("Dagegenlaufen, um mit %s zu reden") % station.npc.display_name if station.has("npc") else "",
			"barbier": Lang.t("Dagegenlaufen, um zu %s zu gehen") % station.npc.display_name if station.has("npc") else "",
			"eingang": Lang.t("Dagegenlaufen, um in das dunkle Loch hinabzusteigen") if String(station.get("building", "")).begins_with("loch") or station.get("building", "") == TreasureMaps.CAVE else Lang.t("Dagegenlaufen, um %s zu betreten") % Lang.t(station.get("name", "")),
			"tresor": Lang.t("Dagegenlaufen, um dein Schließfach zu öffnen"),
			"aushang": Lang.t("Dagegenlaufen, um den Aushang zu lesen"),
			QuarryRocks.KIND: Lang.t("Dagegenlaufen, um Stein zu brechen"),
			WoodLogs.KIND: Lang.t("Dagegenlaufen, um Bauholz zu hacken"),
			SummitGarden.SPRING_KIND: Lang.t("Dagegenlaufen, um aus dem Quell zu trinken"),
			PlotOffice.KIND: Lang.t("Dagegenlaufen, um mit %s über Land zu reden") % station.npc.display_name if station.has("npc") else "",
			"holzfaeller": Lang.t("Dagegenlaufen, um bei %s Bauholz zu kaufen") % station.npc.display_name if station.has("npc") else "",
			Mill.KIND: Lang.t("Dagegenlaufen, um bei %s Körner zu kaufen") % station.npc.display_name if station.has("npc") else "",
			Beekeeper.KIND: Lang.t("Dagegenlaufen, um bei %s Honig zu kaufen") % station.npc.display_name if station.has("npc") else "",
			"steinmetz": Lang.t("Dagegenlaufen, um bei %s Steinblöcke zu kaufen") % station.npc.display_name if station.has("npc") else "",
			"raumausstatter": Lang.t("Dagegenlaufen, um bei %s Möbel zu kaufen") % station.npc.display_name if station.has("npc") else "",
			"schmied": Lang.t("Dagegenlaufen, um mit %s an der Esse zu arbeiten") % station.npc.display_name if station.has("npc") else "",
			"hort": Lang.t("Dagegenlaufen, um deinen Hort zu betrachten"),
			"werkbank": Lang.t(CraftingSquare.bench_of(station.get("craft", "")).get("prompt", "")),
			"wanderhaendler": Lang.t("Dagegenlaufen, um mit %s zu handeln") % station.npc.display_name if station.has("npc") else "",
			ClimberNpc.KIND: Lang.t("Dagegenlaufen, um mit %s über das Klettern zu reden") % station.npc.display_name if station.has("npc") else "",
			"hauswerkbank": Lang.t("Werkbank: Dagegenlaufen, um Wurfmesser zu schmieden oder Ausrüstung zu flicken"),
			GardenDecor.GRILL: Lang.t("Dagegenlaufen, um Wildfleisch oder einen Barsch zu grillen und zu essen"),
			AppleTree.STATION: AppleTree.station_prompt(self, station) if station.kind == AppleTree.STATION else "",
			ValleyEvents.KIND: ValleyEvents.prompt(station),
			HouseFurniture.CANDLE_STATION: Lang.t("Klicken, um die Kerzen zu löschen oder anzuzünden"),
			"trophaeen": Lang.t("Trophäenwand: Dagegenlaufen, um zu sehen, welche Trophäen du hast und welche noch fehlen (je +1 Leben)"),
			"gefaehrten": Lang.t("Dagegenlaufen, um nach deinen Gefährten zu sehen"),
			CapeWardrobe.KIND: Lang.t("Dagegenlaufen, um den Umhangschrank zu öffnen"),
			"schacht": Lang.t("Dagegenlaufen, um in die Tiefe hinabzusteigen"),
			"tafel": Lang.t("Dagegenlaufen, um die Inschrift zu lesen"),
			VillageWall.GATE_STATION: Lang.t("Dagegenlaufen, um das Tor zu öffnen"),
			TreasureMaps.DIG: Lang.t("Dagegenlaufen, um nach dem Schatz zu graben"),
			TreasureMaps.BOULDER: Lang.t("Dagegenlaufen, um den Findling beiseitezurollen"),
			SpringCave.KIND: SpringCave.prompt(self, station) if station.kind == SpringCave.KIND else "",
			SpringCave.PLUG: SpringCave.prompt(self, station) if station.kind == SpringCave.PLUG else "",
			SilverSilk.KIND: Lang.t("Dagegenlaufen, um die Silberseide zu ernten"),
			Mines.CLUSTER: Lang.t("Abgebaut: Bis zum nächsten Morgen wachsen die Kristalle nach") if station.get("spent", false) else Lang.t("Dagegenlaufen, um Kristalle abzubauen"),
			Seats.KIND: Lang.t("Dagegenlaufen, um dich auf die Bank zu setzen"),
			WarHorn.KIND: Lang.t("Dagegenlaufen, um ins Horn zu stoßen und das Dorf zu versammeln"),
		}.get(station.kind, AshSpire.prompt(station.kind) + LostMine.prompt(station.kind) + Sewers.prompt(station.kind, station)))
	elif _prompt.text == "" and at_camp():
		_prompt.text = _hint("camp", Lang.t("U: Lager"))
	elif _prompt.text == "" and door_in_reach() != null:
		var door := door_in_reach()
		if door.locked and not door.own:
			# Not a tutorial hint but the reason it stays shut: always shown.
			_prompt.text = Lang.t("Abgeschlossen")
		elif door.own:
			_prompt.text = _hint("door", Lang.t("E: Tür öffnen oder schließen   Umschalt+E: aufschließen") if door.locked
					else Lang.t("E: Tür öffnen oder schließen   Umschalt+E: abschließen"))
		else:
			_prompt.text = _hint("door", Lang.t("E: Tür öffnen oder schließen"))
	elif _prompt.text == "" and shutters_in_reach() != null:
		_prompt.text = _hint("shutters", Lang.t("E: Fensterläden schließen") if not shutters_in_reach().shut
				else Lang.t("E: Fensterläden öffnen"))
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
	elif _prompt.text == "" and level.stone_in_reach(player) == null and level.pack_in_reach(player) != null:
		_prompt.text = _hint("floor_pack", Lang.t("Klick: Rucksack öffnen   E: Rucksack schieben"))
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


## Whether the list of keys shows at the bottom left: while a first step is
## still to be learned, and only in the beginner dungeon. Once the hero is out
## (open air, a building, a mine) it goes, even with a step still unlearned.
func help_shown() -> bool:
	return tutorial.pending() and level != null and level.beginner_dungeon


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


## Whether the hero can put a hand on a clicked thing they walked up to: no wall
## solid from floor to ceiling between them (see Level.can_reach). Says why not.
func _within_reach(pos: Vector3) -> bool:
	if level.can_reach(player.global_position, pos):
		return true
	show_message(Lang.t("Eine Wand ist im Weg."), 1.6)
	return false


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
		fishing.cancel_walk()
		_pending_station = {}


## Sees every input before buttons or the game use it, so the first click
## or key press anywhere can start the music.
func _input(event: InputEvent) -> void:
	Music.notice_input(event)
	# F1 shows or hides the performance plate anywhere: on the title, in a
	# window, while typing in the chat line.
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1 and perf_overlay != null:
		perf_overlay.toggle()
		get_viewport().set_input_as_handled()
		return
	# Letting go of the mouse ends a drag in the blueprint tool (a wall, a
	# rectangle of cellar or roof). It is seen here because the release may
	# happen over the tool bar, and because _unhandled_input hands on key and
	# button presses only.
	if event is InputEventMouseButton and not event.pressed and state == State.PLAYING \
			and house_sketcher != null and house_sketcher.active and house_sketcher.drag_from.x >= 0:
		var point = _mouse_to_floor(event.position)
		if point != null:
			house_sketcher.mouse(point, false, event.button_index)
		else:
			house_sketcher.cancel_drag()


func _unhandled_input(event: InputEvent) -> void:
	# Typing in the chat line: no key of the game fires, and a click on the
	# world leaves the line (and then does what it does).
	if chat_line.is_typing():
		if event is InputEventKey:
			return
		if event is InputEventMouseButton and event.pressed:
			chat_line.leave()
	# Mouse wheel or + and - zoom the camera, but only while no window is open:
	# a list that is already scrolled to its end lets the wheel fall through to
	# here, and the camera behind the window must not move then.
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if event.pressed and can_zoom() and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(event.factor if event.factor > 0.0 else 1.0) if event.button_index == MOUSE_BUTTON_WHEEL_UP else zoom_by(-(event.factor if event.factor > 0.0 else 1.0))
		return
	if free_camera and event is InputEventKey and event.pressed and can_zoom() and event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		free_pitch = CameraCommand.pitch_after(free_pitch, 1.0 if event.physical_keycode in [KEY_PAGEUP, KEY_BRACKETRIGHT] else -1.0)
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
	# The furnishing tool takes the clicks on the floor, R to turn and Esc to close.
	if state == State.PLAYING and house_furnisher != null and house_furnisher.active and not menus.is_open() \
			and house_furnisher.handle_input(event):
		get_viewport().set_input_as_handled()
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
				if event is InputEventKey and event.physical_keycode in [KEY_I, KEY_H, KEY_P, KEY_N, KEY_O, KEY_Y, KEY_ESCAPE]:
					menus.close()
				return
			# Any key or click of the player's own (but the sound, the menu
			# and the home key itself) calls the way home off.
			if home_run.active and not (event is InputEventKey and event.physical_keycode in [KEY_X, KEY_M, KEY_TAB]):
				home_run.stop()
			if event is InputEventKey:
				match event.physical_keycode:
					KEY_ENTER, KEY_KP_ENTER:
						chat_line.open()
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
					KEY_Y:
						if player.can_act():
							menus.open("fertigkeiten")
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
					KEY_1:
						potion_action()
					KEY_2:
						spell_action()
					KEY_U:
						camp_action()
					KEY_G:
						fish_action()
					KEY_Z:
						AshSpire.cast(player)
					KEY_T:
						gift_action()
					KEY_E:
						var why_not := ""
						var door := door_in_reach()
						if door != null:
							why_not = door_action(door, event.shift_pressed)
						elif shutters_in_reach() != null:
							why_not = window_action(shutters_in_reach())
						elif level.crate_in_reach(player) == null and level.stone_in_reach(player) != null:
							why_not = take_stone()
						elif level.crate_in_reach(player) == null and level.pack_in_reach(player) != null:
							why_not = push_floor_pack()
						elif level.crate_in_reach(player) == null and _use_spot_station_by_key():
							pass
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
						if house_sketcher != null and house_sketcher.active:
							house_sketcher.leave()
						elif plot_marker != null and plot_marker.marking():
							plot_marker.cancel()
							show_message(Lang.t("Abstecken abgebrochen."), 1.6)
						elif playtest_file != "":
							back_to_editor()
						elif _drawer_open:
							# The pull-out menu goes first, as a window would.
							set_drawer_open(false)
						else:
							open_pause()
			elif event is InputEventMouseButton:
				var point = _mouse_to_floor(event.position)
				if point == null:
					return
				if house_sketcher != null and house_sketcher.active:
					house_sketcher.mouse(point, event.pressed, event.button_index)
					get_viewport().set_input_as_handled()
					return
				if plot_marker != null and plot_marker.marking():
					if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						plot_marker.click(point)
					get_viewport().set_input_as_handled()
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
					if _click_floor_pack(event.position):
						_mouse_held = false
					elif _grab_stone(event.position):
						_mouse_held = false
					elif event.double_click:
						if not _lock_door_by_double_click(point):
							_toggle_sneak()
					else:
						_click(point)


## Key U, the "Lager" button or the bedroll in the inventory: rolls out a
## camp where the hero stands (see Camp) and opens its window. At the camp
## already, it opens the window again.
func camp_action() -> void:
	if state != State.PLAYING or player == null or menus.is_open() or not _shrine.is_empty():
		return
	if at_camp():
		player.path.clear()
		menus.open("nachtlager")
		return
	if not player.can_act():
		return
	var why := Camp.why_not(player, level, _indoors())
	if why != "":
		show_message(why, 2.4)
		return
	pack_camp(false)
	var spot := Camp.find_spot(level, player.global_position, player.facing())
	camp = Camp.pitch(level, spot.pos, spot.rot)
	player.path.clear()
	player.velocity = Vector3.ZERO
	player.face(camp.global_position - player.global_position)
	Sfx.play(self, "rummage", -4.0, player.global_position)
	learn(CAMP_LEARN)
	menus.open("nachtlager")


const CAMP_LEARN := "Mit einer Schlafrolle (beim Händler) schlägst du überall ein Lager auf: Taste U, der Knopf „Lager“ im Menü oder die Schlafrolle im Inventar. Am Lagerfeuer speicherst du und schläfst wie im Bett, und beim Laden wachst du dort auf. Nicht im Kampf, nicht mit Ungeheuern in der Nähe und nicht in Häusern. Gehst du weg, packst du das Lager wieder ein."


func _camp_from_drawer() -> void:
	set_drawer_open(false)
	camp_action()


## Whether the hero is inside a building, where a bed is the place to sleep.
func _indoors() -> bool:
	return level.building != "" or level.is_home or level.inn or inside_house > 0


## Whether a camp stands on the level the hero is on.
func has_camp() -> bool:
	return is_instance_valid(camp) and not camp.is_queued_for_deletion() and camp.get_parent() == level


## Whether the hero stands at their camp.
func at_camp() -> bool:
	return has_camp() and Camp._flat(player.global_position, camp.global_position) <= Camp.NEAR


## Rolls the bedroll up again and puts the fire out.
func pack_camp(say := true) -> void:
	if is_instance_valid(camp):
		camp.queue_free()
		if say and camp.get_parent() == level:
			show_message(Lang.t("Du packst dein Lager zusammen."), 1.8)
	camp = null


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
		if not Payment.can_pay(self, count):
			show_message(Lang.t(info.wish), 2.6)
			return
		Payment.pay(self, count)
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
	# Clicking the water of a pond casts the line there (see Fishing).
	player.stop_hunt()
	player.cancel_ladder()
	fishing.cancel_walk()
	for e in level.enemies:
		if is_instance_valid(e) and not e.dead and e.visible and Vector2(e.global_position.x - point.x, e.global_position.z - point.z).length() < 1.6:
			if e.is_friend():
				# The hero's friends are not attacked (see Factions).
				show_message(Lang.t(Factions.FACTIONS[Factions.of(e.kind)].friend), 1.6)
				return
			# A foe that has not noticed the hero is gone round to its back
			# first (see Player.charge); one already open to a stab is struck.
			var in_reach := player.global_position.distance_to(e.global_position) < Player.MELEE_RANGE + 1.0
			if in_reach and (not e.is_unaware() or e.open_to_backstab(player.global_position)):
				player.melee()
			else:
				player.charge(e)
			return
	# Clicking a ladder climbs it (walking into one never does, see LadderClick).
	var ladder := LadderClick.under_ray(get_tree(), player, camera.global_position, (point - camera.global_position).normalized())
	if ladder != null and player.use_ladder(ladder):
		_pending_search = {}
		_pending_station = {}
		_pending_crate = null
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
	if fishing.click_water(point):
		_pending_search = {}
		_pending_station = {}
		return
	# A bed or a workbench only on its pillow or the middle of its top (see Level.station_clicked).
	var station := level.station_clicked(point, camera.global_position, (point - camera.global_position).normalized(), 2.2)
	if not station.is_empty():
		if station.kind == Seats.KIND and station.get("indoor", false):
			# A seat of a hall: walk to where one gets up from it (free by its front or side), then sit
			# from there, rather than walking into its box and bumping.
			station["stand"] = Seats.stand_spot(station, level, player.radius)
		_pending_station = station
		_pending_search = {}
		player.walk_to(station.get("stand", station.pos), WALK_UP_TO)
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
	if house_furnisher != null:
		house_furnisher.refresh_books()


## Puts as many books on the bookshelf of the house as the hero keeps there, and the weapons kept
## on the weapon racks of the self-built house.
func refresh_bookshelf() -> void:
	if level != null and level.is_home:
		Bookshelf.refresh(level, HomeStores.total(home_stores, HomeStores.BOOKS))
	if house_furnisher != null:
		house_furnisher.refresh_books()


## The life the trophy wall gives goes into the hero's stats.
func apply_home_bonus() -> void:
	player.home_hp = HomeUpgrades.trophy_hp(HouseFurniture.upgrades_with_stand(home_upgrades, hero_name), trophies)
	player.refresh_stats()
	_update_hud()


## Hagen builds an upgrade onto the house: "" when done, else why not.
func build_home_upgrade(id: String) -> String:
	var why := HomeUpgrades.why_not(id, home_upgrades, player.bag, storage, Payment.worth(self))
	if why != "":
		return why
	HomeUpgrades.pay_stones(id, player.bag, storage)
	Payment.pay(self, int(HomeUpgrades.ALL[id].gold))
	home_upgrades[id] = true
	learn(HomeUpgrades.LEARN)
	apply_home_bonus()
	if level.is_home:
		level.show_home_upgrades(home_upgrades, trophies)
		level.show_hoard(hoard_coins())
	save_game()
	return ""
