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
##   π  a long dining table with benches and plates of food, where the
##      townsfolk eat together at noon and at seven in the evening (see TownMeals)
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
##      with his living wagon on the tile north of him and the one west of
##      that, and his donkey resting on the tile west of those (see
##      MerchantWagon). Give it open grass, clear of every path and paved way.
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
## The first map row of the farming valley, south of the village.
const VALLEY_FROM := 43
## Tiles anyone can walk on. Everything else is solid.
const WALK := ".,Pai∩:0123456789KOGMYZS¢µöcAXQWHJUDV&£€@'{}-/?¤‖φψχωλκβρΞ≡‡☼"
## Tiles of the robbers' camp: bare, trodden earth.
const CAMP := "NfC"
## The villager who keeps the temple (see _keeper_home): Priestess Elsbeth.
const TEMPLE_KEEPER := "O"
const VILLAGERS := "0123456789KOGMYZS¢µüöφψχωλκβρ"
const BLOCK_CHARS := "RhjnmuskowbE^[])<ßØ"
const BLOCK_MODELS := {
	"R": "crypt", "j": "building_blacksmith_red", "n": "building_tavern_blue",
	"m": "building_market_green", "u": "building_windmill_red",
	"k": "building_castle_blue", "o": "building_home_A_yellow",
	"w": "building_barracks_red", "b": "building_tower_A_blue",
	"[": "building_tavern_blue",
	# The mage tower when its walk-in hall is switched off (see WalkIn.halls): a plain stone tower.
	"Ø": "building_tower_A_blue",
}
const BUILDING_NAMES := {
	"b": "die Bank der Krone", "s": "den Tempel", "k": "das Amt der Krone", "w": "die Abenteurergilde",
	"o": "die Post", "Ø": "den Magierturm", "j": "die Schmiede", "n": "die Schenke Apples & Ivy!", "m": "den Laden",
	"E": "die Drachenhöhle", "[": "die Bergschenke", ")": "den Hort des Großen Alten", "<": "die Aschenzinne",
	"|": "die Ruinen von Sternhall", "\"": "die Verlassene Wüste",
}
## Where the bank's sign post stands from its door: aside (+x) and out into the street (-z).
const BANK_SIGN_SIDE := 1.4
const BANK_SIGN_OUT := 1.1
## Where the smith's sign post stands from the middle of his forge's tile.
const SMITH_SIGN := Vector3(-2.3, 0, 1.7)
## Where the smith's wares stand from the middle of his forge's tile: on the tile west of it.
const SMITH_WARES := Vector3(-3.9, 0, -1.2)
## Where the bank's strongbox stands from its door: to the other side (-x) and out (-z).
const BANK_BOX_SIDE := 2.0
const BANK_BOX_OUT := 0.75
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
## How much of a tree's reach its crown covers on the ground, seen from above; a dead tree's bare
## branches hide far less.
const CROWN := 0.8
const DEAD_CROWN := 0.35
## How far into a forest tile the hero may walk on the leaves in front of its tree (metres):
## less than half a tile, so even a forest one tile thick stays shut.
const FOREST_MARGIN := 1.5
## Undergrowth bushes on the blocked forest floor stand at least this far apart (metres).
const UNDERGROWTH_SPACING := 1.8
## The share of undergrowth bushes that keep their leaves in autumn: the rest have shed them
## (see undergrowth_shed), so the forest edge is not lined with heaps of red and gold leaves, and
## the fallen leaves lie spread over the ground instead (see SurfaceLife.set_autumn).
const UNDERGROWTH_AUTUMN_KEEP := 0.15
## How closely the undergrowth's strip is looked over for bare floor (metres, see _grow_undergrowth).
const UNDERGROWTH_CHECK := 0.5
## The spruces closing the gaps along the forest's edge (see _close_edge_gaps): how far in from the
## open side they stand and how far apart they are looked for (metres).
const EDGE_FILL_DEPTH := 2.3
const EDGE_FILL_STEP := 1.3
## How deep into the forest its gaps are filled with smaller pines (tiles, see _fill_forest_gaps).
const FILL_DEPTH := 3
## How far behind a block's open side its undergrowth grows (metres).
const UNDERGROWTH_DEPTH := 2.0
## The forest's living trees are spruces (see Fern.needle_tree_mesh, _plant_tree). In these tiles of
## Apfeltal, the wood west of the road from the crypt down past the pond, every tree is one.
const SPRUCE_MAP := "Apfeltal"
const SPRUCE_PATCH := Rect2i(0, 14, 14, 26)
## How much of a spruce's reach hides the ground (see CROWN).
const SPRUCE_CROWN := 0.95
## How far off (metres, to the middle of a SPRUCE_CHUNK batch) spruces are drawn frond by frond;
## further off they are the far model of fewer, broader fronds (see Fern.needle_tree_mesh).
const SPRUCE_NEAR := 20.0
## The spruces' batches (tiles square), smaller than GROUND_CHUNK.
const SPRUCE_CHUNK := 4
## Ferns (see Fern.fern_mesh) in the shade along the forest's edge: how many a forest tile beside
## open ground tries for, how far apart they stay and how big they grow (times the model).
const FERN_TRIES := 7
const FERN_SPACING := 1.0
const FERN_SCALE := Vector2(0.45, 0.75)
const FERN_VARIANTS := 4
## How far off a batch of ferns is still drawn (metres).
const FERN_SEEN := 60.0
## Ground pieces are this many tiles across. Each piece is lit by the
## lanterns near it only, so many lanterns can burn at once.
const GROUND_CHUNK := 12
## The ground is drawn in squares of this many tiles. The renderer lights each object with a
## limited set of the lights that touch it, so one big square put a hard, straight edge of
## different lighting across the snow where its lamps and lanterns were cut off; small squares
## see few lights each, and their lighting changes in small steps nobody notices.
const GROUND_PIECE := 4
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
## The wall lamps beside the door (kit metres, measured from doorway_01 and wall_01): the door
## opening is 4 wide around x = 0 and its jambs reach out to 2.5, so the lamps stand 3.5 either side of
## the middle (x), at 8.8 high (y, up from 5.5 by 60%, towards the top of the door frame) on the
## front wall's face, flush with it (z = 11 + the wall's 1).
const TEMPLE_LAMP_X := [-3.5, 3.5]
const TEMPLE_LAMP_Y := 8.8
const TEMPLE_LAMP_Z := 12.0
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
const CHAPEL_GLASS_LIGHT := Color(0.9, 0.8, 0.64)
## How strongly the temple's windows shine by day (a fraction of the night's glow),
## and how much of its night strength the coloured picture on the lawn keeps at high noon
## (half; it fades in and out with the daylight).
## From how far above the ground the temple's surfaces carry a cap of snow: low enough for the
## treads of its front steps (other buildings start at SnowCaps.LOWEST, which skips doorsteps).
const TEMPLE_STEP_SNOW := 0.05
const CHAPEL_DAY_GLOW := 0.45
const CHAPEL_DAY_SPILL := 0.5
## How far either side of the temple's door (metres) its front keeps free of mossy stones: its steps.
const TEMPLE_STEPS_CLEAR := 1.65

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
## The trees on each forest tile near the open ground, each {"at", "crown"}: where it stands and
## how far round it its crown hides the ground (metres, see _build_forest).
var forest_trees := {}
## How many ferns grow along the forest's edge (see _grow_ferns).
var fern_count := 0
## Where the last tree _build_tree planted stands, and how far its crown reaches.
var _tree_at := Vector3.ZERO
var _tree_crown := 0.0
## How many spruces close the gaps along the forest's edge (see _close_edge_gaps).
var edge_fillers := 0
## Whether the last tree _plant_tree planted was a spruce, and how big (see _spruce_size).
var _last_spruce := false
var _last_spruce_size := 1.0
## Where the undergrowth bushes stand, each Vector4(x, y, z, radius) (see _grow_undergrowth).
var undergrowth_bushes: Array[Vector4] = []
## Where the village's shrubs stand (see _plant_bushes).
var shrubs: Array[Vector3] = []
## Where Benno's tent stands (ZERO: not looked up yet, INF: none), see _near_barber.
var _barber_tent := Vector3.ZERO
## The season's stage the trees' leaves were last dressed for (see set_season, IvySeasons.stage).
var _tree_stage := IvySeasons.SUMMER
## The birds and squirrels of the woods (see WoodsLife).
var woods: WoodsLife
## The glowworm swarms that roam the night (see GlowwormSwarms).
var glowworms: GlowwormSwarms
## The bee hives of the valley with their bees and flower meadow (see Apiary), and the tiles they stand on.
var apiary: Apiary
var _hive_cells: Array[Vector2i] = []
## The owls on the branches of the woods (see Owls).
var owls: Owls
## Owlav's grave (INF when the map has none) and what stands in front of it once its crypt is open, and
## the dead tree whose owl strikes the hours (see OwlClock).
var owlav_pos := Vector3.INF
var owlav_parts: Node3D
var owl_tree_at := Vector3.INF
## The peaceful animals of the woods (see Animal).
var animals: Array[Animal] = []
## The village's geese, goats and dogs (see VillageFarm and FarmAnimal).
var farm_animals: Array[FarmAnimal] = []
## The herald's call to arms against slimes in the village (see VillageAlarm).
var village_alarm := VillageAlarm.new()
## The shared lunch and dinner at the tables on the square (see TownMeals).
var meals := TownMeals.new()
## Idle townsfolk resting on the benches round the fountain (see BenchRest).
var bench_rest := BenchRest.new()
## Benno's chair beside his tent: the hero's haircuts, and now and then a villager (see BarberChair).
var barber_chair := BarberChair.new()
## The morning gathering in the temple (see TempleMorning).
var temple_morning := TempleMorning.new()
## Buried rooms far from the hero stop casting shadows (see UndergroundShadows).
var underground_shadows := UndergroundShadows.new()
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
var spots := {"houses": [], "square": [], "well": [], "market": [], "fountain": []}
## The door spots of houses that belong to one villager alone (see SmithCottage), by role: they go
## home to theirs at night, and nobody else does.
var own_homes := {}
## The holes in the ground under the halls with a cellar (the guildhall's, see GuildHall): Rect2
## of x, z on the 2 m lattice, cut open with the house cellars' (see HouseSketcher._redraw).
var hall_holes: Array = []
## The village houses' chimneys: each house's door spot (as in spots.houses)
## and the plume of smoke over its roof (see ChimneySmoke).
var chimneys: Array[Dictionary] = []
## The narrow town houses of Weavers' Lane, by number - 1 (see _build_terrace).
var town_houses: Array[Node3D] = []
## The windmills (see "u" and Windmill), whose sails turn in the wind.
var windmills: Array[Windmill] = []

var _plants := {}
## How far each planted tree reaches out from its trunk (metres), beside _plants.
var _plant_reach := {}
## The tree batches drawn from _plants, by the same key (see clear_plot).
var _plant_batches := {}
## The meshes of each tree model, by name.
var _plant_parts := {}
## The building plots on this map (see Plots), in metres on the ground: no tree,
## boulder or mountain slope reaches into them.
var _plot_areas: Array[Rect2] = []
## Things beside the open ground that a plot registered later may clear away:
## {"at", "reach", "nodes"} (see clear_plot).
var _clearable: Array[Dictionary] = []
## The meshes of the mountains, built again when a plot beside them is registered.
var _mountain_nodes: Array = []
var _house_rect := Rect2i()
var _door_cell := Vector2i(-1, -1)
var _roof: Node3D
## The south walls of the house: full height, but see-through in front of
## the hero while the hero is inside (see WallFade).
var _house_fade := WallFade.new()
var _inside := false
## Whether the hero stands inside a house (built or their own), seeing out only
## through windows and open doors (see hero_sees). Set each frame.
var hero_indoors := false
## The day Elsbeth last thawed frozen Fritz with a spell: he stays thawed for the rest of it (see BlessRound).
var fritz_thawed_day := -1
## The dug cells (Rect2 of x, z) of the house cellar the hero is down in, empty while they are
## not: from down there they see only what is in the cellar (see CellarView, hero_sees).
var hero_cellar: Array = []
## Every cell of every house cellar (Rect2 of x, z, see set_floor_holes): no lightning strikes there.
var _cellar_holes: Array = []
var _inside_view := InsideView.new()
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
## The village buildings one can walk into: the villagers' houses and the temple (see WalkIn).
var walk_in: WalkIn
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
## Where the birds perch on the street lamps in winter: the top of each post and two spots on its arm.
var _lamp_perches: Array[Vector3] = []
## Every street lamp on a map tile: {"foot": its post, "arm": the flat unit direction its arm reaches,
## "walkway": the offset in tiles to the nearest walkway or zero}. For the tests.
var lamp_spots: Array[Dictionary] = []
## How many tiles round a street lamp to look for a walkway to turn its arm towards, and how far from
## the walkway's edge its post stands (m).
const LAMP_SEEK := 6
const LAMP_EDGE_GAP := 0.9
## Where a street lamp's light hangs over its foot: the middle of its lantern's glass.
const LAMP_LIGHT_AT := VillageProps.LANTERN_AT - Vector3(0, 0.03, 0)
## The bandits' campfires light up their camp at night too.
var _fires: Array[Vector3] = []
## The fireplaces, candle stands and torches in the self-built houses (see HouseFurnisher): their
## light shows the hero at night like a lantern's.
var house_lights: Array[Vector3] = []
## What the self-built houses close in (see HouseGround.shelter), set by HouseSketcher: the hero in
## there is indoors (see is_sheltered).
var shelters := {}:
	set(value):
		shelters = value
## The part of `shelters` under a slab or a roof (see HouseGround.roofed): only there the weather
## stays out (no rain, snow or fog falls in, see IndoorMask and is_roofed); a yard closed in only by
## walls is open to the sky. No snow settles under a roof either (see SnowCover.set_shelter). Set by
## HouseSketcher before `shelters`.
var roofs := {}:
	set(value):
		roofs = value
		IndoorMask.mark()
		if snow != null:
			snow.set_shelter(roofs, width, height, TILE)
## The cells (see HouseGround.cell_at) over a house's cellar: dug cells and the cells of the cellar stairs,
## also those beyond the roof. Below the ground there no weather shows (see IndoorMask).
var pits := {}:
	set(value):
		pits = value
		IndoorMask.mark()
## Where something burns (campfires, the forge, smoking chimneys): xyz and how far round it no snow
## settles (see SnowCover.set_warm).
var warm_spots: Array[Vector4] = []
## The fires of the smithy model (building_blacksmith_red): the logs in the furnace's mouth and the
## fire on top of its chimney, in the model's own frame, with how far round them it is warm.
const SMITHY_FIRES: Array[Vector4] = [Vector4(0.22, 0.14, 0.24, 0.24), Vector4(0.21, 0.91, -0.14, 0.14)]
## The village cat that naps on the barrel by the smithy's stacked granite blocks (null when there is
## none, see _adopt_cat).
var village_cat: VillageCat
var _smithy_node: Node3D
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
## All the leaves, stems and grapes of the village (AgedStone.ivy_node), dressed for the season
## (see set_season).
var ivy: Node3D
## The grass, flowers and mossy stones at the foot of the buildings (see WallFoot), and what grew
## there while the village was built.
var wall_foot: Node3D
var _fringe := {}
## The buildings' outlines on the ground, by tile (see _add_footprint).
var _footprints := {}
## The undergrowth on the forest floor that stays blocked between the edge trees (see
## _build_wall_collision): low bushes of the ivy's leaves, turning with the seasons as the ivy does.
var undergrowth: Node3D
var _undergrowth := {"xforms": [], "colours": []}
## The undergrowth bushes and village shrubs that shed their leaves in autumn (hidden then, see
## UNDERGROWTH_AUTUMN_KEEP and SHRUB_AUTUMN_KEEP); the rest of the year they grow as the others do.
var undergrowth_shed: Node3D
var _undergrowth_shed := {"xforms": [], "colours": []}
## The kinds of the last bushes planted, so neighbours differ (see BushKinds.pick).
var _bush_recent: Array = []
var nests: Array[Vector3] = []
var birds: VillageBirds
## The dragon that now and then flies over, seen only as its shadow.
var flyover: DragonFlyover
var _entrances: Array = []
var _ground_img: Image
## The flower beds in the valley's lane (see FlowerBeds): where they are, and the beds themselves.
var bed_spots: Array[Vector3] = []
var flower_beds: FlowerBeds
var _ground_tex: ImageTexture
## How far each spot lies from the pond banks (see _build_shore and pond_shore_at).
var _shore_img: Image
var _shore_tex: ImageTexture
var _village_near := {}
var _village_middle := Vector2(-1, -1)
## What the dressing found for each building (see _dress_building), kept
## for the session.
static var _dressed := {}
## While the village is built, the dressings are collected and grown on worker threads (see _dress_building).
var _dress_batch := false
var _dress_queue: Array = []
var _dress_keys := {}
## Nests at most, and how likely one of Weavers' Lane's town houses gets ivy
## and a nest (the other buildings all have ivy, and most of them a nest).
const MAX_NESTS := 10
const LANE_NEST := 0.15
## Ivy patches on each town house of Weavers' Lane (narrow, many of them).
const LANE_PATCHES := 3
## Dirt paths this close to a village building (tiles) are cobbled like the
## square, and shrubs grow on the grass beside the buildings.
const VILLAGE_REACH := 6
## Where the stonemason's yard of stone blocks lies, from the tile he stands on: to the
## right of his house (as you face its door), past the paved way from the door, so
## neither the doorway nor the way is blocked.
const MASON_YARD := Vector2i(2, -2)
## How far the yard sits east within its tile, clear of the paved way's edge. The pile
## and its solid stay inside the tile, so villagers walking round it are not caught.
const MASON_YARD_SHIFT := 0.4
const VILLAGE_BLOCKS := "hjnmuskowb^["
const BUSH_CHANCE := 0.8
const BUSH_OPEN := 0.3
## How much taller than wide Benno's tent is drawn, and how far round it no shrub grows (metres).
const BARBER_CLEAR := 7.0
## The share of these shrubs that keep their leaves in autumn (the rest shed them, see
## undergrowth_shed), and fewer still within SHRUB_TEMPLE_REACH tiles of the temple.
const SHRUB_AUTUMN_KEEP := 0.5
const SHRUB_TEMPLE_KEEP := 0.25
const SHRUB_TEMPLE_REACH := 3
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
## The season day the world is on (see Seasons, Game.season_day, set_season): what winter, autumn
## and the flowers in the gardens go by.
var season_day := 0
## The fields of the farming valley (see CropFields) and the middles of their tiles by letter.
var crop_fields: CropFields
## The middle of the farming valley's fields: the field tile nearest to their common centre, or
## `fallback` when the map has no fields (see CropFields). Where the testing panel's farms button goes.
func farm_spot(fallback: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for letter: String in _crop_cells:
		for mid: Vector3 in _crop_cells[letter]:
			sum += mid
			n += 1
	if n == 0:
		return fallback
	var centre := sum / n
	var best := fallback
	var best_d := INF
	for letter: String in _crop_cells:
		for mid: Vector3 in _crop_cells[letter]:
			var d := mid.distance_squared_to(centre)
			if d < best_d:
				best_d = d
				best = mid
	return best


## The crows that peck on the fields in autumn and winter (see Crows).
var crows: Crows
## Spooknortz's nights in the village (see SpookRaid).
var spook_raid: SpookRaid
## The small funny happenings in the valley (see ValleyEvents).
var valley_events: ValleyEvents
## The sunflower riddle in the field with the scarecrow (see SunflowerRiddle).
var sunflower_riddle: SunflowerRiddle
## The spirit that rises at midnight from the unknown grave (see GraveSpirit), null without those graves.
var grave_spirit: GraveSpirit
## The safety coffin with its bell (see BellGrave), null without it.
var bell_grave: BellGrave
var _crop_cells := {}
## The village's apple trees: round the fountain and in the gardens (see AppleTree.plant_round_fountains, plant_in_village).
var square_trees: Array = []
## The few more apple trees that explain the fallen leaves (see AppleTree.plant_for_leaves). They are not
## the hedgehogs' apple trees, so those runs stay as they were.
var leaf_trees: Array = []
## Whether the village wears its winter clothes (see WinterWear), set by Game from the day and the
## hour: the clothes change in the night, so the village is asleep when they do.
var winter_wear := false
var _wear_known := false
## "winter" or "spring" on the first morning of a season, until the villagers have had their say
## about it (see Villager.season_remark), and the world hour it lasts until.
var season_talk := ""
var season_talk_until := 0.0
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
## sight). Slimes love bad weather: in spring they crawl out of the pond in
## the rain, the storm and the fog, and only then (see SlimeGrowth.may_crawl).
const WEATHER_FOES := {
	Weather.RAIN: [{"kind": "schleim", "count": 12, "near": "~"}],
	Weather.FOG: [{"kind": "fog_wraith", "count": 6, "near": "d"}, {"kind": "schleim", "count": 8, "near": "~"}],
	Weather.STORM: [{"kind": "fledermaus", "count": 5, "near": "r"}, {"kind": "schleim", "count": 8, "near": "~"}],
}
const WEATHER_RESPAWN := 80.0
## Slimes retreat to the pond when the spring weather clears (see SlimeLife);
## at most this many crawl about.
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
## The layer of snow on every surface that faces the sky (see SnowCover).
var snow: SnowCover
## How thickly the ponds are frozen over, 0 open water to 1 solid ice (see IceCover).
var ice := 0.0
var ice_cover: IceCover
## Fish swimming under the ice, built the first time the water freezes (see set_ice).
var ice_fish: IceFish
## The river's spring (see Waterfall), built by its letter.
var waterfall: Waterfall
## The snow dust the herald's broom kicks up (see SweepDust), made when he first sweeps.
var sweep_dust: SweepDust

## Reeds and cattails round the ponds, with their caps of snow (see PondReeds).
var pond_reeds: PondReeds
## The frogs at the water, built with the reeds (see PondFrogs).
var pond_frogs: PondFrogs
## The fireflies, gnats and butterflies and the chirps of the night (see InsectLife).
var insect_life: InsectLife
## Every pond tile (see IceCover).
var _pond_waters: Array = []
var _ground_mat: ShaderMaterial
## The ground's collision: an endless plane, or while there are holes in the
## ground (see set_floor_holes) a thick slab of boxes around them.
var _floor_shape: CollisionShape3D
var _floor_slabs := StaticBody3D.new()
## The snowman Pip and Pippi build in the snow (see Snowman), or null.
var snowman: Snowman
## Outlines on the ground (x, z) where no patch of dirt, moss or lichen lies: the temple
## glass's light on the lawn (see ChapelSpill), which a patch drawn over it would hide.
var bare_ground: Array[PackedVector2Array] = []
## The leaves, twigs and pebbles on the ground (see SurfaceLife).
var surface_life: SurfaceLife
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
	_plot_areas.clear()
	_crop_cells.clear()
	for deed in Plots.all():
		_plot_areas.append(plot_area(deed.rect))
	_build_ground()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			_build_outdoor_cell(c, cell_char(c))
	_build_blocks()
	_plant_crops()
	if Corral.present(self):
		Corral.build_props(self)
		if Corral.has_shelter(self):
			Corral.build_shelter(self)
	_pave_entrances()
	_plant_bushes()
	# The ivy-covered poles and ropes with their lamps round the dining tables (see MealGarland).
	meals.garland.build(self, meals.tables, _ivy)
	# The braziers that warm the diners in winter (see MealBraziers).
	meals.braziers.build(self, meals.tables)
	# The tavern's pub sign on a post south of the two dining tents (see PubSign).
	_square_pub_sign()
	# No leaf covers any door, whichever building grew it.
	AgedStone.clear_doors(_ivy, _entrances)
	if BushKinds.has_any(_ivy):
		ivy = AgedStone.ivy_node(_ivy)
		add_child(ivy)
		if walk_in != null:
			walk_in.plant_ivy(ivy)
		IvySeasons.apply(ivy, day)
	# Grass, flowers and mossy stones at the foot of the buildings (see WallFoot).
	WallFoot.keep_open(_fringe, func(at: Vector3, stone: bool) -> bool: return _fringe_ground(at, stone or _in_forecourt(at)))
	if not _fringe.is_empty():
		wall_foot = WallFoot.node(_fringe)
		add_child(wall_foot)
		WallFoot.apply(wall_foot, day)
	# Apple trees round the fountain, between the benches (before the birds take the square's spots).
	square_trees = AppleTree.plant_round_fountains(self)
	# And more in the gardens round the houses.
	square_trees.append_array(AppleTree.plant_in_village(self))
	# And one in each grass pocket framed by paths.
	square_trees.append_array(AppleTree.plant_in_pockets(self, square_trees))
	# And a few more, spread over the ground the autumn leaves cover, so they have a tree to come from.
	leaf_trees = AppleTree.plant_for_leaves(self, square_trees)
	# The trees grow on the worker threads while the mountains are built (see AppleTree.dress_begin).
	var dressing := AppleTree.dress_begin(square_trees + leaf_trees, day)
	# The flower beds in the paved lane of the valley.
	if not bed_spots.is_empty():
		flower_beds = FlowerBeds.grow(self, bed_spots, hash(level_name + "beete"))
		flower_beds.set_season(day)
	if not nests.is_empty():
		var pecking: Array[Vector3] = []
		pecking.assign(spots.square)
		var market: Array[Vector3] = []
		market.assign(spots.market)
		birds = VillageBirds.new(self, nests, pecking, market, hash(level_name + "voegel"))
		# In winter they sit about on the lamp posts: the top of the post and its arm (see _build_lantern).
		birds.winter_perches.append_array(_lamp_perches)
		add_child(birds)
	_mountain_nodes = Mountains.build(self, hash(level_name + "berge"), _plot_areas)
	MountainFoot.apply(self)
	MountainFoot.scatter(self)
	AppleTree.dress_end(dressing)
	if waterfall != null:
		waterfall.lay_water(self)
	_build_forest()
	_build_house()
	_build_wall_collision()
	_grow_ferns()
	RiverFlow.build(self)
	if BushKinds.has_any(_undergrowth):
		undergrowth = AgedStone.ivy_node(_undergrowth)
		undergrowth.name = "Undergrowth"
		add_child(undergrowth)
		IvySeasons.apply(undergrowth, day)
	if BushKinds.has_any(_undergrowth_shed):
		undergrowth_shed = AgedStone.ivy_node(_undergrowth_shed)
		undergrowth_shed.name = "UndergrowthShed"
		add_child(undergrowth_shed)
		IvySeasons.apply(undergrowth_shed, day)
	_build_rock_collision()
	SummitGarden.build(self)
	Nohpaan.place_door(self)
	_setup_astar()
	meals.garland.block(self)
	GlowMushrooms.build(self)
	if birds:
		# Not where the fountain, a bench or a stall stands.
		var free: Array[Vector3] = []
		free.assign(birds.market.filter(func(m: Vector3): return is_open(world_to_cell(m))))
		birds.market = free
	_flush_plants()
	_build_woods_life()
	# The village's hedgehogs fetch apples from its apple trees (see WoodsLife.assign_hoards).
	woods.assign_hoards.call_deferred(square_trees)
	# Leaves, twigs, rubble and little crawling creatures on the ground.
	surface_life = SurfaceLife.new(self)
	surface_life.set_autumn(Weather.is_autumn(season_day))
	add_child(surface_life)
	puddles = Puddles.new(self, hash(level_name + "pfuetzen"))
	add_child(puddles)
	pond_reeds = PondReeds.grow(self, _pond_waters)
	if not _pond_waters.is_empty():
		pond_frogs = PondFrogs.grow(self, _pond_waters)
	insect_life = InsectLife.grow(self, _pond_waters)
	ice_cover = IceCover.new(self, _pond_waters, _ground_mat)
	snow = SnowCover.new(self)
	var roofed: Array = []
	for hy in range(_house_rect.position.y, _house_rect.end.y):
		for hx in range(_house_rect.position.x, _house_rect.end.x):
			roofed.append(Vector2i(hx, hy))
	if Corral.has_shelter(self):
		for sy in range(Corral.SHELTER.position.y, Corral.SHELTER.end.y):
			for sx in range(Corral.SHELTER.position.x, Corral.SHELTER.end.x):
				roofed.append(Vector2i(sx, sy))
	roofed.append_array(meals.roofed)
	# The rooms of the buildings one walks into (see WalkIn): no snow on their floors and furniture,
	# which the camera sees once their roof is lifted off. A house's own walls bound that (see
	# walk_in_room), so the yard round it on its block snows over like the rest; the temple's nave
	# its walls (see temple_room); a building without a known shape keeps its whole block clear.
	var rooms: Array = []
	for rec in walk_in.buildings:
		var room := walk_in_room(rec.node)
		if room.has_area():
			# Both storeys, up to the eaves: the upper floor is a room too (the roof above takes snow).
			rooms.append([room, WALK_IN_CEILING, VillageHouse.JETTY, VillageHouse.PLINTH + VillageHouse.GROUND - 0.1])
			continue
		if rec.kind == "temple":
			var nave := temple_room(rec.node)
			rooms.append([nave, (WalkIn.NAVE_WALL - 0.2) * (rec.node as Node3D).scale.y])
			continue
		var block: Rect2i = rec.block
		for by in range(block.position.y, block.end.y):
			for bx in range(block.position.x, block.end.x):
				roofed.append(Vector2i(bx, by))
	snow.set_rooms(rooms, width, height, TILE)
	snow.set_sky_mask(roofed, width, height, TILE, _pond_waters.map(func(w: Dictionary) -> Vector2i: return w.cell))
	snow.set_shore(_shore_tex, SHORE_REACH)
	snow.set_warm(warm_spots)
	snow.set_shelter(roofs, width, height, TILE)
	snow.set_awnings(meals.awnings)
	# The footpaths the herald swept stay swept when the village is built again (see SnowSweep).
	SnowSweep.attach(self)
	_floor_shape = CollisionShape3D.new()
	_floor_shape.shape = WorldBoundaryShape3D.new()
	_walls_body.add_child(_floor_shape)
	_spawn_villagers()
	_adopt_cat()
	_build_war_horn()
	_spawn_wild()
	_spawn_animals()
	farm_animals = VillageFarm.spawn(self)
	valley_events = ValleyEvents.new()
	add_child(valley_events)
	valley_events.setup(self)
	if _crop_cells.has(CropFields.RIDDLE):
		sunflower_riddle = SunflowerRiddle.new()
		add_child(sunflower_riddle)
		sunflower_riddle.setup(self)
	var spirit_graves := GraveSpirit.graves_of(level_name)
	if not spirit_graves.is_empty():
		grave_spirit = GraveSpirit.new()
		add_child(grave_spirit)
		grave_spirit.setup(self, cell_to_world(spirit_graves.unknown))
	if not BellGrave.graves_of(level_name).is_empty():
		bell_grave = BellGrave.new()
		add_child(bell_grave)
		bell_grave.setup(self, level_name)
	spook_raid = SpookRaid.new()
	add_child(spook_raid)
	spook_raid.setup(self)
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
	var scree := {}
	var fence := _bounds_of("z")
	var square := _bounds_of(":")
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			var path := 1.0 if ",aP\\ΞΘ".contains(ch) else 0.0
			var soil := 1.0 if (fence.has_point(c) and not ",aP\\".contains(ch)) or ch == "y" or CropFields.LETTERS.contains(ch) or CAMP.contains(ch) else 0.0
			# Paving stones: path and soil together mean the square.
			if square.has_point(c) and not BLOCK_CHARS.contains(ch):
				path = 1.0
				soil = 1.0
			var wet := 1.0 if "~;≈‖".contains(ch) else 0.0
			var open := 0.0 if ch == "#" else 1.0
			mask.set_pixel(x, y, Color(path, soil, wet, open))
			# Scree on the mountain ground, and at the foot of the rock.
			if "'=]{}-/".contains(ch):
				scree[Vector2i(x, y)] = true
	# A smoother mask gives softer edges between the tiles.
	mask.resize(width * 4, height * 4, Image.INTERPOLATE_BILINEAR)
	_ground_img = mask
	_ground_tex = ImageTexture.create_from_image(mask)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/meadow.gdshader")
	_ground_mat = mat
	mat.set_shader_parameter("ground_mask", _ground_tex)
	mat.set_shader_parameter("stone_mask", ImageTexture.create_from_image(_distance_field(scree, SCREE_REACH)))
	mat.set_shader_parameter("stone_reach", SCREE_REACH)
	mat.set_shader_parameter("grid_size", Vector2(width, height))
	mat.set_shader_parameter("tile", TILE)
	_shore_img = _build_shore()
	_shore_tex = ImageTexture.create_from_image(_shore_img)
	mat.set_shader_parameter("shore_mask", _shore_tex)
	mat.set_shader_parameter("shore_reach", SHORE_REACH)
	mat.set_shader_parameter("shore_on", true)
	# The graveyard's paving is older than the village's (see _pave_graveyard).
	if fence.size != Vector2i.ZERO:
		mat.set_shader_parameter("old_paving", Vector4((fence.position.x - 0.5) * TILE, (fence.position.y - 0.5) * TILE,
				(fence.end.x - 0.5) * TILE, (fence.end.y - 0.5) * TILE))
	var margin := 10
	var size := GROUND_PIECE * TILE
	for cy in range(-margin, height + margin, GROUND_PIECE):
		for cx in range(-margin, width + margin, GROUND_PIECE):
			var plane := PlaneMesh.new()
			plane.size = Vector2(size, size)
			var piece := MeshInstance3D.new()
			piece.mesh = plane
			piece.material_override = mat
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# The candles of the village's houses do not light the ground outside (see LightShadows.GROUND).
			piece.set_meta(LightShadows.GROUND, true)
			piece.position = Vector3((cx - 0.5) * TILE + size * 0.5, 0, (cy - 0.5) * TILE + size * 0.5)
			add_child(piece)


## Pixels per tile of the shore picture, and how far from the bank (metres) it tells apart.
const SHORE_PX := 4
## How far (metres) the scree's distance picture reaches (see _distance_field).
const SCREE_REACH := 6.0
const SHORE_REACH := 8.0


## The ponds' shore as one picture over the whole map, SHORE_PX pixels to a tile: how far each
## spot lies from the nearest bank, 0.5 on the bank itself, more out over the water and less on
## dry land (0 from SHORE_REACH away). The ground shader draws the water, the shallows, the muddy
## bank and the depth from it, so the shore runs round the pond tiles in soft curves (and only a
## little noise away from where they stop the hero), never along their square corners.
func _build_shore() -> Image:
	var img := Image.create(width * SHORE_PX, height * SHORE_PX, false, Image.FORMAT_RH)
	var water := {}
	for y in height:
		for x in width:
			if "~;≈‖".contains(cell_char(Vector2i(x, y))):
				water[Vector2i(x, y)] = true
	if water.is_empty():
		return img
	# Each pond on its own: the tiles that touch, and a margin round them.
	var seen := {}
	var areas: Array[Rect2i] = []
	for start: Vector2i in water:
		if seen.has(start):
			continue
		var box := Rect2i(start, Vector2i.ONE)
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			box = box.expand(at).expand(at + Vector2i.ONE)
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if water.has(at + dir) and not seen.has(at + dir):
					seen[at + dir] = true
					queue.append(at + dir)
		areas.append(box.grow(3))
	var raw := {}
	for box in areas:
		for py in range(box.position.y * SHORE_PX, box.end.y * SHORE_PX):
			for px in range(box.position.x * SHORE_PX, box.end.x * SHORE_PX):
				var spot := Vector2((px + 0.5) / SHORE_PX - 0.5, (py + 0.5) / SHORE_PX - 0.5) * TILE
				raw[Vector2i(px, py)] = _shore_distance(spot, water)
	# Softened twice, so the bays round off as well as the points.
	for _round in 2:
		var soft := {}
		for at: Vector2i in raw:
			var sum := 0.0
			var count := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var v = raw.get(at + Vector2i(dx, dy))
					if v != null:
						sum += v
						count += 1
			soft[at] = sum / count
		raw = soft
	for at: Vector2i in raw:
		if at.x >= 0 and at.y >= 0 and at.x < img.get_width() and at.y < img.get_height():
			img.set_pixel(at.x, at.y, Color(clampf(0.5 + raw[at] / (2.0 * SHORE_REACH), 0.0, 1.0), 0, 0))
	return img


## Like the shore: a picture over the map, SHORE_PX pixels to a tile, of how far each spot lies from the nearest tile
## in `cells` (minus inside them, plus outside), 0.5 on the edge, softened twice. The ground shader reads it through a
## little noise, so the edge of the scree runs in soft curves and never along the tiles.
func _distance_field(cells: Dictionary, reach: float) -> Image:
	var img := Image.create(width * SHORE_PX, height * SHORE_PX, false, Image.FORMAT_RH)
	img.fill(Color(1, 0, 0))
	if cells.is_empty():
		return img
	var raw := {}
	var seen := {}
	for c: Vector2i in cells:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var t := c + Vector2i(dx, dy)
				if seen.has(t) or t.x < 0 or t.y < 0 or t.x >= width or t.y >= height:
					continue
				seen[t] = true
				for py in SHORE_PX:
					for px in SHORE_PX:
						var spot := Vector2(t.x + (px + 0.5) / SHORE_PX - 0.5, t.y + (py + 0.5) / SHORE_PX - 0.5) * TILE
						var inside := cells.has(t)
						var best := reach
						for ey in range(-2, 3):
							for ex in range(-2, 3):
								var o := t + Vector2i(ex, ey)
								if cells.has(o) == inside:
									continue
								var near := Vector2(clampf(spot.x, (o.x - 0.5) * TILE, (o.x + 0.5) * TILE),
										clampf(spot.y, (o.y - 0.5) * TILE, (o.y + 0.5) * TILE))
								best = minf(best, spot.distance_to(near))
						raw[Vector2i(t.x * SHORE_PX + px, t.y * SHORE_PX + py)] = -best if inside else best
	for _round in 2:
		var soft := {}
		for at: Vector2i in raw:
			var sum := 0.0
			var count := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var v = raw.get(at + Vector2i(dx, dy))
					if v != null:
						sum += v
						count += 1
			soft[at] = sum / count
		raw = soft
	for at: Vector2i in raw:
		img.set_pixel(at.x, at.y, Color(clampf(0.5 + raw[at] / (2.0 * reach), 0.0, 1.0), 0, 0))
	return img


## How far `spot` (world x and z) lies from the nearest bank in metres: plus over the water,
## minus on land, the pond tiles in `water`.
func _shore_distance(spot: Vector2, water: Dictionary) -> float:
	var cell := Vector2i(floori(spot.x / TILE + 0.5), floori(spot.y / TILE + 0.5))
	var wet := water.has(cell)
	var best := SHORE_REACH
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var other := cell + Vector2i(dx, dy)
			if water.has(other) == wet:
				continue
			var near := Vector2(clampf(spot.x, (other.x - 0.5) * TILE, (other.x + 0.5) * TILE),
					clampf(spot.y, (other.y - 0.5) * TILE, (other.y + 0.5) * TILE))
			best = minf(best, spot.distance_to(near))
	return best if wet else -best


## How far `pos` lies from the nearest pond bank as the ground draws it, in metres: plus over
## the water, minus on dry land (see _build_shore; without the shader's bit of noise).
func pond_shore_at(pos: Vector3) -> float:
	if _shore_img == null:
		return -SHORE_REACH
	var f := Vector2(pos.x / TILE + 0.5, pos.z / TILE + 0.5) * SHORE_PX - Vector2(0.5, 0.5)
	var i := Vector2i(floori(f.x), floori(f.y))
	var t := f - Vector2(i)
	var w := _shore_img.get_width() - 1
	var h := _shore_img.get_height() - 1
	var at := func(x: int, y: int) -> float: return _shore_img.get_pixel(clampi(x, 0, w), clampi(y, 0, h)).r
	var v: float = lerpf(lerpf(at.call(i.x, i.y), at.call(i.x + 1, i.y), t.x),
			lerpf(at.call(i.x, i.y + 1), at.call(i.x + 1, i.y + 1), t.x), t.y)
	return (v - 0.5) * 2.0 * SHORE_REACH


## How far the slab round the holes reaches beyond the map (metres), and how
## thick it is.
const SLAB_REACH := 120.0
const SLAB_THICK := 8.0
## The side of the lattice the holes lie on (a house's grid cell, metres).
const HOLE_CELL := 2.0


## Opens holes in the ground (a player's cellar): `holes` are Rect2 in world
## x/z, each on the 2 m lattice of the map (see HouseSketch.CELL). The ground is
## not drawn there and the hero can fall in; with no holes everything is as
## before. Walkable floors inside the holes are the cellar's own business.
## `floored` are the holes closed over by a cellar ceiling (see HouseSketch.COVER):
## still cut open, but litter, snow and dropped things lie on them as on the ground.
## `buried` are the holes under whole ground (HouseSketch.BURIED, the forgotten mine's
## tunnels, see LostMine): only the ground's thick slab is taken out under them; the
## ground is drawn and snowed on there as anywhere.
func set_floor_holes(holes: Array, floored: Array = [], buried: Array = []) -> void:
	if _floor_slabs.get_parent() == null:
		_walls_body.add_child(_floor_slabs)
	# Taken out of the body at once and freed at the end of the frame, never freed right away:
	# the redraw can come while the physics step still holds contacts with these shapes.
	for child in _floor_slabs.get_children():
		_floor_slabs.remove_child(child)
		child.queue_free()
	var plane := _floor_shape.shape as WorldBoundaryShape3D
	# The picture: a mask with a pixel for each 2 m cell of the map.
	var mask := Image.create(width * 2, height * 2, false, Image.FORMAT_R8)
	var lattice := {}
	var closed := {}
	for r: Rect2 in floored:
		closed[Vector2i(roundi((r.position.x + TILE * 0.5) / HOLE_CELL), roundi((r.position.y + TILE * 0.5) / HOLE_CELL))] = true
	var whole := {}
	for r: Rect2 in buried:
		whole[Vector2i(roundi((r.position.x + TILE * 0.5) / HOLE_CELL), roundi((r.position.y + TILE * 0.5) / HOLE_CELL))] = true
	# Open to the sky (see open_sky): not where whole ground lies over a hole.
	_cellar_holes = holes.filter(func(r: Rect2) -> bool: return not whole.has(Vector2i(roundi((r.position.x + TILE * 0.5) / HOLE_CELL), roundi((r.position.y + TILE * 0.5) / HOLE_CELL))))
	# Where the cellar lies open to the sky, and the cells nothing may lie on. The snow's mask is 1
	# on an open cell and half on a closed one: snow lies on the ceiling but not in the cellar under it.
	var snow_mask := Image.create(width * 2, height * 2, false, Image.FORMAT_R8)
	var open_lattice := {}
	var open_holes := []
	for r: Rect2 in holes:
		if not closed.has(Vector2i(roundi((r.position.x + TILE * 0.5) / HOLE_CELL), roundi((r.position.y + TILE * 0.5) / HOLE_CELL))):
			open_holes.append(r)
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for r: Rect2 in holes:
		var first := Vector2i(roundi((r.position.x + TILE * 0.5) / HOLE_CELL), roundi((r.position.y + TILE * 0.5) / HOLE_CELL))
		var cells := Vector2i(roundi(r.size.x / HOLE_CELL), roundi(r.size.y / HOLE_CELL))
		for y in range(first.y, first.y + cells.y):
			for x in range(first.x, first.x + cells.x):
				lattice[Vector2i(x, y)] = true
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
				if not closed.has(Vector2i(x, y)):
					open_lattice[Vector2i(x, y)] = true
				if x >= 0 and y >= 0 and x < width * 2 and y < height * 2 and not whole.has(Vector2i(x, y)):
					mask.set_pixel(x, y, Color(1, 0, 0, 1))
					snow_mask.set_pixel(x, y, Color(0.5 if closed.has(Vector2i(x, y)) else 1.0, 0, 0, 1))
	if _ground_mat != null:
		_ground_mat.set_shader_parameter("hole_mask", ImageTexture.create_from_image(mask))
		_ground_mat.set_shader_parameter("holes_on", lattice.size() > whole.size())
	# Nothing lies in a hole: the litter on it is lifted away, and what the hero dropped there moves
	# to the nearest whole ground.
	if surface_life != null:
		surface_life.set_holes(open_holes)
	_move_pickups_out(open_lattice)
	# The snow keeps off the dug squares too (a cellar ceiling gets snow like the ground).
	if snow != null:
		snow.set_holes(ImageTexture.create_from_image(snow_mask) if lattice.size() > whole.size() else null)
	if lattice.is_empty():
		plane.plane = Plane(Vector3.UP, 0.0)
		return
	# The endless plane drops far below; slabs carry the ground instead.
	plane.plane = Plane(Vector3.UP, -SLAB_THICK - 40.0)
	var origin := Vector2(lo.x * HOLE_CELL - TILE * 0.5, lo.y * HOLE_CELL - TILE * 0.5)
	var rows := hi.y - lo.y + 1
	var cols := hi.x - lo.x + 1
	var reach := Vector2(SLAB_REACH, SLAB_REACH)
	var all := Rect2(Vector2(-TILE * 0.5, -TILE * 0.5) - reach, Vector2(width * TILE, height * TILE) + reach * 2.0)
	var inner := Rect2(origin, Vector2(cols, rows) * HOLE_CELL)
	_slab(Rect2(all.position, Vector2(all.size.x, inner.position.y - all.position.y)))
	_slab(Rect2(Vector2(all.position.x, inner.end.y), Vector2(all.size.x, all.end.y - inner.end.y)))
	_slab(Rect2(Vector2(all.position.x, inner.position.y), Vector2(inner.position.x - all.position.x, inner.size.y)))
	_slab(Rect2(Vector2(inner.end.x, inner.position.y), Vector2(all.end.x - inner.end.x, inner.size.y)))
	for ry in rows:
		var run := -1
		for cx in range(cols + 1):
			var open := cx < cols and not lattice.has(Vector2i(lo.x + cx, lo.y + ry))
			if open and run < 0:
				run = cx
			elif not open and run >= 0:
				_slab(Rect2(origin + Vector2(run, ry) * HOLE_CELL, Vector2(cx - run, 1) * HOLE_CELL))
				run = -1


## Moves everything lying on the floor to be picked up out of the dug cells (`lattice`: the 2 m
## cells that are holes), to the centre of the nearest cell that is whole ground.
func _move_pickups_out(lattice: Dictionary) -> void:
	if lattice.is_empty():
		return
	for p in _pickups:
		if not (p is Dictionary and is_instance_valid(p.get("node"))):
			continue
		var node: Node3D = p.node
		var cell := Vector2i(floori((node.position.x + TILE * 0.5) / HOLE_CELL), floori((node.position.z + TILE * 0.5) / HOLE_CELL))
		if not lattice.has(cell):
			continue
		var found := cell
		for ring in range(1, 40):
			var best := INF
			for dy in range(-ring, ring + 1):
				for dx in range(-ring, ring + 1):
					if maxi(absi(dx), absi(dy)) != ring or lattice.has(cell + Vector2i(dx, dy)):
						continue
					var d := float(dx * dx + dy * dy)
					if d < best:
						best = d
						found = cell + Vector2i(dx, dy)
			if best < INF:
				break
		node.position = Vector3((found.x + 0.5) * HOLE_CELL - TILE * 0.5, node.position.y, (found.y + 0.5) * HOLE_CELL - TILE * 0.5)
		var entry = p.get("floor")
		if entry is Array and entry.size() >= 4:
			entry[2] = snappedf(node.position.x, 0.01)
			entry[3] = snappedf(node.position.z, 0.01)


func _slab(area: Rect2) -> void:
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(area.size.x, SLAB_THICK, area.size.y)
	shape.shape = box
	shape.position = Vector3(area.get_center().x, -SLAB_THICK * 0.5, area.get_center().y)
	_floor_slabs.add_child(shape)


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
	var node: Node3D
	if NaturalRock.replaces(name):
		# Boulders are real, uneven rocks, not the kit's flat facets (see NaturalRock).
		node = NaturalRock.node(name)
	else:
		if not _scenes.has(name):
			_scenes[name] = load(_model_path(name))
		node = _scenes[name].instantiate()
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
		var turn := IvySeasons.tree_turn(_tree_stage)
		bark.set_shader_parameter("autumn", turn.x)
		bark.set_shader_parameter("snowy", turn.y)
		_scenes[key] = bark
	return _scenes[key]


## Many copies of one model (trees) are drawn together in one go, one batch
## per GROUND_CHUNK patch of the map. The renderer lights each batch with at
## most a handful of lights (rendering/limits/opengl/max_lights_per_object),
## so one batch for every tree of a kind on the whole map left nearly all of
## them blind to the lanterns, fires and torches near them.
## A tree that would reach into a building plot is left out: the function
## returns how far the tree reaches (metres), or -1 when it was left out.
func _plant(name: String, pos: Vector3, rot: float, s: float) -> float:
	var reach := _reach_of(name, s)
	if on_plot(pos, reach) or Mountains.near_rock(self, pos.x, pos.z, Mountains.TREE_CLEARANCE):
		return -1.0
	# Spruces in smaller batches, so each one turns into its far model at about its own distance.
	var chunk := (SPRUCE_CHUNK if name.begins_with("spruce:") else GROUND_CHUNK) * TILE
	var patch := Vector2i(floori(pos.x / chunk), floori(pos.z / chunk))
	var key := [name, patch]
	if not _plants.has(key):
		_plants[key] = []
		_plant_reach[key] = []
	_plants[key].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), pos))
	_plant_reach[key].append(reach)
	return reach


func _flush_plants() -> void:
	for key in _plants:
		_draw_plants(key)


## Whether a spot lies in the trial stand of spruces (see SPRUCE_PATCH).
func in_spruce_patch(at: Vector3) -> bool:
	return level_name == SPRUCE_MAP and SPRUCE_PATCH.has_point(world_to_cell(at))


## Which of the needle trees (see Fern.NEEDLE_LOOKS: spruces, and a pine here and there, mixed by
## Fern.NEEDLE_MIX) stands at a spot: the same one every time.
func _spruce_of(at: Vector3) -> int:
	return Fern.needle_pick(hash(Vector2i(roundi(at.x * 10.0), roundi(at.z * 10.0))))


## Plants a tree (see _plant), or a spruce in its place: every living tree, in the forest or on
## its own (a "T" tile), is a spruce, and in the spruces' first stand every tree is. The dice for the tree are thrown all the same, so the rest of the map grows as before. A
## smaller tree (a "medium" one, filling a gap) is a smaller spruce. Tells _last_spruce whether it
## was a spruce.
func _plant_tree(name: String, pos: Vector3, rot: float, s: float) -> float:
	_last_spruce = in_spruce_patch(pos) or not name.begins_with("tree_dead")
	if not _last_spruce:
		return _plant(name, pos, rot, s)
	_last_spruce_size = _spruce_size(name, pos)
	return _plant("spruce:%d" % _spruce_of(pos), pos, rot, _last_spruce_size)


## How big the spruce is that stands in for tree `name` at a spot (its model's size times this): a
## little smaller for a "medium" tree.
func _spruce_size(name: String, at: Vector3) -> float:
	return _spruce_grow(at) * (0.8 if name.ends_with("medium") else 1.0)


## How much bigger or smaller than its model the spruce at a spot grows, so no two stand alike.
func _spruce_grow(at: Vector3) -> float:
	return 0.85 + 0.3 * float(posmod(hash(Vector2i(roundi(at.z * 10.0), roundi(at.x * 10.0))), 100)) / 100.0


## Ferns in the shade along the forest's edge: on the forest floor in front of and between the
## edge trees, where the crowns hang over it, and on the undergrowth's strip, never on a building
## plot, a bush or each other. Own dice, so the rest of the map comes out as before.
func _grow_ferns() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name + "farne")
	var placed: Array[Vector3] = []
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "#" or not _beside_walkable(c) or under_lair_mountain(c):
				continue
			var tile := _tile_rect(c)
			for i in FERN_TRIES:
				var at := Vector3(rng.randf_range(tile.position.x, tile.end.x), 0.0, rng.randf_range(tile.position.y, tile.end.y))
				var size := rng.randf_range(FERN_SCALE.x, FERN_SCALE.y)
				var turn := rng.randf() * TAU
				var variant := rng.randi() % FERN_VARIANTS
				# Only where it is shady: under a crown, or on the edge's own strip of floor.
				if not (under_crown(c, at) or _near_open_face(c, forest_block(c), at)):
					continue
				if placed.any(func(f: Vector3): return f.distance_to(at) < FERN_SPACING) \
						or undergrowth_bushes.any(func(b: Vector4): return Vector2(b.x - at.x, b.z - at.z).length() < b.w + 0.3):
					continue
				if _plant("fern:%d" % variant, at, turn, size) >= 0.0:
					placed.append(at)
	fern_count = placed.size()


## One batch of trees (see _plant), drawn again after some were cleared away.
func _draw_plants(key: Array) -> void:
	for node in _plant_batches.get(key, []):
		if is_instance_valid(node):
			node.queue_free()
	_plant_batches[key] = []
	if _plants[key].is_empty():
		return
	var name: String = key[0]
	if not _plant_parts.has(name):
		var made := _made_plant(name)
		if made:
			_plant_parts[name] = [[made, Transform3D()]]
		else:
			var scene: Node3D = load(_model_path(name)).instantiate()
			_plant_parts[name] = _meshes_of(scene, Transform3D())
			scene.free()
	for part in _plant_parts[name]:
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
		elif name.begins_with("spruce:"):
			# Its thousands of fronds are drawn once, without shadow; a plain stand-in of the same
			# outline casts the shadow (see Fern.needle_shadow_mesh), drawn in every shadow map.
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Every spruce is drawn frond by frond at any distance, so it looks the same near and far.
			# Only the Performance preset swaps in the far model (see Fern.needle_tree_mesh) beyond
			# SPRUCE_NEAR, which looks a little different.
			if Graphics.preset == Graphics.PERFORMANCE:
				mmi.visibility_range_end = SPRUCE_NEAR
				var far_mm := MultiMesh.new()
				far_mm.transform_format = MultiMesh.TRANSFORM_3D
				far_mm.mesh = Fern.needle_tree_mesh(int(name.get_slice(":", 1)), true)
				far_mm.instance_count = mm.instance_count
				for i in mm.instance_count:
					far_mm.set_instance_transform(i, mm.get_instance_transform(i))
				var far := MultiMeshInstance3D.new()
				far.multimesh = far_mm
				far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				far.visibility_range_begin = SPRUCE_NEAR
				add_child(far)
				_plant_batches[key].append(far)
			var shade := MultiMesh.new()
			shade.transform_format = MultiMesh.TRANSFORM_3D
			shade.mesh = Fern.needle_shadow_mesh(int(name.get_slice(":", 1)))
			shade.instance_count = mm.instance_count
			for i in mm.instance_count:
				shade.set_instance_transform(i, mm.get_instance_transform(i))
			var caster := MultiMeshInstance3D.new()
			caster.multimesh = shade
			caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			add_child(caster)
			_plant_batches[key].append(caster)
		elif name.begins_with("fern:"):
			# Small (their materials come with the mesh): from further off they are lost in the
			# floor anyway, and their shadows in the trees'.
			mmi.visibility_range_end = FERN_SEEN
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_plant_batches[key].append(mmi)


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


## A plant built in code instead of loaded ("spruce:<variant>", "fern:<variant>", see Fern), or
## null for a model of the kits.
func _made_plant(name: String) -> ArrayMesh:
	if name.begins_with("spruce:"):
		return Fern.needle_tree_mesh(int(name.get_slice(":", 1)))
	if name.begins_with("fern:"):
		return Fern.fern_mesh(int(name.get_slice(":", 1)))
	return null


## The size of a model, measured once.
func _aabb_of(name: String) -> AABB:
	var made := _made_plant(name)
	if made:
		return made.get_aabb()
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

## Plants the fields of the farming valley for the season the world is in.
func _plant_crops() -> void:
	if _crop_cells.is_empty():
		return
	crop_fields = CropFields.grow(self, _crop_cells, TILE, hash(level_name + "felder"), [SunflowerRiddle.centre()])
	crop_fields.set_season(season_day)
	# The crows feed on the low fields (the stubble of the wheat); where there is none, on any.
	var low: Array[Vector3] = []
	var all: Array[Vector3] = []
	for letter: String in _crop_cells:
		for spot: Vector3 in _crop_cells[letter]:
			all.append(spot)
			if letter == CropFields.WHEAT:
				low.append(spot)
	crows = Crows.new(self, low if not low.is_empty() else all, TILE, level_name)
	add_child(crows)
	crows.set_season(season_day)


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
			# Each stone is its own: its kind, model and lean follow from its tile, so the rest of the map's
			# random numbers do not move when graves are added.
			var grave_rng := RandomNumberGenerator.new()
			grave_rng.seed = hash("%s|grab|%s" % [level_name, c])
			var style := GraveStyles.pick(level_name, c)
			var pair := GraveSpirit.graves_of(level_name)
			if not pair.is_empty() and c == pair.unknown:
				style = "sunken"
			elif not pair.is_empty() and c == pair.archy:
				style = "cross"
			var coffin := BellGrave.graves_of(level_name)
			if not coffin.is_empty() and c == coffin.grave:
				style = "ledger"
			if c == OwlClock.grave_cell() or c == RiddleCount.grave_of(level_name):
				style = "classic"
			var jitter := Vector3(grave_rng.randf_range(-0.3, 0.3), 0, grave_rng.randf_range(-0.3, 0.3))
			var lean := grave_rng.randf_range(-0.15, 0.15)
			if style == "classic":
				var stone := _put(GRAVES[grave_rng.randi() % GRAVES.size()], pos + Vector3(0, 0, -0.6) + jitter, lean)
				_age_graveyard(stone, true, absi(hash(c)) % AgedStone.GRAVE_TINTS.size())
			else:
				var memorial := GraveStyles.build(style, grave_rng.randi())
				memorial.position = pos + Vector3(0, 0, -0.6) + jitter * 0.5
				memorial.rotation.y = lean
				add_child(memorial)
			OwlClock.place_grave(self, c, pos, _graves.size())
			_graves.append(c)
			_add_solid(pos + Vector3(0, 0, -0.6), GraveStyles.footprint(style))
			_grave_light(c, pos)
		"d":
			var tree: String = ["tree_dead_large", "tree_dead_medium", "tree_dead_small"][_rng.randi() % 3]
			var at := pos + _jitter(0.5)
			var rot := _rng.randf() * TAU
			var size := _rng.randf_range(1.1, 1.4)
			var reach := _reach_of(tree, size)
			if c == OwlClock.OWL_TREE_CELL:
				owl_tree_at = at
			if not on_plot(at, reach) and not Mountains.near_rock(self, at.x, at.z, Mountains.TREE_CLEARANCE):
				_clearable.append({"at": at, "reach": reach, "nodes": [_put(tree, at, rot, size),
						_add_box(_walls_body, pos + Vector3(0, 2, 0), Vector3(1.4, 4, 1.4))]})
		"p":
			_put_layout(pos, VillageClutter.PUMPKINS, 1.2)
		"l":
			_build_lantern(pos, c)
		"r":
			var rock: String = ["rock_single_A", "rock_single_C", "rock_single_E"][_rng.randi() % 3]
			var at := pos + _jitter(0.4)
			var rot := _rng.randf() * TAU
			var size := _rng.randf_range(7.0, 9.0)
			var reach := _reach_of(rock, size)
			if not on_plot(at, reach):
				# Blocked where the boulder is drawn: some reach well past the
				# middle of their tile, and the hero must not squeeze in between.
				var boulder := _put(rock, at, rot, size)
				var shapes := _walls_body.get_child_count()
				_add_turned_solid(boulder, 1.6)
				var nodes: Array = [boulder]
				for i in range(shapes, _walls_body.get_child_count()):
					nodes.append(_walls_body.get_child(i))
				_clearable.append({"at": at, "reach": reach, "nodes": nodes})
		"T":
			var reach := _build_tree(pos, true)
			if reach >= 0.0:
				_clearable.append({"at": pos, "reach": reach + 0.3,
						"nodes": [_add_box(_walls_body, pos + Vector3(0, 2, 0), Vector3(1.8, 4, 1.8))]})
		"t":
			_put_layout(pos, VillageClutter.STUMP, 1.2)
		"e":
			_put_layout(pos, VillageClutter.heap_for(level_name, c), 1.5)
		Apiary.HIVE:
			# Two hives and their bees (see Apiary): collected here, built together once the map is up.
			_hive_cells.append(c)
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
		"\"":
			Wasteland.build_gate(self, c)
		"°":
			Wasteland.build_signpost(self, c)
		"|":
			SternGate.build_gate(self, c)
		"`":
			SternGate.build_outlet(self, c)
		"?", ">":
			TreasureMaps.place(self, c, ch)
		"‖":
			RiverBridge.build(self, c)
		"∩":
			Waterfall.build(self, c)
		"Ω", "Ψ", "Θ", "Ξ":
			SewerSurface.build(self, c, ch)
		"~", ";", "≈":
			var pond_water := {"water": "teich" if ch == "~" else ("fluss" if ch == "≈" else "senke"), "pos": pos,
					"reach": TILE * 0.5, "round": false, "surface": 0.04, "cell": c}
			pond_water["shape"] = _add_box(_walls_body, pos + Vector3(0, 0.5, 0), Vector3(TILE, 1, TILE))
			fishing_waters.append(pond_water)
			_pond_waters.append(pond_water)
		"≡", "‡", "☼":
			# Wheat, maize and sunflowers (see CropFields): the plants are planted for all tiles at once.
			# The riddle field's tiles (see SunflowerRiddle) are planted as blocks of 5 x 5.
			var crop_key := CropFields.RIDDLE if ch == CropFields.SUNFLOWER and SunflowerRiddle.FIELD.has_point(c) else ch
			if not _crop_cells.has(crop_key):
				_crop_cells[crop_key] = []
			_crop_cells[crop_key].append(pos)
			# No solid: the fields are walkable, the hero and the villagers wade through the crops.
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
			AgedStone.grow_basin_ivy(pos, VillageFountain.RIM_RADIUS - 0.12, VillageFountain.RIM_TOP, ivy_rng, _ivy, 3)
			# Where the villagers fetch water: by the rim, between the bench in front and a tree.
			spots.well.append(pos + Vector3(1, 0, 1).normalized() * (VillageFountain.STEP_RADIUS + 0.7))
			spots.fountain.append(spots.well[-1])
		"x":
			_build_bench(c)
		TownMeals.LETTER:
			meals.build_table(self, c)
			# Still part of the square: the birds peck for crumbs under the tables, and the
			# square's middle stays where it was. Villagers on an errand skip it (see Villager._errand).
			spots.square.append(pos)
			spots.market.append(pos)
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
	# Icicles hang from its roof while snow lies (see SnowCaps).
	var frost := SnowCaps.board_node(pos)
	if frost:
		add_child(frost)
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
	warm_spots.append(Vector4(pos.x, pos.y + 0.3, pos.z, 2.4))
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
	if is_equal_approx(to.length(), TILE):
		# Right beside the fountain: out to the far side of its tile, in line with the apple trees
		# round it (AppleTree.TRUNK_OUT), so benches and trees stand in a square about the fountain
		# with room to walk round its rim.
		pos -= to.normalized() * AppleTree.TRUNK_OUT
	_put("bench", pos, rot, Seats.BENCH_SCALE)
	# Blocked where the bench is drawn: a long, narrow box turned with it, so
	# the hero can walk right up to the seat (see Seats).
	var box := _add_box(_walls_body, pos + Vector3(0, 0.5, 0), Vector3(Seats.BENCH_SIZE.x, 1.0, Seats.BENCH_SIZE.z))
	box.rotation.y = rot
	stations.append(Seats.station(c, pos, rot))


## A street lamp: an old timber post on a stone foot with an iron lantern
## hanging from its arm (see VillageProps.build_lamp), its panes and the
## candle in it glowing at night. A lamp on a map tile (`cell`) turns its arm
## towards the nearest walkway (see _walkway_dir) and, with one right beside it,
## steps up to the edge of that walkway, so the lantern hangs over the path.
func _build_lantern(pos: Vector3, cell := Vector2i(-1, -1)) -> void:
	var yaw := 0.0
	if cell.x >= 0:
		var away := _walkway_dir(cell)
		if away != Vector3.ZERO:
			var dir := away.normalized()
			yaw = VillageProps.lamp_yaw(dir)
			# A walkway right beside it (not diagonal): step up to its edge.
			if absf(away.x) + absf(away.z) == 1.0:
				pos += dir * (TILE * 0.5 - LAMP_EDGE_GAP)
	var turn := Basis(Vector3.UP, yaw)
	if cell.x >= 0:
		lamp_spots.append({"foot": pos, "arm": turn * Vector3(0, 0, 1), "walkway": _walkway_dir(cell)})
	VillageProps.build_lamp(self, pos, _lantern_panes(), yaw)
	# A few icicles on it while snow lies (see SnowCaps).
	var frost := SnowCaps.lamp_node(pos, VillageProps.LANTERN_AT, yaw)
	if frost:
		add_child(frost)
	_lantern_glow(pos + turn * LAMP_LIGHT_AT, pos + turn * VillageProps.LANTERN_AT)
	_lamp_perches.append(pos + Vector3(0, 3.11, 0))
	_lamp_perches.append(pos + turn * Vector3(0, 2.91, 0.5))
	_lamp_perches.append(pos + turn * Vector3(0, 2.91, 0.95))
	_add_solid(pos, Vector3(0.7, 3, 0.7))


## Where the nearest walkway (a dirt path or the paved square) within LAMP_SEEK tiles lies from a
## lamp's tile, as a flat offset in tiles. Zero when there is none.
func _walkway_dir(cell: Vector2i) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for dy in range(-LAMP_SEEK, LAMP_SEEK + 1):
		for dx in range(-LAMP_SEEK, LAMP_SEEK + 1):
			if dx == 0 and dy == 0:
				continue
			var c := cell + Vector2i(dx, dy)
			var surface := ground_at(c)
			if surface != Surfaces.PATH and surface != Surfaces.PAVING:
				continue
			var d := float(dx * dx + dy * dy)
			if d < best_d:
				best_d = d
				best = Vector3(dx, 0, dy)
	return best




## The glass of the lanterns, shared by all of them: lit at nightfall with the
## windows of the village (see set_hour).
func _lantern_panes() -> StandardMaterial3D:
	if _pane_mat == null:
		_pane_mat = StandardMaterial3D.new()
		_pane_mat.albedo_color = Color(0.32, 0.3, 0.24, 0.55)
		_pane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pane_mat.roughness = 0.25
		_pane_mat.emission_enabled = true
		_pane_mat.emission = Color(1.0, 0.68, 0.34)
		_pane_mat.emission_energy_multiplier = 0.0
		_window_mats[_pane_mat] = _pane_mat
	return _pane_mat


## What makes a lantern shine: the light that set_hour dims by day and
## brightens at night, and a candle in the lantern that glows once it fades.
func _lantern_glow(light_at: Vector3, candle_at: Vector3) -> void:
	var light := OmniLight3D.new()
	# A natural, gentler orange, and a falloff that fades out softly instead of ending in a hard
	# edge on the snow (attenuation above 1 pulls the light in toward the lamp).
	light.light_color = Color(1.0, 0.74, 0.48)
	light.light_energy = 2.2
	light.omni_range = 11.0
	light.omni_attenuation = 1.8
	light.position = light_at
	add_child(light)
	_lamps.append(light)
	# A glow mushroom is what a lantern burns: pale by day, glowing with the night (see GlowMushrooms).
	var candle := GlowMushrooms.lamp_node()
	candle.position = candle_at + Vector3(0, -0.07, 0)
	add_child(candle)
	_candles.append(candle)


## Two wall lamps on the temple's front wall, one each side of the door. They
## are not parts of the chapel (its pieces all wear the kit's textures), but
## siblings placed with the chapel's own transform.
func _build_temple_lamps(chapel: Node3D) -> void:
	var panes := _lantern_panes()
	for x: float in TEMPLE_LAMP_X:
		var holder := Node3D.new()
		holder.name = "TempleLamp%d" % int(x > 0.0)
		holder.position = chapel.transform * Vector3(x, TEMPLE_LAMP_Y, TEMPLE_LAMP_Z)
		holder.rotation.y = chapel.rotation.y
		add_child(holder)
		VillageProps.build_wall_lamp(holder, Vector3.ZERO, panes)
		# The light and the candle sit in the middle of the lantern's glass, turned with the wall.
		var glass_at := holder.position + (VillageProps.WALL_LANTERN_AT - Vector3(0, 0.03, 0)).rotated(Vector3.UP, holder.rotation.y)
		_lantern_glow(glass_at, glass_at)


## A leafy tree, or near the graveyard an autumn pine or a bare one. Returns
## how far it reaches (metres), or -1 when it would stand over a building plot.
func _build_tree(pos: Vector3, single := false) -> float:
	var near_crypt := pos.distance_to(cell_to_world(start_cell)) < 13.0 * TILE
	var roll := _rng.randf()
	var rot := _rng.randf() * TAU
	var at := pos + _jitter(0.9 if not single else 0.3)
	_tree_at = at
	# How tall it stands (metres), for the woods' wildlife (see WoodsLife).
	var height := 0.0
	var leafy := false
	var reach := 0.0
	if near_crypt and roll < 0.45:
		reach = _plant_tree(["tree_dead_large", "tree_dead_medium"][_rng.randi() % 2], at, rot, _rng.randf_range(1.2, 1.6))
	elif roll < 0.35 or (near_crypt and roll < 0.8):
		var scale_of := _rng.randf_range(0.9, 1.25)
		var pine: String = ["tree_pine_orange_large", "tree_pine_yellow_large", "tree_pine_orange_medium", "tree_pine_yellow_medium"][_rng.randi() % 4]
		reach = _plant_tree(pine, at, rot, scale_of)
		height = (6.9 if pine.ends_with("large") else 5.4) * scale_of
	elif roll < 0.75 or single:
		var scale_of := _rng.randf_range(5.5, 7.5)
		reach = _plant_tree(["tree_single_A", "tree_single_B"][_rng.randi() % 2], at, rot, scale_of)
		height = 1.1 * scale_of
		leafy = true
	else:
		var scale_of := _rng.randf_range(3.0, 3.8)
		reach = _plant_tree(["trees_A_medium", "trees_B_medium"][_rng.randi() % 2], at, rot, scale_of)
		height = 1.2 * scale_of
	if reach < 0.0:
		return reach
	var spruce := _last_spruce
	if spruce:
		height = Fern.needle_height(_spruce_of(at)) * _last_spruce_size
		# Squirrels live in spruces too (see WoodsLife: "leafy" is a tree they can climb).
		leafy = true
	# A spruce's low branches bend down to the ground and hide it nearly all the way out.
	_tree_crown = reach * (SPRUCE_CROWN if spruce else CROWN if height > 0.0 else DEAD_CROWN)
	if height > 0.0 and not near_crypt:
		_wood_trees.append({"pos": Vector3(at.x, 0.0, at.z), "height": height, "leafy": leafy})
	return reach


# --- Building plots -------------------------------------------------------------

## Room kept free round a plot (metres): a crown or boulder that comes closer
## seems to stand on the plot from the camera's angle, so it goes too.
const PLOT_CLEARANCE := 1.0

## The ground a plot of tiles covers, in metres.
func plot_area(rect: Rect2i) -> Rect2:
	return Rect2((rect.position.x - 0.5) * TILE, (rect.position.y - 0.5) * TILE, rect.size.x * TILE, rect.size.y * TILE)


## Whether something standing at `at` and reaching `reach` metres round it
## would stand over a building plot, or too close to its edge.
func on_plot(at: Vector3, reach: float) -> bool:
	var p := Vector2(at.x, at.z)
	for area in _plot_areas:
		var nearest := p.clamp(area.position, area.end)
		if nearest.distance_to(p) < reach + PLOT_CLEARANCE:
			return true
	return false


## How far a model drawn `s` times its size reaches out from where it stands.
func _reach_of(name: String, s: float) -> float:
	var box := _aabb_of(name)
	return maxf(maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.z), absf(box.end.z))) * s


## A plot registered while the map is open (see Events.plot_registered): the
## trees, boulders and mountain slopes reaching into it go at once.
func clear_plot(rect: Rect2i) -> void:
	var area := plot_area(rect)
	if _plot_areas.has(area):
		return
	_plot_areas.append(area)
	for key in _plants:
		var transforms: Array = _plants[key]
		var reaches: Array = _plant_reach[key]
		var before := transforms.size()
		for i in range(before - 1, -1, -1):
			if on_plot((transforms[i] as Transform3D).origin, reaches[i]):
				transforms.remove_at(i)
				reaches.remove_at(i)
		if transforms.size() < before:
			_draw_plants(key)
	for i in range(_clearable.size() - 1, -1, -1):
		var thing: Dictionary = _clearable[i]
		if on_plot(thing.at, thing.reach):
			for node in thing.nodes:
				if is_instance_valid(node):
					node.queue_free()
			_clearable.remove_at(i)
	# The rock leans back from the plot's edge.
	var beside_rock := false
	for y in range(rect.position.y - 2, rect.end.y + 2):
		for x in range(rect.position.x - 2, rect.end.x + 2):
			beside_rock = beside_rock or cell_char(Vector2i(x, y)) == Mountains.ROCK_LETTER
	if beside_rock:
		for node in _mountain_nodes:
			if is_instance_valid(node):
				node.queue_free()
		_mountain_nodes = Mountains.build(self, hash(level_name + "berge"), _plot_areas)
		MountainFoot.rebuild(self)


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
	if not _hive_cells.is_empty():
		apiary = Apiary.new(self, _hive_cells, level_name)
		add_child(apiary)
	owls = Owls.new(trees, cell_to_world, TILE, level_name)
	add_child(owls)
	if owl_tree_at != Vector3.INF and owlav_pos != Vector3.INF:
		owls.add_clock_owl(owl_tree_at + Vector3(0, OwlClock.OWL_HEIGHT, 0), owlav_pos)
	owls.clock_on = moon_night >= 0 and Moon.is_full(moon_night)


## Trees on every forest tile close to the open ground. Further in there
## is only the dark forest floor, which the camera never gets to see much of.
## The gaps the dice leave just behind the edge are filled (see _fill_forest_gaps).
func _build_forest() -> void:
	for y in range(-2, height + 2):
		for x in range(-2, width + 2):
			var c := Vector2i(x, y)
			if cell_char(c) != "#":
				continue
			if under_lair_mountain(c):
				continue
			var depth := _forest_depth(c)
			if depth > FOREST_DEPTH:
				continue
			if _rng.randf() < [1.0, 1.0, 0.9, 0.75, 0.6][depth]:
				if _build_tree(cell_to_world(c)) >= 0.0:
					forest_trees[c] = [{"at": _tree_at, "crown": _tree_crown}]
	_fill_forest_gaps()
	_close_edge_gaps()


## The forest floor just behind the edge trees, where the camera looks in between their crowns, is
## no clearing to walk into: wherever no crown hides it, a smaller pine fills the gap. Own dice, so
## the rest of the map comes out as before.
func _fill_forest_gaps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name + "waldluecken")
	for y in range(-2, height + 2):
		for x in range(-2, width + 2):
			var c := Vector2i(x, y)
			if cell_char(c) != "#":
				continue
			var depth := _forest_depth(c)
			if depth < 2 or depth > FILL_DEPTH:
				continue
			if under_lair_mountain(c):
				continue
			for spot: Vector2 in [Vector2(0, 0), Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(-1.2, 1.2), Vector2(1.2, 1.2)]:
				var gap := cell_to_world(c) + Vector3(spot.x, 0.0, spot.y)
				var at := gap + Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
				if under_crown(c, gap):
					continue
				var pine: String = ["tree_pine_orange_medium", "tree_pine_yellow_medium", "tree_pine_orange_medium"][rng.randi() % 3]
				var reach := _plant_tree(pine, at, rng.randf() * TAU, rng.randf_range(0.8, 1.05))
				if reach >= 0.0:
					if not forest_trees.has(c):
						forest_trees[c] = []
					forest_trees[c].append({"at": at, "crown": reach * (SPRUCE_CROWN if _last_spruce else CROWN)})


## Along the forest's edge one spruce stands on each tile, and between two the eye looks through
## gaps a body could pass, though the forest is shut there. A smaller spruce fills each such gap:
## on a line EDGE_FILL_DEPTH in from the open side (behind the leaves the hero may walk on, see
## FOREST_MARGIN), every EDGE_FILL_STEP along it, wherever no crown hides the spot yet. They stand
## outside forest_trees, so the walkable strip in front stays as wide as before. Own dice.
func _close_edge_gaps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name + "randluecken")
	var placed: Array[Vector4] = []
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "#" or under_lair_mountain(c) or not _beside_walkable(c):
				continue
			var tile := _tile_rect(c)
			for side: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if not WALK.contains(cell_char(c + side)):
					continue
				var steps := floori(TILE / EDGE_FILL_STEP)
				for k in steps + 1:
					var along := (k + 0.5 * float(k == 0) - 0.5 * float(k == steps)) * TILE / steps
					var at := Vector3.ZERO
					if side.x != 0:
						at.x = tile.position.x + EDGE_FILL_DEPTH if side.x < 0 else tile.end.x - EDGE_FILL_DEPTH
						at.z = tile.position.y + along
					else:
						at.z = tile.position.y + EDGE_FILL_DEPTH if side.y < 0 else tile.end.y - EDGE_FILL_DEPTH
						at.x = tile.position.x + along
					var cell := world_to_cell(at)
					if cell_char(cell) != "#" or under_crown(cell, at) \
							or placed.any(func(f: Vector4): return Vector2(f.x - at.x, f.z - at.z).length() < f.w):
						continue
					at += Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
					var reach := _plant_tree("tree_pine_orange_medium", at, rng.randf() * TAU, 1.0)
					if reach >= 0.0:
						placed.append(Vector4(at.x, 0.0, at.z, reach * SPRUCE_CROWN))
	edge_fillers = placed.size()


## What looks walkable is walkable, and what blocks looks blocked. The forest does not stop the
## hero at the edge of its tiles but where its trees stand: on each side of a forest tile that
## faces walkable ground the block starts at the front of the tree's crown (see forest_block),
## so the leaves in front of and between the edge trees can be walked on. The forest floor that
## still blocks and is not hidden under a crown gets undergrowth (see _grow_undergrowth).
func _build_wall_collision() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name + "unterholz")
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "#" or not _beside_forest_edge(c):
				continue
			var tile := _tile_rect(c)
			var block := forest_block(c)
			_add_block(block)
			# Where two forest tiles meet only at a corner between two open tiles, both keep
			# their corner, so the forest stays shut there as it was.
			for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				if cell_char(c + corner) != "#":
					continue
				var x0 := tile.position.x if corner.x < 0 else block.end.x
				var x1 := block.position.x if corner.x < 0 else tile.end.x
				var z0 := tile.position.y if corner.y < 0 else block.end.y
				var z1 := block.position.y if corner.y < 0 else tile.end.y
				if x1 - x0 > 0.01 and z1 - z0 > 0.01:
					_add_block(Rect2(x0, z0, x1 - x0, z1 - z0))
			if _beside_walkable(c) and not under_lair_mountain(c):
				_grow_undergrowth(c, block, rng)


## Whether a forest tile has anything but forest round it (the tiles the hero can come up to).
func _beside_forest_edge(c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if cell_char(c + Vector2i(dx, dy)) != "#":
				return true
	return false


## Whether a tile has walkable ground beside it, on a side or a corner.
func _beside_walkable(c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if WALK.contains(cell_char(c + Vector2i(dx, dy))):
				return true
	return false


## A tile's ground (x, z), in metres.
func _tile_rect(c: Vector2i) -> Rect2:
	var p := cell_to_world(c)
	return Rect2(p.x - TILE * 0.5, p.z - TILE * 0.5, TILE, TILE)


func _add_block(r: Rect2) -> void:
	var mid := r.get_center()
	_add_box(_walls_body, Vector3(mid.x, 2.0, mid.y), Vector3(r.size.x, 4.0, r.size.y))


## The ground of a forest tile that stops the hero (x, z, in metres): the whole tile, pulled back
## on each side that faces walkable ground to the front of its trees' crowns, by FOREST_MARGIN at
## most (by all of it on a tile without a tree, whose undergrowth then shows where the block
## starts). Under the lair's mountain the rock blocks the whole tile.
func forest_block(c: Vector2i) -> Rect2:
	var r := _tile_rect(c)
	if under_lair_mountain(c):
		return r
	var lo := r.end
	var hi := r.position
	for tree: Dictionary in forest_trees.get(c, []):
		var at: Vector3 = tree.at
		lo = lo.min(Vector2(at.x, at.z) - Vector2.ONE * float(tree.crown))
		hi = hi.max(Vector2(at.x, at.z) + Vector2.ONE * float(tree.crown))
	var a := r.position
	var b := r.end
	if WALK.contains(cell_char(c + Vector2i(-1, 0))):
		a.x = clampf(lo.x, r.position.x, r.position.x + FOREST_MARGIN)
	if WALK.contains(cell_char(c + Vector2i(1, 0))):
		b.x = clampf(hi.x, r.end.x - FOREST_MARGIN, r.end.x)
	if WALK.contains(cell_char(c + Vector2i(0, -1))):
		a.y = clampf(lo.y, r.position.y, r.position.y + FOREST_MARGIN)
	if WALK.contains(cell_char(c + Vector2i(0, 1))):
		b.y = clampf(hi.y, r.end.y - FOREST_MARGIN, r.end.y)
	return Rect2(a, b - a)


## Whether a spot on the ground lies under the crown of a forest tree on tile `c` or round it.
func under_crown(c: Vector2i, at: Vector3) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for tree: Dictionary in forest_trees.get(c + Vector2i(dx, dy), []):
				if Vector2(at.x - tree.at.x, at.z - tree.at.z).length() < float(tree.crown):
					return true
	return false


## Whether a spot in a forest tile's block lies within UNDERGROWTH_DEPTH of a side that faces
## walkable ground (further in, the trees and the filled gaps behind them hide the floor).
func _near_open_face(c: Vector2i, block: Rect2, at: Vector3) -> bool:
	return (WALK.contains(cell_char(c + Vector2i(-1, 0))) and at.x - block.position.x < UNDERGROWTH_DEPTH) \
			or (WALK.contains(cell_char(c + Vector2i(1, 0))) and block.end.x - at.x < UNDERGROWTH_DEPTH) \
			or (WALK.contains(cell_char(c + Vector2i(0, -1))) and at.z - block.position.y < UNDERGROWTH_DEPTH) \
			or (WALK.contains(cell_char(c + Vector2i(0, 1))) and block.end.y - at.z < UNDERGROWTH_DEPTH)


## Low bushes on the part of a forest tile's block that no crown hides, so the leaf-strewn floor
## there no longer looks like a way in.
func _grow_undergrowth(c: Vector2i, block: Rect2, rng: RandomNumberGenerator) -> void:
	var inner := block.grow(-0.5)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	var steps := Vector2i(maxi(1, ceili(inner.size.x)), maxi(1, ceili(inner.size.y)))
	var placed: Array[Vector3] = []
	for iy in steps.y + 1:
		for ix in steps.x + 1:
			var at := Vector3(inner.position.x + inner.size.x * ix / steps.x, 0.0, inner.position.y + inner.size.y * iy / steps.y)
			if not _near_open_face(c, block, at) or under_crown(c, at) or on_plot(at, 0.5) \
					or _near_barber(at) or Mountains.near_rock(self, at.x, at.z, Mountains.BUSH_CLEARANCE) \
					or placed.any(func(b: Vector3): return b.distance_to(at) < UNDERGROWTH_SPACING):
				continue
			placed.append(at)
			_undergrowth_bush(at, rng)
	# A spruce's crown is narrow: where the floor still shows between the crowns and the bushes
	# near the open side, one more bush, as close to it as the strip lets it grow.
	var radii: Array[float] = []
	for b in undergrowth_bushes.slice(undergrowth_bushes.size() - placed.size()):
		radii.append(b.w)
	for iy in ceili(block.size.y / UNDERGROWTH_CHECK):
		for ix in ceili(block.size.x / UNDERGROWTH_CHECK):
			var at := Vector3(block.position.x + (ix + 0.5) * UNDERGROWTH_CHECK, 0.0, block.position.y + (iy + 0.5) * UNDERGROWTH_CHECK)
			if not _near_open_face(c, block, at) or under_crown(c, at) or on_plot(at, 0.5) \
					or _near_barber(at) or Mountains.near_rock(self, at.x, at.z, Mountains.BUSH_CLEARANCE):
				continue
			var covered := false
			for i in placed.size():
				if Vector2(placed[i].x - at.x, placed[i].z - at.z).length() < radii[i] + 0.3:
					covered = true
					break
			if covered:
				continue
			var spot := Vector3(clampf(at.x, inner.position.x, inner.end.x), 0.0, clampf(at.z, inner.position.y, inner.end.y))
			placed.append(spot)
			radii.append(_undergrowth_bush(spot, rng))


## One bush of the undergrowth at `at` (see _grow_undergrowth); returns its radius.
func _undergrowth_bush(at: Vector3, rng: RandomNumberGenerator) -> float:
	# Most of them shed their leaves in autumn (see _keeps_leaves).
	var radius := AgedStone.grow_bush(at, rng, _undergrowth if _keeps_leaves(at, UNDERGROWTH_AUTUMN_KEEP) else _undergrowth_shed, _undergrowth, _bush_recent)
	undergrowth_bushes.append(Vector4(at.x, at.y, at.z, radius))
	return radius


## Whether the mountain of the dragon's lair stands over a tile (no tree grows there).
func under_lair_mountain(c: Vector2i) -> bool:
	if _lair_mountain_at == Vector3.INF:
		return false
	var rel := cell_to_world(c) - _lair_mountain_at
	return LairMountain.covers(rel.x, rel.z)


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
		var arch := _put("arch_gate", pos, rot)
		_age_graveyard(arch, false)
		GraveGate.attach(arch, self)
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
	walk_in = WalkIn.new(self)
	_dress_collect()
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
	_dress_settle()


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
	if ch == "b" and BankVault.on:
		_build_bank_site(block)
		return
	var facing := _block_facing(block) if ch != "R" else Vector2i(0, 1)
	var rot := atan2(float(facing.x), float(facing.y))
	var turned := facing.x != 0
	var room := Vector2(block.size) * TILE * 0.92
	var center := cell_to_world(block.position) + Vector3(block.size.x - 1, 0, block.size.y - 1) * TILE * 0.5
	var node: Node3D
	if ch == "s":
		node = _build_chapel(center, rot, room if not turned else Vector2(room.y, room.x))
		if WalkIn.is_on(ch):
			walk_in.claim(node, "temple", block)
	elif ch == "h" or ch == "ß":
		if ch == "h":
			node = VillageHouse.build(room if not turned else Vector2(room.y, room.x), _rng, _house_glass())
		else:
			# Gorm's own little house beside the smithy (see SmithCottage), with its own dice so the
			# other houses look as they always did.
			node = SmithCottage.build(room if not turned else Vector2(room.y, room.x), block, _house_glass())
		node.position = center
		node.rotation.y = rot
		add_child(node)
		WindowSpill.attach(node, _spill_material())
		var door: Vector3 = node.transform * (node.get_meta("door") as Vector3)
		house_doors.append(node.get_meta("door_leaf"))
		_entrances.append({"door": door, "out": Vector3(facing.x, 0, facing.y)})
		if WalkIn.is_on(ch):
			var rec := walk_in.claim(node, "house", block)
			if ch == "ß":
				rec["owner"] = SmithCottage.OWNER
		_dress_building(node, center, [door], 0.75, AgedStone.IVY_PATCHES, _standalone(block), 0.0, 0.0, 1.0, false, 0, SnowCaps.LOWEST, _open_house.bind(node))
	elif VillageHalls.KINDS.has(ch) and WalkIn.is_on(ch):
		# A hall rebuilt in the village's style to be walked into (see VillageHalls).
		# Its own dice, so switching a hall on or off leaves every other building as it was.
		var hall_rng := RandomNumberGenerator.new()
		hall_rng.seed = hash("hall %s %s" % [ch, block.position])
		node = VillageHouse.build(room if not turned else Vector2(room.y, room.x), hall_rng, _house_glass(), VillageHalls.style(ch))
		node.name = "Hall_" + String(VillageHalls.KINDS[ch])
		node.set_meta("hall", VillageHalls.KINDS[ch])
		node.position = center
		node.rotation.y = rot
		add_child(node)
		WindowSpill.attach(node, _spill_material())
		house_doors.append(node.get_meta("door_leaf"))
		walk_in.claim(node, VillageHalls.KINDS[ch], block)
		walk_in.add_front(node, VillageHalls.hang_sign(node, VillageHalls.KINDS[ch]))
		if ch == "u":
			# The mill's tower, cap and turning sails on its stone storey (see MillTower).
			var tower := MillTower.raise(node, _put)
			_age_kit_building(tower)
			var turning := Windmill.attach(self, tower)
			if turning:
				turning.hall = node
				windmills.append(turning)
				SailCloth.apply(turning.sails as MeshInstance3D, _window_mask)
			walk_in.add_upper(node, tower)
		# Its wares and what goes with its trade set out by the door (see ShopFronts).
		walk_in.add_front(node, ShopFronts.dress(walk_in, node, VillageHalls.KINDS[ch]))
	else:
		var model: String = BLOCK_MODELS[ch]
		var box := _aabb_of(model)
		var model_size := Vector2(box.size.z, box.size.x) if turned else Vector2(box.size.x, box.size.z)
		var s := minf(room.x / model_size.x, room.y / model_size.y)
		var foot := (Vector3(box.position.x + box.size.x * 0.5, 0, box.position.z + box.size.z * 0.5) * s).rotated(Vector3.UP, rot)
		node = _put(model, center - foot, rot, s)
		if ch == "j":
			# The smithy's furnace burns logs in its mouth and a fire on its chimney (spots in the
			# model's own frame, where its texture glows): no snow on either.
			for hot: Vector4 in SMITHY_FIRES:
				var at: Vector3 = node.transform * Vector3(hot.x, hot.y, hot.z)
				warm_spots.append(Vector4(at.x, at.y, at.z, hot.w * s))
			_smithy_fire(node, s)
			_smithy_node = node
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
	if not walk_in.has(node):
		_add_solid(center, solid)
	var reach := Vector2(block.size) * TILE * 0.5 + Vector2(2.0, 2.0)
	var front := center + Vector3(facing.x * reach.x, 0, facing.y * reach.y)
	doors[ch] = front
	if ch == "n" and walk_in.has(node):
		# Eberhard sleeps in the loft of the tavern (see WalkIn._loft).
		own_homes[VillageHalls.KEEPERS.tavern] = front
		# Fritz sleeps at his table there, not in a bed (see TavernBrewer.doze).
		own_homes[TavernBrewer.GUEST] = front
	if ch == "w" and walk_in.has(node):
		# Ragna sleeps in the guildhall's cellar (see GuildHall).
		own_homes[VillageHalls.KEEPERS.guild] = front
	if VillageHalls.HOME_OWNERS.has(VillageHalls.KINDS.get(ch, "")) and walk_in.has(node):
		# The family above the shop and the staff above the post office and the Crown office sleep
		# in the bedrooms there (see WalkIn._bedroom).
		for role: String in VillageHalls.HOME_OWNERS[VillageHalls.KINDS[ch]]:
			own_homes[role] = front
	if ch == "Ø" and walk_in.has(node):
		# Aldo and Odo sleep in the mage tower's top room (see MageTower).
		for role: String in MageTower.OWNERS:
			own_homes[role] = front
	if ch != "R" and ch != "h" and ch != "ß":
		var door := center + Vector3(facing.x * (reach.x - 2.0), 0, facing.y * (reach.y - 2.0))
		_entrances.append({"door": door, "out": Vector3(facing.x, 0, facing.y)})
		if ch == "s":
			var door_spots := []
			for x in [-2.0, 0.0, 2.0]:
				for z in [0.0, -1.5, -3.0]:
					door_spots.append(door + Vector3(x, 0, z).rotated(Vector3.UP, rot))
			# No nest on the temple: the spire stands at the front of its ridge and hides anything on it
			# from the game camera; the nest goes to another roof instead.
			# Its stones and its opening wait for the dressing to be in place (see _dress_building).
			var finish := func() -> void:
				_temple_stones(node, center, door, Vector3(facing.x, 0, facing.y))
				if walk_in.has(node):
					walk_in.open_temple(node)
					for lamp in find_children("TempleLamp*", "Node3D", false, false):
						walk_in.add_front(node, lamp)
			_dress_building(node, center, door_spots, 0.0, TEMPLE_IVY, true, 0.0, 0.0, 1.0, false, TEMPLE_ROOF_VINES, TEMPLE_STEP_SNOW, finish)
		elif walk_in.has(node):
			# A hall wears ivy like the villagers' houses (see VillageHalls).
			var hall_door: Vector3 = node.transform * (node.get_meta("door") as Vector3)
			_dress_building(node, center, [hall_door], 0.75, AgedStone.IVY_PATCHES, _standalone(block), 0.0, 0.0, 1.0, false, 0, SnowCaps.LOWEST, _open_house.bind(node))
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
	if ch == "h" or ch == "ß":
		if ch == "h":
			spots.houses.append(front)
		else:
			own_homes[SmithCottage.OWNER] = front
		var plume := ChimneySmoke.make()
		plume.position = node.transform * (node.get_meta("chimney") as Vector3)
		add_child(plume)
		warm_spots.append(Vector4(plume.position.x, plume.position.y, plume.position.z, 0.8))
		chimneys.append({"door": front, "smoke": plume})
		walk_in.add_upper(node, plume)
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
	elif ch == "o" and not walk_in.has(node):
		# Parcels waiting at the old post office (the walked-in one sets out its own, see ShopFronts).
		var side := Vector3(-facing.y, 0, facing.x) * 2.4
		_put("crate_long_A", front + side - Vector3(facing.x, 0, facing.y) * 1.0, rot, PROP_SCALE)
		_put("crate_open", front - side - Vector3(facing.x, 0, facing.y) * 1.0, rot + 0.3, PROP_SCALE)
	node.set_meta("block", block)


## The bank's block with the bank and its vault walked into (see BankVault): the house itself is
## drawn by HouseSketcher like a hero's, so here only its tiles let sight and reach through (its
## walls stop them) and its door is where villagers and errands go to it.
func _build_bank_site(block: Rect2i) -> void:
	for c in BankVault.bank_tiles():
		walk_in.open_cells[c] = true
	var door: Vector3 = BankVault.sketch().node_world(BankVault.door_cell().x, BankVault.door_cell().y) + Vector3(HouseSketch.CELL * 0.5, 0, 0)
	var front := door + Vector3(0, 0, -2.0)
	doors["b"] = front
	spots.square.append(front)
	_entrances.append({"door": door, "out": Vector3(0, 0, -1)})
	var marker := Node3D.new()
	marker.name = "BankSite"
	marker.position = door
	marker.set_meta("block", block)
	add_child(marker)
	_bank_sign(door)


## The bank's sign: a post beside its door, to the right as one comes up the path (the door faces
## north, -z), off the path, its shield of coins hung away from the path (see HangingShield).
func _bank_sign(door: Vector3) -> void:
	var at := door + Vector3(BANK_SIGN_SIDE, 0, -BANK_SIGN_OUT)
	var board := HangingShield.on_post("bank", Lang.t("Bank"), preload("res://assets/fonts/Cinzel-Bold.woff2"))
	board.name = "BankSign"
	board.position = at
	WeatheredProps.weather_plain(board)
	add_child(board)
	_add_solid(at, Vector3(0.4, HangingShield.POST_HIGH, 0.4))
	# The bank's strongbox on the door's other side, a halberd leaned on it (see ShopFronts).
	var box := ShopFronts.bank_strongbox(Vector3(0, 0, -1))
	var box_at := door + Vector3(-BANK_BOX_SIDE, 0, -BANK_BOX_OUT)
	box.position = box_at
	add_child(box)
	_add_solid(box_at + Vector3(0, 0.5, 0), box.get_meta("solid_size"))


## Where the pub sign's post stands south of the dining tables' middle line, and the sign's board
## (it hangs a bit out from the post) is centred between the two tents.
const PUB_POST_SOUTH := 3.4


## The pub's sign on the village square: a freestanding post with an iron bracket, the painted board
## of Apples & Ivy! hanging between the two dining tents, a little south of them (see PubSign).
func _square_pub_sign() -> void:
	if meals.tables.size() < 2:
		return
	var a: Vector3 = meals.tables[0]
	var b: Vector3 = meals.tables[1]
	var at := Vector3((a.x + b.x) * 0.5 - PubSign.ARM_OUT * 0.53, 0.0, maxf(a.z, b.z) + PUB_POST_SOUTH)
	var post := PubSign.on_post()
	post.name = "PubSignSquare"
	post.position = at
	add_child(post)
	_add_solid(at, Vector3(0.62, PubSign.POST_HIGH, 0.62))


## The vault cellar under the bank (see BankVault) when it is walked into; the old cellar level
## fills its own lockers (see Level.refresh_vaults).
func refresh_vaults() -> void:
	if BankVault.on:
		BankVault.refresh(self)
	else:
		super()


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
		WindowLife.attach(house, _life_material())
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


## Dresses a dungeon gate with winter (see SnowCaps.gate_node): caps on its tops, drifts at its
## foot and icicles under its lintel, all shown only while snow lies.
func gate_snow(parts: Array, tag: String) -> void:
	var node := SnowCaps.gate_node(parts, level_name + tag)
	if node:
		add_child(node)


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
	_dress_lair(arch, AgedStone.lair_stone())
	# The door swung open against the arch's side, dark old planks.
	_dress_lair(_put("lair/Arch_Door", front + Vector3(-1.2, 0, 0.2), -PI * 0.55, 1.0), AgedStone.lair_timber(Color(0.5, 0.4, 0.33)))
	# The opening: steps going down, fading into the dark.
	var hole := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.3)
	hole.mesh = quad
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_texture = StairsDown.doorway_texture()
	black.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	hole.material_override = black
	hole.position = front + Vector3(0, 1.65, -0.35)
	add_child(hole)
	for i in 2:
		_dress_lair(_put("lair/Stairs_Modular", front + Vector3(0, -0.55 - i * 0.9, 0.55 - i * 0.9), PI, 1.3), AgedStone.lair_stone(0.12 * i))
	var lair_parts: Array = [arch]
	for side in [-1.0, 1.0]:
		var column := _put("lair/Column2", front + Vector3(side * 2.9, 0, -0.1), 0.0, 0.9)
		_dress_lair(column, AgedStone.lair_stone(0.05))
		lair_parts.append(column)
		_put("lair/Skull", front + Vector3(side * 2.2 + _rng.randf_range(-0.4, 0.4), 0, 1.6 + _rng.randf_range(0.0, 0.8)), _rng.randf() * TAU, 0.8)
	# The mountain the lair is dug into, rising behind the arch, and a few
	# boulders fallen from it at its foot either side.
	var mountain := LairMountain.build(hash(level_name + "berg"))
	mountain.position = front
	add_child(mountain)
	_lair_mountain_at = front
	_forecourts.append({"block": block, "front": front})
	for side in [-1.0, 1.0]:
		var big_boulder := _put("rock_single_E", front + Vector3(side * 5.6, 0, -4.4), side * 0.9, 9.0)
		_age_ruin(big_boulder, LAIR_BOULDER)
		_add_turned_solid(big_boulder, 1.6)
		_age_ruin(_put("rock_single_C", front + Vector3(side * 3.6, 0, -1.9), side * 2.1, 3.5), LAIR_BOULDER)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.35, 0.15)
	glow.light_energy = 1.1
	glow.omni_range = 6.0
	glow.position = front + Vector3(0, 1.0, -1.2)
	add_child(glow)
	_add_solid(center, Vector3(block.size.x * TILE * 0.86, 4, block.size.y * TILE * 0.86))
	var top := _aabb_of("lair/Arch")
	var post := _aabb_of("lair/Column2")
	var gate_parts: Array = [
		{"at": front + Vector3(top.get_center().x, top.end.y, top.get_center().z), "size": Vector2(top.size.x * 0.55, top.size.z * 0.8)},
		{"at": front + Vector3(-3.7, 0.12, 1.2), "size": Vector2(1.8, 1.4)},
		{"at": front + Vector3(3.7, 0.12, 1.0), "size": Vector2(1.6, 1.4)},
	]
	for side in [-1.0, 1.0]:
		gate_parts.append({"at": front + Vector3(side * 2.9 + post.get_center().x * 0.9, post.end.y * 0.9, -0.1 + post.get_center().z * 0.9), "size": Vector2(post.size.x * 0.6, post.size.z * 0.6) * 0.9})
	gate_snow(gate_parts, "lair")
	arch.set_meta("block", block)
	doors["E"] = front + Vector3(0, 0, 2.0)
	# Overgrown at the foot of its arch and columns, but not in the way down.
	_wild_fringe(lair_parts, front + Vector3(0, 0, -1.0), [front, doors["E"]])
	if interiors.has("E"):
		stations.append({"kind": "eingang", "building": "E", "name": BUILDING_NAMES.E,
				"cell": world_to_cell(front - Vector3(0, 0, 0.5)), "pos": front + Vector3(0, 0, 0.6), "used": false})


## One piece of the lair's entrance (arch, columns, steps, door) in `material`, replacing the
## kit's own colours.
func _dress_lair(node: Node, material: Material) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh != null:
			mi.material_override = material


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
	gate_snow([
		{"at": front + Vector3(0, 4.2, 0), "size": Vector2(4.6, 0.55), "under": 3.7},
		{"at": front + Vector3(0, 4.175, -0.9), "size": Vector2(4.4, 0.45)},
		{"at": front + Vector3(-2.6, 0.12, 0.6), "size": Vector2(1.5, 1.1)},
		{"at": front + Vector3(2.5, 0.12, 0.5), "size": Vector2(1.3, 1.0)},
	], "mine%d" % number)
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
	gate_snow([
		{"at": front + Vector3(0, 7.3, -1.9), "size": Vector2(width * 0.9, 1.6), "under": 6.8, "long": 1.6},
		{"at": front + Vector3(-width * 0.3, 0.12, 2.6), "size": Vector2(2.6, 1.8)},
		{"at": front + Vector3(width * 0.3, 0.12, 2.8), "size": Vector2(2.4, 1.8)},
	], "elder")
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
	gate_snow([
		{"at": front + Vector3(-2.2, 6.8, -1.4), "size": Vector2(1.4, 1.6)},
		{"at": front + Vector3(2.3, 4.8, -1.4), "size": Vector2(1.2, 1.6)},
		{"at": front + Vector3(0.1, 5.4, -1.4), "size": Vector2(3.2, 1.6), "under": 4.4},
		{"at": front + Vector3(-3.0, 0.12, 0.8), "size": Vector2(1.6, 1.2)},
		{"at": front + Vector3(3.2, 0.12, 1.0), "size": Vector2(1.4, 1.2)},
		{"at": front + Vector3(0.0, 0.12, 2.6), "size": Vector2(2.2, 1.2)},
	], "spire")
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
	var walls := ClimbSpots.wall_cells(self)
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "=":
				continue
			# A climbable terrace (see ClimbSpots) is a block only as high as the terrace.
			var spot := ClimbSpots.at(self, c)
			if not spot.is_empty():
				_add_box(_walls_body, cell_to_world(c) + Vector3(0, spot.height * 0.5, 0), Vector3(TILE, spot.height, TILE))
				continue
			if walls.has(c):
				_add_box(_walls_body, cell_to_world(c) + Vector3(0, 6, 0), Vector3(TILE, 12, TILE))
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
	# An easter egg on the spire's peak: a penguin with a banner.
	chapel.add_child(ChapelPenguin.build(self))
	var spill := MeshInstance3D.new()
	spill.name = "ChapelSpill"
	spill.mesh = ChapelSpill.build_mesh()
	spill.material_override = _chapel_spill_material()
	spill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Not a part of the chapel itself: a sibling with the chapel's own placement.
	add_child(spill)
	# The kit is built to cathedral scale: shrink it to fit the block, and
	# move it so that the steps in front of the door stay inside it too.
	var s := minf(room.x / CHAPEL_FOOT.x, room.y / CHAPEL_FOOT.y)
	chapel.scale = Vector3.ONE * s
	chapel.rotation.y = rot
	chapel.position = center - (Vector3(0, 0, CHAPEL_FOOT_MID) * s).rotated(Vector3.UP, rot)
	spill.transform = chapel.transform
	bare_ground.append_array(ChapelSpill.ground_outlines(chapel.transform))
	add_child(chapel)
	_build_temple_lamps(chapel)
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
		# The temple's windows are lit by day and brighter still at night (see set_hour).
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


## The coloured pools of the temple's glass on the ground (see ChapelSpill);
## they glow with the windows all night.
func _chapel_spill_material() -> ShaderMaterial:
	if not _scenes.has("mat_chapel_spill"):
		var mat := ChapelSpill.material(WINDOW_GLOW)
		_scenes["mat_chapel_spill"] = mat
	return _scenes["mat_chapel_spill"]


## The curtains and passing figures behind Weavers' Lane's lit windows (see
## WindowLife); set_hour drives it like the glass.
func _life_material() -> ShaderMaterial:
	if not _scenes.has("mat_window_life"):
		var mat := WindowLife.material(WINDOW_LIGHT)
		_scenes["mat_window_life"] = mat
		_window_mats[mat] = mat
	return _scenes["mat_window_life"]


## The window panes of the villagers' houses: dark by day, warm at night
## (see set_hour).
func _house_glass() -> ShaderMaterial:
	if not _scenes.has("mat_house_glass"):
		var glass := WindowLights.glass_material(WINDOW_LIGHT)
		_scenes["mat_house_glass"] = glass
		_window_mats[glass] = glass
		# The curtains inside the windows one looks through go with it.
		var curtains := VillageHouse.curtain_cloth()
		curtains.set_shader_parameter("colour", Vector3(WINDOW_LIGHT.r, WINDOW_LIGHT.g, WINDOW_LIGHT.b))
		_window_mats[curtains] = curtains
		# The same pane seen from inside a room never shines by itself.
		var inner := VillageHouse.inner_glass()
		_window_mats[inner] = inner
		# The shutters swing shut with the curtains.
		var shutters := VillageHouse.shutters()
		_window_mats[shutters] = shutters
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
		# The way each beam runs, for the grain of its wood.
		mi.mesh = AgedStone.grained_mesh(mi.mesh)
		for surface in mi.mesh.get_surface_count():
			mi.set_surface_override_material(surface, _window_mats[mat])
		# Its windows are clear glass over curtains, like the houses' (see _house_glass), not the
		# palette's flat white; the ivy and the snow learn where they are.
		var glass_surfaces := AgedStone.pane_surfaces(mi.mesh)
		if glass_surfaces.is_empty():
			continue
		var glass := _house_glass()
		for surface: int in glass_surfaces:
			mi.set_surface_override_material(surface, glass)
		# Hinged shutters on those windows, which shut at night like the houses' (see VillageHouse.shutters_for).
		var into: Transform3D = (node as Node3D).global_transform.affine_inverse() * mi.global_transform
		var leaf_windows: Array = []
		for pane: Dictionary in AgedStone.panes_of(mi.mesh):
			var wide := float(pane.wide)
			var high := float(pane.high)
			if wide < 0.03 or high < wide * 0.9 or high > wide * 1.8:
				continue # a slit or an arch in a gable, no window for shutters
			leaf_windows.append({"at": into * (pane.at as Vector3), "out": (into.basis * (pane.out as Vector3)).normalized(),
					"wide": wide * into.basis.get_scale().x, "high": high * into.basis.get_scale().y})
		if not leaf_windows.is_empty() and node is Node3D and node.get_parent() == self:
			var made := VillageHouse.shutters_for(leaf_windows)
			var leaves := MeshInstance3D.new()
			leaves.name = "Shutters"
			leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			leaves.mesh = made.mesh
			node.add_child(leaves)
			var hinges: Array = node.get_meta("shutter_hinges", []) if node.has_meta("shutter_hinges") else []
			hinges.append_array(made.hinges)
			node.set_meta("shutter_hinges", hinges)
		var windows: Array = node.get_meta("windows", []) if node.has_meta("windows") else []
		var outs: Array = node.get_meta("window_outs", []) if node.has_meta("window_outs") else []
		if windows.size() != outs.size():
			continue
		for pane: Dictionary in AgedStone.panes_of(mi.mesh):
			windows.append(into * (pane.at as Vector3))
			outs.append((into.basis * (pane.out as Vector3)).normalized())
		node.set_meta("windows", windows)
		node.set_meta("window_outs", outs)


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
func _dress_building(node: Node3D, middle: Vector3, door_spots: Array, nest_chance := 0.75, patches := AgedStone.IVY_PATCHES, old := false, foot_max := 0.0, proud := 0.0, window_room := 1.0, all_sides := false, roof_vines := 0, cap_from := SnowCaps.LOWEST, then := Callable()) -> void:
	# Stone buildings (old) also carry icicles under their ledges.
	if old:
		patches = maxi(patches, AgedStone.OLD_IVY_PATCHES)
	var key := "%s|%s|%s|%s|%s|%s" % [level_name, middle, _bounds_in(node), old, foot_max, proud]
	var job := {}
	if not _dressed.has(key) and not _dress_keys.has(key):
		job = _dress_prepare(node, middle, door_spots, nest_chance, patches, old, foot_max, proud, window_room, all_sides, roof_vines, cap_from, key)
	var entry := {"node": node, "middle": middle, "key": key, "job": job, "then": then}
	if not _dress_batch:
		if not job.is_empty():
			_dress_grow(job)
		_dress_apply(entry)
		return
	# While the village is being built the ivy and the snow are grown on the worker threads, as the
	# buildings come, and put in their places in the same order at the end (see _dress_settle).
	if not job.is_empty():
		_dress_keys[key] = true
		job["task"] = WorkerThreadPool.add_task(_dress_grow.bind(job), true)
	_dress_queue.append(entry)


## Opens a walked-in house once its dressing is in place (see _dress_building).
func _open_house(node: Node3D) -> void:
	if walk_in.has(node):
		walk_in.open_house(node)


## Starts collecting dressings (see _dress_building) to grow side by side; `_dress_settle` ends it.
func _dress_collect() -> void:
	_dress_batch = true


## Waits for every dressing collected and puts each in its place, in the order they were asked for,
## so the village comes out the same as if they had been done one by one.
func _dress_settle() -> void:
	var queue := _dress_queue
	_dress_queue = []
	for entry: Dictionary in queue:
		var job: Dictionary = entry.job
		if job.has("task"):
			WorkerThreadPool.wait_for_task_completion(job.task)
	_dress_batch = false
	for entry: Dictionary in queue:
		_dress_apply(entry)
	_dress_keys.clear()


## Everything a dressing reads from the scene (the part that must run on the main thread): the
## building's triangles, windows, doors and chimney, with the dice it will use.
func _dress_prepare(node: Node3D, middle: Vector3, door_spots: Array, nest_chance: float, patches: int, old: bool, foot_max: float, proud: float, window_room: float, all_sides: bool, roof_vines: int, cap_from: float, key: String) -> Dictionary:
	var job := {"key": key, "middle": middle, "nest_chance": nest_chance, "patches": patches, "old": old, "foot_max": foot_max,
			"proud": proud, "window_room": window_room, "all_sides": all_sides, "roof_vines": roof_vines, "cap_from": cap_from}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	job["rng"] = rng
	# The meshes are read in world space (a copy of the village is built
	# far below, see WorldPreload); the ivy and the nest are kept in the
	# village's own.
	var offset := global_position
	var tris := AgedStone.triangles(node)
	var ground := node.global_position.y
	var doors_at := door_spots.map(func(d: Vector3): return d + offset)
	# Window panes the house builder noted (see VillageHouse), in world space.
	var panes: Array = (node.get_meta("windows", []) as Array).map(func(w: Vector3): return node.global_transform * w)
	if panes.is_empty():
		panes = AgedStone.window_panes(tris, WINDOW_UV)
	panes.append_array(AgedStone.glass_boxes(tris))
	var ivy_tris := tris
	var roof_reach := 0.0
	var density := AgedStone.IVY_DENSITY
	if node.has_meta("shape") and bool((node.get_meta("shape") as Dictionary).get("mage", false)):
		ivy_tris = MageTower.ivy_faces(node, tris)
		roof_reach = MageTower.IVY_ROOF_REACH + float(GuildHall.layout(node.get_meta("shape")).deck) + MageTower.TOP_H
		density = MageTower.IVY_DENSITY # Three floors and a roof: more ivy than a house, to cover the top room too.
	# Never by a chimney or a fire, where the birds would be smoked.
	var smoky: Array = []
	if node.has_meta("chimney"):
		smoky.append(node.global_transform * (node.get_meta("chimney") as Vector3))
	for w: Vector4 in warm_spots:
		smoky.append(Vector3(w.x, w.y, w.z) + offset)
	# Its snow with a body: caps on the roofs and ledges, icicles at the eaves and windows
	# (shown only while snow lies, see SnowCaps), with dice of their own.
	var ice_rng := RandomNumberGenerator.new()
	ice_rng.seed = hash(key + "schnee")
	# The snow's materials are made once, here, before the threads need them.
	SnowCaps.cap_material()
	SnowCaps.ice_material()
	job.merge({"offset": offset, "tris": tris, "ground": ground, "doors_at": doors_at, "panes": panes, "ivy_tris": ivy_tris,
			"roof_reach": roof_reach, "density": density, "smoky": smoky, "ice_rng": ice_rng,
			"snow_windows": SnowCaps.windows_of(node, tris, WINDOW_UV), "snow_ledges": SnowCaps.ledges_of(node),
			"in_village": _in_village(world_to_cell(middle))})
	return job


## The dressing's own work, on its own data only (so it can run on a worker thread): its ivy, the
## spot for a nest and the snow caps.
func _dress_grow(job: Dictionary) -> void:
	var rng: RandomNumberGenerator = job.rng
	var offset: Vector3 = job.offset
	var tris: Array = job.tris
	var ground: float = job.ground
	var leaves := {"xforms": [], "colours": []}
	AgedStone.grow_ivy(job.ivy_tris, job.middle + offset, ground, job.doors_at, rng, leaves, job.patches, job.old, job.panes, job.foot_max, job.proud, job.window_room, job.all_sides, job.roof_vines, job.density, job.roof_reach)
	for i in leaves.xforms.size():
		leaves.xforms[i] = (leaves.xforms[i] as Transform3D).translated(-offset)
	var stems: Array = leaves.get("stems", [])
	for i in stems.size():
		stems[i] = (stems[i] as Transform3D).translated(-offset)
	var grapes: Array = leaves.get("grapes", [])
	for i in grapes.size():
		grapes[i] = (grapes[i] as Transform3D).translated(-offset)
	var spot := Vector3.INF
	if rng.randf() < float(job.nest_chance):
		spot = AgedStone.nest_spot(tris, ground, job.smoky)
	job["leaves"] = leaves
	job["spot"] = spot
	job["turn"] = rng.randf() * TAU
	job["caps"] = SnowCaps.build(tris, ground, job.snow_windows, job.ice_rng, -offset, job.cap_from, job.old, job.snow_ledges)


## The rest of a dressing, in the village's own order: the grass at the foot (it keeps clear of the
## buildings dressed before), then everything put into place (see _dress_building).
func _dress_apply(entry: Dictionary) -> void:
	var node: Node3D = entry.node
	var middle: Vector3 = entry.middle
	var key: String = entry.key
	var job: Dictionary = entry.job
	if not job.is_empty():
		var offset: Vector3 = job.offset
		var tris: Array = job.tris
		var ground: float = job.ground
		# Grass, flowers and mossy stones at its foot (see WallFoot), with dice of their own.
		var foot_rng := RandomNumberGenerator.new()
		foot_rng.seed = hash(key + "fuss")
		var fringe := {}
		WallFoot.grow(tris, middle + offset, ground, job.doors_at, foot_rng, fringe, func(at: Vector3, stone: bool) -> bool: return _fringe_ground(at - offset, stone), WallFoot.look_for(job.in_village))
		for kind: String in fringe:
			var xforms: Array = fringe[kind].xforms
			for i in xforms.size():
				xforms[i] = (xforms[i] as Transform3D).translated(-offset)
		var outline := WallFoot.footprint(tris, middle + offset, ground)
		for i in outline.size():
			outline[i] -= Vector2(offset.x, offset.z)
		var spot: Vector3 = job.spot
		_dressed[key] = {"leaves": job.leaves, "nest": spot - offset if spot != Vector3.INF else spot, "turn": job.turn, "caps": job.caps, "fringe": fringe, "outline": outline}
	_dress_place(node, key)
	if entry.then.is_valid():
		(entry.then as Callable).call()


## Puts a dressing made for `key` on `node`: its footprint, grass, snow, ivy and nest.
func _dress_place(node: Node3D, key: String) -> void:
	var done: Dictionary = _dressed[key]
	_add_footprint(done.get("outline", PackedVector2Array()))
	for kind: String in done.get("fringe", {}):
		if not _fringe.has(kind):
			_fringe[kind] = {"xforms": [], "colours": []}
		_fringe[kind].xforms.append_array(done.fringe[kind].xforms)
		_fringe[kind].colours.append_array(done.fringe[kind].colours)
	var cap_node := SnowCaps.node_for(done.get("caps"))
	if cap_node:
		add_child(cap_node)
	# A building one can walk into keeps the ivy up on its upper floor and roof and on its front
	# wall apart, to hide with them while the hero is inside (see WalkIn); its snow too.
	var leaves: Dictionary = done.leaves
	if walk_in != null and walk_in.has(node):
		leaves = walk_in.split_ivy(node, leaves)
		walk_in.add_upper(node, cap_node)
	_ivy.xforms.append_array(leaves.xforms)
	_ivy.colours.append_array(leaves.colours)
	if leaves.has("stems"):
		if not _ivy.has("stems"):
			_ivy["stems"] = []
			_ivy["stem_colours"] = []
		_ivy.stems.append_array(leaves.stems)
		_ivy.stem_colours.append_array(leaves.stem_colours)
	if leaves.has("grapes"):
		if not _ivy.has("grapes"):
			_ivy["grapes"] = []
			_ivy["grape_colours"] = []
		_ivy.grapes.append_array(leaves.grapes)
		_ivy.grape_colours.append_array(leaves.grape_colours)
	if done.nest == Vector3.INF or nests.size() >= MAX_NESTS:
		return
	var nest := MeshInstance3D.new()
	nest.name = "Nest"
	nest.mesh = AgedStone.nest_mesh()
	nest.rotation.y = done.turn
	nest.position = done.nest
	add_child(nest)
	nests.append(done.nest)
	if walk_in != null:
		walk_in.add_upper(node, nest)


## Whether `at` lies on the forecourt of an entrance out in the country (see _wild_fringe).
func _in_forecourt(at: Vector3) -> bool:
	var c := world_to_cell(at)
	return _forecourts.any(func(f): return (f.block as Rect2i).grow(1).has_point(c))


## Grass, flowers and stones at the foot of a few pieces out in the country (an entrance's arch and
## columns, standing round `middle`), in the wild look (see WallFoot.look_for); `door_spots` stay clear.
## Abandoned and overgrown, the grass comes up through its paving too.
func _wild_fringe(parts: Array, middle: Vector3, door_spots: Array) -> void:
	var offset := global_position
	var tris: Array = []
	for part: Node3D in parts:
		tris.append_array(AgedStone.triangles(part, true))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|wild" % [level_name, middle])
	var fringe := {}
	WallFoot.grow(tris, middle + offset, offset.y, door_spots.map(func(d: Vector3): return d + offset), rng, fringe,
			func(at: Vector3, _stone: bool) -> bool: return _fringe_ground(at - offset, true), WallFoot.look_for(false))
	for kind: String in fringe:
		if not _fringe.has(kind):
			_fringe[kind] = {"xforms": [], "colours": []}
		for i in fringe[kind].xforms.size():
			_fringe[kind].xforms.append((fringe[kind].xforms[i] as Transform3D).translated(-offset))
			_fringe[kind].colours.append(fringe[kind].colours[i])


## Mossy stones all along the foot of the temple's front (see WallFoot.stone_row), which its wide
## doorway clearance would leave a hard, straight line; only its steps stay free.
func _temple_stones(chapel: Node3D, middle: Vector3, door: Vector3, out: Vector3) -> void:
	var offset := global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|temple stones" % level_name)
	var row := {}
	WallFoot.stone_row(AgedStone.triangles(chapel, true), middle + offset, offset.y, out, door + offset, TEMPLE_STEPS_CLEAR, rng, row,
			func(at: Vector3, _stone: bool) -> bool: return _fringe_ground(at - offset, true))
	if not _fringe.has("stone"):
		_fringe["stone"] = {"xforms": [], "colours": []}
	for i in row.stone.xforms.size():
		_fringe.stone.xforms.append((row.stone.xforms[i] as Transform3D).translated(-offset))
		_fringe.stone.colours.append(row.stone.colours[i])


## Whether grass, flowers or a stone may grow at the foot of a wall at `at` (see WallFoot): on open
## grass or soil, not on paving or a path's stones (a `stone` may lie there), not on the temple
## glass's light, not in water, not inside a building (see _footprints).
func _fringe_ground(at: Vector3, stone := false) -> bool:
	var c := world_to_cell(at)
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height or "~;≈‖#".contains(cell_char(c)):
		return false
	var p := Vector2(at.x, at.z)
	for outline: PackedVector2Array in _footprints.get(c, []):
		if Geometry2D.is_point_in_polygon(p, outline):
			return false
	return (stone or not _paved_at(at)) and not on_bare_ground(at, 0.3)


## Notes where a building stands (its outline on the ground, see WallFoot.footprint), by the tiles it covers.
func _add_footprint(outline: PackedVector2Array) -> void:
	if outline.size() < 3:
		return
	var box := Rect2(outline[0], Vector2.ZERO)
	for q in outline:
		box = box.expand(q)
	var lo := world_to_cell(Vector3(box.position.x, 0, box.position.y))
	var hi := world_to_cell(Vector3(box.end.x, 0, box.end.y))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var c := Vector2i(x, y)
			if not _footprints.has(c):
				_footprints[c] = []
			_footprints[c].append(outline)


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
	bed_spots = FlowerBeds.find(self)
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
	# The flower beds sit in the lane's seam: no bare square of joints is left under them.
	FlowerBeds.pave(_ground_img, bed_spots, TILE)
	_ground_tex.update(_ground_img)


## Whether one of the leaf apple trees stands on a tile (no building plot may cover it, see Plots.problem).
func has_leaf_tree(c: Vector2i) -> bool:
	return leaf_trees.any(func(t): return t.cell == c)


## Whether a tile lies within the village's reach (see Plots: no building plots there).
func near_village(c: Vector2i) -> bool:
	return _in_village(c)


## The middle of the village in map tiles: the mean of its buildings. Plots are named by the way
## from here (see Plots.area_of).
func village_centre() -> Vector2:
	if _village_middle.x < 0.0:
		var sum := Vector2.ZERO
		var count := 0
		for y in height:
			for x in width:
				if VILLAGE_BLOCKS.contains(cell_char(Vector2i(x, y))):
					sum += Vector2(x, y)
					count += 1
		_village_middle = sum / count + Vector2(0.5, 0.5) if count > 0 else Vector2(width, height) * 0.5
	return _village_middle


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
				# Never over the temple glass's light on the grass (bare_ground), a full bush's
				# width (AgedStone.grow_bush) away.
				if _near_barber(at) or Mountains.near_rock(self, at.x, at.z, Mountains.BUSH_CLEARANCE) or _paved_at(at) or on_bare_ground(at, 1.6) or _entrances.any(func(e): return Vector2((e.door as Vector3).x - at.x, (e.door as Vector3).z - at.z).length() < 3.0):
					continue
				shrubs.append(at)
				var keep := SHRUB_TEMPLE_KEEP if _near_letter(c, "s", SHRUB_TEMPLE_REACH) else SHRUB_AUTUMN_KEEP
				AgedStone.grow_bush(at, rng, _ivy if _keeps_leaves(at, keep) else _undergrowth_shed, _ivy, _bush_recent)


## Whether `at` lies near Benno's tent: no shrub grows there, so the chair stands clear (see BARBER_CLEAR).
func _near_barber(at: Vector3) -> bool:
	if _barber_tent == Vector3.ZERO:
		_barber_tent = Vector3.INF
		for y in height:
			for x in width:
				if cell_char(Vector2i(x, y)) == "Z":
					_barber_tent = cell_to_world(Vector2i(x, y - 1))
	return _barber_tent != Vector3.INF and Vector2(_barber_tent.x - at.x, _barber_tent.z - at.z).length() < BARBER_CLEAR


## Whether a spot on the ground lies on or within `radius` of ground kept bare (bare_ground).
func on_bare_ground(at: Vector3, radius: float) -> bool:
	var p := Vector2(at.x, at.z)
	for outline: PackedVector2Array in bare_ground:
		if Geometry2D.is_point_in_polygon(p, outline):
			return true
		for i in outline.size():
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i + 1) % outline.size()])) < radius:
				return true
	return false


## Whether a bush at `at` keeps its leaves in autumn, `keep` being the share that do: dice of its
## own (from the spot), so the bushes' looks stay as they were.
static func _keeps_leaves(at: Vector3, keep: float) -> bool:
	return float(posmod(hash(Vector2i(roundi(at.x * 10.0), roundi(at.z * 10.0))), 1000)) / 1000.0 < keep


## Whether a tile within `reach` tiles of `c` carries the map letter `ch`.
func _near_letter(c: Vector2i, ch: String, reach: int) -> bool:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if cell_char(c + Vector2i(dx, dy)) == ch:
				return true
	return false


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
				CosyBed.build(self, cell_to_world(c), 0.0)
				_add_solid(cell_to_world(c), Vector3(3.2, 1.5, 3.2))
				stations.append({"kind": "bett", "cell": c, "pos": cell_to_world(c), "rot": 0.0, "used": false,
						"spot": pillow_spot(cell_to_world(c), 0.0)})
				home_spot = cell_to_world(c + Vector2i(0, 1))
				fox_beds.append(home_spot + Vector3(1.2, 0, -0.6))
			elif ch == "L":
				FittedChest.place(self, "oak", cell_to_world(c), _back_to_wall(c))
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


## The alarm horn the guard blows, just inside the west gate (see WarHorn). The hero
## can blow it too: it is a station (WarHorn.KIND).
func _build_war_horn() -> void:
	war_horn_at = WarHorn.spot(self)
	if war_horn_at != Vector3.INF:
		VillageProps.build_war_horn(self, war_horn_at, WarHorn.facing(self, war_horn_at))
		_add_solid(war_horn_at, Vector3(1.4, 1.0, 1.4))
		stations.append({"kind": WarHorn.KIND, "cell": world_to_cell(war_horn_at), "pos": war_horn_at, "used": false})


## The hero's horn call: everyone in the village who has time comes to the square
## around the herald (see _call_the_village). Returns whether anyone was called
## (false without a herald out on the square).
func gather_village() -> bool:
	if _herald == null or _herald.at_home or not _herald.visible or night:
		return false
	_call_the_village(INF, false)
	return true


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
			# Whoever keeps a hall one walks into has their place before its door (see _keeper_home).
			v.home = _keeper_home(ch, c)
			add_child(v)
			v.global_position = cell_to_world(v.home)
			villagers.append(v)
			# The shopkeeper trades like the merchant in the refuge; the
			# banker and the barber open their own menus.
			var kind: String = {"6": "haendler", "Y": "bank", "O": "tempel", "S": "steinmetz", "1": "schmied", "3": "holzfaeller", "¢": PlotOffice.KIND, "µ": "raumausstatter", "ü": Mill.KIND, ClimberNpc.ROLE: ClimberNpc.KIND, Beekeeper.ROLE: Beekeeper.KIND, Prospector.ROLE: Prospector.KIND}.get(ch, "npc")
			var station := {"kind": kind, "cell": v.home, "pos": cell_to_world(v.home), "used": false, "npc": v}
			v.station = station
			stations.append(station)
			if ch == "0":
				_elder = v
			elif ch == "K":
				_herald = v
			elif ch == "Z":
				var tent_cell := c + Vector2i(0, -1)
				barber_chair.build(self, v, _build_barber_shop(tent_cell), cell_to_world(tent_cell))
			elif ch == "S":
				_build_stone_yard(c + MASON_YARD)
				_build_quarry(v, c)
			elif ch == "1":
				_build_forge(c + Vector2i(-1, 0))
				_build_anvil(v, c, Vector3.LEFT)
			elif ch == "3":
				_build_chopping_log(v, c)
				WoodLogs.build(self, c)
	_spawn_pips_friend()
	_spawn_street_sweeper()
	WoodLogs.build_windfalls(self)


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


## The street sweeper (see StreetSweeper) has no map letter either: he waits on a walkway near the square.
func _spawn_street_sweeper() -> void:
	var c := StreetSweeper.home_cell(self)
	if c == Vector2i(-1, -1):
		return
	var v := Villager.new()
	v.setup(self, StreetSweeper.ROLE, c)
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
func _build_barber_shop(cell: Vector2i) -> Node3D:
	var pos := cell_to_world(cell)
	# Built by hand (see BarberTent): round timber poles and a saggy linen roof. One can walk in under it:
	# the chair stands there (see BarberChair), and the tent fades away while someone sits.
	var tent := BarberTent.build()
	tent.position = pos
	add_child(tent)
	var pole := Effects.barber_pole()
	pole.position = pos + Vector3(-2.6, 0, 2.4)
	add_child(pole)
	var board := Effects.shop_sign(Lang.t("Barbier"), preload("res://assets/fonts/Cinzel-Bold.woff2"), "scissors")
	WeatheredProps.weather_plain(board)
	board.position = pos + Vector3(2.2, 0, 2.4)
	add_child(board)
	_add_solid(pos + Vector3(-2.6, 0, 2.4), Vector3(0.5, 2.6, 0.5))
	_add_solid(pos + Vector3(2.2, 0, 2.4), Vector3(0.5, 2.6, 0.5))
	return tent


## The stonemason's yard beside his house, to its right as you face the door
## (MASON_YARD): blocks of carved stone stacked up for sale and a sign. It stays
## off the doorway and off the paved way that runs from the door to the road.
func _build_stone_yard(cell: Vector2i) -> void:
	var pos := cell_to_world(cell) + Vector3(MASON_YARD_SHIFT, 0, 0)
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
	# Just round the blocks (x -1.7 to 1.55, z -1.0 to 1.0), so it stays inside the tile.
	_add_solid(pos + Vector3(-0.075, 0, 0), Vector3(3.3, StoneBlock.HEIGHT * 2.0, 2.2))
	astar.set_point_solid(cell, true)
	var board := Effects.shop_sign(Lang.t("Steinmetz"), preload("res://assets/fonts/Cinzel-Bold.woff2"), "stone")
	WeatheredProps.weather_plain(board)
	board.position = pos + Vector3(-1.6, 0, 1.9)
	add_child(board)
	_add_solid(pos + Vector3(-1.6, 0, 1.9), Vector3(0.5, 2.6, 0.5))


## The stonemason's quarry: a small hill of rock west of him, cleared out of
## the forest (see QuarryHill), with a rough block at its foot that he chips
## with his hammer (see Villager.set_chopping) and a few cut blocks beside it.
func _build_quarry(v: Villager, cell: Vector2i) -> void:
	QuarryHill.build(self, cell)
	QuarryRocks.build(self, cell)
	var face := Vector3.LEFT
	var stand := cell_to_world(cell)
	var spot := Node3D.new()
	spot.name = "QuarryBlock"
	spot.position = stand
	spot.rotation.y = atan2(face.x, face.z)
	add_child(spot)
	var rock := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.85, 0.95, 0.7)
	rock.mesh = box
	var rough := StandardMaterial3D.new()
	rough.albedo_color = Color(0.5, 0.48, 0.45)
	rough.roughness = 1.0
	rock.material_override = rough
	rock.position = Villager.ANVIL_AT + Vector3(0, 0.475, 0)
	rock.rotation.y = 0.12
	spot.add_child(rock)
	# Cut blocks beside the rock, and flakes from earlier blows.
	for part in [[Vector3(0.9, 0, 0.9), 1], [Vector3(1.0, StoneBlock.HEIGHT, 0.9), 2], [Vector3(-1.4, 0, 0.1), 3]]:
		var block := StoneBlock.make_model(StoneBlock.SHADES[part[1]])
		block.position = part[0]
		# Fixed turns, so the quarry never shifts the village's random numbers.
		block.rotation.y = (part[1] - 2) * 0.1
		spot.add_child(block)
	var flake := BoxMesh.new()
	flake.size = Vector3(0.12, 0.03, 0.08)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.62, 0.6, 0.57)
	for at in [Vector3(-0.2, 0, 0.9), Vector3(-1.0, 0, 1.0), Vector3(-0.5, 0, 1.8), Vector3(0.1, 0, 1.6), Vector3(-1.1, 0, 1.6)]:
		var f := MeshInstance3D.new()
		f.mesh = flake
		f.material_override = grey
		f.position = at + Vector3(0, 0.015, 0)
		f.rotation.y = at.x * 7.0 + at.z * 3.0
		spot.add_child(f)
	var chips := Effects.make_stone_chips()
	chips.position = Villager.HAMMER_POINT
	spot.add_child(chips)
	_add_solid(spot.to_global(Villager.ANVIL_AT), Vector3(0.7, 0.95, 0.85))
	v.global_position = stand
	v.rotation.y = spot.rotation.y
	v.set_chopping(stand, face, chips)


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
	warm_spots.append(Vector4(coals.x, coals.y, coals.z, 1.8))
	warm_spots.append(Vector4(top.x, top.y, top.z, 1.6))
	var plume := ChimneySmoke.make()
	plume.position = top + Vector3(0, 0.25, 0)
	_fixed_seed(plume, 3)
	add_child(plume)
	ChimneySmoke.light(plume, true, true)
	_add_solid(pos, Vector3(3.2, 1.2, 3.0))
	astar.set_point_solid(cell, true)
	var board := Effects.shop_sign(Lang.t("Schmiede"), preload("res://assets/fonts/Cinzel-Bold.woff2"), "anvil")
	WeatheredProps.weather_plain(board)
	# On the grass beside the paved way to the forge, its shield hanging out over the way.
	board.position = pos + SMITH_SIGN
	add_child(board)
	_add_solid(pos + SMITH_SIGN, Vector3(0.5, 2.6, 0.5))
	# His wares on the grass beside the forge, away from the paved way to it (see ShopFronts).
	var wares := ShopFronts.smith_yard()
	wares.position = pos + SMITH_WARES
	add_child(wares)
	for part: Array in wares.get_meta("solids"):
		_add_solid(wares.position + (part[0] as Vector3) - Vector3(0, (part[1] as Vector3).y * 0.5, 0), part[1])
	astar.set_point_solid(cell + Vector2i(-1, 0), true)


## Where the villager of `role` (on map tile `cell`) has their place: the tile before the door of
## the hall they keep, when it is one to walk into (see VillageHalls.KEEPERS), so they walk in and
## out from there and wait there after closing time; else their own tile.
func _keeper_home(role: String, cell: Vector2i) -> Vector2i:
	var kind := VillageHalls.kept_by(role)
	# The priestess waits at the temple's porch, to one side of the way in, never in its doorway.
	if role == TEMPLE_KEEPER:
		kind = "temple"
	if kind == "":
		return cell
	for rec in walk_in.buildings:
		if rec.kind == kind and rec.get("opened", false):
			# A free tile out from the door, clear of the hall's own block, and a tile to the side
			# of the way in, so whoever waits there never stands in the doorway.
			var way := walk_in.door_points(rec)
			var out := way[0] - way[1]
			out.y = 0.0
			out = out.normalized()
			var side := Vector3(-out.z, 0, out.x)
			for step in 4:
				for aside: float in [1.0, -1.0]:
					var before := world_to_cell(way[0] + out * step * TILE * 0.5 + side * aside * TILE)
					if not (rec.block as Rect2i).has_point(before) and astar.is_in_boundsv(before) and not astar.is_point_solid(before):
						return before
	return cell


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


## The village cat of the big smithy: it strolls about and naps on the lid of the barrel that stands
## beside the stacked granite blocks next to the smithy (the closest such barrel). Without the smithy
## or such a barrel it has no cat.
func _adopt_cat() -> void:
	if _smithy_node == null:
		return
	var home := _smithy_node.global_position
	var stones: Array[Vector3] = []
	var barrels: Array[Node3D] = []
	for c in get_children():
		if not (c is Node3D) or c.get_child_count() == 0 or c.global_position.distance_to(home) > 16.0:
			continue
		var kind := String(c.get_child(0).name)
		if kind.begins_with("resource_stone"):
			stones.append(c.global_position)
		elif kind.begins_with("barrel"):
			barrels.append(c)
	var perch: Node3D
	var best := INF
	for b in barrels:
		for st in stones:
			var d := Vector2(b.global_position.x - st.x, b.global_position.z - st.z).length()
			if d < best:
				best = d
				perch = b
	if perch == null or best > 6.0:
		return
	var lid := _lid_of(perch)
	var away := lid - home
	# No snow settles on the lid or round it: the cat's bed stays bare and dry all winter, warm
	# from the forge beside it.
	warm_spots.append(Vector4(lid.x, lid.y - 0.5, lid.z, 0.9))
	var cat := VillageCat.new()
	cat.name = "VillageCat"
	cat.setup(self, lid, away)
	add_child(cat)
	village_cat = cat


## The middle of the top of a barrel prop (world).
func _lid_of(barrel: Node3D) -> Vector3:
	var top := barrel.global_position
	var high := 0.0
	for mi in barrel.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		high = maxf(high, box.end.y)
		top = Vector3(box.get_center().x, 0.0, box.get_center().z)
	top.y = high
	return top


## The fire of the big smithy behind the little forge (block "j"): the coals in its furnace's mouth
## glow and flicker, a flame and embers drift out of the top of its chimney, and a few more embers
## rise in the mouth. The effects stand at the model's fire spots (SMITHY_FIRES) in the
## open air, not inside the model, so they keep their size; no real light, so nothing leaks through
## the walls. `s` is the model's scale.
func _smithy_fire(node: Node3D, s: float) -> void:
	var mouth_at: Vector3 = node.transform * Vector3(SMITHY_FIRES[0].x, SMITHY_FIRES[0].y, SMITHY_FIRES[0].z)
	var top: Vector3 = node.transform * Vector3(SMITHY_FIRES[1].x, SMITHY_FIRES[1].y, SMITHY_FIRES[1].z)
	# The coals in the furnace's mouth glow and flicker (a small emissive ball, no flat plate, no
	# real light).
	var glow := MeshInstance3D.new()
	glow.name = "SmithyMouthGlow"
	var ball := SphereMesh.new()
	ball.radius = 0.07 * s
	ball.height = 0.14 * s
	glow.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.06, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 2.0
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = mouth_at
	add_child(glow)
	var tween := glow.create_tween().set_loops()
	tween.tween_property(mat, "emission_energy_multiplier", 3.0, 0.4)
	tween.tween_property(mat, "emission_energy_multiplier", 1.6, 0.5)
	tween.tween_property(mat, "emission_energy_multiplier", 2.5, 0.3)
	tween.tween_property(mat, "emission_energy_multiplier", 1.9, 0.4)
	var flame := Effects.make_flame()
	flame.position = top + Vector3(0, 0.03 * s, 0)
	flame.scale = Vector3.ONE * 0.4 * s
	_fixed_seed(flame, 4)
	add_child(flame)
	# Embers lift out of the top of the chimney and drift off on the breeze.
	var embers := Effects.make_forge_embers()
	embers.name = "SmithyEmbers"
	embers.emission_box_extents = Vector3(0.12, 0.02, 0.12) * s
	embers.amount = 10
	embers.scale = Vector3.ONE * clampf(s, 0.5, 1.5)
	_fixed_seed(embers, 5)
	embers.position = top + Vector3(0, 0.05 * s, 0)
	add_child(embers)
	# A few more flicker in the furnace's mouth.
	var low := Effects.make_forge_embers()
	low.name = "SmithyMouthEmbers"
	low.emission_box_extents = Vector3(0.1, 0.02, 0.1) * s
	low.amount = 6
	_fixed_seed(low, 6)
	low.position = mouth_at
	add_child(low)


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
	var sapwood := StandardMaterial3D.new()
	sapwood.albedo_color = WoodLogs.SAPWOOD
	sapwood.roughness = 0.9
	# The trunk lies along the woodcutter's left and right (his own x), grown
	# like the felled trunks of his yard (see WoodLogs.trunk_mesh): lumpy,
	# tapering, with a flared root end, fissured bark and ringed sawn ends.
	# Its middle is LOG_RADIUS thick round LOG_CENTRE, where his axe bites.
	var r := Villager.LOG_RADIUS
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var grain_seed := rng.randf_range(0.0, 50.0)
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.mesh = WoodLogs.trunk_mesh(Villager.LOG_LENGTH, r / 1.02, rng)
	trunk.mesh.surface_set_material(0, WoodLogs.log_material(WoodLogs.BARK, r, 0.2, grain_seed, false))
	trunk.mesh.surface_set_material(1, WoodLogs.log_material(WoodLogs.BARK, r, 0.2, grain_seed, true))
	# trunk_mesh lies on the ground: settle it so its axis is at LOG_CENTRE.
	trunk.position = Villager.LOG_CENTRE - Vector3(0, trunk.mesh.get_aabb().get_center().y, 0)
	spot.add_child(trunk)
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
	# The woodcutter's sign stands just past one end of his trunk
	# (clear of his axe and of the way to the trunk), facing back toward the road behind him.
	var board := Effects.shop_sign(Lang.t("Holzplatz"), preload("res://assets/fonts/Cinzel-Bold.woff2"), "axe")
	WeatheredProps.weather_plain(board)
	board.position = Villager.LOG_CENTRE + Vector3(Villager.LOG_LENGTH * 0.5 + 0.7, -Villager.LOG_CENTRE.y, 0)
	board.rotation.y = PI
	spot.add_child(board)
	_add_solid(spot.to_global(board.position), Vector3(0.5, 2.6, 0.5))
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
		if s.kind == "kit":
			_spawn_warren(s.cell)
			continue
		var a := Animal.new()
		a.setup(self, s.kind, s.cell)
		if taken.has(a.tame_key()):
			# The hero's own companion: it lives with the hero now (see Pet).
			a.free()
			continue
		add_child(a)
		a.global_position = cell_to_world(s.cell)
		animals.append(a)


## A burrow on the meadow with its huddle of baby rabbits (see Warren).
func _spawn_warren(cell: Vector2i) -> void:
	var centre := cell_to_world(cell)
	var hole := Warren.burrow(cell.x * 31 + cell.y)
	add_child(hole)
	hole.global_position = centre
	hole.rotation.y = float(hash(cell) % 628) / 100.0
	hole.add_to_group("burrows")
	Warren.dress(hole, season_day)
	for i in Warren.KITS:
		var a := Animal.new()
		a.setup(self, "kit", cell)
		a._rng.seed += i * 977
		add_child(a)
		a.global_position = Warren.start_of(centre, i)
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
		if absf(point.y - d.global_position.y) > WalkIn.DOOR_LEVEL + 0.5:
			continue # A floor above or below the door.
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
func nearest_station(from: Vector3, max_distance := SEARCH_RANGE, skip_spots := false) -> Dictionary:
	var npc := _npc_station_near(from, max_distance)
	if not npc.is_empty() and npc.kind != "npc":
		return npc
	var other := super(from, max_distance, skip_spots)
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
	# The brazier between the dining tables stands in the way while it burns (see MealBraziers).
	meals.braziers.block_paths(self)
	# Villagers and the hero keep to the paths where they can.
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) == ".":
				astar.set_point_weight_scale(c, 1.6)
	village_wall.sync(self)


## By day everything is lit. At night, and in fog, only the lanterns and
## the campfire show the hero to the eyes of enemies: a sneaking hero in the
## dark or the fog stays unseen. There is no fog under the roof of a built house: by day it is lit there.
func is_lit(pos: Vector3) -> bool:
	if not night and (weather != Weather.FOG or is_roofed(pos)):
		return true
	for lamp in _lamps:
		if _flat_distance(pos, lamp.global_position) < LAMP_REACH:
			return true
	for fire in _fires:
		if _flat_distance(pos, fire) < LAMP_REACH:
			return true
	for light in house_lights:
		if _flat_distance(pos, light) < LAMP_REACH:
			return true
	return meals.lights_up(pos, LAMP_REACH)


## Whether a spot lies inside a self-built house (under its roof or in a yard its walls close in, see
## HouseGround.shelter) or a village room: the hero in there is indoors (see hero_indoors).
func is_sheltered(pos: Vector3) -> bool:
	return HouseGround.sheltered(shelters, pos) or (walk_in != null and walk_in.covers(pos))


## Whether a spot lies under a roof, where no weather reaches: under a slab or roof of a self-built
## house (see roofs) or in a village room.
func is_roofed(pos: Vector3) -> bool:
	return HouseGround.sheltered(roofs, pos) or (walk_in != null and walk_in.covers(pos))


## Whether the hero is under cover: in a house (their own or a built one) or down in a house
## cellar (see hero_cellar). The open air's night life (the glowworms) stays out of there.
func hero_under_cover() -> bool:
	return hero_indoors or not hero_cellar.is_empty()


## Inside a built house or their own village house the hero sees out only
## through its windows and open doors (see InsideView); down in a house cellar only
## what is in the cellar (see hero_cellar); outside, everything shows.
func hero_sees(pos: Vector3) -> bool:
	if not hero_cellar.is_empty():
		return CellarView.down_in(hero_cellar, pos)
	# Up on the ground nothing down in the forgotten mine shows (see LostMine).
	if LostMine.holds(pos):
		return false
	if player == null or not hero_indoors:
		return true
	return has_line_of_sight(player.global_position, pos)


## The shut gate of the village wall stops shots too (see VillageWall.shot_blocked).
func shot_blocked(a: Vector3, b: Vector3) -> bool:
	return super(a, b) or village_wall.shot_blocked(a, b)


## The shut gate of the village wall (three courses) hides what is behind it; the wall itself,
## two courses high, does not: villagers and monsters see over it (see VillageWall.shot_blocked).
## Down in the forgotten mine only its tunnels count (see LostMine.sight): the map's tiles lie overhead.
func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	if LostMine.holds(a) or LostMine.holds(b):
		return LostMine.sight(a, b)
	return super(a, b) and not village_wall.shot_blocked(a, b)


func is_opaque(c: Vector2i) -> bool:
	var ch := cell_char(c)
	return ch == "#" or ch == "=" or ch == "I" or (BLOCK_CHARS.contains(ch) and not (walk_in != null and walk_in.opens(c)))


## A building one can walk into stops a reaching hand with its walls, not its whole block (see WalkIn).
func _blocks_reach(c: Vector2i) -> bool:
	if walk_in != null and walk_in.opens(c):
		return false
	return super(c)


## Winter clothes on (or off). Whoever is out of sight changes at once; the rest change as they go
## home to sleep (see Villager.update_wear). `at_once` (a game being loaded, the sky command) changes
## everyone on the spot.
func set_winter_wear(on: bool, at_once := false) -> void:
	# No eggs or chicks in the nests in winter: they come back in spring (see VillageBirds).
	if birds:
		birds.set_winter(on)
	var first := not _wear_known
	if on == winter_wear and not first and not at_once:
		return
	winter_wear = on
	_wear_known = true
	# The braziers round the dining tables burn all winter.
	meals.braziers.set_winter(on, first or at_once)
	for v in villagers:
		v.update_wear(first or at_once)


## The vines on the houses turn with the seasons: red and gold in autumn, snowy and without grapes
## in winter (see IvySeasons); the leafy trees turn with them. `day_of_season` is the season day
## (see Seasons).
func set_season(day_of_season: int) -> void:
	season_day = day_of_season
	IvySeasons.apply(ivy, day_of_season)
	IvySeasons.apply(undergrowth, day_of_season)
	IvySeasons.apply(undergrowth_shed, day_of_season)
	WallFoot.apply(wall_foot, day_of_season)
	# In autumn most undergrowth has shed its leaves, and they lie spread over the ground.
	var autumn := Weather.is_autumn(day_of_season)
	if undergrowth_shed != null:
		undergrowth_shed.visible = not autumn
	if surface_life != null:
		surface_life.set_autumn(autumn)
	AppleTree.dress(square_trees, day_of_season)
	AppleTree.dress(leaf_trees, day_of_season)
	if flower_beds != null:
		flower_beds.set_season(day_of_season)
	if is_inside_tree():
		for hole: Node3D in get_tree().get_nodes_in_group("burrows"):
			Warren.dress(hole, day_of_season)
	if is_inside_tree():
		for flow: StreamFlow in get_tree().get_nodes_in_group(StreamFlow.GROUP):
			flow.set_season(day_of_season)
	if crop_fields != null:
		crop_fields.set_season(day_of_season)
	if crows != null:
		crows.set_season(day_of_season)
	# The leafy trees turn with the vines (see tree.gdshader).
	var at := IvySeasons.stage(day_of_season)
	if at == _tree_stage:
		return
	_tree_stage = at
	var turn := IvySeasons.tree_turn(at)
	for key in _scenes:
		if String(key).begins_with("mat_tree_"):
			(_scenes[key] as ShaderMaterial).set_shader_parameter("autumn", turn.x)
			(_scenes[key] as ShaderMaterial).set_shader_parameter("snowy", turn.y)


## Whether a tile is walkable ground (for villagers picking where to go).
func is_open(c: Vector2i) -> bool:
	return WALK.contains(cell_char(c)) and not astar.is_point_solid(c)


func _process(delta: float) -> void:
	super(delta)
	if player == null:
		return
	village_alarm.tick(self, delta)
	village_wall.tick(self, delta)
	meals.tick(self, delta)
	bench_rest.tick(self, delta)
	barber_chair.tick(self, delta)
	temple_morning.tick(self, delta)
	underground_shadows.tick(self, player.global_position, delta)
	# The wind carries the swept leaves back over the walkways (see LeafSweep).
	LeafSweep.advance(self)
	var cell := world_to_cell(player.global_position)
	# Down in a cellar or the mine the surface's snow prints stay out of sight.
	SnowPrints.set_underground(not hero_cellar.is_empty() or LostMine.holds(player.global_position) or player.global_position.y < UNDERGROUND_Y)
	var inside := _in_house(cell)
	if inside != _inside:
		_inside = inside
		_roof.visible = not inside
		SnowPrints.set_indoors(inside)
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
	if walk_in != null:
		walk_in.tick(player, delta)
	hero_indoors = inside or is_sheltered(player.global_position)
	_inside_view.tick(self, delta)
	if grave_spirit != null and hour >= 0.0:
		grave_spirit.tick(delta, player.global_position, hour)
	if bell_grave != null and hour >= 0.0:
		bell_grave.tick(delta, player.global_position, hour)
	if owls and hour >= 0.0:
		owls.tick(delta, player.global_position, hour, hero_under_cover())
	if crows and hour >= 0.0:
		crows.tick(delta, player.global_position, hour, hero_under_cover())
	if glowworms and hour >= 0.0:
		glowworms.tick(delta, player.global_position, hour, hero_under_cover())
	if apiary and hour >= 0.0:
		apiary.tick(delta, player.global_position, hour, hero_under_cover(), season_day, weather)
	_mind_the_wild(delta)
	_whisper_from_holes(delta)
	_mind_the_night(delta)
	_mind_the_weather(delta)
	_mind_the_moon(delta)
	_check_basket(delta)
	_herald_timer -= delta
	# Not while he sits in the temple for the morning gathering (see TempleMorning).
	if _herald and _herald_timer <= 0.0 and not night and not _herald.serves():
		_herald_timer = randf_range(HERALD_EVERY_MIN, HERALD_EVERY_MAX)
		_call_the_village()
	if not house_given and _elder and not _elder.at_home and _flat_distance(player.global_position, _elder.global_position) < GREET_RANGE:
		house_given = true
		_elder.greet_newcomer(player)
		if not town_houses.is_empty() and not PropertyRegister.settled(hero):
			# The hero's home is a town house on Weavers' Lane (unless they have a home of their own).
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
func _call_the_village(reach := 22.0 * TILE * 0.5, proclaim := true) -> void:
	var stand: Vector3 = _herald.global_position
	if proclaim:
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
		if _flat_distance(v.global_position, stand) > reach:
			continue
		v.gather_at(ring[i], stand)
		i += 1
	if proclaim and player and _flat_distance(player.global_position, stand) < 30.0:
		notice.emit(Lang.t("Der Herold ruft auf dem Marktplatz aus. Das Dorf kommt zusammen."), 3.0)


# --- Day and night ------------------------------------------------------------

## Lights the village for an hour of the day (see DayNight) and, when night
## falls or the day breaks, sends the village to bed or wakes it, and calls
## the dead out of their graves or back into them. The first call after the
## world is built settles everything at once, without a word.
## Each shutter leaf of the village (world position, its key in the shader and whether it was shut at
## the last look): where a leaf swings, it clacks (see _shutter_sounds).
var _leaves: Array = []
var _leaf_scan := -1
var _leaf_hour := -1.0
var _leaf_moving := true
var _built_night := false
## How near the hero a swinging leaf is still heard (metres).
const LEAF_EARSHOT := 38.0


## The shutters clack as they swing shut in the evening and open in the morning, each leaf at its own
## hour (see WindowLights.shutters_shut), at the leaf and not too loud.
func _shutter_sounds() -> void:
	if get_child_count() != _leaf_scan:
		_leaf_scan = get_child_count()
		_leaves = []
		for house in get_children():
			if not (house is Node3D and house.has_meta("shutter_hinges")):
				continue
			var xf: Transform3D = (house as Node3D).global_transform
			var hinges: Array = house.get_meta("shutter_hinges")
			var ranks: Array = house.get_meta("shutter_ranks", [])
			for i in hinges.size():
				var hinge: Vector3 = hinges[i]
				var key := Vector2(hinge.x + xf.origin.x, hinge.z + xf.origin.z)
				var rank: int = int(ranks[i]) if i < ranks.size() else 0
				_leaves.append({"at": xf * hinge, "key": key, "rank": rank, "cloth": false,
						"shut": WindowLights.shutters_shut(key, hour, rank) > 0.5})
			# The mage tower's curtains flap one after another (its windows in the order of the circle).
			var circle: Array = house.get_meta("magic_windows", [])
			for i in circle.size():
				var at: Vector3 = circle[i]
				var key := WindowLights.key(at) + Vector2(xf.origin.x, xf.origin.z)
				_leaves.append({"at": xf * at, "key": key, "rank": i + 1, "cloth": true,
						"shut": WindowLights.curtains_shut(key, hour, i + 1) > 0.5})
	if absf(hour - _leaf_hour) < 0.004:
		return
	_leaf_hour = hour
	# Outside the two bands of the day when shutters swing, nothing is looked at; the states are only
	# brought up to date silently once, as the band ends (or after a jump of the clock).
	var moving := WindowLights.shutters_moving(hour)
	if not moving and not _leaf_moving:
		return
	_leaf_moving = moving
	var heard := 0
	for leaf: Dictionary in _leaves:
		var cloth: bool = leaf.cloth
		var shut := (WindowLights.curtains_shut(leaf.key, hour, leaf.rank) if cloth else WindowLights.shutters_shut(leaf.key, hour, leaf.rank)) > 0.5
		if shut == leaf.shut:
			continue
		leaf.shut = shut
		if not moving:
			continue
		# Only the ones near the hero: a village of sixty windows would otherwise rattle at once.
		if heard < 4 and is_inside_tree() and player != null and (leaf.at as Vector3).distance_to(player.global_position) < LEAF_EARSHOT:
			heard += 1
			if cloth:
				# The tower's magic: a flap of cloth for each curtain.
				Sfx.play(self, "swing", -17.0, leaf.at, 1.9 if shut else 1.6)
			else:
				Sfx.play(self, "door", -14.0 if leaf.rank > 0 else -20.0, leaf.at, 1.25 if shut else 1.1)


func set_hour(new_hour: float) -> void:
	var first := hour < 0.0
	hour = new_hour
	BuiltShutters.hour = new_hour
	# The shutters the hero built swing at nightfall and at dawn: wake them then, not every frame.
	if BuiltShutters.shut_by_night() != _built_night and is_inside_tree():
		_built_night = BuiltShutters.shut_by_night()
		get_tree().call_group("built_shutters", "wake")
	_shutter_sounds()
	var glow := DayNight.glow_at(hour)
	for lamp in _lamps:
		lamp.light_energy = lerpf(LAMP_DAY, LAMP_NIGHT, glow)
	# The wild glow mushrooms and the ones in the lanterns soak up the day and light up with the night.
	GlowMushrooms.set_glow(glow)
	# The lanterns and candles at the dining tables (see TownMeals).
	meals.set_glow(glow)
	if walk_in != null:
		walk_in.set_hour(hour)
	for mat in _window_mats.values():
		if mat is ShaderMaterial:
			mat.set_shader_parameter("glow", WINDOW_GLOW * glow)
			mat.set_shader_parameter("hour", hour)
		else:
			mat.emission_energy_multiplier = WINDOW_GLOW * glow
	# The temple's windows are never dark: lit by day, at full strength at night.
	var chapel_glow := WINDOW_GLOW * lerpf(CHAPEL_DAY_GLOW, 1.0, glow)
	var chapel_glass: StandardMaterial3D = _scenes.get("mat_chapel_glass")
	if chapel_glass:
		chapel_glass.emission_energy_multiplier = chapel_glow
	var chapel_spill: ShaderMaterial = _scenes.get("mat_chapel_spill")
	if chapel_spill:
		chapel_spill.set_shader_parameter("glow", WINDOW_GLOW * lerpf(CHAPEL_DAY_SPILL, 1.0, glow))
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


## Lights the hearth fires by day, and in the evening the fire in every house
## someone has come home to; lets them burn down at dusk, late at night or
## once the house is empty, and leans the smoke with the wind (see
## ChimneySmoke). `at_once` settles it on the spot.
func _mind_chimneys(at_once := false) -> void:
	if chimneys.is_empty():
		return
	var burns := ChimneySmoke.fire_burns(hour)
	var home := {}
	var strength := ChimneySmoke.strength(hour)
	var breeze := ChimneySmoke.breeze(weather)
	if burns:
		for v in villagers:
			if v.at_home:
				var door: Vector3 = v.house_door()
				home[door] = int(home.get(door, 0)) + 1
	for c in chimneys:
		var plume: CPUParticles3D = c.smoke
		ChimneySmoke.light(plume, ChimneySmoke.smokes(hour, int(home.get(c.door, 0))), at_once)
		if not is_equal_approx(plume.color.a, strength):
			plume.color = Color(1, 1, 1, strength)
		if plume.gravity != breeze:
			plume.gravity = breeze


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
	_send_raven(v)


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
	for c: Vector2i in MerchantWagon.CELLS:
		var cart_cell := _wanderer_cell + CART_OFFSET + c
		astar.set_point_solid(cart_cell, not WALK.contains(cell_char(cart_cell)))


## The tiles Zarek's camp takes on his nights (his pitch, his wagon and his
## donkey, see MerchantWagon.CELLS), empty when the map has no pitch. Nothing
## is planted on them or right beside them (see AppleTree.plant_in_village).
func merchant_camp() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _wanderer_cell.x < 0:
		return out
	out.append(_wanderer_cell)
	for c: Vector2i in MerchantWagon.CELLS:
		out.append(_wanderer_cell + CART_OFFSET + c)
	return out


## Zarek's home on wheels (see MerchantWagon), on the cart's cell and the one
## in front of it, with a few crates and a sack unloaded beside it, a sparkle
## of far-off magic over it, and his raven (see MerchantRaven).
func _build_cart(cell: Vector2i) -> void:
	var pos := cell_to_world(cell)
	_cart = MerchantWagon.build(_rng)
	_cart.position = pos
	add_child(_cart)
	MerchantWagon.kindle(_cart)
	var sparkle := Effects.make_sparkles(Color(0.8, 0.6, 1.0))
	sparkle.position = Vector3(-0.8, 3.0, 0)
	_cart.add_child(sparkle)
	for i in 2:
		var prop: String = ["crate_A_big", "sack"][i]
		_put(prop, Vector3(2.4, 0, 0.2 + i * 0.9), _rng.randf() * TAU, PROP_SCALE, _cart)
	for solid: Array in MerchantWagon.SOLIDS:
		_cart_shapes.append(_add_box(_walls_body, pos + (solid[0] as Vector3), solid[1]))
	for c: Vector2i in MerchantWagon.CELLS:
		astar.set_point_solid(cell + c, true)


## The merchant's raven, flying between his shoulder and its spots on the wagon.
func _send_raven(merchant: Node3D) -> void:
	var perches: Array[Vector3] = []
	for p: Vector3 in _cart.get_meta("perches", []):
		perches.append(_cart.global_transform * p)
	var raven := MerchantRaven.new()
	raven.name = "MerchantRaven"
	_cart.add_child(raven)
	raven.setup(self, merchant, perches, day)


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
	if owls:
		owls.clock_on = night_of >= 0 and Moon.is_full(night_of)
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
			# Slimes head for the pond on their own when the spring weather
			# clears (see SlimeLife); the others go back where they came from.
			if not SlimeGrowth.grows(s.enemy.kind):
				s.enemy.sink_at_dawn()
	_weather_foes.clear()
	if kind != Weather.STORM:
		_fade_ore()
	for foes in WEATHER_FOES.get(kind, []):
		if SlimeGrowth.grows(foes.kind) and not SlimeGrowth.may_crawl(kind, season_day):
			continue
		_place_weather_foes(foes)
	_strike_timer = randf_range(2.0, STRIKE_EVERY_MIN)
	if first:
		return
	var slimy := SlimeGrowth.may_crawl(kind, season_day)
	if kind == Weather.RAIN:
		notice.emit(Lang.t("Es fängt an zu regnen. Am Teich im Wald kriechen Schleime aus dem Wasser.") if slimy
				else Lang.t("Es fängt an zu regnen."), 4.5)
	elif kind == Weather.FOG:
		notice.emit(Lang.t("Nebel zieht auf. Zwischen den toten Bäumen treiben Nebelgeister, am Teich kriechen Schleime, und wer schleicht, bleibt ungesehen.") if slimy
				else Lang.t("Nebel zieht auf. Zwischen den toten Bäumen treiben Nebelgeister, und wer schleicht, bleibt ungesehen."), 4.5)
	elif kind == Weather.SNOW:
		notice.emit(Lang.t("Es schneit! Dicke Flocken fallen, und auf Dächern und Wiesen bleibt der Schnee liegen."), 4.5)
	elif kind == Weather.STORM:
		notice.emit(Lang.t("Ein Gewitter zieht auf! Fledermäuse schwärmen um die Felsen, Schleime kriechen aus dem Teich, und wo der Blitz einschlägt, glimmt Donnererz.") if slimy
				else Lang.t("Ein Gewitter zieht auf! Fledermäuse schwärmen um die Felsen, und wo der Blitz einschlägt, glimmt Donnererz."), 5.0)
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


## How thick the snow lies on the open air, 0 to 1 (see SnowCover), and how bright
## the light of the hour is on it.
func set_snow(cover: float, daylight := 1.0, moon := 0.0) -> void:
	# Prints stay all day (the world may be rebuilt meanwhile), but must not outlive the snow.
	if cover < Weather.PRINT_FROM:
		if not SnowPrints._records.is_empty():
			SnowPrints.clear()
	else:
		# Back from a house or a dungeon the day's prints lie in the snow again.
		SnowPrints.restore(self)
	WallFoot.bury(wall_foot, cover)
	if snow:
		snow.set_amount(cover, daylight, moon)
		SnowSweep.advance(self, cover)
	if pond_reeds != null:
		pond_reeds.set_snow(cover)
	# Leaves and rubbish drifting down the stream and the river turn white under snow.
	if is_inside_tree():
		for flow: StreamFlow in get_tree().get_nodes_in_group(StreamFlow.GROUP):
			flow.set_snow(cover)
		SewerSurface.set_snow(self, cover)
	if waterfall != null:
		waterfall.set_snow(cover)
	if snowman != null and is_instance_valid(snowman):
		if cover < Snowman.MELTED:
			astar.set_point_solid(world_to_cell(snowman.global_position), false)
			snowman.queue_free()
			snowman = null
		else:
			snowman.melt_to(cover)
			snowman.set_daylight(daylight, moon)
	# The children's angels and rolled balls melt too (see SnowGames).
	SnowGames.melt(self, cover)


## How thickly the ponds are frozen, 0 open water to 1 solid ice (see IceCover and
## Weather.ice): the hero can walk on the ice, and fish through its one hole.
func set_ice(value: float) -> void:
	ice = clampf(value, 0.0, 1.0)
	if ice_cover != null:
		ice_cover.set_amount(ice)
	if ice_fish == null and is_inside_tree() and not _pond_waters.is_empty():
		ice_fish = IceFish.build(self, _pond_waters)
	if ice_fish != null:
		ice_fish.set_ice(ice)
	if pond_frogs != null:
		pond_frogs.set_ice(ice)
	if waterfall != null:
		waterfall.set_ice(ice)


## A grey footprint in the snow that fades again; the hero and the villagers leave them while
## the snow lies thick enough (see Weather.PRINT_FROM). `size` 1 is a grown-up's boot; `kind`
## is the shape (see SnowPrints.KINDS), the animals leave paws, hooves and bird feet.
func snow_print(at: Vector3, heading: float, size := 1.0, kind := "boot") -> void:
	if snow == null or snow.amount < Weather.PRINT_FROM or not is_inside_tree() or is_roofed(at):
		return
	# Steps down in a cellar or the mine press nothing into the snow above.
	if at.y < UNDERGROUND_Y or LostMine.holds(at):
		return
	# Ground swept bare of snow takes no prints (see SnowSweep).
	if at.y <= PRINT_ABOVE and SnowSweep.is_bare(self, at):
		return
	# Up on something (a house's roof): the print lies on what is underfoot there, not on the ground.
	var up := Vector3.ZERO
	if at.y > PRINT_ABOVE:
		var hit := _underfoot(at)
		if hit.is_empty() or (hit.normal as Vector3).y < SnowCaps.STEEPEST:
			return
		up = hit.normal
		at = hit.position
	SnowPrints.set_daylight(snow.daylight)
	SnowPrints.leave(self, at, heading, size, kind, snow.daylight, up)


## What is under `at` (a ray hit: position, normal), found by a short ray down past the hero, or
## {} when nothing is within reach below.
func _underfoot(at: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.4, 0), at - Vector3(0, 0.5, 0))
	ray.collide_with_areas = false
	ray.hit_from_inside = false
	if player != null:
		ray.exclude = [player.get_rid()]
	return space.intersect_ray(ray)


## From how high over the ground a print is pressed into what is underfoot (a roof) instead of the
## ground (metres).
const PRINT_ABOVE := 0.5
## Below this height a step is underground (a cellar, a mine) and presses no print in the surface's snow.
const UNDERGROUND_Y := -0.6


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
			if SlimeGrowth.grows(s.kind) and (slimes_about() >= SLIMES_AT_MOST or not SlimeGrowth.may_crawl(weather, season_day)):
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
		s.enemy = null
		s.timer = WEATHER_RESPAWN
		if is_instance_valid(e):
			enemy_killed.emit(e)
			drop_kill_loot(e, randi_range(purse[0], purse[1])))
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
## How many other spots a stroke tries when the first lies under cover (see open_sky).
const STRIKE_TRIES := 12


func strike() -> Vector3:
	var near: Vector3 = player.global_position if player else Vector3.ZERO
	var at: Vector3 = near + Vector3(randf_range(-30, 30), 0, randf_range(-24, 24))
	var ore_spot := Vector2i(-1, -1)
	# Now and then it seeks a creature about, instead of a rock (see LightningStrike).
	var seek = LightningStrike.pick_target(self, player) if player and randf() < LightningStrike.SEEK_CHANCE else null
	if seek != null:
		at = seek
	elif not _rock_cells.is_empty() and randf() < 0.75:
		var rock: Vector2i = _rock_cells.pick_random()
		at = cell_to_world(rock)
		if randf() < ORE_CHANCE and ore_lying() < MAX_ORE:
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if is_open(rock + d):
					ore_spot = rock + d
					break
	at.y = 0.0
	# Never into a house, under a roof or down into a cellar: it strikes the open ground nearby
	# instead, and if none is found, this stroke stays up in the clouds.
	for i in STRIKE_TRIES:
		if open_sky(at):
			break
		ore_spot = Vector2i(-1, -1)
		at = near + Vector3(randf_range(-30, 30), 0, randf_range(-24, 24))
		at.y = 0.0
	if not open_sky(at):
		return Vector3.INF
	_show_bolt(at)
	lightning.emit(at)
	Events.scare("blitz")
	LightningStrike.hit(self, at, player)
	if ore_spot.x >= 0:
		var pos := cell_to_world(ore_spot).lerp(at, 0.35)
		_drop_item(ORE, pos, false)
		_pickups[-1]["weather"] = true
		if player and _flat_distance(player.global_position, pos) < ORE_NOTICE_RANGE:
			notice.emit(Lang.t("Der Blitz schlägt in einen Felsen ein! Daneben glimmt Donnererz."), 3.5)
	return at


## Whether `pos` lies under the open sky: not in a house (the hero's own or a built one), not
## under a roof and not in a house cellar. Lightning only strikes there (see strike).
func open_sky(pos: Vector3) -> bool:
	var ground := Vector3(pos.x, 0.5, pos.z)
	if _in_house(world_to_cell(ground)) or is_roofed(ground):
		return false
	return not CellarView.in_cells(_cellar_holes, Vector3(pos.x, 0.0, pos.z))


## A bright bolt from the sky down to where lightning struck: a hard zig-zag with a few forks
## (see LightningBolt) that flickers for a moment and fades.
func _show_bolt(at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bolt := LightningBolt.build(at, rng)
	add_child(bolt)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.8, 0.88, 1.0)
	glow.light_energy = 14.0
	glow.omni_range = 24.0
	glow.position = at + Vector3(0, 2.0, 0)
	add_child(glow)
	var sparks := Effects.make_sparkles(Color(0.8, 0.9, 1.0), true)
	sparks.position = at + Vector3(0, 0.5, 0)
	add_child(sparks)
	# The bolt flickers: on, dark for a blink, on again (see LightningBolt.FLASHES), then fades.
	var tween := create_tween()
	for i in LightningBolt.FLASHES.size():
		tween.tween_interval(LightningBolt.FLASHES[i])
		if i < LightningBolt.FLASHES.size() - 1:
			var lit := i % 2 == 1
			tween.tween_callback(func():
				if is_instance_valid(bolt):
					bolt.visible = lit)
	tween.tween_property(bolt.get_meta("core"), "albedo_color:a", 0.0, LightningBolt.FADE)
	tween.parallel().tween_property(bolt.get_meta("glow"), "albedo_color:a", 0.0, LightningBolt.FADE)
	tween.tween_callback(bolt.queue_free)
	tween.tween_property(glow, "light_energy", 0.0, 1.0)
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


## The ground the temple's nave stands on (x/z), inside its walls (see WalkIn._walls_of_temple).
func temple_room(node: Node3D) -> Rect2:
	var xf := node.global_transform if node.is_inside_tree() else node.transform
	var a := xf * Vector3(WalkIn.NAVE.position.x - 0.5, 0, WalkIn.NAVE.position.y - 0.5)
	var b := xf * Vector3(WalkIn.NAVE.end.x + 0.5, 0, WalkIn.NAVE_DOOR_Z + 0.5)
	return Rect2(Vector2(a.x, a.z), Vector2.ZERO).expand(Vector2(b.x, b.z))


## How far past a walk-in house's walls the ground stays bare of snow (metres): just its plinth, which
## sticks out 0.05 m. The snow shader draws the walls exactly (see SnowCover.set_rooms).
const ROOM_MARGIN := 0.05
## How high the rooms of a walk-in building reach (metres): its eaves (see VillageHouse._shape), so
## no snow lies on the upper floor's furniture and stairs; the roof over them keeps its snow.
const WALK_IN_CEILING := VillageHouse.PLINTH + VillageHouse.GROUND + VillageHouse.UPPER - 0.05


## The ground a building one walks into stands on (x/z, see WalkIn), from its shape (see
## VillageHouse.build): its ground floor's walls and the plinth. Empty for a
## building built some other way.
func walk_in_room(node: Node3D) -> Rect2:
	if node == null or not node.has_meta("shape"):
		return Rect2()
	var shape: Dictionary = node.get_meta("shape")
	if not shape.has("w") or not shape.has("d"):
		return Rect2()
	var half := Vector2(float(shape.w), float(shape.d)) * 0.5 + Vector2.ONE * ROOM_MARGIN
	var xf := node.global_transform if node.is_inside_tree() else node.transform
	var a := xf * Vector3(-half.x, 0, -half.y)
	var b := xf * Vector3(half.x, 0, half.y)
	# Turned by a quarter or not at all, so two opposite corners span it.
	return Rect2(Vector2(a.x, a.z), Vector2.ZERO).expand(Vector2(b.x, b.z))

