class_name Level
extends Node3D
## Builds a dungeon level from a text map and runs its traps and pickups.
##
## Map legend (one character per 4x4 m tile): see Tiles.DUNGEON, the one
## list of the letters. Claim a new letter there first.
##
## The line "secret: normal|uncommon|rare|epic|godborn" sets how rich the
## secret room is (the German ids ungewoehnlich, selten, episch, gottgeboren
## work too). The richer it is, the harder its lever is to
## notice. Any torch near the secret wall can be the lever, a new one each run.
##
## A level with the line "safe: yes" is a safe room without enemies.
## A level with the line "outdoor: yes" lies in the open air and is built by
## Outdoor, with its own map legend. The lines "building: b" and
## "floor: cellar" (or "upstairs") make a level a floor inside the village
## building with that letter: entered by its door, left by its stairs.
## A building floor with the line "home: yes" is a hero's own house (the
## town houses of Weavers' Lane, see Homes): wooden floors, and several
## storeys drawn side by side as rooms of their own, sealed off by walls and
## linked only by their stairs. The rooms count as storeys from west to east:
## the "<" stairs of a storey lead up to the ">" stairs of the next, and back.
## Its exit "E" is the front door in the south wall instead of stairs.
## A level with the line "elite: yes" has stronger skeletons with dark bones
## and glowing red eyes.
## A building floor with the line "lair: yes" is no safe room but a dungeon
## of its own beneath the wild (the dragon's lair): its monsters stand
## ready again every time the hero comes down, they carry gold, and the
## halls are dressed with cobwebs, skulls, banners and heaps of coins from
## Quaternius' Modular Dungeon kit.
##
## A level with the line "dark: yes" is pitch black: no torches burn on its
## walls, and the hero sees little more than the tile they stand on unless a
## hand torch burns (see HandTorch). The line "horror: <kind>" names the
## horror whose den ("X") it is; without it a den gets one at random.
## Deep in the dungeon (from HORROR_FROM_DEPTH on) a level with enemies has
## a small chance (DUNGEON_HORROR_CHANCE) that a horror lurks in its far end.
##
## Barrels, crates, tables, trunks, chests and wall shelves can be searched.

signal key_collected
signal coins_collected(amount: int)
signal door_opened
signal door_locked
signal player_hurt
signal enemy_killed(enemy: Enemy)
## The dragon of the lair has fallen: the lair is won (see _win_lair).
signal lair_won
## The dragon of the lair has spotted the hero for the first time this visit.
signal dragon_awakened(dragon: Dragon)
## The hero stepped into the glowing way out that opens once the lair is won.
signal lair_exit_taken
## The hero took the dragon's hoard (see DragonHoard).
signal hoard_taken
## The hero stepped onto the hoard while its dragon still lives.
signal hoard_guarded
signal exit_reached
## The boss of a mine floor has fallen (see Mines).
signal boss_won
signal item_collected(id: String)
signal bag_full
signal secret_found(lever_pos: Vector3, wall_pos: Vector3)
## The hero picked up an ingredient the fox dug up (see lay_find).
signal ingredient_collected(id: String)
## How many of the level's pressure plates have a block on them changed.
signal plates_changed(pressed: int, total: int)
## Every pressure plate is pressed: the iron gate at `pos` opens.
signal gate_opened(pos: Vector3)

const TILE := 4.0
const ASSET_DIR := "res://assets/dungeon/"
const KIT_DIR := "res://assets/kit/"
## Floors, walls, pillars and furniture from Omie's 3D Modular Dungeon Kit
## (CC0): carved stone and wood instead of the flat cartoon pieces. The kit is
## built on a 3 m grid with pieces anchored at a corner, so each part gets
## shifted, scaled and turned onto ours. Wall ends overlap their neighbours a
## little, so every other wall sits 2 cm higher to keep the tops from flickering.
## piece: list of parts [kit model, texture set, offset, scale, turn]
const WALL_PART := ["SM_Wall", "walls", Vector3(2, 0, 0), Vector3(4.0 / 3.0, 4.0 / 2.56, 4.0 / 3.0), 0.0]
const KIT_PIECES := {
	"floor_tile_large": [["SM_TileFloor", "floor", Vector3(2, 0, 2), Vector3(4.0 / 3.0, 1.0, 4.0 / 3.0), 0.0]],
	"floor_dirt_large": [["SM_RockyFloor", "floor", Vector3(2, 0, 2), Vector3(4.0 / 3.0, 1.0, 4.0 / 3.0), 0.0]],
	"wall": [WALL_PART],
	"wall_cracked": [WALL_PART],
	# A tall bookcase stands against a plain wall.
	"wall_shelves": [WALL_PART, ["SM_FullBookShelf", "props", Vector3(0, 0, 1.05), Vector3.ONE * 2.2, PI]],
	# A touch taller than the walls, so the tops do not flicker against each other.
	"pillar": [["SM_Pillar", "floor", Vector3.ZERO, Vector3(2.2, 4.1 / 2.59, 2.2), 0.0]],
	"pillar_decorated": [["SM_Pillar", "floor", Vector3.ZERO, Vector3(2.8, 4.1 / 2.59, 2.8), 0.0]],
	"barrel_large": [["SM_WoodenBarrel", "props", Vector3.ZERO, Vector3.ONE * 2.2, 0.0]],
	"barrel_small": [["SM_WoodenBarrel", "props", Vector3.ZERO, Vector3.ONE * 1.2, 0.0]],
	"crates_stacked": [
		["SM_WoodenCrate", "props", Vector3(-0.2, 0, 0), Vector3.ONE * 2.2, 0.0],
		["SM_MetalCrate", "props", Vector3(0.1, 1.62, 0.1), Vector3.ONE * 1.5, 0.4],
	],
	"trunk_large_A": [["SM_UnlockedChestBronze", "chests", Vector3.ZERO, Vector3.ONE * 2.0, 0.0]],
	"table_medium_decorated_A": [
		["SM_WoodenTable", "props", Vector3.ZERO, Vector3.ONE * 1.6, 0.0],
		["SM_Candle", "props", Vector3(-1.1, 1.0, 0.2), Vector3.ONE * 1.6, 0.0],
		["SM_BookPile", "props", Vector3(0.6, 1.0, -0.2), Vector3.ONE * 1.6, 0.6],
		["SM_Bottle", "props", Vector3(-0.3, 1.0, -0.4), Vector3.ONE * 1.6, 0.0],
	],
	"torch_mounted": [["SM_WallTorch", "wallprops", Vector3(0, 0.2, 0), Vector3.ONE * 2.0, PI]],
}
## Wall decorations for some plain walls: banners and a sword with a shield.
const WALL_DECOR := [
	["SM_RedFlag", "wallprops", Vector3(0, 3.7, 0.55), Vector3.ONE * 2.2, PI],
	["SM_BlueFlag", "wallprops", Vector3(0, 3.7, 0.55), Vector3.ONE * 2.2, PI],
	["SM_SwordAndShield", "wallprops", Vector3(0, 2.4, 0.55), Vector3.ONE * 1.8, PI],
]
## The bright cartoon stone of the pieces the kit has no match for is darkened
## to sit among the kit's stone.
const STONE_TINT := Color(0.6, 0.56, 0.52)
## The grey of the kit's floor tiles, for spike and grate tiles.
const FLOOR_GREY := Color(0.74, 0.73, 0.71)
## Cartoon furniture that gets the worn, dusty look (see WornLook).
const WORN_PIECES := ["chest", "chest_gold", "bed_decorated", "stool", "sword_shield", "banner_shield_brown"]
## Kit texture sets that get the worn look: barrels, crates, tables,
## shelves, chests and the wall decorations.
const WORN_SETS := ["props", "chests", "wallprops"]
const TINTED_PIECES := ["floor_tile_big_grate", "floor_tile_big_spikes", "wall_doorway", "wall_doorway_door", "stairs"]
const SOLID := "#bxotkCDHBLVF?f=U|N%~T^"
## Reach for searching: anything on a neighbouring tile.
const SEARCH_RANGE := 4.3
## Height of walls between the camera and the room, so they never hide the player.
const LOW_WALL_SCALE := 0.3
const SPIKE_PERIOD := 3.0
const SPIKE_UP_TIME := 1.1
const SPIKE_DOWN_Y := -1.95
## Height of the blood round floor spikes, just above the stone.
const SPIKE_BLOOD_Y := 0.075
## How much longer a path through a spike trap counts for skeletons.
const SPIKE_DETOUR := 6.0
## How far (metres) from the hero rising floor spikes can be heard.
const SPIKE_HEARD := 14.0

var level_name := ""
## The map's file name, e.g. "03_das_labyrinth.txt".
var file := ""
## The monsters, people and gear made in the map workshop for this map:
## letter -> spec (header "custom:", see Creations).
var creations := {}
## Hidden traps from the header "traps: <count> <kind>, <kind>" (see Traps);
## the game's own maps list theirs in Traps.PLACES.
var trap_place := {}
## The wall writing from the header "writing: WORD | text"; empty for the
## writing chosen by the depth (see WRITINGS).
var custom_writing: Array = []
## Played from the map workshop (see LevelEditor): no level below to fall to.
var playtest := false
var hint := ""
var grid: Array[String] = []
var width := 0
var height := 0
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i(-1, -1)
var astar := AStarGrid2D.new()
var player: Node3D
var finished := false
var has_key := false

var _rng := RandomNumberGenerator.new()
var _scenes := {}
var _time := 0.0
var _torches: Array = []
## Lights that always burn: the stairs, shrines and fountains.
var _light_spots: Array[Vector3] = []
## Chance that a wall torch burns when the level starts.
const TORCH_LIT_CHANCE := 0.5
## How far a light reaches far enough to see someone by.
const LIGHT_REACH := 8.0
## How close to a torch's wall the hero must run to reach it.
const TORCH_TOUCH := 1.6
var _spikes: Array = []
## The hidden traps of this level (see Traps), or null.
var traps: Traps = null
var _pickups: Array = []
var interactables: Array = []
## What the hero already took here: ids of searched furniture and picked up
## coins. The game hands in its own dictionary for this level, keeps it in
## the saved game, and calls restore_taken() after build(), so nothing fills
## up again after a reload, a night in bed or a walk out and back in.
var taken := {}
## Floor tiles with a grate (cell -> true). Nothing is placed on them: no
## props, chests, people, traps or hidden finds.
var grates := {}
## What lies about on the floor here: gear the hero dropped, loot from the
## fallen and spilt coins, as [kind ("item" or "coin"), item id, x, z] each.
## The game hands in its own list for this level and keeps it in the saved
## game; restore_floor() lays it all out again after build(), so nothing
## vanishes when the hero walks off and comes back.
var floor_items: Array = []
## The most things kept lying on one level: past it the oldest go, so a level
## where many fall does not fill the saved game without end.
const FLOOR_MAX := 80
var enemies: Array = []
## Fallen monsters still lying here, oldest first, and the stains and bones
## left by the ones that rotted away (see Corpse).
var corpses: Array = []
var remnants: Array = []
## Shrines and the safe room's bed, storage chest and merchant: things to run into.
var stations: Array = []
## Water the hero can fish in (see Fishing): which water ("brunnen", "teich"
## or "senke"), its middle, how far it reaches from there (metres), whether
## it is round (a fountain's basin) or a square tile (a pond), and the height
## of its surface.
var fishing_waters: Array = []
var safe := false
## The world above ground after the last dungeon level: see Outdoor.
var outdoor := false
## Inside a village building: the building's letter on the village map,
## and which floor ("cellar" below, "upstairs" above).
var building := ""
var floor_name := ""
## The hero's name: the cellar shows which vault is theirs.
var hero := ""
var _vault_slots: Array[Vector2i] = []
var _vault_shows: Array = []
var elite := false
## A dungeon of its own below a village building's door (see "lair: yes").
var lair := false
## The lair's dragon (see Dragon) and its health bar.
var dragon: Dragon
var dragon_bar: BossBar
## Pitch black (see "dark: yes").
var pitch_dark := false
## The horror whose den this is (see "horror:"), "" for any.
var horror_kind := ""
## The chance that a den ("X") holds its horror on a visit.
const DEN_HORROR_CHANCE := 0.5
## Deep in the dungeon a horror lurks now and then in a far corner.
const DUNGEON_HORROR_CHANCE := 0.06
const HORROR_FROM_DEPTH := 3
## A horror in the dungeon keeps at least this many steps from the start.
const HORROR_MIN_STEPS := 10
## Whether the lair's dragon has fallen on this visit.
var lair_cleared := false
## What the dragon's helpers heaped up in the lair, "coins" and bars by
## metal (see DragonHoard.contents), handed in by the game before build().
## It lies beside the hoard chest.
var hoard := {}
## The glowing way out that opens in the lair once the dragon has fallen.
var lair_exit: Node3D
## Whether the hero still stands in the way out (it leads out once per step).
var _in_lair_exit := false
## A hero's own house with several storeys (see "home: yes").
var is_home := false
## The town house on Weavers' Lane this home is (set by the game).
var house_number := 0
## Free spots kept for furniture: {"cell", "pos", "storey"}, from the "+"
## tiles of a home, lowest storey first.
var furniture_slots: Array = []
## The chalked frame on each furniture spot (cell -> its node), wiped away
## once a piece of furniture stands there (see _build_upgrade).
var chalk_marks := {}
## Every stairs tile of a home: {"cell", "up", "storey"}.
var stairs: Array = []
## Where the hero stands beside the bed of a home.
var bed_side := Vector3.ZERO
## An inn on the way, with a bed to rest in (header "inn:").
var inn := false
## The setting of a mine floor (header "theme:", see Mines): its light and
## look. "" for every other level.
var theme := ""
## Where a mine floor's way down ("^") and its stairs lead (headers "down:"
## and "up:"), and whether the way down is sealed ("seal:").
var down_to := ""
var up_to := ""
var seal := ""
## Where the hero stands after coming up the way down ("^") from below.
var shaft_side := Vector3.ZERO
## The boss of a mine floor and its health bar (see Mines).
var mine_boss: Enemy = null
var mine_boss_bar: BossBar = null
## Spots beside the beds for the basket of the hero's fox (see Pet), and the
## baskets once they stand there (only for a hero who has a fox).
var fox_beds: Array[Vector3] = []
## In the hero's house: the spots on the straw in the corner by the door
## ("N") where the companions who stay at home rest ({"pos", "rot"}), see
## Companions and Game._spawn_home_pets.
var companion_spots: Array = []
var _baskets: Array[Node3D] = []
## The storey of every walkable tile of a home (see storey_of).
var _storeys := {}
## The stairs tile the hero last arrived on or stood on: taken again only
## after stepping off it.
var _stair_cell := Vector2i(-1, -1)
## The hero walked onto the stairs of a home: up or down to the tile `to`
## on the storey `storey`.
signal stairs_taken(to: Vector3, up: bool, storey: int)
## How deep the level lies (0 for the first); deeper skeletons wear more gear.
var depth := 0
var fog: Fog
var _doors: Array = []
## The monsters placed from the map, with the cell each started on, so a
## floor the hero leaves can remember who fell (see note_left).
var _map_enemies: Array = []
var _torch_spots: Array[Vector3] = []
var _walls_body := StaticBody3D.new()
var _door_hint_shown := false
## Hidden walls and the torches that open them. Each lever rolls once,
## the first time the hero comes up close to it.
var _secrets: Array = []
## Ingredients hidden in the ground that only the hero's fox can sniff out
## (see Pet): each {"cell": Vector2i, "id": String}. Never saved: they grow
## back whenever the hero comes to the level again.
var hidden_finds: Array = []
## How many ingredients lie hidden in a dungeon level and in the open air.
const HIDDEN_IN_DUNGEON := 3
const HIDDEN_OUTDOORS := 14
## The secret room's wealth: one of TIERS.
var secret_tier := "normal"
## Extra chance in percent to notice a lever; the game adds 1 per room found.
var secret_bonus := 0
## Set by the game when the run is overdue a secret room: the lever is
## noticed for sure.
var secret_sure := false
## How close the hero must come to a lever torch for it to work: the same
## reach as searching, so a lever never tips while the hero is across the room.
const LEVER_RANGE := SEARCH_RANGE
## How many steps from the secret wall a torch may be to serve as its lever.
const LEVER_STEPS := 10
## Writings on the walls: each level of the dungeon has one, chosen by its
## depth, on a plain wall somewhere. It stays hidden until the hero notices
## it while walking past in view (see _check_writing): one roll per visit,
## WRITING_CHANCE % plus what the Erkunden skill adds, from WRITING_RANGE;
## a hero who walks right up to it (WRITING_SURE_RANGE) always notices it.
## A noticed writing pops up on a card (see WritingCard), stays known
## on later visits (in taken) and can be read again by running into the
## wall (a "tafel" station). Each is the word
## written in blood on the stone and what it says (German, for Lang). The word
## is in the player's language too, so it reads as a hint: a Latin word such
## as CAVE ("beware") read as the English "cave" and meant nothing.
const WRITINGS := [
	["HOFFNUNG", "Jemand hat mit Blut an die Wand geschrieben: „Gib nicht auf. Ich bin hier auch hinausgekommen.“"],
	["FACKELN", "Mit Blut an die Wand geschrieben: „Nicht jede Fackel ist nur eine Fackel.“"],
	["IIII IIII IIII", "Blutige Striche an der Wand, zu Zwölfergruppen gebündelt. Jemand hat hier lange die Tage gezählt."],
	["LICHT", "Mit Blut an die Wand geschrieben: „In der Finsternis brennt eine Fackel von selbst. Nimm immer eine mit.“"],
	["GOLD", "Mit Blut an die Wand geschrieben: „Die reichsten Truhen stehen dort, wo niemand hinsieht.“"],
	["LEISE", "Mit Blut an die Wand geschrieben: „Die Toten hören schlecht. Wer leise geht, kommt weit.“"],
	["SUCHE", "Mit Blut an die Wand geschrieben: „Wer jeden Gang gesehen hat, sieht auch, was andere übersehen.“"],
	["WASSER", "Mit Blut an die Wand geschrieben: „Das Wasser der Brunnen heilt. Trink, bevor du weitergehst.“"],
	["EISEN", "Mit Blut an die Wand geschrieben: „Die Skelette tragen, was sie uns Gefangenen genommen haben.“"],
	["FREIHEIT", "Mit Blut an die Wand geschrieben: „Hinter dem Tor liegt die Freiheit. Ich habe sie gerochen.“"],
]
## The writings' texts before they were written in blood, and what they
## are now: a saved compendium keeps the new text (see Game.load).
const OLD_WRITINGS := {
	"Jemand hat in die Wand geritzt: „Gib nicht auf. Ich bin hier auch hinausgekommen.“":
		"Jemand hat mit Blut an die Wand geschrieben: „Gib nicht auf. Ich bin hier auch hinausgekommen.“",
	"In die Wand geritzt: „Nicht jede Fackel ist nur eine Fackel.“":
		"Mit Blut an die Wand geschrieben: „Nicht jede Fackel ist nur eine Fackel.“",
	"Striche in der Wand, zu Zwölfergruppen gebündelt. Jemand hat hier lange die Tage gezählt.":
		"Blutige Striche an der Wand, zu Zwölfergruppen gebündelt. Jemand hat hier lange die Tage gezählt.",
	"In die Wand geritzt: „In der Finsternis brennt eine Fackel von selbst. Nimm immer eine mit.“":
		"Mit Blut an die Wand geschrieben: „In der Finsternis brennt eine Fackel von selbst. Nimm immer eine mit.“",
	"In die Wand geritzt: „Die reichsten Truhen stehen dort, wo niemand hinsieht.“":
		"Mit Blut an die Wand geschrieben: „Die reichsten Truhen stehen dort, wo niemand hinsieht.“",
	"In die Wand geritzt: „Die Toten hören schlecht. Wer leise geht, kommt weit.“":
		"Mit Blut an die Wand geschrieben: „Die Toten hören schlecht. Wer leise geht, kommt weit.“",
	"In die Wand geritzt: „Wer jeden Gang gesehen hat, sieht auch, was andere übersehen.“":
		"Mit Blut an die Wand geschrieben: „Wer jeden Gang gesehen hat, sieht auch, was andere übersehen.“",
	"In die Wand geritzt: „Das Wasser der Brunnen heilt. Trink, bevor du weitergehst.“":
		"Mit Blut an die Wand geschrieben: „Das Wasser der Brunnen heilt. Trink, bevor du weitergehst.“",
	"In die Wand geritzt: „Die Skelette tragen, was sie uns Gefangenen genommen haben.“":
		"Mit Blut an die Wand geschrieben: „Die Skelette tragen, was sie uns Gefangenen genommen haben.“",
	"In die Wand geritzt: „Hinter dem Tor liegt die Freiheit. Ich habe sie gerochen.“":
		"Mit Blut an die Wand geschrieben: „Hinter dem Tor liegt die Freiheit. Ich habe sie gerochen.“",
}
const WRITING_CHANCE := 50
## How close the hero must come to a writing to have a chance to notice it.
const WRITING_RANGE := 8.0
## Within this many metres, in view, the hero notices a writing for sure.
const WRITING_SURE_RANGE := 5.0
## The colour of the card that shows a noticed writing (see WritingCard):
## the same amber as a spotted trap's frame.
const WRITING_COLOR := Color(1.0, 0.62, 0.25)
## The carved word's largest font size, and the smallest it shrinks to.
const WRITING_FONT_SIZE := 64
const WRITING_FONT_MIN := 28
## How wide the carved word may be at most: a wall piece is one TILE wide,
## and the pillars at its ends take a little of it.
const WRITING_MAX_WIDTH := 3.2
## The blood the writings are smeared in, and its dark edges and dried stains.
const WRITING_BLOOD := Color(0.6, 0.04, 0.03)
const WRITING_BLOOD_DARK := Color(0.2, 0.01, 0.01)
## How long the trickles under a writing's letters run (metres).
const WRITING_DRIP_LENGTH := Vector2(0.15, 0.7)
## Kept in taken once the hero has noticed this level's writing.
const WRITING_KEY := "writing:found"
## This level's writing: {"cell", "label" (the carved word, hidden until
## found), "word", "text", "rolled", "found", "station"}. Empty in
## the open air, in buildings and at home.
var _writing := {}
## Seconds between pulling the lever and the stone starting to move.
const SECRET_DELAY := 2.5
## Per wealth: chance in percent to notice the lever, gold in each chest,
## the cheapest gear a chest may hold, and the colour of its name.
const TIERS := {
	"normal": {"name": "Gewöhnlich", "chance": 55, "gold": 10, "min_price": 0, "color": Color(0.85, 0.85, 0.85)},
	"ungewoehnlich": {"name": "Ungewöhnlich", "chance": 40, "gold": 18, "min_price": 15, "color": Color(0.45, 0.9, 0.4)},
	"selten": {"name": "Selten", "chance": 28, "gold": 30, "min_price": 25, "color": Color(0.35, 0.6, 1.0)},
	"episch": {"name": "Episch", "chance": 18, "gold": 45, "min_price": 34, "color": Color(0.75, 0.4, 1.0)},
	"gottgeboren": {"name": "Gottgeboren", "chance": 10, "gold": 70, "min_price": 42, "color": Color(1.0, 0.6, 0.15)},
}
## English names for the secret tiers, accepted in level files.
const TIER_ALIASES := {"common": "normal", "uncommon": "ungewoehnlich", "rare": "selten", "epic": "episch", "godborn": "gottgeboren"}
## Every wall torch, with the tile it lights, and the plain walls without one.
var _wall_torches: Array = []
var _bare_walls: Array = []
## Where the bookcases and the wall decorations stand, so that no two of one
## kind end up side by side (see WALL_GAP): {"kind", "pos"}.
var _wall_pieces: Array = []
## Two bookcases, or two wall decorations of one kind, are at least this far
## apart (metres): three tiles, so a room does not show the same thing twice
## in one spot.
const WALL_GAP := TILE * 3.0 - 0.1
## A secret wall's lever is picked from at least this many torches.
const LEVER_CHOICES := 3


## Whether a level file describes the open air (built by Outdoor).
static func is_outdoor_file(path: String) -> bool:
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("outdoor:"):
			return true
	return false


func load_from_file(path: String) -> void:
	file = path.get_file()
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		line = line.strip_edges(false, true)
		if line.begins_with("name:"):
			level_name = line.substr(5).strip_edges()
		elif line.begins_with("hint:"):
			hint = line.substr(5).strip_edges()
		elif line.begins_with("safe:"):
			safe = true
		elif line.begins_with("elite:"):
			elite = true
		elif line.begins_with("building:"):
			# A floor inside a village building (see Outdoor): safe, and its
			# stairs lead back out of the building's door.
			building = line.substr(9).strip_edges()
			safe = true
		elif line.begins_with("lair:"):
			lair = true
		elif line.begins_with("dark:"):
			pitch_dark = true
		elif line.begins_with("horror:"):
			horror_kind = line.substr(7).strip_edges()
		elif line.begins_with("home:"):
			is_home = true
		elif line.begins_with("theme:"):
			theme = line.substr(6).strip_edges()
		elif line.begins_with("down:"):
			down_to = line.substr(5).strip_edges()
		elif line.begins_with("up:"):
			up_to = line.substr(3).strip_edges()
		elif line.begins_with("seal:"):
			seal = line.substr(5).strip_edges()
		elif line.begins_with("inn:"):
			# An inn on the way (see the mountain tavern): its bed lets the
			# hero rest till morning, and a game saved there wakes up there.
			inn = true
		elif line.begins_with("floor:"):
			floor_name = line.substr(6).strip_edges()
		elif line.begins_with("outdoor:"):
			# Out in the open (see Outdoor): no enemies, like a safe room.
			outdoor = true
			safe = true
		elif line.begins_with(Creations.HEADER):
			var c := Creations.parse_line(line)
			if not c.is_empty():
				creations[c.letter] = c.spec
				Creations.register(c.spec)
		elif line.begins_with("traps:"):
			trap_place = Traps.parse_header(line.substr(6))
		elif line.begins_with("writing:"):
			var parts := line.substr(8).split("|", true, 1)
			if parts.size() == 2 and parts[0].strip_edges() != "" and parts[1].strip_edges() != "":
				custom_writing = [parts[0].strip_edges(), parts[1].strip_edges()]
		elif line.begins_with("secret:"):
			secret_tier = line.substr(7).strip_edges()
			secret_tier = TIER_ALIASES.get(secret_tier, secret_tier)
			if not TIERS.has(secret_tier):
				push_warning("Unknown secret tier: " + secret_tier)
				secret_tier = "normal"
		elif line != "":
			grid.append(line)
			width = maxi(width, line.length())
	height = grid.size()
	if lair:
		# Monsters live down there: not a safe room, even below a building.
		safe = false


func build() -> void:
	_rng.seed = hash(level_name)
	_find_storeys()
	_clear_passages()
	add_child(_walls_body)
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if ch == "#":
				continue
			_build_floor(c, ch)
			_build_walls(c)
			_build_content(c, ch)
			if creations.has(ch):
				_build_creation(c, creations[ch])
	_build_corner_pillars()
	furniture_slots.sort_custom(func(a, b): return a.storey < b.storey)
	if is_home:
		_light_storeys()
	_pick_levers()
	_place_writing()
	_build_wall_collision()
	_setup_astar()
	for c in _heavy_starts:
		var heavy := add_stone(StoneBlock.cell_for(cell_to_world(c), true), true, 0, true)
		heavy.home = heavy.global_position
	refresh_stone_paths()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	_walls_body.add_child(floor_shape)
	fog = Fog.new()
	fog.setup(self)
	add_child(fog)
	_spawn_enemies()
	_restore_left()
	if lair and theme == "":
		_decorate_lair()
	if not outdoor and (building == "" or lair):
		add_child(DungeonLife.new(self))
	if not grates.is_empty():
		add_child(GratePits.new(self))
		var tentacles := GrateTentacles.make(self)
		if tentacles:
			add_child(tentacles)
	if not _vault_slots.is_empty():
		refresh_vaults()
	traps = Traps.make(self)
	if traps:
		add_child(traps)


# --- Keeping the way free ---------------------------------------------------

## Furniture that stands on a whole tile and cannot be walked through.
const FURNITURE := "bxotkCHBLVFfy"
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Furniture that looks alike, by group: chests (treasure chest, trunk,
## storage chest), boards (tables, the timber frames in the mines), barrels
## and crates. Two
## pieces of one group never stand on touching tiles, not even corner to
## corner, so a room does not show the same thing twice side by side.
## tests/furniture_spacing.gd checks the maps.
const LOOKALIKES := ["CkL", "t", "j", "b", "x"]


## Moves furniture out of the way: nothing may stand in a narrow passage, next
## to a door, the stairs or the start, or cut off any part of the level.
func _clear_passages() -> void:
	for round in 20:
		var blocker := _find_blocker()
		if blocker.x < 0:
			return
		var ch := cell_char(blocker)
		_set_cell(blocker, ".")
		var spot := _free_spot_near(blocker, ch)
		if spot.x >= 0:
			_set_cell(spot, ch)


func _find_blocker() -> Vector2i:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if FURNITURE.contains(cell_char(c)) and _crowds_passage(c):
				return c
	# Anything still cut off: free the furniture next to it.
	var reach := _reachable()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if _walkable(c) and not reach.has(c):
				for d in DIRS:
					if FURNITURE.contains(cell_char(c + d)):
						return c + d
	return Vector2i(-1, -1)


## Is this tile, or a tile next to it, a doorway, the stairs, the start or a
## one tile wide gap?
func _crowds_passage(c: Vector2i) -> bool:
	if _is_narrow(c):
		return true
	for d in DIRS:
		var n := c + d
		if "DEP?<>".contains(cell_char(n)) or (_walkable(n) and _is_narrow(n)):
			return true
	return false


func _is_narrow(c: Vector2i) -> bool:
	var wall := func(o: Vector2i) -> bool: return cell_char(c + o) == "#"
	return (wall.call(Vector2i(1, 0)) and wall.call(Vector2i(-1, 0))) \
			or (wall.call(Vector2i(0, 1)) and wall.call(Vector2i(0, -1)))


func _walkable(c: Vector2i) -> bool:
	var ch := cell_char(c)
	return ch != "#" and not FURNITURE.contains(ch) and not (creations.has(ch) and creations[ch].type == "npc")


## Every tile the hero can reach from the start, walking through doors.
func _reachable() -> Dictionary:
	var start := Vector2i(-1, -1)
	for y in height:
		var x := grid[y].find("P")
		if x >= 0:
			start = Vector2i(x, y)
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		var next: Array[Vector2i] = []
		for d in DIRS:
			next.append(c + d)
		if "<>".contains(cell_char(c)):
			# The stairs of a home lead on to the next storey.
			var to := stair_target(c)
			if to.x >= 0:
				next.append(to)
		for n in next:
			if _walkable(n) and not seen.has(n):
				seen[n] = true
				todo.append(n)
	return seen


## The nearest plain floor tile where the furniture blocks nothing.
func _free_spot_near(from: Vector2i, piece := "") -> Vector2i:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	var i := 0
	while i < todo.size():
		var c := todo[i]
		i += 1
		if ".,".contains(cell_char(c)) and c != from and not _crowds_passage(c) \
				and not _beside_lookalike(c, piece):
			var count := _reachable().size()
			_set_cell(c, "x")
			var ok := _reachable().size() == count - 1
			_set_cell(c, ".")
			if ok:
				return c
		for d in DIRS:
			var n := c + d
			if _walkable(n) and not seen.has(n):
				seen[n] = true
				todo.append(n)
	return Vector2i(-1, -1)


## Whether a piece of furniture on this tile would touch another of its
## group (see LOOKALIKES), on a side or at a corner.
func _beside_lookalike(c: Vector2i, piece: String) -> bool:
	var group := lookalike_group(piece)
	if group == "":
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and group.contains(cell_char(c + Vector2i(dx, dy))):
				return true
	return false


## The group of look-alike furniture a map letter belongs to, "" for none.
static func lookalike_group(piece: String) -> String:
	if piece == "":
		return ""
	for group in LOOKALIKES:
		if group.contains(piece):
			return group
	return ""


func _set_cell(c: Vector2i, ch: String) -> void:
	var row := grid[c.y]
	grid[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)


# --- Grid helpers -----------------------------------------------------------

func cell_char(c: Vector2i) -> String:
	if c.y < 0 or c.y >= height or c.x < 0 or c.x >= grid[c.y].length():
		return "#"
	var ch := grid[c.y][c.x]
	return "#" if ch == " " else ch


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * TILE, 0.0, c.y * TILE)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / TILE), roundi(p.z / TILE))


## A wall tile is "low" when the room lies north of it, i.e. it stands between
## the camera and the floor.
func _is_low_wall(c: Vector2i) -> bool:
	# A secret wall counts as wall here: the wall below it stays full height
	# and gives nothing away.
	return cell_char(c) == "#" and not "#?".contains(cell_char(c + Vector2i(0, -1)))


func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, SOLID.contains(cell_char(c)))
	# Skeletons go around spike traps when there is another way.
	for s in _spikes:
		astar.set_point_weight_scale(s.cell, SPIKE_DETOUR)


# --- Building ---------------------------------------------------------------

func _place(piece: String, pos: Vector3, rot_y := 0.0, parent: Node = self) -> Node3D:
	if KIT_PIECES.has(piece):
		return _place_kit(KIT_PIECES[piece], pos, rot_y, parent)
	if not _scenes.has(piece):
		_scenes[piece] = load(ASSET_DIR + piece + ".glb")
	var node: Node3D = _scenes[piece].instantiate()
	node.position = pos
	node.rotation.y = rot_y
	parent.add_child(node)
	if piece in WORN_PIECES:
		WornLook.wear(node, _wear(), piece.begins_with("banner"))
	if piece in TINTED_PIECES:
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if mi.name == "spikes":
				# Old spikes: rust, dirt and dried blood (they move, so the
				# grain rides along with them).
				# Only what rises above the floor counts, not the foot hidden in it.
				var box := mi.get_aabb()
				mi.material_override = Traps.grim_spikes(maxf(box.position.y, 0.0), box.end.y)
			elif piece == "floor_tile_big_grate":
				# Grey floor stone round the hole, dark iron bars across it.
				mi.mesh = _grate_mesh(mi.mesh)
				mi.set_surface_override_material(0, _kit_material("floor"))
				mi.set_surface_override_material(1, _gate_iron())
			elif mi.name == "wall_doorway_door":
				# An old wooden door with rusty fittings.
				WornLook.wear_mesh(mi, _wear(), false, STONE_TINT)
			else:
				mi.material_override = _rough_stone(mi.get_active_material(0), piece in ["floor_tile_big_spikes", "floor_tile_big_grate"])
	return node


func _place_kit(parts: Array, pos: Vector3, rot_y: float, parent: Node) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot_y
	parent.add_child(node)
	for part in parts:
		_add_kit_part(part, node)
	return node


func _add_kit_part(part: Array, parent: Node3D) -> Node3D:
	var model: String = part[0]
	if not _scenes.has(model):
		_scenes[model] = load(KIT_DIR + model + ".fbx")
	var kit: Node3D = _scenes[model].instantiate()
	kit.position = part[2]
	kit.scale = part[3]
	kit.rotation.y = part[4]
	parent.add_child(kit)
	var mat := _kit_material(part[1])
	if model.ends_with("Flag"):
		mat = WornLook.material(load(KIT_DIR + part[1] + "_albedo.png"), load(KIT_DIR + part[1] + "_normal.png"), _wear(), true)
	for mi: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		var skeleton := mi.get_parent() as Skeleton3D
		if skeleton:
			# The chests come rigged, and the rig shows only the lid, tipped
			# on its back: use the plain mesh, standing upright, instead. It
			# is modelled with the lid up, so the lid is cut off onto a hinge
			# of its own and shut (search() opens it like the gold chest's).
			var halves := _chest_halves(mi.mesh)
			var body := MeshInstance3D.new()
			body.mesh = halves[0]
			body.material_override = mat
			kit.add_child(body)
			var hinge := Node3D.new()
			hinge.name = "Lid"
			hinge.position = CHEST_HINGE
			# Turned round, so that tipping it back (rotation.x down) opens it.
			hinge.rotation = Vector3(CHEST_SHUT, PI, 0.0)
			kit.add_child(hinge)
			var lid := MeshInstance3D.new()
			lid.mesh = halves[1]
			lid.material_override = mat
			lid.transform = Transform3D(Basis(Vector3.UP, PI), CHEST_HINGE).affine_inverse()
			hinge.add_child(lid)
			skeleton.get_parent().queue_free()
			continue
		mi.material_override = mat
	return kit


## Where the kit chests' lid is hinged (in the model's own units), and how
## far it turns from the way it is modelled (standing up) to shut.
const CHEST_HINGE := Vector3(0, 0.3208, 0.2669)
const CHEST_SHUT := deg_to_rad(97.0)
## How far a searched chest's lid opens (unless it says "lid_open" itself).
const LID_OPEN := deg_to_rad(70.0)


## A rigged kit chest cut into its body and its lid (the triangles that
## move with the lid bone), as two plain meshes without the rig.
func _chest_halves(mesh: Mesh) -> Array:
	var key := "halves_%d" % mesh.get_instance_id()
	if _scenes.has(key):
		return _scenes[key]
	var arrays := mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per := bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var parts := [PackedInt32Array(), PackedInt32Array()]
	for t in range(0, indices.size(), 3):
		var v := indices[t]
		var on_lid := 0.0
		for k in per:
			if bones[v * per + k] == 1:
				on_lid += weights[v * per + k]
		var part: PackedInt32Array = parts[1 if on_lid > 0.5 else 0]
		part.append_array([indices[t], indices[t + 1], indices[t + 2]])
		parts[1 if on_lid > 0.5 else 0] = part
	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null
	var halves := []
	for part in parts:
		arrays[Mesh.ARRAY_INDEX] = part
		var half := ArrayMesh.new()
		half.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		halves.append(half)
	_scenes[key] = halves
	return halves


## The darkened cartoon stone, made rough and matt like the kit's walls, so
## spike and grate tiles, stairs and doorways do not look like plastic.
## grey: plain grey stone like the kit's floor tiles (for spike and grate tiles).
func _rough_stone(mat: Material, grey := false) -> Material:
	var key := "mat_rough_stone_grey" if grey else "mat_rough_stone"
	if not _scenes.has(key):
		var stone := ShaderMaterial.new()
		stone.shader = STONE_SHADER
		stone.set_shader_parameter("albedo_tex", (mat as StandardMaterial3D).albedo_texture)
		stone.set_shader_parameter("albedo_color", FLOOR_GREY if grey else STONE_TINT)
		stone.set_shader_parameter("desaturate", 1.0 if grey else 0.0)
		stone.set_shader_parameter("use_normal_map", false)
		stone.set_shader_parameter("strength", 1.4)
		_scenes[key] = stone
	return _scenes[key]


func _tinted(mat: Material) -> Material:
	# All KayKit pieces share one texture, so one darkened copy serves them all.
	if not _scenes.has("mat_tinted"):
		var m: StandardMaterial3D = mat.duplicate()
		m.albedo_color = STONE_TINT
		_scenes["mat_tinted"] = m
	return _scenes["mat_tinted"]


const STONE_SHADER := preload("res://shaders/stone.gdshader")


func _kit_material(set_name: String) -> Material:
	var key := "mat_" + set_name
	if not _scenes.has(key) and set_name == "walls":
		# Walls get rough, stained stone instead of the kit's smooth brick faces.
		var stone := ShaderMaterial.new()
		stone.shader = STONE_SHADER
		stone.set_shader_parameter("albedo_tex", load(KIT_DIR + "walls_albedo.png"))
		stone.set_shader_parameter("normal_tex", load(KIT_DIR + "walls_normal.png"))
		_scenes[key] = stone
	if not _scenes.has(key) and set_name in WORN_SETS:
		_scenes[key] = WornLook.material(load(KIT_DIR + set_name + "_albedo.png"), load(KIT_DIR + set_name + "_normal.png"), _wear())
	if not _scenes.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(KIT_DIR + set_name + "_albedo.png")
		m.normal_enabled = true
		m.normal_texture = load(KIT_DIR + set_name + "_normal.png")
		m.roughness = 0.9
		_scenes[key] = m
	return _scenes[key]


## How worn the furniture looks here: fully in the dungeon, a little in the
## hero's home and out in the open, where people use and look after things.
func _wear() -> float:
	return WornLook.HOME if is_home or outdoor else WornLook.DUNGEON


func _random_quarter_turn() -> float:
	return _rng.randi_range(0, 3) * PI * 0.5


func _build_floor(c: Vector2i, ch: String) -> void:
	var pos := cell_to_world(c)
	if is_home:
		_build_home_floor(c, ch)
		return
	if ch == "S":
		var tile := _place("floor_tile_big_spikes", pos)
		var spikes: Node3D = tile.find_child("spikes", true, false)
		spikes.position.y = SPIKE_DOWN_Y
		_spikes.append({"node": spikes, "cell": c, "phase": c.x * 0.45 + c.y * 0.2})
		# Pools and drops of the blood the spikes have drawn, different on each tile.
		BloodStains.lay(tile.get_parent(), pos + Vector3(0, SPIKE_BLOOD_Y, 0), hash(c) + 11, 3, 30, 1.7)
		return
	var piece := "floor_tile_large"
	var roll := _rng.randf()
	if ch == ",":
		piece = "floor_dirt_large"
	elif roll < 0.07:
		# A grate only on plain floor: nothing (an NPC, a chest, the start)
		# stands over the hole. The roll still happens, so the other tiles
		# keep their look.
		if ch == ".":
			piece = "floor_tile_big_grate"
			grates[c] = true
	elif roll < 0.14:
		piece = "floor_dirt_large"
	_place(piece, pos, _random_quarter_turn())


func _build_walls(c: Vector2i) -> void:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = c + d
		if cell_char(n) == "?" and cell_char(c) != "?":
			_build_secret_face(c, d)
			continue
		if cell_char(n) != "#":
			continue
		if d == Vector2i(0, -1) and cell_char(c) == "E" and not is_home:
			continue # The stairs lead out through the north wall.
		if d == Vector2i(0, 1) and cell_char(c) == "E" and is_home:
			continue # The front door (see _build_home_door).
		var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * TILE * 0.5
		# Each wall piece faces into the room.
		var rot := atan2(-float(d.x), -float(d.y))
		var low := _is_low_wall(n)
		# The stairs of a home fill their whole tile and reach into the walls
		# beside them: nothing hangs on those walls, or it would stick out of
		# the steps. The rolls below still run, so the rest of the house keeps
		# the same shelves, windows, torches and banners.
		var by_stairs := is_home and "<>".contains(cell_char(c))
		var piece := "wall"
		var roll := _rng.randf()
		if not low and d == Vector2i(0, -1):
			# The barred window that once hung here showed only rock behind
			# it, so its share of the roll is a solid wall now. The roll
			# stays the same, so the rest of every map is built as before.
			if roll < 0.12:
				piece = "wall_shelves"
			elif roll < 0.32:
				piece = "wall_cracked"
		elif not low and roll < 0.2:
			piece = "wall_cracked"
		# A bookcase right beside another one is left out: a plain wall
		# instead. The piece stays as rolled, so the rolls after it, and the
		# rest of the map, stay as they were.
		var shelves := piece == "wall_shelves" and not by_stairs and not _wall_piece_near("shelves", pos)
		var wall := _place("wall" if by_stairs or (piece == "wall_shelves" and not shelves) else piece, pos, rot)
		if (c.x + c.y + d.x + d.y) % 2 != 0:
			wall.position.y += 0.02
		if cell_char(c) == "?":
			# The passage's own side walls stay hidden until it opens.
			wall.visible = false
			_secret_at(c).inner.append(wall)
			continue
		if shelves:
			_wall_pieces.append({"kind": "shelves", "pos": pos})
			var facing := Vector3(sin(rot), 0, cos(rot))
			var shelf := _add_interactable("Regal", pos + facing * 1.2, pos + facing * 0.9 + Vector3(0, 3.4, 0), c)
			shelf.touch_cell = n
		if low:
			wall.scale.y = LOW_WALL_SCALE
			continue
		# No torch behind a barrel, crate or table: the hero must reach it.
		var torch: Node3D = null
		# A guardian's hall has no wall torches: only its fire bowl lights
		# the middle, and the rim stays dark for the hero to creep along.
		if not FURNITURE.contains(cell_char(c)) and not _near_guardian(c) and not by_stairs:
			torch = _maybe_add_torch(pos, rot)
		if torch != null:
			_wall_torches.append({"holder": torch, "cell": c, "pos": pos, "rot": rot})
		elif piece == "wall" and _rng.randf() < 0.18:
			var pick := _rng.randi() % WALL_DECOR.size()
			if not by_stairs:
				# The same banner or sword close by: another one, or none.
				for i in WALL_DECOR.size():
					var k := (pick + i) % WALL_DECOR.size()
					if not _wall_piece_near("decor%d" % k, pos):
						_add_kit_part(WALL_DECOR[k], wall)
						_wall_pieces.append({"kind": "decor%d" % k, "pos": pos})
						break
		elif piece == "wall" and cell_char(c) != "?" and not FURNITURE.contains(cell_char(c)) and not by_stairs:
			_bare_walls.append({"cell": c, "pos": pos, "rot": rot})


## Whether a bookcase or wall decoration of this kind already hangs within
## WALL_GAP of a wall at pos.
func _wall_piece_near(kind: String, pos: Vector3) -> bool:
	return _wall_pieces.any(func(w): return w.kind == kind and w.pos.distance_to(pos) < WALL_GAP)


func _build_corner_pillars() -> void:
	for vy in range(0, height + 1):
		for vx in range(0, width + 1):
			var cells := [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]
			var walls := 0
			var low := false
			for cc in cells:
				if cell_char(cc) == "#" or cell_char(cc) == "?":
					walls += 1
					low = low or _is_low_wall(cc)
			var diagonal := walls == 2 and ("#?".contains(cell_char(cells[0]))) == ("#?".contains(cell_char(cells[3])))
			if walls == 1 or diagonal:
				var pillar := _place("pillar", Vector3(vx * TILE - TILE * 0.5, 0, vy * TILE - TILE * 0.5))
				if low:
					pillar.scale.y = LOW_WALL_SCALE


func _build_wall_collision() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "#":
				continue
			var near_floor := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if cell_char(c + Vector2i(dx, dy)) != "#":
						near_floor = true
			if near_floor:
				_add_box(_walls_body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(TILE, 4, TILE))


func _add_box(body: StaticBody3D, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)
	return shape


func _add_solid(pos: Vector3, size: Vector3) -> void:
	_add_box(_walls_body, pos + Vector3(0, size.y * 0.5, 0), size)


## Blocks a placed piece of furniture where it is drawn and nowhere else: a
## box round the footprint of its meshes, turned and moved with it, kept
## within its tile and `height` high. A fixed box the size of a tile part
## would stand out past a narrow piece (a trunk, a table turned on its side)
## and stop the hero in mid air, or leave a corner of the piece open for the
## hero to sink into. Without meshes the box is `fallback` around `pos`.
func _add_fitted_solid(model: Node3D, pos: Vector3, height: float, fallback := Vector2(2.4, 2.4)) -> void:
	var foot := footprint(model, self)
	var tile := AABB(Vector3(pos.x - TILE * 0.5, 0.0, pos.z - TILE * 0.5), Vector3(TILE, height, TILE))
	if foot.size.x < 0.05 or foot.size.z < 0.05:
		_add_solid(pos, Vector3(fallback.x, height, fallback.y))
		return
	var box := foot.intersection(tile.grow(-0.05))
	var middle := box.get_center()
	_add_solid(Vector3(middle.x, 0.0, middle.z), Vector3(box.size.x, height, box.size.z))


## Blocks a round piece of furniture (a barrel) where it is drawn: an upright
## cylinder as wide as the piece itself, however it is turned.
func _add_round_solid(model: Node3D, height: float) -> void:
	var own := footprint(model, model)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = maxf(own.size.x, own.size.z) * 0.5 if own.size.x > 0.05 else 1.2
	cylinder.height = height
	shape.shape = cylinder
	var middle := model.transform * own.get_center() if own.size.x > 0.05 else model.position
	shape.position = Vector3(middle.x, height * 0.5, middle.z)
	_walls_body.add_child(shape)


## The bounds of a model's visible meshes in the space of `space` (an
## ancestor of it), from the floor up; flat bits lying on the floor (a rug,
## a shadow) do not count. An empty AABB when there are none.
static func footprint(model: Node3D, space: Node) -> AABB:
	var bounds := AABB()
	var found := false
	var meshes: Array = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var shown := true
		var n: Node = mi
		while n != null and n != space:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
				shown = shown and (n as Node3D).visible
			n = n.get_parent()
		if not shown:
			continue
		var box: AABB = xf * mi.get_aabb()
		if box.end.y < 0.1:
			continue
		bounds = bounds.merge(box) if found else box
		found = true
	return bounds


func _build_content(c: Vector2i, ch: String) -> void:
	var pos := cell_to_world(c)
	match ch:
		"P":
			start_cell = c
		"E":
			exit_cell = c
			if is_home:
				_build_home_door(c)
			else:
				_build_exit(c)
		"<", ">":
			_build_stairs(c, ch == "<")
		"+":
			furniture_slots.append({"cell": c, "pos": pos, "storey": storey_of(c)})
		"K":
			_build_key(pos)
		"f":
			_build_fire_bowl(pos)
		"c":
			_build_coin(pos)
		"C":
			_build_chest(c)
		"D":
			_build_door(c)
		"b":
			var barrel := _place("barrel_large", pos + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4)), _rng.randf() * TAU)
			# One barrel to a tile, not a pile. The roll for the small one that
			# stood beside it stays, so the rest of the map is built as before.
			_rng.randf()
			_add_round_solid(barrel, 2.0)
			_add_interactable("Fass", pos, pos + Vector3(0, 2.8, 0), c)
		"x":
			var stack := _place("crates_stacked", pos, _random_quarter_turn())
			_add_fitted_solid(stack, pos, 2.0, Vector2(3.0, 3.0))
			_add_interactable("Kiste", pos, pos + Vector3(0, 3.6, 0), c)
		"k":
			var trunk_model := _place("trunk_large_A", pos, _random_quarter_turn())
			_add_fitted_solid(trunk_model, pos, 1.5)
			var trunk := _add_interactable("Truhe", pos, pos + Vector3(0, 2.4, 0), c, not _in_secret_room(c))
			trunk.lid = trunk_model.find_child("Lid", true, false)
			# All the way up, as the trunk is modelled, so it shows it is empty.
			trunk.lid_open = CHEST_SHUT
			if _in_secret_room(c):
				trunk.loot = _secret_loot(c, 0.5)
		"o":
			_add_fitted_solid(_place("pillar_decorated", pos), pos, 4.0, Vector2(1.6, 1.6))
		"y":
			_add_fitted_solid(_place_lair("Statue_Horse", pos, _random_quarter_turn(), 0.62), pos, 4.0, Vector2(2.6, 2.6))
		"H":
			_build_shrine(c)
		"B":
			var bed_rot := _facing_room(c)
			_add_fitted_solid(_place("bed_decorated", pos, bed_rot), pos, 1.5, Vector2(3.2, 3.2))
			stations.append({"kind": "bett", "cell": c, "pos": pos, "rot": bed_rot, "used": false})
			if is_home or inn:
				bed_side = cell_to_world(_open_side(c))
			_add_fox_bed(c)
		"N":
			_build_companion_corner(c)
		"L":
			_add_fitted_solid(_place("chest", pos, _facing_room(c)), pos, 1.5)
			stations.append({"kind": "lager", "cell": c, "pos": pos, "used": false})
		"V":
			_build_merchant(c)
		"=":
			_build_bars(c)
		"_":
			_build_plate(c)
		"|":
			_build_gate(c)
		"Q":
			_heavy_starts.append(c)
		"U":
			_vault_slots.append(c)
		"F":
			_build_fountain(c)
		"?":
			_secret_at(c)
		"t":
			_add_fitted_solid(_place("table_medium_decorated_A", pos, _random_quarter_turn()), pos, 2.0, Vector2(3.0, 2.2))
			_add_interactable("Tisch", pos, pos + Vector3(0, 2.8, 0), c)
		"j", "%", "~", "T", "^":
			Mines.build_cell(self, c, ch)


func _has_cell(ch: String) -> bool:
	for row in grid:
		if row.contains(ch):
			return true
	return false


## Whether a cell lies within a guardian's hall (a few tiles of a W).
func _near_guardian(c: Vector2i) -> bool:
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			if cell_char(c + Vector2i(dx, dy)) == "W":
				return true
	return false


## A standing fire bowl: a low stone base with a burning fire that always
## lights the tiles around it.
func _build_fire_bowl(pos: Vector3) -> void:
	var base := _place("pillar", pos)
	base.scale = Vector3(1.0, 0.28, 1.0)
	var flame := Effects.make_flame()
	flame.position = pos + Vector3(0, 1.3, 0)
	flame.scale = Vector3.ONE * 2.2
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.28)
	light.light_energy = 4.5
	light.omni_range = 11.0
	light.omni_attenuation = 1.4
	light.position = pos + Vector3(0, 2.2, 0)
	add_child(light)
	_add_solid(pos, Vector3(1.8, 2, 1.8))
	_light_spots.append(pos)


func _maybe_add_torch(wall_pos: Vector3, rot: float, forced := false) -> Node3D:
	if pitch_dark and not forced:
		return null # Nobody has hung a torch down here.
	for spot in _torch_spots:
		if spot.distance_to(wall_pos) < TILE * 2.2 and not forced:
			return null
	_torch_spots.append(wall_pos)
	var facing := Vector3(sin(rot), 0, cos(rot))
	var holder := Node3D.new()
	holder.position = wall_pos + facing * 0.5 + Vector3(0, 2.3, 0)
	holder.rotation.y = rot
	add_child(holder)
	_place("torch_mounted", Vector3.ZERO, 0.0, holder)
	var flame := Effects.make_flame()
	flame.position = Vector3(0, 0.78, 0.45)
	holder.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.56, 0.24)
	light.light_energy = 3.4
	light.omni_range = 12.0
	light.omni_attenuation = 1.3
	light.position = Vector3(0, 1.0, 1.0)
	holder.add_child(light)
	# Some torches burn, some are cold: a new mix every run.
	var torch := {"light": light, "flame": flame, "holder": holder, "wall_pos": wall_pos, "seed": _rng.randf() * 100.0, "on": true, "touched": -10.0}
	_torches.append(torch)
	set_torch(torch, randf() < TORCH_LIT_CHANCE)
	return holder


## Lights or puts out a torch.
func set_torch(torch: Dictionary, on: bool) -> void:
	torch.on = on
	torch.light.visible = on
	torch.flame.visible = on
	torch.flame.emitting = on


## The torch on the wall the hero runs into, only when the run against the
## wall starts (not while pressing on). Empty otherwise.
func torch_touched(point: Vector3) -> Dictionary:
	for t in _torches:
		if not is_instance_valid(t.holder):
			continue
		if Vector2(point.x - t.wall_pos.x, point.z - t.wall_pos.z).length() < TORCH_TOUCH:
			var fresh: bool = _time - t.touched > 0.4
			t.touched = _time
			return t if fresh else {}
	return {}


## Whether a burning torch, the stairs, a shrine or the fountain lights a spot.
func is_lit(pos: Vector3) -> bool:
	for t in _torches:
		if t.on and is_instance_valid(t.light) and _flat_distance(pos, t.light.global_position) < LIGHT_REACH:
			return true
	for spot in _light_spots:
		if _flat_distance(pos, spot) < LIGHT_REACH:
			return true
	return false


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_key(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 1.3, 0)
	add_child(holder)
	var key := _place("key", Vector3(-0.25, 0, 0), 0.0, holder)
	key.scale = Vector3.ONE * 2.2
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.35)
	light.light_energy = 1.8
	light.omni_range = 4.0
	holder.add_child(light)
	holder.add_child(Effects.make_sparkles(Color(1.0, 0.85, 0.4)))
	_pickups.append({"node": holder, "kind": "key", "radius": 1.8})


## A small gold coin lying flat on the floor, picked up when the hero walks over it.
func _build_coin(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 0.03, 0)
	holder.rotation.y = deg_to_rad(hash(Vector2(pos.x, pos.z)) % 360)
	add_child(holder)
	var coin := _place("coin", Vector3.ZERO, 0.0, holder)
	coin.scale = Vector3.ONE * 1.6
	var c := world_to_cell(pos)
	_pickups.append({"node": holder, "kind": "coin", "radius": 1.5, "id": "coin:%d,%d" % [c.x, c.y]})


func _build_chest(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	# Face the chest towards the open side of the room.
	var rot := 0.0
	if cell_char(c + Vector2i(0, 1)) == "#":
		rot = PI
	var chest := _place("chest_gold", pos, rot)
	_add_fitted_solid(chest, pos, 1.5, Vector2(2.0, 2.0))
	var obj := _add_interactable("Schatztruhe", pos, pos + Vector3(0, 2.6, 0), c, false)
	obj.lid = chest.find_child("chest_gold_lid", true, false)
	if _in_secret_room(c):
		obj.loot = _secret_loot(c, 1.0)
		return
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = hash("%s:chest:%d:%d" % [level_name, c.x, c.y])
	if _behind_gate(c):
		# The reward of a block-pushing puzzle: as rich as a rare secret room.
		var rare: Dictionary = TIERS["selten"]
		obj.loot = {"gold": int(rare.gold), "item": loot_item(loot_rng, int(rare.min_price), HeroLevel.place_level(self) + 1)}
		return
	obj.loot = {"gold": 5, "item": loot_item(loot_rng, 0, HeroLevel.place_level(self))}


## The tiles reachable from the start without passing an iron gate (|).
var _ungated := {}


## Whether a tile lies behind an iron gate, shut off until its pressure
## plates are pressed (and not in the secret room).
func _behind_gate(c: Vector2i) -> bool:
	if not _has_cell("|") or _in_secret_room(c):
		return false
	if _ungated.is_empty():
		for y in height:
			var x := grid[y].find("P")
			if x >= 0:
				_ungated[Vector2i(x, y)] = true
		var todo: Array[Vector2i] = []
		todo.assign(_ungated.keys())
		while not todo.is_empty():
			var at: Vector2i = todo.pop_back()
			for d in DIRS:
				var n := at + d
				if not "#?|".contains(cell_char(n)) and not _ungated.has(n):
					_ungated[n] = true
					todo.append(n)
	return not _ungated.has(c)


## Gold and gear for a chest in the secret room, as rich as its tier. A trunk
## gets a share of the gold and, in the richest rooms, gear too.
func _secret_loot(c: Vector2i, share: float) -> Dictionary:
	var tier: Dictionary = TIERS[secret_tier]
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = hash("%s:secret:%d:%d" % [level_name, c.x, c.y])
	var loot := {"gold": int(round(tier.gold * share * loot_rng.randf_range(0.8, 1.2)))}
	if share >= 1.0 or tier.min_price >= 34:
		loot.item = loot_item(loot_rng, tier.min_price, HeroLevel.place_level(self) + 1)
	return loot


func _in_secret_room(c: Vector2i) -> bool:
	return not _outer_side().has(c)


## A small stone shrine with a floating, glowing crystal.
func _build_shrine(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var base := _place("pillar", pos)
	base.scale = Vector3(1.2, 0.32, 1.2)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		_place("candle_lit", pos + Vector3(cos(a), 0, sin(a)) * 1.25, _rng.randf() * TAU)
	var orb := MeshInstance3D.new()
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.55, 0.8, 0.55)
	orb.mesh = crystal
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.85, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.75, 1.0)
	mat.emission_energy_multiplier = 3.0
	orb.material_override = mat
	orb.position = pos + Vector3(0, 2.3, 0)
	add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.75, 1.0)
	light.light_energy = 2.5
	light.omni_range = 7.0
	light.position = pos + Vector3(0, 2.6, 0)
	add_child(light)
	var motes := Effects.make_sparkles(Color(0.6, 0.85, 1.0))
	motes.position = pos + Vector3(0, 2.0, 0)
	add_child(motes)
	_add_solid(pos, Vector3(2.2, 2, 2.2))
	_light_spots.append(pos)
	stations.append({"kind": "schrein", "cell": c, "pos": pos, "used": false, "orb": orb, "light": light, "motes": motes})


## A turn that points a piece at the open side of its tile.
func _facing_room(c: Vector2i) -> float:
	for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if not SOLID.contains(cell_char(c + d)):
			return atan2(float(d.x), float(d.y))
	return 0.0


## Carved stone for pieces built in code (the fountain): the rough, matt stone
## shader on a plain colour, so its stains, grain and pits give the stone its
## look without a kit texture. Shared per colour.
func _plain_stone(color: Color) -> Material:
	var key := "mat_plain_stone_" + color.to_html()
	if not _scenes.has(key):
		if not _scenes.has("tex_white"):
			var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
			img.fill(Color.WHITE)
			_scenes["tex_white"] = ImageTexture.create_from_image(img)
		var stone := ShaderMaterial.new()
		stone.shader = STONE_SHADER
		stone.set_shader_parameter("albedo_tex", _scenes["tex_white"])
		stone.set_shader_parameter("albedo_color", color)
		stone.set_shader_parameter("use_normal_map", false)
		stone.set_shader_parameter("strength", 1.7)
		_scenes[key] = stone
	return _scenes[key]


const WATER_SHADER := preload("res://shaders/water.gdshader")

const DECAYED_STONE_SHADER := preload("res://shaders/decayed_stone.gdshader")

## The fountain's stone, aged by decay (0 clean, 1 the forgotten dungeon
## fountain): cracks, damp streaks, moss and a lime crust at the water lines
## (see shaders/decayed_stone.gdshader). Shared per colour and decay.
## rubble: loose pieces lying on the floor (no extra moss at their foot).
func _decayed_stone(color: Color, decay: float, rubble := false) -> Material:
	var key := "mat_decayed_stone_%s_%.2f_%s" % [color.to_html(), decay, rubble]
	if not _scenes.has(key):
		var stone := ShaderMaterial.new()
		stone.shader = DECAYED_STONE_SHADER
		stone.set_shader_parameter("albedo_color", color)
		stone.set_shader_parameter("strength", decay)
		stone.set_shader_parameter("water_line_a", FOUNTAIN_WATER)
		stone.set_shader_parameter("water_line_b", FOUNTAIN_BOWL_WATER)
		stone.set_shader_parameter("low_moss", 0.0 if rubble else 1.0)
		_scenes[key] = stone
	return _scenes[key]


## Heights of the water in the fountain's basin and in its bowl.
const FOUNTAIN_WATER := 0.92
const FOUNTAIN_BOWL_WATER := 2.3

## The healing fountain: an eight-sided basin of carved stone on a low step,
## a column with a small bowl on top, and a spout whose water falls back into
## the basin. The water glows faintly and breathes, with a few motes drifting
## over it, since it heals. In the dungeon it has stood forgotten for ages:
## the stone is cracked, streaked and mossy, a piece of the basin's coping has
## broken off and lies on the floor with some rubble, the water is murky with
## a film of scum and the spout only splutters. Up in the village it is
## looked after and only a little weathered.
func _build_fountain(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var decay := 0.25 if outdoor or is_home else 1.0
	var old := decay > 0.5
	var stone := _decayed_stone(Color(0.56, 0.54, 0.5) if not old else Color(0.5, 0.48, 0.43), decay)
	# The inside of the basin stays wet and dark.
	var wet := _decayed_stone(Color(0.3, 0.31, 0.32) if not old else Color(0.24, 0.25, 0.21), decay)
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	var still := ShaderMaterial.new()
	still.shader = WATER_SHADER
	still.set_shader_parameter("rings", 0.3)
	still.set_shader_parameter("ring_spacing", 45.0)
	if old:
		# Murky, greenish water with scum along the rim; it still glows a
		# little, as it still heals.
		for m: ShaderMaterial in [water, still]:
			m.set_shader_parameter("deep_color", Color(0.05, 0.09, 0.06))
			m.set_shader_parameter("shallow_color", Color(0.16, 0.22, 0.14))
			m.set_shader_parameter("glow_color", Color(0.4, 0.8, 0.62))
			m.set_shader_parameter("glow", 0.16)
			m.set_shader_parameter("scum", 1.0)
		water.set_shader_parameter("radius", 1.3)
		water.set_shader_parameter("rings", 0.45)
		still.set_shader_parameter("radius", 0.5)
	# One side of the coping has broken off (the one facing the room's
	# entrance side most often seen, front right).
	var coping_gaps := [1] if old else []
	# [inner radius, outer radius, bottom, top, sides, material, gaps]
	var parts := [
		[0.0, 1.85, 0.0, 0.22, 8, stone, []],  # the step
		[1.3, 1.55, 0.22, 1.0, 8, stone, []],  # the basin's wall
		[1.25, 1.68, 1.0, 1.14, 8, stone, coping_gaps],  # its coping, a little wider
		[0.0, 1.31, 0.22, 0.4, 8, wet, []],  # the basin's floor
		[0.0, 1.3, 0.4, FOUNTAIN_WATER, 24, water, []],  # the water
		[0.0, 0.46, 0.4, 0.62, 8, stone, []],  # the column's foot
		[0.0, 0.3, 0.62, 1.94, 8, stone, []],  # the column
		[0.0, 0.52, 1.94, 2.06, 8, stone, []],  # its capital
		[0.5, 0.74, 2.06, 2.38, 8, stone, []],  # the bowl on top
		[0.0, 0.51, 2.06, 2.14, 8, wet, []],  # the bowl's floor
		[0.0, 0.5, 2.14, FOUNTAIN_BOWL_WATER, 24, still, []],  # the bowl's water
	]
	for part in parts:
		var node := MeshInstance3D.new()
		node.mesh = Effects.ring_mesh(part[0], part[1], part[2], part[3], part[4], part[5], part[6])
		node.position = pos
		if part[5] == water or part[5] == still:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	if old:
		_fountain_rubble(pos, _decayed_stone(Color(0.5, 0.48, 0.43), decay, true))
	var spray := Effects.make_spray(Color(0.75, 0.92, 0.95) if not old else Color(0.62, 0.72, 0.62))
	spray.position = pos + Vector3(0, 2.3, 0)
	if old:
		# The spout half choked: it splutters a few weak drops.
		spray.amount = 16
		spray.initial_velocity_min = 1.2
		spray.initial_velocity_max = 2.0
	add_child(spray)
	var motes := Effects.make_sparkles(Color(0.6, 0.9, 0.9) if not old else Color(0.55, 0.85, 0.7))
	motes.amount = 8 if not old else 5
	motes.emission_sphere_radius = 1.1
	motes.position = pos + Vector3(0, 1.2, 0)
	add_child(motes)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.85, 0.85) if not old else Color(0.48, 0.8, 0.68)
	glow.light_energy = 0.9 if not old else 0.7
	glow.omni_range = 6.5
	glow.position = pos + Vector3(0, 1.8, 0)
	add_child(glow)
	# The glow breathes slowly, like the water.
	var tween := glow.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow, "light_energy", 1.15, 2.4)
	tween.tween_property(glow, "light_energy", 0.75, 2.4)
	_add_solid(pos, Vector3(3.2, 2, 3.2))
	_light_spots.append(pos)
	stations.append({"kind": "brunnen", "cell": c, "pos": pos, "used": false})
	fishing_waters.append({"water": "brunnen", "pos": pos, "reach": 1.3, "round": true, "surface": FOUNTAIN_WATER})


## The broken-off piece of the fountain's coping, lying on the floor in front
## of the gap, with a few smaller chips of stone round the step. Fixed, not
## random, so the fountain looks the same each visit.
func _fountain_rubble(pos: Vector3, stone: Material) -> void:
	# [size, offset from the middle, turn, tilt]
	var pieces := [
		[Vector3(0.72, 0.14, 0.4), Vector3(1.75, 0.07, 1.55), 0.85, Vector3(0.08, 0, 0.22)],
		[Vector3(0.24, 0.12, 0.2), Vector3(1.95, 0.06, 0.6), 0.3, Vector3(0.2, 0, 0.1)],
		[Vector3(0.16, 0.1, 0.14), Vector3(0.9, 0.27, 1.55), 1.2, Vector3(0, 0, 0.15)],
		[Vector3(0.14, 0.08, 0.12), Vector3(-1.3, 0.05, 1.75), 2.1, Vector3(0.1, 0, 0)],
		[Vector3(0.2, 0.1, 0.16), Vector3(-1.9, 0.05, -0.7), 0.6, Vector3(0.15, 0, 0.1)],
	]
	for piece in pieces:
		var box := BoxMesh.new()
		box.size = piece[0]
		var node := MeshInstance3D.new()
		node.mesh = box
		node.material_override = stone
		node.position = pos + piece[1]
		node.rotation = Vector3(piece[3].x, piece[2], piece[3].z)
		add_child(node)


## A secret passage: a wall tile with a fake wall on each open side.
func _secret_at(c: Vector2i) -> Dictionary:
	for s in _secrets:
		if s.cell == c:
			return s
	var body := StaticBody3D.new()
	add_child(body)
	_add_box(body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(TILE, 4, TILE))
	_secrets.append({"cell": c, "body": body, "walls": [], "inner": [], "lever": null, "lever_cell": c, "lever_on_wall": false, "faces": [], "rolled": false, "open": false})
	return _secrets[-1]


## One face of a secret wall, seen from the room at c. The face toward the
## part of the level the hero starts in carries the lever torch.
func _build_secret_face(c: Vector2i, d: Vector2i) -> void:
	var secret := _secret_at(c + d)
	var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * TILE * 0.5
	var rot := atan2(-float(d.x), -float(d.y))
	var wall := _place("wall", pos, rot)
	secret.walls.append(wall)
	if d == Vector2i(0, 1):
		wall.scale.y = LOW_WALL_SCALE
	elif _outer_side().has(c):
		secret.faces.append({"cell": c, "pos": pos, "rot": rot})


## Tiles of the room in front of a secret wall, up to LEVER_STEPS steps
## away, without going through a door: where its lever may hang.
func _steps_from_secret(s: Dictionary) -> Dictionary:
	var steps := {}
	var todo: Array[Vector2i] = []
	for face in s.faces:
		steps[face.cell] = 0
		todo.append(face.cell)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		if steps[c] >= LEVER_STEPS:
			continue
		for d in DIRS:
			var n := c + d
			if not steps.has(n) and _outer_side().has(n) and cell_char(n) != "D":
				steps[n] = steps[c] + 1
				todo.append(n)
	return steps


## Picks each secret wall's lever from the torches around it, at random, so
## it is a different one every run. With no torch near, the wall gets one.
func _pick_levers() -> void:
	for s in _secrets:
		var steps := _steps_from_secret(s)
		var near: Array = []
		for t in _wall_torches:
			if steps.has(t.cell):
				near.append(t)
		# Too few torches around: hang more on the bare walls nearby.
		var bare := _bare_walls.filter(func(w): return steps.has(w.cell))
		while near.size() < LEVER_CHOICES and not bare.is_empty():
			var w: Dictionary = bare.pop_at(_rng.randi() % bare.size())
			if _torch_spots.any(func(spot): return spot.distance_to(w.pos) < TILE * 1.5):
				continue
			near.append({"holder": _maybe_add_torch(w.pos, w.rot, true), "cell": w.cell, "pos": w.pos, "rot": w.rot})
			_wall_torches.append(near[-1])
		if not near.is_empty():
			var t: Dictionary = near[randi() % near.size()]
			s.lever = t.holder
			s.lever_cell = t.cell
		elif not s.faces.is_empty():
			var face: Dictionary = s.faces[0]
			s.lever = _maybe_add_torch(face.pos, face.rot, true)
			s.lever_cell = face.cell
			s.lever_on_wall = true


var _outer: Dictionary = {}


## Tiles reachable from the start without passing a secret wall.
func _outer_side() -> Dictionary:
	if _outer.is_empty():
		var start := Vector2i(-1, -1)
		for y in height:
			var x := grid[y].find("P")
			if x >= 0:
				start = Vector2i(x, y)
		_outer = {start: true}
		var todo: Array[Vector2i] = [start]
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			for d in DIRS:
				var n := c + d
				if cell_char(n) != "#" and cell_char(n) != "?" and not _outer.has(n):
					_outer[n] = true
					todo.append(n)
	return _outer


## The tiles that count when the hero explores the whole map (see
## Journal.note_full_map): every tile one can stand on in the part reachable
## from the start without a secret wall. Locked doors and gates count, so the
## rooms behind them have to be seen as well.
## Needs only the map read from its file, not the level built.
func explore_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _outer_side():
		var ch := cell_char(c)
		var ground := Outdoor.WALK.contains(ch) if outdoor else (not SOLID.contains(ch) or "D|".contains(ch))
		if ground:
			out.append(c)
	return out


## Rolls each lever once, the first time the hero stands next to it in view
## (within LEVER_RANGE). From further away nothing happens and nothing is rolled.
func _check_secrets() -> void:
	for s in _secrets:
		if s.rolled or s.lever == null:
			continue
		var torch: Node3D = s.lever
		var d := Vector2(player.global_position.x - torch.global_position.x, player.global_position.z - torch.global_position.z)
		if d.length() > LEVER_RANGE or not has_line_of_sight(player.global_position, cell_to_world(s.lever_cell)):
			continue
		s.rolled = true
		# Walking past a strange torch sharpens the hero's sense for such things.
		player.train("intuition", 3.0)
		if randi_range(1, 100) <= secret_chance():
			player.train("intuition", 12.0)
			_open_secret(s)


## A person or a piece of gear made in the map workshop (monsters come with
## the others, see _spawn_enemies). Gear lies on the floor once: picked up
## or not, it is remembered from then on (taken, then floor_items).
func _build_creation(c: Vector2i, spec: Dictionary) -> void:
	var pos := cell_to_world(c)
	match spec.type:
		"npc":
			var npc := DungeonNpc.new()
			npc.setup(spec)
			add_child(npc)
			npc.global_position = pos
			stations.append({"kind": "figur", "cell": c, "pos": pos, "used": false, "figure": npc})
		"item":
			var key := "custom:%d:%d" % [c.x, c.y]
			if Items.ALL.has(spec.id) and not taken.has(key):
				taken[key] = true
				_drop_item(spec.id, pos)


## Carves this level's writing into a plain wall in the part of the level
## the hero starts in, the same wall every visit. Only a north wall, the one
## that faces the camera, so the writing can be read.
func _place_writing() -> void:
	if outdoor or building != "" or is_home:
		return
	var outer := _outer_side()
	var free_wall := func(w: Dictionary) -> bool:
		return outer.has(w.cell) and absf(w.rot) < 0.1 and not _torch_spots.any(func(spot): return spot.distance_to(w.pos) < TILE)
	var walls := _bare_walls.filter(free_wall)
	if walls.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:writing" % level_name)
	var wall: Dictionary = walls[rng.randi() % walls.size()]
	var entry: Array = custom_writing if not custom_writing.is_empty() else WRITINGS[depth % WRITINGS.size()]
	var label := Label3D.new()
	label.text = Lang.t(entry[0])
	# Lang.t already chose the language; do not translate the label again.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	label.pixel_size = 0.01
	label.font_size = writing_font_size(label.font, label.text, label.pixel_size)
	label.outline_size = 4
	# Smeared on the stone in blood.
	label.modulate = WRITING_BLOOD
	label.outline_modulate = WRITING_BLOOD_DARK
	label.double_sided = false
	# Flat on the wall, facing into the room, at eye height.
	var facing := Vector3(sin(wall.rot), 0, cos(wall.rot))
	label.position = wall.pos + facing * 0.45 + Vector3(0, 2.4, 0)
	label.rotation.y = wall.rot
	label.visible = false
	add_child(label)
	var drips := _writing_drips(label, rng)
	_writing_arrow(wall.pos, facing, rng)
	# Run into the wall to read a noticed writing again.
	var station := {"kind": "tafel", "cell": wall.cell + Vector2i(0, -1), "pos": wall.pos + facing * 0.5,
			"used": false, "text": entry[1]}
	_writing = {"cell": wall.cell, "label": label, "drips": drips, "word": entry[0], "text": entry[1],
			"rolled": false, "found": false, "station": station}
	if taken.has(WRITING_KEY):
		# Noticed on an earlier visit: it shows at once, without news.
		_writing.found = true
		_writing.rolled = true
		label.visible = true
		stations.append(station)


## Blood running down from the letters: thin trickles under the word, each
## ending in a drop, hanging from a pivot at its top so it can run down when
## the writing is noticed (see reveal_writing). Children of the label, so
## they show with it.
func _writing_drips(label: Label3D, rng: RandomNumberGenerator) -> Array:
	var size := label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size) * label.pixel_size
	var blood := _blood_material(true)
	var drips: Array = []
	var count := clampi(int(size.x / 0.32), 3, 10)
	for i in count:
		var pivot := Node3D.new()
		var x := (float(i) + rng.randf_range(0.2, 0.8)) / count * size.x - size.x / 2.0
		# From the lower part of the letters, a little behind them.
		pivot.position = Vector3(x, -size.y * 0.22, -0.01)
		label.add_child(pivot)
		var length := rng.randf_range(WRITING_DRIP_LENGTH.x, WRITING_DRIP_LENGTH.y)
		var width := rng.randf_range(0.035, 0.06)
		var trickle := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width, length, 0.01)
		trickle.mesh = box
		trickle.material_override = blood
		trickle.position.y = -length / 2.0
		pivot.add_child(trickle)
		var drop := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = width * 0.9
		ball.height = width * 2.2
		drop.mesh = ball
		drop.material_override = blood
		drop.position.y = -length
		pivot.add_child(drop)
		drips.append(pivot)
	return drips


## Bloodstains on the floor in front of the writing, dripped in the shape
## of an arrow that points at it: a trail of drops towards the wall and a
## head of two short strokes. Always there, so they lead the hero to a
## writing not yet noticed. All within the tile in front of the wall.
func _writing_arrow(wall_pos: Vector3, facing: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var arrow := Node3D.new()
	arrow.name = "BloodArrow"
	add_child(arrow)
	var blood := _blood_material(false)
	var side := Vector3(facing.z, 0, -facing.x)
	var spots: Array = []
	# The shaft: from the middle of the tile towards the wall.
	var d := 3.3
	while d > 1.3:
		spots.append([d, rng.randf_range(-0.07, 0.07), rng.randf_range(0.1, 0.17)])
		d -= rng.randf_range(0.28, 0.4)
	# The tip and the two strokes of the head.
	spots.append([0.95, 0.0, 0.19])
	for k in [1.0, -1.0]:
		for step in 3:
			var t := (step + 1) / 3.0
			spots.append([0.95 + 0.55 * t, k * 0.55 * t, rng.randf_range(0.1, 0.15)])
	# A few splashes round about.
	for i in 4:
		spots.append([rng.randf_range(1.0, 3.4), rng.randf_range(-1.2, 1.2), rng.randf_range(0.04, 0.08)])
	for spot in spots:
		var stain := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = spot[2]
		disc.bottom_radius = spot[2]
		disc.height = 0.01
		disc.radial_segments = 12
		stain.mesh = disc
		stain.material_override = blood
		stain.position = wall_pos + facing * spot[0] + side * spot[1] + Vector3(0, DungeonLife.FLOOR_Y + 0.01, 0)
		# Not quite round: drops land a little smeared.
		stain.scale = Vector3(rng.randf_range(0.8, 1.3), 1.0, rng.randf_range(0.8, 1.3))
		stain.rotation.y = rng.randf() * TAU
		arrow.add_child(stain)
	return arrow


## Blood: shiny and dark on the floor; on the wall unshaded like the letters,
## so the trickles match them.
static func _blood_material(on_wall: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = WRITING_BLOOD if on_wall else WRITING_BLOOD_DARK.lerp(WRITING_BLOOD, 0.45)
	if on_wall:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.roughness = 0.25
		m.metallic_specular = 0.7
	return m


## The largest font size, up to WRITING_FONT_SIZE, at which a carved word
## fits on one wall piece (WRITING_MAX_WIDTH) in either
## language: a long word such as FREIHEIT is carved smaller.
static func writing_font_size(font: Font, text: String, pixel_size: float) -> int:
	var room := WRITING_MAX_WIDTH
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, WRITING_FONT_SIZE).x * pixel_size
	if width <= room:
		return WRITING_FONT_SIZE
	return maxi(WRITING_FONT_MIN, floori(WRITING_FONT_SIZE * room / width))


## This level's writing (see _writing), for the tests.
func writing() -> Dictionary:
	return _writing


## Chance in percent to notice this level's writing.
func writing_chance() -> int:
	return WRITING_CHANCE + player.explore_bonus(Training.EXPLORE_WRITING)


## Rolls once per visit, the first time the hero comes near the writing in view.
func _check_writing() -> void:
	if _writing.is_empty() or _writing.found:
		return
	var spot := cell_to_world(_writing.cell)
	var distance := Vector2(player.global_position.x - spot.x, player.global_position.z - spot.z).length()
	if distance > WRITING_RANGE:
		return
	if not has_line_of_sight(player.global_position, spot):
		return
	# Right in front of it, nobody can miss it.
	if distance <= WRITING_SURE_RANGE:
		reveal_writing()
		return
	if _writing.rolled:
		return
	_writing.rolled = true
	if randi_range(1, 100) <= writing_chance():
		reveal_writing()


## The hero noticed the writing: it shows on the wall, and the game hears of it.
func reveal_writing() -> void:
	if _writing.is_empty() or _writing.found:
		return
	_writing.found = true
	_writing.rolled = true
	var label: Label3D = _writing.label
	label.visible = true
	label.modulate.a = 0.0
	label.outline_modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 1.2)
	tween.parallel().tween_property(label, "outline_modulate:a", 1.0, 1.2)
	# The blood runs down from the letters.
	for drip in _writing.drips:
		drip.scale.y = 0.05
		create_tween().tween_property(drip, "scale:y", 1.0, randf_range(1.2, 2.6)).set_delay(0.4).set_ease(Tween.EASE_OUT)
	taken[WRITING_KEY] = true
	if not stations.has(_writing.station):
		stations.append(_writing.station)
	Effects.float_text(self, label.global_position + Vector3(0, 0.8, 0), Lang.t("Eine Inschrift!"), Color(0.9, 0.86, 0.74))
	Events.bus().writing_found.emit(_writing.text)


## Chance in percent to notice this level's lever.
func secret_chance() -> int:
	return 100 if secret_sure else TIERS[secret_tier].chance + secret_bonus + player.intuition_bonus() + player.explore_bonus(Training.EXPLORE_SECRET)


## Whether the hero found this level's secret room.
func secret_opened() -> bool:
	return _secrets.any(func(s): return s.open)


func _open_secret(s: Dictionary) -> void:
	s.open = true
	var torch: Node3D = s.lever
	# The torch tips down like a lever. A moment later the false walls grind
	# down into the floor, somewhere nearby.
	var tween := create_tween()
	tween.tween_property(torch, "rotation:x", deg_to_rad(-30), 0.35).set_trans(Tween.TRANS_BACK)
	var sinking: Array = s.walls + ([torch] if s.lever_on_wall else [])
	tween.tween_callback(func():
		for inner in s.inner:
			inner.visible = true
		# Dust rolls out of the gap while the stone grinds down.
		var dust := Effects.make_sparkles(Color(0.75, 0.62, 0.45), true)
		dust.position = cell_to_world(s.cell) + Vector3(0, 1.0, 0)
		dust.amount = 80
		dust.scale_amount_min = 2.0
		dust.scale_amount_max = 4.0
		add_child(dust)).set_delay(SECRET_DELAY)
	for node in sinking:
		tween.parallel().tween_property(node, "position:y", node.position.y - 4.6, 1.6).set_delay(SECRET_DELAY).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		for node in sinking:
			node.queue_free()
		s.body.queue_free()
		astar.set_point_solid(s.cell, false)
		_set_cell(s.cell, "."))
	secret_found.emit(torch.global_position, cell_to_world(s.cell) + Vector3(0, 2.0, 0))


## A knight who trades behind a little table.
func _build_merchant(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var rot := _facing_room(c)
	var facing := Vector3(sin(rot), 0, cos(rot))
	var knight: Node3D = load("res://assets/characters/Knight.glb").instantiate()
	knight.position = pos - facing * 0.6
	knight.rotation.y = rot
	add_child(knight)
	for part in ["1H_Sword", "2H_Sword", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "Round_Shield", "Knight_Helmet"]:
		var node := knight.find_child(part, true, false)
		if node:
			node.visible = false
	var anim: AnimationPlayer = knight.find_child("AnimationPlayer", true, false)
	anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle")
	_place("table_medium_decorated_A", pos + facing * 1.1, rot + PI * 0.5)
	_add_solid(pos, Vector3(3.0, 2, 3.0))
	stations.append({"kind": "haendler", "cell": c, "pos": pos, "used": false})


## The unused station whose cell contains a world position, if any.
func station_at(point: Vector3) -> Dictionary:
	var c := world_to_cell(point)
	for s in stations:
		if s.cell == c and not s.used:
			return s
	return {}


## The closest unused station within reach of a position, if any.
func nearest_station(from: Vector3, max_distance := SEARCH_RANGE) -> Dictionary:
	for s in stations:
		if not s.used and Vector2(from.x - s.pos.x, from.z - s.pos.z).length() <= max_distance:
			return s
	return {}


## The water closest to a spot, if the hero standing there can cast a line
## into it: no more than `max_distance` metres from its edge. Else {}.
func nearest_water(from: Vector3, max_distance: float) -> Dictionary:
	var best := {}
	var best_distance := max_distance
	for w in fishing_waters:
		var d := water_distance(w, from)
		if d <= best_distance:
			best = w
			best_distance = d
	return best


## How far a spot is from the edge of a water (0 on or over the water).
static func water_distance(w: Dictionary, from: Vector3) -> float:
	var dx := absf(from.x - w.pos.x)
	var dz := absf(from.z - w.pos.z)
	if w.round:
		return maxf(0.0, Vector2(dx, dz).length() - w.reach)
	return Vector2(maxf(0.0, dx - w.reach), maxf(0.0, dz - w.reach)).length()


## A shrine gives only one gift: its crystal goes dark afterwards.
func use_shrine(s: Dictionary) -> void:
	s.used = true
	s.motes.emitting = false
	var burst := Effects.make_sparkles(Color(0.6, 0.85, 1.0), true)
	burst.position = s.orb.position
	add_child(burst)
	var tween := create_tween()
	tween.tween_property(s.light, "light_energy", 0.0, 1.2)
	tween.parallel().tween_property(s.orb.material_override, "emission_energy_multiplier", 0.0, 1.2)
	tween.parallel().tween_property(s.orb.material_override, "albedo_color", Color(0.3, 0.3, 0.35), 1.2)


## The key in `taken` for a monster of the map slain on its start cell `c`.
static func slain_key(c: Vector2i) -> String:
	return "slain:%d:%d" % [c.x, c.y]


## The key in `taken` for a door at cell `c` left open.
static func door_key(c: Vector2i) -> String:
	return "door:%d:%d" % [c.x, c.y]


## Set in `taken` once the hero took this floor's key (held or used).
const KEY_GONE := "key_gone"


## The hero leaves this dungeon floor (up the stairs or down a trapdoor):
## remember which monsters of the map fell, which doors stand open and
## whether the key is gone, so falling back to it later finds it as it was
## left instead of a fresh floor (see _restore_left). Chests, pickups and
## the map already stay as they were through `taken` and the journal.
func note_left() -> void:
	for m in _map_enemies:
		var e = m.enemy
		if not is_instance_valid(e) or e.dead:
			taken[slain_key(m.cell)] = true
	var any_open := false
	for d in _doors:
		if d.open:
			taken[door_key(d.cell)] = true
			any_open = true
	if has_key or any_open:
		taken[KEY_GONE] = true


## Puts back what note_left remembered: open doors stay open, a key that was
## taken stays gone (and is still in the hero's hand if no door used it), and
## a guardian who fell before the key was picked up leaves it where he stood.
func _restore_left() -> void:
	var any_open := false
	for d in _doors:
		if not taken.has(door_key(d.cell)):
			continue
		any_open = true
		d.open = true
		d.leaf.queue_free()
		astar.set_point_solid(d.cell, false)
		if d.door:
			d.door.rotation.y -= deg_to_rad(105)
	if taken.has(KEY_GONE):
		for p in _pickups.duplicate():
			if p.kind == "key":
				_pickups.erase(p)
				p.node.queue_free()
		has_key = not any_open
	elif not _has_cell("K"):
		for y in height:
			for x in width:
				var c := Vector2i(x, y)
				if Enemy.LETTERS.get(cell_char(c), "") == "waechter" and taken.has(slain_key(c)):
					_build_key(cell_to_world(c))
					return


func _build_door(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var blocks_north_south := cell_char(c + Vector2i(-1, 0)) == "#" and cell_char(c + Vector2i(1, 0)) == "#"
	var rot := 0.0 if blocks_north_south else PI * 0.5
	var door := _place("wall_doorway", pos, rot)
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot
	add_child(body)
	_add_box(body, Vector3(-1.55, 2, 0), Vector3(1.0, 4, 1))
	_add_box(body, Vector3(1.55, 2, 0), Vector3(1.0, 4, 1))
	var leaf := _add_box(body, Vector3(0, 2, 0), Vector3(2.2, 4, 1))
	_doors.append({"door": door.find_child("wall_doorway_door", true, false), "leaf": leaf, "cell": c, "pos": pos, "open": false, "spans_x": blocks_north_south})


func _build_exit(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	_place("stairs", pos + Vector3(0, 0, -TILE * 0.5))
	# Pale light falling down the stairs: the way out.
	var light := OmniLight3D.new()
	light.light_color = Color(0.62, 0.78, 1.0)
	light.light_energy = 3.0
	light.omni_range = 10.0
	light.position = pos + Vector3(0, 6.0, -2.5)
	add_child(light)
	_light_spots.append(pos)
	var motes := Effects.make_sparkles(Color(0.7, 0.85, 1.0))
	motes.position = pos + Vector3(0, 2.5, -1.0)
	add_child(motes)


# --- Runtime ----------------------------------------------------------------

## Heroes and skeletons each take up the spot they stand on. Their bodies
## already block each other, but a jump onto a skull, a knockback or a spawn
## can still leave two of them inside each other. Such a pair is pushed apart
## at this speed (metres per second), and neither can strike the other until
## they stand side by side again.
const PUSH_APART_SPEED := 6.0
## How far two bodies may sink into each other before they count as stacked
## (bodies that merely touch must still be able to fight).
const STACK_TOLERANCE := 0.15


## Whether `a` and `b` (the hero or skeletons) stand inside each other or on
## top of each other.
func stacked(a, b) -> bool:
	if a == null or b == null or a == b:
		return false
	if _up_on_crate(a, b):
		return false
	var d: Vector3 = b.global_position - a.global_position
	if absf(d.y) > maxf(a.tall, b.tall) + 0.5:
		return false
	d.y = 0.0
	return d.length() < a.radius + b.radius - STACK_TOLERANCE


func _physics_process(delta: float) -> void:
	_push_apart(delta)


## Pushes overlapping hero and skeletons apart; the lighter one moves more,
## and nobody is pushed through a wall.
func _push_apart(delta: float) -> void:
	var bodies: Array[CharacterBody3D] = []
	if player is Player and not player.dead:
		bodies.append(player)
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.is_inside_tree():
			bodies.append(e)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a = bodies[i]
			var b = bodies[j]
			if _up_on_crate(a, b):
				continue
			var d: Vector3 = b.global_position - a.global_position
			if absf(d.y) > maxf(a.tall, b.tall) + 0.5:
				continue
			d.y = 0.0
			var overlap: float = a.radius + b.radius - d.length()
			if overlap <= 0.02:
				continue
			var away: Vector3 = d.normalized() if d.length() > 0.05 else _free_side(b)
			var weight_a := _push_weight(a)
			var weight_b := _push_weight(b)
			var step := minf(overlap, PUSH_APART_SPEED * delta)
			var move_a: Vector3 = -away * step * weight_b / (weight_a + weight_b)
			var move_b: Vector3 = away * step * weight_a / (weight_a + weight_b)
			# The hero is never shoved onto a tile with furniture: the
			# skeleton makes all the room instead.
			if a is Player and shoves_onto_furniture(a, move_a):
				move_b = away * step
				move_a = Vector3.ZERO
			elif b is Player and shoves_onto_furniture(b, move_b):
				move_a = -away * step
				move_b = Vector3.ZERO
			_shove(a, b, move_a)
			_shove(b, a, move_b)


## The tile to set out from for someone standing at `pos`: their own, or,
## when they stand on the free edge of a tile with furniture (only the piece
## itself is solid, see _add_fitted_solid), the free tile beside it on the
## side they stand on, so the way leads round the piece and not through it.
func set_out_cell(pos: Vector3) -> Vector2i:
	var c := world_to_cell(pos)
	if not astar.is_in_boundsv(c) or not astar.is_point_solid(c) or _stone_cut.has(c):
		return c
	var best := c
	var best_distance := INF
	for d in DIRS:
		var n := c + d
		if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
			var distance := Vector2(pos.x, pos.z).distance_to(Vector2(cell_to_world(n).x, cell_to_world(n).z))
			if distance < best_distance:
				best = n
				best_distance = distance
	return best


## Whether moving `body` by `motion` carries it off its tile onto a tile
## that is not free to walk: one with furniture, a closed door, blocks. With
## `from` the body has moved already, from there to where it is now. Monsters
## and blows never push the hero there (see Player._keep_off_furniture), so
## the hero is never squeezed in beside a piece of furniture.
func shoves_onto_furniture(body: Node3D, motion: Vector3, from = null) -> bool:
	var start: Vector3 = body.global_position if from == null else from
	var end: Vector3 = body.global_position + motion
	var flat := Vector3(end.x - start.x, 0.0, end.z - start.z)
	if flat.length() < 0.0001:
		return false
	var here := world_to_cell(start)
	var there := world_to_cell(end)
	if from == null:
		# Ahead by the body's width: the shove would press it in there.
		there = world_to_cell(end + flat.normalized() * body.radius)
	return there != here and astar.is_in_boundsv(there) and astar.is_point_solid(there)


## Whether the higher of two bodies stands on a crate. A hero up on a
## crate stack may be right above a skeleton's head, but stands on the
## crate, not on the skeleton: they are not stacked, are not pushed apart
## (which would shove the hero off the crates), and may fight.
func _up_on_crate(a, b) -> bool:
	var upper = a if a.global_position.y > b.global_position.y else b
	return upper.has_method("on_crate") and upper.on_crate()


## How hard a body is to push: bigger skeletons weigh more, and a hero
## being moved by the game (up the stairs) does not budge.
func _push_weight(body) -> float:
	if body is Player:
		return 1000.0 if body.frozen else 1.0
	return pow(float(body.tall) / 2.4, 2.0)


## Moves `body` by `motion`, ignoring `other` (they overlap already) but
## stopping at walls, furniture and everyone else.
func _shove(body: CharacterBody3D, other: CharacterBody3D, motion: Vector3) -> void:
	if motion.length() < 0.0001:
		return
	body.add_collision_exception_with(other)
	body.move_and_collide(motion)
	body.remove_collision_exception_with(other)


## A direction to step out of a body standing right on top of another:
## the first side with room, else any.
func _free_side(body: CharacterBody3D) -> Vector3:
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var cell := world_to_cell(body.global_position + d * TILE)
		if astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
			return d
	return Vector3.RIGHT

# --- Crates -------------------------------------------------------------------

## Crates lying about on this level (see Crate). Where they lie is not kept
## in the saved game: a level built again has only the crates it starts with.
var crates: Array = []
## How far the hero reaches to pick up a crate (metres, from their middle).
const CRATE_REACH := 2.4
## How far in front of the hero's middle a crate is set down.
const CRATE_AHEAD := 1.2
## The hero can set a crate on a stack whose top is up to this far above
## their feet.
const CRATE_LIFT := 1.8


func add_crate(pos: Vector3) -> Crate:
	var crate := Crate.new()
	crate.position = pos
	add_child(crate)
	crates.append(crate)
	return crate


## The crate sitting right on top of `crate`, if any.
func crate_on(crate: Crate) -> Crate:
	for other in crates:
		if other != crate and is_instance_valid(other) and absf(other.global_position.y - crate.top()) < 0.1 and crate.covers(other.global_position, -0.1):
			return other
	return null


## The topmost crate of the stack `crate` belongs to.
func stack_top(crate: Crate) -> Crate:
	var top := crate
	for i in Crate.MAX_STACK + 2:
		var above := crate_on(top)
		if above == null:
			break
		top = above
	return top


## Whether the hero or a skeleton stands on top of `crate`.
func _someone_on(crate: Crate) -> bool:
	var bodies: Array = enemies.duplicate()
	bodies.append(player)
	for b in bodies:
		# A corpse (see Corpse) lying on a crate does not hold it down.
		if is_instance_valid(b) and b is Node3D and not (b is Enemy and b.dead) and absf(b.global_position.y - crate.top()) < 0.3 and crate.covers(b.global_position, 0.5):
			return true
	return false


## The crate the hero could pick up now: the nearest one in reach with
## nothing on top and nobody standing on it, or null.
func crate_in_reach(hero: Node3D, near := Vector3.INF) -> Crate:
	var best: Crate = null
	var best_d := INF
	var feet := hero.global_position.y
	for crate in crates:
		if not is_instance_valid(crate):
			continue
		if crate.global_position.y > feet + 2.0 or crate.top() < feet - 1.2:
			continue
		var d := _flat_distance(hero.global_position, crate.global_position)
		if d > CRATE_REACH:
			continue
		if near != Vector3.INF:
			d = _flat_distance(near, crate.global_position) - crate.global_position.y * 0.01
		if d < best_d and crate_on(crate) == null and not _someone_on(crate):
			best = crate
			best_d = d
	return best


## The crate whose footprint (give or take `margin`) a point on the floor
## falls in: the top of its stack. Null when there is none.
func crate_at(point: Vector3, margin := 0.5) -> Crate:
	for crate in crates:
		if is_instance_valid(crate) and crate.covers(point, margin):
			return stack_top(crate)
	return null


## Lifts a crate off the level (into the hero's bag).
func take_crate(crate: Crate) -> void:
	crates.erase(crate)
	crate.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(crate.model, "position:y", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(crate.model, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(crate.queue_free)


## Where a crate set down by a hero facing `ahead` goes: on top of the
## stack in front of them, else onto whatever is in front of them (the
## floor, mostly). Vector3.INF when there is no room there.
func crate_spot(hero: Node3D, ahead: Vector3) -> Vector3:
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.BACK
	var feet := hero.global_position.y
	var spot := hero.global_position + ahead * CRATE_AHEAD
	# A stack right in front: the new crate goes on top of it.
	var column: Array = crates.filter(func(c): return is_instance_valid(c) and c.covers(spot, 0.35) and c.top() > feet - Crate.SIZE * Crate.MAX_STACK - 0.1)
	if not column.is_empty():
		var top: Crate = column[0]
		for c in column:
			if c.top() > top.top():
				top = c
		var count := 1
		var below := top
		while count < Crate.MAX_STACK + 1:
			var under: Crate = null
			for c in column:
				if c != below and absf(c.top() - below.global_position.y) < 0.1:
					under = c
			if under == null:
				break
			below = under
			count += 1
		if count >= Crate.MAX_STACK or top.top() > feet + CRATE_LIFT:
			return Vector3.INF
		spot = Vector3(top.global_position.x, top.top(), top.global_position.z)
	else:
		# Onto whatever lies in front: the floor, or a lower crate stack's
		# side does not count (the room check below catches that).
		var space := get_world_3d().direct_space_state
		var ray := PhysicsRayQueryParameters3D.create(Vector3(spot.x, feet + 0.5, spot.z), Vector3(spot.x, -1.0, spot.z))
		if hero is CollisionObject3D:
			ray.exclude = [(hero as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(ray)
		spot.y = hit.position.y if not hit.is_empty() else 0.0
	return spot if crate_fits(spot) else Vector3.INF


## Whether a crate standing at `spot` (the middle of its bottom) would
## touch nothing: no wall, furniture, hero, skeleton or other crate.
func crate_fits(spot: Vector3) -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * (Crate.SIZE - 0.08)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(), spot + Vector3(0, Crate.SIZE * 0.5, 0))
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Sets a crate down at a spot from crate_spot().
func put_crate(spot: Vector3) -> Crate:
	var crate := add_crate(spot)
	crate.model.scale = Vector3.ONE * 0.4
	create_tween().tween_property(crate.model, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return crate


# --- Stone blocks ---------------------------------------------------------------

## Stone blocks the hero built with on this level (see StoneBlock).
var stones: Array = []
## Where the blocks stand, as [x, z, layer, along x (1) or z (0)] per block.
## The game hands in its own list for this level and keeps it in the saved
## game; restore_stones() builds them again after build().
var built: Array = []
## How far the hero reaches to take a block back into the bag (metres from
## their middle to the block's middle), how far from them a block can be
## grabbed with the mouse and dragged to, and how far ahead a block from the
## bag is set down.
const STONE_REACH := 2.6
const STONE_DRAG_RANGE := 7.0
const STONE_AHEAD := 1.6


func add_stone(first: Vector2i, x_wise: bool, on_layer: int, is_heavy := false) -> StoneBlock:
	var stone := StoneBlock.new()
	stone.heavy = is_heavy
	stone.place(first, x_wise, on_layer)
	add_child(stone)
	stones.append(stone)
	return stone


## Builds the blocks of the saved game again (once, after build()).
func restore_stones() -> void:
	for entry in built.duplicate():
		if entry is Array and entry.size() >= 4:
			add_stone(Vector2i(int(entry[0]), int(entry[1])), int(entry[3]) == 1, int(entry[2]))
	refresh_stone_paths()


func _sync_built() -> void:
	built.clear()
	for s in stones:
		if is_instance_valid(s) and not s.heavy:
			built.append([s.cell.x, s.cell.y, s.layer, 1 if s.along_x else 0])


## How many layers of blocks stand on a grid cell: the layer a new block
## there would lie on. `except` is left out (the block being moved).
func stone_column(c: Vector2i, except: StoneBlock = null) -> int:
	var h := 0
	for s in stones:
		if s != except and is_instance_valid(s) and s.cells().has(c):
			h = maxi(h, s.layer + 1)
	return h


## The layer a block on these cells would land on: on the highest block
## under either of its two cells, else on the floor.
func stone_layer_for(first: Vector2i, x_wise: bool, except: StoneBlock = null) -> int:
	var h := 0
	for c in StoneBlock.cells_of(first, x_wise):
		h = maxi(h, stone_column(c, except))
	return h


## Whether a block can be taken or moved: nothing lies on it and nobody
## stands on it.
func stone_free(stone: StoneBlock) -> bool:
	for s in stones:
		if s != stone and is_instance_valid(s) and s.layer == stone.layer + 1:
			for c in s.cells():
				if stone.cells().has(c):
					return false
	return not _someone_on(stone)


## Whether a block would fit there: not too high, and touching no wall,
## furniture, crate, hero, skeleton or other block.
func stone_fits(first: Vector2i, x_wise: bool, on_layer: int, except: StoneBlock = null) -> bool:
	if on_layer >= StoneBlock.MAX_LAYERS:
		return false
	var box := BoxShape3D.new()
	box.size = Vector3(StoneBlock.CELL * 2.0, StoneBlock.HEIGHT, StoneBlock.CELL) - Vector3.ONE * 0.1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	var basis := Basis() if x_wise else Basis(Vector3.UP, PI * 0.5)
	query.transform = Transform3D(basis, StoneBlock.spot_of(first, x_wise, on_layer) + Vector3(0, StoneBlock.HEIGHT * 0.5, 0))
	if except != null:
		query.exclude = [except.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Where a block from the bag goes when the hero facing `ahead` sets it
## down: on the grid in front of them, lying across their way (a wall in
## front), on the floor or on top of the blocks there. Empty when there is
## no room or it would lie too high to lift there.
func stone_spot_ahead(hero: Node3D, ahead: Vector3) -> Dictionary:
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.BACK
	var x_wise := absf(ahead.z) >= absf(ahead.x)
	var first := StoneBlock.cell_for(hero.global_position + ahead * STONE_AHEAD, x_wise)
	var on_layer := stone_layer_for(first, x_wise)
	if on_layer * StoneBlock.HEIGHT > hero.global_position.y + CRATE_LIFT:
		return {}
	if not stone_fits(first, x_wise, on_layer):
		return {}
	return {"cell": first, "along_x": x_wise, "layer": on_layer}


## Where a block dragged to `point` would land, lying along x or z. Empty
## when it is too far from the hero or there is no room.
func stone_drop_spot(stone: StoneBlock, point: Vector3, x_wise: bool, hero: Node3D) -> Dictionary:
	if stone.heavy:
		return _heavy_spot(stone, point, x_wise, hero)
	var first := StoneBlock.cell_for(point, x_wise)
	var spot := StoneBlock.spot_of(first, x_wise, 0)
	var on_layer := stone_layer_for(first, x_wise, stone)
	var result := {"cell": first, "along_x": x_wise, "layer": on_layer, "ok": false}
	if _flat_distance(spot, hero.global_position) > STONE_DRAG_RANGE:
		return result
	if first == stone.cell and x_wise == stone.along_x and on_layer == stone.layer:
		return result
	result.ok = stone_fits(first, x_wise, on_layer, stone)
	return result


## Sets a block down (from the bag) at a spot from stone_spot_ahead().
func put_stone(first: Vector2i, x_wise: bool, on_layer: int) -> StoneBlock:
	var stone := add_stone(first, x_wise, on_layer)
	stone.model.scale = Vector3.ONE * 0.4
	create_tween().tween_property(stone.model, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sync_built()
	refresh_stone_paths()
	return stone


## Lifts a block off the level (into the hero's bag).
func take_stone(stone: StoneBlock) -> void:
	stones.erase(stone)
	_sync_built()
	refresh_stone_paths()
	stone.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(stone.model, "position:y", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(stone.model, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(stone.queue_free)


## The topmost free block whose footprint a point falls in, give or take
## `margin`, or null.
func stone_at(point: Vector3, margin := 0.3) -> StoneBlock:
	var best: StoneBlock = null
	for s in stones:
		if is_instance_valid(s) and s.covers(point, margin) and (best == null or s.layer > best.layer):
			best = s
	return best


## The block the hero could take back into the bag: the nearest free one in
## reach, within lifting height. Null when there is none.
func stone_in_reach(hero: Node3D) -> StoneBlock:
	var best: StoneBlock = null
	var best_d := INF
	var feet := hero.global_position.y
	for s in stones:
		if not is_instance_valid(s) or s.global_position.y > feet + 2.0 or s.top() < feet - 1.2:
			continue
		var d := _flat_distance(hero.global_position, s.global_position)
		if d <= STONE_REACH and d < best_d and stone_free(s):
			best = s
			best_d = d
	return best


## Pushes or throws a block onto another spot: it flies there in an arc,
## while its collision is there at once.
func move_stone(stone: StoneBlock, first: Vector2i, x_wise: bool, on_layer: int) -> void:
	var from := stone.model.global_transform
	stone.place(first, x_wise, on_layer)
	_sync_built()
	refresh_stone_paths()
	var to := Transform3D(Basis() if x_wise else Basis(Vector3.UP, PI * 0.5), stone.global_position)
	var model := stone.model
	model.top_level = true
	model.global_transform = from
	# A heavy block grinds along the floor instead of flying.
	var rise := 0.0 if stone.heavy else 0.6 + 0.12 * from.origin.distance_to(to.origin)
	var fly := func(t: float) -> void:
		if not is_instance_valid(model):
			return
		var q := from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), t)
		var p := from.origin.lerp(to.origin, t)
		p.y += rise * 4.0 * t * (1.0 - t)
		model.global_transform = Transform3D(Basis(q), p)
	var tween := create_tween()
	tween.tween_method(fly, 0.0, 1.0, 0.35 + 0.03 * from.origin.distance_to(to.origin))
	tween.tween_callback(func():
		if is_instance_valid(model):
			model.top_level = false
			model.transform = Transform3D())


## The height of the stone surface on the grid cell a point lies in (0 with
## no block there), for climbing onto blocks.
func stone_surface(point: Vector3) -> float:
	return stone_column(StoneBlock.grid_cell(point)) * StoneBlock.HEIGHT


## How far a heavy block may move from where it lay when the level began:
## five tiles, measured from middle to middle. Within that it goes anywhere
## on the floor, so it can be neither lost nor wedged out of a puzzle's reach.
const HEAVY_RANGE := 5.0 * TILE


## Whether a heavy block lying on these cells would still be within
## HEAVY_RANGE of where it started. Always true for the hero's own blocks.
func heavy_in_range(stone: StoneBlock, first: Vector2i, x_wise: bool) -> bool:
	return not stone.heavy or _flat_distance(StoneBlock.spot_of(first, x_wise, 0), stone.home) <= HEAVY_RANGE


## A heavy block moves freely: anywhere on the floor towards `point`, lying
## along x or z, within the hero's reach and within HEAVY_RANGE of where it
## started. It is never stacked and never passes through a wall or a shut
## gate (the way from its tile to the new one must be open floor). A point
## beyond the range is pulled back onto its edge, and "edge" says so.
func _heavy_spot(stone: StoneBlock, point: Vector3, x_wise: bool, hero: Node3D) -> Dictionary:
	var result := {"cell": stone.cell, "along_x": stone.along_x, "layer": stone.layer, "ok": false, "edge": false}
	if stone.layer != 0:
		return result
	var off := Vector3(point.x - stone.home.x, 0.0, point.z - stone.home.z)
	if off.length() > HEAVY_RANGE:
		# A little inside the edge, so the snap to the grid stays within it.
		point = stone.home + off.normalized() * (HEAVY_RANGE - StoneBlock.CELL)
		result.edge = true
	var first := StoneBlock.cell_for(point, x_wise)
	result.cell = first
	result.along_x = x_wise
	result.layer = 0
	if first == stone.cell and x_wise == stone.along_x:
		return result
	var spot := StoneBlock.spot_of(first, x_wise, 0)
	if _flat_distance(spot, hero.global_position) > STONE_DRAG_RANGE or not heavy_in_range(stone, first, x_wise):
		return result
	result.ok = _slides_onto(stone, first, x_wise) and _floor_way(stone.global_position, spot)
	return result


func _slides_onto(stone: StoneBlock, first: Vector2i, x_wise: bool) -> bool:
	return stone_layer_for(first, x_wise, stone) == 0 and stone_fits(first, x_wise, 0, stone)


## Whether open floor leads from one spot to another: no wall, pillar or
## shut gate between their tiles.
func _floor_way(from: Vector3, to: Vector3) -> bool:
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	if a == b:
		return true
	var way := grid_path(a, b)
	return not way.is_empty() and way[-1] == b


## Pushes a heavy block one grid cell on along `dir`. False when something
## is in the way, something lies on it or it would leave HEAVY_RANGE.
func push_stone(stone: StoneBlock, dir: Vector2i) -> bool:
	var next := stone.cell + dir
	if stone.layer != 0 or not stone_free(stone) or not heavy_in_range(stone, next, stone.along_x) or not _slides_onto(stone, next, stone.along_x):
		return false
	move_stone(stone, next, stone.along_x, 0)
	return true


# --- Stone blocks in the way of monsters ----------------------------------------

## Tiles that stone blocks wall off: solid for the path finding of skeletons,
## bandits, villagers and the hero's clicks until the blocks are gone again.
## Skeletons and bandits cannot climb, so a wall one block high keeps them
## out, while the hero steps over it.
var _stone_cut := {}
## How finely a tile is checked for a way past the blocks (samples per side,
## 0.4 m each), how many samples wide a gap must be for a skeleton or bandit
## to squeeze through (1.2 m: they are about that broad), and the smallest
## patch of free floor that counts as a way through.
const CUT_SAMPLES := 10
const CUT_GAP := 3
const CUT_PATCH := 4


## Whether stone blocks wall off this tile (see _stone_cut).
func stone_cut(c: Vector2i) -> bool:
	return _stone_cut.has(c)


## The way along the grid from one tile to another (as close as it gets),
## for everyone who walks by the path finding. Someone standing on a tile
## the path finding counts as solid (walled off by blocks, or the doorway of
## a locked door) can still set out from it, so a click always walks them out.
func grid_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var lift := astar.is_in_boundsv(from) and astar.is_point_solid(from)
	if lift:
		astar.set_point_solid(from, false)
	var ids := astar.get_id_path(from, to, true)
	if lift:
		astar.set_point_solid(from, true)
	return ids


## Judges again which tiles the blocks wall off: those they stand on and
## those they walled off before.
func refresh_stone_paths() -> void:
	if stones.is_empty() and _stone_cut.is_empty():
		return
	var covered := {}
	var tiles := {}
	for s in stones:
		if not is_instance_valid(s):
			continue
		for c in s.cells():
			covered[c] = true
			for corner in [Vector2(0.05, 0.05), Vector2(0.75, 0.05), Vector2(0.05, 0.75), Vector2(0.75, 0.75)]:
				tiles[world_to_cell(Vector3(c.x * StoneBlock.CELL + corner.x, 0.0, c.y * StoneBlock.CELL + corner.y))] = true
	for t in _stone_cut.keys():
		tiles[t] = true
	for t in tiles:
		if not astar.is_in_boundsv(t) or (astar.is_point_solid(t) and not _stone_cut.has(t)):
			continue
		var cut := _stone_cuts(t, covered)
		if cut and not _stone_cut.has(t):
			_stone_cut[t] = true
			astar.set_point_solid(t, true)
		elif not cut and _stone_cut.has(t):
			_stone_cut.erase(t)
			astar.set_point_solid(t, false)


## Whether the blocks on a tile cut it: no single patch of floor wide enough
## to walk joins all the sides it can be entered from. A tile split in two
## counts as cut (better a detour than a skeleton stuck at a wall).
func _stone_cuts(t: Vector2i, covered: Dictionary) -> bool:
	var n := CUT_SAMPLES
	var step := TILE / n
	var corner := cell_to_world(t) - Vector3(TILE, 0.0, TILE) * 0.5
	var floor_free := PackedByteArray()
	floor_free.resize(n * n)
	var any_covered := false
	for j in n:
		for i in n:
			var f := not covered.has(StoneBlock.grid_cell(corner + Vector3((i + 0.5) * step, 0.0, (j + 0.5) * step)))
			floor_free[j * n + i] = 1 if f else 0
			if not f:
				any_covered = true
	if not any_covered:
		return false
	# The sides that lead on to floor, north, south, west, east (a tile the
	# blocks wall off counts: the floor is there).
	var open: Array[bool] = []
	for d in DIRS_NSWE:
		var nb: Vector2i = t + d
		open.append(astar.is_in_boundsv(nb) and (not astar.is_point_solid(nb) or _stone_cut.has(nb)))
	# Only wide enough floor counts: a run of CUT_GAP free samples through it
	# along x and along z (running on past an open side).
	var wide_x := PackedByteArray()
	wide_x.resize(n * n)
	var wide_z := PackedByteArray()
	wide_z.resize(n * n)
	for j in n:
		_mark_wide(floor_free, wide_x, j * n, 1, open[2], open[3])
	for i in n:
		_mark_wide(floor_free, wide_z, i, n, open[0], open[1])
	# Patches of walkable floor.
	var comp := PackedInt32Array()
	comp.resize(n * n)
	comp.fill(-1)
	var sizes: Array[int] = []
	for k in n * n:
		if wide_x[k] == 0 or wide_z[k] == 0 or comp[k] >= 0:
			continue
		var id := sizes.size()
		var size := 0
		comp[k] = id
		var todo: Array[int] = [k]
		while not todo.is_empty():
			var q: int = todo.pop_back()
			size += 1
			var qi := q % n
			var qj := (q - qi) / n
			for nb in [q - 1 if qi > 0 else -1, q + 1 if qi < n - 1 else -1, q - n if qj > 0 else -1, q + n if qj < n - 1 else -1]:
				if nb >= 0 and wide_x[nb] == 1 and wide_z[nb] == 1 and comp[nb] < 0:
					comp[nb] = id
					todo.append(nb)
		sizes.append(size)
	# Every open side reached by no patch is a way of its own (a dead end);
	# every patch that reaches a side is one too. More than one: cut.
	var reached := {}
	var ways := 0
	for side in 4:
		if not open[side]:
			continue
		var touched := false
		for m in n:
			var k: int = [m, (n - 1) * n + m, m * n, m * n + n - 1][side]
			if comp[k] >= 0 and sizes[comp[k]] >= CUT_PATCH:
				touched = true
				reached[comp[k]] = true
		if not touched:
			ways += 1
	ways += reached.size()
	return ways >= 2 or reached.is_empty()


## Marks the samples of a line (n samples from `start`, `stride` apart) that
## lie in a run of at least CUT_GAP free ones; a run that touches an open
## end goes on beyond it.
func _mark_wide(floor_free: PackedByteArray, out: PackedByteArray, start: int, stride: int, open_before: bool, open_after: bool) -> void:
	var n := CUT_SAMPLES
	var m := 0
	while m < n:
		if floor_free[start + m * stride] == 0:
			m += 1
			continue
		var first := m
		while m < n and floor_free[start + m * stride] == 1:
			m += 1
		var length := m - first
		if first == 0 and open_before:
			length += CUT_GAP
		if m == n and open_after:
			length += CUT_GAP
		if length >= CUT_GAP:
			for r in range(first, m):
				out[start + r * stride] = 1


# --- Iron gates ------------------------------------------------------------------

## An iron grating across a one tile gap, in the stone of the walls around it:
## a stone beam on top (a kit pillar laid on its side, like the corner pillars
## beside it) and dark iron bars below it. Returns the bars, which are their
## own node so a gate can sink them into the floor and leave the beam standing.
const GATE_BAR_COUNT := 7
const GATE_BAR_TOP := 3.35
const GATE_IRON := Color(0.13, 0.13, 0.14)


func _build_iron_gate(pos: Vector3, rot: float) -> Node3D:
	var gate := Node3D.new()
	gate.position = pos
	gate.rotation.y = rot
	add_child(gate)
	# The beam reaches from corner pillar to corner pillar, its top level with
	# the top of the walls.
	var beam := _add_kit_part(["SM_Pillar", "floor", Vector3(-2.0, 3.6, 0), Vector3(1.4, 4.0 / 2.59, 1.4), 0.0], gate)
	beam.rotation.z = -PI * 0.5
	var bars := Node3D.new()
	bars.name = "Bars"
	gate.add_child(bars)
	var iron := _gate_iron()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.06
	rod.bottom_radius = 0.06
	rod.height = GATE_BAR_TOP
	rod.radial_segments = 8
	for i in GATE_BAR_COUNT:
		var bar := MeshInstance3D.new()
		bar.mesh = rod
		bar.material_override = iron
		bar.position = Vector3(lerpf(-1.35, 1.35, i / float(GATE_BAR_COUNT - 1)), GATE_BAR_TOP * 0.5, 0)
		bars.add_child(bar)
	# Two flat bands hold the bars together.
	var band := BoxMesh.new()
	band.size = Vector3(3.0, 0.12, 0.08)
	for y in [0.9, 2.5]:
		var cross := MeshInstance3D.new()
		cross.mesh = band
		cross.material_override = iron
		cross.position = Vector3(0, y, 0)
		bars.add_child(cross)
	return bars


## Where the kit's floor texture keeps the plain ground between its cobbles:
## one floor tile maps onto this square of the texture.
const FLOOR_GROUND_UV := Rect2(0.3547, 0.4906, 0.1568, 0.1568)


## The floor grate's model in two surfaces: its stone frame (0) and its bars
## (1). The model is one mesh on the KayKit colour atlas, where the bars use
## the left half of the texture and the stone the right half. The frame is
## mapped onto the kit's floor texture instead, laid on like a floor tile, so
## the rim round the hole is the same ground as the tiles beside it.
func _grate_mesh(source: Mesh) -> Mesh:
	if not _scenes.has("grate_mesh"):
		var arrays := source.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if index.is_empty():
			index.resize(verts.size())
			for i in verts.size():
				index[i] = i
		var parts := [SurfaceTool.new(), SurfaceTool.new()]
		for st: SurfaceTool in parts:
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t in range(0, index.size(), 3):
			var bar := uvs[index[t]].x < 0.5
			var st: SurfaceTool = parts[1 if bar else 0]
			for k in 3:
				var i := index[t + k]
				var v := verts[i]
				var uv := uvs[i]
				if not bar:
					# From above for the rim, from the side for the pit's walls.
					var n := normals[index[t]]
					var flat := Vector2(v.x, v.z)
					if absf(n.y) < 0.5:
						flat = Vector2(v.z if absf(n.x) > absf(n.z) else v.x, -v.y)
					uv = FLOOR_GROUND_UV.position + (flat + Vector2(2, 2)) / 4.0 * FLOOR_GROUND_UV.size
				st.set_normal(normals[i])
				st.set_uv(uv)
				st.add_vertex(v)
		var mesh := ArrayMesh.new()
		for st: SurfaceTool in parts:
			st.generate_tangents()
			st.commit(mesh)
		mesh.surface_set_material(0, source.surface_get_material(0))
		mesh.surface_set_material(1, source.surface_get_material(0))
		_scenes["grate_mesh"] = mesh
	return _scenes["grate_mesh"]


## Dark, slightly rusty iron for the bars of the gates and floor grates.
func _gate_iron() -> Material:
	if not _scenes.has("mat_gate_iron"):
		var m := StandardMaterial3D.new()
		m.albedo_color = GATE_IRON
		m.metallic = 0.35
		m.roughness = 0.75
		_scenes["mat_gate_iron"] = m
	return _scenes["mat_gate_iron"]


# --- Pressure plates and the iron gate ------------------------------------------

## Stone slabs in the floor that sink while a stone block lies on them, and
## the iron gates that sink into the floor for good once all of them do.
var _plates: Array = []
var _gates: Array = []
var _plates_pressed := 0
## Where the level's heavy blocks lie when it starts (tiles marked Q).
var _heavy_starts: Array[Vector2i] = []
const DIRS_NSWE: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## A plate fills the 2x2 build grid cells in the middle of its tile: a block
## lying on any of them presses it.
const PLATE_SIZE := StoneBlock.CELL * 2.0 - 0.1
const PLATE_UP := 0.06
const PLATE_SHADER := preload("res://shaders/pressure_plate.gdshader")
## The worn stone frame the plate sinks into: how wide its sides are and how
## far its top stands above the floor (a little above a pressed plate's top,
## so a pressed plate reads as pushed in).
const PLATE_FRAME := 0.16
const PLATE_FRAME_TOP := 0.075


func _build_plate(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(PLATE_SIZE, 0.12, PLATE_SIZE)
	slab.mesh = box
	var mat := ShaderMaterial.new()
	mat.shader = PLATE_SHADER
	mat.set_shader_parameter("plate_size", PLATE_SIZE)
	mat.set_shader_parameter("glow", 0.0)
	slab.material_override = mat
	slab.position = pos + Vector3(0, PLATE_UP, 0)
	# A quarter turn of its own, so the runes do not all face one way.
	slab.rotation.y = PI * 0.5 * (absi(c.x * 3 + c.y * 5) % 4)
	add_child(slab)
	_build_plate_frame(pos)
	var first := StoneBlock.grid_cell(pos - Vector3(StoneBlock.CELL, 0.0, StoneBlock.CELL) * 0.5)
	var cells: Array[Vector2i] = [first, first + Vector2i(1, 0), first + Vector2i(0, 1), first + Vector2i(1, 1)]
	_plates.append({"cell": c, "cells": cells, "node": slab, "mat": mat, "pressed": false})


## The low, old stone kerb around a plate, set into the floor: four sides of
## the fountain's decayed stone, a shade darker than the plate.
func _build_plate_frame(pos: Vector3) -> void:
	var stone := _decayed_stone(Color(0.4, 0.38, 0.34), 1.0, true)
	var gap := 0.012
	var inner := PLATE_SIZE * 0.5 + gap
	var height := PLATE_FRAME_TOP + 0.05
	var y := PLATE_FRAME_TOP - height * 0.5
	var long := PLATE_SIZE + (gap + PLATE_FRAME) * 2.0
	# [middle, size]: the north and south sides run the full length, the east
	# and west ones fit between them.
	var sides := [
		[Vector3(0, y, -inner - PLATE_FRAME * 0.5), Vector3(long, height, PLATE_FRAME)],
		[Vector3(0, y, inner + PLATE_FRAME * 0.5), Vector3(long, height, PLATE_FRAME)],
		[Vector3(-inner - PLATE_FRAME * 0.5, y, 0), Vector3(PLATE_FRAME, height, inner * 2.0)],
		[Vector3(inner + PLATE_FRAME * 0.5, y, 0), Vector3(PLATE_FRAME, height, inner * 2.0)],
	]
	for side in sides:
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = side[1]
		piece.mesh = mesh
		piece.material_override = stone
		piece.position = pos + side[0]
		add_child(piece)


func _build_gate(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var across_x := cell_char(c + Vector2i(-1, 0)) == "#" and cell_char(c + Vector2i(1, 0)) == "#"
	var rot := 0.0 if across_x else PI * 0.5
	var bars := _build_iron_gate(pos, rot)
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot
	add_child(body)
	_add_box(body, Vector3(0, 2, 0), Vector3(TILE, 4, 0.6))
	_gates.append({"cell": c, "node": bars, "body": body, "open": false})


func plate_count() -> int:
	return _plates.size()


func plates_pressed() -> int:
	return _plates_pressed


func gates_open() -> bool:
	return _gates.all(func(g): return g.open)


func _plate_pressed(plate: Dictionary) -> bool:
	for s in stones:
		if is_instance_valid(s) and s.layer == 0:
			for c in s.cells():
				if plate.cells.has(c):
					return true
	return false


func _check_plates() -> void:
	if _plates.is_empty():
		return
	var pressed := 0
	for plate in _plates:
		var down := _plate_pressed(plate)
		if down != plate.pressed:
			plate.pressed = down
			create_tween().tween_property(plate.node, "position:y", 0.0 if down else PLATE_UP, 0.15)
			# The carving glows up while a block weighs the plate down.
			var mat: ShaderMaterial = plate.mat
			create_tween().tween_method(func(g: float): mat.set_shader_parameter("glow", g),
					mat.get_shader_parameter("glow"), 1.0 if down else 0.0, 0.3)
			Sfx.play(self, "lever" if down else "word_klack", -4.0, plate.node.global_position)
		if down:
			pressed += 1
	if pressed == _plates_pressed:
		return
	_plates_pressed = pressed
	plates_changed.emit(pressed, _plates.size())
	if pressed == _plates.size():
		_open_gates()


## Every plate is pressed: the iron gates grind down into the floor and stay
## there, so taking a block off a plate again shuts nobody in.
func _open_gates() -> void:
	for g in _gates:
		if g.open:
			continue
		g.open = true
		g.body.queue_free()
		astar.set_point_solid(g.cell, false)
		create_tween().tween_property(g.node, "position:y", -4.1, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		gate_opened.emit(g.node.global_position)


func _process(delta: float) -> void:
	_time += delta
	for t in _torches:
		if not is_instance_valid(t.light):
			continue
		var s: float = t.seed + _time * 9.0
		t.light.light_energy = 3.4 + sin(s) * 0.25 + sin(s * 2.3) * 0.15
	for s in stations:
		if s.kind != "schrein":
			continue
		s.orb.rotation.y += delta * 1.5
		if not s.used:
			s.orb.position.y = 2.3 + sin(_time * 2.0) * 0.15
	for p in _pickups:
		# Coins lie still on the floor; keys and dropped gear hover and turn.
		if is_instance_valid(p.node) and p.kind != "coin":
			p.node.rotation.y += delta * 2.0
			p.node.position.y += sin(_time * 3.0) * delta * 0.25
	_update_spikes(delta)
	if player == null or finished:
		return
	player.in_shadow = not is_lit(player.global_position)
	_check_pickups()
	_check_doors()
	_check_secrets()
	_check_writing()
	_check_plates()
	if is_home:
		_check_stairs()
	if exit_cell.x >= 0:
		# The stairs fill the whole exit cell: climbing starts at the first step.
		if world_to_cell(player.global_position) == exit_cell:
			finished = true
			exit_reached.emit()
	if is_instance_valid(lair_exit):
		var d := Vector2(player.global_position.x - lair_exit.global_position.x, player.global_position.z - lair_exit.global_position.z)
		var inside := d.length() < LAIR_EXIT_RADIUS
		if inside and not _in_lair_exit:
			lair_exit_taken.emit()
		_in_lair_exit = inside
		lair_exit.rotation.y += delta * 0.8


func _spike_is_up(s: Dictionary) -> bool:
	return fposmod(_time + s.phase, SPIKE_PERIOD) < SPIKE_UP_TIME


func _update_spikes(delta: float) -> void:
	for s in _spikes:
		var t := fposmod(_time + s.phase, SPIKE_PERIOD)
		var target := SPIKE_DOWN_Y
		var speed := 4.0
		if t < SPIKE_UP_TIME:
			target = 0.0
			speed = 30.0
		elif t > SPIKE_PERIOD - 0.45:
			target = SPIKE_DOWN_Y + 0.35 # A small twitch warns before they shoot up.
			speed = 10.0
		s.node.position.y = move_toward(s.node.position.y, target, delta * speed * 2.0)
		var up := t < SPIKE_UP_TIME
		if up and not s.get("up", false):
			_spike_sound(s)
		s.up = up
		if player and not finished and _spike_is_up(s) and player.global_position.y < 0.6:
			var sp := cell_to_world(s.cell)
			if absf(player.global_position.x - sp.x) < 1.6 and absf(player.global_position.z - sp.z) < 1.6:
				player_hurt.emit()
		if _spike_is_up(s):
			# Skeletons caught on the spikes get hurt too.
			var sp := cell_to_world(s.cell)
			for e in enemies:
				if is_instance_valid(e) and absf(e.global_position.x - sp.x) < 1.6 and absf(e.global_position.z - sp.z) < 1.6:
					e.hurt_by_trap(sp)


## Rusty iron scraping out of the floor, when the hero is near enough to hear
## it (a hall full of spikes would drown everything else out otherwise). It is
## a quick thrust, so the scrape plays a little higher than the trap's.
func _spike_sound(s: Dictionary) -> void:
	if player == null:
		return
	var sp := cell_to_world(s.cell)
	var far := Vector2(player.global_position.x - sp.x, player.global_position.z - sp.z).length()
	if far > SPIKE_HEARD:
		return
	Sfx.play(self, "trap_spikes", -6.0 - far * 0.8, sp, 1.25)


## Whether a tile has spikes that are up or about to shoot up: skeletons
## wait at the edge instead of stepping on.
func spike_danger(c: Vector2i) -> bool:
	for s in _spikes:
		if s.cell == c:
			return fposmod(_time + s.phase, SPIKE_PERIOD) > SPIKE_PERIOD - 0.7 or _spike_is_up(s)
	return false


func is_spike_cell(c: Vector2i) -> bool:
	return _spikes.any(func(s): return s.cell == c)


func _check_pickups() -> void:
	for p in _pickups.duplicate():
		var n: Node3D = p.node
		var d := Vector2(player.global_position.x - n.global_position.x, player.global_position.z - n.global_position.z)
		if d.length() > p.radius:
			p.erase("warned")
			p.erase("wait")
			continue
		if p.has("wait"):
			# Just dropped at the hero's feet: it stays until they step away
			# and come back for it.
			continue
		if p.kind == "hoard" and not lair_cleared:
			# The dragon sleeps on its gold: it is the hero's once it fell.
			if not p.has("warned"):
				p.warned = true
				hoard_guarded.emit()
			continue
		if p.kind == "item" and not player.bag_fits(p.id):
			if not p.has("warned"):
				p.warned = true
				bag_full.emit()
			continue
		_pickups.erase(p)
		if p.has("floor"):
			floor_items.erase(p.floor)
		if p.has("id"):
			taken[p.id] = true
		var tween := create_tween()
		tween.tween_property(n, "position:y", n.position.y + 1.5, 0.35).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(n, "scale", Vector3.ONE * 0.01, 0.35).set_ease(Tween.EASE_IN)
		tween.tween_callback(n.queue_free)
		if p.kind == "key":
			key_collected.emit()
		elif p.kind == "item":
			item_collected.emit(p.id)
		elif p.kind == "ingredient":
			ingredient_collected.emit(p.ingredient)
		elif p.kind == "hoard":
			hoard = {}
			hoard_taken.emit()
		else:
			coins_collected.emit(1)


func _check_doors() -> void:
	for d in _doors:
		if d.open:
			continue
		var dist := Vector2(player.global_position.x - d.pos.x, player.global_position.z - d.pos.z).length()
		if dist > 4.6:
			continue
		if not has_key:
			if not _door_hint_shown:
				_door_hint_shown = true
				door_locked.emit()
			continue
		d.open = true
		has_key = false
		d.leaf.queue_free()
		astar.set_point_solid(d.cell, false)
		var tween := create_tween()
		tween.tween_property(d.door, "rotation:y", d.door.rotation.y - deg_to_rad(105), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		door_opened.emit()
	if not has_key and _door_hint_shown:
		# Allow the hint again once the player walked away.
		var far := true
		for d in _doors:
			if not d.open and Vector2(player.global_position.x - d.pos.x, player.global_position.z - d.pos.z).length() < 5.0:
				far = false
		if far:
			_door_hint_shown = false


# --- Searching --------------------------------------------------------------

## Gear finer than common already lying in this level's containers, counted
## by id (see loot_item).
var _rare_loot := {}


## A random piece of gear for a container on this level. Common things may
## turn up again and again, but anything finer (uncommon and up, books too)
## only once a level, so a secret room never holds the same book twice.
func loot_item(rng: RandomNumberGenerator, min_price: int, area: int) -> String:
	var id := Items.random_item(rng, min_price, "", area, _rare_loot)
	if not Items.is_common(id):
		_rare_loot[id] = int(_rare_loot.get(id, 0)) + 1
	return id


## Empties a container's loot before new loot is put in, so the gear it held
## is free to turn up elsewhere on the level.
func clear_loot(obj: Dictionary) -> void:
	var id: String = obj.loot.get("item", "")
	if _rare_loot.has(id):
		_rare_loot[id] -= 1
		if _rare_loot[id] <= 0:
			_rare_loot.erase(id)
	obj.loot = {}


## Something to search. With `roll_loot` false it starts empty, for a container
## that gets loot of its own right after.
func _add_interactable(label: String, pos: Vector3, icon_pos: Vector3, c: Vector2i, roll_loot := true) -> Dictionary:
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = hash("%s:%d:%d:%d" % [level_name, c.x, c.y, interactables.size()])
	var roll := loot_rng.randf()
	var loot := {}
	if roll < 0.3 or not roll_loot:
		loot = {}
	elif roll < 0.62:
		loot = {"gold": loot_rng.randi_range(1, 3)}
	elif roll < 0.75:
		loot = {"knives": 2}
	elif roll < 0.87:
		loot = {"potion": 1}
	else:
		loot = {"item": loot_item(loot_rng, 0, HeroLevel.place_level(self))}
	var obj := {"label": label, "pos": pos, "icon_pos": icon_pos, "cell": c, "touch_cell": c, "searched": false, "loot": loot, "lid": null,
			"id": "%s:%d,%d" % [label, c.x, c.y]}
	interactables.append(obj)
	return obj


## The closest object within reach of a world position, preferring objects
## that have not been searched yet. Empty when nothing is in reach.
func nearest_interactable(from: Vector3, max_distance := SEARCH_RANGE) -> Dictionary:
	var best := {}
	var best_d := INF
	for obj in interactables:
		var d := Vector2(from.x - obj.pos.x, from.z - obj.pos.z).length()
		if obj.searched:
			d += 1000.0
		if d - (1000.0 if obj.searched else 0.0) <= max_distance and d < best_d:
			best = obj
			best_d = d
	return best


## Marks an object as searched and returns what was inside.
## The unsearched object whose solid cell contains a world position, if any.
func unsearched_at(point: Vector3) -> Dictionary:
	var c := world_to_cell(point)
	var best := {}
	for obj in interactables:
		if obj.touch_cell == c and not obj.searched:
			if best.is_empty() or point.distance_to(obj.pos) < point.distance_to(best.pos):
				best = obj
	return best


func search(obj: Dictionary) -> Dictionary:
	if obj.searched:
		return {}
	obj.searched = true
	taken[obj.id] = true
	if obj.lid:
		create_tween().tween_property(obj.lid, "rotation:x", obj.lid.rotation.x - obj.get("lid_open", LID_OPEN), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scatter_debris(obj)
	if not obj.loot.is_empty():
		var burst := Effects.make_sparkles(Color(1.0, 0.85, 0.3), true)
		burst.position = obj.icon_pos - Vector3(0, 1.0, 0)
		add_child(burst)
	return obj.loot


## Leaves everything the hero already took as it was left: furniture
## searched (chests with their lids up, debris in front) and coins gone.
func restore_taken() -> void:
	for obj in interactables:
		if not taken.has(obj.id) or obj.searched:
			continue
		obj.searched = true
		if obj.lid:
			obj.lid.rotation.x -= obj.get("lid_open", LID_OPEN)
		_scatter_debris(obj)
	for p in _pickups.duplicate():
		if p.has("id") and taken.has(p.id):
			_pickups.erase(p)
			p.node.queue_free()


## A coin or two and a torn page left on the floor in front of a searched
## object, toward where the hero stood, so it reads as already gone through.
func _scatter_debris(obj: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(obj.cell) ^ hash(level_name)
	var front := Vector3(player.global_position.x - obj.pos.x, 0, player.global_position.z - obj.pos.z) if player else Vector3.BACK
	front = front.normalized() if front.length() > 0.01 else Vector3.BACK
	var side := front.cross(Vector3.UP)
	var base := Vector3(obj.pos.x, 0.03, obj.pos.z) + front * 1.5
	for i in rng.randi_range(1, 2):
		var coin := _place("coin", base + side * rng.randf_range(-1.0, 1.0) + front * rng.randf_range(-0.3, 0.4), 0.0)
		coin.scale = Vector3.ONE * 1.6
		coin.rotation = Vector3(0, rng.randf() * TAU, 0)
		# Worthless copper, so nobody mistakes it for gold to pick up.
		for mi in coin.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = _copper()
	var page := MeshInstance3D.new()
	page.mesh = _torn_page(rng)
	page.position = base + side * rng.randf_range(-0.8, 0.8) + Vector3(0, 0.02, 0)
	page.rotation.y = rng.randf() * TAU
	add_child(page)


static var _copper_material: StandardMaterial3D


func _copper() -> StandardMaterial3D:
	if _copper_material == null:
		_copper_material = StandardMaterial3D.new()
		_copper_material.albedo_color = Color(0.45, 0.24, 0.14)
		_copper_material.metallic = 0.5
		_copper_material.roughness = 0.7
	return _copper_material


static var _page_material: StandardMaterial3D

## A flat scrap of parchment with ragged edges.
func _torn_page(rng: RandomNumberGenerator) -> Mesh:
	if _page_material == null:
		_page_material = StandardMaterial3D.new()
		_page_material.albedo_color = Color(0.62, 0.55, 0.4)
		_page_material.roughness = 1.0
		_page_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var rim: Array[Vector3] = []
	var steps := 14
	for i in steps:
		var a := TAU * i / steps
		# A squashed square: x, z between the corners of a 0.9 x 0.65 sheet.
		var dir := Vector2(cos(a), sin(a))
		var r := 1.0 / maxf(absf(dir.x) / 0.45, absf(dir.y) / 0.32)
		r *= rng.randf_range(0.72, 1.0)
		rim.append(Vector3(dir.x * r, 0, dir.y * r))
	for i in steps:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(rim[i])
		st.add_vertex(rim[(i + 1) % steps])
	var mesh := st.commit()
	mesh.surface_set_material(0, _page_material)
	return mesh


# --- Enemies ----------------------------------------------------------------

func _spawn_enemies() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if not (Enemy.LETTERS.has(ch) or creations.has(ch) and creations[ch].type == "monster" and not safe):
				continue
			if taken.has(slain_key(c)):
				# Slain before the hero left this floor (see note_left).
				continue
			var e: Enemy
			if Enemy.LETTERS.has(ch):
				e = _spawn_enemy(Enemy.LETTERS[ch], c, elite and ch in "MA")
			else:
				e = _spawn_enemy(creations[ch].base, c, elite, Creations.monster_stats(creations[ch]))
			_map_enemies.append({"enemy": e, "cell": c})
	_spawn_horror()


func _spawn_enemy(kind: String, c: Vector2i, is_elite := false, custom := {}) -> Enemy:
	# The dragon is a boss of its own.
	var e: Enemy = Dragon.new() if kind == "drache" else (MountainKing.new() if kind == "bergkoenig" else Enemy.new())
	e.kind = kind
	e.custom = custom
	e.elite = is_elite
	var gear_chance: float = Enemy.KINDS[e.kind].get("gear_chance", -1.0)
	e.gear = _roll_gear(e.kind, c, gear_chance) if gear_chance != 0.0 else ([] as Array[String])
	e.level = self
	add_child(e)
	e.global_position = cell_to_world(c)
	if e.kind == "waechter":
		e.watch(_guarded_spot())
	if Enemy.KINDS[kind].get("boss", false):
		# The Mountain King (see Mines): a health bar at the top, and his
		# hammer the first time he falls.
		mine_boss = e
		mine_boss_bar = BossBar.new(e)
		add_child(mine_boss_bar)
		e.died.connect(func():
			if not taken.has(Mines.KING_DEFEATED):
				taken[Mines.KING_DEFEATED] = true
				_drop_item(Mines.TROPHY, e.global_position + Vector3(0.8, 0, 0.8))
				Sfx.play_gear(self, Mines.TROPHY, 0.4, e.global_position)
			boss_won.emit())
	if e is Dragon:
		dragon = e as Dragon
		dragon.awakened.connect(func(): dragon_awakened.emit(e))
		dragon_bar = BossBar.new(e)
		add_child(dragon_bar)
	e.died.connect(func():
		enemy_killed.emit(e)
		_drop_gear(e, DROP_CHANCE if not e.is_beast() else BEAST_DROP_CHANCE)
		_drop_boss_loot(e)
		# A monster of the lair leaves a little gold, the dragon a heap.
		var purse: Array = e.custom.get("purse", Enemy.KINDS[e.kind].get("purse", [0, 0]))
		_drop_coins(e.global_position, randi_range(purse[0], purse[1]))
		# The dragon guards the lair: once it falls, the lair is won.
		if lair and e.kind == "drache":
			_win_lair(e.global_position)
		# A guardian on a level without a key carries it.
		if e.kind == "waechter" and not has_key and not _has_cell("K"):
			_build_key(Vector3(e.global_position.x, 0, e.global_position.z)))
	enemies.append(e)
	return e


## Maybe one of the horrors (see Horrors): in its den ("X") every other
## visit, or, rarely, in the far end of a level deep in the dungeon. A new
## roll every time the level is built.
func _spawn_horror() -> void:
	var cell := Vector2i(-1, -1)
	for y in height:
		var x := grid[y].find("X")
		if x >= 0:
			cell = Vector2i(x, y)
			break
	if cell.x >= 0:
		if randf() >= DEN_HORROR_CHANCE:
			return
	elif not safe and not outdoor and building == "" and depth >= HORROR_FROM_DEPTH \
			and not enemies.is_empty() and randf() < DUNGEON_HORROR_CHANCE:
		cell = _far_corner()
	if cell.x < 0:
		return
	var kind := horror_kind if Enemy.HORRORS.has(horror_kind) else String(Enemy.HORRORS[randi() % Enemy.HORRORS.size()])
	_spawn_enemy(kind, cell)


## A plain floor tile far from the start (in steps), away from the stairs:
## one of the farthest few, picked at random. None if the level is small.
func _far_corner() -> Vector2i:
	var start := start_cell
	var steps := {start: 0}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if not steps.has(n) and _walkable(n):
				steps[n] = steps[c] + 1
				todo.append(n)
	var spots: Array[Vector2i] = []
	for c: Vector2i in steps:
		if steps[c] >= HORROR_MIN_STEPS and cell_char(c) in ".," and not _is_narrow(c) \
				and (exit_cell.x < 0 or (c - exit_cell).length() > 3.0):
			spots.append(c)
	if spots.is_empty():
		return Vector2i(-1, -1)
	spots.sort_custom(func(a, b): return steps[a] > steps[b])
	return spots[randi() % maxi(1, spots.size() / 4)]


## Chance for each piece of gear a skeleton may wear: higher the deeper it lies.
const GEAR_CHANCE := 0.1
const GEAR_CHANCE_PER_LEVEL := 0.05
## Chance that a worn piece drops when its skeleton falls; a monster of the
## lair carries its piece in its belly, so it always drops.
const DROP_CHANCE := 0.1
const BEAST_DROP_CHANCE := 1.0


## The items a skeleton wears: up to two (three for a brute), no specials,
## one per slot. Fixed per level and tile, like the loot in chests.
## What a guardian watches over: its fire bowl, the key, or else the stairs.
func _guarded_spot() -> Vector3:
	for ch in "fKE":
		for y in height:
			for x in width:
				if cell_char(Vector2i(x, y)) == ch:
					return cell_to_world(Vector2i(x, y))
	return Vector3.ZERO


## `chance` overrides the usual odds per piece, and `salt` tells one roll
## from the next on the same tile (a bandit that comes back after a fall).
func _roll_gear(kind: String, c: Vector2i, chance := -1.0, salt := 0) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:gear:%d:%d:%d" % [level_name, c.x, c.y, salt]) if salt > 0 else hash("%s:gear:%d:%d" % [level_name, c.x, c.y])
	var gear: Array[String] = []
	if chance < 0.0:
		chance = GEAR_CHANCE + GEAR_CHANCE_PER_LEVEL * depth
	for i in (3 if kind in ["koloss", "hauptmann"] else 2):
		if rng.randf() >= chance:
			continue
		for attempt in 6:
			# Gear that suits the place; the bosses' own fights stay as they were made.
			var id := Items.random_item(rng, 0, "", 0 if HeroLevel.FIXED.has(kind) else HeroLevel.place_level(self))
			var slot: String = Items.ALL[id].slot
			if slot != "spezial" and slot != "buch" and not gear.any(func(g): return Items.ALL[g].slot == slot):
				gear.append(id)
				break
	return gear


func _drop_gear(e: Enemy, chance := DROP_CHANCE) -> void:
	var spot := e.global_position
	var delay := 0.0
	for id in e.gear:
		if randf() < chance:
			_drop_item(id, spot)
			# It clatters onto the floor, one piece after the other.
			Sfx.play_gear(self, id, delay, spot)
			delay += 0.3
			spot += Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))


## Named bosses (the bandit chief, the dragon, the Mountain King, and any
## monster given a name in the map workshop) hold this small chance, on top
## of their usual loot, to drop one extra piece of gear that is rare or
## better (see roll_boss_loot).
const BOSS_RARE_CHANCE := 0.1


## Whether a fallen enemy is a named boss (see BOSS_RARE_CHANCE).
static func is_named_boss(e: Enemy) -> bool:
	return e.is_level_boss() or str(e.custom.get("title", "")) != ""


## The finest of TIERS whose cheapest gear a piece of gear reaches by price.
static func tier_of(id: String) -> String:
	var best := "normal"
	if not Items.ALL.has(id):
		return best
	for t in TIERS:
		if int(Items.ALL[id].price) >= int(TIERS[t].min_price) and int(TIERS[t].min_price) >= int(TIERS[best].min_price):
			best = t
	return best


## A named boss's rare loot, or "" when the roll misses (`roll` in 0..1;
## random when left out). The piece is rare or better, suits the place, and
## like all finer loot never repeats on this level (see loot_item).
func roll_boss_loot(e: Enemy, roll := -1.0) -> String:
	if not is_named_boss(e):
		return ""
	if roll < 0.0:
		roll = randf()
	if roll >= BOSS_RARE_CHANCE:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return loot_item(rng, int(TIERS["selten"].min_price), HeroLevel.place_level(self))


## Drops a named boss's rare loot, if the roll hits, beside where it fell,
## and tells the event log.
func _drop_boss_loot(e: Enemy) -> void:
	var id := roll_boss_loot(e)
	if id == "":
		return
	var spot := e.global_position + Vector3(-0.8, 0, 0.8)
	_drop_item(id, spot)
	Sfx.play_gear(self, id, 0.6, spot)
	var tier: Dictionary = TIERS[tier_of(id)]
	Events.found(Lang.t("Seltene Beute: %s (%s)") % [Items.item_name(id), Lang.t(tier.name)], tier.color)


## Gold coins spilt from a fallen bandit's purse, scattered around the spot.
## Unlike the coins placed by the map they have no id: they are kept on the
## floor list (see floor_items) until picked up, then simply gone.
func _drop_coins(pos: Vector3, amount: int) -> void:
	for i in amount:
		var angle := randf() * TAU
		_lay_coin(Vector3(pos.x, 0, pos.z) + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.5, 1.4))
	if amount > 0:
		Sfx.play_coins(self, amount, 0.3, pos)


## Hides a few ingredients in the ground for the hero's fox to find: on the
## grass of the open air, on plain floor the hero can reach in the dungeon.
## Not in the safe rooms or inside the village buildings.
func hide_ingredients() -> void:
	hidden_finds.clear()
	if (safe and not outdoor) or (building != "" and not lair):
		return
	var cells: Array[Vector2i] = []
	if outdoor:
		for y in height:
			for x in width:
				var c := Vector2i(x, y)
				if cell_char(c) == "." and call("is_open", c):
					cells.append(c)
	else:
		for c in _reachable():
			if cell_char(c) in [".", ","] and not astar.is_point_solid(c) and c != start_cell and not grates.has(c):
				cells.append(c)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := HIDDEN_OUTDOORS if outdoor else HIDDEN_IN_DUNGEON
	for i in mini(count, cells.size()):
		var c: Vector2i = cells.pop_at(rng.randi() % cells.size())
		hidden_finds.append({"cell": c, "id": Crafting.random_fox_find(rng, outdoor)})


## The companions' corner in the hero's house: a bed of straw with a water
## bowl, where the companions who stay at home rest. Running into it opens
## the companions window (station "gefaehrten").
func _build_companion_corner(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.6, 0.48, 0.26)
	straw.roughness = 1.0
	var bed := MeshInstance3D.new()
	var mound := CylinderMesh.new()
	mound.top_radius = 1.45
	mound.bottom_radius = 1.6
	mound.height = 0.16
	bed.mesh = mound
	bed.material_override = straw
	bed.position = pos + Vector3(0, 0.08, 0)
	bed.scale = Vector3(1.0, 1.0, 0.85)
	add_child(bed)
	# Loose straws on top, so it reads as straw and not as a rug.
	var stalk := BoxMesh.new()
	stalk.size = Vector3(0.5, 0.025, 0.035)
	var pale := straw.duplicate() as StandardMaterial3D
	pale.albedo_color = Color(0.74, 0.62, 0.36)
	for i in 26:
		var bit := MeshInstance3D.new()
		bit.mesh = stalk
		bit.material_override = pale if i % 2 == 0 else straw
		var angle := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 1.3
		bit.position = pos + Vector3(sin(angle) * r, 0.17, cos(angle) * r * 0.85)
		bit.rotation.y = _rng.randf() * TAU
		add_child(bit)
	# A wooden water bowl at the edge.
	var turn := _facing_room(c)
	var front := Vector3(sin(turn), 0, cos(turn))
	var side := Vector3(front.z, 0, -front.x)
	var bowl := MeshInstance3D.new()
	var tub := CylinderMesh.new()
	tub.top_radius = 0.3
	tub.bottom_radius = 0.24
	tub.height = 0.16
	bowl.mesh = tub
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.28, 0.14)
	wood.roughness = 0.9
	bowl.material_override = wood
	bowl.position = pos + front * 1.5 + side * 1.2 + Vector3(0, 0.08, 0)
	add_child(bowl)
	var water := MeshInstance3D.new()
	var face := CylinderMesh.new()
	face.top_radius = 0.26
	face.bottom_radius = 0.26
	face.height = 0.01
	water.mesh = face
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.3, 0.5, 0.65)
	blue.roughness = 0.1
	water.material_override = blue
	water.position = bowl.position + Vector3(0, 0.07, 0)
	add_child(water)
	_add_solid(pos, Vector3(3.0, 1.2, 3.0))
	stations.append({"kind": "gefaehrten", "cell": c, "pos": pos, "used": false})
	# Three places on the straw, each animal facing into the room.
	for offset in [-side * 0.85 - front * 0.5, side * 0.85 - front * 0.5, front * 0.55]:
		companion_spots.append({"pos": pos + offset + Vector3(0, 0.16, 0), "rot": turn + _rng.randf_range(-0.5, 0.5)})


## A spot for the fox's basket by the bed at c: on the floor tile in front
## of the bed, near the bed and off to one side.
func _add_fox_bed(c: Vector2i) -> void:
	var o := _open_side(c)
	if o == c:
		return
	var d := o - c
	fox_beds.append(cell_to_world(o) - Vector3(d.x, 0, d.y) * 0.6 + Vector3(d.y, 0, -d.x) * 1.2)


## Sets the fox's basket down beside every bed of the level (once).
func place_fox_baskets() -> void:
	if not _baskets.is_empty():
		return
	for spot in fox_beds:
		var basket := Pet.make_basket()
		basket.position = spot
		add_child(basket)
		_baskets.append(basket)


## The fox's basket closest to `pos`, or Vector3.INF without one.
func fox_bed_near(pos: Vector3) -> Vector3:
	var best := Vector3.INF
	for spot in fox_beds:
		if best == Vector3.INF or _flat_distance(spot, pos) < _flat_distance(best, pos):
			best = spot
	return best


## Lays a dug-up ingredient on the ground. Picked up, it goes into the
## ingredient pouch (see Crafting), not the bag. It is not marked as taken:
## the ground holds new ones the next time round.
func lay_find(id: String, pos: Vector3) -> void:
	var holder := Node3D.new()
	var lump := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.4
	lump.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.6, 0.25)
	lump.material_override = mat
	holder.add_child(lump)
	holder.position = Vector3(pos.x, 0.8, pos.z)
	add_child(holder)
	holder.add_child(Effects.make_sparkles(Color(0.7, 0.95, 0.5)))
	_pickups.append({"node": holder, "kind": "ingredient", "ingredient": id, "radius": 1.6})


## One spilt coin lying flat on the floor, kept on the floor list.
func _lay_coin(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(pos.x, 0.03, pos.z)
	holder.rotation.y = randf() * TAU
	add_child(holder)
	var coin := _place("coin", Vector3.ZERO, 0.0, holder)
	coin.scale = Vector3.ONE * 1.6
	_pickups.append({"node": holder, "kind": "coin", "radius": 1.5, "floor": _remember_on_floor("coin", "", pos)})


## Notes something lying on the floor (see floor_items) and returns the entry.
func _remember_on_floor(kind: String, id: String, pos: Vector3) -> Array:
	var entry := [kind, id, snappedf(pos.x, 0.01), snappedf(pos.z, 0.01)]
	floor_items.append(entry)
	while floor_items.size() > FLOOR_MAX:
		var oldest: Array = floor_items.pop_front()
		for p in _pickups.duplicate():
			if is_same(p.get("floor"), oldest):
				_pickups.erase(p)
				if is_instance_valid(p.node):
					p.node.queue_free()
				break
	return entry


## Lays out again what lay on the floor when the hero was last here
## (once, after build() and restore_taken()). What lies where the hero
## arrives is not picked up at once: they step off and back to take it.
func restore_floor() -> void:
	var kept := floor_items.duplicate()
	floor_items.clear()
	for entry in kept:
		if _pickups.any(func(p): return is_same(p.get("floor"), entry)):
			# Laid out by build() already (the chief's blade): keep as it is.
			floor_items.append(entry)
			continue
		if not (entry is Array and entry.size() >= 4):
			continue
		var pos := Vector3(float(entry[2]), 0, float(entry[3]))
		if str(entry[0]) == "coin":
			_lay_coin(pos)
		elif Items.ALL.has(str(entry[1])):
			_drop_item(str(entry[1]), pos)
		else:
			continue
		var n: Node3D = _pickups[-1].node
		if player and _flat_distance(player.global_position, n.global_position) <= _pickups[-1].radius:
			_pickups[-1].wait = true


## Whether an item lies on this level's floor list (see floor_items).
func lies_on_floor(id: String) -> bool:
	return floor_items.any(func(e): return e is Array and e.size() >= 2 and e[0] == "item" and e[1] == id)


## Takes a pickup lying on the floor list off the floor (the dragon's
## helpers carry it away, see DragonHelpers): no longer a pickup, gone from
## floor_items. Returns its node, which the caller frees, or null when it
## was taken already.
func take_from_floor(p: Dictionary) -> Node3D:
	if not _pickups.has(p):
		return null
	_pickups.erase(p)
	if p.has("floor"):
		floor_items.erase(p.floor)
	return p.node if is_instance_valid(p.node) else null


## The pickups the dragon's helpers may take: what lies on the floor list.
func floor_pickups() -> Array:
	return _pickups.filter(func(p): return p.has("floor") and is_instance_valid(p.node) and DragonHoard.takes(p.floor))


## Sets an item from the bag down at the hero's feet. It stays there (also
## after leaving and coming back, or a reload) until picked up again, which
## needs a step away first.
func put_on_floor(id: String, pos: Vector3) -> void:
	_drop_item(id, pos)
	_pickups[-1].wait = true


## Gear and loot left glowing on the floor until the hero walks over it.
## `keep` false is for things meant to fade (thunder ore after the storm):
## they are not put on the floor list.
func _drop_item(id: String, pos: Vector3, keep := true) -> void:
	var holder := _item_model(id)
	holder.position = Vector3(pos.x, 1.0, pos.z)
	add_child(holder)
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.9, 1.0)
	light.light_energy = 1.4
	light.omni_range = 3.5
	holder.add_child(light)
	holder.add_child(Effects.make_sparkles(Color(0.75, 0.9, 1.0)))
	var pickup := {"node": holder, "kind": "item", "id": id, "radius": 1.6}
	if keep:
		pickup.floor = _remember_on_floor("item", id, pos)
	_pickups.append(pickup)


## What an item looks like lying about: its own model, or a gem.
func _item_model(id: String) -> Node3D:
	var item: Dictionary = Items.ALL[id]
	var holder := Node3D.new()
	if item.has("model"):
		var model: Node3D = load(item.model).instantiate()
		model.scale = Vector3.ONE * float(item.get("model_scale", 1.6))
		holder.add_child(model)
	else:
		var gem := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.35
		mesh.height = 0.7
		mesh.radial_segments = 6
		mesh.rings = 2
		gem.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = item.get("tint", Color(1.0, 0.8, 0.3))
		mat.metallic = 0.6
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.6
		gem.material_override = mat
		holder.add_child(gem)
	return holder


# --- The dragon's lair ---------------------------------------------------------

## Pieces of Quaternius' Modular Dungeon kit (CC0): cobwebs, skulls, banners,
## heaps of coins and a horse statue for the dragon's lair.
const LAIR_DIR := "res://assets/lair/"


func _place_lair(piece: String, pos: Vector3, rot_y := 0.0, s := 1.0) -> Node3D:
	if not _scenes.has("lair/" + piece):
		_scenes["lair/" + piece] = load(LAIR_DIR + piece + ".fbx")
	var node: Node3D = _scenes["lair/" + piece].instantiate()
	node.position = pos
	node.rotation.y = rot_y
	node.scale = Vector3.ONE * s
	add_child(node)
	return node


## Dresses the lair: cobwebs in the back corners, tattered banners on the back
## walls, skulls on the floor and heaps of gold around the dragon's hoard.
## None of it is in the way. Fixed per level, like the walls.
func _decorate_lair() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if ch == "#" or ch == "E":
				continue
			var pos := cell_to_world(c)
			var north := cell_char(c + Vector2i(0, -1)) == "#"
			var west := cell_char(c + Vector2i(-1, 0)) == "#"
			var east := cell_char(c + Vector2i(1, 0)) == "#"
			if north and (west or east) and _rng.randf() < 0.8:
				var side := -1.0 if west else 1.0
				_place_lair("Cobweb" if _rng.randf() < 0.5 else "Cobweb2",
						pos + Vector3(side * (TILE * 0.5 - 0.35), 2.9, -TILE * 0.5 + 0.35), PI * 0.25 * side + PI, 1.4)
			elif north and ch in ".," and _rng.randf() < 0.18:
				_place_lair("Banner", pos + Vector3(0, 0, -TILE * 0.5 + 0.35), 0.0, 0.85)
			if ch in ".," and not north and _rng.randf() < 0.14 and not grates.has(c):
				_place_lair("Skull", pos + Vector3(_rng.randf_range(-1.3, 1.3), 0, _rng.randf_range(-1.3, 1.3)), _rng.randf() * TAU, 0.8)
			if ch == "C":
				# The hoard: gold heaped up around the chest.
				for i in 4:
					var angle := TAU * i / 4.0 + _rng.randf_range(-0.4, 0.4)
					_place_lair("Coin_Pile", pos + Vector3(cos(angle), 0, sin(angle)) * 2.0, _rng.randf() * TAU, _rng.randf_range(7.0, 11.0))
				if hoard.values().any(func(n): return int(n) > 0) and _hoard == null:
					_hoard = _build_hoard(c)


## The hoard the dragon's helpers brought in (see DragonHoard), on the free
## tile beside the hoard chest: a heap of coins, bigger the more it is worth,
## with little stacks of bars around it, one stack per metal in its own
## colour, and a warm glow. Walked over once the dragon has fallen, it is
## the hero's.
var _hoard: Node3D
const HOARD_SCALE := Vector2(7.0, 18.0)


func _build_hoard(chest: Vector2i) -> Node3D:
	var spot := _lair_exit_spot(chest)
	if spot.is_equal_approx(cell_to_world(chest)):
		spot += Vector3(0, 0, TILE * 0.5)
	var holder := Node3D.new()
	holder.position = spot
	add_child(holder)
	var worth := DragonHoard.coin_worth(int(hoard.get("coins", 0)), hoard)
	var size := clampf(HOARD_SCALE.x + worth / 25.0, HOARD_SCALE.x, HOARD_SCALE.y)
	_place_lair("Coin_Pile", Vector3.ZERO, randf() * TAU, size).reparent(holder, false)
	var stacks: Array = Forge.METALS.keys().filter(func(m): return int(hoard.get(m, 0)) > 0)
	for i in stacks.size():
		var angle := PI * 0.75 + TAU * i / 5.0
		_build_bar_stack(holder, Vector3(cos(angle), 0, sin(angle)) * 1.1, angle, stacks[i], int(hoard[stacks[i]]))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.78, 0.35)
	glow.light_energy = 1.3
	glow.omni_range = 4.0
	glow.position = Vector3(0, 1.2, 0)
	holder.add_child(glow)
	holder.add_child(Effects.make_sparkles(Color(1.0, 0.85, 0.4)))
	_pickups.append({"node": holder, "kind": "hoard", "radius": 1.8})
	return holder


## A small stack of bars of one metal: a bar for each, up to BAR_STACK_MAX,
## in rows of three laid crosswise.
const BAR_STACK_MAX := 9
const BAR_SIZE := Vector3(0.42, 0.14, 0.2)


func _build_bar_stack(holder: Node3D, at: Vector3, rot: float, metal: String, count: int) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Forge.METALS[metal].color
	mat.metallic = 0.8
	mat.roughness = 0.35
	var mesh := BoxMesh.new()
	mesh.size = BAR_SIZE
	mesh.material = mat
	var stack := Node3D.new()
	stack.name = "Barren_" + metal
	stack.position = at
	stack.rotation.y = rot
	holder.add_child(stack)
	for i in mini(count, BAR_STACK_MAX):
		var layer := i / 3
		var bar := MeshInstance3D.new()
		bar.mesh = mesh
		var across := (i % 3 - 1) * (BAR_SIZE.z + 0.03)
		bar.position = Vector3(0, BAR_SIZE.y * (layer + 0.5), across)
		if layer % 2 == 1:
			bar.position = Vector3(across, BAR_SIZE.y * (layer + 0.5), 0)
			bar.rotation.y = PI * 0.5
		stack.add_child(bar)


## How close (metres) the hero must step to the way out's middle to leave.
const LAIR_EXIT_RADIUS := 1.3
## The way out shines up this long after the dragon fell.
const LAIR_EXIT_DELAY := 1.5
const LAIR_EXIT_COLOR := Color(1.0, 0.8, 0.35)


## The dragon has fallen where it hovered: the lair is won. A glowing way
## out opens on a free tile next to where it fell (not on it, so picking up
## its gold does not whisk the hero away).
func _win_lair(at: Vector3) -> void:
	if lair_cleared:
		return
	lair_cleared = true
	lair_won.emit()
	var spot := _lair_exit_spot(world_to_cell(at))
	await get_tree().create_timer(LAIR_EXIT_DELAY).timeout
	if not is_inside_tree():
		return
	lair_exit = _build_lair_exit(spot)


## A free floor tile beside `c` for the way out (or `c` itself, if none).
func _lair_exit_spot(c: Vector2i) -> Vector3:
	var best := c
	var best_dist := INF
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var n: Vector2i = c + d
		if not astar.is_in_boundsv(n) or astar.is_point_solid(n) or cell_char(n) != ".":
			continue
		# The one nearest the stairs the hero came down, as a reminder of
		# the way they came.
		var dist := Vector2(n - start_cell).length()
		if dist < best_dist:
			best_dist = dist
			best = n
	return cell_to_world(best)


## A ring of golden light on the floor with a glow and sparkles rising from it.
func _build_lair_exit(pos: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = "LairExit"
	add_child(holder)
	holder.global_position = Vector3(pos.x, 0.05, pos.z)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.3
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = LAIR_EXIT_COLOR
	ring.material_override = mat
	holder.add_child(ring)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.02
	disc.mesh = cyl
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color = Color(LAIR_EXIT_COLOR, 0.45)
	disc.material_override = glow_mat
	holder.add_child(disc)
	var light := OmniLight3D.new()
	light.light_color = LAIR_EXIT_COLOR
	light.light_energy = 2.5
	light.omni_range = 6.0
	light.position.y = 1.2
	holder.add_child(light)
	holder.add_child(Effects.make_sparkles(LAIR_EXIT_COLOR))
	holder.scale = Vector3.ONE * 0.01
	create_tween().tween_property(holder, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(self, "magic", -4.0, pos)
	return holder


# --- A hero's home -------------------------------------------------------------

## The names of a home's storeys, from the ground up.
const STOREY_NAMES := ["Erdgeschoss", "Obergeschoss", "Dachkammer"]


## Splits a home into its storeys: every room sealed off by walls is one,
## counted from west to east.
func _find_storeys() -> void:
	_storeys.clear()
	if not is_home:
		return
	var rooms: Array = []
	var seen := {}
	for x in width:
		for y in height:
			var c := Vector2i(x, y)
			if cell_char(c) == "#" or seen.has(c):
				continue
			var room: Array[Vector2i] = [c]
			seen[c] = true
			var i := 0
			while i < room.size():
				for d in DIRS:
					var n := room[i] + d
					if cell_char(n) != "#" and not seen.has(n):
						seen[n] = true
						room.append(n)
				i += 1
			rooms.append(room)
	for k in rooms.size():
		for c in rooms[k]:
			_storeys[c] = k


## Which storey of a home a tile is on (0 is the ground floor).
func storey_of(c: Vector2i) -> int:
	return _storeys.get(c, 0)


func storey_count() -> int:
	var top := -1
	for c in _storeys:
		top = maxi(top, _storeys[c])
	return top + 1


## The name of a storey of a home, in the chosen language.
func storey_name(storey: int) -> String:
	if storey <= 0:
		return Lang.t(STOREY_NAMES[0])
	if storey >= storey_count() - 1 and storey_count() >= 3:
		return Lang.t(STOREY_NAMES[2])
	return Lang.t(STOREY_NAMES[1])


## The stairs at the other end of the stairs on `c`: "<" leads to the ">"
## of the storey above, ">" to the "<" of the storey below.
func stair_target(c: Vector2i) -> Vector2i:
	var ch := cell_char(c)
	if not is_home or not "<>".contains(ch):
		return Vector2i(-1, -1)
	var storey := storey_of(c) + (1 if ch == "<" else -1)
	var want := ">" if ch == "<" else "<"
	for y in height:
		for x in width:
			var n := Vector2i(x, y)
			if cell_char(n) == want and storey_of(n) == storey:
				return n
	return Vector2i(-1, -1)


## A free tile beside `c` to stand on: plain floor first, the way south first.
func _open_side(c: Vector2i) -> Vector2i:
	for plain in [".P", ".P+"]:
		for d: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
			if plain.contains(cell_char(c + d)):
				return c + d
	return c


## Walking onto the stairs of a home takes the hero to the next storey.
func _check_stairs() -> void:
	var cell := world_to_cell(player.global_position)
	if not "<>".contains(cell_char(cell)):
		_stair_cell = Vector2i(-1, -1)
		return
	if cell == _stair_cell:
		return
	_stair_cell = cell
	var to := stair_target(cell)
	if to.x < 0:
		return
	stairs_taken.emit(cell_to_world(_open_side(to)), cell_char(cell) == "<", storey_of(to))


## A home is lit from within: a warm lamp over the middle of every storey,
## so no room (the attic least of all) sits in the dark.
func _light_storeys() -> void:
	var sums := {}
	for c in _storeys:
		var k: int = _storeys[c]
		if not sums.has(k):
			sums[k] = [Vector3.ZERO, 0]
		sums[k][0] += cell_to_world(c)
		sums[k][1] += 1
	for k in sums:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.84, 0.62)
		lamp.light_energy = 2.4
		lamp.omni_range = 11.0
		lamp.position = sums[k][0] / float(sums[k][1]) + Vector3(0, 3.6, 0)
		add_child(lamp)
		_light_spots.append(sums[k][0] / float(sums[k][1]))


## Wooden planks, as in the houses of the village. The stairs down leave a
## hole in the floor, and the tiles kept for furniture are marked with
## chalk on the boards.
func _build_home_floor(c: Vector2i, ch: String) -> void:
	if ch == ">":
		return
	if not _scenes.has("mat_home_wood"):
		var wood := StandardMaterial3D.new()
		wood.albedo_texture = load("res://assets/house/wood_floor.jpg")
		wood.uv1_scale = Vector3(2, 2, 2)
		wood.roughness = 0.85
		_scenes["mat_home_wood"] = wood
		var plank := PlaneMesh.new()
		plank.size = Vector2(TILE, TILE)
		_scenes["mesh_home_plank"] = plank
		var chalk := StandardMaterial3D.new()
		chalk.albedo_color = Color(0.92, 0.88, 0.78, 0.55)
		chalk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		chalk.roughness = 1.0
		_scenes["mat_home_chalk"] = chalk
	var floor_piece := MeshInstance3D.new()
	floor_piece.mesh = _scenes["mesh_home_plank"]
	floor_piece.material_override = _scenes["mat_home_wood"]
	floor_piece.position = cell_to_world(c) + Vector3(0, 0.02, 0)
	add_child(floor_piece)
	if ch != "+":
		return
	# A chalked frame: room for a piece of furniture.
	var frame := Node3D.new()
	frame.name = "Chalk_%d_%d" % [c.x, c.y]
	add_child(frame)
	chalk_marks[c] = frame
	var inner := TILE * 0.62
	for side in 4:
		var strip := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(inner, 0.07) if side < 2 else Vector2(0.07, inner)
		strip.mesh = quad
		strip.material_override = _scenes["mat_home_chalk"]
		var off := inner * 0.5 * (1.0 if side % 2 == 0 else -1.0)
		strip.position = cell_to_world(c) + (Vector3(0, 0.04, off) if side < 2 else Vector3(off, 0.04, 0))
		frame.add_child(strip)


## Stairs up rise against the north wall, stairs down sink into a dark
## shaft through the floor.
func _build_stairs(c: Vector2i, up: bool) -> void:
	var pos := cell_to_world(c)
	stairs.append({"cell": c, "up": up, "storey": storey_of(c)})
	if up:
		_place("stairs", pos + Vector3(0, 0, -TILE * 0.5))
		return
	_place("stairs", pos + Vector3(0, -WALL_DEPTH, -TILE * 0.5))
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TILE, WALL_DEPTH, TILE)
	shaft.mesh = box
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.06, 0.05)
	dark.cull_mode = BaseMaterial3D.CULL_FRONT
	dark.roughness = 1.0
	shaft.material_override = dark
	shaft.position = pos + Vector3(0, -WALL_DEPTH * 0.5, 0)
	add_child(shaft)
	# A rim of planks round the hole.
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.36, 0.25, 0.17)
	rim.roughness = 0.9
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]:
		var beam := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.2, 0.12, TILE) if side.x != 0.0 else Vector3(TILE, 0.12, 0.2)
		beam.mesh = b
		beam.material_override = rim
		beam.position = pos + side * (TILE * 0.5 - 0.1) + Vector3(0, 0.06, 0)
		add_child(beam)


## How deep the stairs down of a home reach below the floor.
const WALL_DEPTH := 4.0


## The front door of a home: a doorway in the low south wall with the
## daylight of the lane outside, and a mat to wipe your feet on.
func _build_home_door(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var doorway := _place("wall_doorway", pos + Vector3(0, 0, TILE * 0.5), 0.0)
	doorway.scale.y = LOW_WALL_SCALE
	var leaf: Node3D = doorway.find_child("wall_doorway_door", true, false)
	if leaf:
		leaf.visible = false
	var mat := MeshInstance3D.new()
	var rug := BoxMesh.new()
	rug.size = Vector3(1.6, 0.03, 1.0)
	mat.mesh = rug
	var weave := StandardMaterial3D.new()
	weave.albedo_color = Color(0.45, 0.28, 0.2)
	weave.roughness = 1.0
	mat.material_override = weave
	mat.position = pos + Vector3(0, 0.05, 0.9)
	add_child(mat)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 2.2
	light.omni_range = 9.0
	light.position = pos + Vector3(0, 3.5, 2.0)
	add_child(light)
	_light_spots.append(pos)


# --- Home upgrades (see HomeUpgrades) -------------------------------------------

## Where each built upgrade of a home stands (upgrade id -> cell), its
## furniture, and the shelf of the trophy wall.
var _upgrade_cells := {}
var _upgrade_nodes := {}
var _trophy_shelf: Node3D
## Height of a trophy statuette on the shelf (metres).
const TROPHY_STATUE := 0.9


## Builds the furniture of every upgrade built so far on the chalked spots of
## a home (each only once), and puts the trophies won on the trophy wall.
func show_home_upgrades(built: Dictionary, won: Dictionary) -> void:
	if not is_home:
		return
	for id in HomeUpgrades.ALL:
		if not HomeUpgrades.has(built, id) or _upgrade_nodes.has(id):
			continue
		var slot := _upgrade_slot(id)
		if slot.is_empty():
			continue
		_upgrade_cells[id] = slot.cell
		_build_upgrade(id, slot.cell)
	if _upgrade_nodes.has("trophaeen"):
		_show_trophies(won)


## The home's own storage chest, or (-1, -1).
func _home_chest_cell() -> Vector2i:
	for s in stations:
		if s.kind == "lager" and not s.get("upgrade", false):
			return s.cell
	return Vector2i(-1, -1)


## Whether a tile has a wall right behind it (to the north).
func _against_back_wall(c: Vector2i) -> bool:
	return cell_char(c + Vector2i(0, -1)) == "#"


## Whether a tile has a wall at its side (west or east).
func _against_side_wall(c: Vector2i) -> bool:
	return cell_char(c + Vector2i(-1, 0)) == "#" or cell_char(c + Vector2i(1, 0)) == "#"


## The furniture spot for an upgrade, or {} when every spot is taken. The
## second chest goes next to the first; the trophy wall hangs on a back wall,
## high up in the house; the workbench stands against a side wall up there.
func _upgrade_slot(id: String) -> Dictionary:
	var taken: Array = _upgrade_cells.values()
	var chest := _home_chest_cell()
	var best := {}
	var best_score := -INF
	for slot in furniture_slots:
		var c: Vector2i = slot.cell
		if taken.has(c):
			continue
		var storey: int = slot.storey
		var score := 0.0
		match id:
			"truhe":
				score = -Vector2(c - chest).length() if chest.x >= 0 and storey_of(chest) == storey else -100.0 - storey
			"trophaeen":
				score = storey * 10.0 + (5.0 if _against_back_wall(c) else 0.0) + c.x * 0.01
			_:
				score = storey * 10.0 + (3.0 if _against_side_wall(c) else 0.0) - (4.0 if _against_back_wall(c) else 0.0) - c.y * 0.1
		if score > best_score:
			best_score = score
			best = slot
	return best


func _build_upgrade(id: String, c: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Upgrade_" + id
	add_child(root)
	_upgrade_nodes[id] = root
	# The spot is taken now: the chalk frame is wiped away.
	if chalk_marks.has(c):
		chalk_marks[c].queue_free()
		chalk_marks.erase(c)
	var pos := cell_to_world(c)
	# Furniture beside a side wall turns its back to that wall.
	var rot := 0.0
	if cell_char(c + Vector2i(-1, 0)) == "#":
		rot = PI * 0.5
	elif cell_char(c + Vector2i(1, 0)) == "#":
		rot = -PI * 0.5
	match id:
		"werkstatt":
			var bench := Node3D.new()
			root.add_child(bench)
			_place("table_medium_decorated_A", pos, rot, bench)
			_place("stool", pos + Vector3(sin(rot), 0, cos(rot)) * 1.3, rot, bench)
			_place("sword_shield", pos + Vector3(-sin(rot), 0, -cos(rot)) * 1.55, rot, bench)
			_add_fitted_solid(bench, pos, 1.2, Vector2(2.6, 2.6))
			astar.set_point_solid(c, true)
			stations.append({"kind": "hauswerkbank", "cell": c, "pos": pos, "used": false, "upgrade": true})
		"truhe":
			_add_fitted_solid(_place("chest", pos, rot, root), pos, 1.5)
			astar.set_point_solid(c, true)
			stations.append({"kind": "lager", "cell": c, "pos": pos, "used": false, "upgrade": true})
		"trophaeen":
			_build_trophy_wall(root, pos)
			stations.append({"kind": "trophaeen", "cell": c, "pos": pos + Vector3(0, 0, -TILE * 0.5 + 0.6), "used": false, "upgrade": true})


## A dark oak board on the back wall with a long shelf in front of it: the
## statuettes of the trophies stand on the shelf, two shields hang beside
## them. The shelf is solid, so the hero runs into it to look at the
## trophies, but shallow enough to leave the rest of the tile free to walk.
func _build_trophy_wall(root: Node3D, pos: Vector3) -> void:
	var oak := StandardMaterial3D.new()
	oak.albedo_texture = load("res://assets/house/wood_floor.jpg")
	oak.albedo_color = Color(0.55, 0.38, 0.26)
	oak.roughness = 0.8
	var back := pos.z - TILE * 0.5 + 0.12
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(TILE - 0.6, 2.4, 0.1)
	board.mesh = board_mesh
	board.material_override = oak
	board.position = Vector3(pos.x, 2.1, back)
	root.add_child(board)
	var shelf := MeshInstance3D.new()
	var shelf_mesh := BoxMesh.new()
	shelf_mesh.size = Vector3(TILE - 0.8, 0.9, 0.7)
	shelf.mesh = shelf_mesh
	shelf.material_override = oak
	shelf.position = Vector3(pos.x, 0.45, back + 0.4)
	root.add_child(shelf)
	_add_solid(Vector3(pos.x, 0, back + 0.4), Vector3(TILE - 0.8, 0.9, 0.8))
	for side in [-1.0, 1.0]:
		var banner := _place("banner_shield_brown", Vector3(pos.x + side * 1.25, 1.2, back + 0.1), 0.0, root)
		banner.scale = Vector3.ONE * 0.6
	_trophy_shelf = Node3D.new()
	_trophy_shelf.position = Vector3(pos.x, 0.9, back + 0.4)
	root.add_child(_trophy_shelf)


## One small statuette of each foe felled, side by side on the shelf.
func _show_trophies(won: Dictionary) -> void:
	if _trophy_shelf == null:
		return
	for child in _trophy_shelf.get_children():
		_trophy_shelf.remove_child(child)
		child.queue_free()
	var shown := HomeUpgrades.trophies_shown(won)
	var span := TILE - 1.2
	for i in shown.size():
		var kind: String = shown[i]
		var statue := _trophy_statue(kind)
		if statue == null:
			continue
		statue.position.x = -span * 0.5 + span * (i + 0.5) / shown.size()
		_trophy_shelf.add_child(statue)


## A foe's own model, shrunk to a statuette on a little metal plinth and
## frozen in its idle pose.
func _trophy_statue(kind: String) -> Node3D:
	var stats: Dictionary = Enemy.KINDS.get(kind, {})
	if stats.is_empty():
		return null
	var path := "res://assets/%s/%s.%s" % [stats.get("dir", "enemies"), stats.model, stats.get("ext", "glb")]
	if not ResourceLoader.exists(path):
		return null
	var pivot := Node3D.new()
	var body: Node3D = load(path).instantiate()
	pivot.add_child(body)
	body.rotation.y = float(stats.get("turn", 0.0))
	var anim: AnimationPlayer = body.find_child("AnimationPlayer", true, false)
	var idle := String(stats.get("anims", {}).get("Idle", "Idle"))
	if anim and anim.has_animation(idle):
		anim.play(idle)
		anim.seek(0.0, true)
		anim.pause()
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		var to_body := Transform3D.IDENTITY
		var n: Node = mesh
		while n != body and n is Node3D:
			to_body = (n as Node3D).transform * to_body
			n = n.get_parent()
		var b := to_body * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var fit := minf(TROPHY_STATUE / maxf(box.size.y, 0.01), 0.55 / maxf(maxf(box.size.x, box.size.z), 0.01))
	pivot.scale = Vector3.ONE * fit
	pivot.position.y = -box.position.y * fit + 0.04
	var plinth := MeshInstance3D.new()
	var plinth_mesh := CylinderMesh.new()
	plinth_mesh.top_radius = 0.26
	plinth_mesh.bottom_radius = 0.3
	plinth_mesh.height = 0.08
	plinth.mesh = plinth_mesh
	var plinth_mat := StandardMaterial3D.new()
	plinth_mat.albedo_color = HomeUpgrades.TROPHY_COLORS.get(kind, Color.WHITE).darkened(0.3)
	plinth_mat.metallic = 0.6
	plinth_mat.roughness = 0.4
	plinth.material_override = plinth_mat
	var holder := Node3D.new()
	holder.name = "Trophy_" + kind
	holder.add_child(plinth)
	holder.add_child(pivot)
	return holder

# --- The bank's vault cellar ----------------------------------------------------

## Iron bars across a one tile gap: solid, but you can see through.
func _build_bars(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	_build_iron_gate(pos, 0.0)
	_add_solid(pos, Vector3(TILE, 4, 0.6))


## Fills the vaults behind the bars: one for every hero who rented one, in
## the order they rented, each with a name plate, their gold and treasures.
## The hero's own vault opens when they run into its bars.
func refresh_vaults() -> void:
	for node in _vault_shows:
		if is_instance_valid(node):
			node.queue_free()
	_vault_shows.clear()
	stations = stations.filter(func(s): return s.kind != "tresor")
	var holders := Bank.vault_holders()
	for i in _vault_slots.size():
		var slot := _vault_slots[i]
		var bars := slot + (Vector2i(0, 1) if cell_char(slot + Vector2i(0, 1)) == "=" else Vector2i(0, -1))
		var owner: String = holders[i] if i < holders.size() else ""
		var show := Node3D.new()
		show.position = cell_to_world(slot)
		add_child(show)
		_vault_shows.append(show)
		var plate := Label3D.new()
		plate.text = owner if owner != "" else Lang.t("Zu vermieten")
		plate.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
		plate.font_size = 48
		plate.pixel_size = 0.012
		plate.outline_size = 10
		plate.modulate = Color(1.0, 0.82, 0.4) if owner == hero and owner != "" else Color(0.85, 0.85, 0.9)
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.position = cell_to_world(bars) - show.position + Vector3(0, 4.3, 0)
		show.add_child(plate)
		if owner == "":
			continue
		var gold := Bank.gold(owner)
		if gold > 0:
			var stack := _place("coin_stack_large", Vector3(1.1, 0, -1.0), 0.4, show)
			stack.scale = Vector3.ONE * clampf(0.6 + gold / 200.0, 0.6, 1.6)
		var items := Bank.vault_items(owner)
		for k in items.size():
			if not Items.ALL.has(items[k]):
				continue
			var thing := _item_model(items[k])
			thing.position = Vector3(-1.2 + (k % 3) * 1.2, 0.8, -1.2 + (k / 3) * 1.1)
			thing.rotation.y = k * 0.7
			show.add_child(thing)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.85, 0.55)
		glow.light_energy = 1.2
		glow.omni_range = 4.0
		glow.position = Vector3(0, 2.5, 0)
		show.add_child(glow)
		if owner == hero:
			stations.append({"kind": "tresor", "cell": bars, "pos": cell_to_world(bars), "used": false})


## True when nothing blocks the view between two points on the grid.
## A closed door blocks it too, even for someone standing in its doorway.
func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	if door_between(a, b):
		return false
	var from := Vector2(a.x, a.z) / TILE
	var to := Vector2(b.x, b.z) / TILE
	var origin := Vector2i(roundi(from.x), roundi(from.y))
	var target := Vector2i(roundi(to.x), roundi(to.y))
	var steps := int(from.distance_to(to) * 4.0) + 1
	for i in range(1, steps):
		var p := from.lerp(to, float(i) / steps)
		var c := Vector2i(roundi(p.x), roundi(p.y))
		if c == target:
			break
		if c == origin:
			continue # The tile one stands on (a doorway, say) hides nothing.
		if is_opaque(c):
			return false
	return true


## Whether a closed door stands between two points: the straight line from
## one to the other passes through its leaf. Nobody strikes, shoots or looks
## through a closed door, not even at someone standing right in its doorway.
func door_between(a: Vector3, b: Vector3) -> bool:
	for d in _doors:
		if d.open:
			continue
		var p: Vector3 = d.pos
		# How far each point is from the leaf (across it), and where along
		# the doorway each one stands.
		var across_a: float = a.z - p.z if d.spans_x else a.x - p.x
		var across_b: float = b.z - p.z if d.spans_x else b.x - p.x
		if across_a * across_b >= 0.0:
			continue # Both on the same side of the leaf.
		var along_a: float = a.x - p.x if d.spans_x else a.z - p.z
		var along_b: float = b.x - p.x if d.spans_x else b.z - p.z
		var along := lerpf(along_a, along_b, across_a / (across_a - across_b))
		if absf(along) <= TILE * 0.5:
			return true
	return false


func is_opaque(c: Vector2i) -> bool:
	var ch := cell_char(c)
	if ch == "#" or ch == "?":
		return true
	if ch == "D":
		for d in _doors:
			if d.cell == c:
				return not d.open
	return false
