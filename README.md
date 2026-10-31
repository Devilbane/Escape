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
| Kompendium | H | Knopf „Kompendium“ |
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

Finde den **Schlüssel**, öffne die **Tür** und steige die **Treppe** hinauf in die nächste Ebene. Oben angekommen bekommst du 5 Leben zurück.
Fässer, Kisten, Tische, Truhen und Wandregale lassen sich durchsuchen: Darin steckt Gold,
Wurfmesser, ein Heiltrank oder auch gar nichts. Durchsuchtes bekommt ein Häkchen.
Skelette greifen mit Klingen oder Armbrüsten an. Über **Stacheln** kannst du springen. Skelette gehen Stachelfallen aus dem Weg, warten, bis sie unten sind, und verletzen sich selbst daran.
An einem **Schrein** wählst du einmal eine Gabe: +1 Leben, +1 Kampfkraft oder +7% Tempo.
Die Gaben bleiben bis zum Ende des Spiels.

Manchmal findest du **Ausrüstung**: Helme und Hüte (Knochenhelm, Zauberhut, Ritterhelm, Bärenkappe) sitzen sichtbar auf dem Kopf, Schwert und Axt geben Kampfkraft, Schilde geben Leben,
Amulette geben Tempo, Kraft oder Leben. Im **Inventar** (Taste I) legst du sie an oder wirfst sie weg.
Harte Rüstung (Ritterhelm, Wappenschild, Kettenhemd, Plattenpanzer) hat **Härtung**: Sie zieht von jedem
Treffer einen festen Wert ab (mindestens 1 Schaden bleibt). Jeder Treffer nutzt sie mit 5 % Chance um einen
Punkt **Haltbarkeit** ab; ist die verbraucht, zerbricht das Teil.
**Schilde** blocken: Rundschild 20 %, Wappenschild 25 %, Stachelschild 30 %. Ein geblockter Schlag oder
Schuss macht gar keinen Schaden (Stacheln von unten lassen sich nicht blocken). Auch Schilde haben Haltbarkeit:
Jeder Block nutzt sie mit 20 % Chance ab, jeder Treffer wie bei Rüstung mit 5 %.
Jeder Gegenstand hat ein **Gewicht**. Alles, was du trägst, angelegt oder in der Tasche, macht dich langsamer:
1 % Tempo pro kg, höchstens 35 %. Schmuck wiegt fast nichts, ein Plattenpanzer 8 kg. Skelette tragen ihre
Ausrüstung genauso.
Nach jeweils 4 Ebenen kommst du in einen **Saferoom** ohne Gegner. Dort gibt es einen **Brunnen**,
der dein Leben auffüllt und Gift und Flüche heilt, eine Lagertruhe, einen Händler, der für Gold kauft und verkauft, und ein Bett. Beim Betreten der Zuflucht wird automatisch gespeichert; im Bett wird noch einmal gespeichert und du loggst aus. Fällt der Held später, bleibt der Spielstand erhalten: Ein Klick auf dem Gefallen-Bildschirm setzt das Spiel ab der Zuflucht fort, N beginnt ein neues.
Beim nächsten Start geht es mit „Weiterspielen“ dort weiter. Der Spielstand liegt im Browser.
Jede Ebene hat einen **Geheimraum**. Eine der Fackeln in seiner Nähe ist ein Hebel, in jedem Lauf
eine andere. Läufst du zum ersten Mal an ihr vorbei, entdeckst du ihn mit etwas Glück (W100), und
2,5 Sekunden später sinkt die Wand. Je reicher der Raum, desto kleiner die Chance:
Gewöhnlich 55 %, Ungewöhnlich 40 %, Selten 28 %, Episch 18 %, Gottgeboren 10 %. Jeder gefundene
Geheimraum erhöht die Chance um 1. Der Hebel würfelt nur einmal. Hast du bis Ebene 3 noch keinen
gefunden, ist der dortige sicher; danach vergehen nie mehr als 4 Ebenen ohne Geheimraum.
Du siehst nur, was in deiner Sichtlinie liegt und Licht hat: eine brennende Fackel in der Nähe oder
deine eigene Laterne. Dunkle Ecken bleiben schwarz, Skelette darin hörst du nur an ihren Schritten.
Bereits erkundete Bereiche bleiben grau sichtbar. Manche Fackeln brennen, manche nicht: Lauf gegen
die Wand an einer Fackel, um sie anzuzünden oder zu löschen.

**Schleichen** (C oder Doppelklick): 60 % langsamer, lautlos, halb durchsichtig, und die Laterne ist
abgeblendet. Skelette sehen nach vorn (120°), aber nur, was im Licht steht. Hören können sie dich
rundherum, außer du schleichst oder stehst still. Ganz nah bemerken sie dich immer. Verlieren sie
dich aus den Augen, suchen sie noch ein paar Sekunden und gehen dann zurück auf ihren Posten.
Hat dich schon ein Skelett entdeckt (rotes **!**), kannst du erst wieder schleichen, wenn es aufgibt.
Ein „tapp“ im Dunkeln ist ein Skelett, das du nicht siehst, aber hörst.
Jede Art hat außerdem eine eigene Stimme, die du in der Nähe hörst: Krieger knurren, Schützen
zischen, Magier murmeln, Wichte kichern, Kolosse grollen und Wächter klirren mit der Rüstung.
Je näher ein Skelett kommt, desto lauter, öfter und drängender hörst du es (und seine Schritte).
Im Dunkeln zeigt ein Wort, woher es kam; ganz nah wird es zum Ausruf.

**Stich in den Rücken:** Ein Schlag von hinten auf ein Skelett, das dich noch nicht bemerkt hat,
fällt es sofort. Schleichst du dich von hinten an, bemerkt es dich auch ganz nah nicht. In der Gruft
(Ebene 4) trägt ein gepanzerter **Wächter** den Schlüssel: Klingen und Messer prallen an ihm ab,
nur ein Stich in den Rücken bezwingt ihn, mit einem Schlag. Er steht still in seinem Saal neben der
Feuerschale, die nur die Mitte erhellt; der Rand bleibt dunkel. Im Gang davor erfährst du, wie es
geht: Schleichen (C), im Schatten am Rand um ihn herum, von hinten zuschlagen. Ein Saal mit Wächter
hat keine Wandfackeln. Ein Wächter in einem Level ohne `K` lässt beim Tod den Schlüssel fallen.

Durchsuchte Fässer, Kisten, Tische und Truhen erkennst du an Münzen und einem zerrissenen Blatt davor.

Das **Kompendium** (Taste H) zeigt alle Tasten und Mausbefehle und sammelt jeden Hinweis und jede
Erklärung, die du bisher bekommen hast: die Einleitung jeder Ebene, die Tipps zum Schleichen und zum
Wächter, den Geheimhebel. Es wird mit dem Spielstand gespeichert.

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
| `W`     | Wächter          | `f`     | Feuerschale      |

Eine Zeile `safe: ja` macht ein Level zum Saferoom. Eine Zeile wie `secret: episch` legt fest,
wie reich der Geheimraum hinter der Wand `?` ist: `normal`, `ungewoehnlich`, `selten`, `episch`
oder `gottgeboren`.

Der Ausgang `E` braucht eine Wand im Norden (oben) und wird von Süden betreten.
Eine Tür `D` steht in einem ein Feld breiten Durchgang.

## Technik

- Engine: [Godot 4.5](https://godotengine.org) mit dem Compatibility-Renderer, damit es im Browser läuft
- Grafik: KayKit Dungeon Remastered, Adventurers und Skeletons von Kay Lousberg (CC0)
- Böden, Wände, Säulen und Möbel: 3D Modular Dungeon Kit von Omie's Assets (CC0)
- Geräusche: selbst erzeugt mit `tools/make_sounds.py`, Schritte und Tür: Aufnahmen von Fantozzi, „Footsteps Leather, Cloth, Armor“ und qubodup, Kreaturen, Skelettstimmen und Ketten von rubberduck, Armbrustschüsse aus „Medieval sound effects - Weapon Textures“ (CC0, siehe `assets/sounds/CREDITS.txt`)
- Schrift: Cinzel und Cinzel Decorative (SIL Open Font License)
- Comic-Schrift der Kampfblasen: Bangers von Vernon Adams (SIL Open Font License)
- Jeder Push auf `main` spielt alle Levels automatisch durch und veröffentlicht die Browser-Version über GitHub Pages

## Lizenz

© 2026 devilbane. Alle Rechte vorbehalten, siehe [LICENSE](LICENSE). Grafiken und Schriften von anderen stehen unter ihren eigenen Lizenzen (siehe oben).
