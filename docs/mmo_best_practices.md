# What Escape! can learn from the big online RPGs

A review of the user interface, item handling, general usability and code structure of *Escape!*,
measured against what World of Warcraft, Tibia, RuneScape (Old School and RuneScape 3), Dark Age of
Camelot and Ultima Online do, and against the open-source servers and clients built around them
(The Forgotten Server, RuneLite, ModernUO and ServUO, ClassicUO, Dawn of Light, AzerothCore).

Written in November 2026 against `main` at commit `588569b`. Every claim about Escape points at the
code it was read from; every claim about another game has a source at the end.

## How to read this

Each recommendation has the same five parts:

- **Others:** what the reference games do.
- **Escape today:** what the code does now.
- **Suggestion:** the change, kept small and in the game's own style.
- **Effort:** S (an afternoon to a day), M (a few days), L (a week or more, or many files).
- **Risk:** what could go wrong, mainly for saves, layout stability and the tests.

Escape is a single-player game, not an MMO, so not everything carries over. What does carry over is
twenty-five years of polish on the same problems: a small screen full of numbers, a bag that is
always too full, hundreds of items, and a code base that keeps growing. Where an MMO idea does not
fit (server authority, trading between players, raid frames), this report says so instead of
forcing it.

The project's standing rules apply to every suggestion: stable layouts (folding or switching a
section never reshapes the window), Gestalt grouping, simple and readable combat, and everything
through the house helpers of the [`ux-ui` skill](../.claude/skills/ux-ui/SKILL.md).

## What Escape already does well

Several MMO best practices are already in the game. They are listed so nobody "adds" them twice.

| Practice | Reference | Escape |
|---|---|---|
| Item names in rarity colours, with the tier in words for colour-blind players | WoW added the words "Rare" and "Epic" beside blue and purple names in patch 6.1 | `Rarity.label`, `Rarity.bbcode`, `TradeWindow.name_color` |
| Side-by-side comparison with the worn item, green and red deltas | WoW's shift-compare tooltip, `C_TooltipComparison` | `TradeWindow` cards with a "Better" badge |
| Stacks of small things in one slot | Every MMO; AzerothCore's `Stackable` field | `Items.STACK`, `Items.STACK_SLOTS`, `Items.stacks()` |
| One message log to read again | WoW chat frame, UO journal | `EventLog`, 100 lines, fixed size |
| Every HUD value explains itself on hover | WoW tooltips | `tests/hud_tooltips.gd` |
| Teach by doing, one card at a time | WoW's new-player experience | `Tutorial` |
| Fixed window sizes, nothing jumps | — (most MMOs do worse here) | `Menus.WINDOW_SIZES`, `tests/windows_fixed_size.gd` |
| Features talk through events, not each other | RuneLite's `EventBus` with `@Subscribe` | `Events.bus()`, `Game._bus_links()` |
| Map data that is checked by tests | TFS map and item validators | `LevelMap.validate()`, `tests/tile_letters.gd` |

---

## 1. UI and HUD

### 1.1 A HUD that the player can tune, without an editor

- **Others:** WoW's Dragonflight *Edit Mode* lets almost every HUD element move, with options per
  element and named layouts that can be saved, copied and shared. RuneScape 3 went fully free-form,
  and players asked for the old fixed screen back, which became *Classic Interface Layout*. Ultima
  Online's Enhanced Client offers a "legacy containers" switch for the same reason.
- **Escape today:** a fixed, well-reasoned layout (status block top left, event log below it,
  drawer on the right edge, quick buttons on its rail). The only HUD setting is the event log's width
  (`EventLog.MIN_WIDTH`..`MAX_WIDTH`).
- **Suggestion:** do *not* build an edit mode. The lesson from RuneScape is that a good fixed layout
  plus a few switches beats free placement. Add a **HUD scale** slider (0.8 to 1.25, applied to the
  HUD's `CanvasLayer` and to `UiKit.sized`) and a **show/hide** switch for the optional parts (event
  log, chat line, tutorial card). Keep every element's place fixed so the layout guide still holds.
- **Effort:** M. **Risk:** low to medium; every HUD test that measures positions must run at more than
  one scale (`tests/hud_drawer.gd`, `tests/message_overlap.gd`).

### 1.2 A small minimap or compass

- **Others:** every reference game has one. WoW's Dragonflight revamp made the minimap *more*
  prominent while removing clutter elsewhere. Tibia's automap and OSRS's minimap both mark the player,
  stairs and points of interest.
- **Escape today:** a full map window on N (`MapView`, `scripts/map_view.gd`); nothing on the HUD.
- **Suggestion:** a 140 px round minimap in the top right corner, drawn from the same explored-cell
  data as `MapView`, with only three kinds of marks: the hero, the way down (or out) once found, and the
  current quest target. Clicking it opens the map window. A switch in the settings hides it.
- **Effort:** M. **Risk:** low; it reads data the map window already keeps. Watch the frame cost
  (`tests/profile_run.gd`) and draw it to a small `SubViewport` only when the hero changes cell.

### 1.3 Show what the hero is fighting

- **Others:** WoW and DAoC show a *target frame* (name, level, life) and a ring under the target.
  WoW's *Action Combat* option picks the target automatically as the player closes in, which is close
  to what Escape does.
- **Escape today:** melee picks the nearest enemy (`Player._nearest_enemy`), the last target lives in
  `Player._target`, and since PR #495 monsters with more than 100 life show a level and life bar.
  Bosses have `BossBar`.
- **Suggestion:** keep automatic targeting (it fits "simple combat"), but make it visible: a soft
  ground ring under `_target` in the rarity-neutral gold, and the same small life bar over it whatever
  its life. No tab-targeting, no target-of-target.
- **Effort:** S. **Risk:** low; the ring must follow with `SmoothMotion.drawn_at`.

### 1.4 Filters for the event log

- **Others:** WoW's chat frame has tabs and per-tab message types (loot, combat, say, system), and
  its accessibility patch added narration per channel. UO's journal and ClassicUO filter by type.
  OSRS's chat has "game / public / private" tabs with on/off states.
- **Escape today:** one stream for loot, speech and the messages over the hero's head
  (`EventLog`, `scripts/event_log.gd`), 100 lines, no filter.
- **Suggestion:** give every line a kind when it is told (a new optional argument on `Events.tell(text, colour, duration)`: `loot`,
  `talk`, `news`) and add a fixed row of three small toggle chips above the log ("Loot", "Talk",
  "News"). Turning one off hides those lines without changing the box's size. Remember the choice in
  the settings file like the width.
- **Effort:** S to M. **Risk:** low; the box keeps its size. Every `Events.tell` caller gets a default
  kind, so nothing has to change at once.

### 1.5 Interaction prompt when in reach

- **Others:** WoW's *Interact Key* (Dragonflight) shows an icon over the nearest usable NPC or object
  and uses it with one key. Tibia and OSRS show the action on hover ("Open Chest").
- **Escape today:** things are used by walking into them or clicking them; the keys E, Q and B work
  on crates and stones only.
- **Suggestion:** when something usable is within one cell and the hero faces it, show a small key
  glyph over it ("E") and let E use it (open the chest, talk, read the board). Running into things keeps
  working. This gives keyboard players one key for everything and is a big help on touch, where a
  single "Use" button can do the same.
- **Effort:** M. **Risk:** medium; E is already "pick up crate", so the rule must be "the nearest
  usable thing wins", with a test for each kind.

---

## 2. Inventory and item handling

### 2.1 Loot rules: what the hero picks up by walking over it

- **Others:** Tibia's *Quick Loot* (2017) sends a corpse's contents to containers by category, with an
  *accepted* and a *skipped* list. OSRS's *Ground Item Indicators* (2023) label items on the floor, sort
  them into up to five value tiers with colours, hide items below a value and hide items by name.
  RuneLite's *Ground Items* plugin does the same with lists like `bones, item<5`.
- **Escape today:** every item on the floor is taken when the hero walks over it, as long as it fits
  (`Level` pickup loop around `scripts/level.gd:3699`). The bag holds 8 slots (`Items.BAG_SIZE`), 20 with
  a backpack, so it fills with common gear and the player must open the inventory and throw things
  away ("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg.").
- **Suggestion:** two small rules, set in the inventory:
  1. **"Leave on the floor"** on an item's details: that item id is never picked up by walking again
     (it can still be clicked). A list in the settings undoes it.
  2. **A minimum rarity** for walk-over pickup (all / uncommon and up / rare and up), as a three-way
     switch beside the bag tab. Coins, quest items, keys and ammunition are always taken.

  Items left lying get a short name label in their rarity colour on the floor while the hero is near,
  so nothing valuable is missed.
- **Effort:** M. **Risk:** low; the rule only filters the pickup loop. Save the two settings with the
  game (they are about this hero), and test that quest items are never skipped.

### 2.2 Compare in the bag, not only in the shop

- **Others:** WoW shows the worn item beside any item tooltip, in the bag as in a shop; Shift forces
  it. DAoC's delve window and OSRS's equipment stats screen do the same job.
- **Escape today:** the comparison cards exist only in `TradeWindow`. The inventory's details box
  (`Menus._inventory_details`) shows the item's own text.
- **Suggestion:** reuse `TradeWindow`'s card pair in the inventory's details area for any wearable item
  (picked or under the pointer): "this item" against "worn now", with the same green/red lines and
  "Better" badge. The details box already has a fixed size, so the window does not change.
- **Effort:** S to M. **Risk:** low; the cards already work and are tested in
  `tests/merchant_window.gd`.

### 2.3 Fast actions on an item

- **Others:** WoW: right-click uses or equips, Shift-click links, Ctrl-click previews. OSRS: the first
  menu option on left click, *shift-click to drop* as an option. Tibia: *Loot Click* moves an item with
  one click instead of a drag. UO: double-click uses.
- **Escape today:** click to pick an item, then click "Anlegen" or "Wegwerfen" beside the details
  (`Menus._build_inventory`, `_inventory_details`). Two clicks for everything.
- **Suggestion:** keep the two-click path (it is the touch path) and add the fast ones:
  double-click or right-click equips a wearable, drinks a potion or uses the item's first action;
  Shift-click drops one. List them in `Menus.SHORTCUTS`. In chests and the vault, double-click moves
  the item to the other side.
- **Effort:** S. **Risk:** low; double-click must not also trigger the single-click pick twice (pick on
  the first, act on the second).

### 2.4 Sort and tidy

- **Others:** WoW's bags have a "clean up" button and the *Combined Backpack*; Tibia sorts loot by
  category into containers; RuneLite's *Bank Tags* add tags and a `tag:` search.
- **Escape today:** the bag is a plain list in pickup order (`Player.bag`); the grid groups stacks but
  never sorts.
- **Suggestion:** a "Sort" button on the bag tab that orders by slot (as in `Items.SLOTS`), then by
  rarity, then by name, with stacks merged. In the storage chest and the vault, a search field over the
  grid once they hold more than about 20 things.
- **Effort:** S (sort), M (search). **Risk:** low; the bag stays a list of ids, so saves are untouched.

### 2.5 Quick slots the player fills

- **Others:** WoW and DAoC put anything on an action bar (DAoC has several quickbars whose slots are bound to keys);
  OSRS keeps it to a few prayers and special attacks; WoW's *Press and Hold Casting* helps players who
  cannot tap fast.
- **Escape today:** two fixed quick buttons, potion on 1 and Unleashed Power on 2, plus the torch on V
  (`game._setup_quick_bar`).
- **Suggestion:** turn the potion button into **three player-filled slots on 1, 2, 3** for consumables
  (potions, food, throwing knives, torch); Unleashed Power moves to 4 when learned. An item gets there by
  "Put on quick slot" in its details or by dragging it onto the slot. Keep the count and the cooldown
  shading the potion button already has. More than four would go against simple combat.
- **Effort:** M. **Risk:** medium; key 2 changes meaning, so say it once in the patch notes and the
  compendium; migrate the old layout in the save (see 4.3).

### 2.6 Drag and drop (later, optional)

- **Others:** UO and Tibia are built on dragging items between containers, the paperdoll and the
  floor; WoW and DAoC too.
- **Escape today:** no drag and drop in windows (`menus.gd` has no `_get_drag_data`).
- **Suggestion:** only after 2.3, and only between grids that are open together (bag and chest, bag and
  worn slots, bag and quick slots), with Godot's built-in `_get_drag_data` / `_can_drop_data` /
  `_drop_data`. Click paths stay, because touch and keyboard need them.
- **Effort:** M to L. **Risk:** medium; the windows are rebuilt from scratch on every change
  (`Menus._rebuild`), so a drag must survive a rebuild or block it while dragging.

### 2.7 Guard against losing something rare

- **Others:** OSRS asks before dropping an item worth more than 30,000 coins, and keeps a dropped
  untradeable item for 3 minutes.
- **Escape today:** "Wegwerfen" puts the item on the floor at once (`Menus._drop_selected`). Floor items
  are kept across levels and saves (`tests/floor_items.gd`), so nothing is lost, but the player may not
  know that.
- **Suggestion:** no dialog. For rare and better items, the first click turns the button into
  "Really drop?" for three seconds, the same two-click pattern the load window uses to delete a save.
  The note after dropping says "lies on the floor here".
- **Effort:** S. **Risk:** low.

### 2.8 One item record, one place

- **Others:** AzerothCore's `ItemTemplate` keeps every property of an item on one record (quality,
  `Stackable`, `MaxCount`, bonding, required level) and answers questions through predicates
  (`IsPotion()`, `IsWeapon()`, `HasFlag()`). The Forgotten Server splits a static `ItemType` (the
  definition from `items.xml`) from an `Item` (one thing in the world).
- **Escape today:** the definitions live in `Items.ALL` (`scripts/items.gd`), already a good static
  table, and the hero carries ids only. But some properties sit in side tables: stack sizes in
  `Items.STACK` and `Items.STACK_SLOTS`, rarity in `Items.RARITY`, levels in `Items.LEVELS`, and kinds
  are answered by predicates that look at the id or other tables (`is_potion`, `is_ammo`, `is_food`,
  `is_material`, ...).
- **Suggestion:** move each item's stack size and kind (`"kind": "potion" | "ammo" | "food" | "gear" |
  "material" | "quest" | ...`) into its own entry in `Items.ALL`, and have the predicates read the
  field. Add `tests/item_schema.gd` that checks every entry: known keys only, a slot or a kind, a
  price, a weight, a picture, an English name. This is what TFS's item loader and AzerothCore's
  database columns give for free. Loot rules (2.1), sorting (2.4) and quick slots (2.5) all need the
  kind.
- **Effort:** M. **Risk:** low if done with the schema test first; ids stay the same, so saves stay
  valid.

---

## 3. Usability and accessibility

### 3.1 Key rebinding

- **Others:** all five reference games let the player rebind keys; the Game Accessibility Guidelines
  name remapping as one of the four most complained-about gaps (with text size, colour blindness and
  subtitles).
- **Escape today:** keys are a hand-written `match` on `physical_keycode` in `Game._unhandled_input`
  (`scripts/game.gd`, about 34 `KEY_*` checks) and in `Player`; `project.godot` has no `[input]`
  section. The compendium's control list (`Menus.SHORTCUTS`) and the README spell the keys out by hand.
- **Suggestion:** two steps. First, move every key into Godot input actions (`InputMap`, with the
  current keys as defaults) and check `event.is_action_pressed("melee")` instead of the key code; no
  visible change. Second, a "Controls" page in the settings that rebinds an action
  (`InputMap.action_erase_events` + `action_add_event`), saves to the settings file and lets
  `SHORTCUTS` read the current binding (`ux-ui` §11 already asks for this).
- **Effort:** M (step one), M (step two). **Risk:** medium; input is central. A test that presses each
  default key and checks the action, written before the change, keeps it safe.

### 3.2 Text size, motion and flashes

- **Others:** WoW's accessibility panel collects text contrast (a solid background behind quest
  text), colour-blind filters with a strength slider, and reduced camera motion. The Game Accessibility
  Guidelines' basic list asks for readable default text, no flicker, and remembered settings.
- **Escape today:** the settings are music and effects volume with mute, the event log's width, and
  the language (`set_value("musik"|"ton"|"protokoll", ...)`). Camera shakes exist in several places
  (`Events`, `VitalStrike`, `Horrors`, `VillageAlarm`, ...).
- **Suggestion:** one "Display" group in the settings with: **text size** (100 / 115 / 130 %, through
  `UiKit.sized`), **screen shake** on/off (one switch read by every shake through the event bus), and
  **solid backgrounds** for the event log and speech bubbles. The windows already fit the screen with
  `Menus._fit`, so larger text scrolls instead of breaking.
- **Effort:** M. **Risk:** medium for text size (every fixed-size window must be checked at 130 %;
  extend `tests/windows_fixed_size.gd` to run at each size), low for the other two.

### 3.3 One settings window

- **Others:** WoW keeps all options in one *Options* window with categories (Gameplay, Accessibility,
  Controls, Audio); OSRS has one settings panel with a search box.
- **Escape today:** the sliders sit in the pull-out drawer (`_music_slider`, `_effects_slider`,
  `_log_width_slider` in `game.gd`); the language is picked on the title screen.
- **Suggestion:** a "Settings" window (in the drawer and on the title screen) built like the
  compendium: tabs at the top, all pages one size. Pages: Sound, Display (3.2), Controls (3.1), Loot
  (2.1). The drawer keeps its two volume sliders as a shortcut.
- **Effort:** M. **Risk:** low; a new window with an entry in `Menus.WINDOW_SIZES`.

### 3.4 Say what is new, once

- **Others:** WoW marks new items in the bag with a glow until hovered, and new spells on the
  spellbook tab; OSRS flashes a tab when something in it changes.
- **Escape today:** finds are announced in the event log and with the loot fanfare; the inventory does
  not mark what is new.
- **Suggestion:** a small gold dot in the corner of a bag cell for items picked up since the bag was
  last opened, and on the quick icon of a window whose content changed (a new quest, a new recipe).
  The dot sits inside the cell, so nothing moves.
- **Effort:** S. **Risk:** low.

### 3.5 Onboarding beyond the first level

- **Others:** WoW's *Exile's Reach* teaches one system per step and points at the UI element it
  means; Tibia's *Rookgaard* keeps new players in a safe area.
- **Escape today:** `Tutorial` covers walking, running, the dagger, knives, sneaking and jumping in
  the cell; later systems are explained by hints (`Game._hint`) and the compendium.
- **Suggestion:** use the same card for the first time a window matters: the first full bag (point at
  the bag icon, explain "Leave on the floor"), the first merchant (point at the comparison cards), the
  first camp. A pulsing outline on the quick icon it means, gone after one use.
- **Effort:** S per card. **Risk:** low.

---

## 4. Code structure

### 4.1 Split the three biggest files

- **Others:** RuneLite is a set of plugins, each with its own config, overlays and `@Subscribe`
  handlers, started and stopped on their own. Dawn of Light keeps game rules in `GameServerScripts`,
  apart from the engine in `GameServer`.
- **Escape today:** 175 scripts, most of them small and focused, but three are very large:
  `game.gd` 7,146 lines (308 functions: title screen, HUD, input, saving, camera, levels, many
  features), `level.gd` 5,923 and `menus.gd` 4,596 (173 functions, about 560 references to `game.`).
- **Suggestion:** move out what has clear edges, one pull request each, without changing behaviour:
  - from `game.gd`: `SaveGame` (save, load, slots, `save_info`, the `data` dictionary), `Hud`
    (`_setup_hud`, bars, quick bar, drawer) and `InputRouter` (the `_unhandled_input` match, which 3.1
    rewrites anyway);
  - from `menus.gd`: one script per window under `scripts/windows/` (inventory, storage, character,
    compendium, map, load, bed and camp), each with `build(box)` and its size from `WINDOW_SIZES`;
    `Menus` keeps opening, closing, fitting, focus and the shared helpers. `TradeWindow` already shows
    that this works.
- **Effort:** L in total, M per piece. **Risk:** medium; mechanical moves break little, but each
  needs the full test run (see 4.5).

### 4.2 More signals, fewer reach-ins

- **Others:** RuneLite plugins never call each other; they post and subscribe to events
  (`MenuEntryAdded`, `ConfigChanged`). The Godot inventory pattern by uhiyama-lab keeps item logic in one
  place that emits `inventory_changed` and lets the UI redraw.
- **Escape today:** the bus exists with 24 signals and one wiring list (`Game._bus_links`,
  `tests/events.gd`). Windows still read and write the game's state directly (`game.player.bag`,
  `game.coins`, `game.crafting`).
- **Suggestion:** add `bag_changed`, `coins_changed` and `settings_changed` signals and move the bag's
  writes (add, remove, equip, drop) into a few functions on `Player` that emit them. Then the HUD, quick
  slots and the "new item" dot (3.4) listen instead of being refreshed by hand.
- **Effort:** M. **Risk:** low to medium; done slowly, one writer at a time.

### 4.3 Versioned saves with a migration chain

- **Others:** RunUO, ServUO and ModernUO write a version number per object and read old versions
  with a `switch (version)`; ModernUO's generator refuses to compile a version bump without a
  `MigrateFrom` method. The Godot inventory article warns that ids tied to file paths break old saves.
- **Escape today:** `Game.save_game` writes one JSON dictionary of about 50 keys with `"version": 1`
  (`scripts/game.gd:3868`), and the number has never changed: old saves are handled by `get(key,
  default)` everywhere. Some parts already save themselves (`quests.for_save()`, `bounties.for_save()`,
  `Factions.for_save()`).
- **Suggestion:** a small `SaveMigrations` script: `const CURRENT := 2` and
  `static func upgrade(data) -> Dictionary` that runs `_v1_to_v2`, `_v2_to_v3`... in order on load. Bump
  the number whenever a key is renamed or its meaning changes (quick slots in 2.5 are the first case).
  Add `tests/save_migrations.gd` with a frozen version-1 save in `tests/data/` that must keep loading.
  Make every remaining part save itself with `for_save()` / `from_save()` so `save_game` becomes a list.
- **Effort:** S (the chain and the test), M (the `for_save` cleanup). **Risk:** low, and it lowers the
  risk of every later change to saved data.

### 4.4 Simulation apart from presentation

- **Others:** MMOs keep game rules on the server and the client only shows them; OSRS runs every rule
  on a fixed 0.6-second tick. For a single-player game the useful part is the split, not the network:
  rules in plain objects that can be tested without a scene.
- **Escape today:** much of this is already done well: `Items`, `Loot`, `Rarity`, `Training`,
  `Factions` and `MonsterFamilies` are `RefCounted` or static tables. Combat rules sit inside the nodes
  (`Player`, `Enemy`, 2,800 and 2,700 lines).
- **Suggestion:** when touching combat, pull the numbers (hit, block, armour cut, damage) into a static
  `Combat` script with pure functions, and let `Player` and `Enemy` call it. The combat balance sheets in the
  project's shared files (`escape/balance/`) could then be checked by a test against the same functions.
- **Effort:** M. **Risk:** medium; combat feel must not change, so start with a test that records
  today's numbers.

### 4.5 Run every test in CI

- **Others:** RuneLite and the emulators run their whole test suite on every pull request.
- **Escape today:** 201 tests in `tests/`, 156 of them named one by one in `.github/workflows/web.yml`.
  45 are never run by CI, among them `loot.gd`, `pause_menu.gd`, `windows_fit_screen.gd`,
  `bounties.gd`, `companions.gd`, `speech_bubble.gd`, `storage_stacking.gd` and `stride.gd` (the profile
  runs are rightly left out).
- **Suggestion:** replace the list with a loop over `tests/*.gd` and a short skip list
  (`profile_*.gd`, anything that needs a display), so a new test runs from the day it is added. Fix
  or skip, with a reason, the ones that fail today.
- **Effort:** S. **Risk:** low for the game, but expect a few red tests the first time; CI time grows
  by the 45 tests.

### 4.6 Translations: keep the system, add plurals

- **Others:** the big games use string ids; Godot supports gettext `.po` files, where the source text
  is the id, which is what Escape does.
- **Escape today:** German text is the key, English lives in one file per feature in `scripts/lang/`,
  merged into `Lang.EN`, with `tests/lang_keys.gd` guarding it. This works and is well tested.
- **Suggestion:** keep it. Add one thing the gettext model has and Escape lacks: plural forms
  (`Lang.tn("1 Fackel", "%d Fackeln", n)`), so counts read right in both languages. If a third language
  ever comes, export the tables to `.po` with a small tool instead of changing the code.
- **Effort:** S. **Risk:** low.

---

## 5. Top 10, ranked

Ranked by what the player gains per day of work, with the risk to saves and layouts weighed in.

| # | Change | Section | Effort | Risk |
|---|---|---|---|---|
| 1 | Loot rules: "leave on the floor" and a minimum rarity for walk-over pickup, rarity labels on the floor | 2.1 | M | Low |
| 2 | Compare with the worn item in the bag | 2.2 | S–M | Low |
| 3 | Fast item actions (double-click, right-click, Shift-click) | 2.3 | S | Low |
| 4 | Run every test in CI | 4.5 | S | Low |
| 5 | Versioned saves with a migration chain and a frozen old save | 4.3 | S | Low |
| 6 | Input actions, then key rebinding | 3.1 | M + M | Medium |
| 7 | Item kind and stack size in each item's entry, with a schema test | 2.8 | M | Low |
| 8 | Settings window with text size, screen shake and solid backgrounds | 3.2, 3.3 | M | Medium |
| 9 | Three player-filled quick slots on 1–3 | 2.5 | M | Medium |
| 10 | Split `game.gd` and `menus.gd` along clear edges | 4.1 | L | Medium |

Close behind: sort button (2.4), event log filters (1.4), visible target ring (1.3), minimap (1.2),
new-item dot (3.4).

## 6. Roadmap: follow-up threads

Each line is one thread with one pull request (or a short series), in an order where each step
prepares the next. The first three are groundwork the player does not see.

1. **Run all tests in CI** (4.5). Loop over `tests/*.gd` with a skip list; fix or skip today's
   failures with reasons.
2. **Save migrations** (4.3). `SaveMigrations`, `CURRENT := 2`, a frozen version-1 save and its test.
3. **Item kinds in the item table** (2.8). `kind` and `stack` on every entry, predicates read them,
   `tests/item_schema.gd`.
4. **Compare in the bag** (2.2). Reuse the `TradeWindow` cards in the inventory's details area.
5. **Fast item actions and sort** (2.3, 2.4). Double-click, right-click, Shift-click, a Sort button;
   update `SHORTCUTS` and the README.
6. **Loot rules** (2.1). "Leave on the floor", the rarity switch, floor labels; a test that quest items
   are always taken.
7. **Input actions** (3.1, step one). Every key as an `InputMap` action, no visible change, a test per
   default key.
8. **Settings window** (3.3, 3.2, 3.1 step two). Sound, Display (text size, shake, solid backgrounds),
   Controls (rebinding), Loot.
9. **Quick slots** (2.5). Three slots on 1–3, power on 4, save migration v2 → v3, patch note.
10. **Split `game.gd`** (4.1). `SaveGame`, `Hud`, `InputRouter`, one PR each.
11. **Split `menus.gd`** (4.1). One script per window under `scripts/windows/`.
12. **HUD polish** (1.2, 1.3, 1.4, 3.4). Minimap, target ring, log filters, new-item dot; one thread
    each if preferred.

Every visible change in 4 to 12 follows the `ux-ui` checklist and adds a line to
`docs/patch_notes.txt`.

---

## Sources

**World of Warcraft**
- Blizzard, *Dragonflight HUD and UI Revamp* (Edit Mode, layouts, Combined Backpack, Interact Key,
  Action Combat, Press and Hold Casting): https://worldofwarcraft.blizzard.com/en-us/news/23841481
- Blizzard, *Enhance Your Gameplay: Accessibility Updates Now Live* (text narration, quest text
  contrast): https://news.blizzard.com/en-us/article/23691035/enhance-your-gameplay-accessibility-updates-now-live
- Blizzard, *New Colorblind Support in Patch 6.1* (words beside rarity colours, filters with a
  strength slider): https://worldofwarcraft.blizzard.com/news/17964863
- Warcraft Wiki, `C_TooltipComparison.GetItemComparisonDelta`:
  https://warcraft.wiki.gg/wiki/API_C_TooltipComparison.GetItemComparisonDelta
- Warcraft Wiki, *HUD*: https://warcraft.wiki.gg/wiki/HUD

**RuneScape**
- OSRS Wiki, *Update: Ground Item Indicators, Loot Tracking & More* (2023):
  https://oldschool.runescape.wiki/w/Update:Ground_Item_Indicators,_Loot_Tracking_&_More
- OSRS Wiki, *Drop* (despawn timers, confirmation for valuable drops, shift-click drop):
  https://oldschool.runescape.wiki/w/Drop
- OSRS Wiki, *Game tick*: https://oldschool.runescape.wiki/w/Game_tick
- OSRS Wiki, *Bank tags*: https://oldschool.runescape.wiki/w/Bank_tags
- RuneScape Wiki, *Classic Modes* (Classic Interface Layout): https://runescape.wiki/w/Classic_Modes
- RuneLite wiki, *Ground Items*: https://github.com/runelite/runelite/wiki/Ground-Items
- RuneLite wiki, *Bank Tags*: https://github.com/runelite/runelite/wiki/Bank-Tags
- RuneLite wiki, *Developer Guide* (plugins, config, overlays, `@Subscribe`):
  https://github.com/runelite/runelite/wiki/Developer-Guide
- RuneLite API, `BankTagsPlugin`:
  https://static.runelite.net/runelite-client/apidocs/net/runelite/client/plugins/banktags/BankTagsPlugin.html

**Tibia and OpenTibia**
- TibiaQA, *Can I decide where specific loot should go?* (Quick Loot, loot containers, accepted and
  skipped lists): https://www.tibiaqa.com/20639/can-i-decide-where-specific-loot-should-go
- DeepWiki on The Forgotten Server (`ItemType` and `Item`, `items.xml` attributes):
  https://deepwiki.com/daanyx/forgottenserver-downgrade/4.3-items-and-equipment
- OTLand, *The Forgotten Server 1.4*: https://otland.net/threads/the-forgotten-server-1-4.278046/

**Ultima Online**
- uo.com, *Enhanced Client Container Views* (grid and legacy containers): https://uo.com/?p=22971
- TazUO wiki, *Grid Containers* (ClassicUO fork): https://github.com/bittiez/TazUO/wiki/TazUO.Grid-Containers
- ModernUO, *SerializationGenerator* (versioned serialization, `MigrateFrom`):
  https://github.com/modernuo/SerializationGenerator
- ServUO, *Beginner guides: serialization and deserialization*:
  https://www.servuo.dev/threads/beginner-guides-serialization-and-deserialization.16923/latest

**Dark Age of Camelot**
- Camelot Herald, *Using and Understanding the Interface*: https://camelotherald.com/node/260
- Camelot Herald, *Slash Commands*: https://camelotherald.com/node/43
- Dawn of Light (DOLSharp) emulator: https://github.com/Dawn-of-Light/DOLSharp

**World of Warcraft emulators**
- AzerothCore, `ItemTemplate` (stackable, quality, predicates):
  https://azerothcore.org/doxygen/d4/d69/structItemTemplate.html

**Accessibility and Godot**
- *Game Accessibility Guidelines*, basic level: https://gameaccessibilityguidelines.com/basic/
- Godot docs, `InputMap`: https://docs.godotengine.org/en/4.2/classes/class_inputmap.html
- Godot docs, *Localization using gettext*:
  https://docs.godotengine.org/de/4.4/_sources/tutorials/i18n/localization_using_gettext.rst.txt
- uhiyama-lab, *Designing an Inventory System: Item Management with Resources and Signals* (Godot):
  https://uhiyama-lab.com/en/notes/godot/inventory-system/
