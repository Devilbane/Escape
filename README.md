# Escape!

Ein Fantasy-Spiel: Entkomme Ebene für Ebene aus einem finsteren Verlies.
Einfache Steuerung, schöne 2.5D-Grafik, viele Levels.

**Spielen im Browser:** https://devilbane.github.io/Escape/

## Steuerung

| Aktion | Tastatur | Maus / Touch |
|---|---|---|
| Laufen | WASD oder Pfeiltasten | auf den Boden klicken/tippen |
| Springen | Leertaste | Knopf „Springen“ |
| Nahkampf | F | Gegner anklicken, Knopf „Schlagen“ |
| Wurfmesser | R | Rechtsklick, Knopf „Werfen“ |
| Untersuchen | E | Gegenstand anklicken, Knopf „Suchen“ |

Mit `?level=3` hinter der Adresse startet das Spiel direkt in Ebene 3.

## Ziel jeder Ebene

Finde den **Schlüssel**, öffne die **Tür** und steige die **Treppe** hinauf in die nächste Ebene.
Fässer, Kisten, Tische, Truhen und Wandregale lassen sich durchsuchen: Darin steckt Gold,
Wurfmesser, ein Heiltrank oder auch gar nichts. Durchsuchtes bekommt ein Häkchen.
Skelette greifen mit Klingen oder Armbrüsten an. Über **Stacheln** kannst du springen.
Du siehst nur, was in deiner Sichtlinie liegt. Bereits erkundete Bereiche bleiben grau sichtbar.

## Neue Levels bauen

Jedes Level ist eine einfache Textdatei im Ordner `levels/`. Die Levels werden
nach Dateinamen sortiert gespielt. Ein Zeichen steht für ein Feld:

| Zeichen | Bedeutung        | Zeichen | Bedeutung        |
|---------|------------------|---------|------------------|
| `#`     | Wand             | `.`     | Boden            |
| `,`     | Erdboden         | `P`     | Startpunkt       |
| `E`     | Ausgang (Treppe) | `K`     | Schlüssel        |
| `D`     | verschlossene Tür| `S`     | Stachelfalle     |
| `c`     | Goldmünze        | `C`     | Schatztruhe      |
| `b`     | Fässer           | `x`     | Kisten           |
| `o`     | Säule            | `t`     | Tisch            |
| `k`     | kleine Truhe     | `M`     | Skelett-Krieger  |
| `A`     | Skelett-Schütze  |         |                  |

Der Ausgang `E` braucht eine Wand im Norden (oben) und wird von Süden betreten.
Eine Tür `D` steht in einem ein Feld breiten Durchgang.

## Technik

- Engine: [Godot 4.5](https://godotengine.org) mit dem Compatibility-Renderer, damit es im Browser läuft
- Grafik: KayKit Dungeon Remastered, Adventurers und Skeletons von Kay Lousberg (CC0)
- Schrift: Cinzel und Cinzel Decorative (SIL Open Font License)
- Jeder Push auf `main` spielt alle Levels automatisch durch und veröffentlicht die Browser-Version über GitHub Pages
