# Escape!

Ein Fantasy-Spiel: Entkomme Ebene für Ebene aus einem finsteren Verlies.
Einfache Steuerung, schöne 2.5D-Grafik, viele Levels.

**Spielen im Browser:** https://devilbane.github.io/Escape/

## Steuerung

| Aktion | Tastatur | Maus / Touch |
|---|---|---|
| Laufen | WASD oder Pfeiltasten | auf den Boden klicken/tippen |
| Springen | Leertaste | Rechtsklick beim Laufen (linke Taste gehalten), Knopf „Springen“ |
| Nahkampf | gegen den Gegner laufen oder F | Gegner anklicken, Knopf „Schlagen“ |
| Wurfmesser | R | Rechtsklick im Stehen, Knopf „Werfen“ |

Ein Sprung aus dem Lauf behält den Schwung: je schneller du bist, desto weiter fliegst du.
| Inventar | I | Knopf „Inventar“ |
| Spielstand laden | L | Knopf „Laden“ (auch auf dem Startbildschirm) |
| Spiel beenden | Esc | Knopf „Beenden“ oben rechts |
| Ton an/aus | M | Knopf „Ton“ oben rechts |
| Zoom | + und − | Mausrad (nah dran kippt die Kamera, du siehst das Gesicht) |

Wer gegen ein Skelett läuft, kämpft automatisch: Solange du daneben stehst, schlägst du weiter zu.
Gehst du auf Abstand, wirfst du Messer auf das zuletzt angegriffene Skelett, solange du es siehst
und Messer hast.
| Untersuchen | dagegenlaufen | Gegenstand anklicken |

Mit `?level=3` hinter der Adresse startet das Spiel direkt in Ebene 3.

## Ziel jeder Ebene

Finde den **Schlüssel**, öffne die **Tür** und steige die **Treppe** hinauf in die nächste Ebene.
Fässer, Kisten, Tische, Truhen und Wandregale lassen sich durchsuchen: Darin steckt Gold,
Wurfmesser, ein Heiltrank oder auch gar nichts. Durchsuchtes bekommt ein Häkchen.
Skelette greifen mit Klingen oder Armbrüsten an. Über **Stacheln** kannst du springen.
An einem **Schrein** wählst du einmal eine Gabe: +1 Leben, +1 Kampfkraft oder +7% Tempo.
Die Gaben bleiben bis zum Ende des Spiels.

Manchmal findest du **Ausrüstung**: Helme und Hüte (Knochenhelm, Zauberhut, Ritterhelm, Bärenkappe) sitzen sichtbar auf dem Kopf, Schwert und Axt geben Kampfkraft, Schilde geben Leben,
Amulette geben Tempo, Kraft oder Leben. Im **Inventar** (Taste I) legst du sie an oder wirfst sie weg.
Nach jeweils 4 Ebenen kommst du in einen **Saferoom** ohne Gegner. Dort gibt es einen **Brunnen**,
der dein Leben auffüllt und Gift und Flüche heilt, eine Lagertruhe, einen Händler, der für Gold kauft und verkauft, und ein Bett. Im Bett wird gespeichert und du loggst aus.
Beim nächsten Start geht es mit „Weiterspielen“ dort weiter. Der Spielstand liegt im Browser.
Jede Ebene hat einen **Geheimraum**. Eine der Fackeln in seiner Nähe ist ein Hebel, in jedem Lauf
eine andere. Läufst du zum ersten Mal an ihr vorbei, entdeckst du ihn mit etwas Glück (W100), und
2,5 Sekunden später sinkt die Wand. Je reicher der Raum, desto kleiner die Chance:
Gewöhnlich 30 %, Ungewöhnlich 22 %, Selten 15 %, Episch 9 %, Gottgeboren 4 %. Jeder gefundene
Geheimraum erhöht die Chance um 1. Der Hebel würfelt nur einmal.
Du siehst nur, was in deiner Sichtlinie liegt und Licht hat: eine brennende Fackel in der Nähe oder
deine eigene Laterne. Dunkle Ecken bleiben schwarz, Skelette darin hörst du nur an ihren Schritten.
Bereits erkundete Bereiche bleiben grau sichtbar. Manche Fackeln brennen, manche nicht: Lauf gegen
die Wand an einer Fackel, um sie anzuzünden oder zu löschen.

**Schleichen** (C oder Doppelklick): 60 % langsamer, lautlos, halb durchsichtig, und die Laterne ist
abgeblendet. Skelette sehen nach vorn (120°), aber nur, was im Licht steht. Hören können sie dich
rundherum, außer du schleichst oder stehst still. Ganz nah bemerken sie dich immer. Verlieren sie
dich aus den Augen, suchen sie noch ein paar Sekunden und gehen dann zurück auf ihren Posten.

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
| `A`     | Skelett-Schütze  | `H`     | Schrein          |
| `B`     | Bett (speichern) | `L`     | Lagertruhe       |
| `V`     | Händler          | `?`     | Geheimwand       |

Eine Zeile `safe: ja` macht ein Level zum Saferoom. Eine Zeile wie `secret: episch` legt fest,
wie reich der Geheimraum hinter der Wand `?` ist: `normal`, `ungewoehnlich`, `selten`, `episch`
oder `gottgeboren`.

Der Ausgang `E` braucht eine Wand im Norden (oben) und wird von Süden betreten.
Eine Tür `D` steht in einem ein Feld breiten Durchgang.

## Technik

- Engine: [Godot 4.5](https://godotengine.org) mit dem Compatibility-Renderer, damit es im Browser läuft
- Grafik: KayKit Dungeon Remastered, Adventurers und Skeletons von Kay Lousberg (CC0)
- Böden, Wände, Säulen und Möbel: 3D Modular Dungeon Kit von Omie's Assets (CC0)
- Geräusche: selbst erzeugt mit `tools/make_sounds.py`
- Schrift: Cinzel und Cinzel Decorative (SIL Open Font License)
- Comic-Schrift der Kampfblasen: Bangers von Vernon Adams (SIL Open Font License)
- Jeder Push auf `main` spielt alle Levels automatisch durch und veröffentlicht die Browser-Version über GitHub Pages

## Lizenz

© 2026 devilbane. Alle Rechte vorbehalten, siehe [LICENSE](LICENSE). Grafiken und Schriften von anderen stehen unter ihren eigenen Lizenzen (siehe oben).
