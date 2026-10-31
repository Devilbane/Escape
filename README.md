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
An einem **Schrein** wählst du einmal eine Gabe: +1 Leben, +1 Kampfkraft oder +7% Tempo (ein weiser Held auch +1 Härtung).
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

**Dein Held wächst durch Tun.** Er hat sieben **Eigenschaften**, die ganz langsam steigen, und zwar nur
durch das, was er tut. Ein ganzer Lauf durch das Verlies bringt etwa einen Punkt, und jeder weitere Punkt
braucht ein Viertel mehr Übung als der davor:

| Eigenschaft | Wert | Wird geübt durch | Wirkung |
|---|---|---|---|
| Stärke | 10 bis 30 | Treffer landen, Gegner fällen, Schläge blocken, schwere Lasten tragen | +1 Kampfkraft je Punkt, alles Getragene wiegt weniger |
| Konstitution | 10 bis 30 | Leben verlieren (Treffer, Stacheln, Gift) | +1 Leben je Punkt |
| Tempo | 100 % bis 150 %, in 5er-Schritten | Laufen und Springen | schneller laufen |
| Geschick | 10 bis 30 | Springen, Messer werfen, Stachelfallen | Sprünge aus dem Lauf 2 % weiter je Punkt, 4 % je Punkt, hochschießenden Stacheln auszuweichen |
| Intuition | 10 bis 30 | Durchsuchen, an Geheimhebeln vorbeikommen, Geheimräume finden | +2 % je Punkt, einen Geheimhebel zu bemerken |
| Weisheit | 10 bis 30 | Erlebtes, egal wie es ausgeht: Ebenen schaffen, Schlüssel und Geheimräume finden, am Schrein wählen, jeder beendete Lauf, auch ein tödlicher | alle anderen Eigenschaften und Fertigkeiten lernen 5 % schneller je Punkt; ab Weisheit 12 bietet jeder Schrein eine vierte Gabe (+1 Härtung) |
| Intelligenz | 10 bis 30 | Neues verstehen (jeder neue Eintrag im Kompendium), Skelett-Magier besiegen | Dinge des Geistes brauchen sie: der Zauberhut ab Intelligenz 11, später Schriftrollen, Zauberstäbe und Fertigkeiten des Geistes |

Dazu kommen **Fertigkeiten** (Stufe 0 bis 10). Sie wachsen viel schneller, aber nur mit der Ausrüstung,
die sie braucht: **Klingen** mit Dolch oder Schwert, **Äxte** mit der Axt, **Blocken** mit einem Schild,
**Rüstung tragen** mit harter Rüstung; **Messerwurf** und **Schleichen** gehen immer.
Klingen, Äxte und Messerwurf geben je Stufe 5 % Chance auf einen Wuchttreffer (+1 Schaden), Blocken +2 %
Blocken, Rüstung tragen lässt harte Rüstung 6 % leichter wiegen, Schleichen macht 3 % schneller.
Manche Gegenstände geben selbst Stufen dazu (Schattenumhang +2 Schleichen, Wappenschild +1 Blocken,
Kettenhemd +1 Rüstung tragen, Silberarmreif +1 Messerwurf). Alles steht im Inventar, mit dem Fortschritt
zum nächsten Punkt. Was dein Held gelernt hat, bleibt mit seinem Namen gespeichert, auch über neue Spiele hinweg.

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

## Beyond the gate: freedom

Whoever climbs the last stairs steps out of a **crypt** onto a graveyard under the evening sky. That counts
as an escape: it goes into the ranking and the game is saved. But the game goes on. A long path leads
through the autumn forest, past a pond and a woodcutter, to the village of **Lindenhain**. Run into anyone
to hear what they have to say. The **village elder** gives you the empty house with the tiled roof, and a
golden light shows the door. Inside are a **bed** (save and log out) and a **chest** (your storage). When you
play on, you wake up in your own house.

In the middle of the village lies the paved **market square** with a fountain that heals, benches and
lanterns. Around it stand the **smithy**, the **temple**, the **office of the crown**, the **post office**, the
**adventurers' guild**, the **general store** (Mira, the shopkeeper, buys and sells), the **tavern** and the
**bank**. Fifteen villagers go about their day: the smith hammers, the farmer harvests pumpkins, the guard
makes the rounds, the postmaster carries letters, the priestess tends the temple. Every so often the
**herald** rings the bell and calls out the news, and the whole village gathers on the square to listen.

At the **bank** the banker keeps your gold safe (deposit and withdraw) and rents you a **vault** for
50 gold. The vaults are in the **cellar**: small cells behind iron bars, each with its holder's name, their
gold and their treasures. You can walk down and look at what every other hero keeps there; your own cell
opens for you. Until there is a server, the bank keeps one account per hero name on this computer.

The villagers follow a fixed daily routine (small scripts, no AI on the network): that costs no noticeable
computing time and nothing to run.

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

A line `outdoor: ja` turns a level into the world under the open sky (see `levels/11_die_freiheit.txt`).
It has its own characters: `#` forest, `.` meadow, `,` path, `:` paved square, `~` pond, `R` crypt, `g` grave,
`d` dead tree, `z` graveyard fence, `a` gate in the fence, `l` lantern, `p` pumpkins, `r` rock, `T` tree,
`t` tree stump, `e` barrels and crates, `q` well, `F` fountain, `x` bench, `y` pumpkin field. Buildings are a
rectangle of the same character: `h` house, `j` smithy, `n` tavern, `m` general store, `u` windmill,
`s` temple, `k` office of the crown, `o` post office, `w` adventurers' guild, `b` bank. The hero's house:
`I` wall, `i` wooden floor (a gap in the wall is the door), `B` bed, `L` chest. The villagers: `0` elder,
`1` smith, `2` farmer, `3` woodcutter, `4` guard, `5` drinker, `6` shopkeeper, `7` child, `8` scholar,
`9` water carrier, `K` herald, `O` priestess, `G` guild master, `M` postmaster, `Y` banker.

**Floors of buildings.** A level file with the lines `building: b` and `floor: keller` (cellar) or
`floor: oben` (upstairs) is a floor of the village building with that character: walking in at the
building's door leads there, and its stairs `E` lead back out of the door. Such floors are never part of
the run through the dungeon. Inside, `=` is a wall of iron bars and `U` a vault cell (see
`levels/12_der_tresorkeller.txt`, the bank's vault cellar).

Der Ausgang `E` braucht eine Wand im Norden (oben) und wird von Süden betreten.
Eine Tür `D` steht in einem ein Feld breiten Durchgang.

## Technik

- Engine: [Godot 4.5](https://godotengine.org) mit dem Compatibility-Renderer, damit es im Browser läuft
- Grafik: KayKit Dungeon Remastered, Adventurers und Skeletons von Kay Lousberg (CC0)
- Graveyard, crypt and autumn trees: KayKit Halloween Bits; village buildings, trees and rocks: KayKit Medieval Hexagon Pack, both by Kay Lousberg (CC0)
- Wooden floor and roof tiles of the house: "Wood 062" and "Roofing Tiles 014 C" by ambientCG (CC0)
- Böden, Wände, Säulen und Möbel: 3D Modular Dungeon Kit von Omie's Assets (CC0)
- Geräusche: selbst erzeugt mit `tools/make_sounds.py`, Schritte und Tür: Aufnahmen von Fantozzi, „Footsteps Leather, Cloth, Armor“ und qubodup, Kreaturen, Skelettstimmen und Ketten von rubberduck, Armbrustschüsse aus „Medieval sound effects - Weapon Textures“ (CC0, siehe `assets/sounds/CREDITS.txt`)
- Schrift: Cinzel und Cinzel Decorative (SIL Open Font License)
- Comic-Schrift der Kampfblasen: Bangers von Vernon Adams (SIL Open Font License)
- Jeder Push auf `main` spielt alle Levels automatisch durch und veröffentlicht die Browser-Version über GitHub Pages

## Lizenz

© 2026 devilbane. Alle Rechte vorbehalten, siehe [LICENSE](LICENSE). Grafiken und Schriften von anderen stehen unter ihren eigenen Lizenzen (siehe oben).
