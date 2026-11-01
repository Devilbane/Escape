---
name: ux-ui
description: UX and UI best practices (Gestalt laws, Nielsen heuristics, Fitts's and Hick's laws, hierarchy, layout stability, colour, accessibility, game UI). Use before designing, building, reviewing or changing any UI, window, HUD, menu, inventory or shop.
---

# UX and UI guidelines (Escape!)

This is the reference every person and every AI assistant reads **before** building or changing
anything the player sees or touches: windows, the HUD, the pull-out menu, buttons, labels,
tooltips, icons, sounds that give feedback, and controls.

Part 1 (principles) and Part 3 (checklist) apply to any interface. Part 2 and the list of known
gaps are specific to the Godot game *Escape!* (repository `devilbane/escape`); outside that project,
read them as worked examples.

It has three parts:

1. **Principles**: the general knowledge (Gestalt laws, Nielsen's heuristics, Fitts's and Hick's
   laws, visual hierarchy, accessibility, game-UI patterns), each with a rule for this game.
2. **The Escape! house style**: the concrete values, helpers and patterns the game already uses,
   so new UI looks and behaves like the old.
3. **The checklist**: what to verify before a UI change is done.

When a rule here conflicts with a direct request from the game's owner, the request wins. Say so
in the pull request when you depart from this guide, and why.

---

## Contents

- [Part 1: Principles](#part-1-principles)
  - [1. Gestalt laws](#1-gestalt-laws)
  - [2. Nielsen's ten usability heuristics](#2-nielsens-ten-usability-heuristics)
  - [3. Laws of interaction](#3-laws-of-interaction)
  - [4. Visual hierarchy and typography](#4-visual-hierarchy-and-typography)
  - [5. Layout stability](#5-layout-stability)
  - [6. Feedback and state](#6-feedback-and-state)
  - [7. Colour](#7-colour)
  - [8. Accessibility](#8-accessibility)
  - [9. Writing UI text](#9-writing-ui-text)
  - [10. Game UI specifics](#10-game-ui-specifics)
  - [11. Input: mouse, touch, keyboard, controller](#11-input-mouse-touch-keyboard-controller)
  - [12. Motion and sound](#12-motion-and-sound)
- [Part 2: The Escape! house style](#part-2-the-escape-house-style)
- [Part 3: Checklist before a UI change is done](#part-3-checklist-before-a-ui-change-is-done)
- [Known gaps in the current UI](#known-gaps-in-the-current-ui)

---

# Part 1: Principles

## 1. Gestalt laws

The eye groups what it sees before the mind reads it. Gestalt laws describe how. Use them on
purpose, because the player will apply them whether you meant it or not.

### 1.1 Proximity

Things that are close together are seen as one group. Spacing *is* structure.

- Space **inside** a group must be clearly smaller than space **between** groups. A good rule of
  thumb is at least 1.5× to 2×: rows of one category 6 px apart, categories 12 to 16 px apart.
- A label belongs to the control nearest to it. Put a caption closer to its own field than to the
  next one, never halfway between.
- A button that acts on one row lives in that row (as the "Buy" button in each merchant row does),
  not in a toolbar far away.
- Do not use dividers to fix grouping that spacing should already make clear.

### 1.2 Similarity

Things that look alike are read as doing alike. Things that look different are read as different.

- Every button that does the same kind of thing uses the same style, size and font
  (`game._make_button`). A new look means a new meaning, so do not invent one by accident.
- Every price looks like a price (coin icon + number, green when affordable, red when not), in every
  window.
- The colour of a topic stays the same everywhere: gold for gold and titles, `REPUTATION_COLOR`
  violet for everything about the villagers' goodwill, green for "better", red for "worse".
- Conversely, two things that behave differently must not look the same. A disabled button must not
  look like an enabled one; a header that folds must not look like a plain label.

### 1.3 Common region

Things inside one shared border or background belong together. This is stronger than proximity.

- Use a panel (a `PanelContainer` with a `StyleBoxFlat`) to bind a group: one row of the trade
  window, one card, one category header.
- Do not nest more than about three levels of bordered boxes. Box in box in box becomes noise; use
  spacing and type size for the inner levels.

### 1.4 Figure and ground

The eye separates a foreground figure from its background. The player must always know which is
which.

- A window that pauses the game sits on a dark, mostly opaque panel (`panel_style`: background
  alpha 0.9) so the world behind reads as ground, not as content.
- Text drawn over the 3D world needs an outline and a shadow (`game._make_label` adds both); never
  rely on the scene behind to provide contrast.
- The focused or picked element is the figure: give it a brighter border and background (the picked
  trade row turns gold with a 2 px border), and keep everything else calmer.

### 1.5 Continuity (good continuation)

The eye follows lines and alignments. Elements on one line are read as a sequence.

- Align edges. Columns of rows, cards and buttons share a left edge (or a centre line when the
  window is centred). A card that starts 3 px lower than its neighbour looks like a mistake.
- Where something sits above one column but not the other (a badge above one card), put an equal
  spacer above the other column so the cards still start on one line, or move the extra element
  inside its card.
- Reading order is left to right, top to bottom. Put the thing to look at first top left (or top
  centre in a centred window), and the final action (Buy, Close) at the end of that path.

### 1.6 Closure

The mind completes shapes that are almost closed. A rounded panel with a gap still reads as a
panel; an icon need not draw every line.

- Icons can be simple silhouettes; the player fills in the rest. Keep them readable at their
  smallest use size (12 to 18 px in this game).
- The pull-out menu's handle and panel share one border with the inner edge left open, so they read
  as one drawer. Keep that when changing it.

### 1.7 Common fate

Things that move together are seen as one group.

- Animate a group as one: when the drawer slides in, all its buttons slide with it. Never let parts
  of one group move at different speeds.
- Conversely, do not move unrelated things at the same moment; the player will think they are
  connected.

### 1.8 Prägnanz (simplicity)

The eye prefers the simplest reading of a shape. Simple, regular layouts are read faster.

- Prefer grids and straight columns over scattered placement.
- Fewer distinct sizes, colours and borders make a calmer window. Before adding a new style, look for
  an existing one that fits.

### 1.9 Uniform connectedness

Elements joined by a line or a shared shape are grouped more strongly than by proximity or
similarity. Use connecting lines sparingly (e.g. a speech bubble's tail to its speaker) and make sure
they point at the right thing.

### 1.10 Focal point

The element that differs most from its surroundings grabs attention first. There should be exactly
one per window: the title, the picked item, or the main action. If two things shout, neither is
heard.

---

## 2. Nielsen's ten usability heuristics

Jakob Nielsen's heuristics are the standard checklist for judging an interface. Each is given here
with what it means for this game.

1. **Visibility of system status.** The player always knows what is going on: lives, gold, knives,
   key, the run bar, whether sound is on, whether a quest is active. After every action there is a
   visible (and where fitting, audible) reaction within 100 ms. A purchase updates the gold line at
   once; a disabled button tells why (not enough gold, slot full).
2. **Match between the system and the real world.** Use words and pictures from the game's world,
   not from programming: "Gold", "Sell", "Mend", not "Transaction" or "item_id". Order things the way
   the world does (head, body, hands, feet; cheap to dear).
3. **User control and freedom.** Every window has an obvious way out (a "Close" or "Back to game"
   button, and Esc). Undo or confirm anything that is hard to reverse: deleting a save takes two
   clicks, as the load window does; selling a worn or unique item should be confirmable.
4. **Consistency and standards.** The same action has the same name, place and look everywhere.
   All merchants use `TradeWindow`; a new shop does too. Platform conventions apply: Esc closes,
   Enter or Space confirms, the mouse wheel scrolls lists.
5. **Error prevention.** Better than a good error message is no error. Disable what cannot be done
   (and show why), clamp numbers to valid ranges, ask before something cannot be undone.
6. **Recognition rather than recall.** Show, do not make the player remember: item stats on hover,
   the comparison with what is worn right now, shortcut keys listed in the compendium, prices next
   to the buy button.
7. **Flexibility and efficiency of use.** Beginners click; experienced players use keys (I, P, H,
   Tab, Esc). Offer both for every frequent action, and do not make the fast path the only path.
8. **Aesthetic and minimalist design.** Every element competes with every other. Remove what does
   not help the decision at hand; hide detail until it is asked for (the trade cards appear only when
   a row is picked).
9. **Help players recognise, diagnose and recover from errors.** Say in plain words what went wrong
   and what to do: "Not enough gold: 12 more needed", not "Error". Put the message near where the
   player is looking, in the warm note colour.
10. **Help and documentation.** The compendium is the game's help. A new mechanic gets a line
    there (and a row in `SHORTCUTS` if it has a key). Short in-place hints (e.g. `INFO_HINT`) beat a
    manual.

---

## 3. Laws of interaction

### 3.1 Fitts's law

The time to hit a target grows with its distance and shrinks with its size.

- Frequent targets are big and close to where the pointer already is. Buttons in this game are at
  least 118 × 64 (standard) or 76 × 36 (in-row action); do not go below **44 × 44 px** for anything
  clickable, and prefer 48 px or more for touch.
- The whole row is the target, not just its text: a trade row picks on a click anywhere on its
  panel. Do the same for list entries elsewhere.
- Screen edges and corners are "infinitely deep" for a mouse; the drawer handle on the right edge
  uses this. Put rarely used but always-needed controls there.
- Put the confirm button where the pointer ends after the last step (bottom of the flow), and keep
  dangerous buttons away from frequent ones.

### 3.2 Hick's law (Hick-Hyman)

The time to decide grows with the number and complexity of choices.

- Group long lists into categories (the merchant's folding sections), and show only the relevant
  ones.
- Highlight a sensible default or recommendation (the green "Better" badge).
- Split rare choices off into tabs or a second step (the forge's tabs).
- But do not hide frequent choices behind extra clicks: grouping should cut decision time, not add
  navigation time.

### 3.3 Miller's law and chunking

People hold about 4 ± 1 chunks in working memory (Miller's original 7 ± 2 is now considered high).
Break information into small labelled chunks; do not make the player compare numbers that are on
different screens. That is why the trade window puts the new item and the worn item side by side.

### 3.4 Jakob's law

Players spend most of their time in *other* games. They expect inventories, shops and pause menus to
work the way they usually do: Esc to pause or close, I for the inventory, hover for a tooltip, right
side for "what I have now" when comparing. Break a convention only for a clear gain.

### 3.5 Doherty threshold

Interaction feels fluid when the system answers in under about 400 ms, and instantaneous under
100 ms. Rebuilding a window must stay fast. If something takes longer, show progress.

### 3.6 Tesler's law (conservation of complexity)

Some complexity cannot be removed, only moved. Move it to the game, not the player: compute the
comparison, the upgrade badge, the affordability colour, so the player does not have to.

### 3.7 Goal-gradient and Zeigarnik effects

People speed up near a goal and remember unfinished tasks. Show progress towards goals (quest
counters, reputation bars), and keep open tasks visible in the quest log.

### 3.8 Peak-end rule

People judge an experience by its peak and its end. Make rewards (level up, boss defeated, lair won)
feel big, and end windows and sessions cleanly (a clear "what you lose" message on quit, a warm
welcome back).

### 3.9 Von Restorff (isolation) effect

The item that differs from the rest is remembered. Use this for the one thing that matters (a new
item, an upgrade, a warning), and only for that.

### 3.10 Serial position effect

People remember the first and last items of a list best. Put the most important entries at the
start and the end; put the main action last in a row of buttons.

---

## 4. Visual hierarchy and typography

The player should be able to tell in one glance what a window is (title), what is in it (sections),
and what to do (main action).

- **Size, weight, colour, position, space**: the five levers of hierarchy, roughly in that order of
  strength. Use as few as needed; two levers per level are plenty.
- **Type scale in this game** (keep to these steps; do not invent 17 or 19):

  | Role | Font | Size |
  |---|---|---|
  | Title screen headline | `TITLE_FONT` | 120 |
  | Window title | `TITLE_FONT` | 38 to 40 |
  | Section header, card title | `TITLE_FONT` | 20 to 22 |
  | Big status (gold line, HUD level) | `TEXT_FONT` | 22 to 26 |
  | Body text, buttons | `TEXT_FONT` | 18 to 20 |
  | Row names, secondary values | `TEXT_FONT` | 15 to 16 |
  | Fine print (version, counters) | `TEXT_FONT` | 14 to 15 |

- **Minimum size**: 14 px at the 1280 × 720 base resolution, and only for text the player can live
  without. Anything needed to make a decision is 16 px or more.
- `TITLE_FONT` (Cinzel Decorative) is for titles and headers only; never use it for running text,
  numbers or long names.
- **Line length** for wrapped text: about 45 to 75 characters. Set a `custom_minimum_size.x` and
  `autowrap_mode` on long labels (see `_wrapped` and `RETURN_TEXT_WIDTH`).
- **Numbers** that change or are compared should line up: right-align them in columns, or give them
  a fixed-width box, so a value going from 9 to 10 does not shift its neighbours.
- **Alignment**: centred windows centre their title and buttons; lists and cards are left-aligned
  inside. Do not mix centred and left-aligned text inside one block.

---

## 5. Layout stability

**This is a standing rule of the project.** Expanding or collapsing a section (an accordion, a
folding category, a tab, a details card) must not reshape, shrink or condense the rest of the window.
The player's eye and pointer are anchored to positions; moving things under them causes misclicks
and the feeling that the game is unstable.

### 5.1 Rules

1. **Fixed window frame.** A window keeps its width and height while it is open. Content that
   changes in size lives inside a region of fixed size (a `ScrollContainer` with a fixed
   `custom_minimum_size`), and scrolls when it is too big. Do not use
   `minf(content_height, MAX)` for a region that changes as the player folds sections: the
   window would shrink when a section folds and grow when it opens.
2. **Folding affects only what is below, and only inside the scroll region.** Headers above the
   folded section stay exactly where they were; the header that was clicked stays under the pointer.
3. **Reserve space for things that come and go.** A badge, an error note, a hint line or a details
   card that can appear gets its space reserved from the start (e.g. the info line under the
   inventory has `custom_minimum_size.y = 26`; the trade window reserves a line for the purchase
   note). Show placeholder text ("Point at an item to see its values") instead of collapsing to zero.
4. **Picking must not reflow the list.** Selecting a row should open the details in space that was
   already there (a side panel reserved from the start, or an overlay), not change the number of
   columns of the list the pointer is in.
5. **Text that changes keeps its box.** Buttons that toggle text ("Sound: on" / "Sound: off") get a
   fixed minimum width that fits the longest text in *every* language. Counters get room for their
   widest value.
6. **Rebuilds keep the state.** Windows here are rebuilt from scratch on every change. A rebuild must
   restore scroll position, folded sections, picked row and tab, so nothing jumps.
7. **Tabs share one content size.** Switching tabs (forge, shop buy/sell, compendium pages) must not
   resize the window; size the content area for the largest tab.
8. **The HUD does not jump.** HUD elements keep fixed anchors; a label that grows (gold 99 → 100)
   must not push its neighbours. The drawer keeps its place when a button's text changes (see the
   `minimum_size_changed` handler in `_setup_drawer`).

### 5.2 How to check

Open the window, note the position of the window border and of the header you will click, then
fold, unfold, pick, switch tab, buy, and sell. Nothing outside the changed region may move by even a
pixel. A headless test can assert this: read `get_global_rect()` of the panel and the headers before
and after, and compare.

---

## 6. Feedback and state

Every interactive element needs visibly distinct states:

| State | Requirement |
|---|---|
| Normal | Looks clickable: border, button shape, gold text. |
| Hover | Brighter border or background, and the pointing-hand cursor. |
| Pressed | Darker or inset; feedback within one frame. |
| Focused (keyboard/controller) | A clear outline, different from hover. |
| Selected/picked | Strongest highlight; stays while picked. |
| Disabled | Dimmed (about 40 to 50 % opacity or greyed), no hover reaction, and a reason nearby. |

Further rules:

- **Immediate feedback** for every input: a sound, a highlight, a number change. No silent clicks.
- **Say what changed.** After buying, the gold line updates and the bought item leaves or changes
  its row. After a failed action, a short note in the warm note colour says why.
- **Do not rely on hover alone.** Touch has no hover. Anything shown on hover must also be reachable
  by tap (the trade window shows cards on click; the inventory info line updates on tap too).
- **Messages that block the game** (pause windows) must be dismissable with Esc and a visible button.
- **Toasts and floating messages** stay long enough to read: about 1 second plus 60 ms per
  character, and they must not cover the HUD values they talk about.

---

## 7. Colour

- **Meaning, not decoration.** Each colour has one job. The game's semantic colours:

  | Meaning | Value | Used for |
  |---|---|---|
  | Gold / primary | `game.GOLD` (1.0, 0.82, 0.4) | Titles, button text, gold amounts |
  | Border | (0.85, 0.66, 0.32) at 0.55 to 0.8 alpha | Panels, buttons, rows |
  | Better / affordable / now | `GREEN` (0.4, 0.92, 0.4) | Upgrades, prices you can pay, "Now" |
  | Worse / not affordable | `RED` (1.0, 0.38, 0.32) | Downgrades, prices you cannot pay |
  | Information | `BLUE` (0.55 to 0.65, 0.75 to 0.85, 1.0) | Hints, gifts, info lines |
  | Reputation | `REPUTATION_COLOR` (0.78, 0.65, 1.0) | Everything about villagers' goodwill |
  | Note / warning | (1.0, 0.75, 0.5) | Notes after an action, quit warning |
  | Secondary | `GREY` (0.75, 0.72, 0.68) | Counts, empty states, fine print |
  | Lives | (1.0, 0.45, 0.42) | HP in the HUD |

- **Never colour alone.** About 8 % of men and 0.5 % of women have a colour vision deficiency; red
  and green are the most commonly confused. Pair every colour meaning with a second cue: an icon
  (up/down arrow), a sign (+3 / −2), a word ("Better"), or a position.
- **60-30-10**: about 60 % dark background, 30 % secondary surfaces and borders, 10 % accent (gold,
  green, red). Too much accent and nothing stands out.
- **Saturation means importance.** Calm, desaturated tones for structure; saturated colour only for
  what needs attention.

---

## 8. Accessibility

Based on WCAG 2.2 and the Game Accessibility Guidelines (gameaccessibilityguidelines.com).

### 8.1 Contrast

- Text: at least **4.5 : 1** against its background (WCAG AA); large text (24 px+, or 19 px+ bold)
  at least **3 : 1**. Aim for 7 : 1 on body text.
- Non-text elements the player needs (borders of buttons, icons, focus outlines, bar fills): at
  least **3 : 1** against what is next to them.
- Text over the 3D world: outline + shadow, always (`_make_label`). Check it over the brightest
  scene (day-time village, snow, fire).
- Semi-transparent text (e.g. alpha 0.4 for the version label) is only for text nobody needs.

### 8.2 Size and readability

- Base resolution is 1280 × 720 with `canvas_items` stretch, so sizes scale with the window. Test at
  1280 × 720 and at a small browser window; the game is also played in the browser and on touch
  screens.
- Minimum text 14 px, decisions 16 px+ (see section 4). Touch targets 44 × 44 px minimum.
- Avoid long all-caps text; Cinzel is already capital-like, so keep it to short titles.

### 8.3 Colour vision

- Every red/green pair has a second cue (icon, sign, word). Check screens with a deuteranopia and
  protanopia simulation.
- Do not encode rarity, danger or state by hue alone; add shape, icon or label.

### 8.4 Motor

- No action requires precise timing in a menu. Hold-to-confirm or double-click are never the only
  way.
- All windows can be used with the mouse alone and (goal, see Known gaps) with the keyboard alone.
- Key bindings listed in the compendium; avoid chords that need two hands on the mouse and keyboard
  at once for menu work.

### 8.5 Cognitive

- Pausing windows stop the world (`set_world_paused`), so the player can read without pressure. Keep
  it that way for every window that asks for a decision.
- Say one thing per message. Short sentences.
- Consistent placement: Close at the bottom centre, gold at the top centre, title first.

### 8.6 Hearing

- Every sound that carries information (danger, success, failure, an NPC speaking) has a visible
  counterpart: a comic bubble, a flash, a message.
- Separate volume controls for music and effects exist; new sound categories use them.

### 8.7 Photosensitivity

- Nothing flashes more than three times per second. Large bright flashes (lightning, explosions) are
  short and not repeated rapidly.

---

## 9. Writing UI text

- **Language rule:** code comments, docs and new strings for review are written in English (project
  instruction). In-game strings in the code are currently written in German and translated through
  `Lang` (`scripts/lang.gd`): every new player-facing string needs an entry in `Lang.EN`, and
  composed text goes through `Lang.t()`. Check both languages fit the space; German words are often
  30 % longer.
- **Verbs on buttons:** "Buy", "Sell", "Mend", "Close", not "OK" or "Yes". The button says what
  happens.
- **Sentence case** for messages and descriptions; title case only where the game already uses it
  for names.
- **Plain words** from the game's world. No internal ids, no numbers without units.
- **Be specific about errors and costs:** "Costs 15 gold, you have 9."
- **Short.** Cut every word the player does not need to act.
- **Same name for the same thing** everywhere (one word for "gold", one for "lives", one for each
  item).

---

## 10. Game UI specifics

### 10.1 The four kinds of game UI

- **Diegetic**: exists in the world and the hero could see it (the bounty board, the shrine, the
  merchant's cart). Most immersive; use it when the information fits the world.
- **Spatial**: in the 3D scene but not part of the world (prompts over objects, ticks on searched
  crates, quest marks over heads). Good for "this thing here".
- **Meta**: about the hero's state, not in the world (screen effects when hurt). Use sparingly.
- **Non-diegetic**: classic overlays (HUD, windows, the drawer). Clearest; most of the game's UI.

Choose the most immersive kind that is still clear.

### 10.2 HUD

- Show only what the player needs while playing: lives, run stamina, key, knives, gold, level.
  Everything else lives in windows.
- Fixed positions; the HUD never moves. Anchor to corners and edges with margins (24 px here).
- Group by meaning (proximity): survival values together, resources together.
- Keep the centre of the screen free; that is where the action is.
- Transient prompts ("Press E to pick up") appear near the object or at a fixed prompt spot, never
  over the hero.
- Boss bars go top centre, wide, with the boss's name.

### 10.3 Pause windows and menus

- One window at a time, centred (`Menus` uses a `CenterContainer`). A window pauses the world.
- Structure, top to bottom: title, status line (gold), tabs if any, content, notes, main action,
  Close.
- Esc closes the window (or goes back one step). Close is always at the same place.
- Opening a window from the drawer pushes the drawer away, so the window is not covered.
- Remember state per window where it helps (last tab, folded sections) but reset what would confuse
  (a picked row from an earlier visit).

### 10.4 Inventories

- Grid of equal cells; icons in a fixed size; item counts in a corner of the cell.
- Hover or tap shows the stats; the info line has reserved space and a hint when empty.
- Equipped items are visibly marked and shown in their slots.
- Actions (equip, set down, drop) are near the selection and disabled with a reason when not
  possible.
- Destructive actions (throw away) need confirmation or undo.

### 10.5 Shops and trade windows (`TradeWindow`)

The merchant window is the reference pattern for every list-with-details screen.

- Gold at the top centre, always visible, updated at once.
- Categories fold; each header shows icon, title, count and a chevron (down = folded, up = open).
- Rows: icon, name (ellipsis if too long), price line, action button. The whole row is clickable.
- Price colour shows affordability; the button is disabled when unaffordable.
- Picking a row shows two cards side by side: what it is, and what the hero wears in that slot now,
  with green/red differences and a "Better" badge with an up arrow.
- Hovering another row while cards are open previews that row; leaving returns to the picked one.
- After buying, the selection moves to the next row with the same item if there is one
  (`_keep_selection`), so repeat purchases need no re-picking.
- New merchants use `TradeWindow`; do not build a second shop layout.

### 10.6 Journal, compendium, quest log

- Book-like two-column layout (`_book_column`, `BOOK_COLUMN` = 470 px); left page lists, right page
  details.
- Pages as tabs at the top; all pages share one size (section 5).
- Every control appears in `SHORTCUTS`; every learned mechanic appears in "Knowledge".
- Quests show: who gave them, what is needed, progress (3 / 5), reward. Finished quests move down
  or out.

### 10.7 Dialogue and comic bubbles

- Bubbles sit above the speaker with a tail pointing at them (uniform connectedness).
- They must not cover the hero or another bubble; stack or offset them.
- Short text, readable size, enough time to read (section 6).
- Sound words ("Klonk!", "Zack!") are a style element; keep them short and consistent with the sound.

### 10.8 Onboarding

- Teach by doing: one new mechanic at a time, in a safe place, with a short prompt.
- Never show a wall of text before play. Put the details in the compendium.
- Highlight a new button or window the first time it matters.

### 10.9 Saving and loading

- Say when the game saves (it saves on entering the refuge and in its bed) and what is lost on quit.
- The load list shows name, level, play time and date per slot; the current game is marked.
- Deleting a save takes two clicks with a visible "Really delete?" state (already the case).

---

## 11. Input: mouse, touch, keyboard, controller

- **Every action has at least two ways in** (key and click or tap), as the drawer and the
  shortcuts already provide.
- **Mouse:** hover feedback, pointing-hand cursor on clickable elements
  (`mouse_default_cursor_shape = CURSOR_POINTING_HAND`), the wheel scrolls lists.
- **Touch (browser version):** no hover; targets 44 px+; no right click or double click as the only
  way; enough space between targets (8 px+).
- **Keyboard:** Esc closes, Enter/Space activates, Tab or arrow keys move focus in windows. The
  standard actions `ui_accept`, `ui_cancel`, `ui_up` / `ui_down` / `ui_left` / `ui_right` should
  work in every window (see Known gaps).
- **Controller:** if added, everything that works with the keyboard must work with the pad; focus
  moves predictably in a grid (set `focus_neighbor_*` where Godot guesses wrong); the first useful
  element gets focus when a window opens (`grab_focus()`); show the pad's button glyphs instead of
  key names.
- **Focus order** follows the visual order: left to right, top to bottom.
- **Remapping**: if keys are ever remappable, the compendium shows the current binding, not the
  default.

---

## 12. Motion and sound

- **Purpose:** motion explains change (where did that come from, where did it go). No motion for
  decoration in menus.
- **Duration:** 100 to 300 ms for UI transitions; ease-out for things that arrive, ease-in for
  things that leave. The drawer slides; windows may appear instantly.
- **Never animate layout** in a way that moves things under the pointer (section 5).
- **Sound:** every button press has a soft click; success and failure sound different; sounds are
  short and not tiring when repeated. Respect the effects volume slider.
- **Reduced motion:** big camera shakes and screen flashes should be toned down or optional.

---

# Part 2: The Escape! house style

Use these helpers and values; do not re-create them.

| What | Where | Notes |
|---|---|---|
| Window frame | `Menus.panel_style(border)` | Dark background (0.04, 0.03, 0.08, 0.9), 2 px border, radius 18, margin 26. |
| Window host | `Menus.setup` | `CenterContainer` over the HUD, one `PanelContainer`, one `VBoxContainer` (`separation` 10, 6 in the inventory). |
| Opening/closing | `Menus.open(kind)` / `Menus.close()` | Pauses and resumes the world, resets per-visit state. |
| Labels | `game._make_label(font, size, color)` | Adds outline and shadow; mouse ignored. |
| Buttons | `game._make_button(text, action)` | 118 × 64 default, `TEXT_FONT` 20, gold text, radius 14. Close buttons 180 × 52; dialog buttons 220 × 60. |
| Merchant / list-with-details | `TradeWindow` (`scripts/trade_window.gd`) | Sections, rows 350 × 60, cards 290 wide, list height 400. |
| Book pages | `Menus._book_column`, `BOOK_COLUMN` = 470 | Compendium, recipes, quest log, reputation. |
| Item pictures | `ItemIcon.make(id_or_kind, size, flat)` | Use `kind:*` icons (coin, chev_up, chev_down, up, …) for UI symbols. |
| Fonts | `game.TITLE_FONT` (Cinzel Decorative Black), `game.TEXT_FONT` (Cinzel Bold) | Titles vs everything else. |
| Colours | `game.GOLD`, `TradeWindow.GREEN/RED/GREY/BLUE/ORANGE`, `Menus.BLUE`, `Menus.REPUTATION_COLOR` | See section 7. |
| Translations | `Lang.t()`, `Lang.EN` | Every new player-facing string. |
| Pull-out menu | `game._setup_drawer()` | Right edge, Tab toggles; window buttons push it away. |
| Shortcut list | `Menus.SHORTCUTS` | Add every new key. |

Spacing scale (keep to these steps): **4, 6, 8, 10, 12, 14, 24, 26, 28**. Within a row 8 to 10;
between rows 6; between groups 12 to 14; window margin 26; HUD edge margin 24.

Corner radius: 18 for windows, 14 for buttons and the drawer, 8 for rows, cards and headers.

### Tests

UI behaviour is tested headlessly (see `tests/merchant_window.gd`, `tests/hud_drawer.gd`). A new
window or a change to the layout of one gets a test that opens it, interacts with it, and checks the
result, including layout stability where it matters (section 5.2). Run with
`godot --headless -s tests/<name>.gd`; with `SHOTS=<folder>` and a display some tests also save
screenshots, which help in the pull request.

---

# Part 3: Checklist before a UI change is done

Copy this into the pull request description for UI work and tick what applies.

**Structure and Gestalt**
- [ ] Related things are closer to each other than to unrelated things (proximity).
- [ ] Same function looks the same; different function looks different (similarity).
- [ ] Edges and columns line up; cards in a row start on one line (continuity, alignment).
- [ ] One focal point per window.

**Layout stability**
- [ ] Folding, unfolding, picking, switching tabs, buying and selling do not move or resize anything
      outside the changed region.
- [ ] Space for notes, badges, hints and details is reserved.
- [ ] Changing text (counters, toggles, both languages) does not resize its box.
- [ ] A rebuild keeps scroll position, folded sections, tab and selection.

**Feedback and control**
- [ ] Every interactive element has normal, hover, pressed, disabled (and focus) states.
- [ ] Every action gives visible feedback at once; failures say why.
- [ ] Esc and a visible button close the window.
- [ ] Hard-to-undo actions ask first.

**Accessibility**
- [ ] Text contrast ≥ 4.5 : 1 (3 : 1 for large text); needed UI parts ≥ 3 : 1.
- [ ] No text the player needs is smaller than 16 px; nothing below 14 px.
- [ ] No meaning by colour alone (icon, sign or word as well).
- [ ] Click targets ≥ 44 × 44 px; nothing depends on hover only.
- [ ] Works at 1280 × 720 and in a small browser window.

**Text and consistency**
- [ ] New strings have English in `Lang.EN` and fit in both languages.
- [ ] New keys are in `Menus.SHORTCUTS` and the README controls table.
- [ ] Existing helpers used (`panel_style`, `_make_label`, `_make_button`, `TradeWindow`,
      `ItemIcon`); no one-off styles.

**Tests**
- [ ] A headless test covers the new or changed behaviour.
- [ ] Screenshots before and after are attached for visible changes.

---

# Known gaps in the current UI

An honest list of where the game today does not yet meet this guide, so they are not copied into
new work and can be fixed over time. Fix them when touching that code, in their own commit.

Items 1 and 2 are fixed by PR #143 (fixed two-column frame, cards always in place); remove them
from this list once it is merged, and do not fix them again.

1. **Trade window list height follows its content.** `TradeWindow.build` sets the scroll height to
   `minf(height, LIST_HEIGHT)`, so folding categories shrinks the window and unfolding grows it.
   Rule 5.1.1 says the region should keep a fixed height while the window is open.
2. **Picking a trade row changes the list from two columns to one.** The rows move under the
   pointer. Rule 5.1.4 prefers reserving the card space (or showing the cards over the right column)
   so the list keeps its columns.
3. **No hover state on standard buttons.** `game._make_button` uses the same style for "normal" and
   "hover". Section 6 asks for a visible hover state.
4. **No keyboard or controller focus in windows.** Buttons and sliders set
   `focus_mode = FOCUS_NONE`. Section 11 asks for focus navigation with a visible focus outline.
5. **Small text in places.** Counts, fine print and the version label use 14 to 15 px, some at low
   alpha; check that nothing needed for a decision is among them.
6. **Buttons fire on `button_down`.** Activating on press, not release, means a click cannot be
   cancelled by dragging off the button. Fine for game actions in the drawer; for window buttons
   that change things (Buy, Sell, Delete) prefer `pressed`.

---

## Sources and further reading

- Max Wertheimer, Kurt Koffka, Wolfgang Köhler: the Gestalt principles of perception; Stephen
  Palmer and Irvin Rock: common region and uniform connectedness.
- Jakob Nielsen: *10 Usability Heuristics for User Interface Design* (nngroup.com).
- Paul Fitts (1954), W. E. Hick (1952), George Miller (1956), Nelson Cowan (2001) on working memory.
- Jon Yablonski: *Laws of UX* (lawsofux.com).
- W3C: *Web Content Accessibility Guidelines (WCAG) 2.2*.
- *Game Accessibility Guidelines* (gameaccessibilityguidelines.com) and Xbox Accessibility
  Guidelines.
- Celia Hodent: *The Gamer's Brain*; Fagerholt and Lorentzon: *Beyond the HUD* (diegetic,
  spatial, meta, non-diegetic UI).
- Godot documentation: *GUI skinning*, *Size and anchors*, *Containers*, *Keyboard/controller
  navigation and focus*.
