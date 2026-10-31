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
| Melee | run into the enemy or F | click the enemy, “Strike” button |
| Throwing knife | R | right click while standing, “Throw” button |
| Use, search | run into it | click the object |
| Inventory | I | “Inventory” button |
| Compendium | H | “Compendium” button |
| Load saved game | L | “Load” button (also on the title screen) |
| Quit game | Esc | “Quit” button, top right |
| Sound on/off | M | “Sound” button, top right |
| Zoom | + and − | mouse wheel (up close the camera tilts and you see the face) |

A jump from a run keeps its momentum: the faster you are, the farther you fly.

Run into a skeleton and you fight automatically: as long as you stand next to it, you keep striking.
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
Blades, Axes and Knife throwing give a 5 % chance per level of a heavy hit (+1 damage), Blocking +2 %
block chance, Wearing armour makes hard armour 6 % lighter, Sneaking makes you 3 % faster.
Some items add levels themselves (shadow cloak +2 Sneaking, crest shield +1 Blocking,
chain mail +1 Wearing armour, silver bracelet +1 Knife throwing). Everything is shown in the inventory, with the progress
towards the next point. What your hero has learned stays saved with their name, even across new games.

After every 4 levels you reach a **safe room** without enemies, the refuge. It has a **fountain**
that refills your life and cures poison and curses, a storage chest, a merchant who buys and sells for gold, and a bed. The game saves automatically when you enter the refuge; the bed saves once more and logs you out. If the hero falls later, the saved game is kept: a click on the “Fallen” screen continues the game from the refuge, N starts a new one.
On the next start you continue from there with a click or a key. The saved game is stored in the browser.

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

The exit `E` needs a wall to the north (top) and is entered from the south.
A door `D` stands in a passage one tile wide.

## Languages

Texts in the code are written in German and translated to English in `scripts/lang.gd`. Labels and
buttons translate themselves; composed texts go through `Lang.t()`. Every new text needs an English
entry there.

## Technology

- Engine: [Godot 4.5](https://godotengine.org) with the Compatibility renderer, so it runs in the browser
- Graphics: KayKit Dungeon Remastered, Adventurers and Skeletons by Kay Lousberg (CC0)
- Floors, walls, pillars and furniture: 3D Modular Dungeon Kit by Omie's Assets (CC0)
- Sounds: made from scratch with `tools/make_sounds.py`; footsteps and door: recordings by Fantozzi, “Footsteps Leather, Cloth, Armor” and qubodup; creatures, skeleton voices and chains by rubberduck; crossbow shots from “Medieval sound effects - Weapon Textures” (CC0, see `assets/sounds/CREDITS.txt`)
- Font: Cinzel and Cinzel Decorative (SIL Open Font License)
- Comic font of the fight bubbles: Bangers by Vernon Adams (SIL Open Font License)
- Every push to `main` plays through all levels automatically and publishes the browser version via GitHub Pages

## License

© 2026 devilbane. All rights reserved, see [LICENSE](LICENSE). Graphics and fonts by others are under their own licenses (see above).
