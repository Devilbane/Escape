# Escape!

A fantasy game: escape from a dark dungeon, one level at a time.
Simple controls, beautiful 2.5D graphics, lots of levels.
The game can be played in English or German; you choose the language on the title screen.

**Play in the browser:** https://devilbane.github.io/Escape/

## Controls

| Action | Keyboard | Mouse / touch |
|---|---|---|
| Walk | WASD or arrow keys | click/tap the floor |
| Jump | Space | right click while walking (left button held), “Jump” button |
| Melee | run into the enemy or F | click the enemy (the hero walks up to it), “Strike” button |
| Throwing knife | R | right click while standing, “Throw” button |
| Use, search | run into it | click the object |
| Pick up a crate | E | click the crate, “Crate” button |
| Set a crate down | Q | “Crate” button, “Set down” in the inventory |
| Set a stone block down | B | “Stone” button, “Set down” in the inventory |
| Move a stone block | | grab it with the left mouse button, drag, let go (right click while dragging turns it) |
| Pick up a stone block | E | click it briefly, “Stone” button |
| Push a heavy stone block | E | click it briefly; drag it and it slides straight on |
| Inventory | I | “Inventory” button |
| Compendium | H | “Compendium” button |
| Character page | P | “Character” button |
| Load saved game | L | “Load” button (also on the title screen) |
| Quit game | Esc | “Quit” button, top right |
| Sound on/off | M | “Sound” button, top right |
| Zoom | + and − | mouse wheel (up close the camera tilts and you see the face) |

A jump from a run keeps its momentum: the faster you are, the farther you fly.
Running has a risk: lose more than 10 % of your lives within 2 seconds while running (or right after) and you fall to the ground and get up again, which takes about 2.5 seconds. No blow lands while you are down.

Run into a skeleton and you fight automatically: as long as you stand next to it, you keep striking.
Click a skeleton and the hero walks up to it and strikes it. Facing a single enemy the hero **strikes**
it for full damage. With two or more enemies in reach the hero **sweeps** the blade round instead:
up to 3 of them are hit at once, each for half the damage (at least 1).
A hero who is attacked fights back on their own, even without a command: with the blade when the attacker
is close, with throwing knives when it stands further off (as long as there are knives and a clear line of sight).
You and the skeletons each take up your own spot: nobody can stand inside or on top of anyone else.
If you land on a skeleton's head, you are pushed apart, and no blow lands until you stand side by side again.
Step back and you throw knives at the skeleton you attacked last, as long as you can see it
and have knives.

Add `?level=3` to the address to start the game directly on level 3.

## The goal of every level

Find the **key**, open the **door** and climb the **stairs** up to the next level. At the top you get 5 lives back.
Barrels, crates, tables, chests and wall shelves can be searched: inside there may be gold,
throwing knives, a healing potion or nothing at all. Searched objects get a tick.
Skeletons attack with blades or crossbows. You can jump over **spikes**. Skeletons avoid spike traps, wait until the spikes are down, and hurt themselves on them.
At a **shrine** you choose one gift: +1 life, +1 power or +7% speed (a wise hero also gets +1 hardening).
Gifts last until the end of the game.

Sometimes you find **gear**: helmets and hats (bone helmet, wizard hat, knight's helmet, bear cap) sit visibly on your head, sword and axe give power, shields give life,
amulets give speed, power or life. In the **inventory** (key I) you put them on or throw them away.
**Crates** go into your bag (3 kg each) and come out again in front of you; set one down
facing another crate and it goes on top, up to three high. Walk into a crate and you climb on top
of it. A stack two crates high is too tall to just walk up: jump against it and you pull yourself
up, or set a third crate down as a step. In the village, south of the market, a stone **pedestal**
holds a food basket out of reach of the ground and of a single crate. Three crates lie beside it:
stack two next to the pedestal, climb up and eat (+3 lives and every ailment cured). The basket
fills up again after a few minutes.

**Stone blocks** let you build: walls, steps, towers, small enclosures. Hagen the **stonemason** sells them
in the village, west of the pedestal, next to his stone yard (3 gold each, 1 gold back; 4 kg each). A block
is twice as long as it is wide and high and sits on a build grid: set down from the bag (key B), it lies
across your way in front of you, on the floor or on top of the blocks already there, up to five high.
Grab a block lying free with the left mouse button and drag it: a see-through block shows where it will
land (green: it fits, red: no room), let go and it flies there, within 7 m of you. Blocks are climbed like
crates. What you build stays standing in your saved game.
Skeletons and bandits cannot climb: a wall of blocks across a corridor or around your camp keeps them
out, and they look for a way round it instead (a gap narrower than about 1.2 m is too tight for them).
You step over a wall one block high.

Deep in the **Labyrinth** (level 3) lies a **stone chamber** with three old, heavy, mossy blocks, three
**pressure plates** and an iron gate in front of a treasure chest. Heavy blocks do not fit in your bag and
cannot be stacked: E (or a click) pushes one a little away from you, and dragged with the mouse it slides
straight on until it hits something. Pillars stand in the way. Once a block lies on every plate, the
gate sinks into the floor for good, and the chest behind it is as rich as a rare secret room.
Your own blocks from the stonemason press the plates too.

Your bag holds 8 things. A **backpack** worn in its own slot makes room for more: canvas backpack 10,
leather backpack 11, large backpack 12. The bigger the backpack, the rarer it is. You can only take off a
backpack, or swap it for a smaller one, while everything you carry still fits.
Hard armour (knight's helmet, crest shield, chain mail, plate armour) has **hardening**: it takes a fixed amount off every
hit (at least 1 damage always gets through). Every hit has a 5 % chance to wear off one point of
**durability**; once that is used up, the piece breaks.
**Shields** block: round shield 20 %, crest shield 25 %, spiked shield 30 %. A blocked blow or
shot does no damage at all (spikes from below cannot be blocked). Shields have durability too:
every block wears it with a 20 % chance, every hit with 5 % as with armour.
Every item has a **weight**. Everything you carry, worn or in your bag, slows you down:
1 % speed per kg, at most 35 %. Jewellery weighs almost nothing, plate armour 8 kg. Skeletons carry their
gear the same way.

**Your hero grows by doing.** They have seven **attributes** that rise very slowly, and only
through what the hero does. A whole run through the dungeon gives about one point, and every further point
needs a quarter more practice than the one before:

| Attribute | Value | Trained by | Effect |
|---|---|---|---|
| Strength | 10 to 30 | landing hits, felling enemies, blocking blows, carrying heavy loads | +1 power per point, everything you carry weighs less |
| Constitution | 10 to 30 | losing life (hits, spikes, poison) | +1 life per point |
| Speed | 100 % to 150 %, in steps of 5 | walking and jumping | walk faster |
| Dexterity | 10 to 30 | jumping, throwing knives, spike traps | jumps from a run 2 % longer per point, 4 % per point to dodge spikes shooting up |
| Intuition | 10 to 30 | searching, getting past secret levers, finding secret rooms | +2 % per point to notice a secret lever |
| Wisdom | 10 to 30 | experience, whatever the outcome: finishing levels, finding keys and secret rooms, choosing at a shrine, every finished run, even a deadly one | all other attributes and skills learn 5 % faster per point; from Wisdom 12 every shrine offers a fourth gift (+1 hardening) |
| Intelligence | 10 to 30 | understanding new things (every new entry in the compendium), defeating skeleton mages | things of the mind need it: the wizard hat from Intelligence 11, later scrolls, wands and skills of the mind |

On top of that come **skills** (level 0 to 10). They grow much faster, but only with the gear
they need: **Blades** with a dagger or sword, **Axes** with the axe, **Blocking** with a shield,
**Wearing armour** with hard armour; **Knife throwing** and **Sneaking** always work.
With Blades, Axes and Knife throwing, every heavy hit (+1 damage) is a skill roll (see the character page below).
Each level of Blocking adds 2 % block chance, Wearing armour makes hard armour 6 % lighter, Sneaking makes you 3 % faster.
Some items add levels themselves (shadow cloak +2 Sneaking, crest shield +1 Blocking,
chain mail +1 Wearing armour, silver bracelet +1 Knife throwing). Everything is shown in the inventory, with the progress
towards the next point. What your hero has learned stays saved with their name, even across new games.

The **character page** (key P) shows everything as a wheel. The centre circle holds the attributes:
Strength, Dexterity and Intelligence, with Constitution, Wisdom and Intuition between them, and life and
speed in the very middle. Around it is a ring of six sectors: Strength, Strength · Dexterity, Dexterity,
Dexterity · Intelligence, Intelligence, Intelligence · Strength. Every skill sits in the sector of the
attributes that govern it: Axes and Wearing armour under Strength, Blades and Blocking under
Strength · Dexterity, Knife throwing under Dexterity, Sneaking under Dexterity · Intelligence.
Basic skills (levels 0 to 10) sit in the inner ring. Advanced skills build on a basic skill (`needs` in
`Training.SKILLS`) and go in the outer ring. They have 15 levels: the first nine are learned in three ranks
of three, Novice, Advanced and Master; levels 10 to 15 are still to be defined. Anything above that is
special knowledge, only from quests and rewards.
A **skill roll** succeeds if d100 ≤ (sum of the governing attributes / their number) × (skill level + 1).
Example: Blades 2 with Strength 12 and Dexterity 10 gives (12 + 10) / 2 × 3 = 33 %. The page shows this
chance next to every skill.

After every 4 levels you reach a **safe room** without enemies, the refuge. It has a **fountain**
that refills your life and cures poison and curses, a storage chest, a merchant who buys and sells for gold, and a bed. The game saves automatically when you enter the refuge; the bed saves once more and logs you out. If the hero falls later, the saved game is kept: a click on the “Fallen” screen continues the game from the refuge, N starts a new one.
On the next start you continue from there with a click or a key. The saved game is stored in the browser.

**Hero or heroine:** a new game asks whether you play a hero or a heroine before it asks for your name.
The heroine has a body and a face of her own, not just new colours: a narrower waist and jaw, larger eyes
with lashes, a rosy mouth and hair that falls to her shoulders. Hair styles, hats, armour and the sleep in the
bed work for both, and the choice is kept in the saved game.

**Several saved games:** every hero has a saved game of their own, so you can play several heroes side by side.
The **Load** window (key L, or “Load saved game” on the title screen) lists them all with level, gold and the time they were saved;
pick one to load it, or delete it (click “Delete” twice). On the title screen a click continues with the game saved last.
Starting a new game with the name of a hero who already has a saved game replaces it the next time the game saves.

Every level has a **secret room**. One of the torches near it is a lever, a different one in every
run. The first time you walk past it, you may discover it with some luck (d100), and
2.5 seconds later the wall sinks. The richer the room, the smaller the chance:
Normal 55 %, Uncommon 40 %, Rare 28 %, Epic 18 %, Godborn 10 %. Every secret room you find
raises the chance by 1. The lever rolls only once. If you have not found one by level 3,
the one there is certain; after that, never more than 4 levels go by without a secret room.

You only see what lies in your line of sight and has light: a burning torch nearby or
your own lantern. Dark corners stay black; skeletons in them you only hear by their footsteps.
Areas you have already explored stay visible in grey. Some torches burn, some do not: run into
the wall at a torch to light it or put it out.

The dungeon has long been abandoned, but it is not empty: dust lies on the floor and gathers along
the walls, cobwebs hang in the corners and on the furniture, and old bones, broken pots and loose
stones lie about. Cockroaches and spiders crawl around and scurry off when you come close, spiders
lower themselves from their webs, and here and there water drips from the ceiling into a small
puddle (you hear it, too). All of this is decoration only: it never blocks your way.

**Sneaking** (C or double click): 60 % slower, silent, half transparent, and the lantern is
hooded. Skeletons look ahead (120°), but only see what stands in the light. They can hear you
all around, unless you sneak or stand still. Very close they always notice you. If they lose
sight of you, they search for a few seconds and then return to their post.
Once a skeleton has spotted you (red **!**), you can only sneak again after it gives up.
A “tap” in the dark is a skeleton you cannot see but can hear.
Every kind also has its own voice that you hear nearby: warriors growl, archers
hiss, mages murmur, minions giggle, brutes rumble and guardians clank their armour.
The closer a skeleton comes, the louder, more often and more urgently you hear it (and its footsteps).
In the dark a word shows where it came from; very close it becomes a cry.

**Stab in the back:** a blow from behind on a skeleton that has not noticed you yet
fells it at once. If you sneak up from behind, it will not notice you even up close. In the crypt
(level 4) an armoured **guardian** carries the key: blades and knives bounce off it,
only a stab in the back defeats it, with a single blow. It stands still in its hall next to the
brazier, which lights only the middle; the edge stays dark. In the corridor before it you learn how
it is done: sneak (C), go around it in the shadows along the edge, strike from behind. A hall with a guardian
has no wall torches. A guardian in a level without `K` drops the key when it dies.

Searched barrels, crates, tables and chests can be recognised by coins and a torn sheet in front of them.

## Beyond the gate: freedom

Whoever climbs the last stairs steps out of a **crypt** onto a graveyard under the evening sky. That counts
as an escape: it goes into the ranking and the game is saved at once. From then on the **graveyard** is your
new starting point: every load, and every new try after a fall, begins in front of the crypt door, wherever
you saved last. But the game goes on. A long path leads
through the autumn forest, past a pond and a woodcutter, to the village of **Lindenhain**. Run into anyone
to hear what they have to say. The **village elder** gives you the empty house with the tiled roof, and a
golden light shows the door. Inside are a **bed** (save and log out) and a **chest** (your storage). The moment
you first step inside, the house is yours: the game saves, and from then on your house replaces the graveyard as
the starting point. Every load, and every new try after a fall, begins next to your bed.

In the middle of the village lies the paved **market square** with a fountain that heals, benches and
lanterns. Around it stand the **smithy**, the **temple**, the **office of the crown**, the **post office**, the
**adventurers' guild**, the **general store** (Mira, the shopkeeper, buys and sells), the **tavern** and the
**bank**. Sixteen villagers go about their day: the smith hammers, the farmer harvests pumpkins, the guard
makes the rounds, the postmaster carries letters, the priestess tends the temple. Every so often the
**herald** rings the bell and calls out the news, and the whole village gathers on the square to listen.

At the **bank** the banker keeps your gold safe (deposit and withdraw) and rents you a **vault** for
50 gold. The vaults are in the **cellar**: small cells behind iron bars, each with its holder's name, their
gold and their treasures. You can walk down and look at what every other hero keeps there; your own cell
opens for you. Until there is a server, the bank keeps one account per hero name on this computer.

**Benno the barber** keeps a small stall with a striped barber's pole and a scissors sign at the south-east
corner of the market square, under his own burning mohawk. He gives
you a new **hair style** (natural, mohawk or shaved, 5 to 15 gold) and a new **hair colour** (natural,
black, blond, silver, red, green, blue, pink or purple for 10 gold, an animated **rainbow** for 25, or
flickering **fire** that glows in the dark for 30). He also inks a **tattoo**: any word of up to 12 letters
on the right side of your head, straight or arched in a half circle (20 gold, removing it costs 10). It only shows
on a shaved head. A mohawk
hides under helmets and hats, unless you hide the helmet in the inventory: it still protects, but the
haircut shows. Your look is saved with the game.

**Quests.** Some villagers have work for you. Run into them and they hand out a task; run into them
again when it is done to collect the reward. Ulrich the guard wants five bandits from the pass defeated,
Gorm the smith three bruisers, Bruno the woodcutter two poachers, and once the pass is quieter Ragna at the
adventurers' guild sends you after the bandit chief. Mira the shopkeeper wants back three **bandit daggers**
that the cutthroats stole (they drop them while she is still missing some). Anselm the postmaster, Lene the
farmer and Hanna the water carrier give you a letter, a pumpkin or a bucket to carry to another villager,
who pays you when it arrives; lose it and the giver hands you another. Rewards are gold and sometimes gear
(boots, chain mail, a shadow cloak). The **Quests** page of the compendium (key H) lists every task with
who gave it, how far along it is and the reward. Quests are kept in each hero's saved game. The tasks are
defined in `scripts/quests.gd`: adding one is a single entry there plus its English texts in `scripts/lang.gd`.

The villagers follow a fixed daily routine (small scripts, no AI on the network): that costs no noticeable
computing time and nothing to run.

## Day and night

Above ground the world keeps the **time of day**: one full day takes **20 real minutes**, about 13 of them
daylight and 7 of them night (21:00 to 05:00). The clock in the top left shows the hour. It runs in the open
and inside the village buildings; down in the dungeon time stands still. A new hero steps out at 08:00.

The light follows the hour: a pink dawn, the warm autumn daylight, a golden-red dusk and a cool blue
moonlit night. At night the **lanterns** burn bright and the **windows** of the houses glow. Most villagers
walk home and go to sleep; only the guard, the drinker at the tavern and the priestess stay up. Shops and
the bank are closed until morning, and the herald keeps quiet.

The night is dangerous: the **dead rise** from the graves and roam the graveyard until dawn (they come back
a while after they fall), and the **bandits** of the pass are tougher (more life, quicker blows) and come
back twice as fast. In the dark, away from the lanterns, a sneaking hero cannot be seen. At dawn the dead
sink back into their graves.

A night in your **bed** skips to the next morning: you wake up at 07:00. The time of day is kept in the
saved game.

## The robbers' pass

A road leaves the market square to the east and climbs into the **robbers' pass**: rocky heath, dead trees and
a bandit camp with tents, a campfire and the robbers' hoard in a **treasure chest**. **Bandits** roam the
clearings: quick **cutthroats** with daggers, **poachers** who shoot crossbow bolts from afar, heavy
**bruisers** with axes, and the **bandit chief** by the fire with sword and shield. They fight like the
skeletons do (run into them, or click them), but they are people: they shout, they stroll instead of
standing guard, and they chase you only so far from their camp before they give up. Bandits wear gear from
the same list as yours, and much more often than skeletons do; when one falls it spills **gold** and may
drop a piece of its gear. A fallen bandit's spot is taken by another a few minutes later, once you have
left, so there is always something to fight and loot. Whoever falls on the pass starts again on the graveyard.

By the campfire waits the boss of the pass: **Ravenheart, the bandit chief**. Once he takes up the fight, his
**health bar** shows at the top of the screen, with marks where his next phase begins:

1. **Sword and shield.** Stand too close and now and then he rams you with his shield: it cannot be blocked
   and knocks you to the ground.
2. **"To me, lads!"** Below two thirds of his life he calls two cutthroats out of the camp. Now the sweep pays off.
3. **Enraged.** Below one third he glows red, gets quicker and, from a distance, lowers his head and **charges**
   in a straight line. Step aside or jump: a charge that misses leaves him **dazed** for a moment, and a dazed
   chief takes double damage.

A stab in the back does not bring him down at once, it only hits three times as hard. If you run away he binds
his wounds after a while and starts again at full strength. He falls **only once per saved game**: he leaves
plenty of gold and his unique blade, the **Ravenblade** (+3 power, +5% speed), and nobody takes his place.
If you leave the blade lying there, it still waits for you after a reload.

The **compendium** (key H) shows all keys and mouse commands and collects every hint and every
explanation you have been given so far: the introduction of every level, the tips on sneaking and on the
guardian, the secret lever. It is saved with the game.

## Time away (offline activities)

When your hero lies down in the refuge's bed, you plan **one day** for them. While you are logged out,
the hero lives that day over and over: every **10 real minutes are one in-game hour**, so one in-game day
(24 hours) takes 4 real hours. At most **8 in-game days (32 real hours)** count; longer absences are capped.
When you come back, a "Welcome back" window shows what the hero did.

| Block | Hours per day | What it does |
|---|---|---|
| Job | 0 to 12 | City guard (3 gold/h, a little Konstitution and Stärke), smithy helper (needs Stärke 11, 2 gold/h, Stärke), scribe (needs Intelligenz 11, 2 gold/h, Intelligenz) |
| Training | any | practise Stärke, Konstitution, Tempo or Geschick, or a skill whose gear is worn |
| Study | any | read a book you carry or keep in the storage chest: it teaches its skill (no gear needed) and a little Intelligenz |
| Crafting | any | forge throwing knives (1 per 3 h) or mend worn-down gear (1 durability per 2 h); both train Geschick a little |
| Rest | at least 8 | heals an eighth of your life per hour; a full night also cures poison and curses |

The blocks are lived in this order each day, so a short absence pays for the job and the training first.
Training follows the same slow growth as in the dungeon: eight days of eight hours of training bring a fresh
attribute up by one point and most of a second, and every further point costs a quarter more.
Six books (one per skill) can turn up in chests and at the merchant. The rules are in `scripts/offline.gd`.

## Building new levels

Every level is a simple text file in the `levels/` folder. The levels are
played in the order of their file names. One character stands for one tile:

| Character | Meaning           | Character | Meaning           |
|-----------|-------------------|-----------|-------------------|
| `#`       | wall              | `.`       | floor             |
| `,`       | dirt floor        | `P`       | start             |
| `E`       | exit (stairs)     | `K`       | key               |
| `D`       | locked door       | `S`       | spike trap        |
| `c`       | gold coin         | `C`       | treasure chest    |
| `b`       | barrels           | `x`       | crates            |
| `o`       | pillar            | `t`       | table             |
| `k`       | small chest       | `M`       | skeleton warrior  |
| `A`       | skeleton archer   | `Z`       | skeleton mage     |
| `w`       | skeleton minion   | `G`       | skeleton brute    |
| `W`       | guardian          | `H`       | shrine            |
| `B`       | bed (save)        | `L`       | storage chest     |
| `V`       | merchant          | `F`       | fountain          |
| `?`       | secret wall       | `f`       | brazier           |

The lines `name:` and `hint:` give the level's name and the introduction shown when it starts.
A line `safe: yes` makes a level a safe room, and `elite: yes` gives it stronger skeletons.
A line like `secret: epic` sets how rich the secret room behind the wall `?` is: `normal`, `uncommon`, `rare`, `epic`
or `godborn` (the older German ids `ungewoehnlich`, `selten`, `episch` and `gottgeboren` still work).

A line `outdoor: yes` turns a level into the world under the open sky (see `levels/11_die_freiheit.txt`).
It has its own characters: `#` forest, `.` meadow, `,` path, `:` paved square, `~` pond, `R` crypt, `g` grave,
`d` dead tree, `z` graveyard fence, `a` gate in the fence, `l` lantern, `p` pumpkins, `r` rock, `T` tree,
`t` tree stump, `e` barrels and crates, `q` well, `F` fountain, `x` bench, `y` pumpkin field, `N` tent,
`f` campfire, `C` treasure chest. The bandits, who roam and come back a while after they fall: `c` cutthroat,
`A` poacher, `X` bruiser, `Q` bandit chief. Buildings are a
rectangle of the same character: `h` house, `j` smithy, `n` tavern, `m` general store, `u` windmill,
`s` temple, `k` office of the crown, `o` post office, `w` adventurers' guild, `b` bank. The hero's house:
`I` wall, `i` wooden floor (a gap in the wall is the door), `B` bed, `L` chest. The villagers: `0` elder,
`1` smith, `2` farmer, `3` woodcutter, `4` guard, `5` drinker, `6` shopkeeper, `7` child, `8` scholar,
`9` water carrier, `K` herald, `O` priestess, `G` guild master, `M` postmaster, `Y` banker, `Z` barber.

**Floors of buildings.** A level file with the lines `building: b` and `floor: cellar` or
`floor: upstairs` is a floor of the village building with that character: walking in at the
building's door leads there, and its stairs `E` lead back out of the door. Such floors are never part of
the run through the dungeon. Inside, `=` is a wall of iron bars and `U` a vault cell (see
`levels/12_der_tresorkeller.txt`, the bank's vault cellar).

The exit `E` needs a wall to the north (top) and is entered from the south.
A door `D` stands in a passage one tile wide.

## Languages

Texts in the code are written in German and translated to English in `scripts/lang.gd`. Labels and
buttons translate themselves; composed texts go through `Lang.t()`. Every new text needs an English
entry there.

## Technology

- Engine: [Godot 4.5](https://godotengine.org) with the Compatibility renderer, so it runs in the browser
- Graphics: KayKit Dungeon Remastered, Adventurers and Skeletons by Kay Lousberg (CC0)
- Graveyard, crypt and autumn trees: KayKit Halloween Bits; village buildings, trees and rocks: KayKit Medieval Hexagon Pack, both by Kay Lousberg (CC0)
- Wooden floor and roof tiles of the house: "Wood 062" and "Roofing Tiles 014 C" by ambientCG (CC0)
- Floors, walls, pillars and furniture: 3D Modular Dungeon Kit by Omie's Assets (CC0)
- Sounds: made from scratch with `tools/make_sounds.py`; footsteps and door: recordings by Fantozzi, “Footsteps Leather, Cloth, Armor” and qubodup; creatures, skeleton voices and chains by rubberduck; crossbow shots from “Medieval sound effects - Weapon Textures” (CC0, see `assets/sounds/CREDITS.txt`)
- Font: Cinzel and Cinzel Decorative (SIL Open Font License)
- Comic font of the fight bubbles: Bangers by Vernon Adams (SIL Open Font License)
- Every push to `main` plays through all levels automatically and publishes the browser version via GitHub Pages

## License

© 2026 devilbane. All rights reserved, see [LICENSE](LICENSE). Graphics and fonts by others are under their own licenses (see above).
