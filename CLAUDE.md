# Escape!: notes for Claude

A Godot 4.5 game (GDScript). Entry scene `scenes/main.tscn`, main logic in `scripts/game.gd`,
windows in `scripts/menus.gd`, the merchant window in `scripts/trade_window.gd`. Headless tests live
in `tests/` and run with `godot --headless -s tests/<name>.gd`.

## Before any UI work

Read the **`ux-ui` skill** at [`.claude/skills/ux-ui/SKILL.md`](.claude/skills/ux-ui/SKILL.md)
before designing, building, reviewing or changing anything the player sees or touches (windows,
HUD, pull-out menu, inventory, shops, compendium, buttons, labels, icons). Follow its rules and the
house style in its Part 2, and tick its checklist (Part 3) in the pull request.

The most important standing rule: expanding or collapsing a section (accordion, folding category,
tab, details card) must not reshape or condense the rest of the window.

## Language

Write messages, code comments, PR descriptions and docs in English. Player-facing strings are
written in German in the code and translated through `Lang` (`scripts/lang.gd`): every new string
needs an English entry in `Lang.EN`.
