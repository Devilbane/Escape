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
| Map and journal | N | “Map” button |
| Fish (cast, strike, draw in) | G, by the water | “Fish” button |
| Offer a monster a gift | T, next to it | “Give gift” button |
| Load saved game | L | “Load” button (also on the title screen) |
| Quit game | Esc | “Quit” button, top right |
| Sound on/off | M | “Sound” button, top right |
| Music on/off, music volume | | “Music” button and the volume slider in the pull-out menu (Tab) |
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

**Foxes** live on the meadow by the woodland pond, west of the village, beside the path that comes down
from the graveyard. They are shy, but they love **sausages**.
Mira the shopkeeper always has some (2 gold each); when you buy one she tells you where the foxes
live, and the hint stays in the compendium (key H). Carry a sausage and a fox no longer bolts: it
comes up to you, curious, and eats it from your hand. After three sausages it trusts you and follows
you everywhere, in the village and down in the dungeon. It does not cling to your heels: while you stay close it
lounges about, sits, lies down when you rest, strolls around, trots in a circle round you and noses at
barrels and benches nearby. Walk off and it gets up and follows; it climbs the stairs right behind you.
Beside every bed it has a little wicker **basket** with a red cushion: when you go to bed, the fox trots
over, hops in and curls up asleep. You only ever have one fox, and it stays
yours in your saved game. It never fights and cannot be hurt.
Its nose is what makes it useful: **ingredients** lie hidden in the ground that you cannot see
(wild garlic, porcini and rare truffles in the open air; cave mushrooms and glowmoss in the
dungeon). When one is in reach of its nose, the fox runs over, digs it up and leaves it lying there
for you to pick up. They go into your **ingredient pouch** and show up in the ingredient book (key H),
ready for recipes. The ground holds new ones each time you come back.

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
At the **forge** beside the smithy in the village, Gorm the **smith** works your gear (walk into him):
*melt down* metal gear from your bag (weapons, shields, knight's helmet, chain mail, plate armour, rings,
bracelets, amulets) into **iron bars**, one bar per 8 gold of the piece's price (plate armour gives 6;
cloth, leather, fur and bone do not melt); *forge* any metal weapon, shield or armour from iron and a
little gold (plate armour: 8 iron and 16 gold), so you pick exactly the piece you want; and *mend* worn
armour and shields, a few gold per point of durability. He also sells iron bars for 4 gold each, so
forging from bought iron costs about what the merchant asks; iron from melted loot makes it cheaper.
Iron is counted like gold, weighs nothing and stays in your saved game.
Gorm also *sells his own work*, which is found nowhere else (not as loot, not at the merchant), and
he can forge it from iron too. The kite shield and the war hammer, the top of their kinds, he does not
sell: you have him forge them from your iron. The window opens on this tab:

| Piece | Skill | Gold | What it gives |
|---|---|---|---|
| Mace | Axes | 40 | +2 power, +1 life |
| Longsword | Blades | 45 | +2 power, +1 Blades |
| Scimitar | Blades | 50 | +2 power, +8 % speed, light |
| Kite shield | Blocking | 55 | +3 life, armour 1, blocks 30 %, durability 9, +1 Blocking |
| Battle axe | Axes | 60 | +3 power |
| War hammer | Axes | 70 | +3 power, +1 Axes, heavy |

Maces and hammers are swung like axes, so they train the Axes skill.
**Shields** block: round shield 20 %, crest shield 25 %, spiked and kite shield 30 %. A blocked blow or
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
that refills your life and cures poison and curses, a storage chest, a merchant who buys and sells for gold, and a bed.
Merchants sell only plain, basic gear: no specials, no unique or magic items (wizard's hat, shadow cloak,
amulets, silver bracelet) and not the top tier of any kind (plate armour, swift boots, ruby ring, bear cap,
royal cloak, big backpack, war hammer, kite shield). Those come only from loot and your own crafting.
Their windows have a Buy and a Sell page, categories that fold, and cards that compare an item with what
you wear. The game saves automatically when you enter the refuge; the bed saves once more and logs you out. If the hero falls later, the saved game is kept: a click on the “Fallen” screen continues the game from the refuge, N starts a new one.
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
to hear what they have to say. The **village elder** gives you your own house on **Weavers' Lane**, and a golden
light shows the door. Weavers' Lane runs along the northern edge of the village: a row of twenty narrow,
three-storey town houses wall to wall, each with its own colours and a number over the door, so the village has
a home for many heroes. Inside, the **ground floor** has the **chest** (your storage), the **upper floor** the
**bed** (save and log out), and the **attic** is free. Walk onto the stairs to go up or down a storey. Chalked
squares on the floorboards keep room for furniture on every storey. The moment you first step inside, the house
is yours: the game saves, and from then on your house replaces the graveyard as the starting point. Every load,
and every new try after a fall, begins next to your bed. The doors of the houses other heroes live in stay
shut, and an empty one tells you which number is yours. Who lives where is kept on this computer next to the
bank's books, so every hero keeps their house.

Your town house can be **upgraded**. Open the upgrade window from the bed in your town house or from Hagen the
stonemason. You pay with stone blocks (from your bag first, then from your chest) and some gold, and Hagen
builds each upgrade once, on the chalked furniture spots:

| Upgrade | Cost | What it does |
|---|---|---|
| **Second chest** | 4 stone blocks, 10 gold | Stands beside the first chest on the ground floor. Your chests hold 32 things instead of 16. |
| **Workshop** | 6 stone blocks, 30 gold | A workbench in the attic: 1 iron bar makes 3 throwing knives, 1 iron bar fully mends a worn piece of gear, and crafting while you are away takes a third less time. |
| **Trophy wall** | 5 stone blocks, 20 gold | A shelf on the attic wall with a small statuette of each mighty foe you have defeated: the bandit chief, the dragon, the yeti, an orc, a wolf, a giant spider and a brute. Each trophy gives **+1 life** while the wall stands. Trophies count from your first kill, even before the wall is built. |

In the middle of the village lies the paved **market square** with a fountain that heals, benches and
lanterns. Around it stand the **smithy**, the **temple** (a small stone chapel with a spire and stained-glass
windows), the **office of the crown**, the **post office**, the
**adventurers' guild**, the **general store** (Mira, the shopkeeper, buys and sells), the **tavern** and the
**bank**. The villagers live in half-timbered houses with jutting upper floors, shuttered windows and tiled
roofs, each one a little different. Sixteen villagers go about their day: the smith hammers, the farmer harvests pumpkins, the guard
makes the rounds, the postmaster carries letters, the priestess tends the temple. Every so often the
**herald** rings the bell and calls out the news, and the whole village gathers on the square to listen.

On the west side of the market square, right beside Gorm's forge, lies the **crafting square**, the place
where heroes meet to make things. Every workbench stands there in a row: a **fine metalwork bench** (rings,
chains, settings and wire), a **gem cutter's wheel** and an **alchemist's table** with a cauldron bubbling
green over a small fire. Between them stands **your chest**: it opens the same storage as the chest in
your house, so you can fetch ingredients and put away what you made without walking home. Each bench
belongs to one craft, and a recipe made with that craft is made at its bench. Until you know such a
recipe, a bench tells you what is done there. The benches are built in `scripts/crafting_square.gd`.

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

**Recipes and crafts.** Odo the Scholar has an old scroll for you: the recipe for a **Moonsilver Ring**.
A recipe names its ingredients and the craft it needs, but some of its lines have faded (they show only a
fragment like "A still … without …") until you find out what they say. Ingredients go into an
**ingredient pouch**, not the bag, so gathering them never fills it up. The pouch has its own tab in
the inventory (key I), beside the bag, showing every ingredient you carry and how many. The **Recipe book** page of the
compendium (key H) shows every recipe you found, what you have of each ingredient, and how far your craft
has come. Below the recipes it lists each ingredient they name: where it is found, when (for example only
at night), what yields it (an ore vein, a creature's loot, the smith), and whether you found the place yourself; the crafts (for now **fine metalwork**) are listed on the character page. This is the start of a
longer loop: gather ingredients from all over the world, learn and train the craft, work out the faded
lines, and finish the piece under the right influences (a calm mind, a goddess's favour, the right stars).
Recipes and ingredients are defined in `scripts/crafting.gd`, the crafts in `Training.CRAFTS`.

**Fishing.** Stand by the water and press **G** (or the **Fish** button in the pull-out menu) to cast a
line. After a few seconds the float goes under and a **!** shows: press again quickly to strike, or the
fish gets away. Pressing while you wait draws the line in; walking off, getting hit or opening a window
does too. There are three waters: the **fountain** on the village square, the **village pond** by the path into
the village and a small **pond in the wolf hollow** (mind the wolves). Most bites are a **perch**, and in the
fountain often an old coin someone threw in for luck (+1 gold). Each water also has one **rare fish**:
the **golden carp** in the fountain, the **silver pike** in the village pond, but only at dawn and dusk,
and the **moon trout** in the wolf hollow, but only at night. Every fish goes into the ingredient pouch.
Hanna the water carrier has a recipe that needs them: the **Amulet of the Deep** (all three rare fish and
three perch). One of its lines is smudged until you catch a silver pike. What bites where is set in
`Fishing.WATERS` (`scripts/fishing.gd`).

**Reputation.** Every villager has their own opinion of you, and helping them improves it. A finished task
counts the most: 25 points with whoever gave it, 15 with whoever received a delivery, and 5 with everyone
else you have met, because word gets around. Buying from a villager who trades (Mira, Gorm, Hagen, Benno)
gives 2 points per purchase, but only up to 30: buying alone makes a customer, not a friend.

| Standing | Points | What it brings |
|---|---|---|
| Stranger | 0 | nothing yet |
| Friendly | 10 | 5 % off their prices; every other chat they share some gossip: tips about the world and hints at who knows a secret recipe |
| Trusted | 25 | 10 % off; a villager who knows a **secret recipe** teaches it the next time you talk to them |
| Honoured | 45 | 20 % off |

Discounts apply to Mira's goods, everything at Gorm's forge (his wares, forging, iron bars, mending),
Hagen's stone blocks and Benno's haircuts and tattoos. Selling prices stay the same.
The secret recipes are new **crafting** choices for the time away: Gorm's oil-quenched throwing knives
(1 per 2 h instead of 3), Mira's leather grease (1 durability per hour instead of every 2 hours) and Hagen's
way of cutting stone (1 stone block per 4 h, at most 20 per absence, delivered to the storage chest while it has room).
The **Reputation** page of the compendium (key H) lists everyone you have met with their standing, the
points still needed for the next level and the secret recipes you know. Standing is kept in each hero's
saved game. The rules, gossip and secrets are in `scripts/reputation.gd`.

**Bounty board.** On the north-east corner of the village square, under a lantern by the adventurers' guild,
stands a wooden board with notices pinned to it. Every morning at dawn (5:00) the crown's clerk pins up
**three fresh hunts**: wolves, spiders, orcs or the yeti in the wolf hollow, cutthroats, poachers or bruisers
at the robbers' pass, or skeletons that rise from the graveyard at night. Run into the board to read them and
take on the ones you like, then come back to the board to collect the bounty (12 to 25 gold). A hunt not done
by the next dawn expires; one finished in time can still be collected later. Each notice pays once. A gold
**!** over the board means a notice is open, a **?** means a bounty is waiting. Hunts you are on also show on
the Quests page of the compendium. The day counter and the board are kept in each hero's saved game; sleeping
through the night counts as a new day. The hunts are defined in `scripts/bounties.gd` (one entry each, with
their English texts in `scripts/lang.gd`).

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

### The wandering merchant

Every **third night** (the second night after the escape, then the fifth, the eighth and so on) Zarek the
**wandering merchant** rolls his covered cart into the village at nightfall. He stands just south-west of
the market square, beside a lantern, until dawn, then moves on again. Walk into him to trade.

He brings **ingredients from far away** for your recipes: three kinds each visit, one or two pieces of
each. They go straight into your ingredient pouch:

| Ingredient | Price |
|---|---|
| Moonsilver ore | 30 |
| Moonstone | 35 |
| Glowmoss | 18 |
| Wild garlic | 8 |
| Porcini mushroom | 10 |
| Cave mushroom | 10 |

The rarest finds (the truffle and the rare fish) are never for sale. He also brings two pieces of plain
gear or books, at a fifth more than the shopkeeper asks. Like every merchant he sells only **basic** gear:
nothing magic or special (specials, the amulets, the wizard's hat, the shadow cloak, the silver bracelet),
nothing unique and never the best of its kind; Gorm's own work only Gorm sells. Those you find as loot or
craft yourself. He buys nothing.
Every visit brings different wares; what you buy is gone until his next visit. If you sleep through his
night in the bed, you miss him. The herald announces his visits on the square.

## Weather

Above ground the sky does not stay clear: **rain**, **fog** and **thunderstorms** come and go on the same
clock as day and night. A spell of weather lasts 2 to 5 hours of the day (about 2 to 4 real minutes), and
which weather comes next depends on the hour: fog gathers at night and in the early morning, storms brew in
the evening and at night, and by day the sky is mostly clear. The clock in the top left names the weather
when it is not clear. A new hero steps out under a clear sky, every morning after a night in the bed brings
new weather, and the weather is kept in the saved game. Down in the dungeon there is no weather.

Each weather brings its own creatures, which come back a while after they fall for as long as it lasts and
leave again when it changes:

| Weather | What it looks like | What comes out |
|---|---|---|
| Rain | grey sky, rain falls and patters | **slimes** crawl out of the pond in the western woods |
| Fog | washed-out colours, mist drifts over the ground | **fog wraiths**, pale little dead, drift among the dead trees; away from the lanterns a sneaking hero cannot be seen, even by day |
| Thunderstorm | dark sky, pouring rain, lightning and thunder | **bats** swarm around the rocks; where lightning strikes a rock, a lump of glowing **thunder ore** may be left beside it |

**Thunder ore** is only ever found in a thunderstorm, and only until the storm passes: whatever is left
lying fades away. Pick it up and take it to Gorm the smith, who melts each lump into 4 iron bars, or sell it
to the merchant.

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

North of the pass, through a gap in the trees, lies the **wolf hollow**. No bandits here, but beasts:
a pack of quick **wolves**, **spiders** whose bite can poison, two **orcs** that punch hard and a big
**yeti**. They notice, chase, strike and give up just like the bandits, and come back the same way a
while after they fall. A wolf or a spider leaves little more than a coin or two; orcs and the yeti carry
more gold and sometimes a piece of gear.

### Rivals and friends

Not all monsters are on the same side. Every kind belongs to a **faction**, and some factions hate each
other: when rivals meet, they fight, and whoever wins leaves the loser's loot lying for you.

- **The dead** (skeletons, fog wraiths) hate everything that lives.
- **The bandits** of the pass and **the beasts of the wolf hollow** (wolves, orcs, spiders, the yeti)
  are at war. Lure a wolf onto the pass, or let it find a bandit on its own, and watch them go at it.
  The beasts share their hollow in peace.
- **The dragon's brood** (bats, slimes, the dragon) wants the skeletons out of its cave.

A monster that sees a rival within about 14 metres goes for it. A monster that hunts you still goes for a
rival first when the rival is closer than you. A kill by a rival counts for no task and does not feed the
vampire tooth.

Some factions can be **befriended**. Stand next to one of them and press **T** (or “Give gift”):

| Faction | Gift | Gifts to become friends |
|---|---|---|
| Wolves | 1 perch | 3 |
| Orcs | 6 gold | 3 |
| The yeti | 2 perch | 3 |

Each gift calms that one monster for ten seconds, even mid-hunt, and earns the faction's **favour**. Once a
faction is your friend, none of them attacks you any more, your blade, sweeps and knives pass them by, and
they fall upon any monster that hunts you within about 16 metres. Slaying one of them costs favour; slaying
their rivals earns a little (a quarter per kill), but never the last step: that one takes a gift. The favour
is kept in the saved game. Spiders, bandits, the dead and the dragon's brood cannot be won over.

The woods between the graveyard and the village are home to peaceful animals: **does**, **stags** and
**foxes** graze and stroll on the meadows by the path. They never fight and cannot be hurt, and they
never stand in your way, but they are shy: come within about ten metres and they bolt, galloping off
across their meadow. **Sneak** and you get much closer before they notice. Once you are gone they
calm down and go back to grazing.

## Dark holes and nameless horrors

Three **dark holes** gape in the ground of the wild: one among the graves, one in a quiet meadow south-west of
the village, and one in the wolf hollow. A ring of torn earth and rocks, a pit so black no light gets in, skulls
at the rim and a cold mist rising out of it. Come close and the holes **whisper** ("...come closer...").
Run into one to climb down into a small cave of its own: **The Open Grave**, **The Spider Hole** and **The Pale Deep**.

Down there it is **pitch black**. No torch burns on the walls, and without a light of your own you see hardly
more than the tile you stand on. **Torches** are sold by the shopkeeper (3 gold, she always has some): in the
dark one lights itself from your bag and burns for three minutes, then the next one is lit, and when the last
one gutters out the darkness closes in again. Even a torch only lights a few steps around you, and a burning
torch cannot be hooded: every monster down there sees you coming. Back in the open the torch goes out and keeps
what is left of it for next time.

Somewhere in each cave lies a **den**, and every other time you come down something lives in it: a **horror**,
a huge monster nobody has a name for. At first you only hear it breathing in the dark. The moment you see it,
time stalls for a heartbeat, the ground shakes and the edges of the screen run red, and a bar at the top shows
its life under **???**. Horrors hit hard, some of them poison, and a stab in the back only hurts them three times
as much instead of killing them. Only once one has fallen is it **discovered**: its name is spelled out across the
screen, it goes into the compendium, and from then on its bar shows its name. Each one leaves a heap of gold and
the gear it swallowed. Very rarely a horror also lurks in the far end of a level deep in the dungeon (from level 4).

## The dragon's lair

In a clearing in the woods, north of the path from the graveyard to the village, an old **stone arch**
stands over stairs that lead down into the dark. Run into the arch to climb down into the **dragon's lair**,
a dungeon of its own: **bats** flutter about, quick but frail; green **slimes** creep along, tough and
sometimes poisonous; skeleton warriors, archers, minions and a brute haunt the crypts; and in the great hall
at the bottom the **dragon** guards its hoard. Every monster of the lair carries some gold, and the dragon a heap of it and usually a piece
of gear. Behind it waits the hoard's treasure chest among piles of coins.
The halls are dressed with cobwebs, skulls, banners and a stone horse statue from the dungeon kit.
The stairs you came down lead back out of the arch. The monsters stand ready again every time you come
down, so there is always something to fight; searched chests and barrels stay empty.
**Embermaw, the Hoard Dragon** is the boss of the lair. When it spots you, it wakes with a roar that shakes
the lair, and its **health bar** shows at the top of the screen, with marks where its next phase begins.
It hovers over its gold, spits **fireballs** from afar (they follow you like a mage's orb and burn for 2)
and bites whoever comes close. A stab in the back of the sleeping dragon only hits three times as hard.
Every few seconds it draws breath: **red rings** glow on the floor in a line towards you, and a moment
later its **fire breath** sets them ablaze. These **fire fields** burn for 7 seconds; standing in one costs
2 lives at first and 1 every second after, and sets you **burning** (1 life every 1.5 seconds for a few
seconds, never the last one). Step aside, or jump over the flames. Dragons fly through them unharmed.
After each breath the dragon sinks down, **winded**, for a moment: your blade hits twice as hard then.

| Phase | When | What changes |
|---|---|---|
| 1 | full life | fireballs, bites, a line of fire breath |
| 2 | below 60 % | furious: three lines of fire at once, and it breathes more often |
| 3 | below 30 % | raging: quicker, and it **rains fire** around you every few seconds (rings first) |

It guards its hoard and does not follow you far; leave it alone for 15 seconds and it is whole again.

Slay the dragon and the lair is **complete**: a fanfare plays, a window says so, counts the monsters you
have slain and offers to **leave the lair** at once (or stay and collect the loot). Where the dragon fell, a
**golden way out** shines up on the floor: step into it and you stand in front of the stone arch again.

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

## Map and journal

Your hero draws a **map** as they go. In the dungeon everything the fog of war has shown you goes on it,
in the open air everything within about 24 m of you. Press **N** (or “Map” in the pull-out menu) to open it;
the arrows above the map flip through every level you have a map of, and it zooms in on the part you have explored.
Landmarks get a numbered mark once you have seen them, listed beside the map: the stairs, doors, shrines,
fountains, merchants, beds and storage chests below ground, and the crypt, the graveyard, the dragon's lair,
the village buildings, Weavers' Lane, the market fountain, the well, the ponds, the food basket, the bandit camp,
the robbers' pass and the wolf hollow above. Opened secret rooms get a star. Every spot where you found something
gets a small diamond (green for ingredients, blue for fish), and finds of the same thing close together count on one spot.
Below the map you see how much of the level you have explored.

The **journal** on the second page writes down, newest first, every level you arrive at, every landmark you
discover, every secret room and every find, with the day of your journey and the hour. Map and journal are kept
in each hero's saved game. The rules are in `scripts/journal.gd`, the drawing in `scripts/map_view.gd`.
Other features put their finds on the map with `Game.note_find(kind, id, name, pos)`, e.g.
`note_find("ingredient", "mondsilbererz", "Mondsilbererz", pos)` when an ingredient is picked; `Journal.spots_of(id)`
lists every spot where something was found, so a recipe book can show where to look. Ingredients put into the pouch with `Crafting.add` and ore picked up (such as thunder ore) are marked by themselves.

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
| Crafting | any | forge throwing knives (1 per 3 h) or mend worn-down gear (1 durability per 2 h); both train Geschick a little. Secret recipes from trusted villagers add faster knives, faster mending and stone cutting (see Reputation) |
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
| `v`       | bat               | `s`       | slime             |
| `R`       | dragon            | `y`       | horse statue      |
| `X`       | a horror's den    |           |                   |

The lines `name:` and `hint:` give the level's name and the introduction shown when it starts.
A line `lair: yes` on a building floor makes it a dungeon of its own instead of a safe room, with monsters,
dressed with pieces of the dungeon kit (see `levels/13_die_drachenhoehle.txt`, the dragon's lair).
A line `safe: yes` makes a level a safe room, and `elite: yes` gives it stronger skeletons.
A line `dark: yes` makes a level pitch black (no wall torches; the hero needs a hand torch), and `horror: <kind>`
names the horror whose den `X` it is (`hohle_mutter`, `bleicher_waechter` or `schlund`; see the dark holes).
A line like `secret: epic` sets how rich the secret room behind the wall `?` is: `normal`, `uncommon`, `rare`, `epic`
or `godborn` (the older German ids `ungewoehnlich`, `selten`, `episch` and `gottgeboren` still work).

A line `outdoor: yes` turns a level into the world under the open sky (see `levels/11_die_freiheit.txt`).
It has its own characters: `#` forest, `.` meadow, `,` path, `:` paved square, `~` pond, `;` the pond in the wolf hollow, `R` crypt, `g` grave,
`d` dead tree, `z` graveyard fence, `a` gate in the fence, `l` lantern, `p` pumpkins, `r` rock, `T` tree,
`t` tree stump, `e` barrels and crates, `q` well, `F` fountain, `x` bench, `y` pumpkin field, `N` tent,
`f` campfire, `C` treasure chest. The bandits, who roam and come back a while after they fall: `c` cutthroat,
`A` poacher, `X` bruiser, `Q` bandit chief; the beasts of the wolf hollow, who do the same: `W` wolf,
`H` orc, `J` yeti, `U` spider; the peaceful animals of the woods: `D` doe, `V` stag, `&` fox. `E` is the stone arch over the stairs down into the dragon's lair. `(` is a dark hole: the holes are numbered from the top of the map down (west to east in a row), and hole n leads to the floor with `building: loch<n>`. Buildings are a
rectangle of the same character: `h` house, `j` smithy, `n` tavern, `m` general store, `u` windmill,
`s` temple, `k` office of the crown, `o` post office, `w` adventurers' guild, `b` bank, `^` a row of narrow town
houses (one per tile along its front, numbered from west to east, all sharing the floor with `building: ^`). A single
hero's house (not on the map any more): `I` wall, `i` wooden floor (a gap in the wall is the door), `B` bed, `L` chest. The crafting square:
`+` fine metalwork bench, `%` gem cutter's wheel, `*` alchemist's table, `$` your storage chest. The villagers: `0` elder,
`1` smith, `2` farmer, `3` woodcutter, `4` guard, `5` drinker, `6` shopkeeper, `7` child, `8` scholar,
`9` water carrier, `K` herald, `O` priestess, `G` guild master, `M` postmaster, `Y` banker, `Z` barber.

**Floors of buildings.** A level file with the lines `building: b` and `floor: cellar` or
`floor: upstairs` is a floor of the village building with that character: walking in at the
building's door leads there, and its stairs `E` lead back out of the door. Such floors are never part of
the run through the dungeon. Inside, `=` is a wall of iron bars and `U` a vault cell (see
`levels/12_der_tresorkeller.txt`, the bank's vault cellar).
A building floor with the line `home: yes` is a hero's own home (see `levels/14_das_wohnhaus.txt`, the
town houses): wooden floorboards, and several storeys drawn side by side, each a room sealed off by walls and
counted from west to east. `<` are stairs up to the `>` of the next storey and back, `+` is free floor kept
for furniture (the game lists these spots per storey in `Level.furniture_slots`), and the exit `E` is the
front door in the south wall.

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
- The temple's chapel, and the stone and roof tiles of the villagers' houses: Modular Cathedral Kit by SigilsVault (Kevin Barany) (CC0, see `assets/chapel/LICENSE.txt`)
- Floors, walls, pillars and furniture: 3D Modular Dungeon Kit by Omie's Assets (CC0)
- Gorm's own weapons and the kite shield: Medieval Weapon Pack by Omie's Assets (CC0, see `assets/weapons/forge/LICENSE.txt`)
- Wolves, orcs, yeti and spiders: Ultimate Animated Animals, Ultimate Monsters and Easy Animated Enemy Pack by Quaternius (CC0, see `assets/wild/LICENSE.txt`)
- Does, stags and foxes: Ultimate Animated Animals by Quaternius (CC0, see `assets/animals/LICENSE.txt`)
- Bats, slimes and the dragon: Animated Monster Pack; arch, stairs, cobwebs, skulls, banners, coin piles and the horse statue of the dragon's lair: Modular Dungeon kit (May 2019), both by Quaternius (CC0, see `assets/lair/LICENSE.txt`)
- Sounds: made from scratch with `tools/make_sounds.py`; footsteps and door: recordings by Fantozzi, “Footsteps Leather, Cloth, Armor” and qubodup; creatures, skeleton voices and chains by rubberduck; crossbow shots from “Medieval sound effects - Weapon Textures” (CC0, see `assets/sounds/CREDITS.txt`)
- Music: “Abeth” by Audibert jd, from Eleryan Tales volume 1 (2010), www.eleryantales.com (see `assets/music/CREDITS.txt`)
- Font: Cinzel and Cinzel Decorative (SIL Open Font License)
- Comic font of the fight bubbles: Bangers by Vernon Adams (SIL Open Font License)
- Every push to `main` plays through all levels automatically and publishes the browser version via GitHub Pages

## License

© 2026 devilbane. All rights reserved, see [LICENSE](LICENSE). Graphics, music, sounds and fonts by others are under their own licenses (see above).
