class_name Outdoor
extends Level
## The world above ground, reached by the last stairs of the dungeon: the hero
## steps out of a crypt onto a graveyard, follows a long path through the
## woods and comes to a village. Villagers go about their work there, and
## the village elder gives the hero an empty house with a bed and a chest.
##
## Map legend (one character per 4x4 m tile). The one list of the letters
## is Tiles.OUTDOOR: claim a new letter there first. In short:
##   #  forest (trees, cannot be crossed)    .  grass         ,  dirt path
##   P  start, in front of the crypt door    ~  pond (fish bite here, see Fishing)
##   R  the crypt (a block of tiles)         g  grave         d  dead tree
##   z  graveyard fence                      a  gate in the fence
##   l  lantern on a post                    p  pumpkins      r  rock
##   T  tree                                 t  tree stump with logs
##   e  barrels, crates and sacks            q  well
##   Buildings, each a rectangular block of the same letter:
##   h  house (half-timbered, see VillageHouse)   j  smithy   n  tavern   m  market   u  windmill
##   y  pumpkin field
##   ^  Weavers' Lane: a row of narrow two-storey town houses, one per
##      tile across the front (see VillageHouse.build_narrow), numbered from
##      west to east. Every one is a home for a hero (see Homes), entered by
##      its own door; inside, all of them share the building floor with the
##      line "building: ^" (bed, chest, stairs and room for furniture).
##   The hero's house: I  stone wall   i  wooden floor (a gap in the
##   walls is the door)   B  bed (save and log out)   L  chest (storage)
##   :  paved square         F  fountain (heals)   x  bench
##   More buildings: s  temple (a chapel)   k  office of the crown   o  post office
##   w  adventurers' guild   b  bank. A building turns its door to the square or path.
##   Villagers: 0 elder, 1 smith (melts, forges and mends gear at the forge
##   on the tile to his left, see Forge), 2 farmer, 3 woodcutter, 4 guard,
##   5 tavern guest, 6 shopkeeper (buys and sells), 7 child, 8 scholar,
##   9 water carrier, K herald of the crown, O priestess, G guild master,
##   M postmaster, Y banker, Z barber, S stonemason (sells stone blocks to build with,
##   his stone yard is on the tile behind him). Now and then the herald calls out news on the square,
##   and the villagers come over to listen.
##   The robbers' pass east of the village: N tent   f campfire   C treasure chest
##   and the bandits who roam there and come back a while after they fall:
##   c cutthroat, A poacher (crossbow), X bruiser, Q bandit chief (see Enemy).
##   The world keeps the time of day (see DayNight): lanterns and the
##   windows of the houses glow at night, most villagers go home to sleep,
##   the dead rise from the graves and roam the graveyard until dawn, and
##   the bandits of the pass are bolder in the dark.
##   The world has weather too (see Weather): rain brings slimes out of the
##   pond, fog sends fog wraiths drifting among the dead trees (d) and hides
##   a sneaking hero, and in a thunderstorm bats swarm around the rocks (r)
##   while lightning leaves glowing thunder ore beside them. Rain leaves
##   puddles on the grass, the paths and the square that splash underfoot
##   and dry up a while after it (see Puddles).
##   The wolf hollow north of the pass, where beasts roam and come back the
##   same way: W wolf, H orc, J yeti, U spider.   ;  the hollow's pond,
##   where the moon trout bites at night (see Fishing).
##   Peaceful animals that graze in the woods and bolt from the hero
##   (see Animal): D doe, V stag, & fox.
##   !  the bounty board: fresh hunts every morning (see Bounties)
##   The crafting square on the west side of the market square, beside
##   Gorm's forge (see CraftingSquare): +  fine metalwork bench
##   %  gem cutter's wheel   *  alchemist's table   $  the hero's storage chest
##   E  the way down into the dragon's lair: a stone arch over stairs into
##      the dark (a block of tiles, see Level "lair: yes")
##   (  a dark, creepy hole in the ground: run into it to climb down into a
##      small, pitch-black cave of its own (see Level "dark: yes"), where a
##      nameless horror may lurk (see Horrors). The holes are numbered from
##      the top of the map down, west to east within a row; hole n leads to
##      the floor with the line "building: loch<n>".
##   v  a stone pedestal with a food basket on top, too high to reach from
##      the ground or from one crate: stack two crates beside it. Three
##      wooden crates lie close by (see Crate).
##   @  the wandering merchant's pitch: an empty patch of grass, but on his
##      nights (see Wanderer) Zarek stands here from nightfall to dawn,
##      with his covered cart on the tile north of him.
##   ?  plain grass, where a chest lies buried; a treasure map from a
##      bottle marks it (see TreasureMaps)
##   >  a boulder at the forest's edge with a hidden cave beneath it; a
##      treasure map from a bottle tells of it, and then it rolls aside
##      (see TreasureMaps), down to the floor "building: grotte"

## A notice for the message line, e.g. when the house is handed over.
signal notice(text: String, duration: float)
## The hero walked into the house the elder gave for the first time: it is
## theirs now, and the place every saved game starts from.
signal home_claimed
## The hero has reached the food basket on the pedestal and eats.
signal food_basket(heal: int)
## An animal eats its food from the hero's hand (see Animal and Companions).
signal animal_fed(animal: Animal)
## Lightning strikes at a spot in a thunderstorm (see Weather): the sky
## flashes and thunder rolls.
signal lightning(pos: Vector3)

const GRAVEYARD_DIR := "res://assets/graveyard/"
const VILLAGE_DIR := "res://assets/village/"
## Tiles anyone can walk on. Everything else is solid.
const WALK := ".,Pai:0123456789KOGMYZScAXQWHJUDV&@'{}-/?¤"
## Tiles of the robbers' camp: bare, trodden earth.
const CAMP := "NfC"
const VILLAGERS := "0123456789KOGMYZS"
const BLOCK_CHARS := "RhjnmuskowbE^[])<"
const BLOCK_MODELS := {
	"R": "crypt", "j": "building_blacksmith_red", "n": "building_tavern_blue",
	"m": "building_market_green", "u": "building_windmill_red",
	"k": "building_castle_blue", "o": "building_home_A_yellow",
	"w": "building_barracks_red", "b": "building_tower_A_blue",
	"[": "building_tavern_blue",
}
const BUILDING_NAMES := {
	"b": "die Bank der Krone", "s": "den Tempel", "k": "das Amt der Krone", "w": "die Abenteurergilde",
	"o": "die Post", "j": "die Schmiede", "n": "das Wirtshaus", "m": "den Laden",
	"E": "die Drachenhöhle", "[": "die Bergschenke", ")": "den Hort des Großen Alten", "<": "die Aschenzinne",
	"|": "die Ruinen von Sternhall",
}
## The mine entrances in the mountains (see "]" and Mines), west to east:
## the floor of mine n has the line "building: mine<n>".
var mines: Array[Vector3] = []
## The creepy holes in the ground, in map order (see "(").
var holes: Array[Vector3] = []
var _whisper_timer := 3.0
## From how far the hero hears a hole whisper.
const WHISPER_RANGE := 14.0
const WHISPERS := ["...komm näher...", "...tiefer...", "...hier unten...", "...wir warten...", "...hungrig..."]
## The herald calls out news this often (seconds, picked at random between the
## two bounds each time); the first call comes sooner.
const HERALD_EVERY_MIN := 160.0
const HERALD_EVERY_MAX := 240.0
const HERALD_FIRST_MIN := 50.0
const HERALD_FIRST_MAX := 75.0
const GRAVES := ["grave_A", "grave_B", "gravestone", "gravemarker_A", "gravemarker_B", "grave_A_destroyed"]
## The village props come as table-top miniatures: this blows them up to
## the hero's size.
const PROP_SCALE := 6.0
## How far from the open ground trees still grow (in tiles).
const FOREST_DEPTH := 4
## Ground pieces are this many tiles across. Each piece is lit by the
## lanterns near it only, so many lanterns can burn at once.
const GROUND_CHUNK := 12
const TREE_SHADER := preload("res://shaders/tree.gdshader")
## The temple: a chapel from the Modular Cathedral Kit (see _build_chapel).
## Pieces in the kit's own metres, with the door looking south (+z): name,
## where it stands and how far it is turned (degrees).
const CHAPEL_DIR := "res://assets/chapel/"
const CHAPEL_PARTS := [
	["wall_01", Vector3(-12, 0, 11), 0.0], ["doorway_01", Vector3(-4, 0, 11), 0.0], ["wall_01", Vector3(4, 0, 11), 0.0],
	["door_01", Vector3(-2, 0, 11.4), 0.0],
	["wall_01", Vector3(12, 0, -11), 180.0], ["wall_rose_window_01", Vector3(4, 0, -11), 180.0], ["wall_01", Vector3(-4, 0, -11), 180.0],
	["wall_window_01", Vector3(11, 0, 12), 90.0], ["wall_window_01", Vector3(11, 0, 4), 90.0], ["wall_window_01", Vector3(11, 0, -4), 90.0],
	["wall_window_01", Vector3(-11, 0, -12), -90.0], ["wall_window_01", Vector3(-11, 0, -4), -90.0], ["wall_window_01", Vector3(-11, 0, 4), -90.0],
	["rooftop_01", Vector3(0, 16, 8), 0.0], ["rooftop_01", Vector3(0, 16, 0), 0.0], ["rooftop_01", Vector3(0, 16, -8), 0.0],
	["spire_01", Vector3(0, 16, 8), 0.0],
]
## Half the nave's width (x) and length (z), the height of its walls and of
## the gables under the roof, all in kit metres.
const CHAPEL_HALF := Vector2(12, 12)
const CHAPEL_EAVES := 16.0
const CHAPEL_GABLE_HEIGHT := 13.0
## The ground the chapel covers, steps included (kit metres), and the middle
## of it along z.
const CHAPEL_FOOT := Vector2(24, 30)
const CHAPEL_FOOT_MID := 3.0
## Where the bricks sit on the kit's trim sheet (v from top to bottom of four
## rows of bricks).
const GABLE_BRICK_V := Vector2(0.6, 0.92)
## The candlelight behind the temple's stained glass at night: still a little
## dimmer than the houses' windows, but bright enough that the panes shine in
## their own saturated colours without burning out to white.
const CHAPEL_GLASS_LIGHT := Color(0.78, 0.68, 0.54)

const HOUSE_ROOF_HEIGHT := 3.6
const WALL_HEIGHT := 4.0
## The elder calls the hero over from this far (metres).
const GREET_RANGE := 11.0
## Bandits: how likely each piece of gear is on them (what they drop when
## they fall goes by Loot's odds, see Level.drop_kill_loot). The chief has
## more of everything.
const BANDIT_GEAR_CHANCE := 0.45
const CHIEF_GEAR_CHANCE := 0.6
## Seconds after a bandit falls until another takes its place, and how far
## away the hero must be for that to happen out of sight.
const BANDIT_RESPAWN := 150.0
const RESPAWN_FAR := 40.0
## The hero is warned about the pass (or the wolf hollow) when a bandit's
## (or a beast's) spot is this close (metres).
const WILD_WARNING_RANGE := 16.0
## Remembered in the saved game once the bandit chief has fallen: he does
## not come back. His spot stays empty from then on.
const CHIEF_DEFEATED := "boss:bandit_chief"
## Gold in the chief's purse, and how far from his post his cutthroats
## come running when he calls them (tiles).
const CHIEF_GOLD := 15
const CALL_FROM_TILES := Vector2i(5, 9)
## The pedestal with the food basket: how tall it is (metres), how far from
## the basket the hero can reach it, how high their feet must stand for that
## (on two stacked crates), the lives the food gives back, and the seconds
## until the basket is full again.
const PEDESTAL_HEIGHT := 3.2
const BASKET_REACH := 2.4
const BASKET_FEET := Crate.SIZE * 2.0 - 0.2
const BASKET_HEAL := 3
const BASKET_REFILL := 180.0
## Where the pedestal's crates lie, from the middle of its tile.
const PEDESTAL_CRATES: Array[Vector3] = [Vector3(-2.6, 0, 1.0), Vector3(2.5, 0, 1.6), Vector3(-1.4, 0, 3.0)]

var villagers: Array = []
## Every living tree of the woods, for the birds and squirrels in them (see
## WoodsLife): where it stands and how tall it is.
var _wood_trees: Array = []
## The birds and squirrels of the woods (see WoodsLife).
var woods: WoodsLife
## The glowworm swarms that roam the night (see GlowwormSwarms).
var glowworms: GlowwormSwarms
## The peaceful animals of the woods (see Animal).
var animals: Array[Animal] = []
## The village's geese, goats and dogs (see VillageFarm and FarmAnimal).
var farm_animals: Array[FarmAnimal] = []
## The herald's call to arms against slimes in the village (see VillageAlarm).
var village_alarm := VillageAlarm.new()
## The wall round the village and its gates, mended by the stonemason (see VillageWall).
var village_wall := VillageWall.new()
## Where the alarm horn stands by the west gate (see WarHorn), INF when there is none.
var war_horn_at := Vector3.INF
## The kinds of animal the hero has a companion of already: no second one
## of them can be won over (set by the game, see Companions).
var owned_companions: Array = []
var _animal_spots: Array = []
## Has the elder handed the house over yet? Saved games wake up at home.
var house_given := false
## The villagers the hero has talked to, by role letter (see Villager.ROLES):
## their names stay over their heads. Shared with Game.met, so it is kept in
## the saved game.
var met := {}
## Where the hero wakes up in the house: next to the bed.
var home_spot := Vector3.ZERO
## Fronts of the village buildings: where villagers walk to.
var spots := {"houses": [], "square": [], "well": [], "market": []}
## The village houses' chimneys: each house's door spot (as in spots.houses)
## and the plume of smoke over its roof (see ChimneySmoke).
var chimneys: Array[Dictionary] = []
## The narrow town houses of Weavers' Lane, by number - 1 (see _build_terrace).
var town_houses: Array[Node3D] = []
## The windmills (see "u" and Windmill), whose sails turn in the wind.
var windmills: Array[Windmill] = []

var _plants := {}
var _house_rect := Rect2i()
var _door_cell := Vector2i(-1, -1)
var _roof: Node3D
## The south walls of the house: full height, but see-through in front of
## the hero while the hero is inside (see WallFade).
var _house_fade := WallFade.new()
var _inside := false
var _entered_once := false
var _marker: Node3D
## The hero's town house on Weavers' Lane (see Homes), once the elder has
## given it.
var own_house := 0
var _elder: Node3D
var _aabbs := {}
## Buildings with floors of their own: building letter -> level index.
var interiors := {}
## Where each building's door is, by building letter.
var doors := {}
## The swinging plank doors of the village houses (see HouseDoor).
var house_doors: Array[HouseDoor] = []
## The treasure maps' state (see TreasureMaps): the game hands in its own,
## so a map read while the hero is out here shows at once.
var treasure := {}
## The tiles of the treasure spots, by map id, and what is built there
## (see TreasureMaps.build).
var treasure_cells := {}
var treasure_parts := {}
var _herald: Node3D
var _herald_timer := randf_range(HERALD_FIRST_MIN, HERALD_FIRST_MAX)
## The bandits' spots: cell, kind, the bandit standing there (or null while
## it is gone), seconds until the next one arrives, and how many came so far.
var _wild: Array = []
var _wild_warned := false
var _beasts_warned := false
var _pass_warned := false
## The bandit chief while he stands, his health bar, and the cutthroats he
## called in to help (they do not come back once they fall).
var chief: BanditChief
var boss_bar: BossBar
var _called: Array[Enemy] = []
## The food basket: where it stands, its food, whether it is full, the
## seconds until it fills again, and whether the hero was told about it.
var _basket := {}
## The "!" or "?" over the bounty board (see Bounties.mark).
var _board_mark: Label3D

## Lanterns: how strongly they shine by day and at night, the glowing
## candle in each, and how far their light shows the hero to enemies.
const LAMP_DAY := 0.5
const LAMP_NIGHT := 3.2
const LAMP_REACH := 8.0
const CANDLE_GLOW := 5.0
var _lamps: Array[OmniLight3D] = []
## The bandits' campfires light up their camp at night too.
var _fires: Array[Vector3] = []
var _candles: Array[MeshInstance3D] = []
var _candle_mat: StandardMaterial3D
## The glass of the street lamps' lanterns, glowing at night.
var _pane_mat: StandardMaterial3D
## Where the window panes of the village houses sit in the kit's palette
## texture: one small patch colours every pane. A mask over that patch lets
## the windows glow without touching walls or roofs.
const WINDOW_UV := Vector2(0.816, 0.292)
const WINDOW_LIGHT := Color(1.0, 0.7, 0.36)
const WINDOW_GLOW := 2.6
## The kit's material -> its copy with glowing windows.
var _window_mats := {}
var _window_mask: ImageTexture
## The old stone look (see AgedStone): the leaves of all the ivy, the nests
## on the roofs, the doors (and the way they look out) that get a paved way,
## and the ground's mask, which those ways are painted into.
var _ivy := {"xforms": [], "colours": []}
var nests: Array[Vector3] = []
var birds: VillageBirds
## The dragon that now and then flies over, seen only as its shadow.
var flyover: DragonFlyover
var _entrances: Array = []
var _ground_img: Image
var _ground_tex: ImageTexture
var _village_near := {}
## What the dressing found for each building (see _dress_building), kept
## for the session.
static var _dressed := {}
## Nests at most, and how likely one of Weavers' Lane's town houses gets ivy
## and a nest (the other buildings all have ivy, and most of them a nest).
const MAX_NESTS := 10
const LANE_NEST := 0.15
## Ivy patches on each town house of Weavers' Lane (narrow, many of them).
const LANE_PATCHES := 3
## Dirt paths this close to a village building (tiles) are cobbled like the
## square, and shrubs grow on the grass beside the buildings.
const VILLAGE_REACH := 6
const VILLAGE_BLOCKS := "hjnmuskowb^["
const BUSH_CHANCE := 0.8
const BUSH_OPEN := 0.3
## The graveyard (see _age_graveyard): ivy patches on the crypt, how much of
## the fence has ivy on its low wall, how many graves have a grave light (a
## small lantern with a candle, lit at night), and where the light stands.
const CRYPT_IVY := 6
## A building with no paving of the square (":") this many tiles round its
## block stands on its own, out of the village's busy middle: old ivy grows
## all over it, up to and on to its roof (see AgedStone.grow_ivy).
const SQUARE_GAP := 2
const FENCE_IVY := 0.55
## The adventurers' guild, the castle and the temple are smothered in old ivy: this many patches, every
## wall and up on to its roof, even though it stands in the square.
const GUILD_IVY := 28
## The guild hall's windows get this many times the usual clear room, so most of the leaves stay off them.
const GUILD_WINDOW_ROOM := 2.6
## Patches on the other stone buildings (tavern, smithy, market, tower, ...).
const STONE_IVY := 14
## The windmill (stone foot, wooden body) wears as many leaves per square metre as the other stone buildings.
const MILL_IVY := 30
## The bank's tower wears branching ivy on every side (like the guild hall), clear of its door and windows.
const BANK_IVY := 20
const BANK_WINDOW_ROOM := 2.6
## Vines across the bank tower's roof, branching like the temple's.
const BANK_ROOF_VINES := 5
const CASTLE_IVY := 48
## The castle's stones stand this far (metres) proud of their wall planes: its leaves are held out by that much.
const CASTLE_PROUD := 0.3
## The castle's towers stand on a ledge this high (metres): ivy roots there too and climbs the towers.
const CASTLE_TOWER_FOOT := 5.2
## The temple too, but its doorway is kept bare: no ivy roots within a few
## metres of it, to the sides and back along the steps.
const TEMPLE_IVY := 16
## Branching vines across the temple's roof (a patchwork, the tiles still show between).
const TEMPLE_ROOF_VINES := 9
const GRAVE_LIGHTS := 0.35
const GRAVE_LIGHT_AT := Vector3(1.25, 0, -0.35)
## Where the grave light's panes sit on the Halloween kit's palette (UV).
const GRAVE_PANES := Rect2(0.25, 0.75, 0.125, 0.25)
var _grave_glow: ImageTexture
## The paved ways to the doors: how wide (in quarter tiles, the ground
## mask's pixels) and how far they look for the square or a path (tiles).
const WAY_WIDTH := 1.4
## The graveyard's path is wider: it covers the whole dirt path.
const GRAVE_WAY_WIDTH := 2.2
## Wide entrances (the caves and the mines) get a paved forecourt as wide
## as the entrance, reaching out to the path that arrives there (see
## _pave_forecourts): how far it looks for that path (tiles), how far the
## arriving path is paved on from it (tiles), and how much narrower than
## the entrance's block the forecourt is (metres).
const FORECOURT_REACH := 3
const FORECOURT_PATH := 1
const FORECOURT_MARGIN := 1.0
## The wide entrances, each {"block", "front"}, for _pave_forecourts.
var _forecourts: Array[Dictionary] = []
## The grey of the boulders fallen from the lair's mountain.
const LAIR_BOULDER := Color(0.5, 0.48, 0.45)
const WAY_SEARCH := 14
## The hour the world was last lit for, and whether it is night.
var hour := -1.0
var night := false
## The dead of the graveyard: they rise from these graves at nightfall
## (kinds in turn), come back a while after they fall as long as it is
## night, and sink back into the earth at dawn. They never rise within
## sight of the hero.
const NIGHT_DEAD := 5
const NIGHT_DEAD_KINDS := ["krieger", "schuetze", "wicht", "krieger", "schuetze"]
const NIGHT_DEAD_RESPAWN := 90.0
const NIGHT_DEAD_FAR := 14.0
## At night fallen bandits are replaced this much sooner.
const NIGHT_RESPAWN_FACTOR := 0.5
var _graves: Array[Vector2i] = []
var _risen: Array = []
## The day the world's clock is on (see Game.day): with the hour it tells
## which night it is, and whether the wandering merchant is in the village.
var day := 0
## Zarek, the wandering merchant, while he is in the village (else null),
## his pitch, and his cart with its lantern and its solid shapes.
var wanderer: Villager
var _wanderer_cell := Vector2i(-1, -1)
var _cart: Node3D
var _cart_shapes: Array[CollisionShape3D] = []
## Where his cart stands, from his pitch: behind him, as he faces the hero.
const CART_OFFSET := Vector2i(0, -1)
## The weather the world was last set to (see Weather and set_weather).
var weather := ""
## What comes out in which weather (one or more groups): the kind, how many
## at most, the map letter they gather around; then how long until a fallen
## one is replaced, and how far from the hero they appear (never within
## sight). Slimes love bad weather: they crawl out of the pond in the rain
## and the storm, and in the fog too (see SlimeGrowth).
const WEATHER_FOES := {
	Weather.RAIN: [{"kind": "schleim", "count": 12, "near": "~"}],
	Weather.FOG: [{"kind": "fog_wraith", "count": 6, "near": "d"}, {"kind": "schleim", "count": 8, "near": "~"}],
	Weather.STORM: [{"kind": "fledermaus", "count": 5, "near": "r"}, {"kind": "schleim", "count": 8, "near": "~"}],
}
const WEATHER_RESPAWN := 80.0
## Slimes stay when the weather turns; at most this many crawl about.
const SLIMES_AT_MOST := 24
const WEATHER_FAR := 14.0
## In a thunderstorm lightning strikes every so often (seconds, picked at
## random between the two bounds), and a strike on a rock leaves thunder
## ore beside it this often, as long as fewer than MAX_ORE lumps lie about.
const STRIKE_EVERY_MIN := 6.0
const STRIKE_EVERY_MAX := 15.0
const ORE_CHANCE := 0.6
const MAX_ORE := 3
const ORE := "donnererz"
## The hero is told where the ore came from when a strike is this close.
const ORE_NOTICE_RANGE := 36.0
## The weather's creatures on their spots: cell, kind, the creature (or
## null while it is gone) and the seconds until the next one comes.
var _weather_foes: Array = []
## The rain puddles on the open ground (see Puddles).
var puddles: Puddles
## The bounds of the square and the graveyard fence, found once (see ground_at).
var _ground_rects := {}
var _strike_timer := 0.0
var _rock_cells: Array[Vector2i] = []
## Where the mountain over the dragon's lair stands (the foot of the arch),
## so no forest grows out of it; INF while there is none.
var _lair_mountain_at := Vector3.INF
## The moon (see Moon). At full moon a wolf pack hunts through the hollow:
## a leader and the rest of the pack, set out around the hollow's pond (map
## letter PACK_NEAR), and the moon flowers open on the pond's bank. At new
## moon a horror crawls out of the hole nearest the village and lurks this
## far along the way from the hole to the village square (0 at the hole,
## 1 on the square), but at least HORROR_OUT tiles out of its hole. The
## holes breathe that night, and whisper from further away.
const PACK_SIZE := 4
const PACK_NEAR := ";"
const FLOWERS := 3
const FLOWER := "mondblume"
const HORROR_WAY := 0.4
const HORROR_OUT := 6
## Nobody comes out of the dark within this distance of the hero.
const MOON_FAR := 22.0
const BREATH_WHISPER := 2.4
## The night the moon's events were last set up for (see Game.day), -1 for
## none; the pack's spots, the open flowers (pickups), the horror's spot (or
## empty) and the breath rising out of each hole.
var moon_night := -1
var _pack: Array = []
var _moon_horror := {}
var _breaths: Array[CPUParticles3D] = []


func build() -> void:
	_rng.seed = hash(level_name)
	add_child(_walls_body)
	_build_ground()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			_build_outdoor_cell(c, cell_char(c))
	_build_blocks()
	if Corral.present(self):
		Corral.build_props(self)
	_pave_entrances()
	_plant_bushes()
	# No leaf covers any door, whichever building grew it.
	AgedStone.clear_doors(_ivy, _entrances)
	if not _ivy.xforms.is_empty():
		add_child(AgedStone.ivy_node(_ivy))
	if not nests.is_empty():
		var pecking: Array[Vector3] = []
		pecking.assign(spots.square)
		var market: Array[Vector3] = []
		market.assign(spots.market)
		birds = VillageBirds.new(self, nests, pecking, market, hash(level_name + "voegel"))
		add_child(birds)
	Mountains.build(self, hash(level_name + "berge"))
	_build_forest()
	_build_house()
	_build_wall_collision()
	_build_rock_collision()
	_setup_astar()
	if birds:
		# Not where the fountain, a bench or a stall stands.
		var free: Array[Vector3] = []
		free.assign(birds.market.filter(func(m: Vector3): return is_open(world_to_cell(m))))
		birds.market = free
	_flush_plants()
	_build_woods_life()
	# Leaves, twigs, rubble and little crawling creatures on the ground.
	add_child(SurfaceLife.new(self))
	puddles = Puddles.new(self, hash(level_name + "pfuetzen"))
	add_child(puddles)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	_walls_body.add_child(floor_shape)
	_spawn_villagers()
	_build_war_horn()
	_spawn_wild()
	_spawn_animals()
	farm_animals = VillageFarm.spawn(self)
	# The old dragon's little helpers, who gather the loot at night.
	if doors.has("E"):
		add_child(DragonHelpers.new(self, doors.E))
	# Now and then the dragon's shadow sweeps over the land (see DragonFlyover).
	flyover = DragonFlyover.new(self, _lair_mountain_at)
	add_child(flyover)
	for y in height:
		for x in width:
			if cell_char(Vector2i(x, y)) == "r":
				_rock_cells.append(Vector2i(x, y))


# --- Ground -------------------------------------------------------------------

## One mask pixel per tile: red is path, green graveyard soil, both the
## paved square, blue water, alpha open ground (the forest floor is darker).
func _build_ground() -> void:
	var mask := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var stones := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var fence := _bounds_of("z")
	var square := _bounds_of(":")
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			var path := 1.0 if ",aP\\".contains(ch) else 0.0
			var soil := 1.0 if (fence.has_point(c) and not ",aP\\".contains(ch)) or ch == "y" or CAMP.contains(ch) else 0.0
			# Paving stones: path and soil together mean the square.
			if square.has_point(c) and not BLOCK_CHARS.contains(ch):
				path = 1.0
				soil = 1.0
			var wet := 1.0 if "~;".contains(ch) else 0.0
			var open := 0.0 if ch == "#" else 1.0
			mask.set_pixel(x, y, Color(path, soil, wet, open))
			# Scree on the mountain ground, and at the foot of the rock.
			stones.set_pixel(x, y, Color(1.0 if "'=]{}-/".contains(ch) else 0.0, 0, 0, 1))
	# A smoother mask gives softer edges between the tiles.
	mask.resize(width * 4, height * 4, Image.INTERPOLATE_BILINEAR)
	stones.resize(width * 4, height * 4, Image.INTERPOLATE_BILINEAR)
	_ground_img = mask
	_ground_tex = ImageTexture.create_from_image(mask)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/meadow.gdshader")
	mat.set_shader_parameter("ground_mask", _ground_tex)
	mat.set_shader_parameter("stone_mask", ImageTexture.create_from_image(stones))
	mat.set_shader_parameter("grid_size", Vector2(width, height))
	mat.set_shader_parameter("tile", TILE)
	# The graveyard's paving is older than the village's (see _pave_graveyard).
	if fence.size != Vector2i.ZERO:
		mat.set_shader_parameter("old_paving", Vector4((fence.position.x - 0.5) * TILE, (fence.position.y - 0.5) * TILE,
				(fence.end.x - 0.5) * TILE, (fence.end.y - 0.5) * TILE))
	var margin := 10
	var size := GROUND_CHUNK * TILE
	for cy in range(-margin, height + margin, GROUND_CHUNK):
		for cx in range(-margin, width + margin, GROUND_CHUNK):
			var plane := PlaneMesh.new()
			plane.size = Vector2(size, size)
			var piece := MeshInstance3D.new()
			piece.mesh = plane
			piece.material_override = mat
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.position = Vector3((cx - 0.5) * TILE + size * 0.5, 0, (cy - 0.5) * TILE + size * 0.5)
			add_child(piece)


## The smallest rectangle around all tiles of one kind.
func _bounds_of(ch: String) -> Rect2i:
	var r := Rect2i()
	var first := true
	for y in height:
		for x in width:
			if cell_char(Vector2i(x, y)) == ch:
				if first:
					r = Rect2i(x, y, 1, 1)
					first = false
				else:
					r = r.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	return r


# --- Models -------------------------------------------------------------------

func _model_path(name: String) -> String:
	if name.begins_with("lair/"):
		return Level.LAIR_DIR + name.substr(5) + ".fbx"
	var path := GRAVEYARD_DIR + name + ".gltf"
	return path if ResourceLoader.exists(path) else VILLAGE_DIR + name + ".gltf"


func _put(name: String, pos: Vector3, rot := 0.0, s := 1.0, parent: Node = self) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load(_model_path(name))
	var node: Node3D = _scenes[name].instantiate()
	node.position = pos
	node.rotation.y = rot
	node.scale = Vector3.ONE * s
	if name.begins_with("tree") and not WeatheredProps.MODELS.has(name):
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = _tree_material(mi.get_active_material(0), not name.ends_with("_cut"))
	# The old props (barrels, crates, lumber, stone heaps, pumpkins, tents)
	# weathered to match the aged stone (see WeatheredProps).
	WeatheredProps.weather_model(node, name)
	# Flags flutter in the wind (see FlagWind).
	FlagWind.attach(node, name, self)
	parent.add_child(node)
	return node


## The kit's trees are flat, even colours with a glossy shine: plastic. This
## gives their leaves clusters, speckle and a sway, and their bark a grain
## (see tree.gdshader), keeping the kit's palette texture. One material per
## palette, cached.
func _tree_material(mat: Material, wind := true) -> Material:
	var tex: Texture2D = (mat as StandardMaterial3D).albedo_texture if mat is StandardMaterial3D else null
	var key := "mat_tree_%d_%d" % [tex.get_instance_id() if tex else 0, int(wind)]
	if not _scenes.has(key):
		var bark := ShaderMaterial.new()
		bark.shader = TREE_SHADER
		bark.set_shader_parameter("albedo_tex", tex)
		bark.set_shader_parameter("wind", 1.0 if wind else 0.0)
		_scenes[key] = bark
	return _scenes[key]


## Many copies of one model (trees) are drawn together in one go, one batch
## per GROUND_CHUNK patch of the map. The renderer lights each batch with at
## most a handful of lights (rendering/limits/opengl/max_lights_per_object),
## so one batch for every tree of a kind on the whole map left nearly all of
## them blind to the lanterns, fires and torches near them.
func _plant(name: String, pos: Vector3, rot: float, s: float) -> void:
	var patch := Vector2i(floori(pos.x / (GROUND_CHUNK * TILE)), floori(pos.z / (GROUND_CHUNK * TILE)))
	var key := [name, patch]
	if not _plants.has(key):
		_plants[key] = []
	_plants[key].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), pos))


func _flush_plants() -> void:
	var parts := {}
	for key in _plants:
		var name: String = key[0]
		if not parts.has(name):
			var scene: Node3D = load(_model_path(name)).instantiate()
			parts[name] = _meshes_of(scene, Transform3D())
			scene.free()
		for part in parts[name]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = _plants[key].size()
			for i in mm.instance_count:
				mm.set_instance_transform(i, _plants[key][i] * part[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if name.begins_with("tree"):
				mmi.material_override = _tree_material((part[0] as Mesh).surface_get_material(0))
			add_child(mmi)


## Every mesh in a model, with where it sits inside the model.
func _meshes_of(node: Node, xform: Transform3D) -> Array:
	var found := []
	for child in node.get_children():
		if not child is Node3D:
			continue
		var t: Transform3D = xform * child.transform
		if child is MeshInstance3D and child.mesh:
			found.append([child.mesh, t])
		found.append_array(_meshes_of(child, t))
	return found


## The size of a model, measured once.
func _aabb_of(name: String) -> AABB:
	if not _aabbs.has(name):
		var scene: Node3D = load(_model_path(name)).instantiate()
		var box := AABB()
		var first := true
		for part in _meshes_of(scene, Transform3D()):
			var b: AABB = part[1] * (part[0] as Mesh).get_aabb()
			box = b if first else box.merge(b)
			first = false
		scene.free()
		_aabbs[name] = box
	return _aabbs[name]


## Puts down a tidy arrangement of village goods on the tile at `pos` (see
## VillageClutter) and blocks the ground it covers, `height` high.
func _put_layout(pos: Vector3, layout: Array, height: float) -> void:
	for item: Array in layout:
		_put(item[0], pos + Vector3(item[1], 0, item[2]), item[3], item[4])
	var box := VillageClutter.bounds(layout)
	var middle := box.get_center()
	_add_solid(pos + Vector3(middle.x, 0, middle.y), Vector3(box.size.x, height, box.size.y))


func _jitter(amount: float) -> Vector3:
	return Vector3(_rng.randf_range(-amount, amount), 0, _rng.randf_range(-amount, amount))


# --- Tiles --------------------------------------------------------------------

func _build_outdoor_cell(c: Vector2i, ch: String) -> void:
	var pos := cell_to_world(c)
	match ch:
		"P":
			start_cell = c
		"@":
			_wanderer_cell = c
		"_":
			village_wall.add(self, c, false)
		"\\":
			village_wall.add(self, c, true)
		"g":
			var grave: String = GRAVES[_rng.randi() % GRAVES.size()]
			var stone := _put(grave, pos + Vector3(0, 0, -0.6) + _jitter(0.3), _rng.randf_range(-0.15, 0.15))
			_age_graveyard(stone, true, absi(hash(c)) % AgedStone.GRAVE_TINTS.size())
			_graves.append(c)
			_add_solid(pos + Vector3(0, 0, -0.6), Vector3(2.0, 1.6, 1.0))
			_grave_light(c, pos)
		"d":
			var tree: String = ["tree_dead_large", "tree_dead_medium", "tree_dead_small"][_rng.randi() % 3]
			_put(tree, pos + _jitter(0.5), _rng.randf() * TAU, _rng.randf_range(1.1, 1.4))
			_add_solid(pos, Vector3(1.4, 4, 1.4))
		"p":
			_put_layout(pos, VillageClutter.PUMPKINS, 1.2)
		"l":
			_build_lantern(pos)
		"r":
			var rock: String = ["rock_single_A", "rock_single_C", "rock_single_E"][_rng.randi() % 3]
			# Blocked where the boulder is drawn: some reach well past the
			# middle of their tile, and the hero must not squeeze in between.
			_add_turned_solid(_put(rock, pos + _jitter(0.4), _rng.randf() * TAU, _rng.randf_range(7.0, 9.0)), 1.6)
		"T":
			_build_tree(pos, true)
			_add_solid(pos, Vector3(1.8, 4, 1.8))
		"t":
			_put_layout(pos, VillageClutter.STUMP, 1.2)
		"e":
			_put_layout(pos, VillageClutter.heap_for(level_name, c), 1.5)
		"q":
			_put("building_well_yellow", pos, 0.0, 5.0)
			_add_solid(pos, Vector3(3.2, 2, 3.2))
			spots.well.append(pos + Vector3(0, 0, 2.6))
		"z":
			_build_fence(c, false)
		"a":
			_build_fence(c, true)
		"§":
			Corral.build_fence(self, c)
		"¤":
			Corral.build_gate(self, c)
		"(":
			_build_hole(c)
		"|":
			SternGate.build_gate(self, c)
		"`":
			SternGate.build_outlet(self, c)
		"?", ">":
			TreasureMaps.place(self, c, ch)
		"~", ";":
			_add_solid(pos, Vector3(TILE, 1, TILE))
			fishing_waters.append({"water": "teich" if ch == "~" else "senke", "pos": pos,
					"reach": TILE * 0.5, "round": false, "surface": 0.04})
		"y":
			# Rows of pumpkins on dark soil, ready for the harvest.
			for row in 2:
				for col in 2:
					var kind: String = ["pumpkin_orange", "pumpkin_orange", "pumpkin_yellow_small"][_rng.randi() % 3]
					_put(kind, pos + Vector3(-1.0 + col * 2.0, 0, -1.0 + row * 2.0) + _jitter(0.3), _rng.randf() * TAU, _rng.randf_range(0.9, 1.3))
			_add_solid(pos, Vector3(TILE * 0.9, 1, TILE * 0.9))
		":":
			spots.square.append(pos)
			spots.market.append(pos)
		"F":
			_build_fountain(c)
			# A little ivy up the basin's outside, a bit of it over the rim.
			var ivy_rng := RandomNumberGenerator.new()
			ivy_rng.seed = hash("%s|brunnen|%s" % [level_name, c])
			AgedStone.grow_basin_ivy(pos, 1.55, 1.0, ivy_rng, _ivy, 3)
			spots.well.append(pos + Vector3(0, 0, 2.6))
		"x":
			_build_bench(c)
		"v":
			_build_pedestal(c)
		"!":
			_build_bounty_board(c)
		"N":
			_build_tent(pos)
		"f":
			_build_campfire(pos)
		"C":
			_build_chest(c)
			# The robbers' hoard: richer than a chest in the dungeon.
			var loot_rng := RandomNumberGenerator.new()
			loot_rng.seed = hash("%s:hoard:%d:%d" % [level_name, c.x, c.y])
			clear_loot(interactables[-1])
			interactables[-1].loot = {"gold": 20, "item": loot_item(loot_rng, Level.tier_rank("ungewoehnlich"), HeroLevel.AREAS.pass.max)}
		_:
			if CraftingSquare.LETTERS.contains(ch):
				CraftingSquare.build(self, c, ch)
			elif Enemy.WILD_LETTERS.has(ch):
				_wild.append({"cell": c, "kind": Enemy.WILD_LETTERS[ch], "enemy": null, "timer": 0.0, "wave": 0})
			elif Animal.LETTERS.has(ch):
				_animal_spots.append({"cell": c, "kind": Animal.LETTERS[ch]})


## A tall pedestal of old, hewn stone (see VillageProps.build_pedestal) with
## a basket of bread, cheese and apples on top, and the crates to climb up to
## it lying close by.
func _build_pedestal(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	VillageProps.build_pedestal(self, pos, PEDESTAL_HEIGHT)
	_add_solid(pos, Vector3(1.7, PEDESTAL_HEIGHT, 1.7))
	# The basket: an open crate, filled with food that glints.
	var box := _aabb_of("crate_open")
	var s := 1.0 / maxf(0.01, maxf(box.size.x, box.size.z))
	var top := Vector3(pos.x, PEDESTAL_HEIGHT, pos.z)
	_put("crate_open", top - Vector3(box.get_center().x, box.position.y, box.get_center().z) * s, 0.0, s)
	var food := Node3D.new()
	food.position = top + Vector3(0, box.size.y * s * 0.8, 0)
	add_child(food)
	_add_food(food)
	food.add_child(Effects.make_sparkles(Color(1.0, 0.85, 0.45)))
	_basket = {"pos": top, "food": food, "full": true, "timer": 0.0, "hinted": false}
	for offset in PEDESTAL_CRATES:
		add_crate(pos + offset)


## The bounty board: two posts with a little roof over a plank wall, with
## notices pinned to it, facing south. Run into it to read the hunts.
func _build_bounty_board(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var wood := WeatheredProps.colour_material(Color(0.42, 0.28, 0.17))
	var dark := WeatheredProps.colour_material(Color(0.3, 0.19, 0.12))
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.93, 0.88, 0.74)
	paper.roughness = 1.0
	var seal := StandardMaterial3D.new()
	seal.albedo_color = Color(0.7, 0.12, 0.1)
	for side in [-1.0, 1.0]:
		_add_mesh_box(pos + Vector3(side * 1.05, 1.35, 0), Vector3(0.18, 2.7, 0.18), dark)
	_add_mesh_box(pos + Vector3(0, 1.65, 0), Vector3(2.1, 1.3, 0.1), wood)
	_add_mesh_box(pos + Vector3(0, 2.36, 0), Vector3(2.3, 0.12, 0.2), dark)
	_add_mesh_box(pos + Vector3(0, 0.96, 0), Vector3(2.3, 0.1, 0.2), dark)
	# The little roof keeps the rain off the notices.
	for side in [-1.0, 1.0]:
		var roof := MeshInstance3D.new()
		var plank := BoxMesh.new()
		plank.size = Vector3(2.6, 0.08, 0.5)
		roof.mesh = plank
		roof.material_override = dark
		roof.position = pos + Vector3(0, 2.83, side * 0.2)
		roof.rotation.x = side * 0.6
		add_child(roof)
	# The notices, a little crooked, each with a red seal.
	var notes := [[Vector3(-0.6, 1.75, 0.07), 0.08], [Vector3(0.05, 1.6, 0.07), -0.05], [Vector3(0.65, 1.78, 0.07), 0.12]]
	for n in notes:
		var sheet := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 0.66, 0.02)
		sheet.mesh = box
		sheet.material_override = paper
		sheet.position = pos + n[0]
		sheet.rotation.z = n[1]
		add_child(sheet)
		_add_mesh_box(pos + n[0] + Vector3(0, 0.24, 0.02), Vector3(0.08, 0.08, 0.02), seal)
	_add_solid(pos, Vector3(2.4, 2.6, 1.0))
	stations.append({"kind": "aushang", "cell": c, "pos": pos, "used": false})
	_board_mark = Label3D.new()
	_board_mark.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	_board_mark.font_size = 140
	_board_mark.pixel_size = 0.011
	_board_mark.outline_size = 26
	_board_mark.outline_modulate = Color(0.05, 0.03, 0.06, 0.9)
	_board_mark.modulate = Villager.MARK_COLOR
	_board_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_board_mark.no_depth_test = true
	_board_mark.render_priority = 18
	_board_mark.outline_render_priority = 17
	_board_mark.position = pos + Vector3(0, 3.7, 0)
	_board_mark.visible = false
	add_child(_board_mark)
	# The mark bobs gently, like the villagers' marks.
	var bob := _board_mark.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_board_mark, "position:y", pos.y + 3.8, 1.0)
	bob.tween_property(_board_mark, "position:y", pos.y + 3.6, 1.0)


## Shows "!" or "?" over the bounty board, or nothing (see Bounties.mark).
func set_board_mark(text: String) -> void:
	if _board_mark == null:
		return
	_board_mark.text = text
	_board_mark.visible = text != ""


## The mark over the bounty board right now, "" when none shows.
func board_mark() -> String:
	return _board_mark.text if _board_mark and _board_mark.visible else ""


## A loaf, a wedge of cheese and a few apples, heaped in the basket: fresh,
## but no longer shining like wax (see WeatheredProps.FRESH).
func _add_food(parent: Node3D) -> void:
	var loaf := MeshInstance3D.new()
	var loaf_mesh := CapsuleMesh.new()
	loaf_mesh.radius = 0.16
	loaf_mesh.height = 0.6
	loaf_mesh.radial_segments = 12
	loaf_mesh.rings = 4
	loaf.mesh = loaf_mesh
	loaf.material_override = WeatheredProps.colour_material(Color(0.7, 0.44, 0.2), WeatheredProps.FRESH)
	loaf.rotation = Vector3(0, 0.5, PI * 0.5)
	loaf.position = Vector3(-0.1, 0.05, 0.05)
	parent.add_child(loaf)
	var cheese := MeshInstance3D.new()
	var wedge := CylinderMesh.new()
	wedge.top_radius = 0.2
	wedge.bottom_radius = 0.2
	wedge.height = 0.14
	wedge.radial_segments = 3
	cheese.mesh = wedge
	cheese.material_override = WeatheredProps.colour_material(Color(0.92, 0.74, 0.32), WeatheredProps.FRESH)
	cheese.position = Vector3(0.2, 0.05, -0.15)
	parent.add_child(cheese)
	var ball := SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.2
	ball.radial_segments = 10
	ball.rings = 6
	var apple_mat := WeatheredProps.colour_material(Color(0.72, 0.12, 0.08), WeatheredProps.FRESH)
	for spot in [Vector3(0.22, 0.08, 0.2), Vector3(0.05, 0.1, -0.25), Vector3(-0.28, 0.06, -0.18)]:
		var apple := MeshInstance3D.new()
		apple.mesh = ball
		apple.material_override = apple_mat
		apple.position = spot
		parent.add_child(apple)


func _add_mesh_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


## The hero reaches the basket standing high enough beside it (on two
## stacked crates, or on the pedestal itself) and eats; it fills again
## after a while. Coming close on the ground tells them how to get up.
func _check_basket(delta: float) -> void:
	if _basket.is_empty() or not player is CharacterBody3D:
		return
	var food: Node3D = _basket.food
	if not _basket.full:
		_basket.timer -= delta
		if _basket.timer <= 0.0:
			_basket.full = true
			food.visible = true
		return
	var d := _flat_distance(player.global_position, _basket.pos)
	var hero := player as CharacterBody3D
	var climbing: bool = hero.has_method("is_climbing") and hero.is_climbing()
	if d <= BASKET_REACH and not climbing and hero.is_on_floor() and hero.global_position.y >= BASKET_FEET:
		_basket.full = false
		_basket.timer = BASKET_REFILL
		food.visible = false
		food_basket.emit(BASKET_HEAL)
	elif d <= 6.0 and not _basket.hinted and hero.global_position.y < 0.5:
		_basket.hinted = true
		notice.emit(Lang.t("Ganz oben auf dem Sockel steht ein Korb voller Essen. Staple zwei Kisten daneben, um ihn zu erreichen (E: Kiste aufheben, Q: abstellen)."), 5.0)


## A bandit's tent, its opening turned to the south, the camp's size.
func _build_tent(pos: Vector3) -> void:
	var box := _aabb_of("tent")
	var s := 3.4 / maxf(box.size.x, box.size.z)
	_put("tent", pos + _jitter(0.2), _rng.randf_range(-0.2, 0.2), s)
	_add_solid(pos, Vector3(3.2, 2.5, 3.2))


## Logs burning in a ring of stones, with a warm light over the camp.
func _build_campfire(pos: Vector3) -> void:
	_put("resource_lumber", pos + Vector3(0, 0, 0), 0.4, PROP_SCALE * 0.55)
	_put("resource_lumber", pos + Vector3(0, 0.25, 0), 1.9, PROP_SCALE * 0.55)
	for i in 6:
		var angle := i * TAU / 6.0 + _rng.randf_range(-0.2, 0.2)
		_put(["rock_single_A", "rock_single_C", "rock_single_E"][_rng.randi() % 3], pos + Vector3(cos(angle), 0, sin(angle)) * 1.3, _rng.randf() * TAU, _rng.randf_range(1.8, 2.4))
	var flame := Effects.make_flame()
	flame.position = pos + Vector3(0, 0.5, 0)
	flame.scale = Vector3.ONE * 2.6
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.28)
	light.light_energy = 3.5
	light.omni_range = 12.0
	light.omni_attenuation = 1.4
	light.position = pos + Vector3(0, 2.0, 0)
	add_child(light)
	_fires.append(pos)
	_add_solid(pos, Vector3(2.2, 1.5, 2.2))


## A bench on the square, its seat turned to the fountain. The hero can sit
## on it (see Seats).
func _build_bench(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var to := Vector3.ZERO
	for y in height:
		for x in width:
			if cell_char(Vector2i(x, y)) == "F":
				to = cell_to_world(Vector2i(x, y)) - pos
	var rot := atan2(to.x, to.z) if to.length() > 0.1 else 0.0
	_put("bench", pos, rot, Seats.BENCH_SCALE)
	# Blocked where the bench is drawn: a long, narrow box turned with it, so
	# the hero can walk right up to the seat (see Seats).
	var box := _add_box(_walls_body, pos + Vector3(0, 0.5, 0), Vector3(Seats.BENCH_SIZE.x, 1.0, Seats.BENCH_SIZE.z))
	box.rotation.y = rot
	stations.append(Seats.station(c, pos, rot))


## A street lamp: an old timber post on a stone foot with an iron lantern
## hanging from its arm (see VillageProps.build_lamp), its panes and the
## candle in it glowing at night.
func _build_lantern(pos: Vector3) -> void:
	if _pane_mat == null:
		_pane_mat = StandardMaterial3D.new()
		_pane_mat.albedo_color = Color(0.32, 0.3, 0.24, 0.55)
		_pane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pane_mat.roughness = 0.25
		_pane_mat.emission_enabled = true
		_pane_mat.emission = Color(1.0, 0.68, 0.34)
		_pane_mat.emission_energy_multiplier = 0.0
		# Lit at nightfall with the windows of the village.
		_window_mats[_pane_mat] = _pane_mat
	VillageProps.build_lamp(self, pos, _pane_mat)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = 2.2
	light.omni_range = 11.0
	light.position = pos + Vector3(0, 2.6, 1.1)
	add_child(light)
	_lamps.append(light)
	# A candle in the lantern that glows once the light fades.
	if _candle_mat == null:
		_candle_mat = StandardMaterial3D.new()
		_candle_mat.albedo_color = Color(1.0, 0.8, 0.5)
		_candle_mat.emission_enabled = true
		_candle_mat.emission = Color(1.0, 0.7, 0.35)
		_candle_mat.emission_energy_multiplier = 0.0
	var candle := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.06
	ball.height = 0.12
	candle.mesh = ball
	candle.material_override = _candle_mat
	candle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	candle.position = pos + VillageProps.LANTERN_AT
	candle.visible = false
	add_child(candle)
	_candles.append(candle)
	_add_solid(pos, Vector3(0.7, 3, 0.7))


## A leafy tree, or near the graveyard an autumn pine or a bare one.
func _build_tree(pos: Vector3, single := false) -> void:
	var near_crypt := pos.distance_to(cell_to_world(start_cell)) < 13.0 * TILE
	var roll := _rng.randf()
	var rot := _rng.randf() * TAU
	var at := pos + _jitter(0.9 if not single else 0.3)
	# How tall it stands (metres), for the woods' wildlife (see WoodsLife).
	var height := 0.0
	var leafy := false
	if near_crypt and roll < 0.45:
		_plant(["tree_dead_large", "tree_dead_medium"][_rng.randi() % 2], at, rot, _rng.randf_range(1.2, 1.6))
	elif roll < 0.35 or (near_crypt and roll < 0.8):
		var scale_of := _rng.randf_range(0.9, 1.25)
		var pine: String = ["tree_pine_orange_large", "tree_pine_yellow_large", "tree_pine_orange_medium", "tree_pine_yellow_medium"][_rng.randi() % 4]
		_plant(pine, at, rot, scale_of)
		height = (6.9 if pine.ends_with("large") else 5.4) * scale_of
	elif roll < 0.75 or single:
		var scale_of := _rng.randf_range(5.5, 7.5)
		_plant(["tree_single_A", "tree_single_B"][_rng.randi() % 2], at, rot, scale_of)
		height = 1.1 * scale_of
		leafy = true
	else:
		var scale_of := _rng.randf_range(3.0, 3.8)
		_plant(["trees_A_medium", "trees_B_medium"][_rng.randi() % 2], at, rot, scale_of)
		height = 1.2 * scale_of
	if height > 0.0 and not near_crypt:
		_wood_trees.append({"pos": Vector3(at.x, 0.0, at.z), "height": height, "leafy": leafy})


## The birds and squirrels in the trees along the forest's edge: only trees
## that have open ground beside them (a free tile next to the tree's tile, in
## the village or out of it) are used, so every one can be reached.
func _build_woods_life() -> void:
	var trees := []
	for t: Dictionary in _wood_trees:
		var cell := world_to_cell(t.pos)
		# The open tile closest to the trunk.
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := cell + Vector2i(dx, dy)
				if (dx != 0 or dy != 0) and is_open(c) and cell_to_world(c).distance_to(t.pos) < best_d:
					best_d = cell_to_world(c).distance_to(t.pos)
					best = c
		if best.x < 0:
			continue
		trees.append({"pos": t.pos, "height": t.height, "leafy": t.leafy, "cell": best, "edge": true,
				"in_village": _in_village(cell) or _in_village(best)})
	_wood_trees.clear()
	woods = WoodsLife.new(self, trees, level_name)
	add_child(woods)
	glowworms = GlowwormSwarms.new(self, level_name)
	add_child(glowworms)


## Trees on every forest tile close to the open ground. Further in there
## is only the dark forest floor, which the camera never gets to see much of.
func _build_forest() -> void:
	for y in range(-2, height + 2):
		for x in range(-2, width + 2):
			var c := Vector2i(x, y)
			if cell_char(c) != "#":
				continue
			if _lair_mountain_at != Vector3.INF:
				var rel := cell_to_world(c) - _lair_mountain_at
				if LairMountain.covers(rel.x, rel.z):
					continue
			var depth := _forest_depth(c)
			if depth > FOREST_DEPTH:
				continue
			if _rng.randf() < [1.0, 1.0, 0.9, 0.75, 0.6][depth]:
				_build_tree(cell_to_world(c))


## How many tiles from the nearest open ground (up to FOREST_DEPTH + 1).
func _forest_depth(c: Vector2i) -> int:
	for r in range(1, FOREST_DEPTH + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and not "#=]".contains(cell_char(c + Vector2i(dx, dy))) \
						and c.x + dx >= 0 and c.y + dy >= 0 and c.x + dx < width and c.y + dy < height:
					return r
	return FOREST_DEPTH + 1


## An iron graveyard fence, running along its neighbours; a gate is an arch.
func _build_fence(c: Vector2i, gate: bool) -> void:
	var pos := cell_to_world(c)
	var across := "zaR".contains(cell_char(c + Vector2i(1, 0))) or "zaR".contains(cell_char(c + Vector2i(-1, 0)))
	var rot := 0.0 if across else PI * 0.5
	var along := Vector3(1, 0, 0) if across else Vector3(0, 0, 1)
	if gate:
		_age_graveyard(_put("arch_gate", pos, rot), false)
		_add_solid(pos + along * 1.9, Vector3(0.5, 4, 0.5))
		_add_solid(pos - along * 1.9, Vector3(0.5, 4, 0.5))
		return
	var piece := _put("fence" if _rng.randf() < 0.85 else "fence_broken", pos, rot)
	_age_graveyard(piece, false)
	# Ivy over the low wall of some of the fence.
	if absi(hash("%s|zaun|%s" % [level_name, c])) % 1000 < FENCE_IVY * 1000.0:
		_dress_building(piece, pos, [], 0.0, 1)
	for end in [-1, 1]:
		var key := "pillar_%d_%d" % [roundi((pos.x + along.x * 2 * end) * 10), roundi((pos.z + along.z * 2 * end) * 10)]
		if not _scenes.has(key):
			_scenes[key] = true
			_age_graveyard(_put("fence_pillar", pos + along * 2.0 * end, rot), false)
	_add_solid(pos, Vector3(4, 2.2, 0.5) if across else Vector3(0.5, 2.2, 4))


# --- Buildings ----------------------------------------------------------------

## Each block of building tiles gets one building, scaled to fill it.
func _build_blocks() -> void:
	var seen := {}
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if not BLOCK_CHARS.contains(ch) or seen.has(c):
				continue
			var block := Rect2i(c, Vector2i.ONE)
			while cell_char(Vector2i(block.end.x, y)) == ch:
				block.size.x += 1
			while cell_char(Vector2i(x, block.end.y)) == ch:
				block.size.y += 1
			for by in range(block.position.y, block.end.y):
				for bx in range(block.position.x, block.end.x):
					seen[Vector2i(bx, by)] = true
			_build_block(ch, block)


func _build_block(ch: String, block: Rect2i) -> void:
	if ch == "E":
		_build_lair_entrance(block)
		return
	if ch == "^":
		_build_terrace(block)
		return
	if ch == "]":
		_build_mine_entrance(block)
		return
	if ch == ")":
		_build_elder_cave(block)
		return
	if ch == "<":
		_build_spire_gate(block)
		return
	var facing := _block_facing(block) if ch != "R" else Vector2i(0, 1)
	var rot := atan2(float(facing.x), float(facing.y))
	var turned := facing.x != 0
	var room := Vector2(block.size) * TILE * 0.92
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	var node: Node3D
	if ch == "s":
		node = _build_chapel(center, rot, room if not turned else Vector2(room.y, room.x))
	elif ch == "h":
		node = VillageHouse.build(room if not turned else Vector2(room.y, room.x), _rng, _house_glass())
		node.position = center
		node.rotation.y = rot
		add_child(node)
		WindowSpill.attach(node, _spill_material())
		var door: Vector3 = node.transform * (node.get_meta("door") as Vector3)
		house_doors.append(node.get_meta("door_leaf"))
		_entrances.append({"door": door, "out": Vector3(facing.x, 0, facing.y)})
		_dress_building(node, center, [door], 0.75, AgedStone.IVY_PATCHES, _standalone(block))
	else:
		var model: String = BLOCK_MODELS[ch]
		var box := _aabb_of(model)
		var model_size := Vector2(box.size.z, box.size.x) if turned else Vector2(box.size.x, box.size.z)
		var s := minf(room.x / model_size.x, room.y / model_size.y)
		var foot := (Vector3(box.position.x + box.size.x * 0.5, 0, box.position.z + box.size.z * 0.5) * s).rotated(Vector3.UP, rot)
		node = _put(model, center - foot, rot, s)
		if ch != "R":
			_age_kit_building(node)
		if ch == "u":
			var mill := Windmill.attach(self, node)
			if mill:
				windmills.append(mill)
				# The sails: woven canvas, shaded where the frame holds it.
				SailCloth.apply(mill.sails as MeshInstance3D, _window_mask)
		else:
			_age_graveyard(node, false)
	var solid := Vector3(block.size.x * TILE * 0.86, 4, block.size.y * TILE * 0.86)
	_add_solid(center, solid)
	var reach := Vector2(block.size) * TILE * 0.5 + Vector2(2.0, 2.0)
	var front := center + Vector3(facing.x * reach.x, 0, facing.y * reach.y)
	doors[ch] = front
	if ch != "R" and ch != "h":
		var door := center + Vector3(facing.x * (reach.x - 2.0), 0, facing.y * (reach.y - 2.0))
		_entrances.append({"door": door, "out": Vector3(facing.x, 0, facing.y)})
		if ch == "s":
			var door_spots := []
			for x in [-2.0, 0.0, 2.0]:
				for z in [0.0, -1.5, -3.0]:
					door_spots.append(door + Vector3(x, 0, z).rotated(Vector3.UP, rot))
			_dress_building(node, center, door_spots, 0.75, TEMPLE_IVY, true, 0.0, 0.0, 1.0, false, TEMPLE_ROOF_VINES)
		elif ch == "w" or ch == "k":
			# The gate's passage runs from the front in to the middle: all of it stays free of ivy.
			var gate := [0.0, 0.25, 0.5, 0.75, 1.0].map(func(t: float): return front.lerp(center, t))
			gate.append(door)
			_dress_building(node, center, gate, 0.75, GUILD_IVY if ch == "w" else CASTLE_IVY, true, CASTLE_TOWER_FOOT if ch == "k" else 0.0, CASTLE_PROUD if ch == "k" else 0.0, GUILD_WINDOW_ROOM if ch == "w" else 1.0, ch == "w")
		else:
			# Every stone building wears old ivy, so it is as green as the
			# wooden houses (which ordinary ivy suits). The door and its frame
			# stay clear: a ring of spots round the doorway (the windmill's
			# door is wide, and its frame sits a little in front and behind).
			var door_spots := []
			for x in [-1.8, -0.9, 0.0, 0.9, 1.8]:
				for z in [1.0, 0.0, -1.5, -3.0]:
					door_spots.append(door + Vector3(x, 0, z).rotated(Vector3.UP, rot))
			_dress_building(node, center, door_spots, 0.75, MILL_IVY if ch == "u" else (BANK_IVY if ch == "b" else STONE_IVY), true, 0.0, 0.0, BANK_WINDOW_ROOM if ch == "b" else 1.0, ch == "b", BANK_ROOF_VINES if ch == "b" else 0)
	if interiors.has(ch):
		# Run into the door to go in.
		var door := center + Vector3(facing.x * (reach.x - 2.0), 0, facing.y * (reach.y - 2.0))
		stations.append({"kind": "eingang", "building": ch, "name": BUILDING_NAMES.get(ch, ""),
				"cell": world_to_cell(door - Vector3(facing.x, 0, facing.y) * 0.5), "pos": door, "used": false})
	if ch == "h":
		spots.houses.append(front)
		var plume := ChimneySmoke.make()
		plume.position = node.transform * (node.get_meta("chimney") as Vector3)
		add_child(plume)
		chimneys.append({"door": front, "smoke": plume})
	elif ch == "R":
		# Ivy up the old crypt (never over its door), and no nest on it.
		# The door is set back into the front, so the spots run back to it.
		var door_spots := []
		for x in [-1.2, 0.0, 1.2]:
			for z in [0.0, -1.5, -3.0]:
				door_spots.append(center + Vector3(x, 0, reach.y - 2.0 + z))
		_dress_building(node, center, door_spots, 0.0, CRYPT_IVY, true)
		# A faint cold glow in the crypt door the hero came out of.
		var light := OmniLight3D.new()
		light.light_color = Color(0.6, 0.75, 1.0)
		light.light_energy = 1.4
		light.omni_range = 6.0
		light.position = center + Vector3(0, 2.0, block.size.y * TILE * 0.5 - 1.0)
		add_child(light)
		var motes := Effects.make_sparkles(Color(0.7, 0.85, 1.0))
		motes.position = center + Vector3(0, 2.0, block.size.y * TILE * 0.5 - 0.5)
		add_child(motes)
	elif ch in ["n", "m", "j", "s", "k", "o", "w", "b"]:
		spots.square.append(front)
	if ch == "w":
		# Banners and a rack of weapons by the guild door.
		var side := Vector3(-facing.y, 0, facing.x) * 2.2
		_put("weaponrack", front + side - Vector3(facing.x, 0, facing.y) * 0.8, rot, PROP_SCALE)
		_put("flag_red", front - side - Vector3(facing.x, 0, facing.y) * 0.8, rot, PROP_SCALE)
	elif ch == "k":
		var side := Vector3(-facing.y, 0, facing.x) * 4.0
		for flag in [-1, 1]:
			_put("flag_blue", front + side * flag - Vector3(facing.x, 0, facing.y) * 1.2, rot, PROP_SCALE)
	elif ch == "o":
		# Parcels waiting at the post office.
		var side := Vector3(-facing.y, 0, facing.x) * 2.4
		_put("crate_long_A", front + side - Vector3(facing.x, 0, facing.y) * 1.0, rot, PROP_SCALE)
		_put("crate_open", front - side - Vector3(facing.x, 0, facing.y) * 1.0, rot + 0.3, PROP_SCALE)
	node.set_meta("block", block)


## Weavers' Lane: the block is split into one narrow town house per tile
## along its front, wall to wall, each with its own number, door and colours.
## Every door leads into the hero homes' building floor (see Homes).
func _build_terrace(block: Rect2i) -> void:
	var facing := _block_facing(block)
	var rot := atan2(float(facing.x), float(facing.y))
	var across := Vector2i(absi(facing.y), absi(facing.x))
	var count := block.size.x if across.x != 0 else block.size.y
	var deep := block.size.y if across.x != 0 else block.size.x
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	# Numbered from west to east (or north to south).
	var step := Vector3(across.x, 0, across.y) * TILE
	var first := center - step * (count - 1) * 0.5
	var out := Vector3(facing.x, 0, facing.y)
	for i in count:
		var number := i + 1
		var at := first + step * i
		var house := VillageHouse.build_narrow(Vector2(TILE, deep * TILE * 0.92), number, _rng, _house_glass())
		house.position = at
		house.rotation.y = rot
		house.set_meta("block", block)
		add_child(house)
		WindowSpill.attach(house, _spill_material())
		town_houses.append(house)
		var door := at + Vector3(float(house.get_meta("door_x")), 0, 0).rotated(Vector3.UP, rot) + out * deep * TILE * 0.5
		doors["^" + str(number)] = door + out * 2.0
		_entrances.append({"door": door, "out": out})
		house_doors.append(house.get_meta("door_leaf"))
		_dress_building(house, at, [door], LANE_NEST, LANE_PATCHES)
		if interiors.has("^"):
			stations.append({"kind": "eingang", "building": "^", "house": number, "reach": 1.6, "leaf": house.get_meta("door_leaf"),
					"name": Lang.t("das Haus Nr. %d") % number,
					"cell": world_to_cell(door - out * 0.5), "pos": door, "used": false})
	_add_solid(center, Vector3(block.size.x * TILE, 4, block.size.y * TILE) * Vector3(1.0 if across.x != 0 else 0.86, 1, 1.0 if across.y != 0 else 0.86))


## The way down into the dragon's lair: an old stone arch from Quaternius'
## dungeon kit set into the foot of a rocky mountain (see LairMountain) with
## its door hanging open, a black hole and stairs going down behind it,
## columns either side, skulls in the grass and a red glow from below. Arch,
## columns and stairs are in weathered old stone like the graveyard's, and
## the forecourt is paved (see _pave_forecourts). Run into the arch to go
## down.
func _build_lair_entrance(block: Rect2i) -> void:
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	var depth := block.size.y * TILE * 0.5
	var front := center + Vector3(0, 0, depth - 0.6)
	var arch := _put("lair/Arch", front, 0.0, 1.0)
	_age_ruin(arch)
	# The door swung open against the arch's side.
	_age_ruin(_put("lair/Arch_Door", front + Vector3(-1.2, 0, 0.2), -PI * 0.55, 1.0))
	# The opening: steps going down, fading into the dark.
	var hole := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.3)
	hole.mesh = quad
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_texture = StairsDown.doorway_texture()
	hole.material_override = black
	hole.position = front + Vector3(0, 1.65, -0.35)
	add_child(hole)
	for i in 2:
		_age_ruin(_put("lair/Stairs_Modular", front + Vector3(0, -0.55 - i * 0.9, 0.55 - i * 0.9), PI, 1.3))
	for side in [-1.0, 1.0]:
		_age_ruin(_put("lair/Column2", front + Vector3(side * 2.9, 0, -0.1), 0.0, 0.9))
		_put("lair/Skull", front + Vector3(side * 2.2 + _rng.randf_range(-0.4, 0.4), 0, 1.6 + _rng.randf_range(0.0, 0.8)), _rng.randf() * TAU, 0.8)
	# The mountain the lair is dug into, rising behind the arch, and a few
	# boulders fallen from it at its foot either side.
	var mountain := LairMountain.build(hash(level_name + "berg"))
	mountain.position = front
	add_child(mountain)
	_lair_mountain_at = front
	_forecourts.append({"block": block, "front": front})
	for side in [-1.0, 1.0]:
		_age_ruin(_put("rock_single_E", front + Vector3(side * 5.6, 0, -4.4), side * 0.9, 9.0), LAIR_BOULDER)
		_age_ruin(_put("rock_single_C", front + Vector3(side * 3.6, 0, -1.9), side * 2.1, 3.5), LAIR_BOULDER)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.35, 0.15)
	glow.light_energy = 1.8
	glow.omni_range = 7.0
	glow.position = front + Vector3(0, 1.2, -0.8)
	add_child(glow)
	_add_solid(center, Vector3(block.size.x * TILE * 0.86, 4, block.size.y * TILE * 0.86))
	arch.set_meta("block", block)
	doors["E"] = front + Vector3(0, 0, 2.0)
	if interiors.has("E"):
		stations.append({"kind": "eingang", "building": "E", "name": BUILDING_NAMES.E,
				"cell": world_to_cell(front - Vector3(0, 0, 0.5)), "pos": front + Vector3(0, 0, 0.6), "used": false})


## The dungeon kit's pieces at the lair (plain colours, one per surface) in
## old, weathered stone to match the graveyard (see AgedStone.ruin_material).
## With `colour`, every surface is that stone instead (the fallen boulders,
## in the mountain's grey).
func _age_ruin(node: Node, colour := Color(0, 0, 0, 0)) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if colour.a > 0.0:
				mi.material_override = AgedStone.ruin_material(colour)
			elif mat is StandardMaterial3D:
				mi.set_surface_override_material(s, AgedStone.ruin_material((mat as StandardMaterial3D).albedo_color))


## A mine entrance in the mountains (see Mines): a timber frame set into
## the foot of the rock face, black inside, with its number carved on the
## lintel, a lantern beside it and a heap of ore and a barrow out front. The
## mines are numbered from west to east. Run into it to go down.
func _build_mine_entrance(block: Rect2i) -> void:
	var number := 1
	for y in height:
		for x in range(0, block.position.x):
			var c := Vector2i(x, y)
			if cell_char(c) == "]" and cell_char(c + Vector2i(-1, 0)) != "]" and cell_char(c + Vector2i(0, -1)) != "]":
				number += 1
	var id := "mine%d" % number
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	var front := center + Vector3(0, 0, block.size.y * TILE * 0.5 - 0.4)
	mines.append(front)
	_forecourts.append({"block": block, "front": front})
	var wood := AgedStone.timber_material(Color(0.34, 0.23, 0.14))
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.02, 0.015, 0.015)
	# The black mouth at the back of the notch, against the rock face.
	_add_mesh_box(front + Vector3(0, 1.7, -2.9), Vector3(3.4, 3.4, 1.6), black)
	# Timber walls along the notch, so its sides show planks, not bare rock.
	for side in [-1.0, 1.0]:
		_add_mesh_box(front + Vector3(side * 1.95, 1.9, -1.7), Vector3(0.18, 3.8, 3.2), wood)
	# Two posts, a lintel and a beam across the top.
	for side in [-1.0, 1.0]:
		_add_mesh_box(front + Vector3(side * 1.85, 1.9, 0), Vector3(0.45, 3.8, 0.45), wood)
		_add_mesh_box(front + Vector3(side * 1.85, 1.9, -0.9), Vector3(0.4, 3.8, 0.4), wood)
	_add_mesh_box(front + Vector3(0, 3.95, 0), Vector3(4.6, 0.5, 0.55), wood)
	_add_mesh_box(front + Vector3(0, 3.95, -0.9), Vector3(4.4, 0.45, 0.45), wood)
	var sign := Label3D.new()
	sign.text = ["I", "II", "III", "IV", "V"][mini(number, 5) - 1]
	sign.font = preload("res://assets/fonts/CinzelDecorative-Black.woff2")
	sign.font_size = 96
	sign.pixel_size = 0.012
	sign.modulate = Color(0.95, 0.82, 0.5)
	sign.outline_size = 10
	sign.outline_modulate = Color(0.1, 0.06, 0.03)
	sign.position = front + Vector3(0, 3.95, 0.3)
	add_child(sign)
	_build_lantern(front + Vector3(3.1, 0, 0.9))
	_put("resource_stone", front + Vector3(-3.0, 0, 1.4), _rng.randf() * TAU, PROP_SCALE)
	_put("wheelbarrow", front + Vector3(-2.6, 0, 3.0), 0.6 + _rng.randf_range(-0.3, 0.3), PROP_SCALE)
	var glow := OmniLight3D.new()
	glow.light_color = [Color(1.0, 0.6, 0.3), Color(0.45, 0.75, 1.0), Color(1.0, 0.35, 0.15)][(number - 1) % 3]
	glow.light_energy = 1.2
	glow.omni_range = 5.0
	glow.position = front + Vector3(0, 1.0, -0.6)
	add_child(glow)
	_add_solid(center, Vector3(block.size.x * TILE * 0.9, 4, block.size.y * TILE * 0.9))
	sign.set_meta("block", block)
	doors[id] = front + Vector3(0, 0, 2.2)
	if interiors.has(id):
		stations.append({"kind": "eingang", "building": id, "name": Lang.t("Mine %d") % number,
				"cell": world_to_cell(front - Vector3(0, 0, 0.5)), "pos": front + Vector3(0, 0, 0.5), "used": false})


## The way down to the Great Old One (see ElderLair): a huge black cave
## mouth at the foot of the rock face, fanged with stone teeth all round,
## scorched black in front, a giant skull and old bones at its feet and a
## faint violet glow breathing out of the dark. Run into it to go down.
const ELDER_CAVE := "uralt1"


func _build_elder_cave(block: Rect2i) -> void:
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	var front := center + Vector3(0, 0, block.size.y * TILE * 0.5 - 0.4)
	var width := block.size.x * TILE
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.015, 0.01, 0.02)
	var stone := AgedStone.ruin_material(Color(0.3, 0.28, 0.3))
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color(0.06, 0.05, 0.05, 0.55)
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.roughness = 1.0
	# The black mouth, wide and tall, set back into the rock.
	_add_mesh_box(front + Vector3(0, 3.2, -2.6), Vector3(width * 0.78, 6.4, 2.0), black)
	# Stone teeth hanging from the top and rising from the floor.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name + "uralt")
	for i in 9:
		var x := lerpf(-width * 0.36, width * 0.36, i / 8.0)
		for up in [true, false]:
			var tooth := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.radial_segments = 5
			cone.rings = 1
			cone.top_radius = 0.02 if not up else rng.randf_range(0.35, 0.6)
			cone.bottom_radius = rng.randf_range(0.35, 0.6) if not up else 0.02
			cone.height = rng.randf_range(1.2, 2.4) if up else rng.randf_range(0.6, 1.4)
			tooth.mesh = cone
			tooth.material_override = stone
			tooth.position = front + Vector3(x, (6.4 - cone.height * 0.5) if up else cone.height * 0.5, -1.5)
			add_child(tooth)
	# The brow of rock over the mouth.
	_add_mesh_box(front + Vector3(0, 6.8, -1.9), Vector3(width * 0.9, 1.0, 1.6), stone)
	for side in [-1.0, 1.0]:
		_add_mesh_box(front + Vector3(side * width * 0.43, 3.4, -1.9), Vector3(1.4, 6.8, 1.6), stone)
	# Scorched ground in front, a giant skull and bones.
	var scorch := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = width * 0.32
	disc.bottom_radius = width * 0.32
	disc.height = 0.02
	scorch.mesh = disc
	scorch.material_override = soot
	scorch.position = front + Vector3(0, 0.03, 1.2)
	scorch.scale = Vector3(1.0, 1.0, 0.55)
	add_child(scorch)
	_put("lair/Skull", front + Vector3(-width * 0.3, 0, 1.6), 0.6, 3.2)
	for i in 4:
		_put("lair/Skull", front + Vector3(rng.randf_range(-width * 0.35, width * 0.35), 0, rng.randf_range(2.0, 4.5)), rng.randf() * TAU, 0.9)
	var glow := OmniLight3D.new()
	glow.light_color = ElderLair.VIOLET
	glow.light_energy = 1.8
	glow.omni_range = 9.0
	glow.position = front + Vector3(0, 1.6, -1.0)
	add_child(glow)
	_add_solid(center, Vector3(block.size.x * TILE * 0.9, 4, block.size.y * TILE * 0.9))
	glow.set_meta("block", block)
	doors[ELDER_CAVE] = front + Vector3(0, 0, 2.4)
	_forecourts.append({"block": block, "front": front})
	if interiors.has(ELDER_CAVE):
		stations.append({"kind": "eingang", "building": ELDER_CAVE, "name": BUILDING_NAMES[")"],
				"cell": world_to_cell(front - Vector3(0, 0, 0.5)), "pos": front + Vector3(0, 0, 0.5), "used": false})


## The gate of the Ashen Spire (see AshSpire): the foot of a mage's tower
## that fell long ago, a stone arch left standing between two broken
## pillars, black inside with a violet glow breathing out of it, rubble and
## a few scorched stones in front. Run into it to climb down.
const SPIRE_GATE := "spire1"


func _build_spire_gate(block: Rect2i) -> void:
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	var front := center + Vector3(0, 0, block.size.y * TILE * 0.5 - 0.4)
	var width := block.size.x * TILE
	var stone := AgedStone.ruin_material(Color(0.36, 0.34, 0.37))
	var dark := AgedStone.ruin_material(Color(0.2, 0.19, 0.22))
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.015, 0.01, 0.025)
	var rune := StandardMaterial3D.new()
	rune.albedo_color = Color(0.6, 0.4, 1.0)
	rune.emission_enabled = true
	rune.emission = Color(0.6, 0.4, 1.0)
	rune.emission_energy_multiplier = 1.6
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name + "spire")
	# The dark doorway, and the arch round it: two pillars, one broken short.
	_add_mesh_box(front + Vector3(0, 2.2, -1.6), Vector3(3.2, 4.4, 1.0), black)
	_add_mesh_box(front + Vector3(-2.2, 3.4, -1.4), Vector3(1.4, 6.8, 1.6), stone)
	_add_mesh_box(front + Vector3(2.2, 2.4, -1.4), Vector3(1.4, 4.8, 1.6), stone)
	_add_mesh_box(front + Vector3(-0.6, 4.9, -1.4), Vector3(4.6, 1.0, 1.6), stone)
	# The step in front and a carved rune on the lintel.
	_add_mesh_box(front + Vector3(0, 0.12, 0.3), Vector3(4.6, 0.25, 1.2), dark)
	_add_mesh_box(front + Vector3(-0.6, 4.9, -0.58), Vector3(1.4, 0.4, 0.06), rune)
	_add_mesh_box(front + Vector3(-0.6, 4.9, -0.58), Vector3(0.4, 1.0, 0.06), rune)
	# Fallen stones strewn in front, black with old fire.
	for i in 7:
		var rock := MeshInstance3D.new()
		var chunk := BoxMesh.new()
		chunk.size = Vector3(rng.randf_range(0.5, 1.3), rng.randf_range(0.3, 0.8), rng.randf_range(0.5, 1.2))
		rock.mesh = chunk
		rock.material_override = stone if i % 2 == 0 else dark
		rock.position = front + Vector3(rng.randf_range(-width * 0.45, width * 0.45), chunk.size.y * 0.5, rng.randf_range(1.2, 4.0))
		rock.rotation.y = rng.randf() * TAU
		add_child(rock)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.62, 0.4, 1.0)
	glow.light_energy = 1.6
	glow.omni_range = 8.0
	glow.position = front + Vector3(0, 1.8, -0.4)
	add_child(glow)
	_add_solid(center, Vector3(block.size.x * TILE * 0.9, 4, block.size.y * TILE * 0.9))
	glow.set_meta("block", block)
	doors[SPIRE_GATE] = front + Vector3(0, 0, 2.4)
	_forecourts.append({"block": block, "front": front})
	if interiors.has(SPIRE_GATE):
		stations.append({"kind": "eingang", "building": SPIRE_GATE, "name": BUILDING_NAMES["<"],
				"cell": world_to_cell(front - Vector3(0, 0, 0.5)), "pos": front + Vector3(0, 0, 0.5), "used": false})


## The mountain rock is as solid as the forest: a wall along every rock
## tile that borders walkable ground.
func _build_rock_collision() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "=":
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				if not "#=]".contains(cell_char(c + d)):
					_add_box(_walls_body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(TILE, 4, TILE))
					break


## A dark, creepy hole in the ground: a ring of torn earth and rocks round a
## pit so black no light gets in, a skull or two at its rim and a cold
## breath of mist rising out of it. Run into it to climb down.
func _build_hole(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	holes.append(pos)
	var id := "loch%d" % holes.size()
	# The ragged lip of torn earth round the opening (see VillageProps).
	VillageProps.build_hole_rim(self, pos, 1.3)
	var pit := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.32
	disc.bottom_radius = 1.32
	disc.height = 0.02
	disc.radial_segments = 18
	pit.mesh = disc
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.0, 0.0, 0.0)
	pit.material_override = black
	pit.position = pos + Vector3(0, 0.03, 0)
	pit.rotation.y = _rng.randf() * TAU
	add_child(pit)
	# Torn-up rocks round the rim, and what is left of those who went down.
	for i in 6:
		var angle: float = TAU * i / 6.0 + _rng.randf_range(-0.3, 0.3)
		var rock: String = ["rock_single_A", "rock_single_C", "rock_single_E"][_rng.randi() % 3]
		_put(rock, pos + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(1.9, 2.3), _rng.randf() * TAU, _rng.randf_range(2.0, 3.4))
	for i in 2:
		var angle: float = _rng.randf() * TAU
		_put("lair/Skull", pos + Vector3(cos(angle), 0, sin(angle)) * 2.3, _rng.randf() * TAU, 0.6)
	var mist := Effects.make_sparkles(Color(0.45, 0.5, 0.62, 0.5))
	mist.position = pos + Vector3(0, 0.4, 0)
	add_child(mist)
	_add_solid(pos, Vector3(2.8, 1.0, 2.8))
	doors[id] = pos + Vector3(0, 0, TILE * 0.8)
	if interiors.has(id):
		stations.append({"kind": "eingang", "building": id, "name": "ein dunkles Loch",
				"cell": c, "pos": pos, "reach": 2.6, "used": false})


## The holes whisper to a hero who comes near: words out of the dark, and a
## cold sound.
func _whisper_from_holes(delta: float) -> void:
	_whisper_timer -= delta
	if _whisper_timer > 0.0:
		return
	var breathing := holes_breathe()
	_whisper_timer = randf_range(3.0, 5.0) if breathing else randf_range(5.0, 9.0)
	var reach := WHISPER_RANGE * (BREATH_WHISPER if breathing else 1.0)
	for pos in holes:
		var d := _flat_distance(player.global_position, pos)
		if d < reach:
			var near := 1.0 - d / reach
			Sfx.play(self, "eerie_%d" % (randi() % 6), lerpf(-20.0, -8.0, near), pos, 0.8)
			var whisper := Lang.t(WHISPERS[randi() % WHISPERS.size()])
			Effects.float_text(self, pos + Vector3(0, 1.4, 0), whisper, Color(0.62, 0.64, 0.8, lerpf(0.4, 0.85, near)))
			Events.say(Lang.t("Ein Flüstern"), whisper, pos)
			return


## The temple is a small stone chapel put together from the pieces of the
## Modular Cathedral Kit: a nave with tall windows down both sides, a rose
## window at the back, a pointed doorway with steps at the front, a tiled
## roof and a spire over the door. Its stained glass glows at night.
func _build_chapel(center: Vector3, rot: float, room: Vector2) -> Node3D:
	var chapel := Node3D.new()
	chapel.name = "Chapel"
	for part: Array in CHAPEL_PARTS:
		var piece: Node3D = load(CHAPEL_DIR + part[0] + ".fbx").instantiate()
		piece.position = part[1]
		piece.rotation.y = deg_to_rad(part[2])
		chapel.add_child(piece)
	for z in [CHAPEL_HALF.y - 1.0, -CHAPEL_HALF.y]:
		var gable := MeshInstance3D.new()
		gable.mesh = _chapel_gable()
		gable.position = Vector3(0, CHAPEL_EAVES, z)
		chapel.add_child(gable)
	_skin_chapel(chapel)
	# The kit is built to cathedral scale: shrink it to fit the block, and
	# move it so that the steps in front of the door stay inside it too.
	var s := minf(room.x / CHAPEL_FOOT.x, room.y / CHAPEL_FOOT.y)
	chapel.scale = Vector3.ONE * s
	chapel.rotation.y = rot
	chapel.position = center - (Vector3(0, 0, CHAPEL_FOOT_MID) * s).rotated(Vector3.UP, rot)
	add_child(chapel)
	return chapel


## Gives the chapel pieces the kit's textures: stone and bricks from the trim
## sheet, stained glass that can glow, and the wooden door.
func _skin_chapel(chapel: Node) -> void:
	if not _scenes.has("mat_chapel_trim"):
		var trim := StandardMaterial3D.new()
		trim.albedo_texture = load(CHAPEL_DIR + "trim_sheet.png")
		trim.roughness = 0.9
		# Coloured panes in lead, painted over the kit's clear glass (see
		# tools/make_stained_glass.py).
		var glass := StandardMaterial3D.new()
		glass.albedo_texture = load(CHAPEL_DIR + "stained_glass.png")
		glass.emission_enabled = true
		# At night only the panes glow, each in its own colour, lit warm from
		# within; the stone round them stays dark.
		glass.emission = CHAPEL_GLASS_LIGHT
		glass.emission_texture = load(CHAPEL_DIR + "stained_glass_glow.png")
		glass.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		glass.emission_energy_multiplier = 0.0
		var wood := StandardMaterial3D.new()
		wood.albedo_texture = load(CHAPEL_DIR + "door_diffuse.png")
		wood.roughness = 0.85
		_scenes["mat_chapel_trim"] = trim
		_scenes["mat_chapel_glass"] = glass
		_scenes["mat_chapel_wood"] = wood
		# The windows light up with the houses' at night (see set_hour).
		_window_mats[glass] = glass
	for mi: MeshInstance3D in chapel.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			var kind: String = mat.resource_name if mat else ""
			var key := "mat_chapel_trim"
			if kind.begins_with("window"):
				key = "mat_chapel_glass"
			elif kind == "door":
				key = "mat_chapel_wood"
			mi.set_surface_override_material(i, _scenes[key])


## The soft pools of window light on the ground (see WindowSpill). set_hour
## fades them in with the windows, like the panes' own glow.
func _spill_material() -> ShaderMaterial:
	if not _scenes.has("mat_window_spill"):
		var mat := WindowSpill.material(WINDOW_LIGHT, WINDOW_GLOW)
		_scenes["mat_window_spill"] = mat
		_window_mats[mat] = mat
	return _scenes["mat_window_spill"]


## The window panes of the villagers' houses: dark by day, warm at night
## (see set_hour).
func _house_glass() -> ShaderMaterial:
	if not _scenes.has("mat_house_glass"):
		var glass := WindowLights.glass_material(WINDOW_LIGHT)
		_scenes["mat_house_glass"] = glass
		_window_mats[glass] = glass
	return _scenes["mat_house_glass"]


## The kit's roof is open at both ends: a brick gable closes each one. It is
## built in strips so that each strip shows one band of the trim sheet's
## bricks, like the walls below.
func _chapel_gable() -> Mesh:
	if _scenes.has("mesh_chapel_gable"):
		return _scenes["mesh_chapel_gable"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strips := 4
	var strip := CHAPEL_GABLE_HEIGHT / strips
	for i in strips:
		var y0 := i * strip
		var y1 := y0 + strip
		var w0 := CHAPEL_HALF.x * (1.0 - y0 / CHAPEL_GABLE_HEIGHT)
		var w1 := CHAPEL_HALF.x * (1.0 - y1 / CHAPEL_GABLE_HEIGHT)
		var v0 := GABLE_BRICK_V.y
		var v1 := GABLE_BRICK_V.y - (GABLE_BRICK_V.y - GABLE_BRICK_V.x) * strip / 4.0
		for side in [1.0, 0.0]:
			# Both faces of the gable, each turned outwards.
			var n := Vector3(0, 0, 1.0 if side > 0.5 else -1.0)
			var quad := [Vector3(-w0, y0, side), Vector3(w0, y0, side), Vector3(w1, y1, side), Vector3(-w1, y1, side)]
			var uvs := [Vector2(-w0 / 8.0, v0), Vector2(w0 / 8.0, v0), Vector2(w1 / 8.0, v1), Vector2(-w1 / 8.0, v1)]
			var order := [0, 1, 2, 0, 2, 3] if side > 0.5 else [0, 2, 1, 0, 3, 2]
			for k in order:
				st.set_normal(n)
				st.set_uv(uvs[k])
				st.add_vertex(quad[k])
	var mesh := st.commit()
	_scenes["mesh_chapel_gable"] = mesh
	return mesh


## The mask over the window panes on the KayKit palette.
func _window_mask_texture() -> void:
	if _window_mask == null:
		# Image.create starts black: only the window patch shines.
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		var at := Vector2i(WINDOW_UV * 256.0)
		img.fill_rect(Rect2i(at - Vector2i(3, 3), Vector2i(7, 7)), Color.WHITE)
		_window_mask = ImageTexture.create_from_image(img)


## Builds a KayKit building of the temple's old stone instead of its toy
## colours (see AgedStone): its light walls become stone blocks, its roofs
## faded tiles, and its windows still glow at night.
func _age_kit_building(node: Node) -> void:
	_window_mask_texture()
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.get_active_material(0)
		if not mat is StandardMaterial3D:
			continue
		if not _window_mats.has(mat):
			_window_mats[mat] = AgedStone.kit_material((mat as StandardMaterial3D).albedo_texture, _window_mask)
		mi.material_override = _window_mats[mat]
		# The way each beam runs, for the grain of its wood.
		mi.mesh = AgedStone.grained_mesh(mi.mesh)


## Whether a building's block stands on its own: no paving of the square
## within SQUARE_GAP tiles of it (see SQUARE_GAP).
func _standalone(block: Rect2i) -> bool:
	var round := block.grow(SQUARE_GAP)
	for y in range(round.position.y, round.end.y):
		for x in range(round.position.x, round.end.x):
			if cell_char(Vector2i(x, y)) == ":":
				return false
	return true


## Ivy up the walls of a building, and maybe a nest up on it (see AgedStone).
## `middle` is the middle of its foot, `door_spots` where its doors are.
## Each building has its own random numbers, so it is dressed the same every
## time; and what was found is kept, so when the hero steps out of the crypt
## the village built behind the title screen (see WorldPreload) has already
## done the work.
func _dress_building(node: Node3D, middle: Vector3, door_spots: Array, nest_chance := 0.75, patches := AgedStone.IVY_PATCHES, old := false, foot_max := 0.0, proud := 0.0, window_room := 1.0, all_sides := false, roof_vines := 0) -> void:
	if old:
		patches = maxi(patches, AgedStone.OLD_IVY_PATCHES)
	var key := "%s|%s|%s|%s|%s|%s" % [level_name, middle, _bounds_in(node), old, foot_max, proud]
	if not _dressed.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		# The meshes are read in world space (a copy of the village is built
		# far below, see WorldPreload); the ivy and the nest are kept in the
		# village's own.
		var offset := global_position
		var tris := AgedStone.triangles(node)
		var ground := node.global_position.y
		var doors_at := door_spots.map(func(d: Vector3): return d + offset)
		var leaves := {"xforms": [], "colours": []}
		# Window panes the house builder noted (see VillageHouse), in world space.
		var panes: Array = (node.get_meta("windows", []) as Array).map(func(w: Vector3): return node.global_transform * w)
		if panes.is_empty():
			panes = AgedStone.window_panes(tris, WINDOW_UV)
		panes.append_array(AgedStone.glass_boxes(tris))
		AgedStone.grow_ivy(tris, middle + offset, ground, doors_at, rng, leaves, patches, old, panes, foot_max, proud, window_room, all_sides, roof_vines)
		for i in leaves.xforms.size():
			leaves.xforms[i] = (leaves.xforms[i] as Transform3D).translated(-offset)
		var stems: Array = leaves.get("stems", [])
		for i in stems.size():
			stems[i] = (stems[i] as Transform3D).translated(-offset)
		var grapes: Array = leaves.get("grapes", [])
		for i in grapes.size():
			grapes[i] = (grapes[i] as Transform3D).translated(-offset)
		var spot := Vector3.INF
		if rng.randf() < nest_chance:
			spot = AgedStone.nest_spot(tris, ground)
		_dressed[key] = {"leaves": leaves, "nest": spot - offset if spot != Vector3.INF else spot, "turn": rng.randf() * TAU}
	var done: Dictionary = _dressed[key]
	_ivy.xforms.append_array(done.leaves.xforms)
	_ivy.colours.append_array(done.leaves.colours)
	if done.leaves.has("stems"):
		if not _ivy.has("stems"):
			_ivy["stems"] = []
			_ivy["stem_colours"] = []
		_ivy.stems.append_array(done.leaves.stems)
		_ivy.stem_colours.append_array(done.leaves.stem_colours)
	if done.leaves.has("grapes"):
		if not _ivy.has("grapes"):
			_ivy["grapes"] = []
			_ivy["grape_colours"] = []
		_ivy.grapes.append_array(done.leaves.grapes)
		_ivy.grape_colours.append_array(done.leaves.grape_colours)
	if done.nest == Vector3.INF or nests.size() >= MAX_NESTS:
		return
	var nest := MeshInstance3D.new()
	nest.name = "Nest"
	nest.mesh = AgedStone.nest_mesh()
	nest.rotation.y = done.turn
	nest.position = done.nest
	add_child(nest)
	nests.append(done.nest)


## The box round a building's meshes, as it stands in the village.
func _bounds_in(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var b: AABB = (global_transform.affine_inverse() * mi.global_transform) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## The graveyard's models (crypt, gravestones, fence; the KayKit Halloween
## kit, all on one palette) in old, weathered stone to match the village (see
## AgedStone.grave_material). `hewn`: a gravestone, cut from one piece.
## `glowing`: a mask of what glows at night (the panes of a grave light).
func _age_graveyard(node: Node, hewn: bool, shade := 0, glowing: Texture2D = null) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.get_active_material(0)
		if mat is StandardMaterial3D:
			var aged := AgedStone.grave_material((mat as StandardMaterial3D).albedo_texture, hewn, shade, glowing)
			mi.material_override = aged
			if glowing:
				# Lit at nightfall with the windows of the village.
				_window_mats[aged] = aged


## A small lantern beside some of the graves, its panes aglow at night like
## the windows of the village (no light of its own, so it costs nothing).
func _grave_light(c: Vector2i, pos: Vector3) -> void:
	var roll := absi(hash("%s|licht|%s" % [level_name, c]))
	if roll % 1000 >= GRAVE_LIGHTS * 1000.0:
		return
	if _grave_glow == null:
		# The panes are the one patch of the kit's palette at GRAVE_PANES.
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		img.fill_rect(Rect2i(Vector2i(GRAVE_PANES.position * 256.0), Vector2i(GRAVE_PANES.size * 256.0)), Color.WHITE)
		_grave_glow = ImageTexture.create_from_image(img)
	var at := pos + GRAVE_LIGHT_AT * Vector3(1 if roll % 2 == 0 else -1, 1, 1)
	_age_graveyard(_put("lantern_standing", at, float(roll % 628) * 0.01), false, 0, _grave_glow)
	_add_solid(at, Vector3(0.6, 1.0, 0.6))


## The graveyard's path, from the crypt door through the gate, paved with old
## stones like the village's (sunk, mossy and gappy there, see meadow.gdshader).
func _pave_graveyard() -> void:
	var yard := _bounds_of("z")
	if yard.size == Vector2i.ZERO:
		return
	for y in range(yard.position.y, yard.end.y):
		for x in range(yard.position.x, yard.end.x):
			var c := Vector2i(x, y)
			if not ",Pa".contains(cell_char(c)):
				continue
			_pave_line(cell_to_world(c), cell_to_world(c), GRAVE_WAY_WIDTH)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + d
				if ",Pa".contains(cell_char(n)) and yard.has_point(n):
					_pave_line(cell_to_world(c), cell_to_world(n), GRAVE_WAY_WIDTH)
				elif d.y < 0 and cell_char(n) == "R":
					# Up to the crypt's door.
					_pave_line(cell_to_world(c), cell_to_world(c) + Vector3(0, 0, -TILE * 0.5), GRAVE_WAY_WIDTH)


## The forecourts of the wide entrances (the dragon's lair, the Great Old
## One's cave, the mines), paved like the graveyard's path: the whole width
## of the entrance from its front out to the path that arrives there, and
## that path paved on for a few tiles, so the way coming in covers the
## forecourt instead of meeting it as a narrow strip.
func _pave_forecourts() -> void:
	for f: Dictionary in _forecourts:
		var block: Rect2i = f.block
		var front: Vector3 = f.front
		var half := block.size.x * TILE * 0.5 - FORECOURT_MARGIN
		# The first row in front of the block that the arriving path touches
		# (the row right in front of it when no path is close).
		var row := block.end.y
		var arriving: Array[Vector2i] = []
		for k in FORECOURT_REACH:
			for x in range(block.position.x - 1, block.end.x + 1):
				if cell_char(Vector2i(x, block.end.y + k)) == ",":
					arriving.append(Vector2i(x, block.end.y + k))
			if not arriving.is_empty():
				row = block.end.y + k
				break
		var far := maxf(cell_to_world(Vector2i(block.position.x, row)).z, front.z + TILE * 0.5)
		var z := front.z + 0.3
		while z <= far + 0.01:
			_pave_line(Vector3(front.x - half, 0, z), Vector3(front.x + half, 0, z), WAY_WIDTH)
			z += 1.0
		# The arriving path, paved on for a few tiles, tile to tile.
		var seen := {}
		var reach := {}
		for c in arriving:
			reach[c] = 0
			seen[c] = true
		var queue := arriving.duplicate()
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			_pave_line(cell_to_world(c), cell_to_world(c), WAY_WIDTH)
			if reach[c] >= FORECOURT_PATH:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + d
				if seen.has(n) or cell_char(n) != "," or block.has_point(n):
					continue
				seen[n] = true
				reach[n] = reach[c] + 1
				_pave_line(cell_to_world(c), cell_to_world(n), WAY_WIDTH)
				queue.append(n)


## A way paved like the market square from each door to the square or the
## nearest path (only drawn into the ground: the tiles stay as they are).
func _pave_entrances() -> void:
	if _ground_img == null:
		return
	for e: Dictionary in _entrances:
		var door: Vector3 = e.door
		var out: Vector3 = e.out
		var start := world_to_cell(door + out * 2.0)
		var route := _way_to_road(start)
		var points: Array[Vector3] = [door - out * 0.3, door + out * 1.4]
		for c in route:
			points.append(cell_to_world(c))
		for i in points.size() - 1:
			_pave_line(points[i], points[i + 1])
	_pave_graveyard()
	_pave_forecourts()
	# The dirt paths in the village are cobbled too, joined tile to tile.
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "," or not _in_village(c):
				continue
			_pave_line(cell_to_world(c), cell_to_world(c))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if ",:".contains(cell_char(c + d)) and (cell_char(c + d) == ":" or _in_village(c + d)):
					_pave_line(cell_to_world(c), cell_to_world(c + d))
	_ground_tex.update(_ground_img)


## Whether a tile lies within the village: close to one of its buildings.
func _in_village(c: Vector2i) -> bool:
	if _village_near.is_empty():
		for y in height:
			for x in width:
				if VILLAGE_BLOCKS.contains(cell_char(Vector2i(x, y))):
					for dy in range(-VILLAGE_REACH, VILLAGE_REACH + 1):
						for dx in range(-VILLAGE_REACH, VILLAGE_REACH + 1):
							_village_near[Vector2i(x + dx, y + dy)] = true
	return _village_near.has(c)


## Shrubs on the grass beside the village buildings and between them, but
## never in front of a door or on a paved way.
func _plant_bushes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name + "bueschen")
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "." or rng.randf() > BUSH_CHANCE:
				continue
			# Beside a building: the side towards it.
			var toward := Vector3.ZERO
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if VILLAGE_BLOCKS.contains(cell_char(c + d)):
					toward += Vector3(d.x, 0, d.y)
			var count := rng.randi_range(1, 3)
			if toward == Vector3.ZERO:
				# Out on the grass between the buildings, now and then.
				if not _in_village(c) or rng.randf() > BUSH_OPEN:
					continue
				toward = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
				count = 1
			toward = toward.normalized()
			var side := Vector3(-toward.z, 0, toward.x)
			for k in count:
				var at := cell_to_world(c) + toward * rng.randf_range(0.6, 1.3) + side * rng.randf_range(-1.6, 1.6)
				if _paved_at(at) or _entrances.any(func(e): return Vector2((e.door as Vector3).x - at.x, (e.door as Vector3).z - at.z).length() < 3.0):
					continue
				AgedStone.grow_bush(at, rng, _ivy)


## Whether the ground at a spot is paved (the square or a paved way).
func _paved_at(at: Vector3) -> bool:
	var px := Vector2i(floori((at.x / TILE + 0.5) * 4.0), floori((at.z / TILE + 0.5) * 4.0))
	if px.x < 0 or px.y < 0 or px.x >= _ground_img.get_width() or px.y >= _ground_img.get_height():
		return false
	var m := _ground_img.get_pixelv(px)
	return minf(m.r, m.g) > 0.35


## The shortest way over open ground from a tile to the square or a path:
## the tiles in between, string-pulled into as few straight runs as can be.
func _way_to_road(start: Vector2i) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not _open_ground(start):
		return none
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var goal := Vector2i(-1, -1)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if ":,".contains(cell_char(c)):
			goal = c
			break
		if absi(c.x - start.x) + absi(c.y - start.y) >= WAY_SEARCH:
			continue
		for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n := c + d
			if not came.has(n) and _open_ground(n):
				came[n] = c
				queue.append(n)
	if goal.x < 0:
		return none
	var path: Array[Vector2i] = [goal]
	while path[-1] != start:
		path.append(came[path[-1]])
	path.reverse()
	# Straight on wherever the way between stays on open ground.
	var pulled: Array[Vector2i] = [path[0]]
	var i := 0
	while i < path.size() - 1:
		var j := path.size() - 1
		while j > i + 1 and not _clear_between(path[i], path[j]):
			j -= 1
		pulled.append(path[j])
		i = j
	return pulled


func _open_ground(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return false
	var ch := cell_char(c)
	return ".,:'".contains(ch) or (WALK.contains(ch) and not BLOCK_CHARS.contains(ch) and ch != "a")


func _clear_between(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 3
	for k in steps + 1:
		var p := Vector2(a).lerp(Vector2(b), float(k) / maxf(steps, 1))
		if not _open_ground(Vector2i(roundi(p.x), roundi(p.y))):
			return false
	return true


## Paints a straight run of paving into the ground's mask (red and green
## together are the square's stones, see _build_ground).
func _pave_line(from: Vector3, to: Vector3, r := WAY_WIDTH) -> void:
	var a := Vector2(from.x / TILE + 0.5, from.z / TILE + 0.5) * 4.0
	var b := Vector2(to.x / TILE + 0.5, to.z / TILE + 0.5) * 4.0
	var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
	for k in steps + 1:
		var p := a.lerp(b, float(k) / steps)
		for y in range(floori(p.y - r - 1.0), ceili(p.y + r + 1.0)):
			for x in range(floori(p.x - r - 1.0), ceili(p.x + r + 1.0)):
				if x < 0 or y < 0 or x >= _ground_img.get_width() or y >= _ground_img.get_height():
					continue
				var dist := Vector2(x + 0.5, y + 0.5).distance_to(p)
				var paved := clampf(r + 0.5 - dist, 0.0, 1.0)
				if paved <= 0.0:
					continue
				var m := _ground_img.get_pixel(x, y)
				m.r = maxf(m.r, paved)
				m.g = maxf(m.g, paved)
				_ground_img.set_pixel(x, y, m)


## Which way a building's door looks: towards the square if it borders it,
## else towards a path, else south.
func _block_facing(block: Rect2i) -> Vector2i:
	var best := Vector2i(0, 1)
	var best_score := 0
	for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var score := 0
		for y in range(block.position.y, block.end.y):
			for x in range(block.position.x, block.end.x):
				var n := Vector2i(x, y) + d
				if block.has_point(n):
					continue
				if cell_char(n) == ":":
					score += 3
				elif cell_char(n) == ",":
					score += 1
		# Doors facing away from the camera are only taken for the square.
		if d.y < 0:
			score = score - 1 if score >= 3 else 0
		if score > best_score:
			best_score = score
			best = d
	return best


# --- The hero's house ---------------------------------------------------------

## Stone walls from the dungeon kit around a wooden floor, under a tiled
## roof. Inside, the roof lifts off and the south wall turns see-through in
## front of the hero, like the near walls in the dungeon (see WallFade).
func _build_house() -> void:
	_house_rect = _bounds_of("I")
	if _house_rect.size == Vector2i.ZERO:
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/house/wood_floor.jpg")
	wood.uv1_scale = Vector3(2, 2, 2)
	wood.roughness = 0.85
	var plank := PlaneMesh.new()
	plank.size = Vector2(TILE, TILE)
	for y in range(_house_rect.position.y, _house_rect.end.y):
		for x in range(_house_rect.position.x, _house_rect.end.x):
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if ch == "I":
				_add_box(_walls_body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(TILE, 4, TILE))
				continue
			var floor_piece := MeshInstance3D.new()
			floor_piece.mesh = plank
			floor_piece.material_override = wood
			floor_piece.position = cell_to_world(c) + Vector3(0, 0.03, 0)
			add_child(floor_piece)
			if y == _house_rect.end.y - 1:
				_door_cell = c
			_build_house_walls(c)
			if ch == "B":
				_place("bed_decorated", cell_to_world(c), 0.0)
				_add_solid(cell_to_world(c), Vector3(3.2, 1.5, 3.2))
				stations.append({"kind": "bett", "cell": c, "pos": cell_to_world(c), "rot": 0.0, "used": false})
				home_spot = cell_to_world(c + Vector2i(0, 1))
				fox_beds.append(home_spot + Vector3(1.2, 0, -0.6))
			elif ch == "L":
				_place("chest", cell_to_world(c), _back_to_wall(c))
				_add_solid(cell_to_world(c), Vector3(2.4, 1.5, 2.4))
				stations.append({"kind": "lager", "cell": c, "pos": cell_to_world(c), "used": false})
	_build_house_pillars()
	_build_roof()


func _build_house_walls(c: Vector2i) -> void:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if cell_char(c + d) != "I":
			continue
		var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * TILE * 0.5
		var wall := _place("wall", pos, atan2(-float(d.x), -float(d.y)))
		if (c.x + c.y + d.x + d.y) % 2 != 0:
			wall.position.y += 0.02
		# Seen from outside, the inner face of the kit wall would show its
		# back: a second wall faces out.
		var outer := _place("wall", pos + Vector3(d.x, 0, d.y) * 0.02, atan2(float(d.x), float(d.y)))
		if d == Vector2i(0, 1) or c == _door_cell:
			_house_fade.add(wall)
			_house_fade.add(outer)


func _build_house_pillars() -> void:
	for vy in range(_house_rect.position.y + 1, _house_rect.end.y):
		for vx in range(_house_rect.position.x + 1, _house_rect.end.x):
			var cells := [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]
			var walls := cells.filter(func(cc): return cell_char(cc) == "I").size()
			if walls == 1 or walls == 3:
				var pillar := _place("pillar", Vector3(vx * TILE - TILE * 0.5, 0, vy * TILE - TILE * 0.5))
				if vy == _house_rect.end.y - 1:
					_house_fade.add(pillar)


func _build_roof() -> void:
	var w := (_house_rect.size.x - 1) * TILE + 1.6
	var d := (_house_rect.size.y - 1) * TILE + 1.6
	var tiles := StandardMaterial3D.new()
	tiles.albedo_texture = load("res://assets/house/roof_tiles.jpg")
	tiles.uv1_scale = Vector3(4.0, 3.0, 1)
	tiles.albedo_color = Color(0.85, 0.68, 0.6)
	tiles.roughness = 0.8
	var gable_mat := StandardMaterial3D.new()
	gable_mat.albedo_color = Color(0.36, 0.25, 0.17)
	gable_mat.roughness = 0.9
	_roof = Node3D.new()
	var center := cell_to_world(_house_rect.position) + Vector3(_house_rect.size.x - 1, 0, _house_rect.size.y - 1) * TILE * 0.5
	_roof.position = center + Vector3(0, WALL_HEIGHT, 0)
	add_child(_roof)
	# Two tiled slopes, the ridge running east to west, facing the camera.
	var slope := atan2(HOUSE_ROOF_HEIGHT, d * 0.5)
	var length := Vector2(d * 0.5, HOUSE_ROOF_HEIGHT).length() + 0.3
	for side in [1, -1]:
		var slab := BoxMesh.new()
		slab.size = Vector3(w, 0.3, length)
		var piece := MeshInstance3D.new()
		piece.mesh = slab
		piece.material_override = tiles
		piece.rotation.x = slope * side
		piece.position = Vector3(0, HOUSE_ROOF_HEIGHT * 0.5, d * 0.25 * side)
		_roof.add_child(piece)
	# Wooden gables close the ends.
	for side in [1, -1]:
		var gable := PrismMesh.new()
		gable.size = Vector3(d - 0.4, HOUSE_ROOF_HEIGHT - 0.1, 0.3)
		var piece := MeshInstance3D.new()
		piece.mesh = gable
		piece.material_override = gable_mat
		piece.rotation.y = PI * 0.5
		piece.position = Vector3((w * 0.5 - 0.7) * side, HOUSE_ROOF_HEIGHT * 0.5, 0)
		_roof.add_child(piece)
	# A chimney.
	var stack := BoxMesh.new()
	stack.size = Vector3(1.0, 2.4, 1.0)
	var chimney := MeshInstance3D.new()
	chimney.mesh = stack
	chimney.material_override = _kit_material("walls")
	chimney.position = Vector3(w * 0.25, HOUSE_ROOF_HEIGHT * 0.75, -d * 0.12)
	_roof.add_child(chimney)


func _in_house(c: Vector2i) -> bool:
	return _house_rect.has_point(c) and cell_char(c) != "I"


## A golden glow over the door of the hero's new house.
func _show_house_marker() -> void:
	if _marker != null:
		return
	var at := Vector3.INF
	if own_house > 0 and doors.has("^" + str(own_house)):
		at = doors["^" + str(own_house)] + Vector3(0, 0, -1.0)
	elif _door_cell.x >= 0:
		at = cell_to_world(_door_cell) + Vector3(0, 0, 1.0)
	if at == Vector3.INF:
		return
	_marker = Node3D.new()
	_marker.position = at
	add_child(_marker)
	var motes := Effects.make_sparkles(Color(1.0, 0.85, 0.4))
	motes.position.y = 2.0
	_marker.add_child(motes)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position.y = 3.0
	_marker.add_child(light)


## A saved game wakes up in the house the elder gave.
func wake_at_home() -> void:
	house_given = true
	_entered_once = true


## The alarm horn the guard blows, just inside the west gate (see WarHorn).
func _build_war_horn() -> void:
	war_horn_at = WarHorn.spot(self)
	if war_horn_at != Vector3.INF:
		VillageProps.build_war_horn(self, war_horn_at, WarHorn.facing(self, war_horn_at))


# --- Villagers ----------------------------------------------------------------

func _spawn_villagers() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if not VILLAGERS.contains(ch):
				continue
			var v := Villager.new()
			v.setup(self, ch, c)
			add_child(v)
			v.global_position = cell_to_world(c)
			villagers.append(v)
			# The shopkeeper trades like the merchant in the refuge; the
			# banker and the barber open their own menus.
			var kind: String = {"6": "haendler", "Y": "bank", "Z": "barbier", "S": "steinmetz", "1": "schmied"}.get(ch, "npc")
			var station := {"kind": kind, "cell": c, "pos": cell_to_world(c), "used": false, "npc": v}
			v.station = station
			stations.append(station)
			if ch == "0":
				_elder = v
			elif ch == "K":
				_herald = v
			elif ch == "Z":
				_build_barber_shop(c + Vector2i(0, -1))
			elif ch == "S":
				_build_stone_yard(c + Vector2i(0, -1))
			elif ch == "1":
				_build_forge(c + Vector2i(-1, 0))
				_build_anvil(v, c, Vector3.LEFT)
			elif ch == "3":
				_build_chopping_log(v, c)
	_spawn_pips_friend()


## Pip's friend Pippi stands beside him at the goats. She has no map letter:
## she comes with Pip, so a village without him has no friend either.
func _spawn_pips_friend() -> void:
	if not villagers.any(func(v: Villager): return v.role == "7"):
		return
	var c := VillageFarm.pippi_home(self)
	if c == Vector2i(-1, -1):
		return
	var v := Villager.new()
	v.setup(self, "pippi", c)
	add_child(v)
	v.global_position = cell_to_world(c)
	villagers.append(v)
	var station := {"kind": "npc", "cell": c, "pos": cell_to_world(c), "used": false, "npc": v}
	v.station = station
	stations.append(station)


## The barber's stall on the tile behind him: a market tent with a striped
## barber's pole and a hanging sign with scissors at its front, so the shop
## is easy to spot on the square. A barber keeps things clean: the tent is of
## fresh woven linen, not the stained canvas of the bandits' tents.
func _build_barber_shop(cell: Vector2i) -> void:
	var pos := cell_to_world(cell)
	var box := _aabb_of("tent")
	var tent := _put("tent", pos, 0.0, 3.6 / maxf(box.size.x, box.size.z))
	tent.name = "BarberTent"
	WeatheredProps.clean_linen(tent)
	_add_solid(pos, Vector3(3.4, 2.6, 3.4))
	astar.set_point_solid(cell, true)
	var pole := Effects.barber_pole()
	pole.position = pos + Vector3(-2.0, 0, 1.9)
	add_child(pole)
	var board := Effects.shop_sign(Lang.t("Barbier"), preload("res://assets/fonts/Cinzel-Bold.woff2"), "scissors")
	WeatheredProps.weather_plain(board)
	board.position = pos + Vector3(1.4, 0, 1.9)
	add_child(board)
	_add_solid(pos + Vector3(-2.0, 0, 1.9), Vector3(0.5, 2.6, 0.5))
	_add_solid(pos + Vector3(1.4, 0, 1.9), Vector3(0.5, 2.6, 0.5))


## The stonemason's yard on the tile behind him: blocks of carved stone
## stacked up for sale, a rough block on the trestle and a sign.
func _build_stone_yard(cell: Vector2i) -> void:
	var pos := cell_to_world(cell)
	# [offset of the block's bottom middle, turned to lie along z, shade]
	var heap := [
		[Vector3(-0.9, 0, -0.6), false, 0], [Vector3(0.75, 0, -0.6), false, 1],
		[Vector3(-0.05, StoneBlock.HEIGHT, -0.6), false, 2], [Vector3(-0.9, 0, 0.6), false, 3],
		[Vector3(0.75, 0, 0.6), false, 0],
	]
	for part in heap:
		var block := StoneBlock.make_model(StoneBlock.SHADES[part[2]])
		block.position = pos + part[0]
		block.rotation.y = PI * 0.5 if part[1] else _rng.randf_range(-0.05, 0.05)
		add_child(block)
	_add_solid(pos + Vector3(0.2, 0, 0), Vector3(3.4, StoneBlock.HEIGHT * 2.0, 2.6))
	astar.set_point_solid(cell, true)
	var board := Effects.shop_sign(Lang.t("Steinmetz"), preload("res://assets/fonts/Cinzel-Bold.woff2"), "stone")
	WeatheredProps.weather_plain(board)
	board.position = pos + Vector3(-1.6, 0, 1.9)
	add_child(board)
	_add_solid(pos + Vector3(-1.6, 0, 1.9), Vector3(0.5, 2.6, 0.5))


## The smith's forge on the tile beside him: a hearth of rough stones with
## glowing coals under a sooty hood and chimney, bellows, a quench tub and a
## sign (see VillageProps.build_forge), with a flame and a warm light over the
## coals. His anvil stands on his own tile (see _build_anvil).
func _build_forge(cell: Vector2i) -> void:
	var pos := cell_to_world(cell)
	var coals := VillageProps.build_forge(self, pos)
	var flame := Effects.make_flame()
	flame.position = coals
	flame.scale = Vector3.ONE * 2.0
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.omni_attenuation = 1.4
	light.position = coals + Vector3(0, 0.8, 0.6)
	add_child(light)
	# Embers lift off the coals.
	var embers := Effects.make_forge_embers()
	_fixed_seed(embers, 1)
	embers.position = coals + Vector3(0, 0.1, 0)
	add_child(embers)
	# A fire in the chimney: a flickering glowing mouth and a small flame on
	# top of the stack, and the same thin smoke the houses' chimneys give.
	var top := coals + Vector3(0, 2.52, -0.42)
	_chimney_fire(top)
	var plume := ChimneySmoke.make()
	plume.position = top + Vector3(0, 0.25, 0)
	_fixed_seed(plume, 3)
	add_child(plume)
	ChimneySmoke.light(plume, true, true)
	_add_solid(pos, Vector3(3.2, 1.2, 3.0))
	astar.set_point_solid(cell, true)
	var board := Effects.shop_sign(Lang.t("Schmiede"), preload("res://assets/fonts/Cinzel-Bold.woff2"), "anvil")
	WeatheredProps.weather_plain(board)
	board.position = pos + Vector3(-1.5, 0, 1.6)
	add_child(board)
	_add_solid(pos + Vector3(-1.5, 0, 1.6), Vector3(0.5, 2.6, 0.5))


## Gives a particle effect its own fixed random seed. Particles otherwise draw their
## seed from the global random stream, so adding one would shift every roll made
## after it (and the headless tests that depend on them).
func _fixed_seed(p: CPUParticles3D, seed_value: int) -> void:
	p.use_fixed_seed = true
	p.seed = seed_value


## The glow of the forge's fire in its chimney: an emissive mouth on the top
## of the stack that flickers, with a small flame over it (`top` is the middle
## of the stack's top). One material tween, no real light.
func _chimney_fire(top: Vector3) -> void:
	var mouth := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.55, 0.03, 0.3)
	mouth.mesh = slab
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.06, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 2.0
	mouth.material_override = mat
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mouth.position = top + Vector3(0, 0.07, 0)
	add_child(mouth)
	var flame := Effects.make_flame()
	flame.position = top + Vector3(0, 0.1, 0)
	flame.scale = Vector3.ONE * 0.8
	_fixed_seed(flame, 2)
	add_child(flame)
	var tween := mouth.create_tween().set_loops()
	tween.tween_property(mat, "emission_energy_multiplier", 3.0, 0.35)
	tween.tween_property(mat, "emission_energy_multiplier", 1.6, 0.5)
	tween.tween_property(mat, "emission_energy_multiplier", 2.5, 0.25)
	tween.tween_property(mat, "emission_energy_multiplier", 1.9, 0.4)


## The smith's anvil on his own tile, between him and his forge (`face`
## points there), with a bar of glowing iron on it, so his hammer lands on
## iron and not in the air (see Villager.set_chopping). The sparks that fly at
## each blow wait at the spot where the hammer strikes.
func _build_anvil(v: Villager, cell: Vector2i, face: Vector3) -> void:
	var stand := cell_to_world(cell)
	var spot := Node3D.new()
	spot.name = "SmithAnvil"
	spot.position = stand
	spot.rotation.y = atan2(face.x, face.z)
	add_child(spot)
	VillageProps.build_anvil(spot, Villager.ANVIL_AT)
	var sparks := Effects.make_forge_sparks()
	sparks.position = Villager.HAMMER_POINT
	spot.add_child(sparks)
	# The anvil with its heel and horn reaches further across his way than
	# ahead of him.
	var foot := spot.to_global(Villager.ANVIL_AT)
	var size := Vector3(1.1, VillageProps.ANVIL_TOP, 0.8)
	if absf(face.x) > 0.5:
		size = Vector3(0.8, VillageProps.ANVIL_TOP, 1.1)
	_add_solid(foot, size)
	v.global_position = stand
	v.rotation.y = spot.rotation.y
	v.set_chopping(stand, face, sparks)


## The woodcutter's trunk: a felled tree lying across his way on his own
## tile, so his axe lands on wood and not in the air (see
## Villager.set_chopping). He faces the stump with the logs ("t") when one is
## near, as if the trunk came from there; otherwise east. The chips that fly
## at each blow wait at the spot where the blade bites.
func _build_chopping_log(v: Villager, cell: Vector2i) -> void:
	var face := Vector3.RIGHT
	var best := INF
	for y in range(-3, 4):
		for x in range(-3, 4):
			if cell_char(cell + Vector2i(x, y)) == "t" and Vector2(x, y).length() < best:
				best = Vector2(x, y).length()
				face = Vector3(signf(x), 0, 0) if absi(x) >= absi(y) else Vector3(0, 0, signf(y))
	var stand := cell_to_world(cell)
	var spot := Node3D.new()
	spot.name = "ChoppingLog"
	spot.position = stand
	spot.rotation.y = atan2(face.x, face.z)
	add_child(spot)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.4, 0.27, 0.17)
	bark.roughness = 1.0
	var sapwood := StandardMaterial3D.new()
	sapwood.albedo_color = Color(0.86, 0.7, 0.48)
	sapwood.roughness = 0.9
	var heartwood := StandardMaterial3D.new()
	heartwood.albedo_color = Color(0.68, 0.48, 0.28)
	heartwood.roughness = 0.9
	# The trunk lies along the woodcutter's left and right (his own x).
	var r := Villager.LOG_RADIUS
	var trunk := MeshInstance3D.new()
	var round_mesh := CylinderMesh.new()
	round_mesh.top_radius = r
	round_mesh.bottom_radius = r * 1.08
	round_mesh.height = Villager.LOG_LENGTH
	round_mesh.radial_segments = 14
	round_mesh.rings = 1
	trunk.mesh = round_mesh
	trunk.material_override = bark
	trunk.position = Villager.LOG_CENTRE
	trunk.rotation.z = PI * 0.5
	spot.add_child(trunk)
	# The sawn ends: pale wood with a darker heart.
	for side in [-1.0, 1.0]:
		var radius: float = r * (1.08 if side < 0.0 else 1.0)
		for ring in [[radius * 0.94, sapwood, 0.012], [radius * 0.45, heartwood, 0.02]]:
			var disc := MeshInstance3D.new()
			var disc_mesh := CylinderMesh.new()
			disc_mesh.top_radius = ring[0]
			disc_mesh.bottom_radius = ring[0]
			disc_mesh.height = 0.02
			disc_mesh.radial_segments = 14
			disc_mesh.rings = 1
			disc.mesh = disc_mesh
			disc.material_override = ring[1]
			disc.position = Villager.LOG_CENTRE + Vector3(-side * (Villager.LOG_LENGTH * 0.5 + ring[2]), 0, 0)
			disc.rotation.z = PI * 0.5
			spot.add_child(disc)
	# Chips from earlier blows on the ground around the cut.
	var chip_mesh := BoxMesh.new()
	chip_mesh.size = Vector3(0.14, 0.025, 0.08)
	for at in [Vector3(0.35, 0, 1.1), Vector3(-0.6, 0, 1.15), Vector3(0.1, 0, 2.05), Vector3(-0.45, 0, 2.15), Vector3(0.7, 0, 1.95), Vector3(-0.15, 0, 0.95)]:
		var chip := MeshInstance3D.new()
		chip.mesh = chip_mesh
		chip.material_override = sapwood
		chip.position = at + Vector3(0, 0.0125, 0)
		chip.rotation.y = at.x * 7.0 + at.z * 3.0
		spot.add_child(chip)
	var chips := Effects.make_wood_chips()
	chips.position = Villager.BITE_POINT
	spot.add_child(chips)
	var centre := spot.to_global(Villager.LOG_CENTRE)
	var size := Vector3(Villager.LOG_LENGTH, 0.5, r * 2.0)
	if absf(face.x) > 0.5:
		size = Vector3(r * 2.0, 0.5, Villager.LOG_LENGTH)
	_add_solid(Vector3(centre.x, 0, centre.z), size)
	v.global_position = stand
	v.rotation.y = spot.rotation.y
	v.set_chopping(stand, face, chips)


# --- Bandits ------------------------------------------------------------------

## The bandits of the pass take their spots when the world is built.
func _spawn_wild() -> void:
	for s in _wild:
		if s.kind == "hauptmann" and chief_defeated():
			# He fell in this game already. If his blade was left lying
			# there, it still waits where he fell (games saved before the
			# floor was kept get it back here).
			s.timer = INF
			if not taken.has(BanditChief.TROPHY) and not lies_on_floor(BanditChief.TROPHY):
				_drop_item(BanditChief.TROPHY, cell_to_world(s.cell))
			continue
		_spawn_bandit(s)


## Whether the bandit chief has fallen in this saved game.
## Lets the does, stags and foxes out onto their meadows.
func _spawn_animals() -> void:
	for s in _animal_spots:
		var a := Animal.new()
		a.setup(self, s.kind, s.cell)
		if taken.has(a.tame_key()):
			# The hero's own companion: it lives with the hero now (see Pet).
			a.free()
			continue
		add_child(a)
		a.global_position = cell_to_world(s.cell)
		animals.append(a)


func chief_defeated() -> bool:
	return taken.has(CHIEF_DEFEATED)


## Puts a bandit (or a beast) on its spot. When it falls it leaves its loot
## (see Level.drop_kill_loot): a bandit or an orc coins and maybe a piece of
## gear, a wolf or a yeti maybe meat, an ingredient or its fur. After a while
## another comes to take its place.
func _spawn_bandit(s: Dictionary) -> void:
	var stats: Dictionary = Enemy.KINDS[s.kind]
	var is_chief: bool = s.kind == "hauptmann"
	var gear_chance: float = stats.get("gear_chance", CHIEF_GEAR_CHANCE if is_chief else BANDIT_GEAR_CHANCE)
	var purse: Array = stats.get("purse", [CHIEF_GOLD, CHIEF_GOLD] if is_chief else [1, 3])
	var e: Enemy = BanditChief.new() if is_chief else Enemy.new()
	e.kind = s.kind
	e.gear = _roll_gear(e.kind, s.cell, gear_chance, s.wave) if gear_chance > 0.0 else ([] as Array[String])
	# Bandits who come out at night are tougher (see Enemy.night).
	e.night = night
	e.level = self
	add_child(e)
	e.global_position = cell_to_world(s.cell)
	e.died.connect(func():
		enemy_killed.emit(e)
		drop_kill_loot(e, randi_range(purse[0], purse[1]))
		_drop_boss_loot(e)
		s.enemy = null
		s.timer = BANDIT_RESPAWN * (NIGHT_RESPAWN_FACTOR if night else 1.0)
		if is_chief:
			_on_chief_fallen(e))
	if is_chief:
		chief = e
		boss_bar = BossBar.new(e)
		add_child(boss_bar)
	s.enemy = e
	s.wave += 1
	enemies = enemies.filter(func(x): return is_instance_valid(x))
	enemies.append(e)


## The chief falls for good: remembered in the saved game, and his own
## blade drops where he fell.
func _on_chief_fallen(e: BanditChief) -> void:
	taken[CHIEF_DEFEATED] = true
	for s in _wild:
		if s.kind == "hauptmann":
			s.timer = INF
	chief = null
	_drop_item(BanditChief.TROPHY, e.global_position + Vector3(0.8, 0, 0.8))
	Sfx.play_find(self, BanditChief.TROPHY, 0.4, e.global_position)
	notice.emit(Lang.t("Rabenherz ist besiegt! Seine Klinge gehört dir."), 5.0)


## The chief calls his cutthroats: they come running from around the camp,
## from the side away from the hero, and join the fight at once. No more
## than `count` of them at a time.
func call_reinforcements(from: Enemy, count: int) -> void:
	_called = _called.filter(func(x): return is_instance_valid(x) and not x.dead)
	var home := world_to_cell(from.global_position)
	var hero := player.global_position if player else from.global_position
	var cells: Array[Vector2i] = []
	for y in range(-CALL_FROM_TILES.y, CALL_FROM_TILES.y + 1):
		for x in range(-CALL_FROM_TILES.y, CALL_FROM_TILES.y + 1):
			var c := home + Vector2i(x, y)
			var r := Vector2(x, y).length()
			if r < CALL_FROM_TILES.x or r > CALL_FROM_TILES.y or not astar.is_in_boundsv(c) or astar.is_point_solid(c):
				continue
			cells.append(c)
	# Farthest from the hero first, so they come out of the camp.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return cell_to_world(a).distance_squared_to(hero) > cell_to_world(b).distance_squared_to(hero))
	var i := 0
	while _called.size() < count and i < cells.size():
		var e := Enemy.new()
		e.kind = "halsabschneider"
		e.level = self
		add_child(e)
		e.global_position = cell_to_world(cells[i])
		e.alert(hero)
		e.died.connect(func():
			enemy_killed.emit(e)
			drop_kill_loot(e, randi_range(0, 2)))
		enemies = enemies.filter(func(x): return is_instance_valid(x))
		enemies.append(e)
		_called.append(e)
		# Spread them out a little.
		i += 3


## How many of the chief's called cutthroats still stand.
func called_alive() -> int:
	return _called.filter(func(x): return is_instance_valid(x) and not x.dead).size()


## Fallen bandits are replaced once their time is up and the hero is not
## looking; the first time the hero comes near the pass, a warning.
func _mind_the_wild(delta: float) -> void:
	for s in _wild:
		if s.enemy != null:
			continue
		s.timer -= delta
		if s.timer <= 0.0 and _flat_distance(player.global_position, cell_to_world(s.cell)) > RESPAWN_FAR:
			_spawn_bandit(s)
	for s in _wild:
		var beast: bool = Enemy.KINDS[s.kind].get("beast", false)
		if Enemy.KINDS[s.kind].get("mountain", false):
			if not _pass_warned and _flat_distance(player.global_position, cell_to_world(s.cell)) < WILD_WARNING_RANGE:
				_pass_warned = true
				notice.emit(Lang.t("Der Schartenpass! Eiswölfe, Bergorks, Klippenschützen und Felstrolle lauern hier. Nur wer gut gerüstet ist, kommt durch."), 5.0)
			continue
		if (_beasts_warned if beast else _wild_warned) or _flat_distance(player.global_position, cell_to_world(s.cell)) >= WILD_WARNING_RANGE:
			continue
		if beast:
			_beasts_warned = true
			notice.emit(Lang.t("Die Wolfssenke! Wölfe, Orks, Spinnen und ein Yeti streifen hier umher."), 4.5)
		else:
			_wild_warned = true
			notice.emit(Lang.t("Der Räuberpass! Hier lauern Räuber. Wer sie besiegt, nimmt ihre Beute."), 4.5)


## How many bandits stand on the pass right now.
func bandits_alive() -> int:
	var n := 0
	for s in _wild:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead and s.enemy.is_human() and not Enemy.KINDS[s.kind].get("mountain", false):
			n += 1
	return n


## How many beasts roam the wolf hollow right now.
func beasts_alive() -> int:
	var n := 0
	for s in _wild:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead and s.enemy.is_beast() and not Enemy.KINDS[s.kind].get("mountain", false):
			n += 1
	return n


## How much nearer a trader counts than a villager who only talks, when a
## bump or click could mean either (see _npc_station_near).
const TRADER_FIRST := 0.6


## Everyone walking about the village: the villagers and, on the nights he
## comes, the wandering merchant.
func people() -> Array:
	return villagers + [wanderer] if wanderer != null else villagers


## Swings open the village house door nearest to a point, if one is within
## `reach` metres, and tells whether there was one.
func swing_door_near(point: Vector3, reach := 3.5) -> bool:
	var best: HouseDoor = null
	var best_d := reach
	for d in house_doors:
		if not is_instance_valid(d):
			continue
		var dist := _flat_distance(point, d.global_position)
		if dist < best_d:
			best = d
			best_d = dist
	if best == null:
		return false
	best.swing()
	return true


## Bumping into a villager: they walk around, so their tile is not enough.
## A door is hit anywhere along the front of its building.
func station_at(point: Vector3) -> Dictionary:
	var npc := _npc_station_near(point, 1.6)
	if not npc.is_empty():
		return npc
	# Doors of the town houses stand close together: the nearest one counts.
	var door := {}
	var door_distance := INF
	for s in stations:
		if s.kind == "eingang":
			var d := _flat_distance(point, s.pos)
			if d < s.get("reach", 2.4) and d < door_distance:
				door = s
				door_distance = d
	if not door.is_empty():
		return door
	return super(point)


## The villager within reach of a point: the nearest, but a trader counts
## TRADER_FIRST metres nearer than anyone who only talks, so a child playing
## by the stall does not stand between the hero and the goods. {} when
## nobody is that close.
func _npc_station_near(point: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_score := INF
	for s in stations:
		if not s.has("npc") or s.npc.at_home:
			continue
		var d := _flat_distance(point, s.pos)
		if d >= reach:
			continue
		var score := d - (TRADER_FIRST if s.kind != "npc" else 0.0)
		if score < best_score:
			best = s
			best_score = score
	return best


## A click near a villager walks up to the trader among them first, like a
## bump (see _npc_station_near); anything else as anywhere.
func nearest_station(from: Vector3, max_distance := SEARCH_RANGE) -> Dictionary:
	var npc := _npc_station_near(from, max_distance)
	if not npc.is_empty() and npc.kind != "npc":
		return npc
	var other := super(from, max_distance)
	if other.is_empty() or (not npc.is_empty() and other.has("npc")):
		return npc
	return other


# --- Rules of the open air ----------------------------------------------------

func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, not WALK.contains(cell_char(c)))
	# A marked treasure spot or its dug-up chest stands in the way.
	for id in treasure_cells:
		if TreasureMaps.blocks(self, id):
			astar.set_point_solid(treasure_cells[id], true)
	# Villagers and the hero keep to the paths where they can.
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) == ".":
				astar.set_point_weight_scale(c, 1.6)
	village_wall.sync(self)


## By day everything is lit. At night, and in fog, only the lanterns and
## the campfire show the hero to the eyes of enemies: a sneaking hero in the
## dark or the fog stays unseen.
func is_lit(pos: Vector3) -> bool:
	if not night and weather != Weather.FOG:
		return true
	for lamp in _lamps:
		if _flat_distance(pos, lamp.global_position) < LAMP_REACH:
			return true
	for fire in _fires:
		if _flat_distance(pos, fire) < LAMP_REACH:
			return true
	return false


func is_opaque(c: Vector2i) -> bool:
	var ch := cell_char(c)
	return ch == "#" or ch == "=" or ch == "I" or BLOCK_CHARS.contains(ch)


## Whether a tile is walkable ground (for villagers picking where to go).
func is_open(c: Vector2i) -> bool:
	return WALK.contains(cell_char(c)) and not astar.is_point_solid(c)


func _process(delta: float) -> void:
	super(delta)
	if player == null:
		return
	village_alarm.tick(self, delta)
	village_wall.tick(self, delta)
	var cell := world_to_cell(player.global_position)
	var inside := _in_house(cell)
	if inside != _inside:
		_inside = inside
		_roof.visible = not inside
		if not inside:
			_house_fade.reset(self)
		if inside and house_given and not _entered_once:
			_entered_once = true
			notice.emit(Lang.t("Dein neues Zuhause! Im Bett speicherst du, in der Truhe lagerst du deine Schätze."), 4.0)
			home_claimed.emit()
		if inside and _marker:
			_marker.queue_free()
			_marker = null
	if inside:
		_house_fade.update(self, player, get_viewport().get_camera_3d())
	if glowworms and hour >= 0.0:
		glowworms.tick(delta, player.global_position, hour, inside)
	_mind_the_wild(delta)
	_whisper_from_holes(delta)
	_mind_the_night(delta)
	_mind_the_weather(delta)
	_mind_the_moon(delta)
	_check_basket(delta)
	_herald_timer -= delta
	if _herald and _herald_timer <= 0.0 and not night:
		_herald_timer = randf_range(HERALD_EVERY_MIN, HERALD_EVERY_MAX)
		_call_the_village()
	if not house_given and _elder and not _elder.at_home and _flat_distance(player.global_position, _elder.global_position) < GREET_RANGE:
		house_given = true
		_elder.greet_newcomer(player)
		if not town_houses.is_empty():
			# The hero's home is a town house on Weavers' Lane.
			own_house = Homes.house_for(hero, town_houses.size())
		_show_house_marker()
		if own_house > 0:
			notice.emit(Lang.t("Der Dorfvorsteher schenkt dir Haus Nr. %d in der Weberzeile am Nordrand des Dorfes. Ein goldenes Licht zeigt dir die Tür.") % own_house, 5.0)
		elif town_houses.is_empty():
			notice.emit(Lang.t("Der Dorfvorsteher schenkt dir das leere Haus. Ein goldenes Licht zeigt dir die Tür."), 4.5)
		else:
			notice.emit(Lang.t("Der Dorfvorsteher seufzt: Jedes Haus in der Weberzeile ist bewohnt."), 4.5)


## The herald rings the news across the square, and everyone in the village
## comes over to listen for a while: a reason to gather.
func _call_the_village() -> void:
	var stand: Vector3 = _herald.global_position
	_herald.proclaim()
	var ring: Array[Vector3] = []
	var at := world_to_cell(stand)
	for dy in range(-1, 5):
		for dx in range(-4, 5):
			var c := at + Vector2i(dx, dy)
			if cell_char(c) == ":" and absi(dx) + absi(dy) >= 2:
				ring.append(cell_to_world(c))
	ring.shuffle()
	var i := 0
	for v in villagers:
		if v == _herald or not v.comes_to_listen() or i >= ring.size():
			continue
		if _flat_distance(v.global_position, stand) > 22.0 * TILE * 0.5:
			continue
		v.gather_at(ring[i], stand)
		i += 1
	if player and _flat_distance(player.global_position, stand) < 30.0:
		notice.emit(Lang.t("Der Herold ruft auf dem Marktplatz aus. Das Dorf kommt zusammen."), 3.0)


# --- Day and night ------------------------------------------------------------

## Lights the village for an hour of the day (see DayNight) and, when night
## falls or the day breaks, sends the village to bed or wakes it, and calls
## the dead out of their graves or back into them. The first call after the
## world is built settles everything at once, without a word.
func set_hour(new_hour: float) -> void:
	var first := hour < 0.0
	hour = new_hour
	var glow := DayNight.glow_at(hour)
	for lamp in _lamps:
		lamp.light_energy = lerpf(LAMP_DAY, LAMP_NIGHT, glow)
	if _candle_mat:
		_candle_mat.emission_energy_multiplier = CANDLE_GLOW * glow
	for candle in _candles:
		candle.visible = glow > 0.02
	for mat in _window_mats.values():
		if mat is ShaderMaterial:
			mat.set_shader_parameter("glow", WINDOW_GLOW * glow)
			mat.set_shader_parameter("hour", hour)
		else:
			mat.emission_energy_multiplier = WINDOW_GLOW * glow
	var dark := DayNight.is_night(hour)
	var came := _mind_the_wanderer()
	if not first:
		_mind_chimneys()
	if dark == night and not first:
		return
	night = dark
	for v in villagers:
		v.set_night(night, first)
	if first:
		_mind_chimneys(true)
	if night:
		_raise_dead()
	else:
		_lay_the_dead_to_rest()
	set_moon(day if night else -1)
	if not first:
		var text := Lang.t("Die Nacht bricht herein. Das Dorf geht schlafen, und auf dem Friedhof regen sich die Toten.") if night \
				else Lang.t("Ein neuer Tag bricht an. Die Toten kehren in ihre Gräber zurück.")
		var lines := 1
		if came:
			text += "\n" + Lang.t("Am Markt schwingt eine Laterne: Wanderhändler Zarek hat seinen Karren für die Nacht aufgestellt.")
			lines += 1
		if night and Moon.is_full(day):
			text += "\n" + Lang.t("Vollmond! In der Wolfssenke heult ein Rudel, und am Tümpel öffnet sich die Mondblume.")
			lines += 1
		elif night and Moon.is_new(day):
			text += "\n" + Lang.t("Neumond. Die dunklen Löcher atmen, und etwas Großes kriecht näher ans Dorf.")
			lines += 1
		notice.emit(text, 4.5 + 1.5 * (lines - 1))
		# The village takes fright at what the night brings (see VillageWorries).
		if night:
			Events.scare("grauen" if Moon.is_new(day) else "woelfe" if Moon.is_full(day) else "tote")


## Lights the fire in every house someone has come home to in the evening,
## and lets it burn down late at night or once the house is empty (see
## ChimneySmoke). `at_once` settles it on the spot.
func _mind_chimneys(at_once := false) -> void:
	if chimneys.is_empty():
		return
	var burns := ChimneySmoke.fire_burns(hour)
	var home := {}
	if burns:
		for v in villagers:
			if v.at_home:
				var door: Vector3 = v.house_door()
				home[door] = int(home.get(door, 0)) + 1
	for c in chimneys:
		ChimneySmoke.light(c.smoke, ChimneySmoke.smokes(hour, int(home.get(c.door, 0))), at_once)


# --- The wandering merchant ---------------------------------------------------

## Puts Zarek and his cart up on his pitch when his night has come, and
## packs them away again when it is over (see Wanderer). True when he has
## just arrived.
func _mind_the_wanderer() -> bool:
	if _wanderer_cell.x < 0:
		return false
	var due := Wanderer.is_here(day, hour)
	if due == (wanderer != null):
		return false
	if due:
		_wanderer_arrives()
		return true
	_wanderer_leaves()
	return false


func _wanderer_arrives() -> void:
	_build_cart(_wanderer_cell + CART_OFFSET)
	var v := Villager.new()
	v.setup(self, Wanderer.ROLE, _wanderer_cell)
	add_child(v)
	# A little to the side of his cart, so its wheel and lantern show.
	v.global_position = cell_to_world(_wanderer_cell) + Vector3(1.3, 0, 0)
	# He faces the way up from the south, his back to the cart.
	v.rotation.y = 0.0
	var station := {"kind": "wanderhaendler", "cell": _wanderer_cell, "pos": v.global_position, "used": false, "npc": v}
	v.station = station
	stations.append(station)
	wanderer = v


func _wanderer_leaves() -> void:
	if wanderer:
		stations.erase(wanderer.station)
		wanderer.queue_free()
		wanderer = null
	if _cart:
		_cart.queue_free()
		_cart = null
	for shape in _cart_shapes:
		shape.queue_free()
	_cart_shapes.clear()
	var cart_cell := _wanderer_cell + CART_OFFSET
	astar.set_point_solid(cart_cell, not WALK.contains(cell_char(cart_cell)))


## Zarek's covered cart: a wooden box on two big wheels under a hooped
## canvas cover in his colours, its shaft resting on the ground, a lantern on
## a pole, and a few crates and sacks unloaded beside it.
func _build_cart(cell: Vector2i) -> void:
	var pos := cell_to_world(cell)
	_cart = Node3D.new()
	_cart.position = pos
	add_child(_cart)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.9
	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = Color(0.5, 0.3, 0.66)
	canvas.roughness = 1.0
	canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.18, 0.18, 0.2)
	iron.metallic = 0.6
	iron.roughness = 0.5
	var body := _cart_part(BoxMesh.new(), wood, Vector3(0, 1.15, 0))
	(body.mesh as BoxMesh).size = Vector3(3.0, 0.7, 1.7)
	# The canvas: half a cylinder lying along the cart.
	var cover := _cart_part(CylinderMesh.new(), canvas, Vector3(0, 1.5, 0))
	var tube: CylinderMesh = cover.mesh
	tube.top_radius = 0.9
	tube.bottom_radius = 0.9
	tube.height = 2.9
	tube.radial_segments = 20
	# Lying along the cart: only its upper half shows above the box.
	cover.rotation.z = PI * 0.5
	for side in [-1.0, 1.0]:
		var wheel := _cart_part(CylinderMesh.new(), wood, Vector3(0.4, 0.62, side * 0.95))
		var disc: CylinderMesh = wheel.mesh
		disc.top_radius = 0.62
		disc.bottom_radius = 0.62
		disc.height = 0.14
		disc.radial_segments = 16
		wheel.rotation.x = PI * 0.5
		var rim := _cart_part(TorusMesh.new(), iron, Vector3(0.4, 0.62, side * 1.03))
		var ring: TorusMesh = rim.mesh
		ring.inner_radius = 0.56
		ring.outer_radius = 0.66
		rim.rotation.x = PI * 0.5
	var shaft := _cart_part(BoxMesh.new(), wood, Vector3(-2.2, 0.6, 0))
	(shaft.mesh as BoxMesh).size = Vector3(1.8, 0.12, 0.9)
	shaft.rotation.z = -0.45
	# A lantern on a pole at the front corner, with a warm, slightly violet glow.
	var pole := _cart_part(BoxMesh.new(), wood, Vector3(-1.3, 1.6, 1.0))
	(pole.mesh as BoxMesh).size = Vector3(0.1, 3.2, 0.1)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.8, 0.55)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.7, 0.45)
	glass.emission_energy_multiplier = 4.0
	var lamp := _cart_part(BoxMesh.new(), glass, Vector3(-1.3, 3.0, 1.0))
	(lamp.mesh as BoxMesh).size = Vector3(0.3, 0.4, 0.3)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.62)
	light.light_energy = 2.4
	light.omni_range = 9.0
	light.position = Vector3(-1.3, 2.9, 1.4)
	_cart.add_child(light)
	var sparkle := Effects.make_sparkles(Color(0.8, 0.6, 1.0))
	sparkle.position = Vector3(0, 2.6, 0)
	_cart.add_child(sparkle)
	for i in 2:
		var prop: String = ["crate_A_big", "sack"][i]
		_put(prop, Vector3(1.9, 0, -0.4 + i * 0.9), _rng.randf() * TAU, PROP_SCALE, _cart)
	_cart_shapes.append(_add_box(_walls_body, pos + Vector3(0, 1.0, 0), Vector3(3.9, 2.0, 2.2)))
	astar.set_point_solid(cell, true)


func _cart_part(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = at
	_cart.add_child(part)
	return part


## Nightfall: the dead get their spots on the paths beside the graves.
## They rise one by one in _mind_the_night, never where the hero can see.
func _raise_dead() -> void:
	if not _risen.is_empty():
		return
	var spots: Array[Vector2i] = []
	for g in _graves:
		var c := g + Vector2i(0, 1)
		if WALK.contains(cell_char(c)) and not spots.has(c):
			spots.append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name) + int(hour * 60.0)
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	for i in mini(NIGHT_DEAD, spots.size()):
		_risen.append({"cell": spots[i], "kind": NIGHT_DEAD_KINDS[i % NIGHT_DEAD_KINDS.size()], "enemy": null, "timer": 0.0})


## Dawn: the dead who are not fighting the hero sink back into the earth;
## the ones on the hero's heels follow as soon as they give up.
func _lay_the_dead_to_rest() -> void:
	for s in _risen:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead:
			s.enemy.sink_at_dawn()
	_risen.clear()


## The dead rise in the graveyard (and rise again a while after they fall)
## as long as it is night and the hero is not too close.
func _mind_the_night(delta: float) -> void:
	for s in _risen:
		if s.enemy != null:
			continue
		s.timer -= delta
		if s.timer <= 0.0 and _flat_distance(player.global_position, cell_to_world(s.cell)) > NIGHT_DEAD_FAR:
			_spawn_risen(s)


func _spawn_risen(s: Dictionary) -> void:
	var e := Enemy.new()
	e.kind = s.kind
	e.night = true
	e.level = self
	add_child(e)
	e.global_position = cell_to_world(s.cell)
	var dust := Effects.make_sparkles(Color(0.55, 0.8, 0.6), true)
	dust.position = e.global_position + Vector3(0, 0.6, 0)
	add_child(dust)
	e.died.connect(func():
		enemy_killed.emit(e)
		drop_kill_loot(e, randi_range(0, 2))
		s.enemy = null
		s.timer = NIGHT_DEAD_RESPAWN)
	s.enemy = e
	enemies = enemies.filter(func(x): return is_instance_valid(x))
	enemies.append(e)


## How many of the dead walk the graveyard right now.
func risen_alive() -> int:
	var n := 0
	for s in _risen:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead:
			n += 1
	return n


# --- The moon -----------------------------------------------------------------

## Sets up the moon's events for a night (see Moon), or ends them (-1, at
## dawn): the full moon's wolf pack and flowers, the new moon's breathing
## holes and its horror. Whatever is out when the night ends goes back where
## it came from, as soon as it is off the hunt; flowers nobody picked close.
func set_moon(night_of: int) -> void:
	if night_of == moon_night:
		return
	moon_night = night_of
	for s in _pack:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead:
			s.enemy.sink_at_dawn()
	_pack.clear()
	if not _moon_horror.is_empty() and _moon_horror.enemy != null and is_instance_valid(_moon_horror.enemy) and not _moon_horror.enemy.dead:
		_moon_horror.enemy.sink_at_dawn()
	_moon_horror = {}
	_close_flowers()
	var breathing := night_of >= 0 and Moon.is_new(night_of)
	if breathing and _breaths.is_empty():
		_build_breaths()
	for b in _breaths:
		b.visible = breathing
		b.emitting = breathing
	if night_of < 0:
		return
	if Moon.is_full(night_of):
		_place_pack()
		_open_flowers(night_of)
	elif breathing:
		_place_moon_horror(night_of)


## At new moon each hole breathes: a cold, dark plume rises out of it. Made
## the first new moon the hero sees here, and only hidden by day after.
func _build_breaths() -> void:
	for pos in holes:
		var breath := Effects.make_sparkles(Color(0.16, 0.17, 0.24, 0.75))
		breath.amount = 34
		breath.lifetime = 2.6
		breath.mesh = Effects._quad(0.55, Color(1, 1, 1))
		breath.emission_sphere_radius = 1.1
		breath.gravity = Vector3(0, 1.3, 0)
		breath.initial_velocity_min = 0.4
		breath.initial_velocity_max = 1.2
		breath.position = pos + Vector3(0, 0.3, 0)
		add_child(breath)
		_breaths.append(breath)


## Whether the holes breathe tonight: a new-moon night.
func holes_breathe() -> bool:
	return moon_night >= 0 and Moon.is_new(moon_night)


## Open ground right beside a map letter, in map order.
func _cells_beside(letter: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if not is_open(c):
				continue
			var beside := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					beside = beside or cell_char(c + Vector2i(dx, dy)) == letter
			if beside:
				cells.append(c)
	return cells


## The full moon's pack: its leader (an elite wolf) and the others close
## around it on the far side of the pond from the hero's way in.
func _place_pack() -> void:
	var cells := _cells_beside(PACK_NEAR)
	if cells.is_empty():
		return
	var den: Vector2i = cells[cells.size() / 2]
	var spots: Array[Vector2i] = [den]
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := den + Vector2i(dx, dy)
				if spots.size() < PACK_SIZE and not spots.has(c) and is_open(c) and (absi(dx) + absi(dy)) % 2 == 0:
					spots.append(c)
	for i in spots.size():
		_pack.append({"cell": spots[i], "kind": "wolf", "leader": i == 0, "enemy": null, "timer": randf_range(0.0, 3.0)})


## The moon flowers open on the pond's bank: FLOWERS of them, spread out,
## but not the ones the hero picked this night already.
func _open_flowers(night_of: int) -> void:
	for key in taken.keys():
		if str(key).begins_with(FLOWER + ":") and not str(key).begins_with("%s:%d:" % [FLOWER, night_of]):
			taken.erase(key)
	var cells := _cells_beside(PACK_NEAR)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d" % [level_name, night_of])
	var picked: Array[Vector2i] = []
	var tries := 0
	while picked.size() < FLOWERS and not cells.is_empty() and tries < 200:
		tries += 1
		var c: Vector2i = cells[rng.randi() % cells.size()]
		if picked.any(func(p: Vector2i) -> bool: return maxi(absi(p.x - c.x), absi(p.y - c.y)) < 2):
			continue
		picked.append(c)
	for i in picked.size():
		var id := "%s:%d:%d" % [FLOWER, night_of, i]
		if not taken.has(id):
			_grow_flower(cell_to_world(picked[i]), id)


## A pale moon flower: a thin stem with a glowing, silvery bloom, a soft
## light and a few motes over it. Walk into it to pick it: it goes into the
## ingredient pouch (see Crafting).
func _grow_flower(pos: Vector3, id: String) -> void:
	var holder := Node3D.new()
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.3, 0.45, 0.32)
	var stem := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.03
	rod.bottom_radius = 0.05
	rod.height = 0.7
	stem.mesh = rod
	stem.material_override = green
	stem.position = Vector3(0, -0.45, 0)
	holder.add_child(stem)
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.86, 0.9, 1.0)
	pale.emission_enabled = true
	pale.emission = Color(0.62, 0.72, 1.0)
	pale.emission_energy_multiplier = 1.6
	for i in 5:
		var petal := MeshInstance3D.new()
		var leaf := SphereMesh.new()
		leaf.radius = 0.16
		leaf.height = 0.1
		petal.mesh = leaf
		petal.material_override = pale
		var angle := TAU * i / 5.0
		petal.position = Vector3(cos(angle) * 0.15, 0, sin(angle) * 0.15)
		holder.add_child(petal)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.8, 1.0)
	light.light_energy = 1.2
	light.omni_range = 3.0
	holder.add_child(light)
	holder.add_child(Effects.make_sparkles(Color(0.75, 0.85, 1.0)))
	holder.position = Vector3(pos.x, 0.8, pos.z)
	add_child(holder)
	_pickups.append({"node": holder, "kind": "ingredient", "ingredient": FLOWER, "id": id, "radius": 1.6, "moon": true})


## How many moon flowers are open right now.
func flowers_open() -> int:
	return _pickups.filter(func(p): return p.get("moon", false)).size()


## Dawn: the moon flowers nobody picked close and are gone.
func _close_flowers() -> void:
	for p in _pickups.duplicate():
		if p.get("moon", false):
			_pickups.erase(p)
			var n: Node3D = p.node
			if is_instance_valid(n):
				var tween := create_tween()
				tween.tween_property(n, "scale", Vector3.ONE * 0.01, 1.2)
				tween.tween_callback(n.queue_free)


## Where the village square is: the middle of its paving (":").
func village_middle() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for y in height:
		for x in width:
			if cell_char(Vector2i(x, y)) == ":":
				sum += Vector2(x, y)
				n += 1
	return sum / n if n > 0 else Vector2(start_cell)


## The new moon's horror: it crawls out of the hole nearest the village and
## lurks part of the way towards the square. A horror slain this night does
## not come back before the next new moon.
func _place_moon_horror(night_of: int) -> void:
	if holes.is_empty() or taken.has("neumond:%d" % night_of):
		return
	var middle := village_middle()
	var hole := world_to_cell(holes[0])
	for pos in holes:
		var c := world_to_cell(pos)
		if Vector2(c).distance_to(middle) < Vector2(hole).distance_to(middle):
			hole = c
	var way := middle - Vector2(hole)
	var out := maxf(way.length() * HORROR_WAY, HORROR_OUT)
	var aim := Vector2(hole) + way.normalized() * minf(out, way.length())
	var best := Vector2i(-1, -1)
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if is_open(c) and cell_char(c) != ":" and (best.x < 0 or Vector2(c).distance_to(aim) < Vector2(best).distance_to(aim)):
				best = c
	if best.x < 0:
		return
	var kind: String = Enemy.HORRORS[(night_of / Moon.CYCLE) % Enemy.HORRORS.size()]
	_moon_horror = {"cell": best, "hole": hole, "kind": kind, "night": night_of, "enemy": null, "timer": randf_range(2.0, 6.0)}


## The moon's creatures come out once their time has come and the hero is
## not looking. The pack hunts together: once one of them is after the
## hero, the rest of the pack comes running too.
func _mind_the_moon(delta: float) -> void:
	var hunting := false
	for s in _pack:
		if s.enemy == null:
			s.timer -= delta
			if s.timer <= 0.0 and _flat_distance(player.global_position, cell_to_world(s.cell)) > MOON_FAR:
				_spawn_pack_wolf(s)
		elif is_instance_valid(s.enemy) and s.enemy.is_hunting():
			hunting = true
	if hunting:
		for s in _pack:
			if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead and not s.enemy.is_hunting():
				s.enemy.alert(player.global_position)
	if not _moon_horror.is_empty() and _moon_horror.enemy == null:
		_moon_horror.timer -= delta
		if _moon_horror.timer <= 0.0 and _flat_distance(player.global_position, cell_to_world(_moon_horror.cell)) > MOON_FAR:
			_spawn_moon_horror()


func _spawn_pack_wolf(s: Dictionary) -> void:
	var e := Enemy.new()
	e.kind = s.kind
	e.elite = s.leader
	e.night = true
	e.level = self
	add_child(e)
	e.global_position = cell_to_world(s.cell)
	var purse: Array = Enemy.KINDS[s.kind].get("purse", [0, 1])
	e.died.connect(func():
		enemy_killed.emit(e)
		drop_kill_loot(e, randi_range(purse[0], purse[1]) + (3 if s.leader else 0))
		s.timer = INF)
	s.enemy = e
	enemies = enemies.filter(func(x): return is_instance_valid(x))
	enemies.append(e)


func _spawn_moon_horror() -> void:
	var s := _moon_horror
	var e := Enemy.new()
	e.kind = s.kind
	e.night = true
	e.level = self
	add_child(e)
	e.global_position = cell_to_world(s.cell)
	var dust := Effects.make_sparkles(Color(0.2, 0.2, 0.3), true)
	dust.position = e.global_position + Vector3(0, 0.6, 0)
	add_child(dust)
	e.died.connect(func():
		enemy_killed.emit(e)
		taken["neumond:%d" % int(s.night)] = true
		drop_kill_loot(e, randi_range(8, 14))
		s.timer = INF)
	s.enemy = e
	enemies = enemies.filter(func(x): return is_instance_valid(x))
	enemies.append(e)


## How many of the full moon's pack are about right now.
func pack_alive() -> int:
	return _pack.filter(func(s): return s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead).size()


## The new moon's horror while it is out, else null.
func moon_horror() -> Enemy:
	if _moon_horror.is_empty() or _moon_horror.enemy == null or not is_instance_valid(_moon_horror.enemy) or _moon_horror.enemy.dead:
		return null
	return _moon_horror.enemy


# --- Weather ------------------------------------------------------------------

## Sets the weather (see Weather). When it changes, the creatures of the old
## weather go back where they came from (as soon as they are off the hunt),
## thunder ore left from a storm fades, and the new weather's creatures get
## their spots. The first call after the world is built settles everything
## without a word.
func set_weather(kind: String) -> void:
	if kind == weather:
		return
	var first := weather == ""
	var was := weather
	weather = kind
	for s in _weather_foes:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead:
			# Slimes stay when the weather turns and wander on (see
			# SlimeGrowth); the others go back where they came from.
			if not SlimeGrowth.grows(s.enemy.kind):
				s.enemy.sink_at_dawn()
	_weather_foes.clear()
	if kind != Weather.STORM:
		_fade_ore()
	for foes in WEATHER_FOES.get(kind, []):
		_place_weather_foes(foes)
	_strike_timer = randf_range(2.0, STRIKE_EVERY_MIN)
	if first:
		return
	if kind == Weather.RAIN:
		notice.emit(Lang.t("Es fängt an zu regnen. Am Teich im Wald kriechen Schleime aus dem Wasser."), 4.5)
	elif kind == Weather.FOG:
		notice.emit(Lang.t("Nebel zieht auf. Zwischen den toten Bäumen treiben Nebelgeister, am Teich kriechen Schleime, und wer schleicht, bleibt ungesehen."), 4.5)
	elif kind == Weather.STORM:
		notice.emit(Lang.t("Ein Gewitter zieht auf! Fledermäuse schwärmen um die Felsen, Schleime kriechen aus dem Teich, und wo der Blitz einschlägt, glimmt Donnererz."), 5.0)
	else:
		notice.emit(Lang.t("Das Gewitter zieht ab. Liegengebliebenes Donnererz verglimmt.") if was == Weather.STORM
				else Lang.t("Der Himmel klart auf."), 4.0)


## How much water lies in the rain puddles (see Puddles.set_water).
func set_puddles(water: float, rain := 0.0, sky := 1.0) -> void:
	if puddles:
		puddles.set_water(water, rain, sky)


## Whether a spot on the ground is in a rain puddle deep enough to splash.
## The ground of an open-air tile, as _build_ground lays it (see Surfaces):
## paving on the square, the dirt paths, the floor of the hero's old house,
## loose scree in the mountains, dark soil in the graveyard, the pumpkin
## field and the robbers' camp, and grass everywhere else.
func ground_at(c: Vector2i) -> String:
	if _ground_rects.is_empty():
		_ground_rects = {"square": _bounds_of(":"), "fence": _bounds_of("z")}
	var ch := cell_char(c)
	if ",aP".contains(ch):
		return Surfaces.PATH
	if ch == "i" or ch == "B" or ch == "L":
		return Surfaces.WOOD
	if "'=]{}-/".contains(ch):
		return Surfaces.SCREE
	var square: Rect2i = _ground_rects.square
	if ch == ":" or (square.has_point(c) and not BLOCK_CHARS.contains(ch)):
		return Surfaces.PAVING
	var fence: Rect2i = _ground_rects.fence
	if fence.has_point(c) or ch == "y" or CAMP.contains(ch):
		return Surfaces.SOIL
	return Surfaces.GRASS


func in_puddle(p: Vector3) -> bool:
	return puddles != null and p.y < 0.3 and puddles.wet_at(p)


## How full the puddle at a spot is, 0 to 1 (see Puddles.fill_at).
func puddle_fill(p: Vector3) -> float:
	return puddles.fill_at(p) if puddles != null else 0.0


func splash_puddle(at: Vector3, hard := true) -> void:
	if puddles:
		puddles.splash(at, hard)


## A wet footprint on dry ground, left by a hero fresh out of a puddle.
func wet_print(at: Vector3, heading: float) -> void:
	if puddles:
		puddles.wet_print(at, heading)


## Spots for the creatures of a weather: open ground right next to the map
## letter they gather around, spread out so they do not come in a heap.
func _place_weather_foes(foes: Dictionary) -> void:
	var near: String = foes.near
	var cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if not is_open(c) or cells.has(c):
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if cell_char(c + Vector2i(dx, dy)) == near and not cells.has(c):
						cells.append(c)
	cells.shuffle()
	var picked: Array[Vector2i] = []
	for c in cells:
		if picked.size() >= int(foes.count):
			break
		if picked.any(func(p: Vector2i) -> bool: return maxi(absi(p.x - c.x), absi(p.y - c.y)) < 2):
			continue
		picked.append(c)
	for c in picked:
		_weather_foes.append({"cell": c, "kind": foes.kind, "enemy": null, "timer": randf_range(0.0, 6.0)})


## The weather's creatures come (and come again a while after they fall)
## as long as the weather lasts and the hero is not too close; in a storm,
## lightning strikes now and then.
func _mind_the_weather(delta: float) -> void:
	for s in _weather_foes:
		if s.enemy != null:
			continue
		s.timer -= delta
		if s.timer <= 0.0 and _flat_distance(player.global_position, cell_to_world(s.cell)) > WEATHER_FAR:
			# The slimes that stayed from earlier weather count: no more
			# than SLIMES_AT_MOST crawl about at once.
			if SlimeGrowth.grows(s.kind) and slimes_about() >= SLIMES_AT_MOST:
				s.timer = WEATHER_RESPAWN
				continue
			_spawn_weather_foe(s)
	if weather == Weather.STORM:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_strike_timer = randf_range(STRIKE_EVERY_MIN, STRIKE_EVERY_MAX)
			strike()


func _spawn_weather_foe(s: Dictionary) -> void:
	var e := Enemy.new()
	e.kind = s.kind
	e.night = night
	e.level = self
	add_child(e)
	e.global_position = cell_to_world(s.cell)
	var mist := Effects.make_sparkles(Color(0.7, 0.78, 0.86), true)
	mist.position = e.global_position + Vector3(0, 0.6, 0)
	add_child(mist)
	var purse: Array = Enemy.KINDS[s.kind].get("purse", [0, 2])
	e.died.connect(func():
		enemy_killed.emit(e)
		drop_kill_loot(e, randi_range(purse[0], purse[1]))
		s.enemy = null
		s.timer = WEATHER_RESPAWN)
	s.enemy = e
	enemies = enemies.filter(func(x): return is_instance_valid(x))
	enemies.append(e)


## A slime kept from before (see SlimeGrowth.restore) back at `at`, with
## its own colour and level in `custom`.
func spawn_slime(kind: String, at: Vector3, custom: Dictionary) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.night = night
	e.level = self
	e.custom = custom
	add_child(e)
	e.global_position = at
	var purse: Array = Enemy.KINDS[kind].get("purse", [0, 2])
	e.died.connect(func():
		enemy_killed.emit(e)
		drop_kill_loot(e, randi_range(purse[0], purse[1])))
	enemies = enemies.filter(func(x): return is_instance_valid(x))
	enemies.append(e)
	return e


## How many slimes crawl about the open air right now.
func slimes_about() -> int:
	return enemies.filter(func(e): return is_instance_valid(e) and not e.dead and SlimeGrowth.grows(e.kind)).size()


## How many of the weather's creatures are about right now.
func weather_foes_alive() -> int:
	var n := 0
	for s in _weather_foes:
		if s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead:
			n += 1
	return n


## A stroke of lightning. Mostly it hits one of the rocks, and may leave a
## lump of thunder ore glowing beside it; otherwise it strikes somewhere in
## the woods near the hero. Returns where it struck.
func strike() -> Vector3:
	var at: Vector3 = (player.global_position if player else Vector3.ZERO) + Vector3(randf_range(-30, 30), 0, randf_range(-24, 24))
	var ore_spot := Vector2i(-1, -1)
	if not _rock_cells.is_empty() and randf() < 0.75:
		var rock: Vector2i = _rock_cells.pick_random()
		at = cell_to_world(rock)
		if randf() < ORE_CHANCE and ore_lying() < MAX_ORE:
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if is_open(rock + d):
					ore_spot = rock + d
					break
	at.y = 0.0
	_show_bolt(at)
	lightning.emit(at)
	Events.scare("blitz")
	if ore_spot.x >= 0:
		var pos := cell_to_world(ore_spot).lerp(at, 0.35)
		_drop_item(ORE, pos, false)
		_pickups[-1]["weather"] = true
		if player and _flat_distance(player.global_position, pos) < ORE_NOTICE_RANGE:
			notice.emit(Lang.t("Der Blitz schlägt in einen Felsen ein! Daneben glimmt Donnererz."), 3.5)
	return at


## A bright bolt from the sky down to where lightning struck, gone in a blink.
func _show_bolt(at: Vector3) -> void:
	var bolt := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.25
	mesh.bottom_radius = 0.08
	mesh.height = 40.0
	bolt.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.94, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.88, 1.0)
	mat.emission_energy_multiplier = 4.0
	bolt.material_override = mat
	bolt.position = at + Vector3(0, 20.0, 0)
	add_child(bolt)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.8, 0.88, 1.0)
	glow.light_energy = 6.0
	glow.omni_range = 14.0
	glow.position = at + Vector3(0, 2.0, 0)
	add_child(glow)
	var sparks := Effects.make_sparkles(Color(0.8, 0.9, 1.0), true)
	sparks.position = at + Vector3(0, 0.5, 0)
	add_child(sparks)
	var tween := create_tween()
	tween.tween_interval(0.18)
	tween.tween_callback(bolt.queue_free)
	tween.tween_property(glow, "light_energy", 0.0, 0.4)
	tween.tween_callback(glow.queue_free)


## How many lumps of thunder ore lie about right now.
func ore_lying() -> int:
	return _pickups.filter(func(p): return p.get("weather", false)).size()


## The storm has passed: thunder ore nobody picked up fades away.
func _fade_ore() -> void:
	for p in _pickups.duplicate():
		if p.get("weather", false):
			_pickups.erase(p)
			var n: Node3D = p.node
			if is_instance_valid(n):
				var tween := create_tween()
				tween.tween_property(n, "scale", Vector3.ONE * 0.01, 1.2)
				tween.tween_callback(n.queue_free)
